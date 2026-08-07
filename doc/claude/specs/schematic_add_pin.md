# Schematic-editor "Add Pin" (place ipin/opin/iopin instances)

Status: **RATIFIED — RED-first build in progress (2026-07-12).**
Owner: fluid-editing branch. Author notes / map: see the six-agent subsystem map that
seeded this spec (understand-schematic-addpin workflow).

Related prior art (reuse, do not reinvent):
- `doc/claude/specs/cadence_pin_name_text.md` — the symbol-editor Add-Pin form (`addpin::`)
  this generalizes; pin data model.
- `doc/claude/specs/wire_stub_netlabel.md` — `place_net_label` / `place_symbol` / the
  `lab=` net-name mechanism.
- `doc/claude/specs/symbol_editor_apply_scope.md` — headless RED-test conventions.

---

## 1. Motivation

Pressing **`p`** today runs `sym.place_symbol_pin` → `xschem add_symbol_pin` → the modeless
`addpin::` "Add Pin" dialog, which places a **symbol pin** (a `PINLAYER` rect owned by the
symbol) via `create_pin`. That is correct in a **symbol** view, but in a **schematic** view a
"pin" is a different object entirely: an **instance** of a device port symbol
(`devices/ipin.sym`, `opin.sym`, `iopin.sym`) whose `lab=` property names the net.

`p` must do the **right thing per view type**, keeping ONE default shortcut that the user can
reassign with `xschem bind` (the existing action-registry mechanism), and offering the SAME
user model in both views: an Add-Pin dialog taking **multiple space-separated names** + a
**Direction**, plus a Cadence-style **Ctrl+Middle-Mouse-Button** to cycle the pin type while
placing.

### 1.1 Discrepancy corrected by this work
The task premise assumed the symbol Add-Pin dialog already accepts space-separated multiple
names. It does **not** — `create_pin`/`addpin::arm` pass the whole entry as one pin name. This
spec adds multi-name to the **shared** dialog, so both views gain it (decision D1).

---

## 2. Decisions (ratified with the user 2026-07-12)

- **D1 — Unify.** ONE view-aware Add-Pin dialog (`addpin::`). Symbol view keeps placing
  `PINLAYER` pin rects (`add_symbol_pin -place`); schematic view places `ipin/opin/iopin`
  instances (`add_sch_pin -place`). Both gain space-separated multi-name.
- **D2 — Queue drains, then STOP; form stays open.** Names typed in the Pin Name field form a
  queue. Each canvas click drops the current name and the NEXT queued name auto-arms. When the
  last queued name is placed, placement **stops** (no re-arm) but the dialog **stays open** —
  the user types more names or presses Esc / Cancel to dismiss. (This also fixes the old
  symbol behavior of re-arming the *same* name, which produced duplicate pin names.)
- **D3 — Direction ⇄ type.** The Direction combobox (`input`/`output`/`inout`) maps to:
  - symbol view: pin `dir` token `in`/`out`/`inout` (unchanged, via `addpin::dirtok`);
  - schematic view: `input→ipin.sym`, `output→opin.sym`, `inout→iopin.sym`.
- **D4 — Ctrl+MMB cycles the type while placing.** During a live preview, Ctrl+Middle-click
  advances `input→output→inout→input`, updates the Direction combobox, and re-arms the CURRENT
  name — so the user can place `IN` as input, then Ctrl+MMB to output and drop `OUT`, never
  touching the form. Implemented as a **rebindable registry action** `edit.cycle_pin_type`
  (default chord Ctrl+Button2), consistent with the "reassign via bind" ethos.
- **D5 — `p` stays one binding.** No new key. `p` → `sym.place_symbol_pin` →
  `xschem add_symbol_pin` (no-arg) → `addpin::open`, which is now view-aware. Rebind/disable
  via `xschem bind key 112 0 canvas <id>` or `keybindings.csv` exactly as before.

---

## 3. User model (both views)

1. Press `p` (or Symbol menu → Place symbol pin). The modeless **Add Pin** form opens.
2. Type one or more names separated by spaces, e.g. `IN OUT VDD`. Pick a Direction.
3. Move onto the canvas: a preview of the FIRST name follows the cursor. Click to drop it;
   the next name auto-arms. Repeat until the list is exhausted (placement stops; form stays).
4. **Ctrl+MMB** at any time during a preview cycles the direction/type and re-arms the current
   name — no need to touch the Direction combobox between differently-typed pins.
5. Esc (on canvas while placing) or Close ends the gesture and dismisses the form.
6. **Arming a pin ABANDONS an in-progress wire/line draw** (`leave_wire_draw_for()`,
   `scheduler.c`, issue **0233** F1, user-ratified 2026-08-07 — same policy `l` got in issue
   **0230**). Two modal gestures cannot coexist: `end_place_move_copy_zoom()` tests `STARTWIRE`
   before the placement arm, and under `persistent_command` the press handler seizes the click
   one step earlier still, so a pin armed over a live wire mode could never be dropped — every
   click would draw wire while the preview rode the cursor. Nothing is committed (`new_wire()`
   stores and pushes undo only at `PLACE`) and the statusbar says what happened. Wire mode is
   left in **all three** of its states: live draw, menu-armed, and the RESTING mode after a
   double-click ends a segment (`ui_state` clear, only `last_command` armed). The scripted
   coordinate form `add_symbol_pin <x> <y> …` is deliberately NOT gated — it commits outright,
   arms no cursor placement, and is the replay/test seam.
7. **And the reverse: a wire/line verb pressed while a pin preview is live ABANDONS the preview**
   (`leave_placement_for()`, `callback.c`, issue **0233** F2, user-ratified 2026-08-07). The
   exclusion has to hold in both directions or the jam just gets entered backwards — and Add-Pin
   is the worse half, because unlike the Add-Wire-Label form there is no keystroke that re-arms
   the placement and frees the wire: before F2, ESC was the only exit and it threw the pin away.
   The preview is removed without pushing undo (the arm's single baseline stays the only rollback
   point) and the statusbar says `Wire: pending placement abandoned`. Applies to `w`, Shift+L,
   `W`/`s` (snap wire), the context-menu inserts, the menu/toolbar entries and scripted
   `xschem wire|line gui` / `xschem snap_wire`; the scripted coordinate forms are excluded for the
   same reason as above. Exception: with a **multiple selection** live the wire verb declines
   (statusbar: *finish or ESC the pending placement first*) and does not arm the draw — the
   teardown deletes the selection rather than the preview (issue **0231**), so abandoning there
   would wipe the drawing.

The bottom status line reflects state and advertises Ctrl+MMB + the multi-name convention.

---

## 4. Design & touch points

### 4.1 C: schematic pin placement — `place_sch_pin` (`actions.c`)
New sibling of `place_net_label` / `create_pin`:
```
int place_sch_pin(const char *name, const char *dir);
```
- Resolves the symbol by `dir`: `in→ipin.sym`, `out→opin.sym`, else `iopin.sym`
  (via `find_file_first`, path copied into a local buffer before `place_symbol`, since
  `place_symbol` clobbers the Tcl result).
- `place_symbol(-1, sym, mousex_snap, mousey_snap, 0, 0, "name=p1 lab=<name>", 4, 1,
  0/*to_push_undo: caller manages*/)`. `draw_sym&4` selects the new instance so
  `move_objects` can drag it. `name=p1` lets `new_prop_string` uniquify the refdes;
  `lab=<name>` is the net/port name. Returns `place_symbol`'s result.
- Prototype added to `xschem.h` next to `create_pin`.

### 4.2 C: modeless preview command — `xschem add_sch_pin -place` (`scheduler.c`)
Schematic twin of `add_symbol_pin -place`, in the same first-letter (`a`) dispatch block,
immediately after `add_symbol_pin`. Reuses the SAME undo-clean re-arm dance and the shared
`xctx->sympin_preview` flag + `START_SYMPIN` bit:
- read `::pin_new_name` / `::pin_new_dir`;
- if a live preview exists (`sympin_preview && START_SYMPIN`): `move_objects(ABORT)`,
  `delete(0)` (undo-free), clear `START_SYMPIN`; else `push_undo()` once, set
  `sympin_preview=1`;
- `unselect_all(1)`; `place_sch_pin(nm,dr)`; `rebuild_selected_array()`;
  `move_objects(START,0,0,0)`; set `START_SYMPIN`.
- Refuses in a symbol view (`editing_symbol_view()` → no-op) and honors
  `scheduler_readonly_reject`.

### 4.3 C: Ctrl+MMB action (`callback.c`, csvs)
- `action_registry[]` row: `{ "edit.cycle_pin_type", NULL, "addpin::cycle_type",
  "Cycle the pin direction/type (input/output/inout) of the pin being placed" }` (mutates=0).
- `init_input_bindings()`: `set_input_binding(DEV_BUTTON, Button2, ControlMask, ACTX_CANVAS,
  "edit.cycle_pin_type")`. During a preview `excl==0` and `semaphore<2`, so
  `dispatch_button_chord` (callback.c:5997) fires it before the Button2-pan branch (which
  requires `state==0`, so no conflict).
- `mousebindings.csv`: `button,2,ctrl,canvas,edit.cycle_pin_type,` (kept in sync with the C
  table; a smoke test diffs them).
- `actions.csv`: metadata row (menu-less, like `edit.cycle_manhattan`).

### 4.4 Tcl: the shared view-aware dialog (`xschem.tcl`, `addpin::`)
Pure, headless-testable helpers (no Tk):
- `addpin::names_from {s}` → whitespace-split token list.
- `addpin::next_dir {d}` → cycle `input→output→inout→input`.
- `addpin::place_verb` → `add_sch_pin` in a schematic (`current_name` not `*.sym`), else
  `add_symbol_pin`.

State: `name` (raw entry), `dir`, `pending` (names left this pass), `current` (armed name).
- `on_name_change`: `pending = names_from name`; `current = head`; arm. (Editing the name
  restarts the pass.)
- `on_dir_change` (combobox): re-arm `current` with the new dir; pending untouched.
- `arm`: empty `current` → abort preview + hint; else set `::pin_new_name`/`::pin_new_dir`,
  run `xschem [place_verb] -place`, status "placing '<name>' (<dir>) [N left] — click to
  place; Ctrl+MMB cycles type; Esc finishes".
- `after_drop {b}` (canvas ButtonRelease, button 1 only): if a drop completed, pop `current`
  off `pending`; if more remain, arm the next; else stop (armed=0) with an "all placed" hint,
  form stays open.
- `cycle_type` (Ctrl+MMB action): only while `placing`; `dir = next_dir dir` (combobox updates
  via `-textvariable`); re-arm `current`.

`p`/no-arg `add_symbol_pin` still calls `addpin::open`; only `arm`'s dispatch verb differs by
view. Title stays "Add Pin".

---

## 5. RED-first test plan (`tests/headless/test_sch_add_pin.tcl`)

Registered in `tests/run_regression.tcl` `hcases`; prints per-check `ok:`/`FAIL:` and the
`OVERALL: ok` sentinel; run true-headless (`--nogui --pipe -q`). All assertions FAIL before the
implementation (commands / procs absent) → RED, pass after → GREEN.

1. **Registry wiring (RED core):** `catch {xschem bind button 2 ctrl canvas
   edit.cycle_pin_type}` == 0 (unknown action id errors pre-impl); `xschem bindings dump`
   contains a `button 2 ctrl` → `edit.cycle_pin_type` row after `init_input_bindings`.
2. **`add_sch_pin` places the right symbol per direction (RED core):** `xschem clear force`;
   `set ::pin_new_name IN; set ::pin_new_dir in; xschem add_sch_pin -place` →
   `get instances`==1, `getprop instance 0 cell::name` matches `*ipin.sym`,
   `getprop instance 0 lab`==`IN`, `ui_state & 16384` set. Re-arm `out`→`*opin.sym` (still 1
   instance, replaced), `inout`→`*iopin.sym`. Drop via `move_objects end 0 0 0` commits (still
   1 instance, `START_SYMPIN` cleared).
3. **Symbol-view refusal:** load a `.sym` fixture → `add_sch_pin -place` adds no instance.
4. **Tcl pure helpers:** `addpin::names_from " IN  OUT VDD "`=={IN OUT VDD};
   `next_dir input`==output, output==inout, inout==input; `place_verb` == `add_sch_pin` on
   untitled.sch and `add_symbol_pin` after loading a `.sym`.
5. **Sabotage checks:** neuter the dir→symbol map (temporarily) and assert the direction test
   diverges — proven manually during build, not shipped ([[green-but-hollow]]).

GUI-only pieces (the Tk form, live cursor tracking, the actual Ctrl+MMB press) are validated
by hand and by the wireedit-style headless proxies above; `--nogui` cannot create Tk widgets.

---

## 6. Risks / landmines

- **Re-entrant re-arm from a button chord.** `cycle_type` runs via `Tcl_GlobalEval` from inside
  `handle_button_press`; it re-issues `add_*_pin -place` (which calls `move_objects`). This is
  the same C→Tcl→C shape as any button-chord action (e.g. `view.zoom_rect`). If it proves
  flaky, defer the re-arm with `after idle`. Watch `semaphore`/`ui_state` reentrancy.
- **Button2 release must not drop.** `addpin::after_drop` already guards `b==1`; Ctrl+MMB
  (button 2) is ignored there. Verify no Button2-release path commits the preview.
- **Windows modifier mask.** The `xschem.tcl` Windows binding block lacks a
  `<Control-ButtonPress>` row; confirm `%s` carries `ControlMask` for a plain middle-click on
  Windows or add a row (Unix/X11 delivers it through the generic `<ButtonPress>`).
- **`name=p1` uniquify.** Passing `name=p1 lab=<n>` relies on `new_prop_string` uniquifying the
  refdes (mirrors `place_pins.tcl`). Placing many pins yields `p1,p2,…`; the port name is
  `lab`, so identical `lab` on two ports still shorts nets — that is the user's choice, same as
  today's net labels.
- **Behavior change (intended, D2):** single-name placement now stops after one drop (form
  stays) instead of re-arming the same name. Documented; improves symbol pins (no dup names).
- **View detection must not read the display name.** `addpin::place_verb` picks the C verb by
  the CURRENT view (symbol → `add_symbol_pin`, schematic → `add_sch_pin`). It queries
  `xschem get editing_symbol_view` (the authoritative C `editing_symbol_view()`, which tests the
  real loaded path `xctx->sch[currsch]`) — NOT a `*.sym` match on `xschem get current_name`. A
  library-manager symbol DISPLAYS as the extension-less `lib/cell` reference (`rel_sym_path` →
  `lib_qualified_rel` drops `.sym`), so the old name-string match returned 0 and ran
  `add_sch_pin -place`, a no-op in a symbol view: `p` opened the form but no preview armed and a
  click placed nothing. `untitled.sym` kept its `.sym` and worked, which masked the bug. Any new
  symbol-vs-schematic decision in Tcl MUST use `editing_symbol_view`, never the name string.
  Regression: `tests/headless/test_add_pin_lib_symbol_view.tcl`.
