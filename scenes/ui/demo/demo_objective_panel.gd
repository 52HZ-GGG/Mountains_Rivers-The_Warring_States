extends PanelContainer

## Demo 任务面板。
## 负责显示当前目标、步骤状态，并监听 DemoFlow 更新。

signal sortie_requested
signal cheat_attack_requested
signal panel_collapsed

@onready var title_label: Label = $Margin/VBox/Header/Title
@onready var collapse_button: Button = $Margin/VBox/Header/CollapseButton
@onready var collapsed_hint_label: Label = $Margin/VBox/CollapsedHint
@onready var objective_label: Label = $Margin/VBox/Objective
@onready var guidance_label: Label = $Margin/VBox/Guidance
@onready var current_step_label: Label = $Margin/VBox/CurrentStep
@onready var prepare_qin_label: Label = $Margin/VBox/Steps/PrepareQin
@onready var win_skirmish_label: Label = $Margin/VBox/Steps/WinSkirmish
@onready var capture_luoyi_label: Label = $Margin/VBox/Steps/CaptureLuoyi
@onready var completion_label: Label = $Margin/VBox/Completion
@onready var sortie_button: Button = $Margin/VBox/SortieButton
@onready var cheat_attack_button: Button = $Margin/VBox/CheatAttackButton

const STEP_TEXTS: Dictionary = {
	DemoFlow.STEP_OPEN_BIG_MAP: "打开大地图，确认七国与中立城市同场",
	DemoFlow.STEP_INSPECT_LUOYI: "查看洛邑",
	DemoFlow.STEP_MANAGE_CAPITAL: "打开咸阳，确认经营产出、人口与征兵",
	DemoFlow.STEP_PREPARE_QIN: "完成秦国经营准备",
	DemoFlow.STEP_START_CAMPAIGN: "从军事 / 战役出征洛邑",
	DemoFlow.STEP_WIN_SKIRMISH: "摧毁敌城城墙并占领敌方城格",
	DemoFlow.STEP_CAPTURE_LUOYI: "洛邑归秦",
	DemoFlow.STEP_REVIEW_RESULT: "查看洛邑经营结果",
	DemoFlow.STEP_DEMO_COMPLETE: "Demo 完成",
}

const EXPANDED_SIZE: Vector2 = Vector2(400.0, 352.0)


func _ready() -> void:
	visible = false
	custom_minimum_size = EXPANDED_SIZE
	SkirmishTileTextures.style_scene_button(collapse_button)
	SkirmishTileTextures.style_scene_button(sortie_button)
	SkirmishTileTextures.style_scene_button(cheat_attack_button)
	collapse_button.pressed.connect(_on_collapse_pressed)
	sortie_button.pressed.connect(_on_sortie_pressed)
	cheat_attack_button.pressed.connect(_on_cheat_attack_pressed)
	_connect_demo_flow_signals()
	_connect_skirmish_signals()
	update_panel()


func open() -> void:
	visible = true
	update_panel()


func close_panel() -> void:
	visible = false


func update_panel() -> void:
	var target_city_name: String = DemoFlow.get_target_city_name()
	var current_step: String = DemoFlow.get_current_step()
	var completed_steps: Dictionary = DemoFlow.get_completed_steps()

	title_label.text = _get_panel_title()
	collapsed_hint_label.text = _get_collapsed_hint(target_city_name)
	objective_label.text = _get_objective_text(target_city_name)
	guidance_label.text = _get_guidance_text(target_city_name)
	current_step_label.text = "当前步骤：%s" % _get_current_step_text(current_step, target_city_name)

	_apply_step_label(prepare_qin_label, DemoFlow.STEP_PREPARE_QIN, completed_steps, "1", _get_strategy_step_text())
	_apply_step_label(win_skirmish_label, DemoFlow.STEP_WIN_SKIRMISH, completed_steps, "2", _get_skirmish_step_text(target_city_name))
	_apply_step_label(capture_luoyi_label, DemoFlow.STEP_REVIEW_RESULT, completed_steps, "3", _get_result_step_text(target_city_name))

	if DemoFlow.is_demo_complete():
		completion_label.text = "状态：已完成"
		completion_label.modulate = Color(0.85, 0.95, 0.72, 1.0)
		sortie_button.disabled = true
		cheat_attack_button.disabled = true
	else:
		completion_label.text = "状态：进行中"
		completion_label.modulate = Color(0.95, 0.87, 0.66, 1.0)
		sortie_button.disabled = not DemoFlow.is_strategy_prepared()
		cheat_attack_button.disabled = false
	if DemoFlow.is_tutorial_enabled():
		sortie_button.visible = false
	else:
		sortie_button.visible = true
	sortie_button.text = "出征%s" % target_city_name if DemoFlow.is_strategy_prepared() else "先完成经营准备"
	cheat_attack_button.visible = true
	if TacticalSkirmishManager.get_demo_attack_multiplier() > 1.0:
		cheat_attack_button.text = "测试作弊已开启：伤害 ×%d" % int(TacticalSkirmishManager.get_demo_attack_multiplier())
	else:
		cheat_attack_button.text = "测试作弊：我方伤害 ×20"
	SkirmishTileTextures.update_button_disabled(sortie_button)
	SkirmishTileTextures.update_button_disabled(cheat_attack_button)


func _connect_demo_flow_signals() -> void:
	if not DemoFlow.step_completed.is_connected(_on_step_completed):
		DemoFlow.step_completed.connect(_on_step_completed)
	if not DemoFlow.demo_completed.is_connected(_on_demo_completed):
		DemoFlow.demo_completed.connect(_on_demo_completed)


func _connect_skirmish_signals() -> void:
	if not TacticalSkirmishManager.state_changed.is_connected(_on_skirmish_state_changed):
		TacticalSkirmishManager.state_changed.connect(_on_skirmish_state_changed)


func _apply_step_label(label: Label, step_id: String, completed_steps: Dictionary, order_text: String, override_text: String = "") -> void:
	var is_completed: bool = completed_steps.has(step_id)
	var prefix: String = "[完成]" if is_completed else "[未完成]"
	var step_text: String = override_text if override_text != "" else _get_step_text(step_id)
	label.text = "%s %s. %s" % [prefix, order_text, step_text]
	label.modulate = Color(0.78, 0.9, 0.72, 1.0) if is_completed else Color(0.88, 0.84, 0.78, 1.0)


func _get_step_text(step_id: String) -> String:
	return str(STEP_TEXTS.get(step_id, "等待推进"))


func _get_guidance_text(target_city_name: String) -> String:
	if not TacticalSkirmishManager.is_active():
		if DemoFlow.is_tutorial_enabled():
			return "教程会直接进入演武；在战场中打开城市/征兵学习经营，并用结束回合同步推进季节和资源。"
		if not DemoFlow.requires_strategy_preparation():
			return "点击“出征%s”直接进入演武；进入后先打城墙，再进城格。" % target_city_name
		if DemoFlow.is_step_completed(DemoFlow.STEP_CAPTURE_LUOYI):
			return "战斗已胜利，打开%s城池面板查看归属与经营结果。" % target_city_name
		if not DemoFlow.is_step_completed(DemoFlow.STEP_OPEN_BIG_MAP):
			return "先打开大地图，确认七国与中立城市都在战略层。"
		if not DemoFlow.is_step_completed(DemoFlow.STEP_MANAGE_CAPITAL):
			return "再打开咸阳，查看经营、人口、征兵与资源产出。"
		return "经营准备已完成，可以点击“出征%s”进入战斗；进入后先打城墙，再进城格。" % target_city_name
	var wall_text: String = _get_wall_status_text(target_city_name)
	if wall_text != "":
		return wall_text
	return "战术目标：攻破%s城墙，并让秦军进入%s城格。" % [target_city_name, target_city_name]


func _get_current_step_text(step_id: String, target_city_name: String) -> String:
	if step_id == DemoFlow.STEP_WIN_SKIRMISH:
		return _get_skirmish_step_text(target_city_name)
	if step_id == DemoFlow.STEP_REVIEW_RESULT:
		return _get_result_step_text(target_city_name)
	return _get_step_text(step_id)


func _get_strategy_step_text() -> String:
	if DemoFlow.is_tutorial_enabled():
		return "战场内打开城市/征兵"
	if not DemoFlow.requires_strategy_preparation():
		return "直接出征%s" % DemoFlow.get_target_city_name()
	var parts: Array[String] = []
	parts.append("版图" if DemoFlow.is_step_completed(DemoFlow.STEP_OPEN_BIG_MAP) else "打开大地图")
	parts.append("首都经营" if DemoFlow.is_step_completed(DemoFlow.STEP_MANAGE_CAPITAL) else "打开咸阳")
	var joined: String = " / ".join(parts)
	return "经营准备：%s" % joined


func _get_panel_title() -> String:
	if DemoFlow.is_full_demo_enabled():
		return "完整 Demo 目标"
	if DemoFlow.is_tutorial_enabled():
		return "新手教程"
	return "战斗演武目标"


func _get_collapsed_hint(target_city_name: String) -> String:
	if DemoFlow.is_full_demo_enabled():
		return "目标：经营秦国，攻取%s并查看战果。" % target_city_name
	if DemoFlow.is_tutorial_enabled():
		return "教程：学习经营、征兵与洛邑攻城。"
	return "目标：攻取%s。" % target_city_name


func _get_objective_text(target_city_name: String) -> String:
	if DemoFlow.is_full_demo_enabled():
		return "目标：经营秦国 → 出征%s → 胜利后回到战略层查看%s" % [target_city_name, target_city_name]
	if DemoFlow.is_tutorial_enabled():
		return "教学：经营概念 → 征兵准备 → 攻城器械 → 洛邑攻城"
	return "目标：直接进入洛邑攻城，完成战术演武"


func _get_result_step_text(target_city_name: String) -> String:
	if DemoFlow.is_step_completed(DemoFlow.STEP_REVIEW_RESULT):
		return "%s战果已回到经营层查看" % target_city_name
	if DemoFlow.is_step_completed(DemoFlow.STEP_CAPTURE_LUOYI):
		return "%s已归秦，点击胜利弹窗“查看战果”" % target_city_name
	return "胜利后%s归秦，并回到城市面板查看经营结果" % target_city_name


func _get_skirmish_step_text(target_city_name: String) -> String:
	if not TacticalSkirmishManager.is_active():
		return "摧毁%s城墙并占领城格" % target_city_name
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var wall_hp: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	var wall_max: int = TacticalSkirmishManager.get_city_wall_max_hp(enemy_city)
	if wall_hp > 0:
		return "继续攻击%s城墙（剩余 %d/%d）" % [target_city_name, wall_hp, wall_max]
	return "城墙已破，移动秦军进入%s城格" % target_city_name


func _get_wall_status_text(target_city_name: String) -> String:
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var wall_hp: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	var wall_max: int = TacticalSkirmishManager.get_city_wall_max_hp(enemy_city)
	if wall_hp > 0:
		return "%s城墙：%d/%d。城墙未破时不算占领，请继续攻击城墙。" % [target_city_name, wall_hp, wall_max]
	if wall_max > 0:
		return "%s城墙已破。下一步：选择秦军，移动进%s城格完成演武。" % [target_city_name, target_city_name]
	return ""


func _on_step_completed(_step_id: String) -> void:
	update_panel()


func _on_demo_completed(_target_city_id: String) -> void:
	update_panel()


func _on_skirmish_state_changed() -> void:
	update_panel()


func _on_sortie_pressed() -> void:
	sortie_requested.emit()


func _on_cheat_attack_pressed() -> void:
	cheat_attack_requested.emit()


func _on_collapse_pressed() -> void:
	panel_collapsed.emit()
