# Task Delegation — Persistent Tmux Sessions

**Default behavior: delegate work to named, persistent tmux sessions running coding agents.**

Instead of disposable sub-agents that blow up at 200k tokens, we use long-lived tmux sessions with Claude Code or Codex. Each session has its own repo, system prompt, and topic — tracked in `state/tmux-sessions.json`.

## The Model

| Mode | Use For | How |
|------|---------|-----|
| **Claude Code (interactive)** | Exploratory, debugging, undefined scope, back-and-forth | `tmux-session.sh create` + `send` |
| **Ralph + Claude Code** | Multi-step features with clear PRD checklist | `tmux-session.sh ralph <name> <repo> PRD.md` |
| **Ralph + Codex** | Well-scoped backend features with PRD | `tmux-session.sh ralph <name> <repo> PRD.md --engine codex` |

### Ralph Loop (for defined features)

Ralph wraps coding agents in a retry loop against a PRD checklist. Each task gets a **fresh agent invocation** — no context bloat. See `tools/ralph.md` for full details.

```bash
# Write a PRD with checkboxes
cat > ~/projects/my-app/PRD.md << 'EOF'
## Tasks
- [ ] Create the API endpoint for /api/users
- [ ] Add input validation with Zod
- [ ] Write tests for the endpoint
- [ ] Add rate limiting middleware
EOF

# Launch via tmux (auto-notifies on completion)
tmux-session.sh ralph my-app ~/projects/my-app PRD.md
```

**When to use Ralph vs Interactive:**
- **Ralph:** 3-8 subtasks, defined scope, "build this feature" work. Fresh context per task prevents bloat.
- **Interactive:** Debugging, exploratory, needs back-and-forth, undefined scope.

### Parallel agents on same repo

Multiple agents can work on the same repo simultaneously — no need for separate clones or git worktrees. Just scope tasks to non-overlapping files.

## How It Works

1. **Receive task** from the user
2. **Check `state/tmux-sessions.json`** — does a relevant session already exist?
3. **If yes:** Send the task to the existing tmux session via `tmux send-keys`
4. **If no:** Create a new named tmux session, register it in state, then send the task
5. **Monitor** via `tmux capture-pane` and report back when done
6. **Tell the user** the session name whenever creating a new one

## State File: `state/tmux-sessions.json`

```json
{
  "sessions": {
    "my-project": {
      "agent": "claude",
      "repo": "~/projects/my-project",
      "systemPrompt": "You work on my-project — a sample web app...",
      "topic": "Project dev & operations",
      "created": "2026-02-11T...",
      "lastUsed": "2026-02-11T...",
      "status": "idle"
    }
  }
}
```

## Management Script: `scripts/tmux-session.sh`

```bash
tmux-session.sh create <name> <agent> <repo> [system-prompt] [topic]
tmux-session.sh send <name> <task>
tmux-session.sh list        # Show all sessions (state + live tmux)
tmux-session.sh status <name>  # Last 30 lines + state
tmux-session.sh kill <name>
```

## Session Naming

- Use kebab-case: `my-project`, `openclaw-ui`, `data-research`
- Name should match the repo or project, not the task
- Sessions are reusable — send different tasks to the same session over time

## When to Still Use `sessions_spawn`

- **Truly one-off quick tasks** that won't exceed ~50k tokens (quick lookups, simple research)
- **Cron job deliveries** that need isolated sessions
- **Never** for anything involving browser automation, complex multi-step work, or code changes

## When to Do It Inline (No Delegation)

- Trivial one-liners (quick lookups, simple questions, yes/no answers)
- Anything requiring back-and-forth conversation to clarify intent
- Straightforward setup tasks (clone repo, configure a file, update Caddy)
- When the user explicitly says "just do it here"

## 🔬 Research Tasks — ALWAYS Use Skills First

**Before delegating a research task, ALWAYS read the research skill** (`skills/research/SKILL.md`). The skill defines two modes:

1. **Deep Research (comprehensive topics):** Use `parallel-research` CLI → Parallel AI API. This is the DEFAULT for any substantial research request.
2. **Interactive Research (lighter exploration):** Manual web_fetch + synthesis. Only for quick questions.

**This applies to ALL skills.** Before starting any task, scan `<available_skills>` and read the matching SKILL.md. Skills encode best practices and tool choices.

## Coding Agent Conventions

- **Always use `pty: true`** when running coding agents — they need a terminal
- **Never use `--no-verify`** — if pre-commit hooks fail, fix the underlying issue
- **Parallel repo modifications: isolate working directories.** Multiple agents on same repo → each clones to its own temp dir
- **Let the main session handle routing.** Tmux sessions do the work; I relay results to the right Telegram topic

### 🔍 Verify Before Reporting Failure

**HARD RULE: Before reporting a tmux agent as failed/stuck, ALWAYS run `git log --oneline -3` in the repo.**

This mistake has happened repeatedly — agent appears idle or shows a rate-limit warning, so the main session reports failure to the user. But the work was already committed and pushed. The agent just hadn't printed a final summary.

Check sequence when a tmux agent looks stuck:
1. `tmux capture-pane -p -J -t <name> -S -30` — check recent output
2. `cd <repo> && git log --oneline -3` — did it actually commit?
3. `git diff --stat HEAD~1` — what changed?
4. Only THEN report status to the user

### 🚨 External Contact / Real-World Actions

**Sub-agents that interact with the outside world need EXPLICIT constraints.** When a sub-agent fills forms, sends emails, or contacts real humans:

- **INQUIRY ONLY unless explicitly told otherwise.** If the task is "reach out to X," the sub-agent should ONLY submit inquiry/contact forms — NEVER book appointments, make purchases, or take irreversible actions.
- **If only a booking form exists (no contact/inquiry form), STOP and report back.** Do not fill out the booking form. Let the main session decide.
- **No improvising communication channels.** If a contact form doesn't work (captcha, broken, etc.), report back — don't fall back to sending emails from agent addresses unless the task explicitly allows it.
- **No test messages to real people.** Ever. Debug locally, not against live endpoints.
- **Include these constraints verbatim in every sub-agent task** that involves external contact. Don't assume the sub-agent will infer caution — spell it out.

## Model-Specific Guardrails

These exist because specific models made specific mistakes. **Opus/Sonnet: you already know this — skip this section.**

**Budget models (Qwen, free tier):**
- Never use `--no-verify` — fix the pre-commit hooks instead
- Always read the repo's AGENTS.md/CONTRIBUTING.md before committing
- Don't commit directly to main unless explicitly told to
- Create a feature branch before making any changes
- Run lint/type checks before committing (e.g., `bun check`, `bun typecheck`)

**⚠️ DeepSeek is BANNED from all automated tasks.** DeepSeek V3.2 produces garbled XML instead of proper JSON tool calls — `sessions_spawn`, `exec`, and other tools break unpredictably. Observed repeatedly in cron jobs (self-reflection, agentmail, etc.). Don't use DeepSeek for anything that needs reliable tool calling. Use Sonnet for cron jobs, Opus for sub-agents.

**Model selection for code changes:**
- Use Opus/Sonnet/Kimi for anything that commits code to real repos
- Use Qwen for research, file ops, lookups, and non-code tasks (if cost matters)
