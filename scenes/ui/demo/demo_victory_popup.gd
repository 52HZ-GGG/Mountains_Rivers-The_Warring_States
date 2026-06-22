extends PanelContainer

## Demo 胜利弹窗。
## 由主场景在洛邑战役胜利后主动调用 show_victory()。

signal popup_closed
signal return_to_hub_requested
signal replay_requested
signal inspect_result_requested

@onready var title_label: Label = $Margin/VBox/Title
@onready var message_label: Label = $Margin/VBox/Message
@onready var close_button: Button = $Margin/VBox/CloseButton
@onready var replay_button: Button = $Margin/VBox/ActionRow/ReplayButton
@onready var inspect_button: Button = $Margin/VBox/ActionRow/InspectButton


func _ready() -> void:
	visible = false
	SkirmishTileTextures.style_scene_button(close_button)
	SkirmishTileTextures.style_scene_button(replay_button)
	SkirmishTileTextures.style_scene_button(inspect_button)
	close_button.pressed.connect(_on_close_button_pressed)
	replay_button.pressed.connect(_on_replay_button_pressed)
	inspect_button.pressed.connect(_on_inspect_button_pressed)
	_update_text()


func show_victory() -> void:
	_update_text()
	visible = true


func close_popup() -> void:
	visible = false
	popup_closed.emit()


func _update_text() -> void:
	var target_city_name: String = DemoFlow.get_target_city_name()
	title_label.text = "洛邑战役胜利"
	if DemoFlow.is_tutorial_enabled():
		message_label.text = "秦国已攻取%s，教学战斗目标达成。\n\n下一步可返回继续查看城市、人口、征兵与经营结果，完成教学闭环。" % [
			target_city_name,
		]
	else:
		message_label.text = "秦国已攻取%s，战斗目标达成。" % [
			target_city_name,
		]


func _on_demo_completed(_target_city_id: String) -> void:
	pass


func _on_close_button_pressed() -> void:
	close_popup()
	return_to_hub_requested.emit()


func _on_replay_button_pressed() -> void:
	close_popup()
	replay_requested.emit()


func _on_inspect_button_pressed() -> void:
	close_popup()
	inspect_result_requested.emit()
