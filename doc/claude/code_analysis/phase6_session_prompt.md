# Phase 6 session prompt (wire-editing-on-move)

Paste the block below into a fresh session to start Phase 6 with a clean context.

---

Proceed with **Phase 6** of the wire-editing-on-move plan
(`doc/claude/code_analysis/wire_editing_spec_and_plan.md`) on branch **`fluid-editing`**.

**Read first:** the auto-loaded memories `wire-editing-on-move.md` and
`cadence-modifier-drag.md`, then the spec's **Phase 6** section, **Issue E** ("the
dream"), **Issue F** (why routing aesthetics are context-dependent), and the **TC10**
definition in Part III. Skim `doc/claude/issues/0015-component-shove...md` only to know it is a
SEPARATE deferred concern — do not solve it here. Confirm `git log --oneline -4` shows
Phase 5 done (`02975fd4` + spec `e9705e15`); Phases 0–5 complete, map GREEN
TC1-9/11/13-17, RED TC10 (this phase) + TC12 (bus, separate).

## Goal
Make **TC10** GREEN: after a stretch move, a **one-minor-grid stub leaves each moved
pin along its exit direction before the first bend** (the `desired1` rule, Issue E →
R13). This is the **biggest behavior change** in the plan, so it must ship **behind a
new switch** (default OFF) and leave every existing test unchanged.

## ⚠️ Decide the design FIRST (two things to pin down before coding)

**(a) What is "exit direction"?** TC10 was written in Phase 1 as a baseline GUESS and
its asserted geometry is almost certainly WRONG — verify and FIX it before implementing:
- The fixture uses `res.sym` whose **pin M exits VERTICALLY (+y, straight up out of the
  lead, away from the narrow body)** — symbol bbox is ~`-7.5 -32.5 7.5 32.5`, pin M at
  the top of a `+y` lead. So the faithful `desired1` stub out of pin M `(1360,-870)`
  is **vertical**: `(1360,-870)-(1360,-860)`, NOT the **horizontal** `(1360,-870)-
  (1350,-870)` the current TC10 asserts.
- So step 0 is: **characterize the pin's true outward normal headlessly**
  (`get_inst_pin_coord` + the symbol bbox / the pin's lead geometry), decide the rule
  ("exit direction = the pin's outward normal", recommended — it's the uniform,
  symbol-driven rule Issue E describes), and **rewrite TC10's assertion** to match the
  real exit axis. Note in the commit that the Phase-1 assertion was provisional and was
  corrected. Don't make the code match a wrong test.

**(b) Gate behind a new config `wire_exit_stub` (default OFF).** Mirror it C↔Tcl
(search `MIRRORED IN TCL` in `xschem.h`; add the Tcl default in `xschem.tcl`; optional
Options-menu entry like the `808ad990` autotrim entry). **Every existing wireedit test
runs with it OFF**, so TC1-9/11/13-17 geometry is byte-for-byte unchanged; **TC10
turns it ON**. This is how the plan keeps "biggest behavior change" from shifting goldens.

## ⚠️ The Phase-5 interaction you MUST get right
Phase 5 added `trim_wires()` (colinear degree-2 merge) at stretch-move END. A
one-grid exit stub that is **colinear with the route's first leg would be merged right
back** (degree-2 free point → gone). The stub only survives because the route **bends**
just past it (the stub is on one axis, the next segment on the other → a corner, not a
colinear pair → trim leaves it). So:
- Confirm the exit-stub pass runs in an order where `trim_wires()` does NOT eat it
  (run it AFTER trim, or rely on the perpendicular bend). Add a headless assertion that
  the stub is still present *after* the full Phase-5 cleanup.
- For a **straight (no-bend) route**, an exit stub WOULD be colinear and get merged —
  that's fine (a straight exit can't cross the body), so don't force a stub there.

## Where to implement
A new pass at `move_objects(END)` modelled on `compute_wire_slide()` (move.c, ~1207):
guarded to `wire_exit_stub && orthogonal_wiring && non-rotating`, run for each MOVING
instance pin that has an attached route. Splice the existing first segment so it starts
one grid out along the exit normal, inserting the short stub via `storeobject(... WIRE
...)`. Reuse `get_inst_pin_coord`, `point_on_moving_pin`, `order_wire_points`, the
hash/`set_modify` bookkeeping. **Stub length** = one minor grid; document the constant
(the fixtures pin `cadsnap 10`; decide whether the length is `cadsnap`, the symbol pin
spacing, or a fixed constant — and write down why).

## RED-first recipe
1. Confirm TC10 RED for the right reason (no stub today) — and FIX its asserted axis per
   (a) above; re-confirm it is RED against the corrected geometry.
2. Implement the gated pass; TC10 RED→GREEN (switch ON).
3. **Sabotage-verify:** disable the pass → TC10 reddens.
4. **Guard set — all must stay GREEN with the switch OFF (unchanged geometry):**
   - wireedit TC1-9, **TC11** (no over-grab), TC13, **TC14 (undo)**, TC15, TC16, TC17.
   - With the switch **ON**, re-run **TC6** (corner-slide): the stub is additive, the
     rest of the route must be unchanged — assert TC6's segments still present plus the
     new stub.
   - golden harness `tests/headless/run.sh` (`== HARNESS: PASS ==`) — netlist-only, so
     geometry can't break it, but run it anyway.
   - `tests/stable_handles/wrap.tcl` (58 checks; logs to `/tmp/sh_test.log`).
   - `tests/headless/test_cadence_drag.tcl` (16 checks; WSLg-flaky, rerun 2–3×).
5. Commit with the standard Co-Authored-By / Claude-Session trailer; mark Phase 6 ✅ in
   the spec; update the memory files.

## Guard the cross-cutting invariants (never regress)
- **R17 undo fidelity (TC14)** — the exit stub is part of the move's undo unit; one undo
  restores exact prior geometry.
- **Netlist unchanged** — an exit stub is electrically identical (same net, still
  connected). The golden harness proves this; keep it green.
- **No accidental shorts (R16)** — the stub extends an existing pin's own net only;
  never bridge to a neighbour.

## How to run the tests (environment notes)
- **Run from the REPO ROOT** under X:
  `DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_10_exit_stub.tcl`
- Rebuild after C edits: `cd src && make` (then run from root).
- Helpers (`fixtures.tcl`): `we_reset <stretch> <ortho>` (pins `cadsnap 10`);
  `we_device`/`we_wire`/`we_label`; `we_move_stretch dx dy` = `move_objects dx dy
  stretch kissing`; `segset`/`has_seg`/`has_endpoint`/`all_manhattan`/`nwires`. Set
  `wire_exit_stub` explicitly per test (ON in TC10, OFF everywhere else).
- **WSLg flakiness:** gesture tests can flake; re-run. The wireedit smokes are scripted
  `move_objects` (stable).

## Verification discipline (non-negotiable)
A green test that never executed the new code is hollow — sabotage/stash-verify every
RED→GREEN and every "already-green" guard. Read the actual pin geometry with a headless
probe before asserting the stub axis; do not trust the Phase-1 TC10 assertion. `xschem
objects -selected` lists only FULL selections (partials are invisible) — instrument
`.sel`/coords if needed.

## After Phase 6
Remaining: **TC12** (bus `lab=` dropped on the stretch move — a standalone move.c
prop-preservation bug, not a phase), **Phase 7** (`desired0` aesthetic — optional,
heuristic, needs its own golden), **Phase 8** (defaults/discoverability — needs user
sign-off, changes long-standing behavior), **issue 0015** (component-shove, deferred),
and planning the **branch merge to `master`**. Don't bundle these into Phase 6.
