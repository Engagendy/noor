#!/usr/bin/env python3
"""Build the bundled al-Bayquniyyah matn JSON from Arabic Wikisource.

منظومة البيقوني في مصطلح الحديث by al-Bayquni (d. c. 1080 AH) is the classic
beginner poem on hadith terminology — the companion to the Hadith tab, which
offers texts but nothing that teaches how to read them. It is NOT Quran, but
it is a revered classical text: like `build_matn_tuhfa.py`, this script
FETCHES and parses it so the provenance is reproducible and reviewable, and
NOTHING in the poem is typed, generated or "corrected" by hand anywhere in
this repository.

Source: https://ar.wikisource.org/wiki/منظومة_البيقوني (CC BY-SA 4.0), fetched
through the MediaWiki parse API. NOTE the page name: "المنظومة البيقونية" is a
near-empty different page.

MARKUP — this page differs from the Tuhfa one and the parser differs with it:
Tuhfa is a Word-exported `<table class="MsoTableGrid">` whose rows are either
a one-cell section heading or three cells (number, صدر, عجز). This page uses
the modern {{أبيات}} template instead: ONE `<div class="abyat-wrapper">` grid
holding a flat alternating run of `<div class="abyat-sdr">` (صدر) and
`<div class="abyat-ajz">` (عجز) divs. So:
  * lines are paired positionally (sdr, ajz, sdr, ajz, …) and asserted to
    alternate strictly — there is no number cell, so numbering is 1..N by
    position rather than parsed and cross-checked;
  * the source carries NO section headings at all. See SECTIONS below.

Cleaning is deliberately minimal and *proved* minimal, exactly as for Tuhfa:
  * ARABIC TATWEEL (U+0640) is stripped — in this source it is pure visual
    padding for the grid's justification ("أَبْـدَأُ"), never orthography.
  * whitespace is collapsed (the template's cells carry double spaces).
Nothing else. The script asserts, per hemistich, that the sequence of every
non-whitespace, non-tatweel character is identical before and after cleaning,
and fails loudly if any other character would be touched.

Output: Modules/Learn/Sources/Learn/Resources/matn-bayquniyyah.json
"""
import datetime
import html
import json
import os
import re
import sys
import unicodedata
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Modules/Learn/Sources/Learn/Resources/matn-bayquniyyah.json")
UA = "NoorApp/1.0 (free Quran app; contact: engagendy@gmail.com)"

PAGE = "منظومة البيقوني"
PAGE_URL = "https://ar.wikisource.org/wiki/" + urllib.parse.quote(PAGE.replace(" ", "_"))
API = ("https://ar.wikisource.org/w/api.php?action=parse&format=json&prop=text&page="
       + urllib.parse.quote(PAGE))

TATWEEL = "ـ"
# Arabic harakat we require to survive: fatha…sukun, the tanween, the
# superscript alef and the maddah.
HARAKAT = set("ًٌٍَُِّْٰٓ")

# EDITORIAL sections. Unlike the Tuhfa page, this source carries no headings
# whatever, so the reader would otherwise be one undivided run of 34 lines.
# These three are the poem's own structural joints, not a topical scheme
# invented for it:
#   * the opening couplet (praise + the announcement "وذي من أقسام الحديث
#     عدّه"),
#   * the definitions themselves — titled with the poem's own words from that
#     announcement,
#   * the closing couplet, which names the poem and counts its lines.
# `sections_editorial` in the output records this, and the reader prints a
# note under the poem, so a heading is never mistaken for the source's.
# The Arabic titles are section LABELS, never poem text; the boundaries are
# asserted below to be contiguous and to cover every parsed line.
SECTIONS = [
    {"id": "s1", "first": 1, "last": 2,
     "title_ar": "المقدمة", "title_en": "Introduction"},
    {"id": "s2", "first": 3, "last": 32,
     "title_ar": "أقسام الحديث", "title_en": "The kinds of hadith"},
    {"id": "s3", "first": 33, "last": 34,
     "title_ar": "الخاتمة", "title_en": "Conclusion"},
]

# The count the poem itself states in its last line ("فوق الثلاثين بأربع").
EXPECTED_LINES = 34


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def cell_text(inner_html):
    """Tags out, HTML entities in. No character is altered beyond that."""
    return html.unescape(re.sub(r"<[^>]+>", "", inner_html))


def clean(raw, where):
    """Strip tatweel + collapse whitespace, and PROVE nothing else changed."""
    cleaned = " ".join(raw.replace(TATWEEL, "").split())

    # 1. Every character the cleaning removed must be tatweel or whitespace.
    kept = [c for c in cleaned]
    removed = []
    ci = 0
    for c in raw:
        if ci < len(kept) and c == kept[ci]:
            ci += 1
        else:
            removed.append(c)
    illegal = {c for c in removed if c != TATWEEL and not c.isspace()}
    if illegal or ci != len(kept):
        names = ", ".join("U+%04X %s" % (ord(c), unicodedata.name(c, "?")) for c in sorted(illegal))
        sys.exit(f"FAIL [{where}]: cleaning would change more than tatweel/whitespace: {names}")

    # 2. The letter+haraka sequence is identical either side of it.
    before = [c for c in raw if c != TATWEEL and not c.isspace()]
    after = [c for c in cleaned if not c.isspace()]
    if before != after:
        sys.exit(f"FAIL [{where}]: character sequence changed by cleaning")
    return cleaned, removed


def main():
    data = fetch(API)
    parse = data["parse"]
    if parse["title"] != PAGE:
        sys.exit(f"FAIL: fetched '{parse['title']}', expected '{PAGE}'")
    body = parse["text"]["*"]

    # The page's own title and author, from the header template's data block,
    # so neither is typed here. These two are metadata, not poem text, and the
    # header template wraps them in ZERO WIDTH SPACEs (U+200B) — dropped here
    # before the usual proof-carrying clean(), which allows only tatweel and
    # whitespace. Nothing in the poem itself gets that treatment.
    page_title = re.search(r'<span class="ws-title">(.*?)</span>', body, re.S)
    page_author = re.search(r'<span class="ws-author">(.*?)</span>', body, re.S)
    if not page_title or not page_author:
        sys.exit("FAIL: the page carries no ws-title/ws-author block")
    title_ar = clean(cell_text(page_title.group(1)).replace("\u200b", ""), "ws-title")[0]
    author_ar = clean(cell_text(page_author.group(1)).replace("\u200b", ""), "ws-author")[0]

    # The {{أبيات}} grid. Its inner divs are the only content, so the wrapper
    # is taken from its opening tag to the LAST closing tag of the run.
    wrappers = re.findall(r'<div class="abyat-wrapper">(.*?)</div>\s*(?:\n|<!--|$)',
                          body, re.S)
    if len(wrappers) != 1:
        sys.exit(f"FAIL: expected exactly one abyat-wrapper, found {len(wrappers)}")
    grid = wrappers[0]

    # Every div inside the grid must be a hemistich: an unexpected class
    # (abyat-single_bayt, abyat-center, abyat-tadweer, a heading the page
    # gains later) must stop the build rather than be silently dropped.
    classes = re.findall(r'<div class="([^"]+)"', grid)
    unknown = sorted({c for c in classes if c not in ("abyat-sdr", "abyat-ajz")})
    if unknown:
        sys.exit(f"FAIL: unexpected div classes in the poem grid: {unknown} — "
                 "the page's structure changed; adapt the parser rather than dropping content")

    cells = re.findall(r'<div class="abyat-(sdr|ajz)">(.*?)</div>', grid, re.S)
    if len(cells) % 2:
        sys.exit(f"FAIL: {len(cells)} hemistich divs — not a whole number of lines")

    removed_chars = {}
    lines = []
    for i in range(0, len(cells), 2):
        (kind_a, raw_a), (kind_b, raw_b) = cells[i], cells[i + 1]
        number = i // 2 + 1
        if (kind_a, kind_b) != ("sdr", "ajz"):
            sys.exit(f"FAIL: line {number} is ({kind_a}, {kind_b}), expected (sdr, ajz) — "
                     "the hemistichs no longer alternate, so positional pairing is unsafe")
        first, removed = clean(cell_text(raw_a), f"line {number} صدر")
        for c in removed:
            removed_chars[c] = removed_chars.get(c, 0) + 1
        second, removed = clean(cell_text(raw_b), f"line {number} عجز")
        for c in removed:
            removed_chars[c] = removed_chars.get(c, 0) + 1
        if not first or not second:
            sys.exit(f"FAIL: line {number} is missing a hemistich")
        lines.append({"number": number, "section_id": None,
                      "first": first, "second": second,
                      # Reserved for follow-along audio (see Tuhfa builder).
                      "start": None})

    if [line["number"] for line in lines] != list(range(1, len(lines) + 1)):
        sys.exit("FAIL: line numbers not contiguous")

    # Attach the editorial sections, asserting they tile 1..N exactly.
    if SECTIONS[0]["first"] != 1 or SECTIONS[-1]["last"] != len(lines):
        sys.exit(f"FAIL: the editorial sections cover {SECTIONS[0]['first']}..{SECTIONS[-1]['last']}, "
                 f"but the poem parsed as 1..{len(lines)} — fix SECTIONS")
    for previous, section in zip(SECTIONS, SECTIONS[1:]):
        if section["first"] != previous["last"] + 1:
            sys.exit(f"FAIL: editorial sections are not contiguous at {section['id']}")
    for section in SECTIONS:
        for line in lines[section["first"] - 1:section["last"]]:
            line["section_id"] = section["id"]
    if any(line["section_id"] is None for line in lines):
        sys.exit("FAIL: a line ended up in no section")

    harakat = sum(1 for line in lines for c in line["first"] + line["second"] if c in HARAKAT)
    if harakat == 0:
        sys.exit("FAIL: the fetched text carries no harakat — a memorisation matn must be vowelled")
    if any(TATWEEL in line["first"] + line["second"] for line in lines):
        sys.exit("FAIL: tatweel survived cleaning")

    doc = {
        "id": "bayquniyyah",
        "title_ar": title_ar,
        "title_en": "Al-Bayquniyyah — a poem on hadith terminology",
        # Short forms for the navigation bar (the full title is the heading
        # inside the reader; a 44pt inline bar truncates it mid-word).
        "short_title_ar": "المنظومة البيقونية",
        "short_title_en": "Al-Bayquniyyah",
        "author_ar": author_ar,
        "author_en": "Al-Bayquni",
        "composed_ar": None,
        "composed_year_hijri": None,
        "source_name": "ويكي مصدر — Arabic Wikisource",
        "source_url": PAGE_URL,
        "source_license": "CC BY-SA 4.0",
        "retrieved": datetime.date.today().isoformat(),
        # True: the source page carries no headings — see SECTIONS above.
        "sections_editorial": True,
        # Reserved (see the Tuhfa builder): nothing ships until a recording's
        # licence is recorded in LICENSES.md (CLAUDE.md rule 5).
        "audio": None,
        "timings": None,
        "sections": [{"id": s["id"], "title_ar": s["title_ar"], "title_en": s["title_en"]}
                     for s in SECTIONS],
        "lines": lines,
    }

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
        f.write("\n")

    print(f"source     : {PAGE_URL}")
    print(f"sections   : {len(SECTIONS)} (editorial — the source carries none)")
    print(f"lines      : {len(lines)}"
          + ("" if len(lines) == EXPECTED_LINES else
             f"   (NOTE: the poem states {EXPECTED_LINES} — this edition has {len(lines)})"))
    print(f"harakat    : {harakat}")
    print("removed    : " + ", ".join(
        "U+%04X %s ×%d" % (ord(c), unicodedata.name(c, "?"), n)
        for c, n in sorted(removed_chars.items(), key=lambda kv: -kv[1])))
    print(f"written    : {OUT}")


if __name__ == "__main__":
    main()
