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
- **TBD 项追踪**：策划案中标 ⚠️ 的待定项（如法家「法律指数」系统、纵横家盟友数量平衡）需在指定阶段前定稿，不得遗忘

## 项目知识与工具（配置维护）
- 游戏设计知识：见 `.claude/skills/shanhece-world.md`
- 技术架构规范：见 `.claude/skills/godot-guidelines.md`
- 美术资产管线：见 `.claude/skills/art-pipeline.md`
- 自定义命令：`.claude/commands/` 下的 `/balance`、`/event`、`/audit`、`/tilegen`、`/save`
- MCP 服务器配置：见 `.claude/mcp.json.template`（首次使用需复制为 `.claude/mcp.json` 后再按本地环境调整；`mcp.json` 已被 `.gitignore` 排除）
- 决策记录：见 `docs/decisions/阶段0-决策记录.md`