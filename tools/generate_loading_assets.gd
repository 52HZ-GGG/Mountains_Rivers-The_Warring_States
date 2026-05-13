@tool
extends EditorScript
## 生成加载动画素材：ui_loading_hex.png + 4 个武器图标
## 在 Godot 编辑器中：工具 → 运行脚本

const OUTPUT_DIR := "res://assets/ui/icons/"

const COL_GOLD := Color("C8A84E")
const COL_DARK_BROWN := Color("3B2507")
const COL_CREAM := Color("E8D5B0")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_generate_hex_frame()
	_generate_weapon("ui_loading_sword.png", _draw_sword)
	_generate_weapon("ui_loading_bow.png", _draw_bow)
	_generate_weapon("ui_loading_shield.png", _draw_shield)
	_generate_weapon("ui_loading_horse.png", _draw_horse)
	print("[OK] 加载动画素材已保存到: ", OUTPUT_DIR)

# ────────────────────────────────────────────
# 六角形边框（线条风，金色，128×128）
# ────────────────────────────────────────────
func _generate_hex_frame() -> void:
	var size := 128
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var cx := size / 2.0
	var cy := size / 2.0
	var r := 56.0
	var thickness := 3.0

	# 六角形顶点
	var pts: PackedVector2Array = []
	for i in 6:
		pts.append(Vector2(cx, cy) + Vector2.from_angle(deg_to_rad(60 * i - 30)) * r)

	# 画六条边
	for i in 6:
		_draw_thick_line(img, pts[i], pts[(i + 1) % 6], thickness, COL_GOLD)

	# 顶点装饰小圆
	for p in pts:
		_fill_circle(img, int(p.x), int(p.y), 4, COL_GOLD)

	img.save_png(OUTPUT_DIR + "ui_loading_hex.png")
	print("  ui_loading_hex.png")

func _draw_thick_line(img: Image, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var steps := int(a.distance_to(b)) + 1
	var half_w := width / 2.0
	for i in steps:
		var t := float(i) / float(steps)
		var px := lerp(a.x, b.x, t)
		var py := lerp(a.y, b.y, t)
		for dy in range(-int(half_w), int(half_w) + 1):
			for dx in range(-int(half_w), int(half_w) + 1):
				if Vector2(dx, dy).length() <= half_w:
					var fx := int(px) + dx
					var fy := int(py) + dy
					if fx >= 0 and fx < img.get_width() and fy >= 0 and fy < img.get_height():
						img.set_pixel(fx, fy, color)

func _fill_circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if Vector2(x - cx, y - cy).length() <= r:
				if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
					img.set_pixel(x, y, color)

# ────────────────────────────────────────────
# 武器图标（48×48）
# ────────────────────────────────────────────
func _generate_weapon(filename: String, draw_fn: Callable) -> void:
	var size := 48
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	draw_fn.call(img, size)
	img.save_png(OUTPUT_DIR + filename)
	print("  ", filename)

func _draw_sword(img: Image, s: int) -> void:
	var cx := s / 2
	var cy := s / 2
	# 剑身（竖直）
	for y in range(8, 32):
		for x in range(cx - 2, cx + 3):
			img.set_pixel(x, y, COL_CREAM)
	# 剑尖
	for i in 5:
		img.set_pixel(cx - 1 + i / 2, 8 - i / 2, COL_CREAM)
		img.set_pixel(cx + 1 - i / 2, 8 - i / 2, COL_CREAM)
	# 剑格（横线）
	for x in range(cx - 8, cx + 9):
		img.set_pixel(x, 32, COL_GOLD)
		img.set_pixel(x, 33, COL_GOLD)
	# 剑柄
	for y in range(34, 42):
		img.set_pixel(cx - 1, y, COL_DARK_BROWN)
		img.set_pixel(cx, y, COL_DARK_BROWN)
		img.set_pixel(cx + 1, y, COL_DARK_BROWN)

func _draw_bow(img: Image, s: int) -> void:
	var cx := s / 2
	var cy := s / 2
	# 弓臂（弧线）
	for angle in range(-60, 61):
		var rad := deg_to_rad(angle)
		var bx := cx + int(cos(rad) * 18)
		var by := cy + int(sin(rad) * 18)
		if bx >= 0 and bx < s and by >= 0 and by < s:
			img.set_pixel(bx, by, COL_DARK_BROWN)
			img.set_pixel(bx + 1, by, COL_DARK_BROWN)
	# 弓弦
	for y in range(cy - 18, cy + 19):
		if y >= 0 and y < s:
			img.set_pixel(cx + 18, y, COL_CREAM)
	# 箭
	for x in range(cx - 15, cx + 16):
		if x >= 0 and x < s:
			img.set_pixel(x, cy, COL_CREAM)
	# 箭头
	img.set_pixel(cx - 16, cy - 1, COL_GOLD)
	img.set_pixel(cx - 17, cy, COL_GOLD)
	img.set_pixel(cx - 16, cy + 1, COL_GOLD)

func _draw_shield(img: Image, s: int) -> void:
	var cx := s / 2
	var cy := s / 2
	# 盾牌轮廓（椭圆）
	for y in range(8, 40):
		for x in range(10, 38):
			var dx := (float(x) - cx) / 14.0
			var dy := (float(y) - cy) / 16.0
			if dx * dx + dy * dy <= 1.0:
				# 盾面
				var edge := 1.0 - (dx * dx + dy * dy)
				if edge < 0.15:
					img.set_pixel(x, y, COL_DARK_BROWN)  # 边缘
				else:
					img.set_pixel(x, y, COL_GOLD.lerp(COL_DARK_BROWN, 0.3))  # 盾面
	# 盾中央十字
	for y in range(14, 34):
		img.set_pixel(cx, y, COL_DARK_BROWN)
		img.set_pixel(cx - 1, y, COL_DARK_BROWN)
	for x in range(16, 32):
		img.set_pixel(x, cy, COL_DARK_BROWN)
		img.set_pixel(x, cy - 1, COL_DARK_BROWN)

func _draw_horse(img: Image, s: int) -> void:
	# 简化的马头侧面轮廓
	var cx := s / 2
	var cy := s / 2
	# 头部
	_fill_circle(img, cx, cy - 4, 8, COL_DARK_BROWN.lerp(Color(0.4, 0.3, 0.2), 0.3))
	# 耳朵
	img.set_pixel(cx - 5, cy - 12, COL_DARK_BROWN)
	img.set_pixel(cx - 4, cy - 13, COL_DARK_BROWN)
	img.set_pixel(cx + 3, cy - 12, COL_DARK_BROWN)
	img.set_pixel(cx + 4, cy - 13, COL_DARK_BROWN)
	# 嘴部延伸
	for x in range(cx + 4, cx + 14):
		var yy := cy - 2 + (x - cx - 4) / 3
		if x < s and yy < s:
			img.set_pixel(x, yy, COL_DARK_BROWN.lerp(Color(0.4, 0.3, 0.2), 0.3))
	# 鬃毛
	for i in 8:
		var mx := cx - 6 + i
		var my := cy - 10 - i / 2
		if mx >= 0 and mx < s and my >= 0 and my < s:
			img.set_pixel(mx, my, COL_DARK_BROWN)
			img.set_pixel(mx - 1, my, COL_DARK_BROWN)
	# 眼睛
	img.set_pixel(cx - 2, cy - 6, COL_CREAM)
	img.set_pixel(cx - 1, cy - 6, COL_CREAM)
