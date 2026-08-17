# 0434 — what a bogus `.save` card costs depends on the ngspice invocation idiom; the spec documents only the cheap one

Status: OPEN, measured, not fixed (documentation defect + an unresolved design
question). Filed by the S3 write-up agent (op-annotation crew, branch
`annotate`).

Related: spec §3 R5 (added by this finding), spec §6 landmine 9, issue 0429
(sky130's `cgso`/`cgdo`), 0436 and 0437 (the two ways S3 generated bogus cards).

## The contradiction this resolves

Two passages in the design record said opposite things about the same event and
both were believed:

* **Spec landmine 9** (from S1): a save card for a device that does not exist
  writes a **fabricated `0.0` column** under exactly the requested name, with a
  `Warning: unrecognized variable` on stderr. Threat model: I3, a plausible wrong
  number.
* **Issue 0429** (from S2): **one** rejected card makes ngspice write **no raw
  file at all**. Threat model: the whole run is lost.

Neither passage named the discriminator, so anyone reading only one of them
reasons about the wrong failure.

## What was measured

Re-measured for S3 on **both** ngspice binaries now on this box, with a deck
carrying one good card and one card naming a device that is not in the netlist
(`.save @m.xnope.m1[id]`):

| invocation | result |
|---|---|
| `ngspice -b -r out.raw deck.sp` | `Warning: unrecognized variable - @m.xnope.m1[id]`; **raw written**; fabricated column, value decodes to `0.0` |
| `.control` / `op` / `write out.raw` / `.endc` | `Warning from checkvalid`; **NO RAW FILE AT ALL** |

ngspice-46+ adds `Error during 'write': no writable vector found.` to the second
case. Identical behaviour on `/usr/bin/ngspice` (42) and `/usr/local/bin/ngspice`
(46+).

**The second idiom is the one every shipped PDK bench uses.** So in practice the
governing failure mode is the expensive one, and landmine 9 — the passage the
plan's propagation bullets quote — describes the idiom our benches do *not* use.

## The separate `save all` finding, measured in the same runs

Not the same bug, but it belongs with it because it has the same signature (no
raw file) and the plan's wording walked straight into it:

```
deck line `save all`   (bare, deck level)  -> Error on line N ... Unable to find
                                              definition of model   -> RAW=NO   (42 and 46+)
deck line `.save all`  (dot-card)          -> RAW=YES  (272 bytes on 42, 329 on 46+)
```

ngspice parses a bare deck-level `save all` as an **`s`-prefixed switch
instance**. Spec §5 I2 and the S3 plan cell both said "prepend `save all`";
taken literally that instruction removes the entire raw, which is strictly worse
than omitting the line — it destroys more than the node voltages R2 is about.
Both documents have now been corrected. Recorded here because three separate
agents re-measured it independently before anyone trusted it.

## The design question this leaves open, which is above this crew's pay grade

S3's decision **D2** was that `save_cards` performs **no validation or
filtering** — the descriptor's `params` list is the single source of truth shared
by the save side and the read side, and an emitter that silently dropped a
parameter the display still reads would be a second, drifting policy (rung
**L1**, invariant **I1**). Rejected alternatives: a hardcoded invalid-parameter
blocklist inside the emitter (a second data source), and validating against a
real raw at emit time (impossible — the raw does not exist yet; that is the whole
point of a `.save` file).

That decision is defensible on its own terms, but combined with the measurement
above it means **sky130's inherited `cgso`/`cgdo` (issue 0429) reach the emitted
block, and one of them is enough to suppress the entire raw under the bench
idiom.** The fix belongs in the descriptor *data*, not the emitter — but 0429's
own correction is unratified.

## Still open

* **Unanswered, needs a human:** should the sky130 descriptor drop `cgso`/`cgdo`
  now (0429), or does the block stay bug-compatible with the prototype menu that
  has emitted them for years?
* No consumer captures ngspice's stderr warnings and surfaces them, which spec
  §4.6 requirement 4 asks for and which is the only thing that distinguishes
  "your descriptor is wrong" from "your simulation failed" in either idiom.
* **S4 must pin the ngspice path.** `/usr/local/bin/ngspice` (46+) was installed
  2026-08-16 and now *shadows* the `/usr/bin/ngspice` (42) that every earlier
  measurement in the spec and plan quotes. All rules above hold on both, but a
  bare `ngspice` in a test no longer means what the spec's numbers were taken
  against.
