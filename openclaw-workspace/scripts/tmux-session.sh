#!/usr/bin/env bash
# tmux-session.sh — Create/manage persistent coding agent tmux sessions
# Usage:
#   tmux-session.sh create <name> <agent> <repo> [system-prompt] [topic]
#   tmux-session.sh send <name> <task>
#   tmux-session.sh list
#   tmux-session.sh status <name>
#   tmux-session.sh kill <name>
#
# Naming convention: oc-${project}-${feature}
# Always uses default tmux server (no custom sockets).
#
# Context: Claude Code runs interactively in the tmux session so follow-up
# tasks retain full conversation history. Completion is detected by polling
# for the shell/agent prompt.
#
# Callback routing env vars (set before create):
#   OC_CALLBACK_CHANNEL  — channel (e.g. "telegram")
#   OC_CALLBACK_TARGET   — chat id (e.g. "YOUR_GROUP_ID")
#   OC_CALLBACK_THREAD   — topic id (e.g. "1873")

set -euo pipefail

STATE_FILE="$HOME/.openclaw/workspace/state/tmux-sessions.json"
CALLBACK_DIR="/tmp/openclaw-tmux/callbacks"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
WAIT_SCRIPT="$HOME/.agents/skills/tmux/scripts/wait-for-text.sh"

# Ensure state file exists
if [ ! -f "$STATE_FILE" ]; then
  echo '{"sessions":{}}' > "$STATE_FILE"
fi

action="${1:-help}"

case "$action" in
  create)
    name="${2:?Session name required}"
    agent="${3:?Agent type required (claude|codex)}"
    repo="${4:?Repo path required}"
    system_prompt="${5:-}"
    topic="${6:-}"

    # Check if tmux session already exists
    if tmux has-session -t "$name" 2>/dev/null; then
      echo "tmux session '$name' already exists"
      exit 1
    fi

    # Expand repo path
    repo_expanded=$(eval echo "$repo")

    # Create tmux session in detached mode, cd to repo
    tmux new-session -d -s "$name" -c "$repo_expanded"
    tmux send-keys -t "$name" "export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1" Enter

    # Launch the agent interactively
    sleep 0.5
    case "$agent" in
      claude)
        if [ -n "$system_prompt" ]; then
          tmux send-keys -t "$name" -l -- "claude --dangerously-skip-permissions --system-prompt '$(printf '%s' "$system_prompt" | sed "s/'/'\\\\''/g")'"
        else
          tmux send-keys -t "$name" -l -- "claude --dangerously-skip-permissions"
        fi
        sleep 0.2
        tmux send-keys -t "$name" Enter
        ;;
      codex)
        tmux send-keys -t "$name" -l -- "codex"
        sleep 0.2
        tmux send-keys -t "$name" Enter
        ;;
    esac

    # Write callback file if env vars are set
    if [ -n "${OC_CALLBACK_CHANNEL:-}" ] || [ -n "${OC_CALLBACK_TARGET:-}" ]; then
      mkdir -p "$CALLBACK_DIR"
      cat > "$CALLBACK_DIR/${name}.json" <<CALLBACK_EOF
{
  "channel": "${OC_CALLBACK_CHANNEL:-}",
  "target": "${OC_CALLBACK_TARGET:-}",
  "threadId": "${OC_CALLBACK_THREAD:-}",
  "createdAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
CALLBACK_EOF
      echo "Callback: ${OC_CALLBACK_CHANNEL:-}/${OC_CALLBACK_TARGET:-}:${OC_CALLBACK_THREAD:-}"
    fi

    # Update state file
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    tmp=$(mktemp)
    jq --arg name "$name" \
       --arg agent "$agent" \
       --arg repo "$repo" \
       --arg prompt "$system_prompt" \
       --arg topic "$topic" \
       --arg now "$now" \
       --arg cb_channel "${OC_CALLBACK_CHANNEL:-}" \
       --arg cb_target "${OC_CALLBACK_TARGET:-}" \
       --arg cb_thread "${OC_CALLBACK_THREAD:-}" \
       '.sessions[$name] = {
          agent: $agent,
          repo: $repo,
          systemPrompt: $prompt,
          topic: $topic,
          created: $now,
          lastUsed: $now,
          status: "idle",
          callback: {
            channel: $cb_channel,
            target: $cb_target,
            threadId: $cb_thread
          }
        }' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"

    echo "Created tmux session '$name' (agent=$agent, repo=$repo)"
    echo "To monitor: tmux attach -t $name"
    ;;

  send)
    name="${2:?Session name required}"
    task="${3:?Task required}"

    # Check session exists
    if ! tmux has-session -t "$name" 2>/dev/null; then
      echo "tmux session '$name' not found"
      exit 1
    fi

    # Send task via tmux send-keys (agent is running interactively, keeps context)
    tmux send-keys -t "$name" -l -- "$task"
    sleep 0.2
    tmux send-keys -t "$name" Enter

    # Update state
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    tmp=$(mktemp)
    jq --arg name "$name" --arg now "$now" \
       '.sessions[$name].lastUsed = $now | .sessions[$name].status = "running"' \
       "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"

    # Background a completion watcher: wait for prompt, then fire callback
    COMPLETE_SCRIPT="$SCRIPTS_DIR/tmux-complete.sh"
    if [ -f "$WAIT_SCRIPT" ] && [ -f "$COMPLETE_SCRIPT" ]; then
      (
        # Wait for Claude Code prompt (❯) — stale timeout of 5 min
        # (only times out if output stops changing, so long tasks won't get killed)
        "$WAIT_SCRIPT" -t "$name" -p '❯' --stale 300 -i 5 2>/dev/null
        "$COMPLETE_SCRIPT" "$name" 2>/dev/null
      ) &
      disown
      echo "Completion watcher started (stale timeout: 5 min of no output)"
    fi

    echo "Sent task to '$name' (interactive, context preserved)"
    ;;

  list)
    echo "=== Tmux Sessions (from state) ==="
    jq -r '.sessions | to_entries[] | "  \(.key): agent=\(.value.agent) status=\(.value.status) callback=\(.value.callback.channel // "none"):\(.value.callback.threadId // "")"' "$STATE_FILE"
    echo ""
    echo "=== Live Tmux Sessions ==="
    tmux list-sessions 2>/dev/null || echo "  (none)"
    ;;

  status)
    name="${2:?Session name required}"
    if tmux has-session -t "$name" 2>/dev/null; then
      echo "Session '$name' is alive"
      echo "--- Last 30 lines ---"
      tmux capture-pane -t "$name" -p -S -30
    else
      echo "Session '$name' not found in tmux"
    fi
    jq --arg name "$name" '.sessions[$name] // "not in state"' "$STATE_FILE"
    ;;

  kill)
    name="${2:?Session name required}"
    tmux kill-session -t "$name" 2>/dev/null && echo "Killed tmux session '$name'" || echo "Session '$name' not found"
    tmp=$(mktemp)
    jq --arg name "$name" '.sessions[$name].status = "killed"' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
    rm -f "$CALLBACK_DIR/${name}.json"
    ;;

  ralph)
    name="${2:?Session name required}"
    repo="${3:?Repo path required}"
    prd="${4:?PRD file required}"
    shift 4

    # Parse optional flags
    engine="claude"
    extra_flags=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --engine) engine="${2:?Engine required}"; shift 2 ;;
        --fast) extra_flags="$extra_flags --fast"; shift ;;
        --sonnet) extra_flags="$extra_flags --sonnet"; shift ;;
        --codex) engine="codex"; shift ;;
        --max-retries) extra_flags="$extra_flags --max-retries $2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
      esac
    done

    session_name="oc-${name}"

    # Check if tmux session already exists
    if tmux has-session -t "$session_name" 2>/dev/null; then
      echo "tmux session '$session_name' already exists"
      exit 1
    fi

    # Expand repo path
    repo_expanded=$(eval echo "$repo")

    # Build ralphy command with engine flag
    engine_flag=""
    case "$engine" in
      codex) engine_flag="--codex" ;;
      claude) engine_flag="--claude" ;;
      *) engine_flag="--$engine" ;;
    esac

    # Build the full command with completion hook
    ralph_cmd="cd $repo_expanded && ralphy --prd $prd $engine_flag $extra_flags; EXIT_CODE=\$?; echo \"EXITED: \$EXIT_CODE\"; openclaw system event --text \"Ralph loop $session_name finished (exit \$EXIT_CODE) in \$(pwd)\" --mode now; sleep 999999"

    # Create tmux session
    tmux new-session -d -s "$session_name" -c "$repo_expanded"
    sleep 0.3
    tmux send-keys -t "$session_name" "$ralph_cmd" Enter

    # Write callback file if env vars are set
    if [ -n "${OC_CALLBACK_CHANNEL:-}" ] || [ -n "${OC_CALLBACK_TARGET:-}" ]; then
      mkdir -p "$CALLBACK_DIR"
      cat > "$CALLBACK_DIR/${session_name}.json" <<CALLBACK_EOF
{
  "channel": "${OC_CALLBACK_CHANNEL:-}",
  "target": "${OC_CALLBACK_TARGET:-}",
  "threadId": "${OC_CALLBACK_THREAD:-}",
  "createdAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
CALLBACK_EOF
    fi

    # Update state file
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    tmp=$(mktemp)
    jq --arg name "$session_name" \
       --arg agent "$engine" \
       --arg repo "$repo" \
       --arg prd "$prd" \
       --arg now "$now" \
       --arg cb_channel "${OC_CALLBACK_CHANNEL:-}" \
       --arg cb_target "${OC_CALLBACK_TARGET:-}" \
       --arg cb_thread "${OC_CALLBACK_THREAD:-}" \
       '.sessions[$name] = {
          agent: $agent,
          repo: $repo,
          mode: "ralph",
          prd: $prd,
          created: $now,
          lastUsed: $now,
          status: "running",
          callback: {
            channel: $cb_channel,
            target: $cb_target,
            threadId: $cb_thread
          }
        }' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"

    echo "Started Ralph loop '$session_name' (engine=$engine, prd=$prd)"
    echo "Completion hook will fire openclaw system event when done."
    echo "To monitor: tmux attach -t $session_name"
    ;;

  help|*)
    echo "Usage: tmux-session.sh <create|send|ralph|list|status|kill> [args...]"
    echo ""
    echo "Commands:"
    echo "  create <name> <agent> <repo> [system-prompt] [topic]"
    echo "  send   <name> <task>"
    echo "  ralph  <name> <repo> <prd-file> [--engine claude|codex] [--fast] [--sonnet]"
    echo "  list"
    echo "  status <name>"
    echo "  kill   <name>"
    echo ""
    echo "Modes:"
    echo "  create+send: Interactive Claude Code — context persists across tasks"
    echo "  ralph:       Ralph loop — fresh context per PRD task, completion hook"
    echo ""
    echo "Callback routing (set before create/ralph):"
    echo "  OC_CALLBACK_CHANNEL=telegram OC_CALLBACK_TARGET=-100xxx OC_CALLBACK_THREAD=1873 \\"
    echo "    tmux-session.sh ralph my-feature ~/projects/repo PRD.md"
    ;;
esac
