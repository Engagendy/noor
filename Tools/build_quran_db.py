#!/usr/bin/env python3
"""Build the bundled read-only Quran SQLite from verified Tanzil sources.

Inputs (committed verbatim, per Tanzil license — do not edit):
  Tools/source/quran-uthmani.txt   Tanzil Uthmani text  (sura|ayah|text)
  Tools/source/quran-data.xml      Tanzil surah metadata

Output:
  Core/ContentDB/Sources/ContentDB/Resources/quran.sqlite

The verse text is copied byte-for-byte from the Tanzil file. This script must
never transform, normalize, or "fix" the text in any way. A SHA-256 over all
verse lines is stored in `meta` and re-verified by the app at startup.
"""
import hashlib
import os
import sqlite3
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEXT = os.path.join(ROOT, "Tools/source/quran-uthmani.txt")
META = os.path.join(ROOT, "Tools/source/quran-data.xml")
OUT = os.path.join(ROOT, "Core/ContentDB/Sources/ContentDB/Resources/quran.sqlite")

verses = []
sha = hashlib.sha256()
with open(TEXT, "rb") as f:
    for raw in f:
        line = raw.decode("utf-8").rstrip("\n")
        if not line or line.startswith("#"):
            continue
        sura, ayah, text = line.split("|", 2)
        verses.append((int(sura), int(ayah), text))
        sha.update(f"{sura}|{ayah}|{text}".encode("utf-8"))
        sha.update(b"\n")
checksum = sha.hexdigest()

assert len(verses) == 6236, f"expected 6236 ayat, got {len(verses)}"

suras = []
for s in ET.parse(META).getroot().iter("sura"):
    suras.append((
        int(s.get("index")), s.get("name"), s.get("tname"), s.get("ename"),
        int(s.get("ayas")), s.get("type"), int(s.get("order")),
    ))
assert len(suras) == 114

os.makedirs(os.path.dirname(OUT), exist_ok=True)
if os.path.exists(OUT):
    os.remove(OUT)
db = sqlite3.connect(OUT)
db.executescript("""
CREATE TABLE surah (
  id INTEGER PRIMARY KEY,
  name_arabic TEXT NOT NULL,
  name_transliterated TEXT NOT NULL,
  name_english TEXT NOT NULL,
  ayah_count INTEGER NOT NULL,
  revelation_type TEXT NOT NULL CHECK (revelation_type IN ('Meccan','Medinan')),
  revelation_order INTEGER NOT NULL
);
CREATE TABLE verse (
  surah_id INTEGER NOT NULL REFERENCES surah(id),
  ayah INTEGER NOT NULL,
  text TEXT NOT NULL,
  PRIMARY KEY (surah_id, ayah)
) WITHOUT ROWID;
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
""")
db.executemany("INSERT INTO surah VALUES (?,?,?,?,?,?,?)", suras)
db.executemany("INSERT INTO verse VALUES (?,?,?)", verses)
db.executemany("INSERT INTO meta VALUES (?,?)", [
    ("source", "Tanzil.net Quran Uthmani"),
    ("source_url", "https://tanzil.net"),
    ("text_sha256", checksum),
])
db.commit()
db.execute("VACUUM")
db.close()
print(f"quran.sqlite written: {len(verses)} ayat, 114 surahs")
print(f"text_sha256 = {checksum}")
