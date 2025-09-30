#!/bin/bash
set -e
sudo -v
echo "installing server essentials..."

packages=(
    # system
    base-devel
    git
    stow
    sudo
    
    # network
    openssh
    tailscale
    
    # shell
    zsh
    
    # utilities
    htop
    tree
    curl
    wget
    nvim
    man-db
    man-pages
    fastfetch
    
    # system
    intel-ucode  # change to amd-ucode if amd cpu
)

sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm "${packages[@]}"

# systemctl enables
sudo systemctl enable sshd

# clone dotfiles
if [ ! -d "$HOME/.dotfiles" ]; then
    echo "cloning dotfiles..."
    git clone https://github.com/Curator4/.dotfiles.git "$HOME/.dotfiles"
fi

# stow configs
echo "applying stow symlinks..."
cd "$HOME/.dotfiles"

stow_packages=(
    zsh
)

for pkg in "${stow_packages[@]}"; do
    # remove conflicting files/dirs
    stow -n "$pkg" 2>&1 | grep "existing target" | awk '{print $NF}' | while read conflict; do
        rm -rf "$HOME/$conflict"
    done
    stow "$pkg"
done

# change shell to zsh
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "changing shell to zsh..."
    chsh -s $(which zsh)
    echo "shell change will take effect after logout"
fi

echo "server setup complete!"
