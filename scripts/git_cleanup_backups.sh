#!/usr/bin/env bash
set -euo pipefail

# Git Backup Cleanup Script for Home Assistant Config
# Prunes backup/nightly-* tags older than 30 days.
# Weekly snapshot/weekly-* tags are NEVER pruned — they are permanent records.
# Runs locally and pushes deletions to origin.

KEEP_DAYS="${1:-30}"

cd /config

ha_notify() {
    local title="$1"
    local message="$2"
    local -a auth_args=()
    if [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
        auth_args=(-H "Authorization: Bearer ${SUPERVISOR_TOKEN}")
    elif [[ -n "${HA_NOTIFY_TOKEN:-}" ]]; then
        auth_args=(-H "Authorization: Bearer ${HA_NOTIFY_TOKEN}")
    fi
    curl -sf -X POST "http://localhost:8123/api/services/persistent_notification/create" \
        "${auth_args[@]}" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"$title\",\"message\":\"$message\"}" \
        || true
}

echo "Pruning backup/nightly-* tags older than ${KEEP_DAYS} days..."

# Fetch tags from origin so the local list is current
git fetch --tags --prune --prune-tags origin 2>/dev/null || git fetch --tags origin

CUTOFF=$(date -d "${KEEP_DAYS} days ago" +"%Y-%m-%d" 2>/dev/null \
    || date -v -"${KEEP_DAYS}"d +"%Y-%m-%d")  # GNU / BSD fallback

deleted=0
while IFS= read -r tag; do
    # Tag name format: backup/nightly-YYYY-MM-DD
    tag_date="${tag#backup/nightly-}"
    if [[ "$tag_date" < "$CUTOFF" ]]; then
        echo "Deleting old tag: ${tag} (${tag_date} < ${CUTOFF})"
        git tag -d "$tag" 2>/dev/null || true
        git push origin --delete "$tag" 2>/dev/null || true
        deleted=$((deleted + 1))
    fi
done < <(git tag -l "backup/nightly-*" | sort)

echo "Backup cleanup complete: ${deleted} tag(s) removed (kept last ${KEEP_DAYS} days)."
ha_notify "Git Backup Cleanup" "Removed ${deleted} nightly backup tag(s) older than ${KEEP_DAYS} days."
