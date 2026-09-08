#!/usr/bin/env bash
set -euo pipefail

action=${1:-}
project_dir=$(cd "$(dirname "$0")/.." && pwd)
state_root=${XDG_STATE_HOME:-"${HOME:?HOME is required}/.local/state"}
lock_config="$state_root/odyssey/hyprlock.conf"
palette="$state_root/odyssey/palette.json"
[[ -f $palette ]] || palette="$project_dir/generated/palette.json"

available_command() {
    command -v "$1" >/dev/null 2>&1
}

login1_capability() {
    local method=$1 result value
    if ! available_command busctl; then
        printf 'missing\n'
        return
    fi
    result=$(busctl --system call org.freedesktop.login1 \
        /org/freedesktop/login1 org.freedesktop.login1.Manager \
        "$method" 2>/dev/null || true)
    value=${result#*\"}
    value=${value%%\"*}
    if [[ $value == yes || $value == challenge ]]; then
        printf 'ready\n'
    else
        printf 'missing\n'
    fi
}

case $action in
    probe)
        available_command hyprlock && printf 'LOCK=ready\n' || printf 'LOCK=missing\n'
        available_command hyprctl && printf 'LOGOUT=ready\n' || printf 'LOGOUT=missing\n'
        printf 'SUSPEND=%s\n' "$(login1_capability CanSuspend)"
        printf 'HIBERNATE=%s\n' "$(login1_capability CanHibernate)"
        printf 'REBOOT=%s\n' "$(login1_capability CanReboot)"
        printf 'SHUTDOWN=%s\n' "$(login1_capability CanPowerOff)"
        ;;
    lock)
        available_command hyprlock || exit 69
        "$project_dir/scripts/lock-powerctl.sh" reset || true
        if [[ ! -f $lock_config ]]; then
            available_command jq || exit 69
            mode=$(jq -r '.mode // "dark"' "$palette")
            "$project_dir/scripts/export-theme.sh" \
                "$palette" "$mode" \
                "$state_root/odyssey/theme-exports" true >/dev/null
        fi
        exec hyprlock --config "$lock_config"
        ;;
    suspend)
        available_command systemctl || exit 69
        exec systemctl suspend
        ;;
    hibernate)
        available_command systemctl || exit 69
        exec systemctl hibernate
        ;;
    logout)
        available_command hyprctl || exit 69
        # This Hyprland build uses the Lua configuration API. Execute its
        # native exit dispatcher directly instead of relying on legacy syntax.
        exec hyprctl eval 'hl.dispatch(hl.dsp.exit())'
        ;;
    reboot)
        available_command systemctl || exit 69
        exec systemctl reboot
        ;;
    shutdown)
        available_command systemctl || exit 69
        exec systemctl poweroff
        ;;
    *)
        printf 'invalid session action\n' >&2
        exit 64
        ;;
esac
