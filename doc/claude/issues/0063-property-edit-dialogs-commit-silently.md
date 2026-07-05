# Issue 0063 — property-edit dialogs (editprop.c) commit silently

**Opened:** 2026-07-02
**Status:** ✅ FIXED 2026-07-02 (`fluid-editing`) — `edit_property()` (the single core
all commit paths funnel through: scheduler `edit_prop`/`edit_vi_prop`, callback keys/
actions) now emits a source-able `#`-marker `# property-edit <type>: <flat-prop>` at both
commit tails (global-attrs path + the per-type dispatch tail), gated on `modified`.
Chosen over a replayable command because these dialogs edit the **whole prop string of
the live selection** and no faithful subcommand exists (`setprop` is token-level only;
line/arc/poly have no setprop; the target is the selection, not a stable id) — so per the
audit's D1 comment-line decision, a marker (skipped on replay) is logged instead of a
bogus command. Newlines are flattened (`str_chars_replace`) so the line stays one
source-able comment. Excluded: `x==2` view-only, and the slick **instance** form
(`ELEMENT && x==0`) which self-logs a real `xschem apply_properties`. `change_elem_order`
was already covered by slice-5 (logged `xschem change_elem_order -1` at scheduler + Shift-S).
Test: `test_selflog_output.tcl` §3h (5 checks: wire/rect/instance-vi/global markers +
cancel-logs-nothing), sabotage-verified. Follow-up (optional): a true replayable path
needs `setprop … allprops` for the shape types + stable selection referents (0005).
_Original triage below._

**Status (original):** OPEN — identified by the action-log coverage audit; not yet fixed.
**Severity:** HIGH — these dialogs mutate real schematic/symbol content and
`push_undo`, yet leave no action-log / CIW trace. The only property path that
logs is the "slick" instance form.
**Branch:** `fluid-editing`.
**Source:** user-requested full audit of unlogged user interactions.
**Affects:** `src/editprop.c` (contains **zero** `log_action` calls — verified),
dialogs `enter_text`/`edit_prop`/`edit_vi_prop` in `src/xschem.tcl`.
**Related:** [[action-logging]], [[slick-property-forms]]; 0061 (menu entry
points), umbrella 0071. Object-reorder overlaps 0057/0058 property-form work.

---

## 1. Symptom

Editing an object's properties through any of the non-instance property dialogs
and clicking OK changes the object but writes nothing to the log / CIW.

## 2. Root cause

`src/editprop.c` has **no** `log_action` call anywhere (`grep -c log_action
src/editprop.c` → 0). Every per-object property dialog commits through it, so the
mutation is invisible. The slick *instance* form is the lone exception: it logs
`xschem apply_properties …` from Tcl (`property_form.tcl:602`) when a field
actually changed. All other commit paths in editprop.c are silent.

## 3. Scope — unlogged commits (handlers in `src/editprop.c`)

- Edit **wire** properties — `edit_wire_property` (:444).
- Edit **rect** properties — `edit_rect_property` (:258).
- Edit **arc** properties — `edit_arc_property` (:500).
- Edit **line** properties — `edit_line_property` (:380).
- Edit **polygon** properties — `edit_polygon_property` (:576).
- Edit **existing text** properties — `edit_text_property` (:666) via `enter_text`
  (`xschem.tcl:8633`). (Contrast: placing *new* text IS logged, `callback.c:1606`.)
- **Global schematic/symbol attributes** (schprop/schvhdlprop/schsymbolprop/…) —
  text-widget path (:1339→1355) and external-editor path `edit_vi_prop` (:1344).
- **Instance attributes via external editor** (`edit_vi_prop` /
  `edit_vi_netlist_prop`, x==1) — `edit_symbol_property`→`update_symbol`
  (:1169–1173). Only the slick text-widget instance form (x==0) logs.
- **Object stacking order** ("Object Sequence number") — `change_elem_order`
  (:1181/1197), reorders inst/rect/wire/text with `push_undo`.

## 4. Fix sketch

Two consistent options: (a) mirror the slick form — have each dialog's OK handler
emit a replayable `xschem …` line from Tcl after a successful, changed commit
(needs a replayable subcommand for each object's property set; `setprop`/
`apply_properties` exist for some); or (b) add a guarded `log_action` at the
editprop.c commit sites, guarded against replay double-logging exactly as the
slick-form/C split already documents. Reorder can log `xschem change_elem_order`.
