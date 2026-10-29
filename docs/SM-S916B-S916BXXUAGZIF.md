# Galaxy S23+ SM-S916B / S916BXXUAGZIF porting record

## Status

Offline port pending hardware validation — nothing in this profile is
device-tested. Every constant was re-derived offline from the recovered
AGZIF ELF/BTF (kernel `5.15.197-android13-8-34343818-abS916BXXUAGZIF`, a
full rebuild over FZI1's `5.15.189-android13-8-33413713`), using the same
anti-copying method as before: every derivation script runs on both blobs
and had to reproduce the published FZI1 constants on the FZI1 side first.
The OS17 sepolicy gate comparison is machine-checked ("no material
change"), and the KernelSU FZG1 loader-pair reuse passed all three audit
gates, including an instruction-level proof that the AGZIF kernel itself
accepts the FZG1 vermagic. The compiled payloads are committed; the
hardware run against this record is the remaining step. The profile is
not in the support feed.

## Exact target

| Field | Value |
| --- | --- |
| Model | `SM-S916B` Galaxy S23+ |
| Firmware | `S916BXXUAGZIF` |
| Fingerprint | `samsung/dm2qxxx/dm2q:17/CP2A.260605.016/S916BXXUAGZIF:user/release-keys` |
| Kernel | `5.15.197-android13-8-34343818-abS916BXXUAGZIF` (clang `r450784e` 14.0.7, LLD 14.0.7, built `Sun Sep 27 23:09:54 UTC 2026`) |
| Payload profile | `dm2q-S916BXXUAGZIF` |
| Proven writer | MCAST (carried from FZI1) |
| Expected execution domain | `uid=2000`, `u:r:shell:s0` |

## Provenance

```text
firmware zip  SM-S916B_5_20260928230612_i5ccb2l976_fac.zip
boot.img      100663296 bytes        sha256 ed1c34b5b4ed4b914a3f27cf263e1374307d0349932f23b7aa336401750c8121
kernel Image  46860800 bytes         sha256 cc591b86147419b679f3c82b858fac09ccc44abbef560fe8ce9dc8e01bb1a2c5
boot header   v4, kernel_size at 0x08, kernel blob at 0x1000, Image flags 0xa, text_offset 0
BTF blob      [0x21f29dc, 0x27c3953), 6098807 bytes
ELF base      0xffffffc008000000 (126451 recovered symbols, 126441 unique names)
build props   bootimage fp samsung/dm2qxxx/dm2q:13/TP1A.220624.014/S916BXXUAGZIF:user/release-keys (fota BOOT build.prop, dated Mon Sep 28 08:20:41 KST 2026);
              system platform id CP2A.260605.016 (Android 17) confirmed via super.img qssi fingerprint string
```

The `BUILD_FINGERPRINT` pairs the bootimage product/device (`dm2qxxx/dm2q`,
Android 13 boot header) with the system platform id segment
(`:17/CP2A.260605.016`), the same lineage convention as prior profiles.
Method validation: before pointing each script at AGZIF, its FZI1 side
reproduced the published FZI1 constants exactly (logger name `0x01d5dfe7`,
boot-id slot `0x02bba9c8` → `sysctl_bootid 0x02e6c0b1`, event id 108,
callers `0x0010db44`/`0x000c8fe4`, MCAST site `add x3, sp, #0x40`), so
equality with FZI1 anywhere below is an observation after independent
derivation, never a copied value.

## Firmware diff (FZI1 → AGZIF)

Member-level SHA-256 comparison of all 54 tar members in both zips (12 AP,
31 BL, 1 CP, 6 CSC, 4 HOME_CSC):

- **CP changed** this time: `modem.bin` (76,960,536 → 77,040,692 B) —
  unlike FZH3 → FZI1, where the CP build was byte-identical.
- **BL**: every component changed except `dspso.bin` (byte-identical) —
  `abl.elf`, `tz`, `xbl*`, `vbmeta`, `uefi`, `keymint`, …
- **AP**: every member changed — `boot.img.lz4` (+26,973 B compressed),
  `dtbo`, `init_boot`, `recovery`, `super` (+183,219,075 B compressed),
  `vendor_boot`, `vbmeta_system`, `vm-bootsys`, `persist`, `misc`,
  `userdata` (+631,343,541 B), and the ~1.2 GB fota delta
  (1,208,196,718 → 1,306,280,193 B).
- **CSC/HOME_CSC**: `pit`, `cache`, `omr`, `prism` (313,745,244 →
  280,990,441 B), `optics` changed; the HOME_CSC `download-list.txt` is
  byte-identical.

## Kernel diff (the 189→197 rebuild)

Same Image size (46,860,800 B), same toolchain (`r450784e` clang 14.0.7,
LLD 14.0.7), ELF/BTF recovered at the same base `0xffffffc008000000` —
but unlike FZI1 (a full rebuild over a byte-identical type universe and
config), AGZIF's rebuild carries real type and config drift. The verified
decomposition:

1. **BTF type universe: drifted at the edges, identical where it matters.**
   Definition-view names 12,674 → 12,673 (Δ −1; the raw-dump counting
   gives 12,675 → 12,674, the same delta), records 139,558 → 139,655
   (+97 — new functions and their type chains, not struct growth).
   Composition: 8 names gone (`five_cert`, `five_cert_body`,
   `five_cert_header`, `five_signature_type`, `five_version` — matching
   the deleted `CONFIG_FIVE_CERT_USER`; plus `ahash_completion`,
   `dma_buf_list`, `lv`), 7 added (`setid_rule`, `setid_ruleset`,
   `setid_type`, `sid_policy_type` — matching `CONFIG_SECURITY_SAFESETID`;
   `bpf_iter__dmabuf`, `dmabuf_iter_priv`, `dualsense_mixer_elem_info`).
   17 named types changed layout or enum values (`defex_context` 0x58 →
   0x88 and `defex_local_syscall` +4 enumerants — DEFEX link protection —
   `eventpoll`, f2fs, USB/xHCI, …), none payload-relevant. **All 72
   payload layout macros re-derived from the AGZIF BTF are identical**:
   `task_struct` (0x1200), `rt_mutex_waiter` (0x58), `file_operations`
   (0x120), `configfs_buffer` (0x80), `page` (0x40), the workqueue set,
   `ctl_table` (0x40, `.data` at +0x8), `UCOUNT_COUNTS=14`,
   `group_source_req` 0x108 with `gsr_group` @ 0x8.
2. **IKCONFIG: four option-line changes** (2,147 → 2,148 options):
   `CONFIG_SECURITY_SAFESETID=y` (was not set), the new
   `CONFIG_SECURITY_DEFEX_LINK_PROTECTION=y`, `CONFIG_QCOM_LMH` added as
   not set, and `CONFIG_FIVE_CERT_USER` deleted. `CONFIG_MODVERSIONS=y`
   and `CONFIG_MODULE_FORCE_LOAD` (unset) are unchanged.
3. **Code: 35 of 38 payload-relevant functions instruction-identical**
   (symbol-resolving diff; only relocated data references differ). Two
   functions carry real code change, both in the requeue machinery on the
   waker thread: `futex_requeue` (frame 0x140 → 0x150, +3 instructions)
   and `remove_waiter` (frame 0x40 → 0x50, +4). **No `target.h` constant
   binds to either** — the waiter layout constants are BTF-derived and
   unchanged, and the stale waiter's frame is `futex_wait_requeue_pi`'s,
   which is identical. The constants that depend on code shape were
   re-derived and moved: the worker/vfork tracefs callers
   (`0x0010db44`/`0x000c8fe4` → `0x0010ddfc`/`0x000c90bc`). The MCAST
   greqs site (`add x3, sp, #0x40` before `bl ip6_mc_source`) is
   byte-identical and both stack-overlap endpoints are frame-identical,
   so `MCAST_WAITER_OFF 0x78` holds after re-derivation. The pipe path
   (`pipe_write`, `anon_pipe_write`, `pipe_read`, `alloc_pipe_info`,
   `copy_page_from_iter_atomic`) is instruction-identical, corroborating
   the carried pipe constants.
4. **Event ID: unchanged, re-derived** — `__event_sched_blocked_reason`
   and `__start_ftrace_events` both moved −0x398 (index 88), AGZIF BTF
   `__TRACE_LAST_TYPE=20`, so `20 + 88 = 108`.

## Drift table (FZI1 → AGZIF)

All 28 drifted constants of 140 rows (28 drifted, 87 re-derived unchanged,
13 strategy carries, 5 carried geometry rows, 2 carried P0, 3 composed,
2 omitted):

| Constant | FZI1 | AGZIF | Delta |
| --- | ---: | ---: | ---: |
| `SLIDE_NFULNL_LOGGER_NAME_OFF` | `0x01d5dfe7` | `0x01d607d9` | +0x27f2 |
| `KMALLOC_CACHES_OFF` | `0x02064878` | `0x020671f0` | +0x2978 |
| `ANON_PIPE_BUF_OPS_OFF` | `0x01e7f860` | `0x01e81d20` | +0x24c0 |
| `ASHMEM_FOPS_OFF` | `0x0200d8b8` | `0x020100f8` | +0x2840 |
| `ASHMEM_IOCTL_OFF` | `0x0114cb1c` | `0x011513a0` | +0x4884 |
| `ASHMEM_COMPAT_IOCTL_OFF` | `0x0114d178` | `0x011519fc` | +0x4884 |
| `ASHMEM_MMAP_OFF` | `0x0114d1d0` | `0x01151a54` | +0x4884 |
| `ASHMEM_OPEN_OFF` | `0x0114d4b0` | `0x01151d34` | +0x4884 |
| `ASHMEM_RELEASE_OFF` | `0x0114d548` | `0x01151dcc` | +0x4884 |
| `ASHMEM_SHOW_FDINFO_OFF` | `0x0114d664` | `0x01151ee8` | +0x4884 |
| `CONFIGFS_READ_ITER_OFF` | `0x005d74b8` | `0x005d8a1c` | +0x1564 |
| `CONFIGFS_BIN_WRITE_ITER_OFF` | `0x005d7ee0` | `0x005d9444` | +0x1564 |
| `COPY_SPLICE_READ_OFF` | `0x00528198` | `0x00528e28` | +0xc90 |
| `NOOP_LLSEEK_OFF` | `0x004bbd34` | `0x004bc6b4` | +0x980 |
| `INIT_TASK_OFF` | `0x02c050c0` | `0x02c05400` | +0x340 |
| `SLIDE_INIT_TASK_OFF` | `0x02c050c0` | `0x02c05400` | +0x340 |
| `SLIDE_TRACEFS_WORKER_CALLER_OFF` | `0x0010db44` | `0x0010ddfc` | +0x2b8 |
| `CALL_USERMODEHELPER_EXEC_WORK_OFF` | `0x001045d0` | `0x00104888` | +0x2b8 |
| `PREPARE_KERNEL_CRED_OFF` | `0x0011e3c8` | `0x0011e694` | +0x2cc |
| `COMMIT_CREDS_OFF` | `0x00120104` | `0x001203d0` | +0x2cc |
| `OVERRIDE_CREDS_OFF` | `0x0011f1dc` | `0x0011f4a8` | +0x2cc |
| `SLIDE_TRACEFS_VFORK_CALLER_OFF` | `0x000c8fe4` | `0x000c90bc` | +0xd8 |
| `ASHMEM_MISC_FOPS_OFF` | `0x02bfcf78` | `0x02bfd278` | +0x300 |
| `SLIDE_RANDOM_TABLE_BOOT_ID_DATA_PTR_OFF` | `0x02bba9c8` | `0x02bbabc8` | +0x200 |
| `SLIDE_SYSCTL_BOOTID_OFF` | `0x02e6c0b1` | `0x02e6c131` | +0x80 |
| `SELINUX_ENFORCING_OFF` | `0x02d8e5c0` | `0x02d8e600` | +0x40 |
| `SLIDE_NFULNL_LOGGER_OBJECT_OFF` | `0x02a91e48` | `0x02a91e50` | +0x8 |
| `SYSTEM_UNBOUND_WQ_OFF` | `0x02a90800` | `0x02a90808` | +0x8 |

The ashmem text block moved uniformly (+0x4884) from code inserted earlier
in `.text`; configfs moved +0x1564, the cred trio +0x2cc, and the UMH
worker +0x2b8.
The rebuild moved essentially everything (the drift histogram over
119,180 common symbols is spread; `ROOT_TASK_GROUP_OFF` is the only
payload data symbol that held, +0). Values that carry their own proof:

- `SLIDE_NFULNL_LOGGER_NAME_OFF` is the headline slide constant: the
  `.name` qword at AGZIF `nfulnl_logger` (`0x02a91e50`) reads
  `0x01d607d9` from the Image, and the bytes there are the literal
  `"nfnetlink_log"`.
- `SELINUX_ENFORCING_OFF` re-derived from `selinux_state` (nm) + the
  AGZIF BTF `offsetof(selinux_state, enforcing)` = 0 — enforcing is
  still at byte 0, re-derived, not assumed.
- The boot-id slot re-anchored on pointer identity: `random_table`
  entry k=4 (procname `boot_id`, AGZIF BTF stride 0x40, `.data` at +0x8)
  whose `.data` = `0x02e6c131` = nm `sysctl_bootid`.
- `MCAST_WAITER_OFF 0x78` re-derived from frame evidence (both endpoints
  of the stack-overlap arithmetic frame-identical to FZI1), not copied.

The `p0_fingerprint.h` table was generated with
`tools/generate_p0_fingerprint.pl` at probe offset `0x1f0000` and
self-verified (32 rows, 256 qwords; 256/256 qwords confirmed by an
independent read-back from the Image).

**Sigreturn omission.** `SIGRETURN_FPSIMD_WAITER_OFF` and
`SIGRETURN_SVE_WAITER_OFF` are omitted from the AGZIF profile (user
decision): they serve only the SIGRETURN writer variant while the active
route is MCAST, and every shared-src reference is guarded by
`SLIDE_STACK_WRITER == SLIDE_STACK_WRITER_SIGRETURN` (slide_app.c:1298,
1388–1389, 1493–1498; main.c:437). The clean MCAST compile without them
is the non-use proof.

## P0 constants

`P0_PHYS_OFFSET 0x80000000` / `P0_KERNEL_PHYS_LOAD 0x80080000` are
documented carries from FZG1/FZH3/FZI1, where the value was
hardware-validated by passing P0 writes. The AGZIF `abl.elf` (4,194,304 B,
sha256 `f044314c…`) is the same packed container as FZI1's — ELF32/ARM
wrapper, no section headers, obfuscated PT_LOAD (entropy 3.56 b/B), 232
strings, only the tag string differs — so the load base cannot be
re-verified offline. Carrying the value is supported by: every ABL
update in this device family so far (`0x80080000`, hardware-validated on
FZG1, FZH3, and FZI1); the identical kernel Image header
(`text_offset 0`, flags 0xa); and the failure mode — a wrong base
produces a P0 fingerprint mismatch at the read-verify gate and aborts
cleanly, like the documented FZG1-payload-on-FZH3 control failure, never
a blind write. **Hardware validation of the carried base is pending for
AGZIF** and is part of the planned device run.

## Sepolicy (FZI1 → AGZIF)

Machine-checked with the real policy engine (SETools 4.7.1 / libsepol)
over the compiled runtime policies of both builds; the brief-scope
classification, quoted verbatim from the audit:

> **"no material change"** — all compared allow rules (shell+su domain
> access to tracefs/debugfs tracing types and ashmem device, 243 rules in
> the brief scope, 4399 in the extended scope) exist in both the FZI1 and
> AGZIF compiled runtime policies with identical classes and permission
> sets (machine-checked set equality via SETools 4.7.1/libsepol). The
> compiled runtime policy was extracted from each build's ODM partition
> (`/odm/etc/selinux/precompiled_sepolicy`) because neither build's vendor
> partition ships a precompiled policy (init-verified layout); both builds
> were extracted and compared identically. Global policy delta between
> the builds: +13 allows / +1 type / 0 removals, none affecting the
> compared gates.

The +13/0 delta (a new Samsung `proc_bootfile_record` type plus minor
vendor grants) proves the comparison non-vacuous. Two documented
corrections, both retained with evidence: the compiled policy ships in
ODM in **both** builds (vendor ships CIL sources only; `init` references
the ODM path); and Samsung labels tracing under debugfs in both builds —
no `sys_kernel_tracing` class exists in either policy, and the 66
`genfscon debugfs /tracing/...` lines are identical. `shell` keeps
`open/read/map/append` on `debugfs_tracing:file` and the ashmem
`map/ioctl/read/write` domain grants in AGZIF — the userspace gates of
the tracefs route are unchanged. Residual: this comparison is
static-analysis-only (kernel-side LSM hook behavior is out of scope;
both policies have zero booleans, so no runtime toggling exists).

## KernelSU handoff

The published FZG1 loader pair `ksud-dm2q-S916BXXSAFZG1-kdp` (sha256
`5da5818d…`; its embedded module is byte-identical to the published
`.ko`) is reused, and the three-gate audit **passed against AGZIF**:

- **(a) Symbols: PASS.** All 200 undefined module symbols resolve in the
  recovered AGZIF `vmlinux.elf` (126,441 unique names); the FZI1 baseline
  re-passed first (0 missing there too).
- **(b) ABI: PASS.** All 8 fail-set BTF types are exactly identical
  (`ucount_type` enum, `task_struct` — 217 flattened members, 15
  bitfields — `cred`, `ucounts`, `workqueue_struct`, `pool_workqueue`,
  `worker_pool`, `work_struct`).
- **(c) Vermagic: PASS, kernel-side.** `ksud` provably does not rewrite
  the embedded module's vermagic: the binary's only module-load syscall
  is `init_module` (`svc` at `0x286854`; `finit_module` is structurally
  impossible — AGZIF's own `sys_call_table[313]` is `ni_syscall`), the
  only ELF writers are 12 `SHN_ABS` symtab-field rewrites (the
  kallsyms-aware manual relocation), and no running-release string source
  exists outside the boot-patch path. The AGZIF kernel accepts the FZG1
  string: its `check_modinfo` skips the release token on both sides
  whenever the module's `__versions` section exists (the FZG1 module's
  zero-length section has `SHF_ALLOC`, so `index.vers = 38 ≠ 0`), leaving
  `strcmp(" SMP preempt mod_unload modversions aarch64")` → 0. With
  `MODVERSIONS=y` the empty table also means zero CRC checks, and the
  unsigned module taints rather than fails (`CONFIG_MODULE_SIG` without
  `FORCE`).

Runtime risk notes (explicitly not load gates): AGZIF adds
`CONFIG_SECURITY_SAFESETID=y` and `CONFIG_SECURITY_DEFEX_LINK_PROTECTION=y`
— watch the su-path credential transitions and ksud's file-staging/
bind-mount disguise at the device run. The operational notes carry over
unchanged from the FZH3 record (Defex SIGKILL of direct `ksud` execution,
the logcat bind-mount disguise, the `--ephemeral` incompatibility,
`.ksud-stage` restaging, and the module re-enforcing SELinux). As with
gate (c), this is static instruction-level analysis plus string emulation
— not a hardware load; the device run is the remaining proof.

## Artifacts and commands

See [`../artifacts/dm2q-S916BXXUAGZIF/README.md`](../artifacts/dm2q-S916BXXUAGZIF/README.md)
for hashes, the exact per-boot commands, and the residual-risk list.
