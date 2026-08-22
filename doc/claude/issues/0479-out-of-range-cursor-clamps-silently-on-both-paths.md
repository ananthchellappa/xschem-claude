# 0479 — a cursor placed outside the data holds the endpoint and says nothing

Status: **BOTH QUESTIONS RULED BY THE USER 2026-08-22, implementation owed.**
(a) the endpoint hold STAYS, and gains a **status-line note** on both paths;
(b) the rider is a defect — `xschem set cursor2_x <non-number>` must **fail with
rc=1 and leave the cursor unmoved**. See "RULING" at the bottom.
Filed by the S11 crew (2026-08-20).
Related: RULING **D4-4** in `doc/claude/specs/mixed_signal_signal_browser.md`
(`callback.c` `interpolate_yval`'s `frac` clamp), invariants **I1** and **I3**,
issues 0477/0478/0480, spec §4.7 / step S11.

## The behaviour, measured on BOTH paths

**BEFORE S11, graph path** (Measure agent, verbatim; raw sweep ends at 4 ns):

    S11BEFORE D1 GRAPH t=99e-9 past end   : raw annot={4 9.9e-08 0}  v(d)=4  gm=0.00039999999
    S11BEFORE D2 GRAPH t=-5e-9 before 0   : raw annot={0 -5e-09 0}  v(d)=0  gm=0
    S11BEFORE D3 GRAPH t=2.5e-9 between   : raw annot={2 2.5e-09 0}  v(d)=2.5  gm=0.00025

**AFTER S11, graph path** (write-up agent, same script, binary `2f41eadd…`) —
byte-identical, which is the regression clause of the step:

    S11AFTER  D1 GRAPH t=99e-9 past end   : raw annot={4 9.9e-08 0}  v(d)=4  gm=0.00039999999
    S11AFTER  D2 GRAPH t=-5e-9 before 0   : raw annot={0 -5e-09 0}  v(d)=0  gm=0
    S11AFTER  D3 GRAPH t=2.5e-9 between   : raw annot={2 2.5e-09 0}  v(d)=2.5  gm=0.00025

**AFTER S11, the NEW graphless path**, same raw, same process shape:

    S11AFTER  G1 DIRECT t=4e-9  (last) : annot={3 4e-09 0}   v(d)=4  gm=0.00039999999  text="gm  = 400u | gds ="
    S11AFTER  G2 DIRECT t=99e-9 past   : annot={4 9.9e-08 0} v(d)=4  gm=0.00039999999  text="gm  = 400u | gds ="
    S11AFTER  G3 DIRECT t=-5e-9 before : annot={0 -5e-09 0}  v(d)=0  gm=0
    S11AFTER  G4 DIRECT t=2.5e-9 mid   : annot={2 2.5e-09 0} v(d)=2.5  gm=0.00025

The endpoint is **held**, never extrapolated, never blanked, and the two paths
agree digit for digit (invariant I1 — one behaviour, not two).

**The honesty gap is the `text=` column of G1 and G2**: a cursor at the last
sample and a cursor 24× past the end of the sweep render the *identical block*,
`gm = 400u`, and nothing on screen distinguishes them.

## Why S11 shipped it this way

S11's brief asked for out-of-range to be "handled honestly rather than clamping
silently to a fabricated value (I3)". The crew resolved that **against the
brief's wording**, deliberately, decision **D3**:

* **Ladder rung L1, invariant I1.** The direct path reaches the same
  `interpolate_yval()` as the graph path, so it inherits RULING **D4-4**'s clamp.
  Blanking on the new arm only would give one cursor two behaviours — the exact
  silent drift I1 exists to prevent — and **no existing row compares the two
  paths**, so the divergence would have reddened nothing.
* **I3 read narrowly, and this is the load-bearing reading.** An endpoint hold
  is a *real measured sample of a present vector*, not a fabricated number for a
  *missing* one. Missing vectors still blank: `gds` is absent from the fixture
  raw and renders as `gds =` with nothing after it at 1 ns, 3 ns and 99 ns alike
  (row T7, and the `text=` columns above).
* **Rejected** — `annot_p = -1` or a blank on the direct path. Also rejected by
  D4-4 itself when it was ratified: a cursor at t deserves a real answer and the
  readout has no way to render "no answer" that is not itself a lie.

## What already exists, and what does not

`xschem raw annot` reports the **requested** `annot_x` (`9.9e-08`) beside the
**clamped** `annot_p` (`4`), so the condition *is* detectable — by a caller who
knows to look. There is no status-line note, no `xschem raw` seam that says
"the cursor is outside the data", and nothing on the schematic.

## ⚠ The clamp has thinner test coverage than it looks (S11 sabotage, SAB-7)

Deleting **both** clamp lines from `interpolate_yval()` left row **T16** ("past
the end holds the last sample") and rows **XCW4/XCW5** of
`test_wave_cursor_crossdb.tcl` **green**. Mechanism, measured: past the last
sample the function returns at the `(p + 1 < ofs_end)` guard *before* `frac` is
computed, so the upper hold is that guard, not the clamp; XCW4 is a VCD
sparse-stream early return, also clamp-independent. Only the **lower** bound has
behavioural coverage today. Anyone editing that arithmetic should not read a
green suite as protection.

## Rider, same family, measured at write-up time

    S11AFTER  G5 DIRECT t={abc} : rc=0 err="0" get cursor2_x=0 annot={0 0 0}  v(d)=0

`xschem set cursor2_x abc` (and the empty string) **succeeds**, means t = 0 via
`atof_spice()`, and now silently re-annotates the whole graphless sheet at t = 0
— overwriting the operating point the user just got from `annotate_op`, with no
error. Identical on the graph path, so it is not a divergence, but before S11 it
was unreachable from a sheet with nothing plotted.

## THE QUESTION FOR A HUMAN

> A cursor parked outside the loaded sweep now moves every annotated number on a
> **graphless** schematic to the last sample and says nothing. Is that silent
> endpoint hold the right answer, or should **both** paths (never one) gain a
> seam or a status-line note naming the condition?

Whatever the answer, it must be applied to both paths in the same change.
Diverging is the failure mode I1 was written for.


---

# RULING — the user, 2026-08-22

Re-measured first on a **real bench** rather than the 4-point S11 fixture:
`sky130_tests_ase/bandgap_opamp`, 13 FETs, the 15.8 MB bandgap tran raw (4045
points, sweep ending ~50 us), raw read at the top then descended (issue 0608's
order), `annot_show 3`, block read off `op_annot::text M4`.

```
t=20u   (inside)            annot={2012 2e-05}    id = 4.854u | gm = 7.678u | vds = 0.3367
t=49.9u (near end)          annot={4044 4.99e-05} id = 4.851u | gm = 7.671u | vds = 0.3364
t=500u  (10x PAST the end)  annot={4044 0.0005}   id = 4.851u | gm = 7.671u | vds = 0.3364
t=-5u   (before 0)          annot={0 -5e-06}      id = 0      | gm = 0      | vds = 3.209a
t=abc   (a typo)     rc=0   annot={0 0 0}         id = 0      | gm = 0      | vds = 3.209a
t={}    (empty)      rc=0   annot={0 0 0}         id = 0      | gm = 0      | vds = 3.209a
```

Rows 2 and 3 are identical across all six values on all 13 devices. The point
index stays pinned at 4044 while the requested time reads `0.0005`.

## (a) The hold STAYS; both paths gain a status-line note

**Not changed:** holding the endpoint. It is a real measured sample of a present
vector, both paths agree digit for digit (**I1**), and it matches what the
waveform viewer has always done under RULING **D4-4**. S11's decision D3 is
ratified on its merits.

**Added:** a status-line note naming the condition, **on both paths in one
change**. Diverging is the failure mode I1 was written for, and this file's own
closing line already required it.

**The seam already exists and nothing needs computing.** `xschem raw annot`
reports the *requested* `annot_x` beside the *clamped* `annot_p`; the condition is
`annot_x` outside the sweep, which the caller can already see.

**Why the status line and not the schematic.** The annotated block is what the
user is reading, so marking it there is the stronger signal — and it was the
option the user was offered. It was not taken *now* because that block already
collides with the symbol's own texts (issue **0605**, ruled 2026-08-22 as
"basic functionality first, tweak later"), so adding ink to it before 0605 is
settled would make a known problem worse. Revisit with 0605.

### The motivating case is not a typo

Recorded because it changes the priority: the natural way to land past the end is
**walking there**. Once issue **0478** is fixed and the keys step the cursor,
pressing step a few times too many is the ordinary interaction — the numbers
simply stop changing, with nothing to say the data ran out.

## (b) The rider is a DEFECT, not a behaviour — rc=1, cursor unmoved

```
xschem set cursor2_x abc   ->  rc=0   annot={0 0 0}
                               id = 0 | gm = 0 | vgs = -3.467e-15 | vds = 3.209a
```

A typo **succeeds**. `atof_spice()` reads it as 0, the cursor lands at t = 0, and
every number on the sheet becomes the power-up state — a circuit with nothing
turned on — while the return code says the command worked. The empty string is
identical. Before S11 this was unreachable from a sheet with nothing plotted; now
it silently overwrites the operating point the user was reading.

**Chosen: reject it. `rc=1`, and the cursor does not move.** A setter handed a
non-number must fail and change nothing.

**This changes a shipped command's contract** and that is why it was put to the
user rather than decided here: a script passing an empty string would begin
erroring where it used to silently mean t = 0. The user accepted that cost.

Applied to **both** paths, same change, same reason as (a).

Rejected: *accept but report it* (fourth rider on 0604) — weaker, because the
sheet still changes under the user; and *leave it, it matches the graph path* —
consistency with a defect is not a defence.

## TEST WORK OWED — assistant's, not the user's

* **The clamp's coverage is thinner than it looks (S11 sabotage SAB-7).** Deleting
  **both** clamp lines from `interpolate_yval()` left row **T16** and rows
  **XCW4/XCW5** of `test_wave_cursor_crossdb.tcl` green: past the last sample the
  function returns at the `(p + 1 < ofs_end)` guard *before* `frac` is computed,
  so the upper hold is that guard, not the clamp. Only the **lower** bound has
  behavioural coverage. Close that before touching the arithmetic.
* A row that compares the two paths directly. This file notes that **no existing
  row does**, which is why a divergence would have reddened nothing.
* Rows for the rider: non-numeric, empty string, and a valid value after a
  rejected one (the cursor must be where it was, not where the bad call aimed).

`owed.sh clear rule 0479` — both halves answered, 2026-08-22.
