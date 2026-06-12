#!/bin/bash
# Nightly restic backup: aegis → curator-sync (SFTP over Tailscale).
# Secrets live in ~/.config/restic/{env,password} — not tracked in dotfiles.
# Password recovery copy: obsidian-vault/credentials/restic-aegis.md
set -euo pipefail

trap 'notify-send -u critical "restic backup failed" "see: journalctl --user -u restic-backup"' ERR

source "$HOME/.config/restic/env"

restic backup \
    --files-from "$HOME/.bin/restic-includes.txt" \
    --exclude-file "$HOME/.bin/restic-excludes.txt" \
    --exclude-caches

restic forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --prune
