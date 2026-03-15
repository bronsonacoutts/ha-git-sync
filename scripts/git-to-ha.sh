#!/usr/bin/env bash
# git-to-ha.sh - Compatibility wrapper around the hardened git_pull.sh flow.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/git_pull.sh"
