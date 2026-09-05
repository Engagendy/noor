#!/usr/bin/env python3
"""Build the bundled offline city database used by the prayer-times city picker.

Source: GeoNames "cities15000" (every place with population >= 15,000) plus
countryInfo — CC BY 4.0, recorded in LICENSES.md. Nothing is fetched at
runtime: the picker searches this file, so choosing a city never sends a
query anywhere (CLAUDE.md rule 3), and it works offline (rule 2).

Arabic names come from GeoNames' alternate names where one exists; the
hand-curated Arabic spellings already in the app (CityPreset.all) override
them, because GeoNames' Arabic is inconsistent for the cities that matter
most (e.g. مكة vs مكة المكرمة). Country names are NOT stored: both
platforms localise an ISO code at runtime, in every UI language.

Usage: python3 Tools/build_cities_db.py /path/to/cities15000.txt /path/to/countryInfo.txt
Output: Core/ContentDB/Sources/ContentDB/Resources/cities.sqlite
        android/app/src/main/assets/cities.sqlite (copy)
"""
import os, re, shutil, sqlite3, sys, unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Core/ContentDB/Sources/ContentDB/Resources/cities.sqlite")
ANDROID = os.path.join(ROOT, "android/app/src/main/assets/cities.sqlite")
PRESETS = os.path.join(ROOT, "Modules/PrayerTimes/Sources/PrayerTimes/PrayerSettings.swift")

ARABIC = re.compile(r"[؀-ۿ]")

# Letters NFKD leaves alone; the Swift and Kotlin `fold` carry the same map.
LETTER_MAP = {'ł': 'l', 'Ł': 'l', 'ø': 'o', 'Ø': 'o', 'ß': 'ss', 'đ': 'd', 'Đ': 'd', 'æ': 'ae', 'Æ': 'ae', 'œ': 'oe', 'Œ': 'oe', 'ı': 'i', 'ð': 'd', 'Ð': 'd', 'þ': 'th', 'Þ': 'th'}

def strip_accents(s):
    s = "".join(LETTER_MAP.get(c, c) for c in s)
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c)).lower()

def curated_arabic():
    """(english name -> arabic name) from the hand-written CityPreset list."""
    out = {}
    with open(PRESETS, encoding="utf-8") as f:
        for m in re.finditer(r'CityPreset\("([^"]+)",\s*"([^"]+)"', f.read()):
            out[m.group(1).lower()] = m.group(2)
    return out

def main(cities_path, countries_path):
    curated = curated_arabic()
    countries = {}
    with open(countries_path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("#"): continue
            cols = line.rstrip("\n").split("\t")
            countries[cols[0]] = cols[4]

    if os.path.exists(OUT): os.remove(OUT)
    db = sqlite3.connect(OUT)
    db.executescript("""
        CREATE TABLE country (code TEXT PRIMARY KEY, name TEXT NOT NULL);
        CREATE TABLE city (
            id INTEGER PRIMARY KEY,          -- GeoNames id, stable across rebuilds
            name TEXT NOT NULL,              -- English / local Latin name
            ascii TEXT NOT NULL,             -- accent-stripped lowercase, for search
            name_ar TEXT,                    -- Arabic name when known
            country TEXT NOT NULL REFERENCES country(code),
            admin1 TEXT,                     -- region code, disambiguates duplicates
            lat REAL NOT NULL, lon REAL NOT NULL,
            tz TEXT NOT NULL,                -- IANA identifier
            population INTEGER NOT NULL
        );
    """)
    db.executemany("INSERT INTO country VALUES (?,?)", countries.items())
    rows, with_ar = 0, 0
    with open(cities_path, encoding="utf-8") as f:
        for line in f:
            c = line.rstrip("\n").split("\t")
            gid, name, ascii_name, alts = int(c[0]), c[1], c[2], c[3]
            lat, lon, cc, admin1 = float(c[4]), float(c[5]), c[8], c[10]
            population, tz = int(c[14] or 0), c[17]
            if not tz or cc not in countries: continue
            name_ar = curated.get(name.lower())
            if not name_ar:
                # First Arabic-script alternate name, if any.
                for alt in alts.split(","):
                    if ARABIC.search(alt) and not re.search(r"[ݐ-ݿیک]", alt):
                        name_ar = alt.strip(); break
            if name_ar: with_ar += 1
            db.execute("INSERT INTO city VALUES (?,?,?,?,?,?,?,?,?,?)",
                       (gid, name, strip_accents(name), name_ar, cc,
                        admin1 or None, lat, lon, tz, population))
            rows += 1
    db.executescript("""
        CREATE INDEX idx_city_ascii ON city(ascii);
        CREATE INDEX idx_city_name_ar ON city(name_ar);  -- preset resolution is an equality lookup
        CREATE INDEX idx_city_country ON city(country, population DESC);
        CREATE INDEX idx_city_pop ON city(population DESC);
        CREATE INDEX idx_city_latlon ON city(lat, lon);
        VACUUM;
    """)
    db.commit(); db.close()
    shutil.copyfile(OUT, ANDROID)
    print(f"{rows} cities, {with_ar} with Arabic ({with_ar*100//rows}%), "
          f"{len(countries)} countries, {os.path.getsize(OUT)//1024} KB")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
