extends GutTest

## 实体建筑辖区系统（决策 #123）
## 坐标放置 / 槽位 / 可重复墙 / 通行规则 / 旧档迁移


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	TechSystem.reset()
	SchoolManager.reset()
	MinisterManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin"], "qin")
	GameManager.apply_gold_delta(5000)
	GameManager.apply_wood_delta(5000)


func test_jurisdiction_hexes_are_six_neighbors() -> void:
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	assert_eq(hexes.size(), 6, "辖区应为 6 个相邻格")
	var city: Dictionary = CityManager.get_city_state("xianyang")
	var col: int = int(city.get("hex_q", 0))
	var row: int = int(city.get("hex_r", 0))
	var expected: Dictionary = {}
	for nb: Vector2i in HexAxial.offset_visual_neighbors(col, row):
		expected[HexAxial.offset_odd_r_to_axial(nb.x, nb.y)] = true
	for cell: Vector2i in hexes:
		assert_true(expected.has(cell), "应为地图视觉邻格")


func test_start_build_places_physical_hex() -> void:
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	assert_true(hexes.size() > 0)
	var target: Vector2i = hexes[0]
	assert_true(CityManager.start_build("xianyang", "farm", target), "应在指定格开建")
	var city: Dictionary = CityManager.get_city_state("xianyang")
	var queue: Array = city.get("build_queue", [])
	assert_eq(queue.size(), 1)
	assert_eq(int(queue[0].get("hex_q", -1)), target.x, "队列应记录坐标 q")
	assert_eq(int(queue[0].get("hex_r", -1)), target.y, "队列应记录坐标 r")
	assert_eq(str(queue[0].get("is_upgrade", true)), "false", "应为新建")


func test_cannot_build_outside_jurisdiction() -> void:
	var far: Vector2i = CityManager.get_city_center_axial("xianyang") + Vector2i(5, 5)
	var check: Dictionary = CityManager.can_build("xianyang", "farm", far)
	assert_false(check["allowed"])
	assert_eq(check["reason"], CityManager.REASON_HEX_OUT_OF_JURISDICTION)


func test_cannot_build_on_occupied_hex() -> void:
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	var target: Vector2i = hexes[0]
	assert_true(CityManager.start_build("xianyang", "farm", target))
	# 完成建造
	CityManager._process_build_queue("xianyang", {})
	var placed: Dictionary = CityManager.get_building_at_hex(target)
	assert_false(placed.is_empty(), "完成建造后应有实体建筑")
	assert_eq(str(placed.get("building_id", "")), "farm")
	assert_eq(int(placed.get("level", 0)), 1)
	# 同格不能再建
	var check: Dictionary = CityManager.can_build("xianyang", "market", target)
	assert_false(check["allowed"])
	assert_eq(check["reason"], CityManager.REASON_HEX_OCCUPIED)


func test_wall_is_repeatable_on_different_hexes() -> void:
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	assert_true(CityManager.start_build("xianyang", "wall", hexes[0]))
	assert_true(CityManager.start_build("xianyang", "wall", hexes[1]), "城墙可重复建造")
	var city: Dictionary = CityManager.get_city_state("xianyang")
	# 两个在建队列 + 槽位需足够（都城槽位 5）
	assert_true((city.get("build_queue", []) as Array).size() >= 2)
	for i in range(4):
		CityManager._process_build_queue("xianyang", {})
	var w0: Dictionary = CityManager.get_building_at_hex(hexes[0])
	var w1: Dictionary = CityManager.get_building_at_hex(hexes[1])
	assert_eq(str(w0.get("building_id", "")), "wall")
	assert_eq(str(w1.get("building_id", "")), "wall")
	assert_true(int(w0.get("structure_hp", 0)) > 0, "城墙应有结构 HP")
	assert_true(int(w1.get("structure_hp", 0)) > 0)


func test_non_repeatable_blocks_second_build() -> void:
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	assert_true(CityManager.start_build("xianyang", "farm", hexes[0]))
	CityManager._process_build_queue("xianyang", {})
	assert_false(CityManager.get_building_at_hex(hexes[0]).is_empty(), "首个农田应建成")
	var check: Dictionary = CityManager.can_build("xianyang", "farm", hexes[1])
	assert_false(check["allowed"])
	assert_eq(check["reason"], CityManager.REASON_ALREADY_BUILT)


func test_passable_rules_no_hp_vs_hp() -> void:
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	assert_true(CityManager.is_hex_passable_for_units(hexes[0]), "空地可通行")
	assert_true(CityManager.start_build("xianyang", "farm", hexes[0]))
	CityManager._process_build_queue("xianyang", {})
	assert_true(CityManager.is_hex_passable_for_units(hexes[0]), "无血量建筑可通行")
	assert_true(CityManager.start_build("xianyang", "wall", hexes[1]))
	CityManager._process_build_queue("xianyang", {})
	CityManager._process_build_queue("xianyang", {})
	assert_false(CityManager.is_hex_passable_for_units(hexes[1]), "有血量建筑未破防不可通行")
	# 打空结构 HP 后可通行
	var city: Dictionary = CityManager.get_city_state("xianyang")
	for b: Variant in city.get("buildings", []):
		var e: Dictionary = b as Dictionary
		if str(e.get("building_id", "")) == "wall" and int(e.get("hex_q", -1)) == hexes[1].x:
			e["structure_hp"] = 0
	assert_true(CityManager.is_hex_passable_for_units(hexes[1]), "结构 HP=0 后可通行")


func test_migrate_legacy_building_without_hex() -> void:
	var city: Dictionary = CityManager.get_city_state("xianyang")
	# 模拟旧档：无坐标
	(city["buildings"] as Array).append({"building_id": "market", "level": 2})
	CityManager._migrate_physical_buildings()
	var entry: Dictionary = CityManager._find_building_entry(city, "market")
	assert_true(entry.has("hex_q"), "迁移后应补坐标")
	assert_true(entry.has("hex_r"))
	var axial: Vector2i = Vector2i(int(entry["hex_q"]), int(entry["hex_r"]))
	assert_true(CityManager.is_jurisdiction_hex("xianyang", axial), "迁移坐标应在辖区内")
	var at: Dictionary = CityManager.get_building_at_hex(axial)
	assert_eq(str(at.get("building_id", "")), "market")


func test_demolish_frees_hex() -> void:
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	assert_true(CityManager.start_build("xianyang", "farm", hexes[0]))
	CityManager._process_build_queue("xianyang", {})
	assert_false(CityManager.get_building_at_hex(hexes[0]).is_empty())
	assert_true(CityManager.demolish("xianyang", "farm", hexes[0]))
	assert_true(CityManager.get_building_at_hex(hexes[0]).is_empty(), "拆除后格子应空出")
	assert_true(CityManager.can_build("xianyang", "market", hexes[0])["allowed"])


func test_wall_defense_bonus_scales_with_hp() -> void:
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	assert_true(CityManager.start_build("xianyang", "wall", hexes[0]))
	CityManager._process_build_queue("xianyang", {})
	CityManager._process_build_queue("xianyang", {})
	var full: float = CityManager.get_city_wall_defense_bonus("xianyang")
	assert_almost_eq(full, 0.15, 0.01, "满血 Lv1 墙防御 +15%")
	# 打到 50% HP → bonus 线性减半
	var axial: Vector2i = hexes[0]
	CityManager.damage_building_at_hex(axial, 75)
	var half: float = CityManager.get_city_wall_defense_bonus("xianyang")
	assert_almost_eq(half, 0.075, 0.01, "50% HP 墙防御约 +7.5%")
	# HP=0 仍保留 50% 效果（§7.4）
	CityManager.damage_building_at_hex(axial, 999)
	var broken: float = CityManager.get_city_wall_defense_bonus("xianyang")
	assert_almost_eq(broken, 0.075, 0.01, "墙 HP=0 时 defense_bonus 保留 50%")


func test_occupation_disables_no_hp_building() -> void:
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	assert_true(CityManager.start_build("xianyang", "farm", hexes[0]))
	CityManager._process_build_queue("xianyang", {})
	assert_false(bool(CityManager.get_building_at_hex(hexes[0]).get("disabled", true)))
	assert_true(CityManager.disable_building_at_hex(hexes[0]), "敌占应能失效建筑")
	assert_true(bool(CityManager.get_building_at_hex(hexes[0]).get("disabled", false)))
	# 收复恢复
	CityManager.reenable_city_buildings("xianyang")
	assert_false(bool(CityManager.get_building_at_hex(hexes[0]).get("disabled", true)))


func test_damage_building_marks_destroyed() -> void:
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	assert_true(CityManager.start_build("xianyang", "wall", hexes[0]))
	CityManager._process_build_queue("xianyang", {})
	CityManager._process_build_queue("xianyang", {})
	var res: Dictionary = CityManager.damage_building_at_hex(hexes[0], 9999)
	assert_true(bool(res.get("destroyed", false)))
	assert_eq(int(res.get("remaining_hp", -1)), 0)
	assert_false(CityManager.is_hex_passable_for_units(hexes[0]) == false, "破防后应可通行")
