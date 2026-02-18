# OpenClaw Internals

## Sessions API — Subagent Identification (Feb 14, 2026)

**`openclaw sessions --json` returns `kind: "direct"` for subagent sessions**, not `kind: "subagent"`. To identify subagents, match on the session `key` containing `:subagent:` (e.g., `agent:main:subagent:uuid`). This applies to any tool consuming the sessions API (Deck dashboard, scripts, etc.). The `kind` field only distinguishes `"direct"` vs `"group"`.

## Plugin-SDK — Dual-Bundle Module Isolation (Feb 14, 2026)

**`onDiagnosticEvent()` and `registerLogTransport()` from `openclaw/plugin-sdk` don't receive events.** The gateway's bundled JS files (`reply-*.js`, `extensionAPI.js`) each instantiate their own `const listeners = new Set()`, separate from the `plugin-sdk/index.js` bundle that plugins import from. So plugins register in one `Set`, but the gateway emits into different `Set`s. This is a fundamental architecture issue — not a config problem.

**Affected:** Any managed extension that imports `onDiagnosticEvent` or `registerLogTransport` from `openclaw/plugin-sdk` (e.g., `diagnostics-otel`).

**Workaround:** The extension needs to hook into the gateway's *actual* module instances, not the plugin-sdk re-export. Possible approaches:
- Monkey-patch the gateway bundle's `emitDiagnosticEvent` at load time
- Use the plugin API object to bridge events (requires OpenClaw core change)
- Wait for an upstream fix that unifies the listener Sets

**Key lesson:** When debugging "plugin loads but doesn't receive data" in OpenClaw, check for split module instances first. The `jiti` loader aliasing `openclaw/plugin-sdk` to `dist/plugin-sdk/index.js` creates a separate JS module scope from the gateway's own bundled copies of the same code.

**Current state (Feb 14 evening):** The installed dist files (`~/.bun/install/global/node_modules/openclaw/dist/`) have been patched with the `globalThis[Symbol.for("openclaw.diagnosticListeners")]` fix by the `oc-otel-research` tmux agent. But the npm tarball for `openclaw@2026.2.13` does NOT contain this fix (confirmed via `npm pack` comparison). **This patch is fragile — any `bun install`/`bun update` will revert it.** The upstream PR (#5190) is still open.

## Hooks — Override Pattern

**Managed hooks override bundled hooks.** Place `HOOK.md` + `handler.ts` in `~/.openclaw/hooks/<hook-name>/` to replace a bundled hook. OpenClaw picks up the managed version automatically (shows as `openclaw-managed` in `openclaw hooks list`).

**Don't import bundled internals** — Hashed filenames (e.g., `config-CI7EpvlP.js`) change on every OpenClaw update, breaking imports. Rewrite the logic from scratch instead of importing from `../../config-*.js`.

**Session-memory hook custom:** Overridden to write to `memory/daily/` instead of `memory/`. Located at `~/.openclaw/hooks/session-memory/handler.ts`. Generates slug from session topic or key, saves on `/new` command.

## Subagent Announce Failures in Cron Sessions (Feb 17, 2026)

**Subagent completion announcements fail with `Delivering to Telegram requires target <chatId>` when the requester is a cron session.** The cron session doesn't have a Telegram delivery target, so when the subagent finishes and OpenClaw tries to announce the result back, it fails. Visible in `logs/gateway.err.log` and `logs/gateway.log`.

**Impact:** The subagent's work still completes and writes to files correctly — only the announce-back message is lost. The parent cron session never receives the subagent's final summary.

**Affected:** Any cron job that spawns subagents (e.g., self-reflection cron spawns a subagent to do the actual reflection work).

**Workaround:** None needed if the subagent writes its output to files. The announce failure is cosmetic. If the parent cron needs the result, the cron job's `delivery` config may need a `channel`/`target` set.

## Subagent Label Collision on Cron Re-runs (Feb 17, 2026)

**`sessions.patch errorCode=INVALID_REQUEST errorMessage=label already in use: self-reflection`** — When a cron job spawns a subagent with a fixed label (e.g., "self-reflection"), and the previous subagent's session hasn't been fully cleaned up by the next cron run, the label collision prevents the new session from being tagged.

**Visible in:** `logs/gateway.log` as a `sessions.patch` error.

**Impact:** The subagent still runs, but won't have the label attached. May affect `subagents list` filtering.

## Git Pre-Commit Hook

**False positive on `sk_test_` pattern (Feb 14, 2026):** The pre-commit secret scanner blocks commits containing `sk_test_[a-zA-Z0-9]`. This fires on gateway error logs that contain *example* Stripe key patterns (from self-reflection sessions discussing masking rules, not actual secrets). The daily-workspace-commit cron uses `--no-verify` to bypass when the flagged content is confirmed non-secret. Always verify the flagged content before bypassing.
