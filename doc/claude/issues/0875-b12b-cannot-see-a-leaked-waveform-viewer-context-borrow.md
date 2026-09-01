# 0875 — row B12b cannot see a leaked waveform-viewer context borrow, which is the one thing it was written to hold

**Status:** 🔴 **OPEN — measured, NOT fixed.** Filed by the A3 write-up, 2026-08-27,
from the sabotage leg of the 0868 run. Class: **a hollow structural row.**

Owner: issue **0868**, row **B12b** in `tests/headless/test_annot_show_menu.tcl`;
subject `cadence::_annot_tran_cursor` in `utils/annot_mode.tcl` (~:476).

## What B12b claims to hold

Guard **G8**: `_annot_tran_cursor` borrows the waveform viewer's context with
`wviewer::enter_ctx`, reads the cursors, and must `wviewer::leave_ctx` on every path
— *"A body that entered, threw, and never left"* is the leak shape (issue 0173's) its
own header names.

## Measured, three variants

1. **Delete the real `::wviewer::leave_ctx $key $ticket` call.** B12b stays **GREEN**.
   Only B12 reds, and it reds on the VALUE, not on the leak. Cause: B12b counts lines
   matching `wviewer::leave_ctx`, and the proc's own guard line
   `[llength [info commands ::wviewer::leave_ctx]]` satisfies that count all by
   itself.
2. **S10c — strip the `catch` wrapper around the two cursor reads**, so a throw
   escapes past `leave_ctx`. That is verbatim the scenario B12b's header claims to
   own. **All 29 checks pass.**
3. B12b's third element counts any `catch`/`finally` anywhere in the proc — of which
   there are about ten — so it **can never go red**.

## The shipped code is safe; the row is not

The reads ARE inside a `catch`, so no leak is live today. What is missing is anything
that would notice if that stopped being true — and this is the only guard in the item
that no behavioural row can reach, because headless there is no viewer to borrow
from (0868's own S10 note says so).

## Fix shape

Make the row structural in a way the guard line cannot satisfy:

* count `leave_ctx` occurrences that are **calls**, not `info commands` arguments —
  strip the guard line first, or match `::wviewer::leave_ctx \$key`;
* assert the two cursor reads sit inside a `catch` whose body is followed by the
  `leave_ctx` call, or restructure the proc so the borrow is released in ONE place a
  `finally`-shaped wrapper owns and pin THAT shape;
* better still, a behavioural row: stub `::wviewer::enter_ctx` / `leave_ctx` /
  `window_for` in the Tk suite, make a cursor read RAISE, and assert `leave_ctx` was
  still called. That reds on variant 2, which no current row does.
