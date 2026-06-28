# Issue 0041 — Read-only enforcement lives at keyboard-dispatch altitude and is bypassable via Tcl edit paths

**Opened:** 2026-06-26
**Status:** OPEN
**Severity:** HIGH — protection bypass / data integrity; a file-protected schematic can be mutated and
saved with no modified marker.
**Branch:** `fluid-editing`.
**Source:** `/code-review high` this session (workflow `wf_1a6ce6c4-0d9`), finding #3 (CONFIRMED;
merges the two read-only findings — same root cause).
**Affects:** `src/callback.c` `readonly_block()` (:35) + ~45 `if(readonly_block()) break;` guards in
the keyboard switch; the action-binding guard at `callback.c:3136` via `action_id_mutates()`
(`callback.c:3102`, a hand-maintained 9-id allowlist with **default-allow**); the `xschem` Tcl edit
subcommands in `scheduler.c` (delete @1019, flip @1466, `move_objects` @4181, paste @5048, rotate
@6441, …) which have **no** guard; `set_modify()` suppresses the `*` marker on a read-only buffer.
Related: [[readonly-enforcement]], [[descend-readonly]].

---

## 1. Symptom

A read-only (file-protected / browse) schematic can be freely mutated via Tcl scripts, action
bindings, the TCP/stdin command server, or any non-keyboard path — then exported or Saved-As with the
edits. Because `set_modify()` does not flag a read-only buffer modified, the bogus edit shows **no**
`*` marker and does not prompt on close.

## 2. Root cause

Read-only is enforced at **dispatch altitude** with hand-maintained lists, not at the **mutation
chokepoint**. `readonly_block()` and its ~45 call sites guard only the keyboard switch; the
action-binding path guards via a 9-entry `action_id_mutates()` allowlist that returns 0 (non-mutating)
for any id not listed. The actual mutators (`store`, `push_undo`/`set_modify`, the `xschem` edit
subcommands) never consult `xctx->readonly`, so any path that doesn't go through the keyboard switch
edits freely. Every future edit entry point must remember to add its own guard — a leak-by-default
design.

## 3. Fix sketch

Move enforcement to the chokepoint: reject mutation in the shared funnel(s) — e.g. `push_undo()` /
`set_modify(1)` / the `store` registration funnels return early (with a single `ciw_echo`) when
`xctx->readonly`. Then every edit path — keyboard, Tcl subcommand, action binding, command server — is
covered by construction, and the scattered `readonly_block()` guards become a fast-path UX nicety
rather than the sole defense. Verify a `xschem delete`/`paste`/`rotate` on a read-only schematic is a
no-op and leaves the buffer unmodified.

## 4. Acceptance

No edit path can mutate a read-only schematic; the modified marker and save-prompt behavior are
consistent regardless of how the edit was attempted.
