#!/usr/bin/env bash
# Bar disk % = df's Use% (excludes the ext4 root reserve), so waybar,
# aegis's reports, and disk-space-check all read the same number.
# Shows the fuller of / and the filesystem holding $HOME (a separate /data
# partition on some boxes); the tooltip lists both.
paths=(/)
[ "$(stat -c %d "$HOME")" = "$(stat -c %d /)" ] || paths+=("$HOME")

df -h --output=target,pcent,used,size,avail "${paths[@]}" | awk 'NR > 1 {
    pct = $2; sub(/%/, "", pct)
    name = ($1 == "/") ? "/ (system)" : $1 " (your files)"
    tip = tip (tip == "" ? "" : "\\n") sprintf("%s: %s of %s used, %s free", name, $3, $4, $5)
    if (pct + 0 > max + 0) max = pct
}
END { printf "{\"text\":\"%s%%\",\"tooltip\":\"%s\"}\n", max, tip }'
