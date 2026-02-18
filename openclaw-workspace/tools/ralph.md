# Ralph (ralphy) — Autonomous Coding Loop

## Overview

Ralph wraps coding agents (Claude Code, Codex, etc.) in a retry loop that iterates through a PRD checklist. Each task gets a fresh agent invocation — no context bloat. Externally tracks completion by checking if the agent ticked the checkbox.

## Installation

```bash
bun install -g ralphy-cli
```

- **Binary:** `$HOME/.bun/bin/ralphy`
- **Version:** 4.7.2
- **Source:** https://github.com/michaelshimeles/ralphy

## Key Commands

```bash
# PRD mode — work through a checklist
ralphy --prd PRD.md

# Single task
ralphy "add dark mode toggle"

# Engine selection
ralphy --claude --prd PRD.md    # Claude Code (default)
ralphy --codex --prd PRD.md     # Codex
ralphy --sonnet --prd PRD.md    # Claude Code with Sonnet model

# Skip tests/lint for speed
ralphy --fast --prd PRD.md

# Init project config
ralphy --init
```

## PRD Format

Markdown with checkboxes. Ralph picks the first unchecked item, runs the agent, checks if it got ticked, moves to next or retries.

```markdown
## Tasks
- [ ] Create the API endpoint for /api/users
- [ ] Add input validation with Zod
- [ ] Write tests for the endpoint
- [x] Already done (Ralph skips these)
```

Also supports YAML (`--yaml tasks.yaml`), JSON (`--json PRD.json`), and GitHub issues (`--github owner/repo`).

## Project Config (Optional)

```bash
ralphy --init  # Creates .ralphy/config.yaml with auto-detected settings
```

Config stores rules, boundaries, test/lint commands that get injected into every prompt:

```yaml
project:
  name: "my-app"
  language: "TypeScript"
  framework: "Next.js"
commands:
  test: "bun test"
  lint: "bun run lint"
rules:
  - "use server actions not API routes"
boundaries:
  never_touch:
    - "src/legacy/**"
```

## Our Usage: Always via tmux with completion hook

**Never run Ralph bare.** Always through our tmux wrapper:

```bash
# Via tmux-session.sh
tmux-session.sh ralph my-feature ~/projects/my-app PRD.md

# With engine selection
tmux-session.sh ralph my-feature ~/projects/my-app PRD.md --engine codex
tmux-session.sh ralph my-feature ~/projects/my-app PRD.md --sonnet
```

This automatically:
1. Creates tmux session `oc-my-feature`
2. Runs Ralph with completion hook
3. Fires `openclaw system event` when done → main session gets notified
4. Keeps shell alive (`sleep 999999`) so output can be read

## How It Works Under the Hood

1. Reads PRD, finds first `- [ ]` item
2. Builds prompt with task + project rules + boundaries
3. Runs agent non-interactively (`claude -p "prompt" --dangerously-skip-permissions`)
4. Agent exits → Ralph checks if checkbox got ticked `[x]`
5. If yes → next task. If no → retry (up to 3 times)
6. Loop until all checkboxes checked or max iterations hit

**Key insight:** Each iteration is a fresh agent invocation. No context accumulation. The PRD file is the external source of truth.

## Retry Behavior

- Default: 3 retries per task (`--max-retries N`)
- Delay between retries: 5 seconds (`--retry-delay N`)
- Rate limit errors detected and deferred
- Non-zero exit from agent triggers retry

## What Ralph Does NOT Do

- No semantic verification of code quality
- No diff analysis between iterations
- No "tests actually pass" validation (unless you tell it to run tests via config)
- Verification is just "did the checkbox get ticked" — the agent does the actual work

## Parallel Execution (Available but we don't use)

Ralph supports `--parallel` with git worktrees or sandbox mode. We don't use this — we scope tasks to non-overlapping files and run multiple agents in the same repo instead.

## When to Use Ralph vs Interactive Claude Code

| | Ralph | Interactive Claude Code |
|---|---|---|
| **Scope** | Defined, checklist-based | Open-ended, exploratory |
| **Context** | Fresh per task (no bloat) | Persistent (can bloat) |
| **Interaction** | Fire and forget | Back-and-forth |
| **Best for** | "Build this feature" with clear subtasks | Debugging, research, undefined scope |
| **Completion** | Automatic via hook | Manual check or watcher |
