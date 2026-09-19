extends RefCounted

## 战术演武攻击流水线
## 从 TacticalSkirmishManager 提取 try_player_attack / try_attack_city_wall /
## compute_attack_preview 三个超长函数（合计 558 行），避免单文件超 2000 行。
## 持有 manager 引用，通过它访问所有战斗/移动/状态私有 API。
## 入口由 TacticalSkirmishManager 同名 public 方法委派调用。

const HexLib := preload("res://scripts/systems/hex_axial.gd")
const CtxLib := preload("res://scripts/systems/combat_ctx_builder.gd")
const WallLib := preload("res://scripts/systems/wall_combat_rules.gd")
const MoveLib := preload("res://scripts/systems/movement_reach.gd")
const BuildingFxLib := preload("res://scripts/systems/building_combat_effects.gd")

var m: Node


func initialize(manager: Node) -> void:
	m = manager


func _get_national_morale_atk_offset(faction_id: String) -> float:
	return CtxLib.national_morale_atk_offset(faction_id)


func _get_grain_shortage_atk_offset(faction_id: String) -> float:
	return CtxLib.grain_shortage_atk_offset(faction_id)


func _get_grain_shortage_def_offset(faction_id: String) -> float:
	return CtxLib.grain_shortage_def_offset(faction_id)


func _add_ctx_offset(ctx: Dictionary, key: String, offset: float) -> void:
	CtxLib.add_offset(ctx, key, offset)


func execute_player_attack(attacker_id: String, defender_id: String) -> Dictionary:
	var a: Dictionary = m.get_unit_by_id(attacker_id)
	var d: Dictionary = m.get_unit_by_id(defender_id)
	if a.is_empty() or d.is_empty():
		return {"ok": false, "reason": "no_unit"}
	if str(a["faction_id"]) != m._player_faction:
		return {"ok": false, "reason": "not_player"}
	if str(a["faction_id"]) == str(d["faction_id"]):
		return {"ok": false, "reason": "friendly"}
	if bool(a.get("acted", false)):
		return {"ok": false, "reason": "already_acted"}
	# move_after_attack 技能检测
	var maa_skill: Dictionary = m._get_move_after_attack_skill(a.get("skills", []))
	var is_maa: bool = not maa_skill.is_empty()
	if is_maa:
		var per_turn: int = int(maa_skill.get("per_turn_limit", 1))
		if int(a.get("attacks_this_turn", 0)) >= per_turn:
			return {"ok": false, "reason": "attack_limit_reached"}
	var atk_cost: int = int(maa_skill.get("attack_move_cost", 0)) if is_maa else m.get_attack_move_cost()
	if m.has_method("unit_mp") and int(m.unit_mp(a)) < atk_cost:
		return {"ok": false, "reason": "insufficient_mp_for_attack"}
	if not m.has_method("unit_mp") and int(a.get("mp_remaining", 0)) < atk_cost:
		return {"ok": false, "reason": "insufficient_mp_for_attack"}
	if not m._can_attack(a, d):
		return {"ok": false, "reason": "out_of_range"}
	var def_cell: Vector2i = Vector2i(int(d["q"]), int(d["r"]))
	var atk_cell: Vector2i = Vector2i(int(a["q"]), int(a["r"]))
	var def_terrain: String = m.terrain_at(def_cell)
	var atk_morale: int = int(a.get("morale", 100))
	var def_morale: int = int(d.get("morale", 100))
	# 统一规范 §4：基础攻/防修正一律 CtxBuilder；场景仅叠加关隘/墙城/海军等适配层项
	var is_fire: bool = m._can_fire_attack(def_terrain)
	var skills_a: Array = a.get("skills", []) if a.get("skills") is Array else []
	var skills_d: Array = d.get("skills", []) if d.get("skills") is Array else []
	var season: String = str(m.get_current_season()) if m.has_method("get_current_season") else ""
	var atk_ctx: Dictionary = CtxLib.build_attack_ctx(
		str(a["faction_id"]), str(a["unit_type_id"]), skills_a, season, is_fire
	)
	var def_ctx: Dictionary = CtxLib.build_defense_ctx(
		str(d["faction_id"]), str(d["unit_type_id"])
	)
	# 场景层额外项（CtxBuilder 未覆盖）
	var pack_bonus: float = m.get_pack_tactics_bonus(a)
	if pack_bonus > 0.001:
		atk_ctx["unit_ability_bonus"] = float(atk_ctx.get("unit_ability_bonus", 0.0)) + pack_bonus
	var school_ambush: float = SchoolManager.get_effect_float(str(a["faction_id"]), "ambush_damage_bonus")
	if school_ambush > 0.001:
		atk_ctx["school_ambush_bonus"] = school_ambush
	# 关隘 crossing_rules 修正
	var tdata_def: Dictionary = DataManager.get_terrain(def_terrain)
	var cr: Variant = tdata_def.get("crossing_rules", null)
	if cr is Dictionary:
		var cr_dict: Dictionary = cr as Dictionary
		atk_ctx["terrain_atk_offset"] = atk_ctx.get("terrain_atk_offset", 0.0) + float(cr_dict.get("atk_mod", 0.0))
		def_ctx["terrain_def_offset"] = def_ctx.get("terrain_def_offset", 0.0) + float(cr_dict.get("def_bonus", 0.0))
	# 关隘结构防御：HP > 0 时额外防御
	var pass_has_structure: bool = m._pass_hp.has(def_cell) and int(m._pass_hp[def_cell]) > 0
	if pass_has_structure:
		var pass_def_v: Variant = DataManager.get_balance_param("fortification.pass_defense")
		def_ctx["building_def"] = def_ctx.get("building_def", 0.0) + float(pass_def_v) / 100.0
	# 城防防御加成：墙 HP 比例 × 城防（含建筑 defense_bonus，经营效果进演武）
	var city_has_wall: bool = m._city_wall_hp.has(def_cell) and int(m._city_wall_hp[def_cell]) > 0
	if city_has_wall:
		var blds: Array = []
		if "_city_buildings" in m:
			blds = m._city_buildings.get(def_cell, []) as Array
		var wall_buff: float = BuildingFxLib.city_building_def_buff(
			blds,
			int(m._city_wall_hp[def_cell]),
			int(m._city_wall_max_hp.get(def_cell, 0)),
			int(m._city_level.get(def_cell, 3))
		)
		def_ctx["building_def"] = def_ctx.get("building_def", 0.0) + wall_buff
	var dmg_info: Dictionary = m._combat_resolver.compute_damage(
		str(a["unit_type_id"]),
		str(d["unit_type_id"]),
		def_terrain,
		atk_morale,
		def_morale,
		m._rng,
		atk_ctx,
		def_ctx,
	)
	var dmg: int = int(dmg_info.get("damage", 0))
	# 海军战斗最终乘算（§8.1）+ 搁浅攻击修正（§8.3）：在随机波动之后应用
	var naval_atk_mod: float = m._calc_naval_combat_mod(str(a["unit_type_id"]), str(d["unit_type_id"]), atk_cell, def_cell)
	var naval_def_mod: float = m._calc_naval_defense_mod(str(d["unit_type_id"]), def_cell, str(a["unit_type_id"]))
	var stranded_mod: float = m._get_stranded_attack_mod(a)
	var cheat_mult: float = m.get_demo_attack_multiplier()
	dmg = maxi(1, int(float(dmg) * naval_atk_mod * naval_def_mod * stranded_mod * cheat_mult))
	var effective_atk_v: Variant = dmg_info.get("effective_atk", null)
	var eff_atk: float = float(effective_atk_v) if effective_atk_v != null else float(DataManager.get_unit_type(str(a["unit_type_id"])).get("attack", 10))
	eff_atk *= cheat_mult
	if pass_has_structure:
		m._damage_pass_structure(def_cell, str(a["unit_type_id"]), eff_atk)
	# 城防伤害分流（WallCombatRules，与大地图 SiegeResolver 一致）
	if city_has_wall:
		var city_lv: int = int(m._city_level.get(def_cell, 3))
		var split: Dictionary = WallLib.split_damage_to_wall(dmg, str(a["unit_type_id"]), city_lv, true)
		var wall_dmg: int = maxi(1, int(split.get("wall_damage", 0)))
		var unit_dmg: int = maxi(0, dmg - wall_dmg)
		unit_dmg = mini(unit_dmg, int(d["hp"]))
		d["hp"] = int(d["hp"]) - unit_dmg
		m._damage_city_wall(def_cell, wall_dmg)
		m._city_attacked[def_cell] = true
	else:
		dmg = mini(dmg, int(d["hp"]))
		d["hp"] = int(d["hp"]) - dmg
	a["in_combat_this_turn"] = true
	d["in_combat_this_turn"] = true
	var amb: String = "（伏击！）" if bool(dmg_info.get("was_ambush", false)) else ""
	var fire_str: String = "（火攻！）" if is_fire and not bool(dmg_info.get("was_ambush", false)) else ""
	m._append_log("%s 攻击 %s，造成 %d 伤害%s%s" % [attacker_id, defender_id, dmg, amb, fire_str])
	# 火攻触发时施加烧伤 DOT
	if is_fire and not bool(dmg_info.get("was_ambush", false)):
		m._apply_burn(a, d)
	# 夹击/包围：持续状态统一重算（脱离时恢复）
	m._process_flanking_states()
	# ── 反击（§2.4）：防御方存活且为近战攻击时触发 ──
	var counter_dmg: int = 0
	if int(d["hp"]) > 0:
		var atk_type_id: String = str(a["unit_type_id"])
		var def_type_id: String = str(d["unit_type_id"])
		var is_ranged_atk: bool = m._combat_resolver.is_ranged_unit(atk_type_id)
		if m._combat_resolver.should_trigger_counter(def_type_id, is_ranged_atk):
			var atk_terrain2: String = m.terrain_at(atk_cell)
			var skills_c: Array = d.get("skills", []) if d.get("skills") is Array else []
			var c_atk_ctx: Dictionary = CtxLib.build_attack_ctx(
				str(d["faction_id"]), def_type_id, skills_c, season, false
			)
			var c_def_ctx: Dictionary = CtxLib.build_defense_ctx(
				str(a["faction_id"]), atk_type_id
			)
			var c_atk_udata: Dictionary = DataManager.get_unit_type(def_type_id)
			# 攻击方所在地形 crossing_rules
			var tdata_atk2: Dictionary = DataManager.get_terrain(atk_terrain2)
			var cr_atk: Variant = tdata_atk2.get("crossing_rules", null)
			if cr_atk is Dictionary:
				var cr_a: Dictionary = cr_atk as Dictionary
				c_atk_ctx["terrain_atk_offset"] = float(cr_a.get("atk_mod", 0.0))
				c_def_ctx["terrain_def_offset"] = float(cr_a.get("def_bonus", 0.0))
			# 远程单位被近战攻击时用 melee_attack
			if m._combat_resolver.is_ranged_unit(def_type_id):
				var melee_v: Variant = c_atk_udata.get("melee_attack", null)
				if melee_v != null:
					c_atk_ctx["override_attack"] = int(melee_v)
			var c_info: Dictionary = m._combat_resolver.compute_counter_attack(
				def_type_id, atk_type_id, atk_terrain2,
				def_morale, atk_morale, m._rng, c_atk_ctx, c_def_ctx,
			)
			counter_dmg = int(c_info.get("damage", 0))
			var c_naval: float = m._calc_naval_combat_mod(def_type_id, atk_type_id, def_cell, atk_cell)
			var c_strand: float = m._get_stranded_attack_mod(d)
			counter_dmg = maxi(1, int(float(counter_dmg) * c_naval * c_strand))
			counter_dmg = mini(counter_dmg, int(a["hp"]))
			a["hp"] = int(a["hp"]) - counter_dmg
			m._append_log("%s 反击 %s，造成 %d 伤害" % [defender_id, attacker_id, counter_dmg])

	if m.has_method("spend_unit_mp"):
		m.spend_unit_mp(a, atk_cost)
	else:
		a["mp_remaining"] = int(a.get("mp_remaining", 0)) - atk_cost
	if is_maa:
		a["attacks_this_turn"] = int(a.get("attacks_this_turn", 0)) + 1
		# 移动力耗尽时自动结束行动
		var left: int = int(m.unit_mp(a)) if m.has_method("unit_mp") else int(a["mp_remaining"])
		if left <= 0:
			a["acted"] = true
	else:
		a["acted"] = true
	if int(d["hp"]) <= 0:
		var dead_faction: String = str(d["faction_id"])
		m._remove_unit(defender_id)
		m._append_log("%s 被歼灭" % defender_id)
		# 士气事件：击杀+15，友军击杀+5，敌方阵亡-5
		var self_kill_v: Variant = DataManager.get_balance_param("unit_morale.morale_gain_on_self_kill")
		var ally_kill_v: Variant = DataManager.get_balance_param("unit_morale.morale_gain_on_ally_kill")
		var ally_death_v: Variant = DataManager.get_balance_param("unit_morale.morale_loss_on_ally_death")
		m._apply_morale_delta(a, int(self_kill_v) if self_kill_v != null else 15)
		m._apply_faction_morale(str(a["faction_id"]), attacker_id, int(ally_kill_v) if ally_kill_v != null else 5)
		m._apply_faction_morale(dead_faction, "", int(ally_death_v) if ally_death_v != null else -5)
		m._apply_combat_on_kill(a)
	# 攻击方被反击击杀
	if int(a["hp"]) <= 0:
		var atk_dead_faction: String = str(a["faction_id"])
		m._remove_unit(attacker_id)
		m._append_log("%s 被反击歼灭" % attacker_id)
		var ally_death_v2: Variant = DataManager.get_balance_param("unit_morale.morale_loss_on_ally_death")
		m._apply_faction_morale(atk_dead_faction, "", int(ally_death_v2) if ally_death_v2 != null else -5)
	m.state_changed.emit()
	# 发射战斗特效信号
	var effect_id: String = "fx_slash"
	if is_fire and not bool(dmg_info.get("was_ambush", false)):
		effect_id = "fx_fire"
	elif bool(dmg_info.get("was_ambush", false)):
		effect_id = "fx_critical"
	elif m._combat_resolver.is_ranged_unit(str(a["unit_type_id"])):
		effect_id = "fx_arrow_rain"
	elif m._is_siege_unit(str(a["unit_type_id"])):
		effect_id = "fx_siege"
	m.combat_effect_requested.emit(effect_id, def_cell, atk_cell)
	var w: String = m.check_victory()
	if w != "":
		m._finish(w)
	return {"ok": true, "damage": dmg, "was_ambush": dmg_info.get("was_ambush", false)}


func execute_city_wall_attack(attacker_id: String, cell: Vector2i) -> Dictionary:
	var a: Dictionary = m.get_unit_by_id(attacker_id)
	if a.is_empty():
		return {"ok": false, "reason": "no_unit"}
	if str(a["faction_id"]) != m._player_faction:
		return {"ok": false, "reason": "not_player"}
	if bool(a.get("acted", false)):
		return {"ok": false, "reason": "already_acted"}
	if not m._city_wall_hp.has(cell):
		return {"ok": false, "reason": "no_city"}
	var city_left: int = int(m._city_wall_hp[cell])
	if city_left <= 0:
		return {"ok": false, "reason": "city_already_breached"}
	var atk_cost: int = m.get_attack_move_cost()
	if int(a.get("mp_remaining", 0)) < atk_cost:
		return {"ok": false, "reason": "insufficient_mp"}
	var ac: Vector2i = Vector2i(int(a["q"]), int(a["r"]))
	var ug: Dictionary = DataManager.get_unit_type(str(a["unit_type_id"]))
	var base_range: int = int(ug.get("range", 1))
	var dist: int = HexLib.hex_distance_hex(ac, cell)
	var off_a: Vector2i = HexLib.axial_to_offset_odd_r(ac.x, ac.y)
	var off_c: Vector2i = HexLib.axial_to_offset_odd_r(cell.x, cell.y)
	var eff_range: int = MoveLib.effective_range(off_a, off_c, base_range)
	if dist < 1 or dist > eff_range:
		return {"ok": false, "reason": "out_of_range"}
	var eff_atk: float = float(ug.get("attack", 10))
	eff_atk *= m.get_demo_attack_multiplier()
	var city_lv: int = int(m._city_level.get(cell, 3))
	# 城市只有一份 HP；建筑墙只影响伤害结算，不单独挡进驻
	var dmg: int = WallLib.direct_wall_or_city_damage(eff_atk, str(a["unit_type_id"]), city_lv, city_left)
	m._damage_city_wall(cell, dmg)
	m._append_log("%s 攻击城市，造成 %d 伤害（城市 HP %d→%d）" % [
		attacker_id, dmg, city_left, int(m._city_wall_hp.get(cell, 0))
	])
	m._city_attacked[cell] = true
	a["mp_remaining"] = int(a.get("mp_remaining", 0)) - atk_cost
	a["acted"] = true
	if m.has_method("_recheck_city_capture_at"):
		m._recheck_city_capture_at(cell)
	m.state_changed.emit()
	m.combat_effect_requested.emit("fx_siege", cell, ac)
	return {"ok": true, "damage": dmg}


func compute_preview(attacker_id: String, defender_id_or_cell: Variant) -> Dictionary:
	var a: Dictionary = m.get_unit_by_id(attacker_id)
	if a.is_empty():
		return {}
	var atk_type: Dictionary = DataManager.get_unit_type(str(a["unit_type_id"]))
	var base_atk: int = int(atk_type.get("attack", 10))
	var atk_category: String = str(atk_type.get("category", ""))
	var atk_cell: Vector2i = Vector2i(int(a["q"]), int(a["r"]))
	var atk_terrain: String = m.terrain_at(atk_cell)
	var atk_morale: int = int(a.get("morale", 100))
	var atk_fid: String = str(a["faction_id"])

	# 防御方数据
	var d: Dictionary = {}
	var def_cell: Vector2i = Vector2i.ZERO
	var is_wall_attack: bool = false
	if defender_id_or_cell is Vector2i:
		is_wall_attack = true
		def_cell = defender_id_or_cell as Vector2i
	else:
		d = m.get_unit_by_id(str(defender_id_or_cell))
		if d.is_empty():
			return {}
		def_cell = Vector2i(int(d["q"]), int(d["r"]))

	var def_terrain: String = m.terrain_at(def_cell)
	var def_morale: int = int(d.get("morale", 100)) if not is_wall_attack else 100
	var base_def: int = 0
	var def_category: String = ""
	var def_fid: String = ""
	if not is_wall_attack:
		var def_type: Dictionary = DataManager.get_unit_type(str(d["unit_type_id"]))
		base_def = int(def_type.get("defense", 10))
		def_category = str(def_type.get("category", ""))
		def_fid = str(d["faction_id"])

	# --- 攻击加成明细 ---
	var atk_details: PackedStringArray = []
	var atk_buff: float = 1.0
	# 地形
	var tdata_atk: Dictionary = DataManager.get_terrain(atk_terrain)
	var t_atk_offset: float = float(tdata_atk.get("atk_mod", 1.0)) - 1.0
	if absf(t_atk_offset) > 0.001:
		atk_buff += t_atk_offset
		atk_details.append("地形 %+.0f%%" % (t_atk_offset * 100.0))
	# 士气
	var morale_atk_off: float = 0.0
	if atk_morale >= 130:
		morale_atk_off = 0.1
	elif atk_morale < 50:
		morale_atk_off = -0.1
	if absf(morale_atk_off) > 0.001:
		atk_buff += morale_atk_off
		atk_details.append("士气 %+.0f%%" % (morale_atk_off * 100.0))
	var national_morale_offset: float = _get_national_morale_atk_offset(atk_fid)
	if absf(national_morale_offset) > 0.001:
		atk_buff += national_morale_offset
		atk_details.append("民心 %+.0f%%" % (national_morale_offset * 100.0))
	var shortage_atk_offset: float = _get_grain_shortage_atk_offset(atk_fid)
	if absf(shortage_atk_offset) > 0.001:
		atk_buff += shortage_atk_offset
		atk_details.append("断粮 %+.0f%%" % (shortage_atk_offset * 100.0))
	# 火攻
	var is_fire: bool = m._can_fire_attack(def_terrain) and not is_wall_attack
	if is_fire:
		var fire_bonus_v: Variant = DataManager.get_balance_param("combat.fire_atk_bonus")
		var fire_bonus: float = float(fire_bonus_v) if fire_bonus_v != null else 0.4
		atk_buff += fire_bonus
		atk_details.append("火攻 +%d%%" % int(fire_bonus * 100.0))
	# 被动技能
	var passive_bonus: float = m._get_passive_skill_bonus(a.get("skills", []))
	if passive_bonus > 0.0:
		atk_buff += passive_bonus
		atk_details.append("技能 +%d%%" % int(passive_bonus * 100.0))
	# 科技
	var tech_atk: float = TechEffects.attack_modifier(atk_fid, atk_category)
	if absf(tech_atk) > 0.001:
		atk_buff += tech_atk
		atk_details.append("科技 %+.0f%%" % (tech_atk * 100.0))
	# 学派
	var atk_school: Dictionary = m._get_school_combat_bonus(atk_fid)
	var school_atk: float = float(atk_school.get("school_atk", 0.0))
	if absf(school_atk) > 0.001:
		atk_buff += school_atk
		atk_details.append("学派 %+.0f%%" % (school_atk * 100.0))

	var effective_atk: float = float(base_atk) * atk_buff
	if atk_morale < 20:
		effective_atk *= 0.5
		atk_details.append("崩溃 ×0.5")

	# --- 防御加成明细 ---
	var def_details: PackedStringArray = []
	var def_buff: float = 1.0
	if not is_wall_attack:
		var tdata_def: Dictionary = DataManager.get_terrain(def_terrain)
		var t_def_offset: float = float(tdata_def.get("def_mod", 1.0)) - 1.0
		if absf(t_def_offset) > 0.001:
			def_buff += t_def_offset
			def_details.append("地形 %+.0f%%" % (t_def_offset * 100.0))
		var shortage_def_offset: float = _get_grain_shortage_def_offset(def_fid)
		if absf(shortage_def_offset) > 0.001:
			def_buff += shortage_def_offset
			def_details.append("断粮 %+.0f%%" % (shortage_def_offset * 100.0))
		# 科技
		var tech_def: float = TechEffects.defense_modifier(def_fid, def_category)
		if absf(tech_def) > 0.001:
			def_buff += tech_def
			def_details.append("科技 %+.0f%%" % (tech_def * 100.0))
		# 学派
		var def_school: Dictionary = m._get_school_combat_bonus(def_fid)
		var school_def: float = float(def_school.get("school_def", 0.0))
		if absf(school_def) > 0.001:
			def_buff += school_def
			def_details.append("学派 %+.0f%%" % (school_def * 100.0))
		# 关隘
		var pass_has: bool = m._pass_hp.has(def_cell) and int(m._pass_hp[def_cell]) > 0
		if pass_has:
			var pass_def_v: Variant = DataManager.get_balance_param("fortification.pass_defense")
			var bdef: float = float(pass_def_v) / 100.0 if pass_def_v != null else 0.0
			def_buff += bdef
			def_details.append("关隘 +%d%%" % int(bdef * 100.0))
		# 城墙（建筑 defense_bonus 进城防，WallCombatRules 分流）
		var city_has: bool = m._city_wall_hp.has(def_cell) and int(m._city_wall_hp[def_cell]) > 0
		if city_has:
			var blds2: Array = []
			if "_city_buildings" in m:
				blds2 = m._city_buildings.get(def_cell, []) as Array
			var bdef2: float = BuildingFxLib.city_building_def_buff(
				blds2,
				int(m._city_wall_hp[def_cell]),
				int(m._city_wall_max_hp.get(def_cell, 0)),
				int(m._city_level.get(def_cell, 3))
			)
			def_buff += bdef2
			def_details.append("城防 +%d%%" % int(bdef2 * 100.0))
		# 士气防御崩溃
		if def_morale < 20:
			def_details.append("崩溃 ×0.5")

	var effective_def: float = float(base_def) * def_buff
	if def_morale < 20:
		effective_def *= 0.5

	# --- 克制 ---
	var counter: float = 1.0
	if not is_wall_attack:
		counter = m._combat_resolver.compute_counter_multiplier(str(a["unit_type_id"]), str(d["unit_type_id"]))

	# --- 伤害计算 ---
	var counter_dmg: float = effective_atk * counter
	var raw_dmg: float = maxf(counter_dmg - effective_def, 1.0)

	# 攻城城墙伤害（WallCombatRules 与大地图一致）
	var wall_dmg: int = 0
	var unit_dmg: int = 0
	if is_wall_attack:
		var split: Dictionary = WallLib.split_damage_to_wall(
			int(raw_dmg), str(a["unit_type_id"]), int(m._city_level.get(def_cell, 3)), true
		)
		wall_dmg = maxi(1, int(split.get("wall_damage", raw_dmg * 0.5)))
	else:
		# 海军修正
		var naval_atk_mod: float = m._calc_naval_combat_mod(str(a["unit_type_id"]), str(d["unit_type_id"]), atk_cell, def_cell)
		var naval_def_mod: float = m._calc_naval_defense_mod(str(d["unit_type_id"]), def_cell, str(a["unit_type_id"]))
		var stranded_mod: float = m._get_stranded_attack_mod(a)
		unit_dmg = maxi(1, int(raw_dmg * naval_atk_mod * naval_def_mod * stranded_mod))

	# --- 伤害浮动范围 ---
	var spread_lo: float = 0.9
	var spread_hi: float = 1.1
	var rlo_v: Variant = DataManager.get_balance_param("combat.base_random_spread_lo")
	var rhi_v: Variant = DataManager.get_balance_param("combat.base_random_spread_hi")
	if rlo_v != null: spread_lo = float(rlo_v)
	if rhi_v != null: spread_hi = float(rhi_v)
	# 远程精度修正
	if not is_wall_attack and m._combat_resolver.is_ranged_unit(str(a["unit_type_id"])):
		var terrain: Dictionary = DataManager.get_terrain(def_terrain)
		var accuracy: float = float(terrain.get("ranged_accuracy_mod", 0))
		var factor_v: Variant = DataManager.get_balance_param("combat.accuracy_spread_factor")
		var factor: float = float(factor_v) if factor_v != null else 0.001
		var offset: float = accuracy * factor
		spread_lo += offset
		spread_hi += offset
	var unit_dmg_lo: int = 0
	var unit_dmg_hi: int = 0
	if not is_wall_attack:
		var naval_all: float = m._calc_naval_combat_mod(str(a["unit_type_id"]), str(d["unit_type_id"]), atk_cell, def_cell) * m._calc_naval_defense_mod(str(d["unit_type_id"]), def_cell, str(a["unit_type_id"])) * m._get_stranded_attack_mod(a)
		unit_dmg_lo = maxi(1, int(raw_dmg * spread_lo * naval_all))
		unit_dmg_hi = maxi(1, int(raw_dmg * spread_hi * naval_all))

	# --- 反击预览 ---
	var counter_atk_dmg: int = 0
	var counter_atk_dmg_lo: int = 0
	var counter_atk_dmg_hi: int = 0
	var counter_details: PackedStringArray = []
	var can_counter: bool = false
	if not is_wall_attack and not d.is_empty():
		var atk_type_id2: String = str(a["unit_type_id"])
		var def_type_id2: String = str(d["unit_type_id"])
		var is_ranged2: bool = m._combat_resolver.is_ranged_unit(atk_type_id2)
		if m._combat_resolver.should_trigger_counter(def_type_id2, is_ranged2):
			can_counter = true
			# 反击方基础攻击
			var c_def_type: Dictionary = DataManager.get_unit_type(def_type_id2)
			var c_base_atk: int = int(c_def_type.get("attack", 10))
			if m._combat_resolver.is_ranged_unit(def_type_id2):
				var mv: Variant = c_def_type.get("melee_attack", null)
				if mv != null:
					c_base_atk = int(mv)
					counter_details.append("近战反击 %d" % c_base_atk)
			if counter_details.is_empty():
				counter_details.append("基础 %d" % c_base_atk)
			# 反击方攻击加成
			var c_atk_buff: float = 1.0
			var c_tdata: Dictionary = DataManager.get_terrain(atk_terrain)
			var c_t_off: float = float(c_tdata.get("atk_mod", 1.0)) - 1.0
			if absf(c_t_off) > 0.001:
				c_atk_buff += c_t_off
				counter_details.append("地形 %+.0f%%" % (c_t_off * 100.0))
			var c_mor_off: float = 0.0
			if def_morale >= 130: c_mor_off = 0.1
			elif def_morale < 50: c_mor_off = -0.1
			if absf(c_mor_off) > 0.001:
				c_atk_buff += c_mor_off
				counter_details.append("士气 %+.0f%%" % (c_mor_off * 100.0))
			var c_pass: float = m._get_passive_skill_bonus(d.get("skills", []))
			if c_pass > 0.0:
				c_atk_buff += c_pass
				counter_details.append("技能 +%d%%" % int(c_pass * 100.0))
			var c_tech: float = TechEffects.attack_modifier(def_fid, str(c_def_type.get("category", "")))
			if absf(c_tech) > 0.001:
				c_atk_buff += c_tech
				counter_details.append("科技 %+.0f%%" % (c_tech * 100.0))
			var c_sch: Dictionary = m._get_school_combat_bonus(def_fid)
			var c_sch_atk: float = float(c_sch.get("school_atk", 0.0))
			if absf(c_sch_atk) > 0.001:
				c_atk_buff += c_sch_atk
				counter_details.append("学派 %+.0f%%" % (c_sch_atk * 100.0))
			var c_eff_atk: float = float(c_base_atk) * c_atk_buff
			if def_morale < 20:
				c_eff_atk *= 0.5
				counter_details.append("崩溃 ×0.5")
			# 被反击方（攻击方）防御
			var c_atk_def: float = float(DataManager.get_unit_type(atk_type_id2).get("defense", 10))
			var c_def_buff: float = 1.0
			var c_tdata2: Dictionary = DataManager.get_terrain(atk_terrain)
			var c_td_off: float = float(c_tdata2.get("def_mod", 1.0)) - 1.0
			if absf(c_td_off) > 0.001:
				c_def_buff += c_td_off
			var c_tech_d: float = TechEffects.defense_modifier(atk_fid, atk_category)
			if absf(c_tech_d) > 0.001:
				c_def_buff += c_tech_d
			var c_sch_d: Dictionary = m._get_school_combat_bonus(atk_fid)
			var c_sch_def: float = float(c_sch_d.get("school_def", 0.0))
			if absf(c_sch_def) > 0.001:
				c_def_buff += c_sch_def
			var c_eff_def: float = c_atk_def * c_def_buff
			if atk_morale < 20:
				c_eff_def *= 0.5
			var c_counter_mult: float = m._combat_resolver.compute_counter_multiplier(def_type_id2, atk_type_id2)
			var c_raw: float = maxf(c_eff_atk * c_counter_mult - c_eff_def, 1.0)
			var c_naval: float = m._calc_naval_combat_mod(def_type_id2, atk_type_id2, def_cell, atk_cell)
			var c_strand: float = m._get_stranded_attack_mod(d)
			var c_nav_all: float = c_naval * c_strand
			counter_atk_dmg = maxi(1, int(c_raw * c_nav_all))
			# 反击浮动范围
			var c_sp_lo: float = 0.9
			var c_sp_hi: float = 1.1
			var cr_lo_v: Variant = DataManager.get_balance_param("combat.base_random_spread_lo")
			var cr_hi_v: Variant = DataManager.get_balance_param("combat.base_random_spread_hi")
			if cr_lo_v != null: c_sp_lo = float(cr_lo_v)
			if cr_hi_v != null: c_sp_hi = float(cr_hi_v)
			if m._combat_resolver.is_ranged_unit(def_type_id2):
				var c_terr: Dictionary = DataManager.get_terrain(atk_terrain)
				var c_acc: float = float(c_terr.get("ranged_accuracy_mod", 0))
				var c_fv: Variant = DataManager.get_balance_param("combat.accuracy_spread_factor")
				var c_f: float = float(c_fv) if c_fv != null else 0.001
				var c_off: float = c_acc * c_f
				c_sp_lo += c_off
				c_sp_hi += c_off
			counter_atk_dmg_lo = maxi(1, int(c_raw * c_sp_lo * c_nav_all))
			counter_atk_dmg_hi = maxi(1, int(c_raw * c_sp_hi * c_nav_all))

	return {
		"base_atk": base_atk,
		"effective_atk": effective_atk,
		"atk_details": atk_details,
		"base_def": base_def,
		"effective_def": effective_def,
		"def_details": def_details,
		"counter": counter,
		"raw_dmg": raw_dmg,
		"expected_dmg": wall_dmg if is_wall_attack else unit_dmg,
		"expected_dmg_lo": wall_dmg if is_wall_attack else unit_dmg_lo,
		"expected_dmg_hi": wall_dmg if is_wall_attack else unit_dmg_hi,
		"is_wall_attack": is_wall_attack,
		"wall_dmg": wall_dmg,
		"can_counter": can_counter,
		"counter_atk_dmg": counter_atk_dmg,
		"counter_atk_dmg_lo": counter_atk_dmg_lo,
		"counter_atk_dmg_hi": counter_atk_dmg_hi,
		"counter_details": counter_details,
	}
