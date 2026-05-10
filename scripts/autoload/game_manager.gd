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
var _player_horse: int = 0
var _player_refined_iron: int = 0

# AI 国家资源追踪（阶段2）
var _faction_resources: Dictionary = {}  # {faction_id: {food, gold, iron, morale, population, troops}}

# 难度系统（阶段2）
var _difficulty: String = "normal"

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
	_init_ai_factions()
	DiplomacySystem.initialize(active_factions)
	TechSystem.reset()
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


## AI 行动入口。阶段2：外交决策 + 经济简单tick。
func process_ai_turn() -> void:
	var faction_id := get_current_faction()
	# 1. AI经济决策（性格驱动建设）
	_ai_economy_tick(faction_id)
	# 2. AI外交决策（概率触发）
	DiplomacyAI.evaluate_diplomacy(faction_id, _turn_number)
	# 3. AI科技研究
	_ai_research_tick(faction_id)
	# 4. AI军事决策（暂留阶段1占位）
	end_current_turn()


func _ai_economy_tick(faction_id: String) -> void:
	var personality: Dictionary = DataManager.get_ai_personality(faction_id)
	var res: Dictionary = get_faction_resources(faction_id)
	if res.is_empty():
		return
	# 简单规则：好战型优先攒兵，保守型优先攒粮
	if personality.get("aggression", 2) >= 3:
		apply_faction_resource_delta(faction_id, "troops", 5)
	else:
		apply_faction_resource_delta(faction_id, "food", 20)
	# 基础产出
	apply_faction_resource_delta(faction_id, "gold", 10)
	apply_faction_resource_delta(faction_id, "iron", 5)


func _ai_research_tick(faction_id: String) -> void:
	var ai_techs: Dictionary = TechSystem.get_ai_researched_techs(faction_id)
	# 按时代优先，其次按成本从高到低
	var available: Array = []
	for tech in DataManager.get_all_techs():
		var tech_id: String = tech["id"]
		if ai_techs.has(tech_id):
			continue
		var can_research := true
		for prereq in tech.get("prerequisites", []):
			if not ai_techs.has(prereq):
				can_research = false
				break
		if can_research:
			available.append(tech)
	if available.is_empty():
		return
	# 排序：晚期 > 中期 > 早期，同时代按成本降序
	var era_priority := {"late": 3, "mid": 2, "early": 1}
	available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ea: int = era_priority.get(a.get("era", ""), 0)
		var eb: int = era_priority.get(b.get("era", ""), 0)
		if ea != eb:
			return ea > eb
		return a.get("cost_gold", 0) > b.get("cost_gold", 0)
	)
	TechSystem.start_ai_research(faction_id, available[0]["id"])


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


func get_player_horse() -> int:
	return _player_horse


func get_player_refined_iron() -> int:
	return _player_refined_iron


func apply_horse_delta(delta: int) -> void:
	_player_horse = max(0, _player_horse + delta)


func apply_refined_iron_delta(delta: int) -> void:
	_player_refined_iron = max(0, _player_refined_iron + delta)


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
	_player_horse = 0
	_player_refined_iron = 0
	_faction_resources.clear()
	_difficulty = "normal"


# ============= AI 国家资源管理 =============

func get_faction_resources(faction_id: String) -> Dictionary:
	if faction_id == _player_faction:
		return {"food": _player_food, "gold": _player_gold, "iron": _player_iron,
				"morale": _player_morale, "population": _player_population, "troops": _player_troops,
				"horse": _player_horse, "refined_iron": _player_refined_iron}
	return _faction_resources.get(faction_id, {})


func get_faction_resource(faction_id: String, resource: String) -> int:
	var res: Dictionary = get_faction_resources(faction_id)
	return res.get(resource, 0)


func apply_faction_resource_delta(faction_id: String, resource: String, delta: int) -> void:
	if faction_id == _player_faction:
		match resource:
			"food": apply_food_delta(delta)
			"gold": apply_gold_delta(delta)
			"iron": apply_iron_delta(delta)
			"morale": apply_morale_delta(delta)
			"population": apply_population_delta(delta)
			"troops": apply_troops_delta(delta)
			"horse": apply_horse_delta(delta)
			"refined_iron": apply_refined_iron_delta(delta)
		return
	if not _faction_resources.has(faction_id):
		return
	var res: Dictionary = _faction_resources[faction_id]
	if not res.has(resource):
		return
	if resource == "morale":
		res[resource] = clampi(res[resource] + delta, 0, 100)
	else:
		res[resource] = max(0, res[resource] + delta)


func get_difficulty() -> String:
	return _difficulty


func set_difficulty(difficulty: String) -> void:
	_difficulty = difficulty


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
		_player_horse = 0
		_player_refined_iron = 0
		return
	_player_population = capital.get("base_population", 10000)
	# 初始资源基于城市人口和基础产出
	_player_food = int(_player_population * DataManager.get_balance_param("resources.pop_food_rate") * 10)
	_player_gold = int(DataManager.get_balance_param("resources.city_base_gold") * 5)
	_player_iron = int(DataManager.get_balance_param("resources.city_base_iron") * 3)
	_player_troops = 0
	_player_horse = 0
	_player_refined_iron = 0


func _init_ai_factions() -> void:
	_faction_resources.clear()
	var diff_settings: Dictionary = DataManager.get_difficulty_settings(_difficulty)
	var gold_bonus: int = diff_settings.get("initial_gold_bonus", 0)
	var res_mod: float = diff_settings.get("resource_mod", 0.0)

	for fid in _active_factions:
		if fid == _player_faction:
			continue
		var capital: Dictionary = DataManager.get_capital(fid)
		var population: int = capital.get("base_population", 10000) if not capital.is_empty() else 10000
		var base_food: int = int(population * DataManager.get_balance_param("resources.pop_food_rate") * 10)
		var base_gold: int = int(DataManager.get_balance_param("resources.city_base_gold") * 5)
		var base_iron: int = int(DataManager.get_balance_param("resources.city_base_iron") * 3)
		# 应用难度修正
		_faction_resources[fid] = {
			"food": int(base_food * (1.0 + res_mod)),
			"gold": int(base_gold * (1.0 + res_mod)) + gold_bonus,
			"iron": int(base_iron * (1.0 + res_mod)),
			"morale": 50,
			"population": population,
			"troops": 0,
			"horse": 0,
			"refined_iron": 0
		}


func _change_phase(new_phase: Phase) -> void:
	var old_phase := _phase
	_phase = new_phase
	SignalBus.phase_changed.emit(old_phase, new_phase)
