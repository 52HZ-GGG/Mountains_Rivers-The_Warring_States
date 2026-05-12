@tool
extends EditorScript
## 生成 Splash 素材：splash_logo.png / splash_title.png / splash_title_mask.png
## 在 Godot 编辑器中：工具 → 运行脚本 (Run Script)
##
## Splash 动画流程（~4s）：
##   黑屏 0.5s → Logo 淡入 1s → 毛笔写字 1.5s → 光晕 0.5s → 淡出 1s
## 毛笔写字通过 mask 逐帧揭露实现：Shader 读取 mask alpha 来显示下方文字

const OUTPUT_DIR := "res://assets/ui/splash/"

# 素材尺寸
const LOGO_W := 512
const LOGO_H := 256
const TITLE_W := 512
const TITLE_H := 128
const MASK_FRAMES := 12  # 每个字 12 帧揭露，共 36 帧

# 调色板
const COL_GOLD := Color("C8A84E")
const COL_DARK_BROWN := Color("3B2507")
const COL_CREAM := Color("E8D5B0")

# 源素材
const LOGO_SRC := "res://photos/logo/logo_shanhece.png"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_generate_splash_logo()
	_generate_splash_title()
	_generate_title_mask()
	print("[OK] Splash 素材已保存到: ", OUTPUT_DIR)

# ────────────────────────────────────────────
# 1. splash_logo.png — 项目 Logo（512×256）
# ────────────────────────────────────────────
func _generate_splash_logo() -> void:
	var img := Image.create_empty(LOGO_W, LOGO_H, false, Image.FORMAT_RGBA8)

	# 尝试复用已有 Logo
	var src := _load_image(LOGO_SRC)
	if src:
		# 缩放到 512×256 范围内，保持比例
		var ratio := minf(float(LOGO_W) / float(src.get_width()), float(LOGO_H) / float(src.get_height()))
		var tw := int(src.get_width() * ratio)
		var th := int(src.get_height() * ratio)
		src.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		# 居中放置
		var ox := (LOGO_W - tw) / 2
		var oy := (LOGO_H - th) / 2
		img.blit_rect(src, Rect2i(0, 0, tw, th), Vector2i(ox, oy))
	else:
		# 备用：画一个简化的印章式 Logo
		_draw_fallback_logo(img)

	img.save_png(OUTPUT_DIR + "splash_logo.png")
	print("  splash_logo.png")

func _draw_fallback_logo(img: Image) -> void:
	# 外框（印章方形）
	var margin := 40
	var border := 4
	_rect(img, margin, margin, LOGO_W - margin * 2, LOGO_H - margin * 2, border, COL_GOLD)
	# 内部文字区域占位（实际文字由 splash_title 覆盖）
	var cx := LOGO_W / 2
	var cy := LOGO_H / 2
	# 简单的装饰横线
	_hline(img, cx - 80, cy + 60, 160, 2, COL_GOLD.lerp(COL_DARK_BROWN, 0.4))

func _rect(img: Image, x: int, y: int, w: int, h: int, t: int, color: Color) -> void:
	for i in t:
		_hline(img, x, y + i, w, 1, color)
		_hline(img, x, y + h - 1 - i, w, 1, color)
		_vline(img, x + i, y, h, 1, color)
		_vline(img, x + w - 1 - i, y, h, 1, color)

func _hline(img: Image, x: int, y: int, w: int, t: int, color: Color) -> void:
	for dy in t:
		for dx in w:
			var px := x + dx
			var py := y + dy
			if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
				img.set_pixel(px, py, color)

func _vline(img: Image, x: int, y: int, h: int, t: int, color: Color) -> void:
	for dx in t:
		for dy in h:
			var px := x + dx
			var py := y + dy
			if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
				img.set_pixel(px, py, color)

# ────────────────────────────────────────────
# 2. splash_title.png — 「山河策」最终文字（512×128）
# ────────────────────────────────────────────
func _generate_splash_title() -> void:
	var img := Image.create_empty(TITLE_W, TITLE_H, false, Image.FORMAT_RGBA8)
	_draw_title_text(img, COL_GOLD, Vector2i.ZERO)
	img.save_png(OUTPUT_DIR + "splash_title.png")
	print("  splash_title.png")

func _draw_title_text(img: Image, color: Color, offset: Vector2i) -> void:
	# 三字居中，每个字约 100px 宽，间距 20px
	# 总宽约 340px，起始 x = (512-340)/2 = 86
	var char_w := 100
	var gap := 20
	var total_w := char_w * 3 + gap * 2
	var sx := (TITLE_W - total_w) / 2 + offset.x
	var cy := TITLE_H / 2 + offset.y

	_draw_char_shan(img, sx + char_w / 2, cy, color)
	_draw_char_he(img, sx + char_w + gap + char_w / 2, cy, color)
	_draw_char_ce(img, sx + (char_w + gap) * 2 + char_w / 2, cy, color)

# ────────────────────────────────────────────
# 像素字绘制（篆书/隶书风格，较粗笔画）
# ────────────────────────────────────────────
func _draw_char_shan(img: Image, cx: int, cy: int, col: Color) -> void:
	var s := 5  # 笔画粗细
	# 三竖（中竖略高）
	_vline(img, cx - 35, cy - 45, 90, s, col)
	_vline(img, cx,      cy - 55, 110, s, col)
	_vline(img, cx + 35, cy - 45, 90, s, col)
	# 底横（贯穿）
	_hline(img, cx - 45, cy + 40, 90, s, col)

func _draw_char_he(img: Image, cx: int, cy: int, col: Color) -> void:
	var s := 5
	# 三点水（左侧）
	_hline(img, cx - 55, cy - 35, 12, s, col)
	_hline(img, cx - 60, cy - 15, 12, s, col)
	_hline(img, cx - 55, cy + 5,  12, s, col)
	# 可（右侧主体）
	_vline(img, cx - 20, cy - 55, 110, s, col)  # 主竖
	_hline(img, cx - 20, cy - 55, 65, s, col)   # 上横
	_hline(img, cx - 20, cy - 15, 55, s, col)   # 中横
	_hline(img, cx - 20, cy + 25, 65, s, col)   # 下横
	_vline(img, cx + 40, cy - 55, 45, s, col)   # 右竖
	_hline(img, cx + 20, cy - 10, 25, s, col)   # 短横
	# 口
	_hline(img, cx - 5, cy + 25, 35, s, col)
	_hline(img, cx - 5, cy + 55, 35, s, col)
	_vline(img, cx - 5, cy + 25, 30, s, col)
	_vline(img, cx + 30, cy + 25, 30, s, col)

func _draw_char_ce(img: Image, cx: int, cy: int, col: Color) -> void:
	var s := 5
	# 竹字头
	_hline(img, cx - 45, cy - 55, 35, s, col)
	_vline(img, cx - 25, cy - 65, 15, s, col)
	_hline(img, cx + 15, cy - 55, 35, s, col)
	_vline(img, cx + 30, cy - 65, 15, s, col)
	# 册
	_vline(img, cx - 35, cy - 35, 45, s, col)
	_vline(img, cx - 12, cy - 35, 45, s, col)
	_vline(img, cx + 12, cy - 35, 45, s, col)
	_vline(img, cx + 35, cy - 35, 45, s, col)
	_hline(img, cx - 35, cy - 35, 70, s, col)
	_hline(img, cx - 35, cy + 10, 70, s, col)
	# 朿（底部）
	_vline(img, cx, cy + 10, 50, s, col)
	_hline(img, cx - 30, cy + 30, 60, s, col)
	_hline(img, cx - 22, cy + 50, 44, s, col)
	_vline(img, cx + 25, cy + 10, 40, s, col)

# ────────────────────────────────────────────
# 3. splash_title_mask.png — 毛笔字遮罩精灵表（512×128 × 36 帧）
# ────────────────────────────────────────────
# 排列：水平条状，每帧 512×128，共 36 帧
# 每个字 12 帧逐步揭露：黑底 → 逐步露出白色字形
# Shader 采样 mask：白色区域显示文字，黑色区域透明
func _generate_title_mask() -> void:
	var total_frames := MASK_FRAMES * 3  # 3 字 × 12 帧
	var sheet_w := TITLE_W * total_frames
	var sheet_h := TITLE_H
	var sheet := Image.create_empty(sheet_w, sheet_h, false, Image.FORMAT_RGBA8)

	# 先把整张填黑（全遮挡）
	sheet.fill(Color.BLACK)

	# 为每个字生成 12 帧渐进揭露
	for char_idx in 3:
		_generate_char_mask_frames(sheet, char_idx)

	sheet.save_png(OUTPUT_DIR + "splash_title_mask.png")
	print("  splash_title_mask.png (%d 帧, %dx%d)" % [total_frames, sheet_w, sheet_h])

func _generate_char_mask_frames(sheet: Image, char_idx: int) -> void:
	# 先渲染完整字形到临时 Image
	var char_img := Image.create_empty(TITLE_W, TITLE_H, false, Image.FORMAT_RGBA8)
	char_img.fill(Color.TRANSPARENT)

	var char_w := 100
	var gap := 20
	var total_w := char_w * 3 + gap * 2
	var sx := (TITLE_W - total_w) / 2
	var cy := TITLE_H / 2

	match char_idx:
		0: _draw_char_shan(char_img, sx + char_w / 2, cy, Color.WHITE)
		1: _draw_char_he(char_img, sx + char_w + gap + char_w / 2, cy, Color.WHITE)
		2: _draw_char_ce(char_img, sx + (char_w + gap) * 2 + char_w / 2, cy, Color.WHITE)

	# 收集字形像素坐标（按 x 从左到右排序，模拟从左到右书写）
	var pixels: Array[Vector2i] = []
	for y in TITLE_H:
		for x in TITLE_W:
			if char_img.get_pixel(x, y).a > 0.5:
				pixels.append(Vector2i(x, y))

	# 按 x 坐标排序（从左到右笔顺）
	pixels.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)

	var total_px := pixels.size()
	if total_px == 0:
		return

	# 每帧揭露一部分
	for frame in MASK_FRAMES:
		var reveal_count := int(float(total_px) * float(frame + 1) / float(MASK_FRAMES))
		var frame_x_offset := char_idx * MASK_FRAMES * TITLE_W + frame * TITLE_W

		for i in reveal_count:
			var p := pixels[i]
			sheet.set_pixel(frame_x_offset + p.x, p.y, Color.WHITE)

# ────────────────────────────────────────────
# 工具
# ────────────────────────────────────────────
func _load_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if res is ImageTexture:
		return res.get_image().duplicate()
	if res is Image:
		return res.duplicate()
	return null
