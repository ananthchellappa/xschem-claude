# 1720 — closing a window that is not the current one asks about the current window's changes, so its own unsaved edits are lost without a prompt

**STAMP:** `v1 claim=open tree=e6b38ba83 stamped=2026-11-16 fix=untried open=1 by=driver`

Found by the drag-performance batch's verifier (finding G1 of
`doc/claude/drag_perf_batch/receipts/D3-verify.md`); stage D3's crew had noticed it by reading
(`receipts/D3-fix.md`, limit 3). Present at the batch's base `e6b38ba83` and unchanged by stages D
and D3.

## What happens

Tabbed interface off, a second window open, the main window current. The second window's close
script (`xschem new_schematic destroy $topwin.drw {}`) runs `destroy_window()`, which decides
whether to ask by reading `hierarchy_modified()` of the **current** context, not of the window
being closed:

| case | result (base, D, D3 alike) |
|---|---|
| the second window has a completed, unsaved edit; main is clean | no prompt; the window closes and the edit is lost (only its `~` backup keeps it; the cell file is unchanged) |
| the second window is clean; main has unsaved changes | a prompt naming the **main** window's cell; Cancel keeps the clean window |
| the second window has a drag still held | closes silently |

## How a user reaches it

The current context follows the pointer onto a canvas (its EnterNotify). Moving the pointer from
the main window's canvas straight to the second window's title bar, without crossing the second
window's canvas, leaves the main window current, and the title-bar close button then takes the
path above. Real input, no script needed.

## What a fix needs

`destroy_window()` must ask about the window it is destroying: switch to (or read) that window's
own context for the modified check and the prompt's cell name, then restore. Measure it against
the three rows above on a display, with the tabbed interface both off and on.
