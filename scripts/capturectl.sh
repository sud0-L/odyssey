#!/usr/bin/env bash
set -euo pipefail

action=${1:-}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
home_dir=${HOME:?HOME is required}
state_root=${XDG_STATE_HOME:-"$home_dir/.local/state"}
palette="$state_root/odyssey/palette.json"
[[ -r $palette ]] || palette="$script_dir/../generated/palette.json"
pictures_dir=$(xdg-user-dir PICTURES 2>/dev/null || true)
videos_dir=$(xdg-user-dir VIDEOS 2>/dev/null || true)
pictures_dir=${pictures_dir:-"$home_dir/Pictures"}
videos_dir=${videos_dir:-"$home_dir/Videos"}
screenshot_dir=${ODYSSEY_SCREENSHOT_DIR:-"$pictures_dir/Screenshots"}
recording_dir=${ODYSSEY_RECORDING_DIR:-"$videos_dir/Recordings"}

usage() {
    printf 'usage: %s probe | screenshot <full|monitor|region|active> <monitor> <save|copy|both> | prepare-recording <monitor|region> <monitor>\n' "$0" >&2
    exit 64
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        printf '%s is unavailable\n' "$1" >&2
        exit 69
    }
}

unique_path() {
    local directory=$1 prefix=$2 extension=$3 timestamp candidate suffix=1
    mkdir -p "$directory"
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    candidate="$directory/${prefix}_${timestamp}.${extension}"
    while [[ -e $candidate ]]; do
        candidate="$directory/${prefix}_${timestamp}_${suffix}.${extension}"
        ((suffix += 1))
    done
    printf '%s\n' "$candidate"
}

validate_monitor() {
    [[ $1 =~ ^[A-Za-z0-9._:-]+$ ]] || {
        printf 'invalid monitor name\n' >&2
        exit 65
    }
}

active_window_geometry() {
    local window_json x y width height
    require_command hyprctl
    require_command jq
    window_json=$(hyprctl activewindow -j)
    x=$(jq -er '.at[0] | numbers' <<<"$window_json")
    y=$(jq -er '.at[1] | numbers' <<<"$window_json")
    width=$(jq -er '.size[0] | select(. > 0)' <<<"$window_json")
    height=$(jq -er '.size[1] | select(. > 0)' <<<"$window_json")
    printf '%s,%s %sx%s\n' "$x" "$y" "$width" "$height"
}

select_region() {
    local geometry selection_status selector_accent="#c9bfff"
    local fullscreen_workspaces workspaces windows
    local -a slurp_args
    require_command slurp
    require_command hyprctl
    require_command jq
    if command -v jq >/dev/null 2>&1 \
            && [[ -r $palette ]]; then
        selector_accent=$(jq -r \
            'if .mode == "light" then .light.primary else .dark.primary end' \
            "$palette" 2>/dev/null || true)
        [[ $selector_accent =~ ^#[0-9A-Fa-f]{6}$ ]] \
            || selector_accent="#c9bfff"
    fi
    # Match Grimblast's proven area picker: supplying visible window geometry
    # lets a click select a complete window, while click-drag still selects an
    # arbitrary region. This is shared by screenshot and recording workflows.
    hyprctl keyword layerrule "noanim,selection" >/dev/null
    fullscreen_workspaces=$(hyprctl workspaces -j | jq -c \
        'map(select(.hasfullscreen) | .id)')
    workspaces=$(hyprctl monitors -j | jq -c \
        '[.[] | (if .specialWorkspace.name == "" then .activeWorkspace else .specialWorkspace end).id]')
    windows=$(hyprctl clients -j | jq -r --argjson workspaces "$workspaces" \
        --argjson fullscreenWorkspaces "$fullscreen_workspaces" \
        'map(select((([.workspace.id] | inside($workspaces)) and
            (([.workspace.id] | inside($fullscreenWorkspaces)) | not))
            or .fullscreen > 0))
        | .[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')

    slurp_args=(-b "#00000088" -c "${selector_accent}ff" \
        -s "${selector_accent}33" -w 3 -f '%x,%y %wx%h')

    set +e
    if [[ -n $windows ]]; then
        geometry=$(printf '%s\n' "$windows" | timeout --foreground --signal=TERM 60s \
            slurp "${slurp_args[@]}")
    else
        geometry=$(timeout --foreground --signal=TERM 60s slurp "${slurp_args[@]}" \
            </dev/null)
    fi
    selection_status=$?
    set -e
    if [[ $selection_status -eq 124 ]]; then
        printf 'Region selection timed out after 60 seconds\n' >&2
        exit 70
    fi
    [[ $selection_status -eq 0 ]] || exit 2
    [[ $geometry =~ ^-?[0-9]+,-?[0-9]+\ [1-9][0-9]*x[1-9][0-9]*$ ]] || {
        printf 'invalid region selection\n' >&2
        exit 65
    }
    printf '%s\n' "$geometry"
}

case $action in
    probe)
        command -v grim >/dev/null 2>&1 \
            && command -v timeout >/dev/null 2>&1 \
            && printf 'SCREENSHOT=ready\n' || printf 'SCREENSHOT=missing\n'
        command -v wl-copy >/dev/null 2>&1 && printf 'CLIPBOARD=ready\n' || printf 'CLIPBOARD=missing\n'
        command -v gpu-screen-recorder >/dev/null 2>&1 && printf 'RECORDING=ready\n' || printf 'RECORDING=missing\n'
        command -v slurp >/dev/null 2>&1 \
            && command -v timeout >/dev/null 2>&1 \
            && printf 'REGION=ready\n' || printf 'REGION=missing\n'
        ;;
    screenshot)
        mode=${2:-}
        monitor=${3:-}
        output_mode=${4:-both}
        [[ $mode == full || $mode == monitor || $mode == region || $mode == active ]] || usage
        [[ $output_mode == save || $output_mode == copy || $output_mode == both ]] || usage
        require_command grim
        if [[ $mode == monitor ]]; then
            validate_monitor "$monitor"
        fi
        if [[ $output_mode == copy || $output_mode == both ]]; then
            require_command wl-copy
        fi

        saved=false
        copied=false
        temporary_output=false
        if [[ $output_mode == copy ]]; then
            runtime_dir=${XDG_RUNTIME_DIR:-/tmp}
            output_path=$(mktemp "$runtime_dir/odyssey-screenshot.XXXXXX.png")
            temporary_output=true
            trap '[[ $temporary_output == true ]] && rm -f -- "$output_path"' EXIT
        else
            output_path=$(unique_path "$screenshot_dir" Screenshot png)
            saved=true
        fi

        case $mode in
            full)
                timeout --foreground --signal=TERM 15s grim "$output_path"
                ;;
            monitor)
                timeout --foreground --signal=TERM 15s grim -o "$monitor" "$output_path"
                ;;
            region)
                # Use the same area-capture path as the user's working Print
                # binding when Grimblast is installed. It still uses grim and
                # slurp underneath, but also applies Hyprland's proven
                # selection-layer setup. Keep the direct path as a fallback.
                if command -v grimblast >/dev/null 2>&1; then
                    timeout --foreground --signal=TERM 75s \
                        grimblast save area "$output_path"
                else
                    geometry=$(select_region)
                    timeout --foreground --signal=TERM 15s \
                        grim -g "$geometry" "$output_path"
                fi
                ;;
            active)
                geometry=$(active_window_geometry)
                timeout --foreground --signal=TERM 15s grim -g "$geometry" "$output_path"
                ;;
        esac

        if [[ $output_mode == copy || $output_mode == both ]]; then
            wl-copy --type image/png <"$output_path"
            copied=true
        fi
        printf 'SAVED=%s\nCOPIED=%s\n' "$saved" "$copied"
        if [[ $saved == true ]]; then
            printf 'PATH=%s\n' "$output_path"
        fi
        ;;
    prepare-recording)
        mode=${2:-}
        monitor=${3:-}
        [[ $mode == monitor || $mode == region ]] || usage
        require_command gpu-screen-recorder
        output_path=$(unique_path "$recording_dir" Recording mp4)
        printf 'PATH=%s\n' "$output_path"
        if [[ $mode == monitor ]]; then
            validate_monitor "$monitor"
            printf 'TARGET=%s\n' "$monitor"
        else
            geometry=$(select_region)
            if [[ $geometry =~ ^(-?[0-9]+),(-?[0-9]+)\ ([1-9][0-9]*)x([1-9][0-9]*)$ ]]; then
                x=${BASH_REMATCH[1]}
                y=${BASH_REMATCH[2]}
                width=${BASH_REMATCH[3]}
                height=${BASH_REMATCH[4]}
                [[ $x == -* ]] || x=+$x
                [[ $y == -* ]] || y=+$y
                printf 'TARGET=region\nREGION=%sx%s%s%s\n' "$width" "$height" "$x" "$y"
            else
                printf 'invalid region selection\n' >&2
                exit 65
            fi
        fi
        ;;
    *)
        usage
        ;;
esac
