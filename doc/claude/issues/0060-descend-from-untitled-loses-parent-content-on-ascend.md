# Issue 0060 — Descending from an UNTITLED (unsaved) schematic loses the parent content on ascend

**Opened:** 2026-07-02
**Status:** FIXED 2026-07-02 (`fluid-editing`). Dropped the `stat(name)` untitled skip in
`write_backup()` (`src/save.c`): a buffer with a non-empty logical name is now backed up to
`cellName~.sch` even when its base file is not yet on disk, so `go_back()` restores an unsaved untitled
parent via `load_backup_as()` instead of failing to open `untitled.sch`. Gated as before on
`autosave_backup` (default on) and `name[0]`; read-only buffers are still skipped upstream (`set_modify`
`ro_suppress`). Test: `tests/headless/test_descend_untitled_preserve.tcl` (place instance on untitled →
descend → go_back → content + modified flag preserved, no prompt), sabotage-verified RED (3 fails) on
the old skip. `test_backup_file.tcl`'s "untitled skipped" check flipped to "untitled IS backed up".
Full descend/backup suite + property_form 264 + wireedit 20 + main regression green.
**Severity:** HIGH — silent data loss: the unsaved top-level content is discarded, plus an
"Unable to open file: …/untitled.sch" alert under X.
**Branch:** `fluid-editing`.
**Source:** user report (2026-07-02).
**Affects:** `src/save.c` `write_backup()` (~:3471, the `stat(name)` early-return that skips untitled
buffers); the descend/ascend restore in `src/actions.c` `go_back()` (~:3616-3625) which relies on the
`cellName~.sch` autosave backup. Related: [[descend-autosave]], `doc/claude/specs/descend_hierarchy_in_memory.md`.

---

## 1. Symptom (user repro)

1. Open a schematic read-only; select some items including an instance; **Ctrl-C** (copy).
2. **Ctrl-N** — new blank canvas (an *untitled* buffer, `untitled.sch`, never saved to disk).
3. **Ctrl-V** — paste; the untitled canvas now holds the copied objects and is `modified`.
4. Descend into the pasted instance.
5. Pop back to the top level →

```
Unable to open file: /home/qflow/dev/xschem/claude_1/xschem/untitled.sch
```

and **the pasted content is gone** (the top level comes back empty).

## 2. Root cause

The descend/ascend design keeps the parent's unsaved edits in a `cellName~.sch` autosave backup:
`set_modify(1)` → `write_backup()` on every genuine edit, and `go_back()` restores the parent via
`load_backup_as()` (falling back to `load_schematic(cellName)` only when no backup exists). But
`write_backup()` bails for an untitled buffer:

```c
if(stat(name, &buf)) return; /* no real on-disk file (untitled): nothing to back up */   // save.c:3482
```

Since `untitled.sch` has no on-disk file, `stat` fails and **no `untitled~.sch` is written**. On
descend the single object arrays are overwritten by the child; on `go_back()` there is no backup, so it
falls to `load_schematic(1, "untitled.sch", …)`, which cannot open the nonexistent file →
`clear_drawing()` + the "Unable to open file" alert → the parent content is lost.

Headless repro (content loss is observable without X; the alert is `has_x`-gated):
`clear force` → `instance …/bf.sym` (instances=1, modified=1) → `BACKUP untitled~.sch exists=0` →
`descend` → `go_back` → **instances=0**.

## 3. Fix sketch

Let `write_backup()` back up an untitled buffer too (a non-empty logical name whose base file is not yet
on disk), so `go_back()`'s `load_backup_as()` restores it exactly as for a titled parent. Removing the
`stat(name)` skip is sufficient — the backup exists to hold *unsaved* content, and whether the base file
exists on disk is irrelevant to that. (Gated as today on `autosave_backup`, default on; `!name[0]` still
excludes a truly-nameless buffer.) The backup lifecycle is unchanged: `save_schematic`/`remove_backup`
drop it on a real save or discard.

## 4. Acceptance

Descending from an untitled schematic that has unsaved content and then ascending restores that content
(no "Unable to open file" alert, no data loss). A regression: place an instance on an untitled buffer,
descend, `go_back`, assert the instance is still present.
