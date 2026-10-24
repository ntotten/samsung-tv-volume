#!/bin/sh
# Phase 1: consistent backups + exact schema. No modifications anywhere.
exec 2>&1
B=/home/owner/share/tmp/sdk_tools/pkgbackup
DB=/opt/dbspace/.pkgmgr_parser.db
UDB=/opt/dbspace/user/5001/.pkgmgr_parser.db

echo "===== backups (sqlite .backup = consistent online snapshots) ====="
mkdir -p $B
sqlite3 "file:$DB?mode=ro" ".backup $B/pkgmgr_parser.db.before" && echo "global pkgmgr db backed up"
sqlite3 "file:$UDB?mode=ro" ".backup $B/user5001_pkgmgr_parser.db.before" && echo "user pkgmgr db backed up"
sqlite3 "file:/opt/dbspace/user/5001/.appsvc.db?mode=ro" ".backup $B/appsvc.db.before" && echo "appsvc db backed up"
ls -la $B

echo
echo "===== schema: package_app_info (columns + defaults) ====="
sqlite3 "file:$DB?mode=ro" "PRAGMA table_info(package_app_info);"

echo
echo "===== schema: package_app_info_for_uid + all current rows ====="
sqlite3 "file:$DB?mode=ro" "PRAGMA table_info(package_app_info_for_uid);"
echo "--- global rows:"
sqlite3 "file:$DB?mode=ro" "SELECT * FROM package_app_info_for_uid;" | head -10
echo "--- user-db rows:"
sqlite3 "file:$UDB?mode=ro" "SELECT * FROM package_app_info_for_uid;" | head -10

echo
echo "===== package_info tail columns ====="
sqlite3 "file:$DB?mode=ro" "PRAGMA table_info(package_info);"

echo
echo "===== current volume-app app_disable values ====="
sqlite3 "file:$DB?mode=ro" "SELECT app_id, app_support_disable, app_disable FROM package_app_info WHERE app_id='org.tizen.volume-app';"
sqlite3 "file:$DB?mode=ro" "SELECT package_name, package_support_disable, package_disable FROM package_info WHERE package_name='org.tizen.volume-app';"

echo
echo "===== done ====="
