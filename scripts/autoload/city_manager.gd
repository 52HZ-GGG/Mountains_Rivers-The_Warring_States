extends Node

## 城市管理器（CityManager）
##
## 维护 50 城的运行时状态，提供查询、建造、归属变更、回合结算等接口。
## 子任务 1：autoload 骨架 + 状态初始化 + 4 个查询接口。
##
## 状态字段约定（见 docs/decisions/阶段1-策划任务决策记录.md 决策 43/44）：
## - 静态字段（来自 cities.json）：id / name / faction_id / hex_q / hex_r /
##   jurisdiction_radius / max_building_slots / special_resource /
##   is_capital / base_population
## - 运行时字段（本管理器维护）：
##   - current_faction_id: String — 当前占领者，初始 = faction_id
##   - buildings: Array — 已建建筑 [{building_id, level}]，初始 []
##   - build_queue: Array — 建造队列，初始 []
##   - current_population: int — 当前人口，初始 = base_population

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
