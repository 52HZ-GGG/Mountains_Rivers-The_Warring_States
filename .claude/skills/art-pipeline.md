# 山河策美术资产管线规范

## 基础规格
- 像素图块：32×32 像素
- 调色板：战国低饱和暖色调，限制 32 色以内
- 纹理过滤：Nearest（像素风清晰）

## 地形图块列表
必须产出的基础图块：平原、森林、山地、河流、沼泽、关隘、渡口、栈道、箭楼
（每种至少 1 个基础变体，允许有 2-3 个不同季节或文化染色版本）

## 文件命名规则
- 地形：`tile_[terrain_type]_[variant].png` 例：`tile_mountain_01.png`
- 单位：`unit_[faction]_[type]_[variant].png` 例：`unit_qin_rushi_01.png`
- UI 元素：`ui_[element_name].png` 例：`ui_button_end_turn.png`
- 禁止使用空格、大写、特殊字符

## 创作工具与流程
- 主要工具：Aseprite（推荐）或 LibreSprite
- 源文件保存为 `.aseprite` 格式，导出为 `.png`
- 精灵表由 Godot 的 SpriteFrames 或 AtlasTexture 处理
- 严禁直接修改导出的 PNG，必须在 Aseprite 中编辑后重新导出

## 文化覆盖层
- 使用半透明颜色混合，通过 TileMap 的第二层（覆盖层）实现
- 不同学派可定义不同颜色（儒家青、法家白、墨家黑、道家黄、兵家红、纵横家紫）

## 字体与 UI 美术
- 标题/书法字体：免费中文字体（如思源宋体）
- 正文/UI 字体：Noto Serif CJK 或思源宋体
- 所有字体文件需包含完整 CJK 字符集
- UI 主题背景采用羊皮纸/竹简质感，低透明度

## 音频管线
- 工具：Audacity（免费）
- 素材来源：CC0 素材库
- 风格：战国风传统乐器（古琴、编钟、鼓等）
- 文件位置：`assets/audio/bgm/`（背景音乐）、`assets/audio/sfx/`（音效）

## TileSet 创建流程
1. 精灵表导入 Godot
2. TileSet 编辑器定义碰撞形状和自定义数据层（地形类型、移动力消耗、特殊标记如关隘/渡口）
3. TileMapLayer 使用

## 验收标准
- 所有资产文件必须符合命名规则
- 所有 32x32 图块边缘清晰，无半透明像素
- 文化染色层与地形底图叠加后不产生视觉冲突
