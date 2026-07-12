#!/bin/bash

CURRENT_THEME_FILE="${THEME_CURRENT_THEME_FILE:-$HOME/.config/.current-theme}"
SWITCHER="${THEME_SWITCHER:-$HOME/.dotfiles/bin/.bin/theme-switcher.sh}"
THEMES_DIR="${THEME_THEMES_DIR:-$HOME/.dotfiles/themes}"
BOOT_ID_FILE="${THEME_BOOT_ID_FILE:-/proc/sys/kernel/random/boot_id}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/theme-switcher"
BOOT_STATE_FILE="$STATE_DIR/boot-id"
DEFAULT_THEME="jade"

is_desktop_theme() {
    local theme_json="$THEMES_DIR/$1/theme.json"

    [ -f "$theme_json" ] &&
        jq -e 'type == "object" and ((.terminal_only // false) == false)' \
            "$theme_json" >/dev/null 2>&1
}

list_desktop_themes() {
    local theme

    for theme in "$THEMES_DIR"/*; do
        [ -d "$theme" ] || continue
        is_desktop_theme "$(basename "$theme")" || continue
        basename "$theme"
    done
}

choose_boot_theme() {
    local current_theme="$1"
    local theme
    local -a themes candidates

    mapfile -t themes < <(list_desktop_themes)
    [ "${#themes[@]}" -gt 0 ] || return 1

    for theme in "${themes[@]}"; do
        if [ "${#themes[@]}" -eq 1 ] || [ "$theme" != "$current_theme" ]; then
            candidates+=("$theme")
        fi
    done

    printf '%s\n' "${candidates[@]}" | shuf -n 1
}

sleep "${THEME_STARTUP_DELAY:-2}"

current_theme=""
[ -f "$CURRENT_THEME_FILE" ] && current_theme=$(cat "$CURRENT_THEME_FILE")

boot_id=""
[ -r "$BOOT_ID_FILE" ] && boot_id=$(cat "$BOOT_ID_FILE")

last_boot_id=""
[ -f "$BOOT_STATE_FILE" ] && last_boot_id=$(cat "$BOOT_STATE_FILE")

if [ -n "$boot_id" ] && [ "$boot_id" != "$last_boot_id" ]; then
    if boot_theme=$(choose_boot_theme "$current_theme"); then
        if "$SWITCHER" apply "$boot_theme"; then
            mkdir -p "$STATE_DIR"
            printf '%s\n' "$boot_id" > "$BOOT_STATE_FILE.tmp"
            mv "$BOOT_STATE_FILE.tmp" "$BOOT_STATE_FILE"
            exit 0
        fi
    fi
fi

if ! is_desktop_theme "$current_theme"; then
    current_theme="$DEFAULT_THEME"
fi

"$SWITCHER" apply "$current_theme"
