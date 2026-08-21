#!/bin/bash

THEMES_DIR="$HOME/.dotfiles/themes"
CURRENT_THEME_FILE="$HOME/.config/.current-theme"
DOTFILES="$HOME/.dotfiles"
THEME_RENDERER="$DOTFILES/bin/.bin/theme-render.sh"

render_theme_surfaces() {
    local theme_name="$1"
    local theme_dir="$THEMES_DIR/$theme_name"

    if [ ! -d "$theme_dir" ]; then
        echo "Error: Theme '$theme_name' not found"
        return 1
    fi

    if ! "$THEME_RENDERER" \
        "$theme_dir" \
        "$DOTFILES/waybar/.config/waybar/style.css" \
        "$DOTFILES/hypr/.config/hypr/hyprlock.conf" \
        "$DOTFILES/hypr/.config/hypr/theme-effects.lua"; then
        echo "Error: Failed to render shared theme surfaces"
        return 1
    fi

    generate_codexbar_css "$theme_dir"
}

# Point the stable indirection links at the chosen theme.
#
# Configs that only ever named a theme (kitty's include, Hyprland's source)
# used to get sed-rewritten in place on every switch, which dirtied the repo —
# those files are stow symlinks, so editing the live config *is* editing
# tracked content. They now reference a fixed path and this moves the link
# instead. ~/.config/current-theme is not in any stow package. Rofi no longer
# uses a per-theme link; theme-render writes current.rasi from the palette.
link_current_theme() {
    local theme_name="$1"
    local theme_dir="$THEMES_DIR/$theme_name"

    # -n so we replace the link itself rather than writing inside the directory
    # it already points at.
    ln -sfn "$theme_dir" "$HOME/.config/current-theme"
    echo "  ✓ Linked ~/.config/current-theme -> themes/$theme_name"
}

# Function to apply theme
apply_theme() {
    THEME_NAME="$1"
    THEME_DIR="$THEMES_DIR/$THEME_NAME"

    if [ ! -d "$THEME_DIR" ]; then
        echo "Error: Theme '$THEME_NAME' not found"
        exit 1
    fi

    # Terminal-only themes ship just theme.json + kitty.conf, for theme-term.sh to
    # recolor a single window. Applying one desktop-wide points theme.lua's dofile
    # at a hyprland.lua that does not exist, which is a hard config error rather
    # than the undefined-variable warnings hyprlang used to give.
    if [ "$(jq -r '.terminal_only // false' "$THEME_DIR/theme.json" 2>/dev/null)" = "true" ]; then
        echo "Error: '$THEME_NAME' is a terminal-only theme; use theme-term.sh instead"
        exit 1
    fi

    echo "Applying theme: $THEME_NAME"

    render_theme_surfaces "$THEME_NAME" || return 1

    # 1-2. Kitty and Hyprland follow ~/.config/current-theme; moving the link is
    # the whole update. Must happen before reload_services.
    link_current_theme "$THEME_NAME"

    # 3. Waybar was generated from the shared structure
    echo "  ✓ Rendered shared Waybar CSS"

    # 4. Copy Mako config + append output pin + shared timer + household category rules
    if [ -f "$THEME_DIR/mako.conf" ]; then
        cp "$THEME_DIR/mako.conf" "$DOTFILES/mako/.config/mako/config"
        # output.conf is global options — must precede the [category=...] snippets
        OUTPUT_PIN="$DOTFILES/mako/.config/mako/output.conf"
        [ -f "$OUTPUT_PIN" ] && cat "$OUTPUT_PIN" >> "$DOTFILES/mako/.config/mako/config"
        TIMER_CATS="$DOTFILES/mako/.config/mako/timer-categories.conf"
        [ -f "$TIMER_CATS" ] && cat "$TIMER_CATS" >> "$DOTFILES/mako/.config/mako/config"
        HOUSEHOLD_CATS="$DOTFILES/mako/.config/mako/household-categories.conf"
        [ -f "$HOUSEHOLD_CATS" ] && cat "$HOUSEHOLD_CATS" >> "$DOTFILES/mako/.config/mako/config"
        echo "  ✓ Updated Mako config"
    fi

    # 5. Hyprlock and Hyprland effects were rendered from the shared structure
    echo "  ✓ Rendered shared Hyprlock and effect profiles"

    # 6. Rofi was generated from the shared card layout in theme-render

    # 6.5. Update Starship prompt
    if [ -f "$THEME_DIR/starship.toml" ]; then
        cp "$THEME_DIR/starship.toml" "$DOTFILES/starship/.config/starship.toml"
        echo "  ✓ Updated Starship prompt"
    fi

    # 6.6. Switch Neovim colorscheme
    switch_nvim_colorscheme "$THEME_DIR"

    # 6.7. Switch Obsidian theme
    OBSIDIAN_APPEARANCE="$HOME/obsidian-vault/.obsidian/appearance.json"
    if [ -f "$OBSIDIAN_APPEARANCE" ] && [ -f "$THEME_DIR/theme.json" ]; then
        OBSIDIAN_THEME=$(jq -r '.obsidian.cssTheme // empty' "$THEME_DIR/theme.json")
        OBSIDIAN_BASE=$(jq -r '.obsidian.base // "obsidian"' "$THEME_DIR/theme.json")
        if [ -n "$OBSIDIAN_THEME" ]; then
            jq --arg theme "$OBSIDIAN_THEME" --arg base "$OBSIDIAN_BASE" \
                '.cssTheme = $theme | .theme = $base' "$OBSIDIAN_APPEARANCE" > /tmp/obsidian_appearance.json \
                && mv /tmp/obsidian_appearance.json "$OBSIDIAN_APPEARANCE"
            echo "  ✓ Updated Obsidian theme"
        fi
    fi

    # 6.8. Generate wiremix theme from palette
    generate_wiremix_config "$THEME_DIR"

    # 6.9. Generate cava colors from palette
    generate_cava_config "$THEME_DIR"

    # 6.10. Optional mono font swap (theme.json font.mono → kitty/waybar/mako)
    apply_theme_font "$THEME_DIR"

    # 6.11. Client apps (best-effort; missing tools never fail apply)
    generate_codex_theme "$THEME_DIR"
    generate_spicetify_theme "$THEME_DIR"
    generate_ncspot_theme "$THEME_DIR"
    generate_discord_theme "$THEME_DIR"
    generate_firefox_theme "$THEME_DIR"

    # 7. Update Hyprpaper wallpapers
    update_wallpapers "$THEME_DIR"

    # 9. Reload services
    reload_services "$THEME_NAME"

    # 9. Save current theme
    echo "$THEME_NAME" > "$CURRENT_THEME_FILE"

    # 10. Send notification
    if [ -f "$THEME_DIR/theme.json" ]; then
        THEME_DISPLAY_NAME=$(jq -r '.name' "$THEME_DIR/theme.json")
        THEME_ICON=$(jq -r '.icon' "$THEME_DIR/theme.json")
        notify-send "Theme Switcher" "$THEME_ICON Theme applied: $THEME_DISPLAY_NAME" -i preferences-desktop-theme
    fi

    echo "Theme '$THEME_NAME' applied successfully!"
    echo ""
    echo "Note: For existing terminal sessions to pick up the new Starship prompt,"
    echo "run 'reload-shell' or start a new terminal."
}

# Function to switch Neovim colorscheme
switch_nvim_colorscheme() {
    THEME_DIR="$1"

    if [ ! -f "$THEME_DIR/theme.json" ]; then
        echo "  ! Warning: theme.json not found, skipping nvim colorscheme update"
        return
    fi

    # Extract nvim colorscheme from theme.json
    NVIM_COLORSCHEME=$(jq -r '.nvim.colorscheme // empty' "$THEME_DIR/theme.json")
    NVIM_VARIANT=$(jq -r '.nvim.variant // ""' "$THEME_DIR/theme.json")
    NVIM_BACKGROUND=$(jq -r '.nvim.background // "dark"' "$THEME_DIR/theme.json")

    if [ -z "$NVIM_COLORSCHEME" ]; then
        echo "  ! Warning: No nvim colorscheme defined in theme.json"
        return
    fi

    # Update colorscheme config file
    COLORSCHEME_FILE="$HOME/.dotfiles/nvim/.config/nvim/lua/config/colorscheme.lua"
    cat > "$COLORSCHEME_FILE" << EOF
-- Auto-generated by theme-switcher.sh
-- DO NOT EDIT MANUALLY - changes will be overwritten
return {
    colorscheme = "$NVIM_COLORSCHEME",
    variant = "$NVIM_VARIANT",
    background = "$NVIM_BACKGROUND",
}
EOF

    echo "  ✓ Updated Neovim colorscheme config"
}

# Function to announce theme switch via TTS (disabled — was Qwen, needs SoVITS rewrite)
# announce_theme() { ... }

# Resolve a palette role from theme.json, then kitty.conf. Prints #RRGGBB or empty.
theme_palette_color() {
    local theme_dir="$1"
    local role="$2" # background | foreground | black | white | red | green | yellow | blue | magenta | cyan | bright_black | selection_bg | accent
    local color=""

    case "$role" in
        accent)
            color=$(jq -r '.hue.accent // empty' "$theme_dir/theme.json" 2>/dev/null)
            [ -n "$color" ] || color=$(theme_palette_color "$theme_dir" blue)
            printf '%s\n' "$color"
            return
            ;;
        background)
            color=$(jq -r '.palette.background // empty' "$theme_dir/theme.json" 2>/dev/null)
            [ -n "$color" ] || color=$(awk '$1 == "background" { print $2; exit }' "$theme_dir/kitty.conf" 2>/dev/null)
            ;;
        foreground)
            color=$(jq -r '.palette.foreground // empty' "$theme_dir/theme.json" 2>/dev/null)
            [ -n "$color" ] || color=$(awk '$1 == "foreground" { print $2; exit }' "$theme_dir/kitty.conf" 2>/dev/null)
            ;;
        black)
            color=$(jq -r '.palette.colors.black // empty' "$theme_dir/theme.json" 2>/dev/null)
            [ -n "$color" ] || color=$(awk '$1 == "color0" { print $2; exit }' "$theme_dir/kitty.conf" 2>/dev/null)
            ;;
        white)
            color=$(jq -r '.palette.colors.white // empty' "$theme_dir/theme.json" 2>/dev/null)
            [ -n "$color" ] || color=$(awk '$1 == "color7" { print $2; exit }' "$theme_dir/kitty.conf" 2>/dev/null)
            ;;
        red)
            color=$(jq -r '.palette.colors.red // empty' "$theme_dir/theme.json" 2>/dev/null)
            [ -n "$color" ] || color=$(awk '$1 == "color1" { print $2; exit }' "$theme_dir/kitty.conf" 2>/dev/null)
            ;;
        green)
            color=$(jq -r '.palette.colors.green // empty' "$theme_dir/theme.json" 2>/dev/null)
            [ -n "$color" ] || color=$(awk '$1 == "color2" { print $2; exit }' "$theme_dir/kitty.conf" 2>/dev/null)
            ;;
        yellow)
            color=$(jq -r '.palette.colors.yellow // empty' "$theme_dir/theme.json" 2>/dev/null)
            [ -n "$color" ] || color=$(awk '$1 == "color3" { print $2; exit }' "$theme_dir/kitty.conf" 2>/dev/null)
            ;;
        blue)
            color=$(jq -r '.palette.colors.blue // empty' "$theme_dir/theme.json" 2>/dev/null)
            [ -n "$color" ] || color=$(awk '$1 == "color4" { print $2; exit }' "$theme_dir/kitty.conf" 2>/dev/null)
            ;;
        magenta)
            color=$(jq -r '.palette.colors.magenta // empty' "$theme_dir/theme.json" 2>/dev/null)
            [ -n "$color" ] || color=$(awk '$1 == "color5" { print $2; exit }' "$theme_dir/kitty.conf" 2>/dev/null)
            ;;
        cyan)
            color=$(jq -r '.palette.colors.cyan // empty' "$theme_dir/theme.json" 2>/dev/null)
            [ -n "$color" ] || color=$(awk '$1 == "color6" { print $2; exit }' "$theme_dir/kitty.conf" 2>/dev/null)
            ;;
        bright_black)
            color=$(jq -r '.palette.colors.bright_black // empty' "$theme_dir/theme.json" 2>/dev/null)
            [ -n "$color" ] || color=$(awk '$1 == "color8" { print $2; exit }' "$theme_dir/kitty.conf" 2>/dev/null)
            ;;
        selection_bg)
            color=$(jq -r '.palette.selection_bg // empty' "$theme_dir/theme.json" 2>/dev/null)
            [ -n "$color" ] || color=$(theme_palette_color "$theme_dir" bright_black)
            printf '%s\n' "$color"
            return
            ;;
        *)
            return 1
            ;;
    esac

    # Normalize: ensure leading #
    case "$color" in
        \#??????) printf '%s\n' "$color" ;;
        [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
            printf '#%s\n' "$color"
            ;;
    esac
}

# Strip leading # from a hex color (spicetify wants RRGGBB).
hex_nohash() {
    local c="$1"
    printf '%s\n' "${c#\#}"
}

# true if theme is dark (nvim.background, else relative luminance of background).
theme_is_dark() {
    local theme_dir="$1"
    local nvim_bg
    nvim_bg=$(jq -r '.nvim.background // empty' "$theme_dir/theme.json" 2>/dev/null)
    case "$nvim_bg" in
        dark) return 0 ;;
        light) return 1 ;;
    esac

    local bg r g b lum
    bg=$(theme_palette_color "$theme_dir" background)
    bg=$(hex_nohash "$bg")
    [ ${#bg} -eq 6 ] || return 0 # default dark when unknown
    r=$((16#${bg:0:2}))
    g=$((16#${bg:2:2}))
    b=$((16#${bg:4:2}))
    # integer approximation of 0.2126R + 0.7152G + 0.0722B (scaled by 10000)
    lum=$(( (2126 * r + 7152 * g + 722 * b) / 10000 ))
    [ "$lum" -lt 128 ]
}

# Function to generate wiremix config from theme palette
generate_wiremix_config() {
    THEME_DIR="$1"

    WIREMIX_DIR="$HOME/.config/wiremix"
    mkdir -p "$WIREMIX_DIR"

    local fg cyan blue green red bright_black
    fg=$(theme_palette_color "$THEME_DIR" foreground)
    cyan=$(theme_palette_color "$THEME_DIR" cyan)
    blue=$(theme_palette_color "$THEME_DIR" blue)
    green=$(theme_palette_color "$THEME_DIR" green)
    red=$(theme_palette_color "$THEME_DIR" red)
    bright_black=$(theme_palette_color "$THEME_DIR" bright_black)

    if [ -z "$fg" ] || [ -z "$cyan" ]; then
        return
    fi

    cat > "$WIREMIX_DIR/wiremix.toml" << EOF
# Auto-generated by theme-switcher.sh
# DO NOT EDIT MANUALLY - changes will be overwritten
mouse = true
peaks = "auto"
theme = "active"

[themes.active]
selector = { fg = "$cyan" }
tab = { fg = "$bright_black" }
tab_selected = { fg = "$cyan" }
tab_marker = { fg = "$cyan" }
list_more = { fg = "$bright_black" }
node_title = { fg = "$fg" }
node_target = { fg = "$bright_black" }
volume = { fg = "$fg" }
volume_empty = { fg = "$bright_black" }
volume_filled = { fg = "$blue" }
meter_inactive = { fg = "$bright_black" }
meter_active = { fg = "$green" }
meter_overload = { fg = "$red" }
meter_center_inactive = { fg = "$bright_black" }
meter_center_active = { fg = "$green" }
config_device = { fg = "$fg" }
config_profile = { fg = "$bright_black" }
dropdown_icon = { fg = "$bright_black" }
dropdown_border = { fg = "$bright_black" }
dropdown_item = { fg = "$fg" }
dropdown_selected = { fg = "$cyan", add_modifier = "REVERSED" }
dropdown_more = { fg = "$bright_black" }
help_border = { fg = "$bright_black" }
help_item = { fg = "$fg" }
help_more = { fg = "$bright_black" }
EOF

    echo "  ✓ Updated wiremix theme"
}

# Write cava config colors from the theme palette. Structure (framerate, input,
# smoothing) is fixed here so a theme switch only recolors — SIGUSR2 reloads
# colors without restarting the audio path. Config is generated + gitignored.
generate_cava_config() {
    THEME_DIR="$1"
    local CAVA_CONFIG="$DOTFILES/cava/.config/cava/config"
    mkdir -p "$(dirname "$CAVA_CONFIG")"

    # Bottom → top gradient: warm mid-energy → cool body → accent peak.
    local c1 c2 c3
    c1=$(theme_palette_color "$THEME_DIR" yellow)
    c2=$(theme_palette_color "$THEME_DIR" cyan)
    [ -n "$c2" ] || c2=$(theme_palette_color "$THEME_DIR" green)
    c3=$(theme_palette_color "$THEME_DIR" accent)
    [ -n "$c1" ] || c1=$(theme_palette_color "$THEME_DIR" red)
    [ -n "$c3" ] || c3=$(theme_palette_color "$THEME_DIR" magenta)

    if [ -z "$c1" ] || [ -z "$c2" ] || [ -z "$c3" ]; then
        echo "  ! Warning: could not resolve cava gradient colors, leaving config as-is"
        return
    fi

    local theme_slug
    theme_slug=$(basename "$THEME_DIR")

    cat > "$CAVA_CONFIG" << EOF
# Auto-generated by theme-switcher.sh from theme '$theme_slug'
# DO NOT EDIT MANUALLY - changes will be overwritten on the next theme switch.
# Non-color knobs live in this generator; palette stops come from theme.json /
# kitty.conf (yellow → cyan → accent).

[general]
framerate = 60
bars = 0
autosens = 1
sensitivity = 100

[input]
method = pulse
source = auto

[output]
method = ncurses
channels = stereo
mono_option = average

[color]
gradient = 1
gradient_count = 3
gradient_color_1 = '$c1'
gradient_color_2 = '$c2'
gradient_color_3 = '$c3'

[smoothing]
monstercat = 1
waves = 0
gravity = 100
integral = 77
EOF

    echo "  ✓ Updated cava colors ($c1 → $c2 → $c3)"
}

# Optional mono font from theme.json (.font.mono). Default stays Hack Nerd Font.
# Kitty: tiny include (gitignored). Waybar/mako/eww: post-process live configs
# after theme-render / mako copy so switches never dirty per-theme source files.
apply_theme_font() {
    THEME_DIR="$1"
    local font mono_default="Hack Nerd Font"
    font=$(jq -r '.font.mono // empty' "$THEME_DIR/theme.json" 2>/dev/null)
    [ -n "$font" ] || font="$mono_default"

    # 1. Kitty include
    local FONT_CONF="$DOTFILES/kitty/.config/kitty/theme-font.conf"
    cat > "$FONT_CONF" << EOF
# Auto-generated by theme-switcher.sh — font for theme $(basename "$THEME_DIR")
# DO NOT EDIT MANUALLY
font_family $font
bold_font auto
italic_font auto
bold_italic_font auto
EOF

    # 2. Waybar CSS (generated by theme-render; rewrite family only)
    local WAYBAR_STYLE="$DOTFILES/waybar/.config/waybar/style.css"
    if [ -f "$WAYBAR_STYLE" ]; then
        sed -i -E "s|font-family: \"[^\"]*\";|font-family: \"${font}\";|g"             "$WAYBAR_STYLE"
    fi

    # 3. Mako live config (copied from theme dir; preserve size suffix)
    local MAKO_CONF="$DOTFILES/mako/.config/mako/config"
    if [ -f "$MAKO_CONF" ]; then
        sed -i -E "s|^font=.*[[:space:]]([0-9]+)$|font=${font} \1|" "$MAKO_CONF"
    fi

    # 4. eww theme-colors.scss — $hud-font consumed by eww.scss
    local EWW_COLORS="${XDG_CONFIG_HOME:-$HOME/.config}/eww/theme-colors.scss"
    if [ -f "$EWW_COLORS" ]; then
        # Drop any prior $hud-font line, then append the current one.
        grep -v '^\$hud-font:' "$EWW_COLORS" > "${EWW_COLORS}.tmp" \
            && mv "${EWW_COLORS}.tmp" "$EWW_COLORS"
        printf '%s\n' "\$hud-font: \"${font}\";" >> "$EWW_COLORS"
    fi

    echo "  ✓ Theme mono font → $font (kitty/waybar/mako/eww)"
}

# Codex CLI: render a deliberately restrained syntax theme from the active
# desktop palette. Codex keeps its own truecolor syntax palette, so without
# this adapter it falls back to a bundled theme that clashes with Kitty.
generate_codex_theme() {
    local theme_dir="$1"
    local codex_home_dir="${CODEX_HOME:-$HOME/.codex}"
    local codex_theme_dir="$codex_home_dir/themes"
    local theme_out="$codex_theme_dir/desktop.tmTheme"
    local tmp_theme
    local bg fg accent muted red green selection

    if ! command -v codex &>/dev/null && [ ! -d "$codex_home_dir" ]; then
        echo "  ! Codex: not installed, skipped"
        return
    fi

    bg=$(theme_palette_color "$theme_dir" background)
    fg=$(theme_palette_color "$theme_dir" foreground)
    accent=$(jq -r '.codex.accent // empty' "$theme_dir/theme.json" 2>/dev/null)
    [ -n "$accent" ] || accent=$(theme_palette_color "$theme_dir" cyan)
    [ -n "$accent" ] || accent=$(theme_palette_color "$theme_dir" accent)
    muted=$(jq -r '.codex.muted // empty' "$theme_dir/theme.json" 2>/dev/null)
    [ -n "$muted" ] || muted=$(theme_palette_color "$theme_dir" bright_black)
    red=$(theme_palette_color "$theme_dir" red)
    green=$(theme_palette_color "$theme_dir" green)
    selection=$(theme_palette_color "$theme_dir" selection_bg)
    [ -n "$muted" ] || muted="$fg"
    [ -n "$red" ] || red="$fg"
    [ -n "$green" ] || green="$accent"
    [ -n "$selection" ] || selection="$bg"

    if [ -z "$bg" ] || [ -z "$fg" ] || [ -z "$accent" ]; then
        echo "  ! Codex: could not resolve palette, skipped"
        return
    fi

    mkdir -p "$codex_theme_dir"
    tmp_theme=$(mktemp "$codex_theme_dir/.desktop.tmTheme.XXXXXX") || {
        echo "  ! Codex: could not create temporary theme"
        return
    }

    cat > "$tmp_theme" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>name</key>
  <string>Desktop</string>
  <key>settings</key>
  <array>
    <dict>
      <key>settings</key>
      <dict>
        <key>background</key>
        <string>$bg</string>
        <key>foreground</key>
        <string>$fg</string>
        <key>caret</key>
        <string>$accent</string>
        <key>lineHighlight</key>
        <string>$selection</string>
        <key>selection</key>
        <string>$selection</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Muted</string>
      <key>scope</key>
      <string>comment, punctuation.definition.comment</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>$muted</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Accent</string>
      <key>scope</key>
      <string>entity.name.function, support.function, support.function.builtin, meta.function-call, markup.underline.link</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>$accent</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Neutral Syntax</string>
      <key>scope</key>
      <string>keyword, storage, string, constant, entity.name.type, support.type, support.class, variable, variable.parameter, keyword.operator, punctuation</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>$fg</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Error And Deleted</string>
      <key>scope</key>
      <string>invalid, markup.deleted, diff.deleted</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>$red</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Inserted</string>
      <key>scope</key>
      <string>markup.inserted, diff.inserted</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>$green</string>
      </dict>
    </dict>
    <dict>
      <key>name</key>
      <string>Changed</string>
      <key>scope</key>
      <string>markup.changed, diff.changed</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>$accent</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
EOF

    if mv "$tmp_theme" "$theme_out"; then
        chmod 0644 "$theme_out"
        echo "  ✓ Updated Codex CLI theme → desktop ($(basename "$theme_dir"))"
    else
        echo "  ! Codex: could not install $theme_out"
    fi
}

# Spotify (Spicetify): rewrite Themes/dotfiles/color.ini from palette and apply.
# Lives under ~/.config/spicetify (outside the stow tree). Best-effort — needs
# a one-time `spicetify backup apply` after first Spotify launch.
generate_spicetify_theme() {
    THEME_DIR="$1"
    local SPICETIFY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/spicetify"
    local THEME_NAME="dotfiles"
    local THEME_OUT="$SPICETIFY_DIR/Themes/$THEME_NAME"
    local SPOTIFY_PATH="$HOME/.local/share/spotify-launcher/install/usr/share/spotify"
    local PREFS_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/spotify/prefs"

    if ! command -v spicetify &>/dev/null; then
        echo "  ! Spotify: spicetify not installed, skipped"
        return
    fi

    local bg fg accent black bright_black red green selection_bg subtext card
    bg=$(theme_palette_color "$THEME_DIR" background)
    fg=$(theme_palette_color "$THEME_DIR" foreground)
    accent=$(theme_palette_color "$THEME_DIR" accent)
    black=$(theme_palette_color "$THEME_DIR" black)
    bright_black=$(theme_palette_color "$THEME_DIR" bright_black)
    red=$(theme_palette_color "$THEME_DIR" red)
    green=$(theme_palette_color "$THEME_DIR" green)
    selection_bg=$(theme_palette_color "$THEME_DIR" selection_bg)
    [ -n "$black" ] || black="$bg"
    [ -n "$bright_black" ] || bright_black="$black"
    [ -n "$selection_bg" ] || selection_bg="$bright_black"
    [ -n "$green" ] || green="$accent"
    [ -n "$red" ] || red="#e22134"
    # subtext: dimmer than fg — bright_black on light themes, white-ish on dark
    if theme_is_dark "$THEME_DIR"; then
        subtext=$(theme_palette_color "$THEME_DIR" white)
        [ -n "$subtext" ] || subtext="$fg"
        card="$black"
    else
        subtext="$bright_black"
        card="$selection_bg"
    fi

    if [ -z "$bg" ] || [ -z "$fg" ] || [ -z "$accent" ]; then
        echo "  ! Spotify: could not resolve palette, skipped"
        return
    fi

    mkdir -p "$THEME_OUT"

    # Bootstrap paths if missing (spotify-launcher install layout).
    if [ -d "$SPOTIFY_PATH" ]; then
        spicetify config spotify_path "$SPOTIFY_PATH" &>/dev/null || true
    fi
    if [ -f "$PREFS_PATH" ]; then
        spicetify config prefs_path "$PREFS_PATH" &>/dev/null || true
    fi

    cat > "$THEME_OUT/color.ini" << EOF
; Auto-generated by theme-switcher.sh from theme '$(basename "$THEME_DIR")'
; DO NOT EDIT MANUALLY — overwritten on the next theme switch.
[Base]
text               = $(hex_nohash "$fg")
subtext            = $(hex_nohash "$subtext")
main               = $(hex_nohash "$bg")
main-elevated      = $(hex_nohash "$black")
highlight          = $(hex_nohash "$selection_bg")
highlight-elevated = $(hex_nohash "$bright_black")
sidebar            = $(hex_nohash "$bg")
player             = $(hex_nohash "$black")
card               = $(hex_nohash "$card")
shadow             = $(hex_nohash "$bg")
selected-row       = $(hex_nohash "$fg")
button             = $(hex_nohash "$accent")
button-active      = $(hex_nohash "$accent")
button-disabled    = $(hex_nohash "$bright_black")
tab-active         = $(hex_nohash "$selection_bg")
notification       = $(hex_nohash "$accent")
notification-error = $(hex_nohash "$red")
misc               = $(hex_nohash "$bright_black")
EOF

    # Minimal CSS — colors come from color.ini; keep file so the theme is valid.
    cat > "$THEME_OUT/user.css" << 'EOF'
/* Auto-generated by theme-switcher.sh — colors live in color.ini. */
EOF

    spicetify config current_theme "$THEME_NAME" &>/dev/null || true
    spicetify config color_scheme Base &>/dev/null || true

    # Never restart Spotify from the theme switcher.
    #
    # spicetify's built-in restart launches the raw binary (breaks with
    # spotify-launcher: open → die). Our own kill+spotify-launcher bounce
    # races Hyprland/Waybar reloads and hard-crashes Chromium ("GPU process
    # isn't usable" / SIGTRAP in chrome_debug.log). Patch files only; a
    # running client keeps the old paint until the user reopens it.
    if spicetify -n -q refresh &>/dev/null || spicetify -n -q apply &>/dev/null; then
        if pgrep -x spotify >/dev/null 2>&1; then
            echo "  ✓ Updated Spotify colors (no restart — reopen Spotify to apply)"
        else
            echo "  ✓ Updated Spotify colors (spicetify, no restart)"
        fi
    else
        echo "  ! Spotify: wrote $THEME_OUT; run once: spicetify backup apply"
    fi
}

# ncspot: rewrite [theme] in config.toml, preserve every other key/section.
generate_ncspot_theme() {
    THEME_DIR="$1"
    local NCSPOT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ncspot"
    local NCSPOT_CONFIG="$NCSPOT_DIR/config.toml"

    if ! command -v ncspot &>/dev/null && [ ! -d "$NCSPOT_DIR" ]; then
        echo "  ! ncspot: not installed, skipped"
        return
    fi

    local bg fg accent black bright_black red green selection_bg
    bg=$(theme_palette_color "$THEME_DIR" background)
    fg=$(theme_palette_color "$THEME_DIR" foreground)
    accent=$(theme_palette_color "$THEME_DIR" accent)
    black=$(theme_palette_color "$THEME_DIR" black)
    bright_black=$(theme_palette_color "$THEME_DIR" bright_black)
    red=$(theme_palette_color "$THEME_DIR" red)
    green=$(theme_palette_color "$THEME_DIR" green)
    selection_bg=$(theme_palette_color "$THEME_DIR" selection_bg)
    [ -n "$black" ] || black="$bg"
    [ -n "$bright_black" ] || bright_black="$black"
    [ -n "$selection_bg" ] || selection_bg="$bright_black"
    [ -n "$green" ] || green="$accent"
    [ -n "$red" ] || red="#BF616A"

    if [ -z "$bg" ] || [ -z "$fg" ] || [ -z "$accent" ]; then
        echo "  ! ncspot: could not resolve palette, skipped"
        return
    fi

    mkdir -p "$NCSPOT_DIR"

    local rest=""
    if [ -f "$NCSPOT_CONFIG" ]; then
        # Drop any existing [theme] table (and our marker comment) so we re-append cleanly.
        rest=$(awk '
            BEGIN { skip=0 }
            /^# Auto-generated \[theme\]/ { next }
            /^\[theme\]/ { skip=1; next }
            /^\[/ { skip=0 }
            !skip { print }
        ' "$NCSPOT_CONFIG")
        # Collapse trailing blank lines so rewrites do not grow the file.
        rest=$(printf '%s\n' "$rest" | awk '
            { lines[NR]=$0 }
            END {
                end=NR
                while (end > 0 && lines[end] ~ /^[[:space:]]*$/) end--
                for (i=1; i<=end; i++) print lines[i]
            }
        ')
    fi

    {
        if [ -n "$rest" ]; then
            printf '%s\n\n' "$rest"
        fi
        cat << EOF
# Auto-generated [theme] by theme-switcher.sh — overwritten on theme switch.
[theme]
background = "$bg"
primary = "$fg"
secondary = "$bright_black"
title = "$accent"
playing = "$green"
playing_selected = "$accent"
playing_bg = "$black"
highlight = "$fg"
highlight_bg = "$selection_bg"
error = "$fg"
error_bg = "$red"
statusbar = "$bg"
statusbar_progress = "$accent"
statusbar_bg = "$accent"
cmdline = "$fg"
cmdline_bg = "$bg"
search_match = "$red"
EOF
    } > "$NCSPOT_CONFIG"

    echo "  ✓ Updated ncspot theme"
}

# Discord: Vencord QuickCSS / BetterDiscord custom.css when present; always
# also write ~/.config/discord-theme/theme.css so a later install can pick it up.
generate_discord_theme() {
    THEME_DIR="$1"
    local bg fg accent black bright_black selection_bg red
    bg=$(theme_palette_color "$THEME_DIR" background)
    fg=$(theme_palette_color "$THEME_DIR" foreground)
    accent=$(theme_palette_color "$THEME_DIR" accent)
    black=$(theme_palette_color "$THEME_DIR" black)
    bright_black=$(theme_palette_color "$THEME_DIR" bright_black)
    selection_bg=$(theme_palette_color "$THEME_DIR" selection_bg)
    red=$(theme_palette_color "$THEME_DIR" red)
    [ -n "$black" ] || black="$bg"
    [ -n "$bright_black" ] || bright_black="$black"
    [ -n "$selection_bg" ] || selection_bg="$bright_black"
    [ -n "$red" ] || red="#ed4245"

    if [ -z "$bg" ] || [ -z "$fg" ] || [ -z "$accent" ]; then
        echo "  ! Discord: could not resolve palette, skipped"
        return
    fi

    # Discord's 2025 visual refresh mostly ignores legacy --background-primary
    # on :root. Hit .theme-dark / .visual-refresh + the new base tokens, and
    # drive Vencord ClientTheme (rewrites --neutral-N-hsl) from the accent.
    local css
    css=$(cat << EOF
/* Auto-generated by theme-switcher.sh from theme '$(basename "$THEME_DIR")'
 * DO NOT EDIT MANUALLY — overwritten on the next theme switch.
 * Targets Discord visual-refresh tokens + legacy aliases. */
:root, .theme-dark, .theme-light, .visual-refresh, .visual-refresh.theme-dark, .visual-refresh.theme-light {
    --df-bg: $bg;
    --df-bg-secondary: $black;
    --df-bg-tertiary: $bright_black;
    --df-fg: $fg;
    --df-accent: $accent;
    --df-selection: $selection_bg;
    --df-danger: $red;

    /* Legacy tokens (pre-refresh + some remaining surfaces) */
    --background-primary: $bg !important;
    --background-secondary: $black !important;
    --background-secondary-alt: $black !important;
    --background-tertiary: $bright_black !important;
    --background-accent: $selection_bg !important;
    --background-floating: $black !important;
    --background-mobile-primary: $bg !important;
    --background-mobile-secondary: $black !important;
    --background-modifier-hover: color-mix(in srgb, $accent 14%, transparent) !important;
    --background-modifier-active: color-mix(in srgb, $accent 22%, transparent) !important;
    --background-modifier-selected: color-mix(in srgb, $accent 30%, transparent) !important;
    --background-modifier-accent: $accent !important;
    --background-mentioned: color-mix(in srgb, $accent 18%, transparent) !important;
    --background-mentioned-hover: color-mix(in srgb, $accent 26%, transparent) !important;
    --background-message-hover: color-mix(in srgb, $accent 10%, transparent) !important;

    /* Visual-refresh base scale (lowest = deepest chrome) */
    --background-base-lowest: $bg !important;
    --background-base-lower: $black !important;
    --background-base-low: $bright_black !important;
    --background-base-mid: $bright_black !important;
    --background-surface-high: $bright_black !important;
    --background-surface-higher: $selection_bg !important;
    --background-surface-highest: $selection_bg !important;
    --background-mod-subtle: color-mix(in srgb, $accent 10%, transparent) !important;
    --background-mod-normal: color-mix(in srgb, $accent 16%, transparent) !important;
    --background-mod-strong: color-mix(in srgb, $accent 24%, transparent) !important;
    --bg-base-primary: $bg !important;
    --bg-base-secondary: $black !important;
    --bg-base-tertiary: $bright_black !important;
    --bg-overlay-1: $bg !important;
    --bg-overlay-2: $black !important;
    --bg-overlay-3: $bright_black !important;
    --bg-overlay-color: $bg !important;
    --bg-overlay-color-inverse: $fg !important;
    --bg-mod-faint: color-mix(in srgb, $accent 8%, transparent) !important;
    --bg-mod-subtle: color-mix(in srgb, $accent 12%, transparent) !important;
    --bg-mod-strong: color-mix(in srgb, $accent 22%, transparent) !important;
    --chat-background-default: $bg !important;
    --chat-background-default-hover: color-mix(in srgb, $accent 8%, $bg) !important;

    --channeltextarea-background: $black !important;
    --input-background: $black !important;
    --scrollbar-thin-thumb: $bright_black !important;
    --scrollbar-auto-thumb: $bright_black !important;
    --scrollbar-auto-track: transparent !important;

    --header-primary: $fg !important;
    --header-secondary: color-mix(in srgb, $fg 70%, transparent) !important;
    --text-normal: $fg !important;
    --text-muted: color-mix(in srgb, $fg 55%, transparent) !important;
    --text-link: $accent !important;
    --channels-default: color-mix(in srgb, $fg 65%, transparent) !important;
    --interactive-normal: color-mix(in srgb, $fg 75%, transparent) !important;
    --interactive-hover: $fg !important;
    --interactive-active: $fg !important;
    --interactive-muted: color-mix(in srgb, $fg 40%, transparent) !important;

    /* Brand / buttons (Add Friend, nitro chips, etc.) */
    --brand-experiment: $accent !important;
    --brand-experiment-560: $accent !important;
    --brand-100: color-mix(in srgb, $accent 20%, white) !important;
    --brand-200: color-mix(in srgb, $accent 35%, white) !important;
    --brand-300: color-mix(in srgb, $accent 50%, white) !important;
    --brand-400: color-mix(in srgb, $accent 70%, white) !important;
    --brand-500: $accent !important;
    --brand-560: $accent !important;
    --brand-600: color-mix(in srgb, $accent 85%, black) !important;
    --brand-700: color-mix(in srgb, $accent 70%, black) !important;
    --redesign-button-primary-background: $accent !important;
    --redesign-button-primary-pressed-background: color-mix(in srgb, $accent 80%, black) !important;
    --redesign-button-primary-text: $fg !important;
    --button-secondary-background: $bright_black !important;
    --focus-primary: $accent !important;
    --control-brand-foreground: $accent !important;
    --status-danger: $red !important;
}

/* Solid paint on major chrome — beats tokens Discord redefines later */
.theme-dark .bg__12180,
.theme-dark [class*="app_"],
.theme-dark [class*="bg__"],
.theme-dark [class*="layers_"],
.theme-dark [class*="container_"][class*="guilds"],
body,
#app-mount {
    --background-primary: $bg;
    --background-base-lowest: $bg;
}
EOF
)

    local FALLBACK_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/discord-theme"
    local FALLBACK_CSS="$FALLBACK_DIR/theme.css"
    mkdir -p "$FALLBACK_DIR"
    printf '%s\n' "$css" > "$FALLBACK_CSS"

    local wrote=0
    local VENCORD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Vencord"
    local VENCORD_QUICK="$VENCORD_DIR/settings/quickCss.css"
    local VENCORD_SETTINGS="$VENCORD_DIR/settings"
    local VENCORD_SETTINGS_JSON="$VENCORD_SETTINGS/settings.json"
    local BD_CSS="${XDG_CONFIG_HOME:-$HOME/.config}/BetterDiscord/data/stable/custom.css"
    local accent_hex="${accent#\#}"

    if [ -d "$VENCORD_SETTINGS" ] || [ -f "$VENCORD_QUICK" ] || [ -d "$VENCORD_DIR/dist" ]; then
        mkdir -p "$VENCORD_SETTINGS"
        printf '%s\n' "$css" > "$VENCORD_QUICK"
        # ClientTheme recolors the visual-refresh --neutral-N-hsl ramp from one hue.
        # That is what actually tints the 2025 UI; QuickCSS alone is not enough.
        if [ -f "$VENCORD_SETTINGS_JSON" ] && command -v jq &>/dev/null; then
            local tmp
            tmp=$(mktemp)
            if jq \
                --arg c "$accent_hex" \
                '.useQuickCss = true
                 | .plugins.ClientTheme = ((.plugins.ClientTheme // {}) + {enabled: true, color: $c})' \
                "$VENCORD_SETTINGS_JSON" > "$tmp" 2>/dev/null; then
                mv "$tmp" "$VENCORD_SETTINGS_JSON"
                echo "  ✓ Updated Discord (Vencord QuickCSS + ClientTheme #$accent_hex)"
            else
                rm -f "$tmp"
                echo "  ✓ Updated Discord (Vencord QuickCSS); ClientTheme settings patch failed"
            fi
        else
            echo "  ✓ Updated Discord (Vencord QuickCSS)"
        fi
        wrote=1
    fi

    if [ -f "$BD_CSS" ] || [ -d "$(dirname "$BD_CSS")" ]; then
        mkdir -p "$(dirname "$BD_CSS")"
        printf '%s\n' "$css" > "$BD_CSS"
        echo "  ✓ Updated Discord (BetterDiscord custom.css)"
        wrote=1
    fi

    if [ "$wrote" -eq 0 ]; then
        # Optional one-shot install if the non-interactive CLI is already present.
        local installer=""
        if command -v vencordinstallercli &>/dev/null; then
            installer="vencordinstallercli"
        elif command -v VencordInstallerCli &>/dev/null; then
            installer="VencordInstallerCli"
        fi
        if [ -n "$installer" ] && command -v discord &>/dev/null; then
            if "$installer" -install -branch stable &>/dev/null; then
                mkdir -p "$VENCORD_SETTINGS"
                printf '%s\n' "$css" > "$VENCORD_QUICK"
                echo "  ✓ Discord: installed Vencord + wrote QuickCSS"
                wrote=1
            fi
        fi
    fi

    if [ "$wrote" -eq 0 ]; then
        echo "  ! Discord: Vencord not installed, wrote $FALLBACK_CSS"
        echo "    → one-time: yay -S vencord-installer-cli-bin && vencordinstallercli -install -branch stable"
        echo "    → then: cp $FALLBACK_CSS ~/.config/Vencord/settings/quickCss.css (or re-run theme apply)"
    fi
}

# Firefox: enable userChrome, write chrome/userChrome.css (+ light userContent.css).
# Prefer the locked Install default-release profile when present.
generate_firefox_theme() {
    THEME_DIR="$1"
    local FF_ROOT="$HOME/.mozilla/firefox"
    local profile=""

    if [ ! -d "$FF_ROOT" ]; then
        echo "  ! Firefox: no profile dir, skipped"
        return
    fi

    # Locked Install* Default= wins (release channel install).
    if [ -f "$FF_ROOT/installs.ini" ]; then
        profile=$(awk -F= '
            /^\[Install/ { in_install=1; next }
            /^\[/ { in_install=0 }
            in_install && $1 == "Default" { print $2; exit }
        ' "$FF_ROOT/installs.ini")
    fi
    # Fallback: profiles.ini Path for Name=default-release, then Default=1.
    if [ -z "$profile" ] && [ -f "$FF_ROOT/profiles.ini" ]; then
        profile=$(awk -F= '
            /^\[Profile/ { name=""; path="" }
            $1 == "Name" { name=$2 }
            $1 == "Path" { path=$2 }
            name == "default-release" && path != "" { print path; exit }
        ' "$FF_ROOT/profiles.ini")
    fi
    if [ -z "$profile" ] && [ -f "$FF_ROOT/profiles.ini" ]; then
        profile=$(awk -F= '
            /^\[Profile/ { path=""; def=0 }
            $1 == "Path" { path=$2 }
            $1 == "Default" && $2 == "1" { def=1 }
            def && path != "" { print path; exit }
        ' "$FF_ROOT/profiles.ini")
    fi
    # Last resort: the path the user specified.
    [ -n "$profile" ] || profile="btdpag0p.default-release"

    local PROFILE_DIR
    case "$profile" in
        /*) PROFILE_DIR="$profile" ;;
        *) PROFILE_DIR="$FF_ROOT/$profile" ;;
    esac

    if [ ! -d "$PROFILE_DIR" ]; then
        echo "  ! Firefox: profile not found ($profile), skipped"
        return
    fi

    local bg fg accent black bright_black selection_bg
    bg=$(theme_palette_color "$THEME_DIR" background)
    fg=$(theme_palette_color "$THEME_DIR" foreground)
    accent=$(theme_palette_color "$THEME_DIR" accent)
    black=$(theme_palette_color "$THEME_DIR" black)
    bright_black=$(theme_palette_color "$THEME_DIR" bright_black)
    selection_bg=$(theme_palette_color "$THEME_DIR" selection_bg)
    [ -n "$black" ] || black="$bg"
    [ -n "$bright_black" ] || bright_black="$black"
    [ -n "$selection_bg" ] || selection_bg="$bright_black"

    if [ -z "$bg" ] || [ -z "$fg" ] || [ -z "$accent" ]; then
        echo "  ! Firefox: could not resolve palette, skipped"
        return
    fi

    # Enable userChrome loading (idempotent; leave other prefs alone).
    local USER_JS="$PROFILE_DIR/user.js"
    local PREF_LINE='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
    if [ -f "$USER_JS" ]; then
        if grep -q 'toolkit.legacyUserProfileCustomizations.stylesheets' "$USER_JS" 2>/dev/null; then
            # Normalize to true without clobbering the rest of the file.
            sed -i 's/user_pref("toolkit.legacyUserProfileCustomizations.stylesheets".*/user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);/' "$USER_JS"
        else
            printf '\n// theme-switcher: enable userChrome/userContent\n%s\n' "$PREF_LINE" >> "$USER_JS"
        fi
    else
        cat > "$USER_JS" << EOF
// Auto-generated by theme-switcher.sh — enables chrome/userChrome.css theming.
// Safe to add other user_pref lines below; this file is only re-touched for the
// legacyUserProfileCustomizations pref.
$PREF_LINE
EOF
    fi

    local CHROME_DIR="$PROFILE_DIR/chrome"
    mkdir -p "$CHROME_DIR"

    local theme_mode="dark"
    theme_is_dark "$THEME_DIR" || theme_mode="light"

    cat > "$CHROME_DIR/userChrome.css" << EOF
/* Auto-generated by theme-switcher.sh from theme '$(basename "$THEME_DIR")' ($theme_mode)
 * DO NOT EDIT MANUALLY — overwritten on the next theme switch.
 * Restart Firefox after the first enable of userChrome. */
:root {
    --df-bg: $bg;
    --df-bg-elevated: $black;
    --df-fg: $fg;
    --df-accent: $accent;
    --df-muted: $bright_black;
    --df-selection: $selection_bg;
}

/* Toolbar / tabs strip */
#navigator-toolbox {
    background-color: var(--df-bg) !important;
    border-bottom-color: var(--df-muted) !important;
    color: var(--df-fg) !important;
}

#nav-bar, #PersonalToolbar, #TabsToolbar, #toolbar-menubar {
    background-color: var(--df-bg) !important;
    color: var(--df-fg) !important;
}

/* Tabs */
.tab-background {
    background-color: transparent !important;
    border-radius: 6px 6px 0 0 !important;
}
.tab-background[selected] {
    background-color: var(--df-bg-elevated) !important;
    box-shadow: inset 0 -2px 0 var(--df-accent) !important;
}
.tabbrowser-tab:hover > .tab-stack > .tab-background:not([selected]) {
    background-color: color-mix(in srgb, var(--df-accent) 14%, transparent) !important;
}
.tab-label {
    color: var(--df-fg) !important;
}
.tabbrowser-tab:not([selected]) .tab-label {
    opacity: 0.75;
}

/* URL bar */
#urlbar-background, #searchbar {
    background-color: var(--df-bg-elevated) !important;
    border-color: var(--df-muted) !important;
}
#urlbar[focused] > #urlbar-background {
    border-color: var(--df-accent) !important;
}
#urlbar-input, .urlbar-input-box, #urlbar-input-container {
    color: var(--df-fg) !important;
}

/* Sidebar */
#sidebar-box, #sidebar-header {
    background-color: var(--df-bg) !important;
    color: var(--df-fg) !important;
    border-color: var(--df-muted) !important;
}
EOF

    cat > "$CHROME_DIR/userContent.css" << EOF
/* Auto-generated by theme-switcher.sh — new-tab / about: pages only. */
@-moz-document url("about:home"), url("about:newtab"), url("about:blank") {
    :root {
        --newtab-background-color: $bg !important;
        --newtab-text-primary-color: $fg !important;
        --newtab-primary-action-background: $accent !important;
    }
    body {
        background-color: $bg !important;
        color: $fg !important;
    }
}
EOF

    echo "  ✓ Updated Firefox chrome ($profile); restart Firefox to load"
}

# Function to append BRAND-coloured codexbar (AI usage) styling to Waybar CSS.
# Called right after the theme's waybar.css is copied over style.css. Provider
# identity is shown by brand colours so usage reads at a glance on any theme:
# Anthropic=orange, OpenAI=green (or the theme's Codex accent), Google=blue.
# The white source logos are recoloured to match and cached under recolored/ (so
# they never wash out on a light theme). xAI/Grok has no brand colour, so it
# follows the theme foreground to stay legible on light AND dark themes. Critical
# usage adds a faint brand-colour chip; stale data dims the module.
generate_codexbar_css() {
    THEME_DIR="$1"
    local STYLE="$DOTFILES/waybar/.config/waybar/style.css"
    local SRC="$HOME/.local/share/codexbar-waybar/icons"
    local OUT="$HOME/.local/share/codexbar-waybar/recolored"
    [ -f "$STYLE" ] || return
    mkdir -p "$OUT"

    local c_anthropic="#D97757"   # Anthropic orange
    local c_openai
    c_openai=$(jq -r '.codex.accent // empty' "$THEME_DIR/theme.json")
    [ -n "$c_openai" ] || c_openai="#10A37F" # OpenAI green
    local c_google="#4285F4"      # Google blue
    local c_xai                   # xAI: follow theme foreground (monochrome brand)
    c_xai=$(jq -r '.palette.foreground // empty' "$THEME_DIR/theme.json")
    [ -n "$c_xai" ] || c_xai=$(awk '$1 == "foreground" { print $2; exit }' "$THEME_DIR/kitty.conf")
    [ -n "$c_xai" ] || c_xai="#B4B4B4"
    local c_openrouter="#A78BFA"  # OpenRouter: violet (readable on dark and light)
    local c_zai="#22D3EE"         # Z.ai / GLM: cyan (distinct from Google blue + OR violet)

    # Recolour a white source SVG to a brand colour, caching the result.
    # Also resolves currentColor: GTK renders these via CSS background-image,
    # which has no color context, so unresolved currentColor draws invisible.
    _cb_recolor() { # src_name dest_name hex
        [ -f "$SRC/$1" ] && sed -E "s/#[Ff]{6}/$3/g; s/fill=\"white\"/fill=\"$3\"/g; s/currentColor/$3/g" "$SRC/$1" > "$OUT/$2"
    }
    _cb_recolor ProviderIcon-claude.svg     claude.svg     "$c_anthropic"
    _cb_recolor ProviderIcon-grok.svg       grok.svg       "$c_xai"
    _cb_recolor ProviderIcon-codex.svg      codex.svg      "$c_openai"
    _cb_recolor ProviderIcon-gemini.svg     gemini.svg     "$c_google"
    _cb_recolor ProviderIcon-openrouter.svg openrouter.svg "$c_openrouter"
    _cb_recolor ProviderIcon-zai.svg        zai.svg        "$c_zai"

    cat >> "$STYLE" << EOF

/* codexbar-waybar — AI usage, brand-coloured (auto-generated by theme-switcher).
 * Anthropic=orange OpenAI=green/theme Codex accent Google=blue;
 * xAI follows theme foreground. */
#custom-codexbar-claude, #custom-codexbar-grok,
#custom-codexbar-codex,  #custom-codexbar-gemini,
#custom-codexbar-zai,    #custom-codexbar-openrouter {
    padding: 0 8px 0 24px;
    font-weight: bold;
    background-repeat: no-repeat;
    background-position: 5px center;
    background-size: 13px 13px;
    border-radius: 6px;
}
#custom-codexbar-claude { color: $c_anthropic; background-image: url("$OUT/claude.svg"); }
#custom-codexbar-grok   { color: $c_xai;       background-image: url("$OUT/grok.svg"); }
#custom-codexbar-codex  { color: $c_openai;    background-image: url("$OUT/codex.svg"); }
#custom-codexbar-gemini { color: $c_google;    background-image: url("$OUT/gemini.svg"); }
#custom-codexbar-zai    { color: $c_zai;       background-image: url("$OUT/zai.svg"); }
#custom-codexbar-openrouter { color: $c_openrouter; background-image: url("$OUT/openrouter.svg"); margin-right: 48px; }
#custom-codexbar-claude.critical { background-color: alpha($c_anthropic, 0.20); }
#custom-codexbar-grok.critical   { background-color: alpha($c_xai, 0.20); }
#custom-codexbar-codex.critical  { background-color: alpha($c_openai, 0.20); }
#custom-codexbar-gemini.critical { background-color: alpha($c_google, 0.20); }
#custom-codexbar-zai.critical    { background-color: alpha($c_zai, 0.20); }
#custom-codexbar-openrouter.critical { background-color: alpha($c_openrouter, 0.20); }
#custom-codexbar-claude.stale, #custom-codexbar-grok.stale,
#custom-codexbar-codex.stale,  #custom-codexbar-gemini.stale,
#custom-codexbar-zai.stale,    #custom-codexbar-openrouter.stale { opacity: 0.45; }

/* Peak-rate window: z.ai credit plans bill 1x Mon-Fri 06:00-10:00 UTC and 0.5x
 * otherwise, so the same work costs double inside it. Underline the module while
 * the expensive window is open; the ⏱ marker in the text says the same thing. */
#custom-codexbar-zai.peak {
    background-color: alpha($c_zai, 0.14);
    box-shadow: inset 0 -2px 0 0 $c_zai;
}
EOF
    echo "  ✓ Appended codexbar (brand-coloured) styling"
}

expand_home_path() {
    case "$1" in
        \~) printf '%s\n' "$HOME" ;;
        \~/*) printf '%s/%s\n' "$HOME" "${1#\~/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

# Function to update wallpapers
update_wallpapers() {
    THEME_DIR="$1"
    HYPRPAPER_CONF="$DOTFILES/hypr/.config/hypr/hyprpaper.conf"

    if [ ! -f "$THEME_DIR/theme.json" ]; then
        echo "  ! Warning: theme.json not found, skipping wallpaper update"
        return
    fi

    # Kill any existing mpvpaper instances
    killall mpvpaper &>/dev/null

    # hyprpaper 0.8+: wallpaper { } blocks. preload= is gone.
    {
        echo "# Auto-generated by theme-switcher"
        echo "splash = false"
        echo ""
        jq -r '.monitors | to_entries[] | "\(.key)=\(.value)"' "$THEME_DIR/theme.json" 2>/dev/null | while IFS='=' read -r monitor wp_ref; do
            TYPE=$(echo "$wp_ref" | sed 's/\[.*//')
            INDEX=$(echo "$wp_ref" | grep -o '[0-9]*' | head -1)

            if [ "$TYPE" = "live" ]; then
                continue
            fi
            WALLPAPER=$(jq -r ".wallpapers.$TYPE[$INDEX]?" "$THEME_DIR/theme.json" 2>/dev/null)
            if [ -n "$WALLPAPER" ] && [ "$WALLPAPER" != "null" ]; then
                EXPANDED_PATH=$(expand_home_path "$WALLPAPER")
                printf 'wallpaper {\n    monitor = %s\n    path = %s\n    fit_mode = cover\n}\n\n' \
                    "$monitor" "$EXPANDED_PATH"
            fi
        done
    } > "$HYPRPAPER_CONF"

    echo "  ✓ Updated hyprpaper config"

    # Second pass: launch mpvpaper for animated wallpapers (after hyprpaper is ready)
    # Store in temp file to avoid subshell issues
    TEMP_MPVPAPER="/tmp/mpvpaper_commands_$$.sh"
    echo "#!/bin/bash" > "$TEMP_MPVPAPER"

    jq -r '.monitors | to_entries[] | "\(.key)=\(.value)"' "$THEME_DIR/theme.json" 2>/dev/null | while IFS='=' read -r monitor wp_ref; do
        TYPE=$(echo "$wp_ref" | sed 's/\[.*//')
        INDEX=$(echo "$wp_ref" | grep -o '[0-9]*' | head -1)

        if [ "$TYPE" = "live" ]; then
            WALLPAPER=$(jq -r ".wallpapers.$TYPE[$INDEX]?" "$THEME_DIR/theme.json" 2>/dev/null)
            if [ -n "$WALLPAPER" ] && [ "$WALLPAPER" != "null" ]; then
                EXPANDED_PATH=$(expand_home_path "$WALLPAPER")
                echo "systemd-run --user --quiet --collect mpvpaper -o \"loop --hwdec=auto\" \"$monitor\" \"$EXPANDED_PATH\"" >> "$TEMP_MPVPAPER"
            fi
        fi
    done

    chmod +x "$TEMP_MPVPAPER"
    export MPVPAPER_SCRIPT="$TEMP_MPVPAPER"
}

# Function to reload services
reload_services() {
    THEME_NAME="$1"
    echo "  → Reloading services..."

    # Reload Hyprland
    hyprctl reload &>/dev/null && echo "    ✓ Hyprland reloaded" || echo "    ! Hyprland reload failed"

    # Restart Hyprpaper via its user unit (stays supervised in its own cgroup,
    # not a disowned child of whatever called this)
    systemctl --user restart hyprpaper.service &>/dev/null
    sleep 1

    # Send wallpaper commands directly to hyprpaper
    THEME_JSON="$THEMES_DIR/$THEME_NAME/theme.json"
    jq -r '.monitors | to_entries[] | "\(.key)=\(.value)"' "$THEME_JSON" 2>/dev/null | while IFS='=' read -r monitor wp_ref; do
        TYPE=$(echo "$wp_ref" | sed 's/\[.*//')
        INDEX=$(echo "$wp_ref" | grep -o '[0-9]*' | head -1)

        if [ "$TYPE" != "live" ]; then
            WALLPAPER=$(jq -r ".wallpapers.$TYPE[$INDEX]?" "$THEME_JSON" 2>/dev/null)
            if [ -n "$WALLPAPER" ] && [ "$WALLPAPER" != "null" ]; then
                EXPANDED_PATH=$(expand_home_path "$WALLPAPER")
                hyprctl hyprpaper wallpaper "$monitor, $EXPANDED_PATH, cover" &>/dev/null
            fi
        fi
    done
    echo "    ✓ Hyprpaper restarted"

    # Launch mpvpaper instances
    if [ -n "$MPVPAPER_SCRIPT" ] && [ -f "$MPVPAPER_SCRIPT" ]; then
        "$MPVPAPER_SCRIPT"
        rm -f "$MPVPAPER_SCRIPT"
        echo "    ✓ Animated wallpapers started"
    fi

    # Restart Waybar via its user unit (stays supervised — no orphaned module scripts)
    systemctl --user restart app-waybar@autostart.service &>/dev/null
    echo "    ✓ Waybar restarted"

    # Restart Mako via its user unit (stays supervised)
    systemctl --user restart app-mako@autostart.service &>/dev/null
    echo "    ✓ Mako restarted"

    # eww (HUD panel): theme-render wrote theme-colors.scss; reload picks it up.
    # Best-effort — no daemon is fine on a bare shell or before first open.
    if command -v eww &>/dev/null; then
        eww reload &>/dev/null && echo "    ✓ eww (HUD) reloaded" || echo "    ! eww reload failed"
    fi

    # Philips Hue: push theme accent to the configured room/group (best-effort).
    # Silent until `hue pair` has written ~/.config/hue/config.json — never blocks apply.
    HUE_BIN="$DOTFILES/bin/.bin/hue"
    if [ -x "$HUE_BIN" ] && [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/hue/config.json" ]; then
        HUE_OUT=$("$HUE_BIN" theme-soft "$THEME_NAME" 2>/dev/null || true)
        if [ -n "$HUE_OUT" ]; then
            echo "    ✓ Hue: $HUE_OUT"
        fi
    fi

    # Reload Kitty colors using remote control
    KITTY_THEME="$THEMES_DIR/$THEME_NAME/kitty.conf"
    if [ -f "$KITTY_THEME" ]; then
        # Try to reload colors in all kitty instances
        if command -v kitty &>/dev/null; then
            # Use kitty @ to set colors dynamically for all running instances
            # Reload colors in all kitty instances via their individual sockets
            ss -xl 2>/dev/null | grep -oP '@mykitty-\d+' | while read -r sock; do
                kitty @ --to "unix:$sock" set-colors --all --configured "$KITTY_THEME" &>/dev/null || true
                # Font lives in theme-font.conf (include); full load picks it up.
                kitty @ --to "unix:$sock" load-config &>/dev/null || true
            done
            echo "    ✓ Kitty colors reloaded in all terminals"
        fi
    fi

    # Cava: SIGUSR2 reloads colors only (no audio reinit). Best-effort — no
    # instance running is the common case.
    if pgrep -x cava >/dev/null 2>&1; then
        pkill -USR2 -x cava 2>/dev/null \
            && echo "    ✓ Cava colors reloaded" \
            || echo "    ! Cava color reload failed"
    fi
}

# Main execution
case "$1" in
    list)
        # List available themes
        echo "Available themes:"
        for theme in "$THEMES_DIR"/*; do
            if [ -d "$theme" ]; then
                THEME_SLUG=$(basename "$theme")
                if [ -f "$theme/theme.json" ]; then
                    [ "$(jq -r '.terminal_only // false' "$theme/theme.json")" = "true" ] && continue
                    ICON=$(jq -r '.icon' "$theme/theme.json")
                    NAME=$(jq -r '.name' "$theme/theme.json")
                    echo "  $ICON  $NAME ($THEME_SLUG)"
                else
                    echo "  • $THEME_SLUG"
                fi
            fi
        done
        ;;
    current)
        # Show current theme
        if [ -f "$CURRENT_THEME_FILE" ]; then
            CURRENT=$(cat "$CURRENT_THEME_FILE")
            THEME_DIR="$THEMES_DIR/$CURRENT"
            if [ -f "$THEME_DIR/theme.json" ]; then
                ICON=$(jq -r '.icon' "$THEME_DIR/theme.json")
                NAME=$(jq -r '.name' "$THEME_DIR/theme.json")
                echo "$ICON $NAME ($CURRENT)"
            else
                echo "$CURRENT"
            fi
        else
            echo "No theme set (default: osaka-jade)"
        fi
        ;;
    apply)
        # Apply specified theme
        if [ -z "$2" ]; then
            echo "Usage: theme-switcher.sh apply <theme-name>"
            exit 1
        fi
        apply_theme "$2"
        ;;
    *)
        echo "Usage: theme-switcher.sh {list|current|apply <theme-name>}"
        echo ""
        echo "Commands:"
        echo "  list              List all available themes"
        echo "  current           Show the currently active theme"
        echo "  apply <theme>     Apply a specific theme"
        echo ""
        echo "Authoring (new themes — does not apply):"
        echo "  theme-scaffold wallpaper <image> [--name slug]"
        echo "  theme-scaffold base16 <name|file|url>"
        echo "  theme-lint [slug] | theme-lint --all"
        echo "  docs: ~/.dotfiles/themes/README.md"
        exit 1
        ;;
esac
