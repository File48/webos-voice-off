#!/bin/sh
# voice-off: replace LG's voice stack with no-op stand-ins.
# RAM-only: bind-mounts over the binaries, nothing written to system partitions.
# Usage: voice-off.sh start|stop|status

DIR=/media/developer/voice-off
STUB=$DIR/stub
LSNULL=$DIR/lsnull
LOG=$DIR/voice-off.log

# systemd-launched (Type=static on the bus, Restart=on-failure).
# The bus holds calls to a static service until it registers, so a plain stub
# makes callers hang (e.g. Settings waits ~8 s). These get lsnull instead: it
# registers their bus names and every call fails immediately with "Unknown method".
UNITS="voiceinput.service voiceconductor.service"
RESPONDERS="/usr/sbin/voiceinput
/usr/sbin/voiceconductor"

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
is_responder() { echo "$RESPONDERS" | grep -qx "$1"; }

# which file should cover $1
target_for() {
    if is_responder "$1" && [ -x "$LSNULL" ]; then echo "$LSNULL"; else echo "$STUB"; fi
}

start() {
    # 1. stop the systemd units first, so their binaries aren't busy and nothing
    #    real is left running behind a new mount
    systemctl stop $UNITS
    # voiceinput exits 254 on SIGTERM; clear the cosmetic "failed" state
    systemctl reset-failed $UNITS 2>/dev/null

    # 2. cover every binary with its stand-in (fix up an older stub mount on responders)
    for b in $BINS; do
        if [ ! -e "$b" ]; then log "skip missing $b"; continue; fi
        t=$(target_for "$b")
        if mounted "$b"; then
            [ "$b" -ef "$t" ] && continue
            umount "$b" || { log "FAILED to replace mount on $b"; continue; }
        fi
        if mount --bind "$t" "$b"; then log "covered $b with $(basename "$t")"; else log "FAILED to cover $b"; fi
    done

    # 3. close the preloaded voice app (preloadType oneshot, so it won't be re-preloaded)
    luna-send -w 3000 -n 1 luna://com.webos.service.applicationManager/closeByAppId \
        '{"id":"com.webos.app.voice"}' >/dev/null 2>&1

    # 4. kill bus-activated leftovers still running the original code
    for b in $BINS; do
        is_responder "$b" && continue
        n=$(basename "$b")
        p=$(pidof "$n") && kill $p && log "killed $n ($p)"
    done

    # 5. bring the units back up running lsnull (if it's installed)
    if [ -x "$LSNULL" ]; then
        systemctl start $UNITS && log "units started on lsnull" || log "FAILED to start units on lsnull"
    fi
    log "start done"
}

stop() {
    # units first, so lsnull isn't holding its mounts busy
    systemctl stop $UNITS
    systemctl reset-failed $UNITS 2>/dev/null
    for b in $BINS; do
        if mounted "$b"; then
            if umount "$b"; then log "restored $b"; else log "FAILED to restore $b"; fi
        fi
    done
    systemctl start $UNITS
    log "stop done (bus-activated services return on demand; voice app preload returns next boot)"
}

status() {
    echo "covered:"
    for b in $BINS; do
        mounted "$b" || continue
        if [ "$b" -ef "$LSNULL" ]; then w=lsnull; elif [ "$b" -ef "$STUB" ]; then w=stub; else w=other; fi
        echo "  $b ($w)"
    done
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
