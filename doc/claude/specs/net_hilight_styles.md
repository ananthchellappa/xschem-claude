# Net Highlight Styles — Customizable, Command-Driven Net Highlighting

Status: SPEC (Pass 1 = no animation). Author handoff doc.
Related memory: [[hover-highlight]], [[apply-scope-highlight]], [[action-registry]], [[cadence-bindkeys]].

## 1. Goal

Bring xschem net highlighting closer to Cadence Virtuoso's `display.drf` model:
a **command-driven**, **user-customizable** highlight system where the set of
highlight "styles" is defined in a sourced Tcl table rather than hardwired. Unlike
Cadence (which is limited to 10 highlight packets `y0`..`y9`), we support an
**arbitrary number of styles**, each controlling **color, thickness, dash pattern,
and stripe angle**, with **blink and marching-ants animation designed in but deferred
to Pass 2**.

Being command-driven is a deliberate strategic choice: it is the bridge for future
interoperation with simulation waveform viewers and back-annotation tools, which can
drive highlights via `xschem hilight_netname -style N <net>` over the existing Tcl
channel (the `*_backannotate.tcl` files are precedent).

## 2. Scope

### Pass 1 (this spec) — NO animation
- Decouple "highlight style" from "layer color" (the load-bearing refactor).
- A Tcl style table `net_hilight_style`, sourced from a file, compiled on the C side.
- Per-style: **color, width, dash-pattern, stripe-angle-deg** (static visual).
- The animation columns (**blink_ms, anim, rate_persec**) are *parsed and stored from
  day one* but **ignored** in Pass 1. This keeps the file format and command contract
  stable so Pass 2 adds behavior without changing the schema.
- An explicit rebuild command (changing the Tcl variable alone is NOT enough).
- Interactive keyboard shortcuts `9` / `8` / `0` in `cadence_style_rc`, supporting both
  noun-verb and verb-noun interaction.

### Pass 2 (animation — the only genuinely new subsystem)
- **Pass 2a — blink (`blink_ms`) — DONE.** A per-window self-rescheduling Tcl `after`
  tick (precedent `update_process_status`) triggers a *regional* redraw (union bbox of the
  animating nets via `bbox(START/ADD/SET/draw/END)` — NOT a full `draw()`) so the C blink
  gate (`net_hilight_style_on_now` in `draw_hilight_net`) can toggle each net on/off in real
  time. Global kill-switch Tcl var `net_hilight_animate` (1 = on); never animates headless,
  with the switch off, or mid-gesture. Change-detection redraws only at blink edges. Test
  hook `net_hilight_test_now_ms` overrides "now" for deterministic frame sampling. Commands:
  `xschem get net_hilight_animated`, `xschem redraw_hilight_region`.
- **Pass 2b — marching-ants (`anim`, `rate_persec`) — DONE.** Reuses 2a's timer + regional
  redraw and animates the dash offset: `net_hilight_march_offset(st, now)` =
  `dir·(rate_persec·P·now_s) mod P` (period `P` = `sum(dash_arr)`, doubled for an odd
  `dash_len`; `dir` from `march_fwd`/`march_rev`), threaded into the flat path's `XSetDashes`
  phase and the cairo striped path's band start so the dashes/stripes crawl. Wire-only (symbols
  are colored, never marched). Gated like blink (offset 0 on ordinary/hardcopy draws →
  deterministic export). The change-detection signature folds `(int)offset` so the tick redraws
  only when the pattern moves ≥1px, at a ~30fps frame cadence. Test/introspection hook
  `xschem net_hilight_march_offset <idx>` returns the offset at the forced `net_hilight_test_now`
  time. A style needs `anim != none`, a dash pattern, AND `rate_persec > 0` to march.
- **Pass 2-multiwin — animate every visible window — DONE.** The tick was front-window-only at
  first (the C core drew the global front `xctx`). It now animates **every *visible* detached
  window simultaneously** (background **tabs** stay front-only — they share one canvas, by
  design). Mechanism (see `doc/claude/suggestions/plan_net_hilight_multiwindow_anim.md`, phases A–E, and
  FAQ Q20): a side-effect-free **context-borrow** (`net_hilight_borrow_ctx`/`_restore_ctx`)
  repoints `xctx` at a window with no GUI side effects; `xschem get net_hilight_animated <win>`
  and `xschem redraw_hilight_region <win>` evaluate/draw *that* window via the borrow;
  `net_hilight_anim_update()` arms **every** open window; the per-window tick gates on
  **`winfo viewable`** (a `<Visibility>` binding re-arms on de-iconify). Serialization: no window
  animates a frame while the focused window is **mid-gesture** (`net_hilight_ctx_busy()` on the
  pre-borrow context); the global wall-clock keeps all windows in phase. The borrow's only
  draw-path risk is the file-scope draw batch buffers, safe because each borrow wraps one
  complete, non-reentrant `draw()`.

## 3. The style table

### 3.1 Variable and file

A Tcl list named `net_hilight_style`, set in a file the user `source`s (or directly in
`~/.xschem/xschemrc` / `cadence_style_rc`). A default table ships in `xschem.tcl` so the
feature works out-of-the-box and reproduces today's behavior.

Each row is a list with these columns, in order:

| Col | Name              | Meaning                                                              | Pass 1 |
|-----|-------------------|---------------------------------------------------------------------|--------|
| 1   | `index`           | Style id (0-based). Determines table ordering / cycling position.    | used   |
| 2   | `color`           | Color spec: `#rrggbb`, X color name (`yellow`), or layer index.      | used   |
| 3   | `width`           | Line thickness. **`1` = same thickness as the thinnest wire.**       | used   |
| 4   | `dash-pattern`    | Tcl list of on/off run lengths, e.g. `{}` solid, `{4 4}`, `{8 4 2 4}`.| used  |
| 5   | `stripe-angle-deg`| Tilt of dash "stripes" on a thick line. Clamped to **[-45, 45]**.    | used*  |
| 6   | `blink_ms`        | Blink period in ms (`0` = steady). **Live (Pass 2a).**               | used   |
| 7   | `anim`            | Marching mode: `none` / `march_fwd` / `march_rev`. **Live (Pass 2b).**| used   |
| 8   | `rate_persec`     | Marching speed in dash-periods/sec (needs `anim`+dash). **Live (2b).**| used   |

\* `stripe-angle-deg` is parsed, clamped to **[-45,45]** (see the 2026-06-27 note below;
originally [0,45]), and stored in Pass 1, but **nonzero angles are rendered as plain 0°
dashes until Pass 1.5** (tilted-stripe rendering needs Cairo hatch; see §7 / Phase 5).

Example (`net_hilight_style_rc`, to be `source`d):

```tcl
# index  color      width  dash         angle  blink anim        rate
set net_hilight_style {
  {0  "#ff0000"   1   {}          0    0    none        0 }
  {1  "#00ff00"   2   {4 4}       0    0    none        0 }
  {2  "yellow"    3   {8 4 2 4}   30   0    none        0 }
  {3  "#0099cc"   2   {6 6}       45   0    none        0 }
  {4  "#ce0097"   1   {}          0    0    none        0 }
  ...
  {37 "cyan"      4   {10 4}      20   0    none        0 }
}
xschem update_net_hilight_style
```

There is **no 10-entry limit**. The table length *is* the number of styles.

### 3.2 Semantics of columns

- **color**: resolved on the C side to an X pixel via the existing
  `find_best_color()` path (same as `hover_highlight_color`/`slickprop_highlight_color`).
  Accepting a bare integer also lets a style alias an existing layer color for
  backward-compatible defaults.
- **width**: `1` maps to the thinnest wire rendering (`XLINEWIDTH(xctx->lw)` baseline);
  values `> 1` are integer multiples of that base width. Widths scale with zoom exactly
  as wire widths do (honoring `change_lw`/`min_lw`), so highlights track the wire.
- **dash-pattern**: an empty list `{}` is solid. A non-empty list is fed to Xlib
  `XSetDashes` (and `cairo_set_dash`) as the on/off run pattern. With width > 1, each
  "on" run is a band across the line = a **stripe**; with `angle = 0` the bands are
  perpendicular to the wire (a barcode).
- **stripe-angle-deg**: tilts the stripes. `0` = perpendicular (native dash). A positive
  angle shears the stripes one way, a **negative angle shears them the other way**; as the
  magnitude grows toward parallel-with-the-wire it becomes degenerate, so the input is
  **clamped to [-45°, 45°]**. When clamping occurs, `update_net_hilight_style` emits a
  **warning to the log/CIW** naming the offending style index and the original vs clamped
  value. (Range was [0,45] through 2026-06-26; widened to [-45,45] on 2026-06-27 — the
  original upper-only bound was an oversight that permitted a tilt in one direction only.)
- **blink_ms** (Pass 2a) / **anim + rate_persec** (Pass 2b): the animation columns. `blink_ms>0`
  blinks the highlight; `anim` (`march_fwd`/`march_rev`) with a dash pattern and `rate_persec>0`
  scrolls the dashes ("marching ants"). A negative `rate_persec` is clamped to 0 with a warning;
  a marching style with no dash, or `rate_persec<=0`, is warned and does not march. They compose
  (a style can both blink and march).

## 4. Decoupling style from layer color (the refactor)

Today (`hilight.c`):
- `Hilight_hashentry.value` (per net) and `xInstance.color` hold a **color index**.
- `get_color(value)` maps it modulo `n_active_layers` onto a **layer color**.
- `incr_hilight_color()` advances `xctx->hilight_color` modulo `n_active_layers*cadlayers`.

After Pass 1:
- `value` / `inst.color` hold a **style index** into the compiled style table.
- A new resolver `get_hilight_style(value)` returns a `NetHilightStyle*` (color pixel,
  width, dash, angle, …). The legacy `get_color()` becomes a thin wrapper that returns
  `style->color_layer` for any code path still asking only for a color.
- `incr_hilight_color()` advances modulo **`n_net_hilight_styles`** (the table length).
- **Backward compatibility**: the default table is generated to reproduce the current
  layer-color cycling (one steady, solid, width-1 style per active layer), so existing
  behavior, tests, and `.sch`-embedded highlights are unchanged when no custom table is
  provided.

Touch points (from code survey):
- `src/hilight.c`: `get_color()` (~359), `incr_hilight_color()` (~372),
  `draw_hilight_net()` (~2191) — switch the `drawline(get_color(...), THICK, ...)` calls
  to select the style's GC (color+width+dash) instead of a layer color.
- `src/xschem.h`: `Hilight_hashentry` (~807), `xctx->hilight_color` (~1074); add the
  style-table array, count, and GC pool fields to `Xschem_ctx`.
- `src/xinit.c`: build/destroy the per-style GC pool alongside `gc_hover`/`gc_scope`
  (`create_gc` ~445, the hover/scope GC config ~1089-1117).

## 5. Commands

### 5.1 `xschem update_net_hilight_style`
Re-reads the `net_hilight_style` Tcl variable, (re)compiles it into the C style array,
resolves colors to pixels, **clamps stripe angles to [-45,45] with a warning per clamp**,
rebuilds the per-style GC pool, and triggers a redraw. **Must be called after changing
the table** — the Tcl variable alone has no effect because styles are compiled into GCs.
(Naming: `update_net_hilight_style` chosen for prefix consistency with the
`net_hilight_style` variable; see open decision in §8.)

### 5.2 `xschem hilight_netname [-style N] [-fast] <net>` (extend existing)
`-style N` highlights `<net>` with style index `N` explicitly (no cursor advance). This
is the **waveform-viewer / back-annotation bridge**. Without `-style`, behavior is
unchanged (uses the current cursor + auto-increment rules).

Analogous `-style` extension for `xschem hilight` / `hilight_instname` where it makes
sense.

### 5.3 Existing commands reused unchanged
- `xschem unhilight_all` — clear all highlights (bound to key `0`).
- `xschem unhilight` — clear highlights on the current selection.

### 5.4 Style cursor / increment semantics
A "current style cursor" (`xctx->hilight_color`, repurposed as a style index) advances
by one **each time a highlight is applied**, and **wraps**: after the last row it
returns to row 0 and cycles (advance is modulo table length,
`n_net_hilight_styles`). Re-highlighting the same net therefore moves it to the next
style. This governs both interactive paths (§6). Explicit `-style N` does not advance
the cursor (and is itself taken modulo the table length so an out-of-range index is
always valid).

## 6. Interactive keyboard shortcuts (in `cadence_style_rc`)

All three bind via the data-driven action registry
(`xschem bind key <keysym> 0 canvas <action>`), preempting the legacy C digit handlers
(`'8'`/`'9'` are no-ops bare; `'0'` toggles pin logic — all safe to override in this rc).
The status-bar prompt reuses the wire-draw mechanism (`update_statusbar`, the
`{DRAW WIRE! }` slot `.statusbar.10`); the CIW message uses `ciw_echo` (per
[[ciw-feedback-channels]], not `puts`/statusbar).

### 6.1 Key `9` — Highlight net (noun-verb AND verb-noun)
- **Noun-verb** (selection contains net wire(s) and/or label(s)): highlight the selected
  net(s) using the style cursor, advancing the cursor per net highlighted. **The
  selection is LEFT INTACT** (do not `unselect_all`). Command completes immediately.
- **Verb-noun** (nothing selected): enter **Highlight-Net mode**:
  - Status bar shows a persistent prompt (e.g. `HIGHLIGHT NET — click a net/label, ESC to exit`).
  - A matching prompt is echoed to the CIW log via `ciw_echo`.
  - Each left-click highlights the net/label under the cursor with the current style,
    then **advances the cursor** (so successive clicks — even on the same net — cycle
    styles).
  - Mode persists until **ESC** (handled in `abort_operation`).
  - Clicks in mode are transient (they do not leave the net selected).

Both "net" forms are supported: a **wire** (`xctx->wire[n].node`) and a **label**
(a label/pin instance). Implementation resolves the clicked/selected object via
`find_closest_obj` and routes through the existing `hilight_net()` (which already
handles wires, labels, pins, and propagation).

### 6.2 Key `0` — Unhighlight all
Bound directly to `xschem unhilight_all`. Removes all net highlights.

### 6.3 Key `8` — Remove specific net highlight (noun-verb AND verb-noun)
- **Noun-verb** (selection contains net/label): remove highlight on the selected net(s)
  (`xschem unhilight`), leaving the selection intact.
- **Verb-noun** (nothing selected): enter **Unhighlight-Net mode** — same prompt/CIW/ESC
  pattern as §6.1, but each click removes the highlight on the net/label under the cursor
  (hash `XDELETE` + redraw). Persists until ESC.

### 6.4 Modes — implementation notes
- New `ui_state` bits, e.g. `STARTHILIGHTNET` and `STARTUNHILIGHTNET`
  (`xschem.h` ~221), modeled on `STARTWIRE`.
- Prompt added as a branch in `update_statusbar` (`callback.c` ~5713).
- ESC clears the bits in `abort_operation` (`callback.c` ~173) and the Escape case
  (~4905).
- Click handling: a branch in the Button1 dispatch (`callback.c` ~5189) that, when a
  mode bit is set, finds the net under the cursor and add/removes its highlight, then
  returns (does not fall through to normal selection).

## 7. Pass 1 phase breakdown
See the implementation plan (`doc/claude/suggestions/plan_net_hilight_styles.md`). Summary:
1. Style-table data model + decoupling (color only; visual parity, now style-indexed).
2. Per-style width + dash rendering via a GC pool (the 0° barcode case).
3. `update_net_hilight_style` (with angle clamp+warn) + `-style N` command arg +
   default table in `xschem.tcl` + example `net_hilight_style_rc` + docs.
4. Interactive keys `9`/`0`/`8`: modes, noun-verb/verb-noun, prompts, CIW, ESC,
   `cadence_style_rc` bindings.
5. (Flagged / deferrable to Pass 1.5) Nonzero stripe-angle rendering via Cairo clip+hatch;
   Xlib-only builds fall back to angle 0 with a one-time warning.

## 8. Decisions (LOCKED 2026-06-23)
1. **Update-command name**: `update_net_hilight_style`.
2. **Multi-net noun-verb increment**: advance the cursor **per net** — N selected nets
   get N successive styles (matches Cadence's "each highlight a new color").
3. **Stripe-angle scope**: **deferred to Pass 1.5.** Pass 1 ships color + width + dash +
   0° barcode (Phases 1-4). Nonzero stripe angles (Cairo hatch rendering) come after.
   The `stripe-angle-deg` column and the clamp-to-45°+warning in
   `update_net_hilight_style` are still implemented in Pass 1 so the schema and command
   contract are final; only the *rendering* of nonzero angles is deferred (until then a
   nonzero angle is accepted, stored, and rendered as a plain 0° dash).

## 9. Non-goals / constraints
- **Width/dash/angle apply to wires; COLOR also applies to symbols.** The width, dash and
  stripe-angle of a style are applied to highlighted **wire segments** only. The style's
  **color** is applied to both the wires and the instances/pins/labels on the net,
  including the net-label and pin-name **text** — so a custom-RGB style colors the whole
  highlight consistently (wire + label/pin text), not just the wire. Symbols are not
  striped/widened (only colored). Implementation: `draw_hilight_net()` briefly repoints the
  fallback layer's GC + `xcolor_array` to the style's pixel around the `draw_symbol()` call
  for custom-RGB styles (layer-index styles already resolve through that layer's color).
- **Export renderers** (`svgdraw.c`, `psprint.c`) and the ngspice plot-color generator
  resolve highlights through the layer-index path (`get_color`), so exported SVG/PDF/PS
  reflect highlight *color* (approximately, via a fallback layer for custom RGB) but not
  width/dash. On-screen rendering is the Pass-1 deliverable.
- **Custom named colors** are resolved to a pixel once (at `update_net_hilight_style`).
  On a TrueColor visual (the modern default) those pixels are stable across colorscheme
  changes. On legacy palette (PseudoColor) visuals, re-run `xschem
  update_net_hilight_style` after switching colorscheme to re-resolve them. (Not hooked
  into `build_colors`, which is on the redraw/dim hot path.)
- No animation in Pass 1 (blink, marching ants) — schema only.
- C89 throughout; nonzero stripe angles require Cairo (`HAS_CAIRO`); Xlib-only builds
  degrade gracefully to angle 0.
- Per-window/per-tab correctness: each `xctx` owns its GC pool; the rebuild iterates
  live windows (relevant given multi-window work, [[multi-window-detach]]).
