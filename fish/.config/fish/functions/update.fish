function update --description 'Pre-flight brief (CVEs, flagged AUR, reboot) + Aegis read, then yay -Syu'
    set -l tool $HOME/workspace/ai/household-oc/tools/update-brief/update-brief.py
    set -l brief (mktemp -t update-brief.XXXXXX.json)

    # The brief is advisory. Anything that goes wrong below falls through to a
    # plain yay -- the operator's update is never held hostage to this tooling.
    if not test -x $tool
        echo "⚠ update-brief missing — running yay unbriefed"
        rm -f $brief
        yay -Syu $argv
        return $status
    end

    echo
    if not $tool --json-out $brief
        rm -f $brief
        yay -Syu $argv
        return $status
    end

    if not jq -e '.pending | length > 0' $brief >/dev/null 2>&1
        rm -f $brief
        return 0
    end

    # ── Aegis's read ──────────────────────────────────────────────────────────
    # She adds judgment and release-note depth from her morning report and
    # feed-items. Hard-capped: a slow or dead agent must not stand between the
    # operator and his updates, so on timeout we simply proceed without her.
    set -l facts (cat $brief | string collect)
    set -l prompt "System update pre-flight on your own host. These are the deterministic facts for what is about to be installed:

$facts

Give the operator at most four short lines. Lead with anything that changes whether he should proceed right now: a security fix worth taking, a flagged AUR package worth reviewing before it is re-ticked, a reboot to plan for. Use your morning report and feed-items for release-note depth where you have it; do not research from scratch. If it is all routine, say so in one line. Prose only — no headers, no bullets, no preamble, no sign-off."

    echo
    echo "  aegis     reading…"
    set -l reply (timeout 60 openclaw agent --agent aegis --json --message "$prompt" 2>/dev/null \
        | jq -r '.result.payloads[0].text // empty' 2>/dev/null)

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
                    echo "  aegis     $line"
                    set first 0
                else
                    echo "            $line"
                end
            end
        end
    else
        echo "  aegis     (unavailable — the facts above stand on their own)"
    end

    rm -f $brief

    # ── the gate ──────────────────────────────────────────────────────────────
    echo
    read -l -P '  Proceed? [Y/n] ' answer
    switch (string lower -- (string trim -- $answer))
        case '' y yes
            echo
            yay -Syu $argv
        case '*'
            echo "  Aborted — nothing installed."
            return 1
    end
end
