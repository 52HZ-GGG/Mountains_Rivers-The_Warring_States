@tool
class_name GenerateUnitSpriteFrames
extends EditorScript
## 一键生成所有兵种的 SpriteFrames 资源
##
## 使用方法：
##   1. 确保 assets/sprites/units/ 下已有单帧 PNG 文件
##      （由 split_animations.py 生成，已复制到项目中）
##   2. 在 Godot 编辑器中：Project > Tools > EditorScript > 选择本文件
##   3. 等待控制台输出完成信息
##
## 输出：
##   每个兵种目录下生成 unit_xxx_frames.tres（SpriteFrames 资源）
##   包含 idle/move/attack/hurt/death 5 个动画

## 帧率（FPS）
const FPS: float = 8.0

## 动画名称列表
const ANIM_NAMES: Array[String] = ["idle", "move", "attack", "hurt", "death"]

## 是否循环播放（idle 和 move 循环，其他不循环）
const LOOP_ANIMS: Array[String] = ["idle", "move"]

## 单位根目录
const UNITS_ROOT: String = "res://assets/sprites/units/"


func _run() -> void:
	print("=== 兵种 SpriteFrames 生成器 ===")
	print("扫描目录: ", UNITS_ROOT)
	print("")

	var total_units: int = 0
	var total_anims: int = 0
	var total_frames: int = 0

	# 递归扫描所有目录，找到包含动画帧的文件夹
	var results: Array[Dictionary] = []
	_scan_for_anim_dirs(UNITS_ROOT, results)

	if results.is_empty():
		print("未找到动画帧文件，请确认目录结构：")
		print("  assets/sprites/units/base/unit_infantry/idle_01.png ...")
		return

	for result in results:
		var unit_dir: String = result["dir"]
		var frames_by_anim: Dictionary = result["frames"]

		var sf := SpriteFrames.new()

		# 删除默认动画
		if sf.has_animation("default"):
			sf.remove_animation("default")

		var anim_count: int = 0
		var frame_count: int = 0

		for anim_name: String in ANIM_NAMES:
			if not frames_by_anim.has(anim_name):
				continue

			var frame_files: Array = frames_by_anim[anim_name]
			if frame_files.is_empty():
				continue

			sf.add_animation(anim_name)
			sf.set_animation_speed(anim_name, FPS)
			sf.set_animation_loop(anim_name, anim_name in LOOP_ANIMS)

			for frame_path: String in frame_files:
				var tex: Texture2D = load(frame_path) as Texture2D
				if tex:
					sf.add_frame(anim_name, tex)
					frame_count += 1

			anim_count += 1

		# 保存 .tres 文件
		var tres_path: String = unit_dir.path_join("unit_frames.tres")
		var err: Error = ResourceSaver.save(sf, tres_path)
		if err == OK:
			print("  [OK] ", tres_path, " (", anim_count, " anims, ", frame_count, " frames)")
			total_units += 1
			total_anims += anim_count
			total_frames += frame_count
		else:
			print("  [ERR] ", tres_path, " error: ", error_string(err))

	print("")
	print("=== 完成: ", total_units, " 兵种, ", total_anims, " 动画, ", total_frames, " 帧 ===")


## 递归扫描目录，找到包含 idle_01.png 等动画帧的文件夹
func _scan_for_anim_dirs(path: String, results: Array[Dictionary]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()

	var has_frames: bool = false
	var frames_by_anim: Dictionary = {}

	while entry != "":
		var full_path: String = path.path_join(entry)

		if dir.current_is_dir():
			# 递归扫描子目录
			_scan_for_anim_dirs(full_path, results)
		elif entry.ends_with(".png"):
			# 解析文件名：idle_01.png -> anim_name="idle"
			var parts: PackedStringArray = entry.replace(".png", "").rsplit("_", true, 1)
			if parts.size() == 2:
				var anim_name: String = parts[0]
				var frame_num: String = parts[1]

				# 验证是数字帧号
				if frame_num.is_valid_int() and anim_name in ANIM_NAMES:
					if not frames_by_anim.has(anim_name):
						frames_by_anim[anim_name] = []
					frames_by_anim[anim_name].append(full_path)
					has_frames = true

		entry = dir.get_next()

	dir.list_dir_end()

	# 如果当前目录有动画帧，加入结果
	if has_frames:
		# 排序帧文件（确保 01, 02, 03... 顺序正确）
		for anim_name: String in frames_by_anim:
			frames_by_anim[anim_name].sort()

		results.append({
			"dir": path,
			"frames": frames_by_anim,
		})
