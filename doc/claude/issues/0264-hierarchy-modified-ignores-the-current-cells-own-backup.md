# 0264 — `hierarchy_modified()` ignores the CURRENT cell's own `~` backup, so a recovery file that holds the only copy of the work is not evidence of unsaved work

Status: **OPEN** — read off the code while fixing issue **0244**; not measured on its own, not
fixed. **Medium**: it cannot lose data by itself, but it is the amplifier that turned 0244 from a
wrong flag into a *deleted recovery file*.
Area: `src/save.c` — `hierarchy_modified()`, the backup-scanning loop
Tests: none.
Found: 2026-08-08, out of scope of issue **0244** (its landmine 2), filed on closing it.
Related: **0244** (the flag lie this made expensive), **0235** (a different modified-flag blind
spot).

## What it is

`hierarchy_modified()` answers the question every close/quit/ascend/File-New prompt actually asks:
*"is there unsaved work anywhere in this hierarchy?"*. It answers with `xctx->modified` **OR**, when
`autosave_backup` is on, "does any ancestor cell have a `<cell>~.sch` backup on disk".

The loop walks `xctx->sch[0 .. currsch-1]` — **ancestors only**. The cell the user is actually
looking at, `xctx->sch[currsch]`, is not in it. So at top level (`currsch == 0`) the loop is empty
and the function degenerates to `xctx->modified` alone.

## Why that matters

The `~` file of the current cell is exactly the artefact that holds unsaved work when the in-memory
flag is wrong or has been cleared. Issue 0244 was that case: an ESC-ed paste cleared `modified` on a
dirty document, `hierarchy_modified()` had nothing else to go on, every prompt went quiet, and
`clear_schematic()` then ran its silent `save(1, 0)` (a no-op, because the flag said clean) followed
by `remove_backup()` — deleting the file that still held the correct content. Measured in 0244:

```
3 after ESC      modified=0 hier_mod=0 wires=2   backup exists=1
     backup holds the CORRECT post-abort content; the on-disk cell does NOT
=== xschem clear (File > New) ===
     backup exists=0        <-- destroyed, no prompt was ever shown
```

0244's fix removes the flag lie, so this no longer has a known trigger. It remains a missing
belt: any other future path that clears `modified` while a `~` file exists reproduces the same
silent destruction.

## Sketch

Include the current level in the backup scan (`0 .. currsch`), or check `xctx->sch[currsch]`'s
backup explicitly beside the `xctx->modified` test.

**The risk to weigh before doing it** is false positives: a stale `~` file left by a previous
crashed session would then make every Close/Quit prompt fire on an untouched document. That is
probably still the right trade (a spurious prompt is cheap; a deleted recovery file is not), but it
is a user-visible behaviour decision and wants its own measurement of how often stale backups
survive — `remove_backup()` is called on the paths that legitimately end a cell's life, so a
leftover `~` genuinely does mean "a session died with unsaved work".
