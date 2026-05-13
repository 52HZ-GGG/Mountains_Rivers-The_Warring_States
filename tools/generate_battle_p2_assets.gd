@tool
extends EditorScript
## 生成 P2 战斗系统 UI 素材：战斗结果指示、特殊攻击、地形叠加、单位状态、射程可视化、面板
## 在 Godot 编辑器中：工具 → 运行脚本

const OUT_ICONS   := "res://assets/ui/icons/"
const OUT_OVERLAY := "res://assets/ui/overlays/"
const OUT_HL      := "res://assets/ui/highlights/"
const OUT_BARS    := "res://assets/ui/bars/"
const OUT_PANELS  := "res://assets/ui/panels/"

# ── 色板 ──
const COL_RED      := Color("D94040")
const COL_ORANGE   := Color("E0943A")
const COL_GOLD     := Color("F5C542")
const COL_GREEN    := Color("4ADE80")
const COL_BLUE     := Color("4A90D9")
const COL_CYAN     := Color("66CCFF")
const COL_PURPLE   := Color("BB44FF")
const COL_WHITE    := Color(1, 1, 1, 0.9)
const COL_DARK     := Color("1A1A2E")
const COL_GRAY     := Color("666666")
const COL_STONE    := Color("8B7355")
const COL_ICE      := Color("AADDFF")

# ── 像素数字字体 (5×7 点阵，0-9) ──
const DIGIT_W := 5
const DIGIT_H := 7
const DIGIT_DATA := [
	# 0
	[0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110],
	# 1
	[0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
	# 2
	[0b01110, 0b10001, 0b00001, 0b00110, 0b01000, 0b10000, 0b11111],
	# 3
	[0b11111, 0b00010, 0b00100, 0b00010, 0b00001, 0b10001, 0b01110],
	# 4
	[0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010],
	# 5
	[0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110],
	# 6
	[0b00110, 0b01000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110],
	# 7
	[0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000],
	# 8
	[0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110],
	# 9
	[0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00010, 0b01100],
]

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_ICONS)
	DirAccess.make_dir_recursive_absolute(OUT_OVERLAY)
	DirAccess.make_dir_recursive_absolute(OUT_HL)
	DirAccess.make_dir_recursive_absolute(OUT_BARS)
	DirAccess.make_dir_recursive_absolute(OUT_PANELS)

	print("=== P2 战斗系统 UI 素材生成 ===")

	_generate_damage_numbers()      # 模块1
	_generate_attack_indicators()   # 模块2
	_generate_terrain_overlays()    # 模块3
	_generate_unit_state_icons()    # 模块4
	_generate_range_highlights()    # 模块5
	_generate_panel_backgrounds()   # 模块6

	print("\n[OK] 全部 P2 素材已生成")

# ══════════════════════════════════════════
# 模块 1：战斗结果指示器
# ══════════════════════════════════════════
func _generate_damage_numbers() -> void:
	print("\n[1/6] 战斗结果指示器：")

	# 0-9 红色伤害数字
	for i in 10:
		var img := _render_digit(i, COL_RED)
		img.save_png(OUT_ICONS + "ui_dmg_num_%d.png" % i)
		print("  ui_dmg_num_%d.png" % i)

	# miss 文字精灵
	var miss := Image.create_empty(24, 16, false, Image.FORMAT_RGBA8)
	_draw_miss_text(miss, COL_WHITE)
	miss.save_png(OUT_ICONS + "ui_dmg_num_miss.png")
	print("  ui_dmg_num_miss.png")

	# 反击指示
	_make_icon_16("ui_icon_counter.png", COL_ORANGE, "counter")
	print("  ui_icon_counter.png")

	# 格挡指示
	_make_icon_16("ui_icon_deflect.png", COL_BLUE, "deflect")
	print("  ui_icon_deflect.png")

func _render_digit(d: int, color: Color) -> Image:
	var img := Image.create_empty(DIGIT_W, DIGIT_H, false, Image.FORMAT_RGBA8)
	var data: Array = DIGIT_DATA[d]
	for y in DIGIT_H:
		var row: int = data[y]
		for x in DIGIT_W:
			if row & (1 << (DIGIT_W - 1 - x)):
				img.set_pixel(x, y, color)
	return img

func _draw_miss_text(img: Image, color: Color) -> void:
	# 简化 "MISS"：用像素点画 M-I-S-S
	# M: 两竖 + V
	var ox := 1
	for y in range(2, 12):
		img.set_pixel(ox, y, color)
		img.set_pixel(ox + 4, y, color)
	img.set_pixel(ox + 1, 3, color)
	img.set_pixel(ox + 2, 4, color)
	img.set_pixel(ox + 3, 3, color)
	# I
	ox = 7
	for y in range(2, 12):
		img.set_pixel(ox, y, color)
	# S
	ox = 10
	for x in range(ox, ox + 3):
		img.set_pixel(x, 2, color)
		img.set_pixel(x, 6, color)
		img.set_pixel(x, 11, color)
	img.set_pixel(ox, 3, color)
	img.set_pixel(ox, 4, color)
	img.set_pixel(ox, 5, color)
	img.set_pixel(ox + 2, 7, color)
	img.set_pixel(ox + 2, 8, color)
	img.set_pixel(ox + 2, 9, color)
	img.set_pixel(ox + 2, 10, color)
	# S (second)
	ox = 15
	for x in range(ox, ox + 3):
		img.set_pixel(x, 2, color)
		img.set_pixel(x, 6, color)
		img.set_pixel(x, 11, color)
	img.set_pixel(ox, 3, color)
	img.set_pixel(ox, 4, color)
	img.set_pixel(ox, 5, color)
	img.set_pixel(ox + 2, 7, color)
	img.set_pixel(ox + 2, 8, color)
	img.set_pixel(ox + 2, 9, color)
	img.set_pixel(ox + 2, 10, color)

func _make_icon_16(filename: String, color: Color, shape: String) -> void:
	var s := 16
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var cx := 8.0
	var cy := 8.0

	match shape:
		"counter":  # 双剑交叉
			for i in 10:
				_safe_px(img, int(cx - 4 + i), int(cy - 4 + i), color)
				_safe_px(img, int(cx + 4 - i), int(cy - 4 + i), color)
			# 剑柄
			_safe_px(img, int(cx - 4), int(cy - 4), color)
			_safe_px(img, int(cx + 4), int(cy - 4), color)
			_safe_px(img, int(cx), int(cy + 4), color)
			_safe_px(img, int(cx), int(cy + 5), color)

		"deflect":  # 盾牌
			for y in range(3, 13):
				var w := 5 - abs(y - 8) / 2
				if w > 0:
					for x in range(int(cx - w), int(cx + w) + 1):
						_safe_px(img, x, y, color)
			# 盾牌中线
			for y in range(4, 11):
				_safe_px(img, int(cx), y, color.darkened(0.3))

# ══════════════════════════════════════════
# 模块 2：特殊攻击指示器
# ══════════════════════════════════════════
func _generate_attack_indicators() -> void:
	print("\n[2/6] 特殊攻击指示器：")

	# 夹击指示
	_make_icon_32("ui_icon_flank.png", COL_RED, "flank")
	print("  ui_icon_flank.png")

	# 火攻指示
	_make_icon_32("ui_icon_fire_atk.png", COL_ORANGE, "fire_atk")
	print("  ui_icon_fire_atk.png")

	# 灼烧 DOT
	_make_icon_16("ui_icon_burn_dot.png", COL_ORANGE, "burn")
	print("  ui_icon_burn_dot.png")

	# 伏击指示
	_make_icon_32("ui_icon_ambush.png", COL_GOLD, "ambush")
	print("  ui_icon_ambush.png")

func _make_icon_32(filename: String, color: Color, shape: String) -> void:
	var s := 32
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var cx := 16.0
	var cy := 16.0

	match shape:
		"flank":  # 双箭头钳形
			# 左箭头（向右）
			for i in 8:
				_safe_px(img, 4 + i, 16, color)
			for i in 4:
				_safe_px(img, 10, 16 - i, color)
				_safe_px(img, 10, 16 + i, color)
			# 右箭头（向左）
			for i in 8:
				_safe_px(img, 28 - i, 16, color)
			for i in 4:
				_safe_px(img, 22, 16 - i, color)
				_safe_px(img, 22, 16 + i, color)
			# 中心目标点
			_safe_px(img, 16, 16, COL_WHITE)
			_safe_px(img, 15, 16, COL_WHITE)
			_safe_px(img, 16, 15, COL_WHITE)
			_safe_px(img, 17, 16, COL_WHITE)
			_safe_px(img, 16, 17, COL_WHITE)

		"fire_atk":  # 火焰剑
			# 剑身
			for i in 14:
				_safe_px(img, int(cx), int(cy - 7 + i), color.darkened(0.2))
			# 剑尖
			_safe_px(img, int(cx), int(cy - 8), color)
			# 护手
			for x in range(int(cx) - 3, int(cx) + 4):
				_safe_px(img, x, int(cy + 4), color.darkened(0.3))
			# 火焰（围绕剑尖）
			for dy in range(-4, 0):
				var w := 3 - abs(dy + 2)
				for x in range(int(cx) - w, int(cx) + w + 1):
					var fire_col := Color(1.0, 0.5 + dy * 0.1, 0.1, 0.7)
					_safe_px(img, x, int(cy - 8 + dy), fire_col)

		"ambush":  # 惊叹号 + 灌木
			# 灌木底部
			for y in range(22, 28):
				var w := 8 - abs(y - 25)
				for x in range(int(cx) - w, int(cx) + w + 1):
					_safe_px(img, x, y, Color(0.2, 0.5, 0.2, 0.6))
			# 惊叹号
			for y in range(6, 16):
				_safe_px(img, int(cx), y, color)
			_safe_px(img, int(cx), 18, color)

func _make_icon_16_burn(filename: String, color: Color) -> void:
	var s := 16
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	# 小火焰
	for y in range(4, 14):
		var w := 4 - abs(y - 9) / 2
		if w > 0:
			for x in range(8 - int(w), 8 + int(w) + 1):
				var t := float(y - 4) / 10.0
				var c := Color(1.0, 0.8 - t * 0.5, 0.1, 0.8)
				_safe_px(img, x, y, c)
	img.save_png(OUT_ICONS + filename)

# ══════════════════════════════════════════
# 模块 3：地形/天气叠加层
# ══════════════════════════════════════════
func _generate_terrain_overlays() -> void:
	print("\n[3/6] 地形/天气叠加层：")

	# 地形修正图标
	_make_icon_16("ui_icon_terrain_atk.png", COL_RED, "terrain_atk")
	print("  ui_icon_terrain_atk.png")
	_make_icon_16("ui_icon_terrain_def.png", COL_BLUE, "terrain_def")
	print("  ui_icon_terrain_def.png")

	# 海拔指示
	_make_icon_16("ui_icon_elev_0.png", COL_GRAY, "elev_0")
	print("  ui_icon_elev_0.png")
	_make_icon_16("ui_icon_elev_1.png", COL_GRAY, "elev_1")
	print("  ui_icon_elev_1.png")
	_make_icon_16("ui_icon_elev_2.png", COL_GRAY, "elev_2")
	print("  ui_icon_elev_2.png")

	# 河流冻结叠加
	_make_overlay_32("ui_overlay_river_frozen.png", COL_ICE, "ice")
	print("  ui_overlay_river_frozen.png")

	# 季节图标
	_make_season_icon("ui_icon_season_spring.png", Color(0.4, 0.8, 0.4), "spring")
	_make_season_icon("ui_icon_season_summer.png", Color(0.9, 0.7, 0.2), "summer")
	_make_season_icon("ui_icon_season_autumn.png", Color(0.85, 0.5, 0.2), "autumn")
	_make_season_icon("ui_icon_season_winter.png", Color(0.6, 0.8, 0.95), "winter")
	print("  ui_icon_season_*.png (x4)")

func _make_overlay_32(filename: String, color: Color, pattern: String) -> void:
	var s := 32
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)

	match pattern:
		"ice":  # 冰晶纹理：交叉线 + 闪烁点
			for y in s:
				for x in s:
					# 菱形网格
					var gx := (x + y) % 8
					var gy := (x - y + 32) % 8
					if gx == 0 or gy == 0:
						var alpha := 0.3 + randf() * 0.2
						img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
					# 随机冰晶点
					elif randf() < 0.05:
						img.set_pixel(x, y, Color(1, 1, 1, 0.4))

	img.save_png(OUT_OVERLAY + filename)

func _make_season_icon(filename: String, color: Color, season: String) -> void:
	var s := 32
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var cx := 16.0
	var cy := 16.0

	# 圆形底色
	_fill_circle(img, cx, cy, 14.0, color * 0.3, 0.4)

	match season:
		"spring":  # 花瓣（十字 + 对角小点）
			for i in range(-4, 5):
				_safe_px(img, int(cx) + i, int(cy), Color(1, 0.7, 0.8, 0.8))
				_safe_px(img, int(cx), int(cy) + i, Color(1, 0.7, 0.8, 0.8))
			_safe_px(img, int(cx) + 3, int(cy) - 3, Color(1, 0.8, 0.3, 0.8))
			_safe_px(img, int(cx) - 3, int(cy) + 3, Color(1, 0.8, 0.3, 0.8))

		"summer":  # 太阳（圆 + 光线）
			_fill_circle(img, cx, cy, 5.0, Color(1, 0.9, 0.3, 0.8), 0.8)
			for i in 8:
				var angle := i * TAU / 8.0
				for r in range(7, 11):
					_safe_px(img, int(cx + cos(angle) * r), int(cy + sin(angle) * r), Color(1, 0.8, 0.2, 0.6))

		"autumn":  # 落叶（三角 + 茎）
			for i in 8:
				var y := int(cy - 4 + i)
				for x in range(int(cx) - i / 2, int(cx) + i / 2 + 1):
					_safe_px(img, x, y, Color(0.85, 0.5, 0.15, 0.8))
			for i in 4:
				_safe_px(img, int(cx), int(cy + 4 + i), Color(0.5, 0.3, 0.1, 0.7))

		"winter":  # 雪花（六线）
			for i in range(-5, 6):
				_safe_px(img, int(cx) + i, int(cy), color)
				_safe_px(img, int(cx), int(cy) + i, color)
				_safe_px(img, int(cx) + i, int(cy) + i, color)
				_safe_px(img, int(cx) + i, int(cy) - i, color)

	img.save_png(OUT_ICONS + filename)

func _fill_circle(img: Image, cx: float, cy: float, r: float, color: Color, alpha: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var dist := Vector2(x - cx, y - cy).length()
			if dist <= r:
				var edge := clampf((r - dist) / 2.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha * edge))

# ══════════════════════════════════════════
# 模块 4：单位状态指示
# ══════════════════════════════════════════
func _generate_unit_state_icons() -> void:
	print("\n[4/6] 单位状态指示：")

	# 补给状态
	_make_supply_icon("ui_icon_supply_ok.png", false)
	_make_supply_icon("ui_icon_supply_cut.png", true)
	print("  ui_icon_supply_ok.png")
	print("  ui_icon_supply_cut.png")

	# 动量条
	_make_bar("ui_bar_momentum_bg.png", 40, 8, COL_DARK, 2)
	_make_momentum_fill()
	print("  ui_bar_momentum_bg.png")
	print("  ui_bar_momentum_fill.png")

	# 城墙血条
	_make_bar("ui_bar_wall_bg.png", 128, 8, COL_DARK, 3)
	_make_wall_fill()
	print("  ui_bar_wall_bg.png")
	print("  ui_bar_wall_fill.png")

	# 搁浅叠加
	_make_overlay_32("ui_overlay_stranded.png", COL_ICE, "ice")
	print("  ui_overlay_stranded.png")

func _make_supply_icon(filename: String, cut: bool) -> void:
	var s := 24
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var color := COL_GREEN if not cut else COL_RED
	var cx := 12
	var cy := 12

	if not cut:
		# 完整锁链：三个链环
		for i in 3:
			var ox := 4 + i * 8
			_draw_chain_link(img, ox, cy, color)
	else:
		# 断裂锁链：两段 + 裂口
		_draw_chain_link(img, 4, cy, color)
		_draw_chain_link(img, 16, cy, color)
		# 断裂标记
		_safe_px(img, 11, 10, COL_WHITE)
		_safe_px(img, 12, 11, COL_WHITE)
		_safe_px(img, 11, 12, COL_WHITE)
		_safe_px(img, 12, 13, COL_WHITE)
		_safe_px(img, 11, 14, COL_WHITE)

	img.save_png(OUT_ICONS + filename)

func _draw_chain_link(img: Image, x: int, y: int, color: Color) -> void:
	# 小椭圆链环
	for a in 12:
		var angle := a * TAU / 12.0
		_safe_px(img, x + int(cos(angle) * 3), y + int(sin(angle) * 2), color)

func _make_momentum_fill() -> void:
	var w := 38
	var h := 6
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	# 灰→金渐变，5 段分隔
	for y in h:
		for x in w:
			var t := float(x) / float(w)
			var seg := int(t * 5.0)
			var seg_t := fmod(t * 5.0, 1.0)
			var base_col := COL_GRAY.lerp(COL_GOLD, t)
			# 分隔线
			if seg_t < 0.1 and x > 0:
				base_col = COL_DARK
			base_col.a = 0.85
			img.set_pixel(x, y, base_col)
	img.save_png(OUT_BARS + "ui_bar_momentum_fill.png")

func _make_wall_fill() -> void:
	var w := 126
	var h := 6
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var t := float(x) / float(w)
			var c := COL_STONE.lerp(COL_STONE.lightened(0.3), t)
			var vert := 1.0 - abs(float(y) / (h / 2.0) - 1.0) * 0.3
			c = c * vert
			c.a = 0.85
			img.set_pixel(x, y, c)
	img.save_png(OUT_BARS + "ui_bar_wall_fill.png")

func _make_bar(filename: String, w: int, h: int, color: Color, radius: int) -> void:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cx := w / 2.0
	var cy := h / 2.0
	var rx := cx - 1.0
	var ry := cy - 1.0

	for y in h:
		for x in w:
			var dx := abs(x - cx)
			var dy := abs(y - cy)
			var in_rect := true
			if dx > rx - radius and dy > ry - radius:
				var cdx := dx - (rx - radius)
				var cdy := dy - (ry - radius)
				if cdx * cdx + cdy * cdy > radius * radius:
					in_rect = false
			if in_rect:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, 0.85))
	img.save_png(OUT_BARS + filename)

# ══════════════════════════════════════════
# 模块 5：射程可视化
# ══════════════════════════════════════════
func _generate_range_highlights() -> void:
	print("\n[5/6] 射程可视化：")

	# 射程衰减六角（暗橙）
	_make_hex_highlight("ui_highlight_range_reduced.png", Color(0.7, 0.5, 0.2, 0.3))
	print("  ui_highlight_range_reduced.png")

	# 反击预览六角（蓝色）
	_make_hex_highlight("ui_highlight_counter.png", Color(0.3, 0.5, 0.8, 0.3))
	print("  ui_highlight_counter.png")

	# 夹击预览六角（红色）
	_make_hex_highlight("ui_highlight_flank_preview.png", Color(0.8, 0.3, 0.3, 0.25))
	print("  ui_highlight_flank_preview.png")

func _make_hex_highlight(filename: String, color: Color) -> void:
	var size := 32
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var cx := size / 2.0
	var cy := size / 2.0
	var r := 14.0

	# 六角形顶点
	var pts: PackedVector2Array = []
	for i in 6:
		pts.append(Vector2(cx, cy) + Vector2.from_angle(deg_to_rad(60 * i - 30)) * r)

	# 扫描线填充
	var min_y := int(cy - r)
	var max_y := int(cy + r)
	for y in range(clampi(min_y, 0, size - 1), clampi(max_y + 1, 0, size)):
		var x_min := size
		var x_max := 0
		for edge in 6:
			var a := pts[edge]
			var b := pts[(edge + 1) % 6]
			var ix := _line_x_at_y(a, b, float(y))
			if ix != null:
				x_min = mini(x_min, int(ix))
				x_max = maxi(x_max, int(ix))
		for x in range(clampi(x_min, 0, size - 1), clampi(x_max + 1, 0, size)):
			var dx := (x - cx) / r
			var dy := (y - cy) / r
			var dist := sqrt(dx * dx + dy * dy)
			var edge_f := clampf(1.0 - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * edge_f))

	# 边框
	for i in 6:
		_draw_line(img, pts[i], pts[(i + 1) % 6], Color(color.r, color.g, color.b, color.a * 1.5))

	img.save_png(OUT_HL + filename)

func _line_x_at_y(a: Vector2, b: Vector2, y: float):
	if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
		var t := (y - a.y) / (b.y - a.y)
		return a.x + t * (b.x - a.x)
	return null

func _draw_line(img: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var steps := int(max(abs(b.x - a.x), abs(b.y - a.y)).ceil())
	steps = clampi(steps, 1, 200)
	for i in steps:
		var t := float(i) / float(steps)
		var px := int(lerp(a.x, b.x, t))
		var py := int(lerp(a.y, b.y, t))
		if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
			img.set_pixel(px, py, color)

# ══════════════════════════════════════════
# 模块 6：战斗 UI 面板
# ══════════════════════════════════════════
func _generate_panel_backgrounds() -> void:
	print("\n[6/6] 战斗 UI 面板：")

	# 战斗预览面板
	_make_panel_bg("ui_battle_panel_bg.png", 200, 120)
	print("  ui_battle_panel_bg.png")

	# 战斗日志横幅
	_make_panel_bg("ui_combat_log_bg.png", 300, 60)
	print("  ui_combat_log_bg.png")

	# 兵力数字徽章
	_make_troop_badge()
	print("  ui_troop_badge_bg.png")

func _make_panel_bg(filename: String, w: int, h: int) -> void:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)

	# 暗色背景
	for y in h:
		for x in w:
			var edge_dist := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
			var alpha := clampf(float(edge_dist) / 3.0, 0.0, 1.0) * 0.85
			# 顶部渐亮
			var top_blend := 1.0 - float(y) / float(h) * 0.15
			img.set_pixel(x, y, Color(COL_DARK.r * top_blend, COL_DARK.g * top_blend, COL_DARK.b * top_blend, alpha))

	# 金色边框
	for x in range(1, w - 1):
		img.set_pixel(x, 0, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.6))
		img.set_pixel(x, h - 1, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.6))
	for y in range(1, h - 1):
		img.set_pixel(0, y, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.6))
		img.set_pixel(w - 1, y, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.6))

	# 角落装饰点
	for corner in [Vector2(1, 1), Vector2(w - 2, 1), Vector2(1, h - 2), Vector2(w - 2, h - 2)]:
		img.set_pixel(int(corner.x), int(corner.y), Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.8))

	img.save_png(OUT_PANELS + filename)

func _make_troop_badge() -> void:
	var w := 24
	var h := 14
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)

	# 圆角暗色底
	for y in h:
		for x in w:
			var edge_dist := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
			if edge_dist >= 0:
				var alpha := clampf(float(edge_dist) / 2.0, 0.0, 1.0) * 0.8
				img.set_pixel(x, y, Color(COL_DARK.r, COL_DARK.g, COL_DARK.b, alpha))

	# 金色下边框（底部高亮）
	for x in range(2, w - 2):
		img.set_pixel(x, h - 1, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.5))

	img.save_png(OUT_PANELS + "ui_troop_badge_bg.png")

# ── 工具函数 ──
func _safe_px(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, color)
