"""
《山河策》城市图块精细重制 - 纯像素硬边，无抗锯齿
每个像素手动绘制，确保清晰锐利
"""

import os, random
from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))

def save(img, *parts):
    p = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)
    print(f"  [OK] {os.path.relpath(p, ROOT)}")

def px(img, x, y, color):
    """安全写入单像素"""
    w, h = img.size
    if 0 <= x < w and 0 <= y < h:
        img.putpixel((x, y), color)

def rect(img, x0, y0, x1, y1, color):
    """硬边矩形填充"""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, color)

def line_h(img, x0, x1, y, color):
    """水平线"""
    for x in range(x0, x1 + 1):
        px(img, x, y, color)

def line_v(img, x0, y0, y1, color):
    """垂直线"""
    for y in range(y0, y1 + 1):
        px(img, x0, y, color)

# ── 色板 ─────────────────────────────────────────────────
# 秦 - 漆红
QIN = {
    "wall":    (140, 69, 34),
    "wall_h":  (176, 93, 59),
    "wall_s":  (102, 48, 24),
    "roof":    (64, 29, 15),
    "roof_h":  (90, 42, 20),
    "door":    (26, 26, 27),
    "gold":    (197, 163, 104),
    "gold_h":  (217, 190, 139),
    "flag":    (180, 45, 35),
    "flag_h":  (220, 75, 55),
}

# 赵 - 铜靛
ZHAO = {
    "wall":    (43, 51, 48),
    "wall_h":  (69, 82, 77),
    "wall_s":  (26, 33, 30),
    "roof":    (13, 18, 16),
    "roof_h":  (35, 42, 38),
    "door":    (0, 0, 0),
    "gold":    (153, 122, 74),
    "gold_h":  (197, 163, 104),
    "flag":    (55, 85, 130),
    "flag_h":  (80, 115, 160),
}

# 齐 - 苍绿
QI = {
    "wall":    (55, 90, 55),
    "wall_h":  (78, 115, 78),
    "wall_s":  (38, 62, 38),
    "roof":    (22, 40, 22),
    "roof_h":  (45, 68, 45),
    "door":    (13, 18, 16),
    "gold":    (197, 163, 104),
    "gold_h":  (230, 200, 140),
    "flag":    (197, 163, 104),
    "flag_h":  (230, 200, 140),
}

# 楚 - 竹黄
CHU = {
    "wall":    (197, 163, 104),
    "wall_h":  (217, 190, 139),
    "wall_s":  (153, 122, 74),
    "roof":    (102, 82, 49),
    "roof_h":  (140, 110, 70),
    "door":    (64, 29, 15),
    "gold":    (180, 45, 35),
    "gold_h":  (220, 75, 55),
    "flag":    (140, 69, 34),
    "flag_h":  (176, 93, 59),
}

# 魏 - 墨黑
WEI = {
    "wall":    (26, 26, 27),
    "wall_h":  (51, 51, 52),
    "wall_s":  (13, 13, 14),
    "roof":    (0, 0, 0),
    "roof_h":  (20, 20, 21),
    "door":    (0, 0, 0),
    "gold":    (197, 163, 104),
    "gold_h":  (240, 210, 140),
    "flag":    (197, 163, 104),
    "flag_h":  (240, 210, 140),
}

# 燕 - 青灰
YAN = {
    "wall":    (100, 110, 120),
    "wall_h":  (135, 145, 155),
    "wall_s":  (70, 78, 88),
    "roof":    (45, 50, 58),
    "roof_h":  (72, 80, 90),
    "door":    (20, 22, 25),
    "gold":    (153, 122, 74),
    "gold_h":  (197, 163, 104),
    "flag":    (140, 69, 34),
    "flag_h":  (176, 93, 59),
}

# 韩 - 夕橙
HAN = {
    "wall":    (200, 120, 50),
    "wall_h":  (240, 160, 80),
    "wall_s":  (155, 85, 30),
    "roof":    (100, 55, 18),
    "roof_h":  (140, 80, 35),
    "door":    (50, 28, 10),
    "gold":    (197, 163, 104),
    "gold_h":  (230, 200, 140),
    "flag":    (26, 33, 30),
    "flag_h":  (43, 51, 48),
}

# ── 通用城市绘制 ─────────────────────────────────────────

def draw_city_base(img, pal, variant="standard"):
    """绘制 64x64 城市基础结构"""
    # 地基阴影
    rect(img, 8, 55, 55, 58, (0, 0, 0, 60))
    rect(img, 10, 57, 53, 60, (0, 0, 0, 40))

    # === 城墙主体 ===
    # 左墙
    rect(img, 8, 28, 14, 54, pal["wall"])
    rect(img, 9, 29, 11, 52, pal["wall_h"])  # 高光
    rect(img, 13, 29, 14, 52, pal["wall_s"])  # 阴影

    # 右墙
    rect(img, 49, 28, 55, 54, pal["wall"])
    rect(img, 52, 29, 54, 52, pal["wall_h"])
    rect(img, 49, 29, 50, 52, pal["wall_s"])

    # 中墙
    rect(img, 15, 32, 48, 54, pal["wall"])
    rect(img, 16, 33, 22, 52, pal["wall_h"])
    rect(img, 41, 33, 47, 52, pal["wall_s"])

    # 城墙顶部雉堞
    for bx in range(8, 56, 4):
        rect(img, bx, 26, bx + 2, 28, pal["wall_h"])

    # === 城门 ===
    rect(img, 27, 38, 36, 54, pal["door"])
    # 门洞拱形 (像素弧)
    px(img, 28, 37, pal["door"])
    px(img, 29, 36, pal["door"])
    px(img, 30, 36, pal["door"])
    px(img, 31, 35, pal["door"])
    px(img, 32, 35, pal["door"])
    px(img, 33, 36, pal["door"])
    px(img, 34, 36, pal["door"])
    px(img, 35, 37, pal["door"])
    # 门钉
    px(img, 30, 42, pal["gold"])
    px(img, 33, 42, pal["gold"])
    px(img, 30, 47, pal["gold"])
    px(img, 33, 47, pal["gold"])
    # 门框
    line_v(img, 27, 38, 54, pal["gold"])
    line_v(img, 36, 38, 54, pal["gold"])

    # === 中央城楼 ===
    rect(img, 20, 14, 43, 32, pal["wall"])
    rect(img, 21, 15, 28, 30, pal["wall_h"])
    rect(img, 36, 15, 42, 30, pal["wall_s"])

    # 城楼窗户
    rect(img, 26, 20, 29, 24, pal["door"])
    rect(img, 34, 20, 37, 24, pal["door"])
    # 窗框高光
    px(img, 26, 20, pal["gold"])
    px(img, 29, 20, pal["gold"])
    px(img, 34, 20, pal["gold"])
    px(img, 37, 20, pal["gold"])

    # 城楼门
    rect(img, 29, 26, 34, 32, pal["door"])

    # === 屋顶 (尖顶) ===
    # 主屋顶
    for i in range(10):
        y = 14 - i
        x_left = 31 - i - 1
        x_right = 32 + i + 1
        if y >= 3:
            rect(img, x_left, y, x_right, y, pal["roof"])
    # 屋顶高光 (左侧亮)
    for i in range(10):
        y = 14 - i
        x_left = 31 - i - 1
        if y >= 3 and x_left >= 20:
            px(img, x_left, y, pal["roof_h"])
            px(img, x_left + 1, y, pal["roof_h"])

    # 屋脊装饰
    px(img, 31, 3, pal["gold"])
    px(img, 32, 3, pal["gold"])
    px(img, 31, 2, pal["gold_h"])
    px(img, 32, 2, pal["gold_h"])
    # 宝顶
    px(img, 31, 1, pal["gold_h"])
    px(img, 32, 1, pal["gold_h"])
    px(img, 31, 0, pal["flag"])
    px(img, 32, 0, pal["flag"])

    # 屋檐翘角
    px(img, 19, 14, pal["roof_h"])
    px(img, 18, 13, pal["roof_h"])
    px(img, 44, 14, pal["roof_h"])
    px(img, 45, 13, pal["roof_h"])

    # 飞檐装饰 (小三角)
    px(img, 17, 13, pal["gold"])
    px(img, 46, 13, pal["gold"])

    return img


def draw_city_friendly(pal):
    """我方城市"""
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_city_base(img, pal)

    # 己方旗帜 (左侧)
    line_v(img, 4, 10, 25, pal["gold"])
    rect(img, 5, 10, 12, 16, pal["flag"])
    rect(img, 6, 11, 11, 15, pal["flag_h"])
    # 旗上文字 (简笔)
    px(img, 8, 12, pal["gold"])
    px(img, 9, 13, pal["gold"])

    # 己方旗帜 (右侧)
    line_v(img, 58, 10, 25, pal["gold"])
    rect(img, 50, 10, 57, 16, pal["flag"])
    rect(img, 51, 11, 56, 15, pal["flag_h"])
    px(img, 53, 12, pal["gold"])
    px(img, 54, 13, pal["gold"])

    # 城前卫兵
    rect(img, 18, 48, 20, 54, pal["wall_h"])
    px(img, 18, 47, pal["gold"])
    px(img, 19, 46, pal["gold"])
    px(img, 20, 47, pal["gold"])

    rect(img, 43, 48, 45, 54, pal["wall_h"])
    px(img, 43, 47, pal["gold"])
    px(img, 44, 46, pal["gold"])
    px(img, 45, 47, pal["gold"])

    return img


def draw_city_enemy(pal):
    """敌方城市"""
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_city_base(img, pal)

    # 敌方旗帜 (黑旗)
    line_v(img, 4, 10, 25, (80, 80, 80))
    rect(img, 5, 10, 12, 16, (30, 30, 30))
    rect(img, 6, 11, 11, 15, (50, 50, 50))
    px(img, 8, 12, (180, 45, 35))
    px(img, 9, 13, (180, 45, 35))

    line_v(img, 58, 10, 25, (80, 80, 80))
    rect(img, 50, 10, 57, 16, (30, 30, 30))
    rect(img, 51, 11, 56, 15, (50, 50, 50))
    px(img, 53, 12, (180, 45, 35))
    px(img, 54, 13, (180, 45, 35))

    # 城墙破损痕迹
    px(img, 15, 40, pal["wall_s"])
    px(img, 16, 39, pal["wall_s"])
    px(img, 16, 41, pal["door"])
    px(img, 15, 42, pal["door"])

    # 烽火烟
    for sx, sy in [(12, 8), (13, 6), (11, 5), (14, 4), (13, 3)]:
        px(img, sx, sy, (80, 80, 80, 150))
    for sx, sy in [(50, 8), (51, 6), (49, 5), (52, 4), (51, 3)]:
        px(img, sx, sy, (80, 80, 80, 150))

    return img


def draw_city_capital(pal, kingdom_char):
    """都城 - 更大更精致"""
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))

    # 地基
    rect(img, 4, 56, 59, 60, (0, 0, 0, 50))
    rect(img, 6, 58, 57, 61, (0, 0, 0, 30))

    # === 外城墙 ===
    rect(img, 4, 30, 59, 55, pal["wall"])
    rect(img, 5, 31, 12, 53, pal["wall_h"])
    rect(img, 51, 31, 58, 53, pal["wall_s"])

    # 雉堞
    for bx in range(4, 60, 3):
        rect(img, bx, 28, bx + 1, 30, pal["wall_h"])

    # === 主城门 (更大) ===
    rect(img, 24, 36, 39, 55, pal["door"])
    # 拱门
    px(img, 25, 35, pal["door"])
    px(img, 26, 34, pal["door"])
    px(img, 27, 33, pal["door"])
    px(img, 28, 33, pal["door"])
    px(img, 29, 32, pal["door"])
    px(img, 30, 32, pal["door"])
    px(img, 31, 32, pal["door"])
    px(img, 32, 32, pal["door"])
    px(img, 33, 32, pal["door"])
    px(img, 34, 33, pal["door"])
    px(img, 35, 33, pal["door"])
    px(img, 36, 34, pal["door"])
    px(img, 37, 35, pal["door"])
    px(img, 38, 35, pal["door"])
    # 门钉 (两排)
    for dy in [0, 6]:
        px(img, 28, 40 + dy, pal["gold"])
        px(img, 31, 40 + dy, pal["gold"])
        px(img, 35, 40 + dy, pal["gold"])
    # 门框
    line_v(img, 24, 36, 55, pal["gold"])
    line_v(img, 39, 36, 55, pal["gold"])
    line_h(img, 24, 39, 36, pal["gold"])

    # === 内城楼 ===
    rect(img, 16, 16, 47, 32, pal["wall"])
    rect(img, 17, 17, 24, 30, pal["wall_h"])
    rect(img, 39, 17, 46, 30, pal["wall_s"])

    # 内城窗户 (三窗)
    for wx in [21, 29, 37]:
        rect(img, wx, 20, wx + 2, 24, pal["door"])
        px(img, wx, 20, pal["gold"])
        px(img, wx + 2, 20, pal["gold"])

    # 内城门
    rect(img, 28, 26, 35, 32, pal["door"])

    # === 主屋顶 (双层) ===
    # 下层
    for i in range(8):
        y = 16 - i
        x_left = 31 - i - 2
        x_right = 32 + i + 2
        if y >= 7:
            rect(img, x_left, y, x_right, y, pal["roof"])
    for i in range(8):
        y = 16 - i
        x_left = 31 - i - 2
        if y >= 7:
            px(img, x_left, y, pal["roof_h"])
            px(img, x_left + 1, y, pal["roof_h"])

    # 上层小屋顶
    for i in range(5):
        y = 7 - i
        x_left = 31 - i
        x_right = 32 + i
        if y >= 1:
            rect(img, x_left, y, x_right, y, pal["roof"])
    for i in range(5):
        y = 7 - i
        x_left = 31 - i
        if y >= 1:
            px(img, x_left, y, pal["roof_h"])

    # 宝顶
    px(img, 31, 0, pal["gold_h"])
    px(img, 32, 0, pal["gold_h"])

    # 飞檐翘角 (四个方向)
    for dx, dy in [(-12, 8), (12, 8), (-8, 0), (8, 0)]:
        cx, cy = 32 + dx, 16 + dy
        px(img, cx, cy, pal["roof_h"])
        px(img, cx + (-1 if dx < 0 else 1), cy - 1, pal["roof_h"])
        px(img, cx + (-2 if dx < 0 else 2), cy - 1, pal["gold"])

    # === 都城旗帜 (更大更显眼) ===
    line_v(img, 2, 8, 28, pal["gold"])
    rect(img, 3, 8, 13, 17, pal["flag"])
    rect(img, 4, 9, 12, 16, pal["flag_h"])
    # 旗帜内国名
    px(img, 7, 11, pal["gold"])
    px(img, 8, 12, pal["gold"])
    px(img, 9, 13, pal["gold"])

    line_v(img, 61, 8, 28, pal["gold"])
    rect(img, 50, 8, 60, 17, pal["flag"])
    rect(img, 51, 9, 59, 16, pal["flag_h"])
    px(img, 54, 11, pal["gold"])
    px(img, 55, 12, pal["gold"])
    px(img, 56, 13, pal["gold"])

    # === 城前装饰 ===
    # 左鼓楼
    rect(img, 7, 46, 13, 55, pal["wall_s"])
    rect(img, 8, 47, 12, 54, pal["wall"])
    px(img, 10, 49, pal["gold"])
    # 右钟楼
    rect(img, 50, 46, 56, 55, pal["wall_s"])
    rect(img, 51, 47, 55, 54, pal["wall"])
    px(img, 53, 49, pal["gold"])

    return img


# ── 生成所有城市 ─────────────────────────────────────────

if __name__ == "__main__":
    random.seed(42)

    print("=== 基础城市 (64x64) ===")
    save(draw_city_friendly(QIN), "city", "city_friendly.png")
    save(draw_city_enemy(ZHAO), "city", "city_enemy.png")

    print("\n=== 七国都城 (64x64) ===")
    capitals = [
        ("qin",  QIN,  "秦"), ("zhao", ZHAO, "赵"), ("qi",   QI,   "齐"),
        ("chu",  CHU,  "楚"), ("wei",  WEI,  "魏"), ("yan",  YAN,  "燕"),
        ("han",  HAN,  "韩"),
    ]
    for key, pal, char in capitals:
        img = draw_city_capital(pal, char)
        save(img, "city", f"city_capital_{key}.png")

    print("\n完成! 城市图块已重制。")
