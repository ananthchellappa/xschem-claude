# 0429 — sky130 saves `cgso` and `cgdo`, which ngspice-42 rejects, and ONE rejected `.save` card suppresses the ENTIRE raw file

Status: **CLOSED 2026-08-22 — SUPERSEDED BY RULING D9, not answered.** The
ratification question at the bottom of this file is moot: the user cut the MOS
annotation default to `id gm gds vgs vth vds`, so neither `cgso` nor `cgdo` is
in the shipped set at all, and neither is `cgg` or the `ft` that consumed them.
See the D9 block at the very bottom, and spec §4.2a.

Previously: **RULED AND FIXED IN S3b (2026-08-16), ruling D8 — the ratification
question is at the bottom of this file.** The two rows are gone from
`sky130A/sky130_procs.tcl` and `ft` is now `gm/(2*pi*cgg)`. Read the RULING
section before the historical sections below it: **one of this file's own
premises turned out to be wrong**, and the fix sketch it proposed is measurably
refuted.

⚠ **THIS FIX SURVIVED S3b's REVERT — DELIBERATELY.** Step S3b as a whole was
refuted (issue 0442) and its walk, menu item and test section were reverted. The
descriptor change here was kept, because it is in a different file, depends on
nothing that was reverted, and the brief for the step forbade deferring this
ruling a second time. With `save_cards` gone the changed `params`/`derived` are
inert data consumed only by the test goldens until S5 lands the display path, so
keeping it carries no behavioural risk. Guarded by two goldens in
`tests/headless/test_op_annot.tcl`, **P2 and P9** — verified by re-arming:
reinstating the two rows reds exactly those two and nothing else.

⚠ **CORRECTION to the count claimed when the fix landed.** The S3b implement
report said the ruling was "guarded by THREE goldens: P2, P9 and P25's
not-a-param scan". Measured: P25 stays **green** when `cgso`/`cgdo` are
reinstated. There are **two** guardians, not three.

Previously: open — measured, not fixed; the finding that downgraded S2 to
status E. Found by the S2 Verify-C adversary of the op-annotation run
(2026-08-16) on branch `annotate`, then re-measured independently by the S2
write-up agent before the step was committed, and a third time by the S3b crew.

Inherited, not introduced: `sky130A/sky130_procs.tcl:86-87`
(`sky130_write_save_lines`) has emitted these two cards since long before the
op-annotation work. S2's descriptor carries them **because the step's stated
acceptance was byte-for-byte equality with that prototype**. So the defect is in
the tree today with or without S2 — but S2 is the step that measured it, and S3
is the step where it starts costing users their waveforms.

## What was measured

Real sky130 models (`sky130A/models/libs.tech/combined/sky130.lib.spice`, corner
`tt`), real device path, ngspice-42, one parameter per deck, each deck otherwise
identical and using the `.control … write <cell>.raw … .endc` idiom that every
shipped sky130 / gf180 / IHP testbench uses:

```
param=gm    rc=0 RAW-WRITTEN checkvalid_warnings=0
param=gds   rc=0 RAW-WRITTEN checkvalid_warnings=0
param=vth   rc=0 RAW-WRITTEN checkvalid_warnings=0
param=vdsat rc=0 RAW-WRITTEN checkvalid_warnings=0
param=cgg   rc=0 RAW-WRITTEN checkvalid_warnings=0
param=id    rc=0 RAW-WRITTEN checkvalid_warnings=0
param=cgso  rc=0 NO-RAW      checkvalid_warnings=1      <-- INVALID
param=cgdo  rc=0 NO-RAW      checkvalid_warnings=1      <-- INVALID
param=cgs   rc=0 RAW-WRITTEN checkvalid_warnings=0      <-- the valid spelling
param=cgd   rc=0 RAW-WRITTEN checkvalid_warnings=0      <-- the valid spelling
```

The warning, in full:

```
Warning from checkvalid: vector @m.xm1.msky130_fd_pr__nfet_01v8[cgso] is not
available or has zero length.
```

Two things make this worse than a missing number:

* **`rc=0`.** ngspice exits successfully. A caller checking the exit status sees
  a clean run.
* **NO RAW FILE AT ALL.** Not a missing column — the `write <file>.raw` inside
  `.control` never produces a file. One bad card out of eight destroys every
  waveform and every node voltage in the run. `grep -h -o 'write [^ }]*raw'`
  across the shipped benches confirms that idiom is what all three PDKs use
  (`write LACG.raw`, `write test_cap_mim_1f0fF.raw`, `write ac_hbt_13g2.raw`, …).

In the alternative `ngspice -b -r out.raw` mode the raw survives, but the bogus
vector is emitted as a fabricated `capacitance` column — spec §6 landmine 9
again, i.e. a plausible `0.0` on the schematic. Both outcomes are worse than
invariant I3's blank.

gf180's BSIM4 behaves the same way: `cgs`/`cgd` are the valid spellings there
too.

## Where it is, right now

* `sky130A/sky130_procs.tcl:86-87` — the prototype `.save` lines (pre-existing).
* `sky130A/sky130_procs.tcl`, the S2 `op_annot::register` block — `{cgso cgso 1}`
  and `{cgdo cgdo 1}` in `params`, for **both** `nmos` and `pmos`.
* The same block's `derived` row `ft`, which divides by
  `($cgg + $cgdo + $cgso)` — so S5's formatter inherits the breakage as a
  division involving two permanently blank operands.

IHP's `cgsol` / `cgdol` and the thirteen NPN parameters **cannot be checked on
this box at all**: `pre_osdi ihp-sg13g2/osdi/psp103.osdi` fails on ngspice-42
(the vendored OSDI targets v0.4, ngspice-42 supports v0.3). The sky130
measurement above shows unvalidated parameter names are not a theoretical risk,
so IHP's list is carrying the same exposure with no way to test it here.

## Why it was not fixed in S2

Fixing it means dropping the two rows, or replacing them with `cgs`/`cgd`.
Either edit **breaks the acceptance criterion the step was given** — test row
`P3` asserts the generic builder reproduces `sky130_save_fet_params` byte for
byte across 119 cards, and the brief says in terms that "that diff being empty is
the proof the generalization lost nothing". You cannot simultaneously reproduce
the prototype exactly and correct the prototype.

That is a decision above S2's pay grade under ladder rung **L3**, and it is the
question in the S2 ledger row:

> sky130's OP save list carries `cgso`/`cgdo`, which ngspice-42 rejects — and one
> rejected `.save` card makes it write no raw file at all. Correcting them to
> `cgs`/`cgd` breaks the byte-for-byte-equals-the-prototype acceptance this step
> was given. Correct the parameters (and re-baseline the prototype and the test),
> or keep bug-compatibility and fix it when S5 deletes the prototypes?

## Fix sketch as originally filed — ⚠ REFUTED, DO NOT IMPLEMENT

1. ~~Replace `{cgso cgso 1}` / `{cgdo cgdo 1}` with `{cgso cgs 1}` /
   `{cgdo cgd 1}` — keeping the *label* stable so the on-screen text does not
   change, and moving only the raw *parameter*.~~ **Measurably wrong**, see the
   RULING below: `cgs` and `cgd` are different physical quantities from the
   overlap capacitances, `cgs` is NEGATIVE, and substituting them makes `ft`
   about 6x wrong on every sky130 FET on every ngspice.
2. ~~Fix `sky130_write_save_lines:86-87` the same way.~~ Superseded: the
   prototype is deleted by S5, and `P3` already handles the disagreement by
   overriding `params` with the prototype's own seven for the byte-diff row only.
3. Add a test row that is not a self-comparison: assert against **ngspice**, not
   against the prototype, that every registered sky130 parameter yields a vector
   in a real raw. S2's acceptance was a string diff between two pieces of our own
   code, and that is exactly the shape of check that cannot catch this class of
   defect. Spec §8's "the names are real in a raw" leg is the one that would
   have. **Still owed** — S4 (the ngspice round trip) is its natural owner and
   must build it on sky130 or gf180, since IHP cannot be simulated on this box.

# ============================================================================
# THE RULING — S3b decision D8 (2026-08-16), ladder rung L3, step status E
# ============================================================================

## What ships

`sky130A/sky130_procs.tcl` loses `{cgso cgso 1}` and `{cgdo cgdo 1}` from
`params` for both `nmos` and `pmos`, and its `derived` row becomes

```tcl
derived {{ft {$gm/(2*3.141592654*$cgg)}} {gm/id {$gm/$id}}}
```

Guarded by two test goldens, deliberately: `P_SKY_PARAMS` (row P2, the list
itself) and `P_SKY_PNAMES` (row P9, its order and membership), plus row P25's
`not-a-param:` scan which reds on its own if a later edit leaves `ft`
referencing a `$cgso` the params list no longer carries. "Align with the
prototype" is exactly how these two rows would come back, and all three rows
exist to stop that.

## The version-dependence, re-measured on BOTH binaries installed here

`which -a ngspice` -> `/usr/local/bin` (46+), `/usr/bin` (42). **46+ shadows 42
on PATH, so an unpinned `ngspice` measures the forgiving one.** One parameter
per throwaway deck, real sky130 tt models, under the
`.control … write … .endc` idiom every shipped PDK bench uses:

```
/usr/bin/ngspice (42)         gm cgg cgs cgd -> raw written, 0 warnings
                              cgso cgdo      -> exit 0, ONE `checkvalid` line,
                                                and NO RAW FILE AT ALL
/usr/local/bin/ngspice (46+)  gm cgg cgs cgd cgso cgdo -> raw written, 0 warnings
                              bogusparam     -> exit 0, no raw
```

S3b ships the first PDK-NEUTRAL `Create device OP .save file` menu item — the
first time this descriptor is handed to every PDK's users as a generated deck —
and a feature that destroys the data it exists to display is not shippable.

## ⚠ AND IT IS ALSO A CORRECTNESS FIX: cgg ALREADY CONTAINS THE OVERLAP

The step brief asked for one more deck before the question was written down:
does `cgg` already include the overlap terms? Measured on ngspice-46+, same
device (`sky130_fd_pr__nfet_01v8 L=0.15 W=1 nf=1`), Vds=1.8, two gate biases:

```
                 Vgs = 0            Vgs = 0.9
cgg           3.845297e-16        7.611204e-16
cgso          2.463135e-16        2.463135e-16
cgdo          2.463135e-16        2.463135e-16
cgs          -5.09461e-18        -5.52001e-16
cgd           6.340177e-20        6.042782e-19
cgb          -3.79499e-16        -2.09724e-16
```

Two readings, and they agree:

* **The identity holds to 7 digits at both bias points**:
  `cgg == -(cgs + cgd + cgb)`. At Vgs=0.9, `-(-5.52001e-16 + 6.042782e-19 +
  -2.09724e-16) = 7.611207e-16` against a printed `cgg` of `7.611204e-16`; at
  Vgs=0, `3.845302e-16` against `3.845297e-16`. So `cgg` is the TOTAL gate
  capacitance, the sum of the three partial derivatives — and BSIM's `cgs`/`cgd`
  are total (intrinsic **plus** overlap) partials.
* **With the channel off (Vgs=0) `cgg` is still 3.8e-16**, the same order as
  `cgso + cgdo = 4.93e-16`. An intrinsic-only `cgg` would be near zero there.

So the shipped `ft = gm/(2*pi*(cgg + cgdo + cgso))` **double-counts the
overlap**: it adds 4.93e-16 on top of a `cgg` that already contains it, making
the denominator 1.254e-15 where the physically correct one is 7.61e-16 — the
shipped fT was roughly **40% too low on every sky130 FET, on every ngspice
version**. Dropping the two rows is therefore not a loss forced by a
compatibility problem; `gm/(2*pi*cgg)` is both the textbook definition and the
arithmetically consistent one. This shrinks the ratification question to the two
lost DISPLAY rows.

## Rejected alternatives, with why

* **(a) Keep `cgso`/`cgdo`.** Correct on 46+ only. On 42 it suppresses the whole
  raw with exit status 0, and a generated `.save` file cannot know which ngspice
  will read it — it may be `.include`d on another machine entirely.
* **(b) This issue's own sketch: relabel to `cgs`/`cgd`.** Refuted by
  arithmetic. `cgs` measures NEGATIVE (-5.52e-16) and `cgd` is three orders down
  (6.04e-19); the ft denominator would go from `cgg+cgdo+cgso` = 1.254e-15 to
  `cgg+cgd+cgs` = 2.097e-16, a factor of 5.98 — a silently ~6x wrong fT on every
  sky130 FET on every ngspice. That is precisely invariant I3's
  plausible-wrong-number, arriving from a "fix". They are also different
  physical quantities: `cgs`/`cgd` are bias-dependent totals, `cgso`/`cgdo` are
  the fixed overlaps.
* **(c) Keep them behind a per-parameter descriptor guard plus a
  simulator-version probe.** New descriptor grammar on a key three PDKs already
  use, policy back inside the emitter (contrary to the "the descriptor is the
  only policy about what is savable" rule the emitter documents), and the probe
  cannot know which ngspice will run the generated deck. Filed forward as
  **issue 0440** rather than discarded.

## Recovery for a 46+ user who wants the two rows back

One `op_annot::register` round-trip in their own `--script` rc (invariant I5) —
no rebuild, no restart, effective on the next redraw:

```tcl
set d [op_annot::descriptor nmos]
dict set d params [concat [dict get $d params] {{cgso cgso 1} {cgdo cgdo 1}}]
op_annot::register nmos $d
```

That reversibility is half the reason the ruling could be made at all: the
option that loses data on ngspice-42 is unrecoverable for that user, and the
option that loses two display rows on 46+ is three lines in an rc.

## THE STATUS-E QUESTION for the ledger row

> sky130 FET annotation now drops the `cgso`/`cgdo` rows and defines fT as
> `gm/(2*pi*cgg)`, so a generated `.save` block can no longer suppress the whole
> raw on ngspice-42. Measurement since the question was drafted shows `cgg`
> already contains the overlap (`cgg == -(cgs+cgd+cgb)` to 7 digits at two bias
> points), so the old fT double-counted it and was ~40% low — the new one is a
> correctness fix, not a compromise. What is left to ratify is the loss of the
> two `cgso`/`cgdo` DISPLAY rows for ngspice-46+ users: accept the loss (they
> are recoverable with a three-line `op_annot::register` in a user rc), or
> reinstate them behind a per-descriptor simulator guard (issue 0440)?


# ============================================================================
# RULING D9 (the user, 2026-08-22) — THIS ISSUE IS SUPERSEDED
# ============================================================================

The user, reading the ratification question, did not pick either option. The
instruction was:

> Change (spec) display default to only display id, gm, gds, vgs, vth, vds. We
> will provide a means (TBD) for user to update to what she wants. Too many
> parameters displayed is just clutter.
> We don't mess with cgs/cgdo. We can report a mismatch between expectation and
> actual delivery from ngspice as a warning in CIW and logfile.

So:

* **`cgso`/`cgdo` are not in the default set**, and neither is `cgg`. There is no
  "keep them or lose two rows" trade left to ratify.
* **`cgs`/`cgd` are not substituted for anything** — this issue's own fix sketch,
  already refuted by arithmetic above, stays refuted and unused.
* **`ft` leaves with `cgg`.** Worth restating because it was the whole subject of
  the D8 argument: no simulator computes fT. `show m.xm1.msky130_fd_pr__nfet_01v8
  : all` on ngspice-46+ lists 50 BSIM4 instance parameters and neither `ft` nor
  `gm/id` is among them. Both were Tcl arithmetic in the PDK procs files — twice,
  with two different formulas. D8's correction (`gm/(2*pi*cgg)`, fixing a ~40%
  double-count) was right and is simply no longer reachable from the default.

## What D9 closed that D8 could not

This file's own §"Fix sketch" item 3 said the missing check was **an assertion
against ngspice, not against our own strings**, and named S4 as its owner. That
check now exists, and it was run as part of D9:

```
sky130 nfet_01v8   /usr/bin/ngspice (42)   id gm gds vgs vth vds -> RAW, checkvalid=0
                   /usr/local/bin (46+)    id gm gds vgs vth vds -> RAW, checkvalid=0
gf180  nfet_03v3   both binaries           id gm gds vgs vth vds -> RAW, checkvalid=0
```

one card per parameter, real models, the `.control … write … .endc` idiom every
shipped bench uses. **No default row can suppress a raw file on any supported
ngspice** — which is what this issue was ultimately about.

IHP is still unmeasurable on this box (`pre_osdi psp103.osdi` needs OSDI v0.4,
ngspice-42 here supports v0.3), and its six are a **subset of the names its own
prototype already used**, so that PDK's exposure is reduced by inference rather
than by measurement. Said plainly in `sg13g2_procs.tcl` rather than left implicit.

## And a defect class that left the shipped path as a side effect

`vgs` and `vds` are real BSIM4 instance parameters (`vgs 0.896512`,
`vds 1.79302`), savable on both binaries as `v(@m.…[vgs])`. Under D9 they are
ordinary `params` rows, so **no shipped descriptor carries a `pinexpr` any more**
— which takes issue **0446** (a pin expression fabricating `vgs = 0` on a GND
source) and issue **0444** (the load-bearing space before `)`) off the stock
path. Neither C defect is fixed. Both remain reachable by a user-written
`pinexpr`, and their guardians moved to test-local descriptors
(`test_op_annot.tcl` rows S28b, S29, S17b, P10) so they can still fail.

## The half of the instruction that is NOT done

*"We can report a mismatch between expectation and actual delivery from ngspice
as a warning in CIW and logfile"* is approved in principle and filed as invariant
**I8** plus issue **0604**. *"We will provide a means (TBD)"* is issue **0603**.
