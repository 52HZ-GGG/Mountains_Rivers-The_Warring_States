extends GutTest

## 大地图战略单位：生产 / 移动 / 战斗 / 攻城


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	SchoolManager.reset()
	TechSystem.reset()
	StrategicMapManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func _fund_player() -> void:
	CityManager.get_city_state("xianyang")["conscription_pool"] = 10
	GameManager.apply_faction_resource_delta("qin", "gold", 5000)
	GameManager.apply_faction_resource_delta("qin", "food", 5000)
	GameManager.apply_faction_resource_delta("qin", "wood", 1000)


func test_recruit_spawns_strategic_unit_on_city() -> void:
	_fund_player()
	var result: Dictionary = GameManager.recruit_unit_from_city("xianyang", "militia", 1)
	assert_true(bool(result.get("success", false)), "征兵应成功，reason=%s" % str(result.get("reason", "")))
	var unit_id: String = str(result.get("strategic_unit_id", ""))
	assert_ne(unit_id, "", "应返回大地图单位 id")
	var unit: Dictionary = StrategicMapManager.get_unit(unit_id)
	assert_false(unit.is_empty(), "大地图应存在该单位")
	var capital: Dictionary = CityManager.get_city_state("xianyang")
	assert_eq(int(unit.get("col", -1)), int(capital.get("hex_q", 0)), "单位应出生在城市列")
	assert_eq(int(unit.get("row", -1)), int(capital.get("hex_r", 0)), "单位应出生在城市行")


func test_strategic_unit_can_move_within_mp() -> void:
	_fund_player()
	var result: Dictionary = GameManager.recruit_unit_from_city("xianyang", "militia", 1)
	var unit_id: String = str(result.get("strategic_unit_id", ""))
	var reach: Dictionary = StrategicMapManager.get_reachable_cells(unit_id)
	assert_true(reach.size() > 0, "应有可达格")
	# 选第一个可达格移动
	var dest: Vector2i = Vector2i.ZERO
	for cell: Vector2i in reach:
		dest = cell
		break
	var moved: Dictionary = StrategicMapManager.try_move_unit(unit_id, dest)
	assert_true(bool(moved.get("ok", false)), "移动应成功，reason=%s" % str(moved.get("reason", "")))
	var unit: Dictionary = StrategicMapManager.get_unit(unit_id)
	assert_eq(int(unit["q"]), dest.x, "轴向 q 应更新")
	assert_eq(int(unit["r"]), dest.y, "轴向 r 应更新")


func test_strategic_combat_damages_enemy() -> void:
	_fund_player()
	var mine: Dictionary = GameManager.recruit_unit_from_city("xianyang", "militia", 1)
	var my_id: String = str(mine.get("strategic_unit_id", ""))
	var spawn_enemy: Dictionary = StrategicMapManager.spawn_unit_at_city("zhao", "militia", 0, 0, 1)
	assert_true(bool(spawn_enemy.get("success", false)))
	var enemy_id: String = str(spawn_enemy.get("unit_id", ""))
	# 决策 #89：未宣战禁止战略攻击
	DiplomacySystem.declare_war("qin", "zhao")
	# 把我方单位挪到敌方旁
	var enemy: Dictionary = StrategicMapManager.get_unit(enemy_id)
	var enemy_axial: Vector2i = Vector2i(int(enemy["q"]), int(enemy["r"]))
	for neighbor: Vector2i in HexAxial.neighbors_hex(enemy_axial):
		var off: Vector2i = HexAxial.axial_to_offset_odd_r(neighbor.x, neighbor.y)
		if CityManager.get_big_map_terrain_id(off.x, off.y) == "mountain":
			continue
		# 直接改坐标模拟到位（绕过寻路障碍）
		var my_ref: Dictionary = StrategicMapManager._get_unit_ref(my_id)
		my_ref["q"] = neighbor.x
		my_ref["r"] = neighbor.y
		my_ref["acted"] = false
		my_ref["mp"] = 3
		break
	var attack: Dictionary = StrategicMapManager.try_attack_unit(my_id, enemy_id)
	assert_true(bool(attack.get("ok", false)), "攻击应成功，reason=%s" % str(attack.get("reason", "")))
	assert_gt(int(attack.get("damage", 0)), 0, "应造成伤害")
