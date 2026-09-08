#!/usr/bin/env bash
# Renders bindings in a receipt-owned public integration or the exact main
# configuration recorded by a guarded source-development receipt.
set -euo pipefail
command_name=${1:-}; requested_main=${2:-}
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
state_root=${XDG_STATE_HOME:-"${HOME:?HOME is required}/.local/state"}
receipt="$state_root/odyssey/startup/session-startup.json"
[[ -f $receipt ]] || { printf 'Odyssey host integration is unavailable\n' >&2; exit 1; }
receipt_kind='' integration='' target_file='' configuration_mode=preserve
if jq -e '.schema==3 and .adapter=="odyssey-startup" and (.main.path|type=="string") and (.integration.path|type=="string")' "$receipt" >/dev/null 2>&1; then
    receipt_kind=public
    main_file=$(jq -r .main.path "$receipt")
    integration=$(jq -r .integration.path "$receipt")
    configuration_mode=$(jq -r '.configurationMode // "managed"' "$receipt")
    target_file=$integration
elif jq -e '.version==1 and .phase=="active" and (.root|type=="string") and (.hyprlandFile|type=="string")' "$receipt" >/dev/null 2>&1; then
    receipt_kind=development
    main_file=$(jq -r .hyprlandFile "$receipt")
    development_root=$(jq -r .root "$receipt")
    canonical_root=$(cd -- "$development_root" 2>/dev/null && pwd -P) || canonical_root=
    [[ $canonical_root == "$project_dir" ]] || { printf 'Odyssey development receipt root is invalid\n' >&2; exit 1; }
    target_file=$main_file
else
    printf 'Odyssey host integration receipt is invalid\n' >&2
    exit 1
fi
[[ -z $requested_main || $requested_main == "$main_file" ]] || { printf 'Odyssey host main configuration does not match its receipt\n' >&2; exit 1; }
[[ -f $main_file && ! -L $main_file ]] || { printf 'Odyssey host main configuration is unavailable\n' >&2; exit 1; }
[[ -f $target_file && ! -L $target_file ]] || { printf 'Odyssey integration file is unavailable\n' >&2; exit 1; }
case $main_file in *.lua) format=lua;;*.conf) format=conf;;*) printf 'Unsupported Hyprland configuration\n' >&2; exit 1;;esac
marker=$([[ $format == lua ]] && printf '%s' '-- Managed by Odyssey host integration v3' || printf '%s' '# Managed by Odyssey host integration v3')
begin=$([[ $format == lua ]] && printf '%s' '-- BEGIN ODYSSEY MANAGED SHORTCUTS' || printf '%s' '# BEGIN ODYSSEY MANAGED SHORTCUTS')
end=$([[ $format == lua ]] && printf '%s' '-- END ODYSSEY MANAGED SHORTCUTS' || printf '%s' '# END ODYSSEY MANAGED SHORTCUTS')
[[ $receipt_kind == development ]] || grep -Fqx -- "$marker" "$integration" || { printf 'Odyssey integration is not owned\n' >&2; exit 1; }
reload() { command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null || true; }
block_state() {
    local begins ends
    begins=$(grep -Fxc -- "$begin" "$target_file" || true)
    ends=$(grep -Fxc -- "$end" "$target_file" || true)
    if [[ $begins == 0 && $ends == 0 ]]; then printf absent; return; fi
    if [[ $begins == 1 && $ends == 1 ]] && awk -v b="$begin" -v e="$end" '$0==b{if(seen||closed)exit 1;seen=1} $0==e{if(!seen||closed)exit 1;closed=1} END{exit !(seen&&closed)}' "$target_file"; then printf managed; else printf conflict; fi
}
managed() { [[ $(block_state) == managed ]]; }
valid() { [[ $1 == true || $1 == false ]]; }
[[ $(block_state) != conflict ]] || { printf 'Odyssey shortcut markers are ambiguous\n' >&2; exit 1; }
conflict() { local key=$1; [[ $format == lua ]] && awk -v b="$begin" -v e="$end" -v dynamic="hl.bind(mod .. \" + ${key}\"" -v literal="hl.bind(\"SUPER + ${key}\"" '$0==b{inside=1;next}$0==e{inside=0;next}!inside&&$0!~/^[[:space:]]*--/&&(index($0,dynamic)||index($0,literal)){found=1} END{exit found?0:1}' "$main_file" || grep -Eq "^[[:space:]]*bind[[:space:]]*=[[:space:]]*SUPER[[:space:]]*,[[:space:]]*${key// /[[:space:]]*}," "$main_file"; }
render() {
    local target=$1 tmp command="odyssey ipc"
    shift
    tmp=$(mktemp "${target_file}.odyssey.XXXXXX"); awk -v b="$begin" -v e="$end" '$0==b{inside=1;next}$0==e{inside=0;next}!inside{print}' "$target_file" > "$tmp"
    if [[ $target == true ]]; then
        printf '%s\n' "$begin" >> "$tmp"; local keys=(A V comma N Y space 'ALT + L' 'SHIFT + S' 'SHIFT + R') actions=('launcher toggle' 'clipboard toggle' 'settings open' 'notifications toggle' 'insights wallpaper' 'control-center toggle' 'session lock' 'capture screenshot region both' 'capture record region') labels=('Open application launcher' 'Open clipboard history' 'Open Odyssey settings' 'Open notifications' 'Open wallpaper library' 'Open Control Center' 'Lock session' 'Capture and save a region screenshot' 'Record a screen region') index=0 enabled
        for enabled in "$@"; do if [[ $enabled == true ]]; then [[ $format == lua ]] && printf 'hl.bind("SUPER + %s", hl.dsp.exec_cmd("%s %s"), { description = "%s" })\n' "${keys[$index]}" "$command" "${actions[$index]}" "${labels[$index]}" >> "$tmp" || printf 'bind = SUPER, %s, exec, %s %s\n' "${keys[$index]}" "$command" "${actions[$index]}" >> "$tmp"; fi; ((index+=1)); done
        if [[ $configuration_mode != managed && $format == lua ]]; then
            printf '%s\n' \
                'hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("odyssey ipc audio increment 3"), { locked = true, repeating = true, description = "Raise volume" })' \
                'hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("odyssey ipc audio decrement 3"), { locked = true, repeating = true, description = "Lower volume" })' \
                'hl.bind("XF86AudioMute", hl.dsp.exec_cmd("odyssey ipc audio mute"), { locked = true, description = "Toggle audio mute" })' \
                'hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("odyssey ipc audio micmute"), { locked = true, description = "Toggle microphone mute" })' >> "$tmp"
        elif [[ $configuration_mode != managed ]]; then
            printf '%s\n' \
                'bindel = , XF86AudioRaiseVolume, exec, odyssey ipc audio increment 3' \
                'bindel = , XF86AudioLowerVolume, exec, odyssey ipc audio decrement 3' \
                'bindl = , XF86AudioMute, exec, odyssey ipc audio mute' \
                'bindl = , XF86AudioMicMute, exec, odyssey ipc audio micmute' >> "$tmp"
        fi
        printf '%s\n' "$end" >> "$tmp"
    fi
    if ! cmp -s -- "$tmp" "$target_file"; then
        chmod --reference="$target_file" "$tmp"; mv -f -- "$tmp" "$target_file"
        if [[ $receipt_kind == public ]]; then
            receipt_tmp=$(mktemp "$(dirname -- "$receipt")/.shortcut-receipt.XXXXXX")
            jq --arg digest "$(sha256sum -- "$target_file" | awk '{print $1}')" '.integration.sha256=$digest' "$receipt" > "$receipt_tmp"
            chmod 600 "$receipt_tmp"; mv -f -- "$receipt_tmp" "$receipt"
        fi
    else rm -f -- "$tmp"; fi
    reload
}
case $command_name in
 status) managed && printf 'MANAGED=true\n' || printf 'MANAGED=false\n' ;;
 apply) shift 2; (($#==9)) || { printf 'Expected nine shortcut toggles\n' >&2; exit 2; }; for value in "$@"; do valid "$value" || { printf 'Invalid shortcut toggle\n' >&2; exit 2; }; done; keys=(A V comma N Y space 'ALT + L' 'SHIFT + S' 'SHIFT + R'); index=0; for value in "$@"; do [[ $value != true ]] || ! conflict "${keys[$index]}" || { printf 'Shortcut conflict: SUPER + %s is already in use\n' "${keys[$index]}" >&2; exit 1; }; ((index+=1)); done; render true "$@"; printf 'MANAGED=true\n' ;;
 remove) render false; printf 'MANAGED=false\n' ;;
 *) printf 'usage: %s {status|apply|remove} MAIN_CONFIG [TOGGLES...]\n' "$0" >&2; exit 2;;
esac
