extends Node

## ⚠️ 已退役：main.tscn / main.gd 不再作为任何模式的游戏入口。
## 启动流程已按模式分流（见 scripts/autoload/startup_flow.gd 的 _scene_for_mode()）：
##   strategy_hub / test_menu → hub_scene.tscn；full_demo / 默认模式 → big_map_scene.tscn；demo → skirmish_scene.tscn。
## 本文件仅保留给 tests/unit/test_main_turn_ui.gd 等旧测试容器使用（preload 并实例化 main.tscn），
## 其中的信号路由与旧 API 转发 shim 保持可用，勿再接入启动流程。

## 主场景脚本 — 游戏入口 / 中枢交互。
## 大地图及其相关调度已迁出到独立场景 scenes/ui/big_map/big_map_scene.gd：
## main 实例化 big_map_scene 作为子节点并注入 resource_bar / tech_tree_panel，
## 中枢（hub）的「大地图/城池/外交/科技/大夫」信号转路由 big_map_scene 处理。
## 演武（Demo/战术）职责已迁出到独立场景 scenes/ui/skirmish/skirmish_scene.gd：
## main 实例化 skirmish_scene 作为子节点并注入 big_map_scene 引用，
## 中枢的「军事 / Demo 目标」信号转路由 skirmish_scene 处理。

var _resource_bar: Control = null
var _toolbar_elements: Array[Control] = []
var _hub_scene: PackedScene = preload("res://scenes/ui/hub/hub_scene.tscn")
var _hub_panel: Control = null
var _big_map_scene: PackedScene = preload("res://scenes/ui/big_map/big_map_scene.tscn")
var _big_map_scene_instance: BigMapScene = null
var _skirmish_scene: PackedScene = preload("res://scenes/ui/skirmish/skirmish_scene.tscn")
var _skirmish_scene_instance: SkirmishScene = null


func _ready() -> void:
	StartupFlow.trace("Main._ready begin phase=%s pending=%s mode=%s faction=%s" % [
		GameManager.Phase.keys()[GameManager.get_current_phase()],
		str(StartupFlow.is_game_start_pending()),
		StartupFlow.selected_mode,
		StartupFlow.selected_faction,
	])
	_resource_bar = $ResourceBar as Control
	_resource_bar.visible = false

	_init_game()

	# 大地图独立场景：main 实例化并注入资源栏/科技树引用。
	# 先于 hub 加入子节点，保持旧版叠放顺序（main 层按钮在 hub 之下）。
	_big_map_scene_instance = _big_map_scene.instantiate() as BigMapScene
	_big_map_scene_instance.name = "BigMapScene"
	_big_map_scene_instance.resource_bar = _resource_bar
	_big_map_scene_instance.tech_tree_panel = $TechTreePanel
	add_child(_big_map_scene_instance)
	_big_map_scene_instance.hub_visibility_requested.connect(_on_big_map_scene_hub_visibility_requested)
	_big_map_scene_instance.hub_panel_action_requested.connect(_on_big_map_scene_hub_panel_action_requested)

	_hub_panel = _hub_scene.instantiate() as Control
	_hub_panel.name = "FrameworkHub"
	add_child(_hub_panel)
	_toolbar_elements = [_hub_panel]
	_connect_hub_signals()

	# 演武独立场景：main 实例化并注入大地图引用；Demo 教学 UI / 自动进演武由它自管。
	_skirmish_scene_instance = _skirmish_scene.instantiate() as SkirmishScene
	_skirmish_scene_instance.name = "SkirmishScene"
	_skirmish_scene_instance.big_map_scene = _big_map_scene_instance
	add_child(_skirmish_scene_instance)
	_skirmish_scene_instance.hub_visibility_requested.connect(_set_toolbar_visible)
	StartupFlow.trace("Main._ready end phase=%s demo=%s" % [
		GameManager.Phase.keys()[GameManager.get_current_phase()],
		str(DemoFlow.is_enabled()),
	])


func _exit_tree() -> void:
	StartupFlow.trace("Main._exit_tree begin")
	StartupFlow.trace("Main._exit_tree end")


func _init_game() -> void:
	StartupFlow.trace("Main._init_game begin phase=%s pending=%s auto=%s" % [
		GameManager.Phase.keys()[GameManager.get_current_phase()],
		str(StartupFlow.is_game_start_pending()),
		str(StartupFlow.should_main_auto_start_game()),
	])
	StartupFlow.trace("Main._init_game skip always")


# ── 工具栏 / 中枢可见性 ────────────────────────────────────

func _set_toolbar_visible(is_visible: bool) -> void:
	for elem: Control in _toolbar_elements:
		if is_instance_valid(elem):
			elem.visible = is_visible


## big_map_scene 请求显示/隐藏中枢工具栏（大地图/叠层打开时隐藏）
func _on_big_map_scene_hub_visibility_requested(is_visible: bool) -> void:
	_set_toolbar_visible(is_visible)


## big_map_scene 请求在中枢内打开框架页（学派/存档面板属于 hub）
func _on_big_map_scene_hub_panel_action_requested(action: String) -> void:
	match action:
		"schools":
			_hub_panel.call("_show_schools_panel")
		"save":
			_hub_panel.call("_show_save_load_panel")


# ── 中枢信号连接（阶段1 的 hub→main 链路；大地图相关路由到 big_map_scene，演武路由到 skirmish_scene）──

func _connect_hub_signals() -> void:
	_hub_panel.open_big_map_requested.connect(_big_map_scene_instance.open_big_map)
	_hub_panel.open_city_requested.connect(_big_map_scene_instance.open_city)
	_hub_panel.open_diplomacy_requested.connect(_big_map_scene_instance.open_diplomacy)
	_hub_panel.open_tech_requested.connect(_big_map_scene_instance.toggle_tech)
	_hub_panel.open_military_requested.connect(_on_hub_military_requested)
	_hub_panel.open_minister_requested.connect(_big_map_scene_instance.open_minister_overlay)
	_hub_panel.hub_visibility_changed.connect(_on_hub_visibility_changed)
	_hub_panel.demo_objective_update_requested.connect(_on_hub_demo_objective_update_requested)


func _on_hub_military_requested() -> void:
	# 与中枢原 military 模块分支保持一致：Demo 走洛邑演武，普通模式走演武场景选择
	_skirmish_scene_instance.open_military()


func _on_hub_visibility_changed(show_hub: bool) -> void:
	if not show_hub:
		return
	# 大地图仍开着时，关闭占位层即可；否则恢复中枢与工具栏
	if _big_map_scene_instance != null and _big_map_scene_instance.is_big_map_open():
		return
	_set_toolbar_visible(true)
	if _big_map_scene_instance != null:
		_big_map_scene_instance.set_end_turn_visible(false)


func _on_hub_demo_objective_update_requested() -> void:
	_skirmish_scene_instance.update_demo_objective()


# ── 旧 API 转发（tests/unit/test_main_turn_ui.gd 仍通过 main 调用/读取已迁出的职责）──

func _on_big_map_button_pressed() -> void:
	_big_map_scene_instance.open_big_map()


func _on_big_map_closed() -> void:
	_big_map_scene_instance._on_big_map_closed()


func _on_city_clicked(city_id: String) -> void:
	_big_map_scene_instance.open_city(city_id)


func _on_city_panel_back() -> void:
	_big_map_scene_instance._on_city_panel_back()


func _on_diplomacy_button_pressed() -> void:
	_big_map_scene_instance.open_diplomacy()


func _on_diplomacy_closed() -> void:
	_big_map_scene_instance._on_diplomacy_closed()


func _on_tech_button_pressed() -> void:
	_big_map_scene_instance.toggle_tech()


func _on_next_turn_pressed() -> void:
	_big_map_scene_instance._on_next_turn_pressed()


## 演武旧 API 转发：main 不再持有演武/Demo 状态，旧调用路径（GUT 测试）转发到 skirmish_scene。
func _on_skirmish_button_pressed() -> void:
	_skirmish_scene_instance._on_skirmish_button_pressed()


func _on_demo_sortie_requested() -> void:
	_skirmish_scene_instance._on_demo_sortie_requested()


func _on_demo_cheat_attack_requested() -> void:
	_skirmish_scene_instance._on_demo_cheat_attack_requested()


func _on_skirmish_ended(winner_faction_id: String) -> void:
	_skirmish_scene_instance._on_skirmish_ended(winner_faction_id)


## 兼容转发：main 不再持有大地图/演武状态（结束回合按钮/回合弹层/大地图面板/Demo 面板等），
## 旧读取路径（GUT 测试）经由 _get 转发到 big_map_scene / skirmish_scene。
func _get(property: StringName) -> Variant:
	if _big_map_scene_instance != null:
		var big_map_value: Variant = _big_map_scene_instance.get(property)
		if big_map_value != null:
			return big_map_value
	if _skirmish_scene_instance != null:
		return _skirmish_scene_instance.get(property)
	return null
