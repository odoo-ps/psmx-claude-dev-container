#!/usr/bin/env bash
# =============================================================================
# Odoo Dev Environment — Shared Helpers
# =============================================================================
# Source this file from any script:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/helpers.sh"
# =============================================================================

# --- Colors ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Print helpers -----------------------------------------------------------
print_section() { echo -e "\n${BOLD}${CYAN}▸ $1${NC}"; }
print_ok()      { echo -e "  ${GREEN}✓${NC} $1"; }
print_skip()    { echo -e "  ${YELLOW}→${NC} $1 (already exists, skipping)"; }
print_error()   { echo -e "  ${RED}✗${NC} $1"; }
print_info()    { echo -e "  ${BLUE}•${NC} $1"; }

# --- Spinner -----------------------------------------------------------------
# Run a command in the background and show a spinner until it finishes.
# Prints stderr output on failure.
#
# Usage: run_with_spinner "label" cmd [args...]
run_with_spinner() {
    local label="$1"; shift
    local tmpfile; tmpfile=$(mktemp)
    "$@" >"$tmpfile" 2>&1 &
    local pid=$! i=0
    local chars='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  %s %s" "${chars:$((i % 4)):1}" "$label"
        sleep 0.1
        i=$((i + 1))
    done
    wait "$pid"; local code=$?
    printf "\r%-70s\r" ""
    [ "$code" -ne 0 ] && cat "$tmpfile" >&2
    rm -f "$tmpfile"
    return "$code"
}

# --- Version -----------------------------------------------------------------
# Returns 0 (true) if the given version is a legacy Odoo version (< 18).
# Handles both X.Y and saas-X.Y formats.
#
# Usage: is_legacy "17.0" && echo "legacy"
is_legacy() {
    local version="$1"
    local major
    if [[ "$version" == saas-* ]]; then
        major=$(echo "$version" | sed 's/saas-\([0-9]*\)\..*/\1/')
    else
        major=$(echo "$version" | cut -d'.' -f1)
    fi
    [[ "$major" -lt 18 ]]
}

# --- Repositories ------------------------------------------------------------
ODOO_REPO="git@github.com:odoo/odoo.git"
ENTERPRISE_REPO="git@github.com:odoo/enterprise.git"
DESIGN_THEMES_REPO="git@github.com:odoo/design-themes.git"
UPGRADE_REPO="git@github.com:odoo/upgrade.git"
UPGRADE_UTIL_REPO="git@github.com:odoo/upgrade-util.git"

get_repo_url() {
    case "$1" in
        odoo)          echo "$ODOO_REPO" ;;
        enterprise)    echo "$ENTERPRISE_REPO" ;;
        design-themes) echo "$DESIGN_THEMES_REPO" ;;
        upgrade)       echo "$UPGRADE_REPO" ;;
        upgrade-util)  echo "$UPGRADE_UTIL_REPO" ;;
        *) return 1 ;;
    esac
}
