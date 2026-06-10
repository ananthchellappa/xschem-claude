# Refactor plan (Phase 3): remappable input — keys *and* mouse gestures

> **Status (2026-06-07): APPROVED — pivoting here.** Phase 2 keyboard migration is
> paused (Batch 1 banked as proof; `migrated_action_ids` will not grow further). The
> "UI/Tcl-only, don't touch the engine" constraint is lifted for this work. Migrate
> each input ONCE, into the unified C table below. First slice = Phase 3a.
>
> **Phase 3a DONE & verified (2026-06-07).** `src/callback.c` now holds the action
> registry (`ActionDef` id→fn), the mutable binding table (`InputBinding`
> signature→id), `dispatch_input_action()`, and built-in defaults that reproduce the
> old wheel handling exactly; `handle_mouse_wheel` dispatches through the table while
> the `waves_selected` graph-routing stays verbatim in C. `xschem bind`/`bindings
> dump` (scheduler.c `case 'b'`) and `xschem unbind` (`case 'u'` — the dispatcher
> switches on the subcommand's FIRST LETTER, so each branch must sit in the matching
> case) are wired; prototypes in `xschem.h`. Verified by
> `tests/headless/test_mouse_bindings.tcl` (15/15: defaults == old behavior, dump,
> runtime remap, unbind→inert, unknown-action rejected); engine harness 6/6 and the
> Phase-2 GUI smokes (`test_accelerators`, `test_remap`) still PASS. Users can already
> remap the wheel with no GUI/recompile, e.g. `xschem bind wheel up 0 canvas
> view.pan_up` in `.xschemrc`.
>
> **Phase 3b DONE & verified (2026-06-07).** First gesture migrated: right-drag
> zoom-rectangle. Only the initiating chord is data-driven (`act_zoom_rect_start`,
> default `button 3 0 canvas`); the rubber-band + completion stay in C, keyed off
> `ui_state STARTZOOM`. `handle_button_release` got a button-agnostic completion
> `else-if` (inert under defaults). Verified by `test_gesture_bindings.tcl` (9/9) +
> full regression green. **Next: Phase 3c** (contexts: graph-vs-canvas routing).

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

## Plan (risk-sequenced, atomic steps)

Each step is scoped to be independently buildable, verifiable, and ideally one
commit.

### Phase 3a — mouse wheel ✅ DONE (commit `9fd11c1f`)
- [x] Extract the 6 wheel behaviors into named action fns (`act_zoom_in/out`, `act_pan_*`)
- [x] Add `ActionDef` registry (id→fn) + `InputBinding` table (signature→id) + `dispatch_input_action()`
- [x] Seed built-in defaults reproducing the old ladder; rewrite `handle_mouse_wheel` to dispatch through the table (graph-routing kept verbatim)
- [x] Add `xschem bind` / `unbind` / `bindings dump`
- [x] Test (`tests/headless/test_mouse_bindings.tcl`, 15/15) + engine harness 6/6

### Phase 3b — first gesture: right-drag zoom-rectangle ✅ DONE
- [x] **b1.** Extracted `zoom_rectangle(START)` into `act_zoom_rect_start`; registered (id `view.zoom_rect`)
- [x] **b2.** Added `dispatch_button_chord()` and routed the zoom-rect branch in `handle_button_press` through the table (consults binding before the old hardcoded check; falls through if unmatched)
- [x] **b3.** Seeded default `button 3 0 canvas → view.zoom_rect`; the hardcoded branch is now a generalized table-driven branch keeping the original `!excl && semaphore<2` guards
- [x] **b4.** Made completion button-agnostic: added an `else-if` in `handle_button_release` (callback.c) that finishes a pending `STARTZOOM` on a non-Button3 release. Inert under defaults (Button3 path unchanged, incl. the click→context-menu behavior). Confirmed rubber (`callback.c:119`) + END (`zoom_rectangle`) are `ui_state`-driven; only START + the context-menu branch were button-specific.
- [x] **b5.** Buttons round-trip through `bind`/`dump` (code = integer button number); dump prints `button 3 0 canvas view.zoom_rect`
- [x] **b6.** Test `tests/headless/test_gesture_bindings.tcl` (9/9): full press→drag→release zooms; unbind makes button-3 press inert (data-driven proof); rebind restores. Engine harness 6/6; all prior GUI smokes PASS (`test_mouse_bindings` count assertion updated to count wheel rows). *Note:* remap was proven via unbind/rebind of button3 rather than rebinding to button2, because Button2 is special-cased in the skip logic (`callback.c:48/50/52`) — a candidate to clean up in a later phase.

### Phase 3c — contexts (graph-vs-canvas routing)

**Why this is the lynchpin.** A binding signature today is `{device, code, mods}` +
a *constant* `ctx = ACTX_CANVAS`. That can't express the one thing blocking
everything else: the same input meaning different things depending on where the
pointer is. The mechanism for that today is `waves_selected()` (`callback.c:29`) —
"is this event over a waveform graph?" — called **~30 times** as hardcoded
`if(waves_selected(...)){ waves_callback(...); return; }` guards across
`handle_mouse_wheel`, `handle_button_press/release`, and inside individual `case`
bodies of the 1600-line `handle_key_press` switch (`callback.c:2834`). Those
per-key guards are exactly the keys Phase 2 had to **LEAVE IN C** (`s`, `f`, `a`,
`m`, arrows). 3c turns that routing from control flow into data, which is what
finally makes those keys migratable — so it's a modest change that unblocks the
large key-migration work in 3d.

**Design.** Add one dimension + a precedence rule:
- *Compute context once per event* — `current_input_ctx()` simply wraps the
  existing predicate: `waves_selected(...) ? ACTX_OVER_GRAPH : ACTX_CANVAS`. No new
  logic, just a name.
- *Most-specific-wins lookup* — instead of an exact `ctx` match, try
  `{…, ACTX_OVER_GRAPH}` then `{…, ACTX_GLOBAL}`. A graph-scoped row beats a global
  row beats nothing. The small, fixed analogue of a `when` clause — **not** a
  general predicate language.
- *Express the split as rows* — e.g. `wheel up 0 over_graph → graph.forward`
  alongside `wheel up 0 canvas → view.zoom_in`; the hardcoded `if` guard disappears.

**Atomic steps:**
- [x] **c1.** ✅ DONE (with c3). Added `current_input_ctx(event, key, state, button)` = `waves_selected ? ACTX_OVER_GRAPH : ACTX_CANVAS` — the single place that consults `waves_selected` for routing.
- [x] **c2.** ✅ DONE. `dispatch_input_action` now does most-specific-wins lookup (event ctx, then `ACTX_GLOBAL`) via a new `find_binding` helper (also reused by `set_input_binding`). Pure plumbing; defaults are all `canvas`, behavior unchanged. Test `tests/headless/test_binding_precedence.tcl` (5/5): specific-context row beats a `global` row; `global` is the fallback when no specific row exists (verified with canvas-only events — `over_graph` precedence comes with the c3 graph fixture). Full regression green.
- [x] **c3.** ✅ DONE. Added `graph.forward` action (calls `waves_callback`; `ActionEvent` extended with raw `xevent/key/button/aux` so it can re-forward). Seeded 4 `over_graph` wheel rows (no-mod + Shift, up/down); deleted the inline `waves_selected`/`waves_callback` guards from `handle_mouse_wheel`, which now computes context per-branch (Ctrl-wheel stays canvas, as before) and returns `ctx == OVER_GRAPH` to keep the old "graph consumes → 1" contract. Verified by `tests/headless/test_graph_context.tcl` (3/3, loads a schematic with a graph and fires wheels over graph vs canvas); engine 6/6; `test_mouse_bindings` row-count assertion narrowed to canvas-context wheel rows.
- [~] **c4.** Extract the context-routed **keys** (`s`, `f`, `a`, arrows) behaviors into `act_*` fns (ids match `actions.csv`). **Batch 1 DONE:** `f` → `act_zoom_full` (id `view.zoom_full`). **Batch 2 DONE:** arrows → `act_scroll_up/down/left/right` (ids `view.scroll_*`, full-step, sign copied verbatim from the old XK_* arithmetic; distinct from the half-step wheel `view.pan_*`). Remaining: `s` is a dialog/sim op → routing-only later (Group B). Modal keys (`m`, `t` place-text) stay in C.
- [~] **c5.** Add a **`DEV_KEY` dispatch at the top of `handle_key_press`** (`callback.c`): compute keysym signature + context, try the table, return if dispatched, else fall through to the `switch`. **DONE (machinery + first key):** dispatch added before the switch, gated by `key_chord_has_binding(code, mods)` so only migrated chords consult the side-effectful graph context (`current_input_ctx` → `waves_selected` mutates `graph_master`/cursor/GRAPHPAN); un-migrated keys are byte-for-byte unchanged. `mods` normalized per key class (letters strip ShiftMask = `rstate`; named keys use raw `state`). Seeded `key 'f' 0 canvas → view.zoom_full` + `key 'f' 0 graph → graph.forward`; deleted the `rstate==0` `f` guard from the switch (Ctrl-f/Alt-f stay). **Batch 2 (arrows):** seeded 8 no-modifier rows (`key <Up/Down/Left/Right> 0 canvas → view.scroll_*` + `… 0 graph → graph.forward`). This batch is **purely additive** — the arrow switch cases STAY (Ctrl+Left/Right tab-switch; Up/Down pan under *any* modifier incl. lock masks), so only the `mods==0` chord is peeled off by the dispatch; deleting the cases would break NumLock+arrow etc. Comments added to each case so the shadowed no-mod path isn't removed later. **Batch 3 (Group B routing-only) DONE:** 6 exact-chord letter keys (`Ctrl+a` select-all, `A` netlist-show, `Ctrl+A` graph-only, `Ctrl+b` sym-text, `B` header, `Ctrl+B` graph-only) — added `over_graph → graph.forward` rows (no canvas row) and **deleted** the inline waves guard from each switch branch; canvas behavior stays in C (dispatch falls through). TWO SCOPING CONSTRAINTS found: (1) only chords whose guard had NO preceding `if(semaphore>=2) break;` are migratable, because the top dispatch runs before any per-branch sem check — so hoisting a sem-gated guard would forward-to-graph at sem>=2 where the old code broke. Deferred: plain `a`, plain `b`, `s`, `Ctrl+s`, `Ctrl+f`, `Ctrl+r`. (2) only EXACT chords (`== 0`/`== ControlMask`); `Ctrl+t` uses `rstate & ControlMask` (a family) so deleting its guard drops `Ctrl+Alt+t` forwarding — deferred. **Batch 4 (Ctrl+arrow routing) DONE:** `Ctrl+Left`/`Ctrl+Right` (exact chords, waves-first) — added 2 `over_graph → graph.forward` rows, deleted the 2 Ctrl-branch waves guards; tab-switch canvas behavior (`prev_tab`/`next_tab`) stays in C. Completes the arrow keys. Test now 20/20 (also narrowed the batch-2 "no modified-arrow rows" assertion to "no modified-arrow CANVAS rows" — the new over_graph routing rows are expected). **Batch 5 (`t`) DONE:** plain `t` (place text, exact) → guard deleted + `{t,0,over_graph}` row; `Ctrl+t` (new schematic, FAMILY `rstate & ControlMask`) → `{t,Ctrl,over_graph}` row + guard **narrowed** to `(rstate != ControlMask) && waves_selected(...)` so the row owns the exact chord while the guard serves the `Ctrl+<other mods>` remainder (and the narrowing avoids a redundant `waves_selected` on the exact chord's canvas fall-through). Canvas behaviors stay in C; not exercised in tests (they mutate the fixture). Test 23/23.

**DECISION (2026-06-08): the 6 semaphore-first chords (plain `a`/`b`, `s`, `Ctrl+s`/`Ctrl+f`/`Ctrl+r`) are DEFERRED to Phase 3d.** Their guard sits *after* `if(sem>=2) break;`, and the top dispatch runs before any per-branch semaphore check, so migrating them naively would call `waves_selected` (side effects) and forward-to-graph at `sem>=2` where the old code did nothing. Migrating them *correctly* needs a "semaphore-sensitive" notion checked **before** `current_input_ctx` — but that same property governs each key's *canvas* behavior too (the `if(sem>=2)break;` guarding the dialog/save/simulate), which 3d moves to data anyway. So we represent semaphore-sensitivity **once, in 3d** rather than bolt a narrow version on now. **Phase 3c migration is therefore complete:** every remaining `waves_selected` guard in `handle_key_press` is one that belongs in C — modal (`m`/`Ctrl+m`), the `Ctrl+t` family remainder, the mod-agnostic/lock-mask arrow pans, or these 6 sem-first chords parked for 3d.
- [~] **c6.** Verify each migrated key empirically *in both contexts* (pointer over graph vs canvas) via observable state; confirm un-migrated keys still reach C. Commit per small batch. **DONE for `f` + arrows + Group B batch 3:** `tests/headless/test_key_graph_context.tcl` (now 16/16) — `f` zooms full on canvas / forwards over a graph; Up = vertical scroll, Right = horizontal scroll on canvas; Up over a graph leaves canvas origin; canvas `A` toggles netlist_show and `Ctrl+b` toggles sym_txt while over-graph both forward (vars untouched); rows present; no modified-arrow/canvas rows where expected. `test_accelerators.tcl` confirms `f` still has no Tcl-level bind. Engine 6/6 + all GUI smokes green. Repeat per future batch.

**Decisions & risks:**
- Keep the context enum **tiny and fixed** (3 values). Resist adding `move`/`wire_draw` until a concrete need appears; if a binding needs richer logic, point its id at a Tcl command (3d) rather than growing a DSL in C.
- The **`DEV_KEY` dispatch is the riskiest single change** (huge switch, keys interact with edit state). Mitigation: table-first / switch-fallthrough → migrate one small batch at a time; un-migrated keys are byte-for-byte unchanged.
- `waves_selected` is **order-sensitive** — some guards sit before other logic. Lifting them into rows must preserve "graph gets first refusal," which is why `over_graph` outranks `global`/`canvas` in the lookup; the c2 precedence test guards this.
- **Testing context needs a loaded graph** (unlike 3a/3b, which run on an empty schematic) so `waves_selected` returns true — a new test fixture to budget for.

**Scope boundary:** 3c migrates only the **context-routed** inputs. It does NOT
bulk-migrate the ~65 clean `tcleval` keys or the ~85 direct-C keys — that's 3d, and
it depends on a piece 3c doesn't build (an action id resolving to a Tcl command).
3c stays C-function-backed.

**Success criteria:** the `waves_selected` guard count in `callback.c` drops toward
the handful that are genuinely structural; the wheel + a first batch of keys route
correctly in *both* contexts via table rows and are remappable with
`xschem bind … over_graph|canvas …`; full regression (engine 6/6 + GUI smokes +
new context tests) stays green.

### Phase 3d — bulk-migrate keys + unify accel display
- [x] **d1. DONE** (commit `11744529`; design in `design_phase3d1_tcl_backed_actions.md`). Added a `tcl` field to `ActionDef` (an id is backed by EITHER a C `fn` OR a `tcl` string); `dispatch_input_action` runs whichever is set. Replaced `lookup_action_fn` with `find_action_def` and fixed the `xschem bind` validator to accept Tcl-backed ids (it had used "has a C fn" as a proxy for "id exists"). Proven by fully migrating **`B`** (edit header → Tcl action `sch.edit_header`): added the canvas row and **deleted `case 'B'` entirely** — the first key to leave the switch. Test 28/28; engine 6/6 + smokes green. (CSV/`actions.csv` unification stays in d4; context-dependent & semaphore-gated commands stay in d1b/later — see design doc §8.)
- [x] **d1b. DONE** (commit `c806149d`; plan `plan_phase3d1b_idle_only.md`). `InputBinding` gained an `idle_only` flag; the DEV_KEY dispatch gate folds in `!(semaphore>=2 && key_chord_is_idle_only(...))`, checked **before** `current_input_ctx` so no `waves_selected` side effect fires while busy — reproducing the deleted `if(sem>=2)break;`. Exposed as data: `bindings dump` appends ` idle`; `xschem bind <…> <id> [idle]` sets it (re-binding flips both ways — fixed a latent stale-flag bug on the replace path). Migrated the graph ROUTING of **4** of the 6 deferred chords (plain `a`, plain `b`, `Ctrl+f`, `Ctrl+s`): idle_only `over_graph → graph.forward` row + waves guard deleted; canvas behavior + `if(sem>=2)break;` stay in C. **plain `s` and `Ctrl+r` were NOT migrated** — they are *also* `cadence_compat`-gated (their forward lives inside a mode-conditioned branch the table can't express); they stay in C until a mode mechanism exists. Test proves the gate on a safe probe (`xschem set semaphore` + a Tcl-backed counter: fires at sem=0, skipped at sem=2; a non-idle rebind still fires at sem=2). Engine 6/6 + smokes green. **This unblocks the sem-gated command keys for full-data migration in later d2 batches** (add idle_only canvas rows + delete the whole case).
- [~] **d2. IN PROGRESS.** Migrate the clean command keys in batches; the switch shrinks toward the fallthrough.
  - **Prereq DONE** (commit `525bc94f`): the DEV_KEY dispatch now consults the graph context (`current_input_ctx`/`waves_selected`) **only when the chord has an `over_graph` row**; canvas-only chords use `ACTX_CANVAS` directly. Behavior-equivalent for all then-current keys; *required* before migrating canvas-only keys (else a deleted canvas-only case resolves to `OVER_GRAPH` over a graph, finds no row, does nothing).
  - **Batch 1 DONE** (commit `dd0e5909`): `case 'H'` deleted (plain → `sym.attach_net_labels_to_component_instance`, Ctrl → `sym.make_schematic_and_symbol_from_selected_components`, both C-backed); Alt-`h` branch deleted (`sym.create_symbol_pins_from_selected_schematic_pins`, Tcl-backed; EQUAL_MODMASK → two rows Mod1/Mod4). All canvas-only. Test proves Alt-`h` runs on canvas *and* over a graph. Engine 6/6 + smokes green.
  - **Batch 2 DONE** (commit `9a8e517a`; plan `plan_phase3d2_batch2.md`): five clean canvas-only command keys — `y`→`edit.toggle_stretch` (case deleted), `G`→`view.snap_double` (case deleted), `g`→`view.snap_half`, `T`→`prop.toggle_ignore_attribute_on_selected_instances`, `O`→`view.toggle_colorscheme` (g/T/O plain branch only; Ctrl/Alt branches stay). All C-backed; snap acts read `tclgetdoublevar("cadsnap")`, stretch act flips the `enable_stretch` var. Verified via the vars they flip/scale. Engine 6/6 + smokes green. New ids `edit.toggle_stretch`/`view.snap_*` not yet in actions.csv (→ d4).
  - **Next batches:** more pure-global no-sem command keys (C- or Tcl-backed). Still deferred: semaphore-gated (→ d1b) and mouse-coord/embedded-logic commands.
- [x] **d3. DONE** (commits `d8cf32bd` d3a, `2c8d9e16` d3b). **d3a:** `mods_name` now renders `Mod4Mask` as `super` (it printed `0` before) and `parse_mods` accepts `super`/`mod4`, so `bindings dump` shows Super chords and `xschem bind … super …` round-trips. **d3b:** `generate_keybindings_text` (action_registry.tcl) now reads `xschem bindings dump` (the live table) instead of the decorative `accel` column — new `keybinding_chord_label` renders each signature as a readable chord (keysym→name, wheel/button words, mods incl. Super), joined with `actions.csv` only for the human `label` (C-only ids fall back to the id → folded in at d4). idle rows annotated `(when idle)`; `graph.forward` routing rows footnoted, not listed. The sheet can't drift from the C dispatch. The Phase-2 `accel`/`migrated_action_ids`/`remap_action_accel` machinery is left intact (still used by `test_remap`/`test_accelerators`). `test_keybindings_help.tcl` rewritten for the dump-driven output incl. a "sheet follows the live table" unbind/rebind check. Engine 6/6 + smokes green.
- [x] **d4. DONE** (commits `7cb366f1` d4a, `99564587` d4b; plans
  `plan_phase3d4a_csv_single_source.md`, `plan_phase3d4b_bindings_file_loader.md`).
  **d4a:** `actions.csv` is the single source of truth for every bound id — 15 new
  label-only rows (empty `command` → palette skips them) for the C-registered ids
  (`view.scroll_*`, `view.pan_*`, `view.snap_*`, `view.zoom_rect`, toggles); new
  `idle` column (informational mirror of the binding `idle_only` flag, set on the 11
  sem-gated ids); `sch.edit_header` renamed to the pre-existing csv id
  `prop.edit_header_license_text` (same command, one id = one behavior). The
  `Z`/`view.zoom_in` "collision" dissolved on reading both sides: `view_zoom(0.0)`
  defaults to `CADZOOMSTEP`, so csv `xschem zoom_in` == wheel `act_zoom_in` — no id
  split, and a future `Z` migration is unblocked. `view.zoom_rect` vs `view.zoom_box`
  verified genuinely distinct (immediate gesture vs MENUSTART). Smoke now asserts NO
  bound id (graph.forward excepted — footnoted routing plumbing, deliberately no csv
  row) falls back to a bare id in the cheat-sheet.
  **d4b:** `keybindings.csv`/`mousebindings.csv` (rows = the `xschem bind` token
  vocabulary; action `-` = un-bind) are replayed at startup from xschem.tcl
  (share-dir defaults first, then `USER_CONF_DIR` copies, which win) — edit-a-file
  remapping with no recompile. The shipped files are GENERATED from the builtin table
  by `save_input_bindings_file`; `test_bindings_file.tcl` (13 checks) diffs them
  against a fresh save (drift guard), proves the no-op re-load, and proves a fixture
  remap+un-bind changes LIVE key behavior. Note: xschemrc is sourced before the
  `xschem` command exists, so these files are *the* file-remap path.
- [ ] **d5.** Delete the dead hardcoded ladders once parity is proven

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

## Next slice: Phase 3b — why right-drag-zoom

**It's not about the zoom-rect feature — it's the canary that proves the architecture
handles *gestures*, the exact class Phase 1/2's Tcl-interception structurally could
not.** Phase 3a only proved *discrete, instantaneous* actions (one wheel notch → one
action, no state spanning events). A gesture is the harder, distinct case: **press →
drag (rubber-band) → release**, multiple events coordinated against `xctx`. If the
binding architecture can't carry that, it can't deliver the productivity-critical
direct/modal inputs that motivated Phase 3 in the first place.

The thesis being validated is **"bind the initiating chord only; the action owns the
drag loop."** Right-drag-zoom confirms it almost for free, because the gesture is
*already* mostly button-agnostic in the code:

| Phase | Trigger | Keyed on |
|---|---|---|
| START | Button3 press | **button number** (`callback.c:4468`) ← the only button-specific part |
| RUBBER (drag) | mouse motion | `ui_state & STARTZOOM` (`callback.c:119`) — button-agnostic |
| END (release) | button release | `ui_state & STARTZOOM` (`callback.c:1419`) — button-agnostic |

Once `zoom_rectangle(START)` sets the `STARTZOOM` bit, the whole
rubber-band-and-finish machinery flows through `ui_state`-driven code that doesn't
care how it started. So making the gesture remappable means turning **just the START
chord** into a table lookup — zero changes to the interactive loop.

What the change buys us:
1. **Extends remappability to direct/modal interaction**, not just discrete keys/wheel
   — closing the gap that made the Phase 2 approach insufficient.
2. **Establishes the reusable pattern** every later gesture migration follows
   (middle-drag pan, wire draw, move-start): bind the chord, let `ui_state` carry the
   rest. Proven once on the simplest case.
3. **De-risks the rest of Phase 3** by showing the C engine's interactive loops never
   need rewriting — only their entry points become data.
4. **Real user value**: zoom on a different button (3-button/trackball mice, or
   matching muscle memory from another EDA tool) via `xschem bind` — no GUI, no
   recompile.

Ideal first gesture: self-contained, used by essentially every user, and (per the
table) its lifecycle is already `ui_state`-driven, so the risk is low.
