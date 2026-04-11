#!/bin/bash
# Sync installed package lists into the dotfiles repo.
# Run this periodically to keep the package lists up to date.

DOTFILES="$HOME/.dotfiles"
PKG_DIR="$DOTFILES/packages"

mkdir -p "$PKG_DIR"

echo "Syncing package lists..."

# Native pacman packages
pacman -Qqen | sort > "$PKG_DIR/pacman.txt"
echo "  pacman: $(wc -l < "$PKG_DIR/pacman.txt") packages"

# AUR / foreign packages
pacman -Qqem | sort > "$PKG_DIR/aur.txt"
echo "  aur:    $(wc -l < "$PKG_DIR/aur.txt") packages"

# Enabled user services
systemctl --user list-unit-files --state=enabled --no-pager --no-legend \
    | awk '{print $1}' | sort > "$PKG_DIR/user-services.txt"
echo "  user services: $(wc -l < "$PKG_DIR/user-services.txt") enabled"

# Show what changed
echo ""
if git -C "$DOTFILES" diff --stat -- packages/; then
    echo "Run 'git add packages/ && git commit' to save changes."
else
    echo "Package lists are up to date."
fi
