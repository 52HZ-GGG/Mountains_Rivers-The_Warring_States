# 任务：《山河策》回合 UI — 回合数显示 + 结束回合按钮

> **涉及文件**：仅 `scenes/main/main.gd` 和 `scenes/main/main.tscn`
> **不要修改** `game_manager.gd`、`signal_bus.gd`、`resource_bar.gd` 或其他任何文件

---

## 背景

回合系统后端已完整（`GameManager` 状态机、`end_current_turn()`、`process_ai_turn()`、`ResourceBar.refresh()`），但屏幕上没有显示当前回合数和季节。同时"结束回合"按钮是代码动态创建的，需要让它更醒目并加入回合信息。

---

## 实现要求

### 1. 在主场景顶部添加回合信息栏

在 `main.tscn` 中（或在 `main.gd._ready()` 中代码创建），添加一个 `HBoxContainer` 作为回合信息栏，包含：

- **回合数 Label**：显示"第 1 回合"
- **季节 Label**：显示"春"（中文单字）
- **势力 Label**：显示"秦国行动"或"赵国行动..."
- **结束回合 Button**：醒目的按钮

位置：在 `ResourceBar` 的下方、`DiplomacyButton` 行的上方。

### 2. 季节中文映射

```gdscript
const SEASON_CN := {"spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬"}
```

`GameManager.get_current_turn()` 返回回合数，`CityManager.get_current_season(turn)` 返回英文季节字符串（`"spring"` 等）。

### 3. 结束回合按钮

已有代码在 `_ready()` 中动态创建了"结束回合"按钮。**删掉那段动态创建代码**，改为在 `.tscn` 中静态定义（或在 `_ready()` 中创建时放到回合信息栏内），并使用 `SkirmishTileTextures.styled_button()` 样式使其醒目。

按钮文字：正常状态显示"结束回合"，玩家回合结束后变为"下一回合"（见下方 AI 处理）。

### 4. AI 回合自动推进

当前 `_on_next_turn_pressed()` 只调用 `end_current_turn()`。需要改为：

```gdscript
func _on_next_turn_pressed() -> void:
    if GameManager.get_current_phase() != GameManager.Phase.ACTION:
        return
    # 结束玩家回合
    GameManager.end_current_turn()
    _update_turn_info()
    # 如果轮到 AI，自动推进直到回到玩家
    _process_ai_turns()
    _update_turn_info()
    # 刷新资源栏
    if _resource_bar != null and _resource_bar.has_method("refresh"):
        _resource_bar.refresh()
```

`_process_ai_turns()` 逻辑：
- 循环调用 `GameManager.process_ai_turn()` + `GameManager.end_current_turn()`
- 直到 `GameManager.get_current_faction() == GameManager.get_player_faction()`
- 循环中每步用 `await get_tree().process_frame` 防止卡死（或直接同步跑也行，AI 回合目前很快）
- 安全阀：最多循环 100 次防止死循环

### 5. 信号连接

在 `_ready()` 中连接：
```gdscript
SignalBus.turn_started.connect(_on_turn_started)
```

`_on_turn_started` 回调更新回合信息栏。`_update_turn_info()` 函数从 GameManager 读取回合数、季节、当前势力，更新 Label 文本。

### 6. 视觉样式建议

- 回合数字号 18-20px，白色
- 季节字号 16px，按季节着色（春绿/夏红/秋橙/冬蓝）
- 势力名用势力颜色（从 `factions.json` 的 `color` 字段读取）
- 结束回合按钮放在信息栏右侧，字号 15px

---

## 不做

- 不改 `GameManager` 的任何逻辑
- 不加回合过渡动画（后续再做）
- 不加 AI 思考进度条（AI 回合目前瞬间完成）
- 不动 `ResourceBar`、`CityPanel`、`DiplomacyPanel` 等其他 UI
- 不改 `main.tscn` 中已有节点的布局（只在按钮行上方插入新节点）

---

## 验证方式

1. Godot 编辑器中启动 main 场景，顶部应显示"第 1 回合 · 春 · 秦国行动"
2. 点击"结束回合"，应自动推进 AI 回合后回到玩家，回合数 +1，季节每 4 回合切换
3. `ResourceBar` 资源数值随回合变化
4. 不产生任何运行时错误
