# Overnight batch 2026-08-01, item 01 — `m`/`d` place a marker ANYWHERE in the plot box

**Verdict: PROCEED.** Scout stage, 2026-08-01. Every anchor below was re-read
from source today and every behavioural claim was **measured** on the shipping
build (`XSCHEM V3.4.8RC`, HEAD `e516cc85`), not inferred.

**Status: IMPLEMENTED (2026-08-01), committed on `fluid-editing`.** Issue
`doc/claude/issues/0188-marker-create-gate-is-proximity-not-plot-box.md`.
Code: `src/draw.c` (`graph_marker_create` — the plot-box gate + `1e30`) and
`src/xschem.h` (`GRAPH_MARKER_PICK_TOL` deleted). Suite:
`tests/headless/test_wave_markers.tcl` — new `MP0`–`MP15` engine group (BOTH
arms), `MP20`–`MP22` display legs (including the diamond equality),
`mx_empty_row` tightened with `wviewer::plotbox_at`, new `mx_margin_row`, `MX4`
inverted and `MX4b` added. Counts went 328 → **373** (`--nogui`) and 803 → **870**
(DISPLAY), both `ALL PASS`. All three named sabotages verified in both arms; two
deviations from the prompt's kill lists, both recorded in §8 below.
No `callback.c`, `wave_viewer.tcl` or `scheduler.c` change was needed, as §6.4
predicted.

---

## 1. The user's spec, verbatim

> Currently, to select a trace, the mouse pointer needs to be reasonably close to
> the trace - proximity. Good. However, this is not needed for adding a marker.
> Adding a marker is done by pressing "m" key - clear intention. Therefore, if the
> mouse is within the plot area of a strip, and user presses "m" key, add a marker
> at the point that the diamond cursor has snapped to

Two halves, and only one of them is a change:

* **trace SELECTION keeps its proximity** — `GRAPH_TRACE_PICK_TOL` (10 screen px,
  `src/xschem.h:418`), shared by four picking surfaces. This item must not touch
  it, and the suite gets a regression witness that it did not.
* **marker CREATION loses its proximity** — it becomes a plot-box test, and the
  sample it picks becomes exactly the one the item-9 diamond is already sitting on.

---

## 2. What exists today (verified 2026-08-01)

### 2.1 The creation path — three call sites, one primitive

| anchor | what it is |
|---|---|
| `src/callback.c:1514` | `else if((key == 'm') && access_cond)` → `graph_marker_create(i, X_TO_SCREEN(xctx->mousex), Y_TO_SCREEN(xctx->mousey), 0)` |
| `src/callback.c:1518` | the same for `'d'` with `delta = 1` |
| `src/scheduler.c:5146` | `xschem graph_marker add <gi> <px> <py> [-delta]` → the same function |
| `src/draw.c:6357` | **`graph_marker_create()`** — the single gate all three go through |
| `src/draw.c:6313` | `graph_marker_add_record()` — the shared tail: `push_undo` + `graph_markers_store` + `set_modify(1)` + `graph_marker_notify()` + `log_action("xschem graph_marker add_at …")` |

`graph_marker_create()` today, in full:

```c
  memset(&gr_ctx, 0, sizeof(gr_ctx));
  saveflags = xctx->graph_flags & (128 | 256);   /* landmine 37, as above */
  setup_graph_data(i, 1, gr);
  xctx->graph_flags = (xctx->graph_flags & ~(128 | 256)) | saveflags;
  if(gr->digital) {
    graph_marker_refuse("xschem: markers are not supported on digital strips");
    return 0;
  }
  if(!graph_point_at(i, px, py, GRAPH_MARKER_PICK_TOL, -1, -1, &hit)) {   /* :6375 */
    graph_marker_refuse("xschem: no trace near the pointer");
    return 0;
  }
  return graph_marker_add_record(i, hit.wave, hit.dataset, hit.point, hit.x, hit.y, delta);
```

`GRAPH_MARKER_PICK_TOL` is `20.0` (`src/xschem.h:443`) and **`draw.c:6375` is its
only use in the whole tree** (grep: `src/xschem.h`, `src/draw.c`, plus two prose
mentions in `doc/claude/specs/graph_markers.md` and two comments in
`tests/headless/test_wave_markers.tcl`). It is **not** mirrored in Tcl.

### 2.2 The diamond, which already does exactly what the user is asking for

`draw_graph_snap_cursor()` (`src/draw.c:5141`) is viewer-plan item 9. Its pick
loop, `src/draw.c:5180-5187`:

```c
  for(i = 0; i < xctx->rects[GRIDLAYER]; ++i) {
    GraphPointHit h;
    if(!(xctx->rect[GRIDLAYER][i].flags & 1)) continue;   /* not a graph */
    if(!graph_plotbox_at(i, (double)mx, (double)my)) continue;
    if(graph_point_at(i, (double)mx, (double)my, 1e30, -1, -1, &h)) {
      if(!found || h.dist < hit.dist) { hit = h; found = 1; gi = i; }
    }
  }
```

with the comment at `:5172-5179` — *"THE GATE IS THE PLOT BOX, NOT A DISTANCE TO
A TRACE … graph_point_at's `tol` is therefore handed a value nothing can
exceed"*. That is the whole design of this item, already written, tested
(`tests/headless/test_wave_snap.tcl` SS8/SG6) and shipped — for the glyph only.
This item makes the KEY agree with the GLYPH.

`graph_plotbox_at()` (`src/draw.c:5031`) is the gate: local `Graph_ctx`, hcursor
bits bracketed (landmines 11 + 37), both screen-coordinate pairs normalised
because `gr->cy` is negative (landmine 3), and it fails closed on a bad index, a
non-graph rect, an off-screen graph, a **digital** strip and **no loaded data**.
It is already exposed as `xschem get graph_plotbox_at <gi> <px> <py>`
(`src/scheduler.c:3859`) and wrapped as `wviewer::plotbox_at`
(`src/wave_viewer.tcl:3875`).

### 2.3 What `graph_point_at()` guarantees about the picked sample

`src/draw.c:5221`, ranking block `:5390-5426`:

* trace ranking is **point-to-SEGMENT** distance (`nd_min`), strictly-nearer
  wins, **ties go to the first node** (`:5408-5411`);
* the anchored **sample** is tracked independently by plain 2-D screen point
  distance (`pd`, `:5393`), so a marker lands on a real data point;
* `hit.x`/`hit.y` are the **RAW** `gvx[p]`/`gvy[p]`, never the `mylog10()`ed ones
  (landmine 35, `:5395-5396`);
* samples outside the graph's **x window** are skipped (`:5376`), so the anchor's
  x is always inside `[gx1, gx2]`. There is **no y-window filter**;
* the same guard prefix as `graph_plotbox_at`: `!xctx->raw || sch_waves_loaded()
  == -1` → 0 (`:5247`), off-screen → 0 (`:5259`), digital → 0 (`:5260`);
* `restrict_wave`/`restrict_dataset` and the `1e30` idiom are already used by the
  marker drag (`src/callback.c:717`, `src/draw.c:6541`).

### 2.4 Everything else on the path needs NO change

* **`src/callback.c`** — the `m`/`d` arms pass the pointer through and test
  nothing themselves. Read-only is gated in the primitive
  (`graph_marker_ro_refuse`, `src/draw.c:6303`), not the arm. Untouched.
* **`src/wave_viewer.tcl`** — `key_filter` (`:5885`) forwards `m` (109) / `d`
  (100) inside `with_edit` whenever `wviewer::over_graph` (`:5859`) says the
  pointer is inside a graph **rect bbox**. That is strictly LOOSER than the plot
  box, so C's gate is the deciding one in the viewer too. Untouched.
* **`src/scheduler.c`** — `graph_plotbox_at` and `graph_trace_at` verbs already
  exist; no new verb, no letter-dispatch risk. Untouched.
* **`log_action`** — `graph_marker_add_record` logs the **data-addressed**
  `add_at <gi> <wave> <dset> <point>` form (`src/draw.c:6352`), never pixels, so
  replay is unaffected by definition.

### 2.5 Measured behaviour today (`--nogui`, hermetic `raw new` fixture)

Fixture: `xschem raw new mkmark.raw dc vsweep 0 1.0 0.1` + `raw add v_a
{vsweep 1 +}` + `raw add v_b {vsweep 2 *}`; one graph rect `0 0 800 400`,
`node="v_a\nv_b"`, `x1=0 x2=1 y1=0 y2=2.5`, `zoom_full`.

| pixel | `graph_plotbox_at` | `graph_trace_at … 20` | `graph_marker add` TODAY | required AFTER |
|---|---|---|---|---|
| (544, 621) — inside the box, > 25 px from every trace | **1** | −1 | **`{}` refused** | **created**, anchored to node 1 |
| (544, 411) — on trace v_a | 1 | 0 | `1` created | unchanged |
| (145, 480) — **outside** the box, 6 px from trace v_a's left end | **0** | **0** (a hit) | **`1` created** | **`{}` refused** |
| digital strip, anywhere | 0 | — | `{}` | unchanged |
| traceless strip, inside its box | 1 | −1 | `{}` | unchanged |

**The whole pixel path runs under `--nogui`.** That is the single most useful
measurement of this scout: `xschem graph_marker add <gi> <px> <py>`,
`xschem get graph_plotbox_at`, `xschem get graph_trace_at` and
`xschem graph_coord` all answer correctly with no X server, so the bulk of this
item's suite belongs in the BOTH-ARMS engine half, not behind a `has_x` guard.

---

## 3. The design

Three lines inside `graph_marker_create()` (`src/draw.c:6357`), in this order:

1. the existing `gr->digital` refusal stays **first**, so the specific message
   survives (`graph_plotbox_at` also refuses digital and would swallow it);
2. **new gate** — `if(!graph_plotbox_at(i, px, py))` → refuse with a message
   naming the plot area;
3. the tolerance in the existing `graph_point_at` call becomes **`1e30`**, and
   its refusal message becomes "no trace to mark in this strip" (a traceless or
   unresolvable strip is now the only way to reach it).

Plus: delete `#define GRAPH_MARKER_PICK_TOL 20.0` (`src/xschem.h:443`) and mend
the comment block above it.

**⚠ The one trap inside this function.** It calls `setup_graph_data(i, 1, gr)` —
`skip = 1`, on a `memset`-zeroed local. `skip` suppresses the `x1`/`x2` read
(`src/draw.c:3866-3874`), so in *that* `gr` `gx1 == gx2 == gw == 0` and
`gr->cx = gr->w / gr->gw` (`:4045`) is **infinity**. Every derived coefficient —
`cx dx scx sdx` — is garbage there, and the `gr->scx == 0.0` "no transform" test
is useless because `inf != 0`. `gr->digital` is the only field that function may
read. **Do not compute the plot box inline from it**; `graph_plotbox_at()` builds
its own `Graph_ctx` with `skip = 0` and is the single source of truth for the box
(the `graph_marker_label_box` doctrine, one function owns one geometry).

---

## 4. Every spec hole, resolved

PLAN.md's recommendation is taken unless source contradicts it; where it does,
the source-supported answer is taken and said so.

| # | Question | Decision | Why | Rejected |
|---|---|---|---|---|
| D1 | What is "the plot area"? | `graph_plotbox_at()` — the rectangle between the two axes. | It is the **same gate the diamond uses**, so "the point the diamond snapped to" is well defined exactly where the key now works. `waveform_viewer_modes.md` §15.7 already states that the legend band and both axis margins draw **nothing** on hover. | The whole graph rect (would arm `m` where no diamond is shown); a new geometry pass (the box is already a shipped, tested, Tcl-visible query). |
| D2 | What does it snap to when the pointer is far from every trace? | The nearest sample of the nearest trace in that strip, however far — `graph_point_at(i, px, py, 1e30, -1, -1, &hit)`, byte-for-byte the call `draw_graph_snap_cursor` makes. | Same call, same inputs ⇒ the marker cannot land anywhere but under the diamond. | **PLAN's `find_closest_wave()` suggestion — refuted by source**, see §6.1. |
| D3 | Where does the relaxation live? | Inside `graph_marker_create()`, the one primitive behind both key arms and the `xschem graph_marker add` verb. | One gate, three doors; and it is what makes the item assertable in the `--nogui` arm (measured, §2.5). | Gating in the `callback.c` key arms (splits the key from the verb, and makes the change invisible to the engine-arm suite). |
| D4 | Does `d` get the same relaxation? | **Yes.** | `d` is `m` plus a `delta` flag on the shared tail; there is literally no second code path. The user's argument ("pressing the key is clear intention") is identical. | Relaxing `m` only. |
| D5 | Pointer outside the plot box (legend / axis margin / grip column)? | **Refuse**, with a new message. | The user asked for "within the plot area". **Measured:** this removes a real 20-px halo outside the box — `xschem graph_marker add 0 145 480` creates a marker today and must refuse after. Outside the box there is no diamond, so there is no "point it snapped to". | A union gate (box **OR** within 20 px). It keeps the halo, contradicts §15.7, and — decisively — makes the margin-refuse leg **unkillable by any sabotage**, because both halves of the union refuse a far margin pixel. |
| D6 | Digital strips and bus traces? | Still refused, unchanged; the **specific** digital message keeps its place FIRST. | `graph_plotbox_at` refuses digital too, so ordering is the only thing preserving "markers are not supported on digital strips". Bus entries are skipped inside `graph_point_at` (`:5309`), so a bus-only strip reaches the "no trace to mark" arm. | Unlocking digital/bus strips (explicitly deferred in `graph_markers.md` §11). |
| D7 | Several traces equidistant? | Unchanged: nearest trace by point-to-SEGMENT distance, strictly-nearer wins, **ties to the first node**; then the nearest SAMPLE on the winner by 2-D screen distance. | `src/draw.c:5390-5426`. Matches PLAN's recommendation and is what the diamond already resolves. | Any new tie rule. |
| D8 | No raw loaded / traceless strip? | Refuse — and by machinery that already exists. | `graph_plotbox_at` and `graph_point_at` share the `!xctx->raw \|\| sch_waves_loaded() == -1` prefix; a strip with no `node` token produces no candidate and falls into the "no trace to mark" arm. Measured both. | A new explicit test (would duplicate a guard). |
| D9 | Does the marker still bind to a TRACE? | **Yes** — trace + dataset + absolute point + cached raw x/y, unchanged. Only the gate moves. | `graph_marker_add_record` is untouched, so undo, `set_modify(1)`, the `graph_marker_notify` push and the `add_at` log line are all unchanged, and anchor-drag still slides along the marker's own trace. | Anchoring to a free x/y point (would be a data-model change — a genuine DEFER trigger, and it is not needed). |
| D10 | What becomes of `GRAPH_MARKER_PICK_TOL`? | **Deleted** from `src/xschem.h`, with the two spec references and two test comments mended. | It had exactly one use, and its comment (*"is there a trace near the pointer on m / d"*) would document a gate that no longer exists — the precise trap the next reader falls into. `test_wave_snap.tcl` SQ3 sets the precedent ("no proximity-threshold var survives"). | Leaving it as a dead `#define`. |
| D11 | The nearest trace is off the strip's **y** window? | Still eligible, exactly as the diamond is. | `graph_point_at` filters on the x window only (`:5376`); consistency with the feedback glyph is the rule this item exists to establish. A visible trace is always nearer in screen space than an off-window one, so this only fires when **every** trace is off-window. The callout stays readable: `graph_marker_label_box` clamps it to the plot box (`graph_markers.md` §4.1). | Adding a y-window filter (would make the key and the diamond disagree again, in the other direction). |
| D12 | Does the marker DRAG change? | **No.** | `graph_marker_move` / `graph_marker_anchor_at` already pass `1e30` restricted to the marker's own trace (`src/draw.c:6541`, `src/callback.c:717`) and deliberately tolerate the margins (landmine 36's tolerance gap). Out of scope. | Applying the box gate to the drag (would break the documented 8-px above-the-box grab). |
| D13 | Where does the suite live? | `tests/headless/test_wave_markers.tcl`, new group **`MP*`**, with the bulk in the **BOTH-ARMS** engine half. | Measured: the pixel verb, the plot-box query and `graph_coord` all work under `--nogui` (§2.5). PLAN assumed less. | A new suite (the fixture, helpers and footer already exist here); a DISPLAY-only group (halves the coverage for nothing). |
| D14 | The existing `MX4` group asserts the OLD refusal — what happens to it? | **Invert it**, and first tighten `mx_empty_row` (`:3757`) to require `wviewer::plotbox_at`. | Without the requirement MX4's verdict after this change depends on whether the scanned row happens to land in the legend margin or inside the box — the *exact* defect `mf_empty_px` (`:1739`) already carries a 9-line comment about. A test whose expected value depends on an unasserted scan is worse than no test. | Leaving MX4 alone (it would fail, correctly, and for a reason the reader cannot tell from the leg name). |
| D15 | How is the margin-refusal driven in the DISPLAY/viewer arms? | Through the **verb** (`mk_wadd`), **never** a synthetic `m` key. | A key not claimed by the graph falls through to the schematic handler, where `m` is `readonly_block()` — a MODAL that hangs the run to the harness timeout and is scored CRASH. The MX0 banner (`:3746-3754`) documents this, probe-verified. `waves_selected` insets each rect by `5 * tk_scaling * zoom` screen px, so "inside the rect" does not imply "claimed". | Pressing `m` in the margin. |
| D16 | Is a numbered issue warranted? | **Yes — `0188`.** | Same class as 0177/0174: a shipped feature whose gate was proximity where it should have been the plot box, reported by the user in those words. The next free number is 0188 (highest present: 0187). | No issue file (this is a reported defect in shipped behaviour, not a greenfield feature). |

---

## 5. Collision map — what else owns these pixels and these keys

`m` and `d` are **keys**, so there is no mouse-gesture collision to design
around. The complete ownership picture for the pixel the key is aimed at:

| surface | region | owner | interaction with this item |
|---|---|---|---|
| item-9 diamond (`draw_graph_snap_cursor`) | plot box | C | **becomes the exact partner** — same gate, same query, same sample |
| trace SELECTION / wave-bold click | within `GRAPH_TRACE_PICK_TOL` (10 px) of a trace | C | untouched; regression-witnessed |
| RMB trace menu, strip-drag press, strip menu | same 10 px | Tcl | untouched (all four share `GRAPH_TRACE_PICK_TOL`, `xschem.h:405-413`) |
| strip drag-to-reorder | empty body + the `GRAPH_REORDER_HANDLE_W` (14 px) grip | Tcl | untouched — a KEY cannot collide with a drag |
| legend picking (`graph_legend_at`) | band at the rect top | C | now explicitly **outside** `m`'s reach (it is outside the plot box) |
| axis-number margins | left/bottom of the rect | — | now explicitly outside `m`'s reach; **items 03 and 04 of this batch claim these regions for LMB-drag and Ctrl+wheel.** This item takes no gesture there, so there is no conflict — but it does establish that "inside the plot box" is the boundary those items must hit-test against. |
| marker anchor/label grab | `GRAPH_MARKER_TOL` (8 px) around a drawn marker | C | untouched (press path, not the key) |
| `M` (tooltip), `t`, `a`/`b`/`s` | anywhere over a graph | C | untouched |
| `Delete` | over a graph | Tcl in the viewer, C on canvas graphs | untouched |
| `waves_selected` 5-px rect inset | the rim of every strip | C | unchanged, and the reason D15 forbids a synthetic key in the margin |

---

## 6. PLAN.md claims that source refutes

### 6.1 "`find_closest_wave()` is still live for precisely this 'nearest, however far' purpose — reuse it, do not clone it."

**Refuted.** `find_closest_wave()` (`src/draw.c:4700`) is the wrong primitive
here on five independent counts, every one of them documented in the tree:

1. it reads the **C mouse mirror** (`xctx->mousex/mousey`), not the caller's
   pixels — stale for a press with no preceding Motion (landmine 33);
2. it measures only `|Δy|` at the nearest sample, not a real distance;
3. it returns the **dataset** and writes `*node_number`; it does **not** yield
   the `(dataset, point, raw x, raw y)` identity `graph_marker_add_record`
   requires — that is precisely what `GraphPointHit` was introduced for;
4. landmine 40 records **two still-open defects** in it (per-node
   `extra_rawfile` switch with a single restore, gated on intent rather than
   success). Routing marker creation through it would inherit both;
5. the correct primitive is already in the function being edited:
   `graph_point_at(..., 1e30, ...)`, which is what the **diamond** uses.

PLAN's own Q2 recommendation ("the existing nearest-wins rule with the tolerance
dropped (`1e30`), which is exactly what the rigid marker drag already does") is
correct; only the trailing sentence naming `find_closest_wave` is wrong.

### 6.2 "a plot-box pixel measured to be >10 px from every trace now places a marker (this is the leg that dies if the gate is not relaxed)"

**Refuted — `>10 px` is not enough, and a leg built on it would be green and
hollow.** The gate today is `GRAPH_MARKER_PICK_TOL` = **20.0**
(`src/xschem.h:443`), not `GRAPH_TRACE_PICK_TOL` = 10.0. A pixel 12 px from a
trace already creates a marker on the shipping build. The far pixel must be
> 20 px from every trace; the suite's existing scanners use **25** for exactly
this reason (`mf_empty_px` `:1745`, `mx_empty_row` `:3766`).

### 6.3 "`test_wave_markers` is ALREADY RED, at `1 FAILED (802 passed)` … you inherit that one red leg"

**Refuted as stated — it is GREEN today, and MF1 is flaky, not red.** Measured
2026-08-01 on unmodified HEAD, `GUI_GATE=0 tests/headless/run_suites.sh`:

```
--nogui   : RESULT: ALL PASS (328 checks)
DISPLAY   : RESULT: ALL PASS (803 checks)   x 4 consecutive runs
```

803 = 802 + the MF1 leg PLAN saw fail. `status.md` already records MF1 as
load- and timing-sensitive ("0/8 on a paired control, 6/30 on an unpaired
soak — the difference was machine load"). The implementer's gate must therefore
be **"0 or 1 FAILED; any failing leg is MF1; and the pass count rose by exactly
the number of legs I added"**, not "1 FAILED at MF1".

### 6.4 "Likely files: `src/draw.c`, `src/callback.c`, `src/xschem.h`, `src/wave_viewer.tcl` (`key_filter`), possibly `src/scheduler.c`"

**Narrowed.** The code change is **`src/draw.c` + `src/xschem.h` only**.
`callback.c`, `wave_viewer.tcl` and `scheduler.c` need no edit at all (§2.4);
`wave_viewer.tcl`'s `key_filter` gate is the rect bbox, which is looser than the
plot box, so C decides in the viewer too.

---

## 7. The exact formulas and invariants the suite asserts

With the hermetic fixture (`vsweep` 0…1 step 0.1, so sample `p` has
`x == p/10` **exactly**, `v_a[p] == 1 + p/10`, `v_b[p] == p/5`):

* **The gate.** `create(gi, px, py)` succeeds ⟺
  `graph_plotbox_at(gi, px, py) == 1` **and** `graph_point_at(gi, px, py, 1e30,
  −1, −1, ·) == 1`. Both halves witnessed independently.
* **The anchor's trace.** `marker.wave == [xschem get graph_trace_at gi px py 1e30]`
  — the same engine answer, obtained through a different verb.
* **The anchor is a real sample.** `marker.x == marker.point / 10` exactly at
  `%.17g`, and `marker.y ≈ [xschem raw value <name> marker.point]` to 1e-7
  relative (`mk_close`; `raw value` renders through `dtoa`/`%.8g` and the token
  is `%.17g`, so this comparison is numeric by law).
* **The anchor is inside the x window.** `gx1 ≤ marker.x ≤ gx2`.
* **The anchor is near the pointer.** `|marker.x − Gx(px)| ≤ 1.01 × step`, where
  `Gx(px)` is `lindex [xschem graph_coord gi px py] 0` — an independent
  pixel→data path (`scheduler.c`'s `graph_coord`, not `graph_point_at`).
* **The old halo is gone.** For a pixel with `graph_plotbox_at == 0` **and**
  `graph_trace_at … 20 ≥ 0`: `create` returns `{}`.
* **Coverage, as a FRACTION not a magic count** (the `test_wave_snap` SG6
  lesson): sweeping a vertical line at fixed `x` through the box in steps of 8,
  every pixel inside the box creates (`created/tried > 0.95`), and two probe
  pixels 8 px above the box top and 8 px below the box bottom create nothing.
* **`d` is `m` + `prev`.** `add … -delta` at the same far pixel returns a number
  whose record has `prev == <the previously created number>`.
* **Selection proximity is untouched.** At the far pixel
  `graph_trace_at gi px py` (default tol) `== −1` while `create` succeeds — the
  two gates are demonstrably different — and `#define GRAPH_TRACE_PICK_TOL 10.0`
  is still in `xschem.h`.
* **The diamond equality (DISPLAY).** With `graph_snap_cursor` armed, after a
  motion to the far pixel `xschem get graph_snap` = `{gi wave x y}`; the marker
  then created by the `m` KEY at that same pixel has the same `gi`, the same
  `wave`, and `x`/`y` equal to 1e-7 relative. This is the user's sentence,
  asserted.

---

## 8. Test plan

Suite: `tests/headless/test_wave_markers.tcl` (already registered — `full_audit.sh`
auto-discovers `tests/headless/test_*.tcl`; no `logdir_tests` change).

* **`MP*` engine group, BOTH arms**, inserted after the MF engine half's
  `mk_reset` / `raw clear` (`:1669-1671`), with its own fixture and its own
  teardown, so the MF display half below it starts exactly as it does today.
  Scanned pixels only — never hardcoded — with a staging leg per pixel that
  FAILS loudly if the scan came up empty.
* **`MP2x` display legs** inside the existing MF display block, reusing
  `mfe1x`/`mfe1y` (already "empty waveform space, inside the plot box, > 25 px
  from every trace" via `mf_empty_px`): the `m` KEY, the `d` KEY, and the
  diamond-equality leg.
* **`MX4` inverted** in the viewer group, after `mx_empty_row` gains its
  `wviewer::plotbox_at` requirement, plus a new margin scanner driven through
  the **verb** (D15).

Three named sabotages, each with an explicit kill list:

| # | sabotage | must kill | must stay green |
|---|---|---|---|
| SAB-1 | put the tolerance back: `1e30` → `20.0` | `MP2` and the legs that need the far-pixel marker to exist (`MP3`–`MP6`, `MP8`, `MP9`-positive), plus the display `m`/`d`/diamond legs | `MP7`, `MP10`–`MP13`, `MP9`-negative |
| SAB-2 | delete the `graph_plotbox_at` gate line | `MP7` and `MP9`-negative **only** | `MP2`–`MP6`, `MP8`, `MP10`–`MP13` |
| SAB-3 | anchor to node 0: pass `restrict_wave = 0` instead of `−1` | `MP3` **only** (the fixture's far pixel is deliberately scanned so its nearest trace is node **1**) | everything else |

### 8.1 As MEASURED at implementation — two deviations from the lists above

Each sabotage was applied, rebuilt, run in both arms and reverted; the clean
re-run was green (373 / 870).

| # | measured kill list |
|---|---|
| SAB-1 | `MP2`(2) `MP3` `MP4`(2) `MP5` `MP6` `MP8`(2) `MP9`-positive `MP15`(2) `MP20`(3) `MP21`(2) `MP22`(5) `MX4`(4) — **plus `MP14`'s `1e30` tripwire** |
| SAB-2 | `MP7`-refusal, both `MP9`-negatives, `MX4b`(2) — **plus `MP14`'s plot-box tripwire** |
| SAB-3 | `MP3` — **plus `MP14`'s tripwire** (it asserts the exact `-1, -1` pair) |

**Deviation 1 — `MP14` dies with every sabotage, and that is correct.** The
prompt files `MP10`–`MP14` under "must stay green" for SAB-1 and SAB-2. `MP14`
is the SS8-style *source tripwire*: it asserts the exact source lines each
sabotage edits, so it cannot survive its own sabotage. A tripwire that a
sabotage of its own line leaves green would be the defective leg. Kept.

**Deviation 2 — `MP13`'s "and creation succeeded there" witness was MOVED to
`MP2`.** As specified, `MP13` both asserted that selection still refuses at the
far pixel *and* re-created a marker there — which made it die under SAB-1, in
contradiction with the same table's "must stay green". `MP13` is the regression
witness that this item changed **one** gate and not the other, so it must
survive every sabotage of the creation gate; the paired
`{created, selection == -1}` assertion now lives in `MP2`, where dying under
SAB-1 is the point. Two other legs were hardened for non-vacuity at the same
time (`MP8` builds its own base marker rather than reusing `MP2`'s, so a
sabotage that lets `MP7`'s halo create cannot make `MP8` fail for `MP7`'s
reason; `MP8`/`MP21` carry an explicit `string is integer` / `llength` term
because two `{}`s compare equal).

### 8.2 One robustness fix the first full-audit run forced

The `MP*` fixture scan originally seeded its plot-box search over an absolute
`0..1800 x 0..1400` pixel range. That passed every standalone run and then found
**nothing** in one `full_audit` run — `zoom_full` fits the drawing to whatever
the canvas happens to be, and under a window the WM had not finished sizing the
strips were not in that range. An empty coordinate then reached `expr {$mpby1 +
1}`, which unwound the whole file through the outer catch and cost 20 further
legs. Three changes, all of them house idioms already present in this suite:
the seed sweep is bounded by the strip's own band through the engine transform
(`mp_band`, the MF half's `mf_band`); the scan retries behind an
`mp_reestablish` (deiconify / wait-for-mapped / `zoom_full`) up to three times,
re-deriving **every** pixel together; and an unscannable pixel becomes the
sentinel `-1` rather than `{}`, so every leg fails loudly instead of throwing.
The group also gained the GROUP CATCH the MF and MX halves already carry.

---

## 9. Pixels / feel this item cannot assert

The implementation introduces **no new rendering**, so per PLAN's own rule this
is an `[x]` candidate rather than `[E]`. Two consequences are nevertheless
judgement calls no assertion can make:

1. **The removed 20-px halo outside the plot box.** Whether refusing `m` 6 px
   outside the box while a trace passes right there feels correct is a judgement.
   It is asserted as behaviour (MP7) and argued from §15.7, but not eyeballed.
2. **A marker anchored to a trace that is off the strip's y window** (D11) draws
   its anchor glyph outside the plot box while the callout is clamped inside it.
   Behaviourally asserted; visually unjudged.

---

## 10. Documentation this item owes

* `doc/claude/specs/graph_markers.md` — §2 decisions (a new row for the gate),
  §6.1 key table (`m`/`d` rows), §6.3 refusal list (replace the
  `GRAPH_MARKER_PICK_TOL` bullet), §10.1 constants paragraph (drop the constant),
  §11 shipped ledger.
* `doc/claude/specs/waveform_viewer_modes.md` §15.7 — the hover table gains the
  statement that `m`/`d` create **exactly where the diamond appears**.
* `doc/claude/code_analysis/waveform_subsystem_reference.md` — the `xschem.h`
  row of the §1 file map (constant list), the §5 `waves_callback` bullet, and a
  **new landmine 45** carrying the two reusable lessons: *a creation gate must
  match the FEEDBACK gate*, and *`graph_marker_create`'s `setup_graph_data(i, 1,
  gr)` leaves `gx1/gx2/gw` at 0 and every transform coefficient at infinity — the
  box must come from `graph_plotbox_at()`*.
* `doc/claude/issues/0188-marker-create-gate-is-proximity-not-plot-box.md` — new.

---

## 11. Why this is not a DEFER

The diamond snap cursor **exists** (`draw.c:5141`, suite `test_wave_snap.tcl`),
which is PLAN's only stated defer trigger. The change is a three-line
substitution inside one primitive, using a gate function that is already
shipped, already exposed to Tcl and already tested for the sibling feature. No
data-model change, no new verb, no new constant, no Tcl mirror. The single
behavioural narrowing (D5) is measured, argued and asserted.
