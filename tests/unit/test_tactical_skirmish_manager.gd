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


func test_skirmish_tile_textures_resolve() -> void:
	var tt: Texture2D = SkirmishTileTextures.terrain_texture("plains")
	assert_not_null(tt, "平原地形贴图应可加载")
	var ut: Texture2D = SkirmishTileTextures.unit_texture("cavalry")
	assert_not_null(ut, "骑兵占位贴图应可加载")
	var cq: Texture2D = SkirmishTileTextures.capital_texture("qin")
	var cz: Texture2D = SkirmishTileTextures.capital_texture("zhao")
	assert_not_null(cq, "秦国首都战术贴图应可加载")
	assert_not_null(cz, "赵国首都战术贴图应可加载")
