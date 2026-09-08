#!/usr/bin/env bash
# Verify every native library in a built artifact is 16 KB page aligned.
#
# Google Play requires 16 KB alignment for apps shipping native code. Flutter's
# own engine libraries and the plugin .so files all have to pass. Run this
# against a release build before every upload:
#
#   tool/check_16kb_alignment.sh build/app/outputs/bundle/release/app-release.aab
#   tool/check_16kb_alignment.sh build/app/outputs/flutter-apk/app-release.apk
#
set -euo pipefail

ARTIFACT="${1:-build/app/outputs/flutter-apk/app-release.apk}"
[ -f "$ARTIFACT" ] || { echo "No such artifact: $ARTIFACT" >&2; exit 1; }

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$LOCALAPPDATA/Android/Sdk}}"
READELF="$(find "$SDK/ndk" -name 'llvm-readelf*' -path '*/bin/*' 2>/dev/null | sort | tail -1)"
[ -n "$READELF" ] || { echo "llvm-readelf not found under $SDK/ndk" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
unzip -q -o "$ARTIFACT" -d "$WORK"

fail=0
found=0
while IFS= read -r lib; do
  found=$((found + 1))
  # Every PT_LOAD segment must be aligned to at least 0x4000 (16 KB).
  bad="$("$READELF" -lW "$lib" | awk '$1 == "LOAD" { print $NF }' \
        | grep -vE '0x(4000|8000|10000|20000)$' || true)"
  if [ -n "$bad" ]; then
    echo "  NOT ALIGNED  ${lib#$WORK/}  (found: $(echo "$bad" | tr '\n' ' '))"
    fail=1
  else
    echo "  ok           ${lib#$WORK/}"
  fi
done < <(find "$WORK" -name '*.so' | sort)

echo
if [ "$found" -eq 0 ]; then
  echo "No native libraries found in $ARTIFACT - nothing to check."
elif [ "$fail" -eq 0 ]; then
  echo "PASS: all $found native libraries are 16 KB aligned."
else
  echo "FAIL: at least one library is not 16 KB aligned." >&2
  exit 1
fi
