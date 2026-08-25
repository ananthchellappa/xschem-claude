# 0811 — only `load_schematic()` got 0688's deterministic clear; every other root-sheet move is a LAGGED clear

STATUS: **OPEN — measured 2026-08-25 on the committed 0688 fix, filed not fixed.**
FOUND IN: `src/save.c` `load_schematic()` tail (the deterministic seam),
`src/actions.c` `annot_show_sync_cache()` (the lazy backstop).
RELATED: [0688](0688-the-annotation-mask-outlives-the-schematic-so-window-keyed-binding-cannot-hold.md),
[0808](0808-y5-l22-l24-claim-to-pin-the-load-schematic-seam-and-do-not.md)
(the mirror-image finding: the seam the suite thinks it pins is already covered by
the backstop), [0809](0809-the-annotation-mask-leaks-into-a-new-window-with-a-null-stamp.md).

---

## 1. The defect

0688 placed `annot_show_check_root()` at two sites and called them by different
names in its own comments: the `load_schematic()` tail is *"THE DETERMINISTIC
SEAM"*, so `xschem get annot_show` reads 0 the instant a load returns, and
`annot_show_sync_cache()` is *"THE BACKSTOP"* for root changes that never run
`load_schematic()`.

**Only `File > Open` got the deterministic half.** Every other way the root sheet
moves — `Save As`, `clear_schematic()`'s in-place fresh-untitled compose
(`save.c:4850`) — rides the backstop, which fires on the next bulk evaluation and
not before. Between the root move and that evaluation, every reader sees a mask
that belongs to a sheet that is gone.

## 2. The measurement

Write-up agent, 2026-08-25, `--nogui`:

```
WU| after saveas       sch0=sa.sch   annot_show=3  root=dut.sch     <<< stale, root moved
WU| after bulk eval                  annot_show=0  root=
```

`xschem saveas` moved `sch[0]` to a different file and left the mask at 3 with a
stamp naming the old one. It clears only once something calls
`update_all_sym_bboxes` (or any of the other seven `annot_show_sync_cache()`
sites).

## 3. Why the window is real and not theoretical

Under `--nogui`, and on any export-only or scripted path, a bulk evaluation may
never happen at all before a reader looks. The readers that look are exactly the
ones this fix was written for: the ASE-L menu PULL half (`test_op_annot` N22c
reads the mask that way), and every scripted `xschem get annot_show`.

⚠ Note the mirror-image finding in **0808**: for `xschem load` the backstop is
*already* sufficient, because the load itself reaches `calc_drawing_bbox()`
(`actions.c:4983`) whose third statement is `annot_show_sync_cache()`
(`actions.c:4994`). So the seam that WAS added is partly redundant, while the
seams that were NOT added are the ones with a real lag. The two issues should be
read together and fixed in one pass.

## 4. The fix (not implemented)

Call `annot_show_check_root()` at each site that moves `xctx->sch[0]` —
`clear_schematic()` and the save-as path — or, better and smaller, at the ONE
place `sch[0]` is written, so the check cannot be forgotten by the next feature
that moves the root. Then decide, with 0808 in hand, whether the `load_schematic()`
call is still earning its place or should be dropped as redundant defence.

## 5. Still open

All of it.
