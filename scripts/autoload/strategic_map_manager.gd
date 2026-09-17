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
const CtxBuilder := preload("res://scripts/systems/combat_ctx_builder.gd")
const MovementReach := preload("res://scripts/systems/movement_reach.gd")
const SiegeResolver := preload("res://scripts/systems/siege_resolver.gd")

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
	var unit: Dictionary = _get_unit_ref(unit_id)
	if unit.is_empty():
		return {}
	var start: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var mp: int = int(unit.get("mp", 0))
	if mp <= 0:
		return {}
	var unit_type_id: String = str(unit["unit_type_id"])
	var faction_id: String = str(unit["faction_id"])
	var moving_id: String = str(unit["id"])
	# 统一规范 §6：经 MovementReach（含 ZOC）
	return MovementReach.dijkstra_reachable(
		start,
		mp,
		unit_type_id,
		faction_id,
		_units.duplicate(),
		Vector2i(0, 0),
		Vector2i(99, 99),
		func(cell: Vector2i) -> bool:
			if cell == start:
				return false
			var occ: Dictionary = get_unit_at_axial(cell)
			return not occ.is_empty() and str(occ.get("id", "")) != moving_id,
		Callable(),
		func(col: int, row: int) -> String:
			return CityManager.get_big_map_terrain_id(col, row)
	)


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
	# 统一规范 §6：远程遮挡（高程差减射程）
	if range > 1:
		var a_off: Vector2i = HexLib.axial_to_offset_odd_r(a_pos.x, a_pos.y)
		var d_off: Vector2i = HexLib.axial_to_offset_odd_r(d_pos.x, d_pos.y)
		range = MovementReach.effective_range(a_off, d_off, range)
	if HexLib.hex_distance_hex(a_pos, d_pos) > range:
		return {"ok": false, "reason": "OUT_OF_RANGE"}
	var dmg: int = _compute_unit_damage(attacker, defender)
	defender["hp"] = int(defender["hp"]) - dmg
	var counter_dmg: int = 0
	# 反击（统一规范 §5）：防御方存活且为近战攻击时触发
	if int(defender["hp"]) > 0:
		counter_dmg = _compute_counter_damage(defender, attacker, a_pos, d_pos)
		if counter_dmg > 0:
			attacker["hp"] = int(attacker["hp"]) - counter_dmg
	attacker["acted"] = true
	attacker["mp"] = 0
	if int(defender["hp"]) <= 0:
		_remove_unit(str(defender["id"]))
	if int(attacker["hp"]) <= 0:
		_remove_unit(str(attacker["id"]))
	unit_attacked.emit(attacker_id, defender_id, dmg)
	units_changed.emit()
	return {"ok": true, "damage": dmg, "counter_damage": counter_dmg}


## 反击伤害：防御方近战回击攻击方（统一规范 §5.1）
func _compute_counter_damage(counter_attacker: Dictionary, counter_defender: Dictionary, atk_pos: Vector2i, def_pos: Vector2i) -> int:
	var ca_type: String = str(counter_attacker["unit_type_id"])
	var cd_type: String = str(counter_defender["unit_type_id"])
	# 主动远程攻击不触发反击
	if _combat.is_ranged_unit(str(counter_defender["unit_type_id"])):
		return 0
	if not _combat.should_trigger_counter(cd_type, true):
		return 0
	var atk_offset: Vector2i = HexLib.axial_to_offset_odd_r(atk_pos.x, atk_pos.y)
	var atk_terrain: String = CityManager.get_big_map_terrain_id(atk_offset.x, atk_offset.y)
	var season: String = CityManager.get_current_season(GameManager.get_current_turn())
	var ca_skills: Array = counter_attacker.get("skills", []) if counter_attacker.get("skills") is Array else []
	var c_atk_ctx: Dictionary = CtxBuilder.build_attack_ctx(
		str(counter_attacker["faction_id"]), ca_type, ca_skills, season
	)
	# 远程单位被近战反击时用 melee_attack
	var ca_udata: Dictionary = DataManager.get_unit_type(ca_type)
	if _combat.is_ranged_unit(ca_type) and ca_udata.has("melee_attack"):
		c_atk_ctx["override_attack"] = int(ca_udata["melee_attack"])
	var c_def_ctx: Dictionary = CtxBuilder.build_defense_ctx(
		str(counter_defender["faction_id"]), cd_type
	)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var result: Dictionary = _combat.compute_counter_attack(
		ca_type, cd_type, atk_terrain,
		int(counter_attacker.get("morale", 100)),
		int(counter_defender.get("morale", 100)),
		rng, c_atk_ctx, c_def_ctx
	)
	return maxi(0, int(result.get("damage", 0)))


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
	# 统一规范 §7：经 SiegeResolver（墙分流 + 器械倍率 + ctx）
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var siege_result: Dictionary = SiegeResolver.compute_city_attack(unit, city_id, rng)
	var dmg: int = int(siege_result.get("damage", 0))
	var counter_dmg: int = 0
	if not bool(siege_result.get("city_destroyed", false)):
		counter_dmg = SiegeResolver.city_counter_damage(city_id, unit, rng)
		if counter_dmg > 0:
			unit["hp"] = int(unit.get("hp", 0)) - counter_dmg
	unit["acted"] = true
	unit["mp"] = 0
	var destroyed: bool = bool(siege_result.get("city_destroyed", false))
	if destroyed:
		var captor: String = str(unit["faction_id"])
		CityManager.change_ownership(city_id, captor)
		MinisterManager.try_acquire_military_minister(captor)
	if int(unit.get("hp", 0)) <= 0:
		_remove_unit(str(unit["id"]))
	city_sieged.emit(city_id, unit_id, dmg)
	units_changed.emit()
	return {
		"ok": true,
		"damage": dmg,
		"wall_damage": int(siege_result.get("wall_damage", 0)),
		"city_damage": int(siege_result.get("city_damage", dmg)),
		"counter_damage": counter_dmg,
		"destroyed": destroyed,
	}


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
	var season: String = CityManager.get_current_season(GameManager.get_current_turn())
	var a_skills: Array = attacker.get("skills", []) if attacker.get("skills") is Array else []
	# 统一规范 §4：经 CtxBuilder 组装修正
	var atk_ctx: Dictionary = CtxBuilder.build_attack_ctx(
		str(attacker["faction_id"]), a_type_id, a_skills, season
	)
	var def_ctx: Dictionary = CtxBuilder.build_defense_ctx(
		str(defender["faction_id"]), d_type_id
	)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var result: Dictionary = _combat.compute_damage(
		a_type_id,
		d_type_id,
		d_terrain_id,
		int(attacker.get("morale", 100)),
		int(defender.get("morale", 100)),
		rng,
		atk_ctx,
		def_ctx
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
