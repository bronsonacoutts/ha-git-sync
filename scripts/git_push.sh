#!/usr/bin/env bash
set -euo pipefail

# Git Push Script for Home Assistant Config
# Commits local changes, reconciles remote updates, and pushes to origin/main.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./git_runtime.sh
. "${SCRIPT_DIR}/git_runtime.sh"

prepare_repo

git_commit_if_needed "HA config update $(date -Iseconds)" || true

if ! git_fetch_origin_branch; then
    msg="Git push failed: could not fetch origin/${GIT_BRANCH} before push."
    echo "$msg" >&2
    ha_notify "Git Push Failed" "$msg"
    exit 1
fi

if ! git_merge_origin_branch; then
    msg="Git push failed: could not merge origin/${GIT_BRANCH} before push."
    echo "$msg" >&2
    ha_notify "Git Push Failed" "$msg"
    exit 1
fi

if ! git_push_with_retry; then
    msg="Git push failed after reconcile retries. Check credentials and network."
    echo "$msg" >&2
    ha_notify "Git Push Failed" "$msg"
    exit 1
fi

echo "Git push complete: changes pushed to origin/${GIT_BRANCH}."
