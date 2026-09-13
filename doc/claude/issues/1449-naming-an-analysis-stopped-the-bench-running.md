# 1449 — naming an analysis stopped the bench running

**Status:** fixed (the emit reader; `src/ase_window.tcl`'s Options subdialog is still owed — see below)
**Branch:** `fluid-editing`
**Area:** ASE-L — `ase::analysis_emit_check` and the gate that consumes it (`src/ase.tcl`)
**Suites:** `tests/headless/test_ase_core.tcl` rows **EK7** and **EK7c** (both arms)
**Batch:** `doc/claude/ase_analyses_batch/`, the tail of ⚖ **R6**
**Found by** issue **1448**'s task, in the half that shipped before it (issue **1447**).

---

## The defect

**A user who gave an analysis a name and switched it on could not run their bench.**
No deck, no raw, no log — and the sentence they were shown says that the escape
they might reach for does not apply.

⚖ **R6** (issue 1447) gave an `analyses` row an optional `id`: the stable handle
that makes two `dc` rows separately addressable, the thing issue 1444 exists to let
the user *see*. It was added to the row and **not** to the one reader that decides
which row keys are legal:

```tcl
set known [list type enabled x]          ;# src/ase.tcl:4615, before
```

`x` is there. `id` is not. So `ase::analysis_emit_check` answered `unknownkey id`,
and `ase::preflight_gate` — which runs that check over every **enabled** stored row
before a run — turned it into `emit_incomplete`. Measured against the unfixed tree,
on a bench whose only analysis is `{type dc enabled 1 id vinsweep source V2 start 0
stop 1.8 step 0.01}`:

```
emit_check : {unknownkey id {has a setting named 'id' that ASE-L cannot emit}}
gate       : emit_incomplete
gate, the identical bench with the `id` removed : {}      (it runs)
```

and what the user is told, verbatim:

```
ase: the dc analysis has a setting named 'id' that ASE-L cannot emit
ase: it is enabled on this bench, so the run would have started and produced
nothing for it. Nothing was generated: no deck, no raw, no log.
`set ase_preflight 0` does NOT disable this check.
```

⚠ **The refusal was not merely early, it was empty.** The id-ful and id-less benches
render the **same deck, byte for byte** — both carry `dc V2 0 1.8 0.01`. `id` is a
name, not a setting, and no template was ever going to spend it. The gate was
withholding a deck it had no complaint about.

**And the surface that invites the mistake is the one that shipped with it.** Issue
1448's handle grid and `Analyses > List` exist to tell the user what their analyses
are called; 1444's fourth surface is an **editable** `id` field. Typing a name there
and ticking the row is the gesture this refused.

## The fix

One word.

```tcl
set known [list type enabled x id]       ;# src/ase.tcl:4640, after
```

⚠ **`id` is exempt for the OPPOSITE reason to `x`, and that distinction is the whole
guard.** `x` (issue 1419) is exempt because it **emits** — a verbatim list of
`.control` lines. `id` is exempt because it is **not a setting at all**: it is the
row's name, spent by `ase::analysis_handle`, by the Choose Analyses handle grid, by
`Analyses > List` and by a measurement's `id` binding. `unknownkey` refuses a key
that would **silently not emit** (issue 1418: the Options editor collected free-text
pairs, round-tripped them and never emitted them; issue 1401 is the same silence one
level up). A handle the user can see in three places and type into an expression is
not silent, and nothing about it was ever bound for the deck.

⚠ **DO NOT GENERALISE THIS INTO "IGNORE UNKNOWN KEYS."** `DECISIONS.md` **D4** says
there are **exactly two** optional per-row keys, `id` and `x`, and this list is where
that sentence is enforced. A third key means a third clause, with its own reason
written down. Sabotage **s2** below is the over-wide fix, and it reds `EK7c` **and
`GR9`**, the 1418 row in a section this change did not write.

## Why it survived 622 green checks and a clean T1

**No row anywhere enabled a row carrying an `id`.** Section HN of
`test_ase_core.tcl` declares ids and never switches a row on; section EK switches
rows on and never declares an id. Each half was watched by a suite and the seam
between them by nothing — and for the first time in this batch **the two halves lived
in different files**. `EK6`, the corpus invariant that exists to catch exactly "this
commit makes a shipped bench unrunnable", could not see it either: **no committed
bench carries an `id`** (104 files, 416 analysis rows, zero), so every bench it walks
is an id-less one.

So the row that lands with the fix is **not** "does `emit_check` accept `id`". It is
an **enabled row carrying an `id` walked all the way to a rendered deck, in one
expression**, so the two fixtures have to agree with each other.

| row | what it asserts |
|---|---|
| **EK7** | the emit check is clean, the gate is clean, the deck carries `dc V2 0 1.8 0.01`, that deck equals the id-less bench's **byte for byte**, the deck is longer than 100 characters (so the equality is not two empty strings), and the two fixtures **disagree** about their own handle — `vinsweep` against `dc1` |
| **EK7c** | a genuinely unknown key (`nonsense`) on the **same** row is still refused, still stops the gate, and is still the **only** thing refused — the count is 1, which is what says the `id` beside it was not counted |

## Measurements

* `test_ase_core` **622 → 624**, `ALL PASS` on **both** arms (headless, and `:99`
  Xvfb + openbox).
* **104 of 104** tracked `.state` files load and re-serialize **byte-identically**,
  416 analysis rows, **zero** carrying `id`; the in-process control (one `id` added
  to one committed row) disagrees, so the comparison is not vacuous. No tracked
  `.state` file was modified. **No new state key and no schema version bump** — `id`
  already existed; one reader was taught about it.
* `test_ase_preflight` 235, `test_ase_persist` 49 / 153, `test_ase_meas_1443` 100,
  `test_ase_options_1437` 75, `test_ase_window` 56 / 295 — `ALL PASS`, both arms.
* **`test_ase_dialogs` row `GH13b` goes RED, and that is the point** — it was written
  to pin this defect and its own header says *"Fixing it turns that row RED"*. It is
  the only row that moved: display arm **1 FAILED (339 passed) → 2 FAILED (338
  passed)**, the other red being the standing `G2sens` (issue **1436**). The row and
  its paragraph now describe a fixed defect and must be rewritten; that file was not
  this change's to touch.

### Sabotage

| # | what was broken | result |
|---|---|---|
| **s1** | the one word reverted — the defect, back | `2 FAILED (622)`: **EK7** (`unknownkey id` / `emit_incomplete`) and **EK7c** (offence count **2**, not 1) |
| **s2** | the allow-list accepts **everything** — the over-wide fix | `2 FAILED (622)`: **EK7c** and **GR9**, the 1418 row in a section this change did not write |
| **s3** | CONTROL — EK7's fixture loses its `id`, so it stops disagreeing with its own control | `1 FAILED (623)`: **EK7**, on the handle term (`dc1 dc1`) |
| **s4** | POSITIVE CONTROL — the deck-line extractor never matches | `1 FAILED (623)`: **EK7**, third term empty |
| **s4b** | POSITIVE CONTROL — both decks replaced by the empty string, which `string equal` accepts | `1 FAILED (623)`: **EK7**, on the **length floor** (`1 0`) |
| **s5** | CONTROL — EK7c's nonsense key is not nonsense after all | `1 FAILED (623)`: **EK7c** |

⚠ **One mutation is recorded as a finding rather than a witness.** Making
`ase::analysis_line` return `{}` — no analysis card reaches any deck at all — does
**not** redden EK7: it **kills the suite at check 41**, line 5649, with
`ase: analysis type 'op' is not one this simulator backend can render`, no `RESULT:`
line, and **rc 0** (`--nogui --pipe` exits 0 on an uncaught mid-script Tcl error, per
CLAUDE.md). G2tf's failure shape, met again by a fourth route. It is in the generator
as `s4x` so nobody re-derives it.

## What is still owed

⚠ **THE SAME BLINDNESS EXISTS A SECOND TIME, IN `src/ase_window.tcl`, AND IT AFFECTS
BOTH D4 KEYS.** The Options subdialog enumerates a row's legal keys independently:

```tcl
set skip [concat {type enabled} [ase::ui::chana_fields $type $_sim]]
```

at **`:5824`** (`chana_options`, seeding `anextra` from the stored row) and at
**`:5973`** (`chana_x_ok`, stripping the row before write-back). `chana_fields` is
the declared field names only — **neither `id` nor `x` is in it**. Measured for `dc`
on ngspice:

```
skip                                  : type enabled source start stop step source2 start2 stop2 step2
anextra seeded from a row with both   : id vinsweep x {{echo hi}}
chana_x_ok's OK loop would refuse     : id x
```

So opening `Options…` on a row that carries **either** optional key shows the key as
a free-text pair and then **refuses to save**, returning before it writes. The row is
not damaged, but the editor cannot be used on it at all. `x` has been in this state
since issue **1419** — this is not a 1447 regression, it is the third instance of one
class. It needs its own number and a fix in `src/ase_window.tcl`, which was not this
change's file.

Issue **1444**'s editable `id` field was blocked behind the defect above and is now
unblocked.
