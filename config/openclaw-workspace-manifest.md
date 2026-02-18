# OpenClaw Workspace Manifest

What to copy from a working OpenClaw install to bootstrap a new machine.
The setup-openclaw.sh script handles the three secret files. This doc covers
everything else that makes OpenClaw actually useful day-to-day.

---

## 1. Cron Jobs (Generic / Recommended)

These keep OpenClaw running smoothly. They should be recreated on any new install.

| Name | Schedule | What it does |
|---|---|---|
| `self-reflection` | `0 * * * *` (hourly) | Reviews recent sessions, writes lessons learned |
| `system-watchdog` | `0 4 * * *` (daily 4am) | Checks system health, disk, services |
| `cron-health-watchdog` | `0 */6 * * *` (every 6h) | Monitors cron jobs for failures |
| `error-log-digest` | `0 8 * * *` (daily 8am) | Reviews gateway error logs, reports issues |
| `workspace-activity-feed` | `0 */6 * * *` (every 6h) | Posts activity summary to Discord #activity-feed |

### Personal / Optional Cron Jobs
These are personal — skip or adapt:

| Name | Schedule | What it does |
|---|---|---|
| `daily-news-digest` | `0 6 * * *` | Morning news briefing via daily-digest skill |
| `agentmail-inbox-check` | `0 9 * * *` | Checks agent email inbox |
| One-shot reminders | `at` | Personal reminders (eth-btc ladder, Rx check, etc.) |

### Disabled (not needed on new installs)
- `sub-agent-monitor` — experimental, currently disabled
- `daily-workspace-commit` — disabled
- `sync-workspace-to-obsidian` — disabled
- `process-stop-events` — disabled

---

## 2. Skills

### Installed via clawhub (`~/.agents/skills/`)
These get installed by `clawhub install`. Run on new machine:

```bash
clawhub install agent-browser architecture-research caddy commit create-mcp deslop dev-serve diagrams domain-check execute-brain-dump-tasks merge-upstream modal new-brain-dump process-brain-dump research supabase tmux ui-scaffold vercel
```

### Custom skills (`~/.openclaw/skills/`)
These are local/private skills. Copy the whole directory:

**Generic (useful for anyone):**
- `cron-setup` — conventions for creating cron jobs
- `self-reflection` — hourly self-improvement analysis
- `system-watchdog` — system health checks
- `email` — Gmail via gog CLI
- `gog` — Google Workspace CLI
- `flights` — Google Flights search
- `clawdstrike` — security audit
- `doc-layers` — document management conventions
- `answeroverflow` — search Discord community Q&A

**Personal / personal:**
- `daily-digest` — morning news briefing (customized topics)
- `agentmail` — agent email setup
- `amazon` — Amazon browser automation
- `chef` — cooking/recipes
- `spotify-history` — Spotify API
- `telegram-ops` — Telegram bot management
- `voiceclone` — voice cloning
- `vercel-speed` — Vercel performance monitoring

---

## 3. Workspace Files

### Root files (injected every session)
These are the "personality and operating manual":

| File | What it does | Generic? |
|---|---|---|
| `AGENTS.md` | Operating instructions, safety rules, workflow | ✅ Mostly — adapt for your team |
| `SOUL.md` | Personality, tone, communication style | ✅ Customize per agent |
| `IDENTITY.md` | Name, creature, vibe, emoji | ✅ Customize |
| `USER.md` | User profile (name, timezone, values) | ❌ Personal — rewrite per user |
| `TOOLS.md` | Tool gotchas, environment quirks | ✅ Mostly generic |
| `MEMORY.md` | Memory index | ✅ Generic structure |
| `HEARTBEAT.md` | Active processes to monitor | ⚠️ Dynamic — starts empty |

### docs/ (searchable reference)
Generic and useful:
- `tmux-delegation.md` — how to delegate to coding agents
- `model-selection.md` — which models for which tasks
- `sub-agent-guidelines.md` — sub-agent orchestration
- `doc-layers.md` — document management
- `openclaw-playbook.md` — OpenClaw operations guide

### tools/ (searchable reference)
All generic — tool-specific notes and gotchas:
- `browser.md`, `discord.md`, `gog.md`, `ralph.md`, etc.

### scripts/ (automation)
Generic:
- `tmux-session.sh` — tmux session management
- `error-digest.sh` — error log analysis
- `sync-obsidian.sh` — workspace → Obsidian sync

### memory/ (knowledge base)
- `about-user.md` — personal (rewrite per user)
- `daily/` — daily logs (starts empty)

---

## 4. Config Template Updates

The existing `openclaw-config.template.json` should include:

### Agent defaults (already there)
- model, fallbacks, aliases
- memorySearch with Gemini provider
- compaction mode
- heartbeat interval
- max concurrent sessions/subagents

### Skills config (add to template)
```json
"skills": {
  "load": { "extraDirs": ["~/.agents/skills"] },
  "install": { "nodeManager": "bun" },
  "entries": {
    "brave-search": { "apiKey": "$BRAVE_API_KEY" },
    "goplaces": { "apiKey": "$GOOGLE_PLACES_API_KEY" },
    "nano-banana-pro": { "apiKey": "$GEMINI_API_KEY" }
  }
}
```

### Plugins (add to template)
```json
"plugins": {
  "allow": ["device-pair", "memory-core", "discord", "diagnostics-otel"],
  "entries": {
    "discord": { "enabled": true },
    "diagnostics-otel": { "enabled": true }
  }
}
```

---

## 5. Bootstrap Sequence

After secrets files are placed and `setup-openclaw.sh` runs:

1. **Install clawhub skills** — `clawhub install <list>`
2. **Copy custom skills** — from backup/repo to `~/.openclaw/skills/`
3. **Copy workspace files** — AGENTS.md, SOUL.md, etc. to `~/.openclaw/workspace/`
4. **Copy docs/** — reference docs
5. **Copy tools/** — tool-specific notes
6. **Copy scripts/** — automation scripts
7. **Create cron jobs** — via `openclaw` or the cron API
8. **Start gateway** — `openclaw gateway start`
9. **Verify** — `setup-openclaw.sh --check`
