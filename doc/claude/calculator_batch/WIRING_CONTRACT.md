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

- **A wave with its own X axis** — `calc::wave_dest`, built and gated, and at the time
  this section was written **with ZERO call sites in the product**.  Unit J1 is its first
  caller.  ⚠ The figure that used to stand here — *"gated at 90 checks"* — is **left out
  deliberately**: it was already stale when J1 landed (102), and a count written into prose
  is a number nothing re-checks.  The suite's own `RESULT:` line recomputes it every run.  Confirmed: the only non-comment
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
   a short `sweep=` list silently re-axes every later trace.  A short list and an
   **absent** list are two different failures.

   ⚠⚠ **THIS BULLET SAID "ALL SEVEN WALKERS" AND IT WAS WRONG — SEE §12.**  The
   number is kept here, struck, because how it got here is the finding.

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

---

## 10. The completeness critic's corrections — and it overturned §4, §5 and §6

A fourth crew read the three recon receipts adversarially and **re-measured** the
claims that mattered.  Receipt: `receipts/J-wiring-recon-critic.md`.  Six of its
findings change this document; they are recorded here rather than edited in above,
because the superseded text is the evidence that the attack was worth running.

### ⚠⚠ (a) A SHIPPED ROW CANNOT TELL A CORRECT RESULT FROM A WRONG ONE

**This is the most serious finding and it is about existing code, not this stage.**
`WD8` — the end-to-end row this batch has been citing as proof of the destination
hand-off — drives the `v(sq)` fixture.

⚠⚠ **CORRECTED BY THE DRIVER, AND THE TRUTH IS WORSE THAN THE CRITIC'S FIGURE.**
The critic measured at `L = 0.5` and quoted a relative 1.8e-15.  **`WD8` sets
`set L [expr {1.0/3.0}]`**, and there the two per-cycle fractions are
`0.31666666666666676` **twice** — the same double, relative spread **exactly
zero** — compared element-wise with `near` at a relative `WDTOL` of **1e-7**.
Issue **1643** carries the measured table.  This is the fourth
quoted-rather-than-derived figure to be wrong in this batch, and the correction
is left visible for that reason.

So a producer that wrote `y[0]` into **both** points, or wrote the Y column
**reversed**, passes WD8.  The row reads as coverage of the hand-off and does not
discriminate the hand-off's most obvious defect.  The same holds across the
fixture: `riseTime` per edge on `v(sq)` agrees to ~4e-15, and on `v(lp)` elements 1
and 2 agree to 9e-15.

**Only `v(lp)` discriminates** — at `L = 1/3`, `{0.33106652549724797
0.3310059686087729}`, a relative **1.83e-4**; at `L = 0.5`, a relative 1.23e-4.
`L = 1/3` is the better of the two and is also `WD8`'s own level, so changing the
column alone fixes the row.

⚠ **One thing the critic got wrong in the product's favour: the X leg is SOUND.**
`sweep` reads back as `{0.0009666666666666667 0.004966666666666667}`, a factor of
five apart, so `WD8` genuinely does discriminate a wrong X column — which is what
band `WD8` was written for.  **The blindness is one leg wide, not the whole
row.**  Every new row in this stage drives
`v(lp)` and carries an explicit distinctness leg.  This is the *precision band's
level is load-bearing* trap from `DESTINATION_CONTRACT.md` §11(c) arriving from the
other direction: there a level made a row **red on correct code**, here a fixture
makes a row **green on broken code**.

### ⚠ (b) §4, §5 and §6 bundled too much into J1 — J1 is PRODUCER ONLY

This document put `calc::fn_measure`'s shape branch and the viewer arm inside J1.
The critic's objection is decisive and is about **evidence**, not scope:
`calc::fn_measure` and `calc::buf_set_number` **both return early on
`calc::has_win .calc.buf`**, so headless they are no-ops.  `test_calc_measure`
(`hcases`) can never observe what a wave answer does to the buffer or the status
line, and `test_calc_skeleton`/`test_calc_widgets` are `dcases` alone.

So a J1 that bundles the surface produces a red-first transcript **half of which
the counted arm cannot see** — and the user, who is remote with only a phone, has
nothing but that transcript.  The unit splits:

| unit | scope | where the evidence lives |
|---|---|---|
| **J1** | `calc::dutyCycle_scalar`'s default-cycle arm, **producer only**. No click, no viewer, no `fn_measure` change. | Entirely the **counted arm**. Nothing on its path calls `calc::has_win`. |
| **J1b** | `calc::fn_measure`'s shape branch (via the pure routing proc of §4) and `wviewer::plot_sweeps_arm`'s first armer. | Gate display arm only, **declared as such**. |

§4's decision — an explicit `shape` key, never inferred from list length — stands
and belongs to J1b.  §6's warning stands: **J1 alone does not put a trace on the
screen**, and the report must say so rather than imply a working feature.

### ⚠ (c) The destination's LIFETIME is an open question, and the contract's answer was wrong

`recon:contract` prescribed wrapping the producer-plus-plot sequence so
`calc::wave_dest_drop` runs on **every** exit path including a raise.  That
contradicts its own finding that a trace resolves the database **by registry
name** (`wviewer::db_suffix` emits `%__calc_dest<N> table` into `node=`) and that
`wviewer::restore` cannot re-read it.

**Dropping on the success path frees the database the user is looking at.**  So:
the drop belongs on the **failure** paths only, and *who frees a destination the
user is now looking at* is an open design question nobody has answered.  J1
**answers** the destination and does not drop it, and **declares the undropped
slot as a known leak that J1b owns**.

### ⚠ (d) The existing leak fences cannot see this stage's leak

`MT8`'s, `MT9b`'s and `WD9`'s `leaked`/`probeleft` legs glob `__calc_tmp*`,
`__mt_*` and `__wd_*` over the **current database's column names**.  A wired caller
that never drops leaks a registry **slot** named `__calc_dest<N>` whose columns are
`calcx`/`calcy` in a database nobody switches to — measured: three leaked slots
leave **all four globs empty**.  And every band reloads with `xschem raw clear`,
which silently sweeps the evidence between bands.

**Only `wd_nslots` counts slots at all.**  A leak fence for this stage must count
slots, not glob column names.

### ⚠ (e) Two corrections to measured facts this batch has been citing

1. **A bare `raw switch <name>` is ROUND-ROBIN, not slot 0.**
   `DESTINATION_CONTRACT.md` §7 hazard 1 says it *"answers rc 1 while silently
   landing on slot 0"*.  Re-measured over three registered slots: rc 1 from every
   slot, landing `0→1`, `1→2`, `2→0`.  It lands on slot 0 **only from the last
   slot**.  ⚠ A restore fence written from §7's account would **pass on a two-slot
   fixture**, which is this batch's own named vacuity trap.
2. **`switch_back` after a successful `calc::wave_dest` lands on the
   DESTINATION**, not on the user's slot: parked at `cur=0 prev=1`, the inventory
   afterwards reads `cur=0 prev=3`, and `switch_back` goes to `cur=3`.  After
   `wave_dest_drop` the pair reads `cur=0 prev=0`, so the user's `prev=1` is lost
   there too.  **This is a pre-existing defect in `calc::wave_dest_restore`, not
   something J1 introduces** — so a J1 row asserting `switch_back` returns the user
   to their previous slot is **red on correct J1 code**.  It must be filed and
   fixed as its own unit, or J1's red becomes ambiguous.

### ⚠ (f) Two rows this stage must not rely on

- **`WD9`'s derived-caller keystone cannot double as the stage's fence.**  It
  reddens *to announce* the stage — both the `{cross_scalar delay dutyCycle_scalar
  riseTime}` leg and the `atleast 4` leg move — and once its expectation is edited
  nothing re-asserts that `dutyCycle_scalar` now answers a destination.  **The new
  claim needs a NEW band**, and the `atleast` leg must be **re-derived, not
  decremented**, or it stops being a floor.
- **The answer dict would carry two destination-shaped keys.**
  `calc::dutyCycle`'s cycle-0 dict already holds `dest __calc_tmp<N>` — the
  temporary `calc::cross` minted *and deleted*.  Merging the live destination in as
  `db` leaves a dict with a **retired** name in `dest` and the live one in `db`,
  and `MT9b`'s sibling rows read `dest` **by name**.  A row written against the
  wrong key measures the dead one.

### What the cost actually is, apportioned (which `recon:cost` never did)

**J1 moves exactly FOUR rows**, all on the counted arm: `MT8`'s default-cycle row
and `WD9`'s three sharing rows, plus both suites' published check counts.  `MT7`
and `MT9b` drive `delay` and `riseTime` only, so they belong to J3 and J2.  No
trailer term moves, because no suite is being registered.  Nothing display-only
moves **provided J1 stops at the producer** — `dutyCycle` already carries `returns
scalar/wave` so S24 holds; no new `-command` so CW13 holds; no `calc::dest_*` proc
so PL9/CE8 hold; and no `wviewer::*` call from inside `calc::` so **SR5's two
viewer-door literals hold**, which is the row that makes J1b's viewer arm a
deliberate choice rather than a free one.

### And the honest limit of J1's own evidence

**Two points is the most `dutyCycle` can ever produce on the committed fixture**
(`v(sq)` has three rising crossings, so two periods; `dataset 1` is identical), and
three is the most *anything* yields.  Two points cannot catch a stride or an
off-by-one inside the fill loop, cannot catch a dropped middle sample, and gives
the X list only two values to be in the wrong order.  **This batch's own lesson is
that two is not enough.**  J1's row is therefore structurally weaker than it looks
and must say so rather than claim coverage; the three-point case arrives with J2.

---

## 11. Unit J1, as landed — and the four things it taught that §1–§10 did not know

Commit `486a9635`.  Receipts: `receipts/J1-producer-suite.md` (the suite, three attacks and
the repair) and `receipts/J1-implementation.md` (the guard's rows, the implementation and an
independent verification).

```
red    test_calc_wave_dest  12 FAILED (90 passed)    test_calc_measure  10 FAILED (160 passed)
green  test_calc_wave_dest  ALL PASS (102 checks)    test_calc_measure  ALL PASS (170 checks)
unmoved  cross 187   engine 265   scratch_reuse 54
```

Nine sabotages, all caught.  **Five were re-run against the finished code rather than
re-read**, because a green run is not evidence that a fence still fences — this batch's most
expensive lesson, learned from a row whose arm sweep had rotted to 24 of 31 arms while staying
green for a whole stage.

### (a) The guard went INTO J1, and §10(b) was half right

§10(b) split the surface out of J1 on the grounds that the counted arm cannot observe it.  That
reasoning was sound and the conclusion was wrong, because the suite crew then measured the
consequence: **on a producer-only tree a click pastes the whole per-cycle list over the user's
expression, silently.** A producer-only commit on a public branch is a **regression**, so the
guard could not wait for J1b.

What §10(b) got right is kept: the **routing decision** is a pure proc (`calc::fn_sink`) and
gates on the counted arm, while the **act** — the buffer really being left alone, the sentence
really reaching the widget, the undo still being one step — is display-only and declared.  The
split was between *decision* and *act*, not between *producer* and *surface*.

### (b) ⚠ A SEQUENCING HAZARD: the row and the key must land in ONE commit

The suite crew asserted the answer's key set **exactly** and declared in writing that adding
§4's `shape` key would redden it deliberately.  The guard crew then measured both orders:

| tree | result |
|---|---|
| the widened key-set row **ahead of** the producer | a gate red for a key nothing sets |
| the producer **ahead of** the row | a gate red for a key the row does not expect |

So the producer's spec gained one word — merge `{db type xname yname n}` **plus**
`dict set r shape wave` — and band MT12's ten rows had to land in the **same** commit, because
on a producer-only tree they are **eight standing reds**.  Recorded in the band's own comment so
nobody meets it as a gate red.

### (c) The odd-parity switch comment was DRIVEN, not cited

`calc::arg_msg` gained three arms, so the parse trap this batch has been warning everyone about
became live at a real site.  The crew inserted `# R419 applies` — **three words, odd** — between
two patterns and measured `3 FAILED (167 passed)` with every arm reporting `RAISED`.

**The fence is a derivation, not a list.** Band MT12 lifts the arm set out of `calc::arg_msg`'s
own `switch` patterns and asks every one for a sentence, so the ten arms — including the three
added here — are swept the moment they exist.  That is the repair for the rot recorded in
CLAUDE.md, applied prospectively for once rather than after a row was found to have rotted.

### (d) ⚠ A declared hole that is ALREADY crossed, measured rather than reasoned about

Row **S24** bounds a sibling sentence family at **72 characters**, and the bound is on
`calc::fn_reason`, **not** on `calc::arg_msg` — so the three new sentences are swept by nothing.
The verifier measured them rather than trusting the implementer's figure:

| sentence | length |
|---|---|
| the destination sentence at a five-digit serial | **exactly 72** |
| the shape refusal with a realistic token | **74** |
| the value refusal with a 20-element value | **319** |

So the hole is not crossable in principle, it is **already crossed**.  The two refusals are
unreachable through today's click path, so no user can produce them yet; the sentence a user
*does* meet is filed as a `rule` debt with a 62-character alternative offered.

### What J1 still does NOT do, stated plainly

**No trace appears on screen.** `wviewer::plot_sweeps_arm` still has zero callers, which is
also why row SR5's `$viaviewer == {plot_rpn}` one-name literal still holds (re-run: 54 checks).
The user gets a registered two-column database in the Results picker and must plot it
themselves.  Arming the viewer is J1b.

**`riseTime` and `delay` still defer** (J2 and J3), `frequency` is still catalogued with no
implementation, and `cross`'s list destination still waits on phase 10's Table.

**The destination is not dropped on success** — a declared leak, because a trace resolves the
database by registry name and freeing it would free what the user is looking at.  Who frees it
is still unruled (§10(c)).

⚠ **A wrong Y column is fenced in ONE suite only.** The verifier re-ran CONSTANT-Y and
`test_calc_measure` answered `ALL PASS`: the WD11 rows in `test_calc_wave_dest` are the whole
fence.  That is a real bound on coverage, not a note.

---

## 12. ⚠⚠ §7.4's "all seven walkers" is WRONG — and §10 is where that correction should already have been

Unit J1b's recon derived the `sweep=` reader population over `src/*.c` and then read every site.
Receipt: `receipts/J1b-recon-and-suite.md`.  Issue **1645** carries the registration half.

| | count | which |
|---|---|---|
| **carry the token forward** | **SIX** | `draw_graph`, `find_closest_wave`, `graph_fullyzoom`, `graph_point_at`, `graph_wave_resolve`, `wave_hilight_envelope` |
| **read it once (first token only)** | **THREE** | `graph_fullxzoom`, `graph_x_extent`, and the others below — **a different defect**, which no carry-forward fence touches |
| **total readers** | **NINE** | the six above plus three |

⚠ **`graph_fullxzoom` — the FIRST name in the list this contract printed — does not carry forward
at all.**  It reads the token with `find_nth(get_tok_value(…, "sweep", 0), …)` per contributing
database.  So the stated set was wrong at its head.

⚠ **Two user-visible readers are in NO list anywhere**: `backannotate_cursor_b_in_db` and
`waves_callback`'s Button-2 drag-to-position arm, both in `src/callback.c`, both
`get_raw_index(find_nth(get_tok_value(r->prop_ptr, "sweep", 0), ", ", "\"", 0, 1), NULL)` with a
silent `if(idx < 0) idx = 0`.  Those are **cursor-B backannotation to the schematic** and **the
strip's mouse-to-X mapping** — two surfaces a user touches, missing from the stated blast radius.

### Why the wrong number survived, which is the part worth keeping

**Seven is correct — for a DIFFERENT PREDICATE.**  Rows `NDR2`/`NDR3` of
`tests/headless/test_node_token_split.tcl` assert that all **seven** `node=` walkers that *sample*
a database resolve the sweep column **by name** and clamp it against the switched-in `nvars`.  That
is genuinely seven, because `graph_fullxzoom` resolves per contributing database inside
`graph_x_extent`.  **The contract took a correct count attached to "resolves by name" and reused it
for "carries the token forward."**  That is CLAUDE.md's `grep -c '#pragma'` failure exactly: a
figure that survives because nobody re-derives the predicate behind it.

⚠ And `test_node_token_split` is **registered in neither list** (issue 1645), so the one row that
re-measures a walker count every run was never run — which is why nothing re-attached the number to
its predicate.

### ⚠⚠ The process failure, recorded because it is mine

**`receipts/J-wiring-recon-contract.md` already stated both findings exactly** — nine readers, three
first-token-only, six carry-forward, and the mixed-strip `graph_fullxzoom` consequence — and called
this contract's sentence *"WRONG TWICE"*.  §10 is the section that exists to record that crew's
corrections.  It carries **six of them and not this one**, and §7.4 went on reading "all seven
walkers" with no correction beside it, into every brief built from this document.

**A correction that was measured and then dropped out of the document crews are told to read first
is worse than one never made**, because it is now load-bearing twice: once as a false fact, and once
as evidence that this contract's corrections can be trusted.  The shipped comment above
`wviewer::graph_props` copies the same sentence and must be corrected in the product too.

### And the driver's framing of the risk was overstated — measured both ways

This document told a crew the carry-forward was *"the defect most likely to make J1b silently
wrong."*  It is not:

- `wviewer::graph_props` emits the token list **in full or not at all** (re-measured over three
  strip shapes; `WD4` pins it), so the product **cannot produce a short list**; and
- `calc::wave_dest` makes `calcx` **column 0** of its own database, so with `sweep_idx` initialising
  to 0 the measured trace draws against its own X **even with no token at all**.

The three defects that **are** live, in order of what a user would notice: the `calcx`/`calcy` name
collision of issue **1644** (every measurement after the first draws the first one's curve),
`graph_fullxzoom` being unable to frame a **mixed** strip (`sweep={time tshift time}` frames
`0..0.01` and the second quantity's extent never enters the union), and an **unconsumed arm**
persisting to re-axe the next plot in that window.
