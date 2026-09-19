import math, qrcode
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import arabic_reshaper
from bidi.algorithm import get_display

import sys
STORE = sys.argv[1] if len(sys.argv) > 1 else "ios"
IOS_LINK = "https://apps.apple.com/ae/app/noor-al-muslim/id6807128479"
# Same destination, four modules smaller — used only where two QRs share a row.
IOS_LINK_SHORT = "https://apps.apple.com/app/id6807128479"
PLAY_LINK = "https://play.google.com/store/apps/details?id=com.engagendy.noor"
# "both" is the poster the APPS bundle: one image a recipient can act on
# whichever phone they hold, so an Android friend is not sent to the App Store.
LINK = PLAY_LINK if STORE == "play" else IOS_LINK
PAPER, INK, INK2, GREEN, GOLD = "#FAF6EE", "#1F2933", "#5C6670", "#0E6B5C", "#B98A2F"
AR = "/System/Library/Fonts/SFArabic.ttf"
LAT = "/System/Library/Fonts/SFNS.ttf"
ICON = "/Users/engagendy/Documents/projects/noor/android/PlayStore/icon-512.png"

_reshaper = arabic_reshaper.ArabicReshaper(configuration={'delete_harakat': False, 'support_ligatures': True})
def ar(s): return get_display(_reshaper.reshape(s))
def F(path, size):
    try: return ImageFont.truetype(path, size)
    except Exception: return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", size)

def rounded_icon(size, radius_ratio=0.225):
    im = Image.open(ICON).convert("RGBA").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size*4, size*4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0,0,size*4-1,size*4-1], radius=int(size*4*radius_ratio), fill=255)
    im.putalpha(mask.resize((size,size), Image.LANCZOS))
    return im

def star8(d, cx, cy, r, fill):
    # Two squares rotated 45° = the eight-point star used across the app.
    for rot in (0, math.pi/4):
        pts = [(cx + r*math.cos(rot + k*math.pi/2), cy + r*math.sin(rot + k*math.pi/2)) for k in range(4)]
        d.polygon(pts, fill=fill)

def hero_pattern(w, h):
    layer = Image.new("RGBA", (w, h), (0,0,0,0)); d = ImageDraw.Draw(layer)
    step = 150
    for y in range(-step, h+step, step):
        for x in range(-step, w+step, step):
            off = step//2 if (y//step) % 2 else 0
            star8(d, x+off, y, 42, (255,255,255,10))
    return layer

def qr_image(size, logo, link=None, ec=qrcode.constants.ERROR_CORRECT_H):
    q = qrcode.QRCode(error_correction=ec, box_size=1, border=2)
    q.add_data(link or LINK); q.make(fit=True)
    im = q.make_image(fill_color=GREEN, back_color="white").convert("RGBA")
    # Scale by a WHOLE number of pixels per module. Resizing a fixed-box_size
    # render to an arbitrary width lands module edges on fractions of a pixel,
    # and the uneven columns that produces are what stopped the pair decoding
    # once the image is downscaled — which is exactly what chat apps do.
    factor = max(1, size // im.width)
    size = im.width * factor
    im = im.resize((size, size), Image.NEAREST)
    # Small icon in the centre — H-level correction tolerates it comfortably.
    l = rounded_icon(int(size*(0.18 if logo == "small" else 0.2)), 0.25)
    pad = 10
    plate = Image.new("RGBA", (l.width+pad*2, l.height+pad*2), "white")
    ImageDraw.Draw(plate).rounded_rectangle([0,0,plate.width-1,plate.height-1], radius=24, fill="white")
    plate.alpha_composite(l, (pad,pad))
    im.alpha_composite(plate, ((size-plate.width)//2, (size-plate.height)//2))
    return im

def shadow_card(base, box, radius, fill="white", blur=28, alpha=40):
    x0,y0,x1,y1 = box
    sh = Image.new("RGBA", base.size, (0,0,0,0))
    ImageDraw.Draw(sh).rounded_rectangle([x0,y0+14,x1,y1+14], radius=radius, fill=(31,41,51,alpha))
    base.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))
    ImageDraw.Draw(base).rounded_rectangle(box, radius=radius, fill=fill)

def apple_badge(d, cx, cy, w=420, h=104):
    if STORE == "play": return play_badge(d, cx, cy, w, h)
    x0, y0 = cx - w//2, cy - h//2
    d.rounded_rectangle([x0,y0,x0+w,y0+h], radius=h//2, fill="#111111", outline="#A6A6A6", width=2)
    logo = F(LAT, 58)
    d.text((x0+36, cy), "", font=logo, fill="white", anchor="lm")
    d.text((x0+112, cy-24), "Download on the", font=F(LAT, 22), fill="white", anchor="lm")
    d.text((x0+112, cy+16), "App Store", font=F(LAT, 40), fill="white", anchor="lm")

def dotted_line(d, cx, y, parts, font, fill, dot=GOLD, gap=34):
    """Arabic phrases with hand-drawn gold dots between them (SF Arabic has
    no middle-dot glyph). Laid out right-to-left."""
    shaped = [ar(p) for p in parts]
    widths = [d.textlength(t, font=font) for t in shaped]
    total = sum(widths) + gap*2*(len(parts)-1)
    x = cx + total/2   # right edge
    for i, (t, w) in enumerate(zip(shaped, widths)):
        d.text((x, y), t, font=font, fill=fill, anchor="rt")
        x -= w
        if i < len(parts)-1:
            x -= gap
            d.ellipse([x-5, y+font.size*0.42, x+5, y+font.size*0.42+10], fill=dot)
            x -= gap

def play_mark(d, x, cy, s):
    """The Play triangle, four colours around its horizontal axis. Drawn, not
    bundled: neither store badge ships as artwork here (see README)."""
    top, bot, tip = cy - s*0.52, cy + s*0.52, x + s*0.92
    d.polygon([(x, top), (x, cy), (x + s*0.46, cy - s*0.26)], fill="#00A0FF")
    d.polygon([(x, cy), (x, bot), (x + s*0.46, cy + s*0.26)], fill="#00E676")
    d.polygon([(x + s*0.46, cy - s*0.26), (tip, cy), (x + s*0.46, cy + s*0.26)], fill="#FFCE00")
    d.polygon([(x, top), (x + s*0.46, cy - s*0.26), (x + s*0.20, cy - s*0.40)], fill="#FF3A44")

def play_badge(d, cx, cy, w=420, h=104):
    x0, y0 = cx - w//2, cy - h//2
    d.rounded_rectangle([x0,y0,x0+w,y0+h], radius=h//2, fill="#111111", outline="#A6A6A6", width=2)
    play_mark(d, x0 + int(w*0.085), cy, h*0.52)
    tx = x0 + int(w*0.27)
    d.text((tx, cy-24), "GET IT ON", font=F(LAT, int(h*0.21)), fill="white", anchor="lm")
    d.text((tx, cy+16), "Google Play", font=F(LAT, int(h*0.38)), fill="white", anchor="lm")

def store_badge(d, cx, cy, store, w=420, h=104):
    """One badge, explicitly chosen — `apple_badge` switches on the global."""
    if store == "play":
        play_badge(d, cx, cy, w, h)
        return
    x0, y0 = cx - w//2, cy - h//2
    d.rounded_rectangle([x0,y0,x0+w,y0+h], radius=h//2, fill="#111111", outline="#A6A6A6", width=2)
    d.text((x0+int(w*0.085), cy), "\uF8FF", font=F(LAT, int(h*0.56)), fill="white", anchor="lm")
    tx = x0 + int(w*0.27)
    d.text((tx, cy-24), "Download on the", font=F(LAT, int(h*0.21)), fill="white", anchor="lm")
    d.text((tx, cy+16), "App Store", font=F(LAT, int(h*0.38)), fill="white", anchor="lm")

def render(W, H, out):
    im = Image.new("RGBA", (W, H), PAPER)
    m = 48
    footer_h = 140
    # Pick the largest QR that still leaves the hero a sensible height, then
    # give the hero whatever remains (capped) and spread any slack.
    if STORE == "both":
        # Two QRs side by side, a badge under each. Sized so the pair plus the
        # gutter still clears the card's inner margins.
        # Two QRs must each stay as readable as the single one they replace:
        # the original rendered ~9.8 px per module, and a chat app halving the
        # image is the case that matters. Lower correction (M) buys back the
        # versions the pair costs, so the pixels-per-module survives; the hero
        # gives up the height instead, being the decorative half.
        for qr_size in (410, 380, 350, 320):
            badge_w = min(int((W - 2*m - 220) / 2), 400)
            card_h = 40 + 46 + qr_size + 18 + 34 + 16 + 100 + 40
            hero_h = H - (m + 32 + card_h + 30 + footer_h + m)
            if hero_h >= 340: break
    else:
        for qr_size in (440, 400, 360, 330):
            card_h = 40 + qr_size + 24 + 56 + 60 + 104 + 40
            hero_h = H - (m + 32 + card_h + 30 + footer_h + m)
            if hero_h >= 430: break
    hero_h = min(hero_h, 600)
    used = m + hero_h + 32 + card_h + 30 + footer_h + m
    extra = max(0, H - used)
    gap_a, gap_b = 32 + extra//3, 30 + extra//3

    # ---- hero card -----------------------------------------------------
    hero = [m, m, W-m, m+hero_h]
    shadow_card(im, hero, 44, fill=GREEN)
    pat = hero_pattern(W-2*m, hero_h)
    pm = Image.new("L", pat.size, 0); ImageDraw.Draw(pm).rounded_rectangle([0,0,pat.width-1,pat.height-1], radius=44, fill=255)
    pat.putalpha(Image.composite(pat.getchannel("A"), Image.new("L", pat.size, 0), pm))
    im.alpha_composite(pat, (m, m))
    d = ImageDraw.Draw(im)
    icon = rounded_icon(int(hero_h*0.36))
    ix, iy = (W-icon.width)//2, m + int(hero_h*0.09)
    im.alpha_composite(icon, (ix, iy)); d = ImageDraw.Draw(im)
    y = iy + icon.height + int(hero_h*0.05)
    d.text((W//2, y), ar("نور"), font=F(AR, int(hero_h*0.19)), fill="white", anchor="mt")
    y += int(hero_h*0.235)
    d.text((W//2, y), "Noor Al-Muslim", font=F(LAT, int(hero_h*0.075)), fill=(255,255,255,235), anchor="mt")
    y += int(hero_h*0.12)
    d.text((W//2, y), ar("القرآن ومواقيت الصلاة والأذكار"), font=F(AR, int(hero_h*0.068)), fill="white", anchor="mt")
    y += int(hero_h*0.095)
    d.text((W//2, y), "Quran · Prayer Times · Athkar", font=F(LAT, int(hero_h*0.048)), fill=(255,255,255,200), anchor="mt")

    # ---- QR card -------------------------------------------------------
    top = hero[3] + gap_a
    card = [m, top, W-m, top+card_h]
    shadow_card(im, card, 40)
    if STORE == "both":
        d = ImageDraw.Draw(im)
        y = top + 40
        d.text((W//2, y), ar("امسح الرمز لتحميل التطبيق"), font=F(AR, 34), fill=INK, anchor="mt")
        y += 46
        # Right column is iOS, left is Android: the card reads right-to-left
        # like the rest of the poster.
        gutter = 60
        cols = [(W//2 - (qr_size + gutter)//2, "play"),
                (W//2 + (qr_size + gutter)//2, "ios")]
        for cx, store in cols:
            link = PLAY_LINK if store == "play" else IOS_LINK_SHORT
            # M (15%) still swallows the centre logo (~4% of the area) many
            # times over, and the versions it saves are what keep these
            # readable once a chat app has downscaled the poster.
            qr = qr_image(qr_size, "small", link, ec=qrcode.constants.ERROR_CORRECT_M)
            im.alpha_composite(qr, (cx - qr.width//2, y + (qr_size - qr.height)//2))
            d = ImageDraw.Draw(im)
            label = "Google Play" if store == "play" else "App Store"
            d.text((cx, y + qr_size + 18), label, font=F(LAT, 26), fill=INK2, anchor="mt")
            store_badge(d, cx, y + qr_size + 18 + 34 + 16 + 50, store,
                        w=badge_w, h=100)
    else:
        qr = qr_image(qr_size, True)
        im.alpha_composite(qr, ((W-qr.width)//2, top + 40 + (qr_size - qr.height)//2))
        d = ImageDraw.Draw(im)
        y = top + 40 + qr_size + 24
        d.text((W//2, y), ar("امسح الرمز لتحميل التطبيق"), font=F(AR, 38), fill=INK, anchor="mt")
        y += 56
        d.text((W//2, y), ("Scan to download on Google Play" if STORE == "play" else "Scan to download on the App Store"), font=F(LAT, 28), fill=INK2, anchor="mt")
        y += 60
        apple_badge(d, W//2, y + 52)

    # ---- footer --------------------------------------------------------
    fy = card[3] + gap_b
    dotted_line(d, W//2, fy, ["مجانًا للأبد", "بلا إعلانات", "بلا تتبّع"], F(AR, 32), GREEN)
    d.text((W//2, fy+48), "Free forever  ·  No ads  ·  No tracking", font=F(LAT, 25), fill=GOLD, anchor="mt")
    if STORE == "both":
        d.text((W//2, fy+92), "apps.apple.com  \u00b7  play.google.com", font=F(LAT, 23), fill=INK2, anchor="mt")
    else:
        d.text((W//2, fy+92), LINK.replace("https://",""), font=F(LAT, 23), fill=INK2, anchor="mt")
    im.convert("RGB").save(out, quality=95)
    print("wrote", out, im.size, "slack", extra)

tag = {"play": "play", "both": "both"}.get(STORE, "appstore")
render(1080, 1350, f"/tmp/noorpromo/noor-{tag}-share.jpg")
render(1080, 1920, f"/tmp/noorpromo/noor-{tag}-status.jpg")
