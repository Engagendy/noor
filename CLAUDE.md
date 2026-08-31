# CLAUDE.md — standing instructions for Claude Code on this repo

## Project
Free Quran + Sunnah + Prayer app for iOS/iPadOS/macOS. Read the full plan in
`01-PROJECT-PLAN.md` and design tokens/screens in `02-DESIGN-GUIDELINES.md`
before any task. Follow the module structure in plan section 4 exactly.

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
- Arabic Quran rendering only with the bundled KFGQPC/QCF fonts.
- Accessibility non-negotiable: labels, Dynamic Type, 44pt targets on every PR.

## Testing expectations
- Unit tests for: prayer time calculations (methods, madhab, DST, high
  latitudes), notification scheduling window (≤64 pending), audio timing-file
  parsing, content-DB checksum verification, hijri date conversion.
- Snapshot or preview-based checks for reader in EN-LTR and AR-RTL.

## When unsure
Prefer studying `github.com/quran/quran-ios` (Apache-2.0) for mushaf layout,
audio timing, and download-manager patterns before inventing new approaches.
Cite in comments when an approach is adapted from it, per its license.
