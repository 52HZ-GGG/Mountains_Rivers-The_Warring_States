extends Control
class_name HexMapCanvas

## 在 HexBoard 上一次性绘制全部六角地形贴图，避免逐格 Control._draw 叠加误差造成「假缝隙」。

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -40
	set_anchors_preset(PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _white_vertex_colors(n: int) -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray()
	var i: int = 0
	while i < n:
		colors.append(Color.WHITE)
		i += 1
	return colors


func _draw() -> void:
	var board: Control = get_parent() as Control
	if board == null:
		return
	var list: Array[SkirmishHexCell] = []
	for ch: Node in board.get_children():
		if ch is SkirmishHexCell:
			list.append(ch as SkirmishHexCell)
	list.sort_custom(func(a: SkirmishHexCell, b: SkirmishHexCell) -> bool:
		if a.cell_r != b.cell_r:
			return a.cell_r < b.cell_r
		return a.cell_q < b.cell_q
	)
	for cell: SkirmishHexCell in list:
		var lp: PackedVector2Array = cell.get_bleed_polygon_local()
		if lp.size() < 3:
			continue
		var bp: PackedVector2Array = PackedVector2Array()
		var k: int = 0
		while k < lp.size():
			bp.append(cell.position + lp[k])
			k += 1
		var tex: Texture2D = cell.get_terrain_texture_for_map()
		var uvs: PackedVector2Array = cell.get_uvs_for_bleed_polygon(lp)
		if tex != null and bp.size() == uvs.size():
			draw_polygon(bp, _white_vertex_colors(bp.size()), uvs, tex)
		else:
			draw_colored_polygon(bp, SkirmishHexCell.fallback_terrain_color())
	for cell2: SkirmishHexCell in list:
		var tc: Color = cell2.get_overlay_tint_color()
		if tc.a <= 0.001:
			continue
		var lp2: PackedVector2Array = cell2.get_bleed_polygon_local()
		if lp2.size() < 3:
			continue
		var bp2: PackedVector2Array = PackedVector2Array()
		var j: int = 0
		while j < lp2.size():
			bp2.append(cell2.position + lp2[j])
			j += 1
		draw_colored_polygon(bp2, tc)
