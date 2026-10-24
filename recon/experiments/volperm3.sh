#!/bin/sh
# Phase 2: the registry edit + live test. Bind is REMOVED so the test is honest.
exec 2>&1
T=/usr/apps/org.tizen.volume-app/bin/volume-app
DB=/opt/dbspace/.pkgmgr_parser.db

echo "===== [1] remove bind-mount + clean instance ====="
nsenter -t 1 -m -- umount $T 2>&1 && echo "unbound" || echo "(no bind present)"
nsenter -t 1 -m -- wc -c $T
killall -9 volume-app 2>/dev/null
sleep 1
ps -ef | grep -i '[v]olume-app'; echo "(empty above = clean)"

echo
echo "===== [2] SANITY: inject VolumeUp, expect the app to spawn ====="
input_keyevent XF86AudioRaiseVolume
sleep 3
ps -ef | grep -i '[v]olume-app' | head -3
echo "(a process above = injection + launch path working)"

echo
echo "===== [3] clean again ====="
killall -9 volume-app 2>/dev/null
sleep 1

echo
echo "===== [4] THE EDIT: app_disable=true ====="
sqlite3 $DB "UPDATE package_app_info SET app_disable='true' WHERE app_id='org.tizen.volume-app';" && echo "update committed"
echo "readback:"
sqlite3 "file:$DB?mode=ro" "SELECT app_id, app_support_disable, app_disable FROM package_app_info WHERE app_id='org.tizen.volume-app';"

echo
echo "===== [5] restart pkgmgr-info (socket-activated, safe) ====="
systemctl restart pkgmgr-info && echo "restarted"

echo
echo "===== [6] TEST: inject VolumeUp again ====="
input_keyevent XF86AudioRaiseVolume
sleep 3
echo "volume-app procs (EMPTY = disable honored):"
ps -ef | grep -i '[v]olume-app'

echo
echo "===== [7] restore user's volume level ====="
input_keyevent XF86AudioLowerVolume

echo
echo "===== done ====="
