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
  Al-Minshawi and the other ayah-by-ayah sets listed in `Reciter.swift`,
  including two Warsh 'an Nafi' readers (folders `warsh/warsh_ibrahim_aldosary_128kbps`,
  `warsh/warsh_yassin_al_jazaery_64kbps`; Hafs-numbered files).
- **Translated readings (optional, after each ayah):** English — Saheeh
  International read by Ibrahim Walk (`English/Sahih_Intnl_Ibrahim_Walk_192kbps`);
  Urdu — Shamshad Ali Khan (`translations/urdu_shamshad_ali_khan_46kbps`);
  Persian — Fooladvand read by Hedayatfar (`translations/Fooladvand_Hedayatfar_40Kbps`);
  Bosnian — Besim Korkut (`translations/besim_korkut_ajet_po_ajet`);
  Azerbaijani — Balayev (`translations/azerbaijani/balayev`). Same source
  and terms as the recitations.
- **Source:** https://everyayah.com (community-hosted recitation archive).
- **Access:** streamed at listen time, cached to the device Caches directory.
- **Attribution:** "Recitations courtesy of EveryAyah.com."
- **Note:** verify redistribution terms before App Store submission; audio is
  never bundled, only fetched by the user's explicit playback.

### Tafsir — Al-Muyassar, As-Sa'di, Ibn Kathir, At-Tabari, Al-Qurtubi (fetched, cached)
- **Source:** spa5k/tafsir_api CDN bundles
  (https://github.com/spa5k/tafsir_api), serving public tafsir text
  collections; fetched on demand (per ayah, or a whole surah for the Learn
  browser) and cached on device.
- **Attribution:** "Tafsir texts via the Tafsir API project."
- **Note:** verify per-tafsir redistribution terms before App Store release.

### Al-Muyassar fi al-Gharib — Quranic word meanings (fetched per surah, cached)
<!-- Shipped on BOTH platforms: iOS Modules/Tafsir, Android Tafsir.kt. -->
- **Source:** the same spa5k/tafsir_api CDN, edition slug
  `al-muyassar-fi-al-gharib` (الميسر في غريب القرآن). It backs the Learn hub's
  "Quranic word meanings" entry, through the same service, network path and
  cache as every other tafsir edition.
- **Provenance stated upstream:** the repository's `editions.json` records
  only `name`/`author_name` "Al-Muyassar fi Al-Gharib", `language: arabic` and
  `source: https://qul.tarteel.ai/resources/tafsir/519` (Tarteel's QUL
  resource library). The repository itself is **MIT** licensed, which covers
  its code and packaging; it states NO licence for the individual tafsir
  texts, and the linked QUL page carries no licence statement either
  (checked 2026-09-07). Same posture as the editions already shipped, but it
  is unresolved and should be settled before release.
- **Also added:** `asseraj-fi-bayan-gharib-alquran` ("Asseraj fi Bayan Gharib
  AlQuran", QUL resource 250), selectable in the ayah sheet. Despite the name,
  what the API serves under that slug is running commentary in the wording of
  as-Sa'di, not a word glossary (compared against 1:1, 2:255 and 18:9 on
  2026-09-07), so it is presented as a tafsir edition, not as غريب القرآن.

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

### Interface fonts (bundled — Settings → App font)
The five families the user can choose for the app's *interface* text. They
never touch Quran rendering, which stays on the verified Quran fonts above.

- **Files:** iOS `Core/DesignSystem/Sources/DesignSystem/Resources/UIFonts/`;
  Android `android/app/src/main/res/font/` (`readex_pro.ttf`, `cairo.ttf`,
  `ibm_plex_sans_arabic_{regular,medium,semibold,bold}.ttf`,
  `tajawal_{regular,medium,bold}.ttf`, `almarai_{regular,bold}.ttf` —
  Android's resource system only allows lowercase file names, so the
  files are renamed on disk; their contents and the fonts' internal
  Reserved Font Names are untouched).
- **Source:** google/fonts (`ofl/readexpro`, `ofl/ibmplexsansarabic`,
  `ofl/tajawal`, `ofl/almarai`, `ofl/cairo`), fetched from the `main` branch.
- **License:** SIL Open Font License 1.1 (all five).
- **Bundled unmodified.** The files are the upstream binaries byte for byte —
  not subset, not renamed, not re-generated. The OFL forbids a modified
  version from using a Reserved Font Name (IBM reserves "Plex"), so shipping
  the originals is what keeps the names usable. Readex Pro and Cairo are the
  upstream *variable* files; their weights are addressed through the fonts'
  own named instances (iOS) and `fontVariationSettings` (Android), which
  needs no change to the files.
- **Copyright / attribution:**
  - IBM Plex Sans Arabic — Copyright © 2017 IBM Corp. with Reserved Font
    Name "Plex". SIL OFL 1.1.
  - Tajawal — Copyright 2018 Boutros International. SIL OFL 1.1.
  - Almarai — Copyright 2019 The Almarai Project Authors. SIL OFL 1.1.
  - Readex Pro — Copyright 2018 The Readex Pro Project Authors. SIL OFL 1.1.
  - Cairo — Copyright 2009 The Cairo Project Authors. SIL OFL 1.1.

### Athkar — Hisn al-Muslim (bundled)
- **File:** `Modules/Athkar/Sources/Athkar/Resources/athkar.json`
  (132 categories, 267 adhkar).
- **Source text:** "Hisn al-Muslim" (حصن المسلم) by Sa'id ibn Ali ibn Wahf
  al-Qahtani — distributed by the author as a charitable endowment (waqf)
  for free use and reproduction. JSON transcription via
  github.com/rn0x/Adhkar-json (no explicit license; text itself is waqf).
- **Attribution:** "Adhkar from Hisn al-Muslim by Sa'id al-Qahtani."

### Athkar audio — Hisn al-Muslim read by Hamad Al-Duraihim (downloaded on demand)
- **Source:** the audio edition of Hisn al-Muslim narrated by Sheikh Hamad
  Al-Duraihim, published free for da'wah by IslamHouse and hisnmuslim.com,
  and mirrored per dhikr/chapter in github.com/rn0x/Adhkar-json (the same
  repository the athkar text comes from; its author states the files carry
  no licence restriction). Fetched one file at a time from
  `https://www.hisnmuslim.com/audio/ar/<file>` with the GitHub mirror as
  fallback; cached on device after first play.
- **License:** distributed free for use, as with the book (waqf); no formal
  open licence — same standing as the bundled text.
- **Attribution:** "Athkar audio read by Hamad Al-Duraihim, courtesy of IslamHouse / hisnmuslim.com."

### Tuhfat al-Atfal — tajweed matn (bundled)
- **Text:** تحفة الأطفال في تجويد القرآن by Sulayman ibn Husayn al-Jamzuri
  (سليمان الجمزوري), completed 1198 AH / c. 1784 CE. The poem itself is in
  the **public domain** — its author died more than two centuries ago, far
  beyond any copyright term anywhere.
- **Transcription source:** Arabic Wikisource, page "تحفة الأطفال"
  (https://ar.wikisource.org/wiki/%D8%AA%D8%AD%D9%81%D8%A9_%D8%A7%D9%84%D8%A3%D8%B7%D9%81%D8%A7%D9%84),
  page id 4754. Retrieved 2026-09-07; the page footer states
  **Creative Commons Attribution-ShareAlike 4.0** (verified on the live page:
  `creativecommons.org/licenses/by-sa/4.0/`).
- **File:** `Modules/Learn/Sources/Learn/Resources/matn-tuhfat-al-atfal.json`
  (Android ships a BYTE-IDENTICAL copy at
  `android/app/src/main/assets/matn-tuhfat-al-atfal.json` — copied, never
  re-fetched or re-parsed, so both platforms show the same text),
  built by `Tools/build_matn_tuhfa.py` — fetched through the MediaWiki parse
  API, never typed by hand. The only transformation is stripping ARABIC
  TATWEEL (U+0640, used as visual padding by the Word table the page was
  converted from) and collapsing whitespace; the script asserts per cell that
  the letter-and-haraka sequence is otherwise byte-identical to the source and
  fails loudly otherwise. 60 lines, 10 sections, fully vowelled (1805 harakat).
- **Attribution:** "Tuhfat al-Atfal by Sulayman al-Jamzuri (public domain);
  transcription from Arabic Wikisource, CC BY-SA 4.0."
- **Audio:** none. No recording of the matn ships until its licence is
  verified and recorded here (hard rule 5); the JSON keeps empty `audio` and
  `timings` slots for that day.

### Al-Bayquniyyah — hadith terminology matn (bundled)
- **Text:** المنظومة البيقونية (منظومة البيقوني في مصطلح الحديث). The
  Wikisource page names the author only as "البيقوني"; he is commonly
  identified as ʿUmar ibn Muhammad al-Bayquni, d. c. 1080 AH / 1669 CE (that
  identification is NOT from the source page). The poem itself is in the
  **public domain** — an 11th-century-Hijri work, far beyond any copyright
  term anywhere.
- **Transcription source:** Arabic Wikisource, page "منظومة البيقوني"
  (https://ar.wikisource.org/wiki/%D9%85%D9%86%D8%B8%D9%88%D9%85%D8%A9_%D8%A7%D9%84%D8%A8%D9%8A%D9%82%D9%88%D9%86%D9%8A),
  page id 8295, revision 435652. Retrieved 2026-09-07; the page footer states
  **Creative Commons Attribution-ShareAlike 4.0** (verified on the live page:
  `creativecommons.org/licenses/by-sa/4.0/`). NOTE the page name — the
  similarly named "المنظومة البيقونية" is a near-empty different page.
- **File:** `Modules/Learn/Sources/Learn/Resources/matn-bayquniyyah.json`
  (Android ships a BYTE-IDENTICAL copy at
  `android/app/src/main/assets/matn-bayquniyyah.json` — copied, never
  re-fetched or re-parsed),
  built by `Tools/build_matn_bayquniyyah.py` — fetched through the MediaWiki
  parse API, never typed by hand. The only transformation is stripping ARABIC
  TATWEEL (U+0640, visual padding for the {{أبيات}} grid; 275 occurrences) and
  collapsing whitespace (31 redundant spaces); the script asserts per
  hemistich that the letter-and-haraka sequence is otherwise identical to the
  source and fails loudly otherwise. 34 lines, fully vowelled (984 harakat).
- **Sections:** the source page carries NO headings; the three section titles
  in the JSON are the app's own editorial labels, flagged by
  `sections_editorial: true` and disclosed under the poem in the reader.
- **Attribution:** "Al-Bayquniyyah by ʿUmar al-Bayquni (public domain);
  transcription from Arabic Wikisource, CC BY-SA 4.0."
- **Audio:** none, as with Tuhfat al-Atfal (hard rule 5).

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
