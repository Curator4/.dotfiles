#!/bin/bash

THEMES_DIR="$HOME/.dotfiles/themes"
SWITCHER="$HOME/.dotfiles/bin/theme-switcher.sh"

# Build theme list with icons
THEME_LIST=""
declare -A THEME_MAP

for theme_dir in "$THEMES_DIR"/*; do
    [ -d "$theme_dir" ] || continue

    THEME_SLUG=$(basename "$theme_dir")

    if [ -f "$theme_dir/theme.json" ]; then
        ICON=$(jq -r '.icon' "$theme_dir/theme.json")
        NAME=$(jq -r '.name' "$theme_dir/theme.json")
        DISPLAY="$ICON  $NAME"
    else
        ICON=""
        NAME="$THEME_SLUG"
        DISPLAY="  $NAME"
    fi

    THEME_LIST+="$DISPLAY\n"
    THEME_MAP["$NAME"]="$THEME_SLUG"
done

# Show rofi menu
SELECTED=$(echo -e "$THEME_LIST" | rofi -dmenu -i -p "Select Theme" | sed 's/^.*  //')

if [ -n "$SELECTED" ]; then
    # Convert display name to slug
    THEME_SLUG="${THEME_MAP[$SELECTED]}"

    if [ -n "$THEME_SLUG" ]; then
        "$SWITCHER" apply "$THEME_SLUG"

        # Refresh waybar
        pkill -RTMIN+8 waybar 2>/dev/null || true
    fi
fi
