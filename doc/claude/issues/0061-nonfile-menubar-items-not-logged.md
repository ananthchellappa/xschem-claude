# Issue 0061 — non-File menubar items are not logged to the action log / CIW

**Opened:** 2026-07-02
**Status:** OPEN — partially fixed 2026-07-02: `cut`/`delete`/`undo`/`redo` now
self-log at their C core (issue 0071 §4b), so Edit-menu Cut/Delete/Undo/Redo are
covered. Remaining menu mutators await the same one-line core self-log pass.
**Severity:** HIGH — largest single coverage hole. Many are genuine schematic
mutations (cut/delete/undo/redo, flip/rotate, wire surgery, symbol generators),
so replay/CIW records the session incompletely.
**Branch:** `fluid-editing`.
**Source:** user-requested full audit of unlogged user interactions.
**Affects:** `src/xschem.tcl` `build_widgets` (~:13313–13930, every non-File menu).
**Related:** [[action-logging]], spec `doc/claude/specs/action_logging.md`;
umbrella index issue 0071. See also 0066 (Options/`set`), 0063 (property dialogs).

---

## 1. Symptom

Picking almost anything from the **Edit, View, Tools, Symbol, Highlight,
Simulation, Properties, Options** menus performs the action but writes **no line**
to the action log and mirrors nothing to the CIW. Only the **File** menu is
covered.

## 2. Root cause

The File menu is built by `build_menu_from_table` (`src/action_registry.tcl:106`),
which wraps every non-`nolog` command in `menu_action_logged`
(`src/action_registry.tcl:190`) so it always logs. **Every other menu is
hand-written in `build_widgets`** with a bare `-command "xschem <sub>"` (e.g.
`add command -label "Cut" -command "xschem cut"`, `xschem.tcl:13516`). Those
picks log only if the underlying C subcommand self-logs — and almost none do
(see 0071 Part 4). So the entire non-File menu bar bypasses logging.

## 3. Scope — unlogged state-mutating menu items (handlers in `src/xschem.tcl`)

Genuine schematic/symbol mutations (highest value):
- **Edit:** Cut (13516), Delete (13518), Undo (13513), Redo (13514),
  Horizontal/Vertical Flip in place (13527/13529), Rotate in place (13531),
  Flip/Flipv/Rotate selected (13533/13535/13537).
- **Properties:** Edit (13666 `edit_prop`), Edit with editor (13667
  `edit_vi_prop`), Toggle *_ignore (13669), Change insertion order (13671),
  Edit header/license (13673), Edit file (13675). (Commit-side detail in 0063.)
- **Tools:** Align to grid (13785), Join/Trim wires (13787), Break wires ×4
  (13789/13791/13793/13795).
- **Symbol:** Add pin stubs+labels (13718), Make symbol from schematic (13725),
  Make schematic from symbol (13727), Make sch+sym from selected (13729),
  Attach net labels (13731), Create symbol pins from sch pins (13733), Floaters
  from selected inst (13745), Create labels/pins from highlight nets
  (13758/13760/13762).
- **Highlight:** Rename duplicate instance names (13824 `check_unique_names 1`).
- **Simulation / Waves:** Annotate operating point (13926 / 13571 `annotate_op`).
- **Menubar:** Netlist (13555 `xschem netlist -erc`) — export, unlogged.

Placement items that DO mutate but log only a non-replayable `# place symbol pin`
stub (cross-ref 0069): net-label ports / net & wire labels (13737–13743
`net_label`), Place symbol pin (13735), Insert image (13781), Add waveform graph
(13920).

Config/view changes in these menus are covered by issue 0066 (the `xschem set`
family) — not repeated here.

## 4. Fix sketch

Preferred: migrate the non-File menus to `build_menu_from_table` / the action
registry so `menu_action_logged` wraps them uniformly (matches the File-menu
model and reuses the csv `nolog` column for the handful that must stay silent).
Cheaper interim: route each inline `-command` through `menu_action_logged`.
Deepest fix (covers menus **and** toolbars/keys at once): make the mutating C
subcommands self-log with a replay guard — see umbrella 0071.
