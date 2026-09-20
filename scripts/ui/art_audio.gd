extends Node

## 美术音频播放门面：优先 assets/audio/**，文件不存在则静默失败。
## 不依赖具体 UI；任何节点 ArtAudio.play("ui_click") 即可。

var _bgm: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
const _SFX_POOL: int = 6
var _muted: bool = false


func _ready() -> void:
	if Engine.has_singleton("SignalBus") or true:
		var sb := get_node_or_null("/root/SignalBus")
		if sb != null and sb.has_signal("turn_started"):
			sb.turn_started.connect(_on_turn_started)
		if sb != null and sb.has_signal("game_over"):
			sb.game_over.connect(_on_game_over)
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "ArtBgmPlayer"
	_bgm.bus = "Master"
	add_child(_bgm)
	for i in range(_SFX_POOL):
		var p := AudioStreamPlayer.new()
		p.name = "ArtSfx_%d" % i
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)


func set_muted(muted: bool) -> void:
	_muted = muted
	if muted:
		_bgm.stop()
		for p in _sfx_players:
			p.stop()


func play_sfx(key: String, volume_db: float = 0.0) -> void:
	if _muted or not is_instance_valid(ArtCatalog):
		return
	var path := ""
	if ArtCatalog.has_method("sfx_path"):
		path = str(ArtCatalog.sfx_path(key))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	if _sfx_players.is_empty():
		return
	var player: AudioStreamPlayer = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


## 兼容别名
func play(key: String, volume_db: float = 0.0) -> void:
	play_sfx(key, volume_db)


func play_bgm(kind: String = "main", volume_db: float = -6.0) -> void:
	if _muted or not is_instance_valid(ArtCatalog):
		return
	var path := ""
	if kind == "battle":
		path = str(ArtCatalog.battle_bgm_path()) if ArtCatalog.has_method("battle_bgm_path") else ""
	else:
		path = str(ArtCatalog.bgm_path())
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	_bgm.stream = stream
	_bgm.volume_db = volume_db
	_bgm.play()


func stop_bgm() -> void:
	if is_instance_valid(_bgm):
		_bgm.stop()


## 给已有 Button 挂 ui_click 音效
func attach_button_click(btn: Button) -> void:
	if btn == null:
		return
	if not btn.pressed.is_connected(_on_any_button_pressed):
		btn.pressed.connect(_on_any_button_pressed.bind(btn))


func _on_any_button_pressed(_btn: Button) -> void:
	play_sfx("ui_click")


## 批量给容器下所有 Button 挂音效
func attach_clicks_in(node: Node) -> void:
	if node == null:
		return
	if node is Button:
		attach_button_click(node as Button)
	for child in node.get_children():
		attach_clicks_in(child)


func _on_turn_started(_turn: int, _faction: String) -> void:
	play_sfx("turn_start")


func _on_game_over(_winner: String) -> void:
	play_sfx("event_popup")
