extends Node

## 主场景脚本 — 连接UI和游戏系统

var _diplomacy_scene: PackedScene = preload("res://scenes/ui/diplomacy/diplomacy_panel.tscn")
var _diplomacy_panel: Panel = null
var _big_map_scene: PackedScene = preload("res://scenes/ui/big_map/big_map_panel.tscn")
var _big_map_panel: CanvasLayer = null


func _ready() -> void:
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


func _close_big_map() -> void:
	if is_instance_valid(_big_map_panel):
		_big_map_panel.close()
		_big_map_panel = null


func _close_diplomacy() -> void:
	if is_instance_valid(_diplomacy_panel):
		_diplomacy_panel.queue_free()
		_diplomacy_panel = null


func _init_game() -> void:
	var active_factions: Array[String] = []
	for fid in GameManager.FACTION_IDS:
		active_factions.append(fid)
	GameManager.start_game(active_factions, "qin")
	print("[Main] 游戏初始化完成，玩家: 秦国")


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
	$SkirmishPanel.open_panel()


func _on_big_map_button_pressed() -> void:
	_close_diplomacy()
	if not is_instance_valid(_big_map_panel):
		_big_map_panel = _big_map_scene.instantiate() as CanvasLayer
		add_child(_big_map_panel)
	_big_map_panel.open()
