#!/usr/bin/env bash
# backup.sh - create a timestamped .tar.gz of a directory and keep only the newest N
# Licensed under GPL-3.0. See the LICENSE file in the repo root.
set -euo pipefail

usage() {
    echo "Usage: $0 <source_dir> <backup_dir> [keep_count]   (default keep: 7)" >&2
    exit 2
}

[[ $# -ge 2 && $# -le 3 ]] || usage

src="${1%/}"
dest="${2%/}"
keep="${3:-7}"

[[ -d "$src" ]] || { echo "Error: source '$src' is not a directory" >&2; exit 2; }

if ! [[ "$keep" =~ ^[0-9]+$ ]] || (( keep < 1 )); then
    echo "Error: keep_count must be 1 or more" >&2
    exit 2
fi

mkdir -p "$dest"

name="$(basename "$(realpath "$src")")"
stamp="$(date +%Y-%m-%d_%H-%M-%S)"
archive="$dest/${name}-${stamp}.tar.gz"

# Refuse to back up a directory into itself
case "$(realpath "$dest")/" in
    "$(realpath "$src")"/*) echo "Error: backup_dir is inside source_dir" >&2; exit 2 ;;
esac

tar -czf "$archive" -C "$(dirname "$(realpath "$src")")" "$name"

# Verify the archive can be read
if ! tar -tzf "$archive" >/dev/null; then
    echo "Error: archive failed verification: $archive" >&2
    rm -f "$archive"
    exit 1
fi

size="$(du -h "$archive" | cut -f1)"
echo "Created  $archive ($size)"

# Rotation: list this source's backups newest first, delete everything after the first N
mapfile -t old < <(find "$dest" -maxdepth 1 -type f -name "${name}-*.tar.gz" -printf '%T@ %p\n' \
    | sort -rn | tail -n +"$((keep + 1))" | cut -d' ' -f2-)

for f in "${old[@]}"; do
    rm -f -- "$f"
    echo "Deleted  $f (rotation, keeping $keep)"
done
