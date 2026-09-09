# What a native reviewer should check first

The eight new interface languages — Indonesian, Urdu, Turkish, French,
Persian, Bengali, Malay, Spanish — were translated by a machine and **have
not been reviewed by a native speaker**. They are shipped on the judgement
that a careful machine translation, with the religious vocabulary pinned by
`GLOSSARY.md`, serves a Bengali or Turkish speaker better than an English
interface does. That judgement stops being safe the moment anyone treats
this as finished work.

So: nothing here needs 351 strings re-read. Each language has 24–39 strings
its translator flagged as genuinely uncertain, in
`Tools/i18n/review/<code>.md`. That list plus the glossary is the review.

| language | file | flagged | glossary terms it settled |
|---|---|---|---|
| Indonesian | `review/id.md` | 26 + onboarding | 16 |
| Urdu | `review/ur.md` | 26 + onboarding + digits | 15 |
| Turkish | `review/tr.md` | 25 + onboarding | 16 |
| French | `review/fr.md` | 30 + onboarding | 16 |
| Persian | `review/fa.md` | 27 + onboarding | 16 |
| Bengali | `review/bn.md` | 24 + onboarding + digits | 20 |
| Malay | `review/ms.md` | 24 + onboarding | 15 |
| Spanish | `review/es.md` | 25 + onboarding | 18 |

Everything those terms settled is collected in the second table of
`GLOSSARY.md`. **Check that table before the string lists** — it is short,
it is shared with Android, and a wrong term there is wrong in dozens of
places at once.

## Cross-cutting problems, worth one decision each

These came back from several languages independently, which is usually a
sign the ENGLISH is the problem, not the translation.

1. **`After prayer by`** — a dangling English fragment completed by a minutes
   picker. Seven of the eight translators flagged it; every language had to
   guess at the sentence it belongs to. Rewrite the source string (e.g.
   "Minutes after prayer") and all eight follow.
2. **`Finish the Quran in`** — the same shape, and no SOV language (Turkish,
   Urdu, Bengali, Persian) can end a clause on it. All four recast it as a
   noun label.
3. **`line` means a verse of a memorisation poem**, not a row of text — the
   Arabic بيت proves it. Every language rendered it as *verse* (bait, beyit,
   vers, شعر, পঙক্তি, verso). Six strings ride on that one
   reading; if the UI ever counts display lines, all six are wrong in all
   eight languages at once.
4. **`It's time for %@`** — the placeholder is a prayer name, and Spanish,
   French and Turkish all need an article or a case suffix glued to it that
   a format string cannot supply. Spanish gets "Es hora de Fayr" where it
   wants "del Fayr". A source-side fix (bake the article into the passed
   value) is the only clean one.
5. **`Zakat due (2.5%)` contains a bare, unescaped `%`.** Five translators
   flagged it. It is not a valid format specifier; if that string is ever
   passed through `String(format:)` it misparses in *English too*. Left
   exactly as it was — it is an English-side bug, not a translation one.
6. **Prayer-calculation method names** (Egyptian General Authority, Muslim
   World League, Moonsighting Committee, ISNA, Umm al-Qura) are organisation
   names. Some languages have an established rendering, some do not, and app
   convention is often to leave them in English. Each language guessed
   separately; one house rule would settle it.
7. **`Chapters` / `Section` / `Result(s)` / `Bookmark(s)`** are ambiguous out
   of context, and several languages cannot distinguish singular from plural
   here anyway. Each was flagged; each needs a glance at the screen.

## What is deliberately NOT translated

- **`isArabicUI` content branches.** About 58 places in the Swift build a
  string as `isArabicUI ? "<arabic>" : "<english>"` rather than going through
  the catalog. In the eight new languages these fall back to the ENGLISH
  branch. Two of them are on the Today tab and visible in every screenshot:
  the khatmah progress line ("Khatmah · page 604 of 604") and the khatmah
  card's day/page counters (`App/TodayView.swift` ~lines 812–990). The rest
  are hadith/athkar/hijri detail strings (`App/HadithTab.swift`,
  `App/HijriCalendarView.swift`, `Modules/Learn`, `Modules/Athkar`). Moving
  them into the catalog is a separate job; until then those lines are English
  for eight of the ten languages. **This is the largest remaining gap.**
- **Widgets, Live Activities and adhan notifications** still choose between
  Arabic and English only (`Widgets/NoorWidgets.swift`,
  `App/PrayerLiveActivityController.swift`, the notification planner). An
  Urdu user gets an English widget. Same reason: their text is not in the
  catalog.
- **Quran, hadith, athkar and tafsir CONTENT.** Arabic stays Arabic and stays
  right-to-left in every interface language (`.arabicBlock()`), and the
  non-Arabic interface reads the existing English translation. Translating
  the content itself is a content-licensing project, not a localization one.
- **Surah names, reciter names, font family names, city names, "Noor".**

## Layout risks the screenshots did not settle

- **French and Spanish run long.** Both translators listed their likely
  overflows (French: "Prières surérogatoires" for Nawafil; Spanish: "All 604
  pages are offline", "Turn until the arrow points up"). The Today and
  Settings screens were checked at the default text size only — nothing was
  checked at the largest Dynamic Type size.
- **Turkish "Ezan bildirimlerini aç"** is now the widest onboarding button
  label, next to "Daha sonra".
- **Urdu is drawn in Noto Nastaliq Urdu**, whose line box is 2.5em against
  Readex Pro's ~1.3em, so interface text is set at 0.72× the nominal point
  size (0.85× in the language pickers) to keep it inside rows that were
  measured for a Naskh face. It reads correctly at the default text size on
  a 6.9" phone; it has not been checked on a small phone, at large Dynamic
  Type, or on iPad.
