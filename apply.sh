#!/bin/sh
# One-shot apply + verify, for humans. Safe to re-run. Unlike watch.sh this
# does not gate on the debug port, so failures are visible.
set -u
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/config.env" ] && . "$SCRIPT_DIR/config.env"

: "${TV_IP:?TV_IP not set}"
: "${ROOT_TOOL:?ROOT_TOOL not set}"
: "${SDB:?SDB not set}"

B64=$(base64 <"$SCRIPT_DIR/tv-apply.sh" | tr -d '\n')
"$ROOT_TOOL" --sdb "$SDB" archive-root root "$TV_IP" \
  --command "echo $B64 | base64 -d | sh"

"$ROOT_TOOL" --sdb "$SDB" archive-root root "$TV_IP" \
  --command 'nsenter -t 1 -m -- mount | grep volume-app >/dev/null && echo "VOLUME OSD: DISABLED (bind active)" || echo "VOLUME OSD: STILL ACTIVE (bind missing)"'
