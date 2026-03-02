#!/usr/bin/env bash
set -euo pipefail

# migrate_automations.sh
# Thin wrapper around scripts/migrate_automations.py.
# Adds stable, deterministic ids to any HA automation that is missing one.
# Safe to run multiple times (idempotent).
#
# Usage:
#   /config/scripts/migrate_automations.sh [config_root]
#   /config/scripts/migrate_automations.sh /config

CONFIG_ROOT="${1:-/config}"
SCRIPT_PATH="${CONFIG_ROOT}/scripts/migrate_automations.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is not installed; cannot run automation ID migration."
  exit 1
fi

if [ ! -f "$SCRIPT_PATH" ]; then
  echo "Script not found: $SCRIPT_PATH"
  exit 1
fi

python3 "$SCRIPT_PATH" "$CONFIG_ROOT"
