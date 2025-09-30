# info
intended to be pulled to home directory ~/, stores a .dotfiles hidden folder where all configuration is kept.
## stow
stow can automatically create symlinks from this repo to another location (usually ~/.config/). this allows keeping every single config file on the system in this single repo.

the individual stow commands in the setup scripts

## scripts
setup new server or development environment with the respective scripts:
- setup-server.sh
- setup-devenv.sh

## maintaining
- add config folder to ~/.dotfiles called package/.config (usually)
- mv the old config file from original location to there
- stow package (automatically creates a symlink)
- example:
```
cd ~/.dotfiles
mkdir -p obsidian/.config
mv ~/.config/obsidian obsidian/.config/
stow obsidian
```
- add package to the pacman/aur/npm installs in script
- add package to stows in script

# installation guide
## phase 1: base arch
- bootdrive
- partition with cfdisk, 512M efi
- filesystems, mkfs.fat -F32, mkfs.ext4 
- mount, mount drive /mnt, mkdir /mnt/boot, mount drive /mnt/boot
- install, pacstrap /mnt base linux linux-firmware, sudo, git, possible networkmanager
- filesystems table, genfstab -U /mnt >> /mnt/etc/fstab
- arch-chroot /mnt
- timezone, ln -sf /usr/share/zoneinfo/your/region /etc/localtime, hwclock --systohc
- locale, echo "en_US.UTF-8 UTF-8" > /etc/locale.gen, locale-gen, echo "LANG=en_US.UTF-8" > /etc/locale.conf
- hostname, echo "hostname" > /etc/hostname, maybe add to /etc/hosts
- root passwd, passwd
- bootloader, grub
- network, systemctl enable NetworkManager
- user, useradd -m -G wheel username, passwd username
- sudo, EDITOR=nvim visudo, uncomment %wheel ALL=(ALL:ALL) ALL
- exit, umount -R /mnt, reboot

## phase 2: system setup
- update system, sudo pacman -Syu
- git pull this repo https://github.com/Curator4/.dotfiles
- run install script (as user, no sudo), devenv or server. should:
    - auto install paru on dev env
    - auto install all packages from pacman/aur
    - auto install npm packages
    - enable system services
    - clone dotfiles if not done
    - stow configs from repo to config folders, usualle .config etc

## phase 3: manual setup
- tailscale
    - needs web browser auth, use github login
    - sudo systemctl enable tailscaled
    - sudo tailscale up
- syncthing
    - systemctl --user enable syncthing
    - add syncs on http://localhost:8384 with tailscale ips
