#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Odoo Dev Environment — Initial Machine Setup
# =============================================================================
# This script sets up the ~/Odoo/ directory structure, shallow-clones Odoo
# source repos (--depth 1) for selected versions, and installs upgrade tools.
#
# Usage: bash setup.sh
# Safe to re-run: existing directories and repos are skipped.
# =============================================================================

# --- Paths -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODOO_BASE=~/Odoo
DATA_DIR="$ODOO_BASE/.data"
WORKTREES_DIR="$ODOO_BASE/Worktrees"
CUSTOMERS_DIR="$ODOO_BASE/Customers"
REPOS_DIR="$ODOO_BASE/Repos"
DUMPS_DIR="$ODOO_BASE/Dumps"
UPGRADE_DIR="$ODOO_BASE/Upgrade"
DOCKERFILES_DIR="$SCRIPT_DIR/dockerfiles"

# --- Helpers -----------------------------------------------------------------
source "$SCRIPT_DIR/lib/helpers.sh"

# --- Versions ----------------------------------------------------------------
LEGACY_VERSIONS=("16.0" "17.0")
MODERN_VERSIONS=("18.0" "19.0")
ALL_VERSIONS=("${LEGACY_VERSIONS[@]}" "${MODERN_VERSIONS[@]}")

print_header() {
  echo ""
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo -e "${BOLD}${BLUE}  Odoo Dev Environment — Machine Setup${NC}"
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo ""
}

# --- 1. Prerequisites --------------------------------------------------------
check_prerequisites() {
  print_section "Checking prerequisites"
  local failed=0

  if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    print_ok "Docker Desktop is running"
  else
    print_error "Docker Desktop is not running — start it and re-run this script"
    failed=1
  fi

  if command -v git &>/dev/null; then
    print_ok "Git is installed ($(git --version | awk '{print $3}'))"
  else
    print_error "Git is not installed"
    failed=1
  fi

  local ssh_output
  ssh_output=$(ssh -T git@github.com 2>&1 || true)
  if echo "$ssh_output" | grep -q "successfully authenticated"; then
    print_ok "SSH access to GitHub is configured"
  else
    print_error "SSH access to GitHub failed — run: ssh -T git@github.com"
    failed=1
  fi

  if [ $failed -ne 0 ]; then
    echo ""
    echo -e "${RED}Fix the errors above and re-run the script.${NC}"
    exit 1
  fi
}

# --- 2. Directory structure --------------------------------------------------
create_directories() {
  print_section "Creating directory structure"

  local dirs=(
    "$DATA_DIR"
    "$WORKTREES_DIR"
    "$CUSTOMERS_DIR"
    "$REPOS_DIR"
    "$DUMPS_DIR"
    "$UPGRADE_DIR"
  )

  for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
      print_skip "${dir/#$HOME/~}"
    else
      mkdir -p "$dir"
      print_ok "Created ${dir/#$HOME/~}"
    fi
  done
}

# --- 3. Version selection ----------------------------------------------------
select_versions() {
  print_section "Select versions to install"
  echo ""
  echo -e "  Available versions:"
  echo ""

  local i=1
  for version in "${ALL_VERSIONS[@]}"; do
    if is_legacy "$version"; then
      echo -e "    ${BOLD}$i)${NC} $version  ${YELLOW}(Python 3.10 — legacy)${NC}"
    else
      echo -e "    ${BOLD}$i)${NC} $version  ${GREEN}(Python 3.12)${NC}"
    fi
    ((i++))
  done

  echo ""
  echo -e "    ${BOLD}a)${NC} All versions"
  echo ""
  read -rp "  Enter numbers separated by spaces (e.g. 3 4) or 'a' for all: " selection
  echo ""

  SELECTED_VERSIONS=()

  if [[ "$selection" == "a" || "$selection" == "all" ]]; then
    SELECTED_VERSIONS=("${ALL_VERSIONS[@]}")
  else
    for num in $selection; do
      if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#ALL_VERSIONS[@]}" ]; then
        SELECTED_VERSIONS+=("${ALL_VERSIONS[$((num - 1))]}")
      else
        print_error "Invalid selection: $num — skipped"
      fi
    done
  fi

  if [ ${#SELECTED_VERSIONS[@]} -eq 0 ]; then
    print_error "No valid versions selected. Exiting."
    exit 1
  fi

  echo -e "  Installing: ${BOLD}${SELECTED_VERSIONS[*]}${NC}"
}

# --- 4. Worktrees / Repositories ---------------------------------------------
create_worktrees() {
  print_section "Cloning repositories (--depth 1)"

  for version in "${SELECTED_VERSIONS[@]}"; do
    echo ""
    echo -e "  ${BOLD}$version${NC}"

    for repo in odoo enterprise design-themes; do
      local dest="$WORKTREES_DIR/$version/$repo"
      local repo_url
      repo_url="$(get_repo_url "$repo")"

      if [ -d "$dest" ]; then
        print_skip "  Worktrees/$version/$repo"
      else
        echo -e "  Cloning ${BOLD}${repo}${NC} ($version)..."
        git clone --depth 1 --branch "$version" "$repo_url" "$dest"
        print_ok "  Worktrees/$version/$repo"
      fi
    done

    local dockerfile_dest="$WORKTREES_DIR/$version/Dockerfile"
    if [ -f "$dockerfile_dest" ]; then
      print_skip "  Worktrees/$version/Dockerfile"
    else
      if is_legacy "$version"; then
        cp "$DOCKERFILES_DIR/legacy.Dockerfile" "$dockerfile_dest"
      else
        cp "$DOCKERFILES_DIR/modern.Dockerfile" "$dockerfile_dest"
      fi
      print_ok "  Worktrees/$version/Dockerfile"
    fi

    local dockerignore_dest="$WORKTREES_DIR/$version/.dockerignore"
    if [ -f "$dockerignore_dest" ]; then
      print_skip "  Worktrees/$version/.dockerignore"
    elif [ -f "$DOCKERFILES_DIR/.dockerignore" ]; then
      cp "$DOCKERFILES_DIR/.dockerignore" "$dockerignore_dest"
      print_ok "  Worktrees/$version/.dockerignore"
    fi
  done
}

# --- 5. Upgrade tools --------------------------------------------------------
setup_upgrade_tools() {
  print_section "Cloning upgrade tools (--depth 1)"

  if [ -d "$UPGRADE_DIR/upgrade" ]; then
    print_skip "Upgrade/upgrade"
  else
    echo -e "  Cloning ${BOLD}upgrade${NC}..."
    git clone --depth 1 "$UPGRADE_REPO" "$UPGRADE_DIR/upgrade"
    print_ok "Upgrade/upgrade"
  fi

  if [ -d "$UPGRADE_DIR/upgrade-util" ]; then
    print_skip "Upgrade/upgrade-util"
  else
    echo -e "  Cloning ${BOLD}upgrade-util${NC}..."
    git clone --depth 1 "$UPGRADE_UTIL_REPO" "$UPGRADE_DIR/upgrade-util"
    print_ok "Upgrade/upgrade-util"
  fi
}

# --- 6. Docker images --------------------------------------------------------
# Docker images are built per-client via 'make build' from the client folder.
# Building here would be context-dependent and could cause 'check-image' to
# fail if the Docker context changes between setup and 'make start'.
# See WORKFLOWS.md section 6 for details.

# --- 7. Summary --------------------------------------------------------------
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}============================================${NC}"
  echo -e "${BOLD}${GREEN}  Setup complete!${NC}"
  echo -e "${BOLD}${GREEN}============================================${NC}"
  echo ""
  echo -e "${BOLD}Installed versions:${NC}"
  for version in "${SELECTED_VERSIONS[@]}"; do
    echo -e "  ${GREEN}✓${NC} $version"
  done
  echo ""
  echo -e "${BOLD}Next steps:${NC}"
  echo -e "  1. Clone this template for your client:"
  echo -e "     ${CYAN}git clone git@github.com:odoo-ps/psmx-claude-dev-container.git ~/Odoo/Customers/<client>${NC}"
  echo -e "  2. Configure the environment:"
  echo -e "     ${CYAN}cp .env.example .env && \$EDITOR .env${NC}"
  echo -e "  3. Build the Docker image (first time per version):"
  echo -e "     ${CYAN}make build${NC}"
  echo -e "  4. Start the environment:"
  echo -e "     ${CYAN}make start${NC}"
  echo ""
  echo -e "  See ${BOLD}WORKFLOWS.md${NC} for common day-to-day scenarios."
  echo ""
}

# --- Main --------------------------------------------------------------------
main() {
  print_header
  check_prerequisites
  create_directories
  select_versions
  create_worktrees
  setup_upgrade_tools
  print_summary
}

main "$@"
