"""
《山河策》1024x1024 像素风兵种生成器 V4
每个兵种独特造型、动态姿态、有辨识度
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

def line_thick(d, x1,y1, x2,y2, c, w=2):
    d.line([(x1,y1),(x2,y2)], fill=c, width=w)

# ── 画火柴人风格的像素小人，但有体积感 ──
def draw_limb(d, x1,y1, x2,y2, c, w=3):
    """画粗线条肢体"""
    d.line([(x1,y1),(x2,y2)], fill=c, width=w)

def draw_head(d, cx, cy, r, c_skin, c_hair):
    """画圆形头部"""
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=c_skin)
    d.ellipse([cx-r, cy-r, cx+r, cy-r//2], fill=c_hair)

def draw_body(d, x1,y1, x2,y2, c):
    """画梯形身体"""
    w = abs(x2-x1)
    d.polygon([(x1,y1),(x2,y1),(x2+w//4,y2),(x1-w//4,y2)], fill=c)

# ══════════════════════════════════════════════════════════
#  基础兵种
# ══════════════════════════════════════════════════════════

def draw_infantry(img, draw, pal):
    """步兵 - 防御蹲姿，盾牌前顶，矛斜刺"""
    b,h,s,d_ = pal
    # 腿（蹲姿，一前一后）
    draw_limb(draw, 28,42, 20,56, s, 4)
    draw_limb(draw, 32,42, 40,56, s, 4)
    pb(draw, 18,54, 6,4, d_)
    pb(draw, 38,54, 6,4, d_)
    # 身体（前倾）
    draw_body(draw, 24,24, 36,42, b)
    pb(draw, 25,25, 11,17, h)
    # 肩甲
    pb(draw, 20,24, 6,4, d_)
    pb(draw, 36,24, 6,4, d_)
    # 头
    draw_head(draw, 30,18, 6, SK[0], s)
    pb(draw, 24,12, 12,3, d_)
    pb(draw, 30,8, 2,5, RD[0])
    # 左臂 - 盾牌前顶（向前伸出）
    draw_limb(draw, 22,26, 8,30, b, 3)
    # 大盾（立在前方）
    pb(draw, 2,20, 10,20, IR[2])
    pb(draw, 3,21, 8,18, IR[1])
    pb(draw, 6,26, 3,8, IR[0])
    # 右臂 - 长矛斜刺（从身后到前方）
    draw_limb(draw, 38,26, 52,18, b, 3)
    for i in range(24):
        dot(draw, 52-i//2, 18-i, BR[0])
    pb(draw, 37,2, 4,4, IR[0])

def draw_archer(img, draw, pal):
    """弓兵 - 后仰拉弓满月，动态感强"""
    b,h,s,d_ = pal
    # 腿（后仰弓步）
    draw_limb(draw, 34,42, 28,56, s, 4)
    draw_limb(draw, 36,42, 42,56, s, 4)
    pb(draw, 26,54, 6,4, d_)
    pb(draw, 40,54, 6,4, d_)
    # 身体（后仰）
    draw.polygon([(28,24),(38,22),(40,42),(30,42)], fill=b)
    pb(draw, 29,25, 9,16, h)
    # 头（微仰）
    draw_head(draw, 34,16, 6, SK[0], b)
    pb(draw, 28,10, 12,3, h)
    # 左臂 - 推弓（向前伸直）
    draw_limb(draw, 28,28, 10,22, b, 3)
    # 弓身（大弧形）
    for i in range(24):
        angle = math.radians(-70 + i*5.8)
        px = int(10 + 16*math.cos(angle))
        py = int(22 + 16*math.sin(angle))
        dot(draw, px, py, BR[2])
        dot(draw, px+1, py, BR[2])
    # 弦（从弓头到拉弓手）
    draw.line([(10,8),(10,36)], fill=(190,190,170), width=1)
    draw.line([(10,8),(42,24)], fill=(190,190,170), width=1)
    draw.line([(10,36),(42,24)], fill=(190,190,170), width=1)
    # 右臂 - 拉弦到耳边
    draw_limb(draw, 38,26, 44,20, b, 3)
    pb(draw, 42,18, 4,4, SK[0])
    # 箭
    draw.line([(14,22),(44,22)], fill=(110,85,45), width=1)
    pb(draw, 44,20, 4,4, IR[0])
    # 箭袋
    pb(draw, 40,28, 4,14, s)

def draw_cavalry(img, draw, pal):
    """骑兵 - 战马前蹄扬起，骑手举枪刺杀"""
    b,h,s,d_ = pal
    # 马身（倾斜，前蹄扬起）
    draw.polygon([(12,38),(44,34),(46,46),(10,48)], fill=b)
    pb(draw, 13,39, 30,8, h)
    # 马头（高高昂起）
    draw.polygon([(6,24),(14,22),(16,34),(8,36)], fill=b)
    pb(draw, 7,25, 7,9, h)
    dot(draw, 9,28, (20,20,20))
    pb(draw, 5,28, 3,3, s)
    # 马前腿（扬起）
    draw_limb(draw, 14,46, 8,32, s, 3)
    draw_limb(draw, 8,32, 6,28, s, 3)
    # 马后腿
    draw_limb(draw, 38,46, 40,56, s, 3)
    draw_limb(draw, 42,46, 44,56, s, 3)
    pb(draw, 38,54, 6,4, d_)
    pb(draw, 42,54, 6,4, d_)
    # 马尾
    draw_limb(draw, 44,38, 50,30, s, 3)
    draw_limb(draw, 50,30, 54,26, s, 2)
    # 马鞍
    pb(draw, 18,36, 14,3, BR[2])
    # 骑手（举枪前刺）
    draw_body(draw, 20,18, 32,36, b)
    pb(draw, 21,19, 10,16, h)
    draw_head(draw, 26,12, 5, SK[0], s)
    pb(draw, 21,7, 10,3, d_)
    pb(draw, 25,4, 2,4, RD[0])
    # 右臂举枪前刺
    draw_limb(draw, 32,20, 48,10, b, 3)
    for i in range(22):
        dot(draw, 48+i, 10-i//2, BR[0])
    pb(draw, 68,4, 4,4, IR[0])
    # 左臂拉缰
    draw_limb(draw, 20,22, 12,28, b, 3)

def draw_chariot(img, draw, pal):
    """战车 - 双马奔腾，车上战士挥戈"""
    b,h,s,d_ = pal
    # 马匹
    for mx,my,mr in [(4,34,0),(12,32,1)]:
        draw.polygon([(mx,my),(mx+10,my-2),(mx+12,my+8),(mx-2,my+10)], fill=s)
        pb(draw, mx+1,my, 8,6, b)
        draw.polygon([(mx-2,my-4),(mx+4,my-6),(mx+6,my+2),(mx,my+4)], fill=s)
        dot(draw, mx+1,my-2, (20,20,20))
        draw_limb(draw, mx+2,my+8, mx+1,my+16, s, 2)
        draw_limb(draw, mx+8,my+8, mx+9,my+16, s, 2)
    # 轭
    pb(draw, 8,36, 8,2, BR[0])
    # 车轮
    for wx in [16,42]:
        draw.ellipse([wx-5,46,wx+5,56], outline=BR[2], width=2)
        dot(draw, wx, 51, BR[0])
    # 车身
    pb(draw, 12,22, 32,24, b)
    pb(draw, 13,23, 30,22, h)
    pb(draw, 12,22, 32,2, s)
    pb(draw, 12,44, 32,2, s)
    # 驭手
    pb(draw, 16,10, 8,12, b)
    pb(draw, 17,11, 6,10, h)
    draw_head(draw, 20,6, 4, SK[0], s)
    draw_limb(draw, 14,14, 10,18, SK[0], 2)
    draw.line([(8,19),(14,17)], fill=BR[0], width=1)
    # 战士（挥戈劈砍）
    pb(draw, 32,6, 10,16, b)
    pb(draw, 33,7, 8,14, h)
    draw_head(draw, 37,2, 5, SK[0], s)
    pb(draw, 32,-2, 10,5, d_)
    pb(draw, 36,-4, 2,3, RD[0])
    # 挥戈（弧形劈砍）
    draw_limb(draw, 42,8, 54,-2, b, 3)
    for i in range(16):
        angle = math.radians(-30 + i*8)
        px = int(54 + i*0.8*math.cos(angle))
        py = int(-2 + i*0.8*math.sin(angle))
        dot(draw, px, py, BR[0])
    pb(draw, 58,-8, 6,4, IR[0])

def draw_siege(img, draw, pal):
    """攻城器械 - 投石车发射瞬间，石头飞出"""
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
    # 投掷兜（甩出）
    draw.line([(8,2),(4,0)], fill=s, width=2)
    # 飞出的石弹
    draw.ellipse([48,4,54,10], fill=(150,140,130))
    draw.ellipse([49,5,53,9], fill=(180,170,160))
    # 飞行轨迹点
    for i in range(5):
        dot(draw, 44-i*3, 8-i, (200,190,180))
    # 配重
    pb(draw, 32,16, 8,10, IR[2])
    pb(draw, 33,17, 6,8, IR[1])
    # 绞盘
    pb(draw, 26,24, 8,6, BR[2])
    # 操作兵（在后方拉绳）
    pb(draw, 52,30, 6,12, b)
    pb(draw, 53,28, 4,4, SK[0])
    draw_limb(draw, 52,34, 46,28, b, 2)
    draw.line([(46,28),(38,24)], fill=BR[0], width=1)

# ══════════════════════════════════════════════════════════
#  七国特色兵种
# ══════════════════════════════════════════════════════════

def draw_ruishi(img, draw, pal):
    """秦锐士 - 前进压迫姿态，盾墙推进，红缨如林
    百万之军选锐士五万，秦尚红，铁血压迫感"""
    b,h,s,d_ = pal
    # 腿（沉重步伐）
    draw_limb(draw, 28,42, 18,56, IR[2], 5)
    draw_limb(draw, 32,42, 42,56, IR[2], 5)
    pb(draw, 16,54, 6,4, IR[3])
    pb(draw, 40,54, 6,4, IR[3])
    # 躯干（宽厚铁甲）
    pb(draw, 18,20, 28,22, IR[0])
    pb(draw, 19,21, 26,20, IR[1])
    for r in range(5): pb(draw, 20,22+r*4, 24,1, IR[2])
    # 胸甲秦纹
    pb(draw, 24,24, 16,6, IR[2])
    pb(draw, 26,25, 12,4, RD[0])
    # 肩甲（极宽威压）
    pb(draw, 12,18, 8,8, IR[2])
    pb(draw, 44,18, 8,8, IR[2])
    pb(draw, 13,19, 6,6, IR[1])
    pb(draw, 45,19, 6,6, IR[1])
    # 头（全覆面甲，只露双眼红光）
    pb(draw, 20,6, 24,14, IR[0])
    pb(draw, 21,7, 22,12, IR[1])
    pb(draw, 22,12, 20,5, IR[2])
    # 眼缝（红色透出）
    dot(draw, 28,14, RD[0])
    dot(draw, 29,14, RD[0])
    dot(draw, 36,14, RD[0])
    dot(draw, 37,14, RD[0])
    # 红缨（密集如林）
    for dx in [-2,0,2,4]:
        pb(draw, 31+dx, -2, 1, 8, RD[0])
        pb(draw, 31+dx, -4, 1, 3, RD[1])
    # 左臂盾墙（方盾向前推进）
    draw_limb(draw, 18,24, 4,28, IR[0], 4)
    pb(draw, 0,18, 12,24, IR[2])
    pb(draw, 1,19, 10,22, IR[1])
    pb(draw, 5,24, 3,10, IR[0])
    # 右臂长戟前刺
    draw_limb(draw, 46,22, 58,14, IR[0], 3)
    for i in range(28):
        dot(draw, 58+i, 14-i//3, BR[0])
    pb(draw, 84,6, 5,5, IR[1])

def draw_hufu(img, draw, pal):
    """赵胡服骑兵 - 回身射（帕提亚射法），马在飞奔
    赵武灵王胡服骑射，转身向后射箭的骑射经典姿态"""
    b,h,s,d_ = pal
    # 马（全速飞奔，身体拉长）
    draw.polygon([(8,36),(48,32),(50,44),(6,46)], fill=b)
    pb(draw, 9,37, 38,6, h)
    # 马头（前伸）
    draw.polygon([(0,28),(10,26),(12,38),(2,40)], fill=b)
    pb(draw, 1,29, 8,8, h)
    dot(draw, 3,32, (20,20,20))
    pb(draw, -1,32, 3,3, s)
    # 马腿（全部伸展飞奔）
    draw_limb(draw, 12,44, 4,52, s, 3)
    draw_limb(draw, 4,52, 2,58, s, 3)
    draw_limb(draw, 18,44, 16,54, s, 3)
    draw_limb(draw, 38,44, 44,52, s, 3)
    draw_limb(draw, 44,52, 48,58, s, 3)
    draw_limb(draw, 44,44, 50,54, s, 3)
    # 马尾（飘扬）
    draw_limb(draw, 48,36, 56,28, s, 3)
    draw_limb(draw, 56,28, 60,22, s, 2)
    # 马鞍
    pb(draw, 18,34, 14,3, BR[2])
    # 骑手（回身转体）
    # 身体（扭转）
    draw.polygon([(24,16),(36,14),(34,34),(22,36)], fill=b)
    pb(draw, 25,17, 9,16, h)
    # 头（转向后方看目标）
    draw_head(draw, 36,10, 5, SK[0], FU[0])
    # 胡帽
    pb(draw, 31,4, 10,4, FU[0])
    pb(draw, 34,1, 4,4, FU[1])
    # 右臂拉弓（向后方）
    draw_limb(draw, 34,20, 48,14, b, 3)
    # 弓（向后展开）
    for i in range(16):
        angle = math.radians(60 + i*5)
        px = int(52 + 12*math.cos(angle))
        py = int(14 + 12*math.sin(angle))
        dot(draw, px, py, BR[2])
    # 弦
    draw.line([(52,6),(52,26)], fill=(190,190,170), width=1)
    draw.line([(52,6),(48,14)], fill=(190,190,170), width=1)
    draw.line([(52,26),(48,14)], fill=(190,190,170), width=1)
    # 箭（指向后方）
    draw.line([(38,18),(56,10)], fill=(110,85,45), width=1)
    pb(draw, 56,8, 4,4, IR[0])
    # 左手缰绳
    draw_limb(draw, 22,22, 14,30, SK[0], 2)

def draw_jiji(img, draw, pal):
    """齐技击 - 闪避腾挪，侧身格挡反击
    齐国尚武，技击之士善单兵近战，灵活闪避
    区别于步兵正面防御，技击手强调个人身法"""
    b,h,s,d_ = pal
    # 腿（侧身闪避，一腿后撤一腿前弓）
    draw_limb(draw, 36,40, 24,56, s, 4)
    draw_limb(draw, 38,42, 50,52, s, 4)
    pb(draw, 22,54, 6,4, d_)
    pb(draw, 48,50, 6,4, d_)
    # 身体（侧身后仰闪避）
    draw.polygon([(30,20),(42,18),(44,40),(32,42)], fill=b)
    pb(draw, 31,21, 10,18, h)
    # 头（侧闪后仰）
    draw_head(draw, 38,12, 6, SK[0], h)
    # 高冠
    pb(draw, 33,4, 10,5, h)
    pb(draw, 35,1, 6,4, d_)
    # 右臂举剑格挡（挡来自上方的攻击）
    draw_limb(draw, 42,22, 54,8, b, 3)
    pb(draw, 52,4, 3,12, IR[0])
    pb(draw, 53,2, 3,3, IR[1])
    # 格挡火花
    for i in range(6):
        angle = math.radians(30 + i*50)
        px = int(56 + 6*math.cos(angle))
        py = int(4 + 6*math.sin(angle))
        dot(draw, px, py, (255,220,100))
    # 左臂低位反击刺（剑从下往上挑刺）
    draw_limb(draw, 30,28, 16,38, b, 3)
    pb(draw, 14,36, 3,10, IR[0])
    pb(draw, 13,34, 5,3, IR[1])
    # 腰间短剑
    pb(draw, 28,34, 2,8, IR[2])
    pb(draw, 27,33, 4,2, BR[0])

def draw_shenxi(img, draw, pal):
    """楚申息之师 - 双刀旋风斩，身体旋转
    楚虽三户亡秦必楚，楚人剽悍好斗
    区别于步兵和技击手，楚兵双武器旋转攻击"""
    b,h,s,d_ = pal
    # 腿（旋转劈叉）
    draw_limb(draw, 30,42, 16,58, s, 4)
    draw_limb(draw, 32,42, 48,54, s, 4)
    pb(draw, 14,56, 6,4, d_)
    pb(draw, 46,52, 6,4, d_)
    # 身体（旋转扭动）
    draw.polygon([(24,18),(40,16),(38,40),(22,42)], fill=b)
    pb(draw, 25,19, 13,20, h)
    # 楚式花纹
    for r in range(4):
        pb(draw, 27,21+r*4, 9,1, RD[2])
    # 肩甲（外扩）
    pb(draw, 18,16, 7,6, RD[0])
    pb(draw, 39,16, 7,6, RD[0])
    pb(draw, 16,14, 3,4, RD[1])
    pb(draw, 45,14, 3,4, RD[1])
    # 头
    draw_head(draw, 34,10, 6, SK[0], s)
    # 楚式高冠（极高张扬）
    pb(draw, 28,0, 12,7, h)
    pb(draw, 30,-4, 8,5, d_)
    pb(draw, 32,-8, 4,5, RD[0])
    # 冠带飘扬
    draw_limb(draw, 28,4, 20,0, RD[0], 2)
    draw_limb(draw, 20,0, 14,-4, RD[0], 2)
    # 右臂 - 右刀上劈
    draw_limb(draw, 40,20, 56,4, b, 3)
    pb(draw, 54,0, 3,12, IR[0])
    pb(draw, 55,-2, 3,3, IR[1])
    # 右刀光弧
    for i in range(8):
        angle = math.radians(-40 + i*10)
        px = int(58 + 6*math.cos(angle))
        py = int(0 + 6*math.sin(angle))
        dot(draw, px, py, (200,200,210))
    # 左臂 - 左刀下劈
    draw_limb(draw, 22,22, 6,36, b, 3)
    pb(draw, 4,34, 3,12, IR[0])
    pb(draw, 3,32, 5,3, IR[1])
    # 左刀光弧
    for i in range(8):
        angle = math.radians(140 + i*10)
        px = int(4 + 6*math.cos(angle))
        py = int(36 + 6*math.sin(angle))
        dot(draw, px, py, (200,200,210))

def draw_wuzu(img, draw, pal):
    """魏武卒 - 操十二石重弩射击，甲胄层层叠叠
    吴起训练，披三重甲、操十二石弩、日行百里
    区别于秦锐士盾墙，魏武卒以强弩闻名"""
    b,h,s,d_ = pal
    # 腿（半跪稳定射击姿态）
    draw_limb(draw, 28,42, 18,52, IR[2], 5)
    draw_limb(draw, 34,44, 44,52, IR[2], 5)
    pb(draw, 16,50, 8,6, IR[3])
    pb(draw, 42,50, 8,6, IR[3])
    # 三重甲躯干
    pb(draw, 16,18, 30,24, IR[0])
    pb(draw, 17,19, 28,22, IR[1])
    for r in range(5): pb(draw, 18,20+r*4, 26,1, IR[2])
    # 护心镜
    pb(draw, 24,24, 12,6, BR[0])
    pb(draw, 25,25, 10,4, BR[1])
    # 肩甲
    pb(draw, 10,16, 8,7, IR[2])
    pb(draw, 44,16, 8,7, IR[2])
    # 头（重盔）
    pb(draw, 20,4, 22,14, IR[0])
    pb(draw, 21,5, 20,12, IR[1])
    pb(draw, 22,10, 18,5, IR[2])
    dot(draw, 27,12, SK[1])
    dot(draw, 35,12, SK[1])
    pb(draw, 18,8, 3,8, IR[2])
    pb(draw, 41,8, 3,8, IR[2])
    pb(draw, 30,-2, 2,8, RD[0])
    # ── 重弩（十二石弩，占画面主要部分）──
    # 弩身（横在胸前）
    pb(draw, 4,26, 40,4, BR[0])
    pb(draw, 5,27, 38,2, BR[1])
    # 弩臂（向两侧展开）
    pb(draw, 0,20, 6,4, BR[0])
    pb(draw, 42,20, 6,4, BR[0])
    pb(draw, 0,18, 3,6, BR[2])
    pb(draw, 45,18, 3,6, BR[2])
    # 弓弦（拉满）
    draw.line([(1,20),(1,30)], fill=(190,190,170), width=1)
    draw.line([(47,20),(47,30)], fill=(190,190,170), width=1)
    # 箭在弦上
    pb(draw, 4,28, 38,1, (110,85,45))
    pb(draw, 42,27, 4,3, IR[0])
    # 扳机手（右手扣扳机）
    draw_limb(draw, 46,22, 50,26, IR[0], 3)
    pb(draw, 48,24, 4,4, SK[0])
    # 左臂托弩
    draw_limb(draw, 14,22, 6,26, IR[0], 3)
    pb(draw, 4,24, 4,4, SK[0])
    # 瞄准眼睛（专注）
    dot(draw, 48,10, SK[1])

def draw_liaodong(img, draw, pal):
    """燕辽东突骑 - 下马持长矛侦察，皮毛披风飘动
    燕国北方边军，辽东苦寒之地，善近战搏杀
    不同于赵骑射，燕骑更擅长马上冲锋和下马肉搏"""
    b,h,s,d_ = pal
    # 腿（半蹲侦察姿态，一膝微曲）
    draw_limb(draw, 30,42, 22,56, s, 4)
    draw_limb(draw, 34,42, 42,50, s, 4)
    pb(draw, 20,54, 6,4, d_)
    pb(draw, 40,48, 6,4, d_)
    # 身体（微蹲前倾）
    draw.polygon([(24,22),(38,20),(36,42),(22,44)], fill=b)
    pb(draw, 25,23, 11,18, h)
    # 皮毛大披风（飘向左侧）
    pb(draw, 18,18, 10,28, FU[0])
    pb(draw, 14,22, 6,24, FU[1])
    pb(draw, 10,26, 5,20, FU[2])
    draw_limb(draw, 18,18, 12,14, FU[0], 3)
    # 皮毛腰带
    pb(draw, 24,36, 14,3, FU[2])
    pb(draw, 25,37, 12,1, FU[1])
    # 头（皮帽+护耳，警觉转头）
    draw_head(draw, 32,14, 6, SK[0], s)
    pb(draw, 26,8, 12,4, FU[0])
    pb(draw, 28,5, 8,4, FU[1])
    # 护耳
    pb(draw, 24,10, 3,8, FU[0])
    pb(draw, 37,10, 3,8, FU[0])
    # 右臂持长矛（斜持警戒）
    draw_limb(draw, 38,24, 52,12, b, 3)
    for i in range(30):
        dot(draw, 52+i//2, 12-i, BR[0])
    pb(draw, 66,0, 4,4, IR[0])
    # 左臂扶矛杆
    draw_limb(draw, 24,26, 16,30, b, 3)
    pb(draw, 14,28, 4,4, SK[0])
    # 箭袋
    pb(draw, 28,14, 3,12, s)

def draw_jingnu(img, draw, pal):
    """韩劲弩 - 巨型弩炮发射瞬间，弩臂震动
    天下强弓劲弩皆从韩出，射程六百步，精密机械"""
    b,h,s,d_ = pal
    # 底座
    pb(draw, 4,46, 56,8, IR[0])
    pb(draw, 5,47, 54,6, IR[1])
    for wx in [8,56]:
        draw.ellipse([wx-5,50,wx+5,58], outline=IR[2], width=2)
        dot(draw, wx, 54, IR[0])
    # 主支架
    pb(draw, 10,12, 6,34, IR[0])
    pb(draw, 48,12, 6,34, IR[0])
    pb(draw, 11,13, 4,32, IR[1])
    pb(draw, 49,13, 4,32, IR[1])
    # 横梁
    pb(draw, 8,10, 48,4, IR[2])
    pb(draw, 9,11, 46,2, IR[0])
    # 弩身
    pb(draw, 8,28, 48,6, BR[0])
    pb(draw, 9,29, 46,4, BR[1])
    # 弩臂（发射后回弹震动）
    for i in range(3):
        offset = i*2
        pb(draw, 0-offset, 16+offset, 10,4, BR[0])
        pb(draw, 54+offset, 16+offset, 10,4, BR[0])
    # 震动残影
    for i in range(4):
        dot(draw, 2-i, 18+i, BR[1])
        dot(draw, 62+i, 18+i, BR[1])
    # 弦（震动中）
    draw.line([(2,18),(2,36)], fill=(190,190,170), width=1)
    draw.line([(62,18),(62,36)], fill=(190,190,170), width=1)
    draw.line([(4,19),(4,35)], fill=(200,200,180), width=1)
    draw.line([(60,19),(60,35)], fill=(200,200,180), width=1)
    # 飞出的巨箭（正在飞行）
    for i in range(6):
        pb(draw, 58+i*1, 30, 2,2, BR[2])
    pb(draw, 62,28, 6,6, IR[0])
    pb(draw, 65,29, 4,4, IR[1])
    # 箭尾羽
    pb(draw, 58,29, 3,4, (160,140,100))
    # 瞄准器
    pb(draw, 30,24, 4,5, BR[1])
    pb(draw, 29,22, 6,3, BR[0])
    # 绞盘
    pb(draw, 22,34, 18,8, IR[2])
    pb(draw, 24,35, 14,6, IR[1])
    pb(draw, 29,36, 6,4, IR[0])
    # 操作兵（拉绞盘后仰）
    pb(draw, 0,32, 6,14, b)
    pb(draw, 1,30, 4,4, SK[0])
    draw_limb(draw, 6,36, 12,34, b, 2)
    draw.line([(12,34),(20,34)], fill=BR[0], width=1)

# ══════════════════════════════════════════════════════════
def generate_all():
    random.seed(42)
    print("=== 《山河策》兵种 V4 - 独特造型 ===\n")

    units = [
        ("unit_infantry",      "步兵",         draw_infantry, P["漆器红"]),
        ("unit_archer",        "弓兵",         draw_archer,   N["森林"]),
        ("unit_cavalry",       "骑兵",         draw_cavalry,  P["青铜靛"]),
        ("unit_chariot",       "战车",         draw_chariot,  P["竹简黄"]),
        ("unit_siege",         "攻城器械",     draw_siege,    P["水墨黑"]),
        ("unit_qin_ruishi",    "锐士（秦）",   draw_ruishi,   P["漆器红"]),
        ("unit_zhao_hufu",     "胡服骑兵（赵）", draw_hufu,   P["青铜靛"]),
        ("unit_qi_jiji",       "技击手（齐）", draw_jiji,     N["森林"]),
        ("unit_chu_shenxi",    "申息之师（楚）", draw_shenxi, P["竹简黄"]),
        ("unit_wei_wuzu",      "武卒（魏）",   draw_wuzu,     P["水墨黑"]),
        ("unit_yan_liaodong",  "辽东弓骑（燕）", draw_liaodong, N["山地"]),
        ("unit_han_jingnu",    "劲弩（韩）",   draw_jingnu,   N["森林"]),
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
