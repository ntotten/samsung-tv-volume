#!/bin/sh
# Bind-mount /usr/bin/true over volume-app so every per-press launch execs a no-op.
# Volatile: lives in the kernel mount table only; a reboot removes it.
exec 2>&1

echo "===== applying bind-mount ====="
mount --bind /usr/bin/true /usr/apps/org.tizen.volume-app/bin/volume-app && echo "bind OK" || echo "bind FAILED"
mount | grep volume-app

echo
echo "===== killing resident instance ====="
killall volume-app 2>&1
sleep 1
echo "volume-app procs (empty = dead):"
ps -ef | grep -i '[v]olume-app'

echo
echo ">>> 15s window: press VOLUME on the APPLE TV remote now <<<"
sleep 15

echo
echo "===== after presses ====="
echo "volume-app procs (empty = good):"
ps -ef | grep -i '[v]olume-app'
echo "true-process count (should be 0-1, not climbing):"
ps -ef | grep -c '[/]usr/bin/true'
echo "bind still in place:"
mount | grep volume-app
