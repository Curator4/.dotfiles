#!/usr/bin/env bash
# Emoji picker that inserts via type-emoji.sh (Electron-safe paste).
# rofimoji's own typer/clipboard actions use wtype or Shift+Insert alone and
# miss some terminals / Electron edge cases.

set -euo pipefail

char=$(rofimoji --action print --clipboarder wl-copy 2>/dev/null || true)
[[ -z "${char:-}" ]] && exit 0

exec ~/.config/hypr/scripts/type-emoji.sh "$char"
