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
⚠ **Comment residue cleaned 2026-09-17 (see section 5).** The fix corrected the comment at the deleted
gate but left `write_backup()`'s own function header — and `set_modify()`'s call-site comment in
`actions.c` — still asserting the skip it had just removed, for 77 days.
**Severity:** HIGH — silent data loss: the unsaved top-level content is discarded, plus an
"Unable to open file: …/untitled.sch" alert under X.
**Branch:** `fluid-editing`.
**Source:** user report (2026-07-02).
**Affects:** `src/save.c` `write_backup()` — **today at `:6139`** (header comment `:6133-6138`; gates
`:6145-6153`; the corrective note `:6149-6152`), with the `~` name built by `backup_file_name()` `:6116`.
The descend/ascend restore is `src/actions.c` `go_back()` — **today at `:6435`**. The autosave hook that
calls it is `set_modify()`, `src/actions.c:201-208`.
⚠ **The citations above used to read `~:3471`, `~:3482` and `~:3616-3625`** — rotted by roughly 2700
lines. Re-measured 2026-09-17; see section 5. Related: [[descend-autosave]],
`doc/claude/specs/descend_hierarchy_in_memory.md`.

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

(**Historical.** That `save.c:3482` citation describes the **pre-fix** tree. The line was deleted by
the fix below and does not exist today — there is no `stat()` anywhere in `write_backup()`.)

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

## 5. Comment residue — found and fixed 2026-09-17 (harness-concurrency batch)

**The behaviour fix of 2026-07-02 left two comments behind asserting the behaviour it had just
removed.** Found by crew H1 while tracing where a stray `untitled~.sch` in the repo root comes from;
verified and fixed by crew 0060-comment. Receipt:
`doc/claude/harness_concurrency_batch/receipts/0060-comment.md`.

### What was wrong

| Site | Vintage | Said |
|---|---|---|
| `src/save.c:6137-6138` — `write_backup()`'s **function header** | `c408fe3ec`, 2026-06-21 | *"Skipped when autosave_backup is off or the buffer has no real on-disk file yet (untitled): there is nothing to back a `~` file against."* |
| `src/actions.c:204` — `set_modify()`'s **call-site** comment | `a9ca3cfdb`, 2026-06-21 | *"write_backup() is itself a no-op … or for an untitled buffer."* |

Both predate this issue's fix (`6cc6c6950`, 2026-07-02), which edited only the comment at the point of
the deleted `stat()` gate (`:6149-6152`). The header sat **six lines above** the code contradicting it,
inside the same function.

### Why it mattered enough to fix

The claim was **wrong in the direction that hides a live defect**. A reader chasing repo-root
`untitled~.sch` litter reads the header, concludes an untitled buffer can never produce a `~` file, and
stops — so the producer is never identified. That litter has now been filed **five separate times**
(0353, 0356, 0609, 0673, 0687) and remains unfixed; issue 1480 records the same finding independently
(`1480:78-93`). Compounding it, `.gitignore:74-75` ignores `*~.sch`, so the residue is invisible to
`git status` too: the comment was one blindness, the ignore rule a second, and they stack.

### What the code actually does (re-measured 2026-09-17)

`write_backup()` has **four** gates and **none** of them tests for untitled:
`no_autosave` (`:6145`), `autosave_backup` off (`:6146`), an **empty** buffer name (`:6148`), and no
`.sch`/`.sym` extension (`:6153`). Note the third is real but is **not** the untitled case — an
untitled buffer is not nameless, it carries a full path `<dir>/untitled.sch`, so it passes the gate and
**is** backed up. The resulting file is literally `<dir>/untitled~.sch`
(`get_unused_untitled_name`, `xinit.c:189` → `backup_file_name`, `save.c:6127-6129`), landing in
whatever directory the untitled name was composed against — `pwd_dir` at `actions.c:6594`, or
`$PWD`/`pwd_dir` at `save.c:6491-6503`. This is the behaviour asserted by
`tests/headless/test_backup_file.tcl:70`.

**This is correct and deliberate: a crash-recovery backup is exactly what an unsaved buffer needs.**
The fix was comment-only — both comments now say that the function is a *producer* for untitled
buffers, and why — with zero behaviour change.

### Not changed, deliberately

`doc/claude/specs/descend_hierarchy_in_memory.md:32-33` still reads *"skip buffers with no real on-disk
name (untitled / headless tests)"*, but it sits inside a `>` blockquote of the **original design plan**.
That is a historical record of what was proposed before this issue changed it, and rewriting history to
match the present would be a different error. Left as-is by design.
