extends GutTest

func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()


func test_start_skirmish_spawns_four_units() -> void:
	TacticalSkirmishManager.start_skirmish()
	assert_true(TacticalSkirmishManager.is_active())
	assert_eq(TacticalSkirmishManager.get_units().size(), 4)


func test_player_unit_has_reachable_tiles_on_plains() -> void:
	TacticalSkirmishManager.start_skirmish()
	var reach: Dictionary = TacticalSkirmishManager.get_reachable_cells("mvp_p1")
	assert_true(reach.size() > 0, "平原步兵应有可移动格")


func test_attack_move_cost_is_positive_from_balance() -> void:
	TacticalSkirmishManager.start_skirmish()
	var c: int = TacticalSkirmishManager.get_attack_move_cost()
	assert_true(c >= 1, "攻击额外移动力应为正整数")


func test_luoyi_siege_demo_starts_with_wall_and_siege_units() -> void:
	var cfg: Dictionary = DataManager.get_skirmish_scenario(DemoFlow.get_recommended_scenario_id())
	TacticalSkirmishManager.start_skirmish_with_config(cfg.duplicate(true), DemoFlow.get_recommended_season())
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var has_siege_unit: bool = false
	for unit: Dictionary in TacticalSkirmishManager.get_units():
		var unit_type_id: String = str(unit.get("unit_type_id", ""))
		if unit_type_id == "battering_ram" or unit_type_id == "siege":
			has_siege_unit = true
			break

	assert_true(TacticalSkirmishManager.is_active(), "洛邑攻城 Demo 应能正常启动")
	assert_gt(TacticalSkirmishManager.get_city_wall_hp(enemy_city), 0, "洛邑城应初始化城墙 HP")
	assert_true(has_siege_unit, "洛邑攻城 Demo 应生成至少一个攻城器械")


func test_skirmish_tile_textures_resolve() -> void:
	var tt: Texture2D = SkirmishTileTextures.terrain_texture("plains")
	assert_not_null(tt, "平原地形贴图应可加载")
	var ut: Texture2D = SkirmishTileTextures.unit_texture("cavalry")
	assert_not_null(ut, "骑兵占位贴图应可加载")
	var cq: Texture2D = SkirmishTileTextures.capital_texture("qin")
	var cz: Texture2D = SkirmishTileTextures.capital_texture("zhao")
	assert_not_null(cq, "秦国首都战术贴图应可加载")
	assert_not_null(cz, "赵国首都战术贴图应可加载")
