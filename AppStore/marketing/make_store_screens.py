import math, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import arabic_reshaper
from bidi.algorithm import get_display
_re = arabic_reshaper.ArabicReshaper(configuration={'delete_harakat': False})
def ar(s): return get_display(_re.reshape(s))
GREEN, GOLD, PAPER, INK = "#0E6B5C", "#B98A2F", "#FAF6EE", "#1F2933"
AR_F, LAT_F = "/System/Library/Fonts/SFArabic.ttf", "/System/Library/Fonts/SFNS.ttf"
def F(p, s):
    try: return ImageFont.truetype(p, s)
    except Exception: return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", s)

CAPTIONS = {
 '1_today': (("يومك كله في شاشة واحدة", "الصلاة القادمة، وقراءتك، وآية اليوم"),
             ("Your whole day, at a glance", "Next prayer, your reading, today's ayah")),
 '2_mushaf': (("المصحف المدني كما طُبع", "٦٠٤ صفحات بخط مجمع الملك فهد"),
              ("The Madani mushaf, as printed", "604 pages in the King Fahd Complex typeface")),
 '3_prayer': (("مواقيت دقيقة وأذان أصيل", "يعمل بالكامل دون اتصال"),
              ("Accurate times, an authentic adhan", "Works fully offline")),
 '4_city': (("مدينتك أينما كنت", "٣٤ ألف مدينة حول العالم، دون اتصال"),
            ("Your city, wherever you are", "34,000 cities worldwide, offline")),
 '5_athkar': (("حصن المسلم كاملًا", "١٣٢ فصلًا مع عدّاد لكل ذكر"),
              ("All of Hisn al-Muslim", "132 chapters, a counter for every dhikr")),
 '6_hadith': (("الصحيحان والأربعون النووية", "ابحث في كل الأحاديث"),
              ("The two Sahihs and the Forties", "Search every hadith")),
 '7_dark': (("وضع ليلي مريح للعين", "للقراءة قبل النوم وقيام الليل"),
            ("A night mode easy on the eyes", "For reading before sleep and at night")),
 '8_video_share': (("شارك الآية كفيديو", "بصوت قارئك المفضل، جاهز لحالة واتساب"),
                   ("Share an ayah as a video", "With your reciter's voice, ready for your status")),
 '9_athkar_audio': (("استمع إلى الأذكار", "بصوت الشيخ حمد الدريهم، دون اتصال"),
                    ("Listen to the athkar", "Read by Sheikh Hamad Al-Duraihim, offline")),
}

def star8(d, cx, cy, r, fill):
    for rot in (0, math.pi/4):
        d.polygon([(cx + r*math.cos(rot + k*math.pi/2), cy + r*math.sin(rot + k*math.pi/2)) for k in range(4)], fill=fill)

def background(W, H, dark):
    im = Image.new("RGBA", (W, H), "#0B1512" if dark else GREEN)
    pat = Image.new("RGBA", (W, H), (0,0,0,0)); d = ImageDraw.Draw(pat)
    step = int(W*0.16)
    for y in range(-step, H+step, step):
        for x in range(-step, W+step, step):
            off = step//2 if (y//step) % 2 else 0
            star8(d, x+off, y, int(step*0.31), (255,255,255,10))
    im.alpha_composite(pat)
    # soft radial glow behind the device
    glow = Image.new("RGBA", (W, H), (0,0,0,0)); g = ImageDraw.Draw(glow)
    g.ellipse([W*0.1, H*0.35, W*0.9, H*1.05], fill=(255,255,255,26))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(W*0.12)))
    return im

def rounded(im, radius):
    mask = Image.new("L", (im.width*2, im.height*2), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0,0,im.width*2-1,im.height*2-1], radius=radius*2, fill=255)
    out = im.convert("RGBA"); out.putalpha(mask.resize(im.size, Image.LANCZOS)); return out

def render(shot_path, out_path, W, H, key, lang, ipad=False):
    dark = key == '7_dark'
    canvas = background(W, H, dark)
    d = ImageDraw.Draw(canvas)
    head, sub = CAPTIONS[key][0 if lang == 'ar' else 1]
    font_h = F(AR_F if lang=='ar' else LAT_F, int(W*(0.066 if not ipad else 0.05)))
    font_s = F(AR_F if lang=='ar' else LAT_F, int(W*(0.034 if not ipad else 0.026)))
    txt_h = ar(head) if lang=='ar' else head; txt_s = ar(sub) if lang=='ar' else sub
    top = int(H*0.055)
    d.text((W//2, top), txt_h, font=font_h, fill="white", anchor="mt")
    d.text((W//2, top + int(font_h.size*1.35)), txt_s, font=font_s, fill=(255,255,255,205), anchor="mt")
    # device
    shot = Image.open(shot_path).convert("RGB")
    dev_w = int(W*(0.80 if not ipad else 0.74))
    scale = dev_w / shot.width
    shot = shot.resize((dev_w, int(shot.height*scale)), Image.LANCZOS)
    bezel = int(W*(0.018 if not ipad else 0.012))
    corner = int(dev_w*(0.135 if not ipad else 0.06))
    screen = rounded(shot, corner - bezel)
    body = Image.new("RGBA", (dev_w + 2*bezel, shot.height + 2*bezel), (0,0,0,0))
    ImageDraw.Draw(body).rounded_rectangle([0,0,body.width-1,body.height-1], radius=corner, fill="#111111")
    body.alpha_composite(screen, (bezel, bezel))
    # shadow
    sh = Image.new("RGBA", (W, H), (0,0,0,0))
    x = (W - body.width)//2; y = top + int(font_h.size*1.35) + int(font_s.size*2.2)
    ImageDraw.Draw(sh).rounded_rectangle([x, y+40, x+body.width, y+body.height+40], radius=corner, fill=(0,0,0,110))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(40)))
    canvas.alpha_composite(body, (x, y))
    # gold hairline accent under the subline
    d = ImageDraw.Draw(canvas); d.rounded_rectangle([W//2-60, y-int(font_s.size*0.9), W//2+60, y-int(font_s.size*0.9)+8], radius=4, fill=GOLD)
    canvas.convert("RGB").save(out_path, optimize=True)

if __name__ == "__main__":
    src_root, out_root = sys.argv[1], sys.argv[2]
    specs = [("iphone69", 1320, 2868, "/tmp/shots", False), ("iphone65", 1284, 2778, "/tmp/shots", False), ("ipad13", 2064, 2752, "/tmp/shots/ipad", True)]
    for name, W, H, src, ipad in specs:
        for lang in ("ar", "en"):
            os.makedirs(f"{out_root}/{name}/{lang}", exist_ok=True)
            for key in CAPTIONS:
                p = f"{src}/{lang}/{key}.png"
                if os.path.exists(p): render(p, f"{out_root}/{name}/{lang}/{key}.png", W, H, key, lang, ipad)
    print("done")
