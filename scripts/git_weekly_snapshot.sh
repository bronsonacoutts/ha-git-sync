#!/usr/bin/env bash
set -euo pipefail

# Git Weekly Snapshot Script for Home Assistant Config
# Creates a tar.gz snapshot of /config, commits it to the repo, then
# creates an immutable annotated tag (snapshot/weekly-YYYY.WW) as a
# permanent reference point for the weekly full snapshot.

cd "${HA_CONFIG_DIR:-/config}"

# Create backups directory if it doesn't exist
mkdir -p backups

# Generate timestamp for snapshot filename
SNAPTS=$(date +"%Y%m%dT%H%M%S")
SNAPFILE="backups/config-snapshot-${SNAPTS}.tar.gz"

# Create compressed snapshot excluding unnecessary files
tar -czf "$SNAPFILE" \
    --exclude=".git" \
    --exclude="./backups/*.tar.gz" \
    --exclude="*.log*" \
    --exclude="home-assistant_v2.db*" \
    --exclude=".cloud" \
    --exclude=".uuid" \
    ./

/config/scripts/git_pull.sh
/config/scripts/git_push.sh "HA weekly snapshot ${SNAPTS}"

# Create a permanent, immutable annotated tag for this week's snapshot
WEEK=$(date +"%G.%V")   # ISO 8601 year.week (avoids year-boundary ambiguity)
TAG="snapshot/weekly-${WEEK}"
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Snapshot tag ${TAG} already exists — skipping (tags are immutable records)."
else
    git tag -a "$TAG" -m "Weekly snapshot ${WEEK} (${SNAPTS})"
    git push origin "$TAG"
    echo "Weekly snapshot tag created: ${TAG}"
fi
