#!/usr/bin/env bash
# Relocatable Quickshell entry point used by odyssey.service.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
root_dir=$(cd -- "$script_dir/.." && pwd -P)

if [[ ${1:-} == --root ]]; then
    [[ $# == 2 && -d ${2:-} ]] || { printf 'invalid Odyssey root\n' >&2; exit 64; }
    root_dir=$(cd -- "$2" && pwd -P)
elif [[ $# -ne 0 ]]; then
    printf 'usage: %s [--root DIRECTORY]\n' "$0" >&2
    exit 64
fi

[[ -f $root_dir/shell.qml ]] || { printf 'Odyssey shell.qml was not found\n' >&2; exit 69; }
qs_path=$(command -v qs) || { printf 'qs was not found in PATH\n' >&2; exit 69; }
exec "$qs_path" --no-duplicate --path "$root_dir"
