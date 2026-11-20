#!/usr/bin/env bash
# logsummary.sh - summarize failed SSH logins and sudo usage from the auth log or journal
# Licensed under GPL-3.0. See the LICENSE file in the repo root.
set -euo pipefail

usage() {
    echo "Usage: $0 [top_n] [alert_threshold]   (defaults: 5 and 10)" >&2
    echo "Set LOGSUMMARY_FILE=/path/to/log to read a specific file." >&2
    exit 2
}

[[ $# -le 2 ]] || usage
top="${1:-5}"
alert="${2:-10}"
for n in "$top" "$alert"; do
    if ! [[ "$n" =~ ^[0-9]+$ ]] || (( n < 1 )); then
        usage
    fi
done

read_log() {
    if [[ -n "${LOGSUMMARY_FILE:-}" ]]; then
        [[ -r "$LOGSUMMARY_FILE" ]] || { echo "Error: cannot read $LOGSUMMARY_FILE" >&2; exit 2; }
        cat "$LOGSUMMARY_FILE"
    elif [[ -r /var/log/auth.log ]]; then
        cat /var/log/auth.log
    elif command -v journalctl >/dev/null; then
        journalctl --no-pager -q -t sshd -t sudo 2>/dev/null || true
    else
        echo "Error: no log source found (try LOGSUMMARY_FILE)" >&2
        exit 2
    fi
}

log="$(read_log)"

failed=$(grep -c 'Failed password' <<< "$log" || true)
accepted=$(grep -c 'Accepted ' <<< "$log" || true)

echo "== SSH =="
echo "Failed logins:     $failed"
echo "Successful logins: $accepted"

echo
echo "== Top $top source IPs of failed logins =="
grep 'Failed password' <<< "$log" | grep -oE 'from [0-9a-fA-F:.]+' | awk '{print $2}' \
    | sort | uniq -c | sort -rn | head -n "$top" || true

echo
echo "== Top $top usernames tried =="
grep -oE 'Failed password for (invalid user )?[^ ]+' <<< "$log" | awk '{print $NF}' \
    | sort | uniq -c | sort -rn | head -n "$top" || true

echo
echo "== sudo =="
echo "Commands run: $(grep -c 'COMMAND=' <<< "$log" || true)"
grep 'COMMAND=' <<< "$log" | grep -oE 'sudo(\[[0-9]+\])?: +[^ ]+' | awk '{print $2}' \
    | sort | uniq -c | sort -rn | head -n "$top" || true

if (( failed >= alert )); then
    echo
    echo "ALERT: $failed failed logins (threshold $alert)"
    exit 1
fi
