# Issue 0046 — Stretch attach uses `endpoint_near()` while the rest of the pipeline uses exact `==`, dragging an unrelated wire

**Opened:** 2026-06-26
**Status:** OPEN
**Severity:** MEDIUM (verifier verdict: **PLAUSIBLE**) — only on schematics with fractional / sub-grid
coordinates.
**Branch:** `fluid-editing`.
**Source:** `/code-review high` this session (workflow `wf_1a6ce6c4-0d9`), finding #8 (PLAUSIBLE).
**Affects:** `src/select.c` `select_attached_nets()` (~:1352, uses `endpoint_near()` with tolerance
`cadsnap/2`) vs `src/move.c` `point_on_moving_pin()` / `point_on_fixed_pin()` (exact `==`).
Related: [[wire-editing-on-move]], issues 0013/0014/0017.

---

## 1. Symptom

On a schematic with fractional or sub-grid coordinates, stretch-moving a component grabs
(`SELECTED1`/`SELECTED2`) an unrelated wire endpoint that merely lies *within* `cadsnap/2` of the moved
pin and drags it, deforming a wire that belongs to a different net. The corner-slide guards then don't
fire (their exact pin test fails), so the wire jogs unexpectedly. The user sees an unrelated wire
bent/displaced after a simple move.

## 2. Root cause

`select_attached_nets()` was changed to decide "attached" by `endpoint_near()` (tolerance `cadsnap/2`),
but the downstream stretch pipeline (`point_on_moving_pin`/`point_on_fixed_pin` in `move.c`) still tests
pins with exact `==`. The two ends of the pipeline disagree on what "on the pin" means, so a wire can be
selected for stretching that the rest of the pipeline does not treat as pin-attached.

## 3. Fix sketch

Make the attach decision and the pin tests use the *same* predicate — either both exact, or both
tolerance-based (`endpoint_near`) — so a wire is grabbed for stretching iff the corner-slide / pin logic
also treats it as attached. Add a regression on sub-grid coordinates: a nearby-but-unrelated wire is not
dragged by a component move.

## 4. Acceptance

Stretch-move attaches exactly the wires the corner-slide/pin logic recognizes; no unrelated wire is bent
on sub-grid layouts.
