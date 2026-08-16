#!/usr/bin/env bash
# Add a focus-board item. Bound to Super+U; also the target of a project header
# right-click on the panel (when given a project arg).
#
# No args (keybind):
#   1. category picker — existing focus.md projects + "＋ new category…"
#      Free-typing a name that isn't in the list is also a new category.
#   2. if "＋ new category…" was chosen → prompt for the category name
#   3. free-text prompt for the item
#   4. hud focus-add --project <slug> <text>
#
# With a project arg (header right-click): skip the picker, just prompt for text
# under that project. Empty categories don't stick on the board (a section with
# no items is dropped), so "new category" always means "first item under a new
# section" — one flow covers both.
set -euo pipefail

HUD=/home/curator/workspace/hud/hud
NEW_LABEL='＋ new category…'

trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

prompt() {
    local p="$1"
    local out
    out=$(rofi -dmenu -i -p "$p" -l 0) || return 1
    out=$(trim "$out")
    [ -n "$out" ] || return 1
    printf '%s' "$out"
}

pick_project() {
    local list sel
    # Existing sections first in board order, then the create option. Putting
    # create last keeps muscle-memory positions stable as categories come and go.
    list=$("$HUD" projects 2>/dev/null || true)
    if [ -n "$list" ]; then
        list=$(printf '%s\n%s\n' "$list" "$NEW_LABEL")
    else
        list=$NEW_LABEL
    fi
    sel=$(printf '%s\n' "$list" | rofi -dmenu -i -p 'focus · project') || return 1
    sel=$(trim "$sel")
    [ -n "$sel" ] || return 1

    if [ "$sel" = "$NEW_LABEL" ]; then
        prompt 'focus · new category' || return 1
        return 0
    fi
    # Free-typed or picked existing — both land as the project slug. focus-add
    # creates the section when it's new.
    printf '%s' "$sel"
}

project="${1:-}"
if [ -z "$project" ]; then
    project=$(pick_project) || exit 0
fi
project=$(trim "$project")
[ -n "$project" ] || exit 0

text=$(prompt "add · ${project}") || exit 0

"$HUD" focus-add --project "$project" "$text"
rm -f "$HOME/.local/state/hud/board.json"
notify-send -t 3000 "focus → ${project}" "$text" 2>/dev/null || true
