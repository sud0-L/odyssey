#!/usr/bin/env bash
set -euo pipefail

mode=${1:-}
interaction=${2:-noninteractive}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
adapter="$script_dir/startupctl.sh"

[[ $mode == managed || $mode == preserve ]] || {
    printf 'Hyprland configuration mode is invalid.\n' >&2
    exit 64
}
[[ $interaction == interactive || $interaction == noninteractive ]] || {
    printf 'Hyprland configuration selection mode is invalid.\n' >&2
    exit 64
}

resolve() {
    "$adapter" resolve-host "$mode" 2>/dev/null
}

if [[ -n ${ODYSSEY_HYPRLAND_CONFIG:-} ]]; then
    selected=$(resolve) || {
        printf 'ODYSSEY_HYPRLAND_CONFIG does not identify a supported Hyprland Lua config: %s\n' \
            "$ODYSSEY_HYPRLAND_CONFIG" >&2
        exit 1
    }
    printf '%s\n' "$selected"
    exit
fi

if selected=$(resolve); then
    printf '%s\n' "$selected"
    exit
fi

if [[ $interaction != interactive ]]; then
    printf 'The active Hyprland config could not be determined safely. Set ODYSSEY_HYPRLAND_CONFIG to the absolute path of the Hyprland Lua config and rerun the installer.\n' >&2
    exit 1
fi

printf '%s\n' \
    'The active Hyprland config could not be determined safely.' \
    'Enter the path to the Hyprland Lua config that odyssey should integrate with.' >&2
while :; do
    read -r -p 'Hyprland Lua config path: ' entered || {
        printf '\nA Hyprland Lua config path is required.\n' >&2
        exit 1
    }
    if [[ $entered == \~/* ]]; then
        entered="$HOME/${entered:2}"
    fi
    if [[ $entered != /* || $entered != *.lua ]]; then
        printf 'Enter an absolute path ending in .lua.\n' >&2
        continue
    fi
    if [[ ! -f $entered || -L $entered ]]; then
        printf 'The path must identify an existing regular, non-symlink Lua file.\n' >&2
        continue
    fi
    entered=$(readlink -f -- "$entered") || {
        printf 'The entered path could not be resolved.\n' >&2
        continue
    }
    if selected=$(ODYSSEY_HYPRLAND_CONFIG="$entered" \
            "$adapter" resolve-host "$mode" 2>/dev/null); then
        printf '%s\n' "$selected"
        exit
    fi
    printf 'The entered file is not a supported Hyprland Lua config.\n' >&2
done
