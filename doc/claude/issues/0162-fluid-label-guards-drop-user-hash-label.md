# 0162 — the fluid label guards read a user `#` net as disposable tool copper

Status: **FIXED** (2026-07-26)
Area: `src/move.c` (`fluid_wire_explicit_lab`, the H2 sole-carrier guard in `fluid_loop_eligible`)
Tests: `tests/headless/wireedit/test_wireedit_58_user_hash_label_0162.tcl` — `A1`-`B3` (9 checks, new file)
Reference: `doc/claude/WIRING.md` open risk 15 (this issue), §6 "Explicit label"
Related: 0156 (the `#`-reserved policy this aligns with), 0105/0123 (the enforcement gate case A rides on),
0088 (the loop-collapse topology case B uses), 0040 (the H2 guard's origin)

## Report

From WIRING.md open risk 15:

> `fluid_wire_explicit_lab` (~:2945) returns `lab[0] != '#' || strpbrk(lab, "[:")`, and the H2 doom
> guard (~:3196) exempts `lab[0] == '#'` because "a #auto label regenerates". Both predate the 0156
> policy that `#` is *reserved* — a user CAN still have `lab=#foo` in an existing file (nothing
> rewrites it; only `addlabel::name_ok` blocks NEW ones), and for such a wire these guards conclude
> the label is disposable.

Confirmed at 42a2fb6c, and the symptom is sharper than "drops a label": the guard is the **universal
decline for named copper**, consulted by 12 call sites (every de-shorter, both anchor-tail pruners,
the straightener, the overshoot collapser, the jog and the rip-up). A `#foo` net fails it, so all of
them treat the user's net as tool copper they may reshape or delete.

Measured on the issue-0105 topology (`test_wireedit_54`'s fixture) with the END enforcement gate on
(`fluid_enforce_invariants 1`, the default), dragging R18 by (-90,-40):

| the backbone's name | outcome |
|---|---|
| `VDD` | repair blackout → the move is **REFUSED**, geometry byte-identical (16 wires) |
| `#foo` | blackout does not fire → the **user's net is rebuilt** as a y=-50 jog (16 → 17 wires, 6 deleted / 7 added) |
| `#net99` | same reshape — correct, that really is engine copper |

and on the issue-0088 loop topology with the label on the (-420,-90) corner, dragging R18 by (-20,-60):

| name | outcome |
|---|---|
| `FOO` | the redundant rectangle is left alone — 4 wires on the net survive |
| `#foo` | collapsed — **2 of the user's 4 wires deleted** |
| `#net99` | collapsed — correct |

## Fix

Two one-line swaps in `src/move.c`, both to `is_auto_net_name()` (`netlist.c:788`, declared in
`xschem.h`), which is strictly `#net<digits>` — the only shape the engine generates:

```c
/* fluid_wire_explicit_lab */
-  return lab && lab[0] && (lab[0] != '#'        || strpbrk(lab, "[:") != NULL);
+  return lab && lab[0] && (!is_auto_net_name(lab) || strpbrk(lab, "[:") != NULL);

/* fluid_loop_eligible, the H2 sole-carrier guard */
-  if(lab && lab[0] && lab[0] != '#') {
+  if(lab && lab[0] && !is_auto_net_name(lab)) {
```

The direction is monotone: `is_auto_net_name(x)` implies `x[0]=='#'`, so the change only ever
protects **more** copper, never less. Nothing in the tree is affected by construction — a sweep of
every committed `.sch`/`.sym` found **zero** `lab=#…` values that are not `#net<digits>`; the
defect is only reachable in a user's own file.

**This is a real behavior change, not just a save.** A user with a `#foo` net now gets the same
*named-rail blackout* everybody else gets: where the de-shorters used to reroute that net, the move
is now REFUSED (WIRING risk 1). That is the intended consistency — `#foo` is a user name under the
0156 policy — but it trades an automatic repair for a refusal on those nets.

## Verification

- `tests/headless/wireedit/test_wireedit_58_user_hash_label_0162.tcl` — **9 checks**, true headless.
  RED before the fix: `A2` and `B2` FAILED, all four control legs green.
  Every case is a **three-way** comparison (`VDD`/`FOO` · `#foo` · `#net99`) so the fix cannot pass
  by blanket-protecting every `#` name — that is what `A3`/`B3` pin.
- **Sabotage matrix**, four breaks, each applied with an assert-the-pattern-was-found patcher:

  | sabotage | caught by |
  |---|---|
  | revert the `fluid_wire_explicit_lab` swap | `A2`, `B2` |
  | `fluid_wire_explicit_lab` protects EVERY name (incl. `#net<N>`) | `A3`, `B3` |
  | revert the H2 swap | **nothing** — see below |
  | H2 protects EVERY name | **nothing** — see below |
- Gate: all **24** `test_fluid_*` PASS, the **58**-file wireedit suite `WIREEDIT: ALL PASS`.

### The H2 swap has no discriminating fixture — stated plainly

Sabotaging the H2 guard alone (either direction) changes nothing in any suite. That is not an
accident of this fixture: the H2 branch only fires when the loop pass would doom the **last**
carrier of a name, and for a lab_pin-named net every other wire on the net carries the same name,
so `keeps` is satisfied long before the guard matters. A 36-shape sweep (6 label positions × 6 drag
deltas on the 0088 topology) run on a **diagnostic build with `fluid_wire_explicit_lab` fixed and
H2 left old** — so that any difference is necessarily H2-driven — found **zero** differences.

The swap is kept anyway, as policy alignment: leaving one of the two guards on the old loose test
is exactly the kind of inconsistency that breeds the next issue, and the direction is monotone
(it can only protect more user copper). But it is **verified by inspection, not by measurement** —
if someone later constructs a shape where the loop pass dooms a named net's last wire, that is the
missing test.

## Not fixed / follow-ups

1. **The named-rail repair gap stands** (WIRING risk 1): named copper still gets a refusal rather
   than a routed result. `#foo` nets now join that population.
2. The 12 call sites still each carry their own "named" comment; none were rewritten beyond the two
   guards.
