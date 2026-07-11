#!/usr/bin/env bash
# Waybar custom module for OpenRouter credits (via the codexbar CLI).
# codexbar's openrouter provider pegs primary.usedPercent at 100 (a credit
# balance doesn't fit its usage-window model), so the generic codexbar.sh
# wrapper renders a permanent red "100%". This module bypasses the wrapper
# and shows the balance in dollars instead; critical = weekly key headroom
# or account balance running low (the failure mode that silently knocks
# GLM out of council runs).
#
# Last good snapshot is cached so a transient API failure dims (stale)
# rather than blanking the module.

set -u

CODEXBAR="${CODEXBAR_BIN:-${HOME}/.local/bin/codexbar}"
CACHE="${XDG_CACHE_HOME:-${HOME}/.cache}/codexbar-waybar/openrouter.json"
mkdir -p "$(dirname "$CACHE")"

WEEKLY_HEADROOM_CRIT="${OPENROUTER_WEEKLY_CRIT:-3}"   # $ left on key's weekly limit
BALANCE_CRIT="${OPENROUTER_BALANCE_CRIT:-5}"          # $ left on the account

raw="$("$CODEXBAR" usage --provider openrouter --json 2>/dev/null)"

out="$(jq -ce --argjson wcrit "$WEEKLY_HEADROOM_CRIT" --argjson bcrit "$BALANCE_CRIT" '
  .[0].usage.openRouterUsage as $u
  | ($u.balance * 10 | round / 10) as $bal
  | (if ($u.keyLimit // 0) > 0 then $u.keyLimit - $u.keyUsageWeekly else null end) as $headroom
  | {
      text: ("$" + ($bal | tostring)),
      tooltip: (
        "OpenRouter balance: $" + ($u.balance * 100 | round / 100 | tostring)
        + (if $headroom != null
           then "\nWeekly key: $" + ($u.keyUsageWeekly * 100 | round / 100 | tostring)
                + " / $" + ($u.keyLimit | tostring) + " used"
           else "" end)
        + "\nMonthly: $" + ($u.keyUsageMonthly * 100 | round / 100 | tostring)
      ),
      class: (if ($headroom != null and $headroom < $wcrit) or $u.balance < $bcrit
              then "critical" else "" end),
      percentage: ($u.usedPercent | floor)
    }' <<<"$raw" 2>/dev/null)"

if [[ -n "$out" ]]; then
    printf '%s\n' "$out" | tee "$CACHE"
elif [[ -f "$CACHE" ]]; then
    jq -c '.class = "stale"' "$CACHE"
else
    printf '{"text":"--","tooltip":"OpenRouter: no data","class":"stale"}\n'
fi
