#!/bin/sh
# Runs ON the TV. Reverts tv-disable.sh: re-enable the volume OSD app.
DB=/opt/dbspace/.pkgmgr_parser.db

sqlite3 "$DB" "UPDATE package_app_info SET app_disable='false' WHERE app_id='org.tizen.volume-app';"
sqlite3 "file:$DB?mode=ro" "SELECT app_id, app_disable FROM package_app_info WHERE app_id='org.tizen.volume-app';"

echo "== done. Reboot the TV (or restart pkgmgr-info) for it to take effect =="
exit 0
