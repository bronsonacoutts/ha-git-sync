#!/usr/bin/env bash
set -euo pipefail

CONFIG_ROOT="${1:-/config}"
SCRIPT_PATH="${CONFIG_ROOT}/scripts/fix_automation_aliases.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is not installed; skipping automation alias correction."
  exit 0
fi

if [ ! -f "$SCRIPT_PATH" ]; then
  echo "Script not found: $SCRIPT_PATH"
  exit 1
fi

python3 "$SCRIPT_PATH" "$CONFIG_ROOT"
