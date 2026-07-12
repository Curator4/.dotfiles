#!/bin/bash

set -euo pipefail

if [ "$#" -ne 4 ]; then
    echo "Usage: theme-render.sh <theme-dir> <waybar-css> <hyprlock-conf> <hypr-effects-conf>" >&2
    exit 2
fi

THEME_DIR="$1"
WAYBAR_OUTPUT="$2"
HYPRLOCK_OUTPUT="$3"
HYPR_EFFECTS_OUTPUT="$4"
THEME_JSON="$THEME_DIR/theme.json"
KITTY_THEME="$THEME_DIR/kitty.conf"
HYPR_THEME="$THEME_DIR/hyprland.conf"

if ! jq -e 'type == "object" and ((.terminal_only // false) == false)' \
    "$THEME_JSON" >/dev/null 2>&1; then
    echo "Invalid desktop theme: $THEME_DIR" >&2
    exit 1
fi

normalize_hex() {
    local color="${1#\#}"

    if [[ ! $color =~ ^[0-9A-Fa-f]{6}$ ]]; then
        return 1
    fi

    printf '#%s\n' "$color"
}

kitty_color() {
    local key="$1"

    awk -v key="$key" '$1 == key { print $2; exit }' "$KITTY_THEME"
}

theme_color() {
    local role="$1"
    local jq_path kitty_key color

    case "$role" in
        background) jq_path='.palette.background'; kitty_key='background' ;;
        foreground) jq_path='.palette.foreground'; kitty_key='foreground' ;;
        red) jq_path='.palette.colors.red'; kitty_key='color1' ;;
        green) jq_path='.palette.colors.green'; kitty_key='color2' ;;
        yellow) jq_path='.palette.colors.yellow'; kitty_key='color3' ;;
        blue) jq_path='.palette.colors.blue'; kitty_key='color4' ;;
        magenta) jq_path='.palette.colors.magenta'; kitty_key='color5' ;;
        cyan) jq_path='.palette.colors.cyan'; kitty_key='color6' ;;
        bright_black) jq_path='.palette.colors.bright_black'; kitty_key='color8' ;;
        *) echo "Unknown color role: $role" >&2; return 1 ;;
    esac

    color=$(jq -r "$jq_path // empty" "$THEME_JSON")
    [ -n "$color" ] || color=$(kitty_color "$kitty_key")
    normalize_hex "$color"
}

theme_accent() {
    local color

    # $accent is a literal Hyprland variable name in the source file.
    # shellcheck disable=SC2016
    color=$(sed -nE 's/^\$accent[[:space:]]*=[[:space:]]*rgb\(([0-9A-Fa-f]{6})\).*$/#\1/p' \
        "$HYPR_THEME" | head -n 1)
    [ -n "$color" ] || color=$(theme_color blue)
    normalize_hex "$color"
}

hex_to_rgba() {
    local color="${1#\#}"
    local alpha="$2"
    local red green blue

    red=$((16#${color:0:2}))
    green=$((16#${color:2:2}))
    blue=$((16#${color:4:2}))
    printf 'rgba(%d, %d, %d, %s)' "$red" "$green" "$blue" "$alpha"
}

expand_home_path() {
    case "$1" in
        \~) printf '%s\n' "$HOME" ;;
        \~/*) printf '%s/%s\n' "$HOME" "${1#\~/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

lock_wallpaper() {
    local monitor="$1"
    local reference type index wallpaper

    reference=$(jq -r --arg monitor "$monitor" '.monitors[$monitor] // empty' "$THEME_JSON")
    if [[ ! $reference =~ ^([a-z]+)\[([0-9]+)\]$ ]]; then
        echo "Invalid wallpaper reference '$reference' for $monitor" >&2
        return 1
    fi

    type="${BASH_REMATCH[1]}"
    index="${BASH_REMATCH[2]}"
    if [ "$type" = "live" ]; then
        type="static"
        index=0
    fi

    wallpaper=$(jq -r --arg type "$type" --argjson index "$index" \
        '.wallpapers[$type][$index] // empty' "$THEME_JSON")
    wallpaper=$(expand_home_path "$wallpaper")
    if [ ! -f "$wallpaper" ]; then
        echo "Missing lock-screen wallpaper for $monitor: $wallpaper" >&2
        return 1
    fi

    printf '%s\n' "$wallpaper"
}

profile=$(jq -r '.effects.profile // "calm"' "$THEME_JSON")
case "$profile" in
    calm)
        blur_size=4
        blur_passes=2
        blur_vibrancy=0.12
        blur_brightness=0.90
        surface_opacity=0.90
        ;;
    snappy)
        blur_size=3
        blur_passes=1
        blur_vibrancy=0.22
        blur_brightness=0.95
        surface_opacity=0.90
        ;;
    cinematic)
        blur_size=5
        blur_passes=2
        blur_vibrancy=0.16
        blur_brightness=0.82
        surface_opacity=0.92
        ;;
    quiet)
        blur_size=2
        blur_passes=1
        blur_vibrancy=0.0
        blur_brightness=1.0
        surface_opacity=0.94
        ;;
    *)
        echo "Unknown effect profile '$profile' in $THEME_JSON" >&2
        exit 1
        ;;
esac

background=$(theme_color background)
foreground=$(theme_color foreground)
red=$(theme_color red)
green=$(theme_color green)
yellow=$(theme_color yellow)
magenta=$(theme_color magenta)
cyan=$(theme_color cyan)
accent=$(theme_accent)

background_bar=$(hex_to_rgba "$background" "$surface_opacity")
background_tooltip=$(hex_to_rgba "$background" 0.96)
background_lock=$(hex_to_rgba "$background" 0.82)
accent_soft=$(hex_to_rgba "$accent" 0.72)
accent_lock=$(hex_to_rgba "$accent" 0.88)
foreground_soft=$(hex_to_rgba "$foreground" 0.80)
foreground_solid=$(hex_to_rgba "$foreground" 1.0)
red_solid=$(hex_to_rgba "$red" 1.0)
green_solid=$(hex_to_rgba "$green" 1.0)
magenta_soft=$(hex_to_rgba "$magenta" 0.72)
lock_dp1=$(lock_wallpaper DP-1)
lock_dp2=$(lock_wallpaper DP-2)
lock_dp3=$(lock_wallpaper DP-3)
lock_dp4=$(lock_wallpaper DP-4)

atomic_render() {
    local target="$1"
    local source="$2"

    chmod 0644 "$source"
    mv "$source" "$target"
}

mkdir -p \
    "$(dirname "$WAYBAR_OUTPUT")" \
    "$(dirname "$HYPRLOCK_OUTPUT")" \
    "$(dirname "$HYPR_EFFECTS_OUTPUT")"

waybar_tmp=$(mktemp "$(dirname "$WAYBAR_OUTPUT")/.waybar-theme.XXXXXX")
cat > "$waybar_tmp" <<EOF
/* Auto-generated by theme-render.sh. Structure is shared across all themes. */
* {
    font-family: "Hack Nerd Font";
    font-size: 14px;
}

window#waybar {
    background-color: $background_bar;
    color: $foreground;
}

#custom-hud,
#workspaces button,
#clock,
#custom-volume,
#bluetooth,
#network,
#custom-gpu,
#custom-vram,
#cpu,
#memory,
#disk,
#custom-theme {
    padding: 0 10px;
}

#workspaces button {
    color: $foreground;
}

#workspaces button.active,
#custom-hud,
#custom-gpu,
#custom-vram,
#cpu,
#custom-theme {
    color: $accent;
}

#clock {
    padding: 0 12px;
    color: $accent_soft;
}

#custom-volume {
    color: $magenta_soft;
}

#bluetooth {
    color: $cyan;
}

#network {
    color: $foreground;
}

#memory {
    color: $green;
}

#disk {
    color: $yellow;
}

tooltip {
    background: $background_tooltip;
    border: 1px solid $accent;
    border-radius: 4px;
    color: $foreground;
}

tooltip label {
    color: $foreground;
}
EOF
atomic_render "$WAYBAR_OUTPUT" "$waybar_tmp"

hyprlock_tmp=$(mktemp "$(dirname "$HYPRLOCK_OUTPUT")/.hyprlock-theme.XXXXXX")
cat > "$hyprlock_tmp" <<EOF
# Auto-generated by theme-render.sh. Layout is shared across all themes.
general {
    hide_cursor = true
}

animations {
EOF

case "$profile" in
    quiet)
        cat >> "$hyprlock_tmp" <<'EOF'
    enabled = false
EOF
        ;;
    calm)
        cat >> "$hyprlock_tmp" <<'EOF'
    enabled = true
    bezier = themeLock, 0.22, 1, 0.36, 1
    animation = fade, 1, 3.5, themeLock
EOF
        ;;
    snappy)
        cat >> "$hyprlock_tmp" <<'EOF'
    enabled = true
    bezier = themeLock, 0.2, 0.9, 0.2, 1
    animation = fade, 1, 2, themeLock
EOF
        ;;
    cinematic)
        cat >> "$hyprlock_tmp" <<'EOF'
    enabled = true
    bezier = themeLock, 0.16, 1, 0.3, 1
    animation = fade, 1, 5, themeLock
EOF
        ;;
esac

cat >> "$hyprlock_tmp" <<EOF
}

background {
    monitor = DP-1
    path = $lock_dp1
    blur_passes = $blur_passes
    blur_size = $blur_size
    brightness = $blur_brightness
    vibrancy = $blur_vibrancy
}

background {
    monitor = DP-2
    path = $lock_dp2
    blur_passes = $blur_passes
    blur_size = $blur_size
    brightness = $blur_brightness
    vibrancy = $blur_vibrancy
}

background {
    monitor = DP-3
    path = $lock_dp3
    blur_passes = $blur_passes
    blur_size = $blur_size
    brightness = $blur_brightness
    vibrancy = $blur_vibrancy
}

background {
    monitor = DP-4
    path = $lock_dp4
    blur_passes = $blur_passes
    blur_size = $blur_size
    brightness = $blur_brightness
    vibrancy = $blur_vibrancy
}

input-field {
    monitor = DP-3
    size = 300, 50
    outline_thickness = 2
    dots_size = 0.2
    dots_spacing = 0.35
    dots_center = true
    outer_color = $accent_lock
    inner_color = $background_lock
    font_color = $foreground_solid
    font_family = Hack Nerd Font
    fade_on_empty = false
    placeholder_text = <span foreground="$foreground">Enter Password...</span>
    hide_input = false
    position = 0, -120
    halign = center
    valign = center
    check_color = $green_solid
    fail_color = $red_solid
    fail_text = <span foreground="$red">Authentication failed!</span>
}

label {
    monitor = DP-3
    text = cmd[update:1000] echo "\$(date +'%H:%M')"
    color = $foreground_solid
    font_size = 120
    font_family = Hack Nerd Font
    position = 0, 300
    halign = center
    valign = center
}

label {
    monitor = DP-3
    text = cmd[update:1000] echo "\$(date +'%A, %B %d')"
    color = $foreground_soft
    font_size = 24
    font_family = Hack Nerd Font
    position = 0, 150
    halign = center
    valign = center
}

label {
    monitor = DP-3
    text = \$USER
    color = $accent_lock
    font_size = 18
    font_family = Hack Nerd Font
    position = 0, -200
    halign = center
    valign = center
}
EOF
atomic_render "$HYPRLOCK_OUTPUT" "$hyprlock_tmp"

effects_tmp=$(mktemp "$(dirname "$HYPR_EFFECTS_OUTPUT")/.hypr-effects.XXXXXX")
cat > "$effects_tmp" <<EOF
# Auto-generated by theme-render.sh from the '$profile' effect profile.
decoration {
    blur {
        enabled = true
        size = $blur_size
        passes = $blur_passes
        brightness = $blur_brightness
        vibrancy = $blur_vibrancy
    }
}

animations {
EOF

case "$profile" in
    quiet)
        cat >> "$effects_tmp" <<'EOF'
    enabled = false
EOF
        ;;
    calm)
        cat >> "$effects_tmp" <<'EOF'
    enabled = true
    bezier = themeCurve, 0.22, 1, 0.36, 1
    animation = global, 1, 5, themeCurve
    animation = border, 1, 3, themeCurve
    animation = windows, 1, 4.5, themeCurve
    animation = windowsIn, 1, 4.5, themeCurve, popin 92%
    animation = windowsOut, 1, 3, themeCurve, popin 92%
    animation = fade, 1, 3, themeCurve
    animation = layers, 1, 4, themeCurve, fade
    animation = workspaces, 1, 4, themeCurve, fade
EOF
        ;;
    snappy)
        cat >> "$effects_tmp" <<'EOF'
    enabled = true
    bezier = themeCurve, 0.2, 0.9, 0.2, 1
    animation = global, 1, 3, themeCurve
    animation = border, 1, 2, themeCurve
    animation = windows, 1, 2.8, themeCurve
    animation = windowsIn, 1, 2.8, themeCurve, popin 94%
    animation = windowsOut, 1, 2, themeCurve, popin 94%
    animation = fade, 1, 2, themeCurve
    animation = layers, 1, 2.5, themeCurve, fade
    animation = workspaces, 1, 3, themeCurve, slidefade 10%
EOF
        ;;
    cinematic)
        cat >> "$effects_tmp" <<'EOF'
    enabled = true
    bezier = themeCurve, 0.16, 1, 0.3, 1
    animation = global, 1, 6, themeCurve
    animation = border, 1, 4, themeCurve
    animation = windows, 1, 6, themeCurve
    animation = windowsIn, 1, 6, themeCurve, popin 86%
    animation = windowsOut, 1, 4, themeCurve, popin 86%
    animation = fade, 1, 5, themeCurve
    animation = layers, 1, 5, themeCurve, fade
    animation = workspaces, 1, 5, themeCurve, fade
EOF
        ;;
esac

cat >> "$effects_tmp" <<'EOF'
}
EOF
atomic_render "$HYPR_EFFECTS_OUTPUT" "$effects_tmp"
