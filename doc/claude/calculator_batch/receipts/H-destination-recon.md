# Stage H — the destination for a non-scalar result: recon

Six crews over 2026-10-02 (H1 mechanisms, H2 viewer, H3 blast radius, H4 callers and seam, H5
catalogue consequence, plus an issue-filing crew), two of them resumed for a second round of attack.
Driver collected. Decided contract: `../DESTINATION_CONTRACT.md`. **Blockers: none.**

## The headline: the driver's contract was itself one of the artefacts recon had to correct

Nine driver claims were refuted by measurement across the five recon crews. The worst was not a
wrong fact but a wrong *method*: `DESTINATION_CONTRACT.md` was written to correct false prose in the
tree, and **it reproduced a dead claim inside itself** — asserting that spec §7.2 spells `cross` as
`scalar/list`, which it has never done. `scalar/list` appears **zero** times in
`doc/claude/specs/calculator.md` and `git log -S` finds it never did; the spec had already been
corrected, and the source comment above `calc::catalogue` asserting a deliberate one-word
disagreement is stale prose describing a conflict that no longer exists. The driver read that comment
and believed it.

**That is CLAUDE.md's `grep -c '#pragma'` failure exactly** — a correcting sentence becoming its own
counterexample — and it is recorded here rather than quietly fixed because this batch keeps citing
that rule at other people. The lesson that generalises: **a stale comment is not a weaker source
than code, it is a more dangerous one**, because it reads as settled and nothing re-runs it. Grep the
claim, do not inherit it.

Also wrong, and all five caught by crews: `calc::fn_rows` (does not exist anywhere in the tree — the
proc is `calc::catalogue`); the deferral attributed to `calc::cross` (it is `calc::cross_scalar`;
`calc::cross` never defers); `table_read()` described as destructive to the loaded result (two crews
independently measured the guard unreachable through any `raw` verb); the claim that `raw_read()` is
unaffected by the float parser (true only of the **binary** path and the sweep column); and the
driver's own *correction* of the verb count, which replaced one wrong number with another.

## The verb count, twice wrong

`TIMING_CONTRACT.md` and the spec both said *"three verbs behind one missing piece"*. R419 falsified
it, the driver corrected it to **two**, and that was also wrong. The truth is **two destinations**:
three verbs behind the waveform one (`dutyCycle` default, **`delay` with `nth = 0` on either side**,
`frequency`) and one behind the list one (`cross` via `calc::cross_scalar`). `delay` was the verb the
driver dropped. H5 found it by running awk over the enclosing proc of every `listdefer` call site —
**mechanically, not by reading** — which is the only method that has been right about this number.

## What the user ruled, and what each ruling removed

- **R419 — `cross nth = 0` is a plain list of crossing times.** *"Just a list of crossing times like
  cadence does."* Offered three shapes (a list, dots on the threshold line, crossing-number vs time),
  the user chose the plain one and named the reference tool as the reason. **This refuted a claim the
  driver had written as fact and never asked about** — *"Cadence returns a waveform here"* — which had
  propagated from `CROSS_CONTRACT.md` D8 into the published spec and into two source comments. It also
  took one verb off the waveform destination's queue entirely.
- **R420 — `dutyCycle`'s X axis is an argument with a default.** *"Make it an option to the function.
  Default can be time the cycle started. Other choices you gave can be supported with non default
  values to this argument."* The driver had framed three legitimate X axes as a pick-one. All three
  ship. **The driver should have proposed the parameter rather than asked** — when every candidate
  answer is defensible, the question is not which one, it is what the default should be.

## The route: A, decided on three crews' measurements

| route | verdict | the measurement that decides it |
|---|---|---|
| **A** `raw new` + `raw set` | **CHOSEN** | registers rather than clears; `raw set` parses at full double via `atof()` and stores exactly — a fixture crossing time round-trips **bit-exact**, worst case 1.97e-16 against a 1e-12 door |
| **B** ASCII table + `table_read` | **DEAD** | float32. 1.0e-5 plain, **6.9e-8 at the best possible `%.17e` spelling**. No spelling rescues it |
| **C** staircase in the existing sweep | **DEAD for `cross`**, viable for `dutyCycle` | its cost scales with `npoints` not N (25× the writes, ~240 ms extrapolated); and `cross nth = 0`'s answers *are* X values, so a column indexed by the same quantity plots time against time |

**Irregular X is genuinely supported, and this was the open question.** `draw_graph()` resolves the X
column per node entry **by name** from the rect's `sweep=` list — it assumes neither the database's
declared sweep variable nor column 0. Verified two independent ways: a data-path `fullyzoom`
instrument (a resolvable synthetic name takes a strip from −5..5 to the column's real 0.45..0.52; an
unresolvable one leaves it unchanged) and a pixel probe (predicted 170.4 px → measured 171; predicted
687.0 → measured 687). Nothing resamples and nothing sorts: a deliberately non-monotonic X drew in
sample order.

## The tension, the driver's hypothesis, and how it died

**Registered is required and registered is poison.** An unregistered slot draws nothing at all with
no message, legend entry still showing — the worst failure mode either viewer crew found. But a
registered route-A database is immediately `results::current = idx 1 path wavedest type tran`: **the
Calculator's own scratch output becomes the user's selected result**, and `new_rawfile()` even stamps
`raw->schname` so `xschem raw loaded` still answers 0.

The driver hypothesised that a non-result `sim_type` would make the destination structurally
invisible to result selection and dissolve the tension. Sent out **to be attacked rather than
confirmed**, it survived one leg and died on the other:

- **Survived**: trace resolution is fully type-agnostic — `raw switch <name> <type>` is literally what
  every graph walker calls, and returned the right slot for `tran`, `table` and `vcd` alike.
- **Died**: `results::current` does **not** fall through to the user's result while an odd-typed
  destination is current. It answers `{}`. So the type does not hide the Calculator's slot, it makes
  the *selection unreadable* — which is the fail-safe direction (a refusal rather than a wrong
  number) but **not** a substitute for restoring the current slot.

So the type is a backstop worth exactly one row, and **the restore is the primary defence.** Three
further measurements closed it: `table` is the only usable odd type (`{}` enters as `<NULL>` and both
map to *result*; `vcd` is also `is_digital` and would draw as logic levels); `results::current` reads
the current slot only, returning `{}` at the first failing row; and `results::list` lists the
destination whatever its type, so it appears in the Results ▸ Select picker regardless — declared,
not fixed.

## Two things the driver would have got wrong without measurement

**The restore is TWO explicit switches, not one.** `raw clear` is the last step of cleanup and forces
`extra_idx = 0` *at that point*, so a single restore leaves the user moved:

```
capture (user on op slot) = idx 1 … type op
  new + fill + explicit switch  -> identical to capture
  clear wavedest table (rc 1)   -> idx 0 … type tran    == capture? NO -- the user moved
  explicit re-restore (rc 1)    -> idx 1 … type op      == capture? YES
```

Both by name **and** type — also index-independent, which matters because the clear compacts the
array. ⚠ And `raw switch <name>` without a type does not switch by name at all: it **advances
round-robin** and answers rc 1 while landing anywhere (measured from idx 1 of 3: `op1.raw` → 2, again
→ 0, and a **nonexistent** filename → 1, all rc 1). Only the two-argument form can return 0. A row
asserting `rc == 1` proves nothing; it must assert which slot it ended on.

**⚠⚠ And the fence for all of this would have passed vacuously.** With the user on **slot 0**, "after
clear == capture?" answers YES and the hazard is invisible. A suite with a single-slot fixture, or one
that leaves the user on the first slot, measures nothing while reading green. The fence must read the
fixture twice and drive from a **non-zero** slot — the `op` slot is the case that actually moved.
**Fourth vacuous-row trap this batch has caught before shipping**, and like the others it was found by
asking what the row would do if the defect were present, not by checking that it passes.

## The one fence that must be right, measured rather than reasoned

`draw_graph()`'s local `sweep_name` carries the **last non-empty `sweep=` token forward by name** —
never reset when `my_strtok_r` runs out — so a list shorter than `node=` silently re-axes every trace
after the special one. One strip, three traces, only the token list varied, with `calcx` spanning
0.002…0.004 so a re-axed trace is unmistakable:

| rect `sweep=` | third trace `v(ramp)` |
|---|---|
| `"time calcx time"` (full, control) | x 180..294 — correct, on `time` |
| `"time calcx"` (one token short) | x **369..558** — *the second trace's span, to the pixel* |
| `""` (absent) | every trace falls to column 0 — a **different** failure |

⚠ **All SEVEN walkers carry it forward**, each with its own copy of the idiom — `graph_fullxzoom`,
`graph_fullyzoom`, `find_closest_wave`, `graph_point_at`, `wave_hilight_envelope`,
`graph_wave_resolve`, `draw_graph` — so a short list mis-axes picking, bolding, markers and auto-zoom
as well as the drawing, and **a pixel-only fence misses six of the seven**. The row therefore asserts
the positive shape: `graph_props` emits exactly `[llength $traces]` tokens in node order. ⚠ **The
mixed-axis trace must sit in the MIDDLE** — last position hides the defect completely.

## The change is four sites, and the fifth parameter must not be added

`wviewer::plan_plot` needs **nothing** — its `n` is a count, and the proc is pure strip-landing
policy that never sees an expression, name, colour, database or axis. The four are `add_trace` (a
`sweep` key on `trd`), `graph_props` (emit the token — it emits none today), `interp_value` (stop
hardcoding column 0), and the producer (hold-pad the tail).

⚠⚠ **`wviewer::plot_signals` must not gain a fifth parameter.** Its signature is pinned by **three**
spies, one of them this batch's own `test_calc_plot.tcl`, plus `test_ase_current_repair.tcl` and a
literal-source assertion at row `BM05` of `test_wave_sigbrowser.tcl`. A five-argument call raises
*"too many arguments"*, which `browser_plot_ids`' own `catch` swallows — so **every gesture check
then reads as "the gesture did nothing"** rather than as an error, which is what results-batch item
10 fell into when `destover` was added. The established shape is the out-of-band one-shot channel
`plot_dbs_arm`/`plot_dbs_take`, which exists for exactly this and which the per-signal database
already uses.

## Reachability, stated plainly because a green stage must not be oversold

**There is no user-reachable path to any T-route verb at all today.** `calc::fn_click` dispatches on
`calc::fn_reason`, empty for route `T`, and falls through to `calc::inert … 5`; `cross` renders as a
**live** entry (no greying for route T), so it looks clickable and does nothing; all six menu cascades
hold exactly one `(phase 1: not implemented)` entry; and the engine is not a back door
(`rpn_bad_token {v(sq) cross}` → *"unknown token"*). The only live controls that reach any
computation are Plot and Eval.

**But the lid is cheap to lift for this family.** All four rows that assert the phase-5 deferral
sentence by literal — S23 ×2 in `test_calc_skeleton`, CW13 ×2 in `test_calc_widgets` — drive
**route-P `average`**, not a T-route verb. So wiring `fn_click` for route T **only** costs those rows
nothing; a blanket phase-5 wiring reddens all four. That is why the driver's plan is destination
**then** T-route click wiring, rather than shipping a destination under a closed lid.

## The catalogue, and what R419 did to it

`returns` is **not user-visible**: the complete consumer graph is `fn_entries` (field 1), `fn_row`
(field 0), `fn_fill` (binds all six, renders `$name`, greys on `$route` — **`returns` is bound and
never read**), `fn_hover`/`fn_unhover` (field 5, help), `fn_click` (field 2, route),
`fn_cat_changed`; no argument prompt, tooltip or dialog exists, R412's being phase 5. So the spelling
is an engineering decision, and `cross` becomes **`scalar/list`**.

S24's closed vocabulary widens by one term, verified by lifting its own predicate and running it over
both catalogues: against the real vocabulary the proposed catalogue gives
`badrow = cross=returnsscalar/list intersect=returnsscalar/list`; against the widened one, clean. S24's
eight category counts are `{56 26 12 4 3 3 4 108}` on the real **and** proposed catalogues — the edit
touches field 3 and the counts are over field 1. ⚠ The vocabulary is enumerated in **three** other
places besides S24 (the `calc::fn_fields` schema comment, the `calc::catalogue` comment **twice**, and
spec R416), all of which move together.

⚠ **`intersect` is deliberately left alone.** Its "all" case is `cross`'s shape, so its `returns`
ought to follow — but it has no proc yet (PLAN 7.6) and respelling it drags its **user-visible help
text**, *"Where two curves meet: scalar or wave"*. Changing what a user reads about an unbuilt
function, to match an inference from a ruling about a different function, is not a silent call. One
`rule` debt, raised when `intersect` is built.

## ⚠⚠ The blast radius the driver missed entirely

Rows **MT7** and **MT8** of `tests/headless/test_calc_measure.tcl` — **`hcases`, headless, and they
gate** — `string equal` against `[calc::cross_msg listdefer]`, i.e. **identity** with the shared
deferral sentence, for `delay`'s `nth = 0` and `dutyCycle_scalar`'s default. After R419 one caller
needs a list destination and two need a wave, so the natural move is to split the sentence per
caller. **Splitting it reddens both rows**; a reworded but still **shared** sentence costs nothing.
Both rows carry in-suite comments saying this is where a wording ruling lands, which is the only
reason the trap was visible.

Two more naming traps, same class: `test_calc_engine` **CE8** and `test_calc_plot` **PL9** both glob
`dest_*` into a proc set and assert an **exact literal list**, so a helper named `calc::dest_new`
reddens both — one on `hcases`, one on the `dcases`-only arm that only a gate runs. The helper is
named `calc::wave_dest`. And `test_calc_measure`'s own `mt_direct_raw` covers only
`{add values value del}`, so a route-B helper would have escaped it — the suite's declared hole `H7b`,
exercised here rather than left declared.

## Seven defects filed, 1633–1639

| # | what | severity |
|---|---|---|
| **1633** | ASCII numeric input is parsed by a hand-rolled **float** parser although storage is `double` | **HIGH** |
| 1634 | top-level `xschem table_read` **toggles**: two calls to read one file, the first discards the loaded result | MEDIUM |
| 1635 | `raw new` returns success for a database it failed to allocate; the help text's point count is not the code's | MEDIUM |
| 1636 | `raw clear <name> <type>` silently moves the user's selected analysis to slot 0 | MEDIUM-HIGH |
| 1637 | `pos_at` answers −1 or a **wrong index** on a non-monotonic column; the readout bar asks it about column 0 | MEDIUM |
| 1638 | `test_results_select` is in neither case list **and** prints no completion banner | MEDIUM |
| **1639** | `calc::riseTime` with `nth 0` **RAISES** where both its siblings defer, unfenced | **HIGH** |

⚠ **1633 is bigger than the driver described it, and the correction is the valuable part.** The driver
wrote that `raw_read()` was unaffected. It is not: `read_raw_ascii_point()` reaches the same
`my_atof()` under an `#else /* faster */`, so **an ASCII ngspice `.raw` loses the same precision on
every column except the sweep** (which goes through `sscanf "%d %lf"`). The driver's "unaffected" was
true only of the **binary** path and of the sweep column. There are also **two** mechanisms, not one:
the float truncation, and `my_atof`'s 8-digit `p10[]` cap — so the error depends on the producer's
format string, 1e-5 with `%f` against 7e-8 with `%e`. Filed as item 2 of 1633.

`1636`'s description was corrected too: `raw switch <name>` without a type does **not** land on slot
0, it ignores the name and advances **round-robin** (a nonexistent filename still returns rc 1 and
moves the slot). And `1637`'s indices are a property of the probe column, not constants — the file
says so, because the driver quoted indices from a column the crew could not rebuild.

Stamp checker: `self-test PASSED (180 parser cases)` / `ISSUE-STAMP: ok (0 problems)`, and the T1
case `test_issue_stamp` at `ALL PASS (102 checks)`. All seven reproduced by the filing crew itself.
⚠ Two figures that must not be quoted anywhere: `1635`'s `my_calloc` diagnostic prints **twice**, and
`1638`'s suite reports 375 checks armed against 377 bare — two home-sensitive rows.

## Four rotted citations retired, and a liability that was backwards

Spec R601's `src/wave_viewer.tcl:3962/3977` is rotted — the real symbols are `add_trace`,
`plot_dest`, `set_plot_dest`. `src/wave_viewer.tcl`'s own §D1 comment block cites six `draw.c`/`save.c`
coordinates, none of which land (`draw_graph` and `node_token_split` are both thousands of lines from
where it says), and `tests/headless/test_wave_crossdb_trace.tcl`'s header carries the same three.
**None names the commit it was measured at**, which is what would have made a line number legitimate.
Coordinates are deleted rather than corrected, per the standing rule.

⚠ **PLAN 6.5 calls `%<dataset> <rawfile>` landmine L5 and frames it as a liability. It is the
opposite**: a working, pixel-proven route, and the only cross-database destination that exists. Its
real liability is the **silent blank** when the slot is unregistered — which is now a row. Separately,
`src/calculator.tcl`'s own L5 note is correct and stays: `%<n>` typed into the **buffer** is refused
and named, because the suffix belongs to the `node=` path and not to `get_raw_index()`.

And landmine **L4 is far too narrow**. It says `raw add` appends so indices are stable while `raw del`
re-indexes. True, and it misses the live hazard: **adding or switching a *database* invalidates every
name lookup at once** — `index` → −1, and `list`, `points` and `datasets` all change. A cached index
does not go stale, it goes **meaningless**.

## Scratch discipline

H1 64 KB, H2 244 KB, H3 52 KB, H4 24 KB, H5 swept to zero, issue crew 548 KB **swept to zero**. Two
crews deleted a 2.1 MB probe rawfile and their throwaway homes. `/tmp` unchanged at ~750 MB of 7.7 GB
throughout. Reported per stage because an earlier one left **4.4 GB** in a tmpfs and starved the
machine of the RAM a gate needs.
