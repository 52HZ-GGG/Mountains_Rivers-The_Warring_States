"""
《山河策》风格 Demo 生成器
生成两张对比风格图: 像素风 vs 手绘风
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))

def save(img, name):
    p = os.path.join(ROOT, name)
    img.save(p)
    print(f"[OK] {name}")

def get_font(size):
    for name in ["msyh.ttc", "simhei.ttf", "simsun.ttc"]:
        try:
            return ImageFont.truetype(name, size)
        except:
            continue
    return ImageFont.load_default()

def hex_points(cx, cy, r):
    return [(cx + r * math.sin(math.radians(60 * i)),
             cy - r * math.cos(math.radians(60 * i))) for i in range(6)]

# ============================================================
#  DEMO A: 像素风 (Pixel Art)
# ============================================================
def generate_pixel_demo():
    W, H = 960, 640
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 战国色谱
    palette = {
        "plain":   ((140, 155, 110), (165, 178, 135), (105, 118, 82)),
        "forest":  ((55, 90, 55),    (78, 115, 78),   (38, 62, 38)),
        "mountain":((120, 105, 90),  (148, 132, 115), (88, 76, 64)),
        "river":   ((55, 85, 130),   (80, 115, 160),  (35, 60, 95)),
        "wall":    ((43, 51, 48),    (69, 82, 77),    (26, 33, 30)),
        "accent":  ((140, 69, 34),   (176, 93, 59),   (102, 48, 24)),
    }

    # 背景渐变 - 水墨天空
    for y in range(H):
        ratio = y / H
        r = int(26 + 40 * ratio)
        g = int(26 + 35 * ratio)
        b = int(27 + 30 * ratio)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    # 地面区域
    ground_y = 280

    # 画六角形网格 (像素风 - 硬边)
    hex_size = 28
    tile_map = [
        ["mountain", "mountain", "forest",  "forest",  "plain",   "plain",   "plain",   "river",   "river"],
        ["mountain", "forest",   "forest",  "plain",   "plain",   "plain",   "river",   "river",   "plain"],
        ["forest",   "forest",   "plain",   "plain",   "plain",   "plain",   "plain",   "river",   "plain"],
        ["forest",   "plain",    "plain",   "plain",   "plain",   "plain",   "plain",   "plain",   "mountain"],
        ["plain",    "plain",    "plain",   "plain",   "plain",   "plain",   "plain",   "mountain", "mountain"],
    ]

    for row_i, row in enumerate(tile_map):
        for col_i, tile_type in enumerate(row):
            offset = hex_size if row_i % 2 else 0
            cx = 80 + col_i * hex_size * 2 + offset
            cy = ground_y + row_i * int(hex_size * 1.75)

            colors = palette[tile_type]
            pts = hex_points(cx, cy, hex_size)

            # 顶面
            draw.polygon(pts, fill=colors[0])
            # 底部厚度 6px
            min_x = int(min(p[0] for p in pts))
            max_x = int(max(p[0] for p in pts))
            max_y = int(max(p[1] for p in pts))
            draw.rectangle([min_x, max_y, max_x, max_y + 6], fill=colors[2])
            # 边缘线 (像素风 - 硬边, 1px)
            edge = tuple((a + b) // 2 for a, b in zip(colors[0], colors[2]))
            for i in range(len(pts)):
                draw.line([pts[i], pts[(i + 1) % len(pts)]], fill=edge, width=1)

            # 地形细节 - 像素点缀
            if tile_type == "forest":
                for _ in range(3):
                    tx = cx + random.randint(-10, 10)
                    ty = cy + random.randint(-10, 5)
                    draw.rectangle([tx-1, ty-3, tx+1, ty], fill=colors[1])
            elif tile_type == "river":
                for _ in range(2):
                    rx = cx + random.randint(-12, 12)
                    ry = cy + random.randint(-5, 5)
                    draw.line([(rx-4, ry), (rx+4, ry)], fill=colors[1], width=1)
            elif tile_type == "mountain":
                draw.polygon([(cx, cy-12), (cx-8, cy+4), (cx+8, cy+4)], fill=colors[1])

    # 城市 (像素方块)
    city_x, city_y = 400, ground_y + 90
    draw.rectangle([city_x-20, city_y-15, city_x+20, city_y+15], fill=palette["wall"][0])
    draw.rectangle([city_x-15, city_y-25, city_x+15, city_y-13], fill=palette["wall"][1])
    draw.polygon([(city_x, city_y-35), (city_x-15, city_y-25), (city_x+15, city_y-25)], fill=palette["wall"][2])
    draw.rectangle([city_x-4, city_y-5, city_x+4, city_y+15], fill=palette["accent"][2])
    # 城旗
    draw.rectangle([city_x, city_y-50, city_x+2, city_y-35], fill=palette["accent"][0])
    draw.rectangle([city_x+2, city_y-50, city_x+14, city_y-42], fill=palette["accent"][1])

    # 单位 (像素小人)
    for ux, uy, uc in [(350, ground_y+130, palette["accent"]),
                        (370, ground_y+140, palette["accent"]),
                        (450, ground_y+120, palette["wall"])]:
        # 底座
        draw.ellipse([ux-5, uy+2, ux+5, uy+6], fill=uc[2])
        # 身体
        draw.rectangle([ux-3, uy-6, ux+3, uy+2], fill=uc[0])
        # 头
        draw.ellipse([ux-3, uy-12, ux+3, uy-6], fill=uc[1])

    # UI 元素 - 资源条 (像素风硬边)
    # 顶部资源条
    draw.rectangle([0, 0, W, 36], fill=(13, 18, 16, 230))
    draw.rectangle([0, 0, W, 2], fill=(197, 163, 104))
    draw.rectangle([0, 34, W, 36], fill=(197, 163, 104))
    font = get_font(14)
    resources = [("粮: 1200", 30), ("钱: 800", 160), ("铁: 350", 290), ("回合: 5", 420)]
    for text, x in resources:
        draw.text((x, 10), text, fill=(197, 163, 104), font=font)

    # 右侧单位面板
    panel_x = W - 180
    draw.rectangle([panel_x, H-200, W-10, H-10], fill=(13, 18, 16, 220))
    draw.rectangle([panel_x, H-200, W-10, H-198], fill=(197, 163, 104))
    draw.rectangle([panel_x, H-10, W-10, H-8], fill=(197, 163, 104))
    draw.rectangle([panel_x, H-200, panel_x+2, H-10], fill=(197, 163, 104))
    draw.rectangle([W-12, H-200, W-10, H-10], fill=(197, 163, 104))
    draw.text((panel_x+15, H-185), "秦锐士", fill=(176, 93, 59), font=get_font(16))
    draw.text((panel_x+15, H-160), "攻击: 12", fill=(197, 163, 104), font=font)
    draw.text((panel_x+15, H-140), "防御: 8", fill=(197, 163, 104), font=font)
    draw.text((panel_x+15, H-120), "移动力: 3", fill=(197, 163, 104), font=font)

    # 回合按钮
    btn_x, btn_y = W - 120, 50
    draw.rectangle([btn_x, btn_y, btn_x+100, btn_y+32], fill=(43, 51, 48, 230))
    draw.rectangle([btn_x, btn_y, btn_x+100, btn_y+2], fill=(197, 163, 104))
    draw.rectangle([btn_x, btn_y+30, btn_x+100, btn_y+32], fill=(197, 163, 104))
    draw.text((btn_x+50, btn_y+16), "下回合", fill=(197, 163, 104), font=font, anchor="mm")

    # 标题水印
    font_title = get_font(28)
    draw.text((W//2, H-30), "风格A: 像素风 | 64x64 基底 | 硬边 | 16色限制",
              fill=(197, 163, 104, 150), font=font, anchor="mm")

    # 外框
    draw.rectangle([0, 0, W-1, H-1], outline=(197, 163, 104, 100), width=2)

    return img.convert("RGBA")


# ============================================================
#  DEMO B: 手绘风 (Flat 2D Hand-drawn)
# ============================================================
def generate_handdrawn_demo():
    W, H = 960, 640
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 柔和色板 (手绘风 - 饱和度略高, 边缘柔和)
    palette = {
        "sky_top":   (85, 95, 120),
        "sky_bot":   (160, 175, 195),
        "plain":     ((155, 175, 130), (180, 198, 155), (125, 142, 100)),
        "forest":    ((70, 110, 70),   (95, 138, 95),   (48, 78, 48)),
        "mountain":  ((135, 120, 108), (162, 148, 135), (100, 88, 78)),
        "river":     ((70, 105, 150),  (100, 135, 178), (45, 75, 110)),
        "accent":    ((160, 82, 42),   (195, 110, 68),  (115, 58, 28)),
        "ink":       (35, 35, 38),
    }

    # 水墨渐变天空
    for y in range(H):
        ratio = y / H
        r = int(palette["sky_top"][0] + (palette["sky_bot"][0] - palette["sky_top"][0]) * ratio)
        g = int(palette["sky_top"][1] + (palette["sky_bot"][1] - palette["sky_top"][1]) * ratio)
        b = int(palette["sky_top"][2] + (palette["sky_bot"][2] - palette["sky_top"][2]) * ratio)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    # 远山剪影 (水墨晕染感)
    for peak_x, peak_h, width in [(150, 180, 200), (400, 140, 250), (700, 200, 220), (900, 160, 180)]:
        for dy in range(60):
            alpha = max(10, 80 - dy)
            spread = int(width * (1 + dy * 0.02))
            c = (55 + dy, 60 + dy, 65 + dy, alpha)
            y_base = peak_h + dy
            draw.ellipse([peak_x - spread, y_base - 8, peak_x + spread, y_base + 8], fill=c)

    # 地面
    ground_y = 320
    for y in range(ground_y, H):
        ratio = (y - ground_y) / (H - ground_y)
        r = int(140 + 30 * ratio)
        g = int(155 + 25 * ratio)
        b = int(110 + 20 * ratio)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    # 六角形网格 (手绘风 - 圆润边缘, 柔和渐变)
    hex_size = 30
    tile_map = [
        ["mountain", "mountain", "forest",  "forest",  "plain",   "plain",   "river",   "river",   "plain"],
        ["mountain", "forest",   "forest",  "plain",   "plain",   "plain",   "river",   "plain",   "plain"],
        ["forest",   "forest",   "plain",   "plain",   "plain",   "plain",   "plain",   "river",   "mountain"],
        ["forest",   "plain",    "plain",   "plain",   "plain",   "plain",   "plain",   "plain",   "mountain"],
        ["plain",    "plain",    "plain",   "plain",   "plain",   "plain",   "plain",   "mountain", "mountain"],
    ]

    for row_i, row in enumerate(tile_map):
        for col_i, tile_type in enumerate(row):
            offset = hex_size if row_i % 2 else 0
            cx = 80 + col_i * hex_size * 2 + offset
            cy = ground_y - 20 + row_i * int(hex_size * 1.75)

            colors = palette[tile_type]
            pts = hex_points(cx, cy, hex_size)

            # 阴影层 (手绘风 - 轻微偏移产生深度)
            shadow_pts = [(x + 2, y + 2) for x, y in pts]
            draw.polygon(shadow_pts, fill=(*colors[2], 100))

            # 顶面 (手绘风 - 柔和填充)
            draw.polygon(pts, fill=colors[0])

            # 底部厚度 (手绘风 - 渐变而非硬切)
            min_x = int(min(p[0] for p in pts))
            max_x = int(max(p[0] for p in pts))
            max_y_val = int(max(p[1] for p in pts))
            for dy in range(8):
                alpha = 200 - dy * 20
                c = (*colors[2], max(50, alpha))
                draw.line([(min_x + dy, max_y_val + dy), (max_x - dy, max_y_val + dy)], fill=c)

            # 柔和边缘 (手绘风 - 2px 宽, 带透明度)
            edge = (*colors[2], 120)
            for i in range(len(pts)):
                draw.line([pts[i], pts[(i + 1) % len(pts)]], fill=edge, width=2)

            # 地形细节 - 手绘笔触
            if tile_type == "forest":
                for _ in range(4):
                    tx = cx + random.randint(-12, 12)
                    ty = cy + random.randint(-12, 5)
                    # 树冠 (椭圆, 柔和)
                    draw.ellipse([tx-5, ty-8, tx+5, ty], fill=(*colors[1], 180))
                    # 树干
                    draw.line([(tx, ty), (tx, ty+5)], fill=(*palette["ink"], 150), width=1)
            elif tile_type == "river":
                # 水纹 (波浪线)
                for wy in range(cy-8, cy+8, 4):
                    points = []
                    for wx in range(cx-14, cx+15, 2):
                        points.append((wx, wy + math.sin(wx * 0.3) * 2))
                    if len(points) > 1:
                        draw.line(points, fill=(*colors[1], 160), width=1)
            elif tile_type == "mountain":
                # 山峰轮廓 (柔和三角)
                draw.polygon([(cx, cy-14), (cx-10, cy+4), (cx+10, cy+4)],
                             fill=(*colors[1], 180))
                # 山脊线
                draw.line([(cx, cy-14), (cx-3, cy-4)], fill=(*colors[2], 120), width=1)

    # 城市 (手绘风 - 圆润线条)
    city_x, city_y = 420, ground_y + 60
    # 城墙 (带圆角感)
    draw.rounded_rectangle([city_x-25, city_y-18, city_x+25, city_y+18],
                           radius=4, fill=palette["accent"][0])
    draw.rounded_rectangle([city_x-18, city_y-30, city_x+18, city_y-16],
                           radius=3, fill=palette["accent"][1])
    # 城门
    draw.ellipse([city_x-5, city_y-5, city_x+5, city_y+18], fill=palette["accent"][2])
    # 城旗 (飘动感)
    draw.line([(city_x, city_y-48), (city_x, city_y-32)], fill=palette["ink"], width=2)
    flag_pts = [(city_x, city_y-48), (city_x+16, city_y-44), (city_x+14, city_y-38), (city_x, city_y-42)]
    draw.polygon(flag_pts, fill=(*palette["accent"][1], 200))

    # 单位 (手绘风 - 简笔画小人)
    for ux, uy, label in [(360, ground_y+100, "步"), (385, ground_y+110, "弓"), (470, ground_y+90, "骑")]:
        # 阴影
        draw.ellipse([ux-6, uy+4, ux+6, uy+8], fill=(0, 0, 0, 40))
        # 身体 (圆润)
        draw.ellipse([ux-5, uy-8, ux+5, uy+4], fill=(*palette["accent"][0], 220))
        # 头
        draw.ellipse([ux-4, uy-16, ux+4, uy-8], fill=(*palette["accent"][1], 220))
        # 小标签
        font = get_font(9)
        draw.text((ux, uy+10), label, fill=(*palette["ink"], 180), font=font, anchor="mm")

    # 远处飞鸟 (水墨点缀)
    for bx, by in [(200, 120), (230, 110), (650, 100), (680, 95)]:
        draw.arc([bx-6, by-2, bx, by+2], 200, 340, fill=(*palette["ink"], 100), width=1)
        draw.arc([bx, by-2, bx+6, by+2], 200, 340, fill=(*palette["ink"], 100), width=1)

    # UI 元素 (手绘风 - 毛笔边框感)
    # 顶部资源条 - 用弧形边框
    draw.rounded_rectangle([10, 8, W-10, 40], radius=6, fill=(35, 35, 38, 200))
    draw.rounded_rectangle([10, 8, W-10, 40], radius=6, outline=(197, 163, 104, 160), width=1)
    font = get_font(13)
    for text, x in [("粮: 1200", 40), ("钱: 800", 180), ("铁: 350", 320), ("回合: 5", 460)]:
        draw.text((x, 24), text, fill=(217, 190, 139, 200), font=font, anchor="lm")

    # 右侧单位面板 (手绘卷轴感)
    panel_x = W - 190
    draw.rounded_rectangle([panel_x, H-210, W-15, H-15], radius=8, fill=(35, 35, 38, 200))
    draw.rounded_rectangle([panel_x, H-210, W-15, H-15], radius=8, outline=(197, 163, 104, 140), width=1)
    # 卷轴装饰
    draw.ellipse([panel_x-3, H-215, panel_x+8, H-200], fill=(197, 163, 104, 120))
    draw.ellipse([W-20, H-215, W-9, H-200], fill=(197, 163, 104, 120))

    draw.text((panel_x+20, H-190), "秦锐士", fill=(195, 110, 68), font=get_font(15))
    draw.text((panel_x+20, H-165), "攻击: 12", fill=(217, 190, 139, 200), font=font)
    draw.text((panel_x+20, H-145), "防御: 8", fill=(217, 190, 139, 200), font=font)
    draw.text((panel_x+20, H-125), "移动力: 3", fill=(217, 190, 139, 200), font=font)

    # 回合按钮 (手绘圆角)
    btn_x, btn_y = W - 130, 55
    draw.rounded_rectangle([btn_x, btn_y, btn_x+110, btn_y+36], radius=8, fill=(35, 35, 38, 220))
    draw.rounded_rectangle([btn_x, btn_y, btn_x+110, btn_y+36], radius=8, outline=(197, 163, 104, 160), width=1)
    draw.text((btn_x+55, btn_y+18), "下回合", fill=(217, 190, 139), font=font, anchor="mm")

    # 水墨印章 (右下角)
    stamp_x, stamp_y = W - 80, H - 70
    draw.ellipse([stamp_x-20, stamp_y-20, stamp_x+20, stamp_y+20], fill=(160, 82, 42, 160))
    draw.ellipse([stamp_x-16, stamp_y-16, stamp_x+16, stamp_y+16], outline=(115, 58, 28, 180), width=1)
    draw.text((stamp_x, stamp_y), "策", fill=(255, 240, 220, 200), font=get_font(18), anchor="mm")

    # 标题
    font_sm = get_font(13)
    draw.text((W//2, H-25), "风格B: 手绘风 | 柔和边缘 | 水墨晕染 | 卷轴UI",
              fill=(197, 163, 104, 140), font=font_sm, anchor="mm")

    # 外框 (手绘感 - 不完全闭合)
    draw.rounded_rectangle([3, 3, W-4, H-4], radius=10, outline=(197, 163, 104, 80), width=1)

    return img.convert("RGBA")


if __name__ == "__main__":
    random.seed(42)
    print("Generating style demos...")

    img_a = generate_pixel_demo()
    save(img_a, "demo_style_A_pixel.png")

    img_b = generate_handdrawn_demo()
    save(img_b, "demo_style_B_handdrawn.png")

    print("Done! Check photos/ directory.")
