"""
《山河策》战斗特效动画生成器
每种特效 8 帧 | 64×64 像素绘制 → 1024×1024 输出 | 透明背景
运行: python generate_effect_animations.py
"""

import os, math, random
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "effects_animations")
os.makedirs(OUT_DIR, exist_ok=True)

W, H = 64, 64
NUM_FRAMES = 8
SCALE = 16
TRANSPARENT = (0, 0, 0, 0)


def new_frame():
    return Image.new("RGBA", (W, H), TRANSPARENT)


def dot(d, x, y, c, size=1):
    for dx in range(-size + 1, size):
        for dy in range(-size + 1, size):
            px, py = x + dx, y + dy
            if 0 <= px < W and 0 <= py < H:
                d.point((px, py), fill=c)


def save_effect(name, frames):
    effect_dir = os.path.join(OUT_DIR, name)
    os.makedirs(effect_dir, exist_ok=True)
    for i, frame in enumerate(frames):
        big = frame.resize((W * SCALE, H * SCALE), Image.NEAREST)
        big.save(os.path.join(effect_dir, f"{name}_{i + 1:02d}.png"))
    print(f"  [OK] {name}/ ({len(frames)} frames)")


# ── 1. 箭雨 ──────────────────────────────────────────

def gen_arrow_rain():
    frames = []
    random.seed(42)
    arrows = [(random.randint(8, 56), random.randint(-20, 10),
               random.randint(6, 12), random.uniform(0.6, 1.2))
              for _ in range(20)]
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        t = f / (NUM_FRAMES - 1)
        for ax, base_y, length, speed in arrows:
            ay = base_y + int(t * speed * 60)
            if -5 <= ay < H + 5:
                angle = math.radians(85 + random.randint(-5, 5))
                for s in range(length):
                    px = int(ax + s * math.cos(angle))
                    py = int(ay + s * math.sin(angle))
                    if 0 <= px < W and 0 <= py < H:
                        c = (139, 90, 43, 220) if s < length - 3 else (180, 180, 185, 240)
                        d.point((px, py), fill=c)
                # arrowhead
                tip_x = int(ax + length * math.cos(angle))
                tip_y = int(ay + length * math.sin(angle))
                dot(d, tip_x, tip_y, (200, 200, 210, 255))
        # ground impact marks
        if f > 4:
            random.seed(42 + f)
            for _ in range(f - 3):
                gx = random.randint(5, 59)
                gy = random.randint(52, 60)
                dot(d, gx, gy, (100, 80, 50, 150))
        frames.append(img)
    return frames


# ── 2. 火焰 ──────────────────────────────────────────

def gen_fire():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        phase = f * 0.5
        for layer in range(6):
            base_y = 54 - layer * 6
            flicker = int(math.sin(phase + layer * 0.7) * 3)
            cx = 32 + flicker
            w = 16 - layer * 2
            h = 10 - layer
            if w > 0 and h > 0:
                alphas = [180, 200, 210, 220, 230, 200]
                colors = [
                    (255, 255, 120), (255, 210, 60), (255, 160, 40),
                    (255, 100, 25), (220, 60, 15), (180, 40, 10),
                ]
                d.ellipse([cx - w, base_y - h, cx + w, base_y + h],
                          fill=(*colors[layer], alphas[layer]))
        # sparks
        random.seed(42 + f)
        for _ in range(2 + f):
            sx = random.randint(18, 46)
            sy = random.randint(8, 35)
            dot(d, sx, sy, (255, 240, 180, 200))
        # embers floating up
        for i in range(f):
            ex = 24 + (i * 11) % 20
            ey = 20 - i * 3
            if 0 <= ey < H:
                dot(d, ex, ey, (255, 180, 60, 160 - i * 15))
        frames.append(img)
    return frames


# ── 3. 爆炸 ──────────────────────────────────────────

def gen_explosion():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        t = f / (NUM_FRAMES - 1)
        cx, cy = 32, 32
        # expanding shockwave
        radius = int(t * 28)
        if radius > 1:
            alpha = max(60, 220 - int(t * 180))
            d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                      fill=(255, 200, 50, alpha))
            inner = max(1, radius - 4)
            d.ellipse([cx - inner, cy - inner, cx + inner, cy + inner],
                      fill=(255, 255, 200, alpha))
        # debris flying outward
        random.seed(42 + f)
        n_debris = 3 + f * 3
        for _ in range(n_debris):
            angle = random.uniform(0, math.tau)
            dist = random.randint(3, radius + 12)
            dx = cx + int(dist * math.cos(angle))
            dy = cy + int(dist * math.sin(angle))
            c = random.choice([(200, 150, 80), (180, 130, 60), (220, 170, 100)])
            dot(d, dx, dy, (*c, alpha if radius > 1 else 200), size=random.choice([1, 2]))
        # smoke ring
        if f > 3:
            smoke_r = int((f - 3) * 5)
            smoke_a = max(30, 100 - (f - 3) * 15)
            for i in range(0, 360, 15):
                rad = math.radians(i)
                sx = cx + int(smoke_r * math.cos(rad))
                sy = cy + int(smoke_r * math.sin(rad))
                dot(d, sx, sy, (100, 90, 80, smoke_a), size=2)
        frames.append(img)
    return frames


# ── 4. 冲锋 ──────────────────────────────────────────

def gen_charge():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        t = f / (NUM_FRAMES - 1)
        hx = int(8 + t * 42)
        hy = 36
        # horse body
        d.polygon([(hx, hy), (hx + 14, hy - 10), (hx + 14, hy + 6)],
                  fill=(80, 60, 40, 230))
        # horse head
        d.polygon([(hx + 12, hy - 10), (hx + 18, hy - 16), (hx + 16, hy - 6)],
                  fill=(90, 70, 45, 230))
        # legs animation
        leg_offset = int(math.sin(f * 1.2) * 3)
        d.line([(hx + 3, hy + 6), (hx + 3 + leg_offset, hy + 14)], fill=(70, 50, 35, 220), width=1)
        d.line([(hx + 10, hy + 6), (hx + 10 - leg_offset, hy + 14)], fill=(70, 50, 35, 220), width=1)
        # lance
        d.line([(hx + 14, hy - 6), (hx + 28, hy - 16)], fill=(180, 180, 190, 255), width=1)
        dot(d, hx + 28, hy - 16, (200, 200, 210, 255))
        # rider
        d.rectangle([hx + 6, hy - 18, hx + 10, hy - 8], fill=(120, 40, 30, 220))
        dot(d, hx + 8, hy - 20, (200, 180, 150, 230), size=2)
        # dust trail
        if f > 1:
            for i in range(f):
                dx = hx - 2 - i * 4
                dy = hy + 12 + random.randint(-1, 1)
                if 0 <= dx < W:
                    dot(d, dx, dy, (160, 140, 110, 140 - i * 15), size=2)
        # speed lines
        if f > 2:
            for j in range(3):
                lx = hx - 2 - j * 3
                ly = hy - 6 + j * 5
                if 0 <= lx - 5 < W:
                    d.line([(lx, ly), (lx - 5, ly)], fill=(200, 190, 170, 100))
        frames.append(img)
    return frames


# ── 5. 斩击 ──────────────────────────────────────────

def gen_slash():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        t = f / (NUM_FRAMES - 1)
        # sword arc sweeping
        start_a = -90
        end_a = start_a + int(t * 200)
        for a in range(start_a, end_a, 3):
            rad = math.radians(a)
            r = 18 + int(math.sin(a * 0.1) * 3)
            sx = 32 + int(r * math.cos(rad))
            sy = 32 + int(r * math.sin(rad))
            brightness = 200 + int(55 * (1 - abs(a - start_a - (end_a - start_a) / 2) / ((end_a - start_a) / 2 + 1)))
            dot(d, sx, sy, (brightness, brightness, 255, 220))
        # blade trail glow
        if f > 0:
            trail_alpha = max(60, 200 - f * 20)
            for a in range(start_a, end_a, 6):
                rad = math.radians(a)
                r = 16
                sx = 32 + int(r * math.cos(rad))
                sy = 32 + int(r * math.sin(rad))
                dot(d, sx, sy, (255, 255, 255, trail_alpha), size=2)
        # spark at impact point
        if f >= 4:
            impact_t = (f - 4) / 3
            spark_a = math.radians(end_a)
            spark_r = 18
            ix = 32 + int(spark_r * math.cos(spark_a))
            iy = 32 + int(spark_r * math.sin(spark_a))
            random.seed(42 + f)
            for _ in range((f - 3) * 3):
                sa = random.uniform(0, math.tau)
                sd = random.randint(2, 8)
                sx = ix + int(sd * math.cos(sa))
                sy = iy + int(sd * math.sin(sa))
                dot(d, sx, sy, (255, 240, 180, 200 - int(impact_t * 150)))
        frames.append(img)
    return frames


# ── 6. 格挡 ──────────────────────────────────────────

def gen_shield_block():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        t = f / (NUM_FRAMES - 1)
        # shield
        shield_alpha = 240 if f < 6 else max(100, 240 - (f - 6) * 70)
        d.ellipse([22, 20, 42, 50], fill=(100, 85, 55, shield_alpha), outline=(160, 140, 90, shield_alpha))
        d.ellipse([27, 28, 37, 42], fill=(140, 120, 70, shield_alpha))
        # impact sparks
        if 1 <= f <= 5:
            spark_alpha = 255 - (f - 1) * 40
            random.seed(42)
            for _ in range(4 + f * 3):
                sa = random.uniform(0, math.tau)
                sd = random.randint(6, 14 + f * 2)
                sx = 32 + int(sd * math.cos(sa))
                sy = 35 + int(sd * math.sin(sa))
                c = random.choice([(255, 240, 150), (255, 200, 80)])
                dot(d, sx, sy, (*c, spark_alpha))
        # shockwave ring
        if 1 <= f <= 4:
            ring_r = int(f * 6)
            ring_a = max(40, 160 - f * 30)
            for i in range(0, 360, 8):
                rad = math.radians(i)
                rx = 32 + int(ring_r * math.cos(rad))
                ry = 35 + int(ring_r * math.sin(rad))
                dot(d, rx, ry, (220, 220, 240, ring_a))
        # shield push motion
        if f < 3:
            push = 2 - f
            d.rectangle([22 - push, 20, 42 - push, 50], outline=(180, 160, 120, 100))
        frames.append(img)
    return frames


# ── 7. 治疗 ──────────────────────────────────────────

def gen_heal():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        t = f / (NUM_FRAMES - 1)
        # rising green particles
        random.seed(42)
        for i in range(12):
            px = 16 + (i * 5) % 32
            base_y = 55 - i * 2
            py = base_y - int(t * 35)
            alpha = max(40, 200 - int(t * 160))
            if 0 <= py < H:
                c = random.choice([(100, 255, 100), (80, 220, 80), (130, 255, 130)])
                dot(d, px, py, (*c, alpha), size=2)
        # healing cross
        if f < 6:
            cx, cy = 32, 30
            cross_alpha = 220 - f * 20
            d.line([(cx - 5, cy), (cx + 5, cy)], fill=(120, 255, 120, cross_alpha), width=2)
            d.line([(cx, cy - 5), (cx, cy + 5)], fill=(120, 255, 120, cross_alpha), width=2)
        # expanding glow ring
        glow_r = int(8 + t * 16)
        glow_a = max(20, 100 - int(t * 90))
        for i in range(0, 360, 10):
            rad = math.radians(i)
            gx = 32 + int(glow_r * math.cos(rad))
            gy = 30 + int(glow_r * math.sin(rad))
            dot(d, gx, gy, (100, 255, 100, glow_a))
        # sparkle dots
        if f > 2:
            random.seed(42 + f)
            for _ in range(f):
                sx = random.randint(10, 54)
                sy = random.randint(10, 50)
                dot(d, sx, sy, (180, 255, 180, 180))
        frames.append(img)
    return frames


# ── 8. 毒/瘟疫 ──────────────────────────────────────

def gen_poison():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        t = f / (NUM_FRAMES - 1)
        phase = f * 0.6
        # bubbling poison pools
        random.seed(42)
        for i in range(6):
            bx = 14 + (i * 10) % 36
            by = 48 + int(math.sin(phase + i * 0.8) * 4) - f
            alpha = max(60, 180 - f * 12)
            if 0 <= by < H:
                dot(d, bx, by, (80, 200, 50, alpha), size=2)
        # poison cloud spreading
        for layer in range(4):
            cr = 6 + layer * 4 + int(math.sin(phase) * 2)
            ca = max(20, 80 - layer * 15 - f * 5)
            d.ellipse([32 - cr, 28 - cr, 32 + cr, 28 + cr],
                      fill=(100, 180, 60, ca))
        # dripping poison
        for i in range(3):
            dx = 20 + i * 12
            drip_y = 38 + int(t * 20) + int(math.sin(phase + i) * 2)
            if drip_y < H:
                d.line([(dx, 30), (dx, drip_y)], fill=(70, 160, 40, 160), width=1)
                dot(d, dx, drip_y, (90, 200, 60, 200), size=1)
        # skull hint
        if 2 <= f <= 6:
            d.ellipse([28, 22, 36, 32], fill=(60, 140, 40, 140))
            dot(d, 30, 26, (30, 80, 20, 180))
            dot(d, 34, 26, (30, 80, 20, 180))
            d.line([(31, 30), (33, 30)], fill=(40, 100, 30, 160))
        frames.append(img)
    return frames


# ── 9. 冰冻 ──────────────────────────────────────────

def gen_freeze():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        t = f / (NUM_FRAMES - 1)
        # ice crystals radiating outward
        n_crystals = 2 + f * 2
        random.seed(42)
        for _ in range(n_crystals):
            cx = random.randint(8, 56)
            cy = random.randint(8, 56)
            size = random.randint(2, 3 + f // 2)
            alpha = max(60, 200 - f * 12)
            # cross crystal
            d.line([(cx - size, cy), (cx + size, cy)], fill=(180, 220, 255, alpha), width=1)
            d.line([(cx, cy - size), (cx, cy + size)], fill=(180, 220, 255, alpha), width=1)
            # diagonal branches
            s2 = max(1, size // 2)
            d.line([(cx - s2, cy - s2), (cx + s2, cy + s2)], fill=(200, 230, 255, alpha // 2), width=1)
            d.line([(cx - s2, cy + s2), (cx + s2, cy - s2)], fill=(200, 230, 255, alpha // 2), width=1)
        # frost spreading overlay
        frost_alpha = int(t * 50)
        if frost_alpha > 0:
            d.rectangle([0, 0, W, H], fill=(200, 230, 255, frost_alpha))
        # center ice core
        core_r = int(4 + t * 8)
        d.ellipse([32 - core_r, 32 - core_r, 32 + core_r, 32 + core_r],
                  fill=(180, 220, 250, max(40, 180 - int(t * 140))))
        # ice particles
        if f > 2:
            for _ in range(f):
                px = random.randint(5, 59)
                py = random.randint(5, 59)
                dot(d, px, py, (220, 240, 255, 160))
        frames.append(img)
    return frames


# ── 10. 士气提升 ─────────────────────────────────────

def gen_morale():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        t = f / (NUM_FRAMES - 1)
        # rising golden energy spiral
        for i in range(10):
            angle = (i / 10) * math.tau + f * 0.4
            r = 8 + int(t * 12)
            px = 32 + int(r * math.cos(angle))
            py = 40 - int(t * 28) + int(4 * math.sin(angle + f * 0.5))
            alpha = max(40, 220 - int(t * 160))
            if 0 <= px < W and 0 <= py < H:
                colors = [(255, 220, 50), (255, 180, 30), (255, 255, 100)]
                dot(d, px, py, (*colors[i % 3], alpha), size=2)
        # banner/flag
        if f < 6:
            fx, fy = 32, 20
            d.line([(fx, fy), (fx, fy + 18)], fill=(160, 120, 70, 200), width=1)
            wave = int(math.sin(f * 0.8) * 2)
            d.polygon([(fx + 1, fy + 1), (fx + 10 + wave, fy + 5), (fx + 1, fy + 9)],
                      fill=(200, 50, 40, 180))
        # upward arrows
        if f > 1:
            for j in range(3):
                ax = 24 + j * 8
                ay = 50 - f * 3
                if ay > 5:
                    d.line([(ax, ay + 3), (ax, ay)], fill=(255, 255, 150, 150))
                    d.line([(ax - 2, ay + 2), (ax, ay), (ax + 2, ay + 2)], fill=(255, 255, 150, 150))
        # golden glow
        glow_r = int(12 + t * 10)
        d.ellipse([32 - glow_r, 35 - glow_r, 32 + glow_r, 35 + glow_r],
                  fill=(255, 220, 80, max(10, 40 - int(t * 35))))
        frames.append(img)
    return frames


# ── 11. 伏击/陷阱 ────────────────────────────────────

def gen_trap():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        t = f / (NUM_FRAMES - 1)
        # trap jaws closing
        jaw_open = int((1 - t) * 12)
        # left jaw
        d.polygon([(16, 40), (32 - jaw_open, 32), (16, 24)],
                  fill=(100, 80, 50, 220))
        # right jaw
        d.polygon([(48, 40), (32 + jaw_open, 32), (48, 24)],
                  fill=(100, 80, 50, 220))
        # spikes
        for s in range(3):
            sy = 28 + s * 4
            d.line([(32 - jaw_open, sy), (32 - jaw_open - 4, sy)], fill=(170, 170, 180, 240))
            d.line([(32 + jaw_open, sy), (32 + jaw_open + 4, sy)], fill=(170, 170, 180, 240))
        # trigger flash
        if f <= 1:
            d.ellipse([28, 30, 36, 34], fill=(255, 255, 200, 200 - f * 80))
        # dust burst
        if f > 2:
            random.seed(42 + f)
            for _ in range(f * 2):
                dx = random.randint(10, 54)
                dy = random.randint(35, 55)
                dot(d, dx, dy, (150, 130, 100, 100), size=1)
        # chain/rope
        for i in range(5):
            rx = 20 + i * 6
            ry = 44 + int(math.sin(f + i) * 2)
            dot(d, rx, ry, (140, 110, 70, 180))
        frames.append(img)
    return frames


# ── 12. 攻城 ──────────────────────────────────────────

def gen_siege():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        t = f / (NUM_FRAMES - 1)
        # battering ram swinging
        ram_x = int(12 + math.sin(t * math.pi) * 16)
        # ram body
        d.rectangle([ram_x, 36, ram_x + 22, 42], fill=(120, 90, 50, 240))
        # wheels
        d.ellipse([ram_x + 2, 42, ram_x + 8, 48], fill=(80, 60, 40, 220))
        d.ellipse([ram_x + 14, 42, ram_x + 20, 48], fill=(80, 60, 40, 220))
        # ram head (iron)
        d.ellipse([ram_x - 4, 35, ram_x + 4, 43], fill=(160, 160, 170, 255))
        # wall
        d.rectangle([50, 18, 55, 55], fill=(140, 120, 90, 240))
        d.rectangle([48, 15, 57, 20], fill=(150, 130, 100, 240))
        # wall cracks on impact
        if f >= 4:
            crack_len = (f - 3) * 4
            for i in range(crack_len):
                cx = 52 + random.randint(-2, 2)
                cy = 30 + i
                if 0 <= cx < W and 0 <= cy < H:
                    dot(d, cx, cy, (80, 60, 40, 200))
        # impact debris
        if 3 <= f <= 6:
            random.seed(42 + f)
            for _ in range((f - 2) * 3):
                dx = random.randint(46, 58)
                dy = random.randint(12, 48)
                dot(d, dx, dy, (170, 150, 120, 180), size=1)
        # dust cloud
        if f > 2:
            dr = int((f - 2) * 4)
            d.ellipse([48 - dr, 28 - dr, 52 + dr, 42 + dr],
                      fill=(160, 140, 110, max(10, 60 - (f - 2) * 8)))
        frames.append(img)
    return frames


# ── 13. 投石 ──────────────────────────────────────────

def gen_boulder():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        t = f / (NUM_FRAMES - 1)
        # parabolic trajectory
        bx = int(8 + t * 48)
        by = int(52 - math.sin(t * math.pi) * 38)
        # boulder
        d.ellipse([bx - 5, by - 4, bx + 5, by + 4], fill=(140, 130, 110, 255))
        d.ellipse([bx - 3, by - 2, bx + 1, by + 1], fill=(160, 150, 130, 200))
        # shadow on ground
        shadow_size = int(2 + t * 4)
        d.ellipse([bx - shadow_size, 54, bx + shadow_size, 57],
                  fill=(60, 60, 60, int(t * 100)))
        # trail smoke
        for s in range(f):
            tx = bx - (s + 1) * 4
            ty = by + s * 2 + 1
            if 0 <= tx < W and 0 <= ty < H:
                dot(d, tx, ty, (160, 150, 130, 100 - s * 12), size=1)
        # impact explosion
        if f >= 6:
            impact_t = (f - 6) / 1
            random.seed(42 + f)
            for _ in range(10):
                ia = random.uniform(0, math.tau)
                idist = random.randint(3, 10)
                ix = bx + int(idist * math.cos(ia))
                iy = 54 + int(idist * math.sin(ia) * 0.5)
                dot(d, ix, iy, (200, 180, 140, 200), size=random.choice([1, 2]))
            # crater
            d.ellipse([bx - 6, 52, bx + 6, 58], fill=(80, 70, 60, 180))
        frames.append(img)
    return frames


# ── 14. 暴击 ──────────────────────────────────────────

def gen_critical():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        t = f / (NUM_FRAMES - 1)
        cx, cy = 32, 32
        # starburst rays
        n_rays = 12
        for r in range(n_rays):
            angle = (r / n_rays) * math.tau + f * 0.1
            length = int(t * 26)
            alpha = max(40, 240 - int(t * 200))
            for s in range(length):
                rx = cx + int(s * math.cos(angle))
                ry = cy + int(s * math.sin(angle))
                if 0 <= rx < W and 0 <= ry < H:
                    brightness = 255 - s * 3
                    d.point((rx, ry), fill=(brightness, brightness, 100, alpha))
        # center flash
        if f < 3:
            fr = 6 - f * 2
            d.ellipse([cx - fr, cy - fr, cx + fr, cy + fr],
                      fill=(255, 255, 255, 255 - f * 60))
        # impact ring
        if f > 0:
            ring_r = int(f * 4)
            ring_a = max(30, 180 - f * 20)
            for i in range(0, 360, 12):
                rad = math.radians(i)
                rx = cx + int(ring_r * math.cos(rad))
                ry = cy + int(ring_r * math.sin(rad))
                dot(d, rx, ry, (255, 230, 120, ring_a))
        # scattered sparks
        random.seed(42 + f)
        for _ in range(f * 3):
            sa = random.uniform(0, math.tau)
            sd = random.randint(8, 20)
            sx = cx + int(sd * math.cos(sa))
            sy = cy + int(sd * math.sin(sa))
            dot(d, sx, sy, (255, 220, 80, max(60, 200 - f * 20)))
        frames.append(img)
    return frames


# ── 15. 夜火 ──────────────────────────────────────────

def gen_night_fire():
    frames = []
    for f in range(NUM_FRAMES):
        img = new_frame()
        d = ImageDraw.Draw(img)
        phase = f * 0.7
        # dark atmosphere
        d.rectangle([0, 0, W, H], fill=(15, 12, 25, 35))
        # campfire base logs
        d.polygon([(26, 54), (32, 50), (38, 54)], fill=(90, 70, 45, 200))
        d.rectangle([24, 54, 40, 57], fill=(100, 80, 50, 200))
        # flames (taller, more dramatic)
        for layer in range(7):
            base_y = 50 - layer * 5
            flicker = int(math.sin(phase + layer * 0.9) * 3)
            cx = 32 + flicker
            w = 12 - layer * 2
            h = 8 - layer
            if w > 0 and h > 0:
                colors = [
                    (255, 255, 150), (255, 210, 80), (255, 160, 45),
                    (255, 110, 25), (220, 70, 15), (180, 45, 10), (140, 30, 5),
                ]
                alphas = [170, 190, 210, 220, 230, 210, 180]
                d.ellipse([cx - w, base_y - h, cx + w, base_y + h],
                          fill=(*colors[layer], alphas[layer]))
        # sparks
        for s in range(4):
            sx = 32 + int(math.sin(phase + s * 1.8) * 10)
            sy = 18 - s * 5
            alpha = 200 - s * 40
            if 0 <= sy < H and alpha > 0:
                dot(d, sx, sy, (255, 200, 100, alpha))
        # warm glow on ground
        glow_r = 22 + int(math.sin(phase) * 3)
        d.ellipse([32 - glow_r, 40 - glow_r // 2, 32 + glow_r, 40 + glow_r // 2],
                  fill=(255, 150, 50, 20))
        # distant stars
        random.seed(42)
        for _ in range(6):
            star_x = random.randint(2, 61)
            star_y = random.randint(2, 15)
            star_alpha = 100 + int(math.sin(phase + star_x) * 50)
            dot(d, star_x, star_y, (255, 255, 220, max(40, star_alpha)))
        frames.append(img)
    return frames


# ── 主函数 ──────────────────────────────────────────────

EFFECTS = {
    "fx_arrow_rain": gen_arrow_rain,
    "fx_fire": gen_fire,
    "fx_explosion": gen_explosion,
    "fx_charge": gen_charge,
    "fx_slash": gen_slash,
    "fx_shield_block": gen_shield_block,
    "fx_heal": gen_heal,
    "fx_poison": gen_poison,
    "fx_freeze": gen_freeze,
    "fx_morale": gen_morale,
    "fx_trap": gen_trap,
    "fx_siege": gen_siege,
    "fx_boulder": gen_boulder,
    "fx_critical": gen_critical,
    "fx_night_fire": gen_night_fire,
}

print(f"=== 生成 {len(EFFECTS)} 种战斗特效动画 ===")
print(f"输出目录: {OUT_DIR}")
print(f"规格: {W}x{H} → {W * SCALE}x{H * SCALE} | {NUM_FRAMES} 帧/特效 | 透明背景")
print()

for name, gen_func in EFFECTS.items():
    random.seed(42)
    frames = gen_func()
    save_effect(name, frames)

print(f"\n=== 完成: {len(EFFECTS)} 种特效, 共 {len(EFFECTS) * NUM_FRAMES} 帧 ===")
