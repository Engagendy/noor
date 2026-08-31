# Content & Software Licenses

Every bundled or downloaded content source must be recorded here with its
license/permission and attribution string (CLAUDE.md hard rule 5).
Attributions are displayed in Settings → About.

## Bundled content

### Quran Arabic text — Tanzil Uthmani
- **Source:** https://tanzil.net (Tanzil Project)
- **File:** `Tools/source/quran-uthmani.txt` (verbatim, including the Tanzil
  copyright footer) → built into `Core/ContentDB/.../quran.sqlite` by
  `Tools/build_quran_db.py` with zero text transformation.
- **License:** Tanzil terms of use — text may be used freely provided it is
  kept intact, the source is cited, and the copyright notice is included with
  verbatim copies. Notice preserved in the source file footer.
- **Integrity:** SHA-256 `fbf5e7dbcb58abc3a78ef681a373dc55d79353a4901b704f0048ac5b7d0e04f3`
  over all 6236 verse lines; verified at app startup.
- **Attribution:** "Quran text from Tanzil.net (Uthmani)."

### Surah metadata — Tanzil quran-data.xml
- **Source:** https://tanzil.net/res/text/metadata/quran-data.xml
- **License:** same Tanzil terms as above.
- **Attribution:** "Surah metadata from Tanzil.net."

### KFGQPC Uthmanic Hafs font (v22)
- **Source:** King Fahd Glorious Quran Printing Complex
  (https://fonts.qurancomplex.gov.sa), obtained via the mirror
  https://github.com/mustafa0x/qpc-fonts (unmodified, digitally signed TTF).
- **File:** `Core/DesignSystem/Sources/DesignSystem/Resources/UthmanicHafs.ttf`
- **License:** free to use for displaying the Quran, per KFGQPC distribution
  terms.
- **Attribution:** "Uthmanic Hafs font by King Fahd Glorious Quran Printing
  Complex."

### Quran translation — Saheeh International (English)
- **Source:** Tanzil translations collection (https://tanzil.net/trans/), id `en.sahih`.
- **Access:** downloaded on demand to Application Support; fully offline after.
- **License:** Tanzil translation terms — free for non-commercial use with
  source cited; this app is free and non-commercial.
- **Attribution:** "English translation: Saheeh International, via Tanzil.net."

### Recitations — EveryAyah.com (streamed/cached on demand)
- **Reciters:** Mishary Alafasy, Mahmoud Khalil Al-Husary, Mohamed Siddiq
  Al-Minshawi (128 kbps ayah-by-ayah sets).
- **Source:** https://everyayah.com (community-hosted recitation archive).
- **Access:** streamed at listen time, cached to the device Caches directory.
- **Attribution:** "Recitations courtesy of EveryAyah.com."
- **Note:** verify redistribution terms before App Store submission; audio is
  never bundled, only fetched by the user's explicit playback.

## Software dependencies

| Package | License | URL |
|---|---|---|
| GRDB.swift | MIT | https://github.com/groue/GRDB.swift |
| adhan-swift | MIT | https://github.com/batoulapps/adhan-swift |

## Planned (record before shipping each phase)

- Translations (Quran Foundation API / fawazahmed0 quran-api) — per-translation
- Tafsir packs — per-source
- Recitations (EveryAyah / Quran Foundation audio) — per-reciter
- Hadith (Sunnah.com) — per-collection
