# 0644 — `bind $topwin <Unmap>` has no `%W` filter, so any child unmap closes the ERC Info window and clears the preference

STATUS: **OPEN — measured 2026-08-23 by the 0616 crew.** Deliberately not fixed
there (wrong blast radius for a window-mapping item).

## The line

`src/xschem.tcl:14421`, inside `proc set_bindings {topwin}` (`src/xschem.tcl:14331`):

```tcl
bind $topwin <Unmap> " wm withdraw .infotext; set show_infowindow 0 "
```

`set_bindings` runs for **every** toplevel, and in Tk a toplevel is a bindtag of
**every descendant widget**. With no `%W` guard the script therefore fires for
the toplevel *and* for all ~54 of its descendants.

## Measured

Isolated probe — one bare `raise_activate_toplevel .` call, nothing else:

```
BEFORE: show_infowindow=1  .infotext=normal  ismapped(.)=1  wm state(.)=normal
--- calling raise_activate_toplevel . (the exact call do_run reached) ---
AFTER : show_infowindow=0  .infotext=withdrawn  ismapped(.)=1  wm state(.)=normal
unmap events seen = 56
```

**56** — that is the toplevel plus 54 descendants plus `.drw`, and it is why an
unfiltered `<Unmap>` counter written as a *test* also reads 56 instead of 1.

In a full Netlist-and-Run press (issue 0616's case C) `.infotext` went
`normal → withdrawn` across the press. Caveat recorded honestly: in that run the
**variable** read back as `1` afterwards (something re-sets it later in the run)
while the **window** was withdrawn. Assert on `wm state .infotext`, not on the
variable.

This reproduces under `xfwm4`, i.e. it needs no WSLg.

## Impact

Any re-map of a main toplevel silently closes the user's ERC Info window and
clears their `show_infowindow` preference. Issue 0616's fix removed `do_run` from
the set of things that trigger it, but **every other `raise_activate_toplevel`
caller still can** — LibMgr, CIW, `save_as_form`, `copy_form`, `create_instance`,
`alt2_toggle_view`, the wave viewer, and Session > Design Window itself.

## Why 0616 did not fix it

Rung **L2**. It is a binding installed on every toplevel by `set_bindings`; the
fix belongs with that binding, not with an ASE run path. **Also rejected there:**
using `wm state .infotext` as 0616's regression assertion — it would anchor a new
check to a live defect and go red the moment this issue is fixed.

## Fix shape

Filter on the toplevel: `bind $topwin <Unmap> [list apply {{w top} {if {$w eq
$top} {…}}} %W $topwin]`, or the cheaper `if {"%W" eq "<topwin>"}` guard the
0616 test rows use for their own counter. Then decide separately whether an
**intentional** withdraw of the main window should really clear a user
preference at all, or only hide the window.

## Acceptance

- Raising/re-mapping any toplevel leaves `show_infowindow` and `wm state
  .infotext` untouched.
- A regression row: with `.infotext` open, call `raise_activate_toplevel .` and
  assert `wm state .infotext` is still `normal`. (Cheap, display-independent, and
  a tripwire for the whole class.)
