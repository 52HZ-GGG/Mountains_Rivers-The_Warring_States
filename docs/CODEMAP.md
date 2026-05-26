# CODEMAP — 项目代码导航索引

> 自动生成于 2026-05-20，供快速定位文件职责和关键函数。

---

## 1. Autoload 单例（scripts/autoload/）

### signal_bus.gd — 79行
全局信号总线，零逻辑。声明 30+ 信号供系统间解耦通信。
- 信号分类：回合(turn_started/ended)、事件(event_triggered/resolved)、外交(war_declared/alliance_formed)、科技(tech_research_completed)、城市(city_occupied/building_completed)

### data_manager.gd — 516行
只读数据层。启动时加载 `data/*.json`，构建 id 索引，提供查询 API。
- `get_terrain(id)` / `get_unit_type(id)` / `get_city(id)` — 基础查询
- `get_balance_param(path)` — 点分路径查询平衡参数（如 `combat.fire_atk_bonus`）
- `get_counter_multiplier(atk_id, def_id)` — 克制矩阵
- `validate_data()` — 运行时数据完整性校验

### game_manager.gd — 504行
游戏主循环状态机。Phase: GAME_INIT → TURN_START → ACTION → TURN_END → GAME_OVER。
- `start_game(active_factions, player_faction)` — 初始化并开始游戏
- `end_current_turn()` — 结束当前势力回合，推进到下一个
- `process_ai_turn()` — AI回合：外交→科技→结束
- `check_victory()` — 征服胜利判定（最后存活 / 玩家灭亡）
- `get_faction_resources(faction_id)` / `apply_faction_resource_delta(...)` — 资源管理

### city_manager.gd — 708行
50城运行时状态管理。
- `get_city_state(city_id)` / `get_faction_city_states(faction_id)` — 城市查询
- `can_build(city_id, building_id)` / `start_build(...)` — 建造验证+执行
- `change_ownership(city_id, new_faction_id)` — 城市占领
- `process_turn(faction_id)` — 回合结算：建造队列+人口增长
- `get_faction_total_production(faction_id)` — 资源产出汇总

### event_manager.gd — 440行
三阶段事件管线：链式事件(保证触发) → 季节事件(概率1.0) → 池竞争(优先级排序)。
- `resolve_event_choice(event_id, choice_id)` — 处理玩家事件选择
- `get_save_data()` / `load_save_data(data)` — 序列化

### diplomacy_system.gd — 745行
外交系统：好感/声望/条约/战争/附庸/商路，13种外交行动。
- `declare_war(attacker, defender)` — 宣战（断盟+降好感）
- `form_alliance(faction_a, faction_b)` — 结盟（好感≥30）
- `send_gift(sender, receiver, tier)` — 送礼提升好感
- `request_vassal_escape(vassal_id, method)` — 附庸独立（3种方式）

### tech_system.gd — 465行
科技树系统。54科技，前置条件/特殊条件/效果叠加。
- `start_research(tech_id)` / `can_research(tech_id)` — 研究控制
- `get_attack_modifier(target)` / `get_defense_modifier(target)` — 战斗修正
- `is_unit_unlocked(unit_id)` / `can_traverse_terrain(terrain)` — 解锁查询

### tactical_skirmish_manager.gd — 2303行
**最大文件**。战术演武引擎：六角格Dijkstra寻路、战斗结算、攻城、海军、火攻、补给、士气、AI。
- `start_skirmish()` / `start_skirmish_with_config(cfg, season)` — 开始演武
- `try_move_unit(unit_id, dest)` — 移动单位
- `try_player_attack(attacker_id, defender_id)` — 执行攻击（含反击/夹击/火攻/海军修正）
- `compute_attack_preview(attacker_id, defender_id_or_cell)` — 伤害预览（不扣血）
- `try_attack_city_wall(attacker_id, cell)` — 直接攻击城墙
- `try_retreat(unit_id)` — 撤退（消耗全部移动力）
- `begin_player_phase()` — 回合开始处理（士气/灼烧DOT/补给/治疗）
- `check_victory()` — 占领敌方城格即胜

---

## 2. 系统模块（scripts/systems/）

### combat_resolver.gd — 227行
纯函数战斗伤害计算器，无状态。公式：攻防加法层 → 克制乘算 → 扣减防御 → 随机波动(±10%) → 崩溃态乘算。
- `compute_damage(...)` — 完整伤害流水线，返回 `{damage, was_ambush, skipped, effective_atk}`
- `compute_counter_attack(...)` — 反击伤害（委托给 compute_damage）
- `should_trigger_counter(def_type, is_ranged_atk)` — 近战触发反击，远程不触发
- `is_ranged_unit(unit_type_id)` — 远程单位判断
- `compute_counter_multiplier(atk_id, def_id)` — 克制乘算（含 anti_cavalry 覆盖）

### hex_axial.gd — 97行
静态六角坐标工具类（class_name HexAxial）。
- `offset_odd_r_to_axial(col, row)` / `axial_to_offset_odd_r(q, r)` — 坐标转换
- `hex_distance_hex(a, b)` — 六角距离
- `neighbors_hex(cell)` — 6个邻居坐标

### unit_movement_manager.gd — 148行
单位移动管理器（class_name UnitMovementManager）。
- `get_reachable_hexes(unit, move_range)` — BFS泛洪返回可达范围
- `find_path(start, end)` — 简化寻路（贪心最近邻）

---

## 3. AI 模块（scripts/ai/）

### diplomacy_ai.gd — 338行
静态类 DiplomacyAI。AI外交决策引擎。
- `evaluate_diplomacy(faction_id, turn_number)` — 入口：概率触发外交评估
- 战争目标评估（距离/实力/好感评分）、停战提议、结盟、合纵触发（均势机制）

---

## 4. UI 脚本（scripts/ui/）

### skirmish_hex_cell.gd — 225行
单个六角格控件。渲染地形纹理、悬停高亮、点击检测。
- 信号：`hex_clicked(q, r)`

### skirmish_hex_map_canvas.gd — 78行
六角地图纹理渲染器。单次 `_draw()` 绘制所有地形，消除接缝。

### skirmish_tile_textures.gd — 146行
静态类。地形/阵营/事件/兵种贴图路径注册表，缓存加载。

### shader_helpers.gd — 87行
静态类。ShaderMaterial 工厂方法（文化覆盖/羊皮纸UI/按钮状态/高亮脉冲）。

---

## 5. 单位脚本（scripts/units/）

### unit.gd — 202行
单位实体控制器（class_name Unit）。管理类型/阵营/六角格位置/动画状态机(IDLE/MOVE/ATTACK/HURT/DEATH)。

---

## 6. 场景文件（scenes/）

| 场景 | 路径 | 用途 |
|------|------|------|
| 主场景 | scenes/main/main.tscn | 游戏入口，含外交/科技/演武/大地图按钮 |
| 大地图 | scenes/ui/big_map/big_map_panel.tscn | 30×20战略地图，缩放/政治覆盖/悬停信息 |
| 演武面板 | scenes/ui/skirmish/skirmish_mvp_panel.tscn | 战术战斗六角地图，回合控制/日志/悬停信息 |
| 场景选择 | scenes/ui/skirmish/skirmish_scenario_panel.tscn | 7个预设演武场景选择器 |
| 测试指南 | scenes/ui/skirmish/skirmish_test_guide_panel.tscn | 演武测试说明面板 |
| 外交面板 | scenes/ui/diplomacy/diplomacy_panel.tscn | 势力关系/外交行动 |
| 谈判对话 | scenes/ui/diplomacy/negotiation_dialog.tscn | 停战/和平条款确认框 |
| 城市面板 | scenes/ui/city_panel/city_panel.tscn | 城市详情/建造/升级 |
| 增减益 | scenes/ui/buff/buff_panel.tscn | 活跃增益/减益效果列表 |
| 事件弹窗 | scenes/ui/event_popup/event_popup.tscn | 随机事件显示 |
| 事件测试 | scenes/ui/event_test/event_test_panel.tscn | 事件触发调试面板 |
| 启动流 | scenes/ui/splash/*.tscn | 闪屏→模式选择→阵营选择→加载 |
| 单位 | scenes/units/unit.tscn | 单位实体(AnimatedSprite2D) |
| 单位测试 | scenes/units/unit_movement_test.tscn | 移动动画交互测试 |

---

## 7. 数据文件（data/）

| 文件 | 大小 | 内容 | 主要消费者 |
|------|------|------|------------|
| balance_params.json | 28KB | 战斗/资源/士气/移动平衡参数 | combat_resolver, tactical_skirmish_manager, game_manager |
| buildings.json | 26KB | 建筑定义（经济/军事，最多3级） | city_manager |
| cities.json | 14KB | 50城坐标/人口/阵营/发展度 | city_manager, data_manager |
| diplomacy.json | 7KB | 外交参数：礼物/行动效果 | diplomacy_system |
| events.json | 99KB | 88个随机事件（8类别） | event_manager |
| factions.json | 4KB | 七国定义：AI性格/颜色/学派 | game_manager, diplomacy_ai |
| ministers.json | 16KB | 大夫模板（文武外交三类） | (阶段4待实现) |
| schools.json | 22KB | 六大学派定义与效果 | (阶段3待实现) |
| tech_tree.json | 85KB | 54科技树（军事/经济×3时代） | tech_system |
| tech_events.json | 8KB | 科技触发事件 | event_manager |
| tech_synergies.json | 6KB | 科技协同组合 | tech_system |
| terrain.json | 7KB | 11种地形 | data_manager, combat_resolver |
| units.json | 14KB | 19种兵种（含国家变体） | data_manager, combat_resolver |
| wonders.json | 8KB | 奇观建筑 | city_manager |
| tactical_skirmish_mvp.json | 1KB | MVP演武地图 | tactical_skirmish_manager |
| skirmish_scenarios.json | 14KB | 7个演武场景 | tactical_skirmish_manager |
| big_map_terrain.json | 6KB | 大地图30×20地形网格 | big_map_panel |

---

## 8. 设计文档（docs/）

| 目录 | 文件数 | 内容 |
|------|--------|------|
| docs/ | 7 | 策划案、技术栈、接口文档、六角规范、美术策划、动画指南 |
| docs/机制概览/ | 15 | 完整游戏机制设计（战斗/城市/外交/大夫/季节/学派/情报/文化/民心/科技/粮食/经营/事件/地理） |
| docs/策划决策/ | 23 | 各阶段决策记录（阶段0~6 + 重制决策） |
| docs/美术进度/ | 5 | 美术交付清单 |
| docs/程序进度/ | 2 | 已实现功能清单（主分支+战斗分支） |
| docs/测试指南/ | 1 | 演武场景测试指南 |
