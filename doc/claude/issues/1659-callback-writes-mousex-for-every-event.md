# 1659 — `callback()` writes `xctx->mousex/mousey` for EVERY event, so a `<Configure>` on any descendant widget clobbers the mouse pair

**STAMP:** `v1 claim=latent tree=8fdc98ed stamped=2026-10-08 fix=untried open=3`

## What was measured

Found 2026-10-08 while diagnosing why `test_rdw_keys_1245` had six rows failing at HEAD
with a *moving* row set (6, 7, 8 and 10 failures across four runs at one commit). The
suite half is fixed; this is the product half, and it is **a candidate defect, not a
confirmed one** — see the limit at the foot.

The chain, traced end to end by symbol:

1. `src/xschem.tcl` binds `bind $topwin <Configure> "xschem callback %W %T %x %y 0 %w %h 0"`.
2. `$topwin` is a **toplevel**, so every descendant's bindtags include it. The binding
   therefore fires for **every descendant widget's** Configure. Logged `%W` values during
   one window settle: `.statusbar.1`, `.`, `.statusbar`, `.toolbar`, `.tabs`, `.drw`.
   **Corrected 2026-11-19, see the note at the end of this file:** measured, the binding is
   on the design canvas and fires for the canvas's own Configure only.
3. For a child widget, `%x %y` is **that widget's position inside its parent** — not a
   pointer position. Nothing in the binding distinguishes the cases.
4. `callback()` in `src/callback.c` executes

   ```c
   xctx->mousex = X_TO_XSCHEM(mx);
   xctx->mousey = Y_TO_XSCHEM(my);
   ```

   **unconditionally, above its `switch(event)`.** So a `ConfigureNotify` writes a widget
   *position* into the mouse pair. (`case ConfigureNotify:` then runs `resetwin` + `draw`,
   which also moves `zoom`/`xorigin`, so the original pixel cannot be back-computed.)

Instrumented in the suite's own click helper: a synthetic `<Motion> -when now` set
`mousex/mousey` correctly to `136.2803 / -170.01365`, and a single `update` immediately
after it left them at **`1260.7161 / -742.09501`** — a point nobody clicked.

## Why it matters beyond the suite

**`rdw::pick_click` is not the only un-snapped reader of that pair.** It reads
`xschem get mousex` / `xschem get mousey` as its documented default, and so does
**`calc::pick_click`** — the Calculator's net pick (spec R208), which is on the user's own
path. A clobbered pair makes `xschem instance_at` answer empty, and the pick then takes its
"nothing under the click" arm: **rc 0, no error text, no window, no block.** A silent wrong
answer, not a failure — which is why six rows read `NO-BLOCK` and none of them raised.

The alarming half is which Configures can fire it. `.statusbar.1` is in the list, and the
status bar reflows on **ordinary status-text updates**, not only on a window resize.

## What is NOT established

- **Whether a real hand gesture can see it.** The binding was verified to fire
  per-descendant and `callback()` was verified to overwrite the pair, but no interactive
  gesture was driven to produce a user-visible wrong pick. A real pointer sends a genuine
  `<Motion>` before any press, so the question is whether a Configure can land *between*
  the motion and the press often enough to matter. **Measure that before fixing anything.**
- Which specific widget's `%x` produced `1260.7161`; `case ConfigureNotify` moves the
  transform, so it is not recoverable from the logged value.

## Candidate fixes, none applied

1. Write the pair only for the events that carry a pointer position (motion, button,
   enter/leave) — i.e. move the two assignments below the `switch` or guard them by event
   type. Cheapest and most obviously right, but `callback()` has many callers and the
   unconditional write may be load-bearing somewhere; `/usr/bin/grep` for readers of
   `xctx->mousex` before touching it.
2. Bind `<Configure>` on the canvas rather than on `$topwin`, so it stops firing for
   siblings. Changes which resizes are noticed.
3. Make the readers snap: have `rdw::pick_click` and `calc::pick_click` take coordinates
   from the event rather than from the context. Narrowest, but leaves the clobber in place
   for every future reader. ⚠ Note an event's `-x`/`-y` are screen PIXELS while a pick's
   coordinates are SCHEMATIC units (`X_TO_SCREEN` in `src/xschem.h`).

## See also

- **Issue 1655** — the RDW suites are registered in NOTHING
  (`/usr/bin/grep -c 'rdw' tests/run_regression.tcl` is 0), which is why a race latent
  since `8a8f66d2` went unnoticed. This issue is that cost made concrete for the second
  time in one day.
- The suite half of this is already fixed: `kx_click`, `kx_click_px` and `kx_drag_px` in
  `tests/headless/test_rdw_keys_1245.tcl` now pump stale events **before** the synthetic
  motion instead of between the motion and the press. Three consecutive `ALL PASS (92)`.
- **`test_rdw_window_1245` carries a SEPARATE, UNFIXED flake** in its tooltip band: rows
  `HT9`, `HT12` and `HT15` fail with a moving count (measured 1, 0, 3, 4, 3 over five
  consecutive runs). Those are hover/`after`-timer rows, not click rows, so the pump fix
  above does not apply to them and they are not diagnosed here.

## Note, 2026-11-19 (issue 1724): what overwrites the pair, and the three click modes no longer depend on it

Measured while issue 1724's click modes were repaired, on a private Xvfb with openbox
and real events (the probes are in that review's scratch). Three things, one of which
corrects the chain above. The stamp is left as it was: none of the three candidate fixes
was applied, and the engine still writes the pair for every event.

**1. Step 2 of the chain does not hold on this tree.** `set_bindings` is called with the
design CANVAS (its formal is named `topwin`): `bind . <Configure>` is empty, `bind .drw
<Configure>` is `xschem callback %W %T %x %y 0 %w %h 0`, and the bindtags of
`.statusbar.1` are `.statusbar.1 Label . all`, which do not include the canvas. A
`<Configure>` generated on `.statusbar.1`, queued or with `-when now`, left the pair where
it was, and so did a change of the status text. What moved it was the canvas's OWN
`<Configure>`: generated on the canvas with its real geometry, or delivered by a real
resize of the window. That event carries the canvas's position inside its window as its
`%x %y` (step 3 above is right about that). By the source the call sites were the same at
this file's stamp commit (`set_bindings .drw`, `set_bindings <window path>`); the `%W` log
quoted in step 2 was not reproduced.

**2. A real gesture can see it** (the first item under "What is NOT established").

- **A double click in the Results Display Window's pick mode.** The first press dumps the
  device, the dump lays the windows out again, the canvas gets a `<Configure>`, and the
  pair is overwritten before the second press, with no pointer motion in between: 4 of 4
  double clicks, measured with the mode's click script put in the double-click slot. The
  second press then said *"no device under the click"* about the device the first had
  just dumped, which is why that mode swallows its second press.
- **A press after the window was laid out again under a resting pointer.** A real resize
  of the window with the pointer on a pin left the pair far from the pin; a press there,
  with no motion first, was resolved at that other point.
- **Not every double click.** Under a Calculator pick the pair was the same at both
  presses in 6 of 6 double clicks, and in ASE-L's Select On Design in 12 of 12, on a
  session with no ASE-L window open. With a session window whose Outputs pane is refilled
  between the presses it was not measured.

The reproducer that needs no timing: a real `<Motion>` onto an object; `event generate
<canvas> <Configure> -x [winfo x <canvas>] -y [winfo y <canvas>] -width [winfo width
<canvas>] -height [winfo height <canvas>] -when now`; then a press at the object's pixel
with no motion. Before the change below the press answered *"nothing under the click"*
(the Calculator, a voltage selector on a wire), *"nothing there"* (the Calculator, a
current selector on a pin), *"no device under the click"* (the Results Display Window)
and, in Select On Design, queued nothing and said nothing.

**3. The three click modes hand the press's own position to the engine first.** The
script each of them binds on the press is now

```tcl
xschem callback %W 6 %x %y 0 0 0 %s; <the mode's click>; break
```

(`ase::ui::sod_press_script`, also on its double click; `calc::_pick_seize`, also on its
double click; `rdw::_pick_seize`, on its press only: its double click stays swallowed).
The press's pixel goes to the engine as a pointer motion, which is what a hand moving onto
that pixel would have sent, and the click then reads a pair the press has just written. So
`ase::ui::sod_click`, `calc::pick_click` and `rdw::pick_click`, reached by a real press,
no longer depend on the pair surviving from the last motion. This is none of the three
candidate fixes above: the engine still writes the pair for every event, `<Configure>` is
bound where it was, and the click procs still read the context. Called by a script with
no coordinates, each still reads whatever the engine was last handed.

Fences: group PS of `tests/headless/test_pin_marker_1724.tcl` and row TPL10 of
`tests/headless/test_ase_terminal_pick_1724.tcl` (Select On Design), band PG24 of
`tests/headless/test_calc_pick.tcl` (the Calculator), rows XP0 to XP2 of
`tests/headless/test_rdw_keys_1245.tcl` (the Results Display Window). Each fixture leg
shows the pair really was overwritten before the press.

**Still open, and not measured:** the engine half (candidate 1); what a press does when
the engine refuses the motion it is handed because a callback is already running (the
click then reads the pair as before); and the readers that follow a RESTING pointer, which
no press refreshes: the prompts of Select On Design and of the Calculator's current
selectors name the pin under the pair every period of their timers
(`ase::ui::sod_prompt_now`, `calc::pick_hover`).

## Note, 2026-11-19, later the same day: two more traps for a test that moves the pointer between windows

Met while the fourth repair of issue 1724 wrote a row with the pointer in a second window
(group PE of `tests/headless/test_pin_marker_1724.tcl`). Both are this issue's family: an
event that is not a pointer motion moves the pair.

- **A synthetic `<Enter>` on another window, followed at once by a `<Motion>` there, can
  leave the pair at a point nobody moved to.** The Enter switches the engine's context,
  and the switch brings events of its own, which overwrite the pair after the motion.
  Measured: the engine's pointer read back as pixel (0,0) of the canvas. Drain with
  `update` BETWEEN the `<Enter>` and the `<Motion>`, and read `xschem get mousex` and
  `mousey` back after the motion and again after any timer the row waits for (row PE1
  asserts both).
- **A real press on a device pin in a window no mode holds starts the editor's wire**
  under the stock bindings. Left alone it shows in a later group as a rubber-band wire
  from that pin (measured as a difference in the pixels that group compares). Give the
  gesture up with `xschem abort_operation` before the next row, and assert the editor is
  idle with nothing selected (row PE2).

Since the same repair the prompt of Select On Design names a pin only while the pointer is
in the window the mode is on (`ase::ui::sod_pointer_elsewhere`), so of the readers named
under "Still open" above, that one no longer follows a pointer resting in another window
of the design. It still reads the pair every period of its timer in its own window.
