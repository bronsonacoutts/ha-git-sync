#!/usr/bin/env bash
set -euo pipefail

# ha_apply_changes.sh
# Applies merged Home Assistant config changes on the HA host.
#
# Usage:
#   /config/scripts/ha_apply_changes.sh [before_ref] [after_ref]
#
# If refs are omitted, the script compares ORIG_HEAD..HEAD, which matches the
# normal git post-merge hook case.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${HA_CONFIG_DIR:-$(git -C "${SCRIPT_DIR}/.." rev-parse --show-toplevel 2>/dev/null || echo /config)}"
export HA_CONFIG_DIR="${REPO_ROOT}"

# shellcheck source=./git_runtime.sh
. "${SCRIPT_DIR}/git_runtime.sh"

BEFORE_REF="${1:-}"
AFTER_REF="${2:-HEAD}"
HA_API_BASE_URL="${HA_API_BASE_URL:-http://localhost:8123/api}"

if [[ -z "$BEFORE_REF" ]]; then
    if git rev-parse -q --verify ORIG_HEAD >/dev/null 2>&1; then
        BEFORE_REF="ORIG_HEAD"
    else
        BEFORE_REF="HEAD~1"
    fi
fi

cd "$REPO_DIR"

call_ha_service() {
    local domain="$1"
    local service="$2"

    if command -v ha >/dev/null 2>&1; then
        ha service call "$domain" "$service" >/dev/null
        return 0
    fi

    if [[ -n "${HA_NOTIFY_TOKEN:-}" ]]; then
        curl --fail --silent --show-error \
            --connect-timeout 5 --max-time 15 --retry 2 \
            --request POST \
            --header "Authorization: Bearer ${HA_NOTIFY_TOKEN}" \
            --header "Content-Type: application/json" \
            --data '{}' \
            "${HA_API_BASE_URL}/services/${domain}/${service}" >/dev/null
        return 0
    fi

    if [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
        curl --fail --silent --show-error \
            --connect-timeout 5 --max-time 15 --retry 2 \
            --request POST \
            --header "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
            --header "Content-Type: application/json" \
            --data '{}' \
            "http://supervisor/core/api/services/${domain}/${service}" >/dev/null
        return 0
    fi

    echo "[ha-git-sync] Unable to call Home Assistant service ${domain}.${service}: no CLI or API token is available." >&2
    return 1
}

restart_home_assistant() {
    if command -v ha >/dev/null 2>&1; then
        ha core restart >/dev/null
        return 0
    fi

    if [[ -n "${HA_NOTIFY_TOKEN:-}" ]]; then
        curl --fail --silent --show-error \
            --request POST \
            --header "Authorization: Bearer ${HA_NOTIFY_TOKEN}" \
            --header "Content-Type: application/json" \
            --data '{}' \
            "${HA_API_BASE_URL}/services/homeassistant/restart" >/dev/null
        return 0
    fi

    if [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
        curl --fail --silent --show-error \
            --request POST \
            --header "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
            --header "Content-Type: application/json" \
            --data '{}' \
            "http://supervisor/core/restart" >/dev/null
        return 0
    fi

    echo "[ha-git-sync] Unable to restart Home Assistant automatically: no CLI or API token is available." >&2
    return 1
}

fail_apply_action() {
    local message="$1"
    ha_notify "HA Apply Failed" "$message"
    echo "[ha-git-sync] ${message}" >&2
    exit 1
}

ACTIONABLE_FILES=()
RESTART_FILES=()
NEEDS_CORE_RELOAD=0
NEEDS_AUTOMATIONS_RELOAD=0
NEEDS_SCRIPTS_RELOAD=0
NEEDS_SCENES_RELOAD=0

while IFS= read -r file; do
    [[ -n "$file" ]] || continue

    case "$file" in
        .github/*|docs/*|examples/*|gh-backup/*|hooks/*|pulls/*|tests/*|README.md|*.md|LICENSE|SECURITY.md|SUPPORT.md|CODE_OF_CONDUCT.md|CONTRIBUTING.md|.gitignore|.gitconfig.example|.ssh/*)
            continue
            ;;
    esac

    ACTIONABLE_FILES+=("$file")

    case "$file" in
        configuration.yaml|packages/*|custom_components/*|.storage/*|deps/*|themes/*|blueprints/*|requirements*.txt|*.py)
            RESTART_FILES+=("$file")
            ;;
        automations/*|automations.yaml)
            NEEDS_CORE_RELOAD=1
            NEEDS_AUTOMATIONS_RELOAD=1
            ;;
        scripts.yaml)
            NEEDS_SCRIPTS_RELOAD=1
            ;;
        scenes.yaml|scenes/*)
            NEEDS_SCENES_RELOAD=1
            ;;
        *)
            NEEDS_CORE_RELOAD=1
            ;;
    esac
done < <(git diff --name-only "$BEFORE_REF" "$AFTER_REF" 2>/dev/null || true)

if [[ ${#ACTIONABLE_FILES[@]} -eq 0 ]]; then
    echo "[ha-git-sync] No HA runtime changes detected in ${BEFORE_REF}..${AFTER_REF}; no reload or restart needed."
    exit 0
fi

echo "[ha-git-sync] Applying merged HA changes from ${BEFORE_REF}..${AFTER_REF}:"
printf ' - %s\n' "${ACTIONABLE_FILES[@]}"

if [[ ${#RESTART_FILES[@]} -gt 0 ]]; then
    echo "[ha-git-sync] Restart required because these paths changed:"
    printf ' - %s\n' "${RESTART_FILES[@]}"
    if restart_home_assistant; then
        echo "[ha-git-sync] Home Assistant restart requested successfully."
        exit 0
    fi

    ha_notify "HA Restart Required" "Merged changes require a Home Assistant restart, but the HA host could not trigger it automatically."
    echo "[ha-git-sync] Failed to trigger required Home Assistant restart." >&2
    exit 1
fi

if [[ "$NEEDS_CORE_RELOAD" -eq 1 ]]; then
    call_ha_service homeassistant reload_core_config || fail_apply_action "Failed to reload Home Assistant core config after merge."
fi

if [[ "$NEEDS_AUTOMATIONS_RELOAD" -eq 1 ]]; then
    call_ha_service automation reload || fail_apply_action "Failed to reload automations after merge."
fi

if [[ "$NEEDS_SCRIPTS_RELOAD" -eq 1 ]]; then
    call_ha_service script reload || fail_apply_action "Failed to reload scripts after merge."
fi

if [[ "$NEEDS_SCENES_RELOAD" -eq 1 ]]; then
    call_ha_service scene reload || fail_apply_action "Failed to reload scenes after merge."
fi

echo "[ha-git-sync] Home Assistant reload actions completed successfully."
