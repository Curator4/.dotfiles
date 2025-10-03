#!/bin/bash
set -e
sudo -v
echo ""
echo "================================"
echo "setting up development environment..."
echo "================================"

# system update
echo ""
echo "================================"
echo "updating system..."
echo "================================"

sudo pacman -Syu --noconfirm

# pacman packages
echo ""
echo "================================"
echo "installing pacman packages..."
echo "================================"

packages=(
    # system
    base-devel
    git
    stow
    sudo
    
    # network
    networkmanager
    openssh
    tailscale
    
    # desktop/wm
    hyprland
    hyprpaper
    hyprlock
    kitty
    rofi-wayland
    uwsm
    
    # audio/bluetooth
    pipewire
    pipewire-pulse
    pipewire-alsa
    wireplumber
    bluez
    bluez-utils
    pavucontrol
    
    # graphics (nvidia)
    nvidia
    nvidia-utils
    vulkan-icd-loader
    
    # sync
    syncthing
    
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
    wl-clipboard
    wl-clip-persist
    fastfetch
    playerctl
    noto-fonts-emoji
    
    # hardware
    intel-ucode  # change to amd-ucode if amd cpu

    # software
    obsidian
    firefox

    # dev
    nodejs
    npm

)
sudo pacman -S --needed --noconfirm "${packages[@]}"

# install paru (AUR helper)
echo ""
echo "================================"
echo "installing paru..."
echo "================================"

if ! command -v paru &> /dev/null; then
    echo "installing paru..."
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    cd /tmp/paru
    makepkg -si --noconfirm
    cd -
fi


# aur packages
echo ""
echo "================================"
echo "installing AUR packages..."
echo "================================"

aur_packages=(
    pacseek
    starship
    yazi
    eza
    ttf-hack-nerd
    mpvpaper
    ncspot
    cava
    mako
    waybar
    rofimoji
    wtype
)
paru -S --noconfirm "${aur_packages[@]}"

# npm global installs
echo ""
echo "================================"
echo "installing NPM packages..."
echo "================================"

npm_packages=(
    @anthropic-ai/claude-code
)
npm install -g "${npm_packages[@]}"

echo ""
echo "================================"
echo "enabling services..."
echo "================================"

# enable system services
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth
sudo systemctl enable sshd
systemctl --user enable pipewire
systemctl --user enable wireplumber


# clone dotfiles
if [ ! -d "$HOME/.dotfiles" ]; then
    echo ""
    echo "================================"
    echo "cloning dotfiles..."
    echo "================================"
    git clone https://github.com/Curator4/.dotfiles.git "$HOME/.dotfiles"
fi

# stow configs
echo ""
echo "================================"
echo "applying stow symlinks..."
echo "================================"
cd "$HOME/.dotfiles"
stow_packages=(
    hypr
    kitty
    rofi
    zsh
    htop
    nvim
    pacseek
    starship
    ncspot
    cava
    mako
    waybar
    yazi
    git
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

echo ""
echo "================================"
echo "development environment setup complete"
echo "reboot recommended"
echo "check readme for further steps"
echo "================================"
