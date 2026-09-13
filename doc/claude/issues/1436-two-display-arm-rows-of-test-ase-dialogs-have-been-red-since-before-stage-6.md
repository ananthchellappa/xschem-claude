# 1436 — two display-arm rows of `test_ase_dialogs` have been red since before Stage 6

**Filed, not fixed.** Found by the Stage 6 task-6 crew (issue 1435) while running
the display arm of `test_ase_dialogs`, and filed rather than carried forward
because *a standing red is a defect, not furniture* — the rule this branch wrote
after two defects shipped past twenty-eight passing checks.

## What is red, and the proof it is not 1435's

Measured 2026-09-12 on the persistent dev display `:99` (Xvfb 1920x1080x24,
openbox 3.6.1 live), through `tests/headless/run_suites.sh test_ase_dialogs`:

```
FAIL: G2sens selecting sens builds its two fields, leaves none of tran's behind,
      and leaves Enable live -> {1 1 0 1 0 Entry Entry normal}
                             (exp {1 1 0 0 0 Entry Entry normal})
FAIL: GG9  the Detect button is live while cells rest on an assumption, and the
      grid says which cells those are -> {1 disabled 0} (exp {1 normal 1})
RESULT: 2 FAILED (283 passed)
```

⚠ **The proof is a restore, not an argument.** `src/ase.tcl` and
`src/ase_window.tcl` were copied back to HEAD `81312742` by `cp` from
`git show HEAD:…`, the suite re-run, and the files restored with an md5 compare:
**the same two rows, the same actual values, 283 passed either way.**

**T1 runs this file's HEADLESS arm only** (37 checks, ALL PASS), so neither red is
a T1 failure. The display arm is reached by `full_audit.sh` and
`tests/headless/run_suites.sh`.

## G2sens — the visible face of "`depends` has no surface"

The row expects `$top.chana.form.stop` **not** to exist when `sens` is selected.
It was written for issue **1428**, which shipped `sens` with exactly two fields
(`out`, `filters`). Issue **1432** then gave `sens` its AC mode, and with it five
more fields — `mode sweep points start stop` — **every one of them carrying
`depends {mode ac}`**. Measured:

```
ase::analysis_field_names ngspice sens  ->  out filters mode sweep points start stop
```

`ase::ui::chana_show` splits a type's fields into basic and advanced by the
`advanced` key and **builds every basic one whatever its `depends` says**. So the
widget is there, the row says it is not, and the product is arguably the wrong
half: a `Stop frequency (Hz)` box on a DC sensitivity form is a control for a
value that cannot reach the deck.

⚠ **This is receipt 17's own deferred note arriving as a red.** Issue 1432's
receipt recorded *"`depends` has no surface"* as a one-row follow-up for the next
window stage. Deciding whether `chana_show` should honour `depends` — hide the
widget, grey it, or leave it and fix the row — is that stage's decision and a
⚖ R9 wording question if anything is greyed, which is why this is filed rather
than patched to green.

## GG9 — a live capability probe reaches a suite that thinks it is isolated

The row expects `ase::analysis_detectable ngspice [ase::sim_caps_cached ngspice]`
to be **1** (nothing measured, so Detect could still change an answer). By that
point in the display arm the capability cache is **warm**, so every cell answers
`measured`, `detectable` is 0, and the Detect button is correctly disabled.

Measured, and the environment is part of the finding:

* in a **fresh process** on `:99` the cache is cold, `detectable` is **1**, and
  `ase::sim_status ngspice` resolves through the developer's real
  `~/.xschem/ase_simulators` — `source registry entry ngspice-v50`;
* run under a **scratch `HOME`**, a **third** row reds as well —
  `GG3 … -> {{⚠ op} {⊘ pss} {}} (exp {op {⊘ pss} {}})` — i.e. `op` acquires a
  caveat glyph, which only a *measured* capability can produce.

So something between the suite's start and GG9 measures capabilities, and the
result differs with `HOME`. ⚠ **That is `test_ase_core`'s ISO1434 lesson seen
from the other side**: a suite's isolation covers the **registry**, and with no
entry in force `ase::sim_status` falls back to `[auto_execok ngspice]` — so a
live probe of whatever ngspice is on `$PATH` still runs. `test_ase_dialogs` has
no equivalent of ISO1434 and no `test_sim_registry_isolate` call.

Related: issue **1397** (suites are not hermetic about `HOME`), already on the
user's queue.

## What a fix has to decide

1. Whether `ase::ui::chana_show` honours a field's `depends` (product) or
   `G2sens` is rewritten to today's seven-field `sens` (test). **The first is a
   user-visible change and therefore a ruling.**
2. Whether `test_ase_dialogs` gets ISO1434's stub — declaring the capability
   unmeasured for the whole file — or whether GG9's premise is rewritten to hold
   under a warm cache. The first makes the suite say what it measures; the second
   makes it measure the machine.
