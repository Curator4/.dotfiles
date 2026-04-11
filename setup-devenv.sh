#!/bin/bash
set -e

# ── Dotfiles Bootstrap: Desktop Environment ──────────────
# Installs packages, stows configs, enables services.
# Safe to re-run (idempotent).

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
PKG_DIR="$DOTFILES/packages"

# ── Pre-flight ───────────────────────────────────────────

if [[ $EUID -eq 0 ]]; then
    echo "Don't run as root. The script will sudo when needed."
    exit 1
fi

sudo -v
# Keep sudo alive for the duration
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo ""
echo "================================"
echo "setting up development environment..."
echo "================================"

# ── System Update ────────────────────────────────────────

echo ""
echo ":: updating system..."
sudo pacman -Syu --noconfirm

# ── Install Packages ─────────────────────────────────────

if [[ -f "$PKG_DIR/pacman.txt" ]]; then
    echo ""
    echo ":: installing pacman packages..."
    sudo pacman -S --needed --noconfirm - < "$PKG_DIR/pacman.txt"
else
    echo "WARNING: $PKG_DIR/pacman.txt not found, skipping pacman packages"
fi

# ── AUR Helper ───────────────────────────────────────────

if ! command -v yay &>/dev/null; then
    echo ""
    echo ":: installing yay..."
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
    (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
fi

# ── AUR Packages ─────────────────────────────────────────

if [[ -f "$PKG_DIR/aur.txt" ]]; then
    echo ""
    echo ":: installing AUR packages..."
    yay -S --needed --noconfirm - < "$PKG_DIR/aur.txt"
else
    echo "WARNING: $PKG_DIR/aur.txt not found, skipping AUR packages"
fi

# ── NPM Global Packages ─────────────────────────────────

if command -v npm &>/dev/null; then
    echo ""
    echo ":: installing global npm packages..."
    npm install -g @anthropic-ai/claude-code
fi

# ── Stow Configs ─────────────────────────────────────────
# Auto-detect: every top-level directory is a stow package,
# except themes/ and packages/ which are special.

echo ""
echo ":: stowing configs..."
cd "$DOTFILES"

SKIP_DIRS="themes|packages|.git"

for dir in */; do
    pkg="${dir%/}"
    [[ "$pkg" =~ ^($SKIP_DIRS)$ ]] && continue

    echo "  stow: $pkg"
    stow --adopt --restow "$pkg" 2>/dev/null || stow --restow "$pkg"
done

# ── Enable Services ──────────────────────────────────────

echo ""
echo ":: enabling services..."

# System services
sudo systemctl enable --now NetworkManager 2>/dev/null || true
sudo systemctl enable --now bluetooth 2>/dev/null || true
sudo systemctl enable --now sshd 2>/dev/null || true
sudo systemctl enable --now tailscaled 2>/dev/null || true
sudo systemctl enable --now docker 2>/dev/null || true

# User services from list
if [[ -f "$PKG_DIR/user-services.txt" ]]; then
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue
        systemctl --user enable "$service" 2>/dev/null || true
    done < "$PKG_DIR/user-services.txt"
fi

# ── Shell ────────────────────────────────────────────────

FISH="$(command -v fish 2>/dev/null)"
if [[ -n "$FISH" && "$SHELL" != "$FISH" ]]; then
    echo ""
    echo ":: setting default shell to fish..."
    chsh -s "$FISH"
    echo "  (takes effect after logout)"
fi

# ── Done ─────────────────────────────────────────────────

echo ""
echo "================================"
echo "setup complete!"
echo ""
echo "manual steps:"
echo "  - tailscale up"
echo "  - syncthing setup"
echo "  - log out and back in for shell change"
echo "  - reboot recommended"
echo "================================"
