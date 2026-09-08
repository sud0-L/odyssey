#!/usr/bin/env bash
set -euo pipefail

state=${1:-}

case $state in
    connected)
        event=message-new-instant
        sound_file=/usr/share/sounds/freedesktop/stereo/message-new-instant.oga
        ;;
    disconnected)
        event=message
        sound_file=/usr/share/sounds/freedesktop/stereo/message.oga
        ;;
    *)
        exit 64
        ;;
esac

if [[ -r $sound_file ]] && command -v pw-play >/dev/null 2>&1; then
    pw-play "$sound_file" >/dev/null 2>&1 || true
elif [[ -r $sound_file ]] && command -v paplay >/dev/null 2>&1; then
    paplay "$sound_file" >/dev/null 2>&1 || true
elif command -v canberra-gtk-play >/dev/null 2>&1; then
    canberra-gtk-play --id="$event" --description="Odyssey power $state" \
        >/dev/null 2>&1 || true
fi
