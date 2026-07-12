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
        "$DOTFILES/hypr/.config/hypr/theme-effects.conf"; then
        echo "Error: Failed to render shared theme surfaces"
        return 1
    fi

    generate_codexbar_css "$theme_dir"
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
    # recolor a single window. Applying one desktop-wide points Hyprland's source=
    # at a hyprland.conf that does not exist, leaving $border_active and friends
    # undefined across styling.conf.
    if [ "$(jq -r '.terminal_only // false' "$THEME_DIR/theme.json" 2>/dev/null)" = "true" ]; then
        echo "Error: '$THEME_NAME' is a terminal-only theme; use theme-term.sh instead"
        exit 1
    fi

    echo "Applying theme: $THEME_NAME"

    render_theme_surfaces "$THEME_NAME" || return 1

    # 1. Update Hyprland source line
    if [ -f "$DOTFILES/hypr/.config/hypr/hyprland.conf" ]; then
        sed -i "s|source = ~/.dotfiles/themes/.*/hyprland.conf|source = ~/.dotfiles/themes/$THEME_NAME/hyprland.conf|" \
            "$DOTFILES/hypr/.config/hypr/hyprland.conf"
        echo "  ✓ Updated Hyprland config"
    fi

    # 2. Update Kitty include line
    if [ -f "$DOTFILES/kitty/.config/kitty/kitty.conf" ]; then
        sed -i "s|include ~/.dotfiles/themes/.*/kitty.conf|include ~/.dotfiles/themes/$THEME_NAME/kitty.conf|" \
            "$DOTFILES/kitty/.config/kitty/kitty.conf"
        echo "  ✓ Updated Kitty config"
    fi

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

    # 6. Update Rofi theme
    if [ -f "$THEME_DIR/theme.json" ]; then
        ROFI_THEME=$(jq -r '.rofi_theme' "$THEME_DIR/theme.json")
        sed -i "s|@theme \".*\"|@theme \"$ROFI_THEME\"|" \
            "$DOTFILES/rofi/.config/rofi/config.rasi"
        echo "  ✓ Updated Rofi theme"
    fi

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

# Function to generate wiremix config from theme palette
generate_wiremix_config() {
    THEME_DIR="$1"

    WIREMIX_DIR="$HOME/.config/wiremix"
    mkdir -p "$WIREMIX_DIR"

    # Try palette from theme.json first, fall back to kitty.conf
    local has_palette=$(jq 'has("palette")' "$THEME_DIR/theme.json" 2>/dev/null)

    if [ "$has_palette" = "true" ]; then
        local fg=$(jq -r '.palette.foreground' "$THEME_DIR/theme.json")
        local cyan=$(jq -r '.palette.colors.cyan' "$THEME_DIR/theme.json")
        local blue=$(jq -r '.palette.colors.blue' "$THEME_DIR/theme.json")
        local green=$(jq -r '.palette.colors.green' "$THEME_DIR/theme.json")
        local red=$(jq -r '.palette.colors.red' "$THEME_DIR/theme.json")
        local bright_black=$(jq -r '.palette.colors.bright_black' "$THEME_DIR/theme.json")
    elif [ -f "$THEME_DIR/kitty.conf" ]; then
        local fg=$(grep '^foreground' "$THEME_DIR/kitty.conf" | awk '{print $2}')
        local cyan=$(grep '^color6 ' "$THEME_DIR/kitty.conf" | awk '{print $2}')
        local blue=$(grep '^color4 ' "$THEME_DIR/kitty.conf" | awk '{print $2}')
        local green=$(grep '^color2 ' "$THEME_DIR/kitty.conf" | awk '{print $2}')
        local red=$(grep '^color1 ' "$THEME_DIR/kitty.conf" | awk '{print $2}')
        local bright_black=$(grep '^color8 ' "$THEME_DIR/kitty.conf" | awk '{print $2}')
    else
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

# Function to append BRAND-coloured codexbar (AI usage) styling to Waybar CSS.
# Called right after the theme's waybar.css is copied over style.css. Provider
# identity is shown by fixed brand colours so usage reads at a glance on any
# theme: Anthropic=orange, OpenAI=green, Google=blue. The white source logos are
# recoloured to match and cached under recolored/ (so they never wash out on a
# light theme). xAI/Grok has no brand colour, so it follows the theme foreground
# to stay legible on light AND dark themes. Critical usage adds a faint
# brand-colour chip; stale data dims the module.
generate_codexbar_css() {
    THEME_DIR="$1"
    local STYLE="$DOTFILES/waybar/.config/waybar/style.css"
    local SRC="$HOME/.local/share/codexbar-waybar/icons"
    local OUT="$HOME/.local/share/codexbar-waybar/recolored"
    [ -f "$STYLE" ] || return
    mkdir -p "$OUT"

    local c_anthropic="#D97757"   # Anthropic orange
    local c_openai="#10A37F"      # OpenAI green
    local c_google="#4285F4"      # Google blue
    local c_xai                   # xAI: follow theme foreground (monochrome brand)
    c_xai=$(jq -r '.palette.foreground // empty' "$THEME_DIR/theme.json")
    [ -n "$c_xai" ] || c_xai=$(awk '$1 == "foreground" { print $2; exit }' "$THEME_DIR/kitty.conf")
    [ -n "$c_xai" ] || c_xai="#B4B4B4"
    local c_openrouter="#A78BFA"  # OpenRouter: violet (readable on dark and light)

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

    cat >> "$STYLE" << EOF

/* codexbar-waybar — AI usage, brand-coloured (auto-generated by theme-switcher).
 * Anthropic=orange OpenAI=green Google=blue; xAI follows theme foreground. */
#custom-codexbar-claude, #custom-codexbar-grok,
#custom-codexbar-codex,  #custom-codexbar-gemini,
#custom-codexbar-openrouter {
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
#custom-codexbar-openrouter { color: $c_openrouter; background-image: url("$OUT/openrouter.svg"); margin-right: 48px; }
#custom-codexbar-claude.critical { background-color: alpha($c_anthropic, 0.20); }
#custom-codexbar-grok.critical   { background-color: alpha($c_xai, 0.20); }
#custom-codexbar-codex.critical  { background-color: alpha($c_openai, 0.20); }
#custom-codexbar-gemini.critical { background-color: alpha($c_google, 0.20); }
#custom-codexbar-openrouter.critical { background-color: alpha($c_openrouter, 0.20); }
#custom-codexbar-claude.stale, #custom-codexbar-grok.stale,
#custom-codexbar-codex.stale,  #custom-codexbar-gemini.stale,
#custom-codexbar-openrouter.stale { opacity: 0.45; }
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

    # Clear existing hyprpaper config and rebuild
    cat > "$HYPRPAPER_CONF" << 'EOF'
# Auto-generated by theme-switcher
# preload static images
EOF

    # Collect all static and vertical wallpapers for preloading
    for type in static vertical; do
        jq -r ".wallpapers.$type[]?" "$THEME_DIR/theme.json" 2>/dev/null | while read -r wp; do
            if [ -n "$wp" ]; then
                EXPANDED_PATH=$(expand_home_path "$wp")
                echo "preload = $EXPANDED_PATH" >> "$HYPRPAPER_CONF"
            fi
        done
    done

    echo "" >> "$HYPRPAPER_CONF"
    echo "# set wallpapers for each monitor" >> "$HYPRPAPER_CONF"

    # First pass: build hyprpaper config for static wallpapers
    jq -r '.monitors | to_entries[] | "\(.key)=\(.value)"' "$THEME_DIR/theme.json" 2>/dev/null | while IFS='=' read -r monitor wp_ref; do
        TYPE=$(echo "$wp_ref" | sed 's/\[.*//')
        INDEX=$(echo "$wp_ref" | grep -o '[0-9]*' | head -1)

        if [ "$TYPE" != "live" ]; then
            WALLPAPER=$(jq -r ".wallpapers.$TYPE[$INDEX]?" "$THEME_DIR/theme.json" 2>/dev/null)
            if [ -n "$WALLPAPER" ] && [ "$WALLPAPER" != "null" ]; then
                EXPANDED_PATH=$(expand_home_path "$WALLPAPER")
                echo "wallpaper = $monitor,$EXPANDED_PATH" >> "$HYPRPAPER_CONF"
            fi
        fi
    done

    echo "" >> "$HYPRPAPER_CONF"
    echo "# disable splash" >> "$HYPRPAPER_CONF"
    echo "splash = false" >> "$HYPRPAPER_CONF"

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
                hyprctl hyprpaper preload "$EXPANDED_PATH" &>/dev/null
                hyprctl hyprpaper wallpaper "$monitor,$EXPANDED_PATH" &>/dev/null
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

    # Reload Kitty colors using remote control
    KITTY_THEME="$THEMES_DIR/$THEME_NAME/kitty.conf"
    if [ -f "$KITTY_THEME" ]; then
        # Try to reload colors in all kitty instances
        if command -v kitty &>/dev/null; then
            # Use kitty @ to set colors dynamically for all running instances
            # Reload colors in all kitty instances via their individual sockets
            ss -xl 2>/dev/null | grep -oP '@mykitty-\d+' | while read -r sock; do
                kitty @ --to "unix:$sock" set-colors --all --configured "$KITTY_THEME" &>/dev/null || true
            done
            echo "    ✓ Kitty colors reloaded in all terminals"
        fi
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
        exit 1
        ;;
esac
