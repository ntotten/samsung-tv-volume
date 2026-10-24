#!/bin/sh
# Package-registry recon: does this build's pkgmgr DB have a disable concept?
# Read-only throughout.
exec 2>&1

echo "===== pkgmgr / appsvc db files ====="
ls -la /opt/dbspace/ 2>/dev/null | grep -iE 'pkg|app'
ls -la /opt/dbspace/user/5001/ 2>/dev/null

echo
echo "===== pkgcmd -l entry for volume-app (does list show state?) ====="
pkgcmd -l 2>/dev/null | grep -i volume

echo
echo "===== pkgmgr db tables ====="
for db in $(ls /opt/dbspace/.pkgmgr*.db /opt/dbspace/user/5001/.pkgmgr*.db 2>/dev/null); do
  echo "=== $db"
  sqlite3 "file:$db?mode=ro" "SELECT name FROM sqlite_master WHERE type='table';" 2>&1 | head -30
done

echo
echo "===== columns mentioning disable/enable/state/block ====="
for db in $(ls /opt/dbspace/.pkgmgr*.db /opt/dbspace/user/5001/.pkgmgr*.db 2>/dev/null); do
  for t in $(sqlite3 "file:$db?mode=ro" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null); do
    cols=$(sqlite3 "file:$db?mode=ro" "PRAGMA table_info($t);" 2>/dev/null | grep -iE 'disab|enabl|state|block')
    if [ -n "$cols" ]; then
      echo "--- $db :: $t"
      echo "$cols"
    fi
  done
done

echo
echo "===== volume-app rows in pkgmgr tables ====="
for db in $(ls /opt/dbspace/.pkgmgr*.db /opt/dbspace/user/5001/.pkgmgr*.db 2>/dev/null); do
  for t in $(sqlite3 "file:$db?mode=ro" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null); do
    r=$(sqlite3 "file:$db?mode=ro" "SELECT * FROM \"$t\";" 2>/dev/null | grep -i 'volume-app' | head -3)
    if [ -n "$r" ]; then
      echo "--- $db :: $t"
      echo "$r"
    fi
  done
done

echo
echo "===== input_keyevent usage ====="
input_keyevent 2>&1 | head -10

echo
echo "===== pkgmgr-info service state ====="
systemctl status pkgmgr-info --no-pager 2>&1 | head -6

echo
echo "===== done ====="
