# Plan — Buried-Net Highlight Indicator (RED-first)

Spec: `doc/claude/specs/buried_net_hilight.md`. Each slice is atomic: write the
failing check first (RED), make it pass with the smallest change (GREEN), tidy
(REFACTOR), keep the suite green before the next slice.

Code anchors (verified this session):
- `xInstance` struct — `src/xschem.h:637`. Add field near `int color;` (`:655`).
- `propagate_hilights(int set,int clear,int mode)` — `src/hilight.c:1756`. Recompute
  hook; runs on every highlight change + descend (`actions.c:2715`) + ascend
  (`actions.c:2834`).
- `clear_all_hilights()` — `src/hilight.c:871`.
- `get_hilight_style(int value)` — `src/hilight.c:626` → `&net_hilight_style[value % n]`.
- `draw_hilight_net(int on_window)` — `src/hilight.c:3000`. Animated draw pass.
- `draw_hilight_wire(fg, NetHilightStyle*, dash_offset, …)` — `src/draw.c:1592`
  (model for a rect helper).
- Blink gate `net_hilight_style_on_now()` `hilight.c:2574`; march
  `net_hilight_march_offset()` `hilight.c:2666`; `in_hilight_anim_frame` flag.
- `hilight` scheduler subcommands cluster — `src/scheduler.c:2835+` and `:8288+`.
- Path format: root `"."` (`xinit.c:677`), descend appends `instname` + `"."`
  (`actions.c:2693-2696`) → `".x_b.x_c."`.
- Instance screen bbox `inst[i].xx1/yy1/xx2/yy2` set in `draw_symbol()` `draw.c:676`.

Per-instance recompute lives in `propagate_hilights()`; per-frame draw only reads
`inst[i].buried_hilight`. Detection is NEVER run per animation frame.

---

## Slice 1 — Observation seam + RED test  (field + stub query + fixture)

Goal: a clean RED — the test runs, calls a real (stubbed) query, and fails on the
assertion (gets `-1` where it expects a style index).

GREEN-of-the-seam (not the feature):
1. `src/xschem.h`: add `int buried_hilight;` to `xInstance` (comment: "style index of
   a highlighted net buried in this instance's subtree, -1 = none; derived state").
2. Initialise to `-1` wherever an instance is created/cleared — `store.c`
   (`inst_register` / the store path that stamps `id`) and any `inst` zeroing in
   `xinit.c` / paste / copy. Grep `\.color\s*=\s*-10000` and `inst\[.*\]\.color`
   to find the parallel sites; mirror them.
3. `src/scheduler.c`: add subcommand `hilight_buried <instname>` near the other
   `hilight_*` branches (`:2835`). Resolve instance by name (reuse the lookup used by
   `hilight_instname`, `inst_hilight_hash_lookup` / `get_instance_by_name`), set the
   Tcl result to `inst[i].buried_hilight` (or `-1` if not found). **No detection yet —
   the field is still always `-1`.**
4. Build. `cd src && make`.

RED test — `tests/buried_hilight.tcl` (+ fixture, see Slice 1a):
- Load fixture top (cell A). Descend `x_b`→`x_c`→`x_d` (use `xschem descend` /
  `descend_schematic`, mirror how `tests/open_close*` or `hi_descend` tests drive it).
- `xschem hilight_netname <internal_net_of_D>` (a net with no pin connection).
- Ascend once (`xschem go_back`). Assert `xschem hilight_buried x_d` == the style index
  (initially `0` for the first style; query `xschem hilight_netname`'s assigned style or
  read it back). **This assertion FAILS (gets -1).** ← RED confirmed.

Run: `cd tests && tclsh run_regression.tcl` (or source `buried_hilight.tcl`); confirm
the new case reports FAIL on the buried assertion, everything else green.

### Slice 1a — Fixture: 3-level hierarchy with a buried net
Minimal symbol+schematic set under `tests/` (or reuse `xschem_library` devices):
- Cell **D** (`d.sch` + `d.sym`): contains a wire/net `buried_d` connected only to
  internal devices (e.g. two `devices/res.sym`) — crucially **not** routed to any pin
  of `d.sym`. Give `d.sym` at least one real pin wired to a *different* net so it is a
  normal subcircuit.
- Cell **C** (`c.sch`): instantiates `d.sym` as `x_d`. Cell **B** (`b.sch`):
  instantiates `c.sym`/`c.sch` as `x_c`. Cell **A** (`a.sch`): instantiates `x_b`.
- Keep it the smallest thing that netlists cleanly (run `xschem netlist` once to be
  sure). Store under `tests/buried_hilight/` to avoid polluting the library.

DoD: test file exists, runs headless, FAILS only on the buried assertion (RED).

---

## Slice 2 — Detection (GREEN core)

Make the inheritance assertions pass. In `propagate_hilights()` (`hilight.c:1756`),
after the existing instance loop:

1. Reset: loop instances, `inst[i].buried_hilight = -1`.
2. One pass over `xctx->hilight_table[HASHSIZE]`. With `P = xctx->sch_path[currsch]`,
   `lp = strlen(P)`: for each entry, if `strlen(entry->path) > lp` and
   `strncmp(entry->path, P, lp)==0`, take the child component `c` = chars of
   `entry->path` from `lp` up to the next `.`. Accumulate `c → min(style)` in a small
   temporary map (use a `Str_hashtable` if one exists, else a short dynamic list — the
   set of distinct child names at one level is tiny).
3. Assign: loop instances; for each whose `instname` matches a collected `c`
   (base-name match: compare up to `[` for vector instances, §8.4 of spec) **and**
   whose `inst[i].color < 0` (not pin-highlighted), set
   `inst[i].buried_hilight = child_style[c]`.

Gate the whole block on `set` (don't recompute on the pure-clear path; clear is handled
in Slice 3). Free the temporary map.

Run: Slice 1 inheritance assertions for `x_d` (at C), `x_c` (at B), `x_b` (at A) now
pass. Add the **pin-reaching** negative assertion (acceptance #4): a net wired to a pin
colors the instance and yields `hilight_buried == -1` at that level.

DoD: detection assertions GREEN; full suite green.

---

## Slice 3 — Clear semantics

1. `clear_all_hilights()` (`hilight.c:871`): after emptying the table, loop instances
   and set `buried_hilight = -1` (belt-and-suspenders for paths that don't re-run
   propagate). 
2. Confirm the descend-then-unhighlight-specific-net path also drops the cue (it
   should, via recompute). Add assertion.

Test additions in `buried_hilight.tcl`:
- After the inheritance asserts, `xschem unhilight_all`; assert `hilight_buried x_b/x_c`
  == `-1` (acceptance #5).

DoD: clear assertions GREEN; suite green.

---

## Slice 4 — Draw the indicator rectangle (visual)

In `draw_hilight_net()` (`hilight.c:3000`), after the existing highlighted-wire /
instance-color drawing:

1. Loop instances with `buried_hilight >= 0`.
2. `st = get_hilight_style(inst[i].buried_hilight)`.
3. Blink gate: if animating and `!net_hilight_style_on_now(st, now)`, skip.
4. March: `dash_offset = net_hilight_march_offset(st, now)` (0 on ordinary/hardcopy).
5. Draw a rectangle on `inst[i].xx1,yy1,xx2,yy2` using `st`'s color/width/dash. Add a
   small helper `draw_hilight_rect(fg, st, dash_offset, x1,y1,x2,y2, on_window)`
   modeled on `draw_hilight_wire()` (`draw.c:1592`) — four styled segments or an
   `XDrawRectangle` with `XSetDashes` phase = `dash_offset`. Optionally inset by a
   couple of px so it doesn't sit exactly on the symbol outline.

Headless: add a smoke assertion (draw without crash; `xschem get drawcount` advances on
redraw). **Visual correctness is verified manually** (see Slice 5 checklist) — note this
explicitly in the test; do not pretend the suite proves the pixels.

DoD: builds, suite green, no crash on the animated path; manual GUI shows the box.

---

## Slice 5 — Animation parity, multi-window, acceptance & docs

1. Verify the cue blinks/marches in phase with the buried net (same `now`, same gates).
   Cross-check with an already-animated style from `cadence_style_rc`.
2. Verify multi-window: open a detached window on the same design; both compute their
   own `buried_hilight` from their own `currsch`; the multi-window tick redraws both.
3. Manual GUI checklist (record results in the test header / a session note):
   - descend→highlight buried→ascend: ancestor box appears, correct style;
   - climb full chain A↔D: box tracks the right instance at each level;
   - pin-reaching net: instance colored, no redundant box;
   - `unhilight_all`: all boxes gone;
   - animated style: box blinks/marches in phase;
   - export (SVG/PS): deterministic (offset 0, blink on).
4. Update memory: new `buried-net-hilight.md` + MEMORY.md line; link from
   [[net-hilight-styles]]. Mark spec acceptance boxes.
5. Run full `tclsh run_regression.tcl`; confirm green.

DoD: all acceptance criteria (spec §11) met; suite green; docs/memory updated.

---

## Risks / watch-items
- **Init coverage.** Miss an `inst` allocation site and `buried_hilight` is garbage →
  spurious boxes. Grep every `xInstance` zeroing/clone site (store/paste/copy/undo
  restore). A `my_calloc` path is safe; a `my_malloc`+field-set path is not.
- **Path-format off-by-one.** Leading+trailing dots: `P` already ends in `.`; the child
  component is `entry->path[lp..next-dot)`. Unit-check with a `dbg(1,...)` first.
- **`inst[i].color` sentinel.** "Not pin-highlighted" = `color < 0` (the `-10000`
  sentinel). Confirm no code leaves `color` at a stale `>=0` after unhighlight on the
  path the test exercises (propagate's `clear` arm sets `-10000`).
- **Don't recompute per frame.** Detection only in `propagate_hilights`/`clear`. The
  draw pass must only *read* the field.
- **Green-but-hollow.** Drawing is not asserted by the suite; the manual checklist is
  load-bearing. See [[green-but-hollow]].
