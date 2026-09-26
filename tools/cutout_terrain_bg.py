# -*- coding: utf-8 -*-
"""地形变体抠图：白色方底 -> 透明（边缘 flood-fill + 羽化）"""
import os
import numpy as np
from collections import deque
from PIL import Image

TERRAIN_DIR = r"E:\虚拟C盘\shanhece\shanhece-clean\assets\ai_art\terrain"
THRESH = 30
FEATHER = 6

def process(fpath):
    img = Image.open(fpath).convert("RGBA")
    arr = np.asarray(img).copy()
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3].astype(np.int16)
    alpha = arr[:, :, 3].copy()

    # 边缘收集背景种子（白色）
    seeds = []
    edges = [(x, 0) for x in range(w)] + [(x, h-1) for x in range(w)] + \
            [(0, y) for y in range(h)] + [(w-1, y) for y in range(h)]
    for (x, y) in edges:
        p = rgb[y, x]
        if alpha[y, x] > 0 and p[0] >= 235 and p[1] >= 235 and p[2] >= 235:
            seeds.append((x, y))

    bg_mask = np.zeros((h, w), dtype=bool)
    dq = deque()
    for s in seeds:
        if not bg_mask[s[1], s[0]]:
            bg_mask[s[1], s[0]] = True
            dq.append(s)
    while dq:
        x, y = dq.popleft()
        c = rgb[y, x]
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < w and 0 <= ny < h and not bg_mask[ny, nx] and alpha[ny, nx] > 0:
                nc = rgb[ny, nx]
                dist = abs(int(nc[0])-int(c[0])) + abs(int(nc[1])-int(c[1])) + abs(int(nc[2])-int(c[2]))
                if dist < THRESH * 2.2 and nc[0] >= 200 and nc[1] >= 200 and nc[2] >= 200:
                    bg_mask[ny, nx] = True
                    dq.append((nx, ny))

    alpha[bg_mask] = 0

    # 羽化
    for i in range(1, FEATHER+1):
        edge = np.zeros((h, w), dtype=bool)
        edge[1:-1, 1:-1] = (bg_mask[2:, 1:-1] & ~bg_mask[1:-1, 1:-1]) | \
                            (bg_mask[:-2, 1:-1] & ~bg_mask[1:-1, 1:-1]) | \
                            (bg_mask[1:-1, 2:] & ~bg_mask[1:-1, 1:-1]) | \
                            (bg_mask[1:-1, :-2] & ~bg_mask[1:-1, 1:-1])
        edge &= bg_mask
        if not edge.any():
            break
        fade = 255 * (i / FEATHER)
        a = alpha.astype(np.float32)
        a[edge] = np.minimum(a[edge], fade)
        alpha = a.astype(np.uint8)
        bg_mask = bg_mask & (alpha > 0)

    arr[:, :, 3] = alpha
    Image.fromarray(arr, "RGBA").save(fpath, "PNG")

def main():
    targets = []
    for fname in sorted(os.listdir(TERRAIN_DIR)):
        if not fname.endswith(".png"):
            continue
        if "_02" in fname or "_03" in fname:
            targets.append(fname)
    for fname in targets:
        fpath = os.path.join(TERRAIN_DIR, fname)
        img = Image.open(fpath)
        if img.mode != "RGBA":
            img = img.convert("RGBA")
            img.save(fpath, "PNG")
        arr = np.asarray(Image.open(fpath).convert("RGBA"))
        if arr[:, :, 3].min() >= 250:
            process(fpath)
            print(f"cutout: {fname}")
        else:
            print(f"skip: {fname}")

if __name__ == "__main__":
    main()
