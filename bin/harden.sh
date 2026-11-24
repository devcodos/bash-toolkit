#!/usr/bin/env bash
# harden.sh - read-only security audit of a Linux server (PASS / FAIL / SKIP per check)
# Copyright (C) 2026 devcodos (https://github.com/devcodos)
# Licensed under GPL-3.0. See the LICENSE file in the repo root.
set -euo pipefail

if [[ $# -ne 0 ]]; then
    echo "Usage: $0   (run with sudo for the full audit)" >&2
    exit 2
fi

passed=0
failed=0
skipped=0
is_root=0
if (( EUID == 0 )); then is_root=1; fi

pass() { echo "PASS  $1"; passed=$((passed + 1)); }
fail() { echo "FAIL  $1"; [[ -n "${2:-}" ]] && echo "        fix: $2"; failed=$((failed + 1)); return 0; }
skip() { echo "SKIP  $1"; skipped=$((skipped + 1)); }

# Print the effective value of an sshd setting (empty if not set)
ssh_value() {
    local key="${1,,}" val=""
    if (( is_root )) && [[ -x /usr/sbin/sshd ]]; then
        val=$(/usr/sbin/sshd -T 2>/dev/null | awk -v k="$key" '$1 == k {print $2; exit}') || true
    else
        # sshd uses the first match, and the .d folder is read before the main file
        val=$(grep -hiE "^[[:space:]]*${key}[[:space:]]+" /etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config 2>/dev/null \
            | head -n 1 | awk '{print tolower($2)}') || true
    fi
    echo "$val"
}

echo "== Security audit: $(hostname) =="
if (( ! is_root )); then
    echo "(not running as root: some checks will be skipped)"
fi
echo

# 1. SSH
if [[ -f /etc/ssh/sshd_config ]]; then
    v=$(ssh_value PermitRootLogin)
    case "${v:-prohibit-password}" in
        no|prohibit-password|without-password|forced-commands-only)
            pass "SSH root login restricted (${v:-default})" ;;
        *)
            fail "SSH root login allowed (PermitRootLogin $v)" "set 'PermitRootLogin no' in /etc/ssh/sshd_config" ;;
    esac
    v=$(ssh_value PasswordAuthentication)
    if [[ "$v" == "no" ]]; then
        pass "SSH password authentication disabled"
    else
        fail "SSH password authentication enabled (${v:-default yes})" "use keys, then set 'PasswordAuthentication no'"
    fi
else
    skip "SSH server not installed"
fi

# 2. Firewall
if [[ -f /etc/ufw/ufw.conf ]]; then
    if grep -qi '^ENABLED=yes' /etc/ufw/ufw.conf; then
        pass "Firewall (ufw) enabled"
    else
        fail "Firewall (ufw) is not enabled" "allow what you need first (e.g. 'sudo ufw allow OpenSSH'), then 'sudo ufw enable'"
    fi
else
    fail "ufw not installed (no firewall found)" "sudo apt install ufw"
fi

# 3. Empty passwords
if (( is_root )); then
    empty=$(awk -F: '($2 == "") {print $1}' /etc/shadow)
    if [[ -z "$empty" ]]; then
        pass "No accounts with empty passwords"
    else
        fail "Accounts with empty passwords: $(echo "$empty" | tr '\n' ' ')" "sudo passwd -l <user>"
    fi
else
    skip "Empty-password check (needs root)"
fi

# 4. /etc/shadow permissions (last digit = permissions for 'others')
perm=$(stat -c %a /etc/shadow)
if [[ "${perm: -1}" == "0" ]]; then
    pass "/etc/shadow not readable by others ($perm)"
else
    fail "/etc/shadow is readable by others ($perm)" "sudo chmod 640 /etc/shadow"
fi

# 5. World-writable files in /etc
ww=$(find /etc -xdev -type f -perm -0002 2>/dev/null | head -n 5) || true
if [[ -z "$ww" ]]; then
    pass "No world-writable files in /etc"
else
    fail "World-writable files in /etc: $(echo "$ww" | tr '\n' ' ')" "chmod o-w <file>"
fi

# 6. Automatic security updates
if command -v dpkg >/dev/null; then
    if dpkg -s unattended-upgrades >/dev/null 2>&1 && systemctl is-enabled --quiet apt-daily-upgrade.timer 2>/dev/null; then
        pass "Automatic security updates enabled"
    else
        fail "Automatic security updates not enabled" "sudo apt install unattended-upgrades"
    fi
else
    skip "Automatic updates check (not a Debian/Ubuntu system)"
fi

echo
echo "Passed: $passed   Failed: $failed   Skipped: $skipped"
if (( failed > 0 )); then
    exit 1
fi
