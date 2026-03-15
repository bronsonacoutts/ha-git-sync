#!/usr/bin/env bash
set -euo pipefail

# Git Status Script for Home Assistant Config
# Shows the current git status of the config directory

REPO_DIR="${HA_CONFIG_DIR:-/config}"
cd "$REPO_DIR"
git status
