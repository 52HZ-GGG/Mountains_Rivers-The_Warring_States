extends Node

## 主场景脚本 — 连接 UI 和游戏系统

var _diplomacy_scene: PackedScene = preload("res://scenes/ui/diplomacy/diplomacy_panel.tscn")
var _diplomacy_panel: Panel = null
var _big_map_scene: PackedScene = preload("res://scenes/ui/big_map/big_map_panel.tscn")
var _big_map_panel: CanvasLayer = null
var _city_panel_scene: PackedScene = preload("res://scenes/ui/city_panel/city_panel.tscn")
var _city_panel: Panel = null
var _last_big_map_city_focus_id: String = ""
var _formal_demo_big_map_opened: bool = false
var _event_popup_scene: PackedScene = preload("res://scenes/ui/event_popup/event_popup.tscn")
var _event_popup: Panel = null
var _event_test_scene: PackedScene = preload("res://scenes/ui/event_test/event_test_panel.tscn")
var _event_test_panel: Panel = null
var _scenario_panel_scene: PackedScene = preload("res://scenes/ui/skirmish/skirmish_scenario_panel.tscn")
var _scenario_panel: CanvasLayer = null
var _skirmish_panel_scene: PackedScene = preload("res://scenes/ui/skirmish/skirmish_mvp_panel.tscn")
var _active_skirmish_panel: CanvasLayer = null
var _demo_objective_scene: PackedScene = preload("res://scenes/ui/demo/demo_objective_panel.tscn")
var _demo_victory_scene: PackedScene = preload("res://scenes/ui/demo/demo_victory_popup.tscn")
var _demo_layer: CanvasLayer = null
var _demo_objective_panel: PanelContainer = null
var _demo_victory_popup: PanelContainer = null
var _demo_expand_btn: Button = null
var _resource_bar: Control = null
var _event_test_btn: Button = null
var _return_mode_btn: Button = null
var _toolbar_elements: Array[Control] = []
var _debug_tools_enabled: bool = false
var _framework_hub_layer: CanvasLayer = null
var _framework_hub: Control = null
var _framework_hub_root: Control = null
var _framework_hub_scroll: ScrollContainer = null
var _framework_zoom_label: Label = null
var _framework_zoom_scale: float = 1.0
var _framework_placeholder_layer: CanvasLayer = null
var _framework_placeholder_panel: PanelContainer = null
var _framework_placeholder_title: Label = null
var _framework_placeholder_body: RichTextLabel = null
var _framework_placeholder_actions: HBoxContainer = null
var _framework_placeholder_scroll: ScrollContainer = null

var _turn_info_layer: CanvasLayer = null
var _turn_info_panel: PanelContainer = null
var _turn_info_title: Label = null
var _turn_info_season: Label = null
var _turn_info_faction: Label = null
var _turn_info_status: Label = null
var _turn_info_tween: Tween = null

var _end_turn_layer: CanvasLayer = null
var _persistent_end_btn: Button = null
var _is_processing_turn: bool = false

const SEASON_NAMES: Dictionary = {
	"spring": "春",
	"summer": "夏",
	"autumn": "秋",
	"winter": "冬",
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

const FRAMEWORK_QUICK_SAVE_PATH: String = "user://framework_quick_save.json"
const DEMO_CHEAT_ATTACK_MULTIPLIER: float = 20.0


func _ready() -> void:
	_debug_tools_enabled = OS.has_feature("debug")
	StartupFlow.trace("Main._ready begin phase=%s pending=%s mode=%s faction=%s" % [
		GameManager.Phase.keys()[GameManager.get_current_phase()],
		str(StartupFlow.is_game_start_pending()),
		StartupFlow.selected_mode,
		StartupFlow.selected_faction,
	])
	_resource_bar = $ResourceBar as Control
	_resource_bar.visible = false

	var diplomacy_button := $DiplomacyButton as Button
	diplomacy_button.pressed.connect(_on_diplomacy_button_pressed)

	var tech_button := $TechButton as Button
	tech_button.pressed.connect(_on_tech_button_pressed)

	var skirmish_button := $SkirmishButton as Button
	skirmish_button.pressed.connect(_on_skirmish_button_pressed)

	var big_map_button := $BigMapButton as Button
	big_map_button.pressed.connect(_on_big_map_button_pressed)

	_init_game()

	_event_popup = _event_popup_scene.instantiate() as Panel
	add_child(_event_popup)

	var big_map_btn := $BigMapButton as Button
	if _debug_tools_enabled:
		var event_test_btn := SkirmishTileTextures.styled_button("事件测试(Debug)")
		event_test_btn.pressed.connect(_on_event_test_button_pressed)
		big_map_btn.get_parent().add_child(event_test_btn)
		big_map_btn.get_parent().move_child(event_test_btn, big_map_btn.get_index() + 1)
		_event_test_btn = event_test_btn

	var return_mode_btn := SkirmishTileTextures.styled_button("返回模式")
	return_mode_btn.pressed.connect(_on_return_mode_pressed)
	big_map_btn.get_parent().add_child(return_mode_btn)
	if is_instance_valid(_event_test_btn):
		big_map_btn.get_parent().move_child(return_mode_btn, _event_test_btn.get_index() + 1)
	else:
		big_map_btn.get_parent().move_child(return_mode_btn, big_map_btn.get_index() + 1)
	_return_mode_btn = return_mode_btn

	_toolbar_elements = [
		$Label as Control,
		$DiplomacyButton as Control,
		$TechButton as Control,
		$SkirmishButton as Control,
		$BigMapButton as Control,
		return_mode_btn as Control,
	]
	if is_instance_valid(_event_test_btn):
		_toolbar_elements.insert(_toolbar_elements.size() - 1, _event_test_btn)

	_create_turn_info_popup()
	_create_persistent_end_btn()
	_set_end_turn_visible(false)
	var built_in_skirmish_panel: CanvasLayer = $SkirmishPanel as CanvasLayer
	built_in_skirmish_panel.visible = false
	_create_framework_hub()
	_create_framework_placeholder()
	_hide_legacy_toolbar()
	_toolbar_elements = [_framework_hub]
	if DemoFlow.is_enabled():
		_create_demo_ui()
		if not DemoFlow.requires_strategy_preparation():
			call_deferred("_auto_start_skirmish_demo")
	if StartupFlow.selected_mode == StartupFlow.MODE_FULL_DEMO:
		call_deferred("_enter_formal_demo_big_map")
	if not TacticalSkirmishManager.skirmish_ended.is_connected(_on_skirmish_ended):
		TacticalSkirmishManager.skirmish_ended.connect(_on_skirmish_ended)
	StartupFlow.trace("Main._ready end phase=%s demo=%s" % [
		GameManager.Phase.keys()[GameManager.get_current_phase()],
		str(DemoFlow.is_enabled()),
	])


func _exit_tree() -> void:
	StartupFlow.trace("Main._exit_tree begin")
	if TacticalSkirmishManager.skirmish_ended.is_connected(_on_skirmish_ended):
		TacticalSkirmishManager.skirmish_ended.disconnect(_on_skirmish_ended)
	if is_instance_valid(_active_skirmish_panel):
		_active_skirmish_panel.queue_free()
		_active_skirmish_panel = null
	StartupFlow.trace("Main._exit_tree end")


func _close_big_map() -> void:
	if is_instance_valid(_big_map_panel):
		_reclaim_resource_bar()
		_big_map_panel.close()
		_big_map_panel = null


func _close_diplomacy() -> void:
	if is_instance_valid(_diplomacy_panel):
		_diplomacy_panel.queue_free()
		_diplomacy_panel = null


func _close_city_panel() -> void:
	if is_instance_valid(_city_panel):
		_reclaim_resource_bar()
		_city_panel.close()
		_city_panel = null


func _init_game() -> void:
	StartupFlow.trace("Main._init_game begin phase=%s pending=%s auto=%s" % [
		GameManager.Phase.keys()[GameManager.get_current_phase()],
		str(StartupFlow.is_game_start_pending()),
		str(StartupFlow.should_main_auto_start_game()),
	])
	StartupFlow.trace("Main._init_game skip always")


func _embed_resource_bar(target_vbox: VBoxContainer) -> void:
	if _resource_bar.get_parent() != null:
		_resource_bar.get_parent().remove_child(_resource_bar)
	target_vbox.add_child(_resource_bar)
	target_vbox.move_child(_resource_bar, 1)
	_resource_bar.visible = true
	_refresh_resource_bar()


func _reclaim_resource_bar() -> void:
	if _resource_bar.get_parent() != null and _resource_bar.get_parent() != self:
		_resource_bar.get_parent().remove_child(_resource_bar)
		add_child(_resource_bar)
	_resource_bar.visible = false


func _set_toolbar_visible(is_visible: bool) -> void:
	for elem: Control in _toolbar_elements:
		if is_instance_valid(elem):
			elem.visible = is_visible


func _set_end_turn_visible(is_visible: bool) -> void:
	if is_instance_valid(_end_turn_layer):
		_end_turn_layer.visible = is_visible
	if is_instance_valid(_persistent_end_btn):
		_persistent_end_btn.visible = is_visible


func _refresh_resource_bar() -> void:
	if _resource_bar != null and _resource_bar.has_method("refresh"):
		_resource_bar.refresh()


func _framework_demo_mode_name() -> String:
	if not DemoFlow.is_enabled():
		return "普通主菜单"
	if DemoFlow.is_full_demo_enabled():
		return "完整试玩"
	if DemoFlow.is_tutorial_enabled():
		return "新手教程"
	return "战斗演武"


func _should_show_tutorial_guidance_ui() -> bool:
	return DemoFlow.is_tutorial_enabled()


func _auto_start_skirmish_demo() -> void:
	await get_tree().process_frame
	if not DemoFlow.is_enabled() or DemoFlow.requires_strategy_preparation():
		return
	_on_demo_sortie_requested()


func _enter_formal_demo_big_map() -> void:
	if _formal_demo_big_map_opened:
		return
	_formal_demo_big_map_opened = true
	_set_toolbar_visible(false)
	_set_end_turn_visible(true)
	_ensure_big_map()
	_big_map_panel.open()
	var capital: Dictionary = CityManager.get_capital_state(GameManager.get_player_faction())
	var capital_id: String = str(capital.get("id", ""))
	if capital_id != "":
		_last_big_map_city_focus_id = capital_id
		if _big_map_panel.has_method("focus_city"):
			_big_map_panel.focus_city(capital_id)
	_embed_resource_bar(_big_map_panel.get_resource_bar_slot())


func _create_framework_hub() -> void:
	_framework_hub_layer = CanvasLayer.new()
	_framework_hub_layer.layer = 1
	add_child(_framework_hub_layer)

	_framework_hub = Control.new()
	_framework_hub.name = "FrameworkHub"
	_framework_hub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_framework_hub_layer.add_child(_framework_hub)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.055, 0.045, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_framework_hub.add_child(bg)

	var margin := MarginContainer.new()
	margin.name = "HubMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	_framework_hub.add_child(margin)

	_framework_hub_root = Control.new()
	_framework_hub_root.name = "HubViewport"
	_framework_hub_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(_framework_hub_root)

	_framework_hub_scroll = ScrollContainer.new()
	_framework_hub_scroll.name = "HubScroll"
	_framework_hub_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_framework_hub_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_framework_hub_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_framework_hub_root.add_child(_framework_hub_scroll)

	var root := VBoxContainer.new()
	root.name = "HubRoot"
	root.add_theme_constant_override("separation", 18)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(1140, 720)
	_framework_hub_scroll.add_child(root)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var title := Label.new()
	title.name = "Title"
	title.text = "山河策：战略中枢 Demo"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.86, 0.69, 0.34, 1.0))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "公开试玩骨架：主链路可玩，框架页负责说明系统、展示数据并跳转到已接入功能。"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.80, 0.74, 0.62, 1.0))
	title_box.add_child(subtitle)

	var return_btn := SkirmishTileTextures.styled_button("返回模式")
	return_btn.name = "HubReturnModeButton"
	return_btn.custom_minimum_size = Vector2(126, 42)
	return_btn.pressed.connect(_on_return_mode_pressed)
	header.add_child(return_btn)

	var zoom_row := HBoxContainer.new()
	zoom_row.name = "ZoomRow"
	zoom_row.add_theme_constant_override("separation", 8)
	header.add_child(zoom_row)

	var zoom_out_btn := SkirmishTileTextures.styled_button("缩小")
	zoom_out_btn.name = "HubZoomOutButton"
	zoom_out_btn.custom_minimum_size = Vector2(74, 42)
	zoom_out_btn.pressed.connect(_change_framework_zoom.bind(-0.10))
	zoom_row.add_child(zoom_out_btn)

	_framework_zoom_label = Label.new()
	_framework_zoom_label.name = "HubZoomLabel"
	_framework_zoom_label.custom_minimum_size = Vector2(70, 42)
	_framework_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_framework_zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zoom_row.add_child(_framework_zoom_label)

	var zoom_in_btn := SkirmishTileTextures.styled_button("放大")
	zoom_in_btn.name = "HubZoomInButton"
	zoom_in_btn.custom_minimum_size = Vector2(74, 42)
	zoom_in_btn.pressed.connect(_change_framework_zoom.bind(0.10))
	zoom_row.add_child(zoom_in_btn)

	var status := PanelContainer.new()
	status.name = "StatusPanel"
	status.add_theme_stylebox_override("panel", _framework_panel_style(Color(0.11, 0.095, 0.075, 0.94)))
	root.add_child(status)

	var status_grid := GridContainer.new()
	status_grid.name = "StatusGrid"
	status_grid.columns = 4
	status_grid.add_theme_constant_override("h_separation", 24)
	status_grid.add_theme_constant_override("v_separation", 8)
	status.add_child(status_grid)
	_add_framework_status_label(status_grid, "玩家势力", FACTION_NAMES.get(GameManager.get_player_faction(), GameManager.get_player_faction()))
	_add_framework_status_label(status_grid, "当前回合", "第 %d 回合" % GameManager.get_current_turn())
	_add_framework_status_label(status_grid, "当前行动", FACTION_NAMES.get(GameManager.get_current_faction(), GameManager.get_current_faction()))
	_add_framework_status_label(status_grid, "Demo 主线", _framework_demo_mode_name())

	var content := HBoxContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	root.add_child(content)

	var module_panel := PanelContainer.new()
	module_panel.name = "ModulePanel"
	module_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	module_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	module_panel.add_theme_stylebox_override("panel", _framework_panel_style(Color(0.09, 0.08, 0.065, 0.96)))
	content.add_child(module_panel)

	var module_margin := MarginContainer.new()
	module_margin.add_theme_constant_override("margin_left", 18)
	module_margin.add_theme_constant_override("margin_top", 18)
	module_margin.add_theme_constant_override("margin_right", 18)
	module_margin.add_theme_constant_override("margin_bottom", 18)
	module_panel.add_child(module_margin)

	var modules := GridContainer.new()
	modules.name = "ModuleGrid"
	modules.columns = 3
	modules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modules.add_theme_constant_override("h_separation", 12)
	modules.add_theme_constant_override("v_separation", 12)
	module_margin.add_child(modules)

	for module: Dictionary in _framework_modules():
		modules.add_child(_create_framework_module_button(module))

	if _should_show_tutorial_guidance_ui():
		var briefing := PanelContainer.new()
		briefing.name = "BriefingPanel"
		briefing.custom_minimum_size = Vector2(330, 0)
		briefing.add_theme_stylebox_override("panel", _framework_panel_style(Color(0.12, 0.10, 0.075, 0.92)))
		content.add_child(briefing)

		var briefing_box := VBoxContainer.new()
		briefing_box.name = "BriefingBox"
		briefing_box.add_theme_constant_override("separation", 10)
		briefing.add_child(briefing_box)

		var briefing_title := Label.new()
		briefing_title.text = "当前 Demo 目标"
		briefing_title.add_theme_font_size_override("font_size", 20)
		briefing_title.add_theme_color_override("font_color", Color(0.86, 0.69, 0.34, 1.0))
		briefing_box.add_child(briefing_title)

		var briefing_text := RichTextLabel.new()
		briefing_text.name = "BriefingText"
		briefing_text.bbcode_enabled = true
		briefing_text.fit_content = true
		briefing_text.custom_minimum_size = Vector2(300, 280)
		briefing_text.text = _framework_demo_briefing()
		briefing_text.add_theme_color_override("default_color", Color(0.86, 0.82, 0.72, 1.0))
		briefing_box.add_child(briefing_text)


func _hide_legacy_toolbar() -> void:
	for elem: Control in [
		$Label as Control,
		$DiplomacyButton as Control,
		$TechButton as Control,
		$SkirmishButton as Control,
		$BigMapButton as Control,
		_event_test_btn as Control,
		_return_mode_btn as Control,
	]:
		if is_instance_valid(elem):
			elem.visible = false


func _create_framework_placeholder() -> void:
	_framework_placeholder_layer = CanvasLayer.new()
	_framework_placeholder_layer.layer = 80
	_framework_placeholder_layer.visible = false
	add_child(_framework_placeholder_layer)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_framework_placeholder_layer.add_child(dim)

	_framework_placeholder_panel = PanelContainer.new()
	_framework_placeholder_panel.name = "FrameworkPlaceholderPanel"
	_framework_placeholder_panel.custom_minimum_size = Vector2(560, 360)
	_framework_placeholder_panel.set_anchors_preset(Control.PRESET_CENTER)
	_framework_placeholder_panel.offset_left = -280
	_framework_placeholder_panel.offset_right = 280
	_framework_placeholder_panel.offset_top = -180
	_framework_placeholder_panel.offset_bottom = 180
	_framework_placeholder_panel.add_theme_stylebox_override("panel", _framework_panel_style(Color(0.10, 0.085, 0.065, 0.98)))
	_framework_placeholder_layer.add_child(_framework_placeholder_panel)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 12)
	_framework_placeholder_panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)

	_framework_placeholder_title = Label.new()
	_framework_placeholder_title.name = "Title"
	_framework_placeholder_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_framework_placeholder_title.add_theme_font_size_override("font_size", 24)
	_framework_placeholder_title.add_theme_color_override("font_color", Color(0.86, 0.69, 0.34, 1.0))
	header.add_child(_framework_placeholder_title)

	var close_btn := SkirmishTileTextures.styled_button("关闭")
	close_btn.name = "CloseButton"
	close_btn.custom_minimum_size = Vector2(86, 36)
	close_btn.pressed.connect(_hide_framework_placeholder)
	header.add_child(close_btn)

	_framework_placeholder_scroll = ScrollContainer.new()
	_framework_placeholder_scroll.name = "BodyScroll"
	_framework_placeholder_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_framework_placeholder_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_framework_placeholder_scroll.custom_minimum_size = Vector2(520, 250)
	_framework_placeholder_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_framework_placeholder_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(_framework_placeholder_scroll)

	_framework_placeholder_body = RichTextLabel.new()
	_framework_placeholder_body.name = "Body"
	_framework_placeholder_body.bbcode_enabled = true
	_framework_placeholder_body.fit_content = false
	_framework_placeholder_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_framework_placeholder_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_framework_placeholder_body.custom_minimum_size = Vector2(520, 250)
	_framework_placeholder_body.scroll_active = true
	_framework_placeholder_body.add_theme_color_override("default_color", Color(0.86, 0.82, 0.72, 1.0))
	_framework_placeholder_scroll.add_child(_framework_placeholder_body)

	_framework_placeholder_actions = HBoxContainer.new()
	_framework_placeholder_actions.name = "Actions"
	_framework_placeholder_actions.add_theme_constant_override("separation", 10)
	box.add_child(_framework_placeholder_actions)
	_refresh_framework_zoom_label()


func _framework_modules() -> Array[Dictionary]:
	return [
		{"id": "big_map", "title": "大地图", "status": "已接入", "summary": "查看战国版图、城池与势力控制。"},
		{"id": "city", "title": "城市内政", "status": "已接入", "summary": "打开玩家首都，测试建筑、人口、征兵与产出。"},
		{"id": "military", "title": "军事 / 战役", "status": "已接入", "summary": "Demo 模式进入洛邑攻城；普通模式进入演武场景选择。"},
		{"id": "diplomacy", "title": "外交", "status": "已接入", "summary": "查看势力关系、谈判与外交操作。"},
		{"id": "tech", "title": "科技", "status": "已接入", "summary": "研究科技树，查看前置与效果。"},
		{"id": "events", "title": "事件", "status": "只读总览", "summary": "查看最近事件、冷却状态与事件链推进。"},
		{"id": "schools", "title": "学派 / 文化", "status": "只读总览", "summary": "查看当前学派、代表政策与相关事件入口。"},
		{"id": "ministers", "title": "官员 / 大夫", "status": "只读总览", "summary": "查看官员池、势力关注方向与关联模块入口。"},
		{"id": "intelligence", "title": "情报", "status": "只读总览", "summary": "查看势力态势、外交关系与风险目标。"},
		{"id": "resources", "title": "资源状态", "status": "简化可用", "summary": "汇总当前资源、人口、兵力与士气。"},
		{"id": "save", "title": "存档 / 读档", "status": "简化可用", "summary": "单槽快速保存框架快照，读取时显示摘要。"},
		{"id": "settings", "title": "设置", "status": "简化可用", "summary": "音量、窗口模式与测试作弊开关。"},
	]


func _create_framework_module_button(module: Dictionary) -> Button:
	var title: String = str(module.get("title", "模块"))
	var status: String = str(module.get("status", "未知"))
	var summary: String = str(module.get("summary", ""))
	var module_id: String = str(module.get("id", ""))
	var btn := SkirmishTileTextures.styled_button("%s\n[%s]\n%s" % [title, status, summary])
	btn.name = "HubModule_%s" % module_id
	btn.custom_minimum_size = Vector2(220, 116)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(_on_framework_module_pressed.bind(module_id))
	return btn


func _add_framework_status_label(parent: Control, label_text: String, value_text: String) -> void:
	var label := Label.new()
	label.text = "%s：" % label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.62, 0.55, 0.42, 1.0))
	parent.add_child(label)

	var value := Label.new()
	value.text = value_text if value_text != "" else "未初始化"
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", Color(0.88, 0.82, 0.66, 1.0))
	parent.add_child(value)


func _framework_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.42, 0.33, 0.18, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style


func _on_framework_module_pressed(module_id: String) -> void:
	match module_id:
		"big_map":
			_on_big_map_button_pressed()
		"city":
			_open_player_capital_panel()
		"military":
			if DemoFlow.is_enabled():
				_on_demo_sortie_requested()
			else:
				_on_skirmish_button_pressed()
		"diplomacy":
			_on_diplomacy_button_pressed()
		"tech":
			_on_tech_button_pressed()
		"events":
			_show_framework_placeholder("事件总览", _framework_events_summary())
		"schools":
			_show_schools_panel()
		"ministers":
			_show_ministers_panel()
		"intelligence":
			_show_intelligence_panel()
		"resources":
			_show_framework_placeholder("资源状态", _framework_resource_summary())
		"save":
			_show_save_load_panel()
		"settings":
			_show_settings_panel()
		_:
			_show_framework_placeholder(_framework_module_title(module_id), _framework_placeholder_text(module_id))


func _open_player_capital_panel() -> void:
	var faction_id: String = GameManager.get_player_faction()
	if faction_id == "":
		faction_id = DemoFlow.get_player_faction_id()
	var capital: Dictionary = CityManager.get_capital_state(faction_id)
	if capital.is_empty():
		_show_framework_placeholder("城市内政", "[b]暂无法打开城市[/b]\n当前没有找到玩家首都。请先从启动流程进入一局游戏。")
		return
	if DemoFlow.is_enabled():
		DemoFlow.mark_step_completed(DemoFlow.STEP_MANAGE_CAPITAL)
		DemoFlow.mark_strategy_prepared_if_ready()
	_on_city_clicked(str(capital.get("id", "")))


func _show_framework_placeholder(title: String, body: String) -> void:
	if not is_instance_valid(_framework_placeholder_layer):
		return
	_framework_placeholder_title.text = title
	_framework_placeholder_body.text = body
	_clear_framework_placeholder_actions()
	if is_instance_valid(_framework_placeholder_scroll):
		_framework_placeholder_scroll.scroll_vertical = 0
	if is_instance_valid(_framework_placeholder_body):
		_framework_placeholder_body.scroll_to_line(0)
	_framework_placeholder_layer.visible = true


func _hide_framework_placeholder() -> void:
	if is_instance_valid(_framework_placeholder_layer):
		_framework_placeholder_layer.visible = false


func _change_framework_zoom(delta: float) -> void:
	_framework_zoom_scale = clampf(_framework_zoom_scale + delta, 0.80, 1.25)
	if is_instance_valid(_framework_hub_scroll):
		var content: Control = _framework_hub_scroll.get_child(0) as Control
		if is_instance_valid(content):
			content.scale = Vector2(_framework_zoom_scale, _framework_zoom_scale)
	_refresh_framework_zoom_label()


func _refresh_framework_zoom_label() -> void:
	if is_instance_valid(_framework_zoom_label):
		_framework_zoom_label.text = "%d%%" % int(round(_framework_zoom_scale * 100.0))


func _framework_demo_briefing() -> String:
	if not DemoFlow.is_enabled():
		return "[b]可玩闭环[/b]\n大地图 → 城市 → 军事/战役 → 战斗 → 胜利反馈。\n\n[b]试玩骨架[/b]\n主链路已经可走通；框架页负责解释系统、展示当前数据，并把玩家导向已接入功能。\n\n[b]推荐试玩顺序[/b]\n先看资源与情报，再进城市和外交，最后从军事 / 战役进入演武。"

	var snapshot: Dictionary = DemoFlow.get_strategy_snapshot()
	var city_counts: Dictionary = snapshot.get("faction_city_counts", {}) as Dictionary
	var faction_lines: Array[String] = []
	for faction_id: String in GameManager.FACTION_IDS:
		faction_lines.append("%s %d" % [_faction_display_name(faction_id), int(city_counts.get(faction_id, 0))])
	var independent_count: int = int(snapshot.get("independent_city_count", 0))
	var neutral_count: int = int(snapshot.get("neutral_city_count", 0))
	var target_owner: String = _faction_display_name(str(snapshot.get("target_owner", "")))
	return "[b]完整 Demo 闭环[/b]\n经营秦国 → 查看七国版图 → 打开咸阳经营 → 出征洛邑 → 战斗胜利 → 回到洛邑城池面板查看结果。\n\n[b]战略层规模[/b]\n七国同场：%s\n周室/中立城市：%d / %d\n总城数：%d\n洛邑当前归属：%s\n\n[b]操作顺序[/b]\n先打开大地图，再打开城市内政，最后从军事 / 战役进入洛邑战役。" % [
		"、".join(faction_lines),
		independent_count,
		neutral_count,
		int(snapshot.get("total_cities", 0)),
		target_owner,
	]


func _clear_framework_placeholder_actions() -> void:
	if not is_instance_valid(_framework_placeholder_actions):
		return
	for child: Node in _framework_placeholder_actions.get_children():
		child.queue_free()


func _add_framework_placeholder_action(button_name: String, text: String, callback: Callable) -> Button:
	var btn := SkirmishTileTextures.styled_button(text)
	btn.name = button_name
	btn.custom_minimum_size = Vector2(128, 38)
	btn.pressed.connect(callback)
	_framework_placeholder_actions.add_child(btn)
	return btn


func _show_save_load_panel() -> void:
	if not is_instance_valid(_framework_placeholder_layer):
		return
	_framework_placeholder_title.text = "存档 / 读档"
	_framework_placeholder_body.text = _framework_save_load_summary()
	_clear_framework_placeholder_actions()
	_add_framework_placeholder_action("QuickSaveButton", "快速存档", _save_framework_quick_save)
	_add_framework_placeholder_action("QuickLoadButton", "快速读档", _load_framework_quick_save)
	_framework_placeholder_layer.visible = true


func _show_settings_panel() -> void:
	if not is_instance_valid(_framework_placeholder_layer):
		return
	_framework_placeholder_title.text = "设置"
	_framework_placeholder_body.text = _framework_settings_summary()
	_clear_framework_placeholder_actions()
	_add_framework_placeholder_action("ToggleMuteButton", "切换静音", _toggle_framework_mute)
	_add_framework_placeholder_action("ToggleFullscreenButton", "切换全屏", _toggle_framework_fullscreen)
	_add_framework_placeholder_action("ToggleDemoCheatButton", "切换作弊", _toggle_framework_demo_cheat)
	_framework_placeholder_layer.visible = true


func _show_intelligence_panel() -> void:
	if not is_instance_valid(_framework_placeholder_layer):
		return
	_framework_placeholder_title.text = "情报总览"
	_framework_placeholder_body.text = _framework_intelligence_summary()
	_clear_framework_placeholder_actions()
	_add_framework_placeholder_action("OpenIntelMapButton", "查看大地图", _open_intelligence_big_map)
	_add_framework_placeholder_action("OpenIntelDiplomacyButton", "查看外交", _open_intelligence_diplomacy)
	_framework_placeholder_layer.visible = true


func _show_schools_panel() -> void:
	if not is_instance_valid(_framework_placeholder_layer):
		return
	_framework_placeholder_title.text = "学派 / 文化总览"
	_framework_placeholder_body.text = _framework_schools_summary()
	_clear_framework_placeholder_actions()
	_add_framework_placeholder_action("OpenSchoolSelectButton", "切换学派", _open_school_switch_panel)
	_add_framework_placeholder_action("OpenSchoolEventsButton", "相关事件", _open_school_events_panel)
	_add_framework_placeholder_action("OpenSchoolTechButton", "查看科技", _open_school_tech_panel)
	_framework_placeholder_layer.visible = true


func _show_ministers_panel() -> void:
	if not is_instance_valid(_framework_placeholder_layer):
		return
	_framework_placeholder_title.text = "官员 / 大夫总览"
	_framework_placeholder_body.text = _framework_ministers_summary()
	_clear_framework_placeholder_actions()
	_add_framework_placeholder_action("OpenMinisterAssignButton", "派驻首都", _open_minister_assign_panel)
	_add_framework_placeholder_action("OpenMinisterCityButton", "查看城市", _open_minister_city_panel)
	_add_framework_placeholder_action("OpenMinisterDiplomacyButton", "查看外交", _open_minister_diplomacy_panel)
	_framework_placeholder_layer.visible = true


func _open_school_switch_panel() -> void:
	if not is_instance_valid(_framework_placeholder_layer):
		return
	_framework_placeholder_title.text = "学派切换"
	_framework_placeholder_body.text = _framework_school_switch_summary()
	_clear_framework_placeholder_actions()
	var player_faction_id: String = GameManager.get_player_faction()
	if player_faction_id == "":
		player_faction_id = DemoFlow.get_player_faction_id()
	for raw_school: Variant in DataManager.get_all_schools():
		var school: Dictionary = raw_school as Dictionary
		var school_id: String = str(school.get("id", ""))
		var school_name: String = str(school.get("name", school_id))
		_add_framework_placeholder_action("SchoolSwitch_%s" % school_id, school_name, _on_school_switch_requested.bind(school_id))
	_add_framework_placeholder_action("SchoolBackButton", "返回总览", _show_schools_panel)
	_framework_placeholder_layer.visible = true


func _open_minister_assign_panel() -> void:
	if not is_instance_valid(_framework_placeholder_layer):
		return
	_framework_placeholder_title.text = "大夫派驻"
	_framework_placeholder_body.text = _framework_minister_assign_summary()
	_clear_framework_placeholder_actions()
	_add_framework_placeholder_action("MinisterAssignCapitalButton", "派驻首都大夫", _assign_minister_to_capital)
	_add_framework_placeholder_action("MinisterBackButton", "返回总览", _show_ministers_panel)
	_framework_placeholder_layer.visible = true


func _open_school_events_panel() -> void:
	_show_framework_placeholder("事件总览", _framework_events_summary())


func _open_school_tech_panel() -> void:
	_hide_framework_placeholder()
	_on_tech_button_pressed()


func _open_minister_city_panel() -> void:
	_hide_framework_placeholder()
	_open_player_capital_panel()


func _open_minister_diplomacy_panel() -> void:
	_hide_framework_placeholder()
	_on_diplomacy_button_pressed()


func _open_intelligence_big_map() -> void:
	_hide_framework_placeholder()
	_on_big_map_button_pressed()


func _open_intelligence_diplomacy() -> void:
	_hide_framework_placeholder()
	_on_diplomacy_button_pressed()


func _framework_settings_summary() -> String:
	var master_bus: int = AudioServer.get_bus_index("Master")
	var muted: bool = AudioServer.is_bus_mute(master_bus) if master_bus >= 0 else false
	var window_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var window_text: String = "全屏" if window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN else "窗口"
	var cheat_multiplier: float = TacticalSkirmishManager.get_demo_attack_multiplier()
	var cheat_text: String = "开启（伤害 ×%d）" % int(cheat_multiplier) if cheat_multiplier > 1.0 else "关闭"
	return "[b]音频[/b]\n主音频：%s\n\n[b]显示[/b]\n窗口模式：%s\n\n[b]测试开关[/b]\nDemo 作弊：%s\n\n[b]说明[/b]\n当前设置面板先接入最小可用项；语言、分辨率、按键绑定和多档配置会在正式设置系统中扩展。" % [
		"静音" if muted else "正常",
		window_text,
		cheat_text,
	]


func _refresh_settings_panel() -> void:
	if is_instance_valid(_framework_placeholder_body):
		_framework_placeholder_body.text = _framework_settings_summary()


func _toggle_framework_mute() -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus < 0:
		_framework_placeholder_body.text = "[b]设置失败[/b]\n未找到 Master 音频总线。"
		return
	AudioServer.set_bus_mute(master_bus, not AudioServer.is_bus_mute(master_bus))
	_refresh_settings_panel()


func _toggle_framework_fullscreen() -> void:
	var current_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh_settings_panel()


func _toggle_framework_demo_cheat() -> void:
	if TacticalSkirmishManager.get_demo_attack_multiplier() > 1.0:
		TacticalSkirmishManager.set_demo_attack_multiplier(1.0)
	else:
		TacticalSkirmishManager.set_demo_attack_multiplier(DEMO_CHEAT_ATTACK_MULTIPLIER)
	if is_instance_valid(_demo_objective_panel) and _demo_objective_panel.has_method("update_panel"):
		_demo_objective_panel.update_panel()
	_refresh_settings_panel()


func _framework_save_load_summary() -> String:
	var status: String = "尚未发现快速存档。"
	if FileAccess.file_exists(FRAMEWORK_QUICK_SAVE_PATH):
		var save_data: Dictionary = _read_framework_quick_save()
		if save_data.is_empty():
			status = "检测到存档文件，但内容暂无法解析。"
		else:
			status = "最近存档：%s\n玩家势力：%s\n当前回合：第 %d 回合\n目标城归属：%s" % [
				str(save_data.get("saved_at_unix", "未知")),
				_faction_display_name(str(save_data.get("player_faction", ""))),
				int(save_data.get("turn", 0)),
				_faction_display_name(str(save_data.get("target_city_owner", ""))),
			]
	return "[b]快速存档槽[/b]\n%s\n\n[b]当前范围[/b]\n保存框架快照、玩家势力、当前回合、资源摘要、Demo 状态、目标城归属与事件状态。\n\n[b]读档说明[/b]\n本阶段读取后会恢复事件系统状态并展示存档摘要；完整城市、资源与战局回滚会在正式存档系统中接入。" % status


func _save_framework_quick_save() -> void:
	var save_data: Dictionary = _build_framework_quick_save_data()
	var file: FileAccess = FileAccess.open(FRAMEWORK_QUICK_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_framework_placeholder_body.text = "[b]保存失败[/b]\n无法写入快速存档文件：%s" % FRAMEWORK_QUICK_SAVE_PATH
		return
	file.store_string(JSON.stringify(save_data, "\t"))
	_framework_placeholder_body.text = "[b]保存成功[/b]\n已写入快速存档。\n\n%s" % _framework_save_load_summary()


func _load_framework_quick_save() -> void:
	var save_data: Dictionary = _read_framework_quick_save()
	if save_data.is_empty():
		_framework_placeholder_body.text = "[b]读取失败[/b]\n没有可用的快速存档，或存档内容无法解析。"
		return
	var event_state: Dictionary = save_data.get("event_state", {}) as Dictionary
	if not event_state.is_empty():
		EventManager.load_save_data(event_state)
	var school_state: Dictionary = save_data.get("school_state", {}) as Dictionary
	if not school_state.is_empty():
		SchoolManager.load_save_data(school_state)
	var diplomacy_state: Dictionary = save_data.get("diplomacy_state", {}) as Dictionary
	if not diplomacy_state.is_empty():
		DiplomacySystem.load_save_data(diplomacy_state)
	var wonder_state: Dictionary = save_data.get("wonder_state", {}) as Dictionary
	if not wonder_state.is_empty():
		WonderManager.load_save_data(wonder_state)
	_framework_placeholder_body.text = "[b]读取成功[/b]\n已读取框架快照，并恢复事件系统状态。\n\n玩家势力：%s\n当前回合：第 %d 回合\n目标城归属：%s\n资源摘要：%s" % [
		_faction_display_name(str(save_data.get("player_faction", ""))),
		int(save_data.get("turn", 0)),
		_faction_display_name(str(save_data.get("target_city_owner", ""))),
		_framework_resource_line(save_data.get("resources", {}) as Dictionary),
	]


func _build_framework_quick_save_data() -> Dictionary:
	var player_faction: String = GameManager.get_player_faction()
	if player_faction == "":
		player_faction = DemoFlow.get_player_faction_id()
	var target_city: Dictionary = CityManager.get_city_state(DemoFlow.get_target_city_id())
	return {
		"schema_version": 1,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"turn": GameManager.get_current_turn(),
		"player_faction": player_faction,
		"current_faction": GameManager.get_current_faction(),
		"resources": GameManager.get_faction_resources(player_faction).duplicate(true),
		"demo_enabled": DemoFlow.is_enabled(),
		"demo_complete": DemoFlow.is_demo_complete(),
		"demo_completed_steps": DemoFlow.get_completed_steps(),
		"target_city_id": DemoFlow.get_target_city_id(),
		"target_city_owner": str(target_city.get("current_faction_id", "")),
		"city_count": CityManager.get_all_city_states().size(),
		"school_state": SchoolManager.get_save_data(),
		"diplomacy_state": DiplomacySystem.get_save_data(),
		"wonder_state": WonderManager.get_save_data(),
		"event_state": EventManager.get_save_data(),
	}


func _read_framework_quick_save() -> Dictionary:
	if not FileAccess.file_exists(FRAMEWORK_QUICK_SAVE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(FRAMEWORK_QUICK_SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _framework_module_title(module_id: String) -> String:
	for module: Dictionary in _framework_modules():
		if str(module.get("id", "")) == module_id:
			return str(module.get("title", module_id))
	return module_id


func _faction_display_name(faction_id: String) -> String:
	if faction_id == "":
		return "未初始化"
	return str(FACTION_NAMES.get(faction_id, faction_id))


func _framework_resource_line(resources: Dictionary) -> String:
	if resources.is_empty():
		return "暂无资源数据"
	return "粮 %d / 金 %d / 木 %d / 兵 %d / 人口 %d / 士气 %d" % [
		int(resources.get("food", 0)),
		int(resources.get("gold", 0)),
		int(resources.get("wood", 0)),
		int(resources.get("troops", 0)),
		int(resources.get("population", 0)),
		int(resources.get("morale", 0)),
	]


func _framework_placeholder_text(module_id: String) -> String:
	match module_id:
		"events":
			return "[b]定位[/b]\n承接随机事件、季节事件、科技事件与链式事件。\n\n[b]当前状态[/b]\n事件系统后端与事件弹窗已存在，但还缺正式版事件日志、事件池可视化和玩家主动查看入口。\n\n[b]下一步[/b]\n把事件历史、当前待处理事件、事件来源与影响汇总到这里。"
		"schools":
			return "[b]定位[/b]\n诸子百家、文化扩散、学派政策与文化覆盖效果入口。\n\n[b]当前状态[/b]\n数据表已存在，部分文化/学派机制仍分散在后端与文档。\n\n[b]下一步[/b]\n先做只读学派总览，再接入政策选择与城市文化状态。"
		"ministers":
			return "[b]定位[/b]\n官员招募、任命、能力、派驻与国家加成入口。\n\n[b]当前状态[/b]\n官员数据已存在，正式管理面板未接入。\n\n[b]下一步[/b]\n做官员列表、详情卡与城市派驻槽位。"
		"intelligence":
			return "[b]定位[/b]\n侦察、情报力、敌方兵力估计、战争预警入口。\n\n[b]当前状态[/b]\n相关机制仍在规划和局部实现阶段。\n\n[b]下一步[/b]\n先做势力情报总览，再接入侦察行动。"
		"save":
			return "[b]定位[/b]\n保存、读取、自动存档与试玩包存档管理。\n\n[b]当前状态[/b]\n正式存档 UI 尚未接入。\n\n[b]下一步[/b]\n先实现单槽快速存档/读档，再扩展多槽位。"
		"settings":
			return "[b]定位[/b]\n音量、显示、语言、辅助测试开关与版本信息。\n\n[b]当前状态[/b]\n正式设置面板尚未接入。\n\n[b]下一步[/b]\n先接音量与窗口设置，再整理测试开关。"
		_:
			return "[b]模块入口已预留[/b]\n该系统还没有接入正式面板。"


func _framework_resource_summary() -> String:
	var faction_id: String = GameManager.get_player_faction()
	var city_count: int = CityManager.get_faction_city_states(faction_id).size() if faction_id != "" else 0
	return "[b]国家资源[/b]\n粮：%d\n金：%d\n木：%d\n马：%d\n精铁：%d\n匠人：%d\n建材：%d\n\n[b]人口与军事[/b]\n人口：%d\n兵力：%d\n士气：%d\n持城：%d" % [
		GameManager.get_player_food(),
		GameManager.get_player_gold(),
		GameManager.get_player_wood(),
		GameManager.get_player_horse(),
		GameManager.get_player_refined_iron(),
		GameManager.get_player_craftsmen(),
		GameManager.get_player_building_materials(),
		GameManager.get_player_population(),
		GameManager.get_player_troops(),
		GameManager.get_player_morale(),
		city_count,
	]


func _framework_events_summary() -> String:
	var events: Array = DataManager.get_all_events()
	var chains: Array = DataManager.get_event_chains()
	var cooldowns: Dictionary = EventManager.get_cooldowns()
	var recent_events: Array[Dictionary] = EventManager.get_recent_events()
	var chain_progress: Array[Dictionary] = EventManager.get_chain_progress_snapshot()
	var category_counts: Dictionary = {}
	var option_count: int = 0
	var one_shot_count: int = 0
	for raw_event: Variant in events:
		var event: Dictionary = raw_event as Dictionary
		var category: String = str(event.get("category", "uncategorized"))
		category_counts[category] = int(category_counts.get(category, 0)) + 1
		var options: Variant = event.get("options")
		if options is Array and not (options as Array).is_empty():
			option_count += 1
		var trigger: Dictionary = event.get("trigger", {}) as Dictionary
		if bool(trigger.get("one_shot", false)):
			one_shot_count += 1

	var category_lines: Array[String] = []
	var categories: Array = category_counts.keys()
	categories.sort()
	for category_v: Variant in categories:
		var category_id: String = str(category_v)
		category_lines.append("- %s：%d" % [_event_category_name(category_id), int(category_counts[category_id])])

	var sample_lines: Array[String] = []
	var sample_max: int = mini(5, events.size())
	for i: int in range(sample_max):
		var sample_event: Dictionary = events[i] as Dictionary
		sample_lines.append("- %s：%s" % [
			str(sample_event.get("title", "未命名事件")),
			str(sample_event.get("description", "")).substr(0, 34),
		])

	var runtime_lines: Array[String] = []
	for record: Dictionary in recent_events:
		var status: String = "已触发"
		if str(record.get("status", "")) == "resolved":
			status = "已结算"
		var choice_suffix: String = ""
		var choice_id: String = str(record.get("choice_id", ""))
		if choice_id != "":
			choice_suffix = " / 选项 %s" % choice_id
		runtime_lines.append("- %s：%s%s" % [
			status,
			str(record.get("title", "未命名事件")),
			choice_suffix,
		])

	var cooldown_lines: Array[String] = []
	var cooldown_ids: Array = cooldowns.keys()
	cooldown_ids.sort()
	for event_id_v: Variant in cooldown_ids:
		var event_id: String = str(event_id_v)
		var event_data: Dictionary = DataManager.get_event(event_id)
		cooldown_lines.append("- %s：剩余 %d 回合" % [
			str(event_data.get("title", event_id)),
			int(cooldowns[event_id]),
		])

	var chain_lines: Array[String] = []
	for progress: Dictionary in chain_progress:
		chain_lines.append("- %s：%d/%d，下一步 %s" % [
			str(progress.get("name", progress.get("chain_id", "未命名事件链"))),
			int(progress.get("current_index", 0)),
			int(progress.get("total_nodes", 0)),
			str(progress.get("next_title", "未知")),
		])

	return "[b]试玩说明[/b]\n这一页用于确认当前事件系统是否在正常工作：你可以看到最近触发了什么、哪些事件还在冷却、事件链推进到了哪里。\n\n[b]系统定位[/b]\n随机事件、季节事件、事件链与玩家选择的统一入口。\n\n[b]当前数据[/b]\n事件总数：%d\n事件链：%d\n带选项事件：%d\n一次性事件：%d\n\n[b]运行态事件[/b]\n%s\n\n[b]冷却中的事件[/b]\n%s\n\n[b]事件链进度[/b]\n%s\n\n[b]分类分布[/b]\n%s\n\n[b]样例事件[/b]\n%s\n\n[b]建议动作[/b]\n先确认这里有运行态内容，再回到大地图、外交或演武中继续推进试玩。" % [
		events.size(),
		chains.size(),
		option_count,
		one_shot_count,
		"\n".join(runtime_lines) if not runtime_lines.is_empty() else "暂无近期事件",
		"\n".join(cooldown_lines) if not cooldown_lines.is_empty() else "暂无冷却中的事件",
		"\n".join(chain_lines) if not chain_lines.is_empty() else "暂无事件链进度",
		"\n".join(category_lines) if not category_lines.is_empty() else "暂无分类",
		"\n".join(sample_lines) if not sample_lines.is_empty() else "暂无事件",
	]


func _framework_schools_summary() -> String:
	var schools: Array = DataManager.get_all_schools()
	var total_policies: int = 0
	var total_quests: int = 0
	var total_school_events: int = 0
	var school_lines: Array[String] = []
	var player_faction_id: String = GameManager.get_player_faction()
	if player_faction_id == "":
		player_faction_id = DemoFlow.get_player_faction_id()
	var current_school_id: String = SchoolManager.get_current_school(player_faction_id)
	var current_school: Dictionary = DataManager.get_school(current_school_id)
	for raw_school: Variant in schools:
		var school: Dictionary = raw_school as Dictionary
		var policies: Array = school.get("exclusive_policies", []) as Array
		var quests: Array = school.get("quest_pool", []) as Array
		var event_ids: Array = school.get("event_ids", []) as Array
		total_policies += policies.size()
		total_quests += quests.size()
		total_school_events += event_ids.size()
		school_lines.append("- %s：%s（政策 %d / 任务 %d）" % [
			str(school.get("name", "未知学派")),
			str(school.get("core_idea", "未定义")),
			policies.size(),
			quests.size(),
		])

	var current_school_text: String = "当前势力尚未配置运行时学派。"
	if not current_school.is_empty():
		var school_state: Dictionary = SchoolManager.get_school_state(player_faction_id)
		var active_policies: Array = SchoolManager.get_active_policies(player_faction_id)
		var level_one: Dictionary = current_school.get("level_effects", {}).get("1", {}) as Dictionary
		var leader_skill: Dictionary = current_school.get("leader_skill", {}) as Dictionary
		var policies_preview: Array[String] = []
		for policy_v: Variant in (current_school.get("exclusive_policies", []) as Array).slice(0, 2):
			var policy: Dictionary = policy_v as Dictionary
			policies_preview.append("- %s：%s" % [
				str(policy.get("name", "未命名政策")),
				str((policy.get("effects", {}) as Dictionary).get("description", "暂无描述")),
			])
		var events_preview: Array[String] = []
		for event_id_v: Variant in (current_school.get("event_ids", []) as Array).slice(0, 2):
			var event_data: Dictionary = DataManager.get_event(str(event_id_v))
			events_preview.append("- %s" % str(event_data.get("title", event_id_v)))
		var runtime_policy_lines: Array[String] = []
		for policy_state_v: Variant in active_policies:
			var policy_state: Dictionary = policy_state_v as Dictionary
			var policy: Dictionary = SchoolManager.get_policy_definition(player_faction_id, str(policy_state.get("policy_id", "")))
			runtime_policy_lines.append("- %s（剩余 %d 回合）" % [
				str(policy.get("name", policy_state.get("policy_id", "未命名政策"))),
				int(policy_state.get("turns_remaining", 0)),
			])
		current_school_text = "%s（%s）\n核心理念：%s\n描述：%s\n当前等级：%d\n当前经验：%d\n初阶称号：%s\n领袖技能：%s\n运行时政策：\n%s\n代表政策：\n%s\n关联事件：\n%s" % [
			str(current_school.get("name", current_school_id)),
			_faction_display_name(player_faction_id),
			str(current_school.get("core_idea", "未定义")),
			str(current_school.get("description", "暂无描述")),
			int(school_state.get("level", 0)),
			int(school_state.get("exp", 0)),
			str(level_one.get("name", "未定义")),
			str(leader_skill.get("name", "未定义")),
			"\n".join(runtime_policy_lines) if not runtime_policy_lines.is_empty() else "- 暂无激活政策",
			"\n".join(policies_preview) if not policies_preview.is_empty() else "- 暂无专属政策",
			"\n".join(events_preview) if not events_preview.is_empty() else "- 暂无学派事件",
		]

	return "[b]试玩说明[/b]\n这一页用于告诉玩家当前势力偏向哪条思想线，以及这条线未来会和事件、科技、城市发展怎么衔接。\n\n[b]系统定位[/b]\n诸子百家、文化扩散、学派政策、学派任务与学派事件的统一入口。\n\n[b]当前运行时学派[/b]\n%s\n\n[b]当前数据[/b]\n学派数量：%d\n专属政策：%d\n学派任务：%d\n关联事件：%d\n\n[b]学派列表[/b]\n%s\n\n[b]建议动作[/b]\n可先查看相关事件，再结合科技与内政系统逐步接入正式学派玩法。" % [
		current_school_text,
		schools.size(),
		total_policies,
		total_quests,
		total_school_events,
		"\n".join(school_lines) if not school_lines.is_empty() else "暂无学派",
	]


func _framework_school_switch_summary() -> String:
	var player_faction_id: String = GameManager.get_player_faction()
	if player_faction_id == "":
		player_faction_id = DemoFlow.get_player_faction_id()
	var current_school_id: String = SchoolManager.get_current_school(player_faction_id)
	var current_school_name: String = _minister_school_name(current_school_id)
	var lines: Array[String] = []
	for raw_school: Variant in DataManager.get_all_schools():
		var school: Dictionary = raw_school as Dictionary
		var school_id: String = str(school.get("id", ""))
		var school_name: String = str(school.get("name", school_id))
		var exclusive_policies: Array = school.get("exclusive_policies", []) as Array
		var policy_names: Array[String] = []
		for item: Variant in exclusive_policies:
			policy_names.append(str((item as Dictionary).get("name", "未命名政策")))
		lines.append("- %s%s：%s\n  代表政策：%s" % [
			school_name,
			"（当前）" if school_id == current_school_id else "",
			str(school.get("core_idea", "未定义")),
			"、".join(policy_names) if not policy_names.is_empty() else "暂无",
		])
	return "[b]学派切换[/b]\n当前学派：%s\n\n[b]可选学派[/b]\n%s\n\n[b]说明[/b]\n切换后会进入过渡期，并清空已激活政策。当前面板只做运行时切换，不直接调平衡数值。" % [
		current_school_name if current_school_name != "" else "未配置",
		"\n".join(lines) if not lines.is_empty() else "暂无学派",
	]


func _on_school_switch_requested(school_id: String) -> void:
	var player_faction_id: String = GameManager.get_player_faction()
	if player_faction_id == "":
		player_faction_id = DemoFlow.get_player_faction_id()
	if SchoolManager.set_current_school(player_faction_id, school_id):
		_show_schools_panel()
	else:
		_show_framework_placeholder("学派切换", "[b]切换失败[/b]\n当前势力无法切换到该学派。")


func _framework_minister_assign_summary() -> String:
	var player_faction_id: String = GameManager.get_player_faction()
	if player_faction_id == "":
		player_faction_id = DemoFlow.get_player_faction_id()
	var capital: Dictionary = CityManager.get_capital_state(player_faction_id)
	if capital.is_empty():
		return "[b]大夫派驻[/b]\n当前没有找到玩家首都。"
	var capital_id: String = str(capital.get("id", ""))
	var assigned: Dictionary = MinisterManager.get_city_civil_minister(capital_id)
	var lines: Array[String] = []
	for minister_v: Variant in MinisterManager.get_faction_civil_ministers(player_faction_id):
		var minister: Dictionary = minister_v as Dictionary
		lines.append("- %s（%s / %s）" % [
			str(minister.get("name", minister.get("id", "未命名"))),
			str(minister.get("school", "无学派")),
			str(minister.get("status", "idle")),
		])
	var active_name: String = "当前首都尚未派驻文大夫"
	if not assigned.is_empty():
		active_name = "首都当前派驻：%s" % str(assigned.get("name", assigned.get("id", "未命名")))
	return "[b]大夫派驻[/b]\n首都：%s\n%s\n\n[b]可用文大夫[/b]\n%s\n\n[b]说明[/b]\n这里先做首都派驻入口，后续可扩展到各城与官职任命。" % [
		str(capital.get("name", capital_id)),
		active_name,
		"\n".join(lines) if not lines.is_empty() else "暂无可用文大夫",
	]


func _assign_minister_to_capital() -> void:
	var player_faction_id: String = GameManager.get_player_faction()
	if player_faction_id == "":
		player_faction_id = DemoFlow.get_player_faction_id()
	var capital: Dictionary = CityManager.get_capital_state(player_faction_id)
	if capital.is_empty():
		_show_framework_placeholder("大夫派驻", "[b]派驻失败[/b]\n没有找到玩家首都。")
		return
	var capital_id: String = str(capital.get("id", ""))
	var ministers: Array = MinisterManager.get_faction_civil_ministers(player_faction_id)
	if ministers.is_empty():
		_show_framework_placeholder("大夫派驻", "[b]派驻失败[/b]\n当前没有可用的大夫。")
		return
	var current: Dictionary = MinisterManager.get_city_civil_minister(capital_id)
	var chosen_id: String = str(ministers[0].get("id", ""))
	for minister_v: Variant in ministers:
		var minister: Dictionary = minister_v as Dictionary
		var minister_id: String = str(minister.get("id", ""))
		if minister_id != str(current.get("id", "")):
			chosen_id = minister_id
			break
	MinisterManager.assign_civil_minister(capital_id, chosen_id)
	_show_ministers_panel()


func _framework_ministers_summary() -> String:
	var pool: Dictionary = DataManager.get_minister_pool()
	var skills: Dictionary = DataManager.get_minister_skills()
	var total_entries: int = 0
	var historical_count: int = 0
	var template_count: int = 0
	var legendary_names: Array[String] = []
	var type_lines: Array[String] = []
	var player_faction_id: String = GameManager.get_player_faction()
	if player_faction_id == "":
		player_faction_id = DemoFlow.get_player_faction_id()
	var player_school_id: String = SchoolManager.get_current_school(player_faction_id)
	var matching_names: Array[String] = []
	var matching_titles: Array[String] = []
	var minister_types: Array = pool.keys()
	minister_types.sort()
	for type_v: Variant in minister_types:
		var type_id: String = str(type_v)
		var rarity_map: Dictionary = pool.get(type_id, {}) as Dictionary
		var type_count: int = 0
		for rarity_v: Variant in rarity_map.keys():
			var rarity: String = str(rarity_v)
			var entries: Array = rarity_map.get(rarity, []) as Array
			type_count += entries.size()
			total_entries += entries.size()
			for entry_v: Variant in entries:
				var entry: Dictionary = entry_v as Dictionary
				if bool(entry.get("is_historical", false)):
					historical_count += 1
				else:
					template_count += 1
				if rarity == "legendary":
					legendary_names.append(str(entry.get("name", entry.get("id", "未知"))))
				if player_school_id != "" and str(entry.get("school", "")) == player_school_id and bool(entry.get("is_historical", false)):
					matching_names.append(str(entry.get("name", entry.get("id", "未知"))))
					matching_titles.append("%s（%s）" % [
						str(entry.get("name", entry.get("id", "未知"))),
						str(entry.get("title", "未定义称号")),
					])
		type_lines.append("- %s：%d 人 / 技能 %d" % [
			_minister_type_name(type_id),
			type_count,
			(skills.get(type_id, []) as Array).size(),
		])

	var player_focus_text: String = "当前势力尚未配置默认学派。"
	if player_school_id != "":
		var school_data: Dictionary = DataManager.get_school(player_school_id)
		player_focus_text = "%s（%s）\n偏向学派：%s\n推荐历史人物：%s\n代表称号：\n%s" % [
			_faction_display_name(player_faction_id),
			_minister_school_name(player_school_id),
			str(school_data.get("core_idea", "未定义")),
			"、".join(matching_names.slice(0, mini(4, matching_names.size()))) if not matching_names.is_empty() else "暂无已配置历史人物",
			"\n".join(matching_titles.slice(0, mini(4, matching_titles.size()))) if not matching_titles.is_empty() else "- 暂无代表人物",
		]

	return "[b]试玩说明[/b]\n这一页用于让玩家理解“官员系统未来会怎么接进城市和外交”，现在先提供人物池、类型和势力偏好作为试玩认知锚点。\n\n[b]系统定位[/b]\n官员招募、任命、能力成长、城市派驻与国家加成的统一入口。\n\n[b]当前势力关注[/b]\n%s\n\n[b]当前数据[/b]\n官员条目：%d\n历史人物：%d\n随机模板：%d\n技能定义：%d\n\n[b]类型分布[/b]\n%s\n\n[b]传奇人物样例[/b]\n%s\n\n[b]建议动作[/b]\n可先打开城市查看内政承接位，或打开外交面板对照纵横类大夫与关系系统。" % [
		player_focus_text,
		total_entries,
		historical_count,
		template_count,
		_count_minister_skills(skills),
		"\n".join(type_lines) if not type_lines.is_empty() else "暂无官员类型",
		"、".join(legendary_names.slice(0, mini(8, legendary_names.size()))) if not legendary_names.is_empty() else "暂无传奇人物",
	]


func _framework_intelligence_summary() -> String:
	var factions: Array = DataManager.get_all_factions()
	var player_faction: String = GameManager.get_player_faction()
	if player_faction == "":
		player_faction = DemoFlow.get_player_faction_id()
	var faction_lines: Array[String] = []
	var hostile_lines: Array[String] = []
	var relation_lines: Array[String] = []
	var active_faction_count: int = 0
	for raw_faction: Variant in factions:
		var faction: Dictionary = raw_faction as Dictionary
		var faction_id: String = str(faction.get("id", ""))
		if faction_id == "" or bool(faction.get("is_passive", false)):
			continue
		active_faction_count += 1
		var city_count: int = CityManager.get_faction_city_states(faction_id).size()
		var opinion: int = DiplomacySystem.get_opinion(player_faction, faction_id) if faction_id != player_faction else 0
		var personality: Dictionary = faction.get("ai_personality", {}) as Dictionary
		var aggression: int = int(personality.get("aggression", 0))
		var relation_state: String = "本国"
		if faction_id != player_faction:
			if DiplomacySystem.are_at_war(player_faction, faction_id):
				relation_state = "交战"
			elif DiplomacySystem.are_allied(player_faction, faction_id):
				relation_state = "同盟"
			elif DiplomacySystem.have_non_aggression(player_faction, faction_id):
				relation_state = "互不侵犯"
			else:
				relation_state = "中立"
		faction_lines.append("- %s：城池 %d / 当前关系 %+d / 侵略 %d" % [
			str(faction.get("name", faction_id)),
			city_count,
			opinion,
			aggression,
		])
		if faction_id != player_faction:
			relation_lines.append("- %s：%s / 当前好感 %+d" % [
				str(faction.get("name", faction_id)),
				relation_state,
				opinion,
			])
		if faction_id != player_faction and (opinion < 0 or aggression >= 4):
			hostile_lines.append("- %s：关系 %+d，侵略 %d" % [
				str(faction.get("name", faction_id)),
				opinion,
				aggression,
			])

	var neutral_count: int = CityManager.get_faction_city_states("neutral").size()
	return "[b]试玩说明[/b]\n这一页用于帮助玩家快速判断敌我态势：谁危险、谁接壤、当前外交关系如何，以及下一步该去大地图还是外交面板。\n\n[b]系统定位[/b]\n侦察、情报力、敌情估计、外交风险与战争预警的统一入口。\n\n[b]当前情报源[/b]\n势力档案：%d\n城市归属：%d 城\n中立城：%d\n运行态外交关系：已接入\nAI 性格：已接入\n\n[b]势力概览[/b]\n%s\n\n[b]当前外交态势[/b]\n%s\n\n[b]重点关注[/b]\n%s\n\n[b]建议动作[/b]\n可直接打开大地图查看边境，或进入外交面板确认关系与条约。" % [
		active_faction_count,
		CityManager.get_all_city_states().size(),
		neutral_count,
		"\n".join(faction_lines) if not faction_lines.is_empty() else "暂无势力情报",
		"\n".join(relation_lines) if not relation_lines.is_empty() else "暂无外交态势",
		"\n".join(hostile_lines) if not hostile_lines.is_empty() else "暂无高风险目标",
	]


func _count_minister_skills(skills: Dictionary) -> int:
	var count: int = 0
	for skill_group_v: Variant in skills.values():
		count += (skill_group_v as Array).size()
	return count


func _minister_type_name(type_id: String) -> String:
	match type_id:
		"civil":
			return "文大夫"
		"military":
			return "武大夫"
		"diplomat":
			return "外交大夫"
		_:
			return type_id


func _minister_school_name(school_id: String) -> String:
	var school: Dictionary = DataManager.get_school(school_id)
	if not school.is_empty():
		return str(school.get("name", school_id))
	return school_id


func _event_category_name(category_id: String) -> String:
	match category_id:
		"economy":
			return "经济"
		"military":
			return "军事"
		"morale":
			return "民心"
		"season":
			return "季节"
		"politics":
			return "政治"
		"diplomacy":
			return "外交"
		"special":
			return "特殊"
		"school":
			return "学派"
		_:
			return category_id


func _create_demo_ui() -> void:
	_demo_layer = CanvasLayer.new()
	_demo_layer.layer = 120
	add_child(_demo_layer)

	_demo_objective_panel = _demo_objective_scene.instantiate() as PanelContainer
	_demo_layer.add_child(_demo_objective_panel)
	if _demo_objective_panel.has_signal("sortie_requested"):
		_demo_objective_panel.sortie_requested.connect(_on_demo_sortie_requested)
	if _demo_objective_panel.has_signal("cheat_attack_requested"):
		_demo_objective_panel.cheat_attack_requested.connect(_on_demo_cheat_attack_requested)
	if _demo_objective_panel.has_signal("panel_collapsed"):
		_demo_objective_panel.panel_collapsed.connect(_on_demo_objective_collapsed)
	if _demo_objective_panel.has_method("open") and _should_show_tutorial_guidance_ui():
		_demo_objective_panel.open()
	elif is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = false

	_demo_victory_popup = _demo_victory_scene.instantiate() as PanelContainer
	_demo_layer.add_child(_demo_victory_popup)
	if _demo_victory_popup.has_signal("return_to_hub_requested"):
		_demo_victory_popup.return_to_hub_requested.connect(_on_demo_victory_return_to_hub_requested)
	if _demo_victory_popup.has_signal("replay_requested"):
		_demo_victory_popup.replay_requested.connect(_on_demo_victory_replay_requested)
	if _demo_victory_popup.has_signal("inspect_result_requested"):
		_demo_victory_popup.inspect_result_requested.connect(_on_demo_victory_inspect_result_requested)

	_demo_expand_btn = Button.new()
	_demo_expand_btn.text = "展开目标"
	_demo_expand_btn.custom_minimum_size = Vector2(112, 38)
	_demo_expand_btn.offset_left = 24.0
	_demo_expand_btn.offset_top = 24.0
	_demo_expand_btn.offset_right = 136.0
	_demo_expand_btn.offset_bottom = 62.0
	_demo_expand_btn.visible = false
	SkirmishTileTextures.style_scene_button(_demo_expand_btn)
	_demo_expand_btn.pressed.connect(_on_demo_objective_expand_requested)
	_demo_layer.add_child(_demo_expand_btn)


func _create_persistent_end_btn() -> void:
	_end_turn_layer = CanvasLayer.new()
	_end_turn_layer.layer = 5
	add_child(_end_turn_layer)

	_persistent_end_btn = Button.new()
	_persistent_end_btn.text = "结束回合"
	SkirmishTileTextures.style_scene_button(_persistent_end_btn)
	_persistent_end_btn.custom_minimum_size = Vector2(140, 44)
	_persistent_end_btn.pressed.connect(_on_next_turn_pressed)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_turn_layer.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	vbox.add_child(_persistent_end_btn)


func _create_turn_info_popup() -> void:
	_turn_info_layer = CanvasLayer.new()
	_turn_info_layer.layer = 10

	_turn_info_panel = PanelContainer.new()
	_turn_info_panel.visible = false
	_turn_info_panel.custom_minimum_size = Vector2(340, 190)
	_turn_info_panel.set_anchors_preset(Control.PRESET_CENTER)
	_turn_info_panel.offset_left = -170
	_turn_info_panel.offset_right = 170
	_turn_info_panel.offset_top = -95
	_turn_info_panel.offset_bottom = 95

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.08, 0.06, 0.92)
	bg.border_color = Color(0.45, 0.38, 0.24, 1.0)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(6)
	bg.content_margin_left = 20.0
	bg.content_margin_right = 20.0
	bg.content_margin_top = 16.0
	bg.content_margin_bottom = 16.0
	_turn_info_panel.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)

	_turn_info_title = Label.new()
	_turn_info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_info_title.add_theme_font_size_override("font_size", 22)
	_turn_info_title.add_theme_color_override("font_color", Color("C8A84E"))
	vbox.add_child(_turn_info_title)

	_turn_info_season = Label.new()
	_turn_info_season.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_info_season.add_theme_font_size_override("font_size", 18)
	_turn_info_season.add_theme_color_override("font_color", Color("E8D5B0"))
	vbox.add_child(_turn_info_season)

	_turn_info_faction = Label.new()
	_turn_info_faction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_info_faction.add_theme_font_size_override("font_size", 16)
	_turn_info_faction.add_theme_color_override("font_color", Color("A08060"))
	vbox.add_child(_turn_info_faction)

	_turn_info_status = Label.new()
	_turn_info_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_info_status.add_theme_font_size_override("font_size", 16)
	_turn_info_status.add_theme_color_override("font_color", Color("9FCE7C"))
	vbox.add_child(_turn_info_status)

	_turn_info_panel.add_child(vbox)
	_turn_info_layer.add_child(_turn_info_panel)
	add_child(_turn_info_layer)


func _show_turn_info(status_text: String = "回合切换成功") -> void:
	if _turn_info_panel == null:
		return

	if is_instance_valid(_turn_info_tween):
		_turn_info_tween.kill()

	var turn: int = GameManager.get_current_turn()
	var faction: String = GameManager.get_current_faction()
	var season: String = CityManager.get_current_season(turn)

	_turn_info_title.text = "第 %d 回合" % turn
	_turn_info_season.text = "时节：%s" % SEASON_NAMES.get(season, season)
	_turn_info_faction.text = "%s 的回合" % FACTION_NAMES.get(faction, faction)
	_turn_info_status.text = status_text
	_turn_info_panel.visible = true
	_turn_info_panel.modulate.a = 1.0

	_turn_info_tween = create_tween()
	_turn_info_tween.tween_interval(1.5)
	_turn_info_tween.tween_property(_turn_info_panel, "modulate:a", 0.0, 0.5)
	_turn_info_tween.tween_callback(func() -> void: _turn_info_panel.visible = false)


func _ensure_big_map() -> void:
	if is_instance_valid(_big_map_panel):
		return

	_big_map_panel = _big_map_scene.instantiate() as CanvasLayer
	add_child(_big_map_panel)
	_big_map_panel.city_clicked.connect(_on_city_clicked)
	_big_map_panel.map_closed.connect(_on_big_map_closed)


func _on_diplomacy_button_pressed() -> void:
	_close_big_map()
	_close_city_panel()
	_set_toolbar_visible(false)
	_set_end_turn_visible(true)

	if not is_instance_valid(_diplomacy_panel):
		_diplomacy_panel = _diplomacy_scene.instantiate() as Panel
		_diplomacy_panel.diplomacy_panel_closed.connect(_on_diplomacy_closed)
		add_child(_diplomacy_panel)

	_diplomacy_panel.open()


func _on_diplomacy_closed() -> void:
	_diplomacy_panel = null
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)


func _on_tech_button_pressed() -> void:
	var panel := $TechTreePanel as Control
	panel.visible = not panel.visible


func _on_skirmish_button_pressed() -> void:
	_set_toolbar_visible(false)
	_set_end_turn_visible(false)

	if not is_instance_valid(_scenario_panel):
		_scenario_panel = _scenario_panel_scene.instantiate() as CanvasLayer
		add_child(_scenario_panel)
		_scenario_panel.panel_closed.connect(_on_skirmish_scenario_closed)
		_scenario_panel.skirmish_started.connect(_on_scenario_skirmish_started)

	_scenario_panel.open_panel()


func _on_skirmish_scenario_closed() -> void:
	if TacticalSkirmishManager.is_active():
		return
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)


func _on_big_map_button_pressed() -> void:
	if DemoFlow.is_enabled():
		DemoFlow.mark_step_completed(DemoFlow.STEP_OPEN_BIG_MAP)
		DemoFlow.mark_strategy_prepared_if_ready()
	_close_diplomacy()
	_close_city_panel()
	_set_toolbar_visible(false)
	_set_end_turn_visible(true)
	_ensure_big_map()
	_big_map_panel.open()
	_last_big_map_city_focus_id = ""
	_embed_resource_bar(_big_map_panel.get_resource_bar_slot())


func _on_big_map_closed() -> void:
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)
	_close_big_map()


func _on_city_clicked(city_id: String) -> void:
	if DemoFlow.is_enabled() and city_id == DemoFlow.get_target_city_id():
		DemoFlow.mark_step_completed(DemoFlow.STEP_INSPECT_LUOYI)
		if DemoFlow.is_step_completed(DemoFlow.STEP_CAPTURE_LUOYI):
			DemoFlow.mark_result_reviewed()
	_close_big_map()
	_close_city_panel()
	_set_toolbar_visible(false)
	_set_end_turn_visible(true)
	_last_big_map_city_focus_id = city_id

	_city_panel = _city_panel_scene.instantiate() as Panel
	add_child(_city_panel)
	_city_panel.return_to_map.connect(_on_city_panel_back)
	_city_panel.panel_closed.connect(_on_city_panel_closed)
	_city_panel.open(city_id)
	_embed_resource_bar(_city_panel.get_resource_bar_slot())


func _on_city_panel_back() -> void:
	_close_city_panel()
	_set_end_turn_visible(true)
	_ensure_big_map()
	_big_map_panel.open()
	if _last_big_map_city_focus_id != "" and _big_map_panel.has_method("focus_city"):
		_big_map_panel.focus_city(_last_big_map_city_focus_id)
	_embed_resource_bar(_big_map_panel.get_resource_bar_slot())


func _on_city_panel_closed() -> void:
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)
	_close_city_panel()


func _on_event_test_button_pressed() -> void:
	if not _debug_tools_enabled:
		return
	_set_toolbar_visible(false)
	_set_end_turn_visible(false)

	if not is_instance_valid(_event_test_panel):
		_event_test_panel = _event_test_scene.instantiate() as Panel
		add_child(_event_test_panel)
		_event_test_panel.test_panel_closed.connect(_on_event_test_closed)

	_event_test_panel.open()


func _on_event_test_closed() -> void:
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)


func _on_return_mode_pressed() -> void:
	StartupFlow.trace("Main._on_return_mode_pressed")
	_close_big_map()
	_close_diplomacy()
	_close_city_panel()
	if is_instance_valid(_event_test_panel):
		_event_test_panel.queue_free()
		_event_test_panel = null
	StartupFlow.return_to_mode_select()


func _on_demo_sortie_requested() -> void:
	StartupFlow.trace("Main._on_demo_sortie_requested begin demo=%s phase=%s" % [
		str(DemoFlow.is_enabled()),
		GameManager.Phase.keys()[GameManager.get_current_phase()],
	])
	if not DemoFlow.is_enabled():
		StartupFlow.trace("Main._on_demo_sortie_requested ignored demo disabled")
		return
	_close_big_map()
	_close_diplomacy()
	_close_city_panel()
	_set_end_turn_visible(false)
	DemoFlow.mark_step_completed(DemoFlow.STEP_START_CAMPAIGN)
	var scenario_id: String = DemoFlow.get_recommended_scenario_id()
	var season: String = DemoFlow.get_recommended_season()
	if DemoFlow.is_tutorial_enabled():
		season = CityManager.get_current_season(GameManager.get_current_turn())
	if not _start_skirmish_scenario(scenario_id, season):
		if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel):
			_demo_objective_panel.visible = true
		_set_toolbar_visible(true)
		_show_turn_info("出征失败：未能打开演武")
		StartupFlow.trace("Main._on_demo_sortie_requested failed")
	else:
		StartupFlow.trace("Main._on_demo_sortie_requested success active=%s" % str(TacticalSkirmishManager.is_active()))


func _on_demo_cheat_attack_requested() -> void:
	TacticalSkirmishManager.set_demo_attack_multiplier(DEMO_CHEAT_ATTACK_MULTIPLIER)
	if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel) and _demo_objective_panel.has_method("update_panel"):
		_demo_objective_panel.update_panel()
	_show_turn_info("测试作弊已开启：我方演武伤害 ×%d" % int(DEMO_CHEAT_ATTACK_MULTIPLIER))


func _on_demo_objective_collapsed() -> void:
	if not _should_show_tutorial_guidance_ui():
		return
	if is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = false
	if is_instance_valid(_demo_expand_btn):
		_demo_expand_btn.visible = true


func _on_demo_objective_expand_requested() -> void:
	if not _should_show_tutorial_guidance_ui():
		return
	if is_instance_valid(_demo_expand_btn):
		_demo_expand_btn.visible = false
	if is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = true
		if _demo_objective_panel.has_method("update_panel"):
			_demo_objective_panel.update_panel()


func _on_scenario_skirmish_started(scenario_id: String, season: String) -> void:
	_start_skirmish_scenario(scenario_id, season)


func _start_skirmish_scenario(scenario_id: String, season: String) -> bool:
	StartupFlow.trace("Main._start_skirmish_scenario id=%s season=%s" % [scenario_id, season])
	var cfg: Dictionary = DataManager.get_skirmish_scenario(scenario_id)
	if cfg.is_empty():
		push_error("Main: 未找到场景 %s" % scenario_id)
		StartupFlow.trace("Main._start_skirmish_scenario missing cfg")
		return false
	if DemoFlow.is_full_demo_enabled():
		_inject_player_recruited_units_into_skirmish(cfg)

	var panel: CanvasLayer = _ensure_active_skirmish_panel()
	StartupFlow.trace("Main._start_skirmish_scenario panel=%s layer=%d visible=%s" % [
		panel.name,
		panel.layer,
		str(panel.visible),
	])
	if panel.has_method("open_panel_with_config"):
		panel.open_panel_with_config(cfg.duplicate(true), season)
	else:
		TacticalSkirmishManager.start_skirmish_with_config(cfg.duplicate(true), season)
		panel.open_panel()
	return true


func _inject_player_recruited_units_into_skirmish(cfg: Dictionary) -> void:
	var player_faction_id: String = str(cfg.get("player_faction_id", GameManager.get_player_faction()))
	var player_city: Dictionary = cfg.get("player_city", {}) as Dictionary
	if player_city.is_empty():
		return
	var initial_units_variant: Variant = cfg.get("initial_units", [])
	if initial_units_variant is not Array:
		return
	var initial_units: Array = initial_units_variant as Array
	var current_composition: Dictionary = GameManager.get_unit_composition(player_faction_id)
	if current_composition.is_empty():
		return

	var scenario_counts: Dictionary = {}
	for raw_unit: Variant in initial_units:
		if raw_unit is not Dictionary:
			continue
		var unit_entry: Dictionary = raw_unit as Dictionary
		if str(unit_entry.get("faction_id", "")) != player_faction_id:
			continue
		var unit_type_id: String = str(unit_entry.get("unit_type_id", ""))
		scenario_counts[unit_type_id] = int(scenario_counts.get(unit_type_id, 0)) + 1

	var spawn_index: int = 1
	for unit_type_id_variant: Variant in current_composition.keys():
		var unit_type_id: String = str(unit_type_id_variant)
		var current_count: int = int(current_composition.get(unit_type_id, 0))
		var baseline_count: int = int(scenario_counts.get(unit_type_id, 0))
		var extra_count: int = max(current_count - baseline_count, 0)
		var added: int = 0
		while added < extra_count:
			initial_units.append({
				"id": "demo_extra_%s_%d" % [unit_type_id, spawn_index],
				"faction_id": player_faction_id,
				"unit_type_id": unit_type_id,
				"q": int(player_city.get("q", 0)),
				"r": int(player_city.get("r", 0))
			})
			added += 1
			spawn_index += 1
	cfg["initial_units"] = initial_units


func _ensure_active_skirmish_panel() -> CanvasLayer:
	if is_instance_valid(_active_skirmish_panel):
		StartupFlow.trace("Main._ensure_active_skirmish_panel reuse")
		return _active_skirmish_panel
	StartupFlow.trace("Main._ensure_active_skirmish_panel create")
	_active_skirmish_panel = _skirmish_panel_scene.instantiate() as CanvasLayer
	_active_skirmish_panel.name = "ActiveSkirmishPanel"
	_active_skirmish_panel.layer = 100
	add_child(_active_skirmish_panel)
	if _active_skirmish_panel.has_signal("panel_closed") and not _active_skirmish_panel.panel_closed.is_connected(_on_skirmish_panel_closed):
		_active_skirmish_panel.panel_closed.connect(_on_skirmish_panel_closed)
	StartupFlow.trace("Main._ensure_active_skirmish_panel created layer=%d" % _active_skirmish_panel.layer)
	return _active_skirmish_panel


func _on_skirmish_ended(winner_faction_id: String) -> void:
	var completed: bool = DemoFlow.apply_skirmish_victory(winner_faction_id)
	if not completed:
		if DemoFlow.is_enabled() and winner_faction_id != "":
			_show_turn_info("演武失利：可重置演武后再战")
		return
	if DemoFlow.is_enabled():
		_finish_demo_skirmish()
	_show_turn_info("Demo 完成：洛邑已归秦")


func _finish_demo_skirmish() -> void:
	if is_instance_valid(_active_skirmish_panel):
		_active_skirmish_panel.queue_free()
		_active_skirmish_panel = null
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)
	if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = true
		if _demo_objective_panel.has_method("update_panel"):
			_demo_objective_panel.update_panel()
	if is_instance_valid(_demo_victory_popup) and _demo_victory_popup.has_method("show_victory"):
		_demo_victory_popup.show_victory()


func _on_demo_victory_return_to_hub_requested() -> void:
	_close_big_map()
	_close_diplomacy()
	_close_city_panel()
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)
	if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = true
		if _demo_objective_panel.has_method("update_panel"):
			_demo_objective_panel.update_panel()


func _on_demo_victory_replay_requested() -> void:
	TacticalSkirmishManager.reset_skirmish()
	CityManager.reset()
	DemoFlow.reset()
	DemoFlow.set_enabled(true)
	if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = true
		if _demo_objective_panel.has_method("update_panel"):
			_demo_objective_panel.update_panel()
	_on_demo_sortie_requested()


func _on_demo_victory_inspect_result_requested() -> void:
	_close_big_map()
	_close_diplomacy()
	_close_city_panel()
	_set_end_turn_visible(true)
	_on_city_clicked(DemoFlow.get_target_city_id())


func _on_skirmish_panel_closed() -> void:
	StartupFlow.trace("Main._on_skirmish_panel_closed")
	if is_instance_valid(_active_skirmish_panel):
		_active_skirmish_panel.queue_free()
		_active_skirmish_panel = null
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)
	if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = true


func _on_next_turn_pressed() -> void:
	if _is_processing_turn:
		return

	_is_processing_turn = true
	_persistent_end_btn.disabled = true

	if GameManager.get_current_phase() != GameManager.Phase.ACTION:
		push_warning("[Main] 当前阶段 %s，无法结束回合" % GameManager.get_current_phase())
		_reenable_end_btn()
		return

	GameManager.end_current_turn()
	while GameManager.get_current_phase() == GameManager.Phase.ACTION and not GameManager.is_player_faction(GameManager.get_current_faction()):
		GameManager.process_ai_turn()

	_refresh_resource_bar()

	if GameManager.get_current_phase() == GameManager.Phase.GAME_OVER:
		_set_end_turn_visible(false)
		_reenable_end_btn()
		return

	_show_turn_info("已结算敌方回合")
	_reenable_end_btn()


func _reenable_end_btn() -> void:
	_is_processing_turn = false
	if _persistent_end_btn != null:
		_persistent_end_btn.disabled = false
