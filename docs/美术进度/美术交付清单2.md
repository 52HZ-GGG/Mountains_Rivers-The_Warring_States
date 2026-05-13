# 第九章 启动流程与 UI 动画 — 程序交付说明

> **交付日期**：2026-05-12
> **对应策划案**：美术策划案 第九章（9.1~9.10）
> **交付人**：美术

---

## 一、交付物总览

### 1.1 素材生成脚本（`tools/`）

在 Godot 编辑器中执行：工具 → 运行脚本，即可生成对应 PNG 到 `assets/` 目录。

| 脚本 | 生成内容 | 输出路径 |
|:---|:---|:---|
| `generate_app_icon.gd` | App 图标 1024×1024 | `assets/ui/icon_app_1024.png` |
| `generate_splash_assets.gd` | Splash Logo + 标题 + 毛笔遮罩 | `assets/ui/splash/` |
| `generate_announcement_assets.gd` | 公告竹简背景 + 印章 | `assets/ui/panels/` |
| `generate_loading_assets.gd` | 六角旋转框 + 4 武器图标 | `assets/ui/icons/` |
| `generate_faction_select_assets.gd` | 势力卡片 ×7 + 选中框 + 背景 | `assets/ui/panels/` |
| `generate_unit_selection_assets.gd` | 单位阴影 + 3 种六角高亮 | `assets/ui/highlights/` |
| `generate_mode_select_assets.gd` | 模式卡片 + 选中框 + 4 模式图标 | `assets/ui/panels/` |

> **注意**：素材生成脚本产出的是程序化像素占位图。美术后续可替换为手绘终稿，文件名和路径不变即可。

### 1.2 Shader

| 文件 | 用途 | 参数 |
|:---|:---|:---|
| `assets/shaders/splash_brush_reveal.gdshader` | Splash 毛笔写字揭露效果 | `frame`(0~35)、`glow_intensity`(0~1) |

### 1.3 场景 + 脚本

| 场景文件 | 脚本文件 | 功能 |
|:---|:---|:---|
| `scenes/ui/splash/splash_screen.tscn` | `splash_screen.gd` | Splash 进入动画（4.5s） |
| `scenes/ui/splash/announcement_popup.tscn` | `announcement_popup.gd` | 公告弹窗（卷轴展开/收起） |
| `scenes/ui/splash/loading_screen.tscn` | `loading_screen.gd` | 加载动画（六角旋转 + 打字机） |
| `scenes/ui/splash/faction_select.tscn` | `faction_select.gd` | 七国势力选择界面 |
| `scenes/ui/splash/mode_select.tscn` | `mode_select.gd` | 游戏模式选择（4 种模式） |
| `scenes/ui/buff/buff_panel.tscn` | `buff_panel.gd` | Buff/Debuff 详情面板 |

### 1.4 启动流程管理器

| 文件 | 说明 |
|:---|:---|
| `scripts/autoload/startup_flow.gd` | 已注册为 autoload，管理场景切换链 |

---

## 二、启动流程

### 2.1 流程图

```
App 启动
  │
  ├─ SplashScreen（4.5s，点击可跳过）
  │    └─ 结束 → StartupFlow.on_splash_finished()
  │
  ├─ ModeSelect（选择模式）
  │    └─ 确认 → StartupFlow.on_mode_selected(mode_id)
  │
  ├─ FactionSelect（选择势力）
  │    └─ 确认 → StartupFlow.on_faction_selected(faction_id)
  │
  ├─ LoadingScreen（加载动画）
  │    └─ 完成 → StartupFlow.on_loading_finished()
  │
  └─ MainScene（游戏主场景）
       └─ GameManager.start_game() 已由 StartupFlow 调用
```

### 2.2 启用方式

**方式一：设为启动场景（推荐测试）**

修改 `project.godot`：
```ini
run/main_scene="res://scenes/ui/splash/splash_screen.tscn"
```

**方式二：代码触发**

```gdscript
# 在任意位置调用
StartupFlow.start_full_flow()    # 完整流程
StartupFlow.skip_splash = true   # 跳过 Splash（调试）
```

**方式三：快速开始（跳过全部 UI，直接进游戏）**

```gdscript
StartupFlow.quick_start("qin")   # 直接以秦国开始
```

### 2.3 模式对势力的影响

| 模式 | 激活势力 | 回合数 |
|:---|:---|:---|
| 经典（征战天下） | 全部 7 国 | ~30 |
| 快速（逐鹿中原） | 秦、赵、齐 | ~15 |
| 剧情（合纵连横） | 全部 7 国 | ~20 |
| 沙盒（自定义） | 全部 7 国（后续可配置） | 无限 |

---

## 三、API 接口

### 3.1 StartupFlow（autoload）

```gdscript
# 信号
signal flow_changed(step: String)  # "splash" / "mode_select" / "faction_select" / "loading" / "game"

# 属性
var selected_mode: String      # "classic" / "quick" / "story" / "sandbox"
var selected_faction: String   # "qin" / "zhao" / ...
var skip_splash: bool          # 调试用，跳过 Splash

# 方法
func start_full_flow() -> void
func quick_start(faction_id: String, mode: String = "classic") -> void
func goto_splash() -> void
func goto_mode_select() -> void
func goto_faction_select() -> void
func goto_loading() -> void
func goto_game() -> void
```

### 3.2 AnnouncementPopup（实例化使用）

```gdscript
var popup = preload("res://scenes/ui/splash/announcement_popup.tscn").instantiate()
add_child(popup)
popup.show_announcement("标题", "正文内容")
popup.announced.connect(func(): print("公告已关闭"))
```

### 3.3 BuffPanel（实例化使用）

```gdscript
var panel = preload("res://scenes/ui/buff/buff_panel.tscn").instantiate()
add_child(panel)
panel.show_buffs([
    {"name": "攻击强化", "type": "buff", "icon": "attack_up",
     "effect": "攻击力 +20%", "duration": 3, "source": "兵家学派加成", "desc": "兵贵神速，攻势如潮"},
    {"name": "灼烧", "type": "debuff", "icon": "fire",
     "effect": "每回合 -5% 生命", "duration": 2, "source": "火攻", "desc": "烈焰焚身"},
])
panel.buff_selected.connect(func(data): print(data["name"]))
panel.panel_closed.connect(func(): print("面板关闭"))
```

---

## 四、已知限制 & 后续事项

| 项目 | 现状 | 后续 |
|:---|:---|:---|
| 素材 | 程序化像素占位图 | 美术替换为手绘终稿，同路径覆盖即可 |
| 音频 | 未包含（9.8 音效方案仅规范） | 需音效人员制作 22 个 `.ogg` 文件 |
| Buff 图标 | `icon_buff/debuff_*.png` 未生成 | 需按实际 Buff 类型补充 |
| 毛笔字 Shader | `frame` 参数需手动递增 | 已由 AnimationPlayer 自动驱动 |
| main.tscn | 默认 `run/main_scene` 仍指向 main.tscn | 测试完整流程时改为 splash_screen.tscn |
| 公告数据 | 公告内容硬编码在调用方 | 后续可接 `data/announcements.json` |

---

## 五、文件清单

```
新增文件（共 20 个）：

tools/
  generate_app_icon.gd
  generate_splash_assets.gd
  generate_announcement_assets.gd
  generate_loading_assets.gd
  generate_faction_select_assets.gd
  generate_unit_selection_assets.gd
  generate_mode_select_assets.gd

assets/shaders/
  splash_brush_reveal.gdshader

scenes/ui/splash/
  splash_screen.tscn + .gd
  announcement_popup.tscn + .gd
  loading_screen.tscn + .gd
  faction_select.tscn + .gd
  mode_select.tscn + .gd

scenes/ui/buff/
  buff_panel.tscn + .gd

scripts/autoload/
  startup_flow.gd

修改文件（2 个）：
  project.godot          — 新增 StartupFlow autoload
  scenes/main/main.gd    — _init_game() 增加重复初始化检查
```
