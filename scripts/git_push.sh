#!/usr/bin/env bash
set -euo pipefail

# Git Push Script for Home Assistant Config
# Commits local changes, reconciles remote updates, and publishes from the
# HA host to GitHub. In pull-request mode, it pushes a sync branch, opens or
# updates a PR, waits for checks, merges to origin/main, then fast-forwards
# the local repo to the GitHub merge commit.

RAW_COMMIT_MSG="${1-}"
if [ -z "$RAW_COMMIT_MSG" ]; then
    COMMIT_MSG="HA config: sync from HA $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
elif [[ "$RAW_COMMIT_MSG" == HA\ * ]]; then
    COMMIT_MSG="$RAW_COMMIT_MSG"
else
    COMMIT_MSG="HA $RAW_COMMIT_MSG"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/git_runtime.sh
. "${SCRIPT_DIR}/git_runtime.sh"

prepare_repo

if ! reconcile_and_publish "Git Push Failed" "$COMMIT_MSG"; then
    exit 1
fi

echo "Git push complete: HA changes are published to origin/${GIT_BRANCH}."
