#!/bin/sh
# Keep HUD's background exclusion bootstrap without injecting Focus context.
if [ -z "${HUD_BG:-}" ] && [ -z "${HUD_SUMMARIZING:-}" ]; then
  case "${INTER_SESSION_LABEL:-}" in
    *" channel") ;;
    *) exit 0 ;;
  esac
fi

hud_session_id=$(jq -ers '
  select(length == 1) | .[0].session_id |
  select(type == "string") |
  select(length > 0 and length <= 128) |
  select(test("^[A-Za-z0-9][A-Za-z0-9_-]*$"))
' 2>/dev/null) || exit 0

hud_marker_dir="$HOME/.local/state/hud/active"
mkdir -p "$hud_marker_dir" 2>/dev/null || exit 0
[ -L "$hud_marker_dir/$hud_session_id" ] && exit 0
# Replace the directory entry instead of following a concurrently swapped link.
hud_marker_tmp=$(mktemp "$hud_marker_dir/.hud-bg-XXXXXX" 2>/dev/null) || exit 0
trap 'rm -f -- "$hud_marker_tmp"' 0
printf 'bg' >"$hud_marker_tmp" 2>/dev/null || exit 0
mv -fT -- "$hud_marker_tmp" "$hud_marker_dir/$hud_session_id" 2>/dev/null
exit 0
