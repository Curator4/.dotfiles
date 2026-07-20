function update --description 'Pre-flight brief (CVEs, flagged AUR, upstream notes) + LLM triage, then the full sweep: repos+AUR(--devel), npm globals, flatpak, pipx, self-updaters'
    # Measured 2026-07-14 over 3 runs each on a 30-package payload: sonnet ~6.0s
    # (tight), opus ~7.5s (one 10.7s outlier). Near enough the same -- the wait is
    # CLI startup and model load, not the tier, so there is no speed argument for
    # the cheaper model here. Opus stays because it obeyed the one rule that
    # matters: sonnet buried an active AUR-compromise advisory under routine CVE
    # patching, and "the advisory leads" is the whole point of the briefing.
    set -l model opus

    set -l tool $HOME/workspace/ai/household-oc/tools/update-brief/update-brief.py
    set -l brief (mktemp -t update-brief.XXXXXX.json)

    # --deep is ours, not yay's: it lets the model leave the box and read release
    # notes for packages the feed does not already cover. Everything else in $argv
    # passes through to yay untouched.
    set -l deep 0
    set -l yay_args
    for a in $argv
        if test "$a" = --deep
            set deep 1
        else
            set -a yay_args $a
        end
    end

    # The brief is advisory. Anything that goes wrong below falls through to a
    # plain sweep -- the operator's update is never held hostage to this tooling.
    if not test -x $tool
        echo "⚠ update-brief missing — running unbriefed"
        rm -f $brief
        yay -Syu --devel $yay_args
        __update_extras
        return 0
    end

    echo
    if not $tool --json-out $brief
        rm -f $brief
        yay -Syu --devel $yay_args
        __update_extras
        return 0
    end

    # No pacman deltas still means work to do: the brief reads pacman's view only,
    # so it cannot see VCS packages with new upstream commits (that is what --devel
    # below checks) and it knows nothing about npm, flatpak or the self-updaters.
    # Skipping straight out here is what let uv drift fourteen releases behind.
    if not jq -e '.pending | length > 0' $brief >/dev/null 2>&1
        rm -f $brief
        echo "  No repo updates pending — checking VCS packages and other managers."
        echo
        yay -Syu --devel $yay_args
        __update_extras
        return 0
    end

    # ── the read ──────────────────────────────────────────────────────────────
    # Triage, not gating. Thirty package names carry no signal on their own, and
    # the sensor above structurally cannot tell you which three to care about --
    # that takes knowing what the packages *are*, which is the one thing a model
    # brings. It gets the facts and the matching upstream notes inlined; it is
    # never asked to go find anything (see update-brief.py's feed_context).
    #
    # Hermetic on purpose. --setting-sources '' keeps CLAUDE.md, user settings and
    # MCP servers out of the call, so `update` reads identically whether it is run
    # from $HOME or from inside a project checkout. Without it, the brief would
    # quietly inherit the context of whatever directory you happened to be in.
    set -l facts (cat $brief | string collect)
    set -l persona "You are a terse Arch Linux maintainer briefing the owner of this box. You are blunt, you never pad, and you never assert a fact you were not given."
    set -l prompt "Pre-flight triage for a system update. These are the deterministic facts — packages pending with version deltas, CVEs each upgrade closes, AUR packages the yay hook deselected, reboot implications, and any upstream release notes that matched what is pending:

$facts

The list is long and mostly boring; that is precisely the problem you are solving. Tell him which of these actually matter and why, and what to keep in mind afterwards. Judge by what the packages ARE: a major-version jump in a driver, a kernel, a shell, a compositor or the audio stack earns a line; a leaf-library point release does not. Call out anything needing a manual step, anything that will change behaviour he will notice, and anything flagged. An arch-news advisory outranks everything else in the payload. If it is genuinely all routine, say so in one line and stop.

He is standing at a terminal prompt waiting to type Y. Four sentences, hard maximum — one per line, each under about twenty words. Dense, not chatty; drop every word that is not load-bearing. Plain text only: no markdown, no asterisks, no backticks, no headers, no bullets, no preamble, no sign-off. The terminal renders none of it and it will show up as literal punctuation."

    set -l reply
    echo
    if test $deep -eq 1
        echo "  triage    reading (deep — may search)…"
        set reply (timeout 180 claude -p "$prompt" --model $model \
            --system-prompt "$persona Where the payload gives you no upstream note for a package that looks consequential, you may search for its release notes. Cite nothing you did not read." \
            --setting-sources '' --strict-mcp-config --no-session-persistence \
            --allowed-tools WebSearch WebFetch 2>/dev/null)
    else
        echo "  triage    reading…"
        set reply (timeout 60 claude -p "$prompt" --model $model \
            --system-prompt "$persona You have no tools and no network: reason only from the payload. If depth is missing for a package that looks consequential, say so in as few words as possible rather than guessing — the operator can re-run with --deep." \
            --setting-sources '' --strict-mcp-config --no-session-persistence \
            --allowed-tools '' 2>/dev/null)
    end

    # Repaint the placeholder line with the actual answer (only when we own a
    # terminal — piped, the cursor escapes would leak into the output).
    if isatty stdout
        tput cuu1 2>/dev/null
        tput el 2>/dev/null
    end
    if test -n "$reply"
        set -l first 1
        for line in $reply
            if test -n "$line"
                if test $first -eq 1
                    echo "  triage    $line"
                    set first 0
                else
                    echo "            $line"
                end
            end
        end
    else
        echo "  triage    (unavailable — the facts above stand on their own)"
    end

    rm -f $brief

    # ── the gate ──────────────────────────────────────────────────────────────
    # One gate for the whole sweep, not just the pacman half. A gate that guards
    # some of the work is a gate you stop trusting: "n" means nothing runs.
    echo
    read -l -P '  Proceed? [Y/n] ' answer
    switch (string lower -- (string trim -- $answer))
        case '' y yes
            echo
            yay -Syu --devel $yay_args
            __update_extras
        case '*'
            echo "  Aborted — nothing installed."
            return 1
    end
end

# Everything pacman cannot see, plus the post-update checks. Split out because
# four separate paths through `update` reach it (brief missing, brief failed,
# nothing pending, gate passed) and only the declined gate must skip it.
function __update_extras --description 'npm globals, flatpak, pipx, self-updaters; gateway restart; reboot/dotfiles nudges'
    # npm globals — pacman/yay are blind to these (openclaw, @openai/codex backend, gemini-cli, pi).
    set -l oc_before (openclaw --version 2>/dev/null)
    set -l cx_before (codex --version 2>/dev/null)
    npm update -g
    set -l oc_after (openclaw --version 2>/dev/null)
    set -l cx_after (codex --version 2>/dev/null)

    # Other managers outside yay.
    command -q flatpak; and flatpak update -y
    command -q pipx; and pipx upgrade-all

    # Self-updaters in ~/.local/bin — no package manager can see these, so without
    # an explicit call they never move. claude's autoUpdates is off by design
    # (a native-install swap mid-session is worse than being a day behind), which
    # makes this line the only thing that ever advances it.
    command -q claude; and claude update
    command -q uv; and uv self update

    # `openclaw update` has a habit of silently dropping plugins out of the config
    # (npm 12 bug): they vanish from plugins.allow and flip to enabled:false, the
    # gateway restarts clean, and nothing tells you until the plugin's absence
    # bites days later. Check before the restart, so the warning isn't buried
    # under systemctl output.
    __update_check_openclaw_plugins

    # Restart the household gateway only if its runtime changed (openclaw OR the codex backend).
    if test "$oc_before" != "$oc_after"; or test "$cx_before" != "$cx_after"
        echo "Substrate changed (openclaw: $oc_before -> $oc_after | codex: $cx_before -> $cx_after) — restarting gateway + mirrors"
        systemctl --user restart openclaw-gateway.service household-mirror.service \
            discord-mirror.service activator.service
    end

    # --- non-destructive nudges ---
    set -l krun (uname -r)
    set -l kins (pacman -Q linux 2>/dev/null | string split ' ')[2]
    if test -n "$kins"; and test (string replace -a '.' '-' -- $krun) != (string replace -a '.' '-' -- $kins)
        echo "⚠ reboot pending: running $krun, installed $kins"
    end

    set -l df_dirty (git -C ~/.dotfiles status --porcelain 2>/dev/null)
    if test -n "$df_dirty"
        echo "✎ dotfiles uncommitted (run `git acp \"msg\"` when ready):"
        git -C ~/.dotfiles status --short
    end
end

# `$expected` is a declaration, not a discovery. The config on its own cannot tell
# "the npm 12 bug ate this plugin" apart from "the operator switched it off on
# purpose" — both look like allow-missing + enabled:false. So intent gets written
# down here, and anything not listed is simply not this check's business.
#
# codex is deliberately absent. As of 2026-07-20 it fails to register with
# "openKeyedStore is only available for trusted plugins in this release" — a
# trust-model rejection, not the allowlist drop this check exists to catch.
# Listing it would produce a warning on every run that re-adding it wouldn't fix.
function __update_check_openclaw_plugins --description 'Warn when an openclaw update drops a load-bearing plugin from the config'
    set -l expected discord

    set -l cfg $HOME/.openclaw/openclaw.json
    command -q jq; or return 0
    test -r $cfg; or return 0

    set -l broken
    for p in $expected
        set -l allowed (jq -r --arg p $p '.plugins.allow | index($p) != null' $cfg 2>/dev/null)
        set -l enabled (jq -r --arg p $p '.plugins.entries[$p].enabled // false' $cfg 2>/dev/null)
        if test "$allowed" != true; or test "$enabled" != true
            set -a broken "$p (allow=$allowed enabled=$enabled)"
        end
    end

    set -q broken[1]; or return 0

    echo "⚠ openclaw plugins missing from config — an update likely dropped them:"
    for b in $broken
        echo "    $b"
    end
    echo "  Fix in ~/.openclaw/openclaw.json: add the name to .plugins.allow AND set"
    echo "  .plugins.entries.<name>.enabled = true. The gateway restart below will not"
    echo "  repair this on its own."
end
