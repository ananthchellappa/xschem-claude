# 1480 — nothing sweeps for the `untitled*` residue class, and neither audit driver leaves a log that could attribute it

**Status: OPEN — measured 2026-09-17** by the harness concurrency batch (receipts
`V3.md`, `G1.md`, `H1.md` under `doc/claude/harness_concurrency_batch/`).
**Subject** `tests/headless/full_audit.sh`, `tests/headless/run_suites.sh`,
`tests/run_regression.tcl`, and the residue sweep every verification crew in this
batch was briefed to run. **Class** harness / verification method.

**Related, and read them first:** **0609** (the 80-suite leak itself, and the
containment this issue must land with), **0687**, **0673**, **0353**, **0356**.

---

## Why a sixth number for a leak that is already filed five times

**The litter is not this issue.** `untitled~.sch` leaking out of headless suites has
been on file since 2026-08-09 and each of the five numbers owns a real, distinct
piece of it:

| number | status | what it owns |
|---|---|---|
| **0353** | PARTIAL | two gated suites leak `untitled-NN.sch`; the audit's tree-delta arm landed for the **non-backup** shape only |
| **0356** | OPEN | the **open decision** on widening that arm to `--ignored=matching`, with the tradeoff written out |
| **0609** | OPEN | the leak is **80 of 116** suites wide; containment belongs in the harness, not in 80 suites |
| **0673** | OPEN | `test_wave_markers`; its fix item 2 is *verbatim* "widen the tree-hygiene check crews are told to run" |
| **0687** | OPEN | `test_backannotate_digital` litters its **launch dir** while reporting ALL PASS, and the guardian misses a pre-existing file |

Anyone reading this batch's receipts will reach for "add `untitled*` to the sweep".
**That is 0673 item 2 and it is already filed.** Re-filing it would be the sixth
copy of a proposal nobody has implemented, which is the failure mode CLAUDE.md's
"a standing red is a defect, not furniture" is written about — 0609 alone was
re-derived four times before anyone noticed.

**What is new, and in no issue file, is why the leak survived an hour of checking by
four separate readers.** Three facts, each measured on this tree on 2026-09-17:

1. **Neither audit driver writes a per-suite `.log` under `tests/` at all** (§2.1).
   So "did a suite run in this window?" cannot be answered from `tests/*.log` — and
   a verification pass answered it that way and got the wrong answer.
2. **T1 produces one of these files on every ordinary green run** (§3), from a
   *passing* case, into a directory no check in the tree reads.
3. **0609's proposed containment would make every T1 run red** (§5), because T1's
   cwd and `C11`'s search root are different directories today and the containment
   changes exactly that. Nothing in 0609 knows this, and nothing in T1 warns.

---

## 1. The mechanism, pinned and reproduced byte-for-byte

`tests/headless/test_descend_inert_class.tcl:173` places one object on the startup
untitled buffer:

```tcl
xschem clear force
xschem instance [file join $dev lab_pin.sym] 100 100 0 0 {name=zz1}
```

That dirties the buffer → `set_modify(1)` → `write_backup()`
(`src/actions.c:208`) → `<pwd_dir>/untitled~.sch`. Under `full_audit.sh`,
`pwd_dir` is the **repo root**: `full_audit.sh:64` is `cd "$REPO" || exit 2`.
`test_descend_inert_class` is the **last of the 15** names in the CI headless gate
(`.github/workflows/ci.yaml:74`), and the audit's explicit-selection path preserves
the given argument order.

Reproduced by G1 in an isolated cwd: **md5 `2dbeb0ea88ae0a73d6d34e6efc5463e3`,
113 B**, `cmp`-identical to the file found in the repo root.

The content signature is **exclusive**, re-measured today across all 15 CI-gate
suites: `zz1` appears in `test_descend_inert_class` (4 hits) and in **none** of the
other 14. The guard census of the same 15 — `set ::autosave_backup 0` — is
**4 guarded / 11 unguarded**, `test_descend_inert_class` among the unguarded:

```
GUARDED   : test_shape_draw_gate, test_paste_modify_flag_0244,
            test_placement_wire_gate, test_instance_update          (4)
UNGUARDED : the other 11, INCLUDING test_descend_inert_class       (11)
```

⚠ **`write_backup()`'s own header comment says the opposite of what it does**, and
it is wrong in exactly the direction that hides this leak. `src/save.c:6137-6138`:

```c
 * Skipped when autosave_backup is off or the buffer has no real on-disk file yet
 * (untitled): there is nothing to back a "~" file against. */
```

The body, sixteen lines further down at `:6149-6152`, says the reverse — *"Back up
even when 'name' has no on-disk file yet (an untitled buffer) … Skipping untitled
here lost the whole top level on descend+ascend (issue 0060)"* — and **there is no
untitled skip in the code**. A reader who trusts the header concludes an untitled
buffer can never produce a `~` file, i.e. concludes this issue does not exist.
Measured 2026-09-17. The header is the stale half (issue 0060 changed the body).

## 2. Two structural blindnesses, stacked — this is the part that is new

### 2.1 Neither audit driver leaves a `.log` under `tests/`. NOT PREVIOUSLY FILED.

```sh
full_audit.sh:473   tmpd=$(mktemp -d)
full_audit.sh:475   out=$(timeout "$TIMEOUT" env XSCHEM_AL_LOGDIR="$tmpd" "$XSCHEM" … 2>&1); ec=$?
full_audit.sh:477   out=$(timeout "$TIMEOUT" "$XSCHEM" --pipe -q --logdir "$tmpd" … 2>&1); ec=$?
run_suites.sh:121   out=$(timeout "$TIMEOUT" "$XSCHEM" --pipe -q --nolog --nogui … 2>&1); ec=$?
run_suites.sh:122   tmpd=$(mktemp -d)
```

Suite output goes into a **shell variable**; the only on-disk artefact is a
`mktemp -d` logdir outside the repo, `rm -rf`'d on the way out. A `grep` for
`\.log` across `full_audit.sh` yields **one hit, and it is a comment**.

Per-suite `.log` files under `tests/headless/` are written by
**`run_regression.tcl` only** (`:620`, `:691`) and by hand runs.

**The cost, measured.** A verification pass (V3) concluded the litter was
"pre-existing, not this batch" from the step *"no suite ran in that window — zero
`*.log` files anywhere under `tests/` have an mtime between …"*. **That sweep was
structurally incapable of seeing the run responsible**, and the run responsible was
this batch's own CI-gate verification. The premise was false; the conclusion
inherited it. A check that cannot observe the thing it concludes about is the same
fail-open class as issue **0147** and as **1476**'s face 2.

### 2.2 The run that creates the litter cannot report it either. Already filed — see 0353/0356.

`full_audit.sh`'s leak detector is
`tree_delta_snapshot() { git -C "$root" status --porcelain --untracked-files=all }`
(`:411-415`, taken at `:446` and `:529`, printed as `TREEADD`/`TREEDEL` and a
`TREE:` summary). `git status` honours `.gitignore`, and `.gitignore:75` is
`*~.sch`:

```
$ git check-ignore -v untitled~.sch tests/untitled~.sch untitled~.sym
.gitignore:75:*~.sch    untitled~.sch
.gitignore:75:*~.sch    tests/untitled~.sch
.gitignore:76:*~.sym    untitled~.sym
```

**This half is not new and must not be re-filed**: it is the closing section of
**0353**, the whole of **0356**, and it is locked *as a limit* by **C39b/C39c** in
`tests/headless/test_audit_classifier.tcl:490-493`. `.gitignore:48-52` already
writes down the cure (a second `--ignored=matching` pass) *and* warns against
converting coverage into a "CANNOT see" row without filing the loss.

⚠ **Those citations have gone stale and now mislead.** `*~.sch` / `*~.sym` moved to
`.gitignore:75,:76`, but **five places still say `:55,:56`** — measured
2026-09-17: `test_audit_classifier.tcl:166`, `:485` and the **check-name string**
at `:490` (`"C39b tree delta CANNOT see a leaked *~.sch -- .gitignore:55 …"`),
plus `0353:74`, `0356:43,:45` and `0264:335`. `.gitignore:55` is today `# Executables`.
Same defect class as D2's lying detail strings and F2/F3/F4's citation passes.
**Not fixed here** — `:490` is a check name, i.e. test logic, and this task was
documentation-only.

## 3. T1 writes one of these on every green run, and nothing looks

| path | ignored by | who writes it |
|---|---|---|
| `<repo>/untitled~.sch` | `.gitignore:75` | any unguarded suite under `full_audit.sh` (cwd = `$REPO`) |
| `<repo>/tests/untitled~.sch` | `.gitignore:75` | any unguarded case under **T1** (cwd = `tests/`) |

Measured **twice, on two different runs**, which is what makes it a measurement and
not an inference: V3 saw scratch tag `_badig_2066619`; G1 saw `_badig_2108581`
during its own run — **a different pid, so a fresh write, not a survivor.** The
`_badig_` tag is owned by `tests/headless/test_backannotate_digital.tcl:69`
(`set scratch [test_scratch badig]`), and that case **passed**
(`RESULT: ALL PASS (84 checks)`). *(The producer is 0687's subject; 0687's own
citation of `xschem clear force` at `:374` is stale — the only `clear force` in that
file today is `:484`.)*

This is the only one of the batch's residue classes produced by a **passing** case.
The five swept classes and the one nobody swept:

| # | class | ignored by |
|---|---|---|
| 1 | `tests/results.log.lock` | `.gitignore:123` |
| 2 | `tests/results.<pid>.log` | `.gitignore:95` |
| 3 | `tests/<case>/results.<pid>/` | `.gitignore:112-114` |
| 4 | `tests/<case>/.work.<pid>/` | `.gitignore:115-117` |
| 5 | `tests/headless/.scratch/` | `.gitignore:85` |
| **6** | **`untitled*` at the repo root AND in `tests/`** | **`.gitignore:75-76`** |

All six `.gitignore` citations re-measured with `git check-ignore -v`, not inherited.

**Static exposure under T1**, as a proxy and explicitly *not* a leak measurement:
**63 of T1's 69 headless cases contain no `set ::autosave_backup 0` anywhere**. The
6 that do are `test_ase_core`, `test_instance_update`, `test_op_annot`,
`test_paste_modify_flag_0244`, `test_placement_wire_gate`, `test_shape_draw_gate` —
and `test_ase_core`'s is **parked around three statements only**
(`:1520-1530`), not file-wide. A grep for the guard says nothing about whether a
case dirties an untitled buffer; 0609's measured 80-of-116 is the real number.

## 4. The scope limit, stated plainly

**The `tests/` copy can never reach `C11`.** `test_ase_core.tcl:1531` is

```tcl
check "C11 no untitled~.sch was dropped in the repo root (issue 0609)" \
  [file exists [file join $repo untitled~.sch]] 0
```

and `$repo` (`:460`) is `[file normalize [file join $here .. ..]]` — derived from
`[info script]`, so it is the **repo root irrespective of cwd**. A file in `tests/`
is outside that path. `test_op_dump_altshow`'s H1 (`:939-941`) globs
`-directory $repo` and has the same property — and that suite is **not in T1's case
list at all** (measured: no hit for `op_dump_altshow` in `run_regression.tcl`), so
under T1 the only exposed row is `C11`.

So class 6 at `tests/` costs nothing today. It is worth sweeping because it is
**invisible to `git status`, invisible to the audit's own detector, produced by a
green case, and accumulating across every run** — and because §5 is one harness
change away from making it cost a great deal.

## 5. ⚠ THIS FIX AND 0609's MUST LAND TOGETHER, OR EVERY T1 RUN GOES RED

The only reason T1 has never reddened `C11` is that **T1's cwd is `tests/` while
`C11` reads the repo root**. Two independent facts; **either one changing turns
every T1 run red.**

| how the suite is run | cwd | what `C11` actually tests |
|---|---|---|
| by hand from the repo root (its header's recipe) | repo root | **its own leak** — the meaning it was written for ✓ |
| inside `full_audit.sh` (`cd "$REPO"`, `:64`) | repo root | **other suites' leaks** — false red, 13 of 13 recorded audits ✗ |
| inside **T1** (`cd tests`) | `tests/` | **only foreign litter in the root**, never its own ✗ |

0609's "fix direction" is *"give each test its own cwd in
`tests/headless/full_audit.sh` **and `tests/run_regression.tcl`**"*. Applied to T1,
that moves T1's leak from `tests/` into whatever cwd the containment picks — and if
that is `$REPO`, `C11` fires on the first unguarded case and **the one suite whose
baseline is ZERO reports a failure on every run.**

Two details that make this sharper than it looks:

* **T1 does not `cd` and does not set `$env(PWD)`.** Measured: no `env(PWD)`
  assignment anywhere in `run_regression.tcl`, `test_utility.tcl`, `full_audit.sh`
  or `run_suites.sh`; the headless arm is
  `exec $xschem_cmd --nogui --pipe -q --script ${hc}.tcl` (`:619-620`) with a
  relative script path and no directory change. So `pwd_dir` is inherited from the
  invoking shell — which is why `cd tests && tclsh run_regression.tcl` puts the
  litter in `tests/`.
* **0609 already warns that the containment must set `$env(PWD)`, not merely `cd`**
  (`src/xinit.c:3917-3919` prefers `env(PWD)` over the startup `getcwd` at `:3175`;
  a Tcl `cd` moves neither, `src/xinit.c:174`, issue 0323). A containment that
  only `cd`s would leave the children naming their buffers in the *parent's*
  directory — 0609 records that being measured the hard way, with a guardian run
  reading its own positive control as "no litter".

**⚖ Ruling R3 is filed with the user against 0609** (should `C11` become a delta —
clean before, compare after — rather than a raw existence test?). It is the twin of
R2. **Nothing here decides it**, and this issue takes no position on `C11`'s shape.

## 6. The fix direction — **PROPOSED AND UNMEASURED**

Nothing below has been run. Three separable pieces:

1. **The sweep** (this issue's own half). Add class 6 to the residue sweep every
   verification pass runs, with a positive control like the other five:
   ```sh
   find "$REPO"       -maxdepth 1 -name 'untitled*'
   find "$REPO/tests" -maxdepth 1 -name 'untitled*'
   ```
   **PROPOSED AND UNMEASURED.** Note this is deliberately a `find`, not a widened
   `git status` — 0356 records the `--ignored=matching` route as an **open design
   decision with a real tradeoff**, and this issue does not pre-empt it.
2. **A driver-side record that a suite ran.** §2.1's blindness is not fixed by
   sweeping: the question "which run wrote this?" still has no answer from inside
   the repo. The cheapest honest shape is for `full_audit.sh`/`run_suites.sh` to
   leave a single machine-readable manifest (run id, start/end epoch, suite names in
   order) rather than 15 log files. **PROPOSED AND UNMEASURED**, and note
   `.gitignore` would have to not hide it.
3. **`write_backup()`'s header comment** (§1) should be corrected to match its body.
   Source change, one comment, no behaviour. **PROPOSED AND UNMEASURED — not done
   here**, this task was documentation-only.

## 7. What this issue does NOT claim

* It does not claim the leak is new — it is 0609's, filed 2026-08-22, and 0353's
  before that.
* It does not claim `test_descend_inert_class` is the only leaker in that audit. Ten
  other unguarded suites in the same 15 would have written the **same path** earlier
  in the run; the surviving content identifies the **last** writer, not the only one.
* It does not claim the `tests/` copy currently breaks anything (§4).
* It does not attribute any wall-time difference to anything. T1 measured 374.6 /
  375.0 / 377.7 / 375.1 s across four single runs on an uncontrolled box, one of
  which carried a failing case. **Attribute nothing.**
* The byte-exact reproduction, the `cmp`, and the two `_badig_` pids are **G1's and
  V3's measurements**, cited not re-run: both files were deleted by G1, so the
  content is no longer on disk to re-measure. Everything else above was
  re-measured on 2026-09-17.
