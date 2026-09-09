# Indonesian (`id`) review notes

Glossary terms from `GLOSSARY.md` were used verbatim (Salat, Subuh, Zuhur,
Asar, Magrib, Isya, Terbit, Kiblat, Azan, Al-Qur'an, Surah, Ayat, Juz,
Mushaf, Tajwid, Tafsir, Hadis, Zikir, Doa, Tasbih, Khatam, Hafalan, Qari,
Riwayat, Hijriah, Sunnah, Basmalah, Sujud).

## Glossary additions

| en | id | note |
|---|---|---|
| Recitation | Tilawah | the audio recitation of the Quran; "bacaan" felt too generic next to "Qari" |
| Matn (memorisation text) | Matan | plural متون rendered "matan hafalan" |
| Makki / Madani (surah type) | Makkiyah / Madaniyah | the ar source (مكية/مدنية) confirms this is surah classification, not the Madinah print |
| Hizb | Hizb | kept as-is (not in glossary); "Awal hizb", "Seperempat hizb" |
| Line (of a poem/matn) | Bait | matches ar بيت — a verse of poetry, not a UI line |
| Nisab | Nisab | |
| Ruqyah | Ruqyah | deliberately NOT "rukyah/rukyat", which means moon sighting |
| Names of Allah | Asmaul Husna | |
| Nawafil / voluntary prayers | Salat sunnah | follows the glossary's Nafl → "Sunnah" |
| Pause marks | Tanda waqaf | |
| Bookmark | Markah | Apple's Indonesian term (Safari) |
| Settings | Setelan | Apple's Indonesian term |
| Hisn al-Muslim | Hisnul Muslim | standard Indonesian spelling |
| Kaaba | Kakbah | KBBI spelling |
| Tahajjud | Tahajud | KBBI spelling |
| Shafi'i | Syafi'i | Indonesian transliteration |

## Low confidence

- `After prayer by` → "Setelah salat" — the English "by" implies an offset value follows (e.g. "After prayer by | 15 min"). If it is a picker row with the minutes to its right, "Setelah salat" reads fine; if it stands alone it may need "Selang setelah salat".
- `Bell` → "Lonceng" — a notification-sound choice. ar used تنبيه ("alert"). If the row lists sound files, "Lonceng" is right; if it means "alert style", "Bel"/"Nada" would be better.
- `Off` → "Nonaktif" — ar used بدون ("none"). In a sound picker "Tidak ada" may read better.
- `Continuous` → "Berkelanjutan" — playback mode. "Tanpa henti" or "Terus-menerus" are alternatives; needs the screen to judge.
- `Go` → "Buka" — bare button next to a "go to ayah" field. Could be "Buka", "Ke sana", or "Lanjut".
- `Follow-along audio` → "Audio ikuti bacaan" — the word-tracking audio feature. Possibly better as "Audio kata per kata" to match `Word by word`.
- `Word-tracking surah files` → "Berkas surah untuk mode kata per kata" — long; may overflow a storage-row label.
- `Egyptian General Authority` → "Otoritas Umum Mesir" — prayer calculation method. Many Indonesian apps leave these method names untranslated; check the house style for the whole method list.
- `Moonsighting Committee` → "Komite Rukyat Hilal" — same question; it is also a proper organisation name that could stay English.
- `Muslim World League` → "Liga Muslim Dunia" — Indonesian Muslims often say "Rabithah Alam Islami".
- `Hizb quarters` → "Seperempat hizb" — English is plural (the quarter marks); "Rubu' hizb" is the traditional term. Which reads better in a jump list?
- `Memorise` (167) → "Hafal" — a short tab/button label; imperative "Hafalkan" or noun "Hafalan" may fit better. Note 130 uses "Mode hafalan" and 287 "Mulai menghafal".
- `Count` → "Jumlah" — tasbih counter label; "Hitungan" is the alternative.
- `Chapters` → "Bab" — hadith book chapters (ar أبواب). Confirm it is not "Kitab".
- `Mushaf (continuous)` → "Mushaf (bersambung)" vs `Flowing text` → "Teks mengalir" — these two reading modes should be clearly distinct on screen; check they do not read the same.
- `Colour key` → "Keterangan warna" — legend for the tajweed colours; "Kunci warna" is a literal alternative but less idiomatic.
- `Section` → "Bagian" — could be a hadith "bab" depending on the screen.
- `That's not it — here's a new one.` → "Bukan itu — ini soal yang baru." — the ar makes clear "one" = a new *question*; confirm the kids quiz wording.
- `Tap a sound to hear it` → "Ketuk salah satu bunyi untuk mendengarnya" — "sound" here is a tajweed letter-sound sample; "bunyi" vs "suara".
- `Reference` → "Rujukan" — hadith grading/citation row; "Referensi" is also common.
- `%@ min` / `%lld min` → "%@ mnt" — used Apple's abbreviation "mnt". If the row has space, spell "menit".
- `Well done!` → "Bagus sekali!" — kids mode praise; "Hebat!" may suit children better.
- `Assalamualaikum` (33) — written closed per KBBI; some publications prefer "Assalamu'alaikum".
- `Zakat due (2.5%)` → "Zakat yang wajib (2,5%)" — decimal comma used per Indonesian convention; confirm the app formats the computed number the same way.
- `COMING UP IN ISLAMIC HISTORY` → "MENDATANG DALAM SEJARAH ISLAM" — all-caps section header; may be long. "SEJARAH ISLAM MENDATANG" is shorter but reads oddly.
- `Anda` was used throughout for "you"/"your". If the house voice is warmer/informal, these should switch to "kamu" (mainly in Kids mode strings 13, 34, 136, 341).

## Onboarding

- `Quran, prayer times, and athkar — private and free forever` → "Al-Qur'an, jadwal salat, dan zikir — privat dan gratis selamanya" — "privat" is the plain rendering of "private"; if the intent is specifically "no data leaves your phone", "tanpa pelacakan" (as used in the About string) may land better with Indonesian users. Also the longest onboarding line — check it does not wrap awkwardly on a small phone.
- `Your city for prayer times` → "Kota Anda untuk jadwal salat" — literal. If this is a step title above a search field, "Pilih kota Anda" reads more like a step.
- `A beautiful adhan at every prayer. You can change or silence it anytime.` → "Azan yang merdu di setiap waktu salat. Anda bisa menggantinya atau membisukannya kapan saja." — "membisukan" is the standard iOS term for "silence/mute"; "mematikan" is blunter but shorter.
- `Maybe later` → "Nanti saja" — chosen for length (a secondary button). "Mungkin nanti" is the literal form but is longer.
- `Continue` → "Lanjutkan" — Apple's Indonesian uses "Lanjutkan"; "Lanjut" is shorter if the button is tight.
- Formality: onboarding uses "Anda" to match the rest of the app. Flag if the onboarding voice should be warmer.
- `Enable adhan` → "Aktifkan azan" — **DO NOT change this toward playback wording.** The button requests notification permission and switches adhan notifications ON; it plays no audio. "Aktifkan" = turn on, which is correct. Reject any "fix" to "Putar azan", "Dengarkan azan", or "Mainkan azan". If the reviewer wants it more explicit and the button has room, the only acceptable alternative is "Aktifkan notifikasi azan". The body text above it ("Azan yang merdu di setiap waktu salat…") describes when the adhan will sound, which can pull a translator toward playback verbs — "menggantinya"/"membisukannya" there refer to changing and silencing the notification sound, not to a player.
