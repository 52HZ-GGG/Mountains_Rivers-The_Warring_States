extends SceneTree

## 端口化审计脚本：扫描场景/UI 脚本中的越界访问模式。
## 目标：机制全部端口化后，场景只做「接入端 + 渲染」，不直接碰文件/数据/私有成员。
## 检查项：
##   1. 直接文件 IO（FileAccess.open / file_exists）—— 场景不应自己读写文件
##   2. 直接引用 res://data/ 路径 —— 数据应经 DataManager 端口读取
##   3. 直接写 user:// 路径 —— 存档应经 SaveManager 端口
##   4. 跨类私有成员访问（Xxx._yyy）—— 机制层对外只暴露公共 API
##   5. 直接 JSON 解析（JSON.parse_string / stringify）—— 应经数据/存档端口
## 用法：godot --headless --path <project> -s res://tools/audit_scene_porting.gd

const SCAN_DIRS: Array[String] = ["res://scenes", "res://scripts/ui"]

var _patterns: Array[Dictionary] = []


func _init() -> void:
	var io_re := RegEx.new()
	io_re.compile("FileAccess\\.(open|file_exists|get_file_as_bytes)")
	var data_re := RegEx.new()
	data_re.compile("\"res://data/")
	var user_re := RegEx.new()
	user_re.compile("\"user://")
	var private_re := RegEx.new()
	private_re.compile("(^|[^\"\\w])[A-Z][A-Za-z0-9_]*\\._[a-zA-Z]")
	var json_re := RegEx.new()
	json_re.compile("JSON\\.(parse_string|stringify)")
	_patterns = [
		{"name": "直接文件 IO", "re": io_re},
		{"name": "直接引用数据文件", "re": data_re},
		{"name": "直接写用户文件", "re": user_re},
		{"name": "跨类私有成员访问", "re": private_re},
		{"name": "直接 JSON 解析", "re": json_re},
	]
	_run()


func _run() -> void:
	var total_files: int = 0
	var total_hits: int = 0
	var hit_dirs: Dictionary = {}
	for dir in SCAN_DIRS:
		for path in _collect_gd(dir):
			total_files += 1
			var hits: Array = _scan_file(path)
			if hits.is_empty():
				continue
			total_hits += hits.size()
			hit_dirs[path] = hits.size()
			print("== %s" % path)
			for h in hits:
				print("   L%s [%s] %s" % [h["line"], h["pattern"], h["text"]])
	print("")
	print("审计完成：扫描 %d 个文件，%d 个文件命中，共 %d 处越界点。" % [total_files, hit_dirs.size(), total_hits])
	quit()


func _collect_gd(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			out.append_array(_collect_gd(full))
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return out


func _scan_file(path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var line_no: int = 0
	while not f.eof_reached():
		line_no += 1
		var text: String = f.get_line()
		if text.strip_edges().begins_with("#"):
			continue
		for p in _patterns:
			if (p["re"] as RegEx).search(text) != null:
				out.append({"line": line_no, "pattern": str(p["name"]), "text": text.strip_edges()})
	f.close()
	return out
