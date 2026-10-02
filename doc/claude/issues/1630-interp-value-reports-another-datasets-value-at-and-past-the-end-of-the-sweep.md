# 1630 — `wviewer::interp_value` reports ANOTHER dataset's value at and past the end of the sweep

**STAMP:** `v1 claim=open tree=5c8b858a stamped=2026-10-01 fix=none open=2`

Status: **OPEN**, found 2026-10-01 by the calculator batch's `cross` recon stage while measuring
which raw accessor `cross` should read the sample column with. Not a Calculator defect and not
caused by any Calculator change — `interp_value` predates this batch.

Area: `wviewer::interp_value` — `src/wave_viewer.tcl`. Its inputs are
`xschem raw pos_at` (→ `raw_get_pos()`, `src/save.c`), `xschem raw value` and
`xschem raw points`, whose **default dataset conventions disagree with one another**.
Found: measuring `xschem raw values` dataset behaviour against `tests/headless/data/calc_fixture.raw`

## The symptom: a factor-of-two wrong voltage on a measurement surface

On the committed two-dataset fixture, at `x = 0.01` — the **last sample, inside the sweep, not
past it** — the shipped proc answers **2.5** where dataset 0's `v(div)` is **5**.

```
GROUND TRUTH: v(div) last sample of ds0 = 5 ; of ds1 = 2.5
              allpoints index 201 is  v(div)=2.5 time=0.01
  interp_value v(div) 0.0095    -> 4.75   (ds0 truth = ramp/2 = 4.75)   ok
  interp_value v(div) 0.01      -> 2.5    (ds0 truth = ramp/2 = 5.0)    WRONG
  interp_value v(div) 0.0100001 -> 2.5    | ds0 last = 5 | ds1 last = 2.5 | pos_at = -1
  interp_value v(div) 1.0       -> 2.5    | ds0 last = 5 | ds1 last = 2.5 | pos_at = -1
  n-1 = 201 ; max pos_at can return on this raw = -1
```

The fixture's `README.md` derivation is unambiguous: `v(div)` is `v(ramp)/2` in dataset 0 (5 V at
t = 10 ms) and `v(ramp)/4` in dataset 1 (2.5 V). So this is not a rounding question — it is the
wrong dataset's number, reported without any sign that a fallback was taken.

**Reproduced against the SHIPPED code, not a transcription**: the probe extracts the proc body out
of `src/wave_viewer.tcl` and `eval`s it, so what ran is the file's own text.

## Mechanism, measured end to end

Three conventions meet in this proc and no two of them agree:

1. **`pos_at time 0.01` returns `-1`, not 100.** `time[100]` is `0.009999999999999995` — five ulps
   under the round literal — and `raw_get_pos()`'s entry guard compares inclusively against the
   window's end value, so the exact end of the sweep is reported as outside it. (That guard is
   issue **1631**; this issue is what the *caller* then does about it.)
2. **The `$pos < 0` arm then takes `$n` from `xschem raw points`, which answers `allpoints`** —
   202 here, not 101 — and reads `xschem raw value $sweep [expr {$n - 1}]`, i.e. allpoint **201**.
   On a multi-dataset raw that index belongs to **dataset 1**.
3. **The nearest-endpoint test then prefers it**: `|x - s0|` is 0.01 while `|x - sl|` is ≈ 0, so the
   proc holds the far endpoint — and the far endpoint it holds is the other dataset's.

The proc's own comment names the assumption it is built on —
*"dataset-0 semantics — `pos_at` searches dataset 0 and `raw value` indexes allpoints, identical
for single-dataset raws"* — and that is exactly true and exactly insufficient: the fixture is a
two-dataset raw, so what the comment calls a v1 simplification stops being a simplification and
becomes a wrong number. **`RULING D4-4`'s "hold, never extrapolate" is not met**: it holds, but it
holds the wrong dataset's end.

## Open items

1. **The wrong-dataset value at and past the end of the sweep** (above). The fix is to make the
   fallback dataset-relative — read the point count for the dataset being searched rather than
   `allpoints` — so that "hold the last value" holds *this* dataset's last value. Note that fixing
   issue 1631's guard would move the symptom (`pos_at` would answer 100) without fixing this
   defect, because every `x` strictly past the end still takes the `$pos < 0` arm.
2. **The `if {$pos >= $n - 1}` arm is DEAD on any multi-dataset raw.** `pos_at` returns a
   dataset-relative index, at most 100 on this fixture, and `$n - 1` is 201. So the branch that is
   supposed to recognise "at or past the last point" can never be true there, which is the second
   half of the same unit mismatch. A fix for item 1 must not leave this arm comparing the two
   different units.

## What is NOT claimed

- **No evidence of a non-monotonic sweep column breaking this caller.** The recon crew built a
  nested multi-sweep DC raw whose `v-sweep` column restarts inside one dataset and `pos_at`
  answered correctly at every `x` tried, because that sawtooth's endpoints happen to be its
  extremes — which is what the guard needs. The shape that *would* break it (inner sweeps 0→1 then
  0→0.5, where the final value is not the extreme) could not be produced from anything the product
  itself writes. So the monotonicity hypothesis for this caller is **unconfirmed, and it was
  looked for.**
- **One database shape was not built**: `read_dataset()` rewrites a multi-point `Operating Point`
  plot to `sim_type = dc`, and an Operating Point plot's variable 0 is a node voltage rather than
  a sweep — together describing a database where this proc's variable-0 column is an arbitrary
  non-monotonic signal. That is the remaining lead and the crew estimated it a 15-minute probe.
- **No suite fences any of this yet.** The measurements above are a recon probe in a scratch
  directory, not a committed row, so nothing re-checks them. A fix must arrive with one.
