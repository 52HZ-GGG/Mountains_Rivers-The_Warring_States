@tool
extends EditorScript
## 生成势力选择界面素材
## 在 Godot 编辑器中：工具 → 运行脚本

const OUTPUT_DIR := "res://assets/ui/panels/"

const CARD_W := 96
const CARD_H := 128
const SELECTED_W := 104
const SELECTED_H := 136

const COL_PARCHMENT := Color("D4B896")
const COL_PARCHMENT_DARK := Color("A08060")
const COL_GOLD := Color("C8A84E")
const COL_DARK_BROWN := Color("3B2507")
const COL_CREAM := Color("E8D5B0")

# 势力数据（与 factions.json 一致）
const FACTIONS := [
	{"id": "qin",  "name": "秦", "color": "#8B0000"},
	{"id": "zhao", "name": "赵", "color": "#4169E1"},
	{"id": "qi",   "name": "齐", "color": "#FFD700"},
	{"id": "chu",  "name": "楚", "color": "#228B22"},
	{"id": "wei",  "name": "魏", "color": "#4B0082"},
	{"id": "yan",  "name": "燕", "color": "#2F4F4F"},
	{"id": "han",  "name": "韩", "color": "#FF6347"},
]

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_generate_bg()
	for f in FACTIONS:
		_generate_card(f)
	_generate_selected_frame()
	print("[OK] 势力选择素材已保存到: ", OUTPUT_DIR)

# ────────────────────────────────────────────
# ui_select_bg.png — 全屏羊皮纸/地图背景
# ────────────────────────────────────────────
func _generate_bg() -> void:
	var w := 1920
	var h := 1080
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)

	# 羊皮纸底色
	for y in h:
		for x in w:
			var noise := _noise(x, y) * 0.08
			var c := COL_PARCHMENT.lerp(COL_PARCHMENT_DARK, noise)
			img.set_pixel(x, y, c)

	# 地图网格暗纹（六角格）
	var hex_r := 48.0
	var col_w := hex_r * sqrt(3.0)
	var row_h := hex_r * 1.5
	var faint := Color(0.22, 0.14, 0.03, 0.06)
	var row := 0
	var hy := 0.0
	while hy < h + hex_r * 2:
		var x_off := col_w * 0.5 if (row % 2 == 1) else 0.0
		var hx := -col_w + x_off
		while hx < w + col_w:
			_hex_outline(img, Vector2(hx, hy), hex_r, faint)
			hx += col_w
		hy += row_h
		row += 1

	# 中央标题装饰线
	var cy := 80
	for x in range(200, w - 200):
		img.set_pixel(x, cy, COL_GOLD.lerp(COL_PARCHMENT_DARK, 0.4))
		img.set_pixel(x, cy + 1, COL_GOLD.lerp(COL_PARCHMENT_DARK, 0.5))

	img.save_png(OUTPUT_DIR + "ui_select_bg.png")
	print("  ui_select_bg.png")

func _hex_outline(img: Image, c: Vector2, r: float, color: Color) -> void:
	var pts: PackedVector2Array = []
	for i in 6:
		pts.append(c + Vector2.from_angle(deg_to_rad(60 * i - 30)) * r)
	for i in 6:
		_line_a(img, pts[i], pts[(i + 1) % 6], color)

func _line_a(img: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var steps := int(max(abs(b.x - a.x), abs(b.y - a.y)).ceil())
	steps = clampi(steps, 1, 2000)
	for i in steps:
		var t := float(i) / float(steps)
		var px := int(lerp(a.x, b.x, t))
		var py := int(lerp(a.y, b.y, t))
		if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
			var bg := img.get_pixel(px, py)
			img.set_pixel(px, py, bg.lerp(color, color.a))

# ────────────────────────────────────────────
# ui_faction_card_[name].png — 势力卡片
# ────────────────────────────────────────────
func _generate_card(faction: Dictionary) -> void:
	var img := Image.create_empty(CARD_W, CARD_H, false, Image.FORMAT_RGBA8)
	var col := Color.html(faction["color"])

	# 卡片背景（羊皮纸色）
	for y in CARD_H:
		for x in CARD_W:
			var noise := _noise(x + 100, y + 100) * 0.05
			img.set_pixel(x, y, COL_PARCHMENT.lerp(COL_PARCHMENT_DARK, noise))

	# 势力色条（顶部 30px）
	for y in 30:
		for x in CARD_W:
			img.set_pixel(x, y, col)

	# 边框
	_rect_outline(img, 0, 0, CARD_W, CARD_H, 2, COL_DARK_BROWN)

	# 旗帜区域（中间）
	var flag_y := 40
	_rect_fill(img, 15, flag_y, CARD_W - 30, 50, col.lerp(COL_PARCHMENT, 0.3))
	_rect_outline(img, 15, flag_y, CARD_W - 30, 50, 1, col)

	# 国名（底部文字区域）
	_rect_fill(img, 10, CARD_H - 35, CARD_W - 20, 25, COL_PARCHMENT_DARK.lerp(COL_PARCHMENT, 0.5))

	var fname := "ui_faction_card_%s.png" % faction["id"]
	img.save_png(OUTPUT_DIR + fname)
	print("  ", fname)

# ────────────────────────────────────────────
# ui_faction_card_selected.png — 选中态外框
# ────────────────────────────────────────────
func _generate_selected_frame() -> void:
	var img := Image.create_empty(SELECTED_W, SELECTED_H, false, Image.FORMAT_RGBA8)

	# 透明底
	img.fill(Color.TRANSPARENT)

	# 金色发光边框（3px）
	_rect_outline(img, 0, 0, SELECTED_W, SELECTED_H, 3, COL_GOLD)
	_rect_outline(img, 3, 3, SELECTED_W - 6, SELECTED_H - 6, 1, COL_GOLD.lerp(Color.WHITE, 0.3))

	# 四角装饰
	var corner := 10
	for i in corner:
		# 左上
		img.set_pixel(i, 0, COL_GOLD)
		img.set_pixel(0, i, COL_GOLD)
		# 右上
		img.set_pixel(SELECTED_W - 1 - i, 0, COL_GOLD)
		img.set_pixel(SELECTED_W - 1, i, COL_GOLD)
		# 左下
		img.set_pixel(i, SELECTED_H - 1, COL_GOLD)
		img.set_pixel(0, SELECTED_H - 1 - i, COL_GOLD)
		# 右下
		img.set_pixel(SELECTED_W - 1 - i, SELECTED_H - 1, COL_GOLD)
		img.set_pixel(SELECTED_W - 1, SELECTED_H - 1 - i, COL_GOLD)

	img.save_png(OUTPUT_DIR + "ui_faction_card_selected.png")
	print("  ui_faction_card_selected.png")

# ────────────────────────────────────────────
# 工具函数
# ────────────────────────────────────────────
func _rect_outline(img: Image, x: int, y: int, w: int, h: int, t: int, color: Color) -> void:
	for i in t:
		for dx in w:
			if x + dx < img.get_width():
				if y + i < img.get_height(): img.set_pixel(x + dx, y + i, color)
				if y + h - 1 - i < img.get_height(): img.set_pixel(x + dx, y + h - 1 - i, color)
		for dy in h:
			if y + dy < img.get_height():
				if x + i < img.get_width(): img.set_pixel(x + i, y + dy, color)
				if x + w - 1 - i < img.get_width(): img.set_pixel(x + w - 1 - i, y + dy, color)

func _rect_fill(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for dy in h:
		for dx in w:
			var px := x + dx
			var py := y + dy
			if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
				img.set_pixel(px, py, color)

func _noise(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7FFFFFFF
	return float(n % 1000) / 1000.0
