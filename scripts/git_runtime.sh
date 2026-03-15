#!/usr/bin/env bash

# Shared runtime helpers for ha-git-sync shell scripts.

REPO_DIR="${HA_CONFIG_DIR:-/config}"
GIT_BRANCH="${GIT_BRANCH:-main}"
GIT_USER_NAME="${GIT_USER_NAME:-ha-git-sync}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-ha-git-sync@localhost}"
HA_NOTIFY_URL="${HA_NOTIFY_URL:-}"
GIT_SYNC_LOCK_DIR="${GIT_SYNC_LOCK_DIR:-${REPO_DIR}/.git/ha-git-sync.lock}"
GIT_SYNC_LOCK_WAIT_SEC="${GIT_SYNC_LOCK_WAIT_SEC:-180}"
GIT_SYNC_LOCK_STALE_SEC="${GIT_SYNC_LOCK_STALE_SEC:-600}"

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

remove_stale_git_locks() {
    for lock in .git/index.lock ".git/refs/heads/${GIT_BRANCH}.lock"; do
        if [ -f "$lock" ]; then
            echo "Removing stale lock: $lock"
            rm -f "$lock"
        fi
    done
}

_lock_mtime() {
    local path="$1"
    stat -c %Y "$path" 2>/dev/null || stat -f %m "$path" 2>/dev/null
}

release_sync_lock() {
    if [ "${HA_GIT_SYNC_LOCK_HELD:-0}" != "1" ]; then
        return 0
    fi
    rmdir "$GIT_SYNC_LOCK_DIR" 2>/dev/null || true
    HA_GIT_SYNC_LOCK_HELD=0
    export HA_GIT_SYNC_LOCK_HELD
}

acquire_sync_lock() {
    local start now mtime age elapsed

    if [ "${HA_GIT_SYNC_LOCK_HELD:-0}" = "1" ]; then
        return 0
    fi

    start=$(date +%s)
    while ! mkdir "$GIT_SYNC_LOCK_DIR" 2>/dev/null; do
        now=$(date +%s)
        if [ -d "$GIT_SYNC_LOCK_DIR" ]; then
            mtime=$(_lock_mtime "$GIT_SYNC_LOCK_DIR" || echo 0)
            age=$((now - mtime))
            if [ "$age" -ge "$GIT_SYNC_LOCK_STALE_SEC" ]; then
                echo "Removing stale sync lock: $GIT_SYNC_LOCK_DIR"
                rm -rf "$GIT_SYNC_LOCK_DIR" 2>/dev/null || true
                continue
            fi
        fi

        elapsed=$((now - start))
        if [ "$elapsed" -ge "$GIT_SYNC_LOCK_WAIT_SEC" ]; then
            echo "Timed out waiting for sync lock: $GIT_SYNC_LOCK_DIR" >&2
            ha_notify "Git Sync Delayed" "Timed out waiting for the ha-git-sync lock after ${elapsed}s."
            return 1
        fi
        sleep 2
    done

    HA_GIT_SYNC_LOCK_HELD=1
    export HA_GIT_SYNC_LOCK_HELD
    trap release_sync_lock EXIT INT TERM
}

prepare_repo() {
    cd "$REPO_DIR"
    export HA_GIT_AUTOMATED=1
    acquire_sync_lock
    remove_stale_git_locks
    cleanup_accidental_files
}

git_commit_if_needed() {
    local commit_message="$1"

    git add -A
    if git diff --cached --quiet; then
        return 1
    fi

    git -c user.name="$GIT_USER_NAME" \
        -c user.email="$GIT_USER_EMAIL" \
        commit -m "$commit_message"
}

git_fetch_origin_branch() {
    git fetch origin "$GIT_BRANCH"
}

git_merge_origin_branch() {
    local file

    if git merge --no-edit -X ours "origin/$GIT_BRANCH"; then
        return 0
    fi

    if git diff --name-only --diff-filter=U | grep -q .; then
        echo "Auto-resolving remaining merge conflicts in favor of the local HA copy..."
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            git checkout --ours -- "$file" 2>/dev/null || true
            git add -- "$file"
        done < <(git diff --name-only --diff-filter=U)

        git -c user.name="$GIT_USER_NAME" \
            -c user.email="$GIT_USER_EMAIL" \
            commit --no-edit
        return 0
    fi

    return 1
}

git_push_with_retry() {
    local attempt

    for attempt in 1 2 3; do
        if git push origin "$GIT_BRANCH"; then
            return 0
        fi

        echo "Push attempt ${attempt} failed. Reconciling with origin/${GIT_BRANCH} before retry..." >&2

        if ! git_fetch_origin_branch; then
            sleep $((attempt * 5))
            continue
        fi

        if ! git_merge_origin_branch; then
            echo "Automatic reconcile with origin/${GIT_BRANCH} failed." >&2
            return 1
        fi

        sleep $((attempt * 5))
    done

    return 1
}
