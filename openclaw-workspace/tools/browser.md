# Browser Automation

## Two Browser Systems (Feb 16, 2026)

We have **two separate browser setups** — don't confuse them:

| | **agent-browser CLI** | **OpenClaw `browser` tool** |
|---|---|---|
| **Binary** | `agent-browser` (npm) | Built into OpenClaw |
| **Engine** | Real Chrome via CDP | Playwright's "Chrome for Testing" |
| **Profile** | `~/.agents/browser/profiles/default` | `~/.openclaw/browser/openclaw/user-data` |
| **CDP port** | 9222 | 18800 |
| **Google login** | ✅ Yes (real Chrome) | ❌ No (Chrome for Testing blocks it) |
| **Launch** | Raycast script → `open -na "Google Chrome"` | Automatic (OpenClaw manages) |
| **Connect** | `agent-browser --cdp 9222 <command>` | `browser` tool with `profile="openclaw"` |
| **Use for** | Sites needing Google auth, Resy, authenticated browsing | Amazon, unauthenticated scraping |

## agent-browser + Real Chrome (Primary)

**Architecture:** the user launches real Chrome via Raycast script → Chrome stays alive (launchd-managed) → agent-browser connects via `--cdp 9222`.

**Usage:**
```bash
agent-browser --cdp 9222 open "https://resy.com"
agent-browser --cdp 9222 snapshot -i -c
agent-browser --cdp 9222 click @e2
agent-browser --cdp 9222 screenshot page.png
```

**Profile:** `~/.agents/browser/profiles/default` — the user's logged-in Chrome profile with cookies for Google, Resy, etc. Treat as sacred — never nuke it.

**Raycast script:** `~/raycast-scripts/open-agent-browser.sh` — launches real Chrome with `--user-data-dir` and `--remote-debugging-port=9222`. Also cleans stale singleton locks and kills any Playwright instances using the same profile.

## ⚠️ Profile Corruption Prevention Rules

1. **NEVER use `--profile` flag with agent-browser on your Chrome profile.** `--profile` launches Playwright's Chromium ("Chrome for Testing"), which writes to the same profile dir in a different format. Two browsers writing = corruption.
2. **NEVER restore individual SQLite files** (Cookies, Login Data) into an existing profile. Either use the whole profile directory or start fresh.
3. **Chrome CANNOT be launched from `exec` tool** — always fails with "Mach rendezvous failed, parent died?" because exec subprocesses exit and kill Chrome's child processes. Only `open -na` (via Raycast or manual) works.
4. **If Chrome won't start**, check for stale `SingletonLock` files: `rm -f ~/.agents/browser/profiles/default/Singleton*`
5. **If the profile is truly corrupted** (Chrome exits immediately), nuke the profile dir and have the user re-login. Don't try to salvage individual files.

## `AGENT_BROWSER_PROFILE` env var — DO NOT SET

The `AGENT_BROWSER_PROFILE` env var makes agent-browser use Playwright's Chromium with a persistent profile. This conflicts with the real Chrome setup. Do not set it. Always use `--cdp 9222` instead.

## Google OAuth via agent-browser

Google's sign-in pages detect synthetic JS clicks (`element.click()`, `dispatchEvent(new MouseEvent(...))`) and redirect to Help pages instead of completing OAuth. **This includes `eval`-based clicks.**

**What works:** `agent-browser --cdp 9222 click @ref --timeout 15000` — Playwright's native click simulates real mouse input at element coordinates, which Google trusts.

**Workflow for Google OAuth:**
1. `open "https://site.com"` → navigate to the login page
2. `snapshot -i` → get interactive refs
3. `click @e1 --timeout 15000` → click "Log in with Google" (use refs, NOT eval)
4. `snapshot -i` → get account chooser refs
5. `click @e2 --timeout 15000` → click the account (e.g. "your-account@example.com")
6. `snapshot -i` → consent page, click "Continue"
7. Wait for redirect back to the app

**Key rules:**
- Always use `click @ref`, never `eval "element.click()"`
- Use `--timeout 15000` — OAuth pages are slow
- Use `snapshot -i` between each step to get fresh refs
- If stuck on account chooser, do NOT fall back to eval/keyboard — retry with `click @ref`

## Multi-Session Tab Conflicts

**Always open a new tab** (`agent-browser open <url> --new-tab`). Other the agent sessions may be using existing tabs in the same Chrome instance. Never navigate in an existing tab — always start fresh.

## OpenClaw Browser (profile="openclaw") — For Amazon & Unauthenticated

- Uses Playwright's "Chrome for Testing" — **cannot do Google sign-in**
- Profile: `~/.openclaw/browser/openclaw/user-data` (CDP port 18800)
- **Always pass `profile="openclaw"` on every browser tool call** — not just `open`. Actions like `snapshot`, `screenshot`, `act` will silently fall back to the Chrome extension relay if `profile` is omitted.
- **Headless by default** (`browser.headless: true`). If CAPTCHA or re-auth needed, set `browser.headless: false` via config.patch.
- **Snapshot refs go stale** after page navigation, timeouts, or any DOM change. Always re-snapshot immediately before clicking.
- **Avoid broad CSS selectors** on Amazon (e.g., `[id*='buy']` matches 30+ elements). Use snapshot refs (`e36` etc.) or exact element IDs.