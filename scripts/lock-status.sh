#!/usr/bin/env bash
set -euo pipefail

state_root=${XDG_STATE_HOME:-"${HOME:?HOME is required}/.local/state"}
state_dir="$state_root/odyssey"

escape_markup() {
    local value=${1:-}
    value=${value//&/\&amp;}
    value=${value//</\&lt;}
    value=${value//>/\&gt;}
    printf '%s' "$value"
}

single_line() {
    tr '\r\n\t' '   ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

url_decode() {
    local encoded=${1:-}
    encoded=${encoded#file://}
    printf '%b' "${encoded//%/\\x}"
}

wallpaper() {
    local path=""
    [[ -f "$state_dir/current-wallpaper" ]] \
        && IFS= read -r path < "$state_dir/current-wallpaper"
    [[ -f $path ]] || return 0
    printf '%s\n' "$path"
}

identity() {
    local identity_file="$state_root/odyssey-identity.json"
    [[ -f $identity_file ]] || return 0
    command -v jq >/dev/null || return 0
    local source path
    source=$(jq -r '.personalImage // empty' "$identity_file" 2>/dev/null || true)
    [[ $source == file://* ]] || return 0
    path=$(url_decode "$source")
    [[ -f $path ]] || return 0
    printf '%s\n' "$path"
}

battery() {
    local battery_dir percentage status icon
    battery_dir=$(find /sys/class/power_supply -mindepth 1 -maxdepth 1 \
        -type l -name 'BAT*' -print 2>/dev/null | sort | head -n 1)
    [[ -n $battery_dir && -r "$battery_dir/capacity" ]] || return 0
    IFS= read -r percentage < "$battery_dir/capacity"
    status=""
    [[ -r "$battery_dir/status" ]] && IFS= read -r status < "$battery_dir/status"
    if [[ $status == Charging ]]; then
        icon="󰂄"
    elif (( percentage <= 15 )); then
        icon="󰁺"
    elif (( percentage <= 40 )); then
        icon="󰁼"
    elif (( percentage <= 70 )); then
        icon="󰁾"
    else
        icon="󰁹"
    fi
    printf '%s  %s%%\n' "$icon" "$percentage"
}

weather() {
    local cache="$state_dir/weather.json"
    [[ -f $cache ]] || return 0
    command -v jq >/dev/null || return 0
    local icon temperature condition
    icon=$(jq -r '.icon // empty' "$cache" 2>/dev/null || true)
    temperature=$(jq -r '.temperatureLabel // empty' "$cache" 2>/dev/null || true)
    condition=$(jq -r '.condition // empty' "$cache" 2>/dev/null || true)
    [[ -n $temperature && -n $condition ]] || return 0
    printf '%s  %s  ·  %s\n' "$icon" "$temperature" \
        "$(escape_markup "$(printf '%s' "$condition" | single_line)")"
}

media() {
    command -v playerctl >/dev/null || return 0
    local selected="" player status title artist
    while IFS= read -r player; do
        [[ -n $player ]] || continue
        status=$(playerctl --player "$player" status 2>/dev/null || true)
        if [[ $status == Playing ]]; then
            selected=$player
            break
        fi
    done < <(playerctl --list-all 2>/dev/null || true)
    [[ -n $selected ]] || return 0
    title=$(playerctl --player "$selected" metadata title 2>/dev/null \
        | single_line || true)
    artist=$(playerctl --player "$selected" metadata artist 2>/dev/null \
        | single_line || true)
    [[ -n $title ]] || return 0
    title=$(escape_markup "$title")
    artist=$(escape_markup "$artist")
    if [[ -n $artist ]]; then
        printf '󰎈  %s  —  %s\n' "$title" "$artist"
    else
        printf '󰎈  %s\n' "$title"
    fi
}

case ${1:-} in
    wallpaper) wallpaper ;;
    identity) identity ;;
    battery) battery ;;
    weather) weather ;;
    media) media ;;
    probe)
        printf 'WALLPAPER=%s\n' "$(wallpaper)"
        printf 'IDENTITY=%s\n' "$(identity)"
        printf 'BATTERY=%s\n' "$(battery)"
        printf 'WEATHER=%s\n' "$(weather)"
        printf 'MEDIA=%s\n' "$(media)"
        ;;
    *)
        printf 'usage: %s {wallpaper|identity|battery|weather|media|probe}\n' "$0" >&2
        exit 64
        ;;
esac
