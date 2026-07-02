# Issue 0043 — Disk-based undo invalidates session-stable ids, breaking the apply-scope overlay and `xschem object` handles

**Opened:** 2026-06-26
**Status:** FIXED 2026-07-02 (`fluid-editing`). Per-slot **side-channel id snapshot**, exactly the
M–L option: a new `Undo_ids undo_ids[MAX_UNDO]` ring (lazily allocated, `xschem.h`) captures the live
session-stable ids (wire/inst/text/gfx) in canonical save-order at `push_undo` (on the same ring index
the disk slot uses), and `pop_undo` re-stamps them onto the restored objects right after
`read_xschem_file` (before `synth_pin_views`). Positional correspondence is exact — `read_xschem_file`
appends verbatim with no merge/reorder, so the k-th object written to a slot is the k-th read back;
synthesized pin-name texts are skipped at both capture and restore (they never persist). A shape guard
bails (keeps fresh ids, no mis-assign) if counts ever disagree. Ids are NOT baked into the `.sch/.sym`
format (no `XSCHEM_FILE_VERSION` bump). Restored ids are ≤ the monotonic counters, so future births
never collide. Freed in `delete_undo`. Test: `tests/undo_stable_ids.tcl` (26 checks, both undo modes) —
a captured instance/wire/text/rect handle still resolves to the SAME object with the SAME id value after
a disk undo AND redo, disk now matches memory; sabotage-verified (neutering the re-stamp fails exactly
the 8 disk id checks, memory stays green). Full property_form suite (264) + create_save/open_close/
netlisting green.
**Prior triage** (2026-07-01): verified STILL PRESENT; in-memory undo preserves ids (`in_memory_undo.c` struct-copies `.id`), disk undo re-stamps them via the store funnels (asymmetry confirmed). ⚠ On-disk undo is the DEFAULT (`xschem.tcl:14613`), so this bit out-of-the-box. Real severity **MEDIUM.** **Priority P2.** Fix effort **M–L**. (Cheapest mitigation considered but rejected in favor of the real fix: default `undo_type=memory` when the overlay/handle APIs are in use.)
**Severity:** MEDIUM — silent loss of the white-outline scope overlay and stale/dangling object handles
after an undo (only when on-disk undo is in effect).
**Branch:** `fluid-editing`.
**Source:** `/code-review high` this session (workflow `wf_1a6ce6c4-0d9`), finding #5 (CONFIRMED).
**Affects:** `src/store.c` store funnels (`wire_store`/`inst_register`/`gfx_register`/text) which stamp
fresh session-stable ids on every (re)load — **including the disk-based undo restore** (the resolver
comments explicitly note ids are "invalidated by a disk-undo restore", ~:351); consumers
`scope_hi_id` (net-hilight apply-scope overlay) and the `xschem object(s)` handle API resolve ids → index
at use time. Related: [[stable-object-handles]], [[net-hilight-styles]], `in_memory_undo.c`.

---

## 1. Symptom

With on-disk undo in effect: after an **Apply-with-scope** (the white-outline overlay marking the
scoped objects) followed by **Undo**, the scope overlay silently disappears, and any previously-obtained
`xschem object` handles stop resolving (return nothing / the wrong object). The in-memory undo path
does not show this (it preserves the live arrays / ids).

## 2. Root cause

Session-stable ids are guaranteed stable only *within a single load*. A disk-based undo is a reload:
the store funnels re-stamp every restored object with a **new** id, so any id captured before the undo
(scope overlay, handle) no longer matches. The resolvers correctly return "not found", but the overlay
and handle holders have no way to recover.

## 3. Fix sketch

Preserve ids across a disk-undo: serialize each object's stable id into the undo slot and restore it on
pop (so the id survives the round-trip), or re-key the scope overlay / handle table on the undo event,
or make in-memory undo the default for sessions that use the overlay/handle APIs. Add a test: capture a
handle, Apply-with-scope, Undo (disk mode) → the handle still resolves and the overlay persists.

## 4. Acceptance

An undo (in either undo mode) does not silently invalidate the scope overlay or live object handles.
