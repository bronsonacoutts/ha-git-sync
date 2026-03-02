#!/usr/bin/env bash
set -euo pipefail

# install_git_hooks.sh
# One-command installer for git hooks and pre-commit on any machine
# (developer laptop or the HASS box at /config).
#
# Usage:
#   /config/scripts/install_git_hooks.sh
#
# What it installs:
#   1. pre-commit framework hooks (yamllint, alias-lint, validate-automations, etc.)
#   2. commit-msg hook — enforces commit message format
#   3. pre-push hook   — blocks accidental direct pushes to main
#
# Safe to re-run: existing hooks are backed up to <hook>.bak before replacing.

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || echo /config)"
HOOKS_SRC="${REPO_ROOT}/scripts/git_hooks"
GIT_HOOKS_DIR="${REPO_ROOT}/.git/hooks"

echo "==> Installing git hooks for: ${REPO_ROOT}"

# ── 1. Install pre-commit framework ──────────────────────────────────────────
if command -v pre-commit >/dev/null 2>&1; then
    echo "pre-commit already installed: $(pre-commit --version)"
else
    echo "Installing pre-commit..."
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --quiet pre-commit
    elif command -v pip >/dev/null 2>&1; then
        pip install --quiet pre-commit
    else
        echo "⚠️  pip not found — skipping pre-commit install. Install it manually: pip install pre-commit" >&2
    fi
fi

if command -v pre-commit >/dev/null 2>&1; then
    echo "Activating pre-commit hooks..."
    cd "$REPO_ROOT"
    pre-commit install --install-hooks
    echo "✅  pre-commit hooks installed."
fi

# ── 2. Install custom git hook scripts ───────────────────────────────────────
install_hook() {
    local name="$1"
    local src="${HOOKS_SRC}/${name}"
    local dst="${GIT_HOOKS_DIR}/${name}"

    if [[ ! -f "$src" ]]; then
        echo "⚠️  Hook source not found: ${src}" >&2
        return
    fi

    if [[ -f "$dst" && ! -L "$dst" ]]; then
        cp "$dst" "${dst}.bak"
        echo "Backed up existing ${name} hook to ${name}.bak"
    fi

    cp "$src" "$dst"
    chmod +x "$dst"
    echo "✅  Installed hook: ${name}"
}

install_hook "commit-msg"
install_hook "pre-push"

echo ""
echo "==> All git hooks installed. Your commits will now be validated automatically."
