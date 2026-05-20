extends Node
class_name UnitMovementManager

## 单位移动管理器
## 处理单位在六角网格上的移动逻辑

## 移动队列
var movement_queue: Array[Dictionary] = []

## 当前正在移动的单位
var moving_units: Array[Unit] = []

## 地图边界（根据实际地图设置）
var map_bounds_q_min: int = -10
var map_bounds_q_max: int = 10
var map_bounds_r_min: int = -10
var map_bounds_r_max: int = 10


func _process(delta: float) -> void:
	_process_movement_queue()


## 添加移动请求
func request_move(unit: Unit, target_hex: Vector2i) -> void:
	if not _is_valid_hex(target_hex):
		push_warning("UnitMovementManager: Invalid target hex %s" % str(target_hex))
		return

	if unit.is_moving:
		# 如果单位正在移动，加入队列
		movement_queue.append({
			"unit": unit,
			"target_hex": target_hex
		})
	else:
		# 直接开始移动
		_start_move(unit, target_hex)


## 开始移动
func _start_move(unit: Unit, target_hex: Vector2i) -> void:
	unit.move_to(target_hex)
	moving_units.append(unit)

	# 连接信号（如果单位有的话）
	# unit.movement_finished.connect(_on_unit_movement_finished.bind(unit))


## 处理移动队列
func _process_movement_queue() -> void:
	if movement_queue.is_empty():
		return

	# 检查是否有空闲单位可以开始移动
	var i := 0
	while i < movement_queue.size():
		var request: Dictionary = movement_queue[i]
		var unit: Unit = request["unit"]

		if not unit.is_moving:
			_start_move(unit, request["target_hex"])
			movement_queue.remove_at(i)
		else:
			i += 1


## 单位移动完成回调
func _on_unit_movement_finished(unit: Unit) -> void:
	moving_units.erase(unit)


## 验证六角格坐标是否有效
func _is_valid_hex(hex: Vector2i) -> bool:
	return hex.x >= map_bounds_q_min and hex.x <= map_bounds_q_max \
		and hex.y >= map_bounds_r_min and hex.y <= map_bounds_r_max


## 获取单位可以移动到的六角格（基于移动范围）
func get_reachable_hexes(unit: Unit, move_range: int) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	var start_hex := unit.hex_position

	# 使用 BFS 计算可达范围
	var visited: Dictionary = {}
	var queue: Array[Dictionary] = [{"hex": start_hex, "cost": 0}]
	visited[start_hex] = 0

	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var current_hex: Vector2i = current["hex"]
		var current_cost: int = current["cost"]

		if current_cost > 0:
			reachable.append(current_hex)

		if current_cost >= move_range:
			continue

		for neighbor: Vector2i in HexAxial.neighbors_hex(current_hex):
			if not _is_valid_hex(neighbor):
				continue

			var new_cost: int = current_cost + 1
			if not visited.has(neighbor) or visited[neighbor] > new_cost:
				visited[neighbor] = new_cost
				queue.append({"hex": neighbor, "cost": new_cost})

	return reachable


## 计算路径（A* 算法）
func find_path(start_hex: Vector2i, end_hex: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []

	# 简化版本：直线路径
	# 实际项目中应该实现完整的 A* 算法
	var current := start_hex
	while current != end_hex:
		var neighbors := HexAxial.neighbors_hex(current)
		var best_neighbor: Vector2i = current
		var best_distance: int = 999999

		for neighbor: Vector2i in neighbors:
			if not _is_valid_hex(neighbor):
				continue

			var distance := HexAxial.hex_distance_hex(neighbor, end_hex)
			if distance < best_distance:
				best_distance = distance
				best_neighbor = neighbor

		if best_neighbor == current:
			break  # 无法继续前进

		path.append(best_neighbor)
		current = best_neighbor

	return path


## 设置地图边界
func set_map_bounds(q_min: int, q_max: int, r_min: int, r_max: int) -> void:
	map_bounds_q_min = q_min
	map_bounds_q_max = q_max
	map_bounds_r_min = r_min
	map_bounds_r_max = r_max
