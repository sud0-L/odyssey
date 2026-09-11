#!/usr/bin/env bash
# Idempotent Arch/Hyprland source bootstrap, repair, and update entry point.
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
unattended=false
dry_run=false
configuration_mode=managed
configuration_mode_explicit=false
zsh_enabled=false
zsh_explicit=false

if [[ -t 1 && ${TERM:-dumb} != dumb && -z ${NO_COLOR:-} ]]; then
    reset=$'\033[0m' bold=$'\033[1m' dim=$'\033[2m'
    accent=$'\033[38;5;141m' good=$'\033[38;5;114m' warn=$'\033[38;5;215m' bad=$'\033[38;5;203m'
else
    reset='' bold='' dim='' accent='' good='' warn='' bad=''
fi

usage() {
    printf '%s\n' \
        'usage: ./install.sh [--yes] [--dry-run] [--preserve-config] [--with-zsh]' \
        '  --yes      accept the selected installation mode without prompting' \
        '  --dry-run  inspect and print the convergence plan without writes' \
        '  --preserve-config  retain personal desktop configuration files' \
        '  --with-zsh  explicitly install the optional Zsh/Oh My Zsh enhancement'
}
ask() {
    local reply
    [[ $unattended == true ]] && return 0
    read -r -p "$(printf '%s' "${bold}$1${reset} [Y/n] ")" reply || return 1
    [[ -z $reply || $reply =~ ^[Yy]$ ]]
}
ask_no() {
    local reply
    [[ $unattended == true ]] && return 1
    read -r -p "$(printf '%s' "${bold}$1${reset} [y/N] ")" reply || return 1
    [[ $reply =~ ^[Yy]$ ]]
}
display_path() { printf '%s\n' "${1/#$HOME/\~}"; }
section() { printf '\n%s%s%02d · %s%s\n' "$accent" "$bold" "$1" "$2" "$reset"; }
line() { printf '  %s%-2s%s %s\n' "$1" "$2" "$reset" "$3"; }
detail() { printf '     %s%s%s\n' "$dim" "$1" "$reset"; }
die() { printf '\n%s%sInstallation stopped:%s %s\n' "$bad" "$bold" "$reset" "$*" >&2; exit 1; }
run_as_root() {
    if ((EUID == 0)); then "$@"; return; fi
    command -v sudo >/dev/null 2>&1 || die 'sudo is required to configure system services.'
    sudo "$@"
}

while (($#)); do
    case $1 in
      --yes) unattended=true ;;
      --dry-run) dry_run=true ;;
      --preserve-config) configuration_mode=preserve; configuration_mode_explicit=true ;;
      --with-zsh) zsh_enabled=true; zsh_explicit=true ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; exit 64 ;;
    esac
    shift
done

data_root=${XDG_DATA_HOME:-"$HOME/.local/share"}
state_root=${XDG_STATE_HOME:-"$HOME/.local/state"}
config_root=${XDG_CONFIG_HOME:-"$HOME/.config"}
install_manifest="$state_root/odyssey/manager/install.json"
backup_root="$state_root/odyssey"
existing=false
existing_config=false
user_backup_dir=
backup_index=
managed_startup_targets=(
    "$config_root/hypr/hyprland.lua" "$config_root/hypr/odyssey.lua"
    "$config_root/hypr/config/animations.lua" "$config_root/hypr/config/appearance.lua"
    "$config_root/hypr/config/environment.lua" "$config_root/hypr/config/input.lua"
    "$config_root/hypr/config/keybinds.lua" "$config_root/hypr/config/layouts.lua"
    "$config_root/hypr/config/monitors.lua" "$config_root/hypr/config/startup.lua"
    "$config_root/hypr/config/window-rules.lua"
)
managed_host_targets=(
    "$config_root/kitty/kitty.conf" "$config_root/starship.toml"
    "$config_root/fastfetch/config.jsonc" "$config_root/hypr/hypridle.conf"
    "$config_root/systemd/user/hypridle.service"
)
managed_startup_targets+=("$config_root/systemd/user/odyssey.service")

for target in "$install_manifest" "$data_root/odyssey/current" "$data_root/odyssey/manager/current" "${XDG_BIN_HOME:-$HOME/.local/bin}/odyssey"; do
    [[ -e $target || -L $target ]] && existing=true
done
for target in "${managed_startup_targets[@]}" "${managed_host_targets[@]}"; do
    [[ -e $target || -L $target ]] && existing_config=true
done

printf '%s\n' \
    "${accent}╭──────────────────────────────────────────────╮${reset}" \
    "${accent}│${reset}  ${bold}Odyssey Installer${reset}  ${dim}· public alpha${reset}           ${accent}│${reset}" \
    "${accent}╰──────────────────────────────────────────────╯${reset}" \
    "${dim}A complete, deterministic Hyprland desktop environment.${reset}"

section 1 'Welcome'
if [[ $existing == true ]]; then
    line "$good" '●' 'Existing Odyssey installation detected — this run will update or repair it.'
else
    line "$accent" '●' 'Fresh Odyssey installation detected.'
fi
if [[ $existing_config == true ]]; then
    line "$warn" '●' 'Existing desktop configuration detected — affected files will be backed up first.'
fi
printf '\n  %sThis installer will:%s\n' "$dim" "$reset"
printf '%s\n' \
    "    ${dim}1. install every required official Arch package${reset}" \
    "    ${dim}2. enable the NetworkManager and Bluetooth system services${reset}" \
    "    ${dim}3. preserve existing configuration before Odyssey takes ownership${reset}" \
    "    ${dim}4. install, update, or repair a verified Odyssey release${reset}" \
    "    ${dim}5. apply the packaged desktop configuration or preserve personal files${reset}" \
    "    ${dim}6. start the desktop services and verify the finished environment${reset}"
printf '\n  %sSDDM remains a separate, manual integration and is not modified.%s\n' "$dim" "$reset"
[[ $dry_run == true ]] || ask 'Continue with installation?' || { printf '%s\n' 'No changes were made.'; exit 0; }
if [[ $existing_config == true && $unattended == false &&
      $configuration_mode_explicit == false && $dry_run == false ]]; then
    detail 'Choose No to preserve all personal config files; only a reversible require("odyssey") line is added to hyprland.lua.'
    if ! ask "Install Odyssey's packaged desktop configuration?"; then
        configuration_mode=preserve
    fi
fi
if [[ $zsh_explicit == false && $unattended == false && $dry_run == false ]]; then
    if ask_no 'Install the optional Odyssey Zsh and Oh My Zsh enhancement?'; then
        zsh_enabled=true
    fi
fi
if [[ $zsh_enabled == true && $configuration_mode == managed ]]; then
    managed_host_targets+=("$HOME/.zshrc")
fi

for source in config/hypr/hyprland.lua config/kitty/kitty.conf \
        config/starship/starship.toml config/fastfetch/config.jsonc config/zsh/.zshrc; do
    [[ -f $root_dir/$source && ! -L $root_dir/$source ]] \
        || die "Required packaged configuration is missing: $source"
done

hyprland_selection=interactive
[[ $unattended == false && -t 0 ]] || hyprland_selection=noninteractive
hyprland_config_path=$("$root_dir/scripts/select-hyprland-config.sh" \
    "$configuration_mode" "$hyprland_selection") \
    || die 'Hyprland configuration selection failed.'
export ODYSSEY_HYPRLAND_CONFIG="$hyprland_config_path"

create_user_backup_dir() {
    local candidate
    mkdir -p -- "$backup_root/backups"
    while :; do
        candidate="$backup_root/backups/odyssey-backup-$(date +%Y%m%d-%H%M%S)"
        if mkdir -- "$candidate" 2>/dev/null; then
            chmod 700 "$backup_root/backups" "$candidate"
            user_backup_dir=$candidate
            backup_index="$candidate/.odyssey-backup-index"
            : > "$backup_index"
            chmod 600 "$backup_index"
            return
        fi
        sleep 1
    done
}
backup_startup_target() {
    local target=$1 base candidate index=2
    [[ -e $target || -L $target ]] || return 0
    # The index is shared with host-configctl so a later installer stage can
    # never replace this run's original snapshot with an Odyssey-written one.
    grep -Fqx -- "$target" "$backup_index" && return 0
    base=$(basename -- "$target"); candidate="$base.bak"
    while [[ -e $user_backup_dir/$candidate || -L $user_backup_dir/$candidate ]]; do
        candidate="$base.$index.bak"; ((index+=1))
    done
    cp -a -- "$target" "$user_backup_dir/$candidate"
    printf '%s\n' "$target" >> "$backup_index"
}
account_shell_path() {
    local account selected
    account=$(id -un) || return 1
    selected=$(getent passwd "$account" 2>/dev/null | awk -F: 'NR==1 {print $7}') || return 1
    [[ -n $selected ]] || return 1
    printf '%s\n' "$selected"
}
shell_config_target() {
    local selected
    selected=$(account_shell_path) || return 1
    case "$(basename -- "$selected")" in
      bash) printf '%s\n' "$HOME/.bashrc" ;;
      zsh) printf '%s\n' "$HOME/.zshrc" ;;
      fish) printf '%s\n' "$config_root/fish/config.fish" ;;
      *) return 1 ;;
    esac
}
if [[ $existing_config == true && $dry_run == false ]]; then
    create_user_backup_dir
fi

section 2 'Dependencies'
if ! command -v python3 >/dev/null 2>&1; then
    line "$warn" '!' 'Python is required to inspect and install the remaining dependencies.'
    detail 'Bootstrap command: sudo pacman -S --needed python'
    if [[ $dry_run == true ]]; then
        printf '%s\n' '' 'Dry run: Python would be installed before dependency inspection.' 'Dry run complete. No changes were made.'
        exit 0
    fi
    [[ -r /etc/os-release ]] || die 'Cannot identify this host as Arch Linux.'
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ ${ID:-} == arch ]] && command -v pacman >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1 \
        || die 'Automatic Python installation requires Arch Linux, pacman, and sudo.'
    sudo pacman -S --needed python || die 'pacman could not install the required Python package.'
    command -v python3 >/dev/null 2>&1 || die 'Python was installed, but python3 is still unavailable.'
fi

deps=$("$root_dir/odyssey" dependencies --json)
while IFS=$'\t' read -r pkg present class; do
    if [[ $present == true ]]; then line "$good" '✓' "$pkg"; else line "$warn" '○' "$pkg  ($class)"; fi
done < <(python3 -c 'import json,sys;[print("{}\t{}\t{}".format(x["name"],str(x["available"]).lower(),x["class"])) for x in json.load(sys.stdin)["packages"]]' <<<"$deps")
mapfile -t missing < <(python3 -c 'import json,sys;sys.stdout.write("\n".join(json.load(sys.stdin)["missingPackages"]))' <<<"$deps")
if ((${#missing[@]})); then
    printf '\n  %sMissing packages%s\n' "$bold" "$reset"
    printf '     sudo pacman -S --needed'; printf ' %q' "${missing[@]}"; printf '\n'
    if [[ $dry_run == false ]]; then
        "$root_dir/odyssey" dependencies --install --yes >/dev/null
        deps=$("$root_dir/odyssey" dependencies --json)
        [[ $(jq -r '.missingPackages | length' <<<"$deps") == 0 ]] \
            || die 'Required dependencies remain missing after pacman completed.'
        line "$good" '✓' 'All required packages are installed.'
    fi
else
    line "$good" '✓' 'All required packages are already installed.'
fi
mapfile -t missing_optional < <(python3 -c 'import json,sys;sys.stdout.write("\\n".join(x["name"] for x in json.load(sys.stdin).get("optionalPackages", []) if x["class"]=="optional-power-profile" and not x["available"]))' <<<"$deps")
if ((${#missing_optional[@]})); then
    printf '\n  %sOptional enhancements%s\n' "$bold" "$reset"
    python3 -c 'import json,sys
for x in json.load(sys.stdin).get("optionalPackages",[]):
 if x["class"]=="optional-power-profile": print("     [{}] {:22} {}".format("x" if x["available"] else " ",x["name"],x["class"]))' <<<"$deps"
    if [[ $unattended == false && $dry_run == false ]]; then
        if ask_no 'Install optional enhancements?'; then
            "$root_dir/odyssey" dependencies --install --optional --optional-class optional-power-profile --yes >/dev/null
            deps=$("$root_dir/odyssey" dependencies --json)
            line "$good" '✓' 'Optional enhancements installed.'
        else
            line "$accent" '→' 'Optional enhancements skipped.'
        fi
    elif [[ $unattended == true ]]; then
        detail 'Optional enhancements skipped by non-interactive default.'
    fi
elif [[ $(jq -r '[.optionalPackages[] | select(.class=="optional-power-profile")] | length' <<<"$deps") -gt 0 ]]; then
    line "$good" '✓' 'All optional enhancements are already installed.'
fi
if [[ $zsh_enabled == true ]]; then
    if [[ $dry_run == true ]]; then
        detail 'Optional Zsh prerequisites would be installed or verified because --with-zsh was selected.'
    else
        line "$accent" '→' 'Installing optional Zsh prerequisites…'
        "$root_dir/odyssey" dependencies --install --optional --optional-class optional-zsh --yes >/dev/null
        deps=$("$root_dir/odyssey" dependencies --json)
        [[ $(jq -r '[.optionalPackages[] | select(.class=="optional-zsh" and (.available|not))] | length' <<<"$deps") == 0 ]] \
            || die 'Optional Zsh prerequisites remain missing after pacman completed.'
        line "$good" '✓' 'Optional Zsh prerequisites are installed.'
    fi
else
    detail 'Zsh and Oh My Zsh were not selected; no Zsh packages or configuration will be installed.'
fi

section 3 'Configuration & backup plan'
if [[ $configuration_mode == managed ]]; then
    line "$accent" '●' 'Managed configuration — packaged desktop files will be installed.'
    printf '  %-11s %s\n' 'Hyprland' "$(display_path "$config_root/hypr/hyprland.lua") + odyssey.lua"
    printf '  %-11s %s\n' 'Kitty' "$(display_path "$config_root/kitty/kitty.conf")"
    printf '  %-11s %s\n' 'Starship' "$(display_path "$config_root/starship.toml") + login-shell initialization"
    printf '  %-11s %s\n' 'Fastfetch' "$(display_path "$config_root/fastfetch/config.jsonc")"
    if [[ $zsh_enabled == true ]]; then
        printf '  %-11s %s\n' 'Zsh' "$(display_path "$HOME/.zshrc") + pinned Oh My Zsh plugins (opted in)"
    else
        printf '  %-11s %s\n' 'Zsh' 'not installed or modified (optional enhancement not selected)'
    fi
    printf '  %-11s %s\n' 'Hypridle' "$(display_path "$config_root/hypr/hypridle.conf") + hypridle.service"
else
    line "$good" '●' 'Preserve configuration — personal desktop files remain unchanged.'
    printf '  %-11s %s\n' 'Hyprland' 'preserved; only the reversible Odyssey startup include is managed'
    printf '  %-11s %s\n' 'Kitty' 'preserved'
    printf '  %-11s %s\n' 'Starship' 'preserved; shell startup files are not modified'
    printf '  %-11s %s\n' 'Fastfetch' 'preserved'
    if [[ $zsh_enabled == true ]]; then
        printf '  %-11s %s\n' 'Zsh' '.zshrc preserved; pinned Oh My Zsh plugins will be installed (opted in)'
    else
        printf '  %-11s %s\n' 'Zsh' '.zshrc preserved; optional enhancement not selected'
    fi
    printf '  %-11s %s\n' 'Hypridle' 'preserved; existing service state is not modified'
fi
if [[ -n $user_backup_dir ]]; then
    detail 'Every existing file this run modifies is backed up first.'
    detail 'Pre-install backups will be stored in:'
    printf '     %s\n' "$(display_path "$user_backup_dir")/"
else
    detail 'No existing files require a user configuration backup.'
fi
if [[ $dry_run == true ]]; then
    printf '\n%s%sDry run complete.%s No changes were made.\n' "$good" "$bold" "$reset"
    exit 0
fi

default_shell=$(account_shell_path || true)
shell_switch_declined=false
if [[ $zsh_enabled == true && $(basename -- "${default_shell:-unknown}") != zsh ]]; then
    zsh_path=$(command -v zsh) || die 'Zsh was selected but is unavailable after dependency installation.'
    if ask_no 'Switch default shell to Zsh?'; then
        chsh -s "$zsh_path" || die 'chsh could not switch the default shell to Zsh.'
        default_shell=$(account_shell_path) || die 'Could not verify the account default shell after chsh.'
        [[ $(basename -- "$default_shell") == zsh ]] \
            || die 'chsh completed, but the account default shell is still not Zsh.'
    else
        shell_switch_declined=true
    fi
fi
if [[ $zsh_enabled == true && $(basename -- "${default_shell:-unknown}") == zsh ]]; then
    export SHELL="$default_shell"
    systemctl --user set-environment "SHELL=$default_shell" \
        || die 'Could not refresh the user service environment with the verified Zsh login shell.'
    if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && hyprctl monitors -j >/dev/null 2>&1; then
        hyprctl keyword env "SHELL,$default_shell" >/dev/null \
            || die 'Could not refresh the live Hyprland environment with the verified Zsh login shell.'
    fi
fi

section 4 'System services'
if systemctl is-enabled NetworkManager.service bluetooth.service >/dev/null 2>&1 \
        && systemctl is-active NetworkManager.service bluetooth.service >/dev/null 2>&1; then
    line "$good" '✓' 'NetworkManager and Bluetooth are already enabled and active.'
else
    line "$accent" '→' 'Enabling NetworkManager and Bluetooth for this and future boots…'
    run_as_root systemctl enable --now NetworkManager.service bluetooth.service \
        || die 'NetworkManager or Bluetooth could not be enabled and started.'
    line "$good" '✓' 'NetworkManager and Bluetooth are enabled and active.'
fi

section 5 'Install & activate'
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/odyssey-install.XXXXXX")
trap 'rm -rf -- "$build_dir"' EXIT
preserve_manifest="$build_dir/preserved-config.sha256"
preserved_zshrc_identity=
file_identity() {
    local path=$1
    if [[ -L $path ]]; then printf 'link:%s:%s\n' "$path" "$(readlink -- "$path")"
    elif [[ -f $path ]]; then printf 'file:%s:%s\n' "$path" "$(sha256sum -- "$path" | awk '{print $1}')"
    elif [[ -e $path ]]; then printf 'other:%s\n' "$path"
    else printf 'absent:%s\n' "$path"; fi
}
preserved_configs=(
    "$config_root/kitty/kitty.conf" "$config_root/starship.toml"
    "$config_root/fastfetch/config.jsonc" "$config_root/hypr/hypridle.conf"
    "$config_root/systemd/user/hypridle.service" "$HOME/.bashrc" "$HOME/.zshrc"
    "$config_root/fish/config.fish"
)
if [[ $configuration_mode == preserve ]]; then
    for target in "${preserved_configs[@]}"; do file_identity "$target"; done > "$preserve_manifest"
    preserved_zshrc_identity=$(file_identity "$HOME/.zshrc")
fi
artifact="$build_dir/odyssey.ody"
line "$accent" '→' 'Building and verifying the local release artifact…'
project_version=$(<"$root_dir/VERSION")
"$root_dir/odyssey" artifact build --version "$project_version" --output "$artifact" >/dev/null
digest=$("$root_dir/odyssey" artifact verify "$artifact" --json | jq -r .artifactSha256)
line "$good" '✓' 'Release artifact verified.'
line "$accent" '→' 'Converging release, configuration, shortcuts, and user services…'
if [[ -n $user_backup_dir ]]; then
    # Take every snapshot before the first lifecycle helper can touch a user
    # file. Managed mode owns the complete packaged set; preserve mode only
    # patches Hyprland's reversible include and its integration/service files.
    if [[ $configuration_mode == managed ]]; then
        backup_targets=("${managed_startup_targets[@]}" "${managed_host_targets[@]}")
    else
        backup_targets=("$config_root/hypr/hyprland.lua" "$config_root/hypr/odyssey.lua" "$config_root/systemd/user/odyssey.service")
    fi
    shell_target=$(shell_config_target || true)
    if [[ $configuration_mode == managed && -n $shell_target ]]; then
        backup_targets+=("$shell_target")
    fi
    for target in "${backup_targets[@]}"; do backup_startup_target "$target"; done
fi
lifecycle=$("$root_dir/odyssey" bootstrap --artifact "$artifact" \
    --expect-sha256 "$digest" --configuration-mode "$configuration_mode" --json)
release_root="$data_root/odyssey/current"
expected_release_id="$project_version-$digest"
actual_configuration_mode=$(jq -r '.configurationMode // empty' \
    "$state_root/odyssey/startup/session-startup.json" 2>/dev/null || true)
[[ $actual_configuration_mode == "$configuration_mode" ]] \
    || die "Startup adapter recorded configuration mode '${actual_configuration_mode:-missing}', expected '$configuration_mode'."
[[ $(basename -- "$(readlink -f -- "$release_root")") == "$expected_release_id" ]] \
    || die "Bootstrap did not activate the current verified release '$expected_release_id'."
zsh_result='ZSH_SETUP=skipped
CHANGED=0'
if [[ $zsh_enabled == true ]]; then
    line "$accent" '→' 'Installing or validating pinned Oh My Zsh components…'
    if ! zsh_result=$("$release_root/scripts/zsh-setup.sh" apply); then
        die 'Oh My Zsh or required Zsh plugins could not be installed.'
    fi
    line "$good" '✓' 'Pinned Oh My Zsh components are installed.'
fi
if [[ $configuration_mode == managed ]]; then
    for source in config/hypr/animations.lua config/hypr/appearance.lua \
            config/hypr/environment.lua config/hypr/input.lua config/hypr/keybinds.lua \
            config/hypr/layouts.lua config/hypr/monitors.lua config/hypr/startup.lua \
            config/hypr/window-rules.lua; do
        [[ -f $release_root/$source && ! -L $release_root/$source ]] \
            || die "Active verified release lacks managed payload: $source"
    done
fi
if [[ $configuration_mode == managed ]]; then
    config_result=$(ODYSSEY_USER_BACKUP_DIR="$user_backup_dir" "$release_root/scripts/host-configctl.sh" apply "$zsh_enabled")
else
    config_result='HOST_CONFIG=preserved
CHANGED=0
BACKUP=none'
fi
"$release_root/scripts/shortcutctl.sh" apply "$config_root/hypr/hyprland.lua" true true true true true true true true true >/dev/null
systemctl --user daemon-reload
if [[ $configuration_mode == managed ]]; then
    systemctl --user enable odyssey.service hypridle.service >/dev/null
    systemctl --user restart odyssey.service hypridle.service
else
    systemctl --user enable odyssey.service >/dev/null
    systemctl --user restart odyssey.service
fi
line "$good" '✓' 'Odyssey configuration and user services are active.'

section 6 'Verification'
declare -a labels=() results=() details=()
check() { labels+=("$1"); check_detail=; shift; if "$@"; then results+=(pass); details+=(""); else results+=(fail); details+=("${check_detail:-failed}"); fi; }
has_command() { command -v "$1" >/dev/null 2>&1; }
odyssey_command_ok() {
    local output expected="${XDG_BIN_HOME:-$HOME/.local/bin}/odyssey"
    output=$("$root_dir/scripts/verify-launcher-path.sh" "$expected" 2>&1) \
        || { check_detail=$output; return 1; }
}
valid_release() {
    [[ -f $install_manifest && -L $data_root/odyssey/current && -L $data_root/odyssey/manager/current ]] || return 1
    local active; active=$(jq -er .activeReleaseId "$install_manifest") || return 1
    [[ $(basename -- "$(readlink -f "$data_root/odyssey/current")") == "$active" ]]
}
valid_hyprland_files() {
    local split file
    [[ -f $config_root/hypr/hyprland.lua && -f $config_root/hypr/odyssey.lua ]]
    [[ $(grep -Fxc 'require("odyssey")' "$config_root/hypr/hyprland.lua") == 1 ]]
    if [[ $configuration_mode == managed ]]; then
        split="$config_root/hypr/config"
        for file in animations.lua appearance.lua environment.lua input.lua keybinds.lua layouts.lua monitors.lua startup.lua window-rules.lua; do
            [[ -f $split/$file && ! -L $split/$file ]] || return 1
        done
        ! grep -En '/home/[^/]+|\.config/odyssey|odyssey/releases/' \
            "$config_root/hypr/hyprland.lua" "$config_root/hypr/odyssey.lua" \
            "$config_root/hypr/config/"*.lua >/dev/null
    else
        ! grep -En '/home/[^/]+|\.config/odyssey|odyssey/releases/' \
            "$config_root/hypr/odyssey.lua" >/dev/null
    fi
}
valid_shortcuts() {
    local expected=13
    [[ $configuration_mode == managed ]] && expected=9
    [[ $(grep -Fc 'ODYSSEY MANAGED SHORTCUTS' "$config_root/hypr/odyssey.lua") == 2 ]] || return 1
    [[ $(grep -Fc 'odyssey ipc ' "$config_root/hypr/odyssey.lua") == "$expected" ]] \
        && ! grep -Eq 'qs -p|/home/|\.config/odyssey|odyssey/releases/' \
            "$config_root/hypr/odyssey.lua"
}
unit_ok() { [[ -f $config_root/systemd/user/$1.service ]] && systemctl --user is-enabled "$1.service" >/dev/null 2>&1 && systemctl --user is-active "$1.service" >/dev/null 2>&1; }
system_unit_ok() { systemctl is-enabled "$1.service" >/dev/null 2>&1 && systemctl is-active "$1.service" >/dev/null 2>&1; }
kitty_config_ok() {
    [[ -f $config_root/kitty/kitty.conf && ! -L $config_root/kitty/kitty.conf ]] \
        && grep -Fq -- "$state_root/odyssey/theme-exports/kitty.conf" "$config_root/kitty/kitty.conf"
}
starship_config_ok() {
    local init rc
    [[ -f $config_root/starship.toml && ! -L $config_root/starship.toml ]] \
        && STARSHIP_CONFIG="$config_root/starship.toml" starship prompt >/dev/null 2>&1 \
        || return 1
    case "$(basename -- "${SHELL:-bash}")" in
      bash) init='eval "$(starship init bash)"'; rc="$HOME/.bashrc" ;;
      zsh) init='eval "$(starship init zsh)"'; rc="$HOME/.zshrc" ;;
      fish) init='starship init fish | source'; rc="$config_root/fish/config.fish" ;;
      *) return 1 ;;
    esac
    [[ $(grep -Fxc -- "$init" "$rc" 2>/dev/null || true) == 1 ]]
}
fastfetch_config_ok() {
    [[ -f $config_root/fastfetch/config.jsonc && ! -L $config_root/fastfetch/config.jsonc ]] \
        && fastfetch --config "$config_root/fastfetch/config.jsonc" --pipe false >/dev/null 2>&1
}
oh_my_zsh_ok() { [[ -f $HOME/.oh-my-zsh/oh-my-zsh.sh && ! -L $HOME/.oh-my-zsh ]]; }
zshrc_ok() { cmp -s -- "$release_root/config/zsh/.zshrc" "$HOME/.zshrc"; }
zshrc_preserved() { [[ $(file_identity "$HOME/.zshrc") == "$preserved_zshrc_identity" ]]; }
zsh_plugin_ok() { [[ -f $HOME/.oh-my-zsh/custom/plugins/$1/$2 ]]; }
personal_configs_preserved() {
    local after="$build_dir/preserved-config.after"
    for target in "${preserved_configs[@]}"; do file_identity "$target"; done > "$after"
    cmp -s -- "$preserve_manifest" "$after"
}
hyprland_config_ok() {
    local verify
    verify=$(Hyprland --verify-config --config "$config_root/hypr/hyprland.lua" 2>&1) \
        || { check_detail="$verify"; return 1; }
    grep -Fq 'config ok' <<<"$verify" || { check_detail='Hyprland offline parser did not report config ok'; return 1; }
    if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && hyprctl monitors -j >/dev/null 2>&1; then
        local errors; errors=$(hyprctl configerrors 2>&1) || { check_detail="$errors"; return 1; }
        [[ -z ${errors//[[:space:]]/} ]] || { check_detail="$errors"; return 1; }
    fi
}
font_ok() {
    local expected=$1 path=$2
    [[ -f $path ]] || return 1
    fc-match -f '%{family}\n' "$expected" 2>/dev/null | grep -Fq -- "$expected"
}

for cmd in qs hypridle hyprpicker matugen starship fastfetch nmcli bluetoothctl playerctl sensors notify-send; do check "Command · $cmd" has_command "$cmd"; done
check 'Command · odyssey' odyssey_command_ok
check 'Font · Adwaita Sans' font_ok 'Adwaita Sans' /usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf
check 'Font · JetBrainsMono Nerd Font' font_ok 'JetBrainsMono Nerd Font' /usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf
if [[ $zsh_enabled == true ]]; then check 'Command · zsh' has_command zsh; fi
check 'System service · NetworkManager' system_unit_ok NetworkManager
check 'System service · Bluetooth' system_unit_ok bluetooth
check 'Odyssey release' valid_release
check 'Hyprland configuration' valid_hyprland_files
check 'Odyssey shortcuts' valid_shortcuts
check 'User service · Odyssey' unit_ok odyssey
if [[ $configuration_mode == managed ]]; then
    check 'User service · Hypridle' unit_ok hypridle
    check 'Kitty configuration' kitty_config_ok
    check 'Starship configuration' starship_config_ok
    check 'Fastfetch configuration' fastfetch_config_ok
    if [[ $zsh_enabled == true ]]; then check 'Odyssey .zshrc' zshrc_ok; fi
else
    check 'Personal configurations preserved' personal_configs_preserved
    check 'Odyssey .zshrc · preserved' zshrc_preserved
fi
if [[ $zsh_enabled == true ]]; then
    check 'Oh My Zsh' oh_my_zsh_ok
    check 'Zsh plugin · zsh-autosuggestions' zsh_plugin_ok zsh-autosuggestions zsh-autosuggestions.zsh
    check 'Zsh plugin · zsh-syntax-highlighting' zsh_plugin_ok zsh-syntax-highlighting zsh-syntax-highlighting.zsh
    check 'Zsh plugin · zsh-autocomplete' zsh_plugin_ok zsh-autocomplete zsh-autocomplete.plugin.zsh
fi
check 'Hyprland config valid' hyprland_config_ok

failed=0
for i in "${!labels[@]}"; do
    if [[ ${results[$i]} == pass ]]; then line "$good" '✓' "${labels[$i]}"; else line "$bad" '!' "${labels[$i]}${details[$i]:+: ${details[$i]}}"; failed=1; fi
done
if [[ $zsh_enabled == true && $(basename -- "${default_shell:-unknown}") == zsh ]]; then
    line "$good" '✓' "Default shell · $default_shell"
elif [[ $zsh_enabled == true ]]; then
    line "$warn" '○' "Default shell · ${default_shell:-unknown} (Zsh not selected as default)"
fi
printf '\n  %-19s %s\n' 'Lifecycle action' "$(jq -r '.action // .status' <<<"$lifecycle")"
printf '  %-19s %s\n' 'Configuration mode' "$configuration_mode"
printf '  %-19s %s\n' 'Configuration changes' "$(awk -F= '$1=="CHANGED"{print $2}' <<<"$config_result")"
printf '  %-19s %s\n' 'Zsh setup changes' "$(awk -F= '$1=="CHANGED"{print $2}' <<<"$zsh_result")"
backup=${user_backup_dir:-$(awk -F= '$1=="BACKUP"{sub(/^BACKUP=/,"");print}' <<<"$config_result")}
[[ -z $backup || $backup == none ]] || printf '  %-19s %s\n' 'Configuration backup' "$(display_path "$backup")"
if ((failed)); then
    die 'Validation found one or more failed checks. Review the marked entries and rerun ./install.sh after correcting the host issue.'
fi
if [[ $zsh_enabled == true && $shell_switch_declined == true ]]; then
    if [[ $configuration_mode == managed ]]; then
        detail 'The Odyssey Zsh configuration is installed, but Zsh is not the default shell.'
    else
        detail 'Oh My Zsh and its plugins are installed, but Zsh is not the default shell; the existing .zshrc was preserved.'
    fi
fi

printf '\n%s%s╭──────────────────────────────────────────────╮%s\n' "$good" "$bold" "$reset"
printf '%s%s│  Installation complete                       │%s\n' "$good" "$bold" "$reset"
printf '%s%s╰──────────────────────────────────────────────╯%s\n' "$good" "$bold" "$reset"
printf '%s\n' 'Odyssey is installed, configured, running, and ready.' \
    'Rerun ./install.sh at any time to repair or update this installation.'
