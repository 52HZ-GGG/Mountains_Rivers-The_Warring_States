extends GutTest

## 统一实现补齐：演武 CtxBuilder / UnitState mp / ai_mode


func test_pipeline_uses_ctx_builder() -> void:
	var pipe: String = FileAccess.get_file_as_string("res://scripts/systems/skirmish_attack_pipeline.gd")
	assert_true(pipe.contains("CtxLib.build_attack_ctx"), "演武攻击必须 CtxLib.build_attack_ctx")
	assert_true(pipe.contains("CtxLib.build_defense_ctx"), "演武防御必须 CtxLib.build_defense_ctx")


func test_skirmish_units_use_unitstate_mp() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	var factions: Array[String] = ["qin", "zhao"]
	GameManager.start_game(factions, "qin")
	TacticalSkirmishManager.reset_skirmish()
	TacticalSkirmishManager.start_skirmish()
	var units: Array = TacticalSkirmishManager.get("_units") as Array
	assert_false(units.is_empty())
	var u: Dictionary = units[0] as Dictionary
	assert_true(u.has("mp"), "UnitState 权威字段 mp")
	assert_true(u.has("max_mp"))
	assert_true(u.has("mp_remaining"), "兼容别名 mp_remaining")
	assert_eq(int(u.get("mp", -1)), int(u.get("mp_remaining", -2)), "mp 与别名应一致")
	assert_true(u.has("skills"))
	assert_true(u.has("is_supplied"))


func test_ai_mode_defaults() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	var factions: Array[String] = ["qin", "zhao"]
	GameManager.start_game(factions, "qin")
	TacticalSkirmishManager.reset_skirmish()
	var tut: Dictionary = DataManager.get_skirmish_scenario("basic_plains")
	assert_false(tut.is_empty())
	TacticalSkirmishManager.start_skirmish_with_config(tut, "summer")
	assert_eq(str(TacticalSkirmishManager.ai_mode), "tutorial")
	TacticalSkirmishManager.reset_skirmish()
	# 无 ai_mode 的场景默认 scored
	var scored_cfg: Dictionary = tut.duplicate(true)
	scored_cfg.erase("ai_mode")
	scored_cfg["id"] = "custom_no_mode"
	TacticalSkirmishManager.start_skirmish_with_config(scored_cfg, "summer")
	assert_eq(str(TacticalSkirmishManager.ai_mode), "scored")


func test_campaign_writeback_still_on() -> void:
	assert_true(TacticalSkirmishManager.is_campaign_writeback_enabled())
	var sm: String = FileAccess.get_file_as_string("res://scripts/autoload/tactical_skirmish_manager.gd")
	assert_true(sm.contains("apply_result_to_campaign"))
	assert_true(sm.contains("UnitStateLib"), "演武单位应经 UnitState")
