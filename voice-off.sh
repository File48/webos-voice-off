#!/bin/sh
# voice-off: replace LG's voice stack with a no-op stub.
# RAM-only: bind-mounts over the binaries, nothing written to system partitions.
# Usage: voice-off.sh start|stop|status

DIR=/media/developer/voice-off
STUB=$DIR/stub
LOG=$DIR/voice-off.log

# systemd-launched (Type=static); Restart=on-failure, so a clean stop stays stopped
UNITS="voiceinput.service voiceconductor.service"

BINS="/usr/sbin/voiceinput
/usr/sbin/voiceconductor
/usr/sbin/voiceinput_preprocessor
/usr/sbin/voiceinput_sound
/usr/sbin/voiceinput_hidraw
/usr/sbin/voiceinput_network
/usr/sbin/voiceclick
/usr/sbin/nlpmanager
/usr/sbin/trigger_thinq
/usr/sbin/trigger_alexa
/usr/bin/com.webos.app.voice"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
mounted() { grep -q " $1 " /proc/mounts; }

start() {
    # 1. stub first, so anything that respawns gets the no-op
    for b in $BINS; do
        if [ ! -e "$b" ]; then log "skip missing $b"; continue; fi
        if mounted "$b"; then continue; fi
        if mount --bind "$STUB" "$b"; then log "stubbed $b"; else log "FAILED to stub $b"; fi
    done

    # 2. close the preloaded voice app (preloadType oneshot, so it won't be re-preloaded)
    luna-send -w 3000 -n 1 luna://com.webos.service.applicationManager/closeByAppId \
        '{"id":"com.webos.app.voice"}' >/dev/null 2>&1

    # 3. stop systemd-managed ones cleanly, kill the bus-activated rest
    systemctl stop $UNITS
    # voiceinput exits 254 on SIGTERM; clear the cosmetic "failed" state
    systemctl reset-failed $UNITS 2>/dev/null
    for b in $BINS; do
        n=$(basename "$b")
        p=$(pidof "$n") && kill $p && log "killed $n ($p)"
    done
    log "start done"
}

stop() {
    for b in $BINS; do
        if mounted "$b"; then
            if umount "$b"; then log "restored $b"; else log "FAILED to restore $b"; fi
        fi
    done
    systemctl start $UNITS
    log "stop done (bus-activated services return on demand; voice app preload returns next boot)"
}

status() {
    echo "stubbed:"
    for b in $BINS; do mounted "$b" && echo "  $b"; done
    echo "running:"
    for b in $BINS; do
        n=$(basename "$b")
        p=$(pidof "$n") && echo "  $n $p"
    done
    for u in $UNITS; do echo "$u: $(systemctl is-active $u)"; done
}

case "$1" in
    start) start ;;
    stop) stop ;;
    status) status ;;
    *) echo "usage: $0 start|stop|status"; exit 1 ;;
esac
