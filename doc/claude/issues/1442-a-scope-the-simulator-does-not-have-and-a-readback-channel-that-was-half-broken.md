# 1442 — A scope the simulator does not have, a read-back channel that was half broken, and the four rules

**Stage 7 task 4 of 4 of `doc/claude/ase_analyses_batch/` (`PLAN.md` §7e + §7f + §7g).**
Tasks 1–3 landed as `d2f4437a` (issue **1437**, §7a+§7b), `98beb2b5` (**1439**, §7d) and
`f91c36ae` (**1441**, §7c). This is the **last** task of Stage 7.

The three sections are one issue because all three are about **what ASE-L claims versus
what the simulator did**: §7e makes a per-analysis scope out of a simulator that has none,
§7f is the channel that checks whether anything landed, and §7g is the handful of rules
where ASE-L overrides or warns about the user's own choice. §7f is what reports §7e's own
honest limit.

## What goes wrong for the user

**1. The per-analysis options sheet was a lie.** Issue 1441 gave the analysis form a
`Simulator Options…` button that opens the options sheet with the scope preset — and then
writes into the same **global** list. A value the user set "for this tran" was set for the
whole run. ngspice has no per-analysis option scope at all: MEASURED 2026-09-13 on both
binaries, `option keepopinfo` inside `.control` stays set for every later analysis.

**2. There is no error channel for a misspelled option.** RE-MEASURED on both binaries,
with a positive control in the same batch of decks:

```
.options bogusdot=1  +  option bogusopt=3  inside .control   ->  NOT ONE WORD
.options frobnicate  +  .op                                  ->  NOT ONE WORD
.options reltol=0.05                     ->  option prints `reltol (current) = 0.05`
```

The `Error: unknown option %s - ignored` branch is real — `inpdoopt.c:75`, and this tree's
ngspice even `fprintf`s it to stderr at `:77` — and **neither route reaches it**. A
catalogue going stale against an unfamiliar binary is therefore completely silent.

**3. AC sensitivity under KLU crashes the simulator** — rc 139, a SIGSEGV, on both
binaries — and ASE-L's answer was to **refuse the whole run**.

## ⚠ THE MEASUREMENT THAT REFUTED THE PLAN'S OWN RECIPE

`PLAN.md` §7f writes the verification channel as

```
option   > <cell>_ase.effective
set     >> <cell>_ase.effective
```

MEASURED 2026-09-13 on BOTH binaries, in **one** deck, with `echo … > f` and
`print … > f` beside them so that a null result could not be the measurement failing:

| command | bytes written |
|---|---|
| `echo POSITIVE-CONTROL > f` | 22 |
| `print v(mid) > f` | 22 |
| `set >> f` | **440 / 450** |
| `option > f` | **0** |

`com_option.c` writes its entire dump with bare `printf` — stdout — while ngspice's `>`
rebinds `cp_out`, which is what `out_printf` uses and what makes `set`'s redirection work.
So **half the plan's channel writes nothing, by construction**, and a deck built to that
recipe would have produced a plausible half-empty sidecar whose missing half always diffs
clean. That is the batch's own vacuity defect living inside the feature meant to cure it.

**What ships instead**, each half through the door measured to work:

```
echo ASE-EFFECTIVE-BEGIN          ->  the run log (stdout), which ASE-L captures whole
option
echo ASE-EFFECTIVE-END
set >> <cell>_ase.effective       ->  the sidecar, which redirection reaches
```

## ⚠ AND THE NUMBERS THAT RESHAPED §7e

Counted live over the shipped catalogue on 2026-09-13:

| | |
|---|---|
| rows in the catalogue | **247** |
| carry a `default` | **60** |
| can be spelled back through the `control` door | **39** |
| declare an `{analysis …}` scope | **32** |
| **both analysis-scoped and restorable** | **15** |

Issue 1441's receipt says 65 rows carry a `default`. It is **60**; 65 is the `help` count
(64 before 1441 added `units`). §7e's escape hatch — *"an option with no known default is
labelled global and offered only on the global surface"* — would therefore have **removed
17 rows from a surface issue 1441 had already shipped**. A shortcut that disappears is
worse than a shortcut that tells you its scope. What ships: every analysis-scoped row stays
offered, and each row **says** whether it is `scoped` or `leaks`.

## ⚠ AND `ase::opt_restore_line` COULD NOT RESTORE A FLAG, WHICH IS WHAT §7e RESTS ON

The shipped proc answered `{}` for the whole flag class under the comment *"a valueless
option restores by ABSENCE, and absence has no line"*. That is true of the **forward**
spelling and false of the **reverse** one: absence is how a flag starts, not how it is put
back once something has set it. MEASURED on both binaries, with §7e's own example:

```
ac                        ->  $plots  const ac1
option keepopinfo ; ac    ->  $plots  const ac1 op1 ac2        <- ON
option keepopinfo=0 ; ac  ->  $plots  const ac1 op1 ac2 ac3    <- OFF AGAIN
```

The third run gained `ac3` and **no** `op2`. Source generalises the measurement: every
`IF_FLAG` arm in `cktsopt.c` is `task->TSKxxx = (val->iValue != 0)` — with one inversion,
`OPT_SPARSE` at `cktsopt.c:181`, which is `(val->iValue == 0)` and therefore turns KLU
**on** for `sparse=0`.

## ⚠ §7g RULE 1: THE REFUSAL IS DEMOTED, NOT DELETED

`PLAN.md` §7g asks for the option to be *"simply not emitted for that run"*. That carries a
real cost the plan does not name: it drops KLU for **every** analysis in the deck, and KLU
is chosen for speed on exactly the circuits that have several. So the suppression is scoped
to the **analysis**, which is §7e's own mechanism and needs no new spelling. MEASURED on
both binaries, on the deck shape ASE-L actually writes:

| deck | rc | solver per job |
|---|---|---|
| `.options klu` + `tran` + AC `sens` + `tran`, no suppression | **139, SIGSEGV** | — |
| the same with `option klu=0` before the `sens` and `option klu` after | **0** | KLU / sparse / KLU |

and the `sens` numbers are **byte-identical** to the same analysis on a deck that never
asked for KLU. `option sparse` was measured to do the same thing; the restore line is used
instead because it is the mechanism §7e already has.

**The `fatal` survives for the case the emitter cannot fix** — a backend with no
`analysis_suppress` hook, or one whose speller cannot write the off-line — because the
alternative there is the SIGSEGV.

## What ships

**Schema (`src/ase.tcl`, `ase::`)** — §7e: `opt_restore_spell`, `opt_restore_template`,
`opt_restorable`, `opt_row_analysis`, `opt_scope_plan`, `opt_scope_lines`,
`opt_analysis_verdict`, `opt_scoped_names`, `opt_leak_why`, `preview_analysis_types`.
§7f: `effective_path`, `effective_marker`, `effective_region`, `effective_parse_vars`,
`effective_parse_task`, `effective_read`, `effective_lookup`, `effective_same`,
`effective_diff`, `effective_coverage`, `effective_report`, `effective_armed`,
`opt_door_reported`. §7g: `opt_gate_state`, `opt_gate_why`, `opt_door_phrase`,
`analysis_suppress`, `analysis_suppresses`, `analysis_suppress_lines`,
`analysis_point_estimate`, and the `lin_points` and `points_max` preconditions.

**Content (`ase::backend::ngspice`)** — four new optional hooks:
`option_restore_spell`, `effective_emit`, `effective_lookup`, `analysis_suppress`.

**Surface (`src/ase_window.tcl`)** — the per-analysis sheet stamps the analysis onto a new
row (`optsheet_stamp`, through a new optional `stamp` key on the shared list-dialog
config); the `Written` column says which analysis block a scoped row goes into; the detail
line carries the scope verdict and the capability gate.

## The four rules, and which two were already shipped

| rule | what happened |
|---|---|
| 1 — never `option klu` on a run carrying an AC `sens` | **shipped in the other shape and changed here.** `fatal` → `caution` plus a per-analysis suppression |
| 2 — never a narrowed `save` beside `disto`/`noise`/`tf`/dc `sens` | **already shipped, issue 1434 (6g-1).** Confirmed by a row, not re-implemented |
| 3 — `ac lin 2` / `sp lin 2` | new `lin_points` precondition. **Warns, never refuses** (D47) |
| 4 — `No. Points:` above 99,999,999 | new `points_max` precondition — **with a different reason than the plan gives**, see below |
| 5 — a `gated 1` option row whose `requires` says `absent` | new `ase::opt_gate_state`, and one genuinely gated catalogue row |

## ⚠ RULE 4's STATED REASON DOES NOT APPLY TO THE DECK ASE-L WRITES

D4 is `No. Points:` overflowing an 8-character field: `outitf.c:1011` reserves it with
`fprintf(run->fp, "0       \n")` and `outitf.c:1190` back-fills with `%d` and no width, so
a 9-digit count eats the newline. **That is the `-r` streaming writer.** ASE-L's deck
writes with the `write` command, `rawfile.c:209` — `fprintf(fp, "No. Points: %d\n",
length)`, no reservation, nothing to overflow. VERIFIED on both binaries: a 1008-point
`write` produces the header `No. Points: 1008` with no padding. The rule ships with the
reason that **is** true — the size — and the `-r` half is recorded in the source comment so
that whoever adds `-r` to `run_cmd` finds it.

## Tests

New suite `tests/headless/test_ase_effective_1442.tcl` — **92 checks**, identical on both
arms, registered in `tests/run_regression.tcl`'s `hcases`. It is deliberately **not** in
`dcases`: its UI section drives two pure procs and creates no widget, so the display arm
would be a weaker measurement of the same thing rather than a bigger one.

**Three rows re-baselined in other suites, each a decision rather than a drift:**
`test_ase_options_1437` **RS2** (a flag *does* have a restore line — measured),
`test_ase_preflight` **PF230f** (`sens_klu` `fatal` → `caution`), and `test_ase_core`
**D1**'s inline golden deck (the §7f read-back, armed because that bench stores an option).
Four extractors in `test_ase_core` were repaired rather than re-baselined: `^(op|…)` has no
word boundary and also matched `option`.

## Files

* `src/ase.tcl` — the schema half, the adapter's content half, the emitter, `run_deck`'s
  sidecar deletion, and the post-run report
* `src/ase_window.tcl` — the stamp, the `Written` column, the detail line
* `tests/headless/test_ase_effective_1442.tcl` — new
* `tests/headless/test_ase_core.tcl`, `test_ase_options_1437.tcl`,
  `test_ase_preflight.tcl` — the three re-baselines and the four extractor repairs
* `tests/run_regression.tcl` — `hcases`
