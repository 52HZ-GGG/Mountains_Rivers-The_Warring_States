@tool
extends EditorPlugin

var _panel: Control = null
var _panel_button: Button = null


func _enter_tree() -> void:
	_panel = preload("res://addons/skirmish_scenario_editor/scenario_editor_panel.tscn").instantiate() as Control
	if _panel != null and _panel.has_method("set_editor_interface"):
		_panel.call("set_editor_interface", get_editor_interface())
	_panel_button = add_control_to_bottom_panel(_panel, "演武场景编辑器")
	if _panel_button != null:
		_panel_button.shortcut_in_tooltip = true


func _exit_tree() -> void:
	if _panel != null:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
	_panel = null
	_panel_button = null
