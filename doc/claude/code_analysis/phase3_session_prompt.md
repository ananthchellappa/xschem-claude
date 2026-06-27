# Phase 3 session prompt (wire-editing-on-move)

Paste the block below into a fresh session to proceed with Phase 3.

---

Proceed with **Phase 3** of the wire-editing-on-move plan
(`doc/claude/code_analysis/wire_editing_spec_and_plan.md`) on branch **`fluid-editing`**.

**Read first:** the memory files `wire-editing-on-move.md` and
`cadence-modifier-drag.md` (auto-loaded), then the spec's Phase 3 section and the
TC5 + TC16 definitions in Part III. Confirm `git log --oneline -6` shows the
wire-editing commits up to `d554aab3` (FAQ Q15); Phases 0–2 are done.

## Goal
Make **TC5 (T-junction / mid-span follow)** and **TC16 (pin-to-pin abutment generates
a wire)** GREEN. Both are RED today only on the *drag / stretch* path.

## Decision already ratified (spec Phase 3.2, approach **b**)
Route the plain / `cadence_compat` drag through the existing **`connect_by_kissing()`**
(`actions.c:1163`) — it already handles **both** cases (its first loop = pin-to-pin
abutment, second loop = wire point-on-segment via `touch()`). Verified headlessly:
`xschem move_objects 40 0 kissing` regenerates the connecting wire; `... stretch` does
not. So the fix is to set `xctx->connect_by_kissing = 2` (consumed at move END,
`move.c:619/1165`) on the drag path, alongside `select_attached_nets()`.

## Where to wire it (callback.c `handle_button_press` direct-drag dispatch, ~:5237)
- **cadence branch** (the `if(cadence_compat)` block from `15dced84`): the *plain*
  (no-modifier) arm currently does `select_attached_nets(); move_objects(START,...)`.
  Add the kissing trigger there so a plain cadence drag follows T-junctions AND
  abutments. This also **restores what `cadence_compat` lost** when Shift+drag became
  `copy` (legacy Shift+drag used to set kissing).
- **non-cadence intuitive branch** (the `else` with the `enable_stretch` XOR): decide
  whether plain stretch-drag should also kiss (the spec leans yes; keep it behind the
  same reasoning). Don't change default (`enable_stretch`/`orthogonal_wiring` off)
  behavior — the golden harness sets neither and must stay green.

## TC5 expected geometry — pin this FIRST (spec says decide from the test)
TC5 today asserts a vertical stub `(0,30)-(0,70)` joining the old tap point to the new
pin. Before implementing, run the `kissing` move on the TC5 fixture and confirm what
`connect_by_kissing()` actually produces; if it differs, update the test's expected
geometry to the real (correct) result rather than forcing a shape. TC16's result is
already pinned and verified: `(0,30)-(40,30)`.

## RED-first recipe (per the plan's method)
1. Confirm TC5 + TC16 are RED for the right reason (they are; re-run to be sure).
2. Make the smallest change to go GREEN. One behavior per commit.
3. **Sabotage-verify** (revert the kissing trigger → TC5/TC16 redden; restore).
4. Run the **regression guard set** — all must stay GREEN:
   - wireedit: TC1, TC2, TC4, TC11, **TC13** (rigid multi-move must not self-kiss —
     `connect_by_kissing` skips *selected* instances, so verify), TC14.
   - golden harness `tests/headless/run.sh` (must print `== HARNESS: PASS ==`).
   - `tests/stable_handles/wrap.tcl` (58 checks, exercises `move_objects`).
   - `test_cadence_drag.tcl` (11 checks — the cadence gestures must still hold).
5. Commit with a message ending in the standard Co-Authored-By / Claude-Session lines.
6. Mark Phase 3 ✅ in the spec; update the memory files.

## How to run the tests (IMPORTANT environment notes)
- **Run from the REPO ROOT** (fixtures use CWD-relative paths) under X:
  `DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_05_tjunction.tcl`
- Whole suite: `tests/headless/wireedit/run_wireedit.sh` (aggregates; stays non-zero
  until all REDs land — that's by design).
- Rebuild after C edits: `cd src && make` (then run from root).
- **WSLg flakiness:** GUI/gesture tests can flake on a degraded display; re-run 2–3×.
  `test_gesture_end_log`'s rect gesture is a known *environmental* flake (reproduces on
  pre-cadence HEAD), not a regression — don't chase it.
- Net identity in helpers: `we_net` = `resolved_net` (refreshes
  `prepare_netlist_structs`) then `getprop wire <n> lab`; `cadsnap` pinned to 10.

## Verification discipline (non-negotiable)
A green test that never executed the new code is hollow — sabotage/stash-verify every
RED→GREEN and every "already-green" guard. Read the actual code/line before asserting;
prefer a headless probe over recall.

## After Phase 3
Remaining work-list: TC6 (Phase 4 corner-slide — the main Issue-D complaint),
TC7/8/9 (Phase 5 cleanup), TC10 (Phase 6 exit-stub), TC12 (separate gap: stretch move
drops the wire's prop / bus label). Don't bundle these into Phase 3.
