# 1631 — `raw pos_at`'s help text promises a crossing finder; the code is a monotonic bisection

**STAMP:** `v1 claim=open tree=5c8b858a stamped=2026-10-01 fix=none open=3`

Status: **OPEN**, found 2026-10-01 by the calculator batch's `cross` recon stage, which went
looking for an existing level-crossing primitive to build `cross` on and found a verb that
advertises itself as one.

Area: `raw_get_pos()` — `src/save.c` — and the `pos_at` help block in `xschem()`'s `raw`
dispatcher, `src/scheduler.c`. Sole C caller is that verb; the verb's shipped callers are
`wviewer::interp_value` (`src/wave_viewer.tcl`) and `backannot_pos_at`.
Found: 2026-10-01, while measuring whether `cross` could reuse `pos_at`

## The claim and the code

The help block says `pos_at` *"returns the position … of the **first** point `p` where `node[p]`
and `node[p+1]` bracket value"*. The implementation is a bisection seeded from the two **window
endpoints**:

```c
vstart = get_raw_value(dset, idx, start);
vend   = get_raw_value(dset, idx, end);
sign = (vend > vstart) ? 1 : -1;
if( sign * value >= sign * vstart && sign * value <= sign * vend) {
  while(1) {
    x = (start + end ) / 2;
    vx = get_raw_value(dset, idx, x);
    if(abs(end - start) <= 1) break;
    if( sign * vx > sign * value) end = x;
    else start = x;
  }
}
return x;
```

A single search direction is inferred from which endpoint is larger; anything not between them in
that direction is refused; the halving then lands in whichever bracket it lands in. On a monotone
column that is correct and fast. On an oscillating one, neither "first" nor "the crossing" is what
comes back.

## Measured, exhaustively, on the committed fixture

Over **all 5151 sub-windows** of dataset 0 of `tests/headless/data/calc_fixture.raw`, classified
against hand-computed true bracketing pairs:

```
SQ  L=0.25 : bracketing=2368  NON-bracketing=0  MISSED(refused, crossing inside)=1724
SQ  L=0.5  : bracketing=2375  NON-bracketing=1  MISSED=1713
SQ  L=0.75 : bracketing=2208  NON-bracketing=0  MISSED=1820
RMP L=3.05 : bracketing=2170  NON-bracketing=0  MISSED=0
RMP L=0.55 : bracketing=570   NON-bracketing=0  MISSED=0
```

So on the non-monotonic `v(sq)`, **42% of the windows that contain a real crossing are answered
`-1`** — and the monotonic `v(ramp)` misses none of 5151. On a 200 000-point 50-cycle sine with
~100 crossings of ±0.5, `pos_at` answers `-1` for **both** levels, because the endpoints are
`v[0]=0` and `v[199999]=-0.00157` and the guard rejects anything outside `[-0.00157, 0]`.

**The "first" claim is separately false**: at `L=0.25` a later crossing was returned in 527 of the
2368 answering windows, e.g. window `[0,50]` has crossings at `{9, 22, 49}` and `pos_at` answers
**49**. At `L=0.5`, 941 of 2375. On the ramp: 0 of 2170.

**The failure mode is a false negative, not a wrong index**, which is the one piece of good news:
0 non-bracketing answers out of 2368 at `L=0.25`, and the single non-bracket at `L=0.5` is the
degenerate zero-width window `[50,50]`. The guard is conservative — it refuses rather than
fabricates.

**The tree already knows about the requirement**, from a file nobody consulted: `vcd_flush()` in
`src/vcd_read.c` clamps a backwards VCD timestamp *specifically* so that `values[0]` comes out
non-decreasing, and names `raw_get_pos()` as the reason — *"an out-of-order X column is a silently
wrong plot, not a crash, which is the worst kind."*

## Open items

1. **The help text.** The word "first" is wrong, and more importantly the block does not say the
   search assumes a **monotone** column. One sentence fixes it, and this is the item worth doing
   first because the defect's real cost is as a **trap for the next caller** — `cross` is exactly
   the next caller that would reach for it, and the only reason it did not is that this recon ran.
   The help's own next sentence already says *"This is usually done on the sweep (time) variable in
   transient sims"*, so the intent was always the monotone column; the contract was simply never
   stated.
2. **The flat-window path returns a non-answer confidently.** With equal endpoints, `sign` comes
   out `-1` (because `vend > vstart` is false), the guard *admits* the search, and the bisection
   returns the second-to-last index of the window — neither a crossing nor the first point. An
   all-zero window `[0,5]` asked for 0 answers **4**.
3. **The exact end of a sweep is unreachable.** `pos_at` can never return `lastpoint` on a
   non-degenerate window, and it refuses a level the trace reaches exactly at its final sample when
   that value is asked for as a round literal: on the fixture `pos_at time 0.01` is `-1` because
   `time[100]` is `0.009999999999999995`, while `pos_at time 0.009999999999999995` is 99.
   **This is the input half of issue 1630**, where the caller's handling of the `-1` then reports
   another dataset's value.

## Why this is filed rather than fixed, and why it is not urgent

**No shipped caller is wrong today on this account.** Both pass the sweep variable, which is
monotone — `wviewer::interp_value` for the cursor readout and `backannot_pos_at` for the
annotation path — and the measured answers there are right (`pos_at time 0.00095 0` → 9,
`pos_at v(ramp) 3.0 0` → 29). So the behaviour is arguably intended and only its documentation is
wrong. It is filed because the documentation is what the next implementer reads, and because
`cross` now exists in the tree as a correct level-crossing scan that a future reader might be
tempted to "simplify" onto this verb.

A **reversed window is not a bug**: `from_start > to_end` gives the same answer as the forward
spelling, because the inferred `sign` absorbs the reversal. Measured, so nobody needs to guard it.
