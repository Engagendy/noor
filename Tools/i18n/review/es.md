# Spanish (`es`) review notes

Glossary terms from `GLOSSARY.md` are used verbatim. Naturalised Spanish
forms (Corán, adán, alquibla, oración, sura, aleya) are lower-cased mid-
sentence; unnaturalised transliterations (Adhkar, Magrib, Fayr, Dhuhr, Asr,
Isha, Mushaf, Taywid, Tafsir, Hadiz, Yuz, Jatma, Nisab, Riwaya, Tasbih) keep
the glossary spelling exactly. **Check the Adhkar casing decision first** —
"Recordatorio de Adhkar" keeps the capital because the glossary gives it
capitalised; a reviewer may prefer lower-case "adhkar" mid-sentence.

## Glossary additions

| en | es | note |
|---|---|---|
| masjid | mezquita | Standard Spanish; "masyid" is not used in Spanish Muslim publishing. |
| wudu | wudú | Kept as loanword with Spanish accent; "ablución" is the alternative. |
| dhikr | dhikr | Singular of Adhkar; kept as loanword to match the glossary plural. |
| madhab | madhab | Loanword; "escuela jurídica" would not fit a settings row. |
| hizb | hizb | Loanword, lower-case mid-label. |
| matn | matn | Technical term for a memorised didactic text. |
| zakat | zakat | Masculine ("el zakat"); standard in Spanish Islamic texts. |
| nisab | nisab | Masculine ("el nisab"). |
| Ruqyah | Ruqya | Spanish-normalised spelling. |
| Tahajjud | Tahayyud | Same *j→y* transliteration convention as Fayr/Yuz/Jatma. |
| Sahih al-Bukhari | Sahih al-Bujari | Spanish *kh→j* convention. |
| Hafs / Warsh | Hafs / Warsh | Unchanged. |
| Makkah / Madinah | La Meca / Medina | Established Spanish place names. |
| Kaaba | Kaaba | Also written "Kaʿba"; "Kaaba" is the common form. |
| iẓhār | iẓhār | Left in scholarly transliteration, as in English. |
| fi sabilillah | fi sabilillah | Left untranslated, as in English and Arabic. |
| Hisn al-Muslim | Hisn al-Muslim | Book title, untranslated. |
| Names of Allah | Nombres de Allah | "Allah", not "Dios". |

## Low confidence

- `After prayer by` → **"Después de la oración"** — English is a sentence
  fragment continued by a minutes picker ("After prayer by [10] min"). The
  Spanish drops the dangling "by"; if the picker sits inline it may need to
  read "Después de la oración, a los". Needs the screen.
- `Age %lld` → **"Edad %lld"** — natural Spanish would be "%lld años", which
  reverses label and value. Kept literal to preserve the row layout.
- `It's time for %@` → **"Es hora de %@"** — the placeholder is a prayer name
  (Fayr, Magrib…). Correct Spanish wants the article ("Es hora del Fayr"),
  which cannot be inserted from the format string. Contraction *de + el* is
  also lost. Consider changing the source to include the article.
- `Live countdown` → **"Cuenta regresiva"** — es-419 form; Spain says "cuenta
  atrás". Chosen as the more widely-understood neutral option.
- `Madani` / `Makki` → **"Medinense" / "Mecana"** — these are surah revelation
  places (per the Arabic مدنية/مكية), so they agree with feminine *sura*.
  "Medinense" is invariable, "Mecana" is feminine; a reviewer may prefer the
  matched pair "Medinesa / Mecana" or "Medinense / Mequinense".
- `Moonsighting Committee` → **"Comité de Observación Lunar"** — an
  organisation name; the Arabic translates it, so it is translated here, but
  it could equally stay in English as a proper noun.
- `Quranic word meanings` → **"Palabras difíciles del Corán"** — renders غريب
  القرآن idiomatically rather than literally ("significados de palabras").
- `Count` → **"Cuenta"** — tasbih counter; could be "Recuento" or "Repeticiones"
  depending on whether it labels a number or a target.
- `Off` → **"Ninguno"** — assumed to be a sound option (masculine "sonido"). If
  the row is a feminine noun ("notificación") it must become "Ninguna".
- `Bell` / `Silent` → **"Campana" / "Silencio"** — notification-sound names;
  if they are adjectives describing a mode, "Silencioso" would be right.
- `Surah` → **"Suras"** (plural) — follows the Arabic "السور"; this key looks
  like a segmented-control/browse label, not a singular heading.
- `Line %lld`, `%lld lines`, `Mark this line` → **"Verso"** — "lines" here are
  lines of a memorisation poem (Arabic بيت), so *verso*, not *línea*. Verify
  no key in this family means a screen line.
- `Zakat due (2.5%)` → **"Zakat a pagar (2,5%)"** — decimal comma per Spanish
  convention; the bare `%` is copied from the source unescaped. Spanish
  typography would want a space before `%`, omitted for width.
- `Repeat %@×` / `Repeat %lld×` → the `×` sign is kept; Spanish sometimes
  writes "×%lld". Left in English order.
- **Clipping risk — "All 604 pages are offline"** → "Las 604 páginas están
  disponibles sin conexión" (+21 chars). Short fallback: "604 páginas sin
  conexión".
- **Clipping risk — "Hifz mode (hide text)"** → "Modo memorización (ocultar
  texto)"; fallback "Modo hifz (ocultar texto)".
- **Clipping risk — "Download for offline"** → "Descargar para usar sin
  conexión"; fallback "Descargar sin conexión".
- **Clipping risk — "After-prayer athkar reminder"** → "Recordatorio de Adhkar
  tras la oración"; fallback "Adhkar tras la oración".
- **Clipping risk — "Madani print typefaces" / "Page (Madani print)"** →
  "Tipografías del mushaf de Medina" / "Página (impresión de Medina)".
- **Clipping risk — "Quran text size"** → "Tamaño del texto del Corán";
  fallback "Texto del Corán".
- **Clipping risk — "Turn until the arrow points up"** → "Gira hasta que la
  flecha apunte hacia arriba" (qibla hint line, +14 chars).
- **Clipping risk — "COMING UP IN ISLAMIC HISTORY"** → shortened to "PRÓXIMO EN
  LA HISTORIA ISLÁMICA" (rather than "PRÓXIMAMENTE…") to fit an all-caps
  section header.
- **Clipping risk — "Plays straight through"** → "Reproduce de corrido, sin
  repetir"; the "sin repetir" comes from the Arabic and can be dropped.
- **Tab bars** — `Learn` → "Aprender", `Prayer` → "Oración", `Quran` → "Corán",
  `Tools` → "Herramientas". "Herramientas" is the longest tab label; check it
  does not truncate at large Dynamic Type.

## Onboarding

First-run screens, seen before the user has chosen anything.

- `Welcome to Noor` → **"Te damos la bienvenida a Noor"** — Apple's genderless
  formula; "Bienvenido a Noor" is shorter but marks the user as male. Long for
  a hero title (29 vs 15 chars) — check it does not wrap awkwardly.
- `Quran, prayer times, and athkar — private and free forever` →
  **"Corán, oración y Adhkar — privado y gratis para siempre"** — compressed
  "prayer times" to "oración" to keep this on ONE line (it now runs 3 chars
  shorter than the English). If a second line is acceptable, the fuller
  "Corán, horarios de oración y Adhkar — privado y gratis para siempre" is
  more accurate. Em dash preserved.
- `Your city for prayer times` → **"Tu ciudad para los horarios de oración"**
  (+12 chars) — the main clipping risk of the nine. Shorter fallback:
  "Tu ciudad para la oración".
- `Enable adhan` → **"Activar avisos del adán"** — fixed-height button; see the
  note at the end of this section for why it must not become "Activar el adán".
- `Maybe later` → **"Ahora no"** — Apple's short secondary-button idiom,
  shorter than the literal "Quizá más tarde".
- `App language` → **"Idioma de la app"**; `Language` repeats the es.json value
  **"Idioma"** exactly.
- **What `Enable adhan` actually does (do not "correct" this):** the button
  requests notification permission and switches adhan notifications ON. It
  plays no audio. So it is now **"Activar avisos del adán"**, not "Activar el
  adán" — the latter reads in Spanish as "start the adhan playing", which is
  wrong. Do not shorten it back to "Activar el adán" or to anything with
  *reproducir*/*sonar*. `Adhan notifications` in es.json is "Notificaciones del
  adán"; the button uses the shorter *avisos* purely for button width, and
  matches "Aviso antes de la oración" already used in es.json.
- The body above the button, "Un hermoso adán en cada oración. Puedes
  cambiarlo o silenciarlo cuando quieras.", does describe the adhan sounding —
  that is the English source's meaning too (it is what the notification will
  play), so it is intentional and not playback drift. "cambiarlo o silenciarlo"
  refers to the adhan sound, not to a player.
