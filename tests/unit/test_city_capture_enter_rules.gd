extends GutTest

## 战斗系统.md：城市一份 HP；HP>0 不可进驻；HP=0 进驻即占领（同关隘）


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(GameManager.FACTION_IDS, "qin")
	TacticalSkirmishManager.reset_skirmish()
	TacticalSkirmishManager.start_skirmish()


func _enemy_city() -> Vector2i:
	return TacticalSkirmishManager.get_enemy_city()


func _clear_enemies_on(cell: Vector2i) -> void:
	for u: Dictionary in TacticalSkirmishManager.get_units().duplicate():
		if Vector2i(int(u["q"]), int(u["r"])) == cell:
			TacticalSkirmishManager._remove_unit(str(u["id"]))


func test_city_has_single_hp() -> void:
	var city: Vector2i = _enemy_city()
	var wall: int = TacticalSkirmishManager.get_city_wall_hp(city)
	var body: int = TacticalSkirmishManager.get_city_body_hp(city)
	assert_eq(wall, body, "城市应只有一份 HP（墙/体 API 同步）")
	assert_gt(wall, 0)


func test_cannot_enter_while_city_hp_positive() -> void:
	var city: Vector2i = _enemy_city()
	TacticalSkirmishManager._city_wall_hp[city] = 100
	TacticalSkirmishManager._city_body_hp[city] = 100
	_clear_enemies_on(city)
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = city.x - 1
	p1["r"] = city.y
	p1["mp_remaining"] = 10
	assert_false(TacticalSkirmishManager.get_reachable_cells("mvp_p1").has(city), "城市 HP>0 不可进驻")


func test_enter_and_capture_when_city_hp_zero() -> void:
	var city: Vector2i = _enemy_city()
	TacticalSkirmishManager._city_wall_hp[city] = 0
	TacticalSkirmishManager._city_body_hp[city] = 0
	_clear_enemies_on(city)
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = city.x - 1
	p1["r"] = city.y
	p1["mp_remaining"] = 10
	p1["acted"] = false
	var mv: Dictionary = TacticalSkirmishManager.try_move_unit("mvp_p1", city)
	assert_true(bool(mv.get("ok", false)), "城市 HP=0 应可进驻：%s" % str(mv))
	assert_gt(TacticalSkirmishManager.get_city_wall_hp(city), 0, "进驻占领后城市 HP 应恢复")
	assert_eq(p1["q"], city.x)
	assert_eq(p1["r"], city.y)


func test_zeroing_hp_allows_entry() -> void:
	# 模拟：先把城市 HP 打到 0，再移动
	var city: Vector2i = _enemy_city()
	TacticalSkirmishManager._city_wall_hp[city] = 30
	TacticalSkirmishManager._city_body_hp[city] = 30
	_clear_enemies_on(city)
	TacticalSkirmishManager._damage_city_wall(city, 9999)
	assert_eq(TacticalSkirmishManager.get_city_wall_hp(city), 0)
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = city.x - 1
	p1["r"] = city.y
	p1["mp_remaining"] = 10
	p1["acted"] = false
	assert_true(TacticalSkirmishManager.get_reachable_cells("mvp_p1").has(city), "HP 打空后应可进驻")
