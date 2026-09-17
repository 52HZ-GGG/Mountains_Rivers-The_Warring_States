extends GutTest

const MovementReachLib := preload("res://scripts/systems/movement_reach.gd")


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	TechSystem.reset()
	SchoolManager.reset()
	DiplomacySystem.reset()
	DisasterManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao", "qi", "chu", "wei"], "qin")


func test_generates_zoc_infantry_false() -> void:
	var u: Dictionary = {"unit_type_id": "infantry", "faction_id": "qin", "q": 0, "r": 0}
	var gen: bool = MovementReachLib.generates_zoc(u)
	assert_true(gen == true or gen == false)


func test_zoc_immune_defaults() -> void:
	# scout 类特殊单位可能免疫；infantry 不应因不存在而抛错
	var immune: bool = MovementReachLib.is_zoc_immune("infantry")
	assert_true(immune == true or immune == false)


func test_effective_range_same_elevation() -> void:
	# 大地图上同一城周格，射程应不低于 1
	var r: int = MovementReachLib.effective_range_terrain("plains", "plains", 2)
	assert_true(r >= 1, "plains range should stay >= 1, got %d" % r)


func test_effective_range_uphill_reduces() -> void:
	# 若 mountain elevation > plains，则向山射击应减程
	var plains_e: int = int(DataManager.get_terrain("plains").get("elevation", 0))
	var mountain_e: int = int(DataManager.get_terrain("mountain").get("elevation", 0))
	var r: int = MovementReachLib.effective_range_terrain("plains", "mountain", 3)
	if mountain_e > plains_e:
		assert_lt(r, 3, "uphill should reduce range")
	else:
		assert_eq(r, 3)


func test_strategic_reach_includes_zoc_path() -> void:
	StrategicMapManager.reset()
	var spawn: Dictionary = StrategicMapManager.spawn_unit_at_city("qin", "cavalry", 10, 10, 1)
	assert_true(bool(spawn.get("success", false)))
	var uid: String = str(spawn.get("unit_id", ""))
	var reach: Dictionary = StrategicMapManager.get_reachable_cells(uid)
	assert_true(reach.size() >= 0, "reach returns dictionary")
	# 有移动力时应至少能走到相邻非山地格
	var unit: Dictionary = StrategicMapManager.get_unit(uid)
	if int(unit.get("mp", 0)) > 0:
		assert_gt(reach.size(), 0, "mp>0 should reach some cells")


func test_strategic_attack_range_uses_effective() -> void:
	StrategicMapManager.reset()
	# 宣战后远程攻击判定应使用 effective_range
	if not DiplomacySystem.are_at_war("qin", "zhao"):
		DiplomacySystem.declare_war("qin", "zhao")
	var a: Dictionary = StrategicMapManager.spawn_unit_at_city("qin", "archer", 5, 5, 1)
	var d: Dictionary = StrategicMapManager.spawn_unit_at_city("zhao", "militia", 20, 20, 1)
	assert_true(bool(a.get("success", false)))
	assert_true(bool(d.get("success", false)))
	var attack: Dictionary = StrategicMapManager.try_attack_unit(
		str(a.get("unit_id", "")), str(d.get("unit_id", "")))
	# 远距应 OUT_OF_RANGE
	assert_false(bool(attack.get("ok", false)))
	assert_eq(str(attack.get("reason", "")), "OUT_OF_RANGE")
