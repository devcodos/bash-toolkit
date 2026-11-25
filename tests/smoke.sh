#!/usr/bin/env bash
# smoke.sh - basic behavior tests for the scripts in bin/
# Licensed under GPL-3.0. See the LICENSE file in the repo root.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
fails=0

# check <name> <expected_exit_code> <command...>
check() {
    local name="$1" want="$2" got
    shift 2
    "$@" >/dev/null 2>&1
    got=$?
    if [[ $got -eq $want ]]; then
        echo "ok    $name"
    else
        echo "FAIL  $name (expected exit $want, got $got)"
        fails=$((fails + 1))
    fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir "$tmp/src"
echo hello > "$tmp/src/file.txt"

cat > "$tmp/auth.log" << 'LOG'
Nov 20 06:10:01 devops sshd[1001]: Failed password for root from 203.0.113.5 port 40001 ssh2
Nov 20 06:10:03 devops sshd[1002]: Failed password for root from 203.0.113.5 port 40002 ssh2
Nov 20 06:10:05 devops sshd[1003]: Failed password for invalid user admin from 203.0.113.5 port 40003 ssh2
Nov 20 06:11:02 devops sshd[1004]: Failed password for invalid user test from 198.51.100.7 port 50001 ssh2
Nov 20 06:12:00 devops sshd[1005]: Accepted publickey for sal from 192.168.1.20 port 60000 ssh2
LOG

# backup.sh
check "backup: missing source dir"  2 bin/backup.sh /does/not/exist "$tmp/b"
check "backup: keep count of 0"     2 bin/backup.sh "$tmp/src" "$tmp/b" 0
check "backup: creates an archive"  0 bin/backup.sh "$tmp/src" "$tmp/b" 2
sleep 1; bin/backup.sh "$tmp/src" "$tmp/b" 2 >/dev/null
sleep 1; bin/backup.sh "$tmp/src" "$tmp/b" 2 >/dev/null
count="$(find "$tmp/b" -name 'src-*.tar.gz' | wc -l)"
check "backup: rotation keeps 2"    0 test "$count" -eq 2

# logsummary.sh
check "logsummary: below threshold" 0 env LOGSUMMARY_FILE="$tmp/auth.log" bin/logsummary.sh 5 10
check "logsummary: alert fires"     1 env LOGSUMMARY_FILE="$tmp/auth.log" bin/logsummary.sh 5 3
check "logsummary: bad argument"    2 bin/logsummary.sh 0

# sysreport.sh and harden.sh
check "sysreport: bad threshold"    2 bin/sysreport.sh abc
check "harden: rejects arguments"   2 bin/harden.sh unexpected

echo
if (( fails > 0 )); then
    echo "$fails test(s) failed"
    exit 1
fi
echo "All tests passed"
