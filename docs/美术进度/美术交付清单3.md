# P1 + P2 战斗系统 UI 素材 — 程序交付说明

> **交付日期**：2026-05-13
> **对应需求**：战斗系统美术缺口分析
> **交付人**：美术

---

## 一、交付物总览

| 优先级 | 脚本 | 生成内容 | 输出路径 |
|:---|:---|:---|:---|
| P1 | `generate_battle_ui_assets.gd` | 士气图标 ×4 + Buff/Debuff 图标 ×7 + 单位血条 + 城市血条 | `assets/ui/icons/` + `assets/ui/bars/` |
| P2 | `generate_battle_p2_assets.gd` | 伤害数字 + 特殊攻击图标 + 地形叠加 + 单位状态 + 射程高亮 + 面板背景 | 多目录 |

在 Godot 编辑器中执行：工具 → 运行脚本，即可生成对应 PNG。

---

## 二、P1 素材清单

### 2.1 士气状态图标（48×48 圆形图标）

| 文件名 | 对应状态 | 阈值 | 用途 |
|:---|:---|:---|:---|
| `ui_morale_high.png` | 高士气 | ≥ 130 | 攻击力 +10% |
| `ui_morale_normal.png` | 正常 | 50~129 | 无修正 |
| `ui_morale_low.png` | 低士气 | 20~49 | 攻击力 -10% |
| `ui_morale_broken.png` | 崩溃 | < 20 | 攻防 ×0.5，每回合 -20% HP |

### 2.2 Buff/Debuff 图标（40×40 菱形图标）

| 文件名 | 类型 | 效果来源 |
|:---|:---|:---|
| `ui_buff_atk.png` | Buff | 攻击增益（大夫勇武、兵种特技等） |
| `ui_buff_def.png` | Buff | 防御增益（城墙、墨家学派等） |
| `ui_buff_speed.png` | Buff | 移动增益 |
| `ui_debuff_fire.png` | Debuff | 火攻（+40% atk，持续 2 回合） |
| `ui_debuff_poison.png` | Debuff | 中毒（持续伤害） |
| `ui_debuff_freeze.png` | Debuff | 冻土减速 |
| `ui_debuff_chaos.png` | Debuff | 混乱（崩溃态相关） |

### 2.3 单位血条（64×10，地图上叠加显示）

| 文件名 | 说明 |
|:---|:---|
| `ui_hp_bar_bg.png` | 血条背景（暗色圆角矩形） |
| `ui_hp_bar_fill.png` | 血条填充（绿色渐变，运行时裁剪长度） |
| `ui_hp_bar_frame.png` | 血条边框（金色细边） |

### 2.4 城市/关隘血条（128×14，城防 UI 使用）

| 文件名 | 说明 |
|:---|:---|
| `ui_city_hp_bg.png` | 城市血条背景 |
| `ui_city_hp_fill.png` | 城市血条填充（绿→黄→红渐变） |
| `ui_city_hp_frame.png` | 城市血条边框 |

### 2.5 程序使用说明

```gdscript
# 士气图标：根据 morale 值选择对应图标
var morale_icon: String
if morale >= 130:     morale_icon = "res://assets/ui/icons/ui_morale_high.png"
elif morale >= 50:    morale_icon = "res://assets/ui/icons/ui_morale_normal.png"
elif morale >= 20:    morale_icon = "res://assets/ui/icons/ui_morale_low.png"
else:                 morale_icon = "res://assets/ui/icons/ui_morale_broken.png"

# Buff 图标：buff_data["icon"] 对应文件名中的类型字段
# 例：{"icon": "atk"} → "res://assets/ui/icons/ui_buff_atk.png"
# 例：{"icon": "fire"} → "res://assets/ui/icons/ui_debuff_fire.png"

# 单位血条：TextureRect 组合
# bg → fill（裁剪 width = max_width × hp_ratio）→ frame
```

---

## 三、P2 素材清单（共 ~40 个文件）

### 3.1 战斗结果指示器

| 文件名 | 尺寸 | 说明 |
|:---|:---|:---|
| `ui_dmg_num_0.png` ~ `ui_dmg_num_9.png` | 12×16 | 浮动伤害数字精灵（5×7 像素字体） |
| `ui_dmg_num_miss.png` | 24×16 | 闪避文字精灵 |
| `ui_icon_counter.png` | 16×16 | 反击指示（双剑交叉） |
| `ui_icon_deflect.png` | 16×16 | 格挡/最低伤害指示（盾牌） |

### 3.2 特殊攻击指示器

| 文件名 | 尺寸 | 说明 |
|:---|:---|:---|
| `ui_icon_flank.png` | 32×32 | 夹击指示（双箭头钳形） |
| `ui_icon_fire_atk.png` | 32×32 | 火攻可用指示（火焰剑） |
| `ui_icon_burn_dot.png` | 16×16 | 灼烧持续伤害指示 |
| `ui_icon_ambush.png` | 32×32 | 伏击触发指示（惊叹号+灌木） |

### 3.3 地形/天气叠加层

| 文件名 | 尺寸 | 说明 |
|:---|:---|:---|
| `ui_icon_terrain_atk.png` | 16×16 | 地形攻击修正（红剑） |
| `ui_icon_terrain_def.png` | 16×16 | 地形防御修正（蓝盾） |
| `ui_icon_elev_0.png` | 16×16 | 海拔 0（平地） |
| `ui_icon_elev_1.png` | 16×16 | 海拔 1（丘陵） |
| `ui_icon_elev_2.png` | 16×16 | 海拔 2（山脉） |
| `ui_overlay_river_frozen.png` | 32×32 | 河流冻结叠加（冰晶纹理） |
| `ui_icon_season_spring.png` | 32×32 | 春季图标 |
| `ui_icon_season_summer.png` | 32×32 | 夏季图标 |
| `ui_icon_season_autumn.png` | 32×32 | 秋季图标 |
| `ui_icon_season_winter.png` | 32×32 | 冬季图标 |

### 3.4 单位状态指示

| 文件名 | 尺寸 | 说明 |
|:---|:---|:---|
| `ui_icon_supply_ok.png` | 24×24 | 补给正常（绿色锁链） |
| `ui_icon_supply_cut.png` | 24×24 | 补给切断（断裂红色锁链） |
| `ui_bar_momentum_bg.png` | 40×8 | 动量条背景 |
| `ui_bar_momentum_fill.png` | 40×8 | 动量条填充（灰→金渐变，5 段） |
| `ui_bar_wall_bg.png` | 128×8 | 城墙血条背景 |
| `ui_bar_wall_fill.png` | 128×8 | 城墙血条填充（石灰色） |
| `ui_overlay_stranded.png` | 32×32 | 搁浅叠加（碎冰纹理） |

### 3.5 射程可视化

| 文件名 | 尺寸 | 说明 |
|:---|:---|:---|
| `ui_highlight_range_reduced.png` | 32×32 | 射程衰减六角（暗橙半透明） |
| `ui_highlight_counter.png` | 32×32 | 反击预览六角（蓝色半透明） |
| `ui_highlight_flank_preview.png` | 32×32 | 夹击预览六角（红色半透明） |

### 3.6 战斗 UI 面板

| 文件名 | 尺寸 | 说明 |
|:---|:---|:---|
| `ui_battle_panel_bg.png` | 200×120 | 战斗预览面板背景（暗底金边） |
| `ui_combat_log_bg.png` | 300×60 | 战斗日志横幅背景 |
| `ui_troop_badge_bg.png` | 24×14 | 兵力数字徽章背景 |

---

## 四、命名规范

所有文件遵循 `^(tile|unit|ui)_[a-z]+(_[a-z0-9]+)*\.png$` 规范，可通过 pre-push 检查。

## 五、文件清单

```
新增文件（2 个）：
  tools/generate_battle_ui_assets.gd    — P1 素材生成
  tools/generate_battle_p2_assets.gd    — P2 素材生成

输出目录（部分新建）：
  assets/ui/icons/      — 图标（士气、Buff、Debuff、特殊攻击、地形、季节等）
  assets/ui/bars/       — 血条组件（单位血条、城市血条、动量条、城墙血条）
  assets/ui/overlays/   — 叠加层（河流冻结、搁浅）
  assets/ui/highlights/ — 六角高亮（射程衰减、反击预览、夹击预览）
  assets/ui/panels/     — 面板背景（战斗预览、战斗日志、兵力徽章）
```
