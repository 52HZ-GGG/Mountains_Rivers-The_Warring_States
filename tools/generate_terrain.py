"""
《山河策》地形图块生成器
生成9种地形的32x32像素图块，战国低饱和暖色调
"""
import os
import random
from PIL import Image, ImageDraw

# === 调色板（32色以内，低饱和暖色调）===
PALETTE = {
    # 地面色
    "earth_light": (200, 180, 100),   # 浅土黄
    "earth_mid": (168, 148, 84),      # 中土黄
    "earth_dark": (136, 116, 68),     # 深土黄
    # 草地
    "grass_light": (122, 140, 60),    # 浅草绿
    "grass_mid": (96, 116, 48),       # 中草绿
    "grass_dark": (72, 92, 36),       # 深草绿
    # 树木
    "trunk": (107, 78, 50),           # 树干棕
    "canopy_light": (90, 124, 72),    # 浅树叶
    "canopy_mid": (60, 92, 40),       # 中树叶
    "canopy_dark": (40, 68, 28),      # 深树叶
    # 山石
    "stone_light": (180, 180, 180),   # 浅灰
    "stone_mid": (140, 140, 140),     # 中灰
    "stone_dark": (100, 100, 100),    # 深灰
    "stone_shadow": (72, 72, 72),     # 石影
    # 水
    "water_light": (92, 160, 188),    # 浅水蓝
    "water_mid": (60, 124, 156),      # 中水蓝
    "water_dark": (44, 92, 124),      # 深水蓝
    "water_foam": (180, 210, 220),    # 水沫白
    # 沼泽
    "mud_light": (140, 156, 104),     # 浅泥
    "mud_mid": (107, 124, 72),        # 中泥
    "mud_dark": (74, 92, 60),         # 深泥
    # 木头
    "wood_light": (168, 132, 80),     # 浅木
    "wood_mid": (136, 104, 60),       # 中木
    "wood_dark": (100, 76, 44),       # 深木
    # 建筑
    "wall_light": (188, 172, 148),    # 浅墙
    "wall_mid": (156, 140, 116),      # 中墙
    "wall_dark": (124, 108, 88),      # 深墙
    # 强调色
    "accent_red": (168, 72, 60),      # 红旗/火
    "accent_gold": (212, 180, 80),    # 金色
    "accent_dark": (48, 36, 28),      # 深黑棕
    # 雪/冰
    "snow": (220, 228, 236),          # 雪白
    "ice": (180, 208, 224),           # 冰蓝
}

T = PALETTE  # 简写

# === 工具函数 ===

def new_canvas():
    """创建32x32透明画布"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)

def fill_bg(draw, color):
    """填充背景"""
    draw.rectangle([0, 0, 31, 31], fill=color)

def px(draw, x, y, color):
    """画单个像素"""
    if 0 <= x < 32 and 0 <= y < 32:
        draw.point((x, y), fill=color)

def rect(draw, x1, y1, x2, y2, color):
    """画矩形"""
    draw.rectangle([x1, y1, x2, y2], fill=color)

def add_noise(img, intensity=8):
    """给图像添加轻微噪点，增加像素画质感"""
    pixels = img.load()
    random.seed(42)  # 固定种子保证可复现
    for y in range(32):
        for x in range(32):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            n = random.randint(-intensity, intensity)
            pixels[x, y] = (
                max(0, min(255, r + n)),
                max(0, min(255, g + n)),
                max(0, min(255, b + n)),
                a
            )

def save(img, path):
    """保存图片"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(f"  [OK] {os.path.basename(path)}")

# === 地形图块生成函数 ===

def gen_plains():
    """平原：浅土黄底 + 草丛点缀"""
    img, draw = new_canvas()
    fill_bg(draw, T["earth_light"])
    # 散布草丛
    grass_positions = [
        (3,5),(8,3),(14,7),(20,4),(26,6),
        (5,12),(11,15),(18,11),(24,14),(29,10),
        (2,20),(9,22),(16,19),(22,23),(28,21),
        (6,27),(13,29),(20,26),(25,28),(30,27),
    ]
    for gx, gy in grass_positions:
        px(draw, gx, gy, T["grass_mid"])
        px(draw, gx, gy-1, T["grass_light"])
        if gx+1 < 32:
            px(draw, gx+1, gy, T["grass_dark"])
    # 小花点缀
    flowers = [(7,9),(19,17),(27,25)]
    for fx, fy in flowers:
        px(draw, fx, fy, T["accent_gold"])
    add_noise(img, 6)
    return img

def gen_forest():
    """森林：深绿底 + 多棵树"""
    img, draw = new_canvas()
    fill_bg(draw, T["grass_dark"])
    # 画3-4棵树
    trees = [(6,10), (16,8), (26,12), (11,22), (22,24)]
    for tx, ty in trees:
        # 树干
        rect(draw, tx, ty+2, tx+1, ty+4, T["trunk"])
        # 树冠（三角形近似）
        rect(draw, tx-1, ty, tx+2, ty+1, T["canopy_mid"])
        rect(draw, tx-2, ty-2, tx+3, ty-1, T["canopy_light"])
        px(draw, tx, ty-3, T["canopy_dark"])
        px(draw, tx+1, ty-3, T["canopy_dark"])
    # 地面杂草
    for gx in range(0, 32, 4):
        for gy in range(0, 32, 5):
            if random.random() > 0.5:
                px(draw, gx+1, gy+3, T["grass_mid"])
    add_noise(img, 7)
    return img

def gen_mountain():
    """山地：灰色基调 + 三角山峰"""
    img, draw = new_canvas()
    fill_bg(draw, T["stone_mid"])
    # 大山峰（中间偏左）
    for row in range(12):
        y = 14 - row
        half = row + 2
        cx = 10
        for x in range(max(0, cx-half), min(32, cx+half+1)):
            if row < 3:
                px(draw, x, y, T["snow"])
            elif row < 6:
                px(draw, x, y, T["stone_light"])
            else:
                px(draw, x, y, T["stone_mid"])
    # 小山峰（右侧）
    for row in range(8):
        y = 18 - row
        half = row + 1
        cx = 24
        for x in range(max(0, cx-half), min(32, cx+half+1)):
            if row < 2:
                px(draw, x, y, T["stone_light"])
            else:
                px(draw, x, y, T["stone_dark"])
    # 山脚阴影
    for x in range(32):
        if 24 <= x <= 30:
            px(draw, x, 28, T["stone_shadow"])
        if 4 <= x <= 18:
            px(draw, x, 26, T["stone_shadow"])
    add_noise(img, 5)
    return img

def gen_river():
    """河流：蓝色水面 + 波纹"""
    img, draw = new_canvas()
    fill_bg(draw, T["water_mid"])
    # 水流纹理（斜向波纹）
    for y in range(32):
        for x in range(32):
            if (x + y) % 6 == 0:
                px(draw, x, y, T["water_light"])
            elif (x + y) % 6 == 3:
                px(draw, x, y, T["water_dark"])
    # 浪花
    foam = [(4,3),(12,7),(20,11),(28,15),(8,19),(16,23),(24,27),(4,31)]
    for fx, fy in foam:
        px(draw, fx, fy, T["water_foam"])
        px(draw, fx+1, fy, T["water_foam"])
    # 深水区
    for y in range(14, 18):
        for x in range(32):
            if random.random() > 0.6:
                px(draw, x, y, T["water_dark"])
    add_noise(img, 5)
    return img

def gen_marsh():
    """沼泽：泥泞底 + 水洼 + 芦苇"""
    img, draw = new_canvas()
    fill_bg(draw, T["mud_mid"])
    # 水洼
    puddles = [(5,8,9,12), (18,20,24,25), (8,26,12,30)]
    for x1, y1, x2, y2 in puddles:
        rect(draw, x1, y1, x2, y2, T["water_dark"])
        px(draw, x1+1, y1+1, T["water_mid"])
    # 泥地纹理
    for y in range(0, 32, 3):
        for x in range(0, 32, 3):
            if random.random() > 0.5:
                px(draw, x, y, T["mud_dark"])
            else:
                px(draw, x, y, T["mud_light"])
    # 芦苇
    reeds = [(2,4),(14,3),(28,6),(10,18),(26,16)]
    for rx, ry in reeds:
        rect(draw, rx, ry, rx, ry+4, T["grass_dark"])
        px(draw, rx, ry-1, T["grass_light"])
        px(draw, rx, ry-2, T["grass_mid"])
    add_noise(img, 8)
    return img

def gen_pass():
    """关隘：两侧山墙 + 中间通道"""
    img, draw = new_canvas()
    fill_bg(draw, T["stone_mid"])
    # 左侧山墙
    for y in range(32):
        for x in range(0, 10):
            if x < 6:
                px(draw, x, y, T["stone_dark"])
            else:
                px(draw, x, y, T["stone_mid"])
    # 右侧山墙
    for y in range(32):
        for x in range(22, 32):
            if x > 25:
                px(draw, x, y, T["stone_dark"])
            else:
                px(draw, x, y, T["stone_mid"])
    # 中间通道（地面）
    rect(draw, 10, 0, 21, 31, T["earth_mid"])
    # 城墙横跨通道
    rect(draw, 8, 10, 23, 13, T["wall_mid"])
    rect(draw, 9, 11, 22, 12, T["wall_light"])
    # 城门洞
    rect(draw, 14, 10, 17, 13, T["accent_dark"])
    # 箭垛
    for bx in range(9, 23, 2):
        rect(draw, bx, 9, bx, 9, T["wall_dark"])
    # 旗帜
    rect(draw, 12, 6, 12, 10, T["wood_mid"])
    rect(draw, 13, 6, 15, 8, T["accent_red"])
    add_noise(img, 6)
    return img

def gen_ford():
    """渡口：浅水 + 石头汀步"""
    img, draw = new_canvas()
    fill_bg(draw, T["water_light"])
    # 浅水纹理
    for y in range(32):
        for x in range(32):
            if (x * 3 + y * 2) % 7 == 0:
                px(draw, x, y, T["water_mid"])
    # 汀步石头
    stones = [(6,8),(10,12),(14,16),(18,20),(22,24),(12,4),(20,8),(8,28)]
    for sx, sy in stones:
        rect(draw, sx, sy, sx+2, sy+1, T["stone_mid"])
        px(draw, sx+1, sy, T["stone_light"])
    # 两岸提示（上下边缘）
    for x in range(32):
        px(draw, x, 0, T["earth_mid"])
        px(draw, x, 1, T["grass_mid"])
        px(draw, x, 30, T["grass_mid"])
        px(draw, x, 31, T["earth_mid"])
    add_noise(img, 5)
    return img

def gen_plank_road():
    """栈道：山壁上的木板路"""
    img, draw = new_canvas()
    fill_bg(draw, T["stone_dark"])
    # 山壁纹理
    for y in range(32):
        for x in range(32):
            if random.random() > 0.7:
                px(draw, x, y, T["stone_mid"])
    # 木板路（横向贯穿）
    rect(draw, 0, 12, 31, 18, T["wood_mid"])
    # 木板纹理（竖向分割）
    for x in range(0, 32, 4):
        for y in range(12, 19):
            px(draw, x, y, T["wood_dark"])
    # 木板高光
    for x in range(0, 32, 4):
        px(draw, x+1, 13, T["wood_light"])
    # 护栏（上下）
    rect(draw, 0, 11, 31, 11, T["wood_dark"])
    rect(draw, 0, 19, 31, 19, T["wood_dark"])
    # 护栏柱
    for x in range(2, 32, 8):
        rect(draw, x, 10, x, 11, T["trunk"])
        rect(draw, x, 19, x, 20, T["trunk"])
    # 山壁上的草
    for x in range(0, 32, 6):
        px(draw, x, 8, T["grass_dark"])
        px(draw, x+1, 7, T["grass_mid"])
    add_noise(img, 7)
    return img

def gen_arrow_tower():
    """箭楼：山地隘口上的防御塔"""
    img, draw = new_canvas()
    fill_bg(draw, T["stone_mid"])
    # 底座山石
    rect(draw, 0, 22, 31, 31, T["stone_dark"])
    rect(draw, 2, 20, 29, 22, T["stone_mid"])
    # 塔身
    rect(draw, 11, 8, 20, 20, T["wall_mid"])
    rect(draw, 12, 9, 19, 19, T["wall_light"])
    # 塔顶
    rect(draw, 9, 5, 22, 8, T["wall_dark"])
    rect(draw, 10, 4, 21, 5, T["accent_dark"])
    # 箭窗
    rect(draw, 14, 11, 16, 14, T["accent_dark"])
    rect(draw, 14, 16, 16, 18, T["accent_dark"])
    # 旗帜
    rect(draw, 15, 1, 15, 5, T["wood_mid"])
    rect(draw, 16, 1, 19, 3, T["accent_red"])
    # 侧墙
    rect(draw, 8, 14, 11, 20, T["wall_mid"])
    rect(draw, 20, 14, 23, 20, T["wall_mid"])
    add_noise(img, 6)
    return img


# === 主程序 ===

def main():
    base = "E:/虚拟C盘/shanhece/assets/sprites/terrain"

    print("=== Generate Terrain Tiles ===")
    generators = {
        "tile_plain_01": gen_plains,
        "tile_forest_01": gen_forest,
        "tile_mountain_01": gen_mountain,
        "tile_river_01": gen_river,
        "tile_marsh_01": gen_marsh,
        "tile_pass_01": gen_pass,
        "tile_ford_01": gen_ford,
        "tile_plank_road_01": gen_plank_road,
        "tile_arrow_tower_01": gen_arrow_tower,
    }

    for name, gen_func in generators.items():
        img = gen_func()
        save(img, os.path.join(base, f"{name}.png"))

    print(f"\nDone! Generated {len(generators)} terrain tiles")


if __name__ == "__main__":
    main()
