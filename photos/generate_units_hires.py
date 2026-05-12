"""
《山河策》1024x1024 像素风兵种生成器 V5
19 基础兵种 + 7 国家特色兵种 = 26 个，每个独特造型
运行: python generate_units_hires.py
"""

import os, math, random
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "unit")
os.makedirs(OUT_DIR, exist_ok=True)

SZ = 64
WHITE = (255, 255, 255)

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
    "水面": [(40,80,130),(60,110,170),(25,55,100),(15,35,70)],
}
SK = [(200,160,120),(220,185,145),(160,120,85),(130,95,65)]
IR = [(140,140,145),(175,175,180),(100,100,105),(65,65,70)]
BR = [(160,130,80),(190,160,100),(120,95,55),(80,60,35)]
RD = [(160,45,35),(195,65,50),(120,30,20),(80,18,12)]
FU = [(160,130,90),(185,155,115),(130,100,65),(90,70,45)]

def save(img, name):
    img.resize((1024,1024), Image.NEAREST).save(os.path.join(OUT_DIR, f"{name}.png"))
    print(f"  [OK] {name}.png")

def pb(d,x,y,w,h,c):
    d.rectangle([x,y,x+w-1,y+h-1], fill=c)

def dot(d,x,y,c):
    d.point((x,y), fill=c)

def draw_limb(d, x1,y1, x2,y2, c, w=3):
    d.line([(x1,y1),(x2,y2)], fill=c, width=w)

def draw_head(d, cx, cy, r, c_skin, c_hair):
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=c_skin)
    d.ellipse([cx-r, cy-r, cx+r, cy-r//2], fill=c_hair)

def draw_body(d, x1,y1, x2,y2, c):
    w = abs(x2-x1)
    d.polygon([(x1,y1),(x2,y1),(x2+w//4,y2),(x1-w//4,y2)], fill=c)

def draw_horse(d, x, y, c_body, c_detail, c_hoof, facing=1):
    """画一匹马，facing: 1=右, -1=左"""
    # 马身
    d.polygon([(x,y),(x+20*facing,y-3),(x+22*facing,y+10),(x-2*facing,y+12)], fill=c_body)
    pb(d, x+1,y+1, 18,7, c_detail)
    # 马头
    hx = x - 6*facing
    d.polygon([(hx,y-6),(hx+8*facing,y-8),(hx+10*facing,y+2),(hx+2*facing,y+4)], fill=c_body)
    pb(d, hx+1*facing,y-5, 7,8, c_detail)
    dot(d, hx+3*facing,y-2, (20,20,20))
    pb(d, hx-1*facing,y, 3,3, c_hoof)
    # 马腿
    draw_limb(d, x+4,y+10, x+3,y+20, c_hoof, 3)
    draw_limb(d, x+16,y+10, x+17,y+20, c_hoof, 3)
    pb(d, x+1,y+18, 4,3, c_hoof)
    pb(d, x+15,y+18, 4,3, c_hoof)
    # 马尾
    draw_limb(d, x+22*facing,y+4, x+28*facing,y-2, c_hoof, 3)
    draw_limb(d, x+28*facing,y-2, x+32*facing,y-6, c_hoof, 2)

# ══════════════════════════════════════════════════════════
#  步兵类（5 种）
# ══════════════════════════════════════════════════════════

def draw_militia(img, draw, pal):
    """民兵 - 农夫征召，手持农具/木棍，畏缩姿态
    最基础单位，布衣无甲，武器简陋"""
    b,h,s,d_ = pal
    # 腿（站立不稳，微曲）
    draw_limb(draw, 28,42, 24,56, SK[0], 3)
    draw_limb(draw, 32,42, 36,56, SK[0], 3)
    pb(draw, 22,54, 5,3, BR[2])
    pb(draw, 34,54, 5,3, BR[2])
    # 身体（简陋布衣，瘦弱）
    draw_body(draw, 26,26, 34,42, BR[1])
    pb(draw, 27,27, 7,14, BR[0])
    # 头（畏缩低头）
    draw_head(draw, 30,20, 5, SK[0], BR[2])
    # 表情（害怕）- 用小点表示
    dot(draw, 28,21, (20,20,20))
    dot(draw, 32,21, (20,20,20))
    # 左臂（缩在身侧）
    draw_limb(draw, 26,30, 20,36, SK[0], 2)
    # 右臂举木棍（歪歪斜斜）
    draw_limb(draw, 34,28, 42,16, SK[0], 2)
    # 木棍（弯的）
    for i in range(18):
        wobble = int(math.sin(i*0.5)*1)
        dot(draw, 42+i//2+wobble, 16-i, BR[2])
    # 补丁衣服
    pb(draw, 28,32, 3,3, BR[2])
    pb(draw, 31,36, 2,2, BR[2])

def draw_infantry(img, draw, pal):
    """步兵 - 防御蹲姿，盾牌前顶，矛斜刺"""
    b,h,s,d_ = pal
    draw_limb(draw, 28,42, 20,56, s, 4)
    draw_limb(draw, 32,42, 40,56, s, 4)
    pb(draw, 18,54, 6,4, d_)
    pb(draw, 38,54, 6,4, d_)
    draw_body(draw, 24,24, 36,42, b)
    pb(draw, 25,25, 11,17, h)
    pb(draw, 20,24, 6,4, d_)
    pb(draw, 36,24, 6,4, d_)
    draw_head(draw, 30,18, 6, SK[0], s)
    pb(draw, 24,12, 12,3, d_)
    pb(draw, 30,8, 2,5, RD[0])
    draw_limb(draw, 22,26, 8,30, b, 3)
    pb(draw, 2,20, 10,20, IR[2])
    pb(draw, 3,21, 8,18, IR[1])
    pb(draw, 6,26, 3,8, IR[0])
    draw_limb(draw, 38,26, 52,18, b, 3)
    for i in range(24):
        dot(draw, 52-i//2, 18-i, BR[0])
    pb(draw, 37,2, 4,4, IR[0])

def draw_spear(img, draw, pal):
    """枪刺兵 - 密集长矛方阵，三排长矛交错前刺
    反骑兵专用，超长矛（3-5米），阵列感"""
    b,h,s,d_ = pal
    # 腿（并排站立，方阵感）
    draw_limb(draw, 28,42, 24,56, s, 4)
    draw_limb(draw, 32,42, 36,56, s, 4)
    pb(draw, 22,54, 6,4, d_)
    pb(draw, 34,54, 6,4, d_)
    # 身体（挺直，方阵整齐感）
    draw_body(draw, 24,24, 36,42, b)
    pb(draw, 25,25, 11,16, h)
    # 肩甲
    pb(draw, 20,24, 6,5, d_)
    pb(draw, 36,24, 6,5, d_)
    # 头（整齐头盔）
    draw_head(draw, 30,18, 6, SK[0], s)
    pb(draw, 24,12, 12,4, d_)
    # 红缨
    pb(draw, 29,6, 3,7, RD[0])
    pb(draw, 30,4, 2,3, RD[1])
    # 左臂扶矛杆
    draw_limb(draw, 22,28, 14,32, b, 3)
    pb(draw, 12,30, 4,4, SK[0])
    # 右臂持矛（三根长矛交错）
    draw_limb(draw, 38,26, 56,8, b, 3)
    # 主矛（最长，5米感）
    for i in range(36):
        dot(draw, 56+i, 8-i//2, BR[0])
    pb(draw, 90,0, 4,4, IR[0])
    # 第二根矛（稍短，角度略不同）
    for i in range(30):
        dot(draw, 54+i, 10-i//2, BR[1])
    pb(draw, 82,4, 3,3, IR[1])
    # 第三根矛（更短）
    for i in range(24):
        dot(draw, 52+i, 12-i//2, BR[2])
    pb(draw, 74,6, 3,3, IR[2])
    # 矛杆纹理
    for i in range(0,36,6):
        dot(draw, 56+i, 8-i//2, BR[2])

def draw_scout(img, draw, pal):
    """斥候小队 - 弯腰潜行，匕首在手，警觉张望
    高视野（4），轻装快速"""
    b,h,s,d_ = pal
    # 腿（弯腰半蹲，轻步）
    draw_limb(draw, 30,42, 20,54, s, 3)
    draw_limb(draw, 32,42, 40,50, s, 3)
    pb(draw, 18,52, 5,3, d_)
    pb(draw, 38,48, 5,3, d_)
    # 身体（前倾弯腰）
    draw.polygon([(26,26),(38,24),(36,42),(24,44)], fill=b)
    pb(draw, 27,27, 9,14, h)
    # 头（警觉转头张望）
    draw_head(draw, 36,18, 5, SK[0], s)
    # 眼睛（睁大警觉）
    dot(draw, 38,18, (20,20,20))
    dot(draw, 38,17, WHITE)
    # 左臂（撑地保持平衡）
    draw_limb(draw, 26,30, 16,38, SK[0], 2)
    pb(draw, 14,36, 4,4, SK[0])
    # 右臂握匕首（低姿态）
    draw_limb(draw, 36,28, 44,34, SK[0], 2)
    pb(draw, 44,32, 2,6, IR[0])
    pb(draw, 43,31, 4,2, IR[1])
    # 背上短弓（备用武器）
    pb(draw, 22,26, 3,10, BR[0])
    draw_limb(draw, 22,26, 20,20, BR[1], 2)
    # 披风（轻薄，飘动）
    pb(draw, 24,28, 4,14, s)
    pb(draw, 22,32, 3,10, d_)
    # 视野标记（小眼睛符号表示高视野）
    draw.ellipse([46,14,52,20], outline=BR[1], width=1)
    dot(draw, 49,17, BR[0])

def draw_heavy_infantry(img, draw, pal):
    """铁甲兵 - 全身重甲，缓慢威压，大盾重剑
    重甲高防，移动缓慢但坚不可摧"""
    b,h,s,d_ = pal
    # 腿（沉重步伐，宽距站立）
    draw_limb(draw, 26,42, 16,56, IR[2], 5)
    draw_limb(draw, 34,42, 44,56, IR[2], 5)
    pb(draw, 14,54, 8,4, IR[3])
    pb(draw, 42,54, 8,4, IR[3])
    # 躯干（极宽铁甲）
    pb(draw, 16,20, 30,22, IR[0])
    pb(draw, 17,21, 28,20, IR[1])
    # 铁甲层叠纹理
    for r in range(5):
        pb(draw, 18,22+r*4, 26,1, IR[2])
    # 腰甲
    pb(draw, 18,38, 26,4, IR[2])
    pb(draw, 19,39, 24,2, IR[1])
    # 肩甲（极宽）
    pb(draw, 8,18, 10,8, IR[2])
    pb(draw, 44,18, 10,8, IR[2])
    pb(draw, 9,19, 8,6, IR[1])
    pb(draw, 45,19, 8,6, IR[1])
    # 护颈
    pb(draw, 20,16, 22,5, IR[2])
    # 头（全封闭重盔）
    pb(draw, 20,4, 22,14, IR[0])
    pb(draw, 21,5, 20,12, IR[1])
    pb(draw, 22,10, 18,5, IR[2])
    # 窄视缝
    pb(draw, 26,11, 10,2, IR[3])
    dot(draw, 28,12, SK[1])
    dot(draw, 34,12, SK[1])
    # 盔顶红缨
    pb(draw, 30,-2, 2,8, RD[0])
    pb(draw, 29,-4, 4,3, RD[1])
    # 左臂巨盾（覆盖大半个身体）
    draw_limb(draw, 16,24, 2,28, IR[0], 4)
    pb(draw, 0,14, 14,28, IR[2])
    pb(draw, 1,15, 12,26, IR[1])
    pb(draw, 5,22, 5,12, IR[0])
    # 盾上兽面纹
    pb(draw, 4,22, 3,3, RD[2])
    pb(draw, 8,22, 3,3, RD[2])
    # 右臂重剑
    draw_limb(draw, 46,22, 58,10, IR[0], 4)
    pb(draw, 56,6, 4,14, IR[0])
    pb(draw, 57,4, 4,3, IR[1])

# ══════════════════════════════════════════════════════════
#  骑兵类（5 种）
# ══════════════════════════════════════════════════════════

def draw_scout_cavalry(img, draw, pal):
    """斥候骑兵 - 轻骑飞驰，骑手弯腰低伏减少风阻
    高视野（5），速度最快的地面单位"""
    b,h,s,d_ = pal
    # 马（轻快奔跑）
    draw_horse(draw, 14, 34, b, h, s, facing=1)
    # 马鞍（轻便）
    pb(draw, 18,34, 10,2, BR[1])
    # 骑手（低伏贴马背，减少风阻）
    draw.polygon([(20,22),(32,20),(30,34),(18,36)], fill=b)
    pb(draw, 21,23, 9,10, h)
    # 头（低伏，几乎贴马颈）
    draw_head(draw, 22,18, 4, SK[0], s)
    # 风巾（飘向后方）
    pb(draw, 26,16, 8,2, s)
    pb(draw, 30,14, 6,2, d_)
    pb(draw, 34,12, 4,2, s)
    # 左手缰绳
    draw_limb(draw, 18,26, 10,32, SK[0], 2)
    # 右手短剑（贴身）
    draw_limb(draw, 30,24, 36,28, SK[0], 2)
    pb(draw, 36,26, 2,5, IR[0])
    # 视野标记（大眼睛，表示侦察）
    draw.ellipse([38,10,46,18], outline=BR[1], width=1)
    dot(draw, 42,14, BR[0])
    # 飞尘
    for i in range(4):
        dot(draw, 46+i*2, 52+i, (200,190,170))

def draw_cavalry(img, draw, pal):
    """护卫骑兵 - 战马前蹄扬起，骑手举枪刺杀"""
    b,h,s,d_ = pal
    draw.polygon([(12,38),(44,34),(46,46),(10,48)], fill=b)
    pb(draw, 13,39, 30,8, h)
    draw.polygon([(6,24),(14,22),(16,34),(8,36)], fill=b)
    pb(draw, 7,25, 7,9, h)
    dot(draw, 9,28, (20,20,20))
    pb(draw, 5,28, 3,3, s)
    draw_limb(draw, 14,46, 8,32, s, 3)
    draw_limb(draw, 8,32, 6,28, s, 3)
    draw_limb(draw, 38,46, 40,56, s, 3)
    draw_limb(draw, 42,46, 44,56, s, 3)
    pb(draw, 38,54, 6,4, d_)
    pb(draw, 42,54, 6,4, d_)
    draw_limb(draw, 44,38, 50,30, s, 3)
    draw_limb(draw, 50,30, 54,26, s, 2)
    pb(draw, 18,36, 14,3, BR[2])
    draw_body(draw, 20,18, 32,36, b)
    pb(draw, 21,19, 10,16, h)
    draw_head(draw, 26,12, 5, SK[0], s)
    pb(draw, 21,7, 10,3, d_)
    pb(draw, 25,4, 2,4, RD[0])
    draw_limb(draw, 32,20, 48,10, b, 3)
    for i in range(22):
        dot(draw, 48+i, 10-i//2, BR[0])
    pb(draw, 68,4, 4,4, IR[0])
    draw_limb(draw, 20,22, 12,28, b, 3)

def draw_chariot(img, draw, pal):
    """战车 - 双马奔腾，车上战士挥戈"""
    b,h,s,d_ = pal
    for mx,my,mr in [(4,34,0),(12,32,1)]:
        draw.polygon([(mx,my),(mx+10,my-2),(mx+12,my+8),(mx-2,my+10)], fill=s)
        pb(draw, mx+1,my, 8,6, b)
        draw.polygon([(mx-2,my-4),(mx+4,my-6),(mx+6,my+2),(mx,my+4)], fill=s)
        dot(draw, mx+1,my-2, (20,20,20))
        draw_limb(draw, mx+2,my+8, mx+1,my+16, s, 2)
        draw_limb(draw, mx+8,my+8, mx+9,my+16, s, 2)
    pb(draw, 8,36, 8,2, BR[0])
    for wx in [16,42]:
        draw.ellipse([wx-5,46,wx+5,56], outline=BR[2], width=2)
        dot(draw, wx, 51, BR[0])
    pb(draw, 12,22, 32,24, b)
    pb(draw, 13,23, 30,22, h)
    pb(draw, 12,22, 32,2, s)
    pb(draw, 12,44, 32,2, s)
    pb(draw, 16,10, 8,12, b)
    pb(draw, 17,11, 6,10, h)
    draw_head(draw, 20,6, 4, SK[0], s)
    draw_limb(draw, 14,14, 10,18, SK[0], 2)
    draw.line([(8,19),(14,17)], fill=BR[0], width=1)
    pb(draw, 32,6, 10,16, b)
    pb(draw, 33,7, 8,14, h)
    draw_head(draw, 37,2, 5, SK[0], s)
    pb(draw, 32,-2, 10,5, d_)
    pb(draw, 36,-4, 2,3, RD[0])
    draw_limb(draw, 42,8, 54,-2, b, 3)
    for i in range(16):
        angle = math.radians(-30 + i*8)
        px = int(54 + i*0.8*math.cos(angle))
        py = int(-2 + i*0.8*math.sin(angle))
        dot(draw, px, py, BR[0])
    pb(draw, 58,-8, 6,4, IR[0])

def draw_shock_cavalry(img, draw, pal):
    """突击骑兵 - 全速冲锋，骑枪平举，马披甲
    冲锋首回合加成，动能攻击"""
    b,h,s,d_ = pal
    # 马（全速冲锋，身体拉长）
    draw.polygon([(8,36),(48,32),(50,44),(6,46)], fill=b)
    pb(draw, 9,37, 38,6, h)
    # 马头（前伸冲锋）
    draw.polygon([(0,28),(10,26),(12,38),(2,40)], fill=b)
    pb(draw, 1,29, 8,8, h)
    dot(draw, 3,32, (20,20,20))
    pb(draw, -1,32, 3,3, s)
    # 马铠（覆盖全身）
    for i in range(8):
        pb(draw, 9+i*4,37, 3,6, IR[1])
    # 马面甲
    pb(draw, -1,28, 6,6, IR[0])
    pb(draw, 0,29, 4,4, IR[1])
    # 马腿（全力奔跑）
    draw_limb(draw, 12,44, 4,52, s, 3)
    draw_limb(draw, 4,52, 2,58, s, 3)
    draw_limb(draw, 38,44, 44,52, s, 3)
    draw_limb(draw, 44,52, 48,58, s, 3)
    pb(draw, 0,56, 4,3, IR[2])
    pb(draw, 46,56, 4,3, IR[2])
    # 马尾
    draw_limb(draw, 48,36, 56,28, s, 3)
    # 马鞍
    pb(draw, 18,34, 14,3, BR[2])
    # 骑手（前倾冲锋姿态）
    draw_body(draw, 20,14, 34,34, b)
    pb(draw, 21,15, 12,18, h)
    # 头（铁盔）
    draw_head(draw, 28,8, 5, SK[0], IR[0])
    pb(draw, 23,3, 10,4, IR[1])
    pb(draw, 27,0, 3,4, RD[0])
    # 面甲
    pb(draw, 24,8, 8,4, IR[2])
    dot(draw, 27,10, SK[1])
    dot(draw, 31,10, SK[1])
    # 右臂 - 骑枪平举（向前延伸超长）
    draw_limb(draw, 34,18, 56,14, b, 3)
    for i in range(30):
        dot(draw, 56+i, 14, BR[0])
    pb(draw, 84,12, 5,5, IR[0])
    # 枪旗（小三角旗）
    pb(draw, 70,10, 6,3, RD[0])
    # 左臂拉缰
    draw_limb(draw, 20,20, 10,30, SK[0], 2)
    # 飞尘
    for i in range(6):
        dot(draw, 48+i*2, 50+i, (200,190,170))

def draw_heavy_cavalry(img, draw, pal):
    """重骑兵 - 全身甲胄，马匹高大威猛，缓慢碾压
    最强地面冲击力，速度慢但防御极高"""
    b,h,s,d_ = pal
    # 马（高大壮硕）
    draw.polygon([(10,34),(46,30),(48,44),(8,46)], fill=IR[0])
    pb(draw, 11,35, 34,8, IR[1])
    # 马头（高高昂起，威严）
    draw.polygon([(4,22),(14,20),(16,34),(6,36)], fill=IR[0])
    pb(draw, 5,23, 8,10, IR[1])
    dot(draw, 7,27, (20,20,20))
    # 马全铠
    for i in range(7):
        pb(draw, 11+i*4,35, 3,8, IR[2])
    # 马面全甲
    pb(draw, 3,22, 8,8, IR[2])
    pb(draw, 4,23, 6,6, IR[1])
    dot(draw, 6,26, RD[0])
    # 马腿（粗壮）
    draw_limb(draw, 14,44, 10,56, IR[2], 4)
    draw_limb(draw, 40,44, 44,56, IR[2], 4)
    pb(draw, 8,54, 6,4, IR[3])
    pb(draw, 42,54, 6,4, IR[3])
    # 马尾（铁甲尾）
    draw_limb(draw, 46,34, 52,26, IR[2], 3)
    # 马鞍（华丽）
    pb(draw, 18,32, 16,4, BR[0])
    pb(draw, 19,33, 14,2, BR[1])
    # 骑手（全身铁甲，威压感）
    pb(draw, 16,10, 20,22, IR[0])
    pb(draw, 17,11, 18,20, IR[1])
    for r in range(4):
        pb(draw, 18,13+r*4, 16,1, IR[2])
    # 肩甲（极宽）
    pb(draw, 10,8, 8,8, IR[2])
    pb(draw, 34,8, 8,8, IR[2])
    # 头（重盔+红缨）
    pb(draw, 18,0, 16,10, IR[0])
    pb(draw, 19,1, 14,8, IR[1])
    pb(draw, 20,6, 12,3, IR[2])
    dot(draw, 23,8, SK[1])
    dot(draw, 29,8, SK[1])
    pb(draw, 25,-4, 2,6, RD[0])
    # 右臂重戟
    draw_limb(draw, 36,14, 52,4, IR[0], 4)
    for i in range(20):
        dot(draw, 52+i, 4-i//3, BR[0])
    pb(draw, 70,0, 5,5, IR[1])
    # 左臂拉缰
    draw_limb(draw, 16,16, 8,26, IR[0], 3)

# ══════════════════════════════════════════════════════════
#  弓兵类（3 种）
# ══════════════════════════════════════════════════════════

def draw_archer(img, draw, pal):
    """弓兵 - 后仰拉弓满月，动态感强"""
    b,h,s,d_ = pal
    draw_limb(draw, 34,42, 28,56, s, 4)
    draw_limb(draw, 36,42, 42,56, s, 4)
    pb(draw, 26,54, 6,4, d_)
    pb(draw, 40,54, 6,4, d_)
    draw.polygon([(28,24),(38,22),(40,42),(30,42)], fill=b)
    pb(draw, 29,25, 9,16, h)
    draw_head(draw, 34,16, 6, SK[0], b)
    pb(draw, 28,10, 12,3, h)
    draw_limb(draw, 28,28, 10,22, b, 3)
    for i in range(24):
        angle = math.radians(-70 + i*5.8)
        px = int(10 + 16*math.cos(angle))
        py = int(22 + 16*math.sin(angle))
        dot(draw, px, py, BR[2])
        dot(draw, px+1, py, BR[2])
    draw.line([(10,8),(10,36)], fill=(190,190,170), width=1)
    draw.line([(10,8),(42,24)], fill=(190,190,170), width=1)
    draw.line([(10,36),(42,24)], fill=(190,190,170), width=1)
    draw_limb(draw, 38,26, 44,20, b, 3)
    pb(draw, 42,18, 4,4, SK[0])
    draw.line([(14,22),(44,22)], fill=(110,85,45), width=1)
    pb(draw, 44,20, 4,4, IR[0])
    pb(draw, 40,28, 4,14, s)

def draw_crossbow(img, draw, pal):
    """弩兵 - 半跪上弦，弩机精密，脚踩弩臂拉弦
    区别于弓兵：弩是机械发射，精度更高"""
    b,h,s,d_ = pal
    # 腿（半跪姿势，一脚踩弩臂）
    draw_limb(draw, 28,42, 18,50, s, 4)
    draw_limb(draw, 32,42, 42,52, s, 4)
    pb(draw, 16,48, 6,4, d_)
    pb(draw, 40,50, 6,4, d_)
    # 身体（前倾稳定）
    draw_body(draw, 24,24, 36,42, b)
    pb(draw, 25,25, 11,16, h)
    # 头（专注瞄准）
    draw_head(draw, 30,18, 5, SK[0], s)
    # 瞄准眼（微眯）
    dot(draw, 32,18, (20,20,20))
    # 左臂托弩（水平持弩）
    draw_limb(draw, 22,28, 8,26, b, 3)
    pb(draw, 6,24, 4,4, SK[0])
    # 弩身（横梁+弩臂，精密机械感）
    pb(draw, 2,22, 24,3, BR[0])
    pb(draw, 3,23, 22,1, BR[1])
    # 弩臂（向两侧展开）
    pb(draw, 0,18, 4,6, BR[0])
    pb(draw, 24,18, 4,6, BR[0])
    # 弓弦（拉满挂在牙上）
    draw.line([(1,18),(1,28)], fill=(190,190,170), width=1)
    draw.line([(27,18),(27,28)], fill=(190,190,170), width=1)
    # 箭在槽中
    pb(draw, 2,24, 22,1, (110,85,45))
    pb(draw, 24,23, 3,3, IR[0])
    # 扳机（弩机核心）
    pb(draw, 14,25, 4,4, IR[2])
    pb(draw, 15,26, 2,2, IR[1])
    # 右手扣扳机
    draw_limb(draw, 36,28, 18,26, SK[0], 2)
    # 脚踩弩臂（上弦动作）
    draw_limb(draw, 28,42, 2,20, s, 2)
    # 弩机望山（瞄准器）
    pb(draw, 12,20, 2,3, IR[1])

def draw_horse_archer(img, draw, pal):
    """弓骑兵 - 马上侧身射箭，快速移动射击
    可移动后射击，机动性极强"""
    b,h,s,d_ = pal
    # 马（小跑姿态）
    draw_horse(draw, 12, 36, b, h, s, facing=1)
    # 马鞍
    pb(draw, 16,36, 12,2, BR[1])
    # 骑手（侧身坐马，面向右侧射击）
    draw.polygon([(22,18),(34,16),(32,34),(20,36)], fill=b)
    pb(draw, 23,19, 9,14, h)
    # 头（侧向看目标）
    draw_head(draw, 32,12, 5, SK[0], s)
    # 胡帽
    pb(draw, 27,6, 10,4, FU[0])
    pb(draw, 30,3, 4,4, FU[1])
    # 右臂拉弓（向右方射击）
    draw_limb(draw, 32,22, 48,16, b, 3)
    # 弓（展开）
    for i in range(16):
        angle = math.radians(-60 + i*7.5)
        px = int(50 + 12*math.cos(angle))
        py = int(16 + 12*math.sin(angle))
        dot(draw, px, py, BR[2])
    # 弦
    draw.line([(50,6),(50,26)], fill=(190,190,170), width=1)
    draw.line([(50,6),(48,16)], fill=(190,190,170), width=1)
    draw.line([(50,26),(48,16)], fill=(190,190,170), width=1)
    # 箭
    draw.line([(36,18),(54,14)], fill=(110,85,45), width=1)
    pb(draw, 54,12, 4,4, IR[0])
    # 左手缰绳
    draw_limb(draw, 22,24, 12,32, SK[0], 2)
    # 箭袋（背在身后）
    pb(draw, 20,20, 3,12, s)
    # 飞驰效果
    for i in range(3):
        dot(draw, 44+i*2, 50+i, (200,190,170))

# ══════════════════════════════════════════════════════════
#  攻城类（3 种）
# ══════════════════════════════════════════════════════════

def draw_battering_ram(img, draw, pal):
    """冲车 - 巨木撞车，士兵推车冲锋，撞角前突
    攻城核心，破坏城墙"""
    b,h,s,d_ = pal
    # 车轮（两个大轮）
    for wx in [14,46]:
        draw.ellipse([wx-6,44,wx+6,56], outline=BR[2], width=2)
        dot(draw, wx, 50, BR[0])
    # 车身底盘
    pb(draw, 8,38, 44,8, BR[0])
    pb(draw, 9,39, 42,6, BR[1])
    # 防护顶棚（斜面防落石）
    pb(draw, 10,22, 40,4, BR[2])
    pb(draw, 12,18, 36,4, BR[0])
    # 顶棚斜面（防箭矢落石）
    for i in range(4):
        pb(draw, 12+i,18+i, 36-2*i, 1, BR[1])
    # 巨木撞杆（从车身伸出向前）
    pb(draw, 0,30, 16,4, BR[2])
    pb(draw, 1,31, 14,2, BR[0])
    # 撞角（铁包头，尖锐）
    pb(draw, -4,28, 6,8, IR[0])
    pb(draw, -3,29, 4,6, IR[1])
    pb(draw, -6,30, 3,4, IR[2])
    # 推车士兵（在车后推）
    for sx,sy in [(52,30),(56,32)]:
        pb(draw, sx,sy, 5,10, b)
        pb(draw, sx+1,sy-2, 3,3, SK[0])
        draw_limb(draw, sx,sy+4, sx-4,sy+6, SK[0], 2)
    # 尘土效果
    for i in range(4):
        dot(draw, 56+i*2, 50+i, (180,170,150))
    # 车身铁钉
    for i in range(6):
        dot(draw, 12+i*6, 40, IR[2])

def draw_catapult(img, draw, pal):
    """投石车 - 发射瞬间，石头飞出，配重下落"""
    b,h,s,d_ = pal
    # 底座
    pb(draw, 6,42, 48,10, b)
    pb(draw, 7,43, 46,8, h)
    for wx in [10,50]:
        draw.ellipse([wx-4,48,wx+4,56], outline=IR[2], width=2)
    # 支架A字
    draw_limb(draw, 14,42, 26,18, BR[0], 3)
    draw_limb(draw, 46,42, 34,18, BR[0], 3)
    draw_limb(draw, 26,18, 34,18, BR[2], 3)
    # 投射臂（发射姿态 - 甩起）
    draw_limb(draw, 30,20, 14,6, BR[0], 3)
    draw_limb(draw, 14,6, 8,2, BR[0], 2)
    # 投掷兜
    draw.line([(8,2),(4,0)], fill=s, width=2)
    # 飞出的石弹
    draw.ellipse([48,4,54,10], fill=(150,140,130))
    draw.ellipse([49,5,53,9], fill=(180,170,160))
    # 飞行轨迹
    for i in range(5):
        dot(draw, 44-i*3, 8-i, (200,190,180))
    # 配重
    pb(draw, 32,16, 8,10, IR[2])
    pb(draw, 33,17, 6,8, IR[1])
    # 绞盘
    pb(draw, 26,24, 8,6, BR[2])
    # 操作兵
    pb(draw, 52,30, 6,12, b)
    pb(draw, 53,28, 4,4, SK[0])
    draw_limb(draw, 52,34, 46,28, b, 2)

def draw_siege_crossbow(img, draw, pal):
    """弩炮 - 大型弩机架在旋臂上，可调角度
    精密攻城器械，射程远精度高"""
    b,h,s,d_ = pal
    # 底座（带轮）
    pb(draw, 8,44, 48,8, IR[0])
    pb(draw, 9,45, 46,6, IR[1])
    for wx in [12,48]:
        draw.ellipse([wx-4,48,wx+4,56], outline=IR[2], width=2)
        dot(draw, wx, 52, IR[0])
    # 旋臂支架（可旋转）
    pb(draw, 28,20, 8,24, IR[0])
    pb(draw, 29,21, 6,22, IR[1])
    # 旋转底座
    draw.ellipse([24,40,40,46], outline=IR[2], width=2)
    dot(draw, 32,43, IR[0])
    # 弩臂（向两侧展开，巨型）
    pb(draw, 2,24, 28,4, BR[0])
    pb(draw, 34,24, 28,4, BR[0])
    pb(draw, 3,25, 26,2, BR[1])
    pb(draw, 35,25, 26,2, BR[1])
    # 弩弦（粗弦）
    draw.line([(3,24),(3,32)], fill=(190,190,170), width=2)
    draw.line([(61,24),(61,32)], fill=(190,190,170), width=2)
    # 弩身（导轨）
    pb(draw, 16,28, 32,4, BR[2])
    pb(draw, 17,29, 30,2, BR[0])
    # 巨箭（在弦上）
    pb(draw, 4,30, 50,2, (110,85,45))
    pb(draw, 54,28, 6,6, IR[0])
    pb(draw, 57,29, 4,4, IR[1])
    # 箭尾羽
    pb(draw, 4,29, 4,4, (160,140,100))
    # 绞盘（上弦机构）
    pb(draw, 22,34, 20,8, IR[2])
    pb(draw, 24,35, 16,6, IR[1])
    pb(draw, 30,36, 6,4, IR[0])
    # 瞄准器（望山）
    pb(draw, 30,22, 4,6, BR[1])
    pb(draw, 29,20, 6,3, BR[0])
    # 操作兵（在侧面）
    pb(draw, 0,34, 6,12, b)
    pb(draw, 1,32, 4,4, SK[0])
    draw_limb(draw, 6,38, 14,36, b, 2)

# ══════════════════════════════════════════════════════════
#  水军类（3 种）
# ══════════════════════════════════════════════════════════

def draw_mengchong(img, draw, pal):
    """蒙冲 - 小型快船，蒙牛皮防箭，速度极快
    侦察/突击用，轻型水军"""
    b,h,s,d_ = pal
    # 水面
    for i in range(8):
        y = 50 + i
        draw.line([(4,y),(60,y)], fill=N["水面"][0] if i%2==0 else N["水面"][1], width=1)
    # 船体（尖头快船）
    draw.polygon([(8,36),(56,32),(60,44),(4,48)], fill=BR[0])
    pb(draw, 9,37, 46,6, BR[1])
    # 船头铁撞角
    pb(draw, 4,38, 6,4, IR[0])
    pb(draw, 2,39, 3,2, IR[1])
    # 蒙皮覆盖（牛皮防护）
    pb(draw, 14,30, 36,8, FU[0])
    pb(draw, 15,31, 34,6, FU[1])
    # 皮上铆钉
    for i in range(6):
        dot(draw, 18+i*5, 33, IR[2])
    # 船舱（低矮）
    pb(draw, 20,26, 16,6, BR[2])
    pb(draw, 21,27, 14,4, BR[0])
    # 桅杆
    pb(draw, 28,10, 2,18, BR[2])
    # 小帆（半收）
    pb(draw, 22,12, 8,10, s)
    pb(draw, 23,13, 6,8, d_)
    # 划桨（两侧各2支）
    for ox in [18,38]:
        draw_limb(draw, ox,38, ox-8,46, BR[2], 2)
        pb(draw, ox-10,44, 4,4, BR[1])
    # 船尾舵
    draw_limb(draw, 54,38, 58,44, BR[2], 2)
    pb(draw, 56,42, 4,6, BR[1])
    # 弓箭手（1人，在船头）
    pb(draw, 10,28, 4,8, b)
    pb(draw, 11,26, 3,3, SK[0])
    # 水花
    for i in range(4):
        dot(draw, 4+i*3, 48+i, (100,160,220))

def draw_dayi(img, draw, pal):
    """大翼 - 中型战船，船体宽大，可载多人
    主力战船，攻守兼备"""
    b,h,s,d_ = pal
    # 水面
    for i in range(8):
        y = 50 + i
        draw.line([(2,y),(62,y)], fill=N["水面"][0] if i%2==0 else N["水面"][1], width=1)
    # 船体（宽大）
    draw.polygon([(4,34),(58,30),(62,46),(0,48)], fill=BR[0])
    pb(draw, 5,35, 52,8, BR[1])
    # 船头（龙头装饰）
    pb(draw, 0,34, 6,6, BR[2])
    pb(draw, -2,32, 4,4, RD[0])
    dot(draw, -1,33, (200,200,50))
    # 船尾（翘起）
    pb(draw, 56,30, 8,6, BR[2])
    # 船舷（高护栏）
    pb(draw, 8,28, 48,4, BR[2])
    pb(draw, 9,29, 46,2, BR[0])
    # 船舱（多间）
    for cx in [14,28,42]:
        pb(draw, cx,22, 10,8, BR[2])
        pb(draw, cx+1,23, 8,6, BR[1])
        # 窗
        pb(draw, cx+3,24, 3,3, IR[2])
    # 桅杆（主桅）
    pb(draw, 30,4, 3,20, BR[2])
    # 大帆
    pb(draw, 18,6, 14,14, s)
    pb(draw, 19,7, 12,12, d_)
    # 帆上纹饰
    pb(draw, 23,10, 5,5, RD[0])
    # 战旗
    pb(draw, 32,0, 6,4, RD[0])
    pb(draw, 34,-2, 2,3, RD[1])
    # 划桨（4支）
    for ox in [16,24,36,44]:
        draw_limb(draw, ox,36, ox-6,44, BR[2], 2)
        pb(draw, ox-8,42, 4,4, BR[1])
    # 弓箭手（2人）
    for ax in [16,40]:
        pb(draw, ax,24, 4,6, b)
        pb(draw, ax+1,22, 3,3, SK[0])
    # 水花
    for i in range(5):
        dot(draw, 2+i*3, 48+i, (100,160,220))

def draw_louchuan(img, draw, pal):
    """楼船 - 巨型战船，三层甲板，如移动城堡
    最强水军，可载数百人，但速度最慢"""
    b,h,s,d_ = pal
    # 水面
    for i in range(6):
        y = 54 + i
        draw.line([(0,y),(63,y)], fill=N["水面"][0] if i%2==0 else N["水面"][1], width=1)
    # 船体（巨大）
    draw.polygon([(2,38),(60,34),(64,52),(-2,54)], fill=BR[0])
    pb(draw, 3,39, 56,10, BR[1])
    # 船头（巨型撞角）
    pb(draw, 0,38, 6,8, IR[0])
    pb(draw, -4,40, 5,4, IR[1])
    # 船尾楼
    pb(draw, 54,30, 10,12, BR[2])
    pb(draw, 55,31, 8,10, BR[0])
    # 第一层甲板（底层，划桨层）
    pb(draw, 6,36, 50,6, BR[2])
    for ox in [10,18,26,34,42,50]:
        draw_limb(draw, ox,38, ox-4,46, BR[1], 2)
    # 第二层甲板（战斗层）
    pb(draw, 10,26, 42,8, BR[2])
    pb(draw, 11,27, 40,6, BR[0])
    # 护栏
    pb(draw, 10,24, 42,3, BR[1])
    # 战斗层弓箭手
    for ax in [14,22,30,38,46]:
        pb(draw, ax,26, 3,5, b)
        pb(draw, ax+1,24, 2,3, SK[0])
    # 第三层甲板（指挥层）
    pb(draw, 18,16, 26,8, BR[2])
    pb(draw, 19,17, 24,6, BR[0])
    # 指挥舱
    pb(draw, 22,12, 18,6, BR[2])
    pb(draw, 23,13, 16,4, BR[0])
    # 指挥官
    pb(draw, 28,8, 6,8, b)
    pb(draw, 29,6, 4,4, SK[0])
    # 主桅杆（极高）
    pb(draw, 30,0, 3,16, BR[2])
    # 巨帆
    pb(draw, 20,2, 12,12, s)
    pb(draw, 21,3, 10,10, d_)
    # 帆上大旗
    pb(draw, 24,4, 5,5, RD[0])
    # 多面战旗
    for fx,fy in [(32,0),(56,28),(2,34)]:
        pb(draw, fx,fy, 4,3, RD[0])
        pb(draw, fx+2,fy-2, 2,3, RD[1])
    # 舷墙垛口（城垛感）
    for i in range(10):
        pb(draw, 8+i*5,22, 3,3, BR[2])

# ══════════════════════════════════════════════════════════
#  七国特色兵种
# ══════════════════════════════════════════════════════════

def draw_ruishi(img, draw, pal):
    """秦锐士 - 前进压迫姿态，盾墙推进，红缨如林"""
    b,h,s,d_ = pal
    draw_limb(draw, 28,42, 18,56, IR[2], 5)
    draw_limb(draw, 32,42, 42,56, IR[2], 5)
    pb(draw, 16,54, 6,4, IR[3])
    pb(draw, 40,54, 6,4, IR[3])
    pb(draw, 18,20, 28,22, IR[0])
    pb(draw, 19,21, 26,20, IR[1])
    for r in range(5): pb(draw, 20,22+r*4, 24,1, IR[2])
    pb(draw, 24,24, 16,6, IR[2])
    pb(draw, 26,25, 12,4, RD[0])
    pb(draw, 12,18, 8,8, IR[2])
    pb(draw, 44,18, 8,8, IR[2])
    pb(draw, 13,19, 6,6, IR[1])
    pb(draw, 45,19, 6,6, IR[1])
    pb(draw, 20,6, 24,14, IR[0])
    pb(draw, 21,7, 22,12, IR[1])
    pb(draw, 22,12, 20,5, IR[2])
    dot(draw, 28,14, RD[0])
    dot(draw, 29,14, RD[0])
    dot(draw, 36,14, RD[0])
    dot(draw, 37,14, RD[0])
    for dx in [-2,0,2,4]:
        pb(draw, 31+dx, -2, 1, 8, RD[0])
        pb(draw, 31+dx, -4, 1, 3, RD[1])
    draw_limb(draw, 18,24, 4,28, IR[0], 4)
    pb(draw, 0,18, 12,24, IR[2])
    pb(draw, 1,19, 10,22, IR[1])
    pb(draw, 5,24, 3,10, IR[0])
    draw_limb(draw, 46,22, 58,14, IR[0], 3)
    for i in range(28):
        dot(draw, 58+i, 14-i//3, BR[0])
    pb(draw, 84,6, 5,5, IR[1])

def draw_hufu(img, draw, pal):
    """赵胡服骑兵 - 回身射（帕提亚射法），马在飞奔"""
    b,h,s,d_ = pal
    draw.polygon([(8,36),(48,32),(50,44),(6,46)], fill=b)
    pb(draw, 9,37, 38,6, h)
    draw.polygon([(0,28),(10,26),(12,38),(2,40)], fill=b)
    pb(draw, 1,29, 8,8, h)
    dot(draw, 3,32, (20,20,20))
    pb(draw, -1,32, 3,3, s)
    draw_limb(draw, 12,44, 4,52, s, 3)
    draw_limb(draw, 4,52, 2,58, s, 3)
    draw_limb(draw, 18,44, 16,54, s, 3)
    draw_limb(draw, 38,44, 44,52, s, 3)
    draw_limb(draw, 44,52, 48,58, s, 3)
    draw_limb(draw, 44,44, 50,54, s, 3)
    draw_limb(draw, 48,36, 56,28, s, 3)
    draw_limb(draw, 56,28, 60,22, s, 2)
    pb(draw, 18,34, 14,3, BR[2])
    draw.polygon([(24,16),(36,14),(34,34),(22,36)], fill=b)
    pb(draw, 25,17, 9,16, h)
    draw_head(draw, 36,10, 5, SK[0], FU[0])
    pb(draw, 31,4, 10,4, FU[0])
    pb(draw, 34,1, 4,4, FU[1])
    draw_limb(draw, 34,20, 48,14, b, 3)
    for i in range(16):
        angle = math.radians(60 + i*5)
        px = int(52 + 12*math.cos(angle))
        py = int(14 + 12*math.sin(angle))
        dot(draw, px, py, BR[2])
    draw.line([(52,6),(52,26)], fill=(190,190,170), width=1)
    draw.line([(52,6),(48,14)], fill=(190,190,170), width=1)
    draw.line([(52,26),(48,14)], fill=(190,190,170), width=1)
    draw.line([(38,18),(56,10)], fill=(110,85,45), width=1)
    pb(draw, 56,8, 4,4, IR[0])
    draw_limb(draw, 22,22, 14,30, SK[0], 2)

def draw_jiji(img, draw, pal):
    """齐技击 - 闪避腾挪，侧身格挡反击"""
    b,h,s,d_ = pal
    draw_limb(draw, 36,40, 24,56, s, 4)
    draw_limb(draw, 38,42, 50,52, s, 4)
    pb(draw, 22,54, 6,4, d_)
    pb(draw, 48,50, 6,4, d_)
    draw.polygon([(30,20),(42,18),(44,40),(32,42)], fill=b)
    pb(draw, 31,21, 10,18, h)
    draw_head(draw, 38,12, 6, SK[0], h)
    pb(draw, 33,4, 10,5, h)
    pb(draw, 35,1, 6,4, d_)
    draw_limb(draw, 42,22, 54,8, b, 3)
    pb(draw, 52,4, 3,12, IR[0])
    pb(draw, 53,2, 3,3, IR[1])
    for i in range(6):
        angle = math.radians(30 + i*50)
        px = int(56 + 6*math.cos(angle))
        py = int(4 + 6*math.sin(angle))
        dot(draw, px, py, (255,220,100))
    draw_limb(draw, 30,28, 16,38, b, 3)
    pb(draw, 14,36, 3,10, IR[0])
    pb(draw, 13,34, 5,3, IR[1])
    pb(draw, 28,34, 2,8, IR[2])
    pb(draw, 27,33, 4,2, BR[0])

def draw_shenxi(img, draw, pal):
    """楚申息之师 - 双刀旋风斩，身体旋转"""
    b,h,s,d_ = pal
    draw_limb(draw, 30,42, 16,58, s, 4)
    draw_limb(draw, 32,42, 48,54, s, 4)
    pb(draw, 14,56, 6,4, d_)
    pb(draw, 46,52, 6,4, d_)
    draw.polygon([(24,18),(40,16),(38,40),(22,42)], fill=b)
    pb(draw, 25,19, 13,20, h)
    for r in range(4):
        pb(draw, 27,21+r*4, 9,1, RD[2])
    pb(draw, 18,16, 7,6, RD[0])
    pb(draw, 39,16, 7,6, RD[0])
    pb(draw, 16,14, 3,4, RD[1])
    pb(draw, 45,14, 3,4, RD[1])
    draw_head(draw, 34,10, 6, SK[0], s)
    pb(draw, 28,0, 12,7, h)
    pb(draw, 30,-4, 8,5, d_)
    pb(draw, 32,-8, 4,5, RD[0])
    draw_limb(draw, 28,4, 20,0, RD[0], 2)
    draw_limb(draw, 20,0, 14,-4, RD[0], 2)
    draw_limb(draw, 40,20, 56,4, b, 3)
    pb(draw, 54,0, 3,12, IR[0])
    pb(draw, 55,-2, 3,3, IR[1])
    for i in range(8):
        angle = math.radians(-40 + i*10)
        px = int(58 + 6*math.cos(angle))
        py = int(0 + 6*math.sin(angle))
        dot(draw, px, py, (200,200,210))
    draw_limb(draw, 22,22, 6,36, b, 3)
    pb(draw, 4,34, 3,12, IR[0])
    pb(draw, 3,32, 5,3, IR[1])
    for i in range(8):
        angle = math.radians(140 + i*10)
        px = int(4 + 6*math.cos(angle))
        py = int(36 + 6*math.sin(angle))
        dot(draw, px, py, (200,200,210))

def draw_wuzu(img, draw, pal):
    """魏武卒 - 操十二石重弩射击，三重甲"""
    b,h,s,d_ = pal
    draw_limb(draw, 28,42, 18,52, IR[2], 5)
    draw_limb(draw, 34,44, 44,52, IR[2], 5)
    pb(draw, 16,50, 8,6, IR[3])
    pb(draw, 42,50, 8,6, IR[3])
    pb(draw, 16,18, 30,24, IR[0])
    pb(draw, 17,19, 28,22, IR[1])
    for r in range(5): pb(draw, 18,20+r*4, 26,1, IR[2])
    pb(draw, 24,24, 12,6, BR[0])
    pb(draw, 25,25, 10,4, BR[1])
    pb(draw, 10,16, 8,7, IR[2])
    pb(draw, 44,16, 8,7, IR[2])
    pb(draw, 20,4, 22,14, IR[0])
    pb(draw, 21,5, 20,12, IR[1])
    pb(draw, 22,10, 18,5, IR[2])
    dot(draw, 27,12, SK[1])
    dot(draw, 35,12, SK[1])
    pb(draw, 18,8, 3,8, IR[2])
    pb(draw, 41,8, 3,8, IR[2])
    pb(draw, 30,-2, 2,8, RD[0])
    pb(draw, 4,26, 40,4, BR[0])
    pb(draw, 5,27, 38,2, BR[1])
    pb(draw, 0,20, 6,4, BR[0])
    pb(draw, 42,20, 6,4, BR[0])
    pb(draw, 0,18, 3,6, BR[2])
    pb(draw, 45,18, 3,6, BR[2])
    draw.line([(1,20),(1,30)], fill=(190,190,170), width=1)
    draw.line([(47,20),(47,30)], fill=(190,190,170), width=1)
    pb(draw, 4,28, 38,1, (110,85,45))
    pb(draw, 42,27, 4,3, IR[0])
    draw_limb(draw, 46,22, 50,26, IR[0], 3)
    pb(draw, 48,24, 4,4, SK[0])
    draw_limb(draw, 14,22, 6,26, IR[0], 3)
    pb(draw, 4,24, 4,4, SK[0])
    dot(draw, 48,10, SK[1])

def draw_liaodong(img, draw, pal):
    """燕辽东突骑 - 下马持长矛侦察，皮毛披风"""
    b,h,s,d_ = pal
    draw_limb(draw, 30,42, 22,56, s, 4)
    draw_limb(draw, 34,42, 42,50, s, 4)
    pb(draw, 20,54, 6,4, d_)
    pb(draw, 40,48, 6,4, d_)
    draw.polygon([(24,22),(38,20),(36,42),(22,44)], fill=b)
    pb(draw, 25,23, 11,18, h)
    pb(draw, 18,18, 10,28, FU[0])
    pb(draw, 14,22, 6,24, FU[1])
    pb(draw, 10,26, 5,20, FU[2])
    draw_limb(draw, 18,18, 12,14, FU[0], 3)
    pb(draw, 24,36, 14,3, FU[2])
    pb(draw, 25,37, 12,1, FU[1])
    draw_head(draw, 32,14, 6, SK[0], s)
    pb(draw, 26,8, 12,4, FU[0])
    pb(draw, 28,5, 8,4, FU[1])
    pb(draw, 24,10, 3,8, FU[0])
    pb(draw, 37,10, 3,8, FU[0])
    draw_limb(draw, 38,24, 52,12, b, 3)
    for i in range(30):
        dot(draw, 52+i//2, 12-i, BR[0])
    pb(draw, 66,0, 4,4, IR[0])
    draw_limb(draw, 24,26, 16,30, b, 3)
    pb(draw, 14,28, 4,4, SK[0])
    pb(draw, 28,14, 3,12, s)

def draw_jingnu(img, draw, pal):
    """韩劲弩 - 巨型弩炮发射瞬间，弩臂震动"""
    b,h,s,d_ = pal
    pb(draw, 4,46, 56,8, IR[0])
    pb(draw, 5,47, 54,6, IR[1])
    for wx in [8,56]:
        draw.ellipse([wx-5,50,wx+5,58], outline=IR[2], width=2)
        dot(draw, wx, 54, IR[0])
    pb(draw, 10,12, 6,34, IR[0])
    pb(draw, 48,12, 6,34, IR[0])
    pb(draw, 11,13, 4,32, IR[1])
    pb(draw, 49,13, 4,32, IR[1])
    pb(draw, 8,10, 48,4, IR[2])
    pb(draw, 9,11, 46,2, IR[0])
    pb(draw, 8,28, 48,6, BR[0])
    pb(draw, 9,29, 46,4, BR[1])
    for i in range(3):
        offset = i*2
        pb(draw, 0-offset, 16+offset, 10,4, BR[0])
        pb(draw, 54+offset, 16+offset, 10,4, BR[0])
    for i in range(4):
        dot(draw, 2-i, 18+i, BR[1])
        dot(draw, 62+i, 18+i, BR[1])
    draw.line([(2,18),(2,36)], fill=(190,190,170), width=1)
    draw.line([(62,18),(62,36)], fill=(190,190,170), width=1)
    draw.line([(4,19),(4,35)], fill=(200,200,180), width=1)
    draw.line([(60,19),(60,35)], fill=(200,200,180), width=1)
    for i in range(6):
        pb(draw, 58+i*1, 30, 2,2, BR[2])
    pb(draw, 62,28, 6,6, IR[0])
    pb(draw, 65,29, 4,4, IR[1])
    pb(draw, 58,29, 3,4, (160,140,100))
    pb(draw, 30,24, 4,5, BR[1])
    pb(draw, 29,22, 6,3, BR[0])
    pb(draw, 22,34, 18,8, IR[2])
    pb(draw, 24,35, 14,6, IR[1])
    pb(draw, 29,36, 6,4, IR[0])
    pb(draw, 0,32, 6,14, b)
    pb(draw, 1,30, 4,4, SK[0])
    draw_limb(draw, 6,36, 12,34, b, 2)
    draw.line([(12,34),(20,34)], fill=BR[0], width=1)

# ══════════════════════════════════════════════════════════
def generate_all():
    random.seed(42)
    print("=== 《山河策》兵种 V5 - 全部 26 个 ===\n")

    units = [
        # ── 步兵类 5 ──
        ("unit_militia",        "民兵",           draw_militia,        P["竹简黄"]),
        ("unit_infantry",       "步兵",           draw_infantry,       P["漆器红"]),
        ("unit_spear",          "枪刺兵",         draw_spear,          P["青铜靛"]),
        ("unit_scout",          "斥候小队",       draw_scout,          N["森林"]),
        ("unit_heavy_infantry", "铁甲兵",         draw_heavy_infantry,  P["水墨黑"]),
        # ── 骑兵类 5 ──
        ("unit_scout_cavalry",  "斥候骑兵",       draw_scout_cavalry,  N["森林"]),
        ("unit_cavalry",        "护卫骑兵",       draw_cavalry,        P["青铜靛"]),
        ("unit_chariot",        "战车",           draw_chariot,        P["竹简黄"]),
        ("unit_shock_cavalry",  "突击骑兵",       draw_shock_cavalry,  P["漆器红"]),
        ("unit_heavy_cavalry",  "重骑兵",         draw_heavy_cavalry,  P["水墨黑"]),
        # ── 弓兵类 3 ──
        ("unit_archer",         "弓兵",           draw_archer,         N["森林"]),
        ("unit_crossbow",       "弩兵",           draw_crossbow,       P["青铜靛"]),
        ("unit_horse_archer",   "弓骑兵",         draw_horse_archer,   P["竹简黄"]),
        # ── 攻城类 3 ──
        ("unit_battering_ram",  "冲车",           draw_battering_ram,  P["漆器红"]),
        ("unit_catapult",       "投石车",         draw_catapult,       P["水墨黑"]),
        ("unit_siege_crossbow", "弩炮",           draw_siege_crossbow, N["山地"]),
        # ── 水军类 3 ──
        ("unit_mengchong",      "蒙冲",           draw_mengchong,      N["水面"]),
        ("unit_dayi",           "大翼",           draw_dayi,           N["水面"]),
        ("unit_louchuan",       "楼船",           draw_louchuan,       N["水面"]),
        # ── 七国特色 7 ──
        ("unit_qin_ruishi",     "锐士（秦）",     draw_ruishi,         P["漆器红"]),
        ("unit_zhao_hufu",      "胡服骑兵（赵）", draw_hufu,           P["青铜靛"]),
        ("unit_qi_jiji",        "技击手（齐）",   draw_jiji,           N["森林"]),
        ("unit_chu_shenxi",     "申息之师（楚）", draw_shenxi,         P["竹简黄"]),
        ("unit_wei_wuzu",       "武卒（魏）",     draw_wuzu,           P["水墨黑"]),
        ("unit_yan_liaodong",   "辽东弓骑（燕）", draw_liaodong,       N["山地"]),
        ("unit_han_jingnu",     "劲弩（韩）",     draw_jingnu,         N["森林"]),
    ]

    for fn, label, func, pal in units:
        img = Image.new("RGB", (SZ,SZ), WHITE)
        d = ImageDraw.Draw(img)
        func(img, d, pal)
        save(img, fn)

    print(f"\n=== 完成 {len(units)} 个 ===")
    print("请在本地查看 unit/ 目录即可。")

if __name__ == "__main__":
    generate_all()
