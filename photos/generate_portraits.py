"""
《山河策》22个人物 1024x1024 像素风立绘生成器
7君主 + 15将领 · 每人独立造型 · 背景与服饰高对比
"""

import os, random, math
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
random.seed(42)

def save(img, *parts):
    p = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)
    print(f"  [OK] {os.path.relpath(p, ROOT)}")

def px(img, x, y, color):
    w, h = img.size
    if 0 <= x < w and 0 <= y < h:
        img.putpixel((x, y), color)

def rect(img, x0, y0, x1, y1, color):
    for y in range(max(0,y0), min(img.size[1],y1+1)):
        for x in range(max(0,x0), min(img.size[0],x1+1)):
            img.putpixel((x, y), color)

def blend(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(min(len(c1), len(c2))))

def add_noise(c, amt=8):
    n = random.randint(-amt, amt)
    return tuple(max(0, min(255, c[i] + n)) for i in range(3))

def draw_ellipse(img, cx, cy, rx, ry, color):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if ((x - cx)/max(1,rx))**2 + ((y - cy)/max(1,ry))**2 <= 1:
                px(img, x, y, color)

def draw_circle(img, cx, cy, r, color):
    draw_ellipse(img, cx, cy, r, r, color)

def gradient_v(img, x0, y0, x1, y1, c_top, c_bot):
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        c = blend(c_top, c_bot, t)
        for x in range(x0, x1 + 1):
            px(img, x, y, c)

def metal_sheen(img, x0, y0, x1, y1, base):
    cx, cy = (x0+x1)/2, (y0+y1)/2
    md = math.sqrt((x1-x0)**2+(y1-y0)**2)/2
    if md == 0: return
    for y in range(y0, y1+1):
        for x in range(x0, x1+1):
            d = math.sqrt((x-cx)**2+(y-cy)**2)
            s = int(20*(1-(d/md)**2))
            px(img, x, y, add_noise(tuple(max(0,min(255,base[i]+s)) for i in range(3)), 3))


# ══════════════════════════════════════════════════════════
#  通用绘制函数
# ══════════════════════════════════════════════════════════

def draw_bg_gradient(img, c_top, c_bot, pattern="none"):
    """渐变背景 + 可选纹理"""
    w, h = img.size
    for y in range(h):
        t = y / h
        c = blend(c_top, c_bot, t)
        for x in range(w):
            px(img, x, y, c)
    if pattern == "grid":
        for y in range(0, h, 40):
            for x in range(w):
                px(img, x, y, blend(img.getpixel((x,y)), (0,0,0,255) if len(img.getpixel((x,y)))==3 else (0,0,0), 0.05))
        for x in range(0, w, 40):
            for y in range(h):
                px(img, x, y, blend(img.getpixel((x,y)), (0,0,0,255) if len(img.getpixel((x,y)))==3 else (0,0,0), 0.05))
    elif pattern == "dots":
        for y in range(0, h, 24):
            for x in range(0, w, 24):
                if (x//24 + y//24) % 2 == 0:
                    draw_circle(img, x+12, y+12, 2, blend(img.getpixel((x+12,y+12)), (255,255,255), 0.08))
    elif pattern == "diagonal":
        for y in range(h):
            for x in range(w):
                if (x + y) % 60 < 2:
                    c = img.getpixel((x, y))
                    px(img, x, y, blend(c, (255,255,255), 0.06))

def draw_face(img, cx, cy, skin_base, skin_shadow, skin_hi, expression="stern"):
    """通用面部"""
    fw, fh = 64, 78
    # 脸型
    draw_ellipse(img, cx, cy, fw, fh, skin_base)
    # 下颌阴影
    for y in range(cy+25, cy+fh):
        for x in range(cx-fw, cx+fw):
            if ((x-cx)/fw)**2+((y-cy)/fh)**2<=1:
                t = (y-cy-25)/(fh-25)
                c = img.getpixel((x,y))
                px(img, x, y, blend(c, skin_shadow, t*0.45))
    # 左侧阴影
    for y in range(cy-fh, cy+fh):
        for x in range(cx-fw, cx):
            if ((x-cx)/fw)**2+((y-cy)/fh)**2<=1:
                t = (cx-x)/fw
                c = img.getpixel((x,y))
                px(img, x, y, blend(c, skin_shadow, t*0.25))
    # 右侧高光
    for y in range(cy-fh, cy+15):
        for x in range(cx+15, cx+fw):
            if ((x-cx)/fw)**2+((y-cy)/fh)**2<=1:
                t = 1-abs(y-cy+15)/(fh+15)
                c = img.getpixel((x,y))
                px(img, x, y, blend(c, skin_hi, t*0.18))

    # 眉毛
    brow_c = (35, 30, 25)
    for bx in range(cx-36, cx-6):
        for dy in range(-2, 1):
            by = cy-26+dy+int(0.3*(bx-cx+36))
            px(img, bx, by, brow_c)
    for bx in range(cx+6, cx+36):
        for dy in range(-2, 1):
            by = cy-26+dy+int(0.3*(cx+36-bx))
            px(img, bx, by, brow_c)

    # 眼白
    for ex in range(cx-30, cx-10):
        for ey in range(cy-18, cy-8):
            px(img, ex, ey, (250, 245, 235))
    for ex in range(cx+10, cx+30):
        for ey in range(cy-18, cy-8):
            px(img, ex, ey, (250, 245, 235))
    # 瞳孔
    draw_circle(img, cx-20, cy-14, 5, (25, 20, 15))
    draw_circle(img, cx+20, cy-14, 5, (25, 20, 15))
    px(img, cx-21, cy-15, (55, 45, 35))
    px(img, cx+19, cy-15, (55, 45, 35))
    # 眼睑
    for ex in range(cx-32, cx-8):
        px(img, ex, cy-20, (40, 35, 30))
    for ex in range(cx+8, cx+32):
        px(img, ex, cy-20, (40, 35, 30))

    # 鼻
    for ny in range(cy-6, cy+10):
        nx = cx+int(1.5*math.sin((ny-cy+6)*0.2))
        px(img, nx, ny, skin_shadow)
        px(img, nx+1, ny, skin_shadow)
    px(img, cx-4, cy+9, skin_shadow)
    px(img, cx+4, cy+9, skin_shadow)

    # 嘴
    if expression == "stern":
        for mx in range(cx-12, cx+12):
            px(img, mx, cy+22, (150, 95, 85))
            px(img, mx, cy+23, (140, 85, 75))
    elif expression == "smile":
        for mx in range(cx-14, cx+14):
            my = cy+22+int(2*math.sin((mx-cx)*0.15))
            px(img, mx, my, (155, 100, 90))
    elif expression == "proud":
        for mx in range(cx-15, cx+15):
            my = cy+22-int(1*abs(mx-cx)/15)
            px(img, mx, my, (155, 100, 90))
    elif expression == "calm":
        for mx in range(cx-13, cx+13):
            px(img, mx, cy+22, (160, 110, 95))
    else:
        for mx in range(cx-12, cx+12):
            px(img, mx, cy+22, (150, 95, 85))

    # 耳
    for ey in range(cy-12, cy+12):
        px(img, cx-fw+2, ey, skin_shadow)
        px(img, cx-fw+1, ey, skin_shadow)
        px(img, cx+fw-2, ey, skin_shadow)
        px(img, cx+fw-1, ey, skin_shadow)

def draw_beard(img, cx, cy, style="short", color=(50,40,30)):
    """胡须"""
    if style == "short":
        for bx in range(cx-18, cx+18):
            for by in range(cy+30, cy+48):
                if abs(bx-cx)<16-(by-cy-30)*0.3 and random.random()<0.35:
                    n = random.randint(-8,8)
                    px(img, bx, by, tuple(max(0,min(255,color[i]+n)) for i in range(3)))
    elif style == "long":
        for bx in range(cx-20, cx+20):
            for by in range(cy+30, cy+80):
                if abs(bx-cx)<15-(by-cy-30)*0.15 and random.random()<0.3:
                    n = random.randint(-8,8)
                    px(img, bx, by, tuple(max(0,min(255,color[i]+n)) for i in range(3)))
    elif style == "straggly":
        for bx in range(cx-22, cx+22):
            for by in range(cy+30, cy+65):
                if abs(bx-cx)<18 and random.random()<0.25:
                    n = random.randint(-10,10)
                    px(img, bx, by, tuple(max(0,min(255,color[i]+n)) for i in range(3)))
    elif style == "none":
        pass
    elif style == "thin":
        for bx in range(cx-12, cx+12):
            for by in range(cy+30, cy+42):
                if abs(bx-cx)<10 and random.random()<0.3:
                    px(img, bx, by, color)

def draw_crown_generic(img, cx, cy, style, c_main, c_accent):
    """冠饰通用"""
    if style == "tall":  # 秦式高冠
        ct, cb = cy-110, cy-65
        for y in range(ct, cb):
            t = (y-ct)/(cb-ct)
            w = int(26+t*24)
            for x in range(cx-w, cx+w):
                px(img, x, y, add_noise(blend(c_main, (0,0,0), 0.2*t), 4))
        rect(img, cx-28, ct-3, cx+28, ct+2, c_main)
        rect(img, cx-38, ct+6, cx+38, ct+10, c_accent)
        metal_sheen(img, cx-38, ct+6, cx+38, ct+10, c_accent)
    elif style == "flat":  # 楚式扁冠
        ct, cb = cy-100, cy-70
        for y in range(ct, cb):
            t = (y-ct)/(cb-ct)
            w = int(35+t*15)
            for x in range(cx-w, cx+w):
                px(img, x, y, add_noise(c_main, 4))
        rect(img, cx-40, ct-2, cx+40, ct+3, c_accent)
    elif style == "round":  # 齐式圆冠
        draw_ellipse(img, cx, cy-85, 35, 25, c_main)
        rect(img, cx-30, cy-88, cx+30, cy-84, c_accent)
    elif style == "war":  # 赵式武冠
        ct, cb = cy-105, cy-65
        for y in range(ct, cb):
            t = (y-ct)/(cb-ct)
            w = int(30+t*20)
            for x in range(cx-w, cx+w):
                px(img, x, y, add_noise(c_main, 5))
        rect(img, cx-32, ct-5, cx+32, ct, c_accent)
        # 盔缨
        for y in range(ct-25, ct):
            for x in range(cx-4, cx+5):
                px(img, x, y, c_accent)
    elif style == "scholar":  # 文士冠
        ct, cb = cy-100, cy-68
        for y in range(ct, cb):
            w = int(22+(y-ct)*0.4)
            for x in range(cx-w, cx+w):
                px(img, x, y, add_noise(c_main, 3))
        rect(img, cx-24, ct-2, cx+24, ct+2, c_accent)
    elif style == "simple":  # 简朴冠
        ct, cb = cy-95, cy-70
        for y in range(ct, cb):
            w = int(20+(y-ct)*0.3)
            for x in range(cx-w, cx+w):
                px(img, x, y, add_noise(c_main, 3))

def draw_robe_generic(img, cx, cy, shoulder_w, waist_w, hem_w,
                      c_main, c_dark, c_mid, c_accent, top_y=None):
    """深衣通用"""
    if top_y is None: top_y = cy+40
    bot_y = 920

    for y in range(top_y, bot_y):
        if y < cy+180:
            t = (y-top_y)/(cy+180-top_y)
            w = int(shoulder_w + t*(waist_w-shoulder_w))
        else:
            t = (y-cy-180)/(bot_y-cy-180)
            w = int(waist_w + t*(hem_w-waist_w))
        for x in range(cx-w, cx+w):
            n = random.randint(-4,4)
            if abs(x-cx)<2:
                c = add_noise(c_dark, 3)
            elif x < cx-w+18:
                t2 = (x-cx+w)/18
                c = add_noise(blend(c_dark, c_mid, t2), 4)
            elif x > cx+w-25:
                t2 = (cx+w-x)/25
                c = add_noise(blend(c_dark, c_mid, t2), 4)
            else:
                c = add_noise(c_dark, 5)
            px(img, x, y, c)

    # 交领
    for y in range(top_y, top_y+75):
        lx = cx-18+int(y*0.28)-int(top_y*0.28)
        rx = cx+18-int(y*0.28)+int(top_y*0.28)
        for dx in range(-5,2): px(img, lx+dx, y, add_noise(c_mid,3))
        for dx in range(-2,5): px(img, rx+dx, y, add_noise(c_mid,3))

    # 领边镶边
    for y in range(top_y, top_y+85):
        lx = cx-20+int(y*0.28)-int(top_y*0.28)
        rx = cx+20-int(y*0.28)+int(top_y*0.28)
        for d in range(-2,0):
            px(img, lx+d, y, c_accent)
            px(img, rx+d+4, y, c_accent)

    # 下摆镶边
    for x in range(cx-hem_w, cx+hem_w):
        for d in range(-3,0):
            if abs(x-cx)<hem_w-5:
                px(img, x, bot_y+d, c_accent)

    # 衣袖
    draw_sleeve_generic(img, cx-shoulder_w, top_y+8, -1, c_dark, c_mid, c_accent)
    draw_sleeve_generic(img, cx+shoulder_w, top_y+8, 1, c_dark, c_mid, c_accent)

def draw_sleeve_generic(img, sx, sy, dire, c_dark, c_mid, c_accent):
    sl, sw = 160, 50
    for y in range(sy, sy+sl):
        t = (y-sy)/sl
        w = int(sw*(1-t*0.3))
        for x in range(sx, sx+dire*w, dire):
            c = add_noise(c_mid if abs(x-sx)<8 else c_dark, 4)
            px(img, x, y, c)
    for x in range(sx, sx+dire*int(sw*0.7), dire):
        for d in range(-2,2):
            px(img, x, sy+sl+d, c_accent)

def draw_hands_generic(img, cx, cy, skin_base, skin_shadow, hold="none"):
    """手"""
    lx, ly = cx-170, cy+260
    for y in range(ly-12, ly+20):
        for x in range(lx-16, lx+16):
            if math.sqrt((x-lx)**2+(y-ly)**2)<16:
                px(img, x, y, add_noise(blend(skin_base, skin_shadow, 0.15), 5))
    rx, ry = cx+155, cy+300
    for y in range(ry-10, ry+18):
        for x in range(rx-14, rx+14):
            if math.sqrt((x-rx)**2+(y-ry)**2)<14:
                px(img, x, y, add_noise(blend(skin_base, skin_shadow, 0.12), 5))

def draw_belt_generic(img, cx, cy, c_belt, c_buckle):
    by, bh = cy+180, 16
    for y in range(by, by+bh):
        for x in range(cx-100, cx+100):
            px(img, x, y, add_noise(c_belt, 3))
    rect(img, cx-14, by-2, cx+14, by+bh+2, c_buckle)
    metal_sheen(img, cx-14, by-2, cx+14, by+bh+2, c_buckle)

def draw_sword_generic(img, cx, cy, sx, c_blade, c_hilt, c_scabbard):
    """佩剑"""
    st, sb = cy+100, cy+440
    for y in range(st, sb):
        t = (y-st)/(sb-st)
        w = int(7-t*3)
        for x in range(sx-w, sx+w):
            px(img, x, y, add_noise(c_scabbard, 3))
    rect(img, sx-14, st-3, sx+14, st+7, c_hilt)
    metal_sheen(img, sx-14, st-3, sx+14, st+7, c_hilt)
    draw_circle(img, sx, sb+4, 7, c_blade)
    # 剑穗
    for y in range(sb+8, sb+40):
        px(img, sx+int(6*math.sin(y*0.12)), y, c_hilt)

def draw_boots_generic(img, cx, cy, c_boot):
    by = 900
    for side in [-1, 1]:
        bx = cx+side*75
        for y in range(by-35, by):
            for x in range(bx-20, bx+20):
                px(img, x, y, add_noise(c_boot, 3))
        for y in range(by, by+7):
            for x in range(bx-22, bx+22):
                px(img, x, y, (20,18,15))

def add_pixel_noise(img, density=0.025):
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if random.random() < density:
                c = img.getpixel((x, y))
                px(img, x, y, add_noise(c, 6))


# ══════════════════════════════════════════════════════════
#  特殊装饰
# ══════════════════════════════════════════════════════════

def draw_armor(img, cx, cy, c_plate, c_dark):
    """铠甲上身"""
    top, bot = cy+40, cy+200
    for y in range(top, bot):
        t = (y-top)/(bot-top)
        w = int(130-t*20)
        for x in range(cx-w, cx+w):
            n = random.randint(-5,5)
            if (y-top)%18<2:
                c = tuple(max(0,min(255,c_dark[i]+n)) for i in range(3))
            else:
                c = tuple(max(0,min(255,c_plate[i]+n)) for i in range(3))
            px(img, x, y, c)

def draw_armor_plates(img, cx, cy, c_plate, c_dark, c_rivet):
    """札甲 - 甲片层叠"""
    top, bot = cy+40, cy+220
    plate_h = 14
    row = 0
    for y in range(top, bot, plate_h):
        offset = (8 if row%2 else 0)
        w = int(125 - (y-top)*0.08)
        for py in range(y, min(y+plate_h-2, bot)):
            for x in range(cx-w, cx+w):
                n = random.randint(-4,4)
                if py == y:  # 甲片顶部高光
                    c = tuple(max(0,min(255,c_plate[i]+10+n)) for i in range(3))
                elif py > y+plate_h-4:  # 甲片底部阴影
                    c = tuple(max(0,min(255,c_dark[i]+n)) for i in range(3))
                else:
                    c = tuple(max(0,min(255,c_plate[i]+n)) for i in range(3))
                px(img, x+offset, py, c)
        # 铆钉
        for rx in range(cx-w+10, cx+w, 24):
            px(img, rx+offset, y+plate_h//2, c_rivet)
            px(img, rx+offset+1, y+plate_h//2, c_rivet)
            px(img, rx+offset, y+plate_h//2+1, c_rivet)
        row += 1

def draw_cape(img, cx, cy, dire, c_cape, c_dark):
    """披风"""
    top, bot = cy+30, cy+380
    for y in range(top, bot):
        t = (y-top)/(bot-top)
        w = int(60+t*40)
        wave = int(8*math.sin(y*0.03))
        for x in range(cx+dire*60, cx+dire*(60+w+wave)):
            n = random.randint(-4,4)
            if x == cx+dire*60:
                c = add_noise(c_dark, 3)
            else:
                c = add_noise(blend(c_cape, c_dark, t*0.3), 4)
            px(img, x, y, c)

def draw_fur_trim(img, cx, cy, y0, y1, w, c_fur):
    """毛皮镶边"""
    for y in range(y0, y1):
        for x in range(cx-w, cx+w):
            if random.random() < 0.7:
                n = random.randint(-15,15)
                c = tuple(max(0,min(255,c_fur[i]+n)) for i in range(3))
                px(img, x, y, c)

def draw_bamboo_scroll(img, x, y, c_bamboo, c_text, w=55, h=150):
    """竹简"""
    for py in range(y, y+h):
        for px2 in range(x, x+w):
            px(img, px2, py, add_noise(c_bamboo, 7))
    for py in [y+18, y+h-18]:
        for px2 in range(x-2, x+w+2):
            px(img, px2, py, (110,75,35))
    for row in range(4):
        for col in range(2):
            cx2 = x+8+col*22
            cy2 = y+28+row*28
            for s in range(random.randint(2,5)):
                sx = cx2+random.randint(-3,3)
                sy = cy2+random.randint(-5,5)
                px(img, sx, sy, c_text)

def draw_halberd(img, cx, cy, x0, c_shaft, c_blade):
    """戟 - 长兵器"""
    top, bot = cy-80, cy+400
    for y in range(top, bot):
        for x in range(x0-3, x0+4):
            px(img, x, y, add_noise(c_shaft, 3))
    # 戟刃
    for y in range(top, top+60):
        t = (y-top)/60
        w = int(20-t*10)
        for x in range(x0-w, x0+w):
            px(img, x, y, add_noise(c_blade, 4))
    # 横刃
    for y in range(top+40, top+55):
        for x in range(x0-25, x0+25):
            px(img, x, y, add_noise(c_blade, 4))

def draw_bow(img, cx, cy, x0, c_wood, c_string):
    """弓"""
    for y in range(cy-60, cy+120):
        t = (y-cy+60)/180
        x = x0+int(30*math.sin(t*math.pi))
        px(img, x, y, add_noise(c_wood, 3))
        px(img, x+1, y, add_noise(c_wood, 3))
    for y in range(cy-55, cy+115):
        px(img, x0, y, c_string)

def draw_fan(img, cx, cy, x0, c_paper, c_rib):
    """竹扇"""
    for a in range(-40, 41):
        rad = math.radians(a)
        for r in range(50, 130):
            x = x0+int(r*math.cos(rad))
            y = cy+int(r*math.sin(rad))-30
            if abs(a)%8<1:
                px(img, x, y, c_rib)
            else:
                px(img, x, y, add_noise(c_paper, 4))

def draw_jade_pendant(img, cx, cy, x0, y0, c_jade):
    """玉佩"""
    draw_ellipse(img, x0, y0, 10, 14, c_jade)
    px(img, x0, y0-14, (160,130,70))
    for y in range(y0-20, y0-14):
        px(img, x0, y, (160,130,70))


# ══════════════════════════════════════════════════════════
#  人物定义 & 生成
# ══════════════════════════════════════════════════════════

CHARACTERS = {
    # ── 君主 ──
    "portrait_monarch_qin": {
        "name": "秦王嬴政",
        "desc": "秦庄襄王之子，后来的秦始皇。雄才大略，虎视天下。",
        "bg_top": (140,120,90), "bg_bot": (100,85,65), "bg_pattern": "grid",
        "skin": ((195,165,135),(165,135,105),(215,185,155)),
        "crown": ("tall", (28,25,22), (170,140,80)),
        "robe": {"shoulder":135,"waist":105,"hem":185,
                 "main":(28,25,22),"dark":(38,34,30),"mid":(50,45,38),"accent":(170,140,80)},
        "belt": ((40,35,28),(170,140,80)),
        "beard": "short", "beard_c": (40,32,25),
        "expression": "proud",
        "extras": ["cape_gold"],
    },
    "portrait_monarch_chu": {
        "name": "楚考烈王",
        "desc": "楚国末期君主，崇巫好祀，楚文化浪漫神秘。",
        "bg_top": (50,80,65), "bg_bot": (30,55,45), "bg_pattern": "dots",
        "skin": ((195,168,140),(170,142,115),(218,192,165)),
        "crown": ("flat", (60,25,18), (200,160,80)),
        "robe": {"shoulder":130,"waist":100,"hem":175,
                 "main":(140,35,22),"dark":(110,28,18),"mid":(160,50,30),"accent":(200,160,80)},
        "belt": ((80,30,20),(200,160,80)),
        "beard": "long", "beard_c": (55,45,35),
        "expression": "calm",
        "extras": ["jade_pendant"],
    },
    "portrait_monarch_qi": {
        "name": "齐王建",
        "desc": "齐国末代君主，齐地富庶，重工商学术。",
        "bg_top": (100,85,60), "bg_bot": (70,60,42), "bg_pattern": "diagonal",
        "skin": ((192,165,138),(168,140,112),(215,190,162)),
        "crown": ("round", (35,65,50), (160,140,80)),
        "robe": {"shoulder":128,"waist":98,"hem":170,
                 "main":(40,70,52),"dark":(30,55,40),"mid":(55,85,62),"accent":(160,140,80)},
        "belt": ((35,55,40),(160,140,80)),
        "beard": "thin", "beard_c": (50,42,32),
        "expression": "smile",
        "extras": ["fan"],
    },
    "portrait_monarch_zhao": {
        "name": "赵孝成王",
        "desc": "赵武灵王之后，胡服骑射传统，尚武之风。",
        "bg_top": (110,100,85), "bg_bot": (75,68,55), "bg_pattern": "none",
        "skin": ((190,162,135),(162,135,108),(212,185,158)),
        "crown": ("war", (50,42,35), (150,120,70)),
        "robe": {"shoulder":132,"waist":102,"hem":178,
                 "main":(75,58,42),"dark":(58,45,32),"mid":(90,72,55),"accent":(150,120,70)},
        "belt": ((55,42,30),(150,120,70)),
        "beard": "short", "beard_c": (45,38,28),
        "expression": "stern",
        "extras": ["armor_light"],
    },
    "portrait_monarch_wei": {
        "name": "魏安釐王",
        "desc": "魏国君主，信陵君之兄。曾为霸主，后渐衰落。",
        "bg_top": (120,105,80), "bg_bot": (85,72,55), "bg_pattern": "none",
        "skin": ((188,160,132),(160,132,105),(210,182,155)),
        "crown": ("scholar", (40,42,55), (140,120,75)),
        "robe": {"shoulder":130,"waist":100,"hem":175,
                 "main":(50,52,68),"dark":(38,40,55),"mid":(65,68,82),"accent":(140,120,75)},
        "belt": ((42,44,58),(140,120,75)),
        "beard": "short", "beard_c": (48,40,30),
        "expression": "calm",
        "extras": [],
    },
    "portrait_monarch_yan": {
        "name": "燕王喜",
        "desc": "燕国末代君主，北方苦寒之地，民风质朴刚烈。",
        "bg_top": (130,110,90), "bg_bot": (95,80,65), "bg_pattern": "none",
        "skin": ((185,158,130),(158,130,102),(208,180,152)),
        "crown": ("simple", (55,50,45), (130,110,70)),
        "robe": {"shoulder":125,"waist":95,"hem":168,
                 "main":(60,55,50),"dark":(45,40,35),"mid":(75,68,60),"accent":(130,110,70)},
        "belt": ((50,45,38),(130,110,70)),
        "beard": "long", "beard_c": (60,52,42),
        "expression": "stern",
        "extras": ["fur_trim"],
    },
    "portrait_monarch_han": {
        "name": "韩王安",
        "desc": "韩国末代君主，国小力弱，法家申不害曾治韩。",
        "bg_top": (125,110,85), "bg_bot": (90,78,58), "bg_pattern": "none",
        "skin": ((190,165,138),(162,138,110),(212,188,160)),
        "crown": ("scholar", (60,52,40), (145,125,72)),
        "robe": {"shoulder":122,"waist":95,"hem":162,
                 "main":(165,140,100),"dark":(140,118,80),"mid":(180,158,118),"accent":(145,125,72)},
        "belt": ((130,110,78),(145,125,72)),
        "beard": "thin", "beard_c": (52,42,32),
        "expression": "calm",
        "extras": ["bamboo_scroll"],
    },

    # ── 将领 ──
    "portrait_general_商鞅": {
        "name": "商鞅",
        "desc": "卫国人，入秦变法。法家代表，统一度量衡，废井田开阡陌。车裂而死。",
        "bg_top": (145,128,98), "bg_bot": (108,92,68), "bg_pattern": "grid",
        "skin": ((195,165,135),(165,135,105),(215,185,155)),
        "crown": ("tall", (28,25,22), (130,100,55)),
        "robe": {"shoulder":125,"waist":98,"hem":175,
                 "main":(28,25,22),"dark":(38,34,30),"mid":(50,45,38),"accent":(85,30,20)},
        "belt": ((40,35,28),(120,85,45)),
        "beard": "short", "beard_c": (50,40,30),
        "expression": "stern",
        "extras": ["bamboo_scroll_left","sword_right"],
    },
    "portrait_general_白起": {
        "name": "白起",
        "desc": "秦国人，战神。长平之战坑杀赵卒四十万。人屠，从无败绩。",
        "bg_top": (160,140,110), "bg_bot": (120,100,75), "bg_pattern": "none",
        "skin": ((188,158,128),(158,128,100),(210,180,150)),
        "crown": ("war", (35,30,25), (130,100,55)),
        "robe": {"shoulder":140,"waist":112,"hem":190,
                 "main":(35,30,25),"dark":(28,24,20),"mid":(48,42,35),"accent":(130,100,55)},
        "belt": ((35,30,25),(130,100,55)),
        "beard": "straggly", "beard_c": (40,32,22),
        "expression": "stern",
        "extras": ["armor_plates","sword_right","cape_dark"],
    },
    "portrait_general_王翦": {
        "name": "王翦",
        "desc": "秦国人，老将。灭赵、燕、楚三国。善用兵，知进退。",
        "bg_top": (150,132,105), "bg_bot": (112,95,72), "bg_pattern": "none",
        "skin": ((185,158,130),(160,132,105),(205,178,150)),
        "crown": ("war", (42,38,32), (140,115,65)),
        "robe": {"shoulder":135,"waist":108,"hem":185,
                 "main":(42,38,32),"dark":(35,30,25),"mid":(55,48,40),"accent":(140,115,65)},
        "belt": ((42,38,32),(140,115,65)),
        "beard": "long", "beard_c": (75,65,50),
        "expression": "calm",
        "extras": ["armor_light","halberd_right"],
    },
    "portrait_general_蒙恬": {
        "name": "蒙恬",
        "desc": "秦国人，北击匈奴，收河南地。筑长城，修直道。",
        "bg_top": (155,138,108), "bg_bot": (118,100,78), "bg_pattern": "none",
        "skin": ((190,162,135),(162,135,108),(212,185,158)),
        "crown": ("war", (38,34,28), (135,108,60)),
        "robe": {"shoulder":138,"waist":110,"hem":188,
                 "main":(38,34,28),"dark":(30,28,22),"mid":(52,46,38),"accent":(135,108,60)},
        "belt": ((38,34,28),(135,108,60)),
        "beard": "short", "beard_c": (48,40,30),
        "expression": "proud",
        "extras": ["armor_plates","bow_right"],
    },
    "portrait_general_李牧": {
        "name": "李牧",
        "desc": "赵国人，守边名将。大破匈奴，抗秦有功。被反间计害死。",
        "bg_top": (148,130,100), "bg_bot": (110,95,70), "bg_pattern": "none",
        "skin": ((192,165,138),(165,138,110),(215,188,160)),
        "crown": ("war", (55,48,38), (145,118,68)),
        "robe": {"shoulder":136,"waist":108,"hem":185,
                 "main":(55,48,38),"dark":(42,38,28),"mid":(68,60,48),"accent":(145,118,68)},
        "belt": ((50,42,32),(145,118,68)),
        "beard": "short", "beard_c": (45,38,28),
        "expression": "stern",
        "extras": ["armor_plates","sword_right"],
    },
    "portrait_general_廉颇": {
        "name": "廉颇",
        "desc": "赵国人，老将。负荆请罪，与蔺相如为刎颈之交。",
        "bg_top": (152,135,105), "bg_bot": (115,98,72), "bg_pattern": "none",
        "skin": ((185,155,128),(155,128,100),(205,175,148)),
        "crown": ("war", (48,42,35), (140,112,62)),
        "robe": {"shoulder":142,"waist":115,"hem":195,
                 "main":(48,42,35),"dark":(38,32,25),"mid":(62,55,45),"accent":(140,112,62)},
        "belt": ((48,42,35),(140,112,62)),
        "beard": "long", "beard_c": (80,70,55),
        "expression": "proud",
        "extras": ["armor_plates","halberd_right"],
    },
    "portrait_general_赵奢": {
        "name": "赵奢",
        "desc": "赵国人，马服君。阏与之战大破秦军。赵括之父。",
        "bg_top": (145,128,98), "bg_bot": (108,92,68), "bg_pattern": "none",
        "skin": ((190,160,132),(160,132,105),(210,180,152)),
        "crown": ("war", (50,44,36), (142,115,65)),
        "robe": {"shoulder":134,"waist":106,"hem":182,
                 "main":(50,44,36),"dark":(40,35,28),"mid":(65,56,46),"accent":(142,115,65)},
        "belt": ((48,40,32),(142,115,65)),
        "beard": "short", "beard_c": (48,40,30),
        "expression": "stern",
        "extras": ["armor_light","sword_right"],
    },
    "portrait_general_吴起": {
        "name": "吴起",
        "desc": "卫国人，兵家亚圣。仕鲁、魏、楚三国。变法强楚，被乱箭射死。",
        "bg_top": (138,125,100), "bg_bot": (100,88,68), "bg_pattern": "diagonal",
        "skin": ((192,165,138),(165,138,110),(215,188,162)),
        "crown": ("scholar", (35,32,28), (135,108,58)),
        "robe": {"shoulder":130,"waist":102,"hem":178,
                 "main":(35,32,28),"dark":(28,25,20),"mid":(48,42,35),"accent":(100,35,25)},
        "belt": ((38,32,26),(135,108,58)),
        "beard": "short", "beard_c": (45,38,28),
        "expression": "stern",
        "extras": ["armor_light","sword_left"],
    },
    "portrait_general_孙膑": {
        "name": "孙膑",
        "desc": "齐国人，孙武之后。被庞涓陷害受膑刑。围魏救赵，马陵之战复仇。",
        "bg_top": (150,135,108), "bg_bot": (112,98,75), "bg_pattern": "dots",
        "skin": ((190,162,135),(162,135,108),(210,182,155)),
        "crown": ("scholar", (42,38,32), (130,105,55)),
        "robe": {"shoulder":120,"waist":95,"hem":165,
                 "main":(42,38,32),"dark":(32,28,22),"mid":(55,48,40),"accent":(130,105,55)},
        "belt": ((40,35,28),(130,105,55)),
        "beard": "short", "beard_c": (48,40,30),
        "expression": "calm",
        "extras": ["bamboo_scroll_left"],
    },
    "portrait_general_庞涓": {
        "name": "庞涓",
        "desc": "魏国人，鬼谷子弟子。嫉贤妒能，害孙膑。马陵之战兵败自刎。",
        "bg_top": (125,115,95), "bg_bot": (88,78,62), "bg_pattern": "none",
        "skin": ((188,160,132),(160,132,105),(208,180,152)),
        "crown": ("war", (45,40,35), (135,110,62)),
        "robe": {"shoulder":132,"waist":105,"hem":180,
                 "main":(45,40,35),"dark":(35,30,25),"mid":(58,52,42),"accent":(135,110,62)},
        "belt": ((42,38,30),(135,110,62)),
        "beard": "short", "beard_c": (42,35,25),
        "expression": "stern",
        "extras": ["armor_plates","sword_right"],
    },
    "portrait_general_乐毅": {
        "name": "乐毅",
        "desc": "燕国人，下齐七十余城。后奔赵，燕惠王悔。",
        "bg_top": (142,125,98), "bg_bot": (105,90,68), "bg_pattern": "none",
        "skin": ((192,165,138),(165,138,110),(215,188,162)),
        "crown": ("scholar", (50,48,42), (140,115,65)),
        "robe": {"shoulder":128,"waist":100,"hem":172,
                 "main":(50,48,42),"dark":(38,36,30),"mid":(62,58,50),"accent":(140,115,65)},
        "belt": ((45,42,35),(140,115,65)),
        "beard": "short", "beard_c": (50,42,32),
        "expression": "calm",
        "extras": ["sword_right"],
    },
    "portrait_general_田单": {
        "name": "田单",
        "desc": "齐国人，火牛阵复齐七十余城。以即墨一城复国。",
        "bg_top": (148,132,102), "bg_bot": (110,95,70), "bg_pattern": "none",
        "skin": ((190,162,135),(162,135,108),(212,185,158)),
        "crown": ("war", (48,42,35), (138,112,62)),
        "robe": {"shoulder":130,"waist":102,"hem":178,
                 "main":(48,42,35),"dark":(38,32,28),"mid":(60,52,42),"accent":(138,112,62)},
        "belt": ((45,38,30),(138,112,62)),
        "beard": "short", "beard_c": (45,38,28),
        "expression": "proud",
        "extras": ["armor_light","sword_right"],
    },
    "portrait_general_信陵君": {
        "name": "信陵君魏无忌",
        "desc": "魏国人，战国四公子之首。窃符救赵，礼贤下士。门客三千。",
        "bg_top": (135,122,100), "bg_bot": (98,85,68), "bg_pattern": "diagonal",
        "skin": ((195,168,140),(168,140,112),(218,192,165)),
        "crown": ("scholar", (45,42,38), (150,130,75)),
        "robe": {"shoulder":128,"waist":100,"hem":172,
                 "main":(45,42,38),"dark":(35,32,28),"mid":(58,55,48),"accent":(150,130,75)},
        "belt": ((42,38,32),(150,130,75)),
        "beard": "none", "beard_c": (0,0,0),
        "expression": "smile",
        "extras": ["jade_pendant","fan"],
    },
    "portrait_general_春申君": {
        "name": "春申君黄歇",
        "desc": "楚国人，战国四公子。相楚二十余年，门客三千。",
        "bg_top": (130,118,95), "bg_bot": (92,82,62), "bg_pattern": "dots",
        "skin": ((192,165,138),(165,138,110),(215,188,162)),
        "crown": ("flat", (60,28,18), (190,150,75)),
        "robe": {"shoulder":125,"waist":98,"hem":170,
                 "main":(120,32,20),"dark":(95,25,15),"mid":(145,48,28),"accent":(190,150,75)},
        "belt": ((80,28,18),(190,150,75)),
        "beard": "short", "beard_c": (50,42,32),
        "expression": "smile",
        "extras": ["jade_pendant"],
    },
    "portrait_general_项燕": {
        "name": "项燕",
        "desc": "楚国人，项羽祖父。大破秦将李信。楚虽三户，亡秦必楚。",
        "bg_top": (140,120,95), "bg_bot": (100,85,65), "bg_pattern": "none",
        "skin": ((188,160,132),(160,132,105),(208,180,152)),
        "crown": ("war", (58,28,18), (180,145,72)),
        "robe": {"shoulder":138,"waist":110,"hem":188,
                 "main":(130,35,22),"dark":(105,28,18),"mid":(155,50,30),"accent":(180,145,72)},
        "belt": ((85,30,18),(180,145,72)),
        "beard": "long", "beard_c": (60,50,38),
        "expression": "proud",
        "extras": ["armor_plates","halberd_right","cape_red"],
    },
}


# ══════════════════════════════════════════════════════════
#  生成函数
# ══════════════════════════════════════════════════════════

def generate_portrait(key, cfg):
    W, H = 1024, 1024
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    CX, CY = 512, 400

    sk = cfg["skin"]
    skin_base, skin_shadow, skin_hi = sk[0], sk[1], sk[2]

    # 1. 背景
    draw_bg_gradient(img, cfg["bg_top"], cfg["bg_bot"], cfg.get("bg_pattern","none"))

    # 2. 袍服
    r = cfg["robe"]
    draw_robe_generic(img, CX, CY, r["shoulder"], r["waist"], r["hem"],
                      r["main"], r["dark"], r["mid"], r["accent"])

    # 3. 铠甲（如有）
    if "armor_plates" in cfg.get("extras", []):
        draw_armor_plates(img, CX, CY, (80,72,60), (55,48,38), (160,140,80))
    elif "armor_light" in cfg.get("extras", []):
        draw_armor(img, CX, CY, (70,62,52), (48,42,35))

    # 4. 披风（如有）
    if "cape_gold" in cfg.get("extras", []):
        draw_cape(img, CX, CY, -1, (170,140,80), (120,95,55))
    if "cape_dark" in cfg.get("extras", []):
        draw_cape(img, CX, CY, -1, (30,28,25), (18,16,14))
    if "cape_red" in cfg.get("extras", []):
        draw_cape(img, CX, CY, -1, (140,35,22), (95,25,15))

    # 5. 腰带
    b = cfg["belt"]
    draw_belt_generic(img, CX, CY, b[0], b[1])

    # 6. 面部
    draw_face(img, CX, CY-30, skin_base, skin_shadow, skin_hi, cfg.get("expression","stern"))

    # 7. 胡须
    draw_beard(img, CX, CY-30, cfg.get("beard","short"), cfg.get("beard_c",(50,40,30)))

    # 8. 冠
    cr = cfg["crown"]
    draw_crown_generic(img, CX, CY-30, cr[0], cr[1], cr[2])

    # 9. 毛皮镶边（如有）
    if "fur_trim" in cfg.get("extras", []):
        draw_fur_trim(img, CX, CY, CY+38, CY+55, 130, (180,170,155))

    # 10. 手
    draw_hands_generic(img, CX, CY, skin_base, skin_shadow)

    # 11. 特殊道具
    extras = cfg.get("extras", [])
    if "bamboo_scroll_left" in extras:
        draw_bamboo_scroll(img, CX-250, CY+180, (180,155,110), (40,35,28))
    if "bamboo_scroll" in extras:
        draw_bamboo_scroll(img, CX-230, CY+200, (180,155,110), (40,35,28))
    if "sword_right" in extras:
        draw_sword_generic(img, CX, CY, CX+100, (165,130,75), (110,85,50), (85,65,35))
    if "sword_left" in extras:
        draw_sword_generic(img, CX, CY, CX-100, (165,130,75), (110,85,50), (85,65,35))
    if "halberd_right" in extras:
        draw_halberd(img, CX, CY, CX+180, (120,100,70), (150,130,80))
    if "bow_right" in extras:
        draw_bow(img, CX, CY, CX+170, (120,90,55), (180,170,150))
    if "fan" in extras:
        draw_fan(img, CX, CY, CX+180, (230,220,200), (140,110,70))
    if "jade_pendant" in extras:
        draw_jade_pendant(img, CX, CY, CX-80, CY+210, (120,175,135))

    # 12. 靴
    draw_boots_generic(img, CX, CY, (38,32,28))

    # 13. 像素噪点
    add_pixel_noise(img, 0.02)

    return img


# ══════════════════════════════════════════════════════════
#  主入口
# ══════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("=== 生成22个人物 1024x1024 像素风立绘 ===\n")

    for key, cfg in CHARACTERS.items():
        print(f"  生成 {cfg['name']}...")
        img = generate_portrait(key, cfg)
        save(img, "portrait", f"{key}_hires.png")

    print("\n全部完成!")
