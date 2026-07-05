# Issue 0069 — mouse-gesture drops recorded as non-replayable `#` markers

**Opened:** 2026-07-02
**Status:** OPEN — identified by the action-log coverage audit; partially
deferred by spec. Not yet fixed.
**Severity:** MED — the gesture *is* logged (a `#` comment appears in file + CIW),
but the line does not replay the mutation, so a sourced log silently drops these
edits.
**Branch:** `fluid-editing`.
**Source:** user-requested full audit of unlogged user interactions.
**Affects:** `src/callback.c` `end_move_copy_logged` (:1553–1619).
**Related:** [[action-logging]], [[wire-editing-on-move]]; spec §6 (anchor-
preserving transform not minted); issue 0005 (shape control-point + click-select
referents — those markers are tracked there, not here); umbrella 0071.

---

## 1. Symptom

Completing certain canvas gestures writes a `#` comment instead of a replayable
`xschem …` command. The object is created/moved, but re-sourcing the log does not
reproduce it.

## 2. Root cause

Each stub reflects a missing replayable form (no subcommand that reproduces the
gesture from its logged data), per `end_move_copy_logged`.

## 3. Scope — stubs that correspond to real mutations

- `# paste/merge drop at delta …` (:1567) — dropping an in-progress paste/merge
  (`STARTMERGE`) after dragging to a delta. Adds clipboard/merge objects at the
  drop; the fixed-mouse context-menu `xschem paste` does not cover the drag-drop.
- `# place symbol pin (no replayable subcommand yet)` (:1570) — dropping a symbol
  pin (`START_SYMPIN`). Note: an `xschem add_symbol_pin` subcommand already
  exists (registered `callback.c:3036`) but the drop path doesn't read the pin
  back to emit a coordinate form.
- `# move/duplicate selection with rotate/flip …` (:1612) — a move/copy drop
  where the selection was also rotated/flipped mid-gesture; no single subcommand
  both translates and rotates about the gesture anchor (spec §6).

Fallback-only stubs (normal path logs a real line; only the read-back-failure
branch is a stub) — lower priority: `# place symbol (instance not cleanly
recordable)` (:1590), `# place text (text not cleanly recordable)` (:1609).

Out of scope here (tracked in 0005): `# edit shape control point` (:3787) and the
context-menu descend markers (:2534/:2544).

## 4. Fix sketch

- **place symbol pin:** read the placed pin back post-drop and emit `xschem
  add_symbol_pin x y …` (mirror the existing `PLACE_SYMBOL`/`PLACE_TEXT`
  read-back path at :1587/:1606).
- **paste/merge drop:** mint a subcommand that pastes the current clipboard/merge
  buffer at a delta (e.g. `xschem paste_at dx dy` or a merge variant), then log
  it. Blocked partly on the clipboard-content referent.
- **rotate/flip-during-move:** either mint an anchor-preserving transform
  subcommand or decompose into `move_objects` + `rotate/flip` about the recorded
  anchor. Deferred by spec §6; capture the decision here.
