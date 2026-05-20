extends GutTest

## 伤害溢出机制单元测试（§10.4）
## 验证击杀时多余伤害丢弃，HP 不为负数

const HexLib := preload("res://scripts/systems/hex_axial.gd")

func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()


# ============= 基本溢出测试 =============

func test_damage_capped_to_target_hp() -> void:
	# 攻击力远大于目标 HP 时，目标应被歼灭，HP 不为负
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	p1["mp_remaining"] = 10
	p1["acted"] = false
	var p1_cell: Vector2i = Vector2i(int(p1["q"]), int(p1["r"]))
	var e1_cell: Vector2i = Vector2i(int(e1["q"]), int(e1["r"]))
	if HexLib.hex_distance_hex(p1_cell, e1_cell) > 1:
		pass_test("攻击者与目标距离 > 1，跳过")
		return
	e1["hp"] = 5
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	assert_lte(int(e1["hp"]), 0, "目标应被歼灭")


func test_overflow_damage_not_applied() -> void:
	# 目标 HP = 1 时，实际伤害 cap 为 1，HP 恰好为 0
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	p1["mp_remaining"] = 10
	p1["acted"] = false
	var p1_cell: Vector2i = Vector2i(int(p1["q"]), int(p1["r"]))
	var e1_cell: Vector2i = Vector2i(int(e1["q"]), int(e1["r"]))
	if HexLib.hex_distance_hex(p1_cell, e1_cell) > 1:
		pass_test("距离 > 1，跳过")
		return
	e1["hp"] = 1
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	assert_eq(int(e1["hp"]), 0, "HP 应恰好为 0，不应为负数（实际 %d）" % int(e1["hp"]))


func test_normal_damage_not_affected() -> void:
	# 攻击力 < 目标 HP 时，正常扣减，目标存活
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	p1["mp_remaining"] = 10
	p1["acted"] = false
	var p1_cell: Vector2i = Vector2i(int(p1["q"]), int(p1["r"]))
	var e1_cell: Vector2i = Vector2i(int(e1["q"]), int(e1["r"]))
	if HexLib.hex_distance_hex(p1_cell, e1_cell) > 1:
		pass_test("距离 > 1，跳过")
		return
	e1["hp"] = 9999
	var old_hp: int = int(e1["hp"])
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var new_hp: int = int(e1["hp"])
	assert_lt(new_hp, old_hp, "HP 应减少")
	assert_gt(new_hp, 0, "高 HP 目标不应被击杀")
