#!/usr/bin/env bash
# Emoji picker that inserts via type-emoji.sh (Electron-safe paste).
# One row per emoji. Rofi prefix+tokenize matches word starts, so 'cat'
# hits 🐱, not 'intoxicated' on woozy. See emoji_search.py.

set -euo pipefail

here=$(dirname -- "$(readlink -f -- "$0")")
sel=$(python3 "$here/emoji_search.py" --rofi | rofi -dmenu -i \
    -matching prefix -markup-rows -p 'emoji') || true
[[ -z "${sel:-}" ]] && exit 0

# --rofi rows are "<keywords>\t<char>" (display is the glyph + name).
char=$(printf '%s' "$sel" | awk -F '\t' '{print $NF}')
[[ -z "$char" ]] && exit 0
exec "$here/type-emoji.sh" "$char"
