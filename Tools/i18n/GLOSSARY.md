# Terminology glossary for Noor's interface languages

Machine translation gets ordinary words right and religious terms wrong.
A translator that renders "Maghrib" as "sunset" or "Athkar" as "memories"
produces text that is grammatical and useless. Every term below is fixed:
translate the sentence around it, never the term itself.

Most of these are Arabic loanwords already used by Muslims writing in each
language. Where a language genuinely prefers a native word (Turkish
"namaz", Indonesian "salat") that word is given and must be used.

Any language added later must extend this file BEFORE its strings are
written, and a native reviewer must check this table first — it is short,
and it is where the damage would be.

| en | ar | id | ms | tr | fr | ur | fa | bn | es |
|---|---|---|---|---|---|---|---|---|---|
| Prayer (salah) | صلاة | Salat | Solat | Namaz | Prière | نماز | نماز | নামাজ | Oración |
| Fajr | الفجر | Subuh | Subuh | İmsak | Fajr | فجر | صبح | ফজর | Fayr |
| Dhuhr | الظهر | Zuhur | Zohor | Öğle | Dhuhr | ظہر | ظهر | যোহর | Dhuhr |
| Asr | العصر | Asar | Asar | İkindi | Asr | عصر | عصر | আসর | Asr |
| Maghrib | المغرب | Magrib | Maghrib | Akşam | Maghrib | مغرب | مغرب | মাগরিব | Magrib |
| Isha | العشاء | Isya | Isyak | Yatsı | Icha | عشاء | عشاء | এশা | Isha |
| Sunrise | الشروق | Terbit | Syuruk | Güneş | Lever du soleil | طلوعِ آفتاب | طلوع آفتاب | সূর্যোদয় | Amanecer |
| Qibla | القبلة | Kiblat | Kiblat | Kıble | Qibla | قبلہ | قبله | কিবলা | Alquibla |
| Adhan | الأذان | Azan | Azan | Ezan | Adhan | اذان | اذان | আজান | Adán |
| Quran | القرآن | Al-Qur'an | Al-Quran | Kur'an | Coran | قرآن | قرآن | কুরআন | Corán |
| Surah | سورة | Surah | Surah | Sure | Sourate | سورہ | سوره | সূরা | Sura |
| Ayah | آية | Ayat | Ayat | Ayet | Verset | آیت | آیه | আয়াত | Aleya |
| Juz | جزء | Juz | Juzuk | Cüz | Juz | پارہ | جزء | পারা | Yuz |
| Mushaf | مصحف | Mushaf | Mushaf | Mushaf | Mushaf | مصحف | مصحف | মুসহাফ | Mushaf |
| Tajweed | تجويد | Tajwid | Tajwid | Tecvid | Tajwid | تجوید | تجوید | তাজবিদ | Taywid |
| Tafsir | تفسير | Tafsir | Tafsir | Tefsir | Tafsir | تفسیر | تفسیر | তাফসির | Tafsir |
| Hadith | حديث | Hadis | Hadis | Hadis | Hadith | حدیث | حدیث | হাদিস | Hadiz |
| Athkar | أذكار | Zikir | Zikir | Zikir | Adhkar | اذکار | اذکار | জিকির | Adhkar |
| Dua | دعاء | Doa | Doa | Dua | Invocation | دعا | دعا | দোয়া | Súplica |
| Tasbih | تسبيح | Tasbih | Tasbih | Tesbih | Tasbih | تسبیح | تسبیح | তাসবিহ | Tasbih |
| Khatmah | ختمة | Khatam | Khatam | Hatim | Khatma | ختم | ختم | খতম | Jatma |
| Hifz | حفظ | Hafalan | Hafalan | Ezber | Mémorisation | حفظ | حفظ | হিফজ | Memorización |
| Reciter | القارئ | Qari | Qari | Kari | Récitateur | قاری | قاری | ক্বারি | Recitador |
| Riwayah (Hafs/Warsh) | رواية | Riwayat | Riwayat | Rivayet | Riwaya | روایت | روایت | রেওয়ায়েত | Riwaya |
| Hijri | هجري | Hijriah | Hijrah | Hicri | Hégirien | ہجری | هجری | হিজরি | Hégira |
| Ramadan | رمضان | Ramadan | Ramadan | Ramazan | Ramadan | رمضان | رمضان | রমজান | Ramadán |
| Sunnah | سنة | Sunnah | Sunnah | Sünnet | Sunna | سنت | سنت | সুন্নাহ | Sunna |
| Nafl | نافلة | Sunnah | Sunat | Nafile | Surérogatoire | نفل | نافله | নফল | Nafl |
| Bismillah | بسملة | Basmalah | Basmalah | Besmele | Basmala | بسم اللہ | بسم‌الله | বিসমিল্লাহ | Basmala |
| Sajdah | سجدة | Sujud | Sujud | Secde | Prosternation | سجدہ | سجده | সিজদা | Sayda |

## Terms added while translating the eight new languages (2026-09-09)

Every term below came up in the 351 interface strings, was NOT in the table
above, and had to be settled by the translator rather than guessed at each
call site. They are recorded here so the two platforms cannot diverge and so
a reviewer has one table to check instead of 351 strings.

The `ar` column is the form the app's existing, reviewed Arabic strings use.
**Not every cell is equally trustworthy:** a cell is a translator's own
settled choice where that language's strings actually contained the term, and
otherwise it was filled in here for completeness, from the same conventions,
and has been checked by nobody. The per-language `Tools/i18n/review/<code>.md`
files say which terms each translator actually had to settle — those are the
cells with a reason behind them.

| en | ar | id | ms | tr | fr | ur | fa | bn | es |
|---|---|---|---|---|---|---|---|---|---|
| Matn (memorisation text) | متن | Matan | Matan | Metin | matn | متن (pl. متون) | متن | মতন | matn |
| Line of a matn (a verse of poetry, NOT a UI line) | بيت | Bait | Bait | Beyit | vers | شعر (pl. اشعار) | بیت | পঙক্তি | verso |
| Hizb | حزب | Hizb | Hizb | Hizip | hizb | حزب (quarters ارباع) | حزب | হিজব | hizb |
| Nisab | نصاب | Nisab | nisab | Nisap | nisab | نصاب | نصاب | নিসাব | nisab |
| Zakat | زكاة | Zakat | zakat | Zekât | zakat | زکوٰۃ | زکات | যাকাত | zakat |
| Wudu | وضوء | wudu | wuduk | Abdest | wudu | وضو | وضو | অজু | wudú |
| Masjid | مسجد | masjid | masjid | Cami | mosquée | مسجد | مسجد | মসজিদ | mezquita |
| Madhab (the Asr setting) | مذهب | mazhab | mazhab | mezhep | madhab | مسلک | مذهب | মাযহাব | madhab |
| Ruqyah | الرقية الشرعية | Ruqyah | Ruqyah | Rukye | Roqya | رقیہ شرعیہ | رقیهٔ شرعی | রুকইয়াহ | Ruqya |
| Names of Allah | أسماء الله الحسنى | Asmaul Husna | Asmaul Husna | Esmâü'l-Hüsnâ | Noms d'Allah | اسمائے حسنیٰ | اسماء الحسنی | আসমাউল হুসনা | Nombres de Allah |
| Tahajjud (the dark theme's name) | التهجد | Tahajud | Tahajud | Teheccüd | Tahajjud | تہجد | تهجد | তাহাজ্জুদ | Tahayyud |
| Hisn al-Muslim (the athkar book) | حصن المسلم | Hisnul Muslim | Hisnul Muslim | Hısnu'l-Müslim | Hisn al-Muslim | حصن المسلم | حصن المسلم | হিসনুল মুসলিম | Hisn al-Muslim |
| Kaaba | الكعبة | Kakbah | Kaabah | Kâbe | Kaaba | کعبہ | کعبه | কাবা | Kaaba |
| Izhar (tajweed rule) | إظهار | Izhar | izhar | İzhar | iẓhār | اظہار | اظهار | ইজহার | iẓhār |
| Pause marks (waqf) | علامات الوقف | Tanda waqaf | Tanda waqaf | Durak işaretleri | signes de pause | علاماتِ وقف | علامت‌های وقف | ওয়াকফের চিহ্ন | signos de pausa |
| Makki / Madani (surah class — NOT the Madinah print) | مكية / مدنية | Makkiyah / Madaniyah | Makkiyah / Madaniyah | Mekki / Medeni | Mecquoise / Médinoise | مکی / مدنی | مکی / مدنی | মক্কি / মাদানি | mecana / medinense |
| Hafs / Warsh | حفص / ورش | Hafs / Warsy | Hafs / Warsy | Hafs / Verş | Hafs / Warsh | حفص / ورش | حفص / ورش | হাফস / ওয়ারশ | Hafs / Warsh |
| Dhikr (singular of Athkar) | ذكر | Zikir | Zikir | Zikir | dhikr | ذکر | ذکر | জিকির | dhikr |
| Recitation (tilawah) | تلاوة | Tilawah | Tilawah | Tilavet | récitation | تلاوت | تلاوت | তিলাওয়াত | recitación |
| fi sabilillah | في سبيل الله | fi sabilillah | fi sabilillah | fî sebîlillâh | fi sabilillah | فی سبیل اللہ | فی سبیل‌الله | ফি সাবিলিল্লাহ | fi sabilillah |
| Sahih al-Bukhari | صحيح البخاري | Sahih Bukhari | Sahih Bukhari | Sahîh-i Buhârî | Sahih al-Bukhari | صحیح بخاری | صحیح بخاری | সহিহ বুখারি | Sahih al-Bujari |
| Muslim World League (calculation method) | رابطة العالم الإسلامي | Rabithah Alam Islami | Rabitah Alam Islami | Râbıtatü'l-Âlemi'l-İslâmî | Ligue islamique mondiale | رابطہ عالم اسلامی | رابطه جهانی اسلامی | মুসলিম ওয়ার্ল্ড লিগ | Liga Islámica Mundial |

### Renderings that look wrong out of context and are right

- **Turkish "Meal"** is the standard word for a *translation of the Quran*.
  "Çeviri" is a translation of anything; the Quran has a *meal*. It is used
  for "Translation", "Translation audio" and "Show translation".
- **Urdu "مسلک"** for the Asr *madhab* setting. "مذہب" reads as *religion* to
  an Urdu speaker; prayer apps say مسلک.
- **Indonesian "Ruqyah"**, never "rukyah" — which means moon sighting.
- **"Enable adhan"** (onboarding) requests notification permission and turns
  adhan notifications ON. It plays nothing. No language may render it as
  "play the adhan" (tr "Ezan bildirimlerini aç", not "Ezanı aç"; es "Activar
  avisos del adán", not "Activar el adán"; fa «فعال کردن اذان», not «پخش اذان»).
