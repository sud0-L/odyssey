#!/bin/sh
set -eu

action=${1:-}
entry_id=${2:-}

valid_uint() {
    case ${1:-} in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}

valid_format() {
    case ${1:-} in png|jpeg|jpg|webp) return 0 ;; *) return 1 ;; esac
}

runtime_dir() {
    test -n "${XDG_RUNTIME_DIR:-}" && test -d "$XDG_RUNTIME_DIR" || return 1
    printf '%s\n' "$XDG_RUNTIME_DIR"
}

valid_session_dir() {
    target=${1:-}
    base=$(runtime_dir) || return 1
    case "$target" in "$base"/odyssey-clipboard.*) ;; *) return 1 ;; esac
    test -d "$target" || return 1
    test "$(dirname -- "$target")" = "$base" || return 1
}

within_bounds() {
    size=$1 width=$2 height=$3 max_bytes=$4 max_dimension=$5 max_pixels=$6
    valid_uint "$size" && valid_uint "$width" && valid_uint "$height" \
        && valid_uint "$max_bytes" && valid_uint "$max_dimension" \
        && valid_uint "$max_pixels" || return 1
    test "$size" -gt 0 && test "$size" -le "$max_bytes" \
        && test "$width" -gt 0 && test "$width" -le "$max_dimension" \
        && test "$height" -gt 0 && test "$height" -le "$max_dimension" \
        && test "$width" -le $((max_pixels / height))
}

render_thumbnail() {
    input=$1 output=$2 width=$3 height=$4
    temporary="$output.tmp.$$.png"
    rm -f -- "$temporary"
    timeout 8 ffmpeg -v error -nostdin -y -i "$input" -frames:v 1 \
        -map_metadata -1 -vf "scale=${width}:${height}:force_original_aspect_ratio=decrease" \
        -f image2 "$temporary" || { rm -f -- "$temporary"; return 1; }
    mv -f -- "$temporary" "$output"
}

valid_source_dimensions() {
    input=$1 max_dimension=$2 max_pixels=$3
    dimensions=$(timeout 4 ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height -of csv=p=0:s=x "$input" 2>/dev/null) || return 1
    width=${dimensions%x*}; height=${dimensions#*x}
    valid_uint "$width" && valid_uint "$height" && test "$width" -gt 0 \
        && test "$height" -gt 0 && test "$width" -le "$max_dimension" \
        && test "$height" -le "$max_dimension" && test "$width" -le $((max_pixels / height))
}

case "$action" in
    copy)
        case "$entry_id" in
            ''|*[!0-9]*)
                printf 'invalid clipboard entry id\n' >&2
                exit 2
                ;;
        esac
        printf '%s\t\n' "$entry_id" | cliphist decode | wl-copy
        ;;
    delete)
        case "$entry_id" in
            ''|*[!0-9]*)
                printf 'invalid clipboard entry id\n' >&2
                exit 2
                ;;
        esac
        printf '%s\t\n' "$entry_id" | cliphist delete
        ;;
    wipe)
        if [ -n "$entry_id" ]; then
            printf 'wipe does not accept an entry id\n' >&2
            exit 2
        fi
        cliphist wipe
        ;;
    open-preview-session)
        test -z "$entry_id" || { printf 'session does not accept arguments\n' >&2; exit 2; }
        base=$(runtime_dir) || { printf 'private runtime directory is unavailable\n' >&2; exit 1; }
        umask 077
        mktemp -d "$base/odyssey-clipboard.XXXXXX"
        ;;
    close-preview-session)
        valid_session_dir "$entry_id" || { printf 'invalid preview session\n' >&2; exit 2; }
        rm -rf -- "$entry_id"
        ;;
    thumbnail)
        format=${3:-}; byte_size=${4:-}; width=${5:-}; height=${6:-}
        session_dir=${7:-}; output_name=${8:-}
        valid_uint "$entry_id" && valid_format "$format" \
            && within_bounds "$byte_size" "$width" "$height" \
                "${9:-}" "${10:-}" "${11:-}" \
            && valid_session_dir "$session_dir" \
            && [ "$output_name" = "$entry_id.png" ] \
            || { printf 'invalid thumbnail request\n' >&2; exit 2; }
        output="$session_dir/$output_name"
        input="$session_dir/.${entry_id}.source.$$"
        trap 'rm -f -- "$input"' EXIT HUP INT TERM
        timeout 8 sh -c 'printf "%s\\t\\n" "$1" | cliphist decode > "$2"' sh "$entry_id" "$input"
        actual_size=$(wc -c < "$input")
        within_bounds "$actual_size" "$width" "$height" "${9:-}" "${10:-}" "${11:-}" \
            || { printf 'image exceeds preview limits\n' >&2; exit 1; }
        valid_source_dimensions "$input" "${10:-}" "${11:-}" \
            || { printf 'image dimensions exceed preview limits\n' >&2; exit 1; }
        render_thumbnail "$input" "$output" "${12:-160}" "${13:-100}"
        ;;
    probe-current)
        session_dir=${2:-}; output_name=${3:-}; max_bytes=${4:-}
        max_dimension=${5:-}; max_pixels=${6:-}; thumb_width=${7:-}; thumb_height=${8:-}
        valid_session_dir "$session_dir" && [ "$output_name" = "current.png" ] \
            && valid_uint "$max_bytes" && valid_uint "$max_dimension" \
            && valid_uint "$max_pixels" && valid_uint "$thumb_width" && valid_uint "$thumb_height" \
            || { printf 'invalid current preview request\n' >&2; exit 2; }
        mime=$(wl-paste --list-types 2>/dev/null | sed -n '/^image\/png$/p;/^image\/jpeg$/p;/^image\/webp$/p' | head -n 1)
        if [ -z "$mime" ]; then
            if wl-paste --list-types 2>/dev/null | grep -q '^image/'; then printf 'kind=unsupported\n'; else printf 'kind=empty\n'; fi
            exit 0
        fi
        input="$session_dir/.current.source.$$"; output="$session_dir/$output_name"
        trap 'rm -f -- "$input"' EXIT HUP INT TERM
        timeout 8 wl-paste --type "$mime" > "$input" || { printf 'kind=unsupported\n'; exit 0; }
        actual_size=$(wc -c < "$input")
        test "$actual_size" -gt 0 && test "$actual_size" -le "$max_bytes" \
            || { printf 'kind=unsupported\n'; exit 0; }
        valid_source_dimensions "$input" "$max_dimension" "$max_pixels" \
            || { printf 'kind=unsupported\n'; exit 0; }
        render_thumbnail "$input" "$output" "$thumb_width" "$thumb_height" \
            || { printf 'kind=unsupported\n'; exit 0; }
        printf 'kind=image\nformat=%s\n' "${mime#image/}"
        ;;
    *)
        printf 'usage: clipboardctl.sh <copy|delete> <numeric-id> | wipe | preview action\n' >&2
        exit 2
        ;;
esac
