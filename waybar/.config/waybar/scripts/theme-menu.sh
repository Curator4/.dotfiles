#!/bin/bash

THEMES_DIR="$HOME/.dotfiles/themes"
SWITCHER="$HOME/.dotfiles/bin/.bin/theme-switcher.sh"

# Build theme list with icons
THEME_LIST=""
declare -A THEME_MAP

for theme_dir in "$THEMES_DIR"/*; do
    [ -d "$theme_dir" ] || continue

    THEME_SLUG=$(basename "$theme_dir")

    if [ -f "$theme_dir/theme.json" ]; then
        ICON=$(jq -r '.icon' "$theme_dir/theme.json") # ICON is still extracted but not used in DISPLAY
        NAME=$(jq -r '.name' "$theme_dir/theme.json")
        DISPLAY="$NAME"

        THEME_LIST+="$DISPLAY\n"
        THEME_MAP["$NAME"]="$THEME_SLUG"
    fi
done

# Show rofi menu (remove trailing newline)
sleep 0.1
THEME_LIST="${THEME_LIST%\\n}"
SELECTED=$(echo -e "$THEME_LIST" | rofi -dmenu -i -p "Select Theme" | sed 's/^.*  //')

if [ -n "$SELECTED" ]; then
    # Convert display name to slug
    THEME_SLUG="${THEME_MAP[$SELECTED]}"

    if [ -n "$THEME_SLUG" ]; then
        # apply runs reload_services, which restarts waybar. Since this menu is a
        # CHILD of waybar, a direct call would get killed mid-apply by that restart
        # (before .current-theme is written). Detach into a transient user scope so
        # the switcher survives the waybar restart and finishes.
        systemd-run --user --quiet --collect "$SWITCHER" apply "$THEME_SLUG"
    fi
fi
