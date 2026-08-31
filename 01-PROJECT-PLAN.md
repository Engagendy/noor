# Noor — The Muslim's Companion for Worship
### Project Plan (iOS / iPadOS / macOS)

> Working name "Noor" — rename freely. This document is the master plan.
> Use it as the shared context file for Claude Code and Claude Design.

---

## 1. Vision

A completely free, beautiful, offline-first app that helps Muslims truly worship Allah:

- Read the Quran (authentic mushaf text) with translations and tafsir
- Listen to world-class reciters, ayah-by-ayah, with synced highlighting
- Learn from authentic Sunnah: daily hadith, browsable collections
- Never miss a prayer: accurate times + adhan notifications, qibla
- No ads. No subscriptions. No accounts required. Free forever (fi sabilillah).

**Non-goals (v1):** social features, user accounts, custom tafsir authoring,
Quran memorization games, Android. Keep the scope holy and small.

---

## 2. Platforms & Tech Stack

| Layer | Choice | Why |
|---|---|---|
| Language | Swift 5.10+, SwiftUI | Single codebase for iPhone, iPad, Mac |
| Min targets | iOS 17, iPadOS 17, macOS 14 | Modern SwiftUI APIs, wide device coverage |
| Architecture | MVVM + feature modules (Swift Package per feature) | Claude Code works best with clear module boundaries |
| Persistence | SQLite (GRDB.swift) for content DBs + SwiftData for user data | Content ships as read-only SQLite; user data (bookmarks, progress) in SwiftData |
| Audio | AVFoundation (AVPlayer + AVAudioSession) | Background playback, lock-screen controls |
| Prayer times | `adhan-swift` (Batoul Apps, open source) | On-device calculation, offline, all standard methods |
| Notifications | UserNotifications framework | Local notifications — no server needed |
| Networking | URLSession + async/await, thin API client | Only for downloads & optional content |
| CI later | Xcode Cloud or GitHub Actions | Not needed for MVP |

**Mac strategy:** SwiftUI multiplatform target (not Catalyst). The Mac build's
primary jobs: menu-bar prayer countdown, prayer notifications, daily hadith,
and full Quran reading in a resizable window.

---

## 3. Data Sources (all free — verify each license before shipping)

| Content | Source | Access | Notes |
|---|---|---|---|
| Quran Arabic text | Tanzil.net (Uthmani) or KFGQPC data via Quran Foundation | Bundled in app | NEVER hand-edit. Verify checksum. |
| Mushaf page layout + word data | Quran Foundation Content API / quran-ios (QuranEngine, Apache-2.0) | Bundled + API | QuranEngine repo: github.com/quran/quran-ios |
| Translations (100+ langs) | Quran Foundation API; fallback fawazahmed0/quran-api (CDN) | Downloaded per-language | Check per-translation license notes |
| Tafsir (Ibn Kathir, Sa'di, Muyassar, Jalalayn, ...) | Quran Foundation API; spa5k/tafsir_api for offline bundles | Downloaded on demand | Arabic + translated tafsirs |
| Recitations (ayah-by-ayah MP3) | EveryAyah.com; Quran Foundation audio endpoints (with timing files) | Streamed + downloadable | Timing JSON enables ayah highlighting |
| Hadith collections | Sunnah.com API (request free key via GitHub issue) | Pre-fetch → bundle/cache | Also request offline dump. File the request issue on day 1. |
| Prayer times | adhan-swift — computed on device | Library | No API dependency |
| Hijri calendar / Qibla | On-device calculation (Foundation islamic calendars + CoreLocation bearing math); AlAdhan API as cross-check | Library | |
| Arabic Quran font | KFGQPC Uthmanic Hafs (free) or QCF page fonts from Quran Foundation | Bundled | Required for correct rendering of Quranic glyphs |

**Golden rule:** the Quran text is sacred — only verified sources, bundle it
read-only, verify integrity with a checksum at build time, and never allow any
code path to mutate it.

---

## 4. App Structure (feature modules)

```
NoorApp/
├── App/                    # App entry, root navigation, DI container
├── Modules/
│   ├── QuranReader/        # Mushaf pages, translation view, word-by-word
│   ├── QuranAudio/         # Player, reciter picker, downloads, timing sync
│   ├── Tafsir/             # Tafsir browser per ayah
│   ├── Hadith/             # Collections browser, daily hadith engine
│   ├── PrayerTimes/        # Calculation, settings (method/madhab), countdown
│   ├── Notifications/      # Adhan alerts, daily hadith push (local)
│   ├── Qibla/              # Compass view (iPhone only)
│   └── Library/            # Bookmarks, last-read, khatmah progress
├── Core/
│   ├── ContentDB/          # GRDB access to bundled/downloaded SQLite
│   ├── APIClient/          # Quran Foundation + Sunnah.com clients
│   ├── Downloads/          # Background download manager (audio, tafsir)
│   ├── DesignSystem/       # Colors, typography, components (see design doc)
│   └── Localization/       # App UI strings (English + Arabic at minimum, RTL)
└── Tests/
```

---

## 5. Roadmap — build in this order

### Phase 0 — Foundations (week 1)
- [ ] Create Xcode project: multiplatform SwiftUI app + Swift Packages per module
- [ ] Register app on Quran Foundation developer console (get credentials)
- [ ] File Sunnah.com API key request issue on GitHub (human-reviewed — do it NOW)
- [ ] Add GRDB, adhan-swift via SPM
- [ ] Bundle Quran Arabic text SQLite + KFGQPC font; render Surah Al-Fatiha raw
- [ ] Set up DesignSystem package from 02-DESIGN-GUIDELINES.md

### Phase 1 — MVP: Read + Pray (weeks 2–4)
- [ ] Quran reader: surah list, page-based mushaf view, translation toggle
- [ ] Last-read position, bookmarks
- [ ] Prayer times: location permission → adhan-swift → today view + week view
- [ ] Prayer notifications with adhan sound option (user picks per-prayer style)
- [ ] Settings: calculation method, madhab (Asr), notification preferences
- [ ] iPad layout: two-pane (surah list | reader); Mac: same + menu-bar countdown

**MVP definition of done:** a user can read the whole Quran offline with one
translation, and never miss a prayer. Ship TestFlight here.

### Phase 2 — Listen (weeks 5–6)
- [ ] Audio: stream ayah-by-ayah for 2–3 reciters (Alafasy, Husary, Minshawi)
- [ ] Synced ayah highlighting using timing files
- [ ] Repeat ayah/range (for memorization), playback speed
- [ ] Download manager: download surah/juz/whole mushaf per reciter
- [ ] Lock screen / Control Center / AirPods controls; background audio

### Phase 3 — Understand (weeks 7–8)
- [ ] Tafsir per ayah: long-press ayah → sheet with tafsir picker
- [ ] Download tafsir packs per language
- [ ] Word-by-word translation mode (Quran Foundation morphology data)

### Phase 4 — Sunnah (weeks 9–10)
- [ ] Hadith module: browse Bukhari, Muslim, Riyad as-Salihin (from cached/dumped data)
- [ ] Search hadith
- [ ] Daily hadith: local notification at user-chosen time, from Riyad as-Salihin
- [ ] Share hadith as beautiful image card (respect attribution)

### Phase 5 — Polish & Ship (weeks 11–12)
- [ ] Qibla compass; Hijri date on home screen
- [ ] Widgets: prayer countdown (Lock Screen + Home), daily ayah/hadith
- [ ] Full Arabic UI localization + RTL audit
- [ ] Accessibility: Dynamic Type, VoiceOver on every screen
- [ ] App Store assets, privacy nutrition label (should be "Data Not Collected")

---

## 6. Key Technical Decisions & Gotchas

1. **Offline-first:** every feature must work with airplane mode ON except
   initial downloads. Test this constantly.
2. **Mushaf rendering:** two modes — (a) *page mode* using QCF page fonts
   (pixel-faithful Madani mushaf pages), (b) *flow mode* using Uthmanic Hafs
   font with adjustable size + inline translation. Start with flow mode
   (simpler), add page mode in Phase 2/3. Study quran-ios before writing your own.
3. **Audio timing:** timing files map ayah → millisecond offsets in surah MP3s.
   Cache them with the audio. Highlighting = binary search on playback time.
4. **Prayer notifications limit:** iOS allows max 64 pending local notifications.
   Schedule ~10 days ahead (5–6/day) and reschedule on app open + background task.
5. **Location privacy:** compute prayer times from coarse location; allow fully
   manual city selection. Location never leaves the device — say so proudly.
6. **Adhan audio in notifications:** notification sounds max 30s — use a short
   adhan clip; full adhan plays only if app is foregrounded.
7. **API etiquette:** cache aggressively, respect rate limits, and set a proper
   User-Agent. These are charity-funded services — be gentle.
8. **Hadith data:** prefer the offline dump from Sunnah.com over live API calls
   in production. Bundle the daily-hadith collection entirely.
9. **Content licenses file:** keep `LICENSES.md` in repo listing every text,
   translation, tafsir, reciter, and font with its license/permission. Display
   attributions in Settings → About.

---

## 7. How to drive this with Claude Code

- Put this file + `02-DESIGN-GUIDELINES.md` + `CLAUDE.md` at repo root.
- Work phase by phase; one module per session. Example prompts:
  - "Read 01-PROJECT-PLAN.md. Scaffold Phase 0: multiplatform SwiftUI project
    with the module structure in section 4, SPM dependencies, and DesignSystem
    package implementing 02-DESIGN-GUIDELINES.md tokens."
  - "Implement PrayerTimes module per plan section 5 Phase 1 using adhan-swift.
    Include unit tests for calculation-method settings."
- Ask Claude Code to write tests for: prayer time edge cases (high latitudes,
  DST), notification scheduling window, timing-file parsing, DB integrity check.
- Use Claude Design first to produce the visual system & key screens from
  `02-DESIGN-GUIDELINES.md`, then hand exported specs/screens to Claude Code.

---

## 8. Success Criteria for v1.0

- Cold start → readable mushaf in under 2 seconds
- Zero network required after first run for: reading, prayer times, notifications, daily hadith
- Privacy label: Data Not Collected
- VoiceOver-navigable reader and prayer screens
- All content properly attributed; all licenses documented

Bismillah — start with Phase 0.
