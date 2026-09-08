#!/usr/bin/env bash
set -euo pipefail

if (( $# < 1 || $# > 3 )); then
    printf 'usage: %s WALLPAPER [SCHEME] [OUTPUT]\n' "$0" >&2
    exit 2
fi

project_dir=$(cd "$(dirname "$0")/.." && pwd)
wallpaper=$1
scheme=${2:-scheme-content}
state_root=${XDG_STATE_HOME:-"${HOME:?HOME is required}/.local/state"}
output=${3:-"$state_root/odyssey/palette.json"}
temp_config=$(mktemp)
output_dir=$(dirname "$output")
mkdir -p "$output_dir"
temp_palette=$(mktemp "$output_dir/.palette.XXXXXX.json")
trap 'rm -f "$temp_config" "$temp_palette"' EXIT

if [[ ! -f "$wallpaper" ]]; then
    printf 'wallpaper not found: %s\n' "$wallpaper" >&2
    exit 1
fi

command -v matugen >/dev/null || {
    printf 'matugen is required to generate a palette\n' >&2
    exit 1
}

case $scheme in
    scheme-content|scheme-tonal-spot|scheme-vibrant|scheme-monochrome|\
    scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-neutral|\
    scheme-rainbow) ;;
    *)
        printf 'unsupported palette scheme: %s\n' "$scheme" >&2
        exit 2
        ;;
esac

# Matugen 4.1 does not reliably combine relative template paths with --prefix.
# Resolve only this temporary config and render beside the final palette so the
# validated file can replace it atomically on the same filesystem.
sed -e "s#input_path = \"\./matugen/palette.json\"#input_path = \"$project_dir/matugen/palette.json\"#" \
    -e "s#output_path = \"\./generated/palette.json\"#output_path = \"$temp_palette\"#" \
    "$project_dir/matugen/config.toml" > "$temp_config"

palette_mode=$("$project_dir/scripts/wallpaper-mode.sh" "$wallpaper")

matugen image "$wallpaper" \
    --config "$temp_config" \
    --type "$scheme" \
    --mode "$palette_mode" \
    --source-color-index 0 \
    --quiet

jq -e '
    (.mode == "dark" or .mode == "light") and
    (.dark | has("primary") and has("surface") and has("onSurface")) and
    (.light | has("primary") and has("surface") and has("onSurface"))
' "$temp_palette" >/dev/null

chmod 0600 "$temp_palette"
mv -f "$temp_palette" "$output"

printf 'generated %s\n' "$output"
