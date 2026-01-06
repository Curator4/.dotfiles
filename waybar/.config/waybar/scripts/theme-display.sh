#!/bin/bash

CURRENT_THEME_FILE="$HOME/.config/.current-theme"
THEMES_DIR="$HOME/.dotfiles/themes"

# Get current theme
if [ -f "$CURRENT_THEME_FILE" ]; then
    CURRENT=$(cat "$CURRENT_THEME_FILE")
else
    CURRENT="osaka-jade"
fi

THEME_DIR="$THEMES_DIR/$CURRENT"

# Read theme metadata
if [ -f "$THEME_DIR/theme.json" ]; then
    ICON=$(jq -r '.icon' "$THEME_DIR/theme.json")
    NAME=$(jq -r '.name' "$THEME_DIR/theme.json")
    echo "{\"text\": \"$ICON\", \"tooltip\": \"Current theme: $NAME\"}"
else
    # Fallback if no theme.json
    echo "{\"text\": \"\", \"tooltip\": \"Current theme: $CURRENT\"}"
fi
