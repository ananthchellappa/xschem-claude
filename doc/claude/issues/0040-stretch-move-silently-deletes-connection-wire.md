# Issue 0040 — Stretch-move can silently delete a connection-bearing wire

**Opened:** 2026-06-26
**Status:** ✅ FIXED 2026-07-02 (implemented on branch `fluid-editing`, uncommitted). Triaged 2026-07-01: was STILL PRESENT (`src/move.c:1372-1409`). Real severity **MEDIUM** (narrower than framed: the deleted wire's free end must be *dangling*, so the realistic data-loss case is a stub carrying its own `lab=` net name — deleting it silently renames the node). **Priority P1.** Fix effort **S**: skip wires with a `lab=` token and emit a `ciw_echo` on auto-removal; the full "endpoints resolve to same node after re-stitch" check is the **M** follow-up.
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

## Resolution (2026-07-02)

`remove_move_orphan_wires()` (`src/move.c`) now (1) skips any candidate stub carrying a `lab=` token
(`get_tok_value(...,"lab",0)[0]`), so a wire that names its own net is never auto-dropped — deleting it
would silently rename/lose the node even though the pin stays connected via the other wire; and
(2) emits a CIW cue via `ciw_echo` ("auto-removed N redundant wire(s) after move", `has_x`-gated) so the
trim is no longer silent. `removed` became a count for the message. The stronger
"endpoints resolve to the same node after re-stitch" proof (for unlabeled stubs on genuinely distinct
nets) remains the optional **M** follow-up. Builds clean; core regression suite green.

Test coverage TODO (from acceptance): a scripted stretch that drives a labeled stub into a moved pin and
asserts it survives and the message fires.
