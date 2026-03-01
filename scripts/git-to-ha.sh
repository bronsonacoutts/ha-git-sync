#!/usr/bin/env bash
# git-to-ha.sh – Pull the latest config from GitHub into Home Assistant.
#
# Usage:
#   Called automatically by the HA shell_command.git_pull service (triggered
#   via the git_sync_pull_on_webhook automation), or run manually:
#     bash /config/scripts/git-to-ha.sh
#
# Environment variables (optional overrides):
#   HA_CONFIG_DIR  Path to the HA config directory. Default: /config
#   GIT_BRANCH     Branch to pull from.            Default: main
#
# Prerequisites:
#   - git is installed on the HA host.
#   - The config directory is a git repository with the remote configured.
#   - No uncommitted local changes that would conflict with the incoming merge.
#     Run ha-to-git.sh first if you have pending local changes.
#
# Safety:
#   This script uses --ff-only to refuse a merge that would require a merge
#   commit, protecting against unintentional overwrites. If the fast-forward
#   fails, resolve conflicts manually and re-run.

set -euo pipefail

REPO_DIR="${HA_CONFIG_DIR:-/config}"
GIT_BRANCH="${GIT_BRANCH:-main}"

cd "$REPO_DIR"

git fetch origin
git merge --ff-only "origin/$GIT_BRANCH"
echo "[ha-git-sync] Pulled from origin/$GIT_BRANCH."
