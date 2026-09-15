# M22 — a noisy transient through ASE-L's own checkpoint loop

**Measured 2026-09-15 by the driver**, while Stage 13 task 2's crew held the code — ngspice only, in the
driver's scratch directory, one process at a time, nothing that crashes. Both binaries: apt 45.2
(`/usr/bin/ngspice`) and the fork (`/home/analog/dev/ngspice/build-ver_50/src/ngspice`).

The debt: `tran_points` estimates a transient from its card alone, and that estimate decides whether
Stage 6f's checkpoint loop is armed. A noisy transient is far longer than its card says (`TS = 100n` on
`tran 1u 1m`: 44 116 points on 45.2, 50 008 on the fork, where the card says ~1000), so it is never
checkpointed — and nobody had run one through the loop.

## The answer

✅ **The loop is safe to arm on a noisy transient, on both binaries.** It runs, writes its checkpoints,
finishes at the transient's end with monotonic time, rc 0. **The noise the simulator generates is
unchanged by it.** Two costs are measured and small; neither argues against checkpointing.

**So make the estimate noise-aware** — task 1's `ase::stimuli_points` already computes the count, and
its sabotage S44 reds NX2 on purpose until this decision is taken.

## The deck

ASE-L's own loop shape, copied from `render_deck` (issue 1433): `set cktgt = $&cknext`, `stop after
$cktgt` above `tran 1u 1m`, `while ckdone = 0` / `if length(time) >= $cktgt` / `remzerovec` / `write
ck.tmp` / `shell mv -f` / `resume`, then `delete all`. `.options seed=5`, a 1 kΩ load, and one source:

| kind | source |
|---|---|
| white | `v1 1 0 dc 0 trnoise(1 100n 0 0)` |
| `trrandom` | `v1 1 0 dc 0 trrandom(2 100n 0 1 0)` |
| RTS | `v1 1 0 dc 0 trnoise(0 0 0 0 1 5u 5u)` |

Each kind run unchecked and checked, and the final `v(1)` written as an ascii raw for comparison.

## What changes and what does not

| | 45.2 unchecked | 45.2 checked | fork unchecked | fork checked |
|---|---|---|---|---|
| white, checkpoints / points | 0 / 44 116 | **4 / 44 166** | 0 / 50 008 | **5 / 50 028** |
| white, σ of the generated samples (only `t = k·TS`, n = 1003), three runs | 0.992 · 1.001 · 0.994 | 1.002 · 1.020 · 0.998 | 1.012 · 1.001 · 0.992 | 0.994 · 0.995 · 0.978 |
| white, time-weighted RMS of the waveform, three runs | 0.822 · 0.818 · 0.815 | 0.802 · 0.806 · 0.801 | 0.817 · 0.821 · 0.813 | 0.803 · 0.806 · 0.793 |
| white, `stddev(v(1))` over every rawfile point, three runs | 0.881 · 0.878 · 0.876 | **0.833 · 0.837 · 0.831** | 0.860 · 0.867 · 0.857 | **0.821 · 0.824 · 0.811** |
| seeded `trrandom`, points | 44 116 | 44 166 | 50 008 | 50 028 |
| seeded `trrandom`, values at the timepoints both runs share | — | **identical at 10 011 of 10 012**; only `t = 1 ms` differs | — | **identical at 10 012 of 10 013**; only `t = 1 ms` differs |
| seeded RTS, checkpoint step 500 | 1618 points | **3 checkpoints, 1618 points, every value identical** | 1605 points | **3 checkpoints, 1605 points, every value identical** |

## Reading it

1. **The noise is not perturbed.** The generated white samples keep σ ≈ 1.00 whether or not the run was
   checkpointed. A seeded `trrandom` stream is identical at every shared timepoint but one; a seeded RTS
   stream is bit-identical.
2. ⚠ **Resume adds points.** Each `resume` restarts the timestep controller, so a cluster of small steps
   follows every stop — measured at 0.000227 s on 45.2 and 0.000200 s on the fork, about **12 extra
   points a checkpoint on 45.2 and 4 on the fork**. That is noise in a point count nobody pins.
3. ⚠ **So `stddev()` over rawfile points is not a noise statistic, and the 5 % it moved proves it.**
   Points are not uniform in time; extra points clustered after a resume shift a per-point statistic by
   ~5 % while the generated samples do not move at all. **The time-weighted RMS moves about 2 %** (0.818
   against 0.803 on 45.2) — measured, systematic across three runs on each binary, and **not explained**.
   It is small beside the run-to-run spread a user sees from white noise being irreproducible, but it is
   recorded rather than rounded away. **Any readout or measurement of noise must be time-weighted** —
   `meas … rms`, never `stddev` of the raw vector.
4. ⚠ **The last sample of a seeded `trrandom` differs** when the run was checkpointed (45.2: 0.3746
   unchecked, −0.0579 checked; fork: 0.3746, −1.6349). A checkpointed seeded run is therefore **not
   bit-identical to an unchecked one** at its final point. A campaign whose shards all use the same
   checkpoint plan compares like with like; a comparison across a changed plan does not.
5. **The unchecked seeded final value, 0.3745958247514248, is identical on both binaries** — a
   re-confirmation that `trrandom` under a seed is portable across them.

## Not measured

A noisy transient that is **killed** mid-run and salvaged (the checkpoint's purpose, measured for a clean
transient in `evidence/salvage.md`); 1/f noise under the loop; the cause of the 2 % RMS shift.
