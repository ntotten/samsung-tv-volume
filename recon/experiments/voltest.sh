#!/bin/sh
# vconf read + kill test for the volume banner, CEC path.
exec 2>&1

echo "===== current vconf banner values ====="
for k in banner/volume/show_mode banner/mute/show_mode banner/volume/speaker \
         banner/volume/is_microphone banner/volume/current_number \
         banner/volume/ext_speaker_name \
         memory/mledmultiview/control_state_volume_osd \
         memory/menu/sound/musictv_volume_settings; do
  echo "--- $k"
  vconftool get -t int "$k" 2>&1
  vconftool get -t bool "$k" 2>&1
  vconftool get -t string "$k" 2>&1
done

echo
echo "===== killing volume-app ====="
killall volume-app 2>&1
sleep 2
echo "after kill (empty = dead):"
ps -ef | grep -i '[v]olume-app'

echo
echo "===== /usr/bin/true present (for bind-mount option)? ====="
ls -l /usr/bin/true 2>&1

echo
echo ">>> 12s window: press VOLUME on the APPLE TV remote now <<<"
sleep 12

echo
echo "===== after presses (empty = stayed dead) ====="
ps -ef | grep -i '[v]olume-app'
