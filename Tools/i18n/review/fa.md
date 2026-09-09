# Persian (fa) review notes

Glossary terms from `GLOSSARY.md` are used verbatim (نماز، صبح، ظهر، عصر، مغرب،
عشاء، قبله، اذان، قرآن، سوره، آیه، جزء، مصحف، تجوید، تفسیر، حدیث، اذکار، دعا،
تسبیح، ختم، حفظ، قاری، روایت، هجری، سنت، نافله، سجده، طلوع آفتاب…).

## Glossary additions

| en | fa | note |
|---|---|---|
| Hizb | حزب | subdivision of a juz; kept as the Arabic loanword, as in Persian mushaf printing |
| Dhikr (singular of Athkar) | ذکر | singular used in "Connect once to download this dhikr" and "DAILY DHIKR" |
| Matn | متن | classical memorised text; plural "متون حفظ" for "Memorisation texts" |
| Nazm / didactic poem | منظومه | for "classical poems" (منظومه‌های کلاسیک), standard in Persian religious publishing |
| Line (of a matn) | بیت | a verse line of a poem, not a UI line — matches the Arabic "بيت" |
| Izhar | اظهار | tajweed rule, transliterated as in Persian tajweed books |
| Pause marks | علامت‌های وقف | |
| Ruqyah | رقیهٔ شرعی | |
| Nisab | نصاب | |
| Zakat | زکات | |
| Hawl (one hijri year) | یک سال کامل هجری | rendered descriptively, not as حول |
| Names of Allah | اسماء الحسنی | the common Persian title; "نام‌های خدا" would read as a gloss, not a section name |
| Sahih al-Bukhari and Muslim | صحیح بخاری و مسلم | |
| Warsh riwayah | روایت ورش | |
| fi sabilillah | فی سبیل‌الله | |
| Basmalah / As-salamu alaykum | السلام علیکم | left in Arabic form with Persian yeh/kaf |

**Sunni framing.** Several strings are Sunni-specific and were kept literal and
neutral rather than adapted: `Asr madhab` → «مذهب عصر» with options «حنفی» and
«شافعی، مالکی، حنبلی»; `Sunnah fasting reminders` → «یادآوری روزه‌های سنت»;
«صحیح بخاری و مسلم»; «رقیهٔ شرعی». A Persian (largely Shia) audience will read
these as the Sunni fiqh options they are — reviewer should confirm the product
wants that, since no Jafari calculation/madhab option exists in the string set.

## Low confidence

- `Adhan (melodic)` → «اذان (آهنگین)» — Arabic is «مجوّد»; «مجود» is understood
  by Persian qaris but «آهنگین» is plainer for a sound-picker row. Pick one.
- `Adhan (Azeez)` → «اذان (عزیز)» — reciter name, Arabic file has «عاقب عزيز».
  Confirm the intended person and the Persian spelling.
- `After prayer by` → «پس از نماز به‌فاصلهٔ» — a label followed by a minutes
  picker; without the screen the ezafe ending may read oddly. Alternative:
  «چند دقیقه پس از نماز».
- `Egyptian General Authority` → «هیئت عمومی مصر» — this is the Egyptian General
  Authority of Survey (prayer-calc method). Persian apps often just write
  «مصر (هیئت عمومی مساحت)». Reviewer should choose the familiar label.
- `Muslim World League` → «رابطهٔ جهان اسلام» — also seen as «رابطة العالم
  الاسلامی» untranslated in Persian prayer apps.
- `Moonsighting Committee` → «کمیتهٔ رؤیت هلال» — the org is
  "Moonsighting Committee Worldwide"; may need to stay Latin/transliterated.
- `Follow-along audio` → «صوت هم‌زمان با متن» — word-tracking playback. Also
  possible: «صوت با دنبال‌کردن واژه‌ها» (clearer, longer, may overflow).
- `Reader options` → «گزینه‌های صفحهٔ خواندن» — "reader" is the reading view,
  not the qari; the shorter «تنظیمات خواندن» may be better and fits narrower.
- `Ayah actions` → «گزینه‌های آیه» — an accessibility label for the ayah sheet;
  «کارهای آیه» is more literal but less natural.
- `Chapters` → «ابواب» (hadith) vs `Play chapter` → «پخش فصل» (learning text).
  The English key is the same word for two different structures; confirm both.
- `Count` → «تعداد» — the tasbih counter label; «شمار» is shorter if the row is
  tight.
- `Off` → «خاموش» — this is the "no sound" option in the adhan sound list, where
  Arabic uses «بدون». «بدون صدا» may read better but collides with `Silent`.
- `Bell` → «زنگ» — a notification-sound name; if it is the bell *icon* label on
  the prayer row, «زنگوله» is better.
- `Mark this line` / `Go to marked line` / `Remove mark` → «نشان‌کردن این بیت» /
  «رفتن به بیت نشان‌شده» / «برداشتن نشان» — distinct from `Bookmark` («نشانک»);
  confirm the two concepts stay visually distinct in Persian.
- `Bearing from true north` → «زاویه نسبت به شمال حقیقی» — technical; a compass
  screen may prefer «سمت از شمال حقیقی».
- `Net wealth` → «خالص دارایی» vs `Zakatable wealth` → «دارایی مشمول زکات» —
  both are calculator row labels and should be visibly different; check they are.
- `Debts due now (subtract)` → «بدهی‌های حالّ (کسر می‌شود)» — «حالّ» is fiqh
  register; «بدهی‌های سررسیدشده» is plainer but less precise.
- `Business inventory` → «موجودی کالای تجاری» — long for a form row; may need
  «کالای تجاری».
- `Send the app to family and friends — a poster with the store links, ready for
  a status.` → «…آمادهٔ گذاشتن در استوری» — "status" rendered as استوری
  (WhatsApp/Instagram). «استاتوس» is the other option.
- `That's not it — here's a new one.` → «درست نبود — این هم یک سؤال تازه.» — kids
  quiz; register is deliberately informal, and «سؤال» assumes the item is a
  question. Verify against the kids screen.
- `Your stars` → «ستاره‌های تو» — informal «تو» because it is a kids screen,
  while every other string uses formal «شما». Intentional; confirm.
- `Age %lld` → «%lld ساله» — reads "…years old"; if it labels a stepper the form
  «سن: %lld» may be needed.
- `%lld min` / `%@ min` → «%lld دقیقه» — no standard short Persian abbreviation;
  this is longer than "min" and may overflow compact time rows («دق» exists but
  looks clipped).
- `%lld of 604 pages · ~350 MB total` → «%lld از ۶۰۴ صفحه · در مجموع ~۳۵۰
  مگابایت» — the `~` was kept as required; Persian normally writes «حدود».
- `Storage` → «فضای ذخیره» — iOS Persian has no fixed term; «حافظه» also used.
- `App font` / `Mushaf typeface` → «قلم برنامه» / «قلم مصحف» — «قلم» is the
  correct typographic term but «فونت» is what most Persian UIs show.
- Literal numerals (۶۰۴، ۱۱۴، ۱۲، ۸۵، ۲٫۵) were written with Persian digits to
  match the Arabic file; the `2:255` search hints stay Latin because the user
  types them. Confirm this matches how `%lld` renders at runtime.
- `Zakat due (2.5%)` keeps a bare Latin `%` (not ٪) so the specifier count is
  identical to the source string; ٪ would be the Persian typographic choice if
  the string is never passed through `String(format:)`.

## Onboarding

Nine first-run strings in `translations/fa.onboarding.json`. `Language` repeats
the `fa.json` value «زبان» verbatim. Uncertain ones:

- `Welcome to Noor` → «به نور خوش آمدید» — «نور» is both the app name and the
  ordinary word for "light", so the sentence can be read as "welcome to the
  light". That is arguably a nice reading for this app, but if the brand must be
  unmistakable the Latin «به Noor خوش آمدید» is the alternative. Reviewer decides.
- `Quran, prayer times, and athkar — private and free forever` → «قرآن، اوقات
  نماز و اذکار — خصوصی و همیشه رایگان» — one line on a splash screen and already
  long; «خصوصی» carries "private" in the data sense, which some Persian readers
  will first read as "personal". «حریم خصوصی شما محفوظ» is clearer but will not
  fit on one line.
- `Your city for prayer times` → «شهر شما برای اوقات نماز» — literal; as a step
  title «شهر شما» alone or «شهر خود را انتخاب کنید» may read better cold.
- `Enable adhan` → «فعال کردن اذان» — **RESOLVED, do not "fix" this.** The
  button requests the notification permission and switches adhan notifications
  on; it plays no sound at all. So the literal "turn on" reading is correct and
  «پخش اذان» ("play the adhan") would be wrong — it promises playback that
  never happens.
- `Maybe later` → «شاید بعداً» — natural and short (9 chars). «بعداً» alone is
  shorter still if the secondary button is tight.
- `Continue` → «ادامه» — matches iOS Persian convention; «ادامه دادن» is the
  verb form, not needed on a button.
- `A beautiful adhan at every prayer…` → «اذانی دلنشین در وقت هر نماز. هر زمان
  بخواهید می‌توانید آن را عوض یا بی‌صدا کنید.» — «دلنشین» for "beautiful" (of a
  sound); «زیبا» is the flat literal. «بی‌صدا کردن» reuses the `Silent` wording
  from `fa.json`, which is intentional.

## Settled decisions (do not change without asking)

- **Numerals.** The interface runs under the `fa` locale, so every `%lld`
  renders in Persian digits at runtime. Literal numerals in running text are
  therefore written in Persian digits too (۶۰۴، ۱۱۴، ۱۲، ۸۵، ۳۵۰، ۱۰۰), so a
  sentence never mixes two digit systems. Verified: the only Latin digits left
  in `fa.json` are the `2:255` search-input examples, which the user types
  literally. `ISNA` and `Dynamic Island` stay Latin as brand/technical tokens.
- **Decimal separator.** Persian `٫` (U+066B, Arabic decimal separator), not a
  plain dot and not the Urdu convention. The only decimal in the catalog is
  `Zakat due (2.5%)` → «زکات واجب (۲٫۵%)» — confirmed U+066B, no ASCII dot.
- **Storage units.** Written out as «مگابایت» rather than the Latin symbol `MB`
  («فشرده (~۱۰۰ مگابایت)»), which is what Persian iOS shows. This satisfies the
  no-mixed-digits rule outright, since no Latin token sits beside the figure at
  all. If cross-language visual consistency is preferred over native Persian
  convention, the three storage strings can switch to «~۳۵۰ MB» — the figures
  are already Persian either way.
- **Percent sign.** `Zakat due (2.5%)` keeps a bare Latin `%` rather than «٪» so
  the specifier count matches the English source exactly. Note the source string
  itself contains an unpaired `%`, which would misparse in any language if it
  were ever passed through `String(format:)`.
