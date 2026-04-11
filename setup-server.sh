#!/bin/bash
set -e

# ── Dotfiles Bootstrap: Server (Minimal) ────────────────
# Lightweight setup for headless machines.

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

if [[ $EUID -eq 0 ]]; then
    echo "Don't run as root. The script will sudo when needed."
    exit 1
fi

sudo -v

echo ":: installing server essentials..."

packages=(
    base-devel git stow sudo
    openssh tailscale
    fish zsh
    htop btop tree curl wget neovim
    man-db man-pages fastfetch
    ripgrep eza
)

sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm "${packages[@]}"

# Enable services
sudo systemctl enable --now sshd 2>/dev/null || true
sudo systemctl enable --now tailscaled 2>/dev/null || true

# Clone dotfiles if needed
if [[ ! -d "$HOME/.dotfiles" ]]; then
    echo ":: cloning dotfiles..."
    git clone https://github.com/Curator4/.dotfiles.git "$HOME/.dotfiles"
fi

# Stow only what makes sense on a server
echo ":: stowing configs..."
cd "$DOTFILES"
for pkg in zsh fish git htop btop starship nvim fastfetch tmux; do
    if [[ -d "$pkg" ]]; then
        echo "  stow: $pkg"
        stow --adopt --restow "$pkg" 2>/dev/null || stow --restow "$pkg"
    fi
done

# Set shell to fish
FISH="$(command -v fish 2>/dev/null)"
if [[ -n "$FISH" && "$SHELL" != "$FISH" ]]; then
    echo ":: setting default shell to fish..."
    chsh -s "$FISH"
fi

echo ""
echo "server setup complete!"
echo "  - tailscale up"
echo "  - log out for shell change"
