# Noor Android — Release Guide

## 1. One-time: create the upload keystore

The keystore is **never** committed. Generate it once and back it up somewhere
safe (a lost upload key means a Play support ticket).

```bash
keytool -genkeypair \
  -keystore noor-upload.keystore \
  -alias noor \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=Noor, O=Engagendy"
```

Then create `android/keystore.properties` (gitignored):

```properties
storeFile=noor-upload.keystore
storePassword=YOUR_STORE_PASSWORD
keyAlias=noor
keyPassword=YOUR_KEY_PASSWORD
```

Put `noor-upload.keystore` next to it in `android/`. The release build picks
both up automatically; when they are absent, release builds are simply
unsigned (debug builds are never affected).

## 2. Versioning

Set in `app/build.gradle.kts`:

- `versionName` — user-visible, currently `1.0.0`.
- `versionCode` — must increase by at least 1 for every Play upload.

## 3. Build the Play-ready AAB

```bash
cd android
./gradlew bundleRelease
```

Output: `app/build/outputs/bundle/release/app-release.aab`.

Sanity checks before uploading:

```bash
# APK from the bundle for a local smoke test (needs bundletool):
bundletool build-apks --bundle=app/build/outputs/bundle/release/app-release.aab \
  --output=noor.apks --mode=universal
# Or just verify the signature:
jarsigner -verify app/build/outputs/bundle/release/app-release.aab
```

Smoke-test checklist on a device:
- Quran reader opens (flow + Madani page mode), text renders with Amiri/Hafs.
- Recitation plays, survives backgrounding (notification transport controls).
- Reciter picker search works; speed and repeat-ayah settings persist.
- Prayer times correct for the selected city; adhan notification fires.
- Everything above works offline except first-time audio streaming.

## 4. Play Console upload

1. Play Console → Noor → Production → Create new release.
2. Upload `app-release.aab` (use Play App Signing; the keystore above is the
   *upload* key).
3. Release notes (ar + en). App is free, no ads, no IAP — declare accordingly.
4. Data safety form: no data collected, no data shared, no third-party SDKs.
   Location (city choice) is manual and never leaves the device.
5. Content rating questionnaire: reference/religious app.

## 5. ProGuard

Release builds minify with `app/proguard-rules.pro` (keep rules for the adhan
library, org.json, and manifest entry points). If a release-only crash appears,
check `app/build/outputs/mapping/release/mapping.txt` and upload it to Play for
readable crash reports.

## Release log
- vc2 — first closed-test upload. BROKEN: Arabic-locale digits in download URLs (no mushaf fonts, no audio).
- vc3 — Locale.ROOT URL fix.
- vc4 — + dark-mode launch-crash fix (values-night theme must stay AppCompat). Uploaded to closed track 2026-09-02.
- vc5 (pending) — back-navigation sweep, Madani per-word justification + QCF cmap patch (p76 overlap), page-font retry, audio cache/prefetch/retry + buffering spinner, onboarding language picker + auto-locate. VERIFY the Madani fix on a device first (Samsung has the Play-signed build — adb installs rejected; use the Huawei/S25 or a Play upload).
