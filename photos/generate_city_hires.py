"""
《山河策》1024x1024 高精度城市插画 - 六边形约束版
正六边形区域 · 15度微俯视 · 夯土碎石过渡 · 正面视角
"""

import os, random, math
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
random.seed(42)

def save(img, *parts):
    p = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)
    print(f"  [OK] {os.path.relpath(p, ROOT)}")

def px(img, x, y, color):
    w, h = img.size
    if 0 <= x < w and 0 <= y < h:
        img.putpixel((x, y), color)

def rect(img, x0, y0, x1, y1, color):
    for y in range(max(0,y0), min(img.size[1],y1+1)):
        for x in range(max(0,x0), min(img.size[0],x1+1)):
            img.putpixel((x, y), color)

def blend(c1, c2, t):
    t = max(0.0, min(1.0, t))
    r = []
    for i in range(min(len(c1), len(c2))):
        r.append(int(c1[i] + (c2[i] - c1[i]) * t))
    return tuple(r)

def gradient_v(img, x0, y0, x1, y1, c_top, c_bot):
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        c = blend(c_top, c_bot, t)
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


# ══════════════════════════════════════════════════════════
#  六边形工具
# ══════════════════════════════════════════════════════════

def hex_vertices(cx, cy, r):
    """平顶正六边形顶点"""
    verts = []
    for i in range(6):
        angle = math.radians(60 * i)
        verts.append((int(cx + r * math.cos(angle)), int(cy + r * math.sin(angle))))
    return verts

def point_in_hex(px_val, py_val, cx, cy, r):
    """判断点是否在平顶正六边形内 (精确几何法)"""
    dx = abs(px_val - cx)
    dy = abs(py_val - cy)
    if dx > r or dy > r * 0.866:
        return False
    return r * 0.866 - dy >= (dx - r * 0.5) * 0.577 if dx > r * 0.5 else True

def create_hex_mask(w, h, cx, cy, r):
    """创建六边形mask (255=可见, 0=透明)"""
    mask = Image.new("L", (w, h), 0)
    for y in range(h):
        for x in range(w):
            if point_in_hex(x, y, cx, cy, r):
                mask.putpixel((x, y), 255)
    return mask

def hex_edge_distance(px_val, py_val, cx, cy, r):
    """计算点到六边形边缘的距离 (内部为正, 外部为负)"""
    dx = abs(px_val - cx)
    dy = abs(py_val - cy)
    # 近似: 用到六条边的最小距离
    # 简化: 用到外接圆和内切圆的距离
    dist_to_circle = r - math.sqrt((px_val - cx)**2 + (py_val - cy)**2)
    # 六边形更精确的SDF
    q2x = abs(px_val - cx)
    q2y = abs(py_val - cy)
    if q2x > r or q2y > r * 0.866:
        return -max(q2x - r, q2y - r * 0.866)
    dot = 0.5 * q2x + 0.866 * q2y
    if dot > r:
        return -(dot - r)
    return min(dist_to_circle, r - dot)


# ══════════════════════════════════════════════════════════
#  材质绘制
# ══════════════════════════════════════════════════════════

def draw_brick_wall(img, x0, y0, x1, y1, base_color, mortar_color=None,
                    brick_w=18, brick_h=10, variation=12):
    if mortar_color is None:
        mortar_color = tuple(max(0, c - 20) for c in base_color[:3])
    bw, bh = brick_w, brick_h
    row = 0
    y = y0
    while y <= y1:
        offset = (bw // 2) if (row % 2) else 0
        x = x0 - offset
        while x <= x1:
            bx0, by0 = max(x0, x), max(y0, y)
            bx1, by1 = min(x1, x + bw - 2), min(y1, y + bh - 2)
            if bx0 <= bx1 and by0 <= by1:
                n = random.randint(-variation, variation)
                brick_c = tuple(max(0, min(255, base_color[i] + n)) for i in range(3))
                rect(img, bx0, by0, bx1, by1, brick_c)
                for hy in range(by0, min(by0 + 2, by1 + 1)):
                    for hx in range(bx0, bx1 + 1):
                        c = img.getpixel((hx, hy))
                        px(img, hx, hy, tuple(min(255, c[i] + 8) for i in range(3)))
                for hy in range(max(by1 - 1, by0), by1 + 1):
                    for hx in range(bx0, bx1 + 1):
                        c = img.getpixel((hx, hy))
                        px(img, hx, hy, tuple(max(0, c[i] - 6) for i in range(3)))
            for gx in range(max(x0, x), min(x1, x + bw - 2) + 1):
                if y0 <= y <= y1: px(img, gx, y, mortar_color)
            for gy in range(max(y0, y), min(y1, y + bh - 2) + 1):
                if x0 <= x <= x1: px(img, x, gy, mortar_color)
            x += bw
        y += bh
        row += 1

def draw_roof_tiles(img, x0, y0, x1, y1, base_color, tile_h=6):
    for y in range(y0, y1 + 1):
        row_in_tile = (y - y0) % tile_h
        shade = -15 if row_in_tile == tile_h - 1 else (10 if row_in_tile == 0 else 0)
        for x in range(x0, x1 + 1):
            n = random.randint(-5, 5)
            edge = 3 if (x - x0) < 3 else 0
            c = tuple(max(0, min(255, base_color[i] + n + shade + edge)) for i in range(3))
            px(img, x, y, c)

def draw_metal_sheen(img, x0, y0, x1, y1, base_color):
    cx_s, cy_s = (x0 + x1) / 2, (y0 + y1) / 2
    max_dist = math.sqrt((x1-x0)**2 + (y1-y0)**2) / 2
    if max_dist == 0: return
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dist = math.sqrt((x - cx_s)**2 + (y - cy_s)**2)
            t = dist / max_dist
            sheen = int(20 * (1 - t * t))
            n = random.randint(-3, 3)
            c = tuple(max(0, min(255, base_color[i] + sheen + n)) for i in range(3))
            px(img, x, y, c)

def draw_gravel(img, x0, y0, x1, y1, base_color, density=0.6):
    """碎石/夯土过渡纹理"""
    rect(img, x0, y0, x1, y1, base_color)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if random.random() < density:
                n = random.randint(-15, 15)
                c = img.getpixel((x, y))
                nc = tuple(max(0, min(255, c[i] + n)) for i in range(3))
                px(img, x, y, nc)
            if random.random() < 0.03:
                # 偶尔大石块
                n = random.randint(-25, -10)
                c = img.getpixel((x, y))
                px(img, x, y, tuple(max(0, min(255, c[i] + n)) for i in range(3)))


# ══════════════════════════════════════════════════════════
#  氛围效果
# ══════════════════════════════════════════════════════════

def apply_vignette(img, hex_mask, strength=0.4, radius=0.5):
    w, h = img.size
    cx, cy = w / 2, h / 2
    for y in range(h):
        for x in range(w):
            if hex_mask.getpixel((x, y)) == 0:
                continue
            dx = (x - cx) / cx
            dy = (y - cy) / cy
            dist = math.sqrt(dx*dx + dy*dy)
            if dist > radius:
                darken = (dist - radius) / (1 - radius) * strength
                c = img.getpixel((x, y))
                nc = tuple(max(0, int(c[i] * (1 - darken))) for i in range(3))
                if len(c) == 4: nc = nc + (c[3],)
                px(img, x, y, nc)

def apply_fog(img, hex_mask, y_start, y_end, color=(120,115,130), density=0.25):
    for y in range(max(0,y_start), min(img.size[1],y_end)):
        t = (y - y_start) / max(1, y_end - y_start)
        local_d = density * math.sin(t * math.pi)
        for x in range(img.size[0]):
            if hex_mask.getpixel((x, y)) == 0: continue
            if random.random() < local_d * 0.08:
                c = img.getpixel((x, y))
                nc = blend(c, color, local_d * 0.4)
                if len(c) == 4: nc = nc + (c[3],)
                px(img, x, y, nc)

def apply_volumetric_light(img, hex_mask, lx, ly, color=(200,160,80), rays=300, length=400):
    for _ in range(rays):
        angle = random.uniform(-0.5, 0.5)
        ray_len = random.randint(length // 2, length)
        start_x = lx + random.randint(-40, 40)
        start_y = ly + random.randint(-40, 40)
        for step in range(0, ray_len, 2):
            x = int(start_x + step * math.sin(angle))
            y = int(start_y + step * math.cos(angle))
            if 0 <= x < img.size[0] and 0 <= y < img.size[1]:
                if hex_mask.getpixel((x, y)) == 0: continue
                falloff = 1 - step / ray_len
                alpha = 0.03 * falloff * falloff
                c = img.getpixel((x, y))
                nc = blend(c, color, alpha)
                if len(c) == 4: nc = nc + (c[3],)
                px(img, x, y, nc)

def draw_clouds(img, y_min, y_max, count=60):
    for _ in range(count):
        cx = random.randint(-50, img.size[0] + 50)
        cy = random.randint(y_min, y_max)
        rx, ry = random.randint(40, 120), random.randint(10, 30)
        brightness = random.randint(-12, -3)
        for dy in range(-ry, ry + 1):
            for dx in range(-rx, rx + 1):
                nx, ny = cx + dx, cy + dy
                if 0 <= nx < img.size[0] and 0 <= ny < img.size[1]:
                    dist = math.sqrt((dx/rx)**2 + (dy/ry)**2)
                    if dist < 1:
                        falloff = (1 - dist) ** 2
                        c = img.getpixel((nx, ny))
                        adj = int(brightness * falloff)
                        nc = tuple(max(0, min(255, c[i] + adj)) for i in range(3))
                        px(img, nx, ny, nc)


# ══════════════════════════════════════════════════════════
#  秦 · 咸阳 · 六边形约束版
# ══════════════════════════════════════════════════════════

def generate_qin_hex():
    W, H = 1024, 1024
    HEX_CX, HEX_CY, HEX_R = 512, 512, 460

    # ── 创建六边形mask ──
    print("  创建六边形mask...")
    hex_mask = create_hex_mask(W, H, HEX_CX, HEX_CY, HEX_R)

    # ── 绘制完整场景到buffer ──
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # 色板
    wall_dark = (45, 40, 35)
    wall_mid = (65, 58, 48)
    wall_light = (80, 72, 60)
    mortar = (35, 30, 25)
    roof_dark = (28, 25, 22)
    roof_mid = (40, 36, 30)
    bronze_c = (130, 100, 55)
    bronze_dark = (90, 70, 40)
    accent_c = (120, 28, 18)
    gold_c = (170, 140, 80)
    gravel_dark = (48, 42, 35)
    gravel_mid = (60, 52, 42)

    # ── 1. 天空 (六边形内) ──
    print("  [1/9] 天空...")
    for y in range(H):
        for x in range(W):
            if hex_mask.getpixel((x, y)) == 0: continue
            t = y / H
            if t < 0.5:
                c = blend((40, 38, 48), (70, 65, 75), t * 2)
            else:
                c = blend((70, 65, 75), (50, 46, 42), (t - 0.5) * 2)
            px(img, x, y, c)
    draw_clouds(img, 20, 350, count=60)

    # ── 2. 远山 ──
    print("  [2/9] 远山...")
    draw = ImageDraw.Draw(img)
    pts = [(0, 420)]
    for x in range(0, W + 1, 4):
        y = int(400 + 25 * math.sin(x * 0.007) + 15 * math.sin(x * 0.02 + 1))
        pts.append((x, y))
    pts += [(W, 420), (W, 470), (0, 470)]
    draw.polygon(pts, fill=(38, 35, 42))

    # ── 3. 地面 (六边形内夯土地面) ──
    print("  [3/9] 地面...")
    for y in range(450, H):
        for x in range(W):
            if hex_mask.getpixel((x, y)) == 0: continue
            t = (y - 450) / (H - 450)
            c = blend((55, 48, 40), (35, 30, 25), t)
            n = random.randint(-6, 6)
            c = tuple(max(0, min(255, c[i] + n)) for i in range(3))
            px(img, x, y, c)

    # ── 4. 城墙主体 ──
    print("  [4/9] 城墙...")
    wall_x0, wall_x1 = 182, 842
    wall_y0, wall_y1 = 440, 720

    draw_brick_wall(img, wall_x0, wall_y0, wall_x1, wall_y1,
                    wall_mid, mortar, brick_w=20, brick_h=12, variation=10)

    # 城墙底部加厚
    draw_brick_wall(img, wall_x0 - 8, wall_y1 - 30, wall_x1 + 8, wall_y1,
                    wall_dark, mortar, brick_w=22, brick_h=14, variation=8)

    # 城墙顶部高光
    for x in range(wall_x0, wall_x1 + 1):
        for y in range(wall_y0, wall_y0 + 4):
            c = img.getpixel((x, y))
            px(img, x, y, tuple(min(255, c[i] + 12) for i in range(3)))

    # 左侧高光
    for x in range(wall_x0, wall_x0 + 12):
        for y in range(wall_y0, wall_y1 + 1):
            c = img.getpixel((x, y))
            t = (x - wall_x0) / 12
            adj = int(10 * (1 - t))
            px(img, x, y, tuple(min(255, c[i] + adj) for i in range(3)))

    # 右侧阴影
    for x in range(wall_x1 - 12, wall_x1 + 1):
        for y in range(wall_y0, wall_y1 + 1):
            c = img.getpixel((x, y))
            t = (wall_x1 - x) / 12
            adj = int(10 * (1 - t))
            px(img, x, y, tuple(max(0, c[i] - adj) for i in range(3)))

    # ── 5. 雉堞 ──
    print("  [5/9] 雉堞与城门...")
    merlon_w, merlon_h = 20, 16
    for mx in range(wall_x0, wall_x1, merlon_w + 6):
        rect(img, mx, wall_y0 - merlon_h, mx + merlon_w, wall_y0, wall_light)
        for x in range(mx, mx + merlon_w + 1):
            for y in range(wall_y0 - merlon_h, wall_y0 - merlon_h + 3):
                if y >= 0:
                    c = img.getpixel((x, y))
                    px(img, x, y, tuple(min(255, c[i] + 10) for i in range(3)))

    # ── 6. 城门 ──
    gate_x0, gate_x1 = 452, 572
    gate_y0, gate_y1 = 560, 720

    rect(img, gate_x0, gate_y0, gate_x1, gate_y1, (12, 10, 8))
    for y in range(gate_y0, gate_y1):
        t = (y - gate_y0) / (gate_y1 - gate_y0)
        for x in range(gate_x0, gate_x1):
            c = img.getpixel((x, y))
            px(img, x, y, tuple(max(0, c[i] - int(8 * t)) for i in range(3)))

    # 门框
    rect(img, gate_x0 - 4, gate_y0, gate_x0, gate_y1, bronze_c)
    rect(img, gate_x1, gate_y0, gate_x1 + 4, gate_y1, bronze_c)
    rect(img, gate_x0 - 4, gate_y0 - 4, gate_x1 + 4, gate_y0, bronze_c)
    draw_metal_sheen(img, gate_x0 - 4, gate_y0, gate_x0, gate_y1, bronze_c)

    # 门钉
    for dy in [0, 50, 100]:
        for dx in [20, 50, 80]:
            nx, ny = gate_x0 + dx, gate_y0 + 15 + dy
            if nx < gate_x1 and ny < gate_y1:
                for r in range(5):
                    for a_step in range(10):
                        a = a_step * math.pi * 2 / 10
                        ppx = int(nx + r * math.cos(a))
                        ppy = int(ny + r * math.sin(a))
                        if gate_x0 < ppx < gate_x1 and gate_y0 < ppy < gate_y1:
                            px(img, ppx, ppy, bronze_c)
                px(img, nx, ny, gold_c)

    # ── 7. 青铜神兽 ──
    print("  [6/9] 青铜神兽...")
    for beast_x in [gate_x0 - 70, gate_x1 + 15]:
        rect(img, beast_x, 660, beast_x + 50, 720, bronze_dark)
        draw_metal_sheen(img, beast_x, 660, beast_x + 50, 720, bronze_dark)
        rect(img, beast_x + 8, 630, beast_x + 42, 660, bronze_c)
        draw_metal_sheen(img, beast_x + 8, 630, beast_x + 42, 660, bronze_c)
        rect(img, beast_x + 14, 610, beast_x + 36, 630, bronze_c)
        rect(img, beast_x + 16, 596, beast_x + 20, 610, gold_c)
        rect(img, beast_x + 30, 596, beast_x + 34, 610, gold_c)
        px(img, beast_x + 20, 616, accent_c)
        px(img, beast_x + 21, 616, accent_c)
        px(img, beast_x + 30, 616, accent_c)
        px(img, beast_x + 31, 616, accent_c)

    # ── 8. 主楼 ──
    print("  [7/9] 主楼...")
    tower_x0, tower_x1 = 382, 642
    tower_y0, tower_y1 = 300, 440

    draw_brick_wall(img, tower_x0, tower_y0, tower_x1, tower_y1,
                    wall_dark, mortar, brick_w=16, brick_h=10, variation=8)

    for x in range(tower_x0, tower_x0 + 8):
        for y in range(tower_y0, tower_y1 + 1):
            c = img.getpixel((x, y))
            px(img, x, y, tuple(min(255, c[i] + 8) for i in range(3)))

    # 箭窗
    for wy in range(tower_y0 + 25, tower_y1 - 15, 35):
        for wx in [tower_x0 + 40, tower_x0 + 100, tower_x0 + 170, tower_x0 + 220]:
            rect(img, wx, wy, wx + 6, wy + 20, (15, 12, 10))
            rect(img, wx - 2, wy - 2, wx, wy + 22, bronze_dark)
            rect(img, wx + 6, wy - 2, wx + 8, wy + 22, bronze_dark)

    # 平顶
    rect(img, tower_x0 - 12, tower_y0 - 10, tower_x1 + 12, tower_y0, roof_mid)
    draw_roof_tiles(img, tower_x0 - 12, tower_y0 - 10, tower_x1 + 12, tower_y0, roof_mid, 4)
    rect(img, tower_x0 - 12, tower_y0 - 12, tower_x1 + 12, tower_y0 - 10, bronze_c)
    draw_metal_sheen(img, tower_x0 - 12, tower_y0 - 12, tower_x1 + 12, tower_y0 - 10, bronze_c)

    # 主楼雉堞
    for mx in range(tower_x0 - 12, tower_x1 + 12, 20):
        rect(img, mx, tower_y0 - 26, mx + 12, tower_y0 - 12, wall_light)

    # 望楼
    rect(img, 490, 275, 534, 300, wall_dark)
    rect(img, 492, 277, 520, 298, wall_mid)
    rect(img, 485, 270, 541, 277, roof_mid)

    # ── 9. 秦旗 ──
    print("  [8/9] 旗帜...")
    for fx in [260, 380, 644, 764]:
        rect(img, fx, 260, fx + 3, 440, bronze_c)
        draw_metal_sheen(img, fx, 260, fx + 3, 440, bronze_c)
        rect(img, fx - 2, 255, fx + 5, 262, gold_c)
        for row in range(70):
            t = row / 70
            w = int(42 * (1 - t * 0.3))
            y = 270 + row
            for x in range(fx + 4, fx + 4 + w):
                if 0 <= x < W:
                    n = random.randint(-5, 5)
                    px(img, x, y, (max(0,120+n), max(0,28+n), max(0,18+n)))
        for row in range(15, 50):
            y = 270 + row
            px(img, fx + 20, y, gold_c)
            px(img, fx + 21, y, gold_c)

    # ── 10. 六边形边缘过渡 (夯土碎石) ──
    print("  [9/9] 六边形过渡与氛围...")
    # 在六边形边缘内侧添加碎石/夯土过渡带
    transition_width = 30
    for y in range(H):
        for x in range(W):
            if hex_mask.getpixel((x, y)) == 0: continue
            dist = hex_edge_distance(x, y, HEX_CX, HEX_CY, HEX_R)
            if 0 < dist < transition_width:
                # 过渡带: 从城市地面到碎石
                t = 1 - dist / transition_width
                c = img.getpixel((x, y))
                gravel_c = blend(gravel_mid, gravel_dark, random.uniform(0, 0.3))
                nc = blend(c, gravel_c, t * 0.6)
                # 添加碎石噪声
                n = random.randint(-10, 10)
                nc = tuple(max(0, min(255, nc[i] + n)) for i in range(3))
                if len(c) == 4: nc = nc + (c[3],)
                px(img, x, y, nc)

    # ── 氛围效果 ──
    apply_volumetric_light(img, hex_mask, 200, 50, (180, 150, 90), 200, 350)
    apply_fog(img, hex_mask, 680, 850, (90, 82, 75), 0.2)
    apply_fog(img, hex_mask, 400, 470, (100, 95, 105), 0.12)
    apply_vignette(img, hex_mask, 0.4, 0.5)

    # ── 应用六边形mask ──
    print("  应用六边形mask...")
    img.putalpha(hex_mask)

    return img


if __name__ == "__main__":
    print("=== 生成秦·咸阳 1024x1024 六边形约束版 ===")
    img = generate_qin_hex()
    save(img, "city", "city_capital_qin_hex.png")
    print("\n完成!")
