#!/bin/bash

# waybar volume module — follows the REAL default sink via wpctl, refreshed on
# every PipeWire change event (pactl subscribe). Event-driven, no polling.
#
# Replaces the built-in `pulseaudio` module, which latches onto a stale sink and
# stops tracking the default after Bluetooth (re)connects — showing 0% while the
# actual default sits at full volume. `@DEFAULT_AUDIO_SINK@` always resolves to
# the current default, so this can't go stale.

emit() {
    local raw vol desc
    raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) \
        || { echo '{"text": "VOL --", "tooltip": "no default sink"}'; return; }

    # raw is "Volume: 0.65" or "Volume: 0.65 [MUTED]"
    vol=$(awk '{printf "%.0f", $2 * 100}' <<< "$raw")

    # friendly name of the current default sink for the tooltip
    desc=$(pactl list sinks 2>/dev/null | awk -v s="$(pactl get-default-sink)" '
        /^\tName: /        { name = $2 }
        /^\tDescription: / { if (name == s) { print substr($0, index($0, ": ") + 2); exit } }')

    # waybar renders tooltips as Pango markup — escape the specials so device
    # names like "B&W-AR" don't break the parse and blank the whole tooltip.
    # Ampersand first, or the &/&lt;/&gt; entities get double-escaped.
    desc=${desc//&/&amp;}
    desc=${desc//</&lt;}
    desc=${desc//>/&gt;}

    if grep -q MUTED <<< "$raw"; then
        echo "{\"text\": \"VOL Muted\", \"tooltip\": \"${desc}\\nMuted (${vol}%)\"}"
    else
        echo "{\"text\": \"VOL ${vol}%\", \"tooltip\": \"${desc}\\nVolume: ${vol}%\"}"
    fi
}

emit
pactl subscribe 2>/dev/null | while read -r line; do
    # sink events = volume/mute changes; server events = default-sink switches.
    # "on sink #" deliberately excludes the noisy "on sink-input #" stream.
    case "$line" in
        *"on sink #"*|*"on server #"*) emit ;;
    esac
done
