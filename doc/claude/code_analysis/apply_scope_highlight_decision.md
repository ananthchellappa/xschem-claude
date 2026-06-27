# Decision doc — apply-scope highlight (white outline on edit targets)

*Status:* **IMPLEMENTED 2026-06-14 — H1 + H2 + H3 done (suite 136).** Decisions
D1–D7 ratified (§6). H1 = primitive + Only Current; H2 = All Selected + All
(already powered by the shared `scope_targets`); H3 = text bbox + tunable halo
(`::slickprop_highlight_width`). Remaining = the **§8 manual eyeball checklist**
(pixel/visual items the suite cannot assert). Spec:
`doc/claude/specs/apply_scope_highlight.md`. Brief:
`doc/claude/suggestions/apply_scope_highlight_session_prompt.md`.

This doc does the design-first work the spec §6 / the brief require: **§1**
characterizes the drawing path (recipe step 1, "write down what you find");
**§2** answers the open decisions **D1–D6** plus a newly-surfaced **D7** with a
recommendation each; **§3** sketches the resulting shape; **§4** the test plan.
Per the brief, *stop here for ratification* before any code — especially **D1**
(color) and **D2** (persistence), and the newly-surfaced **D7** (outline =
applied set vs. outline = full selection).

---

## 1. Characterization of the drawing path (verified, read end-to-end)

### 1.1 How the selection overlay is rendered — and why it survives a redraw

`draw_selection(GC g, int interruptable)` (`move.c:210`) iterates
`xctx->sel_array[]` and, per `type`, strokes the object in its **natural shape**
with the passed GC, via the temp primitives:

| type | primitive | file |
| --- | --- | --- |
| `xRECT` | `drawtemprect` | `draw.c:2323` |
| `WIRE` | `drawtemp_manhattanline` (the wire **as a line**) | `draw.c:1540` |
| `LINE` | `drawtempline` | `draw.c:1452` |
| `POLYGON` | `drawtemppolygon` | `draw.c:2176` |
| `ARC` | `drawtemparc` | `draw.c:1572` |
| `xTEXT` | `draw_temp_string` | `draw.c:546` |
| `ELEMENT` (instance) | `draw_temp_symbol` ×`cadlayers` | `draw.c:904` |

It is driven by move/rotate state (`xctx->deltax/deltay`, `move_rot`,
`move_flip`); for a **static** overlay all of those are 0, so the geometry
collapses to "stroke the object where it sits."

**The critical finding for D2:** `draw()` (`draw.c:5328`) calls
`draw_selection(xctx->gc[SELLAYER], 0)` **at its very end** (`draw.c:5571`),
*after* the pixmap→window copy (`MyXCopyArea`, `draw.c:5557`). So the selection
overlay is **re-stroked on every full redraw** — it is not a one-shot XOR scribble
that a redraw wipes; it is part of the standard redraw tail. Pan/zoom/any
`draw()` rebuilds the canvas from the pixmap and then re-applies the overlay.

➡ **Consequence:** an apply-scope overlay added as a sibling call right after
`draw.c:5571` inherits the same persistence for free. No separate "survive the
redraw" machinery is needed; no XOR erase is needed. **Clearing = one more
`draw()` with an empty overlay set → pixel-identical to before** (the canvas is
rebuilt from the pixmap, which never contained the overlay).

The temp primitives **batch** into a static buffer and flush on a final `END`
call (e.g. `drawtempline(g, END, …)`); the render function must emit the matching
`END` per primitive type it used, exactly as `draw_selection` does
(`move.c:498–512`).

### 1.2 The GC model

- `xctx->gc` is `GC *gc` (`xschem.h:1043`), an array of `cadlayers` GCs created in
  `create_gc()` (`xinit.c:443`), one per layer, foreground set in `build_colors()`
  (`xinit.c:1075`: `XSetForeground(display, xctx->gc[i], xctx->color_index[i])`).
- `SELLAYER = 2` (`xschem.h:153`); selection draws with `xctx->gc[SELLAYER]`,
  erases with `xctx->gctiled` (a no-op/tiled GC, `xinit.c:2388`).
- Each open window/tab has its **own** `xctx`, hence its own `gc[]`. A new
  dedicated GC must live in `Xschem_ctx`, be created in `create_gc()`, freed in
  `free_gc()`, and (if its color tracks the theme) re-set in `build_colors()`.
- Color name → pixel via `find_best_color()` (`xinit.c`, Tk path
  `Tk_GetColor`, `xinit.c:301`). So a GC can be set to any named/hex color.

### 1.3 The scope → target-set mapping (the "one source of truth")

`apply_symbol_prop()` (`editprop.c:843`) builds `targets[]` from `<scope>`
(`editprop.c:882–893`) — **this exact block is the set Apply writes**:

```c
if(!strcmp(scope, "all")) {            /* every same-master instance */
  int master = xctx->inst[displayed_inst].ptr;
  for(i=0;i<xctx->instances;++i)
    if(xctx->inst[i].ptr == master) targets[ntargets++] = i;
} else if(!strcmp(scope, "selected")) {/* selected INSTANCES only */
  for(k=0;k<xctx->lastsel;++k)
    if(xctx->sel_array[k].type == ELEMENT) targets[ntargets++] = xctx->sel_array[k].n;
} else {                               /* current: the displayed instance */
  targets[ntargets++] = displayed_inst;
}
```

**Key fact:** all three scopes resolve to **instances only** — even `selected`
filters `sel_array` to `type == ELEMENT`. The mid-session entry point is
`apply_instance_properties(scope, displayed_id, …)` (`editprop.c:1017`), which
maps the stable `displayed_id → idx` via `inst_index_from_id()` and calls
`apply_symbol_prop`. Command: `xschem apply_properties <scope> <displayed_id>
<new> <old>` (scheduler.c:181).

The Tcl mirror is `slickprop::scope_instances` (`property_form.tcl:405`) — same
three cases, returns instance **indices**; used by the P3 "values differ" warning.

### 1.4 The form lifecycle + the live-update triggers to reuse

`slickprop::edit_form` (`property_form.tcl:547`):
- builds the modal `.dialog`, sets the sticky scope combobox (`:558–586`);
- seeds nav from stable ids: `nav(ids)` from `::tctx::edit_sel_ids`,
  `nav(disp_id)` = displayed instance id (`:654–670`);
- **opens with** `slickprop::load_pos` (`:489`) which sets `nav(disp_id)` and
  calls `apply_scope_greying` + `update_warning`;
- installs `trace add variable ::slickprop_apply_scope write
  slickprop::apply_scope_greying` (`:677`) — **fires on every dropdown change**;
- close paths: `ok` / `apply_now`(→`ok`-like stays open then later `ok`/`cancel`)
  / `cancel` (`:330–343`), and `WM_DELETE_WINDOW → cancel` (`:706`);
  trace removed at `:725`.

So the three refresh hooks already exist and are exactly where P1/P3 hang:
1. **scope change** → the `::slickprop_apply_scope` write trace
   (`apply_scope_greying`, `:375`);
2. **Next/Prev** → `load_pos` (`:489`, also the open path);
3. **close** → `ok` / `cancel` (`:330`, `:337`).

---

## 2. The decisions (recommendation each)

### D1 — the "white" GC and its color  *(needs a human call)*

**Options.** (a) one **dedicated GC** in `xctx`, foreground set to a tunable
color, created in `create_gc`/freed in `free_gc`/re-set in `build_colors`;
(b) borrow an existing layer GC and `XSetForeground` before/after each stroke
(reentrancy-fragile, must restore — rejected); (c) reuse `gc[SELLAYER]` (wrong —
that *is* the selection color, the whole point is a *distinct* cue).

**The white-on-light-theme problem.** A fixed white outline vanishes on the light
color scheme (white-ish background). Two ways to handle:
- **theme-aware default:** white on the dark scheme, a dark/high-contrast stroke
  on the light scheme — read `tclgetboolvar("dark_colorscheme")` in `build_colors`
  when setting the GC foreground;
- **fixed high-saturation color** that reads on both (the P3 warning precedent:
  `slickprop::warn_color` = `#d02020`); simplest, but "white outline" becomes a
  misnomer.

**Recommendation:** **(a)** a dedicated `xctx->gc_scope` GC, foreground from a
tunable `::slickprop_highlight_color`. Default **theme-aware**: `#ffffff` on dark,
`#101010` on light (computed in `build_colors` from `dark_colorscheme`); if
`::slickprop_highlight_color` is set, it overrides unconditionally (matches the
`slickprop_warn`/`slickprop_accent` precedent). Name it "scope-highlight color,"
keep "white" as the dark-theme default in the docs.
*→ Please confirm the default policy (theme-aware vs. fixed) and the two colors.*

### D2 — where it's drawn & persistence  *(needs a human call)*

**Recommendation:** render it as a **sibling of the selection overlay at the end
of `draw()`** — a new `draw_scope_highlight()` called right after
`draw_selection(...)` (`draw.c:5571`), guarded by `if(xctx->scope_hi_n > 0)`.
This reuses the exact persistence mechanism characterized in §1.1: it re-strokes
on every redraw while active, and **clearing is just `count = 0; draw()`** — no
XOR erase, canvas returns pixel-identical (§1.1). Ownership of re-render after
pan/zoom is therefore the standard `draw()` path; the form does **not** own
redraw correctness, only *what set* is active.
*→ Confirm: end-of-`draw()` hook + full-redraw clear (vs. a form-owned separate
redraw step).*

### D3 — the C↔Tcl command shape

**Recommendation:** keep the invariant trivially true by making **C resolve the
set the same way Apply does**. Extract the §1.3 scope block into a shared helper
and call it from *both* `apply_symbol_prop` and the highlight command:

```
int scope_targets(int displayed_inst, const char *scope, int *targets);  /* editprop.c */
```

Commands (scheduler branch near `apply_properties`, `xschem_cmds_a`):
- `xschem highlight_scope <scope> <displayed_id>` → resolve via
  `inst_index_from_id` + `scope_targets`, store the resulting **instance ids**,
  redraw; **return the space-separated id list** (so a test can assert
  outlined == applied set).
- `xschem highlight_scope` (no args) → return the current overlay **count**
  (queryable: active-while-open, 0 after close).
- `xschem highlight_scope clear` → set count 0, redraw.

Plus, for the general-primitive test only (see D7), a thin general entry:
- `xschem highlight_objects {id …}` → store an explicit typed-object list and
  redraw (lets the suite prove wire-as-line rendering without the dialog using
  it). *Optional; include iff we want the wire-shape test (recommended).*

Store **ids**, not indices (survive reindexing); resolve id→index at draw time.

### D4 — outline thickness / halo

**Recommendation:** a **fixed screen-pixel width** (e.g. 2 px) set once on the
dedicated GC via `XSetLineAttributes`, so a thin wire/instance-bbox reads as a
halo and the cue is zoom-independent (we draw in screen coords via the temp
primitives, so this does *not* vary with zoom the way cairo text extents do).
Start plain-but-slightly-thick; revisit offset/halo in H3 only if it reads poorly.

### D5 — interaction with the selection draw / erase correctness

**Recommendation:** draw the scope overlay **after** `draw_selection` so the
white sits on top (most visible). For instances the cues barely overlap anyway
(selection recolors the symbol's own strokes; the scope cue is a **bbox** — see
D7/shape), so both read clearly. Erase correctness is automatic under the
full-redraw model (D2): no incremental erase, so close leaves the canvas as it
was by construction.

### D6 — "All" cost

**Recommendation:** accept the O(n-instances) scan in `scope_targets` for `all`.
It runs only on open / scope-change / Next-Prev (a few times per dialog), **not
per frame**. No cap needed; add a `dbg()` note. (A 10⁴-instance sheet would still
be one linear pass per user action — negligible.)

### D7 — outline = *applied set*; the displayed object defines the edited kind  *(RATIFIED)*

**The tension.** Spec §1 prose says **"All Selected — every selected *object*
gets a white outline"** and calls out the **wire-as-a-line** case. But §1.3 shows
Apply only ever writes **instances** (even `selected` filters to `ELEMENT`), and
the brief's *single most important invariant* is **outlined set == applied set**.
If a selection contains wires/rects/text (or instances of *different masters*),
"outline every selected object" and "outline == applied" **cannot both hold**.

**Ratified rule (user, 2026-06-14):** *"If instances of different cells (masters)
or different object types are part of the selected set, the object that would be
edited if the form were set to 'Only current' would decide which of the objects
would get the 'being edited' outline highlight."*

➡ The **displayed instance** (the "Only Current" target, `nav(disp_id)`, master
M) defines the **edited kind**. The outline marks exactly the objects an edit of
M would touch:
- **current** → the displayed instance.
- **selected** → the selected instances whose master **== M** (a selected `res`
  is outlined when the displayed instance is a `res`; a selected `capa`, a
  selected wire, etc. are **not**).
- **all** → every instance of master M on the sheet (already same-master).

So `selected` and `all` differ only by *selection membership*; **both are
same-master-filtered by the displayed instance**. This keeps **outlined ==
applied** true by construction (§D3 shared helper) and matches the user's rule.

**Consequence for the apply path (deliberate, ratified via D3 + D7).** Today
`apply_symbol_prop`'s `selected` scope writes *all* selected `ELEMENT`s
regardless of master (`editprop.c:887–890`). Sharing the helper makes the
**apply** `selected` scope same-master-filtered too — a small refinement of the
shipped *All Selected* behavior for **mixed-master** selections only. **Verified
no existing test regresses:** the only `selected`-apply tests (PF21, PF25,
`tests/property_form/body.tcl:381–409`) select **three `res` instances** (all
same master as the displayed R1), so they stay green. A new test should cover the
mixed-master case (select 3×`res` + 1×`capa`, displayed = a `res`, scope
`selected` → 3 outlined and 3 applied, the `capa` untouched).

**Primitive stays general.** The render function still dispatches all 7 types in
natural shape (wire-as-line included); the wire-shape rendering is proven by a
direct `highlight_objects` test (§D3), even though the dialog only ever feeds it
instances.

---

## 3. Resulting shape (if the recommendations are ratified)

**C (engine):**
- `Xschem_ctx`: `GC gc_scope;` + overlay store `unsigned int *scope_hi_id; int
  scope_hi_n;` (instance ids for the dialog; the general path can store typed
  pairs if D3's `highlight_objects` is included).
- `create_gc`/`free_gc`/`build_colors`: create/free/color the `gc_scope` GC
  (theme-aware per D1), fixed 2px line width (D4).
- `editprop.c`: `scope_targets(displayed_inst, scope, targets)` extracted from
  the §1.3 block and shared with `apply_symbol_prop`. Per D7, the `selected`
  case gains a **same-master filter** (`xctx->inst[k].ptr ==
  xctx->inst[displayed_inst].ptr`), so `selected` and `all` both key off the
  displayed instance's master.
- `draw.c`: `draw_scope_highlight()` — `draw_selection`'s per-type dispatch over
  the overlay list, stroked with `gc_scope`, instances as **bbox**
  (`drawtemprect` on `xx1,yy1,xx2,yy2`, the no-text bbox) rather than a full
  symbol re-stroke (keeps it visually distinct from selection); called after
  `draw.c:5571`, guarded by `scope_hi_n > 0`.
- `scheduler.c` (`xschem_cmds_a`): the `highlight_scope` (+ optional
  `highlight_objects`) command(s) from D3.

**Tcl (`property_form.tcl`):**
- `slickprop::update_highlight` → `xschem highlight_scope $::slickprop_apply_scope
  $nav(disp_id)` (guarded on `disp_id` present, like `do_apply`).
- Hang it off the **three existing triggers**: append to `apply_scope_greying`
  (scope change), call at the tail of `load_pos` (open + Next/Prev), and call
  `xschem highlight_scope clear` in **both** `ok` and `cancel`.

This keeps the contract thin (form feeds C a scope + a stable id; C owns drawing)
and the "outlined == applied" invariant true by construction (both go through
`scope_targets`).

---

## 4. Test plan (RED-first, headless, pixel-free) — for after ratification

Add to `tests/property_form/body.tcl` (run via `wrap.tcl`; suite at 91 checks,
keep green). Mirror P3's `pf_form_run <scope> { … }` modal driver (poll until
built, run body, capture into `::globals`, close; cancel every `after`).

- **Target set per scope (high-value, pixel-free):** assert the id list returned
  by `xschem highlight_scope <scope> <disp_id>` **==** the Apply set for the same
  scope — `current` = 1 id, `selected` = N selected-instance ids, `all` =
  same-master count; an unrelated master (e.g. a `capa`) is untouched.
- **Active-while-open / cleared-on-close:** `xschem highlight_scope` (no args)
  returns the count > 0 while the modal lives; **0** after `ok` and after
  `cancel`.
- **Live update:** after `slickprop::nav 1` under *Only Current*, the single
  highlighted id follows `nav(disp_id)`; after switching the scope var, the count
  changes to the new scope's size.
- **Primitive generality (D7):** if `highlight_objects` is included, feed it a
  wire id and assert it is accepted/stored (proves the wire path exists);
  wire-as-line vs. box is an **eyeball** item, noted for manual verification.

**Sabotage after green** (per the brief): freeze the highlight set to the
selection only → the *All*-scope target-set test reddens; make the command ignore
`clear` → the cleared-on-close test reddens. Revert.

Pixel correctness (does it look white, halo thickness, distinct-from-selection) is
an **eyeball** item — note in the spec for manual verification, not a suite assert.

---

## 6. Ratified decisions (user, 2026-06-14)

| # | Decision | Ratified answer |
| --- | --- | --- |
| **D1** | scope-highlight color | **Theme-aware + tunable** — default `#ffffff` on dark scheme, dark/high-contrast on light (from `dark_colorscheme` in `build_colors`); `::slickprop_highlight_color` overrides. |
| **D2** | persistence / where drawn | **End-of-`draw()` hook + full-redraw clear** (sibling of `draw_selection` after `draw.c:5571`; clear = `count=0; draw()`, no XOR erase). |
| **D3** | command / source of truth | **Extract & share `scope_targets()`** between apply + highlight; include the optional general **`highlight_objects`** command for the wire-shape test. |
| **D4** | thickness | Fixed ~2 px screen-width halo on the dedicated GC (zoom-independent). |
| **D5** | draw order / erase | Scope overlay **after** selection; erase automatic under full-redraw. |
| **D6** | "All" cost | Accept O(n) scan per user action (not per frame). |
| **D7** | outlined set | **Outline = applied set; the displayed instance's master defines the edited kind.** `selected`/`all` both same-master-filtered. Apply's `selected` scope gains the same filter (no existing test regresses). |
| shape | instance outline | **Bounding box** (no-text bbox), distinct from selection's symbol re-stroke. |

## 7. Implementation plan (RED-first, per spec phasing) — *next session*

> This session is **planning only** (no build code, per the user). The following
> is the ratified work list for the implementation session.

1. **H1 — primitive + Only Current.** Add `xctx->gc_scope` (D1) +
   create/free/`build_colors`; the overlay store + `draw_scope_highlight()` after
   `draw.c:5571` (D2/D4/D5, instance = bbox); `xschem highlight_scope <scope>
   <id>` / `(no args)` / `clear` (D3); `scope_targets()` extracted from
   `apply_symbol_prop` (D3) with the D7 same-master filter; the general
   `highlight_objects` (D3). Wire the form: `slickprop::update_highlight` off
   `load_pos` (open + Next/Prev) and `highlight_scope clear` in `ok`/`cancel`.
   **RED-first tests:** target-set==applied-set (current), active-while-open / 0
   after close, live update on Next/Prev, wire-as-line accepted via
   `highlight_objects`.
2. **H2 — the other scopes.** Drive `selected` + `all` through the shared
   `scope_targets()` (outlined==applied by construction); refresh off the
   `::slickprop_apply_scope` write trace. **Tests:** per-scope target-set
   (`selected` same-master, `all` same-master, the mixed-master case from D7 —
   `capa` neither outlined nor applied).
3. **H3 — polish.** Theme-aware/tunable color final pass (D1), halo thickness
   (D4), redraw/erase correctness across pan/zoom with the dialog open (D2/D5).

**Throughout:** sabotage after green (freeze set→`all` test reddens; ignore
`clear`→close test reddens); references by **stable id**; keep the 91-check suite
green; commit per phase (`feat(forms): … H1/H2/H3`, `test(forms): … RED/GREEN`);
update `doc/claude/specs/apply_scope_highlight.md` status,
`doc/multi_instance_property_editing.md`, and
`doc/claude/code_analysis/multi_instance_editing_tutorial.md`. Pixel correctness (looks
white, halo, distinct-from-selection) = manual eyeball, not a suite assert.

---

## 8. H3 manual eyeball checklist (the pixel items the suite can't assert)

H1/H2/H3 made the apply-scope highlight functionally complete and
state-tested (PF36–PF51, suite 136). What remains is **visual** verification — it
cannot be asserted headlessly, so confirm these by eye on a real display (open
**Edit Properties** on an instance; menu or `q`):

- [ ] **Visible & distinct on the DARK scheme** — a clear white outline, readable
      as a *second* cue next to the selection recolor (both show on a selected,
      in-scope instance).
- [ ] **Visible on the LIGHT scheme** — the default flips to near-black
      (`#101010`); confirm it does not vanish against the light background.
- [ ] **Halo reads as a halo** — the ~2px stroke sits as an outline, not lost in
      the symbol; try `set slickprop_highlight_width 3` (then reopen) for a
      thicker halo, and `set slickprop_highlight_color #00e0ff` for a custom hue.
- [ ] **Per-type natural shape** — an instance as its bbox, a **wire as its line
      segment**, rect/line/poly/arc/**text (bbox)** each in shape (drive the
      general primitive from the CIW: `xschem highlight_objects text <id> wire
      <id> …` then `xschem redraw`).
- [ ] **Scope tracks live** — switch "Apply to" current → All Selected → All
      (same symbol): the outlined set repaints to match each scope, including
      unselected same-master instances under *All*.
- [ ] **Next/Prev follows** — under Only Current the single outline moves with the
      displayed instance.
- [ ] **Survives pan/zoom** — with the form open, pan and zoom; the outline stays
      on the right objects at the new viewport.
- [ ] **Clears on close** — OK / Apply-then-close / Cancel removes the outline;
      the canvas returns to exactly its prior appearance.
- [ ] **Mixed selection (D7)** — select instances of two masters (e.g. a res and
      a capa) plus a wire, edit a res under All Selected: only the **res**
      instances outline (== what OK writes); the capa and wire do not.

Tunables (set before opening the form): `slickprop_highlight_color`,
`slickprop_highlight_width`.
