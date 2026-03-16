#!/usr/bin/env bash
set -euo pipefail

# Git Nightly Backup Script for Home Assistant Config
# Commits any changes, pushes to main, then creates/updates a
# date-stamped backup tag (backup/nightly-YYYY-MM-DD) for the
# rolling 30-day backup window.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${HA_CONFIG_DIR:-/config}"
cd "$REPO_DIR"

"${SCRIPT_DIR}/git_sync.sh" "HA nightly backup $(date -Iseconds)"

# Create (or overwrite) the nightly backup tag for today
TODAY=$(date +"%Y-%m-%d")
TAG="backup/nightly-${TODAY}"
git tag -f "$TAG" HEAD
git push origin "$TAG" --force
echo "Nightly backup tag set: ${TAG}"
