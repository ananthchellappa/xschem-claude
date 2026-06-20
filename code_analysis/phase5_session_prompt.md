# Phase 5 session prompt (wire-editing-on-move)

Paste the block below into a fresh session to start Phase 5 with a clean context.

---

Proceed with **Phase 5** of the wire-editing-on-move plan
(`code_analysis/wire_editing_spec_and_plan.md`) on branch **`fluid-editing`**.

**Read first:** the auto-loaded memories `wire-editing-on-move.md` and
`cadence-modifier-drag.md`, then the spec's **Phase 5** section and the **TC7 / TC8 /
TC9** definitions in Part III. Confirm `git log --oneline -6` shows the wire-editing
commits through `1c98115b` (issue 0015 doc); Phases 0–4 are done, issues 0013/0014
resolved, 0015 (component-shove) is deferred.

## Goal
Make **TC7 (colinear merge)**, **TC8 (overlap/duplicate dedup)**, and **TC9
(move-orphaned dangling stub)** GREEN — release-time cleanup so repeated
stretch/slide moves don't accumulate cruft (Issue D3 → R10/R11/R12).

## ⚠️ Decide the trigger FIRST (the tests don't move anything)
The three tests as written **build the residue directly and assert the tidied
end-state with NO operation in between** — e.g. TC7 lays two colinear wires and
immediately checks `nwires == 1`. So before coding, decide *where the cleanup runs*
and make the tests exercise it. Two honest options (spec 5.1 prefers the move path):

- **(A) Clean on the stretch-move END.** Run a dedup/merge pass at the end of a
  stretch move (the gesture that creates the cruft), regardless of `autotrim_wires`.
  Then the tests should build the fixture **and perform a (possibly no-op) stretch
  move** so the cleanup fires — i.e. add a `we_move_stretch` and reframe the assert
  as "after a stretch move, the residue is tidied." This is the faithful, in-gesture
  fix. *Recommended.*
- **(B) Clean via an explicit tidy** the test calls (`xschem trim_wires` for TC7/TC8;
  a move-scoped removal for TC9). Simpler but tests a command, not the gesture.

**Pick (A) unless you find a reason not to**, and update the TC7/8/9 fixtures to
trigger it. Note this in the commit so the test change is intentional, not silent.

## Existing machinery to reuse (check before writing new code)
- **`trim_wires()`** (`check.c:161`) already does the **merge** (colinear degree-2)
  and **include/overlap removal** — TC7 and TC8 are essentially what it does. Verify
  headlessly: build TC7/TC8 fixture, `xschem trim_wires`, check. It is **gated by
  `autotrim_wires`** for the *automatic* path — grep `autotrim_wires` in `src/*.c`
  to find where the auto-trigger fires and whether the stretch-move path reaches it.
  (Reminder: `cadence_compat` now turns `autotrim_wires` on — commit `808ad990`.)
- **`check_collapsing_objects()`** (`move.c`) removes only **zero-length/degenerate**
  wires — NOT colinear merges or overlaps. Don't confuse the two.
- **TC9 needs a *move-scoped* removal** (spec 5.3): delete a degree-1 wire only if it
  (i) was selected/created by this move and (ii) has an end on no pin and no other
  wire. Must be carefully scoped so **intentional** dangling stubs elsewhere are
  untouched — `trim_wires` won't do this; it's new, small, move-local logic.

## RED-first recipe (per the plan's method)
1. Confirm TC7/TC8/TC9 are RED for the right reason (they are — no tidy op runs).
2. Smallest first: **TC8** (overlap/include removal), then **TC7** (colinear merge),
   then **TC9** (move-scoped orphan removal). One behavior per commit.
3. **Sabotage-verify** each RED→GREEN (revert the cleanup → the test reddens).
4. Run the **regression guard set** — all must stay GREEN:
   - wireedit: TC1, TC2, TC3, TC4, TC5, TC6, **TC11** (no over-grab), TC13, **TC14
     (undo must still restore — cleanup changes geometry, so undo fidelity is the
     key risk)**, TC15, TC16, **TC17** (wire-drag junction stays anchored).
   - golden harness `tests/headless/run.sh` (`== HARNESS: PASS ==`).
   - `tests/stable_handles/wrap.tcl` (58 checks; logs to `/tmp/sh_test.log`).
   - `tests/headless/test_cadence_drag.tcl` (16 checks).
5. **Re-run TC6's horizontal sibling** (spec 5.4): a horizontal corner-slide may
   leave one overlapping rail segment; confirm Phase 5 now merges it.
6. Commit each step with the standard Co-Authored-By / Claude-Session trailer.
7. Mark Phase 5 ✅ in the spec; update the memory files.

## Guard the cross-cutting invariants (never regress)
- **R16 no accidental shorts** — a merge/dedup must never join two *distinct* nets.
  If two colinear wires are on different nets, do NOT merge. (TC11 is the guard;
  consider a dedicated 2-net colinear test if you merge aggressively.)
- **R17 undo fidelity** — TC14. Cleanup must be inside the move's undo unit so one
  undo restores exact prior geometry.

## How to run the tests (environment notes)
- **Run from the REPO ROOT** under X (fixtures use CWD-relative paths):
  `DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_08_overlap_dedup.tcl`
- Rebuild after C edits: `cd src && make` (then run from root).
- Test helpers (`fixtures.tcl`): `we_reset <stretch> <ortho>` (also pins `cadsnap 10`);
  `we_wire`/`we_device`; `we_move_stretch dx dy` = `move_objects dx dy stretch kissing`
  (the faithful cadence drag); `segset`/`has_seg`/`nwires`/`has_endpoint`. For Phase 5
  you'll likely set `autotrim_wires` explicitly per test if you take option (A) and
  want it independent of cadence.
- **WSLg flakiness:** GUI/gesture tests can flake; re-run 2–3×. The wireedit smokes
  are non-gesture (scripted `move_objects`) so they're stable.

## Verification discipline (non-negotiable)
A green test that never executed the new code is hollow — sabotage/stash-verify every
RED→GREEN and every "already-green" guard. Read the actual code/line before asserting;
prefer a headless probe over recall. `xschem objects -selected` lists only FULL
selections (partials are invisible) — instrument `.sel` flags if you need them.

## After Phase 5
Remaining: **Phase 6** (exit-stub, TC10 — depends on 4/5, biggest behavior change,
keep behind a switch), **TC12** (bus/`lab` dropped on stretch — standalone move.c
prop bug, not a phase), **Phase 8** (defaults/discoverability — needs user sign-off),
**issue 0015** (component-shove, deferred feature), **Phase 7** (`desired0` aesthetic,
optional). Also pending: planning the **branch merge to `master`**. Don't bundle these
into Phase 5.
