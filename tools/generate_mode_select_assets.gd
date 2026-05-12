@tool
extends EditorScript
## 生成模式选择界面素材
## 在 Godot 编辑器中：工具 → 运行脚本

const OUTPUT_DIR := "res://assets/ui/panels/"

const COL_PARCHMENT := Color("D4B896")
const COL_PARCHMENT_DARK := Color("A08060")
const COL_GOLD := Color("C8A84E")
const COL_DARK_BROWN := Color("3B2507")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_generate_card_bg()
	_generate_card_selected()
	_generate_mode_icons()
	print("[OK] 模式选择素材已保存到: ", OUTPUT_DIR)

func _generate_card_bg() -> void:
	var w := 240
	var h := 320
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	# 羊皮纸纹理
	for y in h:
		for x in w:
			var noise := _noise(x + 200, y + 200) * 0.06
			img.set_pixel(x, y, COL_PARCHMENT.lerp(COL_PARCHMENT_DARK, noise))
	# 边框
	_rect_outline(img, 0, 0, w, h, 2, COL_DARK_BROWN)
	img.save_png(OUTPUT_DIR + "ui_mode_card_bg.png")
	print("  ui_mode_card_bg.png")

func _generate_card_selected() -> void:
	var w := 248
	var h := 328
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	_rect_outline(img, 0, 0, w, h, 3, COL_GOLD)
	_rect_outline(img, 3, 3, w - 6, h - 6, 1, COL_GOLD.lerp(Color.WHITE, 0.3))
	img.save_png(OUTPUT_DIR + "ui_mode_card_selected.png")
	print("  ui_mode_card_selected.png")

func _generate_mode_icons() -> void:
	var size := 96
	var icons := [
		{"name": "ui_mode_classic.png", "draw": _draw_classic},
		{"name": "ui_mode_quick.png", "draw": _draw_quick},
		{"name": "ui_mode_story.png", "draw": _draw_story},
		{"name": "ui_mode_sandbox.png", "draw": _draw_sandbox},
	]
	for icon in icons:
		var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		icon["draw"].call(img, size)
		img.save_png(OUTPUT_DIR + icon["name"])
		print("  ", icon["name"])

# 地图+棋子
func _draw_classic(img: Image, s: int) -> void:
	var cx := s / 2
	var cy := s / 2
	# 地图轮廓（六角形）
	var r := 35
	var pts: PackedVector2Array = []
	for i in 6:
		pts.append(Vector2(cx, cy) + Vector2.from_angle(deg_to_rad(60 * i - 30)) * r)
	for i in 6:
		_line(img, pts[i], pts[(i + 1) % 6], COL_DARK_BROWN)
	# 棋子（圆+竖线）
	_fill_circle(img, cx, cy - 10, 10, COL_GOLD)
	_line(img, Vector2(cx, cy), Vector2(cx, cy + 20), COL_GOLD)

# 剑盾
func _draw_quick(img: Image, s: int) -> void:
	var cx := s / 2
	var cy := s / 2
	# 剑
	for y in range(15, 50):
		for x in range(cx - 2, cx + 3):
			img.set_pixel(x, y, COL_PARCHMENT)
	for x in range(cx - 6, cx + 7):
		img.set_pixel(x, 50, COL_GOLD)
	for y in range(52, 65):
		img.set_pixel(cx - 1, y, COL_DARK_BROWN)
		img.set_pixel(cx, y, COL_DARK_BROWN)
	# 盾
	_fill_circle(img, cx + 20, cy + 10, 14, COL_GOLD.lerp(COL_DARK_BROWN, 0.3))
	_line(img, Vector2(cx + 20, cy - 4), Vector2(cx + 20, cy + 24), COL_DARK_BROWN)
	_line(img, Vector2(cx + 6, cy + 10), Vector2(cx + 34, cy + 10), COL_DARK_BROWN)

# 竹简
func _draw_story(img: Image, s: int) -> void:
	var cx := s / 2
	var cy := s / 2
	# 竹简外形
	_rect_fill(img, cx - 25, cy - 30, 50, 60, COL_PARCHMENT.lerp(COL_DARK_BROWN, 0.2))
	_rect_outline(img, cx - 25, cy - 30, 50, 60, 2, COL_DARK_BROWN)
	# 竹片横线
	for i in 5:
		var y := cy - 20 + i * 12
		_line(img, Vector2(cx - 22, y), Vector2(cx + 22, y), COL_DARK_BROWN.lerp(COL_PARCHMENT, 0.5))
	# 绳线
	_line(img, Vector2(cx, cy - 30), Vector2(cx, cy + 30), COL_GOLD)

# 骰子/沙盘
func _draw_sandbox(img: Image, s: int) -> void:
	var cx := s / 2
	var cy := s / 2
	# 沙盘（矩形）
	_rect_fill(img, cx - 30, cy - 20, 60, 40, COL_PARCHMENT.lerp(Color(0.7, 0.6, 0.4), 0.3))
	_rect_outline(img, cx - 30, cy - 20, 60, 40, 2, COL_DARK_BROWN)
	# 骰子
	_fill_circle(img, cx - 10, cy + 30, 10, COL_PARCHMENT)
	_rect_outline(img, cx - 20, cy + 20, 20, 20, 1, COL_DARK_BROWN)
	# 骰子点
	img.set_pixel(cx - 10, cy + 30, COL_DARK_BROWN)
	# 旗帜
	_line(img, Vector2(cx + 15, cy - 20), Vector2(cx + 15, cy - 40), COL_DARK_BROWN)
	_rect_fill(img, cx + 15, cy - 40, 15, 10, COL_GOLD.lerp(Color.RED, 0.3))

# ── 工具 ──
func _rect_outline(img: Image, x: int, y: int, w: int, h: int, t: int, color: Color) -> void:
	for i in t:
		for dx in w:
			if x + dx < img.get_width():
				if y + i < img.get_height(): img.set_pixel(x + dx, y + i, color)
				if y + h - 1 - i >= 0 and y + h - 1 - i < img.get_height(): img.set_pixel(x + dx, y + h - 1 - i, color)
		for dy in h:
			if y + dy < img.get_height():
				if x + i < img.get_width(): img.set_pixel(x + i, y + dy, color)
				if x + w - 1 - i >= 0 and x + w - 1 - i < img.get_width(): img.set_pixel(x + w - 1 - i, y + dy, color)

func _rect_fill(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for dy in h:
		for dx in w:
			var px := x + dx
			var py := y + dy
			if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
				img.set_pixel(px, py, color)

func _fill_circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if Vector2(x - cx, y - cy).length() <= r:
				if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
					img.set_pixel(x, y, color)

func _line(img: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var steps := int(max(abs(b.x - a.x), abs(b.y - a.y)).ceil())
	steps = clampi(steps, 1, 1000)
	for i in steps:
		var t := float(i) / float(steps)
		var px := int(lerp(a.x, b.x, t))
		var py := int(lerp(a.y, b.y, t))
		if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
			img.set_pixel(px, py, color)

func _noise(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7FFFFFFF
	return float(n % 1000) / 1000.0
