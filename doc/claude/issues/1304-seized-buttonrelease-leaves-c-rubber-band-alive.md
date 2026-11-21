# 1304 — a canvas command mode swallows `<ButtonRelease-1>` and leaves C's rubber band alive; pointer drift then CHANGES THE SELECTION

**Status: FILED; since 2026-11-19 all three click modes hold the motion with
the button held** (the Results Display Window's mode, the Calculator's pick and ASE-L's
Select On Design: see the last section). What follows is the record as it was filed and
updated. Found by item **B4**'s adversary. It is the
sharpest of the three refutations that **reverted item B4**, because it breaks
the user's own headline requirement for that feature. The binding shape is
**live in the tree at `735ea26e`** in `src/ase_window.tcl`.

## The shape, verbatim from the tree

`ase::ui::select_on_design` seizes three sequences and no more:

```tcl
  set sod($key,prevpress) [bind $cv <ButtonPress-1>]
  set sod($key,prevrel)   [bind $cv <ButtonRelease-1>]
  set sod($key,prevesc)   [bind $cv <Key-Escape>]
  bind $cv <ButtonPress-1>   "[list ase::ui::sod_click $key]; break"
  bind $cv <ButtonRelease-1> {break}
  bind $cv <Key-Escape>      "[list ase::ui::sod_end $key]; break"
```

**`<B1-Motion>` is not seized.** So C never sees the press (eaten) and never
sees the release (eaten), but *does* keep receiving motion events carrying
`Button1Mask` — and C starts its rubber-band selection from exactly that.

## What was measured

Driven against item B4's mode, which copies the three binds above verbatim:

* **1 px of drift inside a live pick mode** leaves `ui_state = 16`
  (`STARTSELECT`) alive after the release, **and still 16 after `ESC` ended the
  mode**. The mode exits; C's half-started gesture does not.
* **An eight-step drag inside the mode selects 13 objects.** `xschem selection`
  goes from `{}` to `{text 1 3 2} {instance 1 1 2} …` with `lastsel 13`.
* **The control**: the same gesture with no mode armed leaves `ui_state 8`,
  terminated — i.e. the stuck state is caused by the seize, not by the drag.

For item B4 this contradicts the user's own words for the feature — *"This is a
command mode, so clicking will not change selected set."* A hand that moves one
pixel between press and release is not an exotic input; it is what a hand does.

**Not driven on ASE Direct Plot's own mode.** The three binds are identical by
source, so the mechanism is shared, but the stuck-`STARTSELECT` and the
drag-selects legs were measured on B4's mode only. Someone taking this issue
should drive both.

## Why B4's suite could not see it

Every pick row in the reverted suite drives `<ButtonPress-1>` and
`<ButtonRelease-1>` at **one** coordinate, with a `<Motion>` beforehand to set
the snap position. No row moves the pointer *between* press and release, so the
whole class was outside the fence. This is the batch's recurring lesson for the
sixth item running: **a green count is a statement about the fence.**

## Options, none taken

* **(a) seize `<B1-Motion>` too**, with `break`, for the mode's lifetime, and
  hand it back in the same released-latch proc as the other three. Smallest;
  keeps every gesture out of C while the mode owns the canvas.
* **(b) forward the release to C** instead of breaking it, so C's own state
  machine terminates normally. Larger blast radius: C would then see a release
  with no matching press.
* **(c) clear the stuck state on mode end** — `xschem set ui_state 0` or an
  abort verb. Treats the symptom, and leaves the drag-selects leg live.

**Recommended: (a)**, with the fix applied to `ase_window.tcl` and any new mode
through one shared helper, so the two cannot drift.

## Acceptance, when someone takes it

1. Press, **move the pointer**, release — inside a live mode — leaves
   `xschem selection` byte-identical and `lastsel` unchanged.
2. `ui_state` is back to a terminated value after the release, and after `ESC`.
3. The same row driven with no mode armed still selects, so the row cannot pass
   by disabling selection everywhere.

---

## UPDATE, 2026-09-04 — the fix was written, measured, and reverted with its item

Item **B4-2** implemented recommendation **(a)** for the RDW mode only:
`rdw::_pick_seize` latched a fourth predecessor and bound
`<B1-Motion> {break}`, handed back through the same shared `rdw::pick_release`
as the other three. **Measured working**: press + eight `<Motion> -state 256`
steps + release, mode live, left `ui_state 0`, `lastsel 0` and
`xschem selection` **empty** mid-drag, after the release and after a real `ESC`
— against a measured pre-fix `ui_state 24` / `lastsel 20`. The narrowness leg
held too: a plain no-button `<Motion>` still moved `xschem get mousex`, so the
seize blinds C only while Button 1 is held.

**B4-2 was reverted anyway**, for issues **1305**, **1306** and **1307**. The
fix is preserved verbatim in
`doc/claude/op_param_batch/B4-2_working_tree_REVERTED.patch`; **do not retype
it.**

**`src/ase_window.tcl` still seizes only three sequences** (`:1897-1899`) —
recommendation (a)'s "through one shared helper" half was outside B4-2's Files
cell and is outside B4-3's. **This issue may not be closed on the rdw fix
alone.**

### ⚠ AND THE FENCE THAT WAS WRITTEN FOR IT HAS A HOLE — measured by B4-2's sabotage agent

Window-suite row **K14** counts how many of the four sequence *names* appear in
the bodies of `rdw::_pick_seize` and `rdw::pick_release`. Sabotage variant
`SB-NO-MOTION-SEIZE` changed `bind $cv <B1-Motion> {break}` to
`bind $cv <B1-Motion> {}` — which **destroys** the binding and is exactly the
pre-fix behaviour — and **K14 stayed green on both arms**, because the literal
`<B1-Motion>` still appears twice in the body. A second, unplanned variant that
deleted the latch/bind/restore lines outright (the shape this issue actually
files) *did* red K14 at `{0 0 3}` vs `{0 0 4}`.

The exposure is the **headless** arm: `test_rdw_keys_1245.tcl` self-skips
without Tk, so on that arm this issue's whole mechanism rests on K14 alone. **A
`bind … {}` regression would be invisible there.**

**Hardening required of whoever lands the fix:** K14's third leg must require
each of the four sequences to be bound to a **non-empty script** (match
`<B1-Motion>` followed by `{break}`), not merely mentioned by name.

### ⚠ AND THE FOURTH SEQUENCE WIDENS TWO OTHER DEFECTS

Once `<B1-Motion> {break}` is in the seized set, it joins whatever leaks. Issues
**1305** (a re-arm while suspended latches the seize as its own predecessor) and
**1307** (a new window inherits a live seize) both end with a permanently seized
canvas; with the fourth sequence, that canvas also loses its rubber band for the
session. **Land 1305 and 1307's fixes with this one, not after it.**

## Re-measured 2026-11-19, with the work of issue 1724 in the tree, and then cured there

The sentence above, *"`src/ase_window.tcl` still seizes only three sequences"*, is no longer
true. Select On Design's seize is one proc, `ase::ui::sod_seize`, shared by
`ase::ui::select_on_design` and `ase::ui::sod_resume`. After issue 1724's second repair it
took five slots (the press, the double click, the release, Escape and the canvas's
`<Destroy>`) and still not `<B1-Motion>`.

**Measured on that tree**, on the mode itself (a private Xvfb with openbox, real press,
motion and release events, stock bindings and the Cadence-style profile, the same before
and after that repair): a click whose pointer moved two pixels with the button down queued
its pick, cleared a selection made before the mode, and left the editor's rubber band up
(`ui_state` 16) past the mode's own ESC; a second ESC cleared it.

**Cured in issue 1724's third repair, the same day**, by the fix this issue recommends.
`<B1-Motion>` is a slot of the mode's table (`ase::ui::sod_slots`), bound to `break`, and
`ase::ui::sod_release` hands it back from its own record, with the same own-script rule as
the release slot (a bare `break` there counts as the mode's own only beside the mode's own
press). A drag in the mode is now one pick: the selection made before the mode is kept, the
editor's state word does not move with the button down or after the release, and no pixel
changes. Fenced with real events: group PD of `tests/headless/test_pin_marker_1724.tcl`
(a press, a drag and a release; a click on a pin that drifts; the real ESC), its row P8d
with `src/cadence_style_rc` sourced, rows SO15a to SO15c of
`tests/headless/test_sod_pick_no_select_0204.tcl`, and on the counted arm the slot rows of
band TPL in `tests/headless/test_ase_terminal_pick_1724.tcl`. Row PK10 of
`tests/headless/test_calc_selector_names.tcl` moved with it.

What the last section above asked to land with the fourth sequence is in the tree too. A
canvas seized twice no longer latches the mode's own scripts, in any of the three click
modes (`ase::ui::sod_own_script`, the guard in `calc::_pick_seize`, `rdw::pick_own_script`:
issue 1305's shape). And a window made while a mode is up no longer gets the mode's
scripts, the held motion included: each mode tells `cmdmode` what it holds and
`clone_canvas_bindings` copies what is underneath (issue 1307). Issue 0202 has the
measurements.
