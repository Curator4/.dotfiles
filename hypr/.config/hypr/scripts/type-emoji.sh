#!/usr/bin/env bash
# Insert emoji/text into the focused window.
#
# Why not plain `wtype "💀"`?
# Electron/Chromium on native Wayland ignores unicode from the virtual-keyboard
# protocol that wtype uses (Hyprland #6647). Clipboard + synthetic paste works.
#
# Paste chord depends on the focused app:
#   terminals (kitty, …) → Ctrl+Shift+V
#   everything else      → Ctrl+V  (Electron/Discord/Chromium/GTK/Qt)
#
# Hyprland send_shortcut is preferred: keys go to the client and do not re-fire
# our Super+Ctrl binds the way a raw uinput Ctrl+V would while Super is held.
# The config is Lua (hyprland.lua), so `hyprctl dispatch` evaluates its argument
# as Lua — the old `sendshortcut "CTRL,V,activewindow"` form is a parse error.
#
# Usage: type-emoji.sh <text>

set -euo pipefail

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "usage: type-emoji.sh <emoji-or-text>" >&2
  exit 2
fi

text=$1
socket="${YDOTOOL_SOCKET:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/.ydotool_socket}"
export YDOTOOL_SOCKET="$socket"

# Snapshot clipboard so we can restore after paste.
old_clip=
old_primary=
if command -v wl-paste >/dev/null 2>&1; then
  old_clip=$(wl-paste --type text 2>/dev/null || true)
  old_primary=$(wl-paste --primary --type text 2>/dev/null || true)
fi

printf '%s' "$text" | wl-copy
printf '%s' "$text" | wl-copy --primary 2>/dev/null || true

# Focused window class (best-effort).
win_class=
if command -v hyprctl >/dev/null 2>&1; then
  win_class=$(hyprctl activewindow -j 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("class",""))' 2>/dev/null \
    || true)
fi
win_class_lc=$(printf '%s' "$win_class" | tr '[:upper:]' '[:lower:]')

# Terminals typically paste with Ctrl+Shift+V; everyone else with Ctrl+V.
is_terminal=0
case "$win_class_lc" in
  kitty|alacritty|foot|footclient|wezterm|org.wezfurlong.wezterm|\
  com.mitchellh.ghostty|ghostty|gnome-terminal*|org.gnome.terminal|\
  konsole|tilix|xfce4-terminal|codium|code-oss) is_terminal=1 ;;
esac
# VS Code / Codium use Ctrl+V like Electron — leave them non-terminal.
case "$win_class_lc" in
  code|code-url-handler|code-oss|codium|dev.zed.zed|cursor) is_terminal=0 ;;
esac

# Linux keycodes: CTRL=29 SHIFT=42 V=47 INSERT=110 META=125/126
paste_ydotool_ctrl_v()     { ydotool key 29:1 47:1 47:0 29:0; }
paste_ydotool_ctrl_shift() { ydotool key 29:1 42:1 47:1 47:0 42:0 29:0; }
paste_ydotool_shift_ins()  { ydotool key 42:1 110:1 110:0 42:0; }

# hyprctl exits 0 on some Lua errors, so match the "ok" reply, not $?.
paste_sendshortcut() {
  local mods=$1 key=$2
  [[ $(hyprctl dispatch \
    "hl.dsp.send_shortcut({ mods = \"$mods\", key = \"$key\", window = \"activewindow\" })" \
    2>&1) == ok* ]]
}

do_paste() {
  if (( is_terminal )); then
    # kitty et al.
    paste_sendshortcut "CTRL SHIFT" "V" && return 0
    if command -v ydotool >/dev/null 2>&1 && [[ -S "$YDOTOOL_SOCKET" ]]; then
      sleep 0.05
      paste_ydotool_ctrl_shift 2>/dev/null && return 0
      paste_ydotool_shift_ins 2>/dev/null && return 0
    fi
  else
    # Discord / Electron / browsers / normal apps.
    # sendshortcut first — avoids Super+Ctrl+V bind re-entry while Super held.
    paste_sendshortcut "CTRL" "V" && return 0
    paste_sendshortcut "SHIFT" "Insert" && return 0
    if command -v ydotool >/dev/null 2>&1 && [[ -S "$YDOTOOL_SOCKET" ]]; then
      # Wait for physical Super/Ctrl from the hotkey to drop, then paste.
      sleep 0.12
      ydotool key 125:0 126:0 29:0 97:0 2>/dev/null || true
      paste_ydotool_ctrl_v 2>/dev/null && return 0
      paste_ydotool_shift_ins 2>/dev/null && return 0
    fi
  fi

  # Last-ditch: wtype key events, then raw unicode (works in some non-Electron).
  if command -v wtype >/dev/null 2>&1; then
    if (( is_terminal )); then
      wtype -M ctrl -M shift -k v -m shift -m ctrl 2>/dev/null && return 0
    else
      wtype -M ctrl -k v -m ctrl 2>/dev/null && return 0
      wtype -M shift -P Insert -p Insert -m shift 2>/dev/null && return 0
    fi
    wtype -- "$text" 2>/dev/null && return 0
  fi
  return 1
}

ok=0
if do_paste; then
  ok=1
fi

# Restore previous clipboard after the paste has been consumed.
(
  sleep 0.35
  if [[ -n "$old_clip" ]]; then
    printf '%s' "$old_clip" | wl-copy 2>/dev/null || true
  fi
  if [[ -n "$old_primary" ]]; then
    printf '%s' "$old_primary" | wl-copy --primary 2>/dev/null || true
  fi
) &

exit $((1 - ok))
