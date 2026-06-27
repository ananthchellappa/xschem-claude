# Issue 0008 — slick graphical/text property edits are not logged (no replayable action)

**Opened:** 2026-06-14
**Status:** OPEN — design **ratified** (user chose the stable/uniform/replayable
option); not yet implemented. This file is the turnkey build brief.
**Affects:** the slick `text_line` (rect/line/poly/arc/wire) and `enter_text`
(text) dialogs — editing a graphical/text object's properties changes the
drawing but logs **nothing** to the action log / CIW, unlike the slick instance
form which logs a replayable `xschem apply_properties …`.
**Severity:** low–medium (no data loss; the gap is reproducibility — the action
log can't replay a graphical/text property edit).
**Branch:** suggest a dedicated branch off `slick-property-forms` (or master).
**Related:** the action-logging feature ([[action-logging]]); stable object
handles ([[stable-object-handles]]); the slick forms (this branch). Reported by
the user: "select a wire and change width — nothing is logged to the CIW; ditto
changing the dash of the dashed rectangle" (that object is a **poly**).

---

## 1. Why nothing logs (root cause, verified)

The action log is driven by **Tcl `xschem` commands** (`log_action` echoes to the
CIW + `Xschem.log`). The slick **instance** form applies its edit *via* a logged
command — `xschem apply_properties <scope> <id> <new> <old>`
(`property_form.tcl` `do_apply`) — so it appears. The **graphical/text** edits are
applied **C-side** *after* the dialog returns: `edit_rect_property` /
`edit_line_property` / `edit_polygon_property` / `edit_arc_property` /
`edit_wire_property` / `edit_text_property` (`editprop.c`) loop over the selected
objects and set `prop_ptr` directly. No Tcl command runs → nothing is logged.

`xschem setprop` exists only for **instance / rect / wire** (per-token, by *index*);
there is **no** command for **poly / line / arc** — and the user's object is a
poly. So today there is no replayable command to log even if we wanted to.

## 2. Ratified design (user decision)

**Replayable, stable, uniform.** Add a command that sets an object's property by
**stable id** (works for all graphical types + text), and have the slick forms log
it. Chosen over (a) per-token `setprop` for rect/wire-only + markers elsewhere, and
(b) a non-replayable comment marker. The id is stable across the session so replay
survives reindexing ([[stable-object-handles]]).

## 3. The hard part (why it's a real feature, not a one-liner)

There is **no reusable in-place reparse**. Each `edit_*_property` re-derives the
object's cached fields from the new `prop_ptr` *inline* — and they differ per type:

| Type | cached fields re-derived after prop change |
| --- | --- |
| rect | `dash`, `ellipse_a/_b`, `fill`, `bus`, `set_rect_flags`, `set_rect_extraptr`, bbox |
| poly | `dash`, `bus`, `bezier`, `fill`, bbox |
| line | `dash`, `bus`, bbox |
| arc  | `dash`, `bus`, `fill`, bbox |
| wire | `bus`, `set_wire_flags`, bbox |
| text | `set_text_flags`, xscale/yscale (size is separate), bbox |

`store_*` (store.c) derive the same fields but **create/shift** objects (not an
in-place update), so they can't be reused directly.

## 4. Plan (RED-first)

1. **Extract** the per-type reparse into shared C helpers
   `set_<type>_attrs_from_prop(obj …)` and call them from BOTH the existing
   `edit_*_property` (verbatim move → no behaviour change, guarded by the existing
   regression tests) AND the new command. Single source of truth ⇒ in-session
   apply and replayed apply are provably identical.
2. **New command** `xschem setobjprop <type> <id> <wholeprop>`: resolve by
   `<type>`+stable id (`*_index_from_id`), `bbox(START)`, `push_undo`, set
   `prop_ptr`, call the type's reparse helper, `set_modify(1)`, `bbox`/`draw`.
   `<type>` ∈ wire/rect/line/poly/arc/text.
3. **Form logging:** in `gfxform::collect`/`slicktext::collect` OK paths, after a
   real change, `slickprop::log_apply` one `xschem setobjprop <type> <id>
   <newprop>` per affected selected object (by stable id). Log-only — the C apply
   stays in-session; the logged command reproduces it on replay. (For the
   uncommon preserve-on multi-object case the per-object resulting prop should be
   logged, not the first object's; settle in D2.)
4. **Tests:** headless — `setobjprop` sets the prop (verify via `getprop`/`object`
   round-trip) and resolves by id after reindexing; the form logs exactly one line
   per affected object on a real edit, none on a no-op (mirror PF47). Rendering
   correctness (dash/fill/bezier actually redraw) is the eyeball gate.

### Open sub-decisions
- **D1 — command name/shape:** `setobjprop <type> <id> <wholeprop>` (whole string,
  matches how the slick form computes the result) vs per-changed-token. Whole
  string is simpler and matches the form; per-token reuses `setprop` but only for
  rect/wire. Recommend whole-string `setobjprop`.
- **D2 — multi-object fidelity:** with several same-type objects selected, log the
  *actual* per-object resulting prop (changed-fields-only), not the first object's
  whole prop, so replay matches a preserve-on session. Simplest correct: log the
  edited token *changes* applied per object id.
- **D3 — undo granularity:** the in-session C apply is one `push_undo`; N logged
  `setobjprop` lines would be N undo steps on replay. Acceptable (functionally
  identical end state) or batch with a `-fast`-style flag.

## 5. Acceptance criteria

- Editing a wire's width, a rect's dash, or a **poly's** dash via the slick panel
  logs a replayable `xschem setobjprop …` line per affected object (visible in the
  CIW), and sourcing the log reproduces the edit in a fresh session.
- A no-op OK logs nothing.
- References are by stable id (survive reindexing).
- No behaviour change to the in-session edit itself (the extract is verbatim).
