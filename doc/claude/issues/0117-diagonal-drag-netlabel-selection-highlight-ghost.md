# 0117 — diagonal fluid drag of a net-label leaves a selection-highlight ghost at the leg-A pin row

**Status: FIXED** (working tree). Reported by user (windowed feel test, GIF capture
`/tmp/demo_ghost_drag_net_label_diagonal`, trace `/tmp/fltrace_7_8_28.log`):
"Open `tests/from_user/before_9.sch`, press-and-drag the only wire-label (connected to the wire
at 160,-30) diagonally to 90,-10 (left AND down). A selection-highlight ghost line stays from
(90,-30) to (160,-30). ESC (full redraw) clears it."

**Affects:** interactive **diagonal** fluid connected-drag/stretch (`fluid_editing` on) of any
pin-bearing object — the X-then-Y (`nlegs==2`) decomposition. Cosmetic only: the SAVED geometry is
correct (`after_30.sch` — 3 wires `[90 -10 160 -10]`, `[160 -10 160 0]`, `[160 -50 160 -10]`, none
at y=-30). Same *visual family* as 0080/0115 (a stale selection overlay) but a **different root
cause** — not the `draw_selection` delta/rot double-apply, so the 0080/0115 wrapper does not cover
it. Only appears on diagonal drags (a pure H or V drag is `nlegs==1`, no intermediate leg).
**Branch:** `fluid-editing`. **Related:** 0081 (X-then-Y leg decomposition), `incremental_wire_reroute.md`.

---

## 1. Symptom

During/after a diagonal drag the moved follow-wire's **selection highlight** is stroked a second
time at the *intermediate* leg-A position — final drop x, but original y — and that stroke is
baked into `save_pixmap`, so it survives every subsequent redraw until a full `xschem redraw`/ESC.
For the repro: follow wire ends at y=-10, ghost highlight sits at y=-30 (the original pin row),
spanning x 90..160.

## 2. Root cause — a spurious highlight stroke from the between-legs SET regrab

Diagonal fluid stretch commits in two legs (issue 0081): leg A = (Δx,0), leg B = (0,Δy). Between
them, `move_regrab_follow_set()` (move.c) re-derives the tool-owned follow set off the **X-moved,
not-yet-Y-moved** geometry by calling `select_attached_nets()` (select.c). That function grabs each
attached wire with `select_wire(i, SELECTED1/2, fast=1, 0)` — and `fast=1` has bit 2 CLEAR, so
`select_wire` **strokes the selection highlight** (`drawtempline(gc[SELLAYER], …)`) at the wire's
*current* coordinates. At regrab time those coordinates are the leg-A intermediate
`[90 -30 160 -30]`. That stroke lands in `save_pixmap`; leg B then moves the geometry to y=-10, but
nothing re-clears the y=-30 row, so the highlight ghost persists.

`select_attached_nets()` was only ever meant to re-derive the selection SET here — the drawing is an
unwanted side effect of `select_wire`'s dual role (mutate `.sel` + stroke overlay).

### Why 0080/0115's wrapper doesn't catch it
Those fixes neutralize `draw_selection()`'s `delta/rot/flip` while `fluid_reroute_dirty`. This ghost
is NOT drawn by `draw_selection()` — it is `select_attached_nets()` → `select_wire()` calling
`drawtempline()` directly, bypassing the wrapper entirely (confirmed by backtrace:
`drawtempline ← select_wire ← select_attached_nets ← move_objects ← end_move_copy_logged`).

### Why it reproduces interactively but not in the scripted/headless path
The scripted `move_objects` END and the headless windowed run both end with a full `draw()` that
happens to flush over the stale stroke, so `xschem saveas`/PNG capture look clean. Under the real
interactive event stream (crosshair/hover repaints + WSLg pixmap→window blit timing) the leg-A
stroke reaches the window after the clearing redraw, so it lingers. The scripted **geometry** is
byte-identical with and without the fix — so wireedit regressions stay green either way; the defect
is purely the extra stroke.

## 3. Fix (`select.c`, `move.c`, `xschem.h`)

Add `xctx->select_attached_nodraw`. `move_regrab_follow_set()` sets it around its
`select_attached_nets()` call; `select_attached_nets()` computes `int fast = nodraw ? 3 : 1` and
passes it to its four `select_wire()` grabs (bit 2 = suppress the stroke, bit 1 = stay quiet as
before). So the between-legs regrab re-derives the SET only; the final END `draw()` repaints the
real highlight at the committed geometry. Every other `select_attached_nets()` caller (gesture
START) is unchanged (`nodraw==0` ⇒ `fast==1`, byte-identical) — and their stroke is at the correct
current geometry anyway. Default-off `fluid_editing` never reaches this path.

## 4. Verification

- **Instrumented proof:** a gated `drawtempline` probe + `backtrace` showed exactly one emitter of
  a `gc=SEL [90 -30 160 -30]` stroke — `select_attached_nets` via `move_regrab_follow_set`. After the
  fix that emit count is **0** (probe removed after measuring).
- **Geometry unchanged:** scripted diagonal drag of `before_9.sch` yields the identical 3 wires
  pre- and post-fix.
- **Regressions:** wireedit 56/56 ALL PASS (drives the same two-leg regrab); fluid + connected-drag
  windowed suite green — 0098/0105/0106/0107/0108/0109/0111 + reversal 0088/0089/0096 +
  connected-drag 0113/0114. `test_fluid_editing` FE8 fails identically on baseline HEAD (a
  pre-existing arc drag-and-return failure, unrelated).

## 5. Repro (interactive)

1. `FLUID_TRACE=/tmp/t.log src/xschem --script src/cadence_style_rc --logdir /tmp`
2. Open `tests/from_user/before_9.sch`.
3. Press-and-drag the wire-label (at 160,-30) diagonally to 90,-10 (left + down).
4. Pre-fix: a highlight ghost stays from (90,-30) to (160,-30) until ESC. Post-fix: none.
