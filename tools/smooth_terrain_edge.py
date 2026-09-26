# -*- coding: utf-8 -*-
"""去掉地形瓦片六边形描边轮廓：边界内侧 4px 颜色向深部 12px 采样混合"""
import os
import numpy as np
from collections import deque
from PIL import Image

TERRAIN_DIR = r"E:\虚拟C盘\shanhece\shanhece-clean\assets\ai_art\terrain"
EDGE_BAND = 4      # 处理边界内侧多少像素
SAMPLE_DIST = 12   # 从边界向内侧采样的距离

def process(fpath):
    img = Image.open(fpath).convert("RGBA")
    arr = np.asarray(img).copy()
    h, w = arr.shape[:2]
    a = arr[:, :, 3].astype(np.int32)
    rgb = arr[:, :, :3].astype(np.float32)

    # BFS 从边界向内侧计算距离
    dist = np.full((h, w), 10**9, dtype=np.int32)
    dq = deque()
    for y in range(h):
        for x in range(w):
            if a[y, x] <= 0:
                continue
            if (x > 0 and a[y, x-1] <= 0) or (x < w-1 and a[y, x+1] <= 0) or \
               (y > 0 and a[y-1, x] <= 0) or (y < h-1 and a[y+1, x] <= 0):
                dist[y, x] = 1
                dq.append((x, y, 1))
    while dq:
        x, y, d = dq.popleft()
        nd = d + 1
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < w and 0 <= ny < h and a[ny, nx] > 0 and nd < dist[ny, nx]:
                dist[ny, nx] = nd
                dq.append((nx, ny, nd))

    # 对边界带内像素：颜色向内侧 SAMPLE_DIST 处混合
    ys, xs = np.nonzero((dist > 0) & (dist <= EDGE_BAND) & (a > 0))
    for i in range(len(xs)):
        x, y = int(xs[i]), int(ys[i])
        d = dist[y, x]
        # 沿径向向内找采样点：用 8 邻域最小距离方向
        best = None
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < w and 0 <= ny < h and dist[ny, nx] > d:
                cand = dist[ny, nx]
                if best is None or cand < best[0]:
                    best = (cand, nx, ny)
        if best is None:
            continue
        _, bx, by = best
        # 从采样点继续沿方向走 SAMPLE_DIST
        sx, sy = x, y
        steps = 0
        while steps < SAMPLE_DIST:
            nbest = None
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)):
                nx, ny = sx+dx, sy+dy
                if 0 <= nx < w and 0 <= ny < h and a[ny, nx] > 0:
                    if nbest is None or dist[ny, nx] > dist[sy, sx]:
                        nbest = (nx, ny)
            if nbest is None:
                break
            sx, sy = nbest
            steps += 1
        if a[sy, sx] > 0:
            t = 0.5
            rgb[y, x] = rgb[y, x] * t + rgb[sy, sx] * (1 - t)

    arr[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(fpath, "PNG")

def main():
    targets = [f for f in os.listdir(TERRAIN_DIR) if f.endswith(".png") and ("_02" in f or "_03" in f)]
    for fname in targets:
        fpath = os.path.join(TERRAIN_DIR, fname)
        process(fpath)
        print(f"smoothed: {fname}")
    print(f"done {len(targets)}")

if __name__ == "__main__":
    main()
