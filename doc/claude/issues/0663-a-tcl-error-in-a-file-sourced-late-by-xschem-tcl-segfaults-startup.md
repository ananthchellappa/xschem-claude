# 0663 — a Tcl error in any file sourced late by `xschem.tcl` SEGFAULTS startup

Status: **FIXED AS A CLASS, IN C, 2026-08-24 — status E** (the design question it
answers is user-visible and unratified; `owed.sh` carries the `rule` debt).
Filed by: the 0658 crew, 2026-08-24. Fixed by: the 0663 crew, 2026-08-24.

Fix: `src/xinit.c` — four C89 statics plus **one changed line** at the single
`source_tcl_file()` call for `xschem.tcl`. `src/xschem.tcl` is **not touched**.
Tests: `tests/headless/test_startup_guard_0663.tcl` (SG0–SG21).

---

## 1. Measured BEFORE — verbatim from the Measure agent, at HEAD `ac30edf0`

Method: a throw-away `XSCHEM_SHAREDIR` symlink farm over `src/` with exactly one
entry replaced or removed (`XSCHEM_SHAREDIR` is priority 1 in the share-dir
search, `src/xinit.c:2985`); the child launched as
`--nogui --pipe -q --logdir D --script inner.tcl` (nogui leg) and
`GUI_GATE=0 DISPLAY=:99 --pipe -q --logdir D --script inner.tcl` (GUI leg, on the
persistent dev display: `wm: openbox (Openbox)`, 1920x1080x24). `inner.tcl`
prints `R0663-ALIVE`, so `ALIVE=0` means the script never ran.

```
### R6_clean                  [nogui] EXIT=0    ALIVE=1  LOGLINES=3
### R1_opannot_err            [nogui] EXIT=139  ALIVE=0  LOGLINES=3
### R1b_opannot_enderr        [nogui] EXIT=139  ALIVE=0  LOGLINES=3
### R3_opannot_absent         [nogui] EXIT=139  ALIVE=0  LOGLINES=3
### R2_early_actionregistry   [nogui] EXIT=139  ALIVE=0  LOGLINES=3
### R2_late_alt2toggle        [nogui] EXIT=139  ALIVE=0  LOGLINES=3
### NEG_ciw_guarded           [nogui] EXIT=0    ALIVE=1  LOGLINES=4
### R7g_clean                 [gui]   EXIT=0    ALIVE=1  LOGLINES=3
### R7g_opannot_err           [gui]   EXIT=139  ALIVE=0  LOGLINES=3
### R7g_opannot_absent        [gui]   EXIT=139  ALIVE=0  LOGLINES=3
### R7g_early                 [gui]   EXIT=139  ALIVE=0  LOGLINES=3
### R7g_late                  [gui]   EXIT=139  ALIVE=0  LOGLINES=3
### R7g_ciw                   [gui]   EXIT=0    ALIVE=1  LOGLINES=4
```

and on stderr, for the `error {boom}` shape — note that **nothing names
`op_annot.tcl`**:

```
Tcl_AppInit() error: can not execute .../f_anon/xschem.tcl, please fix:
boom
Line No: 14796
can't read "cairo_font_line_spacing": no such variable
      ... eight more ...
can't read "cairo_font_scale": no such variable
```

The crash frame, `gdb -batch`, reproduced independently by the Measure agent:

```
Program received signal SIGSEGV, Segmentation fault.
#0  __strcmp_avx2 () at ../sysdeps/x86_64/multiarch/strcmp-avx2.S:283
#1  0x000055555560d738 in alloc_xschem_data ()
#2  0x000055555561622f in Tcl_AppInit ()
#3  0x00007ffff7ae8eea in Tcl_MainEx () from /lib/x86_64-linux-gnu/libtcl8.6.so
#4  0x000055555555e658 in main ()
```

**`LOGLINES=3` on every crashing row is the header only.** At HEAD the durable
log received **no announcement at all**, and the `error {...}` shape named the
failing helper **nowhere** — `Line No: 14796` indexes the `xschem.tcl` source
line but does not name the file. The ABSENT shape named it only by accident,
because Tcl's own message is `couldn't read file ".../op_annot.tcl"`.

## 2. Mechanism

`src/xschem.tcl` sources **fifteen** helpers with a bare `source`
(`:14568` `action_registry` … `:14815` `alt2_toggle_view`) plus **one** guarded by
issue 0658 (`:14854` `ciw.tcl`) — the "sixteen". It also makes bare top-level
CALLS into helper namespaces (`:14569` `load_action_table`, `:16873`
`wviewer::rawhist_load`). A Tcl error anywhere in that file propagates OUT of
`xschem.tcl`, so the rest of it never runs. `source_tcl_file()`
(`src/xinit.c:1513`) prints the error and returns `TCL_ERROR`; `Tcl_AppInit`
**discarded that return** and walked on into
`tclgetdoublevar("cairo_font_line_spacing")` and nine siblings against variables
nobody set, then into `alloc_xschem_data()`, whose
`strcmp(tclgetvar("undo_type"), "disk")` (`src/xinit.c:658`) was handed a NULL.

Why **139** and not `sig_handler`'s own `exit(1)`: the handler (`src/main.c:32`)
immediately reads `xctx->undo_type` (0 from `calloc`, i.e. the on-disk branch)
and `get_cell(xctx->sch[xctx->currsch], 0)` where `sch[0]` is still NULL. It
faults **again**, and the default action produces 139/core. That second fault is
why the exit code is 139 rather than the handler's own `exit(1)`. Filed as **0668**.

⚠ A 17th `source`, `resources.tcl` at `:13269`, is inside `proc setup_toolbar`
and is **not** on the startup path.

**This is the root cause of issue 0424, not a relative of it.** 0424 lost
`op_annot.tcl` from the install list; 275 in-tree checks stayed green and the
*installed* binary was dead on arrival, exit 139. The fix then was to put the
file back on the list; the crash mechanism was never touched, and `op_annot.tcl`
was still one of the sixteen bare sources on the day this was fixed.

The suite is **structurally blind** to it: in-tree, `XSCHEM_SHAREDIR` resolves to
`src/`, so a file missing from the install list is still found. Only an
installed-tree check or a deliberate sharedir farm can see it.

## 3. What landed

Four file-static C89 helpers above `Tcl_AppInit` in `src/xinit.c`, and one
changed line at `:3571`:

```c
- source_tcl_file(name);
+ if(source_tcl_file(name) != TCL_OK) xschem_startup_abort(name);
```

| helper | what it does | why it exists |
|---|---|---|
| `xschem_first_line()` | copies a string up to its first `\n` | `log_output()` prefixes EVERY physical line with `#! `, so a multi-line cause writes many durable lines — **0665's exact shape**, which R5 forbids |
| `xschem_failed_source_origin()` | extracts the innermost `(file "F" line N)` frame of `::errorInfo` | names the helper in the RAISE shape |
| `xschem_startup_announce()` | builds ONE line, to stderr **and** `log_output(1, …)` | the log is already open — `init_action_log()` runs from `main.c:103` **before** `Tcl_AppInit`, and even the segfaulting runs wrote its header |
| `xschem_startup_abort()` | announce, `fflush(NULL)`, `Tcl_Exit(EXIT_FAILURE)` | does not return |

It calls **no Tcl proc**: seven of the fifteen helpers are sourced *before*
`::xschem::notify_log` exists, so a Tcl-routed announcement would be silent for
exactly the earliest failures. That is what R2's EARLY pick proves.

**Both shapes name the file** because the line carries both halves — the
`::errorInfo` frame AND the first line of `tclresult()`. Measured with `tclsh`:
a helper that RAISES puts the HELPER in the first frame; a helper that is ABSENT
never opens, so the first frame is the OUTER file and the helper is named in the
error RESULT instead.

## 4. Measured AFTER — re-verified by the write-up agent on the shipping binary

```
### clean EXIT=0 ALIVE=1 ANNOUNCE=0 NOSUCHVAR=0  HASHLINES=0 DEGRADED=0
### err   EXIT=1 ALIVE=0 ANNOUNCE=1 NOSUCHVAR=0  HASHLINES=1 DEGRADED=0
### abs   EXIT=1 ALIVE=0 ANNOUNCE=1 NOSUCHVAR=0  HASHLINES=1 DEGRADED=0
### ciw   EXIT=0 ALIVE=1 ANNOUNCE=0 NOSUCHVAR=0  HASHLINES=1 DEGRADED=1
```

`139 → 1`. `NOSUCHVAR` **10 → 0**: control never reaches `:3417`'s unset-variable
reads, so `:658` is never handed a NULL. The durable line, verbatim:

```
#! STARTUP ABORTED: <farm>/xschem.tcl did not finish. Failing file:
<farm>/op_annot.tcl line 1. Cause: WU broken helper. The rest of it -- layers,
colours, menus, key bindings, undo, the statusbar -- was never set up, so xschem
is exiting instead of running structurally invalid. See doc/claude/issues/0663.
```

The same line goes to stderr prefixed `xschem: `. `source_tcl_file()`'s own
`Tcl_AppInit() error:` block is still printed **verbatim** above it, so
`full_audit.sh:316` `classify()`'s `^Tcl_AppInit\(\) error` anchor and
`test_audit_classifier`'s `B_APPINITNAME`/`B_APPINITREAL` are unmoved (50/50
green).

## 5. THE DESIGN QUESTION, ANSWERED — (b), against the driver's recommendation

The brief recommended **(a) announce-and-continue**. The crew shipped
**(b) announce-and-abort**, and the sentence of the brief this refutes is:

> "a user with a broken PDK helper still gets an editor"

As an argument for (a) **at the C level** it does not hold, because the
PDK-helper case is a **different call site**. A PDK procs file sourced from an
`xschemrc` goes through the six `source_tcl_file()` callers at
`src/xinit.c:3249/3256/3263/3279/3288/3294`, which this fix does **not** touch.
That user still gets their editor and still exits 0, exactly as
`doc/claude/specs/op_annotation.md` documents. What now aborts is only xschem's
**own** fifteen shipped GUI helpers.

And for those, continuing is measured **unsafe**. `src/xschem.tcl` sets
`line_width` (`:16328`), `undo_type` (`:16575`), `cairo_font_scale` (`:16638`),
`cairo_font_line_spacing` (`:16641`) and `cadlayers` (`:16663`) — i.e. **every
variable `Tcl_AppInit` reads at `:3417`ff** — *after* the bare-source block at
14568–14854, and `src/xschemrc` ships `set undo_type` (`:414`) and `set cadlayers`
(`:427`) **commented out**. `tclgetintvar` returns 0 on a miss
(`scheduler.c:14323`); `tclgetvar` returns NULL (`:14350`). So "C stops crashing
and continues" is a session with `cadlayers=0`, `line_width=0`, `undo_type` NULL,
no colour lists, no menus, no bindings — **that can still be told to load and
SAVE a schematic**, with **0619** (`ps_colors[cadlayers]` heap over-read) already
open in exactly that state. A subtly wrong tool is worse than a refusal.

Continuing is also **unreachable from C**: only running the REST of `xschem.tcl`
sets those defaults, and C cannot resume an aborted `Tcl_EvalFile`.

⚠ **Do not read "continuing is unsafe" as a rejection of a Tcl-side (a).** It is
true of a *C-level* continue. The scout measured that 14 of 16 helpers survive
fine when wrapped in Tcl `catch` (`cadlayers=22`, `cairo_font_scale=1.0`). The
honest statement is: **option (a) is safe but is a Tcl-side fix, which
`status_annotate.md` §5 forbade ("Not sixteen `catch` wrappers"); C can only do
(b).** A later crew must not cite this issue to reject a Tcl-side (a).

**It announces either way**, which is the part 0423's standing objection cares
about — and it announces strictly *more* than HEAD did.

## 6. Decisions (ladder rung, and the rejected alternative)

| # | rung | decision | rejected |
|---|---|---|---|
| D1 | L3 | **(b) announce and abort cleanly**, exit 1 | (a) at the C level — measured unsafe and unreachable, see §5. **User-visible, unratified → status E** |
| D2 | L2 | **no `src/xschem.tcl` change at all** | an `xschem::source_helper` proc replacing the 15 bare sources — blast radius; the `uplevel #0` landmine (a `source` inside a proc frame turns every helper's top-level `set` into a LOCAL, silently breaking every helper); 7 of 15 precede `notify_log`; and routing a non-`ciw` helper through `notify_degraded_once` would announce "NOTICE CHANNEL DEGRADED" while the channel is fully live — **0666's exact shape** |
| D3 | L2 | change **only** the one call at `:3571`; `source_tcl_file()` stays byte-identical | hardening `source_tcl_file()` or all seven callers — it would turn the documented-survivable broken-`xschemrc` case fatal |
| D4 | L2 | exit code **`EXIT_FAILURE` (1)** via `Tcl_Exit` | a bespoke code (78/86) — buys nothing the text does not. **Also rejected: returning `TCL_ERROR` from `Tcl_AppInit`** — that is not an abort; `Tcl_MainEx` prints "application-specific initialization failed" and walks on with `xctx` unallocated, and `main.c:145`'s detach path discards it entirely |
| D5 | L2 | literal **`STARTUP ABORTED:`** | extending the `Tcl_AppInit() err N:` family — `full_audit.sh:308-310` calls widening that anchor a separate, unmeasured change |
| D6 | L2 | name the file from `::errorInfo`'s first `(file …)` frame **plus the first line only** of `tclresult()` | dumping `::errorInfo` whole — `log_output` prefixes every physical line with `#! `, so one failure writes 6+ durable lines: **0665's shape**, forbidden by R5 |
| D7 | **L1 (I1)** | 0658's per-file `ciw.tcl` catch is **NOT redundant** — keep it | a general guarded `source` in C, which would swallow the failure before 0658's catch body runs, changing its announced cause string and risking a doubled durable line |
| D8 | L2 | do **not** NULL-guard `:658` here | belt-and-braces — it would mask the class and blur SAB-A, which must restore the exact exit-139 signature to prove SG1. Filed as **0668** |
| D9 | L2 | R2 picks: EARLY `action_registry.tcl` (`:14568`, before `notify_log` exists), LATE `alt2_toggle_view.tcl` (`:14815`, after) | two adjacent picks, which would prove only that a list is a list |
| D10 | L2 | a **new** suite `test_startup_guard_0663.tcl`; every row compares a COUNT or a status string, never a raw `-out` blob | extending `test_ase_core` (subject mismatch, no DISPLAY for the R7 legs); adding an omit sentinel to `sharefarm.tcl` (shared with two other suites) |

### The 0658 redundancy verdict — measured, recorded, NOT acted on

`src/xschem.tcl:14854`'s per-file catch is **not redundant and must not be
removed**. With `ciw.tcl` broken, `xschem.tcl` **succeeds** (the catch swallows),
`source_tcl_file` returns `TCL_OK`, and the C path never fires — zero
interaction, one announcement, one durable line, 0658's shipped output
byte-unchanged (SG14 headless + SG18 on `:99` pin this). Under this (b)-shaped
fix that wrapper is **the only thing keeping a broken `ciw.tcl` in the
alive-and-degraded class instead of the clean-abort class**, so removing it would
be a behaviour **regression**, not a cleanup. No double announcement and no
doubled durable line exist to fix.

⚠ That makes `ciw.tcl` the **one helper of the sixteen with different shipped
semantics** from the other fifteen. The asymmetry is deliberate and load-bearing.

## 7. The sabotage matrix — 5 variants, every predicted red appeared

Neutralised by renaming the callee to a no-op (never a `/* SABOTAGE */`
comment); restored with `cp` + `touch`; `grep -rn SABOTAGE src/` empty; rebuilt
after every restore.

| variant | predicted | observed | verdict |
|---|---|---|---|
| **SAB-A** revert the return-value check (`xschem_startup_abort` → no-op stub) | 12 | **14** red — all 12 predicted + SG19 SG20. SG1 returns to the exact HEAD signature `CHILDKILLED SIGSEGV` | superset, no hole |
| **SAB-B** suppress the announcement, keep the clean abort | 11 | **12** red — all 11 + SG19. SG1/SG5/SG6 stayed **green by design** (they measure the abort, not the announcement) | superset; the two contracts are pinned by disjoint rows |
| **SAB-C** announcement hoisted out of the guard → fires on EVERY launch | 5 hard + SG21 conditional | **9** red — all 5 hard (SG12 SG13 SG14 SG17 SG18) + SG2 SG4 SG11 SG20 | superset, no hole |
| **SAB-D** stop naming the failing file (origin extractor → empty string) | 4 | **6** red — all 4 + SG7 SG19. SG8/SG16 (ABSENT) correctly stayed green: Tcl's own result names the file independently | superset, no hole |
| **SAB-E** dump `errorInfo` whole (**0665's shape**) | 1 | **1** red — exactly SG20, reporting 7 durable `#! ` lines instead of 1 | exact |

**Predicted reds that did not appear: none.** One predicted row did not *move* —
**SG21 under SAB-C** — and it is **not a hole**: SG21 counts lines beginning
`Tcl_AppInit() error`, and SAB-C's spurious line uses the `xschem: STARTUP
ABORTED` prefix, so the count correctly stays 1 (that is precisely SG21's job —
guarding `full_audit.sh:316`'s classifier literal). The doubling SAB-C introduces
**is** caught, by SG4 at 2. The plan pre-declared this outcome.

Restore receipt: `md5sum src/xinit.c` = `00565bce5cd3577ffd46d545c4ac2cce`,
`grep -rn SABOTAGE src/` 0 hits, `grep -n '_real(' src/xinit.c` 0 hits,
0 sources newer than `src/xschem`. Re-verified by the write-up agent at commit
time.

## 8. Tiers

`test_startup_guard_0663` **17** checks (`--nogui`, GUI legs self-SKIP with a
printed reason) / **22** (`:99 --pipe -q`). Everything else at baseline:
`test_ase_core` 159 · `test_ase_final` 67 · `test_ase_dialogs` 166 ·
`test_ase_window` 182 · `test_ase_cosim` 341 · `test_op_annot` 330 (`--nogui`) /
336 (`:99 --nolog`) / 337 (`:99` log open) · `test_ase_log_seam_0207` 41 ·
`test_audit_classifier` 50 · T1 3 FAIL / 3 NOGOLD (identical rows) · T2 6/6.

`test_ciw` reports **1 FAILED** on the `:99 --logdir` arm — **pre-existing at
HEAD**, reproduced five times across three agents, byte-identical row. Filed as
**0670**.

## 9. STILL OPEN

**The class fix covers the ERROR path. It does not cover every path to the same
crash**, and two of the residuals below are in the fix's own code.

| id | what |
|---|---|
| **0671** | ⚠ **the guard is CODE-based, not STATE-based.** `return -code return` / `return -level 2` in a helper, or a top-level early `return` in `xschem.tcl`, still give **exit 139, zero announcement, zero durable line** — reproduced by two agents. One extra term closes all three. **The sharpest residual: a future top-level `return` in `xschem.tcl` silently restores the whole 0663 class.** |
| **0672** | the announcement's `Failing file:` can name a file that **never failed** — `strstr(info, "(file \"")` matches the first occurrence anywhere in `::errorInfo`, including inside the error *message*. Measured: a decoy in the message wins. Also: the 512-byte cause buffer truncates with no marker |
| **0668** | `sig_handler` (`main.c:32`) derefs a half-initialised `xctx` and **double-faults** — why the code was 139, not `exit(1)`. This fix removes the trigger at one call site; the handler is still unsafe for any pre-init crash. `xinit.c:658`'s NULL `strcmp` is deliberately still unguarded (D8) |
| **0669** | **the mode the human actually uses is untouched.** Plain interactive GUI (no `--pipe`/`-q`) with a broken helper hangs forever on `source_tcl_file`'s modal (`xinit.c:1535-1545`). Measured: EXIT 124 on a 15 s timeout, `STARTUP ABORTED` count **0** on stderr and **0** in `Xschem.log` |
| **0670** | `test_ciw.tcl:131` RED at HEAD — the CIW error echo reaches the durable log |
| **0673** | `test_wave_markers` litters a **gitignored** `untitled~.sch` in the repo root, which reddens `test_ase_core`'s C11 guard on any later run in the same tree |

Non-defect residuals worth knowing:

* **R4's durable half needs a log to be open.** `--nolog`, and `--nogui` without
  `--logdir` (`src/util.c:351`), both give stderr only. Correct and documented —
  but it means `full_audit`'s `--nolog` arm can never witness the durable half.
* **The exit code is now a test-visible contract.** SG rows assert the literal
  `CHILDSTATUS 1`; changing `EXIT_FAILURE` reddens six rows.
* A helper calling `exit 7` exits 7 with no announcement. Correct — an explicit
  exit is not a failed source.
* `Tcl_EvalFile` converts a top-level `break`/`continue` into a real error, so
  `TCL_BREAK`/`TCL_CONTINUE` cannot be laundered into `TCL_OK`. Probed, not
  exploitable.

## 10. Process hazard recorded, not a code defect

`src/xinit.c` was mutated and rebuilt **twice by a second concurrent session**
during the verification legs (12:30:15 and 12:33:20), and at 12:30 the tree
briefly carried SAB-A residue. The adversary pinned a copy of the binary and
re-verified; the write-up agent re-checked md5 + `grep SABOTAGE` + suite counts
at commit time and found the tree pristine and green. **Any tier number recorded
inside those windows was measured against an unknown build.** Two sessions were
live in one repo while the crew's rule says only the Implement agent builds.
