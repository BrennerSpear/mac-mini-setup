# TOOLS.md - Local Notes

Short cross-cutting gotchas and environment quirks. Detailed tool docs in `tools/*.md` — searchable via `memory_search`.

## npm Wrapper
`/opt/homebrew/bin/npm` may redirect to `bun`. Use `bun install`, `bun install -g <pkg>`.

## Tmux Sessions
Default tmux server only. Naming: `oc-${project}-${feature}`. Easy find: `tmux ls | grep oc-`.

## Scripting
- Prefer bash `.sh` scripts
- Python packages: use `uv` / `uvx` (not pip)
- **SIGPIPE gotcha:** `set -euo pipefail` + `sort | head` → exit 141. Use `set -e` + `trap '' PIPE` for scripts with truncating pipes.

## Brave Search
- Free plan: one request at a time. Sequential searches only.
