#!/usr/bin/env bash
set -euo pipefail

operation=${1:-}
runtime_root=${XDG_RUNTIME_DIR:-/tmp}/odyssey
marker=$runtime_root/idle-brightness

case $operation in
    dim)
        percent=${2:-}
        [[ $percent =~ ^[0-9]+$ ]] || exit 2
        mkdir -p -- "$runtime_root"
        printf 'dim %s\n' "$(date +%s)" > "$marker"
        exec brightnessctl -s set "$percent%"
        ;;
    restore)
        mkdir -p -- "$runtime_root"
        printf 'restore %s\n' "$(date +%s)" > "$marker"
        exec brightnessctl -r
        ;;
    *) exit 2 ;;
esac
