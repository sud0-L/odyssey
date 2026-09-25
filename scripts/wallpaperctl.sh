#!/usr/bin/env bash
# Transaction boundary for Odyssey's private awww renderer namespace.
set -euo pipefail

project_dir=$(cd "$(dirname "$0")/.." && pwd)
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/odyssey"
runtime_root="${XDG_RUNTIME_DIR:-/tmp}/odyssey"
cache_root="${ODYSSEY_PALETTE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/odyssey/palettes}"
current_file="$state_dir/current-wallpaper"
manifest_file="$state_dir/wallpaper-manifest.json"
sddm_wallpaper_file="${ODYSSEY_SDDM_WALLPAPER_EXPORT:-/var/tmp/odyssey-sddm-current-wallpaper}"
recovery_file="$state_dir/awww-recovery-attempts"
request_file="$runtime_root/wallpaper-request"
candidate_dir="$runtime_root/wallpaper-candidate"
active_palette="${ODYSSEY_ACTIVE_PALETTE:-$state_dir/palette.json}"
palette_generator="${ODYSSEY_PALETTE_GENERATOR:-$project_dir/scripts/generate-palette.sh}"
namespace=odyssey
recovery_window=60
recovery_limit=3
probe_count="${ODYSSEY_AWWW_PROBE_COUNT:-10}"
probe_delay="${ODYSSEY_AWWW_PROBE_DELAY:-0.2}"
verify_delay="${ODYSSEY_AWWW_VERIFY_DELAY:-}"
backoff_base="${ODYSSEY_AWWW_BACKOFF_BASE:-0.2}"
palette_cache_version=1
palette_cache_limit="${ODYSSEY_PALETTE_CACHE_LIMIT:-64}"

mkdir -p "$state_dir" "$runtime_root"
chmod 700 "$runtime_root" 2>/dev/null || true

say() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }
valid_image() { [[ -f $1 && ${1,,} =~ \.(png|jpe?g|webp)$ ]]; }
canonical() { realpath -e -- "$1" 2>/dev/null; }
valid_palette() {
    jq -e '
        (.mode == "dark" or .mode == "light") and
        (.dark | has("primary") and has("surface") and has("onSurface")) and
        (.light | has("primary") and has("surface") and has("onSurface"))
    ' "$1" >/dev/null 2>&1
}
query() { awww query --namespace "$namespace" --json; }
ready() { query >/dev/null 2>&1; }
conflict() { pgrep -x hyprpaper >/dev/null 2>&1; }

images() {
    # awww 0.12 groups outputs by namespace. Fixtures use the direct array form.
    query | jq -c '
        (if type == "object" then [.[] | .[]?] else . end)
        | [.[] | {
            name: (.name // .output // ""),
            image: (.displaying.image // .image // .path // "")
        }]
        | map(select(.name != ""))
    '
}

requested_outputs_exist() {
    local snapshot=$1 names=$2
    jq -e --arg names "$names" '
        . as $rows | ($names | split(",") | map(select(length > 0))) as $wanted
        | ($wanted | length) > 0
        and all($wanted[]; . as $name | any($rows[]; .name == $name))
    ' <<<"$snapshot" >/dev/null
}

verify_assignments() {
    local expected=$1 actual
    actual=$(images) || return 1
    jq -e --argjson actual "$actual" '
        . as $expected
        | all($expected[]; . as $want
            | any($actual[]; .name == $want.name and .image == $want.image))
    ' <<<"$expected" >/dev/null
}

select_assignments() {
    local snapshot=$1 names=$2
    jq -c --arg names "$names" '
        ($names | split(",") | map(select(length > 0))) as $wanted
        | [.[] | select(.name as $name | any($wanted[]; . == $name))]
    ' <<<"$snapshot"
}

render_assignments() {
    local assignments=$1 image names result=0
    while IFS= read -r image; do
        [[ -n $image ]] || continue
        names=$(jq -r --arg image "$image" '
            [.[] | select(.image == $image) | .name] | join(",")
        ' <<<"$assignments")
        [[ -n $names ]] || continue
        if ! valid_image "$image"; then
            printf 'committed wallpaper is unavailable: %s\n' "$image" >&2
            result=1
            continue
        fi
        awww img --namespace "$namespace" --outputs "$names" \
            --transition-type none "$image" || result=1
    done < <(jq -r '.[].image' <<<"$assignments" | sort -u)
    return "$result"
}

restore_snapshot() {
    local snapshot=$1 names=${2:-} expected
    expected=$snapshot
    if [[ -n $names ]]; then
        expected=$(select_assignments "$snapshot" "$names")
    fi
    render_assignments "$expected" || return 1
    verify_assignments "$expected"
}

effect_args() {
    local effect=$1 duration=$2 reduced=$3
    if [[ $reduced == true ]]; then
        printf '%s\0' --transition-type none
        return
    fi
    printf '%s\0' --transition-duration "$duration"
    case $effect in
        fade) printf '%s\0' --transition-type fade ;;
        slide) printf '%s\0' --transition-type left ;;
        wipe) printf '%s\0' --transition-type wipe --transition-angle 45 ;;
        wave) printf '%s\0' --transition-type wave --transition-angle 45 --transition-wave 20,20 ;;
        expand) printf '%s\0' --transition-type center ;;
        contract) printf '%s\0' --transition-type outer ;;
        spotlight) printf '%s\0' --transition-type any ;;
        random) printf '%s\0' --transition-type random ;;
        *) die 'unsupported transition' ;;
    esac
}

clamp_duration() {
    awk -v d="$1" 'BEGIN {
        if (d !~ /^[0-9]+([.][0-9]+)?$/) d=.9
        d=(d<.3?.3:(d>2.5?2.5:d)); printf "%.1f", int(d*10+.5)/10
    }'
}

prune_recovery_attempts() {
    local now cutoff temp
    now=$(date +%s)
    cutoff=$((now - recovery_window))
    temp=$(mktemp "$state_dir/.recovery.XXXXXX")
    if [[ -f $recovery_file ]]; then
        awk -v cutoff="$cutoff" '$1 ~ /^[0-9]+$/ && $1 >= cutoff' \
            "$recovery_file" >"$temp"
    fi
    chmod 600 "$temp"
    mv -f "$temp" "$recovery_file"
}

start_renderer() {
    local mode=${1:-auto} attempts attempt poll backoff
    command -v awww >/dev/null && command -v awww-daemon >/dev/null \
        || { say STATE=missing; return 1; }
    if ready; then
        say STATE=ready
        return 0
    fi
    if conflict; then
        say STATE=conflict
        return 2
    fi
    if [[ $mode == probe ]]; then
        say STATE=unavailable
        return 1
    fi
    if [[ $mode == manual ]]; then
        : >"$recovery_file"
        chmod 600 "$recovery_file"
    fi
    prune_recovery_attempts
    attempts=$(wc -l <"$recovery_file")
    if [[ $mode != manual && $attempts -ge $recovery_limit ]]; then
        say STATE=exhausted
        return 1
    fi
    attempt=$((attempts + 1))
    date +%s >>"$recovery_file"
    say STATE=recovering
    say "ATTEMPT=$attempt"
    if [[ $backoff_base != 0 && $attempt -gt 1 ]]; then
        backoff=$(awk -v base="$backoff_base" -v attempt="$attempt" \
            'BEGIN { printf "%.2f", base * (2 ^ (attempt - 2)) }')
        sleep "$backoff"
    fi
    (XDG_CACHE_HOME="$runtime_root/cache" awww-daemon --namespace "$namespace" \
        --no-cache --quiet >/dev/null 2>&1 &)
    poll=0
    while (( poll < probe_count )); do
        sleep "$probe_delay"
        if ready; then
            say STATE=ready
            return 0
        fi
        ((poll += 1))
    done
    prune_recovery_attempts
    attempts=$(wc -l <"$recovery_file")
    if [[ $mode != manual && $attempts -ge $recovery_limit ]]; then
        say STATE=exhausted
    else
        say STATE=unavailable
    fi
    return 1
}

reconcile_manifest() {
    local live committed fallback desired image
    [[ -f $manifest_file ]] || return 0
    jq -e '.version == 2 and (.wallpaper | type == "string")
        and (.scheme | type == "string") and (.assignments | type == "array")' \
        "$manifest_file" >/dev/null || return 1
    live=$(images) || return 1
    committed=$(jq -c '.assignments' "$manifest_file")
    fallback=$(jq -r '.wallpaper' "$manifest_file")
    valid_image "$fallback" || return 1
    desired=$(jq -cn --argjson live "$live" --argjson committed "$committed" \
        --arg fallback "$fallback" '
        [$live[] | .name as $name
            | {name: $name,
               image: (([$committed[] | select(.name == $name) | .image][0])
                   // $fallback)}]
    ')
    while IFS= read -r image; do
        [[ -z $image ]] || valid_image "$image" || return 1
    done < <(jq -r '.[].image' <<<"$desired" | sort -u)
    render_assignments "$desired" || return 1
    verify_assignments "$desired"
}

candidate_matches() {
    local image=$1 scheme=$2 token=$3 source_mode=${4:-wallpaper}
    local source_color=${5:-}
    [[ -f $candidate_dir/manifest.json && -f $candidate_dir/palette.json ]] \
        || return 1
    jq -e --arg image "$image" --arg scheme "$scheme" --arg token "$token" \
        --arg sourceMode "$source_mode" --arg sourceColor "$source_color" '
        .image == $image and .scheme == $scheme and .token == $token
        and (.sourceMode // "wallpaper") == $sourceMode
        and (.sourceColor // "") == $sourceColor
    ' "$candidate_dir/manifest.json" >/dev/null
}

valid_source() {
    [[ $1 == wallpaper ]] || [[ $1 == color && $2 =~ ^#[0-9a-fA-F]{6}$ ]]
}

prepare_candidate() {
    local image=$1 scheme=$2 token=$3 source_mode=${4:-wallpaper}
    local source_color=${5:-} palette_mode=
    valid_source "$source_mode" "$source_color" || die 'invalid theme source'
    rm -rf "$candidate_dir"
    mkdir -p "$candidate_dir"
    chmod 700 "$candidate_dir"
    if [[ $source_mode == color ]]; then
        if [[ -f $active_palette ]]; then
            palette_mode=$(jq -r 'if .mode == "light" then "light" else "dark" end' \
                "$active_palette")
        fi
        "$palette_generator" color "$source_color" "$scheme" \
            "$candidate_dir/palette.json" "$palette_mode" >/dev/null
    else
        if ! cached_palette "$image" "$scheme" \
                "$candidate_dir/palette.json"; then
            "$palette_generator" image "$image" "$scheme" \
                "$candidate_dir/palette.json" >/dev/null
            store_cached_palette "$image" "$scheme" \
                "$candidate_dir/palette.json" || true
        fi
    fi
    jq -n --arg image "$image" --arg scheme "$scheme" --arg token "$token" \
        --arg sourceMode "$source_mode" --arg sourceColor "$source_color" \
        '{image:$image,scheme:$scheme,token:$token,sourceMode:$sourceMode,
          sourceColor:$sourceColor}' >"$candidate_dir/manifest.json"
    chmod 600 "$candidate_dir"/*.json
}

write_request_token() {
    local token=$1 temporary
    temporary=$(mktemp "$runtime_root/.wallpaper-request.XXXXXX")
    printf '%s\n' "$token" >"$temporary"
    chmod 600 "$temporary"
    mv -f -- "$temporary" "$request_file"
}

request_is_current() {
    local token=$1
    [[ -f $request_file && $(<"$request_file") == "$token" ]]
}

prepare_palette_cache() {
    [[ $cache_root == /* && $cache_root != / ]] || return 1
    if [[ -e $cache_root || -L $cache_root ]]; then
        [[ -d $cache_root && ! -L $cache_root ]] || return 1
        [[ $(stat -c '%u' -- "$cache_root" 2>/dev/null) == "$UID" ]] || return 1
    else
        mkdir -p -- "$cache_root" 2>/dev/null || return 1
    fi
    chmod 700 "$cache_root" 2>/dev/null || return 1
}

palette_cache_key() {
    local image=$1 scheme=$2 metadata engine generator
    metadata=$(stat -c '%s:%y' -- "$image") || return 1
    engine=$(matugen --version 2>/dev/null | head -n 1) || return 1
    generator=$(sha256sum -- "$palette_generator" \
        "$project_dir/scripts/wallpaper-mode.sh" \
        "$project_dir/matugen/config.toml" "$project_dir/matugen/palette.json" \
        | sha256sum | awk '{print $1}') || return 1
    printf '%s\0%s\0%s\0%s\0%s\0%s' "$palette_cache_version" "$image" \
        "$metadata" "$scheme" "$engine" "$generator" \
        | sha256sum | awk '{print $1}'
}

cached_palette() {
    local image=$1 scheme=$2 destination=$3 key entry
    prepare_palette_cache || return 1
    key=$(palette_cache_key "$image" "$scheme") || return 1
    entry="$cache_root/$key.json"
    if [[ ! -f $entry || -L $entry ]] || ! valid_palette "$entry"; then
        [[ ! -e $entry && ! -L $entry ]] || rm -f -- "$entry"
        return 1
    fi
    install -m 600 -- "$entry" "$destination" || return 1
    touch -- "$entry" 2>/dev/null || true
}

prune_palette_cache() {
    local limit=$palette_cache_limit index entry
    [[ $limit =~ ^[0-9]+$ ]] || limit=64
    (( limit >= 1 )) || limit=1
    index=0
    while IFS= read -r entry; do
        ((index += 1))
        (( index <= limit )) || rm -f -- "$entry"
    done < <(find "$cache_root" -maxdepth 1 -type f -name '*.json' \
        -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-)
}

store_cached_palette() {
    local image=$1 scheme=$2 source=$3 key entry temporary
    prepare_palette_cache || return 1
    valid_palette "$source" || return 1
    key=$(palette_cache_key "$image" "$scheme") || return 1
    entry="$cache_root/$key.json"
    temporary=$(mktemp "$cache_root/.palette.XXXXXX") || return 1
    if ! install -m 600 -- "$source" "$temporary" \
            || ! mv -f -- "$temporary" "$entry"; then
        rm -f -- "$temporary"
        return 1
    fi
    prune_palette_cache
}

restore_file() {
    local backup=$1 destination=$2 existed=$3
    if [[ $existed == true ]]; then
        cp -f -- "$backup" "$destination"
        chmod 600 "$destination"
    else
        rm -f -- "$destination"
    fi
}

publish_sddm_wallpaper() {
    local image=$1 parent base temporary owner
    [[ $sddm_wallpaper_file == /* && $sddm_wallpaper_file != / ]] \
        || return 1
    parent=${sddm_wallpaper_file%/*}
    base=${sddm_wallpaper_file##*/}
    [[ -n $parent && -n $base && -d $parent && ! -L $parent ]] || return 1
    if [[ -e $sddm_wallpaper_file || -L $sddm_wallpaper_file ]]; then
        [[ -f $sddm_wallpaper_file && ! -L $sddm_wallpaper_file ]] || return 1
        owner=$(stat -c '%u' -- "$sddm_wallpaper_file") || return 1
        [[ $owner == $UID ]] || return 1
    fi
    temporary=$(mktemp "$parent/.${base}.XXXXXX") || return 1
    if ! install -m 0644 -- "$image" "$temporary" \
            || ! mv -f -- "$temporary" "$sddm_wallpaper_file"; then
        rm -f -- "$temporary"
        return 1
    fi
}

restore_sddm_wallpaper() {
    local backup=$1 existed=$2
    if [[ $existed == true ]]; then
        install -m 0644 -- "$backup" "$sddm_wallpaper_file"
    else
        rm -f -- "$sddm_wallpaper_file"
    fi
}

publish_commit() {
    local image=$1 assignments=$2 scheme=$3 source_mode=${4:-wallpaper}
    local source_color=${5:-} transaction
    local palette_existed=false manifest_existed=false current_existed=false sddm_existed=false
    transaction=$(mktemp -d "$runtime_root/.wallpaper-publish.XXXXXX")
    trap 'rm -rf "$transaction"' RETURN
    if [[ -f $active_palette ]]; then
        cp -f -- "$active_palette" "$transaction/palette.before"
        palette_existed=true
    fi
    if [[ -f $manifest_file ]]; then
        cp -f -- "$manifest_file" "$transaction/manifest.before"
        manifest_existed=true
    fi
    if [[ -f $current_file ]]; then
        cp -f -- "$current_file" "$transaction/current.before"
        current_existed=true
    fi
    if [[ -e $sddm_wallpaper_file || -L $sddm_wallpaper_file ]]; then
        [[ -f $sddm_wallpaper_file && ! -L $sddm_wallpaper_file ]] || return 1
        cp -f -- "$sddm_wallpaper_file" "$transaction/sddm.before"
        sddm_existed=true
    fi
    install -m 600 "$candidate_dir/palette.json" "$transaction/palette.next"
    jq -n --arg wallpaper "$image" --arg scheme "$scheme" \
        --arg sourceMode "$source_mode" --arg sourceColor "$source_color" \
        --argjson assignments "$assignments" \
        '{version:2,wallpaper:$wallpaper,scheme:$scheme,assignments:$assignments,
          sourceMode:$sourceMode,sourceColor:$sourceColor}' \
        >"$transaction/manifest.next"
    printf '%s\n' "$image" >"$transaction/current.next"
    chmod 600 "$transaction/manifest.next" "$transaction/current.next"
    if [[ ${ODYSSEY_FAIL_PUBLICATION:-false} == true ]]; then
        return 1
    fi
    if ! publish_sddm_wallpaper "$image" \
        || ! install -m 600 "$transaction/palette.next" "$active_palette" \
        || ! install -m 600 "$transaction/manifest.next" "$manifest_file" \
        || ! install -m 600 "$transaction/current.next" "$current_file"; then
        restore_file "$transaction/palette.before" "$active_palette" "$palette_existed" || true
        restore_file "$transaction/manifest.before" "$manifest_file" "$manifest_existed" || true
        restore_file "$transaction/current.before" "$current_file" "$current_existed" || true
        restore_sddm_wallpaper "$transaction/sddm.before" "$sddm_existed" || true
        return 1
    fi
    rm -rf "$transaction"
    trap - RETURN
}

publish_wallpaper_only() {
    local image=$1 assignments=$2 scheme=$3 source_mode=${4:-wallpaper}
    local source_color=${5:-} transaction
    local manifest_existed=false current_existed=false sddm_existed=false
    transaction=$(mktemp -d "$runtime_root/.wallpaper-publish.XXXXXX")
    trap 'rm -rf "$transaction"' RETURN
    if [[ -f $manifest_file ]]; then
        cp -f -- "$manifest_file" "$transaction/manifest.before"
        manifest_existed=true
    fi
    if [[ -f $current_file ]]; then
        cp -f -- "$current_file" "$transaction/current.before"
        current_existed=true
    fi
    if [[ -e $sddm_wallpaper_file || -L $sddm_wallpaper_file ]]; then
        [[ -f $sddm_wallpaper_file && ! -L $sddm_wallpaper_file ]] || return 1
        cp -f -- "$sddm_wallpaper_file" "$transaction/sddm.before"
        sddm_existed=true
    fi
    jq -n --arg wallpaper "$image" --arg scheme "$scheme" \
        --arg sourceMode "$source_mode" --arg sourceColor "$source_color" \
        --argjson assignments "$assignments" \
        '{version:2,wallpaper:$wallpaper,scheme:$scheme,assignments:$assignments,
          sourceMode:$sourceMode,sourceColor:$sourceColor}' \
        >"$transaction/manifest.next"
    printf '%s\n' "$image" >"$transaction/current.next"
    chmod 600 "$transaction/manifest.next" "$transaction/current.next"
    if [[ ${ODYSSEY_FAIL_PUBLICATION:-false} == true ]] \
            || ! publish_sddm_wallpaper "$image" \
            || ! install -m 600 "$transaction/manifest.next" "$manifest_file" \
            || ! install -m 600 "$transaction/current.next" "$current_file"; then
        restore_file "$transaction/manifest.before" "$manifest_file" "$manifest_existed" || true
        restore_file "$transaction/current.before" "$current_file" "$current_existed" || true
        restore_sddm_wallpaper "$transaction/sddm.before" "$sddm_existed" || true
        return 1
    fi
    rm -rf "$transaction"
    trap - RETURN
}

publish_palette_only() {
    local palette_dir=${1:-$candidate_dir} transaction palette_existed=false
    transaction=$(mktemp -d "$runtime_root/.theme-source-publish.XXXXXX")
    trap 'rm -rf "$transaction"' RETURN
    if [[ -f $active_palette ]]; then
        cp -f -- "$active_palette" "$transaction/palette.before"
        palette_existed=true
    fi
    install -m 600 "$palette_dir/palette.json" "$transaction/palette.next"
    if [[ ${ODYSSEY_FAIL_PUBLICATION:-false} == true ]] \
            || ! install -m 600 "$transaction/palette.next" "$active_palette"; then
        restore_file "$transaction/palette.before" "$active_palette" \
            "$palette_existed" || true
        return 1
    fi
    rm -rf "$palette_dir" "$transaction"
    trap - RETURN
}

case ${1:-} in
    list)
        shift
        roots=()
        for root in "$@"; do [[ -d $root ]] && roots+=("$root"); done
        ((${#roots[@]})) && find "${roots[@]}" -maxdepth 3 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
                -o -iname '*.webp' \) -print 2>/dev/null | sort -u
        ;;
    probe)
        start_renderer probe || true
        [[ -f $current_file ]] && say "CURRENT=$(<"$current_file")"
        true
        ;;
    bootstrap)
        mode=${2:-auto}
        if start_renderer "$mode"; then
            if reconcile_manifest; then
                say RECONCILED=true
                [[ -f $current_file ]] && say "CURRENT=$(<"$current_file")"
                true
            else
                say RECONCILED=false
                die 'committed wallpaper reconciliation failed'
            fi
        else
            exit 1
        fi
        ;;
    candidate)
        image=$(canonical "$2") || die 'wallpaper does not exist'
        valid_image "$image" || die 'unsupported wallpaper format'
        scheme=$3
        token=$4
        source_mode=${5:-wallpaper}
        source_color=${6:-}
        prepare_candidate "$image" "$scheme" "$token" "$source_mode" \
            "$source_color"
        say "CANDIDATE=$candidate_dir"
        ;;
    theme-source)
        source_mode=$2
        source_color=$3
        if [[ $source_mode == wallpaper ]]; then
            image=$(canonical "$4") || die 'wallpaper does not exist'
            valid_image "$image" || die 'unsupported wallpaper format'
        else
            image=
        fi
        scheme=$5
        token=$6
        prepare_candidate "$image" "$scheme" "$token" "$source_mode" \
            "$source_color"
        publish_palette_only || die 'palette publication failed'
        say PALETTE=updated
        say COMMITTED=true
        ;;
    cancel-candidate)
        rm -rf "$candidate_dir"
        say CANCELLED=true
        ;;
    render)
        image=$(canonical "$2") || die 'wallpaper does not exist'
        valid_image "$image" || die 'unsupported wallpaper format'
        scheme=$3
        target=$4
        names=$5
        effect=$6
        seconds=$(clamp_duration "$7")
        reduced=${8:-false}
        token=$9
        source_mode=${10:-wallpaper}
        source_color=${11:-}
        [[ $target == current || $target == all ]] || die 'invalid output target'
        valid_source "$source_mode" "$source_color" || die 'invalid theme source'
        write_request_token "$token"
        start_renderer auto >/dev/null || die 'renderer unavailable'
        [[ -n $names ]] || die 'no live outputs'
        before=$(images) || die 'renderer query failed'
        requested_outputs_exist "$before" "$names" || die 'requested output unavailable'
        expected=$(jq -c --arg image "$image" --arg names "$names" '
            ($names | split(",") | map(select(length > 0))) as $wanted
            | [.[] | if (.name as $name | any($wanted[]; . == $name))
                then .image = $image else . end]
        ' <<<"$before")
        mapfile -d '' args < <(effect_args "$effect" "$seconds" "$reduced")
        if ! awww img --namespace "$namespace" --outputs "$names" \
                "${args[@]}" "$image"; then
            restore_snapshot "$before" "$names" || true
            die 'renderer apply failed; previous assignments restored'
        fi
        if ! verify_assignments "$(select_assignments "$expected" "$names")"; then
            restore_snapshot "$before" "$names" || true
            die 'renderer verification failed; previous assignments restored'
        fi
        after=$(images) || {
            restore_snapshot "$before" "$names" || true
            die 'renderer query failed; previous assignments restored'
        }
        if ! publish_wallpaper_only "$image" "$after" "$scheme" \
                "$source_mode" "$source_color"; then
            restore_snapshot "$before" "$names" || true
            die 'wallpaper publication failed; previous assignments restored'
        fi
        say "CURRENT=$image"
        say WALLPAPER=updated
        say COMMITTED=true
        ;;
    palette)
        image=$(canonical "$2") || die 'wallpaper does not exist'
        valid_image "$image" || die 'unsupported wallpaper format'
        scheme=$3
        token=$4
        source_mode=${5:-wallpaper}
        source_color=${6:-}
        request_is_current "$token" || die 'stale palette request'
        direct_candidate=$(mktemp -d "$runtime_root/.wallpaper-palette.XXXXXX")
        trap 'rm -rf "$direct_candidate"' EXIT
        if [[ $source_mode == color ]]; then
            say PALETTE=unchanged
            say COMMITTED=true
            exit 0
        fi
        if cached_palette "$image" "$scheme" \
                "$direct_candidate/palette.json"; then
            say CACHE=hit
        else
            say CACHE=miss
            "$palette_generator" image "$image" "$scheme" \
                "$direct_candidate/palette.json" >/dev/null
            store_cached_palette "$image" "$scheme" \
                "$direct_candidate/palette.json" || true
        fi
        chmod 600 "$direct_candidate/palette.json"
        request_is_current "$token" || die 'stale palette request'
        publish_palette_only "$direct_candidate" || die 'palette publication failed'
        trap - EXIT
        say PALETTE=updated
        say COMMITTED=true
        ;;
    apply)
        image=$(canonical "$2") || die 'wallpaper does not exist'
        valid_image "$image" || die 'unsupported wallpaper format'
        scheme=$3
        target=$4
        names=$5
        effect=$6
        seconds=$(clamp_duration "$7")
        reduced=${8:-false}
        token=${9:-}
        source_mode=${10:-wallpaper}
        source_color=${11:-}
        [[ $target == current || $target == all ]] || die 'invalid output target'
        candidate_matches "$image" "$scheme" "$token" "$source_mode" \
            "$source_color" || die 'stale candidate'
        start_renderer auto >/dev/null || die 'renderer unavailable'
        [[ -n $names ]] || die 'no live outputs'
        before=$(images) || die 'renderer query failed'
        requested_outputs_exist "$before" "$names" || die 'requested output unavailable'
        expected=$(jq -c --arg image "$image" --arg names "$names" '
            ($names | split(",") | map(select(length > 0))) as $wanted
            | [.[] | if (.name as $name | any($wanted[]; . == $name))
                then .image = $image else . end]
        ' <<<"$before")
        mapfile -d '' args < <(effect_args "$effect" "$seconds" "$reduced")
        if ! awww img --namespace "$namespace" --outputs "$names" \
                "${args[@]}" "$image"; then
            restore_snapshot "$before" "$names" || true
            die 'renderer apply failed; previous assignments restored'
        fi
        delay=${verify_delay:-$(awk -v d="$seconds" 'BEGIN { printf "%.1f", d + .2 }')}
        [[ $delay == 0 ]] || sleep "$delay"
        if ! verify_assignments "$(select_assignments "$expected" "$names")"; then
            restore_snapshot "$before" "$names" || true
            die 'renderer verification failed; previous assignments restored'
        fi
        after=$(images) || {
            restore_snapshot "$before" "$names" || true
            die 'renderer query failed; previous assignments restored'
        }
        if ! publish_commit "$image" "$after" "$scheme" "$source_mode" \
                "$source_color"; then
            restore_snapshot "$before" "$names" || true
            die 'palette publication failed; previous assignments restored'
        fi
        rm -rf "$candidate_dir"
        say "CURRENT=$image"
        say PALETTE=updated
        say COMMITTED=true
        ;;
    scheme)
        image=$(canonical "$2") || die 'wallpaper does not exist'
        scheme=$3
        token=$4
        source_mode=${5:-wallpaper}
        source_color=${6:-}
        candidate_matches "$image" "$scheme" "$token" "$source_mode" \
            "$source_color" || die 'stale candidate'
        start_renderer auto >/dev/null || die 'renderer unavailable'
        reconcile_manifest || die 'renderer reconciliation failed'
        assignments=$(images) || die 'renderer query failed'
        publish_commit "$image" "$assignments" "$scheme" "$source_mode" \
            "$source_color" \
            || die 'palette publication failed'
        rm -rf "$candidate_dir"
        say "CURRENT=$image"
        say PALETTE=updated
        say COMMITTED=true
        ;;
    reconcile)
        start_renderer auto >/dev/null || exit 1
        reconcile_manifest || die 'committed wallpaper reconciliation failed'
        say RECONCILED=true
        ;;
    *)
        printf 'usage: %s {list|probe|bootstrap|candidate|theme-source|cancel-candidate|render|palette|apply|scheme|reconcile}\n' \
            "$0" >&2
        exit 2
        ;;
esac
