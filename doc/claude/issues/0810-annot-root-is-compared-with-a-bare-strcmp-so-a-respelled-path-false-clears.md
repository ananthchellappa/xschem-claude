# 0810 — `annot_root` is compared with a bare `strcmp`, so re-opening the SAME file under a different spelling drops the annotation

STATUS: **OPEN — measured 2026-08-25 on the committed 0688 fix, filed not fixed.**
FOUND IN: `src/actions.c` `annot_show_check_root()` / `annot_show_set()` (issue 0688's fix).
RELATED: [0688](0688-the-annotation-mask-outlives-the-schematic-so-window-keyed-binding-cannot-hold.md),
[0809](0809-the-annotation-mask-leaks-into-a-new-window-with-a-null-stamp.md).

---

## 1. The defect

0688's stamp is `my_strdup`'d straight from `xctx->sch[0]`, which stores the path
**as spelled**, and the check is a bare `strcmp`:

```c
if(xctx->sch[0] && !strcmp(xctx->annot_root, xctx->sch[0])) return;
annot_show_set(0);
```

So two spellings of one file are two different sheets, and a same-file reload
under a different spelling is a **false clear**: the mask is dropped when the KEEP
half of the invariant says it must be held. Row **Y1** ("a same-path
`xschem load` leaves the mask alone") only ever exercises the byte-identical
spelling, so nothing catches it.

## 2. The measurement

Write-up agent, 2026-08-25, `--nogui`, arming mask 3 on `…/aselib/dut/dut.sch`
and re-loading the identical file under four spellings:

```
WU| reload as  b/dut/dut.sch             -> annot_show=3     (correct KEEP)
WU| reload as  b/dut/./dut.sch           -> annot_show=0     (FALSE CLEAR)
WU| reload as  b/dut//dut.sch            -> annot_show=0     (FALSE CLEAR)
WU| reload as  b/decoy/../dut/dut.sch    -> annot_show=0     (FALSE CLEAR)
```

The adversary pass measured the same four plus a **symlinked** path, all clearing.

## 3. How a user reaches it

Not exotic. `library.defs` `DEFINE` lines with a trailing slash, symlinked PDK
library trees (common on shared installs), and any Tcl caller that composes a path
with `file join` against a directory variable that already ends in `/`. The user
sees annotation switch itself off on a re-open of the cell they are already
looking at, with no message — which reads as the annotation feature being flaky.

## 4. The fix (not implemented)

Stamp and compare the **normalised** form. The project already has the vocabulary:
`abs_sym_path()` for the C side, `file normalize` on the Tcl side. Normalise once
in `annot_show_set()` when the stamp is written and once in
`annot_show_check_root()` before the compare, so a respelling cannot separate them.
Symlinks additionally need `file normalize`'s link resolution or a `stat`-based
identity (device+inode), which is the stronger and slightly more expensive answer.

## 5. Severity

Lower than [0809](0809-the-annotation-mask-leaks-into-a-new-window-with-a-null-stamp.md):
this fails **safe** in the direction that matters for the 0683 ruling — it turns
annotation off when it should have stayed on, never on when it should be off. It
is a usability defect in the KEEP half, not a hole in the binding.

## 6. Still open

All of it.
