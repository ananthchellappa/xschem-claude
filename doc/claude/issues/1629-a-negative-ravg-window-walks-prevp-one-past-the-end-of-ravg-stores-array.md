# 1629 — a negative `ravg()` window walks `prevp` one past the end of `ravg_store()`'s array

**STAMP:** `v1 claim=open tree=99a948e8 stamped=2026-10-01 fix=none open=3`

Status: **OPEN**, measured 2026-10-01 · Branch: `fluid-editing`
Found by: an adversarial C-semantics lens during issue **1628**, which was told to report
same-class defects elsewhere in the switch rather than fix them.
Related: issue **0325**, *the same defect in the same function one `case` away, already fixed*;
issue **1628**, the `case DIVIS` out-of-bounds read; `tests/headless/test_del_negative_arg.tcl`,
which is 0325's fence and the template for this one's.

## The defect

`plot_raw_custom_data()` in `src/save.c`, `case RAVG`:

```c
while(stack1[i].prevp <= last && x[p] - x[stack1[i].prevp] > stack2[stackptr2 - 1]) {
  stack1[i].prevp++;
}
stack2[stackptr2 - 2] = (result - ravg_store(2, i, stack1[i].prevp, 0, 0)) / stack2[stackptr2 - 1];
```

The guard is `prevp <= last`, so the loop can exit with **`prevp == last + 1`**: at
`prevp == last` the guard is still true, the body increments, and the next test fails. `prevp` is
then passed straight to `ravg_store()`, whose `arr[i][]` is `my_calloc()`ed with exactly
`last + 1` doubles — so index `last + 1` is **one element past the end**.

**The trigger is a negative window**, which is why it has survived. At `p == last` the time term
`x[p] - x[prevp]` is `0`, and `0 > window` is false for any non-negative window, so the walk stops
before the bound matters. With a **negative** `stack2[stackptr2 - 1]`, `0 > negative` is **true**,
the walk runs to `last + 1`, and the read happens.

## ⚠ This is issue 0325, one `case` away, and 0325's own comment describes it

`case DEL` carried the identical bound until issue 0325 changed it to `< last`. That comment is
still in the file, four lines above this loop, and it describes *this* defect:

> *"`< last`, not `<= last`: the old bound let prevp reach last + 1 and index both `x[]` and
> `ravg_store()`'s `arr[i][]` (my_calloc()ed with last + 1 doubles) one element past their end.
> For a non-negative tmp the bound is unreachable anyway … Issue 0325."*

It even names `ravg_store()` as one of the two arrays overrun. **0325 fixed the caller that led it
to the array and left the array's other caller alone.** Nothing is wrong with 0325's fix; the
defect is that the sibling was not swept at the same time, and no row looks at it.

One asymmetry worth recording: for `DEL` the fix was provably behaviour-preserving, because the
bound is unreachable for a non-negative delay. The same argument holds here for a non-negative
window, so `< last` should be equally free — **but that must be measured, not assumed**, because
`RAVG` divides by the window (`/ stack2[stackptr2 - 1]`) where `DEL` does not, so a negative
window has a second, arithmetic meaning this issue has not characterised.

## Reachability

`ravg()` is **not** obscure: it is a P-route entry in the Calculator's own catalogue —
`{ravg() Arithmetic P wave ravg() {Moving average of X over a window of width Y.}}` in
`calc::catalogue` — so it becomes clickable the moment PLAN phase 5 wires function insertion, and
it is already typeable into the buffer today, which PLAN phase 2 made live. It is also reachable
from a graph `node=` expression and from `xschem raw add`, neither of which validates the window's
sign.

Whether anything *stops* a negative window before the engine sees it has **not** been measured.
That is open item 2.

## Still open (open=3)

1. **The fix.** Almost certainly `prevp < last`, matching what 0325 did to `DEL` — but take the
   measurement 0325 took: show the bound is unreachable for a non-negative window, so the change
   cannot alter what a valid `ravg()` returns. Then decide separately what a **negative** window
   should *mean*, since the division makes it more than a bounds question; `DEL` chose to reject a
   negative delay outright and say so, which is the obvious precedent.
2. **Reachability from the UI is unmeasured.** Does anything validate the window's sign on the
   Calculator path, the graph `node=` path, or `xschem raw add`? If not, a user can reach an
   out-of-bounds read by typing one expression.
3. **Whether any other `case` in the same switch shares the pattern.** Issue 1628's lens found
   this one while checking `DIVIS`, and reported that `PREV`, `DERIV*`, `DEL` and `RAVG` all look
   backwards and carry per-operator state in `stack1[i]`. `DEL` and `RAVG` are now accounted for;
   the backward-looking arms have not each been checked against their own array's allocation.

## How to fence it

Follow `tests/headless/test_del_negative_arg.tcl`, which exists for 0325 and is the direct
template: it drives the real binary over a committed raw and asserts the operator's behaviour at
the window edge. The committed fixture `tests/headless/data/calc_fixture.raw` (landed at
`99a948e8`, contract in that directory's `README.md`) has a uniform 0.1 ms grid, so a window
expressed in sample multiples has exactly-known content — and a **valgrind** leg of the kind issue
1628's suite carries is what turns "the value looks wrong" into "this is an invalid read of size 8,
N bytes before a block of size M".
