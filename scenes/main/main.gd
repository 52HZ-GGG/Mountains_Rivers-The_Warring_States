extends Node

## 主场景脚本 — 连接UI和游戏系统

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


func _ready() -> void:
	_resource_bar = $ResourceBar as HBoxContainer

	# 连接外交按钮
	var diplomacy_button := $DiplomacyButton
	diplomacy_button.pressed.connect(_on_diplomacy_button_pressed)

	# 连接科技按钮
	var tech_button := $TechButton
	tech_button.pressed.connect(_on_tech_button_pressed)

	# 战术演武（阶段1）
	var skirmish_button := $SkirmishButton
	skirmish_button.pressed.connect(_on_skirmish_button_pressed)

	# 大地图
	var big_map_button := $BigMapButton
	big_map_button.pressed.connect(_on_big_map_button_pressed)

	# 初始化游戏（默认7国，玩家为秦）
	_init_game()

	# 事件弹窗（自管理，监听 SignalBus.event_triggered）
	_event_popup = _event_popup_scene.instantiate() as Panel
	add_child(_event_popup)

	# 事件测试按钮（开发用）
	var event_test_btn := SkirmishTileTextures.styled_button("事件测试")
	event_test_btn.pressed.connect(_on_event_test_button_pressed)
	# 放在 BigMapButton 旁边
	var big_map_btn := $BigMapButton
	big_map_btn.get_parent().add_child(event_test_btn)
	big_map_btn.get_parent().move_child(event_test_btn, big_map_btn.get_index() + 1)


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
	# 如果 StartupFlow 已经启动了游戏，跳过
	if GameManager.get_current_phase() != GameManager.Phase.GAME_INIT:
		print("[Main] 游戏已由 StartupFlow 启动，跳过重复初始化")
		return
	var active_factions: Array[String] = []
	for fid in GameManager.FACTION_IDS:
		active_factions.append(fid)
	GameManager.start_game(active_factions, "qin")
	print("[Main] 游戏初始化完成，玩家: 秦国")


## 将 ResourceBar 嵌入目标 VBox（放在标题栏之后）
func _embed_resource_bar(target_vbox: VBoxContainer) -> void:
	if _resource_bar.get_parent() != null:
		_resource_bar.get_parent().remove_child(_resource_bar)
	target_vbox.add_child(_resource_bar)
	target_vbox.move_child(_resource_bar, 1)
	_resource_bar.visible = true
	_resource_bar.refresh()


## 从当前父节点取回 ResourceBar，隐藏后放回 Main
func _reclaim_resource_bar() -> void:
	if _resource_bar.get_parent() != null and _resource_bar.get_parent() != self:
		_resource_bar.get_parent().remove_child(_resource_bar)
		add_child(_resource_bar)
	_resource_bar.visible = false


func _ensure_big_map() -> void:
	if not is_instance_valid(_big_map_panel):
		_big_map_panel = _big_map_scene.instantiate() as CanvasLayer
		add_child(_big_map_panel)
		_big_map_panel.city_clicked.connect(_on_city_clicked)
		_big_map_panel.map_closed.connect(_on_big_map_closed)


func _on_diplomacy_button_pressed() -> void:
	_close_big_map()
	if not is_instance_valid(_diplomacy_panel):
		_diplomacy_panel = _diplomacy_scene.instantiate() as Panel
		add_child(_diplomacy_panel)
	_diplomacy_panel.open()


func _on_tech_button_pressed() -> void:
	var panel := $TechTreePanel
	panel.visible = not panel.visible


func _on_skirmish_button_pressed() -> void:
	if not is_instance_valid(_scenario_panel):
		_scenario_panel = _scenario_panel_scene.instantiate() as CanvasLayer
		add_child(_scenario_panel)
		_scenario_panel.skirmish_started.connect(_on_scenario_skirmish_started)
	_scenario_panel.open_panel()


func _on_big_map_button_pressed() -> void:
	_close_diplomacy()
	_close_city_panel()
	_ensure_big_map()
	_big_map_panel.open()
	_embed_resource_bar(_big_map_panel.get_resource_bar_slot())


func _on_big_map_closed() -> void:
	_close_big_map()


func _on_city_clicked(city_id: String) -> void:
	_close_big_map()
	_close_city_panel()
	_city_panel = _city_panel_scene.instantiate() as Panel
	add_child(_city_panel)
	_city_panel.return_to_map.connect(_on_city_panel_back)
	_city_panel.panel_closed.connect(_on_city_panel_closed)
	_city_panel.open(city_id)
	_embed_resource_bar(_city_panel.get_resource_bar_slot())


func _on_city_panel_back() -> void:
	_close_city_panel()
	_ensure_big_map()
	_big_map_panel.open()
	_embed_resource_bar(_big_map_panel.get_resource_bar_slot())


func _on_city_panel_closed() -> void:
	_close_city_panel()


func _on_event_test_button_pressed() -> void:
	if not is_instance_valid(_event_test_panel):
		_event_test_panel = _event_test_scene.instantiate() as Panel
		add_child(_event_test_panel)
	_event_test_panel.open()


func _on_scenario_skirmish_started(scenario_id: String, season: String) -> void:
	var cfg: Dictionary = DataManager.get_skirmish_scenario(scenario_id)
	if cfg.is_empty():
		push_error("Main: 未找到场景 %s" % scenario_id)
		return
	TacticalSkirmishManager.start_skirmish_with_config(cfg.duplicate(true), season)
	$SkirmishPanel.open_panel()
