#!/usr/bin/env bash
set -euo pipefail

# Git Sync Script for Home Assistant Config
# Commits local changes, merges upstream updates, and pushes safely.
# Auto-recovers from common transient errors (stale lock, rejected push).

commit_message="${1:-HA config sync $(date -Iseconds)}"
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

# Remove stale git lock files that can be left behind by aborted operations
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
    git commit -m "$commit_message"
fi

# Merge upstream with automatic conflict resolution favoring local changes
git fetch origin main
git merge --no-edit -X ours origin/main
echo "Git sync merged origin/main with -X ours (local changes win conflicts; review upstream updates if needed)."

# Push merged changes to origin — retry up to 3 times with backoff
pushed=false
for attempt in 1 2 3; do
    if git push origin main; then
        pushed=true
        break
    fi
    echo "Push attempt $attempt failed. Waiting $((attempt * 10))s before retry..." >&2
    sleep $((attempt * 10))
done

if ! $pushed; then
    msg="Git sync push failed after 3 attempts. Check credentials and network."
    echo "$msg" >&2
    ha_notify "Git Sync Failed" "$msg"
    exit 1
fi
