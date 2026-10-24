#!/bin/sh
# Kill test: does the OSD vanish while volume still works? Does the app respawn?
exec 2>&1

echo "=== before kill ==="
ps -ef | grep -i '[v]olume-app'

killall volume-app 2>&1
sleep 2

echo
echo "=== after kill (empty = dead) ==="
ps -ef | grep -i '[v]olume-app'

echo
echo "=== /usr/bin/true available for bind-mount? ==="
ls -l /usr/bin/true 2>&1

# window for the user to press Vol+ a few times
sleep 12

echo
echo "=== after volume presses (empty = stayed dead) ==="
ps -ef | grep -i '[v]olume-app'
