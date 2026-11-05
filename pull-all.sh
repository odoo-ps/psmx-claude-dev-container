#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Odoo Dev Environment — Pull All
# =============================================================================
# For each shallow-cloned repo (--depth 1), fetch the latest commit of its
# respective version branch and update HEAD to FETCH_HEAD.
#
# Usage:
#   make pull-all
#   (or directly: bash pull-all.sh)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKTREES_DIR="${ODOO_WORKTREE_PATH:-$HOME/Odoo/Worktrees}"
REPOS=(odoo enterprise design-themes)

source "$SCRIPT_DIR/lib/helpers.sh"

# --- Update repositories -----------------------------------------------------
print_section "Updating repositories (--depth 1)"
echo ""

if [ ! -d "$WORKTREES_DIR" ]; then
    print_info "No repositories found in $WORKTREES_DIR"
    echo ""
    exit 0
fi

found=0
for version_dir in "$WORKTREES_DIR"/*/; do
    [ -d "$version_dir" ] || continue
    found=1
    version="$(basename "$version_dir")"
    echo -e "  ${BOLD}$version${NC}"
    for repo in "${REPOS[@]}"; do
        dest="$WORKTREES_DIR/$version/$repo"
        [ -d "$dest" ] || continue
        if run_with_spinner "Updating $repo ($version)..." bash -c "
            git -C '$dest' fetch --depth 1 origin '$version' && \
            git -C '$dest' reset --hard FETCH_HEAD && \
            git -C '$dest' clean -fd
        "; then
            print_ok "$repo"
        else
            print_error "$repo (update failed — check if branch $version exists and SSH access)"
        fi
    done
    echo ""
done

[ "$found" = "1" ] || { print_info "No repositories found."; echo ""; }
