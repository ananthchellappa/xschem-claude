# Refactor plan (Phase 3): remappable input — keys *and* mouse gestures

> **Status (2026-06-07): APPROVED — pivoting here.** Phase 2 keyboard migration is
> paused (Batch 1 banked as proof; `migrated_action_ids` will not grow further). The
> "UI/Tcl-only, don't touch the engine" constraint is lifted for this work. Migrate
> each input ONCE, into the unified C table below. First slice = Phase 3a.

## Starting question

> "`actions.csv` lets *named* GUI items be remapped. But Ctrl+WheelUp ('pan up'),
> WheelUp ('zoom in'), and right-drag-to-zoom are not remappable — they live in the
> monster `handle_key_press` / `handle_mouse_wheel` C code. How do we give users an
> easy way to remap functions WITHOUT going through the GUI? Some productivity-critical
> actions (right-mouse-click-and-drag to zoom) must act *directly* — they can't go
> through an 'enter command mode, then type' flow."

This is the question Phase 1/2 deliberately deferred. It is also the question that
breaks the Phase 1/2 ground rule, and that is the whole point of this document.

## Why Phase 1/2 ran out of road

Phase 1/2 made *named* actions remappable by intercepting **discrete, stateless,
context-free** keystrokes in Tk, *above* C, using binding-specificity + `break`
(`bind_accelerators_from_table` → `run_action`). That works for `u`/`Shift+U`/
`Shift+Z`/`Ctrl+Z` and nothing structurally harder. The project memory already
records the wall: "LEAVE IN C — anything calling `waves_selected()` (graph-vs-canvas
routing), infix/modal placement or move-start, or depending on in-progress edit
state." That exclusion list is not a coincidence of effort; it is a structural class.

The user's examples are exactly that class:

| Input | Why Tcl-interception can't own it |
|---|---|
| right-drag → zoom rectangle | a **gesture** (press → motion* → release) whose rubber-band loop is coordinated in C against `xctx` |
| WheelUp = zoom / Ctrl+WheelUp = pan | trivial *behavior*, but the dispatch is buried in `handle_mouse_wheel`, not in any table |
| `s`/`f`/`a`/arrows | **context-routed**: same key goes to the graph when the pointer is over one (`waves_selected()`) |

Reimplementing these above C would mean rebuilding the interactive rubber-band loop
in Tcl and round-tripping every `MotionNotify` through the `xschem` dispatcher, while
querying `xctx` state from Tcl on every event. Technically possible, practically wrong.

**Conclusion: the binding indirection has to move *into* C, not stay above it.**
That contradicts the standing "UI/Tcl-layer-only, do not touch the engine" constraint
— correctly so for Phase 1/2, and now the thing blocking Phase 3.

## The core reframe: separate *binding* from *behavior*

`handle_key_press` and `handle_mouse_wheel` / `handle_button_press` fuse two jobs
that must be split:

1. **Binding** — *which* physical input (key/button + modifiers + context) → *which*
   action. Today this is hardcoded as the `switch(key)` chain and `if(button==...)`
   ladders. This is the part that should become **data**.
2. **Behavior** — what the action does to `xctx` (zoom, pan, rubber-band, netlist).
   This must **stay in C**; it touches `xctx`, rubber-banding, the hierarchy stack.

Phase 3 = pull #1 out of the C control flow into a loadable table, leave #2 in C,
and join the two through the stable **action-id** namespace already started in
`actions.csv`.

## Target architecture (command pattern + keymap)

### 1. Decompose the switch into named action functions

Each `case` body in `handle_key_press` (and each branch of `handle_mouse_wheel` /
the wheel/zoom ladders) becomes a named function with a uniform signature, registered
in a C table:

```c
typedef struct {
  int    mx, my;         /* pointer at dispatch time            */
  int    state;          /* raw modifier mask                   */
  int    button;         /* 0 for key events                    */
  KeySym key;            /* 0 for mouse events                  */
  int    ctx;            /* ACTX_GLOBAL / ACTX_OVER_GRAPH / ...  */
  const char *win_path;  /* topwin                              */
} ActionEvent;

typedef int (*ActionFn)(const ActionEvent *e);   /* returns 1 if handled */

typedef struct {
  const char *id;        /* "view.zoom_in" — SAME namespace as actions.csv */
  ActionFn    fn;
  const char *help;
} ActionDef;

static const ActionDef action_registry[] = {
  { "view.zoom_in",      act_zoom_in,        "Zoom in"            },
  { "view.zoom_out",     act_zoom_out,       "Zoom out"           },
  { "view.pan_up",       act_pan_up,         "Pan canvas up"      },
  { "view.zoom_rect",    act_zoom_rect_start,"Zoom to rectangle"  },
  /* ... */
};
```

This is mechanical, independently valuable (the 1596-line switch becomes a lookup),
and it is the **enabling** step: you cannot bind to actions that have no names. The
ids deliberately match the `actions.csv` ids so the C registry and the Tcl table
share one vocabulary. (See `handle_key_press_engineering_critique.md` — this is the
same decomposition that doc argues for, now with a dispatch table as the payoff.)

### 2. A binding table in C, keyed by event signature

```
signature := { device(KEY|BUTTON|WHEEL), code, modmask, context } -> action-id
```

The input handlers become thin: normalize the event into a signature, look it up,
dispatch to the `ActionFn`. The still-unmigrated `case`s remain as a **fallthrough**,
so this is incremental — exactly the way Tcl interception currently falls through to
C. Nothing has to move all at once.

Lookup precedence (most-specific wins): exact `modmask` + specific `context` beats
exact `modmask` + `ACTX_GLOBAL` beats default. This is what lets one wheel event mean
"zoom" globally but something else over a graph, expressed as *two rows* instead of
an `if`.

### 3. The table is data, loaded via a new `xschem bind` subcommand

Per CLAUDE.md's grain ("add a branch in `scheduler.c`, wire from Tcl"):

```
xschem bind   <device> <code> <modmask> <context> <action-id>
xschem unbind <device> <code> <modmask> <context>
xschem bindings dump                 # for the generated cheat-sheet
```

Tcl parses `keybindings.csv` / `mousebindings.csv` at startup (we already parse CSV
for `actions.csv` in `load_action_table`) and replays them as `xschem bind` calls.
This keeps a CSV parser out of C89 and reuses the proven C↔Tcl seam. **User remap =
edit the data file (or call `xschem bind` from the console / `.xschemrc`) — no GUI
mode, no recompile.** Runtime remap = re-issue `xschem bind`.

Data file sketch (`mousebindings.csv`):

```
device,code,mods,context,action_id
WHEEL,up,0,global,view.zoom_in
WHEEL,up,Ctrl,global,view.pan_up
WHEEL,down,0,global,view.zoom_out
WHEEL,down,Ctrl,global,view.pan_down
BUTTON,3,0,canvas,view.zoom_rect
BUTTON,2,0,canvas,view.pan_drag
```

### 4. Mouse gestures: bind the *initiating chord only*

This is the direct answer to "right-drag-to-zoom can't go through a mode." You do
**not** migrate the drag loop. You migrate the **trigger**. The row
`BUTTON,3,0,canvas → view.zoom_rect` says only *which chord starts the gesture*;
`act_zoom_rect_start` then owns the subsequent `MotionNotify`/release and rubber-band
exactly as the C code does today. The interactive machinery is untouched; only its
entry point becomes data. So a user can rebind zoom-rect to, say, middle-drag by
editing one row — without any "command mode."

### 5. Context as a small fixed enum, computed in C

```c
enum { ACTX_GLOBAL, ACTX_CANVAS, ACTX_OVER_GRAPH, ACTX_MOVE, ACTX_WIRE_DRAW };
```

Computed cheaply per event (e.g. `ACTX_OVER_GRAPH` from the existing
`waves_selected()` test, `ACTX_MOVE` from the in-progress-move flags). A binding row
carries an optional context; the dispatcher prefers the most specific match. This
turns the scattered `waves_selected()` / modal special-casing **into data rows**
rather than control flow — which is precisely what made those keys un-migratable in
Phase 2. Keep the enum small and fixed; resist inventing a general predicate language.

### 6. Unify with `actions.csv`; kill accel drift

One action-id namespace. An id resolves to **either** a C `ActionFn` (the new
registry) **or** a Tcl command (the existing `actions.csv` `command` column) — the
binding layer is agnostic to which. The `accel` column stops being a hand-maintained
display string that drifts (memory caught "Alt-F" is really `Alt+f`, "U" is keysym
`u`): it becomes **derived from** the binding table via `xschem bindings dump`. Menus
and the cheat-sheet then cannot disagree with what the keys actually do.

## What this unblocks

- Remappable **keyboard and mouse**, including gestures and context-sensitive keys —
  the whole class Phase 2 had to leave behind.
- One data file (or `.xschemrc` lines) for power users; a future "Customize
  Shortcuts" dialog becomes a thin editor over the same `xschem bind` calls.
- An always-accurate cheat-sheet and menu accelerators, generated, not transcribed.
- The Tcl-interception path from Phase 2 stays valid for genuinely Tcl-only actions;
  it simply stops being the *only* mechanism.

## Plan (risk-sequenced)

**Phase 3a — prove the dispatch table on the safest cases (wheel/zoom/pan).**
These are self-contained, stateless, no gesture, no `waves_selected()` ambiguity in
the common path. 1) Extract `act_zoom_in/out`, `act_pan_{up,down,left,right}` from
`handle_mouse_wheel`. 2) Add the `ActionDef` registry + signature lookup; route
`handle_mouse_wheel` through it with the old ladder as fallthrough. 3) Add `xschem
bind`/`unbind` in `scheduler.c`. 4) Load `mousebindings.csv` from Tcl. Verify: wheel
zoom ratio and pan deltas identical to baseline (observe `xschem get zoom`,
xorigin/yorigin); headless harness 6/6.

**Phase 3b — one gesture, end to end (right-drag zoom-rect).**
Extract `act_zoom_rect_start`; bind `BUTTON,3,0,canvas`. Confirm the rubber-band loop
is untouched and rebinding the chord (e.g. to button 2) works via one CSV edit.
This validates "bind the initiating chord, action owns the drag."

**Phase 3c — introduce contexts; migrate the context-routed keys.**
Add the `ctx` enum + computation; express the `waves_selected()` split as paired rows
(`global` vs `over_graph`). Migrate `s`/`f`/`a`/arrows. Verify both routings
empirically (pointer over graph vs canvas).

**Phase 3d — bulk-migrate `handle_key_press`.**
Extract the remaining `case` bodies into `ActionFn`s (the 65 `tcleval` branches are
nearly verbatim; the ~85 direct-C branches wrap existing calls). Generate `accel`
display + cheat-sheet from `xschem bindings dump`; retire the decorative `accel`
column as a source of truth. The switch shrinks to the fallthrough, then to nothing.

## Risks & honest trade-offs

- **This touches the engine.** It breaks the Phase 1/2 "Tcl-only" rule by design;
  there is no engine-free way to make gestures/context-routed inputs remappable. The
  decomposition of `handle_key_press` is real C work (mitigated: it is mostly
  mechanical, and the headless harness covers the engine paths regardless).
- **C↔Tcl call frequency.** Keep `xschem bind` to *startup/remap* only — never per
  input event. Dispatch stays entirely in C; Tcl only populates the table.
- **Incremental safety.** The fallthrough means every batch is independently
  shippable and bisectable; the switch and the table coexist until the table wins,
  exactly as Tcl-interception and C coexist today.
- **Scope discipline on context.** A fixed 4–5 value enum, not a `when`-clause DSL.
  If a binding truly needs richer logic, point its action-id at a Tcl command and let
  the predicate live there.

## First slice for next session

Phase 3a only: `act_zoom_in/out` + `act_pan_*` extracted from `handle_mouse_wheel`,
the `ActionDef` registry + signature lookup, `xschem bind`/`unbind` in `scheduler.c`,
and `mousebindings.csv` loaded from Tcl — with the old ladder as fallthrough and a
headless test asserting wheel zoom/pan are byte-for-byte unchanged before any rebind.
