# Bare theme commands: type the theme name in any kitty window to reskin
# just that window (kitty colors + hyprland border). No claude-code launch.
# Companion to the cc* launchers in config.fish.

function _emit-osc-theme -d "Reskin the current terminal grid via OSC — per-pane inside herdr"
    # Reads a kitty theme conf and emits the equivalent dynamic-color escapes.
    # Only 6-digit hex values are picked up; anything else is skipped silently.
    for line in (command grep -E '^[a-z_0-9]+[[:space:]]+#[0-9a-fA-F]{6}' $argv[1])
        set -l kv (string match -r '^(\S+)\s+(#[0-9a-fA-F]{6})' -- $line)
        switch $kv[2]
            case foreground
                printf '\e]10;%s\e\\' $kv[3]
            case background
                printf '\e]11;%s\e\\' $kv[3]
            case cursor
                printf '\e]12;%s\e\\' $kv[3]
            case selection_background
                printf '\e]17;%s\e\\' $kv[3]
            case selection_foreground
                printf '\e]19;%s\e\\' $kv[3]
            case 'color*'
                printf '\e]4;%s;%s\e\\' (string replace -r '^color' '' $kv[2]) $kv[3]
        end
    end
end

function _apply-kitty-theme -d "Reskin the active kitty window, its hyprland border, and starship prompt"
    set -l slug $argv[1]
    set -l border $argv[2]
    set -l theme_dir ~/.dotfiles/themes/$slug
    set -l kitty_conf $theme_dir/kitty.conf
    set -l starship_conf $theme_dir/starship.toml

    if not test -f $kitty_conf
        echo "theme '$slug' not found at $theme_dir" >&2
        return 1
    end

    # Inside a herdr pane, KITTY_LISTEN_ON/KITTY_PID are stale values inherited
    # from whichever kitty was alive when the herdr *server* started, and
    # set-colors is window-wide regardless. Each pane owns its own VT, so OSC
    # reskins exactly this pane and nothing else.
    if set -q HERDR_ENV
        _emit-osc-theme $kitty_conf
    else
        if test -n "$KITTY_LISTEN_ON"
            kitty @ --to "$KITTY_LISTEN_ON" set-colors --configured $kitty_conf 2>/dev/null
        end

        # The config is Lua (hyprland.lua), so `hyprctl dispatch` evaluates its
        # argument as Lua — the old `setprop "pid:N" prop value` form is a parse
        # error that fails silently into the &>/dev/null below.
        if test -n "$KITTY_PID"; and test -n "$border"
            hyprctl dispatch "hl.dsp.window.set_prop({ window = \"pid:$KITTY_PID\", prop = \"active_border_color\", value = \"$border\" })" &>/dev/null
        end
    end

    if test -f $starship_conf
        set -gx STARSHIP_CONFIG $starship_conf
    end
end

function aegis        -d "Theme: gruvbox warm"; _apply-kitty-theme aegis        'rgba(d79921ee)'; end
function ashen        -d "Theme: velise red";   _apply-kitty-theme ashen        'rgba(8B2222ee)'; end
function crimson-gray -d "Theme: iceberg";       _apply-kitty-theme crimson-gray 'rgba(84a0c6AA)'; end
function cyber        -d "Theme: mustang blue"; _apply-kitty-theme cyber        'rgba(3D6390AA)'; end
function jade         -d "Theme: green";        _apply-kitty-theme jade         'rgba(2DD5B7ee)'; end
function pine         -d "Theme: OpenAI green"; _apply-kitty-theme pine         'rgba(10A37Fee)'; end
function lavender     -d "Theme: purple";       _apply-kitty-theme lavender     'rgba(7B68EEee)'; end
function neon         -d "Theme: pink/cyan";    _apply-kitty-theme neon         'rgba(00f0ffee)'; end
function nord         -d "Theme: nord frost";   _apply-kitty-theme nord         'rgba(88c0d0ee)'; end
function serene       -d "Theme: cool cyan";    _apply-kitty-theme serene       'rgba(8b9ad8ee)'; end
function calliope     -d "Theme: cosmic blue";  _apply-kitty-theme calliope     'rgba(7297BBee)'; end
function ember        -d "Theme: amber dusk";   _apply-kitty-theme ember        'rgba(D69A73ee)'; end
function mono         -d "Theme: monochrome";   _apply-kitty-theme mono         'rgba(C3C3C3ee)'; end

# Full SYSTEM theme switch (wallpapers + waybar + apps + vibe).
# Bare `theme` opens the same rofi picker as the waybar click.
# (the functions above only reskin the current terminal window)
function theme -d "Apply a full system theme"
    command theme $argv
end
complete -c theme -f -a "(path basename ~/.dotfiles/themes/*/)"

# Philips Hue — office group (see ~/.config/hue/config.json)
function hue -d "Philips Hue: on/off/theme/color for office lights"
    ~/.dotfiles/bin/.bin/hue $argv
end
function lights -d "Hue office lights on"
    ~/.dotfiles/bin/.bin/hue on
end
function dark -d "Hue office lights off"
    ~/.dotfiles/bin/.bin/hue off
end
complete -c hue -f -a "pair on off toggle status groups theme color bri config"
