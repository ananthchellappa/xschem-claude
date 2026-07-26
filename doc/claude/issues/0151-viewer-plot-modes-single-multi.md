# 0151 — Waveform viewer plot modes: single-plot / multi-plot + target strip

**Status:** IMPLEMENTED (not pushed)
**Branch:** fluid-editing
**Area:** ASE waveform viewer (`src/wave_viewer.tcl`), ASE session/Direct Plot
(`src/ase.tcl`, `src/ase_window.tcl`), the shipped chord profile
(`src/cadence_style_rc`), and the C graph renderer (`src/draw.c`, `src/xinit.c`,
`src/xschem.h`, plus the on-screen flag bit at `src/callback.c` ×3 and
`src/scheduler.c`).
**Requested by:** user, 2026-07-25.
**Spec:** `doc/claude/specs/waveform_viewer_modes.md` (decisions D1–D8 there).
**Tests:** new `tests/headless/test_wave_modes.tcl` (**144 checks**: 36 pure +
108 GUI); `tests/headless/test_wave_viewer.tcl` 277 (two expectations moved);
`tests/headless/test_ase_plot.tcl` 124 (unchanged, and it caught a real defect —
see §3).

## 1. What was asked

A viewer window should have a **plot mode**. In **single-plot** mode every
signal picked in one Direct Plot gesture lands in one *target strip*; in
**multi-plot** mode each signal gets its own strip. The mode is per window
(several viewers can be open), starts from a config variable, is switchable
from a viewer menu entry that logs a replayable line in the CIW, from Tcl
commands (get / set / easily invert), and — when the viewer is not the active
window — from a chord on the schematic window that reaches the viewer through
its ASE-L session. With more than one strip up, a dull-yellow vertical marker
on the right edge shows which strip is the target, and clicking a strip moves
it. Plus a Tcl command that, from a schematic window, returns the window number
of the associated ASE-L window.

## 2. What shipped

- **Per-window state** `wviewer::mode($token)` / `wviewer::target($token)`
  (the `sharedx` mirror shape), seeded from `wviewer_plot_mode` (default
  `single`) at open time, cleared in `forget`, persisted in the ASE state's
  `viewer` dict as two new trailing keys `mode` / `target`.
- **Policy** in one PURE proc, `wviewer::plan_plot`, applied by
  `wviewer::plot_signals` — the single seam `ase::ui::dp_finish` now calls
  instead of its hard-wired "append one graph, use the last index".
- **Commands** `wviewer::plot_mode`, `set_plot_mode` (single|multi|**invert**),
  `target_strip`, `set_target_strip`, `current_token`;
  `ase::plot_mode_for_current`, `ase::window_number_for_current`,
  `ase::ui::number_for`. Omitted token = the viewer owning the current xschem
  context.
- **Menu** Options > Plot Mode > one dynamic entry ("Set Multi-plot Mode" /
  "Set Single-plot Mode"), relabelled from the submenu's `-postcommand`.
- **Chord** `Ctrl-Shift-4` in `src/cadence_style_rc` → invert the mode of the
  viewer belonging to the session bound to the current design.
- **Logging** `wviewer::set_plot_mode <resolved> <token>` and
  `wviewer::set_target_strip <n> <token>` through the `wviewer::log_action`
  seam, on an actual change only. The **resolved** word is logged, never
  `invert`, and the token is always explicit — replay must not depend on the
  state or the active window at replay time.
- **Marker** the target rect gets an `active=1` prop token (only while >1 strip
  exists); `setup_graph_data` parses it into `Graph_ctx.active` and
  `draw_graph` fills a dull-yellow bar (`gc_graph_active`,
  `graph_active_strip_color` `#a0a000`, `graph_active_strip_width` 5 px) at the
  container's right edge, gated on the new **flags bit 16 = on-screen draw** so
  SVG/PS export never carries it.
- **Click** `<ButtonPress-1>` on the viewer canvas re-targets, then forwards the
  press to the C engine verbatim (the bind is more specific than the kept
  generic `<Button>`, so the forward is mandatory, not decoration).

## 3. The defect the shipped ASE suite caught

First implementation followed the spec literally: single-plot appends into the
target strip, and no new strip is created while the stack is non-empty. That
made `test_ase_plot` P4/P6 fail — correctly. After an ASE run the only strip in
the viewer is the **auto-plot graph** (`auto 1`), which
`ase::ui::auto_plot` **clears and rebuilds after every successful run**. Direct
Plot picks landing there would be silently destroyed by the next run, and it
would break the item-13 invariant "Direct-Plot graphs and the auto graph never
touch each other".

Fix: `plan_plot` takes the auto-graph index and treats "target == auto strip"
exactly like "empty stack" — append ONE strip and use it; `plot_signals` then
moves the target there, so the next gesture accumulates in that strip instead
of appending another. Multi-plot is unaffected (it always appends). Covered by
`M3` (pure) and `MG5b` (GUI) legs.

## 4. Verification

RED-first: the whole suite was written before the product code and failed
30/32 on the pure legs.

Sabotage matrix (break the fix, confirm a test catches it) — **10/10 caught**:

| sabotage | caught by |
|---|---|
| multi lands every signal on one strip | M3 ×3 |
| auto-plot strip no longer excluded | M3, and `test_ase_plot` P4 ×4 / P6 ×2 |
| target clamp made a no-op | M3, M4 |
| marker painted on every strip | MG8 ×4 |
| marker not suppressed for a lone strip | MG8 |
| click no longer re-targets | MG7 ×2 (incl. the real Tk event leg) |
| log records the request word, not the resolved mode | MG3, MG4 |
| mode dropped from the snapshot | MG9 ×3 |
| restore ignores the stored mode | MG9 |
| C: `active` token parse zeroed | the `-d 1` marker probe (below) |

**The C draw is not asserted by any test** — pixels are eyeball-only in this
subsystem, by the standing rule in `test_wave_viewer.tcl`'s header. It was
verified instead with a `dbg(1, ...)` witness kept in the code:

```
./src/xschem -d 1 --pipe -q --nolog --script <probe>   # 3 strips, target 1
  -> "draw_graph(): active-strip marker on graph 1"     (target only)
  with the token parse sabotaged -> no such line at all
```

## 4b. Adversarial review (16 candidates → 6 confirmed, all fixed)

A 20-agent review (4 lenses + per-finding refutation) ran against the finished
diff. Six findings survived refutation; every one is now fixed **and covered**:

1. **The chord could never fire.** `bind .drw <Control-Shift-Key-4>` never
   matches — a physical Ctrl+Shift+4 arrives as keysym `dollar` (probe:
   `event generate . <KeyPress> -keysym 4 -state 5` fires `<Control-Key-dollar>`
   only). The rc already documented this exact trap for Ctrl-Shift-2 and I
   missed it; my MG11 leg was hollow — it grepped the rc text instead of firing
   the chord. Fixed: `<Control-Key-dollar>` is now the real bind (Key-4 kept for
   other layouts), and **MG13** fires the real event.
2. **A re-target click threw away C-engine graph state.** `set_target_strip`
   regenerated, and `regenerate` rebuilds rects from the Tcl model — so an RMB
   box-zoom (which the C engine writes straight into the rect prop, never into
   the model) was silently reverted on the next click. Fixed: the marker now
   moves by rewriting the `active` token in place (`wviewer::move_marker`);
   **MG7b** writes a range rect-side and asserts it survives the re-target.
3. **PNG/XPM export leaked the marker.** The bit-16 gate covers the SVG/PS
   callers, but `print_image()` renders through `draw()`, which sets bit 16, into
   the very pixmap it encodes. Measured: **1945** `#a0a000` pixels in an exported
   PNG. Fixed with the `draw_no_ui_decorations` bracket in `print_image()`;
   re-measured **0**, and with the bracket sabotaged **1945** again.
4. **The one production wiring had no teeth.** Reverting `ase::ui::dp_finish` to
   its pre-0151 body left every suite green (my legs drove `plot_signals`
   directly). Fixed: **MG12** drives the real `dp_finish` in both modes;
   sabotaging dp_finish now fails 3 checks.
5. **Two MG10 legs short-circuited** at the design gate (the ne555 cell is
   outside the test's own library registry, so `design_of_current` returned `{}`
   before the no-session branch was reached). Fixed: the legs now close the
   session on a *registered* design to hit the real branch, and separately cover
   "session bound but viewer closed" and "design not in the registry".
6. **MG8 depended on a layout an earlier phase left behind.** Fixed: it builds
   its own 4-strip layout.

Sabotage of the three review fixes: 3/3 caught (dp_finish revert → MG12 ×3;
dollar bind removed → MG13; `move_marker` → `regenerate` → MG7b).

**Refuted, and worth knowing as behaviour** (probe-backed by the verifiers):
deleting a strip does not make the target "follow" the strip it pointed at — the
target is an index and is clamped, so it can end up on a different strip; and in
multi-plot a signal that fails to add still leaves its (empty) strip, which is
the pre-existing `dp_finish` shape rather than something this change introduced.

## 5. Not verified / judgement calls for the user

- **The marker's appearance** (exact colour, 5 px width, position flush against
  the container's right edge) is unseen by me — eyeball it. Both are retunable
  from an rc: `graph_active_strip_color`, `graph_active_strip_width`. Its
  presence and placement ARE machine-verified indirectly: an exported PNG of a
  two-strip viewer contains a 5 px × strip-height block of exactly `#a0a000`
  when the export gate is removed, and none when the target has no marker.
- **Windows build** untouched but unbuilt here; the new GC follows `gc_hover`
  exactly (same create/free/colour sites), so it is as portable as that one.
- **Clicking the auto-plot strip** makes it the target, and single-plot then
  refuses to land there and creates a strip instead. That is deliberate (§3)
  but it means a click can appear to "not stick" as a landing site.
- **`ase::plot_mode_for_current` needs the viewer window OPEN** — the mode is
  per-window state, so with the viewer closed the chord reports honestly and
  changes nothing rather than pre-seeding a mode for the next open.
- The **auto-plot path and the Add Trace… dialog deliberately ignore the mode**
  (decision D3).
