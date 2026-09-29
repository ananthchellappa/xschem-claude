# 0514 — no Tcl accessor for `raw->schname`, so R804's sentence cannot name the schematic a result was read against

**STAMP:** `v1 claim=fixed tree=57a7dadc stamped=2026-09-29 fix=taken open=1`

**Status:** **FIXED**, 2026-09-29 — one read-only token in the existing arm, plus
`tests/headless/test_raw_schname_0514.tcl` (20 checks) registered in `hcases`.
Originally measured on branch `fluid-editing` at `8b6a8278` (results
batch, after item 3) with the item-4 binary. Pre-existing — nothing in the batch
caused it. ⚠ **Its severity was understated below as "entirely a message-quality
one": measured 2026-09-29, `read_against` — the only thing that could supply the
precise clause — has NO PRODUCTION CALLER, so the sentence this accessor exists
for had never fired for a real user at all.** See the resolution.
**Area:** the `raw` / `raw_query` arm of `xschem`, `src/scheduler.c:10332ff`
(the token list), against `Raw.schname` (`src/xschem.h`).
**Found:** 2026-08-19, results batch item 4, writing R804's sentence
(`doc/claude/specs/results_selection.md` §10).
**Severity:** as filed, "low, and entirely a message-quality one — no wrong
answer, no crash. It costs the user the one clause that would tell them *where to
go back to*." ⚠ **That reading was too kind and the resolution says why**: the
clause had no production source, so the whole sentence was unreachable.

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
xschem raw schname           ;# THE ISSUE -- but see the correction below
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

---

# RESOLUTION — 2026-09-29

## What was built

Two lines in `src/scheduler.c`'s `raw`/`raw_query` arm, between the `sim_type` and
`vars` tokens, inside the arm's existing `raw && raw->values` gate — byte-for-byte
the candidate fix above:

```c
} else if(argc > 2 && !strcmp(argv[2], "schname")) {
  Tcl_SetResult(interp, raw->schname ? raw->schname : "", TCL_VOLATILE);
```

Fenced by `tests/headless/test_raw_schname_0514.tcl`, **20 checks, registered in
`hcases` in the same commit** (a suite in neither list is run by nothing that gates
a commit). Its epilogue was checked against `banner_complete` *itself* rather than
against `run_suites.sh`'s verdict — see the note at the end.

## The red, verbatim, before `src/scheduler.c` was touched

`RESULT: 12 FAILED (8 passed)`, the load-bearing rows being:

```
C2-the-accessor-names-cellA-while-get-schname-raw_level-confidently-names-cellB
   ->got ({ERR:Wrong command} cellB.sch)   (exp cellA.sch cellB.sch)
E2-all-four-clauses-R804-needs-are-answerable-from-the-engine-in-the-non-resolving-state
   ->got (an.raw tran {ERR:Wrong command} cellB.sch)
   (exp an.raw tran cellA.sch cellB.sch)
```

After: `RESULT: ALL PASS (20 checks)`, green on the headless arm, on the display
arm, and under T1's own spelling.

⚠ **One row passed VACUOUSLY on the broken tree and was caught and rewritten.**
`C3` originally asserted only that the accessor's answer *differed* from the stack
query's — which is trivially true when the accessor returns an error string. It now
also requires the answer to be an existing file equal to cellA. The first red run
reported 11 failures; the quoted 12 is after the repair. **A row that discriminates
only by inequality is satisfied by any error.**

## Sabotage matrix (each rebuilt and re-run)

| variant | red rows | note |
|---|---|---|
| drop the ternary (`raw->schname` bare) | `G1c`, `G2` (**2**) | nothing behavioural moved — the honest result: the NULL is **not** Tcl-reachable |
| wrong field (`raw->rawfile ? …`) | `B1 C2 C3 C4 E1 E2 D1 D2 G1c G2` (**10**) | |
| **the plausible liar** (`xctx->sch[raw->level] ? …`) | `C2 C3 C4 E1 E2 D2 G1c G2` (**8**) | `B1` and `D1` — the *agreeing* states — correctly stayed **green** |

The third variant is the one that matters: it is the implementation a reasonable
person would write from `get raw_level` + `get schname`, and group C is what
refuses it.

## The one guard that is fenced statically, stated plainly

**No behavioural row drives `raw->schname` to NULL, because it is not reachable
from Tcl.** `my_strdup2()` leaves the destination NULL only when
`xctx->sch[xctx->currsch]` is NULL, and `xctx->sch[0]` is `<cwd>/untitled.sch` at
startup and **survives `xschem clear force`**; all four stamping sites write it.
So the guard is fenced by *reading the source*: `G1c` cuts the `raw`/`raw_query`
arm out of `scheduler.c` between two anchors each unique in the file — necessary,
because `!strcmp(argv[2], "schname")` now also appears in the `get` arm, which is
the very stack query this issue is about, so a whole-file match would have been
satisfied by the liar — strips comments and whitespace, and requires one of six
named NULL-guard idioms. `G2` pairs a bare-pointer count of 0 with a guarded count
of ≥1, so the absence half cannot go quietly green if the token is deleted. `G0`
re-measures the reachable-NULL claim every run instead of trusting it.

**Deliberately not written:** a row asserting the arm's complete token inventory.
That is a hand-kept list — the defect row `X1` of `test_snprintf_fmt_1608` exists
to name.

## ⚠ What this file got wrong, corrected

* **The repro's `;# ERROR: no such token` was wrong, and it is the substantive
  one.** There is no per-token message. Inside the arm's gate an unknown token
  gets the generic **`Wrong command`**, byte-identical to any typo
  (`xschem raw zzz_not_a_token_0514` → `Wrong command`); with no raw loaded at all
  the outer gate answers **`No raw file loaded`** first — both measured
  2026-09-29. **A row fencing this by asserting an error *string* would die
  silently on a re-wording**, so group A asks a deliberately bogus token in the
  same breath and asserts only that the two replies differ.
* **The "whole token list" is not whole**: it omits `case`
  (`xschem raw case [<mode>]`) and `set` (`xschem raw set node n value`), both
  present today. Probably drift since 2026-08-19, but the file presents the list
  as exhaustive.
* **Every line number in it is stale** at `57a7dadc`, which is this repo's
  cite-by-symbol rule earning itself again: the arm opens at **10935** not
  `10332ff`; `rawfile`/`sim_type` are at **11438-11441** not `10751-10754`;
  `sch_waves_loaded()`'s `raw->schname` test is at **2907** not `draw.c:2825`;
  `get raw_level` is at **5400** not `5007`; `get schname` at **5473** not `5080`.
* Found next door and **left alone**: `src/save.c`'s own comment cites
  *"stamped by `raw_read()` (src/save.c:1383-1384)"*; the stamp is at 1482-1484.
* Everything else reproduced exactly, including the repro's
  `0 / -1 / an.raw / 0 / cellB.sch` sequence.

## Still open — and it is the whole point of the accessor

**`results::_r804_msg`'s `against` argument still comes only from
`opts read_against`, and `read_against` HAS NO PRODUCTION CALLER.** Measured
2026-09-29: the only occurrence anywhere outside `src/results.tcl` is
`tests/headless/test_results_select.tcl:1744`. So ruling R804's precise sentence —

> Selected srlatch_ase.raw (dc), but this result was read against **srlatch.sch**
> and you are in tb_diff_amp.sch — no signal names will resolve until you return.

— **has never fired for a real user.** Every real selection got R804c's fallback,
which says a result was *not* read against where you are and cannot say where to
go. That is why this file's "entirely a message-quality" severity was too kind:
the message in question did not exist in practice.

With `xschem raw schname` in place the engine can supply the clause, and
`read_against` becomes the caller *override* R804c describes rather than the only
source. **Not done here**, because it changes which arm of a ratified sentence
fires in production and rows `SEL251`/`SEL252` pin both arms — and, separately,
because `test_results_select.tcl` is in **neither** T1 list and prints no
`OVERALL: ok`, so its fence is not gated either. Both halves are written up in
`doc/claude/code_analysis/t1_runs_84_of_418_headless_suites.md`.

## A note on how the suite was verified, because it nearly went wrong

The epilogue was copied from `test_zero_point_raw_0836.tcl` (already an `hcases`
citizen) and checked by **sourcing `tests/banner_rule.tcl` and evaluating
`banner_complete` on the suite's real log** — `banner_complete=1`, matching line
`<OVERALL: ok>`. This is not ceremony: one commit earlier (issue **1615**)
registering a suite that printed only `RESULT: ALL PASS` gated **red** with all 88
of its own checks passing, because `run_suites.sh` and `full_audit.sh` accept that
shape and T1's only Tcl reader does not. **"It passes under `run_suites.sh`" is not
evidence that a suite can be registered.**
