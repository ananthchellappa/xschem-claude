# Spec — apply-scope highlight (white outline on edit targets)

*Status:* **H1 IMPLEMENTED 2026-06-14 (primitive + Only Current).** Decisions
D1–D7 ratified — see `doc/claude/code_analysis/apply_scope_highlight_decision.md` (§6
answers, §7 plan). H1 landed the `gc_scope` GC, the redraw-persistent overlay
(`draw_scope_highlight` at the end of `draw()`), the shared `scope_targets()`
(outlined == applied), the `xschem highlight_scope` / `highlight_objects`
commands, and the form wiring (`slickprop::update_highlight`). Tests PF36–PF39.
**H2 DONE 2026-06-14** (drive All Selected + All) — found already functional from
H1's shared `scope_targets` (the resolver + the scope write-trace wiring cover all
scopes); landed as characterization PF49 (per-scope target set incl. the
mixed-master D7 case) + PF50 (the previously-untested mixed-master *selected
apply*), sabotage-verified. Suite 133. **H3 DONE 2026-06-14** — text-bbox completes the
7-type primitive; halo width tunable via `::slickprop_highlight_width`; overlay
redraw-survival (D2) locked by PF51 (suite 136). The only remaining item is the
**manual eyeball checklist** (`doc/claude/code_analysis/apply_scope_highlight_decision.md`
§8) — pixel/visual verification the headless suite cannot assert.
This is the on-canvas highlight that was deferred to backlog throughout the
multi-instance property-editing work
([[multi_instance_property_editing]] §3 "deferred", §4 "highlight", §6.E). It
builds on the slick property form ([[slick-property-forms]]) and the stable
object handles ([[stable-object-handles]]).

*Summary:* while the **Edit Properties** form is open, draw a **white outline**
around exactly the objects an **OK / Apply** would write to — the *apply-scope
set*. The outline is a **second, distinct highlight style**, separate from the
existing selection highlight, so the user can see at a glance *which* objects the
current "Apply to" scope reaches. It tracks the scope live: change the dropdown
or step with Next/Prev and the white outline follows.

---

## 1. The user-visible behavior

While the property form is open:

- **Only Current** — the **one displayed** instance gets a white outline.
- **All Selected** — **every selected object** gets a white outline.
- **All (same symbol)** — **every instance of the same master** in the current
  schematic window gets a white outline, *including ones that aren't selected*.

The outline is drawn **around the object's own shape**, per type:

| Object | Outline shape |
| --- | --- |
| Instance (symbol) | the symbol's bounding box / outline |
| **Wire** | **the wire itself — a line** (a wire *is* a line; its "outline" is the segment) |
| Rectangle | the rectangle |
| Line | the line |
| Polygon | the polygon |
| Arc | the arc |
| Text | the text bounding box |

> The wire case is called out deliberately: the highlight primitive must render
> each type in its **natural geometry**, not force everything into a box. For a
> wire that means stroking the segment. (See §5 — `draw_selection` already does
> exactly this per-type dispatch; the white outline reuses that shape logic.)

The white outline is **visually distinct** from the existing selection highlight
(which recolors selected objects). A selected, in-scope object shows *both* cues:
"selected" and "will be written." The outline **clears** when the form closes
(OK / Apply-then-close / Cancel) — it is purely a transient editing aid.

> **Note on "objects" vs "instances".** The property form's *apply* only writes
> to instances (and "All" is defined by *symbol master*, which only instances
> have). But the highlight should be a **general** mechanism that can outline any
> drawable type in its natural shape — both because **All Selected** may include
> non-instance objects in the selection, and because a reusable "white outline a
> set of objects" primitive is useful beyond this dialog. The dialog is the first
> *consumer*; the primitive should not be instance-only.

---

## 2. Why this is its own highlight, not the selection highlight

XSCHEM today has exactly **one** object-marking style: the selection highlight,
drawn by `draw_selection()` (`move.c:210`) with the select-layer GC
(`xctx->gc[SELLAYER]`, `SELLAYER=2`). It iterates `xctx->sel_array[]` and strokes
each object in its natural shape.

The apply-scope highlight is **different in two ways**:

1. **Different set.** Under **All (same symbol)** the highlighted set is a
   *superset* of the selection — instances the user never selected. So it cannot
   be driven off `sel_array`; it needs its own target list.
2. **Different meaning.** "Selected" and "will be written by Apply" are distinct
   facts the user benefits from seeing at once. Two cues, two styles.

So this is a **new overlay**: same per-type shape logic as `draw_selection`, but
(a) a **white** stroke, and (b) fed an **explicit target list** rather than the
selection array.

---

## 3. The scope → target-set mapping (already computed elsewhere)

The exact set to outline is *the same set the apply already computes*. Two
existing pieces define it and should be the single source of truth:

- **C:** `apply_symbol_prop()` (`editprop.c`) builds its `targets[]` from the
  scope — `current` → the displayed instance; `selected` → the selected
  `ELEMENT`s; `all` → every `inst[i].ptr == displayed master`.
- **Tcl:** `slickprop::scope_instances` (`property_form.tcl`) computes the same
  in-scope instance list (used by the P3 "values differ" warning).

The highlight must outline **this set**, by **stable id** so it survives any
reindexing while the dialog is open (the displayed instance is already passed to
the engine as a stable id via `xschem apply_properties`).

> **Design invariant:** the outlined set and the applied set are the *same set*.
> Never let them diverge — if the user sees a white outline on N objects, OK must
> write exactly those N. Drive both from one computation (a shared helper, or the
> highlight asks the engine "what would scope X touch from displayed id D?").

---

## 4. Live updates (the form must drive the overlay)

The form is modal, so the overlay has to refresh **while the dialog is open**, on
every event that changes the target set:

- **Scope dropdown change** — already a write-trace on `::slickprop_apply_scope`
  (P1/P3 hang `apply_scope_greying` / `update_warning` off it; the highlight
  refresh joins them).
- **Next / Prev** — `load_pos` changes the displayed instance; under
  **Only Current** the outline moves to the new instance.
- **Open / Close** — draw on open (initial scope), erase on every close path
  (`ok` / `apply_now`-then-close is just `ok` / `cancel`).

The likely shape (to be settled in design): a small Tcl entry point
(`slickprop::update_highlight`) that hands C the current scope + displayed id (or
the resolved id list) via a new command, plus the redraw; C holds the transient
overlay and renders it. Mirror how P1's greying and P3's warning are wired off
the same triggers.

---

## 5. How it maps onto the drawing engine (verified)

`draw_selection(GC g, int interruptable)` (`move.c:210`) is the template. It:

- loops `xctx->sel_array[]`, and per `type` strokes the object with `g`:
  - `xRECT` → `drawtemprect(g, …)`
  - `WIRE`  → `drawtempline` / `drawtemp_manhattanline` (the wire *as a line*)
  - `LINE`  → `drawtempline`
  - `POLYGON` → `drawtemppolygon`
  - `ARC`   → `drawtemparc`
  - `xTEXT` → `draw_temp_string` (or its bbox)
  - instances → their bbox / outline
- callers pass `xctx->gc[SELLAYER]` to draw and `xctx->gctiled` to erase
  (`move.c:997`, `move.c:1581`, `draw.c:5571`, `callback.c:1412…`).

The data needed is already on each object:

- `xWire`  — `x1,y1,x2,y2` (the segment), plus a stable id (stable-handles work).
- `xInstance` — `x1,y1,x2,y2` (full bbox), `xx1,yy1,xx2,yy2` (bbox sans text),
  `id` (stable, `xschem.h`).
- rect/line/poly/arc/text — their geometry + per-type stable ids.

So the new overlay is **"`draw_selection`, but over an id list and stroked
white."** The reuse is deliberate: do not reinvent per-type geometry.

---

## 6. Open design decisions (settle these first, then STOP for ratification)

These are the real choices — resolve them in a short **decision doc** before
writing code, exactly as the earlier phases did.

- **D1 — the "white" GC.** Is there a free/whitelayer GC, or must one be made
  (allocate a GC, `XSetForeground` to the theme's "white"/backlight color)?
  Should the color be a tunable (`::slickprop_highlight_color`, default white)
  like `slickprop_warn`/`slickprop_accent`? How does it read on a light theme
  (white-on-white)? Maybe theme-aware (white on dark, a dark stroke on light), or
  a fixed high-contrast color.
- **D2 — where it's drawn & persistence.** The selection overlay is a transient
  XOR/temp stroke on the live window that a full `draw()` wipes. The apply-scope
  outline must survive ordinary redraws *while the dialog lives*. Options: draw it
  at the end of `draw()` (a hook that re-strokes the current scope set if a form
  is open), or keep it as a separate redraw step the form triggers. Decide who
  owns re-rendering after a pan/zoom/redraw with the dialog open.
- **D3 — the C↔Tcl command.** Shape of the new command, e.g.
  `xschem highlight_scope <scope> <displayed_id>` (C resolves the set, like
  `apply_properties`) vs `xschem highlight_objects {id …}` (form resolves, passes
  the list). The former keeps the "outlined == applied" invariant trivially true.
  Plus a `clear` form for close.
- **D4 — outline thickness / style.** Plain stroke vs a slightly thick or
  offset outline so it reads as a halo around (not on top of) the object,
  especially for a thin wire. Account for zoom (cairo extents vary with zoom).
- **D5 — interaction with the existing selection draw.** Order of drawing
  (outline under or over the selection recolor?), and erase correctness so
  closing the form leaves the canvas pixel-identical to before it opened.
- **D6 — scope = "All" cost.** "All same-master" scans all instances each
  refresh. Fine for typical sheets; note a cap/strategy only if a sheet has tens
  of thousands of instances.

---

## 7. Phasing (incremental, each shippable)

1. **H1 — the primitive + one scope. ✅ DONE 2026-06-14.** A C overlay that
   white-outlines a given id list, reusing `draw_selection`'s per-type shape
   logic; wired to the form for **Only Current** (outline the displayed instance,
   follow Next/Prev), cleared on close. D1/D2/D3 settled and implemented.
2. **H2 — the other scopes. ✅ DONE 2026-06-14.** Drive the overlay for **All
   Selected** and **All (same symbol)**, sharing the target-set computation with
   the apply so "outlined == applied" holds by construction. (Already functional
   from H1's shared `scope_targets` + scope write-trace wiring; H2 added the
   characterization + mixed-master D7 tests, PF49–PF50, sabotage-verified.)
3. **H3 — polish. ✅ DONE 2026-06-14.** Theme-aware/tunable color (D1, H1) +
   tunable halo width (D4, `::slickprop_highlight_width`); text-bbox completes the
   7-type primitive; redraw-survival (D2/D5) locked by PF51. Pixel/visual items →
   §8 manual eyeball checklist in the decision doc.

---

## 8. Acceptance criteria

- With the form open, the white outline marks **exactly** the objects an OK/Apply
  would write to, for all three scopes; changing the dropdown or stepping
  Next/Prev updates it live.
- A **wire** in scope is outlined **as its line segment**, not a box; every
  drawable type is outlined in its natural shape.
- The outline is **visually distinct** from the selection highlight (both can
  show on one object).
- Closing the form (OK / Apply-then-close / Cancel) **removes** the outline and
  leaves the canvas as it was.
- The outlined set and the applied set are provably the **same set** (one source
  of truth).
- References are by **stable id** (survive reindexing during the session).

---

## 9. Grounding (verified code references)

- Selection draw (the per-type shape template): `draw_selection` `move.c:210`;
  drawn with `xctx->gc[SELLAYER]` (`SELLAYER` = `xschem.h:153`), erased with
  `xctx->gctiled`; callers `move.c:997`, `move.c:1581`, `draw.c:5571`,
  `callback.c:1412`.
- Temp/overlay primitives: `drawtemprect`, `drawtempline`,
  `drawtemp_manhattanline` (`draw.c:1540`), `drawtemppolygon` (`draw.c:2176`),
  `drawtemparc` (`draw.c:1572`).
- The scope → target set: `apply_symbol_prop` target build (`editprop.c`);
  `slickprop::scope_instances` (`property_form.tcl`).
- The apply already takes a stable id: `xschem apply_properties <scope>
  <displayed_id> …` (`scheduler.c`, `apply_instance_properties` `editprop.c`).
- Object geometry + ids: `xWire` (`x1..y2` + id), `xInstance` (`x1..y2`,
  `xx1..yy2`, `id`) `xschem.h:624-669`.
- Main redraw: `draw(void)` `draw.c:5328`.
- Live-update triggers to reuse: the `::slickprop_apply_scope` write trace
  (`apply_scope_greying` / `update_warning`) and `slickprop::load_pos`
  (`property_form.tcl`).

---

*Implementation walkthrough (once built) should join
`doc/claude/code_analysis/multi_instance_editing_tutorial.md`; the user guide
`doc/multi_instance_property_editing.md` gains a short "scope highlight" note.
Next step: the design-first session — see
`doc/claude/suggestions/apply_scope_highlight_session_prompt.md`.*
