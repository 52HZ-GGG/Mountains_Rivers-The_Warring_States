extends GutTest

## GameManager 单元测试 — 回合循环状态机
##
## 注意：GameManager 是 autoload，状态在测试间持续。
## 每个测试通过 before_each 调用 GameManager.reset() 隔离状态。
## 阶段 1 草稿：覆盖状态机 + 信号 + 玩家身份判定，
##              AI 与胜利条件留 TODO 待实现后追加。

const TWO_FACTIONS: Array[String] = ["qin", "zhao"]
const PLAYER: String = "qin"


func before_each() -> void:
	GameManager.reset()
	# 子任务 4 后 check_victory 依赖 CityManager 状态；同步重置防止跨脚本污染。
	CityManager.reset()


# ============= 初始状态 =============

func test_initial_phase_is_game_init() -> void:
	assert_eq(GameManager.get_current_phase(), GameManager.Phase.GAME_INIT,
		"reset 后阶段应为 GAME_INIT")


func test_initial_turn_is_zero() -> void:
	assert_eq(GameManager.get_current_turn(), 0, "未开始游戏前回合数应为 0")


func test_initial_faction_is_empty() -> void:
	assert_eq(GameManager.get_current_faction(), "", "未开始游戏前当前 faction 为空字符串")


# ============= 开局 =============

func test_start_game_transitions_to_action() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	assert_eq(GameManager.get_current_phase(), GameManager.Phase.ACTION,
		"start_game 后应停在 ACTION 阶段")
	assert_eq(GameManager.get_current_turn(), 1, "首回合应为 1")
	assert_eq(GameManager.get_current_faction(), "qin",
		"首先行动应为 active_factions 列表第一个")


func test_start_game_with_empty_factions_stays_in_init() -> void:
	GameManager.start_game([], "qin")
	assert_eq(GameManager.get_current_phase(), GameManager.Phase.GAME_INIT,
		"空列表应被拒绝，保持 GAME_INIT")


func test_start_game_with_player_not_in_active_stays_in_init() -> void:
	GameManager.start_game(TWO_FACTIONS, "yan")
	assert_eq(GameManager.get_current_phase(), GameManager.Phase.GAME_INIT,
		"player_faction 不在 active_factions 时应被拒绝")


# ============= 推进回合 =============

func test_end_turn_advances_to_next_faction() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()
	assert_eq(GameManager.get_current_faction(), "zhao",
		"结束秦国回合后应轮到赵国")
	assert_eq(GameManager.get_current_turn(), 1,
		"同一轮内回合数不变（仍是 turn 1）")
	assert_eq(GameManager.get_current_phase(), GameManager.Phase.ACTION,
		"切换 faction 后停在 ACTION 阶段等待输入")


func test_full_round_increments_turn_number() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()  # qin → zhao
	GameManager.end_current_turn()  # zhao → 新一轮 qin
	assert_eq(GameManager.get_current_faction(), "qin",
		"新一轮应回到列表第一个 faction")
	assert_eq(GameManager.get_current_turn(), 2,
		"全员行动完一轮后回合数应推进至 2")


# ============= 信号 =============

func test_turn_started_signal_emitted_on_start_game() -> void:
	watch_signals(SignalBus)
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	assert_signal_emitted_with_parameters(SignalBus, "turn_started", [1, "qin"])


func test_turn_ended_signal_emitted_on_end_turn() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	watch_signals(SignalBus)
	GameManager.end_current_turn()
	assert_signal_emitted_with_parameters(SignalBus, "turn_ended", [1, "qin"])


# ============= 玩家身份判定 =============

func test_is_player_faction_for_player() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	assert_true(GameManager.is_player_faction("qin"), "玩家 faction 应识别为 player")


func test_is_player_faction_for_ai() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	assert_false(GameManager.is_player_faction("zhao"), "非玩家 faction 应识别为 AI")


# ============= TODO（待 AI / 城市占领系统就位后追加）=============
# - test_ai_turn_completes_via_process_ai_turn
# - test_check_victory_when_player_capital_captured
# - test_game_over_signal_emitted_on_victory
# - test_phase_locked_after_game_over
