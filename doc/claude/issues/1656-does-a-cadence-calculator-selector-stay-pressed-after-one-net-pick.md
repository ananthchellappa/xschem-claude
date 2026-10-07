# 1656 — Does a Cadence calculator selector stay pressed after one net pick?

**STAMP:** `v1 claim=open tree=ac45d96e stamped=2026-10-07 fix=none open=1`

## The question for the user

In Cadence's calculator, after you click `vt` and then click a net on the
schematic so the expression lands in the buffer — **does `vt` stay pressed, so
your next click on the schematic picks another net? Or does it pop out after
that one pick?**

This is a factual question about ADE/ViVA behaviour, which the user is the
fastest authoritative source for. Nothing is blocked on it: a default has
shipped and either answer costs one line.

## What shipped, and why

**It stays on** (spec R208, `calc::pick_arm` / `calc::sel_click`). The mode
remains armed after a successful insertion and ends on any of:

| exit | mechanism |
|---|---|
| `Escape` | R306, the seized `<Key-Escape>` |
| re-click the armed selector | R201, keyed on `calc::pick_id` |
| click another selector | `calc::pick_end switch` then the new arm |
| the design window closes | `calc::pick_pump`'s `winfo exists` poll |
| navigating the design out of that window's stack | `calc::pick_base` < 0 at click time |
| closing the Calculator | R307, both doors |

**The reasoning for the default:** a mode that stays on can always be left with
one keystroke, while a one-shot mode cannot be extended at all — so the sticky
choice is the recoverable one if it turns out to be wrong. The tree's other
click-to-pick mode (the Results Display Window's device pick) already works
this way, on the user's own earlier ruling that *"this is a command mode, so
clicking will not change selected set"*.

## What changes if Cadence pops it out

One line in `calc::pick_click`'s success arm: `calc::pick_end disarm` after the
insertion instead of returning. The rows that would move, named so the change
is not a search:

- `PG3 the mode is STILL LIVE after a successful pick` and the leg after it
  (`a second click on a different net inserts that net's name`) in
  `tests/headless/test_calc_pick.tcl` — both assert the sticky behaviour
  directly and would invert.
- R208's own paragraph in `doc/claude/specs/calculator.md`.

Nothing else: every refusal path already leaves the mode live for its own
reason (a mode that ended on a mis-click would be unusable), and that is a
separate decision from what a *success* does.

## Not part of this question

The four voltage selectors are v1's whole scope. `it`/`if`/`idc`/`is` pick an
instance **terminal** (R203, a different hit test) and need a new read-only
`scheduler.c` verb, because `find_closest_pin` — the tree's only zoom-scaled pin
hit test — has no Tcl door. That is a separate unit, already named in the
refusal the other ten selectors give.
