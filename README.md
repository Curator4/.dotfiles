# dotfiles

stow-managed dotfiles for arch linux + hyprland. clone to `~/.dotfiles` and run one of the setup scripts.

## quick start

```bash
git clone https://github.com/Curator4/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./setup-devenv.sh   # desktop
./setup-server.sh   # headless
```

the setup script installs packages from `packages/`, stows all configs, enables services, and sets fish as the default shell.

## structure

each top-level directory is a stow package that maps to `~/` or `~/.config/`:

```
hypr/          → ~/.config/hypr/        (hyprland, hyprlock, hyprpaper)
kitty/         → ~/.config/kitty/
nvim/          → ~/.config/nvim/
fish/          → ~/.config/fish/
zsh/           → ~/.zshrc, ~/.zprofile
git/           → ~/.gitconfig, ~/.config/git/
rofi/          → ~/.config/rofi/
waybar/        → ~/.config/waybar/
mako/          → ~/.config/mako/
starship/      → ~/.config/starship.toml
btop/          → ~/.config/btop/
cava/          → ~/.config/cava/
eww/           → ~/.config/eww/
tmux/          → ~/.tmux.conf
pipewire/      → ~/.config/pipewire/
wireplumber/   → ~/.config/wireplumber/
systemd/       → ~/.config/systemd/user/
htop/          → ~/.config/htop/
fastfetch/     → ~/.config/fastfetch/
pacseek/       → ~/.config/pacseek/
autostart/     → ~/.config/autostart/
bin/           → ~/.bin/              (custom scripts)
claude/        → ~/.claude/           (claude code config)
```

**special directories** (not stow packages):
- `themes/` — theme presets used by theme-switcher
- `packages/` — package lists for bootstrap

## theming

**Authoring (new themes):** `theme-scaffold` + `theme-lint` — see
[`themes/README.md`](themes/README.md). Apply path is still `theme-switcher.sh`
only; scaffold never replaces the switcher.

`theme-switcher.sh apply <name>` composes each theme in `themes/` onto the live
config. it writes into the repo, because the stow symlinks mean the live config
*is* the repo — so anything it writes is gitignored (see `.gitignore`) and does
not show up as churn:

- **generated, untracked** — waybar `style.css`, `hyprlock.conf`,
  `hyprpaper.conf`, `theme-effects.conf`, mako `config`, `starship.toml`, nvim
  `colorscheme.lua`, cava `config`, kitty `theme-font.conf`. edits here are
  lost on the next switch. change `themes/<name>/` or the shared structure in
  `theme-render.sh` / `theme-switcher.sh` instead.
  Cava gradient = yellow → cyan → accent (`hue.accent` or blue). Optional mono
  font via `"font": { "mono": "…" }` in `theme.json` (default Hack Nerd Font).
- **client apps (outside stow, best-effort)** — rewritten from the same palette
  on every apply:
  - **Spotify** — `~/.config/spicetify/Themes/dotfiles/` (spicetify). One-time
    after first Spotify launch: `spicetify backup apply`.
  - **ncspot** — `[theme]` block in `~/.config/ncspot/config.toml` (other keys
    preserved).
  - **Discord** — Vencord QuickCSS or BetterDiscord `custom.css` when present;
    otherwise `~/.config/discord-theme/theme.css`. One-time: install Vencord
    (`yay -S vencord-installer-cli-bin && vencordinstallercli -install -branch stable`)
    then re-apply the theme.
  - **Firefox** — `chrome/userChrome.css` + `userContent.css` on the locked
    default-release profile; enables
    `toolkit.legacyUserProfileCustomizations.stylesheets` in `user.js`. Restart
    Firefox after the first enable.
- **tracked inputs** — everything under `themes/`, mako's `output.conf` and
  `*-categories.conf` fragments, the rofi `.rasi` palettes.
- **indirection, not rewriting** — `kitty.conf` and `hyprland.conf` reference
  `~/.config/current-theme/`, and rofi's `config.rasi` references
  `@theme "current"`. those are symlinks the switcher repoints; the tracked
  files never change.

a fresh clone has none of the generated files until `setup-devenv.sh` runs
`theme-switcher.sh apply` (or `theme-startup.sh` fires at login).

## stow basics

stow creates symlinks from the repo into your home directory. each package mirrors the target path structure.

```bash
# add a new config
cd ~/.dotfiles
mkdir -p obsidian/.config
mv ~/.config/obsidian obsidian/.config/
stow obsidian

# restow everything
cd ~/.dotfiles
for d in */; do
    [[ "$d" =~ ^(themes|packages|\.git)/ ]] && continue
    stow --restow "${d%/}"
done
```

## packages

package lists live in `packages/`:
- `pacman.txt` — native pacman packages
- `aur.txt` — AUR packages (installed via yay)
- `user-services.txt` — enabled systemd user services

update them with:
```bash
~/.bin/sync-packages.sh
```

## installation guide

### phase 1: base arch
- boot from usb
- partition: `cfdisk` — 512M EFI + rest ext4
- format: `mkfs.fat -F32` (efi), `mkfs.ext4` (root)
- mount: `/mnt`, `/mnt/boot`
- `pacstrap /mnt base linux linux-firmware sudo git networkmanager`
- `genfstab -U /mnt >> /mnt/etc/fstab`
- `arch-chroot /mnt`
- timezone, locale, hostname, root password
- bootloader (grub), enable NetworkManager
- create user with wheel group, enable sudo
- reboot

### phase 2: setup
- `sudo pacman -Syu`
- clone this repo and run `setup-devenv.sh` (or `setup-server.sh`)
- the script handles packages, stow, services, and shell

### phase 3: manual steps
- **tailscale**: `sudo tailscale up` (needs browser auth)
- **syncthing**: `systemctl --user enable syncthing`, configure at localhost:8384
