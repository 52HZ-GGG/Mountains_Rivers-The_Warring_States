"""
《山河策》事件界面生成器 V3
1024x768 | 系统隶书大字 | 战国色谱 | 透明背景
运行: python generate_events.py
"""

import os, math, random
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "event1")
os.makedirs(OUT_DIR, exist_ok=True)

W, H = 1024, 768

# ── 色板 ──
INK = {"b":(26,26,27), "h":(51,51,52), "s":(13,13,14), "d":(0,0,0)}
BAM = {"b":(197,163,104), "h":(217,190,139), "s":(153,122,74), "d":(102,82,49)}
LAC = {"b":(140,69,34), "h":(176,93,59), "s":(102,48,24), "d":(64,29,15)}
BRO = {"b":(43,51,48), "h":(69,82,77), "s":(26,33,30), "d":(13,18,16)}

# ── 系统字体（华文隶书 — 隶书风格） ──
FONT_CN = "C:/Windows/Fonts/STLITI.TTF"

# ── 英文像素字 (6x8) ──
FONT_EN = {
    'A': [0b011110,0b100001,0b100001,0b111111,0b100001,0b100001,0b100001,0b000000],
    'B': [0b111110,0b100001,0b100001,0b111110,0b100001,0b100001,0b111110,0b000000],
    'C': [0b011110,0b100001,0b100000,0b100000,0b100000,0b100001,0b011110,0b000000],
    'D': [0b111100,0b100010,0b100001,0b100001,0b100001,0b100010,0b111100,0b000000],
    'E': [0b111111,0b100000,0b100000,0b111110,0b100000,0b100000,0b111111,0b000000],
    'F': [0b111111,0b100000,0b100000,0b111110,0b100000,0b100000,0b100000,0b000000],
    'G': [0b011110,0b100001,0b100000,0b101111,0b100001,0b100001,0b011110,0b000000],
    'H': [0b100001,0b100001,0b100001,0b111111,0b100001,0b100001,0b100001,0b000000],
    'I': [0b011110,0b001000,0b001000,0b001000,0b001000,0b001000,0b011110,0b000000],
    'K': [0b100001,0b100010,0b100100,0b111000,0b100100,0b100010,0b100001,0b000000],
    'L': [0b100000,0b100000,0b100000,0b100000,0b100000,0b100000,0b111111,0b000000],
    'M': [0b100001,0b110011,0b101101,0b100001,0b100001,0b100001,0b100001,0b000000],
    'N': [0b100001,0b110001,0b101001,0b100101,0b100011,0b100001,0b100001,0b000000],
    'O': [0b011110,0b100001,0b100001,0b100001,0b100001,0b100001,0b011110,0b000000],
    'P': [0b111110,0b100001,0b100001,0b111110,0b100000,0b100000,0b100000,0b000000],
    'R': [0b111110,0b100001,0b100001,0b111110,0b100100,0b100010,0b100001,0b000000],
    'S': [0b011110,0b100001,0b100000,0b011110,0b000001,0b100001,0b011110,0b000000],
    'T': [0b111111,0b001000,0b001000,0b001000,0b001000,0b001000,0b001000,0b000000],
    'U': [0b100001,0b100001,0b100001,0b100001,0b100001,0b100001,0b011110,0b000000],
    'W': [0b100001,0b100001,0b100001,0b101101,0b101101,0b110011,0b100001,0b000000],
    'X': [0b100001,0b100001,0b010010,0b001100,0b010010,0b100001,0b100001,0b000000],
    'Y': [0b100001,0b100001,0b010010,0b001100,0b001000,0b001000,0b001000,0b000000],
    ' ': [0b000000,0b000000,0b000000,0b000000,0b000000,0b000000,0b000000,0b000000],
    ':': [0b000000,0b001000,0b001000,0b000000,0b001000,0b001000,0b000000,0b000000],
    '!': [0b001000,0b001000,0b001000,0b001000,0b001000,0b000000,0b001000,0b000000],
}


def pb(d, x, y, w, h, c):
    d.rectangle([x, y, x+w-1, y+h-1], fill=c)

def draw_text_centered(d, cx, cy, text, font_path, size, color):
    """居中绘制中文文字（系统字体）"""
    font = ImageFont.truetype(font_path, size)
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = cx - tw // 2
    y = cy - th // 2 - bbox[1]
    d.text((x, y), text, font=font, fill=color)

def draw_en(d, x, y, text, color, scale=5):
    """绘制英文像素字"""
    cx = x
    for ch in text:
        if ch in FONT_EN:
            glyph = FONT_EN[ch]
            for row in range(8):
                bits = glyph[row]
                for col in range(6):
                    if bits & (1 << (5 - col)):
                        pb(d, cx + col * scale, y + row * scale, scale, scale, color)
            cx += 7 * scale
        else:
            cx += 4 * scale

def en_width(text, scale=5):
    return len(text) * 7 * scale - scale

def save(img, name):
    path = os.path.join(OUT_DIR, f"{name}.png")
    img.save(path)
    print(f"  [OK] {name}.png")


# ══════════════════════════════════════════════════════════
#  事件底图模板
# ══════════════════════════════════════════════════════════
def draw_event_bg(d, bg_colors, particles=None):
    """绘制事件背景"""
    c1, c2 = bg_colors
    for y in range(H):
        t = y / H
        r = int(c1[0] + (c2[0]-c1[0]) * t)
        g = int(c1[1] + (c2[1]-c1[1]) * t)
        b = int(c1[2] + (c2[2]-c1[2]) * t)
        pb(d, 0, y, W, 1, (r, g, b, 210))
    if particles:
        random.seed(42)
        for _ in range(particles.get("count", 120)):
            px = random.randint(50, W-50)
            py = random.randint(50, H-50)
            size = random.randint(2, particles.get("size", 8))
            c = particles.get("color", (200,200,200))
            alpha = random.randint(100, 200)
            d.ellipse([px, py, px+size, py+size], fill=(*c, alpha))


def draw_event_title(d, cn_text, en_title, title_color, en_color):
    """绘制事件标题（系统隶书中文 + 英文副标题）"""
    draw_text_centered(d, W//2, 256, cn_text, FONT_CN, 154, title_color)
    tw = en_width(en_title, 5)
    draw_en(d, (W - tw)//2, 436, en_title, en_color, 5)


def draw_event_desc(d, line1, line2=""):
    """绘制事件描述"""
    tw1 = en_width(line1, 5)
    draw_en(d, (W - tw1)//2, 538, line1, BAM["h"], 5)
    if line2:
        tw2 = en_width(line2, 5)
        draw_en(d, (W - tw2)//2, 592, line2, BAM["s"], 5)


def draw_event_border(d):
    """绘制事件边框"""
    pb(d, 0, 0, W, 8, (*BAM["d"], 150))
    pb(d, 0, H-8, W, 8, (*BAM["d"], 150))
    pb(d, 0, 0, 8, H, (*BAM["d"], 150))
    pb(d, W-8, 0, 8, H, (*BAM["d"], 150))
    for cx, cy in [(20,20),(W-21,20),(20,H-21),(W-21,H-21)]:
        d.rectangle([cx-5, cy-5, cx+5, cy+5], fill=(*BAM["h"], 180))
        d.point((cx, cy), fill=(*LAC["b"], 200))


# ══════════════════════════════════════════════════════════
#  事件 1: 商鞅变法
# ══════════════════════════════════════════════════════════
def event_reform():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((40,30,25), (70,45,30)))
    for y in range(102, H-102, 20):
        pb(d, 77, y, W-154, 2, (*BAM["d"], 80))
    pb(d, 51, 90, W-102, 13, (*BAM["s"], 180))
    pb(d, 51, H-102, W-102, 13, (*BAM["s"], 180))
    for i in range(5):
        x = 205 + i * 154
        pb(d, x, 128, 77, 102, (*BRO["b"], 150))
        pb(d, x+13, 141, 51, 77, (*BRO["h"], 120))
        draw_en(d, x+21, 154, "LAW", (*BAM["h"], 180), 3)
    draw_event_title(d, "商鞅变法", "SHANG YANG REFORM", LAC["h"], BAM["h"])
    draw_event_desc(d, "QIN STATE LAUNCHES", "SWEEPING LEGALIST REFORMS")
    draw_event_border(d)
    save(img, "event_reform")


# ══════════════════════════════════════════════════════════
#  事件 2: 合纵
# ══════════════════════════════════════════════════════════
def event_alliance():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((25,35,50), (40,55,70)))
    flag_colors = [LAC["b"], BRO["b"], BAM["b"], (100,60,35), BRO["h"], (60,80,70)]
    for i, fc in enumerate(flag_colors):
        fx = 128 + i * 133
        pb(d, fx, 154, 51, 128, (*fc, 200))
        pb(d, fx+5, 159, 41, 118, (*INK["b"], 150))
        pb(d, fx, 141, 51, 13, (*BAM["s"], 180))
    for i in range(5):
        x1 = 179 + i * 133
        x2 = 179 + (i+1) * 133
        d.line([(x1, 295), (x2, 295)], fill=(*BAM["h"], 180), width=5)
    draw_event_title(d, "合纵抗秦", "VERTICAL ALLIANCE", BAM["h"], BAM["h"])
    draw_event_desc(d, "SIX STATES UNITE", "AGAINST QIN EXPANSION")
    draw_event_border(d)
    save(img, "event_alliance")


# ══════════════════════════════════════════════════════════
#  事件 3: 连横
# ══════════════════════════════════════════════════════════
def event_coalition():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((35,25,20), (60,40,30)))
    pb(d, 410, 128, 205, 179, (*LAC["b"], 200))
    pb(d, 423, 141, 179, 154, (*INK["b"], 150))
    for i in range(6):
        angle = math.radians(30 + i * 50)
        ex = int(512 + 307 * math.cos(angle))
        ey = int(218 + 154 * math.sin(angle))
        d.line([(512, 218), (ex, ey)], fill=(*LAC["h"], 160), width=5)
        d.ellipse([ex-21, ey-21, ex+21, ey+21], fill=(*BRO["b"], 180))
    draw_event_title(d, "连横破纵", "HORIZONTAL STRATEGY", LAC["h"], BAM["h"])
    draw_event_desc(d, "QIN DIVIDES THE ALLIANCE", "THROUGH DIPLOMACY")
    draw_event_border(d)
    save(img, "event_coalition")


# ══════════════════════════════════════════════════════════
#  事件 4: 长平之战
# ══════════════════════════════════════════════════════════
def event_changping():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((50,25,20), (80,35,25)))
    IRON = (160,160,170)
    for i in range(102):
        x = 358 + i
        y = 179 + i
        if 0 <= x < W and 0 <= y < H:
            pb(d, x, y, 8, 8, (*IRON, 200))
    for i in range(102):
        x = 666 - i
        y = 179 + i
        if 0 <= x < W and 0 <= y < H:
            pb(d, x, y, 8, 8, (*IRON, 200))
    for _ in range(51):
        sx = 512 + random.randint(-38, 38)
        sy = 282 + random.randint(-38, 38)
        d.point((sx, sy), fill=(255, 220, 100, 200))
    for _ in range(256):
        rx = random.randint(128, W-128)
        ry = random.randint(307, H-128)
        d.point((rx, ry), fill=(120, 30, 20, 150))
    draw_event_title(d, "长平之战", "BATTLE OF CHANGPING", LAC["h"], BAM["h"])
    draw_event_desc(d, "QIN ANNIHILATES 400,000", "ZHAO SOLDIERS BURIED ALIVE")
    draw_event_border(d)
    save(img, "event_changping")


# ══════════════════════════════════════════════════════════
#  事件 5: 围邯郸
# ══════════════════════════════════════════════════════════
def event_siege():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((30,30,35), (50,45,40)))
    for x in range(154, W-154, 51):
        pb(d, x, 179, 38, 128, (*BRO["b"], 200))
        pb(d, x+5, 184, 28, 118, (*BRO["h"], 150))
    pb(d, 154, 295, W-308, 13, (*BRO["s"], 200))
    pb(d, 461, 218, 102, 90, (*INK["d"], 200))
    for i in range(3):
        lx = 256 + i * 205
        d.line([(lx, 167), (lx+77, 307)], fill=(*BAM["s"], 180), width=5)
        for r in range(5):
            ry = 179 + r * 26
            rx = int(lx + (ry-167) * 77 / 141)
            pb(d, rx-13, ry, 26, 5, (*BAM["d"], 150))
    for _ in range(77):
        fx = random.randint(205, W-205)
        fy = random.randint(141, 192)
        c = random.choice([(200,80,30), (220,120,40), (180,60,20)])
        d.point((fx, fy), fill=(*c, 180))
    draw_event_title(d, "围邯郸", "SIEGE OF HANDAN", LAC["h"], BAM["h"])
    draw_event_desc(d, "QIN ARMY BESIEGES", "THE ZHAO CAPITAL")
    draw_event_border(d)
    save(img, "event_siege")


# ══════════════════════════════════════════════════════════
#  事件 6: 粮仓丰收
# ══════════════════════════════════════════════════════════
def event_harvest():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((60,55,30), (90,80,45)))
    for i in range(8):
        mx = 154 + i * 97
        my = 205
        for dy in range(51):
            for dx in [-3, 0, 3]:
                if abs(dx) + abs(dy-26) <= 21:
                    c = (180,170,90) if (dx+dy)%2==0 else (200,190,110)
                    d.point((mx+dx*2, my+dy), fill=(*c, 200))
        pb(d, mx, my+51, 3, 38, (*BAM["s"], 180))
    pb(d, 307, 358, 410, 154, (*BRO["b"], 200))
    pb(d, 320, 371, 384, 128, (*BRO["h"], 150))
    d.polygon([(282,358),(512,282),(742,358)], fill=(*BAM["s"], 200))
    draw_event_title(d, "粮仓丰收", "BUMPER HARVEST", BAM["h"], BAM["h"])
    draw_event_desc(d, "GRAIN STORES OVERFLOW", "FOOD PRODUCTION DOUBLES")
    draw_event_border(d)
    save(img, "event_harvest")


# ══════════════════════════════════════════════════════════
#  事件 7: 水灾
# ══════════════════════════════════════════════════════════
def event_flood():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((25,40,60), (35,55,80)))
    for y in range(256, H):
        t = (y - 256) / (H - 256)
        for x in range(W):
            wave = math.sin(x*0.016 + y*0.012) * 38
            if y + wave > 307:
                r = int(30 + t*20)
                g = int(55 + t*25)
                b = int(90 + t*30)
                img.putpixel((x, y), (r, g, b, 200))
    for i in range(4):
        bx = 205 + i * 179
        by = 333
        pb(d, bx, by, 77, 64, (*BRO["b"], 180))
        pb(d, bx-13, by-13, 102, 13, (*BRO["s"], 160))
        pb(d, bx, by+38, 77, 38, (40,70,110,150))
    for _ in range(205):
        rx = random.randint(51, W-51)
        ry = random.randint(26, 256)
        d.line([(rx, ry), (rx-3, ry+15)], fill=(150,180,220,150), width=3)
    draw_event_title(d, "水灾", "GREAT FLOOD", (80,140,200), BAM["h"])
    draw_event_desc(d, "DEVASTATING FLOODS HIT", "CROPS DESTROYED WIDELY")
    draw_event_border(d)
    save(img, "event_flood")


# ══════════════════════════════════════════════════════════
#  事件 8: 旱灾
# ══════════════════════════════════════════════════════════
def event_drought():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((70,50,30), (100,70,40)))
    d.ellipse([410, 77, 614, 282], fill=(220,180,60,200))
    d.ellipse([436, 102, 588, 256], fill=(240,200,80,180))
    for i in range(12):
        angle = math.radians(i * 30)
        for s in range(51, 128):
            gx = int(512 + s * math.cos(angle))
            gy = int(179 + s * math.sin(angle))
            if 0 <= gx < W and 0 <= gy < H:
                d.point((gx, gy), fill=(220,180,60, max(0,180-s*2)))
    for y in range(461, H):
        for x in range(W):
            crack = math.sin(x*0.031)*math.cos(y*0.023)
            if crack > 0.7:
                img.putpixel((x, y), (80,55,30,200))
    for i in range(10):
        cx = 128 + i * 82
        for dy in range(38):
            if random.random() < 0.6:
                d.point((cx, 461+dy), fill=(90,65,35,180))
    draw_event_title(d, "旱灾", "SEVERE DROUGHT", (200,150,60), BAM["h"])
    draw_event_desc(d, "CROPS WITHER IN FIELDS", "FAMINE THREATENS THE STATE")
    draw_event_border(d)
    save(img, "event_drought")


# ══════════════════════════════════════════════════════════
#  事件 9: 贸易繁荣
# ══════════════════════════════════════════════════════════
def event_trade():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((45,35,25), (70,55,35)))
    for i in range(4):
        cx = 205 + i * 179
        cy = 256
        d.polygon([(cx,cy),(cx+64,cy-13),(cx+77,cy+26),(cx-13,cy+38)],
                  fill=(*BAM["s"], 200))
        pb(d, cx+13, cy-38, 38, 31, (*BRO["b"], 180))
        pb(d, cx+18, cy-33, 28, 21, (*BRO["h"], 150))
        pb(d, cx+5, cy+31, 5, 26, (*BAM["d"], 180))
        pb(d, cx+51, cy+31, 5, 26, (*BAM["d"], 180))
    for _ in range(77):
        gx = random.randint(128, W-128)
        gy = random.randint(358, 512)
        d.ellipse([gx, gy, gx+10, gy+10], fill=(*BAM["h"], 200))
        d.point((gx+5, gy+5), fill=(*BAM["d"], 180))
    d.line([(154, 333), (870, 333)], fill=(*BAM["d"], 120), width=5)
    draw_event_title(d, "贸易繁荣", "TRADE FLOURISHES", BAM["h"], BAM["h"])
    draw_event_desc(d, "MERCHANT CARAVANS THRIVE", "GOLD FLOWS INTO COFFERS")
    draw_event_border(d)
    save(img, "event_trade")


# ══════════════════════════════════════════════════════════
#  事件 10: 百家争鸣
# ══════════════════════════════════════════════════════════
def event_philosophy():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((35,30,40), (55,45,60)))
    for i in range(6):
        sx = 128 + i * 133
        pb(d, sx, 141, 90, 179, (*BAM["s"], 180))
        pb(d, sx+5, 146, 80, 169, (*BAM["b"], 150))
        for line in range(6):
            pb(d, sx+13, 159+line*26, 64, 3, (*INK["b"], 120))
    symbols = [
        ("RU", (160,120,70)), ("LE", (100,60,40)), ("MO", (80,100,70)),
        ("DA", (120,140,130)), ("ST", (90,70,60)), ("DI", (140,130,80)),
    ]
    for i, (name, col) in enumerate(symbols):
        sx = 141 + i * 133
        pb(d, sx, 358, 64, 46, (*col, 200))
        draw_en(d, sx+8, 366, name, (*BAM["h"], 200), 3)
    draw_event_title(d, "百家争鸣", "HUNDRED SCHOOLS", BAM["h"], BAM["h"])
    draw_event_desc(d, "PHILOSOPHY FLOURISHES", "NEW IDEAS SHAPE THE AGE")
    draw_event_border(d)
    save(img, "event_philosophy")


# ══════════════════════════════════════════════════════════
#  事件 11: 将星陨落
# ══════════════════════════════════════════════════════════
def event_general_death():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((20,20,25), (40,35,35)))
    for i in range(5):
        sx = 256 + i * 128
        sy = 102 + i * 38
        for s in range(38):
            d.point((sx+s, sy+s), fill=(200,180,120, max(0,200-s*5)))
    for i in range(77):
        d.point((512, 205+i), fill=(*BRO["h"], 200))
        d.point((513, 205+i), fill=(*BRO["h"], 200))
    pb(d, 499, 192, 31, 13, (*BRO["b"], 200))
    d.polygon([(474,307),(512,282),(551,307),(538,358),(486,358)],
              fill=(*LAC["b"], 200))
    d.polygon([(481,315),(512,294),(543,315),(532,350),(492,350)],
              fill=(*LAC["s"], 180))
    pb(d, 128, 128, W-256, 5, (*BAM["d"], 100))
    draw_event_title(d, "将星陨落", "A GENERAL FALLS", (180,160,130), BAM["s"])
    draw_event_desc(d, "A GREAT WARRIOR PASSES", "THE STATE MOURNS")
    draw_event_border(d)
    save(img, "event_general_death")


# ══════════════════════════════════════════════════════════
#  事件 12: 筑城
# ══════════════════════════════════════════════════════════
def event_fortify():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((40,35,30), (60,50,40)))
    pb(d, 205, 333, 614, 102, (*BRO["b"], 200))
    pb(d, 218, 346, 588, 77, (*BRO["h"], 150))
    for i in range(8):
        bx = 205 + i * 77
        h = 154 - i * 8
        pb(d, bx, 333-h, 64, h, (*BRO["b"], 180+i*5))
        pb(d, bx+5, 338-h, 54, h-10, (*BRO["h"], 150+i*5))
    for i in range(5):
        wx = 256 + i * 102
        wy = 295
        pb(d, wx, wy, 10, 21, (*BAM["s"], 180))
        pb(d, wx-3, wy-8, 16, 8, (*BAM["b"], 160))
    for i in range(6):
        mx = 230 + i * 90
        pb(d, mx, 448, 31, 21, (*BRO["s"], 180))
    draw_event_title(d, "筑城", "CITY FORTIFIED", BAM["h"], BAM["h"])
    draw_event_desc(d, "NEW DEFENSES CONSTRUCTED", "WALLS RISE HIGH AND STRONG")
    draw_event_border(d)
    save(img, "event_fortify")


# ══════════════════════════════════════════════════════════
#  事件 13: 奇袭
# ══════════════════════════════════════════════════════════
def event_ambush():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((15,20,30), (30,35,45)))
    for i in range(10):
        ax = 77 + i * 90
        ay = 256 + random.randint(-26, 26)
        pb(d, ax, ay, 13, 31, (*INK["d"], 220))
        pb(d, ax-3, ay-10, 18, 10, (*INK["d"], 200))
        pb(d, ax+13, ay-5, 5, 26, (*BRO["h"], 180))
    for i in range(3):
        fx = 307 + i * 205
        fy = 205
        pb(d, fx, fy, 5, 38, (*BAM["s"], 200))
        d.ellipse([fx-10, fy-21, fx+15, fy-5], fill=(220,140,40,200))
        d.ellipse([fx-5, fy-26, fx+10, fy-10], fill=(240,180,60,180))
    for i in range(8):
        sx = 128 + i * 102
        sy = 179 + i * 13
        d.line([(sx, sy), (sx+38, sy-13)], fill=(*BAM["d"], 200), width=3)
        d.point((sx+41, sy-16), fill=(*BRO["h"], 200))
    draw_event_title(d, "奇袭", "AMBUSH!", LAC["h"], BAM["h"])
    draw_event_desc(d, "ENEMY FORCES STRIKE", "FROM THE DARKNESS")
    draw_event_border(d)
    save(img, "event_ambush")


# ══════════════════════════════════════════════════════════
#  事件 14: 王者兴
# ══════════════════════════════════════════════════════════
def event_king_rise():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((50,35,20), (80,55,30)))
    pb(d, 410, 205, 205, 154, (*BRO["b"], 200))
    pb(d, 423, 218, 179, 128, (*BRO["h"], 150))
    pb(d, 397, 192, 230, 13, (*BAM["h"], 200))
    d.polygon([(461,179),(474,141),(487,167),(500,128),(512,167),(525,141),(538,179)],
              fill=(*BAM["h"], 220))
    for i in range(16):
        angle = math.radians(i * 22.5)
        for s in range(77, 179):
            gx = int(512 + s * math.cos(angle))
            gy = int(154 + s * math.sin(angle))
            if 0 <= gx < W and 0 <= gy < H:
                d.point((gx, gy), fill=(*BAM["h"], max(0,int(180-s*1.5))))
    draw_event_title(d, "王者兴", "A KING RISES", BAM["h"], BAM["h"])
    draw_event_desc(d, "A NEW RULER ASCENDS", "THE THRONE AWAITS")
    draw_event_border(d)
    save(img, "event_king_rise")


# ══════════════════════════════════════════════════════════
#  事件 15: 王朝衰
# ══════════════════════════════════════════════════════════
def event_dynasty_fall():
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_event_bg(d, ((25,20,18), (45,35,28)))
    pb(d, 205, 307, 128, 205, (*BRO["b"], 180))
    pb(d, 666, 256, 154, 256, (*BRO["b"], 180))
    d.line([(205, 307), (512, 384)], fill=(*BAM["d"], 180), width=8)
    d.line([(512, 384), (820, 282)], fill=(*BAM["d"], 180), width=8)
    for _ in range(128):
        rx = random.randint(154, W-154)
        ry = random.randint(410, 564)
        size = random.randint(8, 21)
        c = random.choice([BRO["b"], BRO["s"], BAM["d"]])
        pb(d, rx, ry, size, size//2, (*c, 180))
    for _ in range(102):
        sx = random.randint(205, W-205)
        sy = random.randint(154, 307)
        d.ellipse([sx, sy, sx+21, sy+21], fill=(60,50,45,100))
    draw_event_title(d, "王朝衰", "DYNASTY FALLS", (160,120,90), BAM["s"])
    draw_event_desc(d, "THE THRONE CRUMBLES", "CHAOS CONSUMES THE LAND")
    draw_event_border(d)
    save(img, "event_dynasty_fall")


def generate_all():
    print("=== 《山河策》事件界面生成器 V3 (1024x768) ===\n")
    events = [
        event_reform, event_alliance, event_coalition,
        event_changping, event_siege, event_harvest,
        event_flood, event_drought, event_trade,
        event_philosophy, event_general_death, event_fortify,
        event_ambush, event_king_rise, event_dynasty_fall,
    ]
    for func in events:
        func()
    print(f"\n=== 完成！共 {len(events)} 个事件界面 ===")
    print(f"输出: {OUT_DIR}")
    print("规格: 1024x768 | 系统隶书 | 透明背景")
    print("\n请在本地查看 event1/ 目录即可。")

if __name__ == "__main__":
    generate_all()
