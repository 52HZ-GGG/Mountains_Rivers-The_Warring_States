extends Node

## 阶段1战术演武 — 六角移动 + 战斗结算 + 占领城格（策划案 §5 最小可玩）
## 数据：data/tactical_skirmish_mvp.json

const HexLib := preload("res://scripts/systems/hex_axial.gd")
const CombatLib := preload("res://scripts/systems/combat_resolver.gd")
const AILib := preload("res://scripts/systems/skirmish_ai.gd")
const AttackPipelineLib := preload("res://scripts/systems/skirmish_attack_pipeline.gd")
const MoveLib := preload("res://scripts/systems/movement_reach.gd")
const BuildingFxLib := preload("res://scripts/systems/building_combat_effects.gd")
const UnitStateLib := preload("res://scripts/systems/unit_state.gd")
var _combat_resolver: RefCounted = CombatLib.new()
var _ai: AILib = AILib.new()
var _attack: AttackPipelineLib = AttackPipelineLib.new()

signal log_appended(line: String)
signal state_changed()
signal skirmish_ended(winner_faction_id: String)
signal combat_effect_requested(effect_id: String, cell: Vector2i, attacker_cell: Vector2i)
signal campaign_writeback_applied(report: Dictionary)

const BIG_MOVE: int = 999999

var _cfg: Dictionary = {}
var _tiles: Dictionary = {} # Vector2i -> terrain_id
var _all_cells: Array[Vector2i] = []
var _units: Array[Dictionary] = []
var _player_faction: String = ""
var _enemy_faction: String = ""
var _player_city: Vector2i = Vector2i.ZERO
var _enemy_city: Vector2i = Vector2i.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _skirmish_active: bool = false
var _current_season: String = "summer"
# 关隘状态：cell → HP / owner / 被攻击标记
var _pass_hp: Dictionary = {}   # Vector2i → int
var _pass_owner: Dictionary = {} # Vector2i → String ("" = 无主)
var _pass_attacked: Dictionary = {} # Vector2i → bool
# 城防状态：cell → 城墙 HP / 最大 HP / 等级 / 被攻击标记 / 箭塔 HP
var _city_wall_hp: Dictionary = {}     # Vector2i → int
var _city_wall_max_hp: Dictionary = {} # Vector2i → int
var _city_buildings: Dictionary = {}   # Vector2i → Array（建筑效果，经营/场景）
var _city_body_hp: Dictionary = {}     # Vector2i → int（城市本体，独立于城墙）
var _city_body_max_hp: Dictionary = {} # Vector2i → int
var _city_level: Dictionary = {}       # Vector2i → int (1-5)
var _city_attacked: Dictionary = {}    # Vector2i → bool
var _city_tower_hp: Dictionary = {}    # Vector2i → int（箭塔 HP，0 = 无箭塔）
var _demo_attack_multiplier: float = 1.0
## 演武就是战役：结算默认写入战役（CityManager + 战役自动存档）
var _campaign_writeback: bool = true
## AI 档位：scored/tutorial/random（统一规范 §8；场景 JSON 可覆盖）
var ai_mode: String = "scored"


func _ready() -> void:
	_rng.randomize()
	_ai.initialize(self)
	_attack.initialize(self)


func set_campaign_writeback(enabled: bool) -> void:
	_campaign_writeback = enabled


func is_campaign_writeback_enabled() -> bool:
	return _campaign_writeback


## 演武结算写入战役（策划定稿：演武结果=战役结果）
## - 场景 city_id 绑定的城：墙 HP / 城体 HP 同步到 CityManager
## - 胜方占领对方据点城（change_ownership）
## - 写回后触发战役自动存档（SaveManager）
func apply_result_to_campaign(winner: String) -> Dictionary:
	var report: Dictionary = {
		"ok": true,
		"winner": winner,
		"cities": [],
		"captured": [],
	}
	if _cfg.is_empty():
		report["ok"] = false
		report["reason"] = "NO_CONFIG"
		return report
	var pairs: Array = [
		{"key": "player_city", "cell": _player_city, "faction": _player_faction},
		{"key": "enemy_city", "cell": _enemy_city, "faction": _enemy_faction},
	]
	for pair: Variant in pairs:
		var p: Dictionary = pair as Dictionary
		var ccfg: Dictionary = _cfg.get(str(p["key"]), {}) as Dictionary
		var city_id: String = str(ccfg.get("city_id", ""))
		if city_id.is_empty() or not CityManager.has_method("get_city_state"):
			continue
		if CityManager.get_city_state(city_id).is_empty():
			continue
		var cell: Vector2i = p["cell"] as Vector2i
		var wall_now: int = int(_city_wall_hp.get(cell, -1))
		var body_now: int = int(_city_body_hp.get(cell, -1))
		if wall_now >= 0 and CityManager.has_method("set_wall_hp"):
			CityManager.set_wall_hp(city_id, wall_now)
		if body_now >= 0 and CityManager.has_method("set_city_hp"):
			CityManager.set_city_hp(city_id, body_now)
		var city_rec: Dictionary = {
			"city_id": city_id,
			"wall_hp": wall_now,
			"body_hp": body_now,
			"owner_before": str(CityManager.get_city_state(city_id).get("current_faction_id", "")),
		}
		(report["cities"] as Array).append(city_rec)
	# 占城：胜方获得对方据点对应战役城
	var capture_target_key: String = "enemy_city" if winner == _player_faction else "player_city"
	if winner != "" and winner != _player_faction and winner != _enemy_faction:
		capture_target_key = ""
	if capture_target_key != "":
		var tcfg: Dictionary = _cfg.get(capture_target_key, {}) as Dictionary
		var tid: String = str(tcfg.get("city_id", ""))
		if not tid.is_empty() and CityManager.has_method("change_ownership"):
			var tstate: Dictionary = CityManager.get_city_state(tid)
			if not tstate.is_empty():
				var before: String = str(tstate.get("current_faction_id", ""))
				if before != winner:
					if CityManager.change_ownership(tid, winner):
						(report["captured"] as Array).append({"city_id": tid, "from": before, "to": winner})
						_append_log("战役写回：%s 归属 %s → %s" % [tid, before, winner])
	if SaveManager.has_method("save_to_slot"):
		var auto_res: Dictionary = SaveManager.save_to_slot(SaveManager.AUTO_SLOT)
		report["campaign_autosave"] = bool(auto_res.get("success", false))
	campaign_writeback_applied.emit(report)
	return report


func _debug_log(message: String) -> void:
	if OS.has_feature("debug"):
		print(message)


func is_active() -> bool:
	return _skirmish_active


func set_season(season: String) -> void:
	_current_season = season


func get_player_faction() -> String:
	return _player_faction


func get_enemy_faction() -> String:
	return _enemy_faction


func get_player_city() -> Vector2i:
	return _player_city


func get_enemy_city() -> Vector2i:
	return _enemy_city


func set_demo_attack_multiplier(multiplier: float) -> void:
	_demo_attack_multiplier = maxf(multiplier, 1.0)
	state_changed.emit()


func get_demo_attack_multiplier() -> float:
	return _demo_attack_multiplier


func get_active_config() -> Dictionary:
	return _cfg


func get_current_season() -> String:
	return _current_season


const UnitMoraleRules := preload("res://scripts/systems/unit_morale_rules.gd")

func get_unit_morale(unit_id: String) -> int:
	var u: Dictionary = get_unit_by_id(unit_id)
	if u.is_empty():
		return 0
	return int(u.get("morale", 100))


func get_unit_supply(unit_id: String) -> bool:
	var u: Dictionary = get_unit_by_id(unit_id)
	if u.is_empty():
		return true
	return bool(u.get("is_supplied", true))


func get_unit_burn(unit_id: String) -> int:
	var u: Dictionary = get_unit_by_id(unit_id)
	if u.is_empty():
		return 0
	return int(u.get("burn_turns", 0))


func get_units() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u: Dictionary in _units:
		out.append(u.duplicate())
	return out


func terrain_at(cell: Vector2i) -> String:
	return str(_tiles.get(cell, "plains"))


## 开始演武：从 DataManager 读取默认 MVP 配置
func start_skirmish() -> void:
	if _skirmish_active:
		push_warning("TacticalSkirmishManager: 演武已在进行中，忽略重复启动")
		return
	var cfg: Dictionary = DataManager.get_tactical_skirmish_mvp().duplicate(true)
	if cfg.is_empty():
		push_error("TacticalSkirmishManager: tactical_skirmish_mvp 数据为空")
		return
	# 保留调用前 set_season() 设定的季节，避免被硬编码覆盖
	start_skirmish_with_config(cfg, _current_season)


## 以指定配置和季节开始演武（供场景选择器调用）
func start_skirmish_with_config(cfg: Dictionary, season: String = "summer") -> void:
	_debug_log("[TSM] guard check: _skirmish_active=%s" % str(_skirmish_active))
	if _skirmish_active:
		push_warning("TacticalSkirmishManager: 演武已在进行中，忽略重复启动")
		_debug_log("[TSM] 已阻止重复启动")
		return
	_debug_log("[TSM] start_skirmish_with_config: name=%s season=%s" % [str(cfg.get("name", "???")), season])
	_cfg = cfg
	_current_season = season
	ai_mode = _resolve_ai_mode(cfg)
	_player_faction = str(_cfg.get("player_faction_id", "qin"))
	_enemy_faction = str(_cfg.get("enemy_faction_id", "zhao"))
	var pc: Dictionary = _cfg.get("player_city", {})
	var ec: Dictionary = _cfg.get("enemy_city", {})
	## JSON 中据点与 rows[row][col] 一致：q=列 col、r=行 row（odd-R 偏移），运行时一律转轴向
	_player_city = HexLib.offset_odd_r_to_axial(int(pc.get("q", 0)), int(pc.get("r", 0)))
	_enemy_city = HexLib.offset_odd_r_to_axial(int(ec.get("q", 0)), int(ec.get("r", 0)))
	_build_tiles()
	_debug_log("[TSM] _build_tiles 完成, tiles=%d" % _tiles.size())
	_spawn_units()
	_debug_log("[TSM] _spawn_units 完成, units=%d" % _units.size())
	_skirmish_active = true
	_append_log("演武开始：%s 对 %s（%s），攻占对方城格获胜。" % [_player_faction, _enemy_faction, _current_season])
	begin_player_phase()
	_debug_log("[TSM] begin_player_phase 完成, active=%s" % str(_skirmish_active))


func reset_skirmish() -> void:
	_debug_log("[TSM] reset_skirmish 被调用")
	_skirmish_active = false
	_units.clear()
	_tiles.clear()
	_all_cells.clear()
	_cfg.clear()
	_current_season = "summer"
	_pass_hp.clear()
	_pass_owner.clear()
	_pass_attacked.clear()
	_city_wall_hp.clear()
	_city_wall_max_hp.clear()
	_city_buildings.clear()
	_city_body_hp.clear()
	_city_body_max_hp.clear()
	_city_level.clear()
	_city_attacked.clear()
	_city_tower_hp.clear()
	# Demo 作弊倍率跨重置保留，便于测试；需要关掉时再 set_demo_attack_multiplier(1)
	state_changed.emit()


# ============= 演武独立存档（与大地图战役存档分离） =============

const SAVE_SCHEMA_VERSION: int = 1


static func _cell_key(c: Vector2i) -> String:
	return "%d_%d" % [c.x, c.y]


static func _cell_from_key(k: String) -> Vector2i:
	var parts: PackedStringArray = String(k).split("_")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


static func _pack_cell_dict(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in src:
		out[_cell_key(k as Vector2i)] = src[k]
	return out


static func _unpack_cell_dict(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in src:
		out[_cell_from_key(str(k))] = src[k]
	return out


static func _pack_units(units: Array) -> Array:
	var out: Array = []
	for u: Variant in units:
		if u is Dictionary:
			out.append((u as Dictionary).duplicate(true))
	return out


static func _pack_cells_list(cells: Array) -> Array:
	var out: Array = []
	for c: Variant in cells:
		if c is Vector2i:
			out.append({"x": (c as Vector2i).x, "y": (c as Vector2i).y})
	return out


## 演武局内完整快照（独立于 SaveManager 战役存档）
func get_save_data() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"kind": "skirmish",
		"active": _skirmish_active,
		"season": _current_season,
		"player_faction": _player_faction,
		"enemy_faction": _enemy_faction,
		"player_city": {"x": _player_city.x, "y": _player_city.y},
		"enemy_city": {"x": _enemy_city.x, "y": _enemy_city.y},
		"cfg": _cfg.duplicate(true),
		"units": _pack_units(_units),
		"tiles": _pack_cell_dict(_tiles),
		"all_cells": _pack_cells_list(_all_cells),
		"pass_hp": _pack_cell_dict(_pass_hp),
		"pass_owner": _pack_cell_dict(_pass_owner),
		"pass_attacked": _pack_cell_dict(_pass_attacked),
		"city_wall_hp": _pack_cell_dict(_city_wall_hp),
		"city_wall_max_hp": _pack_cell_dict(_city_wall_max_hp),
		"city_buildings": _pack_cell_dict(_city_buildings),
		"city_body_hp": _pack_cell_dict(_city_body_hp),
		"city_body_max_hp": _pack_cell_dict(_city_body_max_hp),
		"city_level": _pack_cell_dict(_city_level),
		"city_attacked": _pack_cell_dict(_city_attacked),
		"city_tower_hp": _pack_cell_dict(_city_tower_hp),
		"demo_attack_multiplier": _demo_attack_multiplier,
	}


func _unpack_cell_array(src: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for item: Variant in src:
		if item is Dictionary:
			var d: Dictionary = item as Dictionary
			out.append(Vector2i(int(d.get("x", d.get("q", 0))), int(d.get("y", d.get("r", 0)))))
		elif item is Vector2i:
			out.append(item as Vector2i)
	return out


## 恢复演武快照（只动演武状态，不读写战役存档/CityManager）
func apply_save_data(data: Dictionary) -> String:
	if str(data.get("kind", "")) != "skirmish":
		return "NOT_SKIRMISH_SAVE"
	if int(data.get("schema_version", 0)) > SAVE_SCHEMA_VERSION:
		return "SKIRMISH_SAVE_VERSION_TOO_NEW"
	reset_skirmish()
	_cfg = data.get("cfg", {}) as Dictionary
	_current_season = str(data.get("season", "summer"))
	_player_faction = str(data.get("player_faction", ""))
	_enemy_faction = str(data.get("enemy_faction", ""))
	var pc: Dictionary = data.get("player_city", {}) as Dictionary
	var ec: Dictionary = data.get("enemy_city", {}) as Dictionary
	_player_city = Vector2i(int(pc.get("x", 0)), int(pc.get("y", 0)))
	_enemy_city = Vector2i(int(ec.get("x", 0)), int(ec.get("y", 0)))
	_tiles = _unpack_cell_dict(data.get("tiles", {}) as Dictionary)
	_all_cells.clear()
	for c: Vector2i in _unpack_cell_dict(data.get("tiles", {}) as Dictionary):
		_all_cells.append(c)
	# all_cells 若单独存过则覆盖
	if data.has("all_cells"):
		var packed_cells: Variant = data.get("all_cells")
		if packed_cells is Array and (packed_cells as Array).size() > 0:
			_all_cells.clear()
			for item: Variant in (packed_cells as Array):
				if item is Dictionary:
					var d: Dictionary = item as Dictionary
					_all_cells.append(Vector2i(int(d.get("x", d.get("q", 0))), int(d.get("y", d.get("r", 0)))))
	_units.clear()
	for u: Variant in data.get("units", []):
		if u is Dictionary:
			_units.append((u as Dictionary).duplicate(true))
	_pass_hp = _unpack_cell_dict(data.get("pass_hp", {}) as Dictionary)
	_pass_owner = _unpack_cell_dict(data.get("pass_owner", {}) as Dictionary)
	_pass_attacked = _unpack_cell_dict(data.get("pass_attacked", {}) as Dictionary)
	_city_wall_hp = _unpack_cell_dict(data.get("city_wall_hp", {}) as Dictionary)
	_city_wall_max_hp = _unpack_cell_dict(data.get("city_wall_max_hp", {}) as Dictionary)
	_city_buildings = _unpack_cell_dict(data.get("city_buildings", {}) as Dictionary)
	_city_body_hp = _unpack_cell_dict(data.get("city_body_hp", {}) as Dictionary)
	_city_body_max_hp = _unpack_cell_dict(data.get("city_body_max_hp", {}) as Dictionary)
	_city_level = _unpack_cell_dict(data.get("city_level", {}) as Dictionary)
	_city_attacked = _unpack_cell_dict(data.get("city_attacked", {}) as Dictionary)
	_city_tower_hp = _unpack_cell_dict(data.get("city_tower_hp", {}) as Dictionary)
	_demo_attack_multiplier = float(data.get("demo_attack_multiplier", 1.0))
	_skirmish_active = bool(data.get("active", true))
	state_changed.emit()
	return ""


## 测试辅助：执行士气处理（恢复/崩溃/衰减）+ 烧伤DOT，不重置行动状态
func process_morale_for_test() -> void:
	# 烧伤 DOT 结算
	for u_burn: Dictionary in _units:
		var burn_turns: int = int(u_burn.get("burn_turns", 0))
		if burn_turns <= 0:
			continue
		var burn_dmg: int = int(u_burn.get("burn_damage", 0))
		u_burn["hp"] = int(u_burn["hp"]) - burn_dmg
		u_burn["burn_turns"] = burn_turns - 1
	for u: Dictionary in _units:
		UnitMoraleRules.process_turn_morale(u, _is_in_own_city(u))
		set_unit_mp(u, UnitMoraleRules.effective_mp(u))
	# 溃退处理
	var rout_units: Array[Dictionary] = []
	for u2: Dictionary in _units:
		if UnitMoraleRules.is_broken(int(u2.get("morale", 100))):
			rout_units.append(u2)
	for ru: Dictionary in rout_units:
		if ru in _units:
			_execute_rout(ru)
	# 治疗结算（测试辅助）：仅治疗，不重置标记（测试自行控制）
	_process_healing(_player_faction)
	_process_healing(_enemy_faction)


func begin_player_phase() -> void:
	# 烧伤 DOT 结算（先于士气恢复）
	_process_burn_dot(_player_faction)
	# 断粮结算
	_process_supply_effects(_player_faction)
	# 夹击/包围持续状态
	_process_flanking_states()
	# 关隘自然恢复
	_process_pass_recovery()
	# 城墙自然恢复
	_process_city_recovery()
	# 单位士气：全军统一结算（与大地图 / UnitMoraleRules 同口径）
	# 行动重置仅玩家方；AI 行动标记由 AI 回合自行管理
	for u: Dictionary in _units:
		UnitMoraleRules.process_turn_morale(u, _is_in_own_city(u))
		if str(u["faction_id"]) == _player_faction:
			u["acted"] = false
			set_unit_mp(u, UnitMoraleRules.effective_mp(u))
			u["attacks_this_turn"] = 0

	# 溃退处理：崩溃态单位自动移向友方城市（收集后处理，避免迭代时修改 _units）
	var rout_units: Array[Dictionary] = []
	for u2: Dictionary in _units:
		if UnitMoraleRules.is_broken(int(u2.get("morale", 100))):
			rout_units.append(u2)
	for ru: Dictionary in rout_units:
		if ru in _units:
			_execute_rout(ru)
	# 治疗结算：先治疗（检查战斗标记），后重置标记为下回合准备
	_process_healing(_player_faction)
	_reset_combat_flags(_player_faction)
	state_changed.emit()


func get_attack_move_cost() -> int:
	var v: Variant = DataManager.get_balance_param("tactical.attack_move_cost")
	return int(v) if v != null else 2


## 玩家主动结束本单位行动（移动后可不攻击：再次点选己方单位）
func finalize_player_unit_action(unit_id: String) -> void:
	var u: Dictionary = get_unit_by_id(unit_id)
	if u.is_empty():
		return
	if str(u["faction_id"]) != _player_faction:
		return
	if bool(u.get("acted", false)):
		return
	u["acted"] = true
	state_changed.emit()


## 玩家结束战术回合：执行 AI，再开启下一玩家阶段
func end_player_turn() -> void:
	if not _skirmish_active:
		return
	_run_ai_turn()
	var w: String = check_victory()
	if w != "":
		_finish(w)
		return
	begin_player_phase()


func get_unit_by_id(unit_id: String) -> Dictionary:
	for u: Dictionary in _units:
		if str(u["id"]) == unit_id:
			return u
	return {}


func add_player_recruited_unit(unit_type_id: String) -> Dictionary:
	if not _skirmish_active:
		return {"ok": false, "reason": "inactive"}
	return _add_recruited_unit(_player_faction, unit_type_id, _player_city)


## 可移动到达的格子（累计移耗 ≤ 本回合剩余 mp_remaining），不含友军占据格
func get_reachable_cells(unit_id: String) -> Dictionary:
	var u: Dictionary = get_unit_by_id(unit_id)
	if u.is_empty():
		return {}
	if bool(u.get("acted", false)):
		return {}
	if _is_unit_stranded(u):
		return {}
	var origin: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
	var mp: int = unit_mp(u)
	return _dijkstra_reachable(origin, mp, str(u["unit_type_id"]), str(u["id"]), str(u["faction_id"]), u.get("skills", []))


func try_move_unit(unit_id: String, dest: Vector2i) -> Dictionary:
	var u: Dictionary = get_unit_by_id(unit_id)
	if u.is_empty():
		return {"ok": false, "reason": "no_unit"}
	if not _skirmish_active:
		return {"ok": false, "reason": "inactive"}
	if str(u["faction_id"]) != _player_faction:
		return {"ok": false, "reason": "not_player"}
	if bool(u.get("acted", false)):
		return {"ok": false, "reason": "already_acted"}
	var reach: Dictionary = get_reachable_cells(unit_id)
	if not reach.has(dest):
		return {"ok": false, "reason": "unreachable"}
	if _occupant_id_at(dest) != "":
		return {"ok": false, "reason": "occupied"}
	var path_cost: int = int(reach[dest])
	spend_unit_mp(u, path_cost)
	var mp_after: int = unit_mp(u)
	u["q"] = dest.x
	u["r"] = dest.y
	u["acted"] = false
	_append_log("%s 移动至 (%d,%d)，剩余移动力 %d" % [unit_id, dest.x, dest.y, mp_after])
	var capture_winner: String = check_victory()
	_check_enter_city(u)
	state_changed.emit()
	var w: String = capture_winner if capture_winner != "" else check_victory()
	if w != "":
		_finish(w)
	return {"ok": true, "reason": "OK"}


func try_player_attack(attacker_id: String, defender_id: String) -> Dictionary:
	return _attack.execute_player_attack(attacker_id, defender_id)



## 玩家直接攻击城墙（点击无驻军的城市格）
func try_attack_city_wall(attacker_id: String, cell: Vector2i) -> Dictionary:
	return _attack.execute_city_wall_attack(attacker_id, cell)



## 攻击预览：计算攻防加成明细和预期伤害（不实际扣血）
func compute_attack_preview(attacker_id: String, defender_id_or_cell: Variant) -> Dictionary:
	return _attack.compute_preview(attacker_id, defender_id_or_cell)



## 玩家主动撤退：消耗全部行动力，自动远离敌军
func try_retreat(unit_id: String) -> Dictionary:
	var u: Dictionary = get_unit_by_id(unit_id)
	if u.is_empty():
		return {"ok": false, "reason": "no_unit"}
	if str(u["faction_id"]) != _player_faction:
		return {"ok": false, "reason": "not_player"}
	if bool(u.get("acted", false)):
		return {"ok": false, "reason": "already_acted"}
	# 崩溃态单位不能主动撤退（由溃退系统处理）
	var break_v: Variant = DataManager.get_balance_param("unit_morale.morale_break_threshold")
	var break_threshold: int = int(break_v) if break_v != null else 20
	if int(u.get("morale", 100)) < break_threshold:
		return {"ok": false, "reason": "morale_break_use_rout"}
	var safe_v: Variant = DataManager.get_balance_param("retreat.safe_distance")
	var safe_dist: int = int(safe_v) if safe_v != null else 3
	u["acted"] = true
	set_unit_mp(u, 0)
	var old_pos: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
	var dir: Vector2i = _find_retreat_direction(u)
	if dir == Vector2i.ZERO:
		_append_log("%s 试图撤退但无路可退" % unit_id)
		state_changed.emit()
		return {"ok": true, "reason": "no_path"}
	u["q"] = dir.x
	u["r"] = dir.y
	_append_log("%s 撤退至 (%d,%d)" % [unit_id, dir.x, dir.y])
	_execute_pursuit(u, old_pos, dir)
	if u not in _units:
		state_changed.emit()
		return {"ok": true, "reason": "pursuit_killed"}
	# 继续撤退直到安全距离
	var max_steps: int = 10
	while max_steps > 0:
		max_steps -= 1
		if _distance_to_nearest_enemy(u) >= safe_dist:
			break
		var next_dir: Vector2i = _find_retreat_direction(u)
		if next_dir == Vector2i.ZERO:
			break
		var prev_pos: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
		u["q"] = next_dir.x
		u["r"] = next_dir.y
		_append_log("%s 继续撤退至 (%d,%d)" % [unit_id, next_dir.x, next_dir.y])
		_execute_pursuit(u, prev_pos, next_dir)
		if u not in _units:
			state_changed.emit()
			return {"ok": true, "reason": "pursuit_killed"}
	_check_enter_city(u)
	state_changed.emit()
	return {"ok": true, "reason": "OK"}


## 可被玩家选中的攻击目标列表（敌对且射程内，且剩余移动力≥攻击额外消耗）
func list_attack_targets(attacker_id: String) -> Array[String]:
	var a: Dictionary = get_unit_by_id(attacker_id)
	var out: Array[String] = []
	if a.is_empty():
		return out
	if unit_mp(a) < get_attack_move_cost():
		return out
	var acell: Vector2i = Vector2i(int(a["q"]), int(a["r"]))
	var ug: Dictionary = DataManager.get_unit_type(str(a["unit_type_id"]))
	var base_range: int = int(ug.get("range", 1))
	for d: Dictionary in _units:
		if str(d["faction_id"]) == str(a["faction_id"]):
			continue
		var dcell: Vector2i = Vector2i(int(d["q"]), int(d["r"]))
		var dist: int = HexLib.hex_distance_hex(acell, dcell)
		var eff_range: int = _get_effective_range(acell, dcell, base_range)
		if dist >= 1 and dist <= eff_range:
			out.append(str(d["id"]))
	return out


func check_victory() -> String:
	if not _skirmish_active:
		return ""
	# 战斗系统.md：城市一份 HP；HP=0 且我方在敌城格上即胜利
	for u: Dictionary in _units:
		var c: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
		if str(u["faction_id"]) == _player_faction and c == _enemy_city:
			if _city_wall_hp.has(c) and int(_city_wall_hp[c]) > 0:
				continue
			if _enemy_pass_blocks(_player_faction):
				return ""
			return _player_faction
	for u: Dictionary in _units:
		var c2: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
		if str(u["faction_id"]) == _enemy_faction and c2 == _player_city:
			if _city_wall_hp.has(c2) and int(_city_wall_hp[c2]) > 0:
				continue
			if _enemy_pass_blocks(_enemy_faction):
				return ""
			return _enemy_faction
	return ""


## 检查是否存在阻断指定阵营获胜的敌方关隘（HP > 0 且有驻军）
func _enemy_pass_blocks(attacker_faction: String) -> bool:
	for cell: Vector2i in _pass_hp.keys():
		if int(_pass_hp[cell]) <= 0:
			continue
		var owner: String = str(_pass_owner.get(cell, ""))
		if owner == attacker_faction:
			continue
		# 无主或敌方关隘：检查是否有驻军
		var occ_id: String = _occupant_id_at(cell)
		if occ_id != "":
			var occ: Dictionary = _get_unit_by_id(occ_id)
			if not occ.is_empty() and str(occ["faction_id"]) != attacker_faction:
				return true
	return false


# ============= 内部 =============

## 场景 AI 档：JSON `ai_mode` 优先；教学场景默认 tutorial；其余默认 scored
## （正式内容不用 random；random 仅测试显式指定）
func _resolve_ai_mode(cfg: Dictionary) -> String:
	var explicit: String = str(cfg.get("ai_mode", ""))
	if explicit != "":
		return explicit
	var sid: String = str(cfg.get("id", ""))
	if sid == "basic_plains" or sid == "luoyi_siege_demo":
		return "tutorial"
	return "scored"


## 统一移动力：权威字段 mp/max_mp（UnitState v3），mp_remaining/speed 为兼容别名
func unit_mp(unit: Dictionary) -> int:
	return int(unit.get("mp", unit.get("mp_remaining", 0)))


func spend_unit_mp(unit: Dictionary, cost: int) -> void:
	var mp: int = maxi(0, unit_mp(unit) - cost)
	unit["mp"] = mp
	unit["mp_remaining"] = mp


func set_unit_mp(unit: Dictionary, value: int) -> void:
	var mp: int = maxi(0, value)
	unit["mp"] = mp
	unit["mp_remaining"] = mp


func _make_skirmish_unit(
	faction_id: String,
	unit_type_id: String,
	axial: Vector2i,
	hp: int,
	max_mp: int,
	unit_id: String,
	col: int,
	row: int,
	skills: Array
) -> Dictionary:
	var u: Dictionary = UnitStateLib.make(
		faction_id, unit_type_id, axial.x, axial.y, hp, max_mp, 1, unit_id, col, row, skills
	)
	# 演武兼容别名（统一规范 §3.2）
	u["speed"] = int(u.get("max_mp", max_mp))
	u["mp_remaining"] = int(u.get("mp", max_mp))
	u["in_combat_this_turn"] = false
	return UnitStateLib.normalize(u)


func _finish(winner: String) -> void:
	_debug_log("[TSM] _finish 被调用, winner=%s" % winner)
	_skirmish_active = false
	_append_log("演武结束，获胜方：%s" % winner)
	if _campaign_writeback:
		apply_result_to_campaign(winner)
	# Demo 步骤标记（占城已由 apply_result_to_campaign 执行；Demo 仍推进任务）
	if DemoFlow.has_method("apply_skirmish_victory"):
		DemoFlow.apply_skirmish_victory(winner)
	skirmish_ended.emit(winner)
	state_changed.emit()


func _append_log(line: String) -> void:
	log_appended.emit(line)


func _build_tiles() -> void:
	_tiles.clear()
	_all_cells.clear()
	_pass_hp.clear()
	_pass_owner.clear()
	_pass_attacked.clear()
	_city_wall_hp.clear()
	_city_wall_max_hp.clear()
	_city_buildings.clear()
	_city_body_hp.clear()
	_city_body_max_hp.clear()
	_city_level.clear()
	_city_attacked.clear()
	_city_tower_hp.clear()
	var w: int = int(_cfg.get("map_width", 7))
	var h: int = int(_cfg.get("map_height", 7))
	var rows: Array = _cfg.get("rows", [])
	for row_o: int in range(h):
		var row: Array = rows[row_o] as Array
		for col_o: int in range(w):
			var cell_axial: Vector2i = HexLib.offset_odd_r_to_axial(col_o, row_o)
			_tiles[cell_axial] = str(row[col_o])
			_all_cells.append(cell_axial)
			# 初始化关隘 HP/owner（与大地图同一规则：必须有归属）
			var tid: String = str(row[col_o])
			if tid == "pass":
				var tdata: Dictionary = DataManager.get_terrain(tid)
				var struct_hp_v: Variant = tdata.get("structure_hp", null)
				var max_hp: int = int(struct_hp_v) if struct_hp_v != null else 300
				if PassManager != null:
					max_hp = PassManager.pass_max_hp()
				_pass_hp[cell_axial] = max_hp
				var owner: String = _resolve_skirmish_pass_owner(cell_axial)
				if PassManager != null and PassManager.has_pass(cell_axial):
					var camp_hp: int = PassManager.get_pass_hp(cell_axial)
					if camp_hp >= 0:
						_pass_hp[cell_axial] = camp_hp
				_pass_owner[cell_axial] = owner
				_pass_attacked[cell_axial] = false
	# 初始化城防数据
	_init_city_data(_player_city, _cfg.get("player_city", {}))
	_init_city_data(_enemy_city, _cfg.get("enemy_city", {}))


## 演武关隘开局归属：场景配置 > 战役 PassManager > 最近战役城
func _resolve_skirmish_pass_owner(cell_axial: Vector2i) -> String:
	# 1) 场景显式配置（便于测试/剧本）
	var pass_owners: Array = _cfg.get("pass_owners", []) as Array
	var off: Vector2i = HexLib.axial_to_offset_odd_r(cell_axial.x, cell_axial.y)
	for item: Variant in pass_owners:
		if not (item is Dictionary):
			continue
		var d: Dictionary = item as Dictionary
		var oc: int = int(d.get("col", d.get("offset_col", -999)))
		var orow: int = int(d.get("row", d.get("offset_row", -999)))
		var aq: int = int(d.get("axial_q", -99999))
		var ar: int = int(d.get("axial_r", -99999))
		var match_cell: bool = (oc == off.x and orow == off.y) or (aq == cell_axial.x and ar == cell_axial.y)
		if match_cell:
			return str(d.get("owner", ""))
	# 2) 战役 PassManager 同 axial
	if PassManager != null and PassManager.has_pass(cell_axial):
		return PassManager.get_pass_owner(cell_axial)
	# 3) 战术图最近城的战役城主
	var d_pc: int = HexLib.hex_distance_hex(cell_axial, _player_city)
	var d_ec: int = HexLib.hex_distance_hex(cell_axial, _enemy_city)
	var use_player: bool = d_pc <= d_ec
	var city_cfg: Dictionary = _cfg.get("player_city" if use_player else "enemy_city", {}) as Dictionary
	var city_id: String = str(city_cfg.get("city_id", ""))
	if city_id != "" and CityManager != null:
		var st: Dictionary = CityManager.get_city_state(city_id)
		if not st.is_empty():
			var owner: String = str(st.get("current_faction_id", ""))
			if owner != "":
				return owner
	return _player_faction if use_player else _enemy_faction


## 演武攻关隘结构（规则与大地图一致：共享结构伤 + 地形修正；满 HP 不可占领）
func try_attack_pass(attacker_id: String, cell: Vector2i) -> Dictionary:
	var u: Dictionary = get_unit_by_id(attacker_id)
	if u.is_empty():
		return {"ok": false, "reason": "no_unit"}
	if not _pass_hp.has(cell):
		return {"ok": false, "reason": "no_pass"}
	if bool(u.get("acted", false)):
		return {"ok": false, "reason": "already_acted"}
	var owner: String = str(_pass_owner.get(cell, ""))
	var fid: String = str(u["faction_id"])
	if owner == fid:
		return {"ok": false, "reason": "own_pass"}
	if int(_pass_hp[cell]) <= 0:
		return {"ok": false, "reason": "already_breached"}
	var apos: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
	var dist: int = HexLib.hex_distance_hex(apos, cell)
	var ug: Dictionary = DataManager.get_unit_type(str(u["unit_type_id"]))
	var rng: int = int(ug.get("range", 1))
	if dist < 1 or dist > rng:
		return {"ok": false, "reason": "out_of_range"}
	var Carrier := preload("res://scripts/systems/defense_carrier_rules.gd")
	var base_atk: float = float(ug.get("attack", 10))
	base_atk *= get_demo_attack_multiplier()
	var school: float = SchoolManager.get_effect_float(fid, "attack_bonus") if SchoolManager != null else 0.0
	base_atk *= (1.0 + school)
	var dmg: int = Carrier.pass_structure_damage(base_atk, str(u["unit_type_id"]))
	var old_hp: int = int(_pass_hp[cell])
	_pass_hp[cell] = maxi(0, old_hp - dmg)
	_pass_attacked[cell] = true
	u["acted"] = true
	set_unit_mp(u, 0)
	_append_log("%s 攻击关隘，结构伤 %d（%d → %d）" % [attacker_id, dmg, old_hp, int(_pass_hp[cell])])
	state_changed.emit()
	return {
		"ok": true,
		"damage": dmg,
		"hp": int(_pass_hp[cell]),
		"destroyed": int(_pass_hp[cell]) <= 0,
		"owner": str(_pass_owner.get(cell, "")),
	}


func _spawn_units() -> void:
	_units.clear()
	var base_morale_v: Variant = DataManager.get_balance_param("unit_morale.base_morale")
	var base_morale: int = int(base_morale_v) if base_morale_v != null else 100
	for raw: Variant in _cfg.get("initial_units", []):
		var e: Dictionary = raw as Dictionary
		var ut: String = str(e.get("unit_type_id", "infantry"))
		var fid: String = str(e.get("faction_id", ""))
		var def: Dictionary = DataManager.get_unit_type(ut)
		var max_hp: int = int(def.get("hp", 100))
		var spd: int = int(def.get("speed", 3))
		var col_u: int = int(e.get("q", 0))
		var row_u: int = int(e.get("r", 0))
		var axial_u: Vector2i = HexLib.offset_odd_r_to_axial(col_u, row_u)
		var skills: Array = DataManager.get_unit_skills(fid, ut)
		var unit_new: Dictionary = _make_skirmish_unit(
			fid, ut, axial_u, max_hp, spd, str(e.get("id", "")), col_u, row_u, skills
		)
		unit_new["morale"] = base_morale
		_units.append(unit_new)


func _occupant_id_at(cell: Vector2i) -> String:
	for u: Dictionary in _units:
		if Vector2i(int(u["q"]), int(u["r"])) == cell:
			return str(u["id"])
	return ""


func _add_recruited_unit(faction_id: String, unit_type_id: String, origin: Vector2i) -> Dictionary:
	var def: Dictionary = DataManager.get_unit_type(unit_type_id)
	if def.is_empty():
		return {"ok": false, "reason": "invalid_unit"}
	var spawn_cell: Vector2i = _find_spawn_cell(origin, unit_type_id)
	if spawn_cell == Vector2i(-9999, -9999):
		return {"ok": false, "reason": "no_spawn_cell"}
	var base_morale_v: Variant = DataManager.get_balance_param("unit_morale.base_morale")
	var base_morale: int = int(base_morale_v) if base_morale_v != null else 100
	var max_hp: int = int(def.get("hp", 100))
	var spd: int = int(def.get("speed", 3))
	var uid: String = "%s_recruit_%s_%d" % [faction_id, unit_type_id, _units.size() + 1]
	var skills: Array = DataManager.get_unit_skills(faction_id, unit_type_id)
	var recruited: Dictionary = _make_skirmish_unit(
		faction_id, unit_type_id, spawn_cell, max_hp, spd, uid,
		int(HexLib.axial_to_offset_odd_r(spawn_cell.x, spawn_cell.y).x),
		int(HexLib.axial_to_offset_odd_r(spawn_cell.x, spawn_cell.y).y),
		skills
	)
	recruited["morale"] = base_morale
	_units.append(recruited)
	_append_log("征兵完成：%s 在 (%d,%d) 入场。" % [uid, spawn_cell.x, spawn_cell.y])
	state_changed.emit()
	return {"ok": true, "reason": "OK", "unit_id": uid, "cell": spawn_cell}


func _find_spawn_cell(origin: Vector2i, unit_type_id: String) -> Vector2i:
	if _all_cells.has(origin) and _occupant_id_at(origin) == "" and int(_city_wall_hp.get(origin, 0)) <= 0:
		return origin
	var candidates: Array[Vector2i] = HexLib.neighbors_hex(origin)
	candidates.append_array(_all_cells)
	for cell: Vector2i in candidates:
		if not _all_cells.has(cell):
			continue
		if _occupant_id_at(cell) != "":
			continue
		if _city_wall_hp.has(cell) and int(_city_wall_hp[cell]) > 0:
			continue
		if _tile_move_cost_cell(cell, unit_type_id) >= BIG_MOVE:
			continue
		return cell
	return Vector2i(-9999, -9999)


func _tile_move_cost_cell(cell: Vector2i, unit_type_id: String, unit_skills: Array = []) -> int:
	var tid: String = terrain_at(cell)
	var tdata: Dictionary = DataManager.get_terrain(tid)
	var mc: int = int(tdata.get("move_cost", 1))
	var udata: Dictionary = DataManager.get_unit_type(unit_type_id)
	var special: Variant = udata.get("special", null)
	# 海军单位：只在可航行地形上移动，天堑（move_cost=-1）对海军使用默认移耗
	if special != null and str(special) == "naval":
		if not bool(tdata.get("is_navigable", false)):
			return BIG_MOVE
		return maxi(1, mc) if mc > 0 else 2
	if mc < 0:
		return BIG_MOVE
	if unit_type_id == "cavalry" and not bool(tdata.get("cavalry_allowed", true)):
		return BIG_MOVE
	# terrain_move_modifier 技能：按地形调整移动力消耗
	for skill: Variant in unit_skills:
		var s: Dictionary = skill as Dictionary
		var mod: Variant = s.get("terrain_move_modifier", null)
		if mod is Dictionary:
			var terrain_mod: Variant = (mod as Dictionary).get(tid, 0)
			mc = maxi(1, mc + int(terrain_mod))
	# crossing_rules 行军降速（如关隘 move_speed_modifier: 0.5）
	var cr: Variant = tdata.get("crossing_rules", null)
	if cr is Dictionary:
		var speed_mod: Variant = (cr as Dictionary).get("move_speed_modifier", null)
		if speed_mod != null:
			mc = maxi(1, int(float(mc) * float(speed_mod)))
	return mc


func _get_unit_by_id(uid: String) -> Dictionary:
	for u: Dictionary in _units:
		if str(u["id"]) == uid:
			return u
	return {}


func _generates_zoc(unit: Dictionary) -> bool:
	var type_id: String = str(unit.get("unit_type_id", ""))
	var udata: Dictionary = DataManager.get_unit_type(type_id)
	if udata.is_empty():
		return false
	var category: String = str(udata.get("category", ""))
	var zoc_data: Variant = DataManager.get_balance_param("zoc.generates_zoc")
	if zoc_data is Dictionary:
		return bool(zoc_data.get(category, false))
	return false


func _is_zoc_immune(unit_type_id: String) -> bool:
	var udata: Dictionary = DataManager.get_unit_type(unit_type_id)
	if udata.is_empty():
		return false
	var special: Variant = udata.get("special", null)
	if special != null and str(special) == "recon":
		return true
	var category: String = str(udata.get("category", ""))
	if category == "navy":
		var navy_v: Variant = DataManager.get_balance_param("zoc.navy_immune_to_land_zoc")
		return bool(navy_v) if navy_v != null else true
	return false


func _is_in_enemy_zoc(cell: Vector2i, moving_faction: String) -> bool:
	var base_range_v: Variant = DataManager.get_balance_param("zoc.base_range")
	var base_range: int = int(base_range_v) if base_range_v != null else 1
	for u: Dictionary in _units:
		if str(u["faction_id"]) == moving_faction:
			continue
		if not _generates_zoc(u):
			continue
		var enemy_pos: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
		if HexLib.hex_distance_hex(cell, enemy_pos) <= base_range:
			return true
	return false


func _check_flanking(target: Dictionary) -> int:
	var target_pos: Vector2i = Vector2i(int(target["q"]), int(target["r"]))
	var neighbors: Array[Vector2i] = HexLib.neighbors_hex(target_pos)
	var enemy_dirs: Array[int] = []
	for i: int in range(6):
		var n: Vector2i = neighbors[i]
		var occ_id: String = _occupant_id_at(n)
		if occ_id == "":
			continue
		var occ: Dictionary = _get_unit_by_id(occ_id)
		if occ.is_empty():
			continue
		if str(occ["faction_id"]) != str(target["faction_id"]):
			enemy_dirs.append(i)
	# 包围：4+ 邻格被敌方占据（机制概览·战斗系统.md §5.2）
	if enemy_dirs.size() >= 4:
		var val: Variant = DataManager.get_balance_param("unit_morale.encirclement_morale_loss")
		return int(val) if val != null else -30
	# 夹击：存在一对相反方向的敌人
	for dir: int in enemy_dirs:
		var opposite: int = (dir + 3) % 6
		if enemy_dirs.has(opposite):
			var val: Variant = DataManager.get_balance_param("unit_morale.flanking_morale_loss")
			return int(val) if val != null else -15
	return 0


## 夹击/包围为持续状态：先回补上次惩罚，再按当前站位重新结算。
## 脱离状态时被扣士气立即恢复（战斗系统.md §5.2）。
func _process_flanking_states() -> void:
	for u: Dictionary in _units:
		var prev: int = int(u.get("flanking_penalty", 0))
		if prev != 0:
			u["morale"] = int(u.get("morale", 100)) - prev
			u["flanking_penalty"] = 0
		var delta: int = _check_flanking(u)
		if delta == 0:
			continue
		u["morale"] = int(u.get("morale", 100)) + delta
		u["flanking_penalty"] = delta
		if _is_unit_encircled(u):
			_append_log("%s 被包围！士气 %d" % [str(u["id"]), delta])
		else:
			_append_log("%s 遭受夹击！士气 %d" % [str(u["id"]), delta])


## 判断单位是否被包围（4+ 邻格敌占）
func _is_unit_encircled(unit: Dictionary) -> bool:
	var target_pos: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var neighbors: Array[Vector2i] = HexLib.neighbors_hex(target_pos)
	var enemy_count: int = 0
	for n: Vector2i in neighbors:
		var occ_id: String = _occupant_id_at(n)
		if occ_id == "":
			continue
		var occ: Dictionary = _get_unit_by_id(occ_id)
		if occ.is_empty():
			continue
		if str(occ["faction_id"]) != str(unit["faction_id"]):
			enemy_count += 1
	return enemy_count >= 4


## 找到最近敌方单位的距离
func _distance_to_nearest_enemy(unit: Dictionary) -> int:
	var pos: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var fid: String = str(unit["faction_id"])
	var min_dist: int = 999
	for u: Dictionary in _units:
		if str(u["faction_id"]) == fid:
			continue
		var d: int = HexLib.hex_distance_hex(pos, Vector2i(int(u["q"]), int(u["r"])))
		if d < min_dist:
			min_dist = d
	return min_dist


## 选择撤退方向（远离最近敌人的方向）
func _find_retreat_direction(unit: Dictionary) -> Vector2i:
	var pos: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var fid: String = str(unit["faction_id"])
	# 找最近敌人
	var nearest_enemy: Dictionary = {}
	var min_dist: int = 999
	for u: Dictionary in _units:
		if str(u["faction_id"]) == fid:
			continue
		var d: int = HexLib.hex_distance_hex(pos, Vector2i(int(u["q"]), int(u["r"])))
		if d < min_dist:
			min_dist = d
			nearest_enemy = u
	if nearest_enemy.is_empty():
		return Vector2i.ZERO
	# 方向向量：从敌人指向我方
	var ex: float = float(pos.x - int(nearest_enemy["q"]))
	var ey: float = float(pos.y - int(nearest_enemy["r"]))
	var neighbors: Array[Vector2i] = HexLib.neighbors_hex(pos)
	# 按点积排序（从大到小 = 最远离敌人）
	var scored: Array[Dictionary] = []
	for i: int in range(6):
		var dv: Vector2i = HexLib.DIRECTIONS[i]
		var dot: float = ex * float(dv.x) + ey * float(dv.y)
		scored.append({"idx": i, "dot": dot})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["dot"] > b["dot"])
	# 遍历候选方向，找到可通行的
	for entry: Dictionary in scored:
		var cand: Vector2i = neighbors[int(entry["idx"])]
		if not _all_cells.has(cand):
			continue
		if _occupant_id_at(cand) != "":
			continue
		var tc: int = _tile_move_cost_cell(cand, str(unit["unit_type_id"]), unit.get("skills", []))
		if tc < BIG_MOVE:
			return cand
	return Vector2i.ZERO


## 找到最近的友方城市坐标
func _find_nearest_friendly_city(unit: Dictionary) -> Vector2i:
	var fid: String = str(unit["faction_id"])
	if fid == _player_faction:
		return _player_city
	return _enemy_city


## 计算向目标移动的下一步（不考虑移动力，只选最近邻居）
func _find_path_toward_city(unit: Dictionary, target: Vector2i) -> Vector2i:
	var pos: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	if pos == target:
		return Vector2i.ZERO
	var neighbors: Array[Vector2i] = HexLib.neighbors_hex(pos)
	var best: Vector2i = Vector2i.ZERO
	var best_dist: int = 999
	for n: Vector2i in neighbors:
		if not _all_cells.has(n):
			continue
		if _occupant_id_at(n) != "":
			continue
		var tc: int = _tile_move_cost_cell(n, str(unit["unit_type_id"]), unit.get("skills", []))
		if tc >= BIG_MOVE:
			continue
		var d: int = HexLib.hex_distance_hex(n, target)
		if d < best_dist:
			best_dist = d
			best = n
	return best


## 计算追击攻击力（简化版，仅基础攻击）
func _calc_pursuit_atk(unit: Dictionary) -> int:
	var udata: Dictionary = DataManager.get_unit_type(str(unit["unit_type_id"]))
	return int(udata.get("attack", 10))


## 执行追击伤害：撤退/溃退单位离开时被附近步兵/骑兵追击
func _execute_pursuit(retreating_unit: Dictionary, old_pos: Vector2i, new_pos: Vector2i) -> void:
	var retreater_id: String = str(retreating_unit["id"])
	var fid: String = str(retreating_unit["faction_id"])
	var ratio_v: Variant = DataManager.get_balance_param("retreat.pursuit_damage_ratio")
	var ratio: float = float(ratio_v) if ratio_v != null else 0.3
	# 检查旧位置附近是否有能追击的敌方单位
	var old_neighbors: Array[Vector2i] = HexLib.neighbors_hex(old_pos)
	for n: Vector2i in old_neighbors:
		var occ_id: String = _occupant_id_at(n)
		if occ_id == "":
			continue
		var pursuer: Dictionary = _get_unit_by_id(occ_id)
		if pursuer.is_empty():
			continue
		if str(pursuer["faction_id"]) == fid:
			continue
		# 只有产生 ZoC 的单位（步兵/骑兵）才能追击
		if not _generates_zoc(pursuer):
			continue
		var atk: int = _calc_pursuit_atk(pursuer)
		var dmg: int = maxi(1, int(float(atk) * ratio))
		dmg = mini(dmg, int(retreating_unit["hp"]))
		retreating_unit["hp"] = int(retreating_unit["hp"]) - dmg
		retreating_unit["in_combat_this_turn"] = true
		_append_log("%s 被 %s 追击，受到 %d 伤害" % [retreater_id, str(pursuer["id"]), dmg])
		if int(retreating_unit["hp"]) <= 0:
			var dead_faction: String = str(retreating_unit["faction_id"])
			_remove_unit(retreater_id)
			_append_log("%s 被追击歼灭" % retreater_id)
			var ally_death_v: Variant = DataManager.get_balance_param("unit_morale.morale_loss_on_ally_death")
			_apply_faction_morale(dead_faction, "", int(ally_death_v) if ally_death_v != null else -5)
			return


## 检查单位周围是否有敌方单位（6 邻居）
func _has_adjacent_enemy(unit: Dictionary) -> bool:
	var pos: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var fid: String = str(unit["faction_id"])
	for n: Vector2i in HexLib.neighbors_hex(pos):
		var occ_id: String = _occupant_id_at(n)
		if occ_id == "":
			continue
		var occ: Dictionary = _get_unit_by_id(occ_id)
		if occ.is_empty():
			continue
		if str(occ["faction_id"]) != fid:
			return true
	return false


## 检查单位是否在友方城市邻居格上（城市区域）
func _is_in_city_area(unit: Dictionary) -> bool:
	var pos: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var fid: String = str(unit["faction_id"])
	var city: Vector2i = _player_city if fid == _player_faction else _enemy_city
	for n: Vector2i in HexLib.neighbors_hex(city):
		if n == pos:
			return true
	return false


## 治疗结算：脱战单位在回合开始时恢复 HP
func _process_healing(faction_id: String) -> void:
	var heal_v: Variant = DataManager.get_balance_param("healing")
	if heal_v == null or not (heal_v is Dictionary):
		return
	var params: Dictionary = heal_v
	var outskirts_hp: int = int(params.get("outskirts_hp_per_turn", 10))
	var city_area_hp: int = int(params.get("city_area_hp_per_turn", 15))
	var city_inside_hp: int = int(params.get("city_inside_hp_per_turn", 20))
	var heal_to_full: bool = bool(params.get("max_heal_to_full", true))
	var no_heal_broken: bool = bool(params.get("no_heal_when_morale_broken", true))
	var break_threshold: int = int(DataManager.get_balance_param("unit_morale.morale_break_threshold")) if DataManager.get_balance_param("unit_morale.morale_break_threshold") != null else 20
	var tech_bonus: float = TechEffects.healing_bonus(faction_id if faction_id != "" else GameManager.get_player_faction())

	for u: Dictionary in _units:
		if str(u["faction_id"]) != faction_id:
			continue
		if bool(u.get("in_combat_this_turn", false)):
			continue
		if no_heal_broken and int(u.get("morale", 100)) < break_threshold:
			continue
		# 额外保险：崩溃态绝不治疗
		if int(u.get("morale", 100)) < break_threshold:
			continue
		var hp: int = int(u.get("hp", 100))
		var max_hp: int = int(u.get("max_hp", 100))
		if hp >= max_hp:
			continue
		if _has_adjacent_enemy(u):
			continue
		var base_heal: int = outskirts_hp
		if _is_in_own_city(u):
			base_heal = city_inside_hp
		elif _is_in_city_area(u):
			base_heal = city_area_hp
		var heal_amount: int = int(float(base_heal) * (1.0 + tech_bonus))
		var new_hp: int = hp + heal_amount
		if heal_to_full:
			new_hp = mini(new_hp, max_hp)
		if new_hp > hp:
			u["hp"] = new_hp
			_append_log("%s 恢复 %d HP（%d → %d）" % [str(u["id"]), new_hp - hp, hp, new_hp])


## 重置指定势力所有单位的战斗标记
func _reset_combat_flags(faction_id: String) -> void:
	for u: Dictionary in _units:
		if str(u["faction_id"]) == faction_id:
			u["in_combat_this_turn"] = false


## 被动溃退：崩溃态单位自动移向最近友方城市
func _execute_rout(unit: Dictionary) -> void:
	var uid: String = str(unit["id"])
	unit["acted"] = true
	var city: Vector2i = _find_nearest_friendly_city(unit)
	var next_step: Vector2i = _find_path_toward_city(unit, city)
	if next_step != Vector2i.ZERO:
		var old_pos: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
		unit["q"] = next_step.x
		unit["r"] = next_step.y
		_append_log("%s 溃退至 (%d,%d)" % [uid, next_step.x, next_step.y])
		_execute_pursuit(unit, old_pos, next_step)
		if unit not in _units:
			return
		# 到达友方城市，恢复士气
		if _is_in_own_city(unit):
			var rec_v: Variant = DataManager.get_balance_param("retreat.rout_recovery_morale")
			var rec_morale: int = int(rec_v) if rec_v != null else 30
			unit["morale"] = rec_morale
			_append_log("%s 溃退至友方城市，士气恢复到 %d" % [uid, rec_morale])
	else:
		# 被包围无路可走，额外 HP 损失
		var loss_v: Variant = DataManager.get_balance_param("retreat.encircled_hp_loss_per_turn")
		var hp_loss: int = int(loss_v) if loss_v != null else 10
		unit["hp"] = maxi(0, int(unit["hp"]) - hp_loss)
		_append_log("%s 被包围无法溃退，额外损失 %d HP" % [uid, hp_loss])
		if int(unit["hp"]) <= 0:
			var dead_faction: String = str(unit["faction_id"])
			_remove_unit(uid)
			_append_log("%s 因包围消耗殆尽" % uid)
			var ally_death_v: Variant = DataManager.get_balance_param("unit_morale.morale_loss_on_ally_death")
			_apply_faction_morale(dead_faction, "", int(ally_death_v) if ally_death_v != null else -5)


func _dijkstra_reachable(origin: Vector2i, mp_budget: int, unit_type_id: String, moving_unit_id: String, moving_faction: String = "", unit_skills: Array = []) -> Dictionary:
	# 统一规范 §6：演武与大地图共用 MovementReach
	# 边界取场景格集合的 offset 包围盒
	var bmin: Vector2i = Vector2i(99999, 99999)
	var bmax: Vector2i = Vector2i(-99999, -99999)
	for c: Vector2i in _all_cells:
		var off: Vector2i = HexLib.axial_to_offset_odd_r(c.x, c.y)
		bmin = Vector2i(mini(bmin.x, off.x), mini(bmin.y, off.y))
		bmax = Vector2i(maxi(bmax.x, off.x), maxi(bmax.y, off.y))
	if bmin.x > bmax.x:
		bmin = Vector2i.ZERO
		bmax = Vector2i(99, 99)
	var occupied := func(axial: Vector2i) -> bool:
		if not _all_cells.has(axial):
			return true
		var occ: String = _occupant_id_at(axial)
		return occ != "" and occ != moving_unit_id
	var wall_block := func(axial: Vector2i) -> bool:
		# 战斗系统.md：城市只有一份 HP；HP>0 不可进驻；HP=0 可进城并占领（同关隘）
		if axial == _player_city:
			return false
		if _city_wall_hp.has(axial) and int(_city_wall_hp[axial]) > 0:
			return true
		return false
	var terrain_provider := func(col: int, row: int) -> String:
		var ax: Vector2i = HexLib.offset_odd_r_to_axial(col, row)
		return terrain_at(ax)
	# 统一核心：地形 + ZOC + 骑兵限制 + 城墙挡格（MovementReach）
	var reach: Dictionary = MoveLib.dijkstra_reachable(
		origin,
		mp_budget,
		unit_type_id,
		moving_faction,
		_units,
		bmin,
		bmax,
		occupied,
		wall_block,
		terrain_provider
	)
	# 适配层：场景技能改移耗时，在共享 cost/ZOC 规则上重算一次预算
	if unit_skills is Array and not (unit_skills as Array).is_empty():
		var skill_reach: Dictionary = {}
		for cell_v: Variant in reach:
			var cell: Vector2i = cell_v as Vector2i
			var cost: int = _tile_move_cost_cell(cell, unit_type_id, unit_skills)
			if cost >= BIG_MOVE:
				continue
			if moving_faction != "" and not MoveLib.is_zoc_immune(unit_type_id) \
				and MoveLib.is_in_enemy_zoc(cell, moving_faction, _units):
				cost += MoveLib.zoc_extra_move_cost()
			if cost <= mp_budget:
				skill_reach[cell] = cost
		return skill_reach
	return reach


func _can_attack(a: Dictionary, d: Dictionary) -> bool:
	# 搁浅单位不能主动攻击（§8.3）
	if _is_unit_stranded(a):
		return false
	var ac: Vector2i = Vector2i(int(a["q"]), int(a["r"]))
	var dc: Vector2i = Vector2i(int(d["q"]), int(d["r"]))
	var dist: int = HexLib.hex_distance_hex(ac, dc)
	var ug: Dictionary = DataManager.get_unit_type(str(a["unit_type_id"]))
	var base_range: int = int(ug.get("range", 1))
	var eff_range: int = _get_effective_range(ac, dc, base_range)
	return dist >= 1 and dist <= eff_range


## 计算远程遮挡后的有效射程：低处向高处射击时，每高 1 级高程射程 -1
## 统一规范 §6：与大地图共用 MovementReach.effective_range
func _get_effective_range(attacker_cell: Vector2i, defender_cell: Vector2i, base_range: int) -> int:
	if base_range <= 1:
		return base_range
	var atk_terrain: String = terrain_at(attacker_cell)
	var def_terrain: String = terrain_at(defender_cell)
	return MoveLib.effective_range_terrain(atk_terrain, def_terrain, base_range)


func _remove_unit(uid: String) -> void:
	for i: int in range(_units.size() - 1, -1, -1):
		if str((_units[i] as Dictionary).get("id", "")) == uid:
			_units.remove_at(i)
			break


func _apply_morale_delta(unit: Dictionary, delta: int) -> void:
	UnitMoraleRules.apply_morale_delta(unit, delta)


func _apply_faction_morale(faction_id: String, exclude_id: String, delta: int) -> void:
	for u: Dictionary in _units:
		if str(u["faction_id"]) == faction_id and str(u["id"]) != exclude_id:
			_apply_morale_delta(u, delta)


func _is_in_own_city(unit: Dictionary) -> bool:
	var cell: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var fid: String = str(unit["faction_id"])
	if fid == _player_faction and cell == _player_city:
		return true
	if fid == _enemy_faction and cell == _enemy_city:
		return true
	return false


## 判断单位是否为水军
func _is_navy(unit_type_id: String) -> bool:
	var udata: Dictionary = DataManager.get_unit_type(unit_type_id)
	return str(udata.get("category", "")) == "navy"


## 判断格子是否为水面地形（is_navigable=true）
func _is_water_terrain(cell: Vector2i) -> bool:
	var tid: String = terrain_at(cell)
	var tdata: Dictionary = DataManager.get_terrain(tid)
	return bool(tdata.get("is_navigable", false))


## 判断单位是否搁浅（水军在冻结水面上，§8.3）
func _is_unit_stranded(unit: Dictionary) -> bool:
	var uid: String = str(unit.get("unit_type_id", ""))
	if not _is_navy(uid):
		return false
	var cell: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	return _is_water_frozen(cell)


## 判断水面地形是否冻结（冬季河流）
func _is_water_frozen(cell: Vector2i) -> bool:
	var tid: String = terrain_at(cell)
	var tdata: Dictionary = DataManager.get_terrain(tid)
	if not bool(tdata.get("is_navigable", false)):
		return false
	var winter_effects: Dictionary = tdata.get("winter_effects", {})
	var frozen_season: String = str(winter_effects.get("frozen_season", ""))
	return frozen_season != "" and frozen_season == _current_season


## 计算海军战斗最终乘算系数（§8.1）
## 返回 1.0 表示无修正，<1.0 表示减伤
func _calc_naval_combat_mod(atk_type: String, def_type: String, atk_cell: Vector2i, def_cell: Vector2i) -> float:
	var atk_navy: bool = _is_navy(atk_type)
	var def_navy: bool = _is_navy(def_type)
	var atk_on_water: bool = _is_water_terrain(atk_cell)
	var def_on_water: bool = _is_water_terrain(def_cell)
	var navy_data: Variant = DataManager.get_balance_param("naval_combat")
	var mods: Dictionary = navy_data if navy_data is Dictionary else {}
	if atk_navy and not def_navy:
		# 水军攻击陆地单位
		return float(mods.get("navy_vs_land_attack_mod", 0.5))
	if not atk_navy and def_navy:
		# 陆军攻击水军单位
		var base_mod: float = float(mods.get("land_vs_navy_attack_mod", 0.5))
		if atk_on_water:
			# 陆军在水面攻击水军：额外 ×0.5
			base_mod *= float(mods.get("land_on_water_attack_mod", 0.5))
		return base_mod
	# 水军 vs 水军：无额外修正
	return 1.0


## 计算陆军在水面被攻击时的防御乘算系数
func _calc_naval_defense_mod(def_type: String, def_cell: Vector2i, atk_type: String) -> float:
	var def_navy: bool = _is_navy(def_type)
	# 水军防御不受惩罚
	if def_navy:
		return 1.0
	# 陆军被水军攻击且在水面：防御 ×0.5
	var atk_navy: bool = _is_navy(atk_type)
	if atk_navy and _is_water_terrain(def_cell):
		var navy_data: Variant = DataManager.get_balance_param("naval_combat")
		var mods: Dictionary = navy_data if navy_data is Dictionary else {}
		return float(mods.get("land_on_water_defense_mod", 0.5))
	return 1.0


## 获取搁浅单位的攻击乘算系数（§8.3），非搁浅返回 1.0
func _get_stranded_attack_mod(unit: Dictionary) -> float:
	if not _is_unit_stranded(unit):
		return 1.0
	var freeze_data: Variant = DataManager.get_balance_param("naval_freeze")
	var mods: Dictionary = freeze_data if freeze_data is Dictionary else {}
	return float(mods.get("stranded_attack_mod", 0.3))


## 火攻触发条件：仅夏秋 + 目标在森林 + 非伏击
func _can_fire_attack(defender_terrain: String) -> bool:
	if _current_season != "summer" and _current_season != "autumn":
		return false
	return defender_terrain == "forest"


## 构建火攻上下文（含兵家季节/政策火攻加成）
func _get_fire_attack_ctx(faction_id: String = "") -> Dictionary:
	var ctx: Dictionary = {"is_fire_attack": true}
	var fire_bonus_v: Variant = DataManager.get_balance_param("combat.fire_atk_bonus")
	var fire_bonus: float = float(fire_bonus_v) if fire_bonus_v != null else 0.4
	if faction_id != "":
		# SchoolManager 已合并 season_bonus 与政策 fire_attack_bonus（§5.3/§12.2）
		fire_bonus += SchoolManager.get_effect_float(faction_id, "fire_attack_bonus")
	ctx["fire_bonus"] = fire_bonus
	return ctx


## 学派战斗加成（从 SchoolManager 读取运行时学派）
func _get_school_combat_bonus(faction_id: String) -> Dictionary:
	var result: Dictionary = {"school_atk": 0.0, "school_def": 0.0}
	result["school_atk"] = SchoolManager.get_effect_float(faction_id, "attack_bonus")
	result["school_def"] = SchoolManager.get_effect_float(faction_id, "defense_bonus")
	return result


## 对目标施加烧伤 DOT
func _apply_burn(attacker_unit: Dictionary, defender_unit: Dictionary) -> void:
	var burn_dur_v: Variant = DataManager.get_balance_param("combat.fire_burn_duration")
	var burn_ratio_v: Variant = DataManager.get_balance_param("combat.fire_burn_dot_ratio")
	var duration: int = int(burn_dur_v) if burn_dur_v != null else 2
	var ratio: float = float(burn_ratio_v) if burn_ratio_v != null else 0.3
	var atk_data: Dictionary = DataManager.get_unit_type(str(attacker_unit["unit_type_id"]))
	var base_atk: int = int(atk_data.get("attack", 10))
	var dot_per_turn: int = maxi(1, int(float(base_atk) * ratio))
	defender_unit["burn_damage"] = dot_per_turn
	defender_unit["burn_turns"] = duration
	_append_log("%s 被点燃！每回合将受到 %d 烧伤伤害，持续 %d 回合" % [
		str(defender_unit["id"]), dot_per_turn, duration,
	])


## 处理烧伤 DOT 回合结算
func _process_burn_dot(faction_id: String) -> void:
	var snapshot: Array[Dictionary] = _units.duplicate()
	for u: Dictionary in snapshot:
		if u not in _units:
			continue
		if str(u["faction_id"]) != faction_id:
			continue
		var burn_turns: int = int(u.get("burn_turns", 0))
		if burn_turns <= 0:
			continue
		var burn_dmg: int = int(u.get("burn_damage", 0))
		burn_dmg = mini(burn_dmg, int(u["hp"]))
		u["hp"] = int(u["hp"]) - burn_dmg
		u["burn_turns"] = burn_turns - 1
		_append_log("%s 受到 %d 烧伤伤害（剩余 %d 回合）" % [
			str(u["id"]), burn_dmg, u["burn_turns"],
		])
		if int(u["hp"]) <= 0:
			var dead_faction: String = str(u["faction_id"])
			_remove_unit(str(u["id"]))
			_append_log("%s 被烧伤致死" % str(u["id"]))
			var ally_death_v: Variant = DataManager.get_balance_param("unit_morale.morale_loss_on_ally_death")
			_apply_faction_morale(dead_faction, "", int(ally_death_v) if ally_death_v != null else -5)


# ============= 补给与断粮 =============

## BFS 检查单位是否能通过可通行地形连通到友方城市
func _check_supply(unit: Dictionary) -> bool:
	var unit_faction: String = str(unit["faction_id"])
	var origin: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	# 确定友方城市坐标
	var friendly_city: Vector2i = Vector2i(-9999, -9999)
	if unit_faction == _player_faction:
		friendly_city = _player_city
	elif unit_faction == _enemy_faction:
		friendly_city = _enemy_city
	else:
		return false
	# 已在友方城市上
	if origin == friendly_city:
		return true
	# BFS
	var visited: Dictionary = {}
	visited[origin] = true
	var queue: Array[Vector2i] = [origin]
	var max_iters: int = 200
	while queue.size() > 0 and max_iters > 0:
		max_iters -= 1
		var current: Vector2i = queue.pop_front()
		for nb: Vector2i in HexLib.neighbors_hex(current):
			if visited.has(nb):
				continue
			if not _all_cells.has(nb):
				continue
			# 不可通行地形
			var tid: String = terrain_at(nb)
			var tdata: Dictionary = DataManager.get_terrain(tid)
			if int(tdata.get("move_cost", 1)) < 0:
				continue
			# 敌方占据的格子不可通过
			var occ_id: String = _occupant_id_at(nb)
			if occ_id != "":
				var occ_unit: Dictionary = _get_unit_by_id(occ_id)
				if not occ_unit.is_empty() and str(occ_unit["faction_id"]) != unit_faction:
					continue
			# 到达友方城市
			if nb == friendly_city:
				return true
			visited[nb] = true
			queue.append(nb)
	return false


## 对断粮单位施加效果：士气下降 + HP 损失
func _process_supply_effects(faction_id: String) -> void:
	var morale_loss_v: Variant = DataManager.get_balance_param("supply.morale_loss_per_turn")
	var hp_loss_ratio_v: Variant = DataManager.get_balance_param("supply.hp_loss_per_turn")
	var morale_loss: int = int(morale_loss_v) if morale_loss_v != null else 10
	var hp_loss_ratio: float = float(hp_loss_ratio_v) if hp_loss_ratio_v != null else 0.05
	var snapshot: Array[Dictionary] = _units.duplicate()
	for u: Dictionary in snapshot:
		if u not in _units:
			continue
		if str(u["faction_id"]) != faction_id:
			continue
		if _check_supply(u):
			u["is_supplied"] = true
			continue
		u["is_supplied"] = false
		# 士气下降
		var old_morale: int = int(u.get("morale", 100))
		u["morale"] = maxi(0, old_morale - morale_loss)
		# HP 损失（按 max_hp 百分比）
		var max_hp: int = int(u.get("max_hp", 100))
		var hp_loss: int = maxi(1, int(float(max_hp) * hp_loss_ratio))
		var old_hp: int = int(u["hp"])
		u["hp"] = maxi(0, old_hp - hp_loss)
		_append_log("%s 断粮！士气 %d→%d，HP %d→%d" % [
			str(u["id"]), old_morale, int(u["morale"]), old_hp, int(u["hp"]),
		])
		if int(u["hp"]) <= 0:
			var dead_faction: String = str(u["faction_id"])
			_remove_unit(str(u["id"]))
			_append_log("%s 因断粮消耗殆尽" % str(u["id"]))
			var ally_death_v: Variant = DataManager.get_balance_param("unit_morale.morale_loss_on_ally_death")
			_apply_faction_morale(dead_faction, "", int(ally_death_v) if ally_death_v != null else -5)


## 汇总被动技能的 unit_ability_bonus 值
func _get_passive_skill_bonus(skills: Array) -> float:
	var bonus: float = 0.0
	for skill: Variant in skills:
		var s: Dictionary = skill as Dictionary
		if s.get("type", "") == "passive":
			# pack_tactics 按相邻友军数叠加，不在这里直接累加
			if str(s.get("id", "")) == "pack_tactics":
				continue
			bonus += float(s.get("value", 0.0))
	return bonus


## pack_tactics（虎狼之师）：min(相邻友军, max_stacks) × value（§3.4）
func get_pack_tactics_bonus(unit: Dictionary) -> float:
	for skill: Variant in unit.get("skills", []):
		var s: Dictionary = skill as Dictionary
		if str(s.get("id", "")) != "pack_tactics":
			continue
		var value: float = float(s.get("value", 0.05))
		var max_stacks: int = int(s.get("max_stacks", 3))
		var allies: int = _count_adjacent_allies(unit)
		return minf(float(allies), float(max_stacks)) * value
	return 0.0


func _count_adjacent_allies(unit: Dictionary) -> int:
	var origin: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var faction: String = str(unit["faction_id"])
	var count: int = 0
	for u: Dictionary in _units:
		if str(u["faction_id"]) != faction:
			continue
		if str(u["id"]) == str(unit.get("id", "")):
			continue
		var cell: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
		if HexLib.hex_distance_hex(origin, cell) == 1:
			count += 1
	return count


## 查找 move_after_attack 技能数据；无此技能返回空字典
func _get_move_after_attack_skill(skills: Array) -> Dictionary:
	for skill: Variant in skills:
		var s: Dictionary = skill as Dictionary
		if s.get("type", "") == "move_after_attack":
			return s
	return {}


## 击杀时恢复 HP（combat_on_kill 技能）
func _apply_combat_on_kill(attacker: Dictionary) -> void:
	for skill: Variant in attacker.get("skills", []):
		var s: Dictionary = skill as Dictionary
		if s.get("type", "") == "combat_on_kill":
			var ratio: float = float(s.get("recover_ratio", 0.0))
			var max_hp: int = int(attacker.get("max_hp", 100))
			var heal: int = maxi(1, int(float(max_hp) * ratio))
			var old_hp: int = int(attacker["hp"])
			attacker["hp"] = mini(old_hp + heal, max_hp)
			_append_log("%s 击杀恢复 %d HP（%d → %d）" % [
				str(attacker["id"]), attacker["hp"] - old_hp, old_hp, int(attacker["hp"]),
			])


# ============= 关隘系统 =============

## 获取关隘当前 HP；无关隘返回 -1
func get_pass_hp(cell: Vector2i) -> int:
	return int(_pass_hp.get(cell, -1))


## 获取城市城墙当前 HP；无城市返回 -1
func get_city_wall_hp(cell: Vector2i) -> int:
	return int(_city_wall_hp.get(cell, -1))


## 获取城市城墙最大 HP；无城市返回 0
func get_city_wall_max_hp(cell: Vector2i) -> int:
	return int(_city_wall_max_hp.get(cell, 0))


func can_capture_city(cell: Vector2i, faction_id: String, unit_id: String = "") -> bool:
	## 战斗系统.md：城市只有一份 HP；HP≤0 且无敌驻军，我方进驻即占领（与关隘同规则）
	if not _city_wall_hp.has(cell):
		return false
	if int(_city_wall_hp[cell]) > 0:
		return false
	for other: Dictionary in _units:
		if unit_id != "" and str(other["id"]) == unit_id:
			continue
		if Vector2i(int(other["q"]), int(other["r"])) == cell and str(other["faction_id"]) != faction_id:
			return false
	return true


## 城体/城墙变化后：检查是否已有己方单位站在城格上并满足占领条件
## （此前只在「移动进城」时判定，城 HP 被打空时站在城里的单位不会触发占领）
func _recheck_city_capture_at(cell: Vector2i) -> void:
	if not _city_wall_hp.has(cell):
		return
	for u: Dictionary in _units:
		if Vector2i(int(u["q"]), int(u["r"])) != cell:
			continue
		_check_enter_city(u)
		return


func _damage_city_wall(cell: Vector2i, wall_dmg: int) -> void:
	if not _city_wall_hp.has(cell):
		return
	var old_hp: int = int(_city_wall_hp[cell])
	var new_hp: int = maxi(0, old_hp - wall_dmg)
	# 城市只有一份 HP：墙/体字典同步，避免显示与进驻判定不一致
	_city_wall_hp[cell] = new_hp
	if _city_body_hp.has(cell):
		_city_body_hp[cell] = new_hp
	_append_log("城市 HP 受到 %d 伤害（%d → %d）" % [wall_dmg, old_hp, new_hp])
	_recheck_city_capture_at(cell)


func _damage_city_body(cell: Vector2i, body_dmg: int) -> void:
	# 统一为城市一份 HP
	_damage_city_wall(cell, body_dmg)


## 城市本体 HP（城墙击破后的主要目标）
func get_city_body_hp(cell: Vector2i) -> int:
	return int(_city_body_hp.get(cell, -1))


func get_city_body_max_hp(cell: Vector2i) -> int:
	return int(_city_body_max_hp.get(cell, 0))


## 获取城市等级；无城市返回 0
func get_city_level(cell: Vector2i) -> int:
	return int(_city_level.get(cell, 0))


## 获取城市箭塔 HP；无箭塔返回 0
func get_city_tower_hp(cell: Vector2i) -> int:
	return int(_city_tower_hp.get(cell, 0))


## 获取关隘最大 HP
func _get_pass_max_hp() -> int:
	var v: Variant = DataManager.get_balance_param("fortification.pass_hp")
	return int(v) if v != null else 500


## 获取关隘当前归属
func get_pass_owner(cell: Vector2i) -> String:
	return str(_pass_owner.get(cell, ""))


## 判断单位是否为攻城器械（category == "siege" 或 special == "siege_bonus"）
func _is_siege_unit(unit_type_id: String) -> bool:
	var udata: Dictionary = DataManager.get_unit_type(unit_type_id)
	if udata.is_empty():
		return false
	if str(udata.get("special", "")) == "siege_bonus":
		return true
	return str(udata.get("category", "")) == "siege"


## 对关隘造成结构伤害（共享规则，含地形×0.5）
func _damage_pass_structure(cell: Vector2i, attacker_type_id: String, effective_atk: float) -> void:
	if not _pass_hp.has(cell):
		return
	var Carrier := preload("res://scripts/systems/defense_carrier_rules.gd")
	var struct_dmg: int = Carrier.pass_structure_damage(effective_atk, attacker_type_id)
	var old_hp: int = int(_pass_hp[cell])
	_pass_hp[cell] = maxi(0, old_hp - struct_dmg)
	_pass_attacked[cell] = true
	_append_log("关隘受到 %d 结构伤害（%d → %d）" % [struct_dmg, old_hp, int(_pass_hp[cell])])


## 对城墙造成伤害（攻城器械已在外层乘算）→ 结构变化后重检占领
# （实现见文件前部 _damage_city_wall）


## 关隘自然恢复：回合开始时未被攻击的关隘恢复 5% 最大 HP
func _process_pass_recovery() -> void:
	var rec_v: Variant = DataManager.get_balance_param("city_combat.natural_recovery_ratio")
	var ratio: float = float(rec_v) if rec_v != null else 0.05
	var max_hp: int = _get_pass_max_hp()
	for cell: Vector2i in _pass_hp.keys():
		if bool(_pass_attacked.get(cell, false)):
			_pass_attacked[cell] = false
			continue
		var hp: int = int(_pass_hp[cell])
		if hp <= 0 or hp >= max_hp:
			continue
		var heal: int = maxi(1, int(float(max_hp) * ratio))
		_pass_hp[cell] = mini(hp + heal, max_hp)
		_append_log("关隘 (%d,%d) 自然恢复 %d HP（%d → %d）" % [
			cell.x, cell.y, _pass_hp[cell] - hp, hp, int(_pass_hp[cell]),
		])


## 城墙自然恢复：回合开始时未被攻击的城市恢复 5% 最大 HP
func _process_city_recovery() -> void:
	var rec_v: Variant = DataManager.get_balance_param("city_combat.natural_recovery_ratio")
	var ratio: float = float(rec_v) if rec_v != null else 0.05
	for cell: Vector2i in _city_wall_hp.keys():
		if bool(_city_attacked.get(cell, false)):
			_city_attacked[cell] = false
			continue
		var hp: int = int(_city_wall_hp[cell])
		var max_hp: int = int(_city_wall_max_hp[cell])
		if hp <= 0 or hp >= max_hp:
			continue
		var heal: int = maxi(1, int(float(max_hp) * ratio))
		_city_wall_hp[cell] = mini(hp + heal, max_hp)
		_append_log("城墙 (%d,%d) 自然恢复 %d HP（%d → %d）" % [
			cell.x, cell.y, _city_wall_hp[cell] - hp, hp, int(_city_wall_hp[cell]),
		])


## 箭塔自动攻击：4 级以上城市每回合攻击范围内敌军
func _process_arrow_towers() -> void:
	for cell: Vector2i in _city_tower_hp.keys():
		var tower_hp: int = int(_city_tower_hp[cell])
		if tower_hp <= 0:
			continue
		# 确定城市归属
		var city_owner: String = ""
		if cell == _player_city:
			city_owner = _player_faction
		elif cell == _enemy_city:
			city_owner = _enemy_faction
		else:
			continue
		# 城墙被摧毁时箭塔失效
		if _city_wall_hp.has(cell) and int(_city_wall_hp[cell]) <= 0:
			continue
		var level: int = int(_city_level.get(cell, 3))
		var tower_range: int = 1
		if level >= 4:
			tower_range = 2
		# 箭塔攻击：优先建筑 arrow_tower.tower_attack，否则城级表
		var blds: Array = _city_buildings.get(cell, []) as Array
		var tower_atk: int = int(BuildingFxLib.tower_attack_from_buildings(blds))
		if tower_atk <= 0:
			var tower_levels_all: Variant = DataManager.get_balance_param("city_levels")
			var tower_level_data: Dictionary = {}
			if tower_levels_all is Dictionary:
				tower_level_data = (tower_levels_all as Dictionary).get(str(level), {})
			tower_atk = int(tower_level_data.get("attack", 15))
		# 攻击范围内的敌军
		for target: Dictionary in _units:
			if str(target["faction_id"]) == city_owner:
				continue
			var target_cell: Vector2i = Vector2i(int(target["q"]), int(target["r"]))
			var dist: int = HexLib.hex_distance_hex(cell, target_cell)
			if dist < 1 or dist > tower_range:
				continue
			# 伤害 = tower_atk × COEFF / (COEFF + target_def)，最低 1
			var target_udata: Dictionary = DataManager.get_unit_type(str(target["unit_type_id"]))
			var target_def: int = int(target_udata.get("defense", 5))
			var coeff: float = 20.0
			var tower_dmg: int = maxi(1, int(float(tower_atk) * coeff / (coeff + float(target_def))))
			tower_dmg = mini(tower_dmg, int(target["hp"]))
			target["hp"] = int(target["hp"]) - tower_dmg
			_append_log("城市 (%d,%d) 箭塔攻击 %s，造成 %d 伤害" % [cell.x, cell.y, str(target["id"]), tower_dmg])
			if int(target["hp"]) <= 0:
				var dead_faction: String = str(target["faction_id"])
				_remove_unit(str(target["id"]))
				_append_log("%s 被箭塔歼灭" % str(target["id"]))
				var ally_death_v: Variant = DataManager.get_balance_param("unit_morale.morale_loss_on_ally_death")
				_apply_faction_morale(dead_faction, "", int(ally_death_v) if ally_death_v != null else -5)
			# 每座箭塔每回合只攻击一次
			break


## 初始化城市：战斗系统.md —— 城市只有一份 HP（city_levels + 首都加成）
## 墙/塔建筑只提供战斗防御加成，不再单独作为第二条 HP 挡进驻
func _init_city_data(cell: Vector2i, city_cfg: Dictionary) -> void:
	var level: int = int(city_cfg.get("level", 3))
	level = clampi(level, 1, 5)
	var is_capital: bool = bool(city_cfg.get("is_capital", false))
	var levels_data: Variant = DataManager.get_balance_param("city_levels")
	var level_data: Dictionary = {}
	if levels_data is Dictionary:
		level_data = (levels_data as Dictionary).get(str(level), {})
	var city_max_hp: int = int(level_data.get("hp", 300))
	if is_capital:
		var bonus_v: Variant = DataManager.get_balance_param("city_levels.capital_bonus.hp")
		city_max_hp += int(bonus_v) if bonus_v != null else 500
	var buildings: Array = BuildingFxLib.resolve_city_buildings(city_cfg)
	_city_buildings[cell] = buildings
	# 一份城市 HP（API 名 get_city_wall_hp 沿用，语义=城市 HP）
	_city_wall_hp[cell] = city_max_hp
	_city_wall_max_hp[cell] = city_max_hp
	_city_body_hp[cell] = city_max_hp
	_city_body_max_hp[cell] = city_max_hp
	_city_level[cell] = level
	_city_attacked[cell] = false
	var tower_from_b: float = BuildingFxLib.tower_attack_from_buildings(buildings)
	if tower_from_b > 0.0:
		_city_tower_hp[cell] = int(tower_from_b) * 10
	elif level >= 4:
		_city_tower_hp[cell] = 150 + 100 * (level - 3)
	else:
		_city_tower_hp[cell] = 0


## 从 buildings.json 解析城墙 structure_hp
func _resolve_wall_structure_hp(wall_level: int) -> int:
	var lv: int = clampi(wall_level, 1, 3)
	var wall: Dictionary = DataManager.get_building("wall")
	var levels: Array = wall.get("levels", []) if wall is Dictionary else []
	if lv >= 1 and lv <= levels.size():
		var effects: Dictionary = (levels[lv - 1] as Dictionary).get("effects", {})
		var structure_hp: int = int(effects.get("structure_hp", 0))
		if structure_hp > 0:
			return structure_hp
	# 兜底：无建筑数据时用城级 HP 的 30% 作城墙池
	return maxi(1, int(int(DataManager.get_balance_param("city_levels.3.hp") if wall_level <= 0 else 150) * 0.3))


func _check_enter_city(u: Dictionary) -> void:
	var c: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
	var fid: String = str(u["faction_id"])
	# 城市占领（战斗系统.md）：城市 HP=0 且无敌驻军，我方进驻 → 占领
	if can_capture_city(c, fid, str(u["id"])):
		var max_hp: int = int(_city_wall_max_hp[c])
		var restore_v: Variant = DataManager.get_balance_param("city_combat.capture_restore_ratio")
		var restore_ratio: float = float(restore_v) if restore_v != null else 0.3
		var restored: int = maxi(1, int(float(max_hp) * restore_ratio))
		_city_wall_hp[c] = restored
		_city_body_hp[c] = restored
		_city_attacked[c] = false
		var captured_city_id: String = ""
		var ccfg: Dictionary = {}
		if c == _enemy_city:
			ccfg = _cfg.get("enemy_city", {}) as Dictionary
		elif c == _player_city:
			ccfg = _cfg.get("player_city", {}) as Dictionary
		captured_city_id = str(ccfg.get("city_id", ""))
		if not captured_city_id.is_empty() and CityManager != null:
			var before: String = str(CityManager.get_city_state(captured_city_id).get("current_faction_id", ""))
			if before != fid:
				if CityManager.change_ownership(captured_city_id, fid):
					_append_log("战役写回：%s 归属 %s → %s（可经营）" % [captured_city_id, before, fid])
					if SaveManager != null and SaveManager.has_method("save_to_slot"):
						SaveManager.save_to_slot(SaveManager.AUTO_SLOT)
		_append_log("%s 占领城市 (%d,%d)！（城 HP=0 且无敌驻军）" % [fid, c.x, c.y])
	elif c == _enemy_city or c == _player_city:
		var wall_left: int = int(_city_wall_hp.get(c, -1))
		var body_left: int = int(_city_body_hp.get(c, -1))
		if wall_left > 0:
			_append_log("%s 未能占领：城墙仍有 %d HP" % [fid, wall_left])
		elif body_left > 0:
			_append_log("%s 在城格上，城体仍有 %d HP（正常流程下城 HP≤0 才可进驻）" % [fid, body_left])
		else:
			_append_log("%s 占据城格 (%d,%d)" % [fid, c.x, c.y])
	# 关隘占领：HP ≤ 0 且无驻守敌军时易主 → 写回战役 PassManager
	if _pass_hp.has(c) and int(_pass_hp[c]) <= 0:
		var occ_id: String = _occupant_id_at(c)
		if occ_id == str(u["id"]) or occ_id == "":
			var old_owner: String = str(_pass_owner.get(c, ""))
			var new_owner: String = str(u["faction_id"])
			if old_owner != new_owner:
				var restore_v: Variant = DataManager.get_balance_param("city_combat.capture_restore_ratio")
				var restore_ratio: float = float(restore_v) if restore_v != null else 0.3
				var max_hp: int = _get_pass_max_hp()
				if PassManager != null:
					max_hp = PassManager.pass_max_hp()
				_pass_hp[c] = maxi(1, int(float(max_hp) * restore_ratio))
				_pass_owner[c] = new_owner
				_pass_attacked[c] = false
				if PassManager != null and PassManager.has_pass(c):
					PassManager.try_capture_pass(c, new_owner)
					var camp_hp: int = PassManager.get_pass_hp(c)
					if camp_hp > 0:
						_pass_hp[c] = camp_hp
				_append_log("%s 占领关隘 (%d,%d)！HP 恢复至 %d" % [new_owner, c.x, c.y, int(_pass_hp[c])])


func _run_ai_turn() -> void:
	_ai.run_turn()
