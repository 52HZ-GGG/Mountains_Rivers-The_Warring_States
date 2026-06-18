# Collaboration Entry

This folder is the shared collaboration entry point for programmers, designers, artists, and AI agents working on the project.

## Core principles
1. Define requirements before delivery.
2. Validate assets and data before integration.
3. Freeze schema before large-scale implementation.
4. Track status explicitly.
5. Keep the main branch launchable in Godot at all times.

## Authority order
1. `AGENTS.md`
2. project code and data
3. design decision records under `docs/`
4. collaboration tracking docs under this folder

## Status vocabulary
Use only the following status values in collaboration docs:
- `planned`
- `waiting_delivery`
- `waiting_integration`
- `waiting_validation`
- `done`
- `paused`

## Recommended workflow
1. Designer/programmer defines exact requirement, path, naming, and acceptance rule.
2. Artist/designer delivers files or data.
3. Programmer validates path, naming, schema, and runtime behavior.
4. Validation result is recorded in board or handoff docs.

## Document map
- `AGENT_COLLAB_RULES.md`: agent-specific collaboration rules
- `TEMPLATE_GUIDELINES.md`: how to fill templates consistently
- `DEV_BOARD.md`: current work tracking board
- `ASSET_GAP_LIST.md`: missing asset list
- `ART_DELIVERY_TEMPLATE.md`: art delivery template
- `DESIGN_DELIVERY_TEMPLATE.md`: design delivery template
- `Agent交接-2026-05-30.md`: latest active handoff note