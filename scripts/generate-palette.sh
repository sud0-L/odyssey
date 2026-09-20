#!/usr/bin/env bash
set -euo pipefail

if (( $# < 1 || $# > 5 )); then
    printf 'usage: %s [image|color] SOURCE [SCHEME] [OUTPUT] [MODE]\n' "$0" >&2
    exit 2
fi

project_dir=$(cd "$(dirname "$0")/.." && pwd)
if [[ $1 == image || $1 == color ]]; then
    source_kind=$1
    source_value=${2:-}
    scheme=${3:-scheme-content}
    output_arg=${4:-}
    requested_mode=${5:-}
else
    # Backward-compatible image invocation used by older installed helpers.
    source_kind=image
    source_value=$1
    scheme=${2:-scheme-content}
    output_arg=${3:-}
    requested_mode=
fi
state_root=${XDG_STATE_HOME:-"${HOME:?HOME is required}/.local/state"}
output=${output_arg:-"$state_root/odyssey/palette.json"}
temp_config=$(mktemp)
output_dir=$(dirname "$output")
mkdir -p "$output_dir"
temp_palette=$(mktemp "$output_dir/.palette.XXXXXX.json")
trap 'rm -f "$temp_config" "$temp_palette"' EXIT

if [[ $source_kind == image ]]; then
    [[ -f $source_value ]] || {
        printf 'wallpaper not found: %s\n' "$source_value" >&2
        exit 1
    }
elif [[ ! $source_value =~ ^#[0-9a-fA-F]{6}$ ]]; then
    printf 'invalid theme source color: %s\n' "$source_value" >&2
    exit 2
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

if [[ $requested_mode == dark || $requested_mode == light ]]; then
    palette_mode=$requested_mode
elif [[ $source_kind == image ]]; then
    palette_mode=$("$project_dir/scripts/wallpaper-mode.sh" "$source_value")
elif [[ -f $output ]]; then
    palette_mode=$(jq -r 'if .mode == "light" then "light" else "dark" end' "$output")
else
    palette_mode=dark
fi

matugen_args=(--config "$temp_config" --type "$scheme"
    --mode "$palette_mode" --quiet)
if [[ $source_kind == image ]]; then
    matugen image "$source_value" "${matugen_args[@]}" --source-color-index 0
else
    matugen color hex "$source_value" "${matugen_args[@]}"
fi

jq -e '
    (.mode == "dark" or .mode == "light") and
    (.dark | has("primary") and has("surface") and has("onSurface")) and
    (.light | has("primary") and has("surface") and has("onSurface"))
' "$temp_palette" >/dev/null

chmod 0600 "$temp_palette"
mv -f "$temp_palette" "$output"

printf 'generated %s\n' "$output"
