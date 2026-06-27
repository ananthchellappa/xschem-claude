# Wish-list implementation plan

Source: `doc/claude/specs/wish_list.txt`. This doc gives, for **every open item**, a concrete
implementation sketch, an **ease-of-implementation** rating, and a **recommended
position in the change cycle** (Early / Mid / Late) with the reasoning about what
should land first.

Nothing here touches build-tracked code yet — it is a map for sequencing the work.

---

## Status snapshot

**Already DONE** (per the list): #4 right-drag zoom, #6 yellow-dot cursor,
#7 snap cursor, #14 orthogonal wire routing, #24 symbol-from-rectangle,
#27 xschemrc line-number errors, #28 run-from-anywhere.

**Two efforts already in flight that the rest of the list should be sequenced around:**

1. **Action registry** (`src/actions.csv`, `src/action_registry.tcl`) — a single
   declarative table that already projects into menus, a command palette, the key
   bindings, and a generated cheat-sheet. *Directly carries items #3, #5, #15, #22,
   and the discoverability half of #18.*
2. **Stable object handles** (current branch `feature/stable-object-handles`) — a
   funnel + session-stable id for objects, queryable from Tcl. Wires are done;
   instances are next. *Directly carries items #21, #26, and de-risks #1, #16, #25.*

The single most useful sequencing rule: **let those two foundations advance first**,
because they convert a dozen "hard, scattered" wish-list items into "small projections
of an existing mechanism."

---

## At-a-glance table

| # | Item | Ease | When | Gated by |
|---|------|------|------|----------|
| 23 | Outline rectangles — fix UX | Easy | **Early** | — |
| 8 | Crossing/enclosing selection toggle | Easy | **Early** | — |
| 11 | Re-place most-recent cell without browser | Easy | **Early** | — |
| 12 | Stay in instance-create to place more | Easy–Mod | **Early** | #11 |
| 10 | Descend without forcing a save | Easy–Mod | **Early** | — |
| 9 | Keep selection after command abort | Moderate | **Early–Mid** | — |
| 17 | Save changed settings to defaults | Moderate | **Early–Mid** | — |
| 21 | TCL access to any object's properties | Moderate | **Mid** | handles (in flight) |
| 15 | Flexible TCL key bindings | Mod (started) | **Mid** | action registry |
| 22 | Net highlighting + bindkey | Easy–Mod | **Mid** | #15 |
| 13 | Command prompt on status bar | Moderate | **Mid** | — (pairs with #5) |
| 5 | Command interpreter window | Moderate | **Mid** | #3 |
| 3 | Log user interactions → macros | Mod (started) | **Mid** | action registry |
| 26 | car(geGetSelSet()) / o~>prop model | Moderate | **Mid–Late** | #21, handles |
| 2 | Cadence-style property forms | Moderate | **Mid–Late** | #21 helps |
| 20 | Better multiple-window support | Mod–Hard | **Mid–Late** | — |
| 18 | Always-visible library manager | Mod–Hard | **Late** | #19 helps |
| 1 | Fluid drag-move keeping connections | Hard | **Late** | handles, #25 |
| 25 | Click-drag rectangle/polygon edge | Moderate | **Late** | shares stretch infra w/ #1 |
| 16 | Wire-label as a fundamental object | Hard | **Late** | format-version bump |
| 19 | Dir-per-cell library structure | Very Hard | **Late** | format/library overhaul |

---

## Early — low risk, high daily-use payoff, no dependencies

These are mostly self-contained and make the tool feel better immediately. Do them
first to build momentum and because none of them block (or are blocked by) the bigger
refactors.

### #23 — Outline rectangles: fix the UX
- **What:** the feature exists; the request is purely to make it usable.
- **Where:** `draw.c` rectangle fill/outline handling; the rectangle creation path in
  `actions.c`; the layer/fill attribute UI in `xschem.tcl`.
- **Plan:** reproduce the current behavior, identify the specific UX friction (likely
  the fill-vs-outline attribute being hard to set or not previewed), expose it as a
  clear toggle on the rectangle property form / layer controls.
- **Ease:** Easy. **When:** Early — no dependencies, good warm-up.

### #8 — Crossing vs enclosing selection toggle
- **What:** rubber-band select should optionally include only fully-enclosed objects
  (enclosing) vs anything it touches (crossing).
- **Where:** `select.c` already has **both** behaviors: `select_inside()` (enclosing,
  `RECT_INSIDE`) and `select_touch()` (crossing, `lineclip`/`RECT_TOUCH`). The work is
  a *mode selector*, not new geometry.
- **Plan:** add a Tcl preference var (mirror in `xctx`, see `MIRRORED IN TCL`), route
  the rubber-band-end in `callback.c` to `select_inside` or `select_touch` based on it.
  Cadence convention: left-to-right drag = enclosing, right-to-left = crossing — derive
  direction from drag dx sign for zero extra UI. Add a menu/pref toggle as well.
- **Ease:** Easy. **When:** Early.

### #11 — Re-place the most-recently-placed cell without the browser
- **What:** "create instance" should default to the last symbol instead of always
  opening the file dialog.
- **Where:** `place_symbol()` in `actions.c` (NULL symbol_name → `load_file_dialog`).
- **Plan:** remember the last successfully placed symbol path in `xctx` (or a Tcl var).
  Add a command/keybinding that calls `place_symbol(last_symbol)` directly; keep the
  browser on a separate binding. Trivial state + one new branch.
- **Ease:** Easy. **When:** Early. Natural pairing with #12.

### #12 — After placing, stay in instance-create for more of the same cell
- **What:** repeated placement without re-invoking the command.
- **Where:** the `PLACE_SYMBOL` ui_state and the `move_objects(END)` transition in
  `actions.c` / `callback.c`.
- **Plan:** on placement-commit, instead of dropping to idle, re-enter placement of the
  same symbol (loop until Esc/right-click). Reuses #11's "last symbol" state.
- **Ease:** Easy–Moderate (modal-state care). **When:** Early, right after #11.

### #10 — Descend without forcing the current schematic to be saved
- **What:** remove the mandatory save gate on descend.
- **Where:** the descend path in `scheduler.c` / `actions.c` (hierarchy push, `sch[]`
  stack); find the "must save first" guard.
- **Plan:** allow descend with unsaved changes (the in-memory model is already the
  source of truth and tabs keep each file's `xctx` resident). Keep a modified-flag so
  ascend/close still warns. Verify undo and netlist paths don't assume on-disk state.
- **Ease:** Easy–Moderate (need to confirm nothing downstream re-reads from disk).
  **When:** Early.

### #9 — Keep the selected set selected when a command is aborted
- **What:** Esc-ing a command shouldn't clear the selection.
- **Where:** the abort/`ui_state` reset paths in `callback.c` and `select.c`
  (`unselect_all`, `rebuild_selected_array`).
- **Plan:** audit which abort paths call `unselect_all()` unconditionally; preserve the
  selection across pure-abort transitions, clearing only when the operation genuinely
  consumed/destroyed the selection. Needs care to not leak a stale `sel_array`.
- **Ease:** Moderate (many call sites; easy to half-fix). **When:** Early–Mid.

### #17 — Menu item + TCL command to save changed settings as defaults
- **What:** persist current preferences so they survive relaunch.
- **Where:** today `create_user_xschemrc()` only *copies* a template; `save_sim_defaults`
  shows the pattern for writing `simrc`. No general write-back exists.
- **Plan:** enumerate the user-facing preference Tcl vars (grid/snap/colors/netlist
  type/…), add `save_preferences` that writes them to `${USER_CONF_DIR}/xschemrc` (or a
  sourced `prefsrc`) as `set var value` lines, with a marked auto-generated block so
  hand edits are preserved. Add a File/Options menu entry + `xschem` subcommand.
- **Ease:** Moderate (the work is *curating which vars* and round-trip safety, not the
  file I/O). **When:** Early–Mid. Independent.

---

## Mid — build on the two foundations

### #21 — TCL access to properties of *any* object (wire/label/pin/wire/instance)
- **What:** uniform read/write of object attributes from Tcl.
- **Where:** `scheduler.c` already has `getprop`/`setprop` for `instance`,
  `instance_pin`, `wire`, `text` and `instance_net`; coverage is uneven across types.
- **Plan:** this is **exactly the stable-handles trajectory** — once instances get the
  same funnel+id treatment wires just got, layer a consistent
  `xschem object <id> get/set <attr>` over the per-type getprop branches. Fill the gaps
  (lines, rects, polys, arcs) so every type answers the same verbs.
- **Ease:** Moderate. **When:** Mid — ride the handles work rather than duplicating it.
- **Depends on:** stable handles (in flight); enables #26 and #2.

### #15 — Flexible TCL key bindings for built-in + user commands
- **What:** user-chosen key combos for any command.
- **Status:** **already started.** The action registry makes shortcuts data
  (`accel` column) and proves end-to-end remap (`remap_action_accel`); a migrated
  allowlist owns specific keys above the C dispatcher.
- **Plan:** continue widening the migrated allowlist in verified batches; add the
  customize-shortcuts dialog (engine exists, only UI remains); let user-defined Tcl
  procs be first-class action rows so they can be bound too.
- **Ease:** Moderate, and de-risked by existing infra. **When:** Mid.
- **Depends on:** action registry (in flight). Enables #22.

### #22 — Improved net highlighting + bindkey support
- **What:** the highlighting is already good; add key-binding hooks and polish.
- **Where:** `hilight.c`, `findnet.c`, `node_hash.c`; bindings via the action table.
- **Plan:** expose highlight/unhighlight/cycle-net as action rows so #15 can bind them;
  small UX additions (highlight-all-of-net, clear-all). Mostly wiring existing C verbs
  into the registry.
- **Ease:** Easy–Moderate. **When:** Mid, right after #15.

### #13 — Display current command prompt on the status bar
- **What:** e.g. "Enter first point of wire segment."
- **Where:** the status bar is `.statusbar.*` widgets in `xinit.c`/`xschem.tcl`,
  currently bound to passive vars; no per-command prompt channel exists.
- **Plan:** add a `xctx` prompt string + `xschem set prompt "..."` (or a dedicated
  status var), set it at each `ui_state` transition in `callback.c`. The cost is
  *enumerating the states and writing the strings*, not the plumbing.
- **Ease:** Moderate. **When:** Mid. Natural to build together with #5 (same message
  channel).

### #5 — Command interpreter window (log + command entry pane)
- **What:** a Cadence CIW: scrolling log of commands/messages + a command entry line.
- **Where:** new Tk toplevel in `xschem.tcl`; the entry evals through the existing
  `xschem`/Tcl command surface; the log is fed by the same message channel as #13.
- **Plan:** (1) a transcript text widget that captures `xschem get infowindow_text`
  output and command echoes; (2) an entry that runs Tcl and prints results; (3) once
  #3's logging exists, the transcript *is* the action log rendered live.
- **Ease:** Moderate (straight Tk). **When:** Mid.
- **Depends on:** best after #3 so the log content is real; pairs with #13.

### #3 — Logging of all user interactions → macros / scripts
- **What:** record interactions to a replayable log enabling macro creation.
- **Status:** **substantially planned/started** — see `plan_action_logging.md` and the
  phase-3d logging plans; the action registry already gives each action a stable id.
- **Plan:** emit a structured record (`action_id` + args) at the action-dispatch seam
  for registry-driven actions; extend to the still-in-C modal operations as those
  migrate. The **stable object handles** matter here: a replayable log must reference
  objects by *id*, not array index (indices are already unstable) — so log/replay-by-handle
  (noted as step-2 option (d) in the handles plan) is the robust target.
- **Ease:** Moderate, and partly built. **When:** Mid.
- **Depends on:** action registry (id-per-action) and, for robust replay, object handles.
  Feeds #5.

---

## Mid–Late — bigger surface, want a foundation under them

### #26 — `car(geGetSelSet())` then `o~>prop` selection-object model
- **What:** SKILL-like model where the selection is a list of object handles you can
  introspect and walk.
- **Where:** selection lives in `sel_array` (`select.c`); today only partial
  per-type access. This is the **named step-2 payoff** of the handles work
  ("selection-as-ids, net-as-object").
- **Plan:** expose `xschem selected` → list of stable object ids; make #21's
  `xschem object <id> get <attr>` the `~>` analogue. Then `car(...)`/iteration is pure
  Tcl over the id list.
- **Ease:** Moderate, *given* #21 + handles. **When:** Mid–Late.
- **Depends on:** #21, stable handles (instances done).

### #2 — Cadence-style property forms (professional look)
- **What:** restyled, consistent property/attribute dialogs.
- **Where:** the property editing dialogs in `xschem.tcl` (`editprop.c` on the C side
  supplies data).
- **Plan:** a reusable Tk form builder (labeled grid, type-aware fields, OK/Apply/
  Cancel, validation). #21's uniform property API makes the form *data-driven* (build
  fields from the object's attribute set) instead of hand-coding each dialog.
- **Ease:** Moderate (UI polish + breadth across object types). **When:** Mid–Late.
- **Depends on:** #21 makes it much cheaper; can start standalone.

### #20 — Better support for multiple windows
- **What:** File→Open should be able to open into a *new* window, not reuse the current.
- **Where:** tabs/windows already exist (`get_save_xctx`, `switch_tab`,
  `create_new_tab`, `tabbed_interface`); each file already has its own `xctx`.
- **Plan:** the infrastructure is largely present — the gap is the open-flow policy.
  Add "open in new window/tab" choices, fix focus/geometry handling, ensure menu/state
  follows the active window. Risk is in window-lifecycle edge cases, not new architecture.
- **Ease:** Moderate–Hard (lifecycle/focus bugs). **When:** Mid–Late.

---

## Late — large, invasive, or best done on top of everything else

### #18 — Cadence-style library manager (always visible)
- **What:** a persistent library/cell browser, not just the place-time file dialog.
- **Where:** today symbol selection delegates to a system file dialog
  (`load_file_dialog`); there is no resident browser widget.
- **Plan:** a dockable Tk tree over the `XSCHEM_LIBRARY_PATH`, with place-on-click and
  search; reuse the action-registry projection idea for its commands. Significantly
  nicer if #19's structured library exists, but workable on the flat layout.
- **Ease:** Moderate–Hard (new persistent UI + path model). **When:** Late.
- **Synergy:** #19.

### #1 — Fluid click-and-drag to move objects while maintaining wire connections
- **What:** smooth drag of an instance with rubber-banding wires staying connected.
- **Where:** `move.c` already has the bones — `move_objects(RUBBER)`,
  `place_moved_wire()` (Manhattan auto-legs), and the `kissing` connect-on-proximity
  flag. The wish is to make it *continuous and connection-preserving*, Cadence-style.
- **Plan:** drive the rubber update live during motion (not just at endpoints),
  auto-include attached wire endpoints in the stretch set, and keep electrical
  connectivity via the kissing/rebuild path. **Object handles make this safer**: track
  the moved object and its attached segments by id so the live rebuild can't grab the
  wrong array slot mid-drag.
- **Ease:** Hard (the most delicate interactive code, perf-sensitive). **When:** Late.
- **Depends on:** stable handles (instances + wires); shares stretch infra with #25.

### #25 — Click and drag for a rectangle or polygon edge
- **What:** grab and stretch an individual edge/vertex of a rect or polygon.
- **Where:** `select.c` stretch mode already marks endpoints (SELECTED1/SELECTED2) for
  wires/lines/arcs; `move.c` moves them. Polygons/rects need the same vertex-level
  stretch.
- **Plan:** extend stretch hit-testing to poly vertices and rect corners/edges, then
  reuse the `move_objects` stretch path. Self-contained but fiddly geometry.
- **Ease:** Moderate. **When:** Late — best built alongside #1 since both extend the
  stretch machinery.

### #16 — Make wire-label a fundamental object (like wire/text)
- **What:** net labels as a primitive object type, not instances of `lab_*.sym`.
- **Where:** labels are currently **instances** of `lab_pin.sym`/`lab_wire.sym`
  (`actions.c` placement; `xschem_library/devices/lab_*.sym`); netlisting reads them as
  components.
- **Plan:** a large change — a new object array + struct (cf. `xText`/`xWire` in
  `xschem.h`), `save.c` record type, `XSCHEM_FILE_VERSION` bump, netlister support in
  `netlist.c` + every backend, draw/hit-test/select/move paths, and a
  back-compat reader that maps old label instances to the new primitive. High blast
  radius across the format and all netlisters.
- **Ease:** Hard. **When:** Late. Do it after the handles/funnel recipe is proven on
  all existing types (the funnel is exactly how you'd add a new type cleanly), and
  bundle the format-version bump with #19 if both are in scope.

### #19 — Cadence-style library structure (directory-per-cell)
- **What:** each cell gets its own directory rather than one dir of mixed `.sch`/`.sym`.
- **Where:** library path + resolution (`Makefile.conf` `xschem_library_path`,
  `find_file_first` Tcl, `.xschemrc`), every place that names a symbol/schematic, and
  the on-disk layout of `xschem_library/`.
- **Plan:** the most invasive item — touches file resolution, save/open, the library
  browser, all example designs, and back-compat with the millions of existing flat
  libraries. Needs a path-abstraction layer that supports *both* layouts and a migration
  tool. Almost certainly a major-version effort.
- **Ease:** Very Hard. **When:** Late, and only as a deliberate, well-scoped project.
  Pairs with #18 (browser) and #16 (format bump).

---

## Recommended ordering, condensed

1. **Quick wins first:** #23, #8, #11, #12, #10, #9, #17 — independent, high daily
   value, build momentum.
2. **Advance the two foundations** (already in motion): finish object handles through
   instances → unlocks #21, #26; widen the action registry → unlocks #15, #22, #3.
3. **Mid GUI features on those foundations:** #21 → #26 → #2; #13 + #5 + #3 together
   (shared message/log channel); #15 → #22.
4. **Window/library UX:** #20, then #18.
5. **Heavy interactive + format work last:** #25 alongside #1; then #16; #19 only as a
   dedicated major-version project.

The throughline: **don't hand-build the hard items.** #21, #26, #1, #16 all get
dramatically cheaper and safer once stable object handles and the action registry are
finished, so spend the early-middle of the cycle maturing those two, surrounded by the
self-contained quick wins.
