"""生成《山河策》战斗场景占位图（水墨像素风格）"""
from PIL import Image, ImageDraw, ImageFont
import random

random.seed(42)

# === 色板（低饱和大地色）===
PALETTE = {
    "竹简黄":     (210, 190, 140),
    "竹简黄暗":   (180, 160, 115),
    "墨绿":       (55, 75, 55),
    "墨绿浅":     (80, 105, 75),
    "赭石":       (150, 90, 60),
    "赭石暗":     (110, 65, 45),
    "靛青":       (50, 80, 110),
    "靛青浅":     (75, 110, 145),
    "深靛青":     (30, 50, 75),
    "极深":       (26, 33, 30),
    "墨色":       (35, 35, 40),
    "水墨灰":     (90, 90, 95),
    "白":         (240, 235, 225),
    "红":         (180, 55, 50),
    "红暗":       (140, 40, 35),
    "金":         (200, 170, 90),
    "金暗":       (165, 135, 65),
}

TILE = 32
COLS, ROWS = 16, 11
W, H = COLS * TILE, ROWS * TILE

# === 地图布局 (0=平原 1=山脉 2=河流 3=森林) ===
TERRAIN = [
    [0,0,0,3,3,0,0,0,0,0,0,1,1,0,0,0],
    [0,0,3,3,0,0,0,0,0,0,1,1,1,0,0,0],
    [0,0,0,0,0,0,0,2,0,0,0,1,1,0,0,0],
    [0,0,0,0,0,0,2,2,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,2,2,0,0,0,0,0,0,3,0,0],
    [0,0,0,0,0,2,2,0,0,0,0,0,3,3,0,0],
    [0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0],
    [0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0],
    [0,3,3,0,0,0,0,0,0,0,1,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
]


def draw_tile_plain(draw, x, y):
    """平原：竹简黄底 + 散点噪声"""
    base = PALETTE["竹简黄"]
    for py in range(TILE):
        for px in range(TILE):
            c = base
            if random.random() < 0.12:
                c = PALETTE["竹简黄暗"]
            if random.random() < 0.03:
                c = PALETTE["墨色"]
            draw.point((x + px, y + py), fill=c)


def draw_tile_forest(draw, x, y):
    """森林：墨绿底 + 簇状抖动（飞白效果）"""
    for py in range(TILE):
        for px in range(TILE):
            c = PALETTE["墨绿"]
            if random.random() < 0.2:
                c = PALETTE["墨绿浅"]
            if random.random() < 0.08:
                c = PALETTE["极深"]
            # 簇状抖动：2x2 像素簇
            if random.random() < 0.06:
                for dy in range(2):
                    for dx in range(2):
                        if px + dx < TILE and py + dy < TILE:
                            draw.point((x + px + dx, y + py + dy), fill=PALETTE["竹简黄暗"])
            draw.point((x + px, y + py), fill=c)
    # 树冠轮廓
    for _ in range(3):
        tx = x + random.randint(4, TILE - 6)
        ty = y + random.randint(4, TILE - 6)
        r = random.randint(4, 7)
        draw.ellipse([tx - r, ty - r, tx + r, ty + r], fill=PALETTE["墨绿浅"], outline=PALETTE["极深"])


def draw_tile_mountain(draw, x, y):
    """山脉：赭石底 + 岩石层理 + 脊线"""
    for py in range(TILE):
        for px in range(TILE):
            c = PALETTE["赭石"]
            if random.random() < 0.15:
                c = PALETTE["赭石暗"]
            if random.random() < 0.05:
                c = PALETTE["极深"]
            draw.point((x + px, y + py), fill=c)
    # 岩石层理（横线）
    for layer_y in [8, 16, 24]:
        for px in range(TILE):
            if random.random() < 0.7:
                draw.point((x + px, y + layer_y), fill=PALETTE["极深"])
    # 脊线
    ridge_y = y + 6
    for px in range(x + 4, x + TILE - 4):
        if random.random() < 0.8:
            draw.point((px, ridge_y), fill=PALETTE["墨色"])
            draw.point((px, ridge_y + 1), fill=PALETTE["赭石暗"])
    # 6px 厚度层（底部）
    for py in range(TILE - 6, TILE):
        for px in range(TILE):
            c = PALETTE["赭石暗"]
            if random.random() < 0.2:
                c = PALETTE["极深"]  # 泥土颗粒感
            if py in (TILE - 4, TILE - 2) and random.random() < 0.5:
                c = PALETTE["极深"]  # 岩石层理
            draw.point((x + px, y + py), fill=c)


def draw_tile_river(draw, x, y):
    """河流：靛青底 + 斜向波纹 + 深度渐变"""
    for py in range(TILE):
        depth = py / TILE
        r = int(50 + depth * 20)
        g = int(80 + depth * 30)
        b = int(110 + depth * 35)
        for px in range(TILE):
            c = (r, g, b)
            # 斜向波纹（循环偏移）
            wave = (px + py * 2) % 8
            if wave < 2:
                c = PALETTE["靛青浅"]
            if random.random() < 0.05:
                c = PALETTE["深靛青"]
            draw.point((x + px, y + py), fill=c)
    # 底部 2px 高光（阳光透射）
    for px in range(TILE):
        if random.random() < 0.3:
            draw.point((x + px, y + TILE - 2), fill=(255, 255, 240, 25))
            draw.point((x + px, y + TILE - 1), fill=(255, 255, 240, 15))
    # 6px 厚度层
    for py in range(TILE - 6, TILE):
        for px in range(TILE):
            c = PALETTE["深靛青"]
            if random.random() < 0.1:
                c = PALETTE["靛青"]
            draw.point((x + px, y + py), fill=c)


def draw_shadow(img, x, y):
    """山脉投射阴影（右侧/下方 2px 半透明）"""
    draw = ImageDraw.Draw(img)
    for py in range(TILE):
        for px in range(2):
            sx = x + TILE + px
            sy = y + py
            if 0 <= sx < W and 0 <= sy < H:
                orig = img.getpixel((sx, sy))
                if len(orig) == 4:
                    orig = orig[:3]
                blended = tuple(int(c * 0.85) for c in orig)
                draw.point((sx, sy), fill=blended)


def draw_unit(draw, cx, cy, color_main, color_accent, label):
    """绘制单位（简化像素小人 + 旗帜）"""
    # 身体
    draw.rectangle([cx - 3, cy - 6, cx + 3, cy + 2], fill=color_main, outline=PALETTE["极深"])
    # 头
    draw.ellipse([cx - 3, cy - 10, cx + 3, cy - 5], fill=PALETTE["竹简黄"], outline=PALETTE["极深"])
    # 武器（戈/矛）
    draw.line([cx + 4, cy - 8, cx + 4, cy + 4], fill=PALETTE["墨色"], width=1)
    draw.polygon([(cx + 4, cy - 8), (cx + 7, cy - 6), (cx + 4, cy - 4)], fill=PALETTE["水墨灰"])
    # 旗帜
    draw.rectangle([cx - 6, cy - 14, cx - 5, cy - 6], fill=PALETTE["墨色"])
    draw.rectangle([cx - 10, cy - 14, cx - 6, cy - 10], fill=color_accent)
    # 底座阴影
    draw.ellipse([cx - 4, cy + 2, cx + 4, cy + 4], fill=PALETTE["墨色"])


def draw_hp_bar(draw, cx, cy, hp_ratio):
    """血条"""
    bar_w = 16
    bar_x = cx - bar_w // 2
    draw.rectangle([bar_x, cy - 13, bar_x + bar_w, cy - 11], outline=PALETTE["极深"], fill=PALETTE["墨色"])
    fill_w = int(bar_w * hp_ratio)
    bar_color = PALETTE["红"] if hp_ratio < 0.4 else PALETTE["金"]
    draw.rectangle([bar_x + 1, cy - 12, bar_x + fill_w, cy - 11], fill=bar_color)


def draw_edge_bleeding(draw, x, y, terrain_type, neighbors):
    """边缘融合：平原/森林交界处 2-3px 混合"""
    for py in range(TILE):
        for px in range(TILE):
            if random.random() < 0.04:
                if terrain_type == 0 and any(n == 3 for n in neighbors):
                    draw.point((x + px, y + py), fill=PALETTE["墨绿"])
                elif terrain_type == 3 and any(n == 0 for n in neighbors):
                    draw.point((x + px, y + py), fill=PALETTE["竹简黄暗"])


# === 主绘制 ===
img = Image.new("RGBA", (W, H), PALETTE["竹简黄"])
draw = ImageDraw.Draw(img)

TILE_FUNCS = {
    0: draw_tile_plain,
    1: draw_tile_mountain,
    2: draw_tile_river,
    3: draw_tile_forest,
}

# 绘制地形
for row in range(ROWS):
    for col in range(COLS):
        t = TERRAIN[row][col]
        x, y = col * TILE, row * TILE
        TILE_FUNCS[t](draw, x, y)
        # 边缘融合
        neighbors = []
        if col > 0: neighbors.append(TERRAIN[row][col - 1])
        if col < COLS - 1: neighbors.append(TERRAIN[row][col + 1])
        if row > 0: neighbors.append(TERRAIN[row - 1][col])
        if row < ROWS - 1: neighbors.append(TERRAIN[row + 1][col])
        draw_edge_bleeding(draw, x, y, t, neighbors)

# 山脉阴影
for row in range(ROWS):
    for col in range(COLS):
        if TERRAIN[row][col] == 1:
            if col < COLS - 1 and TERRAIN[row][col + 1] != 1:
                draw_shadow(img, col * TILE, row * TILE)
            if row < ROWS - 1 and TERRAIN[row + 1][col] != 1:
                draw_shadow(img, col * TILE, row * TILE)

draw = ImageDraw.Draw(img)

# === 部署单位 ===
# 秦（左侧，红方）
qin_units = [
    (2, 3, 0.8), (2, 5, 1.0), (2, 7, 0.6),
    (4, 4, 0.9), (4, 6, 0.7),
    (6, 5, 0.5),
]
# 楚（右侧，金方）
chu_units = [
    (13, 2, 0.9), (13, 4, 1.0), (13, 6, 0.7),
    (11, 3, 0.8), (11, 5, 0.6),
    (9, 4, 0.5),
]

for col, row, hp in qin_units:
    cx, cy = col * TILE + TILE // 2, row * TILE + TILE // 2
    draw_unit(draw, cx, cy, PALETTE["红"], PALETTE["红暗"], "秦")
    draw_hp_bar(draw, cx, cy, hp)

for col, row, hp in chu_units:
    cx, cy = col * TILE + TILE // 2, row * TILE + TILE // 2
    draw_unit(draw, cx, cy, PALETTE["金"], PALETTE["金暗"], "楚")
    draw_hp_bar(draw, cx, cy, hp)

# === UI 覆盖层 ===
# 顶部信息栏
draw.rectangle([0, 0, W, 20], fill=(30, 30, 35, 200))
draw.rectangle([0, 20, W, 21], fill=PALETTE["金暗"])

# 尝试加载字体
try:
    font = ImageFont.truetype("msyh.ttc", 12)
except:
    try:
        font = ImageFont.truetype("simhei.ttf", 12)
    except:
        font = ImageFont.load_default()

draw.text((8, 3), "回合 5  |  秦 vs 楚  |  邯郸之战", fill=PALETTE["白"], font=font)
draw.text((W - 100, 3), "行动: 3/6", fill=PALETTE["金"], font=font)

# 底部状态栏
draw.rectangle([0, H - 28, W, H], fill=(30, 30, 35, 200))
draw.rectangle([0, H - 28, W, H - 27], fill=PALETTE["赭石暗"])
draw.text((8, H - 24), "选中: 秦锐士  攻:12 防:8 移:3  [兵家]", fill=PALETTE["白"], font=font)
draw.text((W - 80, H - 24), "士气: 85%", fill=PALETTE["金"], font=font)

# 保存
out = "e:/虚拟C盘/shanhece/assets/sprites/battle_scene_preview.png"
img.save(out)
print(f"战斗场景图已保存: {out}")
print(f"尺寸: {W}x{H} 像素")
