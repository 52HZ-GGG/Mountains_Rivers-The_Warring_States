"""
《山河策》UI 界面生成器
水墨像素风 | 战国色谱 | 遵循 artline1.md
运行: python generate_ui.py
"""

import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "ui")
os.makedirs(OUT_DIR, exist_ok=True)

# ── 战国色谱 ──
INK = {
    "b": (26,26,27),    # 水墨黑 base
    "h": (51,51,52),    # high
    "s": (13,13,14),    # shadow
    "d": (0,0,0),       # deep
}
BAM = {
    "b": (197,163,104), # 竹简黄 base
    "h": (217,190,139), # high
    "s": (153,122,74),  # shadow
    "d": (102,82,49),   # deep
}
LAC = {
    "b": (140,69,34),   # 漆器红 base
    "h": (176,93,59),   # high
    "s": (102,48,24),   # shadow
    "d": (64,29,15),    # deep
}
BRO = {
    "b": (43,51,48),    # 青铜靛 base
    "h": (69,82,77),    # high
    "s": (26,33,30),    # shadow
    "d": (13,18,16),    # deep
}
# 功能色
RES = {
    "grain": (180,170,90),
    "money": (200,180,100),
    "iron":  (160,160,170),
    "hp":    (80,160,70),
    "mp":    (70,120,170),
}
TXT = {
    "title": (217,190,139),
    "body":  (180,170,150),
    "dim":   (120,110,95),
    "red":   (176,93,59),
    "green": (100,160,80),
}
# 高亮色
HL_SELECT = (220, 200, 80, 90)   # 选中黄
HL_MOVE   = (80, 140, 220, 80)   # 移动蓝


def pb(d, x, y, w, h, c):
    d.rectangle([x, y, x+w-1, y+h-1], fill=c)

def panel(d, x, y, w, h):
    """标准面板：外框深色 + 内框竹简黄 + 暗色内容区"""
    pb(d, x, y, w, h, BRO["d"])       # 外框
    pb(d, x+1, y+1, w-2, h-2, BAM["d"])  # 内框
    pb(d, x+2, y+2, w-4, h-4, INK["s"])  # 内容区
    pb(d, x+3, y+3, w-6, 1, BRO["h"])    # 顶部高光线

def bar_fill(d, x, y, w, h, ratio, color):
    """进度条填充"""
    fill_w = max(1, int(w * ratio))
    pb(d, x, y, fill_w, h, color)
    if fill_w < w:
        pb(d, x+fill_w, y, w-fill_w, h, INK["d"])

def icon_grain(d, cx, cy):
    """粮食图标：谷穗"""
    for dy in range(-4, 1):
        for dx in [-1, 0, 1]:
            if abs(dx) + abs(dy+2) <= 3:
                d.point((cx+dx, cy+dy), fill=RES["grain"])
    d.point((cx, cy+1), fill=BAM["s"])
    d.point((cx, cy+2), fill=BAM["s"])

def icon_money(d, cx, cy):
    """金钱图标：方孔钱"""
    d.ellipse([cx-3, cy-3, cx+3, cy+3], outline=BAM["h"], width=1)
    d.rectangle([cx-1, cy-1, cx+1, cy+1], fill=INK["b"])

def icon_iron(d, cx, cy):
    """铁矿图标：铁锭"""
    d.polygon([(cx-3, cy+2), (cx+3, cy+2), (cx+2, cy-2), (cx-2, cy-2)],
              fill=RES["iron"])
    d.point((cx, cy-1), fill=(190,190,200))

def icon_hp(d, cx, cy):
    """生命值图标"""
    d.point((cx, cy-2), fill=RES["hp"])
    for dx in range(-2, 3):
        d.point((cx+dx, cy-1), fill=RES["hp"])
    for dx in range(-1, 2):
        d.point((cx+dx, cy), fill=RES["hp"])
    d.point((cx, cy+1), fill=RES["hp"])

def icon_atk(d, cx, cy):
    """攻击图标：剑"""
    for i in range(7):
        d.point((cx-3+i, cy-3+i), fill=RES["iron"])
    d.point((cx+3, cy-3), fill=LAC["b"])
    d.point((cx+4, cy-4), fill=LAC["h"])

def icon_mov(d, cx, cy):
    """移动力图标：靴"""
    pb(d, cx-2, cy-1, 4, 3, BAM["s"])
    pb(d, cx+1, cy+1, 2, 2, BAM["d"])

def icon_def(d, cx, cy):
    """防御图标：盾"""
    d.polygon([(cx, cy-3), (cx+3, cy-1), (cx+2, cy+3), (cx-2, cy+3), (cx-3, cy-1)],
              fill=BRO["b"], outline=BRO["h"])

# ── 像素字体（5x7 简易数字/字母）──
FONT = {
    '0': [0b01110,0b10001,0b10011,0b10101,0b11001,0b10001,0b01110],
    '1': [0b00100,0b01100,0b00100,0b00100,0b00100,0b00100,0b01110],
    '2': [0b01110,0b10001,0b00001,0b00110,0b01000,0b10000,0b11111],
    '3': [0b11111,0b00010,0b00100,0b00010,0b00001,0b10001,0b01110],
    '4': [0b00010,0b00110,0b01010,0b10010,0b11111,0b00010,0b00010],
    '5': [0b11111,0b10000,0b11110,0b00001,0b00001,0b10001,0b01110],
    '6': [0b00110,0b01000,0b10000,0b11110,0b10001,0b10001,0b01110],
    '7': [0b11111,0b00001,0b00010,0b00100,0b01000,0b01000,0b01000],
    '8': [0b01110,0b10001,0b10001,0b01110,0b10001,0b10001,0b01110],
    '9': [0b01110,0b10001,0b10001,0b01111,0b00001,0b00010,0b01100],
    '/': [0b00001,0b00010,0b00010,0b00100,0b01000,0b01000,0b10000],
    '+': [0b00000,0b00100,0b00100,0b11111,0b00100,0b00100,0b00000],
    '-': [0b00000,0b00000,0b00000,0b11111,0b00000,0b00000,0b00000],
    ' ': [0b00000,0b00000,0b00000,0b00000,0b00000,0b00000,0b00000],
    'A': [0b01110,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001],
    'B': [0b11110,0b10001,0b10001,0b11110,0b10001,0b10001,0b11110],
    'C': [0b01110,0b10001,0b10000,0b10000,0b10000,0b10001,0b01110],
    'D': [0b11100,0b10010,0b10001,0b10001,0b10001,0b10010,0b11100],
    'E': [0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b11111],
    'F': [0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b10000],
    'G': [0b01110,0b10001,0b10000,0b10111,0b10001,0b10001,0b01110],
    'H': [0b10001,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001],
    'I': [0b01110,0b00100,0b00100,0b00100,0b00100,0b00100,0b01110],
    'K': [0b10001,0b10010,0b10100,0b11000,0b10100,0b10010,0b10001],
    'L': [0b10000,0b10000,0b10000,0b10000,0b10000,0b10000,0b11111],
    'M': [0b10001,0b11011,0b10101,0b10001,0b10001,0b10001,0b10001],
    'N': [0b10001,0b11001,0b10101,0b10011,0b10001,0b10001,0b10001],
    'O': [0b01110,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110],
    'P': [0b11110,0b10001,0b10001,0b11110,0b10000,0b10000,0b10000],
    'R': [0b11110,0b10001,0b10001,0b11110,0b10100,0b10010,0b10001],
    'S': [0b01110,0b10001,0b10000,0b01110,0b00001,0b10001,0b01110],
    'T': [0b11111,0b00100,0b00100,0b00100,0b00100,0b00100,0b00100],
    'U': [0b10001,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110],
    'V': [0b10001,0b10001,0b10001,0b10001,0b01010,0b01010,0b00100],
    'W': [0b10001,0b10001,0b10001,0b10101,0b10101,0b11011,0b10001],
    'X': [0b10001,0b10001,0b01010,0b00100,0b01010,0b10001,0b10001],
    'Y': [0b10001,0b10001,0b01010,0b00100,0b00100,0b00100,0b00100],
}

def draw_text(d, x, y, text, color, scale=1):
    """绘制像素文本"""
    cx = x
    for ch in text:
        if ch in FONT:
            glyph = FONT[ch]
            for row in range(7):
                bits = glyph[row]
                for col in range(5):
                    if bits & (1 << (4 - col)):
                        if scale == 1:
                            d.point((cx+col, y+row), fill=color)
                        else:
                            pb(d, cx+col*scale, y+row*scale, scale, scale, color)
            cx += 6 * scale
        else:
            cx += 4 * scale


def text_width(text, scale=1):
    return len(text) * 6 * scale - 1 * scale


def save(img, name):
    path = os.path.join(OUT_DIR, f"{name}.png")
    img.save(path)
    print(f"  [OK] {name}.png")


# ══════════════════════════════════════════════════════════
#  1. 资源栏 (320x40)
# ══════════════════════════════════════════════════════════
def gen_resource_bar():
    img = Image.new("RGBA", (320, 40), (0,0,0,0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, 320, 40)
    # 粮食
    icon_grain(d, 18, 20)
    draw_text(d, 26, 14, "GRAIN", TXT["dim"])
    bar_fill(d, 8, 28, 80, 6, 0.7, RES["grain"])
    draw_text(d, 26, 28, "840", TXT["body"])
    # 分隔线
    pb(d, 107, 6, 1, 28, BAM["d"])
    # 金钱
    icon_money(d, 125, 20)
    draw_text(d, 133, 14, "GOLD", TXT["dim"])
    bar_fill(d, 115, 28, 80, 6, 0.5, BAM["h"])
    draw_text(d, 133, 28, "520", TXT["body"])
    # 分隔线
    pb(d, 207, 6, 1, 28, BAM["d"])
    # 铁矿
    icon_iron(d, 225, 20)
    draw_text(d, 233, 14, "IRON", TXT["dim"])
    bar_fill(d, 215, 28, 80, 6, 0.3, RES["iron"])
    draw_text(d, 233, 28, "180", TXT["body"])
    save(img, "ui_resource_bar")


# ══════════════════════════════════════════════════════════
#  2. 回合按钮 (120x40)
# ══════════════════════════════════════════════════════════
def gen_turn_button():
    img = Image.new("RGBA", (120, 40), (0,0,0,0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, 120, 40)
    # 高亮边
    pb(d, 3, 3, 114, 1, LAC["h"])
    # 文本
    tw = text_width("TURN END")
    draw_text(d, (120-tw)//2, 12, "TURN END", TXT["title"])
    # 小箭头
    for i in range(5):
        d.point((95+i, 28), fill=BAM["h"])
    d.point((97, 26), fill=BAM["h"])
    d.point((97, 30), fill=BAM["h"])
    save(img, "ui_turn_button")


# ══════════════════════════════════════════════════════════
#  3. 单位信息面板 (200x160)
# ══════════════════════════════════════════════════════════
def gen_unit_info():
    img = Image.new("RGBA", (200, 160), (0,0,0,0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, 200, 160)
    # 标题栏
    pb(d, 3, 3, 194, 14, BRO["s"])
    draw_text(d, 8, 5, "UNIT INFO", TXT["title"])
    # 单位名称
    draw_text(d, 10, 22, "QIN RUSHI", TXT["body"])
    draw_text(d, 10, 32, "LV 3", TXT["dim"])
    # 分隔线
    pb(d, 8, 42, 184, 1, BAM["d"])
    # 属性
    icon_hp(d, 18, 54)
    draw_text(d, 26, 50, "HP", TXT["dim"])
    bar_fill(d, 50, 51, 100, 6, 0.8, RES["hp"])
    draw_text(d, 155, 50, "80/100", TXT["body"])

    icon_atk(d, 18, 68)
    draw_text(d, 26, 64, "ATK", TXT["dim"])
    draw_text(d, 60, 64, "45", TXT["body"])

    icon_def(d, 18, 78)
    draw_text(d, 26, 74, "DEF", TXT["dim"])
    draw_text(d, 60, 74, "38", TXT["body"])

    icon_mov(d, 100, 68)
    draw_text(d, 108, 64, "MOV", TXT["dim"])
    draw_text(d, 142, 64, "3", TXT["body"])

    # 分隔线
    pb(d, 8, 88, 184, 1, BAM["d"])
    # 状态效果
    draw_text(d, 10, 94, "STATUS:", TXT["dim"])
    pb(d, 10, 106, 16, 8, LAC["b"])
    draw_text(d, 30, 106, "FRENZY", TXT["red"])
    pb(d, 10, 118, 16, 8, BRO["b"])
    draw_text(d, 30, 118, "SHIELD", TXT["body"])
    # 底部信息
    pb(d, 8, 132, 184, 1, BAM["d"])
    draw_text(d, 10, 138, "EXP:", TXT["dim"])
    bar_fill(d, 40, 139, 80, 5, 0.6, BAM["h"])
    draw_text(d, 125, 138, "600/1000", TXT["dim"])
    save(img, "ui_unit_info")


# ══════════════════════════════════════════════════════════
#  4. 城市面板 (240x200)
# ══════════════════════════════════════════════════════════
def gen_city_panel():
    img = Image.new("RGBA", (240, 200), (0,0,0,0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, 240, 200)
    # 标题
    pb(d, 3, 3, 234, 14, BRO["s"])
    draw_text(d, 8, 5, "CITY: XIAN YANG", TXT["title"])
    # 人口与产出
    draw_text(d, 10, 22, "POP: 12,500", TXT["body"])
    draw_text(d, 130, 22, "LV 4", TXT["dim"])
    pb(d, 8, 34, 224, 1, BAM["d"])
    # 资源产出
    draw_text(d, 10, 40, "OUTPUT:", TXT["dim"])
    icon_grain(d, 80, 44)
    draw_text(d, 88, 40, "+25", TXT["green"])
    icon_money(d, 125, 44)
    draw_text(d, 133, 40, "+18", TXT["green"])
    icon_iron(d, 175, 44)
    draw_text(d, 183, 40, "+12", TXT["green"])
    pb(d, 8, 54, 224, 1, BAM["d"])
    # 建筑列表
    draw_text(d, 10, 60, "BUILDINGS:", TXT["dim"])
    buildings = ["FARM", "MINE", "WALL", "BARRACK"]
    for i, bld in enumerate(buildings):
        bx = 10 + (i % 2) * 112
        by = 74 + (i // 2) * 18
        pb(d, bx, by, 104, 14, BRO["s"])
        pb(d, bx+1, by+1, 102, 12, INK["b"])
        draw_text(d, bx+4, by+3, bld, TXT["body"])
    # 驻军
    pb(d, 8, 114, 224, 1, BAM["d"])
    draw_text(d, 10, 120, "GARRISON:", TXT["dim"])
    pb(d, 10, 134, 60, 14, BRO["s"])
    draw_text(d, 14, 136, "INF x2", TXT["body"])
    pb(d, 75, 134, 60, 14, BRO["s"])
    draw_text(d, 79, 136, "ARC x1", TXT["body"])
    pb(d, 140, 134, 60, 14, BRO["s"])
    draw_text(d, 144, 136, "CAV x1", TXT["body"])
    # 生产队列
    pb(d, 8, 154, 224, 1, BAM["d"])
    draw_text(d, 10, 160, "PRODUCING:", TXT["dim"])
    pb(d, 10, 174, 180, 14, BRO["s"])
    pb(d, 11, 175, 178, 12, INK["b"])
    draw_text(d, 14, 177, "SPEARMAN", TXT["body"])
    bar_fill(d, 130, 178, 55, 5, 0.65, LAC["h"])
    draw_text(d, 192, 176, "3T", TXT["dim"])
    save(img, "ui_city_panel")


# ══════════════════════════════════════════════════════════
#  5. 选中高亮 (32x32, 可平铺)
# ══════════════════════════════════════════════════════════
def gen_highlight_select():
    img = Image.new("RGBA", (32, 32), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 平顶六角形高亮（半透明黄）
    hr = 15
    cx, cy = 16, 16
    verts = [(cx + hr * __import__('math').cos(__import__('math').radians(60*i)),
              cy + hr * __import__('math').sin(__import__('math').radians(60*i))) for i in range(6)]
    d.polygon([(int(x),int(y)) for x,y in verts], fill=HL_SELECT)
    # 边框
    d.polygon([(int(x),int(y)) for x,y in verts], outline=(220,200,80,180), width=1)
    save(img, "ui_highlight_select")


# ══════════════════════════════════════════════════════════
#  6. 移动高亮 (32x32, 可平铺)
# ══════════════════════════════════════════════════════════
def gen_highlight_move():
    img = Image.new("RGBA", (32, 32), (0,0,0,0))
    d = ImageDraw.Draw(img)
    hr = 15
    cx, cy = 16, 16
    verts = [(cx + hr * __import__('math').cos(__import__('math').radians(60*i)),
              cy + hr * __import__('math').sin(__import__('math').radians(60*i))) for i in range(6)]
    d.polygon([(int(x),int(y)) for x,y in verts], fill=HL_MOVE)
    d.polygon([(int(x),int(y)) for x,y in verts], outline=(80,140,220,150), width=1)
    save(img, "ui_highlight_move")


# ══════════════════════════════════════════════════════════
#  7. 征服公告 (800x600)
# ══════════════════════════════════════════════════════════
def gen_announcement():
    img = Image.new("RGBA", (800, 600), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 半透明黑色背景
    pb(d, 0, 0, 800, 600, (10, 10, 12, 200))
    # 中央面板
    panel(d, 150, 150, 500, 300)
    # 装饰边框
    pb(d, 155, 155, 490, 2, LAC["b"])
    pb(d, 155, 443, 490, 2, LAC["b"])
    pb(d, 155, 155, 2, 290, LAC["b"])
    pb(d, 643, 155, 2, 290, LAC["b"])
    # 标题
    pb(d, 160, 160, 480, 30, BRO["s"])
    tw = text_width("CONQUEST!", 2)
    draw_text(d, (800-tw)//2, 167, "CONQUEST!", TXT["title"], 2)
    # 大字（模拟中文效果）
    # 用装饰性像素块模拟"都破"效果
    for dx in range(-3, 4):
        for dy in range(-3, 4):
            if abs(dx) + abs(dy) <= 4:
                c = LAC["b"] if (dx+dy) % 2 == 0 else LAC["s"]
                d.point((400+dx*12, 250+dy*12), fill=c)
    # 说明文本
    draw_text(d, 220, 310, "THE CAPITAL HAS FALLEN!", TXT["body"], 2)
    draw_text(d, 230, 340, "AN DYNASTY IS DESTROYED", TXT["dim"], 2)
    # 底部装饰线
    pb(d, 200, 380, 400, 1, BAM["d"])
    pb(d, 200, 385, 400, 1, BAM["d"])
    # 确认按钮
    panel(d, 330, 400, 140, 35)
    tw = text_width("CONFIRM")
    draw_text(d, (800-tw)//2, 410, "CONFIRM", TXT["title"])
    save(img, "ui_announcement_conquest")


# ══════════════════════════════════════════════════════════
#  8. 季节横幅 (400x50)
# ══════════════════════════════════════════════════════════
def gen_season_banner():
    img = Image.new("RGBA", (400, 50), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 半透明背景
    panel(d, 0, 0, 400, 50)
    # 季节图标（简化樱花/雪花/落叶/太阳）
    # 春
    pb(d, 10, 10, 20, 20, BRO["s"])
    for dx, dy in [(-3,0),(3,0),(0,-3),(0,3)]:
        d.point((20+dx, 20+dy), fill=(200,150,170))
    d.point((20, 20), fill=(220,180,190))
    draw_text(d, 38, 12, "SPRING", TXT["title"])
    draw_text(d, 38, 24, "EAST WIND BLOWS", TXT["dim"])
    # 装饰线
    pb(d, 200, 15, 180, 1, BAM["d"])
    pb(d, 200, 35, 180, 1, BAM["d"])
    draw_text(d, 210, 20, "YEAR 230 BC", TXT["body"])
    save(img, "ui_season_banner")


# ══════════════════════════════════════════════════════════
#  9. 外交面板 (280x180)
# ══════════════════════════════════════════════════════════
def gen_diplomacy_panel():
    img = Image.new("RGBA", (280, 180), (0,0,0,0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, 280, 180)
    # 标题
    pb(d, 3, 3, 274, 14, BRO["s"])
    draw_text(d, 8, 5, "DIPLOMACY: ZHAO", TXT["title"])
    # 关系条
    draw_text(d, 10, 22, "RELATION:", TXT["dim"])
    # 关系条（红→绿渐变）
    for i in range(100):
        r = int(180 - i * 1.2)
        g = int(60 + i * 1.0)
        b = int(40 + i * 0.2)
        pb(d, 80+i, 24, 1, 8, (max(0,r), min(255,g), max(0,b), 200))
    # 指针
    draw_text(d, 85, 24, "|", TXT["body"])
    draw_text(d, 185, 24, "+50", TXT["green"])
    pb(d, 8, 38, 264, 1, BAM["d"])
    # 可用行动
    draw_text(d, 10, 44, "ACTIONS:", TXT["dim"])
    actions = ["DECLARE WAR", "CEASEFIRE", "PASSAGE", "ALLIANCE", "GIFT"]
    colors = [LAC["b"], BAM["b"], BRO["b"], RES["grain"], BAM["h"]]
    for i, (act, col) in enumerate(zip(actions, colors)):
        ax = 10 + (i % 3) * 88
        ay = 60 + (i // 3) * 28
        pb(d, ax, ay, 82, 22, col)
        pb(d, ax+1, ay+1, 80, 20, INK["s"])
        draw_text(d, ax+4, ay+6, act, TXT["body"])
    # 底部
    pb(d, 8, 150, 264, 1, BAM["d"])
    draw_text(d, 10, 156, "LAST: TRADE AGREEMENT", TXT["dim"])
    save(img, "ui_diplomacy_panel")


# ══════════════════════════════════════════════════════════
#  10. 学派选择面板 (300x220)
# ══════════════════════════════════════════════════════════
def gen_school_panel():
    img = Image.new("RGBA", (300, 220), (0,0,0,0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, 300, 220)
    # 标题
    pb(d, 3, 3, 294, 14, BRO["s"])
    draw_text(d, 8, 5, "SELECT SCHOOL", TXT["title"])
    # 6 个学派
    schools = [
        ("RU", (160,120,70)),   # 儒家
        ("LE", (100,60,40)),    # 法家
        ("MO", (80,100,70)),    # 墨家
        ("DA", (120,140,130)),  # 道家
        ("ST", (90,70,60)),     # 兵家
        ("DI", (140,130,80)),   # 纵横家
    ]
    for i, (name, col) in enumerate(schools):
        sx = 15 + (i % 3) * 92
        sy = 25 + (i // 3) * 85
        # 图标框
        pb(d, sx, sy, 82, 72, col)
        pb(d, sx+1, sy+1, 80, 70, INK["s"])
        # 图标（简化符号）
        cx, cy = sx+41, sy+25
        if name == "RU":  # 儒：人形
            d.point((cx, cy-4), fill=BAM["h"])
            pb(d, cx-2, cy-2, 5, 6, BAM["b"])
            pb(d, cx-4, cy+1, 3, 4, BAM["s"])
            pb(d, cx+2, cy+1, 3, 4, BAM["s"])
        elif name == "LE":  # 法：方正
            pb(d, cx-4, cy-4, 9, 9, LAC["b"])
            pb(d, cx-3, cy-3, 7, 7, LAC["s"])
        elif name == "MO":  # 墨：工匠锤
            pb(d, cx-1, cy-5, 3, 8, BRO["b"])
            pb(d, cx-3, cy+2, 7, 3, BRO["h"])
        elif name == "DA":  # 道：太极
            d.ellipse([cx-5, cy-5, cx+5, cy+5], outline=(150,170,160), width=1)
            d.point((cx-2, cy-2), fill=(180,200,190))
            d.point((cx+2, cy+2), fill=BRO["d"])
        elif name == "ST":  # 兵：剑
            for j in range(8):
                d.point((cx-4+j, cy-4+j), fill=RES["iron"])
        elif name == "DI":  # 纵横：连横
            d.line([(cx-4, cy), (cx+4, cy)], fill=BAM["h"], width=1)
            d.line([(cx, cy-4), (cx, cy+4)], fill=BAM["h"], width=1)
        # 名称
        draw_text(d, sx+8, sy+45, name, TXT["body"])
        draw_text(d, sx+8, sy+55, "SCHOOL", TXT["dim"])
    save(img, "ui_school_panel")


# ══════════════════════════════════════════════════════════
#  11. 科技树面板 (320x240)
# ══════════════════════════════════════════════════════════
def gen_tech_panel():
    img = Image.new("RGBA", (320, 240), (0,0,0,0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, 320, 240)
    pb(d, 3, 3, 314, 14, BRO["s"])
    draw_text(d, 8, 5, "TECHNOLOGY", TXT["title"])
    # 4 个突破科技
    techs = [
        ("BRIDGE", "BUILD BRIDGES", 0),
        ("FLOAT",  "FLOAT BRIDGE",  1),
        ("PLANK",  "PLANK ROAD",    2),
        ("PASS",   "PASS ASSAULT",  3),
    ]
    for i, (name, desc, _) in enumerate(techs):
        tx = 15
        ty = 25 + i * 52
        # 节点
        pb(d, tx, ty, 290, 44, BRO["s"])
        pb(d, tx+1, ty+1, 288, 42, INK["b"])
        # 图标
        pb(d, tx+5, ty+5, 32, 32, BRO["b"])
        pb(d, tx+6, ty+6, 30, 30, BRO["h"])
        # 进度
        progress = [1.0, 0.6, 0.3, 0.0][i]
        if progress >= 1.0:
            draw_text(d, tx+10, ty+12, "OK", TXT["green"])
        else:
            draw_text(d, tx+10, ty+12, str(int(progress*100)), TXT["body"])
        # 文本
        draw_text(d, tx+42, ty+8, name, TXT["title"])
        draw_text(d, tx+42, ty+20, desc, TXT["dim"])
        bar_fill(d, tx+42, ty+32, 200, 5, progress, LAC["h"])
        # 连接线
        if i < 3:
            pb(d, tx+16, ty+44, 2, 8, BAM["d"])
    save(img, "ui_tech_panel")


# ══════════════════════════════════════════════════════════
#  12. 存读档界面 (400x300)
# ══════════════════════════════════════════════════════════
def gen_save_load():
    img = Image.new("RGBA", (400, 300), (0,0,0,0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, 400, 300)
    pb(d, 3, 3, 394, 14, BRO["s"])
    draw_text(d, 8, 5, "SAVE / LOAD", TXT["title"])
    # 标签页
    pb(d, 10, 22, 80, 18, LAC["b"])
    draw_text(d, 22, 26, "SAVE", TXT["title"])
    pb(d, 95, 22, 80, 18, BRO["s"])
    draw_text(d, 107, 26, "LOAD", TXT["dim"])
    # 存档列表
    for i in range(5):
        sy = 48 + i * 44
        pb(d, 10, sy, 380, 38, BRO["s"])
        pb(d, 11, sy+1, 378, 36, INK["b"])
        # 存档名
        draw_text(d, 18, sy+5, f"SLOT {i+1}", TXT["title"])
        # 信息
        draw_text(d, 18, sy+18, "YEAR 230 BC", TXT["dim"])
        draw_text(d, 150, sy+18, "TURN 45", TXT["dim"])
        draw_text(d, 250, sy+18, "QIN", TXT["body"])
        # 操作
        pb(d, 330, sy+4, 50, 14, LAC["b"])
        draw_text(d, 338, sy+7, "SAVE", TXT["body"])
        pb(d, 330, sy+22, 50, 14, BRO["b"])
        draw_text(d, 338, sy+25, "DEL", TXT["dim"])
    # 底部按钮
    pb(d, 10, 275, 80, 18, BRO["b"])
    draw_text(d, 22, 279, "BACK", TXT["body"])
    save(img, "ui_save_load")


# ══════════════════════════════════════════════════════════
#  13. 设置界面 (350x250)
# ══════════════════════════════════════════════════════════
def gen_settings():
    img = Image.new("RGBA", (350, 250), (0,0,0,0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, 350, 250)
    pb(d, 3, 3, 344, 14, BRO["s"])
    draw_text(d, 8, 5, "SETTINGS", TXT["title"])
    # 设置项
    settings = [
        ("MASTER VOL", 0.8),
        ("MUSIC VOL",  0.6),
        ("SFX VOL",    0.7),
        ("SCROLL SPD", 0.5),
    ]
    for i, (name, val) in enumerate(settings):
        sy = 25 + i * 35
        draw_text(d, 15, sy+4, name, TXT["body"])
        bar_fill(d, 140, sy+5, 150, 8, val, BAM["h"])
        draw_text(d, 295, sy+4, str(int(val*100)), TXT["dim"])
    # 切换项
    toggles = ["ANIMATIONS", "AUTO SAVE", "SHOW GRID"]
    for i, name in enumerate(toggles):
        sy = 170 + i * 22
        pb(d, 15, sy, 10, 10, BRO["b"])
        pb(d, 16, sy+1, 8, 8, LAC["b"] if i < 2 else BRO["s"])
        draw_text(d, 30, sy, name, TXT["body"])
    # 按钮
    pb(d, 10, 228, 70, 16, LAC["b"])
    draw_text(d, 18, 231, "APPLY", TXT["body"])
    pb(d, 85, 228, 70, 16, BRO["s"])
    draw_text(d, 93, 231, "CANCEL", TXT["dim"])
    save(img, "ui_settings")


# ══════════════════════════════════════════════════════════
#  14. 新游戏界面 (500x350)
# ══════════════════════════════════════════════════════════
def gen_new_game():
    img = Image.new("RGBA", (500, 350), (0,0,0,0))
    d = ImageDraw.Draw(img)
    panel(d, 0, 0, 500, 350)
    pb(d, 3, 3, 494, 14, BRO["s"])
    draw_text(d, 8, 5, "NEW GAME", TXT["title"])
    # 国家选择
    draw_text(d, 15, 25, "SELECT KINGDOM:", TXT["dim"])
    kingdoms = [
        ("QIN",  LAC["b"]), ("ZHAO", BRO["b"]), ("QI",   BAM["b"]),
        ("CHU",  (100,60,35)), ("WEI",  BRO["h"]), ("YAN",  (60,80,70)),
        ("HAN",  (80,90,75)),
    ]
    for i, (name, col) in enumerate(kingdoms):
        kx = 15 + (i % 4) * 118
        ky = 42 + (i // 4) * 55
        pb(d, kx, ky, 108, 45, col)
        pb(d, kx+1, ky+1, 106, 43, INK["s"])
        draw_text(d, kx+8, ky+8, name, TXT["title"])
        draw_text(d, kx+8, ky+22, "DIFFICULTY", TXT["dim"])
    # 难度选择
    draw_text(d, 15, 160, "DIFFICULTY:", TXT["dim"])
    diffs = ["EASY", "NORMAL", "HARD", "LEGEND"]
    for i, diff in enumerate(diffs):
        dx = 15 + i * 118
        col = [RES["grain"], BAM["h"], LAC["b"], LAC["d"]][i]
        pb(d, dx, 178, 108, 22, col)
        pb(d, dx+1, 179, 106, 20, INK["s"])
        draw_text(d, dx+8, 183, diff, TXT["body"])
    # 地图大小
    draw_text(d, 15, 215, "MAP SIZE:", TXT["dim"])
    sizes = ["SMALL 20x20", "MEDIUM 30x30", "LARGE 40x40"]
    for i, size in enumerate(sizes):
        sx = 15 + i * 158
        pb(d, sx, 233, 148, 18, BRO["s"])
        pb(d, sx+1, 234, 146, 16, INK["b"])
        draw_text(d, sx+5, 237, size, TXT["body"])
    # 开始按钮
    pb(d, 180, 280, 140, 35, LAC["b"])
    pb(d, 181, 281, 138, 33, LAC["h"])
    pb(d, 182, 282, 136, 31, LAC["b"])
    tw = text_width("START GAME")
    draw_text(d, (500-tw)//2, 290, "START GAME", TXT["title"])
    save(img, "ui_new_game")


# ══════════════════════════════════════════════════════════
#  15. 胜利/失败界面 (500x350)
# ══════════════════════════════════════════════════════════
def gen_victory():
    img = Image.new("RGBA", (500, 350), (0,0,0,0))
    d = ImageDraw.Draw(img)
    # 半透明背景
    pb(d, 0, 0, 500, 350, (10, 10, 12, 210))
    panel(d, 50, 50, 400, 250)
    # 装饰金边
    pb(d, 55, 55, 390, 2, BAM["h"])
    pb(d, 55, 293, 390, 2, BAM["h"])
    pb(d, 55, 55, 2, 240, BAM["h"])
    pb(d, 443, 55, 2, 240, BAM["h"])
    # 标题
    pb(d, 60, 60, 380, 30, BRO["s"])
    tw = text_width("VICTORY!", 3)
    draw_text(d, (500-tw)//2, 66, "VICTORY!", BAM["h"], 3)
    # 大字装饰
    for dx in range(-4, 5):
        for dy in range(-4, 5):
            if abs(dx) + abs(dy) <= 5:
                c = BAM["b"] if (dx+dy) % 2 == 0 else BAM["s"]
                d.point((250+dx*10, 140+dy*10), fill=c)
    # 说明
    draw_text(d, 120, 190, "QIN UNIFIES ALL", TXT["title"], 2)
    draw_text(d, 130, 215, "THE WARRING STATES!", TXT["body"], 2)
    # 统计
    draw_text(d, 100, 245, "TURNS: 150  KINGS: 7", TXT["dim"])
    # 按钮
    pb(d, 160, 268, 80, 20, BRO["b"])
    draw_text(d, 175, 272, "MENU", TXT["body"])
    pb(d, 260, 268, 80, 20, LAC["b"])
    draw_text(d, 270, 272, "RESTART", TXT["body"])
    save(img, "ui_victory")


def gen_defeat():
    img = Image.new("RGBA", (500, 350), (0,0,0,0))
    d = ImageDraw.Draw(img)
    pb(d, 0, 0, 500, 350, (10, 10, 12, 220))
    panel(d, 50, 50, 400, 250)
    pb(d, 55, 55, 390, 2, LAC["d"])
    pb(d, 55, 293, 390, 2, LAC["d"])
    pb(d, 55, 55, 2, 240, LAC["d"])
    pb(d, 443, 55, 2, 240, LAC["d"])
    pb(d, 60, 60, 380, 30, BRO["s"])
    tw = text_width("DEFEAT", 3)
    draw_text(d, (500-tw)//2, 66, "DEFEAT", LAC["h"], 3)
    for dx in range(-4, 5):
        for dy in range(-4, 5):
            if abs(dx) + abs(dy) <= 5:
                c = LAC["b"] if (dx+dy) % 2 == 0 else LAC["s"]
                d.point((250+dx*10, 140+dy*10), fill=c)
    draw_text(d, 130, 190, "YOUR KINGDOM", TXT["title"], 2)
    draw_text(d, 120, 215, "HAS BEEN CONQUERED", LAC["h"], 2)
    draw_text(d, 100, 245, "TURNS SURVIVED: 87", TXT["dim"])
    pb(d, 160, 268, 80, 20, BRO["b"])
    draw_text(d, 175, 272, "MENU", TXT["body"])
    pb(d, 260, 268, 80, 20, LAC["b"])
    draw_text(d, 270, 272, "RESTART", TXT["body"])
    save(img, "ui_defeat")


# ══════════════════════════════════════════════════════════
#  主函数
# ══════════════════════════════════════════════════════════
def generate_all():
    print("=== 《山河策》UI 界面生成器 ===\n")

    gen_resource_bar()
    gen_turn_button()
    gen_unit_info()
    gen_city_panel()
    gen_highlight_select()
    gen_highlight_move()
    gen_announcement()
    gen_season_banner()
    gen_diplomacy_panel()
    gen_school_panel()
    gen_tech_panel()
    gen_save_load()
    gen_settings()
    gen_new_game()
    gen_victory()
    gen_defeat()

    print(f"\n=== 完成！共 16 个 UI 元素 ===")
    print(f"输出: {OUT_DIR}")
    print("规格: 像素风 | 战国色谱 | 水墨黑底 | 竹简黄边框")
    print("\n请在本地查看 ui/ 目录即可。")

if __name__ == "__main__":
    generate_all()
