#!/bin/bash

# Reports reachability, not link state. NetworkManager already runs a connectivity
# probe -- the same one behind its +20000 route-metric penalty for offline links --
# so ask it rather than re-implement a ping.

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/waybar-network"
mkdir -p "$STATE_DIR"

connectivity=$(nmcli -t networking connectivity 2>/dev/null)
read -r gw dev < <(ip route show default | awk '{print $3, $5; exit}')

if [ -n "$dev" ]; then
    type=$(nmcli -t -f DEVICE,TYPE device status | awk -F: -v d="$dev" '$1 == d {print $2; exit}')
    addr=$(ip -4 -brief addr show "$dev" | awk '{print $3; exit}')
fi

case "$type" in
    wifi)     icon="󰖨" ;;
    ethernet) icon="󰈁" ;;
    *)        icon="󰛳" ;;
esac

# Bytes/sec since the previous poll. The counter resets when a link is
# re-established, which reads as a negative delta; show nothing rather than a lie.
rate() {
    local counter=$1 file now prev_t prev_b dt
    file="$STATE_DIR/$dev.$counter"
    now=$(< "/sys/class/net/$dev/statistics/${counter}_bytes")
    [ -r "$file" ] && read -r prev_t prev_b < "$file"
    printf '%s %s\n' "$EPOCHSECONDS" "$now" > "$file"

    dt=$(( EPOCHSECONDS - ${prev_t:-0} ))
    if [ -z "$prev_b" ] || [ "$dt" -le 0 ] || [ "$now" -lt "$prev_b" ]; then
        echo "--"
        return
    fi
    numfmt --to=iec --suffix=B/s $(( (now - prev_b) / dt ))
}

if [ -n "$dev" ]; then
    tooltip="$dev\n$addr\nGateway: $gw\n󰞒 $(rate rx) 󰞕 $(rate tx)"
else
    tooltip="No default route"
fi

case "$connectivity" in
    full)
        text="$icon Connected"
        class="full"
        ;;
    limited)
        text="$icon No internet"
        class="limited"
        ;;
    portal)
        text="$icon Portal"
        class="portal"
        ;;
    unknown)
        # Connectivity checking is off in NetworkManager.conf; all we can honestly
        # report is whether a route exists.
        if [ -n "$dev" ]; then
            text="$icon Connected?"
            class="full"
        else
            text="󰖪 Disconnected"
            class="disconnected"
        fi
        ;;
    *)
        text="󰖪 Disconnected"
        class="disconnected"
        ;;
esac

tooltip="$tooltip\nConnectivity: ${connectivity:-unknown}"

echo "{\"text\": \"${text}\", \"tooltip\": \"${tooltip}\", \"class\": \"${class}\"}"
