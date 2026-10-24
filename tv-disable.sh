#!/bin/sh
# Runs ON the TV (piped to `sh` over the samsung-tv-root archive-root agent).
#
# PERMANENT method: flag the volume OSD app as disabled in the package
# registry (/opt/dbspace/.pkgmgr_parser.db). The app framework then refuses
# to launch it on volume events, so the banner never draws. Survives reboots
# (verified across a full power cycle). The registry lives on flash; nothing
# else is modified.
#
# A consistent snapshot of the registry DB is taken first. Revert at any time
# with tv-restore.sh (or by restoring the snapshot).
#
# Caveat: a firmware update regenerates the registry from package manifests
# and will likely reset this flag (re-run this script after an update, if the
# foothold still works on the new firmware).

DB=/opt/dbspace/.pkgmgr_parser.db
B=/home/owner/share/pkgbackup
T=/usr/apps/org.tizen.volume-app/bin/volume-app

echo "== snapshot registry =="
mkdir -p "$B"
sqlite3 "file:$DB?mode=ro" ".backup $B/pkgmgr_parser.db.before-disable"
ls -la "$B"

echo "== set app_disable=true =="
sqlite3 "$DB" "UPDATE package_app_info SET app_disable='true' WHERE app_id='org.tizen.volume-app';"

echo "== readback (want: true) =="
sqlite3 "file:$DB?mode=ro" "SELECT app_id, app_disable FROM package_app_info WHERE app_id='org.tizen.volume-app';"

echo "== clear any volatile bind + resident instance =="
nsenter -t 1 -m -- umount "$T" 2>/dev/null
killall -9 volume-app 2>/dev/null

echo "== done. If the OSD still shows on the next press, reboot the TV once =="
exit 0
