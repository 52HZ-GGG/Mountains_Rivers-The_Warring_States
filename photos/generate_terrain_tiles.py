"""
生成《山河策》地形图块 - 1024x1024 像素风（增强细节版）
flat-top 六边形：左右顶点，上下平行边
先在 256x256 像素画布上绘制，再 4x 放大到 1024x1024
"""

from PIL import Image, ImageDraw
import random
import math
import os

random.seed(42)

# === 调色板（战国低饱和暖色调，扩展色系）===
PALETTE = {
    # 大地色系
    "grass_light":    (168, 180, 110),
    "grass_mid":      (138, 155, 88),
    "grass_dark":     (108, 128, 68),
    "grass_shadow":   (82, 100, 50),
    "grass_bright":   (190, 200, 130),
    "grass_warm":     (155, 165, 95),
    "earth_light":    (180, 155, 110),
    "earth_mid":      (145, 120, 82),
    "earth_dark":     (110, 88, 58),
    "earth_shadow":   (80, 62, 40),
    "earth_warm":     (160, 135, 95),
    "path_dust":      (170, 148, 105),
    # 石头/山地
    "stone_light":    (165, 155, 140),
    "stone_mid":      (130, 120, 108),
    "stone_dark":     (98, 90, 78),
    "stone_shadow":   (70, 64, 55),
    "stone_warm":     (148, 138, 120),
    "stone_cold":     (115, 112, 105),
    "cliff_face":     (120, 110, 95),
    "scree":          (142, 132, 118),
    "snow":           (210, 210, 205),
    "snow_shadow":    (185, 188, 190),
    # 水
    "water_light":    (120, 160, 175),
    "water_mid":      (90, 130, 150),
    "water_dark":     (65, 100, 120),
    "water_deep":     (45, 75, 95),
    "water_foam":     (185, 200, 195),
    "water_shallow":  (140, 175, 180),
    "water_murky":    (80, 105, 85),
    "water_reed":     (100, 130, 100),
    # 树木
    "tree_light":     (88, 128, 65),
    "tree_mid":       (65, 100, 48),
    "tree_dark":      (45, 72, 32),
    "tree_deep":      (30, 55, 22),
    "trunk":          (85, 60, 38),
    "trunk_dark":     (60, 42, 25),
    "trunk_light":    (105, 78, 50),
    "leaf_highlight": (120, 155, 85),
    "bark":           (95, 70, 45),
    # 建筑/关隘
    "wall_light":     (175, 160, 135),
    "wall_mid":       (140, 125, 100),
    "wall_dark":      (105, 92, 72),
    "wall_worn":      (155, 142, 120),
    "roof":           (120, 55, 35),
    "roof_dark":      (88, 38, 22),
    "roof_light":     (145, 72, 48),
    "banner_red":     (165, 45, 35),
    "banner_faded":   (140, 65, 55),
    # 特殊
    "marsh_green":    (110, 125, 75),
    "marsh_dark":     (75, 90, 52),
    "marsh_light":    (130, 145, 90),
    "mud":            (120, 95, 60),
    "mud_wet":        (90, 72, 45),
    "flower_yellow":  (210, 190, 80),
    "flower_pink":    (195, 130, 130),
    "flower_white":   (220, 215, 200),
    "flower_purple":  (140, 100, 145),
    "plank":          (155, 120, 72),
    "plank_dark":     (115, 85, 48),
    "plank_worn":     (135, 105, 62),
    "plank_light":    (170, 138, 88),
    "bush":           (95, 115, 60),
    "bush_dark":      (70, 90, 42),
    "reed":           (115, 130, 75),
    "reed_dry":       (150, 140, 100),
    "moss":           (85, 105, 60),
    "torch_glow":     (220, 180, 100),
    "flag_red":       (180, 50, 40),
    "flag_gold":      (200, 175, 90),
}

RENDER_SIZE = 256
FINAL_SIZE = 1024
SCALE = FINAL_SIZE // RENDER_SIZE


def make_hex_mask(size):
    """创建 flat-top 六边形遮罩，返回 (mask, bbox_points)"""
    img = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(img)
    cx, cy = size / 2, size / 2
    w = size * 0.48
    h = size * 0.48
    points = []
    for i in range(6):
        angle = math.radians(60 * i)
        px = cx + w * math.cos(angle)
        py = cy + h * math.sin(angle)
        points.append((px, py))
    draw.polygon(points, fill=255)
    return img, points


def hex_fill(size):
    """返回六边形填充区域的像素坐标列表"""
    mask, _ = make_hex_mask(size)
    pixels = []
    for y in range(size):
        for x in range(size):
            if mask.getpixel((x, y)) > 128:
                pixels.append((x, y))
    return pixels


def in_hex(x, y, size):
    """检查点是否在六边形内"""
    cx, cy = size / 2, size / 2
    w = size * 0.48
    h = size * 0.48
    dx = abs(x - cx) / w
    dy = abs(y - cy) / h
    if dx > 1.0 or dy > 1.0:
        return False
    return dx + dy * 0.55 <= 1.0


def noise(x, y, seed=0):
    """简单伪噪声"""
    n = (x * 374761393 + y * 668265263 + seed * 1274126177) & 0xFFFFFFFF
    n = ((n >> 13) ^ n) * 1274126177
    n = (n >> 16) ^ n
    return (n & 0xFF) / 255.0


def noise_octave(x, y, seed=0, octaves=3):
    """多层叠加噪声，产生更自然的纹理"""
    val = 0.0
    amp = 1.0
    freq = 1.0
    max_val = 0.0
    for i in range(octaves):
        val += noise(int(x * freq), int(y * freq), seed + i * 100) * amp
        max_val += amp
        amp *= 0.5
        freq *= 2.0
    return val / max_val


def noise_smooth(x, y, seed=0):
    """带插值的平滑噪声"""
    ix, iy = int(x), int(y)
    fx, fy = x - ix, y - iy
    # 双线性插值
    n00 = noise(ix, iy, seed)
    n10 = noise(ix + 1, iy, seed)
    n01 = noise(ix, iy + 1, seed)
    n11 = noise(ix + 1, iy + 1, seed)
    # 平滑插值因子
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    nx0 = n00 + (n10 - n00) * fx
    nx1 = n01 + (n11 - n01) * fx
    return nx0 + (nx1 - nx0) * fy


def color_lerp(c1, c2, t):
    t = max(0, min(1, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def color_add(c, dr, dg, db):
    return tuple(max(0, min(255, c[i] + v)) for i, v in enumerate((dr, dg, db)))


def color_blend(c1, c2, alpha):
    """带 alpha 的颜色混合"""
    alpha = max(0, min(1, alpha))
    return tuple(int(c1[i] * (1 - alpha) + c2[i] * alpha) for i in range(3))


def color_multiply(c, factor):
    """颜色乘以因子"""
    return tuple(max(0, min(255, int(c[i] * factor))) for i in range(3))


def create_tile(name, draw_func):
    """创建一个地形图块"""
    img = Image.new("RGBA", (RENDER_SIZE, RENDER_SIZE), (0, 0, 0, 0))
    mask, hex_points = make_hex_mask(RENDER_SIZE)
    draw = ImageDraw.Draw(img)
    draw_func(img, draw, hex_points)
    img.putalpha(mask)
    img = img.resize((FINAL_SIZE, FINAL_SIZE), Image.NEAREST)
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "terrain")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name)
    img.save(path)
    print(f"  [OK] {name} ({img.size[0]}x{img.size[1]})")
    return img


def safe_pixel(img, x, y, size):
    """安全获取像素，越界返回 None"""
    if 0 <= x < size and 0 <= y < size and in_hex(x, y, size):
        return img.getpixel((x, y))[:3]
    return None


# ============================================================
# 地形绘制函数（增强细节版）
# ============================================================

def draw_plain(img, draw, hex_pts):
    """平原 - 丰富的草地、田间小路、野花丛、灌木"""
    size = RENDER_SIZE
    cx, cy = size // 2, size // 2

    # 基础草地渐变（多层噪声叠加）
    for y in range(size):
        for x in range(size):
            if not in_hex(x, y, size):
                continue
            n1 = noise_octave(x, y, 1, 3)
            n2 = noise_smooth(x * 0.5, y * 0.5, 2)
            dist = math.sqrt((x - cx)**2 + (y - cy)**2) / (size * 0.45)
            # 微妙的丘陵起伏感
            hill = math.sin(x * 0.08 + n2 * 3) * math.cos(y * 0.06 + n2 * 2) * 0.15
            height_var = dist * 0.5 + hill
            base = color_lerp(PALETTE["grass_bright"], PALETTE["grass_dark"], height_var)
            # 温暖区域和阴凉区域
            warmth = noise_smooth(x * 0.3, y * 0.3, 3)
            if warmth > 0.55:
                base = color_lerp(base, PALETTE["grass_warm"], (warmth - 0.55) * 2)
            elif warmth < 0.4:
                base = color_lerp(base, PALETTE["grass_shadow"], (0.4 - warmth) * 1.5)
            v = int((n1 - 0.5) * 20)
            c = color_add(base, v, v + 2, v - 3)
            img.putpixel((x, y), c + (255,))

    # 田间小路（蜿蜒土路）
    path_pts = []
    px, py = 20, 30
    for step in range(200):
        if in_hex(px, py, size):
            path_pts.append((px, py))
            # 路宽 3-4 像素
            for dx in range(-2, 3):
                for dy in range(-1, 2):
                    ppx, ppy = px + dx, py + dy
                    if in_hex(ppx, ppy, size):
                        dist_from_center = abs(dx) / 2.5
                        c = color_lerp(PALETTE["path_dust"], PALETTE["grass_mid"], dist_from_center * 0.6)
                        n = noise(ppx, ppy, 40)
                        c = color_add(c, int((n - 0.5) * 10), int((n - 0.5) * 8), int((n - 0.5) * 6))
                        img.putpixel((ppx, ppy), c + (255,))
        # 蜿蜒前进
        px += 1
        py += random.choice([0, 0, 1, -1])
        if px >= size - 20:
            break

    # 小路上的车辙印
    for ppx, ppy in path_pts[::3]:
        for offset in [-1, 1]:
            rx, ry = ppx, ppy + offset
            if in_hex(rx, ry, size):
                c = safe_pixel(img, rx, ry, size)
                if c:
                    img.putpixel((rx, ry), color_add(c, -8, -6, -4) + (255,))

    # 散布野花丛（多种颜色，成簇出现）
    for _ in range(120):
        fx = random.randint(10, size - 10)
        fy = random.randint(10, size - 10)
        if not in_hex(fx, fy, size):
            continue
        n = noise(fx, fy, 10)
        if n > 0.45:
            # 确定花的类型
            flower_n = noise(fx * 7, fy * 7, 11)
            if flower_n > 0.7:
                col = PALETTE["flower_yellow"]
            elif flower_n > 0.5:
                col = PALETTE["flower_pink"]
            elif flower_n > 0.35:
                col = PALETTE["flower_white"]
            else:
                col = PALETTE["flower_purple"]
            # 花朵形状：十字或单点
            if in_hex(fx, fy, size):
                img.putpixel((fx, fy), col + (255,))
            if n > 0.6:
                for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    if in_hex(fx + dx, fy + dy, size) and noise(fx + dx, fy + dy, 12) > 0.5:
                        lighter = color_lerp(col, (255, 255, 250), 0.3)
                        img.putpixel((fx + dx, fy + dy), lighter + (255,))

    # 草丛纹理（成片的深色草叶）
    for _ in range(90):
        gx = random.randint(8, size - 8)
        gy = random.randint(8, size - 8)
        if not in_hex(gx, gy, size):
            continue
        if noise(gx, gy, 20) > 0.55:
            # 草丛：一组斜线
            length = random.randint(2, 5)
            angle = random.uniform(-0.5, 0.5)
            for i in range(length):
                px = gx + int(i * math.cos(angle))
                py = gy - i
                if in_hex(px, py, size):
                    c = safe_pixel(img, px, py, size)
                    if c:
                        img.putpixel((px, py), color_add(c, -10, 5, -15) + (255,))

    # 灌木丛
    for _ in range(15):
        bx = random.randint(15, size - 15)
        by = random.randint(15, size - 15)
        if not in_hex(bx, by, size):
            continue
        if noise(bx, by, 50) > 0.65:
            bush_r = random.randint(2, 4)
            for dy in range(-bush_r, bush_r + 1):
                for dx in range(-bush_r, bush_r + 1):
                    dist = math.sqrt(dx**2 + dy**2)
                    if dist > bush_r:
                        continue
                    px, py = bx + dx, by + dy
                    if not in_hex(px, py, size):
                        continue
                    n = noise(px, py, 51)
                    if dist < bush_r * 0.5:
                        c = PALETTE["bush"]
                    else:
                        c = PALETTE["bush_dark"]
                    c = color_add(c, int((n - 0.5) * 12), int((n - 0.5) * 10), int((n - 0.5) * 8))
                    img.putpixel((px, py), c + (255,))

    # 散落小石子
    for _ in range(25):
        sx = random.randint(10, size - 10)
        sy = random.randint(10, size - 10)
        if not in_hex(sx, sy, size):
            continue
        if noise(sx, sy, 60) > 0.75:
            c = color_lerp(PALETTE["stone_light"], PALETTE["stone_mid"], noise(sx, sy, 61))
            if in_hex(sx, sy, size):
                img.putpixel((sx, sy), c + (255,))


def draw_forest(img, draw, hex_pts):
    """森林 - 多层树冠、林下灌木、蘑菇、光斑、倒木"""
    size = RENDER_SIZE
    cx, cy = size // 2, size // 2

    # 深绿基底（带泥土色混合）
    for y in range(size):
        for x in range(size):
            if not in_hex(x, y, size):
                continue
            n = noise_octave(x, y, 3, 3)
            n2 = noise_smooth(x * 0.4, y * 0.4, 4)
            dist = math.sqrt((x - cx)**2 + (y - cy)**2) / (size * 0.45)
            # 林地基底：深绿+泥土混合
            base = color_lerp(PALETTE["tree_dark"], PALETTE["tree_deep"], dist * 0.4 + n * 0.3)
            # 偶尔有泥土露出
            if n2 > 0.62:
                base = color_lerp(base, PALETTE["earth_dark"], (n2 - 0.62) * 2)
            v = int((n - 0.5) * 15)
            img.putpixel((x, y), color_add(base, v, v + 1, v - 2) + (255,))

    # 林间光斑
    for _ in range(30):
        lx = random.randint(15, size - 15)
        ly = random.randint(15, size - 15)
        if not in_hex(lx, ly, size):
            continue
        if noise(lx, ly, 70) > 0.7:
            spot_r = random.randint(2, 5)
            for dy in range(-spot_r, spot_r + 1):
                for dx in range(-spot_r, spot_r + 1):
                    dist = math.sqrt(dx**2 + dy**2)
                    if dist > spot_r:
                        continue
                    px, py = lx + dx, ly + dy
                    if not in_hex(px, py, size):
                        continue
                    brightness = 1.0 - dist / spot_r
                    c = safe_pixel(img, px, py, size)
                    if c:
                        blended = color_lerp(c, PALETTE["leaf_highlight"], brightness * 0.35)
                        img.putpixel((px, py), blended + (255,))

    # 绘制树木（多层，自上而下渲染）
    trees = []
    for _ in range(65):
        tx = random.randint(12, size - 12)
        ty = random.randint(12, size - 12)
        if in_hex(tx, ty, size):
            tree_type = noise(tx, ty, 55)
            trees.append((tx, ty, random.randint(3, 8), tree_type))

    trees.sort(key=lambda t: t[1])

    for tx, ty, ts, tree_type in trees:
        # 树干
        trunk_h = ts + random.randint(1, 3)
        for dy in range(ts // 3, trunk_h):
            for dx in range(-1, 2):
                px, py = tx + dx, ty + dy
                if in_hex(px, py, size):
                    n = noise(px, py, 56)
                    if dx == 0:
                        c = PALETTE["trunk"]
                    else:
                        c = PALETTE["trunk_dark"]
                    c = color_add(c, int((n - 0.5) * 8), int((n - 0.5) * 5), int((n - 0.5) * 3))
                    img.putpixel((px, py), c + (255,))

        # 树冠（根据类型变化形状）
        crown_r = ts + 1
        if tree_type > 0.6:
            # 圆形树冠
            for dy in range(-crown_r - 1, crown_r // 2):
                row_width = int(crown_r * math.sqrt(max(0, 1 - (dy / (crown_r * 0.85))**2)))
                for dx in range(-row_width, row_width + 1):
                    px, py = tx + dx, ty + dy
                    if not in_hex(px, py, size):
                        continue
                    n = noise(px, py, 50)
                    dist_from_center = math.sqrt(dx**2 + (dy * 1.2)**2) / crown_r
                    if dist_from_center > 0.92:
                        continue
                    if dist_from_center < 0.35:
                        c = PALETTE["leaf_highlight"]
                    elif dist_from_center < 0.6:
                        c = PALETTE["tree_light"]
                    elif dist_from_center < 0.8:
                        c = PALETTE["tree_mid"]
                    else:
                        c = PALETTE["tree_dark"]
                    v = int((n - 0.5) * 10)
                    img.putpixel((px, py), color_add(c, v, v, v) + (255,))
        else:
            # 锥形/松树形树冠
            for layer in range(crown_r * 2):
                ly = ty - crown_r + layer
                layer_w = max(1, int((layer / (crown_r * 2)) * crown_r * 1.2))
                for dx in range(-layer_w, layer_w + 1):
                    px, py = tx + dx, ly
                    if not in_hex(px, py, size):
                        continue
                    n = noise(px, py, 52)
                    if layer < crown_r * 0.4:
                        c = PALETTE["leaf_highlight"]
                    elif layer < crown_r * 1.2:
                        c = PALETTE["tree_mid"]
                    else:
                        c = PALETTE["tree_dark"]
                    v = int((n - 0.5) * 8)
                    img.putpixel((px, py), color_add(c, v, v, v) + (255,))

        # 树冠阴影边缘
        for dy in range(-crown_r, crown_r // 2):
            for dx in range(-crown_r - 1, crown_r + 2):
                px, py = tx + dx, ty + dy
                if not in_hex(px, py, size):
                    continue
                dist_from_center = math.sqrt(dx**2 + dy**2) / crown_r
                if 0.78 < dist_from_center < 0.95:
                    c = safe_pixel(img, px, py, size)
                    if c:
                        img.putpixel((px, py), color_add(c, -18, -12, -18) + (255,))

    # 林下灌木和蕨类
    for _ in range(35):
        bx = random.randint(10, size - 10)
        by = random.randint(10, size - 10)
        if not in_hex(bx, by, size):
            continue
        if noise(bx, by, 80) > 0.6:
            bush_size = random.randint(1, 3)
            for dy in range(-bush_size, bush_size + 1):
                for dx in range(-bush_size, bush_size + 1):
                    if dx**2 + dy**2 > bush_size**2:
                        continue
                    px, py = bx + dx, by + dy
                    if not in_hex(px, py, size):
                        continue
                    n = noise(px, py, 81)
                    c = color_lerp(PALETTE["bush"], PALETTE["bush_dark"], n)
                    img.putpixel((px, py), c + (255,))

    # 蘑菇
    for _ in range(10):
        mx = random.randint(15, size - 15)
        my = random.randint(15, size - 15)
        if not in_hex(mx, my, size):
            continue
        if noise(mx, my, 85) > 0.8:
            # 菌帽
            for dy in range(-2, 0):
                for dx in range(-2, 3):
                    px, py = mx + dx, my + dy
                    if in_hex(px, py, size):
                        img.putpixel((px, py), PALETTE["earth_warm"] + (255,))
            # 菌柄
            if in_hex(mx, my, size):
                img.putpixel((mx, my), PALETTE["earth_light"] + (255,))

    # 倒木
    for _ in range(5):
        lx = random.randint(20, size - 20)
        ly = random.randint(20, size - 20)
        if not in_hex(lx, ly, size):
            continue
        if noise(lx, ly, 88) > 0.7:
            log_len = random.randint(8, 18)
            angle = random.uniform(-0.3, 0.3)
            for i in range(log_len):
                px = lx + int(i * math.cos(angle))
                py = ly + int(i * math.sin(angle))
                if in_hex(px, py, size):
                    n = noise(px, py, 89)
                    c = color_lerp(PALETTE["trunk_dark"], PALETTE["bark"], n)
                    img.putpixel((px, py), c + (255,))


def draw_mountain(img, draw, hex_pts):
    """山地 - 岩石纹理、崖壁、碎石坡、积雪带、植被带"""
    size = RENDER_SIZE
    cx, cy = size // 2, size // 2

    # 基础岩石色（多层纹理）
    for y in range(size):
        for x in range(size):
            if not in_hex(x, y, size):
                continue
            n1 = noise_octave(x, y, 4, 4)
            n2 = noise_smooth(x * 0.3, y * 0.3, 5)
            dist = math.sqrt((x - cx)**2 + (y - cy)**2) / (size * 0.45)
            # 海拔感：上方（山顶）偏亮偏冷，下方偏暖偏暗
            height_factor = 1.0 - (y / size)
            # 崖壁区域（噪声突变处）
            cliff = abs(n2 - noise_smooth(x * 0.3 + 1, y * 0.3, 5))
            if cliff > 0.15:
                base = PALETTE["cliff_face"]
            else:
                base = color_lerp(PALETTE["stone_dark"], PALETTE["stone_mid"], height_factor)
                base = color_lerp(base, PALETTE["stone_light"], n1 * 0.3)
            # 温暖的岩石色调
            if n2 > 0.5:
                base = color_lerp(base, PALETTE["stone_warm"], (n2 - 0.5) * 0.4)
            v = int((n1 - 0.5) * 25)
            c = color_add(base, v, v - 2, v - 5)
            img.putpixel((x, y), c + (255,))

    # 山脊线（蜿蜒的岩石纹理）
    for _ in range(12):
        sx = random.randint(35, size - 35)
        sy = random.randint(25, size // 2)
        cx_off = random.choice([-2, -1, 0, 1, 2])
        ridge_len = random.randint(25, 70)
        for dy in range(ridge_len):
            px = sx + cx_off * (dy // 5) + random.randint(-1, 1)
            py = sy + dy
            if not in_hex(px, py, size):
                continue
            n = noise(px, py, 10)
            c = color_lerp(PALETTE["stone_light"], PALETTE["stone_shadow"], n)
            for dx in range(-1, 2):
                if in_hex(px + dx, py, size):
                    img.putpixel((px + dx, py), c + (255,))

    # 崖壁纹理（垂直条纹）
    for _ in range(8):
        cx_pos = random.randint(25, size - 25)
        cy_pos = random.randint(20, size - 30)
        if not in_hex(cx_pos, cy_pos, size):
            continue
        cliff_h = random.randint(10, 25)
        cliff_w = random.randint(3, 8)
        for dy in range(cliff_h):
            for dx in range(-cliff_w, cliff_w + 1):
                px, py = cx_pos + dx, cy_pos + dy
                if not in_hex(px, py, size):
                    continue
                n = noise(px, py, 15)
                # 层理线
                if dy % 4 == 0:
                    c = PALETTE["stone_dark"]
                elif dy % 4 == 2:
                    c = PALETTE["stone_light"]
                else:
                    c = PALETTE["stone_mid"]
                c = color_add(c, int((n - 0.5) * 15), int((n - 0.5) * 12), int((n - 0.5) * 10))
                img.putpixel((px, py), c + (255,))

    # 碎石坡
    for _ in range(40):
        sx = random.randint(20, size - 20)
        sy = random.randint(size // 2, size - 20)
        if not in_hex(sx, sy, size):
            continue
        if noise(sx, sy, 16) > 0.55:
            stone_size = random.randint(1, 3)
            for dy in range(-stone_size, stone_size + 1):
                for dx in range(-stone_size, stone_size + 1):
                    if dx**2 + dy**2 > stone_size**2 + 1:
                        continue
                    px, py = sx + dx, sy + dy
                    if not in_hex(px, py, size):
                        continue
                    n = noise(px, py, 17)
                    c = color_lerp(PALETTE["scree"], PALETTE["stone_warm"], n)
                    img.putpixel((px, py), c + (255,))

    # 山顶积雪带
    for y_pos in range(15, 55):
        for x_pos in range(10, size - 10):
            if not in_hex(x_pos, y_pos, size):
                continue
            n = noise(x_pos, y_pos, 18)
            snow_line = 35 + n * 15
            if y_pos < snow_line:
                snow_strength = (snow_line - y_pos) / snow_line
                if snow_strength > 0.2:
                    c = safe_pixel(img, x_pos, y_pos, size)
                    if c:
                        # 积雪混合
                        snow_col = PALETTE["snow"] if n > 0.4 else PALETTE["snow_shadow"]
                        blended = color_lerp(c, snow_col, snow_strength * 0.7)
                        img.putpixel((x_pos, y_pos), blended + (255,))

    # 岩石裂缝
    for _ in range(20):
        fx = random.randint(20, size - 20)
        fy = random.randint(25, size - 20)
        if not in_hex(fx, fy, size):
            continue
        length = random.randint(6, 18)
        dx_dir = random.choice([-1, 0, 1])
        cur_x, cur_y = fx, fy
        for i in range(length):
            if in_hex(cur_x, cur_y, size):
                img.putpixel((cur_x, cur_y), PALETTE["stone_shadow"] + (255,))
            cur_x += dx_dir + random.choice([-1, 0, 0, 1])
            cur_y += 1

    # 高山植被（稀疏草地）
    for _ in range(20):
        vx = random.randint(15, size - 15)
        vy = random.randint(size // 2 + 10, size - 15)
        if not in_hex(vx, vy, size):
            continue
        if noise(vx, vy, 19) > 0.7:
            patch_r = random.randint(2, 4)
            for dy in range(-patch_r, patch_r + 1):
                for dx in range(-patch_r, patch_r + 1):
                    if dx**2 + dy**2 > patch_r**2:
                        continue
                    px, py = vx + dx, vy + dy
                    if not in_hex(px, py, size):
                        continue
                    c = safe_pixel(img, px, py, size)
                    if c:
                        blended = color_lerp(c, PALETTE["grass_dark"], 0.4)
                        img.putpixel((px, py), blended + (255,))


def draw_river(img, draw, hex_pts):
    """河流 - 水流纹理、波纹、芦苇、浮木、水底石"""
    size = RENDER_SIZE
    cx, cy = size // 2, size // 2

    # 水体基底（多层波纹叠加）
    for y in range(size):
        for x in range(size):
            if not in_hex(x, y, size):
                continue
            n1 = noise_octave(x, y, 6, 3)
            n2 = noise_smooth(x * 0.5 + y * 0.2, y * 0.5, 7)
            # 主水流方向（从上到下，带横向波动）
            flow_x = math.sin((y * 0.15 + n2 * 2)) * 0.3
            wave = math.sin((x * 0.2 + y * 0.1 + flow_x)) * 0.25
            # 水深变化
            depth = 0.45 + wave + (n1 - 0.5) * 0.35 + abs(x - cx) / (size * 0.6) * 0.2
            depth = max(0, min(1, depth))
            base = color_lerp(PALETTE["water_deep"], PALETTE["water_light"], depth)
            # 水流高光条纹
            flow_highlight = math.sin((x + y * 0.4) * 0.4 + n2 * 3) * 0.5 + 0.5
            if flow_highlight > 0.75:
                base = color_lerp(base, PALETTE["water_foam"], (flow_highlight - 0.75) * 2)
            v = int((n1 - 0.5) * 18)
            c = color_add(base, v, v + 4, v + 7)
            img.putpixel((x, y), c + (255,))

    # 波浪高光线（多层）
    for _ in range(60):
        wx = random.randint(10, size - 10)
        wy = random.randint(10, size - 10)
        if not in_hex(wx, wy, size):
            continue
        n = noise(wx, wy, 30)
        if n > 0.6:
            length = random.randint(3, 10)
            for dx in range(length):
                px = wx + dx
                if in_hex(px, wy, size):
                    c = safe_pixel(img, px, wy, size)
                    if c:
                        brightness = 1.0 - dx / length
                        c2 = color_lerp(c, PALETTE["water_foam"], brightness * 0.5)
                        img.putpixel((px, wy), c2 + (255,))

    # 水面涟漪（同心椭圆）
    for _ in range(15):
        rx = random.randint(20, size - 20)
        ry = random.randint(20, size - 20)
        if not in_hex(rx, ry, size):
            continue
        r = random.randint(3, 7)
        for ring in range(2):
            cr = r + ring * 2
            for angle_step in range(24):
                angle = angle_step * math.pi * 2 / 24
                px = int(rx + cr * math.cos(angle))
                py = int(ry + cr * 0.5 * math.sin(angle))
                if in_hex(px, py, size):
                    c = safe_pixel(img, px, py, size)
                    if c:
                        img.putpixel((px, py), color_add(c, 8, 14, 18) + (255,))

    # 两岸芦苇丛
    for bank_side in [-1, 1]:
        for _ in range(20):
            rx = random.randint(15, size - 15)
            ry = random.randint(15, size - 15)
            if not in_hex(rx, ry, size):
                continue
            # 芦苇靠近边缘
            edge_dist = abs(rx - cx) / (size * 0.45)
            if edge_dist < 0.5:
                continue
            if noise(rx, ry, 31) > 0.55:
                reed_h = random.randint(4, 9)
                for dy in range(-reed_h, 1):
                    px = rx + random.choice([-1, 0, 0, 1])
                    py = ry + dy
                    if in_hex(px, py, size):
                        t = -dy / reed_h
                        c = color_lerp(PALETTE["water_reed"], PALETTE["reed"], t)
                        img.putpixel((px, py), c + (255,))
                # 芦苇穗
                if in_hex(rx, ry - reed_h, size):
                    img.putpixel((rx, ry - reed_h), PALETTE["reed_dry"] + (255,))

    # 浮木/树枝
    for _ in range(6):
        fx = random.randint(20, size - 20)
        fy = random.randint(20, size - 20)
        if not in_hex(fx, fy, size):
            continue
        if noise(fx, fy, 32) > 0.75:
            log_len = random.randint(5, 12)
            angle = random.uniform(-0.4, 0.4)
            for i in range(log_len):
                px = fx + int(i * math.cos(angle))
                py = fy + int(i * math.sin(angle))
                if in_hex(px, py, size):
                    c = color_lerp(PALETTE["trunk_dark"], PALETTE["bark"], noise(px, py, 33))
                    img.putpixel((px, py), c + (255,))

    # 水底石头（浅水区）
    for _ in range(25):
        sx = random.randint(15, size - 15)
        sy = random.randint(15, size - 15)
        if not in_hex(sx, sy, size):
            continue
        if noise(sx, sy, 35) > 0.58:
            r = random.randint(1, 3)
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if dx**2 + dy**2 <= r**2:
                        px, py = sx + dx, sy + dy
                        if in_hex(px, py, size):
                            c = color_lerp(PALETTE["stone_mid"], PALETTE["water_light"], 0.35)
                            img.putpixel((px, py), c + (255,))


def draw_marsh(img, draw, hex_pts):
    """沼泽 - 湿地泥泞、水坑、芦苇、苔藓、雾气"""
    size = RENDER_SIZE
    cx, cy = size // 2, size // 2

    # 基底：泥地+湿地混合
    for y in range(size):
        for x in range(size):
            if not in_hex(x, y, size):
                continue
            n1 = noise_octave(x, y, 8, 3)
            n2 = noise_smooth(x * 0.4, y * 0.4, 9)
            # 湿润程度变化
            wetness = n2 + math.sin(x * 0.1) * 0.1 + math.cos(y * 0.08) * 0.1
            if wetness > 0.6:
                base = color_lerp(PALETTE["mud"], PALETTE["marsh_dark"], (wetness - 0.6) * 2.5)
            elif wetness > 0.45:
                base = color_lerp(PALETTE["marsh_green"], PALETTE["mud"], (wetness - 0.45) * 6)
            else:
                base = color_lerp(PALETTE["grass_shadow"], PALETTE["marsh_green"], wetness * 2)
            v = int((n1 - 0.5) * 18)
            c = color_add(base, v, v - 3, v - 5)
            img.putpixel((x, y), c + (255,))

    # 水坑（带深度渐变）
    for _ in range(20):
        wx = random.randint(18, size - 18)
        wy = random.randint(18, size - 18)
        if not in_hex(wx, wy, size):
            continue
        r = random.randint(4, 10)
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                dist = math.sqrt(dx**2 + dy**2)
                if dist > r:
                    continue
                px, py = wx + dx, wy + dy
                if not in_hex(px, py, size):
                    continue
                depth = 1.0 - dist / r
                # 水坑边缘苔藓色，中心深水色
                if depth > 0.6:
                    c = color_lerp(PALETTE["water_dark"], PALETTE["water_murky"], depth)
                else:
                    c = color_lerp(PALETTE["marsh_dark"], PALETTE["water_dark"], depth * 1.5)
                # 水面反光
                if depth > 0.5 and noise(px, py, 41) > 0.7:
                    c = color_add(c, 10, 15, 12)
                img.putpixel((px, py), c + (255,))

    # 苔藓覆盖区
    for _ in range(25):
        mx = random.randint(10, size - 10)
        my = random.randint(10, size - 10)
        if not in_hex(mx, my, size):
            continue
        if noise(mx, my, 42) > 0.6:
            moss_r = random.randint(2, 5)
            for dy in range(-moss_r, moss_r + 1):
                for dx in range(-moss_r, moss_r + 1):
                    if dx**2 + dy**2 > moss_r**2:
                        continue
                    px, py = mx + dx, my + dy
                    if not in_hex(px, py, size):
                        continue
                    c = safe_pixel(img, px, py, size)
                    if c:
                        blended = color_lerp(c, PALETTE["moss"], 0.45)
                        img.putpixel((px, py), blended + (255,))

    # 芦苇/草丛（高而稀疏）
    for _ in range(45):
        rx = random.randint(10, size - 10)
        ry = random.randint(10, size - 10)
        if not in_hex(rx, ry, size):
            continue
        if noise(rx, ry, 40) > 0.5:
            height = random.randint(4, 9)
            for dy in range(-height, 1):
                px = rx + random.choice([-1, 0, 0, 1])
                py = ry + dy
                if in_hex(px, py, size):
                    t = -dy / height
                    c = color_lerp(PALETTE["marsh_green"], PALETTE["reed"], t * 0.7)
                    if dy == -height:
                        c = PALETTE["reed_dry"]
                    img.putpixel((px, py), c + (255,))

    # 气泡/沼气痕迹
    for _ in range(12):
        bx = random.randint(15, size - 15)
        by = random.randint(15, size - 15)
        if not in_hex(bx, by, size):
            continue
        if noise(bx, by, 43) > 0.78:
            # 小气泡
            for dx, dy in [(0, 0), (1, 0), (-1, 0)]:
                px, py = bx + dx, by + dy
                if in_hex(px, py, size):
                    c = safe_pixel(img, px, py, size)
                    if c:
                        img.putpixel((px, py), color_add(c, 15, 18, 10) + (255,))

    # 湿地苔藓斑块（亮绿色）
    for _ in range(15):
        gx = random.randint(12, size - 12)
        gy = random.randint(12, size - 12)
        if not in_hex(gx, gy, size):
            continue
        if noise(gx, gy, 44) > 0.72:
            patch_r = random.randint(2, 4)
            for dy in range(-patch_r, patch_r + 1):
                for dx in range(-patch_r, patch_r + 1):
                    if dx**2 + dy**2 > patch_r**2:
                        continue
                    px, py = gx + dx, gy + dy
                    if not in_hex(px, py, size):
                        continue
                    c = safe_pixel(img, px, py, size)
                    if c:
                        blended = color_lerp(c, PALETTE["marsh_light"], 0.35)
                        img.putpixel((px, py), blended + (255,))


def draw_pass(img, draw, hex_pts):
    """关隘 - 城墙、雉堞、拱门、望楼、旗帜、石板路"""
    size = RENDER_SIZE
    cx, cy = size // 2, size // 2

    # 地面基底（多纹理）
    for y in range(size):
        for x in range(size):
            if not in_hex(x, y, size):
                continue
            n1 = noise_octave(x, y, 11, 3)
            n2 = noise_smooth(x * 0.3, y * 0.3, 12)
            dist = math.sqrt((x - cx)**2 + (y - cy)**2) / (size * 0.45)
            base = color_lerp(PALETTE["earth_light"], PALETTE["earth_dark"], dist * 0.5)
            # 土地上的小石子纹理
            if n2 > 0.65:
                base = color_lerp(base, PALETTE["stone_warm"], (n2 - 0.65) * 2)
            v = int((n1 - 0.5) * 15)
            img.putpixel((x, y), color_add(base, v, v - 2, v - 5) + (255,))

    # 主城墙（横贯中部，带砖块纹理）
    wall_y = cy - 3
    wall_h = 16
    for wy in range(wall_y, wall_y + wall_h):
        for wx in range(18, size - 18):
            if not in_hex(wx, wy, size):
                continue
            n = noise(wx, wy, 12)
            # 砖块纹理（交错排列）
            brick_row = (wy - wall_y) % 4
            brick_col = (wx + (0 if brick_row % 2 == 0 else 3)) % 6
            if brick_col == 0:
                c = PALETTE["wall_dark"]  # 砖缝
            elif brick_col == 1:
                c = PALETTE["wall_worn"]  # 风化砖
            else:
                c = color_lerp(PALETTE["wall_mid"], PALETTE["wall_light"], n * 0.4)
            # 城墙底部偏暗
            wy_factor = (wy - wall_y) / wall_h
            if wy_factor > 0.7:
                c = color_multiply(c, 0.9)
            img.putpixel((wx, wy), c + (255,))

    # 城墙顶部雉堞（带磨损）
    for wx in range(20, size - 20):
        merlon = (wx // 4) % 3
        if merlon == 0:
            for dy in range(-4, 0):
                py = wall_y + dy
                if in_hex(wx, py, size):
                    n = noise(wx, py, 13)
                    c = color_lerp(PALETTE["wall_mid"], PALETTE["wall_worn"], n * 0.5)
                    img.putpixel((wx, py), c + (255,))

    # 城门洞（拱形，带门扇细节）
    gate_cx = cx
    gate_w = 13
    gate_h = 12
    for gy in range(wall_y + wall_h - gate_h, wall_y + wall_h):
        for gx in range(gate_cx - gate_w, gate_cx + gate_w):
            if not in_hex(gx, gy, size):
                continue
            rel_x = (gx - gate_cx) / gate_w
            rel_y = (gy - (wall_y + wall_h - gate_h)) / gate_h
            if rel_x**2 + (1 - rel_y)**2 < 1.0:
                depth = 1.0 - rel_y
                c = color_lerp(PALETTE["earth_dark"], PALETTE["earth_shadow"], depth)
                # 门扇纹理（两侧）
                if abs(rel_x) > 0.6:
                    n = noise(gx, gy, 14)
                    c = color_lerp(PALETTE["trunk_dark"], PALETTE["trunk"], n * 0.3)
                img.putpixel((gx, gy), c + (255,))

    # 门洞上方匾额
    plaque_y = wall_y + wall_h - gate_h - 3
    for px in range(gate_cx - 5, gate_cx + 6):
        for py in range(plaque_y, plaque_y + 3):
            if in_hex(px, py, size):
                n = noise(px, py, 15)
                c = color_lerp(PALETTE["trunk"], PALETTE["trunk_dark"], n * 0.3)
                img.putpixel((px, py), c + (255,))

    # 两侧望楼
    for tower_x in [28, size - 28]:
        tower_w = 9
        tower_h = 24
        tower_y = wall_y - tower_h + wall_h
        # 塔身
        for ty in range(tower_y, tower_y + tower_h):
            for tx in range(tower_x - tower_w, tower_x + tower_w):
                if not in_hex(tx, ty, size):
                    continue
                n = noise(tx, ty, 13)
                brick_r = (ty - tower_y) % 3
                brick_c = (tx + (0 if brick_r % 2 == 0 else 2)) % 5
                if brick_c == 0:
                    c = PALETTE["wall_dark"]
                else:
                    c = color_lerp(PALETTE["wall_mid"], PALETTE["wall_light"], n * 0.3)
                img.putpixel((tx, ty), c + (255,))

        # 望楼窗洞
        for wy in [tower_y + 5, tower_y + 12]:
            for wx_off in [-3, 3]:
                wwx = tower_x + wx_off
                for dy in range(-2, 3):
                    for dx in range(-1, 2):
                        px, py = wwx + dx, wy + dy
                        if in_hex(px, py, size):
                            img.putpixel((px, py), PALETTE["earth_shadow"] + (255,))

        # 望楼屋顶（多层飞檐）
        roof_base_y = tower_y
        for layer in range(2):
            roof_w = tower_w + 4 - layer * 2
            ry = roof_base_y - layer * 3
            for r_offset in range(3):
                rw = roof_w - r_offset
                for rx in range(tower_x - rw, tower_x + rw):
                    py = ry - r_offset
                    if in_hex(rx, py, size):
                        tile = ((rx - tower_x + rw) // 3 + r_offset) % 2
                        c = PALETTE["roof"] if tile == 0 else PALETTE["roof_dark"]
                        img.putpixel((rx, py), c + (255,))

    # 城墙旗帜
    for flag_x in [cx - 20, cx + 20]:
        flag_y = wall_y - 8
        # 旗杆
        for dy in range(-10, 1):
            if in_hex(flag_x, flag_y + dy, size):
                img.putpixel((flag_x, flag_y + dy), PALETTE["trunk_dark"] + (255,))
        # 旗面
        for dx in range(1, 6):
            for dy in range(-8, -3):
                px, py = flag_x + dx, flag_y + dy
                if in_hex(px, py, size):
                    n = noise(px, py, 16)
                    wave = math.sin(dx * 0.8 + dy * 0.3) * 0.3
                    c = color_lerp(PALETTE["flag_red"], PALETTE["banner_faded"], n * 0.3 + wave)
                    img.putpixel((px, py), c + (255,))

    # 火把/灯笼
    for torch_x in [35, size - 35]:
        torch_y = wall_y + wall_h // 2
        if in_hex(torch_x, torch_y, size):
            img.putpixel((torch_x, torch_y), PALETTE["trunk_dark"] + (255,))
        for dy in range(-3, 0):
            for dx in range(-1, 2):
                px, py = torch_x + dx, torch_y + dy
                if in_hex(px, py, size):
                    dist = math.sqrt(dx**2 + dy**2)
                    c = color_lerp(PALETTE["torch_glow"], PALETTE["flag_red"], dist * 0.3)
                    img.putpixel((px, py), c + (255,))

    # 地面石板路（门前区域）
    for y in range(wall_y + wall_h + 1, size - 8):
        for x in range(cx - 18, cx + 18):
            if not in_hex(x, y, size):
                continue
            n = noise(x, y, 14)
            # 石板缝隙
            slab_x = (x + 2) % 5
            slab_y = (y + 1) % 4
            if slab_x == 0 or slab_y == 0:
                c = PALETTE["earth_dark"]
            else:
                c = color_lerp(PALETTE["stone_mid"], PALETTE["stone_light"], n * 0.5)
                # 磨损痕迹
                if abs(x - cx) < 4:
                    c = color_lerp(c, PALETTE["stone_warm"], 0.3)
            img.putpixel((x, y), c + (255,))


def draw_ford(img, draw, hex_pts):
    """浅滩 - 可涉水过河，沙底、浅水、石蹬、芦苇"""
    size = RENDER_SIZE
    cx, cy = size // 2, size // 2

    # 基底：浅水+沙底混合
    for y in range(size):
        for x in range(size):
            if not in_hex(x, y, size):
                continue
            n1 = noise_octave(x, y, 16, 3)
            n2 = noise_smooth(x * 0.4, y * 0.4, 17)
            dist = math.sqrt((x - cx)**2 + (y - cy)**2) / (size * 0.45)
            # 中心浅滩区域更浅，边缘更深
            water_depth = 0.25 + dist * 0.35 + (n1 - 0.5) * 0.3
            # 沙洲区域（中心偏下）
            sand_dist = math.sqrt((x - cx)**2 + (y - cy + 5)**2) / (size * 0.3)
            if sand_dist < 0.7:
                sand_strength = 1.0 - sand_dist / 0.7
                water_depth -= sand_strength * 0.3
            water_depth = max(0, min(1, water_depth))
            if water_depth > 0.55:
                base = color_lerp(PALETTE["water_light"], PALETTE["water_mid"], water_depth)
            elif water_depth > 0.3:
                base = color_lerp(PALETTE["water_shallow"], PALETTE["water_light"], water_depth * 2)
            else:
                base = color_lerp(PALETTE["earth_light"], PALETTE["water_shallow"], water_depth * 3)
            v = int((n2 - 0.5) * 18)
            c = color_add(base, v, v + 3, v + 5)
            img.putpixel((x, y), c + (255,))

    # 浅水波纹（多层）
    for wy in range(0, size, 5):
        for wx in range(0, size, 3):
            if not in_hex(wx, wy, size):
                continue
            n = noise(wx, wy, 25)
            if n > 0.6:
                length = random.randint(4, 12)
                for dx in range(length):
                    px = wx + dx
                    if in_hex(px, wy, size):
                        c = safe_pixel(img, px, wy, size)
                        if c:
                            brightness = 1.0 - dx / length
                            c2 = color_lerp(c, PALETTE["water_foam"], brightness * 0.3)
                            img.putpixel((px, wy), c2 + (255,))

    # 水底石头（多大小）
    for _ in range(30):
        sx = random.randint(15, size - 15)
        sy = random.randint(15, size - 15)
        if not in_hex(sx, sy, size):
            continue
        if noise(sx, sy, 35) > 0.55:
            r = random.randint(1, 4)
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if dx**2 + dy**2 <= r**2:
                        px, py = sx + dx, sy + dy
                        if in_hex(px, py, size):
                            n = noise(px, py, 36)
                            c = color_lerp(PALETTE["stone_mid"], PALETTE["water_light"], 0.3)
                            c = color_add(c, int((n - 0.5) * 10), int((n - 0.5) * 8), int((n - 0.5) * 6))
                            img.putpixel((px, py), c + (255,))

    # 石蹬（涉水踏脚石）
    stepping_stones = [(cx - 10, cy - 8), (cx + 5, cy - 2), (cx - 3, cy + 5), (cx + 8, cy + 10)]
    for sx, sy in stepping_stones:
        stone_r = random.randint(2, 3)
        for dy in range(-stone_r, stone_r + 1):
            for dx in range(-stone_r, stone_r + 1):
                if dx**2 + dy**2 > stone_r**2:
                    continue
                px, py = sx + dx, sy + dy
                if in_hex(px, py, size):
                    n = noise(px, py, 37)
                    c = color_lerp(PALETTE["stone_light"], PALETTE["stone_warm"], n)
                    img.putpixel((px, py), c + (255,))

    # 沙洲纹理（中心浅色区域）
    for dy in range(-18, 19):
        for dx in range(-22, 23):
            px, py = cx + dx, cy + dy
            if not in_hex(px, py, size):
                continue
            dist = math.sqrt(dx**2 + dy**2)
            if dist < 20:
                shallow = 1.0 - dist / 20
                c = safe_pixel(img, px, py, size)
                if c:
                    sand_col = color_lerp(PALETTE["earth_light"], PALETTE["earth_warm"], noise(px, py, 38))
                    blended = color_lerp(c, sand_col, shallow * 0.3)
                    img.putpixel((px, py), blended + (255,))

    # 两岸芦苇
    for bank_y in [15, size - 15]:
        for _ in range(12):
            rx = random.randint(15, size - 15)
            ry = bank_y + random.randint(-5, 5)
            if not in_hex(rx, ry, size):
                continue
            reed_h = random.randint(3, 7)
            for dy in range(-reed_h, 1):
                px = rx + random.choice([-1, 0, 0, 1])
                py = ry + dy
                if in_hex(px, py, size):
                    c = color_lerp(PALETTE["water_reed"], PALETTE["reed"], -dy / reed_h)
                    img.putpixel((px, py), c + (255,))


def draw_plank_road(img, draw, hex_pts):
    """栈道 - 木板路、山壁、护栏、藤蔓、铁链"""
    size = RENDER_SIZE
    cx, cy = size // 2, size // 2

    # 山壁基底（两侧，多层岩石纹理）
    for y in range(size):
        for x in range(size):
            if not in_hex(x, y, size):
                continue
            n1 = noise_octave(x, y, 18, 3)
            n2 = noise_smooth(x * 0.3, y * 0.3, 19)
            center_dist = abs(x - cx) / (size * 0.45)
            if center_dist < 0.32:
                # 栈道区域 - 木板路
                base = PALETTE["plank"]
                plank_line = y % 3
                if plank_line == 0:
                    base = PALETTE["plank_dark"]
                elif plank_line == 1:
                    base = PALETTE["plank_worn"]
                # 木纹纹理
                grain = noise_smooth(x * 2, y * 0.3, 20)
                if grain > 0.6:
                    base = color_lerp(base, PALETTE["plank_light"], (grain - 0.6) * 1.5)
                v = int((n1 - 0.5) * 12)
                c = color_add(base, v, v - 4, v - 8)
                img.putpixel((x, y), c + (255,))
            elif center_dist < 0.45:
                # 过渡区：碎石
                base = color_lerp(PALETTE["stone_mid"], PALETTE["scree"], n2)
                v = int((n1 - 0.5) * 15)
                c = color_add(base, v, v - 2, v - 5)
                img.putpixel((x, y), c + (255,))
            else:
                # 山壁（多层岩石）
                height_factor = 1.0 - (y / size)
                base = color_lerp(PALETTE["stone_dark"], PALETTE["stone_mid"], height_factor)
                # 岩石层理
                if y % 5 < 2:
                    base = color_lerp(base, PALETTE["stone_light"], 0.2)
                base = color_lerp(base, PALETTE["cliff_face"], n2 * 0.4)
                v = int((n1 - 0.5) * 20)
                c = color_add(base, v, v - 2, v - 5)
                img.putpixel((x, y), c + (255,))

    # 栈道护栏（木桩+横梁）
    rail_positions = [cx - 20, cx + 20]
    for rx in rail_positions:
        for y in range(6, size - 6, 5):
            # 立柱
            for dy in range(-3, 4):
                for dx in range(-1, 2):
                    px, py = rx + dx, y + dy
                    if in_hex(px, py, size):
                        n = noise(px, py, 21)
                        c = color_lerp(PALETTE["trunk"], PALETTE["trunk_dark"], n * 0.4)
                        img.putpixel((px, py), c + (255,))
            # 横梁（连接立柱）
            for dx in range(-1, 2):
                for sy in range(y, min(y + 5, size)):
                    px, py = rx + dx, sy
                    if in_hex(px, py, size):
                        c = PALETTE["trunk_dark"]
                        img.putpixel((px, py), c + (255,))

    # 木板接缝和钉子
    for y in range(size):
        for x in range(cx - 20, cx + 21):
            if not in_hex(x, y, size):
                continue
            n = noise(x, y, 19)
            # 木板接缝
            if n > 0.82:
                img.putpixel((x, y), PALETTE["trunk_dark"] + (255,))
            # 铁钉
            if y % 12 == 0 and abs(x - cx) < 18 and noise(x, y, 22) > 0.85:
                img.putpixel((x, y), PALETTE["stone_shadow"] + (255,))

    # 山壁凿痕/岩石纹理
    for _ in range(40):
        sx = random.choice([random.randint(3, cx - 28), random.randint(cx + 28, size - 3)])
        sy = random.randint(8, size - 8)
        if not in_hex(sx, sy, size):
            continue
        for dy in range(random.randint(2, 7)):
            px = sx + random.randint(-1, 1)
            py = sy + dy
            if in_hex(px, py, size):
                img.putpixel((px, py), PALETTE["stone_shadow"] + (255,))

    # 藤蔓/苔藓（山壁上）
    for _ in range(15):
        vx = random.choice([random.randint(5, cx - 25), random.randint(cx + 25, size - 5)])
        vy = random.randint(10, size - 15)
        if not in_hex(vx, vy, size):
            continue
        if noise(vx, vy, 23) > 0.6:
            vine_len = random.randint(5, 15)
            cur_x, cur_y = vx, vy
            for i in range(vine_len):
                if in_hex(cur_x, cur_y, size):
                    c = color_lerp(PALETTE["moss"], PALETTE["bush_dark"], noise(cur_x, cur_y, 24))
                    img.putpixel((cur_x, cur_y), c + (255,))
                cur_x += random.choice([-1, 0, 0, 1])
                cur_y += 1

    # 铁链（悬挂护栏）
    for chain_x in [cx - 18, cx + 18]:
        for y in range(8, size - 8, 8):
            for link in range(3):
                ly = y + link
                if in_hex(chain_x, ly, size):
                    c = color_lerp(PALETTE["stone_shadow"], PALETTE["stone_dark"], noise(chain_x, ly, 25))
                    img.putpixel((chain_x, ly), c + (255,))


def draw_arrow_tower(img, draw, hex_pts):
    """箭楼 - 石砌塔楼、箭窗、中式屋顶、旗帜、台阶"""
    size = RENDER_SIZE
    cx, cy = size // 2, size // 2

    # 地面基底（夯土+碎石）
    for y in range(size):
        for x in range(size):
            if not in_hex(x, y, size):
                continue
            n1 = noise_octave(x, y, 21, 3)
            n2 = noise_smooth(x * 0.3, y * 0.3, 22)
            dist = math.sqrt((x - cx)**2 + (y - cy)**2) / (size * 0.45)
            base = color_lerp(PALETTE["earth_light"], PALETTE["earth_dark"], dist * 0.4)
            # 夯土纹理
            if n2 > 0.58:
                base = color_lerp(base, PALETTE["earth_warm"], (n2 - 0.58) * 2)
            v = int((n1 - 0.5) * 12)
            img.putpixel((x, y), color_add(base, v, v - 2, v - 5) + (255,))

    # 箭楼主楼（中心偏上）
    tower_cx, tower_cy = cx, cy - 5
    tower_w = 22
    tower_h = 32

    for ty in range(tower_cy - tower_h // 2, tower_cy + tower_h // 2):
        for tx in range(tower_cx - tower_w, tower_cx + tower_w):
            if not in_hex(tx, ty, size):
                continue
            n = noise(tx, ty, 22)
            # 石砌墙面（更精细的砖块）
            brick_r = (ty - (tower_cy - tower_h // 2)) % 3
            brick_c = (tx + (0 if brick_r % 2 == 0 else 3)) % 6
            if brick_c == 0:
                c = PALETTE["wall_dark"]
            elif brick_c == 1:
                c = PALETTE["wall_worn"]
            else:
                c = color_lerp(PALETTE["wall_mid"], PALETTE["wall_light"], n * 0.35)
            # 墙面底部偏暗
            height_in_tower = (ty - (tower_cy - tower_h // 2)) / tower_h
            if height_in_tower > 0.7:
                c = color_multiply(c, 0.92)
            img.putpixel((tx, ty), c + (255,))

    # 箭窗（射击孔，十字形）
    for wy in [tower_cy - 10, tower_cy - 2, tower_cy + 6]:
        for wx_offset in [-12, -4, 4, 12]:
            wx = tower_cx + wx_offset
            # 竖缝
            for dy in range(-3, 4):
                px, py = wx, wy + dy
                if in_hex(px, py, size):
                    img.putpixel((px, py), PALETTE["earth_shadow"] + (255,))
            # 横缝
            for dx in range(-2, 3):
                px, py = wx + dx, wy
                if in_hex(px, py, size):
                    img.putpixel((px, py), PALETTE["earth_shadow"] + (255,))

    # 屋顶（多层中式飞檐）
    roof_base_y = tower_cy - tower_h // 2
    for layer in range(3):
        roof_w = tower_w + 10 - layer * 3
        ry = roof_base_y - layer * 4
        # 瓦片层
        for r_offset in range(4):
            rw = roof_w - r_offset * 2
            if rw <= 0:
                break
            for rx in range(tower_cx - rw, tower_cx + rw):
                py = ry - r_offset
                if in_hex(rx, py, size):
                    tile = ((rx - tower_cx + rw) // 3 + r_offset + layer) % 2
                    if tile == 0:
                        c = PALETTE["roof"]
                    else:
                        c = PALETTE["roof_dark"]
                    # 屋檐高光
                    if r_offset == 0:
                        c = color_lerp(c, PALETTE["roof_light"], 0.3)
                    img.putpixel((rx, py), c + (255,))

    # 飞檐翘角（四角上翘）
    for side in [-1, 1]:
        for layer in range(3):
            tip_x = tower_cx + side * (tower_w + 8 - layer * 3)
            tip_y = roof_base_y - layer * 4 - 3
            for dy in range(-4, 2):
                for dx in range(-3, 4):
                    px = tip_x + dx * side
                    py = tip_y + dy - abs(dx)
                    if in_hex(px, py, size):
                        img.putpixel((px, py), PALETTE["roof"] + (255,))

    # 塔基台阶（三层）
    for step in range(4):
        sy = tower_cy + tower_h // 2 + step * 2
        sw = tower_w + 6 - step * 2
        for sx in range(tower_cx - sw, tower_cx + sw):
            if in_hex(sx, sy, size):
                img.putpixel((sx, sy), PALETTE["stone_light"] + (255,))
            if in_hex(sx, sy + 1, size):
                n = noise(sx, sy + 1, 23)
                c = color_lerp(PALETTE["stone_mid"], PALETTE["stone_warm"], n * 0.3)
                img.putpixel((sx, sy + 1), c + (255,))

    # 塔顶旗帜
    flag_x = tower_cx
    flag_y = roof_base_y - 12
    # 旗杆
    for dy in range(-8, 0):
        if in_hex(flag_x, flag_y + dy, size):
            img.putpixel((flag_x, flag_y + dy), PALETTE["trunk_dark"] + (255,))
    # 旗面（飘扬）
    for dx in range(1, 7):
        for dy in range(-6, 0):
            px, py = flag_x + dx, flag_y + dy
            if in_hex(px, py, size):
                wave = math.sin(dx * 0.6 + dy * 0.4) * 0.3
                n = noise(px, py, 24)
                c = color_lerp(PALETTE["flag_red"], PALETTE["flag_gold"], n * 0.3 + wave)
                img.putpixel((px, py), c + (255,))

    # 塔身装饰纹样（窗间墙）
    for wy in [tower_cy - 6, tower_cy + 2]:
        for wx in range(tower_cx - tower_w + 3, tower_cx + tower_w - 3):
            if not in_hex(wx, wy, size):
                continue
            if (wx // 4) % 3 == 0:
                c = safe_pixel(img, wx, wy, size)
                if c:
                    img.putpixel((wx, wy), color_add(c, -8, -5, -3) + (255,))

    # 地面铺装（塔基周围）
    for y in range(tower_cy + tower_h // 2 + 8, size - 8):
        for x in range(cx - 20, cx + 20):
            if not in_hex(x, y, size):
                continue
            n = noise(x, y, 25)
            slab_x = (x + 1) % 4
            slab_y = (y + 2) % 4
            if slab_x == 0 or slab_y == 0:
                c = PALETTE["earth_dark"]
            else:
                c = color_lerp(PALETTE["stone_mid"], PALETTE["earth_warm"], n * 0.4)
            img.putpixel((x, y), c + (255,))


# ============================================================
# 主程序
# ============================================================

if __name__ == "__main__":
    print("《山河策》地形图块生成器（增强细节版）")
    print(f"输出尺寸: {FINAL_SIZE}x{FINAL_SIZE} 像素（{RENDER_SIZE}x{RENDER_SIZE} 4x放大）")
    print(f"风格: 像素风，flat-top 六边形")
    print(f"调色板: {len(PALETTE)} 色")
    print("=" * 50)

    terrain_list = [
        ("tile_plain_01.png", draw_plain, "平原 - 草地/田间小路/野花丛/灌木"),
        ("tile_forest_01.png", draw_forest, "森林 - 多层树冠/林下灌木/蘑菇/光斑/倒木"),
        ("tile_mountain_01.png", draw_mountain, "山地 - 岩石纹理/崖壁/碎石坡/积雪带/植被"),
        ("tile_river_01.png", draw_river, "河流 - 水流纹理/波纹/芦苇/浮木/水底石"),
        ("tile_marsh_01.png", draw_marsh, "沼泽 - 湿地泥泞/水坑/芦苇/苔藓/沼气"),
        ("tile_pass_01.png", draw_pass, "关隘 - 城墙/雉堞/拱门/望楼/旗帜/石板路"),
        ("tile_ford_01.png", draw_ford, "浅滩 - 沙底/浅水/石蹬/芦苇"),
        ("tile_plank_road_01.png", draw_plank_road, "栈道 - 木板路/山壁/护栏/藤蔓/铁链"),
        ("tile_arrow_tower_01.png", draw_arrow_tower, "箭楼 - 石砌塔楼/箭窗/中式屋顶/旗帜/台阶"),
    ]

    for name, func, desc in terrain_list:
        print(f"\n生成: {desc}")
        create_tile(name, func)

    print("\n" + "=" * 50)
    print(f"全部完成! 共 {len(terrain_list)} 张图块")
    print(f"输出目录: assets/sprites/terrain/")
