# 0514 — no Tcl accessor for `raw->schname`, so R804's sentence cannot name the schematic a result was read against

**Status:** OPEN. Measured on branch `fluid-editing` at `8b6a8278` (results
batch, after item 3) with the item-4 binary. Pre-existing — nothing in the batch
caused it.
**Area:** the `raw` / `raw_query` arm of `xschem`, `src/scheduler.c:10332ff`
(the token list), against `Raw.schname` (`src/xschem.h`).
**Found:** 2026-08-19, results batch item 4, writing R804's sentence
(`doc/claude/specs/results_selection.md` §10).
**Severity:** low, and entirely a message-quality one — no wrong answer, no
crash. It costs the user the one clause that would tell them *where to go back
to*.

---

## What

A loaded database is bound to the schematic that was current when it was read
(`raw->schname` / `raw->level`), and every name lookup is gated on that stamp
still being on the current hierarchy stack — `sch_waves_loaded()`
(`src/draw.c:2825`). **Tcl can ask whether the stamp resolves and cannot ask what
the stamp says.**

Measured — the whole token list the `raw`/`raw_query` arm answers:

```
add annot datasets del index list points pos_at rawfile rename sim_type
value values vars view_armed view_keys
```

plus `casemode`, `is_digital`, `non_spice`, `loaded`, `info`, `clear`, `read`,
`select`, `switch`, `switch_back`, `new`, `table_read`, `vcd_read`. **No
`schname`.** `xschem get raw_level` (`src/scheduler.c:5007`) returns
`xctx->raw->level` and nothing else.

`xschem get schname <n>` exists (`src/scheduler.c:5080`) but is a **stack**
query — it answers `xctx->sch[n]` — so it cannot stand in: in exactly the state
the sentence describes, the raw's `level` indexes a *different* stack, and
`get schname $raw_level` would name the wrong cell with total confidence.

## Why it matters

`doc/claude/specs/results_selection.md` R804 is the sentence the Results
Selection feature exists for:

> Selected srlatch_ase.raw (dc), but this result was read against **srlatch.sch**
> and you are in tb_diff_amp.sch — no signal names will resolve until you return.

`results::select` can name the file (`wviewer::db_label`) and the cell you are in
(`xschem get schname`), and **cannot** name the cell it was read against. Ruling
**R804c** therefore takes that clause from the caller (`opts read_against`) and
drops it when no caller supplies one, falling back to

> Selected srlatch_ase.raw (dc), but this result was not read against
> tb_diff_amp.sch — no signal names will resolve until you return to the
> schematic it was read from.

which is true and useful and still does not say *where*. The same gap hits the
`Results ▸ Select…` dialog (item 7, R404): a `Loaded` row can show `db_label` and
cannot show what each row is bound to, which is the one column that would explain
why a listed database answers nothing.

## Repro

```tcl
xschem load -inplace cellA.sch
xschem raw read an.raw tran
xschem raw loaded            ;# 0   -- it resolves
xschem load -inplace cellB.sch
xschem raw loaded            ;# -1  -- it does not
xschem raw rawfile           ;# .../an.raw
xschem raw schname           ;# ERROR: no such token. THE ISSUE.
xschem get raw_level         ;# 0   -- an index into cellA's stack, not cellB's
xschem get schname 0         ;# .../cellB.sch  -- the WRONG cell, confidently
```

## Candidate fix

One read-only token in the existing arm, beside `rawfile` and `sim_type`
(`src/scheduler.c:10751-10754`), which are two lines each:

```c
} else if(argc > 2 && !strcmp(argv[2], "schname")) {
  Tcl_SetResult(interp, raw->schname ? raw->schname : "", TCL_VOLATILE);
```

`raw` is already the guarded `xctx->raw` of that arm. A `level` token beside it
would close the other half (`xschem get raw_level` answers only the *current*
database and there is no per-slot form), but that is not needed for R804.

**Not fixed in item 4 on purpose:** that item's scope is Tcl only. Whoever takes
this should also revisit R804c — with the accessor, `results::select` reads the
clause from the engine and `opts read_against` becomes a caller override rather
than the only source.

## Where it is written down

- `doc/claude/specs/results_selection.md` §5.2 **R804c** (the ruling and this
  measurement), §10 R804 (the sentence).
- `src/results.tcl`, `results::_r804_msg`'s header comment.
- `doc/claude/results_batch/receipts/04-results-select-orchestrator.md`.
