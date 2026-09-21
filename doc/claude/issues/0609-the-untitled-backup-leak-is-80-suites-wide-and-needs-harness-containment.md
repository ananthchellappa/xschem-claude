# 0609 — the `untitled~.sch` leak is 80 suites wide; per-suite guards cannot close it

**STAMP:** `v1 claim=partial tree=c84aee78 stamped=2026-09-20 fix=partial open=3 by=stranger-reds`

⚠ **Three of the four drivers were contained on 2026-09-20 (`c84aee78`, issue 1486); the
count is re-measured and the "fix direction" below is half wrong.** Read the last section
first. STATUS: **OPEN — measured 2026-08-22**, during the 0601 fix. Related: 0601 (the
five suites now guarded), 0353 (the two originally filed), 0356 (the delete half),
0323 (`cd` does not move the buffer name), 0060 (why untitled buffers ARE backed
up on purpose).

---

## The measurement

A sweep of all **116** headless suites that touch an untitled buffer and carry no
guard, each run one at a time in a private cwd via `devdisplay.sh exec` with a
12 s timeout: **80 of them leave `untitled~.sch` in their cwd.** Not five.
`test_find_helper`, `test_label_ride`, `test_fluid_editing`,
`test_backannotate_digital`, every `test_perform_action_*`, and so on.

`tests/headless/full_audit.sh:64` does `cd "$REPO"`, so a full audit still ends
with one `untitled~.sch` in the repository root no matter how many individual
suites are guarded.

Good news in the same sweep: the leftover is **only ever** `untitled~.sch`. No
suite creates a numbered `untitled-N.sch` any more — the numbered producer
(`test_placement_wire_gate`) was fixed in `316aafdd`.

## Why the per-suite guard does not generalise

`set ::autosave_backup 0` is correct for a suite that neither descends nor
recovers. It is **wrong** for the suites that assert the backup IS written:
`tests/headless/test_backup_file.tcl:70` and
`tests/headless/test_descend_untitled_preserve.tcl:53`. Blanket-applying the
guard would silently gut those.

## The mechanism, for whoever takes this

* `src/actions.c:208` — `set_modify(1)` calls `write_backup()` on the **first**
  edit of any buffer, untitled included.
* `src/save.c:6139-6161` — `write_backup()`; the create is `fopen(bak, "w")` at
  `:6154`. It deliberately does not skip untitled buffers (`:6149-6152`, issue
  0060). ⚠ **But the function's own header comment at `:6137-6138` says it DOES**
  ("Skipped when … the buffer has no real on-disk file yet (untitled)") — the
  header is stale, the body and the code are right, and the header is wrong in
  exactly the direction that makes a reader conclude this issue cannot exist.
  Measured 2026-09-17; see 1480 §1.
* `src/save.c:6146` — it returns early when `autosave_backup` is off. That is the
  hook the per-suite guard uses.
* The path is composed from `pwd_dir`, which is `$env(PWD)` when set
  (`src/xinit.c:3917-3919`) and otherwise the **startup** `getcwd`
  (`src/xinit.c:3175`). A Tcl `cd` moves neither (`src/xinit.c:174`, issue 0323).

## The fix direction

Containment belongs in the **harness**, not in 80 suites: give each test its own
cwd in `tests/headless/full_audit.sh` and `tests/run_regression.tcl`.

**It must set `$env(PWD)`, not merely `cd`** — that is the load-bearing detail,
and it was measured the hard way while building `test_no_untitled_litter.tcl`: a
child `xschem` exec'd after a Tcl `cd` inherits the parent's `::env(PWD)` and
prefers it over `getcwd`, so the children named their buffers in the *parent's*
directory. The first guardian run read its own positive control as "no litter"
while the file had in fact gone to the repo root.

## What is already covered

`tests/headless/test_no_untitled_litter.tcl` owns the six guarded suites and
fails if any of them loses its guard. It does **not** cover the other 80 — by
design, since the guard is not the right fix for all of them.

---

## 2026-09-08 — the leak makes TWO suites structurally unpassable in a full audit

Found while attributing the non-PASS rows of a `full_audit.sh` run during the
`descend_run_batch`. This section adds three facts and corrects one.

### 1. Two suites carry a GLOBAL existence check, and the audit guarantees they red

| suite | row | what it asserts |
|---|---|---|
| `test_ase_core` | **C11** (`:1531`) | `[file exists $repo/untitled~.sch]` is 0 |
| `test_op_dump_altshow` | **H1** (`:939-941`) | the suite left the cwd alone **and made no `untitled*` in the repo root** |

Both are correct and useful when the suite is run ALONE — they catch that suite's
own leak. Neither can survive `full_audit.sh`, which `cd "$REPO"`s at `:64` and
then runs 80-odd leaking suites in the same directory. `test_ase_core` sorts
after 17 of them; whichever leaks first hands it a red it had no part in.

Measured 2026-09-08, and the pair is decisive:

```
repo root cleaned, suite run alone :
  test_op_dump_altshow  -> ALL PASS (70 checks), and leaves NOTHING behind
  test_ase_core         -> ALL PASS (224 checks)
inside full_audit.sh  :
  test_op_dump_altshow  -> FAIL   (H1 only)
  test_ase_core         -> FAIL   (C11 only)
```

### 2. `test_ase_core` has been red in THIRTEEN recorded audits, uncaused

`grep 'FAIL     | test_ase_core' doc/claude/op_param_batch/audit_*.txt` → **13 of
13** (2026-09-02 … 2026-09-04). Every one of those runs carried it forward as a
number. Nobody named C11, and C11 is the entire reason. That is exactly the
failure CLAUDE.md's "a standing red is a defect, not furniture" is written
about, and it is why this section exists rather than a fourteenth count.

### 3. ⚠ CORRECTION: the leftover is NOT "only ever `untitled~.sch`"

The 2026-08-22 sweep above says "the leftover is **only ever** `untitled~.sch`.
No suite creates a numbered `untitled-N.sch` any more". A numbered one, agreed —
but a **`untitled~.sym`** was measured in the repo root on 2026-09-08, 292 bytes,
and it is what red-ed `test_op_dump_altshow`'s H1 (whose glob is `untitled*`,
not `untitled~.sch`). `clear_schematic(cancel, symbol=1)` names the buffer
`untitled.sym` (`src/actions.c`), and the same `set_modify(1)` →
`write_backup()` path then drops `untitled~.sym`. Any future guard, and any
cleanup in `full_audit.sh`, must glob `untitled*` rather than the `.sch` alone.

### The shape of a fix, for whoever takes it

Per-suite guards cannot close the leak (see above) — but they can stop these two
rows reporting *other* suites' leaks. Snapshot the repo root at suite START and
assert only that THIS suite added nothing:

⚠ **SUPERSEDED — DO NOT PASTE THIS BLOCK. It is a partial fix in two ways, both
measured. See §"2026-09-17 — the delta landed" below for what actually shipped.**

```tcl
set h_pre [glob -nocomplain -directory $repo untitled*]
...
check_true {... made no NEW untitled* in the repo root} \
  [expr {[llength [glob -nocomplain -directory $repo untitled*]] <= [llength $h_pre]}]
```

That keeps each row's real purpose, makes it true under the audit, and leaves the
80-suite leak itself filed here where it belongs. **Not done in the batch that
found this** — two unrelated suites, and the rows are correct as written when run
the way their own headers say to run them.

**Why the block above is not enough:**

1. **It compares COUNTS, not SETS.** A run that removes `untitled~.sym` and adds
   `untitled~.sch` scores `1 <= 1` — clean. **§3 of this very file is the recorded
   correction that both extensions occur**, so the block is defeated by the exact
   swap the file already knows about.
2. **It watches `$repo` only**, so it fixes the false-red direction and leaves the
   **blind** direction exactly as blind. `$repo` comes from `[info script]` and is
   cwd-independent; under T1 the suite's own leak lands in `tests/`, which `$repo`
   never reads. §1 of the 2026-09-17 block above is that finding, and this code does
   not act on it.

---

## 2026-09-17 — under T1, `C11` cannot catch its own leak at all

Measured by the harness concurrency batch (receipts `G1.md`, `H1.md`). This section
adds **one new structural argument**, one **⚠ warning about the fix direction above**,
and a correction table. It changes nothing about this issue's status and settles
nothing about `C11`'s shape.

### 1. The new argument: a third context, and it is the one T1 uses

Section 2.1 above measured two contexts — the suite run alone (correct) and the suite
run inside `full_audit.sh` (false red, 13 of 13). **There is a third, and `C11` is
wrong in it too, for the opposite reason.**

`test_ase_core.tcl:460` sets `$repo` to `[file normalize [file join $here .. ..]]`,
derived from `[info script]` — so `C11` (`:1531`) reads the **repo root irrespective
of the process cwd**. Under T1 the suite's own cwd is `tests/`:
`tests/run_regression.tcl:619-620` runs
`exec $xschem_cmd --nogui --pipe -q --script ${hc}.tcl` with a relative script path,
**no `cd` and no `$env(PWD)` assignment anywhere in the harness** (measured across
`run_regression.tcl`, `test_utility.tcl`, `full_audit.sh`, `run_suites.sh`). So any
`untitled~.sch` the suite itself writes lands in `tests/`, which `C11` does not read.

| how run | cwd | what `C11` actually tests |
|---|---|---|
| by hand from the repo root (its header's recipe) | repo root | **its own leak** — the meaning it was written for ✓ |
| inside `full_audit.sh` (`cd "$REPO"`, `:64`) | repo root | **other suites' leaks** — false red, 13 of 13 ✗ |
| inside **T1** (`cd tests`) | `tests/` | **only foreign litter in the root**, never its own ✗ |

**Under T1, `C11` has zero ability to catch its own suite's leak** — it is a pure
probe of foreign machine state. Two of the three contexts are wrong, and the third
is the rarest.

*(`test_op_dump_altshow`'s H1 has the same `-directory $repo` property, but that
suite is **not in T1's case list at all** — measured, no hit for `op_dump_altshow` in
`run_regression.tcl` — so under T1 the only exposed row is `C11`.)*

**This is the twin of ruling ⚖ R2** (a suite red-ing on machine state it does not
own), and as with R2, pruning the litter greens the box today while the next
contributor inherits the identical false red.

### 2. ⚖ R3 is filed with the user, against this issue

*Should `C11` become a delta — snapshot the repo root at suite start, assert only
that this suite added nothing — instead of the raw existence test?* The fix code is
already in "The shape of a fix" above. **The ruling is the user's and is not decided
here**, and this section takes no position. Recorded in the owed ledger as
`rule/0609`. One answer plausibly settles R2 as well.

### 3. ⚠ THE FIX DIRECTION ABOVE WOULD MAKE EVERY T1 RUN RED, ON ITS OWN

"The fix direction" proposes giving each test its own cwd in `full_audit.sh` **and
`tests/run_regression.tcl`**. Applied to T1, that moves T1's leak out of `tests/` —
and if the new cwd is `$REPO`, `C11` fires on the first unguarded case and **the one
suite whose baseline is ZERO reports a failure on every run.**

The only thing standing between T1 and that red is the accident that its cwd and
`C11`'s search root are different directories. **So the containment and `C11`'s shape
must land together**, and the containment must set `$env(PWD)`, not merely `cd` — the
load-bearing detail already recorded above (`src/xinit.c:3917-3919` prefers
`env(PWD)` over the startup `getcwd` at `:3175`; a Tcl `cd` moves neither,
`src/xinit.c:174`).

Filed as **1480**, together with the measurement that T1 writes `tests/untitled~.sch`
on every green run (twice, with different pids, from a **passing** case) and the
reason nobody saw it: **neither audit driver writes a per-suite `.log` under `tests/`
at all**, so the sweep that concluded "no suite ran in that window" could not have
seen one.

### 4. Corrections — every citation in this file, re-measured 2026-09-17

Corrected in place above; the pre-image is here so nothing is lost.

| what | this file said | **measured today** |
|---|---|---|
| `set_modify(1)` → `write_backup()` | `actions.c:208` | `actions.c:208` ✓ **unchanged** |
| `write_backup()` definition | `save.c:4149-4171` | **`save.c:6139-6161`** |
| the `fopen(bak, "w")` create | `save.c:4164` | **`save.c:6154`** |
| untitled backed up on purpose (0060) | `save.c:4159-4162` | **`save.c:6149-6152`** |
| `autosave_backup` early return | `save.c:4156` | **`save.c:6146`** |
| `$env(PWD)` preferred for `pwd_dir` | `xinit.c:3690-3693` | **`xinit.c:3917-3919`** |
| startup `getcwd` into `pwd_dir` | `xinit.c:2952` | **`xinit.c:3175`** |
| `cd` moves neither | `xinit.c:174` | `xinit.c:174` ✓ **unchanged** |
| `test_ase_core` C11 row | `:772` | **`test_ase_core.tcl:1531`** |
| `test_op_dump_altshow` H1 row | `:924` | **`test_op_dump_altshow.tcl:939-941`** |
| `full_audit.sh` pins the cwd | `:64` | `full_audit.sh:64` ✓ **unchanged** |

⚠ **And one that is NOT in this file but belongs to its mechanism**:
`write_backup()`'s header comment (`save.c:6137-6138`) stated that untitled buffers
were **skipped**, contradicting its own body at `:6149-6152` and the code, which has
no such skip. A reader who trusted the header concluded an untitled buffer can never
produce a `~` file — i.e. concluded this issue does not exist. Recorded in **1480 §1**.
✅ **FIXED — verified 2026-09-17.** `save.c:6137-6138` now reads *"NOT skipped for an
untitled buffer -- it is a PRODUCER of `<dir>/untitled~.sch` (issue 0060, gate note
below). Skipped only when autosave_backup is off, during load, or on an empty name."*
Landed under issue **0060**. **1480 §6 item 3 is therefore done and should not be
re-filed** — it was still being reported as outstanding on the morning of the same day.

---

## 2026-09-17 — the delta landed, and the two rows now mean what they say

**`C11` and its twin `H1` are deltas as of today.** ⚖ R3, built and measured by the
harness-concurrency batch (receipt `R3-build.md`). This section records what shipped,
because the "shape of a fix" block above is **not** what shipped.

### What shipped

* `tests/headless/test_ase_core.tcl` — a fixed watch-directory list and an
  `untitled*` snapshot taken at suite start (`:462-520`); `C11` (`:1591-1605`) is now
  a **set difference** over that snapshot.
* `tests/headless/test_op_dump_altshow.tcl` — the same, `:57-87` and `:975-984`.
  `H1` keeps its cwd-restored leg, so the suite's check count is unchanged at **70**.

Two deliberate departures from the block above:

* **A set difference, not a `llength` comparison** — defect 1 above.
* **The watch list is `{$repo, $env(PWD), [pwd]}`, deduplicated and FIXED at suite
  start**, not `$repo` alone — defect 2 above. xschem composes the untitled buffer
  path from `$env(PWD)` when set (`save.c:6492-6497`, `xinit.c:3917-3919`) and
  otherwise from the startup `getcwd` (`xinit.c:3175`); a Tcl `cd` moves neither
  (`xinit.c:174`, issue 0323). The list is fixed at suite start for that same reason —
  re-deriving it at the row would score pre-existing files in a newly-entered
  directory as new.

### The measurements — every cell executed on this tree today, nothing inferred

| scenario | old row | new row |
|---|---|---|
| clean, from the repo root | `ALL PASS (675)` / `(70)` | **unchanged, 675 / 70** |
| **foreign** `untitled~.sch`+`.sym` planted in the root | `FAIL: C11 … -> {1} (exp {0})`, `FAIL: H1 … -> {0} (exp {1})` | **green, both** |
| real leak (the `autosave_backup` park removed), from the repo root | `FAIL … -> {1}` | **`FAIL … -> {/…/untitled~.sch}`** |
| real leak, run from `tests/` — **T1's cwd** | **`ok:` — green while writing `tests/untitled~.sch`** | **`FAIL … -> {/…/tests/untitled~.sch}`** |

**The fourth row is the point of the whole change**, and it is now measured rather
than argued: the old existence test passed, `RESULT: ALL PASS`, exit 0, while the
suite it was guarding was writing `tests/untitled~.sch` at that moment.

### Scope

The **80-suite leak itself is untouched** and stays filed here. So does the
harness-side containment (1480 §6) and the sweep. ⚠ **The dependency is
one-directional**, contrary to what the batch's own decision record said: the delta is
strictly *less* sensitive than what it replaces, so it ships alone safely; it is the
**containment** that cannot ship before it. With the delta in place, the containment's
choice of directory no longer matters to `C11` — which is the constraint §3 above was
written about.

---

## 2026-09-20 — three of the four drivers are contained; `tests/run_regression.tcl` is not

Landed in `c84aee78` under issue **1486** by the stranger-reds batch, item F. Receipts:
`doc/claude/stranger_reds_batch/receipts/F-impl.md` and `F-verify.md`. This section records
what shipped against this file's own fix direction, re-measures the headline count, and adds
**one class this file's sweeps were structurally blind to**.

### What shipped

* **The harness half of this issue's fix direction, for the three shell drivers.** New
  sourced library `tests/headless/suite_cwd.sh`; `run_suites.sh`, `full_audit.sh` and
  `gated_xschem.sh` arm a per-run private directory and pass `env "PWD=$_scwd"` on every site
  that starts the binary, then disarm — including on the early exits, one of which was
  MEASURED leaving the directory in the checkout.
* **A product change this file did not ask for and needed.** `clear_schematic()` and
  `go_back()`'s "No" arm no longer delete a `~` this session did not write; ownership is
  tracked as the **path** written (`backup_owned`), not as a flag. That half reaches the
  bare `./src/xschem … --script <t>.tcl`, which no driver arms.
* **A T1 case**, `tests/headless/test_untitled_autosave_1486.tcl` (13 checks), registered as
  the 73rd `hcases` entry.

### ⚠ This file's "fix direction" is right about `$env(PWD)` and wrong about the cwd

*"Give each test its own cwd"* was **measured to break suites**: with every suite run from a
private cwd, `test_reopen_readonly` dies at its line 20 with `error copying "": no such file
or directory`, because it globs `[file join [pwd] xschem_library …]` and its own header says
*"cwd = repo root"*. What shipped moves **only `$env(PWD)`**, which leaves Tcl's `pwd` alone
— and that is exactly the load-bearing detail this file already recorded ("it must set
`$env(PWD)`, not merely `cd`"). A shell child re-derives `PWD` at startup, so nothing
downstream is misled by the redirect.

### ⚠ T1 is the fourth driver, and it was not armed

`tests/run_regression.tcl` still runs its cases with no `$env(PWD)` of its own, so **a T1 run
still writes `untitled~.sch` into `tests/`**. MEASURED: `tests/untitled~.sch`, 571 bytes,
mtime **2026-09-20 23:23:39**, inside the window of the batch's own gate run
(`T1-RUN-BEGIN … start=23:22:07` / `T1-RUN-END … end=23:30:59`, `tests/results.2325750.log`)
— written by the very run that proved the fix. Row `S1` of the new guard suite checks the
three shell drivers only and is structurally blind to the Tcl one. **This is the outstanding
half of this issue's containment**, and 1486 defers to this file and to 1480 for it.

**Deliberately not filed as a new number.** 1480 §"Why a sixth number for a leak that is
already filed five times" is explicit about what re-filing this class costs, and the Tcl
driver is named in this file's own fix direction — so it is recorded here rather than given a
seventh number.

**And §3's warning above is now defused on its own terms.** It said the containment would
make every T1 run red, because `C11` reads the repo root while T1's cwd is `tests/`. `C11`
and `H1` became **deltas** on 2026-09-17, so the containment's choice of directory no longer
decides whether T1 reds. What remains is mechanical: a Tcl port of `suite_cwd.sh`, or
`env PWD=` on the four `exec` sites, plus the sweep that a `$PWD` change for all 88 cases
deserves.

### The headline count, re-measured by a sharper question

The 2026-08-22 number was *"80 of 116 suites leave `untitled~.sch` in their cwd"*. The 2026-09-20
sweep asked instead **does a pre-existing `untitled~.sch` survive**, over all 405
`tests/headless/test_*.tcl`, each in a private directory with its own empty HOME and a seeded
canary:

| | before the fix | after |
|---|---|---|
| suites that destroy a seeded `untitled~.sch` | **51** of 405 | **38** of 405 |
| … by DELETING it | 17 | **3** |
| … by OVERWRITING it | 34 | 35 |
| suites that destroy a seeded `untitled~.sym` | 1 | **0** |
| suites that leave any OTHER file **in their working directory** | 0 | 0 |

The three remaining deleters are correct — each writes the backup itself first, or deletes
its own. The 35 overwrites **cannot** be fixed: the buffer really is `<cwd>/untitled.sch` and
backing it up is what issue **0060** requires.

⚠ **And the issue-0601 guard does not stop the delete half.** `set ::autosave_backup 0`
returns early from `write_backup()` and has no effect on `remove_backup()`: MEASURED, four of
the nine guarded suites deleted the seeded canary **while carrying the guard**.
`test_no_untitled_litter` cannot see this — every one of its rows asks "did the suite leave
anything behind", never "did a file that was already there survive". That is why the product
fix, not a wider guard, is what closed the delete.

### ⚠ A second class, which no sweep in this file could see: `cellName~.sch` in the checkout

`backup_file_name()` puts the `~` **beside the cell**, not in `$PWD`. So a sweep that watches
private working directories — every sweep this file records — is structurally blind to it,
and the `$PWD` redirect cannot reach it either. **Nine suites write a `cellName~.sch` into
the checkout**, five files in all; the names are in `tests/headless/suite_cwd.sh`'s header.
Re-measured in the fix round: with `tests/from_user/before_10~.sch` moved out of the tree,
the **armed** `run_suites.sh --nogui test_fluid_bodyshove_guards_0132` put it back
byte-identical (656 bytes, same md5). **It is not a regression** — the pre-fix binary leaves
the same nine identically. It belongs here and to 1480, and it is a third correction to the
2026-08-22 line *"the leftover is only ever `untitled~.sch`"*: §3 above corrected it for
`untitled~.sym`, and this corrects it for a whole second filename shape.
