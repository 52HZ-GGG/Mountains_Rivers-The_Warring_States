extends Control
## 场景切换进度条过渡界面
##
## 由 StartupFlow 实例化并挂到场景树顶层（root 直接子节点）：
## 以线程方式后台加载目标场景（ResourceLoader.load_threaded_request），
## 每帧轮询真实进度（load_threaded_get_status）并更新进度条与百分比文本，
## 加载完成后发出 loaded 信号，由 StartupFlow 执行 change_scene_to_packed 切换。
##
## 使用方式：
##   var transition = preload("res://scenes/ui/loading/scene_transition.tscn").instantiate()
##   get_tree().root.add_child(transition)
##   transition.loaded.connect(_on_loaded)
##   transition.load_failed.connect(_on_failed)
##   transition.start_load("res://scenes/ui/big_map/big_map_scene.tscn")

signal loaded
signal load_failed(error_text: String)

## 加载提示语（复用 loading_screen 文案）
const HINTS := [
	"厉兵秣马...",
	"调兵遣将...",
	"运筹帷幄...",
	"蓄势待发...",
	"粮草先行...",
]
const HEX_ROTATION_SPEED: float = TAU / 2.0  # 六角旋转速度：2 秒一圈
const HINT_INTERVAL: float = 1.0  # 提示语轮换间隔（秒）

@onready var overlay: ColorRect = $Overlay
@onready var hex_frame: TextureRect = $Center/HexFrame
@onready var progress_bar: ProgressBar = $Center/ProgressBar
@onready var percent_label: Label = $Center/PercentLabel
@onready var hint_label: Label = $HintLabel

var _target_scene: String = ""
var _loaded_packed: PackedScene = null
var _load_started: bool = false
var _finished: bool = false
var _hint_index: int = 0
var _hint_timer: float = 0.0


## 开始后台加载 target_scene；加载完成后发 loaded，失败发 load_failed。
func start_load(target_scene: String) -> void:
	_target_scene = target_scene
	_loaded_packed = null
	_finished = false
	_load_started = true
	overlay.visible = true
	hex_frame.visible = true
	hex_frame.rotation = 0.0
	progress_bar.value = 0.0
	percent_label.text = "0%"
	_hint_index = randi() % HINTS.size()
	hint_label.text = str(HINTS[_hint_index])
	_hint_timer = 0.0
	var err: Error = ResourceLoader.load_threaded_request(target_scene)
	if err != OK:
		_finished = true
		load_failed.emit("load_threaded_request 失败: %s err=%s" % [target_scene, str(err)])


func _process(delta: float) -> void:
	if not _load_started or _finished:
		return
	# 旋转六角图标
	hex_frame.rotation += HEX_ROTATION_SPEED * delta
	# 提示语定时轮换（不做打字机，直接换文本）
	_hint_timer += delta
	if _hint_timer >= HINT_INTERVAL:
		_hint_timer = 0.0
		_hint_index = (_hint_index + 1) % HINTS.size()
		hint_label.text = str(HINTS[_hint_index])
	# 轮询线程加载真实进度（0.0 ~ 1.0）
	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_target_scene, progress)
	match status:
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
			var p: float = 0.0
			if progress.size() > 0:
				p = float(progress[0])
			_update_progress(p)
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
			_loaded_packed = ResourceLoader.load_threaded_get(_target_scene) as PackedScene
			_finished = true
			_update_progress(1.0)
			loaded.emit()
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
			_finished = true
			load_failed.emit("场景加载失败: %s" % _target_scene)
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
			_finished = true
			load_failed.emit("场景资源无效: %s" % _target_scene)


## 更新进度条与百分比文本（p 为 0.0 ~ 1.0）
func _update_progress(p: float) -> void:
	progress_bar.value = clampf(p, 0.0, 1.0)
	percent_label.text = "%d%%" % int(roundf(p * 100.0))


## 当前加载进度（0.0 ~ 1.0）
func get_progress() -> float:
	return progress_bar.value


## 已加载完成的 PackedScene（loaded 信号发出后有效，否则为 null）
func get_loaded_packed() -> PackedScene:
	return _loaded_packed
