#!/usr/bin/env bash
# Install and validate Odyssey's fixed Oh My Zsh plugin set.
set -euo pipefail

action=${1:-}
home_dir=${HOME:?HOME is required}
oh_my_zsh="$home_dir/.oh-my-zsh"
plugins_root="$oh_my_zsh/custom/plugins"
changed=0

die() { printf 'odyssey zsh: %s\n' "$*" >&2; exit 1; }

ensure_repository() {
    local target=$1 url=$2 revision=$3 marker=$4 label=$5 parent stage origin head
    if [[ -e $target || -L $target ]]; then
        origin=$(git -C "$target" remote get-url origin 2>/dev/null || true)
        head=$(git -C "$target" rev-parse HEAD 2>/dev/null || true)
        [[ -d $target && ! -L $target && -f $target/$marker && $origin == "$url" && $head == "$revision" ]] \
            || die "$label exists but is not a valid managed dependency: $target"
        return
    fi
    parent=$(dirname -- "$target")
    mkdir -p -- "$parent"
    stage=$(mktemp -d "$parent/.odyssey-zsh.XXXXXX")
    mkdir -- "$stage/repository"
    git -C "$stage/repository" init -q
    git -C "$stage/repository" remote add origin "$url"
    if ! git -C "$stage/repository" fetch --depth=1 origin "$revision" >/dev/null 2>&1 \
            || ! git -C "$stage/repository" checkout -q --detach FETCH_HEAD; then
        rm -rf -- "$stage"
        die "could not install $label"
    fi
    if [[ ! -f $stage/repository/$marker ]]; then
        rm -rf -- "$stage"
        die "$label download did not contain its required entrypoint"
    fi
    mv -- "$stage/repository" "$target"
    rmdir -- "$stage"
    ((changed+=1)) || true
}

valid() {
    command -v zsh >/dev/null 2>&1 \
        && [[ -f $oh_my_zsh/oh-my-zsh.sh && ! -L $oh_my_zsh ]] \
        && [[ -f $plugins_root/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
        && [[ -f $plugins_root/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
        && [[ -f $plugins_root/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]]
}

apply() {
    command -v git >/dev/null 2>&1 || die 'git is required to install Oh My Zsh'
    command -v zsh >/dev/null 2>&1 || die 'zsh is required before configuring Oh My Zsh'
    ensure_repository "$oh_my_zsh" 'https://github.com/ohmyzsh/ohmyzsh.git' \
        '8d10cc948887e3cff29923d758999afa6edf87fb' 'oh-my-zsh.sh' 'Oh My Zsh'
    ensure_repository "$plugins_root/zsh-autosuggestions" \
        'https://github.com/zsh-users/zsh-autosuggestions.git' \
        '85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5' \
        'zsh-autosuggestions.zsh' 'zsh-autosuggestions'
    ensure_repository "$plugins_root/zsh-syntax-highlighting" \
        'https://github.com/zsh-users/zsh-syntax-highlighting.git' \
        '2fc57d63067c18b1100ecdbf684fa5baf49459d1' \
        'zsh-syntax-highlighting.zsh' 'zsh-syntax-highlighting'
    ensure_repository "$plugins_root/zsh-autocomplete" \
        'https://github.com/marlonrichert/zsh-autocomplete.git' \
        'bf8db6bd4e346f55b5ad8301a028e45e615834c8' \
        'zsh-autocomplete.plugin.zsh' 'zsh-autocomplete'
    valid || die 'installed Zsh components did not pass validation'
    printf 'ZSH_SETUP=completed\nCHANGED=%s\n' "$changed"
}

case $action in
  apply) apply ;;
  validate) valid && printf 'ZSH_SETUP=valid\n' ;;
  *) printf 'usage: %s {apply|validate}\n' "$0" >&2; exit 64 ;;
esac
