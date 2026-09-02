# Noor — Google Play listing (copy-paste ready)

## App details
- App name: **نور — القرآن والصلاة** (default ar) / **Noor - Quran & Prayer** (en-US)
- Category: **Books & Reference** (alt: Lifestyle)
- Free. No ads. No in-app purchases. Contains no ads → declare "No ads".
- Contact email: engagendy@gmail.com
- Privacy policy URL: publish `docs/privacy.md` (GitHub Pages) and paste the URL — REQUIRED before submitting.

## Short description (max 80 chars)
- ar: المصحف المدني، ٣١ قارئًا، مواقيت الصلاة والأذكار — مجاني للأبد بلا إعلانات
- en: The Madani mushaf, 31 reciters, prayer times & athkar. Free forever, no ads.

## Full description
Use the App Store description from `AppStore/metadata.md` (both ar and en) with two edits for Android:
- Replace "synced privately through your own iCloud" → ar: «تُحفظ إشاراتك وموضع قراءتك على جهازك» / en: "bookmarks and reading position stay on your device".
- Replace the Live Activity/Dynamic Island line (if present) with home-screen widgets: ar: «أدوات على الشاشة الرئيسية للصلاة التالية وآية اليوم» / en: "Home-screen widgets for the next prayer and the daily ayah".

## Release notes 1.0.0
- ar: الإصدار الأول: المصحف المدني كاملًا، ٣١ قارئًا مع الترديد والحفظ، مواقيت الصلاة والأذان، القبلة، التقويم الهجري، حصن المسلم، الحديث، خطة الختمة، الوضع الداكن، وواجهة عربية وإنجليزية.
- en: First release: the full Madani mushaf, 31 reciters with repeat & memorization, prayer times with adhan, qibla, hijri calendar, Hisn al-Muslim, hadith, khatmah plans, dark mode, Arabic & English.

## Data safety form (Play Console → App content → Data safety)
- Does your app collect or share any of the required user data types? **No**
- Is all of the user data collected by your app encrypted in transit? N/A (nothing collected)
- Location: the app requests coarse location ONLY to compute prayer times/qibla **on device**; it is never transmitted, stored remotely, or shared → under Play's definitions this is *not* "collected" (processed ephemerally on device). Answer **No data collected**.
- No third-party SDKs, no analytics, no ads SDKs.

## Content rating questionnaire
- Category: Reference/Educational. No violence, no user-generated content, no chat, no gambling, no ads. Expected rating: Everyone / PEGI 3.

## App access
- All features available without login (no credentials needed) → "All functionality is available without special access".

## Assets in this folder
- `icon-512.png` — hi-res icon (512×512).
- `feature-graphic.png` — 1024×500 feature graphic.
- Screenshots: take 4–8 phone screenshots (portrait, ≥1080px) — Today, Madani page, surah list/reader, prayer tab, athkar, dark mode. `adb exec-out screencap -p > s1.png` per screen.

## Upload steps
1. Play Console → Create app → name as above, App/Game=App, Free.
2. App content: privacy policy URL, data safety (above), content rating, target audience (Everyone), "News app? No", "COVID app? No".
3. Production → Create release → enable **Play App Signing** → upload `app/build/outputs/bundle/release/app-release.aab`.
4. Paste release notes, save, review, roll out.

## Signing (already done on this Mac)
- Upload keystore: `android/noor-upload.keystore` + `android/keystore.properties` (both gitignored). **BACK BOTH UP** (password is inside keystore.properties). A lost upload key requires a Play support ticket.
