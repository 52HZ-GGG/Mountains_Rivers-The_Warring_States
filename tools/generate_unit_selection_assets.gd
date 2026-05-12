@tool
extends EditorScript
## 生成士兵选中动画素材：ui_unit_shadow.png + 高亮图块
## 在 Godot 编辑器中：工具 → 运行脚本

const OUTPUT_DIR := "res://assets/ui/highlights/"

const COL_GOLD := Color("C8A84E")
const COL_MOVE_GREEN := Color(0.2, 0.7, 0.2, 0.35)
const COL_ATTACK_RED := Color(0.7, 0.2, 0.2, 0.35)
const COL_SHADOW := Color(0, 0, 0, 0.3)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_generate_shadow()
	_generate_hex_highlight("ui_highlight_select.png", COL_GOLD, 0.6)
	_generate_hex_highlight("ui_highlight_move.png", COL_MOVE_GREEN, 0.5)
	_generate_hex_highlight("ui_highlight_attack.png", COL_ATTACK_RED, 0.5)
	print("[OK] 选中动画素材已保存到: ", OUTPUT_DIR)

# ────────────────────────────────────────────
# ui_unit_shadow.png — 单位脚下阴影椭圆（768×256）
# ────────────────────────────────────────────
func _generate_shadow() -> void:
	var w := 768
	var h := 256
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cx := w / 2.0
	var cy := h / 2.0
	var rx := 280.0
	var ry := 80.0

	for y in h:
		for x in w:
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			var dist := dx * dx + dy * dy
			if dist <= 1.0:
				var alpha := (1.0 - dist) * COL_SHADOW.a
				img.set_pixel(x, y, Color(0, 0, 0, alpha))

	img.save_png(OUTPUT_DIR + "ui_unit_shadow.png")
	print("  ui_unit_shadow.png")

# ────────────────────────────────────────────
# 六角形高亮图块（1024×1024）
# ────────────────────────────────────────────
func _generate_hex_highlight(filename: String, color: Color, alpha: float) -> void:
	var size := 1024
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var cx := size / 2.0
	var cy := size / 2.0
	var r := 480.0

	# 六角形填充
	var pts: PackedVector2Array = []
	for i in 6:
		pts.append(Vector2(cx, cy) + Vector2.from_angle(deg_to_rad(60 * i - 30)) * r)

	# 扫描线填充
	var min_y := int(cy - r)
	var max_y := int(cy + r)
	for y in range(min_y, max_y + 1):
		if y < 0 or y >= size:
			continue
		# 找到与六角形相交的 x 范围
		var x_min := size
		var x_max := 0
		for edge in 6:
			var a := pts[edge]
			var b := pts[(edge + 1) % 6]
			var intersection := _line_x_at_y(a, b, float(y))
			if intersection != null:
				x_min = mini(x_min, int(intersection))
				x_max = maxi(x_max, int(intersection))

		for x in range(maxi(x_min, 0), mini(x_max, size)):
			# 边缘渐变
			var dx := (x - cx) / r
			var dy := (y - cy) / r
			var dist := sqrt(dx * dx + dy * dy)
			var edge_f := clampf(1.0 - dist, 0.0, 1.0)
			var final_alpha := alpha * edge_f
			img.set_pixel(x, y, Color(color.r, color.g, color.b, final_alpha))

	# 六角形边框（1px 亮边）
	for i in 6:
		_draw_hex_line(img, pts[i], pts[(i + 1) % 6], Color(color.r, color.g, color.b, alpha * 1.5))

	img.save_png(OUTPUT_DIR + filename)
	print("  ", filename)

func _line_x_at_y(a: Vector2, b: Vector2, y: float):
	if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
		var t := (y - a.y) / (b.y - a.y)
		return a.x + t * (b.x - a.x)
	return null

func _draw_hex_line(img: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var steps := int(max(abs(b.x - a.x), abs(b.y - a.y)).ceil())
	steps = clampi(steps, 1, 2000)
	for i in steps:
		var t := float(i) / float(steps)
		var px := int(lerp(a.x, b.x, t))
		var py := int(lerp(a.y, b.y, t))
		if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
			img.set_pixel(px, py, color)
