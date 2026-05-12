"""
《山河策》像素隶书字体生成器
功能：从系统隶书字体渲染像素风中文字符，生成 BMFont + Godot 资源
运行: python generate_pixel_font.py
"""

import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(ROOT, "..", "assets", "fonts")
os.makedirs(ASSETS, exist_ok=True)

# ── 配置 ──
FONT_SRC = "C:/Windows/Fonts/STLITI.TTF"  # 系统隶书
GLYPH_SIZE = 16   # 每个字形渲染尺寸
ATLAS_SIZE = 512  # 图集尺寸
THRESHOLD = 128   # 二值化阈值

# ── 游戏需要的全部中文字符 ──
CHARS_ASCII = "".join(chr(i) for i in range(32, 127))

CHARS_CN = (
    # 数字大写
    "零一二三四五六七八九十百千万亿"
    # 七国 + 基本
    "秦赵齐楚魏燕韩"
    # 兵种
    "民步骑兵枪刺斥候铁甲护卫战车突击重弓弩冲车投石炮蒙大翼楼船锐士胡服技击申息之师武卒辽东劲弩"
    # 地形
    "原森林山河流沼泽关隘浅滩栈道箭城池村镇都邑"
    # 建筑
    "农场矿墙堡市场书院马厩锻造仓寺庙宫室府库"
    # 资源
    "粮金草料精民心口兵力食钱矿匹"
    # 科技
    "基础桥梁浮栈道攻突破冶铁农耕畜牧冶铜青铜器甲胄戈戟"
    # 学派
    "儒法墨道兵纵横家"
    # 内政
    "征收赋税徭役工商渔盐林牧副渔商贾工匠"
    # 外交
    "宣战结盟停战通婚质子贡赋朝觐聘问会盟连横合纵"
    # 战斗
    "攻防速射程视野伤士气暴击闪避反击冲锋伏击包围撤退追击歼灭"
    # 状态
    "溃逃疲惫饥荒瘟疫丰收祥瑞叛乱流民"
    # 季节
    "春夏秋冬"
    # UI
    "回合结束回合开始回合数年春分秋分冬至夏至存读档设"
    # 势力相关
    "称霸覆灭统一灭亡兴衰存亡得失"
    # 事件
    "改革变法中兴盛世衰落动荡战争和平繁荣饥荒洪旱蝗灾地震"
    # 建筑/城市
    "咸阳邯郸临淄郢大梁蓟新郑洛阳长安"
    # 通用
    "天下国家社稷宗庙朝堂战场疆域版图山河版舆图"
    # 操作
    "确认取消返回退出继续重试选择开始游戏暂停加速减速慢快"
    # 人物
    "君王将相士卒臣民百姓"
    # 评价
    "胜败平局投降逃亡覆灭崛起衰落强弱兴亡"
    # 补充常用
    "是否可以不能需要获得失去提升降低增加减少效果持续回合消耗产量收入支出维护升级建造拆除研究解锁"
    "当前总计剩余目标完成失败进行中已未"
    "攻击防御生命移动力视野范围伤害恢复"
    "等级经验值前中后左右上下"
    "第一二三四五六七八九十"
    "回合制策略经营模拟建设养成探索发现征服统治管理指挥率领派遣驻守巡逻侦察"
    "强大弱小精锐普通新老旧破败"
    "将军丞相太尉御史大夫郡守县令"
    "优点缺点长处短处优势劣势"
    "敌友我同盟中立"
    "平原森林山地河流沼泽沙漠湖泊渡口"
    "步骑弓弩车舟船"
    "近远攻防速"
    "锋矢鹤翼方圆偃月长蛇锥形"
    "夜间拂晓黄昏黎明白昼"
    "东西南北中"
    "风火水土雷"
    "金银铜铁锡玉石"
    "牛羊犬豕鸡鸭鹅马"
    "禾麦稻粱黍稷豆麻桑棉"
    "刀枪剑戟斧钺钩叉鞭锏锤抓镋棍槊棒拐流星"
)

# 去重 + 排序
ALL_CHARS = CHARS_ASCII + "".join(sorted(set(CHARS_CN)))

print(f"字符集：ASCII {len(CHARS_ASCII)} + 中文 {len(set(CHARS_CN))} = {len(ALL_CHARS)} 字符")


def render_char(font, ch):
    """渲染单个字符为像素位图"""
    img = Image.new("L", (GLYPH_SIZE, GLYPH_SIZE), 0)
    d = ImageDraw.Draw(img)
    bbox = font.getbbox(ch)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (GLYPH_SIZE - tw) // 2 - bbox[0]
    y = (GLYPH_SIZE - th) // 2 - bbox[1]
    d.text((x, y), ch, font=font, fill=255)
    # 二值化
    pixels = img.load()
    for py in range(GLYPH_SIZE):
        for px in range(GLYPH_SIZE):
            pixels[px, py] = 255 if pixels[px, py] >= THRESHOLD else 0
    return img


def find_char_bounds(img):
    """找到字符实际像素边界"""
    pixels = img.load()
    min_x, min_y, max_x, max_y = GLYPH_SIZE, GLYPH_SIZE, 0, 0
    found = False
    for y in range(GLYPH_SIZE):
        for x in range(GLYPH_SIZE):
            if pixels[x, y] > 0:
                found = True
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
    if not found:
        return 0, 0, 0, 0
    return min_x, min_y, max_x + 1, max_y + 1


def generate():
    font = ImageFont.truetype(FONT_SRC, GLYPH_SIZE)

    # 第一遍：计算所有字形尺寸
    glyphs = []
    for ch in ALL_CHARS:
        img = render_char(font, ch)
        bx0, by0, bx1, by1 = find_char_bounds(img)
        w = bx1 - bx0
        h = by1 - by0
        advance = max(w + 2, GLYPH_SIZE)
        glyphs.append({
            "char": ch,
            "img": img,
            "x": 0, "y": 0,  # 占位
            "w": w, "h": h,
            "xoff": bx0, "yoff": by0,
            "xadvance": advance,
        })

    # 第二遍：打包到图集（简单行排列）
    atlas = Image.new("L", (ATLAS_SIZE, ATLAS_SIZE), 0)
    cx, cy = 1, 1
    row_h = 0
    for g in glyphs:
        if cx + GLYPH_SIZE + 1 > ATLAS_SIZE:
            cx = 1
            cy += row_h + 1
            row_h = 0
        g["x"] = cx
        g["y"] = cy
        # 粘贴字形
        atlas.paste(g["img"], (cx, cy))
        cx += GLYPH_SIZE + 1
        row_h = max(row_h, GLYPH_SIZE)

    # 保存图集 PNG
    atlas_path = os.path.join(ASSETS, "pixel_lishu_0.png")
    atlas.save(atlas_path)
    print(f"\n  [OK] 图集: pixel_lishu_0.png ({ATLAS_SIZE}x{ATLAS_SIZE})")

    # 生成 BMFont .fnt 文件
    fnt_path = os.path.join(ASSETS, "pixel_lishu.fnt")
    with open(fnt_path, "w", encoding="utf-8") as f:
        f.write(f"info face=\"PixelLishu\" size={GLYPH_SIZE} bold=0 italic=0 "
                f"charset=\"\" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1\n")
        f.write(f"common lineHeight={GLYPH_SIZE} base={GLYPH_SIZE} scaleW={ATLAS_SIZE} "
                f"scaleH={ATLAS_SIZE} pages=1 packed=0\n")
        f.write(f"page id=0 file=\"pixel_lishu_0.png\"\n")
        f.write(f"chars count={len(glyphs)}\n")
        for g in glyphs:
            code = ord(g["char"])
            f.write(f"char id={code} x={g['x']} y={g['y']} "
                    f"width={GLYPH_SIZE} height={GLYPH_SIZE} "
                    f"xoffset={g['xoff']} yoffset={g['yoff']} "
                    f"xadvance={g['xadvance']} page=0 chnl=0\n")
    print(f"  [OK] 字体: pixel_lishu.fnt ({len(glyphs)} 字符)")

    # 生成 Godot BitmapFont .tres
    tres_path = os.path.join(ASSETS, "pixel_lishu.tres")
    with open(tres_path, "w", encoding="utf-8") as f:
        f.write('[gd_resource type="BitmapFont" load_steps=2 format=3]\n\n')
        f.write('[ext_resource type="Texture2D" path="res://assets/fonts/pixel_lishu_0.png" id="1"]\n\n')
        f.write('[resource]\n')
        f.write('textures = [ExtResource("1")]\n')
        f.write(f'height = {GLYPH_SIZE}\n')
        # Godot BitmapFont 使用 characters 数组
        # 每个字符: [start_x, start_y, end_x, end_y, texture_idx, width, ...]
        chars_entries = []
        for g in glyphs:
            code = ord(g["char"])
            sx = g["x"]
            sy = g["y"]
            ex = g["x"] + GLYPH_SIZE
            ey = g["y"] + GLYPH_SIZE
            chars_entries.append(
                f'  Vector2i({code}, {g["xadvance"]})  # {g["char"]}'
            )
        # 简化：使用 fallback 字符范围
        # Godot BitmapFont 的 characters 是字典: codepoint -> Character
        # 但 .tres 格式比较复杂，改用 .fnt 导入更可靠
        f.write(f'# 使用 BMFont 格式导入，共 {len(glyphs)} 个字符\n')
        f.write(f'# 在 Godot 中导入 pixel_lishu.fnt 即可\n')

    print(f"  [OK] Godot 提示: pixel_lishu.tres")

    # 生成 Godot 动态字体版本（使用系统字体渲染为像素风）
    dynamic_tres = os.path.join(ASSETS, "pixel_lishu_dynamic.tres")
    with open(dynamic_tres, "w", encoding="utf-8") as f:
        f.write('[gd_resource type="FontVariation" format=3]\n\n')
        f.write('[ext_resource type="FontFile" path="res://assets/fonts/STLITI.TTF" id="1"]\n\n')
        f.write('[resource]\n')
        f.write('base_font = ExtResource("1")\n')
        f.write(f'fixed_size = {GLYPH_SIZE}\n')
        f.write('fixed_size_scale_mode = 0\n')  # Disabled = 像素清晰
    print(f"  [OK] 动态字体: pixel_lishu_dynamic.tres")

    # 复制系统隶书字体到 assets 作为 fallback
    import shutil
    dst_ttf = os.path.join(ASSETS, "STLITI.TTF")
    if not os.path.exists(dst_ttf):
        shutil.copy2(FONT_SRC, dst_ttf)
        print(f"  [OK] 复制: STLITI.TTF (系统隶书)")

    print(f"\n完成！字体文件在 {ASSETS}/")
    print("  - pixel_lishu.fnt     → BMFont 格式（推荐，Godot 直接导入）")
    print("  - pixel_lishu_0.png   → 字形图集")
    print("  - STLITI.TTF          → 系统隶书原文件")
    print("\n在 Godot 中使用方法：")
    print("  1. 导入 pixel_lishu.fnt 后设为 Label/RichTextLabel 的字体")
    print("  2. 或用 STLITI.TTF 创建 FontVariation，设 fixed_size=16")


if __name__ == "__main__":
    generate()
