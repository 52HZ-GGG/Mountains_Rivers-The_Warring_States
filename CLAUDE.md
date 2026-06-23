# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

## 项目特定要求（《山河策》）

- **回复语言**：中文（commit message、注释、文档同此）
- **引擎**：Godot 4.3+，主力语言 GDScript
- **类型标注**：GDScript 必须使用静态类型（如 `var hp: int = 100`）
- **数据驱动铁律**：所有平衡数值必须从 `data/*.json` 读取，**统一 JSON 格式，禁止 CSV**
  - ✅ `attack += DataManager.get_faction_bonus(faction_id, "attack")`
  - ❌ `if faction == "Qin": attack += 20`
- **Schema 冻结**：阶段 0 末锁定的 JSON 字段名只许加不许改
- **测试**：核心系统（寻路、战斗公式、文化扩散、AI 决策、存档读写）必须有 GUT 单元测试
- **main 分支纪律**：始终保持可在 Godot 编辑器中正常启动
- **占位资源**：阶段 0~1 美术不足时使用 Kenney.nl 等 CC0 素材库占位，禁止下场画终稿
- **回答规范**:不准擅自下决策，除非指定全权完成，否则有任何问题必须向我提问

## 项目知识与工具（配置维护）
- 游戏设计知识：见 `.claude/skills/shanhece-world.md`
- 技术架构规范：见 `.claude/skills/godot-guidelines.md`
- 美术资产管线：见 `.claude/skills/art-pipeline.md`
- 数值平衡调整流程：见 `.claude/skills/balance-workflow.md`（**核心原则：机制以 docs/机制概览/ 为准，不以程序实现为准**）
- 自定义命令：`.claude/commands/` 下的 `/balance`、`/event`、`/audit`、`/tilegen`、`/save`
- MCP 服务器配置：见 `.claude/mcp.json.template`（首次使用需复制为 `.claude/mcp.json` 后再按本地环境调整；`mcp.json` 已被 `.gitignore` 排除）
- 决策记录：见 `docs/`下文档
- 游戏机制总览：见`docs/机制概览/`文件夹下内容

---

## 项目文件索引

### Autoload 单例（`scripts/autoload/`）

| 文件 | 职责 |
|------|------|
| `signal_bus.gd` | 全局信号总线，解耦系统间通信（回合/事件/外交/战斗/科技/城池信号） |
| `data_manager.gd` | 启动时加载所有 `data/*.json`，提供只读索引访问（地形/单位/城池/事件/建筑/势力/科技） |
| `startup_flow.gd` | 启动流程管理：Splash → 公告 → 模式选择 → 势力选择 → 加载 → 游戏场景切换 |
| `event_manager.gd` | 三阶段事件管线：连锁事件、季节事件、池竞争；管理冷却和条件触发 |
| `game_manager.gd` | 主游戏循环控制器；状态机（GAME_INIT→TURN_START→ACTION→TURN_END→GAME_OVER）；回合循环/势力顺序/玩家资源/胜利条件 |
| `city_manager.gd` | 50城运行时状态管理；建筑建造/升级/拆除、所有权变更、迁都、灭国检查 |
| `diplomacy_system.gd` | 外交系统：好感度/声望/条约/战争/附庸/商路/军事通行；每回合衰减和过期 |
| `tactical_skirmish_manager.gd` | 战术演武管理器：六角格移动/战斗结算/攻城/关隘城墙耐久；数据驱动自 `tactical_skirmish_mvp.json` |

### 游戏系统（`scripts/systems/`）

| 文件 | 职责 |
|------|------|
| `hex_axial.gd` | 六角格工具类 `HexAxial`：轴向/偏移坐标转换、邻居查找、距离计算、像素定位 |
| `combat_resolver.gd` | 纯函数战斗伤害计算器：攻防加法层、兵种克制、士气偏移、随机方差、溃散乘数 |
| `tech_system.gd` | 科技研究系统：54项科技的前置条件/研究成本/效果修正（攻防资源移动力士气等） |
| `unit_movement_manager.gd` | 单位移动管理器：处理六角格移动请求队列、验证边界、动画驱动 |
| `skirmish_ai.gd` | AI 战术回合执行器：灼烧DOT/补给效果/士气恢复/敌方单位决策 |
| `skirmish_attack_pipeline.gd` | 攻击管线：玩家攻击执行/城墙攻击/攻击预览计算；火攻逻辑 |

### AI（`scripts/ai/`）

| 文件 | 职责 |
|------|------|
| `diplomacy_ai.gd` | AI 外交决策系统 `DiplomacyAI`：概率驱动的战争评估/停战/结盟/合纵/脱附；性格加权 |

### 单位脚本（`scripts/units/`）

| 文件 | 职责 |
|------|------|
| `unit.gd` | 单位场景控制器 `Unit`：Node2D + 动画精灵、六角格位置、移动插值、动画状态机（IDLE/MOVE/ATTACK/HURT/DEATH） |

### UI 脚本（`scripts/ui/`）

| 文件 | 职责 |
|------|------|
| `shader_helpers.gd` | Shader 材质工厂 `ShaderHelpers`：势力/学派颜色常量、文化覆盖和羊皮纸面板材质创建 |
| `skirmish_hex_map_canvas.gd` | 六角地图画布渲染器 `HexMapCanvas`：单次 `_draw()` 绘制所有地形瓦片，避免接缝 |
| `skirmish_tile_textures.gd` | 纹理路径注册表和缓存 `SkirmishTileTextures`：地形/都城/事件插图/单位/特效精灵路径 |
| `skirmish_hex_cell.gd` | 单六角格控件 `SkirmishHexCell`：平顶六角形绘制/地形纹理映射/色调叠加/点击检测 |

### 场景脚本（`scenes/`）

| 文件 | 职责 |
|------|------|
| `scenes/main/main.gd` | 主场景根节点：连接 UI 按钮（外交/科技/演武/大地图/事件）到游戏系统；初始化7势力 |
| `scenes/ui/splash/splash_screen.gd` | 动画启动画面：Logo 淡入淡出，点击跳过 |
| `scenes/ui/splash/mode_select.gd` | 游戏模式选择：4模式（经典/快速/剧情/沙盒）卡片式 UI |
| `scenes/ui/splash/faction_select.gd` | 势力选择：7战国势力，含立绘/描述/特色兵种/加成 |
| `scenes/ui/splash/loading_screen.gd` | 加载画面：旋转六角框/武器图标轮播/打字机提示文字 |
| `scenes/ui/splash/announcement_popup.gd` | 卷轴式公告弹窗：开合动画+落印 |
| `scenes/ui/resource_bar/resource_bar.gd` | 顶部资源栏：显示10种玩家资源（粮/金/木/马/精铁/匠人/建材/兵/人口/士气）；回合开始自动刷新 |
| `scenes/ui/city_panel/city_panel.gd` | 城池管理面板：城池信息/建筑/建造队列/可建造项+图标映射 |
| `scenes/ui/diplomacy/diplomacy_panel.gd` | 外交面板：势力列表+声望好感显示/操作按钮 |
| `scenes/ui/diplomacy/negotiation_dialog.gd` | 停战谈判对话框：赔款输入/城池选择/附庸复选框；3轮谈判历史 |
| `scenes/ui/event_popup/event_popup.gd` | 事件弹窗：显示事件插图/描述/玩家选项；监听 `SignalBus.event_triggered` |
| `scenes/ui/tech/tech_tree_panel.gd` | 科技树面板：54项科技，3列（早/中/晚期）×4行（军事/经济/文化/建筑）；点击研究 |
| `scenes/ui/big_map/big_map_panel.gd` | 大地图面板：30×20六角格地图显示50城+势力着色；缩放/政治模式切换/城池点击信号 |
| `scenes/ui/buff/buff_panel.gd` | Buff/Debuff 信息面板：显示激活效果+图标/持续时间/来源/描述 |
| `scenes/ui/skirmish/skirmish_scenario_panel.gd` | 演武场景选择器：从 `skirmish_scenarios.json` 列出场景/季节选择/开始按钮 |
| `scenes/ui/skirmish/skirmish_mvp_panel.gd` | 战术演武主 UI：六角格面板渲染/单位选择移动攻击/悬停信息/战斗特效/回合管理 |

### 数据文件（`data/`）

| 文件 | 内容 |
|------|------|
| `terrain.json` | 11种地形类型：移动力消耗/防御/攻击修正 |
| `units.json` | 19种兵种：攻/防/HP/移动力/射程/成本 |
| `cities.json` | 50城（7国×约7+3中立）：坐标/辖区/建筑 |
| `factions.json` | 7势力定义：AI性格/加成/特色兵种 |
| `buildings.json` | 建筑定义：成本/效果/前置条件/国家限制 |
| `events.json` | 随机事件：条件/选项/效果/冷却 |
| `diplomacy.json` | 外交参数：难度设置/拆除返还比/AI决策阈值 |
| `tech_tree.json` | 54项科技树：前置条件/研究成本/效果 |
| `tech_events.json` | 科技触发事件 |
| `tech_synergies.json` | 科技联动加成 |
| `ministers.json` | 官员定义：属性和能力 |
| `schools.json` | 诸子百家定义（儒/法/墨/道等） |
| `wonders.json` | 奇观定义 |
| `balance_params.json` | 全局平衡参数（士气阈值/伤害公式/资源产出率） |
| `big_map_terrain.json` | 30×20大地图六角格地形布局 |
| `tactical_skirmish_mvp.json` | 战术演武 MVP 场景数据（六角格/单位部署） |
| `skirmish_scenarios.json` | 多个演武场景定义 |

### 测试文件（`tests/unit/`）— 22个 GUT 测试

| 文件 | 测试内容 |
|------|----------|
| `test_hex_axial.gd` | 六角格坐标数学：邻居数/距离/像素定位 |
| `test_tactical_skirmish_manager.gd` | 演武管理器：单位生成/可达格/攻击消耗 |
| `test_combat_resolver.gd` | 战斗公式：攻防增益层/士气偏移/伏击火攻加成 |
| `test_data_manager.gd` | 数据加载验证：地形11/兵种19/城池50/ID查询 |
| `test_game_manager.gd` | 游戏状态机：阶段转换/回合循环/势力排序 |
| `test_event_manager.gd` | 事件系统：触发条件/冷却/选项 |
| `test_city_manager.gd` | 城池管理：建造/升级/拆除/所有权 |
| `test_combat_modifiers.gd` | 战斗修正计算 |
| `test_damage_overflow.gd` | 伤害溢出机制 |
| `test_fire_attack.gd` | 火攻系统 |
| `test_flanking.gd` | 侧翼加成计算 |
| `test_healing.gd` | 治疗机制 |
| `test_naval_combat.gd` | 水战规则 |
| `test_pass_combat.gd` | 关隘战斗 |
| `test_ranged_obstruction.gd` | 远程遮挡 |
| `test_retreat.gd` | 撤退机制 |
| `test_supply.gd` | 补给/后勤系统 |
| `test_unit_morale.gd` | 单位士气系统 |
| `test_unit_skills.gd` | 单位特殊技能 |
| `test_zoc.gd` | 控制区（ZoC） |

### 工具脚本（`tools/`）— 12个资产生成脚本

| 文件 | 用途 |
|------|------|
| `generate_unit_sprite_frames.gd` | 从单位精灵 PNG 生成 SpriteFrames .tres |
| `generate_effect_sprite_frames.gd` | 生成战斗特效 SpriteFrames |
| `generate_splash_assets.gd` | 生成启动画面占位资产 |
| `generate_app_icon.gd` | 生成应用图标 |
| `generate_battle_p2_assets.gd` | 生成战斗阶段2资产 |
| `generate_battle_ui_assets.gd` | 生成战斗 UI 占位资产 |
| `generate_city_tiles.gd` | 生成城池瓦片精灵 |
| `generate_faction_select_assets.gd` | 生成势力选择 UI 资产 |
| `generate_loading_assets.gd` | 生成加载画面资产 |
| `generate_mode_select_assets.gd` | 生成模式选择 UI 资产 |
| `generate_unit_selection_assets.gd` | 生成兵种选择资产 |
| `generate_announcement_assets.gd` | 生成公告弹窗资产 |

### 场景文件（`.tscn`）

| 文件 | 用途 |
|------|------|
| `scenes/main/main.tscn` | 主游戏场景（入口点） |
| `scenes/units/unit.tscn` | 单位场景（AnimatedSprite2D） |
| `scenes/ui/splash/splash_screen.tscn` | 启动画面 |
| `scenes/ui/splash/mode_select.tscn` | 模式选择 |
| `scenes/ui/splash/faction_select.tscn` | 势力选择 |
| `scenes/ui/splash/loading_screen.tscn` | 加载画面 |
| `scenes/ui/splash/announcement_popup.tscn` | 公告弹窗 |
| `scenes/ui/resource_bar/resource_bar.tscn` | 资源栏 |
| `scenes/ui/city_panel/city_panel.tscn` | 城池面板 |
| `scenes/ui/diplomacy/diplomacy_panel.tscn` | 外交面板 |
| `scenes/ui/diplomacy/negotiation_dialog.tscn` | 谈判对话框 |
| `scenes/ui/event_popup/event_popup.tscn` | 事件弹窗 |
| `scenes/ui/event_test/event_test_panel.tscn` | 事件测试面板 |
| `scenes/ui/big_map/big_map_panel.tscn` | 大地图面板 |
| `scenes/ui/buff/buff_panel.tscn` | Buff 面板 |
| `scenes/ui/skirmish/skirmish_scenario_panel.tscn` | 演武场景选择 |
| `scenes/ui/skirmish/skirmish_test_guide_panel.tscn` | 演武测试指南 |
| `scenes/ui/skirmish/skirmish_mvp_panel.tscn` | 战术演武 MVP 面板 |

### 美术资产（`assets/`）

| 目录 | 内容 |
|------|------|
| `assets/fonts/` | 字体：STLITI.TTF、pixel_lishu.fnt + 位图、pixel_lishu_dynamic.tres（项目默认字体） |
| `assets/shaders/` | 7个 Shader：文化覆盖/启动笔刷/UI按钮/高亮脉冲/图标发光/羊皮纸/进度条 |
| `assets/sprites/terrain/` | 9种地形瓦片精灵 |
| `assets/sprites/units/` | 17种基础兵种 + 7种势力特色兵种（各含 idle/move/attack/hurt/death 动画帧）+ 16种战斗特效 |
| `assets/ui/` | UI 资产：战斗面板/按钮(10)/高亮(3)/图标(25)/覆盖层/面板(14) |

---

## 快速定位指南

**我要改战斗公式** → `scripts/systems/combat_resolver.gd` + `data/balance_params.json`
**我要改兵种数值** → `data/units.json`
**我要改城池/建筑** → `data/cities.json` + `data/buildings.json` + `scripts/autoload/city_manager.gd`
**我要改外交** → `scripts/autoload/diplomacy_system.gd` + `scripts/ai/diplomacy_ai.gd` + `data/diplomacy.json`
**我要改科技树** → `data/tech_tree.json` + `scripts/systems/tech_system.gd`
**我要改事件** → `data/events.json` + `scripts/autoload/event_manager.gd`
**我要改六角格逻辑** → `scripts/systems/hex_axial.gd`
**我要改单位移动** → `scripts/systems/unit_movement_manager.gd` + `scripts/units/unit.gd`
**我要改演武系统** → `scripts/autoload/tactical_skirmish_manager.gd` + `scripts/systems/skirmish_ai.gd` + `scripts/systems/skirmish_attack_pipeline.gd`
**我要改 UI 面板** → `scenes/ui/` 对应子目录下的 `.gd` + `.tscn`
**我要改启动流程** → `scripts/autoload/startup_flow.gd` + `scenes/ui/splash/`
**我要加新势力** → `data/factions.json` + `data/units.json`（特色兵种）+ `data/cities.json`（势力城池）
**我要调全局平衡** → `data/balance_params.json`（28KB，涵盖士气/伤害/资源等所有平衡参数）