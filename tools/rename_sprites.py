#!/usr/bin/env python3
"""批量重命名 assets/sprites/ 下不规范的文件名，使其符合 pre-push 检查。

规则：
  - 兵种动画帧: unit_archer/idle_01.png → unit_archer/unit_archer_idle_01.png
  - 特效帧:     fx_fire/fx_fire_01.png → fx_fire/ui_fx_fire_01.png

用法：python3 tools/rename_sprites.py [--dry-run]
"""
import os, sys, re

SPRITES_DIR = 'assets/sprites'
DRY_RUN = '--dry-run' in sys.argv

# 规范：必须匹配 tile_|unit_|ui_ 开头
VALID = re.compile(r'^(tile|unit|ui)_[a-z]+(_[a-z0-9]+)*\.png$')

rename_count = 0

def rename_file(old_path: str, new_name: str) -> None:
    global rename_count
    new_path = os.path.join(os.path.dirname(old_path), new_name)
    if os.path.exists(new_path):
        print(f"  [SKIP] 目标已存在: {new_path}")
        return
    if DRY_RUN:
        print(f"  [DRY] {os.path.basename(old_path)} → {new_name}")
    else:
        os.rename(old_path, new_path)
        print(f"  [OK] {os.path.basename(old_path)} → {new_name}")
    rename_count += 1

def process_unit_animations() -> None:
    """处理 units/{faction}/unit_{name}/ 下的动画帧"""
    factions = ['base', 'qin', 'zhao', 'qi', 'chu', 'wei', 'yan', 'han']
    for faction in factions:
        faction_dir = os.path.join(SPRITES_DIR, 'units', faction)
        if not os.path.isdir(faction_dir):
            continue
        for unit_folder in os.listdir(faction_dir):
            unit_path = os.path.join(faction_dir, unit_folder)
            if not os.path.isdir(unit_path) or not unit_folder.startswith('unit_'):
                continue
            # unit_archer → archer（避免 unit_unit_archer_idle_01）
            unit_short = unit_folder[5:]  # 去掉 "unit_"
            for f in os.listdir(unit_path):
                if not f.endswith('.png') or VALID.match(f):
                    continue
                # idle_01.png → unit_archer_idle_01.png
                new_name = f"unit_{unit_short}_{f}"
                rename_file(os.path.join(unit_path, f), new_name)

def process_effects() -> None:
    """处理 units/effects/fx_{name}/ 下的特效帧"""
    effects_dir = os.path.join(SPRITES_DIR, 'units', 'effects')
    if not os.path.isdir(effects_dir):
        return
    for fx_folder in os.listdir(effects_dir):
        fx_path = os.path.join(effects_dir, fx_folder)
        if not os.path.isdir(fx_path) or not fx_folder.startswith('fx_'):
            continue
        for f in os.listdir(fx_path):
            if not f.endswith('.png') or VALID.match(f):
                continue
            # fx_fire_01.png → ui_fx_fire_01.png
            new_name = f"ui_{f}"
            rename_file(os.path.join(fx_path, f), new_name)

if __name__ == '__main__':
    print("=== 批量重命名 assets/sprites ===")
    if DRY_RUN:
        print("[DRY-RUN 模式，不会实际修改文件]\n")

    print("[1/2] 兵种动画帧：")
    process_unit_animations()

    print("\n[2/2] 特效帧：")
    process_effects()

    print(f"\n共 {'预览' if DRY_RUN else '重命名'} {rename_count} 个文件")
    if DRY_RUN:
        print("去掉 --dry-run 参数执行实际重命名")
