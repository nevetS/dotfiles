#!/usr/bin/env bash
# install.sh — dotfiles installer for Linux/macOS
# Usage: ./install.sh [-y] [--skip-private] [--dry-run]

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$DOTFILES_DIR/manifest.yaml"
HOSTNAME="$(hostname -s)"
NON_INTERACTIVE=false
SKIP_PRIVATE=false
DRY_RUN=false

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()    { echo -e "${BOLD}[dotfiles]${RESET} $*"; }
ok()     { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()   { echo -e "${YELLOW}[!]${RESET} $*"; }
err()    { echo -e "${RED}[✗]${RESET} $*"; }
info()   { echo -e "${CYAN}[-]${RESET} $*"; }

# ── Args ───────────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    -y|--yes)           NON_INTERACTIVE=true ;;
    --skip-private)     SKIP_PRIVATE=true ;;
    --dry-run)          DRY_RUN=true ;;
    -h|--help)
      echo "Usage: $0 [-y] [--skip-private] [--dry-run]"
      echo "  -y, --yes         Non-interactive: skip conflicts instead of prompting"
      echo "  --skip-private    Skip rclone private config pull"
      echo "  --dry-run         Show actions without executing"
      exit 0 ;;
    *) err "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ── Dependencies ───────────────────────────────────────────────────────────────
check_deps() {
  local missing=()
  command -v python3 &>/dev/null || missing+=("python3")
  command -v rclone  &>/dev/null || missing+=("rclone")

  if [[ ${#missing[@]} -gt 0 ]]; then
    err "Missing dependencies: ${missing[*]}"
    err "Run: ./bin/install-deps.sh"
    exit 1
  fi
}

# ── Platform ───────────────────────────────────────────────────────────────────
detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

PLATFORM="$(detect_platform)"
log "Platform: $PLATFORM | Hostname: $HOSTNAME"

# ── YAML parsing (python3 stdlib only) ────────────────────────────────────────
# Outputs: "<name>|<repo_dir_or_private_dir>|<public>|<target>"
parse_manifest() {
  python3 - "$MANIFEST" "$PLATFORM" <<'EOF'
import sys, re

manifest_path = sys.argv[1]
platform      = sys.argv[2]

with open(manifest_path) as f:
    content = f.read()

# Minimal block-level YAML parser for our known manifest shape
entries = re.split(r'\n  - name:', content)
private_remote = ""
private_path   = ""

# Parse private_source block
ps_match = re.search(r'private_source:\s*\n\s+tool:\s*(\S+)\s*\n\s+remote:\s*(\S+)\s*\n\s+remote_path:\s*(\S+)', content)
if ps_match:
    private_remote = ps_match.group(2)
    private_path   = ps_match.group(3)

for entry in entries[1:]:
    name_match   = re.match(r'\s*(\S+)', entry)
    public_match = re.search(r'public:\s*(true|false)', entry)
    repo_match   = re.search(r'repo_dir:\s*(\S+)', entry)
    priv_match   = re.search(r'private_dir:\s*(\S+)', entry)

    if not name_match:
        continue

    name   = name_match.group(1)
    public = public_match.group(1) == 'true' if public_match else True

    # Find platform target
    plat_section = re.search(r'platforms:(.*?)(?=\n  -|\Z)', entry, re.DOTALL)
    if not plat_section:
        continue
    plat_block = plat_section.group(1)
    target_match = re.search(rf'{platform}:\s*(\S+)', plat_block)
    if not target_match:
        continue  # not supported on this platform

    target   = target_match.group(1)
    repo_dir = repo_match.group(1) if repo_match else ""
    priv_dir = priv_match.group(1) if priv_match else ""

    src = repo_dir if public else priv_dir
    print(f"{name}|{src}|{'public' if public else 'private'}|{target}")
EOF
}

# ── Symlink with conflict handling ────────────────────────────────────────────
expand_path() {
  # Expand ~ and $VAR in paths
  local path="$1"
  path="${path/#\~/$HOME}"
  path="$(eval echo "$path")"
  echo "$path"
}

prompt_conflict() {
  local target="$1"
  local src="$2"

  echo ""
  warn "Conflict: ${BOLD}$target${RESET} already exists"
  info "  Source:   $src"
  info "  Existing: $(file -b "$target" 2>/dev/null || echo 'unknown')"
  echo ""
  echo -e "  ${BOLD}[s]${RESET} Replace with symlink (delete existing)"
  echo -e "  ${BOLD}[b]${RESET} Backup existing, then symlink"
  echo -e "  ${BOLD}[k]${RESET} Keep existing, skip"
  echo -e "  ${BOLD}[q]${RESET} Quit installer"
  echo ""
  read -rp "  Choice [s/b/k/q]: " choice

  case "${choice,,}" in
    s) echo "replace" ;;
    b) echo "backup"  ;;
    k) echo "keep"    ;;
    q) echo "quit"    ;;
    *) warn "Invalid choice, skipping."; echo "keep" ;;
  esac
}

do_symlink() {
  local src="$1"
  local target="$2"
  local name="$3"

  if [[ ! -e "$src" ]]; then
    err "$name: source not found: $src"
    return
  fi

  local target_expanded
  target_expanded="$(expand_path "$target")"

  # Already correct symlink
  if [[ -L "$target_expanded" && "$(readlink "$target_expanded")" == "$src" ]]; then
    ok "$name: already linked"
    return
  fi

  # Conflict
  if [[ -e "$target_expanded" || -L "$target_expanded" ]]; then
    local action
    if $NON_INTERACTIVE; then
      warn "$name: conflict at $target_expanded — skipping (non-interactive)"
      return
    fi
    action="$(prompt_conflict "$target_expanded" "$src")"

    case "$action" in
      replace)
        $DRY_RUN && { info "[dry-run] rm $target_expanded && ln -sf $src $target_expanded"; return; }
        rm -rf "$target_expanded"
        ;;
      backup)
        local backup="${target_expanded}.bak.$(date +%Y%m%d%H%M%S)"
        $DRY_RUN && { info "[dry-run] mv $target_expanded $backup && ln -sf $src $target_expanded"; return; }
        mv "$target_expanded" "$backup"
        ok "$name: backed up to $backup"
        ;;
      keep)
        info "$name: kept existing, skipped"
        return
        ;;
      quit)
        log "Quitting."
        exit 0
        ;;
    esac
  fi

  $DRY_RUN && { info "[dry-run] ln -sf $src $target_expanded"; return; }

  mkdir -p "$(dirname "$target_expanded")"
  ln -sf "$src" "$target_expanded"
  ok "$name: linked $target_expanded → $src"
}

# ── Private config via rclone ──────────────────────────────────────────────────
pull_private() {
  local remote
  remote="$(python3 -c "
import re, sys
content = open('$MANIFEST').read()
m = re.search(r'remote:\s*(\S+)', content)
print(m.group(1) if m else '')
")"
  local remote_path
  remote_path="$(python3 -c "
import re
content = open('$MANIFEST').read()
m = re.search(r'remote_path:\s*(\S+)', content)
print(m.group(1) if m else '')
")"

  local private_local="$DOTFILES_DIR/.private"

  log "Pulling private config via rclone (${remote}:${remote_path}) …"
  $DRY_RUN && { info "[dry-run] rclone sync ${remote}:${remote_path} $private_local"; return; }

  mkdir -p "$private_local"
  if ! rclone sync "${remote}:${remote_path}" "$private_local" --progress; then
    err "rclone sync failed — skipping private config"
    return 1
  fi
  ok "Private config synced to $private_local"
  echo "$private_local"
}

# ── Machine-local overrides ────────────────────────────────────────────────────
pull_machine_overrides() {
  local private_local="$1"
  local machine_dir="$private_local/machines/$HOSTNAME"

  if [[ ! -d "$machine_dir" ]]; then
    warn "No machine-local overrides found for hostname '$HOSTNAME' in Drive (machines/$HOSTNAME/)"
    warn "Create $machine_dir in Drive if you want machine-specific config."
    return
  fi

  log "Applying machine-local overrides for $HOSTNAME …"

  while IFS= read -r -d '' file; do
    local rel="${file#$machine_dir/}"
    local target="$HOME/$rel"
    $DRY_RUN && { info "[dry-run] symlink $file → $target"; continue; }
    mkdir -p "$(dirname "$target")"
    do_symlink "$file" "$target" "machine:$rel"
  done < <(find "$machine_dir" -type f -print0)
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
  check_deps

  $DRY_RUN && warn "Dry-run mode — no changes will be made"

  # Pull private config
  local private_local=""
  if ! $SKIP_PRIVATE; then
    private_local="$(pull_private)" || SKIP_PRIVATE=true
  fi

  # Process manifest entries
  log "Installing dotfiles for platform: $PLATFORM"
  while IFS='|' read -r name src visibility target; do
    if [[ "$visibility" == "public" ]]; then
      local full_src="$DOTFILES_DIR/$src"
      do_symlink "$full_src" "$target" "$name"
    else
      if $SKIP_PRIVATE || [[ -z "$private_local" ]]; then
        info "$name: skipping private config (--skip-private or rclone failed)"
        continue
      fi
      local full_src="$private_local/$src"
      do_symlink "$full_src" "$target" "$name"
    fi
  done < <(parse_manifest)

  # Machine-local overrides
  if [[ -n "$private_local" ]]; then
    pull_machine_overrides "$private_local"
  fi

  log "Done."
}

main
