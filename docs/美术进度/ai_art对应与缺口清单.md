# ai_art ↔ 程序调用对应 + 缺口清单

> 仓库：`shanhece-clean`；策略：**优先 `assets/ai_art/**`，没有再用旧 `assets/**`**
> 代码：`art_catalog.gd`（解析）+ `skirmish_tile_textures.gd`（调用入口，已改为 ai_art 优先）

## 1. 对应表

| 用途 | 优先 | 回退 |
|---|---|---|
| 地形 | `ai_art/terrain/tile_*_01` + 平原季节 | `assets/terrain`（变体 02/03 仍旧图） |
| 城市 | `ai_art/cities/tile_city_*` | `assets/tiles` 首都 |
| 兵种 | `ai_art/units/{id}_idle.png` | `assets/units/portraits` |
| 事件 | `ai_art/events/event_*` | `assets/events` |
| 面板/图标/高亮/按钮 | `ai_art/ui/**` | `assets/ui/**` |
| 旗帜/建筑图标 | `ai_art/ui/icons/flag_*` `building_*` | 旧 icon_building_* |

## 2. 兵种 idle 映射结果

| unit_id | 文件 | 状态 |
|---|---|---|
| militia | `militia_idle.png` | ✅ |
| infantry | `infantry_idle.png` | ✅ |
| spear | `spear_idle.png` | ✅ |
| scout_team | `scout_team_idle.png` | ✅ |
| iron_armored | `iron_armored_idle.png` | ✅ |
| scout_cavalry | `scout_cavalry_idle.png` | ✅ |
| cavalry | `cavalry_idle.png` | ✅ |
| shock_cavalry | `shock_cavalry_idle.png` | ✅ |
| heavy_cavalry | `heavy_cavalry_idle.png` | ✅ |
| chariot | `chariot_idle.png` | ✅ |
| archer | `archer_idle.png` | ✅ |
| crossbow | `crossbow_idle.png` | ✅ |
| horse_archer | `horse_archer_idle.png` | ✅ |
| battering_ram | `battering_ram_idle.png` | ✅ |
| catapult | `catapult_idle.png` | ✅ |
| ballista | `ballista_idle.png` | ✅ |
| mengchong | `mengchong_idle.png` | ✅ |
| great_wing | `great_wing_idle.png` | ✅ |
| tower_ship | `tower_ship_idle.png` | ✅ |
| rushi | `qin_ruishix_idle.png` | ✅ |
| jijishou | `qi_jiji_idle.png` | ✅ |
| hufu_qibing | `zhao_bianqi_idle.png` | ✅ |
| wuzu | `wei_wuzu_idle.png` | ✅ |
| shenxi_zhishi | `chu_manjia_idle.png` | ✅ |
| jinnu | `han_nushou_idle.png` | ✅ |
| liaodong_gongqi | `yan_sishi_idle.png` | ✅ |

## 3. ai_art 还缺什么

### 3.1 兵种动画（优先）

- 步兵攻击序列：`units/infantry_attack/frame_*.png` → **20 帧**（若 0 则未入库）
- **其余兵种均无 attack/move/death 序列**，需按 units.json 全量补齐：
  - `militia`：idle 循环 / attack / move / death（透明底 256~512）
  - `infantry`：idle 循环 / attack / move / death（透明底 256~512）
  - `spear`：idle 循环 / attack / move / death（透明底 256~512）
  - `scout_team`：idle 循环 / attack / move / death（透明底 256~512）
  - `iron_armored`：idle 循环 / attack / move / death（透明底 256~512）
  - `scout_cavalry`：idle 循环 / attack / move / death（透明底 256~512）
  - `cavalry`：idle 循环 / attack / move / death（透明底 256~512）
  - `shock_cavalry`：idle 循环 / attack / move / death（透明底 256~512）
  - `heavy_cavalry`：idle 循环 / attack / move / death（透明底 256~512）
  - `chariot`：idle 循环 / attack / move / death（透明底 256~512）
  - `archer`：idle 循环 / attack / move / death（透明底 256~512）
  - `crossbow`：idle 循环 / attack / move / death（透明底 256~512）
  - `horse_archer`：idle 循环 / attack / move / death（透明底 256~512）
  - `battering_ram`：idle 循环 / attack / move / death（透明底 256~512）
  - `catapult`：idle 循环 / attack / move / death（透明底 256~512）
  - `ballista`：idle 循环 / attack / move / death（透明底 256~512）
  - `mengchong`：idle 循环 / attack / move / death（透明底 256~512）
  - `great_wing`：idle 循环 / attack / move / death（透明底 256~512）
  - `tower_ship`：idle 循环 / attack / move / death（透明底 256~512）
  - `rushi`：idle 循环 / attack / move / death（透明底 256~512）
  - `jijishou`：idle 循环 / attack / move / death（透明底 256~512）
  - `hufu_qibing`：idle 循环 / attack / move / death（透明底 256~512）
  - `wuzu`：idle 循环 / attack / move / death（透明底 256~512）
  - `shenxi_zhishi`：idle 循环 / attack / move / death（透明底 256~512）
  - `jinnu`：idle 循环 / attack / move / death（透明底 256~512）
  - `liaodong_gongqi`：idle 循环 / attack / move / death（透明底 256~512）
- 源视频仅：`qin_ruishi_attack_greenscreen.mp4`、`infantry_attack_video.mp4`
- 抽帧工具：`tools/unit_chroma_pipeline.py`（ffmpeg）

### 3.2 地形

- ai_art 只有各地形 **01** + 平原 spring/autumn/winter
- 代码多变体（forest_02 等）缺 ai_art 版，现走旧路径
- overlay 有 river_belt/pass/ford，**大地图格边界绘制未接**

### 3.3 UI / 建筑 / 音频

- 资源 12 图标：齐（工匠文件为 `icon_craftsman.png`）
- 建筑：ai_art 为 UI 图标 `ui/icons/building_*`；大地图 `assets/buildings/tile_building_*` 仍可能缺
- victory/defeat/new_game/unit_info 等仍可能回退旧面板
- 音频清单有 sfx/battle BGM，以仓库实际 wav 为准接入



---

## 附录：2026-09-19 音频 + UI 场景绑定

| 项 | 状态 |
|---|---|
| ArtAudio autoload | ✅ `scripts/ui/art_audio.gd`（BGM/SFX 池；文件缺失静默） |
| 音频路径 | 预期 `assets/audio/bgm/main_theme.wav`、`battle_theme.wav`；`assets/audio/sfx/*.wav` |
| UI 皮肤 | `ArtUiSkin.apply_full_skin` → 外交/科技/事件/城表面板 |
| 按钮音效 | 主界面与面板按钮 `ui_click` |
| 回合/事件 | `turn_started`→turn_start；事件弹窗→event_popup；game_over→event_popup |
| 地图建筑/资源 | `map_buildings/map_*` + `resource_*` 已接 building_texture / 特产格 |
| 面板 | victory/defeat/new_game/unit_info/tech/diplomacy/school/save |

**Godot 验收**：Import 后打开外交/科技/城池；点按钮听 ui_click（若 wav 已入库）。

**音频若仓库尚无 wav**：把清单文件放到 `assets/audio/bgm|sfx/` 即可，无需再改代码。

**兵种动画**：仍待 ffmpeg 抽帧 → `assets/units/frames/` 或 `ai_art/units/*_attack/`。

