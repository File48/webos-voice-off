#!/bin/sh
# Install voice-off on a rooted webOS TV. Run on the TV as root from the repo folder.
#   sh install.sh          -> install files only (test with voice-off.sh start)
#   sh install.sh --boot   -> also install the Homebrew Channel startup hook
set -e

SRC=$(cd "$(dirname "$0")" && pwd)
DEST=/media/developer/voice-off
HOOKDIR=/var/lib/webosbrew/init.d
HOOK=$HOOKDIR/50-voiceoff

[ "$(id -u)" = 0 ] || { echo "error: run as root"; exit 1; }
[ -d /var/lib/webosbrew ] || { echo "error: Homebrew Channel (rooted) not found"; exit 1; }

mkdir -p "$DEST"
if [ "$SRC" != "$DEST" ]; then
    cp "$SRC/voice-off.sh" "$SRC/stub" "$SRC/lsnull" "$DEST/"
fi
chmod 755 "$DEST/voice-off.sh" "$DEST/stub" "$DEST/lsnull"
echo "installed to $DEST"

if [ "$1" = "--boot" ]; then
    mkdir -p "$HOOKDIR"
    cp "$SRC/50-voiceoff" "$HOOK"
    chmod 755 "$HOOK"
    echo "boot hook installed: $HOOK"
fi
