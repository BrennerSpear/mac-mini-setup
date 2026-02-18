# Sub-Agent Model Selection

**Always pick the right model for the job.** Default to the smartest available, then drop down based on task complexity and rate limit concerns.

## Model Tiers (prefer higher tiers, drop down when appropriate)

| Tier | Model | Provider | Cost/M (in/out) | Use For |
|------|-------|----------|-----------------|---------|
| **S** | `anthropic/claude-opus-4-6` | Anthropic Direct (Max Plan) | Included | Main session, complex reasoning, architecture, sub-agents needing top intelligence. |
| **A** | `anthropic/claude-sonnet-4-20250514` | Anthropic Direct (Max Plan) | Included | Good all-rounder. Research, writing, analysis. Cheaper on rate limits than Opus. |
| **A** | `openrouter/moonshotai/kimi-k2.5` | OpenRouter | $0.45/$2.25 | Strong non-Anthropic model. Research, docs, creative work. ⚠️ Observed garbled/degenerate thinking output at 169k context — avoid for high-context analytical tasks. |
| **B** | `openrouter/qwen/qwen3-coder` | OpenRouter | $0.22/$1 | Code-heavy tasks — audits, refactors, analysis. |
| **C** | `openrouter/qwen/qwen3-coder:free` | OpenRouter | FREE | Simple code tasks when cost matters. |
| **C** | `openrouter/qwen/qwen3-next-80b-a3b-instruct:free` | OpenRouter | FREE | Simple general tasks when cost matters. |

**⚠️ NEVER route Anthropic models through OpenRouter.** You have a Max Plan — all Claude calls go direct through Anthropic. OpenRouter charges real money for Anthropic models and the Max Plan already covers it.

## Selection Rules

1. **DEFAULT: Always use Opus** (`anthropic/claude-opus-4-6`) for ALL sub-agents. Period. You have a Max Plan — Opus is FREE. There is NO cost reason to use anything else. Do not "cost optimize" — nobody asked for that.
2. **Frontend code (UI, components, CSS, Svelte, React):** Opus — always, no exceptions.
3. **Backend code (APIs, server logic, data processing):** OpenAI Codex (`gpt-5.2-codex`) via `codex exec` CLI — You have a Codex subscription.
4. **Sonnet is NOT for real work.** Only use Sonnet for lightweight cron jobs, quick checks, and small automated tasks. Never for sub-agents doing actual work.
5. **Simple file ops / lookups:** Qwen free models (only when it's truly trivial).
6. **When Anthropic rate limited:** Fall back to Kimi K2.5 or Qwen, NOT OpenRouter Anthropic.
7. **NEVER use DeepSeek.** Unreliable tool calling — produces garbled XML. Banned from all tasks.
8. **When in doubt:** Use Opus. It's included in the plan.

## Codex CLI

- Installed at `$HOME/.local/share/pnpm/codex` (v0.92.0)
- Default model: `gpt-5.2-codex` (configured in `~/.config/codex/config.toml`)
- Usage: `codex exec "prompt"` for non-interactive, `codex "prompt"` for interactive
- You have a Codex subscription with credits
