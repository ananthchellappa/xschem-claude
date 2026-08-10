# 0264 — `hierarchy_modified()` ignores the CURRENT cell's own `~` backup, so a recovery file that holds the only copy of the work is not evidence of unsaved work

Status: **OPEN — MEASURED, attempt 1 written and REVERTED** (item D3 of the 2026-08-09 backlog
run). Upgraded from "read off the code, never measured" to **reproduced three ways with actual
content loss**; the fix that was built and tested introduced a worse user-visible regression and
was backed out. Nothing of it is in the tree — see *Attempt 1* below and
`doc/claude/issues/0264-attempt-1-reverted.patch` for the exact diff.
**Severity raised to High**: it does lose data by itself, on two ordinary paths
(`File > Reload`, opening another cell), with no paste and no 0244 flag lie involved.
Area: `src/save.c` — `hierarchy_modified()`, the backup-scanning loop; and (the real destructor,
found by measuring) `src/actions.c` — `clear_schematic()`'s unconditional `remove_backup()`.
Tests: none in the tree. The attempt's 15 new rows are inside the reverted patch.
Found: 2026-08-08, out of scope of issue **0244** (its landmine 2), filed on closing it.
Measured: 2026-08-09/10.
Related: **0244** (the flag lie this made expensive), **0235** (a different modified-flag blind
spot), **0362** (the `~` has no owner — the root the attempt kept running into), **0363**
(`exit`'s missing `has_x` guard), **0365** (the same blind spot after `go_back`).

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

> **REFUTED 2026-08-09 by measurement.** "No known trigger" was wrong. Two ordinary, paste-free
> paths clear `modified` while the `~` lives on, and both are one menu click:
> `xschem reload` (File > Reload / the FileReload toolbar button / Alt-S,
> `scheduler.c:10450` → `load_schematic(reset_undo=1)` → `set_modify(0)`, **no**
> `remove_backup()`), and any in-place `xschem load` of the same or another cell
> (`scheduler.c:7292`), which is also what every scripted load, action-log replay and
> regression case does. See *Measured* below.

## Sketch

Include the current level in the backup scan (`0 .. currsch`), or check `xctx->sch[currsch]`'s
backup explicitly beside the `xctx->modified` test.

**The risk to weigh before doing it** is false positives: a stale `~` file left by a previous
crashed session would then make every Close/Quit prompt fire on an untouched document. That is
probably still the right trade (a spurious prompt is cheap; a deleted recovery file is not), but it
is a user-visible behaviour decision and wants its own measurement of how often stale backups
survive — `remove_backup()` is called on the paths that legitimately end a cell's life, so a
leftover `~` genuinely does mean "a session died with unsaved work".

> **REFUTED 2026-08-09 by measurement**, and this is the sentence that sank attempt 1. A leftover
> `~` does *not* mean a session died: `xschem reload`, an in-place load of another cell, and
> window/tab teardown after "ok, exit anyway" all leave one behind. The working tree carried **30
> such files** at measurement time, three of them beside *committed* fixtures and all newer than
> their cells (`tests/headless/fixture_0098_pre~.sch`, `fixture_0105_pre~.sch`,
> `tests/from_user/before_3~.sch`). The false-positive rate is not a tail risk to be traded away —
> it is the common case, and the "sketch" above (`0 .. currsch`, bare existence) makes every open
> of those fixtures warn. Filed as **0362**.

---

# Measured — 2026-08-09 (item D3, backlog run 2026-08-09)

Binary `src/xschem` built at 08-09 21:53 from sources at `ee290c5b`. All runs headless:
`./src/xschem --nogui --pipe -q --nolog --script <t>`. **Three independent reproductions, all
with content loss confirmed by wire counts on disk, all with ZERO `ask_save` prompts** (counted
with an instrumented `ask_save` stub).

## BEFORE transcript (verbatim)

```
=== repro A (top level, scratch_D3/repro_0264.tcl) ===
edit:    modified=1 hier_mod=1 cell~ wires=2 cell.sch wires=1
reload:  modified=0 hier_mod=0 cell~ wires=2 cell.sch wires=1
clear:   ask_save prompts=0  cell~ exists=0  cell.sch wires=1
RESULT: 0264 REPRODUCED (backup destroyed with 0 prompts)
=== repro B (scratch_D3/repro_0264b.tcl, same binary/flags) ===
--- CASE A: current cell's own ~ at a DESCENDED level (currsch=1) ---
A0 descend: currsch=1 modified=0 hier_mod=0
A1 edit child:  currsch=1 modified=1 hier_mod=1 child~ wires=4 child.sch wires=3
A2 reload:      currsch=1 modified=0 hier_mod=0 child~ wires=4 child.sch wires=3 parent~ exists=0
--- CASE B: load a DIFFERENT cell in place orphans the previous cell's ~ ---
B1 edit one:    modified=1 hier_mod=1 one~ wires=2 one.sch wires=1
B2 load two:    modified=0 hier_mod=0 one~ wires=2 one.sch wires=1 ask_save prompts=0
--- CASE C: what remove_backup() asks before unlinking ---
C1 reopen one:  modified=0 hier_mod=0 one~ wires=2 one.sch wires=1
C2 clear:       ask_save prompts=0 one~ exists=0 one.sch wires=1
=== the two source lines named by the issue (grep -n src/save.c) ===
3590:  if(xctx->modified) return 1;
3592:  for(i = 0; i < xctx->currsch; i++) {
=== stale ~ already newer than a committed fixture (blast-radius measurement) ===
tests/headless/fixture_0098_pre: cell=2026-07-25 23:07:04  backup=2026-08-09 16:38:49  backup_newer=yes
```

## The scope finding the original filing got wrong

The issue is titled after `hierarchy_modified()`, but **that predicate is not on the path that
deletes the file**. `hierarchy_modified()` has exactly 12 C readers — `xinit.c:2312/2404/2485/2545`
(all `&& has_x`) and the eight `xschem exit` lines in `scheduler.c` — plus the Tcl getter at
`scheduler.c:4458`. None of them ran in any of the three repros.

The destructor is `clear_schematic()` (`actions.c:3973/3980`):

```c
if(cancel == 1) cancel = save(1, 0);   /* save() only PROMPTS when xctx->modified */
if(cancel != -1) {
  remove_backup();                     /* ...but this unlinks unconditionally */
```

On a clean buffer `save(1,0)` asks nothing and `remove_backup()` still unlinks. **A fix confined
to `save.c:3592` changes which prompts fire and stops none of the three measured destructions.**
Any future attempt must fix the destructor, not only the predicate.

---

# Attempt 1 — written, tested, and REVERTED (2026-08-09/10)

Full diff preserved at `doc/claude/issues/0264-attempt-1-reverted.patch` (344 lines: `src/save.c`,
`src/actions.c`, a comment in `src/paste.c`, and 15 new test rows across
`tests/headless/test_backup_recovery.tcl` and `tests/headless/test_hier_close_prompt.tcl`).
**Nothing from it is in the tree** — `src/` and `tests/` are byte-identical to `ee290c5b`
(`git diff HEAD -- src/ tests/` is empty).

> **HAZARD for the next session.** The sources were reverted but **not rebuilt** (per this run's
> rule that only the implement agent may build). The binary left at `src/xschem`
> (`md5 7a13d4f41be68f3008bfd89ad1afb5fe`) still **contains attempt 1**, so any suite run before
> the next `make` measures code that is not in the tree — including a `hierarchy_modified()` that
> answers 1 for a blank canvas. The `.o` files are older than the reverted `.c` files, so a plain
> `make` self-heals; do that first.

Two changes, both at verbs; `set_modify()` was deliberately not touched.

1. **The destructor guard** — `clear_schematic()` latched `int had_unsaved = xctx->modified;` as
   its first statement, before `save(1,0)` could clear the flag, and the unconditional
   `remove_backup()` became `if(had_unsaved) remove_backup();`.
2. **The predicate** — two new C89 statics, `backup_exists()` (bare existence, the ANCESTOR rule,
   unchanged behaviour) and `backup_is_live()` (exists **and** (cell absent **or**
   `bak.st_mtime > cell.st_mtime`), the new CURRENT-level rule), with
   `if(backup_is_live(xctx->sch[xctx->currsch])) return 1;` added after the ancestor loop.

## AFTER transcript (the attempt worked, as far as it went)

```
test_backup_recovery.tcl   RESULT: 3 FAILED  ->  RESULT: ALL PASS (22 rows, rc=0)
test_hier_close_prompt.tcl RESULT: 2 FAILED  ->  RESULT: ALL PASS (21 rows, rc=0)
```

Every listed tier stayed at its baseline count (`shape_draw 421`, `paste_modify_0244 376`,
`add_wire_label 178`, `placement_wire_gate 171`, `label_ride 157`, `preview_doors 177`,
`strand_oracle 32`, `sch_add_pin 21`, `instance_update 95`, `wireedit ALL PASS`,
`run.sh 6 goldens HARNESS: PASS`, `run_regression` exactly the 3 known-red FAIL lines), verified
with the binary checksum pinned at `7a13d4f41be68f3008bfd89ad1afb5fe`.

The canonical repro was genuinely closed: `load(1 wire) → wire → reload → clear` left
`cell~.sch` on disk holding 2 wires, with 0 `ask_save` calls.

## Why it was reverted — the refutation

Adversary attack **A12/A2**, four ordinary commands, no synthetic timestamps:

```
draw a wire  ->  xschem saveas mydesign.sch  ->  xschem clear (File > New)
```

`saveas` renames `sch[currsch]` before `remove_backup()`, orphaning the `untitled~.sch` that
`write_backup()` wrote during the draw (pre-existing behaviour). The new blank buffer is
`untitled.sch`, which **never exists on disk** — so `backup_is_live()` took its

```c
if(stat(cellfile, &csb)) return 1;    /* backup but no cell: the ~ is all there is */
```

arm and the never-edited blank canvas reported `hierarchy_modified() == 1`, **permanently**.
Re-measured independently at write-up time in a clean directory, to rule out issue 0364's
cwd collision as the cause:

```
fresh:      modified=0 hier_mod=0 schname=.../a12b/untitled.sch
  cell exists=0  bak=.../a12b/untitled~.sch bak exists=0
after saveas+New: modified=0 hier_mod=1 schname=.../a12b/untitled.sch
  cell exists=0  bak=.../a12b/untitled~.sch bak exists=1
```

The warning is **factually false** — that `~`'s content is fully preserved in `mydesign.sch` —
and the user has no in-app way to clear it: `xschem backup remove` is bound to nothing but
`hierarchy_close`'s dirty-top-level branch, and change (1) specifically stops `clear` from
removing it. Downstream, under X the WM close button (`xschem.tcl:15173` →
`xinit.c:2312 destroy_window`, `hierarchy_modified() && has_x`) pops a false "UNSAVED data"
modal, and the unforced non-tabbed `xschem exit` (issue **0363**) becomes a **silent no-op** —
so an ordinary draw / Save-As / File>New session cannot quit by that path at all.

That contradicts the attempt's own central claim ("*without turning a never-edited cell dirty*")
and its non-goal row `0264 E`, which only ever checked a descended child that **has** a cell file.

**A second, pre-existing destruction also survived the attempt** (adversary A13i, never
previously measured as a composite): after a reload-discard leaves a live `~`, if another window
or an external tool moves the cell's mtime, `File > New` takes `save()`'s `force = 1` arm; on
"yes" `save_schematic()` writes the **clean** buffer over the cell *and* unlinks the `~` holding
the only copy — one line **above** the new guard, inside `clear_schematic()` itself. The user was
asked about the *file changing*, never about the backup. Filed under **0362**.

## Sabotage matrix (7 variants, all built and run against the attempt)

| # | mutation | predicted red | observed red | verdict |
|---|---|---|---|---|
| S1 | `backup_is_live() → 0` (pre-fix blindness) | 2 | 2 — `0264 A`, `0264 D` | exact |
| S2 | `backup_is_live() → 1` (blanket yes) | 8 | 5 — `clean top`, `clean hierarchy`, `0264 B/C/E` | **3 missing** |
| S3 | `had_unsaved = 1` (guard neutralized) | 3 | 3 — `R4b`, `R4c`, `R4d` | exact |
| S4 | `had_unsaved = 0` (guard over-applied) | 2 | 2 — `R2`, `R4e` | exact |
| S5 | `autosave_backup` early return neutralized | 1 | 1 — `0264 F` | exact |
| S6 | mtime comparison inverted (`>` → `<`) | 3 | 3 — `0264 A/C/D` | exact |
| S7 | `backup_exists() → 0` (ancestor scan off) | 1 | 1 — `DEEP CLOSE GUARD` | exact |

**Predicted reds that did not appear** — recorded because two of them are a standing
mis-belief about coverage, not a one-off:

- S2 did not redden `test_paste_modify_flag_0244.tcl`'s `0244 B: hier_mod clean before` (:273)
  or `0244 B: hier_mod back to 0` (:276). **Root cause measured:** that suite sets
  `set ::autosave_backup 0` at line 73, so `hierarchy_modified()` returns at its early guard and
  never reaches the backup scan at all. Those two rows guard the `xctx->modified` arm and
  contribute **zero** coverage of the `~` scan in either direction — confirmed twice (green under
  S2 *and* under S5, which removes the very guard they depend on). Do not cite them as watching
  a change to the scan.
- S2 did not redden `0264 F` — a mis-prediction, not a hole: the `autosave_backup` early return
  sits *above* the `backup_is_live()` call site, so no substitution of that callee can reach it.
  `0264 F` is owned exclusively by S5, where it reddened alone.

The matrix is trustworthy: every variant was caught, each by rows that name the mechanism it
broke, and the two halves of the fix were witnessed independently (S1/S6/S7 move only
`test_hier_close_prompt`, S3/S4 move only `test_backup_recovery`).

## Decisions, with ladder rung and rejected alternative

Recorded even though the code was backed out — the next attempt should not re-litigate them.

- **D1 [R1 — 0241: a teardown must name what it is tearing down]** Guard
  `clear_schematic()`'s `remove_backup()` with the *pre-save* modify flag.
  *Rejected:* fix only `hierarchy_modified()` (this issue's own sketch) — measured refutation:
  none of its 12 readers is on the path that deleted the file. **This half was never refuted and
  should be re-landed on its own** (see *Next attempt*).
- **D2 [R1/R2]** Widen `hierarchy_modified()` to include `xctx->sch[currsch]`.
  *Rejected:* ship D1 alone — leaves Close/Quit reporting "clean" for a cell whose only copy of
  the work is a live `~`, i.e. the filed defect verbatim. **This half is what was refuted.**
- **D3 [R2 — least surprising, smallest blast radius]** The current level's `~` counts only when
  newer than the cell (or the cell is absent), so "Close warns" ⟺ "reopen would offer recovery".
  *Rejected (a):* bare existence at the current level too — more false positives, disagrees with
  the recovery offer. *Rejected (b):* apply the mtime rule to ancestors as well — re-decides the
  B5/B6 descend contract with no measured need. **The "or the cell is absent" clause is the
  refuting bug**; the mtime clause itself held up under S6.
- **D4 [R2]** Do **not** add `remove_backup()` to `xschem reload` or in-place `load`, even though
  the written B8 contract demands it: on both paths that `~` is currently the only surviving copy
  of the edits, so restoring the purity converts an accidental-but-working recovery file into a
  hard delete. *Rejected (a):* delete there. *Rejected (b):* an in-memory "this buffer's `~` is
  discarded" flag — extra `xctx` state to reset on every load/save/window swap, and it
  desynchronizes the predicate from the recovery offer. Filed as **0362**.
- **D5 [R2, measured]** Do **not** touch `xschem exit`'s non-tabbed arm. Mirroring the tabbed arm
  (`!has_x ||`) makes an unforced headless non-tabbed exit proceed into `clear_schematic(0,0)`,
  which for a dirty buffer drops its `~` — trading a loud no-op for silent data loss. Filed as
  **0363**.
- **D6 [R2]** Do **not** make `clear_schematic()` / File>New prompt on `hierarchy_modified()`.
  A "Save changes?" prompt for content that is not in the buffer is a lie — saving would write the
  clean buffer over the work. *Rejected:* route clear's guard through `hierarchy_modified()` for
  symmetry with the teardown prompts.
- **D7 [R2]** Leave `save_schematic()`'s unconditional post-save `remove_backup()` alone. Same
  missing "whose work is this" question as D4, and `test_paste_modify_flag_0244`'s row-B fixture
  depends on its rename-then-remove **order**. Filed as **0362** — and A13i later showed this is
  the destruction the attempt failed to close.
- **D8 [R1 — 0356: a suite must not delete untracked files from the repo tree]** The 30
  pre-existing `*~.sch`/`*~.sym` in the working tree were not cleaned; new rows worked only under
  `/tmp`. Nothing was deleted from the tree at any point, including at revert.
- **D9 [R3 — user-visible, no prior ratification]** was the ledger question the attempt would have
  raised. It is now moot in the tree, but **its framing was itself incomplete**: it asked about "a
  previous session's crash file, or work the user discarded in THIS session", and the case that
  broke the fix (a blank canvas whose orphan `~` duplicates content already saved under another
  name) is neither.

## Still open

Nothing is fixed. In addition to the original defect, all of the following stand:

1. **The refuting bug is a property of the design, not a typo.** `backup_is_live()`'s
   no-cell-file arm has no legitimate positive trigger at the current level — an edited untitled
   buffer already returns 1 via `xctx->modified`. Narrowing it to "the cell file existed when the
   buffer was loaded", or dropping the arm outright, looks safe **and must be measured**, not
   assumed.
2. **A13i's destruction is still live and is not closed by the guard** (external mtime + "yes"
   → `save_schematic` overwrites the cell with the stale clean buffer and unlinks the `~`).
   Tracked in **0362**. Do not claim 0264 is closed while it stands.
3. **The predicate under-reports in the same-second case.** `st_mtime` is second-granular and the
   test is strict `>`; a cell written and edited within one second gives `hier_mod = 0` with the
   `~` holding the newer content. The canonical fast repro itself lands in that blind spot. Worse
   from the other side: `xschem_recover_backup` (`xschem.tcl:6606`, same granularity) then
   classifies that `~` as stale and **deletes it silently** on the next interactive open — so
   under attempt 1 the work the `clear` guard saved was merely lost later, in the GUI.
4. **The attempt's positive rows never exercised natural timing** — every one synthesized the gap
   with `file mtime $bak [+5]`, so they would have stayed green even if the natural repro never
   fired. A row that edits a cell whose file is ≥1 s old and asserts `hier_mod == 1` *without*
   touching mtimes is required next time.
5. **A third uncovered position:** after `go_back`, an ascended child's live `~` is neither
   current nor an ancestor and is invisible to any predicate. Filed as **0365**.
6. **0241 compliance is only partial.** The guarded call site named what it tears down, but
   `remove_backup()` itself still unlinks by filename with no identity check, and A13i shows that
   unnamed teardown still firing from `save_schematic()`. **0362** is the real fix.
7. **The three committed fixtures** (`fixture_0098_pre~.sch`, `fixture_0105_pre~.sch`,
   `tests/from_user/before_3~.sch`) still carry `~` files newer than their cells. Any predicate
   that keys on mtime alone warns on them, and under X that means a modal on window teardown.
8. **The X teardown prompts were never exercised** (`xinit.c:2312/2404/2485/2545`) — code-read
   plus a measured `hier_mod = 1` only. An xvfb suite that closes a window over one of those
   fixtures is the concrete hang risk.

## Next attempt — the shape that is already justified

Land **D1 alone** (the `had_unsaved` guard in `clear_schematic()`). It is ~3 lines, it was
refuted by nothing, it is witnessed by S3/S4 and by rows `R4b/R4c/R4d/R4e`, it stops all three
measured destructions, and it changes **no** predicate — so it raises no prompt anywhere and no
D9-class user-visible question. Its one measurable consequence is that a `~` now outlives a
File>New on a clean buffer, which is the intended behaviour and is invisible to `full_audit`'s
working-tree arm (`*~.sch`/`*~.sym` are gitignored, `.gitignore:55-56`).

Then treat the predicate (D2/D3) as a separate item that must first answer **0362** — because
every failure above, including the one that reverted this attempt, is the same missing question:
*whose work is this `~`?*
