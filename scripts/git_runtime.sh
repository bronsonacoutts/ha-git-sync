#!/usr/bin/env bash

# Shared runtime helpers for ha-git-sync shell scripts.

REPO_DIR="${HA_CONFIG_DIR:-/config}"
GIT_BRANCH="${GIT_BRANCH:-main}"
GIT_USER_NAME="${GIT_USER_NAME:-ha-git-sync}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-ha-git-sync@localhost}"
HA_NOTIFY_URL="${HA_NOTIFY_URL:-http://localhost:8123/api/services/persistent_notification/create}"
GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"
GITHUB_API_TOKEN="${GITHUB_API_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
GITHUB_SYNC_MODE="${GITHUB_SYNC_MODE:-pull-request}"
GITHUB_SYNC_BRANCH_PREFIX="${GITHUB_SYNC_BRANCH_PREFIX:-ha-sync}"
GITHUB_SYNC_MARKER="${GITHUB_SYNC_MARKER:-[ha-sync]}"
GITHUB_SYNC_POLL_INTERVAL_SEC="${GITHUB_SYNC_POLL_INTERVAL_SEC:-15}"
GITHUB_SYNC_POLL_TIMEOUT_SEC="${GITHUB_SYNC_POLL_TIMEOUT_SEC:-900}"
HA_GIT_SYNC_HOOKS_DIR="${HA_GIT_SYNC_HOOKS_DIR:-${REPO_DIR}/hooks}"
GIT_SYNC_LOCK_DIR="${GIT_SYNC_LOCK_DIR:-${REPO_DIR}/.git/ha-git-sync.lock}"
GIT_SYNC_LOCK_WAIT_SEC="${GIT_SYNC_LOCK_WAIT_SEC:-180}"
GIT_SYNC_LOCK_STALE_SEC="${GIT_SYNC_LOCK_STALE_SEC:-600}"

ha_notify() {
    local title="$1"
    local message="$2"
    local payload
    local -a auth_args=()

    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    if [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
        auth_args=(-H "Authorization: Bearer ${SUPERVISOR_TOKEN}")
    elif [[ -n "${HA_NOTIFY_TOKEN:-}" ]]; then
        auth_args=(-H "Authorization: Bearer ${HA_NOTIFY_TOKEN}")
    else
        return 0
    fi

    payload="$(jq -n --arg title "$title" --arg message "$message" '{title:$title,message:$message}')" || return 0
    curl -sf --connect-timeout 5 --max-time 10 -X POST "$HA_NOTIFY_URL" \
        "${auth_args[@]}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
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
    cd "$REPO_DIR" || return 1
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

run_extension_hooks() {
    local phase="$1"
    local hook_dir="${HA_GIT_SYNC_HOOKS_DIR}/${phase}.d"
    local hook

    if [ ! -d "$hook_dir" ]; then
        return 0
    fi

    for hook in "$hook_dir"/*; do
        [ -f "$hook" ] || continue
        [ -x "$hook" ] || continue
        echo "Running ${phase} hook: ${hook}"
        if ! "$hook"; then
            echo "Hook failed during ${phase}: ${hook}" >&2
            return 1
        fi
    done
}

github_repo_slug() {
    local remote_url repo_slug

    remote_url="$(git remote get-url origin 2>/dev/null || true)"
    case "$remote_url" in
        git@github.com:*)
            repo_slug="${remote_url#git@github.com:}"
            ;;
        ssh://git@github.com/*)
            repo_slug="${remote_url#ssh://git@github.com/}"
            ;;
        https://github.com/*)
            repo_slug="${remote_url#https://github.com/}"
            ;;
        https://*@github.com/*)
            repo_slug="${remote_url#https://*@github.com/}"
            ;;
        http://github.com/*)
            repo_slug="${remote_url#http://github.com/}"
            ;;
        http://*@github.com/*)
            repo_slug="${remote_url#http://*@github.com/}"
            ;;
        *)
            return 1
            ;;
    esac

    repo_slug="${repo_slug%.git}"
    printf '%s\n' "$repo_slug"
}

build_sync_branch_name() {
    local raw_id normalized_id

    raw_id="${GITHUB_SYNC_CLIENT_ID:-${HOSTNAME:-home-assistant}}"
    normalized_id="$(printf '%s' "$raw_id" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
    if [ -z "$normalized_id" ]; then
        normalized_id="home-assistant"
    fi

    printf '%s/%s\n' "$GITHUB_SYNC_BRANCH_PREFIX" "$normalized_id"
}

default_sync_pr_title() {
    local client_id="${GITHUB_SYNC_CLIENT_ID:-${HOSTNAME:-home-assistant}}"

    printf '%s reconcile Home Assistant changes (%s)\n' "$GITHUB_SYNC_MARKER" "$client_id"
}

default_sync_pr_body() {
    local sync_branch="$1"
    local client_id="${GITHUB_SYNC_CLIENT_ID:-${HOSTNAME:-home-assistant}}"

    cat <<EOF
Automated Home Assistant to GitHub sync.

- Source: ${client_id}
- Base branch: ${GIT_BRANCH}
- Sync branch: ${sync_branch}

This PR was opened by ha-git-sync on the Home Assistant host after reconciling local changes with origin/${GIT_BRANCH}.
EOF
}

require_pull_request_mode_prereqs() {
    if [ -z "$GITHUB_API_TOKEN" ]; then
        echo "GITHUB_API_TOKEN or GH_TOKEN must be set when GITHUB_SYNC_MODE=pull-request." >&2
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo "python3 is required when GITHUB_SYNC_MODE=pull-request." >&2
        return 1
    fi

    if ! github_repo_slug >/dev/null 2>&1; then
        echo "Origin remote must point to github.com when GITHUB_SYNC_MODE=pull-request." >&2
        return 1
    fi
}

merge_origin_into_local() {
    local before_head

    before_head="$(git rev-parse HEAD)"

    if ! git_fetch_origin_branch; then
        return 1
    fi

    if ! git_merge_origin_branch; then
        return 1
    fi

    if [ "$before_head" != "$(git rev-parse HEAD)" ]; then
        if ! run_extension_hooks "post-gh-to-ha"; then
            return 1
        fi
    fi
}

publish_via_pull_request() {
    local failure_title="$1"
    local repo_slug sync_branch pr_title pr_body pr_json pr_number msg

    if ! require_pull_request_mode_prereqs; then
        msg="Git publish failed: GitHub pull-request mode prerequisites are not configured on the HA host."
        echo "$msg" >&2
        ha_notify "$failure_title" "$msg"
        return 1
    fi

    repo_slug="$(github_repo_slug)"
    sync_branch="$(build_sync_branch_name)"
    pr_title="$(default_sync_pr_title)"
    pr_body="$(default_sync_pr_body "$sync_branch")"

    if ! git push --force-with-lease origin "HEAD:refs/heads/${sync_branch}"; then
        msg="Git publish failed: could not push sync branch ${sync_branch}."
        echo "$msg" >&2
        ha_notify "$failure_title" "$msg"
        return 1
    fi

    if ! pr_json="$(python3 "${SCRIPT_DIR}/github_pr_sync.py" ensure-pr \
        --repo "$repo_slug" \
        --head "$sync_branch" \
        --base "$GIT_BRANCH" \
        --title "$pr_title" \
        --body "$pr_body")"; then
        msg="Git publish failed: could not create or update the GitHub sync pull request."
        echo "$msg" >&2
        ha_notify "$failure_title" "$msg"
        return 1
    fi

    pr_number="$(printf '%s' "$pr_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["number"])')"

    if ! python3 "${SCRIPT_DIR}/github_pr_sync.py" wait-for-pr \
        --repo "$repo_slug" \
        --number "$pr_number" \
        --timeout "$GITHUB_SYNC_POLL_TIMEOUT_SEC" \
        --interval "$GITHUB_SYNC_POLL_INTERVAL_SEC" >/dev/null; then
        msg="Git publish failed: sync pull request #${pr_number} did not become mergeable before the timeout. Review checks, required reviews, and rulesets."
        echo "$msg" >&2
        ha_notify "$failure_title" "$msg"
        return 1
    fi

    if ! python3 "${SCRIPT_DIR}/github_pr_sync.py" merge-pr \
        --repo "$repo_slug" \
        --number "$pr_number" \
        --method merge \
        --title "$pr_title" \
        --message "$pr_body" >/dev/null; then
        msg="Git publish failed: sync pull request #${pr_number} could not be merged into origin/${GIT_BRANCH}."
        echo "$msg" >&2
        ha_notify "$failure_title" "$msg"
        return 1
    fi

    if ! git_fetch_origin_branch; then
        msg="Git publish merged pull request #${pr_number}, but could not refresh origin/${GIT_BRANCH} locally."
        echo "$msg" >&2
        ha_notify "$failure_title" "$msg"
        return 1
    fi

    if ! git merge --ff-only "origin/$GIT_BRANCH"; then
        msg="Git publish merged pull request #${pr_number}, but local ${GIT_BRANCH} could not fast-forward to the GitHub merge commit."
        echo "$msg" >&2
        ha_notify "$failure_title" "$msg"
        return 1
    fi

    return 0
}

reconcile_and_publish() {
    local failure_title="$1"
    local commit_message="$2"
    local msg

    git_commit_if_needed "$commit_message" || true

    if ! run_extension_hooks "pre-gh-to-ha"; then
        msg="Git sync failed: a pre-gh-to-ha hook aborted the sync."
        echo "$msg" >&2
        ha_notify "$failure_title" "$msg"
        return 1
    fi
    if ! merge_origin_into_local; then
        msg="Git sync failed: could not reconcile origin/${GIT_BRANCH} into the HA working tree."
        echo "$msg" >&2
        ha_notify "$failure_title" "$msg"
        return 1
    fi

    if [ "$(git rev-list --count "origin/$GIT_BRANCH..HEAD")" -eq 0 ]; then
        echo "Git sync complete: local HA state matches origin/${GIT_BRANCH}; no GitHub publish was required."
        return 0
    fi

    if ! run_extension_hooks "pre-ha-to-gh"; then
        msg="Git sync failed: a pre-ha-to-gh hook aborted the publish."
        echo "$msg" >&2
        ha_notify "$failure_title" "$msg"
        return 1
    fi
    if [ "$GITHUB_SYNC_MODE" = "pull-request" ]; then
        if ! publish_via_pull_request "$failure_title"; then
            return 1
        fi
    else
        if ! git_push_with_retry; then
            msg="Git sync push failed after reconcile retries. Check credentials and network."
            echo "$msg" >&2
            ha_notify "$failure_title" "$msg"
            return 1
        fi
    fi

    if ! run_extension_hooks "post-ha-to-gh"; then
        msg="Git sync failed: a post-ha-to-gh hook aborted follow-up actions."
        echo "$msg" >&2
        ha_notify "$failure_title" "$msg"
        return 1
    fi
    echo "Git sync complete: local HA state and origin/${GIT_BRANCH} are reconciled."
}
