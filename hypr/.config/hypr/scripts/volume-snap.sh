#!/usr/bin/env bash
# Step volume to the next multiple of 5 in the given direction.
# Usage: volume-snap.sh up|down
# Bound from Hyprland keybinds — wpctl's relative 5%+/- drifts off the grid
# once volume has been set to a non-multiple (mixer UI, apps, etc.).
set -euo pipefail

dir="${1:-}"
case "$dir" in
	up | down) ;;
	*)
		echo "usage: $0 up|down" >&2
		exit 2
		;;
esac

# "Volume: 0.35" or "Volume: 0.35 [MUTED]"
cur=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d", $2 * 100 + 0.5}')

if [ "$dir" = "up" ]; then
	new=$(((cur / 5 + 1) * 5))
	[ "$new" -gt 100 ] && new=100
else
	if [ $((cur % 5)) -eq 0 ]; then
		new=$((cur - 5))
	else
		new=$(((cur / 5) * 5))
	fi
	[ "$new" -lt 0 ] && new=0
fi

wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "${new}%"
