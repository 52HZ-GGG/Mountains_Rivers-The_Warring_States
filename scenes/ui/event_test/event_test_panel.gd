extends Panel
## 事件测试面板（控制中枢「事件」模块）
## 按 8 类别分组浏览全部事件，无视概率/条件一键触发预览。
## 铁律：纯展示、零结算。绝不调用 EventManager 的任何方法，绝不 emit SignalBus.event_triggered，
## 触发测试只展示事件描述与效果预览，点任意按钮仅关闭展示。

signal closed

const GOLD: Color = Color(0.784, 0.659, 0.306, 1.0)
const CREAM: Color = Color(0.86, 0.82, 0.72, 1.0)
const DIM_GRAY: Color = Color(0.62, 0.55, 0.42, 1.0)
const DARK_BG: Color = Color(0.09, 0.075, 0.055, 0.97)

const CATEGORY_ORDER: Array[String] = [
	"economy", "military", "morale", "season",
	"politics", "diplomacy", "school", "special",
]
const CATEGORY_NAMES: Dictionary = {
	"economy": "经济",
	"military": "军事",
	"morale": "民心",
	"season": "季节",
	"politics": "政治",
	"diplomacy": "外交",
	"school": "学派",
	"special": "特殊",
}
const FACTION_NAMES: Dictionary = {
	"qin": "秦国",
	"zhao": "赵国",
	"qi": "齐国",
	"chu": "楚国",
	"wei": "魏国",
	"yan": "燕国",
	"han": "韩国",
	"zhou": "周室",
	"neutral": "中立",
}
const SEASON_NAMES: Dictionary = {
	"spring": "春",
	"summer": "夏",
	"autumn": "秋",
	"winter": "冬",
}
const EFFECT_NAMES: Dictionary = {
	"food_delta": "粮草",
	"gold_delta": "金钱",
	"wood_delta": "木材",
	"craftsmen_delta": "工匠",
	"building_materials_delta": "建材",
	"morale_delta": "民心",
	"population_delta": "人口",
	"troops_delta": "兵力",
	"horse_delta": "战马",
	"refined_iron_delta": "精铁",
	"school_exp": "学派经验",
	"reputation_change": "声望",
	"reputation_delta": "声望变化",
	"tribute_change": "朝贡",
	"stability_delta": "稳定度",
	"special_victory": "特殊胜利",
	"grant_ability": "授予能力",
	"opinion_change_aid_factions": "援救势力好感",
	"opinion_change_all_hezong_members": "合纵成员好感",
	"opinion_change_all_lianheng_members": "连横成员好感",
	"opinion_change_defector_all": "叛离势力好感",
	"opinion_change_lianheng_allies": "连横盟友好感",
	"diplomacy_random_opinion_shift": "随机外交好感偏移",
	"diplomacy_hezong_trigger": "合纵触发",
	"diplomacy_hezong_dissolve": "合纵解散",
	"diplomacy_hezong_defection": "合纵叛离",
	"diplomacy_lianheng_trigger": "连横触发",
	"diplomacy_lianheng_dissolve": "连横解散",
	"diplomacy_lianheng_backlash": "连横反噬",
	"diplomacy_independence_bonus": "独立加成",
	"diplomacy_zhou_aid": "周室援助",
	"diplomacy_nine_tripods": "九鼎",
}

var _layer: CanvasLayer = null
var _tabs_box: HBoxContainer = null
var _tab_buttons: Array[Button] = []
var _list_box: VBoxContainer = null
var _current_category: String = "economy"
var _current_event: Dictionary = {}
var _events_by_category: Dictionary = {}
var _detail_title: Label = null
var _detail_desc: Label = null
var _detail_stats: Label = null
var _detail_conditions: Label = null
var _showcase_dim: ColorRect = null
var _showcase_card: PanelContainer = null
var _showcase_title: Label = null
var _showcase_desc: Label = null
var _showcase_effects: Label = null


func _ready() -> void:
	_build_ui()
	visible = false


## 打开：确保 CanvasLayer 挂载、重建类别与列表、显示
func open() -> void:
	_ensure_layer()
	_rebuild_data()
	_build_tabs()
	_rebuild_list()
	visible = true
	if is_instance_valid(_layer):
		_layer.visible = true


## 关闭：隐藏并释放 CanvasLayer（面板实例由外部释放）
func close() -> void:
	_hide_showcase()
	visible = false
	if is_instance_valid(_layer):
		_layer.visible = false
		if get_parent() == _layer:
			_layer.remove_child(self)
		_layer.free()
		_layer = null
	closed.emit()


## 当前是否处于打开状态
func is_open() -> bool:
	return visible and is_instance_valid(_layer) and _layer.visible


# ============= 挂载 =============

func _ensure_layer() -> void:
	if is_instance_valid(_layer):
		_layer.visible = true
		return
	_layer = CanvasLayer.new()
	_layer.name = "EventTestLayer"
	_layer.layer = 80
	var host: Node = null
	if get_tree() != null:
		host = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	if host == null:
		return
	host.add_child(_layer)
	if get_parent() != _layer:
		var prev_parent: Node = get_parent()
		if prev_parent != null:
			prev_parent.remove_child(self)
		_layer.add_child(self)


# ============= 数据 =============

func _rebuild_data() -> void:
	_events_by_category.clear()
	for cat: String in CATEGORY_ORDER:
		_events_by_category[cat] = []
	var events: Array = DataManager.get_all_events()
	for raw: Variant in events:
		var evt: Dictionary = raw as Dictionary
		var cat: String = str(evt.get("category", "uncategorized"))
		if not _events_by_category.has(cat):
			_events_by_category[cat] = []
		(_events_by_category[cat] as Array).append(evt)


# ============= UI 构建 =============

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", _main_style())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# 标题行
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "事件测试面板"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)

	var hint := Label.new()
	hint.text = "纯展示 · 零结算（触发测试仅预览，不改变任何状态）"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", DIM_GRAY)
	header.add_child(hint)

	# 类别 Tab 行（横向可滚动）
	var tab_scroll := ScrollContainer.new()
	tab_scroll.name = "CategoryTabScroll"
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.custom_minimum_size = Vector2(0, 46)
	root_vbox.add_child(tab_scroll)

	_tabs_box = HBoxContainer.new()
	_tabs_box.name = "CategoryTabs"
	_tabs_box.add_theme_constant_override("separation", 8)
	tab_scroll.add_child(_tabs_box)

	# 主体：左列表 + 右详情
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root_vbox.add_child(body)

	# 左：事件列表
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)

	var left_title := Label.new()
	left_title.text = "事件列表"
	left_title.add_theme_font_size_override("font_size", 14)
	left_title.add_theme_color_override("font_color", DIM_GRAY)
	left.add_child(left_title)

	var list_scroll := ScrollContainer.new()
	list_scroll.name = "EventListScroll"
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left.add_child(list_scroll)

	_list_box = VBoxContainer.new()
	_list_box.name = "EventList"
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 6)
	list_scroll.add_child(_list_box)

	body.add_child(HSeparator.new())

	# 右：详情区
	var right := VBoxContainer.new()
	right.name = "DetailArea"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)

	var right_title := Label.new()
	right_title.text = "事件详情"
	right_title.add_theme_font_size_override("font_size", 14)
	right_title.add_theme_color_override("font_color", DIM_GRAY)
	right.add_child(right_title)

	_detail_title = Label.new()
	_detail_title.name = "DetailTitle"
	_detail_title.add_theme_font_size_override("font_size", 22)
	_detail_title.add_theme_color_override("font_color", GOLD)
	right.add_child(_detail_title)

	_detail_desc = Label.new()
	_detail_desc.name = "DetailDesc"
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", 16)
	_detail_desc.add_theme_color_override("font_color", CREAM)
	right.add_child(_detail_desc)

	_detail_stats = Label.new()
	_detail_stats.name = "DetailStats"
	_detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_stats.add_theme_font_size_override("font_size", 14)
	_detail_stats.add_theme_color_override("font_color", Color(0.88, 0.82, 0.66, 1.0))
	right.add_child(_detail_stats)

	right.add_child(HSeparator.new())

	var cond_title := Label.new()
	cond_title.text = "触发条件"
	cond_title.add_theme_font_size_override("font_size", 14)
	cond_title.add_theme_color_override("font_color", DIM_GRAY)
	right.add_child(cond_title)

	_detail_conditions = Label.new()
	_detail_conditions.name = "DetailConditions"
	_detail_conditions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_conditions.add_theme_font_size_override("font_size", 14)
	_detail_conditions.add_theme_color_override("font_color", CREAM)
	right.add_child(_detail_conditions)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	right.add_child(actions)

	var trigger_btn: Button = SkirmishTileTextures.styled_button("触发测试")
	trigger_btn.name = "TriggerTestButton"
	trigger_btn.custom_minimum_size = Vector2(140, 42)
	trigger_btn.pressed.connect(_on_trigger_pressed)
	actions.add_child(trigger_btn)

	var close_btn: Button = SkirmishTileTextures.styled_button("关闭")
	close_btn.name = "CloseButton"
	close_btn.custom_minimum_size = Vector2(110, 42)
	close_btn.pressed.connect(_on_close_pressed)
	actions.add_child(close_btn)

	_build_showcase()


func _build_showcase() -> void:
	# 触发测试只读展示层：半透明遮罩 + 居中卡片，任意按钮仅关闭
	_showcase_dim = ColorRect.new()
	_showcase_dim.name = "ShowcaseDim"
	_showcase_dim.color = Color(0, 0, 0, 0.68)
	_showcase_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_showcase_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_showcase_dim.visible = false
	# 点击遮罩任意处也可关闭展示层，避免误以为界面卡死
	_showcase_dim.gui_input.connect(_on_showcase_dim_input)
	add_child(_showcase_dim)

	_showcase_card = PanelContainer.new()
	_showcase_card.name = "ShowcaseCard"
	_showcase_card.custom_minimum_size = Vector2(840, 0)
	_showcase_card.add_theme_stylebox_override("panel", _showcase_style())
	_showcase_card.visible = false
	# 包进 CenterContainer 由容器自动居中，避免锚点偏移导致卡片出现在屏幕外
	var showcase_center := CenterContainer.new()
	showcase_center.name = "ShowcaseCenter"
	showcase_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	showcase_center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(showcase_center)
	showcase_center.add_child(_showcase_card)

	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 10)
	_showcase_card.add_child(card_box)

	var card_header := HBoxContainer.new()
	card_box.add_child(card_header)

	_showcase_title = Label.new()
	_showcase_title.name = "ShowcaseTitle"
	_showcase_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_showcase_title.add_theme_font_size_override("font_size", 24)
	_showcase_title.add_theme_color_override("font_color", GOLD)
	card_header.add_child(_showcase_title)

	var tag := Label.new()
	tag.text = "只读预览"
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", DIM_GRAY)
	card_header.add_child(tag)

	_showcase_desc = Label.new()
	_showcase_desc.name = "ShowcaseDesc"
	_showcase_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_showcase_desc.custom_minimum_size = Vector2(780, 0)
	_showcase_desc.add_theme_font_size_override("font_size", 16)
	_showcase_desc.add_theme_color_override("font_color", CREAM)
	card_box.add_child(_showcase_desc)

	card_box.add_child(HSeparator.new())

	var effects_title := Label.new()
	effects_title.text = "效果预览（纯展示，不结算）"
	effects_title.add_theme_font_size_override("font_size", 14)
	effects_title.add_theme_color_override("font_color", DIM_GRAY)
	card_box.add_child(effects_title)

	_showcase_effects = Label.new()
	_showcase_effects.name = "ShowcaseEffects"
	_showcase_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_showcase_effects.custom_minimum_size = Vector2(780, 0)
	_showcase_effects.add_theme_font_size_override("font_size", 15)
	_showcase_effects.add_theme_color_override("font_color", CREAM)
	card_box.add_child(_showcase_effects)

	var card_actions := HBoxContainer.new()
	card_box.add_child(card_actions)

	var show_close: Button = SkirmishTileTextures.styled_button("关闭")
	show_close.name = "ShowcaseCloseButton"
	show_close.custom_minimum_size = Vector2(110, 40)
	show_close.pressed.connect(_on_showcase_close)
	card_actions.add_child(show_close)


func _main_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DARK_BG
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	return style


func _showcase_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.085, 0.065, 0.98)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	return style


# ============= 类别 Tab =============

func _build_tabs() -> void:
	for child: Node in _tabs_box.get_children():
		child.queue_free()
	_tab_buttons.clear()
	for cat: String in CATEGORY_ORDER:
		var count: int = (_events_by_category.get(cat, []) as Array).size()
		var btn: Button = SkirmishTileTextures.styled_button("%s(%d)" % [str(CATEGORY_NAMES.get(cat, cat)), count])
		btn.name = "Tab_%s" % cat
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_tab_pressed.bind(cat))
		_tabs_box.add_child(btn)
		_tab_buttons.append(btn)
	_refresh_tab_highlight()


func _refresh_tab_highlight() -> void:
	for btn: Button in _tab_buttons:
		var cat: String = str(btn.name).trim_prefix("Tab_")
		btn.button_pressed = cat == _current_category
		btn.add_theme_color_override("font_color", GOLD if cat == _current_category else Color(0.91, 0.835, 0.69, 1.0))


func _on_tab_pressed(category: String) -> void:
	if _current_category == category:
		return
	_current_category = category
	_refresh_tab_highlight()
	_rebuild_list()


# ============= 事件列表 =============

func _rebuild_list() -> void:
	for child: Node in _list_box.get_children():
		child.queue_free()
	var events: Array = _events_by_category.get(_current_category, []) as Array
	if events.is_empty():
		var empty := Label.new()
		empty.text = "（该类别暂无事件）"
		empty.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45, 1.0))
		_list_box.add_child(empty)
		_current_event = {}
		_refresh_detail()
		return
	for raw: Variant in events:
		var evt: Dictionary = raw as Dictionary
		var btn: Button = SkirmishTileTextures.styled_button(str(evt.get("title", "未命名事件")))
		btn.name = "Evt_%s" % str(evt.get("id", ""))
		btn.tooltip_text = str(evt.get("id", ""))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 38)
		btn.pressed.connect(_on_event_button_pressed.bind(evt))
		_list_box.add_child(btn)
	_select_event(events[0] as Dictionary)


func _on_event_button_pressed(event: Dictionary) -> void:
	_select_event(event)


func _select_event(event: Dictionary) -> void:
	_current_event = event
	_refresh_detail()


# ============= 详情区 =============

func _refresh_detail() -> void:
	if _current_event.is_empty():
		_detail_title.text = "（未选择事件）"
		_detail_desc.text = ""
		_detail_stats.text = ""
		_detail_conditions.text = ""
		return
	var trigger: Dictionary = _current_event.get("trigger", {}) as Dictionary
	var stats: String = "概率:%s  |  冷却:%s  |  %s  |  %s" % [
		_format_probability(trigger),
		_cooldown_text(_current_event, trigger),
		_one_shot_text(_current_event, trigger),
		_options_text(_current_event),
	]
	_detail_title.text = str(_current_event.get("title", "未命名事件"))
	_detail_desc.text = str(_current_event.get("description", ""))
	_detail_stats.text = stats
	var conditions: Array[String] = _describe_conditions(trigger.get("conditions", {}) as Dictionary)
	_detail_conditions.text = "\n".join(conditions) if not conditions.is_empty() else "（无触发条件）"


func _format_probability(trigger: Dictionary) -> String:
	var prob: float = float(trigger.get("probability", 0.0))
	if prob > 1.0:
		return "%d%%" % int(prob)
	return "%d%%" % int(round(prob * 100.0))


func _cooldown_text(event: Dictionary, trigger: Dictionary) -> String:
	if bool(trigger.get("one_shot", false)):
		return "一次性（永不重复）"
	var value: int = 3
	var by_type: Variant = DataManager.get_balance_param("event_cooldown_by_type")
	var category: String = str(event.get("category", ""))
	if by_type is Dictionary and (by_type as Dictionary).has(category):
		value = int((by_type as Dictionary)[category])
	else:
		var fallback: Variant = DataManager.get_balance_param("event_cooldown_turns")
		value = int(fallback) if fallback != null else 3
	if value >= 999:
		return "永久冷却"
	if value <= 0:
		return "无冷却"
	return "%d回合" % value


func _one_shot_text(event: Dictionary, trigger: Dictionary) -> String:
	var one_shot: bool = bool(trigger.get("one_shot", false)) or bool(event.get("one_time", false))
	return "一次性:是" if one_shot else "一次性:否"


func _options_text(event: Dictionary) -> String:
	var options: Variant = event.get("options")
	if options is Array and not (options as Array).is_empty():
		return "选项:有（%d个）" % (options as Array).size()
	return "选项:无"


# ============= 触发条件中文解释（15 键全覆盖） =============

func _describe_conditions(conditions: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if conditions.is_empty():
		return lines
	for key: Variant in conditions.keys():
		var k: String = str(key)
		var v: Variant = conditions[key]
		match k:
			"season":
				lines.append("季节:%s" % _season_display_names(v))
			"turn_min":
				lines.append("回合:≥%d" % int(v))
			"turn_max":
				lines.append("回合:≤%d" % int(v))
			"morale_min":
				lines.append("民心:≥%d" % int(v))
			"morale_max":
				lines.append("民心:≤%d" % int(v))
			"border_north":
				lines.append("北方边境:%s" % _bool_text(v))
			"faction":
				lines.append("势力:%s" % _faction_list_text(v))
			"allies_min":
				lines.append("盟友数:≥%d" % int(v))
			"at_war":
				lines.append("处于战争:%s" % _bool_text(v))
			"at_war_with":
				lines.append("与…交战:%s" % _faction_list_text(v))
			"has_alliance":
				lines.append("拥有同盟:%s" % _bool_text(v))
			"reputation_min":
				lines.append("声望:≥%d" % int(v))
			"school":
				lines.append("学派:%s" % _school_list_text(v))
			"tribute_min":
				lines.append("朝贡:≥%d" % int(v))
			"troops_in_hex_range":
				lines.append("周围六格内有军队:%s" % _troops_range_text(v))
			_:
				lines.append("其他条件:%s=%s" % [k, str(v)])
	return lines


func _season_display_names(v: Variant) -> String:
	var names: Array[String] = []
	if v is Array:
		for item: Variant in v:
			names.append(str(SEASON_NAMES.get(str(item), str(item))))
	else:
		names.append(str(SEASON_NAMES.get(str(v), str(v))))
	return "、".join(names)


func _faction_display_name(fid: String) -> String:
	var faction: Dictionary = DataManager.get_faction(fid)
	if not faction.is_empty() and str(faction.get("name", "")) != "":
		return str(faction.get("name", fid))
	return str(FACTION_NAMES.get(fid, fid))


func _faction_list_text(v: Variant) -> String:
	var names: Array[String] = []
	if v is Array:
		for item: Variant in v:
			names.append(_faction_display_name(str(item)))
	else:
		names.append(_faction_display_name(str(v)))
	return "、".join(names)


func _school_display_name(sid: String) -> String:
	var school: Dictionary = DataManager.get_school(sid)
	if not school.is_empty() and str(school.get("name", "")) != "":
		return str(school.get("name", sid))
	return sid


func _school_list_text(v: Variant) -> String:
	var names: Array[String] = []
	if v is Array:
		for item: Variant in v:
			names.append(_school_display_name(str(item)))
	else:
		names.append(_school_display_name(str(v)))
	return "、".join(names)


func _troops_range_text(v: Variant) -> String:
	if v is Dictionary:
		var d: Dictionary = v as Dictionary
		var radius: int = int(d.get("radius", 0))
		var center: Variant = d.get("center", [])
		var parts: Array[String] = []
		if center is Array:
			for x: Variant in center:
				parts.append(str(x))
		var center_text: String = "（中心[%s]）" % ",".join(parts) if not parts.is_empty() else ""
		return "半径%d%s" % [radius, center_text]
	return str(v)


func _bool_text(v: Variant) -> String:
	return "是" if bool(v) else "否"


# ============= 效果预览（纯展示） =============

func _effect_preview_lines(event: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var options: Variant = event.get("options")
	if options is Array and not (options as Array).is_empty():
		for opt_v: Variant in options:
			var opt: Dictionary = opt_v as Dictionary
			var opt_id: String = str(opt.get("id", "?"))
			var opt_text: String = str(opt.get("text", ""))
			var effects: Dictionary = opt.get("outcomes", {}) as Dictionary
			lines.append("【选项 %s】%s" % [opt_id, opt_text])
			lines.append("    效果：%s" % "、".join(_format_effects(effects)))
		return lines
	var variants: Array = event.get("effects_variants", []) as Array
	if not variants.is_empty():
		for variant_v: Variant in variants:
			var variant: Dictionary = variant_v as Dictionary
			var prob: float = float(variant.get("probability", 0.0))
			var effects: Dictionary = variant.get("effects", {}) as Dictionary
			lines.append("◆ 档位（%d%%）：%s" % [int(round(prob * 100.0)), "、".join(_format_effects(effects))])
		return lines
	var effects: Dictionary = event.get("effects", {}) as Dictionary
	lines.append("◆ 效果：%s" % "、".join(_format_effects(effects)))
	return lines


func _format_effects(effects: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if effects.is_empty():
		lines.append("（无直接数值效果）")
		return lines
	for key: Variant in EFFECT_NAMES.keys():
		if not effects.has(key):
			continue
		var v: Variant = effects[key]
		if v is int or v is float:
			var n: int = int(v)
			if n == 0:
				continue
			lines.append("%s%s%d" % [str(EFFECT_NAMES[key]), "+" if n > 0 else "", n])
		else:
			lines.append("%s:%s" % [str(EFFECT_NAMES[key]), str(v)])
	for key: Variant in effects.keys():
		if not EFFECT_NAMES.has(str(key)):
			lines.append("%s=%s" % [str(key), str(effects[key])])
	if lines.is_empty():
		lines.append("（无直接数值效果）")
	return lines


# ============= 触发测试（只读展示） =============

func _on_trigger_pressed() -> void:
	if not _current_event.is_empty():
		_show_event_preview(_current_event)


func _show_event_preview(event: Dictionary) -> void:
	_showcase_title.text = str(event.get("title", "未命名事件"))
	_showcase_desc.text = str(event.get("description", ""))
	_showcase_effects.text = "\n".join(_effect_preview_lines(event))
	_showcase_dim.visible = true
	_showcase_card.visible = true


func _on_showcase_close() -> void:
	_hide_showcase()


## 点击展示层遮罩（黑罩）任意处关闭展示层
func _on_showcase_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_hide_showcase()


func _hide_showcase() -> void:
	if is_instance_valid(_showcase_dim):
		_showcase_dim.visible = false
	if is_instance_valid(_showcase_card):
		_showcase_card.visible = false


func _on_close_pressed() -> void:
	close()
