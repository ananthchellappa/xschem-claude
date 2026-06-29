# Plan: selectable instance pins (with on/off toggle)

*Status:* **IMPLEMENTED on `fluid-editing` (2026-06-28), pending manual GUI test.**
Analysis: `../code_analysis/pin_selection_analysis.md` (§0 there has the verified
file:line map and the same refinement list). Built directly on `fluid-editing`
(no separate branch). **Required `make`** (C changes), built from `src/`.

---

## 0. Ratified scope (do not re-litigate)

- **D1 — pins are INERT in edits.** Selecting a pin renders a highlight, sets
  selection state, and is queryable from Tcl. It MUST NOT participate in
  move / copy / delete / stretch. Those ops must silently ignore pin entries.
- **D2 — click priority = tight radius, else instance.** A click picks the pin
  only when within a small snap radius of the pin point; otherwise the whole
  instance is selected exactly as today.
- **Toggle name:** Tcl var + C field `en_pin_select`, default **0** (off).

Out of scope: persisting pin selection in `.sch`, moving/deleting pins,
multi-pin drag. Keep the diff to selection+highlight+toggle+query.

### 0.1 Refinements adopted during implementation (supersede the steps below)

The step-by-step in §2 is the original design. Four points were refined while
building; where §2 conflicts, **these win** (full rationale in analysis §0):

1. **No `SELECTED1` reuse — pin state lives ONLY in `xInstance.pin_sel[]`.** Pins
   stay out of `inst.sel`, so a pins-only instance has `inst.sel == 0` and every
   `inst[i].sel`-driven edit op ignores it automatically. Step 9's audit collapses
   to "nothing to change" (confirmed: edit ops iterate `inst.sel`, and the
   `sel_array` type-switches all no-op on the unknown `INST_PIN` code — a C `switch`
   with no matching `case` does nothing).
2. **`find_closest_pin()` is invoked only from the Button1 select gesture in
   `callback.c`, gated by `en_pin_select` — NOT from `find_closest_obj()`.** Keeps
   hover / move-start / net-highlight (the other 6 `find_closest_obj` callers)
   unchanged.
3. **Added `xInstance.pin_sel_size`** (allocation length) so a symbol pin-count
   change can never cause an OOB read; `pin_sel` is freed only at instance-death
   sites (`store.c` `inst_delete_compact` + `inst_storage_reset`), never in
   `delete_inst_node` (which runs every netlist rebuild).
4. **Pin click supersedes `add_wire_from_inst`** when the toggle is ON (selects the
   pin instead of starting a wire); OFF leaves that path untouched.
5. **`xctx.pin_sel_active` hint** (testing-caught): `delete()` resets `lastsel`/
   `SELECTION` but leaves inert pins selected, so `unselect_all()`'s guarded body
   would skip them. `select_pin()` sets the hint; `unselect_all()` clears pins in a
   block before its guard, gated by the hint. The scriptable query that reports pins
   is **`xschem selection`** (the generic enumerator), not `xschem selected_set`.

**Status of the original Step 9 audit:** confirmed unnecessary. Edit ops iterate
`inst.sel` (pins not there) and every `sel_array` type-switch (move/copy/delete/
clipboard-save/hilight) no-ops on the unknown `INST_PIN`. Verified by smoke test:
mixed instance+pin selections copy/move/delete the instance and ignore the pin.

**Test:** `tests/pin_select.tcl` (19 checks, all pass), run with
`../src/xschem --nogui --pipe -q --script pin_select.tcl`.

---

## 1. Design in one paragraph

Add per-instance pin-selection state mirroring the polygon's `selected_point[]`:
a lazily-allocated `unsigned char *pin_sel` on `xInstance` (length = symbol pin
count) plus the `SELECTED1` summary bit reused in `inst.sel` to mean "this
instance has selected pins." Add a new selection type code `INST_PIN` (128).
`rebuild_selected_array()` emits one `INST_PIN` entry per set `pin_sel[j]`
(`type=INST_PIN, n=i, col=j`); `draw_selection()` renders each as a small handle
at `get_inst_pin_coord(n,col,…)` on the `SELLAYER` GC. Clicking routes through a
new `find_closest_pin()` (gated on `en_pin_select`, tight threshold) →
`select_object` switch → `select_pin()`. Edit ops ignore `INST_PIN` via switch
defaults. A toggle and a `xschem select pin …` subcommand round it out.

---

## 2. Step-by-step

### Step 1 — type code + summary-bit convention
`src/xschem.h`, near `#define ARC 64` (~`xschem.h:267`):
```c
#define INST_PIN 128  /* sel_array pseudo-type: a single pin of an instance.
                       * Selected.n = instance index, Selected.col = pin index. */
```
Convention (document in a comment): for an instance, `inst.sel & SELECTED1`
means "one or more pins selected; consult `pin_sel[]`", exactly as a polygon's
`SELECTED1` means "consult `selected_point[]`". `SELECTED` (whole instance) and
`SELECTED1` (pins) may coexist; treat them independently.

### Step 2 — per-pin state field on the instance
`src/xschem.h`, in `xInstance` (`xschem.h:626`), after `short sel;`:
```c
unsigned char *pin_sel; /* NULL, or length = symbol PINLAYER pin count.
                         * pin_sel[j]!=0 => pin j selected. Transient,
                         * not saved. Mirrors xPoly.selected_point. */
```
**Lifecycle (critical — this is where bugs hide):**
- Initialize to `NULL` wherever instances are created/cleared. Grep `store.c`
  for where `inst[].node` and `inst[].sel` are first set (instance store /
  `inst_register`) and set `pin_sel = NULL` alongside.
- Free + NULL it wherever an instance is freed or its `node[]` array is freed
  (instance delete, `delete_inst`, context clear, symbol reload that changes pin
  count). Grep `store.c`/`actions.c` for `my_free(... inst[i].node ...)` and add
  a `my_free(_ALLOC_ID_, &xctx->inst[i].pin_sel);` next to each.
- Allocation is lazy: `select_pin()` allocates `pin_sel` to the current pin
  count (`(inst.ptr+xctx->sym)->rects[PINLAYER]`) with `my_calloc` on first use.
- **Safety:** any time pin count could have changed, treat a non-NULL `pin_sel`
  as stale and free it; never index past the current pin count.

### Step 3 — the toggle (C↔Tcl), follow the `show_hidden_texts` pattern exactly
1. `src/xschem.h`: add to `xctx` near other MIRRORED flags (~`xschem.h:1287`):
   `int en_pin_select; /* enable selecting individual instance pins MIRRORED IN TCL */`
2. `src/xschem.tcl`: `set_ne en_pin_select 0` (near `set_ne show_hidden_texts 0`,
   ~`xschem.tcl:12474`).
3. `src/xschem.tcl`: menu checkbutton (near other option checkbuttons,
   ~`xschem.tcl:11452`):
   ```tcl
   $topwin.menubar.option add checkbutton -label "Enable pin selection" \
        -variable en_pin_select -selectcolor $selectcolor \
        -command {xschem set en_pin_select $en_pin_select}
   ```
4. `src/scheduler.c`, in the `xschem set` dispatcher where `argv[2][0] < 'n'`
   (~`scheduler.c:6835`, alongside `draw_window`):
   ```c
   else if(!strcmp(argv[2], "en_pin_select")) {
     if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
     xctx->en_pin_select = atoi(argv[3]);
   }
   ```
   (`en_pin_select` starts with 'e' < 'n', so it goes in the first half.)
5. Read it in C via `tclgetboolvar("en_pin_select")` (used in Step 4).

### Step 4 — hit-testing: `find_closest_pin()`
`src/findnet.c`. Model the body on the existing nearest-pin loop at
`findnet.c:220` and the `find_closest_*` contract (compare to the file-global
`distance`, write the file-global `sel` on win). Sketch:
```c
static void find_closest_pin(double mx, double my, int override_lock)
{
  Instentryptr instanceptr; struct iterator_ctx ctx;
  double xx, yy, d, threshold;
  int i, j, rects, bestn = -1, bestp = -1;
  if(!tclgetboolvar("en_pin_select")) return;            /* gated by toggle  */
  threshold = /* tight: e.g. a few snap units, see CADSNAP / pick_dist */;
  /* iterate instances overlapping a small box around (mx,my), as findnet.c:220 */
  init_inst_iterator(&ctx, mx, my, mx, my);
  while((instanceptr = inst_iterator_next(&ctx))) {
    i = instanceptr->n;
    rects = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    for(j = 0; j < rects; j++) {
      get_inst_pin_coord(i, j, &xx, &yy);
      d = (mx-xx)*(mx-xx) + (my-yy)*(my-yy);
      if(d < threshold*threshold && d < distance) { distance = d; bestn = i; bestp = j; }
    }
  }
  if(bestn >= 0) { sel.type = INST_PIN; sel.n = bestn; sel.col = bestp; }
}
```
Call it inside `find_closest_obj()` (`findnet.c:506`). **Placement for D2:** call
it **last** (after `find_closest_element`) so that, when the cursor is within the
tight pin threshold, the pin's smaller `distance` wins the tie against the
enclosing instance; outside that radius `bestn` stays -1 and the instance result
stands. Verify the threshold is genuinely tight (don't let it swallow normal
instance clicks).

### Step 5 — selection: `select_pin()` + dispatch
`src/select.c`. Add a `case INST_PIN:` in the `select_object` switch
(`select.c:1256`):
```c
case INST_PIN:
  select_pin(sel.n, sel.col, select_mode, override_lock);
  break;
```
New `select_pin(int i, int j, unsigned short mode, int lock)`:
- if `mode` (select): lazily `my_calloc` `inst[i].pin_sel` to pin count if NULL;
  set `pin_sel[j] = 1`; set `inst[i].sel |= SELECTED1`; draw the handle now via
  `drawtemprect(gc[SELLAYER], ADD, …)` around `get_inst_pin_coord(i,j,…)`.
- if `!mode` (deselect): clear `pin_sel[j]`; if no pins remain set, clear the
  `SELECTED1` bit (and free `pin_sel` if you like); restore the pin region from
  `gctiled` (or rely on the caller's redraw).
- mirror `set_first_sel(...)` bookkeeping from `select_element` if needed.
Extend `select_inside()` (area select, `select.c:1409`) to mark pins inside the
rubber-band when `en_pin_select` is on, mirroring the polygon branch
(`select.c:1498`): for each instance pin in the box, set `pin_sel[j]=1` and the
`SELECTED1` summary. (Optional for v1 — can ship click-only first.)

### Step 6 — `rebuild_selected_array()` emits pin entries
`src/move.c:52`. In the per-instance loop, **in addition to** the existing
`if(inst[i].sel) → ELEMENT` emit, add:
```c
if(xctx->inst[i].pin_sel) {
  int rects = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
  for(j = 0; j < rects; j++) if(xctx->inst[i].pin_sel[j]) {
    /* grow sel_array as the existing code does */
    xctx->sel_array[xctx->lastsel].type = INST_PIN;
    xctx->sel_array[xctx->lastsel].n = i;
    xctx->sel_array[xctx->lastsel++].col = j;
  }
}
```
Keep the existing `ELEMENT` emit for `inst[i].sel & SELECTED` (whole instance).
This makes `sel_array` the single source for both drawing and query. The
existing `lastsel==0 → clear SELECTION ui_state` logic then Just Works.

### Step 7 — `draw_selection()` renders the pin handle
`src/move.c:210`. Add a `case INST_PIN:` alongside the `ELEMENT` case
(`move.c:491`):
```c
case INST_PIN: {
  double px, py, h = /* handle half-size in user units, ~pick_dist */;
  get_inst_pin_coord(n, col, &px, &py);
  drawtemprect(g, ADD, px-h, py-h, px+h, py+h);
  break;
}
```
Use the same `g` (`SELLAYER` GC) as the rest of the function so the pin handle
gets the selection color and is flushed by the existing `drawtemprect(..., END,
…)` in `select_object`. Pick a handle size that reads clearly at the pin point
without dominating small symbols (steal the corner-handle size used for rects if
one exists).

### Step 8 — clearing selection frees pin state
`src/select.c` `unselect_all()` (and any "select none" path): for every
instance, clear `inst[i].sel`'s `SELECTED1` bit and free/zero `pin_sel`. Confirm
ESC / right-click-deselect / `xschem unselect all` all route through here.

### Step 9 — edit ops ignore pins (D1 — the safe-default audit)
Grep every `switch` over `sel_array[k].type` / selection consumers in `move.c`,
`paste.c`, `clip.c`, `actions.c` (move, copy, cut, delete, stretch, rotate,
flip). Confirm each has a `default:` that no-ops on the unknown `INST_PIN` code,
**and** that nothing treats `inst.sel & SELECTED1` as "instance is movable."
Where an op iterates instances by `inst[i].sel != 0`, make it test `inst[i].sel &
SELECTED` specifically so a pins-only instance is not dragged/deleted. This step
is mostly reading; add a targeted guard only where a default would misbehave.

### Step 10 — scriptable entry point (for tests + future use)
`src/scheduler.c`, extend the `xschem select` dispatcher (`scheduler.c:6493`)
with a `pin` form mirroring the `instance` branch:
```c
else if(!strcmp(argv[2], "pin") && argc > 4) {   /* xschem select pin <inst> <pinidx> */
  int n = get_instance(argv[3]);
  int p = atoi(argv[4]);
  if(n >= 0) { select_pin(n, p, sel /*SELECTED or 0*/, 1); xctx->ui_state |= SELECTION; }
  Tcl_SetResult(interp, (n >= 0) ? "1" : "0", TCL_STATIC);
}
```
Add the matching `xschem unselect`/`clear` path. This gives regression tests a
headless way to drive pin selection without mouse events.

---

## 3. Touch list (every file/function)

| # | File | Symbol / site | Change |
|---|---|---|---|
| 1 | `xschem.h` | near `#define ARC 64` | `#define INST_PIN 128` + convention comment |
| 2 | `xschem.h` | `xInstance` | add `unsigned char *pin_sel` |
| 3 | `xschem.h` | `xctx` flags block | `int en_pin_select; /* MIRRORED IN TCL */` |
| 4 | `store.c` | inst create/clear/free, `node[]` alloc/free | init NULL, free+NULL |
| 5 | `xschem.tcl` | `set_ne` block | `set_ne en_pin_select 0` |
| 6 | `xschem.tcl` | option menu | checkbutton |
| 7 | `scheduler.c` | `xschem set` (`< 'n'`) | `en_pin_select` setter |
| 8 | `scheduler.c` | `xschem select` | `pin` subcommand |
| 9 | `findnet.c` | new `find_closest_pin`, `find_closest_obj` | hit-test, gated |
| 10 | `select.c` | new `select_pin`, `select_object` switch, `select_inside`, `unselect_all` | select/deselect/clear |
| 11 | `move.c` | `rebuild_selected_array` | emit `INST_PIN` entries |
| 12 | `move.c` | `draw_selection` | render pin handle |
| 13 | `move.c`/`paste.c`/`clip.c`/`actions.c` | edit-op switches | safe-default audit (D1) |

Remember: any new `.c` file needs an `OBJ` entry + compile rule in `src/Makefile`
(none expected here — all edits are to existing files).

---

## 4. Test & verification

**Build:** `cd src && make` (warnings-as-info; C89 — no `//` past column rules,
declare locals at block top).

**Headless regression (preferred — see CLAUDE.md `tests/`):** add a case under
`tests/` that, via `xschem ... --pipe -q --script`:
1. loads a schematic with a known multi-pin instance,
2. `xschem set en_pin_select 1`,
3. `xschem select pin <inst> 0`,
4. asserts the selection count / that `sel_array` contains the pin (expose via an
   existing `xschem get`/selection-query path, or add a tiny query),
5. `xschem unselect all` → asserts empty.
Compare against a golden file as the other cases do.

**Manual eyeball checklist (the suite can't assert pixels):**
- [ ] Toggle OFF: clicking a pin selects the whole instance (today's behavior, no
      regression).
- [ ] Toggle ON, click *on* a pin point: only the pin highlights; instance body
      not outlined.
- [ ] Toggle ON, click on instance *body* (away from pins): whole instance
      selects (D2 tight-radius holds).
- [ ] Pin highlight lands exactly on the pin for a symbol that is **rotated** and
      **flipped** (proves the `get_inst_pin_coord` path).
- [ ] Highlight survives pan, zoom, and a full redraw.
- [ ] Deselect (ESC / click empty) clears the pin highlight cleanly (no
      leftover handle pixels).
- [ ] With a pin selected, Delete / Move / Copy do **nothing** to the instance
      (D1 inert).
- [ ] No leak: select/deselect pins repeatedly under
      `xschem --script xschemtest.tcl -d 3 -l log` and check allocations.

---

## 5. Risks / gotchas

- **`pin_sel` lifecycle is the #1 bug source.** Symbol reload, instance delete,
  and context teardown must all free it. When in doubt, free-and-NULL on any
  structural change — selection is transient and cheap to rebuild.
- **Tight threshold tuning (D2).** Too large and it steals ordinary instance
  clicks; too small and pins feel unclickable. Tie it to the existing snap/pick
  distance, not a raw constant, so it scales with zoom.
- **C89.** Declare all locals at the top of their block; no `//` comments where
  the file uses `/* */`; new fields go through `my_malloc`/`my_calloc`/`my_free`
  with the `_ALLOC_ID_` placeholder (the awk pass numbers them — don't hand-number).
- **Don't break the `ELEMENT` path.** A pins-only instance (`sel == SELECTED1`,
  no `SELECTED`) must not be picked up by code that assumed `inst.sel != 0` means
  "whole instance selected" — Step 9 guards this.
- **Erase correctness.** If the pin handle ever draws outside the instance bbox,
  the `gctiled` restore in `select_element`-style deselect won't cover it; the
  simple fallback is a `draw()` on pin deselect. Acceptable for v1.

---

## v2 plan (2026-06-29) — multi-pin SHIFT+click (D6) + pin-aware deselect (D7)

Spec: `../specs/pin_selection.md` §3.2. RED-first. Step-1 feasibility is already
proven (deselect-one is the shipped registered action `edit.deselect_mode`, commit
`3b9199b5`) — this revision adds gesture + pin-awareness only. No new heap state.

### Phase 0 — RED
- `tests/pin_select.tcl` (--nogui, scriptable): keep the 19 checks; add multi-instance
  pin data-model checks (two pins on two instances selected at once; clear one leaves the
  other) — these already pass (data model is done), they guard it.
- `tests/pin_gestures.tcl` (NEW, DISPLAY only — `xschem callback` SEGFAULTs under --nogui):
  inject the real gestures. RED before the change:
  - SHIFT+click on a 2nd pin ADDS it (lastsel 1→2), doesn't replace.
  - plain click still REPLACES (lastsel stays 1).
  - SHIFT+drag on a pin is IGNORED (no copy: instances unchanged; pin not added).
  - SHIFT+drag on instance BODY still COPIES (instances+1) — cadence guard.
  - in `edit.deselect_mode`, click on a selected pin deselects just it (2→1, the OTHER
    pin remains).

### Phase 1 — D6 SHIFT+click multi-pin (callback.c + xschem.h)
- `xschem.h`: add scalar `int pin_pending_add;` next to `pin_pending` (NOT heap, NOT
  per-instance — the heap-field tutorial does not apply).
- `handle_button_press`, a new branch beside the plain pin block (~5566): if
  `tclgetboolvar("en_pin_select") && intuitive && (state&ShiftMask) && !(state&ControlMask)`
  and `find_closest_pin` hits → record `pin_pending` + `pin_pending_add=1` + press_x/y and
  `return` (consume the press BEFORE the SHIFT cadence-copy path; no unselect, no wire,
  no copy). Not gated on `!already_selected`.
- `handle_button_release` pin_pending block (~5742): if `pin_pending_add`, decide by the
  same `pin_press_x/y` drag test — no motion → `select_pin(pn,pc,SELECTED,0)` additively
  (NO unselect_all) + rebuild + draw + SELECTION; motion → ignore. Always clear the flag.
- `abort_operation`: also clear `pin_pending_add`.

### Phase 2 — D7 deselect-mode click clears a pin (callback.c)
- `deselect_mode_click`: before `unselect_at_mouse_pos`, if `tclgetboolvar("en_pin_select")`
  and `find_closest_pin` hits AND that pin is selected (`inst[i].pin_sel[j]`), call
  `select_pin(i,j,0,0)` + `rebuild_selected_array()`, preserve the mode bit, return. Else
  fall through to the existing object deselect. (Pin priority mirrors the select side.)

### Phase 3 — GREEN + regression
- `make` in `src/`. `pin_gestures.tcl` GREEN under DISPLAY=:0; `pin_select.tcl` 19+ still
  PASS under --nogui; `test_deselect_mode.tcl` still 18/18; engine 6/6; binding smokes.

### Phase 4 — docs/memory; commit only on the user's say-so.
