#!/bin/sh
# Volume OSD recon on the S90D — read-only, no timing needed.
exec 2>&1

echo "===== [1] processes matching volume/osd ====="
ps -ef | grep -iE 'volume|osd|indicator|hud' | grep -v grep

echo
echo "===== [2] cmdline + exe path for the suspects ====="
for p in $(ps -ef | grep -iE '[v]olume|[o]sd' | awk '{print $2}'); do
  echo "--- pid $p ---"
  tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null; echo
  readlink /proc/$p/exe 2>/dev/null
done

echo
echo "===== [3] candidate packages in /usr/apps ====="
ls /usr/apps | grep -iE 'volume|osd|sound|menu|hud'

echo
echo "===== [4] contents of those packages (looking for .edj vs .html/.js/.css) ====="
for d in /usr/apps/*olume* /usr/apps/*[Oo][Ss][Dd]* /usr/apps/*sound*; do
  if [ -d "$d" ]; then
    echo "## $d"
    find "$d" -maxdepth 3 -type f 2>/dev/null | head -60
  fi
done

echo
echo "===== [5] any systemd unit for them? ====="
systemctl list-unit-files --no-pager 2>/dev/null | grep -iE 'vol|osd|sound'

echo
echo "===== done ====="
