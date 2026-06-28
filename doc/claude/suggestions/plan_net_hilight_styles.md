# Plan — Net Highlight Styles (Pass 1, no animation)

Spec: `doc/claude/specs/net_hilight_styles.md`. This plan covers Pass 1 only. Animation (blink,
marching ants) is Pass 2 and is designed-for but not built here.

Guiding principle: land the **decoupling + static styling + commands** first (low risk,
reuses existing GC/dash/color machinery), then the **interactive keys** (modes), and
keep **nonzero stripe-angle rendering** isolated as the last, deferrable phase because it
is the only piece that needs new Cairo hatch rendering.

---

## Phase 0 — Survey confirmations (done)
Key anchor points confirmed by code survey:
- Highlight value→color: `get_color()` `hilight.c:359`, `incr_hilight_color()` `:372`,
  `draw_hilight_net()` `:~2191`; `Hilight_hashentry.value` `xschem.h:807`;
  `xctx->hilight_color` `xschem.h:1074`.
- GC precedent: `gc_hover`/`gc_scope` create `xinit.c:445` (`create_gc`), config
  `xinit.c:1089-1117`; width via `change_linewidth` `xinit.c:2374` + `XLINEWIDTH`.
- Dash: `drawline` dash branch `draw.c:1396-1411` (`XSetDashes`,`LineOnOffDash`); Cairo
  `my_cairo_drawline` `draw.c:1261-1264` (`cairo_set_dash`).
- Color resolve: `find_best_color()`; defaults `light_colors`/`dark_colors`
  `xschem.tcl:12601-12635`.
- Modes: `ui_state` `xschem.h:221`; `update_statusbar` `callback.c:5713`;
  `abort_operation` `callback.c:173`; Escape `callback.c:4905`; Button1 dispatch
  `callback.c:5189`.
- Find net: `find_closest_obj` / `find_closest_wire` `findnet.c:28`,
  `find_closest_net_or_symbol_pin` `findnet.c:201`; net name `xctx->wire[n].node`.
- CIW/status: `statusmsg` `scheduler.c:28`; `log_action`/`ciw_echo` `util.c:346`.
- Selection query: `xschem get lastsel` `scheduler.c:1764`, `first_sel` `:1698`,
  `xschem selection` `:6595`; types `WIRE=1 … xTEXT=16 ELEMENT=8` `xschem.h:265`.
- Keybind: `cadence_style_rc` (`src/`); `xschem bind key` → `action_cmd_bind`
  `callback.c:3265`; registry `set_input_binding` `:2906`, `dispatch_input_action`
  `:3088`, `handle_key_press` `:3686`. Digits `8/9` bare are no-ops, `0` toggles pin
  logic — safe to override.

---

## Phase 1 — Style-table data model + decoupling (color only)
**Outcome:** highlights are indexed by *style*, not layer color; visual output is
identical to today (default table reproduces layer cycling). No new visuals yet.

C structures (`xschem.h`):
```c
typedef struct {
  int   index;
  unsigned int color;     /* resolved X pixel */
  int   color_layer;      /* layer fallback for get_color() compat, -1 if pure pixel */
  int   width;            /* multiples of base wire width; >=1 */
  char *dash;             /* raw "on off ..." spec, NULL/"" = solid */
  int   dash_len; char dash_arr[16];
  int   angle;            /* 0..45, clamped */
  int   blink_ms;         /* Pass 2 */
  int   anim;             /* 0 none,1 fwd,2 rev — Pass 2 */
  int   rate_persec;      /* Pass 2 */
  GC    gc;               /* per-style GC: color+width+dash baked in */
} NetHilightStyle;
```
Add to `Xschem_ctx`: `NetHilightStyle *net_hilight_style; int n_net_hilight_styles;`.

Edits:
- `hilight.c`: add `get_hilight_style(int value)` → `&xctx->net_hilight_style[value %
  n]`. Reduce `get_color()` to return `get_hilight_style(value)->color_layer` (or the
  resolved color) so any color-only caller is unaffected.
- `incr_hilight_color()`: advance modulo `xctx->n_net_hilight_styles`.
- Build a **default table** (in C or `xschem.tcl`) = one steady/solid/width-1 style per
  active layer, so behavior is unchanged when the user supplies no table.

**Verify:** build clean; `tclsh run_regression.tcl` green (highlighting golden output
unchanged). Sabotage-check per [[green-but-hollow]]: temporarily set a default style to
a wrong color, confirm a highlight test actually changes, then revert.

---

## Phase 2 — Per-style width + dash rendering (GC pool, 0° barcode)
**Outcome:** color + thickness + dash pattern all honored. Stripe-angle still 0.

- `xinit.c`: `build_net_hilight_gcs()` — for each style, `XCreateGC`, set foreground to
  the resolved pixel, `XSetLineAttributes(width, dash?LineOnOffDash:LineSolid, …)`, and
  `XSetDashes` from `dash_arr`. Create alongside `gc_hover`/`gc_scope`; free in the
  matching teardown. Width maps `style.width` → `XLINEWIDTH(xctx->lw) * style.width`.
- `hilight.c::draw_hilight_net()`: replace `drawline(get_color(entry->value), THICK,…)`
  with a draw that uses `style->gc` (a `drawline_gc`-style helper, or temporarily point
  the layer GC at the style attributes). Mirror for the Cairo path
  (`my_cairo_drawline` + `cairo_set_dash`, `cairo_set_line_width`).
- Endpoint dots (`filledarc`) take the style color.

**Verify:** manual GUI smoke test — define 3 styles (solid thin, dashed medium, dashed
thick), highlight three nets, confirm distinct width+dash. Regression still green.

---

## Phase 3 — Commands, default table, settings file, docs
- `scheduler.c`: add `xschem update_net_hilight_style` — read `net_hilight_style` Tcl
  var (`tclgetvar` + Tcl list parse, or `Tcl_ListObj` via eval), compile to the C array,
  resolve colors, **clamp `angle` to [0,45] emitting a warning per clamp** through
  `statusmsg`/`ciw_echo` naming the style index, rebuild GC pool, redraw.
- `scheduler.c`: extend `hilight_netname` (and `hilight`) to parse `-style N`
  (explicit style, no cursor advance).
- `xschem.tcl`: ship default `net_hilight_style` (set_ne) reproducing Phase-1 defaults;
  call the compile once at startup after rc sourcing.
- New `src/net_hilight_style_rc` example (sourced, sets the table + calls
  `xschem update_net_hilight_style`).
- Docs: short section in the appropriate doc + comments in `xschemrc` showing the table
  format (mirrors how `light_colors`/`dark_colors` are documented).

**Verify:** edit table → `xschem update_net_hilight_style` → highlights change; bad
angle (e.g. 70) → clamped to 45 + warning in CIW. `-style 3` path highlights with the
exact style.

---

## Phase 4 — Interactive keys 9 / 0 / 8 (modes, noun-verb + verb-noun)
- `xschem.h`: add `STARTHILIGHTNET`, `STARTUNHILIGHTNET` ui_state bits.
- `scheduler.c`: subcommands `hilight_net_interactive` / `unhilight_net_interactive`:
  - If `xctx->lastsel` has wire/label objects → noun-verb: apply (add/remove) highlight
    on the selection using the cursor (advance per net), **leave selection intact**.
  - Else → set the corresponding `ui_state` mode bit and draw the prompt.
- `callback.c`:
  - `update_statusbar` (~5713): prompt branches for the two modes.
  - Button1 dispatch (~5189): when a mode bit set, `find_closest_obj`, resolve net,
    add/remove highlight (route through `hilight_net()` / hash `XDELETE`), advance
    cursor on add, redraw, `return`. Transient (no leftover selection).
  - `abort_operation` (~173) + Escape (~4905): clear the mode bits.
  - CIW prompt via `ciw_echo` on mode entry.
- `cadence_style_rc`: register/locate action ids and bind:
  ```tcl
  xschem bind key 57 0 canvas net.hilight          ;# '9'
  xschem bind key 48 0 canvas net.unhilight_all    ;# '0'  -> xschem unhilight_all
  xschem bind key 56 0 canvas net.unhilight        ;# '8'
  ```
  (Actions are Tcl-backed wrappers calling the subcommands, validated by
  `find_action_def`.)

**Verify (per [[user-run-config]], run with cadence_style_rc):**
- Select a wire, press 9 → highlighted, still selected. Press 9 again → next style.
- Select a label, press 9 → its net highlighted, still selected.
- Deselect all, press 9 → status+CIW prompt; click nets → each gets next style; ESC
  exits; prompt clears.
- Press 0 → all cleared.
- Select net, press 8 → highlight removed, still selected. Deselect, press 8 → mode;
  click highlighted net → its highlight removed; ESC exits.

---

## Phase 5 — Nonzero stripe-angle rendering (DEFERRED to Pass 1.5)
NOTE (locked 2026-06-23): Pass 1 = Phases 1-4 only. The `stripe-angle-deg` column,
parsing, clamp-to-[0,45], and warning are implemented in Phase 3; nonzero angles render
as plain 0° dashes until this phase lands. This phase is Pass 1.5.

Native dashes are perpendicular-only, so tilted stripes need custom rendering:
- Cairo path: build the thick-wire rectangle (quad) from the segment + width, set it as
  a clip, and stroke a family of parallel segments at `wire_angle + 90° - angle`, spaced
  per the dash pattern, thickness = the "on" run. Resolution-independent.
- `HAS_CAIRO` absent → fall back to angle 0 (plain dash) + one-time warning.

Isolated so Phases 1-4 ship a fully useful feature (color + width + dash + 0° barcode)
even if this phase slips.

**Verify:** a style at 30° and one at 45° render visibly tilted stripes on thick wires;
70° in the table is clamped to 45 with a warning; Xlib-only build degrades to 0°.

---

## Pass 2 — animation (split into 2a blink + 2b marching ants)

`blink_ms`, `anim`, `rate_persec` already parse and store (inert since Pass 1). Pass 2 makes
them live. It is the only genuinely new subsystem (a periodic animation tick), so it is split
into two slices that share ONE timer + regional-redraw foundation:

- **Pass 2a — blink** (`blink_ms`): a highlighted net's highlight toggles on/off with period
  `blink_ms`. Trivial per-style ON/OFF gate, no dash math — it exists to build the shared
  infra at the lowest risk.
- **Pass 2b — marching ants** (`anim`, `rate_persec`): the dash pattern scrolls along the
  wire (`march_fwd`/`march_rev`, speed `rate_persec`) by animating the dash offset. Reuses
  2a's timer + redraw; adds dash-offset plumbing.

### Shared foundation (built in 2a, reused by 2b)
1. **Animation clock** — a wall-clock ms source (Tcl `clock milliseconds`, or C
   `gettimeofday`) so periods/speeds are real-time and independent of tick jitter.
2. **Per-window tick** — a self-rescheduling Tcl `after` loop per visible window (exact
   precedent: `update_process_status`, `xschem.tcl:464/466` — `after 1000 …` + `after cancel`).
3. **The erase problem (the main technical task)** — highlights are drawn OVER the schematic
   into `save_pixmap` (no highlight-free copy), then blitted (`MyXCopyAreaDouble`). So a frame
   cannot just over-draw: it must restore the underlying pixels first by redrawing the *union
   bounding box of the highlighted nets* (schematic + current-phase highlights) via the
   `bbox(SET)/draw/bbox(END)` regional-redraw machinery — NOT a full-screen `draw()` (flicker
   + cost). Shared by both slices.
4. **Start/stop wiring** — re-evaluate after every highlight change whether the loop should run.

### Phase 2a — blink (detailed)

**A) Clock + global switch.** Tcl var `net_hilight_animate` (`set_ne 1`) as a kill-switch;
never animate when it is 0, headless (`!has_x`), or mid-gesture (`xctx->ui_state`/semaphore
busy). Read wall-clock ms at draw time.

**B) Blink gate in the draw path (`hilight.c::draw_hilight_net`).**
- `net_hilight_style_on_now(NetHilightStyle *st, ms now)` → ON if `blink_ms<=0` else
  `((now / (blink_ms/2)) & 1) == 0` (50% duty).
- Per highlighted **wire**: if its style is OFF-phase, `continue` (skip wire+dots) so the
  already-redrawn underlying wire shows. Same gate in the **instance/symbol** loop (skip
  OFF-phase instances). With `net_hilight_animate==0`/headless, force ON (no blink) so static
  PNG tests are unaffected.

**C) The tick + regional redraw (Tcl + a thin C entry).**
- `net_hilight_anim_tick(win)`: if `win` gone OR no highlighted nets OR no style needs
  animation → stop (don't reschedule); else regional-redraw the highlight bbox and reschedule
  `after TICK_MS` (~50 ⇒ ≤20 fps cap; blink cadence comes from `blink_ms`, not the tick).
- **Redraw on change only** for blink: track the last on/off state per blinking style and
  redraw only at transitions (a 1 Hz blink → 2 redraws/s, not 20). (2b redraws every tick.)
- Regional redraw entry: a new `xschem redraw_hilight_region` (sets area = union bbox of
  hilighted nets via `bbox(SET_INSIDE)`, redraws, `bbox(END)`), or verify an existing path;
  fall back to `draw()` only if a clean region path proves infeasible.

**D) Start/stop wiring (`net_hilight_anim_update(win)`).** Computes "does this window have ≥1
highlighted net whose style animates (blink_ms>0 or anim!=0)?" → start the `after` loop if so
and not running, else `after cancel` it. Store the after-id per win path. Call from:
`hilight_net_styled` / `hilight_netname` / the mode-click (after applying), `unhilight_net` /
`unhilight_all`, `update_net_hilight_style` (an edit may add/remove blink), load, and
new_schematic switch/destroy (cancel a closed window's loop). Only the **visible** window
animates (tabbed: front tab only).

**Verify (per [[green-but-hollow]]).** blink_ms=600 net visibly toggles ~1.6 Hz; blink_ms=0
steady. PNG-sample the wire region at an on-phase vs off-phase ms (present vs absent).
Sabotage: force OFF always → highlight vanishes (gate is live). CPU: no highlight → no timer;
steady highlight → no timer; blink → timer, stops on `unhilight_all`. No full-screen flicker
(regional). Multi-tab: blink follows the front tab. Headless/`net_hilight_animate 0` → steady
(static tests unchanged). Then `/code-review high`.

**Risks.** (1) regional-redraw correctness/ghosting — union bbox + small margin; (2) `after`
leaks — centralize cancel in `net_hilight_anim_update` + on window destroy; (3) the tick must
NOT `log_action` (not a user action) and must pause during move/wire gestures.

### Phase 2b — marching ants (after 2a)
Animate the dash offset on the same infra: XSetDashes 4th arg (`dash_offset`, today 0) +
`cairo_set_dash` offset; for the Pass-1.5 cairo stripe path, shift `cstart` by the animated
offset. `anim` sets the sign (fwd/rev), `offset = (rate_persec * dash_period * elapsed_s)`.
The tick now redraws every frame for marching nets (still regional). Verify a dashed style
scrolls, `rate_persec` controls speed, `march_rev` reverses, and blink+march compose.

---

## Phase 2b — RED-first plan (atomic, test-first)

Status: PLANNED (2026-06-24), after 2a (blink) shipped + verified (commits e8e1ad7e,
e2d4ff65, 381d5358; live tick verified). Each step is a RED test (fails today) → minimal
GREEN → a sabotage check. Marching is unusually amenable to TDD because most of it is a
**deterministic offset formula** you assert numerically; only the on-screen scroll needs a
PNG byte-diff (`cmp`, already proven to work by the 2a ON/OFF frames).

**The key new test seam** (the "make state an input" lesson, like `net_hilight_test_now`):
`xschem net_hilight_march_offset <styleidx>` returns the computed scroll offset at the
*forced* test time, so the math is assertable without pixel analysis.

### The offset model (every test asserts against this)
- Period `P` = `sum(dash_arr)`, **×2 when `dash_len` is odd** (the XSetDashes role-flip the
  Pass-1.5 striped path already accounts for).
- `offset(now) = dir · (rate_persec · P · now_ms/1000) mod P`, `dir = +1` (march_fwd) /
  `−1` (march_rev), reduced into `[0, P)`.
- Gated exactly like blink: nonzero **only** in an animation frame (or test hook); `0` on
  ordinary/hardcopy draws → deterministic export.

### Phase A — make a marching style "animate"
1. **Predicate recognizes marching.** RED: `xschem get net_hilight_animated` for a
   `{… {6 6} … march_fwd}` (blink_ms 0) style → `0` today. GREEN:
   `net_hilight_style_animates = blink_ms>0 || (anim!=0 && dash_len>0)`; warn at parse if
   `anim!=0 && dash_len==0` (nothing to scroll — mirror the Pass-1.5 angle-needs-dash warn).
   Sabotage: anim→none ⇒ predicate 0, no timer.

### Phase B — the offset math (pure, deterministic — the core)
2. **Queryable offset + time advance.** Add `net_hilight_march_offset(st, now)` (C) +
   `xschem net_hilight_march_offset <idx>` (uses the forced `net_hilight_test_now`). RED:
   command unknown / `0` at `now=500`. GREEN: formula with `dir=+1`, `rate=1`. Sub-RED:
   `offset(0)=0`; monotonic in now; **wraps** mod P.
3. **Direction.** RED: `offset(march_rev,t)` should be `P − offset(march_fwd,t)`, returns
   same. GREEN: `dir` from `anim`.
4. **rate_persec.** RED: `offset(rate=2,t)` should be `2·offset(rate=1,t)` (mod P), equal
   today. GREEN: multiply by `rate_persec`. (3,4 may fold into 2; split for strict RED-first.)

### Phase C — apply to rendering
5. **Xlib flat-dash path scrolls.** RED: `cmp` two PNGs of a **0°** dashed marching net at
   forced times chosen so offset differs by ≈ `P/2` (avoid period-aliasing) → identical
   today. GREEN: thread offset into `draw_hilight_wire` → `XSetDashes(…, offset, …)` (2nd
   arg, currently 0). Sabotage: force offset 0 ⇒ identical again.
6. **Cairo tilted-stripe path scrolls.** RED: same PNG-diff for an **angle>0** marching net
   → identical. GREEN: shift `cstart` by offset in `draw_hilight_wire_striped`.
7. **Offset gated to animation frames.** RED: two *ordinary* hardcopy PNGs at different
   wall-clock moments must be identical (deterministic export); unconditional offset makes
   them differ. GREEN: compute offset only when `anim_on`, else 0. Verify export identical +
   live frames differ.

### Phase D — the tick
8. **Redraw every moved frame.** RED: two `redraw_hilight_region` at forced times Δ apart
   (≥1px move) → second returns `2` (sig ignores offset). GREEN: fold `(int)offset` per
   marching style into the change-detection signature ⇒ `1`. Sabotage: sub-pixel Δ ⇒ still
   `2` (slow marching costs nothing).
9. **Frame-cadence delay.** RED: `redraw_hilight_region` next_ms for a marching net → `250`
   (blink cap); want ~`33` (≈30fps). GREEN: a marching style's "next change" = `FRAME_MS`
   in the next-edge min. Verify via the live `vwait` harness (~30 fires/s; pure-blink
   unchanged).

### Phase E — compose & finish
10. **Blink + march compose.** Verify (guard): a `blink_ms>0, march_fwd` style is **absent**
    at a forced OFF time, **present + scrolled** at an ON time.
11. **Docs (not RED).** Flip `anim`/`rate_persec` to live in the spec table +
    `net_hilight_style_rc` example + xschemrc; optional tutorial addendum. Then
    `/code-review high` (as for 2a).

**Watch-items.** Period-aliasing in the step-5/6 PNG-diff (pick Δ so offset≈P/2); the offset
must reduce mod P with a correct sign for `march_rev` (negative → add P); `dir`/`rate` read
from the compiled `NetHilightStyle`, not re-parsed; offset is wire-only (symbols colored,
never marched — same scope as width/dash/angle, spec §9).

---

## Risks / watch-items
- **Decoupling regressions**: defaults must reproduce current cycling exactly; guard with
  regression + sabotage check.
- **Stripe-angle complexity**: the one item that can balloon; keep it last and behind
  `HAS_CAIRO`.
- **GC lifecycle / per-window**: build and free the style GC pool per `xctx`; rebuild on
  theme change and on `update_net_hilight_style`.
- **Digit-key override**: confirm registry binding preempts the legacy `'0'` pin-logic
  handler under `cadence_style_rc`.
- **Memory**: use `my_malloc`/`my_strdup` (`_ALLOC_ID_`) for the style array and dash
  strings.

## Decisions (LOCKED 2026-06-23)
1. Command name: **`update_net_hilight_style`**.
2. Multi-net noun-verb: **per-net cursor advance** (N nets -> N successive styles).
3. Stripe-angle: **Pass 1.5** — Pass 1 is Phases 1-4 (color+width+dash+0° barcode);
   column/clamp/warning still implemented in Phase 3.
