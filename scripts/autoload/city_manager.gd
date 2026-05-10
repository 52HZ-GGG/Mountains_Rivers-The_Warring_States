extends Node

## 城市管理器（CityManager）
##
## 维护 50 城的运行时状态，提供查询、建造、升级、拆除、归属变更、回合结算等接口。
## 子任务 1：autoload 骨架 + 状态初始化 + 4 个查询接口。
## 子任务 2：建造校验 + start_build（含每国限建逻辑）。
## 子任务 3：升级（can_upgrade / start_upgrade）+ 拆除（demolish）+ 修复 can_build 槽位计算。
##
## 状态字段约定（见 docs/decisions/阶段1-策划任务决策记录.md 决策 43/44）：
## - 静态字段（来自 cities.json）：id / name / faction_id / hex_q / hex_r /
##   jurisdiction_radius / max_building_slots / special_resource /
##   is_capital / base_population
## - 运行时字段（本管理器维护）：
##   - current_faction_id: String — 当前占领者，初始 = faction_id
##   - buildings: Array — 已建建筑 [{building_id, level}]，初始 []
##   - build_queue: Array — 建造队列 [{building_id, turns_remaining}]，初始 []
##     注：升级与新建共用此队列（决策 - 升级队列共用 build_queue）。
##         回合结算时按「该城市 buildings 是否已包含 building_id」判断是新建还是升级。
##   - current_population: int — 当前人口，初始 = base_population
##
## 限建语义说明（决策 33/35 + 子任务 2 解读 B）：
## - buildings.json 的 max_national_count 字段名易误解为「全图」语义，
##   实际策划意图是「每国限建数」：每个 faction 持有该 building_id 的
##   总数（已建 + 在建）≤ max_national_count。无此字段表示不限建。
##
## 拆除返还语义（子任务 3 决策）：
## - 按当前难度查 data/diplomacy.json difficulty.<diff>.demolish_refund_ratio
## - easy 0.75 / normal 0.50 / hard 0.25 / hell 0.00
## - 返还基数：仅基础建造成本（cost_gold + cost_iron），不返还升级花费

# ============= 公开常量（拒绝原因） =============

const REASON_OK := "OK"
const REASON_INVALID_CITY := "INVALID_CITY"
const REASON_INVALID_BUILDING := "INVALID_BUILDING"
const REASON_ALREADY_BUILT := "ALREADY_BUILT"
const REASON_ALREADY_QUEUED := "ALREADY_QUEUED"
const REASON_SLOTS_FULL := "SLOTS_FULL"
const REASON_NATIONAL_CAP_REACHED := "NATIONAL_CAP_REACHED"
const REASON_INSUFFICIENT_RESOURCES := "INSUFFICIENT_RESOURCES"
const REASON_BUILDING_NOT_BUILT := "BUILDING_NOT_BUILT"
const REASON_MAX_LEVEL_REACHED := "MAX_LEVEL_REACHED"

# ============= 私有状态 =============

var _city_states: Dictionary = {}              # city_id (String) → city_state (Dictionary)
var _states_by_faction: Dictionary = {}        # faction_id (String) → Array of city_state

# ============= 生命周期 =============

func _ready() -> void:
	_initialize_states()
	_build_faction_index()
	print("[CityManager] 已初始化 %d 城" % _city_states.size())


# ============= 查询接口 =============

## 按 city_id 获取运行时状态。未知 ID 返回空字典并发 warning。
func get_city_state(city_id: String) -> Dictionary:
	if _city_states.has(city_id):
		return _city_states[city_id]
	push_warning("CityManager: 未找到城市 %s" % city_id)
	return {}


## 获取所有城市的运行时状态数组。
func get_all_city_states() -> Array:
	return _city_states.values()


## 获取指定 faction 当前持有的城市状态数组。包含 "neutral" 中立城市。
## 未知 faction_id 返回空数组（无 warning，便于循环调用）。
func get_faction_city_states(faction_id: String) -> Array:
	return _states_by_faction.get(faction_id, [])


## 获取指定 faction 的首都状态。未找到返回空字典并发 warning。
func get_capital_state(faction_id: String) -> Dictionary:
	for state in get_faction_city_states(faction_id):
		if state.get("is_capital", false):
			return state
	push_warning("CityManager: 未找到 %s 的首都" % faction_id)
	return {}


# ============= 建造接口 =============

## 校验是否能在 city_id 建造 building_id。
## 返回 {"allowed": bool, "reason": String}。reason 为 REASON_* 常量之一。
## 校验项（按顺序）：
##   1. city_id 合法（INVALID_CITY）
##   2. building_id 合法（INVALID_BUILDING）
##   3. 该城市未建过该建筑（ALREADY_BUILT）
##   4. 该城市建造队列中无该建筑（ALREADY_QUEUED）
##   5. 该城市槽位未满（SLOTS_FULL，仅算「新建」队列项，升级中的不占新槽）
##   6. 该 faction 该建筑总数 < max_national_count（NATIONAL_CAP_REACHED）
##   7. 玩家资源够（INSUFFICIENT_RESOURCES）
func can_build(city_id: String, building_id: String) -> Dictionary:
	if not _city_states.has(city_id):
		return {"allowed": false, "reason": REASON_INVALID_CITY}
	var building: Dictionary = DataManager.get_building(building_id)
	if building.is_empty():
		return {"allowed": false, "reason": REASON_INVALID_BUILDING}

	var city: Dictionary = _city_states[city_id]
	if _city_has_building(city, building_id):
		return {"allowed": false, "reason": REASON_ALREADY_BUILT}
	if _city_has_in_queue(city, building_id):
		return {"allowed": false, "reason": REASON_ALREADY_QUEUED}

	# 槽位计算：buildings + 仅「新建」队列项（升级中的项已经在 buildings 里，不重复占槽）
	var slots: int = int(city.get("max_building_slots", 0))
	var occupied: int = (city["buildings"] as Array).size() + _count_new_build_in_queue(city)
	if occupied >= slots:
		return {"allowed": false, "reason": REASON_SLOTS_FULL}

	# max_national_count = 每国限建数（决策 33/35 解读 B）
	var max_per_faction: Variant = building.get("max_national_count")
	if max_per_faction != null:
		var faction_id: String = city["current_faction_id"]
		var existing: int = _count_faction_building(faction_id, building_id)
		if existing >= int(max_per_faction):
			return {"allowed": false, "reason": REASON_NATIONAL_CAP_REACHED}

	var cost_gold: int = int(building.get("cost_gold", 0))
	var cost_iron: int = int(building.get("cost_iron", 0))
	if GameManager.get_player_gold() < cost_gold or GameManager.get_player_iron() < cost_iron:
		return {"allowed": false, "reason": REASON_INSUFFICIENT_RESOURCES}

	return {"allowed": true, "reason": REASON_OK}


## 开始在 city_id 建造 building_id。
## 校验通过 → 扣资源、加入建造队列、返回 true。
## 校验失败 → 不动任何状态、返回 false（建议先调 can_build 看 reason）。
func start_build(city_id: String, building_id: String) -> bool:
	var check: Dictionary = can_build(city_id, building_id)
	if not check["allowed"]:
		return false

	var building: Dictionary = DataManager.get_building(building_id)
	var cost_gold: int = int(building.get("cost_gold", 0))
	var cost_iron: int = int(building.get("cost_iron", 0))
	var build_turns: int = int(building.get("build_turns", 1))

	GameManager.apply_gold_delta(-cost_gold)
	GameManager.apply_iron_delta(-cost_iron)

	var city: Dictionary = _city_states[city_id]
	(city["build_queue"] as Array).append({
		"building_id": building_id,
		"turns_remaining": build_turns,
	})
	return true


# ============= 升级接口 =============

## 校验是否能在 city_id 升级 building_id（升 1 级）。
## 返回 {"allowed": bool, "reason": String}。
## 校验项（按顺序）：
##   1. city_id 合法（INVALID_CITY）
##   2. building_id 合法（INVALID_BUILDING）
##   3. 该建筑已建在该城市（BUILDING_NOT_BUILT）
##   4. 该建筑未在 build_queue（ALREADY_QUEUED；含升级队列中状态）
##   5. 当前等级 < max_level（MAX_LEVEL_REACHED）
##   6. 玩家资源够升级费用（INSUFFICIENT_RESOURCES）
## 注：升级不占新槽位、不增数量，故不校验 SLOTS_FULL 与 NATIONAL_CAP。
func can_upgrade(city_id: String, building_id: String) -> Dictionary:
	if not _city_states.has(city_id):
		return {"allowed": false, "reason": REASON_INVALID_CITY}
	var building: Dictionary = DataManager.get_building(building_id)
	if building.is_empty():
		return {"allowed": false, "reason": REASON_INVALID_BUILDING}

	var city: Dictionary = _city_states[city_id]
	var current_level: int = _city_building_level(city, building_id)
	if current_level == 0:
		return {"allowed": false, "reason": REASON_BUILDING_NOT_BUILT}
	if _city_has_in_queue(city, building_id):
		return {"allowed": false, "reason": REASON_ALREADY_QUEUED}

	var max_level: int = int(building.get("max_level", 1))
	if current_level >= max_level:
		return {"allowed": false, "reason": REASON_MAX_LEVEL_REACHED}

	var costs: Array = _calculate_upgrade_cost(building, current_level)
	if GameManager.get_player_gold() < int(costs[0]) or GameManager.get_player_iron() < int(costs[1]):
		return {"allowed": false, "reason": REASON_INSUFFICIENT_RESOURCES}

	return {"allowed": true, "reason": REASON_OK}


## 开始升级 city_id 的 building_id（升 1 级）。
## 升级费用 = base_cost × upgrade_cost_multiplier^current_level（决策 25）。
## 校验通过 → 扣升级费用、加入 build_queue、返回 true。
## 校验失败 → 不动任何状态、返回 false。
func start_upgrade(city_id: String, building_id: String) -> bool:
	var check: Dictionary = can_upgrade(city_id, building_id)
	if not check["allowed"]:
		return false

	var building: Dictionary = DataManager.get_building(building_id)
	var city: Dictionary = _city_states[city_id]
	var current_level: int = _city_building_level(city, building_id)
	var costs: Array = _calculate_upgrade_cost(building, current_level)
	var build_turns: int = int(building.get("build_turns", 1))

	GameManager.apply_gold_delta(-int(costs[0]))
	GameManager.apply_iron_delta(-int(costs[1]))

	(city["build_queue"] as Array).append({
		"building_id": building_id,
		"turns_remaining": build_turns,
	})
	return true


# ============= 拆除接口 =============

## 拆除 city_id 已建的 building_id。
## 按当前难度查 difficulty.<diff>.demolish_refund_ratio 返还基础建造成本：
##   easy 0.75 / normal 0.50 / hard 0.25 / hell 0.00（兜底 0.50）
## 返还基数：仅基础建造成本（cost_gold + cost_iron），不返还升级花费。
## 若该建筑同时在 build_queue（升级中），一并清除（不补偿升级费）。
## 仅拆已建建筑：未建（仅在队列中）的建筑请用 cancel_build（暂未实现）。
##
## 返回 true 表示拆除成功，false 表示参数非法或建筑未建。
func demolish(city_id: String, building_id: String) -> bool:
	if not _city_states.has(city_id):
		return false
	var city: Dictionary = _city_states[city_id]
	if not _city_has_building(city, building_id):
		return false

	# 计算并返还资源（防御性兜底，避免 difficulty 配置缺失时崩）
	var building: Dictionary = DataManager.get_building(building_id)
	if not building.is_empty():
		var diff: String = GameManager.get_difficulty()
		var settings: Dictionary = DataManager.get_difficulty_settings(diff)
		var ratio: float = float(settings.get("demolish_refund_ratio", 0.5))
		var refund_gold: int = int(round(float(building.get("cost_gold", 0)) * ratio))
		var refund_iron: int = int(round(float(building.get("cost_iron", 0)) * ratio))
		if refund_gold > 0:
			GameManager.apply_gold_delta(refund_gold)
		if refund_iron > 0:
			GameManager.apply_iron_delta(refund_iron)

	# 移除 buildings 中匹配项（倒序遍历安全删除）
	var buildings: Array = city["buildings"]
	for i in range(buildings.size() - 1, -1, -1):
		if buildings[i].get("building_id") == building_id:
			buildings.remove_at(i)

	# 清理 build_queue 中匹配项（含正在升级的）
	var queue: Array = city["build_queue"]
	for i in range(queue.size() - 1, -1, -1):
		if queue[i].get("building_id") == building_id:
			queue.remove_at(i)

	return true


# ============= 测试与重开 =============

## 重置到初始状态。供单元测试与「重新开局」使用。
func reset() -> void:
	_initialize_states()
	_build_faction_index()


# ============= 内部 =============

func _initialize_states() -> void:
	_city_states.clear()
	for city_data in DataManager.get_all_cities():
		var state: Dictionary = city_data.duplicate(true)
		state["current_faction_id"] = city_data["faction_id"]
		state["buildings"] = []
		state["build_queue"] = []
		state["current_population"] = int(city_data.get("base_population", 0))
		_city_states[city_data["id"]] = state


func _build_faction_index() -> void:
	_states_by_faction.clear()
	for city_id in _city_states:
		var state: Dictionary = _city_states[city_id]
		var fid: String = state["current_faction_id"]
		if not _states_by_faction.has(fid):
			_states_by_faction[fid] = []
		_states_by_faction[fid].append(state)


## 该城市的 buildings 是否已包含 building_id
func _city_has_building(city: Dictionary, building_id: String) -> bool:
	for entry in (city["buildings"] as Array):
		if entry.get("building_id") == building_id:
			return true
	return false


## 该城市的 build_queue 是否已包含 building_id
func _city_has_in_queue(city: Dictionary, building_id: String) -> bool:
	for entry in (city["build_queue"] as Array):
		if entry.get("building_id") == building_id:
			return true
	return false


## 该 faction 持有该 building_id 的总数（已建 + 在建）。
## 用于每国限建校验（决策 33/35 解读 B）。
func _count_faction_building(faction_id: String, building_id: String) -> int:
	var count := 0
	for state in get_faction_city_states(faction_id):
		if _city_has_building(state, building_id):
			count += 1
		if _city_has_in_queue(state, building_id):
			count += 1
	return count


## 该城市的 buildings 中该 building_id 的当前等级。0 表示未建。
func _city_building_level(city: Dictionary, building_id: String) -> int:
	for entry in (city["buildings"] as Array):
		if entry.get("building_id") == building_id:
			return int(entry.get("level", 0))
	return 0


## 升级到下一级的成本（基础成本 × multiplier^current_level）。
## 返回 [cost_gold, cost_iron]，已 round + int 化。
func _calculate_upgrade_cost(building: Dictionary, current_level: int) -> Array:
	var multiplier: float = float(building.get("upgrade_cost_multiplier", 1.5))
	var factor: float = pow(multiplier, current_level)
	var cost_gold: int = int(round(float(building.get("cost_gold", 0)) * factor))
	var cost_iron: int = int(round(float(building.get("cost_iron", 0)) * factor))
	return [cost_gold, cost_iron]


## 该城市 build_queue 中「新建」类型的项数（即 building_id 未在 buildings 中）。
## 用于槽位校验：升级中的项已经在 buildings 里，不重复占槽。
func _count_new_build_in_queue(city: Dictionary) -> int:
	var count := 0
	for entry in (city["build_queue"] as Array):
		if not _city_has_building(city, entry.get("building_id", "")):
			count += 1
	return count
