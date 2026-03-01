#!/usr/bin/env bash
set -euo pipefail

# Git Status Script for Home Assistant Config
# Shows the current git status of the config directory

cd /config
git status
