extends Panel

## 城市管理面板
##
## 显示城市信息、已建建筑、建造队列、可建造列表。
## 点击大地图城市 → main.gd 实例化 → open(city_id)。

var _city_id: String = ""
var _main_vbox: VBoxContainer
var _city_name_label: Label
var _info_label: Label
var _buildings_list: VBoxContainer
var _queue_list: VBoxContainer
var _build_list: VBoxContainer
var _detail_label: RichTextLabel
var _selected_building_id: String = ""

signal return_to_map
signal panel_closed

## 建筑 ID → 图标文件名映射（无匹配的建筑不显示图标）
const _BUILDING_ICON_MAP: Dictionary = {
	"farm": "icon_building_farm",
	"market": "icon_building_market",
	"granary": "icon_building_granary",
	"barracks": "icon_building_barracks",
	"stable": "icon_building_stable",
	"horse_farm": "icon_building_stable",
	"wall": "icon_building_wall",
	"academy": "icon_building_academy",
	"ironworks": "icon_building_forge",
	"workshop": "icon_building_forge",
	"shrine": "icon_building_temple",
	"temple_daoist": "icon_building_temple",
	"lumbermill": "icon_building_farm",
	"fishery": "icon_building_farm",
}

# ── 生命周期 ──────────────────────────────────────

func _ready() -> void:
	_build_ui()
	visible = false


func open(city_id: String) -> void:
	_city_id = city_id
	_selected_building_id = ""
	visible = true
	_refresh_all()
	SignalBus.building_completed.connect(_on_building_completed)


func close() -> void:
	if SignalBus.building_completed.is_connected(_on_building_completed):
		SignalBus.building_completed.disconnect(_on_building_completed)
	queue_free()


func get_resource_bar_slot() -> VBoxContainer:
	return _main_vbox


# ── UI 骨架 ──────────────────────────────────────

func _build_ui() -> void:
	# 背景图
	var bg_tex: Texture2D = SkirmishTileTextures.panel_texture("city")
	if bg_tex != null:
		var bg := TextureRect.new()
		bg.name = "Background"
		bg.texture = bg_tex
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "MainVBox"
	_main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_vbox.offset_left = 40
	_main_vbox.offset_top = 30
	_main_vbox.offset_right = -40
	_main_vbox.offset_bottom = -20
	_main_vbox.add_theme_constant_override("separation", 8)
	add_child(_main_vbox)

	# 标题栏
	var title_bar := HBoxContainer.new()
	_main_vbox.add_child(title_bar)

	_city_name_label = Label.new()
	_city_name_label.add_theme_font_size_override("font_size", 22)
	_city_name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 1))
	title_bar.add_child(_city_name_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(spacer)

	var back_btn := SkirmishTileTextures.styled_button("返回大地图")
	back_btn.pressed.connect(_on_back_pressed)
	title_bar.add_child(back_btn)

	var close_btn := SkirmishTileTextures.styled_button("关闭")
	close_btn.pressed.connect(_on_close_pressed)
	title_bar.add_child(close_btn)

	# 内容区：左右分栏
	var split := HSplitContainer.new()
	split.split_offset = 350
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vbox.add_child(split)

	# 左栏
	var left_pane := VBoxContainer.new()
	left_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_pane.custom_minimum_size = Vector2(300, 0)
	left_pane.add_theme_constant_override("separation", 6)
	split.add_child(left_pane)

	# 城市信息
	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 14)
	_info_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 1))
	left_pane.add_child(_info_label)

	# 已建建筑
	var built_title := Label.new()
	built_title.text = "── 已建建筑 ──"
	built_title.add_theme_font_size_override("font_size", 15)
	built_title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7, 1))
	left_pane.add_child(built_title)

	var buildings_scroll := ScrollContainer.new()
	buildings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buildings_scroll.custom_minimum_size = Vector2(0, 120)
	left_pane.add_child(buildings_scroll)

	_buildings_list = VBoxContainer.new()
	_buildings_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buildings_list.add_theme_constant_override("separation", 4)
	buildings_scroll.add_child(_buildings_list)

	# 建造队列
	var queue_title := Label.new()
	queue_title.text = "── 建造队列 ──"
	queue_title.add_theme_font_size_override("font_size", 15)
	queue_title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.6, 1))
	left_pane.add_child(queue_title)

	_queue_list = VBoxContainer.new()
	_queue_list.add_theme_constant_override("separation", 2)
	left_pane.add_child(_queue_list)

	# 右栏
	var right_pane := VBoxContainer.new()
	right_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_pane.add_theme_constant_override("separation", 6)
	split.add_child(right_pane)

	var build_title := Label.new()
	build_title.text = "── 可建造 ──"
	build_title.add_theme_font_size_override("font_size", 15)
	build_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9, 1))
	right_pane.add_child(build_title)

	var build_scroll := ScrollContainer.new()
	build_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_scroll.custom_minimum_size = Vector2(0, 200)
	right_pane.add_child(build_scroll)

	_build_list = VBoxContainer.new()
	_build_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_list.add_theme_constant_override("separation", 4)
	build_scroll.add_child(_build_list)

	# 详情
	var detail_title := Label.new()
	detail_title.text = "── 建筑详情 ──"
	detail_title.add_theme_font_size_override("font_size", 15)
	detail_title.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65, 1))
	right_pane.add_child(detail_title)

	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.custom_minimum_size = Vector2(0, 120)
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_label.add_theme_font_size_override("normal_font_size", 13)
	right_pane.add_child(_detail_label)


# ── 刷新 ──────────────────────────────────────

func _refresh_all() -> void:
	_refresh_info()
	_refresh_buildings()
	_refresh_queue()
	_refresh_build_list()
	_show_default_detail()


func _refresh_info() -> void:
	var city: Dictionary = CityManager.get_city_state(_city_id)
	if city.is_empty():
		_city_name_label.text = "未知城市"
		_info_label.text = ""
		return

	var name_str: String = str(city.get("name", _city_id))
	if city.get("is_capital", false):
		name_str += "（首都）"
	_city_name_label.text = name_str

	var fid: String = str(city.get("current_faction_id", ""))
	var fname: String = _faction_display_name(fid)
	var pop: int = int(city.get("current_population", 0))
	var city_level: int = int(city.get("city_level", 1))
	var levels_cfg: Dictionary = DataManager.get_balance_param("city_levels")
	var level_cfg: Dictionary = levels_cfg.get(str(city_level), {})
	var slots: int = int(level_cfg.get("building_slots", 0))
	var dev: int = int(city.get("development", 0))
	var sr: Variant = city.get("special_resource", null)
	var sr_str: String = "\n特产：%s" % _special_resource_name(str(sr)) if sr != null else ""
	var prod: Dictionary = CityManager.get_city_production(_city_id)

	_info_label.text = "势力：%s\n人口：%s\n发展度：%d\n建筑槽位：%d / %d%s\n\n每回合产出：\n  粮食 +%d  金币 +%d  木材 +%d  工匠 +%d  建材 +%d" % [
		fname,
		_format_pop(pop),
		dev,
		city.get("buildings", []).size(), slots,
		sr_str,
		prod.get("food", 0), prod.get("gold", 0), prod.get("wood", 0),
		prod.get("craftsmen", 0), prod.get("building_materials", 0),
	]


func _refresh_buildings() -> void:
	for ch in _buildings_list.get_children():
		ch.queue_free()

	var city: Dictionary = CityManager.get_city_state(_city_id)
	if city.is_empty():
		return

	for b in city.get("buildings", []):
		var bid: String = str(b.get("building_id", ""))
		var level: int = int(b.get("level", 1))
		var bdata: Dictionary = DataManager.get_building(bid)
		var bname: String = str(bdata.get("name", bid))
		var effects_str: String = _effects_summary(bdata.get("effects", {}), level)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_buildings_list.add_child(row)

		# 建筑图标
		var icon_name: String = str(_BUILDING_ICON_MAP.get(bid, ""))
		if not icon_name.is_empty():
			var icon_tex: Texture2D = SkirmishTileTextures.icon_texture(icon_name)
			if icon_tex != null:
				var icon_rect := TextureRect.new()
				icon_rect.texture = icon_tex
				icon_rect.custom_minimum_size = Vector2(24, 24)
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(icon_rect)

		var lbl := Label.new()
		lbl.text = "%s Lv.%d  %s" % [bname, level, effects_str]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		# 升级按钮
		var upgrade_check: Dictionary = CityManager.can_upgrade(_city_id, bid)
		var up_btn := SkirmishTileTextures.styled_button("升级")
		up_btn.add_theme_font_size_override("font_size", 12)
		up_btn.disabled = not upgrade_check["allowed"]
		SkirmishTileTextures.update_button_disabled(up_btn)
		if up_btn.disabled:
			up_btn.tooltip_text = _reason_text(upgrade_check["reason"])
		else:
			var multiplier: float = float(bdata.get("upgrade_cost_multiplier", 1.5))
			var factor: float = pow(multiplier, level)
			var up_gold: int = int(round(float(bdata.get("cost_gold", 0)) * factor))
			var up_wood: int = int(round(float(bdata.get("cost_wood", 0)) * factor))
			up_btn.tooltip_text = "费用：%d金 %d木材" % [up_gold, up_wood]
		up_btn.pressed.connect(_on_upgrade_pressed.bind(bid))
		row.add_child(up_btn)

		# 拆除按钮
		var del_btn := SkirmishTileTextures.styled_button("拆除")
		del_btn.add_theme_font_size_override("font_size", 12)
		del_btn.pressed.connect(_on_demolish_pressed.bind(bid))
		row.add_child(del_btn)


func _refresh_queue() -> void:
	for ch in _queue_list.get_children():
		ch.queue_free()

	var city: Dictionary = CityManager.get_city_state(_city_id)
	if city.is_empty():
		return

	var queue: Array = city.get("build_queue", [])
	if queue.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "（空）"
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		_queue_list.add_child(empty_lbl)
		return

	for i in queue.size():
		var entry: Dictionary = queue[i]
		var bid: String = str(entry.get("building_id", ""))
		var turns: int = int(entry.get("turns_remaining", 0))
		var bdata: Dictionary = DataManager.get_building(bid)
		var bname: String = str(bdata.get("name", bid))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_queue_list.add_child(row)

		var lbl := Label.new()
		lbl.text = "%s — 剩余 %d 回合" % [bname, turns]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6, 1))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var cancel_btn := SkirmishTileTextures.styled_button("取消")
		cancel_btn.add_theme_font_size_override("font_size", 12)
		cancel_btn.pressed.connect(_on_cancel_build_pressed.bind(i))
		row.add_child(cancel_btn)


func _refresh_build_list() -> void:
	for ch in _build_list.get_children():
		ch.queue_free()

	var all_buildings: Array = DataManager.get_all_buildings()
	for bdata in all_buildings:
		var bid: String = str(bdata["id"])
		var bname: String = str(bdata.get("name", bid))
		var category: String = str(bdata.get("category", ""))
		var cost_gold: int = int(bdata.get("cost_gold", 0))
		var cost_wood: int = int(bdata.get("cost_wood", 0))

		var check: Dictionary = CityManager.can_build(_city_id, bid)
		var allowed: bool = check["allowed"]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_build_list.add_child(row)

		# 建筑图标
		var icon_name: String = str(_BUILDING_ICON_MAP.get(bid, ""))
		if not icon_name.is_empty():
			var icon_tex: Texture2D = SkirmishTileTextures.icon_texture(icon_name)
			if icon_tex != null:
				var icon_rect := TextureRect.new()
				icon_rect.texture = icon_tex
				icon_rect.custom_minimum_size = Vector2(24, 24)
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(icon_rect)

		var btn := SkirmishTileTextures.styled_button("%s [%s] (%d金 %d木材)" % [bname, _category_name(category), cost_gold, cost_wood])
		btn.add_theme_font_size_override("font_size", 13)
		btn.disabled = not allowed
		SkirmishTileTextures.update_button_disabled(btn)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not allowed:
			btn.tooltip_text = _reason_text(check["reason"])
		btn.pressed.connect(_on_build_pressed.bind(bid))
		row.add_child(btn)

		# 详情按钮
		var info_btn := SkirmishTileTextures.styled_button("?")
		info_btn.add_theme_font_size_override("font_size", 12)
		info_btn.custom_minimum_size = Vector2(30, 0)
		info_btn.pressed.connect(_on_detail_pressed.bind(bid))
		row.add_child(info_btn)


func _show_default_detail() -> void:
	_detail_label.text = "点击建筑按钮查看详细信息。"


func _show_building_detail(building_id: String) -> void:
	_selected_building_id = building_id
	var bdata: Dictionary = DataManager.get_building(building_id)
	if bdata.is_empty():
		_detail_label.text = "未知建筑"
		return

	var bname: String = str(bdata.get("name", building_id))
	var desc: String = str(bdata.get("description", ""))
	var category: String = _category_name(str(bdata.get("category", "")))
	var cost_gold: int = int(bdata.get("cost_gold", 0))
	var cost_wood: int = int(bdata.get("cost_wood", 0))
	var build_turns: int = int(bdata.get("build_turns", 1))
	var max_level: int = int(bdata.get("max_level", 1))
	var upkeep: int = int(bdata.get("upkeep_gold", 0))
	var effects: Dictionary = bdata.get("effects", {})
	var max_nat: Variant = bdata.get("max_national_count")

	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]  [%s]" % [bname, category])
	lines.append(desc)
	lines.append("")
	lines.append("建造费用：%d金 %d木材" % [cost_gold, cost_wood])
	lines.append("建造回合：%d  最高等级：%d" % [build_turns, max_level])
	lines.append("维护费：%d 金/回合" % upkeep)
	lines.append("")
	lines.append("效果：")
	for key in effects:
		lines.append("  %s: %s" % [_effect_display_name(key), str(effects[key])])
	if max_nat != null:
		lines.append("")
		lines.append("每国限建：%d" % int(max_nat))

	_detail_label.text = "\n".join(lines)


# ── 回调 ──────────────────────────────────────

func _on_close_pressed() -> void:
	panel_closed.emit()


func _on_back_pressed() -> void:
	return_to_map.emit()


func _on_build_pressed(building_id: String) -> void:
	if CityManager.start_build(_city_id, building_id):
		_refresh_all()
		_refresh_resource_bar()


func _on_upgrade_pressed(building_id: String) -> void:
	if CityManager.start_upgrade(_city_id, building_id):
		_refresh_all()
		_refresh_resource_bar()


func _on_demolish_pressed(building_id: String) -> void:
	if CityManager.demolish(_city_id, building_id):
		_refresh_all()
		_refresh_resource_bar()


func _on_detail_pressed(building_id: String) -> void:
	_show_building_detail(building_id)


func _on_cancel_build_pressed(queue_index: int) -> void:
	if CityManager.cancel_build(_city_id, queue_index):
		_refresh_all()
		_refresh_resource_bar()


func _on_building_completed(_cid: String, _bid: String, _level: int) -> void:
	if _cid == _city_id:
		_refresh_all()


func _refresh_resource_bar() -> void:
	var bar := get_tree().get_first_node_in_group("resource_bar")
	if bar != null and bar.has_method("refresh"):
		bar.refresh()


# ── 工具函数 ──────────────────────────────────────

func _faction_display_name(faction_id: String) -> String:
	var f: Dictionary = DataManager.get_faction(faction_id)
	if not f.is_empty():
		return str(f.get("name", faction_id))
	return faction_id


func _special_resource_name(sr: String) -> String:
	match sr:
		"wood": return "林木（木材产量+30%）"
		"horse": return "马匹（骑兵训练+30%）"
		"salt": return "盐池（金钱收入+20%）"
		"craftsmen": return "工匠（工匠产量+30%）"
		"building_materials": return "建材（建材产量+30%）"
		_: return sr


func _category_name(cat: String) -> String:
	match cat:
		"economic": return "经济"
		"military": return "军事"
		"political": return "政治"
		"special": return "特殊"
		_: return cat


func _effects_summary(effects: Dictionary, level: int) -> String:
	var parts: PackedStringArray = []
	for key in effects:
		var val: Variant = effects[key]
		if val is int or val is float:
			parts.append("%s+%s" % [_effect_display_name(key), str(val * level)])
	return "(%s)" % ", ".join(parts) if parts.size() > 0 else ""


func _effect_display_name(key: String) -> String:
	match key:
		"food_production": return "粮食"
		"gold_production": return "金币"
		"wood_production": return "木材"
		"horse_production": return "马匹"
		"refined_iron_production": return "精铁"
		"craftsmen_production": return "工匠"
		"building_materials_production": return "建材"
		"morale_bonus": return "民心"
		"defense_bonus": return "防御"
		"recruit_speed_bonus": return "征兵加速"
		"tax_bonus": return "税收"
		"diplomacy_bonus": return "外交"
		"intelligence_range": return "情报范围"
		"food_storage_cap": return "粮储上限"
		"culture_production": return "文化"
		"supply_resist_bonus": return "补给韧性"
		"diplomacy_reputation": return "声望"
		_: return key


func _format_pop(pop: int) -> String:
	if pop >= 10000:
		return "%.1f万" % (pop / 10000.0)
	return str(pop)


func _reason_text(reason: String) -> String:
	match reason:
		"OK": return "可以建造"
		"INVALID_CITY": return "城市不存在"
		"INVALID_BUILDING": return "建筑不存在"
		"ALREADY_BUILT": return "已建造"
		"ALREADY_QUEUED": return "已在建造队列中"
		"SLOTS_FULL": return "建筑槽位已满"
		"NATIONAL_CAP_REACHED": return "已达全国限建数"
		"INSUFFICIENT_RESOURCES": return "资源不足"
		"BUILDING_NOT_BUILT": return "建筑未建造"
		"MAX_LEVEL_REACHED": return "已达最高等级"
		"NOT_OWN_CITY": return "非己方城市"
		"RELOCATION_LIMIT": return "迁都次数耗尽"
		_: return reason
