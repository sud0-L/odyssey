#!/usr/bin/env bash
# Install-owned orchestration for the existing bounded terminal theme adapters.
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
state_root=${XDG_STATE_HOME:-"${HOME:?HOME is required}/.local/state"}
config_root=${XDG_CONFIG_HOME:-"$HOME/.config"}
state_dir="$state_root/odyssey"
receipt="$state_dir/terminal-integrations.json"
palette="$state_dir/palette.json"
[[ -f $palette ]] || palette="$project_dir/generated/palette.json"
mode=$(jq -r '.mode // "dark"' "$palette")
[[ $mode == dark || $mode == light ]] || mode=dark

write_receipt() {
    local kitty=$1 starship=$2 fastfetch=$3 temporary
    mkdir -p "$state_dir"
    temporary=$(mktemp "$state_dir/.terminal-integrations.XXXXXX")
    jq -n --arg kitty "$kitty" --arg starship "$starship" --arg fastfetch "$fastfetch" \
        '{version:1, kitty:$kitty, starship:$starship, fastfetch:$fastfetch}' > "$temporary"
    chmod 0600 "$temporary"
    mv -f "$temporary" "$receipt"
}

enable() {
    # Export writes the palette atomically before refreshing independently
    # enabled adapters. A stale manual adapter must not make installation alter
    # or reject another user-owned terminal config.
    "$project_dir/scripts/export-theme.sh" "$palette" "$mode" \
        "$state_dir/theme-exports" false >/dev/null 2>&1 || true
    local kitty=skipped starship=skipped fastfetch=skipped output
    if [[ -f $config_root/kitty/kitty.conf && ! -L $config_root/kitty/kitty.conf ]]; then
        if output=$("$project_dir/scripts/kitty-themectl.py" enable 2>/dev/null); then
            [[ $output == KITTY=enabled* ]] && kitty=enabled
        fi
    fi
    if [[ -f $config_root/starship.toml && ! -L $config_root/starship.toml ]]; then
        if output=$("$project_dir/scripts/starship-themectl.py" enable "$palette" "$mode" 2>/dev/null); then
            [[ $output == STARSHIP=enabled || $output == STARSHIP=refreshed ]] && starship=enabled
        fi
    fi
    if [[ -f $config_root/fastfetch/config.jsonc && ! -L $config_root/fastfetch/config.jsonc ]]; then
        if output=$("$project_dir/scripts/fastfetch-themectl.py" enable 2>/dev/null); then
            [[ $output == FASTFETCH=enabled || $output == FASTFETCH=refreshed ]] && fastfetch=enabled
        fi
    fi
    write_receipt "$kitty" "$starship" "$fastfetch"
    printf 'TERMINAL_THEMING=kitty:%s starship:%s fastfetch:%s\n' "$kitty" "$starship" "$fastfetch"
}

disable() {
    [[ -e $receipt && ! -L $receipt ]] || { printf 'TERMINAL_THEMING=disabled\n'; return; }
    jq -e '.version == 1' "$receipt" >/dev/null
    local kitty starship fastfetch
    kitty=$(jq -r '.kitty' "$receipt"); starship=$(jq -r '.starship' "$receipt"); fastfetch=$(jq -r '.fastfetch' "$receipt")
    [[ $kitty == enabled ]] && "$project_dir/scripts/kitty-themectl.py" disable >/dev/null
    [[ $starship == enabled ]] && "$project_dir/scripts/starship-themectl.py" disable >/dev/null
    [[ $fastfetch == enabled ]] && "$project_dir/scripts/fastfetch-themectl.py" disable >/dev/null
    rm -f -- "$receipt"
    printf 'TERMINAL_THEMING=disabled\n'
}

status() {
    if [[ ! -e $receipt && ! -L $receipt ]]; then
        printf 'TERMINAL_THEMING=disabled kitty:disabled starship:disabled fastfetch:disabled\n'
        return
    fi
    [[ -f $receipt && ! -L $receipt ]] || {
        printf 'terminal integration receipt is not a regular file\n' >&2
        return 3
    }
    jq -e '.version == 1
        and (.kitty == "enabled" or .kitty == "skipped")
        and (.starship == "enabled" or .starship == "skipped")
        and (.fastfetch == "enabled" or .fastfetch == "skipped")' \
        "$receipt" >/dev/null || {
        printf 'terminal integration receipt is invalid\n' >&2
        return 3
    }
    local kitty starship fastfetch state
    kitty=$(jq -r '.kitty' "$receipt")
    starship=$(jq -r '.starship' "$receipt")
    fastfetch=$(jq -r '.fastfetch' "$receipt")
    state=disabled
    if [[ $kitty == enabled || $starship == enabled || $fastfetch == enabled ]]; then
        state=enabled
    fi
    printf 'TERMINAL_THEMING=%s kitty:%s starship:%s fastfetch:%s\n' \
        "$state" "$kitty" "$starship" "$fastfetch"
}

case ${1:-} in
    enable) enable ;;
    disable) disable ;;
    status) status ;;
    *) printf 'usage: %s {enable|disable|status}\n' "$0" >&2; exit 64 ;;
esac
