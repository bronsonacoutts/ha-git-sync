#!/usr/bin/env bash
set -euo pipefail

# Git Nightly Backup Script for Home Assistant Config
# Commits any changes, pushes to main, then creates/updates a
# date-stamped backup tag (backup/nightly-YYYY-MM-DD) for the
# rolling 30-day backup window.

cd "${HA_CONFIG_DIR:-/config}"
export HA_GIT_AUTOMATED=1

/config/scripts/git_pull.sh
/config/scripts/git_push.sh "HA nightly backup $(date -Iseconds)"

TODAY=$(date +"%Y-%m-%d")
TAG="backup/nightly-${TODAY}"
git tag -f "$TAG" HEAD
git push origin "$TAG" --force
echo "[ha-git-sync] Nightly backup tag: ${TAG}"
