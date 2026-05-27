#!/usr/bin/env python3
"""
将 big_map_terrain.json 渲染为 PNG 预览图（使用 Pillow）。
运行: python tools/preview_big_map.py
输出: tools/big_map_preview.png
"""

import json
import os
import math
from PIL import Image, ImageDraw

TERRAIN_COLOR = {
    "plains":         (180, 195, 140),
    "forest":         (60, 120, 50),
    "mountain":       (140, 120, 100),
    "river":          (60, 130, 200),
    "marsh":          (100, 150, 80),
    "pass":           (200, 180, 80),
    "ford":           (80, 160, 220),
    "desert":         (220, 200, 150),
    "tundra":         (200, 210, 220),
    "deep_ocean":     (20, 50, 120),
    "shallow_ocean":  (40, 80, 160),
}

FACTION_COLOR = {
    "qin":     (120, 60, 60),
    "chu":     (60, 100, 60),
    "qi":      (200, 180, 50),
    "zhao":    (80, 80, 140),
    "wei":     (180, 100, 50),
    "han":     (160, 60, 120),
    "yan":     (50, 140, 140),
    "zhou":    (200, 160, 40),
    "neutral": (140, 140, 140),
}


def hex_corners(cx, cy, r):
    return [(cx + r * math.cos(math.radians(60 * i)),
             cy + r * math.sin(math.radians(60 * i))) for i in range(6)]


def main():
    base = os.path.join(os.path.dirname(__file__), "..", "data")
    with open(os.path.join(base, "big_map_terrain.json"), encoding="utf-8") as f:
        terrain_data = json.load(f)
    with open(os.path.join(base, "cities.json"), encoding="utf-8") as f:
        cities_data = json.load(f)

    rows = terrain_data["rows"]
    map_w = terrain_data["map_width"]
    map_h = terrain_data["map_height"]

    hex_r = 8
    hex_w = hex_r * math.sqrt(3)
    hex_h = hex_r * 2

    img_w = int(map_w * hex_w + hex_w + 4)
    img_h = int(map_h * hex_h * 0.75 + hex_h + 4)

    img = Image.new("RGB", (img_w, img_h), (240, 235, 220))
    draw = ImageDraw.Draw(img)

    # Draw terrain hexagons
    for row in range(map_h):
        for col in range(map_w):
            terrain = rows[row][col]
            fill = TERRAIN_COLOR.get(terrain, (200, 200, 200))
            edge = tuple(max(0, c - 30) for c in fill)
            ox = col * hex_w + (hex_w / 2 if row % 2 == 1 else 0) + 2
            oy = row * hex_h * 0.75 + hex_h / 2 + 2
            corners = hex_corners(ox, oy, hex_r - 0.5)
            draw.polygon(corners, fill=fill, outline=edge)

    # Draw cities
    for city in cities_data.get("cities", []):
        q, r = city["hex_q"], city["hex_r"]
        if q >= map_w or r >= map_h:
            continue
        fid = city.get("faction_id", "neutral")
        is_cap = city.get("is_capital", False)
        color = FACTION_COLOR.get(fid, (140, 140, 140))
        ox = q * hex_w + (hex_w / 2 if r % 2 == 1 else 0) + 2
        oy = r * hex_h * 0.75 + hex_h / 2 + 2
        dot_r = 4 if is_cap else 3
        draw.ellipse([ox - dot_r, oy - dot_r, ox + dot_r, oy + dot_r], fill=color)
        if is_cap:
            draw.ellipse([ox - 2, oy - 2, ox + 2, oy + 2], fill=(255, 255, 255))

    out_path = os.path.join(os.path.dirname(__file__), "big_map_preview.png")
    img.save(out_path)
    print(f"Preview saved: {out_path} ({img_w}x{img_h})")


if __name__ == "__main__":
    main()
