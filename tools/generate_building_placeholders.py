# -*- coding: utf-8 -*-
"""生成 32x32 战国风建筑占位图（低饱和暖色，像素风）。
输出：assets/buildings/tile_building_<id>.png
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(r"E:/Mountains_Rivers-The_Warring_States/assets/buildings")
OUT.mkdir(parents=True, exist_ok=True)

# 调色板（低饱和暖色）
BG = (0, 0, 0, 0)
WOOD = (122, 86, 52)
WOOD_D = (88, 60, 38)
STONE = (140, 132, 118)
STONE_D = (100, 94, 84)
ROOF = (156, 72, 58)
ROOF_D = (120, 52, 42)
FIELD = (110, 130, 70)
FIELD_D = (82, 100, 52)
GOLD = (196, 160, 70)
WATER = (70, 110, 140)
INK = (40, 34, 30)


def px(d, x, y, c):
    d.point((x, y), fill=c)


def rect(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], outline=c, fill=c)


def outline_rect(d, x0, y0, x1, y1, fill, line):
    d.rectangle([x0, y0, x1, y1], fill=fill, outline=line)


def make_base():
    img = Image.new("RGBA", (32, 32), BG)
    return img, ImageDraw.Draw(img)


def save(name, img):
    path = OUT / f"tile_building_{name}.png"
    img.save(path)
    print("wrote", path.name)


def draw_farm():
    img, d = make_base()
    for row, y in enumerate(range(18, 30, 3)):
        c = FIELD if row % 2 == 0 else FIELD_D
        d.rectangle([4, y, 27, y + 1], fill=c)
    outline_rect(d, 12, 8, 19, 17, WOOD, WOOD_D)
    d.polygon([(10, 8), (21, 8), (15, 3)], fill=ROOF, outline=ROOF_D)
    save("farm", img)


def draw_market():
    img, d = make_base()
    outline_rect(d, 6, 14, 25, 28, WOOD, WOOD_D)
    # 摊棚
    d.polygon([(4, 14), (27, 14), (25, 8), (6, 8)], fill=ROOF, outline=ROOF_D)
    d.rectangle([9, 18, 13, 24], fill=GOLD, outline=INK)
    d.rectangle([18, 18, 22, 24], fill=GOLD, outline=INK)
    save("market", img)


def draw_wall():
    img, d = make_base()
    outline_rect(d, 2, 12, 29, 28, STONE, STONE_D)
    # 垛口
    for x in range(2, 30, 4):
        d.rectangle([x, 8, x + 2, 12], fill=STONE, outline=STONE_D)
    d.line([2, 20, 29, 20], fill=STONE_D)
    save("wall", img)


def draw_tower():
    img, d = make_base()
    outline_rect(d, 11, 10, 20, 29, STONE, STONE_D)
    d.polygon([(9, 10), (22, 10), (15, 3)], fill=ROOF, outline=ROOF_D)
    d.rectangle([14, 16, 17, 20], fill=INK)
    save("arrow_tower", img)


def draw_barracks():
    img, d = make_base()
    outline_rect(d, 5, 14, 26, 28, WOOD, WOOD_D)
    d.polygon([(3, 14), (28, 14), (15, 5)], fill=ROOF_D, outline=INK)
    d.rectangle([13, 20, 18, 28], fill=INK)
    save("barracks", img)


def draw_academy():
    img, d = make_base()
    outline_rect(d, 4, 12, 27, 28, WOOD, WOOD_D)
    d.polygon([(2, 12), (29, 12), (15, 4)], fill=ROOF, outline=ROOF_D)
    d.rectangle([8, 18, 12, 26], fill=GOLD, outline=WOOD_D)
    d.rectangle([19, 18, 23, 26], fill=GOLD, outline=WOOD_D)
    save("academy", img)


def draw_granary():
    img, d = make_base()
    # 粮仓圆桶
    outline_rect(d, 8, 12, 23, 28, WOOD, WOOD_D)
    d.ellipse([8, 8, 23, 16], fill=WOOD, outline=WOOD_D)
    d.line([8, 20, 23, 20], fill=WOOD_D)
    save("granary", img)


def draw_forge():
    img, d = make_base()
    outline_rect(d, 6, 14, 25, 28, STONE, STONE_D)
    d.rectangle([12, 8, 19, 14], fill=STONE_D, outline=INK)
    d.rectangle([14, 18, 17, 24], fill=(200, 90, 40), outline=INK)  # 炉火
    save("forge", img)


def draw_stable():
    img, d = make_base()
    outline_rect(d, 4, 14, 27, 28, WOOD, WOOD_D)
    d.polygon([(2, 14), (29, 14), (15, 6)], fill=ROOF_D, outline=INK)
    d.rectangle([7, 20, 12, 26], fill=INK)
    d.rectangle([19, 20, 24, 26], fill=INK)
    save("stable", img)


def draw_temple():
    img, d = make_base()
    outline_rect(d, 6, 14, 25, 28, STONE, STONE_D)
    d.polygon([(4, 14), (27, 14), (15, 5)], fill=GOLD, outline=WOOD_D)
    d.rectangle([14, 20, 17, 28], fill=WOOD_D)
    save("temple", img)


def draw_dock():
    img, d = make_base()
    # 水面
    for y in range(24, 32, 2):
        d.line([0, y, 31, y], fill=WATER)
    outline_rect(d, 8, 12, 23, 22, WOOD, WOOD_D)
    d.polygon([(6, 12), (25, 12), (15, 6)], fill=ROOF, outline=ROOF_D)
    save("dock", img)


def draw_workshop():
    img, d = make_base()
    outline_rect(d, 5, 13, 26, 28, WOOD, WOOD_D)
    d.rectangle([10, 6, 21, 13], fill=STONE, outline=STONE_D)
    d.rectangle([13, 18, 18, 25], fill=STONE_D, outline=INK)
    save("workshop", img)


def draw_beacon():
    img, d = make_base()
    outline_rect(d, 12, 16, 19, 29, STONE, STONE_D)
    d.rectangle([10, 10, 21, 16], fill=STONE, outline=STONE_D)
    d.polygon([(12, 10), (19, 10), (15, 4)], fill=(220, 140, 50), outline=INK)
    save("beacon_tower", img)


def draw_generic_economy():
    img, d = make_base()
    outline_rect(d, 7, 14, 24, 28, WOOD, WOOD_D)
    d.polygon([(5, 14), (26, 14), (15, 7)], fill=ROOF, outline=ROOF_D)
    save("economy", img)


def draw_generic_military():
    img, d = make_base()
    outline_rect(d, 6, 14, 25, 28, STONE, STONE_D)
    d.polygon([(4, 14), (27, 14), (15, 6)], fill=ROOF_D, outline=INK)
    save("military", img)


def draw_generic_politics():
    img, d = make_base()
    outline_rect(d, 5, 13, 26, 28, STONE, STONE_D)
    d.polygon([(3, 13), (28, 13), (15, 5)], fill=GOLD, outline=WOOD_D)
    save("politics", img)


def draw_generic_defense():
    img, d = make_base()
    outline_rect(d, 4, 12, 27, 28, STONE, STONE_D)
    for x in range(4, 28, 5):
        d.rectangle([x, 8, x + 2, 12], fill=STONE, outline=STONE_D)
    save("defense", img)


def draw_inner_gate():
    img, d = make_base()
    outline_rect(d, 3, 14, 28, 28, STONE, STONE_D)
    d.rectangle([12, 18, 19, 28], fill=INK)
    d.polygon([(1, 14), (30, 14), (28, 10), (3, 10)], fill=STONE_D, outline=INK)
    save("inner_gate", img)


if __name__ == "__main__":
    draw_farm()
    draw_market()
    draw_wall()
    draw_tower()
    draw_barracks()
    draw_academy()
    draw_granary()
    draw_forge()
    draw_stable()
    draw_temple()
    draw_dock()
    draw_workshop()
    draw_beacon()
    draw_inner_gate()
    draw_generic_economy()
    draw_generic_military()
    draw_generic_politics()
    draw_generic_defense()
    print("ALL BUILDING PLACEHOLDERS DONE")
