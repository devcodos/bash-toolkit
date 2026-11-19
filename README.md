# bash-toolkit

Bash tools for Linux administration. No dependencies beyond Bash and standard Linux utilities.

![ShellCheck](https://github.com/devcodos/bash-toolkit/actions/workflows/shellcheck.yml/badge.svg)

## Tools

| Tool | What it does |
|---|---|
| `bin/sysreport.sh` | One-screen health report: uptime, load, memory, disk usage, top processes, failed services |

## Usage

    ./bin/sysreport.sh
    ./bin/sysreport.sh 90

The optional argument is the disk usage percentage that triggers a warning (default 80).

Exit codes: `0` healthy, `1` a warning was raised (disk full or failed service), `2` bad input.

## License

GPL-3.0. See the `LICENSE` file.
