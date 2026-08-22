function update --description 'Pre-flight brief (CVEs, flagged AUR, upstream notes) + LLM triage, then the full sweep: repos+AUR(--devel), npm globals, flatpak, pipx, self-updaters, then a post-sweep LLM debrief'
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
# nothing pending, gate passed) and only the declined gate must skip it. The
# debrief at the end inherits that exact contract: it fires whenever the sweep
# ran, never when the operator said n.
function __update_extras --description 'npm globals, flatpak, pipx, self-updaters; gateway restart; reboot/dotfiles nudges; LLM debrief'
    # npm globals — pacman/yay are blind to these (openclaw, @openai/codex backend, pi).
    set -l oc_before (openclaw --version 2>/dev/null)
    set -l cx_before (codex --version 2>/dev/null)
    npm update -g
    set -l oc_after (openclaw --version 2>/dev/null)
    set -l cx_after (codex --version 2>/dev/null)

    # pi itself moved with npm above; its extensions install to ~/.pi/agent/{npm,git}
    # and never see a package manager. Pinned git @refs are skipped by design.
    command -q pi; and pi update --extensions

    # Other managers outside yay.
    command -q flatpak; and flatpak update -y
    command -q pipx; and pipx upgrade-all

    # Self-updaters in ~/.local/bin — no package manager can see these, so without
    # an explicit call they never move. claude's autoUpdates is off by design
    # (a native-install swap mid-session is worse than being a day behind), which
    # makes this line the only thing that ever advances it.
    command -q claude; and claude update
    # herdr for the same reason as claude, and with sharper teeth: it is the launch
    # path for dynasty's seats, and 0.7.5 rewrote `agent start` outright. A swap
    # while a bench is mid-run breaks it in flight, so it moves here and only here.
    command -q herdr; and herdr update
    command -q uv; and uv self update
    # codexbar left pacman 2026-07-30: the AUR package froze at 0.42.1 while
    # upstream kept shipping weekly, so releases come straight from GitHub now.
    # It has no self-update subcommand — the function below is the whole updater.
    # VERSION reads bracket the call so the debrief can report codexbar movement.
    set -l cb_before (cat $HOME/.local/lib/codexbar/VERSION 2>/dev/null | string trim)
    __update_codexbar
    set -l cb_after (cat $HOME/.local/lib/codexbar/VERSION 2>/dev/null | string trim)

    # `openclaw update` has a habit of silently dropping plugins out of the config
    # (npm 12 bug): they vanish from plugins.allow and flip to enabled:false, the
    # gateway restarts clean, and nothing tells you until the plugin's absence
    # bites days later. Check before the restart, so the warning isn't buried
    # under systemctl output. Captured rather than run blind, so the debrief
    # knows whether it warned; the lines are re-echoed unchanged.
    set -l plugin_warn (__update_check_openclaw_plugins)
    for w in $plugin_warn
        echo $w
    end

    # Restart the household gateway only if its runtime changed (openclaw OR the codex backend).
    set -l gateway_restart "not fired — substrate steady"
    if test "$oc_before" != "$oc_after"; or test "$cx_before" != "$cx_after"
        set gateway_restart "fired — substrate changed"
        echo "Substrate changed (openclaw: $oc_before -> $oc_after | codex: $cx_before -> $cx_after) — restarting gateway + mirrors"
        systemctl --user restart openclaw-gateway.service household-mirror.service \
            discord-mirror.service activator.service
    end

    # --- non-destructive nudges ---
    set -l krun (uname -r)
    set -l kins (pacman -Q linux 2>/dev/null | string split ' ')[2]
    set -l reboot_note "not needed"
    if test -n "$kins"; and test (string replace -a '.' '-' -- $krun) != (string replace -a '.' '-' -- $kins)
        set reboot_note "pending — running $krun, installed $kins"
        echo "⚠ reboot pending: running $krun, installed $kins"
    end

    set -l df_dirty (git -C ~/.dotfiles status --porcelain 2>/dev/null)
    set -l df_note clean
    if test -n "$df_dirty"
        set df_note (count $df_dirty)" uncommitted entries"
        echo "✎ dotfiles uncommitted (run `git acp \"msg\"` when ready):"
        git -C ~/.dotfiles status --short
    end

    # ── the debrief ────────────────────────────────────────────────────────────
    # Notes, not raw vars: the payload has to read as prose edges (absent /
    # fresh / unchanged / a -> b), never as blank fields a model might invent
    # around.
    set -l oc_note (__update_ver_note "$oc_before" "$oc_after")
    set -l cx_note (__update_ver_note "$cx_before" "$cx_after")
    set -l cb_note (__update_ver_note "$cb_before" "$cb_after")
    set -l plugins_note clean
    test -n "$plugin_warn"; and set plugins_note "warned — plugins missing from config"

    set -l facts "openclaw: $oc_note
 codex backend: $cx_note
 gateway restart: $gateway_restart
 openclaw plugin check: $plugins_note
 reboot: $reboot_note
 dotfiles: $df_note
 codexbar: $cb_note"

    __update_summary "$facts"
end

# The close-out counterpart to the triage in `update`: what the sweep actually
# did, at a glance instead of in scrollback. Same hermetic claude -p call as the
# triage (opus, empty setting sources, strict MCP, no session, no tools,
# timeout) and the same plain-text-only rule for the reply. One deliberate
# difference in the failure mode: the triage prints an "(unavailable)"
# fallback because its facts ARE the briefing, but this is garnish on a sweep
# that already finished — if the model cannot answer, it vanishes without a
# trace. Hence the tty-gated placeholder: piped, a "reading…" line could never
# be repainted and would leak into captured output.
function __update_summary --description 'LLM debrief after the sweep: substrate deltas, restart, reboot, dotfiles'
    set -l facts $argv[1]
    # opus for the same measured reason as the triage — see the note at the top.
    set -l model opus
    set -l persona "You are a terse Arch Linux maintainer briefing the owner of this box. You are blunt, you never pad, and you never assert a fact you were not given."
    set -l prompt "Post-sweep debrief for a system update. These are the deterministic facts — versions of the npm-managed agent substrate before and after the sweep (openclaw, the codex backend), whether the household gateway restarted because its substrate changed, whether the openclaw plugin-config check warned, kernel reboot status, dotfiles cleanliness, and the codexbar CLI version:

$facts

The package-manager output has already scrolled past him; this is the one-glance version of where the box now stands. Lead with what moved and what it means for the running household agents, then anything that still needs him — a pending reboot, dropped plugins, uncommitted dotfiles. Version numbers speak for themselves; never invent deltas, causes or advisories the facts do not contain. If nothing moved and nothing needs him, say so in one line and stop.

He already watched it run; he wants the close-out, not a re-read. Two or three sentences, hard maximum — one per line, each under about twenty words. Dense, not chatty; drop every word that is not load-bearing. Plain text only: no markdown, no asterisks, no backticks, no headers, no bullets, no preamble, no sign-off. The terminal renders none of it and it will show up as literal punctuation."

    # Fail-open, silently. The sweep is done; nothing here may read as trouble.
    command -q claude; or return 0

    set -l tty 0
    if isatty stdout
        set tty 1
    end
    echo
    if test $tty -eq 1
        echo "  debrief   reading…"
    end

    set -l reply
    set reply (timeout 60 claude -p "$prompt" --model $model \
        --system-prompt "$persona You have no tools and no network: reason only from the payload." \
        --setting-sources '' --strict-mcp-config --no-session-persistence \
        --allowed-tools '' 2>/dev/null)
    # The exit status travels with the substitution. A claude that errors (quota,
    # auth, forced update) prints its grievance to stdout, and without this
    # check that text would masquerade as the debrief.
    set -l rc $status

    # Paint the answer over the placeholder (tty only — piped, the cursor
    # escapes would leak into the output).
    if test $tty -eq 1
        tput cuu1 2>/dev/null
        tput el 2>/dev/null
    end
    if test $rc -ne 0; or test -z "$reply[1]"
        if test $tty -eq 1
            # eat the blank line too — the skip is meant to be invisible
            tput cuu1 2>/dev/null
            tput el 2>/dev/null
        end
        return 0
    end

    set -l first 1
    for line in $reply
        if test -n "$line"
            if test $first -eq 1
                echo "  debrief   $line"
                set first 0
            else
                echo "            $line"
            end
        end
    end
end

# The CLI reads its version from a VERSION file resolved relative to argv[0],
# which is why ~/.local/bin/codexbar is a two-line sh wrapper and must never
# become a symlink: symlinked, --version drops the number and this function
# would re-download on every sweep. Layout mirrors what the AUR package did
# system-side: real binary + VERSION in ~/.local/lib/codexbar, wrapper in bin.
function __update_codexbar --description 'Pull the latest CodexBar CLI release from GitHub when upstream is ahead'
    set -l dir $HOME/.local/lib/codexbar
    test -x $dir/CodexBarCLI; or return 0
    command -q jq; or return 0

    set -l installed (cat $dir/VERSION 2>/dev/null | string trim)
    set -l latest (curl -sf --max-time 15 \
        https://api.github.com/repos/steipete/CodexBar/releases/latest \
        | jq -r '.tag_name // empty' | string replace -r '^v' '')

    # Fail loud but never block: like the brief, this is advisory tooling and
    # the sweep must finish whether or not GitHub answers.
    if test -z "$latest"
        echo "⚠ codexbar: release check failed — still on $installed"
        return 0
    end
    test "$latest" != "$installed"; or return 0

    echo "codexbar $installed -> $latest"
    set -l tarball CodexBarCLI-v$latest-linux-x86_64.tar.gz
    set -l base https://github.com/steipete/CodexBar/releases/download/v$latest
    set -l tmp (mktemp -d -t codexbar-up.XXXXXX)

    if not curl -sfL --max-time 300 -o $tmp/$tarball $base/$tarball
        echo "⚠ codexbar: download failed — still on $installed"
        rm -rf $tmp
        return 0
    end

    # The published .sha256 embeds the CI runner's build path, so
    # `sha256sum -c` cannot read it — compare digests by hand.
    set -l want (curl -sfL --max-time 15 $base/$tarball.sha256 | awk '{print $1}')
    set -l got (sha256sum $tmp/$tarball | awk '{print $1}')
    if test -z "$want"; or test "$want" != "$got"
        echo "⚠ codexbar: checksum mismatch — keeping $installed"
        rm -rf $tmp
        return 0
    end

    tar xzf $tmp/$tarball -C $tmp
    install -m755 $tmp/CodexBarCLI $dir/CodexBarCLI
    install -m644 $tmp/VERSION $dir/VERSION

    # Newer providers (zai, openrouter, xai, ...) are JS plugins shipped in a
    # resource bundle the CLI loads from *next to the executable* — installing
    # only the binary leaves them failing with "CodexBarCore resource bundle is
    # missing". Built-in Swift providers (claude/codex/grok) keep working, so
    # the breakage looks provider-specific rather than like a bad install.
    if test -d $tmp/CodexBar_CodexBarCore.bundle
        rm -rf $dir/CodexBar_CodexBarCore.bundle
        cp -r $tmp/CodexBar_CodexBarCore.bundle $dir/
    end

    rm -rf $tmp
    echo "codexbar now "(codexbar --version 2>/dev/null | string replace 'CodexBar ' '')
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

# Prose edges for the debrief facts, because a blank field reads as an error to
# a model told never to invent: blank after-capture means the binary is absent
# (callers capture with stderr redirected), blank-before-with-after means this
# sweep installed it fresh, equal non-empty means no movement.
function __update_ver_note --description 'Render a before/after version pair for the debrief facts'
    set -l before $argv[1]
    set -l after $argv[2]
    if test -z "$after"
        echo absent
    else if test -z "$before"
        echo "freshly installed at $after"
    else if test "$before" = "$after"
        echo "$after (unchanged)"
    else
        echo "$before -> $after"
    end
end
