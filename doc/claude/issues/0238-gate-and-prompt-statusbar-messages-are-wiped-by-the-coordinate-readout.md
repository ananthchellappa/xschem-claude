# 0238 — every gate / prompt statusbar message is wiped by the coordinate readout on the next pointer move

Status: **OPEN** — found by the user in the GUI, 2026-08-07, while eyeballing the issue 0233 F2 fix.

Area: `statusmsg()` (`src/scheduler.c:28`, writes `.statusbar.1` at `:49`) vs the motion-handler
coordinate readout (`src/callback.c:5911-5921`, and the press/release twins at `:8495`, `:8882`)
Tests: none — `.statusbar.1` is only written when `has_x`, so this is not headless-observable
Found: 2026-08-07, verifying issue **0233** F2 in the GUI under `src/cadence_style_rc`
Related: **0230** (whose "in-progress wire abandoned" message has the same fate), **0233** F2,
`doc/claude/suggestions/plan_modal_gesture_exclusion.md` (phases 1–2 add eight more verbs that all
want this feedback)

## Symptom, as reported

Press `p`, type a name, let the pin preview ride the cursor, then press `w`. The preview correctly
vanishes and the wire arms — but the user never sees why. The status bar reads `DRAW WIRE!` and
nothing else. The expected `Wire: pending placement abandoned` is nowhere.

## What is actually happening

Two different status-bar fields are in play, and the message is not fighting the one you would
guess:

- `.statusbar.10` is the green **mode** label (`callback.c:8637-8646`: `DRAW WIRE!`, `DRAW LINE!`,
  `DRAW POLYGON!`, …). It is rewritten from the keyboard/motion path on every event.
- `.statusbar.1` is the wide right-hand field, packed last with `-fill x` (`xschem.tcl:14251`), and
  `statusmsg(str, 1)` is its **only** writer (`scheduler.c:49`).

So the gate message does reach `.statusbar.1`. It is then destroyed by this, in the motion handler:

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
armed — so the first 8-pixel flick of the mouse overwrites it. In practice the user's hand is
already moving, so the message is never read.

## Scope: this is not an F2 bug

The same fate awaits every message written while a gesture is live:

- `leave_wire_draw_for()` — `<verb>: in-progress wire abandoned` (issues 0230, 0233 F1). Shipped
  2026-08-06 and, as far as anyone can tell, never once seen by a user.
- `leave_placement_for()` — `<verb>: pending placement abandoned` (issue 0233 F2), **and** its
  decline message `<verb>: finish or ESC the pending placement first (a multiple selection is
  live)`. The decline case is the worse one: the placement stays armed, so `ui_state` is non-zero
  and the explanation of why the key "did nothing" is wiped by the next mouse move.
- ~15 other prompt-style `statusmsg(…, 1)` callers, including the verb-noun prompts
  (`Copy: click an object to copy it`, `Flip in place: click an object to flip`,
  `Descend: cancelled (no instance there)`).

There is no hold/sticky mechanism anywhere today (`grep` for one finds only unrelated uses of the
word).

## Why it matters more after issue 0233

F2 makes a keystroke **silently discard work in progress** — the pin or label preview the user was
placing. The policy was ratified on the understanding that the status bar says what happened. With
the message invisible, the observable behaviour is "my pin vanished when I pressed `w`". Phases 1–2
of the modal-gesture roadmap add eight more verbs with exactly this shape.

## Fix options

1. **A hold counter in `statusmsg()`** — `statusmsg_hold(str, n_events)` (or a
   `xctx->statusmsg_hold` field) that the coordinate readout checks and decrements instead of
   overwriting. Smallest change, keeps one owner for the field, and the readout stays live for
   moves. **Recommended.**
2. **Give the readout its own field** — honest separation, but it is a layout change in
   `xschem.tcl` and every window/tab path has to follow.
3. **Suppress the readout for N motion events after any gate message** — same as (1) with the
   policy inverted; harder to reason about because the suppression lives in the reader.

## Landmines

- **Do not simply drop the coordinate readout.** `mouse = … selected: N w= h=` is the live size
  feedback during a move/copy/stretch, which is the one place a user reads exact deltas.
- **`statusmsg(str, 2|3)` is a different sink** (the CIW info window, `xctx->infowindow_text`), not
  the status bar. Do not route gate messages there instead: the user is looking at the canvas.
- **Not headless-testable** (`statusmsg` returns early when `!has_x`). Either add a Tcl-level probe
  that reads the label under a real `$DISPLAY`, or accept prove-by-code and say so.
- **Three readout sites, not one** — `callback.c:5911` (motion) plus `:8495` and `:8882`
  (press/release paths). A fix that only covers the motion one will still lose the message on the
  next click.
