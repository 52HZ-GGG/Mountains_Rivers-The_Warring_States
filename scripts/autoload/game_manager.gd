extends Node

## 游戏主循环管理器
##
## 负责回合循环、游戏阶段切换、胜利条件判定。
## 状态机：GAME_INIT → TURN_START → ACTION → TURN_END → (循环) → GAME_OVER
## 阶段 1 草稿：状态机骨架就绪，AI 与胜利条件留 TODO 待 TDD 填充。

# ============= 枚举 =============

## 游戏阶段。每次切换都通过 SignalBus.phase_changed 广播。
enum Phase {
	GAME_INIT,    ## autoload 已就绪、数据加载完，等 start_game
	TURN_START,   ## 回合开始：产出/季节/事件触发（瞬态）
	ACTION,       ## 当前 faction 行动中（玩家等输入 / AI 跑逻辑）
	TURN_END,     ## 回合结束：清理、检查胜利、推进（瞬态）
	GAME_OVER,    ## 胜负已分
}

const FACTION_IDS: Array[String] = ["qin", "zhao", "qi", "chu", "wei", "yan", "han"]

# ============= 私有状态 =============

var _phase: Phase = Phase.GAME_INIT
var _turn_number: int = 0
var _active_factions: Array[String] = []
var _faction_index: int = 0
var _player_faction: String = ""

# 玩家资源状态（阶段1简化：单一资源池）
var _player_food: int = 0
var _player_gold: int = 0
var _player_iron: int = 0
var _player_morale: int = 50
var _player_population: int = 0
var _player_troops: int = 0

# ============= 生命周期 =============

func _ready() -> void:
	print("[GameManager] 启动 — 阶段 1（回合循环就绪，等 start_game）")
	_log_data_loaded()


func _log_data_loaded() -> void:
	var variant_count := 0
	for fid in FACTION_IDS:
		variant_count += DataManager.get_faction_variants(fid).size()

	print("[GameManager] 数据加载验证: %d 地形 / %d 基础兵种 / %d 国家变体 / %d 城市" % [
		DataManager.get_all_terrains().size(),
		DataManager.get_all_unit_types().size(),
		variant_count,
		DataManager.get_all_cities().size(),
	])

	var map_size: Vector2i = DataManager.get_map_size()
	print("[GameManager] 地图尺寸: %d × %d" % [map_size.x, map_size.y])


# ============= 状态查询 =============

func get_current_phase() -> Phase:
	return _phase


func get_current_turn() -> int:
	return _turn_number


func get_current_faction() -> String:
	if _active_factions.is_empty():
		return ""
	return _active_factions[_faction_index]


func is_player_faction(faction_id: String) -> bool:
	return faction_id == _player_faction


# ============= 状态转换 =============

## 开始游戏。active_factions 是激活的国家 ID 列表，player_faction 是人类玩家。
## 仅在 GAME_INIT 阶段可调用。
func start_game(active_factions: Array[String], player_faction: String) -> void:
	if _phase != Phase.GAME_INIT:
		push_warning("GameManager: start_game 只能在 GAME_INIT 阶段调用，当前 %s" % Phase.keys()[_phase])
		return
	if active_factions.is_empty():
		push_error("GameManager: active_factions 不能为空")
		return
	if not active_factions.has(player_faction):
		push_error("GameManager: player_faction %s 不在 active_factions 中" % player_faction)
		return

	_active_factions = active_factions.duplicate()
	_player_faction = player_faction
	_faction_index = 0
	_turn_number = 1
	_init_player_resources()
	_change_phase(Phase.TURN_START)
	SignalBus.turn_started.emit(_turn_number, get_current_faction())
	_change_phase(Phase.ACTION)


## 结束当前 faction 回合。玩家点「结束回合」或 AI 行动完毕调用。
## 仅在 ACTION 阶段可调用。
func end_current_turn() -> void:
	if _phase != Phase.ACTION:
		push_warning("GameManager: end_current_turn 必须在 ACTION 阶段调用")
		return

	var ending_faction := get_current_faction()
	_change_phase(Phase.TURN_END)
	SignalBus.turn_ended.emit(_turn_number, ending_faction)

	var winner := check_victory()
	if winner != "":
		_change_phase(Phase.GAME_OVER)
		SignalBus.game_over.emit(winner)
		return

	# 切到下一个 faction；轮到队首则推进回合数
	_faction_index += 1
	if _faction_index >= _active_factions.size():
		_faction_index = 0
		_turn_number += 1

	_change_phase(Phase.TURN_START)
	SignalBus.turn_started.emit(_turn_number, get_current_faction())
	_change_phase(Phase.ACTION)


## AI 行动入口。阶段 1 同步占位：直接结束回合。
func process_ai_turn() -> void:
	# TODO 阶段 1：实现简易 AI（随机选可移动单位 → 随机目标）
	end_current_turn()


# ============= 胜利条件 =============

## 检查胜利。返回获胜方 faction_id 或空串。
func check_victory() -> String:
	# TODO 阶段 1：实现「占领敌城即胜」
	# 依赖 CityManager（尚未实现），目前返回空串占位
	return ""


# ============= 资源管理（EventManager 调用） =============

func get_player_morale() -> int:
	return _player_morale


func get_player_food() -> int:
	return _player_food


func get_player_gold() -> int:
	return _player_gold


func get_player_iron() -> int:
	return _player_iron


func apply_food_delta(delta: int) -> void:
	_player_food = max(0, _player_food + delta)


func apply_gold_delta(delta: int) -> void:
	_player_gold = max(0, _player_gold + delta)


func apply_iron_delta(delta: int) -> void:
	_player_iron = max(0, _player_iron + delta)


func apply_morale_delta(delta: int) -> void:
	_player_morale = clampi(_player_morale + delta, 0, 100)


func apply_population_delta(delta: int) -> void:
	_player_population = max(0, _player_population + delta)


func apply_troops_delta(delta: int) -> void:
	_player_troops = max(0, _player_troops + delta)


# ============= 测试与重开 =============

## 重置到初始状态。供单元测试与「重新开局」使用。
func reset() -> void:
	_phase = Phase.GAME_INIT
	_turn_number = 0
	_active_factions = []
	_faction_index = 0
	_player_faction = ""
	_player_food = 0
	_player_gold = 0
	_player_iron = 0
	_player_morale = 50
	_player_population = 0
	_player_troops = 0


# ============= 内部 =============

func _init_player_resources() -> void:
	var capital: Dictionary = DataManager.get_capital(_player_faction)
	if capital.is_empty():
		push_warning("GameManager: 未找到玩家首都，使用默认资源")
		_player_food = 500
		_player_gold = 300
		_player_iron = 100
		_player_population = 10000
		_player_troops = 0
		return
	_player_population = capital.get("base_population", 10000)
	# 初始资源基于城市人口和基础产出
	_player_food = int(_player_population * DataManager.get_balance_param("resources.pop_food_rate") * 10)
	_player_gold = int(DataManager.get_balance_param("resources.city_base_gold") * 5)
	_player_iron = int(DataManager.get_balance_param("resources.city_base_iron") * 3)
	_player_troops = 0


func _change_phase(new_phase: Phase) -> void:
	var old_phase := _phase
	_phase = new_phase
	SignalBus.phase_changed.emit(old_phase, new_phase)
