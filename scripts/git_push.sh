#!/usr/bin/env bash
# git_push.sh – Stage, commit, and push Home Assistant config to GitHub.
#
# Usage:
#   Called automatically by the HA shell_command.git_push service, or run
#   manually from a terminal on the HA host:
#     bash /config/scripts/git_push.sh
#   Optionally pass a custom commit message as the first argument:
#     bash /config/scripts/git_push.sh "HA nightly backup $(date -Iseconds)"
#
# Environment variables (optional overrides):
#   HA_CONFIG_DIR   Path to the HA config directory. Default: /config
#   GIT_BRANCH      Branch to push to.            Default: main
#   GIT_USER_NAME   Git author name for commits.  Default: ha-git-sync
#   GIT_USER_EMAIL  Git author email.             Default: ha-git-sync@localhost
#
# Loop prevention:
#   Commit messages start with "HA " so the notify-ha.yml GitHub Actions
#   workflow skips the webhook dispatch for pushes originating from HASS.
#
# Prerequisites:
#   - git is installed on the HA host (e.g. via the Git addon or SSH addon).
#   - The config directory is a git repository initialised against your remote.
#   - SSH key or credential helper is configured for passwordless push.
#     See docs/prerequisites.md for setup instructions.

set -euo pipefail

REPO_DIR="${HA_CONFIG_DIR:-/config}"
GIT_BRANCH="${GIT_BRANCH:-main}"
GIT_USER_NAME="${GIT_USER_NAME:-ha-git-sync}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-ha-git-sync@localhost}"
RAW_COMMIT_MSG="${1-}"
if [ -z "$RAW_COMMIT_MSG" ]; then
    COMMIT_MSG="HA config: sync from HA $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
elif [[ "$RAW_COMMIT_MSG" == HA\ * ]]; then
    COMMIT_MSG="$RAW_COMMIT_MSG"
else
    COMMIT_MSG="HA $RAW_COMMIT_MSG"
fi

cd "$REPO_DIR"
export HA_GIT_AUTOMATED=1

# Remove stale git lock files
for lock in .git/index.lock ".git/refs/heads/${GIT_BRANCH}.lock"; do
    [ -f "$lock" ] && rm -f "$lock" && echo "[ha-git-sync] Removed stale lock: $lock"
done

git -c user.name="$GIT_USER_NAME" -c user.email="$GIT_USER_EMAIL" add -A

if git diff --cached --quiet; then
    echo "[ha-git-sync] Nothing to commit."
    exit 0
fi

git -c user.name="$GIT_USER_NAME" -c user.email="$GIT_USER_EMAIL" commit -m "$COMMIT_MSG"

# Push with 3x retry/backoff
pushed=false
for attempt in 1 2 3; do
    if git push origin "$GIT_BRANCH"; then
        pushed=true
        break
    fi
    echo "[ha-git-sync] Push attempt $attempt failed. Waiting $((attempt * 10))s..." >&2
    sleep $((attempt * 10))
done

$pushed || { echo "[ha-git-sync] Push failed after 3 attempts." >&2; exit 1; }
echo "[ha-git-sync] Pushed to origin/$GIT_BRANCH."
