# -*- coding: utf-8 -*-
"""兵种绿幕视频 → 透明 PNG 序列帧（Godot 可直接当 SpriteFrames 用）。

依赖：
  - ffmpeg（优先 PATH；可环境变量 FFMPEG 指定）
  - 可选：Python Pillow（仅做尺寸检查）

用法（PowerShell）：
  python tools/unit_chroma_pipeline.py --input "assets/ai_art/units/qin_ruishi_attack_greenscreen.mp4"
  python tools/unit_chroma_pipeline.py --input "assets/ai_art/units/infantry_attack_video.mp4" --fps 12 --size 256

输出：
  assets/units/frames/<name>/frame_00.png ...
  assets/units/frames/<name>/sprite_frames.json  （给 Godot 读的元数据）

Godot 侧（skirmish_tile_textures 已有 effect_frames 可扩展）：
  1. AnimatedSprite2D / Sprite2D + SpriteFrames
  2. 每帧 Texture2D，fps 默认 10~12
  3. 状态机 idle → attack → idle

抠图说明：
  ffmpeg colorkey=0x00FF00:similarity=0.3:blend=0.1
  绿幕偏色时改 similarity（0.2~0.45）或先 colorcorrect。
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_ROOT = ROOT / "assets" / "units" / "frames"


def find_ffmpeg() -> str | None:
    env = os.environ.get("FFMPEG")
    if env and Path(env).exists():
        return env
    for cand in (
        shutil.which("ffmpeg"),
        r"C:\ffmpeg\bin\ffmpeg.exe",
        r"C:\Program Files\ffmpeg\bin\ffmpeg.exe",
        str(Path.home() / "scoop" / "shims" / "ffmpeg.exe"),
    ):
        if cand and Path(cand).exists():
            return cand
    return None


def run_ffmpeg(ffmpeg: str, args: list[str]) -> int:
    cmd = [ffmpeg, "-y", *args]
    print(">", " ".join(cmd))
    return subprocess.call(cmd)


def process(input_path: Path, fps: int, size: int, key_hex: str, similarity: float, blend: float) -> Path:
    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        print("[ERROR] 未找到 ffmpeg。请安装或设置环境变量 FFMPEG=完整路径")
        print("  Windows 可用 winget install ffmpeg 或 scoop install ffmpeg")
        sys.exit(2)
    name = input_path.stem
    out_dir = OUT_ROOT / name
    out_dir.mkdir(parents=True, exist_ok=True)
    # 1) 抽帧 + 绿幕抠透明 + 缩放
    vf = (
        f"fps={fps},"
        f"scale={size}:{size}:force_original_aspect_ratio=decrease,"
        f"pad={size}:{size}:(ow-iw)/2:(oh-ih)/2:color=black@0,"
        f"colorkey={key_hex}:similarity={similarity}:blend={blend},"
        f"format=rgba"
    )
    pattern = str(out_dir / "frame_%02d.png")
    rc = run_ffmpeg(ffmpeg, ["-i", str(input_path), "-vf", vf, pattern])
    if rc != 0:
        print("[ERROR] ffmpeg 失败，exit", rc)
        sys.exit(rc)
    frames = sorted(out_dir.glob("frame_*.png"))
    meta = {
        "source": str(input_path.relative_to(ROOT)).replace("\\", "/"),
        "fps": fps,
        "frame_count": len(frames),
        "size": [size, size],
        "frames": [f"res://assets/units/frames/{name}/{f.name}" for f in frames],
        "godot_hint": {
            "animation": "attack",
            "loop": False,
            "autoplay_after": "idle",
        },
    }
    (out_dir / "sprite_frames.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[OK] {len(frames)} 帧 → {out_dir}")
    print(f"     元数据 → {out_dir / 'sprite_frames.json'}")
    return out_dir


def main() -> None:
    p = argparse.ArgumentParser(description="绿幕兵种视频抽帧+抠图（Godot 序列帧）")
    p.add_argument("--input", required=True, help="视频路径，如 assets/ai_art/units/xxx.mp4")
    p.add_argument("--fps", type=int, default=12, help="输出帧率，默认 12")
    p.add_argument("--size", type=int, default=256, help="输出边长像素，默认 256")
    p.add_argument("--key", default="0x00FF00", help="绿幕色，如 0x00FF00")
    p.add_argument("--similarity", type=float, default=0.32, help="抠图相似度 0.2~0.45")
    p.add_argument("--blend", type=float, default=0.1, help="边缘混合")
    args = p.parse_args()
    inp = Path(args.input)
    if not inp.is_absolute():
        inp = ROOT / inp
    if not inp.exists():
        print("[ERROR] 输入不存在:", inp)
        sys.exit(1)
    process(inp, args.fps, args.size, args.key, args.similarity, args.blend)


if __name__ == "__main__":
    main()
