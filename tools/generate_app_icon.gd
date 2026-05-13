@tool
extends EditorScript
## 生成 App 图标 icon_app_1024.png
## 在 Godot 编辑器中：工具 → 运行脚本 (Run Script)
##
## 构图：
##   深褐渐变背景 + 六角格暗纹
##   中央：秦军将领半身像（复用已有头像）
##   底部：「山河策」标题（复用已有 Logo）

const SIZE := 1024
const OUTPUT_DIR := "res://assets/ui/"
const OUTPUT_FILE := "icon_app_1024.png"

# 调色板
const COL_DARK_BROWN := Color("3B2507")
const COL_BLACK := Color("0A0600")
const COL_GOLD := Color("C8A84E")
const COL_HEX_LINE := Color(0.22, 0.14, 0.03, 0.2)

# 已有素材路径
const PORTRAIT_PATH := "res://photos/portrait/portrait_monarch_qin_hires.png"
const LOGO_PATH := "res://photos/logo/logo_shanhece.png"

func _run() -> void:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)

	# 1. 渐变背景
	_draw_radial_gradient(img)

	# 2. 六角格暗纹
	_draw_hex_overlay(img, 64.0, COL_HEX_LINE)

	# 3. 将领半身像（居中偏上）
	_composite_portrait(img)

	# 4. 标题（底部居中）
	_composite_logo(img)

	# 5. 底部六角格细纹装饰
	_draw_hex_overlay(img, 28.0, Color(0.22, 0.14, 0.03, 0.1), y_start = SIZE - 180)

	# 保存
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	img.save_png(OUTPUT_DIR + OUTPUT_FILE)
	print("[OK] App 图标已保存: ", OUTPUT_DIR + OUTPUT_FILE)

# ────────────────────────────────────────────
# 背景：深褐→黑 径向渐变
# ────────────────────────────────────────────
func _draw_radial_gradient(img: Image) -> void:
	var center := Vector2(SIZE / 2.0, SIZE * 0.42)
	var max_r := SIZE * 0.72
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x, y).distance_to(center)
			var t := clampf(d / max_r, 0.0, 1.0)
			# 用 ease 让过渡更自然
			t = ease(t, 0.8)
			img.set_pixel(x, y, COL_DARK_BROWN.lerp(COL_BLACK, t))

# ────────────────────────────────────────────
# 六角格网格暗纹
# ────────────────────────────────────────────
func _draw_hex_overlay(img: Image, hex_r: float, color: Color, y_start: float = 0.0) -> void:
	var col_w := hex_r * sqrt(3.0)
	var row_h := hex_r * 1.5
	var row := 0
	var y := y_start
	while y < SIZE + hex_r * 2:
		var x_off := col_w * 0.5 if (row % 2 == 1) else 0.0
		var x := -col_w + x_off
		while x < SIZE + col_w:
			_hex_outline(img, Vector2(x, y), hex_r, color)
			x += col_w
		y += row_h
		row += 1

func _hex_outline(img: Image, c: Vector2, r: float, color: Color) -> void:
	var pts: PackedVector2Array = []
	for i in 6:
		pts.append(c + Vector2.from_angle(deg_to_rad(60 * i - 30)) * r)
	for i in 6:
		_line_alpha(img, pts[i], pts[(i + 1) % 6], color)

func _line_alpha(img: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var steps := int(max(abs(b.x - a.x), abs(b.y - a.y)).ceil())
	steps = clampi(steps, 1, 1500)
	for i in steps:
		var t := float(i) / float(steps)
		var px := int(lerp(a.x, b.x, t))
		var py := int(lerp(a.y, b.y, t))
		if px >= 0 and px < SIZE and py >= 0 and py < SIZE:
			var bg := img.get_pixel(px, py)
			img.set_pixel(px, py, bg.lerp(color, color.a))

# ────────────────────────────────────────────
# 将领半身像合成
# ────────────────────────────────────────────
func _composite_portrait(img: Image) -> void:
	var portrait := _try_load_image(PORTRAIT_PATH)
	if portrait == null:
		push_warning("未找到头像: %s，跳过将领合成" % PORTRAIT_PATH)
		return

	# 缩放到合适尺寸（高 ~480px，留出上下空间给标题）
	var target_h := 480
	var ratio := float(target_h) / float(portrait.get_height())
	var target_w := int(portrait.get_width() * ratio)
	target_w = mini(target_w, 600)  # 不要太宽
	portrait.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)

	# 暖色调着色
	_warm_tint(portrait, 0.3)

	# 居中偏上放置
	var ox := (SIZE - target_w) / 2
	var oy := 160
	img.blit_rect(portrait, Rect2i(0, 0, target_w, target_h), Vector2i(ox, oy))

	# 边缘羽化（让头像融入背景）
	_feather_edges(img, Rect2i(ox, oy, target_w, target_h), 40)

func _warm_tint(img: Image, strength: float) -> void:
	var warm := Color(0.55, 0.38, 0.22)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.05:
				continue
			img.set_pixel(x, y, c.lerp(warm, strength))

func _feather_edges(img: Image, rect: Rect2i, feather: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if x < 0 or x >= SIZE or y < 0 or y >= SIZE:
				continue
			# 到矩形边缘的距离
			var dx := min(x - rect.position.x, rect.end.x - 1 - x)
			var dy := min(y - rect.position.y, rect.end.y - 1 - y)
			var edge_d := mini(dx, dy)
			if edge_d < feather:
				var t := float(edge_d) / float(feather)
				t = t * t  # 平滑曲线
				var pixel := img.get_pixel(x, y)
				var bg := _bg_at(Vector2(x, y))
				img.set_pixel(x, y, bg.lerp(pixel, t))

# ────────────────────────────────────────────
# Logo 合成（底部标题）
# ────────────────────────────────────────────
func _composite_logo(img: Image) -> void:
	var logo := _try_load_image(LOGO_PATH)
	if logo == null:
		push_warning("未找到 Logo: %s，跳过标题合成" % LOGO_PATH)
		return

	# 缩放 Logo：宽度约 600px
	var target_w := 600
	var ratio := float(target_w) / float(logo.get_width())
	var target_h := int(logo.get_height() * ratio)
	target_h = mini(target_h, 200)
	logo.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)

	# 金色着色（保留 alpha）
	_colorize_gold(logo)

	# 底部居中
	var ox := (SIZE - target_w) / 2
	var oy := SIZE - target_h - 100
	# 先画 1px 描边（深褐色）
	_stroke_blit(img, logo, Vector2i(ox - 1, oy), COL_DARK_BROWN.lerp(COL_BLACK, 0.5))
	_stroke_blit(img, logo, Vector2i(ox + 1, oy), COL_DARK_BROWN.lerp(COL_BLACK, 0.5))
	_stroke_blit(img, logo, Vector2i(ox, oy - 1), COL_DARK_BROWN.lerp(COL_BLACK, 0.5))
	_stroke_blit(img, logo, Vector2i(ox, oy + 1), COL_DARK_BROWN.lerp(COL_BLACK, 0.5))
	# 再画金色正文
	img.blit_rect(logo, Rect2i(0, 0, target_w, target_h), Vector2i(ox, oy))

func _colorize_gold(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.1:
				continue
			var lum := c.get_luminance()
			var gold_col := COL_GOLD.lerp(Color(0.15, 0.1, 0.02), 1.0 - lum)
			gold_col.a = c.a
			img.set_pixel(x, y, gold_col)

func _stroke_blit(dst: Image, src: Image, offset: Vector2i, stroke_color: Color) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a < 0.3:
				continue
			var dx := offset.x + x
			var dy := offset.y + y
			if dx >= 0 and dx < SIZE and dy >= 0 and dy < SIZE:
				var existing := dst.get_pixel(dx, dy)
				if existing == COL_BLACK or existing == COL_DARK_BROWN or existing == COL_DARK_BROWN.lerp(COL_BLACK, 0.5):
					dst.set_pixel(dx, dy, stroke_color)

# ────────────────────────────────────────────
# 工具函数
# ────────────────────────────────────────────
func _try_load_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var tex = load(path)
	if tex == null:
		return null
	var img: Image
	if tex is ImageTexture:
		img = tex.get_image()
	elif tex is Image:
		img = tex
	else:
		return null
	return img.duplicate()

func _bg_at(pos: Vector2) -> Color:
	var center := Vector2(SIZE / 2.0, SIZE * 0.42)
	var max_r := SIZE * 0.72
	var t := clampf(pos.distance_to(center) / max_r, 0.0, 1.0)
	t = ease(t, 0.8)
	return COL_DARK_BROWN.lerp(COL_BLACK, t)
