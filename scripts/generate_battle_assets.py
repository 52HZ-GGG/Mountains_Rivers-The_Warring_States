#!/usr/bin/env python3
"""
《山河策》战斗内图片资产生成脚本
严格遵循 artline1.md (V3.1) 规范：
- 2.5D 尖顶六角形，底部 6px 物理厚度
- 战国色谱，饱和度 < 40%
- Bayer 4x4 有序抖动
- 手动抗锯齿
- 16 色限制
"""

import os
import random
import math
from PIL import Image, ImageDraw

# ============================================================
# 战国物料色坡 (Warring States Material Ramps)
# ============================================================
COLOR_RAMPS = {
    "lacquer_red": {  # 漆器红 - 战争、铁血、秦制
        "base": (140, 69, 34),
        "high": (176, 93, 59),
        "shadow": (102, 48, 24),
        "deep": (64, 29, 15),
    },
    "bronze_indigo": {  # 青铜靛 - 权谋、肃穆、燕赵
        "base": (43, 51, 48),
        "high": (69, 82, 77),
        "shadow": (26, 33, 30),
        "deep": (13, 18, 16),
    },
    "bamboo_yellow": {  # 竹简黄 - 历史、外交、齐鲁
        "base": (197, 163, 104),
        "high": (217, 190, 139),
        "shadow": (153, 122, 74),
        "deep": (102, 82, 49),
    },
    "ink_black": {  # 水墨黑 - 宣纸意境、楚风
        "base": (26, 26, 27),
        "high": (51, 51, 52),
        "shadow": (13, 13, 14),
        "deep": (0, 0, 0),
    },
    "jade_green": {  # 青玉绿 - 森林、自然
        "base": (58, 74, 52),
        "high": (78, 98, 68),
        "shadow": (38, 50, 34),
        "deep": (22, 32, 18),
    },
    "earth_brown": {  # 泥土棕 - 平原、厚度层
        "base": (128, 102, 68),
        "high": (158, 130, 90),
        "shadow": (98, 76, 48),
        "deep": (68, 50, 30),
    },
    "water_blue": {  # 水靛蓝 - 河流、水系
        "base": (48, 72, 96),
        "high": (68, 96, 124),
        "shadow": (30, 50, 70),
        "deep": (18, 32, 48),
    },
    "stone_gray": {  # 石灰 - 山地、岩石
        "base": (108, 104, 96),
        "high": (136, 130, 120),
        "shadow": (80, 76, 68),
        "deep": (52, 48, 42),
    },
    "gold_accent": {  # 金色点缀 - 王旗、将领
        "base": (196, 168, 82),
        "high": (224, 200, 112),
        "shadow": (156, 130, 56),
        "deep": (116, 92, 36),
    },
}

# 国家配色
FACTION_COLORS = {
    "qin": {"primary": "lacquer_red", "accent": "ink_black"},
    "chu": {"primary": "ink_black", "accent": "gold_accent"},
    "yan": {"primary": "bronze_indigo", "accent": "water_blue"},
    "zhao": {"primary": "bronze_indigo", "accent": "lacquer_red"},
    "wei": {"primary": "bamboo_yellow", "accent": "bronze_indigo"},
    "qi": {"primary": "bamboo_yellow", "accent": "jade_green"},
    "han": {"primary": "stone_gray", "accent": "lacquer_red"},
}

# Bayer 4x4 抖动矩阵
BAYER_4X4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]

# ============================================================
# 工具函数
# ============================================================

def lerp_color(c1, c2, t):
    """线性插值两色"""
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def manual_aa_pixel(img, x, y, edge_color, bg_color):
    """手动抗锯齿：插入 (bg+edge)/2 的中性像素"""
    if 0 <= x < img.width and 0 <= y < img.height:
        mid = lerp_color(bg_color, edge_color, 0.5)
        existing = img.getpixel((x, y))
        if existing[3] == 0:  # 只覆盖透明像素
            img.putpixel((x, y), mid + (180,))


def apply_dithering(img, region, color_light, color_dark, threshold_scale=1.0):
    """对指定区域应用 Bayer 4x4 有序抖动"""
    x0, y0, x1, y1 = region
    for y in range(y0, min(y1, img.height)):
        for x in range(x0, min(x1, img.width)):
            threshold = BAYER_4X4[y % 4][x % 4] / 16.0
            if threshold < threshold_scale:
                img.putpixel((x, y), color_dark + (255,))
            else:
                img.putpixel((x, y), color_light + (255,))


def draw_hex_outline(draw, cx, cy, size, color, thickness=1):
    """绘制六角形轮廓（像素级）"""
    # 简化的六角形：上窄下宽的等腰梯形
    half = size // 2
    top_w = size - 6
    bot_w = size
    pts = [
        (cx - top_w // 2, cy - half + 2),
        (cx + top_w // 2, cy - half + 2),
        (cx + bot_w // 2, cy + half),
        (cx - bot_w // 2, cy + half),
    ]
    draw.polygon(pts, outline=color)


def ink_bleeding(img, cx, cy, radius, color, alphas=(0.8, 0.4, 0.1)):
    """水墨渗透边缘效果"""
    for i, alpha in enumerate(alphas):
        r = radius - i
        if r <= 0:
            continue
        a = int(alpha * 255)
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    px, py = cx + dx, cy + dy
                    if 0 <= px < img.width and 0 <= py < img.height:
                        old = img.getpixel((px, py))
                        if old[3] < a:
                            img.putpixel((px, py), color + (a,))


# ============================================================
# 生成：单位精灵图（战斗姿态）
# ============================================================

def generate_unit_sprite(faction, unit_type="swordsman"):
    """为指定国家生成 32x32 战斗单位精灵"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    fc = FACTION_COLORS[faction]
    primary = COLOR_RAMPS[fc["primary"]]
    accent = COLOR_RAMPS[fc["accent"]]

    # 2.5D 底座 (6px 厚度)
    for y in range(26, 32):
        depth = (y - 26) / 6.0
        side_color = lerp_color(primary["shadow"], primary["deep"], depth)
        # 底座宽度随高度收窄
        x_indent = int((32 - y + 26) * 0.3)
        for x in range(x_indent, 32 - x_indent):
            if y >= 26:
                # 6px 厚度层：加入泥土颗粒感
                noise = random.uniform(-0.15, 0.15)
                c = tuple(max(0, min(255, int(v * (1 + noise)))) for v in side_color)
                img.putpixel((x, y), c + (255,))

    # 单位主体 (顶面 26px 区域)
    if unit_type == "swordsman":
        # 头部 (圆形，8px)
        head_cx, head_cy = 16, 8
        for dy in range(-4, 5):
            for dx in range(-4, 5):
                if dx * dx + dy * dy <= 16:
                    px, py = head_cx + dx, head_cy + dy
                    shade = primary["high"] if dy < 0 else primary["base"]
                    img.putpixel((px, py), shade + (255,))

        # 身躯 (梯形)
        for y in range(12, 22):
            w = 5 + (y - 12) // 2
            shade = primary["base"] if y < 17 else primary["shadow"]
            for x in range(16 - w, 16 + w):
                img.putpixel((x, y), shade + (255,))

        # 武器 (右侧斜线 - 剑)
        for i in range(14):
            wx = 22 + i // 3
            wy = 4 + i
            if 0 <= wx < 32 and 0 <= wy < 32:
                img.putpixel((wx, wy), accent["base"] + (255,))

        # 盾牌 (左侧小圆)
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                if dx * dx + dy * dy <= 9:
                    px, py = 8 + dx, 16 + dy
                    img.putpixel((px, py), accent["shadow"] + (255,))

    elif unit_type == "archer":
        # 头部
        head_cx, head_cy = 14, 7
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                if dx * dx + dy * dy <= 9:
                    shade = primary["high"] if dy < 0 else primary["base"]
                    img.putpixel((head_cx + dx, head_cy + dy), shade + (255,))

        # 身躯 (略瘦)
        for y in range(10, 22):
            w = 4 + (y - 10) // 3
            shade = primary["base"] if y < 16 else primary["shadow"]
            for x in range(14 - w, 14 + w):
                img.putpixel((x, y), shade + (255,))

        # 弓 (左侧弧线)
        for i in range(18):
            angle = math.pi * 0.3 + (math.pi * 0.4) * i / 17
            bx = int(6 + 5 * math.cos(angle))
            by = int(12 + 8 * math.sin(angle))
            if 0 <= bx < 32 and 0 <= by < 32:
                img.putpixel((bx, by), accent["base"] + (255,))

        # 弦 (直线)
        for y in range(4, 21):
            if 0 <= y < 32:
                img.putpixel((6, y), accent["high"] + (200,))

        # 箭
        for i in range(10):
            ax = 8 + i
            ay = 12
            if 0 <= ax < 32:
                img.putpixel((ax, ay), accent["deep"] + (255,))

    elif unit_type == "cavalry":
        # 马身 (大型椭圆)
        for dy in range(-5, 6):
            for dx in range(-10, 11):
                if (dx * dx) / 100 + (dy * dy) / 25 <= 1:
                    px, py = 16 + dx, 20 + dy
                    if 0 <= px < 32 and 0 <= py < 32:
                        shade = primary["shadow"] if dy > 0 else primary["base"]
                        img.putpixel((px, py), shade + (255,))

        # 马头
        for dy in range(-3, 4):
            for dx in range(-2, 3):
                if dx * dx + dy * dy <= 5:
                    px, py = 26 + dx, 14 + dy
                    if 0 <= px < 32 and 0 <= py < 32:
                        img.putpixel((px, py), primary["high"] + (255,))

        # 骑手 (小身躯在马背上)
        for y in range(6, 16):
            w = 3
            for x in range(13, 19):
                img.putpixel((x, y), accent["base"] + (255,))

        # 骑手头部
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if dx * dx + dy * dy <= 4:
                    img.putpixel((16 + dx, 4 + dy), accent["high"] + (255,))

    # 手动抗锯齿 (底座边缘)
    for x in range(32):
        for y in [25, 31]:
            if 0 <= y < 32 and img.getpixel((x, y))[3] > 0:
                if y == 25 and img.getpixel((x, y - 1))[3] == 0:
                    aa_color = lerp_color(primary["base"], primary["shadow"], 0.5)
                    img.putpixel((x, y - 1), aa_color + (120,))

    return img


# ============================================================
# 生成：战斗特效
# ============================================================

def generate_slash_effect():
    """32x32 斩击特效 - 斜向弧线"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    accent = COLOR_RAMPS["gold_accent"]

    # 斜向弧形斩击
    for i in range(24):
        angle = -0.6 + 0.05 * i
        cx = int(4 + i)
        cy = int(28 - i * 0.9 + 2 * math.sin(angle * 3))
        # 宽度渐变
        width = max(1, 3 - abs(i - 12) // 4)
        for dw in range(-width, width + 1):
            px, py = cx, cy + dw
            if 0 <= px < 32 and 0 <= py < 32:
                alpha = 255 - abs(i - 12) * 8
                c = accent["high"] if abs(dw) == 0 else accent["base"]
                img.putpixel((px, py), c + (max(60, alpha),))

    # 残影拖尾
    for i in range(8):
        px = 4 + i
        py = 28 - int(i * 0.9)
        if 0 <= px < 32 and 0 <= py < 32:
            old = img.getpixel((px, py))
            trail = accent["deep"] + (40,)
            img.putpixel((px, py), trail)

    return img


def generate_arrow_effect():
    """32x32 箭矢飞行特效"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    accent = COLOR_RAMPS["bronze_indigo"]

    # 箭杆 (斜向)
    for i in range(20):
        ax = 4 + i
        ay = 26 - i
        if 0 <= ax < 32 and 0 <= ay < 32:
            img.putpixel((ax, ay), accent["base"] + (255,))
            # 箭杆厚度
            if 0 <= ay + 1 < 32:
                img.putpixel((ax, ay + 1), accent["shadow"] + (200,))

    # 箭头 (三角)
    tip_x, tip_y = 24, 6
    for dy in range(-1, 2):
        for dx in range(0, 3):
            px, py = tip_x + dx, tip_y + dy
            if 0 <= px < 32 and 0 <= py < 32:
                img.putpixel((px, py), accent["high"] + (255,))

    # 尾羽 (3 根短横线)
    for fy in range(3):
        for fx in range(3):
            px, py = 4 + fx, 26 + fy - 1
            if 0 <= px < 32 and 0 <= py < 32:
                img.putpixel((px, py), COLOR_RAMPS["jade_green"]["base"] + (200,))

    # 运动模糊残影
    for i in range(6):
        blur_x = 4 + i - 3
        blur_y = 26 - i + 3
        if 0 <= blur_x < 32 and 0 <= blur_y < 32:
            img.putpixel((blur_x, blur_y), accent["shadow"] + (60,))

    return img


def generate_magic_effect():
    """32x32 法术/策略特效 - 水墨漩涡"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    ink = COLOR_RAMPS["ink_black"]
    bamboo = COLOR_RAMPS["bamboo_yellow"]

    # 螺旋水墨
    for i in range(60):
        angle = i * 0.3
        r = 2 + i * 0.2
        cx = int(16 + r * math.cos(angle))
        cy = int(16 + r * math.sin(angle))
        if 0 <= cx < 32 and 0 <= cy < 32:
            alpha = max(60, 255 - i * 3)
            c = ink["base"] if i % 3 != 0 else bamboo["shadow"]
            img.putpixel((cx, cy), c + (alpha,))
            # 扩散 1px
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                nx, ny = cx + dx, cy + dy
                if 0 <= nx < 32 and 0 <= ny < 32:
                    old = img.getpixel((nx, ny))
                    if old[3] < alpha // 2:
                        img.putpixel((nx, ny), c + (alpha // 2,))

    # 中心高光
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if dx * dx + dy * dy <= 4:
                img.putpixel((16 + dx, 16 + dy), bamboo["high"] + (220,))

    return img


def generate_impact_effect():
    """32x32 冲击/碰撞特效 - 放射状碎片"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    red = COLOR_RAMPS["lacquer_red"]
    gold = COLOR_RAMPS["gold_accent"]

    # 放射状碎片
    for i in range(12):
        angle = i * math.pi * 2 / 12
        length = 8 + random.randint(0, 6)
        for j in range(length):
            px = int(16 + j * math.cos(angle))
            py = int(16 + j * math.sin(angle))
            if 0 <= px < 32 and 0 <= py < 32:
                alpha = 255 - j * 20
                c = red["high"] if j < length // 2 else gold["base"]
                img.putpixel((px, py), c + (max(40, alpha),))

    # 中心闪光
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            if dx * dx + dy * dy <= 9:
                px, py = 16 + dx, 16 + dy
                if 0 <= px < 32 and 0 <= py < 32:
                    img.putpixel((px, py), gold["high"] + (240,))

    return img


def generate_block_effect():
    """32x32 格挡特效 - 盾形闪光"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    bronze = COLOR_RAMPS["bronze_indigo"]
    stone = COLOR_RAMPS["stone_gray"]

    # 盾形轮廓
    for y in range(6, 28):
        half_w = int(10 * (1 - ((y - 17) / 11) ** 2))
        for x in range(16 - half_w, 16 + half_w + 1):
            if 0 <= x < 32:
                dist = abs(x - 16)
                if dist >= half_w - 1:
                    img.putpixel((x, y), stone["high"] + (255,))
                elif dist >= half_w - 2:
                    img.putpixel((x, y), bronze["high"] + (200,))

    # 中心闪光十字
    for i in range(-4, 5):
        for offset in [-1, 0, 1]:
            if 0 <= 16 + i < 32 and 0 <= 16 + offset < 32:
                img.putpixel((16 + i, 16 + offset), stone["high"] + (180,))
                img.putpixel((16 + offset, 16 + i), stone["high"] + (180,))

    return img


# ============================================================
# 生成：战斗 UI 元素
# ============================================================

def generate_health_bar_bg():
    """64x8 血条背景"""
    img = Image.new("RGBA", (64, 8), (0, 0, 0, 0))
    ink = COLOR_RAMPS["ink_black"]
    draw = ImageDraw.Draw(img)

    # 外框
    draw.rectangle([0, 0, 63, 7], outline=ink["deep"] + (220,), width=1)
    # 内部暗色
    draw.rectangle([1, 1, 62, 6], fill=ink["shadow"] + (180,))

    return img


def generate_health_bar_fill():
    """64x8 血条填充（绿色渐变）"""
    img = Image.new("RGBA", (64, 8), (0, 0, 0, 0))
    jade = COLOR_RAMPS["jade_green"]

    for x in range(1, 63):
        t = x / 62.0
        c = lerp_color(jade["shadow"], jade["high"], t)
        for y in range(1, 7):
            # 上半亮下半暗
            if y < 4:
                img.putpixel((x, y), c + (220,))
            else:
                img.putpixel((x, y), lerp_color(c, jade["deep"], 0.3) + (220,))

    return img


def generate_health_bar_low():
    """64x8 血条填充（红色 - 低血量）"""
    img = Image.new("RGBA", (64, 8), (0, 0, 0, 0))
    red = COLOR_RAMPS["lacquer_red"]

    for x in range(1, 63):
        t = x / 62.0
        c = lerp_color(red["shadow"], red["high"], t)
        for y in range(1, 7):
            if y < 4:
                img.putpixel((x, y), c + (220,))
            else:
                img.putpixel((x, y), lerp_color(c, red["deep"], 0.3) + (220,))

    return img


def generate_turn_indicator():
    """16x16 回合指示器 - 青铜色圆形"""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    bronze = COLOR_RAMPS["bronze_indigo"]
    gold = COLOR_RAMPS["gold_accent"]

    # 外圈
    for dy in range(-7, 8):
        for dx in range(-7, 8):
            dist = math.sqrt(dx * dx + dy * dy)
            if 6 <= dist <= 7:
                img.putpixel((8 + dx, 8 + dy), bronze["high"] + (255,))
            elif dist < 6:
                # 内部填充
                shade = gold["base"] if dist < 3 else bronze["base"]
                img.putpixel((8 + dx, 8 + dy), shade + (200,))

    return img


def generate_selection_cursor():
    """32x32 选择光标 - 六角形边框（脉冲）"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    gold = COLOR_RAMPS["gold_accent"]
    draw = ImageDraw.Draw(img)

    # 六角形边框 (2.5D 尖顶)
    pts = [
        (16, 0),   # 顶
        (30, 8),   # 右上
        (30, 24),  # 右下
        (16, 31),  # 底
        (2, 24),   # 左下
        (2, 8),    # 左上
    ]
    draw.polygon(pts, outline=gold["high"] + (255,), width=2)

    # 角落点缀
    for corner in [(16, 0), (30, 8), (30, 24), (16, 31), (2, 24), (2, 8)]:
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                px, py = corner[0] + dx, corner[1] + dy
                if 0 <= px < 32 and 0 <= py < 32:
                    img.putpixel((px, py), gold["deep"] + (200,))

    return img


def generate_attack_range_overlay():
    """32x32 攻击范围叠加层 - 红色半透明六角"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    red = COLOR_RAMPS["lacquer_red"]

    # 六角形填充 (半透明红)
    for y in range(32):
        for x in range(32):
            # 简化六角判定
            cx, cy = 16, 16
            dx = abs(x - cx)
            dy = abs(y - cy)
            if dx <= 14 and dy <= 14:
                if dx + dy * 0.8 <= 14:
                    noise = random.uniform(0.6, 1.0)
                    a = int(80 * noise)
                    img.putpixel((x, y), red["base"] + (a,))

    return img


def generate_movement_range_overlay():
    """32x32 移动范围叠加层 - 蓝色半透明六角"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    water = COLOR_RAMPS["water_blue"]

    for y in range(32):
        for x in range(32):
            cx, cy = 16, 16
            dx = abs(x - cx)
            dy = abs(y - cy)
            if dx <= 14 and dy <= 14:
                if dx + dy * 0.8 <= 14:
                    noise = random.uniform(0.6, 1.0)
                    a = int(70 * noise)
                    img.putpixel((x, y), water["base"] + (a,))

    return img


# ============================================================
# 生成：战斗地形图块
# ============================================================

def generate_battle_terrain(terrain_type):
    """32x32 战斗场景地形图块"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))

    if terrain_type == "plain":
        color = COLOR_RAMPS["earth_brown"]
        # 顶面 (26px)
        for y in range(26):
            for x in range(32):
                base = lerp_color(color["base"], color["high"], y / 26.0 * 0.3)
                noise = random.uniform(-0.08, 0.08)
                c = tuple(max(0, min(255, int(v * (1 + noise)))) for v in base)
                img.putpixel((x, y), c + (255,))

        # Bayer 抖动过渡
        for y in range(20, 26):
            for x in range(32):
                threshold = BAYER_4X4[y % 4][x % 4] / 16.0
                if threshold < 0.3:
                    img.putpixel((x, y), color["shadow"] + (255,))

    elif terrain_type == "forest":
        earth = COLOR_RAMPS["earth_brown"]
        green = COLOR_RAMPS["jade_green"]

        # 底层大地
        for y in range(26):
            for x in range(32):
                img.putpixel((x, y), earth["base"] + (255,))

        # 树冠 (3 个墨绿圆)
        trees = [(8, 8), (20, 6), (14, 14)]
        for tx, ty in trees:
            r = 5 + random.randint(0, 2)
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if dx * dx + dy * dy <= r * r:
                        px, py = tx + dx, ty + dy
                        if 0 <= px < 32 and 0 <= py < 26:
                            shade = green["high"] if dy < 0 else green["base"]
                            # 簇状抖动
                            if random.random() < 0.15:
                                shade = green["shadow"]
                            img.putpixel((px, py), shade + (255,))

        # 树干
        for tx, ty in trees:
            for y in range(ty + 3, 26):
                if 0 <= tx < 32 and 0 <= y < 32:
                    img.putpixel((tx, y), green["deep"] + (255,))

    elif terrain_type == "mountain":
        stone = COLOR_RAMPS["stone_gray"]
        earth = COLOR_RAMPS["earth_brown"]

        # 山体轮廓 (3 个不规则峰)
        peaks = [(8, 4), (16, 2), (24, 6)]
        for px, py in peaks:
            h = 10 + random.randint(0, 4)
            for y in range(py, py + h):
                w = max(1, (y - py) * 2 + 2)
                for x in range(max(0, px - w), min(32, px + w)):
                    if 0 <= y < 26:
                        shade = stone["high"] if y < py + h // 3 else stone["base"]
                        if y > py + h * 2 // 3:
                            shade = stone["shadow"]
                        img.putpixel((x, y), shade + (255,))

        # 山脊高光 (竹简黄 1px)
        for px, py in peaks:
            for i in range(-2, 3):
                x = px + i
                y = py + abs(i)
                if 0 <= x < 32 and 0 <= y < 26:
                    img.putpixel((x, y), COLOR_RAMPS["bamboo_yellow"]["high"] + (180,))

    elif terrain_type == "river":
        water = COLOR_RAMPS["water_blue"]

        # 水面 (顶面)
        for y in range(26):
            for x in range(32):
                base = water["base"]
                # 波纹
                wave = math.sin(x * 0.5 + y * 0.3) * 0.15
                c = lerp_color(base, water["high"], max(0, wave))
                # Bayer 抖动消除塑料感
                threshold = BAYER_4X4[y % 4][x % 4] / 16.0
                if threshold < 0.25:
                    c = lerp_color(c, water["shadow"], 0.4)
                img.putpixel((x, y), c + (255,))

        # 渗透边缘 (Ink Bleeding)
        ink_bleeding(img, 0, 13, 3, water["shadow"], (0.8, 0.4, 0.1))
        ink_bleeding(img, 31, 13, 3, water["shadow"], (0.8, 0.4, 0.1))

    elif terrain_type == "chokepoint":
        # 关隘 - 石质通道
        stone = COLOR_RAMPS["stone_gray"]
        red = COLOR_RAMPS["lacquer_red"]

        # 基础石地
        for y in range(26):
            for x in range(32):
                c = stone["base"] if y > 6 else stone["shadow"]
                noise = random.uniform(-0.1, 0.1)
                c = tuple(max(0, min(255, int(v * (1 + noise)))) for v in c)
                img.putpixel((x, y), c + (255,))

        # 两侧城墙 (暗红色砖)
        for y in range(0, 20):
            # 左墙
            for x in range(0, 8):
                brick = red["shadow"] if (y // 3 + x // 4) % 2 == 0 else red["deep"]
                img.putpixel((x, y), brick + (255,))
            # 右墙
            for x in range(24, 32):
                brick = red["shadow"] if (y // 3 + x // 4) % 2 == 0 else red["deep"]
                img.putpixel((x, y), brick + (255,))

        # 城门楼 (顶部横梁)
        for x in range(8, 24):
            img.putpixel((x, 4), red["base"] + (255,))
            img.putpixel((x, 5), red["base"] + (255,))

    elif terrain_type == "ford":
        # 渡口 - 浅水 + 石头路
        water = COLOR_RAMPS["water_blue"]
        stone = COLOR_RAMPS["stone_gray"]

        for y in range(26):
            for x in range(32):
                # 浅水底
                c = lerp_color(water["base"], water["high"], 0.3)
                noise = random.uniform(-0.05, 0.05)
                c = tuple(max(0, min(255, int(v * (1 + noise)))) for v in c)
                img.putpixel((x, y), c + (255,))

        # 石头汀步
        stepping_stones = [(8, 10), (16, 14), (24, 18), (12, 22)]
        for sx, sy in stepping_stones:
            for dy in range(-2, 3):
                for dx in range(-3, 4):
                    if dx * dx / 9 + dy * dy / 4 <= 1:
                        px, py = sx + dx, sy + dy
                        if 0 <= px < 32 and 0 <= py < 26:
                            shade = stone["high"] if dy < 0 else stone["base"]
                            img.putpixel((px, py), shade + (255,))

    # 底部 6px 厚度层 (通用)
    color_map = {
        "plain": COLOR_RAMPS["earth_brown"],
        "forest": COLOR_RAMPS["earth_brown"],
        "mountain": COLOR_RAMPS["stone_gray"],
        "river": COLOR_RAMPS["water_blue"],
        "chokepoint": COLOR_RAMPS["stone_gray"],
        "ford": COLOR_RAMPS["water_blue"],
    }
    ramp = color_map.get(terrain_type, COLOR_RAMPS["earth_brown"])

    for y in range(26, 32):
        depth = (y - 26) / 6.0
        side_color = lerp_color(ramp["shadow"], ramp["deep"], depth)
        x_indent = int((32 - y + 26) * 0.2)
        for x in range(x_indent, 32 - x_indent):
            noise = random.uniform(-0.12, 0.12)
            c = tuple(max(0, min(255, int(v * (1 + noise)))) for v in side_color)
            img.putpixel((x, y), c + (255,))

    # 手动 AA (顶面与厚度交界)
    for x in range(32):
        if img.getpixel((x, 25))[3] > 0 and img.getpixel((x, 26))[3] > 0:
            c1 = img.getpixel((x, 25))[:3]
            c2 = img.getpixel((x, 26))[:3]
            mid = lerp_color(c1, c2, 0.5)
            # 在 25px 处插入半透明中性像素
            if img.getpixel((x, 24))[3] == 0:
                img.putpixel((x, 24), mid + (120,))

    return img


# ============================================================
# 生成：战斗背景 (192x128)
# ============================================================

def generate_battle_background():
    """192x128 战斗场景背景"""
    img = Image.new("RGBA", (192, 128), (0, 0, 0, 0))
    bamboo = COLOR_RAMPS["bamboo_yellow"]
    ink = COLOR_RAMPS["ink_black"]
    stone = COLOR_RAMPS["stone_gray"]

    # 宣纸底色 (竹简黄渐变)
    for y in range(128):
        t = y / 128.0
        base = lerp_color(bamboo["high"], bamboo["base"], t)
        for x in range(192):
            noise = random.uniform(-0.04, 0.04)
            c = tuple(max(0, min(255, int(v * (1 + noise)))) for v in base)
            img.putpixel((x, y), c + (255,))

    # 远山剪影 (水墨黑)
    for x in range(192):
        h = int(30 + 15 * math.sin(x * 0.02) + 10 * math.sin(x * 0.05 + 1))
        for y in range(128 - h, 128):
            depth = (y - (128 - h)) / h
            c = lerp_color(ink["shadow"], ink["base"], depth)
            # Bayer 抖动
            threshold = BAYER_4X4[y % 4][x % 4] / 16.0
            if threshold < 0.3:
                c = lerp_color(c, ink["deep"], 0.5)
            alpha = 180 if y < 128 - h + 3 else 255  # 顶部渗透
            img.putpixel((x, y), c + (alpha,))

    # 地面层
    earth = COLOR_RAMPS["earth_brown"]
    for y in range(96, 128):
        for x in range(192):
            t = (y - 96) / 32.0
            c = lerp_color(earth["base"], earth["shadow"], t)
            noise = random.uniform(-0.06, 0.06)
            c = tuple(max(0, min(255, int(v * (1 + noise)))) for v in c)
            img.putpixel((x, y), c + (255,))

    return img


# ============================================================
# 生成：将领/英雄头像 (64x64)
# ============================================================

def generate_hero_portrait(faction):
    """64x64 将领头像"""
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    fc = FACTION_COLORS[faction]
    primary = COLOR_RAMPS[fc["primary"]]
    accent = COLOR_RAMPS[fc["accent"]]
    bamboo = COLOR_RAMPS["bamboo_yellow"]

    # 宣纸背景
    for y in range(64):
        for x in range(64):
            base = lerp_color(bamboo["high"], bamboo["base"], y / 64.0)
            noise = random.uniform(-0.03, 0.03)
            c = tuple(max(0, min(255, int(v * (1 + noise)))) for v in base)
            img.putpixel((x, y), c + (255,))

    # 头部 (圆形，中心偏上)
    head_cx, head_cy, head_r = 32, 22, 14
    for dy in range(-head_r, head_r + 1):
        for dx in range(-head_r, head_r + 1):
            if dx * dx + dy * dy <= head_r * head_r:
                px, py = head_cx + dx, head_cy + dy
                if 0 <= px < 64 and 0 <= py < 64:
                    # 上半亮下半暗
                    shade = primary["high"] if dy < -2 else primary["base"]
                    if dy > 8:
                        shade = primary["shadow"]
                    img.putpixel((px, py), shade + (255,))

    # 冠/帽 (顶部装饰)
    for dy in range(-6, 0):
        for dx in range(-10, 11):
            if abs(dx) <= 10 - abs(dy):
                px, py = head_cx + dx, head_cy - head_r + dy
                if 0 <= px < 64 and 0 <= py < 64:
                    img.putpixel((px, py), accent["base"] + (255,))

    # 冠带 (两侧下垂)
    for i in range(12):
        for dx in [-1, 0, 1]:
            px = head_cx - head_r + dx
            py = head_cy + i
            if 0 <= px < 64 and 0 <= py < 64:
                img.putpixel((px, py), accent["shadow"] + (200,))
            px = head_cx + head_r + dx
            if 0 <= px < 64 and 0 <= py < 64:
                img.putpixel((px, py), accent["shadow"] + (200,))

    # 眼睛 (两点)
    for dx in [-4, 4]:
        px, py = head_cx + dx, head_cy - 2
        if 0 <= px < 64 and 0 <= py < 64:
            img.putpixel((px, py), (0, 0, 0, 255,))
            img.putpixel((px + 1, py), (0, 0, 0, 255,))

    # 胡须 (下巴线条)
    for i in range(8):
        lx = head_cx - 3 + random.randint(-1, 1)
        ly = head_cy + head_r - 2 + i
        if 0 <= lx < 64 and 0 <= ly < 64:
            img.putpixel((lx, ly), primary["deep"] + (180,))

    # 肩甲 (底部梯形)
    for y in range(head_cy + head_r + 4, 58):
        w = 18 + (y - (head_cy + head_r + 4))
        for x in range(head_cx - w, head_cx + w):
            if 0 <= x < 64 and 0 <= y < 64:
                shade = accent["base"] if y < 50 else accent["shadow"]
                img.putpixel((x, y), shade + (255,))

    return img


# ============================================================
# 生成：数字精灵 (用于伤害数字显示)
# ============================================================

def generate_damage_numbers():
    """生成 0-9 伤害数字精灵表 (16x16 每个数字，共 160x16)"""
    img = Image.new("RGBA", (160, 16), (0, 0, 0, 0))
    red = COLOR_RAMPS["lacquer_red"]
    gold = COLOR_RAMPS["gold_accent"]

    # 简单的像素数字模板 (5x7)
    digit_patterns = {
        0: ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        1: ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        2: ["01110", "10001", "00001", "00110", "01000", "10000", "11111"],
        3: ["01110", "10001", "00001", "00110", "00001", "10001", "01110"],
        4: ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        5: ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
        6: ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
        7: ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        8: ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        9: ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    }

    for digit, pattern in digit_patterns.items():
        ox = digit * 16 + 3
        oy = 2
        color = red["high"] if digit > 5 else gold["high"]
        for row_i, row in enumerate(pattern):
            for col_i, cell in enumerate(row):
                if cell == "1":
                    px, py = ox + col_i, oy + row_i
                    if 0 <= px < 160 and 0 <= py < 16:
                        img.putpixel((px, py), color + (255,))

    return img


# ============================================================
# 主函数：生成所有战斗资产
# ============================================================

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    assets_dir = os.path.join(base_dir, "photos")

    # 目录列表
    dirs = [
        os.path.join(assets_dir, "sprites", "units", f) for f in FACTION_COLORS
    ] + [
        os.path.join(assets_dir, "sprites", "effects"),
        os.path.join(assets_dir, "sprites", "ui"),
        os.path.join(assets_dir, "sprites", "terrain"),
        os.path.join(assets_dir, "ui", "battle"),
    ]

    for d in dirs:
        os.makedirs(d, exist_ok=True)

    generated = []

    # 1. 单位精灵 (7 国家 x 3 兵种)
    unit_types = ["swordsman", "archer", "cavalry"]
    for faction in FACTION_COLORS:
        for utype in unit_types:
            img = generate_unit_sprite(faction, utype)
            path = os.path.join(assets_dir, "sprites", "units", faction,
                                f"unit_{faction}_{utype}_01.png")
            img.save(path)
            generated.append(path)

    # 2. 战斗特效
    effects = {
        "effect_slash_01.png": generate_slash_effect,
        "effect_arrow_01.png": generate_arrow_effect,
        "effect_magic_01.png": generate_magic_effect,
        "effect_impact_01.png": generate_impact_effect,
        "effect_block_01.png": generate_block_effect,
    }
    for name, func in effects.items():
        img = func()
        path = os.path.join(assets_dir, "sprites", "effects", name)
        img.save(path)
        generated.append(path)

    # 3. 战斗 UI 元素
    ui_elements = {
        "ui_health_bar_bg.png": generate_health_bar_bg,
        "ui_health_bar_fill.png": generate_health_bar_fill,
        "ui_health_bar_low.png": generate_health_bar_low,
        "ui_turn_indicator.png": generate_turn_indicator,
        "ui_selection_cursor.png": generate_selection_cursor,
        "ui_attack_range.png": generate_attack_range_overlay,
        "ui_movement_range.png": generate_movement_range_overlay,
    }
    for name, func in ui_elements.items():
        img = func()
        path = os.path.join(assets_dir, "sprites", "ui", name)
        img.save(path)
        generated.append(path)

    # 4. 战斗地形
    terrains = ["plain", "forest", "mountain", "river", "chokepoint", "ford"]
    for t in terrains:
        img = generate_battle_terrain(t)
        path = os.path.join(assets_dir, "sprites", "terrain", f"tile_{t}_battle.png")
        img.save(path)
        generated.append(path)

    # 5. 战斗背景
    bg = generate_battle_background()
    bg_path = os.path.join(assets_dir, "ui", "battle", "battle_background.png")
    bg.save(bg_path)
    generated.append(bg_path)

    # 6. 将领头像
    for faction in FACTION_COLORS:
        img = generate_hero_portrait(faction)
        path = os.path.join(assets_dir, "ui", "battle", f"portrait_{faction}_hero.png")
        img.save(path)
        generated.append(path)

    # 7. 伤害数字精灵表
    dmg = generate_damage_numbers()
    dmg_path = os.path.join(assets_dir, "ui", "battle", "damage_numbers.png")
    dmg.save(dmg_path)
    generated.append(dmg_path)

    # 汇总
    print(f"\n{'='*50}")
    print(f"《山河策》战斗资产生成完毕")
    print(f"{'='*50}")
    print(f"共生成 {len(generated)} 个文件\n")
    print("目录结构:")
    print(f"  photos/sprites/units/     - 7国 x 3兵种 = 21 个单位精灵")
    print(f"  photos/sprites/effects/   - 5 个战斗特效")
    print(f"  photos/sprites/ui/        - 7 个战斗UI元素")
    print(f"  photos/sprites/terrain/   - 6 个战斗地形图块")
    print(f"  photos/ui/battle/         - 背景 + 7头像 + 数字精灵表")
    print(f"\n请在本地文件管理器中查看 photos/ 目录。")


if __name__ == "__main__":
    main()
