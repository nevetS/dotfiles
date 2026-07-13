#!/usr/bin/env bash
# bin/install-deps.sh — install dotfiles dependencies on Linux/macOS
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}[✓]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; }
err()  { echo -e "${RED}[✗]${RESET} $*"; exit 1; }

OS="$(uname -s)"

# ── python3 ───────────────────────────────────────────────────────────────────
if command -v python3 &>/dev/null; then
    ok "python3 $(python3 --version 2>&1 | awk '{print $2}')"
else
    warn "python3 not found"
    case "$OS" in
        Darwin) brew install python3 ;;
        Linux)
            if command -v apt-get &>/dev/null; then sudo apt-get install -y python3
            elif command -v dnf &>/dev/null;     then sudo dnf install -y python3
            elif command -v pacman &>/dev/null;   then sudo pacman -S --noconfirm python
            else err "Cannot install python3: no known package manager found"
            fi ;;
    esac
    ok "python3 installed"
fi

# ── rclone ────────────────────────────────────────────────────────────────────
if command -v rclone &>/dev/null; then
    ok "rclone $(rclone --version 2>&1 | head -1)"
else
    warn "rclone not found — installing"
    case "$OS" in
        Darwin)
            if command -v brew &>/dev/null; then brew install rclone
            else curl https://rclone.org/install.sh | sudo bash
            fi ;;
        Linux)
            curl https://rclone.org/install.sh | sudo bash ;;
    esac
    ok "rclone installed"
fi

# ── rclone remote check ───────────────────────────────────────────────────────
echo ""
if rclone listremotes 2>/dev/null | grep -q "gdrive:"; then
    ok "rclone remote 'gdrive' already configured"
else
    warn "rclone remote 'gdrive' not configured"
    echo "  Run: rclone config"
    echo "  Create a new remote named 'gdrive' of type 'drive' (Google Drive)"
    echo "  See: https://rclone.org/drive/"
fi

echo ""
ok "All dependencies satisfied. You can now run ./install.sh"
