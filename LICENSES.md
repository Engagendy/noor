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

### Tafsir — Al-Muyassar & Ibn Kathir (fetched per-ayah, cached)
- **Source:** spa5k/tafsir_api CDN bundles
  (https://github.com/spa5k/tafsir_api), serving public tafsir text
  collections; fetched on demand and cached on device.
- **Attribution:** "Tafsir texts via the Tafsir API project."
- **Note:** verify per-tafsir redistribution terms before App Store release.

### QCF v2 page fonts (Madani page mode — downloaded on demand)
- **Source:** King Fahd Glorious Quran Printing Complex per-page fonts
  (`QCF2001–QCF2604`), obtained via the mustafa0x/qpc-fonts mirror
  (`mushaf-v2`) — the exact typeface of the printed Madani mushaf. One
  ~600 KB font per page, downloaded when a page is first viewed, cached in
  Application Support.
- **Attribution:** "Madani page fonts by King Fahd Glorious Quran Printing
  Complex."

### Page layout + word-by-word data (bundled)
- **Source:** quran.com / Quran Foundation layout data via the public
  qurancdn API (one-time prefetch by `Tools/build_page_layout.py`, gentle
  rate, identified User-Agent). Per-word QCF glyph codes, line numbers, and
  English word-by-word glosses.
- **File:** `Core/ContentDB/Sources/ContentDB/Resources/page_layout.sqlite`
- **Attribution:** "Page layout and word-by-word data courtesy of
  Quran.com (Quran Foundation)."

### Amiri Quran font (bundled — flow-mode Quran text)
- **File:** `Core/DesignSystem/Sources/DesignSystem/Resources/AmiriQuran.ttf`
- **Source:** Amiri project by Khaled Hosny (via google/fonts).
- **License:** SIL Open Font License 1.1.
- **Why:** the KFGQPC *text* fonts mis-position Quranic annotation marks
  (e.g. U+06DF renders a dotted circle) under Apple's text engine; broken
  harakat are a release blocker (design §3). The Madani page mode remains
  100% KFGQPC via the QCF page fonts.
- **Attribution:** "Amiri Quran font by Khaled Hosny (SIL OFL)."

### Athkar — Hisn al-Muslim (bundled)
- **File:** `Modules/Athkar/Sources/Athkar/Resources/athkar.json`
  (132 categories, 267 adhkar).
- **Source text:** "Hisn al-Muslim" (حصن المسلم) by Sa'id ibn Ali ibn Wahf
  al-Qahtani — distributed by the author as a charitable endowment (waqf)
  for free use and reproduction. JSON transcription via
  github.com/rn0x/Adhkar-json (no explicit license; text itself is waqf).
- **Attribution:** "Adhkar from Hisn al-Muslim by Sa'id al-Qahtani."

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

### Adhan — Aaqib Azeez (bundled, trimmed to 28s)
- **Source:** Wikimedia Commons, "The Adhan - Muslim Call to Prayer - Aaqib Azeez.mp3" (uploaded by User:Atcovi)
- **License:** CC BY-SA 4.0
- **Attribution:** "Adhan by Aaqib Azeez (Wikimedia Commons, CC BY-SA 4.0)."

### Adhan — Prophet's Mosque, Madinah (bundled, trimmed to 28s)
- **Source:** Wikimedia Commons, "33937 ejaz215 call-to-prayer-from-the-prophet-s-mo.ogg"
- **License:** CC BY 3.0
- **Attribution:** "Adhan recorded at the Prophet's Mosque, Madinah (Wikimedia Commons, CC BY 3.0)."

### Adhan — melodic (bundled, trimmed to 28s)
- **Source:** Wikimedia Commons, "Beautiful adhan.ogg"
- **License:** CC0 (public domain)
- **Attribution:** none required (credited as courtesy).

### Adhan — Masjid al-Haram, Makkah, 21 Jan 2013 (bundled, trimmed to 28s)
- **Source:** Wikimedia Commons, "Adhan, Great Mosque of Mecca - Jan 21, 2013.webm"
  (audio extracted; licence reviewer-verified on Commons, 2018)
- **License:** CC BY 3.0
- **Attribution:** "Adhan at Masjid al-Haram, Makkah, by Seyfula Islam (Wikimedia Commons, CC BY 3.0)."

### Adhan — Masjid al-Haram, Makkah, Maghrib 25 Feb 2012 (bundled, trimmed to 28s)
- **Source:** Wikimedia Commons, "Maghrib Adhan at the Masjid al Haram, Mecca - 25 Feb, 2012.webm"
  (audio extracted; licence reviewer-verified on Commons, 2020)
- **License:** CC BY 3.0
- **Attribution:** "Maghrib adhan at Masjid al-Haram, Makkah, by 3omar Faruq (Wikimedia Commons, CC BY 3.0)."

### Hadith — An-Nawawi's Forty + Forty Hadith Qudsi (bundled)
- **Source:** fawazahmed0/hadith-api (github.com/fawazahmed0/hadith-api), editions ara/eng-nawawi and ara/eng-qudsi
- **License:** Unlicense (public domain dataset); the classical texts themselves are public domain
- **Attribution:** "Hadith data courtesy of the hadith-api project."

### QCF v1.5 page fonts (compact mushaf, downloaded on demand)
- **Source:** mustafa0x/qpc-fonts, mushaf-v1.5 (KFGQPC Quran Complex fonts)
- **License:** KFGQPC terms (free use with text integrity), same as v2
- **Attribution:** "Madani mushaf fonts by the King Fahd Glorious Quran Printing Complex."

### Hadith — Sahih al-Bukhari & Sahih Muslim (downloaded on demand)
- **Source:** fawazahmed0/hadith-api, editions ara/eng-bukhari and ara/eng-muslim
- **License:** Unlicense (public domain dataset); classical texts are public domain
- **Attribution:** "Hadith data courtesy of the hadith-api project."

### Hadith Arabic book titles (bundled mapping)
- **Source:** AhmedBaset/hadith-json (github.com/AhmedBaset/hadith-json)
- **License:** MIT (data of classical public-domain texts)
- **Attribution:** "Arabic book titles courtesy of the hadith-json project."

### City database for the prayer-times picker (bundled)
- **Source:** GeoNames `cities15000` and `countryInfo` exports
  (https://www.geonames.org), every place with population ≥ 15,000, with
  IANA time zones. Built by `Tools/build_cities_db.py`; Arabic names come
  from GeoNames alternate names, overridden by the app's own curated
  spellings for the cities in `CityPreset.all`.
- **License:** Creative Commons Attribution 4.0 (CC BY 4.0).
- **File:** `Core/ContentDB/Sources/ContentDB/Resources/cities.sqlite`
  (copied to `android/app/src/main/assets/cities.sqlite`). Searched entirely
  on device — choosing a city never sends a query anywhere.
- **Attribution:** "City data © GeoNames (geonames.org), CC BY 4.0."
