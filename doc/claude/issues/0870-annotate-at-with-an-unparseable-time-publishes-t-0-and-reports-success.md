# 0870 — `xschem annotate_at <unparseable>` publishes a number at t = 0 and reports success

**Status:** ✅ **FIXED 2026-09-28**, in `scheduler()`'s `annotate_at` arm (`src/scheduler.c`),
fenced by row **V76** of `tests/headless/test_op_annot.tcl`. Filed by the A3 write-up, 2026-08-27.

## The fix, and the one decision inside it

`strtod()` is asked only **whether it consumed anything**; its value is discarded. The value that is
validated and published is `atof_spice()`'s, because that is the number the schematic will show. The
guard refuses when nothing was consumed, or when the result is not finite.

⚠ **The predicate is "a number BEGINS the token", never "the whole token is a number", and that is
the difference between a fix and a regression.** `atof_spice()` exists to read SPICE suffixes:
measured on the shipped binary, `annotate_at 1ns` resolves to 1e-09 and must go on doing so. This
file's original wording — *"atof_spice consumed the whole token"* — read literally would break it,
and the house helper `move_objects_slot_is_number()` in the same file demands `*endp == '\0'` and
would refuse `1ns`. Row V76 drives `1ns` as the second half of its pair precisely so a fix that
refused everything cannot pass.

**NaN and Inf needed a second clause** and are a different failure from `abc`: they *parse*, so
`strtod` consumes them, and they used to reach `annot_x` verbatim and publish the clamped endpoint
sample. Finiteness is tested with `IS_FINITE_DBL`, which was **moved to `src/xschem.h`** from
`draw.c`'s graph-marker parser rather than written a second time — the C side now has one spelling of
the predicate, as the Tcl side already does with `op_annot::_finite`.

**No new user-facing wording.** The sibling arm already ships `xschem annotate_at <time>: missing
time point`; this one answers `xschem annotate_at <time>: not a time point: <token>`. Both shipped
GUI doors degrade into already-ratified sentences: `cadence::annot_tran` (`utils/annot_mode.tcl`)
wraps the verb in a `catch` and turns a raise into its existing `nodata` refusal, whose sentence is
already in the V-section goldens. So no `rule` debt was filed.

**RED FIRST.** V76 was written and run before the code: at HEAD it failed
`{0 0 0 0 0 1 {0 1e-09 0} 1}` against `{1 1 1 1 1 1 {0 1e-09 0} 1}` — the five refusals absent, and
the last three elements already correct, which is what pinned `1ns` as the constraint the fix had to
preserve. After the fix, 486 checks headless and 493 on the display arm.

## Still open, deliberately

`3xyz` still means 3e6 and `3zzz`/`3sec` still mean 3.0, because `atof_spice`'s suffix scanner
tolerates trailing letters. Both driven. That is pre-existing SPICE-ish leniency shared with every
other `atof_spice` caller in the tree, and narrowing it would be a **user-visible choice** rather
than a defect fix — so it is not done here, and V76's name states the four tokens it drives and
claims nothing about tokens it does not.
Class: **RULING D5-1** shape — a fabricated number reaches a schematic — reached
through the scripting surface rather than the GUI.

Owner: issue **0868**; the verb is `src/scheduler.c` ~:2362.

## Measured, 2026-08-27, shipped binary + the 0868 tree

Same fixture as 0869 (`/tmp/a3m`), transient attached, cursor B on:

```
WU7 annotate_at abc -> rc=0 r=1 annot=0 0 0 PAINTED=d 0
```

`rc=0` is the Tcl return code — no error was raised. `r=1` is the verb's own answer:
**it reports that it annotated.** The empty string behaves identically.

## Why

```c
rc = backannotate_at_time(atof_spice(argv[2]));
```

`atof_spice()` answers `0.0` for anything it cannot parse, so a typo becomes a
perfectly well-formed request for t = 0, which every transient satisfies. The
ARGUMENT-PRESENCE check is right and already there —
`xschem annotate_at` with no argument answers *"xschem annotate_at <time>: missing
time point"* and `TCL_ERROR` — but nothing checks parseability.

## Reachability

**Not** reachable through either shipped entry point: the `Alt-Shift-6` chord and the
ASE-L menu item both pass a real cursor position through `cadence::annot_tran`. It is
reachable by anyone scripting the documented verb, which is the surface
`doc/claude/specs/op_annotation.md` §4.9 advertises. A typo in a script publishes a
number onto the schematic and reports that it worked.

## Fix shape

Validate before calling, in the same arm that already validates presence — the house
pattern is `Tcl_GetDouble()` / an explicit `strtod` end-pointer test — and answer
`TCL_ERROR` naming the unparseable token, the way the missing-argument arm does.
⚠ `atof_spice()` accepts SPICE suffixes (`3n`, `1meg`), so a plain `Tcl_GetDouble`
would REFUSE input the verb should keep accepting; the test must be
"`atof_spice` consumed the whole token", not "Tcl can parse it".

Acceptance: two rows beside section V's V1 — `annotate_at abc` raises and publishes
nothing (`raw annot` unchanged), and `annotate_at 3n` still succeeds.
