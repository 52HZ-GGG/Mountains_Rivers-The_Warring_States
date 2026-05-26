extends ConfirmationDialog

## 停战谈判弹窗 — 阶段2最小可用UI
##
## 战胜方开价界面：赔款输入框 + 城市选择列表 + 称臣复选框
## 谈判历史显示（最多3轮）
## 接受/拒绝/还价按钮

signal negotiation_completed(success: bool)

var _proposer: String = ""
var _target: String = ""
var _current_round: int = 0
var _max_rounds: int = 3
var _negotiation_history: Array[Dictionary] = []

# UI 元素
var _gold_input: SpinBox
var _city_option: OptionButton
var _vassal_check: CheckBox
var _history_label: Label


func _ready() -> void:
	title = "停战谈判"
	visible = false
	confirmed.connect(_on_accept_pressed)

	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "NegotiationVBox"
	add_child(vbox)

	# 谈判信息
	var info_label := Label.new()
	info_label.name = "InfoLabel"
	info_label.text = "谈判进行中..."
	vbox.add_child(info_label)

	# 赔款
	var gold_box := HBoxContainer.new()
	vbox.add_child(gold_box)

	var gold_label := Label.new()
	gold_label.text = "赔款金额:"
	gold_box.add_child(gold_label)

	_gold_input = SpinBox.new()
	_gold_input.name = "GoldInput"
	_gold_input.min_value = 0
	_gold_input.max_value = 10000
	_gold_input.step = 50
	_gold_input.value = 100
	gold_box.add_child(_gold_input)

	# 割地
	var city_box := HBoxContainer.new()
	vbox.add_child(city_box)

	var city_label := Label.new()
	city_label.text = "割让城市:"
	city_box.add_child(city_label)

	_city_option = OptionButton.new()
	_city_option.name = "CityOption"
	_city_option.add_item("无", 0)
	city_box.add_child(_city_option)

	# 称臣
	_vassal_check = CheckBox.new()
	_vassal_check.name = "VassalCheck"
	_vassal_check.text = "称臣纳贡"
	vbox.add_child(_vassal_check)

	# 谈判历史
	_history_label = Label.new()
	_history_label.name = "HistoryLabel"
	_history_label.text = "谈判历史:"
	vbox.add_child(_history_label)

	# 按钮区
	var button_box := HBoxContainer.new()
	vbox.add_child(button_box)

	var reject_btn := SkirmishTileTextures.styled_button("拒绝")
	reject_btn.pressed.connect(_on_reject_pressed)
	button_box.add_child(reject_btn)

	var counter_btn := SkirmishTileTextures.styled_button("还价")
	counter_btn.pressed.connect(_on_counter_pressed)
	button_box.add_child(counter_btn)


func open(proposer: String, target: String) -> void:
	_proposer = proposer
	_target = target
	_current_round = 0
	_negotiation_history.clear()
	_max_rounds = DataManager.get_diplomacy_param("negotiation.max_rounds") as int

	# 填充城市选项
	_city_option.clear()
	_city_option.add_item("无", 0)
	var cities: Array = DataManager.get_faction_cities(target)
	for i in range(cities.size()):
		_city_option.add_item(cities[i]["name"], i + 1)

	_update_info()
	_update_history()
	visible = true


func _update_info() -> void:
	var info_label := $NegotiationVBox/InfoLabel
	info_label.text = "第 %d / %d 轮谈判\n%s → %s" % [_current_round + 1, _max_rounds,
		DataManager.get_faction(_proposer).get("name", _proposer),
		DataManager.get_faction(_target).get("name", _target)]


func _update_history() -> void:
	var text := "谈判历史:\n"
	for i in range(_negotiation_history.size()):
		var entry: Dictionary = _negotiation_history[i]
		var round_text: String = "第%d轮: " % (i + 1)
		if entry.has("gold") and entry["gold"] > 0:
			round_text += "赔款%d金 " % entry["gold"]
		if entry.has("city_name") and entry["city_name"] != "":
			round_text += "割让%s " % entry["city_name"]
		if entry.get("vassal", false):
			round_text += "称臣"
		if entry.has("result"):
			round_text += " → %s" % entry["result"]
		text += round_text + "\n"
	_history_label.text = text


func _get_current_terms() -> Dictionary:
	var terms: Dictionary = {
		"gold": int(_gold_input.value),
		"city_id": "",
		"city_name": "",
		"vassal": _vassal_check.button_pressed,
		"payer": _target,
		"receiver": _proposer
	}
	var city_idx: int = _city_option.selected
	if city_idx > 0:
		var cities: Array = DataManager.get_faction_cities(_target)
		if city_idx - 1 < cities.size():
			terms["city_id"] = cities[city_idx - 1]["id"]
			terms["city_name"] = cities[city_idx - 1]["name"]
	return terms


func _on_accept_pressed() -> void:
	var terms := _get_current_terms()
	_negotiation_history.append(terms)
	_negotiation_history[_negotiation_history.size() - 1]["result"] = "接受"

	# 执行停战
	DiplomacySystem.accept_ceasefire(_proposer, _target, terms)
	_update_history()
	negotiation_completed.emit(true)
	visible = false


func _on_reject_pressed() -> void:
	_negotiation_history.append(_get_current_terms())
	_negotiation_history[_negotiation_history.size() - 1]["result"] = "拒绝"
	_update_history()
	negotiation_completed.emit(false)
	visible = false


func _on_counter_pressed() -> void:
	_current_round += 1
	if _current_round >= _max_rounds:
		# 谈判破裂
		_negotiation_history.append(_get_current_terms())
		_negotiation_history[_negotiation_history.size() - 1]["result"] = "谈判破裂"
		_update_history()
		negotiation_completed.emit(false)
		visible = false
		return

	# AI还价
	var current_terms := _get_current_terms()
	_negotiation_history.append(current_terms)

	# AI评估并还价
	var ai_accepts: bool = DiplomacyAI.evaluate_ceasefire_offer(_target, current_terms)
	if ai_accepts:
		_negotiation_history[_negotiation_history.size() - 1]["result"] = "AI接受"
		DiplomacySystem.accept_ceasefire(_proposer, _target, current_terms)
		_update_history()
		negotiation_completed.emit(true)
		visible = false
	else:
		# AI还价
		var counter_terms: Dictionary = DiplomacyAI.generate_counter_offer(_target, current_terms)
		_negotiation_history[_negotiation_history.size() - 1]["result"] = "AI还价"
		# 更新UI为AI的还价
		_gold_input.value = counter_terms.get("gold", 0)
		_vassal_check.button_pressed = counter_terms.get("vassal", false)
		if counter_terms.has("city_id") and counter_terms["city_id"] != "":
			var cities: Array = DataManager.get_faction_cities(_target)
			for i in range(cities.size()):
				if cities[i]["id"] == counter_terms["city_id"]:
					_city_option.selected = i + 1
					break
		_update_info()
		_update_history()
