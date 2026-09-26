# -*- coding: utf-8 -*-
"""兵种图抠图：浅灰白底 -> 透明背景（边缘 flood-fill + 边界羽化）"""
import os
import numpy as np
from collections import deque
from PIL import Image

UNITS_DIR = r"E:\虚拟C盘\shanhece\shanhece-clean\assets\ai_art\units"
THRESH = 28  # 与背景种子的最大 RGB 距离
FEATHER = 4  # 羽化像素

def is_bg_seed(px):
    """背景种子：接近白色的浅灰像素"""
    return px[0] >= 225 and px[1] >= 225 and px[2] >= 225

def process(fpath):
    img = Image.open(fpath).convert("RGBA")
    arr = np.asarray(img).copy()
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3].astype(np.int16)
    alpha = arr[:, :, 3].copy()

    # 1) 边缘收集背景种子
    seeds = []
    edges = [(x, 0) for x in range(w)] + [(x, h-1) for x in range(w)] + \
            [(0, y) for y in range(h)] + [(w-1, y) for y in range(h)]
    for (x, y) in edges:
        if alpha[y, x] > 0 and is_bg_seed(rgb[y, x]):
            seeds.append((x, y))

    # 2) BFS 连通域标记背景
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
                if dist < THRESH * 2.2 and nc[0] >= 210 and nc[1] >= 210 and nc[2] >= 210:
                    bg_mask[ny, nx] = True
                    dq.append((nx, ny))

    # 3) 背景像素 alpha=0
    alpha[bg_mask] = 0

    # 4) 边界羽化：背景边界一圈渐变
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
    out = Image.fromarray(arr, "RGBA")
    out.save(fpath, "PNG")
    return True

def main():
    fixed = []
    for fname in sorted(os.listdir(UNITS_DIR)):
        if not fname.endswith(".png"):
            continue
        fpath = os.path.join(UNITS_DIR, fname)
        img = Image.open(fpath)
        if img.mode != "RGBA":
            img = img.convert("RGBA")
            img.save(fpath, "PNG")
        arr = np.asarray(img.convert("RGBA"))
        a = arr[:, :, 3]
        if a.min() >= 250:
            process(fpath)
            fixed.append(fname)
            print(f"cutout: {fname}")
        else:
            print(f"skip (already transparent): {fname}")
    print(f"\nTotal cutout: {len(fixed)}")

if __name__ == "__main__":
    main()
