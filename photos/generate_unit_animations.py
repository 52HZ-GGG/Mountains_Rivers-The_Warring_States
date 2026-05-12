"""
《山河策》兵种动画生成器
为每个兵种生成 5 套动画精灵表（idle/move/attack/hurt/death）
每套 4 帧，64x64 像素/帧，导出 1024x1024

运行: python generate_unit_animations.py
"""

import os, math
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "unit_animations")
os.makedirs(OUT_DIR, exist_ok=True)

SZ = 64
FRAME_W = 64
FRAME_H = 64
NUM_FRAMES = 4
TRANSPARENT = (0, 0, 0, 0)
BG = (0, 0, 0, 0)  # 透明背景

# ── 色彩 ──
P = {
    "漆器红": [(140,69,34),(176,93,59),(102,48,24),(64,29,15)],
    "青铜靛": [(43,51,48),(69,82,77),(26,33,30),(13,18,16)],
    "竹简黄": [(197,163,104),(217,190,139),(153,122,74),(102,82,49)],
    "水墨黑": [(26,26,27),(51,51,52),(13,13,14),(0,0,0)],
}
N = {
    "森林": [(55,90,55),(78,115,78),(38,62,38),(22,40,22)],
    "山地": [(120,105,90),(148,132,115),(88,76,64),(58,50,42)],
}
SK = [(200,160,120),(220,185,145),(160,120,85),(130,95,65)]
IR = [(140,140,145),(175,175,180),(100,100,105),(65,65,70)]
BR = [(160,130,80),(190,160,100),(120,95,55),(80,60,35)]
RD = [(160,45,35),(195,65,50),(120,30,20),(80,18,12)]
FU = [(160,130,90),(185,155,115),(130,100,65),(90,70,45)]

# ── 工具函数 ──

def pb(d, x, y, w, h, c):
    d.rectangle([x, y, x+w-1, y+h-1], fill=c)

def dot(d, x, y, c):
    d.point((x, y), fill=c)

def draw_limb(d, x1, y1, x2, y2, c, w=3):
    d.line([(x1, y1), (x2, y2)], fill=c, width=w)

def draw_head(d, cx, cy, r, c_skin, c_hair):
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=c_skin)
    d.ellipse([cx-r, cy-r, cx+r, cy-r//2], fill=c_hair)

def draw_body(d, x1, y1, x2, y2, c):
    w = abs(x2 - x1)
    d.polygon([(x1, y1), (x2, y1), (x2+w//4, y2), (x1-w//4, y2)], fill=c)

def save_sheet(frames, name):
    """将 4 帧合并为精灵表并保存"""
    sheet = Image.new("RGBA", (FRAME_W * len(frames), FRAME_H), BG)
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * FRAME_W, 0))
    # 放大到 1024x1024/帧
    scale_w = FRAME_W * len(frames) * 16  # 64*16=1024
    scale_h = FRAME_H * 16
    sheet = sheet.resize((scale_w, scale_h), Image.NEAREST)
    path = os.path.join(OUT_DIR, f"{name}.png")
    sheet.save(path)
    print(f"  [OK] {name}.png ({len(frames)} frames)")


# ══════════════════════════════════════════════════════════
#  基础绘制函数（带偏移参数，用于动画）
# ══════════════════════════════════════════════════════════

def draw_infantry_frame(ox=0, oy=0, arm_angle=0, leg_phase=0, shield_y=0, spear_angle=0, hurt=False, dead=False):
    """画一帧步兵，返回 Image"""
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = P["漆器红"]
    cx, cy = 30 + ox, 30 + oy

    if dead:
        # 倒地
        draw_body(d, cx-14, cy+10, cx+6, cy+22, b)
        pb(d, cx-13, cy+11, 18, 10, h)
        draw_head(d, cx+10, cy+20, 5, SK[0], s)
        pb(d, cx-16, cy+8, 6, 4, IR[2])
        return img

    # 腿
    lk = int(3 * math.sin(leg_phase))
    draw_limb(d, cx-2, cy+12, cx-10+lk, cy+26, s, 4)
    draw_limb(d, cx+2, cy+12, cx+10-lk, cy+26, s, 4)
    pb(d, cx-12+lk, cy+24, 6, 4, dd)
    pb(d, cx+8-lk, cy+24, 6, 4, dd)

    # 身体
    draw_body(d, cx-6, cy-6, cx+6, cy+12, b)
    pb(d, cx-5, cy-5, 11, 17, h)
    pb(d, cx-10, cy-6, 6, 4, dd)
    pb(d, cx+6, cy-6, 6, 4, dd)

    # 头
    draw_head(d, cx, cy-12, 6, SK[0], s)
    pb(d, cx-6, cy-18, 12, 3, dd)
    pb(d, cx, cy-22, 2, 5, RD[0])

    if hurt:
        # 受击后仰
        pb(d, cx-8, cy-4, 3, 3, RD[1])
        pb(d, cx+6, cy+2, 2, 2, RD[2])

    # 左臂 - 盾
    sy = shield_y
    draw_limb(d, cx-8, cy-4, cx-22, cy+sy, b, 3)
    pb(d, cx-28, cy-10+sy, 10, 20, IR[2])
    pb(d, cx-27, cy-9+sy, 8, 18, IR[1])
    pb(d, cx-24, cy-4+sy, 3, 8, IR[0])

    # 右臂 - 矛
    sa = math.radians(spear_angle)
    ex = int(cx + 22 * math.cos(sa))
    ey = int(-4 + 22 * math.sin(sa)) + cy
    draw_limb(d, cx+8, cy-4, ex, ey, b, 3)
    for i in range(24):
        px = int(ex + i * math.cos(sa))
        py = int(ey + i * math.sin(sa))
        dot(d, px, py, BR[0])
    pb(d, ex + int(24*math.cos(sa))-2, ey + int(24*math.sin(sa))-2, 4, 4, IR[0])

    return img


def draw_archer_frame(ox=0, oy=0, bow_draw=0, leg_phase=0, hurt=False, dead=False):
    """画一帧弓兵"""
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = N["森林"]
    cx, cy = 32 + ox, 30 + oy

    if dead:
        draw_body(d, cx-12, cy+10, cx+8, cy+22, b)
        pb(d, cx-11, cy+11, 17, 10, h)
        draw_head(d, cx+12, cy+18, 5, SK[0], b)
        return img

    lk = int(3 * math.sin(leg_phase))
    draw_limb(d, cx+2, cy+12, cx-4+lk, cy+26, s, 4)
    draw_limb(d, cx+4, cy+12, cx+12-lk, cy+26, s, 4)
    pb(d, cx-6+lk, cy+24, 6, 4, dd)
    pb(d, cx+10-lk, cy+24, 6, 4, dd)

    # 身体后仰
    d.polygon([(cx-4, cy-6), (cx+6, cy-8), (cx+8, cy+12), (cx-2, cy+12)], fill=b)
    pb(d, cx-3, cy-5, 9, 16, h)

    draw_head(d, cx+2, cy-14, 6, SK[0], b)
    pb(d, cx-4, cy-20, 12, 3, h)

    if hurt:
        pb(d, cx+8, cy, 3, 3, RD[1])

    # 左臂推弓
    draw_limb(d, cx-4, cy-2, cx-22, cy-8, b, 3)
    # 弓
    bd = bow_draw  # 0~1 拉弓程度
    for i in range(24):
        angle = math.radians(-70 + i * 5.8)
        px = int(cx - 22 + 16 * math.cos(angle))
        py = int(cy - 8 + 16 * math.sin(angle))
        dot(d, px, py, BR[2])
    # 弦
    d.line([(cx-22, cy-24), (cx-22, cy+8)], fill=(190, 190, 170), width=1)
    pull_x = int(cx + 10 - bd * 4)
    pull_y = cy - 6
    d.line([(cx-22, cy-24), (pull_x, pull_y)], fill=(190, 190, 170), width=1)
    d.line([(cx-22, cy+8), (pull_x, pull_y)], fill=(190, 190, 170), width=1)

    # 右臂拉弦
    draw_limb(d, cx+6, cy-4, pull_x, pull_y, b, 3)
    pb(d, pull_x-2, pull_y-2, 4, 4, SK[0])

    # 箭
    d.line([(cx-18, cy-8), (pull_x+2, pull_y)], fill=(110, 85, 45), width=1)
    pb(d, pull_x+2, pull_y-2, 4, 4, IR[0])

    return img


def draw_cavalry_frame(ox=0, oy=0, leg_phase=0, lance_angle=0, horse_bob=0, hurt=False, dead=False):
    """画一帧骑兵"""
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = P["青铜靛"]
    cx, cy = 30 + ox, 30 + oy
    hb = horse_bob

    if dead:
        # 马倒
        d.polygon([(cx-18, cy+8), (cx+14, cy+4), (cx+16, cy+16), (cx-16, cy+18)], fill=b)
        pb(d, cx-17, cy+9, 30, 8, h)
        draw_head(d, cx-22, cy+12, 5, SK[0], s)
        return img

    # 马身
    d.polygon([(cx-18, cy+6+hb), (cx+14, cy+2+hb), (cx+16, cy+14+hb), (cx-16, cy+16+hb)], fill=b)
    pb(d, cx-17, cy+7+hb, 30, 8, h)
    # 马头
    d.polygon([(cx-24, cy-8+hb), (cx-16, cy-10+hb), (cx-14, cy+2+hb), (cx-22, cy+4+hb)], fill=b)
    pb(d, cx-23, cy-7+hb, 7, 9, h)
    dot(d, cx-21, cy-4+hb, (20, 20, 20))
    pb(d, cx-25, cy-4+hb, 3, 3, s)
    # 马腿
    lk = int(3 * math.sin(leg_phase))
    draw_limb(d, cx-16, cy+14+hb, cx-18+lk, cy+26, s, 3)
    draw_limb(d, cx+12, cy+14+hb, cx+14-lk, cy+26, s, 3)
    pb(d, cx-20+lk, cy+24, 6, 4, dd)
    pb(d, cx+12-lk, cy+24, 6, 4, dd)
    # 马尾
    draw_limb(d, cx+14, cy+6+hb, cx+20, cy-2+hb, s, 3)
    # 马鞍
    pb(d, cx-12, cy+4+hb, 14, 3, BR[2])

    # 骑手
    draw_body(d, cx-10, cy-12+hb, cx+2, cy+6+hb, b)
    pb(d, cx-9, cy-11+hb, 10, 16, h)
    draw_head(d, cx-4, cy-18+hb, 5, SK[0], s)
    pb(d, cx-9, cy-23+hb, 10, 3, dd)
    pb(d, cx-5, cy-26+hb, 2, 4, RD[0])

    if hurt:
        pb(d, cx+2, cy-8+hb, 3, 3, RD[1])

    # 左臂拉缰
    draw_limb(d, cx-10, cy-8+hb, cx-18, cy-2+hb, b, 3)

    # 右臂举枪
    la = math.radians(lance_angle)
    ex = int(cx + 18 * math.cos(la))
    ey = int(cy - 10 + 18 * math.sin(la)) + hb
    draw_limb(d, cx+2, cy-10+hb, ex, ey, b, 3)
    for i in range(22):
        px = int(ex + i * math.cos(la))
        py = int(ey + i * math.sin(la))
        dot(d, px, py, BR[0])
    pb(d, ex + int(22*math.cos(la))-2, ey + int(22*math.sin(la))-2, 4, 4, IR[0])

    return img


def draw_siege_frame(ox=0, oy=0, arm_angle=0, rock_y=0, fire=False, hurt=False, dead=False):
    """画一帧攻城器械（投石车）"""
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = P["水墨黑"]
    cx, cy = 30 + ox, 30 + oy

    if dead:
        # 散架
        pb(d, cx-14, cy+12, 28, 6, BR[2])
        pb(d, cx-10, cy+6, 4, 8, BR[0])
        pb(d, cx+6, cy+4, 4, 10, BR[0])
        pb(d, cx-8, cy+10, 6, 4, IR[2])
        return img

    # 底座
    pb(d, cx-24, cy+12, 48, 10, b)
    pb(d, cx-23, cy+13, 46, 8, h)
    for wx in [cx-20, cx+20]:
        d.ellipse([wx-4, cy+18, wx+4, cy+26], outline=IR[2], width=2)

    # 支架A字
    draw_limb(d, cx-16, cy+12, cx-4, cy-12, BR[0], 3)
    draw_limb(d, cx+16, cy+12, cx+4, cy-12, BR[0], 3)
    draw_limb(d, cx-4, cy-12, cx+4, cy-12, BR[2], 3)

    # 投射臂
    aa = math.radians(arm_angle)
    arm_ex = int(cx + 16 * math.cos(aa))
    arm_ey = int(cy - 10 + 16 * math.sin(aa))
    draw_limb(d, cx, cy-10, arm_ex, arm_ey, BR[0], 3)

    # 配重
    pb(d, cx+2, cy-14, 8, 10, IR[2])
    pb(d, cx+3, cy-13, 6, 8, IR[1])

    if fire and rock_y < 0:
        # 飞出的石弹
        rx = arm_ex + 10
        ry = arm_ey + rock_y
        d.ellipse([rx, ry, rx+6, ry+6], fill=(150, 140, 130))
        d.ellipse([rx+1, ry+1, rx+5, ry+5], fill=(180, 170, 160))
        # 轨迹
        for i in range(4):
            dot(d, rx-3-i*3, ry+2+i, (200, 190, 180))
    else:
        # 投掷兜
        d.line([(arm_ex, arm_ey), (arm_ex-4, arm_ey-2)], fill=s, width=2)

    # 操作兵
    pb(d, cx+22, cy, 6, 12, b)
    pb(d, cx+23, cy-2, 4, 4, SK[0])
    draw_limb(d, cx+22, cy+4, cx+16, cy-2, b, 2)

    return img


def draw_navy_frame(ox=0, oy=0, wave_phase=0, arrow_angle=0, hurt=False, dead=False):
    """画一帧水军（蒙冲）"""
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = N["森林"]
    cx, cy = 30 + ox, 30 + oy
    wy = int(2 * math.sin(wave_phase))

    if dead:
        # 沉船
        d.polygon([(cx-20, cy+10), (cx+20, cy+6), (cx+22, cy+18), (cx-18, cy+20)], fill=BR[2])
        for i in range(6):
            y = cy + 14 + i
            d.line([(cx-22+i, y), (cx+22-i, y)], fill=(60, 100, 150) if i%2==0 else (40, 80, 130), width=1)
        return img

    # 水面
    for i in range(6):
        y = cy + 20 + i + wy
        d.line([(4, y), (60, y)], fill=(40, 80, 130) if i%2==0 else (60, 110, 170), width=1)

    # 船体
    d.polygon([(cx-22, cy+6+wy), (cx+26, cy+2+wy), (cx+28, cy+14+wy), (cx-24, cy+18+wy)], fill=BR[0])
    pb(d, cx-21, cy+7+wy, 46, 6, BR[1])
    # 船头撞角
    pb(d, cx-26, cy+6+wy, 6, 4, IR[0])
    # 蒙皮
    pb(d, cx-16, cy-2+wy, 36, 8, FU[0])
    pb(d, cx-15, cy-1+wy, 34, 6, FU[1])

    if hurt:
        pb(d, cx+10, cy+wy, 3, 3, RD[1])

    # 桅杆
    pb(d, cx, cy-20+wy, 2, 18, BR[2])

    # 弓箭手
    pb(d, cx-18, cy-4+wy, 4, 8, b)
    pb(d, cx-17, cy-6+wy, 3, 3, SK[0])

    return img


# ══════════════════════════════════════════════════════════
#  动画帧生成器
# ══════════════════════════════════════════════════════════

def gen_idle(draw_func, **kwargs):
    """待机 - 微小呼吸晃动"""
    frames = []
    for i in range(NUM_FRAMES):
        t = i / NUM_FRAMES * math.pi * 2
        oy = int(1.5 * math.sin(t))
        frames.append(draw_func(oy=oy, **kwargs))
    return frames

def gen_move(draw_func, speed=1.0, **kwargs):
    """移动 - 行军脚步循环"""
    frames = []
    for i in range(NUM_FRAMES):
        t = i / NUM_FRAMES * math.pi * 2
        leg = t * speed
        oy = int(2 * abs(math.sin(t)))
        ox = int(1 * math.sin(t))
        frames.append(draw_func(ox=ox, oy=-oy, leg_phase=leg, **kwargs))
    return frames

def gen_attack_infantry():
    """步兵攻击 - 矛刺出再收回"""
    frames = []
    angles = [-20, -40, -10, -20]  # 矛角度变化
    for i, a in enumerate(angles):
        t = i / NUM_FRAMES * math.pi * 2
        oy = int(1 * math.sin(t))
        frames.append(draw_infantry_frame(oy=oy, spear_angle=a, leg_phase=0))
    return frames

def gen_attack_archer():
    """弓兵攻击 - 拉弓满月到释放"""
    frames = []
    draws = [0.3, 0.8, 1.0, 0.2]  # 拉弓程度
    for i, bd in enumerate(draws):
        frames.append(draw_archer_frame(bow_draw=bd, leg_phase=0))
    return frames

def gen_attack_cavalry():
    """骑兵攻击 - 枪刺出"""
    frames = []
    angles = [-10, -30, -50, -20]
    bobs = [0, -1, -2, 0]
    for i in range(NUM_FRAMES):
        frames.append(draw_cavalry_frame(
            lance_angle=angles[i], horse_bob=bobs[i], leg_phase=0
        ))
    return frames

def gen_attack_siege():
    """投石车攻击 - 投射臂甩起，石弹飞出"""
    frames = []
    angles = [20, 40, 60, 80]
    fires = [False, False, True, True]
    rock_ys = [0, 0, -10, -20]
    for i in range(NUM_FRAMES):
        frames.append(draw_siege_frame(
            arm_angle=angles[i], fire=fires[i], rock_y=rock_ys[i]
        ))
    return frames

def gen_attack_navy():
    """水军攻击 - 弓箭射出"""
    frames = []
    for i in range(NUM_FRAMES):
        t = i / NUM_FRAMES * math.pi * 2
        wy = int(2 * math.sin(t))
        frames.append(draw_navy_frame(oy=wy, wave_phase=t, arrow_angle=-30))
    return frames

def gen_hurt(draw_func, **kwargs):
    """受击 - 后仰+闪红"""
    frames = []
    offsets = [(0, 0), (2, -2), (1, -1), (0, 0)]
    for i, (ox, oy) in enumerate(offsets):
        frames.append(draw_func(ox=ox, oy=oy, hurt=(i == 1 or i == 2), **kwargs))
    return frames

def gen_death(draw_func, **kwargs):
    """死亡 - 倒下消散"""
    frames = []
    for i in range(NUM_FRAMES):
        if i < 2:
            oy = i * 4
            frames.append(draw_func(oy=oy, **kwargs))
        else:
            frames.append(draw_func(dead=True, **kwargs))
    return frames


# ══════════════════════════════════════════════════════════
#  民兵专用绘制（布衣木棍，与其他兵种不同）
# ══════════════════════════════════════════════════════════

def draw_militia_frame(ox=0, oy=0, leg_phase=0, stick_angle=0, hurt=False, dead=False):
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = P["竹简黄"]
    cx, cy = 30 + ox, 30 + oy

    if dead:
        draw_body(d, cx-12, cy+10, cx+6, cy+22, BR[1])
        pb(d, cx-11, cy+11, 15, 10, BR[0])
        draw_head(d, cx+8, cy+18, 5, SK[0], BR[2])
        return img

    lk = int(3 * math.sin(leg_phase))
    draw_limb(d, cx-2, cy+12, cx-6+lk, cy+26, SK[0], 3)
    draw_limb(d, cx+2, cy+12, cx+6-lk, cy+26, SK[0], 3)
    pb(d, cx-8+lk, cy+24, 5, 3, BR[2])
    pb(d, cx+4-lk, cy+24, 5, 3, BR[2])

    draw_body(d, cx-4, cy-4, cx+4, cy+12, BR[1])
    pb(d, cx-3, cy-3, 7, 14, BR[0])
    pb(d, cx-2, cy+2, 3, 3, BR[2])
    pb(d, cx+1, cy+6, 2, 2, BR[2])

    draw_head(d, cx, cy-10, 5, SK[0], BR[2])
    dot(d, cx-2, cy-9, (20, 20, 20))
    dot(d, cx+2, cy-9, (20, 20, 20))

    if hurt:
        pb(d, cx+4, cy-6, 3, 3, RD[1])

    draw_limb(d, cx-4, cy, cx-10, cy+6, SK[0], 2)

    sa = math.radians(stick_angle)
    sx = int(cx + 18 * math.cos(sa))
    sy = int(cy - 6 + 18 * math.sin(sa))
    draw_limb(d, cx+4, cy-2, sx, sy, SK[0], 2)
    for i in range(18):
        wobble = int(math.sin(i * 0.5) * 1)
        dot(d, sx + int(i*math.cos(sa)) + wobble, sy + int(i*math.sin(sa)), BR[2])

    return img


def draw_militia_idle():
    return gen_idle(draw_militia_frame)

def draw_militia_move():
    return gen_move(draw_militia_frame)

def draw_militia_attack():
    frames = []
    angles = [20, 40, 60, 30]
    for i, a in enumerate(angles):
        t = i / NUM_FRAMES * math.pi * 2
        oy = int(1 * math.sin(t))
        frames.append(draw_militia_frame(oy=oy, stick_angle=a, leg_phase=0))
    return frames

def draw_militia_hurt():
    return gen_hurt(draw_militia_frame)

def draw_militia_death():
    return gen_death(draw_militia_frame)


# ══════════════════════════════════════════════════════════
#  枪刺兵专用绘制（超长矛方阵）
# ══════════════════════════════════════════════════════════

def draw_spear_frame(ox=0, oy=0, leg_phase=0, spear_phase=0, hurt=False, dead=False):
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = P["青铜靛"]
    cx, cy = 30 + ox, 30 + oy

    if dead:
        draw_body(d, cx-12, cy+10, cx+6, cy+22, b)
        pb(d, cx-11, cy+11, 15, 10, h)
        draw_head(d, cx+8, cy+18, 5, SK[0], s)
        for i in range(12):
            dot(d, cx+10+i, cy+14-i//2, BR[0])
        return img

    lk = int(3 * math.sin(leg_phase))
    draw_limb(d, cx-2, cy+12, cx-6+lk, cy+26, s, 4)
    draw_limb(d, cx+2, cy+12, cx+6-lk, cy+26, s, 4)
    pb(d, cx-8+lk, cy+24, 6, 4, dd)
    pb(d, cx+4-lk, cy+24, 6, 4, dd)

    draw_body(d, cx-6, cy-6, cx+6, cy+12, b)
    pb(d, cx-5, cy-5, 11, 16, h)
    pb(d, cx-10, cy-6, 6, 5, dd)
    pb(d, cx+6, cy-6, 6, 5, dd)

    draw_head(d, cx, cy-12, 6, SK[0], s)
    pb(d, cx-6, cy-18, 12, 4, dd)
    pb(d, cx-1, cy-24, 3, 7, RD[0])
    pb(d, cx, cy-26, 2, 3, RD[1])

    if hurt:
        pb(d, cx+6, cy-2, 3, 3, RD[1])

    draw_limb(d, cx-8, cy-2, cx-16, cy+2, b, 3)
    pb(d, cx-18, cy, 4, 4, SK[0])

    # 三根长矛
    sp = spear_phase
    for j, (angle_off, len_mult) in enumerate([(-20, 1.0), (-15, 0.85), (-25, 0.7)]):
        sa = math.radians(angle_off + sp)
        length = int(36 * len_mult)
        for i in range(length):
            px = int(cx + 18 + i * math.cos(sa))
            py = int(cy - 6 + i * math.sin(sa))
            dot(d, px, py, BR[j])
        tip_x = int(cx + 18 + length * math.cos(sa))
        tip_y = int(cy - 6 + length * math.sin(sa))
        pb(d, tip_x-2, tip_y-2, 4, 4, IR[0])

    return img


def draw_spear_idle():
    return gen_idle(draw_spear_frame)

def draw_spear_move():
    return gen_move(draw_spear_frame)

def draw_spear_attack():
    frames = []
    phases = [0, -10, -25, -10]
    for i, sp in enumerate(phases):
        t = i / NUM_FRAMES * math.pi * 2
        oy = int(1 * math.sin(t))
        frames.append(draw_spear_frame(oy=oy, spear_phase=sp, leg_phase=0))
    return frames

def draw_spear_hurt():
    return gen_hurt(draw_spear_frame)

def draw_spear_death():
    return gen_death(draw_spear_frame)


# ══════════════════════════════════════════════════════════
#  斥候专用绘制（弯腰潜行）
# ══════════════════════════════════════════════════════════

def draw_scout_frame(ox=0, oy=0, leg_phase=0, look_phase=0, hurt=False, dead=False):
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = N["森林"]
    cx, cy = 32 + ox, 30 + oy

    if dead:
        d.polygon([(cx-14, cy+10), (cx+4, cy+8), (cx+2, cy+20), (cx-16, cy+22)], fill=b)
        pb(d, cx-13, cy+11, 15, 8, h)
        draw_head(d, cx+6, cy+16, 4, SK[0], s)
        return img

    lk = int(3 * math.sin(leg_phase))
    draw_limb(d, cx, cy+12, cx-10+lk, cy+24, s, 3)
    draw_limb(d, cx+2, cy+12, cx+10-lk, cy+20, s, 3)
    pb(d, cx-12+lk, cy+22, 5, 3, dd)
    pb(d, cx+8-lk, cy+18, 5, 3, dd)

    # 弯腰前倾
    d.polygon([(cx-4, cy-4), (cx+8, cy-6), (cx+6, cy+12), (cx-6, cy+14)], fill=b)
    pb(d, cx-3, cy-3, 9, 14, h)

    # 头（警觉转头）
    lk2 = int(2 * math.sin(look_phase))
    draw_head(d, cx+6+lk2, cy-10, 5, SK[0], s)
    dot(d, cx+8+lk2, cy-10, (20, 20, 20))

    if hurt:
        pb(d, cx+10, cy-4, 3, 3, RD[1])

    draw_limb(d, cx-4, cy, cx-14, cy+8, SK[0], 2)
    pb(d, cx-16, cy+6, 4, 4, SK[0])

    draw_limb(d, cx+6, cy-2, cx+14, cy+4, SK[0], 2)
    pb(d, cx+14, cy+2, 2, 6, IR[0])
    pb(d, cx+13, cy+1, 4, 2, IR[1])

    # 视野标记
    d.ellipse([cx+16, cy-16, cx+22, cy-10], outline=BR[1], width=1)
    dot(d, cx+19, cy-13, BR[0])

    return img


def draw_scout_idle():
    frames = []
    for i in range(NUM_FRAMES):
        t = i / NUM_FRAMES * math.pi * 2
        oy = int(1 * math.sin(t))
        lp = t * 0.5
        frames.append(draw_scout_frame(oy=oy, look_phase=lp))
    return frames

def draw_scout_move():
    frames = []
    for i in range(NUM_FRAMES):
        t = i / NUM_FRAMES * math.pi * 2
        leg = t
        oy = int(2 * abs(math.sin(t)))
        ox = int(1 * math.sin(t))
        lp = t * 0.3
        frames.append(draw_scout_frame(ox=ox, oy=-oy, leg_phase=leg, look_phase=lp))
    return frames

def draw_scout_attack():
    frames = []
    offsets = [0, -4, -6, -2]
    for i, off in enumerate(offsets):
        t = i / NUM_FRAMES * math.pi * 2
        frames.append(draw_scout_frame(ox=off, oy=0, leg_phase=0, look_phase=0))
    return frames

def draw_scout_hurt():
    return gen_hurt(draw_scout_frame)

def draw_scout_death():
    return gen_death(draw_scout_frame)


# ══════════════════════════════════════════════════════════
#  铁甲兵专用绘制（全身重甲）
# ══════════════════════════════════════════════════════════

def draw_heavy_infantry_frame(ox=0, oy=0, leg_phase=0, sword_angle=0, hurt=False, dead=False):
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = P["水墨黑"]
    cx, cy = 30 + ox, 30 + oy

    if dead:
        pb(d, cx-16, cy+8, 30, 14, IR[0])
        pb(d, cx-15, cy+9, 28, 12, IR[1])
        draw_head(d, cx+14, cy+14, 5, SK[0], IR[0])
        return img

    lk = int(2 * math.sin(leg_phase))
    draw_limb(d, cx-4, cy+12, cx-14+lk, cy+26, IR[2], 5)
    draw_limb(d, cx+4, cy+12, cx+14-lk, cy+26, IR[2], 5)
    pb(d, cx-16+lk, cy+24, 8, 4, IR[3])
    pb(d, cx+12-lk, cy+24, 8, 4, IR[3])

    pb(d, cx-14, cy-10, 30, 22, IR[0])
    pb(d, cx-13, cy-9, 28, 20, IR[1])
    for r in range(5):
        pb(d, cx-12, cy-8+r*4, 26, 1, IR[2])
    pb(d, cx-12, cy+8, 26, 4, IR[2])

    pb(d, cx-22, cy-12, 10, 8, IR[2])
    pb(d, cx+14, cy-12, 10, 8, IR[2])

    pb(d, cx-10, cy-26, 22, 14, IR[0])
    pb(d, cx-9, cy-25, 20, 12, IR[1])
    pb(d, cx-8, cy-20, 18, 5, IR[2])
    pb(d, cx-4, cy-19, 10, 2, IR[3])
    dot(d, cx-2, cy-18, SK[1])
    dot(d, cx+4, cy-18, SK[1])
    pb(d, cx, cy-32, 2, 8, RD[0])

    if hurt:
        pb(d, cx+10, cy-10, 3, 3, RD[1])

    draw_limb(d, cx-14, cy-6, cx-28, cy-2, IR[0], 4)
    pb(d, cx-30, cy-12, 14, 28, IR[2])
    pb(d, cx-29, cy-11, 12, 26, IR[1])
    pb(d, cx-25, cy-4, 5, 12, IR[0])

    sa = math.radians(sword_angle)
    ex = int(cx + 18 * math.cos(sa))
    ey = int(cy - 16 + 18 * math.sin(sa))
    draw_limb(d, cx+16, cy-8, ex, ey, IR[0], 4)
    pb(d, ex-2, ey, 4, 14, IR[0])
    pb(d, ex-1, ey-2, 4, 3, IR[1])

    return img


def draw_heavy_infantry_idle():
    return gen_idle(draw_heavy_infantry_frame)

def draw_heavy_infantry_move():
    return gen_move(draw_heavy_infantry_frame, speed=0.7)

def draw_heavy_infantry_attack():
    frames = []
    angles = [-20, -40, -60, -30]
    for i, a in enumerate(angles):
        t = i / NUM_FRAMES * math.pi * 2
        oy = int(1 * math.sin(t))
        frames.append(draw_heavy_infantry_frame(oy=oy, sword_angle=a, leg_phase=0))
    return frames

def draw_heavy_infantry_hurt():
    return gen_hurt(draw_heavy_infantry_frame)

def draw_heavy_infantry_death():
    return gen_death(draw_heavy_infantry_frame)


# ══════════════════════════════════════════════════════════
#  骑兵模板（斥候骑兵 / 护卫骑兵 / 突击骑兵 / 重骑兵）
# ══════════════════════════════════════════════════════════

def draw_cavalry_variant_frame(variant="normal", ox=0, oy=0, leg_phase=0, lance_angle=-10, horse_bob=0, hurt=False, dead=False):
    """骑兵变体：scout=轻骑, normal=标准, shock=突击, heavy=重骑"""
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)

    if variant == "scout":
        b, h, s, dd = N["森林"]
    elif variant == "shock":
        b, h, s, dd = P["漆器红"]
    elif variant == "heavy":
        b, h, s, dd = P["水墨黑"]
    else:
        b, h, s, dd = P["青铜靛"]

    cx, cy = 30 + ox, 30 + oy
    hb = horse_bob

    if dead:
        d.polygon([(cx-18, cy+8+hb), (cx+14, cy+4+hb), (cx+16, cy+16+hb), (cx-16, cy+18+hb)], fill=b)
        pb(d, cx-17, cy+9+hb, 30, 8, h)
        return img

    # 马身
    horse_c = IR[0] if variant == "heavy" else b
    horse_d = IR[1] if variant == "heavy" else h
    d.polygon([(cx-18, cy+6+hb), (cx+14, cy+2+hb), (cx+16, cy+14+hb), (cx-16, cy+16+hb)], fill=horse_c)
    pb(d, cx-17, cy+7+hb, 30, 8, horse_d)

    # 马头
    d.polygon([(cx-24, cy-8+hb), (cx-16, cy-10+hb), (cx-14, cy+2+hb), (cx-22, cy+4+hb)], fill=horse_c)
    pb(d, cx-23, cy-7+hb, 7, 9, horse_d)
    dot(d, cx-21, cy-4+hb, (20, 20, 20))

    # 马铠（重骑）
    if variant == "heavy":
        for i in range(7):
            pb(d, cx-17+i*4, cy+7+hb, 3, 6, IR[2])
        pb(d, cx-25, cy-8+hb, 6, 6, IR[2])

    # 马腿
    lk = int(3 * math.sin(leg_phase))
    speed_mult = 0.7 if variant == "heavy" else 1.0
    draw_limb(d, cx-16, cy+14+hb, cx-18+int(lk*speed_mult), cy+26, s, 3)
    draw_limb(d, cx+12, cy+14+hb, cx+14-int(lk*speed_mult), cy+26, s, 3)
    draw_limb(d, cx+8, cy+14+hb, cx+10+int(lk*speed_mult), cy+26, s, 3)
    draw_limb(d, cx+14, cy+14+hb, cx+16-int(lk*speed_mult), cy+26, s, 3)

    # 马尾
    draw_limb(d, cx+14, cy+6+hb, cx+20, cy-2+hb, s, 3)
    # 马鞍
    pb(d, cx-12, cy+4+hb, 14, 3, BR[2])

    # 骑手
    draw_body(d, cx-10, cy-12+hb, cx+2, cy+6+hb, b)
    pb(d, cx-9, cy-11+hb, 10, 16, h)
    draw_head(d, cx-4, cy-18+hb, 5, SK[0], s)

    if variant == "heavy":
        pb(d, cx-9, cy-23+hb, 10, 3, IR[1])
        pb(d, cx-5, cy-26+hb, 2, 4, RD[0])
        pb(d, cx-8, cy-18+hb, 8, 4, IR[2])
    elif variant == "scout":
        pb(d, cx+2, cy-20+hb, 8, 2, s)
        pb(d, cx+6, cy-22+hb, 6, 2, dd)
    else:
        pb(d, cx-9, cy-23+hb, 10, 3, dd)
        pb(d, cx-5, cy-26+hb, 2, 4, RD[0])

    if hurt:
        pb(d, cx+2, cy-8+hb, 3, 3, RD[1])

    # 左臂
    draw_limb(d, cx-10, cy-8+hb, cx-18, cy-2+hb, b, 3)

    # 右臂
    la = math.radians(lance_angle)
    arm_len = 18 if variant != "heavy" else 20
    ex = int(cx + arm_len * math.cos(la))
    ey = int(cy - 10 + arm_len * math.sin(la)) + hb
    draw_limb(d, cx+2, cy-10+hb, ex, ey, b, 3)

    # 武器
    if variant == "scout":
        pb(d, ex, ey, 2, 5, IR[0])
    elif variant in ("normal", "shock"):
        for i in range(22):
            dot(d, ex + int(i*math.cos(la)), ey + int(i*math.sin(la)), BR[0])
        pb(d, ex + int(22*math.cos(la))-2, ey + int(22*math.sin(la))-2, 4, 4, IR[0])
    elif variant == "heavy":
        for i in range(20):
            dot(d, ex + int(i*math.cos(la)), ey + int(i*math.sin(la)), BR[0])
        pb(d, ex + int(20*math.cos(la))-2, ey + int(20*math.sin(la))-2, 5, 5, IR[1])

    return img


def make_cavalry_anim(variant):
    """为指定骑兵变体生成动画集"""
    def idle():
        frames = []
        for i in range(NUM_FRAMES):
            t = i / NUM_FRAMES * math.pi * 2
            hb = int(1 * math.sin(t))
            frames.append(draw_cavalry_variant_frame(variant, horse_bob=hb))
        return frames

    def move():
        frames = []
        for i in range(NUM_FRAMES):
            t = i / NUM_FRAMES * math.pi * 2
            leg = t
            hb = int(2 * abs(math.sin(t)))
            ox = int(1 * math.sin(t))
            frames.append(draw_cavalry_variant_frame(variant, ox=ox, oy=-hb, leg_phase=leg, horse_bob=0))
        return frames

    def attack():
        frames = []
        angles = [-10, -30, -50, -20]
        bobs = [0, -1, -2, 0]
        for i in range(NUM_FRAMES):
            frames.append(draw_cavalry_variant_frame(variant, lance_angle=angles[i], horse_bob=bobs[i]))
        return frames

    def hurt():
        frames = []
        offsets = [(0, 0), (2, -2), (1, -1), (0, 0)]
        for i, (ox, oy) in enumerate(offsets):
            frames.append(draw_cavalry_variant_frame(variant, ox=ox, oy=oy, hurt=(i in (1, 2))))
        return frames

    def death():
        frames = []
        for i in range(NUM_FRAMES):
            if i < 2:
                frames.append(draw_cavalry_variant_frame(variant, oy=i*4))
            else:
                frames.append(draw_cavalry_variant_frame(variant, dead=True))
        return frames

    return idle, move, attack, hurt, death


# ══════════════════════════════════════════════════════════
#  弩兵 / 弓骑兵绘制
# ══════════════════════════════════════════════════════════

def draw_crossbow_frame(ox=0, oy=0, leg_phase=0, draw_phase=0, hurt=False, dead=False):
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = P["青铜靛"]
    cx, cy = 30 + ox, 30 + oy

    if dead:
        draw_body(d, cx-12, cy+10, cx+6, cy+22, b)
        pb(d, cx-11, cy+11, 15, 10, h)
        draw_head(d, cx+8, cy+18, 5, SK[0], s)
        return img

    lk = int(3 * math.sin(leg_phase))
    draw_limb(d, cx-2, cy+12, cx-12+lk, cy+20, s, 4)
    draw_limb(d, cx+2, cy+12, cx+12-lk, cy+22, s, 4)
    pb(d, cx-14+lk, cy+18, 6, 4, dd)
    pb(d, cx+10-lk, cy+20, 6, 4, dd)

    draw_body(d, cx-6, cy-6, cx+6, cy+12, b)
    pb(d, cx-5, cy-5, 11, 16, h)
    draw_head(d, cx, cy-12, 5, SK[0], s)

    if hurt:
        pb(d, cx+6, cy-4, 3, 3, RD[1])

    # 左臂托弩
    draw_limb(d, cx-8, cy-2, cx-22, cy-6, b, 3)
    pb(d, cx-24, cy-8, 4, 4, SK[0])

    # 弩身
    pb(d, cx-28, cy-10, 24, 3, BR[0])
    pb(d, cx-27, cy-9, 22, 1, BR[1])
    pb(d, cx-30, cy-14, 4, 6, BR[0])
    pb(d, cx-6, cy-14, 4, 6, BR[0])

    # 弦（拉弦动画）
    dp = draw_phase  # 0~1
    pull = int(dp * 8)
    d.line([(cx-29, cy-14), (cx-29, cy-4)], fill=(190, 190, 170), width=1)
    d.line([(cx-3, cy-14), (cx-3, cy-4)], fill=(190, 190, 170), width=1)

    # 箭
    pb(d, cx-28, cy-8-pull, 22, 1, (110, 85, 45))
    pb(d, cx-6, cy-9-pull, 3, 3, IR[0])

    # 扳机
    pb(d, cx-16, cy-7, 4, 4, IR[2])

    # 右手扣扳机
    draw_limb(d, cx+6, cy-2, cx-12, cy-4, SK[0], 2)

    return img


def draw_horse_archer_frame(ox=0, oy=0, leg_phase=0, bow_draw=0, horse_bob=0, hurt=False, dead=False):
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = P["竹简黄"]
    cx, cy = 30 + ox, 30 + oy
    hb = horse_bob

    if dead:
        d.polygon([(cx-18, cy+8+hb), (cx+14, cy+4+hb), (cx+16, cy+16+hb), (cx-16, cy+18+hb)], fill=b)
        pb(d, cx-17, cy+9+hb, 30, 8, h)
        return img

    # 马
    d.polygon([(cx-18, cy+6+hb), (cx+14, cy+2+hb), (cx+16, cy+14+hb), (cx-16, cy+16+hb)], fill=b)
    pb(d, cx-17, cy+7+hb, 30, 8, h)
    d.polygon([(cx-24, cy-8+hb), (cx-16, cy-10+hb), (cx-14, cy+2+hb), (cx-22, cy+4+hb)], fill=b)
    pb(d, cx-23, cy-7+hb, 7, 9, h)
    dot(d, cx-21, cy-4+hb, (20, 20, 20))

    lk = int(3 * math.sin(leg_phase))
    draw_limb(d, cx-16, cy+14+hb, cx-18+lk, cy+26, s, 3)
    draw_limb(d, cx+12, cy+14+hb, cx+14-lk, cy+26, s, 3)
    draw_limb(d, cx+14, cy+6+hb, cx+20, cy-2+hb, s, 3)
    pb(d, cx-12, cy+4+hb, 12, 3, BR[1])

    # 骑手侧坐
    d.polygon([(cx-8, cy-12+hb), (cx+4, cy-14+hb), (cx+2, cy+4+hb), (cx-10, cy+6+hb)], fill=b)
    pb(d, cx-7, cy-11+hb, 9, 14, h)
    draw_head(d, cx+2, cy-18+hb, 5, SK[0], s)
    pb(d, cx-3, cy-23+hb, 10, 4, FU[0])
    pb(d, cx, cy-26+hb, 4, 4, FU[1])

    if hurt:
        pb(d, cx+4, cy-10+hb, 3, 3, RD[1])

    # 右臂拉弓
    bd = bow_draw
    draw_limb(d, cx+2, cy-8+hb, cx+18, cy-14+hb, b, 3)
    for i in range(16):
        angle = math.radians(-60 + i * 7.5)
        px = int(cx + 20 + 12 * math.cos(angle))
        py = int(cy - 14 + hb + 12 * math.sin(angle))
        dot(d, px, py, BR[2])
    d.line([(cx+20, cy-24+hb), (cx+20, cy-4+hb)], fill=(190, 190, 170), width=1)
    pull_x = cx + 16 - int(bd * 4)
    pull_y = cy - 14 + hb
    d.line([(cx+20, cy-24+hb), (pull_x, pull_y)], fill=(190, 190, 170), width=1)
    d.line([(cx+20, cy-4+hb), (pull_x, pull_y)], fill=(190, 190, 170), width=1)
    d.line([(cx+6, cy-12+hb), (pull_x+2, pull_y)], fill=(110, 85, 45), width=1)
    pb(d, pull_x+2, pull_y-2, 4, 4, IR[0])

    # 左手缰绳
    draw_limb(d, cx-8, cy-6+hb, cx-18, cy+0+hb, SK[0], 2)

    return img


# ══════════════════════════════════════════════════════════
#  攻城模板（冲车 / 弩炮）
# ══════════════════════════════════════════════════════════

def draw_battering_ram_frame(ox=0, oy=0, ram_phase=0, push_phase=0, hurt=False, dead=False):
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = P["漆器红"]
    cx, cy = 30 + ox, 30 + oy
    rp = int(3 * math.sin(ram_phase))

    if dead:
        pb(d, cx-14, cy+12, 28, 6, BR[2])
        pb(d, cx-10, cy+6, 4, 8, BR[0])
        pb(d, cx+6, cy+4, 4, 10, BR[0])
        return img

    # 车轮
    for wx in [cx-16, cx+16]:
        d.ellipse([wx-6, cy+14, wx+6, cy+26], outline=BR[2], width=2)
        dot(d, wx, cy+20, BR[0])

    # 车身
    pb(d, cx-22, cy+8, 44, 8, BR[0])
    pb(d, cx-21, cy+9, 42, 6, BR[1])

    # 防护顶棚
    pb(d, cx-20, cy-8, 38, 4, BR[2])
    pb(d, cx-18, cy-12, 34, 4, BR[0])

    # 撞杆
    pb(d, cx-30+rp, cy, 16, 4, BR[2])
    pb(d, cx-29+rp, cy+1, 14, 2, BR[0])
    # 撞角
    pb(d, cx-34+rp, cy-2, 6, 8, IR[0])
    pb(d, cx-33+rp, cy-1, 4, 6, IR[1])
    pb(d, cx-36+rp, cy, 3, 4, IR[2])

    if hurt:
        pb(d, cx+10, cy, 3, 3, RD[1])

    # 推车士兵
    pp = int(2 * math.sin(push_phase))
    for sx, sy in [(cx+22, cy), (cx+26, cy+2)]:
        pb(d, sx+pp, sy, 5, 10, b)
        pb(d, sx+1+pp, sy-2, 3, 3, SK[0])
        draw_limb(d, sx+pp, sy+4, sx-4+pp, sy+6, SK[0], 2)

    return img


def draw_siege_crossbow_frame(ox=0, oy=0, draw_phase=0, recoil=0, hurt=False, dead=False):
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = N["山地"]
    cx, cy = 30 + ox, 30 + oy

    if dead:
        pb(d, cx-14, cy+12, 28, 6, IR[0])
        pb(d, cx-10, cy+6, 4, 8, BR[0])
        return img

    # 底座
    pb(d, cx-22, cy+14, 44, 8, IR[0])
    pb(d, cx-21, cy+15, 42, 6, IR[1])
    for wx in [cx-18, cx+18]:
        d.ellipse([wx-4, cy+18, wx+4, cy+26], outline=IR[2], width=2)

    # 支架
    pb(d, cx-2, cy-10, 8, 24, IR[0])
    d.ellipse([cx-6, cy+10, cx+10, cy+16], outline=IR[2], width=2)

    # 弩臂（带后坐力震动）
    rc = int(recoil * 2)
    pb(d, cx-28+rc, cy-6, 28, 4, BR[0])
    pb(d, cx+4-rc, cy-6, 28, 4, BR[0])

    # 弦
    d.line([(cx-26+rc, cy-6), (cx-26+rc, cy+2)], fill=(190, 190, 170), width=1)
    d.line([(cx+30-rc, cy-6), (cx+30-rc, cy+2)], fill=(190, 190, 170), width=1)

    # 导轨
    pb(d, cx-14, cy-2, 32, 4, BR[2])

    # 巨箭
    dp = draw_phase
    arrow_pull = int(dp * 6)
    pb(d, cx-26+rc, cy-4-arrow_pull, 50, 2, (110, 85, 45))
    pb(d, cx+24-rc, cy-6-arrow_pull, 6, 6, IR[0])

    if hurt:
        pb(d, cx+10, cy-4, 3, 3, RD[1])

    # 瞄准器
    pb(d, cx, cy-10, 4, 5, BR[1])
    # 绞盘
    pb(d, cx-8, cy+4, 18, 8, IR[2])
    pb(d, cx-6, cy+5, 14, 6, IR[1])

    # 操作兵
    pb(d, cx-28, cy+4, 6, 12, b)
    pb(d, cx-27, cy+2, 4, 4, SK[0])
    draw_limb(d, cx-22, cy+8, cx-16, cy+6, b, 2)

    return img


# ══════════════════════════════════════════════════════════
#  水军模板（大翼 / 楼船）
# ══════════════════════════════════════════════════════════

def draw_dayi_frame(ox=0, oy=0, wave_phase=0, hurt=False, dead=False):
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = N["森林"]
    cx, cy = 30 + ox, 30 + oy
    wy = int(2 * math.sin(wave_phase))

    if dead:
        d.polygon([(cx-26, cy+10+wy), (cx+28, cy+6+wy), (cx+30, cy+20+wy), (cx-24, cy+22+wy)], fill=BR[2])
        return img

    for i in range(6):
        y = cy + 20 + i + wy
        d.line([(2, y), (62, y)], fill=(40, 80, 130) if i%2==0 else (60, 110, 170), width=1)

    d.polygon([(cx-26, cy+4+wy), (cx+28, cy+0+wy), (cx+30, cy+16+wy), (cx-24, cy+18+wy)], fill=BR[0])
    pb(d, cx-25, cy+5+wy, 52, 8, BR[1])
    pb(d, cx-28, cy+4+wy, 5, 5, BR[2])
    pb(d, cx-30, cy+2+wy, 3, 3, RD[0])

    pb(d, cx-22, cy-2+wy, 48, 4, BR[2])
    for cx2 in [cx-16, cx-2, cx+12]:
        pb(d, cx2, cy-8+wy, 10, 8, BR[2])
        pb(d, cx2+1, cy-7+wy, 8, 6, BR[1])
        pb(d, cx2+3, cy-6+wy, 3, 3, IR[2])

    pb(d, cx, cy-20+wy, 3, 18, BR[2])
    pb(d, cx-12, cy-14+wy, 14, 12, s)

    if hurt:
        pb(d, cx+10, cy+2+wy, 3, 3, RD[1])

    for ox2 in [cx-14, cx-6, cx+6, cx+14]:
        draw_limb(d, ox2, cy+6+wy, ox2-6, cy+14+wy, BR[2], 2)

    return img


def draw_louchuan_frame(ox=0, oy=0, wave_phase=0, hurt=False, dead=False):
    img = Image.new("RGBA", (SZ, SZ), BG)
    d = ImageDraw.Draw(img)
    b, h, s, dd = N["森林"]
    cx, cy = 30 + ox, 30 + oy
    wy = int(2 * math.sin(wave_phase))

    if dead:
        d.polygon([(cx-28, cy+10+wy), (cx+30, cy+6+wy), (cx+32, cy+22+wy), (cx-26, cy+24+wy)], fill=BR[2])
        return img

    for i in range(4):
        y = cy + 22 + i + wy
        d.line([(0, y), (63, y)], fill=(40, 80, 130) if i%2==0 else (60, 110, 170), width=1)

    d.polygon([(cx-28, cy+8+wy), (cx+30, cy+4+wy), (cx+32, cy+20+wy), (cx-26, cy+22+wy)], fill=BR[0])
    pb(d, cx-27, cy+9+wy, 56, 10, BR[1])
    pb(d, cx-30, cy+8+wy, 5, 6, IR[0])

    # 三层
    pb(d, cx-24, cy+4+wy, 50, 6, BR[2])
    pb(d, cx-20, cy-4+wy, 42, 8, BR[2])
    pb(d, cx-12, cy-12+wy, 26, 8, BR[2])

    # 指挥舱
    pb(d, cx-8, cy-18+wy, 18, 6, BR[2])
    pb(d, cx, cy-24+wy, 3, 12, BR[2])
    pb(d, cx-12, cy-22+wy, 12, 10, s)

    # 战旗
    pb(d, cx+2, cy-28+wy, 4, 3, RD[0])

    if hurt:
        pb(d, cx+10, cy+wy, 3, 3, RD[1])

    return img


# ══════════════════════════════════════════════════════════
#  通用动画生成器
# ══════════════════════════════════════════════════════════

def make_standard_anim_set(draw_func, attack_func, move_speed=1.0, **extra_kwargs):
    """为一个绘制函数生成标准 5 套动画"""
    def idle():
        return gen_idle(draw_func, **extra_kwargs)

    def move():
        return gen_move(draw_func, speed=move_speed, **extra_kwargs)

    def attack():
        return attack_func()

    def hurt():
        return gen_hurt(draw_func, **extra_kwargs)

    def death():
        return gen_death(draw_func, **extra_kwargs)

    return idle, move, attack, hurt, death


def make_bob_anim_set(draw_func, attack_func, bob_param="oy", **extra_kwargs):
    """为没有腿的单位（攻城/水军）生成简化动画，用上下晃动代替移动"""
    def idle():
        frames = []
        for i in range(NUM_FRAMES):
            t = i / NUM_FRAMES * math.pi * 2
            val = int(1.5 * math.sin(t))
            frames.append(draw_func(**{bob_param: val}, **extra_kwargs))
        return frames

    def move():
        frames = []
        for i in range(NUM_FRAMES):
            t = i / NUM_FRAMES * math.pi * 2
            val = int(3 * math.sin(t))
            frames.append(draw_func(**{bob_param: val}, **extra_kwargs))
        return frames

    def attack():
        return attack_func()

    def hurt():
        frames = []
        offsets = [(0, 0), (2, -2), (1, -1), (0, 0)]
        for i, (ox, oy) in enumerate(offsets):
            frames.append(draw_func(ox=ox, oy=oy, hurt=(i in (1, 2)), **extra_kwargs))
        return frames

    def death():
        frames = []
        for i in range(NUM_FRAMES):
            if i < 2:
                frames.append(draw_func(oy=i*4, **extra_kwargs))
            else:
                frames.append(draw_func(dead=True, **extra_kwargs))
        return frames

    return idle, move, attack, hurt, death


# ══════════════════════════════════════════════════════════
#  主函数
# ══════════════════════════════════════════════════════════

def generate_all():
    print("=== 《山河策》兵种动画生成器 ===\n")

    anim_sets = {
        # ── 步兵类 ──
        "unit_militia":        (draw_militia_idle, draw_militia_move, draw_militia_attack, draw_militia_hurt, draw_militia_death),
        "unit_infantry":       make_standard_anim_set(draw_infantry_frame, gen_attack_infantry),
        "unit_spear":          (draw_spear_idle, draw_spear_move, draw_spear_attack, draw_spear_hurt, draw_spear_death),
        "unit_scout":          (draw_scout_idle, draw_scout_move, draw_scout_attack, draw_scout_hurt, draw_scout_death),
        "unit_heavy_infantry": (draw_heavy_infantry_idle, draw_heavy_infantry_move, draw_heavy_infantry_attack, draw_heavy_infantry_hurt, draw_heavy_infantry_death),

        # ── 骑兵类 ──
        "unit_scout_cavalry":  make_cavalry_anim("scout"),
        "unit_cavalry":        make_cavalry_anim("normal"),
        "unit_chariot":        make_standard_anim_set(
            lambda **kw: draw_cavalry_frame(**kw),
            gen_attack_cavalry
        ),
        "unit_shock_cavalry":  make_cavalry_anim("shock"),
        "unit_heavy_cavalry":  make_cavalry_anim("heavy"),

        # ── 弓兵类 ──
        "unit_archer":         make_standard_anim_set(draw_archer_frame, gen_attack_archer),
        "unit_crossbow":       make_standard_anim_set(draw_crossbow_frame, lambda: gen_idle(draw_crossbow_frame)),
        "unit_horse_archer":   make_standard_anim_set(
            lambda **kw: draw_horse_archer_frame(**kw),
            lambda: gen_idle(draw_horse_archer_frame)
        ),

        # ── 攻城类 ──
        "unit_battering_ram":  make_bob_anim_set(
            draw_battering_ram_frame,
            lambda: gen_idle(draw_battering_ram_frame)
        ),
        "unit_catapult":       make_bob_anim_set(draw_siege_frame, gen_attack_siege),
        "unit_siege_crossbow": make_bob_anim_set(
            draw_siege_crossbow_frame,
            lambda: gen_idle(draw_siege_crossbow_frame)
        ),

        # ── 水军类 ──
        "unit_mengchong":      make_bob_anim_set(
            draw_navy_frame,
            gen_attack_navy
        ),
        "unit_dayi":           make_bob_anim_set(
            draw_dayi_frame,
            lambda: gen_idle(draw_dayi_frame)
        ),
        "unit_louchuan":       make_bob_anim_set(
            draw_louchuan_frame,
            lambda: gen_idle(draw_louchuan_frame)
        ),

        # ── 七国特色兵种（复用基础模板，用不同调色板） ──
        "unit_qin_ruishi":     make_standard_anim_set(draw_heavy_infantry_frame, draw_heavy_infantry_attack),
        "unit_zhao_hufu":      make_cavalry_anim("normal"),
        "unit_qi_jiji":        make_standard_anim_set(draw_infantry_frame, gen_attack_infantry),
        "unit_chu_shenxi":     make_standard_anim_set(draw_infantry_frame, gen_attack_infantry),
        "unit_wei_wuzu":       make_standard_anim_set(draw_crossbow_frame, lambda: gen_idle(draw_crossbow_frame)),
        "unit_yan_liaodong":   make_cavalry_anim("scout"),
        "unit_han_jingnu":     make_bob_anim_set(draw_siege_crossbow_frame, lambda: gen_idle(draw_siege_crossbow_frame)),
    }

    anim_names = ["idle", "move", "attack", "hurt", "death"]
    total = 0

    for unit_name, (idle_f, move_f, attack_f, hurt_f, death_f) in anim_sets.items():
        unit_dir = os.path.join(OUT_DIR, unit_name)
        os.makedirs(unit_dir, exist_ok=True)

        for anim_name, anim_func in zip(anim_names, [idle_f, move_f, attack_f, hurt_f, death_f]):
            frames = anim_func()
            sheet = Image.new("RGBA", (FRAME_W * len(frames), FRAME_H), BG)
            for i, frame in enumerate(frames):
                sheet.paste(frame, (i * FRAME_W, 0))
            # 放大到 1024x1024/帧
            scale_w = FRAME_W * len(frames) * 16
            scale_h = FRAME_H * 16
            sheet = sheet.resize((scale_w, scale_h), Image.NEAREST)
            path = os.path.join(unit_dir, f"{anim_name}.png")
            sheet.save(path)
            total += 1

        print(f"  [OK] {unit_name}/ (5 animations)")

    print(f"\n=== 完成: {len(anim_sets)} 兵种 x 5 动画 = {total} 个精灵表 ===")
    print(f"输出目录: {OUT_DIR}")
    print("每个精灵表 4 帧水平排列，1024x1024/帧")

if __name__ == "__main__":
    generate_all()
