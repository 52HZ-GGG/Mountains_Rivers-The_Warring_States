extends GutTest

## 合纵连横战役：主菜单入口整合 + 关卡配置

const CampaignFlowScript := preload("res://scripts/autoload/campaign_flow.gd")
const ModeSelectScript := preload("res://scenes/ui/splash/mode_select.gd")


func test_campaign_levels_json_has_tutorial_as_level1() -> void:
	var levels: Array = CampaignFlow.get_levels()
	assert_false(levels.is_empty(), "campaign_levels.json 应包含关卡")
	var first: Dictionary = levels[0]
	assert_eq(str(first.get("id", "")), "level_01_tutorial", "第一关应为新手教程")
	assert_eq(str(first.get("launch_mode", "")), CampaignFlow.LAUNCH_MODE_TUTORIAL, "第一关应启动 demo 教程流程")
	assert_false(bool(first.get("locked", true)), "第一关应解锁可玩")


func test_resolve_launch_mode_blocks_locked_levels() -> void:
	assert_eq(CampaignFlow.resolve_launch_mode("level_01_tutorial"), "demo", "第一关可启动")
	assert_eq(CampaignFlow.resolve_launch_mode("level_02_placeholder"), "", "锁定关卡不可启动")
	assert_eq(CampaignFlow.resolve_launch_mode("not_exist"), "", "未知关卡不可启动")


func test_mode_select_has_no_standalone_tutorial_entry() -> void:
	var modes: Array = ModeSelectScript.MODES
	var has_tutorial: bool = false
	var story_locked: bool = true
	for m: Variant in modes:
		var d: Dictionary = m as Dictionary
		var mid: String = str(d.get("id", ""))
		if mid == "demo":
			has_tutorial = true
		if mid == "story":
			story_locked = bool(d.get("locked", true))
	assert_false(has_tutorial, "主菜单不应再单独列出新手教程")
	assert_false(story_locked, "合纵连横战役入口应解锁")


func test_startup_flow_has_story_and_campaign_paths() -> void:
	assert_eq(StartupFlow.MODE_STORY, "story", "应存在战役模式常量")
	assert_true(StartupFlow.campaign_level_select_scene.ends_with("campaign_level_select.tscn"), "应配置关卡选择场景")
	assert_true(ResourceLoader.exists(StartupFlow.CAMPAIGN_LEVEL_SELECT_SCENE), "关卡选择场景文件应存在")


func test_campaign_level_select_scene_script_loads() -> void:
	var script: Script = load("res://scenes/ui/splash/campaign_level_select.gd")
	assert_not_null(script, "关卡选择脚本应可加载")
	var packed: PackedScene = load("res://scenes/ui/splash/campaign_level_select.tscn")
	assert_not_null(packed, "关卡选择场景应可加载")
