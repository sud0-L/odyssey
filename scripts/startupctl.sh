#!/usr/bin/env bash
# Public Odyssey host-integration boundary: one service, one owned integration,
# and one exact include in a documented Hyprland main configuration.
set -euo pipefail

config_root=${XDG_CONFIG_HOME:-"${HOME:?HOME is required}/.config"}
state_root=${XDG_STATE_HOME:-"${HOME:?HOME is required}/.local/state"}
data_root=${XDG_DATA_HOME:-"${HOME:?HOME is required}/.local/share"}
state_dir="$state_root/odyssey/startup"; receipt_file="$state_dir/session-startup.json"
pending_file="$state_dir/pending.json"; backup_dir="$state_dir/backups"
unit_file="$config_root/systemd/user/odyssey.service"
unit_marker='# Managed by Odyssey host integration v3'
split_files=(animations.lua appearance.lua environment.lua input.lua keybinds.lua layouts.lua monitors.lua startup.lua window-rules.lua)

sha() { sha256sum -- "$1" | awk '{print $1}'; }
mode() { stat -c '%a' -- "$1"; }
compact() { jq -cS .; }
emit() { jq -cn "$@" | compact; }
error() { local cmd=$1 code=$2 message=$3 status=${4:-error}; emit --arg command "$cmd" --arg status "$status" --arg code "$code" --arg message "$message" '{adapter:"odyssey-startup",adapterVersion:3,command:$command,error:{code:$code,message:$message},schema:3,status:$status}'; }
systemd_ok() { command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; }
enabled() { systemctl --user is-enabled odyssey.service >/dev/null 2>&1; }
active() { systemctl --user is-active odyssey.service >/dev/null 2>&1; }
managed_unit() { [[ -f $unit_file && ! -L $unit_file ]] && grep -Fqx -- "$unit_marker" "$unit_file"; }
split_directory() { printf '%s/config' "$(dirname -- "$1")"; }
split_sources_valid() { local root=$1 file; for file in "${split_files[@]}"; do [[ -f $root/config/hypr/$file && ! -L $root/config/hypr/$file ]] || return 1; done; }
copy_split_files() {
    local root=$1 main=$2 destination file source tmp
    destination=$(split_directory "$main"); split_sources_valid "$root" || return 1
    mkdir -p -- "$destination"
    for file in "${split_files[@]}"; do
        source="$root/config/hypr/$file"; tmp=$(mktemp "$destination/.${file}.XXXXXX")
        cat -- "$source" > "$tmp"; chmod 600 "$tmp"; mv -f -- "$tmp" "$destination/$file"
    done
}
backup_split_files() {
    local id=$1 main=$2 destination file
    destination=$(split_directory "$main"); mkdir -p -- "$backup_dir/$id/config"
    for file in "${split_files[@]}"; do
        [[ -f $destination/$file && ! -L $destination/$file ]] && cp -p -- "$destination/$file" "$backup_dir/$id/config/$file"
    done
    return 0
}
split_matches_receipt() {
    local receipt=$1 main=$2 destination file expected
    jq -e '.splitConfig.files | type == "array"' "$receipt" >/dev/null 2>&1 || return 0
    [[ $(jq '.splitConfig.files | length' "$receipt") == 0 ]] && return 0
    destination=$(split_directory "$main")
    for file in "${split_files[@]}"; do
        expected=$(jq -r --arg name "$file" '.splitConfig.files[] | select(.name==$name) | .afterSha256 // empty' "$receipt")
        [[ -n $expected && -f $destination/$file && ! -L $destination/$file && $(sha "$destination/$file") == "$expected" ]] || return 1
    done
}
split_snapshots() {
    local main=$1 destination file result='[]'
    destination=$(split_directory "$main")
    for file in "${split_files[@]}"; do result=$(jq -cn --argjson records "$result" --arg name "$file" --argjson snapshot "$(snapshot "$destination/$file")" '$records + [{name:$name,snapshot:$snapshot}]'); done
    printf '%s\n' "$result"
}
restore_split_snapshots() {
    local records=$1 main=$2 destination file
    destination=$(split_directory "$main")
    jq -c '.[]' <<<"$records" | while IFS= read -r file; do restore "$(jq -c .snapshot <<<"$file")" "$destination/$(jq -r .name <<<"$file")"; done
    rmdir --ignore-fail-on-non-empty "$destination" 2>/dev/null || true
}
split_backups_valid() {
    local receipt=$1 file backup expected absent
    jq -e '.splitConfig.files | type == "array"' "$receipt" >/dev/null 2>&1 || return 0
    [[ $(jq '.splitConfig.files | length' "$receipt") == 0 ]] && return 0
    for file in "${split_files[@]}"; do
        absent=$(jq -r --arg name "$file" '.splitConfig.files[] | select(.name==$name) | .previouslyAbsent' "$receipt")
        [[ $absent == true ]] && continue
        backup=$(jq -r --arg name "$file" '.splitConfig.files[] | select(.name==$name) | .backup' "$receipt")
        expected=$(jq -r --arg name "$file" '.splitConfig.files[] | select(.name==$name) | .backupSha256 // empty' "$receipt")
        [[ -f $backup && -n $expected && $(sha "$backup") == "$expected" ]] || return 1
    done
}
restore_split_receipt() {
    local receipt=$1 main=$2 destination file absent backup
    jq -e '.splitConfig.files | type == "array"' "$receipt" >/dev/null 2>&1 || return 0
    [[ $(jq '.splitConfig.files | length' "$receipt") == 0 ]] && return 0
    destination=$(split_directory "$main")
    for file in "${split_files[@]}"; do
        absent=$(jq -r --arg name "$file" '.splitConfig.files[] | select(.name==$name) | .previouslyAbsent' "$receipt")
        if [[ $absent == true ]]; then rm -f -- "$destination/$file"; else backup=$(jq -r --arg name "$file" '.splitConfig.files[] | select(.name==$name) | .backup' "$receipt"); mkdir -p -- "$destination"; cp -p -- "$backup" "$destination/$file"; fi
    done
    rmdir --ignore-fail-on-non-empty "$destination" 2>/dev/null || true
}

active_hyprland_config() {
    local signature=${HYPRLAND_INSTANCE_SIGNATURE:-} instances pid info selected='' cwd index
    local -a arguments=()
    [[ -n $signature ]] || return 1
    command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 1
    instances=$(hyprctl instances -j 2>/dev/null) || return 1
    pid=$(jq -er --arg signature "$signature" \
        '[.[] | select(.instance==$signature) | .pid] | if length==1 then .[0] else empty end' \
        <<<"$instances") || return 1
    [[ $pid =~ ^[0-9]+$ && -r /proc/$pid/cmdline &&
       $(stat -c '%u' "/proc/$pid") == "$EUID" ]] || return 1
    mapfile -d '' -t arguments < "/proc/$pid/cmdline" || true
    for ((index=0; index<${#arguments[@]}; index++)); do
        case ${arguments[$index]} in
          --config|-c)
            ((index+1 < ${#arguments[@]})) || return 1
            selected=${arguments[$((index+1))]}
            break
            ;;
          --config=*) selected=${arguments[$index]#--config=}; break ;;
        esac
    done
    if [[ -n $selected ]]; then
        if [[ $selected != /* ]]; then
            cwd=$(readlink -f -- "/proc/$pid/cwd") || return 1
            selected="$cwd/$selected"
        fi
        readlink -m -- "$selected"
        return
    fi
    info=$(hyprctl systeminfo 2>/dev/null) || return 1
    grep -Eq '^[[:space:]]*configProvider:[[:space:]]*lua[[:space:]]*$' \
        <<<"$info" || return 1
    printf '%s\n' "$config_root/hypr/hyprland.lua"
}
host() {
    local configuration_mode=${1:-managed} selected
    if [[ -n ${ODYSSEY_HYPRLAND_CONFIG:-} ]]; then
        selected=$ODYSSEY_HYPRLAND_CONFIG
    elif [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        selected=$(active_hyprland_config) || return 1
    elif [[ -f $receipt_file ]] && jq -e \
            '.schema==3 and .adapter=="odyssey-startup" and (.main.path|type=="string")' \
            "$receipt_file" >/dev/null 2>&1; then
        selected=$(jq -r .main.path "$receipt_file")
    elif [[ $configuration_mode == managed ]]; then
        selected="$config_root/hypr/hyprland.lua"
    else
        return 1
    fi
    [[ $selected == /* && $selected == *.lua && ! -L $selected ]] || return 1
    [[ ! -e $selected || -f $selected ]] || return 1
    printf 'lua\t%s\t%s\n' "$selected" "$(dirname -- "$selected")/odyssey.lua"
}
include() { [[ $1 == lua ]] && printf 'require("odyssey")' || printf 'source = %s' "$2"; }
marker() { [[ $1 == lua ]] && printf '%s' '-- Managed by Odyssey host integration v3' || printf '%s' '# Managed by Odyssey host integration v3'; }
count_include() { grep -Fxc -- "$2" "$1" 2>/dev/null || true; }
managed_integration() { [[ -f $2 && ! -L $2 ]] && grep -Fqx -- "$(marker "$1")" "$2"; }
valid_configuration_mode() { [[ $1 == managed || $1 == preserve ]]; }
legacy_receipt() {
    local main=$1 root
    [[ -f $receipt_file && ! -L $receipt_file ]] || return 1
    jq -e --arg main "$main" '.version==1 and .phase=="active" and
        .hyprlandFile==$main and (.root|type=="string")' "$receipt_file" \
        >/dev/null 2>&1 || return 1
    root=$(jq -r .root "$receipt_file")
    [[ $root == /* && -d $root && ! -L $root &&
       -x $root/scripts/odyssey-session.sh ]]
}

release() {
    local id=$1 root=$2 expected canonical
    [[ $id =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ && $root == /* ]] || return 1
    canonical=$(cd -- "$root" 2>/dev/null && pwd -P) || return 1
    expected="$data_root/odyssey/releases/$id"; expected=$(cd -- "$(dirname -- "$expected")" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$id") || return 1
    [[ $canonical == "$expected" && -f $canonical/shell.qml && -x $canonical/scripts/odyssey-session.sh && -f $canonical/release.json ]] || return 1
    jq -e --arg id "$id" '(.releaseId // .id) == $id' "$canonical/release.json" >/dev/null 2>&1 || return 1
    printf '%s\n' "$canonical"
}
render_unit() {
    local root=$1 tmp; mkdir -p -- "$(dirname -- "$unit_file")"; tmp=$(mktemp "$(dirname -- "$unit_file")/.odyssey.service.XXXXXX")
    [[ -x $root/scripts/odyssey-session.sh ]] || return 1
    printf '%s\n' "$unit_marker" '[Unit]' 'Description=Odyssey Quickshell session' 'After=graphical-session.target' 'PartOf=graphical-session.target' 'StartLimitIntervalSec=60' 'StartLimitBurst=3' '' '[Service]' 'Type=simple' 'ExecStart=/bin/sh -c '\''current="$${XDG_DATA_HOME:-$${HOME}/.local/share}/odyssey/current"; release="$$(readlink -f "$$current")"; exec "$$release/scripts/odyssey-session.sh" --root "$$release"'\''' 'Restart=on-failure' 'RestartSec=3' '' '[Install]' 'WantedBy=graphical-session.target' > "$tmp"
    chmod 600 "$tmp"; printf '%s\n' "$tmp"
}
render_integration() {
    local format=$1 file=$2 tmp
    tmp=$(mktemp "${file}.odyssey.XXXXXX")
    if [[ $format == lua ]]; then
        printf '%s\n' "$(marker lua)" \
            'hl.on("hyprland.start", function()' \
            '    hl.exec_cmd("systemctl --user start odyssey.service")' \
            '    hl.exec_cmd("bash -c \"pgrep -u $USER -x wl-paste >/dev/null || wl-paste --watch cliphist store &\"")' \
            'end)' > "$tmp"
    else
        printf '%s\n' "$(marker conf)" 'exec-once = systemctl --user start odyssey.service' > "$tmp"
    fi
    chmod 600 "$tmp"; mv -f -- "$tmp" "$file"
}
identity() { [[ -f $1 && ! -L $1 ]] && jq -cn --arg path "$1" --arg sha "$(sha "$1")" --argjson mode "$(mode "$1")" '{status:"present",path:$path,sha256:$sha,mode:$mode}' || jq -cn --arg path "$1" '{status:"absent",path:$path}'; }
receipt_summary() {
    [[ -f $receipt_file ]] || { printf 'null\n'; return; }
    jq -e '.schema==3 and .adapter=="odyssey-startup" and .adapterVersion==3 and (.receiptId|type=="string")' "$receipt_file" >/dev/null 2>&1 && jq -c '{status:"valid",receiptId,generation,configurationMode:(.configurationMode // "managed")}' "$receipt_file" || jq -cn '{status:"legacy-or-invalid",receiptId:null,generation:null,configurationMode:null}'
}
observed() {
    local config format main integration e=false a=false; config=$(host) || { jq -cn --argjson receipt "$(receipt_summary)" '{receipt:$receipt,host:{status:"unsupported-or-ambiguous"}}'; return; }; IFS=$'\t' read -r format main integration <<<"$config"
    enabled && e=true; active && a=true
    jq -cn --arg format "$format" --arg include "$(include "$format" "$integration")" --argjson receipt "$(receipt_summary)" --argjson main "$(identity "$main")" --argjson integration "$(identity "$integration")" --argjson unit "$(identity "$unit_file")" --argjson enabled "$e" --argjson active "$a" '{receipt:$receipt,host:{format:$format,include:$include,main:$main,integration:$integration},unit:$unit,odyssey:{enabled:$enabled,active:$active}}'
}
state() {
    local rec config format main integration line; systemd_ok || { printf unsupported; return; }; [[ ! -f $pending_file ]] || { printf partial; return; }
    rec=$(receipt_summary); [[ $(jq -r '.status // ""' <<<"$rec") != legacy-or-invalid ]] || { printf conflict; return; }
    config=$(host) || { printf conflict; return; }; IFS=$'\t' read -r format main integration <<<"$config"; line=$(include "$format" "$integration")
    if [[ $(jq -r '.status // ""' <<<"$rec") == valid ]]; then
        jq -e --arg main "$main" --arg mainsha "$(sha "$main")" --arg integration "$integration" --arg integrationsha "$(sha "$integration")" --arg unitsha "$(sha "$unit_file")" '.main.path==$main and .main.afterSha256==$mainsha and .integration.path==$integration and .integration.sha256==$integrationsha and .unit.sha256==$unitsha' "$receipt_file" >/dev/null 2>&1 && managed_unit && managed_integration "$format" "$integration" && [[ $(count_include "$main" "$line") == 1 ]] && split_matches_receipt "$receipt_file" "$main" || { printf conflict; return; }
        active && printf active || printf configured
    elif [[ -f $unit_file || -f $integration || $(count_include "$main" "$line") != 0 ]]; then printf partial; else printf unmanaged; fi
}
write_json() { local path=$1 content=$2 dir tmp; dir=$(dirname -- "$path"); mkdir -p -- "$dir"; chmod 700 "$state_dir"; tmp=$(mktemp "$dir/.tmp.XXXXXX"); printf '%s\n' "$content" > "$tmp"; chmod 600 "$tmp"; mv -f -- "$tmp" "$path"; }
status_json() { local rec state_now release_json=null; rec=$(receipt_summary); state_now=$(state); [[ $(jq -r '.status // ""' <<<"$rec") == valid ]] && release_json=$(jq -c '{id:.release.id,root:.release.root}' "$receipt_file"); emit --arg state "$state_now" --argjson receipt "$rec" --argjson release "$release_json" '{adapter:"odyssey-startup",adapterVersion:3,command:"status",error:null,receipt:$receipt,release:$release,schema:3,state:$state,status:"ok"}'; }
preservable_main() {
    local target=$1 begin='-- BEGIN ODYSSEY MANAGED SHORTCUTS' end='-- END ODYSSEY MANAGED SHORTCUTS'
    local begins ends include_count
    [[ ! -f $target ]] && return 0
    begins=$(grep -Fxc -- "$begin" "$target" || true)
    ends=$(grep -Fxc -- "$end" "$target" || true)
    [[ $begins == 0 && $ends == 0 || $begins == 1 && $ends == 1 ]] || return 1
    if [[ $begins == 1 ]]; then
        awk -v b="$begin" -v e="$end" '$0==b{if(seen||closed)exit 1;seen=1}
            $0==e{if(!seen||closed)exit 1;closed=1} END{exit !(seen&&closed)}' \
            "$target" >/dev/null || return 1
    fi
    include_count=$(count_include "$target" 'require("odyssey")')
    ((include_count <= 1))
}
render_main() {
    local root=$1 integration=$2 target=$3 configuration_mode=$4 tmp source
    source="$root/config/hypr/hyprland.lua"
    [[ -f $source && ! -L $source ]] || return 1
    [[ $configuration_mode != preserve ]] || preservable_main "$target" || return 1
    mkdir -p -- "$(dirname -- "$target")"
    tmp=$(mktemp "$(dirname -- "$target")/.hyprland.lua.XXXXXX")
    if [[ $configuration_mode == managed ]]; then
        cat -- "$source" > "$tmp"
    elif [[ -f $target ]]; then
        local begin='-- BEGIN ODYSSEY MANAGED SHORTCUTS' end='-- END ODYSSEY MANAGED SHORTCUTS'
        awk -v b="$begin" -v e="$end" -v legacy="$(legacy_receipt "$target" && printf true || printf false)" \
            '$0==b{inside=1;next}$0==e{inside=0;next}
             !inside && !(legacy=="true" && $0 ~ /^[[:space:]]*hl\.exec_cmd\("systemctl --user start odyssey\.service"\)[[:space:]]*$/){print}' \
            "$target" > "$tmp"
    else
        : > "$tmp"
    fi
    [[ $(tail -c1 "$tmp" | wc -l) == 1 ]] || printf '\n' >> "$tmp"
    local include_count
    include_count=$(count_include "$tmp" 'require("odyssey")')
    ((include_count <= 1)) || return 1
    ((include_count == 1)) || printf 'require("odyssey")\n' >> "$tmp"
    chmod 600 "$tmp"; mv -f -- "$tmp" "$target"
}
plan() {
    local action=$1 id=${2:-} root=${3:-} requested_mode=${4:-} configuration_mode canonical release_json=null config format main integration line base pid
    systemd_ok || { error plan UNSUPPORTED 'user systemd is unavailable' unsupported; return 69; }
    case $action in apply|retarget) canonical=$(release "$id" "$root") || { error plan INVALID_RELEASE 'release is not a canonical installed root' refused; return 64; }; release_json=$(jq -cn --arg id "$id" --arg root "$canonical" '{id:$id,root:$root}');; remove) ;; *) error plan INVALID_REQUEST 'unsupported plan action' refused; return 64;; esac
    if [[ -n $requested_mode ]]; then configuration_mode=$requested_mode
    elif jq -e '.schema==3 and .adapter=="odyssey-startup"' "$receipt_file" >/dev/null 2>&1; then
        configuration_mode=$(jq -r '.configurationMode // "managed"' "$receipt_file")
    else configuration_mode=managed; fi
    valid_configuration_mode "$configuration_mode" || { error plan INVALID_REQUEST 'configuration mode must be managed or preserve' refused; return 64; }
    [[ ! -f $pending_file ]] || { error plan PENDING_OPERATION 'explicit compensation is required' refused; return 73; }; config=$(host "$configuration_mode") || { error plan UNSUPPORTED_HOST 'active Hyprland Lua configuration could not be resolved safely; set ODYSSEY_HYPRLAND_CONFIG explicitly' refused; return 73; }; IFS=$'\t' read -r format main integration <<<"$config"; line=$(include "$format" "$integration")
    case $action in
      apply) [[ $(jq -r '.status // ""' <<<"$(receipt_summary)") != legacy-or-invalid ]] || { [[ $configuration_mode == preserve ]] && legacy_receipt "$main" || { error plan CONFLICT 'invalid startup receipt requires manual review' refused; return 73; }; };;
      retarget) [[ $(jq -r '.status // ""' <<<"$(receipt_summary)") == valid ]] || { error plan CONFLICT 'retarget requires a valid public receipt' refused; return 73; };;
      remove) [[ $(jq -r '.status // ""' <<<"$(receipt_summary)") == valid ]] || { [[ $(state) == unmanaged ]] && { emit --argjson observed "$(observed)" '{adapter:"odyssey-startup",adapterVersion:3,command:"plan",error:null,plan:null,schema:3,status:"ready"}'; return; }; error plan CONFLICT 'remove requires a valid public receipt' refused; return 73; };;
    esac
    if [[ $action != remove && $configuration_mode == preserve ]] && ! preservable_main "$main"; then
        error plan CONFLICT 'personal Hyprland configuration has ambiguous Odyssey markers or includes' refused
        return 73
    fi
    base=$(jq -cn --arg action "$action" --arg mode "$configuration_mode" --argjson release "$release_json" --argjson observed "$(observed)" '{schema:3,adapter:"odyssey-startup",adapterVersion:3,kind:"plan",action:$action,configurationMode:$mode,release:$release,observed:$observed}'); pid=$(printf '%s' "$base" | compact | sha256sum | awk '{print $1}'); emit --argjson plan "$(jq -cn --argjson p "$base" --arg id "$pid" '$p+{planId:$id}' | compact)" '{adapter:"odyssey-startup",adapterVersion:3,command:"plan",error:null,plan:$plan,schema:3,status:"ready"}'
}
validate_plan_identity() {
    local action=$1 file=$2 id=$3 expected actual; [[ $file == /* && -f $file ]] || return 64; jq -e --arg action "$action" --arg id "$id" '.schema==3 and .adapter=="odyssey-startup" and .adapterVersion==3 and .kind=="plan" and .action==$action and .planId==$id' "$file" >/dev/null || return 64
    expected=$(jq -cS 'del(.planId)' "$file"); actual=$(printf '%s\n' "$expected" | sha256sum | awk '{print $1}'); [[ $actual == "$id" ]] || return 64; [[ $action == remove ]] || release "$(jq -r .release.id "$file")" "$(jq -r .release.root "$file")" >/dev/null || return 73
}
validate_plan() {
    local action=$1 file=$2 id=$3
    validate_plan_identity "$action" "$file" "$id" || return $?
    jq -e --argjson now "$(observed)" '.observed==$now' "$file" >/dev/null || return 73
}
snapshot() { [[ -f $1 && ! -L $1 ]] && jq -cn --arg content "$(base64 -w0 "$1")" --argjson mode "$(mode "$1")" '{content:$content,mode:$mode}' || printf 'null\n'; }
restore() { local obj=$1 destination=$2; if jq -e '.!=null' <<<"$obj" >/dev/null; then mkdir -p -- "$(dirname -- "$destination")"; jq -r .content <<<"$obj" | base64 -d > "$destination"; chmod "$(jq -r .mode <<<"$obj")" "$destination"; else rm -f -- "$destination"; fi; }
pending() { local action=$1 id=$2 config format main integration e=false a=false; config=$(host); IFS=$'\t' read -r format main integration <<<"$config"; enabled && e=true; active && a=true; jq -cn --arg action "$action" --arg id "$id" --argjson unit "$(snapshot "$unit_file")" --argjson main "$(snapshot "$main")" --argjson integration "$(snapshot "$integration")" --argjson split "$(split_snapshots "$main")" --argjson receipt "$(snapshot "$receipt_file")" --argjson enabled "$e" --argjson active "$a" '{action:$action,planId:$id,unit:$unit,main:$main,integration:$integration,split:$split,receipt:$receipt,odyssey:{enabled:$enabled,active:$active}}'; }
result() { local cmd=$1 status=$2 now=$3 id=$4; emit --arg command "$cmd" --arg status "$status" --arg state "$now" --arg plan "$id" --argjson receipt "$(receipt_summary)" '{adapter:"odyssey-startup",adapterVersion:3,command:$command,error:null,planId:$plan,receipt:$receipt,schema:3,state:$state,status:$status}'; }
compensate() {
    local plan_file=$1 id=$2 action data config format main integration; [[ -f $pending_file ]] || { result compensate unchanged "$(state)" "$id"; return 0; }; action=$(jq -r .action "$pending_file"); [[ $(jq -r .planId "$pending_file") == "$id" ]] && validate_plan_identity "$action" "$plan_file" "$id" >/dev/null 2>&1 || { error compensate STALE_PLAN 'pending capsule does not match exact plan' refused; return 73; }; data=$(cat "$pending_file"); config=$(host); IFS=$'\t' read -r format main integration <<<"$config"
    restore "$(jq -c .unit <<<"$data")" "$unit_file"; restore "$(jq -c .main <<<"$data")" "$main"; restore "$(jq -c .integration <<<"$data")" "$integration"; restore_split_snapshots "$(jq -c .split <<<"$data")" "$main"; restore "$(jq -c .receipt <<<"$data")" "$receipt_file"; systemctl --user daemon-reload || { error compensate COMPENSATION_FAILED 'daemon reload failed'; return 75; }; jq -e '.odyssey.enabled==true' <<<"$data" >/dev/null && systemctl --user enable odyssey.service || systemctl --user disable odyssey.service || true; jq -e '.odyssey.active==true' <<<"$data" >/dev/null && systemctl --user start odyssey.service || systemctl --user stop odyssey.service || true; rm -f -- "$pending_file"; result compensate compensated "$(state)" "$id"; return 1
}
split_receipt_records() {
    local plan_file=$1 generation=$2 main=$3 plan_id old destination file records='[]' backup absent after
    plan_id=$(jq -r .planId "$plan_file"); destination=$(split_directory "$main")
    for file in "${split_files[@]}"; do
        old=$(jq -c --arg name "$file" '.splitConfig.files[]? | select(.name==$name)' "$receipt_file" 2>/dev/null || true)
        if ((generation > 1)) && [[ -n $old ]]; then
            backup=$(jq -r .backup <<<"$old"); absent=$(jq -r .previouslyAbsent <<<"$old")
        else
            backup="$backup_dir/$plan_id/config/$file"; [[ -f $backup ]] && absent=false || { backup=""; absent=true; }
        fi
        after=$(sha "$destination/$file")
        if [[ $absent == false ]]; then backup_sha=$(sha "$backup"); else backup_sha=""; fi
        records=$(jq -cn --argjson prior "$records" --arg name "$file" --arg path "$destination/$file" --arg after "$after" --arg backup "$backup" --arg backupsha "$backup_sha" --argjson absent "$absent" '$prior + [{name:$name,path:$path,afterSha256:$after,backup:$backup,backupSha256:$backupsha,previouslyAbsent:$absent}]')
    done
    jq -cn --arg path "$destination" --argjson files "$records" '{path:$path,files:$files}'
}
write_receipt() {
    local plan_file=$1 generation=$2 backup=$3 absent=$4 config format main integration raw rid backupsha="" plan_id
    local integration_absent=true integration_backup="" integration_backup_sha=""
    local unit_absent=true unit_backup="" unit_backup_sha=""
    local previous_receipt_absent=true previous_receipt_backup="" previous_receipt_sha=""
    local configuration_mode split
    config=$(host); IFS=$'\t' read -r format main integration <<<"$config"; plan_id=$(jq -r .planId "$plan_file")
    configuration_mode=$(jq -r .configurationMode "$plan_file")
    [[ $absent == true ]] || backupsha=$(sha "$backup")
    if ((generation > 1)) && [[ -f $receipt_file ]]; then
        integration_absent=$(jq -r '.integration.previouslyAbsent' "$receipt_file"); integration_backup=$(jq -r '.integration.backup // ""' "$receipt_file"); integration_backup_sha=$(jq -r '.integration.backupSha256 // ""' "$receipt_file")
        unit_absent=$(jq -r '.unit.previouslyAbsent' "$receipt_file"); unit_backup=$(jq -r '.unit.backup // ""' "$receipt_file"); unit_backup_sha=$(jq -r '.unit.backupSha256 // ""' "$receipt_file")
        previous_receipt_absent=$(jq -r 'if .previousReceipt then .previousReceipt.previouslyAbsent else true end' "$receipt_file"); previous_receipt_backup=$(jq -r '.previousReceipt.backup // ""' "$receipt_file"); previous_receipt_sha=$(jq -r '.previousReceipt.backupSha256 // ""' "$receipt_file")
    else
        if [[ $(jq -r '.observed.host.integration.status // "absent"' "$plan_file") == present ]]; then integration_absent=false; integration_backup="$backup_dir/$plan_id/integration.before"; integration_backup_sha=$(sha "$integration_backup"); fi
        if [[ $(jq -r '.observed.unit.status // "absent"' "$plan_file") == present ]]; then unit_absent=false; unit_backup="$backup_dir/$plan_id/odyssey.service.before"; unit_backup_sha=$(sha "$unit_backup"); fi
        if [[ -f $backup_dir/$plan_id/session-startup.before ]]; then previous_receipt_absent=false; previous_receipt_backup="$backup_dir/$plan_id/session-startup.before"; previous_receipt_sha=$(sha "$previous_receipt_backup"); fi
    fi
    if [[ $configuration_mode == managed ]]; then split=$(split_receipt_records "$plan_file" "$generation" "$main"); else split=$(jq -cn --arg path "$(split_directory "$main")" '{path:$path,files:[]}'); fi
    raw=$(jq -cn --argjson release "$(jq -c .release "$plan_file")" --arg configurationMode "$configuration_mode" --arg format "$format" --arg main "$main" --arg before "$(jq -r '.observed.host.main.sha256 // ""' "$plan_file")" --arg after "$(sha "$main")" --arg include "$(include "$format" "$integration")" --arg backup "$backup" --arg backupsha "$backupsha" --argjson absent "$absent" --arg integration "$integration" --arg integrationsha "$(sha "$integration")" --argjson integrationmode "$(mode "$integration")" --argjson integrationabsent "$integration_absent" --arg integrationbackup "$integration_backup" --arg integrationbackupsha "$integration_backup_sha" --arg unit "$unit_file" --arg unitsha "$(sha "$unit_file")" --argjson unitmode "$(mode "$unit_file")" --argjson unitabsent "$unit_absent" --arg unitbackup "$unit_backup" --arg unitbackupsha "$unit_backup_sha" --argjson split "$split" --argjson previousreceiptabsent "$previous_receipt_absent" --arg previousreceiptbackup "$previous_receipt_backup" --arg previousreceiptsha "$previous_receipt_sha" --argjson generation "$generation" '{schema:3,adapter:"odyssey-startup",adapterVersion:3,generation:$generation,configurationMode:$configurationMode,release:$release,main:{path:$main,beforeSha256:$before,afterSha256:$after,include:$include,backup:$backup,backupSha256:$backupsha,previouslyAbsent:$absent},splitConfig:$split,integration:{path:$integration,sha256:$integrationsha,mode:$integrationmode,previouslyAbsent:$integrationabsent,backup:$integrationbackup,backupSha256:$integrationbackupsha},unit:{path:$unit,sha256:$unitsha,mode:$unitmode,previouslyAbsent:$unitabsent,backup:$unitbackup,backupSha256:$unitbackupsha},previousReceipt:{previouslyAbsent:$previousreceiptabsent,backup:$previousreceiptbackup,backupSha256:$previousreceiptsha}}')
    rid=$(printf '%s' "$raw" | compact | sha256sum | awk '{print $1}'); write_json "$receipt_file" "$(jq -cn --argjson r "$raw" --arg id "$rid" '$r+{receiptId:$id}')"
}
mutate() {
    local action=$1 plan_file=$2 id=$3 rc config format main integration root backup generation=1 absent=false run_backup previous
    validate_plan "$action" "$plan_file" "$id"; rc=$?; [[ $rc == 0 ]] || { error "$action" "$([[ $rc == 73 ]] && echo STALE_PLAN || echo INVALID_PLAN)" 'plan validation failed' refused; return "$rc"; }; [[ $action != remove || $(state) != unmanaged ]] || { result remove unchanged unmanaged "$id"; return; }
    write_json "$pending_file" "$(pending "$action" "$id")"; config=$(host); IFS=$'\t' read -r format main integration <<<"$config"; root=$(jq -r '.release.root // ""' "$plan_file")
    if [[ $action == apply ]]; then
      mkdir -p -- "$backup_dir/$id"; backup="$backup_dir/$id/main-config"; if [[ -f $main ]]; then cp -p -- "$main" "$backup"; chmod 600 "$backup"; else absent=true; fi; [[ $(jq -r .configurationMode "$plan_file") != managed ]] || backup_split_files "$id" "$main"; [[ ! -e $integration ]] || cp -a -- "$integration" "$backup_dir/$id/integration.before"; [[ ! -e $unit_file ]] || cp -a -- "$unit_file" "$backup_dir/$id/odyssey.service.before"; [[ ! -e $receipt_file ]] || cp -p -- "$receipt_file" "$backup_dir/$id/session-startup.before"; render_main "$root" "$integration" "$main" "$(jq -r .configurationMode "$plan_file")"; [[ $(jq -r .configurationMode "$plan_file") != managed ]] || copy_split_files "$root" "$main"; render_integration "$format" "$integration"; render_unit "$root" | xargs -r -I{} mv -f {} "$unit_file"; systemctl --user daemon-reload && systemctl --user enable odyssey.service && systemctl --user restart odyssey.service || { compensate "$plan_file" "$id" || true; return 1; }; write_receipt "$plan_file" 1 "$backup" "$absent"
    elif [[ $action == retarget ]]; then
      generation=$(($(jq -r .generation "$receipt_file")+1)); mkdir -p -- "$backup_dir/$id"; if [[ $(jq -r .main.path "$receipt_file") == "$main" ]]; then backup=$(jq -r .main.backup "$receipt_file"); absent=$(jq -r '.main.previouslyAbsent // false' "$receipt_file"); else cp -p -- "$receipt_file" "$backup_dir/$id/previous-startup-receipt.json"; backup="$backup_dir/$id/main-config"; if [[ -f $main ]]; then cp -p -- "$main" "$backup"; chmod 600 "$backup"; else absent=true; fi; fi; [[ $(jq -r .configurationMode "$plan_file") != managed ]] || backup_split_files "$id" "$main"; run_backup="$backup_dir/$id/main-config.before-reapply"; [[ ! -f $main ]] || { cp -p -- "$main" "$run_backup"; chmod 600 "$run_backup"; }; [[ ! -e $integration ]] || cp -a -- "$integration" "$backup_dir/$id/integration.before"; [[ ! -e $unit_file ]] || cp -a -- "$unit_file" "$backup_dir/$id/odyssey.service.before"; render_main "$root" "$integration" "$main" "$(jq -r .configurationMode "$plan_file")"; [[ $(jq -r .configurationMode "$plan_file") != managed ]] || copy_split_files "$root" "$main"; render_integration "$format" "$integration"; render_unit "$root" | xargs -r -I{} mv -f {} "$unit_file"; systemctl --user daemon-reload && systemctl --user enable odyssey.service && systemctl --user restart odyssey.service || { compensate "$plan_file" "$id" || true; return 1; }; write_receipt "$plan_file" "$generation" "$backup" "$absent"
    else
      jq -e --arg mainsha "$(sha "$main")" --arg integrationsha "$(sha "$integration")" --arg unitsha "$(sha "$unit_file")" '.main.afterSha256==$mainsha and .integration.sha256==$integrationsha and .unit.sha256==$unitsha' "$receipt_file" >/dev/null && split_matches_receipt "$receipt_file" "$main" || { error remove DRIFT 'managed host files changed' refused; return 73; }; backup=$(jq -r .main.backup "$receipt_file"); absent=$(jq -r '.main.previouslyAbsent // false' "$receipt_file"); if [[ $absent == false ]]; then [[ -f $backup && $(sha "$backup") == $(jq -r .main.backupSha256 "$receipt_file") ]] || { error remove BACKUP_DRIFT 'recorded main-config backup is unavailable' refused; return 73; }; fi; split_backups_valid "$receipt_file" || { error remove BACKUP_DRIFT 'recorded split-config backup is unavailable' refused; return 73; }; systemctl --user stop odyssey.service || true; systemctl --user disable odyssey.service || { compensate "$plan_file" "$id" || true; return 1; }; if [[ $absent == true ]]; then rm -f -- "$main"; else cp -p -- "$backup" "$main"; fi; restore_split_receipt "$receipt_file" "$main"; if [[ $(jq -r '.integration.previouslyAbsent' "$receipt_file") == true ]]; then rm -f -- "$integration"; else cp -p -- "$(jq -r .integration.backup "$receipt_file")" "$integration"; fi; if [[ $(jq -r '.unit.previouslyAbsent' "$receipt_file") == true ]]; then rm -f -- "$unit_file"; else cp -p -- "$(jq -r .unit.backup "$receipt_file")" "$unit_file"; fi; systemctl --user daemon-reload || { compensate "$plan_file" "$id" || true; return 1; }; if [[ $(jq -r 'if .previousReceipt then .previousReceipt.previouslyAbsent else true end' "$receipt_file") == false ]]; then previous=$(jq -r .previousReceipt.backup "$receipt_file"); [[ -f $previous && $(sha "$previous") == $(jq -r .previousReceipt.backupSha256 "$receipt_file") ]] || { error remove BACKUP_DRIFT 'previous startup receipt backup is unavailable' refused; return 73; }; cp -p -- "$previous" "$receipt_file"; else rm -f -- "$receipt_file"; fi; rm -f -- "$pending_file"; result remove completed unmanaged "$id"; return
    fi
    enabled && active || { error "$action" VERIFY_FAILED 'Odyssey unit did not become active'; return 75; }; rm -f -- "$pending_file"; result "$action" completed active "$id"
}
main() { shift 2; local cmd=${1:-} action='' id='' root='' mode='' plan_file=''; shift || true; while (($#)); do case $1 in --action) action=$2;shift 2;;--release-id) id=$2;shift 2;;--release-root) root=$2;shift 2;;--configuration-mode) mode=$2;shift 2;;--plan-file) plan_file=$2;shift 2;;--plan-id) id=$2;shift 2;;*) error "$cmd" INVALID_REQUEST 'invalid arguments' refused;return 64;;esac; done; case $cmd in status) status_json;;plan) plan "$action" "$id" "$root" "$mode";;apply|retarget|remove) mutate "$cmd" "$plan_file" "$id";;compensate) compensate "$plan_file" "$id";;*) error unknown INVALID_REQUEST 'invalid command' refused;return 64;;esac; }

if [[ ${1:-} == resolve-host ]]; then
    valid_configuration_mode "${2:-}" || { printf 'configuration mode must be managed or preserve\n' >&2; exit 64; }
    config=$(host "$2") || exit 73
    IFS=$'\t' read -r _ main_config _ <<<"$config"
    printf '%s\n' "$main_config"
    exit
fi
if [[ ${1:-} == --contract ]]; then [[ ${2:-} == odyssey-startup/v2 ]] || { error unknown UNSUPPORTED 'unsupported contract' unsupported; exit 69; }; main "$@"; exit $?; fi
[[ ${1:-} == status ]] && { systemd_ok && printf 'STATE=%s\n' "$(state)" || printf 'STATE=unsupported\n'; exit; }
printf 'usage: %s status\n' "$0" >&2; exit 64
