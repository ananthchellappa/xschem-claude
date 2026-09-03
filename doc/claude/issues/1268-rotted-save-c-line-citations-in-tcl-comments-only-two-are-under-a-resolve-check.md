# 1268 — rotted `save.c:NNNN-MMMM` citations in `.tcl` comments; only **two** are under a resolve-check

**Filed** 2026-09-02 by item **A6**. **Pre-existing rot — A6 did not introduce
it**, but A6 is what exposed the mechanism. **Measured, not fixed.**

## How it surfaced

Item A6-b inserted ~96 lines into `src/save.c`, which moved
`extra_rawfile()`'s `what == 4` printer. Rows **SEL468 / SEL469** of
`tests/headless/test_results_select.tcl` **resolve** the two source comments that
cite that printer by line number, and the suite went red — **which is the design**.
The check's own prose says:

> When `save.c` moves, re-grep the `what == 4` printer in `extra_rawfile()`,
> restate the two source comments AND the two literals here; do not delete the
> check.

A6 restated `save.c:2379-2388` → `save.c:2475-2488` in `src/wave_viewer.tcl` and
`src/ase.tcl` (comment-only), verified the new window contains both anchors, and
the suite returned to ALL PASS (377 checks). **The mechanism works.**

## The defect

**About a dozen `save.c:NNNN-MMMM` citations exist in `.tcl` comments across the
tree and only those two are under a resolve-check.** The rest rot silently, and
several already have. Measured on this tree, 2026-09-02:

| citation | claims | actually at |
|---|---|---|
| `src/op_annot.tcl:385` | `get_raw_index()` at `save.c:2251-2285` | **4125** |
| `src/op_annot.tcl:447` | `save.c:2567-2600` | moved |
| `src/calculator.tcl:1635`, `:2038`, `:2042` | — | same shape |
| `src/xschem.tcl:6154` | — | same shape |
| `src/ase.tcl:5808` | — | same shape |

`src/op_annot.tcl:385` is off by **1874 lines**. A reader following it lands in
unrelated code and, worse, may "correct" the comment to describe whatever is
actually there.

## Fix shape, two options

1. **One sweep**, re-grepping each anchor and restating the range. Cheap once,
   rots again.
2. **One check** — a single test row that resolves *every* `save.c:NNNN` citation
   in `.tcl` comments the way SEL468/SEL469 resolve their two. This is the
   self-maintaining option and is the same idea as the existing resolve-check,
   generalised. It turns a class of silent rot into a red row on the commit that
   causes it.

Option 2 is recommended. Note it must resolve by **anchor text**, not by line
number alone, or it merely re-encodes the rot.

## Still open

All of it. `src/wave_viewer.tcl` and `src/ase.tcl` are correct as of this commit;
nothing else was touched.
