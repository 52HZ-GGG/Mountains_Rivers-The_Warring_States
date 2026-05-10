"""
《山河策》七国旗帜生成器 V4
1024x1024 | 每国独立造型 | 系统中文字体 | 透明背景 | 超高细节
运行: python generate_flags.py
"""

import os, math, random
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "flag1")
os.makedirs(OUT_DIR, exist_ok=True)

SZ = 1024

# ── 色板 ──
INK = {"b":(26,26,27), "h":(51,51,52), "s":(13,13,14), "d":(0,0,0)}
BAM = {"b":(197,163,104), "h":(217,190,139), "s":(153,122,74), "d":(102,82,49)}
LAC = {"b":(140,69,34), "h":(176,93,59), "s":(102,48,24), "d":(64,29,15)}
BRO = {"b":(43,51,48), "h":(69,82,77), "s":(26,33,30), "d":(13,18,16)}

# ── 七国各不同字体 ──
FONTS = {
    "秦": "C:/Windows/Fonts/STLITI.TTF",
    "赵": "C:/Windows/Fonts/STXIHEI.TTF",
    "齐": "C:/Windows/Fonts/STSONG.TTF",
    "楚": "C:/Windows/Fonts/STXINWEI.TTF",
    "魏": "C:/Windows/Fonts/STKAITI.TTF",
    "燕": "C:/Windows/Fonts/simhei.ttf",
    "韩": "C:/Windows/Fonts/STHUPO.TTF",
}

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


# ══════════════════════════════════════════════════════════
#  秦 — 虎符兵令：上圆下方玉玺形，虎纹篆刻
# ══════════════════════════════════════════════════════════
def flag_qin():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 主体：上圆下方（天圆地方）
    d.pieslice([112, 80, 912, 560], 180, 360, fill=(*LAC["b"], 230))
    d.pieslice([136, 104, 888, 536], 180, 360, fill=(*LAC["s"], 210))
    d.rectangle([112, 320, 912, 920], fill=(*LAC["b"], 230))
    d.rectangle([136, 344, 888, 896], fill=(*LAC["s"], 210))
    # 虎纹横带
    for i in range(6):
        y = 200 + i * 112
        if y > 800:
            break
        d.polygon([(160, y), (320, y-32), (328, y+24), (168, y+56)], fill=(*INK["b"], 180))
        d.polygon([(696, y), (856, y-32), (864, y+24), (704, y+56)], fill=(*INK["b"], 180))
    # 虎头徽记
    cx, cy = 512, 440
    d.ellipse([cx-112, cy-88, cx+112, cy+72], fill=(*LAC["h"], 220))
    d.polygon([(cx-96, cy-72), (cx-72, cy-120), (cx-40, cy-64)], fill=(*LAC["h"], 210))
    d.polygon([(cx+96, cy-72), (cx+72, cy-120), (cx+40, cy-64)], fill=(*LAC["h"], 210))
    d.ellipse([cx-64, cy-40, cx-24, cy], fill=(*BAM["h"], 230))
    d.point((cx-44, cy-20), fill=(*INK["d"], 240))
    d.ellipse([cx+24, cy-40, cx+64, cy], fill=(*BAM["h"], 230))
    d.point((cx+44, cy-20), fill=(*INK["d"], 240))
    d.polygon([(cx-16, cy+8), (cx, cy-8), (cx+16, cy+8)], fill=(*INK["b"], 200))
    d.arc([cx-56, cy+8, cx+56, cy+64], 0, 180, fill=(*INK["b"], 200), width=8)
    for dx in [-80, -64, 64, 80]:
        d.line([(cx+dx//2, cy+16), (cx+dx, cy+8)], fill=(*BAM["h"], 180), width=4)
    # 篆刻边框
    d.arc([104, 72, 920, 568], 180, 360, fill=(*INK["b"], 220), width=12)
    d.line([(104, 320), (104, 928)], fill=(*INK["b"], 220), width=12)
    d.line([(920, 320), (920, 928)], fill=(*INK["b"], 220), width=12)
    d.line([(104, 928), (920, 928)], fill=(*INK["b"], 220), width=12)
    d.arc([128, 96, 896, 544], 180, 360, fill=(*BAM["s"], 180), width=4)
    d.line([(128, 344), (128, 904)], fill=(*BAM["s"], 180), width=4)
    d.line([(896, 344), (896, 904)], fill=(*BAM["s"], 180), width=4)
    d.line([(128, 904), (896, 904)], fill=(*BAM["s"], 180), width=4)
    # 国名
    draw_text_centered(d, 512, 760, "秦", FONTS["秦"], 192, (*BAM["h"], 230))
    # 底部装饰带
    pb(d, 200, 952, 624, 12, (*BAM["d"], 140))
    pb(d, 240, 976, 544, 8, (*BAM["d"], 100))
    save(img, "flag_qin")


# ══════════════════════════════════════════════════════════
#  赵 — 胡服骑射：燕尾三角旗，骑兵骑射剪影
# ══════════════════════════════════════════════════════════
def flag_zhao():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    d.polygon([(80,80),(944,512),(80,944)], fill=(*BRO["b"], 230))
    d.polygon([(120,120),(896,512),(120,904)], fill=(*BRO["h"], 210))
    d.polygon([(80,280),(260,512),(80,744)], fill=(0,0,0,0))
    # 骑兵骑射剪影
    d.polygon([(320,400),(600,360),(640,440),(560,500),(340,480)],
              fill=(*BRO["s"], 220))
    for lx in [380, 440, 520, 580]:
        d.line([(lx, 472), (lx-16, 580)], fill=(*BRO["d"], 200), width=8)
    for i in range(48):
        d.point((328-i//2, 420+i), fill=(*INK["b"], 180))
    d.polygon([(432,280),(540,260),(552,380),(420,400)], fill=(*BRO["s"], 220))
    d.ellipse([460, 208, 520, 268], fill=(*BAM["s"], 200))
    d.arc([456, 192, 524, 248], 180, 360, fill=(*BRO["h"], 220), width=8)
    for i in range(80):
        angle = math.radians(50 + i * 2)
        px = int(592 + 72 * math.cos(angle))
        py = int(288 + 72 * math.sin(angle))
        d.point((px, py), fill=(*BAM["h"], 200))
    d.line([(592, 288), (660, 240)], fill=(*BAM["d"], 200), width=4)
    d.line([(552, 320), (660, 240)], fill=(*BRO["h"], 200), width=4)
    d.point((660, 240), fill=(160,165,175, 220))
    # 边框
    d.polygon([(72,72),(952,512),(72,952)], outline=(*BAM["h"], 200), width=8)
    d.polygon([(112,112),(904,512),(112,912)], outline=(*BAM["s"], 140), width=4)
    # 流苏
    for i in range(20):
        y = 360 + i * 20
        for s in range(32):
            d.point((88+s, y+s//2), fill=(*BAM["h"], max(0, 160-s*4)))
    draw_text_centered(d, 480, 720, "赵", FONTS["赵"], 160, (*BAM["h"], 230))
    save(img, "flag_zhao")


# ══════════════════════════════════════════════════════════
#  齐 — 稷下学宫：玉璧环形，谷纹密布
# ══════════════════════════════════════════════════════════
def flag_qi():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    d.ellipse([72, 72, 952, 952], fill=(*BAM["b"], 230))
    d.ellipse([104, 104, 920, 920], fill=(*BAM["s"], 210))
    d.ellipse([200, 200, 824, 824], fill=(*BAM["b"], 220))
    d.ellipse([224, 224, 800, 800], fill=(*BAM["s"], 200))
    d.ellipse([320, 320, 704, 704], fill=(*BAM["d"], 220))
    d.ellipse([344, 344, 680, 680], fill=(*BAM["b"], 200))
    # 谷纹
    random.seed(301)
    for ring_r in [272, 328, 384, 440]:
        count = int(ring_r * 0.15)
        for i in range(count):
            angle = math.radians(i * (360 / count) + random.uniform(-3, 3))
            gx = int(cx + ring_r * math.cos(angle))
            gy = int(cy + ring_r * math.sin(angle))
            if 160 < gx < 864 and 160 < gy < 864:
                dist = math.sqrt((gx-cx)**2 + (gy-cy)**2)
                if dist > 248 or dist < 180:
                    d.ellipse([gx-8, gy-8, gx+8, gy+8], fill=(*BAM["h"], 200))
                    d.point((gx-4, gy-4), fill=(*BAM["b"], 220))
    # 竹简纹
    for i in range(20):
        y = 440 + i * 8
        pb(d, 368, y, 288, 1, (*BAM["s"], 140))
    d.ellipse([312, 312, 712, 712], outline=(*BAM["h"], 180), width=4)
    draw_text_centered(d, cx, cy, "齐", FONTS["齐"], 208, (*BAM["h"], 230))
    d.ellipse([64, 64, 960, 960], outline=(*BAM["h"], 200), width=8)
    d.ellipse([88, 88, 936, 936], outline=(*BAM["s"], 140), width=4)
    # 缨络
    for i in range(28):
        x = 440 + i * 6
        for s in range(48):
            d.point((x+s//3, 56-s), fill=(*BAM["h"], max(80, 180-s*3)))
    save(img, "flag_qi")


# ══════════════════════════════════════════════════════════
#  楚 — 凤凰涅槃：菱形凤鸟，尾羽飘逸
# ══════════════════════════════════════════════════════════
def flag_chu():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    d.polygon([(cx,64),(SZ-64,cy),(cx,SZ-64),(64,cy)], fill=(90,40,50,230))
    d.polygon([(cx,112),(SZ-112,cy),(cx,SZ-112),(112,cy)], fill=(110,50,60,210))
    # 凤凰主体
    d.polygon([(cx-72,cy-40),(cx+72,cy-40),(cx+88,cy+120),(cx-88,cy+120)],
              fill=(180,80,90,220))
    d.ellipse([cx-48, cy-112, cx+48, cy-32], fill=(200,100,110,220))
    # 冠羽
    for i in range(3):
        angle = math.radians(250 + i * 20)
        for s in range(72):
            px = int(cx + (s+32) * math.cos(angle))
            py = int(cy-80 + (s+32) * math.sin(angle))
            if 0 <= px < SZ and 0 <= py < SZ:
                c = [(220,140,60),(200,120,50),(180,100,40)][i]
                alpha = max(80, 220-s*3)
                d.point((px, py), fill=(*c, alpha))
    d.point((cx-16, cy-72), fill=(*BAM["h"], 230))
    d.point((cx+16, cy-72), fill=(*BAM["h"], 230))
    d.polygon([(cx-12, cy-48), (cx, cy-64), (cx+12, cy-48)], fill=(200,160,60,220))
    # 左翅
    for i in range(100):
        angle = math.radians(140 + i * 1.25)
        r = 160 + 32 * math.sin(i * 0.125)
        wx = int(cx-40 + r * math.cos(angle))
        wy = int(cy + r * 0.6 * math.sin(angle))
        if 0 <= wx < SZ and 0 <= wy < SZ:
            c = (160,70,80) if i % 3 != 0 else (180,90,100)
            alpha = max(100, 200-i*2)
            d.point((wx, wy), fill=(*c, alpha))
    # 右翅
    for i in range(100):
        angle = math.radians(40 - i * 1.25)
        r = 160 + 32 * math.sin(i * 0.125)
        wx = int(cx+40 + r * math.cos(angle))
        wy = int(cy + r * 0.6 * math.sin(angle))
        if 0 <= wx < SZ and 0 <= wy < SZ:
            c = (160,70,80) if i % 3 != 0 else (180,90,100)
            alpha = max(100, 200-i*2)
            d.point((wx, wy), fill=(*c, alpha))
    # 尾羽
    for i in range(3):
        base_x = cx - 40 + i * 40
        base_y = cy + 120
        for s in range(140):
            t = s / 140
            tx = int(base_x + (i-1) * t * 80 + 20 * math.sin(s * 0.075))
            ty = int(base_y + s * 1.5)
            if 0 <= tx < SZ and 0 <= ty < SZ:
                c = [(200,100,60),(180,80,100),(160,60,80)][i]
                alpha = max(60, 200-s*1)
                d.point((tx, ty), fill=(*c, alpha))
    # 边框
    d.polygon([(cx,56),(SZ-56,cy),(cx,SZ-56),(56,cy)],
              outline=(200,140,60,200), width=8)
    for ax, ay in [(cx,56),(SZ-56,cy),(cx,SZ-56),(56,cy)]:
        d.ellipse([ax-16, ay-16, ax+16, ay+16], fill=(220,160,60,200))
    draw_text_centered(d, cx, cy+260, "楚", FONTS["楚"], 160, (*BAM["h"], 230))
    save(img, "flag_chu")


# ══════════════════════════════════════════════════════════
#  魏 — 武卒铁甲：六角盾牌，甲片纹理
# ══════════════════════════════════════════════════════════
def flag_wei():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    pts_outer = []
    pts_inner = []
    for i in range(6):
        angle = math.radians(-90 + i * 60)
        pts_outer.append((int(cx + 440 * math.cos(angle)), int(cy + 440 * math.sin(angle))))
        pts_inner.append((int(cx + 400 * math.cos(angle)), int(cy + 400 * math.sin(angle))))
    d.polygon(pts_outer, fill=(*BRO["b"], 230))
    d.polygon(pts_inner, fill=(*BRO["h"], 210))
    # 鱼鳞甲
    for row in range(40):
        y = 200 + row * 18
        offset = 12 if row % 2 == 0 else 0
        for col in range(48):
            x = 120 + col * 18 + offset
            dx = abs(x - cx)
            dy = abs(y - cy)
            if dx < 360 and dy < 360:
                d.arc([x-6, y-4, x+6, y+8], 0, 180, fill=(*BRO["b"], 180), width=1)
                d.arc([x-5, y-3, x+5, y+7], 0, 180, fill=(*BRO["s"], 140), width=1)
                if row % 3 == 0 and col % 3 == 0:
                    d.ellipse([x-8, y-8, x+8, y+8], fill=(*BAM["s"], 200))
                    d.point((x-4, y-4), fill=(*BAM["h"], 220))
    # 护心镜
    d.ellipse([cx-112, cy-112, cx+112, cy+112], fill=(*BAM["b"], 220))
    d.ellipse([cx-88, cy-88, cx+88, cy+88], fill=(*BAM["h"], 200))
    d.ellipse([cx-56, cy-56, cx+56, cy+56], fill=(*BAM["s"], 180))
    d.ellipse([cx-24, cy-24, cx+24, cy+24], fill=(*BAM["h"], 220))
    d.point((cx-16, cy-16), fill=(255, 250, 230, 180))
    # 盾缘铆钉
    for i in range(6):
        angle = math.radians(-90 + i * 60)
        for s in [340, 380]:
            nx = int(cx + s * math.cos(angle))
            ny = int(cy + s * math.sin(angle))
            d.ellipse([nx-12, ny-12, nx+12, ny+12], fill=(*BAM["s"], 200))
            d.point((nx-4, ny-4), fill=(*BAM["h"], 220))
    d.polygon(pts_outer, outline=(*BAM["h"], 200), width=8)
    draw_text_centered(d, cx, cy+220, "魏", FONTS["魏"], 176, (*BAM["h"], 230))
    save(img, "flag_wei")


# ══════════════════════════════════════════════════════════
#  燕 — 辽东突骑：长条旌旗，寒月狼图腾
# ══════════════════════════════════════════════════════════
def flag_yan():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 长条旌旗
    d.rectangle([320, 64, 704, 800], fill=(50,65,55,230))
    d.rectangle([344, 88, 680, 776], fill=(65,80,70,210))
    d.polygon([(320, 800), (512, 976), (704, 800)], fill=(50,65,55,230))
    d.polygon([(344, 800), (512, 952), (680, 800)], fill=(65,80,70,210))
    # 皮毛纹理
    random.seed(501)
    for _ in range(480):
        fx = random.randint(352, 672)
        fy = random.randint(96, 768)
        if random.random() < 0.35:
            c = random.choice([(80,60,45), (90,70,50), (70,55,40)])
            d.point((fx, fy), fill=(*c, 140))
    # 寒月
    d.ellipse([400, 200, 624, 424], fill=(160,170,185,220))
    d.ellipse([424, 224, 600, 400], fill=(190,200,215,200))
    d.ellipse([472, 272, 504, 304], fill=(170,180,195,160))
    d.ellipse([528, 296, 552, 320], fill=(170,180,195,140))
    # 狼图腾
    d.polygon([(480,440),(560,432),(576,500),(464,508)], fill=(80,95,85,220))
    d.polygon([(544,432),(592,380),(608,420),(576,448)], fill=(80,95,85,220))
    d.polygon([(576,380),(584,344),(600,376)], fill=(70,85,75,200))
    d.polygon([(592,384),(604,352),(616,380)], fill=(70,85,75,200))
    d.point((572, 400), fill=(180,200,215,220))
    d.line([(592, 408), (608, 384)], fill=(60,75,65,200), width=4)
    for lx in [480, 512, 544, 568]:
        d.line([(lx, 500), (lx-8, 552)], fill=(70,85,75,200), width=4)
    for i in range(32):
        d.point((464-i//2, 460+i//3), fill=(80,95,85, max(100, 200-i*6)))
    # 雪花
    for sx, sy in [(380, 560), (640, 600), (440, 680), (592, 660)]:
        for arm in range(6):
            angle = math.radians(arm * 60)
            for s in range(20):
                px = int(sx + s * math.cos(angle))
                py = int(sy + s * math.sin(angle))
                if 344 < px < 680 and 88 < py < 776:
                    d.point((px, py), fill=(180,200,220, 150))
    # 旗杆
    pb(d, 504, 8, 16, 64, (*BRO["h"], 200))
    d.polygon([(496,8),(512,0),(528,8)], fill=(*BRO["h"], 220))
    d.rectangle([312, 56, 712, 808], outline=(*BAM["h"], 180), width=8)
    draw_text_centered(d, 512, 620, "燕", FONTS["燕"], 144, (*BAM["h"], 230))
    save(img, "flag_yan")


# ══════════════════════════════════════════════════════════
#  韩 — 劲弩连发：扇形弩臂，齿轮机关
# ══════════════════════════════════════════════════════════
def flag_han():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 扇形底
    for i in range(160):
        angle = math.radians(200 + i * 0.875)
        for r in range(40, 400):
            x = int(512 + r * math.cos(angle))
            y = int(800 + r * math.sin(angle))
            if 0 <= x < SZ and 0 <= y < SZ:
                c = (60,75,65) if r % 16 == 0 else (50,65,55)
                alpha = max(100, 200 - r//2)
                d.point((x, y), fill=(*c, alpha))
    # 弩臂放射线
    for i in range(36):
        angle = math.radians(205 + i * 4.5)
        for r in range(40, 400):
            x = int(512 + r * math.cos(angle))
            y = int(800 + r * math.sin(angle))
            if 0 <= x < SZ and 0 <= y < SZ:
                alpha = max(80, 200 - r)
                d.point((x, y), fill=(*BRO["h"], alpha))
    # 弩身
    pb(d, 488, 240, 48, 560, (*BRO["b"], 220))
    pb(d, 496, 248, 32, 544, (*BRO["h"], 200))
    for i in range(60):
        y = 260 + i * 9
        pb(d, 500, y, 24, 1, (*BRO["s"], 160))
    # 弩弦
    d.line([(488, 260), (200, 480)], fill=(180,180,170,200), width=8)
    d.line([(536, 260), (824, 480)], fill=(180,180,170,200), width=8)
    # 箭矢
    for i in range(3):
        ax = 468 + i * 28
        pb(d, ax, 160, 8, 320, (*BAM["s"], 200))
        d.polygon([(ax,160),(ax+4,120),(ax+8,160)], fill=(*BRO["h"], 220))
        d.point((ax-4, 472), fill=(180,50,40,180))
        d.point((ax+12, 472), fill=(180,50,40,180))
    # 齿轮
    gx, gy = 512, 800
    d.ellipse([gx-72, gy-72, gx+72, gy+72], outline=(*BRO["h"], 200), width=8)
    d.ellipse([gx-48, gy-48, gx+48, gy+48], outline=(*BRO["h"], 180), width=4)
    d.point((gx, gy), fill=(*BRO["h"], 220))
    for i in range(48):
        angle = math.radians(i * 7.5)
        for s in [56, 64, 72]:
            tx = int(gx + s * math.cos(angle))
            ty = int(gy + s * math.sin(angle))
            if 0 <= tx < SZ and 0 <= ty < SZ:
                d.point((tx, ty), fill=(*BRO["h"], 180))
    # 扇形边框
    for r in [400]:
        for i in range(160):
            angle = math.radians(200 + i * 0.875)
            x = int(512 + r * math.cos(angle))
            y = int(800 + r * math.sin(angle))
            if 0 <= x < SZ and 0 <= y < SZ:
                d.point((x, y), fill=(*BAM["h"], 160))
    draw_text_centered(d, 512, 920, "韩", FONTS["韩"], 144, (*BAM["h"], 230))
    save(img, "flag_han")


def generate_all():
    print("=== 《山河策》七国旗帜生成器 V4 (1024x1024) ===\n")
    for func in [flag_qin, flag_zhao, flag_qi, flag_chu, flag_wei, flag_yan, flag_han]:
        func()
    print(f"\n=== 完成！共 7 面旗帜 ===")
    print(f"输出: {OUT_DIR}")
    print("规格: 1024x1024 | 超高细节 | 透明背景")
    print("\n请在本地查看 flag1/ 目录即可。")

if __name__ == "__main__":
    generate_all()
