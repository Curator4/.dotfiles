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
    alias cdh 'cd ~/'
    alias cda 'cd ~/workspace/ai/'
    alias cdtts 'cd ~/workspace/ai/tts-daemon/'
    alias cdio 'cd ~/workspace/ai/io'
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
    alias cc 'claude --allow-dangerously-skip-permissions --permission-mode acceptEdits'
    function ccm; test -n "$KITTY_LISTEN_ON"; and kitty @ --to "$KITTY_LISTEN_ON" set-colors --all --configured ~/.dotfiles/themes/aegis/kitty.conf 2>/dev/null; test -n "$KITTY_PID"; and hyprctl dispatch setprop "pid:$KITTY_PID" active_border_color "rgba(d79921AA)" &>/dev/null; echo -e "\e[1;33m━━━ Mustang ━━━\e[0m"; cc --append-system-prompt-file ~/.claude/agents/mustang.md --name Mustang $argv; end
    function ccv; test -n "$KITTY_LISTEN_ON"; and kitty @ --to "$KITTY_LISTEN_ON" set-colors --all --configured ~/.dotfiles/themes/ashen/kitty.conf 2>/dev/null; test -n "$KITTY_PID"; and hyprctl dispatch setprop "pid:$KITTY_PID" active_border_color "rgba(8B2222ee)" &>/dev/null; echo -e "\e[1;35m━━━ Velise ━━━\e[0m"; cc --append-system-prompt-file ~/.claude/agents/velise.md --name Velise $argv; end
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

# gcloud
if test -f ~/Downloads/google-cloud-sdk/path.fish.inc
    source ~/Downloads/google-cloud-sdk/path.fish.inc
end

# Conda lazy-loaded via conf.d/conda-lazy.fish — do NOT run 'conda init fish',
# it will re-add an eager init block here and kill startup time.

