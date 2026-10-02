# 1632 — `xschem raw values <name> <dataset>` reads `npoints` out of bounds, and the garbage can drive a runaway loop

**STAMP:** `v1 claim=open tree=5c8b858a stamped=2026-10-01 fix=none open=3`

Status: **OPEN**, found 2026-10-01 by the calculator batch's `cross` read-back recon while
establishing how `cross` should name its dataset. Pre-existing; no Calculator change caused it.

Area: the **`values`** arm of the `raw` dispatcher in `xschem()` — `src/scheduler.c` — feeding
`get_raw_value()` (`src/save.c`). The sibling **`points`** arm in the same dispatcher **does**
guard, which is the asymmetry that shows where the missing check belongs.
Found: `env -u DISPLAY valgrind ./src/xschem --nogui --pipe -q --script …` against
`tests/headless/data/calc_fixture.raw` (2 datasets)

## The defect

The arm takes the dataset straight from the argument and bounds it only from below:

```c
if(argc > 4) dataset = atoi(argv[4]);
if(dataset < 0) np = raw->allpoints;
else            np = raw->npoints[dataset];
```

`raw->npoints` is sized `my_realloc(&raw->npoints, raw->datasets * sizeof(int))`, so
`npoints[2]` on a two-dataset raw is past the end. There is **no upper bound anywhere on the
path**.

Valgrind, one error, and the block arithmetic is exact — a block of size 8 is `2 * sizeof(int)`
and the read is 0 bytes after it:

```
==2514772== Invalid read of size 4
==2514772==    at 0x40A27F5: xschem_cmds_r.constprop.0 (in .../src/xschem)
==2514772==    by 0x40BBBD2: xschem (in .../src/xschem)
==2514772==    by 0x4E34DDD: TclInvokeStringCommand (in /usr/lib/.../libtcl8.6.so)
==2514772==  Address 0x70bedb8 is 0 bytes after a block of size 8 alloc'd
==2514772==    at 0x4A1107F: realloc (vg_replace_malloc.c:1804)
==2514772==    by 0x40DE4CF: my_realloc (in .../src/xschem)
```

## ⚠ It is much worse than a four-byte read, and that is the reason this is filed rather than noted

**The out-of-bounds value becomes a loop bound.** On a plain run the garbage in that slot happened
to be ≤ 0 and the verb returned the empty string — `xschem raw values v(sq) 2` gave
`llength=0`, which looks like a polite "no such dataset". Under valgrind the same slot held a
large positive integer, so `for(p = 0; p < np; p++)` ran away, and `get_raw_value()`'s
**unconditional** `dbg(0, "get_raw_value(): dataset(%d) >= datasets(%d)")` printed once per
iteration:

- **46 462 copies** of that line in the last 2 MB of the log alone
- the log reached **1.1 GB** before the run was killed at **3m35s**

So the behaviour is heap-dependent: benign empty answer or hang-plus-disk-filler, decided by
whatever happens to sit past the end of a two-int allocation. Reachable from **any** Tcl caller
that computes a dataset number rather than typing a literal, which is every caller that iterates
datasets and gets its bound slightly wrong.

## Open items

1. **The missing upper bound in the `values` arm.** Mirror the `points` arm's guard
   (`if(dset >= 0 && dset < raw->datasets)`) so an out-of-range dataset is a defined empty answer
   rather than a heap read. This is the fix; the two below are what makes the fix insufficient on
   its own.
2. **`get_raw_value()`'s per-point `dbg(0, …)` is itself a hazard.** A diagnostic on the hot
   per-sample accessor, at level 0 so it prints on an ordinary run, turns any caller's bad
   dataset into unbounded output. Even with item 1 fixed, the next caller that reaches
   `get_raw_value()` with a bad dataset — there are many, and `draw.c` has twelve — gets the same
   disk-filler. The diagnostic wants to fire once, or be demoted, or the accessor wants to refuse
   rather than narrate.
3. **Audit the other arms of the `raw` dispatcher for the same missing bound.** `points` guards
   and `values` does not, in the same `switch`, which is strong evidence the bound was added
   per-arm as each defect surfaced rather than once. `pos_at` clamps its *dataset* (`if(dset >=
   raw->datasets) dset = raw->datasets - 1;`) which is a third convention again. Three arms,
   three different dispositions toward the same bad input.

## What `cross` does about it in the meantime

`cross` takes an explicit dataset and defaults to 0, which it was going to do anyway for the
separate reason in issue **1630** — the accessors disagree about their default dataset, and
reading across `allpoints` (`dataset -1`) manufactures a phantom crossing at the dataset seam
whose interpolated X sits within 2.5 × 10⁻¹⁸ of a real crossing. `cross` therefore never passes a
dataset it did not validate against `xschem raw datasets`, which keeps it clear of this defect
without relying on it being fixed.

## Related, not filed separately

**`xschem raw del` will delete the sweep column, irreversibly, and return 1.** `raw_deletevar()`
has no notion of a protected column: `del time` answers `rc=1`, `vars` drops 10 → 9, `index time`
becomes −1, index 0 becomes `@m1[gm]`, and there is no inverse verb. Combined with the fact that
the name-collision probe is **case-insensitive** (`index __CALC_TMP1` resolves `__calc_tmp1`,
`index V(RAMP)` resolves `v(ramp)`), a wrongly-computed temp name could destroy a loaded result's
X axis. Left unfiled because it is plausibly by design and no shipped caller is harmed — recorded
here so the next person to reach for `raw del` knows it is not restricted to vectors they added.
