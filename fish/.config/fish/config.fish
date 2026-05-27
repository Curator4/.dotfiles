if status is-interactive
    # aliases
    alias copy 'wl-copy'
    alias paste 'wl-paste'
    alias dots 'cd ~/.dotfiles'
    alias home 'cd ~/'
    alias hypr 'cd ~/.dotfiles/hypr/.config/hypr/'
    alias ls 'eza -l --icons --color=auto --group-directories-first'
    alias ll 'eza -l --icons --color=auto --group-directories-first'
    alias la 'eza -la --icons --color=auto --group-directories-first'
    alias lt 'eza -T --icons --color=auto --group-directories-first'
    alias y 'yazi'
    alias gs 'git status'
    alias themis '~/.bin/themis-entry'
    alias gb 'gator browse'
    alias cdb 'cd ~/workspace/bootdev/'
    alias cdw 'cd ~/workspace/'
    alias cdp 'cd ~/workspace/pnc/'
    alias cdpa 'cd ~/workspace/pnc/alarm-receiver/'
    alias cdd 'cd ~/.dotfiles'
    alias cdh 'cd ~/workspace/ai/household-oc/'
    alias cda 'cd ~/workspace/ai/'
    alias cdtts 'cd ~/workspace/ai/tts-daemon/'
    alias cdio 'cd ~/workspace/ai/io'
    alias docs 'cd ~/docs/'
    alias cddp 'cd ~/docs/pnc/'
    alias cdt 'cd ~/docs/pnc/tech-docs/'
    alias cdf 'cd ~/.dotfiles/fish/.config/fish'
    alias fishconfig 'nvim ~/.dotfiles/fish/.config/fish/config.fish'
    alias fishsource 'source ~/.config/fish/config.fish'
    alias nvc 'cd ~/.config/nvim'
    alias .. 'cd ..'
    alias ... 'cd ../..'
    alias .... 'cd ../../..'
    function rc; pkill -9 -f "claude-desktop-native"; claude-desktop-native &>/dev/null &; disown; end
    alias rdp-receiver 'xfreerdp3 /u:Administrator /p:Station1 /v:10.200.0.60 /sec:tls /cert:ignore /dynamic-resolution'
    alias gtree 'git log --oneline --graph -20'
    alias t 'tree -L'
    function __cc_slug; basename (pwd) | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | string trim -c '-' | string sub -l 30; end
    function cc; set -q INTER_SESSION_NAME; or set -lx INTER_SESSION_NAME (__cc_slug); claude --allow-dangerously-skip-permissions --permission-mode auto $argv; end
    function ccd; set -lx INTER_SESSION_NAME discord-(__cc_slug); set -lx INTER_SESSION_LABEL "discord channel"; cc --channels plugin:discord@claude-plugins-official $argv; end
    function ccm; test -n "$KITTY_LISTEN_ON"; and kitty @ --to "$KITTY_LISTEN_ON" set-colors --all --configured ~/.dotfiles/themes/cyber/kitty.conf 2>/dev/null; test -n "$KITTY_PID"; and hyprctl dispatch setprop "pid:$KITTY_PID" active_border_color "rgba(84a0c6AA)" &>/dev/null; set -x TTS_VOICE mustang; set -lx INTER_SESSION_NAME mustang-(__cc_slug); set -lx INTER_SESSION_LABEL "Mustang — strategic, dry wit"; if test (count $argv) -eq 0; cc --append-system-prompt-file ~/.claude/agents/mustang.md "/color blue"; else; cc --append-system-prompt-file ~/.claude/agents/mustang.md $argv; end; end
    function ccv; test -n "$KITTY_LISTEN_ON"; and kitty @ --to "$KITTY_LISTEN_ON" set-colors --all --configured ~/.dotfiles/themes/ashen/kitty.conf 2>/dev/null; test -n "$KITTY_PID"; and hyprctl dispatch setprop "pid:$KITTY_PID" active_border_color "rgba(8B2222ee)" &>/dev/null; set -x TTS_VOICE velise; set -lx INTER_SESSION_NAME velise-(__cc_slug); set -lx INTER_SESSION_LABEL "Velise — sharp, analytical"; if test (count $argv) -eq 0; cc --append-system-prompt-file ~/.claude/agents/velise.md "/color red"; else; cc --append-system-prompt-file ~/.claude/agents/velise.md $argv; end; end
    function cca; test -n "$KITTY_LISTEN_ON"; and kitty @ --to "$KITTY_LISTEN_ON" set-colors --all --configured ~/.dotfiles/themes/aegis/kitty.conf 2>/dev/null; test -n "$KITTY_PID"; and hyprctl dispatch setprop "pid:$KITTY_PID" active_border_color "rgba(d79921ee)" &>/dev/null; set -lx INTER_SESSION_NAME aegis-(__cc_slug); set -lx INTER_SESSION_LABEL "Aegis (yellow)"; if test (count $argv) -eq 0; cc "/color yellow"; else; cc $argv; end; end
    function ccj; test -n "$KITTY_LISTEN_ON"; and kitty @ --to "$KITTY_LISTEN_ON" set-colors --all --configured ~/.dotfiles/themes/jade/kitty.conf 2>/dev/null; test -n "$KITTY_PID"; and hyprctl dispatch setprop "pid:$KITTY_PID" active_border_color "rgba(2DD5B7ee)" &>/dev/null; set -lx INTER_SESSION_NAME jade-(__cc_slug); set -lx INTER_SESSION_LABEL "Jade (green)"; if test (count $argv) -eq 0; cc "/color green"; else; cc $argv; end; end
    function ccl; test -n "$KITTY_LISTEN_ON"; and kitty @ --to "$KITTY_LISTEN_ON" set-colors --all --configured ~/.dotfiles/themes/lavender/kitty.conf 2>/dev/null; test -n "$KITTY_PID"; and hyprctl dispatch setprop "pid:$KITTY_PID" active_border_color "rgba(7B68EEee)" &>/dev/null; set -lx INTER_SESSION_NAME lavender-(__cc_slug); set -lx INTER_SESSION_LABEL "Lavender (purple)"; if test (count $argv) -eq 0; cc "/color purple"; else; cc $argv; end; end
    function ccn; test -n "$KITTY_LISTEN_ON"; and kitty @ --to "$KITTY_LISTEN_ON" set-colors --all --configured ~/.dotfiles/themes/neon/kitty.conf 2>/dev/null; test -n "$KITTY_PID"; and hyprctl dispatch setprop "pid:$KITTY_PID" active_border_color "rgba(00f0ffee)" &>/dev/null; set -lx INTER_SESSION_NAME neon-(__cc_slug); set -lx INTER_SESSION_LABEL "Neon (pink)"; if test (count $argv) -eq 0; cc "/color pink"; else; cc $argv; end; end
    function ccs; test -n "$KITTY_LISTEN_ON"; and kitty @ --to "$KITTY_LISTEN_ON" set-colors --all --configured ~/.dotfiles/themes/serene/kitty.conf 2>/dev/null; test -n "$KITTY_PID"; and hyprctl dispatch setprop "pid:$KITTY_PID" active_border_color "rgba(8b9ad8ee)" &>/dev/null; set -lx INTER_SESSION_NAME serene-(__cc_slug); set -lx INTER_SESSION_LABEL "Serene (cyan)"; if test (count $argv) -eq 0; cc "/color cyan"; else; cc $argv; end; end
    function ccc; test -n "$KITTY_LISTEN_ON"; and kitty @ --to "$KITTY_LISTEN_ON" set-colors --all --configured ~/.dotfiles/themes/crimson-gray/kitty.conf 2>/dev/null; test -n "$KITTY_PID"; and hyprctl dispatch setprop "pid:$KITTY_PID" active_border_color "rgba(ccccccee)" &>/dev/null; set -lx INTER_SESSION_NAME crimson-(__cc_slug); set -lx INTER_SESSION_LABEL "Crimson Gray (mono)"; cc $argv; end
    alias pavu 'flatpak run com.saivert.pwvucontrol'
    alias wm 'wiremix'
    alias stfu 'pkill -f "python3 tts_hook.py"; pkill -f "python3 stream_tts.py"; pkill -f "python3 -c"; touch /tmp/tts-daemon/stopped 2>/dev/null'
    alias tts-stop 'systemctl --user stop vllm-tts'
    alias tts-start 'systemctl --user start vllm-tts'

    # starship prompt
    starship init fish | source

    # gator background start
    if not pgrep -f "gator agg" > /dev/null
        nohup gator agg 1m > /dev/null 2>&1 &
    end
end

# paths
fish_add_path ~/.local/opt/go/bin
fish_add_path ~/go/bin
fish_add_path ~/.local/bin
fish_add_path ~/.bin
fish_add_path ~/.npm-global/bin
fish_add_path ~/.turso

# env vars
set -x EDITOR nvim
set -x GITHUB_TOKEN $(gh auth token)

# gcloud
if test -f ~/Downloads/google-cloud-sdk/path.fish.inc
    source ~/Downloads/google-cloud-sdk/path.fish.inc
end

# Conda lazy-loaded via conf.d/conda-lazy.fish — do NOT run 'conda init fish',
# it will re-add an eager init block here and kill startup time.

# OpenClaw Completion
source "/home/curator/.openclaw/completions/openclaw.fish"
