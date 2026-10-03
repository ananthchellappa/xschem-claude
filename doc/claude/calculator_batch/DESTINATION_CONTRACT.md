# The destination for a non-scalar result — the implementation contract

**Opened by the driver 2026-10-02**, before any code exists, while four recon crews are still out.
Companion to `CROSS_CONTRACT.md` and `TIMING_CONTRACT.md`, both of which stay in force. Where this
file and `doc/claude/specs/calculator.md` differ, **the spec wins and this file is the bug**.

The stage exists because four already-written callers defer their user-facing surface, across **two**
destinations — ⚠ **and this sentence is the corrected one; the driver's first version of it named
three callers, one of them wrongly.** Enumerated mechanically, by the enclosing proc of every
`listdefer` call site:

- the **waveform** destination: `calc::dutyCycle_scalar`'s default cycle (`TIMING_CONTRACT.md` R416),
  `calc::delay` with `nth = 0` on **either** side, and the unbuilt `frequency`;
- the **list** surface: `calc::cross_scalar` with `nth = 0` (`CROSS_CONTRACT.md` D8, as corrected
  there by R419).

The original sentence said *"three verbs … `calc::cross` with `nth = 0`, `calc::dutyCycle`'s default,
and the unbuilt `frequency`"*, which is wrong in three ways at once: `calc::cross` never defers
(`calc::cross_scalar` does), `calc::delay` was dropped, and the one caller it did name first is the
one waiting on the **other** destination. Nothing new has to be invented for any of them to *compute*;
they compute correctly today and have no way to hand the answer over.

## 1. What the user ruled, and the stage it split in two

### R419 — `cross` with `nth = 0` returns a PLAIN LIST of crossing times

> *"Just a list of crossing times like cadence does."*

Asked directly, with three shapes offered: a list in a dialog; dots plotted at the crossing times
sitting on the threshold line; or crossing-number-versus-time, where the slope shows the spacing.
**The plain list was chosen over both richer shapes**, and the user named the reference tool's own
behaviour as the reason. So:

- **No Y axis is invented.** Not the threshold level, not the ordinal, not the sample index. A list
  of X values is a list of X values, and the surface that holds it is a list.
- `cross nth = 0` is therefore **not a waveform result at all** and never was — which is the part
  that changes this stage's shape, below.
- The standing project rule is that ADE-L is a **floor**, so a convenience it lacks may still be
  kept. This ruling declines one. That is the user's call to make and it is made: the plain shape is
  what they want to see, so a plot is not a feature here, it is a difference.

### ⚠ The consequence: ONE stage became TWO, and one of them shrank

**This contradicts a sentence the driver wrote three times** and should be read as a correction, not
as news. `G-timing-verbs-recon.md`, `TIMING_CONTRACT.md` R416 and the spec's `dutyCycle` note all say
some version of *"three verbs behind one missing piece makes that destination the measurement layer's
critical path"*. After R419 that is **false** — but ⚠ **the driver's first correction of it was also
wrong**, and a crew caught that too. The sentence is not "two verbs instead of three": it is **two
destinations**, with **three** verbs behind the waveform one and **one** behind the list one. The
verb the driver dropped is `calc::delay`, which defers behind the same sentence when `nth = 0` is
given on *either* side. Enumerated mechanically, by awk over the enclosing proc of every `listdefer`
call site, rather than by reading: `calc::cross_scalar`, `calc::delay`, `calc::dutyCycle_scalar`.

| what it needs | verbs behind it | status |
|---|---|---|
| a **waveform** destination — a wave whose X axis is not the loaded sweep | `dutyCycle` default, `delay` with `nth = 0` either side, `frequency` | route **A** decided; §7 |
| a **list** surface — N values, no Y, readable and copyable | `cross` with `nth = 0`, via `calc::cross_scalar` | W14 (`Table`) is inert, routed to `calc::inert {Table} 10`; spec R606; PLAN phase 10 |

**Prose this stage owes**, and it is an obligation rather than a nicety, because all three sentences
read as current fact: the spec note and the two contracts must be corrected in the commit that lands
this stage. ⚠ **"corrected to two verbs" is what this sentence said, and it is the driver's own wrong
correction surviving inside the paragraph that demands corrections** — the right statement is the
table immediately above: **two destinations**, three callers behind the waveform one and one behind
the list one. The DATED RECORDS — this batch's `LEDGER.md` items and the earlier receipts — are
**superseded, not edited**: the correction stands beside them, because editing a dated record to
agree with a later ruling falsifies the record. This is the third time this batch that a shipped
sentence has been
falsified by a later ruling — the first two were tables disagreeing with a ruling written beside
them — and the lesson keeps being the same one: **a ruling obliges re-reading what the tree already
claims, because nothing re-runs prose.**

## 2. What is still open, and who is measuring it

Four recon crews are out as this file is written. Nothing in this section is decided; it is here so
that a reader knows which questions the receipts must answer.

- **H1 — the three candidate mechanisms.** `xschem raw new` + `xschem raw set`; an ASCII table plus
  `xschem raw table_read` / `xschem raw read <f> table`; or padding into the existing sweep via
  `xschem raw add`. The make-or-break question is whether each **registers an additional database**
  or **clears the loaded result** — `table_read()` in `src/save.c` carries a `dbg(0, …)` saying
  *"must clear current data file before loading new"*, and a destination that destroys the user's
  simulation is not a destination. Also the precision door again: `xschem raw values` prints
  `%.16g`, `xschem raw value` returns `dtoa()` = `%.8g`, and the fixture documents a 1e-12 tolerance
  for `time`. A route that cannot carry a crossing time at that tolerance is dead.
- **H2 — the viewer side.** Whether a trace can name a vector in a non-active database (the
  `%<dataset> <rawfile>` token form, landmine L5, PLAN 6.5), what `wviewer::add_trace` accepts, and
  whether an **irregular X** is drawn faithfully or silently resampled.
- **H3 — the blast radius.** Which registered rows each route reddens; and the severe one: whether a
  Calculator-created database can be mistaken for a user **result** by W05's live resolution through
  `results::current`. A Calculator evaluating against its own scratch output would be wrong in a way
  no row currently catches.
- **H4 — the callers and the seam.** What each waiting verb hands over, every site that currently
  defers, and the question R419 just promoted: **is R606's Table the right surface for a bare list
  with no Y, and is it reachable without phase 5?**

## 3. The caveat that must be carried into the report

`calc::fn_click` dispatches on `calc::fn_reason`, which is empty for route `T`, and falls through to
`calc::inert … 5`. So `cross`, `riseTime`, `delay` and `dutyCycle` are **not clickable today**, and a
destination does not by itself change that — phase 5 owns R410/R411/R412. Whether this stage can ship
something the user can actually reach is H4's question 3, and the answer goes in the report in plain
words either way. **A green destination is not automatically a feature**, and the previous two stages
were both reported with that caveat attached rather than discovered later.

## 4. The driver's decision on the catalogue's `returns` field

R419 falsifies the stated justification for `cross`'s `returns` value, so the value is revisited here
rather than left to be rediscovered. The relevant comment in `src/calculator.tcl` sits above
**`calc::catalogue`** and records that `scalar/wave` was chosen for three reasons — one of which was
*"the reference tool returns a WAVEFORM for `nth = 0`"*. **That reason is now dead**, and it was a
guess the user has refuted.

⚠ **Two things the driver wrote in this very section were false, and a crew measured both.** The
catalogue proc is `calc::catalogue`, not `calc::fn_rows`, which **does not exist anywhere in the
tree**. And the claim that spec §7.2 spells `cross` as `scalar/list` is **false**: the string appears
**zero** times in `doc/claude/specs/calculator.md` and `git log -S` finds it never did — the spec was
already corrected to `scalar/wave`, and the source comment asserting a deliberate one-word
disagreement is stale prose describing a conflict that no longer exists. **The driver read that stale
comment and reproduced its dead claim here, in the document written to correct dead claims.** That is
CLAUDE.md's `grep -c '#pragma'` failure exactly — a correcting sentence becoming its own
counterexample — and it is recorded rather than quietly fixed because the rule it breaks is one this
file is otherwise citing at other people.

**This is the driver's call and not a ruling**, on a measurement: `calc::fn_hover` publishes
`[lindex $row 5]`, the `help` field, and the function browser's canvas renders only `$name`. The
`returns` field is therefore **not user-visible anywhere** — the "table read by a person" the comment
defends is the spec's §7.2 documentation table, not the UI. An internal field's spelling is an
engineering decision.

**Decision: `cross` becomes `scalar/list`, and S24's closed vocabulary widens by one term.** The
field's only real future consumer is the dispatch this very stage is about — deciding which surface a
result needs. After R419 a list result and a wave result go to **two different destinations**, so
collapsing both into `scalar/wave` would blind the field exactly where it is about to be read.
`dutyCycle` genuinely is `scalar/wave` under R416, and the two must now be spelled apart precisely
because the difference is load-bearing. Widening S24 is a one-word edit in a `dcases` suite, and the
gate's display arm verifies it — the same arm that verified last stage's `dutyCycle` change, and the
only arm that can, since that suite self-skips to 0 checks under `--nogui`.

⚠ **And the consequence spreads further than `cross`.** The same comment justifies `scalar/wave` by
noting that `intersect`, `frequency` and `freq` already use it and share `cross`'s shape — one value
for an ordinal request, many for "all". But that shape splits under R419: `frequency`'s "many" is a
genuine wave (one value per cycle, with a Y), while `intersect`'s "many" is a **list of X values**,
exactly like `cross`. So the three siblings must be re-decided individually, by measuring what each
one's "many" case actually contains, not by inheriting a spelling. Handed to a crew rather than
guessed, because inheriting a spelling from a sibling is how the wrong one spread in the first place.

## 5. Prose the stage must correct, with the sites named

Four sites assert the refuted Cadence claim or the inflated dependency. Listed so the correction is
mechanical and nothing is missed — searching for the phrase again later is how the
`grep -c '#pragma'` failure happened:

⚠ **The driver's list of four was wrong in three ways and incomplete by nine.** A crew enumerated the
real set: **18 live sites**, plus four dated records to leave alone. Two of the driver's four were
misattributed (`calc::cross` never defers — `calc::cross_scalar` does; and `calc::fn_rows` does not
exist), one asserted a conflict that had already been fixed, and **three of the eighteen are in this
contract itself**. The full table is in the stage receipt; the four that matter most:

| site | what is false, and why it is the worst |
|---|---|
| `calc::cross_msg`'s `listdefer` arm — ⚠ **USER-VISIBLE PRODUCT STRING** | *"so a destination that can hold a **wave** has to come first"*. The one false sentence a user can actually read. Becomes *"a destination that can hold more than one"* — ⚠ and it **must stay a single shared sentence**, see below |
| the comment above `calc::catalogue` | asserts a deliberate `scalar/list` vs `scalar/wave` disagreement with §7.2 that **does not exist**; the whole paragraph goes |
| spec §7.2's `cross` table row | `scalar/wave` → `scalar/list`. **This is the authoritative site**, since this file's own header says the spec wins |
| spec R416, and `TIMING_CONTRACT.md` R416 | not just the verb count — the clause *"the waveform destination that R414's `nth = 0` is already waiting on"* **is itself the refuted claim** |

### ⚠⚠ The real blast radius is not S24, and the driver missed it

Rows **MT7** and **MT8** of `tests/headless/test_calc_measure.tcl` — **`hcases`, headless, and they
gate** — assert `string equal` against `[calc::cross_msg listdefer]`, i.e. **identity** with the
shared deferral sentence, for `delay`'s `nth = 0` and `dutyCycle_scalar`'s default. After R419 one
caller needs a *list* destination and two need a *wave*, so the temptation is to split the sentence
per caller. **Splitting it reddens both rows.** They compare by identity and never by words, so a
**reworded but still shared** sentence costs nothing. Both rows carry in-suite comments saying this
is where a wording ruling lands, which is the only reason the trap is visible at all.

### `intersect` is deliberately left alone this stage

Its "all" case is the same shape as `cross` — X values where two curves meet — so its `returns`
*ought* to follow. It is not changed here for two reasons: **it has no proc yet** (PLAN 7.6), so
nothing depends on the spelling; and respelling it drags its **user-visible help text**, which reads
*"Where two curves meet: scalar or wave"*. Changing what a user reads about an unbuilt function to
match an inference from a ruling about a different function is not a call to make silently. One `rule`
debt, raised when `intersect` is built.

`CROSS_CONTRACT.md` D8's parenthetical — *"(Cadence returns a waveform here, which is the eventual
answer, plausibly via `xschem raw table_read`)"* — is the **origin** of all four. It is superseded,
not deleted: the superseded reasoning stays with the correction beside it, as D10's did, because a
contract that quietly loses a wrong decision teaches nobody.

## 6. R420 — `dutyCycle`'s X axis is an ARGUMENT, with a default

The driver asked the user to pick one X axis for the per-cycle series from three candidates: the
time each cycle started, the cycle number, or the cycle's midpoint. The user refused the framing:

> *"Make it an option to the function. Default can be time the cycle started. Other choices you gave
> can be supported with non default values to this argument."*

So all three ship. **Default: the time the cycle started.** The other two are reachable by a
non-default value of a new argument, and `frequency` inherits the same argument when it is built.

**The driver should have proposed this rather than asked.** Every one of the three was a legitimate
thing a user might want to see, which is exactly why no single answer could be argued for — and a
pick-one framing was about to discard two working behaviours to avoid a decision about precedence.
The reference tool this Calculator clones is full of optional arguments of precisely this kind. The
lesson generalises and is recorded with the same weight as the two refuted performance intuitions:
**when the candidate answers are all legitimate, the question is not which one, it is what the
default should be.**

Recon had already measured all three as constructible: `calc::dutyCycle` computes `r0`, `r1` and `xf`
per cycle today and **discards all three**, so cycle-start and midpoint are both already in hand and
only the ordinal needs no data at all.

## 7. The route, and the tension that decides its shape

### Route A — `xschem raw new` + `xschem raw set`. Decided, on three crews' measurements.

- **It registers; it never clears.** `new_rawfile()` adds a slot and the user's result survives at
  slot 0, verified by both H1 and H3.
- **`raw set` writes the sweep column at full double precision.** It parses with C `atof()` and
  stores exactly; a fixture crossing time round-trips **bit-exact**, and worst-case over six
  full-precision doubles is **1.97e-16** against the fixture's 1e-12 door.
- **It plots, measured two independent ways** — H1's `fullyzoom` data-path instrument (a resolvable
  synthetic name takes a strip from −5..5 to the column's real 0.45..0.52, an unresolvable one leaves
  it at −5..5) and H2's pixel probe (predicted 170.4 px, measured 171; predicted 687.0, measured 687).
- **Irregular X is genuinely supported**, and this was the open question: `draw_graph()` resolves the
  X column **per node entry, by name**, from the rect's `sweep=` list. It does not assume the
  database's declared sweep variable and does not assume column 0. Nothing resamples and nothing
  sorts — a deliberately non-monotonic X drew in sample order.

### Route B — an ASCII table plus `table_read`. DEAD, on precision, killed twice independently.

`table_read()` is the tree's only reader of `SPICE_DATA_TYPE`, which `src/xschem.h` defines as
`1 /* Use 1 for float, 2 for double */` while `SPICE_DATA` is `double`. The `#if SPICE_DATA_TYPE == 1`
arm parses with `my_atof()`, a hand-rolled **float** parser. H1 measured ~1e-7 relative error; H3
carried the fixture's own crossing time through and got 1.0e-5 plain and **6.9e-8 at the best possible
`%.17e` spelling**. Against a 1e-12 door, **no ASCII spelling rescues it.** This is the same precision
door that reversed D10, now on its third appearance, and it is a filable engine defect in its own
right.

### Route C — a staircase padded into the existing sweep. Viable for `dutyCycle`, DEAD for `cross`.

Constructible and plottable today, and it is the only route that leaves `results::current`
byte-identical. But its cost scales with `npoints` rather than with N — 25× the writes on the
fixture, ~240 ms extrapolated to a 100 000-point column, which would roughly **double** the verb's
hot cost against route A's ~0.1 ms. And it cannot express `cross nth = 0` at all, whose answers *are*
X values: a column indexed by the same quantity would plot time against time.

### ⚠⚠ The tension, and the shape that may dissolve it

**Registered is required and registered is poison.** A trace resolves the destination out of the
registry by name+type `strcmp`, and an **unregistered** slot draws nothing with no message at all —
a silent blank with the legend entry still showing, which is the single worst failure mode either
viewer crew found. So the destination must stay registered. But H3 measured that a registered
route-A database is immediately `results::current = idx 1 path calcdest type tran`: **the
Calculator's own scratch output becomes the user's selected result**, and `new_rawfile()` even stamps
`raw->schname` so `xschem raw loaded` still answers 0. A Calculator evaluating against its own
output is a wrong-number defect no existing row catches.

The hypothesis, assembled from three receipts and **out for attack rather than confirmation**: route
B is invisible to result selection for a *type* reason (`raw_type_is_non_spice` → `_is_result_type` 0
→ `results::current` answers `{}`), `raw new` accepts **any** `sim_type` including the empty string,
and trace resolution is a `strcmp` that does not care what a type *means*. If all three hold, a
route-A database created with a **non-result `sim_type`** is registered and plottable while being
structurally invisible to `results::current`. If it does not hold, the switch-back discipline below
is the only defence and this stage needs more rows, not fewer.

### Three hazards that are now requirements, not notes

1. **Restore the user's slot explicitly, by name and type.** `raw switch_back` is a **1-deep toggle**
   (`extra_idx` ↔ `extra_prev_idx`) that verifies nothing about where it lands, and `raw switch <name>`
   *alone* answers rc 1 while silently landing on slot 0. Capture `(name, type)` before touching
   anything and restore by both.
2. **Cleanup is itself destructive and cannot be fixed here.** `raw clear <name> <type>` sets
   `extra_idx = 0` **unconditionally**, so a user sitting on an `op` slot silently ends up on slot 0
   `tran` with no sentence — and `src/ase.tcl`'s `ase::attach_dbs` already depends on that behaviour,
   so it is load-bearing elsewhere. Reuse without clearing is not an escape either: `raw new` on an
   existing name returns **0**, ignores the requested geometry and keeps the previous evaluation's
   samples, which would freeze the point count at the first call and serve stale data.
3. **`raw add <sweepname> <expr>` clobbers the sweep in place**, and `raw set` only ever touches the
   **current** database — with the wrong one current it silently no-ops, or on a name collision
   **writes into the user's result** (measured: a planted name took the write).

### Two things decided on crew findings, adopted as written

- **The helper is not named `calc::dest_*`.** `test_calc_engine` **CE8** and `test_calc_plot` **PL9**
  both glob `dest_*` into a proc set and assert an exact literal list, so a `calc::dest_new` reddens
  both — one on `hcases`, one on the `dcases`-only arm that only the gate runs. `calc::wave_dest` is
  green everywhere. A naming collision with a test's glob is not a thing to discover in a gate.
- **A new fence asserts `results::current` is unchanged across an Evaluate.** H3's recommendation,
  adopted because of the reason attached to it: a leaked destination does not merely redden, it makes
  **every existing `__calc_tmp*` leak row vacuous**, since `xschem raw list` then reads the wrong
  inventory. A row that silently stops measuring is worse than a row that fails.

### What the producer must do that nothing warns about

`raw_add_vector()` makes every column `allpoints` long and **zero-fills** it, and `draw_graph` plots
the whole dataset — so an N-point result draws a **false diagonal from the last real point back to
(0, 0)**. H2 has the PNG. The destination must **hold-pad** the tail at the last real value, which
costs only an invisible overdraw on the final pixel. Related and separate: `xschem raw pos_at` is a
binary search and answers **−1 or garbage** on such a column, which matters because
`wviewer::interp_value` calls it and hardcodes column 0 for the sweep — so the Tcl cursor readout on
an own-X trace would show a number computed against `time`. The C-side in-graph measurement is
already correct; only the readout bar is not.

## 8. The change, scoped to four sites — and the fifth parameter that must not be added

`wviewer::plan_plot` needs **nothing**. Its `n` argument is a *count*, not the expressions; the proc
is pure strip-landing policy returning `new` and `targets`, and it never sees an expression, a name,
a colour, a database or an axis. Measured, not inferred from comments. So:

| site | change |
|---|---|
| `wviewer::add_trace` | accept a sweep and put a `sweep` key on `trd` (today: `expr`/`name`/`vec`/`color`, plus optional `rawfile`/`sim_type`) |
| `wviewer::graph_props` | emit the `sweep=` token — it emits **none** today |
| `wviewer::interp_value` | stop hardcoding `set sweep [lindex $names 0]` |
| the producer (`calc::wave_dest`) | hold-pad the tail; never leave `raw_add_vector`'s zero fill |

### ⚠⚠ `wviewer::plot_signals` must NOT gain a fifth parameter

Its signature `{token exprs {colors {}} {destover {}}}` is pinned by **three** spies, and one of them
is **this batch's own suite** — `tests/headless/test_calc_plot.tcl`, plus
`test_ase_current_repair.tcl` and a literal-source assertion at row `BM05` of
`test_wave_sigbrowser.tcl`. A five-argument call raises *"too many arguments"*, which
`browser_plot_ids`' own `catch` swallows, so **every gesture check then reads as "the gesture did
nothing"** rather than as an error. That file's own warning records results-batch item 10 falling
into exactly this hole when `destover` was added.

The established shape is the **out-of-band one-shot channel** `wviewer::plot_dbs_arm` /
`plot_dbs_take`, which exists for this reason — the per-signal *database* already travels that way.
A sweep follows it verbatim: arm before the call, `take` as the **first statement** of
`plot_signals` before any early return, pad to `exprs`' length as `dblist` does, and drop it in
`wviewer::forget`.

## 9. The one fence this stage must get right, and why pixels are the wrong oracle

`draw_graph()`'s local `sweep_name` carries the **last non-empty `sweep=` token forward by name** —
`sweep_name` is never reset when `my_strtok_r` runs out, so a list shorter than `node=` silently
re-axes every trace after the special one.

**Measured, and the number is the argument.** One strip, three traces, only the token list varied;
`calcx` spans 0.002…0.004 only, so a re-axed trace is unmistakable:

| rect `sweep=` | third trace `v(ramp)` |
|---|---|
| `"time calcx time"` (full, control) | x 180..294 — correct, on `time` |
| `"time calcx"` (one token short) | x **369..558** — *the second trace's span, to the pixel* |
| `""` (absent) | every trace falls to column 0 — a **different** failure again |

So `""` and a short list are two distinct defects and a fence needs both negatives.

⚠ **All SEVEN walkers carry the token forward, each with its own copy of the idiom** —
`graph_fullxzoom`, `graph_fullyzoom`, `find_closest_wave`, `graph_point_at`,
`wave_hilight_envelope`, `graph_wave_resolve` and `draw_graph`. A short list therefore mis-axes
picking, bolding, markers and auto-zoom as well as the drawing, **so a fence that only renders
misses six of the seven.**

**What the row asserts is the positive shape, not the absence of the wrong one** — that rule is in
CLAUDE.md because a symptom-keyed fence dies quietly when something else cures the symptom:
`graph_props` emits exactly `[llength $traces]` whitespace-separated `sweep=` tokens, in node order,
with the database's own X name for every ordinary trace. ⚠ **And the mixed-axis trace must sit in
the MIDDLE of the strip**, because a special trace in last position hides the defect completely.

## 10. The final shape, after two rounds of attack

The driver's hypothesis — that a non-result `sim_type` would make the destination structurally
invisible to result selection and thereby dissolve the registered-is-required/registered-is-poison
tension — **survived the plottability leg and died on the leg it was built on.** Both halves matter.

**What survived.** Trace resolution is fully type-agnostic: `xschem raw switch <name> <type>` is
literally what every graph walker calls, and it returned the right slot for `tran`, `table` and `vcd`
alike. So an odd type costs nothing in drawing.

**What died.** `results::current` does **not** answer the user's result while an odd-typed
destination is current — it answers `{}`. So the type does not hide the Calculator's slot; it makes
the *selection unreadable*. That is the fail-safe direction, because the Calculator then refuses with
`calc::no_result_msg` rather than serving a number computed against its own scratch output — but it
is **defence in depth, not an alternative to restoring the current slot.**

Three further measurements closed the design:

- **`table` is the only usable odd type.** An empty `sim_type` is dead — `{}` enters as `<NULL>` and
  `results::_is_result_type` maps both to *result*. `raw_reader_table[]` has exactly two non-result
  rows, `table` and `vcd`, and **`vcd` is also `is_digital`**, so a vcd-typed destination would draw
  as logic levels.
- **`results::current` reads the current slot only**, returning `{}` at the first row that fails
  `_is_result_type` rather than falling through; that predicate has exactly one consumer in the tree.
  ⚠ But `results::list` **does** list the destination, so it appears in the Results ▸ Select picker
  whatever its type. Declared, not fixed.
- **`xschem raw switch <name>` without a type does not switch by name.** The by-name arm needs both
  arguments; with one it falls past the digit arm to *"switch to next"* and answers **rc 1 while
  landing on the wrong slot**. And `switch_back` is unsafe for a second reason beyond being a 1-deep
  toggle: `node_db_restore`'s own comment records that a **read-only** graph getter already clobbers
  `extra_prev_idx`.

### The restore is TWO explicit switches, not one

The driver wrote one. `raw clear` is the last step of cleanup and forces `extra_idx = 0` *at that
point*, so the sequence is:

```
capture (name, type) BEFORE anything
  -> raw new -> fill -> raw switch <user> <type>      (mid-life restore: identical to capture)
  -> ... -> raw clear <dest> table                     (user has now SILENTLY MOVED to slot 0 tran)
  -> raw switch <user> <type> AGAIN                    (identical to capture)
```

Both restores by name **and** type, which is also index-independent — and that matters, because the
clear compacts the array.

### ⚠⚠ The fence that would have passed vacuously

**With the user on slot 0, "after clear == capture?" answers YES and the hazard is invisible.** A
suite with a single-slot fixture, or one that leaves the user on the first slot, measures nothing at
all while reading as green. So the fence must **read the fixture twice and drive its Evaluate from a
non-zero slot** — the `op` slot is the case that actually moved. This is the fourth vacuous-row trap
this batch has caught before shipping, and like the others it was found by asking what the row would
do if the defect were present rather than by checking that it passes.


## 11. Corrections from the suite author — eight, and two change the implementation

The suite is `tests/headless/test_calc_wave_dest.tcl`, **88 checks, bands WD0–WD10, `hcases` alone**
(derived from `summarize_all`'s own arms on both arms, which measure the identical 88 — nothing in it
is display-only). Red first: **39 FAILED (49 passed)**, exit 1, **zero aborted bands, zero `RAISED:`,
zero `UNEXPECTED ERROR`**, with WD0 and WD1 — infrastructure and the independent derivations —
**fully green on the red run**, which is what lets a reader tell "the feature is absent" from "the
suite is broken". 20 mutations, 19 reddening only their own bands, 22 rows narrow to exactly one.

### ⚠⚠ (a) A REGISTERED GATING SUITE WILL REDDEN, AND THIS CONTRACT DID NOT SAY SO

`test_calc_scratch_reuse` goes **53 → 2 FAILED (51 passed)** against a conforming reference. Row
**SR5** derives four sets over the `calc::` namespace and asserts them equal; the producer **must**
call `xschem raw add` — it is the only way to create a second column — so it lands in `adders`
without minting a `calc::tmpvec`, reading samples back, or deleting.

**The producer is right and SR5 is narrow.** R402's mint-and-delete discipline is about a
*temporary*; the destination's Y column is **persistent** — the same exemption SR5's own comment
already grants `plot_rpn`. **SR5 widens in the implementation commit**, exactly as it did for
`cross`. The suite author correctly did **not** edit a registered suite, and left two WD10 rows
carrying the corrected invariant — the four-way equality holds for every direct caller *except* the
destination producer — so whoever widens SR5 meets a named claim rather than a four-list diff in a
gate. Blast radius elsewhere is clean: `test_calc_engine` 265, `test_calc_cross` 187,
`test_calc_measure` 125 with **MT7/MT8 green**, `test_wave_viewer` 59.

### ⚠⚠ (b) TWO SLOTS IS NOT ENOUGH — §10's own fix was necessary and NOT sufficient

§10 said "read the fixture twice and drive from a non-zero slot". Measured, with slots
`{0 tran, 1 op}` and the user on 1: post-clear the current slot is forced to 0, and the **wrong**,
name-only restore lands on "the next one" = slot 1 = `op` — **the right answer by accident.** The row
passes over the very defect it was written to catch. With three slots `{0 tran, 1 ac, 2 op}` and the
user on 2, the wrong restore lands on 0 mid-life and 1 post-clear, neither of which is 2. So the
fixture is read **three** times and the user sits on `op` at **slot 2**, with both wrong landings
themselves rows. This is the *fifth* vacuous-row trap, and it was hiding inside the fix for the
fourth.

### ⚠ (c)–(d) The precision band's level is load-bearing, and "~1e-8" is level-dependent

`v(sq)`'s level-`L` crossings are `0.9 + 0.2L` ms and **inherit `L`'s digit count**. Measured `%.8g`
relative error: `L = 0.5` → **2.2e-16**, `L = 0.27` → **1.9e-16** — both *inside* 1e-12, so a
discrimination row at a round level would be **RED ON A CORRECT TREE**. `L = 1/3` gives
**3.4e-9 … 6.7e-9**, past the door by three orders. The band drives `L = 1/3` and *derives* the
discrimination every run rather than quoting a figure. Likewise the lossy-echo row needs the right
value: `raw set`'s return on `0.008954…` differs by 1.9e-16 and demonstrates nothing;
`0.0009666666666666667` echoes as `0.00096666667`. Both halves confirmed — `raw values` round-trips
**bit-exactly**, `raw set`'s return does not.

### ⚠ (e) The hold-pad is CONDITIONAL, and exact sizing is the better requirement

§7 said the producer "must hold-pad the tail". Measured: `xschem raw new <db> table <x> 0 <n-1> 1`
yields **exactly n** points for every n driven, so a longer database is a *choice*, not a constraint —
and a zero-padding mutation under exact sizing produced **byte-identical output**, i.e. the pad branch
is dead code nothing can observe. **So the requirement is exact sizing**, which removes the false
diagonal at source and also retires §7's note about `raw pos_at` on a padded column. The hold-pad
rows stay as belt and braces, and the mutation that matters is over-allocate **and** zero-pad
together.

### ⚠ (f)–(g) Two arity pins, not one; and CE8/PL9's mechanism is one step off

§8 warns only about `wviewer::plot_signals`' fifth parameter. **`wviewer::graph_props` is also
arity-pinned** — row `GT8` of `tests/headless/test_wave_grid.tcl` asserts
`[llength [info args wviewer::graph_props]] == 3` with the third named `grid`. Neither that suite nor
`test_wave_sigbrowser`, `test_wave_modes` or `test_ase_current_repair` is in either case list, so none
gates — but all are `full_audit.sh`-reachable, and a broken arity there is still broken. Both arities
are now a row.

And CE8/PL9 do not assert an exact literal list of the `dest_*` glob set, as §7 states: they assert
`>= 18` / `>= 6` members and *then* an exact literal list of those whose decommented code names no
`.calc` path. **The conclusion stands** — `calc::wave_dest` is safe, `calc::dest_*` is not, confirmed
by mutation — but the stated mechanism was wrong, and a reader fixing it from this file's description
would have aimed at the wrong assertion.

### (h) The deferral-caller set is DERIVED, which makes issue 1639 self-announcing

The real set is `{cross_scalar delay dutyCycle_scalar}`, and `calc::riseTime` with `nth = 0`
**raises** rather than joining it (issue **1639**). The band derives the set instead of listing it, so
**if 1639 is fixed by making `riseTime` defer, the band reddens naming the undriven caller** — a fence
that reports its own obsolescence rather than silently covering less.

⚠ **THAT PREDICTION WAS PAID OUT ON 2026-10-03 AND IT IS THE STRONGEST THING THIS SECTION CAN SAY.**
1639 was fixed by making `calc::riseTime` defer, and `WD9` reddened on the first run afterwards —
`{cross_scalar delay dutyCycle_scalar riseTime}` against an expectation of three, naming the caller
nothing was driving. The remedy was to **drive** the fourth caller in `WD9`'s identity and pairwise
rows; the derivation was **not** relaxed, and its lower-bound leg moved with it. The set above is
left as the dated figure it was — read the row, never this sentence.

### Holes the suite declares, and the two the driver must act on

H1 `wviewer::interp_value` is unfenced here (needs a viewer window and a mixed strip — a `dcases`
viewer suite, and it is issue 1637). **H2 the rendering is deliberately unfenced** — a pixel fence
reaches only `draw_graph`, which is one reader of the `sweep=` token among many, so the band asserts
the positive shape upstream of all of them; **that the engine then draws it is a `look` debt.**
⚠ **THIS SENTENCE SAID "all seven walkers carry the token forward … a pixel fence would miss six"
AND IT WAS WRONG TWICE** — same defect as §7.4 of `WIRING_CONTRACT.md`, corrected there in its §12.
`graph_fullxzoom`, the first name the old list gave, reads field ONE once for the whole rect and
carries nothing, and the population derived over `src/*.c` is larger than seven, with two
user-visible readers in `src/callback.c` (`backannotate_cursor_b_in_db` and `waves_callback`'s
drag-to-position arm) that no list anywhere named. **The number is gone from this sentence on
purpose**: band **WD12**'s first row of `tests/headless/test_calc_wave_dest.tcl` derives the
population and both partitions every run and reddens naming a new walker, which is the only form
CLAUDE.md permits a figure to take. (The seven is right about a *different* predicate — rows
NDR2/NDR3 of `tests/headless/test_node_token_split.tcl`, seven `node=` walkers resolving the sweep
column BY NAME — and was reused here without re-deriving the set.) H4 a restore by captured
*index* is structurally indistinguishable from name+type on this fixture, because `raw new` appends
and clearing never compacts the user's slot — the band fences the observable end state, which is the
hazard, and would pass an index-based restore. H5 every measurement reads the `tran` plot; an
`ac`/`op`-sourced destination is unfenced. H8 leak hygiene **across a throw** is unfenced, and that is
the one path which would leave the user on the Calculator's own scratch database.

### Registration, derived not predicted

`hcases` alone, one entry in `tests/run_regression.tcl`. Derived delta: **cases +1, blocks +1,
counted_failures +0, skips +0, `wc -l` +3** → `cases=124 blocks=123 counted_failures=0 skips=8`,
`wc -l` 371. `planned_cases` arithmetic agrees independently at 124 (3 tcases + 96 hcases + 24 dcases
+ `xschemtest`). Structural shape confirmed: one `exit`, one `OVERALL: ok` site, `RESULT:` last, no
whole-file no-X early exit, and **zero real Tcl `switch` commands in the file**, which sidesteps the
comment-between-patterns trap entirely. **Read the trailer.**
