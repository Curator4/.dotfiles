#!/bin/bash
# Desktop theme picker. Waybar click and `theme` (no args) both land here.
# Each row is "<icon>  <Name>" from theme.json; 🎲 Random is last so the
# named-theme positions stay put as the set grows.

THEMES_DIR="$HOME/.dotfiles/themes"
SWITCHER="$HOME/.dotfiles/bin/.bin/theme-switcher.sh"
RANDOM_LABEL="🎲  Random"

THEME_LIST=""
declare -A THEME_MAP

for theme_dir in "$THEMES_DIR"/*; do
    [ -d "$theme_dir" ] || continue

    THEME_SLUG=$(basename "$theme_dir")
    json="$theme_dir/theme.json"
    [ -f "$json" ] || continue

    # Terminal-only (grok-night) and drafts don't belong on a desktop apply.
    [ "$(jq -r '.terminal_only // false' "$json")" = "true" ] && continue
    [ "$(jq -r '.draft // false' "$json")" = "true" ] && continue

    NAME=$(jq -r '.name' "$json")
    ICON=$(jq -r '.icon // "•"' "$json")
    DISPLAY="$ICON  $NAME"

    THEME_LIST+="$DISPLAY\n"
    THEME_MAP["$DISPLAY"]="$THEME_SLUG"
done

THEME_LIST+="$RANDOM_LABEL"

sleep 0.1
# -l covers every desktop theme + Random; the global rasi caps at 8.
SELECTED=$(printf '%b' "$THEME_LIST" | rofi -dmenu -i -p "Select Theme" -l 14) || exit 0
[ -n "$SELECTED" ] || exit 0

# apply restarts waybar. This script is often a child of waybar, so detach
# into a transient user scope or the switcher dies mid-apply.
if [ "$SELECTED" = "$RANDOM_LABEL" ]; then
    systemd-run --user --quiet --collect "$HOME/.bin/theme" random
    exit 0
fi

THEME_SLUG="${THEME_MAP[$SELECTED]}"
[ -n "$THEME_SLUG" ] || exit 0
systemd-run --user --quiet --collect "$SWITCHER" apply "$THEME_SLUG"
