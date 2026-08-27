# 0870 — `xschem annotate_at <unparseable>` publishes a number at t = 0 and reports success

**Status:** 🔴 **OPEN — measured, NOT fixed.** Filed by the A3 write-up, 2026-08-27.
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
