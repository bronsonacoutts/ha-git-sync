#!/usr/bin/env bash
set -euo pipefail

# Git Push Script for Home Assistant Config
# Commits local changes and pushes to origin/main.
# Auto-recovers from stale locks; retries push up to 3 times with backoff.

cd /config
export HA_GIT_AUTOMATED=1

# Remove stale git lock files
for lock in .git/index.lock .git/refs/heads/main.lock; do
    if [ -f "$lock" ]; then
        echo "Removing stale lock: $lock"
        rm -f "$lock"
    fi
done

# Stage and commit any remaining local changes
git add -A
if ! git diff --cached --quiet; then
    git commit -m "HA config update $(date -Iseconds)"
fi

# Push with retry
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
    msg="Git push failed after 3 attempts. Check credentials and network."
    echo "$msg" >&2
    exit 1
fi
echo "Git push complete: changes pushed to origin/main."
