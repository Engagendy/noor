# Somali (so) — reviewer notes

Latin script, LTR. No font, shaping or direction work was needed; everything
below is language.

Somali orthography followed throughout: `x` = ح, `c` = ع, `q` = ق, `kh` = خ,
`dh` = the retroflex D, and long vowels are doubled (Quraan, Suurad, Aayad,
Tafsiir, Tajwiid, Nisaab, Xadiis). Somali has no letter for ghayn (غ), which
is why **Maqrib** (not "Maghrib"/"Magrib") is used.

## Glossary — what was corroborated and what was not

**Verified against published Somali Islamic material** (prayer-time sites,
Somali tafsir/hadith blogs, Xisnul Muslim translations, Somali Quran
academies):

Subax · Duhur · Casar · Maqrib · Cishe · Salaad · Quraan · Suurad · Aayad ·
Tafsiir · Tajwiid · Xadiis · Qiblad · Adaan · Kacba · Masjid · Mus'haf ·
Adkaar · Dikri · Duco · Tasbiix · Xifdi · Juz · Xizib · Qaari · Zako
(zakada/sakada) · Nisaab · Weyso · Sunno · Nafil / Nawaafil · Hijri ·
Xisnul Muslim · Xafs · Warsh · Riwaayad · Mad-hab · Dahab / Qalin (gold /
silver) · Shaafici, Maaliki, Xanbali, Xanafi.

That is **35 of 52** glossary cells with a real source behind them.

**NOT corroborated — please check these first:**

| term | used | why it is uncertain |
|---|---|---|
| Khatmah | **Khatmo** (*khatmada*) | The root is certainly used in Somali ("khatmi", "khatunka Quraanka"), but I found no page that settles the noun form for a *reading plan*. "Khatmad" and "Khatam" are both plausible alternatives. Appears in 6 strings and one ALL-CAPS header. |
| Izhar | **Idhaar** | إظهار. Somali has no clean way to write ظ; sources write it variously "idhaar", "isdhaar", "izhaar". I found no Somali tajweed page using any of them. Low stakes (one parenthetical), but it is a guess. |
| Matn | **Matan** | Formed from Arabic by the usual Somali pattern, not seen in the wild. |
| Line of a matn (بيت) | **Beyd** | Somali verse terminology is native and does not map cleanly onto Arabic *bayt*. "Beyd" follows the Arabic; the native word would be "misraac" or simply "xariiq" (a UI line — wrong sense). Used in 8 strings including the plural. |
| Ruqyah | **Ruqyo** (*ruqyada*) | The practice is widely discussed in Somali but the searches returned no page using a settled Somali spelling. "Ruqyad" is the other candidate. |
| Names of Allah | **Magacyada Alle** | Translated rather than transliterated, because "Asmaa'ul Xusna" is also current; the glossary records both. If the app has a dedicated screen title, "Asmaa'ul Xusna" may read more like a book title. |
| Tahajjud | **Tahajud** | Dark theme name; vowel length is a guess ("Tahajjud" also seen). |
| Moonsighting Committee | **Guddiga Arkitaanka Bisha** | Invented; the organisation's name is normally left in English. |
| Egyptian General Authority | **Hay'adda Guud ee Masar** | The real name is the Egyptian General Authority of Survey; no settled Somali rendering. |
| Muslim World League | **Raabidatul Caalamil Islaami** | Transliterated the Arabic rather than translating. "Ururka Caalamiga ah ee Islaamka" is the translated alternative and may be clearer to a Somali reader who has not seen the Arabic. |

## Competing forms, and which was chosen

- **Zako / Sako.** Somali writing uses both ("zakada" and "sakada" appear in
  the same corpora, sometimes on the same site). **Zako / zakada** was
  chosen because it is closer to the Arabic and is the form Somali fatwa
  collections title their chapters with. A reviewer preferring *sako* should
  change all 6 occurrences together, not one.
- **Riwaayad vs. keeping Arabic.** Chose **Riwaayad** — see the glossary
  note; the drama sense is real but the Islamic sense is attested.
- **Qorrax-soo-bax vs. Shuruuq** for Sunrise. Chose the native
  **Qorrax-soo-bax**; *shuruuq* is used in some Somali prayer timetables and
  would be shorter in a timetable row. Flagged as a swap a reviewer may
  reasonably make (single row label, one key).
- **Adkaar vs. Xusuus.** Chose the Arabic loan **Adkaar**, which is what
  Somali religious sites actually print; *xusuus* is the literal Somali for
  "remembrance" and would be exactly the "Athkar → memories" failure the
  glossary warns about.
- **Mad-hab vs. Madhab.** Chose the hyphenated **Mad-hab**, because in
  Somali orthography an unhyphenated `dh` is the retroflex consonant and
  "madhab" would be read wrong. Reviewers used to Arabic may want to remove
  the hyphen; it should stay.
- **Weyso vs. Wuduu** for wudu. Chose the native **Weyso**, which is the
  everyday Somali word and is attested in Somali fiqh texts.
- **Barnaamij vs. "abka"** for "app". Chose **barnaamij** (programme)
  throughout; *ab*/*abka* is common in speech but looks like a loan stub in
  print.

## "Looks wrong, is right" — do not undo

- **"Shid ogeysiisyada adaanka"** for `Enable adhan` (onboarding). The button
  requests notification permission and switches adhan notifications on; it
  plays no audio. Somali *shid* on its own is exactly the verb used for
  turning on a radio, so "Shid adaanka" would read as *play the adhan*. The
  longer form is deliberate. If the button overflows, cut a word somewhere
  else, not "ogeysiisyada".
  The two neighbouring onboarding sentences were re-checked for the same
  drift and are clean: "Adaan qurux badan salaad kasta. Waqti kasta waad
  beddeli kartaa ama waad aamusiin kartaa." — *aamusiin* (silence) is
  notification-sound language, not player language, and matches the English.
  The same check was applied to the in-app twin of that sentence
  (`A beautiful adhan at every prayer. …silence the sound later.`) and to
  `Adhan notifications` / `Adhan sound`, which are nouns and unaffected.
- **"Xizib"**, not "xisbi" — *xisbi* is a political party.
- **"Qalin (garaam)"** for `Silver (grams)` — *qalin* also means "pen", but
  the gold/silver pairing "dahabka iyo qalinka" is standard in Somali zakat
  texts. Do not replace with "silfar"/"fidda".
- **"Riwaayadda Xafs" / "Riwaayadda Warsh"** — see above; not a drama.
- **"Lacag aad dadka ku leedahay"** for `Money owed to you`. Somali marks the
  direction of a debt with the person, not the verb: the tempting literal
  "lacag lagugu leeyahay" means the *opposite* (money **you** owe). This one
  is easy to "correct" into a factual error in the zakat calculator.
- **"Da' %lld"** for `Age %lld` — *da'* with the apostrophe is the Somali
  word for age (the apostrophe is a glottal stop, not a typo).

## Low confidence / needs a look at the real control

- `After prayer by` → **"Salaadda ka dib"**. The English is a fragment
  ending in "by" with a minutes value after it. Reads fine as
  "Salaadda ka dib  10 daq"; if the value is not adjacent, it needs
  "(daqiiqado)".
- `Finish the Quran in` → **"Muddada Quraanka lagu dhammaynayo"** ("the
  period in which the Quran is completed"). Turned into a noun label because
  the fragment cannot end a Somali sentence. Check against the picker.
- `Chapters` → **"Cutubyada"** (hadith-book context). Somali religious books
  also use "baabab" (from Arabic أبواب), which is the technical term but may
  read archaic in a list header.
- `Off` → **"Xidhan"** (closed/off). If it sits in a list next to "Cod
  la'aan" (Silent) the two may feel too close; "La damiyay" is the
  alternative.
- `Done` → **"Diyaar"**. Somali has no settled toolbar-confirm word;
  "Dhammaaday" is the other option but is longer.
- `Clear` and `Delete` are **both "Tirtir"** — Somali uses the one verb for
  erase/clear/delete and the contexts (a counter, a download) don't collide
  on screen. Flagged so it doesn't look like a copy-paste slip.
- `Remove bookmark` → "Ka saar calaamadda" vs `Remove mark` → "Tirtir
  calaamadda" — deliberately different verbs so the two rows are
  distinguishable; both are "remove a mark" in Somali.
- `Bearing from true north` → **"Jihada laga qiyaasay woqooyiga saxda ah"** —
  free rendering; Somali has no compass-bearing noun.
- `Well done!` → **"Aad baad u fiicantahay!"** — kids-mode praise. It is
  2.3× the English and the longest ratio in the file (see below). Somali has
  no short interjection for this; "Waad ku guulaysatay!" is equally long.
- `Play` → **"Dhageyso"** (*listen*), not the media-generic "Ciyaar" (which
  means *play a game* in Somali and is a known bad machine rendering). This
  also makes `Play` and `Listen` the same word; acceptable here because the
  only playable content is recitation.
- `Pause` → **"Hakad"** vs `Stop` → **"Jooji"**. `Cancel` was given a third
  verb, **"Baaji"**, to avoid a three-way collision on "Jooji".
- `%@ is approaching` → **"Waqtiga %@ wuu soo dhowaanayaa"**. The word
  "Waqtiga" was added because Somali agreement depends on the gender of the
  placeholder's referent; anchoring the sentence to a masculine noun makes it
  grammatical whatever prayer name is substituted. Same trick in
  `It's time for %@` → "Waa waqtigii %@".
- `Near %@` → **"Agagaarka %@"** — safe with any city name (no suffix touches
  the placeholder).
- `with %@'s recitation` → **"akhriska %@"**. Somali would idiomatically want
  a genitive ("akhriska Sheekh Mishaary-ga"), which is impossible without
  knowing the name; the bare juxtaposition is understood.
- `Showing %lld of %lld — open the text to see the rest` → rendered as a
  slash ratio, positional specifiers throughout. Verify the numbers are
  (shown, total) in that order.
- `Searching %@ of %@ surahs you have downloaded` → "Waxaa la raadinayaa
  %1$@ / %2$@ suurad oo aad soo dejisay" — also a ratio; the fully written
  Somali prose form is far too long for a status line.
- `Zakat due (2.5%)` → "Zakada la bixinayo (2.5%)" — decimal comma is not
  standard in Somali, so the point was kept, and the `%` left trailing rather
  than risking a leading `%2` inside a format string.
- `Grown-ups` → **"Dadka waaweyn"** (kids-mode section header). "Waalidka"
  (parents/guardian) is closer to the Arabic لولي الأمر if that is the sense.
- `Public-domain dataset` → "Xog dadweynaha u furan" — descriptive; Somali
  has no legal term of art for public domain. Legal reviewers may want it
  left in English.
- Proper names transliterated on judgement, not from a source:
  **Madiina, Maka, Dubay, Ummul Quraa, Karaachi, Ibnu Kathiir, Xamad
  Al-Duraihim, Saxiix al-Bukhaari**. `Adhan (Azeez)` kept the Latin spelling
  "Azeez" unchanged, since it identifies an audio file's muezzin.
- "offline" was left as the English word (it is what Somali speakers say);
  "widget", "status", "Dynamic Island" likewise.

## Length

Somali is agglutinative with a lot of short function words, so it runs
**longer than English almost everywhere** — the median string grew, and
these are the worst ratios:

| en | so | ratio |
|---|---|---|
| Load failed | Soo bixintu way fashilantay | 2.45× |
| Edit plan | Wax ka beddel qorshaha | 2.44× |
| Well done! | Aad baad u fiicantahay! | 2.30× |
| No matches | Wax u dhigma lama helin | 2.30× |
| From ayah | Laga bilaabo aayadda | 2.22× |
| App font | Farta barnaamijka | 2.12× |
| All events | Dhammaan dhacdooyinka | 2.10× |

None of these is a tab-bar item. **The tab bar is safe**: Quraan / Salaad /
Baro / Qalabka / Dejinta are all 4–7 characters, shorter than the French and
Spanish that already strain it. The at-risk spots are narrow buttons —
"Isku day mar kale" (Retry), "Waa hagaag" (OK) and "Fur qufulka" (Unlock) —
and the ALL-CAPS section headers, of which
**"WAXA SOO SOCDA EE TAARIIKHDA ISLAAMKA"** (`COMING UP IN ISLAMIC HISTORY`,
37 chars) is the longest in the file. If it overflows, "TAARIIKHDA ISLAAMKA"
alone carries the meaning.

## Onboarding

`translations/so.onboarding.json`, nine strings:

- `Welcome to Noor` → "Ku soo dhawoow Noor" — the standard Somali welcome;
  no case suffix attaches to the name.
- `Quran, prayer times, and athkar — private and free forever` →
  "Quraan, waqtiyada salaadda, iyo adkaar — asturnaantaada waa la ilaaliyaa,
  weligeedna bilaash". "Private" cannot be a bare adjective: Somali *qarsoon*
  means *hidden/secret*, which would misdescribe the app, so it is rendered
  as "your privacy is protected". It is long; a shorter option is
  "— gaar ahaan adiga, weligeedna bilaash".
- `Enable adhan` → "Shid ogeysiisyada adaanka" — see the do-not-undo section.
- `Continue` → "Sii wad"; `Maybe later` → "Goor dambe" (kept to two words so
  it fits beside the wide adhan button); `Language` → "Luqadda", identical to
  the value in `so.json` as required; `App language` → "Luqadda barnaamijka".
- `Your city for prayer times` → "Magaaladaada waqtiyada salaadda" — a noun
  phrase matching the English title. If it functions as a prompt,
  "Dooro magaaladaada waqtiyada salaadda" reads better.

## Overall confidence

**Moderate-to-good on ordinary language, moderate on terminology.** The
everyday interface Somali (verbs, buttons, error sentences) I am confident
in. The religious vocabulary is mostly attested — the prayer names, the
Quran-structure words and the zakat words all came back from real Somali
Islamic sources — but Somali has less standardised Latin orthography for
Arabic loans than any other language in this file, so vowel length and `dh`
vs `d` spellings vary between publishers even when the word is right. The
11 flagged rows above, and Khatmo and Beyd in particular (they recur across
many strings), are where a native reviewer's time is best spent.
