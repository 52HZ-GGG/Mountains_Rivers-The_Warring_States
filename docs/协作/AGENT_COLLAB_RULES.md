# Agent Collaboration Rules

These rules are specifically for AI agent-assisted work in this repository.

## Language policy
- User replies should remain in Chinese unless the user asks otherwise.
- Collaboration docs for agents/workflow may be written in English.
- Code comments should prefer English going forward.
- Player-facing in-game text may remain Chinese.

## Safety policy for garbled files
Some `.gd` files contain garbled Chinese comments/text.
In unstable shells, rewriting those files can corrupt unrelated content.

Preferred approach:
1. Use Codex CLI, Git Bash, WSL, or manual IDE edits.
2. Prefer minimal diffs over whole-file rewrites.
3. Avoid broad formatting-only changes in high-risk files.
4. If a file is already garbled, do not "clean it up" as part of an unrelated bug fix.

## Coding change policy
- Fix root causes where possible.
- Keep changes minimal and directly tied to the task.
- Do not invent gameplay rules.
- Respect data-driven design and frozen schema expectations.

## Handoff policy
Each active multi-step issue should have:
- a current handoff doc
- a clear next action
- a note about risky files or unsafe editing environments