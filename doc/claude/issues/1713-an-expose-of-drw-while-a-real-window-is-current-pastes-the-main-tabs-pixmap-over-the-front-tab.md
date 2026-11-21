# 1713 — an Expose of `.drw` while a real top-level window is current pastes the MAIN tab's pixmap over the front tab

**STAMP:** `v1 claim=open tree=e3c43487e stamped=2026-11-15 fix=untried open=1 by=selection_look-docs`

Found by the selection-look batch: the stage A4 fix crew's finding **K6**
(`doc/claude/selection_look_batch/receipts/A4-fixes.md`, "K6, a base bug, not fixed"),
re-measured by that stage's verifier (`receipts/A4-verify.md`, "K6 is base"). **The batch did
not cause it.** The base build, `~/gsl0` (a clone of `e3c43487e`, the batch's base, before
any selection-look change), gives the same figure. Filed, not fixed.

## What happens

Under the tabbed interface (the default on this branch), with:

- a tab other than the main one (`t1`) on the shared canvas `.drw`, and
- a real top-level window (made by `xschem new_schematic create_window`) as the current
  context,

an Expose of `.drw` repaints the canvas with the **main** tab's drawing and the main tab's
selection. The tab bar still shows `t1` in front. The wrong drawing stays until something
draws `t1` again: a full redraw, or a tab click.

## Repro (from the receipts)

The pose is `A4/scr/v/ctx_a4.tcl`, rows K6 and K6b, in the batch's session scratchpad
(`.../scratchpad/selshot/A4/`). That directory is scratch and will not last, so the steps are
copied here. Each run used a private Xvfb (1920x1080x24) with openbox, `DISPLAY` unset in the
calling shell, `GUI_GATE=0`, a throwaway `HOME`, and `sky130A/cadence_style_rc` sourced,
with `wm geometry . 900x700+0+0`. Pixels were compared with `magick compare -metric AE`.

1. Main tab: load `sky130A/xschem_libs/sky130_tests/not/schematic/not.sch`.
2. `xschem new_schematic create {} xschem_library/examples/flop.sch` makes tab `t1`
   (`set t1 [xschem get current_win_path]`).
3. `xschem new_schematic create_window {} xschem_library/examples/cmos_example.sch` makes
   the real window `w` (`set w [xschem get current_win_path]`), then
   `wm geometry [winfo toplevel $w] 800x600+950+0` and `xschem redraw`.
4. `xschem new_schematic switch $t1`, then `xschem redraw`. `t1` is in front and drawn on
   `.drw`.
5. `xschem new_schematic switch $w`. `w` is current; `t1`'s drawing is still on `.drw`.
6. Snapshot `.drw` (`import -window [winfo id .drw]`).
7. `xschem callback .drw 12 0 0 0 [winfo width .drw] [winfo height .drw] 0`. Event 12 is
   Expose, over the whole canvas.
8. Snapshot `.drw` again and compare it with step 6.

In the pose, steps 4–8 run after rows K1–K5 in the same process. K5 ends with `x5`
selected in `t1` and `t1` drawn by a `dr` 1 switch, so that is the state step 6 photographs.

**K6b** continues from there. Switch to `t1`, `xschem unselect_all`,
`xschem select instance p0`, switch to `w`, send the same Expose. Then compare `.drw` with a
full redraw of `t1` (a `dr` 1 switch to `t1` plus `xschem redraw`).

## Measured (the receipts' figures)

| row | what is compared | build, selection style | AE px |
|---|---|---|---|
| K6 | `.drw` before and after the Expose | `~/gsl0` (base), classic | **62028** (crew and verifier) |
| K6 | same | A4 tree, classic | **62028** (crew and verifier) |
| K6 | same | A4 tree, halo | **63651** (crew and verifier) |
| K6 | same | A4 tree, bright `own` | **60906** (verifier) |
| K6b | `.drw` after the Expose against a full redraw of `t1` | classic | **62222** (verifier) |
| K6b | same | halo | **56749** (verifier) |

The crew reports K6b as "inherits it in every build". Classic is the pre-batch look, byte for
byte, so the classic row on `~/gsl0` is the base defect alone. The crew's before/after image
is `A4/img/K6_expose_base_classic_pre_post.png` (scratch, as above).

Every measurement was a synthesized Expose on Xvfb. None was a real window uncovering
`.drw` by hand.

## Cause

This is the receipts' diagnosis, checked here against the code at `e3c43487e`:

1. `set_bindings` in `src/xschem.tcl` binds `<Expose>` on the canvas to
   `xschem callback %W ...`. Tabs share one canvas, so `%W` is `.drw` whichever tab is
   drawn there.
2. `callback()` in `src/callback.c` calls `handle_window_switching()` first. Under the
   tabbed interface its switching block runs only when the event window or the current
   context is a real window (`win_is_real || cur_is_real`). Here the current context is
   `w`, so the block runs. An Expose takes the "redraw ONLY" arm:
   `new_schematic("switch_no_tcl_ctx", win_path, "", 1)` with `win_path` = `.drw`, and the
   previous path saved in `restore_win`.
3. The `switch_no_tcl_ctx` arm of `new_schematic()` in `src/xinit.c` calls
   `switch_window(..., 0)`. That resolves the path with `get_tab_or_window_number(".drw")`,
   which answers **slot 0, the main tab**. Slot 0 owns the canvas's widget path. It is not
   necessarily the tab whose drawing is on the canvas.
4. `handle_expose()` copies `xctx->save_pixmap` (the main tab's) to `xctx->window` (the
   shared `.drw` X window). It then draws the main tab's selection, clipped to the exposed
   rectangle. `callback()` then switches back to `w`.

The tree already tracks which tab is shown on `.drw`: `get_drw_front_win()` and
`note_drw_front()` in `src/xinit.c` (issue 0073). In this repro it names `t1`. This path never
reads it.

## Whose defect it is

It is not upstream behaviour, and it is older than the selection-look batch:

- **Upstream cannot reach it.** In `origin/master` (upstream xschem, `f276d0cf2`),
  `handle_window_switching()` gates its whole block on `!tabbed_interface`. Its
  `switch_no_tcl_ctx` arm also requires `!tabbed_interface`. Upstream's tabbed mode has no
  real top-level windows (no `create_window`) and never does a redraw-only switch.
- **`1a7887fa9`** (2026-06-22, "tabs AND windows") let real windows coexist with tabs. It
  widened the gate to `win_is_real || cur_is_real`.
- **`8dfdb7b24`** (issue 0848, 2026-08-26) removed the gate on `switch_no_tcl_ctx`. The
  comment it left above that arm says *"a genuine tab shares the .drw X window, so pointing
  xctx at it and repainting is correct there too"*. That is true when the main tab is in
  front. With another tab in front, slot 0 is the wrong context. Before 0848 the switch did
  nothing and the Expose was serviced against the real window's context, a different wrong
  answer (0848's "bug 1").

Neither commit is in `origin/master`, and both are ancestors of `e3c43487e`.

Do not confuse this with **N5** in `receipts/A4-verify.md`. N5 is the batch's own finding: a
full Expose after a `dr` 0 tab switch, where the batch's `sel_canvas_win` is not updated. It
is in the same function and has a different mechanism.

## Reach

This section is reasoned from the code, not measured. In a real session `.drw` gets an
Expose when something covering the main window moves off it or closes: the real window
itself, a dialog, another application. For K6 to fire, a real window must be the current
context at that moment, for example because the pointer is in it with
`mouse_follows_focus` on. If a tab other than the main one is in front, the main window then
shows the main tab's drawing under `t1`'s tab until something redraws. Nobody has reproduced
this by hand.

## Proposed fix (NOT built)

From the A4 receipt: in the redraw-only arm of `handle_window_switching()`, under the tabbed
interface, resolve `.drw` to the tab whose drawing is on the canvas before switching. Do not
send it to slot 0.

- The candidate at base is `get_drw_front_win()`. The A4 tree also has `sel_canvas_win`,
  which records the tab whose full redraw last reached the canvas.
- The two can differ: after a `dr` 0 switch the front tab is not what the canvas shows (the
  A4 receipt's N4 analysis). Choosing between them is part of the fix.
- The A4 crew left it unbuilt because it changes classic pixels, which that stage was not
  allowed to do. This needs to be its own change.
- A fence for it is K6's shape, made into rows:
  - `.drw` after the Expose must be AE 0 against a full redraw of the front tab;
  - a control with the main tab in front must still repaint the main tab (0848's case).

## Two more shapes of the same routing, measured 2026-11-19 (issue 1724's third review)

Found while reviewing issue 1724 (finding VJ1 of its third review, re-measured by a second
agent). Neither is caused by that work: `src/callback.c` was byte-identical to
`d36cb429e` and the same runs on a build of `d36cb429e` printed the same. Filed here, not
fixed; the stamp line above is left as it was. Every run was on a private Xvfb with
openbox, a throwaway `HOME`, `tabbed_interface` 1 and `mouse_follows_focus` 1.

Both come from the fact this file is about: under the tabbed interface an event whose
window is the shared canvas `.drw` is taken for **slot 0**, the first tab, and
`get_drw_front_win()` is not read on that path.

### Shape 1: an Enter on `.drw` after a real window was current brings the FIRST tab to the front

No Expose is needed, and the main tab's drawing is not pasted over the front tab: the
main window really switches tab.

1. Tab `one.sch` (slot 0), a second tab `two.sch` made with `xschem new_schematic create`,
   and a real window `three.sch` made with `xschem new_schematic create_window`, placed
   BESIDE the main window (no overlap).
2. Put `two.sch` in front with its tab button.
3. Move the real pointer into the real window's canvas (`event generate <canvas> <Motion>
   -warp 1`): the real window becomes the current context.
4. Move the real pointer back onto `.drw`.

Result, working tree and `d36cb429e` alike: the current context is `.drw`, the sheet shown
is `one.sch` and the tab bar has `one.sch` in front, where `two.sch` was. Traced in a
scratch build with a print in `handle_window_switching()`: the event is 7 (EnterNotify)
with the window `.drw` while the current context is the real window, and the function
calls `switch_tab(".drw")`, which is slot 0.

### Shape 2: the restore after a borrowed event fails for a tab, and strands the context on the real window

With a tab other than the first as the current context and an event that belongs to the
real window (traced: event 12, an Expose of the real window's canvas),
`handle_window_switching()` borrows the real window's context for the event and then
restores the previous one with `new_schematic("switch_no_tcl_ctx", <the tab's context>)`.
That goes through `switch_window()`, which asks Tk for a widget named after the context.
A tab's context name (`.x1.drw`) is no widget, so the restore gives up, prints

    new_schematic("switch",...): Warning: .x1.drw has been destroyed

and leaves the REAL WINDOW as the current context. The next Enter on `.drw` is then
shape 1.

### What a user sees (measured through issue 1724's Select On Design)

With a design in a tab other than the first and a second real window on the screen (the
waveform viewer's window, or a block opened in a window of its own):

- Session > Design Window, or entering a click mode from the session's menu, raises the
  main window, and the main window can end with the FIRST tab in front. The mode is then
  armed over another design's sheet; its first click is refused by the mode's own window
  test, the mode stays armed, and one press of the design's tab puts it right.
- With the other window moved clear of the main window the entry leaves the design's tab
  shown, and the tab still flips as soon as the real pointer crosses the other window's
  canvas on its way to the schematic. A synthetic pointer that never visits the other
  window does not show it, which is how a "window moved away" control passed.
- Straight after a plot, with the viewer in front, the entry works.
- Pressing a Calculator selector does it too (measured the same day by the verifier of
  issue 1724's closing pass: the design in the second tab, the viewer's window on the
  screen, a real press on `vt`). Before the press the current context was the design's
  tab; after it the pick was armed with the FIRST tab's sheet in front, and the output
  held shape 2's line, `new_schematic("switch",...): Warning: .x1.drw has been
  destroyed`. Nothing wrong is inserted: a real click on the sheet that came to the
  front left the Calculator's buffer as it was and said `selector vt: this window is on
  another schematic now; pick cancelled`. Unlike Select On Design, which stays armed
  after its refused click, the pick is cancelled by that click: the user presses the
  design's tab, presses the selector again and clicks.

A cure in the caller does not hold: a switch back to the design's context once the entry
has settled is undone by the next crossing of the other window.

### The cure proposed, two symbols, NOT built

Tried in a scratch build outside the repository, on four flows only, not on the
regression population:

- `handle_window_switching()` in `src/callback.c`: under the tabbed interface an event
  whose window is `.drw` is for the tab in front, `get_drw_front_win()`, not slot 0 (the
  slot number, the comparison with the current context and the `new_schematic` calls);
- `switch_window()` in `src/xinit.c`: for a context with an empty top path (a tab) the
  widget asked of Tk is `.drw`, so the redraw-only restore to a tab succeeds.

With the second alone, the flow with the pointer in the session window passed and a
pointer resting over an overlap still flipped the tab. With both, shape 1's probe and the
three ASE-L flows tried ended right. The first is the same change as "Proposed fix" above,
applied to every event and not only to the redraw-only arm.

A fence, once the engine is changed: shape 1 as a row beside K6's (two tabs, the second in
front, a real window beside the main one, the REAL pointer warped there and back; the
sheet shown is still the second tab's), and the same with the window under the main one.
The row must place the real pointer itself: on Xvfb it rests at the screen's centre, and
the same scenario passes or fails with where it happens to be.

The probes are in that review's scratch (`review3/verify-journey/`: `v1e.tcl` is shape 1
with no ASE-L; `v1.tcl` the flows through Select On Design; the traced build is `bld/`).
That directory is session scratch and will not last, which is why the steps are here.
