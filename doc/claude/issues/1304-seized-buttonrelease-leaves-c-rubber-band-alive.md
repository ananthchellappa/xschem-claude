# 1304 — a canvas command mode swallows `<ButtonRelease-1>` and leaves C's rubber band alive; pointer drift then CHANGES THE SELECTION

**Status: FILED, NOT FIXED.** Found by item **B4**'s adversary. It is the
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
