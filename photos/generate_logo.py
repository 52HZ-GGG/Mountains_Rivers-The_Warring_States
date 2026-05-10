"""
《山河策》游戏Logo生成器
800x400 | 像素风 | 山河意象 | 透明背景
运行: python generate_logo.py
"""

import os, math, random
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "logo")
os.makedirs(OUT_DIR, exist_ok=True)

W, H = 800, 400

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

# ── 字体 ──
FONT_CN = "C:/Windows/Fonts/STLITI.TTF"  # 华文隶书

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


def generate_logo():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = W // 2, H // 2

    # ══════════════════════════════════════════════════════
    #  背景层：远山叠嶂
    # ══════════════════════════════════════════════════════
    # 远山（最淡）
    for x in range(W):
        h = int(280 + 30 * math.sin(x * 0.005) + 20 * math.sin(x * 0.013) + 15 * math.sin(x * 0.03))
        for y in range(h, H):
            t = (y - h) / (H - h)
            c = (int(50 + t * 15), int(60 + t * 15), int(50 + t * 10))
            alpha = max(30, int(80 - t * 40))
            d.point((x, y), fill=(*c, alpha))

    # 中山
    for x in range(W):
        h = int(300 + 40 * math.sin(x * 0.008 + 1) + 25 * math.sin(x * 0.02 + 2))
        for y in range(h, H):
            t = (y - h) / (H - h)
            c = (int(40 + t * 20), int(50 + t * 20), int(40 + t * 15))
            alpha = max(40, int(100 - t * 50))
            d.point((x, y), fill=(*c, alpha))

    # 近山（最深）
    for x in range(W):
        h = int(320 + 35 * math.sin(x * 0.01 + 3) + 20 * math.sin(x * 0.025 + 1))
        for y in range(h, H):
            t = (y - h) / (H - h)
            c = (int(30 + t * 15), int(38 + t * 15), int(30 + t * 10))
            alpha = max(60, int(140 - t * 60))
            d.point((x, y), fill=(*c, alpha))

    # ══════════════════════════════════════════════════════
    #  河流：蜿蜒穿过
    # ══════════════════════════════════════════════════════
    for x in range(W):
        t = x / W
        river_y = int(310 + 20 * math.sin(t * math.pi * 3 + 0.5) + 10 * math.sin(t * math.pi * 7))
        for dy in range(-4, 5):
            y = river_y + dy
            if 0 <= y < H:
                alpha = max(40, 120 - abs(dy) * 25)
                c = (60, 90, 130) if abs(dy) < 2 else (50, 75, 110)
                d.point((x, y), fill=(*c, alpha))
                if abs(dy) < 2:
                    d.point((x, y+1), fill=(*c, alpha // 2))

    # 河面波光
    random.seed(101)
    for _ in range(60):
        wx = random.randint(50, W - 50)
        wy = int(310 + 20 * math.sin((wx / W) * math.pi * 3 + 0.5))
        for s in range(random.randint(5, 15)):
            if 0 <= wx + s < W:
                alpha = max(30, 100 - s * 8)
                d.point((wx + s, wy), fill=(100, 140, 180, alpha))

    # ══════════════════════════════════════════════════════
    #  城墙剪影（左侧）
    # ══════════════════════════════════════════════════════
    # 城墙基座
    pb(d, 40, 280, 120, 40, (35, 40, 38, 180))
    # 城垛
    for x in range(40, 160, 16):
        pb(d, x, 272, 10, 10, (35, 40, 38, 200))
    # 城楼
    pb(d, 80, 250, 40, 32, (35, 40, 38, 200))
    d.polygon([(76, 250), (100, 232), (124, 250)], fill=(35, 40, 38, 200))
    # 城门
    d.arc([90, 290, 110, 310], 180, 360, fill=(25, 28, 26, 200), width=2)

    # ══════════════════════════════════════════════════════
    #  旌旗（右侧）
    # ══════════════════════════════════════════════════════
    # 旗杆
    pb(d, 680, 220, 3, 100, (*BRO_H, 180))
    # 旗面（飘动）
    for i in range(25):
        wave = int(4 * math.sin(i * 0.4))
        pb(d, 683, 225 + i, 30 + wave, 1, (*LAC, max(100, 180 - i * 4)))
        pb(d, 683, 226 + i, 25 + wave, 1, (*LAC_H, max(80, 160 - i * 4)))
    # 旗杆尖
    d.polygon([(679, 220), (682, 210), (684, 220)], fill=(*BAM_H, 200))

    # 另一面旗
    pb(d, 720, 235, 3, 85, (*BRO_H, 160))
    for i in range(20):
        wave = int(3 * math.sin(i * 0.5 + 1))
        pb(d, 723, 240 + i, 25 + wave, 1, (*BRO, max(80, 150 - i * 4)))

    # ══════════════════════════════════════════════════════
    #  七国徽记（底部装饰带）
    # ══════════════════════════════════════════════════════
    # 底部横带
    pb(d, 100, 350, 600, 3, (*BAM_D, 140))
    pb(d, 120, 356, 560, 2, (*BAM_D, 100))
    # 七个小圆点代表七国
    for i in range(7):
        x = 200 + i * 60
        d.ellipse([x-4, 348, x+4, 356], fill=(*BAM_H, 160))
        d.point((x-1, 350), fill=(*BAM, 200))

    # ══════════════════════════════════════════════════════
    #  主标题：山河策
    # ══════════════════════════════════════════════════════
    # 阴影
    draw_text_centered(d, cx + 3, 133, "山河策", FONT_CN, 100, (15, 15, 15, 120))
    # 主字
    draw_text_centered(d, cx, 130, "山河策", FONT_CN, 100, (*BAM_H, 240))
    # 描边效果（上下左右微偏）
    for dx, dy in [(-2,0),(2,0),(0,-2),(0,2)]:
        draw_text_centered(d, cx+dx, 130+dy, "山河策", FONT_CN, 100, (*BAM_S, 80))

    # ══════════════════════════════════════════════════════
    #  副标题：WARRING STATES
    # ══════════════════════════════════════════════════════
    font_en = ImageFont.truetype("C:/Windows/Fonts/STLITI.TTF", 24)
    en_text = "WARRING STATES"
    bbox = font_en.getbbox(en_text)
    tw = bbox[2] - bbox[0]
    en_x = cx - tw // 2
    en_y = 210
    # 英文阴影
    d.text((en_x + 1, en_y + 1), en_text, font=font_en, fill=(15, 15, 15, 100))
    # 英文主字
    d.text((en_x, en_y), en_text, font=font_en, fill=(*BAM, 200))

    # ══════════════════════════════════════════════════════
    #  装饰元素
    # ══════════════════════════════════════════════════════
    # 左右装饰线
    pb(d, 140, 125, 100, 2, (*BAM_S, 120))
    pb(d, 560, 125, 100, 2, (*BAM_S, 120))
    pb(d, 160, 130, 60, 1, (*BAM_S, 80))
    pb(d, 580, 130, 60, 1, (*BAM_S, 80))

    # 左右角饰
    for ax, ay in [(130, 100), (670, 100)]:
        d.ellipse([ax-5, ay-5, ax+5, ay+5], fill=(*BAM_H, 160))
        d.point((ax-2, ay-2), fill=(*BAM, 200))

    # 顶部横线
    pb(d, 200, 60, 400, 2, (*BAM_D, 80))

    # 青铜纹饰（标题下方）
    for i in range(11):
        x = 280 + i * 24
        d.arc([x, 185, x+12, 195], 0, 180, fill=(*BAM_S, 100), width=1)

    save(img, "logo_shanhece")


def generate_all():
    print("=== 《山河策》Logo生成器 ===\n")
    generate_logo()
    print(f"\n=== 完成！ ===")
    print(f"输出: {OUT_DIR}")
    print("规格: 800x400 | 像素风 | 透明背景")
    print("\n请在本地查看 logo/ 目录即可。")

if __name__ == "__main__":
    generate_all()
