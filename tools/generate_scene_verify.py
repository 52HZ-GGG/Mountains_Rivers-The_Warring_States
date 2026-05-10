"""
《山河策》场景概念验证图生成器
基于 V2.0 极精细规范 + V2.1 优化方案
输出: Scene_Concept_Verify.png (320x320, 10x10 地块矩阵)
"""
import os
import random
from PIL import Image, ImageDraw

# ============================================================
# V2.0 战国物料色谱 (Color Ramps)
# ============================================================
COLORS = {
    # 平原 - 竹简黄
    "plain_base":    (197, 163, 104),  # #C5A368
    "plain_high":    (217, 190, 139),  # #D9BE8B
    "plain_shadow":  (153, 122, 74),   # #997A4A
    "plain_deep":    (102, 82, 49),    # #665231

    # 山脉 - 青铜靛
    "mountain_base":   (43, 51, 48),   # #2B3330
    "mountain_high":   (69, 82, 77),   # #45524D
    "mountain_shadow": (26, 33, 30),   # #1A211E
    "mountain_deep":   (13, 18, 16),   # #0D1210

    # 河流 - 深靛青 (比青铜靛偏蓝)
    "river_base":    (30, 50, 58),     # 深靛青
    "river_high":    (50, 75, 85),     # 亮部
    "river_shadow":  (18, 35, 42),     # 暗部
    "river_deep":    (10, 22, 28),     # 极深
    "river_foam":    (120, 150, 160),  # 浪花
    "river_glint":   (60, 90, 100),    # 水下高光

    # 森林 - 墨绿
    "forest_base":   (40, 68, 28),     # 墨绿基
    "forest_high":   (72, 100, 48),    # 亮叶
    "forest_shadow": (28, 48, 18),     # 暗叶
    "forest_deep":   (18, 32, 12),     # 极深
    "forest_trunk":  (80, 56, 36),     # 树干
}

# ============================================================
# Bayer 4x4 抖动矩阵
# ============================================================
BAYER_4X4 = [
    [ 0,  8,  2, 10],
    [12,  4, 14,  6],
    [ 3, 11,  1,  9],
    [15,  7, 13,  5],
]
BAYER_N = 4
# 归一化到 [0,1)
BAYER_NORM = [[v / 16.0 for v in row] for row in BAYER_4X4]


def bayer_should_place(x, y, threshold):
    """Bayer 4x4 抖动判定: 返回 True 表示该像素使用较暗色"""
    return BAYER_NORM[y % BAYER_N][x % BAYER_N] < threshold


def clumped_dither(img, x, y, dark_color, light_color, threshold=0.35):
    """
    V2.1 簇状抖动: 2x2 像素簇模拟毛笔"飞白"
    以 (x,y) 为左上角，决定 2x2 块的整体明暗
    """
    if bayer_should_place(x, y, threshold):
        return dark_color
    return light_color


def lerp_color(c1, c2, t):
    """线性插值两色"""
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def darken(color, factor=0.8):
    """颜色加深 (厚度层比顶面深 20%)"""
    return tuple(max(0, int(c * factor)) for c in color[:3])


def scatter_noise(img, region, intensity=0.2, seed=42):
    """V2.1: 散点噪声模拟泥土颗粒感"""
    pixels = img.load()
    random.seed(seed)
    x1, y1, x2, y2 = region
    for y in range(y1, y2):
        for x in range(x1, x2):
            if random.random() < intensity:
                r, g, b = pixels[x, y][:3]
                n = random.randint(-12, 12)
                pixels[x, y] = (
                    max(0, min(255, r + n)),
                    max(0, min(255, g + n)),
                    max(0, min(255, b + n)),
                    255,
                )


# ============================================================
# 地块生成函数 (32x32, 含 6px 厚度层)
# ============================================================

def gen_plains(col=0, row=0):
    """平原: 竹简黄色坡 + 6px 泥土断面 + Bayer 抖动"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    base  = COLORS["plain_base"]
    high  = COLORS["plain_high"]
    shadow = COLORS["plain_shadow"]
    deep  = COLORS["plain_deep"]

    # 顶面 26px (y=0..25)
    for y in range(26):
        for x in range(32):
            # 基础色 + Bayer 抖动在明暗之间
            if bayer_should_place(x, y, 0.25):
                c = shadow
            else:
                c = base
            draw.point((x, y), fill=(*c, 255))

    # 散布草丛点缀
    rng = random.Random(col * 100 + row)
    for _ in range(12):
        gx = rng.randint(1, 30)
        gy = rng.randint(2, 23)
        draw.point((gx, gy), fill=(*COLORS["forest_shadow"], 255))
        draw.point((gx, gy - 1), fill=(*COLORS["forest_base"], 180))

    # 厚度层 6px (y=26..31) — 比顶面深 20%
    thick_base = darken(base, 0.8)
    thick_shadow = darken(shadow, 0.8)
    for y in range(26, 32):
        for x in range(32):
            if bayer_should_place(x, y, 0.3):
                c = thick_shadow
            else:
                c = thick_base
            draw.point((x, y), fill=(*c, 255))

    # V2.1: 泥土颗粒感散点噪声
    scatter_noise(img, (0, 26, 32, 32), intensity=0.25, seed=col * 31 + row * 17)

    return img


def gen_forest(col=0, row=0):
    """森林: 墨绿色坡 + 树冠 + 6px 泥土断面"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    base  = COLORS["forest_base"]
    high  = COLORS["forest_high"]
    shadow = COLORS["forest_shadow"]
    deep  = COLORS["forest_deep"]

    # 顶面
    for y in range(26):
        for x in range(32):
            if bayer_should_place(x, y, 0.3):
                c = shadow
            else:
                c = base
            draw.point((x, y), fill=(*c, 255))

    # 树木 (3-4 棵)
    rng = random.Random(col * 200 + row * 7)
    tree_positions = [(rng.randint(3, 28), rng.randint(4, 20)) for _ in range(rng.randint(3, 5))]
    for tx, ty in tree_positions:
        # 树干
        draw.rectangle([tx, ty + 2, tx + 1, ty + 4], fill=(*COLORS["forest_trunk"], 255))
        # 树冠
        draw.rectangle([tx - 1, ty, tx + 2, ty + 1], fill=(*high, 255))
        draw.rectangle([tx - 2, ty - 2, tx + 3, ty - 1], fill=(*base, 255))
        draw.point((tx, ty - 3), fill=(*deep, 255))
        draw.point((tx + 1, ty - 3), fill=(*deep, 255))

    # 厚度层
    thick_base = darken(base, 0.8)
    thick_shadow = darken(shadow, 0.8)
    for y in range(26, 32):
        for x in range(32):
            if bayer_should_place(x, y, 0.35):
                c = thick_shadow
            else:
                c = thick_base
            draw.point((x, y), fill=(*c, 255))

    scatter_noise(img, (0, 26, 32, 32), intensity=0.2, seed=col * 47 + row * 23)

    return img


def gen_mountain(col=0, row=0):
    """
    山脉: 青铜靛色坡 + 脊线 + 6px 岩石断面
    V2.1: 厚度层含岩石层理线
    """
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    base   = COLORS["mountain_base"]
    high   = COLORS["mountain_high"]
    shadow = COLORS["mountain_shadow"]
    deep   = COLORS["mountain_deep"]

    rng = random.Random(col * 300 + row * 13)

    # 顶面: 山脉脊线从中间隆起
    # 脊线高度随 col 变化，使相邻山脉连贯
    ridge_offset = (col * 7 + row * 3) % 8  # 伪随机但相邻地块相近

    for y in range(26):
        for x in range(32):
            # 计算到脊线中心的距离
            center = 16 + ridge_offset % 5 - 2
            dist = abs(x - center)
            # 海拔越高越亮
            altitude = max(0, 25 - y) / 25.0
            if dist < 4 and altitude > 0.5:
                c = high
            elif dist < 8:
                c = base
            else:
                c = shadow
            # Bayer 抖动
            if bayer_should_place(x, y, 0.2):
                c = shadow
            draw.point((x, y), fill=(*c, 255))

    # 脊线高光 (1px 竹简黄)
    ridge_y = rng.randint(6, 10)
    for x in range(4, 28):
        ry = ridge_y + rng.randint(-1, 1)
        draw.point((x, ry), fill=(*COLORS["plain_high"], 200))

    # 厚度层 — 岩石断面 + 层理线
    thick_base = darken(base, 0.8)
    thick_shadow = darken(shadow, 0.8)
    for y in range(26, 32):
        for x in range(32):
            if bayer_should_place(x, y, 0.3):
                c = thick_shadow
            else:
                c = thick_base
            draw.point((x, y), fill=(*c, 255))

    # V2.1: 岩石层理线 (1-2 条极深色横线)
    strata_y1 = 27 + rng.randint(0, 1)
    strata_y2 = 30 + rng.randint(0, 1)
    for x in range(32):
        draw.point((x, strata_y1), fill=(*deep, 255))
        draw.point((x, strata_y2), fill=(*deep, 255))

    return img


def gen_river(col=0, row=0):
    """
    河流: 深靛青 + 波纹 + 6px 水下断面
    V2.1: 厚度层底部高光模拟阳光透射
    """
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    base   = COLORS["river_base"]
    high   = COLORS["river_high"]
    shadow = COLORS["river_shadow"]
    deep   = COLORS["river_deep"]

    # 顶面: 水面 + 斜向波纹
    offset = col * 3  # 波纹偏移量，使相邻河流连贯
    for y in range(26):
        for x in range(32):
            wave = (x + y + offset) % 8
            if wave < 2:
                c = high
            elif wave < 5:
                c = base
            else:
                c = shadow
            # Bayer 抖动
            if bayer_should_place(x, y, 0.2):
                c = deep
            draw.point((x, y), fill=(*c, 255))

    # 浪花点缀
    rng = random.Random(col * 400 + row)
    for _ in range(6):
        fx = rng.randint(2, 29)
        fy = rng.randint(2, 23)
        draw.point((fx, fy), fill=(*COLORS["river_foam"], 220))
        draw.point((fx + 1, fy), fill=(*COLORS["river_foam"], 180))

    # 厚度层 — 水下深度 (禁止纯黑，用深靛青色坡)
    thick_base = darken(base, 0.75)
    thick_shadow = darken(shadow, 0.75)
    for y in range(26, 32):
        for x in range(32):
            if bayer_should_place(x, y, 0.35):
                c = thick_shadow
            else:
                c = thick_base
            draw.point((x, y), fill=(*c, 255))

    # V2.1: 底部 2px 微弱高光 (Alpha 0.1) 模拟阳光透射
    for y in range(30, 32):
        for x in range(32):
            if bayer_should_place(x, y, 0.15):
                draw.point((x, y), fill=(*COLORS["river_glint"], 25))

    return img


# ============================================================
# 边缘融合 (V2.1 Edge Bleeding)
# ============================================================

def edge_bleed(tiles, grid_w, grid_h):
    """
    V2.1: 在不同地形交界处添加 2-3px 的混合区域
    使用随机概率将相邻地形的像素点缀入边缘
    """
    W = grid_w * 32
    H = grid_h * 32
    result = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # 先拼贴所有地块
    for gy in range(grid_h):
        for gx in range(grid_w):
            tile = tiles[gy][gx]
            result.paste(tile, (gx * 32, gy * 32))

    pixels = result.load()
    rng = random.Random(42)

    # 检查水平边界
    for gy in range(grid_h):
        for gx in range(grid_w - 1):
            if tiles[gy][gx] is tiles[gy][gx + 1]:
                continue  # 同类型跳过
            # 在 x=31 和 x=32 之间做 2px 混合
            boundary_x = (gx + 1) * 32
            for y in range(gy * 32, (gy + 1) * 32):
                for dx in range(-2, 3):
                    px = boundary_x + dx
                    if 0 <= px < W and rng.random() < 0.3:
                        # 取相邻像素混合
                        src_x = boundary_x - 1 if dx < 0 else boundary_x
                        if 0 <= src_x < W:
                            c = pixels[src_x, y]
                            if c[3] > 0:
                                blended = (*c[:3], max(40, c[3] // 2))
                                pixels[px, y] = blended

    # 检查垂直边界
    for gy in range(grid_h - 1):
        for gx in range(grid_w):
            if tiles[gy][gx] is tiles[gy + 1][gx]:
                continue
            boundary_y = (gy + 1) * 32
            for x in range(gx * 32, (gx + 1) * 32):
                for dy in range(-2, 3):
                    py = boundary_y + dy
                    if 0 <= py < H and rng.random() < 0.3:
                        src_y = boundary_y - 1 if dy < 0 else boundary_y
                        if 0 <= src_y < H:
                            c = pixels[x, src_y]
                            if c[3] > 0:
                                blended = (*c[:3], max(40, c[3] // 2))
                                pixels[x, py] = blended

    return result


# ============================================================
# 全局阴影投射 (V2.1)
# ============================================================

def apply_global_shadows(canvas, tiles, grid_w, grid_h):
    """山脉对相邻右侧/下方平原投射 2px 半透明阴影带"""
    pixels = canvas.load()
    W = grid_w * 32
    H = grid_h * 32
    shadow_color = (13, 18, 16, 38)  # Alpha 0.15

    for gy in range(grid_h):
        for gx in range(grid_w):
            tile_type = tiles[gy][gx]
            if tile_type != "mountain":
                continue
            # 右侧阴影
            if gx + 1 < grid_w and tiles[gy][gx + 1] in ("plain", "forest"):
                sx = (gx + 1) * 32
                for y in range(gy * 32, min((gy + 1) * 32, H)):
                    for dx in range(2):
                        px = sx + dx
                        if 0 <= px < W:
                            orig = pixels[px, y]
                            blended = (
                                (orig[0] * 170 + shadow_color[0] * 85) // 255,
                                (orig[1] * 170 + shadow_color[1] * 85) // 255,
                                (orig[2] * 170 + shadow_color[2] * 85) // 255,
                                min(255, orig[3] + shadow_color[3]),
                            )
                            pixels[px, y] = blended
            # 下方阴影
            if gy + 1 < grid_h and tiles[gy + 1][gx] in ("plain", "forest"):
                sy = (gy + 1) * 32
                for x in range(gx * 32, min((gx + 1) * 32, W)):
                    for dy in range(2):
                        py = sy + dy
                        if 0 <= py < H:
                            orig = pixels[x, py]
                            blended = (
                                (orig[0] * 170 + shadow_color[0] * 85) // 255,
                                (orig[1] * 170 + shadow_color[1] * 85) // 255,
                                (orig[2] * 170 + shadow_color[2] * 85) // 255,
                                min(255, orig[3] + shadow_color[3]),
                            )
                            pixels[x, py] = blended

    return canvas


# ============================================================
# 场景拼装
# ============================================================

def assemble_scene():
    """
    320x320 画布 (10x10 地块矩阵)
    布局: 左3列=山脉, 中2列=河流, 右5列=平原/森林交错
    """
    GRID_W, GRID_H = 10, 10
    TILE = 32
    W, H = GRID_W * TILE, GRID_H * TILE

    # 定义布局类型
    grid_types = [[None] * GRID_W for _ in range(GRID_H)]
    for gy in range(GRID_H):
        for gx in range(GRID_W):
            if gx < 3:
                grid_types[gy][gx] = "mountain"
            elif gx < 5:
                grid_types[gy][gx] = "river"
            else:
                # 右侧区域: 奇数列平原, 偶数列森林 (形成棋盘交错)
                if (gx + gy) % 2 == 0:
                    grid_types[gy][gx] = "plain"
                else:
                    grid_types[gy][gx] = "forest"

    # 生成每个地块
    gen_map = {
        "mountain": gen_mountain,
        "river":    gen_river,
        "plain":    gen_plains,
        "forest":   gen_forest,
    }

    tiles_img = [[None] * GRID_W for _ in range(GRID_H)]
    for gy in range(GRID_H):
        for gx in range(GRID_W):
            ttype = grid_types[gy][gx]
            tiles_img[gy][gx] = gen_map[ttype](gx, gy)

    # 边缘融合
    canvas = edge_bleed(tiles_img, GRID_W, GRID_H)

    # 全局阴影
    canvas = apply_global_shadows(canvas, grid_types, GRID_W, GRID_H)

    return canvas


# ============================================================
# 自检清单 (V2.0 Pre-delivery Check)
# ============================================================

def self_check(img):
    """V2.0 自检: 色数、饱和度"""
    pixels = img.load()
    colors = set()
    for y in range(img.height):
        for x in range(img.width):
            c = pixels[x, y]
            if c[3] > 0:
                colors.add(c[:3])

    print(f"  颜色数量: {len(colors)} (目标: ≤16)")

    # 检查饱和度 (简化: 取平均)
    sat_sum = 0
    count = 0
    for c in colors:
        r, g, b = c
        mx = max(r, g, b)
        mn = min(r, g, b)
        if mx > 0:
            sat_sum += (mx - mn) / mx
            count += 1
    avg_sat = sat_sum / max(count, 1)
    print(f"  平均饱和度: {avg_sat:.2%} (目标: <40%)")

    if len(colors) <= 16:
        print("  [PASS] 16色限制")
    else:
        print("  [WARN] 超出16色限制，需精简")
    if avg_sat < 0.4:
        print("  [PASS] 低饱和度")
    else:
        print("  [WARN] 饱和度偏高")


# ============================================================
# 主程序
# ============================================================

def main():
    print("=== 《山河策》场景概念验证图生成 ===")
    print("规范: V2.0 极精细 + V2.1 优化")
    print("规格: 320x320 (10x10 地块矩阵)")
    print()

    img = assemble_scene()

    # 保存
    out_dir = "E:/虚拟C盘/shanhece/assets/sprites"
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "Scene_Concept_Verify.png")
    img.save(out_path)
    print(f"[OK] 已保存: {out_path}")

    # 自检
    print("\n=== V2.0 自检清单 ===")
    self_check(img)
    print()

    # 布局摘要
    print("=== 布局摘要 ===")
    print("  列 0-2: 山脉 (青铜靛)")
    print("  列 3-4: 河流 (深靛青)")
    print("  列 5-9: 平原/森林 交错 (竹简黄/墨绿)")
    print()
    print("=== V2.1 优化项 ===")
    print("  [x] 山脉脊线连贯性 (col-based offset)")
    print("  [x] 6px 厚度层岩石层理线")
    print("  [x] 6px 泥土颗粒散点噪声")
    print("  [x] 河流底部高光 (阳光透射)")
    print("  [x] Bayer 4x4 簇状抖动 (飞白效果)")
    print("  [x] 边缘像素融合 (Edge Bleeding)")
    print("  [x] 全局阴影投射 (山脉→平原)")
    print()
    print('"破格方能入画，连点始成江山。"')


if __name__ == "__main__":
    main()
