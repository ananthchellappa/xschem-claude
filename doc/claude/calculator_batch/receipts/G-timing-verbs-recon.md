# Stage G — `riseTime`, `delay`, `dutyCycle` recon

Four crews, 2026-10-02, before any 7.3 code existed. Driver collected. Decided contract:
`../TIMING_CONTRACT.md`. **Blockers: none.**

## The headline: the driver's planned optimisation was pointless, and measurement said so

The intent was a shared *evaluate once, scan many* helper, so a verb needing two levels would not
evaluate its expression twice. Where the time actually goes, on a 100 000-point column:

```
raw add + raw del          0.21 ms
one bulk raw values read   10.3  ms
ONE nth=0 scan            296    ms      <- 27x a column read
```

So hoisting the evaluation saves **~20 ms out of ~300**. On the committed 101-point fixture the
whole question is **191 µs against 106 µs**. The helper was solving the cheap half.

And the simple shape is *correct*, established four independent ways rather than argued:

- **92** level/nth/edge combinations bit-identical through `calc::cross` and through a separate
  evaluation scanned directly;
- the engine deterministic **even when the vector array grew between the two adds**;
- **340** mint/add/read/delete cycles leaving `xschem raw list` byte-identical, `nvars` unchanged,
  no `__calc_tmp*` leaked;
- two independent evaluations of two expressions yielding **bit-identical X columns**.

⚠ **And the clever shapes break a registered fence.** Ten candidate shapes were run against row
**SR5** of `test_calc_scratch_reuse`: A, B, E, I and J′ keep it green; **C, C2, D, F, H′ and G redden
it**. The trap is a verb reading a named vector it did not create. Delegating to `cross` is shape A.

**This is the SECOND performance intuition this batch has had refuted by measurement.** The first
was D10, where the faster per-point read turned out to print `%.8g` and could not meet the fixture's
own 1e-12 tolerance. The rule that keeps falling out: *a performance number is not a reason on its
own, and the shape you were about to optimise may not be where the time is.*

## The evaluate-once seam already exists, so 7.3 needs no refactor

`calc::cross_scan {xs ys L nth edge}` takes the **columns**, not an expression. Called directly with
columns the crew read itself, it returned bit-identical answers to `calc::cross` at every level, both
signs of `nth`, every edge and `nth = 0` — 24 of 24 lines ending `identical=1`. So
`cross_scan`, `cross_pair`, `cross_absent`, `cross_refusal`, `cross_ordinal` and `cross_msg` all stay
exactly as shipped.

## `cross` costs 12 raw operations per call, and the contract's inventory was one short

Traced with a counting wrapper over the real dispatcher (`rename xschem __xs_real`), not read off the
source:

```
 1 raw loaded   2 raw datasets   3 raw sim_type   4 raw index time   5 raw list
 6 raw case     7 raw index __calc_tmp1           8 raw index __calc_tmp1
 9 raw add __calc_tmp1 v(sq)    10 raw values __calc_tmp1 0
11 raw values time 0           12 raw del __calc_tmp1
```

`xschem raw case` (op 6) is reached through `calc::rpn_bad_token` → `wviewer::validate_rpn` →
`wviewer::db_fuzzy` and was missing from `CROSS_CONTRACT.md`'s account. **Ops 7 and 8 are the same
query with the same argument on adjacent statements** — `calc::tmpvec`'s collision probe and D11's
pre-add destination check — and the F2 receipt already records that no row forces the second.

The refusal paths cost, measured: **D7's request validation touches ZERO raw operations**, `nodata`
costs 1, the OP-plot `nosweep` 3, `badtoken` 6, and only a call reaching the engine costs 12. That
makes D7 provably database-free and is the clean seam for a verb-side pre-check.

## The fixture can golden all three, and `dutyCycle` agrees with the deck

A scratch prototype of the three verbs as delegates agreed with shipped `calc::cross` over 48
combinations, and **`dutyCycle` returned `0.3000000000000002`, which is the generating deck's own
hand derivation** — a PULSE of 1 ms width plus 0.2 ms edges is 1.2 ms high in a 4 ms period. An
independent confirmation from the `.cir` rather than from the implementation.

## What went to the user, one question at a time

Both answers **simplified** the code, and both are recorded as rulings in the contract:

- **R415 — `riseTime`'s reference levels are supplied, never derived.** *"Cadence makes you supply
  them."* No min/max search, no first/last-sample rule, no settled-value estimator; omitting them is
  a refusal. This removed what would have been the verb's most delicate part — picking 100% off a
  ringing edge — and recon had already established the engine could not have helped
  (`min()`/`max()` are two-argument clamps, `avg()` is a running mean).
- **R416 — `dutyCycle` returns a wave, one value per cycle.** Not the first period, not the mean.
  ⚠ **Consequence:** its default now needs the waveform destination that `cross`'s `nth = 0` is
  already waiting on, and `frequency` will want it too. **Three verbs behind one missing piece makes
  that destination the measurement layer's critical path**, ahead of phase 4.

The driver settled the rest rather than queuing them: `delay` takes a full edge spec per side and
returns a **negative** answer rather than refusing (ADE-L is a floor, so a restriction it lacks is a
defect); `dutyCycle` reports a **fraction**, because the shipped catalogue help already promises
*"Fraction of a period the signal spends high"* and returning `30` would make shipped prose false.

## Three things found and deliberately not fixed here

1. **Spec §7.2's `settlingTime` and `overshoot` rows carry route `T`, not `T (on cross)`**, while the
   same section's prose and `CROSS_CONTRACT.md`'s opening list all seven as layered on `cross`. A
   table disagreeing with the prose beside it. Harmless for 7.3; it will mislead whoever takes the
   other two. Owed by this stage's commit.
2. **`calc::cross_scan`'s `nth = 0` arm answers success with an EMPTY list** for a level nothing
   reaches — `ok 1 absent 0 value {}`. **Declared and fenced**, not a defect: row `CX8` pins it by
   name. But `dutyCycle` is its first real caller and an empty list reaching period arithmetic is
   exactly how that contract becomes a raise. Guarded at the point of use, as a row (T5).
3. ⚠ **`calc::fn_click` has no route for a T-route verb whose measurement proc exists.** It dispatches
   on `calc::fn_reason`, empty for route `T`, and falls through to `calc::inert … 5`. So **a shipped
   `riseTime` is not reachable from the UI**, exactly as `cross` is not. Correct by design — phase 5
   owns R410/R411/R412, and two registered suites assert the phase-5 sentence by literal — but it
   must be stated plainly so **nobody reads a green 7.3 as a feature the user can reach**.

## Scratch discipline

376 KB left under the recon label, about 180 KB of it this round's; no large fixtures built, the
100 000-point probe column deleted, the throwaway HOME removed. `/tmp` unchanged at ~743 MB used.
This is now reported per stage because the previous one left **4.4 GB** in a tmpfs and starved the
machine of the RAM T1 needed.
