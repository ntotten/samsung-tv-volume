#!/bin/sh
# Mount-namespace membership: is our bind visible to the app launcher?
exec 2>&1

echo "===== mount namespace ids ====="
echo -n "pid 1 (system):  "; readlink /proc/1/ns/mnt
echo -n "pool (344):      "; readlink /proc/344/ns/mnt
echo -n "this root cmd:   "; readlink /proc/self/ns/mnt
for p in $(ps -ef | awk '/[v]olume-app/{print $2}'); do
  echo -n "volume-app $p: "; readlink /proc/$p/ns/mnt
done

echo
echo "===== nsenter available? ====="
command -v nsenter

echo
echo "===== bind visible in pid 1's view? ====="
nsenter -t 1 -m -- wc -c /usr/apps/org.tizen.volume-app/bin/volume-app 2>&1 || cat /proc/1/mounts | grep volume-app

echo
echo "===== pool processes right now ====="
ps -ef | grep -E 'process-pool|launchpad' | grep -v grep | awk '{print $2, $3, $8, $9}'

echo
echo "===== /etc/aul contents (preload config?) ====="
ls -la /etc/aul/ 2>/dev/null
grep -ri volume /etc/aul/ 2>/dev/null | head -5

echo
echo "===== cleanup: stray dlogutil ====="
killall -9 dlogutil 2>&1; echo "killed (or none)"

echo
echo "===== done ====="
