#!/bin/bash

# Get list of paired devices
devices=$(bluetoothctl devices | cut -d' ' -f2-)

if [ -z "$devices" ]; then
    notify-send "Bluetooth" "No paired devices found"
    exit 0
fi

# Show menu with rofi
selected=$(echo "$devices" | rofi -dmenu -i -p "Bluetooth Device")

if [ -n "$selected" ]; then
    # Extract MAC address
    mac=$(echo "$selected" | awk '{print $1}')

    # Check if already connected
    if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
        bluetoothctl disconnect "$mac"
        notify-send "Bluetooth" "Disconnected from $selected"
    else
        bluetoothctl connect "$mac"
        sleep 2
        # Set trusted and try to reconnect audio profile if needed
        bluetoothctl trust "$mac"
        pactl set-card-profile "bluez_card.${mac//:/_}" a2dp-sink 2>/dev/null
        notify-send "Bluetooth" "Connected to $selected"
    fi
fi
