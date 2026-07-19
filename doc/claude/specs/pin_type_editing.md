# Easy pin-type editing (schematic parity with the symbol pin editor)

Status: v1 spec, 2026-07-19. Follows crossview_copy_paste.md. Owner: fluid-editing.

## Problem

In a schematic, a port pin's type IS its symbol (`devices/ipin|opin|iopin.sym`), so
"change pin type" today means the generic instance form + manually replacing the
symbol reference — nothing like the symbol editor, where a pin rect gets the slick
`pin` panel with a Direction field. Wanted: changing in/out/inout must be EASY and
feel the same in both views.

User-ratified slice (2026-07-19): verb + Ctrl+MMB cycle + form parity
(context-menu idea deferred).

## 1. Core verb — `xschem set_pin_type <in|out|inout|-cycle> [<inst>]`

View-aware, ONE undo slot for the whole call, returns the number of pins changed.

- Schematic view: targets = `<inst>` (name or number, must be a port instance,
  else TCL_ERROR) or, without `<inst>`, every SELECTED ipin/opin/iopin instance.
  Each target's symbol is swapped via the existing `xschem replace_symbol ... fast`
  machinery (fast = no per-instance undo/log; this branch owns the single
  push_undo), keeping name=, lab=, position, rotation, flip.
- Symbol view: targets = every SELECTED PINLAYER rect carrying name=/dir=.
  dir= is rewritten in place (name view geometry untouched — same as Cadence,
  cycling type does not move the name text).
- `-cycle` advances each target independently: in → out → inout → in.
- No-change targets don't count and don't burn the undo slot (a call where every
  target already has the requested type changes nothing, pushes nothing).
- readonly: rejected at the boundary (scheduler_readonly_reject).
- Logged raw on success (changed > 0): `xschem set_pin_type <arg> [<inst>]` —
  deterministic on replay (cycle from a replayed state reproduces itself); the
  inner replace_symbol `fast` calls self-suppress (atom-4 axis).
- Helpers `pin_sym_dir` / `dir_pin_sym` / `dir_literal` (paste.c, from the
  cross-view feature) get exported and shared.

## 2. Gesture — Ctrl+MMB cycles a PLACED pin's type

`edit.cycle_pin_type` (already bound to Ctrl+Button2 on the canvas) currently
no-ops unless the Add-Pin form is placing a preview. Extension, in
`addpin::cycle_type`:

- placing (form armed): unchanged — cycles the preview.
- otherwise: `xschem set_pin_type -cycle` on the current selection; if that
  changes nothing, click-select the object under the pointer
  (`unselect_all` + `select_at` at mousex/y_snap) and retry. Selection is left
  where it lands (Cadence click-acts-on-object; documented quirk: a Ctrl+MMB on
  empty canvas or a non-pin clears the selection).
- Works identically in both views (the verb is view-aware). Headless-safe: the
  Add-Pin-form branch is guarded by `info commands winfo`.

## 3. Form parity — `q` on a pin instance opens the pin form

`slickprop::edit_form` (the instance Edit Properties router) detects a port
instance (`[file tail $symbol]` ∈ ipin/opin/iopin.sym) and routes to
`schpin::edit_form` instead of the generic instance form:

- Fields: Name (the `lab=` token — the net/port name, what the symbol editor
  calls the pin name) and Direction (readonly ttk::combobox input/output/inout,
  matching the symbol-editor pin panel's field).
- Header bar (grey60, slick convention): `<instname> — <symbol>`.
- Modeless like the slick form (M2): OK = apply + close, Apply = apply + stay,
  Cancel/Esc = close. Same `.dialog` toplevel slot.
- Apply: lab change → `xschem setprop instance <inst> lab <val>`; direction
  change → `xschem set_pin_type <dir> <inst>`. Sets tctx::applied so the C
  caller's contract holds. Two changed fields = two undo slots (v1 accepted,
  documented).
- Target = the instance under edit at open time (name captured from
  tctx::retval's name= token, the slick header convention). Multi-select: form
  edits the first instance, like the generic form.

## Non-goals (v1)

- context-menu Pin Type submenu (idea 2 — deferred).
- atomic lab+dir single-undo apply.
- name-view relayout on symbol-view dir change.
- lab_pin/lab_wire (net labels are not ports).
- bus/range-aware renames.

## Files

- src/scheduler.c: set_pin_type branch in xschem_cmds_s (alphabetical, near
  set_modify) — [[scheduler-letter-dispatch]].
- src/paste.c + xschem.h: export pin_sym_dir/dir_pin_sym/dir_literal.
- src/xschem.tcl: addpin::cycle_type fallback + schpin:: namespace (form).
- src/property_form.tcl: pin-instance route at the top of slickprop::edit_form.
- tests/headless/test_pin_type_edit.tcl (registered in run_regression hcases).
