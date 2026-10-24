#!/bin/sh
# Runs ON the TV (piped to `sh` over the samsung-tv-root archive-root agent).
# Idempotent: if the bind-mount exists, do nothing.
#
# What it does: bind-mounts /usr/bin/true over the volume OSD app's binary,
# inside the SYSTEM mount namespace (pid 1's), then kills any resident
# instance. The app framework relaunches volume-app on every volume key
# event; the bind makes that launch exec a no-op binary, so the banner never
# draws. The actual volume change (incl. HDMI-CEC passthrough to a receiver)
# happens in the audio middleware, not this app, and is unaffected.
#
# Volatile by design: the mount lives in the kernel mount table only. A TV
# reboot returns everything to stock; nothing is written to the TV's flash.

T=/usr/apps/org.tizen.volume-app/bin/volume-app

if nsenter -t 1 -m -- mount | grep -q "$T"; then
  exit 0
fi

nsenter -t 1 -m -- mount --bind /usr/bin/true "$T"
killall -9 volume-app 2>/dev/null || true
exit 0
