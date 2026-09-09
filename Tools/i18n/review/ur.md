# Urdu (`ur`) review notes

All glossary terms were used verbatim (نماز، فجر، ظہر، عصر، مغرب، عشاء، طلوعِ آفتاب،
قبلہ، اذان، قرآن، سورہ، آیت، پارہ، مصحف، تجوید، تفسیر، حدیث، اذکار، دعا، تسبیح،
ختم، حفظ، قاری، روایت، ہجری، سنت، نفل).

## Glossary additions

| en | ur | note |
|---|---|---|
| Zakat | زکوٰۃ | Standard Urdu spelling with the دال/واو-ہ ligature; not "زکات". |
| Nisab | نصاب | Zakat threshold. |
| Madhab (Asr madhab) | مسلک | Urdu prayer apps say "مسلک" for the Hanafi/Shafi'i Asr setting; "مذہب" reads as "religion". |
| Hizb | حزب | Kept as the Arabic term; quarters = ارباع. |
| Iẓhār | اظہار | Tajweed rule name, transliterated as in Urdu tajweed books. |
| Matn (learning text) | متن / متون | Classical memorisation text. |
| Line (of a matn poem) | شعر / اشعار | ar uses بيت; Urdu poetry counts اشعار. See low-confidence note. |
| Ruqyah | رقیہ شرعیہ | Follows ar الرقية الشرعية. |
| Dhikr (singular) | ذکر | Singular of اذکار. |
| Khatmah plan | ختم کا منصوبہ | "plan" = منصوبہ throughout. |
| Wudu | وضو | |
| Masjid | مسجد | |
| Names of Allah | اسمائے حسنیٰ | |
| Business inventory (zakat) | مالِ تجارت | Fiqh term, not a literal "inventory". |
| Hafs / Warsh | حفص / ورش | With روایت per the glossary. |

## Low confidence

- `%lld lines` / `Line %lld` / `Mark this line` / `No matching lines` / `%lld of %lld lines` / `Go to marked line` — I rendered "line" as شعر / اشعار (a couplet of a matn). The Arabic uses بيت. If the UI counts *display* lines rather than verses of poetry, these should all be سطر / سطریں. One decision, six strings.
- `Finish the Quran in` — "قرآن مکمل کرنے کی مدت" (lit. "duration to finish the Quran"). It is a picker label followed by a number of days; a literal "قرآن مکمل کریں" would read as a button.
- `After prayer by` — "نماز کے کتنے منٹ بعد". Assumed a minutes picker; if the unit is chosen elsewhere, drop منٹ.
- `Live countdown` — "براہِ راست الٹی گنتی". Long for a toggle row; "الٹی گنتی" alone may fit better. Some Urdu apps just say "کاؤنٹ ڈاؤن".
- `Reader options` — "مطالعے کے اختیارات". The ar (خيارات القارئ) is ambiguous between "reading view" and "reciter"; I read the code sense as reading view.
- `Quranic word meanings` — used the plain "قرآنی الفاظ کے معانی" rather than the technical "غریب القرآن" (which the ar uses). The technical term is shorter and would fit a row better, but is opaque to lay readers.
- `Section` — "حصہ"; could be باب or عنوان depending on whether it heads a hadith chapter or an athkar group.
- `Chapters` — "ابواب" (hadith books). If this list is Quran chapters it must be سورتیں.
- `Bell` — "گھنٹی" as an adhan-sound option (a short chime, not the icon). Check against the sound list.
- `Off` — "بند" as a sound option; if the row means "no sound" then "کوئی نہیں" is clearer.
- `Nearby` — "آس پاس"; "قریبی مقامات" if it heads a list of cities.
- `Popular` — "مقبول"; possibly "مشہور" for reciters.
- `Grown-ups` — "بڑوں کے لیے" (kids-mode section header). Register check wanted.
- `Ask a grown-up` — "کسی بڑے سے پوچھیں"; kids-mode copy, tone check.
- `Reset` — "دوبارہ ترتیب دیں" is long for a button; "ری سیٹ" is what most Urdu UIs actually show.
- `Storage` — kept the loanword "اسٹوریج"; "ذخیرہ" is the purist option.
- `Tools` — "اوزار" is a tab label; may read oddly for zakat/qibla utilities ("سہولیات"?).
- `Adhan (Azeez)` — "اذان (عزیز)"; the ar names the reciter عاقب عزيز. If it is a person's name it should probably be "اذان (عاقب عزیز)".
- `System` (language row) — "نظام کی زبان"; iOS Urdu sometimes shows "سسٹم".
- `Egyptian General Authority` / `Moonsighting Committee` / `Muslim World League` — calculation-method names; Urdu prayer apps often leave these in English. Confirm the house style.
- `Zakat due (۲.۵%)` — settled, not open: the literal `%` is not a format specifier and stays a bare `%` (not the Arabic `٪`), and the decimal separator stays a plain `.` (Pakistan writes the dot; the Persian `٫` is not used). Digits are eastern — see Digits.
- `ON THIS DAY` — "اسی دن"; could be "آج کے دن" for a historical-events header.
- `Word-tracking surah files` — "لفظی تتبع کے لیے سورتوں کی فائلیں"; long storage-row label, likely to wrap.
- `Follow-along audio` — "لفظ کے ساتھ چلنے والی آڈیو"; descriptive rather than a term of art.
- `Repetition %lld of %lld` — reordered to "%2$lld میں سے %1$lld تکرار". Reads as "repetition 2 out of 5"; check it does not sound like a count of repetitions already done.
- `Bearing from true north` — "حقیقی شمال سے زاویہ" (angle). "سمت" (direction) is the alternative.

## Onboarding

The nine first-run strings live in `translations/ur.onboarding.json`. Kept
deliberately short — Nastaliq's line box is ~2.5× a Latin face, so these wrap
and clip fast. `Language` repeats the exact value used in `ur.json` (زبان).

- `Quran, prayer times, and athkar — private and free forever` — "قرآن، نماز کے اوقات اور اذکار — نجی اور ہمیشہ مفت". "نجی" for *private* is correct but dry; many Urdu apps just say "پرائیویٹ". This is the longest onboarding string and the likeliest to wrap in Nastaliq — if it does, drop "نماز کے اوقات" to "اوقاتِ نماز".
- `Your city for prayer times` — used the compact Persianate izafat "اوقاتِ نماز کے لیے آپ کا شہر" rather than "نماز کے اوقات کے لیے…" purely to save width. Confirm the register is not too formal for a first-run screen.
- `A beautiful adhan at every prayer. You can change or silence it anytime.` — "ہر نماز پر خوبصورت اذان۔ جب چاہیں بدل یا خاموش کر سکتے ہیں۔" I dropped the explicit "آپ اسے" from the second sentence for length; it is still unambiguous, but a reviewer may prefer the fuller "آپ اسے جب چاہیں بدل یا خاموش کر سکتے ہیں۔".
- `Maybe later` — shortened to "بعد میں" ("later") to keep the secondary button narrow. The literal "شاید بعد میں" is closer but noticeably wider.
- `Enable adhan` — "اذان فعال کریں". "فعال کریں" is the standard Urdu UI verb for *enable*; "آن کریں" is the colloquial alternative and one character shorter.
- `Welcome to Noor` — "نور میں خوش آمدید". Note the app name نور is also the ordinary Urdu word for "light", so the line reads naturally either way; no change needed, but worth a native ear.

## Digits

Decision (made after the first pass): the Urdu interface runs under the locale
`ur-u-nu-arabext`, overriding CLDR's `latn` default for `ur`, so every runtime
number — `%lld`, prayer times, dates — renders in eastern Arabic-Indic digits
(۰۱۲۳۴۵۶۷۸۹). Literal numerals in the running text of `ur.json` were therefore
converted to match: ۶۰۴ pages (3 strings), ۱۱۴ surahs (2), ۸۵ grams, ۱۲ days (2),
۲.۵%, and the unit-bound sizes below — 12 strings in all.

Deliberately left in Latin:

- Everything inside a format specifier (`%lld`, `%1$@`) — untouched.
- `2:255` in the two search-field placeholders: it shows the user what to TYPE,
  and the keyboard produces Latin.
- `ISNA`, `Dynamic Island`, and other brand/technical tokens.

Unit-bound figures follow the project-wide rule: **the unit symbol stays Latin,
the number before it does not** — `~۳۵۰ MB`, not `~350 MB`. Two digit systems in
one sentence read to a native as a rendering bug. This converted three more
strings (`Compact (~۱۰۰ MB)`, `Print quality (~۳۵۰ MB)`, and the tail of
`%lld of 604 pages · ~350 MB total`), so 12 strings in total carry eastern digits.

A final sweep of `ur.json` for any line mixing the two digit systems comes back
clean: the only Latin numerals left anywhere in the file are the two `2:255`
search examples, which contain no eastern digits alongside them.

Settled, not open questions: decimal separator is a plain `.` (Pakistan writes
the dot, not the Persian `٫`); percent is a bare `%`, not `٪`.
