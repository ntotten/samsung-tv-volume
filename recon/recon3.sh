#!/bin/sh
# Identify the app-pool parent (pid 344) and map the launch machinery.
exec 2>&1

echo "===== pid 344 identity ====="
tr '\0' ' ' < /proc/344/cmdline 2>/dev/null; echo
ls -l /proc/344/exe 2>/dev/null
cat /proc/344/comm 2>/dev/null

echo
echo "===== does 344 have volume-app mapped? ====="
grep -i volume /proc/344/maps 2>/dev/null | head -10

echo
echo "===== current children of 344 ====="
ps -ef | awk '$3 == 344'

echo
echo "===== what volume-app itself has mapped (first 15 paths) ====="
for p in $(ps -ef | awk '/[v]olume-app/{print $2}'); do
  echo "--- pid $p"
  grep -oE '/[^ ]+\.(so[.0-9]*|wgt|app|bin/[a-z-]+)' /proc/$p/maps 2>/dev/null | sort -u | grep -iE 'volume|appfw|aul' | head -15
done

echo
echo "===== who is 344's parent / what else does 344 spawn? ====="
ps -ef | awk '$2 == 344 || $3 == 344' | awk '{print $2, $3, $8}' | head -30

echo
echo "===== prelaunch config mentions ====="
ls /etc/ 2>/dev/null | grep -iE 'aul|launch|preload'
grep -l 'volume-app' /etc/*.conf /etc/launch* 2>/dev/null

echo
echo "===== package manager / privilege tools available ====="
for t in pkgcmd pkginfo su setpriv runuser sudo sqlite3; do command -v $t; done

echo
echo "===== done ====="
