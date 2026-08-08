# 0238 — every gate / prompt statusbar message is wiped before it can be read

Status: **FIXED** 2026-08-08. Found by the user in the GUI, 2026-08-07, while eyeballing the issue
0233 F2 fix. Fixed first in that session's successor because phases 1–2 of the modal-gesture
roadmap add eight more verbs that silently discard work in progress, and the statusbar line is
their entire user-visible half.

Area: `statusmsg()` (`src/scheduler.c`, writes `.statusbar.1`) vs the motion-handler coordinate
readout (`src/callback.c`, and the press/release twins) **and** `select.c`'s object-info line
Tests: `tests/headless/test_statusmsg_hold_0238.tcl` (**7 checks, needs a real `$DISPLAY`** — it
reads `.statusbar.1 cget -text` after synthesizing real `<Motion>` events through the Tk bindings)
plus section **H** of `tests/headless/test_placement_wire_gate.tcl` (flag-level, headless)
Found: 2026-08-07, verifying issue **0233** F2 in the GUI under `src/cadence_style_rc`
Related: **0230**, **0233** F2, **0237** (the verbs that depend on this feedback),
`doc/claude/suggestions/plan_modal_gesture_exclusion.md`

## Symptom, as reported

Press `p`, type a name, let the pin preview ride the cursor, then press `w`. The preview correctly
vanishes and the wire arms — but the user never sees why. The status bar reads `DRAW WIRE!` and
nothing else. The expected `Wire: pending placement abandoned` is nowhere.

## What was actually happening

Two different status-bar fields are in play, and the message was not fighting the one you would
guess:

- `.statusbar.10` is the green **mode** label (`DRAW WIRE!`, `DRAW LINE!`, …), rewritten from the
  keyboard/motion path on every event.
- `.statusbar.1` is the wide right-hand field, packed last with `-fill x` (`xschem.tcl`), and
  `statusmsg(str, 1)` is its **only** writer.

So the gate message did reach `.statusbar.1`. It was then destroyed by the motion handler:

```c
    /* update status bar messages */
    if(xctx->ui_state) {
      if(abs(mx-xctx->mx_save) > 8 || abs(my-xctx->my_save) > 8 ) {
        my_snprintf(str, S(str), "mouse = %.16g %.16g - selected: %d w=%.6g h=%.6g", …);
        statusmsg(str,1);
      }
    }
```

`ui_state` is non-zero for the whole point of the message — a gesture was just armed or is still
armed — so the first 8-pixel flick of the mouse overwrote it.

**Measured, pre-fix, with the GUI probe now committed as the test** (`add_sch_pin -place` then
`wire gui`, then 25 synthesized motion events):

```
reverse msg (0233 F2): {Wire: pending placement abandoned}
after 25 motions     : {mouse = 150 100 - selected: 0 w=250 h=200}
```

## A second clobberer the issue did not name

Found while fixing it: for every **placement** verb the message did not even survive the arm, let
alone the mouse. `place_symbol()` SELECTS the preview instance it just placed, and `select.c`'s
`"n=%4d x = %.16g  y = %.16g  w = %.16g h = %.16g"` info line (six sibling sites) is a plain
`statusmsg(str, 1)` that lands ONE call after the gate message. Measured: after
`xschem net_label 0` on a live wire draw the field read `n=   0 x = -1.25  y = -1.25  w = 2.5
h = 2.5`. This is why the fix is on the WRITER side (below) rather than at the three readout
sites the issue originally listed — a reader-side fix would have left this one.

## The fix

A hold, enforced inside `statusmsg()`:

- `statusmsg_hold(str, n)` — write the line and hold the field. Used by `leave_wire_draw_for()`,
  `leave_placement_for()` (both messages, including the issue-0231 decline), and the eleven
  verb-noun prompts (`Copy: click an object to copy it`, `Move: …`, `Stretch: …`, `Rotate: …`,
  `Flip: …`, `Descend: …`).
- `statusmsg(str, 1)` — an ordinary line is DROPPED while a hold is up.
- `statusmsg_held()` — self-expiring test, `STATUSMSG_HOLD_MS = 5000`.
- `statusmsg_hold_clear()` — called on every **ButtonPress** (`callback.c`), so the live
  `w=`/`h=` size feedback during a move/copy/stretch comes back the moment the user clicks
  (landmine 1 below), and by `xschem statusmsg <text>`, which is deliberate news.
- `xctx->statusmsg_hold_ms` + `xctx->statusmsg_text` (the last line that actually reached the
  field), read back with `xschem get statusmsg_hold` / `xschem get statusmsg`.

### Where this diverged from the *Fix options* below

1. **Wall clock, not an event counter.** Option 1 proposed a hold of *N events*. X streams motion
   at ~100 events/s while the hand is moving, so any count small enough to feel responsive expires
   in milliseconds — the failure being fixed. 5 s of wall clock (Tcl_GetTime via
   `net_hilight_now_ms()`) is what "long enough to read" means; a click ends it sooner.
2. **Writer-side, not reader-side.** See the second clobberer above. It also means a readout added
   later cannot reintroduce the bug — the three known readout sites needed no change at all.
3. **It IS testable.** The issue expected prove-by-code. `xschem get statusmsg` /
   `statusmsg_hold` give headless flag-level checks (section H), and the GUI test drives real
   `<Motion>`/`<ButtonPress>` events through the Tk bindings and reads the label — RED on the
   pre-change binary, GREEN after (both measurements above and in the test's header).

## Landmines (all still true)

- **Do not drop the coordinate readout.** `mouse = … selected: N w= h=` is the live size feedback
  during a move/copy/stretch, the one place a user reads exact deltas. That is what the
  ButtonPress release exists for.
- **`statusmsg(str, 2|3)` is a different sink** (the CIW info window, `xctx->infowindow_text`) and
  is never held — netlist/ERC output must not be swallowed.
- **A 5-second hold swallows ordinary lines.** An unrelated warning issued through
  `statusmsg(…, 1)` within the window is dropped (most also go to the info window via `…, 2`). A
  message that must win should call `statusmsg_hold()`, which replaces the held one.
- **In GUI mode a test cannot print to stdout unless `--pipe` is given** (`main.c` `freopen` on
  `--detach`, and a plain GUI run's stdout goes nowhere useful), and with `--pipe` xschem blocks
  reading stdin so `after` timers never fire. The committed GUI test therefore runs entirely at
  source time with explicit `update` calls, and also mirrors every line into
  `tests/headless/results/test_statusmsg_hold_0238.log`. It is NOT registered in
  `tests/run_regression.tcl` (that harness runs `--nogui` and demands an `OVERALL: ok` sentinel an
  X-gated skip cannot honestly print); `tests/headless/full_audit.sh` picks it up automatically.
