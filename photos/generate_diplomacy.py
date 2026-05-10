"""
《山河策》外交交互图片生成器
1024x1024 | 结盟宣战等外交场景 | 系统中文字体 | 透明背景
运行: python generate_diplomacy.py
"""

import os, math, random
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "diplomacy")
os.makedirs(OUT_DIR, exist_ok=True)

SZ = 1024

# ── 色板 ──
INK = (26, 26, 27)
BAM = (197, 163, 104)
BAM_H = (217, 190, 139)
BAM_S = (153, 122, 74)
BAM_D = (102, 82, 49)
LAC = (140, 69, 34)
LAC_H = (176, 93, 59)
BRO = (43, 51, 48)
BRO_H = (69, 82, 77)
IRON = (160, 165, 175)
GOLD = (220, 190, 80)
BLOOD = (150, 30, 25)

# ── 字体 ──
FONT_CN = "C:/Windows/Fonts/STLITI.TTF"

def pb(d, x, y, w, h, c):
    d.rectangle([x, y, x+w-1, y+h-1], fill=c)

def draw_text_centered(d, cx, cy, text, font_path, size, color):
    font = ImageFont.truetype(font_path, size)
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = cx - tw // 2
    y = cy - th // 2 - bbox[1]
    d.text((x, y), text, font=font, fill=color)

def save(img, name):
    path = os.path.join(OUT_DIR, f"{name}.png")
    img.save(path)
    print(f"  [OK] {name}.png")


def draw_bg(d, c1, c2):
    for y in range(SZ):
        t = y / SZ
        r = int(c1[0] + (c2[0]-c1[0]) * t)
        g = int(c1[1] + (c2[1]-c1[1]) * t)
        b = int(c1[2] + (c2[2]-c1[2]) * t)
        pb(d, 0, y, SZ, 1, (r, g, b, 180))


def draw_border(d, c):
    pb(d, 0, 0, SZ, 6, (*c, 150))
    pb(d, 0, SZ-6, SZ, 6, (*c, 150))
    pb(d, 0, 0, 6, SZ, (*c, 150))
    pb(d, SZ-6, 0, 6, SZ, (*c, 150))
    for cx, cy in [(16,16),(SZ-17,16),(16,SZ-17),(SZ-17,SZ-17)]:
        d.ellipse([cx-8, cy-8, cx+8, cy+8], fill=(*BAM_H, 180))


# ══════════════════════════════════════════════════════════
#  1. 结盟 — 两国旗帜交叠，握手
# ══════════════════════════════════════════════════════════
def dip_alliance():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_bg(d, (30,40,55), (50,60,75))
    # 左旗（红）
    pb(d, 200, 200, 180, 400, (*LAC, 220))
    pb(d, 210, 210, 160, 380, (*LAC_H, 200))
    # 右旗（蓝）
    pb(d, 644, 200, 180, 400, (50,70,100,220))
    pb(d, 654, 210, 160, 380, (65,85,115,200))
    # 旗杆
    pb(d, 192, 120, 8, 500, (*BRO_H, 200))
    pb(d, 824, 120, 8, 500, (*BRO_H, 200))
    # 旗杆尖
    d.polygon([(188,120),(196,90),(204,120)], fill=(*GOLD, 220))
    d.polygon([(820,120),(828,90),(836,120)], fill=(*GOLD, 220))
    # 握手（中央）
    # 左手
    d.polygon([(380,480),(420,440),(480,450),(500,480),(480,520),(420,530)],
              fill=(180,150,120,220))
    d.polygon([(390,485),(425,450),(475,458),(490,485),(475,510),(425,520)],
              fill=(200,170,140,200))
    # 右手
    d.polygon([(520,480),(560,440),(620,450),(640,480),(620,520),(560,530)],
              fill=(170,140,110,220))
    d.polygon([(530,485),(565,450),(615,458),(630,485),(615,510),(565,520)],
              fill=(190,160,130,200))
    # 握手处光芒
    for i in range(16):
        angle = math.radians(i * 22.5)
        for s in range(20, 80):
            px = int(512 + s * math.cos(angle))
            py = int(490 + s * math.sin(angle))
            if 0 <= px < SZ and 0 <= py < SZ:
                d.point((px, py), fill=(*GOLD, max(30, 120-s*2)))
    # 盟约竹简
    pb(d, 420, 600, 184, 100, (*BAM_D, 200))
    pb(d, 428, 608, 168, 84, (*BAM, 180))
    for i in range(6):
        pb(d, 436, 616+i*12, 152, 2, (*INK, 120))
    # 金色光点
    random.seed(1001)
    for _ in range(60):
        px = random.randint(300, 724)
        py = random.randint(200, 600)
        size = random.randint(3, 8)
        d.ellipse([px,py,px+size,py+size], fill=(*GOLD, random.randint(80,180)))
    draw_border(d, BAM_S)
    draw_text_centered(d, 512, 880, "结盟", FONT_CN, 120, (*BAM_H, 230))
    save(img, "dip_alliance")


# ══════════════════════════════════════════════════════════
#  2. 宣战 — 利剑出鞘，战鼓
# ══════════════════════════════════════════════════════════
def dip_declare_war():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_bg(d, (50,20,15), (80,30,20))
    # 战鼓
    d.ellipse([350,500,674,600], fill=(100,70,50,220))
    d.ellipse([350,480,674,580], fill=(120,85,60,200))
    d.ellipse([360,490,664,570], fill=(140,100,70,180))
    # 鼓面纹理
    d.ellipse([420,510,604,560], outline=(*BAM_S, 140), width=2)
    # 鼓槌
    d.line([(300,450),(420,520)], fill=(100,80,60,200), width=10)
    d.line([(724,450),(604,520)], fill=(100,80,60,200), width=10)
    d.ellipse([288,438,312,462], fill=(120,90,65,200))
    d.ellipse([712,438,736,462], fill=(120,90,65,200))
    # 利剑（交叉）
    # 左剑
    for i in range(350):
        x = 300 + i
        y = 200 + int(i * 0.57)
        if 100 < x < 924 and 100 < y < 500:
            c = (200,205,215) if abs(i-175) < 60 else (170,175,185)
            alpha = max(100, 220 - abs(i-175))
            pb(d, x, y, 6, 6, (*c, alpha))
    # 右剑
    for i in range(350):
        x = 724 - i
        y = 200 + int(i * 0.57)
        if 100 < x < 924 and 100 < y < 500:
            c = (200,205,215) if abs(i-175) < 60 else (170,175,185)
            alpha = max(100, 220 - abs(i-175))
            pb(d, x, y, 6, 6, (*c, alpha))
    # 剑格
    pb(d, 460, 380, 40, 20, (*GOLD, 220))
    pb(d, 524, 380, 40, 20, (*GOLD, 220))
    # 火焰背景
    random.seed(2001)
    for _ in range(100):
        px = random.randint(100, 924)
        py = random.randint(100, 400)
        size = random.randint(8, 25)
        c = random.choice([(200,60,20),(220,100,30),(180,40,15)])
        alpha = random.randint(80, 180)
        d.ellipse([px,py,px+size,py+size], fill=(*c, alpha))
    # 血色光晕
    for r in range(200, 0, -1):
        alpha = max(5, 40 - r//5)
        for i in range(24):
            angle = math.radians(i * 15)
            x = int(512 + r * math.cos(angle))
            y = int(300 + r * math.sin(angle))
            if 0 <= x < SZ and 0 <= y < SZ:
                d.point((x, y), fill=(200,40,30, alpha))
    draw_border(d, (120,30,20))
    draw_text_centered(d, 512, 880, "宣战", FONT_CN, 120, (220,180,160,230))
    save(img, "dip_declare_war")


# ══════════════════════════════════════════════════════════
#  3. 和谈 — 案几对坐，茶盏
# ══════════════════════════════════════════════════════════
def dip_peace():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_bg(d, (35,40,50), (55,60,70))
    # 案几
    pb(d, 250, 480, 524, 40, (*BAM_D, 220))
    pb(d, 260, 486, 504, 28, (*BAM, 200))
    # 案腿
    for x in [280, 720]:
        pb(d, x, 520, 16, 80, (*BAM_D, 200))
    # 茶盏（左）
    d.ellipse([340,460,380,480], fill=(*BAM_H, 200))
    d.ellipse([344,462,376,478], fill=(80,120,90,180))
    # 茶盏（右）
    d.ellipse([644,460,684,480], fill=(*BAM_H, 200))
    d.ellipse([648,462,680,478], fill=(80,120,90,180))
    # 竹简（盟约）
    pb(d, 440, 440, 144, 50, (*BAM_S, 200))
    pb(d, 446, 444, 132, 42, (*BAM, 180))
    for i in range(4):
        pb(d, 452, 450+i*9, 120, 1, (*INK, 120))
    # 左侧人物剪影
    d.polygon([(200,300),(240,260),(280,280),(270,380),(210,380)],
              fill=(60,55,50,200))
    d.ellipse([220,240,260,280], fill=(65,60,55,200))
    # 右侧人物剪影
    d.polygon([(744,300),(784,260),(824,280),(814,380),(754,380)],
              fill=(55,50,48,200))
    d.ellipse([764,240,804,280], fill=(60,55,50,200))
    # 和平光晕
    for r in range(160, 0, -1):
        alpha = max(5, 30 - r//5)
        for i in range(36):
            angle = math.radians(i * 10)
            x = int(512 + r * math.cos(angle))
            y = int(400 + r * math.sin(angle) * 0.5)
            if 0 <= x < SZ and 0 <= y < SZ:
                d.point((x, y), fill=(180,200,160, alpha))
    # 飞鸟
    for bx, by in [(300,180),(700,160),(500,140)]:
        for wing in [-1, 1]:
            for s in range(15):
                wx = bx + wing * s
                wy = by - abs(s-7)
                d.point((wx, wy), fill=(80,75,70, 160))
    draw_border(d, BAM_S)
    draw_text_centered(d, 512, 880, "和谈", FONT_CN, 120, (*BAM_H, 230))
    save(img, "dip_peace")


# ══════════════════════════════════════════════════════════
#  4. 朝贡 — 金银珠宝进献
# ══════════════════════════════════════════════════════════
def dip_tribute():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_bg(d, (40,35,25), (65,55,40))
    # 宝箱
    pb(d, 350, 500, 324, 120, (*BAM_D, 220))
    pb(d, 358, 506, 308, 108, (*BAM_S, 200))
    # 箱盖打开
    d.polygon([(350,500),(512,420),(674,500)], fill=(*BAM_D, 220))
    d.polygon([(358,498),(512,428),(666,498)], fill=(*BAM_S, 200))
    # 金银珠宝溢出
    random.seed(3001)
    for _ in range(40):
        gx = random.randint(380, 644)
        gy = random.randint(420, 500)
        size = random.randint(6, 14)
        c = random.choice([GOLD, (240,210,100), (200,170,60), (180,160,120)])
        alpha = random.randint(180, 240)
        d.ellipse([gx,gy,gx+size,gy+size], fill=(*c, alpha))
    # 金元宝
    for gx in [420, 480, 540, 600]:
        d.ellipse([gx,460,gx+20,480], fill=(*GOLD, 220))
        d.ellipse([gx+4,464,gx+16,476], fill=(240,220,120,200))
    # 玉璧
    d.ellipse([460,430,560,470], fill=(140,180,140,200))
    d.ellipse([480,442,540,458], fill=(160,200,160,180))
    # 进献者（左侧跪姿）
    d.polygon([(180,520),(220,480),(260,500),(250,600),(190,600)],
              fill=(60,55,50,200))
    d.ellipse([200,460,240,500], fill=(65,60,55,200))
    # 托盘
    pb(d, 180, 500, 80, 10, (*BRO_H, 200))
    for i in range(3):
        d.ellipse([190+i*20,486,210+i*20,500], fill=(*GOLD, 200))
    # 接受者（右侧高坐）
    pb(d, 740, 360, 120, 160, (70,60,52,200))
    d.polygon([(730,360),(800,310),(870,360)], fill=(60,52,44,200))
    d.polygon([(760,400),(790,380),(820,400),(810,480),(770,480)],
              fill=(65,58,50,200))
    d.ellipse([770,360,810,400], fill=(68,60,52,200))
    # 金色光点
    for _ in range(50):
        px = random.randint(300, 700)
        py = random.randint(350, 550)
        size = random.randint(2, 6)
        d.ellipse([px,py,px+size,py+size], fill=(*GOLD, random.randint(60,150)))
    draw_border(d, BAM_S)
    draw_text_centered(d, 512, 880, "朝贡", FONT_CN, 120, (*BAM_H, 230))
    save(img, "dip_tribute")


# ══════════════════════════════════════════════════════════
#  5. 联姻 — 鸾凤和鸣
# ══════════════════════════════════════════════════════════
def dip_marriage():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_bg(d, (60,30,35), (90,45,50))
    # 双喜红绸
    pb(d, 200, 200, 624, 8, (180,40,30,200))
    pb(d, 200, 220, 624, 8, (180,40,30,200))
    # 红绸垂落
    for i in range(60):
        wave = int(8 * math.sin(i * 0.15))
        pb(d, 200+wave, 228+i, 624, 2, (160,35,25, max(80,180-i*2)))
    # 鸾鸟（左）
    d.polygon([(280,400),(320,360),(360,380),(350,450),(290,450)],
              fill=(180,60,50,220))
    d.ellipse([300,340,340,380], fill=(200,80,60,200))
    # 冠羽
    for i in range(3):
        angle = math.radians(250 + i * 20)
        for s in range(30):
            px = int(320 + s * math.cos(angle))
            py = int(350 + s * math.sin(angle))
            if 0 <= px < SZ and 0 <= py < SZ:
                d.point((px, py), fill=(*GOLD, max(80,200-s*6)))
    # 凤鸟（右）
    d.polygon([(664,400),(704,360),(744,380),(734,450),(674,450)],
              fill=(200,80,60,220))
    d.ellipse([684,340,724,380], fill=(220,100,70,200))
    # 冠羽
    for i in range(3):
        angle = math.radians(250 + i * 20)
        for s in range(30):
            px = int(704 + s * math.cos(angle))
            py = int(350 + s * math.sin(angle))
            if 0 <= px < SZ and 0 <= py < SZ:
                d.point((px, py), fill=(*GOLD, max(80,200-s*6)))
    # 尾羽交汇
    for i in range(40):
        # 左尾
        lx = 350 + i * 3
        ly = 440 + i * 2
        if 0 <= lx < SZ and 0 <= ly < SZ:
            d.point((lx, ly), fill=(180,60,50, max(60,180-i*3)))
        # 右尾
        rx = 674 - i * 3
        ry = 440 + i * 2
        if 0 <= rx < SZ and 0 <= ry < SZ:
            d.point((rx, ry), fill=(200,80,60, max(60,180-i*3)))
    # 合卺杯
    d.ellipse([470,500,510,540], fill=(*BAM_H, 200))
    d.ellipse([514,500,554,540], fill=(*BAM_H, 200))
    d.line([(510,520),(514,520)], fill=(*BAM, 200), width=4)
    # 红烛
    for cx in [350, 674]:
        pb(d, cx-6, 380, 12, 100, (180,40,30,200))
        d.ellipse([cx-8,360,cx+8,385], fill=(240,180,50,200))
        d.ellipse([cx-4,350,cx+4,370], fill=(255,220,80,220))
    # 花瓣飘落
    random.seed(4001)
    for _ in range(40):
        px = random.randint(200, 824)
        py = random.randint(200, 600)
        size = random.randint(3, 8)
        d.ellipse([px,py,px+size,py+size], fill=(200,80,80, random.randint(80,180)))
    draw_border(d, (140,40,35))
    draw_text_centered(d, 512, 880, "联姻", FONT_CN, 120, (220,180,160,230))
    save(img, "dip_marriage")


# ══════════════════════════════════════════════════════════
#  6. 背叛 — 断裂玉珏
# ══════════════════════════════════════════════════════════
def dip_betrayal():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_bg(d, (25,20,22), (45,35,38))
    # 断裂玉珏（左半）
    d.ellipse([300,350,500,550], fill=(120,160,130,200))
    d.ellipse([320,370,480,530], fill=(140,180,150,180))
    d.ellipse([370,420,430,480], fill=(100,140,110,180))
    # 断裂面
    for i in range(40):
        x = 490 + random.randint(-3, 3)
        y = 370 + i * 4
        if 0 <= x < SZ and 0 <= y < SZ:
            d.point((x, y), fill=(80,100,85, 180))
    # 断裂玉珏（右半）
    d.ellipse([524,350,724,550], fill=(120,160,130,200))
    d.ellipse([544,370,704,530], fill=(140,180,150,180))
    d.ellipse([594,420,654,480], fill=(100,140,110,180))
    # 断裂面
    for i in range(40):
        x = 534 + random.randint(-3, 3)
        y = 370 + i * 4
        if 0 <= x < SZ and 0 <= y < SZ:
            d.point((x, y), fill=(80,100,85, 180))
    # 裂缝火花
    for _ in range(30):
        sx = 512 + random.randint(-20, 20)
        sy = 400 + random.randint(-40, 40)
        size = random.randint(2, 6)
        c = random.choice([(200,180,120),(180,160,100),(220,200,140)])
        d.ellipse([sx,sy,sx+size,sy+size], fill=(*c, random.randint(120,220)))
    # 暗色裂纹蔓延
    for i in range(5):
        sx = 512
        sy = 450
        angle = math.radians(random.uniform(0, 360))
        for s in range(random.randint(40, 80)):
            px = int(sx + s * math.cos(angle + s*0.03))
            py = int(sy + s * math.sin(angle + s*0.03))
            if 0 <= px < SZ and 0 <= py < SZ:
                d.point((px, py), fill=(40,30,30, max(40, 160-s*3)))
    # 暗色烟雾
    random.seed(5001)
    for _ in range(40):
        px = random.randint(300, 724)
        py = random.randint(300, 550)
        size = random.randint(15, 40)
        d.ellipse([px,py,px+size,py+size], fill=(30,25,25, random.randint(30,80)))
    draw_border(d, (80,40,35))
    draw_text_centered(d, 512, 880, "背叛", FONT_CN, 120, (180,140,120,230))
    save(img, "dip_betrayal")


# ══════════════════════════════════════════════════════════
#  7. 停战 — 兵器放下
# ══════════════════════════════════════════════════════════
def dip_ceasefire():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_bg(d, (35,42,52), (55,60,70))
    # 地面
    pb(d, 0, 600, SZ, 424, (55,48,40,180))
    # 放下的剑
    d.line([(300,620),(724,620)], fill=(180,185,195,200), width=8)
    pb(d, 280, 612, 40, 16, (*GOLD, 200))
    pb(d, 260, 616, 20, 8, (*BRO, 200))
    # 放下的矛
    d.line([(350,580),(350,680)], fill=(140,130,110,200), width=6)
    d.polygon([(340,580),(350,560),(360,580)], fill=(*IRON, 220))
    d.line([(674,580),(674,680)], fill=(140,130,110,200), width=6)
    d.polygon([(664,580),(674,560),(684,580)], fill=(*IRON, 220))
    # 盾牌
    d.polygon([(480,600),(512,570),(544,600),(536,640),(488,640)],
              fill=(*BRO, 200))
    # 白旗
    pb(d, 508, 300, 6, 280, (*BRO_H, 200))
    for i in range(40):
        wave = int(6 * math.sin(i * 0.2))
        pb(d, 514, 310+i, 50+wave, 2, (220,220,210, max(120,200-i*2)))
    # 橄榄枝
    for i in range(8):
        lx = 440 + i * 20
        ly = 450 - int(10 * math.sin(i * 0.4))
        d.ellipse([lx,ly,lx+16,ly+10], fill=(80,130,60,180))
    d.line([(420,460),(600,440)], fill=(70,100,50,180), width=4)
    # 和平光晕
    for r in range(120, 0, -1):
        alpha = max(5, 25 - r//5)
        for i in range(24):
            angle = math.radians(i * 15)
            x = int(512 + r * math.cos(angle))
            y = int(400 + r * math.sin(angle) * 0.5)
            if 0 <= x < SZ and 0 <= y < SZ:
                d.point((x, y), fill=(160,190,220, alpha))
    draw_border(d, BAM_S)
    draw_text_centered(d, 512, 880, "停战", FONT_CN, 120, (*BAM_H, 230))
    save(img, "dip_ceasefire")


# ══════════════════════════════════════════════════════════
#  8. 割让 — 地图划分
# ══════════════════════════════════════════════════════════
def dip_cession():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_bg(d, (40,38,32), (60,55,45))
    # 地图底
    pb(d, 150, 150, 724, 550, (*BAM_D, 200))
    pb(d, 160, 158, 704, 534, (*BAM_S, 180))
    # 山川纹理
    random.seed(6001)
    for _ in range(80):
        px = random.randint(170, 854)
        py = random.randint(168, 682)
        size = random.randint(3, 10)
        c = random.choice([(80,75,65),(90,82,70),(70,65,58)])
        d.ellipse([px,py,px+size,py+size], fill=(*c, 100))
    # 分界线（锯齿状）
    for y in range(160, 690):
        x = 512 + int(30 * math.sin(y * 0.05)) + random.randint(-5, 5)
        for dx in range(-3, 4):
            if 160 < x+dx < 864:
                d.point((x+dx, y), fill=(200,40,30, 200))
    # 割让区域（红色斜线阴影）
    for y in range(160, 690):
        for x in range(512, 864):
            if (x + y) % 12 < 3:
                d.point((x, y), fill=(180,40,30, 60))
    # 保留区域（正常）
    # 印章
    d.ellipse([350,500,450,580], outline=(180,40,30,200), width=6)
    draw_text_centered(d, 400, 540, "割", FONT_CN, 48, (180,40,30,200))
    d.ellipse([574,500,674,580], outline=(180,40,30,200), width=6)
    draw_text_centered(d, 624, 540, "让", FONT_CN, 48, (180,40,30,200))
    # 毛笔
    d.line([(780,200),(820,160)], fill=(60,50,40,200), width=6)
    d.polygon([(816,160),(824,140),(828,160)], fill=(20,20,20,220))
    draw_border(d, BAM_S)
    draw_text_centered(d, 512, 880, "割让", FONT_CN, 120, (*BAM_H, 230))
    save(img, "dip_cession")


# ══════════════════════════════════════════════════════════
#  9. 间谍 — 暗影窥探
# ══════════════════════════════════════════════════════════
def dip_spy():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_bg(d, (15,18,25), (30,32,40))
    # 暗夜城楼剪影
    pb(d, 300, 350, 424, 250, (35,32,30,180))
    pb(d, 310, 358, 404, 234, (42,38,36,160))
    for x in range(300, 724, 40):
        pb(d, x, 334, 28, 20, (35,32,30,180))
    d.polygon([(280,350),(512,280),(744,350)], fill=(32,28,26,180))
    # 城门
    d.arc([470,500,554,570], 180, 360, fill=(20,18,16,200), width=6)
    # 暗影人物
    d.polygon([(440,420),(470,380),(500,400),(490,520),(450,520)],
              fill=(20,20,22,220))
    d.ellipse([452,360,488,400], fill=(22,22,24,220))
    # 面巾
    pb(d, 456, 375, 28, 10, (30,28,26,200))
    # 窥视目光
    d.point((464, 382), fill=(200,180,100, 220))
    d.point((476, 382), fill=(200,180,100, 220))
    # 密信
    pb(d, 600, 450, 80, 50, (*BAM_D, 180))
    pb(d, 606, 454, 68, 42, (*BAM, 160))
    for i in range(4):
        pb(d, 612, 460+i*8, 56, 1, (*INK, 100))
    # 暗影烟雾
    random.seed(7001)
    for _ in range(60):
        px = random.randint(100, 924)
        py = random.randint(100, 600)
        size = random.randint(20, 60)
        d.ellipse([px,py,px+size,py+size], fill=(15,15,20, random.randint(20,60)))
    # 月牙
    d.ellipse([700,80,780,160], fill=(200,200,190,180))
    d.ellipse([720,75,800,155], fill=(15,18,25,200))
    # 猫头鹰
    d.ellipse([180,200,220,240], fill=(40,38,35,180))
    d.point((192,218), fill=(200,180,100,200))
    d.point((208,218), fill=(200,180,100,200))
    draw_border(d, (40,35,30))
    draw_text_centered(d, 512, 880, "间谍", FONT_CN, 120, (160,150,130,230))
    save(img, "dip_spy")


# ══════════════════════════════════════════════════════════
#  10. 贸易协定 — 商队+契约
# ══════════════════════════════════════════════════════════
def dip_trade():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_bg(d, (40,35,28), (60,52,40))
    # 商道
    for x in range(SZ):
        y = int(650 + 20 * math.sin(x * 0.01))
        pb(d, x, y, 1, 40, (70,62,50, 120))
    # 商队骆驼
    for cx in [200, 400, 600]:
        # 驼身
        d.polygon([(cx-30,580),(cx,550),(cx+30,560),(cx+25,600),(cx-25,600)],
                  fill=(140,120,90,200))
        d.ellipse([cx-8,540,cx+8,558], fill=(130,110,82,200))
        # 驼峰
        d.ellipse([cx-15,555,cx+15,575], fill=(150,130,98,180))
        # 货物
        pb(d, cx-20, 545, 40, 20, (*BAM_S, 180))
        # 腿
        for lx in [cx-20, cx+18]:
            pb(d, lx, 598, 4, 22, (120,100,75,200))
    # 契约竹简
    pb(d, 380, 300, 264, 150, (*BAM_D, 220))
    pb(d, 390, 308, 244, 134, (*BAM, 200))
    for i in range(10):
        pb(d, 400, 318+i*12, 224, 2, (*INK, 120))
    # 印章
    d.ellipse([460,390,560,440], outline=(180,40,30,200), width=4)
    draw_text_centered(d, 510, 415, "信", FONT_CN, 36, (180,40,30,200))
    # 金币堆
    for gx in [250, 750]:
        for i in range(5):
            for j in range(3):
                d.ellipse([gx+i*14, 620+j*10, gx+12+i*14, 628+j*10],
                         fill=(*GOLD, 200))
    # 旗号
    for x in [150, 874]:
        pb(d, x, 300, 5, 120, (*BRO_H, 180))
        for i in range(18):
            wave = int(4 * math.sin(i * 0.3))
            pb(d, x+5, 308+i, 28+wave, 2, (*BAM, max(100,180-i*4)))
    draw_border(d, BAM_S)
    draw_text_centered(d, 512, 880, "贸易", FONT_CN, 120, (*BAM_H, 230))
    save(img, "dip_trade")


def generate_all():
    print("=== 《山河策》外交交互图片生成器 (1024x1024) ===\n")
    dips = [
        dip_alliance, dip_declare_war, dip_peace, dip_tribute,
        dip_marriage, dip_betrayal, dip_ceasefire, dip_cession,
        dip_spy, dip_trade,
    ]
    for func in dips:
        func()
    print(f"\n=== 完成！共 {len(dips)} 张外交图片 ===")
    print(f"输出: {OUT_DIR}")
    print("规格: 1024x1024 | 系统隶书 | 透明背景")
    print("\n请在本地查看 diplomacy/ 目录即可。")

if __name__ == "__main__":
    generate_all()
