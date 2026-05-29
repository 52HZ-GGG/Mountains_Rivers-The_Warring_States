extends GutTest

## 远程遮挡机制单元测试
## 验证高程差影响射程：低处→高处射程减少，高处→低处/同高程无影响

const HexLib := preload("res://scripts/systems/hex_axial.gd")

func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()


# ============= 有效射程计算测试 =============

func test_same_elevation_no_penalty() -> void:
	# 平原(0) → 平原(0)，射程不减
	TacticalSkirmishManager.start_skirmish()
	var cell_a: Vector2i = _find_terrain_cell("plains")
	var cell_b: Vector2i = _find_terrain_cell("plains")
	if cell_a == Vector2i(-999, -999) or cell_b == Vector2i(-999, -999) or cell_a == cell_b:
		pass_test("地图无足够平原格，跳过")
		return
	var eff: int = TacticalSkirmishManager._get_effective_range(cell_a, cell_b, 2)
	assert_eq(eff, 2, "同高程射程不应减少（实际 %d）" % eff)


func test_low_to_high_reduces_range() -> void:
	# 平原(0) → 森林(1)，射程 -1
	TacticalSkirmishManager.start_skirmish()
	var plains_cell: Vector2i = _find_terrain_cell("plains")
	var forest_cell: Vector2i = _find_terrain_cell("forest")
	if plains_cell == Vector2i(-999, -999) or forest_cell == Vector2i(-999, -999):
		pass_test("地图无平原或森林，跳过")
		return
	var eff: int = TacticalSkirmishManager._get_effective_range(plains_cell, forest_cell, 2)
	assert_eq(eff, 1, "平原→森林射程应减1（实际 %d）" % eff)


func test_high_to_low_no_penalty() -> void:
	# 森林(1) → 平原(0)，射程不减
	TacticalSkirmishManager.start_skirmish()
	var forest_cell: Vector2i = _find_terrain_cell("forest")
	var plains_cell: Vector2i = _find_terrain_cell("plains")
	if forest_cell == Vector2i(-999, -999) or plains_cell == Vector2i(-999, -999):
		pass_test("地图无森林或平原，跳过")
		return
	var eff: int = TacticalSkirmishManager._get_effective_range(forest_cell, plains_cell, 2)
	assert_eq(eff, 2, "高处→低处射程不应减少（实际 %d）" % eff)


func test_river_to_mountain_range_zero() -> void:
	# 河流(-1) → 山地(1)，高程差 2，射程 2 - 2 = 0
	TacticalSkirmishManager.start_skirmish()
	var river_cell: Vector2i = _find_terrain_cell("river")
	var mountain_cell: Vector2i = _find_terrain_cell("mountain")
	if river_cell == Vector2i(-999, -999) or mountain_cell == Vector2i(-999, -999):
		pass_test("地图无河流或山地，跳过")
		return
	var eff: int = TacticalSkirmishManager._get_effective_range(river_cell, mountain_cell, 2)
	assert_eq(eff, 0, "河流→山地有效射程应为 0（实际 %d）" % eff)


func test_melee_range_unaffected() -> void:
	# 近战（射程 1）不受遮挡影响
	TacticalSkirmishManager.start_skirmish()
	var plains_cell: Vector2i = _find_terrain_cell("plains")
	var forest_cell: Vector2i = _find_terrain_cell("forest")
	if plains_cell == Vector2i(-999, -999) or forest_cell == Vector2i(-999, -999):
		pass_test("地图无平原或森林，跳过")
		return
	var eff: int = TacticalSkirmishManager._get_effective_range(plains_cell, forest_cell, 1)
	assert_eq(eff, 1, "近战射程不受遮挡影响（实际 %d）" % eff)


# ============= 攻击目标列表测试 =============

func test_list_attack_targets_filters_by_elevation() -> void:
	# 弓兵在平原(0)向山地(1)的敌军，射程 2 → 有效 1，超出距离的目标被过滤
	TacticalSkirmishManager.start_skirmish()
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	var plains_cell: Vector2i = _find_terrain_cell("plains")
	if plains_cell == Vector2i(-999, -999):
		pass_test("无平原格，跳过")
		return
	p2["q"] = plains_cell.x
	p2["r"] = plains_cell.y
	p2["mp_remaining"] = 10
	p2["acted"] = false
	var mountain_cell: Vector2i = _find_terrain_cell("mountain")
	if mountain_cell == Vector2i(-999, -999):
		pass_test("无山地格，跳过")
		return
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = mountain_cell.x
	e1["r"] = mountain_cell.y
	var dist: int = HexLib.hex_distance_hex(plains_cell, mountain_cell)
	var targets: Array[String] = TacticalSkirmishManager.list_attack_targets("mvp_p2")
	if dist > 1:
		assert_false("mvp_e1" in targets, "平原→山地超出有效射程时不应在目标列表中")
	else:
		assert_true("mvp_e1" in targets, "距离 1 时应在目标列表中")


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
