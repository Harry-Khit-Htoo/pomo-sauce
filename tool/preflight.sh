#!/usr/bin/env bash
# Pre-upload check for Google Play.
#
#   tool/preflight.sh
#
# Runs every mechanical check that can be automated and prints a PASS/FAIL
# summary. It does NOT check the things only a human can (Play Console
# declarations, screenshots, the demo videos reviewers ask for on restricted
# permissions) - those are listed at the end as manual items.
#
# Exit code 0 only when every automated check passes.

set -uo pipefail
cd "$(dirname "$0")/.."

PASS=0
FAIL=0
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL + 1)); }
note() { printf '        %s\n' "$1"; }

echo
echo "Pomo Sauce - Play upload preflight"
echo "===================================="
echo

# --- 1. static analysis -------------------------------------------------
echo "Code"
if flutter analyze >/dev/null 2>&1; then
  ok "flutter analyze is clean"
else
  bad "flutter analyze reported issues"
  note "run: flutter analyze"
fi

if flutter test >/dev/null 2>&1; then
  ok "flutter test passes"
else
  bad "flutter test has failures"
  note "run: flutter test"
fi

# --- 2. placeholders ----------------------------------------------------
echo
echo "Store metadata in the app"
if grep -qE "example\.com|CHANGE_ME|placeholder" lib/core/constants.dart 2>/dev/null; then
  bad "placeholder URLs still in lib/core/constants.dart"
  grep -nE "example\.com|CHANGE_ME|placeholder" lib/core/constants.dart | sed 's/^/        /'
  note "Play requires a reachable privacy policy, linked in-app AND in Console"
else
  ok "privacy policy / support address are not placeholders"
fi

# --- 3. signing ---------------------------------------------------------
echo
echo "Signing"
if [ -f android/key.properties ]; then
  ok "android/key.properties present"
else
  bad "android/key.properties missing - release builds are DEBUG SIGNED"
  note "see android/key.properties.example"
fi

AAB="build/app/outputs/bundle/release/app-release.aab"
APK="build/app/outputs/flutter-apk/app-release.apk"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$LOCALAPPDATA/Android/Sdk}}"
APKSIGNER="$(find "$SDK/build-tools" -name 'apksigner*' 2>/dev/null | sort | tail -1)"

check_signer() {
  local artifact="$1"
  [ -f "$artifact" ] || { note "not built yet: $artifact"; return; }
  [ -n "$APKSIGNER" ] || { note "apksigner not found; cannot verify signer"; return; }
  local dn
  dn="$("$APKSIGNER" verify --print-certs "$artifact" 2>/dev/null \
        | grep -i 'certificate DN' | head -1)"
  if [ -z "$dn" ]; then
    note "could not read signer for $(basename "$artifact")"
  elif echo "$dn" | grep -qi "Android Debug"; then
    bad "$(basename "$artifact") is DEBUG SIGNED - Play will reject it"
  else
    ok "$(basename "$artifact") is signed with a release key"
    note "$dn"
  fi
}
check_signer "$APK"

# --- 4. the shipped artifact -------------------------------------------
echo
echo "Release artifact"
if [ -f "$AAB" ]; then
  ok "app bundle exists"

  if bash tool/check_16kb_alignment.sh "$AAB" >/dev/null 2>&1; then
    ok "native libraries are 16 KB page aligned"
  else
    bad "16 KB alignment check failed"
    note "run: tool/check_16kb_alignment.sh $AAB"
  fi

  # The alarm tones are referenced only from Dart, so resource shrinking can
  # silently strip them and leave every alarm silent in release.
  RAW_COUNT=$(unzip -l "$AAB" 2>/dev/null | grep -cE 'res/.*\.wav')
  if [ "$RAW_COUNT" -ge 3 ]; then
    ok "all 3 alarm tones survived resource shrinking"
  else
    bad "only $RAW_COUNT/3 alarm tones in the bundle - alarms will be silent"
    note "check android/app/src/main/res/raw/keep.xml"
  fi
else
  bad "no app bundle - run: flutter build appbundle --release"
fi

MANIFEST=$(ls build/app/intermediates/packaged_manifests/release/*/AndroidManifest.xml 2>/dev/null | head -1)
if [ -n "$MANIFEST" ]; then
  TARGET=$(grep -oE 'android:targetSdkVersion="[0-9]+"' "$MANIFEST" | grep -oE '[0-9]+')
  if [ "${TARGET:-0}" -ge 36 ]; then
    ok "targetSdkVersion is $TARGET"
  else
    bad "targetSdkVersion is ${TARGET:-unknown}; Play requires 36+ for new apps"
  fi
  echo
  echo "Permissions in the shipped manifest (each needs a Console justification):"
  grep -oE 'android:name="android\.permission[^"]*"' "$MANIFEST" \
    | sed 's/.*permission\.//;s/"//' | sort -u | sed 's/^/        /'
fi

# --- 5. store assets ----------------------------------------------------
echo
echo "Store assets"
for f in assets/branding/icon_play_512.png assets/branding/feature_graphic_1024x500.png; do
  [ -f "$f" ] && ok "$(basename "$f")" || bad "missing $f"
done
SHOTS=$(ls store/screenshots/*.png 2>/dev/null | wc -l | tr -d ' ')
if [ "$SHOTS" -ge 2 ]; then
  ok "$SHOTS screenshots in store/screenshots/"
else
  bad "no phone screenshots (found $SHOTS in store/screenshots/)"
  note "Play needs at least 2; take them in BOTH light and dark theme"
fi

# --- summary ------------------------------------------------------------
echo
echo "===================================="
printf 'Automated: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m\n' "$PASS" "$FAIL"
echo
echo "Still manual - nothing here can check these for you:"
cat <<'MANUAL'
  [ ] Privacy policy actually hosted and reachable at the URL in the app
  [ ] Data safety form: no data collected, none shared, none transmitted
  [ ] Foreground service (specialUse) justification + demo video
  [ ] Notification Policy Access (DND) justification + demo video
  [ ] Content rating questionnaire, target audience, ads declaration
  [ ] Tested a full-length session on a REAL device with the screen off
  [ ] Tested on an OEM with aggressive battery killing (Xiaomi/Samsung/Oppo)
MANUAL
echo
echo "Wording for the two restricted-permission justifications is in README.md"
echo "under 'Play Store submission checklist'."
echo

[ "$FAIL" -eq 0 ]
