#!/usr/bin/env bash
set -euo pipefail

# Git Sync Script for Home Assistant Config
# Commits local changes, merges upstream updates, and pushes safely.

commit_message="${1:-HA config sync $(date -Iseconds)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./git_runtime.sh
. "${SCRIPT_DIR}/git_runtime.sh"

prepare_repo

git_commit_if_needed "$commit_message" || true

if ! git_fetch_origin_branch; then
    msg="Git sync failed: could not fetch origin/${GIT_BRANCH}."
    echo "$msg" >&2
    ha_notify "Git Sync Failed" "$msg"
    exit 1
fi

if ! git_merge_origin_branch; then
    msg="Git sync failed: could not merge origin/${GIT_BRANCH}."
    echo "$msg" >&2
    ha_notify "Git Sync Failed" "$msg"
    exit 1
fi

echo "Git sync merged origin/${GIT_BRANCH} with -X ours (local changes win conflicts; review upstream updates if needed)."

if ! git_push_with_retry; then
    msg="Git sync push failed after reconcile retries. Check credentials and network."
    echo "$msg" >&2
    ha_notify "Git Sync Failed" "$msg"
    exit 1
fi

echo "Git sync complete: local and origin/${GIT_BRANCH} reconciled."
