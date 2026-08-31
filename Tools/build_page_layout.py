#!/usr/bin/env python3
"""Build the bundled Madani page-layout DB (QCF v1 mushaf) + word-by-word data.

Fetches all 604 pages once from the public quran.com CDN API (gentle rate,
proper User-Agent per plan §6.7) and stores per-word records:
page, line, surah, ayah, position, QCF v1 glyph, Uthmani text, English word
translation. The Quran display text in the app still comes only from the
checksummed Tanzil DB; glyphs here are font code points, and text_uthmani is
kept for word-by-word display where it is shown word-at-a-time.

Output: Core/ContentDB/Sources/ContentDB/Resources/page_layout.sqlite
"""
import json
import os
import sqlite3
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Core/ContentDB/Sources/ContentDB/Resources/page_layout.sqlite")
UA = "NoorApp/0.1 (free Quran app; contact: engagendy@gmail.com)"

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)

rows = []
for page in range(1, 605):
    url = (f"https://api.qurancdn.com/api/qdc/verses/by_page/{page}"
           "?words=true&per_page=50"
           "&word_fields=code_v1,code_v2,line_number,text_uthmani"
           "&fields=verse_key")
    data = fetch(url)
    assert data.get("pagination", {}).get("next_page") is None, f"page {page} paginated"
    for verse in data["verses"]:
        surah, ayah = map(int, verse["verse_key"].split(":"))
        for w in verse["words"]:
            rows.append((
                page, w["line_number"], surah, ayah, w["position"],
                w.get("code_v1") or "", w.get("code_v2") or "",
                w.get("text_uthmani") or "",
                (w.get("translation") or {}).get("text") or "",
                w.get("char_type_name") or "word",
            ))
    if page % 50 == 0:
        print(f"{page}/604 ({len(rows)} words)")
    time.sleep(0.12)

assert len(rows) > 77000, f"unexpectedly few words: {len(rows)}"

if os.path.exists(OUT):
    os.remove(OUT)
db = sqlite3.connect(OUT)
db.executescript("""
CREATE TABLE page_word (
  page INTEGER NOT NULL,
  line INTEGER NOT NULL,
  surah_id INTEGER NOT NULL,
  ayah INTEGER NOT NULL,
  position INTEGER NOT NULL,
  glyph TEXT NOT NULL,
  glyph_v2 TEXT NOT NULL,
  text TEXT NOT NULL,
  translation TEXT NOT NULL,
  char_type TEXT NOT NULL
);
CREATE INDEX idx_page_word_page ON page_word(page, line, surah_id, ayah, position);
CREATE INDEX idx_page_word_ref ON page_word(surah_id, ayah, position);
""")
db.executemany("INSERT INTO page_word VALUES (?,?,?,?,?,?,?,?,?,?)", rows)
db.commit()
db.execute("VACUUM")
db.close()
print(f"page_layout.sqlite written: {len(rows)} words, "
      f"{os.path.getsize(OUT) / 1e6:.1f} MB")
