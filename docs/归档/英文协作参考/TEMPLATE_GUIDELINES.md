# Template Guidelines

This file defines how collaboration templates should be filled by humans and AI agents.

## General rules
1. Record facts, not guesses.
2. Copy file paths exactly.
3. Use fixed status values only.
4. Prefer tables over long prose.
5. Every completed item should be traceable to a file, test, data path, or reproducible check.

## Status values
- `planned`
- `waiting_delivery`
- `waiting_integration`
- `waiting_validation`
- `done`
- `paused`

## Path rules
- Use repo-relative paths.
- Do not use URI schemes.
- Do not write "same as above" or similar shorthand.

## Evidence field suggestions
Use one or more of:
- `file: <path>`
- `test: <name>`
- `data: <json path>`
- `check: <manual validation step>`

## Responsibility field
Use a concrete role or account name:
- `programming`
- `design`
- `art`
- specific teammate handle
- `unassigned`

## Recommended template discipline
- Keep titles short.
- Keep scope explicit.
- Separate delivered / pending / blocked items.
- Mark unknowns honestly.