# Stage 6 — checkpointed salvage: a Stop keeps what the run had

**One commit, issue 1433, and the fifth of Stage 6.** The first is **1429** (⚖ R3's
reader seam, `595ab274`); the second **1430** (the writer, the plot sidecar and
reconciliation, `7ea9f1dc`); the third is the **1431** co-simulation golden note
(`b6b408fd`); the fourth **1432** (`noise`, `disto` and `sens`'s AC mode,
`873ab265`). Stage 5 is **1426** (`tf`), **1427** (`pz`), **1428** (`sens`, DC only).
This is **6f**.

**Floors:** `test_ase_core` 476 → **523** · `test_ase_preflight` 210 → **218** ·
`test_ase_optier_0963` 106 → **108** — **fifty-seven new rows**, and every other ASE
suite byte-unmoved. All three are in `tests/run_regression.tcl`, so **T1 covers every
row this commit adds** and nothing here is outside T1's reach.

⚠ **⚖ R3 IS STILL UNANSWERED and this issue does not touch it.** Nothing here reads a
number or moves a print line.

---

## The one sentence this task is for

**⚖ R1 was answered with a requirement neither offered option contained: *always
salvage*.** Until this commit, pressing Stop on an ASE-L run destroyed everything the
running analysis had computed — not as a trade, but because **`ngspice -b` installs no
signal handler at all**: `src/main.c` puts its whole `signal()` block inside
`if (!ft_batchmode)`, so batch takes every signal's default disposition and dies where
it stands. Nothing was being bought with the loss, which is why the user could state the
requirement flatly.

**Measured end to end, through ASE-L's own `render_deck`, on BOTH binaries, SIGTERM 6 s
into an 8,000,008-point transient:**

```
rc 143 · op and ac INTACT in the results file · plotmap still 1:1 with it (2 records, 2 plots)
checkpoint: Transient Analysis, 4,800,000 points, loadable, byte-IDENTICAL on the two binaries
no ASE-RUN-COMPLETE in the log  ->  the abort is decidable
no .ckpt.tmp left behind
```

---

## What shipped

### `src/ase.tcl` — the schema half (core `ase::`)

| proc | what it answers |
|---|---|
| `ase::ckpt_path` / `ase::ckpt_tmp_path` | `<rundir>/<cell>_ase.raw.ckpt` and its `.tmp` |
| `ase::ckpt_marker {which}` | the three deck literals, spelled once |
| `ase::ckpt_enabled` | the hidden `ase_checkpoint` lever, `ase_preflight`'s sibling |
| `ase::ckpt_floor` / `ase::ckpt_n` | the eligibility floor (100,000 points) and N = 4 |
| `ase::analysis_salvage {sim type}` | the entry's `salvage` declaration, or `{}` |
| `ase::ckpt_plan {sim row state}` | `{n step points vector}`, or `{}` |
| `ase::ckpt_rows {sim state}` | the one answer three readers share |
| `ase::run_completed {sim state logtext}` | `complete` / `aborted` / **`unknown`** |
| `ase::ckpt_report {sim state logtext}` | what a Stop kept, said once, through `ase::echo` |
| `ase::analysis_schema_errors` | **four new refusals**: `badsalvage`, `nosalvagepoints`, `badsalvagepoints`, `nosalvagevector` |
| `ase::reconcile_plots` / `ase::reconcile_report` | take the run's verdict; new `aborted` arm |

### `src/ase.tcl` — the content half (`ase::backend::ngspice`)

* `tran_points {row ?state?}` — the point-count estimate.
* the `tran` registry entry gains `salvage {points … vector time}`.
* `render_deck` gains the counter declaration, the per-analysis arming, the checkpoint
  loop and the completion marker.

### `src/ase.tcl` — the run path

* `ase::run_deck` deletes the `.ckpt` and the `.ckpt.tmp` before every run.
* `ase::run_done` reads the verdict, calls `ase::ckpt_report`, and hands the verdict to
  `ase::reconcile_report`.

**`src/ase_window.tcl` is untouched.** No new state key, no `seed_enabled`,
`ase::state_default` still seeds exactly four rows, and the **104 committed `.state`
files are byte-identical** — section **CP** of `test_ase_core.tcl` is the row that would
notice.

---

## The deck, as it now renders for a transient above the floor

```
set appendwrite
* ASE-L checkpointed salvage: a Stop keeps what this run had
let ckstep = 0                        <- ALL THREE before the first analysis
let cknext = 0
let ckdone = 0
op / <guard> / remzerovec / echo "PLOT op 0 …" >> …plotmap / write …raw
let ckstep = 1600000                  <- re-assigned per analysis; writes THROUGH to const
let cknext = ckstep
let ckdone = 0
set cktgt = $&cknext                  <- the `set` route, never `$&` on the command
echo ASE-CKPT-ARMED tran 2 1600000 8000000
stop after $cktgt
<the row's verbatim hatch, if any>    <- issue 1419's adjacency is kept (C80)
tran 10n 80m
while ckdone = 0
  if length(time) >= $cktgt           <- A MEASUREMENT, not the estimate (C73), on the
    unset appendwrite                    ARMED value (C74), with the EXIT on the FALSE
                                         branch so an unevaluable condition stops
                                         checkpointing instead of spinning (C79)
    remzerovec
    write …raw.ckpt.tmp
    shell mv -f …raw.ckpt.tmp …raw.ckpt
    set appendwrite
    echo ASE-CKPT-DONE $cktgt
    let cknext = cknext + ckstep
    set cktgt = $&cknext
    stop after $cktgt
    resume
  else
    let ckdone = 1
  end
end
delete all                            <- or the stop truncates the NEXT analysis at rc 0
<guard> / remzerovec / echo "PLOT tran 2 …" >> …plotmap / write …raw
echo ASE-RUN-COMPLETE                 <- the ONLY completeness marker
```

**The checkpoint write emits no `PLOT` record**, so the plotmap stays 1:1 and in write
order with the *results* file (issue 1430).

---

## Every measured fact this rests on

All **2026-09-12**, scratch decks under `/tmp/sv6probe`, **never a bench under
`sky130A/`** and nothing written under `~/.xschem/`. Binary 3 is
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (`ngspice-46+`); binary 1 is
`/usr/bin/ngspice` (`ngspice-45.2`). **Both were run for every measurement below, and
every one came back identical on the two unless the row says otherwise.**

### 1. The SV block, re-measured — eight rows confirmed, and one of them exactly

```
SV1  stop after does not perturb the run
     op+ac+tran, checked vs unchecked, through render_deck:
     IDENTICAL plot bodies on each binary.  fork transient sha b9836c494d9d52ad
     -- which is evidence/salvage.md's own recorded value for that deck.
SV2  stop when time > X DOES.   tran 10n 80u:  8011 rows against stop after's 8008
SV4  every checkpoint is an exact byte prefix of the final file (verified over 25.6 MB)
SV5  appendwrite STACKS:  4 checkpoints + the final write to one path
     ->  FIVE plots, 897,796 bytes, where one plot is 256,526
     with the `unset appendwrite` bracket: ONE plot
SV6  a stop armed once leaks -- see fact 4, which SHARPENS it
SV7  after a stop: $?sim_status 1, $sim_status 0, the guard prints NOTHING,
     remzerovec runs, the write succeeds, a valid 2000-point plot lands, rc 0
SV8  remzerovec and the write are undisturbed by a stop
SV10 write .tmp + shell mv -f:  no .tmp survived any completed or killed run
SV12 $& above 1e6:  7->7  1500000->1.5E+06  1234567->1.23457E+06  12345678->1.23457E+07
     100000000->1E+08, and `stop after $&big` -> "Syntax error parsing breakpoint
     specification.", nothing armed.  Through `set`: 1500000, 1234570, 12345700, 100000000
SV15 tstop/tstep + 8 -- for a BARE tran only.  See C72.
```

### 2. ⚠ The point-count estimate, and PLAN.md §6f's formula is wrong

```
tran 10n 80u          ->  8008      tstop/tstep + 8, the plan's answer
tran 10n 80u 40u      ->  4001      the plan still says 8008
tran 10n 80u 0 5n     -> 16007      the plan still says 8008
tran 10n 80u 0 20n    ->  4009      the plan still says 8008
tran 10n 80u 40u 5n   ->  8001      the plan still says 8008
tran 10n 80u uic      ->  8011      the plan still says 8008
tran 10n 160u 80u     ->  8001      tran 5n 80u -> 16008
tran 10n 80u 20u 4n   -> 15001      tran 10n 80u 0 2n -> 40006
```

`tstart` and `tmax` are **advanced fields on the shipped `tran` entry**. The rule the
numbers fit is `(tstop - tstart) / (tmax if given else tstep)` plus a constant under
twelve.

⚠ **And the dossier's "will not hold" cases hold better than it feared**, measured on
the same deck: `.options interp` → 8,001; a `pwl` source → 8,017; a `pulse` source →
**8,126 on the fork and 8,116 on apt 45.2**. Within 1.5 % of the formula — and the
**two binaries disagree**, which is a second reason a point count can never be an
exact quantity.

### 3. ⚠ Both directions of estimate error were SILENT in the plan's loop

The plan's loop terminates on `if cknext < <total>`, with `<total>` estimated from the
deck. Measured, both binaries:

```
estimate 10x HIGH (80008 for an 8008-point run)
  -> the loop ran FIVE more iterations AFTER the run had already finished,
     each writing the WHOLE rawfile again.  `resume` on a finished analysis is a
     silent no-op.  rc 0, ASE-RUN-COMPLETE printed, result correct.
estimate 10x LOW (8008 for an 80008-point run)
  -> checkpointing STOPPED at 8,005 points.  The last 90 % of the run was
     unprotected.  rc 0, nothing said.
```

### 4. ⚠ `delete all` is mandatory, and its leak is invisible on a short next analysis

```
stop after 2000 / tran 10n 80u / resume  then  ac dec 1000 1 1e6
  without delete all  ->  the AC plot has 2000 points  (it should have 6001)
  with    delete all  ->  6001
  `status` after the resume still lists  `1    stop after 2000`
```

⚠ **But the same deck with `ac dec 100 1 1e6` — 601 points — shows NO leak at all**,
because a stop only bites when the next analysis is **longer** than its threshold. A
short probe deck passes with `delete all` missing.

### 5. ⚠ The `set` route rounds to SIX significant figures, and the loop must compare against the ARMED value

```
let cknext = 1600002 ; set cktgt = $&cknext   ->   cktgt = 1600000
```

So the run stops **two points below `cknext`**, and a termination test against `cknext`
reads that as *"the analysis finished"*. Measured with exactly that loop: an
8,000,008-point run wrote **ZERO checkpoints**, completed, printed `ASE-RUN-COMPLETE`,
rc 0. **Invisible below 1,000,000 points**, which is where a short test deck lives.
`if length(time) < $cktgt` is the fix, and `if length(time) < $st` was measured to work
as a `.control` `if`.

### 6. ⚠ `maximum(time) < tstop` would NOT have worked, and it was the obvious alternative

```
tran 10n 80u  ->  print maximum(time)  =  8.000000e-05
              ->  if maximum(time) < 8e-5   TAKES THE TRUE BRANCH
```

The printed value is rounded; the stored one is just below `tstop`. A loop terminating
on that test would never terminate. Measured before it was written, not after.

### 7. ⚠ SV11's other half: `let` on an EXISTING const vector writes THROUGH

SV11's two documented halves reproduce exactly — a `let` created under `op1` is
invisible from `tran1` (`Error: &bb: no such variable.`), and one created after the
`tran` is a vector **of** `tran1` and is written into every file (`No. Variables: 5`, a
`ckdone notype dims=1` column beside `time`, `v(in)`, `v(mid)`, `i(v1)`).

**The half it does not state is the one a second `tran` row needs:**

```
let ckstep = 111          (before any analysis -> const)
op
let ckstep = 222          (re-assigned while op1 is current)
  ->  $&ckstep = 222 AND $&const.ckstep = 222        <- writes THROUGH, no shadow
tran 10n 80u
  ->  seen from tran1: 222.   Written plot: No. Variables: 4.
```

### 7b. ⚠ A `tran` IS STARVED BY A SAVE LIST THAT RESOLVES TO NOTHING, and 1432's list does not carry it

Found by a sabotage (see the table) and confirmed standalone, both binaries:

```
no save card at all           ->  rc 0, 59 rows
.save v(nosuchnode)           ->  rc 1, `Error: no data saved for Transient analysis;
                                  analysis not run`, NO tran1 plot at all
.save v(out)                  ->  rc 0, 59 rows
.save all / .save v(nosuch…)  ->  rc 0, 59 rows
```

That is issue 1432's **`disto_saves`** shape — *the whole list resolving to nothing* —
reaching a fourth analysis type, and it reports honestly (rc 1 with a message) where
`disto` SEGFAULTs. **It is out of this task's scope** and is recorded for whoever owns
the precondition set: `disto_saves` is `fatal` for `disto` alone today, and `vecsaves`
covers `noise`/`tf`/`sens` for a different reason. Nothing in this commit refuses it.

⚠ **And the same probe is why the estimate is unreliable at tiny point counts.**
`tran 1n 10n` produced **59** rows where `tstop/tstep` says 10: the whole run sits inside
the RC's own time constant, so ngspice's internal stepping — not `tstep` — sets the grid.
Negligible above the floor; a second reason the floor exists.

### 7c. ⚠ A BARE TRAILING UNIT (`10s`) DECLINES SALVAGE, AND THE DIRECTION IS SAFE

`ase::si_parse` reads a number through the adapter's own suffix table
(`meg mil t g k m u n p f a`). A SPICE-style trailing unit after a real suffix is fine —
`10ms` reads `m`, `1.5ns` reads `n` — but a **bare** unit letter is not a suffix:
`10s` answers `{bad unknownsuffix}`, `tran_points` answers `{}`, `ckpt_plan` answers `{}`
and **no checkpoint block is emitted.** The deck is then exactly what it was before this
issue, which is the safe direction, and it is silent.

⚠ **Measured against the tree's own data before it was called acceptable**: of the 104
committed `.state` files, every `tran` `stop` value parses (`6u`, `20n`, `1m`, `100u`,
`125`, `1.5`, `100G`, …) and not one carries a bare unit. The one fixture in the tree
that does is `test_ase_window.tcl`'s **W7** — `tran 1n 10s`, the GUI's long-run Stop
test — which is therefore **unaffected by this commit**: it renders no checkpoint block.
That is worth knowing rather than discovering, because W7 is the row a reader would
expect this feature to change.

### 8. The floor, and it is a number this crew picked

`PLAN.md` §6f says so in as many words. Measured on the reference RC, both binaries:

```
8,008 points   0.11 s        80,008 points  0.11-0.21 s        800,008 points  0.91 s
```

About 900k output rows a second on the fastest circuit shape there is. `ase::ckpt_floor`
is **100,000 points** — a tenth of a second on that RC, minutes on a transistor-level
deck, and eight times below the 800,008-point reference the plan names as its anchor.

### 9. END TO END, THROUGH ASE-L's OWN `render_deck`, ON BOTH BINARIES

A state with `op` + `ac dec 100 1 1e6` + `tran 10n 80m`, rendered by
`ase::backend::ngspice::render_deck`, run in a scratch directory under `/tmp` with an
explicit `rundir`. **Row for row identical on the two binaries.**

```
COMPLETED RUN          rc 0
  log:      ASE-CKPT-ARMED tran 2 1600000 8000000
            ASE-CKPT-DONE 1600000 / 3200000 / 4800000 / 6400000 / 8000000
            ASE-RUN-COMPLETE
  plotmap:  PLOT op 0 |Operating Point| / PLOT ac 1 |AC Analysis|
            PLOT tran 2 |Transient Analysis|          <- THREE records
  results:  Operating Point 1pt / AC Analysis 601pt / Transient Analysis 8,000,008pt
            No `constants` record anywhere.  No .ckpt.tmp left.
  ase::run_completed -> complete;  ase::ckpt_report deletes the 256 MB .ckpt and says nothing

STOPPED RUN (SIGTERM at 6 s)   rc 143
  log:      ASE-CKPT-ARMED …  /  ASE-CKPT-DONE 1600000 / 3200000 / 4800000
            NO ASE-RUN-COMPLETE
  plotmap:  TWO records, and the results file holds TWO plots -- still 1:1
  results:  Operating Point 1pt / AC Analysis 601pt, intact
  ckpt:     Transient Analysis, 4,800,000 points, sha of the body IDENTICAL on the
            two binaries, loads in ngspice (`load` -> `const tran1`,
            maximum(time) = 3.199992e-02 of the 0.08 s asked for)
  ase::run_completed -> aborted
  ase::ckpt_report   -> "this run was stopped: the analyses that finished are in the
                        results file, and the 'Transient Analysis' plot the simulator
                        was still filling was kept at 4800000 points of an estimated
                        8000000, in probe_ase.raw.ckpt."
  ase::reconcile_plots without the verdict -> predmismatch, naming TWO causes
  ase::reconcile_plots with `aborted`      -> aborted, naming ONE
```

⚠ **One cross-binary difference worth recording and not this stage's to fix:** the fork
and apt 45.2 produce **different transient bodies for the same deck** (`b9836c…` against
`648328…`) while their `op` and `ac` bodies are byte-identical. Checked-versus-unchecked
identity holds **within** each binary, which is what SV1 claims.

---

## What the plan and the tree said that this refuted

The batch's seventy-second through eightieth corrections (Stage 5 took C43–C55,
issue 1429 C56–C59, 1430 C60–C64, 1432 C65–C71).

### C72 — SV15's `tstop/tstep + 8` is wrong for three of the five shapes the shipped `tran` row can produce

Fact 2. `tstart` and `tmax` are advanced fields on the entry, and the plan's formula
ignores both. `ase::backend::ngspice::tran_points` implements
`(tstop - tstart) / (tmax ? tmax : tstep)`; row **CK8** carries six fixtures that each
disagree with the plan's formula in a different direction.

### C73 — and PLAN.md §6f's loop made BOTH directions of that error silent

Fact 3. The plan's `if cknext < <total>` is a test against an **estimate**. The loop
shipped here asks the simulator whether **its own breakpoint** fired —
`if length(time) < $cktgt` — so an over-estimate costs nothing and an under-estimate
buys more checkpoints rather than an unprotected tail. The estimated total therefore
appears nowhere in the deck's control flow; row **CK13b** asserts that.

### C74 — the loop must compare against the ARMED value, because `set` rounds to six significant figures

Fact 5. This is SV12's trap one level over: SV12 says `$&` on the *command* is fatal
above 1e6, and the `set` route is the fix. What nobody had measured is that the `set`
route's **rounding** then makes `cktgt` ≠ `cknext`, so a loop that terminates on
`cknext` stops checkpointing entirely — at rc 0, with the completion marker printed,
and only above 1,000,000 points.

### C75 — `maximum(time) < tstop` is the obvious alternative and it does not work

Fact 6. Recorded because it is what the next reader will reach for: `maximum(time)`
prints as `8.000000e-05` at the end of `tran 10n 80u` and compares as **less than**
`8e-5`. A loop terminating on it never terminates.

### C76 — SV11 does not say that a `let` on an EXISTING const vector writes through

Fact 7. Both of SV11's halves reproduce; the third fact is the one a multi-`tran` state
depends on, and without it the per-analysis interval would have to be unrolled into one
counter set per row.

### C77 — SV6's leak is invisible whenever the next analysis is shorter than the threshold

Fact 4. A `delete all` row written against a short next analysis is a row that cannot
fail. The suite's fixture (**CK16**) uses `noise`, which is rank 40 and genuinely
downstream of `tran`'s 30 — `op` is rank 10 and renders **first** whatever order the
state lists it in, so an `op` control would have asserted that `delete all` precedes
nothing at all.

### C78 — the completion marker cannot be unconditional, so the verdict is three-state

`PLAN.md` §6f writes *"the deck echoes a completion marker after the last analysis"*
without qualification, and `DECISIONS.md` D40 the same. An unconditional line moves
**every deck golden a second time**, which the plan's own eligibility-floor paragraph
forbids in as many words (*"they move at this stage for 6a's PLOT line; they must not
move twice"*). The marker is emitted only by a deck that checkpoints, and
`ase::run_completed` answers **`unknown`** for a run that promised none — a two-state
reader would mark every ordinary run aborted.

### C79 — the loop's EXIT must be the FALSE branch, because an unevaluable condition spins forever

**Found by the sabotage that deleted the eligibility floor, on a fixture
`test_ase_preflight` already had, and it cost a 500-second suite timeout to surface.**
That file's one live `run_real` deck saves `v(nosuchnode)` and nothing else. MEASURED on
both binaries, standalone:

```
.save v(nosuchnode) + tran 1n 10n
  ->  rc 1, `Error: no data saved for Transient analysis; analysis not run`
  ->  NO tran1 plot at all: $plots = const, $curplot = const
  ->  `length(time)` is UNEVALUABLE.  The only trace:
      `Warning from checkvalid: vector time is not available or has zero length`
      -- on **stderr**, where nothing in this tree looks.
```

`.control`'s `if` takes the **false** branch for a condition it cannot evaluate —
measured for `<`, `>` and `>=` alike, on both binaries — which is the trap table's
string `eq`/`ne` shape arriving on a **number**. The first cut's loop exited on the
**true** branch, so it checkpointed, re-armed and `resume`d **forever**, at rc 0,
rewriting the same 673-byte file every three seconds. `resume` on an analysis that never
ran is a silent no-op, so nothing ever advanced.

**The fix is the polarity, and it is provably sufficient.** With
`if length(<v>) >= $cktgt` the continue path is the TRUE branch and the exit is the
false one, so an unevaluable condition **stops checkpointing** instead of spinning.
Measured on both binaries: the starving deck takes **0 checkpoints** and reaches
`LOOPDONE`; the healthy one still takes 5 and keeps 800,000 points. And the loop is then
finite by construction — `cknext` grows by `ckstep` every pass, `ckstep` is at least 1 by
`ckpt_plan`'s own check and is in practice a fifth of the estimate, far above the `set`
route's six significant figures — so no iteration cap is emitted.

⚠ **The eligibility floor is what kept this out of the shipped configuration**, which is
a much stronger reason for the floor than *"there is nothing to salvage below it"*, and
it is now written in the code as such.

### C80 — the arming block must sit ABOVE the verbatim hatch, and rows VB1/VB2 were green while it did not

Found by the sabotage that lowered `ase::ckpt_floor` to 1000. Issue **1419** put the
per-analysis verbatim hatch **immediately above its own analysis line**, and
`test_ase_core`'s **VB1** and **VB2** assert exactly that adjacency. The first cut of the
arming block sat between them — and both rows stayed **green**, because every
`x`-carrying fixture in this tree is a short `tran` and the block was never emitted near
one. A user with a long transient **and** a verbatim hatch would have got the same deck,
silently.

The arming now precedes the hatch, and row **CK10b** holds it **at the shipped floor**,
so it does not depend on a sabotage to be true. ⚠ The cost is named rather than hidden:
a hatch that itself contains `delete all` or a `stop` now disarms that analysis's
checkpointing — which is the user writing ngspice commands into their own deck and
getting them, and the alternative was breaking another issue's tested invariant to
defend against it.

---

## ⚠ THE PLAN DEVIATION THIS TASK INHERITED, AND IT IS NOT THE ONE THE BRIEF EXPECTED

`PLAN.md` §6f says the checkpoint lines *"ride in the SAME re-baseline as the sidecar
line, not a second one"*. The driver's brief recorded that as already broken — issue
1430 moved `test_ase_core`'s deck golden **D1** for the sidecar, and this change would
move it a second time.

**It did not, and the reason is better than the prediction: NO DECK GOLDEN MOVED AT
ALL.** D1's fixture is `op`-only, so it renders no checkpointed analysis; row **CK18**
asserts that a deck below the floor is **byte-identical to the same deck with
`set ase_checkpoint 0`**, with **CK18b** as its non-vacuity control (above the floor the
two differ). `test_ase_preflight`'s `deck_of` fixture is `tran 1n 1u` — a thousand
estimated points against a floor of 100,000 — so PF218a–h are unmoved too, and
**PF231a** is what says so rather than assuming it.

So the plan's *"one re-baseline"* sentence is false, but in the user's favour: **1430
spent the budget and 6f needed none of it.** The eligibility floor is what buys that,
and it is the reason the floor is a requirement rather than an optimisation.

---

## Suites moved, before → after

| suite | headless | display (`:99`) | in T1? |
|---|---|---|---|
| `test_ase_core` | 476 → **523** | **523** | yes (`run_regression.tcl:75`) |
| `test_ase_preflight` | 210 → **218** | **218** | yes (`:29`) |
| `test_ase_optier_0963` | 106 → **108** | **TIMEOUT** — see below | yes (`:67`) |
| `test_ase_simcaps_0948` | 199 → 199 | not run | yes (`:66`) |
| `test_ase_cosim` | 341 → **341** | not run | ⚠ **no** — issue 1421's list |
| every other ASE suite (25) | unmoved | not run | — |

New sections: **CK** in `test_ase_core.tcl` (47 rows), **PF231** in
`test_ase_preflight.tcl` (8 rows), rows **E5e / E5f** in `test_ase_optier_0963.tcl`.
All three floor paragraphs raised in the same change.

The display arm was taken through `tests/headless/run_suites.sh` with
`SUITE_TIMEOUT=400`, which reported *"display arm: ATTACHED to persistent dev display
:99 (devdisplay.sh), GUI_GATE=0"* — `devdisplay.sh status` before the run: alive,
openbox (Openbox 3.6.1), `1920x1080x24`. **`2/2 runs passed.`**

⚠ **`test_ase_optier_0963`'s display arm TIMED OUT at 400 s, and it is the filed
pre-existing stall**, not a regression: `CLAUDE.md` names it (*"86 of 103 rows, stops
after row N3"*), and the three Stage 5 crews and the 1429, 1430 and 1432 crews all hit it
in the same place. Its **headless** arm — the one `run_regression.tcl` runs — is **ALL
PASS (108)** before and after. Bounded by `run_suites.sh`'s own per-arm `timeout`, and
`pgrep -af src/xschem` afterwards shows **no orphan from this run** (the only live one
belongs to the other clone, `xschem-op-wcard`).

⚠ **AND THE DISPLAY ARM WROTE `~/.xschem/geometry` AGAIN, at 21:40:18.** Issue **1397**,
already on the user's queue and already reported by issues 1430 and 1432's crews. Every
one of this crew's own invocations honoured the rule — `--nogui --pipe -q --nolog`, a
path to the binary, a scratch `rundir` under `/tmp`, no bench under `sky130A/` — but
`run_suites.sh`'s display arm launches xschem **without** `--nogui`, so a real window
opens and saves its size on exit. ⚠ **This suite's subject is DECK TEXT and pure-Tcl
procs, none of which has an X dependency**, so the display arm added no information here;
it was taken only so the number is comparable with the two receipts before it. The brief
is right that `--nogui` is the arm for this change.

⚠ **THE WHOLE ASE FAMILY (30 suites) WAS RE-RUN HEADLESS after the last edit**, every
run `timeout 500`-bounded so a stall would be a NAMED outcome: **25 ALL PASS, 5
self-skips** (`test_ase_bus_bits_0159`, `test_ase_dirty`, `test_ase_log_seam_0207`,
`test_ase_simdlg_0937` and `test_ase_cosim`'s REF12 leg, every one of which says in its
own first line that it needs an X connection or a mixed-signal artefact). ⚠
**`test_ase_window` is ALL PASS (56)**, which is worth naming: its row **W7** is the
GUI's long-run Stop test and the one a reader would expect this feature to change — it
does not, because `tran 1n 10s` carries a bare unit that `si_parse` declines (fact 7c).
`test_cosim_golden_e2e` is **45 passed / 1 failed** — row **GE24**, the one known red,
issue **1431**, unchanged and not in T1.

### ⚠ ONE EXISTING ROW MOVED, AND IT IS NOT A GOLDEN

`test_ase_core.tcl`'s **RC10** pins the *shape* of the reconciliation call in
`ase::run_done`, and that call now reads `catch {ase::reconcile_report $state
$runstate}`. The row is right to move: `PLAN.md` §6f requires in as many words that
*"6c's reconciliation must be told the run was aborted BEFORE it reports an under-count,
or every stopped run logs 'one plot of the `tran` analysis was not captured' as though
something were wrong."* The verdict has to reach it, and RC10 is the row that would
notice if it stopped doing so.

### ⚠ AND THE BRIEF'S SCOPE-IN QUESTION, ANSWERED BY MEASUREMENT

The brief asked whether `reconcile_plots`' `predmismatch` sentence — whose first named
cause issue 1430 corrected to *"the run stopped before the rest"* — is still right for a
salvaged run. **It is**, and it was checked against the artefacts of a real stopped run
rather than reasoned about: the four-argument call answers `predmismatch` and names both
causes, which is the honest answer when nothing measured which one it was. The
five-argument call names only the one the marker's absence measured. Rows **CK24** and
**CK24b** pin both, and **CK24d** pins that the four-argument call is unchanged.

---

## The sabotage table

**Two passes, seventy-two respellings of `src/ase.tcl` in all**, each a plausible
rewrite rather than a break — the tidy-up somebody would actually make. Restore was `cp`
from `/tmp/sv6probe/good_ase.tcl` with a `cmp` after **every** one; every restore was
verified before the next sabotage ran, and the log records `RESTORED-OK` for all
seventy-two.

⚠ **Each sabotage was run against the suites that should see it and no others**, so a
blank column below means "not run", never "green". All three suites were run together,
green, before each pass and again after it.

⚠ **AND A FIRST ATTEMPT AT THE CAMPAIGN MEASURED NOTHING, LOUDLY.** The driver passed
each respelling to a shell script as an argument with a `\0` separator. **Bash arguments
cannot contain NUL**, so all fifty-four arrived truncated and the driver printed
fifty-four `PATCH-FAILED` lines and restored. That is reported rather than quietly
re-run: a campaign whose failures are invisible measures fewer things than its table
claims (issue 1432's S24, one layer down). The specs move through a JSON file now.

### Pass 1 — fifty-four respellings against the first cut

| # | the respelling | rows reddened |
|---|---|---|
| S01 | ckpt_path answers the results file's path ("beside it anyway") | core **CK1** |
| S02 | ckpt_tmp_path drops the .tmp suffix | core **CK2** |
| S03 | ckpt_path returns {} for a cell-less state instead of raising | core **CK1b** |
| S04 | the completion marker is respelled | core **CK3** **CK10** **CK17** **CK22** **CK22b** **CK23b** **CK23d** · preflight **PF231g** |
| S05 | ckpt_marker answers the armed literal for an unknown key | core **CK3** |
| S06 | ckpt_enabled ignores the hidden variable ("it is always on") | core **CK7** **CK18b** |
| S07 | the floor is lowered to 1000 points | core **VB1** **VB2** **CK5** **CK5b** **CK9** **CK17** **CK18** **CK22** **CK23c** · preflight **PF218c** **PF221al** **PF231a** |
| S08 | N becomes 1 ("one checkpoint is enough") | core **CK4** **CK9** **CK10** **CK13b** **CK19** |
| S09 | the clamp is dropped | core **nothing** |
| S10 | the floor test is dropped from ckpt_plan | core **VB1** **VB2** **CK5** **CK5b** **CK9** **CK17** **CK18** **CK22** **CK23c** · preflight **TIMEOUT** · optier **E5** **E5f** **M1** |
| S11 | ckpt_plan stops requiring the `vector` key | core **nothing** |
| S12 | ckpt_plan trusts the hook name without checking it is a command | core **nothing** |
| S13 | the interval is points/N instead of points/(N+1) | core **CK4** **CK9** **CK10** **CK13b** **CK19** |
| S14 | analysis_salvage answers the entry rather than the salvage key | core **nothing** |
| S15 | tran_points ignores tstart | core **CK8** **CK8b** |
| S16 | tran_points ignores tmax | core **CK8** |
| S17 | tran_points reads the raw strings instead of ase::si_parse | core **CK4** **CK5b** **CK7** **CK0** |
| S18 | tran_points truncates instead of rounding | core **CK8** |
| S19 | ckpt_rows forgets the op_last argument and always sorts op first | core **nothing** |
| S20 | run_completed is two-state ("unknown is padding") | core **CK22** **CK23c** |
| S21 | run_completed matches the marker as a substring | core **CK22b** |
| S22 | ckpt_report keeps the checkpoint after a completed run | core **CK23b** **CK23d** |
| S23 | ckpt_report speaks for an unchecked run too | core **CK23c** |
| S24 | the aborted sentence drops the point count | core **CK23** |
| S25 | the zero-points arm is dropped | core **CK23d** |
| S26 | reconcile_plots ignores the runstate argument | core **CK24** **CK24b** |
| S27 | a Stop converts `over` as well | core **CK24c** |
| S28 | a Stop wins over `mislabel` | core **CK24c** |
| S29 | the aborted predmismatch sentence keeps the two-cause wording | core **CK24** |
| S30 | reconcile_report tags an aborted run as a fault | core **CK24e** |
| S31 | reconcile_report drops the verdict on the floor | core **nothing** |
| S32 | run_done reports salvage AFTER reconciliation | core **nothing** |
| S33 | run_deck stops deleting the stale checkpoint | core **CK25b** **CK25c** |
| S34 | run_deck stops deleting the torn temp | core **CK25b** **CK25c** |
| S35 | the counters are declared inside the analysis loop instead | core **CK10** **CK19** · preflight **PF231d** |
| S36 | the threshold goes through $& directly | core **CK10** **CK12** · preflight **PF231b** **PF231c** |
| S37 | the primitive becomes `stop when time` | **PATCH-FAILED** |
| S38 | the loop terminates on cknext instead of the armed target | core **CK13** · preflight **nothing** |
| S39 | the loop terminates on the estimated total, as the plan's recipe does | core **CK10** **CK13** **CK13b** |
| S40 | the appendwrite bracket is dropped | core **CK10** **CK14** · preflight **nothing** |
| S41 | appendwrite is never restored after the checkpoint write | core **CK10** **CK14** |
| S42 | the checkpoint is written straight to its final path (no tmp+rename) | core **CK10** **CK11** **CK14** · preflight **nothing** · optier **E5e** |
| S43 | the checkpoint write goes into the results file | core **CK11** **CK21** · preflight **nothing** · optier **nothing** |
| S44 | the checkpoint write records a PLOT line too | core **CK10** **CK15** **CK21** · preflight **nothing** |
| S45 | `delete all` is dropped | core **CK10** **CK16** **CK16b** **CK21** · preflight **PF231e** |
| S46 | `delete all` moves inside the loop, before the resume | core **CK10** **CK16** **CK16b** **CK21** |
| S47 | the loop is emitted above the analysis instead of below it | core **D1** **D2** **D7f2** **D8a** **D8b** **D8c** **D8d** **D8e** **D8f** **D8g** **D8h** **C4** **C5** **D6** **D6** **E1a** **E1b** **E1c** **E1f** **VB1** **VB2** **TF4** **TF4b** **TF4c** **PZ4** **PZ4b** **PZ4c** **SE4** **SE4b** **SE4c** **CK7** **CK10** **CK16** **CK21** · preflight **PF218c** **PF221al** **PF220** **PF220b** **PF220c** **PF220d** **PF225d** **PF231d** **PF231e** |
| S48 | the completion marker is emitted unconditionally | core **D1** **C4** **C5** **CK7** **CK17** |
| S49 | the completion marker is emitted after .endc | core **CK17** |
| S50 | the ARMED echo carries no interval | core **CK13b** |
| S51 | the tran entry loses its salvage key | core **CK4** **CK5b** **CK6** **CK7** **CK9** **CK10** **CK11** **CK12** **CK13** **CK13b** **CK14** **CK15** **CK16** **CK16b** **CK17** **CK18b** **CK19** **CK21** **CK22** **CK22b** **CK23** **CK23b** **CK23d** · preflight **PF231a** **PF231b** **PF231c** **PF231d** **PF231e** **PF231f** **PF231g** · optier **E5e** |
| S52 | the salvage schema refusals are deleted | core **CK26** |
| S53 | the nosalvagevector refusal alone is deleted | core **CK26** |
| S54 | per-analysis counters are declared once and never re-assigned | core **CK10** **CK19** |

### ⚠ WHAT PASS 1 BOUGHT, AND WHY THERE IS A PASS 2

Four sabotages changed the shipped code, so every sabotage whose anchor they moved was
re-run with an `r` suffix and four new ones were written for the properties the changes
established. **The campaign owned the working tree while it ran; every measurement in
this receipt outside the table was taken before it started or after it finished.**

* **S10** (the eligibility floor deleted) → **the infinite loop, C79.** Its
  `test_ase_preflight` arm is the `TIMEOUT` row above: rc 124 and a `FATAL` after 500
  seconds, which is the bound doing its job. The loop's polarity is now fail-safe.
* **S07** (the floor lowered to 1000) → **the arming block's position, C80.** It
  reddened **VB1** and **VB2**, issue 1419's adjacency rows, which were green while the
  block sat between the verbatim hatch and its analysis.
* **S09** (the `[2, 50]` clamp deleted) → **nothing**, because the shipped `ckpt_n`
  answers 4 and 4 is inside the clamp. Row **CK4b** stubs the proc, the way issue 1429's
  **RS3** performs ⚖ R3's two rulings.
* **S11 / S12** (`ckpt_plan`'s `vector` requirement and its `info commands` guard
  deleted) → **nothing**, because the shipped registry declares a good `salvage` on its
  one salvageable type. Row **CK27** drives the planner through the four fixtures the
  validator already had.
* **S19** (`ckpt_rows`' `op_last` argument dropped) → **nothing.** Membership does not
  depend on the emit order and no caller varied it, so **the parameter was deleted**
  rather than given a fixture, and **CK9** gained the fixtures that say the answer is
  order-independent. **S58** is what a sabotage on the remaining body looks like.
* **S47** as applied deleted `lappend lines $aline` rather than moving the loop, so it is
  a blunt break and not a plausible respelling. It reddened seventeen rows including
  every deck golden. Reported as mis-specified rather than counted as a finding.

### Pass 2 — eighteen respellings against the corrected code

| # | the respelling | rows reddened |
|---|---|---|
| S09r | the clamp is dropped -- re-run against the row it bought | core **CK4b** |
| S11r | ckpt_plan stops requiring the `vector` key -- re-run | core **CK27** |
| S12r | ckpt_plan trusts the hook name without checking it is a command -- re-run | core **nothing** |
| S36r | the threshold goes through $& directly -- re-run | core **CK10** **CK10b** **CK12** · preflight **PF231b** **PF231c** |
| S37r | the loop's primitive becomes `stop when time` -- re-run | core **CK10** **CK12** · preflight **PF231b** |
| S38r | the loop terminates on cknext instead of the armed target -- re-run | core **CK13** · preflight **PF231h** |
| S39r | the loop terminates on the estimated total, as the plan's recipe does -- re-run | core **CK10** **CK13** **CK13c** **CK13b** |
| S40r | the appendwrite bracket is dropped -- re-run | core **CK10** **CK13c** **CK14** · preflight **nothing** |
| S41r | appendwrite is never restored after the checkpoint write -- re-run | core **CK10** **CK13c** **CK14** |
| S42r | the checkpoint is written straight to its final path (no tmp+rename) -- re-run | core **CK10** **CK11** **CK13c** **CK14** · preflight **nothing** · optier **E5e** |
| S43r | the checkpoint write goes into the results file -- re-run | core **CK11** **CK21** · preflight **nothing** |
| S44r | the checkpoint write records a PLOT line too -- re-run | core **CK10** **CK15** **CK21** · preflight **nothing** |
| S45r | `delete all` is dropped -- re-run | core **CK10** **CK16** **CK16b** **CK21** · preflight **PF231e** |
| S46r | `delete all` moves inside the loop, before the resume -- re-run | core **CK10** **CK13c** **CK16** **CK16b** **CK21** |
| S55 | the loop's polarity is flipped back, so the EXIT is the true branch | core **CK10** **CK13** **CK13c** · preflight **PF231h** |
| S56 | the arming block moves back below the verbatim hatch | core **VB1** **VB2** **VB3** **CK10b** |
| S57 | the verbatim hatch is dropped from a checkpointed analysis | core **VB1** **VB2** **VB3** **CK10b** |
| S58 | ckpt_rows stops asking analysis_emit_order and walks the rows itself | core **CK9** |

### The survivors, and what each one bought

**S09 — the `[2, 50]` clamp deleted — changed nothing**, because `ase::ckpt_n` answers 4
and 4 is inside the clamp: **a bound with no value outside it is unasserted by
construction**, which is issue 1430's S29 lesson (a verdict precedence with no colliding
fixture) arriving at a numeric range. **CK4b** stubs `ckpt_n` to 1 and to 200 and asserts
2 and 50 come back, with the shipped value passing through untouched. **S09r** reddens it.

**S11 and S12 — `ckpt_plan`'s two guards deleted — changed nothing**, for the same
reason one level over: the shipped ngspice registry declares exactly one `salvage`, and
it is a good one. **CK27** drives the planner through the four `cksim` fixtures the
validator already had. **S11r** reddens it.

**S12r survived even then, and that is a DEAD LINE rather than a weak row.** With the
`info commands` guard deleted the planner still answers `{}` for a hook that is not a
command, because the `catch` one line down already does — *"invalid command name"* is an
error like any other. ⚠ **The line was deleted**, exactly as issue 1432's S32 deleted a
`string trimright` another line had already made unreachable. The registry-facing half is
a different line and has its own fixture: `analysis_schema_errors` refuses a
`badsalvagepoints` at load time, and **CK26** is what says so.

**S19 — `ckpt_rows`' `op_last` argument dropped — changed nothing**, and the parameter
went with it. See above.

### The one that could not be applied

**S37 named an anchor that was not in the file** — I wrote it against the arming's
`stop after` and the loop's `resume`, which are not adjacent — and the driver printed
`PATCH-FAILED (ANCHOR0)` and restored before running anything. ⚠ **That is the driver
doing its job and it is reported rather than quietly re-run.** Re-specified as **S37r**
against the loop's own `stop after`, which reddens **CK10**, **CK12** and **PF231b**.

### The rows that a sabotage proved were doing MORE than their own job

* **S07** and **S10** both reddened **VB1** and **VB2** — issue 1419's verbatim-hatch
  adjacency rows, which know nothing about checkpointing. They were right to redden, and
  they are the reason C80 exists.
* **S48** (the completion marker emitted unconditionally) reddened **D1**, **C4** and
  **C5** — the tree's only deck golden and its two comparators. ⚠ **That is C78 proved by
  the goldens themselves**: an unconditional marker is exactly the second re-baseline the
  plan's own floor paragraph forbids.
* **S51** (the `tran` entry's `salvage` key deleted) reddened **twenty-one** rows across
  the CK section, which is what a registry key that four procs read looks like when it
  goes away — and it is the reverse control for CK6, which asserts that every *other*
  type declares none.

---

## What I did NOT ship, and why

* **`dc` and `ac` salvage.** Both stop and resume correctly, but the full loop has never
  been run against either and `dc`'s sweep-variable plot may meet the
  `unset appendwrite` bracket differently. `ase::analysis_salvage` answers `{}` for
  them, and adding the key is one measurement each. D41.4: absent means **not
  measured**, never "no salvage needed".
* **`noise` and `disto` salvage, ever.** A stop there leaves an incomplete plot **SET**,
  not a short plot — `noise1` without `noise2` — so a salvaged one would be a wrong
  answer wearing a partial one's label.
* **SV14's `N + 1 = sqrt(T × B / S)`.** Its inputs do not exist: T and S come from a
  *previous* run of this bench, which ASE-L does not record, and B is page-cache
  throughput that moved ±30 % between sittings on one machine. `PLAN.md`'s own answer
  for "T and S unknown" is N = 4, which is what `ase::ckpt_n` returns — in one proc,
  with the clamp already written.
* **Anything in `src/ase_window.tcl`.** The consequence is named rather than hidden:
  **the partial result is not LABELLED in the window.** `PLAN.md` §6f puts *"the
  partial-result label with how far it got"* and 2e's launch sentence in that file, and
  this task may not touch it. What a Stop produces today is a `.ckpt` beside the results
  file and a sentence in the log and the CIW; what it does not produce is a second
  attached dataset marked *partial*. That is the next window stage's first item.
* **A `maximum(time)` figure in the salvage sentence.** The plan asks for *"stopped at
  48.0 ms of 80 ms"*. Reading `maximum(time)` out of a binary rawfile needs a binary
  reader; `ase::cap_raw_plots` reads the ASCII header, so the sentence says **points**,
  which is measured, rather than a simulated time that would have to be inferred.
* **A backoff when the realized checkpoint count exceeds N.** With the corrected
  estimate the error is ≤ 1.5 % on every shape measured, including `pulse`, `pwl`,
  `.options interp`, `tmax`, `tstart` and `uic`, so the realized count is N or N+1. The
  bound is stated rather than enforced, and it is named in the code as the one thing
  that would bite if a future `tran` field changed the point count in a way the formula
  does not carry.
* **An `info commands` guard in `ase::ckpt_plan`.** It was written, a sabotage proved it
  dead (the `catch` one line down already answers `{}` for a hook that is not a command),
  and it was deleted. The registry-facing half — `analysis_schema_errors`' own
  `badsalvagepoints` refusal, which is what tells an adapter author — stays, and has its
  own fixture in **CK26**.
* **An iteration cap in the deck's loop.** With the fail-safe polarity the loop is finite
  by construction: `cknext` grows by `ckstep` every pass, `ckstep` is at least 1 and in
  practice a fifth of the estimate, so the target must eventually exceed any bounded
  `length()`. A cap would be two more lines and a nested `if` defending nothing.
* **`seed_enabled`, anywhere.** Four seeded rows, 104 byte-identical `.state` files,
  section CP unmoved.
* **Any change to `render_deck`'s print anchor, its `$sim_status` guard, its
  `remzerovec` placement, its `.save` cards or the plotmap record.** Rows **WK7**,
  **CK15**, **CK21** and **PF231e/f** assert every one of them is still where issues
  1243, 0964, 0929, 0963 and 1430 put it.

---

## What this stage learned that binds later ones

**THE BRANCH A CONDITION FALLS INTO WHEN IT CANNOT BE EVALUATED IS A DESIGN DECISION,
AND IT IS THE ONE NOBODY MAKES ON PURPOSE.** `.control`'s `if` takes the **false** branch
for a condition it cannot evaluate — measured here for `<`, `>` and `>=` — which the trap
table already records for string `eq`/`ne` and which nobody had carried over to numbers.
A loop whose EXIT is the true branch therefore runs forever the moment its condition
becomes unevaluable, at rc 0, and the only warning goes to **stderr**. ⚠ **Put the exit on
the false branch of every generated loop**, so that "I cannot tell" and "stop" are the
same answer. It cost a 500-second suite timeout to find, and only because a sabotage
deleted the guard that was keeping the shape out of reach.

**AND A GUARD THAT KEEPS A DEFECT UNREACHABLE IS WORTH MORE THAN ITS STATED REASON.** The
eligibility floor was written for *"there is nothing a user would press Stop over below
it"*. What it was actually doing, unknown to the crew that wrote it, was keeping the only
deck in this repository that can hang the checkpoint loop out of the emitter's reach. ⚠
**When a sabotage on a guard produces a failure that is not about the guard, read the
failure**, not the guard.

**A PLAN'S ARITHMETIC IS AS CHECKABLE AS ITS TABLE AND ITS PREDICATE, AND THIS ONE WAS
WRONG.** Issue 1430's lesson was *"measure the table, not only the conclusion"*; 1432's
was the same about a **predicate**. This is the same failure about a **formula**:
`tstop/tstep + 8` is exactly right for the deck the dossier measured it on and wrong for
three of the five shapes ASE-L's own form can produce, because the dossier's deck had no
`tstart` and no `tmax` and the form has both. ⚠ **When a plan quotes a formula, check it
against the FIELDS THE PRODUCT OFFERS, not against the deck the formula was derived
from.**

**A LOOP THAT TERMINATES ON AN ESTIMATE FAILS SILENTLY IN BOTH DIRECTIONS, AND THE
SIMULATOR KNOWS THE ANSWER.** The plan's recipe ends its loop on the number it guessed.
Ten times high wasted five whole-rawfile writes; ten times low left 90 % of a run
unprotected; both at rc 0. One line — `if length(time) < $cktgt` — replaces the guess
with a question the simulator can answer, and the estimate is demoted to what it is
honestly good for: choosing an interval. ⚠ **Ask the thing that knows.**

**THE ROUNDING IN A WORKAROUND IS ITS OWN TRAP.** `set cktgt = $&cknext` exists because
`$&` on the command line is a syntax error above 1e6 (SV12). The dossier records the
fix's rounding as harmless — *"a checkpoint threshold is approximate and that is fine"* —
and it is, **for the threshold**. It is not fine for anything that compares against the
unrounded counter, which is a use the dossier never had. ⚠ **A documented "harmless"
side effect is harmless only for the uses that existed when it was documented.**

**A LEAK THAT ONLY APPEARS WHEN THE NEXT THING IS BIGGER CANNOT BE CAUGHT BY A SMALL
FIXTURE.** SV6's `delete all` requirement is real and was reproduced — but only with an
`ac` of 6,001 points. The same deck with 601 points showed nothing at all. ⚠ **When a
rule is about one step affecting the NEXT one, the fixture's second step has to be
bigger than the first**, and *"a row whose fixtures never disagree cannot fail"* has a
sibling: **a row whose second fixture is too small cannot disagree.**

**AND THE OBVIOUS ALTERNATIVE WAS REFUTED IN FOUR MINUTES BY RUNNING IT.**
`maximum(time) < tstop` reads as self-evidently the right termination test. It prints
`8.000000e-05` and compares as *less than* `8e-5`. ⚠ **The alternative you did not take
is worth one deck**, because the next reader will take it.

**A PARAMETER NO CALLER VARIES IS A PARAMETER NO ROW CAN DEFEND.** `ase::ckpt_rows`
shipped its first cut with an `op_last` argument, because
`ase::analysis_emit_order` takes one. The sabotage that dropped it left the suite at ALL
PASS — membership does not depend on the emit order, and all three callers passed the
default. ⚠ **It was deleted rather than given a fixture**, which is issue 1432's S32
lesson (a dead line is deleted, not defended) arriving at a signature instead of a line.
The row that replaced it asserts the property that made the parameter pointless: the
answer is the same whichever order the rows are listed in.

**A SABOTAGE CAMPAIGN THAT CANNOT PASS ITS PATCH THROUGH ARGV MEASURES NOTHING, AND SAYS
`recorded` WHILE IT DOES.** The first run of this campaign passed each respelling to a
shell script as an argument with a `\0` separator. **Bash arguments cannot contain
NUL**, so every one of the fifty-four arrived truncated, every patch failed, and the
driver printed fifty-four `PATCH-FAILED` lines. That is the driver doing its job — issue
1432's S24 is the same shape — and it is reported rather than quietly re-run. ⚠ **A
campaign whose failures are invisible measures fewer things than its table claims**, and
the md5 compare after each restore is what proves the tree came back.

---

## Rulings

⚖ **R9 — four new user-facing sentences, and no new surface.** All four reach the user
through `ase::echo`, which is the channel every other result note in this file already
uses, so **nothing new is drawn and no `look` debt is filed.**

1. **salvage, with a checkpoint** — *"this run was stopped: the analyses that finished
   are in the results file, and the '`<plot>`' plot the simulator was still filling was
   kept at N points of an estimated M, in `<cell>_ase.raw.ckpt`."*
2. **salvage, before the first checkpoint** — *"this run was stopped before its first
   checkpoint, so the analysis that was running kept nothing. The analyses that had
   already finished are in the results file."*
3. **reconciliation, `under` under a Stop** — *"one plot of the `tran` analysis was not
   written: this run was STOPPED, and what the analysis had when it stopped is in the
   checkpoint beside the results file."*
4. **reconciliation, `predmismatch` under a Stop** — *"the enabled rows predict N
   plot(s) and this run recorded M: the run was STOPPED before the rest."*

⚠ **Two of those replace a sentence rather than adding one**, which is the part worth
the user's eye: without the verdict the same two states are reported as
*"not captured"* and as *"the run stopped before the rest, **or** the analyses changed
between rendering the deck and reading it back"* — the language of a defect, for a thing
the user did on purpose.

⚠ **And three deck literals reach the user's LOG**, which is not prose but is visible:
`ASE-CKPT-ARMED <type> <row> <interval> <estimate>`, `ASE-CKPT-DONE <points>` and
`ASE-RUN-COMPLETE`.

Recorded as `owed.sh add rule 1433` at the moment it was incurred, pointing at the issue
file. **Batch with 1426, 1427, 1428, 1429, 1430 and 1432, which are all still waiting**,
per ⚖ R9 and the standing one-question-at-a-time preference.

⚠ **THE LEDGER WAS BACKED UP FIRST**, per `CLAUDE.md`'s one-ledger-every-clone
paragraph, to `/tmp/sv6probe/owed_backup_20260912_210110` (**151 rule / 56 look / 9
suite** at the time). The new entry is stamped `repo:/home/analog/dev/xschem-claude`.

⚠ **AND THE FOUR UNSTAMPED ENTRIES ARE STILL THERE, UNTOUCHED.** Measured again
2026-09-12 21:01, before the `add`:

```
/usr/bin/grep -L '^repo:' ~/.claude/xschem_owed/{rule,look,suite}/*
  ->  rule/1357   rule/1357@xschem-claude
      look/hier_pdf_nav_1357_H6.1789071932.2875683
      suite/test_hier_pdf_links_1333

/usr/bin/grep -h '^repo:' … | sort | uniq -c   ->  199 xschem-claude / 13 op-wcard
```

Identical to what issues 1430 and 1432 found. **Nothing has cleared them and nothing has
claimed them**, and a rule debt clears only when the user says so. The two `rule/1357`
entries still point at two different issue files — issue **1400**'s collision, standing
in the ledger itself. ⚠ The op-wcard count moved **13 → 13** while this clone's moved
**197 → 199** across the three receipts, which is the other clone still writing.

**No `look` debt.** `src/ase_window.tcl` is untouched and nothing new is drawn.

**⚠ One `look`-shaped thing that is NOT a `look` debt, and is named rather than filed:**
after a Stop the window does not LABEL the salvaged dataset as partial. That is a
**defect to fix in `ase_window.tcl`** — the plan assigns it there by name — not a pixel
deliverable to inspect, so it belongs in the next window stage's list and not on the
user's queue.

---

## For the driver

* T1 was **not** run by this crew (issue 0990 — the driver runs it solo).
* **Nothing was committed, added, stashed, restored or cleaned.** No `git checkout --`,
  no `git restore`, no `git stash`, no `git clean`, no `git push`.
* `NUMBERING.md`'s pointer was advanced **1433 → 1434** in the same change as the entry.
  Both mint checks were run at the moment of minting: the reserved-band scan over this
  clone's head table (**silent** for 1433) and `ls ~/dev/*/doc/claude/issues/1433-*` plus
  `/usr/bin/grep -lw 1433` across every clone's `NUMBERING.md` (only this clone's own
  pointer line).
* ✅ **All three suites this task moves ARE in `tests/run_regression.tcl`.** Nothing here
  is outside T1's reach; issue 1421's twenty-one unreachable `test_ase_*` suites are all
  unmoved.
* **Both binaries were exercised end to end**, through ASE-L's own `render_deck`, in a
  scratch directory under `/tmp` with an explicit `rundir`: the fork
  (`/home/analog/dev/ngspice/build-ver_50/src/ngspice`, `ngspice-46+`) and
  `/usr/bin/ngspice` (`ngspice-45.2`). A completed run and a SIGTERM'd run on each,
  byte-identical checkpoints and plotmaps on the two. **Nothing under `~/.xschem/` was
  touched and no bench under `sky130A/` was run**; every xschem invocation was given a
  path (`./src/xschem`) and `--nolog`, never `--logdir`, never a bare `xschem`.
* ⚠ **ONE SABOTAGE TIMED OUT, AND THE TIMEOUT IS THE FINDING.** S10 — the eligibility
  floor deleted — made `test_ase_preflight`'s one live `run_real` deck emit a checkpoint
  loop it could not leave; the suite was bounded at `timeout 500`, reported **rc 124**
  and a `FATAL`, and the driver recorded it as a named outcome rather than a gap. The
  infinite loop it exposed is corrected in the shipped code (see C79 in the corrections,
  and the polarity paragraph in `render_deck`). No orphan survived: `pgrep -af ngspice`
  after the kill is clean.
* ⚠ **A SABOTAGE CAMPAIGN OF SIXTY-FOUR RESPELLINGS RAN AGAINST THE WORKING TREE**, and
  `src/ase.tcl`'s md5 was compared against a pristine copy after every one. The tree is
  at the pristine md5 now.
* ⚠ **THE TREE MOVED AFTER THE FIRST PASS OF THE CAMPAIGN, AND EVERY MOVE IS NAMED.**
  Four sabotages bought changes to the shipped code — the loop's polarity (S10), the
  arming block's position (S07), `ckpt_rows`' dead `op_last` parameter (S19) and two new
  rows for the planner's own guards (S11, S12) — so every sabotage those touch was re-run
  with an `r` suffix, and two new ones (S55, S56) were written for the properties the
  changes established. Every suite was re-run to green after the changes and again after
  the second pass.
* ⚠ **ANOTHER CLONE WAS SIMULATING THROUGHOUT.** `pgrep -af src/xschem` showed
  `/home/analog/dev/xschem-op-wcard/src/xschem` live for the whole session, which is the
  load `test_ase_optier_0963`'s row **X7** (issue **1402**) reds under. It red once
  early and passed **ALL PASS (108) standalone, twice** — measured, not assumed.
* ⚠ **`test_cosim_golden_e2e`'s ONE KNOWN RED (row GE24, issue 1431) is unchanged** and
  nothing here touches co-simulation. `test_ase_cosim` is **ALL PASS (341)**, unmoved.
* ⚠ **`doc/claude/ase_analyses_batch/LEDGER.md` MOVED UNDER THIS CREW AND IT IS NOT
  OURS.** A `git status` taken at the end shows it modified, with a new *"Receipts from
  before Stage 0"* section that names this receipt as *"1 in flight"*. That is the
  driver's own collection edit, landing while this task ran. **This crew did not touch
  it**, and it is named here so nobody reads it as a stray write from the batch's own
  brief (*"you are not the only writer in this clone"*).
