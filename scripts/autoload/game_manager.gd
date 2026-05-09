extends Node

## 游戏主循环管理器
##
## 负责回合循环、游戏阶段切换、胜利条件判定。
## 阶段 0：仅打印数据加载结果，验证 autoload 顺序与 DataManager 可用。
## 阶段 1：接入 turn_started / turn_ended 信号驱动的回合系统。

const FACTION_IDS: Array[String] = ["qin", "zhao", "qi", "chu", "wei", "yan", "han"]


func _ready() -> void:
	print("[GameManager] 启动 — 阶段 0（地基搭建）")

	var variant_count := 0
	for fid in FACTION_IDS:
		variant_count += DataManager.get_faction_variants(fid).size()

	print("[GameManager] 数据加载验证: %d 地形 / %d 基础兵种 / %d 国家变体 / %d 城市" % [
		DataManager.get_all_terrains().size(),
		DataManager.get_all_unit_types().size(),
		variant_count,
		DataManager.get_all_cities().size(),
	])

	var map_size: Vector2i = DataManager.get_map_size()
	print("[GameManager] 地图尺寸: %d × %d" % [map_size.x, map_size.y])
