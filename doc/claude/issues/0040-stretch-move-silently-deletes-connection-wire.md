# Issue 0040 — Stretch-move can silently delete a connection-bearing wire

**Opened:** 2026-06-26
**Status:** ✅ FIXED 2026-07-02 (`fluid-editing`; initial guard `c4a44172`, same-net correction follow-up — see Correction below). Triaged 2026-07-01: was STILL PRESENT (`src/move.c:1372-1409`). Real severity **MEDIUM** (narrower than framed: the deleted wire's free end must be *dangling*, so the realistic data-loss case is a stub carrying its own `lab=` net name — deleting it silently renames the node). **Priority P1.** Fix effort **S**: skip wires with a `lab=` token and emit a `ciw_echo` on auto-removal; the full "endpoints resolve to same node after re-stitch" check is the **M** follow-up.
**Severity:** HIGH — silent connectivity / netlist change with no visible cue.
**Branch:** `fluid-editing`.
**Source:** `/code-review high` this session (workflow `wf_1a6ce6c4-0d9`), finding #2 (CONFIRMED).
**Affects:** `src/move.c` `remove_move_orphan_wires()` (~:1285), invoked on every stretch move.
Related: [[wire-editing-on-move]], issues 0013/0014/0015 (wire-follow cascade).

---

## 1. Symptom

A stretch move can silently delete a wire stub that actually carries the only (or an intended)
connection — e.g. when two nets transiently share a pin coordinate after the kissing/commit step
re-creates wires. The generated netlist then differs from what the user drew, with **no** status
message or visual cue that a wire was removed.

## 2. Root cause

`remove_move_orphan_wires()` deletes a wire when **all** of these hold, using a geometry-only
redundancy heuristic that runs on **every** stretch move (even with autotrim off):

- its *free* endpoint matches the captured grab-coordinate snapshot (`coord_was_grabbed`, exact `==`),
- its *kept* end lies on a moving pin, and
- that pin is touched by another wire.

This is a heuristic "this stub is redundant" test, but coincident coordinates do not imply the same
electrical node — so a genuinely-connecting stub can match and be removed.

## 3. Fix sketch

Tighten the redundancy test so a wire is removed only when it is provably redundant (its two endpoints
resolve to the same node *after* the re-stitch, i.e. the connection is preserved by another wire),
and/or gate the auto-removal on the autotrim preference. At minimum, emit a `ciw_echo` note when a wire
is auto-removed so the change is not silent. Add a regression: a stub carrying a distinct net into a
moved pin survives the stretch (netlist unchanged for that node).

## 4. Acceptance

Stretch-moving a component never drops a wire that is the sole carrier of a connection; any auto-trim
of a truly-redundant wire is reported.

## Resolution (2026-07-02, committed `c4a44172`)

`remove_move_orphan_wires()` (`src/move.c`) skips any candidate stub carrying a `lab=` token
(`get_tok_value(...,"lab",0)[0]`) and emits a CIW cue via `ciw_echo` ("auto-removed N redundant wire(s)
after move", `has_x`-gated) so the trim is no longer silent.

## Correction (2026-07-02, same-net check)

The bare `lab[0]` guard above was **too broad and broke `test_wireedit_09_orphan_stub` (TC9)**:
`prepare_netlist_structs()` bakes the *derived* net name into EVERY named-net wire's `prop_ptr` `lab=`
(`netlist.c:1051/1075`), so `lab` is non-empty on essentially every stub on a named net — the guard
refused to remove ordinary redundant same-net stubs, gutting the Phase-5 cleanup for named nets in
production (not just the test). Replaced with the intended **same-net** condition (0040's "M follow-up"):
a *named* stub is dropped only when another wire at the kept pin carries the **same** net (new
`other_wire_same_lab()` compares the baked `lab` token); an anonymous stub (empty `lab`) stays removable
on the geometric `point_on_other_wire` redundancy as before. So TC9 (stub + rail both net `OUTI`) is
cleaned, while a stub bridging a **distinct** net is kept — the original 0040 protection. In any
*consistent* netlist a stub touching a served pin shares that pin's net, so the distinct-net case is the
transient mid-kissing inconsistency the baked cache still reflects; that transient case is preserved by
the lab comparison but (like the pre-fix state) is not separately reproducible in a clean scripted
fixture. TC9 is the sabotage-sensitive regression (it fails under the old bare-`lab` guard). Full
wireedit suite (20) + property_form (264) + main regression green.
