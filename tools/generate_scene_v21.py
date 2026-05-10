"""
《山河策》V2.1 视觉优化验证场景生成器
展示：脊线连接、岩石断面、边缘融合、簇状抖动、统一阴影
输出: assets/sprites/terrain/scene_v21_verify.png (320x240)
"""
import os
import random
from PIL import Image, ImageDraw

random.seed(42)

# === 调色板 ===
PALETTE = {
    "earth_light": (200, 180, 100),
    "earth_mid": (168, 148, 84),
    "earth_dark": (136, 116, 68),
    "grass_light": (122, 140, 60),
    "grass_mid": (96, 116, 48),
    "grass_dark": (72, 92, 36),
    "trunk": (107, 78, 50),
    "canopy_light": (90, 124, 72),
    "canopy_mid": (60, 92, 40),
    "canopy_dark": (40, 68, 28),
    "stone_light": (180, 180, 180),
    "stone_mid": (140, 140, 140),
    "stone_dark": (100, 100, 100),
    "stone_shadow": (72, 72, 72),
    "stone_abyss": (26, 33, 30),       # V2.1 极深岩石层理
    "water_light": (92, 160, 188),
    "water_mid": (60, 124, 156),
    "water_dark": (44, 92, 124),
    "water_deep_indigo": (36, 56, 84), # V2.1 深靛青（替代纯黑）
    "water_bed_highlight": (56, 80, 108, 25),  # V2.1 河床高光 Alpha 0.1
    "water_foam": (180, 210, 220),
    "mud_light": (140, 156, 104),
    "mud_mid": (107, 124, 72),
    "mud_dark": (74, 92, 60),
    "wood_light": (168, 132, 80),
    "wood_mid": (136, 104, 60),
    "wood_dark": (100, 76, 44),
    "wall_light": (188, 172, 148),
    "wall_mid": (156, 140, 116),
    "wall_dark": (124, 108, 88),
    "accent_red": (168, 72, 60),
    "accent_gold": (212, 180, 80),
    "accent_dark": (48, 36, 28),
    "snow": (220, 228, 236),
    "shadow": (0, 0, 0, 38),           # V2.1 统一阴影 Alpha 0.15
}

T = PALETTE

# === 场景尺寸 ===
TILE = 32
COLS, ROWS = 10, 7
W, H = COLS * TILE, ROWS * TILE

# === 地形布局 (10x7) ===
# M=山地 P=平原 F=森林 R=河流
LAYOUT = [
    ["M","M","M","P","P","F","F","P","P","P"],
    ["M","M","M","P","P","F","F","P","P","P"],
    ["M","M","M","P","P","P","P","P","P","P"],
    ["P","P","P","P","R","R","P","P","M","M"],
    ["P","P","P","P","R","R","P","P","M","M"],
    ["P","P","P","P","R","R","P","P","P","P"],
    ["P","P","P","P","R","R","P","P","P","P"],
]


def clumped_dither(img, region, color_a, color_b, density=0.3):
    """V2.1 簇状抖动：2x2 或 1x2 像素簇模拟飞白"""
    pixels = img.load()
    x1, y1, x2, y2 = region
    for y in range(y1, y2, 2):
        for x in range(x1, x2, 2):
            if random.random() < density:
                # 2x2 簇
                for dy in range(2):
                    for dx in range(2):
                        nx, ny = x + dx, y + dy
                        if x1 <= nx < x2 and y1 <= ny < y2:
                            pixels[nx, ny] = color_b
            elif random.random() < density * 0.5:
                # 1x2 竖簇
                for dy in range(2):
                    ny = y + dy
                    if y1 <= ny < y2:
                        pixels[x, ny] = color_b


def add_edge_bleeding(img, mask, terrain_map):
    """V2.1 边缘抖动融合：不同地形交界处 2-3px 混合"""
    pixels = img.load()
    w, h = img.size
    blend_colors = {
        ("P", "F"): T["grass_mid"],
        ("F", "P"): T["grass_dark"],
        ("P", "M"): T["stone_light"],
        ("M", "P"): T["earth_dark"],
        ("R", "P"): T["water_light"],
        ("P", "R"): T["earth_mid"],
    }
    for y in range(h):
        for x in range(w):
            tx, ty = x // TILE, y // TILE
            if tx >= COLS or ty >= ROWS:
                continue
            current = terrain_map[ty][tx]
            # 检查右邻和下邻
            for dx, dy in [(1, 0), (0, 1)]:
                nx, ny = tx + dx, ty + dy
                if 0 <= nx < COLS and 0 <= ny < ROWS:
                    neighbor = terrain_map[ny][nx]
                    if current != neighbor:
                        # 在边界 3px 内随机融合
                        edge_dist = 0
                        if dx == 1:
                            edge_dist = (tx + 1) * TILE - x
                        elif dy == 1:
                            edge_dist = (ty + 1) * TILE - y
                        if 0 < edge_dist <= 3 and random.random() < 0.4:
                            key = (current, neighbor)
                            if key in blend_colors:
                                pixels[x, y] = blend_colors[key]


def draw_mountain_tile(img, ox, oy):
    """山地：连贯脊线 + 岩石断面 + 阴影"""
    draw = ImageDraw.Draw(img)
    # 基底
    draw.rectangle([ox, oy, ox+31, oy+31], fill=T["stone_mid"])
    # 大山峰
    for row in range(14):
        y = oy + 16 - row
        half = row + 3
        cx = ox + 12
        for x in range(max(ox, cx - half), min(ox + 32, cx + half + 1)):
            if row < 3:
                draw.point((x, y), fill=T["snow"])
            elif row < 7:
                draw.point((x, y), fill=T["stone_light"])
            else:
                draw.point((x, y), fill=T["stone_mid"])
    # V2.1 岩石断面：6px 厚度层中插入极深层理线
    for y in range(oy + 24, oy + 30):
        for x in range(ox, ox + 32):
            draw.point((x, y), fill=T["stone_dark"])
        # 层理线
        if y in (oy + 26, oy + 28):
            for x in range(ox + 2, ox + 30):
                if random.random() > 0.2:
                    draw.point((x, y), fill=T["stone_abyss"])


def draw_mountain_ridge_connect(img, terrain_map):
    """V2.1 山脉脊线连接：相邻山地对齐脊线"""
    draw = ImageDraw.Draw(img)
    for ty in range(ROWS):
        for tx in range(COLS):
            if terrain_map[ty][tx] != "M":
                continue
            # 检查右邻
            if tx + 1 < COLS and terrain_map[ty][tx + 1] == "M":
                boundary_x = (tx + 1) * TILE
                # 在共享边界处画连接脊线
                for dy in range(8, 18):
                    y = ty * TILE + dy
                    draw.point((boundary_x - 1, y), fill=T["stone_light"])
                    draw.point((boundary_x, y), fill=T["stone_light"])
            # 检查下邻
            if ty + 1 < ROWS and terrain_map[ty + 1][tx] == "M":
                boundary_y = (ty + 1) * TILE
                for dx in range(6, 20):
                    x = tx * TILE + dx
                    draw.point((x, boundary_y - 1), fill=T["stone_light"])
                    draw.point((x, boundary_y), fill=T["stone_light"])


def draw_plains_tile(img, ox, oy):
    """平原：竹简黄底 + 草丛"""
    draw = ImageDraw.Draw(img)
    draw.rectangle([ox, oy, ox+31, oy+31], fill=T["earth_light"])
    # 草丛
    for i in range(8):
        gx = ox + random.randint(2, 29)
        gy = oy + random.randint(2, 29)
        draw.point((gx, gy), fill=T["grass_mid"])
        draw.point((gx, gy-1), fill=T["grass_light"])
    # V2.1 泥土断面：散点噪声模拟颗粒感
    pixels = img.load()
    for y in range(oy + 26, oy + 32):
        for x in range(ox, ox + 32):
            if random.random() < 0.2:
                pixels[x, y] = T["earth_dark"]


def draw_forest_tile(img, ox, oy):
    """森林"""
    draw = ImageDraw.Draw(img)
    draw.rectangle([ox, oy, ox+31, oy+31], fill=T["grass_dark"])
    # 树木
    trees = [(ox+8, oy+10), (ox+20, oy+8), (ox+14, oy+22)]
    for tx, ty in trees:
        draw.rectangle([tx, ty+2, tx+1, ty+4], fill=T["trunk"])
        draw.rectangle([tx-1, ty, tx+2, ty+1], fill=T["canopy_mid"])
        draw.rectangle([tx-2, ty-2, tx+3, ty-1], fill=T["canopy_light"])
        draw.point((tx, ty-3), fill=T["canopy_dark"])
    # 簇状抖动（飞白效果）
    clumped_dither(img, (ox, oy, ox+32, oy+32), T["grass_dark"], T["canopy_dark"], 0.15)


def draw_river_tile(img, ox, oy):
    """河流：连贯波纹 + 深靛青厚度层 + 河床高光"""
    draw = ImageDraw.Draw(img)
    draw.rectangle([ox, oy, ox+31, oy+31], fill=T["water_mid"])
    pixels = img.load()
    # V2.1 斜向流动波纹（循环偏移量）
    for y in range(oy, oy + 32):
        for x in range(ox, ox + 32):
            # 斜向引导线
            if (x + y) % 6 == 0:
                pixels[x, y] = T["water_light"]
            elif (x + y) % 6 == 3:
                pixels[x, y] = T["water_dark"]
    # V2.1 深靛青厚度层（禁止纯黑）
    for y in range(oy + 26, oy + 32):
        for x in range(ox, ox + 32):
            pixels[x, y] = T["water_deep_indigo"]
    # V2.1 河床高光（底部 2px，Alpha 0.1）
    for y in range(oy + 30, oy + 32):
        for x in range(ox, ox + 32):
            if random.random() < 0.3:
                r, g, b, a = pixels[x, y]
                highlight = T["water_bed_highlight"]
                blend_r = int(r * 0.9 + highlight[0] * 0.1)
                blend_g = int(g * 0.9 + highlight[1] * 0.1)
                blend_b = int(b * 0.9 + highlight[2] * 0.1)
                pixels[x, y] = (blend_r, blend_g, blend_b, 255)
    # 浪花
    foam_positions = [(ox+4, oy+3), (ox+16, oy+15), (ox+26, oy+25)]
    for fx, fy in foam_positions:
        draw.point((fx, fy), fill=T["water_foam"])
        draw.point((fx+1, fy), fill=T["water_foam"])


def draw_projected_shadows(img, terrain_map):
    """V2.1 统一阴影投射：山脉对右/下方平原投射 2px 半透明阴影"""
    pixels = img.load()
    shadow_color = T["shadow"]
    for ty in range(ROWS):
        for tx in range(COLS):
            if terrain_map[ty][tx] != "M":
                continue
            # 右侧阴影
            if tx + 1 < COLS and terrain_map[ty][tx + 1] in ("P", "F"):
                sx = (tx + 1) * TILE
                for dy in range(TILE):
                    y = ty * TILE + dy
                    for dx in range(2):
                        x = sx + dx
                        if x < W:
                            r, g, b, a = pixels[x, y]
                            sr, sg, sb, sa = shadow_color
                            blend = sa / 255.0
                            pixels[x, y] = (
                                int(r * (1 - blend) + sr * blend),
                                int(g * (1 - blend) + sg * blend),
                                int(b * (1 - blend) + sb * blend),
                                255
                            )
            # 下方阴影
            if ty + 1 < ROWS and terrain_map[ty + 1][tx] in ("P", "F"):
                sy = (ty + 1) * TILE
                for dx in range(TILE):
                    x = tx * TILE + dx
                    for dy in range(2):
                        y = sy + dy
                        if y < H:
                            r, g, b, a = pixels[x, y]
                            sr, sg, sb, sa = shadow_color
                            blend = sa / 255.0
                            pixels[x, y] = (
                                int(r * (1 - blend) + sr * blend),
                                int(g * (1 - blend) + sg * blend),
                                int(b * (1 - blend) + sb * blend),
                                255
                            )


def main():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # 按布局逐格绘制
    tile_funcs = {
        "M": draw_mountain_tile,
        "P": draw_plains_tile,
        "F": draw_forest_tile,
        "R": draw_river_tile,
    }
    for ty in range(ROWS):
        for tx in range(COLS):
            terrain = LAYOUT[ty][tx]
            ox, oy = tx * TILE, ty * TILE
            tile_funcs[terrain](img, ox, oy)

    # V2.1 全局优化 Pass
    draw_mountain_ridge_connect(img, LAYOUT)
    add_edge_bleeding(img, img, LAYOUT)
    draw_projected_shadows(img, LAYOUT)

    # 保存
    out_dir = "E:/虚拟C盘/shanhece/assets/sprites/terrain"
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "scene_v21_verify.png")
    img.save(out_path)
    print(f"[OK] V2.1 验证场景已保存: {out_path}")
    print(f"  尺寸: {W}x{H}")
    print(f"  包含优化: 脊线连接 / 岩石断面 / 边缘融合 / 簇状抖动 / 统一阴影")


if __name__ == "__main__":
    main()
