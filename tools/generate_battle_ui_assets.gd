@tool
extends EditorScript
## 生成 P1 战斗系统 UI 素材：士气图标、Buff/Debuff 图标、单位血条、城市血条
## 在 Godot 编辑器中：工具 → 运行脚本

const OUTPUT_ICONS := "res://assets/ui/icons/"
const OUTPUT_HP := "res://assets/ui/bars/"

# ── 色板 ──
const COL_MORALE_HIGH   := Color("F5C542")   # 金黄：高士气
const COL_MORALE_NORMAL := Color("8ABE6A")   # 绿色：正常
const COL_MORALE_LOW    := Color("E0943A")   # 橙色：低士气
const COL_MORALE_BROKEN := Color("D94040")   # 红色：崩溃

const COL_ATK_UP   := Color("E06040")   # 攻击增益：红橙
const COL_DEF_UP   := Color("4A90D9")   # 防御增益：蓝
const COL_SPEED_UP := Color("5ECF5E")   # 速度增益：绿

const COL_FIRE   := Color("FF6622")   # 火焰：橙红
const COL_POISON := Color("88CC44")   # 中毒：黄绿
const COL_FREEZE := Color("66CCFF")   # 冰冻：浅蓝
const COL_CHAOS  := Color("BB44FF")   # 混乱：紫

const COL_HP_GREEN  := Color("4ADE80")   # 血条绿
const COL_HP_YELLOW := Color("FACC15")   # 血条黄
const COL_HP_RED    := Color("EF4444")   # 血条红
const COL_HP_BG     := Color("1A1A2E")   # 血条背景
const COL_HP_FRAME  := Color("C8A84E")   # 血条边框

const ICON_SIZE := 48
const BUFF_SIZE := 40
const HP_W := 64
const HP_H := 10
const CITY_HP_W := 128
const CITY_HP_H := 14

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_ICONS)
	DirAccess.make_dir_recursive_absolute(OUTPUT_HP)

	print("=== P1 战斗系统 UI 素材生成 ===")

	# 1. 士气状态图标（4个）
	_generate_morale_icons()

	# 2. Buff/Debuff 图标（7个）
	_generate_buff_icons()

	# 3. 单位血条组件
	_generate_unit_hp_bar()

	# 4. 城市/关隘血条组件
	_generate_city_hp_bar()

	print("\n[OK] 全部 P1 素材已生成")

# ────────────────────────────────────────
# 1. 士气状态图标 — 48×48 圆形 + 内部符号
# ────────────────────────────────────────
func _generate_morale_icons() -> void:
	print("\n[1/4] 士气状态图标：")
	_make_morale_icon("ui_morale_high.png", COL_MORALE_HIGH, "▲")      # 上升箭头
	_make_morale_icon("ui_morale_normal.png", COL_MORALE_NORMAL, "●")  # 实心圆
	_make_morale_icon("ui_morale_low.png", COL_MORALE_LOW, "▼")        # 下降箭头
	_make_morale_icon("ui_morale_broken.png", COL_MORALE_BROKEN, "✕")  # 崩溃叉

func _make_morale_icon(filename: String, color: Color, symbol: String) -> void:
	var s := ICON_SIZE
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var cx := s / 2.0
	var cy := s / 2.0
	var r := 20.0

	# 圆形底色 + 暗边
	for y in s:
		for x in s:
			var dist := Vector2(x - cx, y - cy).length()
			if dist <= r:
				var edge := clampf((r - dist) / 3.0, 0.0, 1.0)
				var dark := 1.0 - clampf((dist / r) * 0.3, 0.0, 0.3)
				var c := color * dark
				c.a = edge
				img.set_pixel(x, y, c)
			elif dist <= r + 1.5:
				var alpha := clampf(r + 1.5 - dist, 0.0, 1.0) * 0.6
				img.set_pixel(x, y, Color(1, 1, 1, alpha))

	# 内部简单符号（像素绘制）
	_draw_symbol(img, cx, cy, symbol, Color(1, 1, 1, 0.9))

	img.save_png(OUTPUT_ICONS + filename)
	print("  ", filename)

func _draw_symbol(img: Image, cx: float, cy: float, symbol: String, color: Color) -> void:
	# 用像素点绘制简单符号
	match symbol:
		"▲":  # 上升箭头
			for i in 10:
				var y := int(cy + 4 - i)
				for x in range(int(cx) - i / 2, int(cx) + i / 2 + 1):
					if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
						img.set_pixel(x, y, color)
		"●":  # 实心圆
			for dy in range(-6, 7):
				for dx in range(-6, 7):
					if dx * dx + dy * dy <= 36:
						var px := int(cx) + dx
						var py := int(cy) + dy
						if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
							img.set_pixel(px, py, color)
		"▼":  # 下降箭头
			for i in 10:
				var y := int(cy - 4 + i)
				for x in range(int(cx) - i / 2, int(cx) + i / 2 + 1):
					if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
						img.set_pixel(x, y, color)
		"✕":  # 叉
			for i in 8:
				var px1 := int(cx) + i - 4
				var py1 := int(cy) + i - 4
				var px2 := int(cx) + 4 - i
				var py2 := int(cy) + i - 4
				for off in range(-1, 2):
					_set_safe(img, px1 + off, py1, color)
					_set_safe(img, px2 + off, py2, color)
					_set_safe(img, px1, py1 + off, color)
					_set_safe(img, px2, py2 + off, color)

func _set_safe(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, color)

# ────────────────────────────────────────
# 2. Buff/Debuff 图标 — 40×40 菱形底 + 符号
# ────────────────────────────────────────
func _generate_buff_icons() -> void:
	print("\n[2/4] Buff/Debuff 图标：")
	# Buff
	_make_status_icon("ui_buff_atk.png", COL_ATK_UP, "sword")
	_make_status_icon("ui_buff_def.png", COL_DEF_UP, "shield")
	_make_status_icon("ui_buff_speed.png", COL_SPEED_UP, "arrow")
	# Debuff
	_make_status_icon("ui_debuff_fire.png", COL_FIRE, "fire")
	_make_status_icon("ui_debuff_poison.png", COL_POISON, "drop")
	_make_status_icon("ui_debuff_freeze.png", COL_FREEZE, "snowflake")
	_make_status_icon("ui_debuff_chaos.png", COL_CHAOS, "swirl")

func _make_status_icon(filename: String, color: Color, shape: String) -> void:
	var s := BUFF_SIZE
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var cx := s / 2.0
	var cy := s / 2.0

	# 菱形底色
	for y in s:
		for x in s:
			var dx := abs(x - cx) / (s / 2.0)
			var dy := abs(y - cy) / (s / 2.0)
			if dx + dy <= 0.85:
				var edge := clampf((0.85 - dx - dy) * 10.0, 0.0, 1.0)
				var c := color * 0.8
				c.a = edge * 0.7
				img.set_pixel(x, y, c)

	# 内部符号
	_draw_status_shape(img, cx, cy, shape, Color(1, 1, 1, 0.85))

	img.save_png(OUTPUT_ICONS + filename)
	print("  ", filename)

func _draw_status_shape(img: Image, cx: float, cy: float, shape: String, color: Color) -> void:
	match shape:
		"sword":  # 剑形：竖线 + 斜线
			for i in 14:
				_set_safe(img, int(cx), int(cy - 7 + i), color)
				_set_safe(img, int(cx + i - 7), int(cy + 7 - i), color)
			# 护手
			for x in range(int(cx) - 3, int(cx) + 4):
				_set_safe(img, x, int(cy + 4), color)

		"shield":  # 盾形：倒三角
			for i in 10:
				var y := int(cy - 4 + i)
				for x in range(int(cx) - (10 - i) / 2, int(cx) + (10 - i) / 2 + 1):
					_set_safe(img, x, y, color)

		"arrow":  # 箭头：向右上
			for i in 10:
				_set_safe(img, int(cx - 5 + i), int(cy + 5 - i), color)
			for i in 6:
				_set_safe(img, int(cx + 3), int(cy - 3 - i), color)
				_set_safe(img, int(cx + 3 + i), int(cy - 3), color)

		"fire":  # 火焰：三角 + 顶部尖
			for i in 12:
				var y := int(cy + 6 - i)
				for x in range(int(cx) - i / 2, int(cx) + i / 2 + 1):
					_set_safe(img, x, y, color)
			_set_safe(img, int(cx), int(cy - 7), color)
			_set_safe(img, int(cx), int(cy - 8), color)

		"drop":  # 水滴：上圆下尖
			for dy in range(-5, 8):
				var w := 5 - abs(dy) if dy < 0 else 5 - dy * 0.7
				if w > 0:
					for x in range(int(cx - w), int(cx + w) + 1):
						_set_safe(img, x, int(cy + dy), color)

		"snowflake":  # 雪花：十字 + 对角
			for i in range(-6, 7):
				_set_safe(img, int(cx) + i, int(cy), color)
				_set_safe(img, int(cx), int(cy) + i, color)
				_set_safe(img, int(cx) + i, int(cy) + i, color)
				_set_safe(img, int(cx) + i, int(cy) - i, color)

		"swirl":  # 混乱：螺旋线
			for a in 36:
				var angle := a * TAU / 36.0
				var radius := 3.0 + a * 0.15
				var px := int(cx + cos(angle) * radius)
				var py := int(cy + sin(angle) * radius)
				_set_safe(img, px, py, color)

# ────────────────────────────────────────
# 3. 单位血条组件 — 64×10
# ────────────────────────────────────────
func _generate_unit_hp_bar() -> void:
	print("\n[3/4] 单位血条组件：")

	# 血条背景（暗色圆角矩形）
	_make_rounded_rect("ui_hp_bar_bg.png", HP_W, HP_H, COL_HP_BG, 3)
	# 血条填充（绿色，实际运行时动态着色）
	_make_hp_fill("ui_hp_bar_fill.png", HP_W - 2, HP_H - 2)
	# 血条边框（金色细边）
	_make_rounded_rect("ui_hp_bar_frame.png", HP_W, HP_H, COL_HP_FRAME, 3, true)

func _make_hp_fill(filename: String, w: int, h: int) -> void:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			# 渐变：左亮右暗
			var t := float(x) / float(w)
			var c := COL_HP_GREEN.lerp(COL_HP_GREEN.darkened(0.3), t)
			# 上下渐隐
			var vert := 1.0 - abs(float(y) / (h / 2.0) - 1.0) * 0.4
			c = c * vert
			c.a = 0.9
			img.set_pixel(x, y, c)
	img.save_png(OUTPUT_HP + filename)
	print("  ", filename)

# ────────────────────────────────────────
# 4. 城市/关隘血条组件 — 128×14
# ────────────────────────────────────────
func _generate_city_hp_bar() -> void:
	print("\n[4/4] 城市/关隘血条组件：")
	_make_rounded_rect("ui_city_hp_bg.png", CITY_HP_W, CITY_HP_H, COL_HP_BG, 4)
	_make_city_hp_fill("ui_city_hp_fill.png", CITY_HP_W - 2, CITY_HP_H - 2)
	_make_rounded_rect("ui_city_hp_frame.png", CITY_HP_W, CITY_HP_H, COL_HP_FRAME, 4, true)

func _make_city_hp_fill(filename: String, w: int, h: int) -> void:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var t := float(x) / float(w)
			# 城市血条：从绿到黄到红的完整渐变（运行时裁剪长度表示 HP 百分比）
			var c: Color
			if t < 0.5:
				c = COL_HP_RED.lerp(COL_HP_YELLOW, t * 2.0)
			else:
				c = COL_HP_YELLOW.lerp(COL_HP_GREEN, (t - 0.5) * 2.0)
			var vert := 1.0 - abs(float(y) / (h / 2.0) - 1.0) * 0.3
			c = c * vert
			c.a = 0.9
			img.set_pixel(x, y, c)
	img.save_png(OUTPUT_HP + filename)
	print("  ", filename)

# ────────────────────────────────────────
# 通用：圆角矩形 / 边框
# ────────────────────────────────────────
func _make_rounded_rect(filename: String, w: int, h: int, color: Color, radius: int, border_only: bool = false) -> void:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cx := w / 2.0
	var cy := h / 2.0
	var rx := cx - 1.0
	var ry := cy - 1.0

	for y in h:
		for x in w:
			var dx := abs(x - cx)
			var dy := abs(y - cy)
			# 圆角判断
			var in_rect := true
			if dx > rx - radius and dy > ry - radius:
				var corner_dx := dx - (rx - radius)
				var corner_dy := dy - (ry - radius)
				if corner_dx * corner_dx + corner_dy * corner_dy > radius * radius:
					in_rect = false

			if in_rect:
				if border_only:
					var near_edge := dx >= rx - 1.5 or dy >= ry - 1.5
					if near_edge:
						img.set_pixel(x, y, Color(color.r, color.g, color.b, 0.8))
				else:
					img.set_pixel(x, y, Color(color.r, color.g, color.b, 0.85))

	img.save_png(OUTPUT_HP + filename)
	print("  ", filename)
