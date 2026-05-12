extends Control
## 点击加载动画（六角格旋转 + 武器图标切换 + 打字机文字）
##
## 使用方式：
##   var loading = preload("res://scenes/ui/splash/loading_screen.tscn").instantiate()
##   loading.start_loading("res://scenes/main/main.tscn")

signal loading_finished

@onready var hex_frame: TextureRect = $HexFrame
@onready var weapon_icon: TextureRect = $HexFrame/WeaponIcon
@onready var hint_label: Label = $HintLabel
@onready var overlay: ColorRect = $Overlay

@export var next_scene: String = ""

# 武器图标
var _weapon_textures: Array[Texture2D] = []
var _current_weapon := 0

# 加载提示语
const HINTS := [
	"厉兵秣马...",
	"调兵遣将...",
	"运筹帷幄...",
	"蓄势待发...",
	"粮草先行...",
]
var _current_hint := 0

# 动画参数
const HEX_ROTATION_SPEED := TAU / 2.0  # 2 秒一圈
const WEAPON_SWITCH_INTERVAL := 0.8
const TYPEWRITER_SPEED := 0.1  # 每字间隔

func _ready() -> void:
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.visible = false
	hex_frame.visible = false
	_load_textures()

func _load_textures() -> void:
	var paths := [
		"res://assets/ui/icons/ui_loading_sword.png",
		"res://assets/ui/icons/ui_loading_bow.png",
		"res://assets/ui/icons/ui_loading_shield.png",
		"res://assets/ui/icons/ui_loading_horse.png",
	]
	for p in paths:
		if ResourceLoader.exists(p):
			_weapon_textures.append(load(p))

func start_loading(target_scene: String) -> void:
	next_scene = target_scene
	overlay.visible = true
	hex_frame.visible = true
	hex_frame.rotation = 0.0
	_current_weapon = 0
	_current_hint = randi() % HINTS.size()

	if _weapon_textures.size() > 0:
		weapon_icon.texture = _weapon_textures[0]

	_start_hint_typewriter()
	_start_weapon_cycle()

func _process(delta: float) -> void:
	if not hex_frame.visible:
		return
	# 六角形旋转
	hex_frame.rotation += HEX_ROTATION_SPEED * delta

func _start_weapon_cycle() -> void:
	if _weapon_textures.size() <= 1:
		return
	var timer := get_tree().create_timer(WEAPON_SWITCH_INTERVAL)
	timer.timeout.connect(_switch_weapon)

func _switch_weapon() -> void:
	if not hex_frame.visible:
		return
	_current_weapon = (_current_weapon + 1) % _weapon_textures.size()

	# 淡入淡出切换
	var tw := create_tween()
	tw.tween_property(weapon_icon, "modulate:a", 0.0, 0.1)
	tw.tween_callback(func(): weapon_icon.texture = _weapon_textures[_current_weapon])
	tw.tween_property(weapon_icon, "modulate:a", 1.0, 0.1)
	tw.tween_callback(func(): _start_weapon_cycle())

func _start_hint_typewriter() -> void:
	hint_label.text = ""
	hint_label.visible = true
	var hint := HINTS[_current_hint]
	_typewriter_step(hint, 0)

func _typewriter_step(text: String, index: int) -> void:
	if not hex_frame.visible:
		return
	if index > text.length():
		# 打完一轮，等待后换下一句
		await get_tree().create_timer(1.0).timeout
		_current_hint = (_current_hint + 1) % HINTS.size()
		_start_hint_typewriter()
		return
	hint_label.text = text.substr(0, index)
	await get_tree().create_timer(TYPEWRITER_SPEED).timeout
	_typewriter_step(text, index + 1)

func finish_loading() -> void:
	# 淡出
	var tw := create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.3)
	tw.tween_property(hex_frame, "modulate:a", 0.0, 0.3)
	tw.tween_property(hint_label, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func():
		overlay.visible = false
		hex_frame.visible = false
		if next_scene != "":
			get_tree().change_scene_to_file(next_scene)
		else:
			StartupFlow.on_loading_finished()
		loading_finished.emit()
	)
