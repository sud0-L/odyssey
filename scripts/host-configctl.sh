#!/usr/bin/env bash
# Canonical public-alpha user configuration deployment and repair.
set -euo pipefail

action=${1:-}
zsh_enabled=${2:-false}
[[ $zsh_enabled == true || $zsh_enabled == false ]] || {
    printf 'usage: %s {apply|validate} [true|false]\n' "$0" >&2
    exit 64
}
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
home_dir=${HOME:?HOME is required}
config_root=${XDG_CONFIG_HOME:-"$home_dir/.config"}
state_root=${XDG_STATE_HOME:-"$home_dir/.local/state"}
backup_root="$state_root/odyssey/backups"
receipt="$state_root/odyssey/installer/host-config.json"
unit_dir="$config_root/systemd/user"
hypridle_unit="$unit_dir/hypridle.service"
changed=0
backup_dir=
shell_rc=
declare -a backed_up=()
declare -A backed_up_targets=()

die() { printf 'odyssey config: %s\n' "$*" >&2; exit 1; }
sha() { sha256sum -- "$1" | awk '{print $1}'; }
ensure_backup_dir() {
    [[ -n $backup_dir ]] && return
    if [[ -n ${ODYSSEY_USER_BACKUP_DIR:-} ]]; then
        [[ -d $ODYSSEY_USER_BACKUP_DIR && ! -L $ODYSSEY_USER_BACKUP_DIR ]] \
            || die 'installer user backup directory is unavailable'
        backup_dir=$ODYSSEY_USER_BACKUP_DIR
        return
    fi
    backup_dir="$backup_root/odyssey-backup-$(date +%Y%m%d-%H%M%S)"
    while [[ -e $backup_dir || -L $backup_dir ]]; do sleep 1; backup_dir="$backup_root/odyssey-backup-$(date +%Y%m%d-%H%M%S)"; done
    mkdir -p -- "$backup_dir"
    chmod 700 "$backup_root" "$backup_dir"
}
backup_target() {
    local target=$1 label=$2 base candidate index=2
    [[ -e $target || -L $target ]] || return 0
    [[ -n ${backed_up_targets[$target]:-} ]] && return 0
    ensure_backup_dir
    if [[ -n ${ODYSSEY_USER_BACKUP_DIR:-} && -f $backup_dir/.odyssey-backup-index ]] &&
            grep -Fqx -- "$target" "$backup_dir/.odyssey-backup-index"; then
        backed_up_targets[$target]=1
        return 0
    fi
    base=$(basename -- "$target"); candidate="$base.bak"
    while [[ -e $backup_dir/$candidate || -L $backup_dir/$candidate ]]; do candidate="$base.$index.bak"; ((index+=1)); done
    cp -a -- "$target" "$backup_dir/$candidate"
    backed_up_targets[$target]=1
    if [[ -n ${ODYSSEY_USER_BACKUP_DIR:-} ]]; then
        printf '%s\n' "$target" >> "$backup_dir/.odyssey-backup-index"
    fi
    backed_up+=("$target")
}
atomic_install() {
    local source=$1 target=$2 label=$3 mode=${4:-600} tmp
    backup_target "$target" "$label"
    mkdir -p -- "$(dirname -- "$target")"
    tmp=$(mktemp "$(dirname -- "$target")/.odyssey-config.XXXXXX")
    install -m "$mode" -- "$source" "$tmp"
    mv -f -- "$tmp" "$target"
    case $label in
      kitty.conf) reset_adapter_state "$state_root/odyssey/kitty-theme.json" kitty-theme.json ;;
      starship.toml) reset_adapter_state "$state_root/odyssey/starship-theme.json" starship-theme.json ;;
      fastfetch-config.jsonc) reset_adapter_state "$state_root/odyssey/fastfetch-theme.json" fastfetch-theme.json ;;
    esac
    ((changed+=1)) || true
}
reset_adapter_state() {
    local path=$1 label=$2
    [[ -e $path || -L $path ]] || return 0
    ensure_backup_dir
    cp -a -- "$path" "$backup_dir/$label"
    rm -f -- "$path"
}
render_kitty() {
    local output=$1 theme="$state_root/odyssey/theme-exports/kitty.conf"
    sed "s#@ODYSSEY_KITTY_THEME@#$theme#g" "$project_dir/config/kitty/kitty.conf" > "$output"
}
render_hypridle_unit() {
    local output=$1
    printf '%s\n' '# Managed by Odyssey installer' '[Unit]' \
        'Description=Odyssey idle and lock policy' \
        'PartOf=graphical-session.target' 'After=graphical-session.target' '' \
        '[Service]' 'Type=simple' 'ExecStart=/bin/sh -c '\''exec "$${XDG_BIN_HOME:-$${HOME}/.local/bin}/odyssey" hypridle'\''' \
        'Restart=on-failure' 'RestartSec=3' '' '[Install]' \
        'WantedBy=graphical-session.target' > "$output"
}
shell_name() {
    local account selected
    account=$(id -un) || return 1
    selected=$(getent passwd "$account" 2>/dev/null | awk -F: 'NR==1 {print $7}') || return 1
    [[ -n $selected ]] || return 1
    basename -- "$selected"
}
configure_shell() {
    local shell rc init begin='# BEGIN ODYSSEY STARSHIP' end='# END ODYSSEY STARSHIP' tmp
    shell=$(shell_name || true)
    case $shell in
      bash) rc="$home_dir/.bashrc"; init='eval "$(starship init bash)"' ;;
      zsh) rc="$home_dir/.zshrc"; init='eval "$(starship init zsh)"' ;;
      fish) rc="$config_root/fish/config.fish"; init='starship init fish | source' ;;
      *) shell_rc=; return 0 ;;
    esac
    [[ $shell != zsh || $zsh_enabled == true ]] || { shell_rc=; return 0; }
    shell_rc=$rc
    mkdir -p -- "$(dirname -- "$rc")"
    [[ -e $rc || -L $rc ]] || : > "$rc"
    if grep -Fqx -- "$init" "$rc" && ! grep -Fqx -- "$begin" "$rc"; then return 0; fi
    tmp=$(mktemp "$(dirname -- "$rc")/.odyssey-shell.XXXXXX")
    awk -v b="$begin" -v e="$end" '$0==b{inside=1;next}$0==e{inside=0;next}!inside{print}' "$rc" > "$tmp"
    if ! grep -Fqx -- "$init" "$tmp"; then printf '%s\n%s\n%s\n' "$begin" "$init" "$end" >> "$tmp"; fi
    if ! cmp -s -- "$tmp" "$rc"; then
        backup_target "$rc" "shell-$shell.rc"
        chmod --reference="$rc" "$tmp" 2>/dev/null || chmod 600 "$tmp"
        mv -f -- "$tmp" "$rc"
        ((changed+=1)) || true
    else rm -f -- "$tmp"; fi
}
write_receipt() {
    local tmp shell_digest="" zsh_digest=""; mkdir -p -- "$(dirname -- "$receipt")"; tmp=$(mktemp "$(dirname -- "$receipt")/.host-config.XXXXXX")
    [[ -n $shell_rc && -f $shell_rc ]] && shell_digest=$(sha "$shell_rc")
    [[ $zsh_enabled == true && -f $home_dir/.zshrc ]] && zsh_digest=$(sha "$home_dir/.zshrc")
    jq -n --arg backup "${backup_dir:-}" --argjson changed "$changed" \
        --argjson targets "$(printf '%s\n' "${backed_up[@]:-}" | jq -R . | jq -s 'map(select(length>0))')" \
        --arg kitty "$(sha "$config_root/kitty/kitty.conf")" --arg starship "$(sha "$config_root/starship.toml")" \
        --arg fastfetch "$(sha "$config_root/fastfetch/config.jsonc")" --arg hypridle "$(sha "$config_root/hypr/hypridle.conf")" \
        --arg zshrc "$zsh_digest" --arg service "$(sha "$hypridle_unit")" --arg shell "$shell_digest" \
        --argjson zsh "$zsh_enabled" \
        '{schema:1,manager:"odyssey-host-config",zshEnabled:$zsh,backupDirectory:$backup,changedCount:$changed,backedUpTargets:$targets,files:{"kitty.conf":$kitty,"starship.toml":$starship,"fastfetch-config.jsonc":$fastfetch,"hypridle.conf":$hypridle,".zshrc":$zshrc,"hypridle.service":$service,"shell-rc":$shell}}' > "$tmp"
    chmod 600 "$tmp"; mv -f -- "$tmp" "$receipt"
}
apply() {
    local stage
    stage=$(mktemp -d "${TMPDIR:-/tmp}/odyssey-host-config.XXXXXX")
    trap 'rm -rf -- "$stage"' RETURN
    render_kitty "$stage/kitty.conf"
    render_hypridle_unit "$stage/hypridle.service"
    atomic_install "$stage/kitty.conf" "$config_root/kitty/kitty.conf" kitty.conf
    atomic_install "$project_dir/config/starship/starship.toml" "$config_root/starship.toml" starship.toml
    atomic_install "$project_dir/config/fastfetch/config.jsonc" "$config_root/fastfetch/config.jsonc" fastfetch-config.jsonc
    atomic_install "$project_dir/config/hypridle/hypridle.conf" "$config_root/hypr/hypridle.conf" hypridle.conf
    if [[ $zsh_enabled == true ]]; then
        atomic_install "$project_dir/config/zsh/.zshrc" "$home_dir/.zshrc" .zshrc
    fi
    atomic_install "$stage/hypridle.service" "$hypridle_unit" hypridle.service
    configure_shell
    "$project_dir/scripts/terminal-integrations.sh" enable >/dev/null
    systemctl --user daemon-reload
    systemctl --user enable hypridle.service >/dev/null
    if systemctl --user is-active hypridle.service >/dev/null 2>&1; then
        systemctl --user restart hypridle.service
    else
        systemctl --user start hypridle.service
    fi
    write_receipt
    printf 'HOST_CONFIG=completed\nCHANGED=%s\nBACKUP=%s\n' "$changed" "${backup_dir:-none}"
}
validate() {
    local failed=0 shell init
    for file in "$config_root/kitty/kitty.conf" "$config_root/starship.toml" \
        "$config_root/fastfetch/config.jsonc" "$config_root/hypr/hypridle.conf" \
        "$hypridle_unit"; do
        [[ -f $file && ! -L $file ]] || { printf 'FAIL file %s\n' "$file"; failed=1; }
    done
    grep -Fq -- "$state_root/odyssey/theme-exports/kitty.conf" "$config_root/kitty/kitty.conf" || { printf 'FAIL kitty-theme\n'; failed=1; }
    STARSHIP_CONFIG="$config_root/starship.toml" starship prompt >/dev/null 2>&1 || { printf 'FAIL starship-config\n'; failed=1; }
    fastfetch --config "$config_root/fastfetch/config.jsonc" --pipe false >/dev/null 2>&1 || { printf 'FAIL fastfetch-config\n'; failed=1; }
    if [[ $zsh_enabled == true ]]; then
        [[ -f $home_dir/.zshrc && ! -L $home_dir/.zshrc ]] || { printf 'FAIL file %s\n' "$home_dir/.zshrc"; failed=1; }
        cmp -s -- "$project_dir/config/zsh/.zshrc" "$home_dir/.zshrc" || { printf 'FAIL zsh-config\n'; failed=1; }
    fi
    shell=$(shell_name || true)
    case $shell in
      bash) init='eval "$(starship init bash)"'; rc="$home_dir/.bashrc" ;;
      zsh)
        if [[ $zsh_enabled == true ]]; then init='eval "$(starship init zsh)"'; rc="$home_dir/.zshrc"
        else init=; rc=; fi ;;
      fish) init='starship init fish | source'; rc="$config_root/fish/config.fish" ;;
      *) init=; rc= ;;
    esac
    [[ -z ${rc:-} || $(grep -Fxc -- "$init" "$rc" 2>/dev/null || true) == 1 ]] || { printf 'FAIL starship-init\n'; failed=1; }
    systemctl --user is-enabled hypridle.service >/dev/null 2>&1 || { printf 'FAIL hypridle-enabled\n'; failed=1; }
    systemctl --user is-active hypridle.service >/dev/null 2>&1 || { printf 'FAIL hypridle-active\n'; failed=1; }
    ((failed==0)) && printf 'HOST_CONFIG=valid\n'
    return "$failed"
}

case $action in apply) apply;; validate) validate;; *) printf 'usage: %s {apply|validate} [true|false]\n' "$0" >&2; exit 64;; esac
