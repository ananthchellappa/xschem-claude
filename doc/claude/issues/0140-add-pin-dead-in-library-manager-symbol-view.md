# 0140 — Add-Pin (`p`) dead in a library-manager symbol view

**Status:** FIXED (not pushed)
**Branch:** fluid-editing
**Area:** view-aware Add-Pin form (`src/xschem.tcl` `addpin::place_verb`) + `xschem get` dispatch
(`src/scheduler.c`). Spec `doc/claude/specs/schematic_add_pin.md`.
**Reported by:** user, 2026-07-24.
**Test:** `tests/headless/test_add_pin_lib_symbol_view.tcl` (12 checks, in run_regression hcases).
**Teaching write-up:** `doc/claude/code_analysis/view_detection_display_name_trap.md`.

## Symptom

In the symbol editor, pressing `p` opens the Add-Pin form. Type a pin name, move the mouse onto
the canvas → **no cursor preview**. Click → **nothing is placed**.

Reproduces ONLY for a symbol opened from a library: an **existing** symbol, or one made by
**Tools → Make symbol from schematic** then opened. A **fresh `untitled.sym`** (File → New Symbol,
`clear force symbol`) works normally — which masked the bug and made it look intermittent.

## Root cause

The form is view-aware: `addpin::place_verb` (xschem.tcl) picks the C verb by the current view —
symbol → `add_symbol_pin` (PINLAYER rect), schematic → `add_sch_pin` (ipin/opin/iopin instance).
It decided the view with a **display-name string match**:

```tcl
return [expr {[string match {*.sym} [xschem get current_name]] ? "add_symbol_pin" : "add_sch_pin"}]
```

`xschem get current_name` returns the **display** reference, not the file path. For a symbol inside
a registered library, `rel_sym_path` → `lib_qualified_rel` (library_defs.tcl:293) returns the
portable **`lib/cell`** form and **drops the `.sym`** (via `file rootname`). So:

| view opened as | current_name | `*.sym` match | verb chosen |
|---|---|---|---|
| `untitled.sym` | `untitled.sym` | 1 | `add_symbol_pin` ✓ |
| library symbol | `mylib/cell` | **0** | **`add_sch_pin`** ✗ |
| schematic | `x.sch` | 0 | `add_sch_pin` ✓ |

`add_sch_pin -place` is a **no-op in a symbol view** by design (scheduler.c:1774
`if(editing_symbol_view()) { Tcl_ResetResult(interp); return TCL_OK; }`). So the form armed the
wrong verb, which silently did nothing: no `START_SYMPIN`, no preview, no drop.

The deeper defect: **two different oracles for "is this a symbol view."**
- C `editing_symbol_view()` (actions.c:2435) tests the **real loaded path** `xctx->sch[currsch]`
  ending in `.sym` — correct even for lib/cell display refs (the file on disk is still `.sym`).
- `place_verb` tested the **display name** — a lossy projection that drops `.sym` for libraries.

`add_sch_pin`'s own guard used the C oracle (true) while `place_verb` used the string oracle
(false). Disagreement → the form routed a click into a verb that refused it.

## Fix

Give Tcl the **same** oracle the C guard uses.

1. `src/scheduler.c` — expose it: `xschem get editing_symbol_view` → `my_itoa(editing_symbol_view())`.
   Placed in **`case 'e'`** of the `switch(argv[2][0])` get-dispatch (@3620). A `get` arg in the
   wrong first-letter case is silently unreachable (returns ""). This bit us mid-fix — the
   branch first went into `case 'c'` (next to `current_name`/`currsch`) and `get` returned "".
2. `src/xschem.tcl` — `place_verb` now returns
   `[expr {[xschem get editing_symbol_view] ? "add_symbol_pin" : "add_sch_pin"}]`.

The check is now **name-independent**: it reads `xctx->sch[currsch]`, identical for
`untitled.sym`, a plain-path `.sym`, and a `lib/cell` library ref.

## Verification

- Repro of the exact failing condition headlessly: a symbol saved under a `pathlist`-registered
  library root loads with `current_name = mylibroot/cell1` (no `.sym`); `place_verb` now returns
  `add_symbol_pin`, the preview arms (`START_SYMPIN` set), one PINLAYER rect is created.
- Real GUI e2e on the lib/cell symbol: `p` → form → type `VDD` → motion → click → pin placed,
  `name=VDD`.
- No regression: `test_sch_add_pin` 21/21, `test_sympin_drop_log` ALL PASS, `test_pin_type_edit`
  19/19, `test_crossview_paste`, `test_add_wire_label`, `test_sky130a_libmgr`,
  `test_gf180mcud_libmgr` all green.

## Scope / follow-ups

- Only `place_verb` used the display-name heuristic for a view decision (grep of `*.tcl` for
  `current_name`); `xschem.tcl:12641` (`abs_sym_path [xschem get current_name] {.sym}`) is a
  benign path construction, not a view test.
- Pre-existing, unrelated (documented in the spec, F3): the whole form mechanism binds the MAIN
  window canvas `.drw` only, so the multi-name **queue advance** and canvas-Esc do not work in a
  detached window / non-first tab (`.xN.drw`). Single-pin placement (this issue) is unaffected —
  the drop commits through the C callback in whatever window it lands.
