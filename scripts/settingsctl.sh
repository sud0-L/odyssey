#!/usr/bin/env bash
set -euo pipefail

state_root=${XDG_STATE_HOME:-"${HOME:?HOME is required}/.local/state"}
state_dir="$state_root/odyssey"
settings_file="$state_dir/settings.json"

write_hyprlock() {
    local enabled=$1 temporary
    [[ $enabled == true || $enabled == false ]] || exit 64
    command -v jq >/dev/null || exit 69
    mkdir -p "$state_dir"
    temporary=$(mktemp "$state_dir/.settings.XXXXXX.json")
    if [[ -f $settings_file ]] && jq -e 'type == "object"' \
            "$settings_file" >/dev/null 2>&1; then
        jq --argjson enabled "$enabled" \
            '.version = 1 | .settings = (.settings // {})
            | .settings.externalThemes = (.settings.externalThemes // {})
            | .settings.externalThemes.hyprlock = $enabled' \
            "$settings_file" > "$temporary"
    else
        jq -n --argjson enabled "$enabled" \
            '{version: 1, settings: {externalThemes: {hyprlock: $enabled}}}' \
            > "$temporary"
    fi
    chmod 0600 "$temporary"
    mv -f "$temporary" "$settings_file"
}

case ${1:-} in
    set-hyprlock)
        write_hyprlock "${2:-}"
        printf 'HYPRLOCK=%s\n' "$2"
        ;;
    get-hyprlock)
        if [[ -f $settings_file ]] && command -v jq >/dev/null; then
            jq -r '.settings.externalThemes.hyprlock // false' "$settings_file"
        else
            printf 'false\n'
        fi
        ;;
    *)
        printf 'usage: %s {get-hyprlock|set-hyprlock BOOL}\n' "$0" >&2
        exit 64
        ;;
esac
