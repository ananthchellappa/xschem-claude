# 0651 — the shared `dialog_frame` closes on the window-manager button without running the cancel path, leaking every dialog's `dlg` records

STATUS: **OPEN — measured 2026-08-23** by the 0648 crew, under Tk on `:99` with
**openbox 3.6.1 live** (not a bare Xvfb — that distinction is what makes the
measurement evidence rather than a no-op). 0648 fixed this for **Save All only**;
the shared scaffold is untouched. Related: 0648, 0652, 0645.

---

## Measured

On the Save All dialog, before 0648's fix:

```
wm protocol WM_DELETE_WINDOW on the dialog : ''      (empty = NO handler)
dlg record after WM close                  : 1       (1 = save_all_cancel NEVER RAN)
```

`ase::ui::dialog_frame` builds every scaffold dialog and its teardown is a bare
`catch {destroy $w}`. It sets **no** `wm protocol WM_DELETE_WINDOW`. So the
window-manager close button destroys the toplevel directly, and the per-dialog
`ase::ui::dlg($key,*)` records that the cancel path exists to `array unset` are
left behind.

This also **corrects a sentence in 0648's own filing**, which asserted that
"Cancel, ESC via `bind_dialog_esc`, and the window-manager close all reach
`save_all_cancel`". Cancel and ESC do. **The WM close does not** — measured
above. The tick is still discarded (the record is dialog-local and never
committed), but it is discarded by a *different* route that runs no cleanup.

## Why it is worth its own issue

0648 needed this fixed for Save All and fixed it there, via
`ase::ui::dialog_close_protocol`. Its sabotage variant **SAB-E** proves that fix
is load-bearing: neutralise the protocol wiring and `GE10b` (protocol reads `''`
again) and `GE10g` (`{1 1 1 1 0}` — the dialog *survives* and all three `dlg`
records leak) both go red, exactly as predicted.

But `dialog_frame` is **shared by roughly eight dialogs**. Every one of the others
still has the hole:

* the record leak is per-dialog state that accumulates for the session's life;
* a reopened dialog seeds its checkbuttons from `dlg(...)` when present, so a
  leaked record can make the *next* open show stale values;
* any future dialog that grows an on-close obligation (a discard notice, a
  re-arm, a released lock) inherits the bypass silently.

## What to do

Wire `WM_DELETE_WINDOW` **in `dialog_frame` itself**, defaulting to the dialog's
own cancel path, so no individual dialog has to remember. 0648's
`ase::ui::dialog_close_protocol` is the mechanism; the work is hoisting it from
one caller into the scaffold and giving each dialog its cancel command.

## Landmines

- **The widget paths are the test surface.** `test_ase_dialogs` (166 checks)
  drives `.allv .alli .levels .btns.proceed` and their siblings by path. Hoisting
  must not rename anything.
- A dialog whose cancel path does more than tidy (Save All's now *reports* a
  discard, 0648) must not fire that twice if both ESC and the protocol run.
- **This does not close every silent-drop route, and 0648's adversary measured
  two more that bypass both ESC and the WM protocol:** reopening Save All after a
  tick (`dialog_frame`'s own `catch {destroy $w}` runs neither), and closing the
  ASE session window with a ticked dialog open (`ase::ui::close` does
  `array unset dlg $key,*` then destroys the parent). Both drop the tick with no
  discard line and no re-arm. Fixing the protocol alone leaves those live — say
  so rather than declaring the class closed.
- Measuring this needs a **real window manager**. A bare Xvfb does not deliver
  `WM_DELETE_WINDOW`, so the row would pass while the bug is live (issue 0645).

## Acceptance

- Every scaffold dialog's `wm protocol WM_DELETE_WINDOW` is non-empty.
- Closing any of them by the WM button leaves no `dlg($key,*)` record behind.
- A dialog whose cancel path reports something reports it exactly once,
  whichever of the three dismissal routes is used.
- `test_ase_dialogs` stays at or above 166, measured with a WM live.
