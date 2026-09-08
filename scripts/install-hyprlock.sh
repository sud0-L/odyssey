#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd "$(dirname "$0")/.." && pwd)
state_root=${XDG_STATE_HOME:-"${HOME:?HOME is required}/.local/state"}
state_dir="$state_root/odyssey"
palette="$state_dir/palette.json"
[[ -f $palette ]] || palette="$project_dir/generated/palette.json"
config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/hypr
active_config="$config_dir/hyprlock.conf"
generated_config="$state_dir/hyprlock.conf"
mode=$(jq -r '.mode // "dark"' "$palette")

"$project_dir/scripts/export-theme.sh" "$palette" \
    "$mode" "$state_dir/theme-exports" true >/dev/null

mkdir -p "$config_dir"
if [[ -L $active_config ]]; then
    current_target=$(readlink -f "$active_config" 2>/dev/null || true)
    expected_target=$(readlink -f "$generated_config" 2>/dev/null || true)
    [[ $current_target == "$expected_target" ]] || {
        printf 'refusing to replace existing Hyprlock symlink: %s\n' \
            "$active_config" >&2
        exit 3
    }
elif [[ -e $active_config ]]; then
    printf 'refusing to replace existing Hyprlock configuration: %s\n' \
        "$active_config" >&2
    exit 3
else
    ln -s "$generated_config" "$active_config"
fi

"$project_dir/scripts/settingsctl.sh" set-hyprlock true >/dev/null

printf 'CONFIG=%s\n' "$generated_config"
printf 'ACTIVE=%s\n' "$active_config"
