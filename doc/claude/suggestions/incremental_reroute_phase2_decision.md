# Phase II decision record — incremental per-snap-step reroute (timing)

Branch `fluid-editing`. Spec `doc/claude/specs/incremental_wire_reroute.md` §5/§8. Tip 3995ca45.

## Decision: restore-and-reapply the TOTAL delta each step (spec §5 shape 1). CHOSEN.

**Why (over accumulate-mutations):**
- **Byte-identical stepwise==release is structural, not proven.** Each qualifying RUBBER
  step RESTORES the pristine pre-move geometry+selection, then applies the *current total*
  delta through the **unchanged** END pipeline. The committed result on release is literally
  `pipeline(pristine, final_delta)` regardless of how many intermediate steps ran — the
  intermediate steps have ZERO effect on the final state (each is discarded by the next
  restore). Release-only (no steps) and stepwise both reduce to the same call. No drift proof
  needed; `trim_wires`/`insert_exit_stubs` statefulness cannot accumulate.
- **Builds the snapshot infra Phase III/IV consume** (spec §10.1/§10.2 explicit `F`/terminal
  state). We reuse the existing full-schematic snapshot pair `mem_serialize_slot` /
  `mem_restore_slot` (in_memory_undo.c) — already decoupled from the undo stack — into a
  dedicated in-memory scratch slot `xctx->fluid_reroute_snap`. Independent of the configured
  undo backend (disk or memory): the snapshot is ALWAYS in-memory, so no per-tick disk churn.
- accumulate-mutations is cheaper per step but must PROVE no drift vs END across
  buses/kissing/merge — fragile, and lands no reusable infra.

## Mechanism (surgical, gated on `fluid_editing` — default off ⇒ byte-identical)

New xctx state: `Undo_slot fluid_reroute_snap` (+ per-layer arrays, lazily alloc'd),
`int fluid_reroute_active` (snapshot valid this gesture), `int fluid_reroute_dirty` (a RUBBER
step committed geometry).

- **START** (move.c, at the fluid_snapshot_partition point, AFTER select_attached_nets +
  connect_by_kissing): if `fluid_editing && stretch_select`, `mem_serialize_slot(&snap)` =
  pristine post-kiss, pre-delta geometry WITH selection flags. Set `active=1, dirty=0`.
- **RUBBER** step: if active, and snapped pos changed (existing top-of-RUBBER filter — mousex_snap
  is already cadsnap-quantized, so any change is ≥1 cadsnap): set delta=total; `mem_restore_slot`;
  `need_reb_sel_arr=1; rebuild_selected_array()`; `commit_move_geometry()`; `dirty=1`; zero delta;
  `draw()`. RETURN before the XOR-preview branch (never mix preview + committed geometry).
- **END**: if `active && dirty`, `mem_restore_slot` + rebuild BEFORE the existing `push_undo`
  (so undo baseline = pristine, not the last intermediate route). Then the EXISTING END body
  runs unchanged, calling the SAME `commit_move_geometry()`. Free snap; clear flags.
  If `!dirty` (release-only, incl. the headless `move_objects dx dy` seam), NO restore — the
  existing inline path runs verbatim ⇒ trivially byte-identical to today.
- **ABORT**: if active, `mem_restore_slot` FIRST (live ⇒ post-kiss pristine = exactly the state
  today's ABORT sees at entry, since RUBBER used to only preview) → existing ABORT logic
  (kissing `pop_undo` etc.) runs unchanged → free snap.

`commit_move_geometry(orthogonal_wiring)` = the extracted END geometry block (move.c
~1938–2320: `update_symbol_bboxes` → `compute_wire_slide` → the k-loop transform → the ELEMENT
loop → `check_collapsing_objects` → `trim/maintain` → `remove_move_orphan_wires` →
`insert_exit_stubs` → `unselect_partial_sel_wires` → Phase-I fluid deselect). NO draw calls
inside; re-fetches `xctx->wire`/`xctx->line` fresh (the top-of-move_objects `const` locals are
stale after a restore reallocates the arrays). Both END and the RUBBER step call it ⇒ identical
code ⇒ byte-identical by construction.

## Invariants held
- **One undo per gesture.** We add NO undo push/pop. The single baseline is the existing END
  `push_undo` (non-kissing) or the `connect_by_kissing` START push (kissing). The scratch snap is
  orthogonal to the undo stack. Restore-before-push at END keeps the baseline = pristine.
- **Algorithm unchanged** (Phase III owns the R18 short). `commit_move_geometry` IS today's code.
- **Determinism (P8):** step result = pure fn of (snapshot, total delta) — snapshot is exact.
- **Memcheck:** per-step `mem_restore_slot` frees+reallocs every array — run `--memcheck`.

## Adversarial-review fixes folded in (5-lens design critique, pre-code)
- **`mem_restore_slot` → `unselect_all(1)` zeroes `ui_state`** (select.c:834), dropping STARTMOVE
  mid-gesture. `fluid_reroute_restore()` saves `ui_state` across the restore and puts it back.
- **END must NOT re-commit at zero delta.** The RUBBER step keeps `deltax/deltay = total` on
  return (it only zeroes them transiently around the redraw, then restores), so interactive END
  (`dx=dy=0` args → uses accumulated delta) applies the real total, not zero → the drag does not
  snap back. The redraw zeroes delta so `draw_selection` (draws at coord+delta) does not double-offset
  the already-committed geometry.
- **Stale `xWire* const wire`/`xLine** const line`** (move.c top) are use-after-free once a restore
  reallocs the arrays → `commit_move_geometry()` re-fetches `xctx->wire`/`xctx->line` fresh; the two
  outer `const` locals are removed.
- **Scratch slot per-layer arrays** (`lines/rects/arcs/polygons` + `lptr/bptr/aptr/pptr`) are alloc'd
  by `mem_snapshot_alloc()` (mirrors `mem_init_undo`), independent of the undo backend, else
  `mem_serialize_slot` NULL-derefs. Freed by `mem_snapshot_free()` each gesture (no exit leak).
- **`movelastsel` refresh:** `fluid_reroute_restore()` sets `movelastsel = lastsel` after rebuild, so
  `update_symbol_bboxes`'s `[0,movelastsel)` bound tracks the restored selection (else the dce0bea6
  `symbol_bbox` heap-overflow re-fires per tick).
- **Stable-id counters** (`wire/inst/gfx/text_id_counter`) are captured at START and restored after
  every `mem_restore_slot` before commit, so tool-created wires re-stamp identical ids each step (P8
  determinism; ids are not in the `.sch` so the byte compare is unaffected either way).
- **No leaked `active`:** `fluid_reroute_discard()` (free snap + clear `active`/`dirty`) runs on EVERY
  END and ABORT exit; the RUBBER commit is gated on `fluid_editing && stretch_select && active`; the
  END restore/free block sits ABOVE the no-motion early-return so a zero-delta release still frees.
- **ABORT repaints:** after a dirty ABORT rolls geometry back, a full `draw()` runs (arrays changed).
- **Extraction cut:** `commit_move_geometry` ends at the Phase-I deselect (~move.c:2320); the
  `stretch_select=0` / free `stretch_grabbed_xy` (2321-2323) stay in the END/ABORT caller (freed once).

## Implementation-review fixes (2nd workflow, on the actual diff — 3 confirmed majors)
- **Buffer teardown mid-gesture resurrected/leaked the snapshot.** `move_objects start; xschem clear
  force; move_objects step` restored the pre-clear geometry onto the emptied buffer (deleted content
  back, delta-shifted) + leaked the deep copy. Fix: `clear_schematic()` now calls
  `fluid_reroute_discard()` + frees the stretch scope; the RUBBER incremental gate additionally
  requires `ui_state & STARTMOVE` (which teardown zeroes). Regression: test_33 case J (sabotage-verified).
- **Zero-delta END early-return leaked the stretch scope.** A fluid drag out and back to the origin
  snap (`drag_elements && delta==0`) returned before the post-finalizers, so `stretch_select` /
  `stretch_grabbed_xy` bled into the next gesture (which Phase II's stretch_select-keyed gates then
  mis-routed). Fix: the early-return now clears `stretch_select`/`stretch_grabbed_n` and frees
  `stretch_grabbed_xy`, mirroring the normal END tail. (Interactive-only path; not headless-reachable.)
- **Spurious `modified` on aborted/no-op fluid drags.** Fix: the live RUBBER step no longer calls
  `set_modify()` — the flag is set only at the real END (matching a non-fluid drag preview), so an
  aborted or return-to-origin drag leaves the buffer clean. Floaters still refresh live because each
  step's `mem_restore_slot` invalidates `floater_inst_table`. Regression: test_33 case K (ABORT rollback).
- Verified `start+clear`-abandon is leak-clean (matches the pre-existing baseline; the snapshot and
  `stretch_grabbed_xy` are freed). Added `move_objects abort` to the headless seam for case K.

**Deferred (documented, NOT Phase II):** (a) the k-loop `wire`/`line` local can go stale mid-loop if
`place_moved_wire()->storeobject()` reallocates the array — PRE-EXISTING on HEAD (identical pattern),
memcheck-clean in the suite, orthogonal to timing; (b) ROTATE/FLIP interleaved with a live fluid drag
leaves an XOR preview over committed geometry — the committed END result is still correct (END is the
authoritative restore+reapply), only the transient preview glitches.

## Known cost (spec open decision §10.3)
`mem_serialize/restore_slot` deep-copies the WHOLE schematic each committed RUBBER tick. Fine at
interactive rates for moderate schematics; scope-to-follow-set optimization deferred (the END
commit is authoritative regardless, so throttling the live preview never affects correctness).

## Test seam
Extend `xschem move_objects` (scheduler.c `xschem_cmds_m`) with explicit stepping:
`move_objects start [kissing] [stretch]` / `move_objects step <x> <y>` (sets mousex/y_snap +
RUBBER) / `move_objects end [dx dy]`. Existing `move_objects dx dy ...` (START+END) unchanged.
RED-first teeth: a `step` mid-drag must COMMIT (live geometry changes before END) — false before
the hook exists ⇒ RED; true after ⇒ GREEN. Plus stepwise==release segset equality, gated-off
no-mid-commit, and one-undo-entry cases.
