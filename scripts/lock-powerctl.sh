#!/usr/bin/env bash
set -euo pipefail

# Small state bridge for Hyprlock's native clickable labels. It intentionally
# accepts only fixed session actions and delegates their execution to the same
# bounded helper used by Odyssey's Session page.
action=${1:-}
argument=${2:-}
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
runtime_root=${XDG_RUNTIME_DIR:-}

[[ -n $runtime_root && -d $runtime_root ]] || exit 69
state_dir="$runtime_root/odyssey"
state_file="$state_dir/hyprlock-power-state"
confirmation_lifetime=15

mkdir -p "$state_dir"
chmod 0700 "$state_dir"

refresh_lock() {
    command -v pkill >/dev/null 2>&1 || return 0
    pkill -USR2 -x hyprlock 2>/dev/null || true
}

read_state() {
    [[ -f $state_file ]] || return 0
    local value pending timestamp now
    value=$(<"$state_file")
    case $value in
        menu)
            printf '%s\n' "$value"
            ;;
        confirm:*)
            IFS=: read -r _ pending timestamp <<< "$value"
            valid_action "$pending" || return 0
            [[ $pending != suspend && $timestamp =~ ^[0-9]+$ ]] || return 0
            now=$(date +%s)
            if (( now >= timestamp && now - timestamp <= confirmation_lifetime )); then
                printf 'confirm:%s\n' "$pending"
            fi
            ;;
    esac
}

write_state() {
    local value=$1 temporary
    temporary=$(mktemp "$state_dir/.hyprlock-power.XXXXXX")
    chmod 0600 "$temporary"
    printf '%s\n' "$value" > "$temporary"
    mv -f "$temporary" "$state_file"
    refresh_lock
}

clear_state() {
    rm -f "$state_file"
    refresh_lock
}

valid_action() {
    case $1 in
        suspend|hibernate|logout|reboot|shutdown) return 0 ;;
        *) return 1 ;;
    esac
}

case $action in
    toggle)
        [[ $(read_state) == menu ]] && clear_state || write_state menu
        ;;
    cancel|reset)
        clear_state
        ;;
    action)
        valid_action "$argument" || exit 64
        if [[ $argument == suspend ]]; then
            clear_state
            exec "$project_dir/scripts/sessionctl.sh" suspend
        fi
        write_state "confirm:$argument:$(date +%s)"
        ;;
    confirm)
        valid_action "$argument" || exit 64
        [[ $(read_state) == "confirm:$argument" ]] || exit 64
        clear_state
        exec "$project_dir/scripts/sessionctl.sh" "$argument"
        ;;
    label)
        state=$(read_state)
        case $argument in
            power) printf '󰐥\n' ;;
            suspend) if [[ $state == menu ]]; then printf 'Suspend\n'; fi ;;
            hibernate) if [[ $state == menu ]]; then printf 'Hibernate\n'; fi ;;
            logout) if [[ $state == menu ]]; then printf 'Log out\n'; fi ;;
            reboot)
                if [[ $state == menu ]]; then
                    printf 'Restart\n'
                elif [[ $state == confirm:reboot ]]; then
                    printf 'Confirm restart\n'
                fi
                ;;
            shutdown)
                if [[ $state == menu ]]; then
                    printf 'Shut down\n'
                elif [[ $state == confirm:shutdown ]]; then
                    printf 'Confirm shut down\n'
                fi
                ;;
            confirm-hibernate) if [[ $state == confirm:hibernate ]]; then printf 'Confirm hibernate\n'; fi ;;
            confirm-logout) if [[ $state == confirm:logout ]]; then printf 'Confirm log out\n'; fi ;;
            cancel) if [[ $state == confirm:* ]]; then printf 'Cancel\n'; fi ;;
            *) exit 64 ;;
        esac
        ;;
    *)
        exit 64
        ;;
esac
