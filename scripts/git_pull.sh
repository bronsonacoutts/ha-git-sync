#!/usr/bin/env bash
set -euo pipefail

# Git Pull Script for Home Assistant Config
# Commits local changes then merges latest from origin/main (no push).
# Auto-recovers from stale locks, serializes syncs, and exits clearly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./git_runtime.sh
. "${SCRIPT_DIR}/git_runtime.sh"

prepare_repo

git_commit_if_needed "HA config pre-pull commit $(date -Iseconds)" || true

if ! git_fetch_origin_branch; then
    msg="Git pull failed: could not fetch from origin. Check network/credentials."
    echo "$msg" >&2
    ha_notify "Git Pull Failed" "$msg"
    exit 1
fi

if ! git_merge_origin_branch; then
    msg="Git pull failed: could not merge origin/${GIT_BRANCH}."
    echo "$msg" >&2
    ha_notify "Git Pull Failed" "$msg"
    exit 1
fi

echo "Git pull complete: merged origin/${GIT_BRANCH} (local changes win on conflict)."
