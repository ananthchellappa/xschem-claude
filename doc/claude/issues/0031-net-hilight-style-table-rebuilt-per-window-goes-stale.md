# Issue 0031 — net-highlight style table is compiled per-window and only the current window is rebuilt, so other windows go stale and wrap highlight styles to the wrong row

**Opened:** 2026-06-25
**Status:** ✅ RESOLVED (2026-06-25) — `update_net_hilight_style` now calls new
`net_hilight_invalidate_other_styles()` (hilight.c), which frees every OTHER open context's
compiled `net_hilight_style[]` (my_free NULLs it) so each rebuilds lazily from the just-edited
global Tcl var via `get_hilight_style()`. Took option 1 (lazy-invalidate, no borrow/draw). Verified
with a two-window GUI RED/GREEN test: window A (stale 2-row table) errors on style idx 3 BEFORE the
update reaches it (proving switch alone doesn't rebuild), and resolves idx 3 (marching offset 2.0)
AFTER the update in window B invalidates A — the update→invalidate is the sole differing action.
Regression suites green. Discovered while building the Phase B test harness for multi-window
net-highlight animation, `doc/claude/suggestions/plan_net_hilight_multiwindow_anim.md`. Pre-existing
behavior, **not** introduced by the Phase A/B borrow work.
**Affects:** `build_net_hilight_styles()` / `get_hilight_style()` (`src/hilight.c`),
`xschem update_net_hilight_style` (`src/scheduler.c:8172`), the per-`xctx`
`net_hilight_style[]` / `n_net_hilight_styles` table. Each open window/tab has its own
`Xschem_ctx` and thus its own compiled table.
**Severity:** low–medium — wrong highlight style (color/width/dash/**blink**/march) in any
window that wasn't the one where the style table was last edited. Most visible for the
multi-window animation feature: an animating style added in one window renders **static** in
another. No crash, no data loss.
**Branch:** `fluid-editing`. See [[net-hilight-styles]], [[multi-window-detach]].

---

## 1. Symptom

With two or more windows open, add/append a net-highlight style (edit the global
`net_hilight_style` Tcl list, e.g. via `net_hilight_apply` or the `net_hilight_style_*`
editors) and `xschem update_net_hilight_style`. Highlight a net **in a different window** with
the new style's index: that window renders the **wrong** style — typically the new index wraps
back to an old row (e.g. a freshly added blinking style at index 15 shows as solid style 0).
The window where the table was edited renders it correctly.

Concretely (the Phase B test hit this): window B appended a blinking style at index 15 and
rebuilt B's table (16 rows). Window A, built earlier with 15 rows (0–14), was never rebuilt;
highlighting a net in A with style 15 mapped `15 % 15 == 0` → solid style 0 → **no blink**.

## 2. Root cause

The `net_hilight_style` **Tcl variable is global** (one table, shared by all windows), but the
**compiled C table is per-`xctx`** and is rebuilt only for the *current* window:

```c
/* src/scheduler.c:8172 — rebuilds the CURRENT xctx only */
else if(!strcmp(argv[1], "update_net_hilight_style")) {
  build_net_hilight_styles();          /* operates on the global xctx */
  draw();
  net_hilight_anim_update();           /* front window only */
}
```

```c
/* src/hilight.c — each window builds lazily from the global Tcl var, then caches count */
void build_net_hilight_styles(void) { ... xctx->n_net_hilight_styles = nrows; ... }

NetHilightStyle *get_hilight_style(int value) {
  if(!xctx->net_hilight_style || xctx->n_net_hilight_styles <= 0) build_net_hilight_styles();
  n = xctx->n_net_hilight_styles;      /* THIS window's cached row count */
  if(value < 0) value = 0;
  return &xctx->net_hilight_style[value % n];   /* stale n -> wrong row */
}
```

So a window keeps whatever table it last compiled (at creation, or its last
`update_net_hilight_style`, or an `enable_layers()` rebuild). It does not track later edits made
while another window was current. The `value % n` wrap then silently maps an out-of-range index
onto a stale row rather than erroring.

## 3. Fix

Make a style-table edit apply to **every** open context, or invalidate the others so they
rebuild on next use. Options:

1. In the `update_net_hilight_style` handler, iterate `save_xctx[]` (honoring the
   single-schematic caveat — see the Phase A borrow notes in
   `plan_net_hilight_multiwindow_anim.md`) and `build_net_hilight_styles()` for each, or just
   mark each `n_net_hilight_styles = 0` so the lazy path in `get_hilight_style()` rebuilds it.
   The Phase A `net_hilight_borrow_ctx()` primitive is a ready, side-effect-free way to retarget
   each context for the rebuild.
2. Alternatively, make the compiled table genuinely shared (single global table) rather than
   per-`xctx`, since the source Tcl var is already global. Bigger change; revisit only if the
   per-window split has no other purpose (it may, for per-window layer sets — `enable_layers()`
   also rebuilds, and the default table is layer-derived, so a fully shared table would need
   care for windows with different active layers).

Whichever path, also (re)evaluate the animation tick for every affected window after the
rebuild, not just the front (ties into Phase D of the multi-window-anim plan).

## 4. Tests

- Two windows; in window B append a blinking style and `update_net_hilight_style`; switch to A
  and highlight a net with that style index. Assert `xschem get net_hilight_animated .A` (Phase B
  query) is 1 / the highlight actually blinks — fails today (wraps to a non-animating row),
  passes after the fix.
- Regression (`create_save`/`open_close`/`netlisting`) stays green.

## 5b. Follow-up: repaint other windows' PIXELS, not just their table (2026-06-25)

A `/code-review high` noted the original fix invalidated other windows' compiled tables but
`update_net_hilight_style` only `draw()`s the current window — so a STATIC (non-animating) detached
window kept showing the OLD style until it independently repainted. Added
`net_hilight_redraw_other_windows()` (hilight.c): after invalidating, it borrows each other detached
window and `draw()`s it, with the same cross-window guards as `redraw_hilight_region` (skip mid-gesture,
skip background tabs, skip unexposed windows with no save_pixmap). Verified by pixmap RED/GREEN
(redrawother.tcl): a style edit in window A now changes window B's backing pixmap (a control confirms
the var-change alone does not). Animating windows were already covered by their tick.

## 5. Notes

Found as a **test-harness gotcha** during Phase B of the multi-window net-highlight animation
work: the test had to call `xschem update_net_hilight_style` after switching to each window to
force its table to match the global list, otherwise the front window's highlight silently used a
stale row. That workaround masks the underlying product issue logged here. Directly relevant to
the multi-window animation feature (an animating style must look the same in every window) —
worth fixing alongside Phase D (which already plans to arm/refresh every window).
