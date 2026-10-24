#!/bin/sh
# Host-side watchdog: keep the volume-OSD bind-mount applied on the TV.
# Exits 0 silently when the bind is already in place or the TV is off.
#
# Configuration via environment (or a config.env next to this script):
#   TV_IP      LAN IP of the TV (DHCP reservation recommended)
#   ROOT_TOOL  path to the samsung-tv-root executable
#   SDB        path to Samsung's sdb executable
set -u
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/config.env" ] && . "$SCRIPT_DIR/config.env"

: "${TV_IP:?TV_IP not set}"
: "${ROOT_TOOL:?ROOT_TOOL not set}"
: "${SDB:?SDB not set}"

# Port 26101 is Samsung's debug bridge (sdbd), open only while the TV is on
# with Developer Mode enabled. Closed => nothing to do this interval.
if [ "$(uname -s)" = "Darwin" ]; then
  nc -z -G 3 "$TV_IP" 26101 >/dev/null 2>&1 || exit 0
else
  nc -z -w 3 "$TV_IP" 26101 >/dev/null 2>&1 || exit 0
fi

B64=$(base64 <"$SCRIPT_DIR/tv-apply.sh" | tr -d '\n')
exec "$ROOT_TOOL" --sdb "$SDB" archive-root root "$TV_IP" \
  --command "echo $B64 | base64 -d | sh"
