# -*- coding: utf-8 -*-
"""buff/debuff 通用图标：白底抠透明 + 转真 PNG"""
import os
import numpy as np
from collections import deque
from PIL import Image

ICONS_DIR = r"E:\虚拟C盘\shanhece\shanhece-clean\assets\ai_art\ui\icons"
THRESH = 28
FEATHER = 4

def cutout(fpath):
    img = Image.open(fpath).convert("RGBA")
    arr = np.asarray(img).copy()
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3].astype(np.int16)
    alpha = arr[:, :, 3].copy()
    seeds = []
    edges = [(x, 0) for x in range(w)] + [(x, h-1) for x in range(w)] + \
            [(0, y) for y in range(h)] + [(w-1, y) for y in range(h)]
    for (x, y) in edges:
        p = rgb[y, x]
        if alpha[y, x] > 0 and p[0] >= 225 and p[1] >= 225 and p[2] >= 225:
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
                if dist < THRESH * 2.2 and nc[0] >= 205 and nc[1] >= 205 and nc[2] >= 205:
                    bg_mask[ny, nx] = True
                    dq.append((nx, ny))
    alpha[bg_mask] = 0
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
    urls = {
        "icon_buff_generic.png": "https://aka.doubaocdn.com/s/17kqXZlBAG",
        "icon_debuff_generic.png": "https://aka.doubaocdn.com/s/Pa5teLY5Xp",
    }
    for fname, url in urls.items():
        fpath = os.path.join(ICONS_DIR, fname)
        os.system(f'curl.exe -L -s -o "{fpath}" "{url}"')
        img = Image.open(fpath)
        if img.format == "JPEG" or img.mode != "RGBA":
            img = img.convert("RGBA")
            img.save(fpath, "PNG")
        cutout(fpath)
        a = np.asarray(Image.open(fpath).convert("RGBA").getchannel("A"))
        print(f"{fname}: 透明占比={(a==0).mean()*100:.0f}%")

if __name__ == "__main__":
    main()
