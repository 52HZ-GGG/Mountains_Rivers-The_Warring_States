extends Node

## 主场景脚本 — 连接UI和游戏系统


func _ready() -> void:
	# 连接外交按钮
	var diplomacy_button := $DiplomacyButton
	diplomacy_button.pressed.connect(_on_diplomacy_button_pressed)

	# 初始化游戏（默认7国，玩家为秦）
	_init_game()


func _init_game() -> void:
	var active_factions: Array[String] = []
	for fid in GameManager.FACTION_IDS:
		active_factions.append(fid)
	GameManager.start_game(active_factions, "qin")
	print("[Main] 游戏初始化完成，玩家: 秦国")


func _on_diplomacy_button_pressed() -> void:
	var panel := $DiplomacyPanel
	panel.open()
