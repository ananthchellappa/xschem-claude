# Issue 1641 -- FE8 repaired red-first, and the `dcases` registration derived
Four crews: a fixer, two adversaries in worktrees, and a closer that also prepared the
registration. The registration edit is left UNCOMMITTED in the working tree for the driver
to gate; `src/` was never touched by any of them.


## fix:fe8

**findings**

[]

**red_first_row**

Row **`FE8a`**, added to `/home/analog/dev/xschem-claude/tests/headless/test_fluid_editing.tcl` FIRST, with FE8's press point left exactly as it was (`lassign [sch2scr 1286.6 -50] ex ey`). It reads `xschem get lastsel` immediately after `gpress` and asserts the press selected something, and its detail is produced by a new proc `arc_press_diag`, which inverts the press pixel through a new `scr2sch` and states where it landed in the terms the two hit tests use.

Verbatim red, display arm, `tests/headless/run_suites.sh test_fluid_editing` (the unmodified-product suite, only the row added):

```
FAIL     | test_fluid_editing           run 1/1  RESULT: 2 FAILED (25 passed)
         | FAIL: FE8a the press SELECTED the arc (lastsel=1), so the gesture below ran at all (lastsel=0 -- 0 means THE PRESS SELECTED NOTHING, so no gesture happened and FE8's verdict says nothing about the false-clean; press px (421,344) -> sch (1290.0,-43.3): angle 25.7 vs span 30..120, r 99.9 vs 100, clear of the a+b handle box by 0.69 px) : FAIL
         | FAIL: FE8 drag-and-return changed the arc AND left buffer MODIFIED (no false-clean) (mod=0 a=30; a=30 is the arc's STARTING angle, so a=30 with lastsel=0 means the gesture never happened, NOT a false-clean; press px (421,344) -> sch (1290.0,-43.3): angle 25.7 vs span 30..120, r 99.9 vs 100, clear of the a+b handle box by 0.69 px) : FAIL
RESULT: 0/1 runs passed
```

Two things that red bought beyond the row itself. The detail now prints the CAUSE — `angle 25.7 vs span 30..120` — instead of the sentinel `a=30` that cost the diagnosis a day; and FE8's own detail was rewritten to carry `lastsel` plus the same aim string, so `a=30` can never again be read as a false-clean. The new figure `clear of the a+b handle box by 0.69 px` is also the measurement that killed the obvious fix (see `fix`).

**fix**

Only the press point moved, and it is now **computed from the arc**, not written down. New proc `arc_a_press_px` returns the pixel for the `a` control point of whatever arc is in the buffer, at the live zoom:

```
R   = r + 4*zoom                      ;# 4 px OUTWARD along the radius
dth = asin(0.71*zoom/R)               ;# angular size of one pixel's worst-case rounding
ang = a + 2*dth                       ;# bias INWARD by twice that
press = sch2scr(polar(centre, R, ang))
```

The drag-away point is derived the same way (same R, at `a+b`). Row FE8's own `zoom_box` is untouched.

Why this spelling and not a bigger zoom or a looser tolerance:

* **A bigger zoom makes it worse, not better, and that is measured.** `find_closest_arc`'s radial threshold is `CADWIREMINDIST*CADWIREMINDIST * zoom*zoom * tk_scaling*tk_scaling` — it grows as you zoom out — while its span test is `angle >= angle1 && angle <= angle2` with no tolerance term at all. Derived over `src/findnet.c`: every one of `find_closest_wire`, `find_closest_polygon`, `find_closest_line`, `find_closest_arc` and `find_closest_box` carries `xctx->zoom` in its threshold; `find_closest_arc` is the only one that then adds a **zoom-independent** predicate. So zooming is the axis along which this row breaks. Zooming *in* would also change what the row measures: `edit_arc_point`'s handle half-size is `ds = cadhalfdotsize*2*zoom`, and the zoom-out is what puts the press inside the handle at all.
* **A looser tolerance is not available to loosen** — the row's predicate is `mod == 1 && a != 30`, with no epsilon to widen except `feq`'s 1e-6, which is not where the failure is.
* **The honest lever is the SIGN of the rounding error**, exactly as the diagnosis said. Measured at this row's zoom (17.316): the arc's own endpoint `(1286.6,-50)` rounds to pixel `(421,344)`, which maps back to 25.7° on a span of 30..120 — 4.3° outside its own arc.
* **The radial `+4 px` is not padding, it is forced, and I only found that by measuring.** `edit_arc_point` tests the `a+b` handle box FIRST, so a press inside it grabs `SELECTED3` and changes `b`, leaving `a` at 30 — the row would fail for a *different* reason. At this zoom `ds` = 128.1 schematic units against a radius of 100, so the two handle boxes overlap almost the whole arc: on the ring, escaping the `a+b` box needs angle < 38.7°, while one pixel is ~7°. The old press point had only **0.69 px** of clearance there (printed in the red above). Going outward in radius both shrinks the per-pixel angle and pushes x clear: the press now has **12.08° of span margin against 5.89°/px = 2.05 px**, and sits inside the `a` handle box and inside the radial slack, i.e. it is a real control-point grab.
* I also corrected three comments that stated the opposite of the measurement, rather than leaving prose copies lying: the band header's *"needs that zoom to select reliably"*, the `zoom_box` line's *"precise-enough endpoint select"*, and the file header's *"safe to register in hcases"* (which the issue names as how the registration mistake happened) plus its bare `./src/xschem` run instruction, now `tests/headless/run_suites.sh test_fluid_editing`.
* `cad_ds` reads `cadhalfdotsize` from `xschem globals` rather than restating `CADHALFDOTSIZE`: it moves with `cadsnap` via `set_dotsize_from_snap`, so a copy in the test would be a number nothing re-checks.

**green_proof**

DISPLAY arm, `tests/headless/run_suites.sh test_fluid_editing` (no `--nogui`; attached to the dev Xvfb `:99`, throwaway HOME, `AUDIT_SCREEN` left at its default):

```
PASS     | test_fluid_editing           run 1/1  RESULT: ALL PASS (27 checks)
RESULT: 1/1 runs passed
```

Soaked on the same arm, `run_suites.sh -n 4 test_fluid_editing` — four consecutive `RESULT: ALL PASS (27 checks)`, `RESULT: 4/4 runs passed`; then `-n 2` again after the comment corrections, 2/2. The press is deterministic, not a coin-flip.

Raw capture of the same arm scored with T1's own readers lifted from `tests/banner_rule.tcl` (`banner_complete`, `banner_died`, `regression_case_failed`): 27 `ok:`/`FAIL:` rows, exit 0, `banner_complete=1`, `banner_died=0`, `regression_case_failed=0`, last `RESULT: ALL PASS (27 checks)`.

**both_arms**

Both arms re-measured after the final edit, each captured raw and scored with `tests/banner_rule.tcl`'s own procs.

| | DISPLAY arm | `--nogui` arm |
|---|---|---|
| rows that ran (`^ok:`/`^FAIL:`) | **27** | **0** |
| exit code | 0 | 0 |
| last `RESULT:` | `RESULT: ALL PASS (27 checks)` | `RESULT: SKIP (no X)` |
| `banner_complete` | **1** | **1** |
| `banner_died` | 0 | 0 |
| `regression_case_failed` | **0** | **0** |
| lowercase `^skip:` / uppercase `^SKIP` | 0 / 0 | 0 / **1** |

So: `banner_complete` is satisfied on BOTH arms, and the display arm is now registerable — the `banner_complete=0` the issue recorded was the FE8 failure, nothing structural. The `--nogui` arm is byte-unchanged in shape: still 0 rows, still `OVERALL: ok`, still the UPPERCASE skip that `summarize_all` does not count, so it still adds 0 to `skips=`. Row count moved 26 → 27 (one added row, confirmed as 27 `^check ` call sites in the file).

**Registration was deliberately NOT changed.** The suite is still `hcases` only; `tests/run_regression.tcl` is untouched. That is issue 1641's open item 2 and it is the driver's gate to run — the figures above are what it needs: a `dcases` entry would now score `banner_complete=1`, exit 0, `regression_case_failed=0`, cost +1 case / +1 block / +0 counted / +0 `skips`, and the `hcases` entry stays as the crash guard.

**why_not_a_tolerance_loosening**

Measured, not argued. A probe reproduced FE8's band three times and evaluated **FE8's and FE8a's own predicates** over each resulting state (`probe_discriminate.tcl` in the scratch dir):

```
state        measured                 | the two rows' OWN predicates (1=pass)
real        lastsel=1 mod=1 a=73  | FE8a predicate=1  FE8 predicate=1
falseclean  lastsel=1 mod=0 a=73  | FE8a predicate=1  FE8 predicate=0
missed      lastsel=0 mod=0 a=30  | FE8a predicate=0  FE8 predicate=0
```

The `falseclean` state is the defect FE8 exists for: the arc really changed (a 30 → 73) and the buffer was then marked clean. **FE8 goes FALSE there** — the row still catches its own defect, so it is not a hole. (The state is reached through `saveas`, the only lever a test has on `modified`; the product bug reached the same state through the release-cell no-op test. I could not re-introduce the product bug because `src/` is off-limits, so I reproduced its *state* instead and said so.)

The `missed` row uses the OLD hardcoded press point and is the red I shipped first: FE8a goes false and names the cause. So the pair now **discriminates** the two states that were previously the same string — which is strictly more measurement than before, not less.

Three further reasons this is a tightening:

1. The widened thing is the *press point*, and it was widened **away from** the margin, not toward it: 0.69 px → 2.05 px of clearance from the wrong handle, 25.7° (outside) → 42.1° (12.08° inside the span). Nothing the row asserts became easier to satisfy.
2. The predicate is unchanged: `mod == 1 && ![feq $a 30]`. `a` is still required to move, and it still has to be the **`a`** control point — the radial offset is what guarantees `SELECTED2` rather than `SELECTED3`, so a press that drifted onto the other handle (b changes, a stays 30) is still a FAIL, and the detail now says why.
3. A new row was added, so the suite asserts one thing more than it did. `a` changing is non-vacuous and understood: `move_objects`'s arc arm computes `angle = my_round(fmod(atan2(-deltay, deltax)*180/PI + a, 360))`, and the move reference is the arc's CENTRE, so a net-zero mouse drag still yields `a_new = round(a + angle_of(press - centre))` ≈ 73. That is precisely the mechanism FE8's comment describes, and it is why the drag target is irrelevant (measured: three different drag targets all give a=73).

**product_untouched**

`git status --porcelain src/` is **empty**. `src/` was not touched, and the diagnosis's finding stands: the behaviour FE8 fences is intact (the `real` row of the table above — `mod=1` after a drag-and-return that changed the arc).

`git diff --stat`:

```
 doc/claude/specs/fluid_editing.md      |  14 ++-
 tests/headless/test_calc_measure.tcl   |  45 ++-
 tests/headless/test_calc_wave_dest.tcl | 498 +++++++++++++++++++++++++++++++--
 tests/headless/test_fluid_editing.tcl  | 110 ++++++-
```

Mine are the first and last. `test_calc_measure.tcl` and `test_calc_wave_dest.tcl` were already modified in the working tree when I started (they are in the session-start git status, a sibling crew's work) — I did not open or touch either.

Files I changed, absolute:
* `/home/analog/dev/xschem-claude/tests/headless/test_fluid_editing.tcl` — new `scr2sch`, `cad_ds`, `arc_press_diag`, `arc_a_press_px`; new row `FE8a`; FE8's press point derived and its detail made cause-naming; three comments corrected where they stated the opposite of the measurement.
* `/home/analog/dev/xschem-claude/doc/claude/specs/fluid_editing.md` — it carried a dead `(26 checks)`. Per this repo's rule I **dropped the number** rather than updating it to 27 (the `RESULT:` line is where it is recomputed every run), and added the `hcases`-only / zero-rows fact with a pointer to 1641's open item 2 and the armed run spelling.

Not touched: `tests/run_regression.tcl`, the `owed.sh` ledger, `~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display`, `~/.claude/gui_test_gate`, any `/tmp/xschem_emergencysave_*`, `~/dev/xschem-op-wcard`. No commit, no push, no full T1. `devdisplay.sh start|stop|view` never run (every run attached to the already-live `:99` through `run_suites.sh`). Scratch is 88K under the session scratchpad and leaves nothing in `/tmp`.

**other_rows**

**Yes — four other press sites, in three rows, sit on the same zero-tolerance predicate with about HALF A PIXEL of margin.** Derived three ways, not eyeballed.

**1. Population, from the suite's own text** (scan for `xschem zoom_box|zoom_full|zoom_in|zoom_out` and for `gpress|grab_drag` in **command position** — bare-word scanning would have counted prose; `clear force` does not reset zoom, so a zoom_box is in effect for every later line): 16 command-position press lines, of which one is the `gpress` inside `proc grab_drag`'s own body, giving **15 call sites**. Exactly **2 run with a suite-set zoom** — FE7's body drag and FE8's press — and 13 at the pristine default zoom. 27 check rows, of which 4 sit under a zoom (FE7's one, FE8's three).

**2. Mechanism, from `src/findnet.c`**: the thresholds of `find_closest_wire`, `find_closest_polygon`, `find_closest_line`, `find_closest_arc` and `find_closest_box` all carry `xctx->zoom`, so a rounding error of a fixed number of *pixels* is measured against a tolerance of a fixed number of *pixels* — zoom-invariant. `find_closest_arc` alone adds `angle >= angle1 && angle <= angle2` with **no tolerance term**. So this fragility class can only arise where a press has to satisfy an arc span test — i.e. at an arc press, whatever the zoom.

**3. Measurement, over all 15 press sites**: I ran an instrumented copy of the suite that wraps `gpress` and records, for every press, the pixel, the zoom, `lastsel` immediately after, and (where an arc is in the buffer) the round-trip angle, its margin to each span end, and the angular size of one pixel at that radius.

* **0 of 15 presses selected nothing.** No other row is broken today.
* The four genuine arc-endpoint presses — entries 4, 5, 9 and 10, i.e. **FE3, FE3c and FE6 (two presses)** — land at `press_angle=0.09` on a span of `0..90` with `one_px=0.17 deg`. That is **0.53 px of margin** on the predicate with no tolerance. They pass only because the rounding sign points *inward*, which is exactly the asymmetry the diagnosis identified for the `a=0` fixture arc. It is also a property of the current window size, since zoom and origin derive from it.
* FE8 after the fix: `margin_to_a=+12.08` against `one_px=5.89 deg` = **2.05 px**.
* The eight entries showing `press_angle` near 180 are rect/line presses — my instrumentation annotates the only arc in the fixture for every press; those presses select the rect or line, not the arc, and no span test is in their path.
* FE7, the other zoomed press, has no arc in its fixture and every predicate it must satisfy is in pixels (`find_closest_box`'s threshold, `edit_rect_point`'s `ds` bands). From its own constants — W = 20 px, H = 8 px, ds = 7.4 px, pressed at the centre — its clearance from the left/right edge bands is 10 − 7.4 = **2.6 px** against ≤0.5 px of rounding. Not this class of fragility.

**I did not change FE3/FE3c/FE6.** They are green and deterministic at the pinned screen size, there is no red to lead with, and re-aiming three more rows on a hunch is the move this task warns against. `arc_a_press_px` is in the file and applies to them unchanged (at the default zoom it would give them ~0.7 px of guaranteed margin instead of a sign that happens to favour them). I recommend it as a follow-up on 1641's open item 1, and note that open item 3 — `find_closest_arc`'s zoom-scaled radial slack with zero angular slack — is the product-side root of all four.



## attack:false-clean

**sabotage**

ASSIGNED SABOTAGE (false-clean), and what it took to make it real.

Site: `end_shape_point_edit` in `src/callback.c` — the proc whose own comment records the defect FE8 was written for: *"This replaces an older 'release cell == press cell' test that assumed the move reference is the mouse -- false for an arc, whose START reference is the arc CENTER, so a drag-and-return would silently change the arc yet reset the modified flag to clean."* The shipped line is `int moved = (xctx->deltax != 0.0 || xctx->deltay != 0.0);` and `if(!moved) set_modify(save);` is what restores the pre-gesture flag.

**S1 — the false-clean, reverted to the historical test.** Replaced `moved` with the release-cell==press-cell comparison. The arc still changes: `move_objects`' END arc `SELECTED2` arm computes `angle = my_round(fmod(atan2(-deltay, deltax)*180/PI + a, 360))`, and `move_objects(START)` sets `xctx->x1,y1` to the arc CENTRE for an arc whose `sel != SELECTED`, so the centre-relative delta is nonzero even for a net-zero MOUSE drag. `moved` reads 0, `set_modify(save)` runs with `save == 0`, and the buffer reports CLEAN after a real geometry change. Exactly the lost-edit-on-close-without-save state.

⚠ **MY FIRST SPELLING OF S1 WAS A SILENT NO-OP AND IT "PASSED". Reporting a SURVIVED on it would have been wrong.** `mx_double_save`/`my_double_save` hold the UNSNAPPED press point on this path while `mousex_snap`/`mousey_snap` are cadsnap-quantised, so the bare comparison was never true. I instrumented the proc to dump `press`, `rel`, `delta` and both spellings of `moved` to a file for every one of the suite's nine `end_shape_point_edit` calls, and it printed `moved_SABOTAGED=1 moved_SHIPPED=1` on all nine — the sabotage never fired. Snapping the press point with the product's own rule (`my_round(mx_double_save/cadsnap)*cadsnap`, `cadsnap` read via `tclgetdoublevar`) made it fire on exactly one gesture, FE8's: `press=(1320,-110) rel=(1320,-110) delta=(120,-110) moved_SABOTAGED=0 moved_SHIPPED=1`. **A green run against a sabotage proves nothing until the sabotage is witnessed firing.**

**S2 — the literal wording of the assignment** ("bump the counter the row reads without actually moving the arc's endpoint"): in `move.c`'s arc `SELECTED2` arm, dropped the `xctx->arc[c][n].a = angle;` commit. The delta is still nonzero, so `moved` is 1 and the END tail still calls `set_modify(1)` — a modification reported that did not happen.

**S3 — the hole probe, and the one that matters.** Same arm, kept `set_modify(1)` and the change, but committed a constant garbage angle (`a = 7.0`) instead of the computed one. The arc moves, the flag is honest, and the value is wrong.

Scope: `src/` reverted to pristine (`git status --porcelain src/` empty) and the baseline re-measured green afterwards. Nothing committed or pushed, `tests/run_regression.tcl` untouched, ledger untouched. ⚠ The worktree arrived parked on `052b29f1`, a commit that does not contain `tests/headless/test_fluid_editing.tcl` at all; I reset my own worktree branch to `fluid-editing` (82711083), built from scratch, and copied in the fixer's repaired suite from the main working tree (it is still an uncommitted modification there), so every figure below is against the fixer's actual repaired row.

**verdict**

CAUGHT — but with two findings the driver needs, one of which is that a neighbouring sabotage SURVIVED all 27 rows, and the other that this catch is invisible to T1 today.

**evidence**

All runs: `tests/headless/run_suites.sh test_fluid_editing` (no `--nogui`), attached to the dev Xvfb `:99`, throwaway HOME, `AUDIT_SCREEN` at its default. `$DISPLAY` (the user's Windows screen) was never used.

=== BASELINE: pristine product + repaired suite ===
```
PASS     | test_fluid_editing           run 1/1  RESULT: ALL PASS (27 checks)
RESULT: 1/1 runs passed
```

=== S1 FALSE-CLEAN, display arm, 3 consecutive runs — CAUGHT, DETERMINISTIC ===
```
FAIL     | test_fluid_editing           run 1/3  RESULT: 1 FAILED (26 passed)
         | FAIL: FE8 drag-and-return changed the arc AND left buffer MODIFIED (no false-clean) (mod=0 a=73; a=30 is the arc's STARTING angle, so a=30 with lastsel=1 means the gesture never happened, NOT a false-clean; press px (423,340) -> sch (1324.7,-112.6): angle 42.1 vs span 30..120, r 168.0 vs 100, clear of the a+b handle box by 2.69 px) : FAIL
FAIL     | test_fluid_editing           run 2/3  RESULT: 1 FAILED (26 passed)
         | FAIL: FE8 drag-and-return changed the arc AND left buffer MODIFIED (no false-clean) (mod=0 a=73; ...) : FAIL
FAIL     | test_fluid_editing           run 3/3  RESULT: 1 FAILED (26 passed)
         | FAIL: FE8 drag-and-return changed the arc AND left buffer MODIFIED (no false-clean) (mod=0 a=73; ...) : FAIL
RESULT: 0/3 runs passed
```
`mod=0 a=73` is the false-clean verbatim: the arc moved 30 -> 73 and the buffer was reported clean. FE8a passed in the same run (`lastsel=1` in the detail), so the pair discriminated this from a missed click — which is what FE8a was added for, and it earned its place here.

=== ⚠ S1 STILL LIVE, `--nogui` arm — the ONLY arm T1 runs ===
```
SKIP     | test_fluid_editing           run 1/1 (self-skipped: no X — nothing ran)
RESULT: 0/0 runs passed (1 skipped)
```
exit 0, nothing measured. `/usr/bin/grep -c fluid_editing tests/run_regression.tcl` = **1**, at line 35, inside `set hcases [list` (line 27); `set dcases` begins at line 682. **So the false-clean FE8 catches three times out of three would pass T1 today.**

=== S2 SPURIOUS DIRTY (arc not moved, modification reported) — CAUGHT, by TWO rows ===
```
FAIL     | test_fluid_editing           run 1/1  RESULT: 2 FAILED (25 passed)
         | FAIL: FE3 arc start angle a CHANGED off 0 (arc=1200 0 100 0 90) : FAIL
         | FAIL: FE8 drag-and-return changed the arc AND left buffer MODIFIED (no false-clean) (mod=1 a=30; a=30 is the arc's STARTING angle, so a=30 with lastsel=1 means the gesture never happened, NOT a false-clean; press px (423,340) -> sch (1324.7,-112.6): angle 42.1 vs span 30..120, r 168.0 vs 100, clear of the a+b handle box by 2.69 px) : FAIL
RESULT: 0/1 runs passed
```

=== ⚠⚠ S3 GARBAGE ANGLE (a = 7.0 constant, on EVERY arc control-point drag) — SURVIVED ===
```
PASS     | test_fluid_editing           run 1/1  RESULT: ALL PASS (27 checks)
RESULT: 1/1 runs passed
```

=== AFTER REVERT: product pristine, baseline re-measured ===
```
PASS     | test_fluid_editing           run 1/1  RESULT: ALL PASS (27 checks)
RESULT: 1/1 runs passed
```

=== THE EXPECTED ANGLE IS DERIVABLE, so the missing row is cheap ===
`move_objects`' arc `SELECTED2` arm against the snapped release and the arc centre:
```
deltax,deltay = 120.0 -110.0
atan2 term    = 42.5104
a + term      = 72.5104
my_round      = 73        <- exactly the a=73 the product produced
```
The suite already holds every piece: `scr2sch` inverts the press pixel, `cad_ds` shows the idiom for reading a product global (`cadhalfdotsize`) so `cadsnap` comes the same way, and `arc_press_diag` already computes the angle it prints as `42.1`. The snapped release, not the unsnapped press, is what `move_objects` consumes — that is the one subtlety.

**which_row_caught_it**

**Row `FE8`** — `tests/headless/test_fluid_editing.tcl`, predicate `$fe8_mod == 1 && ![feq $fe8_a 30]` — caught the assigned false-clean, 3/3, deterministically, printing `mod=0 a=73`. Row **`FE8a`** (the fixer's new row) passed alongside it with `lastsel=1`, and that is what makes the catch readable rather than ambiguous: the pair separates "the fence broke" from "the click missed". S2 was caught by **FE8 and FE3** together. **The repair is a real fence, not decoration.**

THREE FINDINGS THE DRIVER NEEDS, ranked.

**1. ⚠⚠ The catch does not reach the gate. This is the most important line in this receipt.** `test_fluid_editing` is still `hcases`-only; the registration was deliberately left for the driver (the fixer says so). Measured above: with the false-clean live in the product, the `--nogui` arm self-skips, exit 0, nothing measured — T1 is green. So **the only thing standing between this false-clean and a silent landing on the branch the user shares publicly is issue 1641's open item 2.** The fixer's `both_arms` table supplies what the registration needs (`banner_complete=1`, exit 0, `regression_case_failed=0`, +1 case / +1 block / +0 counted / +0 `skips`) and my runs re-confirm the display arm is green on a pristine product. FE8 is now a fence that works and is wired to nothing.

**2. ⚠⚠ A HOLE: no row in the suite asserts the arc's resulting angle — only that it left its start value.** S3 committed a constant `a = 7.0` for every arc control-point drag, at every zoom, on every arc, and all 27 rows passed. Derived over the suite's own arc assertions, there are exactly three and every one is satisfied by any wrong-but-different value:
* `FE3 arc start angle a CHANGED off 0` — `![feq $aa 0]`, and 7 != 0.
* `FE8 ... (no false-clean)` — `mod == 1 && ![feq $a 30]`, and 7 != 30.
* `FE3c undo restores the arc to (1200,0) r=100 a=0 b=90` — asserts the *undone* state, so it passes whatever the drag committed.

This is CLAUDE.md's *"prefer asserting the correct shape over asserting a wrong one's absence"* at the arc-angle site. **The row that would catch it:** extend FE8 (and FE3) from `a != start` to `a == my_round(start + atan2(-(rel_y - cy), rel_x - cx)*180/PI)`, with `rel` the cadsnap-snapped release in schematic units. The arithmetic is verified above (73, matching the product exactly) and every helper is already in the file, so this is one `expr` and a `cadsnap` read, not a new instrument. Note this widens two published check counts if split into new rows — which is not a baseline, per the `test_calc_wave_dest` precedent in CLAUDE.md where a crew's choice to leave a sabotage unfenced for that reason was overruled.

**3. The repaired detail asserts a counterfactual in the exact state the row exists to catch.** Its prose is unconditional, so in the S1 red it reads *"a=30 is the arc's STARTING angle, so a=30 with lastsel=1 means the gesture never happened, NOT a false-clean"* while printing `a=73` — i.e. in the one state FE8 is for, the detail tells the reader the gesture never happened. FE8's whole justification was that the bare `a=30` cost a day of diagnosis; the cause-naming prose should be gated on `[feq $fe8_a 30]` so it fires only where it is true, and say *"a MOVED (30 -> $fe8_a) with mod=0: this IS the false-clean"* otherwise. Cosmetic, but it is a comment-shaped number that nothing re-checks, in the detail written to stop exactly that.



## attack:press-misses

**sabotage**

**Press-misses, against the repaired `test_fluid_editing` (fixer's file copied into my worktree unchanged, `src/` untouched, product = the main checkout's built binary `XSCHEM=/home/analog/dev/xschem-claude/src/xschem`, verified newer than every tracked `.c`/`.h` and identical source).**

Four spellings, all in `tests/headless/test_fluid_editing.tcl` only, at the one line the fix introduced (`lassign [arc_a_press_px] ex ey`):

* **A — the shipped bug verbatim**: replaced the derived press with the old hardcoded one, `lassign [sch2scr 1286.6 -50] ex ey`. (The other spelling the task offers, "restore the zoom the original row used", is not available: `xschem zoom_box -6000 -6000 6000 6000` is the zoom the original row *already* used and the fix left it untouched — the fix moved the press, not the zoom.)
* **B — one pixel**, `incr ey 1` (toward the arc's start angle; measured as the most angle per pixel of the four single-pixel nudges).
* **B2/C — two and three pixels**, `incr ey 2` / `incr ey 3`, to find where the press actually leaves the arc.
* **D — not assigned, found while aiming**: `incr ex -3`, three pixels the other way, which puts the press **inside the `a+b` control-point handle box**. The press then *does* select, but grabs the wrong handle.

To aim these honestly rather than by eye I ran one throwaway probe row that printed the live geometry through the fix's own `arc_press_diag` (removed again; raw output kept at `/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/I1641/adv-press-misses/probe.txt`):

```
zoom=17.31601731601732 press=(423,340)
 DERIVED:        angle 42.1 vs span 30..120, r 168.0, clear of the a+b handle box by  2.69 px
 y+1:            angle 37.4                               2.69 px
 y+2:            angle 32.0                               2.69 px
 y+3:            angle 25.9   <-- OFF the span             2.69 px
 x-2:            angle 51.3                               0.69 px
 x-3:            angle 57.1                              -0.31 px  <-- INSIDE the a+b box
 OLD-HARDCODED:  angle 25.7   <-- OFF the span            0.69 px
```

So the repair bought **12.1 degrees of span margin = about 2.5 px**, and the one-pixel nudge the task names does not reach the defect: at `y+1` the press is still at 37.4 degrees on a 30..120 span, i.e. **still on the arc**. It takes **three** pixels. That is a measurement of the margin, not a hole — and I say it plainly because "nudge by one pixel, it passed" would otherwise read as a survival.

**verdict**

CAUGHT

**evidence**

All runs through `tests/headless/run_suites.sh test_fluid_editing` (no `--nogui`), each reporting `display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0` and a throwaway HOME. `AUDIT_SCREEN` left at its default. Never a bare binary.

**BASELINE (repaired suite, unsabotaged) — exit 0**
```
PASS     | test_fluid_editing           run 1/1  RESULT: ALL PASS (27 checks)
RESULT: 1/1 runs passed
```

**SABOTAGE A — the shipped bug's hardcoded press point — exit 1, CAUGHT**
```
FAIL     | test_fluid_editing           run 1/1  RESULT: 2 FAILED (25 passed)
         | FAIL: FE8a the press SELECTED the arc (lastsel=1), so the gesture below ran at all (lastsel=0 -- 0 means THE PRESS SELECTED NOTHING, so no gesture happened and FE8's verdict says nothing about the false-clean; press px (421,344) -> sch (1290.0,-43.3): angle 25.7 vs span 30..120, r 99.9 vs 100, clear of the a+b handle box by 0.69 px) : FAIL
         | FAIL: FE8 drag-and-return changed the arc AND left buffer MODIFIED (no false-clean) (mod=0 a=30; a=30 is the arc's STARTING angle, so a=30 with lastsel=0 means the gesture never happened, NOT a false-clean; press px (421,344) -> sch (1290.0,-43.3): angle 25.7 vs span 30..120, r 99.9 vs 100, clear of the a+b handle box by 0.69 px) : FAIL
RESULT: 0/1 runs passed
```
The exact words are `THE PRESS SELECTED NOTHING` plus the cause in numbers, `angle 25.7 vs span 30..120`. They read as **missed**, not as "unchanged": the sentinel `(mod=0 a=30)` is still printed but is now immediately followed by `a=30 is the arc's STARTING angle, so a=30 with lastsel=0 means the gesture never happened, NOT a false-clean`. **The repair fixed the legibility, not only the row.**

**SABOTAGE C — three pixels (`incr ey 3`), the smallest nudge that actually leaves the span — exit 1, CAUGHT**
```
FAIL     | test_fluid_editing           run 1/1  RESULT: 2 FAILED (25 passed)
         | FAIL: FE8a the press SELECTED the arc (lastsel=1), so the gesture below ran at all (lastsel=0 -- 0 means THE PRESS SELECTED NOTHING, so no gesture happened and FE8's verdict says nothing about the false-clean; press px (423,343) -> sch (1324.7,-60.6): angle 25.9 vs span 30..120, r 138.6 vs 100, clear of the a+b handle box by 2.69 px) : FAIL
         | FAIL: FE8 drag-and-return changed the arc AND left buffer MODIFIED (no false-clean) (mod=0 a=30; a=30 is the arc's STARTING angle, so a=30 with lastsel=0 means the gesture never happened, NOT a false-clean; press px (423,343) -> sch (1324.7,-60.6): angle 25.9 vs span 30..120, r 138.6 vs 100, clear of the a+b handle box by 2.69 px) : FAIL
RESULT: 0/1 runs passed
```

**SABOTAGE B — one pixel (`incr ey 1`) — exit 0, GREEN, and that is CORRECT rather than a hole**
```
PASS     | test_fluid_editing           run 1/1  RESULT: ALL PASS (27 checks)
RESULT: 1/1 runs passed
```
Soaked, same arm, `-n 3` — deterministic, not a coin-flip:
```
PASS     | test_fluid_editing           run 1/3  RESULT: ALL PASS (27 checks)
PASS     | test_fluid_editing           run 2/3  RESULT: ALL PASS (27 checks)
PASS     | test_fluid_editing           run 3/3  RESULT: ALL PASS (27 checks)
RESULT: 3/3 runs passed
```
Two pixels (`incr ey 2`) likewise `RESULT: ALL PASS (27 checks)`, `RESULT: 1/1 runs passed`. **This is not a sabotage that survived: at `y+1` and `y+2` the press is at 37.4 and 32.0 degrees on a 30..120 span, so it still lands on the arc and the gesture it fences really does run.** Asking the row to fail there would be asking it to fail on a valid press.

**SABOTAGE D (not assigned, and a real legibility defect) — three pixels the other way (`incr ex -3`) — exit 1, caught by FE8 only, and the sentence it prints is WRONG**
```
FAIL     | test_fluid_editing           run 1/1  RESULT: 1 FAILED (26 passed)
         | FAIL: FE8 drag-and-return changed the arc AND left buffer MODIFIED (no false-clean) (mod=1 a=30; a=30 is the arc's STARTING angle, so a=30 with lastsel=1 means the gesture never happened, NOT a false-clean; press px (420,340) -> sch (1272.7,-112.6): angle 57.1 vs span 30..120, r 134.0 vs 100, clear of the a+b handle box by -0.31 px) : FAIL
RESULT: 0/1 runs passed
```
Read it: `a=30 with lastsel=1 means the gesture never happened` — **it demonstrably did happen**, `mod=1` in the same string says the buffer was modified. What happened is that `edit_arc_point` tests the `a+b` handle box first, the press fell inside it (`clear of the a+b handle box by -0.31 px`, negative), so `b` moved and `a` stayed at 30. The row's *verdict* is right and the row is not a coverage hole; its *narrative* is prose hardcoded for the `lastsel=0` case and asserts a false cause in the `lastsel=1` case. The honest number is printed right beside the wrong sentence, which is the same shape of defect issue 1641 was filed about — a detail that reads as one thing while meaning another.

**which_row_caught_it**

**Row `FE8a`** — the row the fixer added — caught both genuine press-misses (A, the shipped bug verbatim, and C, the three-pixel nudge), *first*, and named the cause in its own detail: `lastsel=0 -- 0 means THE PRESS SELECTED NOTHING`, with `angle 25.7 vs span 30..120` / `angle 25.9 vs span 30..120` as the mechanism. Row `FE8` corroborated in the same run, and its rewritten detail no longer reads as "unchanged".

**What is NOT caught by any row, and what would catch it.** Sabotage D — a press that lands *on* the arc but inside the `a+b` handle box, so `SELECTED3` is grabbed, `b` moves and `a` stays at 30 — is caught as a FAIL by `FE8`, but `FE8a` passes (`lastsel=1`) and `FE8`'s detail then **states the wrong cause**. The missing assertion is "the press grabbed the **`a`** control point", not merely "the press selected something". Two spellings, either of which would close it:

* widen `FE8a` to assert the handle it grabbed, using the figure `arc_press_diag` already computes: require the `clear of the a+b handle box by` term to be **positive**, so a press that drifts into the other handle fails *at the press*, with the negative clearance as its detail; or
* make the two details branch on `$fe8_sel` instead of asserting one cause unconditionally — `lastsel=0` keeps the present sentence, `lastsel=1` with `a` unmoved says "the press selected the arc but grabbed the OTHER control point (the `a+b` handle box was entered)".

The first is the better of the two because it is an assertion rather than a sentence, and it is derived from the live geometry rather than written down. Either way the repaired pair as it stands **discriminates "missed" from "false-clean" but not "missed the `a` handle" from "regressed"**, and the suite is one row short of that third state.



## register:1641


### survivors_closed

- **S3 — a constant garbage angle committed on every arc `a`-control-point drag — WAS A REAL SURVIVOR AND IS NOW CLOSED BY NEW ROW `FE8b`.** I reproduced it first, in a throwaway copy of the tree built from the real one (`src/` in the shared checkout never touched): in `move_objects`' arc `SELECTED2` **END** arm I replaced `xctx->arc[c][n].a = angle;` with `xctx->arc[c][n].a = 7.0;`, rebuilt, and the suite as the fixer left it came back `PASS | test_fluid_editing run 1/1  RESULT: ALL PASS (27 checks)`. **THE RED, on that same sabotaged build, with the row added and nothing else changed:** `FAIL | test_fluid_editing run 1/1  RESULT: 1 FAILED (27 passed)` / `FAIL: FE8b committed arc == the record derived from move_objects' own arc-END arithmetic (arc=1200 0 100 7 90; derived=1200 0 100 73.0 90; a expected 73.0 got 7, b expected 90 got 90 ...) : FAIL` — FE8b the ONLY failure, i.e. the hole was exactly one row wide. Reverted and rebuilt: `RESULT: ALL PASS (28 checks)`, soaked 3/3. The row asserts the WHOLE arc record against one derived from the product's own arithmetic, not that `a` left its start: new proc `arc_expected_a` walks the chain by symbol — `callback()`'s `mousex_snap = my_round(mousex/cadsnap)*cadsnap` (with `my_round_c`, a Tcl mirror of `my_round` in actions.c, because C89 has no `round()` and the product rounds half away from zero), `move_objects(START)`'s arc reference being the arc CENTRE, then `move_objects(END)`'s `a = my_round(fmod(atan2(-deltay,deltax)*180/PI + a, 360))`. `cadsnap` is read from the live interpreter, never restated. Derivation verified exactly against the product: delta (120,-110), atan2 term 42.5104, 30+42.5104 -> my_round -> **73**, and the product commits **73**.

- **Sabotage D (the adversary's unassigned find: a press that lands ON the arc but inside the `a+b` handle box, so `edit_arc_point` — which tests that box FIRST — grabs `SELECTED3`, moves `b` and leaves `a` at 30) is now caught BY AN ASSERTION, with the cause named.** Re-measured with `incr ex -3` against the pristine product: `RESULT: 2 FAILED (26 passed)` — `FE8` plus `FE8b`, whose detail reads `arc=1200 0 100 30 148; derived=1200 0 100 88.0 90; a expected 88.0 got 30, b expected 90 got 148 -- ... a moved \`b\` with \`a\` unmoved means the press grabbed the OTHER control point`, beside the printed clearance `clear of the a+b handle box by -0.31 px`. I chose the behavioural clause (centre, radius and `b` must be untouched) over the adversary's suggested geometric proxy (require the clearance term positive), because the proxy re-implements half of `edit_arc_point` in the test and asserts the AIM, whereas this asserts the RESULT and catches a wrong handle however the press reached it.

- **The counterfactual detail (adversary finding 3) is fixed and WITNESSED in all three states, not reasoned about.** FE8's unconditional prose said `a=30 is the arc's STARTING angle, so ... the gesture never happened, NOT a false-clean` and printed that while showing `a=73` — i.e. it misdescribed the one state the row exists for. The clause is now computed with a three-way `if`, and the hardcoded `30` is gone (it reads the fixture's own captured start angle). Measured, one sabotage per state: (a) false-clean — `if(!moved)` -> `if(1)` in `end_shape_point_edit`, rebuilt: `FE8 ... (mod=0 a=73; a MOVED 30 -> 73, so the geometry really changed: with mod=0 this IS the false-clean this row exists for ...)`, with FE8a and FE8b both PASSING, so the trio discriminates; (b) missed press — the shipped hardcoded `sch2scr 1286.6 -50`: `3 FAILED (25 passed)`, clause `a is STILL the starting angle (30) and lastsel=0, so the press selected nothing and no gesture happened -- a MISSED PRESS, not a false-clean`; (c) wrong handle — sabotage D: `a is STILL the starting angle (30) but lastsel=1, so the press DID select and the gesture ran yet left \`a\` alone -- FE8b below says which control point it got`.

- **NOT closed, declared, with the row that would close it: `FE3`, `FE3c` and `FE6` still assert only that `a` left its start.** S3 was caught at the FE8 site, so the measured survivor is fenced, but the same garbage-angle shape is invisible to the three default-zoom arc rows. `arc_expected_a` is in the file and applies to them unchanged; the honest extension is `FE3`'s `![feq $aa 0]` becoming `[feq $aa [arc_expected_a 1200 0 0 $tx $ty]]`. I did not do it: it is a second site, at a different zoom, with its own aim margin (the adversary measured 0.53 px there), and widening three green rows on a hunch is the move that turns a closing task into a new red on the branch the user shares. Recommended as 1641 open item 1 follow-up.

**banner_check**

The suite's epilogue is `puts "OVERALL: [expr {$::fails ? {notok} : {ok}}]"` on the pass path and, on the X-gate self-skip path, a literal `puts "OVERALL: ok"`. `banner_complete` in `tests/banner_rule.tcl` — sourced by `run_regression.tcl`, the only Tcl reader — is verbatim:

    regexp -line {^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$} $body

I did not trust the issue's claim; I ran that proc (sourced from `banner_rule.tcl`, not re-spelled) over BOTH arms' real captured output, taken with the two loops' own command spellings out of `run_regression.tcl` (`hccmd`: `$xschem --nogui --pipe -q --script headless/test_fluid_editing.tcl`, run under `env -u DISPLAY`; `dccmd`: `devdisplay.sh exec timeout --kill-after=20 900 $xschem --pipe -q --logdir <dir> --script ...`):

| | DISPLAY arm | `--nogui` arm |
|---|---|---|
| `banner_complete` | **1** | **1** |
| `banner_died` | 0 | 0 |
| exit code | 0 | 0 |
| `regression_case_failed` | **0** | **0** |
| rows `^ok:`/`^FAIL:` | **28** | 0 |
| last `RESULT:` | `RESULT: ALL PASS (28 checks)` | `RESULT: SKIP (no X)` |

So the suite satisfies the regexp **on both arms**, and the `banner_complete=0` the issue recorded for the display arm was purely `FE8`'s failure (`OVERALL: notok`), nothing structural. `RESULT: ALL PASS` is NOT what satisfies it and never appears in the predicate — that spelling is only accepted by `run_suites.sh` and `full_audit.sh`, the two readers that are not the gate, which is issue 1615's incident exactly. Here the sentinel is a real `OVERALL: ok` line, computed, and it is one of the 13 computing suites row `RB4` of `test_registered_banner_1626` re-measures. I also ran the two meta-suites against the new registration: `test_registered_banner_1626` `ALL PASS (10 checks)` (RB1 resolves the new entry to a file, RB4 accepts its command-substitution banner, RB6/RB7 unaffected) and `test_suite_watchdog_1403` `ALL PASS (40 checks)` (its `W20h` population is derived from these two lists, and this suite already arms the bound by sourcing `scratch.tcl`).

**registration**

LEFT IN THE WORKING TREE, UNCOMMITTED, for the driver to gate. `git status --porcelain src/` is empty; the only files I changed are `/home/analog/dev/xschem-claude/tests/headless/test_fluid_editing.tcl` and `/home/analog/dev/xschem-claude/tests/run_regression.tcl` (the three other modified files in `git status` are sibling crews' and I did not open them).

The list edit — one entry appended to `dcases`, `hcases` untouched:

    @@ -701,7 +701,8 @@ set dcases [list "headless/test_op_annot" ...
                      "headless/test_calc_buffer" \
    -                 "headless/test_calc_plot"]
    +                 "headless/test_calc_plot" \
    +                 "headless/test_fluid_editing"]

Plus a 25-line `##` paragraph appended after the last per-entry paragraph in the `dcases` commentary (before the `## ---` separator that opens the next topic), recording: that the suite is in BOTH lists; that the `hcases` entry alone measured nothing and why (whole-file no-X early exit, exit 0 plus a banner, so the case PASSED having run zero rows); that the `hcases` entry STAYS as the crash guard, because the gesture path dereferences the absent `.drw` canvas and SIGSEGVs under `--nogui`; and the measured figures below with the method that produced them. The prose deliberately carries no row count (`EVERY gesture row runs on the DISPLAY arm`), and the two check counts it does quote are attributed to a named capture rather than written as a baseline.

Lists after the edit, counted the way CLAUDE.md prescribes (locate `set <name> [list` by text, accumulate to `info complete`, `eval`, `llength` — not `grep -c`): tcases **3**, hcases **96**, dcases **25**, so `planned_cases` = 3+96+25+1 = **125**. That header arithmetic agrees INDEPENDENTLY with the `summarize_all`-derived +1 below.

Not touched: the `owed.sh` ledger, `~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display`, `~/.claude/gui_test_gate`, any `/tmp/xschem_emergencysave_*`, `~/dev/xschem-op-wcard`, the issue file and `NUMBERING.md` (1641's stamp and open-item count are the committer's business). No commit, no push, no full T1. `devdisplay.sh start|stop|view` never run — every display-arm run attached to the already-live `:99`, and `$DISPLAY` (`172.20.160.1:0`, the user's Windows screen) was never inherited by any invocation. Scratch is 60K after sweeping a 135M build copy back out of tmpfs.

**trailer_delta**

DERIVED, not predicted, and not reasoned about from registration shape. Method: `summarize_all` **lifted out of `tests/run_regression.tcl`'s own text** — every top-level `proc` in that file lifted beside it into a probe namespace (the shape row `C1` of `test_scratch_home_note.tcl` uses, so a new helper arrives for free instead of being a hand-kept list; 16 procs lifted, `summarize_all` present) — with `banner_complete`/`banner_died`/`regression_case_failed` **sourced** from `tests/banner_rule.tcl`, then run over this suite's REAL captured output from BOTH arms.

Its five regexp arms, printed from the lifted body:

    if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
    } elseif { [regexp {^(NOGOLD|NODISPLAY)} $line] } {
    } elseif { [regexp {^skip:} $line] } {
    } elseif { [regexp {^RESULT:} $line] } {
    } elseif { [banner_complete $line] && [regexp {\([^)]*\)} $line] } {

What it actually wrote, per arm (the block the verdict would carry):

    ARM disp : exit=0 banner_complete=1 banner_died=0 regression_case_failed=0
               counted_failures=0  blocks=+1  skips=+0  block_lines=3
               | headless/test_fluid_editing.disp.log
               | RESULT: ALL PASS (28 checks)
               | Total num fail: 0

    ARM nogui: exit=0 banner_complete=1 banner_died=0 regression_case_failed=0
               counted_failures=0  blocks=+1  skips=+0  block_lines=3
               | headless/test_fluid_editing.nogui.log
               | RESULT: SKIP (no X)
               | Total num fail: 0

The `--nogui` block is byte-identical in shape to what it already contributes, because the `hcases` entry is unchanged. So the DELTA is the display arm's block alone:

* **cases +1** (the `dcases` loop's `puts "Start ${dc}.tcl (display arm)"` with `incr t1_cases`) — 124 -> **125**, matching `planned_cases=125`
* **blocks +1** (`summarize_all` does `incr ::t1_blocks`) — 123 -> **124**
* **counted_failures +0** — zero lines in the display capture match any arm-1 shape (`/usr/bin/grep -cE 'FAIL$|GOLD\?$|RESULT\?$|^FATAL'` = **0**)
* **skips +0**
* **`wc -l` +3** (label + the one `RESULT:` line + `Total num fail:`) — 371 -> **374**

Expected trailer: `cases=125 blocks=124 counted_failures=0 skips=8`. Two environment notes that make this robust rather than lucky: T1's private Xvfb is `-screen 0 1920x1080x24` and the dev display's default is the same `1920x1080x24`, so the display arm's window geometry — and therefore the zoom the press pixel is derived from — is identical whichever route T1 takes; and the press and its expected angle are BOTH derived from the live arc and zoom at runtime, so they move together rather than being pinned.

**skip_spelling**

**No. Zero lowercase `^skip:` lines, on either arm.** The self-skip is announced UPPERCASE, so `summarize_all`'s `regexp {^skip:}` arm does not see it and the entry adds **0** to `skips=`.

Commands and counts, over the two real captures (`cap/disp.log`, `cap/nogui.log`):

    /usr/bin/grep -c '^skip:' cap/nogui.log  -> 0      /usr/bin/grep -c '^SKIP' cap/nogui.log  -> 1
    /usr/bin/grep -c '^skip:' cap/disp.log   -> 0      /usr/bin/grep -c '^SKIP' cap/disp.log   -> 0
    /usr/bin/grep -c '^RESULT:' cap/nogui.log -> 1     /usr/bin/grep -c '^RESULT:' cap/disp.log -> 1

The one uppercase line is the X gate's `SKIP: no viewable X window (.drw) -- fluid-editing gesture test needs a real display`. Over the suite's whole text there is no lowercase `skip:` emitter at all (`/usr/bin/grep -c 'puts "skip:' tests/headless/test_fluid_editing.tcl` -> 0), so there is no arm or environment on which one could appear — this is not a spelling that could flip with a fixture or a home. And the lifted `summarize_all` independently confirms it: `skips=+0` on both arms, with each block holding exactly one carried `RESULT:` line and no skip line.

**ready**

**Yes — safe for the driver to gate.** What will move: `cases` 124 -> 125, `blocks` 123 -> 124, `wc -l` 371 -> 374, `counted_failures` **0** and `skips` **8** both unchanged; and the suite's published check count moves 26 -> **28** on the display arm (one row from the fixer, one from me), which is not a baseline — `OVERALL:`, `RESULT:` and the `banner_rule`/`summarize_all` capture all recompute it every run.

Evidence behind the yes: display arm `ALL PASS (28 checks)` in the real tree, 2/2 soaked, and 3/3 in the build copy; `--nogui` arm unchanged (0 rows, exit 0, `OVERALL: ok`, `RESULT: SKIP (no X)`); `banner_complete=1` and `regression_case_failed=0` on BOTH arms, measured with `banner_rule.tcl`'s own procs rather than `run_suites.sh`'s ERE; the two suites that fence the lists themselves green with the entry in (`test_registered_banner_1626` 10 checks, `test_suite_watchdog_1403` 40 checks); and every figure above derived from `summarize_all`'s own arms before any gate ran, with `planned_cases=125` agreeing independently.

Three things the driver should know rather than discover. **(1)** Until this `dcases` entry lands, the false-clean `FE8` catches 3/3 on the display arm would pass T1 silently — that is the whole of 1641 open item 2, and it is now one commit away. **(2)** `FE3`/`FE3c`/`FE6` still assert only that the arc's angle changed, so the garbage-angle class is fenced at the `FE8` site and nowhere else; the one-line extension is in `survivors_closed` and I recommend it as follow-up, not as a blocker. **(3)** 1641 open item 3 (`find_closest_arc`'s zoom-scaled radial slack with a zero-tolerance angular span test) is still the product-side root of the whole aiming problem and is a user-visible ruling, untouched here.

Nothing is running now: the sabotage build copy is swept out of tmpfs, no xschem process younger than eight days exists, and no throwaway home or `/tmp` scratch of mine remains.

