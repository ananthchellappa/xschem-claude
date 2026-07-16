# Issue 0079 — fluid reroute follow-set wires render as genuine user selection on plain click

**Opened:** 2026-07-06
**Status:** OPEN — design/UX. Behavior is intentional at the mechanism level but the
*visual* was expected to be addressed and is not.
**Affects:** interactive use with `fluid_editing` on, plain (no-modifier) LMB
click-drag of an instance that has attached wires.
**Severity:** low — cosmetic/UX; connectivity and netlist are correct.
**Branch:** `fluid-editing`.
**Related:** [[nice-drag-rerouting]]; [[fluid-editing-tip-grab]]; issue 0015 (the
drag-toward shove gap); `select_attached_nets` in `select.c`; the transient
auto-deselect in `move.c`.

---

## 1. Observed (real-window feel test)

Launched `src/xschem --script src/cadence_style_rc --logdir /tmp`, opened
`tests/from_user/before_1.sch`, clicked-and-held LMB on **R18**.

The two wires attached to R18's **P** and **M** pins *immediately* render in the grey
selection color on LMB-press — before any motion — **as if they are part of the
selection**, even though the user only clicked the instance.

Expectation was that the auto-grabbed reroute follow-set would **not** present as
user selection (either not shown, or shown in a distinct "auto-grabbed / will-be-
rerouted" cue), so the user can tell what they actually selected (the instance) from
what the tool grabbed on their behalf (the wires).

## 2. Why it happens (verified)

The follow-set wires are **genuinely selected**, not merely drawn in a selected-like
color:

- Plain-drag path calls `select_attached_nets()` (`src/select.c:1504`). For each
  moving-instance pin it partial-selects any unselected wire whose endpoint is
  `endpoint_near()` (tol `cadsnap/2`) the pin, via `select_wire(i, SELECTED1/2)`
  (`src/select.c:1546`, `:1549`).
- `select_wire` sets `xctx->wire[i].sel` (`src/select.c:966-969`) and pushes the
  wire into `sel_array` — real selection state.
- They paint grey because that state is drawn in the standard selection color
  `SELLAYER` (`src/xschem.h:164`), first at grab time via
  `drawtempline(gc[SELLAYER])` (`src/select.c:975`), then as the move rubber-band.

The **only** fluid-specific additions today are:
1. The *trigger* — `select_attached_nets()` now fires on a plain no-modifier drag
   (`src/callback.c:6061-6064`, `:6079-6080`); stock xschem grabbed attached nets
   only under Ctrl / `enable_stretch`.
2. A *transient auto-deselect at move END* — when the user had selected no wires of
   their own (`fluid_startsel_wires==0`, captured `src/select.c:1523-1524`), the
   auto-grabbed wires are force-deselected on release (`src/move.c:3044-3051`) so
   they don't persist as selection *after* the gesture.

So the wires are transient *after* release, but *during* the whole grab+drag they
carry — and display as — real selection.

## 3. Desired

Distinguish the tool-owned reroute follow-set from user selection **during** the
gesture. Options (decision open):

- **A. Distinct cue.** Draw the auto-grabbed follow wires in a dedicated
  follow-set style (e.g. a different color/dash) rather than `SELLAYER`, so they
  read as "riding along," not "selected."
- **B. No highlight until motion.** Don't color them on bare LMB-press; only show
  the reroute preview once the drag actually starts moving them.
- **C. Keep as-is, accept it.** They *are* being manipulated, so selection color is
  arguably honest; the transient auto-deselect already prevents lasting confusion.

Preference leans A or B (matches the expectation that a plain click selects only
what was clicked). Needs the tool-owned-follow-set concept (Phase I ownership) to
carry its own render style rather than reusing the selection funnel.

## 4. Repro

1. `src/xschem --script src/cadence_style_rc --logdir /tmp`
2. Open `tests/from_user/before_1.sch`, ensure `fluid_editing` on.
3. LMB-press (hold, no move) on R18.
4. Observe: P-pin and M-pin wires turn grey (selected) instantly.
