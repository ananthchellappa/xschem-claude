# 1495 — a checkout path longer than about 73 characters reds `test_op_annot` and `test_annot_hier_0911`

**STAMP:** `v1 claim=open tree=0eed8a1b stamped=2026-09-20 fix=none open=4 by=B-docs`

**Status: OPEN — filed 2026-09-20** by the stranger-reds batch, from item B's implement
round (`receipts/B-impl.md` §6.1) and its fix round (`receipts/B-verify.md` §4.7, §4.8 —
findings 13 and 14 of 14), under batch decision **D6**.
**Class** stranger-facing false red in T1: where the tree is checked out decides whether
two T1 cases pass. **Related: 1484** (an uppercase letter in the checkout path) and
**1490** (a space in it) — the same class with a different trigger **and a completely
different mechanism**; see "Why this is not filed into 1484 or 1490".

---

## What happens

Check the repository out into a deep path — a CI runner's
`/builds/<org>/<project>/<pipeline-id>/…`, a sandbox scratch root, anything past roughly
73 characters — build it, and **two T1 cases go red**. The same binary at a short path is
green. Nothing about the tree is different; only the name of a directory above it.

## Measured — four times, by four different people

| # | who | tree / binary | root | result |
|---|---|---|---|---|
| 1 | item B's implementer | **unfixed** binary, `DISPLAY` **set** | `…/scratchpad/stranger_reds/b/work`, **118** chars | `RESULT: 3 FAILED (482 passed)` — rows **N6**, **N9**, **V31b** |
| 2 | item B's implementer | same binary | `/var/tmp/x1483/w`, **16** chars | `RESULT: ALL PASS (485 checks)` |
| 3 | item B's fixer | **fixed** binary, md5 `7b0e3ec568938c40ed67730c752d9bf4`, `env -u DISPLAY --nogui` | `/tmp/vb83/w`, **12** chars | `RESULT: ALL PASS (485 checks)` |
| 4 | item B's fixer | **the same binary, copied** | `…/scratchpad/stranger_reds/b/w`, **113** chars | `RESULT: 3 FAILED (482 passed)`, `OVERALL: notok` — **N6**, **N9**, **V31b** |

Rows 1 and 2 were taken on the **unfixed** binary with `DISPLAY` **set**, which is what
proves this predates item B's work and has nothing to do with `DISPLAY`. Rows 3 and 4 are
one binary at two paths: **one binary, two paths, two verdicts.**

Both verifiers reproduced it independently as well, which is what makes this four
sightings rather than two.

The cut is visible in the `got` side (fixer's row 4):

```
got: … There is no results file at...
exp: … There is no results file at /tmp/claude-1000/…/stranger_reds/b/w/tests/headless/
     .scratch/_op_annot_488706/n_nd_empty/n_dev.raw yet. Run a simulation first.
```

## It is wider than three rows — a T1 in a long root counts 11

**MEASURED by the `completeness` verifier** (`receipts/B-verify.md` §4.7): a full T1 run
inside the assigned **111-character** scratch root closes `counted_failures=11`, and all
eleven lines are this one defect:

| what | lines |
|---|---|
| `test_op_annot` rows **N6**, **N9**, **V31b**, on **both** T1 arms (it is registered twice) | 6 |
| `test_op_annot`'s two `HARNESS` lines | 2 |
| `test_annot_hier_0911` rows **H6** and **H13** | 2 |
| `test_annot_hier_0911`'s `HARNESS` line | 1 |
| | **11** |

`test_annot_hier_0911` is named in neither the implement receipt nor the earlier
sightings; it was found by widening the measurement from one suite to a whole T1.

**Read that the right way round:** a crew that runs T1 in a long path and reports eleven
failures has found nothing — and this is not hypothetical, it is what made item B's own
gate unrunnable inside the scratch root its crew was assigned. Two crews had to move
their clones to get a green measurement, and `CREW_BRIEF.md` now tells crews to work in a
short path (`0eed8a1b`).

## The mechanism — READ at `0eed8a1b`, end to end

1. `xctx->statusmsg_text` is `char statusmsg_text[256]` in `src/xschem.h`. Its own comment
   cites issue **0248**: it is the last line `statusmsg()` actually put on the status bar,
   kept so it can be read back.
2. `proc cadence::_annot_fit` in `utils/annot_mode.tcl` returns its argument unchanged
   while it is ≤ 255 bytes; past that it shrinks a **character** window until the window
   holds ≤ 252 **bytes**, cuts back to the last space inside it (`string last { }`), and
   appends `...`. Every held status sentence on the annotation surface goes through it
   (`src/xschem.tcl` and three sites in `utils/annot_mode.tcl`).
3. The goldens compare `[xschem get statusmsg]` against a sentence that embeds an
   **absolute** path. READ in `tests/headless/test_op_annot.tcl`:
   `check {N6 …}` expects `"$A11_M1 There is no results file at [file join $N_ND_EMPTY
   n_dev.raw] yet. Run a simulation first."`, and `check {N9 …}` the same shape with
   `Could not read the results file [file join $N_ND_BAD n_dev.raw], …`. READ in
   `tests/headless/test_annot_hier_0911.tcl`: `check {H6 …}` expects `[file join $ND2
   top.raw]` and `check {H13 …}` `[file join $ND6 top.raw]`, in the identical sentence.
4. **V31b is the same cause one remove out.** It does not compare the sentence; it asserts
   `[string match "$A11_M1 There is no results file at *" $v31b2_msg]`. The cut appends
   `...` directly after `at`, leaving no space for the `*` to bind to — which is exactly
   what the `got:` line above shows.

**The threshold, INFERRED and approximate.** The implement receipt measures the fixed
prefix at 83 bytes and the suffix at 29, so the sentence survives only while the absolute
path stays under about 143 bytes — i.e. while the clone root stays under about 73
characters, the remainder being `…/tests/headless/.scratch/_op_annot_<pid>/…/n_dev.raw`.
⚠ **That figure is arithmetic, not a measurement**, and the scratch directory name carries
a pid whose width varies. **The measured facts are the four endpoints above: green at 12
and 16 characters, red at 113 and 118.** Nobody has bisected the boundary.

## Why this is not filed into 1484 or 1490

It is the same **class** — a stranger's checkout path reds a suite that has nothing to do
with paths — and a completely different **cause**:

| | 1484 / 1490 | this file |
|---|---|---|
| trigger | an uppercase letter · a space | **length** |
| where it breaks | an ngspice control line in `sp_export_lines`, `src/ase.tcl` | a status-bar sentence truncated by `cadence::_annot_fit` |
| suites | five `test_ase_*` | `test_op_annot`, `test_annot_hier_0911` |
| product side | a real user defect — an S-parameter export lands somewhere else | **arguably correct**: the elision is ratified (A11-12b) |
| fix side | product | **test** |

A fix for either of those does nothing for this one. Filing them together would put a
status-bar truncation inside a file whose title says "a space", and would hide the one
member of the family whose product side is *not* the defect.

## ⚠ Do not "fix" this by widening `statusmsg_text`

Cutting the file name out of an over-long status line is **ratified behaviour** — ruling
**A11-12b**, and `utils/annot_mode.tcl` records the choice in its own comment: the CIW
gets the sentence whole, the held status line gets it through `_annot_fit`, *"nothing is
dropped from the record, and the bar shows a marked elision instead of an amputation."*
The defect is that five test goldens hard-code a string whose length depends on where the
tree was checked out.

## Fix direction

1. **Fix the five rows.** Assert `[file tail $path]`, or compare against
   `cadence::_annot_fit`'s own output, rather than the raw absolute path — `test_op_annot`
   **N6**, **N9**, **V31b** and `test_annot_hier_0911` **H6**, **H13**. Comparing against
   `_annot_fit`'s output keeps the sentence's full text as the subject at short paths and
   stays correct at long ones; `[file tail …]` is simpler and gives up the path assertion.
   Either is defensible; say which and why.
2. **Sweep for siblings, by pattern rather than by this list.** Any golden anywhere that
   compares `[xschem get statusmsg]` against a sentence containing an absolute path has
   this defect at *some* path length. Five rows in two suites is what a 113-character root
   happened to reach.
3. **Give it a guard that does not depend on the checkout path.** A row that builds a
   sentence past 255 bytes deliberately and asserts the marked elision is a test of the
   ratified behaviour; a row that trips over it by accident is this bug.
4. **Bisect the boundary once**, so the ~73 above stops being arithmetic. It is cheap —
   one binary, a loop over nested directory names — and it turns the threshold from
   INFERRED into MEASURED.

## Still open (4)

1. The five rows still embed absolute paths; nothing is fixed.
2. No sweep for other goldens of the same shape.
3. No path-independent guard, so a recurrence is invisible to any T1 taken at a short path
   — which is every green T1 ever taken.
4. The ~73-character threshold is INFERRED arithmetic; only the four endpoints are
   measured.

## Evidence

`doc/claude/stranger_reds_batch/receipts/B-impl.md` §6.1 (the first two measurements, on
the unfixed binary with `DISPLAY` set) and its fix-round correction (*"§6.1 is narrower
than the defect"*, which adds `test_annot_hier_0911` and the count of 11);
`receipts/B-verify.md` §4.7 and §4.8 (findings 13 and 14, and the one-binary-two-paths
run); `DECISIONS.md` **D6**; `CREW_BRIEF.md` at `0eed8a1b` (the short-path rule this
defect produced). Source READ at `0eed8a1b`: `statusmsg_text` in `src/xschem.h`,
`proc cadence::_annot_fit` in `utils/annot_mode.tcl`, and the five named rows in
`tests/headless/test_op_annot.tcl` and `tests/headless/test_annot_hier_0911.tcl`.
