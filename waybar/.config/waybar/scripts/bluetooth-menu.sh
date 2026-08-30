#!/bin/bash

route_bluetooth_audio() {
    local mac="$1"
    local mac_key="${mac//:/_}"
    local card="bluez_card.$mac_key"
    local sink=""

    # BlueZ can report a connection before PipeWire has created the card and
    # A2DP sink. Poll that boundary instead of relying on a fixed sleep.
    for _ in {1..20}; do
        pactl set-card-profile "$card" a2dp-sink 2>/dev/null || true
        sink=$(pactl list short sinks |
            awk -v prefix="bluez_output.$mac_key" '$2 ~ "^" prefix { print $2; exit }')
        [ -n "$sink" ] && break
        sleep 0.25
    done

    [ -n "$sink" ] || return 1
    pactl set-default-sink "$sink" || return 1

    while read -r stream_id _; do
        [ -n "$stream_id" ] || continue
        pactl move-sink-input "$stream_id" "$sink" || true
    done < <(pactl list short sink-inputs)
}

# Keep the heredoc form: BlueZ 5.86 can fail to list paired devices through
# its non-interactive command form.
devices=$(
    bluetoothctl <<< "devices Paired" 2>/dev/null |
        sed -n 's/^Device //p' |
        awk '{
            address = $1
            $1 = ""
            sub(/^ /, "")
            print (tolower($0) ~ /bose/ ? 0 : 1) "\t" $0 " : " address
        }' |
        sort -t $'\t' -k1,1n -k2,2f |
        cut -f2-
)

if [ -z "$devices" ]; then
    notify-send "Bluetooth" "No paired devices found"
    exit 0
fi

selected=$(printf '%s\n' "$devices" | rofi-pick 'bluetooth') || exit 0
[ -n "$selected" ] || exit 0

mac=${selected##* : }

if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
    if bluetoothctl --timeout 10 disconnect "$mac"; then
        notify-send "Bluetooth" "Disconnected from $selected"
    else
        notify-send -u critical "Bluetooth" "Could not disconnect from $selected"
    fi
    exit 0
fi

bluetoothctl --timeout 20 connect "$mac"
if ! bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
    notify-send -u critical "Bluetooth" "Could not connect to $selected"
    exit 1
fi

bluetoothctl trust "$mac" >/dev/null
if route_bluetooth_audio "$mac"; then
    notify-send "Bluetooth" "Connected to $selected"
else
    notify-send -u critical "Bluetooth" \
        "Connected to $selected, but its A2DP output did not appear"
    exit 1
fi
