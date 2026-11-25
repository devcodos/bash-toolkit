#!/usr/bin/env bash
# sysreport.sh - one-screen system health report
# Copyright (C) 2026 devcodos (https://github.com/devcodos)
# Licensed under GPL-3.0. See the LICENSE file in the repo root.
set -euo pipefail

threshold="${1:-80}"
if ! [[ "$threshold" =~ ^[0-9]+$ ]] || (( threshold < 1 || threshold > 100 )); then
    echo "Usage: $0 [disk_warn_percent]   (1-100, default 80)" >&2
    exit 9
fi

status=0

echo "== System report: $(hostname) =="
date
echo "Uptime: $(uptime -p)"
echo "Load (1/5/15 min): $(cut -d' ' -f1-3 /proc/loadavg)  on $(nproc) CPUs"

echo
echo "== Memory =="
free -h | awk 'NR==1 || /^Mem:/'

echo
echo "== Disk (warn at ${threshold}%) =="
while read -r use mount; do
    if (( use >= threshold )); then
        echo "WARNING  $mount is ${use}% full"
        status=1
    else
        echo "OK       $mount is ${use}% full"
    fi
done < <(df -P -x tmpfs -x devtmpfs -x squashfs | awk 'NR>1 {gsub("%","",$5); print $5, $6}')

echo
echo "== Top 5 processes by CPU =="
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6 || true

echo
echo "== Failed services =="
if command -v systemctl >/dev/null; then
    ignore="${SYSREPORT_IGNORE:-}"
    failed=""
    while read -r unit _; do
        [[ -z "$unit" ]] && continue
        skip=0
        for pattern in $ignore; do
            # shellcheck disable=SC2053
            [[ "$unit" == $pattern ]] && skip=1
        done
        (( skip )) || failed+="$unit"$'\n'
    done < <(systemctl --failed --no-legend --plain 2>/dev/null || true)
    if [[ -n "$failed" ]]; then
        printf '%s' "$failed"
        status=1
    else
        echo "none"
    fi
else
    echo "systemctl not available"
fi

exit "$status"
