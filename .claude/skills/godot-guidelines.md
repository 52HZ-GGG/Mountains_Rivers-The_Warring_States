# 山河策 Godot 4.3 架构与编码规范

## 引擎与语言
- 引擎：Godot 4.3+ 标准版
- 主力语言：GDScript（**必须**使用静态类型标注 `var health: int = 100`）
- 备选：C#（仅在性能分析确认瓶颈后使用，如大地图寻路、文化扩散）
- 扩展：GDExtension（C++/Rust）（Phase 5 优化，非初始决策）

## 项目目录结构
```
data/                        # JSON 数据文件（units/terrain/tech_tree/events/buildings/factions/diplomacy）
scenes/                      # Godot 场景文件 (.tscn)
  main/                      # 主场景、菜单
  map/                       # TileMap、摄像机
  units/                     # 单位场景
  cities/                    # 城市场景
  ui/                        # UI 面板场景
    hud/                     # 资源栏、回合指示器
    city_panel/              # 城市管理面板
    diplomacy/               # 外交对话框
    tech_tree/               # 科技树视图
    events/                  # 事件弹窗
scripts/                     # GDScript 脚本
  autoload/                  # 全局单例管理器（game_manager/data_manager/event_manager/signal_bus）
  map/                       # 地图相关脚本
  units/                     # 单位行为
  cities/                    # 城市逻辑
  ai/                        # AI 决策（diplomacy_ai/military_ai/economy_ai）
  systems/                   # 游戏系统（combat_system/culture_system/tech_system/diplomacy_system）
assets/                      # 美术和音频资源
  sprites/                   # 像素美术
  tilesets/                  # TileSet 资源
  audio/bgm/                 # 背景音乐
  audio/sfx/                 # 音效
  fonts/                     # 字体文件
  themes/                    # Godot Theme 资源
```

## 全局单例 (Autoload)
- `GameManager`：回合循环、游戏状态
- `DataManager`：加载 `data/*.json` 并提供数据访问
- `EventManager`：随机事件调度
- `SignalBus`：信号总线，系统间解耦通信

## 信号驱动架构
- 回合结束信号链：GameManager.end_turn() → 发射 turn_ending → 各系统处理 → 发射 turn_started → UI 更新
- 系统间严禁直接调用方法，必须通过 SignalBus 发射信号并连接

## 地图与寻路
- 网格：六角网格，使用轴坐标 (q, r)
- 渲染：TileMapLayer 分层（地形底、覆盖、单位、文化）
- 寻路：AStarGrid2D（内置，支持六角模式），自定义权重函数基于地形消耗
- 补给线检测：BFS/泛洪填充

## UI 技术栈
- 全部使用 Godot Control 节点（PanelContainer, VBoxContainer, ScrollContainer 等）
- 主题：项目级 Theme 资源，统一管理字体、颜色、按钮样式
- 科技树：自定义 Control + `_draw()` 或 GraphEdit

## 数据驱动铁律
- 程序严禁硬编码任何游戏数值、国家 ID、学派 ID
- 所有数值必须通过 `DataManager.get_xxx()` 从 JSON 获取
- 兵种属性字段：id, name, attack, defense, speed, range, special
- 地形字段：id, name, move_cost, effects
- 引擎原生数据（Theme、TileSet 配置、自定义 Resource 子类）使用 `.tres`（Godot Resource）格式

## 版本控制与构建
- Git 托管于 GitHub，二进制资产（PNG、音频、字体）使用 **Git LFS** 管理
- 分支策略：`main`（始终可运行）→ `dev`（开发集成）→ `feature/*`（功能分支）
- 可选 CI/CD：GitHub Actions 自动构建、运行测试、生成可下载构建

## 性能注意
- 文化扩散、AI 计算等 CPU 密集逻辑需使用 `call_deferred` 或分帧处理
- 超过 100 城市时，文化算法优化为仅计算邻城或分批

## 测试
- GUT 单元测试针对：战斗公式、寻路、文化传播、AI 决策、存档读写
