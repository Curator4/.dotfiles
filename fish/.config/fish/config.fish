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
    function ccd; set -lx INTER_SESSION_NAME discord-(__cc_slug); set -lx INTER_SESSION_LABEL "discord channel"; test -n "$KITTY_PID"; and set -l __ws9 (hyprctl activewindow -j 2>/dev/null | jq -r '.pid'); and test "$__ws9" = "$KITTY_PID"; and hyprctl dispatch movetoworkspacesilent 9 &>/dev/null; claude --allow-dangerously-skip-permissions --permission-mode auto --model claude-opus-4-8 --effort xhigh --settings ~/.claude/channels/discord/io_settings.json --channels plugin:discord@claude-plugins-official --append-system-prompt-file ~/.claude/channels/discord/io_bot.md $argv; end
    function cct; set -lx INTER_SESSION_NAME telegram-(__cc_slug); set -lx INTER_SESSION_LABEL "telegram channel"; test -n "$KITTY_PID"; and set -l __ws9 (hyprctl activewindow -j 2>/dev/null | jq -r '.pid'); and test "$__ws9" = "$KITTY_PID"; and hyprctl dispatch movetoworkspacesilent 9 &>/dev/null; claude --permission-mode dontAsk --model claude-opus-4-8 --effort xhigh --settings ~/.claude/channels/telegram/as_dev_settings.json --channels plugin:telegram@claude-plugins-official --append-system-prompt-file ~/.claude/channels/telegram/as_dev_bot.md $argv; end
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
# Do NOT export GITHUB_TOKEN here — it snapshots gh's rotating OAuth token at
# shell start, goes stale, and then shadows the working keyring auth (401s,
# blocks `gh auth refresh`). Tools needing a token: use `gh auth token` at call time.

# gcloud
if test -f ~/Downloads/google-cloud-sdk/path.fish.inc
    source ~/Downloads/google-cloud-sdk/path.fish.inc
end

# Conda lazy-loaded via conf.d/conda-lazy.fish — do NOT run 'conda init fish',
# it will re-add an eager init block here and kill startup time.

# OpenClaw Completion
source "/home/curator/.openclaw/completions/openclaw.fish"

# >>> grok installer >>>
fish_add_path $HOME/.grok/bin
# <<< grok installer <<<

# TUI launchers that run the app edge-to-edge, optionally under a theme.
#
# A TUI painting a solid canvas only ever paints *cells*. window_padding has no
# cells, so it keeps kitty's default background and the canvas stops 14pt short
# of the window edge — a frame in the wrong colour around apps like hunk. For a
# full-screen TUI that padding is dead space anyway, so drop it for the session
# rather than trying to colour-match it.
#
# Themed launchers additionally reskin the window. Colours are snapshotted and
# replayed, because theme-term.sh passes --configured, which rewrites the
# defaults new tabs inherit — without the replay the reskin is permanent.
#
# An empty slug means "no reskin, just reclaim the padding".
function _tui-run --description 'Run a TUI edge-to-edge, restoring kitty padding and colours on exit'
    set -l slug $argv[1]
    set -l cmd $argv[2..-1]

    # Outside kitty there is nothing to adjust, and theme-term.sh would target
    # whatever window happens to be focused. Under tmux every pane inherits the
    # server's KITTY_LISTEN_ON and KITTY_WINDOW_ID, which name the window tmux
    # first started in — not this one — so the restore could land on a stranger.
    # Both cases: run the command unadorned.
    if test -z "$KITTY_LISTEN_ON"; or test -n "$TMUX"
        command $cmd
        return $status
    end

    set -l kt kitty @ --to "$KITTY_LISTEN_ON"
    # Pin to this window, so losing focus mid-session cannot misdirect the
    # restore. Empty when kitty did not export an id, falling back to active.
    set -l target
    test -n "$KITTY_WINDOW_ID"; and set target --match id:$KITTY_WINDOW_ID

    # No --configured: the configured 14pt stays intact, so `default` restores.
    $kt set-spacing $target padding=0 2>/dev/null; or true

    set -l snapshot
    if test -n "$slug"
        set snapshot (mktemp)
        $kt get-colors $target >$snapshot 2>/dev/null; or true
        ~/.dotfiles/bin/.bin/theme-term.sh $slug 2>/dev/null; or true
    end

    command $cmd
    set -l st $status

    $kt set-spacing $target padding=default 2>/dev/null; or true

    if test -n "$snapshot"
        # --all --configured mirrors what theme-term.sh changed, so this is a
        # true inverse rather than a reset to kitty's startup colours.
        if test -s $snapshot
            $kt set-colors --all --configured $snapshot 2>/dev/null; or true
        end
        rm -f $snapshot
        # unset reverts to the hyprland.conf defaults — the per-window tint a
        # bare theme command may have applied is not recorded anywhere.
        if test -n "$KITTY_PID"
            hyprctl dispatch setprop "pid:$KITTY_PID" active_border_color unset &>/dev/null
            hyprctl dispatch setprop "pid:$KITTY_PID" inactive_border_color unset &>/dev/null
        end
    end

    return $st
end

function grok --wraps grok --description 'Launch grok edge-to-edge under the grok-night theme'
    _tui-run grok-night grok $argv
end

function codex --wraps codex --description 'Launch Codex edge-to-edge under the Jade theme'
    _tui-run jade codex -c 'tui.theme="jade"' $argv
end

function hunk --wraps hunk --description 'Launch hunk edge-to-edge'
    _tui-run '' hunk $argv
end
