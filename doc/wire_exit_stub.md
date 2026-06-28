# `wire_exit_stub` — the pin exit-stub option (experimental)

*What it is meant to do, how it works, why it is currently **off by default and not
recommended**, and what a future session should do to make it good.*

> **STATUS: EXPERIMENTAL — default OFF. Do not enable for real work yet.**
> Implemented in Phase 6 of the wire-editing-on-move effort (commit `8ba5ddf7`, branch
> `fluid-editing`). It passes its synthetic unit test (`TC10`) but **manual testing on a
> real schematic (`mos_power_ampli`, 2026-06-20) found the editing experience *worse*
> than with it off.** The feature is being **deferred** for a redesign in smaller,
> atomic steps with simpler examples. This document records the intent and the current
> mechanism so that work can resume from a known state.

---

## 1. What it is supposed to do (the "dream")

When you move a component and its attached wires rubber-band to follow (a *stretch*
move), the route often leaves a pin by immediately turning 90°. Cadence-style routing
instead keeps a **short stub jutting straight out of each pin along the pin's natural
lead direction**, and only *then* bends. It is the most uniform, predictable exit rule —
"Issue E / the dream" in the wire-editing spec (`doc/claude/code_analysis/wire_editing_spec_and_plan.md`,
requirement **R13**). The user's golden `mos_power_ampli_desired1.sch` shows the target:
a one-grid vertical stub `N 1360 -900 1360 -880` out of the pin before the route turns.

## 2. How to turn it on (if you want to experiment)

- **Menu:** Options → **"Keep stub out of moved pins (exit stub)"** (a checkbutton).
- **Script / command box:** `set wire_exit_stub 1`
- It is a plain Tcl global (default `0`, set in `xschem.tcl`), read on the C side via
  `tclgetboolvar("wire_exit_stub")`. It is saved/restored with the other preferences
  (it is in `tctx::global_list`).

It only has any effect together with the rest of the rubber-band machinery — i.e. during
a **stretch** move with **orthogonal wiring** on (e.g. after loading `cadence_style_rc`,
which sets `cadence_compat`, `enable_stretch`, `orthogonal_wiring`).

## 3. How it works (current mechanism)

The pass lives in `insert_exit_stubs()` in `src/move.c` and runs at the **end** of
`move_objects()`, gated:

```c
if(xctx->stretch_select && tclgetboolvar("wire_exit_stub") && orthogonal_wiring &&
   xctx->move_rot == 0 && xctx->move_flip == 0) {
  insert_exit_stubs();
}
```

It runs **after** the Phase-5 cleanup (`trim_wires()` / `remove_move_orphan_wires()`) so
the stub it inserts is never merged back. For each **moving** instance pin that carries
**exactly one** attached wire (the route's "first leg"):

1. **Exit normal** = the dominant axis of `(pin − symbol-bbox-centre)`. E.g. `res.sym`
   pin `M` sits at the top of a `+y` lead, so it exits vertically (`+y`).
2. If the first leg already runs **along** that normal (a straight exit), leave it alone
   — a colinear stub would just be re-merged, and a straight exit can't cross the body.
3. If the first leg runs **perpendicular** to the normal (it bends right at the pin),
   **slide** that leg one minor grid (`cadsnap`) out along the normal — dragging its far
   endpoint and every wire endpoint at that corner the same grid so it stays Manhattan
   and connected — and fill the gap at the pin with the short **exit stub**.

Guards mirror `compute_wire_slide()`: never pull a leg's far end off a *fixed* pin; only
act where the far end meets another wire (a real corner). The net is unchanged
(electrically identical, netlist-safe), and one undo restores the prior geometry.

## 4. Why it is currently *worse* on real schematics

`TC10` (a single 2-pin `res.sym` with a clean L-route) goes green, but a real schematic
is denser and less uniform, and the manual eyeball was worse. The **suspected** failure
modes — to be confirmed/triaged in the redesign, not yet root-caused — are:

- **Too eager, all at once.** The pass fires on *every* qualifying moved pin
  simultaneously. On a multi-pin device that injects many new stubs + jogs in one move,
  which reads as visual noise rather than a clean exit.
- **Outward-normal heuristic is crude.** "Dominant axis of (pin − bbox centre)" can pick
  the wrong axis/sign when the symbol bbox is skewed (pin-number text, asymmetric bodies,
  pins not at clean extremes), so a stub can point the "wrong" way or into the body.
- **Single-leg-only is inconsistent.** Pins with two or more attached wires are skipped
  (`cnt != 1`), so on the same device some pins sprout a stub and some don't — uneven.
- **The re-jog cascade can fight the route.** Sliding the first leg + dragging the corner
  can interact with the Phase-4 corner-slide and Phase-5 cleanup to produce a double-jog
  or a stub that overlaps neighbouring routing on a busy sheet.
- **Stub length is a guess.** One `cadsnap` may be too short/long depending on the
  schematic's grid and pin pitch.

The common thread: the rule was validated on one synthetic, uniform case; real symbols
and real routing violate the assumptions it quietly makes.

## 5. Plan: deferred, to be redone in atomic steps

The decision (2026-06-20) is to **break the problem into smaller, atomic steps with
simpler, well-chosen examples** in a future session, rather than patch the current
all-in-one pass. Suggested decomposition for that session:

1. **Characterise the exit normal properly** — derive it from the pin's *lead* geometry
   (the symbol line touching the pin), not the bbox centroid; unit-test it across several
   real symbols (mos, res, cap, multi-pin) before touching the move path.
2. **One pin, one stub, observable** — start with a single moved pin and a single first
   leg; get the stub direction, length, and re-jog visually right on a *minimal* fixture
   that mirrors a real symbol, then a real one.
3. **Decide the multi-pin / multi-wire policy explicitly** — when *not* to add a stub
   (busy pins, short legs, against-the-body), so the result is uniform.
4. **Re-introduce behind the same switch**, re-eyeball on `mos_power_ampli`, and only
   then consider defaults.

Keep it behind `wire_exit_stub` (default OFF) throughout, so trunk behaviour is
unaffected while it bakes.

## 6. Observations from manual testing

- **2026-06-20 (`mos_power_ampli`, `wire_exit_stub=1`, fluid-editing):** overall editing
  experience judged **worse** than with the option off → feature deferred. *(Specific
  per-move observations to be added here as they are captured — they will anchor the
  atomic-step redesign.)*

## 7. References

- Spec & plan: `doc/claude/code_analysis/wire_editing_spec_and_plan.md` — Issue E, requirement R13,
  Phase 6, test case TC10.
- Test: `tests/headless/wireedit/test_wireedit_10_exit_stub.tcl` (synthetic, green).
- Implementation: `insert_exit_stubs()` in `src/move.c`; switch wiring in `src/xschem.tcl`
  (`set_ne wire_exit_stub 0`, `tctx::global_list`, Options menu entry).
- Commit: `8ba5ddf7` (Phase 6 exit-stub behind the switch).
- Related bug class write-up: `doc/claude/code_analysis/prop_dropped_on_move_tutorial.md`.
