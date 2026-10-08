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
