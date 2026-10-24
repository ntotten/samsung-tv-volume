#!/bin/sh
# macOS setup: writes config.env and installs a per-user launchd watchdog
# that re-applies the bind every 180 seconds (no-op unless the TV rebooted).
#
#   TV_IP=192.168.1.50 ./install.sh
#
# Linux: no installer here — put watch.sh on a cron/systemd timer instead
# (see README "Persistence").
set -eu
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

: "${TV_IP:?usage: TV_IP=<tv LAN ip> ./install.sh}"
ROOT_TOOL="${ROOT_TOOL:-$PWD/tool/samsung-tv-root}"
SDB="${SDB:-$PWD/tool/sdb}"

[ -x "$ROOT_TOOL" ] || { echo "error: $ROOT_TOOL missing — see README step 2"; exit 1; }
[ -x "$SDB" ] || { echo "error: $SDB missing — see README step 2"; exit 1; }

printf 'TV_IP=%s\nROOT_TOOL=%s\nSDB=%s\n' "$TV_IP" "$ROOT_TOOL" "$SDB" >config.env
echo "wrote config.env"

LABEL=net.samsungtv.volume
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
sed -e "s|@WATCH_SH@|$PWD/watch.sh|g" -e "s|@LOG@|$PWD/watch.log|g" \
  "launchd/$LABEL.plist.template" >"$PLIST_DST"
UID_=$(id -u)
launchctl bootout "gui/$UID_/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_" "$PLIST_DST"
echo "watchdog installed: $LABEL (every 180s, log: $PWD/watch.log)"
