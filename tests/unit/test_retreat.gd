extends GutTest

## 撤退/溃退/追击单元测试
## 验证主动撤退、被动溃退、追击伤害、包围惩罚

func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()


# ============= 主动撤退测试 =============

func test_retreat_moves_away_from_enemy() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	assert_false(p1.is_empty(), "mvp_p1 应存在")
	# 玩家步兵在 (0,3)，敌方步兵放到旁边 (1,3)
	p1["q"] = 0
	p1["r"] = 3
	e1["q"] = 1
	e1["r"] = 3
	# 将其他单位移远
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = -10
	e2["r"] = -10
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	p2["q"] = -10
	p2["r"] = -10
	var result: Dictionary = TacticalSkirmishManager.try_retreat("mvp_p1")
	assert_true(result["ok"], "撤退应成功")
	# 撤退后应远离敌人
	var dist_after: int = HexAxial.hex_distance_hex(
		Vector2i(int(p1["q"]), int(p1["r"])),
		Vector2i(int(e1["q"]), int(e1["r"])),
	)
	assert_true(dist_after > 1, "撤退后应远离敌方步兵，距离 > 1，实际: %d" % dist_after)


func test_retreat_consumes_all_mp() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	p1["q"] = 0
	p1["r"] = 3
	e1["q"] = 1
	e1["r"] = 3
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = -10
	e2["r"] = -10
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	p2["q"] = -10
	p2["r"] = -10
	TacticalSkirmishManager.try_retreat("mvp_p1")
	assert_eq(int(p1["mp_remaining"]), 0, "撤退后移动力应为 0")
	assert_true(bool(p1["acted"]), "撤退后 acted 应为 true")


func test_retreat_no_path_stays_put() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = 0
	p1["r"] = 3
	var orig_q: int = int(p1["q"])
	var orig_r: int = int(p1["r"])
	# 用 6 个敌方单位包围
	var neighbors: Array[Vector2i] = [
		Vector2i(1, 3), Vector2i(0, 4), Vector2i(-1, 4),
		Vector2i(-1, 3), Vector2i(0, 2), Vector2i(1, 2),
	]
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e1["q"] = neighbors[0].x
	e1["r"] = neighbors[0].y
	e2["q"] = neighbors[1].x
	e2["r"] = neighbors[1].y
	for i: int in range(2, 6):
		TacticalSkirmishManager._units.append({
			"id": "enc_ret_%d" % i,
			"faction_id": "zhao",
			"unit_type_id": "infantry",
			"q": neighbors[i].x,
			"r": neighbors[i].y,
			"hp": 100, "max_hp": 100, "morale": 100,
		})
	# 移除弓兵避免干扰
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	p2["q"] = -10
	p2["r"] = -10
	var result: Dictionary = TacticalSkirmishManager.try_retreat("mvp_p1")
	assert_true(result["ok"], "撤退应返回 ok")
	assert_eq(int(p1["q"]), orig_q, "被包围时不应移动（q）")
	assert_eq(int(p1["r"]), orig_r, "被包围时不应移动（r）")


# ============= 被动溃退测试 =============

func test_rout_triggers_at_low_morale() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = 0
	p1["r"] = 3
	p1["morale"] = 10  # 低于崩溃阈值 20
	# 移走所有敌方单位避免追击
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 10
	e1["r"] = 10
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 10
	e2["r"] = 11
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	p2["q"] = -10
	p2["r"] = -10
	# 触发溃退
	TacticalSkirmishManager.process_morale_for_test()
	# 溃退后单位应标记为已行动
	assert_true(bool(p1.get("acted", false)), "溃退后单位应标记为已行动")


func test_rout_moves_toward_friendly_city() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	# 放到远离友方城市的位置（使用简单平原坐标）
	p1["q"] = 2
	p1["r"] = 0
	p1["morale"] = 10
	p1["acted"] = false
	# 移走所有敌方单位避免追击
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 10
	e1["r"] = 10
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 10
	e2["r"] = 11
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	p2["q"] = -10
	p2["r"] = -10
	p2["morale"] = 100  # 确保 p2 不触发溃退
	var city: Vector2i = TacticalSkirmishManager.get_player_city()
	var dist_before: int = HexAxial.hex_distance_hex(Vector2i(2, 0), city)
	TacticalSkirmishManager.process_morale_for_test()
	var dist_after: int = HexAxial.hex_distance_hex(Vector2i(int(p1["q"]), int(p1["r"])), city)
	assert_true(dist_after < dist_before, "溃退应移向友方城市，距离应减小（前=%d，后=%d）" % [dist_before, dist_after])


func test_rout_reaches_city_recovers_morale() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	# 放到友方城市旁边（找可通行且未被占据的邻居）
	var city: Vector2i = TacticalSkirmishManager.get_player_city()
	var neighbors: Array[Vector2i] = HexAxial.neighbors_hex(city)
	var passable: Vector2i = Vector2i.ZERO
	for n: Vector2i in neighbors:
		if not TacticalSkirmishManager._all_cells.has(n):
			continue
		if TacticalSkirmishManager._occupant_id_at(n) != "":
			continue
		var tc: int = TacticalSkirmishManager._tile_move_cost_cell(n, "infantry")
		if tc < 999999:
			passable = n
			break
	assert_ne(passable, Vector2i.ZERO, "应找到可通行的邻居")
	p1["q"] = passable.x
	p1["r"] = passable.y
	p1["morale"] = 10
	# 移走所有敌方单位
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 10
	e1["r"] = 10
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 10
	e2["r"] = 11
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	p2["q"] = -10
	p2["r"] = -10
	TacticalSkirmishManager.process_morale_for_test()
	# 验证单位到达城市坐标
	var final_pos: Vector2i = Vector2i(int(p1["q"]), int(p1["r"]))
	assert_eq(final_pos, city, "溃退后单位应在城市坐标上")
	# 到达城市后士气应恢复
	assert_true(int(p1["morale"]) >= 30, "到达友方城市后士气应恢复到 30+，实际: %d" % int(p1["morale"]))


# ============= 追击测试 =============

func test_pursuit_damage_on_retreat() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	# 敌方步兵在旁边
	p1["q"] = 0
	p1["r"] = 3
	e1["q"] = 1
	e1["r"] = 3
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = -10
	e2["r"] = -10
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	p2["q"] = -10
	p2["r"] = -10
	var hp_before: int = int(p1["hp"])
	TacticalSkirmishManager.try_retreat("mvp_p1")
	# 应该被追击，HP 减少
	assert_true(int(p1["hp"]) < hp_before, "撤退时应被步兵追击受伤（HP %d -> %d）" % [hp_before, int(p1["hp"])])


func test_no_pursuit_from_archer() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	# 将敌方步兵和骑兵移远
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 10
	e1["r"] = 10
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 10
	e2["r"] = 11
	# 添加一个敌方弓兵在旁边
	TacticalSkirmishManager._units.append({
		"id": "archer_pursuit",
		"faction_id": "zhao",
		"unit_type_id": "archer",
		"q": 1, "r": 3,
		"hp": 100, "max_hp": 100, "morale": 100,
	})
	p1["q"] = 0
	p1["r"] = 3
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	p2["q"] = -10
	p2["r"] = -10
	var hp_before: int = int(p1["hp"])
	TacticalSkirmishManager.try_retreat("mvp_p1")
	# 弓兵不应追击
	assert_eq(int(p1["hp"]), hp_before, "弓兵不应触发追击（HP 不变）")


# ============= 包围惩罚测试 =============

func test_encircled_extra_hp_loss() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = 3
	p1["r"] = 3
	p1["morale"] = 10  # 崩溃态
	# 包围：6 个敌方
	var neighbor_offsets: Array[Vector2i] = [
		Vector2i(4, 3), Vector2i(3, 4), Vector2i(2, 4),
		Vector2i(2, 3), Vector2i(3, 2), Vector2i(4, 2),
	]
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e1["q"] = neighbor_offsets[0].x
	e1["r"] = neighbor_offsets[0].y
	e2["q"] = neighbor_offsets[1].x
	e2["r"] = neighbor_offsets[1].y
	for i: int in range(2, 6):
		TacticalSkirmishManager._units.append({
			"id": "enc_hp_%d" % i,
			"faction_id": "zhao",
			"unit_type_id": "infantry",
			"q": neighbor_offsets[i].x,
			"r": neighbor_offsets[i].y,
			"hp": 100, "max_hp": 100, "morale": 100,
		})
	var hp_before: int = int(p1["hp"])
	TacticalSkirmishManager.process_morale_for_test()
	# 被包围 + 崩溃态 HP 损失 + 包围额外损失
	assert_true(int(p1["hp"]) < hp_before, "被包围崩溃态应有额外 HP 损失（%d -> %d）" % [hp_before, int(p1["hp"])])


# ============= ZoC 豁免测试 =============

func test_retreat_ignores_zoc() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	# 敌方步兵在旁边，形成 ZoC
	p1["q"] = 0
	p1["r"] = 3
	e1["q"] = 1
	e1["r"] = 3
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = -10
	e2["r"] = -10
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	p2["q"] = -10
	p2["r"] = -10
	var result: Dictionary = TacticalSkirmishManager.try_retreat("mvp_p1")
	assert_true(result["ok"], "撤退应成功（ZoC 不应阻止撤退）")
	# 确认单位确实移动了
	assert_true(int(p1["q"]) != 0 or int(p1["r"]) != 3, "撤退应成功移动（ZoC 豁免）")
