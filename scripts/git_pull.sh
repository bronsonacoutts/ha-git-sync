#!/usr/bin/env bash
set -euo pipefail

# Git Pull Script for Home Assistant Config
# Commits local changes then merges latest from origin/main (no push).
# Auto-recovers from stale locks, cleans up common junk files, and exits clearly.

HA_NOTIFY_URL="${HA_NOTIFY_URL:-}"

ha_notify() {
    local title="$1"
    local message="$2"

    if [ -z "$HA_NOTIFY_URL" ]; then
        return 0
    fi

    curl -sf -X POST "$HA_NOTIFY_URL" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"$title\",\"message\":\"$message\"}" \
        || true
}

cleanup_accidental_files() {
    while IFS= read -r -d '' f; do
        echo "Removing accidental file: $f"
        git rm --cached -- "$f" 2>/dev/null || true
        rm -f -- "$f"
    done < <(find . -mindepth 1 -maxdepth 1 -name "*:" -print0)

    for junk in .lesshst .bash_history; do
        if [ -f "$junk" ]; then
            echo "Removing junk file: $junk"
            git rm --cached -- "$junk" 2>/dev/null || true
            rm -f -- "$junk"
        fi
    done
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

# Remove common junk files created by shell mistakes or pager history.
cleanup_accidental_files

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
