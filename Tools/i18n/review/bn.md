# Bengali (bn) review notes

## Glossary additions

| en | bn | note |
|---|---|---|
| Recitation / tilawah | তিলাওয়াত | Used for "recitation"; "ক্বারি" (glossary) kept for the person. |
| Line (of a matn/poem) | পঙক্তি | Line of a memorisation poem (ar بيت), not a UI text line. |
| Matn | মতন | Memorisation text; "Memorisation texts" → হিফজের মতন. |
| Zakat | যাকাত | Publishing spelling; জাকাত is the newspaper spelling. |
| Nisab | নিসাব | |
| Wudu | অজু | Bangladeshi everyday form (not ওজু/উযূ). |
| Masjid | মসজিদ | |
| Madhab | মাযহাব | |
| Hafs / Warsh | হাফস / ওয়ারশ | With রেওয়ায়েত from the glossary. |
| Izhar | ইজহার | Tajweed rule in the colour-key footer. |
| Waqf marks | ওয়াকফের চিহ্ন | "Pause marks". |
| Hisn al-Muslim | হিসনুল মুসলিম | Book title, standard BD transliteration. |
| Ruqyah | রুকইয়াহ | |
| Tahajjud | তাহাজ্জুদ | Dark-theme name. |
| Fi sabilillah | ফি সাবিলিল্লাহ | Kept transliterated, as in English source. |
| Kaaba | কাবা | |
| Hizb | হিজব | Juz is পারা per glossary, but হিজব has no native BD equivalent. |
| Sahih al-Bukhari | সহিহ বুখারি | |
| Shafi'i, Maliki, Hanbali | শাফিয়ি, মালিকি, হাম্বলি | |
| Umm al-Qura | উম্মুল কুরা | |

## Low confidence

- `Appearance` → "চেহারা" — settings-section title. "থিম" or the loanword "অ্যাপিয়ারেন্স" may read faster; needs the screen.
- `System` → "সিস্টেম" — the Arabic reads "system language", so if this row only ever appears under Language, "সিস্টেমের ভাষা" is better; I kept it neutral in case it is also the theme option.
- `Search` → "সার্চ" (loanword) vs "খুঁজুন"/"অনুসন্ধান". I used সার্চ for the bare noun/field but "… খুঁজুন" for the verb phrases (`Search athkar`, `Search city`). Confirm the mix is acceptable.
- `Play` / `Pause` → "প্লে" / "পজ" loanwords, matching iOS media UI. Native "চালান"/"বিরতি" is an option but reads oddly on a transport control.
- `Bell` → "ঘণ্টা" — this is a notification-sound name; if the list shows sound names in Latin elsewhere, "বেল" may fit better.
- `Count` → "গণনা" — tasbih counter label; "সংখ্যা" is the alternative.
- `Back` → "পেছনে" — iOS nav-bar back label; "ফিরুন" also possible.
- `Done` → "সম্পন্ন" vs the more colloquial "হয়ে গেছে".
- `Finish the Quran in` → "কুরআন খতম করবেন যত দিনে" — a picker label followed by a duration; wording depends on what follows it.
- `After prayer by` → "নামাজের কত পরে" — same problem: a label followed by a minutes value.
- `%@ · manual` → "%@ · ম্যানুয়াল" — very tight row; "নিজে" (self-set) is shorter and clearer if it means a manually chosen city.
- `Reader options` → "রিডারের অপশন" — the Arabic could be read as "the reciter's options"; I took it as the reading screen.
- `Grown-ups` → "অভিভাবক" (guardian) — kids-mode gate; "বড়দের জন্য" is the alternative for a section header.
- `Your stars` → "তোমার তারা" — kids screen, so informal তুমি; if the string is also used for adults it should be "আপনার তারা".
- `Ask a grown-up` → informal তুমি form ("জিজ্ঞাসা করো") for the same reason.
- `Hizb quarters` → "হিজবের চতুর্থাংশ" — long for a row label; "রুবুল হিজব" is the traditional term.
- `Memorisation texts` / `Search this matn` → মতন — correct madrasa term but may be unfamiliar to lay users; "মুখস্থের পাঠ" is plainer.
- `%lld lines` plural — Bengali has no one/other distinction here, so both forms are identical; intentional.
- `Egyptian General Authority` → "মিসরের জেনারেল অথরিটি" — half-loan calculation-method name; the full native "মিসরীয় সাধারণ জরিপ কর্তৃপক্ষ" is long and may overflow the picker row.
- `Moonsighting Committee` → "মুনসাইটিং কমিটি" — kept as a proper name; "চাঁদ দেখা কমিটি" would be translated instead.
- Numerals: all digits left in Latin (604, 114, 12, 85, 2.5%, MB) because `%lld` renders Latin at runtime; mixing Bengali literals with Latin substitutions would look wrong. Confirm this is the wanted convention.
- `Zakat due (2.5%)` — the source has a bare `%` (not `%%`); kept verbatim, but worth checking it is not passed through `String(format:)`.
- `That's not it — here's a new one.` → "এটি সঠিক উত্তর নয় — এই নিন নতুন একটি।" The Arabic says "here's a new *question*"; I left the noun implicit.
- `Flowing text` → "চলমান টেক্সট" — reading-mode name paired with "মুসহাফ (একটানা)"; a native reviewer may prefer "ধারাবাহিক লেখা".

## Onboarding

Nine first-run strings, in `translations/bn.onboarding.json`. Uncertain ones:

- `Welcome to Noor` → "Noor-এ স্বাগতম" — the Latin brand takes a Bengali case suffix with a hyphen; a reviewer may prefer "Noor এ স্বাগতম" or "স্বাগতম Noor-এ".
- `Quran, prayer times, and athkar — private and free forever` → "কুরআন, নামাজের সময় ও জিকির — গোপনীয় এবং চিরকাল ফ্রি" — long for one line; "গোপনীয়" (private/confidential) is the weak spot, "আপনার তথ্য আপনারই" reads better but is longer.
- `Continue` → "চালিয়ে যান" — standard, but note `CONTINUE READING`/`CONTINUE LISTENING` in bn.json also end in "চালিয়ে যান"; that is intended.
- `Maybe later` → "পরে দেখব" (first-person "I'll see later", how a BD user would phrase declining). "এখন নয়" is shorter if the button overflows.
- `Enable adhan` → "আজান চালু করুন". **This button turns adhan NOTIFICATIONS on** (it requests notification permission and switches them on); it does NOT play a sound. "চালু করুন" = turn on, which is correct — do not "fix" it toward playback ("বাজান"/"শোনান"). Only open question is register: "আজান চালু করি" would match the informal tone of "পরে দেখব" if the reviewer wants the two buttons parallel.
- Same drift risk in the body string above it: "প্রতি নামাজে সুন্দর একটি আজান।" describes what the notification will sound like, and "বদলাতে বা নীরব করতে পারবেন" = change or silence the notification sound — neither is a playback control. `Maybe later` declines the permission prompt.
- `A beautiful adhan at every prayer. You can change or silence it anytime.` → "প্রতি নামাজে সুন্দর একটি আজান। যেকোনো সময় সেটি বদলাতে বা নীরব করতে পারবেন।" — "নীরব করতে" for "silence"; "বন্ধ করতে" is plainer but overlaps with "turn off".
- `Language` repeats the bn.json value exactly: "ভাষা". `App language` → "অ্যাপের ভাষা".

## Digits decision (supersedes the earlier note)

The app runs the Bengali UI under the `bn` locale, so `%lld` and formatted
dates/times render in Bengali digits (০১২৩৪৫৬৭৮৯). All literal numerals in
running text were therefore rewritten in Bengali digits — 11 strings changed:
৬০৪ (×3), ১১৪ (×2), ১২ (×2), ১০০/৩৫০ MB (×3), ৮৫, ২.৫%.
Unit symbols stay Latin but the NUMBER before them does not: "~৩৫০ MB",
never "~350 MB" — two digit systems in one sentence reads to a native reader
as a rendering bug.

Deliberately left Latin: format specifiers themselves (`%1$lld` untouched),
the unit/brand tokens "MB", "ISNA", "Dynamic Island" (in "লক স্ক্রিন ও ডাইনামিক
আইল্যান্ড"), and the `2:255` search-field examples, since the user types those
in Latin.

Verified by an ASCII-only sweep of every value in bn.json and
bn.onboarding.json: the ONLY remaining Latin digits are the two `2:255`
examples, and no string mixes Bengali and Latin digits.
