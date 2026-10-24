#!/bin/sh
# Hunt for the banner/volume vconf keys: file-backed kdb store + buxton dbs.
exec 2>&1

echo "===== kdb file backend: banner/volume keys ====="
find /opt/var/kdb -path '*banner*' 2>/dev/null | head -20
echo "--- contents of any found ---"
for f in $(find /opt/var/kdb -path '*banner*' -type f 2>/dev/null); do
  echo "$f = $(cat "$f" 2>/dev/null)"
done

echo
echo "===== kdb volume/osd-named keys anywhere ====="
find /opt/var/kdb \( -iname '*volume*' -o -iname '*osd*' \) 2>/dev/null | head -20
for f in $(find /opt/var/kdb \( -iname '*volume*' -o -iname '*osd*' \) -type f 2>/dev/null | head -20); do
  echo "$f = $(cat "$f" 2>/dev/null)"
done

echo
echo "===== buxton2 dbs: tables + banner rows ====="
for db in $(find /opt/var/lib/buxton2 -name '*.db' 2>/dev/null); do
  for t in $(sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null); do
    r=$(sqlite3 "$db" "SELECT * FROM \"$t\";" 2>/dev/null | grep -i banner | head -5)
    if [ -n "$r" ]; then
      echo "=== $db :: $t"
      echo "$r"
    fi
  done
done

echo
echo "===== uid 5001 username (for runuser route) ====="
grep ':5001:' /etc/passwd

echo
echo "===== done ====="
