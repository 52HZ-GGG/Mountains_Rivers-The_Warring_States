"""
将精灵表拆分为单帧文件，方便 Godot 直接导入为 SpriteFrames

输入: unit_animations/unit_infantry/idle.png (4帧水平排列, 4096x1024)
输出: unit_animations_split/unit_infantry/idle_01.png ~ idle_04.png (每张 1024x1024)

运行: python split_animations.py
"""

import os
from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(ROOT, "unit_animations")
OUT_DIR = os.path.join(ROOT, "unit_animations_split")
os.makedirs(OUT_DIR, exist_ok=True)

FRAME_W = 1024
FRAME_H = 1024
NUM_FRAMES = 4

total = 0

for unit_name in sorted(os.listdir(SRC_DIR)):
    unit_src = os.path.join(SRC_DIR, unit_name)
    if not os.path.isdir(unit_src):
        continue

    unit_out = os.path.join(OUT_DIR, unit_name)
    os.makedirs(unit_out, exist_ok=True)

    for fname in sorted(os.listdir(unit_src)):
        if not fname.endswith(".png"):
            continue

        src_path = os.path.join(unit_src, fname)
        sheet = Image.open(src_path)

        # 计算实际帧数（根据图片宽度）
        actual_frames = sheet.width // FRAME_W
        anim_name = fname.replace(".png", "")

        for i in range(actual_frames):
            x = i * FRAME_W
            frame = sheet.crop((x, 0, x + FRAME_W, FRAME_H))
            out_name = f"{anim_name}_{i+1:02d}.png"
            frame.save(os.path.join(unit_out, out_name))
            total += 1

    print(f"  [OK] {unit_name}/ ({len(os.listdir(unit_out))} frames)")

print(f"\n=== 完成: {total} 个单帧文件 ===")
print(f"输出目录: {OUT_DIR}")
