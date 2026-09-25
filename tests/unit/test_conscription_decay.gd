extends GutTest

## 决策 #95：阵亡 → 最大征召 −1；每 death_recovery_period 回合恢复 +1


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_casualty_reduces_max_conscription() -> void:
	var fid: String = "qin"
	var pop: int = GameManager.get_player_population()
	var rate: float = float(DataManager.get_balance_param("population.conscription_rate"))
	var base_max: int = int(pop * rate)
	assert_eq(GameManager.get_max_conscription(fid), base_max)
	GameManager.apply_conscription_casualty(fid, 7)
	assert_eq(GameManager.get_conscription_death_penalty(fid), 7)
	assert_eq(GameManager.get_max_conscription(fid), maxi(0, base_max - 7), "阵亡 7 人 → 最大征召 −7")


func test_casualty_recovery_every_period_turns() -> void:
	var fid: String = "qin"
	GameManager.apply_conscription_casualty(fid, 2)
	var period: int = int(DataManager.get_balance_param("population.death_recovery_period"))
	if period <= 0:
		period = 4
	# 前 period-1 回合不恢复
	for i: int in range(period - 1):
		GameManager.process_national_conscription(fid)
		assert_eq(GameManager.get_conscription_death_penalty(fid), 2, "第 %d 回合不应恢复" % (i + 1))
	# 第 period 回合恢复 1
	GameManager.process_national_conscription(fid)
	assert_eq(GameManager.get_conscription_death_penalty(fid), 1, "满 %d 回合应恢复 1 点" % period)
	for i: int in range(period):
		GameManager.process_national_conscription(fid)
	assert_eq(GameManager.get_conscription_death_penalty(fid), 0, "再满一轮应恢复完毕")


func test_remove_units_with_casualty_flag() -> void:
	var fid: String = "qin"
	var before_pen: int = GameManager.get_conscription_death_penalty(fid)
	GameManager.add_units(fid, "infantry", 3)
	GameManager.remove_units(fid, "infantry", 2, true)
	assert_eq(GameManager.get_conscription_death_penalty(fid), before_pen + 2, "战损 remove_units 应计衰减")
	var before2: int = GameManager.get_conscription_death_penalty(fid)
	GameManager.add_units(fid, "infantry", 2)
	GameManager.remove_units(fid, "infantry", 2, false)
	assert_eq(GameManager.get_conscription_death_penalty(fid), before2, "非战损（调配/撤军）不计衰减")


func test_max_cons_never_negative_and_clamps_pool() -> void:
	var fid: String = "qin"
	GameManager.apply_conscription_casualty(fid, 999999)
	assert_eq(GameManager.get_max_conscription(fid), 0, "最大征召不得为负")
	GameManager.process_national_conscription(fid)
	assert_eq(GameManager.get_available_conscription(fid), 0)


func test_save_load_restores_death_penalty() -> void:
	var fid: String = "qin"
	GameManager.apply_conscription_casualty(fid, 5)
	var save: Dictionary = GameManager.get_save_data()
	GameManager.reset()
	assert_eq(GameManager.get_conscription_death_penalty(fid), 0)
	GameManager.load_save_data(save)
	assert_eq(GameManager.get_conscription_death_penalty(fid), 5, "读档应恢复阵亡衰减")
