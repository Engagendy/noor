# Afaan Oromoo (om) — reviewer notes

**Read this before `translations/om.json`.** This is the least-corroborated
language in the directory and the notes below say so term by term. Qubee
Latin, LTR — no script, font or direction work was needed; everything
uncertain here is vocabulary.

Conventions applied throughout: doubled vowels for length (`Qur'aana`,
`Tafsiira`), doubled consonants for gemination (`Hisnul Musliim`,
`Tahajjuda`), and the ASCII apostrophe `'` for the glottal stop — never a
typographic `’`, so the files stay greppable and the Android
`strings.xml` escaper sees one consistent character (`Du'aa'ii`,
`Ishaa'ii`, `Mus'hafa`, `Qaraa'aa`).

---

## 1. Terminology: what was corroborated and what was not

I could find published Afaan Oromoo Islamic material for roughly half of the
glossary. The rest are my own Qubee transliterations — formed consistently,
attested nowhere I could reach. **The unverified list is long on purpose.**

### 1a. Corroborated in published Afaan Oromoo Islamic sources

Attested in running Oromo prose on learningislam.com/om, islamhouse.com/om,
byenah.com/or, the Afaan Oromoo *Hisnul Muslim* and *Hiikkaa Qur'aanaa*
translations, and Sh. Mohammed Rashaad's tafsir material.

| term | om | where it was seen |
|---|---|---|
| Prayer (salah) | Salaata | "salaanni guyyaatti yeroo shan salaatama" |
| Fajr | Fajrii | listed with the other four daily prayers |
| Dhuhr | Zuhrii | same list |
| Asr | Asrii | same list |
| Maghrib | Magriba | same list (also spelled *magriibaa* when suffixed) |
| Isha | Ishaa'ii | same list |
| Qibla | Qiblaa | "fuula gara qiblaatti garagalfachuu" — condition of salah |
| Adhan | Azaana | "azaanni waggaa tokkoffaa hijraa booda seeraa'e" |
| Quran | Qur'aana | universal |
| Surah | Suuraa | "suuraa 114" |
| Juz | Juzii | "juzii 30" |
| Mushaf | Mus'hafa | "walitti qabama mus'hafaa" |
| Tajweed | Tajwiida | "tajwiidaan sirreessanii qara'uu" |
| Tafsir | Tafsiira | title of several published works |
| Hadith | Hadiisa | "Hadiissa Afaan Oromoo" |
| Athkar / Dhikr | Zikrii | "zikriin ganamaa fi galgalaa" |
| Dua | Du'aa'ii | "Zikrii fi Du'aa'ii" |
| Hifz | Hifzii | "seenaa hifzii", "warra hifzii qaban" |
| Recitation | Qaraatii | "qaraatii qur'aanaa", "naamusa qaraatii" |
| Translation | Hiikkaa | "Hiikkaa Qur'aana Afaan Oromoo" |
| Masjid | Masjiida | "salaata masjiidaa dhiisuu" |
| Wudu | Wuduu'a | "akkaataa wuduu'aa", "waan wuduu'a balleessu" |
| Zakat | Zakaa | "waa'ee soomanaa fi zakaa" |
| Ramadan | Ramadaana | "soomana Ramadaanaa" |
| Hisn al-Muslim | Hisnul Musliim | named as the source of the Oromo athkar book |
| Uthmani (script) | Usmaanii | "barruu Arabiffaa (Usmaanii)" |
| to memorise | haffazuu (`haffazi`, `haffazan`) | "namni hundi ayaata dhagahe ni haffaza" |
| Allah | Rabbi / Rabbiin | universal in Oromo Islamic prose |
| fasting | soomana | universal |

**Partially corroborated — `Qaraa'aa` (Reciter).** I found the *plural* in
print ("qaraa'ota beekamoo", and the classical "qurraa'onni" for the reciters
killed at Yamamah). The singular `Qaraa'aa` is my back-formation from it. The
plural forms used in the strings (`Qaraa'ota barbaadi`) are the attested ones;
the bare singular on the "Reciter" row is not. If a reviewer changes one,
change both.

### 1b. NOT corroborated — my own transliteration, checked by nobody

Every one of these follows the same Qubee rules and is *plausible*. None of
them is evidence. Flagged individually because a reviewer should be able to
strike through the list as they go.

| term | om as shipped | risk |
|---|---|---|
| Khatmah | Khatmaa | **High.** The whole khatmah feature (12 strings) rides on it. Oromo speakers may simply say *Qur'aana xumuruu* ("finishing the Quran") and not use a loan at all. |
| Line of a matn (بيت) | Beyitii | **High.** Six strings. See §3. |
| Matn | Matnii | **High.** No Oromo attestation for the technical sense. |
| Hizb | Hizbii | Medium. Also note *hizbii* is the ordinary Oromo word for a political party; in a Quran context this is probably still fine, but it is worth one native glance. |
| Hizb quarters | Kurmaana hizbii | Medium. *Kurmaana* = quarter, native and clear, but the set phrase is unattested. |
| Nisab | Nisaaba | Medium. |
| Madhab | Mazhaba | Medium. |
| Ruqyah | Ruqyaa | Medium. |
| Tasbih | Tasbiiha | Medium. |
| Nafl / Nawafil | Naafilaa | Medium. Used for both "Nawafil" and "a voluntary fasting day". |
| Sajdah | Sujuuda | Low–medium. |
| Tahajjud | Tahajjuda | Medium — it is the dark theme's name, so it is visible in Settings. |
| Kaaba | Ka'abaa | Medium. Appears on the qibla screen. |
| Izhar | Izhaara | Medium. Tajweed rule name. |
| Pause marks (waqf) | Mallattoolee waqfii | Medium. *Waqfii* itself unattested in Oromo. |
| Makki / Madani | Makkii / Madanii | Medium. |
| Riwayah | Riwaayaa | Medium. |
| Hijri | Hijrii | Medium. The *event* is attested in Oromo as **hijraa** ("waggaa 12ffaa hijraa"); the calendar adjective *hijrii* is my extension of it. |
| Bismillah | Bismillaah | Low risk as a phrase, unchecked as an orthography. |
| fi sabilillah | fii sabiilillaah | Medium. |
| Sahih al-Bukhari | Sahiih al-Bukhaarii | Medium — transliteration only. |
| The Two Sahihs | Sahiihota Lamaan | Medium. Native plural on a loan stem. |
| The Forty Collections | Walitti Qabamoota Afurtamaa | **High.** Clumsy; a native reviewer will probably have a shorter idiom. |
| An-Nawawi's Forty | Afurtama An-Nawawii | Medium. |
| Forty Hadith Qudsi | Hadiisa Qudsii Afurtama | Medium. |
| Jumu'ah Mubarakah | Jum'aa Mubaarakaa | Medium. This is a *greeting*; greetings are exactly where a calque reads wrong. |
| the white days | guyyoota adii | **High.** Every other language in this file reached for the Arabic *ayyām al-bīḍ*; I used the literal Oromo. If Oromo speakers say *ayyaamul biid*, change it. |
| Names of Allah | Maqaalee Rabbii | Medium. See §2. |
| Muslim World League | Waldaa Islaamaa Addunyaa | **High — invented.** No established Oromo rendering found. See §4. |
| Sunrise | Bahiinsa aduu | **High as a timetable row.** See §2. |

**Count: 30 corroborated (one of them only partially), 29 not.**

---

## 2. Competing forms, and why I chose the one I did

Where real usage has two live options I recorded both here rather than
silently picking.

1. **Ayah — `Aayata` (chosen) vs `Keeyyata`.** Both are attested in Oromo
   Quran material: "ayaata ayaataan" and "keeyyata Qur'aanaa". *Keeyyata* is
   the native word (also = "article/clause"); *Aayata* is the Arabic loan.
   I chose **Aayata** because it pluralises cleanly (`Aayatoota`), because it
   cannot be confused with a legal clause, and because the app uses "Ayah" as
   a hard navigation unit (`Ayah %lld`, `Surah %@ · Ayah %@`) where a loan
   reads as a label. A reviewer who prefers *Keeyyata* must change ~20 keys.
2. **Recitation — `Qaraatii` (chosen) vs `Tilaawaa`.** Both attested;
   *qaraatii* appeared in the more instructional sources ("seeraafii naamusa
   qaraatii qur'aanaa"), *tilaawaa* in app marketing copy. Chose *Qaraatii*
   as the everyday word. It is also used for "Play recitation", "Downloading
   recitation…", "with %@'s recitation".
3. **Fajr — `Fajrii` (chosen) vs `Subhii`.** The Oromo sources list the
   prayer as *"subhii (fajrii)"*, i.e. **Subhii may be the commoner spoken
   name.** I kept *Fajrii* so the row matches the Latin key and the other nine
   languages, and because the app has no separate imsak row for it to collide
   with. If an Oromo reviewer says people say *Subhii*, that is a one-key fix.
4. **Sunrise — `Bahiinsa aduu` (chosen) vs `Shuruuqa`.** Native descriptive
   phrase vs the Arabic loan. I chose the native one because it is certainly
   understood; but as a *prayer-timetable row* sitting between Fajrii and
   Zuhrii, the Arabic *Shuruuqa* may be what a mosque timetable actually
   prints, and my phrase is long for that column. **Most likely single
   change in the whole file.**
5. **Names of Allah — `Maqaalee Rabbii` (chosen) vs `Asmaa'ul Husnaa`.** The
   Arabic title is what the other languages use. I chose the Oromo calque
   because it is transparent and because "Among the Names of Allah" is a
   sentence fragment where a title reads badly. Either is defensible.
6. **Download — `Buufadhu` (chosen) vs `Naqadhu`.** The ELRC/ICT Development
   Office Oromo glossary gives *naqadhu*; wider modern usage (and Mozilla-style
   Oromo localisation) uses *buufadhu*. Chose **buufadhu** and applied it
   consistently across ~25 keys (`buufame`, `buufamaa jira`, `buufannaa`).
7. **Share — `Qoodi` (chosen) vs `Raabsi` / `Yagutoomsi`.** The ICT glossary
   offers *yagutoomsi*/*raabsi*; both read as *broadcast/distribute*. *Qooduu*
   is the ordinary "to share" and is what social apps use.
8. **Allah — `Rabbi` (chosen) vs `Allaah`.** Oromo Islamic prose overwhelmingly
   writes *Rabbi/Rabbiin*, so that is what the two du'a strings use
   ("Rabbiin salaata kee haa qeebalu"). *Allaah* is kept only inside the fixed
   phrase "Maashaa Allaah".
9. **Notification vs Reminder — `Beeksisa` vs `Yaadachiisa`.** The ICT glossary
   gives *yaadachiisa* for "notification". I split them: **Beeksisa** =
   notification (system-level), **Yaadachiisa** = reminder (the athkar/fasting
   nudges). The app distinguishes them and Oromo can too. Worth confirming.
10. **Settings — `Qindaa'ina`.** ELRC-confirmed. Note it also covers
    "configuration", so it is slightly broad, but it is the standard.
11. **Mushaf — `Mus'hafa` (chosen) vs `Mushaafa`.** The apostrophe keeps the
    س–ح boundary audible rather than letting it read as a "sh" digraph. Qubee
    would otherwise pronounce `mush-` wrongly. This is a deliberate spelling.

---

## 3. Least-confident strings

- **`Line %lld`, `Mark this line`, `Go to marked line`, `No matching lines`,
  `%lld lines`, `%lld of %lld lines` → `Beyitii`.** Same trap flagged by all
  eight earlier languages: Arabic بيت means *a verse of a memorisation poem*,
  not a row of text. I followed that reading. But unlike Turkish *beyit* or
  Persian *بیت*, **Oromo has no attested literary loan `beyitii`** — I coined
  it. The honest alternative is the native `sarara` (line/row), which is
  *wrong for the concept* but right for the word. If a reviewer rejects
  *beyitii*, the next-best is probably `walaloo` (poem) → "line of a poem"
  spelled out. Six strings move together.
- **`After prayer by` → "Salaata booda".** English is a dangling fragment
  completed by a minutes picker (flagged by seven of eight earlier
  translators). Oromo is SOV, so this cannot end a clause at all. Reads fine
  only if the control renders "Salaata booda  10 daqiiqaa". Otherwise use
  "Salaata booda (daqiiqaa)".
- **`Finish the Quran in` → "Qur'aana xumuruuf yeroo"** ("time to finish the
  Quran"). Recast as a noun label for the same SOV reason. Check against the
  actual picker.
- **`Play` → "Taphachiisi"; `Pause` → "Yeroof dhaabi"; `Stop` → "Dhaabi".**
  **The weakest cluster of non-religious strings in the file.** Oromo has no
  settled media-player vocabulary that I could verify. *Taphachiisi* is
  literally "make it play" (from *taphachuu*, to play a game) and may read as
  gaming rather than audio; *dhageessisi* ("make it be heard") is the other
  candidate and might be better for recitation specifically. "Pause" at two
  words ("Yeroof dhaabi" = stop for a time) next to one-word "Dhaabi" is also
  a layout risk on the player bar. Six strings: `Play`, `Play chapter`,
  `Play from here`, `Play recitation`, `Play surah`, `Pause`, `Pause chapter`,
  `Stop`, plus `Playback mode` / `Playback controls…` / `Plays straight
  through` which use *taphaa*.
- **`Could not play this recording` → "Waraabbiin kun hin taphanne"** — same
  verb, intransitive. If *taphachiisi* is rejected this changes too.
- **`Bell` → "Bilbila".** In Oromo *bilbila* is overwhelmingly *telephone*;
  the bell sense exists but is secondary. This is a notification-sound option
  sitting next to "Callisaa" (Silent) and "Azaana", so the phone reading
  would be actively confusing. A reviewer may want "Sagalee bilbilaa" or a
  different word entirely. **Likely wrong.**
- **`Live countdown` → "Lakkoofsa kallattii".** Literally "direct/live
  count". *Kallattii* is doing a lot of work (it also means "direction", and
  I use it that way in `Bearing from true north`). The fuller "lakkoofsa gadi
  bu'aa kallattii" was too long for the row. Both senses of *kallattii* now
  appear in the same catalog — flagged deliberately.
- **`Bearing from true north` → "Kaaba dhugaa irraa kallattii".** Compass
  jargon; unverified that *kaaba* (north) does not collide oddly with
  *Ka'abaa* (the Kaaba) on the same screen. They are different words and
  spelled differently, but they are one letter apart on the qibla screen.
  **Worth one look at that screen specifically.**
- **`Reset` → "Duraatti deebisi"** ("return it to the former state"). No
  settled Oromo UI word; *haaromsi* would read as "refresh".
- **`Noor — version %@` → "Noor — vershinii %@".** Bare transliteration.
  *Fooyya'iinsa* (the ICT glossary's word) means "improvement/revision" and
  could be misread as an update prompt. Neither is good.
- **`Done` → "Xumuri"** (imperative "finish"). If the button confirms a
  completed state rather than commanding one, "Xumurame" is better.
- **`Chapters` → "Boqonnaalee"** and **`Section` → "Kutaa"** — both ambiguous
  in the English too (flagged by every earlier language). *Boqonnaa* is used
  for hadith-book chapters (الأبواب); it is also used for `Play chapter` /
  `Pause chapter`, which are **audio** chapters. Same word, two screens.
- **`Result` / `Results` → "Bu'aa" / "Bu'aawwan".** Oromo tolerates the bare
  form for both; the plural is used only where English is explicitly plural.
- **`Grown-ups` → "Namoota guddaa"** (kids-mode section header). The Arabic
  original is لولي الأمر (guardian). "Warra" (parents) may fit the screen
  better; depends whether it heads a settings group or addresses the child.
- **`Ask a grown-up` → "Nama guddaa gaafadhu"** — fine, but it is the kids'
  lock prompt, so it should sound gentle. Unverified register.
- **`Egyptian General Authority` → "Abbaa Taayitaa Waliigalaa Gibxii".**
  *Gibxii* is the standard Oromo for Egypt. The organisation's full name is
  the Egyptian General Authority of Survey; no Oromo rendering exists.
- **`Moonsighting Committee` → "Koree Ilaalcha Ji'aa".** Calque. Prayer apps
  often leave this in English.
- **`ISNA (North America)` → "ISNA (Amerikaa Kaabaa)"**, `University of
  Karachi` → "Yunivarsiitii Karaachii" — transliterations, unverified.
- **`Recited by %@` → "Kan qara'e: %@".** Recast as "the one who recited:",
  because Oromo would want a case suffix glued to the reciter's name and a
  format string cannot supply one. Same source-side problem the Spanish and
  Turkish reviewers raised about `It's time for %@`.
- **`It's time for %@` → "Yeroon %@ ga'eera"** ("the time of %@ has
  arrived"). The placeholder sits mid-sentence with no suffix, which works
  *only* if prayer names are passed bare ("Asrii", "Magriba"). Confirm.
- **`Near %@` → "%@ bira"** and **`in %@` → "%@ keessatti"** — postpositions,
  so the placeholder leads. Safe in Oromo, but note these now start with the
  variable, unlike English.
- **`Searching %@ of %@ surahs you have downloaded`** — I reordered to
  "Suuraalee ati buufatte %2$@ keessaa %1$@ barbaadamaa jira" because Oromo
  needs the total before the partitive *keessaa*. **Positional specifiers,
  reversed.** Same for `Showing %lld of %lld — open the text to see the rest`.
  Verify the argument order is (shown, total).
- **`Zakat due (2.5%)` → "Zakaa kaffalamu (2.5%)"** — the bare `%` is left
  exactly as the English has it. It is an English-side bug (five earlier
  translators flagged it); not fixed here.
- **`a white day (%lldh)` → "guyyaa adii (%lldh)"** — the `h` after `%lld` is
  a literal, not a specifier; preserved.
- **`Unlock` → "Bani"** (open). Oromo has no separate "unlock"; the kids-mode
  lock context has to carry it.
- **`Off` → "Cufaa"** (closed/shut). A toggle state label; if it sits next to
  an "On" that is not in this catalog, the pair may not read as a pair.

---

## 4. Looks wrong out of context, is right

- **`Zikrii` is used for both "Athkar" (plural, the feature) and "Dhikr"
  (singular).** Oromo does not distinguish them here and the Oromo sources
  use *zikrii* for both. "MORNING ATHKAR" → "ZIKRII GANAMAA" is correct even
  though it looks singular.
- **`Hiikkaa` for "Translation" everywhere**, including `Translation audio`
  and `Show translation`. This is the established word for a Quran
  translation in Oromo (it is the title of every published one) and is also
  the ordinary word for translation, so unlike Turkish *meal* there is no
  second term to keep straight.
- **`Interneetii malee` for "offline"** — literally "without internet". There
  is no Oromo loan for *offline* that I would trust, and the phrase is
  unambiguous. It is *long*: "Download for offline" becomes "Interneetii
  malee fayyadamuuf buufadhu" (38 chars vs 20). Appears in 8 strings; see §5.
- **`Aayata hundaa` for "Each ayah"** rather than the fuller *aayata tokkoon
  tokkoon isaa*. The long form is more precise Oromo ("each and every ayah")
  but was 2.6× the English and these are picker rows. The short form is
  correct, just less emphatic.
- **`Boru soomana sunnaa`** for "Sunnah fasting tomorrow" — verbless, as
  Oromo notification headlines are.

---

## 5. Length outliers

Oromo runs long: agglutinative suffixes plus the *interneetii malee* phrase.
Nothing was checked against a real screen. Worst offenders, longest-relative
first:

| key | en | om | ratio |
|---|---|---|---|
| `Or jump to a juz` | 16 | 35 | 2.2× |
| `Money owed to you` | 17 | 37 | 2.2× |
| `Mark this line` | 14 | 28 | 2.0× |
| `Go to marked line` | 17 | 34 | 2.0× |
| `Saved in bookmarks` | 18 | 35 | 1.9× |
| `Download for offline` | 20 | 38 | 1.9× |
| `Offline tafsir texts` | 20 | 37 | 1.9× |
| `Back to Quran` | 13 | 25 | 1.9× |
| `Some ayat failed — tap to retry.` | 32 | 59 | 1.8× |
| `Composing video…` | 16 | 28 | 1.8× |
| `All %@ pages are offline` | 24 | 40 | 1.7× |
| `Adhan (melodic)` | 15 | 25 | 1.7× |
| `Pause chapter` | 13 | 22 | 1.7× |

`Mark this line` / `Go to marked line` / `Back to Quran` are toolbar or
action-sheet items where 2× is a real overflow risk. `Adhan (melodic)` sits
in a list of five sibling rows — "Azaana (sagalee mi'aawaa)" could be cut to
"Azaana (mi'aawaa)" if that row wraps.

---

## 6. Onboarding (`translations/om.onboarding.json`)

Nine first-run strings.

- **`Enable adhan` → "Beeksisa azaanaa dandeessisi"** — literally *enable
  adhan notifications*. **Do not shorten this to "Azaana banii".**
  CONFIRMED BEHAVIOUR: the button requests notification permission and
  switches adhan notifications ON; it plays no audio. Oromo *banuu* is the
  same "open / turn on" verb used for starting a sound ("raadiyoo banuu" =
  turn the radio on), so the short form would promise playback — exactly the
  drift that had to be corrected in three earlier languages. *Dandeessisuu*
  ("to enable") cannot be misread as playback. It is the longest button label
  in the onboarding flow; if it overflows, cut a word somewhere else, **not**
  "Beeksisa".
- **The neighbouring sentence was re-checked for the same drift and is
  clean.** "Salaata hundaaf azaana bareedaa. Yeroo barbaadde jijjiiruu
  yookaan callisiisuu ni dandeessa." — *callisiisuu* is "to silence", which
  is notification-sound language (it is what you do to an alert), not player
  language. It describes what the user will hear *from the notification*,
  as the English does. The same check was applied to the near-duplicate key
  in `om.json` ("…You can change or silence the sound later." → "Sagalicha
  booda jijjiiruu yookaan callisiisuu ni dandeessa.") and to
  `Adhan notifications`, `Adhan sound`, `Notification sound`, `Silent` and
  `Active — tap to turn off`. None of them says "play".
- **`Welcome to Noor` → "Baga gara Noor dhufte"** — the Oromo welcome
  formula is *baga … dhufte* ("good that you came"), second person singular.
  The app addresses the user as *ati* (singular) throughout; if a reviewer
  prefers the polite plural, ~15 strings using `-tta`/`-ta`/`kee` change too.
- **`Quran, prayer times, and athkar — private and free forever` → "Qur'aana,
  yeroo salaataa fi zikrii — icciitii kee ni eega, bara baraan bilisa"** —
  "private" could not be a bare adjective: Oromo *dhuunfaa* means
  *personal/individual*, which would misdescribe the app. Rendered as "it
  guards your secrecy/privacy". Long for one line.
- **`Maybe later` → "Booda ta'a"** (lit. "it will be later"). Two words, to
  stay narrow next to the wide enable button. The more literal "Tarii booda"
  is also fine.
- **`Continue` → "Itti fufi"**, matching `CONTINUE READING` / `CONTINUE
  LISTENING` in the main file.
- **`Your city for prayer times` → "Yeroo salaataatiif magaalaa kee"** — noun
  phrase, matching the English title. If it functions as a prompt,
  "…magaalaa kee filadhu" reads better.
- **`Language` → "Afaan"**, identical to the value in `om.json` as required.
  `App language` → "Afaan aappii".

---

## 7. Verification performed

- Both JSON files parse. 508 keys in `om.json`, key set **and order**
  identical to the other nine languages; 9 keys in `om.onboarding.json`.
- No empty or whitespace-only values; the one plural key (`%lld lines`) has
  both `one` and `other`.
- Format specifiers checked programmatically against every source key: same
  count and same kind (`%@` / `%lld`) in all 508. No string mixes positional
  with non-positional specifiers; every string with more than one specifier
  uses positional form (`%1$@`, `%2$lld`). The two strings whose argument
  order was deliberately reversed are listed in §3.
- Literal `\n` preserved in the two multi-line keys; URLs, `~350 MB`,
  `1–604`, `2:255`, `2.5%`, `%lldh`, the Arabic parentheticals
  (`علامات الوقف`, `أحكام التجويد`), `ﷺ` and `🎉` left untouched.

---

## 8. Honest bottom line

**Ship-readiness: NOT ready without a native reviewer.** My recommendation is
to hold `om` rather than ship it with the other nine.

The ordinary interface language — verbs, navigation, error messages,
sentence structure — I am reasonably confident in; Oromo grammar is
well-documented and SOV word order was applied consistently. The problem is
the vocabulary layer this app is made of. Twenty-nine of fifty-nine glossary
terms are transliterations I produced with no attestation, and several of
them (`Khatmaa`, `Beyitii`, `Waldaa Islaamaa Addunyaa`, `guyyoota adii`) each
control a whole feature's worth of strings. On top of that the media-player
cluster (`Taphachiisi`/`Yeroof dhaabi`) and `Bilbila` for "Bell" are ordinary
words I actively suspect are wrong, and "Bell" I would call more likely wrong
than right.

For the other nine languages the shipping argument was "a careful machine
translation serves the user better than an English interface, and errors will
be reported". The first half still holds for Oromo. **The second half does
not** — the Afaan Oromoo-speaking Muslim population that would file a bug
against an app store listing is small, so an error here has no correction
path and would sit in the app indefinitely. That asymmetry, not the quality
of the draft, is why I would hold it.

A native reviewer needs perhaps two hours: the `om` column of `GLOSSARY.md`
(§1b first — 29 cells), then §3 (about 30 strings), then the nine onboarding
strings. That is the whole review. If §1b comes back clean, this ships.
