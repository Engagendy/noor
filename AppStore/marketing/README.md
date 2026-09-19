# App Store share images

`make_appstore_poster.py [ios|play|both]` — the argument picks the store.

- `noor-both-share.jpg` / `noor-both-status.jpg` — **what the apps bundle**
  (copied to `App/Resources/share_noor.jpg` and
  `android/app/src/main/assets/share_noor.jpg`, byte-identical). Both stores,
  one QR each, so the recipient can install on whichever phone they hold —
  an Android friend was previously sent to the App Store.
- `noor-appstore-*.jpg` / `noor-play-*.jpg` — single-store variants, for
  posting on a channel where the audience is known.

Sizes are 1080×1350 (4:5) for chats and 1080×1920 (9:16) for status.

QR readability is the constraint that drives the dual layout, not taste.
Two codes side by side are each narrower than the single one they replace, so
they are rendered at a whole number of pixels per module (resizing a
fixed-`box_size` render to an arbitrary width puts module edges on fractions
of a pixel, and the uneven columns stop it decoding once downscaled) and drop
to error-correction M, which still swallows the centre logo many times over.
Measured at ~10–12 px per module against the single poster's 10.3, decoding
down to 33% of full size where the original failed. Re-measure after any
layout change: chat apps deliver these at roughly half size.

Neither store badge is bundled artwork — both are drawn in the script. If
these ever go on a store listing or paid placement rather than a user's own
status, swap in Apple's and Google's official badges and record them in
`LICENSES.md`.

Regenerate with `make_appstore_poster.py` in a venv holding
`pillow qrcode arabic-reshaper python-bidi` (Pillow here has no raqm, so
Arabic is shaped by arabic-reshaper; SF Arabic is used because Amiri Quran
lacks presentation forms and SF Arabic has no middle-dot — separators are
drawn by hand).

## Framed store screenshots + app previews

`make_store_screens.py <raw-shots-dir> <out-dir>` wraps the raw simulator
captures (see Screenshots/README.md) in the marketing frame: headline and
subline per screen (ar/en), the capture in a phone/iPad bezel on the app's
green with the star pattern. Produces iphone69 (1320×2868), iphone65
(1284×2778) and ipad13 (2064×2752). The app previews are 23 s
1080×1920 H.264 slideshows with a slow push-in and a silent stereo track,
made with ffmpeg from the iphone69 frames.
