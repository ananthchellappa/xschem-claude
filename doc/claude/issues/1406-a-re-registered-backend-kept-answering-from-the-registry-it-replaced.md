# 1406 — a re-registered backend kept answering from the registry it replaced

**Status:** fixed
**Branch:** fluid-editing
**Filed:** 2026-09-11
**Found by:** the Stage 2 recon crews of `doc/claude/ase_analyses_batch/` — **independently, three
times**, by the crews working 2a, 2b and 2d, which is the tell that a fourth pass would have found
it again.

## The defect

Stage 1 (issue **1401**) gave `ase::analysis_types` a memo so that the per-simulator adapter hook
is called once per backend rather than once per reader:

```tcl
variable ase::analysis_cache {}

proc ase::analysis_types {{sim {}}} {
  variable analysis_cache
  if {$sim eq {}} { set sim [ase::default_simulator] }
  if {[dict exists $analysis_cache $sim]} { return [dict get $analysis_cache $sim] }
  ...
  dict set analysis_cache $sim $r
```

**It gave it no invalidator.** Measured: `grep -n analysis_cache` over `src/ase.tcl`,
`src/ase_window.tcl` and every suite returns **four** hits — the declaration, the `variable`, the
read and the write. `ase::sim_caps_clear` does not touch it. Nothing else does either.

So `ase::register_backend <name> <hooks>` replaces what a backend *is*, and the answer to *"what
analyses does it have"* goes on being the one taken from the registry that was replaced — for the
life of the interpreter.

## Why it shipped green, and why that is the interesting part

**Because the invalidation rule was "nobody ever does that."** Adapters are first-party and
register exactly once, at source time, from inside `src/ase.tcl`. Under that usage the memo is
never wrong and no row could see it.

That is the same shape as the eight copies of *"what is a `dc` analysis"* this batch exists to
delete: a thing that is correct only because of a habit nobody wrote down. The habit changed the
moment Stage 2 arrived — **both** of the sub-items that follow this one register stand-in
registries *per test row*, which is precisely the usage the memo cannot survive.

## The fix

`ase::analysis_cache_clear {{sim {}}}`, called from `ase::register_backend` **after** the
five-hook `foreach` — registering a name is the one event that changes what the answer should be,
so the memo is dropped where the replacement happens.

⚠ **The call sits BELOW the five-hook loop, not inside it.** Row **A3** of
`tests/headless/test_ase_simcaps_0948.tcl` reads that loop's own source line and asserts it names
exactly the five hooks and does **not** name `capabilities`; anything added inside it is read by
that row as a sixth *required* hook, which would redden every hand-built five-hook registration in
`test_ase_core.tcl`.

⚠ **`{}` means EVERY simulator, which is deliberately the opposite of `ase::analysis_types`'s
`{}`** (that one means *the default simulator*). The asymmetry is the safe direction, because the
two failure modes are not symmetric: a caller who means *clear everything* and gets only ngspice
holds a stale memo for every other backend and cannot tell; a caller who means *clear ngspice* and
gets everything has thrown away a memo that costs one hook call to rebuild. **One is a wrong
answer, the other is a recomputation.**

## The row

`test_ase_simcaps_0948.tcl` section **L**, row **L1**: register `zzl1` with a registry naming type
`zzl1a`, read it, re-register `zzl1` with a registry naming `zzl1b`, read again — and assert the
**second** answer comes back, with a control proving a *different* backend (`ngspice`) was not
disturbed, so a clear-everything bug cannot pass the row by accident either.

⚠ **It reads the TYPE KEYS, not a count.** A count is equal for two registries of the same size,
so a count-based row would pass while the wrong registry answered.

**Sabotage, two passes, both reddening L1 with exactly `{zzl1a zzl1a OK}`** — the replaced registry
still speaking:

1. delete the `ase::analysis_cache_clear $name` line from `ase::register_backend`;
2. keep the call but make the named-simulator arm a no-op — the plausible wrong body, where the
   proc exists, is called, and does nothing.

## Floors

`test_ase_simcaps_0948` **110 → 111**, both arms.

⚠ **This suite had no floor paragraph and no floor constant at all**, which is its own defect and
is fixed here: a suite that records no expected count leaves **no trace** when a row is silently
deleted or a section stops running — `ALL PASS` prints as happily over 80 checks as over 110. That
is the same shape that cost 100 checks in `test_ase_persist.tcl` (issue **1405**).

## Related

* **1401** — Stage 1, which added the memo.
* **1405** — the sibling Stage 1 debt found by the same recon pass; both are "shipped green because
  the thing that would have caught it was never run".
* **0950** — `ase::sim_caps_clear` on every registry edit, which is the same rule for the
  *capability* cache. This issue is that rule reaching the *analysis registry* cache.
