# `cross` — the implementation contract

**Written by the driver 2026-10-01**, before any `cross` code exists, so that the implementation
crew builds against a decided contract rather than discovering it. Spec rulings live in
`doc/claude/specs/calculator.md` §7.2aa (R414–R414e) and §7.3 (R401–R405); this file decides the
things the spec leaves to the implementer and nothing else. Where this file and the spec differ,
**the spec wins and this file is the bug**.

`cross` is PLAN rows 7.1 (T-route plumbing) + 7.2, pulled ahead of phases 4–6 at the user's
request. It is the keystone: the spec's own implementation order is *"P, then C, then
T-on-`cross`, then the rest"*, and `riseTime` `slewRate` `delay` `dutyCycle` `frequency`
`settlingTime` `overshoot` are all layered on it. Seven verbs inherit every decision below, which
is why they are written down before the code rather than after.

## 1. What the user supplied, and what follows from it

The `nth` semantics in R414 came from the **user**, who uses the reference tool professionally:
`-1` is the last crossing, `-2` the second-to-last. Two consequences that are easy to get wrong:

- **D1. A negative `nth` must scan from the END, downwards.** A forward scan cannot answer "which
  was last" without reaching the end of the sweep, so the obvious loop serves only positive `nth`
  and silently walks the entire trace for negative `nth`. Implement **two scan directions**, so
  both signs early-exit; neither traverses a long transient to answer about an edge near its tail.
  This is R414c and it is the single most likely thing to be implemented wrongly.
- **D2. `0` means every crossing and is not a special case.** Once both signs are ordinals from
  opposite ends, zero is the only integer left over. Write it that way — a selector sign test, not
  a magic value checked first.

## 2. Decisions this file makes

### D3. The detection rule, stated as a predicate on a sample pair

For the pair `(p-1, p)` with level `L`:

- **rising** crossing iff `y[p-1] < L && y[p] >= L`
- **falling** crossing iff `y[p-1] > L && y[p] <= L`
- **either** is the disjunction, and a pair can satisfy at most one of them

The strict-below / inclusive-above asymmetry is deliberate: it counts each transition exactly
once, and an exact sample hit (`y[p] == L`) is a crossing **at** that sample, for which the
interpolation formula in D4 already yields exactly `x[p]` with no special case.

**⚠ Known limit, and it must be a row, not a comment.** A trace that arrives at exactly `L`, sits
flat on it for several samples, and then leaves *downwards* registers a **rising** crossing on
entry and **no falling** crossing on exit, because the departing pair has `y[p-1] == L` which is
not `> L`. The behaviour is asymmetric. It is accepted for v1 because a threshold is normally
mid-swing and exact float equality with it is vanishingly rare outside rail-clamped digital
traces — but it is accepted **knowingly**, so a row pins the current behaviour by name and says
in that name that it is a limit. If a real signal ever hits it, the row is where the fix starts.

### D4. Interpolation, written once

```
x = x[p-1] + (L - y[p-1]) * (x[p] - x[p-1]) / (y[p] - y[p-1])
```

Linear, between the two straddling samples, never snapped to a sample (R414d). The denominator
cannot be zero when D3's predicate holds, because the predicate requires the endpoints to be
strictly on opposite sides of `L` — but the implementation must not *rely* on a reader noticing
that, so the division sits behind the predicate and nowhere else.

`graph_marker_sample()` and `graph_marker_anchor_at()` in `src/draw.c` already do this arithmetic
for the markers. Same formula, different consumer; `graph_marker_anchor_at`'s own comment records
that snapping to the sample was the pre-issue-0193 behaviour, so do not reintroduce it here.

### D5. Both ends of out-of-range answer the same way

Fewer than `|nth|` crossings is **"no crossing"** — not an error, not zero, not an empty string
that a caller might arithmetic on by accident (R414b). It is symmetric: `-5` and `+5` over three
crossings give the same answer by the same path. Every verb layered on `cross` must be able to
propagate it, so pick a representation that **cannot be silently consumed as a number** and say
in the proc's header comment what it is. A bare `{}` that `expr` turns into an error at some
distant call site is the wrong choice; so is `0`, which is a perfectly good X value.

### D6. A non-finite sample cannot bracket a crossing — and the test runs BEFORE D3, not inside it

Both endpoints of a candidate pair must be finite, **and that is checked before D3's predicate is
evaluated at all**. Use `calc::eval_finite`, which is textual.

**⚠ This was written as "skipped as a bracket endpoint" and measurement showed that reading is not
strong enough.** Two results from the read-back recon, on Tcl 8.6.17:

```
  y0=-inf y1=0.6 : rising=1 falling=0      <-- D3's PREDICATE PASSES
  y0=0.4  y1=inf : rising=1 falling=0      <-- D3's PREDICATE PASSES
  y0=-nan y1=0.6 : rising=0 falling=0
```

`-inf < L && 0.6 >= L` is perfectly true, so an infinity does **not** fail D3 — it sails through
as a crossing. Letting D3 decide first and skipping only what it rejects therefore admits a
phantom crossing on every infinite sample. The finiteness gate must come first.

And the arithmetic is worse than wrong, it **raises**:

```
  finite    : 0.0010500000000000002
  y0 = -nan : RAISED: can't use non-numeric floating-point value as operand of "-"
  y0 = -inf : RAISED: domain error: argument not in valid range
  y0 == y1  : RAISED: domain error: argument not in valid range   (zero denominator)
```

Comparison operators on NaN return 0 quietly, but `expr {$x - $L}` and `abs($x)` throw. An
unguarded `cross` would therefore **THROW rather than refuse**. The predicate-before-division
ordering D4 mandates is load-bearing for the same reason.

⚠ **This paragraph used to say a throw "reaches the file-scope catch and aborts the whole suite",
and that is false** — measured by the suite-repair crew against `test_calc_cross.tcl`'s three
actual catch layers. A throw out of `::calc::cross` is caught by the suite's own `cx_call` and
becomes a `RAISED:` sentinel, failing **one row**; a throw out of the suite's own code is caught by
`group` and abandons **one band**; neither reaches the file-scope catch. The correction matters in
both directions: the consequence is smaller than claimed, *and* a band that abandons silently stops
measuring its remaining rows, which is the worse half and the half the old sentence obscured by
over-stating the blast radius. A throw is still a defect; it is a defect of a different shape.

Use `calc::eval_finite` and not `string is double -strict`, which accepts all four non-finite
spellings, and not `expr {$v == $v}`, whose "raises on NaN" rationale is **false on this Tcl** —
see §4's correction list. The engine really does produce these: `v(ramp) -1 * sqrt()` gives
`-nan` and `1e300 1e300 *` gives `inf`, both arriving through `raw values` as literal tokens with
`llength` still correct.

### D10. ⚠ REVERSED 2026-10-01: read the column in BULK, always. The fast door is not precise enough.

**The decision below was wrong and is kept because the reasoning is instructive.** `cross` reads
the sample and sweep columns with **`xschem raw values`**, once each, for every `nth` including
`nth = ±1`. There is one read path, not two.

**Why.** The per-point door loses eight significant digits. `xschem raw value` returns
`dtoa(val)`, and `dtoa()` in `src/util.c` is `my_snprintf(s, S(s), "%.8g", i)`; the `values` arm
formats `"%.16g"`. So the two routes do not see the same operands:

```
time[9]   bulk 0.0009000000000000002    per point 0.0009
v(sq)[10] bulk 0.5000000000000009       per point 0.5
```

A crossing interpolated from `%.8g` samples carries ~1e-8 relative error at best, and the
fixture's own README documents a **1e-12** relative tolerance for `time`. **The fast route cannot
produce an answer good enough to assert**, so the optimisation was buying speed with the only
thing the measurement is for.

**Three consequences, and the third is the one that nearly got away.** One read path is simpler
than two. 15 ms on a 100 000-point trace is invisible behind a button press, which is the only
place `cross` is called from. And a test row that compared the `nth = 0` answer against the
`nth = 1` answer with string identity **could never pass** under the two-route design — the
adversarial lens measured `0.0009999999999999998` against `0.001` — while an implementation that
quietly used bulk for everything turned that row green **with nothing else in the suite
noticing D10 had been discarded**. So the row would have selected for abandoning this decision in
silence. Reversing it deliberately is the honest version of the same outcome.

**R414c and D1 are untouched.** The two scan directions are semantics, not I/O: scanning a
materialised Tcl list from the end for a negative `nth` is still correct and still cheap. What
R414c loses is only the claim that it saves a round trip. **D10 is therefore not fenceable by any
row** — nothing observable distinguishes the routes except low-order bits — and the adversarial
lens was right to declare it so rather than invent a timing row that would flake.

<details>
<summary>The superseded reasoning, kept because it is how the mistake was made</summary>

R414c's bidirectional early exit is **only real if the scan reads one point at a time**.
`xschem raw values` materialises the entire column into a Tcl string, so it cannot early-exit at
all. Measured on a 100 000-point synthetic raw:

```
  raw values + llength + lindex end  : 15598 us
  raw values alone                   : 12089 us
  200 backward single-point reads    :   111 us
  200 forward  single-point reads    :    88 us
```

Per point, `xschem raw value <name> <point> [dset]` is about 3.5× dearer than bulk — and on the
101-point fixture bulk actually wins (14 µs against 40 µs). So **this decision is free today and
is the difference between 0.1 ms and 15 ms on a real transient**, which is why it is made now
rather than when someone notices.

`cross` therefore scans with `xschem raw value` per point in the chosen direction for a positive
or negative `nth`, and uses `xschem raw values` for `nth = 0`, where the whole column is needed
anyway. An out-of-range point answers the empty string rather than raising.

⚠ **Do not quote those microsecond figures in a source comment.** They are one run each through
Tcl's `time` with a count of 1 on a quiet machine — order-of-magnitude evidence for the decision,
not a benchmark. If the choice ever needs defending, a row re-measures the ratio. (This is the
house rule against writing down a number nothing re-checks.)

**The lesson from the reversal**, which generalises past this function: the recon crew measured
speed because speed was the question asked, and the answer was correct. Nobody asked what the fast
door's *precision* was, so the decision got made on half the data. **A performance number is not
a reason on its own — the cheaper route has to be shown adequate first.**
</details>

### D11. The pre-flight, because `raw add`'s return value does not mean what it looks like

Three measured facts, each of which would be a defect if `cross` trusted the obvious reading:

- **`xschem raw add` never returns −1.** The spec's §3.1 *"unknown vector ⇒ the whole evaluation
  returns `-1`"* is true of `plot_raw_custom_data()` and **false of the Tcl verb**, because
  `raw_add_vector()` discards that return. A bad expression on a fresh name answers **1**, leaves
  the vector behind, and it reads back as 101 defined **zeros** — indistinguishable at the Tcl
  surface from an expression that legitimately evaluates to zero.
- **`rc` means "did I create the name", not "did it evaluate".** Re-adding an existing name
  answers `0` *and still evaluates*, writing the caller's expression into somebody else's column:
  `raw_add_vector()` guards only the registration block, and the `if(expr) plot_raw_custom_data(…)`
  call sits outside that guard.
- **With no raw loaded, `values`, `add`, `index` and `datasets` all RAISE.** Only
  `xschem raw loaded` answers (`-1`) without throwing.

So `cross` does what `calc::eval_rpn` already does, and the implementer **copies that proc's
pre-flight rather than inventing one**: gate on `xschem raw loaded`; reject an empty expression
separately (`calc::rpn_bad_token` answers `{}` for a clean RPN *and* for an empty one); run
`calc::rpn_bad_token` before the engine; and check the destination name with `xschem raw index`
**before** the add. `calc::tmpvec` already mints `__calc_tmp<N>` with a collision probe, and R402
already works today — no `__calc_tmp*` survived either measured call. Note the probe is
**case-insensitive**: `index __CALC_TMP1` resolves `__calc_tmp1`.

### D12. One dataset, explicit, defaulting to 0, never `-1`

The four accessors disagree about their default dataset — `pos_at` → 0, `raw value` → allpoints,
`raw values` → 0, `raw points` → allpoints — so `cross` states its dataset rather than inheriting
one. It must also **validate it against `xschem raw datasets`**, because an out-of-range dataset
reaches issue **1632**'s out-of-bounds read.

Reading across `allpoints` is specifically forbidden, and this was measured with this file's own
D3 and D4: at `L = 0.5` over `dataset -1`, the X column has exactly one non-increasing step (at
the seam, `0.009999999999999995 → 0`) and that step **manufactures a falling crossing at
t = 0.0049999999999999975** — a time inside dataset 0's range that coincides to 2.5 × 10⁻¹⁸ with a
real *rising* crossing. No caller could reject that by inspection, and no tolerance-based row
could tell the two apart.

⚠ **Read the sweep column by NAME, not as index 0.** On the transient plot `time` is index 0 and
reads cleanly. But the fixture's `Operating Point` plot has **no sweep column at all** — its index
0 is `v(sq)` — so a `cross` that assumes index 0 is X is wrong for an OP read. Derive the name
from `xschem raw sim_type` (`time` / `frequency`) and resolve it with `xschem raw index`.

### D7. Refuse a malformed request, in the house style

A non-finite `L`, a non-integer `nth`, and an `edge` outside `rising`/`falling`/`either` are all
refused before any evaluation happens, with a message built the way `calc::eval_refusal` and
`calc::plot_refusal` build theirs — the recon crew reports the exact pattern, and the implementer
**matches it rather than inventing a third style**.

Note this is the *opposite* disposition from `nth` being out of range (D5): a request that cannot
be interpreted is refused, a well-formed request whose answer does not exist reports that it does
not exist. Keeping those two distinct is what lets `settlingTime` tell "you asked me something
meaningless" apart from "this signal never settles".

### D8. `nth = 0` returns a list from the proc; the BUTTON defers

The proc returns every crossing for `nth = 0`, because `frequency`, `period_jitter` and
`dutyCycle` all need the full set and they call the proc, not the button.

The **UI** surface is a different matter. R404 says a T-route scalar lands in the buffer as a
literal number, and a list of forty-seven crossing times is not something the RPN evaluator can
eat — so for v1 the keypad/catalogue path **refuses `nth = 0` with a message naming what is
missing**, and the list case waits for a destination that can hold a wave (Cadence returns a
waveform here, which is the eventual answer, plausibly via `xschem raw table_read`). Deferring a
surface with a message is honest; silently truncating a list to its first element would not be.

**This is the R404 gap the driver flagged to the user, written down rather than left in a reply.**

### D9. Scope boundary for this stage

In: the measurement proc, its plumbing (R401–R403), its refusals, the catalogue row going live,
and the suite. **Out**: the seven derived verbs (PLAN 7.3), the argument dialog's visual design
beyond R412's byte-identical-on-Cancel requirement, the wave destination for D8, and anything
touching the stack (phase 4). A crew that finds itself editing phase 4's `calc::inert` sites has
left its scope.

## 3. What recon settled — every pending item, answered by measurement

### ⚠⚠ Landmine L2 does NOT apply to a named `raw add`. This file said it did, and it was wrong.

The tension §3 flagged — L2 says one shared scratch column, yet `raw_add_vector()` takes a
*name* — resolves **entirely in favour of the name**. Named vectors are persistent and
independent; three successive adds give three independent columns, and a later add does not
disturb an earlier one:

```
add A rc=1   A first5 = 0 0.2 0.4 0.6000000000000001 0.8000000000000005
add B rc=1   A first5 = 0 0.2 0.4 0.6000000000000001 0.8000000000000005
             B first5 = 0 0.3 0.6 0.9000000000000001 1.200000000000001
add C rc=1   A, B unchanged ; C first5 = 0 0.5 1.0 1.5 2.0
```

The mechanism: `raw_add_vector()` grows the arrays by one, so **the old scratch slot becomes the
new named column and a fresh scratch slot is created above it**; `plot_raw_custom_data()` then
resolves `yname` and writes `values[yidx]`, taking the `values[nvars]` default **only when
`yname == NULL`** — which happens at twelve call sites in `src/draw.c` and nowhere else.
`/usr/bin/grep -c 'plot_raw_custom_data' src/scheduler.c` is **0**: there is no Tcl verb that
evaluates into the unnamed scratch column.

**So L2 is a true statement about graph custom-wave expressions and not a statement about
`xschem raw add`.** `cross` carries **no** re-evaluate-before-reading rule. R402's delete stays
mandatory for a different reason: the column is *persistent*, so a leaked `__calc_tmpN` stays in
`xschem raw list` and the viewer's inventory for the life of the database. **Leak hygiene, not a
staleness remedy** — and it cannot use `rc` to decide whether there is anything to clean up,
because a failed add leaves a vector behind and still answers 1 (D11).

### L4 is narrower than R403 implies

No `xschem raw` verb takes a column index as **input** — every read is by name — so the
dangling-pointer half of L4 **cannot be triggered from Tcl at all**. What is Tcl-visible: `raw add`
*appends*, so existing indices survive it; `raw del` *re-indexes*, so a cached `raw index` or
`raw list` goes stale after a delete; and a `raw values` result is a Tcl string copy, immune to
everything. **R403 covers index numbers and inventories, never samples.** `cross` needs one rule
only: do not cache an index across its own `raw del`.

### Clip (R304) is not wired, and is a phase away

`::calc::clip` has **no reader anywhere in the tree**; the checkbutton's `-command` is still
`calc::inert {Clip} 6`, and PLAN puts Clip's semantics at row 6.6 while `cross` is 7.2. So `cross`
scans the whole sweep and **says so in its own header**. The reader it will eventually want
already exists — `wviewer::graph_range {token gi}` — so this is a wiring gap, not a missing
capability. Two things stay undecided and belong to phase 6, not here: which graph is "the target"
when a viewer holds several strips, and whether `graph_range` is called inside the existing
`enter_ctx $tok 1` loan or given its own bracket, since a bare call clobbers the viewer's title
(issue 0173).

### Registration: `hcases`, and the derived trailer

`cross` needs no display, so the suite needs no display gate — which is why the two existing
`hcases` calculator suites have none. Derived expectation, by lifting `summarize_all` out of
`run_regression.tcl`'s own text and running its arms over real captures of sibling `hcases`
suites: **`cases=122 blocks=121 counted_failures=0 skips=8`**, with `Δskips = 0`. The `8` is a
claim that *this registration costs no skip*, not a prediction about the other 121 cases, whose
skip count is environment-dependent. **Read the trailer; do not check it against this number.**

⚠ **Two suite-shape traps, both measured rather than remembered.** The suite must **not** copy
`test_calc_buffer`'s or `test_calc_plot`'s whole-file no-X early exit — those exits print no
`OVERALL: ok`, so an `hcases` entry carrying one is scored `HARNESS: … (exit=0, OVERALL_ok=0,
died=0)` with every one of its own checks passing, which is issue 1615's incident exactly. And the
epilogue keeps `RESULT:` **last** with exactly **one** executable `exit` in the file, because a
second `RESULT:` line silently rewrites the published check count with nothing reddening (issue
1627, open and unfenced). Source `tests/headless/scratch.tcl` for the watchdog even without
calling `test_scratch`; `test_divis_zero_1628` is the in-tree precedent.

### A registered suite WILL redden on this commit, and that is correct

`test_calc_scratch_reuse` row **SR5** asserts that the set of `::calc::` procs touching
`xschem raw add` is exactly `{eval_rpn}`, and likewise for `xschem raw value`. A `cross` that
reads samples makes both answers `cross eval_rpn`. **Whoever implements `cross` owns that edit in
the same change.** SR5 already widened once for Plot and its own comments say how to do it
honestly — name the T-route readers as a *derived* set rather than a hand-kept list, keeping
"exactly one **direct** verb" true and narrow. A `cross` that routed through some other proc to
dodge the row would be gaming the fence.

### The golden data, and two rows that would have passed by luck

Dataset 0's crossings reproduce the fixture README exactly — rising at 1.0, 5.0, 9.0 ms, falling
at 2.2, 6.2 ms — and **D4's exact-sample-hit case is verified on real data**: `v(sq)` at sample 50
is bit-exactly `0.5`, and D4's formula returned exactly `0.005` with no special case.

- **Assert only levels strictly inside (0, 1).** At 0.0 and 1.0 the two plausible strict/non-strict
  conventions disagree in **both count and direction**, and 1.0 additionally carries a dust-driven
  recrossing (`v[51] = 1.000000000000039`). 0.3 and 0.75 are convention-independent and fully
  interpolated; 0.5 is convention-independent in its X values but not in its bracket indices.
- **R414d (interpolated, never snapped) is not fenceable at 0.5**, because those crossings sit on
  samples. That row needs an off-sample level such as 0.25.
- **`rising nth = -1` would pass by luck on `v(sq)`**, because the last crossing overall is rising,
  so it equals `either nth = -1` and a broken direction filter survives. Use the inverted square,
  `1 v(sq) -` (measured working on both datasets); `rising -1` on it must be
  `0.0061599999999999997`, not `0.0090399999999999994`.
- ⚠ **D3's flat-on-`L` limit is NOT reachable through the fixture.** Four of the five 50 % samples
  are 9 × 10⁻¹⁶ to 1.8 × 10⁻¹⁵ off exact, so the asymmetry D3 warns about needs a **synthetic
  clamped column** (an `add` using `min()`/`max()`), not `v(sq)` at 0.5. The row still gets
  written; it just cannot be written against the fixture trace.

### The refusal pattern, by symbol

`calc::eval_msg {kind ?a? ?b?}` is a `switch -exact` returning the sentence;
`calc::eval_refusal {msg ?dataset? ?dest? ?point?}` builds the dict at **one site** so the key set
cannot drift between refusing paths and the one success path. `calc::plot_msg` / `calc::plot_refusal`
are the same shape for Plot. Measured sentence style: leading verb, colon, full sentence, period,
offending value in parentheses — *"Evaluate: the result is not a finite number ($a)."*

**`cross` adds its own `calc::cross_msg` + `calc::cross_refusal` pair in that shape**, rather than
extending `eval_msg`, which is Evaluate's vocabulary.

## 4. Prose corrections this stage owes, found by recon

Two shipped claims are false and both are in files this stage edits, so they are fixed here rather
than filed. **This batch's standing lesson is that a prose claim is the one artefact nothing
re-runs** — it survives a green suite, a sabotage round and an adversarial lens — so a false one
found in passing gets corrected in passing.

1. **`calc::eval_finite`'s header** says *"`expr {$v == $v}` raises a domain error on a NaN operand
   in Tcl 8.5+"*. On Tcl 8.6.17 it returns `0` **without raising**; what raises is arithmetic
   (`$v - 0.5`) and `abs($v)`. The proc's conclusion — be textual, not arithmetic — is still right
   and its portability argument is untouched. Only the stated mechanism is wrong.
2. **Spec §3.1's** *"unknown vector ⇒ the whole evaluation returns `-1`"* is true of
   `plot_raw_custom_data()` and false of `xschem raw add`, which discards it (D11). §3.1 is
   describing the engine and is not wrong about the engine — but a T-route implementer reading
   §3.1 and R401 together will reach for a `-1` that cannot arrive, so §3.1 needs one clause
   saying the Tcl verb swallows it.

## 5. A note on how this stage was run

The driver wrote issue files and `NUMBERING.md` while a recon crew was live. The crew's tree-state
report **flagged it unprompted** — *"their mtimes land inside my run, so another crew is writing
this tree concurrently"* — which is the fence working, and no measurement was affected because no
crew reads those files. The batch rule was *"while a crew holds the tree, the driver edits only
files no crew measurement reads"*; the refinement is that **`git status` is itself something a
crew reads**, so either tell crews up front which files the driver is touching, or expect the
flag and reconcile it. Expecting the flag is cheaper.
