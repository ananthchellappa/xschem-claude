# Issue 0062 — toolbar and recent-component bar buttons are not logged

**Opened:** 2026-07-02
**Status:** OPEN — partially fixed 2026-07-02: toolbar EditUndo/EditRedo/Cut/Delete
now record because their C cores self-log (issue 0071 §4b). Remaining toolbar
buttons await core self-log of their subcommands.
**Severity:** HIGH — the toolbar is a primary interaction surface and drives
core mutations (save, cut/copy/paste/delete, undo/redo, trim/break wires,
netlist, place symbol/wire/…), none of which are recorded.
**Branch:** `fluid-editing`.
**Source:** user-requested full audit of unlogged user interactions.
**Affects:** `src/xschem.tcl` `toolbar_add` (:11982), `add_toolbuttons`
(:12076–12119), recent-component bar `c_toolbar` (:6025–6134), tab bar
(:12212–12220), tab context menu `tab_context_menu` (:11803).
**Related:** [[action-logging]], [[multi-window-detach]]; umbrella 0071; 0061.

---

## 1. Symptom

Clicking a main-toolbar icon (New/Open/Save, Undo/Redo, Cut/Copy/Paste/Delete,
Move/Duplicate, Insert wire/line/rect/poly/arc/text/symbol, Trim/Break wires,
Toggle colorscheme, Descend/Back, Netlist, Reload) performs the action but logs
**nothing** to the file or CIW. The recent-component palette (`c_toolbar`) places
a symbol with no log line. Tab create/switch and the tab right-click menu are
likewise unlogged (tab *detach* is the one exception, `xschem.tcl:11779`).

## 2. Root cause

`toolbar_add {name cmd …}` sets the button's `-command $cmd` **verbatim**
(`xschem.tcl:11996`) — a raw `xschem <sub>` string with no logging wrapper. The
buttons do not pass through `menu_action_logged`, `dispatch_input_action`, or any
gesture hook, and the underlying C subcommands do not self-log (0071 Part 4). The
recent-component buttons use `-command "c_toolbar::command $i"` (:6111), also
unwrapped. Gesture-*starting* buttons (Move/Insert-*) can still get an END line
if the user completes a drag on the canvas, but the button click itself records
nothing.

## 3. Scope

- **Main toolbar** (`add_toolbuttons`): FileSave, EditUndo (`xschem undo; xschem
  redraw`), EditRedo, Cut/Copy/Paste/Delete, Duplicate/Move (`copy_objects` /
  `move_objects`), Insert wire/line/rect/polygon/arc/circle/text/symbol,
  ToolJoinTrim (`trim_wires`), ToolBreak (`break_wires`), toggle_colorscheme,
  descend/descend_symbol/go_back, `netlist -erc`, reload.
- **Recent-component bar** (`c_toolbar`): places a symbol per click.
- **Tab bar / tab context menu**: new-tab, tab switch, and the counterpart-open
  pick (a `load`) are unlogged. (Navigation switches are lower priority; the
  file-open one should log like the File menu's open.)

## 4. Fix sketch

Give `toolbar_add` (and `c_toolbar::command`) the same logging wrapper the File
menu uses — route the command through `menu_action_logged`, or bind toolbar
buttons to the corresponding registered actions so `dispatch_input_action`
handles logging. The self-log-at-core option in 0071 subsumes this.
