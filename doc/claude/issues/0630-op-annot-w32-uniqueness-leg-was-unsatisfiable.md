# 0630 — test_op_annot row W32's "no card emitted twice" leg was unsatisfiable, and green only while `save_cards` did not exist

STATUS: **FIXED 2026-08-22** by the S3 implement agent, in the same change that
landed `op_annot::save_cards`. Filed because it is exactly the class of defect
issue **0499** was written about, and because the fix is a test edit that a
reviewer must be able to find.

---

## WHAT IT WAS

`tests/headless/test_op_annot.tcl`, section W, row **W32**:

```tcl
set w32_devs [opa_w_devs $W_SHBLK]
…
[expr {[llength $w32_devs] == [llength [lsort -unique $w32_devs]]}] \
```

expected `1`.

`opa_w_devs` returns the **device path** of every card — `.save @m.x.y[gm]` →
`@m.x.y`. Section W's two descriptors (`w_nmos`, `w_nmos2`) each carry **two**
`params` rows, so every device legitimately contributes **two** cards and its
path appears **twice**. `llength devs == llength unique devs` is therefore `0`
for *any correct block*, and the row could never go green once `save_cards`
existed. Measured on the W32 fixture after S3 landed: **8 cards over 4 devices**.

It read as green in the red-report run for one reason only: `save_cards` raised,
`W_SHBLK` was set to `{}`, and `llength {} == llength {}` is 1. **A vacuous leg,
passing on an empty list.**

## THE FIX

The row's own stated claim is *"no card is emitted twice"* — which is about
**cards**, not device paths, and which a re-visited hierarchy level (the issue
0433 class-1 defect W32 exists to catch) would break by duplicating whole `.save`
LINES. One token:

```tcl
set w32_devs [opa_w_lines $W_SHBLK]
```

with a comment above it recording the arithmetic. Every other leg of W32 is
unchanged.

## WHY IT MATTERS BEYOND THIS ROW

Spec landmine 11 and issue 0499 both say the same thing from two directions: a
guardian that *cannot fail* certifies nothing, and a predicted red that does not
appear is a fixture defect. This one is the third variant — a guardian that could
only ever pass while the feature was absent, and could only ever fail once it
arrived. When writing a red test against an absent proc, check that the expected
value is reachable *by a correct implementation*, not merely different from what
the absent one returns.
