@tool
extends EditorScript
## 生成公告弹窗素材：ui_announcement_bg.png + ui_announcement_seal.png
## 在 Godot 编辑器中：工具 → 运行脚本

const OUTPUT_DIR := "res://assets/ui/panels/"
const BG_W := 600
const BG_H := 400
const SEAL_SIZE := 64

# 调色板
const COL_PARCHMENT := Color("D4B896")
const COL_PARCHMENT_DARK := Color("A08060")
const COL_BAMBOO := Color("8B7355")
const COL_GOLD := Color("C8A84E")
const COL_RED_SEAL := Color("C03030")
const COL_DARK_BROWN := Color("3B2507")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_generate_bg()
	_generate_seal()
	print("[OK] 公告素材已保存到: ", OUTPUT_DIR)

# ────────────────────────────────────────────
# ui_announcement_bg.png — 竹简/卷轴背景
# ────────────────────────────────────────────
func _generate_bg() -> void:
	var img := Image.create_empty(BG_W, BG_H, false, Image.FORMAT_RGBA8)

	# 竹简底色
	img.fill(COL_PARCHMENT)

	# 竹简纹理（横向条纹模拟竹片）
	for y in BG_H:
		var stripe := int(y / 8) % 2
		var tint := COL_PARCHMENT.lerp(COL_PARCHMENT_DARK, 0.08 if stripe == 0 else 0.0)
		for x in BG_W:
			# 添加噪点纹理感
			var noise_val := _pseudo_noise(x, y) * 0.06
			var c := tint.lerp(COL_PARCHMENT_DARK, noise_val)
			img.set_pixel(x, y, c)

	# 竹简边框（上下各 3 根竹片线）
	for i in 3:
		var y_top := 15 + i * 10
		var y_bot := BG_H - 15 - i * 10
		for x in BG_W:
			img.set_pixel(x, y_top, COL_BAMBOO.lerp(COL_PARCHMENT, 0.3))
			img.set_pixel(x, y_bot, COL_BAMBOO.lerp(COL_PARCHMENT, 0.3))

	# 左右卷轴装饰
	_draw_scroll_ends(img)

	# 标题区装饰横线
	var title_y := 60
	for x in range(80, BG_W - 80):
		img.set_pixel(x, title_y, COL_GOLD.lerp(COL_PARCHMENT_DARK, 0.5))
		img.set_pixel(x, title_y + 1, COL_GOLD.lerp(COL_PARCHMENT_DARK, 0.6))

	# 底部按钮区域底色（略深）
	for y in range(BG_H - 80, BG_H - 20):
		for x in range(80, BG_W - 80):
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, c.lerp(COL_PARCHMENT_DARK, 0.15))

	img.save_png(OUTPUT_DIR + "ui_announcement_bg.png")
	print("  ui_announcement_bg.png")

func _draw_scroll_ends(img: Image) -> void:
	# 左侧卷轴
	for y in range(10, BG_H - 10):
		for x in range(0, 20):
			var t := float(x) / 20.0
			var c := COL_BAMBOO.lerp(COL_PARCHMENT, t * 0.5)
			img.set_pixel(x, y, c)
		# 卷轴高光线
		img.set_pixel(5, y, COL_PARCHMENT.lerp(COL_BAMBOO, 0.2))
	# 右侧卷轴
	for y in range(10, BG_H - 10):
		for x in range(BG_W - 20, BG_W):
			var t := float(BG_W - 1 - x) / 20.0
			var c := COL_BAMBOO.lerp(COL_PARCHMENT, t * 0.5)
			img.set_pixel(x, y, c)
		img.set_pixel(BG_W - 6, y, COL_PARCHMENT.lerp(COL_BAMBOO, 0.2))

func _pseudo_noise(x: int, y: int) -> float:
	# 简单哈希噪点
	var n := (x * 374761393 + y * 668265263) & 0x7FFFFFFF
	return float(n % 1000) / 1000.0

# ────────────────────────────────────────────
# ui_announcement_seal.png — 红色印章
# ────────────────────────────────────────────
func _generate_seal() -> void:
	var img := Image.create_empty(SEAL_SIZE, SEAL_SIZE, false, Image.FORMAT_RGBA8)

	var cx := SEAL_SIZE / 2
	var cy := SEAL_SIZE / 2
	var r := 28

	# 圆形印章底
	for y in SEAL_SIZE:
		for x in SEAL_SIZE:
			var dist := Vector2(x - cx, y - cy).length()
			if dist <= r:
				# 印章红底 + 做旧效果
				var edge_f := clampf((r - dist) / 4.0, 0.0, 1.0)
				var noise := _pseudo_noise(x * 3, y * 3)
				var worn := 1.0 if noise > 0.75 else 0.0  # 做旧斑驳
				var c := COL_RED_SEAL.lerp(Color.TRANSPARENT, worn * 0.4)
				c.a = edge_f * (1.0 - worn * 0.3)
				img.set_pixel(x, y, c)
			elif dist <= r + 1:
				# 1px 边缘抗锯齿
				var aa := clampf(r + 1.0 - dist, 0.0, 1.0)
				img.set_pixel(x, y, Color(COL_RED_SEAL.r, COL_RED_SEAL.g, COL_RED_SEAL.b, aa * 0.6))

	# 中心十字纹（篆刻风格）
	for i in range(-12, 13):
		var px := cx + i
		if px >= 0 and px < SEAL_SIZE:
			var c := img.get_pixel(px, cy)
			if c.a > 0.1:
				img.set_pixel(px, cy, Color(0.9, 0.85, 0.75, c.a * 0.7))
		var py := cy + i
		if py >= 0 and py < SEAL_SIZE:
			var c := img.get_pixel(cx, py)
			if c.a > 0.1:
				img.set_pixel(cx, py, Color(0.9, 0.85, 0.75, c.a * 0.7))

	img.save_png(OUTPUT_DIR + "ui_announcement_seal.png")
	print("  ui_announcement_seal.png")
