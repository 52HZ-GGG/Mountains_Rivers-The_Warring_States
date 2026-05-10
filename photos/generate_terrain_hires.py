"""
《山河策》1024x1024 六角形地形地块生成器 V5
物理台基 + 极致占满 + 3D 厚度感 + 独立地形轮廓
平顶六角形 | 透明背景 | 遵循 artline1.md
运行: python generate_terrain_hires.py
"""

import os, math, random
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "terrain")
os.makedirs(OUT_DIR, exist_ok=True)

SIZE = 1024
CX, CY = SIZE // 2, SIZE // 2

# ── 平顶六角形：最大化占满画布 ──
# 宽度 = 2R ≈ 1008, 高度 = R√3 ≈ 873
HR = 504
HV = [(CX + HR * math.cos(math.radians(60*i)),
       CY + HR * math.sin(math.radians(60*i))) for i in range(6)]

# 3D 台基参数
SIDE_H = 55  # 侧面厚度像素

# 侧面顶点（从六角形底边向下延伸）
BL, BR_ = HV[4], HV[5]  # 左下、右下顶点
SIDE_FACE = [BL, BR_,
             (BR_[0], BR_[1] + SIDE_H),
             (BL[0], BL[1] + SIDE_H)]

# 左侧面（左下→左上边缘向下）
LT, LB = HV[3], HV[4]
LEFT_FACE = [LT, LB,
             (LB[0], LB[1] + SIDE_H),
             (LT[0], LT[1] + SIDE_H * 0.4)]

# 右侧面
RT, RB = HV[0], HV[5]
RIGHT_FACE = [RT, RB,
              (RB[0], RB[1] + SIDE_H),
              (RT[0], RT[1] + SIDE_H * 0.4)]

WHITE = (255, 255, 255)

# ── 预计算六角形蒙版 ──
HH = HR * math.sqrt(3) / 2
HM = [[False]*SIZE for _ in range(SIZE)]
for _py in range(SIZE):
    _dy = abs(_py - CY)
    if _dy > HH: continue
    for _px in range(SIZE):
        _dx = abs(_px - CX)
        if _dx <= HR and HH*HR - HH*_dx - HR*_dy >= 0:
            HM[_py][_px] = True

def inside(x, y):
    return 0 <= x < SIZE and 0 <= y < SIZE and HM[y][x]

def pts(verts):
    return [(int(x), int(y)) for x, y in verts]

def bld(c1, c2, t):
    return tuple(int(c1[i]+(c2[i]-c1[i])*t) for i in range(3))

# ── 色板 ──
P = {
    "平原":  [(155,170,95),(185,198,125),(110,125,65),(70,80,40)],
    "森林":  [(35,95,40),(60,130,65),(20,60,25),(10,35,12)],
    "山地":  [(145,125,105),(180,165,148),(100,85,70),(55,45,38)],
    "河流":  [(45,85,140),(75,120,175),(28,55,95),(15,35,65)],
    "沼泽":  [(65,85,45),(90,115,65),(42,58,28),(22,32,15)],
    "桥梁":  [(55,90,135),(85,125,170),(35,60,90),(20,38,60)],
    "隘口":  [(55,65,60),(80,95,88),(35,42,38),(18,22,20)],
    "玉石":  [(120,160,130),(155,195,160),(85,115,90),(50,70,55)],
    "战火":  [(110,60,40),(145,85,55),(75,40,25),(40,20,10)],
}

# 侧面夯土/岩石色
SIDE = {
    "平原":  [(100,80,45),(125,100,60),(75,58,30),(50,38,18)],
    "森林":  [(45,55,35),(65,75,50),(30,38,22),(18,22,12)],
    "山地":  [(90,75,60),(115,95,78),(65,52,40),(40,30,22)],
    "河流":  [(55,65,80),(75,88,105),(38,45,58),(22,28,35)],
    "沼泽":  [(55,60,35),(72,78,48),(38,42,22),(22,25,12)],
    "桥梁":  [(55,65,80),(75,88,105),(38,45,58),(22,28,35)],
    "隘口":  [(65,60,55),(85,78,72),(45,40,36),(28,25,22)],
    "玉石":  [(75,95,80),(95,120,100),(55,68,55),(32,40,32)],
    "玉石矿床": [(75,95,80),(95,120,100),(55,68,55),(32,40,32)],
    "战火":  [(80,45,28),(105,62,38),(55,30,18),(30,15,8)],
    "战火遗址": [(80,45,28),(105,62,38),(55,30,18),(30,15,8)],
}

B4 = [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]]


# ══════════════════════════════════════════════════════════
#  台基绘制（所有地形共享）
# ══════════════════════════════════════════════════════════
def draw_pedestal(img, side_colors):
    d = ImageDraw.Draw(img)
    sb, sh, ss, sd = side_colors
    # 正面侧面（最重要，视觉主面）
    d.polygon(pts(SIDE_FACE), fill=ss)
    # 左侧面（次要，稍亮）
    d.polygon(pts(LEFT_FACE), fill=bld(ss, sb, 0.3))
    # 右侧面（次要，稍暗）
    d.polygon(pts(RIGHT_FACE), fill=bld(ss, sd, 0.3))
    # 侧面夯土纹理（水平分层线）
    px_data = img.load()
    for fy in range(int(BL[1]), int(BL[1]) + SIDE_H):
        # 每隔几行画一条深色线（夯土层）
        if (fy - int(BL[1])) % 7 == 0:
            for fx in range(int(BL[0]), int(BR_[0]) + 1):
                if 0 <= fx < SIZE and 0 <= fy < SIZE:
                    c = px_data[fx, fy]
                    if isinstance(c, tuple) and len(c) >= 3:
                        px_data[fx, fy] = bld(c, sd, 0.4)
        # 随机岩石纹理点
        if (fy - int(BL[1])) % 3 == 0:
            for fx in range(int(BL[0]), int(BR_[0]) + 1):
                if 0 <= fx < SIZE and 0 <= fy < SIZE and random.random() < 0.15:
                    c = px_data[fx, fy]
                    if isinstance(c, tuple) and len(c) >= 3:
                        px_data[fx, fy] = bld(c, sh, 0.2)
    # 侧面顶部边缘高光
    for fx in range(int(BL[0]), int(BR_[0]) + 1):
        fy = int(BL[1])
        if 0 <= fx < SIZE and 0 <= fy < SIZE:
            px_data[fx, fy] = bld(sh, (200,190,170), 0.3)
    # 六角形顶面边缘阴影（台基顶面与侧面交界处）
    for i in range(6):
        x1, y1 = HV[i]
        x2, y2 = HV[(i+1) % 6]
        steps = int(max(abs(x2-x1), abs(y2-y1)))
        for s in range(steps):
            t = s / max(steps, 1)
            px = int(x1 + (x2-x1) * t)
            py = int(y1 + (y2-y1) * t)
            for dy in range(3):
                if inside(px, py+dy):
                    c = img.getpixel((px, py+dy))
                    if isinstance(c, tuple) and len(c) >= 3:
                        img.putpixel((px, py+dy), bld(c, (0,0,0), 0.15 + dy*0.05))


# ══════════════════════════════════════════════════════════
#  地形 1: 平原 — 极致平坦台地，麦田满铺
# ══════════════════════════════════════════════════════════
def draw_plain(img):
    d = ImageDraw.Draw(img)
    b,h,s,dk = P["平原"]
    # 顶面：完整六角形填充
    d.polygon(pts(HV), fill=b)
    # 内部高光层（稍小六角形）
    inner = [(CX + (HR-30)*math.cos(math.radians(60*i)),
              CY + (HR-30)*math.sin(math.radians(60*i))) for i in range(6)]
    d.polygon(pts(inner), fill=h)
    # 麦田横向条纹（满铺整个顶面）
    for py in range(int(CY - HH), int(CY + HH)):
        if py % 5 == 0:
            for px in range(CX - HR, CX + HR):
                if inside(px, py):
                    img.putpixel((px, py), bld(h, (200,195,120), 0.3))
    # 麦穗（密集分布）
    random.seed(201)
    for _ in range(600):
        gx = CX + random.randint(-HR+40, HR-40)
        gy = CY + random.randint(-int(HH)+40, int(HH)-40)
        if inside(gx, gy):
            img.putpixel((gx, gy), bld(h, (230,210,130), 0.5))
            if inside(gx, gy-1):
                img.putpixel((gx, gy-1), (210,200,120))
    # 箭孔（均匀分布在边缘区域）
    for ax in range(CX - HR + 60, CX + HR - 59, 70):
        for ay_off in [-int(HH*0.5), int(HH*0.3)]:
            ay = CY + ay_off
            if inside(ax, ay):
                d.rectangle([ax-4, ay-6, ax+4, ay+2], fill=s)
                d.rectangle([ax-3, ay-5, ax+3, ay+1], fill=dk)
    # 边缘阴影
    for py in range(int(CY - HH), int(CY + HH)):
        for px in range(CX - HR, CX + HR):
            if inside(px, py):
                dx = abs(px - CX)
                dy = abs(py - CY)
                dist = (dx/HR + dy/HH)
                if dist > 0.85:
                    c = img.getpixel((px, py))
                    if isinstance(c, tuple) and len(c) >= 3:
                        img.putpixel((px, py), bld(c, s, (dist-0.85)*3))


# ══════════════════════════════════════════════════════════
#  地形 2: 山地 — 三重堆叠方块，棱角暴政
# ══════════════════════════════════════════════════════════
def draw_mountain(img):
    d = ImageDraw.Draw(img)
    b,h,s,dk = P["山地"]
    # 底层满铺
    d.polygon(pts(HV), fill=bld(b, s, 0.5))
    # 底层大方块（占据下半部）
    d.rectangle([CX-400, CY+60, CX+400, CY+int(HH)-20], fill=s)
    d.rectangle([CX-390, CY+70, CX+390, CY+int(HH)-30], fill=b)
    # 中层方块（左偏）
    d.rectangle([CX-350, CY-120, CX+150, CY+80], fill=h)
    d.rectangle([CX-340, CY-110, CX+140, CY+70], fill=bld(h, b, 0.4))
    # 顶层方块（右偏）
    d.rectangle([CX-100, CY-300, CX+300, CY-100], fill=s)
    d.rectangle([CX-90, CY-290, CX+290, CY-110], fill=h)
    # 烟囱结构（顶部中央）
    d.rectangle([CX-25, CY-420, CX+45, CY-280], fill=dk)
    d.rectangle([CX-20, CY-415, CX+40, CY-285], fill=s)
    d.rectangle([CX-15, CY-440, CX+35, CY-415], fill=bld(dk, (0,0,0), 0.3))
    # 45 度棱角边缘像素（刺状）
    random.seed(301)
    for _ in range(400):
        ex = CX + random.randint(-HR+30, HR-30)
        ey = CY + random.randint(-int(HH)+30, int(HH)-30)
        if inside(ex, ey):
            dx = abs(ex - CX)
            dy = abs(ey - CY)
            if dx > HR*0.6 or dy > HH*0.55:
                if random.random() < 0.35:
                    img.putpixel((ex, ey), dk)
                    if inside(ex+1, ey-1):
                        img.putpixel((ex+1, ey-1), s)
    # 岩石纹理线
    for py in range(int(CY - HH), int(CY + HH)):
        if py % 4 == 0:
            for px in range(CX - HR, CX + HR):
                if inside(px, py) and random.random() < 0.2:
                    img.putpixel((px, py), dk)
    # 雪线
    for px in range(CX-80, CX+280):
        sy = CY - 300 + abs(px - CX - 100) // 4
        if inside(px, sy):
            img.putpixel((px, sy), (220, 225, 235))
            if inside(px, sy-1):
                img.putpixel((px, sy-1), (240, 242, 248))


# ══════════════════════════════════════════════════════════
#  地形 3: 河流 — 半圆弧线，柔和流动
# ══════════════════════════════════════════════════════════
def draw_river(img):
    d = ImageDraw.Draw(img)
    b,h,s,dk = P["河流"]
    # 底层满铺深水
    d.polygon(pts(HV), fill=s)
    # 半圆波浪主体
    for i in range(8):
        y_off = CY - int(HH*0.4) + i * int(HH*0.12)
        x_shrink = i * 25
        d.ellipse([CX-HR+60+x_shrink, y_off-50,
                   CX+HR-60-x_shrink, y_off+80],
                  fill=h if i % 2 == 0 else bld(h, b, 0.3))
    # 顶部云朵
    d.ellipse([CX-250, CY-int(HH*0.7), CX+250, CY-int(HH*0.3)],
             fill=bld(h, (180,210,240), 0.3))
    d.ellipse([CX-200, CY-int(HH*0.65), CX+200, CY-int(HH*0.35)],
             fill=h)
    # 羽翼弧线（左）
    for i in range(40):
        angle = math.radians(150 + i * 2.2)
        fx = int(CX - 250 + 150 * math.cos(angle))
        fy = int(CY - int(HH*0.5) + 80 * math.sin(angle))
        if inside(fx, fy):
            img.putpixel((fx, fy), bld(h, (200,225,250), 0.5))
            if inside(fx+1, fy):
                img.putpixel((fx+1, fy), h)
    # 羽翼弧线（右）
    for i in range(40):
        angle = math.radians(30 + i * 2.2)
        fx = int(CX + 250 + 150 * math.cos(angle))
        fy = int(CY - int(HH*0.5) + 80 * math.sin(angle))
        if inside(fx, fy):
            img.putpixel((fx, fy), bld(h, (200,225,250), 0.5))
            if inside(fx+1, fy):
                img.putpixel((fx+1, fy), h)
    # 水波光点
    random.seed(401)
    for _ in range(400):
        wx = CX + random.randint(-HR+50, HR-50)
        wy = CY + random.randint(-int(HH*0.6), int(HH*0.8))
        if inside(wx, wy):
            img.putpixel((wx, wy), bld(h, (160,200,240), random.random()*0.6))


# ══════════════════════════════════════════════════════════
#  地形 4: 森林 — 双阙横向，拱桥连接
# ══════════════════════════════════════════════════════════
def draw_forest(img):
    d = ImageDraw.Draw(img)
    b,h,s,dk = P["森林"]
    # 底层满铺
    d.polygon(pts(HV), fill=bld(b, s, 0.5))
    # 左阙楼
    d.rectangle([CX-HR+50, CY-120, CX-HR+280, CY+int(HH)-30], fill=s)
    d.rectangle([CX-HR+60, CY-110, CX-HR+270, CY+int(HH)-40], fill=b)
    d.rectangle([CX-HR+70, CY-100, CX-HR+260, CY-60], fill=h)
    # 右阙楼
    d.rectangle([CX+HR-280, CY-120, CX+HR-50, CY+int(HH)-30], fill=s)
    d.rectangle([CX+HR-270, CY-110, CX+HR-60, CY+int(HH)-40], fill=b)
    d.rectangle([CX+HR-260, CY-100, CX+HR-70, CY-60], fill=h)
    # 拱桥连接
    d.arc([CX-HR+270, CY-250, CX+HR-270, CY+50], 180, 0, fill=h, width=50)
    d.arc([CX-HR+280, CY-240, CX+HR-280, CY+40], 180, 0,
          fill=bld(h, b, 0.4), width=35)
    # 树冠密集覆盖
    random.seed(501)
    for _ in range(350):
        tx = CX + random.randint(-HR+60, HR-60)
        ty = CY + random.randint(-int(HH*0.8), int(HH*0.7))
        if inside(tx, ty):
            for dx in range(-4, 5):
                for dy in range(-4, 2):
                    if abs(dx)+abs(dy) <= 4 and inside(tx+dx, ty+dy):
                        c = h if (dx+dy) % 2 == 0 else b
                        img.putpixel((tx+dx, ty+dy), c)
            for dy in range(3, 6):
                if inside(tx, ty+dy):
                    img.putpixel((tx, ty+dy), dk)
    # 金色装饰
    for _ in range(40):
        gx = CX + random.randint(-HR+80, HR-80)
        gy = CY + random.randint(-int(HH*0.5), int(HH*0.5))
        if inside(gx, gy):
            img.putpixel((gx, gy), bld((180,150,80), h, 0.3))


# ══════════════════════════════════════════════════════════
#  地形 5: 沼泽 — 凸字形金字塔堆叠
# ══════════════════════════════════════════════════════════
def draw_swamp(img):
    d = ImageDraw.Draw(img)
    b,h,s,dk = P["沼泽"]
    # 底层满铺
    d.polygon(pts(HV), fill=s)
    # 底层大正方形
    d.rectangle([CX-380, CY+100, CX+380, CY+int(HH)-20], fill=b)
    # 中层正方形
    d.rectangle([CX-280, CY-80, CX+280, CY+110], fill=h)
    d.rectangle([CX-270, CY-70, CX+270, CY+100], fill=bld(h, b, 0.4))
    # 顶层小正方形
    d.rectangle([CX-160, CY-220, CX+160, CY-70], fill=s)
    d.rectangle([CX-150, CY-210, CX+150, CY-80], fill=b)
    # 歇山顶
    d.polygon(pts([
        (CX-170, CY-220), (CX+170, CY-220),
        (CX+120, CY-310), (CX-120, CY-310),
    ]), fill=h)
    d.polygon(pts([
        (CX-160, CY-225), (CX+160, CY-225),
        (CX+115, CY-305), (CX-115, CY-305),
    ]), fill=bld(h, (100,120,70), 0.3))
    # 泥沼水洼
    random.seed(601)
    for _ in range(140):
        wx = CX + random.randint(-HR+60, HR-60)
        wy = CY + random.randint(-int(HH*0.5), int(HH*0.8))
        if inside(wx, wy):
            for dx in range(-5, 6):
                for dy in range(-5, 6):
                    if dx*dx+dy*dy <= 25 and inside(wx+dx, wy+dy):
                        img.putpixel((wx+dx, wy+dy), dk)
    # 气泡
    for _ in range(250):
        bx = CX + random.randint(-HR+60, HR-60)
        by = CY + random.randint(-int(HH*0.5), int(HH*0.8))
        if inside(bx, by):
            img.putpixel((bx, by), h)
    # 植被
    for _ in range(200):
        gx = CX + random.randint(-HR+60, HR-60)
        gy = CY + random.randint(-int(HH*0.5), int(HH*0.7))
        if inside(gx, gy):
            img.putpixel((gx, gy), (80,110,55))
            if inside(gx, gy-1):
                img.putpixel((gx, gy-1), (95,125,65))


# ══════════════════════════════════════════════════════════
#  地形 6: 桥梁 — 低矮重型战车掩体
# ══════════════════════════════════════════════════════════
def draw_bridge(img):
    d = ImageDraw.Draw(img)
    b,h,s,dk = P["桥梁"]
    # 底层满铺
    d.polygon(pts(HV), fill=s)
    # 主体：低矮梯形掩体（占据下半部）
    d.polygon(pts([
        (CX-HR+50, CY+int(HH*0.3)),
        (CX+HR-50, CY+int(HH*0.3)),
        (CX+HR-100, CY+int(HH)-20),
        (CX-HR+100, CY+int(HH)-20),
    ]), fill=b)
    # 上层防御模块
    d.polygon(pts([
        (CX-HR+150, CY-int(HH*0.2)),
        (CX+HR-150, CY-int(HH*0.2)),
        (CX+HR-200, CY+int(HH*0.35)),
        (CX-HR+200, CY+int(HH*0.35)),
    ]), fill=h)
    # 箭孔
    for ax in range(CX-HR+200, CX+HR-199, 70):
        if inside(ax, CY+int(HH*0.1)):
            d.rectangle([ax-6, CY+int(HH*0.1)-8, ax+6, CY+int(HH*0.1)+4], fill=dk)
    # 巨弩装饰
    d.rectangle([CX-5, CY+int(HH*0.45), CX+5, CY+int(HH*0.55)], fill=dk)
    d.rectangle([CX-100, CY+int(HH*0.48), CX-100, CY+int(HH*0.50)], fill=s)
    d.rectangle([CX+100, CY+int(HH*0.48), CX+100, CY+int(HH*0.50)], fill=s)
    d.line([(CX-100, CY+int(HH*0.49)), (CX-160, CY+int(HH*0.38))], fill=dk, width=3)
    d.line([(CX+100, CY+int(HH*0.49)), (CX+160, CY+int(HH*0.38))], fill=dk, width=3)
    d.line([(CX-150, CY+int(HH*0.44)), (CX+150, CY+int(HH*0.44))], fill=(110,85,45), width=2)
    # 装甲纹理
    random.seed(701)
    for _ in range(300):
        tx = CX + random.randint(-HR+80, HR-80)
        ty = CY + random.randint(-int(HH*0.3), int(HH*0.8))
        if inside(tx, ty) and random.random() < 0.25:
            img.putpixel((tx, ty), dk)


# ══════════════════════════════════════════════════════════
#  地形 7: 隘口 — 单体高耸重型塔楼
# ══════════════════════════════════════════════════════════
def draw_pass(img):
    d = ImageDraw.Draw(img)
    b,h,s,dk = P["隘口"]
    # 底层满铺
    d.polygon(pts(HV), fill=s)
    # 主塔楼
    d.rectangle([CX-160, CY-int(HH*0.65), CX+160, CY+int(HH)-20], fill=b)
    # 厚重基座
    d.rectangle([CX-220, CY+int(HH*0.3), CX+220, CY+int(HH)-20], fill=dk)
    d.rectangle([CX-210, CY+int(HH*0.31), CX+210, CY+int(HH)-30], fill=s)
    # 庑殿顶 + 积雪
    d.polygon(pts([
        (CX-200, CY-int(HH*0.65)),
        (CX+200, CY-int(HH*0.65)),
        (CX+130, CY-int(HH*0.85)),
        (CX-130, CY-int(HH*0.85)),
    ]), fill=h)
    d.polygon(pts([
        (CX-190, CY-int(HH*0.66)),
        (CX+190, CY-int(HH*0.66)),
        (CX+125, CY-int(HH*0.84)),
        (CX-125, CY-int(HH*0.84)),
    ]), fill=(210,215,225))
    d.polygon(pts([
        (CX-170, CY-int(HH*0.67)),
        (CX+170, CY-int(HH*0.67)),
        (CX+120, CY-int(HH*0.83)),
        (CX-120, CY-int(HH*0.83)),
    ]), fill=(235,238,245))
    # 窗户
    for wy in range(CY-int(HH*0.4), CY+int(HH*0.4), 90):
        for wx in [CX-60, CX+60]:
            if inside(wx, wy):
                d.rectangle([wx-10, wy-14, wx+10, wy+5], fill=dk)
    # 冰晶纹理
    random.seed(801)
    for _ in range(150):
        ix = CX + random.randint(-140, 140)
        iy = CY + random.randint(-int(HH*0.6), int(HH*0.8))
        if inside(ix, iy):
            img.putpixel((ix, iy), bld(b, (200,210,225), random.random()*0.3))


# ══════════════════════════════════════════════════════════
#  地形 8: 玉石矿床 — 圆形中空玉环
# ══════════════════════════════════════════════════════════
def draw_jade(img):
    d = ImageDraw.Draw(img)
    b,h,s,dk = P["玉石"]
    # 外圆
    d.ellipse([CX-HR+40, CY-int(HH)+40, CX+HR-40, CY+int(HH)-40], fill=s)
    d.ellipse([CX-HR+60, CY-int(HH)+60, CX+HR-60, CY+int(HH)-60], fill=b)
    # 中空
    d.ellipse([CX-220, CY-220, CX+220, CY+220], fill=dk)
    d.ellipse([CX-200, CY-200, CX+200, CY+200], fill=bld(dk, b, 0.5))
    # 内部半月
    d.ellipse([CX-170, CY-80, CX+170, CY+280], fill=h)
    d.ellipse([CX-150, CY-60, CX+150, CY+260], fill=bld(h, (180,210,190), 0.3))
    # 云纹弧线
    for i in range(50):
        angle = math.radians(i * 7.2)
        rx = 350 + 35 * math.sin(math.radians(i * 21.6))
        fx = int(CX + rx * math.cos(angle))
        fy = int(CY + rx * math.sin(angle))
        if inside(fx, fy):
            img.putpixel((fx, fy), bld(h, (200,230,210), 0.6))
            if inside(fx+1, fy):
                img.putpixel((fx+1, fy), h)
    # 玉石高光
    random.seed(901)
    for _ in range(200):
        jx = CX + random.randint(-HR+80, HR-80)
        jy = CY + random.randint(-int(HH)+80, int(HH)-80)
        if inside(jx, jy):
            r = math.sqrt((jx-CX)**2 + (jy-CY)**2)
            if 200 < r < HR-80:
                if random.random() < 0.2:
                    img.putpixel((jx, jy), bld(h, (200,240,220), 0.5))


# ══════════════════════════════════════════════════════════
#  地形 9: 战火遗址 — 崩塌废墟
# ══════════════════════════════════════════════════════════
def draw_ruins(img):
    d = ImageDraw.Draw(img)
    b,h,s,dk = P["战火"]
    # 底层满铺焦土
    d.polygon(pts(HV), fill=bld(dk, s, 0.5))
    # 残垣断壁（非对称）
    d.rectangle([CX-HR+50, CY+80, CX-HR+300, CY+int(HH)-20], fill=s)
    d.rectangle([CX-HR+60, CY+90, CX-HR+290, CY+int(HH)-30], fill=b)
    d.rectangle([CX+50, CY-60, CX+320, CY+260], fill=s)
    d.rectangle([CX+60, CY-50, CX+310, CY+250], fill=bld(b, s, 0.5))
    # 断裂立柱
    d.rectangle([CX-80, CY-220, CX-35, CY+160], fill=h)
    d.rectangle([CX-75, CY-215, CX-40, CY+155], fill=bld(h, b, 0.4))
    # 獠牙残顶（左）
    random.seed(1001)
    for i in range(6):
        tx = CX - HR + 100 + i * 50
        ty = CY + 60 - i * 30 - random.randint(0, 40)
        d.polygon(pts([(tx, CY+80), (tx+18, ty), (tx+36, CY+80)]), fill=dk)
    # 獠牙残顶（右）
    for i in range(5):
        tx = CX + 80 + i * 55
        ty = CY - 80 - i * 25 - random.randint(0, 30)
        d.polygon(pts([(tx, CY-60), (tx+22, ty), (tx+44, CY-60)]), fill=dk)
    # 焦土纹理
    for _ in range(500):
        rx = CX + random.randint(-HR+40, HR-40)
        ry = CY + random.randint(-int(HH)+40, int(HH)-40)
        if inside(rx, ry):
            c = random.choice([dk, s, bld(dk, (80,30,15), 0.5)])
            img.putpixel((rx, ry), c)
    # 余烬
    for _ in range(60):
        fx = CX + random.randint(-HR+60, HR-60)
        fy = CY + random.randint(-int(HH*0.5), int(HH*0.8))
        if inside(fx, fy):
            img.putpixel((fx, fy), bld((180,60,20), (220,100,30), random.random()))
    # 烟尘
    for _ in range(120):
        sx = CX + random.randint(-HR+60, HR-60)
        sy = CY + random.randint(-int(HH*0.8), int(HH*0.5))
        if inside(sx, sy):
            img.putpixel((sx, sy), bld(dk, (60,50,45), 0.5))


# ══════════════════════════════════════════════════════════
#  保存
# ══════════════════════════════════════════════════════════
def save(img, mask, name):
    soft = mask.filter(ImageFilter.GaussianBlur(radius=2.5))
    bg = Image.new("RGBA", (SIZE, SIZE), (255,255,255,0))
    bg.paste(img, (0,0), soft)
    draw = ImageDraw.Draw(bg)
    # 绘制六角形边框 + 侧面轮廓
    draw.polygon(HV, outline=(0,0,0,120), width=2)
    draw.polygon(pts(SIDE_FACE), outline=(0,0,0,80), width=1)
    bl_pt = (int(BL[0]), int(BL[1]))
    br_pt = (int(BR_[0]), int(BR_[1]))
    s2_pt = (int(SIDE_FACE[2][0]), int(SIDE_FACE[2][1]))
    s3_pt = (int(SIDE_FACE[3][0]), int(SIDE_FACE[3][1]))
    draw.line([bl_pt, s2_pt], fill=(0,0,0,60), width=1)
    draw.line([br_pt, s3_pt], fill=(0,0,0,60), width=1)
    bg.save(os.path.join(OUT_DIR, f"{name}.png"))
    print(f"  [OK] {name}.png")


# ══════════════════════════════════════════════════════════
#  主函数
# ══════════════════════════════════════════════════════════
def generate_all():
    print("=== 《山河策》1024x1024 六角形地形地块 V5 ===\n")
    print(f"  几何: 平顶六角形 | 半径 {HR}px | 侧面厚度 {SIDE_H}px")
    print(f"  宽度: {HR*2}px / {SIZE}px | 高度: {int(HR*math.sqrt(3))}px")
    print(f"  9 种独立物理轮廓 | 3D 台基 | 透明背景\n")

    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).polygon(HV, fill=255)

    tiles = [
        ("tile_plain",    draw_plain,    "平原"),
        ("tile_forest",   draw_forest,   "森林"),
        ("tile_mountain", draw_mountain, "山地"),
        ("tile_river",    draw_river,    "河流"),
        ("tile_swamp",    draw_swamp,    "沼泽"),
        ("tile_bridge",   draw_bridge,   "桥梁"),
        ("tile_pass",     draw_pass,     "隘口"),
        ("tile_jade",     draw_jade,     "玉石矿床"),
        ("tile_ruins",    draw_ruins,    "战火遗址"),
    ]

    for i, (name, func, label) in enumerate(tiles):
        random.seed(100 + i * 137)
        img = Image.new("RGB", (SIZE, SIZE), WHITE)
        func(img)
        draw_pedestal(img, SIDE[label])
        save(img, mask, name)

    print(f"\n=== 完成！共 {len(tiles)} 个地形地块 ===")
    print(f"输出: {OUT_DIR}")
    print("规格: 1024x1024 | 平顶六角形 | 3D 台基 | 透明背景")
    print("\n请在本地查看 terrain/ 目录即可。")


if __name__ == "__main__":
    generate_all()
