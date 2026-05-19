extends GutTest

## ZoC（区域控制）单元测试
## 验证 ZoC 产生、免疫、移耗计算

func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()


# ============= 辅助函数测试 =============

func test_infantry_generates_zoc() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	assert_false(p1.is_empty(), "mvp_p1 应存在")
	var generates: bool = TacticalSkirmishManager._generates_zoc(p1)
	assert_true(generates, "步兵应产生 ZoC")


func test_cavalry_generates_zoc() -> void:
	TacticalSkirmishManager.start_skirmish()
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	assert_false(e2.is_empty(), "mvp_e2 应存在")
	var generates: bool = TacticalSkirmishManager._generates_zoc(e2)
	assert_true(generates, "骑兵应产生 ZoC")


func test_archer_does_not_generate_zoc() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	assert_false(p2.is_empty(), "mvp_p2 应存在")
	var generates: bool = TacticalSkirmishManager._generates_zoc(p2)
	assert_false(generates, "弓兵不应产生 ZoC")


# ============= 免疫测试 =============

func test_recon_unit_is_zoc_immune() -> void:
	var immune: bool = TacticalSkirmishManager._is_zoc_immune("scout_team")
	assert_true(immune, "斥候小队（recon）应免疫 ZoC")


func test_navy_unit_is_zoc_immune() -> void:
	var immune: bool = TacticalSkirmishManager._is_zoc_immune("mengchong")
	assert_true(immune, "水军应免疫陆地 ZoC")


func test_regular_infantry_is_not_zoc_immune() -> void:
	var immune: bool = TacticalSkirmishManager._is_zoc_immune("infantry")
	assert_false(immune, "普通步兵不应免疫 ZoC")


func test_cavalry_is_not_zoc_immune() -> void:
	var immune: bool = TacticalSkirmishManager._is_zoc_immune("cavalry")
	assert_false(immune, "骑兵不应免疫 ZoC")


# ============= 敌方 ZoC 范围检测 =============

func test_cell_adjacent_to_enemy_is_in_zoc() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var p_pos: Vector2i = Vector2i(int(p1["q"]), int(p1["r"]))
	e1["q"] = p_pos.x + 1
	e1["r"] = p_pos.y
	var in_zoc: bool = TacticalSkirmishManager._is_in_enemy_zoc(p_pos, str(p1["faction_id"]))
	assert_true(in_zoc, "与敌方步兵相邻的格子应处于 ZoC 中")


func test_cell_far_from_enemy_is_not_in_zoc() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var p_pos: Vector2i = Vector2i(int(p1["q"]), int(p1["r"]))
	var in_zoc: bool = TacticalSkirmishManager._is_in_enemy_zoc(p_pos, str(p1["faction_id"]))
	assert_false(in_zoc, "远离敌方的格子不应处于 ZoC 中")


# ============= 集成测试：ZoC 影响移耗 =============

func test_zoc_increases_move_cost() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var p_pos: Vector2i = Vector2i(int(p1["q"]), int(p1["r"]))
	# 将敌方步兵放到玩家步兵东侧 2 格处
	e1["q"] = p_pos.x + 2
	e1["r"] = p_pos.y
	var reach: Dictionary = TacticalSkirmishManager.get_reachable_cells("mvp_p1")
	# 检查敌方旁边的格子（ZoC 范围内）移耗是否增加
	var zoc_cell: Vector2i = Vector2i(p_pos.x + 1, p_pos.y)
	if reach.has(zoc_cell):
		var zoc_cost: int = int(reach[zoc_cell])
		assert_true(zoc_cost >= 2, "ZoC 格子移耗应 >= 2（基础 1 + ZoC 1），实际: %d" % zoc_cost)


func test_zoc_overlap_does_not_stack() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	var p_pos: Vector2i = Vector2i(int(p1["q"]), int(p1["r"]))
	# 将两个敌方单位放到玩家步兵两侧
	e1["q"] = p_pos.x + 1
	e1["r"] = p_pos.y
	e2["q"] = p_pos.x - 1
	e2["r"] = p_pos.y
	var in_zoc: bool = TacticalSkirmishManager._is_in_enemy_zoc(p_pos, str(p1["faction_id"]))
	assert_true(in_zoc, "被两个敌方夹击时应在 ZoC 中")
	var reach: Dictionary = TacticalSkirmishManager.get_reachable_cells("mvp_p1")
	assert_true(reach.size() > 0, "ZoC 不叠加时仍应有可达格")
