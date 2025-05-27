#!/system/bin/sh

TMPDIR_FOR_VERIFY="${TMPDIR:-/dev/tmp}/.verify"
mkdir -p "$TMPDIR_FOR_VERIFY"

ui_print() {
  echo "$1"
}

abort_verify() {
  ui_print "*********************************************************"
  ui_print "! $1"
  ui_print "! 模块可能已损坏, 请重新下载"
  exit 1
}

verify_file() {
  zip="$1"
  file="$2"

  base=$(basename "$file")
  target="$TMPDIR_FOR_VERIFY/$base"
  hash="$target.sha256"

  unzip -o "$zip" "$file" -d "$TMPDIR_FOR_VERIFY" >/dev/null 2>&1 || abort_verify "$file not found"
  unzip -o "$zip" "$file.sha256" -d "$TMPDIR_FOR_VERIFY" >/dev/null 2>&1 || abort_verify "$file.sha256 missing"

  sha256sum -c "$hash" --status || abort_verify "$file failed integrity check"
  ui_print "- Verified $file"
}
