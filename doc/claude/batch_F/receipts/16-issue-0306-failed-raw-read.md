# Receipt 16 — issue 0306: a failed raw read leaves a state the next operation crashes on

**Branch** `fluid-editing`. **Commit** `c6743aff`. **Nothing pushed.** Issue 0315 untouched.
**Task brief** `doc/claude/suggestions/next_task_0306_failed_raw_read_crashes.md`.
**Issue** `doc/claude/issues/0306-a-failed-raw-read-leaves-a-state-the-next-operation-crashes-on.md`.

Two independent, measured SIGSEGVs and a ~250 KB-per-attempt leak, all three of one shape: **a raw
read that fails leaves `xctx->raw` in a state the very next operation dereferences without
checking.** Part 1 left it non-NULL but half-built; part 2 left it NULL.

---

## 1. What was fixed

### `src/save.c`, `table_read()`'s `err:` label — the fix

```c
  if(xctx->raw) {
    dbg(0, "table_read(): discarding the partially built database\n");
    free_rawfile(&xctx->raw, 0, 1);
  }
```

The line `vcd_read()` has had at its `done:` label since it was written. `table_read()` probes with
a bare `open()` (which succeeds on a directory and on `/dev/null`) and reads with `my_fopen()`
(which rejects anything not `S_ISREG`), so for a non-regular path control reaches the `my_calloc` +
`int_hash_init`, then falls out of `if(fd)` into `err:` and returned 0 having freed nothing. **One
line kills both the crash and the leak, because the orphan is what both are made of.**

The `dbg()` is not decoration — it is the only externally visible trace that the orphan ever
existed (`xschem raw loaded` answers -1 either way, which is what makes the orphan invisible in the
first place), and it fires only when there is something to discard. It is what nine checks use to
prove the fixed line actually runs; see SAB-11.

### `src/save.c`, `extra_rawfile()` + `new_rawfile()` — six NULL-`rawfile` guards, defence in depth

The registry has **seven** places that `strcmp()` an entry's `rawfile`. One had no guard and was the
measured SIGSEGV (the non-spice dedup loop); two more (`what==3`'s by-name clear arms) had no guard
either and turned out to be **two further reachable crash doors the issue never named** — found by
this phase's sabotage battery, measured crashing on the pre-fix tree, and now covered by checks
C18/C19. Three (the spice dedup loop, the `what==2` switch loop, `new_rawfile()`) test `sim_type`
first and got away with it by luck. The `what==4` `raw info` append had no guard and a NULL there
silently mangles the listing. All seven now agree.

`new_rawfile()`'s loop is the sixth site and was **added this phase** on review finding A-3.

### `src/save.c`, `update_waves_menu_cue()` — new static helper, called after both restores

`free_rawfile()` repaints the Waves menubar cue grey unconditionally, so the new free at `err:`
greyed it on `extra_rawfile()`'s restore path *while a good database was still current*. Both
reviewers confirmed the mechanism independently. The helper re-asks `sch_waves_loaded()` **after**
`xctx->raw = save`, which is the only point where the question has the right answer (`raw_read()`
already asks, but before the restore, so its answer is about the failed read).

### `src/scheduler.c`, the `set raw_level` arm — part 2

```c
  if(xctx->raw && n >= 0 && n <= xctx->currsch) {
    xctx->raw->level = n;
```

The range check was on `n`; nothing tested whether there was a database to write into. Both shipped
callers (`open_sub_schematic`, `hi_descend`'s new-window arm) emit this on the line immediately
after `xschem raw_read`, without testing its result, and that arm clears the whole registry before
it reads. `-1` is already the arm's "did not take" answer, matching the getter, which has always
been guarded. `atoi(argv[3])` → `n` on the assignment line: same value, one parse.

### `tests/headless/full_audit.sh`

`test_raw_read_failure_0306` registered in `nogui_tests`.

---

## 2. The test — 63 checks, `tests/headless/test_raw_read_failure_0306.tcl`

Runs true-headless in ~1.3 s. Every crash-provoking sequence runs in a **child** `xschem`; the
parent never executes one, so a regression reads as FAIL with named ids instead of an opaque
`CRASH`. Child output goes to a file and every path from child stdout to a printed detail line
passes through a `scrub` that neutralises all six sentinels `full_audit.sh` greps for; the sentinels
are built at runtime so none appears literally in the file.

| band | ids | what it claims |
| --- | --- | --- |
| H1–H4 | 4 | harness self-test: exit codes, the fatal-signal detector, and the catch wrapper |
| C1–C9 | 9 | part 1, **no crash**: 4 spellings × directory/`/dev/null`, two-in-a-row, the vcd trigger, the spice control |
| C1r–C9r | 9 | part 1, **registry state**: the failed read left no orphan entry |
| C1f–C9f | 9 | part 1, **path entry**: the orphan really was built and really was discarded |
| C10–C14 | 5 | part 2, the issue's three repros + the `op` branch + a virgin context |
| C15/C16 | 2 | part 2 **end to end**, through `open_sub_schematic` and `hi_descend` |
| C17 | 1 | control: a nonexistent path allocates nothing, so discards nothing |
| C18/C19 (+r) | 4 | the two `raw clear <file>` doors found this phase |
| C20 | 1 | control: `raw new` after an orphan survived pre-fix too |
| S1–S11 | 19 | in-process state, safe before and after the fix |

`xschem raw info` is the orphan discriminator, never `xschem raw loaded` — the latter says -1 in
both states, which is the whole point of the issue.

---

## 3. Sabotage table — 14 mutations, all re-measured this phase

Anchors moved when the review findings were applied, so the entire battery was re-run rather than
patched. Every id is a measured red.

| id | mutation | reds |
| --- | --- | --- |
| SAB-1 | delete the whole discard+free block at `err:` | C1r–C9r C1f–C9f C18r C19r S1b S2–S5 (**25**); C1–C9, C18, C19 stay GREEN |
| SAB-1b | delete only the `free_rawfile()`, keep the discard `dbg()` | C1r–C9r C18r C19r S1b S2–S5 (**16**); the nine `C*f` stay GREEN |
| SAB-2 | revert the whole NULL-guard sweep, 7 sites | **NOTHING** — structural, see below |
| SAB-3 | SAB-1 + SAB-2 = the pre-fix tree | C1–C8 C1r–C8r C1f–C9f C18 C19 S1b S2–S5 (**32**) |
| SAB-4 | drop `xctx->raw &&` from `set raw_level` | C10–C16 (**7**), including both end-to-end ids |
| SAB-5 | make that arm always refuse | S9 (**1**) |
| SAB-6 | free on SUCCESS too | **34** ids **and kills the parent at S7b** |
| SAB-7 | drop the `raw info` NULL guard alone | **NOTHING** |
| SAB-8 | SAB-1 + SAB-7 | C1f–C9f C18r C19r S1b S2–S5 (**16**) — C1r–C9r go back GREEN |
| SAB-9 | `raw->level = n` → `n + 1` | S9b (**1**) |
| SAB-10 | widen the range check to `CADMAXHIER-1` | S10b (**1**), and not S10 |
| SAB-11 | make the two opens agree (the orphan is never created) | C1f–C9f (**9**) and nothing else |
| SAB-12 | drop the `new_rawfile()` guard alone | **NOTHING** |
| SAB-13 | delete both `update_waves_menu_cue()` calls | **NOTHING** |

**What the battery found.**

1. **The guards are falsifiable only in PAIRS, and both pairs are measured flips.**
   SAB-1 → SAB-3 flips **10** ids (C1–C8, and C18/C19 — the two doors this phase discovered);
   SAB-1 → SAB-8 flips **9** ids (C1r–C9r). SAB-2/SAB-7/SAB-12 red nothing on their own because
   with the free in place nothing reachable produces a NULL-`rawfile` *registry entry*.

2. **Three of the seven guard sites are unfalsifiable BY CONSTRUCTION, not by omission.** The spice
   dedup loop, the `what==2` switch loop and `new_rawfile()` all test `sim_type` before `rawfile`,
   and an orphan's `sim_type` is NULL too, so their `strcmp` is never reached. Control **C20**
   measures that for `new_rawfile()` — the one of the three that also owns an adopt block, i.e. the
   one where "unreachable" is least obvious. That is the honest reason those three are guarded
   anyway, and it is now written down instead of inferred.

3. **SAB-11 is the answer to "can this test tell 'freed' from 'never created'?"** It applies the
   issue's own alternative fix (probe with `my_fopen()`), which makes the orphan impossible — and
   reds exactly the nine `C*f` ids and nothing else. Without them, that change would have passed
   with the `free_rawfile()` deleted.

4. **SAB-6 kills the parent** at S7b, on a NULL *entry pointer* (`extra_raw_arr[i]` itself), not a
   NULL `rawfile` — a different mechanism, and the one mutation the child-harness design does not
   contain. Recorded, not patched: a NULL entry needs a reader that returns success having produced
   nothing, which none does, so guarding it would be a fourth unfalsifiable guard.

5. **SAB-13 reds nothing** — an honest hole. `has_x` is 0 under `--nogui`, so no check in this file
   can see the Waves menubar cue. See §6.

---

## 4. Leak — matched pair on this tree

| | definitely lost |
| --- | --- |
| free deleted (pre-fix), 10 failed reads | **2,278,504 bytes** (1,360 direct + 2,277,144 indirect) in 10 blocks |
| as shipped | **0 bytes in 0 blocks** |

Reproduces the issue's own figure exactly. Valgrind stays out of the suite (120 s per-test budget).

---

## 5. Review findings and their triage

Two adversarial reviewers, neither the implementer: **A** (C memory-safety / lifetime), **B**
(evidence quality). Ten findings; **seven fixed, two filed as new issues, one refuted by
measurement.**

### A-1 — `read_dataset()`'s four malformed-header aborts leak the same ~250 KB. **CONFIRMED, FILED as issue 0316, not fixed.**
Verified by reading and then **measured**: `253,152 bytes (136 direct + 253,016 indirect)
definitely lost` for one malformed-header read with a database already registered — and the good
database is destroyed with it (`raw info` empty, `raw loaded` -1 afterwards). Exactly 0306's shape,
in a third function. The brief's scope rule is explicit — *"If, while fixing, you find a third
instance of the same shape, file it as a new issue and fix it only if it is in the same two
functions"* — and `read_dataset()` is neither `table_read()` nor `extra_rawfile()`. Filed as
`doc/claude/issues/0316-read_dataset-malformed-header-aborts-leak-the-half-built-raw.md` with the
measurement, the reachability (higher than 0306's: a truncated raw file, not a typed path), and the
note that the reviewer's proposed one-liner does **not** work — `extra_rawfile(3, ...)` has already
NULLed `*rawptr` by then, so the fix must hold the pointer itself.
**The false premise it falsifies was corrected**: the test header's "`raw_read()` frees on failure"
is true only of its fall-through path, and the header now says so, with the note that the narrower
claim those sabotage rows actually make (no reachable producer of a NULL-`rawfile` *registry*
entry) survives, because the leaked `Raw` is never registered.

### A-2 — false evidence citation in the `err:` comment. **CONFIRMED, FIXED.**
The comment claimed the placement was pinned by "check S7, sabotage SAB-6". Both citations were
wrong: S7/S7b go through `extra_rawfile()`, which sets `xctx->raw = NULL` before calling the reader,
so they never reach the entry guard; SAB-6 mutates the success path. Verified that **all four**
`read_rawfile_by_type()` call sites NULL `xctx->raw` first (`save.c` ×2 directly, `scheduler.c` ×3
via `extra_rawfile(3, ...)`), so the entry guard is unreachable from every shipped caller. The
comment now says plainly that the placement is a statement about what the guard *means*, is
forward-looking and currently unexercised, and that SAB-6 is a different over-free.

### A-3 — the sweep missed the sixth lookup loop, `new_rawfile()`. **CONFIRMED, FIXED (guarded).**
It is verbatim the construct the neighbouring comment condemns, and it is reachable through the same
adopt block. Guarded, and the reason it could never have crashed (the `sim_type` short-circuit) is
now measured by control C20 rather than asserted.

### A-4 / B-3 — the new free greys the Waves menu while a live database is current. **CONFIRMED, FIXED.**
Both reviewers reached it independently; the mechanism is deterministic. Fixed at the restore point
in `extra_rawfile()` rather than at `free_rawfile()`, which also covers the identical pre-existing
wart in `vcd_read()` and `raw_read()`. See §6 for what is still not claimed.

### A-5 — the fifo hang has no timeout and is now the sole surviving consequence. **CONFIRMED, FILED as issue 0317.**
`open(fifo, O_RDONLY)` blocks forever before `my_fopen()`'s `S_ISREG` rejection is consulted; the
editor is single-threaded, so the whole application freezes. Not fixed here for the reason SAB-11
now measures: making the two opens agree renders 0306's own fix unfalsifiable. 0317 records that
coupling explicitly and tells whoever takes it to expect the nine `C*f` ids to red and why.

### B-1 — "two sabotage rows contradict the code; the headline conclusion rests on one of them". **REFUTED BY MEASUREMENT.**
The reviewer traced SAB-8 as making C1r–C9r **red** (predicting `Z_INFO="1 current | 0 "`, with the
good file's name absent), and SAB-3 as reddening C9r, giving 22 ids not 21. Re-measured directly:
**SAB-8 reds C1f–C9f, C18r, C19r, S1b, S2–S5 — the C1r–C9r ids are GREEN**, and **SAB-3 reds 32 ids
with C9r green**. The reviewer's trace assumes a NULL in `Tcl_AppendResult`'s vararg list ends the
*loop*; it ends that one **call**. The following iterations still print, so the orphan's line merely
loses its newline and merges with the next entry's — the segment count is 2 again and the good
file's name is still in the string. The implementer's original conclusion stands; the wording
"truncates the listing" was loose and has been replaced with the exact mechanism, and the
`raw info` guard is kept for the measured reason (it is what keeps nine checks able to see what
they test for).

### B-2 — the C band cannot distinguish "the orphan was freed" from "the orphan was never created". **CONFIRMED, FIXED.**
The strongest finding of the two reviews. Fixed as the reviewer suggested in substance but not in
form: rather than switching the free to `no_warning=0` (whose "clearing data" message is imprecise —
there was no data), `table_read()` now emits its own `dbg(0)` naming what it is discarding, only
when there is something to discard. Nine new `C*f` ids assert it, control **C17** asserts its
absence on the nonexistent path (so "the line is printed unconditionally" is excluded), and
**SAB-11 is the reviewer's own scenario turned into a mutation**: apply the `S_ISREG` probe fix and
exactly those nine ids red, nothing else. The coupling the reviewer said was unrecorded is now
recorded in the test header, in SAB-11, and in issue 0317.

### B-4 — 19 children × `timeout 60` inside `AUDIT_TIMEOUT=120`. **CONFIRMED, FIXED.**
Real: an uncaught Tcl error in a `--pipe --script` child drops it into the stdin loop, where it
idles rather than exits, and two idlers would have scored this row TIMEOUT — the opaque outcome the
child design exists to prevent. Fixed at the cause as well as the symptom: `run_child` now wraps
every body in a `catch` that turns any error into a prompt `exit 9` with the message captured as
`Z_ERR`, and the per-child bound is **10 s** (~50× the ~0.2 s a child takes). New check **H4**
proves the wrapper fires.

### B-5 — sabotage coverage gaps (S9b, S10, S7*, S8, S1, S11). **CONFIRMED, FIXED.**
`SAB-9` now covers the `atoi(argv[3])` → `n` edit (S9b is the only id that can see it — S9 cannot,
both spellings return the same number). `SAB-10` covers the range check; it required a **new check
S10b** using the *adjacent* out-of-range level, because the obvious mutation admitting 99 walks off
`xctx->sch[CADMAXHIER]` and a sabotage whose observable is undefined behaviour measures nothing.
`SAB-6`'s red list is now enumerated (34 ids) instead of counted, which covers S7*, S8. S1 is
relabelled `SMOKE` and S11 `CONTROL`, with the reason for S1 stated in-line.

### B-6 — the forgery trap is narrower than its description. **CONFIRMED, FIXED.**
`zval` now scrubs, so every path from child stdout to a printed detail line is covered, not just
`ctail`. The sixth sentinel `is_skip` greps for (`SKIP: no X connection`) was missing from the map
and is added. The header now states the invariant it actually holds, plus the reason scrubbing
cannot mask a real mismatch (every expected value is a literal containing no sentinel).

---

## 6. Audit

`GUI_GATE=1 DISPLAY=:0 bash tests/headless/full_audit.sh`, diffed by **test name and status**
against `doc/claude/batch_F/baseline_status.txt` (baseline `7a592f9c`, 2026-08-09).

Run: `SUMMARY: 287 pass  23 fail  1 crash/timeout  1 skip  (total 312)` /
`WIREEDIT: PASS` / `SCRATCH: 0 leaked dir(s)`. (The baseline lists the 58
wireedit cases as individual rows; this run reports them as one block, all
`ALL PASS`, so they are absent from the by-name join and are not a diff.)

**RED-WARD — four rows, all four re-run standalone, none a regression.**

| test | baseline | this run | standalone re-run | verdict |
| --- | --- | --- | --- | --- |
| `test_cadence_stretch_move` | PASS | SKIP | **PASS** | batched-sweep flake |
| `test_wave_sigbrowser_i1315` | PASS | FAIL | **PASS (191 checks)** | the named `BP72` flake class |
| `test_ase_plot` | TIMEOUT | FAIL | **PASS (150 checks)** | the named P4/P6/P8 gesture flake class; baseline was TIMEOUT, so not red-ward on the merits either |
| `test_altf5_ciw` | PASS | FAIL | FAIL — **and FAILS IDENTICALLY WITH THIS CHANGE STASHED** | pre-existing, not mine |

`test_altf5_ciw` is the only one that reproduced, so it got the stash test: with
`src/save.c` and `src/scheduler.c` reverted to `c80c514d` and rebuilt, it fails
twice more — and on a *different* check each time (`Alt-F5 raises/opens the CIW`,
then `rebound Alt-F5 raises CIW again`), which is the signature of the WSLg
raise flake, not of a deterministic break. Nothing in this change touches key
dispatch, window raising or the CIW.

**GREEN-WARD — seven rows, none of them mine either** (`test_ase_persist`,
`test_fluid_bodyshove_guards_0132`, `test_rotate_stretch_dangling_0103`,
`test_wave_axis_zoom`, `test_wave_crossdb_trace`, `test_wave_sigbrowser_i12`,
`test_wire_vertex_grab` — all FAIL/SKIP → PASS). These are the same flake
classes settling the other way, plus work landed between the baseline and now.
Recorded, not claimed.

**NEW ROWS — six** tests exist now that the baseline predates:
`test_raw_read_failure_0306` **PASS** (this change), plus
`test_backannotate_digital`, `test_cosim_golden_e2e`, `test_wave_cursor_crossdb`,
`test_wave_sigbrowser_0312`, `test_wave_sigbrowser_digital`, all PASS.

**`test_placement_wire_gate`** was TIMEOUT in the baseline and is TIMEOUT here —
unchanged, and the run's only crash/timeout.

An `X connection to :0 broken` line closes the log. It lands *after* all 312 rows
and the summary block, during the failing-test output replay, and
`wslg_health.sh` says `HEALTHY` afterwards — the known Xwayland abort, with no
scored row behind it.

---

## 7. What this does NOT claim

* **Not claimed: the fifo hang is fixed.** It is not, deliberately, and it is filed as issue 0317.
  A `rawfile=` graph attribute naming a fifo still freezes the editor with no signal.
* **Not claimed: `read_dataset()` is fixed.** It is not, deliberately, and it is filed as issue
  0316 with its measurement. A malformed raw file still leaks 253,152 bytes and still destroys the
  loaded database. That is a **more reachable** defect than the one fixed here.
* **Not claimed: the Waves menubar cue is verified.** The fix is correct by construction and the
  state it derives from is asserted headless (S7d), but `has_x` is 0 under `--nogui`, SAB-13 reds
  nothing, and **no check in any suite exercises a failed table read with `has_x`**. It wants an
  eyeball: load a spice raw so the Waves menu goes Green, then fail a `xschem raw table_read` on a
  directory, and confirm the menu is still Green.
* **Not claimed: `graph_fill_listbox` is exercised.** `src/xschem.tcl`'s line handing `table_read()`
  an unvalidated `rawfile=` attribute — the one shipped route with no typing in it — needs the
  `.graphdialog` widget tree and is not driven by any check. It remains a code-path argument, as the
  issue itself says.
* **Not claimed: the leak is asserted by the suite.** On the restore path the orphan is invisible to
  every Tcl probe. It is measured out of band with valgrind (§4) and nowhere else.
* **Not claimed: SAB-6's NULL-entry crash is guarded.** It is reachable only from a reader that
  returns success having produced nothing. Recorded, not patched.
* **Not claimed: the entry-guard placement is measured.** No shipped caller can reach
  `table_read()`'s entry guard; the argument for putting the free at `err:` and not there is
  reasoning, and the comment now says so.
* **Not claimed: three of the seven NULL guards do anything today.** The spice dedup loop, the
  `what==2` loop and `new_rawfile()` short-circuit on `sim_type` first. They are defence in depth
  against a future reader with the same slip, and C20 measures that they were never reachable.
