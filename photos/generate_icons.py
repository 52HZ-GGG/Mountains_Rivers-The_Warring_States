"""
《山河策》学派图标生成器 V2
1024x1024 | 六大可选学派 | 像素风 | 透明背景
运行: python generate_icons.py
"""

import os, math, random
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "icon1")
os.makedirs(OUT_DIR, exist_ok=True)

SZ = 1024

# ── 色板 ──
INK = (26, 26, 27)
BAM = (197, 163, 104)
BAM_H = (217, 190, 139)
BAM_S = (153, 122, 74)
BAM_D = (102, 82, 49)
LAC = (140, 69, 34)
LAC_H = (176, 93, 59)
BRO = (43, 51, 48)
BRO_H = (69, 82, 77)

# ── 字体 ──
FONT_CN = "C:/Windows/Fonts/STLITI.TTF"

def pb(d, x, y, w, h, c):
    d.rectangle([x, y, x+w-1, y+h-1], fill=c)

def draw_text_centered(d, cx, cy, text, font_path, size, color):
    font = ImageFont.truetype(font_path, size)
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = cx - tw // 2
    y = cy - th // 2 - bbox[1]
    d.text((x, y), text, font=font, fill=color)

def save(img, name):
    path = os.path.join(OUT_DIR, f"{name}.png")
    img.save(path)
    print(f"  [OK] {name}.png")


# ══════════════════════════════════════════════════════════
#  儒家 — 仁政礼治：鼎 + 竹简 + 祭祀
# ══════════════════════════════════════════════════════════
def icon_confucianism():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    # 圆形底座
    d.ellipse([80, 80, 944, 944], fill=(*BAM_D, 220))
    d.ellipse([112, 112, 912, 912], fill=(*BAM_S, 200))
    # ── 鼎（礼器） ──
    # 鼎耳
    d.arc([368, 176, 448, 304], 180, 360, fill=(*INK, 220), width=16)
    d.arc([576, 176, 656, 304], 180, 360, fill=(*INK, 220), width=16)
    # 鼎身（梯形）
    d.polygon([(352, 304), (672, 304), (720, 576), (304, 576)], fill=(*LAC, 220))
    d.polygon([(384, 336), (640, 336), (688, 544), (336, 544)], fill=(*LAC_H, 200))
    # 鼎足
    for x in [384, 512, 640]:
        pb(d, x-24, 576, 48, 96, (*INK, 200))
        pb(d, x-16, 656, 32, 24, (*BRO_H, 180))
    # 鼎纹（兽面纹简化）
    d.line([(432, 400), (592, 400)], fill=(*BAM_H, 180), width=8)
    d.line([(416, 440), (608, 440)], fill=(*BAM_H, 160), width=8)
    d.point((480, 464), fill=(*BAM_H, 200))
    d.point((544, 464), fill=(*BAM_H, 200))
    d.arc([448, 480, 576, 544], 0, 180, fill=(*BAM_H, 180), width=8)
    # ── 竹简（两侧） ──
    for sx in [176, 768]:
        for i in range(5):
            y = 320 + i * 80
            pb(d, sx, y, 64, 8, (*BAM, 160))
    # ── 装饰环 ──
    d.ellipse([64, 64, 960, 960], outline=(*BAM_H, 200), width=16)
    d.ellipse([96, 96, 928, 928], outline=(*BAM_S, 160), width=8)
    # 文字
    draw_text_centered(d, cx, 800, "儒", FONT_CN, 176, (*BAM_H, 230))
    save(img, "icon_confucianism")


# ══════════════════════════════════════════════════════════
#  法家 — 法治耕战：律令竹简 + 刑鼎 + 利剑
# ══════════════════════════════════════════════════════════
def icon_legalism():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    # 方形底座（法度方正）
    pb(d, 80, 80, 864, 864, (30, 30, 32, 220))
    pb(d, 112, 112, 800, 800, (45, 45, 48, 200))
    # ── 律令竹简（中央展开） ──
    # 卷轴左轴
    pb(d, 192, 240, 48, 544, (*BAM_S, 220))
    pb(d, 200, 248, 32, 528, (*BAM, 200))
    # 卷轴右轴
    pb(d, 784, 240, 48, 544, (*BAM_S, 220))
    pb(d, 792, 248, 32, 528, (*BAM, 200))
    # 简面
    pb(d, 240, 240, 544, 544, (*BAM_D, 180))
    # 简文（律条）
    for i in range(6):
        y = 280 + i * 80
        pb(d, 272, y, 480, 8, (*INK, 160))
    # ── 利剑（贯穿） ──
    # 剑身
    for i in range(400):
        x = 400 + i
        y = 512 - i // 10
        if 240 < x < 784:
            c = (180, 185, 195) if abs(i - 200) < 80 else (150, 155, 165)
            alpha = max(120, 220 - abs(i-200) * 1)
            pb(d, x, y, 8, 24, (*c, alpha))
    # 剑格
    pb(d, 384, 480, 48, 64, (*BAM_H, 220))
    # 剑柄
    pb(d, 304, 496, 80, 32, (*BRO, 200))
    # ── 天平符号（公正） ──
    # 横杆
    d.line([(400, 176), (624, 176)], fill=(*BAM_H, 180), width=16)
    # 支点
    d.polygon([(504, 176), (520, 176), (528, 224), (496, 224)], fill=(*BAM_H, 200))
    # 左盘
    d.arc([384, 176, 448, 240], 0, 180, fill=(*BAM_H, 180), width=8)
    # 右盘
    d.arc([576, 176, 640, 240], 0, 180, fill=(*BAM_H, 180), width=8)
    # 边框
    pb(d, 64, 64, 896, 16, (*BAM_S, 180))
    pb(d, 64, 944, 896, 16, (*BAM_S, 180))
    pb(d, 64, 64, 16, 896, (*BAM_S, 180))
    pb(d, 944, 64, 16, 896, (*BAM_S, 180))
    # 角钉
    for x, y in [(96,96),(896,96),(96,896),(896,896)]:
        d.ellipse([x-24, y-24, x+24, y+24], fill=(*BAM_H, 200))
    draw_text_centered(d, cx, 848, "法", FONT_CN, 160, (*BAM_H, 230))
    save(img, "icon_legalism")


# ══════════════════════════════════════════════════════════
#  墨家 — 兼爱非攻：城防 + 连弩 + 墨线
# ══════════════════════════════════════════════════════════
def icon_mohism():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    # 八角形底座（规矩）
    pts = []
    for i in range(8):
        angle = math.radians(-90 + i * 45)
        pts.append((int(cx + 440 * math.cos(angle)), int(cy + 440 * math.sin(angle))))
    d.polygon(pts, fill=(*BRO, 220))
    pts2 = []
    for i in range(8):
        angle = math.radians(-90 + i * 45)
        pts2.append((int(cx + 400 * math.cos(angle)), int(cy + 400 * math.sin(angle))))
    d.polygon(pts2, fill=(*BRO_H, 200))
    # ── 城墙（防御工事） ──
    # 城墙主体
    pb(d, 224, 400, 576, 280, (*BRO, 220))
    pb(d, 240, 416, 544, 248, (*BRO_H, 200))
    # 城垛
    for x in range(240, 784, 96):
        pb(d, x, 352, 64, 64, (*BRO, 220))
        pb(d, x+8, 360, 48, 48, (*BRO_H, 200))
    # 城门
    d.arc([448, 480, 576, 672], 180, 360, fill=(*INK, 200), width=16)
    pb(d, 448, 576, 128, 104, (*INK, 200))
    # ── 连弩（城上） ──
    pb(d, 320, 288, 160, 32, (*BAM_S, 200))
    pb(d, 336, 272, 16, 48, (*BAM_S, 180))
    # 箭矢
    for i in range(3):
        ax = 352 + i * 40
        pb(d, ax, 224, 8, 64, (*BAM, 180))
        d.point((ax, 216), fill=(*BRO_H, 200))
    # ── 墨线（规矩工具） ──
    # 左下角矩尺
    d.line([(144, 704), (144, 800)], fill=(*BAM_H, 180), width=16)
    d.line([(144, 800), (240, 800)], fill=(*BAM_H, 180), width=16)
    # 右下角圆规
    d.line([(784, 704), (832, 800)], fill=(*BAM_H, 180), width=8)
    d.line([(784, 704), (736, 800)], fill=(*BAM_H, 180), width=8)
    d.point((784, 704), fill=(*BAM_H, 220))
    # 边框
    d.polygon(pts, outline=(*BAM_H, 200), width=16)
    draw_text_centered(d, cx, 800, "墨", FONT_CN, 176, (*BAM_H, 230))
    save(img, "icon_mohism")


# ══════════════════════════════════════════════════════════
#  道家 — 无为而治：太极 + 山水 + 云气
# ══════════════════════════════════════════════════════════
def icon_taoism():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    # 圆形底座（天道圆融）
    d.ellipse([80, 80, 944, 944], fill=(30, 40, 35, 220))
    d.ellipse([112, 112, 912, 912], fill=(40, 55, 45, 200))
    # ── 太极图 ──
    # 外圆
    d.ellipse([224, 192, 800, 768], fill=(200, 200, 190, 200))
    # 左半（黑）
    d.pieslice([224, 192, 800, 768], 90, 270, fill=(26, 26, 27, 220))
    # 上鱼眼（白中黑点）
    d.ellipse([432, 256, 576, 448], fill=(200, 200, 190, 220))
    d.ellipse([464, 304, 544, 400], fill=(26, 26, 27, 220))
    # 下鱼眼（黑中白点）
    d.ellipse([432, 512, 576, 704], fill=(26, 26, 27, 220))
    d.ellipse([464, 560, 544, 656], fill=(200, 200, 190, 220))
    # S曲线（简化）
    for i in range(240):
        t = i / 240
        y = int(192 + t * 576)
        x = int(512 + 112 * math.sin(t * math.pi))
        if 224 < x < 800 and 192 < y < 768:
            d.point((x, y), fill=(200, 200, 190, 180))
            d.point((x+1, y), fill=(200, 200, 190, 120))
    # ── 山水（底部） ──
    # 远山
    for x in range(160, 864):
        h = int(800 + 64 * math.sin(x * 0.01) + 40 * math.sin(x * 0.019))
        for y in range(h, 896):
            if 112 < x < 912 and 112 < y < 912:
                c = (50, 65, 55) if y - h < 24 else (40, 55, 45)
                d.point((x, y), fill=(*c, 140))
    # ── 云气 ──
    random.seed(401)
    for _ in range(20):
        px = random.randint(160, 864)
        py = random.randint(128, 240)
        size = random.randint(24, 64)
        d.ellipse([px, py, px+size, py+size//2], fill=(180, 190, 180, 60))
    # 边框
    d.ellipse([64, 64, 960, 960], outline=(*BAM_H, 200), width=16)
    d.ellipse([96, 96, 928, 928], outline=(*BAM_S, 140), width=8)
    draw_text_centered(d, cx, 896, "道", FONT_CN, 144, (*BAM_H, 200))
    save(img, "icon_taoism")


# ══════════════════════════════════════════════════════════
#  兵家 — 出奇制胜：双剑交叉 + 虎符 + 兵法
# ══════════════════════════════════════════════════════════
def icon_military():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    # 盾形底座
    d.polygon([
        (160, 128), (512, 64), (864, 128),
        (896, 544), (800, 864), (512, 960), (224, 864), (128, 544)
    ], fill=(*BRO, 230))
    d.polygon([
        (192, 160), (512, 112), (832, 160),
        (864, 528), (768, 832), (512, 912), (256, 832), (160, 528)
    ], fill=(*BRO_H, 210))
    # ── 双剑交叉 ──
    # 左剑（从左上到右下）
    for i in range(480):
        x = 240 + i
        y = 160 + i
        if 192 < x < 832 and 112 < y < 912:
            c = (170, 175, 185) if abs(i - 240) < 120 else (140, 145, 155)
            alpha = max(100, 220 - abs(i-240) * 1)
            pb(d, x, y, 8, 8, (*c, alpha))
    # 左剑格
    d.line([(320, 224), (272, 272)], fill=(*BAM_H, 220), width=24)
    # 左剑柄
    d.line([(256, 272), (192, 336)], fill=(*BRO, 220), width=24)
    # 右剑（从右上到左下）
    for i in range(480):
        x = 784 - i
        y = 160 + i
        if 192 < x < 832 and 112 < y < 912:
            c = (170, 175, 185) if abs(i - 240) < 120 else (140, 145, 155)
            alpha = max(100, 220 - abs(i-240) * 1)
            pb(d, x, y, 8, 8, (*c, alpha))
    # 右剑格
    d.line([(704, 224), (752, 272)], fill=(*BAM_H, 220), width=24)
    # 右剑柄
    d.line([(768, 272), (832, 336)], fill=(*BRO, 220), width=24)
    # ── 虎符（交叉点） ──
    d.ellipse([432, 400, 592, 560], fill=(*BAM, 220))
    d.ellipse([456, 424, 568, 536], fill=(*BAM_H, 200))
    # 虎纹
    d.line([(480, 448), (544, 448)], fill=(*INK, 180), width=8)
    d.line([(472, 480), (552, 480)], fill=(*INK, 160), width=8)
    d.point((512, 504), fill=(*INK, 200))
    # ── 兵法竹简（底部） ──
    for i in range(5):
        y = 720 + i * 40
        pb(d, 320, y, 384, 8, (*BAM_S, 140))
    # 边框
    d.polygon([
        (144, 112), (512, 48), (880, 112),
        (912, 560), (816, 880), (512, 976), (208, 880), (112, 560)
    ], outline=(*BAM_H, 200), width=16)
    draw_text_centered(d, cx, 832, "兵", FONT_CN, 160, (*BAM_H, 230))
    save(img, "icon_military")


# ══════════════════════════════════════════════════════════
#  纵横家 — 合纵连横：天平 + 地图 + 舌
# ══════════════════════════════════════════════════════════
def icon_diplomacy():
    img = Image.new("RGBA", (SZ, SZ), (0,0,0,0))
    d = ImageDraw.Draw(img)
    cx, cy = 512, 512
    # 菱形底座
    d.polygon([(cx,80),(944,cy),(cx,944),(80,cy)], fill=(50, 40, 55, 220))
    d.polygon([(cx,144),(880,cy),(cx,880),(144,cy)], fill=(65, 52, 70, 200))
    # ── 天平（外交公正） ──
    # 横杆
    d.line([(272, 320), (752, 320)], fill=(*BAM_H, 220), width=16)
    # 支柱
    pb(d, 496, 320, 32, 224, (*BAM_H, 200))
    # 支座
    d.polygon([(448, 544), (576, 544), (544, 576), (480, 576)], fill=(*BAM_H, 220))
    # 左盘
    d.line([(272, 320), (240, 416)], fill=(*BAM_H, 180), width=8)
    d.line([(272, 320), (304, 416)], fill=(*BAM_H, 180), width=8)
    d.arc([208, 400, 336, 480], 0, 180, fill=(*BAM_H, 200), width=16)
    # 右盘
    d.line([(752, 320), (720, 416)], fill=(*BAM_H, 180), width=8)
    d.line([(752, 320), (784, 416)], fill=(*BAM_H, 180), width=8)
    d.arc([688, 400, 816, 480], 0, 180, fill=(*BAM_H, 200), width=16)
    # ── 七国地图（简化节点连线） ──
    nodes = [(240, 656), (400, 624), (560, 640), (720, 656),
             (320, 768), (512, 752), (672, 768)]
    # 连线（合纵）
    for i in range(6):
        x1, y1 = nodes[i]
        x2, y2 = nodes[i+1]
        d.line([(x1, y1), (x2, y2)], fill=(*BAM_H, 160), width=8)
    # 连横（横贯）
    d.line([(nodes[0]), (nodes[3])], fill=(*LAC_H, 140), width=8)
    d.line([(nodes[4]), (nodes[6])], fill=(*LAC_H, 140), width=8)
    # 节点
    for nx, ny in nodes:
        d.ellipse([nx-24, ny-24, nx+24, ny+24], fill=(*BAM_H, 200))
        d.point((nx-8, ny-8), fill=(*BAM, 220))
    # ── 舌（辩才） ──
    d.ellipse([432, 160, 592, 272], fill=(*LAC, 180))
    d.arc([448, 192, 576, 288], 200, 340, fill=(*LAC_H, 200), width=16)
    # 边框
    d.polygon([(cx,64),(960,cy),(cx,960),(64,cy)],
              outline=(*BAM_H, 200), width=16)
    draw_text_centered(d, cx, 864, "纵横", FONT_CN, 128, (*BAM_H, 220))
    save(img, "icon_diplomacy")


def generate_all():
    print("=== 《山河策》学派图标生成器 V2 (1024x1024) ===\n")
    for func in [icon_confucianism, icon_legalism, icon_mohism,
                 icon_taoism, icon_military, icon_diplomacy]:
        func()
    print(f"\n=== 完成！共 6 个学派图标 ===")
    print(f"输出: {OUT_DIR}")
    print("规格: 1024x1024 | 像素风 | 透明背景")
    print("\n请在本地查看 icon1/ 目录即可。")

if __name__ == "__main__":
    generate_all()
