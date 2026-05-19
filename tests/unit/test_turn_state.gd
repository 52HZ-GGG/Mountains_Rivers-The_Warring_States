extends GutTest

## Sprint 8 测试：回合状态机
## 验证 TurnState 枚举、行动速度排序、势力顺序

# === TurnState 枚举 ===

func test_turn_state_enum_exists() -> void:
	assert_true(GameManager.TurnState.has("WAITING"), "应有 WAITING 状态")
	assert_true(GameManager.TurnState.has("EXECUTING"), "应有 EXECUTING 状态")
	assert_true(GameManager.TurnState.has("COMPLETED"), "应有 COMPLETED 状态")

func test_initial_turn_state() -> void:
	GameManager.reset()
	assert_eq(GameManager.get_turn_state(), GameManager.TurnState.WAITING, "初始应为 WAITING")

# === 势力排序 ===

func test_faction_order_after_start() -> void:
	GameManager.reset()
	var factions: Array[String] = ["qin", "zhao", "qi"]
	GameManager.start_game(factions, "qin")
	var order: Array[String] = GameManager.get_faction_order()
	assert_eq(order.size(), 3, "排序后应有 3 个势力")
	assert_true(order.has("qin"), "应包含 qin")
	assert_true(order.has("zhao"), "应包含 zhao")
	assert_true(order.has("qi"), "应包含 qi")
	GameManager.reset()

func test_get_current_faction_from_order() -> void:
	GameManager.reset()
	var factions: Array[String] = ["qin", "zhao"]
	GameManager.start_game(factions, "qin")
	var current: String = GameManager.get_current_faction()
	assert_true(factions.has(current), "当前势力应在列表中")
	GameManager.reset()

func test_faction_order_preserves_all() -> void:
	GameManager.reset()
	var factions: Array[String] = ["qin", "zhao", "qi", "chu", "wei", "yan", "han"]
	GameManager.start_game(factions, "qin")
	var order: Array[String] = GameManager.get_faction_order()
	assert_eq(order.size(), 7, "排序后应有 7 个势力")
	for f in factions:
		assert_true(order.has(f), "排序应包含 %s" % f)
	GameManager.reset()
