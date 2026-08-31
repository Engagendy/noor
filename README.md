# Noor — The Muslim's Companion for Worship

A completely free, beautiful, offline-first Quran + Sunnah + Prayer app for
iOS, iPadOS, and macOS. No ads, no subscriptions, no accounts, no tracking.
Free forever — fi sabilillah.

- **Plan:** [01-PROJECT-PLAN.md](01-PROJECT-PLAN.md)
- **Design:** [02-DESIGN-GUIDELINES.md](02-DESIGN-GUIDELINES.md)
- **Licenses & attributions:** [LICENSES.md](LICENSES.md)

## Building

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate   # produces Noor.xcodeproj (not committed)
open Noor.xcodeproj
```

To rebuild the bundled Quran database from the verbatim Tanzil sources:

```sh
python3 Tools/build_quran_db.py
```

## Structure

Feature modules are local Swift Packages (see plan §4):

- `App/` — app entry, root navigation
- `Core/DesignSystem` — color/typography tokens, bundled KFGQPC Hafs font
- `Core/ContentDB` — read-only GRDB access to the bundled Quran SQLite,
  startup checksum verification
- `Modules/QuranReader` — mushaf reading (flow mode)
- `Modules/PrayerTimes` — on-device prayer time calculation (adhan-swift)

## Quran text integrity

The Arabic text ships read-only from Tanzil.net, byte-for-byte, built by
`Tools/build_quran_db.py`, and is verified against a SHA-256 checksum at every
launch. No code path may generate or transform Quranic text.
