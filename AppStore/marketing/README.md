# App Store share images

- `noor-appstore-share.jpg` — 1080×1350 (4:5), for sharing in chats.
- `noor-appstore-status.jpg` — 1080×1920 (9:16), for WhatsApp / Instagram status.

Both carry a QR code to https://apps.apple.com/ae/app/noor-al-muslim/id6807128479
(verified to decode at full size and at 50%, roughly what WhatsApp delivers).

Regenerate with `make_appstore_poster.py` in a venv holding
`pillow qrcode arabic-reshaper python-bidi` (Pillow here has no raqm, so
Arabic is shaped by arabic-reshaper; SF Arabic is used because Amiri Quran
lacks presentation forms and SF Arabic has no middle-dot — separators are
drawn by hand).
