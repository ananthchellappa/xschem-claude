# 0609 — the `untitled~.sch` leak is 80 suites wide; per-suite guards cannot close it

STATUS: **OPEN — measured 2026-08-22**, during the 0601 fix. Related: 0601 (the
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
`write_backup()`'s header comment (`save.c:6137-6138`) states that untitled buffers
are **skipped**, contradicting its own body at `:6149-6152` and the code, which has
no such skip. A reader who trusts the header concludes an untitled buffer can never
produce a `~` file — i.e. concludes this issue does not exist. Source change, not
made here (this was a documentation-only task). Recorded in **1480 §1**.
