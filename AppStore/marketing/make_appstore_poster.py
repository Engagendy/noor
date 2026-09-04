import math, qrcode
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import arabic_reshaper
from bidi.algorithm import get_display

LINK = "https://apps.apple.com/ae/app/noor-al-muslim/id6807128479"
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

def qr_image(size, logo):
    q = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H, box_size=12, border=2)
    q.add_data(LINK); q.make(fit=True)
    im = q.make_image(fill_color=GREEN, back_color="white").convert("RGBA").resize((size,size), Image.NEAREST)
    # Small icon in the centre — H-level correction tolerates it comfortably.
    l = rounded_icon(int(size*0.2), 0.25)
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

def render(W, H, out):
    im = Image.new("RGBA", (W, H), PAPER)
    m = 48
    footer_h = 140
    # Pick the largest QR that still leaves the hero a sensible height, then
    # give the hero whatever remains (capped) and spread any slack.
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
    qr = qr_image(qr_size, True)
    im.alpha_composite(qr, ((W-qr_size)//2, top + 40)); d = ImageDraw.Draw(im)
    y = top + 40 + qr_size + 24
    d.text((W//2, y), ar("امسح الرمز لتحميل التطبيق"), font=F(AR, 38), fill=INK, anchor="mt")
    y += 56
    d.text((W//2, y), "Scan to download on the App Store", font=F(LAT, 28), fill=INK2, anchor="mt")
    y += 60
    apple_badge(d, W//2, y + 52)

    # ---- footer --------------------------------------------------------
    fy = card[3] + gap_b
    dotted_line(d, W//2, fy, ["مجانًا للأبد", "بلا إعلانات", "بلا تتبّع"], F(AR, 32), GREEN)
    d.text((W//2, fy+48), "Free forever  ·  No ads  ·  No tracking", font=F(LAT, 25), fill=GOLD, anchor="mt")
    d.text((W//2, fy+92), LINK.replace("https://",""), font=F(LAT, 23), fill=INK2, anchor="mt")
    im.convert("RGB").save(out, quality=95)
    print("wrote", out, im.size, "slack", extra)

render(1080, 1350, "/tmp/noorpromo/noor-appstore-share.jpg")
render(1080, 1920, "/tmp/noorpromo/noor-appstore-status.jpg")
