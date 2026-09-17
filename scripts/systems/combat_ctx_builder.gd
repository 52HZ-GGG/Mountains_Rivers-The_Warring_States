class_name CombatCtxBuilder

## 共享战斗修正组装（统一规范 §4）
## 大地图与演武必须经此构建 atk_ctx / def_ctx，禁止各拼一套。
## 来源系统为大地图权威：Tech / School / Minister / GameManager，实时只读。


static func add_offset(ctx: Dictionary, key: String, offset: float) -> void:
	if absf(offset) <= 0.001:
		return
	ctx[key] = float(ctx.get(key, 0.0)) + offset


static func national_morale_atk_offset(faction_id: String) -> float:
	if not GameManager.is_player_faction(faction_id):
		return 0.0
	var morale_mod: float = float(GameManager.get_morale_threshold_effect().get("morale_atk_mod", 1.0))
	return morale_mod - 1.0


static func grain_shortage_atk_offset(faction_id: String) -> float:
	return GameManager.get_grain_shortage_attack_mod(faction_id) - 1.0


static func grain_shortage_def_offset(faction_id: String) -> float:
	return GameManager.get_grain_shortage_defense_mod(faction_id) - 1.0


static func school_combat_bonus(faction_id: String) -> Dictionary:
	return {
		"school_atk": SchoolManager.get_effect_float(faction_id, "attack_bonus"),
		"school_def": SchoolManager.get_effect_float(faction_id, "defense_bonus"),
	}


static func passive_skill_bonus(skills: Array) -> float:
	var bonus: float = 0.0
	for skill: Variant in skills:
		var s: Dictionary = skill as Dictionary
		if s.get("type", "") == "passive":
			bonus += float(s.get("value", 0.0))
	return bonus


static func tech_attack_modifier(unit_type_id: String) -> float:
	var udata: Dictionary = DataManager.get_unit_type(unit_type_id)
	return TechSystem.get_attack_modifier(str(udata.get("category", "")))


static func tech_defense_modifier(unit_type_id: String) -> float:
	var udata: Dictionary = DataManager.get_unit_type(unit_type_id)
	return TechSystem.get_defense_modifier(str(udata.get("category", "")))


## 组装攻击方修正（不含地形/关隘/城墙——由调用方或 compute_damage 补）
static func build_attack_ctx(
	attacker_faction: String,
	attacker_unit_type_id: String,
	attacker_skills: Array,
	season: String = "",
	is_fire: bool = false
) -> Dictionary:
	var atk_ctx: Dictionary = {}
	if is_fire:
		atk_ctx = build_fire_attack_ctx(season)
	add_offset(atk_ctx, "faction_atk", national_morale_atk_offset(attacker_faction))
	add_offset(atk_ctx, "faction_atk", grain_shortage_atk_offset(attacker_faction))
	var passive: float = passive_skill_bonus(attacker_skills)
	if passive > 0.0:
		atk_ctx["unit_ability_bonus"] = float(atk_ctx.get("unit_ability_bonus", 0.0)) + passive
	var tech_atk: float = tech_attack_modifier(attacker_unit_type_id)
	if tech_atk != 0.0:
		atk_ctx["tech_atk"] = tech_atk
	var school: Dictionary = school_combat_bonus(attacker_faction)
	if float(school.get("school_atk", 0.0)) != 0.0:
		add_offset(atk_ctx, "school_atk", float(school["school_atk"]))
	var mil_atk: float = MinisterManager.get_faction_military_attack_bonus(attacker_faction)
	if mil_atk > 0.001:
		atk_ctx["minister_bravery_pct"] = mil_atk
	return atk_ctx


## 组装防御方修正
static func build_defense_ctx(
	defender_faction: String,
	defender_unit_type_id: String,
	defender_city_id: String = ""
) -> Dictionary:
	var def_ctx: Dictionary = {}
	add_offset(def_ctx, "faction_def", grain_shortage_def_offset(defender_faction))
	var tech_def: float = tech_defense_modifier(defender_unit_type_id)
	if tech_def != 0.0:
		def_ctx["tech_def"] = tech_def
	var school: Dictionary = school_combat_bonus(defender_faction)
	if float(school.get("school_def", 0.0)) != 0.0:
		add_offset(def_ctx, "school_def", float(school["school_def"]))
	# 文化 mismatch：只读 CityManager，不落演武状态（统一规范 §9）
	if defender_city_id != "" and CityManager.has_culture_mismatch(defender_city_id):
		var pen_v: Variant = DataManager.get_balance_param("culture.culture_mismatch_garrison_def_penalty")
		if pen_v != null:
			add_offset(def_ctx, "faction_def", float(pen_v))
	return def_ctx


static func build_fire_attack_ctx(season: String) -> Dictionary:
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
				if seasons.has(season):
					ctx["school_atk"] = float(bonus.get("value", 0.0))
	return ctx


static func can_fire_attack(defender_terrain_id: String, season: String) -> bool:
	var terrain: Dictionary = DataManager.get_terrain(defender_terrain_id)
	if bool(terrain.get("is_flammable", false)) or str(terrain.get("id", "")) == "forest":
		return season == "summer" or season == "autumn"
	# 数据未标 is_flammable 时按 fire_seasons + forest 判定
	var fire_seasons_v: Variant = DataManager.get_balance_param("combat.fire_seasons")
	var seasons: Array = ["summer", "autumn"]
	if fire_seasons_v is Array:
		seasons = fire_seasons_v as Array
	if not seasons.has(season):
		return false
	return str(terrain.get("id", "")) == "forest"
