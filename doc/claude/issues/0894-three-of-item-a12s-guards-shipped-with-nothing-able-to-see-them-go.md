# 0894 — three of item A12's guards shipped with nothing able to see them go

**Status:** **FIXED** 2026-08-28, in the same commit as issues 0891 and 0893.
Found by the sabotage pass of backlog item A12; reproduced independently at the
write-up before anything was changed. **Test-only** — no product line moves.

## Why this is a defect and not tidying

This branch's recorded lesson is that a standing green over an unseen guard is
how two defects shipped past twenty-eight passing checks. Item A12 added guards
for issue 0891 (the everyday runner must run this suite on a real display, and
never on the human's own screen) and issue 0893 (a refusal that must not tear
down the user's own annotations). Three of them had no row that could see them
removed. Neutralize any one and the whole tree stays **`ALL PASS` in both arms,
exit 0**, with the check count unmoved.

## The three, measured

### 1. The display arm could stop routing to the virtual display and start opening windows on the user's real screen

Strip `$dd exec` out of the launch line of `tests/run_regression.tcl`'s display
loop and `tclsh run_regression.tcl` opens a full GUI xschem on whatever screen
it was started from — on this box `172.30.64.1:0`, the human's own Windows X
server, which is the exact thing `devdisplay.sh` exists to prevent.

Measured with that removal in place: headless `RESULT: ALL PASS (451 checks)`
exit 0, display `RESULT: ALL PASS (458 checks)` exit 0, **V57 still `ok`**.
(`run_regression.tcl` was deliberately *not* executed under this variant —
running it is the thing that would have flooded the screen. The dead leg was
proved with a `tclsh` replica of the row against the sabotaged file.)

**Why it was blind.** V57's routing leg grepped the **whole loop** for
`devdisplay\.sh|\$dd`, and the loop satisfies that twice over with no routing at
all: the liveness variable is named `$dd_alive`, and the sentence the runner
prints when no dev display is up literally contains the words
`tests/headless/devdisplay.sh start`. **A grep over a whole block matches the
prose about the thing as readily as the thing.**

### 2. The runner could go back to swallowing "this arm verified nothing" in silence

Revert `summarize_all`'s classifier from `^(NOGOLD|NODISPLAY)` to `^NOGOLD` —
undoing exactly what V57's sixth leg claims to pin — and a box with no dev
display reports the display arm as a bare pass with no warning. That **is**
issue 0891. Measured: headless 451 `ALL PASS`, display 458 `ALL PASS`, V57 `ok`.

**Why it was blind.** The leg read `opa_proc_src`'s slice of `summarize_all`.
`run_regression.tcl` contains exactly **one** proc, and `opa_proc_src` ends a
proc at the next `\nproc `, so the slice ran to end of file and swallowed the
display loop — whose own printed message says `NODISPLAY`. The leg was matching
the message, not the classifier.

### 3. The new refusal could start tearing down the user's own annotations

`viewerunread`'s arm depends on a stated RULING D5-1 guarantee — nothing has
been attached yet, so no unwind is owed. Give that arm a
`cadence::_annot_tran_unwind $attached $mask0` it must not have — the shape
that, on any later edit moving the arm below `set attached 1`, strips the
numbers the user already had off their schematic as part of a *refusal* — and
the tree stays green in both arms.

**Why it was blind.** **V52** is the row whose whole job is this roll-call
("which refusals must put back what the press attached, and which must not touch
it"). It enumerated six arms. `viewerunread` was the ninth refusal state and was
the only one `cadence::annot_tran` can return that V52 did not name.

## What shipped

All three are one leg each in `tests/headless/test_op_annot.tcl`; no product
change.

* **V57 leg 4** now isolates the single line in the loop that launches the
  binary and requires the routing to be on **that line**:
  `(devdisplay\.sh|\$dd)\s+exec`. Verified 1 → 0 across removal 1.
* **V57 leg 6** now slices `summarize_all` by **brace matching**
  (`opa_v_block`), not by scanning to the next `proc`, and asserts the
  alternation `NOGOLD\|NODISPLAY` that only the classifier line carries.
  Verified 1 → 0 across removal 2.
* **V52** gained a ninth leg, `[opa_v_hasunwind $V_A10_TRN2 viewerunread]`
  expecting `0`, and its header now names every state `cadence::annot_tran` can
  return: ok, nocursor, nodata, noraw, notran, staleraw, viewerdiff,
  viewerunread.

## Measured, at the close

Each removal replayed against the repaired rows, one at a time, in a `/tmp`
symlink shadow tree with the repository untouched. Every one reddens **exactly
one row and nothing else**:

| removal | before | after |
|---|---|---|
| routing off the launch line | `ALL PASS (451)` | `1 FAILED (450)` — **V57** |
| classifier back to `^NOGOLD` | `ALL PASS (451)` | `1 FAILED (450)` — **V57** |
| unwind added to `viewerunread` | `ALL PASS (451)` | `1 FAILED (450)` — **V52** |

Repaired tree: `--nogui` `ALL PASS (451 checks)` / `OVERALL: ok` / exit 0;
`devdisplay.sh exec` on `:99` (Xvfb 1920x1080x24, **openbox 3.6.1** live)
`ALL PASS (458 checks)` / `OVERALL: ok` / exit 0; `tests/run_regression.tcl`
**zero** counted failures across 38 case blocks.

## Still open, spun off

A fourth hole of the same family is **not** fixed here and is filed as **0897**:
the two plain-English enumerations that hold a refusal sentence to the user's
readability ruling are hand-maintained, with nothing asserting they cover every
state the sentence minter can render. Removing `viewerunread` from either leaves
the tree green *and does not move the check count*.
