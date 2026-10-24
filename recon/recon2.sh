#!/bin/sh
# Binary-level recon on volume-app — read-only, no timing needed.
exec 2>&1
B=/usr/apps/org.tizen.volume-app/bin/volume-app

echo "===== package files (full listing) ====="
find /usr/apps/org.tizen.volume-app \( -type f -o -type l \) 2>/dev/null

echo
echo "===== linked UI/graphics libs ====="
ldd $B 2>/dev/null | grep -iE 'edje|ecore|elementary|evas|efl|wayland|x11|glib'

echo
echo "===== useful tools present on TV ====="
for t in enlightenment_remote vconftool buxton2ctl input_keyevent dlogutil journalctl strings; do
  command -v $t
done

echo
echo "===== strings: config keys / tunables ====="
strings $B 2>/dev/null | grep -iE 'vconf|buxton|^db/|^memory/|timeout|duration|scale|opacity|transparen|position|geometry|width|height' | sort -u | head -80

echo
echo "===== strings: edje/theme/layout hints ====="
strings $B 2>/dev/null | grep -iE 'edje|\.edc|\.edj|theme|layout|elm_|evas' | sort -u | head -40

echo
echo "===== done ====="
