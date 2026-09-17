# 0060-comment — `write_backup()`'s header comment said the opposite of what it does; fixed (comment-only)

**Status:** DONE

H1 was **right**. The header comment of `write_backup()` claimed untitled buffers are
skipped; the code deliberately backs them up. I also found a **second live copy** of the
same false claim in `src/actions.c`, which H1 did not report.

## Files touched

| File | Lines | What |
|---|---|---|
| `src/save.c` | 6137-6138 (2 lines replaced by 2) | `write_backup()` header comment — the false "Skipped … (untitled)" clause |
| `src/actions.c` | 203-205 (3 lines replaced by 3) | `set_modify()`'s autosave comment — same false clause, **newly found** |
| `doc/claude/issues/0060-*.md` | status/affects + new section 5 | recorded the finding, de-rotted the line numbers |
| `doc/claude/harness_concurrency_batch/receipts/0060-comment.md` | new | this receipt |

**Line counts were preserved deliberately**, in both files, so that live citations elsewhere
do not rot:

* `src/save.c`'s header stays **6 lines** (6133-6138) → `write_backup()` stays at **6139** and
  the body note stays at **6149-6152**, which is what issue **1480** cites.
* `src/actions.c`'s comment stays **7 lines** (201-207) → the `write_backup()` call stays at
  **208**, which is what `src/ase.tcl:16188` cites as "actions.c:206-208".

## Rows added/changed

**None, and deliberately none.** This is a comment-only change: there is no behaviour to
red-first. No suite was run and no suite row was added — two other crews are live and
CREW_BRIEF rule 4 forbids it. The behaviour the corrected comment now describes is *already*
asserted by an existing row, `tests/headless/test_backup_file.tcl:70`
`ck "untitled buffer IS backed up (issue 0060)" [file exists $ubak]`, which I read but did
not run. **Nothing I touched can change its verdict** — see the diff below.

## Commands run

All read-only except the two edits. No suite, no `./src/xschem`, no `make`, no `run_suites.sh`,
no `run_regression.tcl`. Every command returned immediately; none needed a timeout.

```sh
cat doc/claude/issues/0060-descend-from-untitled-loses-parent-content-on-ascend.md
/usr/bin/grep -n 'write_backup' src/*.c src/*.h src/*.tcl
/usr/bin/grep -n 'doc/claude' src/save.c | head -30
/usr/bin/grep -n 'untitled' src/save.c
git blame -L 6130,6165 src/save.c
git blame -L 200,210 src/actions.c
sed -n '6480,6510p' src/save.c        # clear_schematic / load_schematic untitled namer
sed -n '6575,6605p' src/actions.c     # `xschem clear` untitled namer
sed -n '170,196p' src/xinit.c         # get_unused_untitled_name
sed -n '2705,2725p' src/scheduler.c   # `xschem backup write|remove|name`
sed -n '28,80p' .gitignore
sed -n '55,75p' tests/headless/test_backup_file.tcl
sed -n '20,50p' doc/claude/specs/descend_hierarchy_in_memory.md
sed -n '60,110p' doc/claude/issues/1480-*.md    # READ ONLY (do-not-touch list)
/usr/bin/grep -rn -i 'untitled' src/*.c src/*.h src/*.tcl | /usr/bin/grep -i 'skip\|no-op\|not.*back\|never.*back'
git diff -U0 src/save.c ; git diff -U0 src/actions.c ; git status --porcelain
```

## Measurements

| Measurement | Value | Command |
|---|---|---|
| Stale header comment | `src/save.c:6137-6138` | `sed -n '6133,6138p' src/save.c` |
| Its blame | `c408fe3ec` Ananth Ch **2026-06-21** | `git blame -L 6130,6165 src/save.c` |
| Corrective body comment | `src/save.c:6149-6152` | same |
| Its blame | `6cc6c6950` Ananth Ch **2026-07-02** | same |
| Second stale copy | `src/actions.c:203-205` | `git blame -L 200,210 src/actions.c` |
| Its blame | `a9ca3cfdb` Ananth Ch **2026-06-21** | same |
| **False** "untitled is skipped" claims in `src/` **before** | **2** — `save.c:6138`, `actions.c:204` | the `grep -i 'skip\|no-op\|not.*back\|never.*back'` sweep above |
| **False** claims **after** | **0** | same sweep re-run — ⚠ but it still prints **2 lines**, and both are *true in sense*: `save.c:6137` (the new *"NOT skipped for an untitled buffer"*) and the pre-existing corrective note `save.c:6151` (*"Skipping untitled here lost the whole top level…"*). **The sweep matches the word, not the polarity.** Read the two hits; do not count them |

⚠ **That second row is written out in full on purpose.** My first draft of this receipt recorded it as
a bare "**0**, same sweep re-run" — which would have left a future reader running the quoted command,
seeing 2 hits, and concluding the fix had not landed. A grep for `skip` cannot distinguish "untitled is
skipped" from "untitled is NOT skipped"; only reading the lines can. This is the batch's own dominant
finding (thirteen wrong recorded beliefs, all caught by re-measuring) reproduced in miniature inside the
receipt that reports it.
| Gates actually in `write_backup()` | **4**, none of them an untitled test | `sed -n '6139,6161p' src/save.c` |
| `untitled~.sch` visible to `git status` | **No** — `.gitignore:74-75` is `*~.sch` / `*~.sym` | `sed -n '74,76p' .gitignore` |
| Lines changed | save.c 2, actions.c 3 | `git diff --stat` |
| `//` comments introduced | **0** (C89 clean) | `git diff -U0 … \| /usr/bin/grep '^+' \| /usr/bin/grep -c '//'` |

The 2026-06-21 → 2026-07-02 blame gap **is the whole mechanism**: the 0060 fix updated the
comment at the point of the deleted `stat()` gate and left both *surrounding* comments —
one six lines above it in the same function, one in the calling file — asserting the
behaviour that had just been removed.

## What the code actually does

```c
/* src/save.c:6139-6153 */
void write_backup(void)
{
  ...
  if(xctx->no_autosave) return;                 /* :6145 during load */
  if(!tclgetboolvar("autosave_backup")) return; /* :6146 flag off    */
  name = xctx->sch[xctx->currsch];              /* :6147            */
  if(!name || !name[0]) return;                 /* :6148 EMPTY name -- not "untitled" */
  /* :6149-6152  "Back up even when 'name' has no on-disk file yet (an untitled buffer)" */
  if(!backup_file_name(bak, S(bak), name)) return;   /* :6153 no .sch/.sym extension */
```

Four gates, **not one of which tests for untitled**. There is no `stat()` — 0060 deleted it.

* **Path**: `write_backup()` never reads `pwd_dir` itself; it takes `xctx->sch[xctx->currsch]`
  and inserts `~` before the extension (`backup_file_name`, `save.c:6127-6129`). That buffer
  path is composed against `pwd_dir` at `actions.c:6594` (`xschem clear`) and against
  `xctx->current_dirname` — `$PWD`, else `pwd_dir` — at `save.c:6491-6503` (`load_schematic`
  with no file). So the `~` lands wherever the untitled *name* was composed, which under
  `full_audit.sh` is the repo root.
* **Filename**: `get_unused_untitled_name` (`xinit.c:189`) builds `untitled.sch`
  (`untitled-<n>.sch` if taken), so the backup is literally **`untitled~.sch`** — the name
  `tests/headless/test_backup_file.tcl:71` deletes by hand with the comment
  *"don't leave untitled~.sch in the run cwd"*.

## The diff (every changed line is inside a `/* */` block)

```diff
diff --git a/src/save.c b/src/save.c
@@ -6137,2 +6137,2 @@ int backup_file_name(char *dest, int destsize, const char *src)
- * Skipped when autosave_backup is off or the buffer has no real on-disk file yet
- * (untitled): there is nothing to back a "~" file against. */
+ * NOT skipped for an untitled buffer -- it is a PRODUCER of <dir>/untitled~.sch (issue 0060,
+ * gate note below). Skipped only when autosave_backup is off, during load, or on an empty name. */

diff --git a/src/actions.c b/src/actions.c
@@ -203,3 +203,3 @@ int set_modify(int mod)
-   * crash. write_backup() is itself a no-op during load (xctx->no_autosave), when
-   * autosave_backup is off, or for an untitled buffer. Highlight/select/pan/zoom and
-   * net-resolution never call set_modify(1), so they correctly do not write.
+   * crash. write_backup() no-ops during load (xctx->no_autosave), when autosave_backup is off,
+   * or on an empty buffer name -- but an untitled buffer IS backed up (issue 0060, save.c).
+   * Highlight/select/pan/zoom and net-resolution never call set_modify(1), so they do not write.
```

Zero behaviour change: no statement, declaration, expression or preprocessor line is touched,
so the compiled output is identical. This is why it was safe to do with suites running.

## Claims checked vs taken on trust

Everything below was **checked**. Nothing was taken on trust.

| # | Claim (H1 / the task) | Verdict | Line actually read |
|---|---|---|---|
| 1 | `save.c:6137-6138` is `write_backup()`'s header comment | **CONFIRMED, exact** | header block is 6133-6138; the false clause is exactly 6137-6138 |
| 2 | …and it says untitled buffers are **skipped** | **CONFIRMED** | `:6137` *"Skipped when autosave_backup is off or the buffer has no real on-disk file yet"* `:6138` *"(untitled): there is nothing to back a \"~\" file against."* |
| 3 | `save.c:6149-6152` does the deliberate opposite | **CONFIRMED, exact** | `:6149` *"Back up even when 'name' has no on-disk file yet (an untitled buffer)"* |
| 4 | "H1's numbers may have rotted" (task's caution) | **REFUTED** | both citations are byte-exact on today's tree; no rot. The rotted numbers were in the **0060 issue file**, not H1's report |
| 5 | Untitled buffers ARE backed up | **CONFIRMED** | four gates at `:6145-6153`, none tests untitled; no `stat()` remains |
| 6 | "a buffer with **no filename** (an 'untitled' one)" | **CORRECTED** | conflates two distinct cases. `:6148` `if(!name \|\| !name[0]) return;` really **does** skip an **empty-named** buffer. An untitled buffer is **not** nameless — it carries a full path `<dir>/untitled.sch`. The corrected comments preserve this distinction; a naive "untitled is never skipped" rewrite would have introduced a *new* falsehood |
| 7 | The file lands in `pwd_dir` | **CONFIRMED w/ refinement** | `write_backup()` never reads `pwd_dir`; the path comes from `xctx->sch[currsch]`, composed against `pwd_dir` (`actions.c:6594`) or `$PWD`/`pwd_dir` (`save.c:6491-6503`) |
| 8 | The filename is literally `untitled~.sch` | **CONFIRMED** | `xinit.c:189` `"untitled.%s"` + `save.c:6127-6129` `dest[stem]='~'`; named verbatim at `test_backup_file.tcl:71` |
| 9 | Issue 0060 is about this comment | **REFUTED** | 0060 is a **behaviour** issue, **FIXED 2026-07-02** — it is the change that *caused* the divergence, not a report of it. It prescribes nothing outstanding |
| 10 | (H1 did not claim) a second copy exists | **NEW FINDING** | `actions.c:203-205`, blame `a9ca3cfdb` 2026-06-21, same pre-fix vintage |

## Corrections to PLAN.md / for the next crew

1. **The task framed this as one comment; it was two.** `src/actions.c:204` carried the
   identical falsehood and is arguably the *more* dangerous of the pair: it sits at the call
   site, inside `set_modify()`, which is where a reader asking "what writes these `~` files?"
   actually lands. I fixed it under the same comment-only, zero-behaviour-change constraint.
   **This is a deliberate scope extension** — flagging it here rather than letting the driver
   discover it in an audit.
2. **A third residue exists and I deliberately did NOT touch it.**
   `doc/claude/specs/descend_hierarchy_in_memory.md:32-33` says *"skip buffers with no real
   on-disk name (untitled / headless tests)"* — but it sits inside a `>` blockquote of the
   **original design plan**, i.e. a historical record of what was proposed before 0060
   changed it. Editing history to match the present would be a different kind of error. My
   recommendation: leave it. If the driver disagrees, it is a one-line annotation.
3. **Issue 1480 already records this exact finding** (`1480:78-93`, *"write_backup()'s own
   header comment says the opposite of what it does"*). 1480 is on my do-not-touch list, so I
   read it only. **Its `:6149-6152` citation still resolves** — I preserved the line count for
   that reason. Its `:6137-6138` quotation is now historical and its owner should mark the
   header fixed. **The driver should tell 1480's crew**, or they will re-file a fixed defect —
   which in this file's own words has already happened five times (0353, 0356, 0609, 0673, 0687).
4. **`.gitignore:74-75` ignores `*~.sch` / `*~.sym`.** So an `untitled~.sch` dropped in the
   repo root is **invisible to `git status`**, and therefore to any leak detector that trusts
   it. That is directly relevant to 1480's `tree_delta_snapshot()` analysis — the comment was
   one blindness, the ignore rule is a second, and they stack.

## Left dirty

Mine, uncommitted, for the driver:

* `src/save.c` — 2 comment lines (6137-6138)
* `src/actions.c` — 3 comment lines (203-205)
* `doc/claude/issues/0060-descend-from-untitled-loses-parent-content-on-ascend.md` — updated
* `doc/claude/harness_concurrency_batch/receipts/0060-comment.md` — this receipt

**Not mine.** `doc/claude/harness_concurrency_batch/DECISIONS.md` (modified) and
`receipts/R1-recon.md` (untracked) were dirty when I arrived and had been **committed by another crew
by the time I finished** — they no longer appear in `git status`. I touched neither. Pre-existing
untracked, also untouched: `.xschem/`, `doc/claude/rdw_lists_batch/`, `doc/claude/rdw_sim_batch/`,
`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/`.

Verified untouched (the do-not-touch list), by `git status --porcelain -- <f>`:
`tests/headless/test_ase_core.tcl`, `tests/headless/test_startup_guard_0663.tcl`,
`tests/headless/scratch.tcl`, `tests/run_regression.tcl`, `doc/claude/issues/0609-*.md`,
`doc/claude/issues/1480-*.md` — **all clean.**

Not committed — the driver holds the git identity.

## Owed to the user

**Nothing filed** — a crew must not touch `owed.sh` (CREW_BRIEF rule 8), and nothing here
needs the user's eyes: a comment correction has no pixels and no unratified user-visible
behaviour. The one judgement call I made unilaterally is item 2 above (leaving the spec's
historical blockquote alone); if the driver wants that ratified it is theirs to file, not mine.
