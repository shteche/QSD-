#!/system/bin/sh

. /data/adb/QSD++/common/util_verify.sh

FILES_TO_VERIFY=(
  "META-INF/com/google/android/update-binary"
  "scripts/post-fs-data.sh"
  "scripts/service.sh"
)

for FILE in "${FILES_TO_VERIFY[@]}"; do
  verify_file "$ZIPFILE" "$FILE"
done
