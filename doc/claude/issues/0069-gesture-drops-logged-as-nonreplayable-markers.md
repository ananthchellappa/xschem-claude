# Issue 0069 — mouse-gesture drops recorded as non-replayable `#` markers

**Opened:** 2026-07-02
**Status:** OPEN — paste/merge drop FIXED 2026-07-14 (atom 9, see §3/§4 strikethrough
and the audit doc §12); **sympin (symbol + schematic) drop FIXED 2026-07-15 (atom 11,
audit doc §14)**; rotate/flip-during-plain-move still open (keeps this issue OPEN).
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

- ~~`# paste/merge drop at delta …` — dropping an in-progress paste/merge
  (`STARTMERGE`) after dragging to a delta.~~ **FIXED 2026-07-14 (atom 9):** the
  drop logs `xschem paste <dx> <dy> [<rot> <flip> [local]] [-anchor ax ay]
  [-file {f}]` — the scheduler paste branch's own (extended) coordinate replay
  form, so replays bypass the funnel and never re-log. Clipboard pastes replay
  against the replay-time clipboard content (accepted delta) with the rotation
  pivot pinned by `-anchor` (the replayed `xschem copy` regenerates the G
  record, so the pivot must ride the line); file merges carry their recorded
  source via `-file` (`xctx->merge_source`, stashed by `merge_file`); a
  mid-gesture rotate/flip rides as `rot flip [local]`. The ctx-menu pick-8
  `xschem paste` table line was removed (the drop line is the record; a kept
  pick line would replay a second merge), and `merge_file` no longer leaves
  `STARTMERGE` dangling after an empty merge (a dangler mislogged the next move
  drop as a paste). Audit doc §12 (incl. review round + documented residuals:
  unrecorded ESC-abort of a channel-typed paste; mutable `-file` referents);
  locked by `test_paste_at_log.tcl` (40 checks) + grep-guard S1/S1c/S2/S3 rows.
- ~~`# place symbol pin (no replayable subcommand yet)` — dropping a symbol
  pin (`START_SYMPIN`).~~ **FIXED 2026-07-15 (atom 11):** ONE marker covered TWO
  drops that share `START_SYMPIN` + the sympin-preview move machinery, now told
  apart in `end_move_copy_logged` by the dropped object's type: a **symbol pin**
  (a `PINLAYER` xRECT) logs `xschem add_symbol_pin <x> <y> <name> <dir> 0 1` (the
  direct form gained a trailing `noline` arg so the replay stores no stub leg line
  and reproduces the move-time `pin_view_writeback`, making the save byte-identical
  to the drop); a **schematic pin** (an ipin/opin/iopin ELEMENT placed by
  `add_sch_pin -place`) logs the same `xschem instance {sym} x y rot flip {prop}`
  read-back as a normal symbol placement (new shared `log_placed_instance` helper).
  Both replay forms are coordinate commands that bypass the funnel, so a replay
  never re-logs. Audit doc §14; locked by `test_sympin_drop_log.tcl` (42 checks) +
  grep-guard S1/S1c/S2/S3 rows. Residual: a mid-gesture rotate/flip of a sym-pin
  preview replays the label at rot/flip 0 (same class as the open
  rotate/flip-during-plain-move marker below).
- `# move/duplicate selection with rotate/flip …` (:1612) — a move/copy drop
  where the selection was also rotated/flipped mid-gesture; no single subcommand
  both translates and rotates about the gesture anchor (spec §6).

Fallback-only stubs (normal path logs a real line; only the read-back-failure
branch is a stub) — lower priority: `# place symbol (instance not cleanly
recordable)` (:1590), `# place text (text not cleanly recordable)` (:1609).

Out of scope here (tracked in 0005): `# edit shape control point` (:3787) and the
context-menu descend markers (:2534/:2544).

## 4. Fix sketch

- ~~**place symbol pin:** read the placed pin back post-drop and emit `xschem
  add_symbol_pin x y …` (mirror the existing `PLACE_SYMBOL`/`PLACE_TEXT`
  read-back path).~~ DONE (atom 11) — exactly as sketched for the symbol pin, plus
  the schematic-pin (instance) variant via the shared `log_placed_instance` and a
  `noline`/writeback replay arg for byte-identical symbol-pin geometry. See §3
  strikethrough and audit doc §14.
- ~~**paste/merge drop:** mint a subcommand that pastes the current clipboard/merge
  buffer at a delta (e.g. `xschem paste_at dx dy` or a merge variant), then log
  it. Blocked partly on the clipboard-content referent.~~ DONE (atom 9): no new
  subcommand needed — the existing `xschem paste [x y]` branch was extended in
  place; the clipboard referent stays conventional (replay-time re-read).
- **rotate/flip-during-move:** either mint an anchor-preserving transform
  subcommand or decompose into `move_objects` + `rotate/flip` about the recorded
  anchor. Deferred by spec §6; capture the decision here.
