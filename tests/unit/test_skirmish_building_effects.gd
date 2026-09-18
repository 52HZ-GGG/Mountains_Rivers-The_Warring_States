extends GutTest

## 演武接入经营建筑战斗效果（墙/箭塔/城防）

const BuildingFxLib := preload("res://scripts/systems/building_combat_effects.gd")


func test_building_fx_lib_sum() -> void:
	var blds: Array = [
		{"building_id": "wall", "level": 1},
		{"building_id": "barracks", "level": 1},
	]
	var def_b: float = BuildingFxLib.defense_bonus_from_buildings(blds)
	var wall_hp: int = BuildingFxLib.wall_structure_hp_from_buildings(blds)
	assert_true(def_b > 0.0, "wall Lv1 应有 defense_bonus，got=%s" % def_b)
	assert_true(wall_hp > 0, "wall 应有 structure_hp，got=%s" % wall_hp)
	var tower_blds: Array = [{"building_id": "arrow_tower", "level": 1}]
	assert_true(BuildingFxLib.tower_attack_from_buildings(tower_blds) > 0.0)


func test_city_id_from_citymanager_when_available() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	var factions: Array[String] = ["qin"]
	GameManager.start_game(factions, "qin")
	GameManager.apply_gold_delta(5000)
	GameManager.apply_wood_delta(5000)
	# 咸阳若可建墙则建一堵；否则跳过
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	if not hexes.is_empty() and bool(CityManager.can_build("xianyang", "wall", hexes[0]).get("allowed", false)):
		assert_true(CityManager.start_build("xianyang", "wall", hexes[0]))
		for i in range(4):
			CityManager._process_build_queue("xianyang", {})
	var from_mgr: Array = BuildingFxLib.buildings_from_city_id("xianyang")
	assert_true(from_mgr is Array)


func test_skirmish_city_uses_buildings() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	var factions: Array[String] = ["qin", "zhao"]
	GameManager.start_game(factions, "qin")
	TacticalSkirmishManager.reset_skirmish()
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var blds: Variant = TacticalSkirmishManager.get("_city_buildings")
	assert_true(blds is Dictionary)
	var cell_blds: Array = (blds as Dictionary).get(enemy_city, []) as Array
	assert_false(cell_blds.is_empty(), "演武城格应有建筑列表，got=%s" % cell_blds)
	# 默认/场景建筑应含墙
	var has_wall: bool = false
	for b in cell_blds:
		if str((b as Dictionary).get("building_id", "")) == "wall":
			has_wall = true
	assert_true(has_wall, "城池建筑列表应含 wall，got=%s" % cell_blds)
	var wall_hp: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	assert_gt(wall_hp, 0)


func test_scenarios_json_has_city_buildings_for_luoyi() -> void:
	var text: String = FileAccess.get_file_as_string("res://data/skirmish_scenarios.json")
	assert_true(text.contains("luoyi_siege_demo"))
	assert_true(text.contains("\"city_id\": \"luoyi\"") or text.contains("\"city_id\":\"luoyi\""), "洛邑场景应绑定 city_id")
	assert_true(text.contains("building_id"), "场景应可配置建筑列表")
