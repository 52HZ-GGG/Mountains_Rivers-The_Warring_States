# 《山河策》Demo 纵向切片规划

> 更新日期：2026-06-20  
> 目标：尽快做出一个可试玩、可胜利、可演示的最小 Demo。  
> 范围原则：先做一条 10~20 分钟能跑通的闭环，不补完整游戏。

---

## 1. Demo 定义

本 Demo 固定为 **秦国开局**。

核心目标：

1. 玩家进入主游戏后看到明确任务。
2. 玩家以秦国完成一场指定战术演武。
3. 演武胜利后，战略层目标城 **洛邑 `luoyi`** 归秦。
4. 系统弹出 Demo 胜利反馈。

验收句：

> 从启动进入秦国开局，按任务提示完成整备与演武，胜利后洛邑归秦，并看到 Demo 完成弹窗。

---

## 2. 非目标

以下内容不进入第一版 Demo 阻塞项：

| 系统 | Demo 处理 |
|---|---|
| 大夫系统 | 暂不做完整获取、任命、升级闭环 |
| 学派系统 | 保留默认学派，不做政策/经验完整循环 |
| 奇观系统 | 不作为 Demo 胜利条件 |
| 正式存档 | 暂不要求 |
| 完整七国平衡 | 只校准秦国 Demo 线路 |
| 全地图战略单位移动 | 暂不要求 |
| 长期外交博弈 | 展示已有面板即可，不作为胜负核心 |

---

## 3. P0 必做闭环

| 编号 | 任务 | 内容 | 主要文件/模块 | 验收 |
|---|---|---|---|---|
| P0-1 | Demo 状态模块 | 新增轻量状态管理，记录目标城、任务步骤、是否完成 | 建议新增 `scripts/autoload/demo_flow.gd` 或普通 helper | 能查询/推进 Demo 任务 |
| P0-2 | 任务面板 | 显示当前目标、完成状态、下一步提示 | 建议新增 `scenes/ui/demo/demo_objective_panel.*` | 玩家不读文档也知道下一步 |
| P0-3 | 主场景接线 | 在 `main.gd` 挂载任务面板，监听演武胜负 | `scenes/main/main.gd` | 启动后能看到 Demo 目标 |
| P0-4 | 演武胜利反写战略层 | 演武胜利且赢家为秦时，调用城市归属变更，让 `luoyi` 归秦 | `main.gd` + `CityManager` 公开接口 | 赢演武后 `CityManager.get_city_state("luoyi").current_faction_id == "qin"` |
| P0-5 | Demo 胜利弹窗 | 洛邑归秦后弹出完成反馈 | 建议新增 `scenes/ui/demo/demo_victory_popup.*` | 玩家明确知道 Demo 已完成 |
| P0-6 | 基础稳定验收 | 启动、打开大地图、打开城市、开演武、胜利、返回不崩 | 手动测试 + 必要 GUT | 10~20 分钟流程无阻断 |

---

## 4. P1 体验补强

| 编号 | 任务 | 内容 | 验收 |
|---|---|---|---|
| P1-1 | 推荐演武入口 | 任务面板提供“出征洛邑”按钮，直接进入指定演武场景 | 玩家少走场景选择器 |
| P1-2 | 节奏校准 | 秦国资源、建筑、科技至少在 Demo 内有一次正反馈 | 3~5 回合内能看到成长 |
| P1-3 | 隐藏调试入口 | Demo 默认隐藏 `事件测试` 等调试按钮 | 首屏不像开发工具 |
| P1-4 | 失败处理 | 演武失败后可重试或回到主场景 | 失败不进入死局 |
| P1-5 | 视觉缺口收尾 | 单位贴图、外交背景叠图、缺失资源引用做一次巡检 | 试玩不出现明显破图/叠图 |

---

## 5. P2 后续打磨

| 编号 | 任务 | 内容 |
|---|---|---|
| P2-1 | Demo 片头文案 | 用一段短公告解释秦国东进目标 |
| P2-2 | 更多任务步骤 | 增加建造、研究、外交提示 |
| P2-3 | 战后结算 | 显示伤亡、奖励、洛邑归属变化 |
| P2-4 | 音效与动画 | 胜利弹窗、任务完成、出征按钮加演出 |
| P2-5 | 自动化验收 | 补一条 demo flow 测试或手动验收脚本 |

---

## 6. 建议指定演武场景

第一版建议复用已有场景，不新增复杂战斗数据。

优先候选：

| 场景 ID | 名称 | 理由 |
|---|---|---|
| `siege_warfare` | 攻城战 | 与“夺取洛邑”语义最贴近 |
| `basic_plains` | 基础平原战 | 最短、最稳，适合第一版闭环 |

建议：

> 第一版用 `basic_plains` 跑通流程；若稳定，再切到 `siege_warfare` 做更贴近攻城的体验。

---

## 7. 主控接口约定

为减少并行冲突，建议主控先冻结以下接口：

```gdscript
# DemoFlow 建议接口
func get_target_city_id() -> String
func get_current_step() -> String
func mark_step_completed(step_id: String) -> void
func is_demo_complete() -> bool
func complete_demo() -> void
```

建议任务步骤：

| step_id | 含义 |
|---|---|
| `open_big_map` | 打开大地图 |
| `inspect_luoyi` | 查看洛邑 |
| `prepare_qin` | 完成整备动作 |
| `win_skirmish` | 赢下指定演武 |
| `capture_luoyi` | 洛邑归秦 |
| `demo_complete` | Demo 完成 |

主控接线建议：

1. `main.gd` 在 `_ready()` 创建任务面板。
2. `main.gd` 监听 `TacticalSkirmishManager.skirmish_ended`。
3. 若赢家为 `qin` 且 Demo 未完成，则调用 `CityManager.change_ownership("luoyi", "qin")` 或现有等价接口。
4. 标记 `capture_luoyi` 与 `demo_complete`。
5. 弹出 Demo 胜利反馈。

注意：

- 不建议多个子进程同时改 `main.gd`。
- 不建议多个子进程同时改 `tactical_skirmish_manager.gd`。
- 优先新增小文件，再由主控统一接入。

---

## 8. 子进程任务包

### 子进程 A：任务面板与胜利弹窗

目标：

实现 Demo 专用 UI，不改核心玩法。

建议范围：

| 文件 | 操作 |
|---|---|
| `scenes/ui/demo/demo_objective_panel.gd` | 新增 |
| `scenes/ui/demo/demo_objective_panel.tscn` | 新增 |
| `scenes/ui/demo/demo_victory_popup.gd` | 新增 |
| `scenes/ui/demo/demo_victory_popup.tscn` | 新增 |

验收：

- 面板能显示目标：`攻取洛邑`。
- 能显示步骤完成/未完成。
- 胜利弹窗能显示 Demo 完成。
- 不直接修改 `main.gd`，只提供清晰方法供主控接入。

提示词：

```text
你是子进程 A。阅读 AGENTS.md 和 docs/程序进度/PROMPT-Demo纵向切片.md。
只做 Demo 任务面板和胜利弹窗 UI，优先新增 scenes/ui/demo/ 下的小文件。
不要改 main.gd，不要改核心系统。提供 open/update/show_victory 等清晰方法供主控接入。
回复中文，GDScript 使用静态类型，改动保持最小。
```

### 子进程 B：演武胜负体验与失败处理

目标：

检查战术演武从开始到胜负是否适合作为 Demo 战斗。

建议范围：

| 文件 | 操作 |
|---|---|
| `data/skirmish_scenarios.json` | 仅在必要时微调 Demo 目标场景 |
| `scenes/ui/skirmish/skirmish_mvp_panel.gd` | 只做必要失败/重试反馈 |

验收：

- 推荐场景能在 5~8 分钟内完成。
- 失败后可以重试或关闭返回。
- 不改战略城市归属逻辑。

提示词：

```text
你是子进程 B。阅读 AGENTS.md 和 docs/程序进度/PROMPT-Demo纵向切片.md。
检查 basic_plains 和 siege_warfare 哪个更适合作为第一版 Demo 战斗。
只处理演武胜负体验、失败/重试反馈和必要的小范围数值建议。
不要实现洛邑归属反写，那由主控负责。
回复中文，保持改动最小。
```

### 子进程 C：Demo 数值节奏

目标：

保证秦国 Demo 前几回合不缺关键资源，经营动作有反馈。

建议范围：

| 文件 | 操作 |
|---|---|
| `data/balance_params.json` | 必要时微调 demo 相关参数 |
| `data/cities.json` | 原则上不改 Schema，只在必要时调初始值 |
| `data/buildings.json` | 必要时校对成本/工期 |

验收：

- 秦国开局能做至少一个城市经营动作。
- 3~5 回合内能看到资源或建筑反馈。
- 不影响 JSON 字段名。

提示词：

```text
你是子进程 C。阅读 AGENTS.md 和 docs/程序进度/PROMPT-Demo纵向切片.md。
只做 Demo 节奏校准建议或小范围 JSON 数值调整，目标是秦国 10~20 分钟试玩顺畅。
禁止改 JSON 字段名，禁止把平衡数值写进代码。
回复中文，说明每个数值调整的理由和验收方式。
```

### 子进程 D：资源与明显 UI 缺口巡检

目标：

收尾已知视觉问题，避免 Demo 出现明显破图。

建议范围：

| 问题 | 相关文件 |
|---|---|
| 单位贴图命名混用 | `scripts/units/unit.gd`、`scenes/ui/skirmish/skirmish_mvp_panel.gd` |
| 外交面板额外背景 | `scenes/ui/diplomacy/diplomacy_panel.gd` |
| 缺失资源引用 | `scripts/ui/skirmish_tile_textures.gd` |

验收：

- 基础演武单位图正常显示。
- 外交面板无额外叠图。
- 资源缺失有明确清单。

提示词：

```text
你是子进程 D。阅读 AGENTS.md、docs/协作/Agent交接-2026-05-30.md 和 docs/程序进度/PROMPT-Demo纵向切片.md。
优先修复 Demo 试玩会直接看到的视觉缺口：单位贴图命名、外交面板叠图、缺失资源引用。
注意旧交接文档提到部分 .gd 文件存在编码风险，改动必须极小，避免整文件重写。
回复中文，并列出已修复和仍缺失的资源。
```

### 子进程 E：验收清单与测试

目标：

建立 Demo 手动验收清单，必要时补一两个低风险 GUT 测试。

建议范围：

| 文件 | 操作 |
|---|---|
| `docs/测试指南/Demo纵向切片测试指南.md` | 新增 |
| `tests/unit/test_demo_flow.gd` | 可选，视 DemoFlow 是否落地 |

验收：

- 有一条从启动到胜利的手动步骤。
- 每步写明预期结果。
- 如果新增 DemoFlow，则至少测目标城 ID、完成状态推进。

提示词：

```text
你是子进程 E。阅读 AGENTS.md 和 docs/程序进度/PROMPT-Demo纵向切片.md。
编写 Demo 纵向切片测试指南，覆盖启动、任务面板、大地图、演武、洛邑归秦、胜利弹窗。
如 DemoFlow 已实现，可补最小 GUT 测试；不要改核心玩法。
回复中文，说明如何验收。
```

---

## 9. 推荐执行顺序

1. 主控新增 DemoFlow 接口与目标常量。
2. 子进程 A/D/C 并行。
3. 主控接入 `main.gd` 与演武胜利反写。
4. 子进程 B 检查战斗时长与失败处理。
5. 子进程 E 写验收指南。
6. 主控统一跑流程，记录剩余缺口。

---

## 10. 当前决策记录

| 决策 | 结果 |
|---|---|
| Demo 玩家势力 | 固定秦国 `qin` |
| Demo 目标城 | 洛邑 `luoyi` |
| Demo 胜利条件 | 赢演武后洛邑归秦，并弹出胜利反馈 |
| 第一版范围 | 纵向切片，不补完整大夫/学派/奇观/存档 |

