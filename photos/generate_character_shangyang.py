"""
商鞅 1024x1024 像素风立绘
秦制法家 · 深衣高冠 · 手持竹简 · 腰佩青铜剑
"""

import os, random, math
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
random.seed(2024)

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
    r = []
    for i in range(min(len(c1), len(c2))):
        r.append(int(c1[i] + (c2[i] - c1[i]) * t))
    return tuple(r)

def gradient_v(img, x0, y0, x1, y1, c_top, c_bot):
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        c = blend(c_top, c_bot, t)
        for x in range(x0, x1 + 1):
            px(img, x, y, c)

def gradient_h(img, x0, y0, x1, y1, c_left, c_right):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            t = (x - x0) / max(1, x1 - x0)
            c = blend(c_left, c_right, t)
            px(img, x, y, c)

def add_noise(c, amount=10):
    n = random.randint(-amount, amount)
    return tuple(max(0, min(255, c[i] + n)) for i in range(3))

def draw_circle(img, cx, cy, r, color):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx)**2 + (y - cy)**2 <= r**2:
                px(img, x, y, color)

def draw_ellipse(img, cx, cy, rx, ry, color):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if ((x - cx)/rx)**2 + ((y - cy)/ry)**2 <= 1:
                px(img, x, y, color)


# ══════════════════════════════════════════════════════════
#  秦制色板
# ══════════════════════════════════════════════════════════

# 肤色
SKIN_BASE = (195, 165, 135)
SKIN_SHADOW = (165, 135, 105)
SKIN_HIGHLIGHT = (215, 185, 155)

# 秦黑深衣
ROBE_BLACK = (28, 25, 22)
ROBE_DARK = (38, 34, 30)
ROBE_MID = (50, 45, 38)
ROBE_ACCENT = (85, 30, 20)  # 暗红镶边

# 冠
CROWN_BLACK = (22, 20, 18)
CROWN_DARK = (35, 32, 28)
CROWN_ACCENT = (90, 70, 40)  # 青铜冠饰

# 竹简
BAMBOO_BASE = (180, 155, 110)
BAMBOO_DARK = (140, 115, 80)
BAMBOO_TEXT = (40, 35, 28)

# 青铜剑
BRONZE_BASE = (130, 100, 55)
BRONZE_LIGHT = (165, 130, 75)
BRONZE_DARK = (85, 65, 35)
BRONZE_HILT = (110, 85, 50)

# 腰带
BELT_DARK = (40, 35, 28)
BELT_ACCENT = (120, 85, 45)  # 青铜带扣

# 背景
BG_TOP = (45, 42, 50)
BG_BOT = (30, 28, 35)


# ══════════════════════════════════════════════════════════
#  人物绘制
# ══════════════════════════════════════════════════════════

def draw_background(img):
    """渐变背景"""
    w, h = img.size
    for y in range(h):
        t = y / h
        c = blend(BG_TOP, BG_BOT, t)
        for x in range(w):
            px(img, x, y, c)

def draw_face(img, cx, cy):
    """面部 - 正面严肃表情"""
    # 脸型轮廓（略方，秦人特征）
    face_w, face_h = 68, 82
    draw_ellipse(img, cx, cy, face_w, face_h, SKIN_BASE)

    # 下颌阴影
    for y in range(cy + 30, cy + face_h):
        for x in range(cx - face_w, cx + face_w):
            if ((x - cx)/face_w)**2 + ((y - cy)/face_h)**2 <= 1:
                t = (y - cy - 30) / (face_h - 30)
                c = img.getpixel((x, y))
                nc = blend(c, SKIN_SHADOW, t * 0.5)
                px(img, x, y, nc)

    # 左侧阴影（光从右上角来）
    for y in range(cy - face_h, cy + face_h):
        for x in range(cx - face_w, cx):
            if ((x - cx)/face_w)**2 + ((y - cy)/face_h)**2 <= 1:
                t = (cx - x) / face_w
                c = img.getpixel((x, y))
                nc = blend(c, SKIN_SHADOW, t * 0.3)
                px(img, x, y, nc)

    # 右侧高光
    for y in range(cy - face_h, cy + 20):
        for x in range(cx + 20, cx + face_w):
            if ((x - cx)/face_w)**2 + ((y - cy)/face_h)**2 <= 1:
                t = 1 - abs(y - cy + 20) / (face_h + 20)
                c = img.getpixel((x, y))
                nc = blend(c, SKIN_HIGHLIGHT, t * 0.2)
                px(img, x, y, nc)

    # 眉毛 - 浓眉，严肃
    for bx in range(cx - 38, cx - 8):
        for dy in range(-2, 1):
            by = cy - 28 + dy + int(0.3 * (bx - cx + 38))
            px(img, bx, by, (35, 30, 25))
    for bx in range(cx + 8, cx + 38):
        for dy in range(-2, 1):
            by = cy - 28 + dy + int(0.3 * (cx + 38 - bx))
            px(img, bx, by, (35, 30, 25))

    # 眼睛 - 锐利上挑
    # 左眼
    for ex in range(cx - 32, cx - 12):
        for ey in range(cy - 20, cy - 10):
            px(img, ex, ey, (255, 250, 240))
    draw_circle(img, cx - 22, cy - 16, 5, (25, 20, 15))
    px(img, cx - 23, cy - 17, (60, 50, 40))
    # 右眼
    for ex in range(cx + 12, cx + 32):
        for ey in range(cy - 20, cy - 10):
            px(img, ex, ey, (255, 250, 240))
    draw_circle(img, cx + 22, cy - 16, 5, (25, 20, 15))
    px(img, cx + 21, cy - 17, (60, 50, 40))

    # 眼睑线
    for ex in range(cx - 34, cx - 10):
        px(img, ex, cy - 22, (40, 35, 30))
    for ex in range(cx + 10, cx + 34):
        px(img, ex, cy - 22, (40, 35, 30))

    # 鼻子 - 高挺
    for ny in range(cy - 8, cy + 12):
        nx = cx + int(1.5 * math.sin((ny - cy + 8) * 0.2))
        px(img, nx, ny, SKIN_SHADOW)
        px(img, nx + 1, ny, SKIN_SHADOW)
    # 鼻翼
    px(img, cx - 5, cy + 10, SKIN_SHADOW)
    px(img, cx + 5, cy + 10, SKIN_SHADOW)

    # 嘴 - 紧抿，严肃线
    for mx in range(cx - 14, cx + 14):
        my = cy + 24
        px(img, mx, my, (155, 100, 90))
        px(img, mx, my + 1, (145, 90, 80))
    # 上唇高光
    for mx in range(cx - 10, cx + 10):
        px(img, mx, cy + 22, blend(SKIN_BASE, (170, 120, 100), 0.3))

    # 胡须 - 秦式短须
    for bx in range(cx - 20, cx + 20):
        for by in range(cy + 32, cy + 55):
            dist = abs(bx - cx)
            if dist < 18 - (by - cy - 32) * 0.3:
                if random.random() < 0.4:
                    n = random.randint(-10, 10)
                    px(img, bx, by, (55 + n, 45 + n, 35 + n))

    # 耳朵
    for ey in range(cy - 15, cy + 15):
        px(img, cx - face_w + 2, ey, SKIN_SHADOW)
        px(img, cx - face_w + 1, ey, SKIN_SHADOW)
        px(img, cx + face_w - 2, ey, SKIN_SHADOW)
        px(img, cx + face_w - 1, ey, SKIN_SHADOW)

def draw_crown(img, cx, cy):
    """秦式高冠"""
    crown_top = cy - 115
    crown_bot = cy - 70
    crown_w = 52

    # 冠身 - 梯形
    for y in range(crown_top, crown_bot):
        t = (y - crown_top) / (crown_bot - crown_top)
        w = int(28 + t * (crown_w - 28))
        for x in range(cx - w, cx + w):
            n = random.randint(-4, 4)
            shade = 0.8 + 0.2 * t
            c = tuple(int(CROWN_DARK[i] * shade + n) for i in range(3))
            px(img, x, y, c)

    # 冠顶横梁
    rect(img, cx - 30, crown_top - 4, cx + 30, crown_top + 2, CROWN_BLACK)
    # 冠饰（青铜横簪）
    rect(img, cx - 40, crown_top + 8, cx + 40, crown_top + 12, CROWN_ACCENT)
    draw_metal_sheen(img, cx - 40, crown_top + 8, cx + 40, crown_top + 12, CROWN_ACCENT)

    # 冠缨（系带）
    for y in range(crown_bot, crown_bot + 30):
        for dx in [-2, -1, 0, 1, 2]:
            x = cx - crown_w - 5 + dx + int(2 * math.sin(y * 0.15))
            px(img, x, y, ROBE_ACCENT)
            x = cx + crown_w + 5 + dx + int(2 * math.sin(y * 0.15 + 1))
            px(img, x, y, ROBE_ACCENT)

def draw_metal_sheen(img, x0, y0, x1, y1, base_color):
    cx_s, cy_s = (x0 + x1) / 2, (y0 + y1) / 2
    max_dist = math.sqrt((x1-x0)**2 + (y1-y0)**2) / 2
    if max_dist == 0: return
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dist = math.sqrt((x - cx_s)**2 + (y - cy_s)**2)
            t = dist / max_dist
            sheen = int(20 * (1 - t * t))
            n = random.randint(-3, 3)
            c = tuple(max(0, min(255, base_color[i] + sheen + n)) for i in range(3))
            px(img, x, y, c)

def draw_robe(img, cx, cy):
    """秦制深衣 - 黑色为主"""
    robe_top = cy + 45
    robe_bot = 900

    # 躯干
    shoulder_w = 130
    waist_w = 100
    hem_w = 180

    for y in range(robe_top, robe_bot):
        if y < cy + 200:
            # 上身
            t = (y - robe_top) / (cy + 200 - robe_top)
            w = int(shoulder_w + t * (waist_w - shoulder_w))
        else:
            # 下摆展开
            t = (y - cy - 200) / (robe_bot - cy - 200)
            w = int(waist_w + t * (hem_w - waist_w))

        for x in range(cx - w, cx + w):
            n = random.randint(-4, 4)
            # 中间衣缝
            if abs(x - cx) < 2:
                c = add_noise(ROBE_BLACK, 3)
            # 左侧阴影
            elif x < cx - w + 20:
                t2 = (x - cx + w) / 20
                c = blend(ROBE_DARK, ROBE_MID, t2)
                c = add_noise(c, 4)
            # 右侧高光
            elif x > cx + w - 30:
                t2 = (cx + w - x) / 30
                c = blend(ROBE_DARK, ROBE_MID, t2)
                c = add_noise(c, 4)
            else:
                c = add_noise(ROBE_DARK, 5)
            px(img, x, y, c)

    # 衣领 - 交领右衽
    for y in range(robe_top, robe_top + 80):
        # 左领
        x = cx - 20 + int(y * 0.3) - int(robe_top * 0.3)
        for dx in range(-6, 2):
            px(img, x + dx, y, add_noise(ROBE_MID, 3))
        # 右领
        x = cx + 20 - int(y * 0.3) + int(robe_top * 0.3)
        for dx in range(-2, 6):
            px(img, x + dx, y, add_noise(ROBE_MID, 3))

    # 镶边 - 暗红色
    # 领口镶边
    for y in range(robe_top, robe_top + 90):
        lx = cx - 22 + int(y * 0.3) - int(robe_top * 0.3)
        rx = cx + 22 - int(y * 0.3) + int(robe_top * 0.3)
        for dx in range(-2, 0):
            px(img, lx + dx, y, ROBE_ACCENT)
            px(img, rx + dx + 4, y, ROBE_ACCENT)

    # 下摆镶边
    for x in range(cx - hem_w, cx + hem_w):
        for dy in range(-4, 0):
            if abs(x - cx) < hem_w - 5:
                px(img, x, robe_bot + dy, ROBE_ACCENT)

    # 衣袖
    draw_sleeve(img, cx - 130, robe_top + 10, -1)  # 左袖
    draw_sleeve(img, cx + 130, robe_top + 10, 1)   # 右袖

def draw_sleeve(img, sx, sy, direction):
    """衣袖"""
    sleeve_len = 180
    sleeve_w = 55

    for y in range(sy, sy + sleeve_len):
        t = (y - sy) / sleeve_len
        w = int(sleeve_w * (1 - t * 0.3))
        for x in range(sx, sx + direction * w, direction):
            n = random.randint(-4, 4)
            if abs(x - sx) < 8:
                c = add_noise(ROBE_MID, 3)
            else:
                c = add_noise(ROBE_DARK, 5)
            px(img, x, y, c)

    # 袖口镶边
    for x in range(sx, sx + direction * int(sleeve_w * 0.7), direction):
        for dy in range(-2, 2):
            px(img, x, sy + sleeve_len + dy, ROBE_ACCENT)

def draw_hands(img, cx, cy):
    """手部 - 左手持竹简"""
    # 左手（持竹简）
    hand_x = cx - 180
    hand_y = cy + 280

    # 手掌
    for y in range(hand_y - 15, hand_y + 25):
        for x in range(hand_x - 18, hand_x + 18):
            dist = math.sqrt((x - hand_x)**2 + (y - hand_y)**2)
            if dist < 18:
                c = blend(SKIN_BASE, SKIN_SHADOW, 0.2)
                px(img, x, y, add_noise(c, 5))

    # 手指（握竹简）
    for fy in range(hand_y - 20, hand_y + 5):
        for fx in range(hand_x - 12, hand_x + 15):
            if abs(fx - hand_x) < 10:
                px(img, fx, fy, add_noise(SKIN_BASE, 4))

    # 右手（自然下垂或按剑）
    hand_r_x = cx + 160
    hand_r_y = cy + 320

    for y in range(hand_r_y - 12, hand_r_y + 20):
        for x in range(hand_r_x - 15, hand_r_x + 15):
            dist = math.sqrt((x - hand_r_x)**2 + (y - hand_r_y)**2)
            if dist < 16:
                c = blend(SKIN_BASE, SKIN_SHADOW, 0.15)
                px(img, x, y, add_noise(c, 5))

def draw_bamboo_scroll(img, cx, cy):
    """竹简 - 手持律令"""
    scroll_x = cx - 220
    scroll_y = cy + 200
    scroll_w = 60
    scroll_h = 160

    # 竹简主体
    for y in range(scroll_y, scroll_y + scroll_h):
        for x in range(scroll_x, scroll_x + scroll_w):
            n = random.randint(-8, 8)
            c = (BAMBOO_BASE[0] + n, BAMBOO_BASE[1] + n, BAMBOO_BASE[2] + n)
            c = tuple(max(0, min(255, v)) for v in c)
            px(img, x, y, c)

    # 竹简编绳（上下各一道）
    for x in range(scroll_x - 2, scroll_x + scroll_w + 2):
        for dy in range(-2, 2):
            px(img, x, scroll_y + 20 + dy, (120, 80, 40))
            px(img, x, scroll_y + scroll_h - 20 + dy, (120, 80, 40))

    # 竹简文字（竖排墨字）
    for row in range(5):
        char_y = scroll_y + 30 + row * 25
        for char_col in range(3):
            char_x = scroll_x + 10 + char_col * 16
            # 简化的汉字笔画
            for stroke in range(random.randint(3, 6)):
                sx = char_x + random.randint(-4, 4)
                sy = char_y + random.randint(-6, 6)
                px(img, sx, sy, BAMBOO_TEXT)
                px(img, sx + 1, sy, BAMBOO_TEXT)

    # 竹简卷轴端
    for y in range(scroll_y - 8, scroll_y + scroll_h + 8):
        for x in range(scroll_x - 6, scroll_x):
            dist = abs(y - (scroll_y + scroll_h / 2))
            if dist < scroll_h / 2 + 5:
                c = blend(BAMBOO_DARK, BAMBOO_BASE, 0.5)
                px(img, x, y, add_noise(c, 5))

def draw_sword(img, cx, cy):
    """青铜剑 - 腰间佩剑"""
    sword_x = cx + 100
    sword_top = cy + 120
    sword_bot = cy + 480

    # 剑鞘
    for y in range(sword_top, sword_bot):
        t = (y - sword_top) / (sword_bot - sword_top)
        w = int(8 - t * 3)  # 逐渐变窄
        for x in range(sword_x - w, sword_x + w):
            n = random.randint(-3, 3)
            c = tuple(max(0, min(255, BRONZE_DARK[i] + n)) for i in range(3))
            px(img, x, y, c)

    # 剑格（护手）
    rect(img, sword_x - 16, sword_top - 4, sword_x + 16, sword_top + 8, BRONZE_BASE)
    draw_metal_sheen(img, sword_x - 16, sword_top - 4, sword_x + 16, sword_top + 8, BRONZE_BASE)

    # 剑首
    draw_circle(img, sword_x, sword_bot + 5, 8, BRONZE_LIGHT)

    # 剑穗
    for y in range(sword_bot + 10, sword_bot + 50):
        x = sword_x + int(8 * math.sin(y * 0.1))
        px(img, x, y, ROBE_ACCENT)
        px(img, x + 1, y, ROBE_ACCENT)

def draw_belt(img, cx, cy):
    """腰带 - 青铜带扣"""
    belt_y = cy + 190
    belt_h = 18

    # 腰带主体
    for y in range(belt_y, belt_y + belt_h):
        for x in range(cx - 110, cx + 110):
            n = random.randint(-3, 3)
            c = (BELT_DARK[0] + n, BELT_DARK[1] + n, BELT_DARK[2] + n)
            px(img, x, y, tuple(max(0, min(255, v)) for v in c))

    # 带扣
    rect(img, cx - 15, belt_y - 2, cx + 15, belt_y + belt_h + 2, BELT_ACCENT)
    draw_metal_sheen(img, cx - 15, belt_y - 2, cx + 15, belt_y + belt_h + 2, BELT_ACCENT)

    # 带扣纹饰
    for dy in [-4, 0, 4]:
        px(img, cx, belt_y + belt_h // 2 + dy, (160, 130, 70))
        px(img, cx - 1, belt_y + belt_h // 2 + dy, (160, 130, 70))
        px(img, cx + 1, belt_y + belt_h // 2 + dy, (160, 130, 70))

def draw_boots(img, cx, cy):
    """秦式靴"""
    boot_y = 880

    for side in [-1, 1]:
        bx = cx + side * 80
        # 靴筒
        for y in range(boot_y - 40, boot_y):
            for x in range(bx - 22, bx + 22):
                n = random.randint(-3, 3)
                c = (35 + n, 30 + n, 25 + n)
                px(img, x, y, tuple(max(0, min(255, v)) for v in c))
        # 靴底
        for y in range(boot_y, boot_y + 8):
            for x in range(bx - 24, bx + 24):
                px(img, x, y, (20, 18, 15))

def draw_shadows(img, cx, cy):
    """人物投影"""
    # 地面投影
    for y in range(900, 950):
        for x in range(cx - 200, cx + 200):
            dist = abs(x - cx) / 200
            t = (y - 900) / 50
            alpha = max(0, 0.3 * (1 - dist) * (1 - t))
            if alpha > 0.01:
                c = img.getpixel((x, y))
                nc = blend(c, (15, 12, 10), alpha)
                px(img, x, y, nc)

def add_pixel_texture(img, x0, y0, x1, y1, density=0.05):
    """添加像素风噪点纹理"""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if random.random() < density:
                c = img.getpixel((x, y))
                n = random.randint(-8, 8)
                nc = tuple(max(0, min(255, c[i] + n)) for i in range(3))
                px(img, x, y, nc)


# ══════════════════════════════════════════════════════════
#  主生成函数
# ══════════════════════════════════════════════════════════

def generate_shangyang():
    W, H = 1024, 1024
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    CX, CY = 512, 420  # 人物中心偏上

    print("  [1/9] 背景...")
    draw_background(img)

    print("  [2/9] 投影...")
    draw_shadows(img, CX, CY)

    print("  [3/9] 衣袍...")
    draw_robe(img, CX, CY)

    print("  [4/9] 面部...")
    draw_face(img, CX, CY - 30)

    print("  [5/9] 冠...")
    draw_crown(img, CX, CY - 30)

    print("  [6/9] 手...")
    draw_hands(img, CX, CY)

    print("  [7/9] 竹简...")
    draw_bamboo_scroll(img, CX, CY)

    print("  [8/9] 剑...")
    draw_sword(img, CX, CY)

    print("  [9/9] 腰带、靴子...")
    draw_belt(img, CX, CY)
    draw_boots(img, CX, CY)

    # 像素风噪点
    add_pixel_texture(img, 0, 0, W - 1, H - 1, 0.03)

    return img


if __name__ == "__main__":
    print("=== 生成商鞅 1024x1024 像素风立绘 ===")
    img = generate_shangyang()
    save(img, "character", "char_shangyang_hires.png")
    print("\n完成!")
