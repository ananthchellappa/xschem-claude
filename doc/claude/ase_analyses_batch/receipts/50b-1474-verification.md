# 50b — independent verification of issue 1474 (receipt 50)

Verifier pass, 2026-09-15. Tree at `df5df4fe` plus the crew's uncommitted work.
**Nothing implemented, committed or fixed here.** No `git checkout/restore/stash/clean/push`,
no `pkill`, no bare `xschem`, no `--logdir`, nothing read or written under `~/.xschem/`
except `owed.sh list` (read-only), no simulation on any bench under `sky130A/`.

At start and at end: `src/ase.tcl` `946b1fb4…`, `src/ase_window.tcl` `b38be6df…`,
`test_ase_core.tcl` `4ee42bc3…`, `test_ase_trnoise_1466.tcl` `b59d36bf…`,
`R9_COPY_REVIEW.md` `91aee8ab…` — the crew's hand-over values, unmoved.
Base taken with `git show df5df4fe:<f>` (`ase.tcl` `145eeac1…`, `ase_window.tcl` `55b021fd…`).

**All nine claims CONFIRMED.** Three things the receipt states more strongly than the tree
supports, and one that has changed under it, are recorded below; none changes a verdict.

---

## The nine claims

### 1. The plan is 1473's, not a second resolve — CONFIRMED

Measured through the **real `ase::ui::do_stop`** with `kill_running_cmds` stubbed, on a
session whose own bench and whose run record deliberately disagree:

| session bench | run record `ckpt` | sentence the CIW got |
|---|---|---|
| checkpointed (`tran 10n/8m`) | `{}` | `…nothing of this run was written` |
| checkpointed | this run's plan | `…every point up to this run's last checkpoint was written, and what is kept is marked partial` |
| checkpointed | **no `ckpt` key at all** (every pre-1473 record) | `…nothing of this run was written` |

And the case the issue is actually about — **the bench edited between launch and stop**: the
session re-opened on a state *below* the checkpoint floor (`ase::ckpt_rows` over the session's
current state → `{}`) while the record still holds the launched plan. The Stop still said
**KEEPS**. So the sentence follows the record and cannot be reached from the session's current
bench. My own arm **V_REDERIVE** (the Stop door re-derives via `ase::ckpt_rows` over
`ase::session_state`) reddens **CK33 CK33b** and nothing else.

### 2. ⚠ The new `ase::run_record` seam — CONFIRMED, with the validation only PARTLY pinned

Every branch measured directly: absent id → `{}`; non-integer and empty → `{}`; short list
(3 elements) → `{}`; foreign first word with a dict-shaped element 4 → `{}`; the real record
→ the meta dict, and `ckpt` reads back out of it intact.

**The identity check is real:** arm **V_FIRSTWORD** (drop `[lindex $cb 0] ne {ase::run_done}`)
reddens **CK32** alone. So removing it does change a row.

⚠ **But its stated justification does not reproduce, and one of its two guards is pinned by
nothing.** Two measured qualifications to the receipt's headline:

* **The threat named in the comment is not reachable from the tree's other writer.**
  `src/xschem.tcl`'s own `simulate` writes `execute(callback)` as a **multi-line string**, not
  a 5-element list. Measured on that exact shape: `lindex $cb 4` → `{}`, `dict size` → `0`.
  So even with **no** first-word check, `ase::run_record` returns `{}` for it. The check bites
  only a hypothetical foreign callback carrying ≥5 elements *and* a dict-shaped element 4 —
  which is precisely CK32's synthetic fixture and nothing else in this tree.
* **"reading it as one would put arbitrary text through `ase::state_get`" overstates the
  harm.** Measured: `ase::state_get {this is arbitrary text of odd length} ckpt {}` → `{}`,
  no raise. `state_get` is `dict exists` + `dict get`, and `dict exists` answers 0 on that
  input rather than erroring.
* ⚠ **`if {[catch {dict size $meta}]} { return {} }` IS PINNED BY NO ROW.** Arm
  **V_DICTSIZE** deletes that line outright and both suites come back **ALL PASS** —
  `test_ase_core` 652, `test_ase_trnoise_1466` 80, zero reds. CK32's six terms never hand
  `ase::run_done` a non-dict element 4, so the guard is unmeasured. It is not dead (an
  odd-length element 4 does return `{}` because of it — measured), it is simply **undefended**,
  and the brief's own rule is that a line nothing can red is a line that quietly stops working.
  **Found, not fixed:** one more term in CK32 would close it.

**The read-before-kill order is insurance, not a live race — confirmed structurally.**
`kill_running_cmds` (`src/xschem.tcl:401`) is `exec kill` on the numeric branch and enters no
event loop, and `execute` drops `callback,<id>` at `src/xschem.tcl:315` only when it fires the
callback. So nothing between the two lines can pump the loop today. The order is pinned by
**CK33b**'s `string first` term.

### 3. The fourth adapter key `after_ckpt` — CONFIRMED

Four backend shapes registered and measured, each the full ngspice entry with only
`run_stop_cost` differing:

| backend declares | un-checkpointed run | checkpointed run |
|---|---|---|
| `after` only | its `after` sentence | **`{}` — nothing at all** |
| `before` + `before_ckpt` only | `{}` | `{}` |
| `after_ckpt` only | `{}` | its `after_ckpt` sentence |
| empty hook / not registered at all | `{}` | `{}` |

So a backend missing `after_ckpt` says **nothing**, never the other column's sentence, and a
`before_ckpt`-only backend is not accidentally given one. Arm **V_SILENCE** (a missing
`after_ckpt` falls back to `after`) reddens **CK30b CK31**.

### 4. The un-checkpointed run's sentence is byte-identical to `df5df4fe` — CONFIRMED

Probed **against the commit itself**, not against the code's appearance: `src/ase.tcl` and
`src/ase_window.tcl` replaced by `git show df5df4fe:…`, the same probe run, the answer written
as raw UTF-8 bytes and compared with `cmp`.

```
base (df5df4fe)  md5 0687549d60eea63076623d620162323c   59 bytes   info args -> sim
fixed            md5 0687549d60eea63076623d620162323c   59 bytes   info args -> {sim ckpt}
cmp -> identical
```

### 5. CK31 is the row the issue is about — CONFIRMED, and more strongly than the receipt showed

The parent's test was to *break the agreement in a way per-message goldens would miss*. Arm
**V_CK31** does exactly that: the checkpointed branch is taken only for `n >= 4`. Because
`ase::ckpt_n` is the constant **4**, every plan the per-message goldens exercise is unaffected;
only CK31's hand-spelled **n=2** plan now has a launch warning that promises salvage and a stop
message that denies it.

```
V_CK31  test_ase_core  rc=1  KILLED  reds=[CK31]
V_CK31  test_ase_trnoise_1466  rc=0  SURVIVED  reds=[]
```

**CK31 reddens alone** — CK30, CK30b, CK30c, CK33 and NP7b all stay green. The crew's own
campaign contains no such arm (their N02 reddens `CK30b CK31` together), so this is the first
measurement showing CK31 is not reachable by any per-message golden. The receipt's headline is
**understated**, not overstated.

### 6. CK28f pins all eight residue kinds one at a time — CONFIRMED

The row's own expression re-evaluated with `ase::analysis_salvage` monkey-patched to give
**one** kind a salvage declaration it does not have, eight times over:

```
break op -> moved [op]        break sp   -> moved [sp]
break noise -> moved [noise]  break pz   -> moved [pz]
break disto -> moved [disto]  break sens -> moved [sens]
break pss -> moved [pss]      break tf   -> moved [tf]
```

Each break moves **exactly its own term and no other**, so the row fails for the right reason
per kind and is not satisfied by a planner that answers `{}` to everything. The non-vacuity
control is live (`ase::ckpt_plan` over the long transient → `{n 4 step 160000 points 800000
vector time}`), and the baseline restores to eight `{}` answers after the patch is removed.

The `pss` justification is confirmed as a registry fact, not an omission:
`ase::analysis_emit_rank pss` → `{}`, `ase::analysis_emit_order` over a `pss` bench →
`RAISED: analysis type 'pss' is not one this simulator backend can render`, and a walked bench
carrying `pss` + a live transient → `ase::ckpt_rows` → `{}`. `sp`'s rank is **95**, which is why
it *can* sit in CK28c's bench. Receipt correction **C2 is accurate.**

### 7. The complete-just-before-the-kill race — CONFIRMED, and correctly characterised

Measured in one pass: the stop sentence for a checkpointed run is the **partial** one, while
`ase::run_completed` over a log carrying the completion marker answers **`complete`** and
`ase::ckpt_report` then returns **`{}`** — it says nothing, having deleted the checkpoint.
So the user is left holding "what is kept is marked partial" for a run that finished, with
nothing following to correct it.

**It is genuinely the pre-existing race in the opposite direction, and it is not widened.** At
`df5df4fe` the sentence was unconditional, so the same race told a run that had written
*everything* that *nothing* was written. The receipt's "neither introduced nor widened here" is
accurate. One observation worth carrying: the new wording is a **positive** claim about an
artifact `ase::ckpt_report` has just deleted, where the old one was a negative claim about a
file that existed — the same-sized race, but the wrong answer is now more actionable.

### 8. ⚠ `EE5` — CONFIRMED intermittent, and NOT apt-specific as the receipt implies

Re-run independently, **38 runs of my own**, every one under `timeout`:

| arm | runs | `EE5/apt` ok | `EE5/fork` ok |
|---|---|---|---|
| headless | 24 | 24 | **23** |
| display (`:99`) | 14 | 14 | 14 |

**One failure in 38 (≈2.6 %), and it was `EE5/fork`, not `EE5/apt`:**

```
FAIL: EE5/fork ... -> {0 white {random rts} 1 1 1 0} (exp {0 white {random rts} 1 1 1 1})
```

Identical symptom to the crew's — the last term `0` where `1` was expected — on the **other
binary**. So the row is intermittent on **both** ngspice builds, which makes it a property of
the row (a seeded-noise repeatability comparison on a real two-run end-to-end), not of apt 45.2
and not of the display arm. Combined with the crew's 1-in-9, the rate is order 2–10 %.

**It was not reddened by this change**: the change is pure Tcl reachable only from
`ase::run_stopped_msg`, `ase::run_record`, one adapter dict key and `ase::ui::do_stop`, none of
which a noise-seed measurement touches — and it reddens identically on the **base** tree's own
code path, which carries none of this change. The crew's refusal to score 8 greens as a verdict
was correct; their "intermittent in a pre-existing per-binary row" is right, but a later crew
should not read it as an apt-only phenomenon. **Still unfiled — one observation is not a rate,
but there are now two, on two binaries.**

### 9. The ledger and the copy review — CONFIRMED

```
owed.sh list -> [1474] the moment-of-the-Stop sentence for a checkpointed run
                ref: doc/claude/issues/1474-...md          (resolves, file present)
~/.claude/xschem_owed/rule/1474 -> repo:/home/analog/dev/xschem-claude   repo_via:git
owed.sh count -> 187 rule, 70 look, 11 suite      cleared.log -> 51 lines (unchanged)
```

`R9_COPY_REVIEW.md` header reads **726 strings, from 38 issues**. R9-726 extracted from its
fenced block and compared with the string the code actually produces:

```
R9-726 (document)  md5 685cdda50b661f0e5d6640bdaf3c2fad  120 bytes
ase::run_stopped_msg ngspice <plan>  md5 685cdda50b661f0e5d6640bdaf3c2fad  120 bytes
```

⚠ **Out of scope but worth naming:** `grep -L '^repo:'` over the ledger is **no longer silent** —
`rule/1357`, `rule/1357@xschem-claude`, one `look/` and one `suite/` entry carry no `repo:`
stamp. Per CLAUDE.md an unstamped entry against a stamped ledger is evidence of another clone's
older `owed.sh` overwriting something. **Nothing to do with 1474** (whose entry is stamped) and
not this task's to fix, but it is the signal that paragraph exists for.

---

## Suites — base → after, both arms, as a NAME diff

Base = all five files at `df5df4fe`. Headless `./src/xschem --nogui --pipe -q --nolog --script`;
display `devdisplay.sh exec timeout --kill-after=20 420 ./src/xschem --pipe -q --nolog --script`
on `:99` (Xvfb + **openbox**, 1920x1080x24, confirmed live). Every run rc **0**.

| suite | headless base → after | display base → after |
|---|---|---|
| `test_ase_core` | 644 → **652** | 644 → **652** |
| `test_ase_simreg_0931` | 118 → 118 | 118 → 118 |
| `test_ase_trnoise_1466` | 79 → **80** | 79 → **80** |
| `test_ase_persist` | 49 → 49 | 153 → 153 |
| `test_ase_preflight` | 235 → 235 | 235 → 235 |
| `test_ase_events_1465` | 87 → 87 | 87 → 87 |
| `test_ase_variant_1470` | 76 → 76 | 76 → 76 |

**Name diff, 14 comparisons, computed with `comm` over sorted row names from every
`ok:`/`FAIL:` line:**

* **lost = 0 in all fourteen.**
* **gained:** `test_ase_core` → `CK28f CK30 CK30b CK30c CK31 CK32 CK33 CK33b` (8, both arms);
  `test_ase_trnoise_1466` → `NP7b` (1, both arms); the other five suites gained nothing on
  either arm.

Every number in the receipt's suite table is **independently reproduced**.

## `.state` byte identity

Driven through the proc (`source` + `ase_state_roundtrip $repo`), never as a bare `--script`:

```
tracked 104    bad {}    control_disagrees 1    control_agrees 1
```

## The sabotage campaign — my own arms, not the crew's

Exact-anchor mutations (anchor count asserted **= 1**, an arm whose md5 did not move is
**refused**), restore by plain `cp` from a pristine snapshot of all five files from the normal
path **and** from SIGINT/SIGTERM/SIGHUP, md5-verified after every arm.

**The gate is a positive assertion and was fed the empty case first:**

```
empty=NORESULT  missing=NORESULT  partial=NORESULT  pass=SURVIVED  fail=KILLED
```

| arm | what I broke | verdict | rows that reddened |
|---|---|---|---|
| **N00** | the whole pre-change pair (base source, current suites) | KILLED | core **CK0** (section CK dies on `wrong # args`), trnoise **NP7b** |
| **V_CK31** | checkpointed branch only for `n >= 4` | KILLED | **CK31 — alone** |
| **V_SILENCE** | a missing `after_ckpt` falls back to `after` | KILLED | **CK30b** CK31 |
| **V_DICTSIZE** | `ase::run_record` drops its dict-shape guard | ⚠ **SURVIVED** | **none — the finding** |
| **V_FIRSTWORD** | `ase::run_record` reads element 4 of ANY callback | KILLED | **CK32** |
| **V_REDERIVE** | the Stop door re-derives the plan from the session's bench | KILLED | **CK33 CK33b** |

`RESTORED_CLEAN 5/5 files byte-identical` after **every** arm, including the interrupted-path
handlers. **Final restored tree, positive last row:** all seven suites **ALL PASS** on **both**
arms, rc 0 — headless 652 / 118 / 80 / 49 / 235 / 87 / 76, display 652 / 118 / 80 / 153 / 235 /
87 / 76.

---

## ⚠ The tree moved under this verification

`doc/claude/issues/NUMBERING.md` was **unmodified** at the start of this session and is
**modified now** (mtime `2026-09-15 18:27:17`, +12 lines), adding the `1474` row and superseding
the `next free number is 1474` line.

**This is not a crew error and the receipt's correction C5 was accurate when written:**
`git show df5df4fe:doc/claude/issues/NUMBERING.md | grep -c '^- \*\*1474\*\*'` → **0**, so the
row genuinely was absent at the commit the crew measured. The driver has since written it, which
is exactly what C5 asked for. The consequence for the record is only that the working tree now
carries **six** modified files, where receipt 50's hygiene section describes five.

## "What is unchanged, and how it is known" — checked by body, not by eye

The receipt claims `ase::run_stop_warning`, `ase::ckpt_worst_n`, `ase::ckpt_plan`,
`ase::ckpt_rows`, `ase::ckpt_report`, `ase::run_deck` and `ase::run_log_header` have no line in
the diff. Tested directly: each proc's body extracted from `git show df5df4fe:src/ase.tcl` and
from the worktree, and md5-compared.

```
ase::run_stop_warning UNCHANGED   ase::run_completed   UNCHANGED
ase::ckpt_worst_n     UNCHANGED   ase::run_stop_cost   UNCHANGED   (the CORE reader)
ase::ckpt_plan        UNCHANGED   ase::analysis_salvage UNCHANGED
ase::ckpt_rows        UNCHANGED   ase::state_get       UNCHANGED
ase::ckpt_report      UNCHANGED   ase::run_deck        UNCHANGED  (29777 bytes)
ase::run_log_header   UNCHANGED
ase::run_stopped_msg  CHANGED     ase::run_record      ABSENT at df5df4fe, present now
```

Exactly two procs moved, and they are the two the issue names. The adapter's own
`run_stop_cost` (inside `namespace eval ase::backend::ngspice`) gained `after_ckpt` as claimed;
the core `ase::run_stop_cost` reader is untouched. Per-file diff arithmetic also matches the
receipt exactly — `23/1`, `101/8`, `17/1`, `233/1`, `38/0` = **412 insertions, 11 deletions**,
five files, **no `.c` / `.h` / `.y` / `.l` / `Makefile`** in the diff, and `src/xschem` still
md5 `96fc4899…`. All nine new rows are pure Tcl: the only added test line mentioning a run
verb is a **comment** (`## ase::run_deck already resolved this run's plan once`).

## ⚠ THE T1 INVOCATION IS A TRAP, AND IT FAILS AS A CLEAN SWEEP

`tclsh tests/run_regression.tcl` **cannot work from the repo root.** Line 329 is a bare
`source test_utility.tcl` and `$log_fn` (line 295) is the bare `"results.log"`, so the script
resolves both against **cwd**:

```
couldn't read file "test_utility.tcl": no such file or directory
    while executing "source test_utility.tcl  "
    (file "tests/run_regression.tcl" line 329)          rc 1, 0 Start / 0 Finish lines
```

⚠ **And the failure is invisible in `results.log`, because the script dies before touching
it.** The file left on disk is the *previous* run's — same mtime, same size, same byte count —
so a verifier who runs the documented command, sees rc 1 (or doesn't check it, since
`run_regression.tcl` normally exits 0 regardless), and then counts `Total num fail:` lines in
`tests/results.log` reads **someone else's clean sweep as their own measurement**. I hit this
exactly: 82 × `Total num fail: 0` and zero counted lines, out of a file stamped **17:52:42**,
before this session began.

The invocation that works is CLAUDE.md's — `cd tests && tclsh run_regression.tcl` — and the
T1 result below was taken that way, with the `results.log` md5 recorded **before and after** to
prove the file was actually rewritten.

⚠ **This bears on receipt 49b**, the verification of issue 1473, which reports
*"`tclsh tests/run_regression.tcl`, solo and in the foreground under `timeout 3600`: rc 0,
**zero** counted lines … 84 × `Total num fail: 0`"*. As literally written that command exits **1**
and reads a stale file. Either 49b ran it from `tests/` and wrote the path loosely, or its T1
row is a stale-file reading; the receipt does not record an rc that would tell the two apart,
and it reports **rc 0** where this command yields rc 1. Not this task's to resolve — flagged
because 49b was handed to this pass as ground truth.

## T1 — `run_regression.tcl`, solo, three runs

Each run solo (guarded by a **process-NAME** match, `ps -eo comm=,args= | awk '$1=="tclsh"…'`,
which no shell's own argv can counterfeit), from `tests/`, under `timeout`, verdict read from
`tests/results.log` and never from stdout or the exit code.

| run | tree | rc | elapsed | cases | **counted** |
|---|---|---|---|---|---|
| 1 | fixed (`946b1fb4…`) | 0 | ~350 s | 82 | ⚠ **3** |
| 2 | **base `df5df4fe`** (all five files) | 0 | 357 s | 82 | **0** |
| 3 | fixed, restored | 0 | 357 s | 82 | **0** |

Run 1's file is provably mine (`results.log` md5 `8456b56c…` → `14b30eb6…`, 5412 bytes). No
`couldn't execute`, no `exit 127`, and **no `exit -1`** in any run — so no issue-0990 collision,
and the numbers are evidence.

**Run 1's three counted lines were all one case — `headless/test_ase_optier_0963`:**

```
FAIL: X1 ... every one of the requests this run made comes back with a number -> {NORAW} (exp {1 0 {}})
FAIL: X2 ... the two ways of asking give the SAME numbers -> {{} ZZNOTRUN} (exp {{} {}})
HARNESS: headless/test_ase_optier_0963 did not complete cleanly (exit=1, OVERALL_ok=0, died=0)
Total num fail: 3
```

**It is intermittent and it is not this change's.** Four independent reasons, in the order they
were measured:

1. **It did not reproduce.** Run 3, the same tree, same invocation: `optier` logged and **0
   counted**.
2. **The base tree is also green** — so there is no "green before, red after" to explain.
3. **The failure mode is a missing artifact, not a wrong answer.** `NORAW` is
   `if {$raw eq {} || ![file isfile $raw]}` — the suite's own in-scratch run produced no
   rawfile; `ZZNOTRUN` is its initialiser, i.e. the comparison never ran. That is the shape of
   a simulator that did not deliver, not of a sentence that changed.
4. ⚠ **The change is unreachable from that suite.** It references **none** of
   `run_stopped_msg`, `run_record`, `after_ckpt`, `do_stop`, `ckpt_worst_n` (grep count 0), the
   file is unmodified vs HEAD, and every behavioural delta in this issue executes only through
   `ase::ui::do_stop`, which that suite never calls.

`test_ase_optier_0963` is the suite CLAUDE.md already records as having **hung for 8 h 7 min**
on its display arm, and the regression list runs it headless only. **So T1's zero baseline is
met** — reproduced on both trees — with one intermittent red in a known-fragile real-ngspice
case, named here rather than carried forward as a count. It is **not filed**: two runs is not a
rate, but a later crew meeting `X1/X2` should read this before assuming it is new.

⚠ **The case count is 82, not 84.** All three runs agree, and so did the stale file from before
this session. The task brief and receipt 49b both say 84. Not caused by anything here and not
this pass's to resolve, but the baseline someone is comparing against has moved.

## ⚠ SECOND PASS — verifying the DELETION of the dict-shape guard

The crew acted on V1/V2 by **deleting** `if {[catch {dict size $meta}]} { return {} }` rather
than pinning it. `ase::run_record` is now five lines ending `return [lindex $cb 4]`; `src/ase.tcl`
`78adcd17…`, diff **+431 / −11** (`src/ase.tcl` **+120 / −8**). **The deletion is correct.**
Checked by measurement, not by reading their summary:

**1. Reachability — CONFIRMED, and no unnamed writer exists.** Every product writer of
`execute(callback)` in `src/*.tcl` is exactly two: `ase.tcl:16837`, built with `list` from the
**single** `set meta` in all of `run_deck` (`dict create`, line 16830 — grepped, there is no
other assignment), and `xschem.tcl:5889`, whose first word is `set_simulate_button` and which
the identity check rejects. `xschem.tcl:361` only *moves* `callback` → `callback,$id`. The
direct `ase::run_done` calls are in `tests/headless/test_ase_cosim.tcl`, which write no table
entry. **The only product caller of `ase::run_record` is `ase_window.tcl:12544`, and it is
inside a `catch`.**

**2. The threat does not reproduce — CONFIRMED.** Measured on this Tcl, all five shapes:

```
odd list {a b c} | bare word | empty | even list {aa bb cc dd} | unbalanced "{foo"
  dict exists -> 0 for every one, NO raise      ase::state_get -> {} for every one
```

**3. The raise lands two lines ABOVE the old guard — CONFIRMED, and this is the load-bearing
one.** A callback carrying an unmatched open brace raises `unmatched open brace in list` at
**`lindex`/`llength`** (`ase.tcl:16901`, the identity check) — measured directly on both — i.e.
before the removed line could ever run. Driven through the **real `ase::ui::do_stop`**, not a
synthetic path: rc **0**, nothing escapes, the CIW still receives
*"nothing of this run was written"*, `kill_running_cmds` still fired for **all three** ids, and a
good record in the same session still yields the checkpointed sentence.

⚠ **One refinement to "identically either way".** I put the guard **back** and re-ran the same
probe: every row is byte-identical except one — `ase::run_record` on an `ase::run_done`-headed
callback whose element 4 is an odd-length list returns `{a b c}` without the guard and `{}` with
it. **No caller can tell**, because `ase::state_get` answers `{}` for both (row
`C3_elem4_odd_stateget`, identical either way), and `do_stop` is the only caller. So the claim is
true of the *outcome* and not of the proc's *return value* — worth one sentence in a comment,
not a reason to keep the line.

**4. N10 — CONFIRMED.** My own arm (`ase::run_record` returns `{}` unconditionally):
`test_ase_core` **KILLED, reds CK32 CK33**; trnoise SURVIVED. The surviving body is load-bearing.

**5. CK32 still pins the identity check — CONFIRMED.** My arm dropping
`[lindex $cb 0] ne {ase::run_done}` on the *changed* proc: **KILLED, reds CK32**.

`RESTORED_CLEAN` after every arm; final positive row `test_ase_core` **652**, trnoise **80**.

### Closing measurements on the final tree

* **Both arms, rc 0, ALL PASS:** headless **652 / 118 / 80 / 49 / 235 / 87 / 76**, display
  **652 / 118 / 80 / 153 / 235 / 87 / 76**. Name diff vs `df5df4fe`: **lost = 0**, gained exactly
  `CK28f CK30 CK30b CK30c CK31 CK32 CK33 CK33b` + `NP7b`.
* **`.state` round-trip as a proc:** tracked **104**, bad `{}`, both controls **1**.
* **T1, solo, `cd tests && tclsh run_regression.tcl`:** rc 0, 362 s, **82** cases, **ZERO**
  counted, log non-empty, no `couldn't execute` / `exit 127` / `exit -1`.
  ⚠ **The md5 did NOT move (`8456b56c…`, 4721 bytes both sides) and that is correct here:**
  `results.log` is **byte-deterministic for a green 82-case run**, so two green runs are
  identical. **The mtime is what proves the rewrite** (19:09:19 → 19:33:13). It also re-reads the
  fossil I caught earlier: that file was a *previous green run*, not a corrupted one — which is
  precisely why the stale-log trap is dangerous, since the fossil is indistinguishable from a
  pass. **Check the mtime, not only the md5.**
* **Ledger:** `187 rule, 70 look, 11 suite`; `rule 1474` stamped `repo:/home/analog/dev/xschem-claude`;
  `cleared.log` unchanged at 51 lines.
* **Tree restored:** the five files at their post-deletion values, HEAD `0b0b61c0`.

## Corrections to receipt 50

| | |
|---|---|
| **V1** | ⚠ **`ase::run_record`'s dict-shape guard is pinned by no row** (arm V_DICTSIZE survives, both suites ALL PASS). The receipt presents the whole seam as validated by CK32; CK32 validates the *identity* check and the arity check, not this one. One more CK32 term closes it |
| **V2** | ⚠ **The identity check's stated threat does not reproduce.** `src/xschem.tcl`'s `simulate` writes a multi-line **string**; its `lindex 4` is `{}` and `dict size` is `0`, so `run_record` rejects it with or without the first-word check. And `ase::state_get` on malformed text returns `{}` without raising, so "arbitrary text through `ase::state_get`" overstates the harm. The check is still worth keeping and is still pinned — the *reasoning* in the comment is what is too strong |
| **V3** | **`EE5` is not apt-specific.** The receipt names `EE5/apt`; measured here, `EE5/fork` fails with the identical symptom. 1 failure in 38 independent runs. A later crew reading receipt 50 alone would look for an apt 45.2 explanation that does not exist |
| **V4** | **Correction C5 is now discharged** — see above. Accurate when written, stale now |
| **V5** | **CK31's headline is understated.** The receipt argues CK31 is not a second copy of CK30; no arm in its own campaign demonstrates it. V_CK31 here reddens CK31 alone and proves the point |

## Hygiene

* Snapshots are under `…/scratchpad/pristine/` and are **this verifier's**, taken at the
  hand-over md5s; the campaign restores from them and ends on a positive row. Nothing of mine
  can restore over a moving tree after this pass — the tree is already byte-identical to the
  snapshot, verified 5/5.
* **No background process of mine is running.** Checked by process **NAME**
  (`ps -eo comm=`, never an `-f` pattern this shell's own argv could match): no `xschem`, no
  `ngspice`, no `tclsh`, no `python3`.
* Working logs, probes and campaign output: `…/scratchpad/` (`probe1.tcl`, `probe1.out`,
  `msgprobe.tcl`, `rt.tcl`, `mut.py`, `sab.sh`, `base/`, `after/`, `afterd/`, `sab/`, `ee5/`,
  `ee5d/`).
* `…/scratchpad` is
  `/tmp/claude-1000/-home-analog-dev-xschem-claude/c8183bb1-7387-41d6-9d30-a409f8d7e1a3/scratchpad`.
