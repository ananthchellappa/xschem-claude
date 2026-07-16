# Handoff — make fluid editing DEFAULT-ON (new session start prompt)

Branch `fluid-editing`, everything pushed @ `c40c3ebe` (github/fluid-editing). The whole
nice-drag-rerouting effort (Phases 0–III, obstacle Layers 1–3, SHOVE, P6 min-bend, 0081 diagonal
decomposition, 0083 offset solder-joint + far-pin landing + hardening) is DONE, user-eyeballed and
pushed. Thread-1 mid-drag big-delta no longer reproduces (dropped). The pre-default-on cleanups the
user asked for (recent-files protection: `--nogui`/`--pipe`/`--norecent` sessions never touch
`$USER_CONF_DIR/recent_files`; `# launch:`/`# cwd:` header in Xschem.log) are in. **The remaining
milestone is DEFAULT-ON: ship the fluid-editing drag behavior as the out-of-the-box default, so a
stock `src/xschem` launch (no cadence_style_rc) gets it.**

## Orient first (read these, in order)
- Memory `nice-drag-rerouting.md` — full history, **newest entries at the BOTTOM**; also `MEMORY.md`
  index (`fluid-editing-tip-grab.md`, `wire-editing-on-move.md`, `user-run-config.md`).
- Spec `doc/claude/specs/incremental_wire_reroute.md` + `doc/claude/specs/nice_drag_rerouting.md`
  (predicates P1..P8, conflict order `P1=P2 > P3 > P5 > P4 > P7 > P6`).
- Issues `doc/claude/issues/0081-*.md`, `0083-*.md` (incl. the review-hardening section + known
  limits), `0084-*.md` (OPEN, pre-existing replay-test failure — unrelated, do not absorb it here).
- `src/cadence_style_rc` — the exact set of variables the user's launch enables today.
- `src/xschem.tcl` defaults block (`set_ne fluid_editing 0` and neighbours, ~line 14690).

## What "default-on" must decide FIRST (present to the user before coding)
`fluid_editing` alone is NOT sufficient: the fluid paths gate on companions.
Build the real dependency map by grep (`fluid_editing`, `orthogonal_wiring`, `enable_stretch`,
`stretch_select`, `cadence_compat`, `unselect_partial_sel_wires`, `wire_exit_stub`,
`autotrim_wires`) and then put a small decision matrix to the user:
1. **Minimum bundle**: which vars must flip WITH `fluid_editing` for the drag behavior to actually
   engage on a stock launch? (At minimum check: `orthogonal_wiring` — the reroute/offset passes
   early-return without it; `enable_stretch` — fluid gates on `stretch_select`; the Phase-I
   follow-wire deselect assumes `unselect_partial_sel_wires` semantics.)
2. **autotrim_wires stays 0 (stock default)?** The 0083 hardening proved fluid+autotrim=0 is a
   DIFFERENT regime (un-split buses; that is where the three P1 holes lived, now guarded by
   test_wireedit_42). The wireedit suite runs almost entirely autotrim=1. If default-on ships with
   autotrim=0, that combination needs a real sweep (see Verification).
3. **cadence_compat / bindkeys stay opt-in** (they are look-and-feel, not drag machinery) — confirm
   with the user that default-on means the DRAG behavior only, and `cadence_style_rc` remains the
   opt-in for keys/menus.

## Implementation (small once decided)
- Flip the chosen `set_ne` defaults in `src/xschem.tcl` (defaults are `set_ne`, so an existing
  user xschemrc that sets 0 still wins — that IS the escape hatch; document it).
- Check for any C-side mirror of the flipped vars (`MIRRORED IN TCL` in `xschem.h`); fluid_editing
  itself is read fresh via `tclgetboolvar` (no mirror), verify the companions.
- Update `cadence_style_rc` comments (vars that are now redundant there).
- Grep tests that IMPLICITLY relied on default-off: any headless test that never sets
  `fluid_editing` now runs WITH it. Sweep `tests/` for suites whose expectations change; where a
  test intends to exercise the NAIVE path, make it say `set fluid_editing 0` explicitly.

## Verification (the bulk of the work)
- **Full regression**: `cd tests && tclsh run_regression.tcl` (create_save / open_close /
  netlisting golden files) with the flipped default — netlists must be UNAFFECTED (fluid is a
  drag-time feature; any netlist diff is a red flag).
- **All headless suites**: wireedit (42), wire_split, fluid_editing, action log/replay (0084's one
  pre-existing FAIL excepted), plus the `tests/headless/*.sh` shell suites.
- **Explicit-off byte-identical**: with `set fluid_editing 0` (etc.) in an rc, the flipped binary
  must byte-identical-match the pre-flip binary on the wireedit fixture drives (regenerate a
  baseline binary from HEAD-before-flip; run it with `XSCHEM_SHAREDIR=<repo>/src`).
- **autotrim=0 sweep** (if that stays the default): run the key wireedit drives under autotrim=0
  release+stepwise and eyeball segsets — test_42 covers the far-pin never-worse rails, but the
  broader drive set has not been swept in that regime.
- **Perf sanity**: `xschem --script xschemtest.tcl` (+ `xschemtest`) — the fluid commit path
  re-solves from pristine each RUBBER step; make sure big-schematic drag latency is acceptable.
  `--memcheck` on the wireedit suite.
- **Acceptance gate = user real-window eyeball of a STOCK launch** (`src/xschem`, NO
  cadence_style_rc, fresh HOME if needed): drags behave fluidly, nothing else feels broken, and a
  `set fluid_editing 0` xschemrc restores the old behavior. Push only after sign-off.

## Discipline (unchanged)
RED-first where a behavior changes; commit WIP before any git-capable subagent and
worktree-isolate review/attack agents (`isolation:'worktree'` — a review once `git reset --hard`ed
uncommitted work); adversarial-review the flip decision matrix and the test sweep
(green-but-hollow has struck 3× in this effort — a green suite that silently stopped covering the
naive path is the exact failure mode to fear here); FLUID_TRACE
(`FLUID_TRACE=/tmp/fltrace.log src/xschem ...`, file NOT stderr) for any gesture the user reports;
headless seam `xschem move_objects start/step/end` faithfully mirrors interactive drags.

## Known limits riding along (decline==naive, NOT blockers — fluid-on is never worse than today)
Y-axis transpose far-pin landing (horizontal-riser scope, still shorts exactly like naive does);
long-instance-name text-inflated bbox makes the offset pass decline; corner exactly on a foreign
WIRE endpoint declines (mid-span repairs); own-body P5 driver unimplemented. Candidates for
increments after default-on, or before it if the user wants the transpose closed first (it is the
same gesture rotated 90° — ask).
