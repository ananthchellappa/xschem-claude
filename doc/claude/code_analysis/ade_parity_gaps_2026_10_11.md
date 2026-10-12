# ASE-L / Calculator vs Cadence ADE-L — what the user wants, and where we differ (2026-10-11)

Agreed with the user on 2026-10-11 as the reference for future Calculator and ASE-L Outputs work.
Items marked ❓ are the driver's understanding of Cadence, **not confirmed by the user** — ask before
treating any of them as fact. Gaps are a snapshot at `1a67a5d4`; re-check before quoting one.

## What the user wants

1. **ADE-L is the floor.** Anything ADE-L lets you do, ASE-L and its Calculator should let you do, the
   same way. A difference is our defect.
2. **`vt` / `vf` / `vdc` / `vs` are different things.** Each reads its own analysis and finds it in the
   run's results by itself. Done: spec R208c (`ed44ceec`..`1a67a5d4`).
3. **Cadence-style text works**, e.g. quoted arguments: `cross(v("vbg"), 0.5, 1, "rising")`. Partly
   done (`4a03c0e1`); see the language gaps below.
4. **An Outputs expression is a calculation on the simulation's results.** User, verbatim: *"Why would
   expressions in the outputs pane of ASE-L go to the netlist? They are computations made using the
   result of the simulation! They should not influence the input to the simulator."* It is evaluated
   after the run, by the same engine as the Calculator. The only netlist effect allowed is making sure
   the signals it reads were saved (ADE's save list).
5. **Outputs re-evaluate after every run**, with the answer shown in the table.

## Where we differ from Cadence today

### Outputs pane (ASE-L)
1. ~~Expressions go into the netlist (`.save <expr>` and ngspice `print`, read back by `result_probe`)
   instead of being computed afterwards from the results.~~ **Done (Outputs build item 1):** the
   deck carries no `print` for any output; every row is evaluated after the run from the results
   file — a single vector by the file reader, everything else by the Calculator's pure evaluator
   `calc::eval_texts` — on run finish, on open and on Load State. The Value cell shows a number,
   `wave`, or the Calculator's refusal sentence. Spec ase_l.md R-OUT1..R-OUT6, calculator.md R609.
   Repaired the same day: an expression row read a results file that OP annotation or the
   Calculator had left loaded as that stale slot, showing the previous run's number beside a plain
   row from the new run; the evaluator now always reads the file on disk (`calc::et_alias`).
2. ~~So the Expression field takes ngspice syntax, not Calculator syntax.~~ **Done:** it takes
   Calculator syntax (postfix RPN, measurement calls, `vt()`/`vf()`/`vdc()`/`vs()`, quotes). One
   ngspice idiom is kept for committed benches, a negated single signal (`-i(v1)`); any other
   ngspice infix (`v(a)*2`) is refused with a sentence. The Calculator's own gaps (postfix, no
   slash paths) now apply here — see *Expression language* below.
3. Measurements are a separate dialog (`Outputs > Measurements…`, ngspice `.meas`,
   `ase::ui::measurements_dialog`), and their results go to the run log, not the Outputs table.
   ❓ In ADE a measurement is just another output expression.
4. No spec limits, no pass/fail column.
5. Corners and Monte Carlo tabulate only `.meas` results, not Calculator expressions.
6. No button to send the Calculator buffer to Outputs, or back (spec R608, PLAN row 10.4, not built;
   calculator.md open question 4 unruled). R608 as written would put a Calculator expression into
   today's ngspice field, which is exactly item 1's defect.
7. ~~To check: in ngspice, any `.save` line may make it keep **only** the listed signals.~~
   **Measured 2026-10-11** on the registry's ngspice-46+: yes — any `.save` keeps only what is
   listed, in every plot; `.save all` beside it restores everything. ASE-L now saves a ticked plain
   signal as before and, whenever that narrows the deck, every signal an expression reads; an
   expression's own tick never narrows (ase_l.md R-OUT3).

### Expression language
1. Plain arithmetic is postfix (`v(a) v(b) +`), not normal algebra (`v(a) + v(b)`).
2. Signal names are xschem net names (`lp`). Cadence slash paths (`/lp`, `/I0/net`) are refused
   (row Q6 of `test_calc_quotes`).
3. Quotes are accepted but not required. ❓ Cadence requires them.
4. Measurement arguments are comma-separated and positional. ❓ Cadence's own buffer text may be
   space-separated with `nil` placeholders, like `cross(VT("/vbg") 0.5 1 "rising" nil nil)`. That was a
   verifier's guess and is unconfirmed.
5. A plain `v(net)` reads whichever analysis is showing; only `vt()`/`vf()`/`vdc()`/`vs()` choose their
   own. ❓ Whether Cadence has an unqualified form at all.
6. A plain expression with no measurement gives the value at the last point, or at the cursor, rather
   than the whole waveform.
7. Missing ADE functions: `ymax`, `ymin`, `value`, `peakToPeak`, `unityGainFreq`.
8. About 20 functions appear in the Calculator's list but do nothing yet, including `stddev`, `clip`,
   `sample`, `peak`, `compare`, the jitter functions and `eyeDiagram`. Others are deferred altogether
   (`dft`, `psd`, `spectrum`, `thd`, `harmonic*`, `convolve`).
9. A bare `M` suffix is refused as ambiguous between milli and mega. Waiting on the user's ruling
   (`rule/calc_eng_capital_M`).

### Results and datasets
1. Only the first dataset of a sweep is evaluated. No per-sweep-point or per-corner result.
2. A wave-valued measurement can only go to the waveform viewer (`calc::wave_dest`). It can't yet be
   returned as a value.

### Calculator window and CIW
1. Typing `cross(...)` in the CIW fails, because the CIW speaks Tcl. ❓ Cadence's CIW evaluates
   Calculator functions directly. Batch item 6
   (`doc/claude/calc_feedback_batch/item6_ciw_expression_prompt.md`) is waiting on the user's build
   decision.
2. The stack's side buttons (Del, Recall, Swap, Roll) do nothing yet.
3. Two picking behaviours are waiting on the user's rulings: whether a selector stays pressed after a
   pick (`rule/1656`), and what happens after a click that misses (`rule/calc_r208b_miss_stays_armed`).

## The agreed first build step (DONE 2026-10-11 — see Outputs items 1, 2 and 7 above)

Take Outputs expressions out of the netlist, and compute them after the run from the results.

1. A pure "evaluate this text on this result (raw path, analysis, dataset)" call, factored out of
   `calc::eval_click`'s routing with no buffer, stack or status side effects.
2. Outputs rows evaluated by it after every run (`ase::ui::run_finished`, and on open and Load State
   as `refresh_output_values` does), with the value or the refusal sentence in the Value cell.
3. The netlist gets only the saves the expressions need.
