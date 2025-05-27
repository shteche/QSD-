#!/system/bin/sh

rm -f /data/local/tmp/QSD++

find /data/dalvik-cache/ -type f \( -name "*.vdex" -o -name "*.odex" -o -name "*.art" \) -exec rm -f {} + >/dev/null 2>&1
find /data/user_de -type f -name '*shaders_cache*' -exec rm -f {} + >/dev/null 2>&1
find /data -type f -name '*shader*' -exec rm -f {} + >/dev/null 2>&1

for key in \
  "global:auto_sync" "global:hotword_detection_enabled" "global:activity_starts_logging_enabled" \
  "secure:adaptive_sleep" "secure:screensaver_enabled" "secure:send_action_app_error" \
  "system:motion_engine" "system:master_motion" "system:air_motion_engine" \
  "system:air_motion_wake_up" "system:send_security_reports" "system:intelligent_sleep_mode"
do
  IFS=":" read -r type name <<< "$key"
  settings delete "$type" "$name" >/dev/null 2>&1
done

