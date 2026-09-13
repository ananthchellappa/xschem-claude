# 1447 — two sweeps of one type, and no word for either of them

**Status:** fixed (schema half; the three surfaces are open — see *What is still owed*)
**Branch:** `fluid-editing`
**Area:** ASE-L — analysis identity and the reference scheme (`src/ase.tcl`)
**Suites:** `tests/headless/test_ase_core.tcl` sections CP7 + HN (18 rows),
`tests/headless/test_ase_persist.tcl` section R8 (5 rows)
**Batch:** `doc/claude/ase_analyses_batch/`, ⚖ **R6**'s addressing task
**Ships the half issue 1444 sequenced here.** 1444 stays open.

---

## The defect

A bench could hold two DC sweeps — *"sweep VIN, and also sweep temperature"* — and
there was **no way to say which one anything meant.** Not in the file, not on the
screen, and not in an expression.

Three places wanted the word and none of them had it:

* **The file.** An `analyses` row carried a `type` and its field values and
  nothing that distinguished it from the row above it with the same `type`.
* **The machine.** `ase::meas_binding` (issue 1443) answered *"which analysis
  occurrence does this measurement read"* as `{type idx}` — an **index**, which is
  a position and not a name. A row inserted above it re-points every reference
  below.
* **The person.** `PLAN.md` §8a's measurement rows were written against a handle
  from the start — `{name pm analysis ac id a1 kind param …}` — and **the scheme
  that spells `a1` had never been specified.** The user raised it while ruling
  ⚖ R6: *"It should be easy for a user to find out how to refer to different
  analyses for purposes of building measure statements."*

⚠ **And a picker would not have closed it.** `src/calculator.tcl` is where a user
**types** an expression by hand. A dropdown solves the dialog and does nothing for
someone composing `180 + vp(out)`, which is the user's own reason for raising it.

## What shipped

**One optional per-row key and one proc that spells a reference.**

`id` is an optional key on an `analyses` row. `analyses` is a list of open dicts,
so there is no `version` bump, no new member of `schema_keys`, and nothing added
to `ase::omit_if_empty` — a key that is never written cannot need omitting.

**The scheme, in one line: a row's handle is its `id` if it declares one, and
`<type><n>` otherwise**, `n` counting 1 from the top among rows of the same type.
`ac1`, `dc1`, `dc2`, `tran1`, `op1`.

```
op1    OP
dc1    DC    V2 0 1.8 0.01
ac1    AC    dec 10 1 10meg
dc2    DC    TEMP -40 125 5  (off)
tran1  TRAN  1n 10u
```

| proc | answers |
|---|---|
| `ase::analysis_id {row}` | the `id` a row declares, or `{}` |
| `ase::analysis_id_ok {id}` | is it a bare identifier a person can type |
| `ase::analysis_handles {state}` | **THE ONE SPELLER** — every row's handle, in stored order |
| `ase::analysis_handle {state idx}` | one row's |
| `ase::analysis_by_handle {state h}` | `{type idx}` — `ase::meas_binding`'s own shape |
| `ase::analysis_handle_faults {state}` | `{idx illegal\|duplicate spelling}` triples |
| `ase::analysis_handle_fields {sim state idx}` | `{handle … type … args … enabled …}` |
| `ase::analysis_handle_text {sim state}` | the whole bench as one copy-pasteable block |

and `ase::meas_binding` gains one arm: a measurement row carrying `id` binds by
handle, and the handle **beats** the `row` index.

## The three decisions inside it

**1. `n` counts every row of the type, switched on or not.** Counting only enabled
rows renames `dc2` to `dc1` the moment somebody unticks the row above it — and a
measurement, or a line typed into the calculator, silently starts reading a
different sweep. Unticking a row is an everyday gesture. A derived handle still
moves when a row is **inserted or deleted**, and that is what `id` is for.

**2. An explicit `id` is claimed over the whole list before any derived handle is
minted.** A row that really is called `dc2` takes the spelling and the second
derived `dc` becomes `dc3`. Without the claiming pass the two are the same word
and the resolver has to pick a winner — a coin toss wearing a rule.

**3. A type the registry does not OFFER still gets a handle.** `registered 0`
entries are invisible to the radio row and to the seed, and a bench can still hold
a row of one. *"What do I call this?"* is a question about the **bench**, which the
state answers, not about the registry, which may never have heard of it.
Sabotage **S6** — derive the handle from `ase::analysis_offered` — reds **one row
of 769** (`HN10`) and nothing else.

## ⚠ The trap: `id` is not the committed output row called `id`

Four committed benches carry `outputs {{name id expr -i(v1) save 1 plot 0}}` — a
**drain current**, in a different list, whose `name` happens to be the word. ⚖ R6's
whole safety argument is that no committed bench moves, and it holds only because
every reader asks an **`analyses`** row. `HN7` and `R8e` drive both at once — the
readers and the file — and sabotage **S5** (treat that output row as a declaration)
reds exactly those two and nothing else.

## Measured

```
104 of 104 tracked .state files load and re-serialize BYTE-IDENTICALLY
   0 committed analysis rows carry `id`
```

That is `CP7`, and `CP7c` is its control: one committed file with one `id` added
to one analysis row stops round-tripping, so the comparison can disagree.

## What is still owed — issue 1444 stays open

The **surfaces** are `src/ase_window.tcl`'s and are not in this change:

| surface | calls | status |
|---|---|---|
| handle column in Choose Analyses | `ase::analysis_handle $state $idx` | open |
| `Analyses > List` | `ase::analysis_handle_text $sim $state` | open |
| Measurements dropdown (Stage 8 task 2) | `ase::analysis_handle_fields`, writes `id` on the measurement row | open |
| an `id` field the user can edit | `ase::analysis_id_ok`, `ase::analysis_handle_faults` | open |

**None of them may mint a second spelling.** The whole point of the scheme is that
the word a user reads off the grid is the word they type into the calculator.

## Ruling owed

The scheme is **new user-facing copy** and rides ⚖ **R9** — the handle spelling
(`dc1` lowercase, as in the user's own sketch, against the house rule that
acronyms are UPPERCASE), the uppercase TYPE column, the `(off)` marker, the
departure from 1444's *"enabled analyses"* in `Analyses > List`, and the three new
refusal sentences. Filed with `owed.sh add rule 1447`.
