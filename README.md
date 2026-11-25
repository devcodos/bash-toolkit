# bash-toolkit

Bash tools for Linux administration. No dependencies beyond Bash and standard Linux utilities.

![ShellCheck](https://github.com/devcodos/bash-toolkit/actions/workflows/shellcheck.yml/badge.svg)

![Gitleaks](https://github.com/devcodos/bash-toolkit/actions/workflows/gitleaks.yml/badge.svg)

## Tools

| Tool | What it does |
|---|---|
| `bin/sysreport.sh` | One-screen health report: uptime, load, memory, disk usage, top processes, failed services |
| `bin/backup.sh` | Creates a timestamped .tar.gz of a directory and keeps only the newest N backups |
| `bin/logsummary.sh` | Summarizes failed SSH logins, top source IPs and usernames, and sudo usage from the auth log or journal |
| `bin/harden.sh` | Read-only security audit: SSH settings, firewall, empty passwords, file permissions, automatic updates |

## Usage

    ./bin/sysreport.sh
    ./bin/sysreport.sh 90
    SYSREPORT_IGNORE="vboxadd*.service" ./bin/sysreport.sh
    ./bin/backup.sh ~/projects ~/backups 5
    ./bin/logsummary.sh 10 20
    sudo ./bin/harden.sh

- `sysreport.sh`: the optional argument is the disk usage percentage that triggers a warning (default 80). Set `SYSREPORT_IGNORE` to a space-separated list of service names (wildcards allowed) to leave known failures out of the report.
- `backup.sh`: arguments are source folder, backup folder, and how many backups to keep.
- `logsummary.sh`: set `LOGSUMMARY_FILE` to analyze a specific log file. Arguments are the top-N size and the failed-login alert threshold.
- `harden.sh`: never changes the system. Run it with `sudo` for the full audit.

## Exit codes

`0` success, `1` a check failed or a warning was raised (full disk, failed service, failed archive check, login alert threshold reached, failed security check), `2` bad input.

## Author

[devcodos](https://github.com/devcodos)

## License

GPL-3.0. See the `LICENSE` file.
