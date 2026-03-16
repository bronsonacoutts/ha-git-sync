#!/usr/bin/env bash
set -euo pipefail

# install_git_hooks.sh
# Installs the commit-msg, pre-push, and post-merge git hooks.
#
# Usage:
#   /config/scripts/install_git_hooks.sh
#
# Safe to re-run: existing hooks are backed up to <hook>.bak before replacing.

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || echo /config)"
GIT_HOOKS_SRC="${REPO_ROOT}/scripts/git_hooks"
MERGE_HOOKS_SRC="${REPO_ROOT}/hooks"
GIT_HOOKS_DIR="${REPO_ROOT}/.git/hooks"

echo "==> Installing git hooks for: ${REPO_ROOT}"

install_hook() {
    local name="$1"
    local source_dir="$2"
    local src="${source_dir}/${name}"
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

install_hook "commit-msg" "${GIT_HOOKS_SRC}"
install_hook "pre-push" "${GIT_HOOKS_SRC}"
install_hook "post-merge" "${MERGE_HOOKS_SRC}"

echo ""
echo "==> Git hooks installed."
