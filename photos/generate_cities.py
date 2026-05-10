"""
《山河策》城市插画生成器
1024x1024 | 14座城市各具特色 | 系统中文字体 | 透明背景
运行: python generate_cities.py
"""

import os, math, random
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "city")
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


# ══════════════════════════════════════════════════════════
#  通用：天空渐变 + 地面
# ══════════════════════════════════════════════════════════
def draw_sky(d, top_c, bot_c):
    for y in range(SZ):
        t = y / SZ
        r = int(top_c[0] + (bot_c[0]-top_c[0]) * t)
        g = int(top_c[1] + (bot_c[1]-top_c[1]) * t)
        b = int(top_c[2] + (bot_c[2]-top_c[2]) * t)
        pb(d, 0, y, SZ, 1, (r, g, b, 180))

def draw_ground(d, y_start, c1, c2):
    for y in range(y_start, SZ):
        t = (y - y_start) / (SZ - y_start)
        r = int(c1[0] + (c2[0]-c1[0]) * t)
        g = int(c1[1] + (c2[1]-c1[1]) * t)
        b = int(c1[2] + (c2[2]-c1[2]) * t)
        pb(d, 0, y, SZ, 1, (r, g, b, 200))

def draw_wall(d, x, y, w, h, c1, c2):
    pb(d, x, y, w, h, (*c1, 220))
    pb(d, x+4, y+4, w-8, h-8, (*c2, 200))
    for bx in range(x, x+w, max(1, w//8)):
        pb(d, bx, y-16, max(8, w//10), 20, (*c1, 220))

def draw_gate(d, x, y, w, h, c):
    d.arc([x, y, x+w, y+h], 180, 360, fill=(*c, 220), width=6)
    pb(d, x, y+h//2, w, h//2, (*c, 220))

def draw_mountain_bg(d, y_base, peaks, c, alpha=80):
    for x in range(SZ):
        h = y_base
        for px, py, pw in peaks:
            dist = abs(x - px)
            if dist < pw:
                h = min(h, py + int(dist * 0.6))
        for y in range(h, SZ):
            if y > y_base:
                t = (y - y_base) / (SZ - y_base)
                r = int(c[0] * (1 + t * 0.3))
                g = int(c[1] * (1 + t * 0.3))
                b = int(c[2] * (1 + t * 0.3))
                d.point((x, y), fill=(min(255,r), min(255,g), min(255,b), alpha))


# ══════════════════════════════════════════════════════════
#  1. 咸阳 — 秦都，高台宫殿，法家严峻
# ══════════════════════════════════════════════════════════
def city_xianyang():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (40,50,65), (80,90,100))
    draw_ground(d, 680, (60,50,40), (45,38,30))
    draw_mountain_bg(d, 500, [(200,350,300),(512,300,400),(800,360,300)], (50,60,55))
    # 高台基座（三层递减）
    pb(d, 200, 520, 624, 160, (70,60,50,220))
    pb(d, 220, 530, 584, 140, (85,72,60,200))
    pb(d, 260, 460, 504, 80, (70,60,50,220))
    pb(d, 280, 468, 464, 64, (85,72,60,200))
    pb(d, 320, 400, 384, 80, (70,60,50,220))
    pb(d, 340, 408, 344, 64, (85,72,60,200))
    # 台阶
    for i in range(6):
        y = 680 - i * 26
        w = 580 - i * 60
        x = 512 - w//2
        pb(d, x, y, w, 26, (75,65,55,200))
    # 主殿
    pb(d, 360, 300, 304, 120, (90,75,62,220))
    pb(d, 370, 308, 284, 104, (100,85,70,200))
    # 重檐屋顶
    d.polygon([(340,300),(512,230),(684,300)], fill=(60,50,42,220))
    d.polygon([(350,296),(512,240),(674,296)], fill=(75,62,50,200))
    d.polygon([(380,260),(512,200),(644,260)], fill=(60,50,42,220))
    # 殿门
    draw_gate(d, 480, 360, 64, 60, (40,35,30))
    # 廊柱
    for x in [380, 420, 460, 540, 580, 620]:
        pb(d, x, 310, 8, 100, (95,80,65,200))
    # 旗杆
    for x in [300, 724]:
        pb(d, x, 200, 6, 120, (*BRO_H, 200))
        for i in range(20):
            wave = int(4 * math.sin(i * 0.4))
            pb(d, x+6, 210+i, 30+wave, 2, (*LAC, max(120,200-i*4)))
    # 两侧望楼
    for tx in [180, 760]:
        pb(d, tx, 400, 60, 120, (80,68,58,220))
        pb(d, tx+6, 406, 48, 108, (90,76,64,200))
        d.polygon([(tx-10,400),(tx+30,360),(tx+70,400)], fill=(60,50,42,220))
    # 铁矿标志（熔炉）
    pb(d, 120, 620, 40, 50, (80,70,60,200))
    d.polygon([(115,620),(140,590),(165,620)], fill=(100,85,70,200))
    for i in range(8):
        d.point((135+i%3, 600-i*2), fill=(200,120,40, 180))
    # 城墙
    draw_wall(d, 100, 700, 824, 40, (70,60,50), (85,72,60))
    draw_gate(d, 470, 700, 84, 40, (40,35,30))
    draw_text_centered(d, 512, 920, "咸阳", FONT_CN, 120, (*BAM_H, 230))
    save(img, "city_xianyang")


# ══════════════════════════════════════════════════════════
#  2. 雍城 — 秦旧都，宗庙祭坛
# ══════════════════════════════════════════════════════════
def city_yongcheng():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (50,55,60), (85,80,75))
    draw_ground(d, 700, (65,55,45), (50,42,35))
    draw_mountain_bg(d, 520, [(300,380,250),(700,360,300)], (55,50,45))
    # 宗庙主殿
    pb(d, 250, 500, 524, 200, (80,68,58,220))
    pb(d, 270, 510, 484, 180, (92,78,66,200))
    d.polygon([(220,500),(512,420),(804,500)], fill=(65,55,45,220))
    d.polygon([(240,496),(512,430),(784,496)], fill=(80,68,56,200))
    # 祭坛
    pb(d, 380, 620, 264, 80, (75,65,55,220))
    pb(d, 400, 628, 224, 64, (88,75,63,200))
    # 鼎
    for dx in [-60, 0, 60]:
        cx = 512 + dx
        pb(d, cx-12, 600, 24, 20, (*LAC, 220))
        d.polygon([(cx-16,600),(cx,580),(cx+16,600)], fill=(*LAC_H, 200))
        pb(d, cx-4, 620, 8, 10, (*INK, 200))
    # 编钟架
    pb(d, 160, 480, 120, 80, (85,72,60,200))
    for i in range(6):
        bx = 168 + i * 18
        d.arc([bx, 490, bx+12, 520], 0, 180, fill=(*BAM, 200), width=2)
    # 竹林
    for i in range(12):
        bx = 820 + i * 16
        for j in range(8):
            by = 550 + j * 20
            pb(d, bx, by, 3, 18, (60,80,50,180))
    draw_wall(d, 120, 720, 784, 35, (70,60,50), (85,72,60))
    draw_text_centered(d, 512, 920, "雍城", FONT_CN, 120, (*BAM_H, 230))
    save(img, "city_yongcheng")


# ══════════════════════════════════════════════════════════
#  3. 邯郸 — 赵都，丛台+骑兵
# ══════════════════════════════════════════════════════════
def city_handan():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (45,55,70), (80,85,90))
    draw_ground(d, 680, (60,55,45), (48,42,35))
    draw_mountain_bg(d, 480, [(200,340,280),(512,310,350),(820,350,280)], (50,55,50))
    # 丛台（多层高台）
    for i in range(4):
        w = 400 - i * 60
        h = 60
        x = 512 - w//2
        y = 520 - i * 70
        pb(d, x, y, w, h, (75,65,55,220))
        pb(d, x+6, y+6, w-12, h-12, (88,76,64,200))
    # 顶部殿阁
    pb(d, 420, 260, 184, 80, (85,72,60,220))
    pb(d, 428, 266, 168, 68, (95,82,68,200))
    d.polygon([(400,260),(512,200),(624,260)], fill=(65,55,45,220))
    # 军旗
    for x in [380, 644]:
        pb(d, x, 180, 6, 100, (*BRO_H, 200))
        for i in range(25):
            wave = int(5 * math.sin(i * 0.4))
            pb(d, x+6, 188+i, 36+wave, 2, (*LAC, max(120,200-i*3)))
    # 马厩
    pb(d, 100, 560, 160, 120, (80,70,60,200))
    pb(d, 108, 568, 144, 104, (90,78,66,180))
    d.polygon([(90,560),(180,520),(270,560)], fill=(70,60,50,200))
    # 马匹剪影
    for mx in [130, 190]:
        d.polygon([(mx,620),(mx+20,600),(mx+40,610),(mx+35,640),(mx+5,640)],
                  fill=(60,50,40,200))
        d.ellipse([mx+18,590,mx+32,604], fill=(55,48,38,200))
    # 骑兵训练场
    pb(d, 700, 600, 200, 80, (65,58,48,180))
    for i in range(3):
        cx = 730 + i * 60
        d.line([(cx,640),(cx+30,620)], fill=(*BRO_H, 180), width=3)
        d.point((cx+30,618), fill=(*IRON, 200))
    draw_wall(d, 80, 700, 864, 40, (70,60,50), (85,72,60))
    draw_gate(d, 470, 700, 84, 40, (40,35,30))
    draw_text_centered(d, 512, 920, "邯郸", FONT_CN, 120, (*BAM_H, 230))
    save(img, "city_handan")


# ══════════════════════════════════════════════════════════
#  4. 代郡 — 赵北境，边塞堡垒+烽火台
# ══════════════════════════════════════════════════════════
def city_daijun():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (35,45,60), (65,70,80))
    draw_ground(d, 700, (55,50,42), (40,38,32))
    draw_mountain_bg(d, 460, [(150,300,200),(400,260,300),(650,280,250),(900,320,200)], (45,50,45))
    # 边塞城墙
    pb(d, 100, 500, 824, 200, (70,62,52,220))
    pb(d, 110, 508, 804, 184, (82,72,60,200))
    for x in range(100, 924, 40):
        pb(d, x, 480, 28, 24, (70,62,52,220))
    # 烽火台
    for tx in [200, 512, 824]:
        pb(d, tx-30, 380, 60, 140, (75,66,56,220))
        pb(d, tx-24, 386, 48, 128, (88,78,66,200))
        d.polygon([(tx-10,380),(tx,340),(tx+10,380)], fill=(200,100,40,200))
        for i in range(12):
            d.point((tx+random.randint(-5,5), 345-i*3),
                    fill=(240,160,50, max(80,200-i*15)))
    # 关隘门
    draw_gate(d, 480, 580, 64, 120, (40,35,30))
    # 马匹
    for mx in [300, 700]:
        d.polygon([(mx,660),(mx+25,640),(mx+50,650),(mx+45,690),(mx+5,690)],
                  fill=(55,48,38,200))
    # 雪花
    random.seed(4001)
    for _ in range(60):
        sx = random.randint(50, 974)
        sy = random.randint(50, 500)
        for arm in range(6):
            angle = math.radians(arm * 60)
            for s in range(8):
                px = int(sx + s * math.cos(angle))
                py = int(sy + s * math.sin(angle))
                if 0 <= px < SZ and 0 <= py < SZ:
                    d.point((px, py), fill=(200,210,230, 100))
    draw_text_centered(d, 512, 920, "代郡", FONT_CN, 120, (*BAM_H, 230))
    save(img, "city_daijun")


# ══════════════════════════════════════════════════════════
#  5. 临淄 — 齐都，盐池+商业繁荣
# ══════════════════════════════════════════════════════════
def city_linzi():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (50,60,75), (85,90,100))
    draw_ground(d, 700, (65,60,50), (50,45,38))
    # 大城
    draw_wall(d, 100, 500, 824, 200, (75,68,58), (90,80,68))
    # 小城（宫城）
    pb(d, 300, 380, 424, 140, (80,72,62,220))
    pb(d, 310, 388, 404, 124, (95,85,72,200))
    # 宫殿
    pb(d, 380, 300, 264, 100, (88,78,66,220))
    pb(d, 390, 308, 244, 84, (100,88,74,200))
    d.polygon([(360,300),(512,240),(664,300)], fill=(68,58,48,220))
    # 稷下学宫
    pb(d, 700, 400, 160, 120, (85,75,65,200))
    d.polygon([(690,400),(780,360),(870,400)], fill=(70,60,50,200))
    # 盐池
    for y in range(580, 700):
        for x in range(100, 300):
            wave = math.sin(x*0.05 + y*0.03) * 8
            if y + wave > 590:
                t = (y - 580) / 120
                r = int(180 + t * 30)
                g = int(200 + t * 20)
                b = int(220 + t * 15)
                d.point((x, y), fill=(r, g, b, 160))
    # 盐堆
    for sx in [140, 200, 260]:
        d.polygon([(sx-20,660),(sx,630),(sx+20,660)], fill=(220,220,210,200))
    # 商铺
    for i in range(5):
        bx = 350 + i * 80
        pb(d, bx, 620, 60, 60, (82,72,62,200))
        pb(d, bx+4, 624, 52, 52, (92,80,68,180))
        d.polygon([(bx-6,620),(bx+30,596),(bx+66,620)], fill=(70,60,50,200))
    # 旗帜
    for x in [350, 670]:
        pb(d, x, 280, 5, 120, (*BRO_H, 200))
        for i in range(20):
            wave = int(4 * math.sin(i * 0.4))
            pb(d, x+5, 288+i, 28+wave, 2, (*BAM, max(120,200-i*4)))
    draw_gate(d, 470, 700, 84, 40, (40,35,30))
    draw_text_centered(d, 512, 920, "临淄", FONT_CN, 120, (*BAM_H, 230))
    save(img, "city_linzi")


# ══════════════════════════════════════════════════════════
#  6. 即墨 — 齐海港，渔村+海防
# ══════════════════════════════════════════════════════════
def city_jimo():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (45,60,80), (70,85,105))
    draw_ground(d, 650, (60,58,50), (48,45,38))
    # 大海
    for y in range(650, SZ):
        for x in range(SZ):
            wave = math.sin(x*0.02 + y*0.03) * 12
            t = (y - 650) / (SZ - 650)
            r = int(30 + t * 20)
            g = int(60 + t * 25)
            b = int(100 + t * 30)
            d.point((x, y), fill=(r, g, b, 180))
    # 海浪
    random.seed(6001)
    for _ in range(40):
        wx = random.randint(50, 974)
        wy = random.randint(660, 980)
        for s in range(random.randint(10, 30)):
            if 0 <= wx+s < SZ:
                d.point((wx+s, wy), fill=(120,160,200, 120))
    # 渔船
    for bx, by in [(200,750),(600,780),(800,720)]:
        d.polygon([(bx-30,by),(bx,by-15),(bx+30,by),(bx+25,by+10),(bx-25,by+10)],
                  fill=(100,85,70,200))
        pb(d, bx-2, by-40, 4, 30, (*BRO_H, 180))
    # 海防城墙
    pb(d, 150, 520, 724, 130, (72,65,55,220))
    pb(d, 158, 528, 708, 114, (85,76,65,200))
    for x in range(150, 874, 36):
        pb(d, x, 504, 24, 20, (72,65,55,220))
    # 瞭望塔
    for tx in [250, 512, 774]:
        pb(d, tx-20, 420, 40, 120, (78,70,60,220))
        pb(d, tx-16, 424, 32, 112, (90,80,68,200))
        d.polygon([(tx-28,420),(tx,380),(tx+28,420)], fill=(65,58,48,220))
    # 渔网
    for i in range(8):
        x = 400 + i * 30
        for j in range(6):
            y = 560 + j * 15
            d.line([(x,y),(x+15,y+10)], fill=(140,120,90,120), width=1)
    draw_gate(d, 480, 600, 64, 50, (40,35,30))
    draw_text_centered(d, 512, 920, "即墨", FONT_CN, 120, (*BAM_H, 230))
    save(img, "city_jimo")


# ══════════════════════════════════════════════════════════
#  7. 郢 — 楚都，章华台+凤鸟
# ══════════════════════════════════════════════════════════
def city_ying():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (55,40,50), (90,70,75))
    draw_ground(d, 680, (60,52,45), (48,40,35))
    # 章华台
    for i in range(5):
        w = 350 - i * 40
        h = 50
        x = 512 - w//2
        y = 520 - i * 60
        pb(d, x, y, w, h, (85,50,55,220))
        pb(d, x+5, y+5, w-10, h-10, (100,60,65,200))
    # 顶部宫殿
    pb(d, 400, 280, 224, 80, (90,55,60,220))
    pb(d, 408, 286, 208, 68, (105,65,70,200))
    # 飞檐
    d.arc([370,240,512,300], 180, 360, fill=(70,42,48,220), width=8)
    d.arc([512,240,654,300], 180, 360, fill=(70,42,48,220), width=8)
    d.polygon([(380,280),(512,220),(644,280)], fill=(75,45,50,220))
    # 凤鸟装饰
    cx, cy = 512, 240
    d.polygon([(cx-20,cy),(cx,cy-30),(cx+20,cy)], fill=(200,140,60,220))
    d.line([(cx,cy-30),(cx,cy-50)], fill=(200,140,60,200), width=4)
    # 漆器纹饰
    for i in range(8):
        dx = 430 + i * 24
        d.arc([dx,300,dx+16,316], 0, 180, fill=(160,50,40,180), width=2)
    # 云梦泽
    for y in range(600, 680):
        for x in range(100, 400):
            wave = math.sin(x*0.04 + y*0.03) * 6
            if y + wave > 610:
                d.point((x, y), fill=(50,80,110, 140))
    # 棕榈/竹林
    for tx in [120, 850]:
        pb(d, tx, 450, 6, 100, (70,90,55,180))
        for leaf in range(6):
            angle = math.radians(30 + leaf * 50)
            for s in range(30):
                lx = int(tx + s * math.cos(angle))
                ly = int(460 + s * math.sin(angle))
                if 0 <= lx < SZ and 0 <= ly < SZ:
                    d.point((lx, ly), fill=(60,100,50,160))
    draw_wall(d, 80, 700, 864, 40, (75,55,50), (90,65,60))
    draw_gate(d, 470, 700, 84, 40, (40,30,28))
    draw_text_centered(d, 512, 920, "郢", FONT_CN, 140, (*BAM_H, 230))
    save(img, "city_ying")


# ══════════════════════════════════════════════════════════
#  8. 寿春 — 楚晚期都城，水乡
# ══════════════════════════════════════════════════════════
def city_shouchun():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (50,55,65), (80,85,90))
    draw_ground(d, 650, (58,52,45), (45,40,35))
    # 河流
    for y in range(600, 750):
        for x in range(SZ):
            wave = math.sin(x*0.015 + y*0.02) * 20
            if 600 < y + wave < 750:
                t = (y - 600) / 150
                r = int(40 + t * 20)
                g = int(65 + t * 20)
                b = int(100 + t * 25)
                d.point((x, y), fill=(r, g, b, 170))
    # 桥
    pb(d, 350, 640, 324, 12, (*BRO, 200))
    for bx in range(350, 674, 40):
        pb(d, bx, 640, 8, 60, (*BRO, 200))
    # 宫殿
    pb(d, 350, 420, 324, 120, (82,60,55,220))
    pb(d, 358, 426, 308, 108, (95,70,64,200))
    d.polygon([(330,420),(512,360),(694,420)], fill=(68,48,42,220))
    # 城墙
    draw_wall(d, 150, 540, 724, 110, (72,58,50), (85,68,60))
    for x in range(150, 874, 36):
        pb(d, x, 524, 24, 20, (72,58,50,220))
    # 水门
    d.arc([470,600,554,660], 180, 360, fill=(40,30,28,200), width=6)
    # 渔民
    for bx in [200, 750]:
        d.polygon([(bx-20,700),(bx,690),(bx+20,700)], fill=(100,85,70,180))
    draw_text_centered(d, 512, 920, "寿春", FONT_CN, 120, (*BAM_H, 230))
    save(img, "city_shouchun")


# ══════════════════════════════════════════════════════════
#  9. 大梁 — 魏都，中原正统，运河
# ══════════════════════════════════════════════════════════
def city_daliang():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (48,52,62), (82,85,92))
    draw_ground(d, 680, (62,58,48), (50,45,38))
    # 运河
    for y in range(620, 680):
        for x in range(SZ):
            wave = math.sin(x*0.03 + y*0.02) * 5
            d.point((x, y+wave), fill=(45,70,100, 160))
    # 城墙
    pb(d, 120, 400, 784, 280, (78,70,62,220))
    pb(d, 130, 408, 764, 264, (92,82,72,200))
    for x in range(120, 904, 36):
        pb(d, x, 384, 24, 20, (78,70,62,220))
    # 宫殿群
    for row in range(2):
        for col in range(3):
            bx = 250 + col * 180
            by = 420 + row * 100
            pb(d, bx, by, 140, 70, (85,76,66,200))
            d.polygon([(bx-8,by),(bx+70,by-25),(bx+148,by)], fill=(70,62,52,200))
    # 中轴大殿
    pb(d, 400, 340, 224, 80, (88,78,68,220))
    d.polygon([(380,340),(512,280),(644,340)], fill=(72,64,54,220))
    # 旗杆
    pb(d, 510, 250, 6, 100, (*BRO_H, 200))
    for i in range(20):
        wave = int(3 * math.sin(i * 0.4))
        pb(d, 516, 258+i, 28+wave, 2, (*BAM_H, max(120,200-i*4)))
    # 运河码头
    pb(d, 400, 620, 224, 60, (80,72,62,200))
    for bx in [420, 500, 580]:
        pb(d, bx, 610, 8, 20, (*BRO, 200))
    draw_gate(d, 470, 640, 84, 40, (40,35,30))
    draw_text_centered(d, 512, 920, "大梁", FONT_CN, 120, (*BAM_H, 230))
    save(img, "city_daliang")


# ══════════════════════════════════════════════════════════
#  10. 安邑 — 魏旧都，铁矿+冶铁
# ══════════════════════════════════════════════════════════
def city_anyi():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (50,48,45), (85,80,75))
    draw_ground(d, 680, (60,55,48), (48,42,36))
    draw_mountain_bg(d, 480, [(200,340,250),(800,360,280)], (50,48,42))
    draw_wall(d, 150, 480, 724, 200, (72,65,58), (85,76,66))
    # 冶铁炉
    for i in range(3):
        fx = 250 + i * 200
        d.polygon([(fx-30,600),(fx-20,500),(fx+20,500),(fx+30,600)],
                  fill=(80,70,62,220))
        d.polygon([(fx-24,596),(fx-16,504),(fx+16,504),(fx+24,596)],
                  fill=(95,82,72,200))
        for j in range(10):
            sx = fx + random.randint(-8, 8)
            sy = 490 - j * 15
            size = random.randint(6, 14)
            d.ellipse([sx,sy,sx+size,sy+size], fill=(70,65,60, max(40,120-j*10)))
        for j in range(8):
            d.point((fx+random.randint(-6,6), 505+j), fill=(220,140,50, 200))
    # 铁锭堆
    for i in range(6):
        ix = 700 + i * 30
        pb(d, ix, 620, 20, 12, (*IRON, 200))
        pb(d, ix+2, 622, 16, 8, (180,185,195,180))
    # 宫殿
    pb(d, 350, 380, 324, 120, (82,72,62,220))
    d.polygon([(330,380),(512,320),(694,380)], fill=(68,60,50,220))
    draw_gate(d, 470, 640, 84, 40, (40,35,30))
    draw_text_centered(d, 512, 920, "安邑", FONT_CN, 120, (*BAM_H, 230))
    save(img, "city_anyi")


# ══════════════════════════════════════════════════════════
#  11. 蓟 — 燕都，北方边塞+易水
# ══════════════════════════════════════════════════════════
def city_ji():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (35,42,55), (65,70,80))
    draw_ground(d, 680, (52,48,42), (40,38,32))
    draw_mountain_bg(d, 440, [(150,280,200),(512,250,350),(870,300,220)], (42,48,42))
    # 易水
    for y in range(640, 680):
        for x in range(SZ):
            wave = math.sin(x*0.025 + y*0.03) * 6
            d.point((x, y+wave), fill=(40,65,95, 150))
    # 宫殿
    pb(d, 300, 400, 424, 160, (75,65,55,220))
    pb(d, 310, 408, 404, 144, (88,78,66,200))
    d.polygon([(270,400),(512,320),(754,400)], fill=(60,52,42,220))
    d.polygon([(290,396),(512,330),(734,396)], fill=(72,62,52,200))
    # 练兵台
    pb(d, 100, 520, 200, 80, (70,62,52,200))
    pb(d, 108, 526, 184, 68, (82,72,62,180))
    # 兵马
    for i in range(4):
        mx = 120 + i * 45
        d.polygon([(mx,580),(mx+15,565),(mx+30,575),(mx+28,598),(mx+2,598)],
                  fill=(55,48,38,200))
    # 长城远景
    for x in range(700, 1024, 20):
        h = random.randint(30, 60)
        pb(d, x, 440-h, 16, h, (65,60,52,160))
        pb(d, x, 440-h-8, 16, 10, (65,60,52,160))
    # 松树
    for tx in [850, 950]:
        pb(d, tx, 400, 8, 80, (60,50,40,200))
        for layer in range(3):
            ly = 410 + layer * 20
            w = 40 - layer * 10
            d.polygon([(tx-w,ly),(tx+4,ly-20),(tx+w+8,ly)], fill=(40,65,40,180))
    draw_wall(d, 80, 700, 864, 40, (68,60,50), (82,72,62))
    draw_gate(d, 470, 700, 84, 40, (40,35,30))
    draw_text_centered(d, 512, 920, "蓟", FONT_CN, 140, (*BAM_H, 230))
    save(img, "city_ji")


# ══════════════════════════════════════════════════════════
#  12. 辽阳 — 燕北境，马场+雪原
# ══════════════════════════════════════════════════════════
def city_liaoyang():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (30,38,52), (55,60,72))
    draw_ground(d, 680, (200,200,210), (170,175,185))
    # 雪原
    random.seed(12001)
    for _ in range(200):
        sx = random.randint(0, SZ)
        sy = random.randint(680, SZ)
        size = random.randint(2, 6)
        d.ellipse([sx,sy,sx+size,sy+size], fill=(220,225,235, 120))
    # 木栅栏围场
    for x in range(150, 874, 30):
        pb(d, x, 520, 6, 60, (100,85,65,200))
        d.line([(x,530),(x+30,530)], fill=(100,85,65,180), width=3)
        d.line([(x,560),(x+30,560)], fill=(100,85,65,180), width=3)
    # 马匹
    for mx in [250, 400, 550, 700]:
        d.polygon([(mx,600),(mx+25,580),(mx+50,590),(mx+45,630),(mx+5,630)],
                  fill=(120,100,75,200))
        d.ellipse([mx+20,572,mx+38,588], fill=(110,92,68,200))
        for lx in [mx+8, mx+38]:
            pb(d, lx, 628, 4, 20, (100,85,65,200))
    # 木屋
    pb(d, 350, 440, 200, 100, (110,90,70,220))
    pb(d, 358, 446, 184, 88, (120,100,78,200))
    d.polygon([(340,440),(450,390),(560,440)], fill=(90,75,58,220))
    # 烟囱冒烟
    for j in range(8):
        sx = 420 + random.randint(-5, 5)
        sy = 385 - j * 18
        size = random.randint(8, 18)
        d.ellipse([sx,sy,sx+size,sy+size], fill=(180,180,190, max(30,100-j*10)))
    # 雪花
    for _ in range(80):
        sx = random.randint(50, 974)
        sy = random.randint(50, 600)
        for arm in range(6):
            angle = math.radians(arm * 60)
            for s in range(10):
                px = int(sx + s * math.cos(angle))
                py = int(sy + s * math.sin(angle))
                if 0 <= px < SZ and 0 <= py < SZ:
                    d.point((px, py), fill=(210,220,240, 90))
    draw_text_centered(d, 512, 920, "辽阳", FONT_CN, 120, (*BAM_H, 230))
    save(img, "city_liaoyang")


# ══════════════════════════════════════════════════════════
#  13. 新郑 — 韩都，紧凑防御+弩机
# ══════════════════════════════════════════════════════════
def city_xinzheng():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (45,50,60), (80,82,88))
    draw_ground(d, 680, (60,56,48), (48,44,38))
    # 外城
    draw_wall(d, 100, 480, 824, 220, (72,65,58), (85,76,66))
    for x in range(100, 924, 32):
        pb(d, x, 464, 22, 20, (72,65,58,220))
    # 宫城
    pb(d, 300, 360, 424, 140, (78,70,62,220))
    pb(d, 308, 366, 408, 128, (90,80,70,200))
    for x in range(300, 724, 28):
        pb(d, x, 344, 20, 20, (78,70,62,220))
    # 宫殿
    pb(d, 380, 280, 264, 80, (82,74,64,220))
    d.polygon([(360,280),(512,220),(664,280)], fill=(66,58,48,220))
    # 弩机工坊
    pb(d, 140, 520, 120, 80, (78,70,62,200))
    pb(d, 148, 526, 104, 68, (88,78,68,180))
    for nx in [160, 200, 240]:
        d.line([(nx,540),(nx-20,560)], fill=(*BAM_S, 180), width=4)
        d.line([(nx,540),(nx+20,560)], fill=(*BAM_S, 180), width=4)
        pb(d, nx-2, 540, 4, 30, (*BRO, 200))
    # 弩箭堆
    for i in range(8):
        ax = 780 + i * 20
        pb(d, ax, 560, 3, 40, (*BAM_S, 180))
        d.point((ax+1, 558), fill=(*IRON, 200))
    draw_gate(d, 470, 660, 84, 40, (40,35,30))
    draw_text_centered(d, 512, 920, "新郑", FONT_CN, 120, (*BAM_H, 230))
    save(img, "city_xinzheng")


# ══════════════════════════════════════════════════════════
#  14. 上党 — 韩山地要塞
# ══════════════════════════════════════════════════════════
def city_shangdang():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    draw_sky(d, (40,45,55), (70,72,78))
    draw_ground(d, 600, (55,50,44), (42,38,32))
    # 山地
    for x in range(SZ):
        h1 = int(400 + 80 * math.sin(x * 0.008) + 50 * math.sin(x * 0.02))
        h2 = int(450 + 60 * math.sin(x * 0.012 + 2) + 40 * math.sin(x * 0.03))
        for y in range(min(h1,h2), 600):
            t = (y - 350) / 250
            r = int(50 + t * 20)
            g = int(48 + t * 18)
            b = int(40 + t * 15)
            d.point((x, y), fill=(r, g, b, 160))
    # 山顶要塞
    pb(d, 380, 350, 264, 120, (75,65,55,220))
    pb(d, 388, 356, 248, 108, (88,78,66,200))
    # 碉楼
    for tx in [380, 644]:
        pb(d, tx-16, 300, 32, 70, (78,68,58,220))
        pb(d, tx-12, 304, 24, 62, (90,80,68,200))
        d.polygon([(tx-22,300),(tx,270),(tx+22,300)], fill=(65,58,48,220))
    # 城墙沿山脊
    for i in range(8):
        x = 200 + i * 80
        y = 420 - int(30 * math.sin(i * 0.5))
        pb(d, x, y, 60, 20, (72,64,56,200))
        pb(d, x, y-12, 15, 14, (72,64,56,200))
        pb(d, x+45, y-12, 15, 14, (72,64,56,200))
    # 铁矿标志
    pb(d, 100, 500, 50, 40, (80,70,60,200))
    d.polygon([(95,500),(125,475),(155,500)], fill=(100,85,70,200))
    for i in range(6):
        d.point((120+i%3, 485-i*2), fill=(200,120,40,180))
    # 云雾
    random.seed(14001)
    for _ in range(30):
        cx = random.randint(100, 924)
        cy = random.randint(300, 450)
        size = random.randint(30, 80)
        d.ellipse([cx,cy,cx+size,cy+size//3], fill=(180,180,190, 50))
    draw_text_centered(d, 512, 920, "上党", FONT_CN, 120, (*BAM_H, 230))
    save(img, "city_shangdang")


def generate_all():
    print("=== 《山河策》城市插画生成器 (1024x1024) ===\n")
    cities = [
        city_xianyang, city_yongcheng, city_handan, city_daijun,
        city_linzi, city_jimo, city_ying, city_shouchun,
        city_daliang, city_anyi, city_ji, city_liaoyang,
        city_xinzheng, city_shangdang,
    ]
    for func in cities:
        func()
    print(f"\n=== 完成！共 {len(cities)} 座城市 ===")
    print(f"输出: {OUT_DIR}")
    print("规格: 1024x1024 | 系统隶书 | 透明背景")
    print("\n请在本地查看 city/ 目录即可。")

if __name__ == "__main__":
    generate_all()
