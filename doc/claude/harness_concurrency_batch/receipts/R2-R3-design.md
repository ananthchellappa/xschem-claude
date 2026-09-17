# R2-R3-design — the two builds designed to the line, nothing executed

**Status:** DONE (design only — read-only task, per the hard constraint)

**Files touched:** exactly one — this receipt. No test file, no source file, no
issue file, no `owed.sh`. `git diff --stat` unchanged.

**Rows added/changed:** none *executed*. Two rows designed for R2
(`SG22` new, plus the fix that greens `SG13`/`SG14`) and one changed for R3
(`C11`, plus its twin `H1` in `test_op_dump_altshow`). No red-before/green-after
is quoted as **observed** anywhere in this receipt; every colour below is a
**prediction** with the arithmetic shown, so the implementation crew can falsify it.

**Commands run:** `/usr/bin/grep`, `sed -n`, `ls`, `git check-ignore -v`,
`git ls-files`, and `Read`. No `xschem`, no `make`, no suite, no `run_regression.tcl`,
no `full_audit.sh`, nothing that writes to the repo, `~/.xschem/` or a display.
Every command was bounded by construction (local file reads, no network, no spawn).
**Another crew was running suites; CREW_BRIEF rule 4 was honoured absolutely.**

---

# ⚠ READ THIS FIRST — three corrections to the taken decisions

Both decisions survive, but **three load-bearing sentences in `DECISIONS.md` are
wrong or over-stated**, and one of them would have mis-scoped the whole R3 build.

### 1. ⚠ "Neither ships alone" is HALF wrong. The dependency is ONE-DIRECTIONAL.

`DECISIONS.md` (R3): *"⚠ MUST LAND TOGETHER WITH 1480's CONTAINMENT. … Neither
ships alone."*

**The C11 delta ships alone perfectly safely.** It only ever makes the row *less*
sensitive: it converts "is this directory clean?" into "did I dirty it?", so every
state that is green today stays green and 13-of-13 false reds go away. There is no
state in which the delta alone reds something that passes today.

**The containment cannot ship alone** — that half is correct, and only if the
containment picks a directory `C11` reads.

So the true ordering is: **delta first (or together), containment never before.**
This matters for scheduling: R3's valuable half is unblocked right now and does not
have to wait on the riskier half. I recommend landing the delta as its own commit.

### 2. ⚠ "0609's containment pins T1's cwd to `$REPO`" — 0609 does not say `$REPO`.

`DECISIONS.md` states it flatly; **0609's actual text** (`:52-54`) is *"give each
test its own cwd in `tests/headless/full_audit.sh` and `tests/run_regression.tcl`"* —
no directory named. `1480 §5` states it correctly, with the conditional intact
(*"and **if that is `$REPO`**, `C11` fires…"*). The summary dropped the "if".

The practical consequence is the opposite of alarming: **any per-case directory that
is not the repo root is already safe for `C11` as it stands today.** The red is not a
property of containment, it is a property of one possible choice of directory. The
delta is still worth having — it is what makes `C11` *mean* something again — but the
containment is not the tripwire the summary implies.

### 3. ⚠ 0609's supplied fix code is a PARTIAL fix — do not paste it.

`0609`'s *"The shape of a fix"* block is cited by the brief as already-supplied fix
code. Read against today's tree it has two defects, one cosmetic and one structural:

```tcl
set h_pre [glob -nocomplain -directory $repo untitled*]
check_true {... made no NEW untitled* in the repo root} \
  [expr {[llength [glob -nocomplain -directory $repo untitled*]] <= [llength $h_pre]}]
```

* **(a) It compares COUNTS, not SETS.** A run that removes `untitled~.sym` and adds
  `untitled~.sch` scores `1 <= 1` — clean. 0609 §3 is itself the recorded correction
  that *both* extensions occur, so this is the exact swap the file already knows about.
* **(b) It still only looks at `$repo`, so it fixes the false-red direction and leaves
  the BLIND direction exactly as blind.** Under T1 (cwd `tests/`) and under *any*
  containment, the suite's own leak lands somewhere `$repo` is not, and the row can
  never see it. That is precisely the finding R3 was decided on — and 0609's own code
  does not address it.

My design fixes both (§B4). This is the **third** issue file in this batch whose
prescribed fix turns out to be a no-op or a partial; the brief predicted it, and it
happened again.

---

# TASK A — ⚖ R2: isolate `test_startup_guard_0663` from the simulator registry

## A2.1 — WHICH 2 OF THE 22, and why it is exactly two

**Answer: `SG13` (`test_startup_guard_0663.tcl:332-334`) and `SG14` (`:343-352`).**
They are the *only* two checks in the file that count the child's **total** `#! `
durable-log lines. Every other row counts a *named* string, and the registry's
sentences carry none of those names.

| row | line | what it counts | today | with 3 dead entries |
|---|---|---|---|---|
| **SG13** | `:332-334` | `sg_log_count $sg_clean {#! }` | `0` | **`3`** ✗ |
| **SG14** | `:343-352` | list, last element `sg_log_count $sg_ciw {#! }` | `{0 1 1 0 1}` | **`{0 1 1 0 4}`** ✗ |

The code, verbatim:

```tcl
:332  check "SG13 0663 R6 hard form: a healthy startup writes ZERO `#! ` lines to the\
:333   durable log -- not one error line of any kind" \
:334    [sg_log_count $sg_clean {#! }] 0
```

```tcl
:347          [list [dict get $sg_ciw -status] \
:348                [sg_out_count $sg_ciw SG-ALIVE] \
:349                [sg_log_count $sg_ciw {NOTICE CHANNEL DEGRADED}] \
:350                [sg_log_count $sg_ciw {STARTUP ABORTED}] \
:351                [sg_log_count $sg_ciw {#! }]] \
:352    [list 0 1 1 0 1]
```

**Why the other twenty are immune — this is the part that makes "2" a derivation
rather than a coincidence:**

* **SG1–SG11, SG15–SG16, SG19–SG21** are children whose helper raises *during*
  `xschem.tcl`. The registry is loaded at **`src/xschem.tcl:19929`** (`ase::sim_load_conf`),
  and every injected failure sits **above** it — `action_registry.tcl` at `:17144`,
  `op_annot.tcl` at `:17521`, `alt2_toggle_view.tcl` at `:17593`. The child is already
  dead before the registry is read. (`SG11` breaks `xschem.tcl` *itself* with a
  **trailing** error, so it does reach `:19929` — but `SG11` counts only
  `{*STARTUP ABORTED*xschem.tcl*}`, `-status` and `SG-ALIVE`, never a `#! ` total.)
* **SG20** (`:225-227`) counts `#! ` totals too — but on `$sg_err`, whose `op_annot.tcl`
  aborts at `:17521`, **before** `:19929`. Immune for the same reason.
* **SG12, SG17, SG5, SG4** count `SG-ALIVE` / `STARTUP ABORTED` / `no such variable`
  occurrences in `-out`, and the registry sentences **never reach `-out`** (§A2.2).
* **SG21** globs `Tcl_AppInit() error*`. **SG0** reads `src/xschem.tcl` as text.
* **SG18** counts `NOTICE CHANNEL DEGRADED` and `STARTUP ABORTED` by name, not totals.

**⚠ And "22" is the DISPLAY arm.** Counting the `check` calls: 17 headless
(SG0–SG14, SG20, SG21) + 5 GUI legs (SG17, SG15, SG16, SG18, SG19) = **22**. Both
affected rows are in the *headless* 17, so the prediction is **2 of 22 on a display
and 2 of 17 headless** — the same two rows on both arms. `full_audit.sh` puts this
suite on its default arm (`--pipe -q --nolog`, no `--nogui` — it is in none of
`logdir_tests`/`nogui_tests`/`nolog_tests`, `full_audit.sh:84,161,163`), so under the
audit the GUI legs run and the count is 22. That is where the driver's number comes from.

## A2.2 — the path from `~/.xschem/ase_simulators` to a `#! ` line, hop by hop

Every hop read today. **This is the chain the implementation crew must confirm empirically**,
because it is the whole basis of A2.1.

| # | hop | file:line |
|---|---|---|
| 1 | the child is `exec`'d with the parent's `::env`, so it inherits **HOME** | `tests/headless/sharefarm.tcl:87-88` |
| 2 | `home_dir` ← `getenv("HOME")` | `src/xinit.c:3179` |
| 3 | `USER_CONF_DIR` ← `regsub ^~/ → home_dir` on the macro `"~/.xschem"` | `src/xinit.c:3286-3289`; macro at `config.h:46` |
| 4 | startup loader reads the list, once, beside `load_recent_file` | `src/xschem.tcl:19929` (`ase::sim_load_conf`) |
| 5 | the conf file is **`source`d**, so each line is a real call | `src/ase.tcl:4598-4614` (`uplevel #0 [list source $path]`) |
| 6 | `ase::sim_register` validates the program and **REPORTS** a bad one | `src/ase.tcl:1806-1807` |
| 7 | the five ordered guards give the `kind` | `src/ase.tcl:1550-1557` (`ase::sim_check`) |
| 8 | `ase::sim_say` → `ase::echo` | `src/ase.tcl:1445-1450`, `:314-320` |
| 9 | `ase::echo` → `::xschem::notify_safe` → `::xschem::notify` | `src/xschem.tcl:17499`, `src/ciw.tcl:256` |
| 10 | **sink 2** = the durable log | `src/ciw.tcl:~325` → `src/xschem.tcl:17327` (`notify_log`) |
| 11 | `xschem log_action -error` → `log_output(1, …)` | `src/scheduler.c:8107` |
| 12 | `log_output` prefixes every physical line with **`#! `** | `src/util.c:571-583` |

**⚠ The decisive ordering fact, and the one that could have killed this whole
hypothesis:** the durable log must already be open when `xschem.tcl` is sourced, or
step 12 silently no-ops (`log_output` returns early on a NULL `actionlog_fp`,
`util.c:574`). It is: **`init_action_log()` is called from `main.c:103`, BEFORE
`Tcl_AppInit`** — stated in the code's own words at `src/xinit.c:3112`
(*"The log is already open here -- init_action_log() runs from main() BEFORE
Tcl_AppInit, and even the segfaulting runs wrote its header"*), and corroborated by
0663's own HEAD measurement table (`R6_clean … LOGLINES=3`, i.e. the header was
written by a child that then ran normally).

**Why the sentences do NOT reach `-out`** (and therefore cannot touch SG12/SG5/SG4):
`xschem::notify`'s sinks are (1) `ciw_echo` — absent under `--nogui`, (2) the log
file, (3)/(4) Tk widgets — absent. **There is no stderr sink.** The only
`puts stderr` in the chain is `ase::echo`'s fallback for when `notify_safe` itself
raises (`src/ase.tcl:315-317`), which does not happen here.

## A2.3 — `scratch.tcl`, and the count the driver was given

**Does `scratch.tcl` redirect `USER_CONF_DIR` today? No.** It contains a
*memory-only* registry isolator, `test_sim_registry_isolate`
(`tests/headless/scratch.tcl:166-190`), and it says in its own header, twice, that
**nothing there touches a file** (`:148-153`) — by design, because moving the user's
live list and losing it on an abort is the defect it was written to avoid.

**⚠ `test_sim_registry_isolate` CANNOT fix this suite, and that is the new finding.**
It clears `ase::simulators` in **this** process. The 0663 suite's subject is a
**second xschem process**, which reads `~/.xschem/ase_simulators` for itself, from
disk, before any parent can touch it. **This is a child-process face of issue 1377
that 1377 does not cover** — 1377's eighteen suites are all in-process
(`/usr/bin/grep -n 'child' doc/claude/issues/1377-*.md` → **silence**).

**The driver's "169 suites" — CORRECTED. The number is wrong in three different ways
depending on what you count**, and none of the three is 169:

| what was counted | command | answer |
|---|---|---|
| files under `tests/` mentioning `scratch.tcl` | `/usr/bin/grep -rl scratch.tcl tests/ \| wc -l` | **195** |
| files that actually `source` it | `/usr/bin/grep -rl 'source.*scratch\.tcl' tests/` | **193** |
| **`test_*.tcl` suites** under `tests/headless/` | `/usr/bin/grep -rl 'scratch\.tcl' tests/headless/test_*.tcl \| wc -l` | **187** |
| non-`test_*` consumers | — | 7: `scratch.tcl` itself, `full_audit.sh`, `wvbs_common.tcl`, `probe_0194_symptom2.tcl`, `leakprobe_fullyzoom.tcl`, `tests/alt2_toggle_view.tcl`, `tests/select_same_cell.tcl` |

CLAUDE.md says "169 of 384", `scratch.tcl:157` says "171 suites", `1377` says "eighteen".
**The blast-radius argument is unaffected and gets stronger** — 187 suites, not 169 —
so **the ruling stands: `scratch.tcl` is out of scope.** But the number itself should
not be quoted as 169 again.

## A2.4 — THE RECOMMENDED EDIT: a private HOME for the children, in this suite only

### The options, evaluated

| option | verdict |
|---|---|
| **(a) a private conf dir for the children, via `HOME`, set inside this suite** | ✅ **RECOMMENDED** |
| (b) stub/override the registry-reading proc | ❌ **impossible** — the reader runs in a *child process*, before any script of ours exists. Nothing in the parent can reach it. |
| (c) have the two checks assert on a registry the suite populates | ❌ **does not fit** — the two rows do not assert *about* the registry at all; they assert that a **clean startup writes no error lines**. Making them tolerate N registry lines would gut R6's whole contract ("the normal path is byte-unchanged"), which is the fence SAB-C exists to redden. |
| (d) the same redirect inside `sharefarm.tcl` | ⚠ defensible but wider: `share_farm_child` has **3** callers (`test_ase_core` ×5, `test_startup_guard_0663` ×2, `test_ase_log_seam_0207` ×1). `test_ase_core` already isolates *itself* in-process and would gain child isolation it does not ask for. Prefer (a); revisit if a second suite hits this. |

**Why `HOME` and not `::USER_CONF_DIR`:** `USER_CONF_DIR` is a Tcl variable set by
the child's own C startup (`xinit.c:3289`); setting it in the parent reaches nothing.
`HOME` is the only handle, and it is the **existing in-tree idiom for exactly this
problem** — `test_ase_simdlg_0937.tcl:397-417` (*"HOME is what moves `::USER_CONF_DIR`,
so the child is given a HOME of its own inside this suite's scratch tree and never
sees the developer's list"*) and `test_ase_simreg_0931.tcl:357-375`.

### Edit A-1 — `tests/headless/test_startup_guard_0663.tcl`, after line 90

**BEFORE** (`:90`):
```tcl
set scratch [test_scratch startup_guard_0663]
```

**AFTER** (`:90` unchanged, new block inserted after it):
```tcl
set scratch [test_scratch startup_guard_0663]

## ISOLATION FROM WHOEVER'S ~/.xschem/ase_simulators IS LIVE -- the CHILD-PROCESS
## face of issue 1377, which that issue does not cover.
##
## Every farm child is a FULL xschem start, so it reaches src/xschem.tcl:19929
## `ase::sim_load_conf` and registers the DEVELOPER'S simulator list. Every entry
## whose program is missing, is not a file, is not executable, or IS xschem
## itself is REPORTED -- src/ase.tcl:1806-1807 -> ase::sim_say -> ase::echo ->
## xschem::notify sink 2 -> src/xschem.tcl:17327 notify_log -> `xschem
## log_action -error` -> src/scheduler.c:8107 -> log_output(1) -- i.e. as a `#! `
## line in the CHILD'S OWN durable log. SG13 and SG14 count those lines and
## expect 0 and 1, so on a machine with N bad entries they read N and N+1 and
## this suite reports a defect the repository does not have.
##
## ⚠ `test_sim_registry_isolate` (scratch.tcl) CANNOT REACH THIS. It clears THIS
## process's memory; the child reads the file from disk for itself, before any
## script of ours exists. HOME is the only handle: src/xinit.c:3179 getenv(HOME)
## -> :3286-3289 regsub of USER_CONF_DIR ("~/.xschem", config.h:46). Idiom lifted
## from test_ase_simdlg_0937.tcl:397-417 and test_ase_simreg_0931.tcl:357-375.
##
## ⚠ NOTHING OF THE USER'S IS READ, WRITTEN, RENAMED OR BACKED UP -- scratch.tcl's
## own rule (:148-153). The .xschem directory is PRE-CREATED so the child's
## `stat` at src/xinit.c:3437 finds it and does not mkdir one and copy a template
## xschemrc, which would print `Created ... dir with template xschemrc` on the
## child's stderr.
set sg_home [file join $scratch home]
file mkdir [file join $sg_home .xschem]
```

### Edit A-2 — `sg_run`, lines 132-139 (the only launch site)

**BEFORE** (`:132-139`, verbatim):
```tcl
proc sg_run {tag replace {flags {--nogui --pipe -q}} {drop {}}} {
  global repo scratch SG_INNER
  set farm [share_farm $repo [file join $scratch farm_$tag] $replace]
  foreach d $drop { file delete -force [file join $farm $d] }
  set r [share_farm_child $farm [file join $scratch c_$tag] $SG_INNER $flags]
  note "SG child $tag status" [dict get $r -status]
  return $r
}
```

**AFTER:**
```tcl
proc sg_run {tag replace {flags {--nogui --pipe -q}} {drop {}}} {
  global repo scratch SG_INNER sg_home
  set farm [share_farm $repo [file join $scratch farm_$tag] $replace]
  foreach d $drop { file delete -force [file join $farm $d] }
  ## The child's HOME, restored on EVERY path -- share_farm_child already restores
  ## ::env(XSCHEM_SHAREDIR) the same way (sharefarm.tcl:90-91), and a suite that
  ## left the parent's HOME moved would poison every later row in this process.
  set had [info exists ::env(HOME)] ; set old {}
  if {$had} { set old $::env(HOME) }
  set ::env(HOME) $sg_home
  set rc [catch {share_farm_child $farm [file join $scratch c_$tag] \
                   $SG_INNER $flags} r]
  if {$had} { set ::env(HOME) $old } else { catch {unset ::env(HOME)} }
  if {$rc} { return -code error $r }
  note "SG child $tag status" [dict get $r -status]
  return $r
}
```

### Edit A-3 — make the isolation OBSERVABLE (SG_INNER `:126-130`, and a new row SG22)

Without this, the fix is a line nothing can redden: it would go on passing on a box
whose registry happens to be clean and silently stop working the day somebody edits
`sg_run`. **That is issue 1377's own recorded lesson** (`scratch.tcl:191-197`:
*"a line nothing can red is a line that quietly stops working"*).

**BEFORE** (`:126-130`):
```tcl
set SG_INNER {
  puts "SG-ALIVE cadlayers=[expr {[info exists ::cadlayers] ? $::cadlayers : {NONE}}]"
  flush stdout
  exit 0
}
```

**AFTER:**
```tcl
set SG_INNER {
  puts "SG-ALIVE cadlayers=[expr {[info exists ::cadlayers] ? $::cadlayers : {NONE}}]"
  ## SG22's witnesses: which config directory this CHILD resolved, and how many
  ## simulators it inherited. Printed by the child, asserted by the parent.
  puts "SG-CONF=[expr {[info exists ::USER_CONF_DIR] ? $::USER_CONF_DIR : {NONE}}]"
  puts "SG-SIMS=[expr {[catch {llength [ase::sim_list]} n] ? {ERR} : $n}]"
  flush stdout
  exit 0
}
```

**New row, inserted after SG13 (after `:334`):**
```tcl
# --- SG22: the isolation is REAL, and it is OBSERVABLE -----------------------
# RED with the two HOME lines of sg_run removed: the child resolves the
# developer's own ~/.xschem and inherits however many simulators are registered
# there. This row is why SG13 and SG14 above can be trusted -- without it they
# pass on a clean machine and red on a working one, naming nothing.
check "SG22 1377 the farm children resolve a PRIVATE config dir inside this\
 suite's scratch and inherit ZERO registered simulators -- SG13/SG20/SG14's\
 `#! ` counts are about xschem's own startup, never about ~/.xschem" \
  [list [expr {[sg_out_glob $sg_clean "SG-CONF=$sg_home*"] ? 1 : 0}] \
        [sg_out_count $sg_clean {SG-SIMS=0}]] \
  [list 1 1]
```

**Check-count consequence, which MUST be recorded when it lands:**
**22 → 23** on the display arm, **17 → 18** headless. Ledgers and receipts through
this batch quote `startup_guard_0663 22`; `doc/claude/op_param_batch/` quotes it nine
times. Nothing *asserts* on the number (`/usr/bin/grep '22 checks' tests/headless/*.sh`
→ silence; `AUDIT_MIN_PASS` counts **suites**, not checks), so nothing reds — but the
next reader comparing counts will see a delta and must be told why.

If the crew prefers a zero-new-rows landing, A-1 and A-2 alone green the suite. I do
not recommend it: the untested isolation is how this comes back.

## A2.5 — Red-first plan, on a box that HAS the three dead entries

**This box has them right now** (`~/.xschem/ase_simulators`, mtime 2026-09-14 00:22),
so no fixture is needed. Measured today, read-only, with `[ -e ]` / `[ -f ]` / `[ -x ]`:

| entry | path | state | `ase::sim_check` verdict |
|---|---|---|---|
| `ng-cm3` | `…/xschem-claude/src/xschem` | FILE, EXEC | **`iseditor`** — guard 5, `ase::sim_is_editor` compares against the child's own `[info nameofexecutable]`, which `share_farm_child` sets to the **same binary** (`sharefarm.tcl:87`) |
| `stub` | `/tmp/stage11/e2e/bin/sim` | **MISSING** | **`missing`** |
| `realsim` | `…/ngspice/build-ver_50/src/ngspice` | FILE, EXEC | clean |
| `eebin` | `/usr/bin/ngspice` | FILE, EXEC | clean |
| `slowstub` | `/tmp/stage11/kp/bin/slowsim` | **MISSING** | **`missing`** |
| — | `ase::sim_select ng-cm3` (last line) | — | says nothing: `ase::sim_select` (`src/ase.tcl:2010-2030`) has **no** `sim_say` on the success path — verified by reading |

**→ exactly 3 reported entries → 3 `#! ` lines per child that reaches `:19929`.**

### The falsifiable prediction

**RED, before the fix** (either arm):
```
FAIL: SG13 0663 R6 hard form: ... -> {3} (exp {0}) : FAIL
FAIL: SG14 0663 the 0658 CONTROL: ... -> {0 1 1 0 4} (exp {0 1 1 0 1}) : FAIL
RESULT: 2 FAILED (20 passed)          # display arm; headless: 2 FAILED (15 passed)
```
**GREEN, after:** `RESULT: ALL PASS (23 checks)` / `ALL PASS (18 checks)` headless.

**If the observed numbers are not 3 and 4, my mechanism is wrong somewhere and the
receipt must say so** — the *identity* of the two rows would still stand (nothing
else counts `#! ` totals), but the chain in §A2.2 would need re-walking. **Report the
actual numbers, do not round them into "2 failed".**

### The procedure

1. **Back up first, touch nothing:** `cp -p ~/.xschem/ase_simulators <scratch>/`.
   **⚠ The suite must never write, rename or prune that file** — that is the whole
   of ⚖ R2 and of `scratch.tcl:148-153`.
2. Rebuild (`make -C src`) — brief rule 6 — then run **both arms** before the edit:
   `tests/headless/devdisplay.sh exec ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_startup_guard_0663.tcl`
   and the `--pipe -q` GUI arm. Quote the two FAIL lines verbatim.
3. Apply A-1/A-2/A-3. Re-run both arms. Quote `ALL PASS`.
4. **Sabotage (the non-vacuity proof):** comment out the two `set ::env(HOME)` lines
   in `sg_run` and re-run — SG13, SG14 **and SG22** must all redden. Restore.
5. **Positive control for a clean machine**, so the fix is not accidentally a no-op
   on a developer box with an empty registry: run once with
   `HOME=<empty dir> ./src/xschem … --script …` **before** the edit and confirm
   `ALL PASS` — that is the driver's *"with a clean HOME the suite is ALL PASS"*
   claim, which I could not execute and is **taken on trust**.
6. Confirm `~/.xschem/ase_simulators` is byte-identical to the backup afterwards
   (`cmp`), and that `<scratch>` is gone.

### T1 is unaffected, confirmed by reading

`/usr/bin/grep -n 'startup_guard' tests/run_regression.tcl` → **silence**. The suite is
in neither `hcases` (`:27-93`) nor `dcases` (`:309-318`). **T1's zero is untouched
either way.** `full_audit.sh` picks it up through `ls "$HERE"/test_*.tcl` (`:427`),
which is the audit being repaired. *(F4's receipt records the same grep result
independently — two derivations, same answer.)*

---

# TASK B — ⚖ R3: `C11` becomes a delta, paired with the containment

## B3.1 — what 0609 supplies, and whether it is still correct

**What it supplies:** the `h_pre` snapshot / `<=` count comparison quoted in §3
above. **Verdict: partial — see correction 3.** Use the amended shape in §B4.

**Its citations, ALL re-measured by me today** rather than inherited from H1's pass:

| 0609 says | measured today | |
|---|---|---|
| `actions.c:208` → `write_backup()` | `:208` is `if((mod == 1 \|\| mod == 3) && !ro_suppress) write_backup();` | ✓ |
| `save.c:6139-6161` `write_backup()` | `:6139` is `void write_backup(void)` | ✓ |
| `save.c:6146` `autosave_backup` early return | `:6146` is `if(!tclgetboolvar("autosave_backup")) return;` | ✓ |
| `save.c:6149-6152` untitled backed up on purpose | the 0060 comment, verbatim | ✓ |
| `save.c:6154` the `fopen(bak, "w")` | `if(!(fd = fopen(bak, "w")))` | ✓ |
| `xinit.c:3917-3919` env(PWD) preferred | `:3918` `if(tcleval("info exists env(PWD)")[0] == '1')`, `:3919` the `my_snprintf` | ✓ |
| `xinit.c:3175` startup `getcwd` | `if(!getcwd(pwd_dir, PATH_MAX))` | ✓ |
| `xinit.c:174` a `cd` moves neither | the 0323 comment | ✓ |
| `test_ase_core.tcl:1531`, `:460` | exact | ✓ |
| `test_op_dump_altshow.tcl:939-941` | exact | ✓ |
| `full_audit.sh:64` `cd "$REPO"` | `cd "$REPO" \|\| exit 2` | ✓ |

**H1's corrections hold — all eleven.** I found nothing new wrong in 0609.

**⚠ But TWO TEST FILES carry the same stale citations H1 fixed in 0609, and nobody
has flagged them.** This is the F2/F3/F4 citation class, still live:

* **`tests/headless/test_no_untitled_litter.tcl`** — its header and `run_child`
  comment cite `save.c:4508-4511`, `save.c:4149`, `save.c:4156`, `save.c:4159-4162`,
  `save.c:4175-4182`, `xinit.c:2952`, `xinit.c:3690-3693`, `actions.c:4639-4652`,
  `actions.c:4618`. **Nine sites, all ~1 200–2 000 lines stale.** (`actions.c:208`,
  `xinit.c:174` and `full_audit.sh:64` in the same header are correct.)
* **`tests/headless/test_ase_core.tcl:1516`** says `write_backup() (actions.c:207)`
  — off by one; it is **`:208`**.

Both are *comments*, so nothing reds. `test_ase_core.tcl:1516` is inside the block
being edited anyway and should be corrected in the same hunk.

## B3.2 — `C11`, quoted exactly

```tcl
1531:check "C11 no untitled~.sch was dropped in the repo root (issue 0609)" \
1532:  [file exists [file join $repo untitled~.sch]] 0
```
with `$repo` at **`:460`**: `set repo [file normalize [file join $here .. ..]]`,
`$here` at `:459` from `[info script]`.

**The driver's characterisation is CONFIRMED.** A raw existence test, expecting 0,
on a path derived from the script's own location — so it reds on any repo-root
`untitled~.sch` regardless of producer. Note it globs **only `untitled~.sch`**, while
0609 §3's own correction records an `untitled~.sym` in the repo root; the delta
should glob `untitled*` (the shape `test_op_dump_altshow`'s H1 already uses).

## B3.3 — G1's decisive measurement: **VERIFIED, it holds**

I re-derived it from source rather than inheriting it, and every leg checks out:

| leg | evidence |
|---|---|
| `$repo` is cwd-**independent** | `test_ase_core.tcl:459-460`, from `[info script]` |
| T1 never `cd`s | `/usr/bin/grep -n '^[[:space:]]*cd \|env(PWD)' tests/run_regression.tcl` → **silence** |
| T1 passes the script **relatively** | `:619` `[list $xschem_cmd --nogui --pipe -q --script ${hc}.tcl]` |
| so T1's cwd is `tests/` | forced by CLAUDE.md's invocation `cd tests && tclsh run_regression.tcl`; run any other way the driver exits 1 |
| the child inherits `env(PWD)` = the shell's cwd | `PWD` is exported by bash (verified: `env \| grep ^PWD=`), and Tcl `exec` passes `::env` |
| xschem prefers `env(PWD)` for `pwd_dir` | `xinit.c:3918-3919` over `:3175` |
| `test_ase_core` never `cd`s | `/usr/bin/grep -n '^[[:space:]]*cd ' tests/headless/test_ase_core.tcl` → **silence** |

**→ under T1 the suite's own leak would land in `tests/`, which `C11` does not read.
G1's claim stands: under T1, `C11` cannot catch its own leak at all.** It is
simultaneously over-sensitive (foreign litter) and blind (its own). Two of its three
contexts are wrong.

## B3.4 — THE RECOMMENDED EDIT for `C11`

### Edit B-1 — `tests/headless/test_ase_core.tcl`, insert after line 461

```tcl
## C11's BASELINE (issues 0609 and 1480 §5). C11 was a raw existence test on the
## repo root, which made it a probe of FOREIGN machine state -- red in 13 of 13
## recorded full_audit runs because some OTHER suite littered the root first --
## and SIMULTANEOUSLY BLIND under T1, whose cwd is tests/ while :460 resolves the
## repo root from [info script]. A delta fixes both directions at once.
##
## ⚠ BOTH DIRECTORIES, AND THAT IS THE HALF 0609'S OWN FIX CODE MISSES. xschem
## names the untitled buffer under `pwd_dir`, which is $env(PWD) when set and the
## startup getcwd otherwise (src/xinit.c:3917-3919 over :3175; a Tcl `cd` moves
## neither, :174). So THIS suite's own leak lands in the CWD -- the repo root by
## hand and under full_audit.sh (:64 `cd "$REPO"`), tests/ under T1, and a
## per-case directory under any future containment. Watching $repo alone keeps
## the row blind in exactly the context it runs in most.
proc c11_litter_dirs {} {
  global repo
  set here [expr {[info exists ::env(PWD)] && $::env(PWD) ne {} \
                    ? $::env(PWD) : [pwd]}]
  set ds [list [file normalize $repo]]
  set n  [file normalize $here]
  if {$n ne [lindex $ds 0]} { lappend ds $n }
  return $ds
}
proc c11_litter_snap {} {
  set out {}
  foreach d [c11_litter_dirs] {
    foreach f [glob -nocomplain -directory $d -tails untitled*] {
      lappend out [file join $d $f]
    }
  }
  return [lsort $out]
}
set c11_pre [c11_litter_snap]
```

**Why the snapshot goes at suite start and not beside the row:** 0609 asks for
"snapshot at suite START", and it is the right call — it keeps the row's real
meaning ("did *this suite* leak?") across the ~1 070 lines that run before `:1531`.
Taking it at `:1519` instead would narrow the row to the three parked statements and
throw away most of its value. The residual risk — a *concurrent* process littering
the root mid-suite — is a far smaller window than "ever", and is the kind of thing
this batch's own lock work exists to prevent.

### Edit B-2 — replace `:1531-1532`

**BEFORE:**
```tcl
check "C11 no untitled~.sch was dropped in the repo root (issue 0609)" \
  [file exists [file join $repo untitled~.sch]] 0
```

**AFTER:**
```tcl
## ⚠ A SET DIFFERENCE, NOT A COUNT. 0609's suggested shape compares LENGTHS
## (`<= [llength $h_pre]`), which scores a run that removed `untitled~.sym` and
## added `untitled~.sch` as perfectly clean -- and 0609 §3 is itself the recorded
## correction that BOTH extensions occur. What is asserted is that this suite
## added NOTHING, so the new NAMES are the answer, and a failure prints them.
set c11_new {}
foreach f [c11_litter_snap] {
  if {[lsearch -exact $c11_pre $f] < 0} { lappend c11_new $f }
}
check "C11 this suite added no untitled* to the repo root or to its own working\
 directory (issue 0609 -- a DELTA, not an existence test: it must not red on\
 litter another suite left before this one started, and it must still catch its\
 own)" \
  $c11_new {}
```

Also, in the same hunk, correct `:1516`'s `actions.c:207` → **`actions.c:208`**.

`check` (`:449`) compares `$got eq $exp`, so an empty list passes and a leak prints
the offending paths in the FAIL line — strictly more diagnostic than today's `{1}`.

### Edit B-3 — the twin, `tests/headless/test_op_dump_altshow.tcl:939-941`

Same defect, same fix, and 0609 §2.1 names them as a pair. That suite is **not** in
T1 (`/usr/bin/grep -n 'op_dump_altshow' tests/run_regression.tcl` → silence), so it
carries no T1 risk; it is in the audit. Its H1 already restores cwd and already globs
`untitled*`, so only the "compare against a start snapshot" half is missing. Land it
in the same commit or say why not.

### What the delta does and does not change

| context | today | with the delta |
|---|---|---|
| by hand from the repo root | catches its own leak ✓ | unchanged ✓ |
| inside `full_audit.sh` | **false red, 13/13** ✗ | green, and still catches its own ✓ |
| inside **T1** (cwd `tests/`) | blind to its own ✗ | **catches its own, in `tests/`** ✓ |
| under a future containment | would be blind ✗ | catches its own, in the per-case dir ✓ |

**It can still red**, which is what keeps it honest: remove the
`set ::autosave_backup 0` park at `:1520-1530` and the row must fire. That is the
sabotage.

## B3.5 — the pairing constraint, and what the containment must do instead

### Would 0609's containment red every T1 run? **Only if it picks `$REPO`.**

Read against `run_regression.tcl`: the driver has **no `cd` and no `env(PWD)`
assignment anywhere** (measured, silence). If a containment set the child cwd/PWD to
`$REPO`, then on the first unguarded case the `untitled~.sch` would land in the repo
root, and `C11` — a raw existence test at that moment — would fire **in the one suite
whose baseline is ZERO**, on every run. **63 of T1's 69 headless cases carry no
`autosave_backup` guard** (H1's static census), so "the first unguarded case" is the
first case.

**With the delta in place, the choice of directory stops mattering to `C11`.** That is
the whole point of landing the delta first.

### The containment's four hard constraints

1. **It must set `$env(PWD)`, not merely `cd`.** Measured twice in this tree:
   0609's guardian run read its own positive control as "no litter", and
   `test_no_untitled_litter.tcl:86-108` carries the warning over its own `run_child`
   (*"`cd` ALONE DOES NOT ISOLATE THE CHILD"*). `run_child` (`:97-108`) is the proven
   recipe — `cd` **and** `set ::env(PWD)`, both restored.
2. **It must not be `$REPO`** — and with the delta, must not be any directory `C11`
   reads, which now includes the child's own cwd. The right answer is a directory
   *per run* that nothing else looks at.
3. **It must not move the DRIVER's own cwd.** `tcases` (`create_save`, `open_close`,
   `netlisting`) resolve `$testname/results` relative to `tests/`, `summarize_all`
   reads `${hc}.log` relatively, and `test_utility.tcl:36-50` absolutises
   `$xschem_cmd` precisely because jobs `cd` elsewhere. Enter and leave around the
   child `exec` only.
4. **It must not disturb four source-text rows that read this driver's text**:
   * `test_suite_watchdog_1403.tcl` **W15a** (≥4 uses of `$t1_pre`), **W15b**,
     **W15c** ×4 (`rr_cmdline` finds `set <var> [concat`, and `$t1_pre` must precede
     `[list $xschem_cmd --nogui` / `--pipe` / `tclsh`), **W16a** (`$dd exec …$t1_pre`
     on the `dccmd` line);
   * `test_op_annot.tcl` **V57** (`:14247-14287`): the single line in the `dcases`
     loop containing `$xschem_cmd` must also contain `(devdisplay\.sh|\$dd)\s+exec`
     **and** `--logdir`, **on that one line**, and the loop must contain no
     `--nogui`. `run_regression.tcl:683-689` warns in as many words: *"do not
     re-wrap it."*

   **All four survive the design below**, because the command-building lines keep
   their shape and only their *path arguments* become absolute.

### The recommended containment (design; implementation is a later task)

```tcl
## near the top, once:
set t1_tests  [file normalize [pwd]]                 ;# the driver's own cwd = tests/
set t1_litter [file join $t1_tests _t1litter_[pid]]
file mkdir $t1_litter
proc t1_litter_enter {} { … cd $t1_litter ; set ::env(PWD) $t1_litter … }
proc t1_litter_leave {} { … cd back ; restore or unset ::env(PWD) … }
```

* **`_t1litter_<pid>` is deliberately the house scratch shape.** Measured:
  `git check-ignore -v tests/_t1litter_12345/untitled~.sch` → **`.gitignore:84:_*_[0-9]*/`**,
  so it needs **no new `.gitignore` rule**; and `scratch.tcl`'s dead-pid sweeper
  already sweeps `[file join $repo tests]` for `_*_[0-9]*` (`:68-80`, `:111-113`), so
  a killed run self-heals. No existing `tests/_*` directory collides (`ls` → none).
* In the **hcases** loop (`:616-635`): `${hc}.tcl` → `[file join $t1_tests ${hc}.tcl]`
  inside the existing `[list …]`, `> ${hc}.log` → `> [file join $t1_tests ${hc}.log]`,
  and `t1_litter_enter` / `t1_litter_leave` bracketing the `catch`. `summarize_all`
  stays where it is, at the driver's own cwd.
* In the **dcases** loop (`:667-706`): the same, plus `$dd` made absolute
  (`[file join $t1_tests headless devdisplay.sh]`) since the cwd moves. The `dccmd`
  line stays **one line** and keeps `$dd exec` → `$t1_pre` → `$xschem_cmd --pipe` →
  `--logdir` in that order. `$dlogdir` is already absolute (`:661`).
* **`tcases` and `xschemtest` are deliberately left alone** — constraint 3. They can
  leak too; that is a second, separate task and should be said out loud rather than
  quietly skipped.

**This is a design, not a measurement.** §"What must be measured" lists what would
falsify it.

## B3.6 — the scope boundary, stated plainly

**IN scope, designed here:** `C11`'s delta (+ its twin H1), and the *containment*.

**OUT of scope, and untouched:**

* **1480 §6 item 1, the SWEEP.** It requires deciding **0356** —
  `git status --ignored=matching` versus a `find`-based arm — and that governs what
  the user's own `git status` shows them. **The driver deliberately left it with the
  user; nothing here pre-empts it**, and my containment adds no new `.gitignore` rule
  precisely so that it cannot.
* **1480 §6 item 2**, the driver-side run manifest.
* **1480 §6 item 3**, `write_backup()`'s lying header comment (`save.c:6137-6138`) —
  **re-confirmed by reading today**: the header says untitled buffers are *skipped*,
  the body at `:6149-6152` says the reverse and there is no skip in the code. Source
  change, one comment, no behaviour. Still unfixed.
* The 80-suite leak itself (0609's subject).
* `test_no_untitled_litter.tcl`'s nine stale citations (§B3.1) — reported, not fixed.

---

# What must be MEASURED before any of this is trusted

Everything below is **INFERRED FROM SOURCE**. I executed nothing.

### Task A

| # | claim | how to falsify |
|---|---|---|
| A-i | the two red rows are **SG13** and **SG14** | run the suite on this box, both arms |
| A-ii | the counts are **3** and **`{0 1 1 0 4}`** | read the FAIL lines; any other number means §A2.2's chain is wrong somewhere |
| A-iii | `ase::sim_register` really reports at **startup**, in a child, into the **log** | the child's `Xschem.log` should hold 3 `#! ` lines naming `stub`, `slowstub` and `ng-cm3` |
| A-iv | `iseditor` really fires for `ng-cm3` (the child's own binary) | one of the three lines should be the `is xschem itself` sentence |
| A-v | the registry sentences do **not** reach `-out` | if they do, SG12/SG4/SG5 may move too and the "2" becomes more |
| A-vi | a private `HOME` with a pre-created `.xschem` produces **no** new stderr line | `Created … dir with template xschemrc` must be absent |
| A-vii | nothing else in the child depends on the real HOME | `ALL PASS` on both arms after the edit |
| A-viii | **the driver's "clean HOME → ALL PASS (22)"** | taken entirely on trust; step 5 of the plan re-takes it |
| A-ix | `~/.xschem/ase_simulators` is **byte-identical** afterwards | `cmp` against the backup |

### Task B

| # | claim | how to falsify |
|---|---|---|
| B-i | the delta greens `C11` under `full_audit.sh` | audit with the repo root deliberately pre-littered |
| B-ii | the delta still **reds** on a real leak | remove the `:1520-1530` park; `C11` must fire |
| B-iii | `c11_litter_dirs` returns **two** dirs under T1 and **one** by hand | the `note` idiom, or read the FAIL text |
| B-iv | `test_ase_core` count moves **675 → 675** (no new row) | its `RESULT:` line |
| B-v | the containment does not disturb **W15a/W15b/W15c/W16a/V57** | run `test_suite_watchdog_1403` and `test_op_annot` on both arms |
| B-vi | the five T1 suites using `[pwd]` survive a moved cwd — `test_ase_campaign_1462`, `test_ase_simcaps_0948`, `test_ase_simreg_0931`, `test_ase_variant_1470`, `test_regression_concurrency_1476` | read: most are `set save [pwd]` save/restore, and `simcaps`' K4/K5 rows assert *"nothing was created in my cwd"*, which a per-case cwd should preserve — **but this is inference, not measurement** |
| B-vii | ⚠ **`test_regression_concurrency_1476` copies THIS DRIVER and runs two copies** (`:89-91`, `:417-455`) | a containment edit changes what those copies do; run that suite explicitly |
| B-viii | `env(PWD)` alone would suffice (so `cd` could be dropped) | **do not assume it** — `env(PWD)` also feeds `xctx->current_dirname` (`xinit.c:3740-3744`), which resolves relative paths handed to `xschem load`. Setting them apart is a split brain. Use both, as `run_child` does |
| B-ix | a per-run litter dir is swept/ignored | `git check-ignore` ✓ measured; the sweep is inferred from `scratch.tcl:68-80,111-113` |
| B-x | **T1 is at zero before and after** | solo T1, per CLAUDE.md's reading rules |

---

# Claims checked vs taken on trust

**Checked, first-hand, today (read-only).** Every `check` in
`test_startup_guard_0663.tcl` and what each one counts, read in full; that only
SG13/SG14/SG20 count `#! ` **totals** and that SG20's child dies above `:19929`; the
twelve-hop registry→`#! ` chain, every hop opened; **`init_action_log()` at
`main.c:103` before `Tcl_AppInit`**, the fact the whole hypothesis rests on;
`xschem::notify`'s sinks and the **absence of a stderr sink**; `ase::sim_check`'s five
guards and `ase::sim_why`'s kinds; that `ase::sim_select` says nothing on success;
the live contents of `~/.xschem/ase_simulators` and the **existence/type/exec bit of
all five registered paths**; the HOME→`USER_CONF_DIR` chain in C and the
`config.h:46` macro; the conf-dir `mkdir`+template-copy at `xinit.c:3437-3446`; that
`share_farm_child` passes `::env` and restores only `XSCHEM_SHAREDIR`; its **three**
callers and their call counts; the existing child-HOME idiom in
`test_ase_simdlg_0937` and `test_ase_simreg_0931`; that `scratch.tcl` does **not**
redirect `USER_CONF_DIR` and that `test_sim_registry_isolate` is memory-only; the
scratch.tcl consumer counts **four different ways**; that `test_startup_guard_0663`
is **absent** from T1 and present in `full_audit.sh`'s glob, and which audit arm it
lands on; `C11` and `$repo` verbatim with line numbers; that `test_ase_core` and
`run_regression.tcl` contain **no `cd`** and **no `env(PWD)`**; T1's relative script
path; that `PWD` is exported by the invoking shell; **all eleven of 0609's citations
against today's `save.c`/`xinit.c`/`actions.c`/`full_audit.sh`**; the
`write_backup()` header/body contradiction, read in full; `test_op_dump_altshow`'s H1;
`test_no_untitled_litter.tcl` end to end, including its nine stale citations and its
`run_child` recipe; W14–W19 and V57's exact predicates; the 1476 suite's source-text
rows and its driver-copy mechanics; `.gitignore` coverage of `_t1litter_<pid>` via
**`git check-ignore -v`**; that no `tests/_*` directory exists today; and that nothing
in `tests/` asserts on either suite's check count.

**Taken on trust, named as such.**
1. **The driver's "2 of 22" and "clean HOME → ALL PASS (22 checks)"** — I could not
   execute. My reading *predicts* 2, names them, and predicts the numbers; that is
   agreement by derivation, not confirmation.
2. **0609's "80 of 116 suites"** (2026-08-22) and the **13-of-13** red audits.
3. **G1's byte-exact reproduction, the `cmp`, and the two `_badig_` pids** — the
   files are deleted; not re-measurable.
4. **H1's account** of what it changed in 0609 (I re-verified the *citations*, not
   the diff).
5. **T1's 84-case / zero baseline** — not mine, and nothing here re-takes it.
6. That the **other crew's** suite run did not perturb anything I read. I ran nothing,
   so no number of mine can have been contended.

**Refuted / corrected by me:** DECISIONS.md's *"neither ships alone"* (half wrong);
DECISIONS.md's *"0609's containment pins T1's cwd to `$REPO`"* (0609 names no
directory); DECISIONS.md's *"`scratch.tcl` reaches 169 suites"* (187 suites / 193
sourcers / 195 mentions — the argument survives, the number does not); and **0609's
own fix code**, which is count-based and single-directory (correction 3).

---

# Corrections to PLAN.md

None — `PLAN.md` stops at stage E3 and does not cover R2/R3. The corrections above are
to **`DECISIONS.md`** (three) and to **0609** (its fix code). The driver should fold
correction 1 into `DECISIONS.md` before the next task is dispatched, because it changes
the *order* the two R3 halves can be built in.

**One scheduling recommendation:** land **R2** and the **C11 delta** as two small
independent commits (neither can red T1 — R2's suite is not in T1, and the delta only
relaxes a row). Treat the **containment** as a separate, larger task with its own
sabotage pass, gated on B-v/B-vi/B-vii. Do not bundle all three.

---

# Left dirty

**Only this receipt**, new and untracked at
`doc/claude/harness_concurrency_batch/receipts/R2-R3-design.md`.

No test file, no source file, no issue file, no `NUMBERING.md`, no `owed.sh`, no
commit. I created no litter of any class: **this task started no process.** The four
pre-batch untracked entries (`.xschem/`, `doc/claude/rdw_lists_batch/`,
`doc/claude/rdw_sim_batch/`, `sky130A/.../debug_st1/`) are as the driver left them.

---

# Owed to the user

**Nothing new, and nothing cleared.** I did not touch `owed.sh` (brief rule 8) and did
not read the ledger.

No pixels, no user-visible behaviour, no GUI, no UI copy. Both builds are internal
test-harness engineering — which is exactly the driver's stated reason for taking R2
and R3 off the user's queue, and nothing I found disturbs that judgement.

⚠ **One thing the driver should weigh, because it is a decision and not a finding:**
the containment (§B3.5) is adjacent to **0356**, which the driver has deliberately
left with the user. My design stays clear of it — it adds **no `.gitignore` rule** and
**no sweep**, reusing the existing `_*_[0-9]*/` shape precisely so that 0356's open
question is not pre-empted. If a future task widens it into a sweep, that crosses into
0356 and becomes the user's call again.
