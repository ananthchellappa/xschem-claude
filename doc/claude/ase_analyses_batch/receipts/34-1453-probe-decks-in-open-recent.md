# Issue 1453 — ASE-L's capability probe took over the user's `File > Open Recent`

**Crew:** the 1453 task crew · **Date:** 2026-09-13 · **Branch:** `fluid-editing`
**HEAD when this started:** `2f67787b` *fix(1456): T1 has not been at zero since stage 7…*
**Files I own and touched:** `src/ase.tcl`, `tests/headless/test_ase_simcaps_0948.tcl`,
`doc/claude/issues/1453-ase-l-probe-decks-took-over-the-users-open-recent.md`, this receipt.
**Nothing committed, staged, stashed, restored, cleaned or pushed.**

---

## ⚠ THE HEADLINE: THE WRITER IS NOT THIS PROCESS, AND BOTH EARLIER DRAFTS HUNTED IT HERE

The brief was right to refuse the guessed mechanism, and the true one is one step further out
than either draft reached.

**The probing xschem never calls the recorder at all.** The writer is a **second xschem
process that ASE-L's capability probe `exec`s** — because the user's registered "simulator"
is the **xschem binary itself**:

```
$ cat ~/.xschem/ase_simulators
ase::sim_register ng-cm3 /home/analog/dev/xschem-claude/src/xschem -args {} -backend {} -casemode {} -nospiceinit 1
ase::sim_select ng-cm3
```

`ase::cap_run` builds `timeout <secs> <program> -b <deck>`. `-b` is ngspice's *batch*; in
`src/options.c` it is xschem's **`--detach`**, and `<deck>` is then a bare filename argument →
`cli_opt_filename` → `src/xinit.c`'s `tcl_call("update_recent_file", fname, NULL, NULL)`, **in
a child carrying no `--nogui`, no `--pipe` and no `--norecent`**. `no_recent_files` is 0 in
*that* process, so it rewrites `$USER_CONF_DIR/recent_files` with the probe deck and exits.

**The 0119 gate is behaving exactly as designed in both processes.** A fix that touched it
would have been a worse defect than the one being repaired. Row **XE11** exists to keep that
true for the next person.

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

**MEASURED by me, on this box, today:**

| | |
|---|---|
| the instrumented probe run (the writer hunt) | the wrapper logged **zero** calls, the file appeared anyway |
| `ase::sim_check` / `sim_status` / `sim_capabilities_at` behaviour before and after | every XE row |
| the child's behaviour with and without `DISPLAY`, with `-q`, with `--norecent` | four runs, timings below |
| `-b` = `--detach` in `src/options.c:174` | read, then confirmed behaviourally |
| the three extra `update_recent_file` callers in `src/actions.c` | grep; **the brief's list was incomplete** |
| headless arm, 14 suites, before and after | `RESULT:` lines below |
| display arm, 7 suites, after | `RESULT:` lines below |
| six sabotages, each restored by `cp` + md5 | table below |
| **`~/.xschem/recent_files` md5 unchanged across a post-fix display sweep** | the end-to-end proof |

**TRANSCRIBED, not re-measured:** the brief's statement of the standing display-arm baseline
for `test_ase_dialogs` (1 FAILED / 382 passed, `G2sens`, issue 1436) — although my own two
display runs reproduced it exactly, so it is independently confirmed here. `evidence/
binary-differences.md`'s ≈5 ms probe-launch figure is quoted from issue 1453, not re-taken.

---

## The measurement that found the writer, and it wrote nothing

Scratch `HOME`, so nothing of the user's moved. In the probing session `update_recent_file`,
`write_recent_file` and `update_recent_dir` were renamed aside and replaced with wrappers that
log the argument and the whole `info level` stack and **do not call through**. Then a live
probe was driven on the dev display:

```
HOME=/tmp/w1453/home XSCHEM_DEVDISPLAY_DIR=… \
  tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script /tmp/w1453/probe.tcl
```

```
HOME=/tmp/w1453/home
USER_CONF_DIR=/tmp/w1453/home/.xschem
nameofexecutable=/home/analog/dev/xschem-claude/src/xschem
no_recent_files=1
update_recent_files=0
registry: {name ng-cm3 path /home/analog/dev/xschem-claude/src/xschem … ok 1}
sim_status: ok 1 … resolved /home/analog/dev/xschem-claude/src/xschem …
elapsed_ms=30279
caps: known 0 unmeasured timeout secs 31
RESULT: probe driven

$ cat /tmp/w1453/parent.log
start Sun Sep 13 18:44:22 MST 2026          <-- and NOT ONE CALL after it

$ head -1 /tmp/w1453/home/.xschem/recent_files
set recentfile {/tmp/w1453/home/.xschem/simulations/.ase_probe/p3644712_1/probe_a.sp}
```

**The recorder is never reached in this process and the file is written anyway.** `p3644712`
is this process's own pid, taken by `ase::cap_workdir`'s `p[pid]_$cap_seq` — which is what
made it look like a local write for so long.

`elapsed_ms=30279` and `unmeasured timeout` are the second half of the story: the child is an
**editor**, it does not exit, and the probe pays its entire budget and then reports the user's
"simulator" as unmeasurable. Deck A is the only deck that ever runs, which is exactly why the
user's list holds three `probe_a.sp` entries per process number and no `probe_b.sp`.

### The child, four ways, each in its own scratch HOME

| launch | rc | wall | `<HOME>/.xschem/recent_files` |
|---|---|---|---|
| `./src/xschem -b <deck>`, `DISPLAY=:99` | 124 (killed at 15 s) | 15 s | **written** |
| `./src/xschem -b <deck>`, no `DISPLAY` | 124 (killed at 15 s) | 15 s | **written** |
| `./src/xschem -q --nolog -b <deck>` | 0 | **108 ms** | **written** |
| `./src/xschem -q --nolog --norecent -b <deck>` | 0 | 106 ms | absent |

⚠ **The child records with or without a display.** What is display-only is the **parent**:
`test_ase_dialogs` row G13 is a GUI leg, so only the display arm reaches the probe at all.
The brief's "renews on the display arm" is correct; the reason is the parent, not the child.
This is what let rows XE11/XE12 be **headless** rather than display-only.

---

## What shipped — `src/ase.tcl`, two guards

**Option A was recommended against a mechanism that does not exist** (there are no probe
loads to wrap a flag around). What shipped is **option B, aimed at the measured writer**: the
probe stops putting its deck in front of an editor by refusing to start one.

### 1. `ase::sim_check` gains a fifth ordered guard, `iseditor`

```tcl
proc ase::sim_check {path} {
  if {$path eq {}}               { return empty_path }
  if {![file exists $path]}      { return missing }
  if {![file isfile $path]}      { return notfile }
  if {![file executable $path]}  { return notexec }
  if {[ase::sim_is_editor $path]} { return iseditor }
  return {}
}
```

**One guard, every door** — the validator is the single place `ase::sim_register`,
`ase::sim_entry_kind` → `ase::sim_status` (so a **run** refuses), `ase::sim_entry_why` (the
Simulators list's Problem column), `ase::sim_capabilities_path` (the typed-location / Detect
door) and the three casemode readers all go through. **Last on purpose:** a missing path, a
folder and a non-executable are facts about the file the user typed and are what they need to
hear first. Row **XE2** is what keeps it last.

### 2. `ase::sim_is_editor` — identity, not name

Normalised path first; **device+inode** only when the two spellings differ, so a symbolic
link, a hard link and `./src/xschem` are one answer and the ordinary case costs one string
compare. A basename test **was considered and refused**: it buys a false positive (a
simulator somebody named `xschem`) and still misses a second xschem build under another
name. Row **XE3** pins both halves; sabotage **S4** is that wrong shape.

### 3. `ase::sim_why iseditor` — the sentence

### 4. `ase::sim_capabilities_at` refuses at the probe funnel

```tcl
if {[ase::sim_is_editor $resolved]} {
  return [dict create known 0 unmeasured iseditor]
}
```

Placed **before the cache read** and before `ase::cap_workdir`: no folder is made, no deck is
written, no program is started. It answers in the capability vocabulary's own shape, beside
`unmeasured noplace` and `unmeasured timeout`. `ase::cap_report` stays **silent** on the
token deliberately — the sentence about this program belongs to the registry, which is where
the user's gesture was, and every other `known 0` answer is silent too.

### The residual, said out loud rather than papered over

**A DIFFERENT xschem binary is not caught** — `/usr/local/bin/xschem`, an installed copy, a
build in another tree. Telling one apart from a simulator means starting it, which is the
thing being refused. Written into the proc's header and into issue 1453.

---

## ⚖ R9 — the new user-facing sentence, verbatim

**One new string. `ase::sim_why iseditor`:**

```
<path> is xschem itself, not a simulator. It is registered as the simulator named <name>. Starting it would open a second editor that overwrites your own recent files and window settings, so nothing was started. Point this entry at a simulator program such as ngspice.
```

House style checked: terse, no acronym to case (there is none in it), same voice and shape as
the four `sim_why` sentences it sits beside (`$path` … `which you registered as the simulator
named $name` … what to do instead). **Pinned byte for byte by row XE4**, so a silent reword
shows up as a red row. `owed.sh add rule 1453` filed.

**Nothing else new.** No dialog, no menu item, no label.

---

## ⚠ THE SIDE EFFECT THE USER WILL SEE, AND IT IS THE POINT

Their `ng-cm3` entry stays in the registry and is now reported **unrunnable**, with that
sentence, at startup and in the Simulators window. It could never have simulated anything —
it is the editor. **Whether that entry was theirs or a suite's is a question for them**, and
it is in the rule debt: `~/.xschem/ase_simulators` is dated **2026-09-13 02:29** and is
written by xschem itself (issue 0931), so a suite running with a non-scratch `HOME` is a live
possibility (issue 1397's shape).

---

## Both arms, before and after, from the `RESULT:` line

### Headless — `run_suites.sh --nogui`, `SUITE_TIMEOUT=400`

| suite | before | after |
|---|---|---|
| **test_ase_simcaps_0948** | ALL PASS (**199**) | **ALL PASS (211)** ← +12, section XE |
| test_ase_dialogs | ALL PASS (37) | ALL PASS (37) |
| test_ase_simreg_0931 | ALL PASS (117) | ALL PASS (117) |
| test_ase_simdlg_0937 | ALL PASS (5) | ALL PASS (5) |
| test_ase_simchoice_1395 | — | ALL PASS (31) |
| test_ase_core | — | ALL PASS (636) |
| test_ase_preflight | — | ALL PASS (235) |
| test_ase_sod_case | — | ALL PASS (53) |
| test_ase_result_case | — | ALL PASS (31) |
| test_ase_predeck_1439 | — | ALL PASS (78) |
| test_sim_plain_run | — | ALL PASS (54, 0 skipped) |
| test_sim_casemode_registry | — | ALL PASS (43) |
| test_sim_probe | — | ALL PASS (44) |
| test_sim_run_profile | — | ALL PASS (37) |

`RESULT: 14/14 runs passed`. Every run printed a `RESULT:` line; no run is being scored on an
exit code alone.

### Display — `run_suites.sh` on the persistent dev display `:99` (openbox), `GUI_GATE=0`

| suite | before | after |
|---|---|---|
| **test_ase_dialogs** | **1 FAILED (382 passed)** — `G2sens` | **1 FAILED (382 passed)** — `G2sens` |
| test_ase_simcaps_0948 | ALL PASS (199) | **ALL PASS (211)** |
| test_ase_simdlg_0937 | ALL PASS (55) | ALL PASS (55) |
| test_ase_simreg_0931 | ALL PASS (117) | ALL PASS (117) |
| test_ase_simchoice_1395 | — | ALL PASS (31) |
| test_ase_core | — | ALL PASS (636) |
| test_ase_preflight | — | ALL PASS (235) |

**The one red is `G2sens`, issue 1436, standing, and it is a name+status match with the
brief's stated baseline** — value `{1 1 0 1 0 Entry Entry normal}` against expected
`{1 1 0 0 0 Entry Entry normal}`, character for character, before and after. **Not mine, not
moved.**

⚠ **Honest note on the display "before" column.** My first display sweep straddled the first
edit to `src/ase.tcl` — `test_ase_simcaps_0948` ran at its head, the other three after. I say
so rather than presenting it as a clean baseline. What makes the comparison safe anyway is
that `test_ase_dialogs`' number in that run (1 FAILED / 382 passed, `G2sens`) reproduces the
brief's independently-stated baseline exactly, and the headless "before" column above **was**
taken on a pristine tree.

---

## ⚠ THE END-TO-END PROOF, ON THE USER'S OWN MACHINE

`~/.xschem/recent_files` is read-only observation, nothing else.

```
before the pre-fix display sweep   160dfb3078faab246e2e60c8025176a5   4 pids
after  the pre-fix display sweep   703cc9657fcaed3a1573d1ac1b847494   4 pids  <- p3653867 arrived, oldest dropped
after  the POST-fix display sweep  703cc9657fcaed3a1573d1ac1b847494   4 pids  <- BYTE-IDENTICAL
```

The post-fix sweep **includes `test_ase_dialogs`' display arm**, i.e. row G13, i.e. a live
capability probe. **It added nothing.** Before the fix the same sweep added a process number.

---

## ⚠ AND I RENEWED THE POLLUTION WHILE GETTING THERE — the count

Per receipt 33's standing statement, and it is unavoidable: the brief requires the display
arm, and G13 is not my row.

**I added exactly one process number, `p3653867`, three decks**, in the one pre-fix display
sweep. That pushed out the oldest three (`p3536542`) — **which were themselves probe decks**,
so **no file of the user's was lost by me**: the list had already been emptied of their own
work before this task started. It now reads:

```
p3537063_ p3538224_ p3541467_ p3653867_      (ten entries, each listed twice —
                                              `recentfile` and `tctx::recentfile`)
```

**The ten entries are the user's to repair and I did not touch them.** `owed.sh add look
open_recent_1453` is filed. Every other run I made in this task used a **scratch `HOME`**,
including all six sabotage runs and every child launch.

---

## The rows — `tests/headless/test_ase_simcaps_0948.tcl` section XE, floor **199 → 211**

The suite's own `AND RAISED` history paragraph carries the new line, in the same commit.
It was chosen over `test_ase_dialogs` because the subject is **the probe**, not its GUI, and
because this suite is already in T1's `hcases` with both banners.

**Every row asserts the CALL, never the file.** No row reads `~/.xschem/recent_files` — that
would be both a rule violation and a test that depends on the developer's machine. XE8 and
XE10 count `ase::cap_workdir` and `ase::cap_run` through a watcher that renames both **inside
`::ase`** (a proc moved to `::` would resolve `variable cap_seq` against the wrong namespace
and the positive control would be measuring a broken stand-in), so the verdict reads *no
folder was made and nothing was started*.

| row | what it pins |
|---|---|
| XE1 | `sim_check` answers `iseditor` for this program, absolutely and through a symlink, and `{}` for two ordinary programs |
| XE2 | the four filesystem answers are unchanged **and still come first** |
| XE3 | identity, not name: a link to this program → 1; **a different program called `xschem` → 0** |
| XE4 | the sentence, **byte for byte** (⚖ R9) |
| XE5 | registering the editor records the entry **unrunnable** and says why, **once**, as an `error` |
| XE6 | the Simulators list's per-entry reason is the same sentence |
| XE7 | the resolver refuses: `ok 0`, `resolved {}`, the sentence in `why` |
| XE8 | **guard 2 alone** — the funnel answers `known 0` + `unmeasured iseditor`, **0 folders, 0 launches** |
| XE9 | **CONTROL** — an ordinary registered program is **still probed**: folder made, program started ≥2×, answer `known 1` |
| XE10 | the whole route with the editor in force: `known 0`, **0 folders, 0 launches** |
| XE11 | **CONTROL** — a plain launch that names a file **still records it**: the writer is the child, and the user's own opens still work |
| XE12 | the same launch told `--norecent` writes no recent list at all |

⚠ **XE11/XE12 use a throw-away `HOME` inside the suite's scratch directory** and carry the
child's exit status into the answer (`EXECFAIL(<rc>):<out>`) — because `NORECENT` is what
XE12 *expects*, so a broken `exec` would otherwise make the pair green while measuring
nothing. **That is not hypothetical: my first draft of XE11 passed a Tcl list where `exec`
wanted words, and both rows went "green" against a child that never started.** The guard was
added after, and the row count discipline caught it (XE11 red, XE12 "green").

---

## THE SABOTAGE CAMPAIGN — six mutations, acceptance by name+status

One runner at a time, each launched on its own line. Every run in a **scratch `HOME`**, every
restore a `cp` from a pristine snapshot with an **md5 compare printed after every arm** —
`src/ase.tcl` `6c8dc27c…`, `src/xschem.tcl` `87ba1eec…`, the suite `f6b895cd…`, identical
after all six.

| # | mutation | verdict | reddened **by name** |
|---|---|---|---|
| **S1** | **the fix removed** — `sim_check`'s fifth guard deleted | 4 FAILED (207) | XE1, XE5, XE6, XE7 |
| **S2** | guard 2 removed — `sim_capabilities_at`'s funnel refusal deleted | 1 FAILED (210) | **XE8** |
| **S3** | **both** guards removed | 6 FAILED (205) | XE1, XE5, XE6, XE7, XE8, **XE10** |
| **S4** | **the wrong scope** — `sim_is_editor` matches on **basename** instead of identity | 1 FAILED (210) | **XE3** |
| **S5** | **the worse defect** — `update_recent_file` silenced for every caller (`src/xschem.tcl`) | 1 FAILED (210) | **XE11** |
| **S6** | the `iseditor` sentence removed from `sim_why`, guard kept | 1 FAILED (210) | **XE4** |

**S3 is why XE10 is not the only row in the section.** XE10 cannot redden under S1 or S2
alone — either guard on its own stops the launch — so a section built around it would have
passed with half the fix deleted. The split is deliberate and the table is the proof.

### ⚠ S2 REPRODUCED THE USER'S DEFECT INSIDE THE SUITE'S OWN THROW-AWAY HOME

With the funnel guard gone, XE8's direct `sim_capabilities_at` call launched the child, and
the scratch `HOME` came back holding:

```
set recentfile {…/.scratch/_simcaps0948_3670235/simdir/.ase_probe/p3670235_582/probe_a.sp}
```

That is the user's symptom, in miniature, in a directory nobody cares about. It is the
strongest single piece of evidence in this receipt and it cost nothing to obtain.

### The four ways a row fails to fail, answered

* **A fixture that never disagrees** — every extractor row carries its own control: XE1 and
  XE3 each test the yes **and** the no; XE9 is the control for XE8/XE10; XE12 is the control
  for XE11.
* **A TOTAL reader** — the suite's `a_ans` answers `NOPROC` for a missing command and
  `RAISED:<text>` for a raise, so a deleted proc can never satisfy a golden. Used on every
  new row. `a_xe_watch` returns `NOPROC` rather than a count when either spied proc is gone.
* **`--nogui --pipe` exits 0 on a mid-script Tcl error** — every run above printed a
  `RESULT:` line and I checked for it; and the suite's whole body is inside the file's
  `catch`, whose `zzerr` arm prints `FATAL:` and increments `fail`.
* **A hidden dependency on a real simulator** — XE1–XE10 use `/bin/sh` stubs the suite writes
  itself, exactly as the rest of the file does. XE11/XE12 use this tree's own binary, which
  is present by definition.

---

## Testing discipline

* Binary always given a path: `./src/xschem` or `tests/headless/devdisplay.sh exec`. **No
  bare `xschem` anywhere in this task.**
* `--nolog` on every launch, including both child launches inside the suite. **Never
  `--logdir`.**
* Every command under a hard `timeout`; the two long sweeps under `run_suites.sh` with
  `SUITE_TIMEOUT=400`, so a stall would have been a printed `TIMEOUT` verdict.
* **`tests/run_regression.tcl` NOT run** — it is the driver's and it runs solo (issue 0990).
  The suite I raised, `test_ase_simcaps_0948`, is in T1's `hcases` and already carries both
  banners (`RESULT:` **and** a whole-line `OVERALL:`), so no new registration is needed and
  issue 1456's shape is not reopened. **No hard-coded check count exists anywhere for it** —
  `grep 199` over `tests/run_regression.tcl` and `tests/headless/gold/` is empty — so the
  199→211 raise moves nothing but the file's own paragraph.
* **No simulation on any bench under `sky130A/` or `ihp-sg13g2/`.** No new `.tcl` file, so no
  `src/Makefile.in` / `./configure` obligation (issues 0423/0424).
* **Pure Tcl — no rebuild needed, and none was done.** The binary at `src/xschem` is
  2026-09-05 and unchanged; every suite run picks the Tcl up from the tree.
* **The stock-binary rule does not apply**: nothing here emits, reads back or offers anything
  to a simulator. No row starts ngspice, and the change cannot reach a deck. Saying that
  rather than testing twice, per the brief.
* Nothing `git checkout --`/`restore`/`stash`/`clean`'d. Nothing `pkill`ed that I did not
  start (two of my own child launches, by their full command line).

---

## Corrections to the brief, and to the issue

1. **⚠ The brief's instrument was aimed at the wrong process, and following it literally
   would have found nothing.** *"rename `update_recent_file` aside, install a wrapper … then
   drive G13's path"* — I did exactly that, and **the wrapper logged zero calls while the
   file was written**. That negative result is what identified the writer, so the instrument
   was right and its stated expectation (*"the caller then names itself"*) was wrong. The
   brief's own hedge — *"If `update_recent_file` turns out not to be the writer at all"* —
   is the clause that mattered, and the answer is that it **is** the writer, in a **different
   process**.
2. **The issue's C-caller list is incomplete.** It names `src/scheduler.c` (4 sites) and
   `src/xinit.c:3975`. **`src/actions.c` has three more** — `saveas()` and both arms of
   `ask_new_file()`. None is the writer here; the command-line one is. Corrected in the
   issue.
3. **Option A is refuted, not merely unchosen.** It presumes probe loads that do not exist.
   Option **B** is what shipped; option **C** is refused on a second ground the issue does not
   give — passing `--norecent` would put one program's command-line spelling into ASE-L's own
   source, against D34–D36, **and** it would silence the symptom while a second editor still
   started, taking the user's `geometry` with it (measured: the scratch `HOME` of the
   instrumented run came back holding `ase_simulators`, **`geometry`**, `recent_files` and
   `simulations/` — `geometry` is written by that child too).
4. **"Renews whenever the display arm runs" is right; the stated reason is not.** The child
   records **with or without a `DISPLAY`** — measured both ways. What is display-only is the
   **parent**, because G13 is a GUI leg. This is what let XE11/XE12 be headless rows.
5. **The brief's "three decks each" is explained, not just observed.** The child is an editor,
   so it never exits; the probe's deck-A run eats the whole budget (`elapsed_ms=30279`,
   `known 0 unmeasured timeout secs 31`) and decks B and C are never reached. Three
   *workdirs* per session, one recorded deck each — which is why every entry is `probe_a.sp`.
6. **The ledger counts in the brief were current.** 170 rule / 63 look / 10 suite before;
   **170 rule / 64 look / 10 suite** after — `rule/1453` already existed (the driver's) and
   was **updated**, not created. Backup taken first (`cp -a ~/.claude/xschem_owed
   /tmp/w1453/owed_backup`), and `cleared.log` holds the full pre-image of the overwrite,
   stamped `repo:/home/analog/dev/xschem-claude`. The four unstamped entries were left alone.

---

## Debts

| kind | id | why |
|---|---|---|
| **rule** | `1453` (**updated**, the driver's text kept and extended) | (a) the ten dead entries — the repair of the user's list is theirs; (b) **the new `iseditor` sentence**, quoted verbatim above; (c) whether the `ng-cm3` registry entry pointing at `src/xschem` was theirs or a suite's |
| **look** | `open_recent_1453` | `File > Open Recent` holds ten dead probe decks. The cause is fixed; the list is theirs to clear and nothing in this tree may touch it. **Suites green, please look.** |
| **suite** | `test_ase_simdlg_0937` (**updated**) | the new sentence appears in the Simulators window's Problem column. Verified on `:99` only; CLAUDE.md asks for one `:0` run before a GUI feature is called done |

Counts: **170 / 63 / 10 → 170 / 64 / 10.**

---

## For the driver

* **The fix is `src/ase.tcl` only** — four edits, all in the simulator-registry section
  (`ase::sim_is_editor` new, `ase::sim_check`'s fifth guard, `ase::sim_why`'s `iseditor` arm,
  `ase::sim_capabilities_at`'s funnel refusal). `src/ase_window.tcl` is **untouched**.
* **The suite is `tests/headless/test_ase_simcaps_0948.tcl`**, floor 199 → 211, its own
  history paragraph updated in the same change. Already in T1 `hcases`, both banners present.
* **T1 is yours and I did not run it.** The one suite of mine that T1 runs went 199 → 211
  ALL PASS on both arms; nothing else moved.
* **A commit message in the tree's voice:**
  `fix(1453): ASE-L started the editor as a simulator, and the child took over the user's Open Recent`
* **One thing worth raising with the user, once, when R9 is raised:** their registered
  simulator is the xschem binary. Either they typed it, or a suite wrote it into
  `~/.xschem/ase_simulators` with a non-scratch `HOME` (issue 1397's shape). The second
  possibility is worth a look regardless of the answer, because it would mean something is
  still writing the user's registry.
