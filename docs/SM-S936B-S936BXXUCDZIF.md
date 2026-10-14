# SM-S936B / S936BXXUCDZIF porting record

Offline port of the CVE-2026-43499 app payload to the Galaxy S25+
international (`SM-S936B`, `pa2q`) on One UI 9.0 stable, **device-tested
2026-10-15** (full chain: tracefs KASLR, physical-alias write, exploit
root, KernelSU late-load, granted `su` under Enforcing). Every constant
below is re-derived from this exact firmware, never copied. The per-boot
driver sequence is automated in
[`tools/root-pa2q-S936BXXUCDZIF.sh`](../tools/root-pa2q-S936BXXUCDZIF.sh).

## 1. Firmware identity

| field | value |
| --- | --- |
| model / device | `SM-S936B` / `pa2q` (product `pa2qxxx`) |
| AP/PDA | `S936BXXUCDZIF` (CSC `S936BOXMCDZIF`, OXM) |
| display build | `CP2A.260605.016.S936BXXUCDZIF` |
| system fingerprint | `samsung/pa2qxxx/qssi_64:17/CP2A.260605.016/S936BXXUCDZIF:user/release-keys` |

`BUILD_FINGERPRINT` in `target.h` bakes `samsung/pa2qxxx/pa2q:17/…` — the
ZZI4 convention of pairing the bootimage product/device (`pa2q`) with the
system build identity (`:17/CP2A.260605.016`), rather than either raw
fota fingerprint. The macro is a label only (unused by shared src).
| Android / SDK / One UI | 17 / 37 / 9.0 |
| SPL | 2026-09-05 |
| SoC / board | SM8750 / `sun` (Snapdragon 8 Elite, oryon) |
| kernel release | `6.6.127-android15-8-p33f4ffe-abogkiS936BXXUCDZIF-4k` (`#1 SMP PREEMPT Sat Sep 19 07:10:16 UTC 2026`) |
| kernel SHA-256 | `a160d149d35279c299b52460b405d4f517d30deaddbb65e997aebdf38446b724` (39,115,264 bytes) |
| boot.img SHA-256 | `b4e6f117503be87454e410cc8a23dfce5e1e8ff6efd60f62ad1b3b47107b9e43` (101,122,048 bytes) |

The GKI build id `p33f4ffe` is identical to the S938B ZZI4/DZIF One UI 9
kernels; the older `galaxy-s25-series` 6.6.98 payload does not cover the
6.6.127 boot.

## 2. Relation to the ZZI4 (S938B One UI 9) table

Same GKI ⇒ the kallsyms/BTF baseline matches the ZZI4 record:

- all 20 audited `*_OFF` symbols are **identical** to
  `pa3q-S938BXXUCZZI4` (including `KMALLOC_CACHES_OFF 0x0180e578`,
  `INIT_TASK_OFF 0x0234e2c0`, `SLIDE_SYSCTL_BOOTID_OFF 0x02683910`);
- `ASHMEM_MISC_FOPS_OFF = ashmem_misc + 0x10 = 0x024bcd80`;
- `SLIDE_RANDOM_TABLE_BOOT_ID_DATA_PTR_OFF = 0x024785c8` (entry procname
  `boot_id`, `.data` slot at `random_table + 0x108`, verified against
  `sysctl_bootid`);
- raw BTF: single validated blob `[0x18aca6c, 0x1ecd673)`, 6,425,607 bytes,
  SHA-256 `e13df32a16b5536c43897542b4dbc2c7082f2aefb91249bc94a06bfc5870950c`
  — **byte-identical to ZZI4**, so every struct layout macro (fops 0x108,
  task_struct 0x12c0 with pi_lock 0x90c/pi_waiters 0x920/pi_top_task
  0x930/pi_blocked_on 0x938/sched_task_group 0x348, page 0x40 with
  compound_head/slab_cache 0x08 and page_type 0x30, rt_mutex_waiter 0x70,
  workqueue/pwq/pool/work_struct) carries over verified, not assumed.

The **one** deliberate divergence (never copy across devices):

| macro | ZZI4 | this device | source |
| --- | ---: | ---: | --- |
| `SLIDE_NFULNL_LOGGER_NAME_OFF` | `0x01791638` | `0x01791664` | dereferenced `nfulnl_logger` name pointer → `"nfnetlink_log"` in this Image's `.rodata` |

Symbol addresses are identical; the string pool shifted +0x2c between
same-GKI device builds. Copying ZZI4's value would mis-solve the slide by
0x2c.

## 3. Slide-route derivations

- `SLIDE_TRACEFS_EVENT_ID = 109`:
  `(__event_sched_blocked_reason 0x22f17e8 − __start_ftrace_events
  0x22f1520) / 8 = 89` (zero-based), `__TRACE_LAST_TYPE = 20` on 6.6.
  Verify on device via `/sys/kernel/tracing/events/sched/sched_blocked_reason/id`.
- `SLIDE_TRACEFS_WORKER_CALLER_OFF = 0x000d9ba0`: `worker_thread` at
  `0x000d9b04`; the blocking `bl schedule` at `0x000d9b9c` decodes to
  `schedule` (`0x0115f2d0`) exactly, caller = the following instruction.
- `SLIDE_PSELECT_WORD_SHIFT = 0`: same non-LEGACY `rt_mutex_waiter`
  word 0–13 layout and `nfds=320` reasoning as the psq/S9360/ZZI4 records.

## 4. Physical addresses

- `P0_PHYS_OFFSET = 0x80000000`: vendor_boot DTB
  `/reserved-memory/gunyah_hyp_region@80000000`.
- `P0_KERNEL_PHYS_LOAD = 0xa8000000`: family ruling. DZIF's `uefi.elf`
  (LOAD at `0xa7000000`, entry `0xa7000000`, size `0x2ca000`; `abl.elf`
  ARM32 at `0x9fa00000`) no longer stores the literal in plaintext (no
  u32/u64 hits; two LZMA FV streams decode to QcomPkg DXE modules with 597
  ambiguous u32 hits and no ARM64-Image-magic loader). Accepted on the
  agreement of pa3q-S938NKSUACZF1, pa2q-S9360ZCSCCZG1 (same device, One UI
  8, device-tested), psq-S9370ZCS9CZG1, and pa3q-S938BXXUCZZI4 (same GKI,
  One UI 9). A wrong value would make phys-alias writes land elsewhere in
  RAM (no root, reboot clears it; nothing is flashed); first device run
  must confirm.

## 5. Route flags (One UI 9 pattern)

`APP_PHYS_P0_ORACLE 1` (fallback compiled) + `APP_TRACEFS_SLIDE 1`
(deterministic KASLR discovery) + `APP_TRACEFS_PHYS_ALIAS_DATA 1` (data
writes through the physical-load alias; canonical direct-map writes never
land on this build per the ZZI4 finding) + `APP_FOPS_RETRY_BUDGET 8`
(state-neutral window misses retried while no write has landed). The
supporting shared-src additions are default-off and were merged with a
byte-identical rebuild gate on `pa3q-S938NKSUACZF1`
(`71f1f607fa53e23c393348ed779bbd0c1b9dc3ec34b99f8ac6541dc6d9965c3d`).

## 6. P0 fingerprint

Regenerated from this Image at probe `0x1f0000`
(`src/targets/pa2q-S936BXXUCDZIF/p0_fingerprint.h`), 32 rows, readback
verified 256/256 qwords. 5/32 rows differ from ZZI4
(slides `0x70000`, `0x90000`, `0xa0000`, `0xc0000`, `0x1a0000`) — the
expected per-device pattern.

## 7. Build and artifact

```sh
make TARGET=pa2q-S936BXXUCDZIF ANDROID_NDK_HOME=/opt/android-ndk release
```

`build/pa2q-S936BXXUCDZIF/cve-2026-43499-app.release.so` (padded to the
fixed 104,128 bytes) is published as
`artifacts/pa2q-S936BXXUCDZIF/cve-2026-43499-app.so`,
SHA-256 `4dcfaf7b288583ab5dc86648ffbf52d4f9f6639344415605633f449ded7f64a9`,
label `pa2q-S936BXXUCDZIF-app-tracefs-phys-alias`. The device-tested root
helper (`make all`, SHA-256
`375857c5d9a3b425c84decbb243f4abba579993c33ea30086c29fd3a7e8f06f2`) is
published alongside as `cve-2026-43499-root` — it is both the UMH daemon
and the `--run-payload` runner used by the driver script.

Dynamic-import audit against a same-tree `pa3q-S938NKSUACZF1` release
build: identical 81-symbol base plus three route-justified imports —
`strtoul`/`strtoull` (tracefs event-id parsing, direct calls inside the
`APP_TRACEFS_SLIDE` block) and `getauxval`/`__system_property_get`
(bionic-internal imports pulled in by `sysconf(_SC_NPROCESSORS_CONF)` in
the same block). The Extended-fork ZZI4 payload's libc set
(`fstat`/`fsync`/`pipe2`) is a fork-src artifact and does not apply.

## 8. KernelSU

Upstream `kernelsu/ksud-s25u-kdp` is reused unchanged (user directive:
upstream first). The module embedded in `ksud-s25u-kdp` (rust-embed 8 +
include_flate raw deflate, decode site `0x4de4f`+`0x19285e`, wbits −15)
inflates to 3,543,168 bytes **byte-identical** to the standalone
`android15-6.6_kernelsu-s25u-kdp.ko` (SHA-256
`54676e77a87a86203c825695199b20abe5b464b5766e200185968a990c57b235`), so
the standalone module is a valid audit subject. Audit against the DZIF
`vmlinux.nm`: all **222** undefined module symbols resolve, 0 missing.
The module is a 6.6.127-KMI build (`vermagic
6.6.127-4k-g46a034eca005-dirty SMP preempt mod_unload modversions aarch64`,
zero-length `__versions`); the late loader relocates from `/proc/kallsyms`
and adapts vermagic (see the S9370 record), so the release-string
inequality is expected. No rebuild needed.

## 9. Status

| stage | result |
| --- | --- |
| Symbol/layout port | derived; 20/20 ZZI4 match + one explained divergence |
| P0 fingerprint | re-derived, 256/256 readback, 5/32 rows device-specific |
| Payload build | 104,128 bytes, label verified, import audit clean |
| KernelSU | upstream pair reused, 222/222 symbols resolve |
| On-device validation | **passed 2026-10-15** (checklist below) |

### On-device validation record (2026-10-15, serial R5CY21VN54W)

Every acceptance item passed:

1. **Event ID** — `events/sched/sched_blocked_reason/format` reports
   `ID: 109`; the runtime tracefs route logged `id=109`.
2. **Worker-caller alignment** — live trace shows
   `caller=worker_thread+0x9c/0x334`; the exploit's raw parse read
   `ffffffc080179ba0`, and `0x179ba0 − 0xd9ba0 = 0xa0000` ⇒ slide
   `0xa0000`, 64-KiB aligned, inside the candidate range. Both the
   symbolic and raw observations agree exactly.
3. **Phys-alias confirmation (the `0xa8000000` gate)** —
   `p0 physical write status=0 ok=1`, `phys step probed write done ok=1`,
   `rw64=1/1`, `uid=2000->0`. The family-ruled `P0_KERNEL_PHYS_LOAD` is
   confirmed on this build. Supporting address math from the same run:
   the CFI chain's `want=ffffffc08046b7f8` equals
   base+slide+`NOOP_LLSEEK_OFF` exactly, and the selinux write target
   resolved to `SELINUX_ENFORCING_OFF`.
4. **P0-oracle fallback** — exercised state-neutrally: the first run's
   FOPS window missed (`window=0`, no write landed) and the boot stayed
   repeatable; the oracle cache-gate read real kmalloc-2k pointers
   (`selected=ffffff8001cf4c00`, `match=1` — the S9360 failure mode is
   ruled out).
5. **KernelSU** — logcat-disguised `ksud late-load` brought
   `kernelsu 172032 … Live (O)` up on the 6.6.127 kernel; the module
   re-enforced SELinux, and `su -c id` returns
   `uid=0 … context=u:r:ksu:s0` under Enforcing.

Run behavior worth knowing: with `SLIDE_SOURCE=tracefs` the slide solves
on the first shot every time; the timing-sensitive FOPS write needed 6
shots on the validated run (`EXPLOIT_ATTEMPTS=8` matches
`APP_FOPS_RETRY_BUDGET=8`; missed shots are state-neutral and announced
as `fops shot N/8`). A full attempt-1 log is retained at
`~/.superpowers/Root-My-Galaxy-Payloads/S936BXXUCDZIF/device-run-2026-10-15.log`.
The shell context has `readtracefs` and the payload enables
`sched_blocked_reason` plus `tracing_on` itself. Root is per-boot
volatile: nothing is flashed, reboot clears it, rerun the driver script.
