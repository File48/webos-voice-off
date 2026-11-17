# webos-voice-off

Disables LG's voice stack on a rooted webOS TV by replacing its binaries with a no-op stub through RAM-only bind mounts. Nothing is written to system partitions, and a reboot without the startup hook restores stock behaviour.

## Why

On a webOS 24 TV with voice never used, the voice services were the largest steady CPU consumer at idle:

| Process | CPU time over 6 h uptime |
|---|---|
| `voiceinput_preprocessor` | ~93 min (12–16% when sampled) |
| `trigger_thinq` | ~50 min |
| `voiceinput_sound` | ~26 min |
| `com.webos.app.voice` | ~15 min |

That's roughly a quarter of one core used constantly. Only three of the four cores were online on the test TV.

**Be realistic about the gain.** The test TV was otherwise mostly idle and showed no memory pressure (PSI memory 0, no swap in/out). Removing the voice stack doesn't make the UI noticeably faster. You get less background CPU and wakeups, about 60–80 MB of RAM back, and LG's microphone and assistant pipeline (including the Alexa and ThinQ triggers) out of the picture.

## What it disables

| Binary | Started by |
|---|---|
| `/usr/sbin/voiceinput` | systemd (`voiceinput.service`) |
| `/usr/sbin/voiceconductor` | systemd (`voiceconductor.service`) |
| `/usr/sbin/voiceinput_preprocessor` | luna bus (on demand) |
| `/usr/sbin/voiceinput_sound` | luna bus |
| `/usr/sbin/voiceinput_hidraw` | luna bus |
| `/usr/sbin/voiceinput_network` | luna bus |
| `/usr/sbin/voiceclick` | luna bus |
| `/usr/sbin/nlpmanager` | luna bus |
| `/usr/sbin/trigger_thinq` | luna bus |
| `/usr/sbin/trigger_alexa` | luna bus |
| `/usr/bin/com.webos.app.voice` | SAM (preloaded once by preloadmanager) |

How it works:
1. It bind-mounts `stub` (`exit 0`) over each binary first, so anything respawned by systemd, the luna hub or SAM runs the no-op.
2. It closes the preloaded voice app and stops the two systemd units cleanly. `Restart=on-failure` doesn't fire after a manual stop.
3. It kills the remaining bus-activated processes.

**What you lose:** the remote's mic button and all voice and assistant features.

**What still works on the test TV:** Magic Remote pointer and D-pad, Home, input switching (HDMI), app playback including passthrough audio, and AirPlay.

## Requirements

- A rooted LG webOS TV with [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel) and SSH
- Tested on an LG C2 OLED, webOS 24 (9.2.2), software 23.25.55. Other versions may use different binary names. The script skips any binary that's missing.

## Install

Copy the repo to the TV and test without the boot hook first:

```sh
scp -r webos-voice-off root@TV_IP:/tmp/
ssh root@TV_IP 'sh /tmp/webos-voice-off/install.sh && /media/developer/voice-off/voice-off.sh start && /media/developer/voice-off/voice-off.sh status'
```

Use the TV for a while. If everything you use still works, enable it at boot:

```sh
ssh root@TV_IP 'sh /tmp/webos-voice-off/install.sh --boot'
```

The hook runs from Homebrew Channel's startup script, which runs `/var/lib/webosbrew/init.d/*`. That's after core boot, so the voice services start briefly and are then stopped.

## Use

```sh
/media/developer/voice-off/voice-off.sh status   # what's stubbed / still running
/media/developer/voice-off/voice-off.sh stop     # restore originals now
cat /media/developer/voice-off/voice-off.log     # actions log
```

To skip one boot, create the `disabled` file:

```sh
touch /media/developer/voice-off/disabled
```

## Uninstall

```sh
ssh root@TV_IP 'sh /tmp/webos-voice-off/uninstall.sh'
```

## Notes

- `voiceinput` exits with status 254 on SIGTERM. The script runs `systemctl reset-failed` so the unit shows `inactive` instead of `failed`.
- Bus-activated services come back on demand after `stop`. The voice app preload comes back on the next boot.

## Disclaimer

Use at your own risk. Rooting and modifying your TV may void the warranty. This project isn't affiliated with LG Electronics.
