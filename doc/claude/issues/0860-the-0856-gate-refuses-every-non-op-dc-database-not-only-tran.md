# 0860 - the 0856 gate refuses EVERY database that is not op/dc, not only `tran` — a widening the user has not ratified

**Status:** **RULED 2026-08-29 — SETTLED. The widening and the `dbg(0)` line are ratified as shipped; ONE follow-up wording change is owed (see the RULING section at the foot of this file).** Formerly OPEN, awaiting the user's ruling. The behaviour LANDED WIDE on
2026-08-27 with the
[0856](0856-annotate-op-shows-a-transient-s-t-0-as-the-operating-point-silently.md)
gate, and is pinned by row `T27` of `tests/headless/test_op_annot.tcl` so it
cannot drift unnoticed. A `rule` debt carrying both questions below is recorded
in `tests/headless/owed.sh`; only the user clears it.

## The gap between the ruling and the code

The user ruled, verbatim, 2026-08-26:

> "if OP is part of the run, then plot from OP. We haven't yet built anything for
> annotating from TRAN results, so it should do nothing silently. Why complicate
> things?"

That sentence is about **TRAN**. The guard that landed in `update_op()`
(`src/save.c`) refuses everything whose `sim_type` is not `op` or `dc` — `tran`,
`ac`, `noise`, `table` and `vcd` alike.

**Measured live** on the landed binary: an ascii **table** database answers
`xschem update_op` -> `0` and puts nothing on the schematic. Pinned by row `T27`
of `tests/headless/test_op_annot.tcl`.

## Why it landed wide

One rule, one answer. Nothing but `op`/`dc` has ever held a meaningful operating
point, and the narrow alternative — `strcmp(sim_type, "tran")` only — leaves
`ac`, `noise` and `table` publishing their point 0 as though it were an operating
point, which is **RULING D5-1**'s exact failure (a number that was not measured
for the thing it is displayed next to). A per-type allow-list would drift.

`T27` exists so this is a VISIBLE decision rather than a silent one: if the user
later rules that tables should publish, that row reds and forces the
conversation.

## Second, smaller, observation: the log line

The gate is silent everywhere the user looks — no CIW line, no status line, no
number on the schematic — but it prints one `dbg(0)` line per call:

```
update_op(): 'tran' is not an operating point database, publishing nothing
```

`dbg(0)` is the uniform level of both neighbouring refusals in the same function,
so it was left alone rather than made a lone `dbg(1)`. A script grepping an
action log WILL see these lines. Not ratified either way.

## Owed

- Does the widening stand, or should it narrow to `tran` only?
- Does the `dbg(0)` log line stand, or demote to `dbg(1)`?

## RULED 2026-08-29 — the widening STANDS, and the log line STAYS at `dbg(0)`

Decided under the user's instruction of 2026-08-29 ("decide the 23, leave 0861
and 0299 for me"). **Nothing in the tree moves**; this ratifies what already
ships.

**Question 1 — does the widening stand? YES.** `update_op()` keeps its
ALLOW-LIST: it publishes an operating point only when the attached database
calls itself `op` or `dc`, and refuses everything else — `tran`, `ac`, `noise`,
`table`, `vcd` — publishing nothing. The narrow alternative (`strcmp(sim_type,
"tran")` only) would let an AC, noise or table run put its point 0 next to a
device as though it had been measured there, which **RULING D5-1** forbids in as
many words. Cadence does not annotate an operating point out of an AC sweep
either, so the allow-list is also the Cadence-compatible answer, not merely the
safe one. Row `T27` of `tests/headless/test_op_annot.tcl` stays as the pin.

**Question 2 — the `dbg(0)` log line? STAYS AT `dbg(0)`.** Verified in the tree:
both neighbouring refusals in the same function, `backannot_refuse_digital()`
(`src/save.c:1602`) and `backannot_refuse_empty()` (`src/save.c:1652`), emit at
`dbg(0)`; `debug_var` defaults to 0 (`src/globals.c:166`, `src/xinit.c:3605`), so
all three always reach the log. One idiom per function beats a lone `dbg(1)`. The
line is invisible on the product surface — no CIW line, no status line, no number
— and **nothing in the tree greps for it** (the only other occurrences of the
string are this issue file, 0856, 0863 and one ledger entry), so no script's
behaviour turns on the choice. A refusal that leaves no trace anywhere is the
failure mode this branch keeps paying for; keeping the trace costs nothing.

**What the user sees is not silence, and that is what makes the widening
comfortable.** Pressing `6` or `Alt-6` with a non-operating-point database
attached does not reach this guard at all — `cadence::_annot_op_db_ok`
(`utils/annot_mode.tcl:1013`) mirrors the same `op`/`dc` pair and returns first,
so the user gets a named, plain-English sentence on the status line and in the
CIW: "No operating point results are loaded. These are from a '<type>' run
instead, so there are no operating-point numbers to show..."
(`utils/annot_mode.tcl:900`).

**Observation, NOT part of this ruling, and NOT filed here as work:** that
sentence closes by offering `Alt-Shift-6`, and `cadence::annot_tran`
(`utils/annot_mode.tcl:2324` onward) accepts `tran` only — so on an `ac`, `noise`
or `table` run the offer leads to a second refusal. That is 0886's wording, not
0860's gate. If it is ever worth fixing, it belongs to whoever owns that
sentence.

**Verified in the tree, 2026-08-29:** `src/save.c:2300-2305` (the allow-list and
its `dbg(0)`); `src/save.c:1602`, `:1652` (both neighbours at `dbg(0)`);
`src/util.c:265` with `src/globals.c:166` and `src/xinit.c:3605` (`dbg(0)` always
prints); `utils/annot_mode.tcl:1013` (the Tcl mirror of the same pair) and
`:894-903` (the plain-English sentence); `tests/headless/test_op_annot.tcl:7249`
(row T27 pins the widening).

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim, 2026-08-29:

> "decide the 23, leave 0861 and 0299 for me"

A read-only audit of the 57-entry ruling queue classified 25 debts as questions
whose answer is cheap and obvious — things to be DECIDED rather than put to the
user. **This debt was one of those 23** (0861 and 0299 were held back for the
user). Deciding it here is the user's instruction, not an agent overstepping.

⚠ **This section is the settled ruling and it SUPERSEDES the "RULED 2026-08-29"
section above on one point only**: that section parked the false `Alt-Shift-6`
offer as "0886's wording, not 0860's gate", and 0886 is **landed**. A live defect
handed to a closed issue is handed to nobody. The offer is fixed here, and owned
here. Everything else that section says still stands.

### The ruling, as an instruction to the codebase

1. **The widening STANDS.** `update_op()` (`src/save.c`) keeps its ALLOW-LIST:
   it publishes an operating point only when the attached results call themselves
   `op` or `dc`, and publishes nothing for `tran`, `ac`, `noise`, `table` or
   `vcd`. Do not narrow it to a `tran`-only denylist.
2. **The log line STAYS at `dbg(0)`,** beside its two neighbouring refusals in
   the same function. Do not demote it to `dbg(1)`.
3. **The Tcl chord gate keeps spelling the same `op`/`dc` pair**
   (`utils/annot_mode.tcl:1013`), and **row `T27`** of
   `tests/headless/test_op_annot.tcl` stays as the pin. No C change, no test
   change at either of those two places.
4. **BUT the sentence the user actually reads must stop making a promise the
   widening broke** — see "Implied code change" below. That repair belongs to
   **this** issue.

### Why

**On the widening (question 1).** The narrow alternative is the unsafe one. A
`tran`-only denylist would let an AC, noise or table run publish its point 0
next to a transistor as though it had been measured there — **RULING D5-1**'s
exact failure, "never a number displayed next to a thing it was not measured
for". Nothing but `op`/`dc` has ever held an operating point, and Cadence does
not annotate an operating point out of an AC sweep either, so the allow-list is
the **CADENCE-OR-NOTHING** answer as well as the careful one.

⚠ **Correction to the earlier section's claim:** the allow-list is **the safer of
the two options offered**, not "safe". It does not fully satisfy D5-1, and the
recorded ruling must not claim that it does. A genuine multi-point DC transfer
characteristic still answers `update_op()` with 1, puts its FIRST sweep step on
the schematic and reports "n points = 1" while holding five — that is
[0862](0862-update-op-publishes-a-multi-point-dc-sweep-s-first-step-as-the-operating-point.md),
**open and measured**. A later reader who trusts an unqualified "satisfies D5-1"
will not go looking for it.

**On the log level (question 2).** Both neighbouring refusals in the same
function emit at `dbg(0)`, and `debug_var` defaults to 0, so all three always
reach the log; one idiom per function beats a lone `dbg(1)`. The line cannot be
seen by a user at all — the CIW pane mirrors the action log, while `dbg()` goes
to the debug stream, a different file — and nothing in the tree greps for the
string, so no script's behaviour turns on the choice. `update_op()` has four
call sites, none in a draw loop, so it is one line per key press, not a flood. A
refusal that leaves no trace anywhere is the failure mode this branch keeps
paying for; keeping the trace costs nothing.

**On why the sentence is this decision's debt (the reason for item 4).** Before
the widening, an `ac`, `noise`, `table` or `vcd` run never reached the
no-operating-point sentence at all. **The widening is what routes them into it.**
That sentence closes by offering `Alt-Shift-6`, and the transient annotator
accepts `tran` and nothing else — its own comment says `dc` and `ac` are NOT
accepted. So on a Bode plot, XSCHEM now tells the user to press `Alt-Shift-6`,
and `Alt-Shift-6` refuses too. That is **INTENT OVER MECHANISM**'s named defect
— locally correct at every joint, collectively absurd — and **PLAIN ENGLISH** is
not only "use plain words": the user's rule is *say what happened AND what the
user can do about it*. Telling someone to press a key that will refuse is worse
than saying nothing. The truthfulness of that sentence for the newly-routed
analysis types is therefore **this decision's debt**, not a pre-existing
condition and not a landed issue's leftovers.

### Implied code change — FOLLOW-UP WORK, NOT YET DONE

This ruling **ratifies everything that ships in C and in the test pins**, and
requires **one wording repair in Tcl**:

- **File:** `utils/annot_mode.tcl`, the `notop` arm of `cadence::_annot_msg`
  (the type-named shape, currently at `:900`).
- **Change:** make the closing offer of `Alt-Shift-6` **conditional on the
  attached run being a transient**. On a `tran` run the present wording is
  correct and stays exactly as it is. On an `ac`, `noise`, `table` or logic
  (`vcd`) run the sentence must stop naming `Alt-Shift-6` and end after the true
  half — for example: *"No operating point results are loaded. These are from an
  'ac' run instead, so there are no operating-point numbers to show. Run an
  operating point analysis and press 6 again."*
- **Test:** row **V42**'s golden gains the third shape (the non-transient
  type-named sentence). Row **V43** is untouched: the sentence stays minted in
  this one file, so **RULING D5-4** still holds and the fragment still appears on
  a code line of `utils/annot_mode.tcl` and of no other file.
- **Not decided here:** the bare shape (`$path eq {}`, where the attached
  database cannot say what it is) stays exactly as it ships. This ruling covers
  the type-named shape only.

### What was verified in the tree, 2026-08-29

- `src/save.c:2300-2305` — the shipped guard really is an ALLOW-LIST:
  `if(!xctx->raw || !xctx->raw->sim_type || (strcmp(sim_type,"op") &&
  strcmp(sim_type,"dc")))` then `dbg(0, ...)` and `return 0`. The widening is
  real, exactly as this issue claims.
- `src/save.c:1602` (`backannot_refuse_digital()`) and `src/save.c:1652`
  (`backannot_refuse_empty()`) — both neighbours end their sentence with
  `dbg(0, "%s\n", msg)`. The "uniform level" claim is true.
- `src/util.c:265` (`dbg()` prints when `debug_var >= level`), `src/globals.c:166`
  (`int debug_var=-10`), `src/xinit.c:3605` (`if(debug_var==-10) debug_var=0`) —
  so `dbg(0)` always prints, for this line and for both neighbours alike.
- `src/save.c` — the digital (`raw_is_digital`) and zero-point (`allpoints<=0`)
  refusals both sit ABOVE this guard, so `vcd` is shadowed by the digital
  sentence and is not silently swallowed by the widening. Order pinned by `BA37`.
- `utils/annot_mode.tcl:1013` (`cadence::_annot_op_db_ok`) — the chord layer
  spells the same `op`/`dc` pair and returns FIRST, so pressing `6`/`Alt-6` with
  a non-operating-point database attached never reaches the C guard.
- `utils/annot_mode.tcl:894-903` — the user-facing sentence for that state, both
  shapes, and its closing `Alt-Shift-6` offer.
- `utils/annot_mode.tcl:2324` onward (`cadence::annot_tran`) — its own comment
  states `dc` and `ac` are NOT accepted; it takes `tran` only. That is what makes
  the offer false for the newly-routed types.
- `tests/headless/test_op_annot.tcl:7249` — row `T27` asserts an ascii **table**
  database gives `{table 3 0}` with an empty `ngspice_data`; `T23`-`T28` cover
  the whole truth table. `:13186` — row `V42` pins both existing `notop` shapes
  byte for byte; `:13256` — row `V43` pins the single-mint rule.
- `grep` for `is not an operating point database` across `.c/.tcl/.sh/.md` — one
  code site (`src/save.c:2302`) and three doc mentions. **No test, script or tool
  consumes the log line**, so neither `dbg` level changes any observable
  behaviour.
- `doc/claude/issues/0886-*.md` opens `STATUS: **landed**` — confirming that the
  earlier disposition of the false offer routed it to a closed issue.

### Observation, recorded — not work owned here

With a **mixed `op`+`ac` raw** attached as `ac` and being viewed, the gate
refuses before anything goes looking for the `op` plot sitting in the same file.
That is the other half of the user's own ruling of 2026-08-26, *"if OP is part of
the run, then plot from OP"*. It belongs to
[0863](0863-a-mixed-raw-s-op-plot-is-only-found-when-it-is-the-first-plot-in-the-file.md),
which is **open**. Noted here so a later reader sees the connection; no work is
filed against 0860 for it.

### Adversary

An adversarial pass ran against this decision. It could not break either answer —
it confirmed the `tran`-only denylist is the unsafe option and that the `dbg(0)`
line is invisible to the user and cheap — but it **overturned the disposition**,
on the grounds that the ruling was incomplete in a way that hurts the user and
routed the harm to a landed issue. Its better answer is the ruling recorded
above: keep the C, keep the `dbg(0)`, keep `T27`, and fix the one clause the
widening made false, under 0860.

**The user may reverse this at any time; it was decided to spare their attention,
not to bind them.**
