# Wiring the destination to the verbs that still refuse — the implementation contract

Stage J of the Calculator batch.  Spec `doc/claude/specs/calculator.md` §7.2ac
(R419–R421) and §7.3 (R401–R405).  Predecessors: `DESTINATION_CONTRACT.md` (which
built `calc::wave_dest`) and `CLICK_CONTRACT.md` (which built the click that reaches
it).  Fences in play: `tests/headless/test_calc_measure.tcl` (MT7, MT8, MT9b, MT11),
`tests/headless/test_calc_wave_dest.tcl` (WD4, WD9, WD10),
`tests/headless/test_calc_skeleton.tcl` (S24, S28) and
`tests/headless/test_calc_widgets.tcl` (CW13).

Everything in §1–§3 below was MEASURED by three recon crews on 2026-10-03 against
HEAD `ff49a92f`.  Receipts: `receipts/J-wiring-recon-sites.md`,
`receipts/J-wiring-recon-cost.md`, `receipts/J-wiring-recon-contract.md`.

---

## 1. The driver's framing of this stage was wrong THREE times, and the record is the point

The driver opened the stage by naming its targets as *"`dutyCycle`'s default X axis,
`delay` with `nth = 0`, and the unbuilt `frequency`"*.  Every clause of that is
wrong, and each was wrong in a different way:

| the claim | the measurement |
|---|---|
| `dutyCycle`'s **X axis** defers | ⚠ It does not.  R420's `xaxis` formal **landed with PLAN 5.4**: `calc::dutyCycle_scalar` is `{rpn level {cycle 0} {dataset 0} {xaxis start}}`, it forwards `xaxis`, `calc::dutyCycle` validates it with `lsearch -exact {start number mid}` and refuses an unknown token with `cross_msg badxaxis`.  What defers is the default **`cycle` ordinal** — `cycle == 0`, meaning *all* cycles. |
| **three** waveform callers | ⚠ There are **three**, but not these three.  Derived over every `cross_msg listdefer` call site: `calc::riseTime`, `calc::delay`, `calc::dutyCycle_scalar`.  `riseTime` is a deferring wave caller — **issue 1639 added that guard** — and the driver's list omitted it. |
| `frequency` is **unbuilt** and defers | ⚠ Half stale.  `frequency` and `freq` ARE in `calc::catalogue`, both route `T`, both already carrying `returns scalar/wave`.  No implementation exists (`info procs ::calc::frequency` → 0), so it cannot appear in a population derived over `listdefer` call sites at all.  A click on it reaches `calc::inert`, which is a **different refusal** from the shared deferral sentence. |

**The count happened to be right and the membership was wrong**, which is the exact
failure CLAUDE.md records for `grep -c '#pragma'`: a figure that survives because
nobody re-derives the set behind it.  The driver's source was four source comments —
above `calc::cross_msg`, `calc::cross`, `calc::delay` and `calc::catalogue` — all of
which still enumerate *"`delay`, `dutyCycle_scalar` and the unbuilt `frequency`"*.
**The test row had it right all along**: WD9 of `test_calc_wave_dest.tcl` names
*"`cross_scalar`'s nth 0, `delay`'s nth 0 on a side, `dutyCycle_scalar`'s default
cycle and `riseTime`'s nth 0"* and derives that set over the namespace every run.
So the fence was correct and only the prose rotted — which is the argument for
deriving a population rather than reading a sentence, made against this batch's own
documents for the second time.

## 2. The two destinations, and the four callers (derived, not read)

- **A wave with its own X axis** — `calc::wave_dest`, built, gated at 90 checks,
  and with **ZERO call sites in the product**.  Confirmed: the only non-comment
  occurrence of the token in `src/` is its own `proc` line.  Its three waiting
  callers are `calc::riseTime` (`nth` 0), `calc::delay` (`nth` 0 on either side)
  and `calc::dutyCycle_scalar` (`cycle` 0).
- **A plain list of crossing times** — R419, `calc::cross_scalar` with `nth` 0.
  **Nothing exists for it**: there is no `calc::list_dest` and no proc of any name
  that is one (verified both over the file's proc names and in the live namespace).
  It waits on spec R606's `Table` control, which is phase 10.  **Stage J does not
  touch it.**

All four deferral guards test an integer-**valued** zero, so `0`, `0.0`, `-0` and
`0e0` all defer identically, and a non-finite ordinal deliberately falls through to
the ordinary request-level refusal.

## 3. The change site that NO derivation over the deferral finds

`calc::fn_measure` — the OK path that shipped two commits ago — ends its success
arm unconditionally:

```tcl
set v {}
catch {set v [dict get $d value]}
set num [calc::buf_set_number $v]
return [calc::status [calc::arg_provenance $name $vals $num]]
```

There is no branch on the answer's shape, and `calc::buf_set_number` performs
`.calc.buf delete 1.0 end; .calc.buf insert end $n` **with no numeric check**.  So
the moment any verb answers `ok 1` carrying a LIST in `value`, that list is pasted
into the RPN buffer, and R404 (*"a literal number"*) and R421 (*"the number lands in
the buffer"*) are both violated **silently** — a wrong buffer, not an error.

⚠ **This site is invisible to the method that got §2 right.**  It issues no
`listdefer`, so the derivation over deferral call sites cannot name it; it was found
by reading the click path.  A stage that wired only the verbs would ship the defect.

## 4. How the surface knows the answer is a wave — DECIDED, internal

The verb's answer dict will carry an explicit **`shape`** key (`scalar` or `wave`),
set by the verb, and `calc::fn_measure` will branch on it.

The alternative — inferring from `[llength [dict get $d value]] > 1` — is rejected:
a legitimate single-cycle waveform has length 1 and would be mis-routed into the
buffer, which is precisely the silent-wrong-buffer failure of §3 arriving by a
second door.  An explicit declaration cannot be fooled by a one-sample result.

This is internal engineering and is the driver's call, not a ruling.

⚠ **The verb must not call `calc::wave_dest` itself.**  `calc::dutyCycle`'s own
comment states the architecture — *"the verb computes, the surface decides where the
answer goes"* — and **row MT10's transitive-closure row would redden if a layered
verb opened an engine door of its own.**  `calc::dutyCycle` already returns the
complete series (`dict set r value $series; dict set r sweep $xseries`) with the
X axis already selected per R420 in the same loop, so for `dutyCycle` the wiring is
a handful of lines with nothing to derive.

## 5. The cost: EIGHTEEN existing green rows, which is why this is THREE units

Recon ran every implicated suite rather than reading it.  Current, measured:

```
test_calc_wave_dest   ALL PASS  (90)    test_calc_measure   ALL PASS (160)
test_calc_cross       ALL PASS (187)    test_calc_engine    ALL PASS (265)
test_calc_scratch_reuse ALL PASS (54)
```

**18 rows assert the current refusal and will go red** — three times PLAN 5.1's
six.  They are not defects: MT7, MT8, MT9b and WD9 exist to pin exactly the
behaviour this stage changes, and WD9's derived-set row is built to **redden naming
itself** when the caller set moves.  A fence doing its job is not a fence to weaken.

Because the rows partition by caller, the stage partitions the same way:

| unit | caller | why this order |
|---|---|---|
| **J1** | `dutyCycle_scalar` (`cycle` 0) | The series **already exists**, X axis included.  Nothing to derive, nothing to decide but the name.  Carries `calc::fn_measure`'s shape branch and the consumer arm, so it is the unit that proves the whole route. |
| **J2** | `riseTime` (`nth` 0) | Needs one extra `cross` call; it already issues the high read with a literal 0. |
| **J3** | `delay` (`nth` 0 on a side) | ⚠ The only genuinely open design question in the stage: **both sides zero** means pairing two crossing lists that can differ in length, where `calc::wave_dest`'s `destlen` refusal fires. |

`returns` re-spelling for `riseTime` and `delay` (`scalar` → `scalar/wave`) is
**cheap, and that was measured rather than assumed**: `scalar/wave` is already in
S24's closed vocabulary, so the vocabulary does not widen and its three prose copies
do not move; and S24's `{56 26 12 4 3 3 4 108}` arm counts rows **per §7.1
category**, not per `returns` value, so no count there moves either.  Contrast
R419's own widening, which cost four sites.

## 6. The half nobody has mentioned: the CONSUMER has zero call sites too

`wviewer::plot_sweeps_arm {token sweeps}` has **zero callers in `src/` and zero
references in `tests/`** — its own banner says *"DECLARED: NOTHING ARMS IT YET …
`calc::wave_dest`'s own caller will be the first armer."*  Its `take` partner IS
consumed, inside `wviewer::plot_signals`.

So **a stage that wires only the producer leaves the user with a registered
two-column database and no trace on screen** — which would be reported as working
and would not be.  Unit J1 must arm it.

The other door, `wviewer::add_trace`'s 7th parameter `sweep`, is reachable today and
is pinned by **WD4** (`{7 sweep db}` — seven formals, 7th named `sweep`), which is
the one gate-visible arity pin among the three.

⚠ **Do NOT "simplify" the arm/take one-shot into a parameter.**
`wviewer::plot_signals` must keep four formals (row BM05 of
`test_wave_sigbrowser.tcl` pins the signature as a **literal source string**, and
six 4-parameter spy stubs redefine it); `wviewer::graph_props` must keep three (row
GT8 of `test_wave_grid.tcl`).  A 5-arg call raises *"too many arguments"*, which
`browser_plot_ids`' own `catch` **swallows**, so every gesture check reads as *"the
gesture did nothing"*.

## 7. Traps, each measured

1. **`calc::arg_surface` silently redirects.**  It is literally *"if
   `::calc::${name}_scalar` exists, return it."*  `riseTime` and `delay` have **no
   `_scalar` wrapper today**, so the moment J2 or J3 mints one, every click on that
   verb routes there and MT11's surface-formals row starts asserting against the new
   proc.
2. **Formal ORDER is load-bearing, and getting it wrong is silent.**
   `calc::arg_values` walks `info args` of the surface proc in **formal order** and
   `break`s at the first formal it has no value for; `calc::arg_invoke` then appends
   values **positionally**.  So a new wrapper must carry its formals in the dialog's
   key order or the call is **truncated** at the first unknown formal and everything
   after it silently falls back to its default.  A destination-naming argument is
   safe only as a **trailing** formal with a default.
3. **`destempty` is three separate dispositions, and only one is covered.**
   `calc::wave_dest` refuses an empty list.  `dutyCycle_scalar` is safe (`nocycle`
   and the per-period `nofall` fire first).  **`riseTime` with `nth` 0 and no low
   crossing will hand it an empty list**, and the user would read a *"Destination:"*
   sentence where an absence sentence is the true answer.  `delay` the same, plus the
   both-sides-zero case.
4. **The `sweep=` carry-forward.**  `draw_graph`'s local `sweep_name` carries the
   **last non-empty** token forward and never resets when `my_strtok_r` runs out, so
   a short `sweep=` list silently re-axes every later trace — and **all seven
   walkers** do it.  A short list and an **absent** list are two different failures.

## 8. Unruled, and therefore filed rather than invented

- ⚠ **The destination's NAME is user-visible and nobody has decided it.**
  `results::list` iterates every database out of `xschem raw info` and **filters by
  nothing** — there is no type test anywhere in the proc — so `__calc_dest<N>`
  appears in the Results picker for as long as it lives, and the trace label shows
  the column names, which default to `calcx`/`calcy`.  Nothing in spec §7.2ac, in
  `DESTINATION_CONTRACT.md` or in the catalogue says what a measured wave should be
  called.  **`rule` debt, not an internal choice.**
- The three `destempty` dispositions of §7.3.
- Stage J invents no new sentence it can avoid: the deferral string is shared by all
  four callers precisely so that a landing destination **retires one string rather
  than one per caller**.  Splitting it per caller reddens MT7 and MT8, which compare
  it by identity.

## 9. Prose this stage must correct — TWENTY copies, named

Recon enumerated them mechanically.  Nine in `src/calculator.tcl` (above
`cross_msg`, `cross`, `riseTime`, `delay`, `dutyCycle_scalar`, `catalogue`,
`fn_fields`, `fn_measure`, `arg_surface`), two in `src/wave_viewer.tcl`, five in the
suites (including `test_calc_wave_dest.tcl`'s own header, line 34, carrying **the
same three-not-four omission inside the suite whose WD9 row has it right**), one in
the spec, and two in this directory's own contracts.

⚠ `TIMING_CONTRACT.md` lines 45–57 state the three-caller count and then **correct
it to four in place**, saying explicitly *"the count is left wrong above on
purpose."*  That document got there first.  **Leave it alone** — editing it would
destroy the record it exists to keep.
