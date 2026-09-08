#!/bin/bash
# Shared wallpaper helpers for theme-switcher.sh and theme-render.sh.
#
# Optional theme.json block:
#   "wallpaper_schedule": {
#     "DP-3": {
#       "morning": "static[1]",
#       "evening": "static[0]",
#       "morning_start": "07:00",
#       "evening_start": "19:00"
#     }
#   }
# monitors.<name> is the fallback when no schedule exists (and for evening
# if evening is omitted). Default window is 07:00 ≤ t < 19:00 = morning.

hhmm_to_minutes() {
    local t="$1"
    printf '%s\n' $((10#${t%%:*} * 60 + 10#${t##*:}))
}

# Print the type[index] ref that should be active on $monitor right now.
resolve_monitor_ref() {
    local theme_json="$1"
    local monitor="$2"
    local ref morning evening morning_start evening_start now now_m start_m end_m

    ref=$(jq -r --arg m "$monitor" '.monitors[$m] // empty' "$theme_json")
    morning=$(jq -r --arg m "$monitor" '.wallpaper_schedule[$m].morning // empty' "$theme_json")
    if [ -z "$morning" ]; then
        printf '%s\n' "$ref"
        return 0
    fi
    evening=$(jq -r --arg m "$monitor" '.wallpaper_schedule[$m].evening // empty' "$theme_json")
    [ -n "$evening" ] || evening="$ref"
    morning_start=$(jq -r --arg m "$monitor" '.wallpaper_schedule[$m].morning_start // "07:00"' "$theme_json")
    evening_start=$(jq -r --arg m "$monitor" '.wallpaper_schedule[$m].evening_start // "19:00"' "$theme_json")
    now=$(date +%H:%M)
    now_m=$(hhmm_to_minutes "$now")
    start_m=$(hhmm_to_minutes "$morning_start")
    end_m=$(hhmm_to_minutes "$evening_start")
    if [ "$now_m" -ge "$start_m" ] && [ "$now_m" -lt "$end_m" ]; then
        printf '%s\n' "$morning"
    else
        printf '%s\n' "$evening"
    fi
}
