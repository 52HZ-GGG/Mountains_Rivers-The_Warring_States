"""
《山河策》美术资产占位符生成器
按 ART.md 方案生成全部阶段的占位资产
运行: python generate_assets.py
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFont

# ── 目录结构 ──────────────────────────────────────────────
DIRS = [
    "terrain", "unit", "ui", "portrait", "event",
    "effect", "icon", "season", "diplomacy", "flag", "city",
    "school", "logo",
]
ROOT = os.path.dirname(os.path.abspath(__file__))

def ensure_dirs():
    for d in DIRS:
        os.makedirs(os.path.join(ROOT, d), exist_ok=True)

# ── 战国色谱 (饱和度 < 40%) ─────────────────────────────────
PALETTE = {
    "漆器红": {"base": (140, 69, 34),  "high": (176, 93, 59),  "shadow": (102, 48, 24), "deep": (64, 29, 15)},
    "青铜靛": {"base": (43, 51, 48),   "high": (69, 82, 77),   "shadow": (26, 33, 30),  "deep": (13, 18, 16)},
    "竹简黄": {"base": (197, 163, 104),"high": (217, 190, 139),"shadow": (153, 122, 74),"deep": (102, 82, 49)},
    "水墨黑": {"base": (26, 26, 27),   "high": (51, 51, 52),   "shadow": (13, 13, 14),  "deep": (0, 0, 0)},
}

# 自然色
NATURE = {
    "平原":  {"base": (140, 155, 110), "high": (165, 178, 135), "shadow": (105, 118, 82),  "deep": (72, 82, 56)},
    "森林":  {"base": (55, 90, 55),    "high": (78, 115, 78),   "shadow": (38, 62, 38),    "deep": (22, 40, 22)},
    "山地":  {"base": (120, 105, 90),  "high": (148, 132, 115), "shadow": (88, 76, 64),    "deep": (58, 50, 42)},
    "河流":  {"base": (55, 85, 130),   "high": (80, 115, 160),  "shadow": (35, 60, 95),    "deep": (20, 40, 68)},
    "沼泽":  {"base": (75, 95, 65),    "high": (98, 118, 88),   "shadow": (52, 68, 45),    "deep": (32, 45, 28)},
}

# ── 辅助函数 ─────────────────────────────────────────────
def save(img, *path_parts):
    p = os.path.join(ROOT, *path_parts)
    img.save(p)
    print(f"  [OK] {os.path.relpath(p, ROOT)}")

def hex_points(cx, cy, r):
    """尖顶六角形顶点"""
    return [(cx + r * math.sin(math.radians(60 * i)),
             cy - r * math.cos(math.radians(60 * i))) for i in range(6)]

def draw_hex_tile(size, colors, terrain_type="plain"):
    """生成 2.5D 尖顶六角形地块 (32x32)"""
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = w // 2, h // 2 - 3
    r = min(w, h) // 2 - 2

    # 顶部六角面
    pts = hex_points(cx, cy, r)
    draw.polygon(pts, fill=colors["base"])

    # 底部 6px 厚度（地层断面）
    bottom_color = colors["deep"]
    # 找最低的三个顶点
    pts_sorted = sorted(pts, key=lambda p: p[1], reverse=True)
    bottom_pts = pts_sorted[:3]
    for i in range(3):
        x, y = bottom_pts[i]
        bottom_pts[i] = (x, y + 6)
    # 连接底部
    hull = sorted(pts, key=lambda p: (p[0], p[1]))
    bottom_hull = [(x, y + 6) for x, y in hull[:3]]
    # 简单底部矩形
    min_x = int(min(p[0] for p in pts))
    max_x = int(max(p[0] for p in pts))
    min_y = int(min(p[1] for p in pts))
    max_y = int(max(p[1] for p in pts))
    draw.rectangle([min_x, max_y, max_x, max_y + 6], fill=bottom_color)

    # 斜边手动 AA - 简化版:在边缘插入中性像素
    edge_color = tuple((a + b) // 2 for a, b in zip(colors["base"], colors["shadow"]))
    for i in range(len(pts)):
        x1, y1 = int(pts[i][0]), int(pts[i][1])
        x2, y2 = int(pts[(i + 1) % len(pts)][0]), int(pts[(i + 1) % len(pts)][1])
        # 画边缘线
        draw.line([(x1, y1), (x2, y2)], fill=edge_color, width=1)

    # 高光点缀
    highlight = colors["high"]
    for _ in range(3):
        hx = cx + random.randint(-r // 2, r // 2)
        hy = cy + random.randint(-r // 2, 0)
        if 0 <= hx < w and 0 <= hy < h:
            img.putpixel((hx, hy), highlight)

    # 水墨噪声 (强度 0.15)
    if terrain_type in ("river", "swamp"):
        ink_color = (*PALETTE["水墨黑"]["base"], 38)
        for _ in range(15):
            ix = random.randint(min_x + 2, max_x - 2)
            iy = random.randint(min_y + 2, max_y - 2)
            if 0 <= ix < w and 0 <= iy < h:
                img.putpixel((ix, iy), ink_color)

    return img

def draw_unit_icon(size, colors, unit_shape="circle"):
    """生成 64x64 单位图标"""
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # 底座
    draw.ellipse([cx - 20, cy + 8, cx + 20, cy + 24], fill=colors["deep"])
    # 身体
    draw.rectangle([cx - 10, cy - 15, cx + 10, cy + 10], fill=colors["base"])
    # 头
    draw.ellipse([cx - 8, cy - 28, cx + 8, cy - 12], fill=colors["high"])
    # 高光
    draw.rectangle([cx - 8, cy - 13, cx - 6, cy + 8], fill=colors["high"])

    return img

def draw_portrait(size, label, palette_key="漆器红"):
    """生成 256x256 半身像占位"""
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    colors = PALETTE[palette_key]

    # 背景圆形
    draw.ellipse([20, 20, w - 20, h - 20], fill=(*colors["deep"], 180))
    # 身体轮廓
    draw.rectangle([w // 2 - 50, h // 2 + 20, w // 2 + 50, h - 30], fill=colors["base"])
    # 头部
    draw.ellipse([w // 2 - 35, h // 2 - 60, w // 2 + 35, h // 2 + 20], fill=colors["high"])
    # 冠冕
    draw.rectangle([w // 2 - 25, h // 2 - 80, w // 2 + 25, h // 2 - 55], fill=colors["shadow"])
    # 文字标签
    try:
        font = ImageFont.truetype("msyh.ttc", 16)
    except:
        font = ImageFont.load_default()
    draw.text((w // 2, h - 15), label, fill=(255, 255, 255, 200), font=font, anchor="mm")

    return img

def draw_icon(size, symbol, colors):
    """生成 64x64 图标"""
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    # 圆形底座
    draw.ellipse([4, 4, w - 4, h - 4], fill=colors["base"])
    draw.ellipse([6, 6, w - 6, h - 6], fill=colors["high"])

    # 中心符号
    try:
        font = ImageFont.truetype("msyh.ttc", 28)
    except:
        font = ImageFont.load_default()
    draw.text((cx, cy), symbol, fill=colors["deep"], font=font, anchor="mm")

    return img

def draw_ui_panel(size, title="", border_color=None):
    """生成 UI 面板"""
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    bc = border_color or PALETTE["青铜靛"]["base"]

    # 边框
    draw.rectangle([0, 0, w - 1, h - 1], fill=(*PALETTE["水墨黑"]["deep"], 200))
    draw.rectangle([2, 2, w - 3, h - 3], fill=(*PALETTE["竹简黄"]["deep"], 180))
    draw.rectangle([4, 4, w - 5, h - 5], fill=(*PALETTE["水墨黑"]["shadow"], 220))

    # 标题
    if title:
        try:
            font = ImageFont.truetype("msyh.ttc", 14)
        except:
            font = ImageFont.load_default()
        draw.text((w // 2, 14), title, fill=PALETTE["竹简黄"]["high"], font=font, anchor="mm")

    return img

def draw_flag(size, emblem, bg_color, fg_color):
    """生成旗帜"""
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 旗面
    draw.rectangle([2, 2, w - 3, h - 3], fill=bg_color)
    # 边框
    draw.rectangle([0, 0, w - 1, h - 1], outline=fg_color, width=2)
    # 徽记
    try:
        font = ImageFont.truetype("msyh.ttc", 24)
    except:
        font = ImageFont.load_default()
    draw.text((w // 2, h // 2), emblem, fill=fg_color, font=font, anchor="mm")

    return img

def draw_effect(size, effect_type):
    """生成特效占位"""
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2

    if effect_type == "attack":
        for i in range(8):
            angle = math.radians(45 * i)
            x1 = cx + int(10 * math.cos(angle))
            y1 = cy + int(10 * math.sin(angle))
            x2 = cx + int(25 * math.cos(angle))
            y2 = cy + int(25 * math.sin(angle))
            draw.line([(x1, y1), (x2, y2)], fill=PALETTE["漆器红"]["high"], width=3)
    elif effect_type == "fire":
        for i in range(5):
            x = cx + random.randint(-15, 15)
            y = cy + random.randint(-20, 5)
            r = random.randint(3, 8)
            color = random.choice([PALETTE["漆器红"]["base"], PALETTE["漆器红"]["high"], (200, 120, 40)])
            draw.ellipse([x - r, y - r, x + r, y + r], fill=color)
    elif effect_type == "culture":
        for r in range(5, 30, 5):
            alpha = max(20, 150 - r * 4)
            draw.ellipse([cx - r, cy - r, cx + r, cy + r],
                         outline=(*PALETTE["竹简黄"]["high"], alpha), width=2)
    else:
        # 通用粒子
        for _ in range(12):
            x = cx + random.randint(-20, 20)
            y = cy + random.randint(-20, 20)
            r = random.randint(2, 5)
            draw.ellipse([x - r, y - r, x + r, y + r], fill=PALETTE["竹简黄"]["high"])

    return img

def draw_season(size, season):
    """生成季节过渡图"""
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    season_colors = {
        "春": ((120, 160, 120), (180, 210, 160), (220, 180, 200)),
        "夏": ((80, 130, 80), (50, 100, 50), (160, 200, 80)),
        "秋": ((180, 130, 60), (150, 90, 40), (200, 160, 80)),
        "冬": ((180, 190, 200), (140, 155, 170), (220, 225, 230)),
    }
    c1, c2, c3 = season_colors.get(season, season_colors["春"])

    # 渐变背景
    for y in range(h):
        r = c1[0] + (c2[0] - c1[0]) * y // h
        g = c1[1] + (c2[1] - c1[1]) * y // h
        b = c1[2] + (c2[2] - c1[2]) * y // h
        draw.line([(0, y), (w, y)], fill=(r, g, b))

    # 装饰元素
    for _ in range(20):
        x = random.randint(0, w)
        y = random.randint(0, h)
        r = random.randint(2, 6)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=(*c3, 150))

    # 季节文字
    try:
        font = ImageFont.truetype("msyh.ttc", 48)
    except:
        font = ImageFont.load_default()
    draw.text((w // 2, h // 2), season, fill=(255, 255, 255, 200), font=font, anchor="mm")

    return img

# ==========================================================
#  主生成流程
# ==========================================================

def generate_all():
    ensure_dirs()
    random.seed(42)

    print("\n=== 阶段 0: 基础地块 ===")
    terrains = {
        "plain":  ("平原", NATURE["平原"]),
        "forest": ("森林", NATURE["森林"]),
        "mountain":("山地", NATURE["山地"]),
        "river":  ("河流", NATURE["河流"]),
        "swamp":  ("沼泽", NATURE["沼泽"]),  # 阶段 3 补齐
    }
    for key, (name, colors) in terrains.items():
        for v in range(1, 3):
            img = draw_hex_tile((32, 32), colors, key)
            save(img, "terrain", f"tile_{key}_{v:02d}.png")

    # 特殊地块 (32x32)
    print("\n=== 阶段 3: 特殊地块 ===")
    specials = {
        "pass":    ("关隘", PALETTE["青铜靛"]),
        "plank":   ("栈道", NATURE["山地"]),
        "bridge":  ("浮桥", NATURE["河流"]),
        "tower":   ("箭楼", PALETTE["漆器红"]),
    }
    for key, (name, colors) in specials.items():
        img = draw_hex_tile((32, 32), colors, key)
        save(img, "terrain", f"tile_{key}_01.png")

    print("\n=== 阶段 1:单位图标 (64x64) ===")
    units = {
        "infantry": ("步兵", PALETTE["漆器红"]),
        "archer":   ("弓兵", NATURE["森林"]),
        "cavalry":  ("骑兵", PALETTE["青铜靛"]),
        "chariot":  ("战车", PALETTE["竹简黄"]),
        "siege":    ("攻城", PALETTE["水墨黑"]),
    }
    for key, (name, colors) in units.items():
        img = draw_unit_icon((64, 64), colors)
        save(img, "unit", f"unit_{key}.png")

    print("\n=== 阶段 4:七国特色兵种 (64x64) ===")
    special_units = {
        "qin_ruishi":     ("锐士",     PALETTE["漆器红"]),
        "zhao_hufu":      ("胡服骑兵", PALETTE["青铜靛"]),
        "qi_jiji":        ("技击手",   NATURE["森林"]),
        "chu_shenxi":     ("申息之师", PALETTE["竹简黄"]),
        "wei_wuzu":       ("武卒",     PALETTE["水墨黑"]),
        "yan_liaodong":   ("辽东弓骑", NATURE["山地"]),
        "han_jingnu":     ("劲弩",     NATURE["河流"]),
    }
    for key, (name, colors) in special_units.items():
        img = draw_unit_icon((64, 64), colors)
        save(img, "unit", f"unit_{key}.png")

    print("\n=== 阶段 1:城市图块 (64x64) ===")
    for side, colors in [("friendly", NATURE["平原"]), ("enemy", PALETTE["漆器红"])]:
        img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        draw.rectangle([12, 20, 52, 50], fill=colors["base"])
        draw.rectangle([20, 8, 44, 22], fill=colors["high"])
        draw.polygon([(32, 0), (20, 12), (44, 12)], fill=colors["shadow"])
        draw.rectangle([28, 35, 36, 50], fill=colors["deep"])
        save(img, "city", f"city_{side}.png")

    print("\n=== 阶段 4:七国都城差异化 (64x64) ===")
    kingdoms = ["秦", "赵", "齐", "楚", "魏", "燕", "韩"]
    kingdom_colors = [
        PALETTE["漆器红"], PALETTE["青铜靛"], NATURE["森林"],
        PALETTE["竹简黄"], PALETTE["水墨黑"], NATURE["山地"], NATURE["河流"]
    ]
    for i, (kingdom, colors) in enumerate(zip(kingdoms, kingdom_colors)):
        img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        # 城墙
        draw.rectangle([8, 24, 56, 56], fill=colors["base"])
        # 城楼
        draw.rectangle([18, 10, 46, 26], fill=colors["high"])
        # 城门
        draw.rectangle([26, 38, 38, 56], fill=colors["deep"])
        # 旗帜
        draw.rectangle([30, 2, 34, 12], fill=colors["shadow"])
        draw.rectangle([28, 2, 36, 8], fill=colors["high"])
        try:
            font = ImageFont.truetype("msyh.ttc", 10)
        except:
            font = ImageFont.load_default()
        draw.text((32, 50), kingdom, fill=(255, 255, 255, 200), font=font, anchor="mm")
        save(img, "city", f"city_capital_{kingdom}.png")

    print("\n=== 阶段 1:UI 面板 ===")
    # 资源条
    resource_bar = draw_ui_panel((320, 40), "资源")
    save(resource_bar, "ui", "ui_resource_bar.png")

    # 回合按钮
    turn_btn = draw_ui_panel((120, 40), "下一回合")
    save(turn_btn, "ui", "ui_turn_button.png")

    # 单位信息框
    unit_info = draw_ui_panel((200, 160), "单位信息")
    save(unit_info, "ui", "ui_unit_info.png")

    # 城市面板
    city_panel = draw_ui_panel((240, 200), "城市面板")
    save(city_panel, "ui", "ui_city_panel.png")

    # 选中高亮
    highlight_select = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(highlight_select)
    draw.polygon(hex_points(16, 16, 14), fill=(255, 255, 100, 80))
    save(highlight_select, "ui", "ui_highlight_select.png")

    # 移动范围高亮
    highlight_move = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(highlight_move)
    draw.polygon(hex_points(16, 16, 14), fill=(100, 180, 255, 60))
    save(highlight_move, "ui", "ui_highlight_move.png")

    # 主菜单背景
    menu_bg = Image.new("RGBA", (800, 600), (0, 0, 0, 0))
    draw = ImageDraw.Draw(menu_bg)
    for y in range(600):
        r = 26 + y * 20 // 600
        g = 26 + y * 15 // 600
        b = 27 + y * 10 // 600
        draw.line([(0, y), (800, y)], fill=(r, g, b))
    try:
        font = ImageFont.truetype("msyh.ttc", 64)
        font_sm = ImageFont.truetype("msyh.ttc", 20)
    except:
        font = ImageFont.load_default()
        font_sm = font
    draw.text((400, 200), "山河策", fill=PALETTE["竹简黄"]["high"], font=font, anchor="mm")
    draw.text((400, 280), "至精至微，方显山河之策", fill=PALETTE["竹简黄"]["shadow"], font=font_sm, anchor="mm")
    save(menu_bg, "logo", "main_menu_bg.png")

    # Logo
    logo = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(logo)
    draw.ellipse([10, 10, 246, 246], fill=(*PALETTE["水墨黑"]["base"], 230))
    draw.ellipse([20, 20, 236, 236], fill=(*PALETTE["竹简黄"]["deep"], 200))
    try:
        font = ImageFont.truetype("msyh.ttc", 72)
    except:
        font = ImageFont.load_default()
    draw.text((128, 128), "山河策", fill=PALETTE["水墨黑"]["base"], font=font, anchor="mm")
    save(logo, "logo", "logo.png")

    print("\n=== 阶段 2:外交 UI ===")
    # 外交弹窗
    diplomacy_types = ["宣战", "停战", "通行权", "结盟", "赠礼"]
    for dt in diplomacy_types:
        panel = draw_ui_panel((280, 180), dt)
        save(panel, "diplomacy", f"diplomacy_{dt}.png")

    # 好感度条
    favor_bar = Image.new("RGBA", (200, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(favor_bar)
    for x in range(200):
        # -100 红 到 +100 绿
        ratio = x / 200
        r = int(180 * (1 - ratio))
        g = int(180 * ratio)
        draw.line([(x, 2), (x, 22)], fill=(r, g, 60))
    draw.line([(100, 0), (100, 24)], fill=(255, 255, 255), width=1)
    save(favor_bar, "diplomacy", "diplomacy_favor_bar.png")

    # 好感度表情
    favor_icons = {
        "hostile":  ("😠", PALETTE["漆器红"]),
        "unfriendly":("😐", PALETTE["青铜靛"]),
        "neutral":  ("😑", NATURE["山地"]),
        "friendly": ("🙂", NATURE["森林"]),
        "allied":   ("😊", PALETTE["竹简黄"]),
    }
    for key, (emoji, colors) in favor_icons.items():
        img = draw_icon((64, 64), emoji, colors)
        save(img, "diplomacy", f"favor_{key}.png")

    print("\n=== 阶段 2:君主头像 (256x256) ===")
    monarchs = {
        "qin":  ("秦王", "漆器红"),
        "zhao": ("赵王", "青铜靛"),
        "qi":   ("齐王", "竹简黄"),
        "chu":  ("楚王", "水墨黑"),
        "wei":  ("魏王", "青铜靛"),
        "yan":  ("燕王", "漆器红"),
        "han":  ("韩王", "竹简黄"),
    }
    for key, (name, pk) in monarchs.items():
        img = draw_portrait((256, 256), name, pk)
        save(img, "portrait", f"portrait_monarch_{key}.png")

    print("\n=== 阶段 4:名将立绘 (256x256) ===")
    generals = [
        ("商鞅", "漆器红"), ("乐毅", "青铜靛"), ("白起", "漆器红"),
        ("李牧", "青铜靛"), ("王翦", "漆器红"), ("廉颇", "青铜靛"),
        ("孙膑", "竹简黄"), ("吴起", "水墨黑"), ("庞涓", "青铜靛"),
        ("赵奢", "竹简黄"), ("蒙恬", "漆器红"), ("项燕", "水墨黑"),
        ("田单", "竹简黄"), ("信陵君", "青铜靛"), ("春申君", "竹简黄"),
    ]
    for name, pk in generals:
        img = draw_portrait((256, 256), name, pk)
        save(img, "portrait", f"portrait_general_{name}.png")

    print("\n=== 阶段 4:七国旗帜 (128x128) ===")
    flags = {
        "qin":  ("秦", PALETTE["漆器红"]["base"],     PALETTE["漆器红"]["high"]),
        "zhao": ("赵", PALETTE["青铜靛"]["base"],     PALETTE["青铜靛"]["high"]),
        "qi":   ("齐", NATURE["森林"]["base"],        NATURE["森林"]["high"]),
        "chu":  ("楚", PALETTE["竹简黄"]["base"],     PALETTE["竹简黄"]["high"]),
        "wei":  ("魏", PALETTE["水墨黑"]["high"],     PALETTE["竹简黄"]["high"]),
        "yan":  ("燕", NATURE["山地"]["base"],        NATURE["山地"]["high"]),
        "han":  ("韩", NATURE["河流"]["base"],        NATURE["河流"]["high"]),
    }
    for key, (emblem, bg, fg) in flags.items():
        img = draw_flag((128, 128), emblem, bg, fg)
        save(img, "flag", f"flag_{key}.png")

    print("\n=== 阶段 3:六大学派图标 (64x64) ===")
    schools = {
        "rujia":   ("儒", PALETTE["竹简黄"]),
        "fajia":   ("法", PALETTE["漆器红"]),
        "mojia":   ("墨", PALETTE["青铜靛"]),
        "daojia":  ("道", NATURE["森林"]),
        "bingjia": ("兵", PALETTE["水墨黑"]),
        "zongheng":("纵横", NATURE["山地"]),
    }
    for key, (symbol, colors) in schools.items():
        img = draw_icon((64, 64), symbol, colors)
        save(img, "icon", f"icon_school_{key}.png")

    print("\n=== 阶段 3:季节插图 (800x600) ===")
    for season in ["春", "夏", "秋", "冬"]:
        img = draw_season((800, 600), season)
        save(img, "season", f"season_{season}.png")

    print("\n=== 阶段 2 & 4:事件插画 (400x300) ===")
    events = [
        "缔约", "背盟", "纳贡",          # 阶段 2 外交事件
        "变法", "合纵", "连横",           # 学派事件
        "攻城", "伏击", "火攻", "断粮",   # 战斗事件
        "登基", "叛乱", "饥荒", "丰收",   # 内政事件
        "结盟", "宣战", "迁都", "称帝",   # 大事件
        "间谍", "朝贡", "改革", "围困",
        "突围", "投降", "灭国", "统一",
        "祭祀", "求贤", "筑城", "开河",
    ]
    event_palettes = [
        PALETTE["竹简黄"], PALETTE["漆器红"], PALETTE["青铜靛"],
        NATURE["森林"], NATURE["山地"], NATURE["河流"],
    ]
    for i, evt in enumerate(events):
        colors = event_palettes[i % len(event_palettes)]
        img = Image.new("RGBA", (400, 300), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        # 背景
        draw.rectangle([0, 0, 400, 300], fill=(*colors["deep"], 200))
        draw.rectangle([10, 10, 390, 290], fill=(*colors["shadow"], 180))
        # 装饰线
        draw.line([(20, 25), (380, 25)], fill=colors["high"], width=2)
        draw.line([(20, 275), (380, 275)], fill=colors["high"], width=2)
        # 事件名
        try:
            font = ImageFont.truetype("msyh.ttc", 36)
            font_sm = ImageFont.truetype("msyh.ttc", 14)
        except:
            font = ImageFont.load_default()
            font_sm = font
        draw.text((200, 140), evt, fill=colors["high"], font=font, anchor="mm")
        draw.text((200, 180), "— 山河策 —", fill=(*colors["base"], 180), font=font_sm, anchor="mm")
        save(img, "event", f"event_{evt}.png")

    print("\n=== 阶段 5:战斗特效 (64x64) ===")
    effects = ["attack", "ambush", "fire", "flank", "cutoff", "defense", "culture", "siege"]
    for eff in effects:
        img = draw_effect((64, 64), eff)
        save(img, "effect", f"effect_{eff}.png")

    print("\n=== 阶段 5:攻破都城公告 (800x600) ===")
    announcement = Image.new("RGBA", (800, 600), (0, 0, 0, 0))
    draw = ImageDraw.Draw(announcement)
    # 暗红渐变背景
    for y in range(600):
        r = 40 + y * 20 // 600
        g = 15 + y * 5 // 600
        b = 10 + y * 5 // 600
        draw.line([(0, y), (800, y)], fill=(r, g, b))
    # 边框
    draw.rectangle([30, 30, 770, 570], outline=PALETTE["竹简黄"]["high"], width=3)
    draw.rectangle([40, 40, 760, 560], outline=PALETTE["竹简黄"]["base"], width=1)
    try:
        font_lg = ImageFont.truetype("msyh.ttc", 56)
        font_md = ImageFont.truetype("msyh.ttc", 24)
        font_sm = ImageFont.truetype("msyh.ttc", 16)
    except:
        font_lg = font_md = font_sm = ImageFont.load_default()
    draw.text((400, 200), "都城已破", fill=PALETTE["漆器红"]["high"], font=font_lg, anchor="mm")
    draw.text((400, 300), "山河易主，天下震动", fill=PALETTE["竹简黄"]["high"], font=font_md, anchor="mm")
    draw.text((400, 400), "至精至微，方显山河之策", fill=PALETTE["竹简黄"]["shadow"], font=font_sm, anchor="mm")
    save(announcement, "ui", "ui_announcement_conquest.png")

    # ── 统计 ─────────────────────────────────────────────
    print("\n" + "=" * 50)
    total = 0
    for d in DIRS:
        dp = os.path.join(ROOT, d)
        if os.path.isdir(dp):
            count = len([f for f in os.listdir(dp) if f.endswith(".png")])
            total += count
            print(f"  {d:12s} → {count:3d} 个文件")
    print(f"\n  {'总计':12s} → {total:3d} 个资产文件")
    print("=" * 50)
    print("生成完成！请在 photos/ 目录下查看所有资产。")


if __name__ == "__main__":
    generate_all()
