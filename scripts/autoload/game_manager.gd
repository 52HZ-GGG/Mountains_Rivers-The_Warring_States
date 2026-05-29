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
var _player_wood: int = 0
var _player_morale: int = 50
var _player_population: int = 0
var _player_troops: int = 0
var _player_horse: int = 0
var _player_refined_iron: int = 0
var _player_craftsmen: int = 0
var _player_building_materials: int = 0

# 兵种构成追踪（Phase 3）: {faction_id: {unit_id: count}}
var _unit_composition: Dictionary = {}

# AI 国家资源追踪（阶段2）
var _faction_resources: Dictionary = {}  # {faction_id: {food, gold, wood, morale, population, troops, horse, refined_iron, craftsmen, building_materials}}

# 难度系统（阶段2）
var _difficulty: String = "normal"

# 税率系统（Phase 2）
var _tax_rate: float = 0.3  # 默认标准税率 30%

# 国家粮仓（Phase 2）
var _national_grain_pool: int = 0

# ============= 生命周期 =============

func _ready() -> void:
	print("[GameManager] 启动 — 阶段 1（回合循环就绪，等 start_game）")
	_log_data_loaded()
	SignalBus.revolt_occurred.connect(_on_revolt_occurred)


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


func get_player_faction() -> String:
	return _player_faction


# ============= 税率系统（Phase 2） =============

## 获取当前税率（0.1 ~ 0.5）。
func get_tax_rate() -> float:
	return _tax_rate


## 设置税率。rate 必须在 [tax.min_rate, tax.max_rate] 范围内。
## 返回 true 表示设置成功。
func set_tax_rate(rate: float) -> bool:
	var min_rate: float = float(DataManager.get_balance_param("tax.min_rate"))
	var max_rate: float = float(DataManager.get_balance_param("tax.max_rate"))
	if rate < min_rate or rate > max_rate:
		push_warning("GameManager: 税率 %.2f 超出范围 [%.2f, %.2f]" % [rate, min_rate, max_rate])
		return false
	_tax_rate = rate
	return true


## 获取国家粮仓当前存量。
func get_national_grain_pool() -> int:
	return _national_grain_pool


## 获取当前民心阈值效果。返回 {production_mod, recruit_mod, description}。
## 民心区间：80-100 产出+10% / 60-79 正常 / 40-59 产出-10% / 20-39 产出-25% / 0-19 叛乱
func get_morale_threshold_effect() -> Dictionary:
	var morale: int = _player_morale
	if morale >= 80:
		return {"production_mod": 1.1, "recruit_mod": 1.2, "description": "民心高昂"}
	elif morale >= 60:
		return {"production_mod": 1.0, "recruit_mod": 1.0, "description": "民心正常"}
	elif morale >= 40:
		return {"production_mod": 0.9, "recruit_mod": 1.0, "description": "民心低落"}
	elif morale >= 20:
		return {"production_mod": 0.75, "recruit_mod": 0.8, "description": "民心动荡"}
	else:
		return {"production_mod": 0.5, "recruit_mod": 0.5, "description": "叛乱风险"}


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
	# 首回合：季节民心修正 + 城市结算 + 资源产出 + 军队维护
	_apply_season_morale()
	var first_faction := get_current_faction()
	CityManager.process_turn(first_faction)
	_process_production(first_faction)
	_apply_upkeep(first_faction)
	SignalBus.turn_started.emit(_turn_number, first_faction)
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
	# 新一轮（季节切换）：应用季节民心修正
	if _faction_index == 0:
		_apply_season_morale()
	var new_faction := get_current_faction()
	# 回合开始：城市结算（建造队列+人口）→ 资源产出 → 军队维护
	CityManager.process_turn(new_faction)
	_process_production(new_faction)
	_apply_upkeep(new_faction)
	SignalBus.turn_started.emit(_turn_number, new_faction)
	_change_phase(Phase.ACTION)


## AI 行动入口：外交决策 → 科技研究 → 军事决策（征兵/攻城/驻军）。
func process_ai_turn() -> void:
	var faction_id := get_current_faction()
	# 1. AI外交决策
	DiplomacyAI.evaluate_diplomacy(faction_id, _turn_number)
	# 2. AI科技研究
	_ai_research_tick(faction_id)
	# 3. AI军事决策（征兵/攻城/驻军）
	MilitaryAI.evaluate_military(faction_id)
	end_current_turn()


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


# ============= 每回合资源产出 =============

## 计算并应用势力的每回合资源产出（建筑效果 + 季节修正 + 税率修正）。
func _process_production(faction_id: String) -> void:
	var total: Dictionary = CityManager.get_faction_total_production(faction_id)
	# 税率修正：金币产出按税率/默认税率比例调整
	var default_rate: float = float(DataManager.get_balance_param("tax.default_rate"))
	var tax_multiplier: float = _tax_rate / default_rate if default_rate > 0 else 1.0
	total["gold"] = int(total["gold"] * tax_multiplier)
	# 民心阈值修正（仅玩家）
	if faction_id == _player_faction:
		var effect: Dictionary = get_morale_threshold_effect()
		var prod_mod: float = effect["production_mod"]
		total["food"] = int(total["food"] * prod_mod)
		total["gold"] = int(total["gold"] * prod_mod)
		total["wood"] = int(total["wood"] * prod_mod)
	apply_faction_resource_delta(faction_id, "food", total["food"])
	apply_faction_resource_delta(faction_id, "gold", total["gold"])
	apply_faction_resource_delta(faction_id, "wood", total["wood"])
	apply_faction_resource_delta(faction_id, "horse", total.get("horse", 0))
	apply_faction_resource_delta(faction_id, "refined_iron", total.get("refined_iron", 0))
	apply_faction_resource_delta(faction_id, "craftsmen", total.get("craftsmen", 0))
	apply_faction_resource_delta(faction_id, "building_materials", total.get("building_materials", 0))
	# 国家粮仓：跟踪粮食净产出（cap 限制）
	if faction_id == _player_faction:
		var grain_cap: int = int(DataManager.get_balance_param("population.national_grain_cap_base"))
		_national_grain_pool = mini(_player_food, grain_cap)
	SignalBus.resources_produced.emit(faction_id, total)


## 扣除军队维护费（粮食 + 金币）。按兵种构成计算，无构成时回退 flat rate。
func _apply_upkeep(faction_id: String) -> void:
	var comp: Dictionary = _unit_composition.get(faction_id, {})
	var total_food_upkeep: int = 0
	var total_gold_upkeep: int = 0
	if not comp.is_empty():
		# 按兵种维护费
		for unit_id in comp:
			var count: int = int(comp[unit_id])
			if count <= 0:
				continue
			var unit_data: Dictionary = DataManager.get_unit_type(unit_id)
			if unit_data.is_empty():
				continue
			total_food_upkeep += count * int(unit_data.get("upkeep_food", 0))
			total_gold_upkeep += count * int(unit_data.get("upkeep_gold", 0))
	else:
		# 回退：flat rate（AI 未建立兵种构成时）
		var troops: int = get_faction_resource(faction_id, "troops")
		var food_per_troop: int = int(DataManager.get_balance_param("resources.army_upkeep_food_per_unit"))
		var gold_per_troop: int = int(DataManager.get_balance_param("resources.army_upkeep_gold_per_unit"))
		total_food_upkeep = troops * food_per_troop
		total_gold_upkeep = troops * gold_per_troop
	# 马匹维护（独立于兵种构成）
	var horse: int = get_faction_resource(faction_id, "horse")
	var food_per_horse: int = int(DataManager.get_balance_param("resources.horse_upkeep_food_per_unit"))
	total_food_upkeep += horse * food_per_horse
	if total_food_upkeep > 0:
		apply_faction_resource_delta(faction_id, "food", -total_food_upkeep)
	if total_gold_upkeep > 0:
		apply_faction_resource_delta(faction_id, "gold", -total_gold_upkeep)


## 季节 + 税率民心修正（每轮一次，国家级）。
## 季节：spring +5 / summer -5 / autumn +10 / winter -10
## 税率：查 morale.tax_morale_values（0.1→+15, 0.2→+5, 0.3→0, 0.4→-10, 0.5→-20）
func _apply_season_morale() -> void:
	# 季节修正
	var season: String = CityManager.get_current_season(_turn_number)
	var mods: Variant = DataManager.get_balance_param("morale.season_morale_mod")
	if mods is Dictionary:
		var delta: int = int((mods as Dictionary).get(season, 0))
		if delta != 0:
			apply_morale_delta(delta)
	# 税率修正
	var tax_morale: Variant = DataManager.get_balance_param("morale.tax_morale_values")
	if tax_morale is Dictionary:
		var rate_key: String = str(_tax_rate)
		var tax_delta: int = int((tax_morale as Dictionary).get(rate_key, 0))
		if tax_delta != 0:
			apply_morale_delta(tax_delta)


# ============= 胜利条件 =============

## 检查胜利。返回获胜方 faction_id 或空串。
## 规则（子任务 4）：
## - 唯一存活的 faction → 该 faction 获胜（征服胜利）
## - 玩家已被灭（0 城）但仍有多个 AI 存活 → 游戏对玩家结束，返第一个存活 AI 作为获胜方
## - 其它情况 → 返空串（游戏继续）
func check_victory() -> String:
	if _active_factions.is_empty():
		return ""

	var alive: Array[String] = []
	for fid in _active_factions:
		if not CityManager.is_faction_eliminated(fid):
			alive.append(fid)

	if alive.size() == 1:
		return alive[0]

	if _player_faction != "" and CityManager.is_faction_eliminated(_player_faction):
		return alive[0] if not alive.is_empty() else ""

	return ""


# ============= 叛乱处理 =============

## 叛乱信号处理器：城池翻中立 → 首都叛乱扣民心/AI迁都。
## 灭国检查由 end_current_turn → check_victory 自动处理。
func _on_revolt_occurred(city_id: String, _stability: int) -> void:
	var city: Dictionary = CityManager.get_city_state(city_id)
	var old_faction: String = city.get("current_faction_id", "")
	if old_faction == "" or old_faction == "neutral":
		return

	var result: Dictionary = CityManager.revoke_to_neutral(city_id)
	if not result.get("success", false):
		return

	# 首都叛乱：民心惩罚 + 首都丢失信号 + AI 迁都
	if city.get("is_capital", false):
		var penalty: int = int(DataManager.get_balance_param("stability.revolt.capital_revolt_morale_penalty"))
		apply_faction_resource_delta(old_faction, "morale", penalty)
		SignalBus.capital_lost.emit(old_faction, city_id)
		if old_faction != _player_faction:
			CityManager.relocate_ai_capital(old_faction)


# ============= 资源管理（EventManager 调用） =============

func get_player_morale() -> int:
	return _player_morale


func get_player_food() -> int:
	return _player_food


func get_player_gold() -> int:
	return _player_gold


func get_player_wood() -> int:
	return _player_wood


func get_player_population() -> int:
	return _player_population


func get_player_troops() -> int:
	return _player_troops


func apply_food_delta(delta: int) -> void:
	_player_food = max(0, _player_food + delta)


func apply_gold_delta(delta: int) -> void:
	_player_gold = max(0, _player_gold + delta)


func apply_wood_delta(delta: int) -> void:
	_player_wood = max(0, _player_wood + delta)


func apply_morale_delta(delta: int) -> void:
	_player_morale = clampi(_player_morale + delta, 0, 100)


func apply_population_delta(delta: int) -> void:
	_player_population = max(0, _player_population + delta)


func apply_troops_delta(delta: int) -> void:
	_player_troops = max(0, _player_troops + delta)


# ============= 兵种构成管理（Phase 3） =============

## 获取 faction 的兵种构成。返回 {unit_id: count}。
func get_unit_composition(faction_id: String) -> Dictionary:
	return _unit_composition.get(faction_id, {})


## 给 faction 添加指定兵种。自动同步 _player_troops（玩家侧）。
func add_units(faction_id: String, unit_id: String, count: int) -> void:
	if count <= 0:
		return
	if not _unit_composition.has(faction_id):
		_unit_composition[faction_id] = {}
	var comp: Dictionary = _unit_composition[faction_id]
	comp[unit_id] = int(comp.get(unit_id, 0)) + count
	if faction_id == _player_faction:
		_player_troops = _sum_composition(faction_id)


## 移除 faction 指定兵种。不会低于 0。
func remove_units(faction_id: String, unit_id: String, count: int) -> void:
	if not _unit_composition.has(faction_id):
		return
	var comp: Dictionary = _unit_composition[faction_id]
	if not comp.has(unit_id):
		return
	comp[unit_id] = max(0, int(comp[unit_id]) - count)
	if comp[unit_id] == 0:
		comp.erase(unit_id)
	if faction_id == _player_faction:
		_player_troops = _sum_composition(faction_id)


## 获取 faction 总兵力（从兵种构成求和）。
func get_total_troops(faction_id: String) -> int:
	return _sum_composition(faction_id)


func _sum_composition(faction_id: String) -> int:
	var total: int = 0
	for count in _unit_composition.get(faction_id, {}).values():
		total += int(count)
	return total


func get_player_horse() -> int:
	return _player_horse


func get_player_refined_iron() -> int:
	return _player_refined_iron


func apply_horse_delta(delta: int) -> void:
	_player_horse = max(0, _player_horse + delta)


func apply_refined_iron_delta(delta: int) -> void:
	_player_refined_iron = max(0, _player_refined_iron + delta)


func get_player_craftsmen() -> int:
	return _player_craftsmen


func apply_craftsmen_delta(delta: int) -> void:
	_player_craftsmen = max(0, _player_craftsmen + delta)


func get_player_building_materials() -> int:
	return _player_building_materials


func apply_building_materials_delta(delta: int) -> void:
	_player_building_materials = max(0, _player_building_materials + delta)


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
	_player_wood = 0
	_player_morale = 50
	_player_population = 0
	_player_troops = 0
	_player_horse = 0
	_player_refined_iron = 0
	_player_craftsmen = 0
	_player_building_materials = 0
	_faction_resources.clear()
	_unit_composition.clear()
	_difficulty = "normal"
	_tax_rate = 0.3
	_national_grain_pool = 0


# ============= AI 国家资源管理 =============

func get_faction_resources(faction_id: String) -> Dictionary:
	if faction_id == _player_faction:
		return {"food": _player_food, "gold": _player_gold, "wood": _player_wood,
				"morale": _player_morale, "population": _player_population, "troops": _player_troops,
				"horse": _player_horse, "refined_iron": _player_refined_iron,
				"craftsmen": _player_craftsmen, "building_materials": _player_building_materials}
	return _faction_resources.get(faction_id, {})


func get_faction_resource(faction_id: String, resource: String) -> int:
	var res: Dictionary = get_faction_resources(faction_id)
	return res.get(resource, 0)


func apply_faction_resource_delta(faction_id: String, resource: String, delta: int) -> void:
	if faction_id == _player_faction:
		match resource:
			"food": apply_food_delta(delta)
			"gold": apply_gold_delta(delta)
			"wood": apply_wood_delta(delta)
			"morale": apply_morale_delta(delta)
			"population": apply_population_delta(delta)
			"troops": apply_troops_delta(delta)
			"horse": apply_horse_delta(delta)
			"refined_iron": apply_refined_iron_delta(delta)
			"craftsmen": apply_craftsmen_delta(delta)
			"building_materials": apply_building_materials_delta(delta)
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
		_player_wood = 100
		_player_population = 10000
		_player_troops = 0
		_player_horse = 0
		_player_refined_iron = 0
		_player_craftsmen = 0
		_player_building_materials = 0
		return
	_player_population = capital.get("base_population", 10000)
	# 初始资源基于城市人口和基础产出（路径：population.food_per_pop / gold_per_pop）
	var food_pp: float = float(DataManager.get_balance_param("population.food_per_pop"))
	var gold_pp: float = float(DataManager.get_balance_param("population.gold_per_pop"))
	_player_food = int(_player_population * food_pp * 10)
	_player_gold = int(_player_population * gold_pp * 5)
	_player_wood = int(DataManager.get_balance_param("resources.city_base_wood") * 3)
	_player_troops = 0
	_player_horse = 0
	_player_refined_iron = 0
	_player_craftsmen = 0
	_player_building_materials = 0


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
		var ai_food_pp: float = float(DataManager.get_balance_param("population.food_per_pop"))
		var ai_gold_pp: float = float(DataManager.get_balance_param("population.gold_per_pop"))
		var base_food: int = int(population * ai_food_pp * 10)
		var base_gold: int = int(population * ai_gold_pp * 5)
		var base_wood: int = int(DataManager.get_balance_param("resources.city_base_wood") * 3)
		# 应用难度修正
		_faction_resources[fid] = {
			"food": int(base_food * (1.0 + res_mod)),
			"gold": int(base_gold * (1.0 + res_mod)) + gold_bonus,
			"wood": int(base_wood * (1.0 + res_mod)),
			"morale": 50,
			"population": population,
			"troops": 0,
			"horse": 0,
			"refined_iron": 0,
			"craftsmen": 0,
			"building_materials": 0
		}


func _change_phase(new_phase: Phase) -> void:
	var old_phase := _phase
	_phase = new_phase
	SignalBus.phase_changed.emit(old_phase, new_phase)
