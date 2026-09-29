# Galaxy S23+ SM-S916B / S916BXXSAFZI1 porting record

## Status

Offline port of the hardware-proven FZH3 profile to the September 2026
`S916BXXSAFZI1` CAU firmware. Every constant was re-derived from the
recovered FZI1 ELF/BTF and cross-checked against an identically recovered
FZH3 set (which reproduced every published FZH3 constant exactly).
Hardware validation is pending; the profile is not in the support feed.

## Exact target

| Field | Value |
| --- | --- |
| Model | `SM-S916B` Galaxy S23+ |
| Firmware | `S916BXXSAFZI1` (CAU/OXM multi-CSC) |
| Fingerprint | `samsung/dm2qxxx/dm2q:16/BP4A.251205.006/S916BXXSAFZI1:user/release-keys` |
| Kernel | `5.15.189-android13-8-33413713-abS916BXXSAFZI1` (clang `r450784e` 14.0.7, LLD 14.0.7, built `Tue Sep 8 02:02:15 UTC 2026`) |
| Payload profile | `dm2q-S916BXXSAFZI1` |
| Proven writer | MCAST (carried from FZH3) |
| Expected execution domain | `uid=2000`, `u:r:shell:s0` |

## Provenance

```text
firmware zip  SM-S916B_5_20260909113951_bkv9809ank_fac_S916BXXSAFZI1_S916BOXMAFZI1_S916BXXSAFZE1_S916BXXSAFZI1_CAU.zip
boot.img      100663296 bytes        sha256 1b2c4c98221a294e87a020d573196c1834ebda82c8f3f0f24ad9a09f5df6f253
kernel Image  46860800 bytes         sha256 5ccf2ae68d28d06b5f8f9d5d8709e3c19e23d4722f25b8fa1b937a06ef753223
boot header   v4, kernel_size at 0x08, kernel blob at 0x1000, Image flags 0xa, text_offset 0
BTF blob      [0x21f02ac, 0x27c0256), single validated candidate
ELF base      0xffffffc008000000 (126214 recovered symbols)
build props   bootimage fp samsung/dm2qxxx/dm2q:13/TP1A.220624.014/S916BXXSAFZI1:user/release-keys (fota BOOT/RAMDISK build.prop, dated Tue Sep 8 11:13:07 KST 2026);
              system platform id BP4A.251205.006 confirmed via super.img qssi fingerprint string
```

The FZH3 comparison baseline (boot.img `3cbe0895…`, kernel `94148bec…`,
BTF `[0x21ef2ac, 0x27bf188)`) reproduced the published FZH3 provenance
exactly, validating the derivation method.

## Firmware diff (FZH3 → FZI1)

Member-level SHA-256 comparison of every tar in both zips:

- **CP unchanged**: `modem.bin` byte-identical (same `S916BXXSAFZE1` CP
  build).
- **BL**: every component changed (`abl.elf`, `tz`, `xbl*`, `vbmeta`…).
- **AP**: `boot.img.lz4` (+3,767 B compressed), `dtbo`, `init_boot`,
  `recovery`, `super`, `vendor_boot`, `vbmeta_system`, `vm-bootsys`,
  `persist`, `misc`, and the 1.2 GB fota delta all changed.
- **CSC/HOME_CSC**: `prism.img`, `optics.img`, `pit`, `cache` changed.

## Kernel diff (the September rebuild)

Unlike FZG1→FZH3 (byte-identical text, four drifted data objects), FZI1 is
a **full rebuild**: 11,000 of 11,441 4-KiB Image pages differ, yet the
kernel size, build ID (`33413713`), toolchain, and ABI are unchanged. The
verified decomposition:

1. **BTF type universe: byte-identical.** All 12,675 named types — every
   struct, union, and enum, including `enum ucount_type`
   (`UCOUNT_COUNTS=14`), `enum trace_type` (`__TRACE_LAST_TYPE=20`),
   `task_struct`, `mm_struct` (0x3e0), `rt_mutex_waiter` (0x58),
   `file_operations`, `configfs_buffer`, `page`, workqueue structs,
   `cred`, `ucounts`, `skb_shared_info`, `ctl_table` — have identical
   sizes, member bit offsets, and enum values. Every layout constant in
   the profile therefore carries over, for both the exploit and the
   KernelSU module ABI.
2. **IKCONFIG: byte-identical** (2,147 options). Config-derived behavior
   (slab geometry, kmalloc types, VA layout) is unchanged.
3. **Code: instruction-count identical everywhere checked.** A
   symbol-resolving disassembly diff (movz/movk/adrp value tracking,
   every materialized address resolved through each kernel's own symbol
   table, referenced content annotated) over 35 payload-relevant
   functions found no real code change: the only differences are
   relocated data references (e.g. the `"dev/ashmem/"` and
   `"size:\t%zu\n"` strings, `init_cred_kdp` pointer slots, tracepoint
   structs) and one `security_hook_heads` slot that moved because the
   hook array layout drifted. The constants that depend on code shape
   were re-derived and are unchanged: the worker/vfork tracefs callers
   (`bl schedule` at `worker_thread+0x74` → `0x0010db44`; the return
   after `bl wait_for_common` at `wait_for_vfork_done+0x44` →
   `0x000c8fe4`), the MCAST setsockopt chain (the `add x3, sp, #0x40`
   greqs argument to `ip6_mc_source` is byte-identical, so
   `MCAST_WAITER_OFF 0x78` holds), and the futex waiter chain.
4. **Event ID: unchanged** — `__event_sched_blocked_reason` and
   `__start_ftrace_events` both drifted +0, index 88, `20 + 88 = 108`.

## Drift table (FZH3 → FZI1)

| Constant | FZH3 | FZI1 | Delta |
| --- | ---: | ---: | ---: |
| `KMALLOC_CACHES_OFF` | `0x02063fb8` | `0x02064878` | +0x8c0 |
| `ANON_PIPE_BUF_OPS_OFF` | `0x01e7efa0` | `0x01e7f860` | +0x8c0 |
| `ASHMEM_FOPS_OFF` | `0x0200cff8` | `0x0200d8b8` | +0x8c0 |
| `ASHMEM_MISC_FOPS_OFF` | `0x02bfcf28` | `0x02bfcf78` | +0x50 |
| `INIT_TASK_OFF` | `0x02c05080` | `0x02c050c0` | +0x40 |
| `ASHMEM_IOCTL_OFF` | `0x0114c6dc` | `0x0114cb1c` | +0x440 |
| `ASHMEM_COMPAT_IOCTL_OFF` | `0x0114cd38` | `0x0114d178` | +0x440 |
| `ASHMEM_MMAP_OFF` | `0x0114cd90` | `0x0114d1d0` | +0x440 |
| `ASHMEM_OPEN_OFF` | `0x0114d070` | `0x0114d4b0` | +0x440 |
| `ASHMEM_RELEASE_OFF` | `0x0114d108` | `0x0114d548` | +0x440 |
| `ASHMEM_SHOW_FDINFO_OFF` | `0x0114d224` | `0x0114d664` | +0x440 |
| `CONFIGFS_READ_ITER_OFF` | `0x005d7420` | `0x005d74b8` | +0x98 |
| `CONFIGFS_BIN_WRITE_ITER_OFF` | `0x005d7e48` | `0x005d7ee0` | +0x98 |
| `SLIDE_NFULNL_LOGGER_NAME_OFF` | `0x01d5d842` | `0x01d5dfe7` | +0x7a5 |

The ashmem text block moved uniformly (+0x440) from code inserted earlier
in `.text`; configfs moved +0x98. All other payload symbols —
`prepare_kernel_cred`, `commit_creds`, `override_creds`,
`call_usermodehelper_exec_work`, `generic_file_splice_read`,
`noop_llseek`, `root_task_group`, `selinux_state` (enforcing at byte 0),
`system_unbound_wq`, `nfulnl_logger`, `random_table`, `sysctl_bootid` —
are unchanged. `random_table[4].data` at `0x02bba9c8` was verified to
still point at `sysctl_bootid` (`0x02e6c0b1`), and the FZI1
`nfulnl_logger.name` qword was read from the Image and lands on the
`"nfnetlink_log"` string at `0x01d5dfe7`.

The `p0_fingerprint.h` table was generated with
`tools/generate_p0_fingerprint.pl` at probe offset `0x1f0000` and
self-verified (32 rows, 256 qwords).

## P0 constants

`P0_PHYS_OFFSET 0x80000000` / `P0_KERNEL_PHYS_LOAD 0x80080000` are carried
from FZG1/FZH3, where they were hardware-validated by a passing P0 write.
The FZI1 `abl.elf` is a packed container (no strings, no sections, high
entropy — not statically analyzable), so the load base could not be
re-verified offline. Carrying the value is supported by: every ABL update
in this device family so far (FZG1→FZH3, and the same-SoC dm1q S911U1,
dm3q-S9180, gts9/gts9u profiles, all `0x80080000`); the identical kernel
Image header (`text_offset 0`); and the failure mode — a wrong base
produces a P0 fingerprint mismatch at the read-verify gate and aborts
cleanly, like the documented FZG1-payload-on-FZH3 control failure, never a
blind write. Hardware P0 validation is the final gate for this port.

## KernelSU handoff

The published FZG1 loader pair `ksud-dm2q-S916BXXSAFZG1-kdp` (kallsyms
aware, empty `__versions`, runtime relocation by name) is reused. Audit
against the recovered FZI1 `vmlinux.elf`: **all 200 undefined module
symbols resolve**, and the module's compile-time ABI assumptions
(`enum ucount_type`, `task_struct`, `cred`, `ucounts`, workqueue layouts)
are covered by the byte-identical BTF type universe. The FZG1 module's
vermagic embeds `…-abS916BXXSAFZG1`; the manual loader ignores vermagic,
as already proven on the FZH3 device by the same binary. The operational
notes (Defex SIGKILL of direct `ksud` execution, the logcat bind-mount
disguise, the `--ephemeral` incompatibility, `.ksud-stage` restaging, and
the module re-enforcing SELinux) carry over unchanged from the FZH3
record.

## Artifacts and commands

See [`../artifacts/dm2q-S916BXXSAFZI1/README.md`](../artifacts/dm2q-S916BXXSAFZI1/README.md)
for hashes, the exact per-boot commands, and the hardware-validation
checklist.
