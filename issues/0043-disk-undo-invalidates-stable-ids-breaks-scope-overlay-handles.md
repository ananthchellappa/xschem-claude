# Issue 0043 — Disk-based undo invalidates session-stable ids, breaking the apply-scope overlay and `xschem object` handles

**Opened:** 2026-06-26
**Status:** OPEN
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
