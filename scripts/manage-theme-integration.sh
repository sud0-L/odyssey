#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd "$(dirname "$0")/.." && pwd)
state_root=${XDG_STATE_HOME:-"${HOME:?HOME is required}/.local/state"}
config_root=${XDG_CONFIG_HOME:-"$HOME/.config"}
generated_lock="$state_root/odyssey/hyprlock.conf"
active_lock="$config_root/hypr/hyprlock.conf"

hyprlock_status() {
    if [[ -L $active_lock ]] \
            && [[ $(readlink -f "$active_lock" 2>/dev/null || true) \
                == $(readlink -f "$generated_lock" 2>/dev/null || true) ]]; then
        printf 'enabled\n'
    elif [[ -e $active_lock || -L $active_lock ]]; then
        printf 'external\n'
    else
        printf 'disabled\n'
    fi
}

target=${1:-}
action=${2:-}
[[ $target == hyprlock ]] || {
    printf 'unsupported theme integration: %s\n' "$target" >&2
    exit 64
}

case $action in
    enable)
        "$project_dir/scripts/install-hyprlock.sh"
        ;;
    disable)
        status=$(hyprlock_status)
        if [[ $status == enabled ]]; then
            unlink "$active_lock"
        elif [[ $status == external ]]; then
            printf 'refusing to remove an externally owned Hyprlock config\n' >&2
            exit 3
        fi
        "$project_dir/scripts/settingsctl.sh" set-hyprlock false >/dev/null
        printf 'STATUS=disabled\n'
        ;;
    status)
        printf 'STATUS=%s\n' "$(hyprlock_status)"
        ;;
    *)
        printf 'usage: %s hyprlock {enable|disable|status}\n' "$0" >&2
        exit 64
        ;;
esac
