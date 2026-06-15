# Issue 0009 — the property editor form blocks schematic interaction (not fully modeless)

**Opened:** 2026-06-14
**Status:** OPEN — root cause verified; design path sketched; not implemented.
**Affects:** the slick instance property form (`slickprop::edit_form`,
`src/property_form.tcl`). While it is open, the schematic window accepts only
**selection** (Shift-click add, via M1) and **zoom** — every other command is
blocked, and the form keeps window focus.
**Severity:** medium (workflow friction; Cadence imposes no such restriction —
its property forms are fully modeless).
**Reported:** "with the property editor form active I can Shift-click to add to
the selection and zoom, but cannot otherwise interact with the schematic; I want
to click the schematic title bar to make it active and run commands. The form
refuses to yield focus."
**Related:** the slick forms / **M1 modeless-selection** work
([[slick-property-forms]]); the input/semaphore dispatcher
([[action-registry]]). Builds directly on M1 — this is "M2: full modeless".

---

## 1. Root cause (verified)

Two mechanisms, the first is the real blocker:

1. **The `semaphore >= 2` input lock.** `edit_form` raises the editor semaphore on
   open (`property_form.tcl`: `xschem set semaphore +1`, restored on close) and
   the C input dispatcher gates nearly every action on it:
   `if(xctx->semaphore >= 2) return 0;` / `break;` (e.g. `callback.c:1866`,
   `:1891`, `:3306`, and the per-chord `if(xctx->semaphore >= 2) break;` guards
   from `:3469` on). So while the form is open, key chords and most button
   gestures are dropped. **Zoom** is not semaphore-gated (a view op) and **canvas
   selection** is the one carve-out M1 added (`::slickprop_form_open` lets
   selection through at `semaphore >= 2` and fires `on_selection_changed`) — which
   is exactly the "only zoom + Shift-select work" the user sees.

2. **Focus / stacking.** `edit_form` does `wm transient .dialog [xschem get
   topwindow]` (no hard Tk `grab`). Transient keeps the dialog above the schematic
   and owning keyboard focus; combined with the input lock, clicking the schematic
   does little. `tkwait window .dialog` blocks the *calling* proc but the event
   loop still runs (that is how M1 selection reaches the canvas).

M1 deliberately unlocked **selection only** ("move/wire/place stay locked") to
avoid the form's edited-instance state going stale under a structural edit. This
issue asks to finish the job: full modeless interaction.

## 2. Expected (Cadence-style)

With the form open, the schematic window can be activated and accept **all**
commands (pan, move, wire, place, delete, descend, run any bound action), while
the form floats independently and stays consistent with the live selection. No
focus capture; no command lock.

## 3. Design path (M2 — settle before coding)

- **D1 — drop the input lock for the form.** Stop raising `semaphore` to the
  gated level for `edit_form` (or add a "form open ⇒ don't gate" path), so the
  dispatcher runs canvas actions normally. Audit what the `semaphore >= 2` guards
  protect against — some are for genuinely re-entrant operations (a gesture in
  progress), NOT the form; only the form's bump should be relaxed, not the
  in-gesture guard. (The semaphore is overloaded: "a gesture is mid-flight" vs
  "a modal-ish dialog is open" — M2 likely needs to separate these.)
- **D2 — consistency under live edits.** The form references the edited instance
  by **stable id** (nav(disp_id)). If the user deletes/replaces it on the canvas
  while the form is open, Apply/OK must no-op gracefully (id no longer resolves) —
  partly handled by the stable-id apply; verify and harden. A move/rotate is fine
  (id survives). A selection change already re-targets the form (M1
  `on_selection_changed`); extend that to cope with the edited object vanishing.
- **D3 — focus / window behaviour.** Make the form a normal top-level (or relax
  `wm transient`) so the schematic title bar can activate it; keep the form
  on-screen (not lost behind). Cadence keeps the form floating but non-capturing.
  Decide per-platform (X11 WM behaviour varies).
- **D4 — Apply-to-live-selection.** With full canvas use, the "Apply to" scope
  already keys off the live selection (M1). Confirm Apply/OK/Next/Prev still
  behave when the selection changed out from under the form.

## 4. Acceptance criteria

- With the form open, clicking the schematic activates it and **all** bound
  commands work (not just zoom/selection); the form stays open and consistent.
- Deleting the edited object on the canvas does not crash or mis-apply; Apply/OK
  no-ops on a vanished id.
- The form no longer captures focus (can be raised/activated independently).
- M1 selection-reactive behaviour is preserved (selection still re-targets the
  form).
- No regression to the genuine in-gesture re-entrancy guards (those stay).
