#!/bin/bash

# Theme initialization script - runs on startup
CURRENT_THEME_FILE="$HOME/.config/.current-theme"
SWITCHER="$HOME/.dotfiles/bin/.bin/theme-switcher.sh"
DEFAULT_THEME="frost"

# Wait a moment for Hyprland to fully initialize
sleep 2

# Read saved theme or use default
if [ -f "$CURRENT_THEME_FILE" ]; then
    THEME=$(cat "$CURRENT_THEME_FILE")
else
    THEME="$DEFAULT_THEME"
fi

# Apply the theme
"$SWITCHER" apply "$THEME"
