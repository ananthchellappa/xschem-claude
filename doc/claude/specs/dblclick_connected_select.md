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

### Escalation state & reset — IMPLEMENTED as seed-driven recompute

A small state machine keyed on a **seed** (object under the double-click) + a
**level** counter (1 → ring1, 2 → ring2, 3 → whole net; capped at 3).

The interactive gesture / coordinate form **recomputes the selection from the
seed** each call: `unselect_all`, re-select the seed, grow `level` rings (or flood
to fixpoint at level 3). This is the key robustness decision — see "Interactive
reality" below: the surrounding fluid gesture leaves an unpredictable transient
selection, so growing the *live* selection incrementally is unreliable. Recompute
sidesteps it entirely; the selection at level N is a pure function of (seed, N).

**Reset to level 0 (restart)** in two cases:

1. The double-clicked object differs from the stored seed (compared by type +
   session-stable id) — checked inside `select_grow_connected_step`.
2. **ANY intervening non-double gesture** — a single click (anywhere, INCLUDING on
   the seed itself), a drag, a wire draw, etc. The next double-click on the seed then
   restarts at ring1 instead of jumping straight to whole-net.

Case 2 is the subtle one. The live selection CANNOT detect it: a plain click on the
already-selected seed leaves the selection visually unchanged (seed + ring stay
selected), and the double-click's own press re-selects the seed anyway — so neither a
selection-count check nor a seed-identity check can distinguish "continuation" from
"fresh after an intervening click." The only reliable signal is the **event stream**,
and it is read like this (all in `callback.c`):

- A button-1 **RELEASE** that is not a double-click's release2 snapshots the current
  level into `dblgrow_level_save` and **tentatively zeroes** `dblgrow_level`.
- The double-click's **`-3`** handler, right before growing, **restores**
  `dblgrow_level = dblgrow_level_save`. Reaching `-3` proves the preceding
  press/release was the *first half of a double*, not a standalone click, so its
  tentative reset is undone and escalation continues.
- A standalone single click's tentative zero is **never restored** (no `-3` follows),
  so it sticks → the next double restarts at ring1.
- `dblgrow_last_press_was_grow` (set by `-3`, cleared by every non-`-3` button-1
  press) guards the double's own **release2** — whose preceding "press" was the `-3`
  grow — from tripping the reset.

This is robust to the exact double-click event pattern. Ground truth (Tk
`event generate`): a real double fires `P1, R1, <Double>(-3), R2` — the 2nd press
emits ONLY `-3` (the specific `<Double-Button-1>` binding wins over the generic
`<ButtonPress>`), NOT a second callback-4. Because the snapshot is taken at the
*release* (not the press), the mechanism works whether or not a second press-4 is
emitted (the headless test harness injects a synthetic extra press-4; real Tk does
not — both pass). After level 3 (whole net) further double-clicks on the same seed
are no-ops.

Note the **coordinate command** `xschem select_grow_connected x y`, driven directly
(not through a press/release), still escalates on repeated same-seed calls regardless
of an `unselect_all` in between — it never rides the button event stream, so only
case 1 applies. Tests: T5 (coord survives `unselect_all`), T8 (gesture resets on
deselect / off-seed click), T9 (resets on a single click ON the seed — the
selection-invisible case), T10 (escalation + reset under the real `4,5,-3,5` stream).

The scriptable **coordless** form (`xschem select_grow_connected` with no coords)
is instead *incremental* — it grows the current selection by one ring and DOES
reset the level on an external selection change (a `sel_sig` snapshot of
`lastsel`). This is the primitive scripts/tests use.

No timing window of our own — we ride Tk's `<Double-Button-N>`; seed identity, not
a timer, drives escalation.

### Interactive reality — the fluid/pin gesture must be aborted at `-3`

With the Cadence profile (`fluid_editing=1` + `en_pin_select=1`) the **2nd press
of the double-click always arms a transient gesture BEFORE `-3` fires**: a fluid
move-grab (`STARTMOVE`, on a wire or instance body) or a pin wire-arm (`STARTWIRE`
+ `pin_pending`, on an instance pin). So `ui_state` at `-3` is almost never a bare
`0`/`SELECTION`. The trigger (below) detects these transient arms and
`abort_operation()`s them first, then recomputes+grows. It also latches
`place_click_committed` so the **release2** that follows does not run the cadence
"deselect everything but the object under the cursor" collapse (which would undo
the grow). Both were found only by driving the *full* `press,release,press,-3,
release` sequence — a bare `-3` event silently skips the whole problem, so tests
MUST drive the real sequence. Post-mortem:
[`../code_analysis/lessons_gesture_test_full_event_sequence.md`].

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

**RATIFIED path — new subcommand + `cadence_compat`-gated trigger, no registry
change.** `xschem select_grow_connected [x y]` in `scheduler.c` is the scriptable/
rebindable engine entry. IMPLEMENTED (commit 2).

**Trigger — C branch in `handle_double_click`, NOT a Tk rebind.** The plan's
Step 5 first proposed a Tcl rebind of `<Double-Button-1>`. That was rejected in
implementation: the Tk `<Double-Button-1>` binding funnels to synthetic event
`-3` which ALSO terminates in-progress draw gestures (STARTWIRE/STARTLINE/
STARTPOLYGON, `callback.c:6682-6694`); a blind Tk rebind would drop that. Instead
the branch lives inside `handle_double_click` (`callback.c:6668+`): when
`cadence_compat` and `ui_state` is idle/SELECTION, call
`select_grow_connected_step(mousex, mousey, 1)` and return; an active draw gesture
still falls through to the termination code below. This keeps the `-3` funnel's
screen→schematic conversion, `semaphore>=2`/`ui_state` guards, and gesture
termination — none of which a Tk rebind would have. Still honors O1=A: no
registry-grammar change, gated by `cadence_compat`, subcommand available for
scripting/user-rebind. No `cadence_style_rc` bind line needed (auto under
`cadence_compat`).

(Rejected alternatives: a first-class `dblclick` registry device — more C work;
a Tk `<Double-Button-1>` rebind — loses draw-gesture termination.)

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
  out of scope.) **SHIPPED SEPARATELY, 2026-08-08:** the node-name option exists on
  its own chord instead of taking over a double-click level — Ctrl+Alt+Shift+LMB /
  `xschem select_same_net`, see [select_same_net_by_label.md](select_same_net_by_label.md).
  This spec's escalation is unchanged and stays purely geometric.
- **O4 — cap at 3.** click1→ring1, click2→ring2, click3→whole net (jump,
  regardless of net size), click4+→no-op.
- **Edit Properties on double-click: given up** under the Cadence profile; `q`
  covers it (user confirmed).
