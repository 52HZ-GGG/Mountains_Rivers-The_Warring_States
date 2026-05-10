"""
《山河策》精细资产重制器
参考像素大作风格，重制事件插画、头像、旗帜、单位、特效
"""

import os, math, random
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))

def save(img, *parts):
    p = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)
    print(f"  [OK] {os.path.relpath(p, ROOT)}")

def font(size):
    for n in ["msyh.ttc", "simhei.ttf", "simsun.ttc", "arial.ttf"]:
        try: return ImageFont.truetype(n, size)
        except: continue
    return ImageFont.load_default()

def hex_pts(cx, cy, r):
    return [(cx + r * math.sin(math.radians(60 * i)),
             cy - r * math.cos(math.radians(60 * i))) for i in range(6)]

def lerp_color(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))

def gradient_rect(draw, x0, y0, x1, y1, c1, c2, vertical=True):
    for i in range(y1 - y0 if vertical else x1 - x0):
        t = i / max(1, (y1 - y0 if vertical else x1 - x0) - 1)
        c = lerp_color(c1, c2, t)
        if vertical:
            draw.line([(x0, y0 + i), (x1, y0 + i)], fill=c)
        else:
            draw.line([(x0 + i, y0), (x0 + i, y1)], fill=c)

def draw_star(draw, cx, cy, r, color, points=5):
    pts = []
    for i in range(points * 2):
        angle = math.radians(90 + 360 * i / (points * 2))
        radius = r if i % 2 == 0 else r * 0.4
        pts.append((cx + radius * math.cos(angle), cy - radius * math.sin(angle)))
    draw.polygon(pts, fill=color)

# ============================================================
#  色板
# ============================================================
C = {
    "漆红": ((140, 69, 34), (176, 93, 59), (102, 48, 24), (64, 29, 15)),
    "铜靛": ((43, 51, 48), (69, 82, 77), (26, 33, 30), (13, 18, 16)),
    "竹黄": ((197, 163, 104), (217, 190, 139), (153, 122, 74), (102, 82, 49)),
    "墨黑": ((26, 26, 27), (51, 51, 52), (13, 13, 14), (0, 0, 0)),
    "血红": ((180, 45, 35), (220, 75, 55), (130, 30, 22), (80, 18, 12)),
    "金黄": ((210, 180, 80), (240, 210, 120), (170, 140, 55), (120, 95, 35)),
    "苍绿": ((55, 90, 55), (78, 115, 78), (38, 62, 38), (22, 40, 22)),
    "青灰": ((100, 110, 120), (135, 145, 155), (70, 78, 88), (45, 50, 58)),
    "烟紫": ((90, 60, 100), (120, 85, 135), (60, 38, 70), (35, 20, 42)),
    "夕橙": ((200, 120, 50), (240, 160, 80), (155, 85, 30), (100, 55, 18)),
}

# ============================================================
#  事件插画 - 精细版 (512x384, 多层场景)
# ============================================================

def make_event_scene(sky_c1, sky_c2, ground_c, elements, effects, frame_c, title, subtitle=""):
    """通用事件场景生成器"""
    W, H = 512, 384
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 天空渐变
    gradient_rect(draw, 0, 0, W, H // 2 + 40, sky_c1, sky_c2)

    # 地面
    ground_y = H // 2 + 40
    gradient_rect(draw, 0, ground_y, W, H, ground_c, lerp_color(ground_c, (0, 0, 0), 0.4))

    # 远山剪影
    for peak_x, peak_h, peak_w in [(100, ground_y - 60, 140), (280, ground_y - 45, 180),
                                     (420, ground_y - 70, 160)]:
        pts = [(peak_x - peak_w, ground_y)]
        for i in range(20):
            t = i / 19
            x = peak_x - peak_w + 2 * peak_w * t
            y = ground_y - peak_h * math.sin(math.pi * t) + random.randint(-3, 3)
            pts.append((x, y))
        pts.append((peak_x + peak_w, ground_y))
        silhouette = lerp_color(sky_c2, ground_c, 0.6)
        draw.polygon(pts, fill=(*silhouette, 120))

    # 场景元素
    for elem in elements:
        elem(draw, W, H, ground_y)

    # 特效层
    for eff in effects:
        eff(draw, W, H, ground_y)

    # 边框 (青铜纹饰感)
    bw = 6
    draw.rectangle([0, 0, W - 1, H - 1], outline=(*frame_c[0], 200), width=bw)
    draw.rectangle([bw, bw, W - bw - 1, H - bw - 1], outline=(*frame_c[2], 150), width=1)
    # 角饰
    for cx, cy in [(bw + 8, bw + 8), (W - bw - 9, bw + 8), (bw + 8, H - bw - 9), (W - bw - 9, H - bw - 9)]:
        draw.rectangle([cx - 3, cy - 3, cx + 3, cy + 3], fill=(*frame_c[1], 180))

    # 底部标题条
    title_h = 52
    for y in range(H - title_h, H):
        alpha = int(220 * (y - (H - title_h)) / title_h)
        draw.line([(bw, y), (W - bw, y)], fill=(*C["墨黑"][3], alpha))
    draw.rectangle([bw, H - title_h, W - bw, H - title_h + 1], fill=(*frame_c[1], 160))

    ft = font(22)
    ft_sm = font(12)
    draw.text((W // 2, H - title_h + 18), title, fill=(*C["竹黄"][1], 240), font=ft, anchor="mm")
    if subtitle:
        draw.text((W // 2, H - title_h + 38), subtitle, fill=(*C["竹黄"][2], 180), font=ft_sm, anchor="mm")

    return img

# --- 场景元素生成器 ---

def elem_warriors(draw, W, H, gy, count=5, color_key="漆红", pose="stand"):
    """武士群像"""
    base_c = C[color_key]
    for i in range(count):
        x = W // 2 + (i - count // 2) * 45 + random.randint(-8, 8)
        y = gy + 15 + random.randint(-5, 15)
        h = random.randint(55, 70)
        # 阴影
        draw.ellipse([x - 12, y + 2, x + 12, y + 7], fill=(0, 0, 0, 50))
        # 腿
        draw.rectangle([x - 5, y - h // 3, x - 2, y], fill=(*base_c[2], 220))
        draw.rectangle([x + 2, y - h // 3, x + 5, y], fill=(*base_c[2], 220))
        # 身体
        draw.rectangle([x - 8, y - h * 2 // 3, x + 8, y - h // 3 + 2], fill=(*base_c[0], 230))
        # 铠甲高光
        draw.rectangle([x - 6, y - h * 2 // 3 + 2, x - 2, y - h // 3 - 2], fill=(*base_c[1], 160))
        # 头
        draw.ellipse([x - 6, y - h, x + 6, y - h * 2 // 3], fill=(*C["竹黄"][1], 220))
        # 冠/盔
        draw.rectangle([x - 7, y - h - 4, x + 7, y - h + 2], fill=(*base_c[2], 200))
        # 兵器
        if pose == "stand":
            draw.line([(x + 10, y - h + 5), (x + 10, y + 5)], fill=(*C["青灰"][1], 200), width=2)
            draw.rectangle([x + 7, y - h + 3, x + 13, y - h + 8], fill=(*C["青灰"][0], 200))
        elif pose == "bow":
            draw.arc([x + 8, y - h * 2 // 3, x + 22, y - h // 3], 200, 340,
                     fill=(*C["苍绿"][2], 200), width=2)
        elif pose == "charge":
            draw.polygon([(x + 10, y - h * 2 // 3 - 5), (x + 25, y - h // 2),
                          (x + 10, y - h // 3 + 5)], fill=(*C["青灰"][0], 200))

def elem_city_burning(draw, W, H, gy):
    """燃烧的城池"""
    cx = W // 2
    # 城墙
    for bx in range(cx - 80, cx + 80, 16):
        draw.rectangle([bx, gy - 50, bx + 12, gy + 10], fill=(*C["铜靛"][2], 220))
        draw.rectangle([bx + 1, gy - 48, bx + 4, gy - 44], fill=(*C["铜靛"][1], 160))
    # 城楼
    draw.rectangle([cx - 25, gy - 80, cx + 25, gy - 48], fill=(*C["铜靛"][0], 230))
    draw.polygon([(cx, gy - 100), (cx - 30, gy - 78), (cx + 30, gy - 78)], fill=(*C["铜靛"][2], 200))
    # 城门
    draw.ellipse([cx - 10, gy - 25, cx + 10, gy + 10], fill=(*C["墨黑"][3], 200))
    # 火焰
    for _ in range(15):
        fx = cx + random.randint(-70, 70)
        fy = gy + random.randint(-90, -10)
        fr = random.randint(4, 12)
        fc = random.choice([C["血红"][0], C["血红"][1], C["夕橙"][0], C["金黄"][0]])
        draw.ellipse([fx - fr, fy - fr, fx + fr, fy + fr // 2], fill=(*fc, 180))
    # 烟尘
    for _ in range(8):
        sx = cx + random.randint(-60, 60)
        sy = gy + random.randint(-120, -60)
        sr = random.randint(8, 20)
        draw.ellipse([sx - sr, sy - sr // 2, sx + sr, sy + sr // 2], fill=(*C["青灰"][2], 60))

def elem_throne(draw, W, H, gy):
    """王座"""
    cx = W // 2
    # 台阶
    for i in range(4):
        w = 60 + i * 20
        draw.rectangle([cx - w, gy - 5 - i * 10, cx + w, gy + 5 - i * 10],
                       fill=(*lerp_color(C["铜靛"][0], C["金黄"][0], i / 4), 200))
    # 座椅
    draw.rectangle([cx - 30, gy - 80, cx + 30, gy - 20], fill=(*C["漆红"][0], 230))
    draw.rectangle([cx - 25, gy - 75, cx + 25, gy - 25], fill=(*C["漆红"][1], 200))
    # 靠背装饰
    draw.polygon([(cx, gy - 110), (cx - 35, gy - 78), (cx + 35, gy - 78)],
                 fill=(*C["金黄"][0], 200))
    draw.ellipse([cx - 8, gy - 100, cx + 8, gy - 88], fill=(*C["金黄"][1], 220))
    # 扶手
    for dx in [-30, 30]:
        draw.rectangle([cx + dx - 5, gy - 50, cx + dx + 5, gy - 20], fill=(*C["金黄"][2], 200))
        draw.ellipse([cx + dx - 6, gy - 54, cx + dx + 6, gy - 46], fill=(*C["金黄"][1], 200))

def elem_mountain_pass(draw, W, H, gy):
    """关隘"""
    cx = W // 2
    # 左山
    draw.polygon([(0, gy + 20), (0, 20), (cx - 40, gy - 30), (cx - 40, gy + 20)],
                 fill=(*C["青灰"][2], 200))
    # 右山
    draw.polygon([(W, gy + 20), (W, 30), (cx + 40, gy - 25), (cx + 40, gy + 20)],
                 fill=(*C["青灰"][2], 200))
    # 城门
    draw.rectangle([cx - 40, gy - 60, cx + 40, gy + 20], fill=(*C["铜靛"][0], 230))
    draw.rectangle([cx - 12, gy - 15, cx + 12, gy + 20], fill=(*C["墨黑"][3], 220))
    # 烽火台
    draw.rectangle([cx - 8, gy - 90, cx + 8, gy - 58], fill=(*C["铜靛"][2], 220))
    # 烽火
    for _ in range(6):
        fx = cx + random.randint(-6, 6)
        fy = gy - 100 + random.randint(-15, 0)
        fr = random.randint(3, 7)
        draw.ellipse([fx - fr, fy - fr, fx + fr, fy], fill=(*C["夕橙"][0], 180))

def elem_river_crossing(draw, W, H, gy):
    """渡河"""
    # 河流
    for y in range(gy - 10, gy + 40):
        t = (y - gy + 10) / 50
        c = lerp_color(C["铜靛"][0], C["铜靛"][2], t)
        draw.line([(0, y), (W, y)], fill=(*c, 180))
    # 波纹
    for _ in range(12):
        wx = random.randint(20, W - 20)
        wy = gy + random.randint(-5, 30)
        draw.arc([wx - 8, wy - 2, wx + 8, wy + 2], 0, 180, fill=(*C["铜靛"][1], 120), width=1)
    # 浮桥
    for bx in range(60, W - 60, 20):
        draw.rectangle([bx, gy - 5, bx + 15, gy], fill=(*C["苍绿"][2], 200))
    # 渡河士兵
    for i in range(4):
        x = 120 + i * 80
        y = gy - 15
        draw.rectangle([x - 4, y - 20, x + 4, y], fill=(*C["漆红"][0], 200))
        draw.ellipse([x - 4, y - 28, x + 4, y - 18], fill=(*C["竹黄"][1], 200))

def elem_scroll_ceremony(draw, W, H, gy):
    """变法/改革 - 竹简卷轴"""
    cx = W // 2
    # 卷轴主体
    draw.rectangle([cx - 60, gy - 90, cx + 60, gy + 10], fill=(*C["竹黄"][0], 230))
    # 卷轴上下轴
    for yy in [gy - 92, gy + 8]:
        draw.rectangle([cx - 65, yy, cx + 65, yy + 6], fill=(*C["漆红"][0], 220))
        draw.ellipse([cx - 68, yy - 1, cx - 60, yy + 7], fill=(*C["漆红"][1], 200))
        draw.ellipse([cx + 60, yy - 1, cx + 68, yy + 7], fill=(*C["漆红"][1], 200))
    # 竹简线条
    for i in range(7):
        y = gy - 75 + i * 12
        draw.line([(cx - 50, y), (cx + 50, y)], fill=(*C["竹黄"][3], 150), width=1)
    # 文字提示 (竖排小点模拟)
    for i in range(5):
        for j in range(6):
            x = cx - 40 + j * 15
            y = gy - 70 + i * 12
            draw.rectangle([x, y, x + 3, y + 3], fill=(*C["墨黑"][0], 180))

def elem_funeral(draw, W, H, gy):
    """祭祀/丧葬"""
    cx = W // 2
    # 祭台
    draw.rectangle([cx - 50, gy - 15, cx + 50, gy + 10], fill=(*C["铜靛"][0], 220))
    draw.rectangle([cx - 45, gy - 25, cx + 45, gy - 13], fill=(*C["铜靛"][1], 200))
    # 鼎
    draw.rectangle([cx - 15, gy - 55, cx + 15, gy - 25], fill=(*C["铜靛"][2], 230))
    draw.rectangle([cx - 18, gy - 58, cx + 18, gy - 53], fill=(*C["铜靛"][1], 200))
    # 鼎足
    for dx in [-12, 0, 12]:
        draw.rectangle([cx + dx - 3, gy - 25, cx + dx + 3, gy - 18], fill=(*C["铜靛"][2], 200))
    # 香烟
    for i in range(5):
        sx = cx + random.randint(-8, 8)
        sy = gy - 65 - i * 12
        draw.ellipse([sx - 4, sy - 3, sx + 4, sy + 3], fill=(*C["青灰"][1], 80 - i * 12))

def elem_spy(draw, W, H, gy):
    """间谍/暗杀"""
    cx = W // 2
    # 月亮
    draw.ellipse([W - 80, 30, W - 40, 70], fill=(*C["竹黄"][1], 180))
    draw.ellipse([W - 70, 28, W - 35, 65], fill=(*lerp_color(C["墨黑"][0], C["铜靛"][0], 0.3), 200))
    # 黑衣人
    x = cx + 30
    y = gy
    # 披风
    draw.polygon([(x - 15, y - 50), (x + 15, y - 50), (x + 25, y), (x - 25, y)],
                 fill=(*C["墨黑"][0], 220))
    # 头
    draw.ellipse([x - 6, y - 60, x + 6, y - 48], fill=(*C["墨黑"][1], 220))
    # 眼睛
    draw.rectangle([x - 4, y - 56, x - 1, y - 54], fill=(*C["竹黄"][1], 200))
    draw.rectangle([x + 1, y - 56, x + 4, y - 54], fill=(*C["竹黄"][1], 200))
    # 匕首
    draw.polygon([(x + 15, y - 35), (x + 30, y - 40), (x + 15, y - 25)], fill=(*C["青灰"][1], 200))

def elem_harvest(draw, W, H, gy):
    """丰收"""
    # 麦田
    for x in range(0, W, 8):
        for y in range(gy - 20, gy + 20, 10):
            h = random.randint(12, 20)
            draw.line([(x + 4, y), (x + 4, y - h)], fill=(*C["金黄"][0], 200), width=1)
            draw.ellipse([x + 1, y - h - 3, x + 7, y - h + 1], fill=(*C["金黄"][1], 180))
    # 农人
    for x in [120, 280, 400]:
        draw.rectangle([x - 4, gy - 20, x + 4, gy], fill=(*C["竹黄"][2], 200))
        draw.ellipse([x - 4, gy - 28, x + 4, gy - 18], fill=(*C["竹黄"][1], 200))
        # 镰刀
        draw.arc([x + 4, gy - 25, x + 18, gy - 10], 200, 350, fill=(*C["青灰"][1], 200), width=2)

def elem_famine(draw, W, H, gy):
    """饥荒"""
    cx = W // 2
    # 枯树
    draw.rectangle([cx - 4, gy - 70, cx + 4, gy], fill=(*C["铜靛"][3], 200))
    for dx, dy, angle in [(-25, -65, 210), (20, -60, 330), (-10, -75, 250)]:
        x1, y1 = cx + dx, gy + dy
        x2 = x1 + int(25 * math.cos(math.radians(angle)))
        y2 = y1 + int(25 * math.sin(math.radians(angle)))
        draw.line([(x1, y1), (x2, y2)], fill=(*C["铜靛"][3], 180), width=2)
    # 龟裂地面
    for _ in range(15):
        x = random.randint(20, W - 20)
        y = gy + random.randint(5, 30)
        for _ in range(3):
            x2 = x + random.randint(-15, 15)
            y2 = y + random.randint(-5, 10)
            draw.line([(x, y), (x2, y2)], fill=(*C["铜靛"][3], 120), width=1)
    # 饿殍
    for x in [100, 350]:
        draw.rectangle([x - 3, gy - 12, x + 3, gy], fill=(*C["竹黄"][3], 180))
        draw.ellipse([x - 3, gy - 18, x + 3, gy - 10], fill=(*C["竹黄"][2], 180))

def elem_alliance(draw, W, H, gy):
    """结盟 - 两人对坐"""
    cx = W // 2
    # 案几
    draw.rectangle([cx - 40, gy - 20, cx + 40, gy - 10], fill=(*C["漆红"][2], 220))
    draw.rectangle([cx - 35, gy - 10, cx - 30, gy + 5], fill=(*C["漆红"][2], 200))
    draw.rectangle([cx + 30, gy - 10, cx + 35, gy + 5], fill=(*C["漆红"][2], 200))
    # 酒爵
    draw.polygon([(cx - 8, gy - 25), (cx + 8, gy - 25), (cx + 5, gy - 18), (cx - 5, gy - 18)],
                 fill=(*C["铜靛"][1], 200))
    draw.rectangle([cx - 2, gy - 18, cx + 2, gy - 12], fill=(*C["铜靛"][1], 200))
    # 左人
    for x, ck in [(cx - 70, "漆红"), (cx + 70, "铜靛")]:
        draw.rectangle([x - 8, gy - 35, x + 8, gy - 5], fill=(*C[ck][0], 220))
        draw.ellipse([x - 7, gy - 48, x + 7, gy - 33], fill=(*C["竹黄"][1], 220))
        draw.rectangle([x - 8, gy - 52, x + 8, gy - 46], fill=(*C[ck][2], 200))

def elem_tribute(draw, W, H, gy):
    """纳贡/朝贡"""
    cx = W // 2
    # 宝箱
    draw.rectangle([cx - 20, gy - 15, cx + 20, gy + 5], fill=(*C["漆红"][0], 220))
    draw.rectangle([cx - 22, gy - 18, cx + 22, gy - 13], fill=(*C["漆红"][1], 200))
    draw.rectangle([cx - 3, gy - 12, cx + 3, gy - 5], fill=(*C["金黄"][0], 200))
    # 金光
    for _ in range(8):
        gx = cx + random.randint(-15, 15)
        gy2 = gy - 20 + random.randint(-10, 0)
        draw_star(draw, gx, gy2, 4, (*C["金黄"][1], 150))
    # 跪拜的人
    for x in [cx - 60, cx + 60]:
        draw.ellipse([x - 5, gy - 15, x + 5, gy - 5], fill=(*C["竹黄"][1], 200))
        draw.polygon([(x - 10, gy - 5), (x + 10, gy - 5), (x + 15, gy + 5), (x - 15, gy + 5)],
                     fill=(*C["铜靛"][0], 200))

# --- 特效生成器 ---

def fx_fire_glow(draw, W, H, gy):
    """火光"""
    for _ in range(20):
        x = W // 2 + random.randint(-80, 80)
        y = gy + random.randint(-100, -20)
        r = random.randint(2, 6)
        c = random.choice([C["血红"][1], C["夕橙"][0], C["金黄"][0]])
        draw.ellipse([x - r, y - r, x + r, y + r], fill=(*c, random.randint(60, 150)))

def fx_moonlight(draw, W, H, gy):
    """月光"""
    for y in range(0, gy, 3):
        alpha = max(5, 30 - y // 5)
        draw.line([(W // 2 - 40 + y // 3, y), (W // 2 + 40 + y // 3, y)],
                  fill=(*C["竹黄"][1], alpha))

def fx_smoke(draw, W, H, gy):
    """烟尘"""
    for _ in range(12):
        x = W // 2 + random.randint(-70, 70)
        y = gy + random.randint(-130, -40)
        r = random.randint(10, 25)
        draw.ellipse([x - r, y - r // 2, x + r, y + r // 2], fill=(*C["青灰"][2], random.randint(20, 50)))

def fx_rain(draw, W, H, gy):
    """雨"""
    for _ in range(60):
        x = random.randint(0, W)
        y = random.randint(0, H)
        draw.line([(x, y), (x - 2, y + 8)], fill=(*C["铜靛"][1], random.randint(40, 100)), width=1)

def fx_gold_dust(draw, W, H, gy):
    """金色微粒"""
    for _ in range(20):
        x = random.randint(30, W - 30)
        y = random.randint(30, gy + 20)
        r = random.randint(1, 3)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=(*C["金黄"][1], random.randint(80, 180)))

def fx_dark_vignette(draw, W, H, gy):
    """暗角"""
    for i in range(40):
        alpha = int(80 * (1 - i / 40))
        draw.rectangle([i, i, W - i, H - i], outline=(0, 0, 0, alpha))

def fx_wind_particles(draw, W, H, gy):
    """风沙粒子"""
    for _ in range(25):
        x = random.randint(0, W)
        y = random.randint(gy - 30, gy + 30)
        draw.line([(x, y), (x + random.randint(5, 15), y + random.randint(-2, 2))],
                  fill=(*C["竹黄"][2], random.randint(40, 100)), width=1)

# ============================================================
#  事件定义
# ============================================================
EVENTS = {
    # --- 外交 ---
    "缔约": dict(sky_c1=(60, 70, 90), sky_c2=(120, 130, 150), ground_c=(80, 90, 70),
                 elements=[elem_alliance], effects=[fx_gold_dust],
                 frame_c=C["竹黄"], subtitle="两国歃血为盟，共谋天下"),
    "背盟": dict(sky_c1=(50, 35, 40), sky_c2=(90, 60, 65), ground_c=(60, 50, 45),
                 elements=[elem_alliance], effects=[fx_dark_vignette],
                 frame_c=C["血红"], subtitle="盟约化为齑粉，刀兵相向"),
    "纳贡": dict(sky_c1=(80, 75, 60), sky_c2=(150, 140, 110), ground_c=(100, 90, 70),
                 elements=[elem_tribute], effects=[fx_gold_dust],
                 frame_c=C["金黄"], subtitle="奇珍异宝，车载斗量"),
    "朝贡": dict(sky_c1=(80, 75, 60), sky_c2=(150, 140, 110), ground_c=(100, 90, 70),
                 elements=[elem_tribute], effects=[fx_gold_dust],
                 frame_c=C["金黄"], subtitle="万国来朝，四海臣服"),
    "宣战": dict(sky_c1=(60, 30, 25), sky_c2=(120, 50, 40), ground_c=(50, 40, 35),
                 elements=[lambda draw, W, H, gy: elem_warriors(draw, W, H, gy, 6, "漆红", "charge")],
                 effects=[fx_fire_glow, fx_smoke],
                 frame_c=C["血红"], subtitle="战鼓擂动，铁骑踏尘"),
    "结盟": dict(sky_c1=(60, 70, 90), sky_c2=(120, 130, 150), ground_c=(80, 90, 70),
                 elements=[elem_alliance], effects=[fx_gold_dust],
                 frame_c=C["竹黄"], subtitle="歃血为盟，共赴国难"),
    "停战": dict(sky_c1=(70, 80, 100), sky_c2=(140, 150, 170), ground_c=(90, 100, 80),
                 elements=[elem_alliance], effects=[],
                 frame_c=C["铜靛"], subtitle="刀兵入库，马放南山"),
    # --- 学派 ---
    "变法": dict(sky_c1=(70, 60, 50), sky_c2=(130, 110, 90), ground_c=(80, 70, 55),
                 elements=[elem_scroll_ceremony], effects=[fx_gold_dust],
                 frame_c=C["金黄"], subtitle="法令既出，举国震动"),
    "合纵": dict(sky_c1=(55, 65, 85), sky_c2=(100, 115, 140), ground_c=(70, 80, 65),
                 elements=[lambda draw, W, H, gy: elem_warriors(draw, W, H, gy, 7, "铜靛", "stand")],
                 effects=[fx_wind_particles],
                 frame_c=C["铜靛"], subtitle="六国合纵，共抗强秦"),
    "连横": dict(sky_c1=(65, 45, 35), sky_c2=(130, 85, 65), ground_c=(75, 60, 48),
                 elements=[lambda draw, W, H, gy: elem_warriors(draw, W, H, gy, 4, "漆红", "charge")],
                 effects=[fx_smoke],
                 frame_c=C["漆红"], subtitle="远交近攻，各个击破"),
    "改革": dict(sky_c1=(70, 60, 50), sky_c2=(130, 110, 90), ground_c=(80, 70, 55),
                 elements=[elem_scroll_ceremony], effects=[fx_gold_dust],
                 frame_c=C["竹黄"], subtitle="除旧布新，强国之基"),
    # --- 战斗 ---
    "攻城": dict(sky_c1=(50, 30, 25), sky_c2=(100, 50, 40), ground_c=(45, 35, 30),
                 elements=[elem_city_burning], effects=[fx_fire_glow, fx_smoke],
                 frame_c=C["血红"], subtitle="云梯高架，城破在即"),
    "伏击": dict(sky_c1=(30, 35, 45), sky_c2=(55, 60, 75), ground_c=(35, 40, 35),
                 elements=[elem_mountain_pass, lambda draw, W, H, gy: elem_warriors(draw, W, H, gy, 3, "苍绿", "bow")],
                 effects=[fx_dark_vignette],
                 frame_c=C["苍绿"], subtitle="伏兵四起，箭如雨下"),
    "火攻": dict(sky_c1=(60, 30, 20), sky_c2=(140, 60, 35), ground_c=(50, 35, 25),
                 elements=[elem_city_burning], effects=[fx_fire_glow, fx_smoke],
                 frame_c=C["夕橙"], subtitle="火烧连营，赤地千里"),
    "断粮": dict(sky_c1=(60, 55, 50), sky_c2=(110, 100, 90), ground_c=(65, 60, 50),
                 elements=[elem_famine], effects=[fx_wind_particles],
                 frame_c=C["铜靛"], subtitle="粮道被断，军心动摇"),
    "突围": dict(sky_c1=(40, 35, 50), sky_c2=(80, 65, 90), ground_c=(45, 40, 38),
                 elements=[lambda draw, W, H, gy: elem_warriors(draw, W, H, gy, 4, "漆红", "charge")],
                 effects=[fx_fire_glow],
                 frame_c=C["烟紫"], subtitle="破釜沉舟，死中求生"),
    "围困": dict(sky_c1=(45, 40, 42), sky_c2=(85, 75, 78), ground_c=(50, 45, 40),
                 elements=[elem_city_burning, lambda draw, W, H, gy: elem_warriors(draw, W, H, gy, 8, "铜靛", "stand")],
                 effects=[fx_smoke, fx_dark_vignette],
                 frame_c=C["铜靛"], subtitle="四面楚歌，内无粮草"),
    # --- 内政 ---
    "登基": dict(sky_c1=(80, 65, 45), sky_c2=(160, 130, 80), ground_c=(90, 75, 55),
                 elements=[elem_throne, lambda draw, W, H, gy: elem_warriors(draw, W, H, gy, 5, "金黄", "stand")],
                 effects=[fx_gold_dust],
                 frame_c=C["金黄"], subtitle="黄袍加身，君临天下"),
    "称帝": dict(sky_c1=(80, 65, 45), sky_c2=(160, 130, 80), ground_c=(90, 75, 55),
                 elements=[elem_throne], effects=[fx_gold_dust],
                 frame_c=C["金黄"], subtitle="天命所归，开国称帝"),
    "叛乱": dict(sky_c1=(45, 30, 30), sky_c2=(90, 50, 45), ground_c=(50, 38, 33),
                 elements=[lambda draw, W, H, gy: elem_warriors(draw, W, H, gy, 6, "血红", "charge")],
                 effects=[fx_fire_glow, fx_smoke],
                 frame_c=C["血红"], subtitle="烽烟四起，群雄并立"),
    "饥荒": dict(sky_c1=(65, 60, 55), sky_c2=(120, 110, 100), ground_c=(70, 65, 55),
                 elements=[elem_famine], effects=[fx_wind_particles, fx_dark_vignette],
                 frame_c=C["铜靛"], subtitle="赤地千里，饿殍遍野"),
    "丰收": dict(sky_c1=(85, 95, 70), sky_c2=(170, 185, 140), ground_c=(110, 120, 85),
                 elements=[elem_harvest], effects=[fx_gold_dust],
                 frame_c=C["金黄"], subtitle="五谷丰登，国泰民安"),
    "祭祀": dict(sky_c1=(40, 35, 55), sky_c2=(75, 65, 95), ground_c=(50, 45, 55),
                 elements=[elem_funeral], effects=[fx_moonlight],
                 frame_c=C["烟紫"], subtitle="钟鸣鼎食，祭告天地"),
    "求贤": dict(sky_c1=(70, 75, 85), sky_c2=(140, 145, 160), ground_c=(85, 90, 78),
                 elements=[elem_scroll_ceremony], effects=[fx_gold_dust],
                 frame_c=C["竹黄"], subtitle="千金买骨，天下归心"),
    "间谍": dict(sky_c1=(20, 22, 30), sky_c2=(40, 42, 55), ground_c=(25, 28, 25),
                 elements=[elem_spy], effects=[fx_dark_vignette, fx_moonlight],
                 frame_c=C["墨黑"], subtitle="暗影潜行，一击致命"),
    # --- 大事件 ---
    "灭国": dict(sky_c1=(50, 25, 20), sky_c2=(100, 40, 30), ground_c=(40, 28, 22),
                 elements=[elem_city_burning, lambda draw, W, H, gy: elem_warriors(draw, W, H, gy, 8, "漆红", "charge")],
                 effects=[fx_fire_glow, fx_smoke, fx_dark_vignette],
                 frame_c=C["血红"], subtitle="社稷倾覆，宗庙为墟"),
    "统一": dict(sky_c1=(80, 75, 55), sky_c2=(170, 160, 110), ground_c=(100, 95, 70),
                 elements=[elem_throne, lambda draw, W, H, gy: elem_warriors(draw, W, H, gy, 10, "金黄", "stand")],
                 effects=[fx_gold_dust],
                 frame_c=C["金黄"], subtitle="六王毕，四海一"),
    "迁都": dict(sky_c1=(65, 70, 80), sky_c2=(130, 140, 155), ground_c=(80, 85, 72),
                 elements=[lambda draw, W, H, gy: elem_warriors(draw, W, H, gy, 5, "铜靛", "stand")],
                 effects=[fx_wind_particles],
                 frame_c=C["铜靛"], subtitle="车辚辚，马萧萧"),
    "筑城": dict(sky_c1=(70, 70, 65), sky_c2=(140, 138, 125), ground_c=(85, 82, 70),
                 elements=[elem_city_burning], effects=[],
                 frame_c=C["铜靛"], subtitle="夯土为墙，立国之本"),
    "开河": dict(sky_c1=(55, 80, 110), sky_c2=(110, 155, 195), ground_c=(70, 90, 75),
                 elements=[elem_river_crossing], effects=[],
                 frame_c=C["铜靛"], subtitle="开凿沟渠，灌溉万顷"),
}

# ============================================================
#  头像 - 精细版 (256x256)
# ============================================================
def draw_portrait_refined(size, name, color_key, features="default"):
    W, H = size
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    base_c = C[color_key]

    # 背景渐变圆
    for r in range(120, 0, -1):
        t = r / 120
        c = lerp_color(base_c[3], base_c[2], 1 - t)
        alpha = int(200 * (1 - t * 0.5))
        draw.ellipse([128 - r, 128 - r, 128 + r, 128 + r], fill=(*c, alpha))

    # 身体/衣袍
    draw.polygon([(80, 200), (128, 170), (176, 200), (190, 280), (66, 280)],
                 fill=(*base_c[0], 230))
    # 衣领
    draw.polygon([(110, 175), (128, 185), (146, 175), (140, 200), (116, 200)],
                 fill=(*base_c[1], 200))
    # 衣领纹饰
    for y in range(185, 200, 4):
        draw.line([(120, y), (136, y)], fill=(*C["金黄"][2], 120), width=1)

    # 脖子
    draw.rectangle([120, 155, 136, 175], fill=(*C["竹黄"][0], 220))

    # 头部
    draw.ellipse([98, 90, 158, 165], fill=(*C["竹黄"][0], 230))
    # 面部阴影
    draw.ellipse([100, 95, 155, 160], fill=(*C["竹黄"][1], 200))

    # 眼睛
    for ex in [115, 141]:
        # 眼白
        draw.ellipse([ex - 6, 120, ex + 6, 130], fill=(240, 235, 225, 230))
        # 瞳孔
        draw.ellipse([ex - 3, 122, ex + 3, 129], fill=(*C["墨黑"][0], 230))
        # 高光
        draw.rectangle([ex - 1, 123, ex + 1, 125], fill=(255, 255, 255, 200))
    # 眉毛
    draw.line([(108, 116), (122, 114)], fill=(*C["墨黑"][1], 180), width=2)
    draw.line([(134, 114), (148, 116)], fill=(*C["墨黑"][1], 180), width=2)

    # 鼻子
    draw.line([(128, 128), (126, 140)], fill=(*C["竹黄"][2], 150), width=1)
    draw.line([(124, 140), (132, 140)], fill=(*C["竹黄"][2], 120), width=1)

    # 嘴
    draw.line([(120, 148), (136, 148)], fill=(*C["漆红"][1], 160), width=2)

    # 冠冕
    draw.rectangle([95, 72, 161, 95], fill=(*base_c[2], 230))
    draw.polygon([(128, 55), (95, 78), (161, 78)], fill=(*base_c[1], 220))
    # 冠饰
    draw.ellipse([123, 58, 133, 68], fill=(*C["金黄"][0], 220))
    # 冠缨
    draw.line([(105, 92), (95, 110)], fill=(*C["血红"][0], 180), width=2)
    draw.line([(151, 92), (161, 110)], fill=(*C["血红"][0], 180), width=2)

    # 底部名字条
    for y in range(240, 280):
        alpha = int(200 * (y - 240) / 40)
        draw.line([(0, y), (W, y)], fill=(*C["墨黑"][3], alpha))
    draw.line([(20, 242), (W - 20, 242)], fill=(*base_c[1], 150), width=1)
    ft = font(18)
    draw.text((W // 2, 260), name, fill=(*C["竹黄"][1], 230), font=ft, anchor="mm")

    return img

# ============================================================
#  旗帜 - 精细版 (128x128)
# ============================================================
def draw_flag_refined(size, kingdom, bg_c, fg_c, emblem):
    W, H = size
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 旗杆
    draw.rectangle([8, 5, 14, H - 5], fill=(*C["铜靛"][0], 220))
    draw.ellipse([6, 2, 16, 10], fill=(*C["金黄"][0], 200))

    # 旗面 (带飘动弧线)
    pts = [(14, 12)]
    for y in range(12, H - 12, 4):
        wave = int(3 * math.sin(y * 0.15))
        pts.append((W - 15 + wave, y))
    pts.append((14, H - 12))
    draw.polygon(pts, fill=(*bg_c, 230))

    # 旗面纹理 (暗纹)
    for y in range(20, H - 20, 8):
        wave = int(3 * math.sin(y * 0.15))
        draw.line([(20, y), (W - 20 + wave, y)], fill=(*lerp_color(bg_c, (0, 0, 0), 0.15), 60), width=1)

    # 边饰
    for y in range(12, H - 12, 4):
        wave = int(3 * math.sin(y * 0.15))
        draw.rectangle([14, y, 18, y + 3], fill=(*fg_c, 180))
        draw.rectangle([W - 18 + wave, y, W - 14 + wave, y + 3], fill=(*fg_c, 180))

    # 中央徽记
    ft = font(32)
    draw.text((W // 2 + 2, H // 2), emblem, fill=(*lerp_color(bg_c, (0, 0, 0), 0.3), 100), font=ft, anchor="mm")
    draw.text((W // 2, H // 2 - 2), emblem, fill=(*fg_c, 230), font=ft, anchor="mm")

    return img

# ============================================================
#  单位 - 精细版 (64x64)
# ============================================================
def draw_unit_refined(size, name, color_key, weapon="sword", has_mount=False):
    W, H = size
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    base_c = C[color_key]

    cx, cy = W // 2, H // 2

    # 地面阴影
    draw.ellipse([cx - 14, cy + 18, cx + 14, cy + 24], fill=(0, 0, 0, 50))

    if has_mount:
        # 马身
        draw.ellipse([cx - 18, cy - 2, cx + 14, cy + 14], fill=(*C["铜靛"][2], 220))
        # 马腿
        for dx in [-12, -6, 6, 10]:
            draw.rectangle([cx + dx - 1, cy + 10, cx + dx + 1, cy + 20], fill=(*C["铜靛"][3], 200))
        # 马头
        draw.ellipse([cx + 12, cy - 12, cx + 24, cy + 2], fill=(*C["铜靛"][1], 220))
        # 马耳
        draw.polygon([(cx + 16, cy - 14), (cx + 18, cy - 20), (cx + 20, cy - 14)], fill=(*C["铜靛"][2], 200))
        rider_y = cy - 10
    else:
        rider_y = cy + 2

    # 腿
    draw.rectangle([cx - 5, rider_y + 2, cx - 2, rider_y + 16], fill=(*base_c[2], 220))
    draw.rectangle([cx + 2, rider_y + 2, cx + 5, rider_y + 16], fill=(*base_c[2], 220))

    # 身体
    draw.rectangle([cx - 8, rider_y - 14, cx + 8, rider_y + 4], fill=(*base_c[0], 230))
    # 铠甲纹理
    draw.rectangle([cx - 6, rider_y - 12, cx - 2, rider_y + 2], fill=(*base_c[1], 150))
    # 腰带
    draw.rectangle([cx - 8, rider_y - 2, cx + 8, rider_y], fill=(*C["金黄"][2], 180))

    # 头
    head_y = rider_y - 20
    draw.ellipse([cx - 6, head_y, cx + 6, head_y + 12], fill=(*C["竹黄"][1], 225))
    # 盔
    draw.rectangle([cx - 7, head_y - 4, cx + 7, head_y + 3], fill=(*base_c[2], 220))
    draw.polygon([(cx, head_y - 8), (cx - 8, head_y - 2), (cx + 8, head_y - 2)],
                 fill=(*base_c[1], 200))
    # 盔缨
    draw.line([(cx, head_y - 8), (cx, head_y - 14)], fill=(*C["血红"][0], 200), width=2)
    draw.ellipse([cx - 2, head_y - 16, cx + 2, head_y - 12], fill=(*C["血红"][1], 200))

    # 武器
    if weapon == "sword":
        draw.rectangle([cx + 10, head_y - 5, cx + 12, rider_y + 8], fill=(*C["青灰"][1], 220))
        draw.rectangle([cx + 8, rider_y - 2, cx + 14, rider_y], fill=(*C["金黄"][0], 200))
    elif weapon == "bow":
        draw.arc([cx + 8, head_y, cx + 22, rider_y + 5], 200, 340, fill=(*C["苍绿"][2], 220), width=2)
        draw.line([(cx + 15, head_y + 2), (cx + 15, rider_y + 3)], fill=(*C["竹黄"][2], 180), width=1)
    elif weapon == "spear":
        draw.line([(cx + 10, head_y - 12), (cx + 10, rider_y + 14)], fill=(*C["青灰"][0], 220), width=2)
        draw.polygon([(cx + 10, head_y - 12), (cx + 7, head_y - 4), (cx + 13, head_y - 4)],
                     fill=(*C["青灰"][1], 230))
    elif weapon == "halberd":
        draw.line([(cx + 10, head_y - 10), (cx + 10, rider_y + 12)], fill=(*C["铜靛"][1], 220), width=2)
        draw.polygon([(cx + 10, head_y - 10), (cx + 4, head_y - 2), (cx + 16, head_y - 2)],
                     fill=(*C["青灰"][1], 230))
        draw.polygon([(cx + 10, head_y - 6), (cx + 18, head_y - 2), (cx + 10, head_y + 2)],
                     fill=(*C["青灰"][0], 200))
    elif weapon == "crossbow":
        draw.rectangle([cx + 8, rider_y - 8, cx + 20, rider_y - 5], fill=(*C["苍绿"][2], 220))
        draw.line([(cx + 14, rider_y - 12), (cx + 14, rider_y - 5)], fill=(*C["铜靛"][1], 200), width=2)
        draw.line([(cx + 8, rider_y - 12), (cx + 20, rider_y - 12)], fill=(*C["铜靛"][1], 200), width=2)

    # 单位名
    ft = font(8)
    draw.text((W // 2, H - 4), name, fill=(*C["竹黄"][1], 180), font=ft, anchor="mm")

    return img

# ============================================================
#  特效 - 精细版 (96x96, 多层)
# ============================================================
def draw_effect_refined(size, effect_type):
    W, H = size
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = W // 2, H // 2

    if effect_type == "attack":
        # 斩击弧线 + 火花
        for i in range(5):
            r = 20 + i * 4
            draw.arc([cx - r, cy - r, cx + r, cy + r], 210, 330,
                     fill=(*C["金黄"][1], 200 - i * 30), width=3)
        for _ in range(12):
            angle = random.uniform(210, 330)
            dist = random.uniform(15, 35)
            x = cx + dist * math.cos(math.radians(angle))
            y = cy + dist * math.sin(math.radians(angle))
            r = random.randint(1, 3)
            draw.ellipse([x - r, y - r, x + r, y + r], fill=(*C["金黄"][0], 200))

    elif effect_type == "ambush":
        # 暗影 + 箭矢
        for r in range(30, 0, -2):
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*C["墨黑"][0], max(5, 40 - r)))
        for _ in range(6):
            angle = random.uniform(0, 360)
            x1 = cx + 8 * math.cos(math.radians(angle))
            y1 = cy + 8 * math.sin(math.radians(angle))
            x2 = cx + 30 * math.cos(math.radians(angle))
            y2 = cy + 30 * math.sin(math.radians(angle))
            draw.line([(x1, y1), (x2, y2)], fill=(*C["铜靛"][1], 200), width=2)
            # 箭头
            draw.polygon([(x2, y2),
                          (x2 - 5 * math.cos(math.radians(angle - 20)),
                           y2 - 5 * math.sin(math.radians(angle - 20))),
                          (x2 - 5 * math.cos(math.radians(angle + 20)),
                           y2 - 5 * math.sin(math.radians(angle + 20)))],
                         fill=(*C["铜靛"][0], 200))

    elif effect_type == "fire":
        # 多层火焰
        for _ in range(20):
            x = cx + random.randint(-20, 20)
            y = cy + random.randint(-25, 10)
            r = random.randint(3, 10)
            c = random.choice([C["血红"][0], C["血红"][1], C["夕橙"][0], C["金黄"][0]])
            draw.ellipse([x - r, y - r * 1.5, x + r, y + r * 0.5], fill=(*c, 160))
        # 火星
        for _ in range(8):
            x = cx + random.randint(-25, 25)
            y = cy + random.randint(-35, -15)
            draw_star(draw, x, y, 2, (*C["金黄"][1], 180))

    elif effect_type == "flank":
        # 夹击 - 两道弧线交叉
        for sign in [-1, 1]:
            for i in range(3):
                r = 15 + i * 5
                start = 180 if sign > 0 else 0
                draw.arc([cx - r, cy - r, cx + r, cy + r], start, start + 120,
                         fill=(*C["漆红"][1], 180 - i * 40), width=3)
        # 中心爆点
        for r in range(8, 0, -1):
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*C["金黄"][0], 120 + r * 10))

    elif effect_type == "cutoff":
        # 断粮 - 断裂的线
        draw.line([(cx - 30, cy + 10), (cx - 5, cy - 5)], fill=(*C["铜靛"][1], 200), width=3)
        draw.line([(cx + 5, cy + 5), (cx + 30, cy - 10)], fill=(*C["铜靛"][1], 200), width=3)
        # 裂痕火花
        for _ in range(8):
            x = cx + random.randint(-5, 5)
            y = cy + random.randint(-5, 5)
            draw_star(draw, x, y, 3, (*C["金黄"][1], 180))

    elif effect_type == "defense":
        # 盾牌光环
        for r in range(30, 5, -3):
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(*C["铜靛"][1], max(20, 150 - r * 4)), width=2)
        # 盾
        draw.ellipse([cx - 12, cy - 15, cx + 12, cy + 10], fill=(*C["铜靛"][0], 220))
        draw.ellipse([cx - 8, cy - 11, cx + 8, cy + 6], fill=(*C["铜靛"][1], 200))
        draw.rectangle([cx - 2, cy - 10, cx + 2, cy + 5], fill=(*C["金黄"][2], 160))

    elif effect_type == "culture":
        # 文化辐射波纹
        for r in range(5, 40, 5):
            alpha = max(10, 150 - r * 3)
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(*C["竹黄"][1], alpha), width=2)
        # 中心学派符号
        ft = font(20)
        draw.text((cx, cy), "文", fill=(*C["竹黄"][0], 200), font=ft, anchor="mm")

    elif effect_type == "siege":
        # 攻城 - 碎石飞溅
        for _ in range(15):
            angle = random.uniform(0, 360)
            dist = random.uniform(10, 35)
            x = cx + dist * math.cos(math.radians(angle))
            y = cy + dist * math.sin(math.radians(angle))
            r = random.randint(2, 5)
            draw.rectangle([x - r, y - r, x + r, y + r], fill=(*C["青灰"][2], 180))
        # 冲击波
        for r in range(10, 35, 4):
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(*C["夕橙"][0], max(20, 120 - r * 3)), width=2)

    return img

# ============================================================
#  风格 Demo - 精细版
# ============================================================
def generate_pixel_demo_refined():
    W, H = 960, 640
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    random.seed(42)

    # 水墨天空
    for y in range(H):
        t = y / H
        r = int(22 + 45 * t)
        g = int(24 + 40 * t)
        b = int(28 + 35 * t)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    # 远山
    ground_y = 300
    for peak_x, peak_h, peak_w in [(120, 120, 160), (350, 90, 200), (600, 140, 180), (850, 100, 150)]:
        pts = [(peak_x - peak_w, ground_y)]
        for i in range(30):
            t = i / 29
            x = peak_x - peak_w + 2 * peak_w * t
            y = ground_y - peak_h * math.sin(math.pi * t)
            pts.append((x, y))
        pts.append((peak_x + peak_w, ground_y))
        draw.polygon(pts, fill=(45 + peak_x // 20, 50 + peak_x // 20, 55 + peak_x // 20, 100))

    # 地面渐变
    for y in range(ground_y, H):
        t = (y - ground_y) / (H - ground_y)
        draw.line([(0, y), (W, y)], fill=lerp_color((90, 105, 75), (55, 65, 48), t))

    # 六角网格
    hex_size = 28
    tile_map = [
        ["mountain", "mountain", "forest",  "forest",  "plain",   "plain",   "river",   "river",   "plain"],
        ["mountain", "forest",   "forest",  "plain",   "plain",   "plain",   "river",   "plain",   "plain"],
        ["forest",   "forest",   "plain",   "plain",   "plain",   "plain",   "plain",   "river",   "mountain"],
        ["forest",   "plain",    "plain",   "plain",   "plain",   "plain",   "plain",   "plain",   "mountain"],
        ["plain",    "plain",    "plain",   "plain",   "plain",   "plain",   "plain",   "mountain", "mountain"],
    ]

    terrain_colors = {
        "mountain": ((120, 105, 90), (148, 132, 115), (88, 76, 64)),
        "forest":   ((55, 90, 55), (78, 115, 78), (38, 62, 38)),
        "plain":    ((140, 155, 110), (165, 178, 135), (105, 118, 82)),
        "river":    ((55, 85, 130), (80, 115, 160), (35, 60, 95)),
    }

    for row_i, row in enumerate(tile_map):
        for col_i, tile_type in enumerate(row):
            offset = hex_size if row_i % 2 else 0
            cx = 80 + col_i * hex_size * 2 + offset
            cy = ground_y - 15 + row_i * int(hex_size * 1.75)

            colors = terrain_colors[tile_type]
            pts = hex_pts(cx, cy, hex_size)
            draw.polygon(pts, fill=colors[0])

            min_x = int(min(p[0] for p in pts))
            max_x = int(max(p[0] for p in pts))
            max_y = int(max(p[1] for p in pts))
            draw.rectangle([min_x, max_y, max_x, max_y + 6], fill=colors[2])

            edge = tuple((a + b) // 2 for a, b in zip(colors[0], colors[2]))
            for i in range(len(pts)):
                draw.line([pts[i], pts[(i + 1) % len(pts)]], fill=edge, width=1)

            if tile_type == "forest":
                for _ in range(4):
                    tx = cx + random.randint(-10, 10)
                    ty = cy + random.randint(-10, 5)
                    draw.rectangle([tx - 1, ty - 5, tx + 1, ty], fill=colors[1])
                    draw.ellipse([tx - 3, ty - 8, tx + 3, ty - 4], fill=colors[1])
            elif tile_type == "river":
                for _ in range(3):
                    rx = cx + random.randint(-12, 12)
                    ry = cy + random.randint(-5, 5)
                    draw.line([(rx - 5, ry), (rx + 5, ry)], fill=colors[1], width=1)
            elif tile_type == "mountain":
                draw.polygon([(cx, cy - 14), (cx - 8, cy + 4), (cx + 8, cy + 4)], fill=colors[1])
                draw.line([(cx, cy - 14), (cx - 2, cy - 6)], fill=(255, 255, 255, 40), width=1)

    # 城市
    city_x, city_y = 420, ground_y + 80
    draw.rectangle([city_x - 22, city_y - 16, city_x + 22, city_y + 16], fill=(43, 51, 48))
    draw.rectangle([city_x - 16, city_y - 28, city_x + 16, city_y - 14], fill=(69, 82, 77))
    draw.polygon([(city_x, city_y - 38), (city_x - 18, city_y - 26), (city_x + 18, city_y - 26)], fill=(26, 33, 30))
    draw.rectangle([city_x - 5, city_y - 4, city_x + 5, city_y + 16], fill=(0, 0, 0, 200))
    draw.rectangle([city_x, city_y - 52, city_x + 2, city_y - 36], fill=(102, 48, 24))
    draw.rectangle([city_x + 2, city_y - 52, city_x + 14, city_y - 44], fill=(176, 93, 59))

    # 单位群
    for ux, uy, uc in [(350, ground_y + 120, C["漆红"]), (370, ground_y + 130, C["漆红"]),
                        (390, ground_y + 125, C["漆红"]), (460, ground_y + 110, C["铜靛"]),
                        (480, ground_y + 118, C["铜靛"])]:
        draw.ellipse([ux - 5, uy + 2, ux + 5, uy + 6], fill=(*uc[2], 180))
        draw.rectangle([ux - 3, uy - 8, ux + 3, uy + 2], fill=(*uc[0], 230))
        draw.ellipse([ux - 3, uy - 14, ux + 3, uy - 6], fill=(*C["竹黄"][1], 225))
        draw.rectangle([ux - 4, uy - 16, ux + 4, uy - 13], fill=(*uc[2], 200))
        draw.line([(ux + 5, uy - 10), (ux + 5, uy + 5)], fill=(135, 145, 155, 200), width=1)

    # UI
    draw.rectangle([0, 0, W, 38], fill=(13, 18, 16, 230))
    draw.rectangle([0, 0, W, 2], fill=(197, 163, 104, 200))
    draw.rectangle([0, 36, W, 38], fill=(197, 163, 104, 200))
    ft = font(13)
    for text, x in [("粮: 1200", 30), ("钱: 800", 170), ("铁: 350", 310), ("回合: 5", 450)]:
        draw.text((x, 12), text, fill=(197, 163, 104), font=ft)

    panel_x = W - 185
    draw.rectangle([panel_x, H - 205, W - 10, H - 10], fill=(13, 18, 16, 220))
    draw.rectangle([panel_x, H - 205, W - 10, H - 203], fill=(197, 163, 104, 180))
    draw.rectangle([panel_x, H - 10, W - 10, H - 8], fill=(197, 163, 104, 180))
    draw.rectangle([panel_x, H - 205, panel_x + 2, H - 10], fill=(197, 163, 104, 180))
    draw.rectangle([W - 12, H - 205, W - 10, H - 10], fill=(197, 163, 104, 180))
    ft_name = font(15)
    draw.text((panel_x + 15, H - 190), "秦锐士", fill=(176, 93, 59), font=ft_name)
    for text, dy in [("攻击: 12", -160), ("防御: 8", -138), ("移动力: 3", -116), ("士气: 高", -94)]:
        draw.text((panel_x + 15, H + dy), text, fill=(197, 163, 104, 220), font=ft)

    btn_x, btn_y = W - 125, 50
    draw.rectangle([btn_x, btn_y, btn_x + 105, btn_y + 34], fill=(43, 51, 48, 230))
    draw.rectangle([btn_x, btn_y, btn_x + 105, btn_y + 2], fill=(197, 163, 104, 180))
    draw.rectangle([btn_x, btn_y + 32, btn_x + 105, btn_y + 34], fill=(197, 163, 104, 180))
    draw.text((btn_x + 52, btn_y + 17), "下回合", fill=(197, 163, 104), font=ft, anchor="mm")

    draw.text((W // 2, H - 28), "风格A: 像素风 | 硬边六角 | 16色限制 | 64x64 基底",
              fill=(197, 163, 104, 120), font=ft, anchor="mm")
    draw.rectangle([0, 0, W - 1, H - 1], outline=(197, 163, 104, 80), width=2)

    return img


def generate_handdrawn_demo_refined():
    W, H = 960, 640
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    random.seed(42)

    # 水墨天空
    for y in range(H):
        t = y / H
        r = int(80 + 80 * t)
        g = int(90 + 85 * t)
        b = int(110 + 85 * t)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    # 远山 (水墨晕染)
    ground_y = 320
    for peak_x, peak_h, peak_w in [(150, 130, 180), (400, 100, 220), (700, 150, 200), (900, 110, 170)]:
        for layer in range(5):
            pts = [(peak_x - peak_w, ground_y)]
            for i in range(25):
                t = i / 24
                x = peak_x - peak_w + 2 * peak_w * t
                y = ground_y - (peak_h + layer * 8) * math.sin(math.pi * t) + random.randint(-2, 2)
                pts.append((x, y))
            pts.append((peak_x + peak_w, ground_y))
            alpha = 60 - layer * 10
            c = (55 + layer * 10, 60 + layer * 10, 68 + layer * 10, max(15, alpha))
            draw.polygon(pts, fill=c)

    # 地面
    for y in range(ground_y, H):
        t = (y - ground_y) / (H - ground_y)
        draw.line([(0, y), (W, y)], fill=lerp_color((140, 160, 120), (95, 108, 80), t))

    # 飞鸟
    for bx, by in [(200, 100), (225, 92), (650, 85), (675, 80), (700, 88)]:
        draw.arc([bx - 6, by - 2, bx, by + 2], 200, 340, fill=(35, 35, 38, 120), width=1)
        draw.arc([bx, by - 2, bx + 6, by + 2], 200, 340, fill=(35, 35, 38, 120), width=1)

    # 六角网格 (圆润)
    hex_size = 30
    tile_map = [
        ["mountain", "mountain", "forest",  "forest",  "plain",   "plain",   "river",   "river",   "plain"],
        ["mountain", "forest",   "forest",  "plain",   "plain",   "plain",   "river",   "plain",   "plain"],
        ["forest",   "forest",   "plain",   "plain",   "plain",   "plain",   "plain",   "river",   "mountain"],
        ["forest",   "plain",    "plain",   "plain",   "plain",   "plain",   "plain",   "plain",   "mountain"],
        ["plain",    "plain",    "plain",   "plain",   "plain",   "plain",   "plain",   "mountain", "mountain"],
    ]

    terrain_colors = {
        "mountain": ((135, 120, 108), (162, 148, 135), (100, 88, 78)),
        "forest":   ((70, 110, 70), (95, 138, 95), (48, 78, 48)),
        "plain":    ((155, 175, 130), (180, 198, 155), (125, 142, 100)),
        "river":    ((70, 105, 150), (100, 135, 178), (45, 75, 110)),
    }

    for row_i, row in enumerate(tile_map):
        for col_i, tile_type in enumerate(row):
            offset = hex_size if row_i % 2 else 0
            cx = 80 + col_i * hex_size * 2 + offset
            cy = ground_y - 20 + row_i * int(hex_size * 1.75)

            colors = terrain_colors[tile_type]
            pts = hex_pts(cx, cy, hex_size)

            # 阴影
            shadow_pts = [(x + 2, y + 2) for x, y in pts]
            draw.polygon(shadow_pts, fill=(*colors[2], 80))

            draw.polygon(pts, fill=colors[0])

            # 柔和底部
            max_y_val = int(max(p[1] for p in pts))
            min_x = int(min(p[0] for p in pts))
            max_x = int(max(p[0] for p in pts))
            for dy in range(8):
                alpha = max(30, 180 - dy * 20)
                draw.line([(min_x + dy, max_y_val + dy), (max_x - dy, max_y_val + dy)],
                          fill=(*colors[2], alpha))

            # 柔和边缘
            for i in range(len(pts)):
                draw.line([pts[i], pts[(i + 1) % len(pts)]], fill=(*colors[2], 100), width=2)

            if tile_type == "forest":
                for _ in range(4):
                    tx = cx + random.randint(-12, 12)
                    ty = cy + random.randint(-12, 5)
                    draw.ellipse([tx - 5, ty - 9, tx + 5, ty], fill=(*colors[1], 160))
                    draw.line([(tx, ty), (tx, ty + 5)], fill=(35, 35, 38, 140), width=1)
            elif tile_type == "river":
                for wy in range(cy - 8, cy + 8, 4):
                    points = [(wx, wy + math.sin(wx * 0.3) * 2) for wx in range(cx - 14, cx + 15, 2)]
                    if len(points) > 1:
                        draw.line(points, fill=(*colors[1], 140), width=1)
            elif tile_type == "mountain":
                draw.polygon([(cx, cy - 15), (cx - 10, cy + 4), (cx + 10, cy + 4)],
                             fill=(*colors[1], 160))
                draw.line([(cx, cy - 15), (cx - 3, cy - 4)], fill=(*colors[2], 100), width=1)

    # 城市 (圆润)
    city_x, city_y = 430, ground_y + 55
    draw.rounded_rectangle([city_x - 26, city_y - 18, city_x + 26, city_y + 18],
                           radius=4, fill=(160, 82, 42, 220))
    draw.rounded_rectangle([city_x - 18, city_y - 30, city_x + 18, city_y - 16],
                           radius=3, fill=(195, 110, 68, 200))
    draw.ellipse([city_x - 5, city_y - 5, city_x + 5, city_y + 18], fill=(115, 58, 28, 200))
    draw.line([(city_x, city_y - 48), (city_x, city_y - 32)], fill=(35, 35, 38, 200), width=2)
    draw.polygon([(city_x, city_y - 48), (city_x + 16, city_y - 44),
                  (city_x + 14, city_y - 38), (city_x, city_y - 42)],
                 fill=(195, 110, 68, 180))

    # 单位
    for ux, uy, label in [(360, ground_y + 95, "步"), (385, ground_y + 105, "弓"),
                           (410, ground_y + 100, "骑"), (475, ground_y + 85, "车")]:
        draw.ellipse([ux - 6, uy + 4, ux + 6, uy + 8], fill=(0, 0, 0, 35))
        draw.ellipse([ux - 5, uy - 9, ux + 5, uy + 4], fill=(160, 82, 42, 210))
        draw.ellipse([ux - 4, uy - 17, ux + 4, uy - 8], fill=(217, 190, 139, 210))
        ft = font(8)
        draw.text((ux, uy + 10), label, fill=(35, 35, 38, 160), font=ft, anchor="mm")

    # UI (卷轴风)
    draw.rounded_rectangle([12, 8, W - 12, 42], radius=6, fill=(35, 35, 38, 200))
    draw.rounded_rectangle([12, 8, W - 12, 42], radius=6, outline=(197, 163, 104, 140), width=1)
    ft = font(13)
    for text, x in [("粮: 1200", 45), ("钱: 800", 190), ("铁: 350", 335), ("回合: 5", 480)]:
        draw.text((x, 25), text, fill=(217, 190, 139, 200), font=ft, anchor="lm")

    panel_x = W - 195
    draw.rounded_rectangle([panel_x, H - 215, W - 15, H - 15], radius=8, fill=(35, 35, 38, 200))
    draw.rounded_rectangle([panel_x, H - 215, W - 15, H - 15], radius=8, outline=(197, 163, 104, 120), width=1)
    draw.ellipse([panel_x - 3, H - 220, panel_x + 8, H - 205], fill=(197, 163, 104, 100))
    draw.ellipse([W - 20, H - 220, W - 9, H - 205], fill=(197, 163, 104, 100))
    draw.text((panel_x + 20, H - 195), "秦锐士", fill=(195, 110, 68), font=font(15))
    for text, dy in [("攻击: 12", -168), ("防御: 8", -148), ("移动力: 3", -128), ("士气: 高", -108)]:
        draw.text((panel_x + 20, H + dy), text, fill=(217, 190, 139, 200), font=ft)

    btn_x, btn_y = W - 135, 55
    draw.rounded_rectangle([btn_x, btn_y, btn_x + 115, btn_y + 38], radius=8, fill=(35, 35, 38, 220))
    draw.rounded_rectangle([btn_x, btn_y, btn_x + 115, btn_y + 38], radius=8, outline=(197, 163, 104, 140), width=1)
    draw.text((btn_x + 57, btn_y + 19), "下回合", fill=(217, 190, 139), font=ft, anchor="mm")

    # 印章
    stamp_x, stamp_y = W - 75, H - 68
    draw.ellipse([stamp_x - 22, stamp_y - 22, stamp_x + 22, stamp_y + 22], fill=(160, 82, 42, 150))
    draw.ellipse([stamp_x - 18, stamp_y - 18, stamp_x + 18, stamp_y + 18], outline=(115, 58, 28, 160), width=1)
    draw.text((stamp_x, stamp_y), "策", fill=(255, 240, 220, 200), font=font(20), anchor="mm")

    draw.text((W // 2, H - 25), "风格B: 手绘风 | 柔和边缘 | 水墨晕染 | 卷轴UI",
              fill=(197, 163, 104, 120), font=font(13), anchor="mm")
    draw.rounded_rectangle([3, 3, W - 4, H - 4], radius=10, outline=(197, 163, 104, 60), width=1)

    return img


# ============================================================
#  主流程
# ============================================================
if __name__ == "__main__":
    random.seed(42)
    total = 0

    print("=== 事件插画 (512x384, 多层场景) ===")
    for name, params in EVENTS.items():
        img = make_event_scene(**params, title=name)
        save(img, "event", f"event_{name}.png")
        total += 1

    print("\n=== 君主头像 (256x256) ===")
    monarchs = {
        "qin":  ("秦王·嬴政", "漆红"),  "zhao": ("赵王·迁", "铜靛"),
        "qi":   ("齐王·建", "竹黄"),    "chu":  ("楚王·负刍", "血红"),
        "wei":  ("魏王·假", "青灰"),    "yan":  ("燕王·喜", "苍绿"),
        "han":  ("韩王·安", "夕橙"),
    }
    for key, (name, ck) in monarchs.items():
        img = draw_portrait_refined((256, 256), name, ck)
        save(img, "portrait", f"portrait_monarch_{key}.png")
        total += 1

    print("\n=== 名将立绘 (256x256) ===")
    generals = [
        ("商鞅", "铜靛"), ("乐毅", "苍绿"), ("白起", "血红"),
        ("李牧", "铜靛"), ("王翦", "漆红"), ("廉颇", "铜靛"),
        ("孙膑", "竹黄"), ("吴起", "墨黑"), ("庞涓", "青灰"),
        ("赵奢", "夕橙"), ("蒙恬", "漆红"), ("项燕", "烟紫"),
        ("田单", "竹黄"), ("信陵君", "铜靛"), ("春申君", "金黄"),
    ]
    for name, ck in generals:
        img = draw_portrait_refined((256, 256), name, ck)
        save(img, "portrait", f"portrait_general_{name}.png")
        total += 1

    print("\n=== 七国旗帜 (128x128) ===")
    flags = {
        "qin":  ("秦", C["漆红"][0], C["金黄"][1], "秦"),
        "zhao": ("赵", C["铜靛"][0], C["竹黄"][1], "赵"),
        "qi":   ("齐", C["苍绿"][0], C["金黄"][1], "齐"),
        "chu":  ("楚", C["血红"][0], C["金黄"][1], "楚"),
        "wei":  ("魏", C["墨黑"][1], C["竹黄"][1], "魏"),
        "yan":  ("燕", C["铜靛"][2], C["竹黄"][1], "燕"),
        "han":  ("韩", C["夕橙"][0], C["金黄"][1], "韩"),
    }
    for key, (name, bg, fg, emblem) in flags.items():
        img = draw_flag_refined((128, 128), name, bg, fg, emblem)
        save(img, "flag", f"flag_{key}.png")
        total += 1

    print("\n=== 单位图标 (64x64) ===")
    units = [
        ("步兵", "漆红", "sword", False), ("弓兵", "苍绿", "bow", False),
        ("骑兵", "铜靛", "spear", True),  ("战车", "金黄", "halberd", True),
        ("攻城", "青灰", "crossbow", False),
    ]
    for name, ck, wp, mount in units:
        img = draw_unit_refined((64, 64), name, ck, wp, mount)
        save(img, "unit", f"unit_{name}.png")
        total += 1

    print("\n=== 七国特色兵种 (64x64) ===")
    special_units = [
        ("锐士", "漆红", "sword", False),     ("胡服骑", "铜靛", "spear", True),
        ("技击手", "苍绿", "bow", False),      ("申息师", "血红", "halberd", False),
        ("武卒", "墨黑", "sword", False),      ("辽东骑", "铜靛", "bow", True),
        ("劲弩", "青灰", "crossbow", False),
    ]
    for name, ck, wp, mount in special_units:
        img = draw_unit_refined((64, 64), name, ck, wp, mount)
        save(img, "unit", f"unit_{name}.png")
        total += 1

    print("\n=== 战斗特效 (96x96) ===")
    effects = ["attack", "ambush", "fire", "flank", "cutoff", "defense", "culture", "siege"]
    for eff in effects:
        img = draw_effect_refined((96, 96), eff)
        save(img, "effect", f"effect_{eff}.png")
        total += 1

    print("\n=== 风格 Demo ===")
    img_a = generate_pixel_demo_refined()
    save(img_a, "demo_style_A_pixel.png")
    total += 1

    img_b = generate_handdrawn_demo_refined()
    save(img_b, "demo_style_B_handdrawn.png")
    total += 1

    print(f"\n完成! 共生成 {total} 个精细资产。")
