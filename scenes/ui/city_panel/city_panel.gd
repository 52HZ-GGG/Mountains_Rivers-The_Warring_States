extends Panel

## 城市管理面板
##
## 显示城市信息、已建建筑、建造队列、可建造列表。
## 点击大地图城市 → main.gd 实例化 → open(city_id)。

var _city_id: String = ""
var _main_vbox: VBoxContainer
var _city_name_label: Label
var _info_label: Label
var _status_label: Label
var _back_button: Button
var _buildings_list: VBoxContainer
var _queue_list: VBoxContainer
var _build_list: VBoxContainer
var _recruit_list: VBoxContainer
var _detail_label: RichTextLabel
var _selected_building_id: String = ""
var _refresh_pending: bool = false

signal return_to_map
signal panel_closed
signal place_building_requested(city_id: String, building_id: String)

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
	const _ArtUiSkin := preload("res://scripts/ui/art_ui_skin.gd")
	_ArtUiSkin.apply_full_skin(self, "city")
	_build_ui()
	visible = false


func _is_own_city() -> bool:
	var city: Dictionary = CityManager.get_city_state(_city_id)
	if city.is_empty():
		return false
	var owner: String = str(city.get("current_faction_id", ""))
	if owner == "" or owner == "neutral":
		return false
	return owner == GameManager.get_player_faction()


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


func get_city_id() -> String:
	return _city_id


func refresh() -> void:
	_refresh_all()


func set_back_button_text(text: String) -> void:
	if _back_button != null:
		_back_button.text = text


# ── UI 骨架 ──────────────────────────────────────

func _build_ui() -> void:
	# 背景：半透明深色面板
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.92)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.6, 0.5, 0.3, 0.6)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)

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

	_back_button = SkirmishTileTextures.styled_button(I18n.t("city.back_to_map"))
	_back_button.pressed.connect(_on_back_pressed)
	title_bar.add_child(_back_button)

	_status_label = Label.new()
	_status_label.name = "CityStatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55, 1))
	_status_label.text = "提示：右侧选择兵种征兵。全局兵源见顶栏「兵源」；消耗可服役池+资源，不扣城人口。"
	_main_vbox.add_child(_status_label)

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
	_info_label.name = "CityInfoLabel"
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 14)
	_info_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 1))
	left_pane.add_child(_info_label)

	# 已建建筑
	var built_title := Label.new()
	built_title.text = I18n.t("city.built_title")
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
	queue_title.text = I18n.t("city.queue_title")
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
	build_title.text = I18n.t("city.build_title")
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

	var recruit_title := Label.new()
	recruit_title.text = I18n.t("city.recruit_title")
	recruit_title.add_theme_font_size_override("font_size", 15)
	recruit_title.add_theme_color_override("font_color", Color(0.85, 0.7, 0.55, 1))
	right_pane.add_child(recruit_title)

	var recruit_help := Label.new()
	recruit_help.name = "RecruitHelpLabel"
	recruit_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recruit_help.text = "征兵池是本城本回合可转化为部队的人口额度，显示在下方第一行“征兵池”。征 1 队会消耗：征兵池 1、人口 1、该兵种列出的金/粮/木/马/铁/工匠。征兵池为 0 时点击按钮会提示原因；结束回合后由城市经营结算补充。"
	recruit_help.add_theme_font_size_override("font_size", 12)
	recruit_help.add_theme_color_override("font_color", Color(0.78, 0.78, 0.7, 1))
	right_pane.add_child(recruit_help)

	var recruit_scroll := ScrollContainer.new()
	recruit_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recruit_scroll.custom_minimum_size = Vector2(0, 120)
	right_pane.add_child(recruit_scroll)

	_recruit_list = VBoxContainer.new()
	_recruit_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recruit_list.add_theme_constant_override("separation", 4)
	recruit_scroll.add_child(_recruit_list)

	# 详情
	var detail_title := Label.new()
	detail_title.text = I18n.t("city.detail_title")
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
	_refresh_recruit_list()
	_show_default_detail()


func _queue_refresh_all() -> void:
	if _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_apply_deferred_refresh")


func _apply_deferred_refresh() -> void:
	_refresh_pending = false
	if not visible:
		return
	_refresh_all()


func _refresh_info() -> void:
	var city: Dictionary = CityManager.get_city_state(_city_id)
	if city.is_empty():
		_city_name_label.text = I18n.t("city.unknown")
		_info_label.text = ""
		return

	var name_str: String = str(city.get("name", _city_id))
	if city.get("is_capital", false):
		name_str += I18n.t("city.capital")
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
	var preview: Dictionary = GameManager.preview_faction_turn_income(fid)
	var national_prod: Dictionary = preview.get("production", {})
	var national_delta: Dictionary = preview.get("deltas", {})

	_info_label.text = "势力：%s\n人口：%s\n发展度：%d\n建筑槽位：%d / %d%s\n\n本城产出（结算前）：\n  粮食 %+d  金币 %+d  木材 %+d  工匠 %+d  建材 %+d\n\n预计国家入库（税后/维护后）：\n  粮食 %+d  金币 %+d  木材 %+d  工匠 %+d  建材 %+d\n  税率 %.0f%%  税收效率 %.0f%%\n\n%s" % [
		fname,
		_format_pop(pop),
		dev,
		city.get("buildings", []).size(), slots,
		sr_str,
		prod.get("food", 0), prod.get("gold", 0), prod.get("wood", 0),
		prod.get("craftsmen", 0), prod.get("building_materials", 0),
		national_delta.get("food", 0), national_delta.get("gold", 0), national_prod.get("wood", 0),
		national_prod.get("craftsmen", 0), national_prod.get("building_materials", 0),
		float(preview.get("tax_rate", 0.0)) * 100.0,
		float(preview.get("tax_efficiency", 0.0)) * 100.0,
		_build_culture_section(fid),
	]


## 本城文化：本国 + top2 对手；标出主流与是否冲突
func _build_culture_section(owner_fid: String) -> String:
	var cult: Dictionary = CityManager.get_city_culture(_city_id)
	if cult.is_empty():
		return I18n.t("city.culture_title") + "\n  " + I18n.t("city.culture_empty")
	var ranked: Array = []
	for fid_key in cult:
		ranked.append({"id": str(fid_key), "v": float(cult[fid_key])})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["v"]) > float(b["v"])
	)
	var total: float = 0.0
	for item in ranked:
		total += float(item["v"])
	if total <= 0.0:
		return I18n.t("city.culture_title") + "\n  " + I18n.t("city.culture_empty")

	var lines: Array[String] = [I18n.t("city.culture_title")]
	var shown: Dictionary = {}
	for item in ranked:
		if str(item["id"]) == owner_fid:
			shown[str(item["id"])] = float(item["v"])
			break
	for item in ranked:
		if shown.size() >= 3:
			break
		shown[str(item["id"])] = float(item["v"])
	for fid_key in shown:
		var pct: int = int(round(shown[fid_key] / total * 100.0))
		var bar_len: int = clampi(pct / 5, 0, 20)
		var bar: String = "█".repeat(bar_len)
		lines.append("  %s %d%% %s" % [_faction_display_name(str(fid_key)), pct, bar])
	var mainstream: String = CityManager.get_mainstream_culture(_city_id)
	if mainstream.is_empty():
		lines.append("  " + (I18n.t("city.culture_mainstream") % "-"))
	else:
		var tag: String = I18n.t("city.culture_match") if mainstream == owner_fid else I18n.t("city.culture_conflict")
		lines.append("  " + (I18n.t("city.culture_mainstream") % _faction_display_name(mainstream)) + " · " + tag)
	return "\n".join(lines)


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
		var effects_str: String = _effects_summary(_building_level_data(bdata, level).get("effects", {}), 1)
		var hex_q: int = int(b.get("hex_q", -9999))
		var hex_r: int = int(b.get("hex_r", -9999))
		var hex_str: String = ""
		if hex_q != -9999:
			hex_str = " @(%d,%d)" % [hex_q, hex_r]
		var hp_str: String = ""
		if b.has("structure_hp"):
			hp_str = " HP %d/%d" % [int(b.get("structure_hp", 0)), int(b.get("max_structure_hp", 0))]
		if bool(b.get("disabled", false)):
			hp_str += " [失效]"

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
		lbl.text = "%s Lv.%d%s%s  %s" % [bname, level, hex_str, hp_str, effects_str]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var b_hex: Vector2i = Vector2i(hex_q, hex_r)
		# 升级按钮
		var upgrade_check: Dictionary = CityManager.can_upgrade(_city_id, bid, b_hex)
		var up_btn := SkirmishTileTextures.styled_button(I18n.t("city.upgrade"))
		up_btn.add_theme_font_size_override("font_size", 12)
		up_btn.disabled = not upgrade_check["allowed"]
		SkirmishTileTextures.update_button_disabled(up_btn)
		if up_btn.disabled:
			up_btn.tooltip_text = _reason_text(upgrade_check["reason"])
		else:
			var next_level: Dictionary = _building_level_data(bdata, level + 1)
			var up_gold: int = int(next_level.get("cost_gold", 0))
			var up_wood: int = int(next_level.get("cost_wood", 0))
			up_btn.tooltip_text = "费用：%d金 %d木材" % [up_gold, up_wood]
		up_btn.pressed.connect(_on_upgrade_pressed.bind(bid, b_hex))
		row.add_child(up_btn)

		# 拆除按钮
		var del_btn := SkirmishTileTextures.styled_button(I18n.t("city.demolish"))
		del_btn.add_theme_font_size_override("font_size", 12)
		del_btn.pressed.connect(_on_demolish_pressed.bind(bid, b_hex))
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
	if not _is_own_city():
		var locked := Label.new()
		locked.text = "非己方城市：仅可查看信息，无法建造。"
		_build_list.add_child(locked)
		return

	var all_buildings: Array = DataManager.get_all_buildings()
	for bdata in all_buildings:
		var bid: String = str(bdata["id"])
		var bname: String = str(bdata.get("name", bid))
		var category: String = str(bdata.get("category", ""))
		var lv0_arr: Array = bdata.get("levels", [])
		var lv0: Dictionary = lv0_arr[0] if lv0_arr.size() > 0 else {}
		var cost_gold: int = int(lv0.get("cost_gold", 0))
		var cost_wood: int = int(lv0.get("cost_wood", 0))

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


func _refresh_recruit_list() -> void:
	for ch in _recruit_list.get_children():
		ch.queue_free()
	if not _is_own_city():
		var locked := Label.new()
		locked.text = "非己方城市：无法征兵。"
		_recruit_list.add_child(locked)
		return

	var city: Dictionary = CityManager.get_city_state(_city_id)
	if city.is_empty():
		return

	var faction_id: String = str(city.get("current_faction_id", ""))
	var avail: int = GameManager.get_available_conscription(faction_id)
	var max_cons: int = GameManager.get_max_conscription(faction_id)
	var active: int = GameManager.get_total_troops(faction_id)
	var pool_label := Label.new()
	pool_label.name = "RecruitPoolLabel"
	pool_label.text = "征兵（全局）：可服役 %d/%d ｜ 已服役 %d\n详见顶栏「兵源」悬浮；此处仅选择兵种与花费" % [
		avail, max_cons, active,
	]
	pool_label.tooltip_text = _conscription_progress_tooltip(_city_id)
	pool_label.add_theme_font_size_override("font_size", 13)
	pool_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74, 1))
	_recruit_list.add_child(pool_label)

	var recruitable_units: Array[String] = CityManager.get_recruitable_units(_city_id)
	if recruitable_units.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "（当前城市没有可征兵种）"
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1))
		_recruit_list.add_child(empty_lbl)
		return

	for unit_id: String in recruitable_units:
		var unit_data: Dictionary = DataManager.get_unit_type(unit_id)
		if unit_data.is_empty():
			continue
		var unit_name: String = str(unit_data.get("name", unit_id))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_recruit_list.add_child(row)

		var info := Label.new()
		info.text = "%s  金%d 粮%d 木%d 马%d 铁%d 工匠%d" % [
			unit_name,
			int(unit_data.get("cost_gold", 0)),
			int(unit_data.get("cost_food", 0)),
			int(unit_data.get("cost_wood", 0)),
			int(unit_data.get("cost_horse", 0)),
			int(unit_data.get("cost_refined_iron", 0)),
			int(unit_data.get("cost_craftsmen", 0)),
		]
		info.add_theme_font_size_override("font_size", 13)
		info.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 1))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var current_count: int = int(GameManager.get_unit_composition(faction_id).get(unit_id, 0))
		var count_label := Label.new()
		count_label.text = "已有 %d" % current_count
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.add_theme_color_override("font_color", Color(0.76, 0.82, 0.72, 1))
		row.add_child(count_label)

		var recruit_btn := SkirmishTileTextures.styled_button(I18n.t("city.recruit_one"))
		recruit_btn.name = "RecruitButton_%s" % unit_id
		recruit_btn.add_theme_font_size_override("font_size", 12)
		recruit_btn.disabled = not GameManager.is_player_faction(faction_id)
		if recruit_btn.disabled:
			recruit_btn.tooltip_text = "只有玩家城市可征兵"
		elif avail <= 0:
			recruit_btn.tooltip_text = "全局可服役池不足（见顶栏「兵源」）；每回合按最大征召×10% 填充"
		else:
			recruit_btn.tooltip_text = "从全局可服役池征发 1 队 %s（扣池与资源，不扣城人口）" % unit_name
		SkirmishTileTextures.update_button_disabled(recruit_btn)
		recruit_btn.pressed.connect(_on_recruit_pressed.bind(unit_id))
		row.add_child(recruit_btn)


func _show_default_detail() -> void:
	_detail_label.text = "点击建筑按钮查看详细信息；右侧征兵区使用正式人口、资源与兵种构成逻辑。"


func _show_building_detail(building_id: String) -> void:
	_selected_building_id = building_id
	var bdata: Dictionary = DataManager.get_building(building_id)
	if bdata.is_empty():
		_detail_label.text = "未知建筑"
		return

	var bname: String = str(bdata.get("name", building_id))
	var desc: String = str(bdata.get("description", ""))
	var category: String = _category_name(str(bdata.get("category", "")))
	var lv1: Dictionary = _building_level_data(bdata, 1)
	var cost_gold: int = int(lv1.get("cost_gold", 0))
	var cost_wood: int = int(lv1.get("cost_wood", 0))
	var build_turns: int = int(lv1.get("build_turns", 1))
	var max_level: int = int(bdata.get("max_level", 1))
	var upkeep: int = int(bdata.get("upkeep_gold", 0))
	var effects: Dictionary = lv1.get("effects", {})
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
	if effects.is_empty():
		lines.append("  （无直接数值效果）")
	else:
		for key in effects:
			lines.append("  %s: %s" % [_effect_display_name(key), _format_effect_value(key, effects[key])])
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
	if not _is_own_city():
		_status_label.text = "非己方城市，无法建造。"
		return
	var check: Dictionary = CityManager.can_build(_city_id, building_id)
	if not check["allowed"]:
		_status_label.text = "建造失败：%s" % _reason_text(str(check.get("reason", "UNKNOWN")))
		return
	place_building_requested.emit(_city_id, building_id)
	# 无宿主监听时自动落到空闲辖区格，保证建造仍可完成
	if place_building_requested.get_connections().is_empty():
		for cell: Vector2i in CityManager.get_jurisdiction_hexes(_city_id):
			if CityManager.start_build(_city_id, building_id, cell):
				_status_label.text = "已自动放置于 (%d,%d)，回合计完成建造。" % [cell.x, cell.y]
				_refresh_all()
				_refresh_resource_bar()
				return
		_status_label.text = "建造失败：无空闲辖区格"
		return
	_status_label.text = "请在地图上点击绿色辖区格放置（右键取消）。"


func _free_jurisdiction_hexes_for(building_id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in CityManager.get_jurisdiction_hexes(_city_id):
		var hex_check: Dictionary = CityManager.can_build(_city_id, building_id, cell)
		if bool(hex_check.get("allowed", false)):
			out.append(cell)
	return out


func _do_build_on_hex(building_id: String, axial: Vector2i) -> void:
	if CityManager.start_build(_city_id, building_id, axial):
		var bname: String = str(DataManager.get_building(building_id).get("name", building_id))
		_status_label.text = "已加入建造队列：%s → 辖区格(%d,%d)。" % [bname, axial.x, axial.y]
		_refresh_all()
		_refresh_resource_bar()
	else:
		_status_label.text = "建造失败：%s" % _reason_text(str(CityManager.can_build(_city_id, building_id, axial).get("reason", "UNKNOWN")))


## 辖区六格选点弹窗（决策 #123 实体建筑）。
func _show_hex_picker(building_id: String, free_hexes: Array[Vector2i]) -> void:
	var win := Window.new()
	win.title = "选择建筑位置（辖区）"
	win.size = Vector2i(420, 360)
	win.unresizable = true
	win.always_on_top = true
	add_child(win)
	win.popup_centered()

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	win.add_child(root)

	var hint := Label.new()
	var bname: String = str(DataManager.get_building(building_id).get("name", building_id))
	hint.text = "为「%s」选择要放置的辖区六角格：" % bname
	hint.add_theme_font_size_override("font_size", 14)
	root.add_child(hint)

	for cell: Vector2i in CityManager.get_jurisdiction_hexes(_city_id):
		var terrain_id: String = CityManager.get_big_map_terrain_id(cell.x, cell.y)
		var occupied: bool = not CityManager.get_building_at_hex(cell).is_empty()
		var free: bool = free_hexes.has(cell)
		var label: String = "(%d,%d) %s" % [cell.x, cell.y, terrain_id]
		if occupied:
			label += " [已有建筑]"
		elif not free:
			label += " [不可建]"
		var btn := SkirmishTileTextures.styled_button(label)
		btn.disabled = not free
		SkirmishTileTextures.update_button_disabled(btn)
		btn.pressed.connect(func() -> void:
			_do_build_on_hex(building_id, cell)
			win.queue_free()
		)
		root.add_child(btn)

	var cancel := SkirmishTileTextures.styled_button("取消")
	cancel.pressed.connect(func() -> void:
		win.queue_free()
	)
	root.add_child(cancel)


func _on_upgrade_pressed(building_id: String, target_hex: Vector2i = Vector2i(-9999, -9999)) -> void:
	if CityManager.start_upgrade(_city_id, building_id, target_hex):
		_refresh_all()
		_refresh_resource_bar()


func _on_demolish_pressed(building_id: String, target_hex: Vector2i = Vector2i(-9999, -9999)) -> void:
	if CityManager.demolish(_city_id, building_id, target_hex):
		_refresh_all()
		_refresh_resource_bar()


func _on_detail_pressed(building_id: String) -> void:
	_show_building_detail(building_id)


func _on_cancel_build_pressed(queue_index: int) -> void:
	if CityManager.cancel_build(_city_id, queue_index):
		_status_label.text = "已取消建造，建造费用已返还。"
		_refresh_all()
		_refresh_resource_bar()


func _on_recruit_pressed(unit_id: String) -> void:
	var result: Dictionary = GameManager.recruit_unit_from_city(_city_id, unit_id, 1)
	var message: String = ""
	if bool(result.get("success", false)):
		var deployed: Dictionary = {}
		if DemoFlow.is_tutorial_enabled() and TacticalSkirmishManager.is_active():
			deployed = TacticalSkirmishManager.add_player_recruited_unit(unit_id)
		var strategic_id: String = str(result.get("strategic_unit_id", ""))
		message = "已征发 %d 队 %s。" % [
			int(result.get("recruited", 0)),
			str(DataManager.get_unit_type(unit_id).get("name", unit_id)),
		]
		if strategic_id != "":
			message += " 已在大地图本城格生成部队，可打开大地图选中移动/作战。"
		if not deployed.is_empty() and bool(deployed.get("ok", false)):
			message += " 新部队已进入演武地图。"
		elif not deployed.is_empty():
			message += " 但演武地图布置失败：%s。" % str(deployed.get("reason", "UNKNOWN"))
	else:
		message = "征兵失败：%s" % _reason_text(str(result.get("reason", "UNKNOWN")))
	_refresh_all()
	_status_label.text = message
	_detail_label.text = message
	_refresh_resource_bar()


func _on_building_completed(_cid: String, _bid: String, _level: int) -> void:
	if _cid == _city_id:
		_queue_refresh_all()


func _refresh_resource_bar() -> void:
	for bar: Node in get_tree().get_nodes_in_group("resource_bar"):
		if bar != null and bar.has_method("refresh"):
			bar.refresh()


# ── 工具函数 ──────────────────────────────────────

func _faction_display_name(faction_id: String) -> String:
	var f: Dictionary = DataManager.get_faction(faction_id)
	if not f.is_empty():
		return str(f.get("name", faction_id))
	return faction_id


func _special_resource_name(sr: String) -> String:
	var special_res: Variant = DataManager.get_balance_param("resources.special_resources")
	if special_res is Dictionary and (special_res as Dictionary).has(sr):
		var entry: Dictionary = (special_res as Dictionary)[sr] as Dictionary
		var bonus_text: String = str(entry.get("bonus_description", ""))
		if bonus_text != "":
			return bonus_text
		return str(entry.get("description", sr))
	return sr


func _category_name(cat: String) -> String:
	match cat:
		"economic": return I18n.t("city.category_economic")
		"military": return I18n.t("city.category_military")
		"political": return I18n.t("city.category_political")
		"special": return I18n.t("city.category_special")
		_: return cat


func _effects_summary(effects: Dictionary, level: int) -> String:
	var parts: PackedStringArray = []
	for key in effects:
		var val: Variant = effects[key]
		if val is int or val is float:
			parts.append("%s+%s" % [_effect_display_name(key), _format_effect_value(key, val)])
	return "(%s)" % ", ".join(parts) if parts.size() > 0 else ""


func _building_level_data(bdata: Dictionary, level: int) -> Dictionary:
	var levels: Array = bdata.get("levels", [])
	if levels.is_empty():
		return {}
	var index: int = clampi(level - 1, 0, levels.size() - 1)
	return levels[index] as Dictionary


func _format_effect_value(key: String, value: Variant) -> String:
	if value is float:
		var f: float = float(value)
		if key.ends_with("_bonus") or key.contains("reduction") or absf(f) < 1.0:
			return "%+d%%" % int(round(f * 100.0))
		return "%+g" % f
	if value is int:
		return "%+d" % int(value)
	return str(value)


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


func _progress_bar_text(ratio: float, width: int = 12) -> String:
	var r: float = clampf(ratio, 0.0, 1.0)
	var filled: int = int(round(r * float(width)))
	var s: String = "["
	for i: int in range(width):
		s += "█" if i < filled else "░"
	return s + "]"


func _conscription_progress_tooltip(_city_id: String) -> String:
	var fid: String = GameManager.get_player_faction()
	if fid == "":
		fid = str(CityManager.get_city_state(_city_id).get("current_faction_id", ""))
	var avail: int = GameManager.get_available_conscription(fid)
	var mx: int = GameManager.get_max_conscription(fid)
	var active: int = GameManager.get_total_troops(fid)
	return "兵源为全局池（决策 #94）\n可服役 %d / 最大征召 %d（已服役 %d）\n详细进度与公式：请看顶栏「兵源」悬浮\n征兵消耗：池 + 兵种资源，不扣本城人口" % [avail, mx, active]


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
		"INVALID_HEX": return "无效格子"
		"HEX_OUT_OF_JURISDICTION": return "不在城市辖区内"
		"HEX_OCCUPIED": return "该格已有建筑"
		"HEX_RESERVED": return "该格已在建造队列中"
		"HEX_TERRAIN": return "地形不允许该建筑"
		_: return reason
