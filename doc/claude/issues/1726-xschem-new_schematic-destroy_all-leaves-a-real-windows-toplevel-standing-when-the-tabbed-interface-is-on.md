# 1726 — `xschem new_schematic destroy_all` leaves a real window's toplevel standing when the tabbed interface is on

**STAMP:** `v1 claim=open tree=d36cb429e stamped=2026-11-19 fix=untried open=3 by=docs5`

**Status: OPEN, filed, not fixed.** An engine defect, older than the work that met it.
**Files:** `src/xinit.c` (`new_schematic()`, `destroy_all_tabs()`, `destroy_all_windows()`,
`is_window_context()`).
**Found by** the fourth repair of issue 1724 (its command-mode package), 2026-11-19, on
the way: a later leg of `tests/headless/test_cmdmode_descend_0201.tcl` was building its
control window over a window an earlier leg had left behind. Confirmed the same day by
that repair's verifier with a probe of its own, and run once more for this file.
**Not issue 1724's.** The working tree the measurements ran on carries that issue's
uncommitted changes, but its only change to `src/xinit.c` is one line in
`free_xschem_data()`; the functions named here are as they are at `d36cb429e`.

## What happens

With the tabbed interface on (the default), a schematic can still be in a real window of
its own: `xschem new_schematic create_window` makes one (the Cadence-style profile's
Ctrl-N runs it), and so do a descend into a new window and a tab that is detached.
`xschem new_schematic destroy_all`, and the command `xschem destroy_all` that calls it,
then take that window's schematic away and leave its toplevel on the screen.

MEASURED 2026-11-19, private Xvfb with openbox, the verifier's probe run from a copy
through `tests/headless/run_suites.sh` (display arm); the lines are the probe's own, the
window list is `xschem windows` and the toplevel list is every child of `.` that has a
`.drw`:

```
tabbed_interface=1 ; windows=.drw ; toplevels with a canvas=
tabbed=1: create_window -> 1 ; windows=.drw .x1.drw ; toplevels=.x1
tabbed=1: destroy_all force -> 0 ; windows=.drw ; toplevels=.x1
tabbed=0: create_window -> 1 ; windows=.drw .x1.drw ; toplevels=.x1
tabbed=0: destroy_all force -> 0 ; windows=.drw ; toplevels=
tabbed=1: create_window -> 1 ; windows=.drw .x1.drw ; toplevels=.x1
tabbed=1: destroy .x1.drw {} -> 0 ; windows=.drw ; toplevels=
```

So with the tabbed interface on, `destroy_all` answers 0 windows left and `xschem
windows` agrees, while the toplevel `.x1` is still there. With the tabbed interface off
the toplevel goes, and `xschem new_schematic destroy <win> {}` closes such a window
properly in either setting. The verifier's run and the run made for this file printed the
same seven lines.

**What follows from the leftover toplevel**, MEASURED by the repair's package in an
instrumented copy of the descend suite: the next window made takes the same name, and
the engine prints

```
tclvareval(): error executing toplevel .x1 -bg {} -width 400 -height 400 -takefocus 0: window name "x1" already exists in parent
tclvareval(): error executing build_widgets .x1: window name "menubar" already exists in parent
```

and builds the new window over the old canvas, whose `<Visibility>` binding then holds
`net_hilight_anim_update %W` twice.

## Why — READ in the code, at the stamped revision

`new_schematic()` routes its `destroy_all` arm by the GLOBAL flag: with the tabbed
interface off it calls `destroy_all_windows()`, with it on `destroy_all_tabs()`.
`destroy_all_tabs()` walks every slot and, for each, runs the tab's teardown (`delete_ctx`,
`delete_tab`, `delete_schematic_data()`); it destroys no toplevel.

The `destroy` and `switch` arms of the same function do not route that way. They ask
`is_window_context()` about the TARGET, and the comment above that function gives the
reason in its own words: a real window handled by the tab path has its context deleted
and its toplevel never destroyed, "a zombie window". `destroy_all` was left on the global
flag.

## What was not measured

* **What a user sees.** The one caller in the product's Tcl is `quit_xschem`
  (`src/xschem.tcl`), and `xwin_exit()` calls the arm on the way out. When the quit goes
  through, the process ends and the toplevel with it. Whether any user gesture leaves the
  leftover window on the screen with xschem still running (a quit that is cancelled at
  another window's unsaved-changes question, for one) was not driven.
* **A detached tab and a window made by a descend.** Only `xschem new_schematic
  create_window` was put through the probe. The package met the defect with a window made
  by a descend (`hi_descend … target=new_window`) inside the suite; a detached tab was not
  tried.
* **Other displays.** A private Xvfb with openbox only.

## Fix direction — proposed, not built, not tried

In the `destroy_all` arm, close each slot for which `is_window_context()` is true through
`destroy_window()`, as `destroy` already does, and leave true tabs to `destroy_all_tabs()`.
Both walkers ask one unsaved-changes question for each dirty window; a fix has to keep it
at one. A row would be the probe above: after `destroy_all` with the tabbed interface on,
no child of `.` with a `.drw` is left.

## Where it is worked around today

`tests/headless/test_cmdmode_descend_0201.tcl` closes the window its leg DS6 opens by
name (`xschem new_schematic destroy $NEW {}`), with a comment naming this defect, because
the suite's later `destroy_all force` would leave it standing and leg DS8 would be built
over it. Row DS8a asserts that no window of an earlier leg is left. That is a seam in one
suite, not a cure.

## Still open (3)

1. The defect itself: `destroy_all` routes by the global flag and leaves a real window's
   toplevel behind when the tabbed interface is on. C change, not made.
2. What a user sees, and by which gesture (above): not measured.
3. No row fences it. The suite's seam hides it from the one suite that met it.

## Evidence

Session scratch of 2026-11-19, not kept in the repository: the verifier's probe
`p_destroyall.tcl` and its output; the package's instrumented run of the descend suite
(`raw_dbg1.txt`: the child list of `.` before and after `destroy_all force`, and the two
`tclvareval()` lines). The seven probe lines above are that evidence in full.
