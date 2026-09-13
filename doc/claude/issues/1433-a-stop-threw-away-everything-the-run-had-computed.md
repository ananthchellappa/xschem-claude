# 1433 — a Stop threw away everything the run had computed

**Stage 6f of `doc/claude/ase_analyses_batch/`**, the fifth commit of Stage 6 and the
first that is not about the writer: **1429** is ⚖ R3's reader seam, **1430** the
writer, the plot sidecar and reconciliation, **1432** the three multi-plot types.
This is ⚖ **R1's always-salvage requirement**.

## The defect

Pressing Stop on an ASE-L run destroyed everything the running analysis had computed.
Not by design and not as a trade: **`ngspice -b` installs no signal handler at all.**
`src/main.c` puts its whole `signal()` block inside `if (!ft_batchmode)`, so batch mode
takes every signal's default disposition and the process dies where it stands — SIGINT,
SIGTERM, SIGHUP, SIGQUIT alike. Batch was written for scripted use where nobody presses
Stop. Nothing is being bought with the loss, which is why the user could state the
requirement flatly: *"What is the benefit of losing partial results on Stop? Why would
one ever want to do that?"*

⚖ **R1 was answered with a requirement neither offered option contained** — *"We should
put that in right away - always salvage, and alert user that her sittings will cause
loss of simulation effort 'thus far'"* — and `DECISIONS.md` **D38–D41** are that
requirement written down.

## What shipped

A deck that stops **itself**, writes what it has to a checkpoint beside the results
file, and resumes. Measured end to end through ASE-L's own `render_deck`, on **both**
binaries, killed with SIGTERM 6 s into an 8,000,008-point transient:

```
rc 143 · op and ac INTACT in the results file · plotmap 1:1 with it (2 records, 2 plots)
checkpoint: Transient Analysis, 4,800,000 points, loadable, byte-identical on the two
no ASE-RUN-COMPLETE in the log, which is what makes the abort decidable
no .ckpt.tmp left behind
```

**Core (`ase::`, schema):** `ckpt_path`, `ckpt_tmp_path`, `ckpt_marker`, `ckpt_enabled`,
`ckpt_floor`, `ckpt_n`, `analysis_salvage`, `ckpt_plan`, `ckpt_rows`, `run_completed`,
`ckpt_report`. **Adapter (`ase::backend::ngspice`, content):** `tran_points`, the
`salvage` key on the `tran` registry entry, and the deck lines — `stop after`, the
`while` loop, `shell mv -f`, `delete all`, `resume`.

**`src/ase_window.tcl` is untouched.** No new state key, no `seed_enabled`, and the 104
committed `.state` files are byte-identical.

## Eight measured refutations of PLAN.md §6f, which had never been re-measured

All 2026-09-12, on the fork (`build-ver_50`, `ngspice-46+`) **and** on `/usr/bin/ngspice`
(`ngspice-45.2`), identical on both unless stated.

**1. The point-count formula is wrong for three of the five shapes ASE-L's own `tran`
row can produce.** `PLAN.md` §6f and SV15 give it as `tstop/tstep + 8`:

```
tran 10n 80u          ->  8008      the formula's answer
tran 10n 80u 40u      ->  4001      the formula still says 8008
tran 10n 80u 0 5n     -> 16007      the formula still says 8008
tran 10n 80u 0 20n    ->  4009      the formula still says 8008
tran 10n 80u 40u 5n   ->  8001      the formula still says 8008
tran 10n 80u uic      ->  8011      the formula still says 8008
```

`tstart` and `tmax` are **advanced fields on the shipped `tran` entry**, so the plan's
formula is wrong for any bench that uses one. The rule the numbers fit is
`(tstop - tstart) / (tmax if given else tstep)`, plus a constant under twelve.

**2. And both directions of estimate error were silent.** With the plan's loop, whose
termination test is `if cknext < <total>` against the estimate: an estimate **10× too
high** made the loop spin five more times after the run had already finished, each
iteration writing the **whole rawfile** again (`resume` on a finished analysis is a
silent no-op); one **10× too low** stopped checkpointing at 8,005 points of an
80,008-point run, leaving the last 90 % unprotected. Both at **rc 0**, nothing said.
The loop shipped here terminates on a **measurement** — `if length(time) < $cktgt`, which
asks the simulator whether its own breakpoint fired — so neither is reachable.

**3. The `set` route rounds to SIX significant figures, and the loop must compare
against the ARMED value.** `let cknext = 1600002` then `set cktgt = $&cknext` gives
`1600000`. The run therefore stops two points **below** `cknext`, and a termination test
against `cknext` reads that as *"the analysis finished"*: measured, an 8,000,008-point
run wrote **zero** checkpoints, completed, and said nothing. It is invisible below
1,000,000 points, which is where a short test deck lives — the same trap as SV12, one
level over.

**4. `let` on a name that already exists in `const` writes THROUGH to `const`.** SV11
says a `let` created while `op1` is current lands in `op1` and is invisible from `tran1`
(re-confirmed: `Error: &bb: no such variable.`), and that one created after the `tran` is
a vector **of** `tran1` and is written into every file (re-confirmed: `No. Variables: 5`,
a `ckdone notype dims=1` column). The half it does not say is the one a second `tran`
row needs: assigning an **existing** const vector from inside another plot does **not**
shadow it — measured 222 assigned under `op1`, read back 222 from `tran1` and from
`const.ckstep`, with the written plot still at `No. Variables: 4`.

**5. `delete all` is mandatory, and the leak it prevents is invisible on a short next
analysis.** SV6 is confirmed — `stop after 2000` left armed truncated the **following**
`ac` to exactly 2000 points where it should have had 6001, at rc 0, with `status` still
listing the breakpoint after the resume. But an `ac` of **601** points showed no leak at
all: a stop only bites when the next analysis is **longer** than its threshold, so a
short probe deck passes with the line missing.

**6. The completion marker is emitted only by a deck that checkpoints, so the verdict is
three-state.** `PLAN.md` §6f writes the marker unqualified. An unconditional line would
move every deck golden a **second** time, which the plan's own eligibility-floor
paragraph forbids (*"they move at this stage for 6a's PLOT line; they must not move
twice"*). `ase::run_completed` answers `complete` / `aborted` / **`unknown`**, the third
for a run that promised no marker — a two-state reader would mark every ordinary run
aborted.

**7. The loop's EXIT must be the FALSE branch, or it spins forever.** Found by the
sabotage that deleted the eligibility floor, on a fixture `test_ase_preflight` already
had. With a save list that resolves to nothing the transient **does not run at all**
(`Error: no data saved for Transient analysis; analysis not run`), so there is no `tran1`
plot, `length(time)` is unevaluable, and the only trace is a `checkvalid` warning on
**stderr**. `.control`'s `if` takes the **false** branch for a condition it cannot
evaluate — measured for `<`, `>` and `>=` alike — which is the trap table's string
`eq`/`ne` shape arriving on a number. A loop whose exit was the true branch checkpointed,
re-armed and `resume`d **forever**, at rc 0, rewriting the same file every three seconds;
`resume` on an analysis that never ran is a silent no-op. With `>=` the same deck takes
**0 checkpoints** and leaves the loop. ⚠ The eligibility floor is what kept that out of
the shipped configuration, which is a much stronger reason for the floor than the one it
was written for.

**8. The arming block must sit ABOVE the verbatim hatch, and rows VB1/VB2 were green
while it did not.** Issue **1419** put the per-analysis hatch **immediately above** its
own analysis line and `test_ase_core`'s VB1/VB2 assert that adjacency. The first cut sat
between them and both rows stayed green, because every `x`-carrying fixture in the tree
is a short `tran`. The sabotage that lowered the floor reddened both. Row **CK10b** holds
it at the shipped floor.

Re-confirmed unchanged on both binaries: **SV1** (`stop after` does not perturb the run —
identical plot bodies checked and unchecked, fork transient sha `b9836c494d9d52ad`, the
dossier's own), **SV2** (`stop when time` adds 3 rows per checkpoint: 8,011 against
8,008), **SV4** (each checkpoint is an exact byte prefix of the final file), **SV5**
(`appendwrite` stacks — five plots and 897,796 bytes where one plot is 256,526),
**SV7** (`$sim_status` 0 and rc 0 after a stop), **SV8**, **SV10**, **SV12**, **SV15**'s
bare-`tran` case.

## The floor, and it is a number this crew picked

`PLAN.md` §6f says so in as many words. `ase::ckpt_floor` is **100,000 points**. Measured
on the reference RC, both binaries: 8,008 points in 0.11 s, 80,008 in 0.11–0.21 s,
800,008 in 0.91 s — about 900k output rows a second on the fastest circuit shape there
is, so at the floor such a run is a tenth of a second and there is nothing to press Stop
during. Below it no block is emitted at all, which is what keeps every small
rendered-deck golden from moving twice.

## Suites

`test_ase_core` 476 → **523** (section CK), `test_ase_preflight` 210 → **218**
(PF231), `test_ase_optier_0963` 106 → **108** (E5e/E5f). All three are in
`tests/run_regression.tcl`. **One row moved and no golden did**: `test_ase_core`'s
**RC10**, which pins the shape of the reconciliation call in `ase::run_done` and now
reads `catch {ase::reconcile_report $state $runstate}` — reconciliation has to be told
the run was stopped, or a Stop's short plot count is reported in the language of a
defect, which is `PLAN.md` §6f's own requirement.
