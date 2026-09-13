if status is-interactive
    # aliases
    alias bots 'herdr session attach bots'
    alias copy 'wl-copy'
    alias paste 'wl-paste'
    alias dots 'cd ~/.dotfiles'
    alias dyn 'herdr --session dynasty'
    alias home 'cd ~/'
    alias hypr 'cd ~/.dotfiles/hypr/.config/hypr/'
    alias ls 'eza -l --icons --color=auto --group-directories-first'
    alias ll 'eza -l --icons --color=auto --group-directories-first'
    alias la 'eza -la --icons --color=auto --group-directories-first'
    alias lt 'eza -T --icons --color=auto --group-directories-first'
    alias y 'yazi'
    alias gs 'git status'
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
    function codex --wraps codex --description 'Codex CLI; -c resumes the latest chat'
        set -l codex_args $argv
        if test (count $argv) -eq 1; and test "$argv[1]" = -c
            set codex_args resume --last
        end

        if set -q HERDR_ENV
            command codex $codex_args
            return $status
        end

        # Standalone Codex transfers transient notification ownership to
        # agent-cue. Direct binary invocations and Herdr keep native ownership.
        set -lx AGENT_CUE_OWNS_CODEX_MAKO 1
        command codex -c 'tui.notifications=false' $codex_args
    end
    function __cc_slug; basename (pwd) | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | string trim -c '-' | string sub -l 30; end
    function cc; set -q INTER_SESSION_NAME; or set -lx INTER_SESSION_NAME (__cc_slug); claude --allow-dangerously-skip-permissions --permission-mode auto $argv; end
    function ccd; set -lx INTER_SESSION_NAME discord-(__cc_slug); set -lx INTER_SESSION_LABEL "discord channel"; claude --name io --allow-dangerously-skip-permissions --permission-mode auto --effort xhigh --settings ~/.claude/channels/discord/io_settings.json --channels plugin:discord@claude-plugins-official --append-system-prompt-file ~/.claude/channels/discord/io_bot.md $argv; end
    function cct; set -lx INTER_SESSION_NAME telegram-(__cc_slug); set -lx INTER_SESSION_LABEL "telegram channel"; claude --name as_dev --permission-mode dontAsk --effort xhigh --settings ~/.claude/channels/telegram/as_dev_settings.json --channels plugin:telegram@claude-plugins-official --append-system-prompt-file ~/.claude/channels/telegram/as_dev_bot.md $argv; end
    function ccm; _apply-kitty-theme cyber 'rgba(3D6390AA)'; set -x TTS_VOICE mustang; set -lx INTER_SESSION_NAME mustang-(__cc_slug); set -lx INTER_SESSION_LABEL "Mustang — strategic, dry wit"; if test (count $argv) -eq 0; cc --append-system-prompt-file ~/.claude/agents/mustang.md "/color blue"; else; cc --append-system-prompt-file ~/.claude/agents/mustang.md $argv; end; end
    function ccv; _apply-kitty-theme ashen 'rgba(8B2222ee)'; set -x TTS_VOICE velise; set -lx INTER_SESSION_NAME velise-(__cc_slug); set -lx INTER_SESSION_LABEL "Velise — sharp, analytical"; if test (count $argv) -eq 0; cc --append-system-prompt-file ~/.claude/agents/velise.md "/color red"; else; cc --append-system-prompt-file ~/.claude/agents/velise.md $argv; end; end
    function cca; _apply-kitty-theme aegis 'rgba(d79921ee)'; set -lx INTER_SESSION_NAME aegis-(__cc_slug); set -lx INTER_SESSION_LABEL "Aegis (yellow)"; if test (count $argv) -eq 0; cc "/color yellow"; else; cc $argv; end; end
    function ccj; _apply-kitty-theme jade 'rgba(2DD5B7ee)'; set -lx INTER_SESSION_NAME jade-(__cc_slug); set -lx INTER_SESSION_LABEL "Jade (green)"; if test (count $argv) -eq 0; cc "/color green"; else; cc $argv; end; end
    function ccl; _apply-kitty-theme lavender 'rgba(7B68EEee)'; set -lx INTER_SESSION_NAME lavender-(__cc_slug); set -lx INTER_SESSION_LABEL "Lavender (purple)"; if test (count $argv) -eq 0; cc "/color purple"; else; cc $argv; end; end
    function ccn; _apply-kitty-theme neon 'rgba(00f0ffee)'; set -lx INTER_SESSION_NAME neon-(__cc_slug); set -lx INTER_SESSION_LABEL "Neon (pink)"; if test (count $argv) -eq 0; cc "/color pink"; else; cc $argv; end; end
    function ccs; _apply-kitty-theme serene 'rgba(8b9ad8ee)'; set -lx INTER_SESSION_NAME serene-(__cc_slug); set -lx INTER_SESSION_LABEL "Serene (cyan)"; if test (count $argv) -eq 0; cc "/color cyan"; else; cc $argv; end; end
    function ccc; _apply-kitty-theme crimson-gray 'rgba(84a0c6AA)'; set -lx INTER_SESSION_NAME iceberg-(__cc_slug); set -lx INTER_SESSION_LABEL "Iceberg"; cc $argv; end
    alias pavu 'flatpak run com.saivert.pwvucontrol'
    alias wm 'wiremix'
    alias stfu '$HOME/workspace/ai/tts-daemon/.venv/bin/python $HOME/workspace/ai/tts-daemon/tts_client.py kill >/dev/null 2>&1'
    alias tts-stop 'systemctl --user stop tts-daemon-v2'
    alias tts-start 'systemctl --user start tts-daemon-v2'

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
set -l gcloud_init ~/Downloads/google-cloud-sdk/path.fish.inc
if test -f $gcloud_init
    source $gcloud_init
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
    set -l prev_theme
    if test -n "$slug"
        set -lx AGENT_CUE_THEME $slug
        if test -n "$KITTY_PID"; and test -f ~/.local/state/agent-cue/term-theme/$KITTY_PID
            set prev_theme (string trim < ~/.local/state/agent-cue/term-theme/$KITTY_PID)
        end
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
        # bare theme command may have applied is not recorded anywhere. The Lua
        # form is required since 0.55; the old `setprop` syntax is a parse error
        # that fails silently into the &>/dev/null.
        if test -n "$KITTY_PID"
            for prop in active_border_color inactive_border_color
                hyprctl dispatch "hl.dsp.window.set_prop({ window = \"pid:$KITTY_PID\", prop = \"$prop\", value = \"unset\" })" &>/dev/null
            end
            if test -n "$prev_theme"
                ~/.dotfiles/bin/.bin/theme-term.sh --record $KITTY_PID $prev_theme
            else
                ~/.dotfiles/bin/.bin/theme-term.sh --forget $KITTY_PID
            end
        end
    end

    return $st
end

function grok --wraps grok --description 'Launch grok edge-to-edge under the grok-night theme'
    _tui-run grok-night grok $argv
end

function hunk --wraps hunk --description 'Launch hunk edge-to-edge'
    _tui-run '' hunk $argv
end


# Added by Antigravity CLI installer
set -gx PATH "/home/curator/.local/bin" $PATH
