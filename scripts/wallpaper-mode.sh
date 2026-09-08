#!/usr/bin/env bash
set -euo pipefail

if (( $# != 1 )); then
    printf 'usage: %s WALLPAPER\n' "$0" >&2
    exit 2
fi

wallpaper=$1
[[ -f $wallpaper ]] || {
    printf 'wallpaper not found: %s\n' "$wallpaper" >&2
    exit 1
}

# Auto mode is intentionally conservative when the optional decoder is absent.
# A one-pixel downsample measures the whole image without retaining image data.
mode=dark
if command -v ffmpeg >/dev/null; then
    pixel_values=$(ffmpeg -v error -i "$wallpaper" -vf 'scale=1:1' \
        -frames:v 1 -f rawvideo -pix_fmt rgb24 - 2>/dev/null \
        | od -An -v -tu1 | awk 'NF >= 3 { print $1, $2, $3; exit }') || true
    read -r red green blue <<< "$pixel_values"
    if [[ ${red:-} =~ ^[0-9]+$ && ${green:-} =~ ^[0-9]+$ \
            && ${blue:-} =~ ^[0-9]+$ ]]; then
        # Integer Rec. 709 luma in the source image's display-referred RGB space.
        luma=$(( (2126 * red + 7152 * green + 722 * blue) / 10000 ))
        (( luma >= 128 )) && mode=light
    fi
fi

printf '%s\n' "$mode"
