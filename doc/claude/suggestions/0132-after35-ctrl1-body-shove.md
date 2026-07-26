# Session handoff — fix issue 0132 after_35 (fluid CTRL1 body-driven backbone shove)

Branch `fluid-editing`, HEAD `e6186956`, `src/move.c` is CLEAN. Read `doc/claude/WIRING.md` (esp
§11.1 named-rail blackout, §5 pass table) and `doc/claude/issues/0132-fluid-second-drag-own-copper.md`
§11.9c BEFORE editing.

## Bug

Repro: load `tests/from_user/before_10.sch`, drag instance `x1` two snap-grid units right (`+20x`, pure
ortho, no rotation), release → saved as `tests/from_user/after_35.sch`. `x1` = `SANDBOX/solar_ctl`
lands `(130,20) rot 1`. CTRL1's stationary vertical backbone `N 140 -20 140 100` ends up threading the
moved pin-inclusive body of `x1` (body box `x[97.5,150] y[-132.5,82.5]`, so `x=140` is interior). The
CTRL1 pin `(140,80)` lands mid-run on its own backbone; nothing shoves it out.

Expected (user): the vertical is PUSHED RIGHT clear of the body (to `x=160`), pin reconnecting via a
short jog — live, as the advancing body reaches it. This is a BODY-driven shove, distinct from the
PIN-driven `fluid_shove_connected_wire`.

Headless repro (reproduces after_35 exactly):
`xschem select instance x1; xschem move_objects 20 0 stretch kissing`.
Test env: `cadence_compat 1`, `fluid_editing 1`, `orthogonal_wiring 1`,
`XSCHEM_LIBRARY_DEFS=<repo>/xschem_libs_newsym/library.defs`, `library_registry_defs_only 1`,
`XSCHEM_LIBRARY_PATH {}`. Enable tracing with env `FLUID_TRACE=<path>`.

## Make this pass (currently P5 is xfail)

`tests/headless/test_fluid_ortho_ctrl1_shove_0132.tcl` — P1 connectivity + P4 no-diagonal already pass;
promote P5 (CTRL1 backbone clear of body) xfail→hard check. Build: `make -C src xschem`.
Run: `src/xschem -q --pipe -x --script <test>`.

## Why existing layers miss it

- `fluid_shove_connected_wire` (move.c ~6728, issue 0015): PIN-driven, needs a wire PARALLEL to the
  move with a moving-pin endpoint driven past its junction. CTRL1's pin exits +y then jogs → never
  matches.
- `fluid_reroute_body_crossing_feeds` (~4811): gated `diag_relay`, skipped on the pure-ortho path
  (`diag_relay==0`). Its delete-based whole-net hoist over-fired on 2-pin devices when tried — do NOT
  reintroduce a delete approach.

## What was attempted last session (correct geometry, but reverted)

A new END pass `fluid_shove_body_crossing_backbone`:

- Gate: pure-axis move; moved instance; moved pin whose column `pc` is strictly inside the body
  cross-range; net `N` from `fluid_moving_pin_net(px,py)` (NOT "a wire touching the pin" — that grabbed
  a foreign wire's prop and shorted CTRL1↔TRIANG).
- THROUGH-RUN gate: same-net perpendicular run at column `pc` with copper BOTH above AND below the pin
  (excludes TRIANG/net1 one-sided escapes — this is the key over-fire guard). Scan must INCLUDE
  selected wires (mid-gesture the run is mixed-sel: stationary backbone below + `SELECTED1` relaid
  pin-leg above; skipping selected split the run and laid a diagonal).
- REBUILD (not translate): collapse run wires to the pin point (`check_collapsing_objects` reaps them),
  find load-bearing attachment corners (points on column `pc` touched by a NON-run same-net wire), lay
  ONE new backbone at `ct = fluid_grid_above(bx2) = 160` spanning only `[pin..corners]`, DROP the dead
  stub above the pin `(140,80)-(140,100)` — it is named CTRL1 so orphan-prune skips it (§11.1), and
  shoving it up crosses the TRIANG rail at `y=90` and solders the nets. Translate attachment endpoints
  on column `pc` to `ct`. Add jog `(px,py)-(ct,py)`. Partition-verify with exact revert (never worse).

This produced the CORRECT geometry for CTRL1.

## Why it failed (the unsolved part — fix THIS)

It ran in the mid-gesture shared commit block (next to `fluid_shove_connected_wire`, move.c
~8049/8093) and fought the dirty transient state. Internal partition check passed, but the
attempt-final check saw `partition_changed=3` (phantom CTRL1↔TRIANG merge, all copper relabeled
TRIANG) — surviving even with `jprop.lab` confirmed `=CTRL1` and NO geometric contact (rebuilt backbone
max `y=80` < TRIANG rail `y=90`). Suspected RUBBER-vs-END / follow-selection interaction (intervening
`trim`/`maintain`/`check_collapsing` creating a junction, or RUBBER-pass pollution). Gating to
`!commit_now` (END-only) did NOT fix it.

## Identified correct-fix path

Run the shove on CLEAN, FULLY-COMMITTED geometry — all `sel==0`, trimmed/merged — i.e. AFTER
`unselect_partial_sel_wires` (move.c ~8100+), or as a first-class END-cluster pass with its OWN restore
snapshot + partition-verify, NOT in the mid-gesture shared block. At that point CTRL1 is a single clean
vertical `(140,-20)-(140,100)` with the pin mid-span, no selected fragments, no degenerates — the
rebuild is then unambiguous. Still must explicitly drop the named dead stub above the pin.

## Regression gates (must ALL stay green)

- `tests/headless/wireedit/run_wireedit.sh` → `WIREEDIT: ALL PASS`
- every `tests/headless/test_fluid_*.tcl` → `OVERALL: ok` (incl.
  `test_fluid_ortho_second_drag_0132.tcl` = after_34, must stay ALL PASS)

## Discipline

- Assert a per-pin / whole-net body-clearance invariant, NOT a single-wire check (the after_34 test
  only checked TRIANG and let CTRL1 escape green — that is the lesson).
- Never ship without wireedit + all `test_fluid_*` green. Trace-verify the actual saved geometry;
  a green suite ≠ the code ran.
