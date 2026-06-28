# 0059 — Net-highlight style editor: angle slider doesn't update the preview live

## Summary

In the Net highlight styles editor, dragging a row's **Angle** slider does not change
the live preview — the preview only picks up the new angle once the cursor is moved into
another field of that row. Every other field (color, width, dash, blink, march, speed)
updates the preview as you edit it.

## Root cause

The preview repaints continuously (the 40 ms `nhse_preview_tick` → `nhse_preview_paint`)
from `nhse_focus_fields`, which reads the **live** staged vars `::nhse_v($::nhse_focus_row,*)`
of *whichever row last fired `<FocusIn>`* (`::nhse_focus_row`, set by `nhse_focus_set`).

The angle widget is a Tk `scale` (`xschem.tcl` ~923). A Tk `scale` does **not** take
keyboard focus on a mouse click/drag, so dragging it never fires `<FocusIn>` and never
makes its row the focused row. If the slider's row is not already the focused row, the
preview keeps mirroring the *previously* focused row, so the angle change appears to do
nothing — until the user clicks another cell in the row, which fires `<FocusIn>`, sets
`::nhse_focus_row`, and the next tick paints the new angle. (Even when the row *is*
already focused, the slider has no hook to repoint/repaint, so the behavior is
inconsistent with the spinbox/entry fields, which commit on change.)

The scale only had a `<ButtonRelease-1>` → `nhse_cell_commit` binding (commit at end of
drag); it had no per-change hook to drive the preview, unlike the width spinbox which
carries `-command nhse_cell_commit`.

## Fix

Give the scale a `-command [list nhse_scale_changed $i]`. Tk invokes a scale's `-command`
on every value change, **after** the linked variable is updated, so the new angle is
read with no lag. `nhse_scale_changed`:

- ignores the creation-time invocation during `nhse_rebuild` (guarded by `::nhse_building`,
  the same guard `nhse_commit` uses),
- sets `::nhse_focus_row` to this row (so the preview mirrors the row being dragged), and
- repaints the preview immediately.

Commit to the C styles still happens only on `<ButtonRelease-1>` (one rebuild at the end
of the drag, not one per pixel). `src/xschem.tcl` only.

## Test

GUI: open the editor, drag a row's Angle slider, confirm the preview's dash stripes shear
live during the drag (no need to click another field). Headless coverage is not
applicable — the preview canvas and slider need Tk.
