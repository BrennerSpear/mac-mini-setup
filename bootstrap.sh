#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Mac Mini Bootstrap — One-liner entry point
# curl -fsSL mac.brennerspear.com | bash
# curl -fsSL mac.brennerspear.com | bash -s -- --handoff   # hand off to Claude Code after
# =============================================================================

REPO_URL="https://github.com/BrennerSpear/mac-mini-setup.git"
CLONE_DIR="$HOME/projects/mac-mini-setup"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║       Mac Mini Setup — Bootstrap             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Step 1: Xcode Command Line Tools ──────────────────────────────────────────
if ! xcode-select -p &>/dev/null; then
  echo ">>> Installing Xcode Command Line Tools (required for git, compilers, etc.)..."
  echo "    A system dialog will appear. Click 'Install' and wait for it to finish."
  xcode-select --install

  # Wait for it to actually finish
  echo "    Waiting for Xcode CLT installation to complete..."
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
  echo "    ✅ Xcode CLT installed"
else
  echo "✅ Xcode CLT already installed"
fi

# ── Step 2: Clone the repo ────────────────────────────────────────────────────
mkdir -p "$(dirname "$CLONE_DIR")"

if [ -d "$CLONE_DIR/.git" ]; then
  echo ">>> Repo already cloned at $CLONE_DIR — pulling latest..."
  git -C "$CLONE_DIR" pull --ff-only
else
  echo ">>> Cloning setup repo..."
  git clone "$REPO_URL" "$CLONE_DIR"
fi

# ── Step 3: Run the setup script ──────────────────────────────────────────────
echo ""
echo ">>> Running setup script..."
echo ""
chmod +x "$CLONE_DIR/setup.sh"
"$CLONE_DIR/setup.sh" "$@"
