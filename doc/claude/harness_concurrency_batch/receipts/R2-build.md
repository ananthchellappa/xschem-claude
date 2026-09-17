# R2-build — `test_startup_guard_0663` stops asserting on the developer's simulator registry

**Status:** DONE

Every prediction in `receipts/R2-R3-design.md` §A was falsifiable and **every one of
them survived**, to the digit. The design crew's two headline numbers — `SG13 -> {3}`
and `SG14 -> {0 1 1 0 4}` — were produced by reading source with nothing executed, and
the tree returned exactly those strings on both arms. Three things the design could not
execute are now measured, one of them a **new finding the design did not predict**
(§"What the design did not know").

---

## Files touched

* **`tests/headless/test_startup_guard_0663.tcl`** — the only file changed.
  `git diff --stat` → **85 insertions, 2 deletions**, five hunks:

  | hunk | new lines | what |
  |---|---|---|
  | `@@ -91,0 +92,43` | `:92-134` | the isolation rationale + `set sg_home` / `file mkdir $sg_home/.xschem` (**Edit A-1**) |
  | `@@ -127,0 +171,6` | `:171-176` | `SG_INNER` gains the two witness `puts` (**Edit A-3a**) |
  | `@@ -133 +182` | `:182` | `global` line gains `sg_home` (**Edit A-2**) |
  | `@@ -136 +185,16` | `:185-200` | `sg_run`'s HOME save/set/restore around the launch (**Edit A-2**) |
  | `@@ -335,0 +400,19` | `:400-418` | **new row `SG22`** (**Edit A-3b**) |

* Nothing else. No source file, no issue file, no `NUMBERING.md`, no `owed.sh`, no
  `CLAUDE.md`, no driver, no shared helper (`sharefarm.tcl` and `scratch.tcl` are
  **unchanged** — option (d) was declined exactly as the design recommended). No commit.

## ⚠ THE PROHIBITION: `~/.xschem/ase_simulators` WAS NOT TOUCHED

Checked at the start, after every phase, and at the end.

| when | size | mtime | md5 |
|---|---|---|---|
| before anything | 724 | 2026-09-14 00:22:03.895474585 | `13c5cec624b130f598db5779f7b2b8bf` |
| after **13** child-xschem launches across 8 suite runs and 5 probes | 724 | 2026-09-14 00:22:03.895474585 | `cmp` vs backup → **byte-identical** |

Backup taken first at
`<scratchpad>/R2/ase_simulators.bak` and `cmp`'d five separate times; every one silent.
The three dead entries (`ng-cm3`, `stub`, `slowstub`) are **still there, untouched, and
the suite no longer cares** — which is the whole of ⚖ R2.

**`~/.xschem/recent_files` (the issue 0924 canary) also never moved**: 2632 bytes,
2026-09-13 18:53:01, before and after.

---

## Rows added/changed — red-before and green-after, quoted

### `SG13` and `SG14` — the two false reds (fixed, not touched)

Neither row's text or expectation was changed. They were made *correct* by removing the
foreign input, which is the point: the contract they encode ("a healthy startup writes
zero `#! ` lines") was always right, and the environment was wrong.

**RED — before any edit, on today's tree, HEADLESS arm:**

```
FAIL: SG13 0663 R6 hard form: a healthy startup writes ZERO `#! ` lines to the durable log -- not one error line of any kind -> {3} (exp {0}) : FAIL
FAIL: SG14 0663 the 0658 CONTROL: a broken ciw.tcl still starts (exit 0), writes EXACTLY ONE `NOTICE CHANNEL DEGRADED` line and no STARTUP ABORTED, and the log gains exactly ONE `#! ` line in total -- the C backstop does not fire and does not double-announce -> {0 1 1 0 4} (exp {0 1 1 0 1}) : FAIL
RESULT: 2 FAILED (15 passed)
```

**RED — same two rows, same two values, DISPLAY arm** (`:99`):

```
FAIL: SG13 ... -> {3} (exp {0}) : FAIL
FAIL: SG14 ... -> {0 1 1 0 4} (exp {0 1 1 0 1}) : FAIL
RESULT: 2 FAILED (20 passed)
```

**GREEN — after A-1/A-2/A-3:**

```
RESULT: ALL PASS (18 checks)        # headless, rc 0
RESULT: ALL PASS (23 checks)        # display :99, rc 0
```

### `SG22` — new, and observed RED before the isolation existed

Sequenced deliberately: **A-1 and A-3 were applied first and A-2 held back**, so the
row's red is the genuine pre-fix state *and* the sabotage proof for A-2 at the same
time. A row that has never been red proves nothing, and this one has now been red on
both arms in a tree that contained its own witnesses.

**RED — A-1 + A-3 applied, A-2 absent, BOTH arms, identical value:**

```
FAIL: SG22 1377 the farm children resolve a PRIVATE config dir inside this suite's own scratch and inherit ZERO registered simulators -- so SG13/SG20's and SG14's `#! ` counts are about xschem's startup, never about whatever is in the developer's ~/.xschem/ase_simulators -> {0 0} (exp {1 1}) : FAIL
RESULT: 3 FAILED (15 passed)        # headless
RESULT: 3 FAILED (20 passed)        # display :99
```

`{0 0}` is both halves failing independently: the child resolved
`USER_CONF_DIR=/home/analog/.xschem` (so the `SG-CONF=$sg_home*` glob found nothing)
**and** answered `SG-SIMS=5` (so the `SG-SIMS=0` count was zero). Measured directly, out
of band, with a standalone probe: `P-CONF=/home/analog/.xschem` / `P-SIMS=5` on the real
HOME versus `P-CONF=<scratch>/hb/.xschem` / `P-SIMS=0` on a private one.

**GREEN — after A-2:** inside the `ALL PASS (18)` / `ALL PASS (23)` above.

**Check count: 22 → 23 display, 17 → 18 headless.** Arithmetic confirmed at every
stage (`15+2=17`, `15+3=18`, `20+2=22`, `20+3=23`). **Nothing asserts on it** —
`/usr/bin/grep -rn 'startup_guard_0663' tests/ --include=*.sh --include=*.tcl` returns
four hits and all four are prose cross-references in other suites' comments
(`sharefarm.tcl:27`, `test_ase_log_seam_0207.tcl:749`,
`test_op_param_store_1245.tcl:671`, `test_ase_core.tcl:3394`). Ledgers and receipts
quoting `startup_guard_0663 22` are now one behind.

---

## Commands run

Every command carried a `timeout`; no waiting loop anywhere. No stall occurred, so no
`TIMEOUT` outcome had to be named.

```sh
timeout 600 make -C src                                    # rebuild, brief rule 6
timeout 400 env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog \
  --script tests/headless/test_startup_guard_0663.tcl       # headless arm   (x4)
GUI_GATE=0 timeout 400 env DISPLAY=:99 ./src/xschem --pipe -q --nolog \
  --script tests/headless/test_startup_guard_0663.tcl       # display arm    (x3)
GUI_GATE=0 timeout 400 tests/headless/devdisplay.sh exec ./src/xschem ...   # x1, see trap
timeout 60 ./src/xschem --nogui --pipe -q --logdir <d> --script <probe>      # x5 probes
timeout 30 tests/headless/devdisplay.sh status                               # x2
```

**Never a bare `xschem`** — every launch is `./src/xschem` or under
`devdisplay.sh exec`. **No `run_regression.tcl` run** (instructed not to; a verification
crew owns T1). **No `full_audit.sh`.** No other crew's suite was running: the only live
`xschem`/`wish` processes on the box belong to **`/opt/xschem-repo`**, a different tree,
and `tests/results.log.lock` was absent throughout.

---

## Measurements

### The rebuild — verified, not assumed

`make -C src` printed **`Nothing to be done for 'all'`**, which is what two earlier
crews were burned by. It is **honest here**, checked three ways rather than trusted:

```
src/xschem     2026-09-17 07:00:25   <- binary
src/actions.c  2026-09-17 06:47:12   <- newest source, 13 min OLDER
src/save.c     2026-09-17 06:46:43
make -C src -n                       -> "Nothing to be done for 'all'"
```

The binary post-dates every `.c`/`.h` in the tree. Nothing was stale.

### The `init_action_log()` ordering — CONFIRMED, and it was the load-bearing hop

The design said the whole hypothesis dies if this is the other way round.

```
src/main.c:103   init_action_log();
src/main.c:145   Tcl_AppInit(interp);          /* the --preinit path */
src/main.c:148   if(has_x) Tk_Main(1, argv, Tcl_AppInit);
src/main.c:149   else      Tcl_Main(1, argv, Tcl_AppInit);
```

`init_action_log()` is **42 lines and three call sites earlier** than any entry into
`Tcl_AppInit`, so the durable log is open before `xschem.tcl` is sourced and
`log_output()` does not early-return on a NULL `actionlog_fp`. `src/xinit.c:3111-3112`
says so in its own comment and is **correct**. Confirmed empirically as well: the
registry sentences appear in a child's `Xschem.log` at all, which they could not if the
file were opened later.

### The chain, end to end — the three `#! ` lines, verbatim

A child launched with the real HOME and its own `--logdir` wrote exactly three, and they
name exactly the three entries predicted:

```
#! /home/analog/dev/xschem-claude/src/xschem is xschem itself, not a simulator. It is
   registered as the simulator named ng-cm3. Starting it would open a second editor that
   overwrites your own recent files and window settings, so nothing was started. ...
#! There is no file at /tmp/stage11/e2e/bin/sim, which you registered as the simulator
   named stub. ...
#! There is no file at /tmp/stage11/kp/bin/slowsim, which you registered as the simulator
   named slowstub. ...
```

(three physical lines; wrapped here only for the receipt.) The same child with a private
HOME wrote **zero** — its `Xschem.log` held only the three `#`-comment header lines.

### The positive control the driver had never measured

```
clean private HOME, DISPLAY arm  ->  RESULT: ALL PASS (22 checks)     rc 0
clean private HOME, headless     ->  RESULT: ALL PASS (17 checks)     rc 0
```

**The driver's "with a clean `HOME` it is ALL PASS (22 checks)" is now measured and
true**, to the check count, on a tree with no edits applied. It had been taken entirely
on trust through the whole ruling.

---

## What the design did not know — a second leak, and it is the user's own config dir

**`~/.xschem/geometry` was being written by this suite's children**, which nobody had
recorded. It is not hypothetical:

| moment | `geometry` mtime | md5 |
|---|---|---|
| before my first run | 07:42:38.078318295 | — |
| after the **pre-fix** display run | **07:46:20.898191969** | `da202f986a33f2d4d58d394d35c00ef0` |
| after the **post-fix** display run (full 23 checks) | **07:46:20.898191969** — unmoved | `da202f986a33f2d4d58d394d35c00ef0` — unchanged |

So the isolation removes a real, previously unrecorded write into the developer's
`~/.xschem/`, not merely a read. It also **localises the writer**: in the post-fix
display run the *parent* still has the real HOME while only the *children* are moved,
and `geometry` did not move — therefore **the writer is a farm child, never the parent**.
The same file duly appeared inside the private HOME during the positive control
(`<scratch>/pc/.xschem/geometry`).

This is one more argument against pruning and for isolation: pruning the registry would
have left this write in place.

---

## The brief's own warning, discharged: did MY fix leak?

> *"Setting `HOME` is exactly the kind of change that can leak."*

Two directions, both measured.

1. **Into the real `~/.xschem/`** — a full `ls -la` of the directory before and after
   the whole task: **eleven entries, identical names, identical sizes, and the only
   moved mtime is `geometry`'s, which moved during the PRE-fix runs and stood still
   through the post-fix ones.** Nothing of mine wrote there.
2. **The parent's own `HOME` left moved** — this one the `geometry` canary *cannot*
   answer (the writer is a child, see above), so it was measured directly, on a
   **throw-away copy** of the suite in `tests/headless/` so the real file was never
   touched for a probe:

   ```
   note: PARENT-HOME after all children = {/home/analog}
   RESULT: ALL PASS (18 checks)
   ```

   The copy was deleted in the same command; `ls tests/headless/_probehome*` → none, and
   `git diff --stat` is back to the intended 85/2.

**Litter** (checked with `ls`, never `git status` — issue 1480): `untitled*` in `.`,
`tests/`, `tests/headless/` and `src/` → **all four empty**, before and after.
`tests/headless/.scratch/` → **empty**, so `test_scratch`'s exit cleanup ran and the
moved HOME did not defeat it.

---

## Claims checked vs taken on trust

Every design inference, marked. The design was supplied as inference precisely so it
could be falsified; it was tested rather than re-read.

| claim | verdict | what settled it |
|---|---|---|
| The 2 of 22 are **SG13** and **SG14** | **CONFIRMED** | the two FAIL lines, both arms |
| SG13 reads **`{3}`** | **CONFIRMED exactly** | `-> {3} (exp {0})` |
| SG14 reads **`{0 1 1 0 4}`** | **CONFIRMED exactly** | `-> {0 1 1 0 4} (exp {0 1 1 0 1})` |
| headless is 17, display 22 | **CONFIRMED** | `2 FAILED (15 passed)` / `2 FAILED (20 passed)` |
| `init_action_log()` runs before `Tcl_AppInit` | **CONFIRMED** | `main.c:103` vs `:145/:148/:149` |
| the 3 lines name `stub`, `slowstub`, `ng-cm3` (A-iii) | **CONFIRMED** | child `Xschem.log`, quoted above |
| `ng-cm3` trips the `iseditor` guard (A-iv) | **CONFIRMED** | *"is xschem itself, not a simulator"*, `ase.tcl:1550-1557` |
| the sentences never reach `-out`/stderr (A-v) | **CONFIRMED** | child stdout+stderr carries none of the three |
| a pre-created `.xschem` suppresses `Created … template xschemrc` (A-vi) | **CONFIRMED, both directions** | pre-created → absent; not pre-created → the line **is** printed (`xinit.c:3436-3446`) |
| nothing else in the child needs the real HOME (A-vii) | **CONFIRMED** | `ALL PASS` on both arms |
| registry byte-identical afterwards (A-ix) | **CONFIRMED** | `cmp` silent, ×5 |
| **driver's "clean HOME → ALL PASS (22)"** (A-viii) | **CONFIRMED** | measured for the first time; see above |
| option (b) — stub the reader — **impossible** | **CONFIRMED by measurement** | the child prints its own `USER_CONF_DIR`, resolved in C startup before any script exists; no parent-side proc can precede it |
| option (c) — assert on a populated registry | **CONFIRMED unsuitable** | SG13/SG14 assert "a healthy startup writes no error lines"; tolerating N lines guts R6, the fence SAB-C exists to redden |
| `test_sim_registry_isolate` cannot reach this | **CONFIRMED** | it clears *this* process's `ase::simulators`; `P-SIMS=5` in a child proves the child re-reads from disk |
| suite is absent from T1 | **CONFIRMED** | `grep -n 'startup_guard' tests/run_regression.tcl` → silent |
| nothing asserts on the check count | **CONFIRMED** | 4 hits, all prose |
| the binary was fresh | **CONFIRMED** | mtimes + `make -n` |

**Taken on trust, named as such:**

1. **T1's zero baseline.** I did not run `run_regression.tcl` — instructed not to, and a
   verification crew owns it. The *reason* it is unaffected is measured (the suite is not
   in `hcases`/`dcases`), but the baseline itself is not mine.
2. **0663's own contract** (R1–R7, SAB-C/SAB-D). I changed no expectation, so I did not
   re-derive them.
3. **The 13 dead-entry states of other developers' registries** — this box has three;
   the claim that another box would differ is a prediction, and it is precisely the
   prediction the fix makes irrelevant.

---

## Corrections to the design — two traps it would have walked a crew into

The design's §A2.5 *procedure* (not its analysis) contains two commands that fail.

1. ⚠ **`devdisplay.sh exec` CANNOT BE USED WITH A MOVED `HOME`.** Step 5 says to take
   the clean-HOME positive control through the wrapper. Measured:

   ```
   env HOME=<clean> tests/headless/devdisplay.sh exec ./src/xschem ...
   -> rc 6, "!! devdisplay ERROR: :99 is not running. Start it first: ..."
   ```

   The display was alive the whole time. `devdisplay.sh:70` resolves
   `STATE_DIR="${XSCHEM_DEVDISPLAY_DIR:-$HOME/.claude/xschem_dev_display}"`, so moving
   `HOME` moves the wrapper's own state dir and it cannot find the display it started.
   **The failure message names the wrong cause**, which is what makes it expensive — it
   tells you to start a display that is already running. Use `GUI_GATE=0 DISPLAY=:99`
   directly (the form `test_startup_guard_0663.tcl:71-72` documents in its own header),
   or export `XSCHEM_DEVDISPLAY_DIR`. This generalises: **any** task that moves `HOME`
   loses `devdisplay.sh`, and `~/.claude/gui_test_gate/` and `~/.claude/xschem_owed/`
   sit under the same root.

2. ⚠ **`env HOME=x -u DISPLAY cmd` silently runs the wrong program.** `env` stops
   parsing options at the first `NAME=VALUE`, so `-u` became the command: **rc 127**,
   no output, and a green-looking "no failures" if anyone had grepped for `FAIL`.
   Options first: `env -u DISPLAY HOME=x cmd`.

Everything else in the design landed unaltered: the three edits were applied
essentially verbatim, the comment blocks kept (with the measured numbers folded in so
the next reader inherits evidence rather than a prediction), and no widening into
`sharefarm.tcl` or `scratch.tcl`.

## For issue 1377

The design asks that this be noted, and it is worth a line in
`doc/claude/issues/1377-four-ase-suites-read-the-developers-simulator-registry.md`:
**1377 has a child-process face that its eighteen in-process suites do not cover, and
`test_sim_registry_isolate` cannot close it.** `scratch.tcl`'s isolator clears
`ase::simulators` in the *test's* interpreter; a suite whose subject is a second xschem
process is untouched by that, because the child re-reads
`~/.xschem/ase_simulators` from disk in its own startup. The handle is `HOME`, the
in-tree idiom already exists in three suites (`test_ase_simdlg_0937.tcl:397-417`,
`test_ase_simreg_0931.tcl:355-375`, and now this one), and the tell is a row that counts
*totals* rather than named strings. **I did not edit 1377** — one task, and the issue
file was not mine to touch.

**A candidate for a future task, not done here:** `share_farm_child`
(`tests/headless/sharefarm.tcl`) has three callers — `test_ase_core` (×5),
`test_startup_guard_0663` (×2, now isolated) and `test_ase_log_seam_0207` (×1). The
other two launch children under the developer's HOME today. Option (d) — moving the
redirect into `sharefarm.tcl` — was declined here as too wide for one task, and it
remains the right answer if a second suite hits this.

---

## Left dirty

**Mine, and only this:**

```
 M tests/headless/test_startup_guard_0663.tcl      (+85 -2)
?? doc/claude/harness_concurrency_batch/receipts/R2-build.md   (this file)
```

**⚠ NOT MINE — the tree moved under me while I worked, and the driver should know:**

* **Two commits landed mid-task**: `9ed27a7f test(R3): C11 becomes a delta ...` and
  `1f6b70a9 docs(ledger): caught up through 9ed27a7f ...`. HEAD was `2e65e885` when I
  started. The five modified files in my dispatch snapshot (`0609-*.md`, `1480-*.md`,
  `test_ase_core.tcl`, `test_op_dump_altshow.tcl`, `test_no_untitled_litter.tcl`) are
  consequently **gone from `git status`** — committed, not lost.
* **A foreign change set appeared during my task and is STILL GROWING as I write.** It
  was **0** files when I took my first tree snapshot, **2** at 07:48:13/07:48:16, and
  **11** by the time I closed out — `.gitignore`, `src/xschem.tcl`, and nine
  `tests/headless/test_*.tcl` (`annot_show_menu`, `delete_cut_selflog`,
  `instance_update`, `perform_action_align`, `placement_wire_gate`,
  `statusmsg_hold_0248`, `traversal_flag_leak`, `undo_link_symbols`, `undo_selection`).
  **Do not read that list as final; read it as a timestamp.**
* **None of it is mine, and the content proves it, not just the mtimes.** My only writes
  in this tree were `test_startup_guard_0663.tcl` and a throw-away copy deleted in the
  command that made it. The two I inspected are **stale-citation repairs** of exactly
  the class the R2-R3 design flagged in §B3.1 — `save.c:4149` → `:6139`,
  `save.c:4156` → `:6146`, `xinit.c:2952` → `:3175` — i.e. somebody is working the
  0609/1480 citation seam, which is R3's neighbourhood and not R2's.
* **⚠ My file was NOT collaterally edited.** `git diff --stat` on it reads **85
  insertions, 2 deletions** at close, byte-for-byte the change I made, unchanged since
  07:46:43. The driver can stage it in isolation.
* ⚠ **A consequence for whoever commits this:** `git commit -a` in this tree would sweep
  up eleven files belonging to another task. Stage
  `tests/headless/test_startup_guard_0663.tcl` and this receipt **by path**.
* The four pre-existing untracked entries (`.xschem/`, `doc/claude/rdw_lists_batch/`,
  `doc/claude/rdw_sim_batch/`, `sky130A/.../debug_st1/`) are as the driver left them.

**Nothing to clean up:** no scratch dirs, no `untitled*`, no probe files, no farm
residue, and `~/.xschem/` byte-unchanged except a `geometry` mtime that the **pre-fix**
runs moved.

## Owed to the user

**Nothing new, and nothing cleared.** I did not touch `owed.sh` (brief rule 8).

No pixels, no user-visible behaviour, no GUI, no UI copy — this is internal test-harness
engineering, which is the driver's stated reason for taking ⚖ R2 off the user's queue,
and nothing measured today disturbs that judgement. The one thing that *is* the user's
— the three dead entries in their own `~/.xschem/ase_simulators` — is deliberately
**still there**, and is now nobody's problem but theirs to prune when they feel like it.
