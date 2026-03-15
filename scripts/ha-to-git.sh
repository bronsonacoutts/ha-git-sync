#!/usr/bin/env bash
# ha-to-git.sh - Compatibility wrapper around the hardened git_push.sh flow.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/git_push.sh"
