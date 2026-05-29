extends GutTest

## 海军战斗机制单元测试
## 验证水军/陆军战斗修正、水军移动限制、河流冻结搁浅

const HexLib := preload("res://scripts/systems/hex_axial.gd")

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()
	_rng.seed = 42


# ============= 海军分类判断测试 =============

func test_navy_unit_is_navy() -> void:
	assert_true(TacticalSkirmishManager._is_navy("mengchong"), "蒙冲应为水军")
	assert_true(TacticalSkirmishManager._is_navy("great_wing"), "大翼应为水军")
	assert_true(TacticalSkirmishManager._is_navy("tower_ship"), "楼船应为水军")


func test_land_unit_is_not_navy() -> void:
	assert_false(TacticalSkirmishManager._is_navy("infantry"), "步兵不应为水军")
	assert_false(TacticalSkirmishManager._is_navy("cavalry"), "骑兵不应为水军")
	assert_false(TacticalSkirmishManager._is_navy("archer"), "弓兵不应为水军")


# ============= 水面地形判断测试 =============

func test_river_is_water_terrain() -> void:
	TacticalSkirmishManager.start_skirmish()
	var river: Vector2i = _find_terrain_cell("river")
	if river == Vector2i(-999, -999):
		pass_test("地图无河流，跳过")
		return
	assert_true(TacticalSkirmishManager._is_water_terrain(river), "河流应为水面地形")


func test_ford_is_water_terrain() -> void:
	TacticalSkirmishManager.start_skirmish()
	var ford: Vector2i = _find_terrain_cell("ford")
	if ford == Vector2i(-999, -999):
		pass_test("地图无渡口，跳过")
		return
	assert_true(TacticalSkirmishManager._is_water_terrain(ford), "渡口应为水面地形")


func test_plains_is_not_water() -> void:
	TacticalSkirmishManager.start_skirmish()
	var plains: Vector2i = _find_terrain_cell("plains")
	if plains == Vector2i(-999, -999):
		pass_test("地图无平原，跳过")
		return
	assert_false(TacticalSkirmishManager._is_water_terrain(plains), "平原不应为水面地形")


# ============= 海军战斗修正测试 =============

func test_navy_vs_land_attack_mod() -> void:
	var mod: float = TacticalSkirmishManager._calc_naval_combat_mod("mengchong", "infantry", Vector2i(0, 0), Vector2i(1, 0))
	assert_eq(mod, 0.5, "水军攻击陆地应 ×0.5（实际 %.1f）" % mod)


func test_land_vs_navy_attack_mod() -> void:
	var mod: float = TacticalSkirmishManager._calc_naval_combat_mod("infantry", "mengchong", Vector2i(0, 0), Vector2i(1, 0))
	assert_eq(mod, 0.5, "陆军攻击水军应 ×0.5（实际 %.1f）" % mod)


func test_navy_vs_navy_no_mod() -> void:
	var mod: float = TacticalSkirmishManager._calc_naval_combat_mod("mengchong", "great_wing", Vector2i(0, 0), Vector2i(1, 0))
	assert_eq(mod, 1.0, "水军 vs 水军应无修正（实际 %.1f）" % mod)


func test_land_vs_land_no_mod() -> void:
	var mod: float = TacticalSkirmishManager._calc_naval_combat_mod("infantry", "cavalry", Vector2i(0, 0), Vector2i(1, 0))
	assert_eq(mod, 1.0, "陆军 vs 陆军应无修正（实际 %.1f）" % mod)


# ============= 搁浅状态测试 =============

func test_navy_on_river_in_winter_is_stranded() -> void:
	TacticalSkirmishManager.start_skirmish()
	TacticalSkirmishManager.set_season("winter")
	var river: Vector2i = _find_terrain_cell("river")
	if river == Vector2i(-999, -999):
		pass_test("地图无河流，跳过")
		return
	var unit: Dictionary = {"unit_type_id": "mengchong", "q": river.x, "r": river.y}
	assert_true(TacticalSkirmishManager._is_unit_stranded(unit), "冬季水军在河流上应搁浅")


func test_navy_on_river_in_summer_not_stranded() -> void:
	TacticalSkirmishManager.start_skirmish()
	TacticalSkirmishManager.set_season("summer")
	var river: Vector2i = _find_terrain_cell("river")
	if river == Vector2i(-999, -999):
		pass_test("地图无河流，跳过")
		return
	var unit: Dictionary = {"unit_type_id": "mengchong", "q": river.x, "r": river.y}
	assert_false(TacticalSkirmishManager._is_unit_stranded(unit), "夏季水军在河流上不应搁浅")


func test_land_unit_on_river_not_stranded() -> void:
	TacticalSkirmishManager.start_skirmish()
	TacticalSkirmishManager.set_season("winter")
	var river: Vector2i = _find_terrain_cell("river")
	if river == Vector2i(-999, -999):
		pass_test("地图无河流，跳过")
		return
	var unit: Dictionary = {"unit_type_id": "infantry", "q": river.x, "r": river.y}
	assert_false(TacticalSkirmishManager._is_unit_stranded(unit), "陆军不应搁浅")


# ============= 搁浅攻击限制测试 =============

func test_stranded_unit_cannot_initiate_attack() -> void:
	TacticalSkirmishManager.start_skirmish()
	TacticalSkirmishManager.set_season("winter")
	var river: Vector2i = _find_terrain_cell("river")
	if river == Vector2i(-999, -999):
		pass_test("地图无河流，跳过")
		return
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["unit_type_id"] = "mengchong"
	p1["q"] = river.x
	p1["r"] = river.y
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = river.x + 1
	e1["r"] = river.y
	assert_false(TacticalSkirmishManager._can_attack(p1, e1), "搁浅单位不应能主动攻击")


func test_stranded_attack_mod_is_0_3() -> void:
	TacticalSkirmishManager.start_skirmish()
	TacticalSkirmishManager.set_season("winter")
	var river: Vector2i = _find_terrain_cell("river")
	if river == Vector2i(-999, -999):
		pass_test("地图无河流，跳过")
		return
	var unit: Dictionary = {"unit_type_id": "mengchong", "q": river.x, "r": river.y}
	var mod: float = TacticalSkirmishManager._get_stranded_attack_mod(unit)
	assert_eq(mod, 0.3, "搁浅攻击修正应为 0.3（实际 %.1f）" % mod)


func test_non_stranded_attack_mod_is_1() -> void:
	TacticalSkirmishManager.start_skirmish()
	var unit: Dictionary = {"unit_type_id": "infantry", "q": 0, "r": 0}
	var mod: float = TacticalSkirmishManager._get_stranded_attack_mod(unit)
	assert_eq(mod, 1.0, "非搁浅攻击修正应为 1.0（实际 %.1f）" % mod)


# ============= 辅助函数 =============

func _find_terrain_cell(terrain_id: String) -> Vector2i:
	var units: Array[Dictionary] = TacticalSkirmishManager.get_units()
	var occupied: Array[Vector2i] = []
	for u: Dictionary in units:
		occupied.append(Vector2i(int(u["q"]), int(u["r"])))
	for row: int in range(7):
		for col: int in range(7):
			var cell: Vector2i = HexLib.offset_odd_r_to_axial(col, row)
			if cell in occupied:
				continue
			if TacticalSkirmishManager.terrain_at(cell) == terrain_id:
				return cell
	return Vector2i(-999, -999)
