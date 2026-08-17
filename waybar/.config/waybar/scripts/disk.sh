#!/usr/bin/env bash
# Bar disk % = df's Use% (excludes the ext4 root reserve), so waybar,
# aegis's reports, and disk-space-check all read the same number.
df -h --output=pcent,used,size,avail / | awk 'NR==2 {
    gsub(/[[:space:]]/, "", $1)
    printf "{\"text\":\"%s\",\"tooltip\":\"Disk /: %s of %s used, %s free (df Use%%)\"}\n",
        $1, $2, $3, $4
}'
