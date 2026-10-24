#!/bin/sh
# Host wrapper: apply the PERMANENT registry disable on the TV.
# Same transport as apply.sh. Config via environment or config.env.
set -u
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/config.env" ] && . "$SCRIPT_DIR/config.env"

: "${TV_IP:?TV_IP not set}"
: "${ROOT_TOOL:?ROOT_TOOL not set}"
: "${SDB:?SDB not set}"

B64=$(base64 <"$SCRIPT_DIR/tv-disable.sh" | tr -d '\n')
"$ROOT_TOOL" --sdb "$SDB" archive-root root "$TV_IP" \
  --command "echo $B64 | base64 -d | sh"
