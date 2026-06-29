# Code analysis — selectable instance pins

*Status:* **IMPLEMENTED on `fluid-editing` (2026-06-28).** The original analysis
below was written pre-implementation; it remains accurate in its model of the
codebase. The actual implementation refined four decisions for robustness — see
**§0. Implementation update** immediately below, which supersedes the original
text wherever they differ. Companion plan: `../suggestions/pin_selection_plan.md`.
Line numbers drift — grep the named symbol if a line is off.

---

## 0. Implementation update (2026-06-28) — what was actually built

Re-verified every site against the live tree before coding. Verified anchors:

| symbol | file:line (2026-06-28) |
|---|---|
| `Selected {type;n;col}` | `xschem.h:459` |
| object type codes (`ARC 64`, next free **128**) | `xschem.h:278` |
| `xPoly.selected_point` (the template) | `xschem.h:543` |
| `xInstance` (`short sel;`) | `xschem.h:653` (struct ends `:687`) |
| `get_inst_pin_coord` | `netlist.c:753` |
| nearest-pin loop precedent | `findnet.c:219` |
| `find_closest_obj` cascade | `findnet.c:506` |
| `find_closest_element` | `findnet.c:432` |
| `select_object` switch | `select.c:1256` |
| `select_element` / `select_polygon` | `select.c:994` / `:1175` |
| `unselect_all` | `select.c:758` |
| `rebuild_selected_array` | `move.c:52` |
| `draw_selection` (ELEMENT case `:491`) | `move.c:210` |
| Button1 select gesture | `callback.c:5441` (pick at `:5472`, `add_wire_from_inst` at `:5492`, `select_object` at `:5516`) |
| `add_wire_from_inst` | `callback.c:2087` |
| `net_hilight_mode_click` | `callback.c:232` |
| instance death doors | `store.c:485` (`inst_delete_compact`), `:510` (`inst_storage_reset`) |
| `xschem set` (`argv[2][0] < 'n'`) | `scheduler.c:7150` (e.g. `hide_symbols` `:7233`) |
| `xschem select` dispatcher | `scheduler.c:6869` (new `pin` form added after the `instance` branch) |
| `xschem selection` query switch (the generic enumerator, NOT `selected_set`) | `scheduler.c:7104` (new `case INST_PIN: tname="pin"`) |
| Tcl toggle pattern | `set_ne` `xschem.tcl:14219`, menu `:13391`, sync `housekeeping_ctx:12563` |

**Four refinements adopted over the original plan (each is a strict
improvement — rationale in the plan doc §0.1):**

1. **Pin selection state is kept entirely OUT of `inst.sel`** (the original idea of
   reusing the `SELECTED1` summary bit was dropped). Pin state lives only in the new
   `xInstance.pin_sel[]` array. Consequence: every existing edit op iterates
   `inst[i].sel` and therefore ignores pins *by construction* — a pins-only instance
   has `inst.sel == 0`. This dissolves almost all of the original "Step 9 safe-default
   audit." (`unselect_all` tests `inst.sel == SELECTED` exactly, and `select_element`
   *overwrites* `inst.sel`, so a reused `SELECTED1` bit would have been fragile.)

2. **`find_closest_pin()` is NOT wired into `find_closest_obj()`.** That cascade has
   **7 callers** (hover `callback.c:1898`, move-start, `net_hilight_mode_click`,
   `scheduler.c:777`, …) — injecting pins there would change all of them. Instead the
   pin pick is a dedicated, `en_pin_select`-gated branch inside the Button1 select
   handler (`callback.c`), so only the literal click-to-select gesture can pick a pin;
   the other 6 callers are byte-for-byte unchanged even with the toggle on.

3. **`xInstance.pin_sel_size` companion field.** A symbol's pin count can change under
   a live selection (change-symbol / symbol reload), which would make a bare `pin_sel`
   stale and risk an out-of-bounds read. Storing the allocation length lets every
   consumer bound its scan to `min(pin_sel_size, current_pin_count)`, so a pin-count
   change is *harmless* and `pin_sel` only has to be freed at true instance-death
   sites (no scattered symbol-change frees). `delete_inst_node()` (`netlist.c:1705`)
   was rejected as a free site precisely because it runs on **every** netlist rebuild
   (via `delete_netlist_structs` and `select_element`'s `prepare_netlist_structs`),
   which would wipe a live pin selection constantly.

4. **The pin click supersedes `add_wire_from_inst`.** Today an exact click on a pin
   *starts a wire* from it (`callback.c:5492`). With `en_pin_select` ON the same click
   instead *selects the pin* (and consumes the event before the wire path), matching
   the user's "select the pin now, build its wire-stub later" workflow. With the
   toggle OFF this path is untouched — clicking a pin starts a wire exactly as before.

5. **`xctx.pin_sel_active` guard hint (added during testing).** `delete()`
   (`select.c:525`) force-resets `lastsel`/`SELECTION` but cannot clear inert pins
   (a pins-only instance is never doomed), so a later `unselect_all()` — whose body
   is guarded by `(ui_state & SELECTION) || lastsel` — would *skip* the stale
   `pin_sel`. Fix: `select_pin()` sets `xctx.pin_sel_active`, and `unselect_all()`
   clears pin selections in a block placed **before** that guard, gated only by the
   hint (one bool test when idle). Regression-caught: select pin → delete →
   unselect_all → next pin-select previously reported 2 selected instead of 1.

Everything else (the polygon-vertex precedent, `get_inst_pin_coord` for the
transform, the `SELLAYER` temp primitives, the toggle plumbing) is used as the
original analysis describes.

**Verification (headless, 2026-06-28):** `tests/pin_select.tcl` — 19/19 checks pass
(toggle, single/multi pin select, `xschem selection` rows `{pin <inst> <pin> <id>}`,
clear form, `unselect_all`, bad-arg rejection, delete-inertness). Plus ad-hoc smoke:
`select_all`/mixed-select/`copy_objects`/`delete`/`netlist` all coexist with live
`INST_PIN` entries without crashing or acting on pins; a 500× select/deselect +
reload churn shows no leak/double-free. GUI click path (callback hook) is
manual-test-only (no mouse events headless).

---

**Goal being scoped:** let the user select an *individual pin* of a placed
instance (not just the whole instance), behind an on/off toggle, with the
selection highlight rendering correctly on the selected pin.

**Ratified scope decisions (see plan §0):**
- **D1 — pins are inert in edits.** Pin selection renders a highlight, sets
  selection state, and is queryable from Tcl. It does **not** participate in
  move / copy / delete. It is the foundation for later features (probing, pin
  properties, net ops).
- **D2 — click priority = tight radius, else instance.** A click selects the
  pin only when within a small snap radius of the pin point; otherwise the
  whole instance is selected exactly as today.

---

## 1. The selection model (how anything gets selected)

### 1.1 The `Selected` descriptor and `sel_array`
`xschem.h:448`:
```c
typedef struct { unsigned short type; int n; unsigned int col; } Selected;
```
- `type` — object class (bitflag codes below).
- `n` — index into that class's object array (`wire[]`, `inst[]`, `rect[col][]`…).
- `col` — layer/column for per-layer objects (rect/line/poly/arc). For
  instances it is currently **always `WIRELAYER` and otherwise unused** — this
  is the spare field pin index can ride on.

The live selection is the dense array `xctx->sel_array[]` (count `lastsel`,
capacity `maxsel`, `xschem.h:1035`). It is **rebuilt from per-object `sel`
fields**, never edited directly as the source of truth.

### 1.2 Object type codes — `xschem.h:267`
```c
#define WIRE 1
#define xRECT 2
#define LINE 4
#define ELEMENT 8      /* an instance */
#define xTEXT 16
#define POLYGON 32
#define ARC 64
```
These are powers of two; the next free code is **128** (room for a new
`INST_PIN` pseudo-type — see plan).

### 1.3 Selection-state bits — `xschem.h:245`
```c
#define SELECTED  1U   /* whole object selected */
#define SELECTED1 2U   /* sub-part 1 (endpoint / corner / "partial") */
#define SELECTED2 4U
#define SELECTED3 8U
#define SELECTED4 16U
```
Stored in each object's `sel` field and OR-combined.

### 1.4 The precedent that matters: sub-part selection already exists
| object | sub-parts | state | mechanism |
|---|---|---|---|
| wire (`xschem.h:455`) | 2 endpoints | `SELECTED1`/`SELECTED2` | bits in `sel` |
| line | 2 endpoints | `SELECTED1`/`SELECTED2` | bits in `sel` |
| rect (`xschem.h:503`) | 4 corners | `SELECTED1..4` | bits in `sel` |
| **polygon (`xschem.h:525`)** | **N vertices** | **`SELECTED1` summary + `selected_point[k]` array** | **per-vertex array** |
| **instance (`xschem.h:626`)** | **N pins (none today)** | **only `SELECTED`** | **— missing —** |

**The polygon is the template.** It carries `unsigned short *selected_point`
(one byte/short per vertex) plus the `SELECTED1` "partial" summary bit in `sel`.
Pin selection should mirror this exactly. See `select_inside()` polygon branch
(`select.c:1498`) for how per-vertex flags are set and summarized.

---

## 2. Instances and their pins (the data already in hand)

### 2.1 `xInstance` — `xschem.h:626`
Relevant fields: `int ptr` (index of the symbol in `xctx->sym[]`), `double
x0,y0` (anchor), `short rot,flip`, `short sel`, `int color` (highlight color),
`int flags` (bit 2 = `HILIGHT_CONN`), `char **node` (one net pointer per pin),
`unsigned int id` (durable handle). **There is no per-pin selection field.**

### 2.2 Where pins live
Pins are `xRect`s on `PINLAYER` (`=5`, `xschem.h:158`) of the **symbol**, not the
instance:
- count: `(xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER]`
- rect j: `(xctx->inst[i].ptr + xctx->sym)->rect[PINLAYER][j]`
- `inst[i].node[j]` is the net attached to pin j (parallel to the pin list).

### 2.3 Absolute pin coordinates — already solved
`get_inst_pin_coord(int i, int j, double *x, double *y)` — `netlist.c:753`.
Takes the pin-rect center in symbol space, applies the instance `rot`/`flip` via
the `ROTATION` macro (`xschem.h:344`), translates by `inst.x0/y0`. **Rotation and
flip are fully handled here** — pin hit-testing and highlight drawing must go
through this function and never reinvent the transform.

### 2.4 Pin name / direction
```c
get_tok_value(sym->rect[PINLAYER][j].prop_ptr, "name", 0)   /* hilight.c:867 */
get_tok_value(rct[j].prop_ptr, "dir", 0)                    /* in/out/inout  */
```

### 2.5 Pin hit-testing already exists (reuse, don't reinvent)
- **Spatial index:** `Instpinentry { next; double x0,y0; int n; int pin; }`
  (`xschem.h:869`) in `instpin_spatial_table[NBOXES][NBOXES]` (`xschem.h:1053`),
  populated by `hash_inst_pin()` / `instpininsert()` (`netlist.c:343`,
  `netlist.c:451`).
- **Nearest-pin-to-point loop already written:** `findnet.c:220` iterates an
  instance iterator, calls `get_inst_pin_coord`, and keeps the closest pin to
  `(mx,my)`. `find_closest_pin()` for selection is essentially this loop with a
  threshold and a `Selected` write.

---

## 3. The click → select path

`handle_button_press()` (`callback.c`, Button1 path) →
`select_object(mx, my, SELECTED, 0, NULL)` (`select.c:1256`).

`select_object` (`select.c:1256`):
1. `sel = find_closest_obj(mx, my, override_lock)` when no explicit `selptr`.
2. `switch(sel.type)` → `select_wire` / `select_element` / `select_box` /
   `select_line` / `select_polygon` / `select_arc` / `select_text`.
3. flush temp primitives (`drawtemprect/line/arc(..., END, ...)`).
4. if not in incremental `select_mode`: `rebuild_selected_array()` then
   `draw_selection(gc[SELLAYER], 0)`.

`find_closest_obj` (`findnet.c:506`) runs each `find_closest_*` in turn against a
shared global `distance`; **instances run last so they win ties**
(`find_closest_element`, `findnet.c:432`). A new `find_closest_pin` slots into
this cascade; the **tight radius** of D2 is enforced by giving it a small
distance threshold so it only wins when the cursor is right on the pin.

`select_element(i, mode, fast, lock)` (`select.c:1010`): sets `inst[i].sel =
mode` and, when selecting, overdraws the whole symbol in the `SELLAYER` GC via
`draw_temp_symbol(ADD, gc[SELLAYER], i, c, …)`; when deselecting, restores the
instance bbox region from `gctiled`. This is the model a `select_pin()` follows
at pin granularity.

---

## 4. How the selection highlight is rendered

`draw_selection(GC g, int interruptable)` — `move.c:210` — iterates
`xctx->sel_array[]` and strokes each entry **in its natural shape** with GC `g`
(`SELLAYER`, `#define SELLAYER 2`, `xschem.h:153`):
- `xRECT` → `drawtemprect` (`move.c:267`)
- `WIRE` → `drawtemp_manhattanline` (`move.c:370`)
- `LINE` → `drawtempline` (`move.c:423`)
- `ARC` → `drawtemparc` (`move.c:464`)
- `ELEMENT` → `draw_temp_symbol(ADD, g, …)` (`move.c:491`)

A new `INST_PIN` case here draws a small handle/box at
`get_inst_pin_coord(n, col, …)` via `drawtemprect` on the `SELLAYER` GC — same
primitive, same GC, so it inherits the selection color and survives the same
redraw flush as every other selected object.

`rebuild_selected_array()` — `move.c:52` — scans every object's `sel` and emits
dense entries. **This is the single place that must learn to emit pin entries**
(scan a per-instance pin-selection array, emit one `INST_PIN` entry per selected
pin). Because every redraw funnels through here, getting this one function right
makes the highlight robust across pan/zoom/redraw.

---

## 5. The toggle mechanism (boolean option, C↔Tcl mirrored)

End-to-end pattern, verified on existing options (`hide_symbols`, `draw_window`,
`show_hidden_texts`):
1. **C field** in `xctx`, tagged `/* MIRRORED IN TCL */` (e.g. `xschem.h:1259`).
2. **Tcl default** via `set_ne <var> <default>` in `xschem.tcl` (helper at
   `xschem.tcl:215`).
3. **Menu checkbutton** bound to the Tcl var, `-command {xschem set <var> $<var>}`
   (pattern `xschem.tcl:11452`).
4. **C setter branch** in the `xschem set` dispatcher (`scheduler.c:6773`,
   alphabetized on `argv[2][0] < 'n'`): `xctx-><field> = atoi(argv[3]);`.
5. **C read** at the decision point via `tclgetboolvar("<var>")` (e.g.
   `hilight.c:793`).

The `xschem select` subcommand dispatcher (`scheduler.c:6493`) is where a
scriptable `xschem select pin <inst> <pinidx>` form would be added, mirroring the
existing `xschem select instance <name>` branch.

---

## 6. The gap, stated precisely

Everything needed to *locate, identify, and draw* a pin already exists
(`get_inst_pin_coord`, the pin spatial hash, the `findnet.c:220` nearest-pin
loop, the `SELLAYER` temp primitives, the toggle pattern). The **only missing
primitive is per-pin selection state on the instance** — the exact analog of the
polygon's `selected_point[]`. Once that field and a summary bit exist, the rest
is wiring it into five well-understood call sites: `find_closest_obj`,
`select_object`'s switch, `rebuild_selected_array`, `draw_selection`, and
`unselect_all` — plus the toggle and a Tcl entry point. Edit operations
(move/copy/delete) need only a **safe-default audit** so they ignore pin
entries, per scope decision D1.

See `claude_suggs/pin_selection_plan.md` for the step-by-step.
