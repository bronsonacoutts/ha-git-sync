#!/usr/bin/env bash
set -euo pipefail

# Git Sync Script for Home Assistant Config
# Reconciles GitHub changes into HA, then publishes any remaining HA changes
# back to GitHub using the configured sync mode.

commit_message="${1:-HA config sync $(date -Iseconds)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./git_runtime.sh
. "${SCRIPT_DIR}/git_runtime.sh"

prepare_repo

if ! reconcile_and_publish "Git Sync Failed" "$commit_message"; then
    exit 1
fi

echo "Git sync complete: HA and GitHub are reconciled."
