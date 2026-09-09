# Turkish (tr) — reviewer notes

## Glossary additions

Terms settled here that are not in `GLOSSARY.md` (Diyanet-style Turkish usage):

| en | tr | note |
|---|---|---|
| Translation (of the Quran) | Meal | Standard Turkish term for a Quran translation; used for "Translation", "Translation audio", "Show translation". |
| Hizb | Hizip | Turkish orthography of حزب; declines as *hizbin*, so kept bare in "%lld. hizip". |
| Tahajjud | Teheccüd | Dark theme name. |
| Warsh / Hafs | Verş / Hafs | Turkish Islamic publishing writes Verş; Hafs stays as-is. |
| Nisab | Nisap | Bare form *nisap*, but suffixed forms soften: *nisabın*, *nisabı*. |
| Zakat | Zekât | With circumflex, as in Diyanet publications. |
| Wudu | Abdest | Native Turkish word, not "vudû". |
| Masjid | Cami | "mescit" is possible but "cami" is the everyday word. |
| Iẓhār | İzhar | Tajweed rule name, Turkish spelling. |
| Matn (متن) | Metin | Rendered as ordinary "metin"; Turkish has no distinct loan for the technical sense. |
| Names of Allah | Esmâü'l-Hüsnâ | Standard Turkish title. |
| Line (of a memorisation poem) | Beyit | ar بيت = a verse of poetry, not a UI "satır". |
| Makki / Madani (surah) | Mekki / Medeni | Surah classification, distinct from "Medine baskısı" (the print). |
| Hisn al-Muslim | Hısnu'l-Müslim | Transliteration used by Turkish editions. |
| fi sabilillah | fî sebîlillâh | Kept as a transliterated phrase. |

## Low confidence

- `After prayer by` → "Namazdan sonra" — English is a fragment ending in "by" followed by a minutes value. If the picker shows "Namazdan sonra  10 dk" this reads fine; if not, "Namazdan sonra (dakika)" is better.
- `Finish the Quran in` → "Kur'an'ı bitirme süresi" — turned into a noun label because the English fragment ("in ___ days") cannot end a Turkish sentence naturally. Check against the actual control.
- `%@ · manual` → "%@ · manuel" — "elle" is more native but "manuel" is shorter for a subtitle row. Reviewer's call.
- `Chapters` → "Bölümler" — hadith-book context (ar الأبواب); "Bablar" is the technical term but may read archaic in a list header.
- `Reader options` → "Okuma seçenekleri" — avoided "Okuyucu", which in Turkish suggests a person (and collides with Kari).
- `Reciter` → "Kari" (glossary) but `Search reciters` → "Kari ara" — the plural/accusative would be "Karileri ara"; kept bare for placeholder brevity. Confirm.
- `Egyptian General Authority` → "Mısır Genel Araştırma Kurumu" — the calculation method's full name is the Egyptian General Authority of Survey; no settled Turkish rendering.
- `Muslim World League` → "Dünya İslam Birliği" — alternatives: "Râbıta" / "İslam Dünyası Ligi".
- `Moonsighting Committee` → "Hilal Gözlem Komitesi" — the organisation name is often left in English in prayer apps.
- `Sunrise` → "Güneş" (glossary) — correct as a prayer-timetable row, but as a standalone label some may expect "Güneş doğuşu".
- `Fajr` → "İmsak" (glossary) — note this is the *imsak* time; if the app also shows a separate imsak/sahur row somewhere, the two would collide.
- `Zakat due (2.5%)` → "Ödenecek zekât (2,5%)" — Turkish normally writes "%2,5", but a leading `%2` inside a format string is dangerous, so the percent sign was left trailing. Please confirm this is acceptable rather than risk the formatter.
- `%lld of %lld ayat` / `lines` / `stars` → "%1$lld / %2$lld ayet" — rendered as a slash ratio; the fully written "%2$lld ayetin %1$lld tanesi" is more natural prose but much longer for a row label.
- `Showing %lld of %lld — open the text to see the rest` → reordered to "%2$lld sonuçtan %1$lld tanesi gösteriliyor…"; positional specifiers used throughout. Verify the numbers are (shown, total) in that order.
- `with %@'s recitation` → "%@ tilavetiyle" — no suffix attaches to the reciter's name, so vowel harmony is safe, but a genitive ("Mishary'nin tilavetiyle") would be more idiomatic and is impossible without knowing the name.
- `It's time for %@` → "%@ vakti girdi" — deliberately suffix-free after the placeholder; "İkindi vakti girdi" reads well, but confirm the prayer names are passed in bare nominative form.
- `Near %@` → "%@ yakınında" — safe (suffix is on "yakın"), but for a city ending in a consonant this is still correct only because no case suffix touches the placeholder.
- `Ayahs %lld to %lld` → "%1$lld–%2$lld. ayetler" — the ordinal dot placement is a judgement call; alternative "%1$lld. ile %2$lld. ayetler".
- `Madani` → "Medeni" (surah class) vs `Madani print typefaces` → "Medine Mushafı yazı tipleri" — two different senses of "Madani" in the same catalog; confirm the first key really is the surah classification.
- `Grown-ups` → "Büyükler" — kids-mode section header; "Veliler" (guardians) matches the Arabic لولي الأمر more closely.
- `Bell` → "Zil" — a notification-sound option; may need "Zil sesi" if it sits next to "Sessiz"/"Ezan".
- `Match your local masjid exactly…` → "Mahalle caminizle birebir aynı olsun." — free rendering; "Yerel caminizle tam olarak eşleştirin" is more literal.
- `Play` → "Oynat" (iOS media convention) though for recitation Turkish speakers often say "Çal"/"Dinle". Consistency was chosen over idiom.
- `COMING UP IN ISLAMIC HISTORY` → "İSLAM TARİHİNDE YAKINDA" — uppercase section header; may overflow. "TARİHTE SIRADAKİ" is shorter.
- `Downloaded once, readable forever offline. Public-domain dataset…` → "Kamuya açık veri kümesi" for public domain; legal reviewers sometimes prefer "kamu malı".
- `Sunnah fasting reminders` → "Sünnet oruç hatırlatmaları" — "nafile oruç" is the more common Turkish phrase for these fasts.

## Onboarding

Nine first-run strings (`translations/tr.onboarding.json`):

- `Welcome to Noor` → "Noor'a hoş geldiniz" — the dative apostrophe follows the *pronunciation* "Nur" (back vowel, ends in a consonant), so "-a" is correct, not "-e". A reviewer seeing the written double-o may instinctively want "Noor'e"; it should stay "-a".
- `Quran, prayer times, and athkar — private and free forever` → "Kur'an, namaz vakitleri ve zikirler — gizliliğinize saygılı, sonsuza dek ücretsiz" — "private" cannot be a bare adjective here: Turkish "gizli" means *hidden/secret*, which would misdescribe the app. Rendered as "respects your privacy". It is long for one line; a shorter option is "…— gizliliğe saygılı, hep ücretsiz".
- `Enable adhan` → "Ezan bildirimlerini aç" — **do not shorten this to "Ezanı aç".** CONFIRMED BEHAVIOUR: the button requests notification permission and switches adhan notifications ON. It plays no audio. In Turkish "Ezanı aç" reads most naturally as *play the adhan* (cf. "müziği aç"), which would promise something the button does not do, so the longer "bildirimlerini" wording is deliberate. Same category as the "Noor'a" note above: correct, but looks over-long out of context. If it overflows, drop a word elsewhere — not "bildirimlerini".
- `Maybe later` → "Daha sonra" — kept to two words for the secondary button. The fuller "Belki daha sonra" is more literal but risks overflow next to the wide "Ezan bildirimlerini aç".
- `Continue` → "Devam et" — iOS Turkish system convention; "İleri" is the other common wizard label if the flow shows step arrows.
- `Your city for prayer times` → "Namaz vakitleri için şehriniz" — a noun phrase, matching the English title. If it functions as a prompt, "Namaz vakitleri için şehrinizi seçin" reads better.
- `Language` → "Dil", identical to the value in `tr.json` as requested.
- Neighbouring onboarding strings were re-checked for the same playback drift and are clean: "Her namazda güzel bir ezan…" describes what the user will hear from the notification (as the English does), and "susturabilirsiniz" (silence it) is notification-sound language, not player language.
