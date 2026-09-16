# ⚖ R9 ruling A1 — the shouted words, the arithmetic in the labels, and the two exceptions

**One task from the driver: implement the user's ruling A1**, recorded in the `## A1` section of
`R9_COPY_REVIEW.md`. Files touched, and nothing else: `src/ase.tcl`, five suites
(`test_ase_dialogs`, `test_ase_effective_1442`, `test_ase_preflight`, `test_ase_optsheet_1441`,
`test_ase_core`), `R9_COPY_REVIEW.md`, and this receipt.

⚠ **`src/ase_window.tcl` IS NOT MODIFIED** — md5 `b38be6df…` before and after. The prefix it
composes is one the ruling **kept**, so the only new thing pointed at it is a row that *reads* its
body. No C. No new `.tcl` file, so no `src/Makefile.in` / `./configure` obligation.

HEAD was `89677ac5` at hand-over and is `89677ac5` now. **No commit, no `git add`, no
stash/restore/checkout/clean/push.** `tests/run_regression.tcl` **NOT run** — the driver's, solo.
`owed.sh count` is **187 rule, 70 look, 11 suite** before and after: **no `rule` debt added** (this
*is* the ruling being implemented) and **none cleared** (rule and look debts clear only when the
user says so). The ledger was never written, so no backup was needed.

**104 of 104** tracked `.state` files round-trip byte-identically — `bad` empty, **both controls 1**,
driven as a **proc** (`ase_state_roundtrip`), not by running `state_roundtrip.tcl` as a script.

---

## ⚠ THE HEADLINE: IMPLEMENTING THE RULING EXPOSED THE DEFECT IT WAS ABOUT, ONE LAYER DOWN

A1 part 1 moves the points arithmetic out of the field labels and into the caution beneath the form,
**on the user's stated condition that each form's caution state its OWN rule** — because `ac`/`sp`
said *"(2 gives ONE point)"* while `noise` said *"(1 gives ONE point)"*, and a user who opened both
in one session read a typo rather than two correct counts.

**The caution it was to move into was already the shared sentence the ruling forbids.** One
predicate, `lin_points`, fired on `lin 2` for **four** types and said *"a linear sweep of 2 points
yields ONE point"* to all of them. Re-measured 2026-09-15 on **both binaries**, identically:

| | `lin 1` | `lin 2` | `lin 3` | `lin 4` |
|---|---|---|---|---|
| `ac` (and `sp`) | 1 | **1** ← collapses | 3 | — |
| `noise` | **1**, and `$plots` is `const noise1` — **the Integrated Noise plot is not created at all** | 2 | 3 | 4 |
| `disto` | 3 | **4** | 5 | 6 — it never collapses |

So the sentence was **measured false on `noise` and on `disto`**, and the real `noise` hazard — at
**one** point, where a whole plot goes missing — was stated *only* by the field label A1 removes.
Deleting the label without giving `noise` its own arm would have deleted the warning.

What ships: `noise` gets its own arm firing at 1 and naming the lost plot; `disto` no longer declares
the precondition at all; `ac`/`sp` keep the (true) sentence with `ONE` lowercased. The predicate is
still written **over the fields, not over a type list**, so `sp` keeps its inherited coverage, and
the comment now warns that a new type whose linear count differs needs an arm of its own rather than
this need and a sentence nobody measured for it.

---

## What changed, by handle

| handle | was | now |
|---|---|---|
| `R9-011` (ac), `R9-051` (noise), and `sp`'s identical literal | `Number of points (2 / 1 gives ONE point)` | `Number of points` |
| `R9-030` (rendered) | `Number of points (2 gives ONE point):` | `Number of points:` — **the trailing colon is `form_label`'s and is kept** |
| `R9-118` | `measures a VOLTAGE` | `measures a voltage` |
| `R9-138` | `(phase is in DEGREES)` | `(phase is in degrees)` |
| `R9-078` | `` `set ase_preflight 0` does NOT disable this check.`` | `` `set ase_preflight 0` leaves this check in force.`` — **positive rewrite, in all FOUR places the fragment is said** |
| `R9-171` | `set for the $atype analysis and NOT put back afterwards -- [why], so it stays in force…` | `set for the $atype analysis and left in force for every analysis after it -- [why]` — the negated clause is **gone**, not lowercased |
| `R9-153` | `yields ONE point` | `yields one point`, **plus a `noise` arm of the same predicate** |
| ✅ `R9-135` | `ngspice SEGFAULTS` | **unchanged** |
| ✅ `R9-190`, `R9-212`–`R9-221` | `NOT OFFERED:` / `NOT MEASURED:` | **unchanged, all eleven** |

⚠ **`R9-078`'s fragment is shared by FOUR refusals inside `ase::preflight_gate`, and all four
changed together.** Lowercasing one and leaving three would have re-created, inside a single
procedure, exactly the drift §A1 exists to delete. `PF234b` asserts the count is 4 *and* that the old
spelling is 0.

**No handle was added and none renumbered.** 726 distinct handles at HEAD and 726 now (the 727th
line matching `^**R9-` is a prose range header, `**R9-294 … R9-372 are consumed unchanged**`, not a
handle). The document's *"726 strings, from 38 issues"* claim is intact.

---

## The exceptions are pinned by rows, which was the most important part of the task

A1 deliberately leaves the interface **looking** inconsistent: four sentences lose their capitals
while one word and eleven row prefixes keep theirs. The distinction is *structural* — outcome and
prefix versus emphasis — and structural distinctions are the ones a later reader does not notice.

| row | suite | reds if |
|---|---|---|
| `PF234a` | preflight | `SEGFAULTS` is lowercased **or** a second word is shouted beside it (the term is the *set* of all-caps runs, `{SEGFAULTS}`) |
| `HK4` | optsheet | `NOT OFFERED:` / `SET ELSEWHERE:` / `CLAMPED:` / `SCOPED:` lose their capitals in `optsheet_detail` |
| `HK5` | optsheet | any of the **ten** `NOT MEASURED:` catalogue reasons loses its prefix — the count is the non-vacuity half |
| `PF234b` | preflight | any of the four gate sentences reverts to the shouted `NOT` |
| `PF234c` | preflight | `degrees` is re-shouted |
| `PF230b` | preflight | `voltage` is re-shouted (moved row: a new term asserts nothing in the clause is shouted) |
| `G2e2` | dialogs (disp) | any of the four `lin` labels regains a number or a shouted word |

⚠ **`SEGFAULTS` turns out to have two guards, not one.** Sabotage S6 reddened the pre-existing
`PF230h` as well as the new `PF234a` — `PF230h` matched `*SEGFAULT*` case-sensitively all along and
was pinning the capitals by accident. `PF234a` is the one that says *why*.

---

## Suites — name diff on BOTH arms

Row names **gained** and **lost**, not counts alone. `nogui` = `./src/xschem --nogui --pipe -q
--nolog`; `disp` = `devdisplay.sh exec` on `:99` (Xvfb + openbox 3.6.1).

| suite | before (nogui / disp) | after | rows changed |
|---|---|---|---|
| `test_ase_dialogs` | 37 / 384 passed (385 rows) | 37 / **385** passed (386 rows) | **disp:** `G2e` renamed, **`G2e2` gained**; nogui 0 |
| `test_ase_effective_1442` | 94 / 94 | **97 / 97** | **`RU6c` `RU6d` `RU6e` gained**, `RU8` renamed |
| `test_ase_preflight` | 235 / 235 | **238 / 238** | **`PF234a` `PF234b` `PF234c` gained** |
| `test_ase_optsheet_1441` | 62 / 87 | **64 / 89** | **`HK4` `HK5` gained** |
| `test_ase_core` | 652 / 652 | 652 / 652 | none — comment only |

⚠ **TWO MOVED ROWS CANNOT APPEAR IN A NAME DIFF**, because their content changed and their names did
not: **`PF230b`** (its `VOLTAGE` term) and **`G2g`** (its golden). Sabotage arms **S9** and **S1** are
what prove those moved. A name diff alone would have reported them as untouched.

⚠ **`test_ase_dialogs`' display arm carries ONE red before AND after: `G2sens`**, with the identical
actual value `{1 1 0 1 0 Entry Entry normal}` that the file's own header records verbatim. It is
**issue 1436**, filed rather than carried, and it is **not mine** — it is red on the pristine tree in
the same run. T1 runs this file on **neither** arm. Every other row in all five suites is green on
both arms.

**The whole ASE family was swept** to catch a stale golden my registry change might have touched:
**32 `test_ase_*` suites, every one PASS**, except `test_ase_dirty` and `test_ase_log_seam_0207`
which **self-skipped for want of X on the `--nogui` arm** (nothing ran; not a pass).

## Sabotage — eleven arms, every one red by name

Each arm: restore from the finished snapshot → mutate → **verify the md5 MOVED off the finished
value** → run → restore. ⚠ **The md5 check is not decoration**: a `sed` that matched nothing would
read as *"the row did not go red"*, which is a false pass of exactly the shape this batch keeps
meeting. The restore is guaranteed against interruption by an `EXIT INT TERM HUP` trap.

| | sabotage | reds |
|---|---|---|
| S1 | ac label regains its arithmetic | `G2e` `G2e2` `G2g` |
| S2 | noise label regains its arithmetic | `G2e2` |
| S3 | ac caution re-shouts `ONE` | `RU6c` |
| S4 | noise loses its own arm, inherits ac's rule | `RU6d` |
| S5 | disto regains the precondition | `RU6e` `RU8` |
| S6 | `SEGFAULTS` lowercased | `PF234a` **and `PF230h`** |
| S7 | ONE of four gate sentences reverts | `PF234b` |
| S8 | `degrees` re-shouted | `PF234c` |
| S9 | `voltage` re-shouted | `PF230b` |
| S10 | `NOT OFFERED:` lowercased | `HK4` |
| S11 | one `NOT MEASURED:` lowercased | `HK5` |

**Ends on a positive restored-tree row**: all seven files md5-identical to the finished snapshot, and
`effective 97` / `preflight 238` / `optsheet 64` / `core 652` / `dialogs 385 passed (G2sens only)`.

## Corrections

| | |
|---|---|
| **C1** | **The caution A1 moved the arithmetic INTO was itself the shared sentence A1 forbids**, and measured false for two of its four types. Headline above. This is a defect fix riding inside a copy ruling, and it is the reason `RU6d`/`RU6e` exist |
| **C2** | **My own first `HK4` RAISED instead of answering.** `expr {… ? kept : GONE}` — Tcl's `expr` takes `yes`/`no` as **boolean literals** (which is why `RU8`'s pre-existing idiom works) and rejects every other bareword. Rewritten with `if`; the reason is recorded in the row so nobody re-derives it |
| **C3** | **`disto` was removed from the registry's `needs`, not left returning nothing.** A precondition that can never fire correctly is the drift this batch deletes. `RU8` moved from `{yes yes yes}` to `{yes yes yes no}` and gained `sp` |
| **C4** | **My first `disto` measurement read `length(frequency)` in whichever plot happened to be current.** Redone naming the plot explicitly and printing the vector, because `disto` creates `disto1`/`disto2` and `noise` creates `noise1`/`noise2` — and for `noise lin 1` the second plot **does not exist**, which is the finding |

## ⚠ Found and NOT fixed — stated plainly

1. **The new `noise` caution ships with no `R9` handle**, by instruction (*"no handle is added or
   renumbered; the count stays 726"*). It is recorded inside **`R9-153`'s note** as a per-type arm of
   that handle. A later copy review looking for it under its own number will not find one.
2. **`R9_COPY_REVIEW.md` has a duplicated, empty `### ✅ CONSEQUENCE — R9-153's ONE lowercases too`
   heading at line 147**, with the real one at 166. It is in the **driver's own in-flight edit** that
   was landing as this task started, so it was left alone rather than edited underneath the driver.
3. **`G2sens`** — pre-existing display-arm red, issue 1436, red on the pristine tree in the same run.
   Not touched.
4. **`PLAN.md` §7g still describes rule 3 as one sentence over every linear sweep.** The plan was not
   rewritten; the correction is recorded here, which is this batch's convention.
5. **`test_ase_dirty` and `test_ase_log_seam_0207` were swept on the `--nogui` arm only** and
   self-skipped there. They were not run on `:99`.
6. **`full_audit.sh` was not run**, and no `:0`/`$DISPLAY` run was taken — the display arm here is
   `:99`. No pixel deliverable is claimed, so no `look` debt; A1 changes no layout, only words.

## Debts — queue

**Nothing added, nothing cleared. 187 rule, 70 look, 11 suite, before and after.** No new
user-facing sentence that is the user's to rule on — every string here is the ruling's own required
content. No pixel deliverable. ⚠ **A `suite` debt for a `:0` run was considered and NOT filed**: A1
ships no new widget and no new drawing, and the one GUI row added (`G2e2`) reads a label through
`form_label`. If the driver wants an eyeball on the four forms reading `Number of points`, that is a
`look`, and it is the driver's call rather than mine to file.

## Hygiene

* **Every command carried a `timeout`**; every wait was a `Monitor` or a bounded background task with
  a completion marker, never an open-ended `until … sleep` loop. Nothing was stopped for memory, so
  no run lacks a verdict.
* **No simulation on a bench under `sky130A/`.** The nine ngspice probe decks are in the scratchpad
  with explicit output paths. `/usr/bin/ngspice` was run **18 times, rc 0 every time** — never
  crashed, never hung. Both binaries were used for every measurement, and they agreed exactly.
* **Binary always by path** (`./src/xschem`, `devdisplay.sh exec ./src/xschem`), always `--nolog`,
  never `--logdir`, never a bare `xschem`.
* ⚠ **`~/.xschem` — checked rather than assumed.** `recent_files` is **untouched at 2026-09-13
  18:53** (the issue 0924 canary), `ase_simulators` at 2026-09-14, `xschemrc` at 2026-09-01, and
  `simulations/` at **19:27**, which predates my first run (23:03). `geometry` and an **empty**
  `op_annot/` carry mtimes inside my window — but **two `xschem` processes started 22:42:28 and
  22:46:56**, before my first run, are alive and are an interactive session, and both suites that
  could have written geometry source `scratch.tcl`, whose exit path **no-ops `::store_geom`** for
  exactly this reason. I did not use a scratch `HOME` for the suite runs; a future pass that wants
  certainty rather than inference should.
* **Processes matched by NAME** (`ps -eo comm=`), never `pgrep -f` / a pattern my own argv contains.
  **No `pkill`.** **No background process of this crew is running**, and the three that are alive at
  hand-over are named rather than waved past: `Xvfb` (pid 1116, **08:09:29** — the shared persistent
  dev display `:99`, hours older than this session) and **two `xschem`** (pids 807232 / 809774,
  **22:42:28** and **22:46:56**) which predate my first run at 23:03 and are the interactive session
  referred to under `~/.xschem` above. Every run of mine was `--nogui --pipe --script` or
  `devdisplay.sh exec`, and all exited.
* **Snapshots**: pristine at `…/scratchpad/a1/snap/`, finished at `…/scratchpad/a1/after/`. ⚠ **Both
  are being renamed to `ARCHIVED_DO_NOT_RESTORE/` at hand-over** so a stale waiter cannot fire a
  restore over a later tree.
* ⚠ **If this crew is woken after collection: `git status` and `git log` before touching anything.**

## What binds later stages

1. **A field label carries no arithmetic** (`G2e2`), and **`SEGFAULTS` / `NOT OFFERED:` /
   `NOT MEASURED:` keep their capitals** (`PF234a`, `HK4`, `HK5`). These are a **user ruling**, not a
   style preference. A consistency pass that reds these rows has reversed the user, not tidied.
2. **`lin_points` is per type.** A new analysis whose linear count differs from `ac`'s needs an arm of
   its own; it must not be handed the need and left to inherit a sentence nobody measured for it.
3. **`noise lin 1` loses the Integrated Noise plot entirely** — measured, both binaries. Anything
   reasoning about noise result vectors should know the second plot can be absent.
4. **The gate's closing sentence is said in four places**, and `PF234b` asserts the count. Adding a
   fifth refusal means saying it the same way.
