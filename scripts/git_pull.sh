#!/usr/bin/env bash
# git_pull.sh – Pull the latest config from GitHub into Home Assistant.
#
# Usage:
#   Called automatically by the HA shell_command.git_pull service (triggered
#   via the Git Pull on GitHub Webhook automation), or run manually:
#     bash /config/scripts/git_pull.sh
#
# Environment variables (optional overrides):
#   HA_CONFIG_DIR  Path to the HA config directory. Default: /config
#   GIT_BRANCH     Branch to pull from.            Default: main
#   GIT_USER_NAME  Git author name for commits.    Default: ha-git-sync
#   GIT_USER_EMAIL Git author email.               Default: ha-git-sync@localhost
#
# Conflict resolution:
#   Local changes always win (-X ours). Any uncommitted local changes are
#   committed as a pre-pull snapshot before the merge so they are preserved.

set -euo pipefail

REPO_DIR="${HA_CONFIG_DIR:-/config}"
GIT_BRANCH="${GIT_BRANCH:-main}"
GIT_USER_NAME="${GIT_USER_NAME:-ha-git-sync}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-ha-git-sync@localhost}"

cd "$REPO_DIR"
export HA_GIT_AUTOMATED=1

# Remove stale git lock files
for lock in .git/index.lock ".git/refs/heads/${GIT_BRANCH}.lock"; do
    [ -f "$lock" ] && rm -f "$lock" && echo "[ha-git-sync] Removed stale lock: $lock"
done

# Commit any local changes before merging to avoid conflict
git -c user.name="$GIT_USER_NAME" -c user.email="$GIT_USER_EMAIL" add -A
if ! git diff --cached --quiet; then
    git -c user.name="$GIT_USER_NAME" -c user.email="$GIT_USER_EMAIL" \
        commit -m "HA config: pre-pull snapshot $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
fi

if ! git fetch origin "$GIT_BRANCH"; then
    echo "[ha-git-sync] Pull failed: could not fetch from origin." >&2
    exit 1
fi

# Merge with conflict resolution: local changes win
git merge --no-edit -X ours "origin/$GIT_BRANCH"
echo "[ha-git-sync] Pulled from origin/$GIT_BRANCH (local changes win on conflict)."
