#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Odoo Dev Environment — Worktree Manager
# =============================================================================
# Add or remove Odoo source worktrees (odoo, enterprise, design-themes).
#
# Usage:
#   make worktree                        ← interactive menu
#   make worktree-add VERSION=18.0       ← non-interactive add
#   make worktree-add VERSION=saas-18.4
#   make worktree-remove VERSION=18.0    ← non-interactive remove
#
#   (or invoke directly: bash worktree.sh [add|remove] [version])
# =============================================================================

# --- Paths -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODOO_BASE=~/Odoo
WORKTREES_DIR="$ODOO_BASE/Worktrees"
DOCKERFILES_DIR="$SCRIPT_DIR/dockerfiles"

REPOS=(odoo enterprise design-themes)

# --- Helpers -----------------------------------------------------------------
source "$SCRIPT_DIR/lib/helpers.sh"

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}============================================${NC}"
    echo -e "${BOLD}${BLUE}  Odoo Dev Environment — Worktree Manager${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
    echo ""
}

validate_version() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]] && [[ ! "$version" =~ ^saas-[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: invalid version format '${version}'.${NC}"
        echo -e "${RED}Expected X.Y or saas-X.Y (e.g. 18.0, saas-18.4).${NC}"
        exit 1
    fi
}

check_connectivity() {
    nc -z -w 5 github.com 22 2>/dev/null
}

# --- Add ---------------------------------------------------------------------
cmd_add() {
    local version="${1:-}"

    if [[ -z "$version" ]]; then
        echo -e "  Examples: ${CYAN}18.0${NC}, ${CYAN}19.0${NC}, ${CYAN}saas-18.4${NC}"
        echo ""
        read -rp "  Version to create: " version
        echo ""
    fi

    validate_version "$version"

    if ! check_connectivity; then
        print_error "Cannot reach GitHub (github.com:22 unreachable)"
        print_error "SSH access to GitHub is required to shallow-clone the repositories."
        exit 1
    fi

    # Clone repos shallowly
    echo ""
    echo -e "  ${BOLD}Cloning repositories for $version (--depth 1)${NC}"
    echo ""
    for repo in "${REPOS[@]}"; do
        local dest="$WORKTREES_DIR/$version/$repo"
        local repo_url
        repo_url="$(get_repo_url "$repo")"

        if [[ -d "$dest" ]]; then
            print_skip "Worktrees/$version/$repo"
        else
            echo -e "  Cloning ${BOLD}${repo}${NC} ($version)..."
            git clone --depth 1 --branch "$version" "$repo_url" "$dest"
            print_ok "Worktrees/$version/$repo"
        fi
    done

    # Copy Dockerfile
    echo ""
    local dockerfile_dest="$WORKTREES_DIR/$version/Dockerfile"
    if [[ -f "$dockerfile_dest" ]]; then
        print_skip "Worktrees/$version/Dockerfile"
    else
        if is_legacy "$version"; then
            cp "$DOCKERFILES_DIR/legacy.Dockerfile" "$dockerfile_dest"
            print_ok "Worktrees/$version/Dockerfile  ${YELLOW}(legacy — Python 3.10)${NC}"
        else
            cp "$DOCKERFILES_DIR/modern.Dockerfile" "$dockerfile_dest"
            print_ok "Worktrees/$version/Dockerfile  ${GREEN}(modern — Python 3.12)${NC}"
        fi
    fi

    # Copy .dockerignore for optimized build context
    local dockerignore_dest="$WORKTREES_DIR/$version/.dockerignore"
    if [[ -f "$dockerignore_dest" ]]; then
        print_skip "Worktrees/$version/.dockerignore"
    elif [[ -f "$DOCKERFILES_DIR/.dockerignore" ]]; then
        cp "$DOCKERFILES_DIR/.dockerignore" "$dockerignore_dest"
        print_ok "Worktrees/$version/.dockerignore"
    fi

    echo ""
    echo -e "${BOLD}${GREEN}  Worktree $version ready!${NC}"
    echo ""
    echo -e "${BOLD}  Next steps:${NC}"
    echo -e "    Build the Docker image:"
    echo -e "    ${CYAN}make build${NC}"
    echo ""
}

# --- Remove ------------------------------------------------------------------
cmd_remove() {
    local version="${1:-}"

    # List existing worktrees
    local existing=()
    if [[ -d "$WORKTREES_DIR" ]]; then
        while IFS= read -r dir; do
            existing+=("$(basename "$dir")")
        done < <(find "$WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
    fi

    if [[ ${#existing[@]} -eq 0 ]]; then
        print_error "No worktrees found in $WORKTREES_DIR"
        exit 1
    fi

    if [[ -z "$version" ]]; then
        echo -e "  Existing worktrees:"
        echo ""
        local i=1
        for v in "${existing[@]}"; do
            echo -e "    ${BOLD}$i)${NC} $v"
            ((i++))
        done
        echo ""
        read -rp "  Number to remove: " selection
        echo ""

        if [[ ! "$selection" =~ ^[0-9]+$ ]] || \
           [[ "$selection" -lt 1 ]] || \
           [[ "$selection" -gt "${#existing[@]}" ]]; then
            print_error "Invalid selection."
            exit 1
        fi

        version="${existing[$((selection - 1))]}"
    fi

    # Confirm
    echo -e "  ${YELLOW}This will permanently remove Worktrees/${version}.${NC}"
    echo ""
    read -rp "  Are you sure? [y/N]: " confirm
    echo ""
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Aborted."
        exit 0
    fi

    # Remove repositories
    echo -e "  ${BOLD}Removing repositories for $version${NC}"
    echo ""
    for repo in "${REPOS[@]}"; do
        local dest="$WORKTREES_DIR/$version/$repo"
        if [[ -d "$dest" ]]; then
            rm -rf "$dest"
            print_ok "removed Worktrees/$version/$repo"
        else
            print_skip "Worktrees/$version/$repo (not found)"
        fi
    done

    # Remove remaining files (Dockerfile, .dockerignore, etc.)
    local version_dir="$WORKTREES_DIR/$version"
    if [[ -d "$version_dir" ]]; then
        rm -rf "$version_dir"
        print_ok "removed Worktrees/$version"
    fi

    echo ""
    echo -e "${BOLD}${GREEN}  Worktree $version removed.${NC}"
    echo ""
}

# --- Main --------------------------------------------------------------------
main() {
    local cmd="${1:-}"
    local version="${2:-}"

    print_header

    if [[ -n "$cmd" ]]; then
        case "$cmd" in
            add)    cmd_add    "$version" ;;
            remove) cmd_remove "$version" ;;
            *)
                echo -e "${RED}Unknown command: $cmd${NC}"
                echo -e "Usage: make worktree-add VERSION=<version> | make worktree-remove VERSION=<version>"
                exit 1
                ;;
        esac
        return
    fi

    # Interactive menu
    echo -e "  What do you want to do?"
    echo ""
    echo -e "    ${BOLD}1)${NC} Add a worktree"
    echo -e "    ${BOLD}2)${NC} Remove a worktree"
    echo ""
    read -rp "  Choice [1/2]: " choice
    echo ""

    case "$choice" in
        1) cmd_add    "" ;;
        2) cmd_remove "" ;;
        *)
            print_error "Invalid choice."
            exit 1
            ;;
    esac
}

main "$@"
