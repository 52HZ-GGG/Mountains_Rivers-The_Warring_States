extends CanvasLayer

## 战术演武场景选择面板
## 选择场景 + 季节 → 通知 main.gd 打开演武面板

signal skirmish_started(scenario_id: String, season: String)

var _guide_panel_scene: PackedScene = preload("res://scenes/ui/skirmish/skirmish_test_guide_panel.tscn")
var _guide_panel: CanvasLayer = null
var _scenarios: Array = []
var _selected_index: int = -1

@onready var _scenario_list: ItemList = %ScenarioList
@onready var _detail_name: Label = %DetailName
@onready var _detail_desc: RichTextLabel = %DetailDesc
@onready var _detail_mechanics: RichTextLabel = %DetailMechanics
@onready var _detail_info: Label = %DetailInfo
@onready var _season_option: OptionButton = %SeasonOption
@onready var _start_btn: Button = %StartBtn
@onready var _guide_btn: Button = %GuideBtn


func _ready() -> void:
	visible = false
	_scenarios = DataManager.get_skirmish_scenarios()
	_populate_list()
	_scenario_list.item_selected.connect(_on_scenario_selected)
	SkirmishTileTextures.style_scene_button(%BackBtn)
	SkirmishTileTextures.style_scene_button(_start_btn)
	SkirmishTileTextures.style_scene_button(_guide_btn)
	%BackBtn.pressed.connect(_on_back_pressed)
	_start_btn.pressed.connect(_on_start_pressed)
	_start_btn.disabled = true
	SkirmishTileTextures.update_button_disabled(_start_btn)
	_guide_btn.pressed.connect(_on_guide_pressed)
	_guide_btn.disabled = true
	SkirmishTileTextures.update_button_disabled(_guide_btn)


func open_panel() -> void:
	show()
	_selected_index = -1
	_scenario_list.deselect_all()
	_clear_detail()
	_start_btn.disabled = true
	_guide_btn.disabled = true


func close_panel() -> void:
	hide()


func _populate_list() -> void:
	_scenario_list.clear()
	for s: Dictionary in _scenarios:
		_scenario_list.add_item(str(s.get("name", "???")))
	if _scenarios.size() > 0:
		_selected_index = 0
		_scenario_list.select(0)
		_show_detail(0)


func _on_scenario_selected(index: int) -> void:
	_selected_index = index
	_show_detail(index)
	_start_btn.disabled = false
	_guide_btn.disabled = false


func _show_detail(index: int) -> void:
	if index < 0 or index >= _scenarios.size():
		_clear_detail()
		return
	var s: Dictionary = _scenarios[index]
	_detail_name.text = str(s.get("name", ""))
	_detail_desc.text = str(s.get("description", ""))
	var mechanics: Array = s.get("mechanics", [])
	if mechanics.is_empty():
		_detail_mechanics.text = ""
	else:
		var lines: PackedStringArray = []
		for m: String in mechanics:
			lines.append("- %s" % m)
		_detail_mechanics.text = "\n".join(lines)
	var w: int = int(s.get("map_width", 7))
	var h: int = int(s.get("map_height", 7))
	var units: Array = s.get("initial_units", [])
	var player_count: int = 0
	var enemy_count: int = 0
	var pfid: String = str(s.get("player_faction_id", ""))
	for u: Dictionary in units:
		if str(u.get("faction_id", "")) == pfid:
			player_count += 1
		else:
			enemy_count += 1
	_detail_info.text = "地图：%dx%d | 我方：%d 单位 | 敌方：%d 单位" % [w, h, player_count, enemy_count]


func _clear_detail() -> void:
	_detail_name.text = ""
	_detail_desc.text = ""
	_detail_mechanics.text = ""
	_detail_info.text = ""


func _on_back_pressed() -> void:
	close_panel()


func _on_start_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _scenarios.size():
		print("[ScenarioPanel] 未选中场景，忽略")
		return
	var s: Dictionary = _scenarios[_selected_index]
	var scenario_id: String = str(s.get("id", ""))
	var season: String = "summer"
	match _season_option.selected:
		0: season = "spring"
		1: season = "summer"
		2: season = "autumn"
		3: season = "winter"
	print("[ScenarioPanel] 开始演武: id=%s season=%s" % [scenario_id, season])
	skirmish_started.emit(scenario_id, season)
	print("[ScenarioPanel] 信号已发射")
	close_panel()


func _on_guide_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _scenarios.size():
		return
	var s: Dictionary = _scenarios[_selected_index]
	var scenario_id: String = str(s.get("id", ""))
	if not is_instance_valid(_guide_panel):
		_guide_panel = _guide_panel_scene.instantiate() as CanvasLayer
		add_child(_guide_panel)
	_guide_panel.open_guide(scenario_id)
