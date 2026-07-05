# Plan — Multi-window net-highlight animation (blink + marching ants)

Status: PLANNED (2026-06-25), after net-highlight Pass 1/1.5/2a/2b all shipped on
`fluid-editing` (single-window animation works; HEAD `c2162eeb`). Goal: let blink AND
marching highlights animate in **every visible window simultaneously**, not just the front one.
See FAQ Q20 (`doc/claude/FAQ.md`) for the architectural summary and `doc/claude/specs/net_hilight_styles.md`
/ `doc/claude/specs/multi_window_detach.md` for context.

Guiding principle: this is **not a new subsystem** — the per-window contexts (`save_xctx[]`) and a
per-window Tcl tick (`net_hilight_after` array, keyed by window path) already exist. The whole job
is **lifting the "global front `xctx`" assumption** out of the four animation entry points, behind a
single audited **context-borrow** primitive, gated on visibility and serialized. Land the borrow
primitive first (read-only, lowest risk), then the query, then the draw (the one real risk), then
arm-all + visibility, then serialize + verify.

Each step is a RED test (fails today) → minimal GREEN → a sabotage check, exactly like the Pass 2b
plan. Multi-window is harder to unit-test than the offset math, but the key behaviors ARE assertable
headlessly via a new per-window query arg (the test seam below) plus per-window PNG byte-diffs
(`cmp`, already proven by 2a/2b).

---

## Why it's front-only today (the three bake-ins)
1. `net_hilight_anim_update()` (`hilight.c`) arms the tick only for `xctx->current_win_path`.
2. `net_hilight_has_animation()` / `scan_animating_hilights()` / `draw_hilight_region()` read the
   **global** `xctx`.
3. `xschem redraw_hilight_region <win>` (`scheduler.c`) returns `0` (stop) when
   `win != xctx->current_win_path`, so a background window's tick self-cancels.

Already multi-window-ready: the Tcl tick (`net_hilight_anim_tick {win}` / `net_hilight_anim_update
{win}` in `xschem.tcl`) is per-window; N concurrent self-rescheduling `after` chains already work.

## The key new test seam
`xschem get net_hilight_animated <win>` and `xschem redraw_hilight_region <win>` must evaluate
**window `<win>`'s context**, not the global front one. Once the query takes `<win>` and answers
about that window, every phase below is assertable from a headless/script `--script` run that opens
two windows, highlights an animating net in the **non-front** one, and asserts on `<win>`.

## Scope decision (LOCKED)
This is a **detached-windows** feature. Background **tabs share one canvas and are not mapped**, so
animating a hidden tab is invisible and would scribble an unmapped surface. Only windows whose canvas
is `winfo viewable` animate; background tabs stay static (already correct). So "multi-window
animation" == "every *visible* top-level (`.drw`, `.x1.drw`, `.x2.drw`, …) animates."

## Shared test harness (used by every phase)
```tcl
# open a 2nd detached window with a different schematic, highlight an animating net in it,
# return focus to the first. The non-front window is the unit under test.
xschem load A.sch                                  ;# front = .drw
xschem new_schematic create_window B.sch           ;# detached -> .x1.drw
# operate on .x1.drw's context via the existing (heavyweight) switch for SETUP only:
#   select a net there, install a blinking style, hilight it
# then switch focus back to .drw so .x1.drw is the NON-front window.
```
(Confirm the exact `new_schematic` subcommand + how setup switches contexts during the spike.)

---

## Phase A — the context-borrow primitive (read-only; lowest risk)

A1. **Map a window path to its context.** RED: a unit that, given `.x1.drw`, finds `save_xctx[n]`.
GREEN: reuse `get_tab_or_window_number(win_path)` (`xinit.c:1395`) + `get_save_xctx()`; handle the
"single schematic not yet in save_xctx → it's the live `xctx`" caveat (see `xinit.c:1408`,
`get_window_count()==0`). Sabotage: an unknown win path → returns -1, borrow is a safe no-op.

A2. **`with_net_hilight_ctx(win, &saved)` borrow + restore.** A C helper that points global `xctx`
at `save_xctx[n]` and returns the previous `xctx` (NULL if win is already current / not found →
caller skips switching). A matching restore. NO drawing, NO GUI side effects (unlike
`switch_window()`, `xinit.c:1579`, which raises/focuses/sets title). RED: a probe subcommand
`xschem get schname <win>` (or similar context-specific read) returns the FRONT window's value for a
background win. GREEN: it returns the background window's value, and the global `xctx` is byte-identical
before vs after (restore is exact). Sabotage: force the restore off → a follow-up front-window query
returns the wrong window's value (proves the restore is load-bearing).

A3. **Borrow audit (the de-risking step, no new behavior).** Enumerate every global the draw path
reads that is NOT inside `Xschem_ctx`: `display` (shared, fine), the `bbox()` machinery state,
`set_clip_mask` statics, cairo globals, `rstate`/areax. Document which are xctx-relative (safe) vs
truly global (must be saved/restored or are read-only). Output: a short audit note appended to this
plan. This gates Phase C.

---

## Phase B — context-aware animation query

B1. **`xschem get net_hilight_animated <win>`.** RED: with an animating net highlighted in the
**non-front** window, `xschem get net_hilight_animated .x1.drw` → returns the front window's answer
(today: ignores the arg, reads global `xctx`). GREEN: borrow `<win>` (Phase A), call
`net_hilight_has_animation()` against it, restore; with no arg keep the current (front) behavior.
Sub-RED: the front window's own `net_hilight_animated` is unchanged. Sabotage: highlight nothing in
`.x1.drw` → returns 0.

B2. **`net_hilight_has_animation()` reads the (now possibly-borrowed) `xctx` correctly.** No change
expected (it already reads the global `xctx`, which the borrow has repointed) — assert it via B1.
Confirm the busy/animate-enabled guards still apply per-borrowed-context.

---

## Phase C — context-aware regional redraw (the one real risk)

C1. **`xschem redraw_hilight_region <win>` draws window `<win>`, not the front.** RED: two PNGs of
the **background** window at forced animation times (blink ON vs OFF, via `net_hilight_test_now`) →
identical today (the command returns 0 / no-ops for a non-front win). GREEN: borrow `<win>`, run
`draw_hilight_region(&next)` (it draws into that context's pixmap + canvas via `bbox(...)`/`draw()`),
restore; remove the `win != current_win_path → return 0` bail. PNGs now differ. Sabotage: skip the
borrow (draw with the front context) → the background window's PNG is unchanged AND the FRONT
window's pixmap gets corrupted (proves the borrow targets the right surface).

C2. **The front window keeps animating correctly while a background window also animates.** RED/guard:
PNG the front window across its own blink edge while `.x1.drw` is also ticking → front still toggles,
and `.x1.drw`'s redraw did not touch the front's pixmap (front PNG identical at equal forced times
regardless of background activity). This is the cross-talk check the borrow must satisfy.

C3. **Tabs stay front-only.** Guard: a background *tab* (not a detached window) does NOT animate
(its canvas is not `winfo viewable`); only the front tab does. Verify no redraw is issued to an
unmapped tab surface.

---

## Phase D — arm every animating window + visibility gate

D1. **`net_hilight_anim_update` arms all windows, not just the front.** RED: highlight an animating
net in `.x1.drw` (non-front); today no `net_hilight_after(.x1.drw)` timer is registered. GREEN:
iterate `save_xctx[]`, and for each window with animation arm its tick (the Tcl
`net_hilight_anim_update {win}` already exists per win). Sabotage: `unhilight_all` in `.x1.drw` →
its timer cancels; the front's is untouched.

D2. **Visibility gate.** RED: a background detached window that is *iconified/withdrawn* still ticks.
GREEN: the tick (or `net_hilight_animated <win>`) returns 0 / stops when the window's canvas is not
`winfo viewable`. Sabotage: de-iconify → it resumes.

---

## Phase E — serialization, reentrancy, finish

E1. **Borrows never overlap a gesture.** Guard: globalize the `semaphore` / `HILIGHT_ANIM_BUSY`
check so NO window animates a frame while the user is mid-drag/-wire/-move in ANY window (a borrow
mid-gesture would corrupt the gesturing context). Verify a background tick returns "busy, keep
ticking" (tri-state 2) during a front-window gesture, then resumes.

E2. **No nested borrows / one at a time.** The borrow asserts it is not already borrowed (or is
re-entrant-safe). Verify two windows' ticks interleave without leaving `xctx` mis-pointed.

E3. **Live multi-window verification.** Two detached windows, each highlighting a blinking + a
marching net; `vwait` harness confirms BOTH tick (~blink edges / ~30fps marching) simultaneously,
each redraws only its own region, neither leaks into the other, CPU bounded, both stop on
`unhilight_all`. Then `/code-review high`.

E4. **Docs.** Update FAQ Q20 ("now: all visible windows animate"), `doc/claude/specs/net_hilight_styles.md`
(drop the "front window only" note), and `doc/claude/specs/multi_window_detach.md` (the borrow primitive is
reusable for other background-window redraws).

---

## Watch-items / risks
- **The borrow audit (A3) is the whole risk.** If a draw-path global outside `Xschem_ctx` is missed,
  a background redraw corrupts the front window or vice-versa. Front↔background PNG cross-talk checks
  (C2) are the safety net — make them strict (byte-identical front frames regardless of background
  activity).
- **`switch_window()` is the wrong tool** — it raises/focuses/retitles. The borrow must be the
  minimal pointer swap + nothing else; resist reusing the heavyweight switch.
- **Front-context special case**: with a single schematic the front context is the live `xctx`, not
  `save_xctx[0]` (`xinit.c:1408`). The win→ctx map (A1) must return the live `xctx` for the front.
- **Cost**: N visible windows × cadence × regional redraw. Each frame is regional (small); bounded.
  The adaptive marching cadence (1000/(rate·P) ms) and blink edge-seeking already minimize wakeups.
- **GC/colormap**: `gc[]` and `gc_hilight` are per-`xctx` (`xschem.h:1067,1078`) — the borrow gets the
  right GCs. `display` is shared (read-only). Confirm no per-draw reconfiguration of a *shared* GC
  races between windows (serialization E1 covers this).
- **Reentrancy with the Tcl event loop**: the per-window `after` ticks fire on the Tk loop; a borrow
  must complete synchronously within one tick callback (no `vwait`/`update` inside a borrow).

## Decisions (LOCKED 2026-06-25)
1. Scope = **visible top-level windows** only; background tabs stay front-only (by design).
2. The borrow is a **new minimal primitive**, NOT `switch_window()`.
3. Land **read-only borrow (query) before draw borrow**; the A3 audit gates the draw phase.
4. Test seam = **`<win>` arg on `get net_hilight_animated` + `redraw_hilight_region`** + per-window
   PNG `cmp`.

---

## Phase A — STATUS: DONE (2026-06-25, HEAD after `714ce42d`)

A1+A2 implemented and verified RED→GREEN→sabotage; A3 audit below. Single commit on `fluid-editing`.

### What landed
- **`net_hilight_borrow_ctx(const char *win_path)` / `net_hilight_restore_ctx(Xschem_ctx *saved)`**
  (`hilight.c`, prototypes in `xschem.h`). The borrow maps `win_path` → context via
  `get_tab_or_window_number()` + `get_save_xctx()`, honoring the single-schematic caveat
  (`get_window_count()==0 && n==0` → the live `xctx`, not `save_xctx[0]`), repoints the global
  `xctx`, and returns the previous one. Returns **NULL = no borrow** (unknown/empty win, or already
  current); restore of a NULL is a no-op, so the pair is always balanced. **No** GUI side effects —
  no raise/focus/title, no Tcl `save_ctx`/`restore_ctx`, no layer-button reconfigure (explicitly
  NOT `switch_window()`).
- **Probe wiring:** `xschem get current_name <win>` now borrows `<win>`, reads `xctx->current_name`
  (copied via `TCL_VOLATILE` before restore), restores. No-arg form unchanged. This is the A2 test
  seam; the real feature wiring (`net_hilight_animated <win>`, `redraw_hilight_region <win>`) is
  Phase B/C.

### Verification (`scratchpad/phaseA_borrow_test.tcl`, `DISPLAY=:0`)
Two detached windows (`.drw`=LM5134A, `.x1.drw`=LCC_instances), focus returned to `.drw`:
- **RED** (pre-change binary): `get current_name .x1.drw` → `LM5134A.sch` (arg ignored). 1 FAIL.
- **GREEN**: → `LCC_instances.sch`; front no-arg/own-path reads unchanged; `current_win_path`
  identical before/after the borrow (restore exact); unknown win path falls back to front. ALL PASS.
- **Sabotage** (restore body `#if`'d out): after the borrowed read the global `xctx` leaks at
  `.x1.drw`, so the follow-up front no-arg reads return `.x1.drw`/`LCC_instances.sch` (2 FAIL) —
  proving the restore is load-bearing. Reverted; rebuilt GREEN.

### A3 — borrow audit of draw-path globals (gates Phase C)
Audited every global the regional-redraw path (`draw_hilight_region` → `bbox()` → `set_clip_mask()`
→ `draw()` → `drawline/filledrect/drawarc/...`) reads that is NOT inside `Xschem_ctx`:

| Draw-path state | Owner | xctx-relative? | Verdict under borrow |
|---|---|---|---|
| `bbox()` machinery (`bbx*`, `area*`, `savex*`, `xrect[0]`, `bbox_set`, `lw`, `mooz`) | all `xctx->…` (`select.c`) | YES | **SAFE** — per-context |
| `set_clip_mask()` (`gc[]`, `gcstipple[]`, `gctiled`, `gc_hilight`, `cairo_ctx`, `cairo_save_ctx`) | all `xctx->…` (`xinit.c:1139`) | YES | **SAFE** — per-context |
| cairo source/font (`set_cairo_color`, `set_text_custom_font`: `cairo_ctx`, `cairo_save_ctx`, `xcolor_array`, `cairo_font`) | all `xctx->…` (`draw.c`) | YES | **SAFE** — per-context |
| draw target (`window`, `save_pixmap`, `draw_window`, `draw_pixmap`, `gc[c]`) | all `xctx->…` (`draw.c:1362`) | YES | **SAFE** — per-context |
| `display`, `colormap`, `visual`, `screen_number/depth`, `cadlayers` | `globals.c`, init-once | global, read-only | **SAFE** — shared handle/constants |
| `pixmap[]`, `pixdata[]` (16×16 layer stipple bitmaps) | `globals.c`, set at init, bound into `gcstipple[]` | global, read-only during draw | **SAFE** — window-independent fill patterns |
| `cairo_font_scale`, `cairo_vert_correct`, `nocairo_vert_correct`, `text_svg/ps` | `globals.c`, config | global, read-only | **SAFE** — style constants |
| **static draw batch buffers** — `static int i; static XSegment/XArc/XRectangle r[CADDRAWBUFFERSIZE]` in `drawline`/`drawarc`/`filledrect`/`drawtemp*` (`draw.c`) | **draw.c file scope — ONE set shared by ALL contexts** | **NO — truly global** | **CONDITIONALLY SAFE** (see below) |
| `rstate` | `callback.c` event-handler **locals** | N/A | not a draw-path global — irrelevant to the borrow |

**The one truly-global draw state = the static batch buffers.** Each batched primitive function
accumulates segments/arcs/rects into a file-scope `r[]` (counter `i`) on `ADD` and flushes them to
**whatever `xctx` is current at flush time** (`xctx->window`/`save_pixmap`/`gc[c]`) on `END` (or when
the buffer fills). They are **empty between top-level `draw()` calls** — the existing single-window
regional redraw (`draw_hilight_region`) already relies on every `ADD` being matched by an `END`
flush within one synchronous `draw()`.

→ **Phase C/E constraint (gate satisfied):** a borrow is safe to draw **only** if it
(1) wraps a *complete* `draw()`/`draw_hilight_region()` call — never interrupts one mid-accumulation,
(2) is **non-reentrant** (no nested borrow), and
(3) does **no** `vwait`/`update` inside the borrow (which could let another draw start mid-buffer).
The per-window Tcl `after` ticks already fire between event-loop iterations (not mid-draw) and
`draw()` is synchronous, so these hold naturally — but Phase E (serialization E1/E2) must assert them
explicitly. No buffer save/restore is needed; serialization is sufficient. **A3 clears Phase C to
start**, with the cross-talk PNG checks (C2) as the safety net for the buffer invariant.

---

## Phase B — STATUS: DONE (2026-06-25)

B1+B2 implemented and verified RED→GREEN; single commit on `fluid-editing`.

### What landed
- **`xschem get net_hilight_animated <win>`** (`scheduler.c`): with an optional `<win>` arg the
  query borrows that window's context (Phase-A `net_hilight_borrow_ctx`), calls
  `net_hilight_has_animation()`, and restores — so a per-window tick for a NON-front window gets
  its own window's answer, not the front's. No-arg form is byte-unchanged (front/current behavior).
- **B2:** `net_hilight_has_animation()` needed **no change** — it already reads the global `xctx`,
  which the borrow has repointed. Its per-context guards (`hilight_nets`, `semaphore`,
  `ui_state & HILIGHT_ANIM_BUSY`, the `scan_animating_hilights` walk) now correctly evaluate the
  borrowed context; the only global guard is the `net_hilight_animate` kill-switch (intentionally
  global). Confirmed via the sabotage assertion below.

### Verification (`scratchpad/phaseB_animated_test.tcl`, `DISPLAY=:0`)
Two detached windows: front `.drw` (no highlights), background `.x1.drw` with a **blinking**
highlight (style `{idx magenta 2 {} 0 600 none 0}` applied via `net_hilight_apply` — NB the styledef
is a full 8-column row incl. a leading index placeholder; a 7-col row silently mis-maps `blink`).
Focus returned to `.drw`:
- **RED** (pre-wiring binary): `get net_hilight_animated .x1.drw` → `0` (arg ignored, reads front).
  Exactly one assertion fails; front behavior / restore / unknown-path / sabotage all already pass.
- **GREEN**: → `1` (borrows `.x1.drw`); front no-arg/`.drw` query stays `0`; `current_win_path`
  unchanged across the borrowed query; unknown win path → front answer (`0`). ALL PASS.
- **Sabotage (B1 + B2 guard):** `unhilight_all` in `.x1.drw` → its `hilight_nets` drops to 0 →
  `get net_hilight_animated .x1.drw` → `0`, proving the query tracks the *borrowed* context's live
  state, not a constant. Regression suite (create_save/open_close/netlisting) clean.

Next: Phase C (context-aware regional redraw — the one real draw risk; gated A3-clear).

---

## Phase C — STATUS: DONE (2026-06-25)

C1+C2 implemented and verified RED→GREEN→sabotage. The A3 audit's draw-batch-buffer invariant
held in practice (front PNG byte-identical across a background redraw). Single commit.

### What landed
- **`xschem redraw_hilight_region <win>`** (`scheduler.c`): with the optional `<win>` arg the
  command borrows that window's context (Phase A) and runs `draw_hilight_region(&next)` against
  it — which draws into THAT window's own `save_pixmap` + canvas via `bbox()`/`draw()` — then
  restores. The old `win != current_win_path → r=0` bail is gone. An explicit unknown/stale
  `<win>` (unborrowable, non-current) returns `0` (stop the tick), matching the Phase B contract.
  The borrow wraps a complete, synchronous, non-reentrant `draw_hilight_region()` with no
  `vwait`/`update` inside — exactly the condition the A3 audit requires for the file-scope draw
  batch buffers (`draw.c`) to stay safe under a context swap.
- **Two borrow-based test seams** (both `TEST HOOK … never used in production`, siblings of
  `net_hilight_test_now`): `net_hilight_test_now <ms> [<win>]` now sets the per-`xctx` forced
  blink/march time on `<win>`'s context (so a background frame can be driven from the front);
  and new `net_hilight_dump_pixmap <file> [<win>]` writes a window's **live** `save_pixmap` to a
  PNG **without re-rendering** — unlike `print png`, which calls `draw()` and captures steady
  highlights, this captures exactly the animation phase a preceding `redraw_hilight_region`
  painted, so per-window frames are byte-comparable and cross-talk is detectable.

### Verification (`scratchpad/phaseC_redraw_test.tcl`, `DISPLAY=:0`)
Front `.drw` (cmos_inv) and background `.x1.drw` (LCC_instances), each with a blinking highlight,
focus on the front. Live `save_pixmap` PNGs via `net_hilight_dump_pixmap`, forced per-window time
via `net_hilight_test_now <ms> <win>`, byte-compared with `cmp`:
- **C1** — redraw `.x1.drw` at blink ON (`t=0`) vs OFF (`t=300`): its pixmap **differs** (it drew
  into the background surface). RED (old bail) → command returns `0 50`, pixmap unchanged →
  identical (C1 fails, exactly one assertion). GREEN → returns `1 …`, pixmaps differ.
- **C2 cross-talk** — capture the front at `t=0` (ON); arm the front to `t=300` (OFF) **without
  redrawing it**; redraw `.x1.drw`; re-capture the front: byte-**identical** (the background
  redraw did not touch the front surface). Front still toggles on its own edge.
- **Sabotage** (skip the borrow → draw the front context): C1 fails (background unchanged), C2
  cross-talk fails (front flips to OFF — corrupted), and the unknown-`<win>` guard fails (drew
  instead of stopping) — three failures, proving the borrow both runs AND targets the right
  surface. Reverted; GREEN restored; regression (create_save/open_close/netlisting) clean.

### Scope note (C3 deferred to Phase D)
This is the **detached-windows** feature (LOCKED). `redraw_hilight_region <win>` will draw
whatever window it is told; the decision **not** to tick a non-viewable background *tab*
(tabs share the main canvas) is the `winfo viewable` visibility gate in **Phase D**, verified
there. Phase C tested detached windows only.

Next: Phase D (arm every animating window from C + the visibility gate).

---

## Phase D — STATUS: DONE (2026-06-25)

D1+D2 implemented and verified RED→GREEN→sabotage. D2's `winfo viewable` gate also closes C3
(background tabs). Single commit.

### What landed
- **D1 — `net_hilight_anim_update()` (C, `hilight.c`) arms EVERY open window**, not just the
  front. It now iterates the open windows (mirroring `xschem windows`: `save_xctx[]`, with the
  sole-schematic caveat → the live `xctx`) and calls the per-window Tcl `net_hilight_anim_update
  {win}` for each. That proc forwards `<win>` to `get net_hilight_animated` (Phase B), which
  borrows the window's context, so each window arms/cancels on its **own** animation state. The
  borrow restores `xctx` before returning, so the C loop's `xctx` stays stable across iterations.
- **D2 — visibility gate** (`xschem.tcl`): both `net_hilight_anim_update {win}` (arm) and
  `net_hilight_anim_tick {win}` (run) now `return` early when `![winfo viewable $win]`. A
  withdrawn/iconified detached window stops; **and a background tab — whose shared canvas is
  unmapped — is not viewable, so it stays front-only (closes C3)** with no tab-specific code.

### Verification (`scratchpad/phaseD_arm_test.tcl`, `DISPLAY=:0`)
Two detached windows (front `.drw` cmos_inv, background `.x1.drw` LCC_instances), each with a
blinking highlight; assertions on the per-window `net_hilight_after(<win>)` timer registration
(no event loop needed — `clear_timers` after any `update` drops self-rescheduled Phase-C ticks so
the checks isolate the arm DECISION):
- **D1** — RED (front-only): a global `net_hilight_anim_update()` arms `.drw` only; `.x1.drw` gets
  no timer (1 fail). GREEN: both armed. Sabotage: `unhilight_all` in `.x1.drw` → its timer cancels,
  `.drw` untouched.
- **D2** — RED (D1 landed, no gate): a **withdrawn** `.x1.drw` is still armed (1 fail). GREEN
  (`winfo viewable` gate): withdrawn `.x1.drw` not armed, `.drw` still armed. Sabotage:
  `wm deiconify` → `.x1.drw` arms again.
Phase B/C tests still green; regression (create_save/open_close/netlisting) clean.

Next: Phase E (serialization E1/E2 — never borrow mid-gesture, non-reentrant — + live multi-window
`vwait` verification E3 + docs E4).

---

## Phase E — STATUS: DONE (2026-06-25) — FEATURE COMPLETE

E1–E4 implemented/verified; the feature is complete and the docs reflect it.

- **E1 — never animate mid-gesture.** New `net_hilight_ctx_busy()` (`hilight.c`; single source
  of truth for the `HILIGHT_ANIM_BUSY` gesture mask + `semaphore`). `redraw_hilight_region`
  checks it on the **pre-borrow (front)** context: if the focused window is mid-gesture, no
  window draws a frame (a borrow would swap `xctx` out from under the in-flight gesture / shared
  draw buffers) — returns 2 (busy), resumes when the gesture ends. RED→GREEN: with a `wire gui`
  gesture active on the front, a background redraw returned 1 (drew) before, 2 (busy) after, then
  drew the pending edge on `abort_operation` (`scratchpad/phaseE1_gesture_test.tcl`).
- **E2 — re-entrant-safe borrow.** Documented on `net_hilight_borrow_ctx`: balanced borrow/restore
  stack, restored synchronously within one command/tick (no `vwait`/`update` between), single-
  threaded Tcl loop runs each tick to completion → ticks never interleave mid-borrow. Guard test:
  a mixed sequence of query/redraw/test_now/dump on two windows leaves `current_win_path` +
  `current_name` the front's after every op (`phaseE2_interleave_test.tcl`).
- **E3 — live verification.** `vwait` pumps the real event loop: both detached windows tick ~10×
  each in 1.3 s simultaneously on wall-clock, rate bounded (edge-seeking, not a 20/s spin), both
  stop on `unhilight_all` (`phaseE3_live_test.tcl`). Would fail pre-Phase-D (bg never ticks).
- **E4 — docs.** FAQ Q20 marked DONE with the shipped mechanism; `doc/claude/specs/net_hilight_styles.md`
  gained a "Pass 2-multiwin — DONE" bullet (front-only note dropped); `doc/claude/specs/multi_window_detach.md`
  documents the borrow primitive as a reusable building block for any background-window redraw.

Commits: A `00ed9ebd`/`c85b4751` · B `4115a27d`/`fd12f072` · C `87a36b86`/`2b7cf900` ·
D `4ab92062`/`03597562` · E `38bf4ea4` (+docs). Issues logged for deferred cleanups: 0030
(dash-period recompute), 0031 (per-window style-table staleness), 0032 (fan-out cost).
