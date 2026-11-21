# 1387 — two Tcl command modes seize one canvas, nobody decides, and neither of them works in a tab

**Branch** `fluid-editing`. **Files** `src/rdw.tcl` (`rdw::pick_start`,
`rdw::_pick_seize`), `src/ase_window.tcl` (`ase::ui::select_on_design`,
`ase::ui::sod_statusbar`, `ase::ui::sod_prompt_pump`).
**Status: NOT FIXED — filed.** Found while repairing issue **1384**; none of it
is 1384's to fix, and all of it was measured in the same runs.
**2026-11-19:** the tab half of §1 is closed (the keys arm the mode in a tab), and of §3
the label is no longer written by two pumps at once; the rest stands, the ruling §3
asks for included. See the note at the end.

Three defects that share one cause: **the design canvas has two Tcl-level
command modes and no owner**, and both of them identify the canvas by a string
that is not always a widget.

---

## 1. The RDW pick mode does nothing, and says nothing, in a tab

`rdw::pick_start` asks `winfo exists [xschem get current_win_path]` and refuses
when it is 0. In a **tab** that path is a logical name, not a Tk widget.
Measured on :99, shipped `tabbed_interface 1`, one
`xschem schematic_in_new_window force`:

```
xschem get current_win_path   .x1.drw
winfo exists .x1.drw          0        <- tabs share the ONE real .drw
xschem get top_path           {}       <- so C writes the shared .statusbar.10
rdw::pick_start               0
.statusbar.10                 | |      <- nothing on the sheet
```

So pressing `1`, `2` or `3` with nothing selected, in a tab, **does nothing and
reports nothing** — not on the status bar, not in the CIW. Every other refusal
in `rdw.tcl` names itself through `rdw::_ciw`; this one does not, because it is
a `return 0` from a proc whose callers do not check it.

**Two things are wrong and they are separable.** The silence is a bug on its
own — a refusal that changes nothing must still *say* something (this file's own
rule). And the refusal itself is avoidable: the mode does not need the logical
path, it needs the **canvas widget**, which in a tab is the shared `.drw`. The
fix that makes both go away is for the seize to hold the real widget.

⚠ **If it is fixed, issue 1384's status-bar hint has to follow.** Row `HT14` of
`tests/headless/test_rdw_window_1245.tcl` asserts the silence, so it goes red the
day the mode arms in a tab and whoever fixes it is told. `rdw::_hint_slot` is
already right for that world: with `pick(canvas)` a real widget it derives the
bar from `winfo toplevel`, and needs no tab arm at all.

## 2. `ase::ui::sod_statusbar` has the uncorrected arithmetic

```tcl
proc ase::ui::sod_statusbar {cv} {
  regsub {\.drw$} $cv {} top
  return "$top.statusbar.10"
}
```

This is the proc `rdw::_hint_slot` was copied from, and 1384 corrected the copy
without being able to correct the original — `rdw.tcl` deliberately does not
call across into `ase_window.tcl` (that file is a peer it must load without).
For a tab it answers `.x1.statusbar.10`, a widget that does not exist. Whether
it is REACHABLE there depends on what `ase::ui::design_window` hands it, which
is not measured here. **Copying a proc copies its bugs** — that is the standing
cost of the refused dependency, and it is worth writing down where the copy
lives, which `rdw::_hint_slot`'s comment now does.

## 3. The two modes fight over one canvas and one label, and nobody arbitrates

`ase::ui::select_on_design` self-serialises against **another SOD**
(ase_window.tcl:1897, "ONE mode globally") and against nothing else.
`rdw::pick_start` self-serialises against another RDW pick and against nothing
else. Both register with `cmdmode`, but that contract is about a **descend**
suspending and resuming a mode, not about two modes coexisting.

So arming select-on-design and then pressing `1` with nothing selected leaves:

* **`<ButtonPress-1>` seized twice.** `rdw::_pick_seize` latches SOD's own script
  as its predecessor and installs its own, so a click dumps to the Results window
  and never reaches SOD. Last arm wins, silently. (The inverse order is the
  mirror image.)
* **`.statusbar.10` written by two pumps.** `ase::ui::sod_prompt_pump` and
  `rdw::_hint_pump` both write that label on an 80 ms timer and neither reads
  the other.

Before issue 1384's repair pass this was worse than it looks: ASE's prompt won
the label (a timer that fires last wins) while the RDW seize won the click, so
**the status bar was describing a mode that a press would not enter**. 1384's
synchronous re-assert makes the RDW hint win the label as decisively as its
seize wins the click, so the label and the button now agree — an improvement,
but not a decision. The decision is still owed, and it belongs to whichever
layer owns the canvas:

* (a) one Tcl command mode globally, the way SOD already treats its own kind —
  `pick_start` ends a live SOD (and vice versa) and says so in the CIW;
* (b) `cmdmode` grows a claim on the canvas and refuses the second arm by name;
* (c) leave it, and document that the last arm wins.

Whatever wins, the answer must be in ONE place: two procs that both decide who
owns `<ButtonPress-1>` is invariant **I1** one canvas out.

## 4. `ase_window.tcl:1884` states a measured falsehood

The comment above `ase::ui::sod_prompt_pump` reads:

> ~80 ms => a blanking event shows at most a sub-frame flicker before the prompt
> returns; a C ui_state bit would remove even that.

Issue 1384 copied that sentence as precedent and then measured it. On :99, with
a motion timer on `.drw` and the slot sampled every 10 ms, 200 samples a cell:

| main window | motion every 16 ms | 33 ms | 50 ms |
|---|---|---|---|
| 1110x761 | 18 % visible | 16 % | 40 % |
| 1400x800 | 17 % visible | 16 % | 37 % |

It is the **prompt** that shows for a sub-frame. And because `.statusbar.10` is
packed `-side left` with no `-fill x` (xschem.tcl:16834) the slot's width follows
its text, so the same stream swung it 8 ↔ 471 px at ~12 Hz and dragged
`.statusbar.1` — the coordinate readout — between 218 and 275 px.

The measurements above were taken with the RDW hint on the label; ASE's own
prompt is a different string on the same widget under the same blank, so the
duty cycle is the same mechanism and has **not** been re-measured with SOD live.
`rdw.tcl` fixes it with a private binding tag on the canvas that re-asserts in
the same binding invocation C blanked in (100 % visible, both widths constant,
~1.3 ms of CPU per second of moving the mouse). **The same fix is available to
`sod_prompt_pump` and is not applied here** — it is another feature's file and
another feature's suite, and a change to it with no ASE row driving it would be
exactly the kind of unfenced edit this tree keeps paying for.

## What is owed

* A ruling on §3 (which layer owns the canvas, and what the second arm is told).
* §1 is a plain bug and needs no ruling: a refusal must say something.
* §2 and §4 are ASE's file and want an ASE row each.

**Nothing here was fixed.** Issue 1384's suites are green on `:99` with all of
it live, because none of it is reachable from the gestures 1384 owns.

## Note, 2026-11-19 (issue 1724, its fourth repair): the tab half of §1 is closed

Closed as §1 proposed: the seize holds the real widget.

- `rdw::_pick_canvas {ctx}` (`src/rdw.tcl`) resolves a window context to the canvas that
  shows it: the name itself when it is a widget, otherwise the `.drw` of the toplevel that
  `xschem windows` lists for that context (the main window's toplevel is `.`). It is the
  lookup `calc::pick_canvas` and `ase::ui::sod_canvas` make, written out here because
  `rdw.tcl` loads without either of those files.
- `rdw::pick_start` puts `xschem get current_win_path` through it, so `1`, `2` or `3`
  with nothing selected, in a tab other than the first, arm the mode on the main window's
  canvas with its sentence on the main window's status bar. **Measured** with a real
  second tab and real clicks: a click on a device dumps it.
- `rdw::pick_resume` puts the name `cmdmode` hands it through the same lookup, so the mode
  follows a return from a block opened in its own window to a parent that is in such a
  tab. The Calculator's pick does the same (`calc::pick_resume`), as Select On Design has
  since the third repair of that issue.
- Row `HT14` of `tests/headless/test_rdw_window_1245.tcl`, which asserted the silence and
  was written to go red on this day, is restated: the mode arms on the shared canvas with
  its sentence on the shared bar, and ending it takes all of that off again. Row XP8 of
  `tests/headless/test_rdw_keys_1245.tcl` is the key and the resume in a real second tab.

**Not closed:**

- The silence half of §1 where the mode still cannot arm (no canvas at all for the
  context): `rdw::pick_start` still answers 0 and says nothing.
- ~~`rdw::_focus_canvas` still tests the context's name as a widget, so in a tab other
  than the first no dump hands the keyboard back to the canvas.~~ **Closed the same day**
  by the closing pass of issue 1724: `rdw::_focus_canvas` resolves the name through
  `rdw::_pick_canvas` too, and after a dump made in such a tab the keyboard is back on
  the canvas, as in the first tab. Measured in a real second tab with the tabbed
  interface on; row XP8 holds it and goes red with the old line put back. A third tab
  and the non-tabbed interface were not driven. This was the last place in `rdw.tcl`
  and `calculator.tcl` that the fourth repair's verifier found treating the context's
  name as a widget.
- §2 and §4 are as they were. §3's nesting is issue 0202, which has what the
  repairs of 2026-11-19 changed about it.
- **§3's second bullet, the label written by two pumps, is closed for the label** by the
  last build of issue 1724, the same day. `ase::ui::sod_prompt_pump`, `rdw::_hint_sync`
  and the Calculator's `calc::pick_pump` each write the slot only while no other click
  mode that is up holds the press slot of the mode's canvas over it
  (`ase::ui::sod_covered`, `rdw::_pick_covered`, `calc::pick_covered`, which ask
  `cmdmode::pristine`); the timers keep running. So with two modes stacked the slot
  shows one sentence, that of the mode on top, which is the mode a press goes to, and
  the lower mode's sentence is back when the top mode ends. **Measured before it**,
  the slot sampled with no event sent: two sentences in turn in each stack of two.
  **After it**: one. Band PG28 of `tests/headless/test_calc_pick.tcl` and row TPL14 of
  `tests/headless/test_ase_terminal_pick_1724.tcl`. This is not ruling (a), (b) or (c)
  of §3: the modes still nest and the last arm still wins the click. What it adds is
  that the label says so. Not touched: the tooltip the Results window's mode arms on
  the slot keeps its own sentence while that mode is underneath.
- **§3's stack, ended out of order**, no longer leaves a mode with nothing bound by any
  door of the product that was found: the Results window's mode takes the canvas again
  when the mode under it is ended (`rdw::pick_reseat`), and since the same last build
  the mode on top takes it again when the Results window's mode is ended first, by
  Escape in the Results window (`ase::ui::sod_reseat`, `calc::pick_reseat`). Issue 0202
  has the orders. The ruling §3 asks for is still owed.
