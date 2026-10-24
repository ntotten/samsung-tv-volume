#!/bin/sh
# Round 2: verify bind redirection, SIGKILL resident app, then test presses.
exec 2>&1

echo "===== bind status (re-apply if missing) ====="
mount | grep volume-app || mount --bind /usr/bin/true /usr/apps/org.tizen.volume-app/bin/volume-app
mount | grep volume-app

echo
echo "===== exec redirection proof (both should be 9776) ====="
wc -c /usr/bin/true /usr/apps/org.tizen.volume-app/bin/volume-app

echo
echo "===== SIGKILL resident volume-app ====="
killall -9 volume-app 2>&1
sleep 2
echo "procs now (MUST be empty):"
ps -ef | grep -i '[v]olume-app'

echo
echo ">>> 15s window: press VOLUME on the APPLE TV remote now <<<"
sleep 20

echo
echo "===== after presses ====="
echo "volume-app procs (empty = win):"
ps -ef | grep -i '[v]olume-app'
echo "true churn count (low and stable = fine):"
ps -ef | grep -c '[/]usr/bin/true'
echo "bind still in place:"
mount | grep volume-app
