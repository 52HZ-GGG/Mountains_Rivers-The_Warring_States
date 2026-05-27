#!/usr/bin/env python3
"""
生成 100×70 战国大地图 big_map_terrain.json
基于战国七雄历史地理，odd-R 偏移坐标系
"""

import json
import os

W = 100  # cols (q direction roughly)
H = 70   # rows (r direction roughly)

def make_grid(fill="plains"):
    return [[fill for _ in range(W)] for _ in range(H)]

def set_cell(grid, r, c, terrain):
    if 0 <= r < H and 0 <= c < W:
        grid[r][c] = terrain

def fill_rect(grid, r1, c1, r2, c2, terrain):
    for r in range(max(0, r1), min(H, r2)):
        for c in range(max(0, c1), min(W, c2)):
            grid[r][c] = terrain

def draw_river(grid, points):
    """Draw a river along a list of (row, col) waypoints with interpolation."""
    for i in range(len(points) - 1):
        r0, c0 = points[i]
        r1, c1 = points[i + 1]
        steps = max(abs(r1 - r0), abs(c1 - c0), 1)
        for s in range(steps + 1):
            t = s / steps
            r = int(r0 + (r1 - r0) * t)
            c = int(c0 + (c1 - c0) * t)
            set_cell(grid, r, c, "river")
            # Make major rivers 2 cells wide in places
            if (r + c) % 3 == 0:
                set_cell(grid, r + 1, c, "river")
                set_cell(grid, r, c + 1, "river")

def draw_mountain_line(grid, points, thickness=1):
    """Draw mountains along waypoints."""
    for i in range(len(points) - 1):
        r0, c0 = points[i]
        r1, c1 = points[i + 1]
        steps = max(abs(r1 - r0), abs(c1 - c0), 1)
        for s in range(steps + 1):
            t = s / steps
            r = int(r0 + (r1 - r0) * t)
            c = int(c0 + (c1 - c0) * t)
            set_cell(grid, r, c, "mountain")
            if thickness > 1:
                for dr in range(-thickness + 1, thickness):
                    for dc in range(-thickness + 1, thickness):
                        if abs(dr) + abs(dc) < thickness + 1:
                            set_cell(grid, r + dr, c + dc, "mountain")

def fill_forest(grid, r1, c1, r2, c2, density=0.5):
    """Fill area with forest at given density (checkerboard pattern for natural look)."""
    for r in range(max(0, r1), min(H, r2)):
        for c in range(max(0, c1), min(W, c2)):
            if grid[r][c] == "plains":
                if (r * 7 + c * 13) % 100 < density * 100:
                    grid[r][c] = "forest"

def add_pass(grid, r, c):
    """Add a pass at a mountain crossing."""
    set_cell(grid, r, c, "pass")
    set_cell(grid, r, c + 1, "pass")

def add_ford(grid, r, c):
    """Add a ford at a river crossing."""
    set_cell(grid, r, c, "ford")


def generate():
    grid = make_grid("plains")

    # ================================================================
    # 1. OCEAN — 东海岸线 (col 85-99 为海，Shandong 半岛突出)
    # ================================================================
    # 基线：col >= 88 为海
    for r in range(H):
        coastline = 88
        # 渤海凹陷 (rows 15-28)
        if 15 <= r <= 28:
            coastline = 85
        # 山东半岛突出 (rows 30-42)
        if 30 <= r <= 36:
            coastline = 92
        if 37 <= r <= 42:
            coastline = 90
        # 长江口凹陷 (rows 52-56)
        if 52 <= r <= 56:
            coastline = 85
        # 南部海岸
        if r >= 58:
            coastline = 86
        if r >= 62:
            coastline = 84
        for c in range(coastline, W):
            grid[r][c] = "deep_ocean" if c >= coastline + 3 else "shallow_ocean"

    # 齐国半岛细节 — 琅琊、即墨突出
    for r in range(32, 40):
        for c in range(88, 93):
            if r <= 38:
                set_cell(grid, r, c, "plains")
    # 半岛尖端
    for r in range(34, 38):
        for c in range(91, 94):
            set_cell(grid, r, c, "plains")
    # 半岛南部海岸线
    for r in range(39, 44):
        for c in range(87, W):
            grid[r][c] = "shallow_ocean" if c < 90 else "deep_ocean"

    # ================================================================
    # 2. MOUNTAINS — 主要山脉
    # ================================================================

    # 2a. 秦岭 Qinling (东西走向, 约 row 52-56, col 10-45)
    draw_mountain_line(grid, [(52, 8), (53, 15), (54, 22), (54, 30), (53, 38), (52, 45)], thickness=2)
    # 秦岭西段更厚
    for r in range(50, 57):
        for c in range(8, 20):
            if grid[r][c] == "plains" and (r + c) % 3 != 0:
                set_cell(grid, r, c, "mountain")

    # 2b. 太行山 Taihang (南北走向, col 33-37, row 10-55)
    draw_mountain_line(grid, [(10, 34), (20, 35), (30, 34), (40, 35), (50, 34), (55, 35)], thickness=2)

    # 2c. 西部山脉 Longxi/陇山 (col 5-12, 南北走向)
    draw_mountain_line(grid, [(5, 8), (15, 10), (25, 9), (35, 10), (45, 8), (55, 10)], thickness=2)
    # 贺兰山 (col 3-6)
    draw_mountain_line(grid, [(8, 4), (15, 5), (22, 4), (28, 5)], thickness=1)

    # 2d. 阴山 Yinshan (东西, 北部边疆 row 3-6)
    draw_mountain_line(grid, [(4, 15), (4, 25), (5, 35), (4, 45), (5, 55), (4, 65)], thickness=1)
    # 北部加一些山地
    for c in range(20, 70):
        if c % 7 == 0:
            set_cell(grid, 3, c, "mountain")
            set_cell(grid, 5, c, "mountain")

    # 2e. 西南山地 (楚国南部/巴蜀以南)
    for r in range(58, 70):
        for c in range(5, 30):
            if (r * 3 + c * 7) % 5 == 0:
                set_cell(grid, r, c, "mountain")
    draw_mountain_line(grid, [(58, 10), (62, 15), (66, 12), (70, 18)], thickness=1)

    # 2f. 燕山 (燕国北部, row 8-12, col 55-75)
    draw_mountain_line(grid, [(8, 55), (9, 62), (10, 70), (9, 78)], thickness=1)

    # 2g. 齐国泰山 (Shandong 半岛内, row 36-39, col 82-86)
    draw_mountain_line(grid, [(36, 82), (37, 84), (38, 83), (37, 86)], thickness=1)
    set_cell(grid, 37, 84, "mountain")
    set_cell(grid, 36, 85, "mountain")

    # ================================================================
    # 3. RIVERS — 主要河流
    # ================================================================

    # 3a. 黄河 Yellow River (九曲十八弯)
    # 河源(青藏) → 向北入宁夏 → 河套东流 → 南下晋陕峡谷 → 东折出三门峡 → 东北入海
    yellow_river = [
        (30, 3),   # 河源（青海方向）
        (28, 5),   # 西南来
        (24, 6),   # 宁夏段南
        (18, 7),   # 向北到宁夏
        (15, 9),   # 河套西端
        (14, 13),  # 河套北岸东流
        (14, 17),  # 河套东端
        (16, 19),  # 开始向南拐
        (20, 19),  # 南下（晋陕峡谷西侧）
        (26, 18),  # 壶口附近
        (32, 18),  # 继续南
        (38, 19),  # 龙门
        (42, 22),  # 开始东折
        (44, 28),  # 渭河汇入
        (43, 34),  # 过潼关
        (42, 38),  # 中原
        (41, 42),  # 过荥阳
        (40, 46),  # 大梁以北
        (38, 50),  # 继续东
        (36, 55),  # 齐地
        (34, 60),  # 济水
        (32, 66),  # 继续东
        (30, 72),  # 入海段
        (29, 78),  # 接近渤海
        (28, 84),  # 入渤海
    ]
    draw_river(grid, yellow_river)

    # 3b. 渭河 Wei River (黄河最大支流，关中平原)
    wei_river = [
        (48, 6),   # 源头（陇西）
        (47, 10),
        (46, 14),
        (45, 18),  # 天水
        (45, 22),
        (44, 26),  # 咸阳/长安南
        (44, 28),  # 汇入黄河
    ]
    draw_river(grid, wei_river)

    # 3c. 长江 Yangtze River
    # 从巴蜀 → 三峡 → 荆楚 → 东流 → 入海
    yangtze = [
        (58, 3),   # 源头方向
        (57, 8),
        (56, 12),  # 蜀
        (56, 16),  # 成都南
        (56, 20),
        (55, 25),  # 三峡入口
        (54, 30),  # 三峡
        (54, 34),  # 三峡出口
        (54, 38),  # 江陵
        (55, 42),
        (55, 46),  # 云梦泽
        (55, 50),
        (54, 54),  # 鄂
        (53, 58),
        (53, 62),  # 九江
        (53, 66),
        (52, 70),  # 吴地
        (52, 74),
        (53, 78),  # 入海口
        (53, 82),  # 入海
        (53, 85),
    ]
    draw_river(grid, yangtze)

    # 3d. 汉水 Han River (从秦岭南入长江)
    han_river = [
        (56, 28),  # 源头（秦岭南）
        (57, 32),
        (57, 36),
        (56, 40),
        (55, 44),  # 汇入长江
    ]
    draw_river(grid, han_river)

    # 3e. 汾水 Fen River (山西纵谷)
    fen_river = [
        (12, 32),  # 源头（太原北）
        (16, 33),
        (20, 33),
        (25, 32),
        (30, 32),
        (35, 33),
        (40, 32),  # 汇入黄河
    ]
    draw_river(grid, fen_river)

    # 3f. 济水 (齐国，从黄河分出向东)
    ji_river = [
        (36, 56),
        (36, 60),
        (36, 64),
        (36, 68),
        (35, 72),  # 入海
    ]
    draw_river(grid, ji_river)

    # 3g. 漳水 (魏/赵边界)
    zhang_river = [
        (40, 36),
        (41, 40),
        (40, 44),
    ]
    draw_river(grid, zhang_river)

    # 3h. 淮水 (楚国中部，长江黄河之间)
    huai_river = [
        (48, 40),
        (48, 45),
        (48, 50),
        (48, 55),
        (49, 60),
        (48, 65),
        (47, 70),
    ]
    draw_river(grid, huai_river)

    # 3i. 沅水/湘水 (楚国南部，洞庭湖区域)
    xiang_river = [
        (62, 42),  # 源头（湘南）
        (60, 44),
        (58, 46),
        (56, 48),  # 入洞庭/长江
    ]
    draw_river(grid, xiang_river)

    # ================================================================
    # 4. FORESTS — 森林区域
    # ================================================================

    # 4a. 巴蜀森林（四川盆地周围山地）
    fill_forest(grid, 55, 12, 60, 25, density=0.6)

    # 4b. 楚国南方森林（江南丘陵）
    fill_forest(grid, 58, 35, 66, 55, density=0.5)

    # 4c. 秦岭南坡森林
    fill_forest(grid, 56, 10, 59, 40, density=0.4)

    # 4d. 燕国北部森林
    fill_forest(grid, 5, 55, 12, 75, density=0.4)

    # 4e. 太行山西侧零散森林
    fill_forest(grid, 15, 28, 40, 33, density=0.3)

    # 4f. 关中平原边缘零散森林
    fill_forest(grid, 38, 12, 48, 22, density=0.2)

    # 4g. 中原零散森林
    fill_forest(grid, 40, 40, 47, 55, density=0.2)

    # 4h. 齐国南部零散森林
    fill_forest(grid, 38, 70, 43, 82, density=0.2)

    # 4i. 吴越沿海森林
    fill_forest(grid, 55, 65, 62, 82, density=0.3)

    # 4j. 云梦泽区域（湖北，楚地大泽）— 用 marsh
    for r in range(52, 57):
        for c in range(42, 52):
            if grid[r][c] == "plains" and (r * 5 + c * 3) % 4 == 0:
                set_cell(grid, r, c, "marsh")

    # ================================================================
    # 5. DESERT — 北部草原/荒漠
    # ================================================================
    # 河套以北，阴山以北
    fill_rect(grid, 0, 10, 5, 55, "desert")
    # 部分保留 plains（草原）
    for r in range(0, 5):
        for c in range(10, 55):
            if grid[r][c] == "desert" and (r + c) % 3 == 0:
                set_cell(grid, r, c, "plains")

    # ================================================================
    # 6. MARSH — 沼泽/大泽
    # ================================================================
    # 云梦泽已上方处理
    # 巨野泽（鲁西南）
    for r in range(41, 44):
        for c in range(55, 58):
            set_cell(grid, r, c, "marsh")

    # 洞庭湖区
    for r in range(55, 58):
        for c in range(46, 50):
            set_cell(grid, r, c, "marsh")

    # ================================================================
    # 7. PASSES — 关隘
    # ================================================================
    # 函谷关（秦魏之间，col~30, row~43）
    add_pass(grid, 43, 30)
    # 武关（秦楚之间）
    add_pass(grid, 50, 28)
    # 萧关（秦北部门户）
    add_pass(grid, 25, 12)
    # 散关（入蜀要道）
    add_pass(grid, 50, 14)
    # 剑阁/入蜀关
    add_pass(grid, 55, 18)
    # 井陉口（太行山通道，赵地）
    add_pass(grid, 22, 35)
    # 潼关
    add_pass(grid, 43, 32)
    # 雁门关（赵国北部）
    add_pass(grid, 8, 35)
    # 居庸关方向（燕国）
    add_pass(grid, 8, 60)

    # ================================================================
    # 8. FORDS — 渡口
    # ================================================================
    # 黄河主要渡口
    add_ford(grid, 42, 38)  # 蒲津渡
    add_ford(grid, 38, 50)  # 白马津
    add_ford(grid, 34, 60)  # 齐地渡口
    # 长江渡口
    add_ford(grid, 54, 34)  # 三峡出口
    add_ford(grid, 55, 50)  # 鄂地

    # ================================================================
    # 9. 特殊区域修饰
    # ================================================================

    # 9a. 关中平原 — 确保肥沃
    for r in range(40, 50):
        for c in range(15, 30):
            if grid[r][c] == "forest":
                if (r + c) % 4 == 0:
                    pass  # 保留部分森林
                else:
                    set_cell(grid, r, c, "plains")

    # 9b. 中原（华北平原）— 大面积平原
    for r in range(35, 47):
        for c in range(40, 65):
            if grid[r][c] == "forest":
                if (r * 3 + c) % 5 != 0:
                    set_cell(grid, r, c, "plains")

    # 9c. 四川盆地 — 内部平原化
    for r in range(55, 62):
        for c in range(15, 28):
            if grid[r][c] == "mountain":
                pass  # 盆地边缘保留山
            elif grid[r][c] == "forest":
                if c > 17 and c < 26:
                    set_cell(grid, r, c, "plains")

    # 9d. 北部边疆 — 沙漠/草原过渡
    for r in range(0, 8):
        for c in range(55, 85):
            if grid[r][c] == "plains" and (r + c * 3) % 5 == 0:
                set_cell(grid, r, c, "desert")

    return grid


def update_city_coords(cities_data):
    """
    将城市坐标从 30×20 缩放并重新定位到 100×70 的历史位置。
    使用实际的战国地理坐标。
    """
    # 基于战国历史地理的精确坐标 (hex_q, hex_r) → (col, row)
    city_positions = {
        # 秦国 (关中 + 陇西 + 蜀)
        "xianyang":   (22, 44),  # 咸阳 — 渭河北岸
        "yongcheng":  (16, 38),  # 雍城 — 关中西部
        "yueyang":    (26, 40),  # 栎阳 — 关中东北
        "chencang":   (18, 46),  # 陈仓 — 宝鸡
        "longxi":     (10, 36),  # 陇西 — 甘肃
        "shujun":     (18, 56),  # 蜀郡 — 成都
        "nanzheng":   (24, 52),  # 南郑 — 汉中
        "hanzhong":   (20, 50),  # 汉中
        # 楚国 (南方)
        "ying":       (42, 55),  # 郢 — 江陵（楚都）
        "shouchun":   (60, 50),  # 寿春 — 安徽
        "yuancheng":  (38, 52),  # 鄢城 — 宜城
        "chencheng":  (52, 52),  # 陈城 — 淮阳
        "jiangling":  (40, 58),  # 江陵
        "pengcheng":  (62, 46),  # 彭城 — 徐州
        "wu":         (72, 54),  # 吴 — 苏州
        "kuaiji":     (78, 58),  # 会稽 — 绍兴
        "changsha":   (46, 62),  # 长沙
        # 齐国 (山东)
        "linzi":      (76, 34),  # 临淄 — 齐都
        "jimo":       (82, 36),  # 即墨 — 青岛方向
        "yingqiu":    (72, 30),  # 营丘 — 临淄附近
        "donga":      (68, 33),  # 东阿
        "pinglu":     (70, 36),  # 平陆
        "xue":        (72, 38),  # 薛 — 枣庄方向
        "langye":     (80, 38),  # 琅琊 — 胶南
        # 赵国 (河北北部/山西)
        "handan":     (44, 32),  # 邯郸 — 赵都
        "daijun":     (38, 14),  # 代郡 — 大同方向
        "jinyang":    (32, 24),  # 晋阳 — 太原
        "zhongshan":  (46, 20),  # 中山 — 定州
        "yunzhong":   (28, 10),  # 云中 — 呼和浩特
        "yanmen":     (32, 12),  # 雁门 — 代县
        "taoyu":      (48, 28),  # 陶 — 赵地
        # 魏国 (中原)
        "daliang":    (54, 38),  # 大梁 — 开封（魏都）
        "anyi":       (36, 36),  # 安邑 — 夏县（魏旧都）
        "hedong":     (34, 32),  # 河东 — 运城
        "puyang":     (52, 40),  # 濮阳
        "ye":         (46, 36),  # 邺 — 临漳
        "huaxia":     (42, 36),  # 华夏 — 魏地
        # 韩国 (中原西南)
        "xinzheng":   (48, 42),  # 新郑 — 韩都
        "shangdang":  (38, 30),  # 上党 — 长治
        "yiyang":     (40, 42),  # 宜阳
        "yangzhai":   (46, 44),  # 阳禹 — 禹州
        "nanyang":    (42, 48),  # 南阳
        # 燕国 (河北东北/辽东)
        "ji":         (62, 10),  # 蓟 — 北京（燕都）
        "liaoyang":   (78, 8),   # 辽阳
        "liaoxi":     (70, 8),   # 辽西
        "shanggu":    (56, 8),   # 上谷 — 张家口
        "yuyang":     (64, 6),   # 渔阳 — 密云
        # 周天子
        "luoyi":      (38, 44),  # 洛邑 — 洛阳
        # 中立
        "xingtai":    (50, 34),  # 邢台
        "dingtao":    (56, 40),  # 定陶
    }

    for city in cities_data:
        cid = city["id"]
        if cid in city_positions:
            col, row = city_positions[cid]
            city["hex_q"] = col
            city["hex_r"] = row

    return cities_data


def main():
    # Generate terrain
    grid = generate()

    # Build output
    rows_data = []
    for r in range(H):
        row = []
        for c in range(W):
            row.append(grid[r][c])
        rows_data.append(row)

    output = {
        "schema_version": "2.0",
        "description": "大地图 100x70 odd-R 偏移格地形（战国七雄历史地理）",
        "map_width": W,
        "map_height": H,
        "rows": rows_data
    }

    out_path = os.path.join(os.path.dirname(__file__), "..", "data", "big_map_terrain.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    # Stats
    terrain_counts = {}
    for r in range(H):
        for c in range(W):
            t = grid[r][c]
            terrain_counts[t] = terrain_counts.get(t, 0) + 1

    print(f"Generated {W}x{H} big map ({W*H} cells)")
    for t, count in sorted(terrain_counts.items(), key=lambda x: -x[1]):
        print(f"  {t:15s}: {count:5d} ({count*100/(W*H):.1f}%)")

    # Update city coords
    cities_path = os.path.join(os.path.dirname(__file__), "..", "data", "cities.json")
    with open(cities_path, "r", encoding="utf-8") as f:
        cities_data = json.load(f)

    cities = cities_data.get("cities", [])
    updated = update_city_coords(cities)
    cities_data["map_width"] = W
    cities_data["map_height"] = H

    with open(cities_path, "w", encoding="utf-8") as f:
        json.dump(cities_data, f, ensure_ascii=False, indent=2)

    print(f"\nUpdated {len(updated)} city coordinates")
    print("Done!")


if __name__ == "__main__":
    main()
