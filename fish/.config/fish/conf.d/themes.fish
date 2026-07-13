# Bare theme commands: type the theme name in any kitty window to reskin
# just that window (kitty colors + hyprland border). No claude-code launch.
# Companion to the cc* launchers in config.fish.

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

    if test -n "$KITTY_LISTEN_ON"
        kitty @ --to "$KITTY_LISTEN_ON" set-colors --configured $kitty_conf 2>/dev/null
    end

    if test -n "$KITTY_PID"; and test -n "$border"
        hyprctl dispatch setprop "pid:$KITTY_PID" active_border_color "$border" &>/dev/null
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

# Full SYSTEM theme switch (wallpapers + waybar + apps + vibe): `theme <name>`
# (the bare names above only reskin the current terminal window)
function theme -d "Apply a full system theme"
    if test -z "$argv[1]"
        echo "usage: theme <name>  —  "(command ls ~/.dotfiles/themes | string join ', ')
        return 1
    end
    ~/.dotfiles/bin/.bin/theme-switcher.sh apply $argv[1]
end
complete -c theme -f -a "(command ls ~/.dotfiles/themes)"
