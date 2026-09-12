# 1419 — the one escape from a typed form that actually emits

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C6** of Stage 3 of `doc/claude/ase_analyses_batch/`.

## Why an escape has to exist at all

Issues 1416–1418 turned every parameter an analysis genuinely has into a typed field and then shut
the door on everything else. That is correct and it is also not sufficient: ngspice's `.control`
block accepts things no field table will ever enumerate — an `alter` on a device parameter, a `set`
of an option for one analysis only, a `save` of an internal node. A tool that offers no escape at
all does not stop people needing one; it makes them stop using the tool.

⚠ **Every escape this stage inherited was a lie.** `Options…` collected free-text pairs,
round-tripped them through the `.state` file and rendered them back in the Arguments column — and
emitted nothing (issue 1418). The Arguments column is what made the lie convincing: the user saw
their setting confirmed. `x` is the replacement, and the entire difference is that **it emits**.

## What ships

`x` on an analysis row: a **list of verbatim lines** placed into `.control` immediately above that
row's own analysis command. `ase::analysis_verbatim` is the one reader; `ase::analysis_emit_check`
gains a **`verbatim`** offence; `ase::ui::arg_summary` appends `+ verbatim: <n> line(s)`.

## It is a row key, not a field, and that distinction is load-bearing

A `field` no template spends is exactly what `ase::analysis_schema_errors` refuses — so declaring
`x` as a field would make the registry self-inconsistent **by its own rule**. It is not an unknown
key either, because unlike everything C5 shut the door on, something reads it. So it joins `type`
and `enabled` as a row key the schema knows about directly.

## Above its own analysis, not at the top of `.control`

These lines exist to set something up for **this** analysis. A deck with three enabled analyses
that hoisted every hatch to the top of the control block would apply one analysis's setup to all
three — silently, in run order, with no line anywhere saying so. Row **VB2** puts a different hatch
on two enabled analyses and requires each to sit immediately above its own command.

## An escape that cannot be wrong is an escape nobody can trust

A malformed list raises inside `render_deck`'s `foreach`, where there is no sentence to say about
it; it is refused by `analysis_emit_check`, where there is one. A **blank** line among the verbatim
lines is refused too — it emits an empty line into `.control`, which ngspice accepts and which makes
the deck unreadable to the next person who opens it. `ase::analysis_verbatim` itself never raises:
two of its three callers are on paths where a raise is either swallowed (`arg_summary`'s catch) or
fatal (`render_deck`).

## The column shows a count, not the contents

Three `.control` lines pasted into a one-line treeview cell would push the analysis line — the thing
the column is *for* — off the right-hand edge. But it may not be **silent** either: a deck carrying
lines the window never mentions fails the second half of this batch's acceptance criterion, and it
fails in the direction where the user runs something they cannot see. So the cell reads
`tran 1n 1u  + verbatim: 2 lines`.

## Suites

`test_ase_core.tcl` **337 → 343** (section **VB**).

⚠ **VB3's first draft pinned a whole deck against one rendered in section D, and failed on one
thing: the `write` line's raw-file path.** Section D renders while the rundir still resolves to the
user's default; by the time VB runs, a later fixture has moved it into the suite's scratch tree. The
decks were otherwise identical. **A row that pins a whole deck across a file this long is really
pinning every fixture between the two points**, and it reds for whichever of them moved last. VB3
now strips the hatch's own lines out of the hatched deck and requires the remainder to equal the
unhatched one byte for byte — order-independent, and the actual claim.

## What this does NOT ship

**An editor.** Until one lands, `x` is reachable by hand-editing a `.state` file — which is the tier
the plan's third refusal level already exists for. The Arguments column shows the count, so a deck
carrying a hatch is never invisible, and `analysis_emit_check` refuses a malformed one before a run.
