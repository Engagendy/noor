# French (fr) — reviewer notes

Typography: narrow no-break space (U+202F) before `: ; ? !` and before `%`;
apostrophe U+2019 throughout. Glossary terms used verbatim (Coran, Sourate,
Verset, Prière, Fajr, Dhuhr, Asr, Maghrib, Icha, Qibla, Adhan, Adhkar,
Tajwid, Tafsir, Hadith, Mushaf, Khatma, Riwaya, Sunna, Invocation, Hégirien,
Récitateur, Mémorisation, Surérogatoire, Prosternation, Basmala).

## Glossary additions

| en | fr | note |
|---|---|---|
| madhab | madhab | Kept as loanword ("Madhab pour l’Asr"); "école juridique" is too long for a settings row. |
| masjid | mosquée | Standard French; "masjid" is not idiomatic in French UI. |
| wudu | wudu | Kept as loanword; "ablutions" is the alternative if the reviewer prefers. |
| dhikr | dhikr | Singular of Adhkar; used where the English is singular. |
| nisab | nisab | Standard in French zakat literature (lowercase). |
| zakat | zakat | Lowercase, feminine ("la zakat", "aucune zakat n’est due"). |
| Hifz mode | mode mémorisation | Per glossary Hifz = Mémorisation. |
| Ruqyah | Roqya | Spelling used by French Muslim publishing. |
| matn | matn | Kept as loanword (memorisation text); no accepted French equivalent. |
| Hisn al-Muslim | Hisn al-Muslim | Book title, transliteration kept. |
| Hafs / Warsh | Hafs / Warsh | Reciter/riwaya names kept. |
| iẓhār | iẓhār | Transliteration kept as in source. |
| Makki / Madani (surah) | Mecquoise / Médinoise | Feminine (sourate), per the Arabic مكية/مدنية. |
| line (of a matn) | vers | Arabic بيت = line of classical verse, not "ligne". |
| Kaaba | Kaaba | Standard French spelling. |
| Hanafi / Shafi'i / Maliki / Hanbali | Hanafite / Chafiite / Malikite / Hanbalite | Standard French adjectives. |

## Low confidence

- `After prayer by` → "Après la prière" — English is a truncated phrase ("… by N minutes"); the French drops the "by". If the value control is separate this reads fine, otherwise it needs "Après la prière (min)".
- `Age %lld` → "%lld ans" — assumed a child-age value row, not a "Age:" label. If it is a label, use "Âge %lld".
- `Count` → "Nombre" — ambiguous without the screen (tasbih target count vs. current tally). "Compteur" if it is the running tally.
- `It's time for %@` → "C’est l’heure de %@" — placeholder is a prayer name; "de Fajr" is fine, but "de l’Asr / du Dhuhr" would need the article baked into the prayer names. No agreement bug, just slightly bare.
- `Off` → "Aucun" — assumed a *sound* picker option (Arabic بدون). If it labels a toggle state, "Désactivé".
- `Bell` → "Cloche" — notification-sound name; "Carillon" is the other candidate.
- `ON THIS DAY` → "CE JOUR-LÀ" — chosen for length; the fuller "UN JOUR COMME AUJOURD’HUI" is more idiomatic but far too long for a section header.
- `Moonsighting Committee` → left in English (proper name of the org, as with ISNA). Alternative: "Comité d’observation lunaire".
- `Quranic word meanings` → "Sens des mots coraniques" — Arabic is غريب القرآن (rare/difficult words). "Mots difficiles du Coran" is closer to the meaning; picked the shorter neutral label.
- `Search the word meanings you have` → "Rechercher dans vos sens de mots" — awkward; depends on what the downloaded packs are called on screen.
- `No matching athkar` → "Aucun dhikr correspondant" — singular dhikr chosen for the negative; "Aucun Adhkar correspondant" is ungrammatical in French.
- `Your stars` → "Tes étoiles" and `Ask a grown-up` → "Demande à un adulte" use **tutoiement** (kids mode); everything else uses vouvoiement. Confirm the kids screens are all tutoiement.
- `%lld lines` plural → "%lld vers" for both `one` and `other` ("vers" is invariable). Correct French but looks like a copy-paste error; kept deliberately.
- `Madani` → "Médinoise" / `Makki` → "Mecquoise" assume the surah-revelation badge (feminine). If either string is ever reused for the *mushaf print*, it must not be feminine — `Madani print typefaces` was translated separately as "Polices du Mushaf de Médine".
- `Repeat %@×` / `Repeat %lld×` → "Répéter %@×" — the "×" reads oddly after a French verb; "%@×" alone may be better if the row already says "Répétition".

### Clipping risk (French much longer than English)

- `Nawafil` → "Prières surérogatoires" (8 → 22 chars). Glossary-faithful but a likely overflow in a list row; "Nawafil" would fit.
- `COMING UP IN ISLAMIC HISTORY` → "À VENIR DANS L’HISTOIRE ISLAMIQUE" — uppercase section header, long.
- `Hifz mode (hide text)` → "Mode mémorisation (masquer le texte)" — settings row with a trailing control.
- `Live countdown to the next prayer` → "Compte à rebours jusqu’à la prochaine prière".
- `Download all 114 surahs to search them` → "Téléchargez les 114 sourates pour y chercher".
- `Turn until the arrow points up` → "Tournez jusqu’à ce que la flèche pointe vers le haut" (qibla overlay, one line).
- `Word-tracking surah files` → "Fichiers de sourates pour le suivi des mots" (storage row with a size on the right).
- `Bearing from true north` → "Azimut depuis le nord géographique".
- `Voluntary prayers and their times` → "Prières surérogatoires et leurs horaires".
- `Start memorizing` → "Commencer la mémorisation" (button).
- `Showing %lld of %lld — open the text to see the rest` → "%1$lld sur %2$lld affichés — ouvrez le texte pour la suite".
- `Downloaded once, readable forever offline…` and the Zakat disclaimer are the two longest bodies; both grow ~20% in French.

## Onboarding

Nine first-run strings, in `translations/fr.onboarding.json`. `Language` repeats
the value already used in `fr.json` ("Langue").

- `Quran, prayer times, and athkar — private and free forever` → "Coran, prière et Adhkar — privé et gratuit à jamais" — must stay on ONE line on a phone, so "prayer times" was compressed to "prière" (the full "horaires de prière" pushes it over). If two lines are acceptable, prefer "Coran, horaires de prière et Adhkar — privé et gratuit à jamais". Highest clipping risk of the nine.
- `Your city for prayer times` → "Votre ville pour les horaires de prière" (26 → 39 chars) — step title, may need to wrap or shorten to "Votre ville".
- `App language` → "Langue de l’app" — "app" matches the register used elsewhere ("Police de l’app"); "Langue de l’application" is the formal alternative but is longer.
- `Enable adhan` → "Activer l’adhan" — fixed-height primary button; fits.
- `Maybe later` → "Plus tard" — deliberately shorter than a literal "Peut-être plus tard", which would clip a secondary button.
- `Welcome to Noor` → "Bienvenue dans Noor" — "dans" (inside the app) rather than "à"; confirm preference.
- `A beautiful adhan at every prayer…` → "…le changer ou le désactiver à tout moment." — "désactiver" (not "couper") because "silence it" here means turning the notification off, not muting a sound in progress.
- **`Enable adhan` is a NOTIFICATIONS toggle, not playback.** The button requests the notification permission and switches adhan notifications on; it plays no sound. "Activer l’adhan" is correct because French "activer" can only mean *turn on a feature*, never *lancer la lecture* — do NOT "fix" it toward "Écouter / Lire l’adhan". For the same reason the body line ends "…le changer ou le **désactiver** à tout moment" (turn the notification off), not "le couper", which would suggest silencing a sound already playing.
