extends Node
## 启动流程管理器
## 管理：Splash → 公告 → 模式选择 → 势力选择 → 加载 → 游戏
##
## 用法：设为 autoload（在 GameManager 之前），启动时自动进入 Splash。
## 其它场景通过 StartupFlow.goto_xxx() 推进流程。

signal flow_changed(step: String)

const MODE_DEMO: String = "demo"
const MODE_FULL_DEMO: String = "full_demo"
const MODE_STRATEGY_HUB: String = "strategy_hub"
const MODE_TEST_MENU: String = "test_menu"
const TRACE_PATH: String = "user://startup_trace.log"

# 当前流程步骤
var _current_step: String = ""

# 是否正在启动流程中（main.gd 据此跳过自动初始化）
var is_startup_flow_active: bool = false

# 玩家选择
var selected_mode: String = ""
var selected_faction: String = ""
var _game_start_pending: bool = false

# 启动配置
@export var splash_scene: String = "res://scenes/ui/splash/splash_screen.tscn"
@export var mode_select_scene: String = "res://scenes/ui/splash/mode_select.tscn"
@export var faction_select_scene: String = "res://scenes/ui/splash/faction_select.tscn"
@export var loading_scene: String = "res://scenes/ui/splash/loading_screen.tscn"
@export var game_scene: String = "res://scenes/main/main.tscn"

# 是否跳过 Splash（调试用）
@export var skip_splash: bool = false

func _ready() -> void:
	_clear_trace()
	trace("StartupFlow._ready")
	# 应用全局隶书字体
	SkirmishTileTextures.apply_global_font()
	_restore_window_if_offscreen()
	call_deferred("_nudge_window_to_front")
	if _handle_direct_launch_args():
		return
	# 标记启动流程激活
	is_startup_flow_active = true
	# 避免在 _ready() 内直接切换场景触发 remove_child 错误
	call_deferred("_ensure_initial_scene")

# ────────────────────────────────────────────
# 流程入口
# ────────────────────────────────────────────

## 从头开始完整启动流程
func start_full_flow() -> void:
	trace("start_full_flow")
	selected_mode = ""
	selected_faction = ""
	if skip_splash:
		goto_mode_select()
	else:
		goto_splash()

## 跳过所有前置流程，直接进入游戏（测试用）
func quick_start(faction_id: String, mode: String = "classic") -> void:
	trace("quick_start faction=%s mode=%s" % [faction_id, mode])
	selected_mode = mode
	selected_faction = faction_id
	DemoFlow.set_enabled(_is_demo_mode(mode) or mode == MODE_STRATEGY_HUB)
	DemoFlow.set_full_demo_enabled(mode == MODE_FULL_DEMO)
	DemoFlow.set_tutorial_enabled(mode == MODE_DEMO)
	_start_game()


## 进入功能测试主菜单：跳过 Demo 任务层，只启动普通主场景。
func goto_test_menu() -> void:
	trace("goto_test_menu")
	selected_mode = MODE_TEST_MENU
	selected_faction = "qin"
	DemoFlow.set_enabled(false)
	DemoFlow.set_full_demo_enabled(false)
	DemoFlow.set_tutorial_enabled(false)
	_current_step = "test_menu"
	flow_changed.emit(_current_step)
	goto_game()


func goto_strategy_hub() -> void:
	trace("goto_strategy_hub")
	selected_mode = MODE_STRATEGY_HUB
	selected_faction = "qin"
	DemoFlow.set_enabled(true)
	DemoFlow.set_full_demo_enabled(false)
	DemoFlow.set_tutorial_enabled(false)
	_current_step = "strategy_hub"
	flow_changed.emit(_current_step)
	goto_game()


## 从 Demo 或测试主菜单返回模式选择，并清理本局运行时状态。
func return_to_mode_select() -> void:
	trace("return_to_mode_select begin phase=%s" % _phase_name())
	_game_start_pending = false
	selected_mode = ""
	selected_faction = ""
	is_startup_flow_active = true
	goto_mode_select()
	call_deferred("_reset_runtime_after_scene_change")

# ────────────────────────────────────────────
# 场景跳转
# ────────────────────────────────────────────

func goto_splash() -> void:
	trace("goto_splash")
	_game_start_pending = false
	is_startup_flow_active = true
	_current_step = "splash"
	flow_changed.emit(_current_step)
	_request_scene_change(splash_scene)
	call_deferred("_nudge_window_to_front")

func goto_mode_select() -> void:
	trace("goto_mode_select")
	_game_start_pending = false
	is_startup_flow_active = true
	_current_step = "mode_select"
	flow_changed.emit(_current_step)
	_request_scene_change(mode_select_scene)
	call_deferred("_nudge_window_to_front")

func goto_faction_select() -> void:
	trace("goto_faction_select")
	_game_start_pending = false
	is_startup_flow_active = true
	_current_step = "faction_select"
	flow_changed.emit(_current_step)
	_request_scene_change(faction_select_scene)
	call_deferred("_nudge_window_to_front")

func goto_loading() -> void:
	trace("goto_loading mode=%s faction=%s" % [selected_mode, selected_faction])
	_game_start_pending = false
	is_startup_flow_active = true
	_current_step = "loading"
	flow_changed.emit(_current_step)
	_request_scene_change(loading_scene)
	call_deferred("_nudge_window_to_front")

func goto_game() -> void:
	trace("goto_game begin mode=%s faction=%s phase=%s" % [selected_mode, selected_faction, _phase_name()])
	_current_step = "game"
	is_startup_flow_active = false
	_game_start_pending = true
	flow_changed.emit(_current_step)
	_request_scene_change(game_scene)
	call_deferred("_nudge_window_to_front")
	call_deferred("_start_pending_game")

# ────────────────────────────────────────────
# 流程回调（由各场景调用）
# ────────────────────────────────────────────

## Splash 结束后调用
func on_splash_finished() -> void:
	trace("on_splash_finished")
	goto_mode_select()

## 模式选择完成后调用
func on_mode_selected(mode_id: String) -> void:
	trace("on_mode_selected mode=%s" % mode_id)
	selected_mode = mode_id
	DemoFlow.set_enabled(_is_demo_mode(mode_id) or mode_id == MODE_STRATEGY_HUB)
	DemoFlow.set_full_demo_enabled(mode_id == MODE_FULL_DEMO)
	DemoFlow.set_tutorial_enabled(mode_id == MODE_DEMO)
	if mode_id == MODE_FULL_DEMO:
		goto_faction_select()
		return
	if mode_id == MODE_DEMO:
		start_demo_game_direct(mode_id)
		return
	if mode_id == MODE_STRATEGY_HUB:
		goto_strategy_hub()
		return
	if mode_id == MODE_TEST_MENU:
		goto_test_menu()
		return
	goto_faction_select()

## 势力选择完成后调用
func on_faction_selected(faction_id: String) -> void:
	trace("on_faction_selected faction=%s" % faction_id)
	selected_faction = faction_id
	goto_loading()

## 加载完成后调用
func on_loading_finished() -> void:
	trace("on_loading_finished")
	goto_game()

# ────────────────────────────────────────────
# 内部
# ────────────────────────────────────────────

func _change_to_splash() -> void:
	_request_scene_change(splash_scene)

func _ensure_initial_scene() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		var path: String = current_scene.scene_file_path
		if path == splash_scene or path.begins_with("res://temp/"):
			trace("ensure_initial_scene skip current=%s" % path)
			return
	_request_scene_change(splash_scene)

func _request_scene_change(scene_path: String) -> void:
	trace("request_scene_change path=%s" % scene_path)
	call_deferred("_change_scene_deferred", scene_path)

func _change_scene_deferred(scene_path: String) -> void:
	trace("change_scene_deferred begin path=%s" % scene_path)
	var err: Error = get_tree().change_scene_to_file(scene_path)
	trace("change_scene_deferred end path=%s err=%s" % [scene_path, str(err)])

func _reset_runtime_after_scene_change() -> void:
	trace("reset_runtime_after_scene_change wait")
	await get_tree().process_frame
	trace("reset_runtime_after_scene_change begin phase=%s" % _phase_name())
	GameManager.reset()
	CityManager.reset()
	DiplomacySystem.reset()
	TechSystem.reset()
	TacticalSkirmishManager.reset_skirmish()
	DemoFlow.reset()
	selected_mode = ""
	selected_faction = ""
	is_startup_flow_active = true
	_game_start_pending = false
	trace("reset_runtime_after_scene_change end phase=%s" % _phase_name())

func should_main_auto_start_game() -> bool:
	return false

func is_game_start_pending() -> bool:
	return _game_start_pending

func _start_pending_game() -> void:
	trace("start_pending_game wait pending=%s phase=%s" % [str(_game_start_pending), _phase_name()])
	await get_tree().process_frame
	if not _game_start_pending:
		trace("start_pending_game canceled phase=%s" % _phase_name())
		return
	trace("start_pending_game begin phase=%s" % _phase_name())
	_start_game()
	_game_start_pending = false
	trace("start_pending_game end phase=%s" % _phase_name())

func _start_game() -> void:
	# 根据模式决定激活哪些势力
	var active_factions := _get_active_factions()
	trace("start_game active=%s player=%s phase=%s" % [str(active_factions), selected_faction, _phase_name()])
	GameManager.start_game(active_factions, selected_faction)
	trace("start_game done phase=%s current=%s" % [_phase_name(), GameManager.get_current_faction()])


func start_demo_game_direct(mode_id: String = MODE_FULL_DEMO) -> void:
	trace("start_demo_game_direct begin")
	_game_start_pending = false
	is_startup_flow_active = false
	selected_mode = mode_id
	if selected_faction == "":
		selected_faction = DemoFlow.get_player_faction_id()
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	DiplomacySystem.reset()
	TechSystem.reset()
	TacticalSkirmishManager.reset_skirmish()
	DemoFlow.reset()
	DemoFlow.set_enabled(mode_id == MODE_FULL_DEMO or mode_id == MODE_DEMO or mode_id == MODE_STRATEGY_HUB)
	DemoFlow.set_full_demo_enabled(mode_id == MODE_FULL_DEMO)
	DemoFlow.set_tutorial_enabled(mode_id == MODE_DEMO)
	GameManager.start_game(GameManager.FACTION_IDS, selected_faction)
	_request_scene_change(game_scene)
	call_deferred("_nudge_window_to_front")
	trace("start_demo_game_direct end phase=%s" % _phase_name())


func _handle_direct_launch_args() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var full_args: PackedStringArray = OS.get_cmdline_args()
	for arg: String in full_args:
		if not args.has(arg):
			args.append(arg)
	var has_full_demo_direct: bool = args.has("--demo-direct") or args.has("--full-demo-direct")
	var has_tutorial_direct: bool = args.has("--tutorial-direct") or args.has("--battle-demo-direct")
	if not has_full_demo_direct and not has_tutorial_direct:
		return false
	trace("handle_direct_launch_args demo-direct")
	is_startup_flow_active = false
	_game_start_pending = false
	if has_tutorial_direct:
		call_deferred("start_demo_game_direct", MODE_DEMO)
	else:
		call_deferred("start_demo_game_direct", MODE_FULL_DEMO)
	return true

func _get_active_factions() -> Array[String]:
	match selected_mode:
		"demo":
			return GameManager.FACTION_IDS.duplicate()
		"full_demo":
			return GameManager.FACTION_IDS.duplicate()
		"strategy_hub":
			return GameManager.FACTION_IDS.duplicate()
		"quick":
			# 快速模式：三国
			return ["qin", "zhao", "qi"]
		"story":
			# 剧情模式：全部
			return ["qin", "zhao", "qi", "chu", "wei", "yan", "han"]
		"sandbox":
			# 沙盒：全部（后续可配置）
			return ["qin", "zhao", "qi", "chu", "wei", "yan", "han"]
		_:
			# 经典模式：全部
			return ["qin", "zhao", "qi", "chu", "wei", "yan", "han"]


func _is_demo_mode(mode_id: String) -> bool:
	return mode_id == MODE_DEMO or mode_id == MODE_FULL_DEMO


func trace(message: String) -> void:
	var line: String = "[%d] %s" % [Time.get_ticks_msec(), message]
	if OS.has_feature("debug"):
		print("[StartupTrace] %s" % line)
	var file: FileAccess = FileAccess.open(TRACE_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(TRACE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
	file.close()


func _clear_trace() -> void:
	var file: FileAccess = FileAccess.open(TRACE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_line("=== startup trace begin ===")
	file.close()


func _nudge_window_to_front() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_request_attention()
	DisplayServer.window_move_to_foreground()


func _restore_window_if_offscreen() -> void:
	var current_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return
	var position: Vector2i = DisplayServer.window_get_position()
	var size: Vector2i = DisplayServer.window_get_size()
	if size.x <= 0 or size.y <= 0:
		return
	var display_size: Vector2i = DisplayServer.screen_get_size()
	if display_size.x <= 0 or display_size.y <= 0:
		return
	var min_visible_x: int = -size.x + 120
	var min_visible_y: int = -size.y + 120
	var max_visible_x: int = display_size.x - 120
	var max_visible_y: int = display_size.y - 120
	var is_offscreen: bool = (
		position.x < min_visible_x
		or position.y < min_visible_y
		or position.x > max_visible_x
		or position.y > max_visible_y
	)
	if not is_offscreen:
		return
	var safe_x: int = maxi((display_size.x - size.x) / 2, 40)
	var safe_y: int = maxi((display_size.y - size.y) / 2, 40)
	DisplayServer.window_set_position(Vector2i(safe_x, safe_y))
	trace("restore_window_if_offscreen from=%s to=%s" % [str(position), str(Vector2i(safe_x, safe_y))])


func _phase_name() -> String:
	return GameManager.Phase.keys()[GameManager.get_current_phase()]


func _should_show_mode_select() -> bool:
	return true
