extends RefCounted

## AI 战术回合执行器
## 从 TacticalSkirmishManager 提取，避免单文件超 2000 行。
## 持有 manager 引用，通过它访问所有战斗/移动/状态私有 API。
## 公共入口：run_turn()，由 TacticalSkirmishManager._run_ai_turn() 委派调用。

var m: Node


func initialize(manager: Node) -> void:
	m = manager


func run_turn() -> void:
	var enemies: Array[Dictionary] = []
	for u: Dictionary in m._units:
		if str(u["faction_id"]) == m._enemy_faction:
			enemies.append(u)

	# 烧伤 DOT 结算（先于士气恢复）
	m._process_burn_dot(m._enemy_faction)
	# 断粮结算
	m._process_supply_effects(m._enemy_faction)
	# 过滤掉已被烧伤/断粮致死的单位

	enemies = enemies.filter(func(e: Dictionary) -> bool: return e in m._units)
	# 敌方士气处理（与 begin_player_phase 对称）
	var morale_params_ai: Dictionary = {}
	var bp_ai: Variant = DataManager.get_balance_param("unit_morale")
	if bp_ai is Dictionary:
		morale_params_ai = bp_ai
	var recovery_turn_ai: int = int(morale_params_ai.get("morale_recovery_per_turn", 3))
	var recovery_city_ai: int = int(morale_params_ai.get("morale_recovery_in_city", 8))
	var natural_cap_ai: int = int(morale_params_ai.get("natural_recovery_cap", 100))
	var break_threshold_ai: int = int(morale_params_ai.get("morale_break_threshold", 20))
	var broken_hp_ratio_ai: float = float(morale_params_ai.get("broken_hp_loss_per_turn", 0.2))
	var broken_speed_mod_ai: float = float(morale_params_ai.get("broken_speed_mod", 0.5))

	for u: Dictionary in enemies:
		var current_morale: int = int(u.get("morale", 100))
		if current_morale < natural_cap_ai:
			var recovery: int = recovery_city_ai if m._is_in_own_city(u) else recovery_turn_ai
			u["morale"] = mini(current_morale + recovery, natural_cap_ai)
		if int(u.get("morale", 100)) > natural_cap_ai:
			u["morale"] = int(u.get("morale", 100)) - 1
		if int(u.get("morale", 100)) < break_threshold_ai:
			var max_hp: int = int(u.get("max_hp", 100))
			var hp_loss: int = int(float(max_hp) * broken_hp_ratio_ai)
			u["hp"] = maxi(1, int(u.get("hp", max_hp)) - hp_loss)

	for u: Dictionary in enemies:
		u["acted"] = false
		u["attacks_this_turn"] = 0

	var atk_cost_ai: int = m.get_attack_move_cost()
	for u: Dictionary in enemies:
		var uid: String = str(u["id"])
		var base_speed: int = int(u.get("speed", 3))
		var effective_speed: int = base_speed
		if int(u.get("morale", 100)) < break_threshold_ai:
			effective_speed = maxi(1, int(float(base_speed) * broken_speed_mod_ai))
		u["mp_remaining"] = effective_speed
		# 随机移动：消耗 mp_remaining
		var reach: Dictionary = m._dijkstra_reachable(Vector2i(int(u["q"]), int(u["r"])), int(u["mp_remaining"]), str(u["unit_type_id"]), uid, str(u["faction_id"]), u.get("skills", []))
		var candidates: Array[Vector2i] = []
		for pos: Variant in reach.keys():
			var p: Vector2i = pos as Vector2i
			if m._occupant_id_at(p) == "":
				candidates.append(p)
		if candidates.size() > 0:
			var pick_i: int = m._rng.randi_range(0, candidates.size() - 1)
			var dest: Vector2i = candidates[pick_i]
			var step_cost: int = int(reach[dest])
			u["mp_remaining"] = int(u["mp_remaining"]) - step_cost
			u["q"] = dest.x
			u["r"] = dest.y
			m._append_log("AI %s 移动至 (%d,%d)，剩余移动力 %d" % [uid, dest.x, dest.y, int(u["mp_remaining"])])
			m._check_enter_city(u)

		var wmid: String = m.check_victory()
		if wmid != "":
			m._finish(wmid)
			return

		# 进攻：需剩余移动力≥攻击额外消耗
		var ai_maa: Dictionary = m._get_move_after_attack_skill(u.get("skills", []))
		var ai_unit_atk_cost: int = int(ai_maa.get("attack_move_cost", 0)) if not ai_maa.is_empty() else atk_cost_ai
		var targets: Array[String] = []
		if int(u.get("mp_remaining", 0)) >= ai_unit_atk_cost:
			for o: Dictionary in m._units:
				if str(o["faction_id"]) == m._enemy_faction:
					continue
				if m._can_attack(u, o):
					targets.append(str(o["id"]))
		if targets.size() > 0:
			var t_id: String = targets[m._rng.randi_range(0, targets.size() - 1)]
			var defender: Dictionary = m.get_unit_by_id(t_id)
			var ai_def_cell: Vector2i = Vector2i(int(defender["q"]), int(defender["r"]))
			var def_ter: String = m.terrain_at(ai_def_cell)
			var ai_atk_morale: int = int(u.get("morale", 100))
			var ai_def_morale: int = int(defender.get("morale", 100))
			# AI 火攻判定
			var ai_atk_ctx: Dictionary = {}
			var ai_def_ctx: Dictionary = {}
			var ai_is_fire: bool = m._can_fire_attack(def_ter)
			if ai_is_fire:
				ai_atk_ctx = m._get_fire_attack_ctx()
			# 被动技能加成
			var ai_passive_bonus: float = m._get_passive_skill_bonus(u.get("skills", []))
			if ai_passive_bonus > 0.0:
				ai_atk_ctx["unit_ability_bonus"] = ai_atk_ctx.get("unit_ability_bonus", 0.0) + ai_passive_bonus
			# 科技战斗修正
			var ai_atk_udata: Dictionary = DataManager.get_unit_type(str(u["unit_type_id"]))
			var ai_tech_atk: float = TechSystem.get_attack_modifier(str(ai_atk_udata.get("category", "")))
			if ai_tech_atk != 0.0:
				ai_atk_ctx["tech_atk"] = ai_tech_atk
			var ai_def_udata: Dictionary = DataManager.get_unit_type(str(defender["unit_type_id"]))
			var ai_tech_def: float = TechSystem.get_defense_modifier(str(ai_def_udata.get("category", "")))
			if ai_tech_def != 0.0:
				ai_def_ctx["tech_def"] = ai_tech_def
			# 学派战斗修正
			var ai_atk_school: Dictionary = m._get_school_combat_bonus(str(u["faction_id"]))
			if ai_atk_school.get("school_atk", 0.0) != 0.0:
				ai_atk_ctx["school_atk"] = ai_atk_school["school_atk"]
			var ai_def_school: Dictionary = m._get_school_combat_bonus(str(defender["faction_id"]))
			if ai_def_school.get("school_def", 0.0) != 0.0:
				ai_def_ctx["school_def"] = ai_def_school["school_def"]
			# 关隘 crossing_rules 修正
			var ai_tdata_def: Dictionary = DataManager.get_terrain(def_ter)
			var ai_cr: Variant = ai_tdata_def.get("crossing_rules", null)
			if ai_cr is Dictionary:
				var ai_cr_dict: Dictionary = ai_cr as Dictionary
				ai_atk_ctx["terrain_atk_offset"] = ai_atk_ctx.get("terrain_atk_offset", 0.0) + float(ai_cr_dict.get("atk_mod", 0.0))
				ai_def_ctx["terrain_def_offset"] = ai_def_ctx.get("terrain_def_offset", 0.0) + float(ai_cr_dict.get("def_bonus", 0.0))
			# 关隘结构防御
			var ai_pass_has_structure: bool = m._pass_hp.has(ai_def_cell) and int(m._pass_hp[ai_def_cell]) > 0
			if ai_pass_has_structure:
				var ai_pass_def_v: Variant = DataManager.get_balance_param("fortification.pass_defense")
				ai_def_ctx["building_def"] = ai_def_ctx.get("building_def", 0.0) + float(ai_pass_def_v) / 100.0
			# 城防防御加成
			var ai_city_has_wall: bool = m._city_wall_hp.has(ai_def_cell) and int(m._city_wall_hp[ai_def_cell]) > 0
			if ai_city_has_wall:
				var ai_city_lvl: int = int(m._city_level.get(ai_def_cell, 3))
				var ai_city_levels_all: Variant = DataManager.get_balance_param("city_levels")
				var ai_city_def_data: Dictionary = {}
				if ai_city_levels_all is Dictionary:
					ai_city_def_data = (ai_city_levels_all as Dictionary).get(str(ai_city_lvl), {})
				var ai_city_def: float = float(ai_city_def_data.get("city_defense", 45))
				var ai_wall_ratio: float = float(m._city_wall_hp[ai_def_cell]) / float(m._city_wall_max_hp[ai_def_cell]) if int(m._city_wall_max_hp[ai_def_cell]) > 0 else 1.0
				var ai_min_r_v: Variant = DataManager.get_balance_param("city_combat.wall_defense_min_ratio")
				var ai_min_r: float = float(ai_min_r_v) if ai_min_r_v != null else 0.5
				var ai_eff_ratio: float = maxf(ai_wall_ratio, ai_min_r)
				ai_def_ctx["building_def"] = ai_def_ctx.get("building_def", 0.0) + ai_city_def * ai_eff_ratio / 100.0
			var dmg_i: Dictionary = m._combat_resolver.compute_damage(
				str(u["unit_type_id"]),
				str(defender["unit_type_id"]),
				def_ter,
				ai_atk_morale,
				ai_def_morale,
				m._rng,
				ai_atk_ctx,
				ai_def_ctx,
			)
			var ai_dmg: int = int(dmg_i.get("damage", 0))
			# 海军战斗最终乘算 + 搁浅攻击修正
			var ai_atk_cell: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
			var ai_naval_atk: float = m._calc_naval_combat_mod(str(u["unit_type_id"]), str(defender["unit_type_id"]), ai_atk_cell, ai_def_cell)
			var ai_naval_def: float = m._calc_naval_defense_mod(str(defender["unit_type_id"]), ai_def_cell, str(u["unit_type_id"]))
			var ai_stranded: float = m._get_stranded_attack_mod(u)
			ai_dmg = maxi(1, int(float(ai_dmg) * ai_naval_atk * ai_naval_def * ai_stranded))
			var ai_eff_atk_v: Variant = dmg_i.get("effective_atk", null)
			var ai_eff_atk: float = float(ai_eff_atk_v) if ai_eff_atk_v != null else float(DataManager.get_unit_type(str(u["unit_type_id"])).get("attack", 10))
			# 关隘结构伤害
			if ai_pass_has_structure:
				m._damage_pass_structure(ai_def_cell, str(u["unit_type_id"]), ai_eff_atk)
			# 城防伤害分流
			if ai_city_has_wall:
				var ai_split_v: Variant = DataManager.get_balance_param("city_combat.damage_split_wall")
				var ai_split: float = float(ai_split_v) if ai_split_v != null else 0.5
				var ai_siege_v: Variant = DataManager.get_balance_param("city_combat.siege_damage_multiplier")
				var ai_siege_m: float = float(ai_siege_v) if ai_siege_v != null else 3.0
				var ai_sf: float = ai_siege_m if m._is_siege_unit(str(u["unit_type_id"])) else 1.0
				var ai_wall_dmg: int = maxi(1, int(float(ai_dmg) * ai_split * ai_sf))
				var ai_unit_dmg: int = ai_dmg - ai_wall_dmg
				ai_unit_dmg = mini(ai_unit_dmg, int(defender["hp"]))
				defender["hp"] = int(defender["hp"]) - ai_unit_dmg
				m._damage_city_wall(ai_def_cell, ai_wall_dmg)
				m._city_attacked[ai_def_cell] = true
			else:
				ai_dmg = mini(ai_dmg, int(defender["hp"]))
				defender["hp"] = int(defender["hp"]) - ai_dmg
			u["in_combat_this_turn"] = true
			defender["in_combat_this_turn"] = true
			var amb2: String = "（伏击！）" if bool(dmg_i.get("was_ambush", false)) else ""
			var fire2: String = "（火攻！）" if ai_is_fire and not bool(dmg_i.get("was_ambush", false)) else ""
			m._append_log("AI %s 攻击 %s，%d 伤%s%s" % [uid, t_id, ai_dmg, amb2, fire2])
			# AI 火攻施加烧伤 DOT
			if ai_is_fire and not bool(dmg_i.get("was_ambush", false)):
				m._apply_burn(u, defender)
			# 夹击/包围：受伤后检测并应用士气惩罚
			var flanking_delta_ai: int = m._check_flanking(defender)
			if flanking_delta_ai != 0:
				m._apply_morale_delta(defender, flanking_delta_ai)
				if flanking_delta_ai <= -50:
					m._append_log("%s 被包围！士气大幅下降" % t_id)
				else:
					m._append_log("%s 遭受夹击！士气下降" % t_id)
			if int(defender["hp"]) <= 0:
				var dead_faction_ai: String = str(defender["faction_id"])
				m._remove_unit(t_id)
				m._append_log("%s 被歼灭" % t_id)
				# 士气事件：击杀+15，友军击杀+5，敌方阵亡-5
				var self_kill_v2: Variant = DataManager.get_balance_param("unit_morale.morale_gain_on_self_kill")
				var ally_kill_v2: Variant = DataManager.get_balance_param("unit_morale.morale_gain_on_ally_kill")
				var ally_death_v2: Variant = DataManager.get_balance_param("unit_morale.morale_loss_on_ally_death")
				m._apply_morale_delta(u, int(self_kill_v2) if self_kill_v2 != null else 15)
				m._apply_faction_morale(str(u["faction_id"]), uid, int(ally_kill_v2) if ally_kill_v2 != null else 5)
				m._apply_faction_morale(dead_faction_ai, "", int(ally_death_v2) if ally_death_v2 != null else -5)
				m._apply_combat_on_kill(u)
			u["mp_remaining"] = int(u.get("mp_remaining", 0)) - ai_unit_atk_cost
			if not ai_maa.is_empty():
				u["attacks_this_turn"] = int(u.get("attacks_this_turn", 0)) + 1
		u["acted"] = true

		var wmid2: String = m.check_victory()
		if wmid2 != "":
			m._finish(wmid2)
			return

	# AI 溃退处理：崩溃态敌方单位自动移向友方城市
	var break_v_ai: Variant = DataManager.get_balance_param("unit_morale.morale_break_threshold")
	var break_thr_ai: int = int(break_v_ai) if break_v_ai != null else 20
	var ai_rout_units: Array[Dictionary] = []
	for u2: Dictionary in m._units:
		if str(u2["faction_id"]) == m._enemy_faction and int(u2.get("morale", 100)) < break_thr_ai:
			ai_rout_units.append(u2)
	for ru: Dictionary in ai_rout_units:
		if ru in m._units:
			m._execute_rout(ru)
	# 治疗结算：先治疗（检查战斗标记），后重置标记为下回合准备
	m._process_healing(m._enemy_faction)
	m._reset_combat_flags(m._enemy_faction)
	# 箭塔自动攻击
	m._process_arrow_towers()

	m.state_changed.emit()
