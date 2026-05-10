"""
《山河策》季节过渡界面生成器
800x600 | 像素风 | 大字 | 战国色谱
运行: python generate_season.py
"""

import os, math, random
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "season")
os.makedirs(OUT_DIR, exist_ok=True)

W, H = 800, 600

# ── 色板 ──
INK = {"b":(26,26,27), "h":(51,51,52), "s":(13,13,14), "d":(0,0,0)}
BAM = {"b":(197,163,104), "h":(217,190,139), "s":(153,122,74), "d":(102,82,49)}
LAC = {"b":(140,69,34), "h":(176,93,59), "s":(102,48,24), "d":(64,29,15)}
BRO = {"b":(43,51,48), "h":(69,82,77), "s":(26,33,30), "d":(13,18,16)}

# ── 大像素字体 (8x11) ──
FONT_BIG = {
    'S': [0b01111110,0b11000000,0b11000000,0b01111110,0b00000011,0b00000011,0b11111110,0b00000000],
    'P': [0b11111100,0b11000011,0b11000011,0b11111100,0b11000000,0b11000000,0b11000000,0b00000000],
    'R': [0b11111100,0b11000011,0b11000011,0b11111100,0b11011000,0b11001100,0b11000110,0b00000000],
    'I': [0b01111110,0b00011000,0b00011000,0b00011000,0b00011000,0b00011000,0b01111110,0b00000000],
    'N': [0b11000011,0b11100011,0b11110011,0b11011011,0b11001111,0b11000111,0b11000011,0b00000000],
    'G': [0b01111110,0b11000011,0b11000000,0b11011111,0b11000011,0b11000011,0b01111110,0b00000000],
    'U': [0b11000011,0b11000011,0b11000011,0b11000011,0b11000011,0b11000011,0b01111110,0b00000000],
    'M': [0b11000011,0b11100111,0b11111111,0b11011011,0b11000011,0b11000011,0b11000011,0b00000000],
    'E': [0b11111111,0b11000000,0b11000000,0b11111100,0b11000000,0b11000000,0b11111111,0b00000000],
    'R': [0b11111100,0b11000011,0b11000011,0b11111100,0b11011000,0b11001100,0b11000110,0b00000000],
    'A': [0b00111100,0b01100110,0b11000011,0b11111111,0b11000011,0b11000011,0b11000011,0b00000000],
    'T': [0b11111111,0b00011000,0b00011000,0b00011000,0b00011000,0b00011000,0b00011000,0b00000000],
    'W': [0b11000011,0b11000011,0b11000011,0b11011011,0b11111111,0b11100111,0b11000011,0b00000000],
    'O': [0b01111110,0b11000011,0b11000011,0b11000011,0b11000011,0b11000011,0b01111110,0b00000000],
    'L': [0b11000000,0b11000000,0b11000000,0b11000000,0b11000000,0b11000000,0b11111111,0b00000000],
    'D': [0b11111000,0b11001100,0b11000110,0b11000110,0b11001100,0b11111000,0b00000000,0b00000000],
    'F': [0b11111111,0b11000000,0b11000000,0b11111100,0b11000000,0b11000000,0b11000000,0b00000000],
    'H': [0b11000011,0b11000011,0b11000011,0b11111111,0b11000011,0b11000011,0b11000011,0b00000000],
    'C': [0b01111110,0b11000011,0b11000000,0b11000000,0b11000000,0b11000011,0b01111110,0b00000000],
    'B': [0b11111100,0b11000011,0b11000011,0b11111100,0b11000011,0b11000011,0b11111100,0b00000000],
}

# 中文大像素字 (用图案模拟汉字)
CN_SPRING = [  # 春
    "  ##    ",
    " ####   ",
    "# ## #  ",
    "  ##    ",
    " ###### ",
    " # ## # ",
    "#  ##  #",
    "  ##    ",
    "  ##    ",
    "  ##    ",
]
CN_SUMMER = [  # 夏
    " ###### ",
    "   ##   ",
    " ###### ",
    "# #  # #",
    "  ####  ",
    " # ## # ",
    "#  ##  #",
    " #    # ",
    "  ####  ",
    " #    # ",
]
CN_AUTUMN = [  # 秋
    "  #  #  ",
    " # ## # ",
    "# #### #",
    " ##  ## ",
    "  ####  ",
    " ##  ## ",
    "# #  # #",
    "  #  #  ",
    " # ## # ",
    "#  ##  #",
]
CN_WINTER = [  # 冬
    "   #    ",
    "  ###   ",
    " # # #  ",
    "#  #  # ",
    "  ####  ",
    " # ## # ",
    "  ####  ",
    "   ##   ",
    "  ####  ",
    "  ####  ",
]

CN_BIG = {
    "春": CN_SPRING,
    "夏": CN_SUMMER,
    "秋": CN_AUTUMN,
    "冬": CN_WINTER,
}

# 季节诗词
POEMS = {
    "spring": "DONG FENG YE FANG HUA QIAN SHU",
    "summer": "JIE TIAN LIAN YE WU QIONG BI",
    "autumn": "LUO XIU YU SHUANG HONG YU ER",
    "winter": "HU RU YI YE CHUN FENG LAI",
}

def pb(d, x, y, w, h, c):
    d.rectangle([x, y, x+w-1, y+h-1], fill=c)

def draw_cn_big(d, cx, cy, char, color, scale=6):
    """绘制大号中文像素字"""
    if char not in CN_BIG:
        return
    pattern = CN_BIG[char]
    ph = len(pattern)
    pw = max(len(row) for row in pattern)
    ox = cx - (pw * scale) // 2
    oy = cy - (ph * scale) // 2
    for y, row in enumerate(pattern):
        for x, ch in enumerate(row):
            if ch == '#':
                pb(d, ox + x * scale, oy + y * scale, scale, scale, color)

def draw_text_big(d, x, y, text, color, scale=4):
    """绘制大号英文像素字"""
    cx = x
    for ch in text:
        if ch == ' ':
            cx += 5 * scale
            continue
        if ch in FONT_BIG:
            glyph = FONT_BIG[ch]
            for row in range(8):
                bits = glyph[row]
                for col in range(8):
                    if bits & (1 << (7 - col)):
                        pb(d, cx + col * scale, y + row * scale, scale, scale, color)
            cx += 9 * scale
        else:
            cx += 5 * scale

def text_big_width(text, scale=4):
    w = 0
    for ch in text:
        w += 9 * scale if ch in FONT_BIG else 5 * scale
    return w - scale

def save(img, name):
    path = os.path.join(OUT_DIR, f"{name}.png")
    img.save(path)
    print(f"  [OK] {name}.png")


# ══════════════════════════════════════════════════════════
#  春 — 东风夜放花千树
# ══════════════════════════════════════════════════════════
def gen_spring():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 背景：暖粉绿渐变
    for y in range(H):
        t = y / H
        r = int(40 + t * 30)
        g = int(55 + t * 25)
        b = int(45 + t * 15)
        pb(d, 0, y, W, 1, (r, g, b, 220))
    # 远山轮廓
    for x in range(W):
        h = int(180 + 40 * math.sin(x * 0.008) + 20 * math.sin(x * 0.02))
        for y in range(h, H):
            t = (y - h) / (H - h)
            c = (int(60 + t*20), int(75 + t*15), int(55 + t*10), 200)
            img.putpixel((x, y), c)
    # 樱花树干
    for i in range(3):
        tx = 150 + i * 250
        ty = 280 + i * 20
        for dy in range(200):
            dx = int(math.sin(dy * 0.03) * 8)
            w = max(2, 8 - dy // 30)
            pb(d, tx + dx - w//2, ty + dy, w, 1, (80, 50, 35, 200))
    # 樱花花瓣（大量粉色点）
    random.seed(501)
    for _ in range(400):
        fx = random.randint(50, W-50)
        fy = random.randint(100, 400)
        size = random.randint(2, 5)
        alpha = random.randint(150, 230)
        c = random.choice([(230,180,190), (220,160,175), (240,200,210), (210,140,160)])
        d.ellipse([fx, fy, fx+size, fy+size], fill=(*c, alpha))
    # 飘落花瓣（动态感）
    for _ in range(80):
        fx = random.randint(0, W)
        fy = random.randint(0, H)
        c = random.choice([(235,185,195), (225,165,180)])
        d.point((fx, fy), fill=(*c, 200))
        d.point((fx+1, fy+1), fill=(*c, 150))
    # 大字标题
    draw_cn_big(d, W//2, 220, "春", (230, 200, 210), 10)
    # 英文副标题
    tw = text_big_width("SPRING", 5)
    draw_text_big(d, (W - tw)//2, 340, "SPRING", (217, 190, 139), 5)
    # 诗词
    poem = POEMS["spring"]
    tw2 = text_big_width(poem, 2)
    draw_text_big(d, (W - tw2)//2, 440, poem, (180, 160, 140), 2)
    # 装饰边框
    pb(d, 0, 0, W, 3, (197,163,104,120))
    pb(d, 0, H-3, W, 3, (197,163,104,120))
    pb(d, 0, 0, 3, H, (197,163,104,120))
    pb(d, W-3, 0, 3, H, (197,163,104,120))
    # 年号
    tw3 = text_big_width("YEAR 230 BC", 2)
    draw_text_big(d, (W - tw3)//2, 520, "YEAR 230 BC", (120, 110, 95), 2)
    save(img, "season_spring")


# ══════════════════════════════════════════════════════════
#  夏 — 接天莲叶无穷碧
# ══════════════════════════════════════════════════════════
def gen_summer():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 背景：浓翠绿渐变
    for y in range(H):
        t = y / H
        r = int(25 + t * 20)
        g = int(65 + t * 30)
        b = int(35 + t * 15)
        pb(d, 0, y, W, 1, (r, g, b, 230))
    # 荷塘水面
    for y in range(350, H):
        t = (y - 350) / (H - 350)
        for x in range(W):
            wave = math.sin(x * 0.03 + y * 0.02) * 0.3
            r = int(35 + t * 15 + wave * 10)
            g = int(75 + t * 20 + wave * 10)
            b = int(90 + t * 25 + wave * 15)
            img.putpixel((x, y), (r, g, b, 210))
    # 荷叶（大圆）
    random.seed(601)
    for _ in range(12):
        lx = random.randint(80, W-80)
        ly = random.randint(360, 500)
        lr = random.randint(30, 55)
        c = random.choice([(40,100,50), (50,120,60), (35,90,45)])
        d.ellipse([lx-lr, ly-lr//2, lx+lr, ly+lr//2], fill=(*c, 200))
        # 荷叶纹理
        for i in range(5):
            angle = random.uniform(0, math.pi*2)
            ex = int(lx + lr*0.7*math.cos(angle))
            ey = int(ly + lr*0.35*math.sin(angle))
            d.line([(lx, ly), (ex, ey)], fill=(30,80,40,150), width=1)
    # 荷花
    for _ in range(5):
        fx = random.randint(100, W-100)
        fy = random.randint(340, 450)
        for p in range(6):
            angle = p * 60
            px = int(fx + 12 * math.cos(math.radians(angle)))
            py = int(fy + 8 * math.sin(math.radians(angle)))
            d.ellipse([px-6, py-4, px+6, py+4], fill=(220,150,160,200))
        d.ellipse([fx-4, fy-3, fx+4, fy+3], fill=(240,200,80,220))
    # 萤火虫
    for _ in range(40):
        fx = random.randint(50, W-50)
        fy = random.randint(200, 500)
        d.point((fx, fy), fill=(220, 240, 100, 200))
        d.point((fx+1, fy), fill=(220, 240, 100, 120))
        d.point((fx-1, fy), fill=(220, 240, 100, 120))
    # 大字标题
    draw_cn_big(d, W//2, 180, "夏", (180, 220, 150), 10)
    tw = text_big_width("SUMMER", 5)
    draw_text_big(d, (W - tw)//2, 300, "SUMMER", (217, 190, 139), 5)
    poem = POEMS["summer"]
    tw2 = text_big_width(poem, 2)
    draw_text_big(d, (W - tw2)//2, 400, poem, (160, 180, 140), 2)
    pb(d, 0, 0, W, 3, (197,163,104,120))
    pb(d, 0, H-3, W, 3, (197,163,104,120))
    pb(d, 0, 0, 3, H, (197,163,104,120))
    pb(d, W-3, 0, 3, H, (197,163,104,120))
    tw3 = text_big_width("YEAR 230 BC", 2)
    draw_text_big(d, (W - tw3)//2, 520, "YEAR 230 BC", (120, 110, 95), 2)
    save(img, "season_summer")


# ══════════════════════════════════════════════════════════
#  秋 — 落霞与孤鹜齐飞
# ══════════════════════════════════════════════════════════
def gen_autumn():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 背景：暖橙褐渐变
    for y in range(H):
        t = y / H
        r = int(80 + t * 40)
        g = int(50 + t * 25)
        b = int(30 + t * 15)
        pb(d, 0, y, W, 1, (r, g, b, 220))
    # 夕阳天空
    for y in range(200):
        t = y / 200
        r = int(180 - t * 80)
        g = int(100 - t * 50)
        b = int(50 - t * 20)
        pb(d, 0, y, W, 1, (r, g, b, 180))
    # 太阳
    d.ellipse([350, 60, 450, 160], fill=(220, 160, 80, 200))
    d.ellipse([360, 70, 440, 150], fill=(240, 190, 100, 180))
    # 远山
    for x in range(W):
        h = int(250 + 50 * math.sin(x * 0.006) + 25 * math.sin(x * 0.015))
        for y in range(h, H):
            t = (y - h) / (H - h)
            c = (int(90 + t*30), int(60 + t*20), int(35 + t*10), 190)
            img.putpixel((x, y), c)
    # 枯树剪影
    for i in range(2):
        tx = 200 + i * 350
        # 树干
        for dy in range(180):
            w = max(2, 10 - dy // 20)
            pb(d, tx - w//2, 250 + dy, w, 1, (50, 35, 25, 220))
        # 枝干
        for b_i in range(4):
            angle = math.radians(-30 + b_i * 20 + i * 10)
            for s in range(40):
                bx = int(tx + s * math.cos(angle))
                by = int(260 + s * math.sin(angle))
                if 0 <= bx < W and 0 <= by < H:
                    d.point((bx, by), fill=(55, 38, 28, 200))
    # 落叶
    random.seed(701)
    for _ in range(200):
        lx = random.randint(30, W-30)
        ly = random.randint(200, H-50)
        size = random.randint(2, 4)
        c = random.choice([(180,100,40), (200,130,50), (160,80,30), (190,110,45)])
        alpha = random.randint(160, 230)
        d.ellipse([lx, ly, lx+size, ly+size], fill=(*c, alpha))
    # 飞鸟剪影
    for _ in range(8):
        bx = random.randint(100, W-100)
        by = random.randint(80, 250)
        s = random.randint(3, 6)
        d.line([(bx-s, by+s//2), (bx, by), (bx+s, by+s//2)], fill=(40,30,25,200), width=1)
    # 大字标题
    draw_cn_big(d, W//2, 200, "秋", (220, 180, 120), 10)
    tw = text_big_width("AUTUMN", 5)
    draw_text_big(d, (W - tw)//2, 330, "AUTUMN", (217, 190, 139), 5)
    poem = POEMS["autumn"]
    tw2 = text_big_width(poem, 2)
    draw_text_big(d, (W - tw2)//2, 430, poem, (180, 150, 110), 2)
    pb(d, 0, 0, W, 3, (197,163,104,120))
    pb(d, 0, H-3, W, 3, (197,163,104,120))
    pb(d, 0, 0, 3, H, (197,163,104,120))
    pb(d, W-3, 0, 3, H, (197,163,104,120))
    tw3 = text_big_width("YEAR 230 BC", 2)
    draw_text_big(d, (W - tw3)//2, 520, "YEAR 230 BC", (120, 100, 80), 2)
    save(img, "season_autumn")


# ══════════════════════════════════════════════════════════
#  冬 — 忽如一夜春风来
# ══════════════════════════════════════════════════════════
def gen_winter():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 背景：冷灰蓝渐变
    for y in range(H):
        t = y / H
        r = int(30 + t * 15)
        g = int(35 + t * 15)
        b = int(50 + t * 20)
        pb(d, 0, y, W, 1, (r, g, b, 230))
    # 雪地
    for y in range(380, H):
        t = (y - 380) / (H - 380)
        r = int(160 - t * 30)
        g = int(170 - t * 25)
        b = int(185 - t * 20)
        pb(d, 0, y, W, 1, (r, g, b, 200))
    # 远山雪峰
    for x in range(W):
        h = int(200 + 60 * math.sin(x * 0.005) + 30 * math.sin(x * 0.018))
        for y in range(h, 380):
            t = (y - h) / (380 - h)
            c = (int(80 + t*40), int(85 + t*40), int(100 + t*40), 180)
            img.putpixel((x, y), c)
        # 雪顶
        if h < 380:
            for sy in range(h, min(h+15, 380)):
                img.putpixel((x, sy), (200, 210, 225, 180))
    # 枯树（带雪）
    for i in range(3):
        tx = 120 + i * 280
        for dy in range(160):
            w = max(2, 8 - dy // 25)
            c = (60, 55, 50, 220) if dy > 10 else (180, 190, 205, 200)
            pb(d, tx - w//2, 280 + dy, w, 1, c)
        # 枝干（带雪）
        for b_i in range(5):
            angle = math.radians(-40 + b_i * 18 + i * 8)
            for s in range(35):
                bx = int(tx + s * math.cos(angle))
                by = int(290 + s * math.sin(angle))
                if 0 <= bx < W and 0 <= by < H:
                    c = (55, 50, 45, 200) if s > 5 else (190, 200, 215, 180)
                    d.point((bx, by), fill=c)
    # 雪花
    random.seed(801)
    for _ in range(300):
        sx = random.randint(0, W)
        sy = random.randint(0, H)
        size = random.randint(1, 3)
        alpha = random.randint(120, 220)
        d.ellipse([sx, sy, sx+size, sy+size], fill=(220, 225, 235, alpha))
    # 冰晶装饰
    for _ in range(20):
        ix = random.randint(50, W-50)
        iy = random.randint(50, 350)
        for arm in range(6):
            angle = math.radians(arm * 60)
            for s in range(8):
                ex = int(ix + s * math.cos(angle))
                ey = int(iy + s * math.sin(angle))
                if 0 <= ex < W and 0 <= ey < H:
                    d.point((ex, ey), fill=(180, 200, 220, 150))
    # 大字标题
    draw_cn_big(d, W//2, 180, "冬", (180, 200, 220), 10)
    tw = text_big_width("WINTER", 5)
    draw_text_big(d, (W - tw)//2, 310, "WINTER", (217, 190, 139), 5)
    poem = POEMS["winter"]
    tw2 = text_big_width(poem, 2)
    draw_text_big(d, (W - tw2)//2, 420, poem, (150, 165, 180), 2)
    pb(d, 0, 0, W, 3, (197,163,104,120))
    pb(d, 0, H-3, W, 3, (197,163,104,120))
    pb(d, 0, 0, 3, H, (197,163,104,120))
    pb(d, W-3, 0, 3, H, (197,163,104,120))
    tw3 = text_big_width("YEAR 230 BC", 2)
    draw_text_big(d, (W - tw3)//2, 520, "YEAR 230 BC", (120, 115, 105), 2)
    save(img, "season_winter")


def generate_all():
    print("=== 《山河策》季节界面生成器 ===\n")
    gen_spring()
    gen_summer()
    gen_autumn()
    gen_winter()
    print(f"\n=== 完成！共 4 个季节界面 ===")
    print(f"输出: {OUT_DIR}")
    print("规格: 800x600 | 像素风 | 大字 | 透明背景")
    print("\n请在本地查看 season/ 目录即可。")

if __name__ == "__main__":
    generate_all()
