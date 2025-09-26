Phase 1: Base Arch Install





Boot Arch ISO: Download from archlinux.org, flash to USB, boot.



Partition Drive: Use fdisk or cfdisk for EFI (/dev/sdX1, ~512M, FAT32), root (/dev/sdX2, ext4), swap (~2-4GB). Example:





mkfs.fat -F32 /dev/sdX1



mkfs.ext4 /dev/sdX2



mkswap /dev/sdX3 && swapon /dev/sdX3



Mount & Install Base: mount /dev/sdX2 /mnt, mkdir /mnt/boot, mount /dev/sdX1 /mnt/boot, pacstrap /mnt base linux linux-firmware.



Fstab: genfstab -U /mnt >> /mnt/etc/fstab.



Chroot: arch-chroot /mnt.



Configure Base:





Timezone: ln -sf /usr/share/zoneinfo/Your/Region /etc/localtime, hwclock --systohc.



Locale: echo "en_US.UTF-8 UTF-8" > /etc/locale.gen, locale-gen, echo "LANG=en_US.UTF-8" > /etc/locale.conf.



Hostname: echo "myhost" > /etc/hostname, add to /etc/hosts.



Root password: passwd.



Bootloader: bootctl --path=/boot install, create /boot/loader/entries/arch.conf:

title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=PARTUUID=your-root-partuuid rw

Get PARTUUID with blkid.



Network & User:





Install: pacman -S networkmanager sudo.



Enable: systemctl enable NetworkManager.



Add user: useradd -m -G wheel username, passwd username.



Sudo: visudo, uncomment %wheel ALL=(ALL:ALL) ALL.



Exit & Reboot: exit, umount -R /mnt, reboot.

Phase 2: Core System Setup





Update System: Login as user, sudo pacman -Syu.



Install AUR Helper: Clone yay (git clone https://aur.archlinux.org/yay.git), cd yay, makepkg -si.



Essential Packages:





sudo pacman -S vim git base-devel curl wget tree htop neofetch.



Dev tools: sudo pacman -S nodejs npm python python-pip (add rust, go if needed).



Graphics Drivers: sudo pacman -S mesa (or nvidia for proprietary).



Audio & Fonts: sudo pacman -S pipewire pipewire-pulse wireplumber ttf-dejavu ttf-font-awesome.

Phase 3: GNU Stow & Dotfiles Setup





Install Stow: sudo pacman -S stow.



Create Dotfiles Repo:





mkdir ~/dotfiles && cd ~/dotfiles && git init.



Create dir structure: mkdir -p hypr waybar kitty nvim.



Store Configs:





Copy Omarchy’s good configs (e.g., hyprland.conf, waybar styles) to ~/dotfiles/hypr/, etc.



Example: cp omarchy/hypr/hyprland.conf ~/dotfiles/hypr/.



Apply Symlinks with Stow:





From ~/dotfiles, run stow hypr to symlink ~/dotfiles/hypr/hyprland.conf to ~/.config/hypr/hyprland.conf.



Repeat for waybar, kitty, nvim, etc.



Git Commit & Push:





git add ., git commit -m "Initial dotfiles".



Create GitHub repo, add remote: git remote add origin <url>, git push -u origin main.

Phase 4: Hyprland WM Setup





Install Hyprland & Tools:





sudo pacman -S hyprland waybar hyprpaper kitty wl-clipboard xdg-desktop-portal-hyprland rofi-wayland dunst grim slurp.



Login manager: sudo pacman -S sddm, sudo systemctl enable sddm.



Configure Hyprland:





Copy default: cp /usr/share/hyprland/hyprland.conf ~/dotfiles/hypr/.



Stow: cd ~/dotfiles && stow hypr.



Edit ~/dotfiles/hypr/hyprland.conf:





Keybinds: bind=SUPER,return,exec,kitty, bind=SUPER,Q,killactive, bind=SUPER,R,exec,rofi -show drun.



Workspaces: bind=SUPER,1,workspace,1 (up to 10).



Autostart: exec-once=waybar, exec-once=hyprpaper.



Copy Omarchy’s liked keybinds (e.g., tiling shortcuts) from its hyprland.conf.



Theming:





If Omarchy’s Catppuccin was good, yay -S catppuccin-gtk.



Wallpaper: Configure ~/dotfiles/hypr/hyprpaper.conf, stow, apply.



Test: Start Hyprland (Hyprland) or via SDDM. Hot-reload: hyprctl reload.

Phase 5: Browser Setup





Install Browser: sudo pacman -S firefox (or yay -S brave-bin).



Wayland Fix: In ~/dotfiles/hypr/hyprland.conf, add exec-once=firefox --ozone-platform=wayland.



Minimal Config:





Skip Omarchy’s browser bloat (e.g., forced extensions).



Manually add extensions (uBlock Origin, etc.).



Copy Omarchy’s good bookmark setups if any (check ~/.mozilla/firefox/).

Phase 6: Dev Tools & Shell





Editor: sudo pacman -S neovim or code. Copy Omarchy’s nvim plugins if good (~/dotfiles/nvim/).



Shell: sudo pacman -S zsh, install Oh My Zsh: sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)". Stow ~/.zshrc.



Dev Tools: sudo pacman -S docker docker-compose, enable user group. Add gh (GitHub CLI) via yay.



Ditch Omarchy Bloat: Avoid its extra CLI tools (e.g., bat, exa) unless you liked them.

Phase 7: Backup & Reproducibility





Automate Setup:





Create ~/dotfiles/setup.sh:

#!/bin/bash
sudo pacman -Syu hyprland waybar kitty firefox neovim stow
yay -S catppuccin-gtk
cd ~/dotfiles && stow hypr waybar kitty nvim



Stow: cp setup.sh ~/dotfiles/, git add setup.sh.



Backup: rsync -a ~/dotfiles /path/to/usb or cloud.



Git Push: git push after every config tweak.

