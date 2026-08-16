# Logical (net-name) connected select — Ctrl+Alt+Shift+LMB

## Status
IMPLEMENTED, 2026-08-08. Engine `select_same_net_by_name()` in `src/select.c`,
subcommand `xschem select_same_net`, actions `select.same_net_by_label` /
`select.same_net_by_label_add`, default chord installed by `src/cadence_style_rc`.
Test: `tests/headless/test_select_same_net_by_label.tcl`.

## Motivation

The double-click grow (`select_grow_connected`,
[dblclick_connected_select.md](dblclick_connected_select.md)) walks **copper**: it
adds wire segments that geometrically touch, and stops where the wire stops. That
is the right model for "select this piece of routing", but it cannot express the
thing a designer usually means by *the net*: in a real schematic the same node is
routed as several disconnected islands tied together by **wire-labels**, and in
the SPICE netlist those islands are one node.

`dblclick_connected_select.md` left this open as **O3** ("is whole-net defined
geometrically or name-wise?") and answered it *geometrically* for the double-click.
This feature is the other answer, on its own chord, so both are available:

| | walks | reaches |
|---|---|---|
| `select_grow_connected` (LMB double-click) | copper | segments that touch |
| `select_same_net` (Ctrl+Alt+Shift+LMB) | the netlist | every segment with the same net name, touching or not |

## Behaviour

**Chord: Ctrl+Alt+Shift+LMB on a wire** (or on a net-label, or on an instance pin).
Selects, in one shot:

- every **wire segment** whose node name equals the clicked object's — including
  segments that touch nothing and are joined only through a shared wire-label;
- every **net-label / port / probe** instance that names that node
  (`IS_LABEL_SH_OR_PIN`: `label`, `ipin`, `opin`, `iopin`, `probe`-family,
  `show_label`, `bus_tap` — the same family net highlighting selects).

Devices are never selected — only wires and the symbols that *name* the net.

The chord **replaces** the selection. An additive twin
(`select.same_net_by_label_add`) ships unbound; bind it to a second chord to gather
several nets one click at a time.

### What names a net

Node names come from `prepare_netlist_structs(0)` — the same pass net highlighting
uses — so *same net* here means exactly what the netlister means. Consequences:

- **Unnamed nets do not collapse.** Each electrically distinct unnamed net gets its
  own synthetic `#netN`, so on unlabelled routing the chord degenerates to "the
  whole physical net" and never over-selects.
- **Global nets** (`VDD`, `GND`, …) select every occurrence on the sheet. That is
  the honest answer to "what is this net", and it can be a large selection.
- The chord is **sheet-local**: it selects inside the schematic you are looking at.
  It does not descend or ascend the hierarchy.

### Seed resolution

The object under the pointer is resolved in the order the user sees it:

1. an instance **pin** within the tight pin pick radius (`find_closest_pin`, the
   same test `en_pin_select` uses) → the net wired to that pin, so aiming at a
   MOSFET drain works, not just at the wire;
2. a **wire** → `wire.node`;
3. a **net-label / port / probe** instance → `node[0]`.

Anything else (device body, text, graphics, empty space) has no net: the chord
reports "no net under the pointer", changes nothing, and returns 0.

### Known limit: buses are not expanded

Matching is on the **whole node name**. A segment labelled `A[3:0]` and one
labelled `A[1]` are different names and are *not* selected together, even though
the netlist shorts `A[1]` into the bus. Highlighting does expand bus notation
(`bus_hilight_hash_lookup`); doing the same here would mean either mutating the
highlight tables as a side effect of a selection, or duplicating the expander.
Whole-name matching is also what "same wire-label" means to the user, so this is a
deliberate stop, not an oversight. If bus-aware selection is wanted later, the
place to add it is `select_objects_on_net()` in `src/select.c`.

## Bindings

The chord is **data-driven and remappable** — it is a row in the C input-binding
table, not a hard-coded branch:

```tcl
# what src/cadence_style_rc installs
xschem bind button 1 ctrl+alt+shift canvas select.same_net_by_label
# move it elsewhere / drop it
xschem bind   button 2 ctrl+shift      canvas select.same_net_by_label
xschem unbind button 1 ctrl+alt+shift  canvas
# the additive twin (ships unbound)
xschem bind button 2 ctrl+alt+shift canvas select.same_net_by_label_add
```

Notes on the chord itself:

- **Alt+LMB is already "unselect at pointer"** (`SET_MODMASK` in
  `handle_button_press`). The binding table is consulted *before* that branch, so
  the bound chord wins; un-bind it and Ctrl+Alt+Shift+LMB falls back to unselect.
- Some window managers grab **Alt+LMB** for window-drag. Ctrl+Alt+Shift+LMB is
  rarely grabbed, but if the click never reaches the canvas that is the first thing
  to check — rebind to a free chord.
- Caps Lock / Num Lock do not matter: `callback()` strips `LockMask` and
  `Mod2Mask` from every event before dispatch.
- The chord is skipped while a wire/line/polygon/rect/arc draw is in flight (the
  `!excl` guard shared with every other button chord).

## Scripting

```
xschem select_same_net [x y] [add]     -> number of objects selected
```

- with `x y`: the object at that schematic coordinate is the seed;
- without coords: **every** wire / net-label in the current selection seeds a net,
  and all of those nets are selected in full (this is the form the command palette
  entry runs);
- `add` keeps the existing selection instead of replacing it.

## Logging

Both sinks, on every use — the interactive chord included:

- the **action log file** gets a replayable command line
  `xschem select_same_net <x> <y>` (grid-snapped coordinates), followed by a
  source-able outcome comment
  `#= select_same_net: net NET1 -- 2 wire segments, 2 label/pins selected`;
- the **CIW pane** gets both lines too (the command via `log_action`'s mirror, the
  outcome via `ciw_echo`).

A click that finds no net writes the report but **no** command line — a no-op must
not leave a replayable phantom (same rule as `select_grow_connected_step`).

Logging happens at the **core**, inside `select_same_net_by_name()`, not at the
scheduler branch: the bound chord calls the core directly from `callback.c` and
would otherwise be silent. This is the recurring issue-0071 shape — *the logged
unit is the command string but the shared unit is the C function* — see
`../code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md`. The two
`actions.csv` rows are therefore marked `nolog`, so `dispatch_input_action`'s
Layer A line cannot double up, and the scheduler branch does not log either.

**Invariant:** exactly one command line and one outcome line per action. Test T9
holds it for both entry paths.

## Code map

| what | where |
|---|---|
| engine + self-log | `src/select.c` — `select_same_net_by_name()`, helpers `net_name_at()`, `select_objects_on_net()`, `select_net_report()` |
| subcommand | `src/scheduler.c` — `select_same_net` branch |
| actions + chord dispatch | `src/callback.c` — `act_select_same_net`, `act_select_same_net_add`, `action_registry[]` |
| metadata (palette, cheat-sheet) | `src/actions.csv` — `select.same_net_by_label*` |
| default chord | `src/cadence_style_rc` |
| test | `tests/headless/test_select_same_net_by_label.tcl` |
