# Spec: "Apply to" scope in the Symbol editor (multi-pin editing)

Status: DECISIONS RATIFIED (D1–D4, D9 locked 2026-07-04). Ready for RED-first build.
Branch: `fluid-editing`.
Related: `doc/claude/specs/multi_instance_property_editing.md` (the schematic-editor
original), `doc/claude/specs/apply_scope_highlight.md`, `doc/claude/specs/cadence_pin_name_text.md`.

## 1. Goal

The schematic editor's Edit Properties form has an **"Apply to" selector — Only Current /
All Selected / All** — that fans changed fields across instances of the same master, greys
per-instance identity (the `name`), and draws a distinct on-canvas outline of the set that
Apply/OK will touch. The concept is meant to apply to *any* object in *any* editor.

Extend it to the **Symbol editor**, for **pins** (PINLAYER rects). When the user selects
multiple pins and opens the pin property editor:

- **Pin name** — greyed / non-editable when the apply set is more than one pin, *unless*
  every in-scope pin already has the same name. (Name is per-pin identity; never blindly
  fanned.)
- **Pin direction** (`input` / `output` / `inout`) — can be applied to *All Selected* and
  *All*.
- **Show pin-name text** (`show_pinname` on/off) — can be applied to *All Selected* and
  *All*.
- **Selection / apply-set highlight** — the affected pins are outlined on the symbol canvas
  (the same idea as the schematic apply-scope highlight), tracking the scope selector live.

## 2. Background — what already exists

Verified against current code (2026-07-04).

### 2.1 Pin data model
A symbol pin is a rectangle on `PINLAYER` (==5) whose `prop_ptr` carries tokens:
`name=`, `dir=` (`in`|`out`|`inout`), `show_pinname=true|false`, and appearance tokens
`name_dx/name_dy/name_size/name_rot/name_flip/name_font`. The visible pin-name is a
synthesised text "view" bound to the rect by `xRect.id`
(see `cadence_pin_name_text.md`, Option B). `xRect.id` (xschem.h:544) is a session-stable,
runtime-only (not persisted) identity stamped at birth in `gfx_register()` (store.c:586).

### 2.2 The two pin editors (gfxform) — already built, MODAL
`slickprop::gfx_schema` (property_form.tcl:132) defines two schemas over the same tokens:

- **`pin`** (Q on the pin body): Name (string), Direction (enum), Show name (bool) —
  property_form.tcl:146-149, plus hidden appearance mirrors (162-167).
- **`pinname`** (Q on the displayed name text, which C retargets onto the owning pin):
  Text size, Font, Offset x/y, Rotation, Flip — property_form.tcl:150-157, plus hidden
  identity mirrors (159-161).

`gfxform::selected_type` (xschem.tcl:9968-9981) returns `pin` for a `col==5` rect (or
`pinname` when C set `::gfxform_via_name`). The dialog is built by `text_line_slick`
(xschem.tcl:10106-10207) and is **modal**: `wm transient` (10114) + `tkwait window`
(10205). Contrast `slickprop::edit_form` (the instance form), which is modeless.

### 2.3 Multi-pin fan-out ALREADY works (no scope UI)
`xschem apply_pin_prop <new_prop>` (scheduler.c:240-298) is the live Apply/OK primitive.
It already **loops every selected PINLAYER rect**, applying **changed-fields-only** via
`set_different_token(&rect.prop_ptr, new, base)` (scheduler.c:286) against
`base = sel_array[0].prop_ptr` (the primary pin). On a `dir` change it calls `pin_reorient`;
it always calls `pin_view_apply` (create/delete/sync the name view per `show_pinname`).
One `push_undo`, no-op guard, single `draw()`.

Consequence: editing *direction* or *show name* on N selected pins **already propagates to
all N today**, each pin keeping its own `name` (because names differ ⇒ not in the "changed"
set). The gap is: there is **no scope choice** (it is implicitly *All Selected*), and
**nothing stops `name` from fanning** when the user does touch the Name field.

`edit_rect_property` (editprop.c:258) is the OK-after-tkwait C path for the non-live case;
it loops all selected rects the same way, with `preserve_unchanged_attrs` force-set to 1
for `lastsel>1 && type!=ELEMENT` (editprop.c:1489-1491).

### 2.4 Selection highlight on pins — already drawn
`draw_selection` (move.c:272) strokes a `SELLAYER`-coloured outline around every selected
rect (rect case move.c:284-289), called on every redraw (draw.c:6131). Selected pins in the
symbol editor already show a selection rectangle. This is the *base* highlight; §4.4 adds
the distinct *apply-set* overlay on top.

### 2.5 Apply-scope highlight infra — already generic, only the producer is instance-locked
- Store `xctx->scope_hi_{type,id,n,alloc}` (xschem.h:1161) is a generic
  `{object-type, stable-id}` list; `add_scope_highlight(type,id)` (draw.c:5639),
  `clear_scope_highlight()` (draw.c:5634).
- `draw_scope_highlight()` (draw.c:5651) has a **generic per-type dispatch**; the `xRECT`
  case (draw.c:5675-5682) resolves any layer (incl. PINLAYER) via
  `gfx_index_from_id(xRECT,id,&layer)` (store.c:638) and strokes the rect in the dedicated
  theme-aware `gc_scope`.
- `xschem highlight_objects rect <id> …` (scheduler.c:3221) already feeds arbitrary rect
  ids into the overlay. **A pin is already outline-able as an apply-set member today.**
- Only `xschem highlight_scope` (scheduler.c:3179) and its resolver `scope_targets()`
  (editprop.c:877) are instance-only (`inst[]`, same-master `inst[].ptr` filter). There is
  no pin/rect resolver.

## 3. Scope semantics for pins

| Scope         | Target set (pins) |
|---------------|-------------------|
| Only Current  | the primary pin only (`sel_array[0]`, the pin whose props are shown) |
| All Selected  | every currently selected PINLAYER rect |
| All           | every PINLAYER rect in the current symbol (there is no "master" for a pin — **D1**) |

Because a symbol has no instance-master grouping, **"All" = all pins of this symbol**
(the natural analog of "all instances of this master"). This makes "select one pin, scope =
All, toggle Show name" a first-class gesture.

## 4. Behaviour spec

### 4.1 Field disposition in the `pin` editor
| Field          | Token          | Multi-pin behaviour |
|----------------|----------------|---------------------|
| Name           | `name`         | **Per-pin identity.** Editable only when the apply set is 1 pin, OR every in-scope pin already shares the same `name`. Otherwise greyed and excluded from apply. **D2** |
| Direction      | `dir`          | Fans to the whole scope (Only Current / All Selected / All). |
| Show name      | `show_pinname` | Fans to the whole scope. |

Changed-fields-only stays the rule: only fields the user actually edited are written to
each target; every other token on each pin is preserved (`set_different_token`).

### 4.2 Name greying rule (D2, precise)
Grey (disable) the Name entry when: **in-scope pin count > 1 AND the in-scope pins' `name`
tokens are not all identical.** A greyed Name entry is excluded from the change set (its
value stays == loaded, so `collect_changes`/`set_different_token` omit it). When the scope
is a single pin, or all in-scope names coincide, the Name entry is editable; editing it then
fans the new name to the whole scope. (Fanning a name to multiple pins yields duplicate pin
names, which the existing `xschem check_pin_names` ERC already flags — acceptable, the user
opted in by selecting a same-named set.)

The greying must re-evaluate live when the "Apply to" selector changes (a write-trace on the
scope var, mirroring `slickprop::apply_scope_greying`, property_form.tcl:818).

### 4.3 Default scope (D3 — RATIFIED: Only Current)
Default = **Only Current**, for cross-editor consistency with the instance editor ("the same
selector, the same mental model, everywhere"). Note this is a **behaviour change** from
today's implicit *All Selected* (§2.3): after this change, a multi-pin edit touches only the
primary pin unless the user widens the scope. `apply_pin_prop` with no scope arg keeps
defaulting to `selected` (back-compat for existing callers / replay logs, §5.2) — only the
**form** seeds the selector to `current`.

### 4.4 Apply-set highlight
While the pin editor is open, outline exactly the scope's target set on the symbol canvas
using the existing generic overlay (§2.5), in the theme-aware `gc_scope` (distinct from the
`SELLAYER` selection outline). The overlay tracks the "Apply to" selector live and clears on
OK/Cancel. Single source of truth: the highlighted set is produced by the *same* resolver as
the apply (§5.1), so outlined-set == applied-set by construction.

Reuse tunables `::slickprop_highlight_color` / `::slickprop_highlight_width`.

### 4.5 Modality (D4)
Keep gfxform **modal** for v1 (a scope selector works fine in a modal form — the combobox
callback runs in the event loop `tkwait` is already servicing, so it can call the highlight
command and force a redraw). Making the pin editor modeless like the instance form is a
separate, larger effort — out of scope here.

## 5. Architecture / touch points

### 5.1 New shared resolver (single source of truth)
```c
/* editprop.c (near scope_targets) */
int pin_scope_targets(int primary_n, const char *scope, int *targets);
/*  current  -> { primary_n }
 *  selected -> every sel_array[] entry with type==xRECT && col==PINLAYER
 *  all      -> every index in rect[PINLAYER][0 .. rects[PINLAYER])
 *  returns count; targets[] are indices into rect[PINLAYER][].            */
```
Both the apply path and the highlight path resolve through this. (Analogous to
`scope_targets()` for instances, but rect/PINLAYER instead of `inst[]`/master.)

### 5.2 Scope-aware apply
`xschem apply_pin_prop [<scope>] <new_prop>` (scheduler.c:240) — accept an optional leading
scope arg (`current`|`selected`|`all`; default `selected` when omitted, for back-compat with
any existing caller/replay log). Replace the inline `for(i<lastsel)` PINLAYER loop
(scheduler.c:258-293) with iteration over `pin_scope_targets(sel_array[0].n, scope, …)`.
Baseline for `set_different_token` stays the primary pin's prop.

### 5.3 Name-uniformity helper (for greying)
`xschem pin_scope_prop_uniform <scope> <token>` → `"1"`/`"0"` — resolves `pin_scope_targets`
and reports whether `get_tok_value(rect.prop,token,0)` is identical across the set. Lets the
Tcl form implement the D2 rule without duplicating the resolver.

### 5.4 Apply-set highlight producer
`xschem highlight_pin_scope <scope>` / `highlight_pin_scope clear` (scheduler.c, beside
`highlight_scope`) — `pin_scope_targets` → `clear_scope_highlight()` +
`add_scope_highlight(xRECT, rect[PINLAYER][t].id)` for each target → `draw()`. (Or, if we
prefer zero new C command surface, the Tcl form can enumerate the ids and call the existing
`xschem highlight_objects rect <id> …`; the dedicated command is preferred for single-source
parity with §5.2.)

### 5.5 Tcl form changes (gfxform, in property_form.tcl / xschem.tcl)
- Sticky `::gfxform_pin_scope` (current|selected|all), default per D3.
- "Apply to" `ttk::combobox` added to the `pin` form header (only for the `pin` type).
- `gfxform::pin_scope_greying` — write-trace on the scope var: disable Name per §4.2 (via
  `pin_scope_prop_uniform name`), refresh the highlight.
- `gfxform::update_pin_highlight` — call `highlight_pin_scope` on open + scope change; clear
  in `ok`/`cancel`.
- `gfxform::ok` / `gfxform::apply` (xschem.tcl:10083-10101) pass `$::gfxform_pin_scope` to
  `apply_pin_prop`.

## 6. Test plan (headless, RED-first + sabotage, per repo discipline)

- **C resolver / apply** (`tests/…`): place a symbol with pins A(in) B(out) C(inout);
  select A+B; `apply_pin_prop current "…dir=inout…"` → only A; `apply_pin_prop selected` →
  A+B; `apply_pin_prop all` → A+B+C. Names never overwritten unless in the changed set.
  Sabotage: force scope=selected in the resolver ⇒ the current/all checks flip.
- **Name greying / uniformity**: `pin_scope_prop_uniform name` = 0 for A+B (distinct),
  1 for a same-named pair; drives the disabled-Name assertion. Form-driven test opens the
  real editor (as the property_form PF-suite does) and asserts the Name entry state +
  exclusion from the applied set.
- **Highlight**: `highlight_pin_scope <scope>` target-set == apply set per scope; overlay
  active while open, cleared on close; survives a redraw. Sabotage: neuter the resolver ⇒
  outline count diverges from apply count.
- Netlist golden (`tests/headless/run.sh`) unchanged (display-only feature).

## 7. Out of scope / future

- **`pinname` editor scope** (text size/font/offset/rot/flip fanning to a scope). Natural
  next step — none of those tokens is an identity, so all could fan — but multi-`pinname`
  editing needs the Q-on-name-text path to stop collapsing the selection to one pin
  (editprop.c:1469-1480). **D9**: defer to a later phase.
- **"Values differ" red footer** cue when an in-scope field is non-uniform (the instance
  form's P3). Optional polish.
- **Scope for generic gfxform types** (rect/line/poly/arc). The user's ask is pins; the
  machinery generalises, but not built here.
- **Modeless pin editor** (§4.5).

## 8. Open decisions (ratify before build)

- **D1** ✅ "All" = all pins of the current symbol (only sensible analog).
- **D2** ✅ Name greying rule = §4.2 (from the user's brief).
- **D3** ✅ Default scope = **Only Current** (§4.3); a behaviour change from today's implicit
  All-Selected, accepted for cross-editor consistency.
- **D4** ✅ Keep modal for v1.
- **D9** ✅ Defer the `pinname` editor; **v1 = the `pin` editor only**.
