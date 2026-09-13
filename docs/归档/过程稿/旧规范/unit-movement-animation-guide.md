# 单位移动动画系统使用指南

## 系统概述

单位移动动画系统实现了：
- 单位在六角网格上的平滑移动
- 移动时自动播放移动动画
- 到达目标后切换为空闲动画
- 支持攻击、受伤、死亡等动画状态

## 文件结构

```
scenes/units/
├── unit.tscn                    # 单位场景
└── unit_movement_test.tscn      # 测试场景

scripts/units/
├── unit.gd                      # 单位核心逻辑
└── unit_movement_test.gd        # 测试脚本

scripts/systems/
└── unit_movement_manager.gd     # 移动管理器
```

## 快速开始

### 1. 创建单位

```gdscript
# 实例化单位场景
var unit_scene = preload("res://scenes/units/unit.tscn")
var unit = unit_scene.instantiate()

# 设置单位类型和阵营
unit.setup("unit_infantry", "base", Vector2i(0, 0))

# 添加到场景
add_child(unit)
```

### 2. 移动单位

```gdscript
# 直接移动到目标六角格
unit.move_to(Vector2i(3, 2))

# 或使用移动管理器（支持队列和路径计算）
var movement_manager = $UnitMovementManager
movement_manager.request_move(unit, Vector2i(3, 2))
```

### 3. 播放动画

```gdscript
# 播放不同动画
unit.play_attack()
unit.play_hurt()
unit.play_death()

# 自动切换回空闲动画
```

## 动画状态

| 动画 | 帧率 | 循环 | 说明 |
|------|------|------|------|
| idle | 8 FPS | ✅ | 空闲状态 |
| move | 8 FPS | ✅ | 移动状态 |
| attack | 8 FPS | ❌ | 攻击动画 |
| hurt | 8 FPS | ❌ | 受伤动画 |
| death | 8 FPS | ❌ | 死亡动画 |

## 移动管理器功能

### 请求移动

```gdscript
# 请求移动（支持队列）
movement_manager.request_move(unit, target_hex)
```

### 计算可达范围

```gdscript
# 获取单位可移动到的六角格
var move_range = 3
var reachable_hexes = movement_manager.get_reachable_hexes(unit, move_range)
```

### 寻路

```gdscript
# 计算路径
var path = movement_manager.find_path(start_hex, end_hex)
```

### 设置地图边界

```gdscript
# 设置地图边界（用于验证移动目标）
movement_manager.set_map_bounds(-20, 20, -20, 20)
```

## 测试场景

打开 `scenes/units/unit_movement_test.tscn` 运行测试：

- **Space**：移动单位到下一个测试点
- **Escape**：重置单位位置
- **T**：测试可达范围计算

## 集成到游戏

### 在主场景中使用

```gdscript
# main.gd
extends Node2D

var unit_scene = preload("res://scenes/units/unit.tscn")
var movement_manager: UnitMovementManager

func _ready():
    # 创建移动管理器
    movement_manager = UnitMovementManager.new()
    add_child(movement_manager)

    # 创建单位
    var unit = unit_scene.instantiate()
    unit.setup("unit_infantry", "base", Vector2i(0, 0))
    add_child(unit)

    # 移动单位
    movement_manager.request_move(unit, Vector2i(5, 3))
```

### 处理输入

```gdscript
func _input(event):
    if event is InputEventMouseButton and event.pressed:
        var target_hex = _get_hex_from_mouse_position(event.position)
        movement_manager.request_move(selected_unit, target_hex)
```

## 注意事项

1. **SpriteFrames 资源**：确保已运行 EditorScript 生成 `unit_frames.tres`
2. **六角格坐标**：使用 `HexAxial` 工具类进行坐标转换
3. **移动速度**：默认 200 像素/秒，可在 `unit.gd` 中调整
4. **动画切换**：移动完成会自动切换回空闲动画

## 扩展建议

1. **路径优化**：实现完整的 A* 算法
2. **移动成本**：不同地形不同移动消耗
3. **移动范围显示**：可视化显示可达范围
4. **移动音效**：添加移动音效
5. **移动特效**：添加移动轨迹特效
