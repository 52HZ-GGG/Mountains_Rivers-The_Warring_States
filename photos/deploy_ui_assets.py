"""
《山河策》UI 素材部署 + 补全脚本
功能：
  1. 将 photos/ 中已生成的 UI/图标 复制到 assets/ 对应目录
  2. 生成缺失的按钮四态、资源图标、建筑图标、科技图标、战斗面板
运行: python deploy_ui_assets.py
"""

import os, shutil, math
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(ROOT, "..", "assets")

# ── 目录结构 ──
DIRS = [
    "ui/battle", "ui/buttons", "ui/icons", "ui/panels",
    "ui/highlights", "ui/overlays",
    "fonts", "shaders",
]
for d in DIRS:
    os.makedirs(os.path.join(ASSETS, d), exist_ok=True)

# ── 色板（与 generate_ui.py 一致） ──
INK = {"b": (26,26,27), "h": (51,51,52), "s": (13,13,14), "d": (0,0,0)}
BAM = {"b": (197,163,104), "h": (217,190,139), "s": (153,122,74), "d": (102,82,49)}
LAC = {"b": (140,69,34), "h": (176,93,59), "s": (102,48,24), "d": (64,29,15)}
BRO = {"b": (43,51,48), "h": (69,82,77), "s": (26,33,30), "d": (13,18,16)}

RES_COLORS = {
    "food":    (180,170,90),
    "gold":    (200,180,100),
    "iron":    (160,160,170),
    "horse":   (140,110,70),
    "refined": (180,185,195),
    "morale":  (80,160,70),
    "pop":     (70,120,170),
    "troops":  (176,93,59),
}
BUILDING_TYPES = [
    "farm", "mine", "wall", "barracks", "market",
    "academy", "stable", "forge", "granary", "temple",
]
TECH_CATEGORIES = ["military", "economy", "culture", "infrastructure"]


def pb(d, x, y, w, h, c):
    d.rectangle([x, y, x+w-1, y+h-1], fill=c)


def save(img, path):
    img.save(path)
    print(f"  [OK] {os.path.relpath(path, ASSETS)}")


# ══════════════════════════════════════════════════════════
#  第一步：复制已有素材
# ══════════════════════════════════════════════════════════
def copy_existing():
    print("=== 复制已有素材到 assets/ ===\n")
    pairs = [
        # 面板
        ("ui/ui_city_panel.png",         "ui/panels/ui_city_panel.png"),
        ("ui/ui_diplomacy_panel.png",    "ui/panels/ui_diplomacy_panel.png"),
        ("ui/ui_tech_panel.png",         "ui/panels/ui_tech_panel.png"),
        ("ui/ui_school_panel.png",       "ui/panels/ui_school_panel.png"),
        ("ui/ui_settings.png",           "ui/panels/ui_settings.png"),
        ("ui/ui_save_load.png",          "ui/panels/ui_save_load.png"),
        ("ui/ui_new_game.png",           "ui/panels/ui_new_game.png"),
        ("ui/ui_victory.png",            "ui/panels/ui_victory.png"),
        ("ui/ui_defeat.png",             "ui/panels/ui_defeat.png"),
        ("ui/ui_unit_info.png",          "ui/panels/ui_unit_info.png"),
        ("ui/ui_announcement_conquest.png", "ui/panels/ui_announcement_conquest.png"),
        ("ui/ui_season_banner.png",      "ui/panels/ui_season_banner.png"),
        # 地图 UI
        ("ui/ui_highlight_select.png",   "ui/highlights/ui_highlight_select.png"),
        ("ui/ui_highlight_move.png",     "ui/highlights/ui_highlight_move.png"),
        ("ui/ui_resource_bar.png",       "ui/overlays/ui_resource_bar.png"),
        ("ui/ui_turn_button.png",        "ui/buttons/ui_turn_button.png"),
        # 学派图标
        ("icon/icon_confucianism.png",   "ui/icons/icon_confucianism.png"),
        ("icon/icon_legalism.png",       "ui/icons/icon_legalism.png"),
        ("icon/icon_mohism.png",         "ui/icons/icon_mohism.png"),
        ("icon/icon_taoism.png",         "ui/icons/icon_taoism.png"),
        ("icon/icon_military.png",       "ui/icons/icon_military.png"),
        ("icon/icon_diplomacy.png",      "ui/icons/icon_diplomacy.png"),
        # 季节图标
        ("season/season_spring.png",     "ui/icons/icon_season_spring.png"),
        ("season/season_summer.png",     "ui/icons/icon_season_summer.png"),
        ("season/season_autumn.png",     "ui/icons/icon_season_autumn.png"),
        ("season/season_winter.png",     "ui/icons/icon_season_winter.png"),
    ]
    for src_rel, dst_rel in pairs:
        src = os.path.join(ROOT, src_rel)
        dst = os.path.join(ASSETS, dst_rel)
        if os.path.exists(src):
            shutil.copy2(src, dst)
            print(f"  [CP] {src_rel} -> {dst_rel}")
        else:
            print(f"  [SKIP] {src_rel} (不存在)")


# ══════════════════════════════════════════════════════════
#  第二步：生成按钮四态
# ══════════════════════════════════════════════════════════
def gen_button_state(d, x, y, w, h, state):
    """绘制按钮的四种状态"""
    if state == "normal":
        pb(d, x, y, w, h, BRO["d"])
        pb(d, x+1, y+1, w-2, h-2, BAM["d"])
        pb(d, x+2, y+2, w-4, h-4, INK["s"])
        pb(d, x+2, y+2, w-4, 1, BRO["h"])
    elif state == "hover":
        pb(d, x, y, w, h, BRO["d"])
        pb(d, x+1, y+1, w-2, h-2, BAM["b"])
        pb(d, x+2, y+2, w-4, h-4, INK["h"])
        pb(d, x+2, y+2, w-4, 1, BAM["h"])
    elif state == "pressed":
        pb(d, x, y, w, h, BRO["d"])
        pb(d, x+1, y+1, w-2, h-2, BAM["s"])
        pb(d, x+2, y+2, w-4, h-4, INK["d"])
        pb(d, x+2, y+h-3, w-4, 1, BRO["h"])
    elif state == "disabled":
        pb(d, x, y, w, h, BRO["s"])
        pb(d, x+1, y+1, w-2, h-2, INK["s"])
        pb(d, x+2, y+2, w-4, h-4, INK["d"])


def gen_buttons():
    print("\n=== 生成按钮四态 ===\n")
    w, h = 120, 36
    for state in ["normal", "hover", "pressed", "disabled"]:
        img = Image.new("RGBA", (w, h), (0,0,0,0))
        d = ImageDraw.Draw(img)
        gen_button_state(d, 0, 0, w, h, state)
        save(img, os.path.join(ASSETS, f"ui/buttons/btn_{state}.png"))

    # 小按钮变体
    sw, sh = 80, 28
    for state in ["normal", "hover", "pressed", "disabled"]:
        img = Image.new("RGBA", (sw, sh), (0,0,0,0))
        d = ImageDraw.Draw(img)
        gen_button_state(d, 0, 0, sw, sh, state)
        save(img, os.path.join(ASSETS, f"ui/buttons/btn_small_{state}.png"))


# ══════════════════════════════════════════════════════════
#  第三步：生成资源图标（24x24）
# ══════════════════════════════════════════════════════════
def draw_icon_grain(d, cx, cy):
    """谷穗"""
    c = RES_COLORS["food"]
    for dy in range(-5, 2):
        for dx in [-2, -1, 0, 1, 2]:
            if abs(dx) + abs(dy+2) <= 4:
                d.point((cx+dx, cy+dy), fill=c)
    d.point((cx, cy+3), fill=BAM["s"])
    d.point((cx, cy+4), fill=BAM["s"])

def draw_icon_gold(d, cx, cy):
    """方孔钱"""
    c = RES_COLORS["gold"]
    d.ellipse([cx-5, cy-5, cx+5, cy+5], outline=c, width=1)
    d.rectangle([cx-2, cy-2, cx+2, cy+2], fill=INK["b"])

def draw_icon_iron(d, cx, cy):
    """铁锭"""
    c = RES_COLORS["iron"]
    d.polygon([(cx-5, cy+3), (cx+5, cy+3), (cx+4, cy-3), (cx-4, cy-3)], fill=c)
    d.point((cx, cy-2), fill=(190,190,200))

def draw_icon_horse(d, cx, cy):
    """马头"""
    c = RES_COLORS["horse"]
    # 头
    pb(d, cx-2, cy-5, 5, 4, c)
    pb(d, cx-3, cy-3, 3, 6, c)
    # 耳
    d.point((cx-1, cy-6), fill=c)
    d.point((cx+2, cy-6), fill=c)
    # 身
    pb(d, cx-1, cy+2, 6, 3, c)

def draw_icon_refined(d, cx, cy):
    """精铁（亮色铁锭）"""
    c = RES_COLORS["refined"]
    d.polygon([(cx-4, cy+3), (cx+4, cy+3), (cx+3, cy-3), (cx-3, cy-3)], fill=c)
    d.point((cx-1, cy-1), fill=(220,225,235))
    d.point((cx, cy-2), fill=(230,235,245))

def draw_icon_morale(d, cx, cy):
    """民心（心形）"""
    c = RES_COLORS["morale"]
    d.point((cx-2, cy-3), fill=c)
    d.point((cx+2, cy-3), fill=c)
    for dx in range(-3, 4):
        for dy in range(-2, 3):
            if abs(dx) + abs(dy) <= 3:
                d.point((cx+dx, cy+dy), fill=c)
    d.point((cx, cy+3), fill=c)

def draw_icon_pop(d, cx, cy):
    """人口（人形）"""
    c = RES_COLORS["pop"]
    d.point((cx, cy-4), fill=c)
    pb(d, cx-2, cy-2, 5, 4, c)
    pb(d, cx-4, cy+1, 3, 4, c)
    pb(d, cx+2, cy+1, 3, 4, c)

def draw_icon_troops(d, cx, cy):
    """兵力（剑）"""
    c = RES_COLORS["troops"]
    for i in range(8):
        d.point((cx-4+i, cy-4+i), fill=c)
    d.point((cx+4, cy-4), fill=LAC["h"])
    # 剑格
    pb(d, cx-1, cy, 3, 1, BAM["h"])


ICON_DRAWERS = {
    "food":    draw_icon_grain,
    "gold":    draw_icon_gold,
    "iron":    draw_icon_iron,
    "horse":   draw_icon_horse,
    "refined": draw_icon_refined,
    "morale":  draw_icon_morale,
    "pop":     draw_icon_pop,
    "troops":  draw_icon_troops,
}

def gen_resource_icons():
    print("\n=== 生成资源图标 (24x24) ===\n")
    sz = 24
    for name, drawer in ICON_DRAWERS.items():
        img = Image.new("RGBA", (sz, sz), (0,0,0,0))
        d = ImageDraw.Draw(img)
        drawer(d, 12, 12)
        save(img, os.path.join(ASSETS, f"ui/icons/icon_{name}.png"))


# ══════════════════════════════════════════════════════════
#  第四步：生成建筑图标（24x24）
# ══════════════════════════════════════════════════════════
def draw_building_farm(d, cx, cy):
    pb(d, cx-6, cy+2, 12, 6, BAM["s"])
    for dx in [-4, -1, 2, 5]:
        pb(d, cx+dx, cy-4, 2, 6, RES_COLORS["food"])

def draw_building_mine(d, cx, cy):
    d.polygon([(cx-6,cy+6),(cx+6,cy+6),(cx+3,cy-4),(cx-3,cy-4)], fill=RES_COLORS["iron"])
    pb(d, cx-1, cy-6, 2, 4, BAM["s"])

def draw_building_wall(d, cx, cy):
    pb(d, cx-6, cy-2, 12, 8, BRO["b"])
    for x in [cx-6, cx-2, cx+2]:
        pb(d, x, cy-5, 3, 3, BRO["b"])
    pb(d, cx-1, cy+2, 2, 4, INK["b"])

def draw_building_barracks(d, cx, cy):
    pb(d, cx-6, cy-2, 12, 8, BRO["b"])
    pb(d, cx-5, cy-1, 10, 6, BRO["h"])
    d.point((cx, cy-4), fill=LAC["b"])
    pb(d, cx-1, cy+2, 2, 4, INK["b"])

def draw_building_market(d, cx, cy):
    pb(d, cx-6, cy, 12, 6, BAM["b"])
    pb(d, cx-5, cy+1, 10, 4, BAM["h"])
    d.ellipse([cx-3, cy-5, cx+3, cy+1], fill=BAM["h"])
    d.point((cx, cy-3), fill=RES_COLORS["gold"])

def draw_building_academy(d, cx, cy):
    pb(d, cx-6, cy, 12, 6, BAM["b"])
    for i in range(3):
        pb(d, cx-4+i*4, cy-4, 2, 4, BAM["s"])
    pb(d, cx-1, cy-6, 2, 2, BRO["h"])

def draw_building_stable(d, cx, cy):
    pb(d, cx-6, cy, 12, 6, BAM["s"])
    pb(d, cx-5, cy+1, 10, 4, BAM["b"])
    draw_icon_horse(d, cx, cy-2)

def draw_building_forge(d, cx, cy):
    pb(d, cx-5, cy, 10, 6, BRO["b"])
    pb(d, cx-4, cy+1, 8, 4, LAC["b"])
    d.point((cx, cy-2), fill=(255,200,80))
    d.point((cx-1, cy-3), fill=(255,180,60))

def draw_building_granary(d, cx, cy):
    d.ellipse([cx-5, cy-3, cx+5, cy+5], fill=BAM["b"])
    d.ellipse([cx-4, cy-2, cx+4, cy+4], fill=BAM["h"])
    pb(d, cx-6, cy+3, 12, 3, BAM["s"])
    d.point((cx, cy-4), fill=BAM["s"])

def draw_building_temple(d, cx, cy):
    pb(d, cx-6, cy+1, 12, 5, BRO["b"])
    d.polygon([(cx-7,cy+1),(cx+7,cy+1),(cx,cy-6)], fill=LAC["b"])
    d.point((cx, cy-2), fill=LAC["h"])
    pb(d, cx-1, cy+2, 2, 4, INK["b"])

BUILDING_DRAWERS = [
    draw_building_farm, draw_building_mine, draw_building_wall,
    draw_building_barracks, draw_building_market, draw_building_academy,
    draw_building_stable, draw_building_forge, draw_building_granary,
    draw_building_temple,
]

def gen_building_icons():
    print("\n=== 生成建筑图标 (24x24) ===\n")
    sz = 24
    for name, drawer in zip(BUILDING_TYPES, BUILDING_DRAWERS):
        img = Image.new("RGBA", (sz, sz), (0,0,0,0))
        d = ImageDraw.Draw(img)
        drawer(d, 12, 12)
        save(img, os.path.join(ASSETS, f"ui/icons/icon_building_{name}.png"))


# ══════════════════════════════════════════════════════════
#  第五步：生成科技图标（32x32）
# ══════════════════════════════════════════════════════════
def draw_tech_military(d, cx, cy):
    """军事科技：盾+剑"""
    d.polygon([(cx,cy-6),(cx+5,cy-2),(cx+4,cy+5),(cx-4,cy+5),(cx-5,cy-2)],
              fill=BRO["b"], outline=BRO["h"])
    for i in range(8):
        d.point((cx-4+i, cy-8+i), fill=RES_COLORS["iron"])

def draw_tech_economy(d, cx, cy):
    """经济科技：方孔钱+谷穗"""
    d.ellipse([cx-6, cy-6, cx+6, cy+6], outline=RES_COLORS["gold"], width=1)
    d.rectangle([cx-2, cy-2, cx+2, cy+2], fill=INK["b"])
    for dy in range(-3, 0):
        for dx in [-1, 0, 1]:
            d.point((cx+dx+5, cy+dy+4), fill=RES_COLORS["food"])

def draw_tech_culture(d, cx, cy):
    """文化科技：竹简"""
    for i in range(5):
        y = cy - 6 + i * 3
        pb(d, cx-6, y, 12, 2, BAM["b"])
    pb(d, cx-7, cy-7, 2, 14, BAM["s"])
    pb(d, cx+5, cy-7, 2, 14, BAM["s"])

def draw_tech_infra(d, cx, cy):
    """基础科技：桥"""
    pb(d, cx-8, cy, 16, 3, BAM["s"])
    for x in [cx-6, cx-2, cx+2]:
        pb(d, x, cy+3, 2, 4, BAM["d"])
    d.arc([cx-8, cy-5, cx+8, cy+1], 180, 360, fill=BAM["b"], width=2)

TECH_DRAWERS = [draw_tech_military, draw_tech_economy, draw_tech_culture, draw_tech_infra]

def gen_tech_icons():
    print("\n=== 生成科技图标 (32x32) ===\n")
    sz = 32
    for name, drawer in zip(TECH_CATEGORIES, TECH_DRAWERS):
        img = Image.new("RGBA", (sz, sz), (0,0,0,0))
        d = ImageDraw.Draw(img)
        drawer(d, 16, 16)
        save(img, os.path.join(ASSETS, f"ui/icons/icon_tech_{name}.png"))


# ══════════════════════════════════════════════════════════
#  第六步：生成攻击范围高亮（红色变体）
# ══════════════════════════════════════════════════════════
def gen_attack_highlight():
    print("\n=== 生成攻击范围高亮 ===\n")
    sz = 32
    img = Image.new("RGBA", (sz, sz), (0,0,0,0))
    d = ImageDraw.Draw(img)
    hr = 15
    cx, cy = 16, 16
    verts = [(cx + hr * math.cos(math.radians(60*i)),
              cy + hr * math.sin(math.radians(60*i))) for i in range(6)]
    d.polygon([(int(x),int(y)) for x,y in verts], fill=(220,80,80,80))
    d.polygon([(int(x),int(y)) for x,y in verts], outline=(220,80,80,150), width=1)
    save(img, os.path.join(ASSETS, "ui/highlights/ui_highlight_attack.png"))


# ══════════════════════════════════════════════════════════
#  第七步：生成文化覆盖层基础图块
# ══════════════════════════════════════════════════════════
def gen_culture_overlay():
    print("\n=== 生成文化覆盖层 ===\n")
    sz = 32
    img = Image.new("RGBA", (sz, sz), (0,0,0,0))
    d = ImageDraw.Draw(img)
    hr = 15
    cx, cy = 16, 16
    verts = [(cx + hr * math.cos(math.radians(60*i)),
              cy + hr * math.sin(math.radians(60*i))) for i in range(6)]
    # 纯白色半透明，运行时通过 Shader/modulate 染色
    d.polygon([(int(x),int(y)) for x,y in verts], fill=(255,255,255,60))
    save(img, os.path.join(ASSETS, "ui/overlays/tile_culture_overlay.png"))


# ══════════════════════════════════════════════════════════
#  第八步：生成战斗面板
# ══════════════════════════════════════════════════════════
def panel(d, x, y, w, h):
    pb(d, x, y, w, h, BRO["d"])
    pb(d, x+1, y+1, w-2, h-2, BAM["d"])
    pb(d, x+2, y+2, w-4, h-4, INK["s"])
    pb(d, x+3, y+3, w-6, 1, BRO["h"])

def bar_fill(d, x, y, w, h, ratio, color):
    fill_w = max(1, int(w * ratio))
    pb(d, x, y, fill_w, h, color)
    if fill_w < w:
        pb(d, x+fill_w, y, w-fill_w, h, INK["d"])

# 简易 5x7 像素字体（仅数字和少量字母）
FONT = {
    '0': [0b01110,0b10001,0b10011,0b10101,0b11001,0b10001,0b01110],
    '1': [0b00100,0b01100,0b00100,0b00100,0b00100,0b00100,0b01110],
    '2': [0b01110,0b10001,0b00001,0b00110,0b01000,0b10000,0b11111],
    '3': [0b11111,0b00010,0b00100,0b00010,0b00001,0b10001,0b01110],
    '4': [0b00010,0b00110,0b01010,0b10010,0b11111,0b00010,0b00010],
    '5': [0b11111,0b10000,0b11110,0b00001,0b00001,0b10001,0b01110],
    '6': [0b00110,0b01000,0b10000,0b11110,0b10001,0b10001,0b01110],
    '7': [0b11111,0b00001,0b00010,0b00100,0b01000,0b01000,0b01000],
    '8': [0b01110,0b10001,0b10001,0b01110,0b10001,0b10001,0b01110],
    '9': [0b01110,0b10001,0b10001,0b01111,0b00001,0b00010,0b01100],
    '/': [0b00001,0b00010,0b00010,0b00100,0b01000,0b01000,0b10000],
    ' ': [0,0,0,0,0,0,0],
    'A': [0b01110,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001],
    'B': [0b11110,0b10001,0b10001,0b11110,0b10001,0b10001,0b11110],
    'C': [0b01110,0b10001,0b10000,0b10000,0b10000,0b10001,0b01110],
    'D': [0b11100,0b10010,0b10001,0b10001,0b10001,0b10010,0b11100],
    'E': [0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b11111],
    'F': [0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b10000],
    'G': [0b01110,0b10001,0b10000,0b10111,0b10001,0b10001,0b01110],
    'H': [0b10001,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001],
    'I': [0b01110,0b00100,0b00100,0b00100,0b00100,0b00100,0b01110],
    'K': [0b10001,0b10010,0b10100,0b11000,0b10100,0b10010,0b10001],
    'L': [0b10000,0b10000,0b10000,0b10000,0b10000,0b10000,0b11111],
    'M': [0b10001,0b11011,0b10101,0b10001,0b10001,0b10001,0b10001],
    'N': [0b10001,0b11001,0b10101,0b10011,0b10001,0b10001,0b10001],
    'O': [0b01110,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110],
    'P': [0b11110,0b10001,0b10001,0b11110,0b10000,0b10000,0b10000],
    'R': [0b11110,0b10001,0b10001,0b11110,0b10100,0b10010,0b10001],
    'S': [0b01110,0b10001,0b10000,0b01110,0b00001,0b10001,0b01110],
    'T': [0b11111,0b00100,0b00100,0b00100,0b00100,0b00100,0b00100],
    'U': [0b10001,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110],
    'V': [0b10001,0b10001,0b10001,0b10001,0b01010,0b01010,0b00100],
    'W': [0b10001,0b10001,0b10001,0b10101,0b10101,0b11011,0b10001],
    'X': [0b10001,0b10001,0b01010,0b00100,0b01010,0b10001,0b10001],
    'Y': [0b10001,0b10001,0b01010,0b00100,0b00100,0b00100,0b00100],
}

def draw_text(d, x, y, text, color, scale=1):
    cx = x
    for ch in text:
        if ch in FONT:
            glyph = FONT[ch]
            for row in range(7):
                bits = glyph[row]
                for col in range(5):
                    if bits & (1 << (4 - col)):
                        if scale == 1:
                            d.point((cx+col, y+row), fill=color)
                        else:
                            pb(d, cx+col*scale, y+row*scale, scale, scale, color)
            cx += 6 * scale
        else:
            cx += 4 * scale


def gen_battle_panel():
    print("\n=== 生成战斗面板 ===\n")
    img = Image.new("RGBA", (320, 200), (0,0,0,0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, 320, 200)
    # 标题栏
    pb(d, 3, 3, 314, 14, BRO["s"])
    draw_text(d, 8, 5, "BATTLE", (217,190,139))
    # 攻方
    draw_text(d, 10, 22, "ATTACKER:", (120,110,95))
    draw_text(d, 10, 34, "QIN RUSHI", (180,170,150))
    draw_text(d, 10, 44, "HP", (120,110,95))
    bar_fill(d, 30, 45, 100, 6, 0.8, (80,160,70))
    draw_text(d, 135, 44, "80/100", (180,170,150))
    draw_text(d, 10, 56, "ATK 45", (180,170,150))
    draw_text(d, 80, 56, "DEF 38", (180,170,150))
    # 分隔线
    pb(d, 8, 68, 304, 1, BAM["d"])
    # 守方
    draw_text(d, 10, 74, "DEFENDER:", (120,110,95))
    draw_text(d, 10, 86, "ZHAO HUFU", (180,170,150))
    draw_text(d, 10, 96, "HP", (120,110,95))
    bar_fill(d, 30, 97, 100, 6, 0.5, (80,160,70))
    draw_text(d, 135, 96, "45/90", (180,170,150))
    draw_text(d, 10, 108, "ATK 42", (180,170,150))
    draw_text(d, 80, 108, "DEF 35", (180,170,150))
    # 分隔线
    pb(d, 8, 120, 304, 1, BAM["d"])
    # 战斗结果预览
    draw_text(d, 10, 126, "PREDICTION:", (120,110,95))
    draw_text(d, 10, 138, "ATK WIN 72%", (100,160,80))
    draw_text(d, 10, 148, "DMG: 35-42", (180,170,150))
    draw_text(d, 150, 148, "LOSS: 8-12", (176,93,59))
    # 按钮
    pb(d, 60, 165, 80, 22, LAC["b"])
    pb(d, 61, 166, 78, 20, LAC["h"])
    draw_text(d, 78, 170, "ATTACK", (217,190,139))
    pb(d, 180, 165, 80, 22, BRO["s"])
    pb(d, 181, 166, 78, 20, BRO["h"])
    draw_text(d, 198, 170, "RETREAT", (180,170,150))
    save(img, os.path.join(ASSETS, "ui/battle/ui_battle_panel.png"))


# ══════════════════════════════════════════════════════════
#  第九步：生成事件弹窗
# ══════════════════════════════════════════════════════════
def gen_event_popup():
    print("\n=== 生成事件弹窗 ===\n")
    img = Image.new("RGBA", (280, 180), (0,0,0,0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, 280, 180)
    pb(d, 3, 3, 274, 14, BRO["s"])
    draw_text(d, 8, 5, "EVENT", (217,190,139))
    # 事件图标区
    pb(d, 15, 25, 48, 48, BRO["s"])
    pb(d, 16, 26, 46, 46, INK["b"])
    draw_text(d, 28, 38, "HARVEST", (180,170,90))
    # 事件描述
    draw_text(d, 70, 28, "BUMPER HARVEST!", (217,190,139))
    draw_text(d, 70, 40, "GRAIN OUTPUT +30%", (180,170,150))
    draw_text(d, 70, 52, "FOR 3 TURNS", (120,110,95))
    # 分隔线
    pb(d, 8, 80, 264, 1, BAM["d"])
    # 效果详情
    draw_text(d, 10, 86, "EFFECTS:", (120,110,95))
    draw_text(d, 10, 98, "GRAIN +30", (100,160,80))
    draw_text(d, 100, 98, "MORALE +5", (100,160,80))
    # 按钮
    pb(d, 50, 130, 70, 22, LAC["b"])
    draw_text(d, 60, 135, "ACCEPT", (217,190,139))
    pb(d, 160, 130, 70, 22, BRO["s"])
    draw_text(d, 170, 135, "IGNORE", (180,170,150))
    save(img, os.path.join(ASSETS, "ui/panels/ui_event_popup.png"))


# ══════════════════════════════════════════════════════════
#  主函数
# ══════════════════════════════════════════════════════════
def main():
    print("╔══════════════════════════════════════╗")
    print("║  《山河策》UI 素材部署 + 补全脚本    ║")
    print("╚══════════════════════════════════════╝\n")

    copy_existing()
    gen_buttons()
    gen_resource_icons()
    gen_building_icons()
    gen_tech_icons()
    gen_attack_highlight()
    gen_culture_overlay()
    gen_battle_panel()
    gen_event_popup()

    print("\n" + "="*50)
    print("部署完成！assets/ 目录结构：")
    for dirpath, dirnames, filenames in os.walk(ASSETS):
        level = dirpath.replace(ASSETS, "").count(os.sep)
        indent = "  " * level
        print(f"{indent}{os.path.basename(dirpath)}/")
        if level < 3:
            for f in sorted(filenames):
                if not f.endswith(".import"):
                    print(f"{indent}  {f}")
    print(f"\n共生成/部署 {sum(1 for _,_,fs in os.walk(ASSETS) for f in fs if not f.endswith('.import'))} 个文件")


if __name__ == "__main__":
    main()
