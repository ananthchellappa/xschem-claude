# Cadence-style double-click incremental connected-selection

## Status
SPEC / DESIGN — not implemented. Branch `fluid-editing`. Written 2026-07-12.
Design decisions RATIFIED 2026-07-12 (see "Ratified decisions" below). Companion
plan: `../suggestions/plan_dblclick_connected_select.md`.

**Ratified:** trigger via Tcl rebind + subcommand (not the registry); rings are
**wires-only**; 3rd click = **geometric** whole-net flood; escalation **capped at
3** clicks; LMB double-click **gives up Edit Properties** under the Cadence
profile (`q` opens properties instead — user confirmed sufficient).

## Motivation

Virtuoso lets you double-click an object to **grow the selection outward along
connectivity**, one ring of connected wire segments per double-click, until the
whole net is selected. xschem has all the connectivity machinery
(`select_connected_nets`) but exposes it only as a one-shot (Ctrl-RMB /
Shift-RMB / `xschem connected_nets`). There is no incremental, click-to-grow
gesture.

## Target behavior

Trigger: **double-click** on a schematic object (default gesture = LMB
double-click; see §"Trigger & bindability"). Successive double-clicks on the
**same seed** escalate:

| Click | On a wire | On a pin / net-label / instance |
|---|---|---|
| **1st** | select the wire **+ its immediately adjacent connected wire segments** (one ring). If the wire was not selected, this first double-click both selects it and grows the ring — identical to the result had it been pre-selected. | select the object **+ the wire segments immediately touching its pins/anchor** (one ring). |
| **2nd** | for **each** wire segment selected by click 1, add **its** immediately adjacent wire segments (ring 2). | same — ring 2 from the ring-1 set. |
| **3rd** | **select all** connected wire segments (whole net). | same. |

- A single (non-double) click anywhere behaves exactly as today (plain select /
  deselect). Double-click is purely additive to the selection.
- "Immediately adjacent" = geometric endpoint/junction adjacency between wire
  segments (the split inter-attachment `xWire` records), **not** node-name
  equivalence. Two physically-separate wires with the same net name are NOT one
  ring apart; they are only unified by the 3rd (whole-net) click if that click is
  defined name-wise (see Open question O3).

### Escalation state & reset

The gesture is a small state machine keyed on a **seed** (the object under the
first double-click) and a **level** counter (0 → ring1, 1 → ring2, 2 → all).
Reset level to 0 (start a fresh escalation) when:

1. the double-clicked object differs from the stored seed, OR
2. the stored seed is no longer selected (selection was cleared/changed by any
   other action), OR
3. the current selection was mutated by anything other than this grower since the
   last double-click (tracked via a selection-generation stamp).

After the 3rd click (whole net) further double-clicks on the same seed are no-ops
(already fully selected).

There is **no timing window** of our own — we ride Tk's `<Double-Button-N>`
detector. "Same seed" identity, not a timer, drives escalation, so a slow
sequence of double-clicks on the same object still escalates correctly.

## Trigger & bindability

Double-click is **not** expressible in today's `xschem bind` registry (grammar =
`wheel|button|key` + code + mods + ctx + action; no click-count dimension —
`InputBinding` at `callback.c:3407`, parsers `callback.c:3759-3803`). It is
hardwired: Tk `<Double-Button-1/2/3>` → `xschem callback %W -3 …`
(`xschem.tcl:13488-13490`) → C `case -3` → `handle_double_click()`
(`callback.c:7021`, `6659`), bypassing the registry.

Today LMB double-click already = **Edit Properties** (`edit_property(0)`,
`callback.c:6679`). `handle_double_click()` already receives `cadence_compat`
(`callback.c:6659` / call site `7021`) — the natural gate.

**RATIFIED path — Tcl rebind + new subcommand.** Add `xschem
select_grow_connected <x> <y>` in `scheduler.c`; the shipped `cadence_style_rc`
rebinds `<Double-Button-1>` to it. No registry-grammar change. Trade-offs
accepted: not `bindings dump`-visible, and the Tk `<Double-Button-1>` binding must
be reapplied at every `set_bindings` site (`xinit.c:3512,1938,2154`) — fold the
rebind into `set_bindings` (`xschem.tcl:13441`) so all windows (main / new /
detached) inherit it.

(Rejected alternative: a first-class `dblclick` registry device — more C work,
not needed for this feature.)

### Default binding
- `cadence_compat=1`: LMB double-click = connected-grow. **Edit Properties on
  double-click is deliberately given up** — reached via `q` instead (user
  confirmed sufficient).
- `cadence_compat=0`: LMB double-click unchanged (= Edit Properties). The
  `select_grow_connected` subcommand still exists; a user may bind it to any Tk
  event (e.g. `<Double-Button-2>`, a free no-op slot today —
  `handle_double_click` acts only on Button1).

## Reused infrastructure (do not reinvent)

- **One-ring grow:** `select_connected_nets(2)` — direct neighbors, no recursion
  (`select.c:93`, core guard `check_connected_nets` `&2` at `select.c:63`). Already
  Tcl-exposed: `xschem connected_nets 2` (`scheduler.c:1232`).
- **Whole net:** `select_connected_nets(0)` — full geometric flood.
- **Seed pick:** `select_object(mx,my,SELECTED,override_lock,NULL)` (`select.c:1440`)
  / `xschem select_at` (`scheduler.c:8022`).
- **Selection model:** per-object `.sel` flag + `xctx->sel_array` rebuilt by
  `rebuild_selected_array()` under `need_reb_sel_arr` (`move.c:53`). Any `.sel`
  flip must set the dirty flag — the `select_*` primitives already do.
- **Silent compute (for flicker-free multi-ring draw):** `select_wire` `fast`
  bit2 = nodraw (`select.c:1020`); `select_attached_nodraw` (`xschem.h:1306`).
- **Wire-segment model:** each clickable inter-attachment region is a distinct
  `xWire` (split by `break_wires_at_attach_points`, `check.c:693`); "one ring" =
  the set of `xWire` records whose endpoints touch the current selection. Read
  `doc/claude/specs/wire_segment_splitting.md` and `doc/claude/WIRING.md` before
  touching this.

### Wires-only rings (RATIFIED) — needs a thin variant
`check_connected_nets(&2, …)` also auto-selects touching pin/label/probe
**instances** and always hard-marks `SELECTED` (`select.c:46-87`), so it is NOT
reusable verbatim. Rings must grow **wire segments only**: a thin wires-only ring
routine (non-recursive bucket walk over `wire_spatial_table` +
`touch()`/`endpoint_near`, marking with `select_wire`, no instance inclusion). The
seed object of any type stays selected; growth never pulls in other devices.

## Non-goals
- No change to single-click selection, drag, or any non-double-click gesture.
- No change under `cadence_compat=0` unless the user explicitly binds the new
  action.
- Not touching netlist / hierarchy traversal — this is pure in-sheet geometric
  selection.

## Ratified decisions (2026-07-12)
- **O1 — bindability path: A (Tcl rebind + subcommand).** New `xschem
  select_grow_connected`; `cadence_style_rc` rebinds `<Double-Button-1>`. No
  registry-grammar change.
- **O2 — ring contents: wires-only.** Rings add only wire segments; seed of any
  type stays selected; no other devices pulled in. Needs the thin wires-only ring
  variant.
- **O3 — 3rd click: geometric flood** (`select_connected_nets(0)`) — physically
  touching only, same model as rings 1–2. (Node-name net = possible later option,
  out of scope.)
- **O4 — cap at 3.** click1→ring1, click2→ring2, click3→whole net (jump,
  regardless of net size), click4+→no-op.
- **Edit Properties on double-click: given up** under the Cadence profile; `q`
  covers it (user confirmed).
