#!/bin/sh
# Captures system logs while the volume OSD is on screen.
# USER ACTION: press Enter on the Mac, count to ~3, then press Vol+ 3 times on the remote.
exec 2>&1

if command -v dlogutil >/dev/null 2>&1; then
  echo "logger: dlogutil"
  dlogutil -v time > /run/vol.log 2>&1 &
else
  echo "logger: journalctl"
  journalctl -f --no-pager > /run/vol.log 2>&1 &
fi
LP=$!
sleep 20
kill $LP 2>/dev/null

echo "--- lines mentioning volume/osd/sound/audio ---"
grep -iE 'volume|osd|sound|audio' /run/vol.log | head -50

echo
echo "--- busiest log tags during the window (the OSD app should be near the top) ---"
awk '{print $3}' /run/vol.log | sort | uniq -c | sort -rn | head -25
