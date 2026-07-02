# Issue 0047 — `insert_exit_stubs()` stores wires mid-scan, so freshly inserted stubs re-enter later pin scans

**Opened:** 2026-06-26
**Status:** ✅ FIXED 2026-07-02 (implemented on branch `fluid-editing`, uncommitted). Triaged 2026-07-01: was STILL PRESENT (`move.c:1442-1506`; inner scans use live `xctx->wires`, `storeobject` bumps it at `store.c:344/371`). Geometry-gated AND behind the default-OFF `wire_exit_stub` flag, so no user hits it today. Real severity **MEDIUM**, low urgency. **Priority P3.** Fix **S**: snapshot `int nwires0=xctx->wires;` before the loops and bound the three inner scans (`:1464/:1480/:1490`) by it, or defer stub insertion to a second pass.
**Severity:** MEDIUM (verifier verdict: **PLAUSIBLE**) — only with `wire_exit_stub` enabled, on
multi-pin component moves.
**Branch:** `fluid-editing`.
**Source:** `/code-review high` this session (workflow `wf_1a6ce6c4-0d9`), finding #9 (PLAUSIBLE).
**Affects:** `src/move.c` `insert_exit_stubs()` (~:1411). `storeobject()` reallocs `xctx->wire` and
increments `xctx->wires` inside the per-instance / per-pin loops, while the inner scans iterate
`for(n=0; n<xctx->wires; n++)`. Related: [[wire-editing-on-move]].

---

## 1. Symptom

With `wire_exit_stub` enabled, moving a multi-pin component can produce spurious extra exit stubs or
mis-detected "corners": a stub just stored for one pin is counted as an attached/corner wire when
processing a subsequent pin of the same (or another) moving instance, yielding stray dangling segments
at moved pins.

## 2. Root cause

`insert_exit_stubs()` appends stub wires via `storeobject()` (which grows `xctx->wire` and bumps
`xctx->wires`) while the surrounding scans use `xctx->wires` as their live upper bound. So a wire created
for pin *k* is visible to the scan for pin *k+1*, which can treat the new stub as a pre-existing attached
wire.

## 3. Fix sketch

Snapshot the wire count before the loop (`int nwires0 = xctx->wires;`) and bound the inner scans by the
snapshot, or defer all stub insertions to a second pass after the scans complete (collect intended stubs
in a temp list, then `storeobject()` them). Add a regression: moving a multi-pin component with
`wire_exit_stub` on produces exactly one stub per exiting pin, no extras.

## 4. Acceptance

A multi-pin move with exit-stubs enabled inserts exactly the intended stubs; previously-inserted stubs do
not perturb later pins' corner/attachment detection.

## Resolution (2026-07-02)

`insert_exit_stubs()` (`src/move.c`) now snapshots `int nwires0 = xctx->wires;` at entry and bounds all
three inner scans (pin-endpoint count, corner detection, corner-neighbour drag) by `nwires0` instead of
the live `xctx->wires`. Stubs appended via `storeobject()` land at index >= `nwires0`, so they can no
longer re-enter a later pin's / instance's scans. Still behind the default-OFF `wire_exit_stub` flag.
Builds clean; core regression suite green.

Test coverage TODO (from acceptance): a scripted multi-pin move with `wire_exit_stub` on, asserting
exactly one stub per exiting pin.
