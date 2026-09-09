# Malay (ms) — reviewer notes

Register: Bahasa Melayu Malaysia, Apple/iOS Malay UI conventions
("Selesai", "Batal", "Tetapan", "Perihal", "Penampilan", "apl", "fon",
"ketik" for tap, "muat turun", "luar talian"). Glossary terms used
verbatim (Solat, Subuh, Zohor, Asar, Maghrib, Isyak, Syuruk, Juzuk,
Kiblat, Azan, Zikir, Hadis, Tajwid, Sunat …) — no Indonesian drift.

## Glossary additions

| en | ms | note |
|---|---|---|
| Hizb | Hizb | kept as-is; "hizib" also seen in MY publishing — confirm preference |
| Matn / memorisation texts | Matan | standard MY term for a memorised didactic text |
| Line (of a matn poem) | Bait | ar بيت = a verse line of poetry, not a UI "line" |
| Makki / Madani (surah type) | Makkiyah / Madaniyah | surah revelation class; "Madani" kept only in "cetakan Madani" (the print) |
| Wudu | wuduk | MY spelling (not Indonesian "wudu") |
| Names of Allah | Asmaul Husna | ar أسماء الله الحسنى |
| Pause marks (waqf) | Tanda waqaf | JAKIM-style |
| Izhar | izhar | left lowercase inside parentheses, as in en |
| Tahajjud | Tahajud | MY spelling of the dark theme name |
| Hisn al-Muslim | Hisnul Muslim | title as commonly printed in Malaysia |
| Ruqyah | Ruqyah | kept |
| Nisab / zakat | nisab / zakat | kept |
| Kaaba | Kaabah | MY spelling |
| Muslim World League | Rabitah Alam Islami | MY/JAKIM name of the calculation authority |
| Reciter | Qari | glossary; used for both "Reciter" and "Search reciters" |

## Low confidence

- `Bookmark` / `Bookmarks` → "Penanda buku" for both. Malay has no plural
  form; if the singular row is a button next to the plural list title they
  will look identical on screen.
- `Result` → "Keputusan" (zakat outcome) but `Results` → "Hasil" (search).
  Deliberately different; unify if they share a screen.
- `Edit plan` / `Start plan` / `Stop plan` / `KHATMAH PLAN` → "pelan".
  Malaysian Islamic apps often say "jadual khatam" (schedule). "Pelan" reads
  slightly telco-ish; reviewer's call.
- `Off` → "Tiada" (adhan-sound picker; ar بدون = "none"). "Mati" would be the
  literal toggle word — depends whether this row is a sound choice or a switch.
- `Bearing from true north` → "Arah dari utara benar". "Bearing" is often left
  untranslated in MY navigation UI; "bearing" may be clearer to users.
- `Reader options` → "Pilihan pembaca". Ambiguous: "pembaca" can read as the
  human reciter. "Pilihan paparan bacaan" is unambiguous but long.
- `Follow-along audio` / `Word-tracking surah files` → "Audio ikut perkataan" /
  "Fail surah untuk ikut perkataan". Coined phrasing; no settled MY term.
- `Moonsighting Committee` left in English (Moonsighting Committee Worldwide is
  a proper name). "Jawatankuasa Rukyah Hilal" is the descriptive alternative.
- `Egyptian General Authority` → "Pihak Berkuasa Am Mesir". This is the Egyptian
  General Authority of Survey; MY prayer apps usually leave it in English.
- `Adhan (melodic)` → "Azan (bertarannum)". "Bertarannum" is the correct MY
  religious term but is longer than the other picker rows (overflow risk).
- `Live countdown` / `Live countdown to the next prayer` → "Kira detik langsung".
  Long for a settings row label; "Kira detik" alone may be enough.
- `Memorize a range` → "Hafal satu bahagian" (ar حفظ مقطع = a passage). "Julat"
  is the literal but mathematical-sounding option.
- `Plays straight through` → "Membaca terus tanpa ulangan" (from the ar, which
  spells out "the whole surah without repetition").
- `%lld lines` / `Line %lld` / `No matching lines` → "bait". Correct for the
  memorisation poems; wrong if any of these strings is ever reused for mushaf
  lines (where it would be "baris").
- `Section` → "Bahagian" and `Chapters` → "Bab"; check against the hadith
  library hierarchy (kitab/bab) so the two levels do not collide.
- `Classical poems …` → "Syair klasik". "Matan" is used for the noun elsewhere;
  "syair" chosen here because the sentence describes the poems, not the corpus.
- `As-salamu alaykum` → "Assalamualaikum" (single word, standard MY greeting).
- `Well done!` → "Syabas!" — kids screen; "Bagus!" is gentler for young children.
- `Grown-ups` / `Ask a grown-up` → "Orang dewasa" / "Tanya orang dewasa".
  MY parents' UI often says "ibu bapa"; depends on the intended gatekeeper.
- `System` (language picker) → "Bahasa sistem", following the ar (لغة النظام)
  rather than the bare en "System".
- `Your choice is remembered, and is the same one the ayah sheet uses.` →
  "kad ayat", from the ar (بطاقة تفسير الآية). Verify the UI actually shows a card.
- `Send the app to family and friends …` → "pautan gedung aplikasi".
  "Gedung aplikasi" vs "kedai aplikasi" both circulate in MY; brand names
  App Store / Google Play are untouched elsewhere.
- `Zakat due (2.5%)` → decimal kept as "2.5%"; Malaysia uses a decimal point,
  but confirm the app is not localising the numeral separately.
- `Storage` → "Storan" (Apple MY). "Penyimpanan" is the more common everyday word.
- `Turn left` / `Turn right` (qibla) → "Pusing ke kiri/kanan"; these must not be
  mirrored under RTL — they describe physical rotation.

## Onboarding

Nine first-run strings, in `translations/ms.onboarding.json`. `Language` repeats
the value already used in `ms.json` ("Bahasa").

- `Quran, prayer times, and athkar — private and free forever` →
  "Al-Quran, waktu solat dan zikir — peribadi dan percuma selamanya". "Peribadi"
  is the literal rendering of "private"; for privacy-as-a-promise MY marketing
  often says "privasi terjaga" — reads warmer but is two words longer on a line
  that must not wrap.
- `App language` → "Bahasa apl". "Apl" is Apple MY for "app" but is still
  uncommon in everyday MY speech; "Bahasa aplikasi" is safer for a cold first
  screen, at the cost of length.
- `Maybe later` → "Nanti dulu" (short, natural spoken MY). The more formal
  "Kemudian" or "Lain kali" are alternatives if the button reads too casual.
- `Enable adhan` → "Hidupkan azan". "Aktifkan azan" is the more formal register;
  "hidupkan" matches the toggle wording used elsewhere in the app.
- `A beautiful adhan at every prayer…` → "Azan yang merdu pada setiap waktu
  solat…". "Merdu" (melodious) is the idiomatic MY compliment for a voice;
  a literal "indah/cantik" would sound wrong applied to the adhan.
- `Welcome to Noor` → "Selamat datang ke Noor". "ke" vs "di" — "ke" is correct
  for arriving at an app/place; confirm it reads well above the logo.
- **`Enable adhan` turns adhan NOTIFICATIONS on** (it requests notification
  permission and flips the setting) — it does not play anything. "Hidupkan azan"
  is deliberate and correct: do NOT "fix" it to "Mainkan azan" / "Main azan",
  which would promise playback. Same caution for the body text above it:
  "menukar atau menyenyapkannya" = change or silence the notification sound,
  not pause a player.
