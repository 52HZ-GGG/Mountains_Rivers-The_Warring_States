@tool
extends EditorScript
## 生成城墙/城市相关六角图块（32×32 像素，flat-top hex）
## 在 Godot 编辑器中：工具 → 运行脚本
##
## 生成文件：
##   tile_pass_01.png        — 关隘（城墙关口）
##   tile_city_small_01.png  — 小城
##   tile_city_large_01.png  — 大城
##   tile_city_capital_01.png — 首都
##   tile_city_neutral_01.png — 中立城
##   tile_arrow_tower_01.png — 箭楼

const OUTPUT_DIR := "res://assets/sprites/tiles/"
const S := 32  # 图块尺寸

# ── 32 色调色板（战国低饱和暖色调）──
const C_BG_TRANSPARENT := Color(0, 0, 0, 0)

# 城墙/石材
const C_WALL_LIGHT  := Color("B8A88A")   # 城墙亮面
const C_WALL_MID    := Color("8C7E6A")   # 城墙中调
const C_WALL_DARK   := Color("5C5040")   # 城墙暗面
const C_WALL_TOP    := Color("D4C8A8")   # 城墙顶部

# 屋顶
const C_ROOF_RED    := Color("8B3A3A")   # 红色屋顶（大城/首都）
const C_ROOF_GRAY   := Color("6B6B6B")   # 灰色屋顶（小城）
const C_ROOF_GOLD   := Color("C8A84E")   # 金色屋顶（首都）

# 木/门
const C_WOOD        := Color("6B4226")   # 木门/木结构
const C_WOOD_LIGHT  := Color("8B6240")   # 木亮面

# 土地
const C_GROUND      := Color("7A6B52")   # 土地底色
const C_GROUND_LIGHT:= Color("9A8B72")   # 土地亮面

# 草/装饰
const C_GRASS       := Color("4A6B3A")   # 草地

# 特殊
const C_FLAG_RED    := Color("CC3333")   # 红旗
const C_GOLD        := Color("F5C542")   # 金色装饰
const C_ARROW_SLOT  := Color("2A2A2A")   # 箭窗暗色
const C_WATER       := Color("4A7B9A")   # 护城河

# 六角形掩码（flat-top，16 个六角形顶点形成的多边形）
var _hex_mask: Array = []  # Array[Array[bool]]，32×32

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_build_hex_mask()

	print("=== 城墙/城市图块生成 ===")

	_generate_pass()
	_generate_city_small()
	_generate_city_large()
	_generate_city_capital()
	_generate_city_neutral()
	_generate_arrow_tower()

	print("\n[OK] 全部城市图块已生成到: ", OUTPUT_DIR)

# ────────────────────────────────────────
# 六角形掩码（flat-top hex）
# ────────────────────────────────────────
func _build_hex_mask() -> void:
	_hex_mask.clear()
	var cx := S / 2.0
	var cy := S / 2.0
	# flat-top hex: 宽边在上下，尖端在左右
	# 内切半径 = 高度/2 = 16, 外接半径 = 宽度/2 = 16
	# 但 flat-top hex 宽度 = 2*r, 高度 = sqrt(3)*r
	# 32×32 中：r = 16, 高度 = 27.7 ≈ 28
	var r := 15.5  # 留 1px 边距

	for y in S:
		var row: Array[bool] = []
		for x in S:
			var dx := x - cx + 0.5
			var dy := y - cy + 0.5
			# flat-top hex 距离公式
			var q := abs(dx) / r
			var s := abs(dy) / (r * 0.866)  # sqrt(3)/2
			var in_hex: bool
			if q + s <= 1.0:
				in_hex = true
			elif q <= 1.0 and s <= 1.0:
				# 角落修正
				in_hex = (q * 0.5 + s) <= 1.0
			else:
				in_hex = false
			row.append(in_hex)
		_hex_mask.append(row)

func _is_hex(x: int, y: int) -> bool:
	if x < 0 or x >= S or y < 0 or y >= S:
		return false
	return _hex_mask[y][x]

func _set_hex(img: Image, x: int, y: int, color: Color) -> void:
	if _is_hex(x, y):
		img.set_pixel(x, y, color)

# ────────────────────────────────────────
# 关隘（城墙关口）
# ────────────────────────────────────────
func _generate_pass() -> void:
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)

	# 底色土地
	_fill_hex(img, C_GROUND)

	# 城墙横条（中段）
	for y in range(12, 20):
		for x in range(4, 28):
			if _is_hex(x, y):
				var shade: Color
				if y == 12:
					shade = C_WALL_TOP
				elif y < 16:
					shade = C_WALL_LIGHT
				else:
					shade = C_WALL_MID
				img.set_pixel(x, y, shade)

	# 城墙暗面底部
	for y in range(20, 22):
		for x in range(5, 27):
			if _is_hex(x, y):
				img.set_pixel(x, y, C_WALL_DARK)

	# 城门（中间缺口）
	for y in range(14, 22):
		for x in range(13, 19):
			if _is_hex(x, y):
				img.set_pixel(x, y, C_WOOD if y > 16 else C_WOOD_LIGHT)

	# 城门拱顶
	_set_hex(img, 14, 13, C_WALL_DARK)
	_set_hex(img, 17, 13, C_WALL_DARK)

	# 城墙垛口（顶部锯齿）
	for x in range(5, 13):
		if (x - 5) % 3 != 2:
			_set_hex(img, x, 11, C_WALL_TOP)
	for x in range(19, 27):
		if (x - 19) % 3 != 2:
			_set_hex(img, x, 11, C_WALL_TOP)

	# 左右箭窗
	_set_hex(img, 8, 15, C_ARROW_SLOT)
	_set_hex(img, 8, 17, C_ARROW_SLOT)
	_set_hex(img, 23, 15, C_ARROW_SLOT)
	_set_hex(img, 23, 17, C_ARROW_SLOT)

	# 旗帜
	_set_hex(img, 7, 8, C_FLAG_RED)
	_set_hex(img, 7, 9, C_FLAG_RED)
	_set_hex(img, 24, 8, C_FLAG_RED)
	_set_hex(img, 24, 9, C_FLAG_RED)
	# 旗杆
	_set_hex(img, 7, 10, C_WALL_MID)
	_set_hex(img, 7, 11, C_WALL_MID)
	_set_hex(img, 24, 10, C_WALL_MID)
	_set_hex(img, 24, 11, C_WALL_MID)

	# 护城河（底部）
	for x in range(8, 24):
		if _is_hex(x, 24):
			img.set_pixel(x, 24, C_WATER)
		if _is_hex(x, 25):
			img.set_pixel(x, 25, C_WATER.darkened(0.2))

	img.save_png(OUTPUT_DIR + "tile_pass_01.png")
	print("  tile_pass_01.png")

# ────────────────────────────────────────
# 小城
# ────────────────────────────────────────
func _generate_city_small() -> void:
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)

	_fill_hex(img, C_GROUND_LIGHT)

	# 城墙围合（方形轮廓）
	for y in range(10, 22):
		for x in range(8, 24):
			if _is_hex(x, y):
				if y == 10 or y == 21 or x == 8 or x == 23:
					img.set_pixel(x, y, C_WALL_MID)
				elif y == 11 or y == 20:
					img.set_pixel(x, y, C_WALL_LIGHT)

	# 内部庭院
	for y in range(12, 20):
		for x in range(9, 23):
			if _is_hex(x, y):
				img.set_pixel(x, y, C_GROUND)

	# 灰色屋顶（单层建筑）
	for y in range(14, 18):
		for x in range(11, 21):
			if _is_hex(x, y):
				if y == 14:
					img.set_pixel(x, y, C_ROOF_GRAY.lightened(0.2))
				elif y < 16:
					img.set_pixel(x, y, C_ROOF_GRAY)
				else:
					img.set_pixel(x, y, C_ROOF_GRAY.darkened(0.2))

	# 小门
	_set_hex(img, 15, 21, C_WOOD)
	_set_hex(img, 16, 21, C_WOOD)

	# 垛口
	for x in [9, 11, 13, 18, 20, 22]:
		_set_hex(img, x, 9, C_WALL_TOP)

	img.save_png(OUTPUT_DIR + "tile_city_small_01.png")
	print("  tile_city_small_01.png")

# ────────────────────────────────────────
# 大城
# ────────────────────────────────────────
func _generate_city_large() -> void:
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)

	_fill_hex(img, C_GROUND_LIGHT)

	# 外城墙
	for y in range(8, 24):
		for x in range(6, 26):
			if _is_hex(x, y):
				if y == 8 or y == 23 or x == 6 or x == 25:
					img.set_pixel(x, y, C_WALL_DARK)
				elif y == 9 or y == 22:
					img.set_pixel(x, y, C_WALL_MID)

	# 内城墙
	for y in range(12, 20):
		for x in range(10, 22):
			if _is_hex(x, y):
				if y == 12 or y == 19 or x == 10 or x == 21:
					img.set_pixel(x, y, C_WALL_LIGHT)

	# 红色屋顶主殿
	for y in range(14, 18):
		for x in range(12, 20):
			if _is_hex(x, y):
				if y == 14:
					img.set_pixel(x, y, C_ROOF_RED.lightened(0.2))
				elif y < 16:
					img.set_pixel(x, y, C_ROOF_RED)
				else:
					img.set_pixel(x, y, C_ROOF_RED.darkened(0.2))

	# 城门（外）
	for y in range(18, 24):
		_set_hex(img, 15, y, C_WOOD)
		_set_hex(img, 16, y, C_WOOD)

	# 城门（内）
	_set_hex(img, 15, 19, C_WOOD_LIGHT)
	_set_hex(img, 16, 19, C_WOOD_LIGHT)

	# 角楼
	for pos in [Vector2(6, 8), Vector2(25, 8), Vector2(6, 23), Vector2(25, 23)]:
		_set_hex(img, int(pos.x), int(pos.y), C_WALL_TOP)

	# 垛口
	for x in range(7, 15):
		if (x - 7) % 3 != 2:
			_set_hex(img, x, 7, C_WALL_TOP)
	for x in range(17, 25):
		if (x - 17) % 3 != 2:
			_set_hex(img, x, 7, C_WALL_TOP)

	# 旗帜
	_set_hex(img, 6, 5, C_FLAG_RED)
	_set_hex(img, 6, 6, C_FLAG_RED)
	_set_hex(img, 25, 5, C_FLAG_RED)
	_set_hex(img, 25, 6, C_FLAG_RED)

	img.save_png(OUTPUT_DIR + "tile_city_large_01.png")
	print("  tile_city_large_01.png")

# ────────────────────────────────────────
# 首都
# ────────────────────────────────────────
func _generate_city_capital() -> void:
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)

	_fill_hex(img, C_GROUND_LIGHT)

	# 三重城墙（外）
	for y in range(6, 26):
		for x in range(4, 28):
			if _is_hex(x, y):
				if y == 6 or y == 25 or x == 4 or x == 27:
					img.set_pixel(x, y, C_WALL_DARK)

	# 中层城墙
	for y in range(9, 23):
		for x in range(7, 25):
			if _is_hex(x, y):
				if y == 9 or y == 22 or x == 7 or x == 24:
					img.set_pixel(x, y, C_WALL_MID)

	# 内城墙
	for y in range(12, 20):
		for x in range(10, 22):
			if _is_hex(x, y):
				if y == 12 or y == 19 or x == 10 or x == 21:
					img.set_pixel(x, y, C_WALL_LIGHT)

	# 金色屋顶宫殿（核心）
	for y in range(14, 18):
		for x in range(12, 20):
			if _is_hex(x, y):
				if y == 14:
					img.set_pixel(x, y, C_GOLD)
				elif y < 16:
					img.set_pixel(x, y, C_ROOF_GOLD)
				else:
					img.set_pixel(x, y, C_ROOF_GOLD.darkened(0.2))

	# 宫殿尖顶
	_set_hex(img, 15, 13, C_GOLD)
	_set_hex(img, 16, 13, C_GOLD)
	_set_hex(img, 15, 12, C_GOLD.lightened(0.2))

	# 城门（外层）
	for y in range(20, 26):
		_set_hex(img, 15, y, C_WOOD)
		_set_hex(img, 16, y, C_WOOD)

	# 角楼（外层）
	for pos in [Vector2(4, 6), Vector2(27, 6), Vector2(4, 25), Vector2(27, 25)]:
		_set_hex(img, int(pos.x), int(pos.y), C_WALL_TOP)
		_set_hex(img, int(pos.x), int(pos.y) - 1, C_FLAG_RED)

	# 垛口（外层）
	for x in range(5, 15):
		if (x - 5) % 2 == 0:
			_set_hex(img, x, 5, C_WALL_TOP)
	for x in range(17, 27):
		if (x - 17) % 2 == 0:
			_set_hex(img, x, 5, C_WALL_TOP)

	# 护城河
	for x in range(8, 24):
		if _is_hex(x, 26):
			img.set_pixel(x, 26, C_WATER)
		if _is_hex(x, 27):
			img.set_pixel(x, 27, C_WATER.darkened(0.2))

	img.save_png(OUTPUT_DIR + "tile_city_capital_01.png")
	print("  tile_city_capital_01.png")

# ────────────────────────────────────────
# 中立城
# ────────────────────────────────────────
func _generate_city_neutral() -> void:
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)

	_fill_hex(img, C_GROUND)

	# 低矮城墙
	for y in range(12, 20):
		for x in range(9, 23):
			if _is_hex(x, y):
				if y == 12 or y == 19 or x == 9 or x == 22:
					img.set_pixel(x, y, C_WALL_DARK)

	# 内部（泥地）
	for y in range(13, 19):
		for x in range(10, 22):
			if _is_hex(x, y):
				img.set_pixel(x, y, C_GROUND_LIGHT)

	# 简易棚屋
	for y in range(15, 18):
		for x in range(12, 16):
			if _is_hex(x, y):
				img.set_pixel(x, y, C_ROOF_GRAY.darkened(0.3))
	for y in range(15, 18):
		for x in range(17, 21):
			if _is_hex(x, y):
				img.set_pixel(x, y, C_WOOD.lightened(0.1))

	# 简易门
	_set_hex(img, 15, 19, C_WOOD)
	_set_hex(img, 16, 19, C_WOOD)

	# 市集旗帜（白色/灰色，表示中立）
	_set_hex(img, 14, 11, Color(0.8, 0.8, 0.8))
	_set_hex(img, 18, 11, Color(0.8, 0.8, 0.8))

	# 周围草地点缀
	_set_hex(img, 6, 18, C_GRASS)
	_set_hex(img, 25, 18, C_GRASS)
	_set_hex(img, 10, 24, C_GRASS)
	_set_hex(img, 22, 24, C_GRASS)

	img.save_png(OUTPUT_DIR + "tile_city_neutral_01.png")
	print("  tile_city_neutral_01.png")

# ────────────────────────────────────────
# 箭楼
# ────────────────────────────────────────
func _generate_arrow_tower() -> void:
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)

	_fill_hex(img, C_GROUND)

	# 塔基
	for y in range(18, 22):
		for x in range(12, 20):
			if _is_hex(x, y):
				img.set_pixel(x, y, C_WALL_MID)

	# 塔身
	for y in range(10, 18):
		for x in range(13, 19):
			if _is_hex(x, y):
				if y < 12:
					img.set_pixel(x, y, C_WALL_LIGHT)
				else:
					img.set_pixel(x, y, C_WALL_MID)

	# 塔顶（锥形）
	for y in range(7, 10):
		var w := 10 - y
		for x in range(16 - w / 2, 16 + w / 2 + 1):
			_set_hex(img, x, y, C_ROOF_RED)

	# 箭窗（四面）
	_set_hex(img, 13, 13, C_ARROW_SLOT)
	_set_hex(img, 13, 15, C_ARROW_SLOT)
	_set_hex(img, 18, 13, C_ARROW_SLOT)
	_set_hex(img, 18, 15, C_ARROW_SLOT)
	_set_hex(img, 15, 10, C_ARROW_SLOT)
	_set_hex(img, 16, 10, C_ARROW_SLOT)

	# 顶部旗帜
	_set_hex(img, 16, 5, C_FLAG_RED)
	_set_hex(img, 16, 6, C_FLAG_RED)
	_set_hex(img, 16, 7, C_WALL_MID)  # 旗杆

	# 底部城墙延伸
	for x in range(8, 13):
		_set_hex(img, x, 21, C_WALL_DARK)
	for x in range(19, 24):
		_set_hex(img, x, 21, C_WALL_DARK)

	img.save_png(OUTPUT_DIR + "tile_arrow_tower_01.png")
	print("  tile_arrow_tower_01.png")

# ────────────────────────────────────────
# 工具函数
# ────────────────────────────────────────
func _fill_hex(img: Image, color: Color) -> void:
	for y in S:
		for x in S:
			if _is_hex(x, y):
				img.set_pixel(x, y, color)
