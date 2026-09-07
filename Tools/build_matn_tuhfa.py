#!/usr/bin/env python3
"""Build the bundled Tuhfat al-Atfal matn JSON from Arabic Wikisource.

Tuhfat al-Atfal (تحفة الأطفال في تجويد القرآن) by Sulayman al-Jamzuri
(finished 1198 AH) is the classic beginner tajweed matn. It is NOT Quran,
but it is a revered classical text: this script FETCHES and parses it so the
provenance is reproducible and reviewable, and NOTHING in the poem is typed,
generated or "corrected" by hand anywhere in this repository.

Source: https://ar.wikisource.org/wiki/تحفة_الأطفال (CC BY-SA 4.0), fetched
through the MediaWiki parse API. The page body is HTML converted from Word:
one big table whose rows are either a section heading (a single colspan cell)
or a line of verse (three cells: number, first hemistich, second hemistich).

Cleaning is deliberately minimal and *proved* minimal:
  * ARABIC TATWEEL (U+0640) is stripped — in this source it is pure visual
    padding for the Word table's alignment ("يَقُــولُ"), never orthography.
  * whitespace is collapsed (the HTML carries newlines and NBSPs from Word).
Nothing else. The script asserts, per cell, that the sequence of every
non-whitespace, non-tatweel character is byte-identical before and after
cleaning, and fails loudly if any other character would be touched.

Output: Modules/Learn/Sources/Learn/Resources/matn-tuhfat-al-atfal.json

The emitted schema also serves future matns (e.g. al-Jazariyyah, once a
*vowelled* source is verified) and future audio: `audio` (per-matn file) and
`timings` (per-line start seconds) are present and null today, so gaining
playback and follow-along highlighting needs no restructuring.
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
OUT = os.path.join(ROOT, "Modules/Learn/Sources/Learn/Resources/matn-tuhfat-al-atfal.json")
UA = "NoorApp/1.0 (free Quran app; contact: engagendy@gmail.com)"

PAGE = "تحفة الأطفال"
PAGE_URL = "https://ar.wikisource.org/wiki/" + urllib.parse.quote(PAGE.replace(" ", "_"))
API = ("https://ar.wikisource.org/w/api.php?action=parse&format=json&prop=text&page="
       + urllib.parse.quote(PAGE))

TATWEEL = "ـ"
# Arabic harakat we require to survive: fatha…sukun, the tanween, the
# superscript alef and the maddah.
HARAKAT = set("ًٌٍَُِّْٰٓ")

# English section titles. These are OUR translations of the (Arabic) headings
# the source carries — the Arabic is never invented, only rendered.
SECTION_EN = {
    "المقدمة": "Introduction",
    "النون الساكنة والتنوين": "Noon sākinah and tanween",
    "الميم والنون المشددتين": "Doubled meem and noon",
    "الميم الساكنة": "Meem sākinah",
    "لام آل ولام الفعل": "Lām of “al-” and lām of the verb",
    "المثلين والمتقاربين والمتجانسين": "Identical, close and homogeneous letters",
    "أقسام المد": "Kinds of madd",
    "أحكام المد": "Rulings of madd",
    "أقسام المد اللازم": "Kinds of the necessary madd",
    "الخاتمة": "Conclusion",
}


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

    # 2. The letter+haraka sequence is byte-identical either side of it.
    before = [c for c in raw if c != TATWEEL and not c.isspace()]
    after = [c for c in cleaned if not c.isspace()]
    if before != after:
        sys.exit(f"FAIL [{where}]: character sequence changed by cleaning")
    return cleaned, removed


def slug(index):
    return f"s{index}"


def main():
    data = fetch(API)
    parse = data["parse"]
    if parse["title"] != PAGE:
        sys.exit(f"FAIL: fetched '{parse['title']}', expected '{PAGE}'")
    body = parse["text"]["*"]

    tables = re.findall(r'<table class="MsoTableGrid".*?</table>', body, re.S)
    if len(tables) != 1:
        sys.exit(f"FAIL: expected exactly one poem table, found {len(tables)}")
    rows = re.findall(r"<tr>(.*?)</tr>", tables[0], re.S)

    sections, lines = [], []
    removed_chars = {}
    current = None
    for i, row in enumerate(rows):
        cells = re.findall(r"<td\b([^>]*)>(.*?)</td>", row, re.S)
        texts = []
        for attrs, inner in cells:
            cleaned, removed = clean(cell_text(inner), f"row {i}")
            for c in removed:
                removed_chars[c] = removed_chars.get(c, 0) + 1
            texts.append(cleaned)
        if len(cells) == 1:
            title = texts[0]
            if not title:
                sys.exit(f"FAIL: empty section heading at row {i}")
            current = {"id": slug(len(sections) + 1), "title_ar": title,
                       "title_en": SECTION_EN.get(title)}
            if current["title_en"] is None:
                sys.exit(f"FAIL: no English title recorded for section '{title}' — "
                         "add it to SECTION_EN rather than shipping it untranslated")
            sections.append(current)
        elif len(cells) == 3:
            if current is None:
                sys.exit(f"FAIL: verse row {i} before any section heading")
            number_raw = texts[0]
            m = re.fullmatch(r"\((\d+)\)", number_raw)
            if not m:
                sys.exit(f"FAIL: unparsable line number '{number_raw}' at row {i}")
            number = int(m.group(1))
            if number != len(lines) + 1:
                sys.exit(f"FAIL: line numbers not contiguous: got {number}, expected {len(lines) + 1}")
            first, second = texts[1], texts[2]
            if not first or not second:
                sys.exit(f"FAIL: line {number} is missing a hemistich")
            lines.append({"number": number, "section_id": current["id"],
                          "first": first, "second": second,
                          # Reserved for follow-along audio (see module docstring).
                          "start": None})
        else:
            sys.exit(f"FAIL: row {i} has {len(cells)} cells, expected 1 or 3")

    harakat = sum(1 for line in lines for c in line["first"] + line["second"] if c in HARAKAT)
    if harakat == 0:
        sys.exit("FAIL: the fetched text carries no harakat — a tajweed matn must be vowelled")
    if any(TATWEEL in line["first"] + line["second"] for line in lines):
        sys.exit("FAIL: tatweel survived cleaning")

    doc = {
        "id": "tuhfat-al-atfal",
        "title_ar": "تحفة الأطفال في تجويد القرآن",
        "title_en": "Tuhfat al-Atfal — a poem on Quranic tajweed",
        "author_ar": "سليمان بن حسين الجمزوري",
        "author_en": "Sulayman al-Jamzuri",
        "composed_ar": "فرغ من نظمها سنة ١١٩٨ هـ",
        "composed_year_hijri": 1198,
        "source_name": "ويكي مصدر — Arabic Wikisource",
        "source_url": PAGE_URL,
        "source_license": "CC BY-SA 4.0",
        "retrieved": datetime.date.today().isoformat(),
        # Reserved: a bundled/downloaded recitation of the whole matn, and
        # per-line start seconds for follow-along highlighting. Nothing ships
        # until a recording's licence is recorded in LICENSES.md (rule 5).
        "audio": None,
        "timings": None,
        "sections": sections,
        "lines": lines,
    }

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
        f.write("\n")

    print(f"source     : {PAGE_URL}")
    print(f"sections   : {len(sections)}")
    print(f"lines      : {len(lines)}"
          + ("" if len(lines) == 61 else
             f"   (NOTE: the received count is conventionally 61 — this edition has {len(lines)})"))
    print(f"harakat    : {harakat}")
    print("removed    : " + ", ".join(
        "U+%04X %s ×%d" % (ord(c), unicodedata.name(c, "?"), n)
        for c, n in sorted(removed_chars.items(), key=lambda kv: -kv[1])))
    print(f"written    : {OUT}")


if __name__ == "__main__":
    main()
