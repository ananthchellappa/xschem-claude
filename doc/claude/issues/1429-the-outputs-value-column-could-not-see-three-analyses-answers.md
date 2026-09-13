# 1429 — the Outputs Value column could not see three analyses' answers

**Stage 6 of `doc/claude/ase_analyses_batch/`, first commit: ⚖ R3's reader seam and
nothing else.** Stage 5 is issues **1426** (`tf`), **1427** (`pz`) and **1428** (`sens`).
Nothing here touches any of them, or the writer, or the sidecar, or salvage.

⚠ **⚖ R3 WAS ANSWERED ON 2026-09-12 — Option C, RATIFIED.** The user's words were
*"both with a rule is right, keep it"*, which answers the "both" and the "rule" halves
together: both readers stay, and `ase::result_source` is the one place that says which
one answers a row. This paragraph said *asked and unanswered* until the ruling arrived;
what shipped ahead of it was built so that a ruling of A or B would have **removed a
reader** rather than invalidating the work — see *Why Option C can ship unratified*
below, which is now the record of a risk that did not have to be paid.
`DECISIONS.md` records R3 as **extending** the user's own ruling in issue **1243**, not
reversing it: `render_deck`'s print anchor is untouched and every expression row still
reads exactly the log 1243 anchored.

## The defect

The Outputs pane's Value column is filled by `ase::backend::ngspice::result_probe`, which
scrapes `<expr> = <number>` out of the `print` echo in the run log. `print` reads
**whichever plot the simulator is standing in**, and issue 1243 — the user's own ruling —
anchors the print lines on the operating point.

Measured 2026-09-12, one deck, the prints placed exactly where `render_deck` puts them:

```
op / write / print v(mid) / print Transfer_function / print onoise_total / print r1
   / tf v(mid) V1 / write / sens v(mid) dc / write

  -> v(mid) = 1.500000e+00
  -> NOTHING ON STDOUT for the other three -- no `<name> = <value>` line, which is
     the only thing `result_probe` parses.
```

The `tf` and `sens` vectors are **in the results file**. They are simply not in the plot
the prints stand in. So three analyses Stage 5 had just made choosable — the DC transfer
function, DC sensitivity and the noise integrals — produced numbers the user could not be
shown, and no amount of log parsing could give them one. Moving the prints is not the fix:
that is the defect issue 1243 was filed about.

⚠ **AND `PLAN.md` §6e's STATED REASON IS WRONG.** It says reading the raw *"removes
`result_probe`'s case-folding ladder"*. It does not. The rawfile reader needs a fold of its
own, because the fork writes `v(Transfer_function)` where apt 45.2 writes
`v(transfer_function)` (issue 1426's C46). The gain is the plot, not the ladder.


⚠ **CORRECTED BY THE DRIVER BEFORE THIS COMMIT LANDED.** This issue first read *"no value,
no warning, no error line"*. ngspice **does** emit `Warning from checkvalid: vector <name> is
not available or has zero length` — but on **stderr**, where no reader in this tree looks.
Measured on `/usr/bin/ngspice`. The defect is that nothing **parseable** reaches stdout, not
that ngspice is silent; the distinction matters to the next person who goes looking for that
warning and finds it.

## What this changes

Three new procs and one rename. **`src/ase_window.tcl` is untouched.**

| proc | class | what it is |
|---|---|---|
| `ase::raw_scalars {path}` | core, **schema** | every one-point number in a results file, as a LIST of `{plotname {var value …}}` pairs |
| `ase::result_source {sim ex}` | core, **schema** | ⚖ R3's rule, and the whole of it: `raw` or `log` |
| `ase::backend::ngspice::result_probe_raw {state {mode fold}}` | adapter | the results-file reader |
| `ase::backend::ngspice::result_probe_log {state logtext {mode {}}}` | adapter | **the old `result_probe`, renamed**, body unchanged but for where `mode` comes from |
| `ase::backend::ngspice::result_casemode {state logtext}` | adapter | the case rule's head, lifted out so both readers obey one rule |
| `ase::backend::ngspice::result_probe {state logtext}` | adapter | now a **dispatcher** |

Two small helpers ride with the raw reader: `raw_spellings` (the `v(…)` wrapper the file
writer adds) and `raw_scalar_format` (`%.6e`).

### The rule, stated on screen

> A row whose expression **names exactly one vector** reads the results file.
> Anything else reads the print log.

The dispatcher says it once per run, through `ase::echo`, with the split this run took:

```
ase: results -- a row whose expression names exactly one vector is read from the
results file; anything else is read from the print log. This run: 2 from the file,
1 from the log.
```

⚠ The counts are **computed from the rule**, never written out as prose, so a later ruling
of A or B leaves the sentence telling the truth without being edited. Row **RS4b**.

### What "names exactly one vector" means

1. The backend's `out_decompose` hook (issue 1426) answers first, because it is this
   tree's existing reader of ngspice output syntax and this must not be a second spelling
   of it. `{voltage n}` and `{current n}` are one vector. `{voltage a b}` is **two** —
   measured, `print v(in,mid)` echoes `v(in,mid) = 1.714286e+00` and there is **no**
   `v(in,mid)` vector in the file.
2. Otherwise the expression is a **bare vector name** when it is a letter or `_` followed
   by letters, digits and `_ . : #`. That is exactly the namespace the three analyses use:
   `Transfer_function`, `v1#Input_impedance`, `onoise_total`, `inoise_total`, `r1`,
   `r1:r`, `r1_m` and the hierarchical `r.x1.ra:r` (issue 1428's measurement 3). `:` is
   not treated as an operator because ngspice's only use of it is the `? :` ternary,
   which cannot occur without a `?`.
3. ⚠ **Everything else is an expression, including a parenthesis this rule did not put
   there.** `abs(v(mid))` and `output_impedance_at_V(mid)` are the same string shape and
   no string test tells a function call from a vector name that contains brackets. Both
   go to the **log**, which is the direction that loses nothing: `abs(v(mid))` and
   `v(a)*2` are exactly what Option B exists to protect and they keep working, while
   `output_impedance_at_V(mid)` gets no value today and gets no value after. Measured:
   `print output_impedance_at_V(mid)` **does** work when the simulator is standing in the
   `tf` plot — so the limitation is the print anchor's, not a parser's, and the fix is the
   registry's `plots` key (issue 1426 already computes that name in `tf_vectors`), not a
   cleverer regexp. **Not shipped here**; it is Stage 6's results seam.
4. ⚠ **`@dev[param]` and `a[0]` stay on the log, deliberately.** A bracket is how
   ngspice's expression parser spells a **subscript** (issue 0167: `print a[0]` reads
   element 0 of a vector `a` and prints nothing, which is why `print_arg` quotes it), and
   `@…` is the op-parameter seam issues 0963/0965 built on the log. Neither shape changes.

### What the Value column shows when a run computed nothing: NOTHING

Measured 2026-09-12 on both binaries, and reproduced independently by the driver: a `sens`
filter matching nothing — and a save list resolving to nothing — **exit 0** and write a
results file whose only record is

```
Title: Constant values / Plotname: constants / No. Variables: 12 / No. Points: 1
```

`ase::raw_scalars` excludes that plot **by name**, so the reader finds no vector, records
no value, and says so on screen. ⚠ **A reader that treated "no vector" as zero would print
a number for a run that computed nothing** — and `i` is one of those twelve constants, so
a reader that merely forgot the name test would answer for an output row called `i`. That
the plot is also `Flags: complex` on both binaries is a **second, accidental** guard;
rows **RD5c** and **RV3b** exist because a sabotage proved the accidental one was carrying
the deliberate one.

⚠ **And the reader never falls back to the log.** A single-vector row whose vector is not
in the file has **no** value, and the reason is echoed. A fallback would make the
on-screen sentence false and would make a later ruling of A two changes instead of one.
Row **RD12**.

### The number on screen does not change for any row that already had one

Measured: the results file carries `1.285714285714286e+00` where the log carries
`v(mid) = 1.285714e+00`, and `%.6e` of the first **is** the second, byte for byte. So
Option C gives a number to rows that had none and changes no row that had one — which is
most of why it can be recommended without a ruling in hand. Row **RD1**.

## Why Option C can ship unratified

C is the **superset** of A and B, and the code is shaped so that is a fact rather than a
claim:

| a later ruling | what changes |
|---|---|
| **A** — results file only | `ase::result_source`'s body becomes `return raw`; `result_probe_log` is deleted whole |
| **B** — print log only | `ase::result_source`'s body becomes `return log`; `result_probe_raw`, `raw_spellings`, `raw_scalar_format` and `ase::raw_scalars` are deleted whole |

**Neither reader calls the other and neither reads the other's source.** The dispatcher
partitions the output rows by `ase::result_source`'s answer and hands each reader a state
carrying only its own rows, so a reader does not know the rule exists.

Two rows hold that property, and the second is the one that costs something:

* **RS2** — structural: neither reader's body names the other, names `raw_file`,
  `raw_scalars`, `logtext` or `ase::result_source`.
* **RS3** — behavioural: it **performs both rulings**, by stubbing `ase::result_source` to
  one fixed answer, which is literally what ruling A and ruling B do to that proc, and
  shows the whole surface following from that one edit. Its fixture log carries a
  *different* number for `Transfer_function` from the one in the results file, so the row
  can say **which reader answered** and not merely that a number appeared. A fixture whose
  two sources agreed could not adjudicate it at all.

## What was NOT shipped

* **The writer, the `setplot previous` walk, `<cell>_ase.plotmap` and reconciliation**
  (`PLAN.md` 6a–6c). No deck golden moves; `render_deck` is untouched.
* **`noise`, `disto` and `sens (ac)`** (6d). No analysis type is added and no registry
  entry changes, so `ase::analysis_schema_errors` stays clean, row **GR8**'s declared-kind
  set is unmoved, and `test_ase_preflight`'s **PF222a-e / PF222h-j** — which rest on
  `noise` being unrenderable — stay green.
* **Checkpointed salvage** (6f) and the variant mitigations (6g).
* **`seed_enabled`, anywhere.** The 104 committed `.state` files are byte-identical and
  section **CP** of `test_ase_core.tcl` still proves it.
* **`output_impedance_at_V(mid)` and `pole(1)` as Value-column rows** — reason 3 above.
  `pz`'s roots were never the Value column's anyway: issue 1427 gives them
  `results {table {kind roots}}`.
* **A complex scalar.** Measured: `ac lin 1 1k 1k` writes a one-point **complex** plot and
  `print v(mid)` echoes `4.999951e-01,-1.57078e-03` — two numbers, which today's log
  regexp does not match either. A Value column holds one number; a complex scalar is a
  surface's problem.
* **Any change to `render_deck`'s print anchor.** That is issue 1243, the user's ruling,
  and ⚖ R3 extends it rather than reversing it.

## Tests

| suite | before | after | new |
|---|---|---|---|
| `test_ase_core` | 391 | **417** | sections **RS** (the rule, and its separability) and **RD** (the two readers over canned results files) |
| `test_ase_simcaps_0948` | 180 | **190** | section **RV** (`ase::raw_scalars`, the canned-file idiom) |
| `test_ase_result_case` | 28 | **31** | section **NCR** (⚖ R3's dispatcher over this file's own subject) |
| `test_ase_print_bracket_0167` | 12 | **14** | **PB13** (the routing) and **PB12b** |

⚠ **Sections RS, RD and RV carry their own `catch`.** `test_ase_core.tcl`'s outer one
closes at the end of section SI and `test_ase_simcaps_0948.tcl`'s at the end of section H,
both far above where these sections live — issue 1428's S10 and S12 measured what that
costs: a sabotage that *should* have reddened rows killed the file instead, with no
`RESULT:` line at all, which in a sabotage log reads as "nothing went red".

⚠ **`test_ase_result_case.tcl` and `test_ase_print_bracket_0167.tcl` now drive
`result_probe_log` BY NAME**, and the swap being **one line** in each is itself the
evidence for the separability claim. Both files are about the print log; every expression
in them names exactly one vector, so driving the dispatcher would have measured the
rawfile reader under their names. Each gained rows that keep the dispatcher honest.
