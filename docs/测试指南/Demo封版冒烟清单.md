# Demo 封版冒烟清单

更新日期：2026-06-20

目标：确认当前 Demo 纵向切片能稳定进入、完成、返回，并且主菜单子功能不会黑屏、卡死或残留错误 UI 状态。

## 1. Demo 主线

1. 从项目入口启动，进入模式选择。
2. 选择 `Demo 演武`，进入主界面。
3. 确认左上角显示 `Demo 目标`，目标城市为 `洛邑`。
4. 点击 `出征洛邑`，进入战术演武。
5. Debug 构建可选：点击 `测试作弊：我方伤害 ×20`，确认按钮文字变为已开启。Release 导出中该按钮应隐藏。
6. 攻击洛邑城墙，确认目标面板实时显示城墙 HP。
7. 城墙归零后，移动秦军进入洛邑城格。
8. 预期：演武结束，返回主界面，弹出 Demo 完成反馈，目标显示完成。

## 2. Demo 失败与重试

1. 进入演武后点击 `重置演武`。
2. 预期：地形、单位贴图、城墙信息正常恢复。
3. 点击演武界面的 `关闭`。
4. 预期：返回主界面，工具栏恢复，Demo 目标仍可展开/收起。
5. 再次点击 `出征洛邑`。
6. 预期：可再次进入演武，不黑屏、不卡死。

## 3. 主菜单子功能冒烟

1. 点击 `大地图`，确认大地图打开，资源栏和结束回合按钮可见；关闭后工具栏恢复。
2. 在大地图点击任意城市，确认城池面板打开；点击 `返回大地图` 后回到大地图；再关闭大地图。
3. 点击 `外交`，确认外交面板打开；关闭后工具栏恢复。
4. 点击 `科技`，确认科技树显示；再次点击后隐藏。
5. 点击 `战术演武（阶段1）`，确认场景选择面板打开；返回后工具栏恢复。
6. Debug 构建点击 `事件测试(Debug)`，确认事件测试面板打开；关闭后工具栏恢复。Release 导出中该入口应隐藏。
7. 点击 `返回模式`，确认能回到模式选择界面。
8. Debug 构建在模式选择界面可见 `测试主菜单`；Release 导出中该入口应隐藏。

## 4. 自动化覆盖

当前已覆盖：

- `tests/unit/test_main_turn_ui.gd`：主菜单入口、Demo 入口、胜利弹窗、目标面板收起、主菜单子功能冒烟。
- `tests/unit/test_demo_flow.gd`：Demo 状态推进与洛邑归秦。
- `tests/unit/test_city_combat.gd`：城墙、占领、胜利判定。
- `tests/unit/test_tactical_skirmish_manager.gd`：演武管理器核心行为。
- `tests/unit/test_skirmish_scenario_document.gd`：演武场景数据结构。

建议封版前运行：

```powershell
& 'D:\tools\godot\Godot.exe' --headless --path . --quit
& 'D:\tools\godot\Godot.exe' --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_main_turn_ui.gd -gexit
& 'D:\tools\godot\Godot.exe' --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_demo_flow.gd -gexit
& 'D:\tools\godot\Godot.exe' --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_city_combat.gd -gexit
```

## 5. 已知非封版阻断项

- 科技、外交当前只做冒烟，不作为 Demo 胜利条件。
- `事件测试(Debug)`、`测试作弊`、`测试主菜单` 仅 Debug 构建可见；Release 导出中应隐藏。
- 当前入口仍以 Demo 测试流为主；正式导出前需要再次确认 `project.godot` 主场景配置。
