extends Node

## 主场景脚本 — 连接 UI 和游戏系统

var _diplomacy_scene: PackedScene = preload("res://scenes/ui/diplomacy/diplomacy_panel.tscn")
var _diplomacy_panel: Panel = null
var _big_map_scene: PackedScene = preload("res://scenes/ui/big_map/big_map_panel.tscn")
var _big_map_panel: CanvasLayer = null
var _city_panel_scene: PackedScene = preload("res://scenes/ui/city_panel/city_panel.tscn")
var _city_panel: Panel = null
var _event_popup_scene: PackedScene = preload("res://scenes/ui/event_popup/event_popup.tscn")
var _event_popup: Panel = null
var _event_test_scene: PackedScene = preload("res://scenes/ui/event_test/event_test_panel.tscn")
var _event_test_panel: Panel = null
var _scenario_panel_scene: PackedScene = preload("res://scenes/ui/skirmish/skirmish_scenario_panel.tscn")
var _scenario_panel: CanvasLayer = null
var _resource_bar: HBoxContainer = null
var _event_test_btn: Button = null
var _toolbar_elements: Array[Control] = []

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
}


func _ready() -> void:
	_resource_bar = $ResourceBar as HBoxContainer
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

	var event_test_btn := SkirmishTileTextures.styled_button("事件测试")
	event_test_btn.pressed.connect(_on_event_test_button_pressed)
	var big_map_btn := $BigMapButton as Button
	big_map_btn.get_parent().add_child(event_test_btn)
	big_map_btn.get_parent().move_child(event_test_btn, big_map_btn.get_index() + 1)
	_event_test_btn = event_test_btn

	_toolbar_elements = [
		$Label as Control,
		$DiplomacyButton as Control,
		$TechButton as Control,
		$SkirmishButton as Control,
		$BigMapButton as Control,
		event_test_btn as Control,
	]

	_create_turn_info_popup()
	_create_persistent_end_btn()
	_set_end_turn_visible(false)


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
	if GameManager.get_current_phase() != GameManager.Phase.GAME_INIT:
		print("[Main] 游戏已由 StartupFlow 启动，跳过重复初始化")
		return

	var active_factions: Array[String] = []
	for faction_id: String in GameManager.FACTION_IDS:
		active_factions.append(faction_id)
	GameManager.start_game(active_factions, "qin")
	print("[Main] 游戏初始化完成，玩家: 秦国")


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
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)


func _on_big_map_button_pressed() -> void:
	_close_diplomacy()
	_close_city_panel()
	_set_toolbar_visible(false)
	_set_end_turn_visible(true)
	_ensure_big_map()
	_big_map_panel.open()
	_embed_resource_bar(_big_map_panel.get_resource_bar_slot())


func _on_big_map_closed() -> void:
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)
	_close_big_map()


func _on_city_clicked(city_id: String) -> void:
	_close_big_map()
	_close_city_panel()
	_set_toolbar_visible(false)
	_set_end_turn_visible(true)

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
	_embed_resource_bar(_big_map_panel.get_resource_bar_slot())


func _on_city_panel_closed() -> void:
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)
	_close_city_panel()


func _on_event_test_button_pressed() -> void:
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


func _on_scenario_skirmish_started(scenario_id: String, season: String) -> void:
	var cfg: Dictionary = DataManager.get_skirmish_scenario(scenario_id)
	if cfg.is_empty():
		push_error("Main: 未找到场景 %s" % scenario_id)
		return

	TacticalSkirmishManager.start_skirmish_with_config(cfg.duplicate(true), season)
	$SkirmishPanel.open_panel()


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

	_refresh_resource_bar()

	if GameManager.get_current_phase() == GameManager.Phase.GAME_OVER:
		_set_end_turn_visible(false)
		_reenable_end_btn()
		return

	_show_turn_info("回合切换成功")
	_reenable_end_btn()


func _reenable_end_btn() -> void:
	_is_processing_turn = false
	if _persistent_end_btn != null:
		_persistent_end_btn.disabled = false
