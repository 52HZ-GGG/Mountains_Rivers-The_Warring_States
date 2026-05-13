extends Node
## 启动流程管理器
## 管理：Splash → 公告 → 模式选择 → 势力选择 → 加载 → 游戏
##
## 用法：设为 autoload（在 GameManager 之前），启动时自动进入 Splash。
## 其它场景通过 StartupFlow.goto_xxx() 推进流程。

signal flow_changed(step: String)

# 当前流程步骤
var _current_step: String = ""

# 玩家选择
var selected_mode: String = ""
var selected_faction: String = ""

# 启动配置
@export var splash_scene: String = "res://scenes/ui/splash/splash_screen.tscn"
@export var mode_select_scene: String = "res://scenes/ui/splash/mode_select.tscn"
@export var faction_select_scene: String = "res://scenes/ui/splash/faction_select.tscn"
@export var loading_scene: String = "res://scenes/ui/splash/loading_screen.tscn"
@export var game_scene: String = "res://scenes/main/main.tscn"

# 是否跳过 Splash（调试用）
@export var skip_splash: bool = false

func _ready() -> void:
	# 不自动跳转 — 由 main 场景或命令行触发
	pass

# ────────────────────────────────────────────
# 流程入口
# ────────────────────────────────────────────

## 从头开始完整启动流程
func start_full_flow() -> void:
	selected_mode = ""
	selected_faction = ""
	if skip_splash:
		goto_mode_select()
	else:
		goto_splash()

## 跳过所有前置流程，直接进入游戏（测试用）
func quick_start(faction_id: String, mode: String = "classic") -> void:
	selected_mode = mode
	selected_faction = faction_id
	_start_game()

# ────────────────────────────────────────────
# 场景跳转
# ────────────────────────────────────────────

func goto_splash() -> void:
	_current_step = "splash"
	flow_changed.emit(_current_step)
	get_tree().change_scene_to_file(splash_scene)

func goto_mode_select() -> void:
	_current_step = "mode_select"
	flow_changed.emit(_current_step)
	get_tree().change_scene_to_file(mode_select_scene)

func goto_faction_select() -> void:
	_current_step = "faction_select"
	flow_changed.emit(_current_step)
	get_tree().change_scene_to_file(faction_select_scene)

func goto_loading() -> void:
	_current_step = "loading"
	flow_changed.emit(_current_step)
	get_tree().change_scene_to_file(loading_scene)

func goto_game() -> void:
	_current_step = "game"
	flow_changed.emit(_current_step)
	_start_game()

# ────────────────────────────────────────────
# 流程回调（由各场景调用）
# ────────────────────────────────────────────

## Splash 结束后调用
func on_splash_finished() -> void:
	goto_mode_select()

## 模式选择完成后调用
func on_mode_selected(mode_id: String) -> void:
	selected_mode = mode_id
	goto_faction_select()

## 势力选择完成后调用
func on_faction_selected(faction_id: String) -> void:
	selected_faction = faction_id
	goto_loading()

## 加载完成后调用
func on_loading_finished() -> void:
	goto_game()

# ────────────────────────────────────────────
# 内部
# ────────────────────────────────────────────

func _start_game() -> void:
	# 根据模式决定激活哪些势力
	var active_factions := _get_active_factions()
	GameManager.start_game(active_factions, selected_faction)

func _get_active_factions() -> Array[String]:
	match selected_mode:
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
