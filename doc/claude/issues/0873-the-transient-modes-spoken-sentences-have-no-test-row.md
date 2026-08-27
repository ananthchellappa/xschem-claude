# 0873 — the transient mode's spoken output has no test row: silencing the CIW emitter leaves 651 checks green

**Status:** 🔴 **OPEN — measured, NOT fixed.** Filed by the A3 write-up, 2026-08-27,
from the sabotage leg of the 0868 run. Class: **a guard no row can see** — the house
rule's own words, *"a guard no behavioural row can see needs a STRUCTURAL row"*.

Owner: guard **G9** of issue **0868** — `cadence::_annot_ciw` and the four refusal
arms of `cadence::annot_tran` in `utils/annot_mode.tcl`.

## What is unguarded

**Part 5 of the A3 brief — the entire user-visible output of the feature.** The
sentences exist and are pinned byte-for-byte (row V17); nothing pins that they are
ever SPOKEN.

## Measured by the sabotage leg, 2026-08-27

Two variants, each restored with `cp backup && touch`:

* **S8** — every refusal arm of `cadence::annot_tran` returns without minting or
  emitting: `test_op_annot` **401**, `test_ase_window` **221**,
  `test_annot_show_menu` **29**. **All 651 checks green.**
* **S8b** — `cadence::_annot_ciw` reduced to `return 0`: **all 651 checks green.**

The channel is not broken. A live spy proves the real path works:

```
cadence::annot_tran with no cursor on delivers to ::ase::echo
  {warn {Transient annotation -- NO CURSOR: turn on cursor A or B in the waveform viewer}}
  and leaves `xschem get statusmsg_hold` = 1
```

So the feature speaks, and the suite would not notice if it stopped.

## Why the plan's own prediction missed it

0868's sabotage table predicted S8 would redden V14/V15/V16. It cannot: those rows
assert the **returned state name**, which silencing does not change. The plan's S8b
entry then said, in its own words, *"MUST REDDEN a row that reads the CIW sink; if
none does, add one (the `test_annot_show_menu` C5 sink-read technique) rather than
shipping an unseen channel."* **That contingency fired and was not honoured.**

Section V also carries no `statusmsg_hold` assertion for the transient mode, so the
held status line is untested too.

## Fix shape — small, and the machinery already exists

`tests/headless/test_ase_window.tcl:727-733` already carries an `ase::echo` spy, and
`cadence::_annot_ciw` prefers `::ase::echo` when it is defined, so a headless row in
`test_op_annot` section V can define the spy and read what arrives. Rows wanted:

* the `ok` sentence reaches the sink AND `xschem get statusmsg_hold` is 1;
* each reachable refusal (`nocursor`, `noraw`, `notran` — see issue **0871** for why
  `nodata` is not one) reaches the sink with the `warn` tag;
* the emitter falls through to the next sink when `::ase::echo` raises — the
  behaviour the proc's own comment claims and the one 0857 is about.

Acceptance: S8 and S8b must each redden at least one of them.
