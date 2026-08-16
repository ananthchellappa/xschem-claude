# 0393 — a placement form's `abort_if_placing` deselects (`deselect=1`) where the ESC terminal honours `escape_deselects` (default 0)

Status: **OPEN** — measured during D7 (issue 0245), deliberately NOT fixed there.
Area: `src/xschem.tcl:10999` (`addpin::abort_if_placing`), `:11346` (`addlabel::`),
`src/create_instance.tcl:39` (`ciform::`) vs `src/scheduler.c:1695` (`xschem abort_operation`
no-arg ⇒ `deselect = 1`) vs `src/callback.c` `escape_terminal()` (⇒ `escape_deselects`,
`src/xschem.tcl:15884`, default 0).
Found: 2026-08-10, D7 scout/measure for **0245**.
Related: **0245** (the canvas-ESC terminal), **0122** E1/E2.

## The claim

All three placement forms tear a live preview down with

```tcl
proc X::abort_if_placing {} { if {[X::placing]} { catch {xschem abort_operation} } }
```

`xschem abort_operation` with no argument is `deselect = 1` (`scheduler.c:1697`), so **closing a
form while a preview is armed clears the selection**. Plain canvas ESC does not: it passes
`escape_deselects`, whose default is 0.

So two routes that a user reads as "the same Escape" have different selection semantics, and which
one they get depends on whether a preview happened to still be attached.

## Why 0245 did not fix it

0245's fix puts the C terminal at the **canvas** Escape only (`X::canvas_escape`), leaving
`X::escape` — which the form's own **Close button** and the form-focused `<Key-Escape>` both call —
untouched. `abort_if_placing` is also the teardown for the WM-close / `on_destroy` route, which
must NOT reach the terminal (it must not set `tclstop=1`). Making the deselect consistent therefore
means deciding what the *Close* route should do with the selection, which is a separate ratification
from 0245's "canvas ESC must reach C".

## To decide

Should `abort_if_placing` pass `escape_deselects` (`xschem abort_operation [expr {![...]}]`), or is
"closing a form with a live preview clears the selection" the intended Close-route behaviour?

## Test seam

`tests/headless/test_add_wire_label.tcl` / `test_sch_add_pin.tcl` can pin it headlessly:
select something, arm a preview, call `X::escape`, read `xschem get lastsel`.
