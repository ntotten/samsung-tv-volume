#!/bin/sh
# Round 3: bind-mount inside the SYSTEM mount namespace (pid 1), SIGKILL, test.
exec 2>&1
T=/usr/apps/org.tizen.volume-app/bin/volume-app

echo "===== apply bind in SYSTEM namespace ====="
nsenter -t 1 -m -- mount --bind /usr/bin/true $T && echo "bind OK" || echo "bind FAILED"

echo
echo "===== verify from SYSTEM view (want 9776) ====="
nsenter -t 1 -m -- wc -c $T

echo
echo "===== SIGKILL resident instance ====="
killall -9 volume-app 2>&1
sleep 2
echo "procs (MUST be empty):"
ps -ef | grep -i '[v]olume-app'

echo
echo ">>> 20s window: press VOLUME on the APPLE TV remote now <<<"
sleep 20

echo
echo "===== after presses ====="
echo "volume-app procs (empty = WIN):"
ps -ef | grep -i '[v]olume-app'
echo "true churn (0-1 = fine):"
ps -ef | grep -c '[/]usr/bin/true'
echo "bind still in place (system view):"
nsenter -t 1 -m -- mount | grep volume-app
echo "any new app namespace got the bind?"
for p in $(ps -ef | awk '/[v]olume-app/{print $2}'); do
  echo -n "pid $p ns: "; readlink /proc/$p/ns/mnt
  nsenter -t $p -m -- wc -c $T 2>&1
done
