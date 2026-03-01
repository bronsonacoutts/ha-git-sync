#!/usr/bin/env bash
set -euo pipefail

# Git Pull Script for Home Assistant Config
# Commits local changes then merges latest from origin/main (no push).
# Auto-recovers from stale locks; notifies HA on unrecoverable errors.

HA_NOTIFY_URL="http://localhost:8123/api/services/persistent_notification/create"

ha_notify() {
    local title="$1"
    local message="$2"
    local -a auth_args=()
    if [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
        auth_args=(-H "Authorization: Bearer ${SUPERVISOR_TOKEN}")
    elif [[ -n "${HA_NOTIFY_TOKEN:-}" ]]; then
        auth_args=(-H "Authorization: Bearer ${HA_NOTIFY_TOKEN}")
    fi
    curl -sf -X POST "$HA_NOTIFY_URL" \
        "${auth_args[@]}" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"$title\",\"message\":\"$message\"}" \
        || true
}

cd /config
export HA_GIT_AUTOMATED=1

# Remove stale git lock files
for lock in .git/index.lock .git/refs/heads/main.lock; do
    if [ -f "$lock" ]; then
        echo "Removing stale lock: $lock"
        rm -f "$lock"
    fi
done

# Stage and commit local changes first to avoid merge conflicts
git add -A
if ! git diff --cached --quiet; then
    git commit -m "HA config pre-pull commit $(date -Iseconds)"
fi

# Fetch and merge from origin, preferring local changes on conflict
if ! git fetch origin main; then
    msg="Git pull failed: could not fetch from origin. Check network/credentials."
    echo "$msg" >&2
    ha_notify "Git Pull Failed" "$msg"
    exit 1
fi
git merge --no-edit -X ours origin/main
echo "Git pull complete: merged origin/main (local changes win on conflict)."
