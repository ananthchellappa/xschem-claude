# 0212 — `Descend to here` cannot address a vector-instance slice

**Status:** OPEN (declared limit of signal-browser PLAN item 11, not a regression)
**Area:** `src/wave_viewer.tcl` (`wviewer::hier_resolve` / `wviewer::hier_walk`),
`src/scheduler.c` (`descend`, `change_sch_path`), `src/actions.c`
(`descend_schematic`)
**Raised by:** signal-browser batch item 11 (hierarchy sync, browser → schematic)

## Symptom

The Signal Browser's `Descend to here` refuses any hierarchy path whose segment
carries a bracketed slice index:

```
hier_walk x1[3].x2
  -> {err {vector instance 'x1[3]' cannot be addressed (issue 0212)} {}}
```

Nothing moves, and the browser's status line says so. Scalar instances are
unaffected. This is a REFUSAL, deliberately, rather than a guess — landing on
the wrong slice while reporting success is the worse failure.

## Why it cannot simply be passed through, measured

Two different spellings of the same instance are in play and the two ends of the
walk disagree about which one they use.

* **What `sch_path` records is the EXPANDED name.** `descend_schematic()`
  (`src/actions.c`, the `find_nth` call on the instance name) writes the
  *individual* slice into `xctx->sch_path[]`, so a descend into slice 3 of
  `x1[3:0]` leaves a path component spelled `x1[3]`. That is what
  `xschem get sim_sch_path` — item 11's pivot (settled decision 10) — reports
  back, and it is also the spelling ngspice puts in the raw file, so it is the
  spelling the browser's tree carries.

* **What `get_instance()` matches is the UNEXPANDED name.** `get_instance()`
  (`src/scheduler.c`) resolves against the instance's own `name` property, which
  for a vector instance is the *range* form `x1[3:0]`. A lookup of `x1[3]` finds
  nothing, so `xschem descend -inst x1[3]` errors with
  *"instance not found"*.

So the path the browser holds cannot be fed back to the name-addressed descend
verb, and item 11 is name-addressed by settled decision 10 (a coordinate- or
index-addressed sync would not be replayable in the action log).

## The route a future item would take

`descend -inst` picks the *instance*; the *slice* is a separate axis:

* `xschem change_sch_path <n>` (`src/scheduler.c`) sets the slice at the current
  level;
* `xschem get sch_inst_number [n]` (`src/scheduler.c`) reads the slice that was
  descended into to reach level `n` — note the off-by-one its own comment
  documents: the value lives at `sch_inst_number[n-1]`, because
  `descend_schematic` records the slice at the PARENT level.

The fix is therefore, per segment:

1. split a bracketed segment into `<base>` and `<index>`;
2. resolve `<base>` against the instance's UNEXPANDED name — which means
   expanding each candidate instance's `name` with the label parser and asking
   whether `<base>[<index>]` is one of its bits, not a string compare;
3. `xschem descend -inst <the unexpanded name>`;
4. `xschem change_sch_path <slice>` to select the bit;
5. verify by reading `sim_sch_path` back — it will then read the EXPANDED
   spelling again, so the existing final verify works unchanged.

Step 2 is the real work and is why item 11 deferred it: it needs the same
bus/bit expansion `ase::ui::sod_expand_bits` does, applied to instance names
rather than net names, and it needs a decision about what a *range* target
(`x1[3:0]`) in the browser should even mean.

## Not in scope for this issue

The all-digit segment. `get_instance()` treats an all-digit argument as an
INDEX rather than a name, so `descend -inst 3` descends into instance number 3.
Item 11's `hier_resolve` sidesteps it by scanning by index and never doing a
by-name lookup, and the case is unreachable from the browser anyway (a raw
file's path segments are SPICE instance names, which cannot be all digits).
Recorded here so the next reader does not rediscover it as a bug.
