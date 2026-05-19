extends GutTest

## 夹击/包围单元测试
## 验证夹击（相对方向两敌）和包围（六格全敌）士气惩罚

func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()


# ============= 夹击测试 =============

func test_flanking_from_opposite_directions() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	assert_false(p1.is_empty(), "mvp_p1 应存在")
	# 将玩家步兵放在中心
	p1["q"] = 3
	p1["r"] = 3
	# 两个敌方从相对方向（东+西）包围
	e1["q"] = 4
	e1["r"] = 3
	e2["q"] = 2
	e2["r"] = 3
	var delta: int = TacticalSkirmishManager._check_flanking(p1)
	assert_eq(delta, -20, "相对方向两敌应触发夹击，士气 -20")


func test_flanking_from_nw_se_opposite() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	p1["q"] = 3
	p1["r"] = 3
	# NW (direction 4: 0,-1) 和 SE (direction 1: 0,1)
	e1["q"] = 3
	e1["r"] = 2
	e2["q"] = 3
	e2["r"] = 4
	var delta: int = TacticalSkirmishManager._check_flanking(p1)
	assert_eq(delta, -20, "NW/SE 相对方向应触发夹击")


func test_no_flanking_non_opposite_directions() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	p1["q"] = 3
	p1["r"] = 3
	# 东 (direction 0) 和 SE (direction 1) — 非相对方向
	e1["q"] = 4
	e1["r"] = 3
	e2["q"] = 3
	e2["r"] = 4
	var delta: int = TacticalSkirmishManager._check_flanking(p1)
	assert_eq(delta, 0, "非相对方向两敌不应触发夹击")


func test_no_flanking_single_enemy() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	p1["q"] = 3
	p1["r"] = 3
	e1["q"] = 4
	e1["r"] = 3
	# 将第二个敌方移远
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 0
	e2["r"] = 0
	var delta: int = TacticalSkirmishManager._check_flanking(p1)
	assert_eq(delta, 0, "仅一个相邻敌人不应触发夹击")


# ============= 包围测试 =============

func test_encirclement_all_six_neighbors() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = 3
	p1["r"] = 3
	# 六个邻居方向：(1,0), (0,1), (-1,1), (-1,0), (0,-1), (1,-1)
	var neighbor_offsets: Array[Vector2i] = [
		Vector2i(4, 3), Vector2i(3, 4), Vector2i(2, 4),
		Vector2i(2, 3), Vector2i(3, 2), Vector2i(4, 2),
	]
	# 用已有的两个敌方单位
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e1["q"] = neighbor_offsets[0].x
	e1["r"] = neighbor_offsets[0].y
	e2["q"] = neighbor_offsets[1].x
	e2["r"] = neighbor_offsets[1].y
	# 额外添加 4 个临时敌方单位
	for i: int in range(2, 6):
		TacticalSkirmishManager._units.append({
			"id": "enc_%d" % i,
			"faction_id": "zhao",
			"unit_type_id": "infantry",
			"q": neighbor_offsets[i].x,
			"r": neighbor_offsets[i].y,
			"hp": 100,
			"max_hp": 100,
			"morale": 100,
		})
	var delta: int = TacticalSkirmishManager._check_flanking(p1)
	assert_eq(delta, -50, "六格全敌应触发包围，士气 -50")


func test_encirclement_supersedes_flanking() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = 3
	p1["r"] = 3
	# 六格全敌
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
			"id": "enc2_%d" % i,
			"faction_id": "zhao",
			"unit_type_id": "infantry",
			"q": neighbor_offsets[i].x,
			"r": neighbor_offsets[i].y,
			"hp": 100,
			"max_hp": 100,
			"morale": 100,
		})
	var delta: int = TacticalSkirmishManager._check_flanking(p1)
	# 包围返回 -50，不应叠加为 -70
	assert_eq(delta, -50, "包围应优先于夹击，不叠加")


func test_no_encirclement_five_neighbors() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = 3
	p1["r"] = 3
	# 只放 5 个敌方（缺 direction 5: (1,-1)）
	var neighbor_offsets: Array[Vector2i] = [
		Vector2i(4, 3), Vector2i(3, 4), Vector2i(2, 4),
		Vector2i(2, 3), Vector2i(3, 2),
	]
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e1["q"] = neighbor_offsets[0].x
	e1["r"] = neighbor_offsets[0].y
	e2["q"] = neighbor_offsets[1].x
	e2["r"] = neighbor_offsets[1].y
	for i: int in range(2, 5):
		TacticalSkirmishManager._units.append({
			"id": "five_%d" % i,
			"faction_id": "zhao",
			"unit_type_id": "infantry",
			"q": neighbor_offsets[i].x,
			"r": neighbor_offsets[i].y,
			"hp": 100,
			"max_hp": 100,
			"morale": 100,
		})
	var delta: int = TacticalSkirmishManager._check_flanking(p1)
	# 5 个邻居中 direction 0 和 3 是相对的 → 夹击 -20，不是包围
	assert_eq(delta, -20, "5 个邻居（含相对方向）应触发夹击而非包围")


# ============= 友军不触发夹击 =============

func test_ally_adjacent_no_flanking() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	p1["q"] = 3
	p1["r"] = 3
	# 友军在两侧
	p2["q"] = 4
	p2["r"] = 3
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 2
	e1["r"] = 3
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 0
	e2["r"] = 0
	var delta: int = TacticalSkirmishManager._check_flanking(p1)
	assert_eq(delta, 0, "友军不应触发夹击")
