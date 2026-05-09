# `.claude/` 配置说明

本目录为《山河策》接入 Claude Code 的项目级配置。skills、commands、mcp 服务器在此集中管理。

## 首次拉取后的本机化步骤

仓库只提交了模板 `.claude/mcp.json.template`，真正生效的 `.claude/mcp.json` 已加入 `.gitignore`，**每位开发者首次克隆后必须执行以下两步**：

1. 复制模板为本地配置：
   ```bash
   cp .claude/mcp.json.template .claude/mcp.json
   ```
2. 编辑 `.claude/mcp.json`，把 `<YOUR_PROJECT_ABSOLUTE_PATH>` 替换为本机项目根绝对路径：
   - Windows 示例：`C:/Users/your_name/code/Mountains_Rivers-The_Warring_States`（推荐使用正斜杠，避免 JSON 转义问题）
   - macOS / Linux 示例：`/home/your_name/code/Mountains_Rivers-The_Warring_States`

之后改动 `mcp.json` 不会进入版本控制；如果模板本身有结构性更新，请改 `.template` 文件并提交。

## MCP 服务器一览

| 服务器       | 用途                                  | 最早启用阶段 |
| :----------- | :------------------------------------ | :----------- |
| `godot-mcp`  | 连接 Godot 编辑器，用于场景操作、调试 | 阶段 1       |
| `gamecodex`  | 4X 设计模式 / AI 行为树参考检索       | 阶段 0       |
| `filesystem` | 批量读写 JSON、搜索脚本、校验资产命名 | 阶段 0       |

## 验证

启动 Claude Code 后，输入 `/mcp` 查看上述三个服务器是否在线；若 `filesystem` 显示连接失败，先检查 `mcp.json` 是否已从模板复制、占位符是否已替换、路径是否真实存在。
