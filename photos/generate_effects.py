"""
《山河策》战斗特效生成器 V2
1024x1024 | 纯特效无文字 | 像素风 | 透明背景
运行: python generate_effects.py
"""

import os, math, random
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "effect1")
os.makedirs(OUT_DIR, exist_ok=True)

SZ = 1024

# ── 色板 ──
INK = (26, 26, 27)
BAM = (197, 163, 104)
LAC = (140, 69, 34)
BRO = (43, 51, 48)
IRON = (160, 165, 175)
GOLD = (220, 190, 80)
FIRE_R = (200, 60, 30)
FIRE_Y = (240, 180, 50)
ICE = (140, 190, 220)
POISON = (80, 160, 50)
BLOOD = (150, 30, 25)

def pb(d, x, y, w, h, c):
    d.rectangle([x, y, x+w-1, y+h-1], fill=c)

def save(img, name):
    path = os.path.join(OUT_DIR, f"{name}.png")
    img.save(path)
    print(f"  [OK] {name}.png")


# ══════════════════════════════════════════════════════════
#  1. 剑气斩击 — 弧形刀光 + 火花飞溅
# ══════════════════════════════════════════════════════════
def fx_slash():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    # 弧形斩击光带
    for i in range(240):
        angle = math.radians(-30 + i * 1)
        r = 280 + 40 * math.sin(i * 0.3)
        x = int(cx + r * math.cos(angle))
        y = int(cy + r * math.sin(angle))
        width = max(2, 24 - abs(i - 120) // 4)
        alpha = max(60, 220 - abs(i - 120) * 2)
        for w in range(-width, width+1):
            px = x + int(w * math.sin(angle))
            py = y - int(w * math.cos(angle))
            if 0 <= px < SZ and 0 <= py < SZ:
                c = (220, 230, 255) if abs(w) <= 4 else (180, 200, 240)
                d.point((px, py), fill=(*c, alpha))
    # 内弧亮芯
    for i in range(220):
        angle = math.radians(-25 + i * 1)
        r = 272
        x = int(cx + r * math.cos(angle))
        y = int(cy + r * math.sin(angle))
        if 0 <= x < SZ and 0 <= y < SZ:
            d.point((x, y), fill=(255, 255, 255, 230))
    # 火花飞溅
    random.seed(101)
    for _ in range(160):
        angle = math.radians(random.uniform(-40, 220))
        dist = random.randint(240, 440)
        sx = int(cx + dist * math.cos(angle))
        sy = int(cy + dist * math.sin(angle))
        size = random.randint(4, 12)
        c = random.choice([(255,220,120), (255,180,80), (240,140,60)])
        alpha = random.randint(150, 240)
        d.ellipse([sx, sy, sx+size, sy+size], fill=(*c, alpha))
    # 冲击波纹
    for r in [160, 220]:
        for i in range(144):
            angle = math.radians(i * 2.5)
            x = int(cx + r * math.cos(angle))
            y = int(cy + r * math.sin(angle))
            d.point((x, y), fill=(200, 210, 240, 80))
    save(img, "fx_slash")


# ══════════════════════════════════════════════════════════
#  2. 箭雨 — 密集箭矢从天而降
# ══════════════════════════════════════════════════════════
def fx_arrow_rain():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    random.seed(201)
    for _ in range(240):
        ax = random.randint(80, SZ-80)
        ay = random.randint(40, 720)
        length = random.randint(60, 120)
        angle = math.radians(random.uniform(60, 120))
        # 箭杆
        for s in range(length):
            px = int(ax + s * math.cos(angle))
            py = int(ay + s * math.sin(angle))
            if 0 <= px < SZ and 0 <= py < SZ:
                c = (120, 95, 60) if s < length - 16 else (80, 80, 85)
                alpha = max(100, 200 - s * 2)
                d.point((px, py), fill=(*c, alpha))
                d.point((px+1, py), fill=(*c, alpha // 2))
        # 箭头
        tip_x = int(ax + length * math.cos(angle))
        tip_y = int(ay + length * math.sin(angle))
        if 0 <= tip_x < SZ and 0 <= tip_y < SZ:
            d.point((tip_x, tip_y), fill=(180, 180, 185, 230))
            d.point((tip_x+1, tip_y), fill=(180, 180, 185, 180))
        # 箭羽
        tail_x = int(ax + 8 * math.cos(angle))
        tail_y = int(ay + 8 * math.sin(angle))
        for f in range(-8, 9):
            fx_ = tail_x + int(f * math.sin(angle))
            fy_ = tail_y - int(f * math.cos(angle))
            if 0 <= fx_ < SZ and 0 <= fy_ < SZ:
                d.point((fx_, fy_), fill=(180, 50, 40, 160))
    # 地面插箭
    for _ in range(60):
        gx = random.randint(120, SZ-120)
        gy = random.randint(800, 960)
        for s in range(80):
            if 0 <= gx < SZ and 0 <= gy - s < SZ:
                d.point((gx, gy - s), fill=(100, 85, 55, 180))
        d.point((gx, gy - 80), fill=(160, 160, 165, 200))
    save(img, "fx_arrow_rain")


# ══════════════════════════════════════════════════════════
#  3. 爆炸 — 火球 + 冲击波 + 碎片
# ══════════════════════════════════════════════════════════
def fx_explosion():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    # 外层烟雾
    random.seed(301)
    for _ in range(320):
        angle = random.uniform(0, math.pi*2)
        dist = random.randint(160, 360)
        sx = int(cx + dist * math.cos(angle))
        sy = int(cy + dist * math.sin(angle))
        size = random.randint(24, 64)
        c = random.choice([(80,60,50), (60,50,45), (90,70,55)])
        alpha = random.randint(80, 160)
        d.ellipse([sx, sy, sx+size, sy+size], fill=(*c, alpha))
    # 中层火焰
    for _ in range(240):
        angle = random.uniform(0, math.pi*2)
        dist = random.randint(80, 240)
        sx = int(cx + dist * math.cos(angle))
        sy = int(cy + dist * math.sin(angle))
        size = random.randint(16, 40)
        c = random.choice([(200,80,30), (220,120,40), (180,60,20), (240,160,50)])
        alpha = random.randint(150, 230)
        d.ellipse([sx, sy, sx+size, sy+size], fill=(*c, alpha))
    # 内核白热
    for _ in range(120):
        angle = random.uniform(0, math.pi*2)
        dist = random.randint(0, 100)
        sx = int(cx + dist * math.cos(angle))
        sy = int(cy + dist * math.sin(angle))
        size = random.randint(8, 24)
        c = random.choice([(255,240,180), (255,255,220), (255,220,150)])
        alpha = random.randint(180, 250)
        d.ellipse([sx, sy, sx+size, sy+size], fill=(*c, alpha))
    # 冲击波环
    for r in [200, 280, 360]:
        alpha = max(40, 150 - r//3)
        for i in range(288):
            angle = math.radians(i * 1.25)
            x = int(cx + r * math.cos(angle))
            y = int(cy + r * math.sin(angle))
            if 0 <= x < SZ and 0 <= y < SZ:
                d.point((x, y), fill=(240, 200, 120, alpha))
    # 飞散碎片
    for _ in range(100):
        angle = random.uniform(0, math.pi*2)
        dist = random.randint(200, 440)
        sx = int(cx + dist * math.cos(angle))
        sy = int(cy + dist * math.sin(angle))
        size = random.randint(8, 20)
        c = random.choice([(180,160,140), (120,100,80), (200,180,160)])
        alpha = random.randint(150, 220)
        pb(d, sx, sy, size, size, (*c, alpha))
    save(img, "fx_explosion")


# ══════════════════════════════════════════════════════════
#  4. 治疗光环 — 绿色光点上升 + 光环扩散
# ══════════════════════════════════════════════════════════
def fx_heal():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 640
    # 外层光晕
    for r in range(240, 0, -1):
        alpha = max(10, 60 - r//4)
        for i in range(144):
            angle = math.radians(i * 2.5)
            x = int(cx + r * math.cos(angle))
            y = int(cy + r * math.sin(angle) * 0.6)
            if 0 <= x < SZ and 0 <= y < SZ:
                d.point((x, y), fill=(100, 200, 80, alpha))
    # 光圈
    for r in [120, 180]:
        for i in range(240):
            angle = math.radians(i * 1.5)
            x = int(cx + r * math.cos(angle))
            y = int(cy + r * math.sin(angle) * 0.5)
            if 0 <= x < SZ and 0 <= y < SZ:
                alpha = 140 if r == 120 else 100
                d.point((x, y), fill=(120, 220, 90, alpha))
    # 上升光点
    random.seed(401)
    for _ in range(200):
        px = random.randint(cx-200, cx+200)
        py = random.randint(cy-240, cy+80)
        size = random.randint(4, 12)
        c = random.choice([(130,230,100), (100,200,80), (160,240,130)])
        alpha = random.randint(120, 220)
        d.ellipse([px, py, px+size, py+size], fill=(*c, alpha))
    # 中心十字光芒
    for s in range(160):
        alpha = max(40, 180 - s * 1)
        for dx, dy in [(1,0),(-1,0),(0,1),(0,-1)]:
            x = cx + s * dx
            y = cy + s * dy // 2
            if 0 <= x < SZ and 0 <= y < SZ:
                d.point((x, y), fill=(180, 255, 150, alpha))
    # 叶片符号
    for i in range(3):
        angle = math.radians(90 + i * 120)
        lx = int(cx + 72 * math.cos(angle))
        ly = int(cy + 40 * math.sin(angle))
        d.ellipse([lx-12, ly-8, lx+12, ly+8], fill=(80, 180, 60, 200))
    save(img, "fx_heal")


# ══════════════════════════════════════════════════════════
#  5. 格挡盾击 — 盾牌冲击 + 火花四溅
# ══════════════════════════════════════════════════════════
def fx_shield_block():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    # 盾牌主体
    d.polygon([
        (cx-140, cy-160), (cx+140, cy-160),
        (cx+160, cy+40), (cx+120, cy+180),
        (cx, cy+220), (cx-120, cy+180),
        (cx-160, cy+40)
    ], fill=(*BRO, 220))
    # 盾牌内纹
    d.polygon([
        (cx-112, cy-132), (cx+112, cy-132),
        (cx+128, cy+20), (cx+96, cy+152),
        (cx, cy+184), (cx-96, cy+152),
        (cx-128, cy+20)
    ], fill=(60, 70, 65, 200))
    # 盾牌中心圆
    d.ellipse([cx-48, cy-48, cx+48, cy+48], fill=(*BAM, 220))
    d.ellipse([cx-32, cy-32, cx+32, cy+32], fill=(*IRON, 200))
    # 冲击火花（从盾面中心向外）
    random.seed(501)
    for _ in range(200):
        angle = random.uniform(0, math.pi*2)
        dist = random.randint(160, 360)
        sx = int(cx + dist * math.cos(angle))
        sy = int(cy + dist * math.sin(angle))
        size = random.randint(4, 16)
        c = random.choice([(255,230,120), (255,200,80), (255,160,60)])
        alpha = random.randint(150, 240)
        d.ellipse([sx, sy, sx+size, sy+size], fill=(*c, alpha))
    # 冲击波纹
    for r in [200, 260, 320]:
        alpha = max(40, 140 - (r - 200) // 5)
        for i in range(192):
            angle = math.radians(i * 1.875)
            x = int(cx + r * math.cos(angle))
            y = int(cy + r * math.sin(angle))
            if 0 <= x < SZ and 0 <= y < SZ:
                d.point((x, y), fill=(200, 210, 220, alpha))
    # 裂纹
    for i in range(5):
        angle = math.radians(random.uniform(0, 360))
        for s in range(60, 140):
            px = int(cx + s * math.cos(angle + s*0.013))
            py = int(cy + s * math.sin(angle + s*0.013))
            if 0 <= px < SZ and 0 <= py < SZ:
                d.point((px, py), fill=(180, 185, 190, max(60, 180-s*2)))
    save(img, "fx_shield_block")


# ══════════════════════════════════════════════════════════
#  6. 骑兵冲锋 — 马蹄扬尘 + 速度线
# ══════════════════════════════════════════════════════════
def fx_charge():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 地面扬尘
    random.seed(601)
    for _ in range(400):
        px = random.randint(80, SZ-80)
        py = random.randint(640, 960)
        size = random.randint(16, 48)
        c = random.choice([(160,140,110), (140,120,90), (180,160,130)])
        alpha = random.randint(80, 160)
        d.ellipse([px, py, px+size, py+size], fill=(*c, alpha))
    # 速度线（向左）
    for _ in range(160):
        sx = random.randint(320, 800)
        sy = random.randint(240, 720)
        length = random.randint(80, 200)
        alpha = random.randint(100, 200)
        c = random.choice([(200,190,170), (180,170,150)])
        for s in range(length):
            x = sx - s
            if 0 <= x < SZ:
                d.point((x, sy), fill=(*c, max(40, alpha - s*2)))
    # 马蹄印
    for _ in range(8):
        hx = random.randint(160, 800)
        hy = random.randint(720, 920)
        d.ellipse([hx, hy, hx+32, hy+20], fill=(120, 100, 75, 150))
    # 尘土飞溅
    for _ in range(120):
        angle = math.radians(random.uniform(200, 340))
        dist = random.randint(80, 240)
        sx = int(400 + dist * math.cos(angle))
        sy = int(800 + dist * math.sin(angle) * 0.5)
        size = random.randint(8, 20)
        alpha = random.randint(100, 180)
        d.ellipse([sx, sy, sx+size, sy+size], fill=(170, 150, 120, alpha))
    # 振动波纹
    for i in range(5):
        x = 240 + i * 140
        for dy in [-12, 0, 12]:
            d.line([(x, 780+dy), (x+60, 780+dy)], fill=(140,120,90,80), width=3)
    save(img, "fx_charge")


# ══════════════════════════════════════════════════════════
#  7. 暴击 — 集中一点的猛烈冲击
# ══════════════════════════════════════════════════════════
def fx_critical():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    # 放射状冲击线
    for i in range(96):
        angle = math.radians(i * 3.75)
        length = random.randint(240, 400)
        for s in range(length):
            x = int(cx + s * math.cos(angle))
            y = int(cy + s * math.sin(angle))
            if 0 <= x < SZ and 0 <= y < SZ:
                alpha = max(40, 220 - s * 1)
                c = (255, 240, 180) if s < 80 else (255, 200, 100)
                d.point((x, y), fill=(*c, alpha))
                if s < 120:
                    d.point((x+1, y), fill=(*c, alpha//2))
                    d.point((x, y+1), fill=(*c, alpha//2))
    # 中心爆点
    for r in range(60, 0, -1):
        alpha = min(255, 100 + r * 3)
        c = (255, 255, 220) if r > 32 else (255, 220, 120)
        d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(*c, alpha))
    # 四散碎片
    random.seed(701)
    for _ in range(120):
        angle = random.uniform(0, math.pi*2)
        dist = random.randint(120, 320)
        sx = int(cx + dist * math.cos(angle))
        sy = int(cy + dist * math.sin(angle))
        size = random.randint(8, 20)
        c = random.choice([(255,200,80), (255,160,60), (240,120,40)])
        alpha = random.randint(150, 230)
        pb(d, sx, sy, size, size, (*c, alpha))
    # 冲击波环
    for r in [100, 180, 260]:
        alpha = max(30, 120 - (r-100)//4)
        for i in range(240):
            angle = math.radians(i * 1.5)
            x = int(cx + r * math.cos(angle))
            y = int(cy + r * math.sin(angle))
            if 0 <= x < SZ and 0 <= y < SZ:
                d.point((x, y), fill=(255, 230, 150, alpha))
    save(img, "fx_critical")


# ══════════════════════════════════════════════════════════
#  8. 火焰术 — 螺旋火焰 + 灼烧
# ══════════════════════════════════════════════════════════
def fx_fire():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 720
    # 螺旋火焰
    for i in range(480):
        angle = math.radians(i * 2)
        r = 40 + i * 0.5
        x = int(cx + r * math.cos(angle))
        y = int(cy - i * 1.2 + r * math.sin(angle) * 0.3)
        if 0 <= x < SZ and 0 <= y < SZ:
            t = i / 480
            red = int(200 + 55 * (1-t))
            green = int(60 + 120 * (1-t))
            blue = int(20 + 30 * (1-t))
            alpha = max(80, int(220 - t * 140))
            size = max(2, int(20 - t * 12))
            d.ellipse([x, y, x+size, y+size], fill=(red, green, blue, alpha))
    # 核心白焰
    for i in range(160):
        angle = math.radians(i * 3)
        r = 20 + i * 0.3
        x = int(cx + r * math.cos(angle))
        y = int(cy - i * 0.8)
        if 0 <= x < SZ and 0 <= y < SZ:
            alpha = max(100, 240 - i * 2)
            d.ellipse([x, y, x+8, y+8], fill=(255, 250, 200, alpha))
    # 火星飞溅
    random.seed(801)
    for _ in range(200):
        angle = math.radians(random.uniform(200, 340))
        dist = random.randint(80, 320)
        sx = int(cx + dist * math.cos(angle))
        sy = int(cy - 240 + dist * math.sin(angle) * 0.5)
        size = random.randint(4, 12)
        c = random.choice([(255,200,60), (255,160,40), (240,120,30)])
        alpha = random.randint(150, 230)
        d.ellipse([sx, sy, sx+size, sy+size], fill=(*c, alpha))
    # 底部灼烧痕迹
    for _ in range(120):
        bx = random.randint(320, 704)
        by = random.randint(800, 960)
        size = random.randint(12, 32)
        c = random.choice([(60,30,15), (80,40,20), (50,25,10)])
        alpha = random.randint(100, 180)
        d.ellipse([bx, by, bx+size, by+size], fill=(*c, alpha))
    save(img, "fx_fire")


# ══════════════════════════════════════════════════════════
#  9. 毒雾 — 绿色毒气弥漫
# ══════════════════════════════════════════════════════════
def fx_poison():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 560
    # 毒雾云团
    random.seed(901)
    for _ in range(320):
        angle = random.uniform(0, math.pi*2)
        dist = random.randint(40, 280)
        sx = int(cx + dist * math.cos(angle))
        sy = int(cy + dist * math.sin(angle) * 0.6)
        size = random.randint(32, 80)
        c = random.choice([(80,160,50), (60,140,40), (100,180,60), (70,130,45)])
        alpha = random.randint(60, 140)
        d.ellipse([sx, sy, sx+size, sy+size], fill=(*c, alpha))
    # 内层浓毒
    for _ in range(160):
        angle = random.uniform(0, math.pi*2)
        dist = random.randint(0, 140)
        sx = int(cx + dist * math.cos(angle))
        sy = int(cy + dist * math.sin(angle) * 0.5)
        size = random.randint(20, 48)
        c = random.choice([(100,190,60), (120,200,70), (90,170,55)])
        alpha = random.randint(100, 180)
        d.ellipse([sx, sy, sx+size, sy+size], fill=(*c, alpha))
    # 毒液滴落
    for _ in range(80):
        dx = random.randint(cx-200, cx+200)
        dy = random.randint(cy+80, cy+240)
        size = random.randint(8, 20)
        d.ellipse([dx, dy, dx+size, dy+size], fill=(90, 170, 50, 180))
        # 滴痕
        for s in range(random.randint(20, 60)):
            if 0 <= dy+s < SZ:
                d.point((dx+size//2, dy+s), fill=(80, 150, 45, max(60, 160-s*3)))
    # 骷髅符号（简化）
    d.ellipse([cx-32, cy-60, cx+32, cy+8], fill=(140, 200, 90, 200))
    d.point((cx-12, cy-32), fill=(40, 80, 20, 220))
    d.point((cx+12, cy-32), fill=(40, 80, 20, 220))
    d.point((cx, cy-16), fill=(40, 80, 20, 200))
    save(img, "fx_poison")


# ══════════════════════════════════════════════════════════
#  10. 冰冻 — 冰晶凝结 + 寒气
# ══════════════════════════════════════════════════════════
def fx_freeze():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    # 冰晶放射
    for i in range(6):
        angle = math.radians(i * 60)
        for s in range(240):
            x = int(cx + s * math.cos(angle))
            y = int(cy + s * math.sin(angle))
            if 0 <= x < SZ and 0 <= y < SZ:
                alpha = max(60, 200 - s * 1)
                c = (180, 210, 235) if s % 3 == 0 else (150, 190, 220)
                d.point((x, y), fill=(*c, alpha))
                # 冰晶分支
                if s > 60 and s % 10 == 0:
                    for br in range(32):
                        ba = angle + math.radians(30 if br % 2 == 0 else -30)
                        bx = int(x + br * math.cos(ba))
                        by = int(y + br * math.sin(ba))
                        if 0 <= bx < SZ and 0 <= by < SZ:
                            d.point((bx, by), fill=(170, 200, 230, max(80, 180-br*5)))
    # 中心冰核
    d.ellipse([cx-72, cy-72, cx+72, cy+72], fill=(180, 210, 240, 200))
    d.ellipse([cx-48, cy-48, cx+48, cy+48], fill=(200, 225, 250, 220))
    d.ellipse([cx-24, cy-24, cx+24, cy+24], fill=(230, 245, 255, 240))
    # 寒气弥漫
    random.seed(1001)
    for _ in range(240):
        angle = random.uniform(0, math.pi*2)
        dist = random.randint(120, 360)
        sx = int(cx + dist * math.cos(angle))
        sy = int(cy + dist * math.sin(angle))
        size = random.randint(12, 32)
        c = random.choice([(160,200,230), (140,180,215), (170,210,240)])
        alpha = random.randint(60, 130)
        d.ellipse([sx, sy, sx+size, sy+size], fill=(*c, alpha))
    # 霜花
    for _ in range(30):
        fx = random.randint(160, SZ-160)
        fy = random.randint(160, SZ-160)
        for arm in range(6):
            angle = math.radians(arm * 60 + random.uniform(-10, 10))
            for s in range(random.randint(12, 32)):
                px = int(fx + s * math.cos(angle))
                py = int(fy + s * math.sin(angle))
                if 0 <= px < SZ and 0 <= py < SZ:
                    d.point((px, py), fill=(200, 220, 240, 140))
    save(img, "fx_freeze")


# ══════════════════════════════════════════════════════════
#  11. 攻城投石 — 巨石飞行 + 碎裂
# ══════════════════════════════════════════════════════════
def fx_siege():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 飞行巨石
    bx, by = 560, 320
    # 石头
    d.polygon([(bx-48,by),(bx,by-60),(bx+48,by-20),(bx+40,by+40),(bx-32,by+48)],
              fill=(120,110,100,220))
    d.polygon([(bx-32,by+8),(bx-8,by-40),(bx+32,by-12),(bx+24,by+28)],
              fill=(140,130,120,200))
    # 尾迹
    for i in range(120):
        tx = bx - 20 - i * 3
        ty = by + 32 + i * 2
        if 0 <= tx < SZ and 0 <= ty < SZ:
            alpha = max(40, 150 - i * 2)
            d.point((tx, ty), fill=(100,90,80, alpha))
    # 着地碎裂
    gx, gy = 320, 800
    # 撞击坑
    d.ellipse([gx-100, gy-20, gx+100, gy+32], fill=(60,55,50,180))
    d.ellipse([gx-72, gy-12, gx+72, gy+20], fill=(80,70,60,160))
    # 碎片飞散
    random.seed(1101)
    for _ in range(160):
        angle = math.radians(random.uniform(200, 340))
        dist = random.randint(60, 240)
        sx = int(gx + dist * math.cos(angle))
        sy = int(gy + dist * math.sin(angle) * 0.5)
        size = random.randint(8, 24)
        c = random.choice([(110,100,90), (130,120,110), (90,80,70)])
        alpha = random.randint(150, 220)
        pb(d, sx, sy, size, size, (*c, alpha))
    # 烟尘
    for _ in range(120):
        sx = random.randint(gx-160, gx+160)
        sy = random.randint(gy-120, gy+40)
        size = random.randint(20, 48)
        d.ellipse([sx, sy, sx+size, sy+size], fill=(80,75,70,80))
    # 弹道弧线
    for i in range(200):
        t = i / 200
        x = int(800 - t * 480)
        y = int(160 + t * 640 + (t - 0.5)**2 * 320)
        if 0 <= x < SZ and 0 <= y < SZ:
            d.point((x, y), fill=(140,130,120, max(30, 100-i*1)))
    save(img, "fx_siege")


# ══════════════════════════════════════════════════════════
#  12. 士气鼓舞 — 金色光柱 + 战旗飘扬
# ══════════════════════════════════════════════════════════
def fx_morale():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    # 光柱
    for y in range(160, 880):
        for x in range(cx-120, cx+120):
            dist = abs(x - cx)
            alpha = max(20, 100 - dist // 4)
            if 0 <= x < SZ:
                d.point((x, y), fill=(220, 190, 80, alpha))
    # 战旗
    fx = cx + 80
    # 旗杆
    pb(d, fx, 200, 12, 480, (*BRO, 200))
    # 旗面（飘动）
    for i in range(120):
        wave = int(20 * math.sin(i * 0.3))
        pb(d, fx+12, 220+i, 140+wave, 4, (*LAC, max(120, 200-i*2)))
        pb(d, fx+12, 224+i, 120+wave, 4, (170,90,40, max(100, 180-i*2)))
    # 金色光点上升
    random.seed(1201)
    for _ in range(160):
        px = random.randint(cx-240, cx+240)
        py = random.randint(240, 800)
        size = random.randint(4, 12)
        c = random.choice([(240,210,100), (220,190,80), (255,230,120)])
        alpha = random.randint(120, 220)
        d.ellipse([px, py, px+size, py+size], fill=(*c, alpha))
    # 光环扩散
    for r in [160, 240, 320]:
        alpha = max(30, 100 - (r-160)//5)
        for i in range(240):
            angle = math.radians(i * 1.5)
            x = int(cx + r * math.cos(angle))
            y = int(cy + r * math.sin(angle) * 0.6)
            if 0 <= x < SZ and 0 <= y < SZ:
                d.point((x, y), fill=(240, 210, 100, alpha))
    save(img, "fx_morale")


# ══════════════════════════════════════════════════════════
#  13. 陷阱触发 — 尖刺突起 + 束缚
# ══════════════════════════════════════════════════════════
def fx_trap():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 地面裂痕
    for i in range(8):
        sx = random.randint(240, 784)
        sy = random.randint(720, 880)
        for s in range(random.randint(40, 100)):
            px = sx + random.randint(-8, 8)
            py = sy + s
            if 0 <= px < SZ and 0 <= py < SZ:
                d.point((px, py), fill=(80,65,50,180))
    # 尖刺突起
    for i in range(12):
        sx = 240 + i * 56
        sy = 800
        height = random.randint(120, 240)
        # 刺身
        for h in range(height):
            width = max(2, 16 - h // 8)
            pb(d, sx-width//2, sy-h, width, 4, (100,95,90,200))
        # 刺尖
        d.point((sx, sy-height), fill=(160,155,150,230))
        d.point((sx, sy-height+4), fill=(140,135,130,200))
    # 绳索缠绕
    for i in range(6):
        angle = math.radians(random.uniform(0, 360))
        cx_ = 512 + random.randint(-120, 120)
        cy_ = 640 + random.randint(-80, 80)
        for s in range(80):
            r = 60 + s * 0.5
            x = int(cx_ + r * math.cos(angle + s*0.05))
            y = int(cy_ + r * math.sin(angle + s*0.05) * 0.5)
            if 0 <= x < SZ and 0 <= y < SZ:
                d.point((x, y), fill=(140,120,80, 160))
    # 尘土飞扬
    random.seed(1301)
    for _ in range(120):
        px = random.randint(320, 704)
        py = random.randint(680, 840)
        size = random.randint(8, 20)
        d.ellipse([px, py, px+size, py+size], fill=(120,105,85,100))
    save(img, "fx_trap")


# ══════════════════════════════════════════════════════════
#  14. 夜袭火把 — 暗夜火光摇曳
# ══════════════════════════════════════════════════════════
def fx_night_fire():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 深色背景薄雾
    for _ in range(160):
        px = random.randint(0, SZ)
        py = random.randint(0, SZ)
        size = random.randint(40, 120)
        d.ellipse([px, py, px+size, py+size], fill=(20,20,25,40))
    # 多支火把
    for torch_x in [320, 512, 704]:
        torch_y = 560
        # 火把杆
        pb(d, torch_x-8, torch_y, 16, 240, (80,60,45,200))
        # 火焰主体
        for i in range(100):
            fx_ = torch_x + random.randint(-32, 32)
            fy_ = torch_y - 40 - random.randint(0, 120)
            size = random.randint(12, 32)
            c = random.choice([(240,180,50), (220,140,40), (200,100,30), (255,200,80)])
            alpha = random.randint(150, 230)
            d.ellipse([fx_, fy_, fx_+size, fy_+size], fill=(*c, alpha))
        # 火焰核心
        for i in range(40):
            fx_ = torch_x + random.randint(-16, 16)
            fy_ = torch_y - 60 - random.randint(0, 60)
            size = random.randint(8, 16)
            d.ellipse([fx_, fy_, fx_+size, fy_+size], fill=(255,240,180,220))
        # 光晕
        for r in range(120, 0, -1):
            alpha = max(5, 40 - r//3)
            for i in range(48):
                angle = math.radians(i * 7.5)
                x = int(torch_x + r * math.cos(angle))
                y = int(torch_y - 80 + r * math.sin(angle) * 0.6)
                if 0 <= x < SZ and 0 <= y < SZ:
                    d.point((x, y), fill=(220,160,60, alpha))
    # 火星飘散
    for _ in range(120):
        px = random.randint(200, 824)
        py = random.randint(160, 520)
        size = random.randint(4, 8)
        d.ellipse([px, py, px+size, py+size], fill=(255,200,80, random.randint(100,200)))
    save(img, "fx_night_fire")


# ══════════════════════════════════════════════════════════
#  15. 落石 — 巨石滚落 + 灰尘
# ══════════════════════════════════════════════════════════
def fx_boulder():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 巨石（多个）
    for bx, by, sz in [(400, 320, 120), (600, 400, 100), (480, 520, 80)]:
        # 石头主体
        d.polygon([
            (bx-sz, by), (bx-sz//2, by-sz),
            (bx+sz//2, by-sz+20), (bx+sz, by-sz//3),
            (bx+sz-20, by+sz//2), (bx-sz//3, by+sz)
        ], fill=(110,100,90,220))
        # 石头纹理
        d.line([(bx-sz//3, by-sz//2), (bx+sz//4, by-sz//3)],
               fill=(90,80,70,150), width=4)
        d.line([(bx-sz//4, by+sz//4), (bx+sz//3, by)],
               fill=(90,80,70,150), width=4)
    # 滚落轨迹
    for i in range(160):
        t = i / 160
        x = int(240 + t * 640)
        y = int(200 + t * 720)
        alpha = max(30, 120 - i * 1)
        d.point((x, y), fill=(100,90,80, alpha))
    # 撞击碎片
    random.seed(1501)
    for _ in range(200):
        angle = math.radians(random.uniform(180, 360))
        dist = random.randint(40, 200)
        sx = int(512 + dist * math.cos(angle))
        sy = int(800 + dist * math.sin(angle) * 0.4)
        size = random.randint(8, 24)
        c = random.choice([(100,90,80), (120,110,100), (80,70,60)])
        alpha = random.randint(140, 210)
        pb(d, sx, sy, size, size, (*c, alpha))
    # 灰尘
    for _ in range(160):
        sx = random.randint(320, 704)
        sy = random.randint(680, 880)
        size = random.randint(20, 48)
        d.ellipse([sx, sy, sx+size, sy+size], fill=(90,85,80,70))
    # 裂缝
    for i in range(5):
        sx = 440 + i * 40
        sy = 840
        for s in range(60):
            px = sx + random.randint(-4, 4)
            py = sy + s * 2
            if 0 <= px < SZ and 0 <= py < SZ:
                d.point((px, py), fill=(70,60,50,160))
    save(img, "fx_boulder")


def generate_all():
    print("=== 《山河策》战斗特效生成器 V2 (1024x1024) ===\n")
    effects = [
        fx_slash, fx_arrow_rain, fx_explosion, fx_heal,
        fx_shield_block, fx_charge, fx_critical, fx_fire,
        fx_poison, fx_freeze, fx_siege, fx_morale,
        fx_trap, fx_night_fire, fx_boulder,
    ]
    for func in effects:
        func()
    print(f"\n=== 完成！共 {len(effects)} 个战斗特效 ===")
    print(f"输出: {OUT_DIR}")
    print("规格: 1024x1024 | 纯特效无文字 | 透明背景")
    print("\n请在本地查看 effect1/ 目录即可。")

if __name__ == "__main__":
    generate_all()
