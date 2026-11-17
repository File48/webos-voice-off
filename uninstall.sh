#!/bin/sh
# Remove voice-off: restore the original binaries, remove the boot hook and files.
DEST=/media/developer/voice-off
HOOK=/var/lib/webosbrew/init.d/50-voiceoff

[ "$(id -u)" = 0 ] || { echo "error: run as root"; exit 1; }

[ -x "$DEST/voice-off.sh" ] && "$DEST/voice-off.sh" stop
rm -f "$HOOK"
rm -rf "$DEST"
echo "voice-off removed (the voice app preload returns on next boot)"
