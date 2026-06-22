extends Node

## 阶段1战术演武 — 六角移动 + 战斗结算 + 占领城格（策划案 §5 最小可玩）
## 数据：data/tactical_skirmish_mvp.json

const HexLib := preload("res://scripts/systems/hex_axial.gd")
const CombatLib := preload("res://scripts/systems/combat_resolver.gd")
const AILib := preload("res://scripts/systems/skirmish_ai.gd")
const AttackPipelineLib := preload("res://scripts/systems/skirmish_attack_pipeline.gd")
var _combat_resolver: RefCounted = CombatLib.new()
var _ai: AILib = AILib.new()
var _attack: AttackPipelineLib = AttackPipelineLib.new()

signal log_appended(line: String)
signal state_changed()
signal skirmish_ended(winner_faction_id: String)
signal combat_effect_requested(effect_id: String, cell: Vector2i, attacker_cell: Vector2i)

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
var _city_level: Dictionary = {}       # Vector2i → int (1-5)
var _city_attacked: Dictionary = {}    # Vector2i → bool
var _city_tower_hp: Dictionary = {}    # Vector2i → int（箭塔 HP，0 = 无箭塔）
var _demo_attack_multiplier: float = 1.0


func _ready() -> void:
	_rng.randomize()
	_ai.initialize(self)
	_attack.initialize(self)


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
	start_skirmish_with_config(cfg, "summer")


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
	_city_level.clear()
	_city_attacked.clear()
	_city_tower_hp.clear()
	_demo_attack_multiplier = 1.0
	state_changed.emit()


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
	var morale_params: Dictionary = {}
	var bp: Variant = DataManager.get_balance_param("unit_morale")
	if bp is Dictionary:
		morale_params = bp
	var recovery_turn: int = int(morale_params.get("morale_recovery_per_turn", 3))
	var recovery_city: int = int(morale_params.get("morale_recovery_in_city", 8))
	var natural_cap: int = int(morale_params.get("natural_recovery_cap", 100))
	var break_threshold: int = int(morale_params.get("morale_break_threshold", 20))
	var broken_hp_ratio: float = float(morale_params.get("broken_hp_loss_per_turn", 0.2))
	var broken_speed_mod: float = float(morale_params.get("broken_speed_mod", 0.5))

	for u: Dictionary in _units:
		var current_morale: int = int(u.get("morale", 100))
		if current_morale < natural_cap:
			var recovery: int = recovery_city if _is_in_own_city(u) else recovery_turn
			u["morale"] = mini(current_morale + recovery, natural_cap)
		if int(u.get("morale", 100)) > natural_cap:
			u["morale"] = int(u.get("morale", 100)) - 1
		if int(u.get("morale", 100)) < break_threshold:
			var max_hp: int = int(u.get("max_hp", 100))
			var hp_loss: int = int(float(max_hp) * broken_hp_ratio)
			u["hp"] = maxi(1, int(u.get("hp", max_hp)) - hp_loss)
		var base_speed: int = int(u.get("speed", 3))
		if int(u.get("morale", 100)) < break_threshold:
			u["mp_remaining"] = maxi(1, int(float(base_speed) * broken_speed_mod))
	# 溃退处理
	var rout_units: Array[Dictionary] = []
	for u2: Dictionary in _units:
		if int(u2.get("morale", 100)) < break_threshold:
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
	# 关隘自然恢复
	_process_pass_recovery()
	# 城墙自然恢复
	_process_city_recovery()
	var morale_params: Dictionary = {}
	var bp: Variant = DataManager.get_balance_param("unit_morale")
	if bp is Dictionary:
		morale_params = bp
	var recovery_turn: int = int(morale_params.get("morale_recovery_per_turn", 3))
	var recovery_city: int = int(morale_params.get("morale_recovery_in_city", 8))
	var natural_cap: int = int(morale_params.get("natural_recovery_cap", 100))
	var break_threshold: int = int(morale_params.get("morale_break_threshold", 20))
	var broken_hp_ratio: float = float(morale_params.get("broken_hp_loss_per_turn", 0.2))
	var broken_speed_mod: float = float(morale_params.get("broken_speed_mod", 0.5))

	for u: Dictionary in _units:
		if str(u["faction_id"]) == _player_faction:
			var current_morale: int = int(u.get("morale", 100))

			# 士气恢复：城中 +8，野外 +3，上限 natural_recovery_cap
			if current_morale < natural_cap:
				var recovery: int = recovery_city if _is_in_own_city(u) else recovery_turn
				u["morale"] = mini(current_morale + recovery, natural_cap)

			# 高士气衰减（> natural_cap 回到 natural_cap）
			if int(u.get("morale", 100)) > natural_cap:
				u["morale"] = int(u.get("morale", 100)) - 1

			# 崩溃态 HP 损失
			if int(u.get("morale", 100)) < break_threshold:
				var max_hp: int = int(u.get("max_hp", 100))
				var hp_loss: int = int(float(max_hp) * broken_hp_ratio)
				u["hp"] = maxi(1, int(u.get("hp", max_hp)) - hp_loss)

			# 速度计算：崩溃态速度衰减
			var base_speed: int = int(u.get("speed", 3))
			var effective_speed: int = base_speed
			if int(u.get("morale", 100)) < break_threshold:
				effective_speed = maxi(1, int(float(base_speed) * broken_speed_mod))

			u["acted"] = false
			u["mp_remaining"] = effective_speed
			u["attacks_this_turn"] = 0

	# 溃退处理：崩溃态单位自动移向友方城市（收集后处理，避免迭代时修改 _units）
	var rout_units: Array[Dictionary] = []
	for u2: Dictionary in _units:
		if str(u2["faction_id"]) == _player_faction and int(u2.get("morale", 100)) < break_threshold:
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
	var mp: int = int(u.get("mp_remaining", int(u.get("speed", 3))))
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
	var mp_after: int = int(u.get("mp_remaining", int(u.get("speed", 3)))) - path_cost
	u["q"] = dest.x
	u["r"] = dest.y
	u["mp_remaining"] = mp_after
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
	u["mp_remaining"] = 0
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
	if int(a.get("mp_remaining", 0)) < get_attack_move_cost():
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
	var _vc_debug: bool = false
	for u: Dictionary in _units:
		var c: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
		if str(u["faction_id"]) == _player_faction and c == _enemy_city:
			# 城墙未摧毁时不能获胜
			if _city_wall_hp.has(c) and int(_city_wall_hp[c]) > 0:
				continue
			# 关隘阻断：敌方关隘仍有驻军时不能获胜
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

func _finish(winner: String) -> void:
	_debug_log("[TSM] _finish 被调用, winner=%s" % winner)
	_skirmish_active = false
	_append_log("演武结束，获胜方：%s" % winner)
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
			# 初始化关隘 HP/owner
			var tid: String = str(row[col_o])
			if tid == "pass":
				var tdata: Dictionary = DataManager.get_terrain(tid)
				var struct_hp_v: Variant = tdata.get("structure_hp", null)
				var max_hp: int = int(struct_hp_v) if struct_hp_v != null else 500
				_pass_hp[cell_axial] = max_hp
				_pass_owner[cell_axial] = ""
				_pass_attacked[cell_axial] = false
	# 初始化城防数据
	_init_city_data(_player_city, _cfg.get("player_city", {}))
	_init_city_data(_enemy_city, _cfg.get("enemy_city", {}))


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
		_units.append({
			"id": str(e.get("id", "")),
			"faction_id": fid,
			"unit_type_id": ut,
			"q": axial_u.x,
			"r": axial_u.y,
			"hp": max_hp,
			"max_hp": max_hp,
			"speed": spd,
			"mp_remaining": spd,
			"acted": false,
			"morale": base_morale,
			"in_combat_this_turn": false,
			"burn_damage": 0,
			"burn_turns": 0,
			"skills": skills,
			"attacks_this_turn": 0,
		})


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
	_units.append({
		"id": uid,
		"faction_id": faction_id,
		"unit_type_id": unit_type_id,
		"q": spawn_cell.x,
		"r": spawn_cell.y,
		"hp": max_hp,
		"max_hp": max_hp,
		"speed": spd,
		"mp_remaining": spd,
		"acted": false,
		"morale": base_morale,
		"in_combat_this_turn": false,
		"burn_damage": 0,
		"burn_turns": 0,
		"skills": skills,
		"attacks_this_turn": 0,
	})
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
	# 包围：6 格全敌
	if enemy_dirs.size() == 6:
		var val: Variant = DataManager.get_balance_param("unit_morale.encirclement_morale_loss")
		return int(val) if val != null else -50
	# 夹击：存在一对相反方向的敌人
	for dir: int in enemy_dirs:
		var opposite: int = (dir + 3) % 6
		if enemy_dirs.has(opposite):
			var val: Variant = DataManager.get_balance_param("unit_morale.flanking_morale_loss")
			return int(val) if val != null else -20
	return 0


## 判断单位是否被包围（6 格全敌）
func _is_unit_encircled(unit: Dictionary) -> bool:
	return _check_flanking(unit) <= -50


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
	var tech_bonus: float = TechSystem.get_healing_bonus()

	for u: Dictionary in _units:
		if str(u["faction_id"]) != faction_id:
			continue
		if bool(u.get("in_combat_this_turn", false)):
			continue
		if no_heal_broken and int(u.get("morale", 100)) < break_threshold:
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
	var dist: Dictionary = {}
	for c: Vector2i in _all_cells:
		dist[c] = BIG_MOVE
	dist[origin] = 0
	var visited: Dictionary = {}
	while true:
		var u: Vector2i = Vector2i(-9999, -9999)
		var best: int = BIG_MOVE
		for c: Vector2i in _all_cells:
			if visited.has(c):
				continue
			var d: int = int(dist[c])
			if d < best:
				best = d
				u = c
		if best >= BIG_MOVE or best > mp_budget:
			break
		visited[u] = true
		for v: Vector2i in HexLib.neighbors_hex(u):
			if not dist.has(v):
				continue
			var occ: String = _occupant_id_at(v)
			if occ != "" and occ != moving_unit_id:
				continue
			# 城墙未破的城格不可通行
			if _city_wall_hp.has(v) and int(_city_wall_hp[v]) > 0:
				continue
			var w: int = _tile_move_cost_cell(v, unit_type_id, unit_skills)
			if w >= BIG_MOVE:
				continue
			if moving_faction != "" and not _is_zoc_immune(unit_type_id):
				if _is_in_enemy_zoc(v, moving_faction):
					var zoc_cost_v: Variant = DataManager.get_balance_param("zoc.extra_move_cost")
					w += int(zoc_cost_v) if zoc_cost_v != null else 1
			var alt: int = int(dist[u]) + w
			if alt < int(dist[v]):
				dist[v] = alt
	var reach: Dictionary = {}
	for k: Vector2i in dist.keys():
		var cost: int = int(dist[k])
		if cost <= mp_budget and cost < BIG_MOVE and k != origin:
			# 不能停在友军格（起点除外已在上面迭代）
			var occf: String = _occupant_id_at(k)
			if occf != "" and occf != moving_unit_id:
				continue
			# 城墙未破的城格不可停留
			if _city_wall_hp.has(k) and int(_city_wall_hp[k]) > 0:
				continue
			reach[k] = cost
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
func _get_effective_range(attacker_cell: Vector2i, defender_cell: Vector2i, base_range: int) -> int:
	if base_range <= 1:
		return base_range
	var atk_terrain: String = terrain_at(attacker_cell)
	var def_terrain: String = terrain_at(defender_cell)
	var atk_elev: int = int(DataManager.get_terrain(atk_terrain).get("elevation", 0))
	var def_elev: int = int(DataManager.get_terrain(def_terrain).get("elevation", 0))
	var diff: int = def_elev - atk_elev
	if diff > 0:
		return maxi(0, base_range - diff)
	return base_range


func _remove_unit(uid: String) -> void:
	for i: int in range(_units.size() - 1, -1, -1):
		if str((_units[i] as Dictionary).get("id", "")) == uid:
			_units.remove_at(i)
			break


func _apply_morale_delta(unit: Dictionary, delta: int) -> void:
	var max_morale_v: Variant = DataManager.get_balance_param("unit_morale.max_morale")
	var max_morale: int = int(max_morale_v) if max_morale_v != null else 130
	unit["morale"] = clampi(int(unit.get("morale", 100)) + delta, 0, max_morale)


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


## 构建火攻上下文（含兵家季节加成）
func _get_fire_attack_ctx() -> Dictionary:
	var ctx: Dictionary = {"is_fire_attack": true}
	var fire_bonus_v: Variant = DataManager.get_balance_param("combat.fire_atk_bonus")
	ctx["fire_bonus"] = float(fire_bonus_v) if fire_bonus_v != null else 0.4
	# 兵家学派夏秋加成
	var school_data: Dictionary = DataManager.get_school("military")
	if not school_data.is_empty():
		for sb: Variant in school_data.get("season_bonus", []):
			var bonus: Dictionary = sb as Dictionary
			if bonus.get("effect", "") == "fire_attack_bonus":
				var seasons: Array = bonus.get("season", [])
				if seasons.has(_current_season):
					ctx["school_atk"] = float(bonus.get("value", 0.0))
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
			bonus += float(s.get("value", 0.0))
	return bonus


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


## 对关隘造成结构伤害（攻城器械 × siege_damage_multiplier）
func _damage_pass_structure(cell: Vector2i, attacker_type_id: String, effective_atk: float) -> void:
	if not _pass_hp.has(cell):
		return
	var struct_def_v: Variant = DataManager.get_balance_param("fortification.pass_struct_def")
	var pass_struct_def: float = float(struct_def_v) if struct_def_v != null else 10.0
	var mult_v: Variant = DataManager.get_balance_param("fortification.siege_damage_multiplier")
	var siege_mult: float = float(mult_v) if mult_v != null else 3.0
	var dmg_mult: float = siege_mult if _is_siege_unit(attacker_type_id) else 1.0
	var coeff: float = 20.0
	var struct_dmg: int = maxi(1, int(effective_atk * dmg_mult * coeff / (coeff + pass_struct_def)))
	var old_hp: int = int(_pass_hp[cell])
	_pass_hp[cell] = maxi(0, old_hp - struct_dmg)
	_pass_attacked[cell] = true
	_append_log("关隘受到 %d 结构伤害（%d → %d）" % [struct_dmg, old_hp, int(_pass_hp[cell])])


## 对城墙造成伤害（攻城器械已在外层乘算）
func _damage_city_wall(cell: Vector2i, wall_dmg: int) -> void:
	if not _city_wall_hp.has(cell):
		return
	var old_hp: int = int(_city_wall_hp[cell])
	_city_wall_hp[cell] = maxi(0, old_hp - wall_dmg)
	_append_log("城墙受到 %d 伤害（%d → %d）" % [wall_dmg, old_hp, int(_city_wall_hp[cell])])


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
		var tower_levels_all: Variant = DataManager.get_balance_param("city_levels")
		var tower_level_data: Dictionary = {}
		if tower_levels_all is Dictionary:
			tower_level_data = (tower_levels_all as Dictionary).get(str(level), {})
		var tower_atk: int = int(tower_level_data.get("attack", 15))
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


## 初始化单个城市的城防数据
func _init_city_data(cell: Vector2i, city_cfg: Dictionary) -> void:
	var level: int = int(city_cfg.get("level", 3))
	level = clampi(level, 1, 5)
	var is_capital: bool = bool(city_cfg.get("is_capital", false))
	var levels_data: Variant = DataManager.get_balance_param("city_levels")
	var level_data: Dictionary = {}
	if levels_data is Dictionary:
		level_data = (levels_data as Dictionary).get(str(level), {})
	var wall_max_hp: int = int(level_data.get("hp", 1000))
	if is_capital:
		var bonus_v: Variant = DataManager.get_balance_param("city_levels.capital_bonus.hp")
		wall_max_hp += int(bonus_v) if bonus_v != null else 500
	_city_wall_hp[cell] = wall_max_hp
	_city_wall_max_hp[cell] = wall_max_hp
	_city_level[cell] = level
	_city_attacked[cell] = false
	# 箭塔：4 级以上城市有箭塔
	if level >= 4:
		var tower_base: int = 150 + 100 * (level - 3)
		_city_tower_hp[cell] = tower_base
	else:
		_city_tower_hp[cell] = 0


func _check_enter_city(u: Dictionary) -> void:
	var c: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
	var fid: String = str(u["faction_id"])
	# 城市占领：城墙 HP ≤ 0 且无敌方驻军时易主
	if can_capture_city(c, fid, str(u["id"])):
		var old_wall_hp: int = int(_city_wall_hp[c])
		var max_hp: int = int(_city_wall_max_hp[c])
		var restore_v: Variant = DataManager.get_balance_param("city_combat.capture_restore_ratio")
		var restore_ratio: float = float(restore_v) if restore_v != null else 0.3
		_city_wall_hp[c] = maxi(1, int(float(max_hp) * restore_ratio))
		_city_attacked[c] = false
		_append_log("%s 占领城市 (%d,%d)！城墙 HP 恢复至 %d" % [fid, c.x, c.y, int(_city_wall_hp[c])])
	elif c == _enemy_city or c == _player_city:
		_append_log("%s 占据城格 (%d,%d)" % [fid, c.x, c.y])
	# 关隘占领：HP ≤ 0 且无驻守敌军时易主
	if _pass_hp.has(c) and int(_pass_hp[c]) <= 0:
		var occ_id: String = _occupant_id_at(c)
		if occ_id == str(u["id"]) or occ_id == "":
			var old_owner: String = str(_pass_owner.get(c, ""))
			var new_owner: String = str(u["faction_id"])
			if old_owner != new_owner:
				var restore_v: Variant = DataManager.get_balance_param("city_combat.capture_restore_ratio")
				var restore_ratio: float = float(restore_v) if restore_v != null else 0.3
				var max_hp: int = _get_pass_max_hp()
				_pass_hp[c] = maxi(1, int(float(max_hp) * restore_ratio))
				_pass_owner[c] = new_owner
				_pass_attacked[c] = false
				_append_log("%s 占领关隘 (%d,%d)！HP 恢复至 %d" % [new_owner, c.x, c.y, int(_pass_hp[c])])


func _run_ai_turn() -> void:
	_ai.run_turn()
