extends Node

## 大地图战略单位系统。
## 单位从城市生产后出现在大地图六角格上；移动/战斗/攻城均在大地图完成（无独立演武场景）。
## 坐标与城市一致：odd-R 偏移 (col=q, row=r)，邻接/距离用轴向转换。

signal units_changed
signal unit_moved(unit_id: String, from: Vector2i, to: Vector2i)
signal unit_attacked(attacker_id: String, defender_id: String, damage: int)
signal city_sieged(city_id: String, attacker_id: String, damage: int)

const HexLib := preload("res://scripts/systems/hex_axial.gd")
const CombatLib := preload("res://scripts/systems/combat_resolver.gd")
const UnitStateLib := preload("res://scripts/systems/unit_state.gd")

var _units: Array[Dictionary] = []
var _next_unit_seq: int = 1
var _selected_unit_id: String = ""
var _combat: RefCounted = CombatLib.new()


func _ready() -> void:
	SignalBus.turn_started.connect(_on_turn_started)


func reset() -> void:
	_units.clear()
	_next_unit_seq = 1
	_selected_unit_id = ""
	units_changed.emit()


func _on_turn_started(_turn_number: int, faction_id: String) -> void:
	begin_faction_turn(faction_id)


func begin_faction_turn(faction_id: String) -> void:
	for u: Dictionary in _units:
		if str(u["faction_id"]) != faction_id:
			continue
		u["acted"] = false
		u["mp"] = int(u["max_mp"])
	units_changed.emit()


# ============= 查询 =============

func get_units() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u: Dictionary in _units:
		out.append(u.duplicate(true))
	return out


func get_unit(unit_id: String) -> Dictionary:
	for u: Dictionary in _units:
		if str(u["id"]) == unit_id:
			return u.duplicate(true)
	return {}


func get_unit_at_offset(col: int, row: int) -> Dictionary:
	var axial: Vector2i = HexLib.offset_odd_r_to_axial(col, row)
	return get_unit_at_axial(axial)


func get_unit_at_axial(axial: Vector2i) -> Dictionary:
	for u: Dictionary in _units:
		if int(u["q"]) == axial.x and int(u["r"]) == axial.y:
			return u.duplicate(true)
	return {}


func get_faction_units(faction_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u: Dictionary in _units:
		if str(u["faction_id"]) == faction_id:
			out.append(u.duplicate(true))
	return out


func get_selected_unit_id() -> String:
	return _selected_unit_id


func select_unit(unit_id: String) -> void:
	_selected_unit_id = unit_id
	units_changed.emit()


func clear_selection() -> void:
	_selected_unit_id = ""
	units_changed.emit()


# ============= 生产 =============

## 在城市格生产一队战略单位。col/row 为 odd-R 偏移。
func spawn_unit_at_city(faction_id: String, unit_type_id: String, col: int, row: int, count: int = 1) -> Dictionary:
	var type_data: Dictionary = DataManager.get_unit_type(unit_type_id)
	if type_data.is_empty():
		return {"success": false, "reason": "INVALID_UNIT", "unit_id": ""}
	var hp: int = int(type_data.get("hp", 100)) * maxi(1, count)
	var speed: int = int(type_data.get("speed", 3))
	var unit_id: String = "su_%d_%s_%s" % [_next_unit_seq, faction_id, unit_type_id]
	_next_unit_seq += 1
	var axial: Vector2i = HexLib.offset_odd_r_to_axial(col, row)
	var skills: Array = DataManager.get_unit_skills(faction_id, unit_type_id)
	var unit: Dictionary = UnitStateLib.make(
		faction_id, unit_type_id, axial.x, axial.y, hp, speed, count, unit_id, col, row, skills
	)
	_units.append(unit)
	units_changed.emit()
	return {"success": true, "unit_id": unit_id}


# ============= 移动 =============

func get_reachable_cells(unit_id: String) -> Dictionary:
	var result: Dictionary = {}
	var unit: Dictionary = _get_unit_ref(unit_id)
	if unit.is_empty():
		return result
	var start: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var mp: int = int(unit.get("mp", 0))
	if mp <= 0:
		return result
	var frontier: Array = [{"cell": start, "cost": 0}]
	var best: Dictionary = {start: 0}
	while not frontier.is_empty():
		frontier.sort_custom(func(a, b) -> bool:
			return int((a as Dictionary).get("cost", 0)) < int((b as Dictionary).get("cost", 0)))
		var node: Variant = frontier.pop_front()
		if not (node is Dictionary):
			continue
		var node_dict: Dictionary = node as Dictionary
		var cell: Vector2i = node_dict["cell"] as Vector2i
		var cost: int = int(node_dict.get("cost", 0))
		if cost > mp:
			continue
		for neighbor: Vector2i in HexLib.neighbors_hex(cell):
			var occ: Dictionary = get_unit_at_axial(neighbor)
			if not occ.is_empty():
				continue
			var offset: Vector2i = HexLib.axial_to_offset_odd_r(neighbor.x, neighbor.y)
			var terrain_id: String = CityManager.get_big_map_terrain_id(offset.x, offset.y)
			var terrain: Dictionary = DataManager.get_terrain(terrain_id)
			var move_cost: int = int(terrain.get("move_cost", 1))
			if move_cost < 0:
				continue
			# 骑兵禁入山地等：cavalry_allowed=false
			var category: String = str(DataManager.get_unit_type(str(unit["unit_type_id"])).get("category", ""))
			if category == "cavalry" and not bool(terrain.get("cavalry_allowed", true)):
				continue
			var new_cost: int = cost + maxi(1, move_cost)
			if new_cost > mp:
				continue
			if best.has(neighbor) and int(best[neighbor]) <= new_cost:
				continue
			best[neighbor] = new_cost
			frontier.append({"cell": neighbor, "cost": new_cost})
	for cell: Vector2i in best:
		if cell == start:
			continue
		result[cell] = int(best[cell])
	return result


func try_move_unit(unit_id: String, dest_axial: Vector2i, allow_ai: bool = false) -> Dictionary:
	var unit: Dictionary = _get_unit_ref(unit_id)
	if unit.is_empty():
		return {"ok": false, "reason": "NO_UNIT"}
	if not allow_ai and str(unit["faction_id"]) != GameManager.get_player_faction():
		return {"ok": false, "reason": "NOT_PLAYER"}
	if bool(unit.get("acted", false)):
		return {"ok": false, "reason": "ALREADY_ACTED"}
	var reach: Dictionary = get_reachable_cells(unit_id)
	if not reach.has(dest_axial):
		return {"ok": false, "reason": "UNREACHABLE"}
	return _apply_move(unit, dest_axial, int(reach[dest_axial]))


func _apply_move(unit: Dictionary, dest_axial: Vector2i, cost: int) -> Dictionary:
	var unit_id: String = str(unit["id"])
	var from: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	unit["q"] = dest_axial.x
	unit["r"] = dest_axial.y
	var offset: Vector2i = HexLib.axial_to_offset_odd_r(dest_axial.x, dest_axial.y)
	unit["col"] = offset.x
	unit["row"] = offset.y
	unit["mp"] = int(unit.get("mp", 0)) - cost
	if int(unit["mp"]) < 0:
		unit["mp"] = 0
	# 仍有移动力可继续行动
	unit["acted"] = false
	# 移动到敌城且城防为 0 → 占领
	var city_id: String = _city_id_at_offset(offset.x, offset.y)
	if city_id != "":
		_try_capture_city_if_clear(str(unit["faction_id"]), city_id)
	unit_moved.emit(unit_id, from, dest_axial)
	units_changed.emit()
	return {"ok": true}


## 一步移动到目标方向最近可达格（供 AI 用）。
func move_toward(unit_id: String, target_axial: Vector2i) -> Dictionary:
	var unit: Dictionary = _get_unit_ref(unit_id)
	if unit.is_empty() or bool(unit.get("acted", false)):
		return {"ok": false, "reason": "NO_ACTION"}
	var reach: Dictionary = get_reachable_cells(unit_id)
	if reach.is_empty():
		return {"ok": false, "reason": "NO_REACH"}
	var best_cell: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var best_dist: int = HexLib.hex_distance_hex(best_cell, target_axial)
	var best_cost: int = 0
	for cell: Vector2i in reach:
		var dist: int = HexLib.hex_distance_hex(cell, target_axial)
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
			best_cost = int(reach[cell])
	if best_cell == Vector2i(int(unit["q"]), int(unit["r"])):
		return {"ok": false, "reason": "NO_CLOSER"}
	return _apply_move(unit, best_cell, best_cost)


# ============= 战斗 =============

func try_attack_unit(attacker_id: String, defender_id: String) -> Dictionary:
	var attacker: Dictionary = _get_unit_ref(attacker_id)
	var defender: Dictionary = _get_unit_ref(defender_id)
	if attacker.is_empty() or defender.is_empty():
		return {"ok": false, "reason": "NO_UNIT"}
	if str(attacker["faction_id"]) == str(defender["faction_id"]):
		return {"ok": false, "reason": "SAME_FACTION"}
	# 决策 #89：未宣战禁止交互
	if not DiplomacySystem.are_at_war(str(attacker["faction_id"]), str(defender["faction_id"])):
		return {"ok": false, "reason": "NOT_AT_WAR"}
	if bool(attacker.get("acted", false)):
		return {"ok": false, "reason": "ALREADY_ACTED"}
	var a_pos: Vector2i = Vector2i(int(attacker["q"]), int(attacker["r"]))
	var d_pos: Vector2i = Vector2i(int(defender["q"]), int(defender["r"]))
	var a_type: Dictionary = DataManager.get_unit_type(str(attacker["unit_type_id"]))
	var range: int = int(a_type.get("range", 1))
	if HexLib.hex_distance_hex(a_pos, d_pos) > range:
		return {"ok": false, "reason": "OUT_OF_RANGE"}
	var dmg: int = _compute_unit_damage(attacker, defender)
	defender["hp"] = int(defender["hp"]) - dmg
	attacker["acted"] = true
	attacker["mp"] = 0
	if int(defender["hp"]) <= 0:
		_remove_unit(str(defender["id"]))
	unit_attacked.emit(attacker_id, defender_id, dmg)
	units_changed.emit()
	return {"ok": true, "damage": dmg}


func try_attack_city(unit_id: String, city_id: String) -> Dictionary:
	var unit: Dictionary = _get_unit_ref(unit_id)
	if unit.is_empty():
		return {"ok": false, "reason": "NO_UNIT"}
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return {"ok": false, "reason": "NO_CITY"}
	if str(city.get("current_faction_id", "")) == str(unit["faction_id"]):
		return {"ok": false, "reason": "OWN_CITY"}
	# 决策 #89：未宣战禁止攻城（中立城除外）
	var city_owner: String = str(city.get("current_faction_id", ""))
	if city_owner != "neutral" and city_owner != "":
		if not DiplomacySystem.are_at_war(str(unit["faction_id"]), city_owner):
			return {"ok": false, "reason": "NOT_AT_WAR"}
	if bool(unit.get("acted", false)):
		return {"ok": false, "reason": "ALREADY_ACTED"}
	var u_pos: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var c_pos: Vector2i = HexLib.offset_odd_r_to_axial(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
	var a_type: Dictionary = DataManager.get_unit_type(str(unit["unit_type_id"]))
	var range: int = int(a_type.get("range", 1))
	if HexLib.hex_distance_hex(u_pos, c_pos) > range:
		return {"ok": false, "reason": "OUT_OF_RANGE"}
	var atk: int = int(a_type.get("attack", 10))
	var siege_mult: float = 1.0
	if str(a_type.get("category", "")) == "siege":
		siege_mult = float(DataManager.get_balance_param("city_combat.siege_damage_multiplier"))
	var city_def: float = float(CityManager.get_city_defense(city_id))
	var coeff: float = 20.0
	var dmg: int = maxi(1, int(float(atk) * siege_mult * coeff / (coeff + maxf(city_def, 0.0))))
	var result: Dictionary = CityManager.damage_city(city_id, dmg)
	unit["acted"] = true
	unit["mp"] = 0
	if bool(result.get("destroyed", false)):
		var captor: String = str(unit["faction_id"])
		CityManager.change_ownership(city_id, captor)
		# 占城胜利有机会招募武大夫
		MinisterManager.try_acquire_military_minister(captor)
	city_sieged.emit(city_id, unit_id, dmg)
	units_changed.emit()
	return {"ok": true, "damage": dmg, "destroyed": bool(result.get("destroyed", false))}


func _city_id_at_offset(col: int, row: int) -> String:
	for city in CityManager.get_all_city_states():
		if int(city.get("hex_q", -1)) == col and int(city.get("hex_r", -1)) == row:
			return str(city.get("id", ""))
	return ""


func _compute_unit_damage(attacker: Dictionary, defender: Dictionary) -> int:
	var a_type_id: String = str(attacker["unit_type_id"])
	var d_type_id: String = str(defender["unit_type_id"])
	var d_offset: Vector2i = HexLib.axial_to_offset_odd_r(int(defender["q"]), int(defender["r"]))
	var d_terrain_id: String = CityManager.get_big_map_terrain_id(d_offset.x, d_offset.y)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var result: Dictionary = _combat.compute_damage(
		a_type_id,
		d_type_id,
		d_terrain_id,
		int(attacker.get("morale", 100)),
		int(defender.get("morale", 100)),
		rng
	)
	return maxi(1, int(result.get("damage", 1)))


func _try_capture_city_if_clear(faction_id: String, city_id: String) -> void:
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return
	if str(city.get("current_faction_id", "")) == faction_id:
		return
	if int(city.get("current_hp", 0)) > 0:
		return
	CityManager.change_ownership(city_id, faction_id)
	MinisterManager.try_acquire_military_minister(faction_id)


## 公开：城防归零时尝试占城（供测试与 AI 调用）
func try_capture_city_if_clear(faction_id: String, city_id: String) -> void:
	_try_capture_city_if_clear(faction_id, city_id)


func _get_unit_ref(unit_id: String) -> Dictionary:
	for u: Dictionary in _units:
		if str(u["id"]) == unit_id:
			return u
	return {}


func _remove_unit(unit_id: String) -> void:
	for i in range(_units.size() - 1, -1, -1):
		if str((_units[i] as Dictionary).get("id", "")) == unit_id:
			_units.remove_at(i)
	if _selected_unit_id == unit_id:
		_selected_unit_id = ""


# ============= 存档 =============

func get_save_data() -> Dictionary:
	return {
		"units": _units.duplicate(true),
		"next_unit_seq": _next_unit_seq,
	}


func load_save_data(data: Dictionary) -> void:
	_units.clear()
	var raw: Variant = data.get("units", [])
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				_units.append(UnitStateLib.normalize((item as Dictionary).duplicate(true)))
	_next_unit_seq = int(data.get("next_unit_seq", _units.size() + 1))
	_selected_unit_id = ""
	units_changed.emit()
