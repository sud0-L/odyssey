#!/usr/bin/env bash
set -euo pipefail

expected=${1:-}
[[ $expected == /* ]] || {
    printf 'expected odyssey launcher path is invalid\n' >&2
    exit 64
}

resolved=$(command -v odyssey 2>/dev/null || true)
if [[ -z $resolved ]]; then
    printf 'odyssey is installed at %s but is not available on PATH; add %s to PATH, start a new shell, and rerun ./install.sh\n' \
        "$expected" "$(dirname -- "$expected")" >&2
    exit 1
fi

expected_target=$(readlink -f -- "$expected" 2>/dev/null || true)
resolved_target=$(readlink -f -- "$resolved" 2>/dev/null || true)
if [[ -z $expected_target || $resolved_target != "$expected_target" ]]; then
    printf 'odyssey resolves to %s instead of the installed launcher %s; correct PATH ordering and rerun ./install.sh\n' \
        "$resolved" "$expected" >&2
    exit 1
fi
