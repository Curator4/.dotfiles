function update --description 'Pre-flight brief (CVEs, flagged AUR, upstream notes) + LLM triage, then yay -Syu'
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
    # plain yay -- the operator's update is never held hostage to this tooling.
    if not test -x $tool
        echo "⚠ update-brief missing — running yay unbriefed"
        rm -f $brief
        yay -Syu $yay_args
        return $status
    end

    echo
    if not $tool --json-out $brief
        rm -f $brief
        yay -Syu $yay_args
        return $status
    end

    if not jq -e '.pending | length > 0' $brief >/dev/null 2>&1
        rm -f $brief
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
    echo
    read -l -P '  Proceed? [Y/n] ' answer
    switch (string lower -- (string trim -- $answer))
        case '' y yes
            echo
            yay -Syu $yay_args
        case '*'
            echo "  Aborted — nothing installed."
            return 1
    end
end
