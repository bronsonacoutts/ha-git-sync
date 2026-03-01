#!/usr/bin/env bash
set -euo pipefail

# Git Nightly Backup Script for Home Assistant Config
# Commits any changes, pushes to main, then creates/updates a
# date-stamped backup tag (backup/nightly-YYYY-MM-DD) for the
# rolling 30-day backup window.

cd /config

/config/scripts/git_sync.sh "HA nightly backup $(date -Iseconds)"

# Create (or overwrite) the nightly backup tag for today
TODAY=$(date +"%Y-%m-%d")
TAG="backup/nightly-${TODAY}"
git tag -f "$TAG" HEAD
git push origin "$TAG" --force
echo "Nightly backup tag set: ${TAG}"
