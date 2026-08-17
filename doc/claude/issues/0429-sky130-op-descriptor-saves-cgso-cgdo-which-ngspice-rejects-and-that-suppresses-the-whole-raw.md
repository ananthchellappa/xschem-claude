# 0429 — sky130 saves `cgso` and `cgdo`, which ngspice-42 rejects, and ONE rejected `.save` card suppresses the ENTIRE raw file

Status: **open — measured, not fixed. This is the finding that downgraded S2 to
status E.** Found by the S2 Verify-C adversary of the op-annotation run
(2026-08-16) on branch `annotate`, then re-measured independently by the S2
write-up agent before the step was committed.

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

## Fix sketch, whichever way the answer goes

1. Replace `{cgso cgso 1}` / `{cgdo cgdo 1}` with `{cgso cgs 1}` / `{cgdo cgd 1}`
   — keeping the *label* stable so the on-screen text does not change, and moving
   only the raw *parameter*. That is the smallest blast radius (I3/L2) and it
   keeps `ft` meaningful.
2. Fix `sky130_write_save_lines:86-87` the same way, so the prototype and the
   generic builder still agree and `P3` can stay a byte-for-byte assertion.
3. Add a test row that is not a self-comparison: assert against **ngspice**, not
   against the prototype, that every registered sky130 parameter yields a vector
   in a real raw. S2's acceptance was a string diff between two pieces of our own
   code, and that is exactly the shape of check that cannot catch this class of
   defect. Spec §8's "the names are real in a raw" leg is the one that would
   have.
4. S4 (the ngspice round trip) is the natural owner of step 3 and must build it
   on sky130 or gf180 — IHP cannot be simulated on this box.
