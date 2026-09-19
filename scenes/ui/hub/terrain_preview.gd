extends Control

signal closed

const GRID_SCRIPT: Script = preload("res://scenes/ui/hub/terrain_preview_grid.gd")
const TERRAIN_CHOICES: Array = [
	["平原 01", "plains", 0], ["平原 02", "plains", 1], ["平原 03", "plains", 2],
	["森林 01", "forest", 0], ["森林 02", "forest", 1], ["森林 03", "forest", 2],
	["山地 01", "mountain", 0], ["山地 02", "mountain", 1], ["山地 03", "mountain", 2],
	["沼泽 01", "marsh", 0], ["沼泽 02", "marsh", 1], ["沼泽 03", "marsh", 2],
	["沙漠 01", "desert", 0], ["沙漠 02", "desert", 1], ["沙漠 03", "desert", 2],
	["冻土 01", "tundra", 0], ["冻土 02", "tundra", 1], ["冻土 03", "tundra", 2],
	["关隘 01", "pass", 0], ["关隘 02", "pass", 1],
	["浅海 01", "shallow_ocean", 0], ["浅海 02", "shallow_ocean", 1],
	["深海 01", "deep_ocean", 0], ["深海 02", "deep_ocean", 1],
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.14, 0.18, 0.15)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var title := Label.new()
	title.text = "2D 俯视地形接入测试"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(0.89, 0.72, 0.43))
	heading.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "九类地形 · 24 张素材  |  陆地六类各三款，关隘与海域各两款"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.76, 0.68))
	heading.add_child(subtitle)
	var back := Button.new()
	back.text = "返回战略中枢"
	back.custom_minimum_size = Vector2(164, 42)
	back.pressed.connect(func() -> void: closed.emit())
	header.add_child(back)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	layout.add_child(content)
	var source_column := VBoxContainer.new()
	source_column.custom_minimum_size = Vector2(285, 0)
	source_column.add_theme_constant_override("separation", 10)
	content.add_child(source_column)
	var source_label := Label.new()
	source_label.text = "查看单张素材"
	source_label.add_theme_font_size_override("font_size", 18)
	source_column.add_child(source_label)
	var picker := OptionButton.new()
	picker.name = "TerrainPicker"
	for choice: Array in TERRAIN_CHOICES:
		picker.add_item(str(choice[0]))
		picker.set_item_metadata(picker.item_count - 1, choice)
	source_column.add_child(picker)
	var source := TextureRect.new()
	source.name = "SourceTexture"
	source.custom_minimum_size = Vector2(285, 285)
	source.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	source.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	source_column.add_child(source)
	var note := Label.new()
	note.name = "SourceFilename"
	note.add_theme_font_size_override("font_size", 13)
	source_column.add_child(note)

	var grid_column := VBoxContainer.new()
	grid_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_column.add_theme_constant_override("separation", 10)
	content.add_child(grid_column)
	var grid_label := Label.new()
	grid_label.text = "六角试排 · 24 格 · 相邻边缘渐变"
	grid_label.add_theme_font_size_override("font_size", 18)
	grid_column.add_child(grid_label)
	var mode_picker := OptionButton.new()
	mode_picker.name = "PreviewModePicker"
	mode_picker.add_item("混合地形")
	mode_picker.add_item("三类变体与交界")
	mode_picker.add_item("九类完整变体")
	mode_picker.select(2)
	grid_column.add_child(mode_picker)
	var grid := Control.new()
	grid.name = "HexGridPreview"
	grid.set_script(GRID_SCRIPT)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_column.add_child(grid)
	grid.call("set_preview_mode", 2)
	mode_picker.item_selected.connect(func(index: int) -> void:
		grid.call("set_preview_mode", index)
	)
	picker.item_selected.connect(_update_source_preview.bind(picker, source, note))
	_update_source_preview(0, picker, source, note)
	var legend := Label.new()
	legend.text = "完整变体：24 张各出现一次；大地图按坐标稳定选图"
	legend.add_theme_font_size_override("font_size", 13)
	grid_column.add_child(legend)

	var footer := Label.new()
	footer.text = "测试目标：九类地形去重复、交界衔接与缩小可读性；河流和渡口不参与。"
	footer.add_theme_font_size_override("font_size", 14)
	footer.add_theme_color_override("font_color", Color(0.68, 0.71, 0.66))
	layout.add_child(footer)


func _update_source_preview(index: int, picker: OptionButton, source: TextureRect,
		note: Label) -> void:
	var choice: Array = picker.get_item_metadata(index) as Array
	var terrain_id: String = str(choice[1])
	var variant_index: int = int(choice[2])
	source.texture = SkirmishTileTextures.terrain_texture_by_variant(terrain_id, variant_index)
	note.text = SkirmishTileTextures.terrain_variant_path(terrain_id, variant_index).get_file()
