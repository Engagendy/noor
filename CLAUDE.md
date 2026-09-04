# CLAUDE.md — standing instructions for Claude Code on this repo

## Project
Free Quran + Sunnah + Prayer app. iOS/iPadOS/macOS (Swift/SwiftUI, modules
under `Modules/` + `Core/`) AND native Android (Kotlin + Jetpack Compose,
single-module app in `android/`). The Android app mirrors iOS 100% in design
and features — when changing one platform, check whether the other needs the
same change; the iOS Swift source is the spec for Android work. Read the full
plan in `01-PROJECT-PLAN.md` and design tokens/screens in
`02-DESIGN-GUIDELINES.md` before any task. Follow the module structure in
plan section 4 exactly (iOS).

## Hard rules
1. **Quran text integrity is sacred.** Quran Arabic text lives only in the
   bundled read-only SQLite from verified sources (Tanzil/KFGQPC). Never
   generate, type, "fix," or transform Quranic text in code, tests, fixtures,
   or previews. For previews/tests, load real text from the DB or use clearly
   non-Quranic placeholder Arabic.
2. **Offline-first.** No feature may require network after initial content
   download. Any new network call needs a cached/offline path.
3. **Privacy.** No analytics SDKs, no tracking, no third-party network calls
   beyond the documented content sources. Location never leaves the device.
4. **Free forever.** No IAP, ads, or paywall code.
5. Every bundled/downloaded content source must be recorded in `LICENSES.md`
   with its license/permission and attribution string.

## Engineering conventions
- Swift 5.10+, SwiftUI, async/await; no Combine unless unavoidable.
- MVVM: Views dumb; ViewModels `@Observable`; services injected via initializer.
- One Swift Package per feature module (see plan §4). Cross-module deps only
  through `Core/*` — features never import each other.
- Persistence: GRDB for read-only content DBs; SwiftData for user data
  (bookmarks, progress, settings mirror). Migrations tested.
- All user-facing strings in String Catalogs (en + ar). Any new screen must
  be RTL-verified (add a preview with `.environment(\.layoutDirection, .rightToLeft)`).
- Use design tokens from `Core/DesignSystem` — never hard-code colors/fonts.
- Arabic Quran rendering only with bundled, verified Quran fonts: QCF page
  fonts (page mode) and Amiri Quran (flow mode — the KFGQPC text fonts
  break Quranic marks like U+06DF under Apple's shaper; verified 2026-08-31).
- Accessibility non-negotiable: labels, Dynamic Type, 44pt targets on every PR.

## Android conventions (`android/`)
- Kotlin + Compose, manual state navigation (no NavHost); tokens in
  `Theme.kt` (`NoorColor` is a REACTIVE palette — light "Mushaf" / dark
  "Tahajjud", switched via `NoorColor.apply`); Arabic-default resources with
  `values-en/` for English; per-app locale via AppCompatDelegate
  (MainActivity MUST stay an AppCompatActivity, `res/xml/locales_config.xml`
  + `android:localeConfig` MUST be declared — from API 33 the per-app locale
  goes through the system LocaleManager, which silently ignores it otherwise,
  so the language pickers do nothing — and BOTH `values/themes.xml`
  and `values-night/themes.xml` MUST stay `Theme.AppCompat` descendants —
  a Material parent crashes every system-dark device at launch).
- **Locale-safe formatting:** Kotlin `"%d".format()` uses the default locale;
  with the ar per-app locale it emits Arabic-Indic digits. ALWAYS
  `format(Locale.ROOT, …)` for URLs, filenames, and cache keys.
- Never write prefs from composition (bump a `version` int in click handlers);
  heavy IO off-main; system back wired via `BackHandler(enabled = …)`.
- Ripples must be clipped: `.clip(shape)` before `.clickable` on rounded UI.
- RTL arrow rule: forward/disclosure points LEFT in ar, RIGHT in en — use the
  explicit direction-aware helpers in `LocaleSupport.kt` (NoorIcons), never
  emoji glyphs as icons.
- `AyahActionsSheet` self-dismisses BEFORE firing its action — any state or
  coroutine the action needs must live above the sheet (screen level / a
  scope that outlives it).
- Madani page mode: QCF v2 per-page fonts are downloaded and used UNTOUCHED.
  Do NOT reintroduce a cmap patch: rewriting the file made Compose's font
  loader reject it outright ("Could not load font", thrown during layout, so
  it killed the app), and it was never what fixed the p76 l4 word overlap —
  the per-word renderer was. Lines render per-word (justified edge-to-edge
  like the print; <55%-width closing lines centered), so glyph bearings can
  never overlap a neighbouring word whatever the shaper does.
- Immersive reader: the tab bar is hidden while either Quran reader is open
  (`ReaderChrome.readerOpen`, mirroring iOS `.toolbar(.hidden, for: .tabBar)`)
  — a Madani page is a rigid 15-row grid stretched to the height it gets, so
  chrome shrinks every line. When it is hidden the bottom Column must carry
  `navigationBarsPadding()`, since `NavigationBar` was consuming that inset.
- Release signing: `android/noor-upload.keystore` + `keystore.properties`
  (gitignored — back up!). Play requires targetSdk 36+. Devices running the
  Play-signed closed-test build REJECT adb installs of locally-signed APKs
  — debug builds use applicationIdSuffix `.debug` so they install side by side.

## Testing expectations
- Unit tests for: prayer time calculations (methods, madhab, DST, high
  latitudes), notification scheduling window (≤64 pending), audio timing-file
  parsing, content-DB checksum verification, hijri date conversion.
- Snapshot or preview-based checks for reader in EN-LTR and AR-RTL.

## When unsure
Prefer studying `github.com/quran/quran-ios` (Apache-2.0) for mushaf layout,
audio timing, and download-manager patterns before inventing new approaches.
Cite in comments when an approach is adapted from it, per its license.
