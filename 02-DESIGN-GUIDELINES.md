# Noor — Design Guidelines
### For Claude Design & the DesignSystem package

The design goal in one line: **a quiet, luminous space that honors the Word of
Allah — the app disappears, the Quran remains.**

---

## 1. Design Principles

1. **Reverence over decoration.** The Arabic text is the hero of every screen.
   No visual element may compete with it. When in doubt, remove.
2. **Sakinah (tranquility).** Generous whitespace, slow subtle motion, soft
   contrast. Reading Quran should feel like entering a masjid, not an app.
3. **Offline confidence.** Never show spinners for core content. Downloaded =
   instant. Design empty/downloading states to feel calm, not broken.
4. **Two reading postures.** Focused immersion (reader) vs. quick glance
   (prayer times, daily hadith). Design each screen knowing which it is.
5. **Universal ummah.** Flawless RTL, Dynamic Type up to accessibility sizes,
   VoiceOver, and no cultural assumptions beyond Islam itself.
6. **Geometry, not imagery.** Draw from Islamic geometric art (8-fold /
   16-fold patterns) used sparingly as texture — never photos of people,
   never mosque-photo clichés on every screen.

---

## 2. Color System

Inspired by mushaf pages, prayer at fajr, and masjid interiors.

### Light mode ("Mushaf")
| Token | Hex | Use |
|---|---|---|
| `bg/primary` | `#FAF6EE` | App background — warm paper, like mushaf pages |
| `bg/elevated` | `#FFFFFF` | Cards, sheets |
| `ink/primary` | `#1F2933` | Arabic & primary text (near-black, softened) |
| `ink/secondary` | `#5C6670` | Translations, metadata |
| `accent/primary` | `#0E6B5C` | Deep masjid green — actions, active states |
| `accent/gold` | `#B98A2F` | Ayah markers, surah ornaments, highlights (use sparingly) |
| `state/reciting` | `#0E6B5C` at 12% | Background of currently-recited ayah |
| `state/bookmark` | `#B98A2F` | Bookmark indicators |
| `semantic/prayer-next` | `#0E6B5C` | Next prayer emphasis |

### Dark mode ("Tahajjud")
| Token | Hex | Use |
|---|---|---|
| `bg/primary` | `#0F1512` | Very dark warm green-black, easy at night |
| `bg/elevated` | `#1A211D` | Cards, sheets |
| `ink/primary` | `#EDE7DA` | Text — warm off-white, not pure white |
| `ink/secondary` | `#9AA49E` | Secondary text |
| `accent/primary` | `#4FB3A0` | Lightened green |
| `accent/gold` | `#D8B25E` | Ornaments/highlights |
| `state/reciting` | `#4FB3A0` at 16% | Recited ayah background |

Rules:
- Contrast: body text ≥ 7:1, secondary ≥ 4.5:1 (WCAG AAA target for reading).
- Gold is an *accent of honor* — surah headers, ayah-end markers, sajdah marks.
  If gold appears more than ~3 times on a screen, you're overusing it.
- A third "Sepia/Night-shift" reader theme is a v1.1 nice-to-have.

---

## 3. Typography

| Role | Font | Notes |
|---|---|---|
| Quran Arabic | **KFGQPC Uthmanic Hafs** (bundled) | Only this (or QCF page fonts) for ayat. Never render Quran in system Arabic fonts. |
| Arabic UI / hadith Arabic | SF Arabic | System font — free, excellent, Dynamic Type |
| Latin UI & translations | SF Pro / New York | SF Pro for UI; **New York (serif) for translation & tafsir body** — gives a "sacred book" reading feel |
| Numerals | Localized (Arabic-Indic in Arabic UI) | Follow locale |

Scale (Dynamic Type–relative, base @ Large):
- Quran text: default 26pt, user-adjustable 20–44pt, line-height 2.0–2.2
  (Arabic script with harakat needs tall lines — never clip diacritics!)
- Translation body: 17pt New York, line-height 1.5
- Tafsir body: 16pt, line-height 1.6
- Screen titles: SF Pro 28pt semibold; section headers 20pt semibold
- Metadata/captions: 13pt

Rules:
- Test every Arabic text style with full tashkeel + superscript alef + sajdah
  marks. Clipped harakat = release blocker.
- Quran font size control lives *in the reader* (pinch + slider), separate
  from system Dynamic Type; UI text follows Dynamic Type.

---

## 4. Iconography & Ornament

- SF Symbols throughout for UI (weight: regular; scale: medium).
- Custom symbols needed: qibla/kaaba, sajdah mark, juz marker, ayah-end
  rosette, misbaha. Draw as SF Symbol–compatible SVGs (mono, hierarchical).
- Surah headers: a single refined geometric ornament frame (gold, thin
  stroke) — one design used consistently, not a different frame per surah.
- Ayah end marker: traditional rosette ۝ with number inside, in gold.
- App icon: minimal geometric star/rub-el-hizb motif in deep green + gold on
  paper background. No text, no crescent-and-photo clichés.

---

## 5. Motion

- Palette: fades and gentle 0.25–0.35s ease-in-out. Nothing bouncy.
- Page turns (mushaf page mode): horizontal slide with subtle parallax; RTL
  direction (pages advance right-to-left) — this is critical and often done wrong.
- Recitation highlight: 200ms crossfade between ayat, auto-scroll keeps the
  active ayah in the upper third of the screen.
- Prayer countdown: no ticking animations; update minute-level, calmly.
- Respect Reduce Motion: replace slides with fades.

---

## 6. Key Screens (design these in Claude Design, in this order)

### 6.1 Home / Today
Quick-glance posture. Top: Hijri + Gregorian date. Hero card: next prayer
with countdown ("Asr in 1h 24m") + small daily progress (khatmah). Below:
Continue Reading card (surah, ayah, % progress) → Daily Hadith card (short,
with source e.g. "Riyad as-Salihin 1/13") → Daily Ayah. Max 4 cards. Calm.

### 6.2 Quran Reader (flow mode) — THE screen; spend 50% of design effort here
- Chrome-less by default: text on paper, tap to reveal top bar (surah name,
  juz, page) and bottom bar (audio, bookmark, font size, tafsir).
- Ayah interactions: tap = select (subtle underline glow); long-press =
  context sheet (Play from here / Tafsir / Bookmark / Copy / Share).
- Translation display modes: Arabic-only / inline below each ayah / side-by-side (iPad).
- Audio bar (when playing): compact floating pill — reciter avatar, ayah ref,
  play/pause, repeat. Expands to full player sheet.

### 6.3 Surah & Navigation Index
Segmented: Surah / Juz / Bookmarks. Surah rows: calligraphic surah name
(Arabic) + transliteration + meaning + ayah count + Makki/Madani glyph.
Fast alphabet/number scrubber. Search field (surah name, ayah number "2:255").

### 6.4 Prayer Times
Today's five prayers as a vertical timeline, current segment highlighted;
next prayer enlarged with countdown. Week view swipe. Per-prayer notification
toggle + sound choice inline (bell / adhan short / silent). Settings link:
calculation method, madhab, manual location.

### 6.5 Tafsir Sheet
Slides over reader (half → full). Header: the ayah itself (small, gold
frame). Tafsir source picker (chips). Serif body, comfortable measure
(~65ch). Download state per tafsir pack.

### 6.6 Hadith
Collections grid → book list → hadith reader. Hadith card anatomy: narrator
line (secondary), Arabic matn (SF Arabic, larger), translation (serif),
grade badge (Sahih = green outline chip), reference. Share-as-image action.

### 6.7 Daily Hadith notification & widgets
- Notification: hadith excerpt ≤ 140 chars + source; tapping opens full hadith.
- Widgets: (S) next prayer countdown; (M) today's prayer row; (M) daily
  ayah/hadith on paper texture. Lock Screen: next prayer inline + circular.

### 6.8 iPad & Mac adaptations
- iPad: NavigationSplitView — index sidebar + reader; tafsir as trailing
  third column in landscape.
- Mac: same split + **menu-bar extra**: countdown to next prayer, click →
  popover with today's times + daily hadith. Reader in resizable window,
  ⌘+/- font size, full keyboard navigation.

---

## 7. Voice & Microcopy

- Tone: warm, humble, serving. Never gamified-pushy ("Streak lost! 😱" — never).
- Honorifics: always "Prophet Muhammad ﷺ"; "Allah ﷻ" optional but consistent.
- Islamic terms stay in transliteration with first-use gloss: adhan, juz,
  khatmah, sajdah.
- Empty states as gentle invitations: "Your bookmarks will gather here."
- Notifications: "It's time for Maghrib · 6:42 PM" — no exclamation marks.
- Attribution lines always present on shared images: reciter/translator/
  collection + app name small.

## 8. RTL & Localization Rules
- The mushaf is ALWAYS RTL regardless of UI language.
- In Arabic UI, the entire app mirrors (navigation, chevrons, swipes).
- Never mirror: audio progress? — mirrors; playback icons (play triangle) — do
  NOT mirror; numerals order — follow locale.
- Test matrix: EN-LTR, AR-RTL, large Dynamic Type, dark mode — every screen.

## 9. Accessibility Checklist (per screen)
- [ ] VoiceOver reads ayah number + Arabic + translation in logical order
- [ ] All tap targets ≥ 44×44pt
- [ ] Reader works at largest accessibility type size (UI text)
- [ ] Reduce Motion + Reduce Transparency variants
- [ ] Audio player fully controllable via VoiceOver rotor

---

## 10. Prompts to start with in Claude Design

1. "Using 02-DESIGN-GUIDELINES.md, create the design system: color tokens
   (light 'Mushaf' + dark 'Tahajjud'), type scale, buttons, cards, chips,
   list rows, and the surah-header ornament frame."
2. "Design screen 6.2 Quran Reader (flow mode), iPhone 15 Pro, both themes,
   states: chrome hidden / chrome visible / ayah selected / audio playing."
3. "Design 6.1 Home/Today and 6.4 Prayer Times, light + dark."
4. "Adapt reader + index to iPad split view (6.8), landscape with tafsir column."
5. "Design the four widgets and the Mac menu-bar popover (6.7, 6.8)."
