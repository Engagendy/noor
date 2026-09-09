#!/usr/bin/env python3
"""Build the bundled tajweed annotation DB (riwayat Hafs).

Source: https://github.com/cpfair/quran-tajweed
        output/tajweed.hafs.uthmani-pause-sajdah.json
The repository carries NO LICENSE file; its README is the only licence
statement and says the data file "is licensed under a Creative Commons
Attribution 4.0 International License, while the original Tanzil.net text
file linked above is made available under the Tanzil.net terms of use".
Recorded in LICENSES.md.

THE ALIGNMENT PROBLEM
---------------------
The annotations are per-ayah Unicode *codepoint* offsets (the README's
"start": 245 example is stale — offsets are relative to the ayah, not the
file) into one specific Tanzil text: the copy the README links from
github.com/cpfair/quran-tajweed/files/7281388/quran-uthmani.txt, which
despite the data file's "uthmani-pause-sajdah" name carries NO waqf/sajdah
marks.  Our bundled quran.sqlite is the pause+sajdah variant (byte-identical
to Tools/source/quran-uthmani.txt).  Feeding the raw offsets to our text puts
27% of qalqalah spans on letters that are not qalqalah letters.

quran.sqlite is verified and checksummed and is NEVER touched here (hard rule
1).  Instead we diff each ayah (reference vs ours) with difflib and carry the
offsets across.  The only differences are (a) waqf/sajdah marks inserted in
ours — 8 codepoints that appear in our text and never in the reference — and
(b) a handful of spelling variants (small yeh U+06E6 written as U+0640 U+06E7,
hamza carriers).  Because an inserted waqf mark can land *inside* a span that
crosses a word boundary, each mapped span is split around the inserted
codepoints so a pause mark is never tinted as if it were a tajweed letter.

Verification is by "skeleton": strip combining marks, tatweel and waqf marks
from the reference span and from the mapped span and require them equal.  The
script asserts on the mismatch rate, on out-of-range spans and on the rule
set.  Offsets in the output are Unicode scalar offsets into verse.text (all
codepoints involved are BMP, so these equal UTF-16 offsets).

Output: Core/ContentDB/Sources/ContentDB/Resources/tajweed.sqlite
"""
import collections
import difflib
import hashlib
import json
import os
import sqlite3
import time
import unicodedata
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Core/ContentDB/Sources/ContentDB/Resources/tajweed.sqlite")
QURAN_DB = os.path.join(ROOT, "Core/ContentDB/Sources/ContentDB/Resources/quran.sqlite")
UA = "NoorApp/0.1 (free Quran app; contact: engagendy@gmail.com)"

DATA_URL = ("https://raw.githubusercontent.com/cpfair/quran-tajweed/master/"
            "output/tajweed.hafs.uthmani-pause-sajdah.json")
# The exact Tanzil copy the annotations were generated against, as linked by
# the quran-tajweed README. Do NOT substitute tanzil.net's current download.
REF_URL = "https://github.com/cpfair/quran-tajweed/files/7281388/quran-uthmani.txt"

RETRIEVED = "2026-09-09"

# The 18 rules the data file uses. This list is the contract with the app's
# legend (TajweedRule in Core/ContentDB) — the app asserts it matches.
RULES = [
    "ghunnah",
    "hamzat_wasl",
    "idghaam_ghunnah",
    "idghaam_mutajanisayn",
    "idghaam_mutaqaribayn",
    "idghaam_no_ghunnah",
    "idghaam_shafawi",
    "ikhfa",
    "ikhfa_shafawi",
    "iqlab",
    "lam_shamsiyyah",
    "madd_2",
    "madd_246",
    "madd_6",
    "madd_munfasil",
    "madd_muttasil",
    "qalqalah",
    "silent",
]

# Waqf (pause) marks, the rub-el-hizb and the sajdah sign — recitation
# *instructions*, never letters and so never tajweed targets. Deliberately
# excludes U+06E5/U+06E6/U+06E7 (small waw/yeh), which ARE pronounced letters
# and are exactly what madd_2 lands on in the Ibrahim/Ismail spellings.
MARKS = set(chr(c) for c in list(range(0x06D6, 0x06DF)) + [0x06E9])
TATWEEL = "ـ"
QALQALAH_LETTERS = set("قطبجد")  # ق ط ب ج د

SCHEMA = """
CREATE TABLE tajweed_rule (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);
CREATE TABLE tajweed_span (
  surah_id INTEGER NOT NULL,
  ayah INTEGER NOT NULL,
  rule_id INTEGER NOT NULL REFERENCES tajweed_rule(id),
  start INTEGER NOT NULL,
  end INTEGER NOT NULL
);
CREATE INDEX idx_tajweed_span_ref ON tajweed_span(surah_id, ayah);
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
"""


def fetch(url, attempts=6):
    """GET with retries — the GitHub raw CDN intermittently answers 503."""
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read()
        except (urllib.error.HTTPError, urllib.error.URLError) as error:
            if attempt == attempts:
                raise
            print(f"  {error} — retrying ({attempt}/{attempts - 1})")
            time.sleep(2 * attempt)


def parse_tanzil(blob):
    """Parse Tanzil 'text with aya numbers' (surah|ayah|text) into a dict."""
    verses = {}
    for line in blob.decode("utf-8").splitlines():
        line = line.strip("﻿").strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) < 3:
            continue
        verses[(int(parts[0]), int(parts[1]))] = parts[2]
    return verses


def skeleton(text):
    """Letters only: drop combining marks, tatweel, waqf marks and spaces.

    Two spans with the same skeleton cover the same letters, which is what
    'the annotation landed in the right place' means across two orthographies.
    """
    return "".join(c for c in text
                   if c not in MARKS and c != TATWEEL and c != " "
                   and unicodedata.category(c) != "Mn")


def offset_maps(ref, ours):
    """Map every boundary position 0..len(ref) into our text.

    Returns (lo, hi, inserted) where lo[i]/hi[i] are the earliest/latest our-
    text position corresponding to reference boundary i, and `inserted` is the
    set of our-text indices that have no counterpart in the reference (the
    waqf/sajdah marks and their padding).
    """
    if ref == ours:
        identity = list(range(len(ref) + 1))
        return identity, identity, set()
    matcher = difflib.SequenceMatcher(a=ref, b=ours, autojunk=False)
    lo = [None] * (len(ref) + 1)
    hi = [None] * (len(ref) + 1)
    inserted = set()
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            for k in range(i2 - i1 + 1):
                lo[i1 + k] = hi[i1 + k] = j1 + k
        else:
            if tag == "insert":
                inserted.update(range(j1, j2))
            for i in range(i1, i2 + 1):
                if lo[i] is None:
                    lo[i] = j1
                hi[i] = j2
    for i in range(len(lo)):
        if lo[i] is None:
            lo[i] = hi[i]
    return lo, hi, inserted


def split_span(text, start, end, inserted):
    """Split [start, end) around inserted codepoints; trim edge whitespace."""
    segments = []
    run = None
    for i in range(start, end):
        if i in inserted or text[i] in MARKS:
            if run is not None:
                segments.append(run)
                run = None
            continue
        run = (run[0], i + 1) if run else (i, i + 1)
    if run is not None:
        segments.append(run)
    trimmed = []
    for s, e in segments:
        while s < e and text[s] == " ":
            s += 1
        while e > s and text[e - 1] == " ":
            e -= 1
        if e > s:
            trimmed.append((s, e))
    return trimmed


print("fetching annotations …")
annotations = json.loads(fetch(DATA_URL))
print("fetching the reference Tanzil text the offsets index …")
reference = parse_tanzil(fetch(REF_URL))

connection = sqlite3.connect(f"file:{QURAN_DB}?mode=ro", uri=True)
ours = {(s, a): t for s, a, t in
        connection.execute("SELECT surah_id, ayah, text FROM verse")}
connection.close()

assert len(annotations) == 6236, f"expected 6236 ayat, got {len(annotations)}"
assert len(reference) == 6236, f"reference text has {len(reference)} ayat"
assert len(ours) == 6236, f"our DB has {len(ours)} ayat"
assert set(reference) == set(ours), "reference and our DB disagree on ayah keys"

found_rules = sorted({a["rule"] for e in annotations for a in e["annotations"]})
assert found_rules == RULES, f"rule set changed upstream: {found_rules}"

rule_id = {name: i + 1 for i, name in enumerate(RULES)}
rows = []
stats = collections.Counter()
mismatches = []

for entry in annotations:
    key = (entry["surah"], entry["ayah"])
    assert key in ours, f"{key} missing from quran.sqlite"
    ref_text, our_text = reference[key], ours[key]
    lo, hi, inserted = offset_maps(ref_text, our_text)
    stats["ayat"] += 1
    if ref_text != our_text:
        stats["ayat_needing_alignment"] += 1

    for annotation in entry["annotations"]:
        start, end = annotation["start"], annotation["end"]
        stats["annotations"] += 1
        assert 0 <= start < end <= len(ref_text), \
            f"{key} {annotation['rule']} [{start},{end}) outside reference ayah"

        our_start, our_end = lo[start], hi[end]
        assert 0 <= our_start < our_end <= len(our_text), \
            f"{key} {annotation['rule']} mapped to [{our_start},{our_end}) " \
            f"outside our ayah of {len(our_text)} codepoints"

        expected = skeleton(ref_text[start:end])
        actual = skeleton(our_text[our_start:our_end])
        if expected == actual:
            stats["aligned"] += 1
        else:
            stats["misaligned"] += 1
            if len(mismatches) < 20:
                mismatches.append((key, annotation["rule"],
                                   ref_text[start:end], our_text[our_start:our_end]))

        segments = split_span(our_text, our_start, our_end, inserted)
        assert segments, \
            f"{key} {annotation['rule']} mapped to an empty span"
        if len(segments) > 1:
            stats["spans_split_around_waqf"] += 1
        for s, e in segments:
            assert 0 <= s < e <= len(our_text), f"{key} bad segment [{s},{e})"
            rows.append((key[0], key[1], rule_id[annotation["rule"]], s, e))

# A qalqalah span must contain a qalqalah letter — the sharpest end-to-end
# check that the offsets landed on our letters and not merely inside our ayah.
qalqalah_total = qalqalah_ok = 0
for surah, ayah, rid, s, e in rows:
    if rid != rule_id["qalqalah"]:
        continue
    qalqalah_total += 1
    if any(c in QALQALAH_LETTERS for c in ours[(surah, ayah)][s:e]):
        qalqalah_ok += 1

rate = stats["aligned"] / stats["annotations"]
print(f"annotations         : {stats['annotations']}")
print(f"ayat needing align  : {stats['ayat_needing_alignment']} / {stats['ayat']}")
print(f"aligned (skeleton)  : {stats['aligned']} ({rate * 100:.4f}%)")
print(f"misaligned          : {stats['misaligned']}")
print(f"split around waqf   : {stats['spans_split_around_waqf']}")
print(f"qalqalah on a qalqalah letter: {qalqalah_ok}/{qalqalah_total} "
      f"({qalqalah_ok / qalqalah_total * 100:.2f}%)")
for m in mismatches:
    print(f"  MISMATCH {m[0]} {m[1]}: ref {m[2]!r} vs ours {m[3]!r}")

# Thresholds. The known residue is the small-yeh spelling variant (reference
# U+06E6 written in our text as U+0640 U+06E7), which the skeleton test cannot
# see through; the letters covered are the same. Anything beyond that is a
# regression and must be investigated, not waved through.
assert rate > 0.999, f"alignment rate collapsed to {rate:.4%}"
assert stats["misaligned"] <= 40, f"{stats['misaligned']} misaligned spans"
assert qalqalah_ok == qalqalah_total, \
    f"{qalqalah_total - qalqalah_ok} qalqalah spans miss a qalqalah letter"
assert len(rows) >= stats["annotations"], "lost spans while splitting"

if os.path.exists(OUT):
    os.remove(OUT)
db = sqlite3.connect(OUT)
db.executescript(SCHEMA)
db.executemany("INSERT INTO tajweed_rule (id, name) VALUES (?, ?)",
               [(i, n) for n, i in sorted(rule_id.items(), key=lambda kv: kv[1])])
db.executemany(
    "INSERT INTO tajweed_span (surah_id, ayah, rule_id, start, end) VALUES (?,?,?,?,?)",
    rows)

digest = hashlib.sha256()
for row in sorted(rows):
    digest.update(("%d|%d|%d|%d|%d\n" % row).encode("utf-8"))
db.executemany("INSERT INTO meta (key, value) VALUES (?, ?)", [
    ("source", "https://github.com/cpfair/quran-tajweed"),
    ("source_file", "output/tajweed.hafs.uthmani-pause-sajdah.json"),
    ("license", "CC BY 4.0 (README; the repository has no LICENSE file)"),
    ("attribution", "Tajweed annotations by cpfair/quran-tajweed, CC BY 4.0"),
    ("retrieved", RETRIEVED),
    ("offsets", "Unicode scalar offsets into quran.sqlite verse.text"),
    ("alignment_rate", f"{rate:.6f}"),
    ("span_checksum", digest.hexdigest()),
])
db.commit()
db.execute("VACUUM")
db.close()

print(f"wrote {len(rows)} spans over {stats['ayat']} ayat to {OUT} "
      f"({os.path.getsize(OUT) / 1e6:.1f} MB)")
print(f"span checksum: {digest.hexdigest()}")
