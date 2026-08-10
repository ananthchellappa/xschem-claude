# 0362 — the `~` autosave backup carries no "whose work is this" identity, so three verbs treat a stranger's recovery file as their own

Status: **OPEN — filed, not fixed** (measured while working issue **0264**, item D3 of the
2026-08-09 backlog run). **This is the root cause that reverted 0264's attempt 1** — see the
"How this reverted 0264" section at the bottom.
Area: `src/save.c` (`write_backup` / `remove_backup` / `save_schematic`), `src/scheduler.c`
(`reload`, in-place `load`), `src/xinit.c` (window/tab teardown), `src/xschem.tcl`
(`xschem_recover_backup`).
Related: **0264** (attempt 1 written and REVERTED — nothing landed), **0244**, **0356**,
**0365**.

## The one missing question

`<cell>~.sch` is written by `write_backup()` on every `set_modify(1)` and deleted by
`remove_backup()` — and **nothing anywhere records which session wrote it**. Three
consequences were measured at HEAD and are NOT fixed by 0264:

1. **`xschem reload` and an in-place `xschem load` of another cell leave the `~` behind** while
   clearing `modified`. 0264's attempt 1 would have made that leftover honest to
   `hierarchy_modified()` (it is real unsaved work on disk), but `xschem_recover_backup` — whose
   only staleness rule is mtime — will still offer to "recover unsaved changes" the user
   *explicitly discarded*. That attempt was reverted, so today the leftover is simply invisible.
2. **Window/tab teardown after "ok, exit anyway"** leaves the `~` too (`delete_schematic_data`
   has no `remove_backup()`), same ambiguity.
3. **`save_schematic()` removes the `~` unconditionally after a real save**, so File > Save on a
   freshly-opened clean buffer destroys a *previous* session's crash backup that the user was
   never shown (headless opens never get the recovery offer at all —
   `scheduler.c` gates it on `!force && has_x`). The same happens through `save()`'s
   external-mtime `force = 1` arm, which saves with no prompt at all.

The spec sentence this contradicts is in `clear_schematic()` and in
`doc/claude/specs/descend_hierarchy_in_memory.md` (B8): *"a leftover `~` on the next open
unambiguously means a crash, not an intentional discard."* Measured false.

## Why 0264 did not fix it

0264 deliberately stopped at *not destroying* work (see its decision D4): deleting the `~` at
`reload` / `load` to restore the B8 purity would convert today's accidental-but-working
recovery file into a hard delete of the only copy of the user's edits. Making the artifact
self-describing (an owner/session marker, or an in-memory "this buffer's `~` is discarded"
state) is the real fix and is a design decision, not a patch.

## How this reverted 0264

0264's attempt 1 tried to answer "is this `~` unsaved work?" from the *filename plus mtime*,
because that is all the artifact offers. Both halves of the missing identity then bit:

**(a) Consequence 3 above survived the fix, as a measured composite** (adversary attack A13i,
never previously measured end to end). After a reload-discard leaves a live `~`, a second window
or an external tool moves the cell's mtime; `File > New` then takes `save()`'s `force = 1` arm,
and on "yes" `save_schematic()` writes the **clean** buffer over the cell *and* unlinks the `~`
holding the only copy. The user was asked about the *file changing* — never about the backup.
0264's guard sits one line below and cannot see it.

**(b) The mtime proxy has no answer for a cell that does not exist.** The fix counted a `~` as
live when the cell file was absent ("the `~` is all there is"), which is true for a crashed
untitled session and false for an *orphaned* one. Draw → `Save As` → `File > New` orphans
`untitled~.sch` (its content already safe under the new name) and left the blank canvas
reporting `hierarchy_modified() == 1` forever. Filename-and-mtime cannot tell those apart;
an owner marker can.

**(c) Second granularity.** `st_mtime` is whole-seconds and both readers use it
(`backup_is_live()`'s strict `>`, and `xschem_recover_backup`'s `>=` at `xschem.tcl:6606`), so a
cell written and edited inside one second reads as stale from both sides — the recovery dialog
silently **deletes** that `~` on the next interactive open. A monotonic marker written *into* the
`~` would not have this failure mode.

So the fix for this issue is a prerequisite for 0264's predicate half, not a follow-up to it.
