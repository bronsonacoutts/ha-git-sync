#!/usr/bin/env bash
# ha-to-git.sh – Stage, commit, and push Home Assistant config to GitHub.
#
# Usage:
#   Called automatically by the HA shell_command.git_push service, or run
#   manually from a terminal on the HA host:
#     bash /config/scripts/ha-to-git.sh
#
# Environment variables (optional overrides):
#   HA_CONFIG_DIR   Path to the HA config directory. Default: /config
#   GIT_BRANCH      Branch to push to.            Default: main
#   GIT_USER_NAME   Git author name for commits.  Default: ha-git-sync
#   GIT_USER_EMAIL  Git author email.             Default: ha-git-sync@localhost
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
COMMIT_MSG="chore: sync from HA $(date -u '+%Y-%m-%dT%H:%M:%SZ')"  # requires GNU coreutils date (standard on Linux/HA hosts)

cd "$REPO_DIR"

git -c user.name="$GIT_USER_NAME" \
    -c user.email="$GIT_USER_EMAIL" \
    add -A

# Only commit when there are staged changes.
if git diff --cached --quiet; then
  echo "[ha-git-sync] Nothing to commit. Working tree is clean."
  exit 0
fi

git -c user.name="$GIT_USER_NAME" \
    -c user.email="$GIT_USER_EMAIL" \
    commit -m "$COMMIT_MSG"

git push origin "$GIT_BRANCH"
echo "[ha-git-sync] Pushed to origin/$GIT_BRANCH."
