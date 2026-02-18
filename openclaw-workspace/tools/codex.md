# Codex CLI — Failure Modes

**`codex exec` can silently hang (Feb 14, 2026):** Observed multiple attempts where `codex exec` spawns a process that shows 0:00.00 CPU time and produces 0 bytes of output indefinitely. Likely an OpenAI API issue (rate limit or outage). Every retry exhibits the same pattern — zombie processes.

**Workaround:** When Codex hangs, fall back to web search + manual research or use Claude directly. Don't keep retrying `codex exec` — it won't unstick itself.

**Installation:** `$HOME/.local/share/pnpm/codex` (v0.92.0)
**Default model:** `gpt-5.2-codex` (configured in `~/.config/codex/config.toml`)
**Usage:** `codex exec "prompt"` for non-interactive, `codex "prompt"` for interactive
**Subscription:** the user has a Codex subscription with credits
