# OVB-05 — dragging one selected trace drags the whole selection, with the shrink preview on all of them

You are implementing item **05** of the overnight batch
`doc/claude/overnight_batch_2026_08_01/PLAN.md`. Repo
`/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.

**The user's spec, verbatim:**

> When multiple traces are selected, an LMB-press-and-drag with press on/near one
> of the traces, and drag to a destination strip will cause all selected traces to
> be moved to the destination. All selected traces being moved will display the
> cool-factor shrink during the press-and-drag

The scout has already resolved every spec hole. **Read the decision doc first and
implement what it decided** — do not re-litigate D-41…D-60.

Issue to open: `doc/claude/issues/0192-multi-trace-drag-to-strip.md`.
Spec home: `doc/claude/specs/waveform_viewer_modes.md` **§19** (new).

> ⚠ **The single most important thing PLAN.md gets wrong about this item:** the
> "cool-factor shrink" is **already shipped** — both axes, one rc knob
> (`::wviewer_drag_shrink`, default `0.7`), bit-16 chrome, 46-check suite. You
> are **not building it**. You are making it carry N traces instead of 1, and you
> must **not** change the factor, the maths or the knob. See decision doc §9.1.

---

## READ FIRST (in order)

1. `doc/claude/code_analysis/ovb01_05_multi_trace_drag_to_strip_decision.md`
   — **your contract.** Design, all resolved spec holes, the collision map, the
   invariants the suite asserts, the sabotage table, the eyeball list.
2. `doc/claude/code_analysis/waveform_subsystem_reference.md` — the WIRING.md of
   this subsystem. §2.3 (a graph is an `xRect`), §4 (render pipeline), §5
   (interaction), §8 (the ASE viewer), §9 (verb surface), §10 (the "New viewer
   op" recipe), landmines **3, 11, 17, 18, 19, 20, 32, 33, 34, 41, 43, 46**.
   Landmine **34** and landmine **46** are the two you will lean on hardest.
3. `doc/claude/specs/waveform_viewer_modes.md` — **§13** (the single-trace drag
   you are extending: §13.2 the pure ops, §13.3 the ordering contract, §13.5 the
   `reorder_handle=4` frame), **§12.2/§12.3** (the ordering contract's origin and
   `capture_live_graph_state`), **§14** (viewer undo — `push_undo` is the
   extension seam), **§15** (the trace SELECTION as a SET; §15.1 is the full
   LMB/RMB ownership table you will add a row to), **§16** (`delete_items`, the
   N-object gesture template).
4. `doc/claude/specs/waveform_viewer.md` — the "**Mid-drag shrink preview (viewer
   plan item 6, 2026-07-29)**" section. Read it in full before you touch
   `graph_preview` anything.
5. `doc/claude/specs/graph_markers.md` §3.5 (transient UI state vs durable
   content) and §7.2/§7.3 (the Button1 precedence table you must not disturb).
6. `CLAUDE.md` — build, tests, conventions.

---

## DISCIPLINE (non-negotiable)

* **C89.** Declarations at the top of a block. No `//` comments in `.c` files.
  Allocations use `my_malloc`/`my_strdup`/`my_realloc` with the literal
  `_ALLOC_ID_` placeholder — never a hand-written number.
* **`xschem get` sub-keys are letter-dispatched.** `graph_preview_set` goes in
  `xschem_cmds_g`'s `get` `case 'g':` chain, beside `graph_preview`. `xschem set`
  splits on `argv[2][0] < 'n'` — `graph_preview` is already in the `< 'n'` half
  and stays there. A key filed in the wrong half is **silently unreachable**: no
  error, the setter just does nothing.
* **FIXED arrays in `xctx`, never pointers.** `xctx` is *reset*, not freed
  (`clear_drawing`), and a pointer would add a free path for nothing — landmine
  46(b). Same rule that made `graph_marker_sel_set[]` and
  `Graph_ctx.sel_wave[]` fixed.
* **ONE writer and ONE draw-side predicate.** Landmines 43 and 46(a): a surviving
  bare comparison renders a selected/previewed object in the wrong style and **no
  behavioural leg that exercises a single object can see it**. That is why `DM6`
  asserts it at SOURCE level with a `count_code`-style tripwire.
* **Constants mirrored between C and Tcl must be changed on both sides** with a
  "change both" comment each (the `GRAPH_REORDER_HANDLE_W` precedent).
  `GRAPH_MAX_PREVIEW_WAVES` is deliberately **not** such a constant — say so at
  the `#define`.
* **A green suite does not prove your code ran.** Every named sabotage below must
  fail **exactly** its target check; revert it with a targeted
  `git checkout -- <file>` **only after** `git diff` confirms that file holds
  nothing but the sabotage; then a clean re-run must be green again.
* **Run every suite with `GUI_GATE=0` in the environment.** Nobody is at the
  desk. Prefer `tests/headless/run_suites.sh`; never a bare `for` loop over
  `./src/xschem`.
* **Never `git push`. Never `git reset --hard`. Never `git add -A` / `git commit
  -a`.** Stage the explicit file list at the end of this prompt and nothing else.
  Do not touch the ~60 pre-existing untracked scratch paths in the tree.
* Scratch files go in the test's own `test_scratch` dir, never the repo root.
* **Do not "re-fix" pre-existing bugs you notice outside this item's scope** —
  record them in the receipt. (Two are already known and listed in decision doc
  §10; leave both.)

---

## ANCHORS (verified by the scout 2026-08-01 — **verify, do not trust**)

Line numbers drift. Grep the symbol, then confirm the line says what this table
claims before you edit near it.

### `src/wave_viewer.tcl` — most of the work is here

| line | symbol | what it does |
|---|---|---|
| 381-391 | the `tdrag_*` variable block | five per-window arrays created in `open`. **Add `tdrag_pairs` here** |
| 526-529 | `forget`'s `foreach a {tdrag_gi …}` | unsets them. **Add `tdrag_pairs` to that list** |
| 945 / 950 / 958 | `empty_graph` / `layout_for` / `set_graphs` | model accessors |
| 1162 | `remap_markers_after_trace_move` | marker migration for ONE moved trace |
| 2232 | `set_target_strip` | writes the `active` token; **no regenerate**, so a live selection survives a press |
| 2283 | `strip_at_pixel` | which strip band a canvas pixel is in |
| 2481 | `capture_live_graph_state` | folds live `x1 x2 y1 y2 hilight_wave sel_waves markers` back into the model. **Must run FIRST in any mutation** |
| 2818 / 2838 | `marker_grabbed` / `axis_grabbed` | the two "ask C what it armed" rungs |
| **2973** | **`strip_drag_press`** | forwards the press to C verbatim at `:2984`, then the rungs |
| **3015-3021** | the trace-zone rung | `trace_at >= 0` → `cursor_grabbed` wins, else `trace_drag_arm` |
| 3036 / 3067 / 3117 | `strip_drag_motion` / `_release` / `_cancel` | `_release` forwards to C **before** `trace_drag_drop` at `:3104` |
| 3144 / 3159 / 3182 | `node_index_of_trace` / `node_count` / `trace_index_of_node` | **landmine 34**: model index != node index |
| 3200 / 3240 | `remap_hilight_after_trace_move` / `remap_sel_after_trace_move` | the scalar and SET remaps |
| 3216 / 3228 | `model_sel` / `model_sel_set` | the model-side mirror of the two tokens |
| **3272** | **`move_trace_in_graphs`** | **PURE. The primitive your fold calls. Do not edit it.** `:3303` is the independent `moved_was_bold`; `:3312-3314` is the empty-destination range blanking |
| **3357** | **`move_trace`** | the shipped singular mutation and its ordering contract. **Do not edit it**; your plural form copies its shape |
| 3506 | `move_trace_to_new_strip` | a second `move_trace_in_graphs` caller — leave alone |
| 3850 | `push_undo` | the extension seam |
| 3953 / 3965 / 3982 | `plotbox_at` / `trace_at` / `legend_at` | the fail-closed C query wrappers |
| 3994 / **4010** | `sel_waves_norm` / **`selected_waves {wp gi}`** | the live per-strip selection, read off the RECT |
| 4028 | `trace_drag_feedback` | paints `reorder_handle=4` on the destination. Unchanged |
| 4047 / **4062** | `trace_drag_clear` / **`trace_drag_reset`** | **`:4071` takes the preview down BEFORE the frame repaint — keep that order** |
| **4091** | **`trace_drag_arm`** | where the moving SET is computed and stored |
| **4129** | **`drag_shrink`** | the knob. **Do not change the default, the range check or the fallback** |
| **4143** | **`drag_preview_arm {token gi ti}`** | becomes a wrapper over the new plural form |
| 4159 | `drag_preview_clear` | disarm + redraw. Unchanged |
| **4168** | **`trace_drag_motion`** | `:4176` the 3-px threshold, `:4186` the one-shot preview arm |
| **4205** | **`trace_drag_drop`** | `:4215` the three refusals, `:4220` the one `move_trace` |
| 4690 | `delete_in_graphs` | the PURE delete; removes highest-index-first (0176 D6) |
| **4786** | **`delete_items`** | **the N-object template. Read its header before writing `move_traces`** |
| **4943** | **`delete_selection_at`** | **`:4950-4958` is the selection→MODEL-pairs fold you are extracting** |

### `src/draw.c`

| line | symbol | what it does |
|---|---|---|
| **2925** | `wave_is_hilighted(gr, wcnt)` | **the predicate idiom to copy.** Put `graph_preview_has()` beside it |
| 2945 / 2994 / 3040 | `graph_sel_waves_get/set/toggle` | the only C readers/writers of the selection token pair |
| **3505** | `draw_graph_points()` starts | |
| **3517-3519** | the `preview` local + its comment | |
| **3548-3553** | **the ONE preview comparison.** `!digital && gr->preview_wave == wcnt && xctx->graph_preview_scale != 0.0`; centre = mean of `S_Y(gy1)`/`S_Y(gy2)` (landmine 3) | |
| 3588 | `if(preview) yy = prev_c + (yy - prev_c) * prev_s;` — before the rail clamp | |
| 3605-3614 / 3666-3670 | the X scale-in-place and its verbatim restore | |
| 3796 | `setup_graph_data()` starts | |
| **3823** | **`gr->preview_wave = -1;`** — the default, **above** the `RECT_OUTSIDE` return | |
| 3899 | the `RECT_OUTSIDE` early return | landmine 37 |
| 5851 / 5861 | `graph_wave_at` / `graph_near_wave` | the pick. **Do not touch** |
| **6901** | `graph_marker_is_selected(num)` | **the SET-predicate shape to mirror** |
| **7195** | `draw_graph(i, flags, gr, ct)` | |
| **7222-7234** | **the preview arming block.** `(flags & 16) && has_x && scale != 0.0 && i == graph_preview_gi` | |
| 7506 / 7556 | the two `draw_graph_points(...)` calls | the ONLY callers — which is why `gr->preview_gi` is always set before use |

### `src/xschem.h`

| line | what |
|---|---|
| 393 | `GRAPH_REORDER_HANDLE_W` — the "MIRRORED IN TCL, change both" precedent |
| 418 | `GRAPH_TRACE_PICK_TOL 10.0` — four surfaces share it. **Do not touch** |
| **434** | `GRAPH_MAX_SEL_WAVES 64` + the "fixed array, never a pointer" reasoning |
| **458** | `GRAPH_MARKER_MAX_SEL 8` + the "NOT mirrored in Tcl" reasoning — **copy this comment shape for `GRAPH_MAX_PREVIEW_WAVES`** |
| 1183-1190 | `Graph_ctx.sel_wave[]` / `n_sel_waves` |
| **1231-1237** | **`Graph_ctx.preview_wave`** — the field you rename |
| **1728-1736** | **`graph_marker_sel` + `graph_marker_sel_set[]` + `graph_marker_n_sel`** — the head/set/count pattern |
| **1763-1774** | **the `graph_preview_*` block.** ⚠ `:1771` claims a `graph_preview_clear()` that **does not exist** — fix that sentence |
| 2034-2037 | the `graph_sel_waves_*` + `wave_is_hilighted` prototypes — put yours here |

### `src/scheduler.c`

| line | what |
|---|---|
| 3615 | `xschem_cmds_g` (the `get` verb) |
| 3804 | its `case 'g':` |
| **4052-4071** | **`get graph_marker_sel` + `get graph_marker_sel_set`** — the head/set getter pair. `Tcl_ResetResult` + `Tcl_AppendElement` loop is the idiom to copy |
| **4099-4112** | **`get graph_preview`** — **leave its output shape byte-identical** |
| 9976 | `xschem_cmds_s` (the `set` verb) |
| **10593** | `if(argv[2][0] < 'n')` — the `set` letter split |
| **10612-10635** | **`set graph_preview`** — where the trailing pairs are parsed |

### `src/actions.c` / `src/xinit.c`

| line | what |
|---|---|
| **1935-1937** (`actions.c`) | `clear_drawing()`'s three preview resets. Add the count |
| **686-688** (`xinit.c`) | `alloc_xschem_data()`'s three. Add the count |

### Test files

| file:line | helper |
|---|---|
| `tests/headless/test_wave_modes.tcl:266` / `:387` / `:565` | the `M7` / `M8` / `DT` PURE groups — your `MV*` group's neighbours and style. ⚠ **`M9` is TAKEN** (issue 0173) |
| `tests/headless/test_wave_drag_preview.tcl:102-116` | the `DV*` verb legs (extend after `DV7`) |
| `:143` / `:155` / `:169` | `dp_ev` (`-time`-stamped events) / `fill_viewer` (**plants a vec-less trace deliberately**) / `find_trace_px` |
| `:138` | `preview_of` |
| `tests/headless/test_wave_trace_menu.tcl:364` / `:376` / `:383` / `:398` | `viewer_ready` / `profile` / `vecs_at` / `tm_ev` |
| `:406` | **`fill_viewer`** — 3 traces on strip 0, 1 on strip 1, real hermetic raw |
| `:482-486` | `xschem raw new` / `raw add` — the hermetic fixture, no ngspice |
| `:1248` / `:1277` / `:1282` / `:1292` | `ts_sels` / `ts_click` (`st 0x4` = Ctrl) / `ts_px_for_node` / `ts_far_px` |
| `tests/headless/test_wave_viewer.tcl:1884-1886` | the inert `sdid` per-strip key idiom |

**MEASURED baselines (2026-08-01, `GUI_GATE=0`, under `$DISPLAY`) — record them,
you must beat them:**

```
test_wave_drag_preview.tcl   ALL PASS (46 checks)
test_wave_trace_menu.tcl     ALL PASS (323 checks)
test_wave_viewer.tcl         ALL PASS (368 checks)     <- must NOT change
test_wave_modes.tcl          ALL PASS (433 checks)
```

---

## DO — in this order

### 1. Reproduce the two measurements the design rests on

Before writing a line, confirm for yourself with a throwaway script in your own
`test_scratch` dir:

* **(a)** the shrink preview is already shipped and already both-axes:
  `xschem set graph_preview 0 1 0.7; xschem get graph_preview` → `0 1 0.7`, and
  `wviewer::drag_shrink` → `0.7`. If this does not hold, **stop and report** —
  the whole item is "extend it", not "build it".
* **(b)** a press over a trace does **not** change the selection (only the
  no-travel *release* does). Open the viewer, select a trace, press on another
  trace without releasing, read `wviewer::selected_waves` — it must still name
  the first. This is what makes D-41's press-time read correct.

### 2. `src/xschem.h`

* Add, immediately after `GRAPH_MARKER_MAX_SEL` (~:458) or beside the
  `graph_preview_*` block — your choice, but next to one of the two caps:

```c
/* How many traces one MULTI-TRACE drag can PREVIEW at once (issue 0192,
 * doc/claude/specs/waveform_viewer_modes.md 19). Matches GRAPH_MAX_SEL_WAVES
 * because the set is derived from the trace selection.
 * FIXED arrays in xctx, never pointers: xctx is reset, not freed, at
 * clear_drawing() and alloc_xschem_data(), and a pointer would add a free path
 * for nothing (landmine 46(b)).
 * The cap bounds the PREVIEW only -- the move itself is uncapped, so the worst
 * case of an over-long selection is that the 65th carried trace is drawn full
 * size while it travels. Refusing the gesture over a cosmetic limit would be a
 * functional regression.
 * NOT mirrored in Tcl: Tcl reads the list back from `xschem get
 * graph_preview_set` and never needs the cap (the GRAPH_MARKER_MAX_SEL rule). */
#define GRAPH_MAX_PREVIEW_WAVES  64
```

* In the `graph_preview_*` xctx block (~:1763-1774): keep `graph_preview_scale`,
  `graph_preview_gi` and `graph_preview_wave` **exactly as they are** and
  document them as the **HEAD** (the `graph_marker_sel` wording at `:1728`), then
  add the set beside them:

```c
  int graph_preview_set_gi[GRAPH_MAX_PREVIEW_WAVES];
  int graph_preview_set_wave[GRAPH_MAX_PREVIEW_WAVES];
  int graph_preview_n;   /* 0 <=> graph_preview_scale == 0.0 */
```

  **and fix the stale sentence** — there is no `graph_preview_clear()`; the
  resets are inline in `clear_drawing()` (`actions.c`) and
  `alloc_xschem_data()` (`xinit.c`).

* `Graph_ctx` (~:1231-1237): rename `preview_wave` → `preview_gi` and rewrite its
  comment: it is now the **rect index this draw may preview, or -1**, not a node
  index; the per-trace question moved to `graph_preview_has()`; and the
  default-before-`RECT_OUTSIDE` rule is unchanged and still load-bearing
  (landmine 11).

* Add two prototypes beside `wave_is_hilighted` (~:2037), with a comment saying
  `graph_preview_arm` is the ONE writer and `graph_preview_has` the ONE draw-side
  test:

```c
extern void graph_preview_arm(const int *gis, const int *waves, int n, double scale);
extern int  graph_preview_has(int gi, int wcnt);
```

### 3. `src/draw.c`

* Beside `wave_is_hilighted` (~:2925), add both functions. `graph_preview_arm`
  clamps `n` to `GRAPH_MAX_PREVIEW_WAVES`, copies the pairs, sets
  `graph_preview_n`, sets the head from element 0, sets the scale — and when
  `scale == 0.0` **or** `n <= 0` it zeroes all five fields, so the disarm has one
  home. `graph_preview_has` returns 0 immediately when
  `xctx->graph_preview_scale == 0.0`, then walks the set comparing **both**
  `gi` and `wcnt`.
  Comment: this is the `graph_marker_is_selected` shape (landmine 46(a)); a
  surviving bare comparison would draw a carried trace at full size and no leg
  that drags one trace can see it, which is why `DM6` counts the sites at source
  level.
* `setup_graph_data` `:3823`: `gr->preview_wave = -1;` → `gr->preview_gi = -1;`.
  Keep it exactly where it is (above `RECT_OUTSIDE`) and keep the comment's
  reasoning, updated for the new meaning.
* `draw_graph` `:7230-7234`: replace the block with
  `gr->preview_gi = ((flags & 16) && has_x) ? i : -1;`, keeping the existing
  comment about bit 16 being chrome stripped from every export and `has_x`
  because a preview is a thing you look at. Add: the *membership* test moved into
  `graph_preview_has()` so one predicate answers for every graph.
* `draw_graph_points` `:3548`: the condition becomes
  `if(!digital && gr->preview_gi >= 0 && graph_preview_has(gr->preview_gi, wcnt))`.
  **Change nothing else in this function** — not the centre computation, not the
  scale line, not the X save/restore.

### 4. `src/scheduler.c`

* `set graph_preview` (~:10612-10635): keep the three-argument form's meaning
  byte-identical and accept **trailing `<gi> <ni>` pairs**. Parse into two local
  fixed arrays sized `GRAPH_MAX_PREVIEW_WAVES`, head first, ignore a trailing odd
  argument, then call `graph_preview_arm(...)`. `argc <= 5` still disarms.
  Update the comment block: the three-argument form is the single-trace arm
  (viewer plan item 6), the pairs are issue 0192's multi-trace arm, and the head
  is element 0 so `get graph_preview` is unchanged.
* Add `get graph_preview_set` to the `case 'g':` chain immediately after
  `get graph_preview`, copying `graph_marker_sel_set`'s body shape verbatim
  (`Tcl_ResetResult` then an `Tcl_AppendElement` loop of `%d`s), emitting
  `gi ni gi ni …` head first and `""` when `graph_preview_n == 0`. Fail SOFT —
  never a Tcl error.

### 5. `src/actions.c` and `src/xinit.c`

Add `xctx->graph_preview_n = 0;` beside the three existing resets in each
(`actions.c:1935-1937`, `xinit.c:686-688`). One line of comment: the set joins
the same reset class for the same reason — a surviving arm would shrink whatever
trace lands at that index in the NEW document.

### 6. `src/wave_viewer.tcl`

Everything below keeps the shipped procs' signatures unless stated.

* **`wviewer::selection_pairs {W}`** — new, placed next to `selected_waves`
  (~:4010). Folds `selected_waves` across every strip of the window into MODEL
  `{gi ti}` pairs via `trace_index_of_node`, ascending. Then **rewire
  `delete_selection_at` (`:4950-4958`) onto it** so there is exactly one such
  fold in the file (D-53), with a comment saying why (landmine 43/46(a)).
* **`tdrag_pairs`** — new per-window array. Declare at `:381-391` with a one-line
  comment; unset in `forget` (`:526-529`); set to `{}` in `trace_drag_clear`.
* **`trace_drag_arm`** (`:4091`) — after it resolves `ti`, compute the moving set:
  read `selection_pairs $W`; if `[list $gi $ti]` is in it, `tdrag_pairs` is that
  whole list; otherwise `tdrag_pairs` is `[list [list $gi $ti]]`. Comment: D-41
  — a press on an unselected trace does not extend, collapse or clear the
  selection; and D-41's press-time timing, because the release is forwarded to C
  before `trace_drag_drop` and a no-travel release collapses the selection.
* **`drag_preview_arm_set {token pairs}`** — new, beside `drag_preview_arm`.
  Maps each MODEL pair through `node_index_of_trace` (landmine 34), drops the
  ones that answer -1 (a vec-less trace draws nothing), refuses when nothing
  survives, then issues ONE
  `xschem set graph_preview <gi0> <ni0> <shrink> <gi1> <ni1> …`.
  **`drag_preview_arm {token gi ti}` becomes a one-line wrapper over it** — its
  signature and its return contract are unchanged so `DN1` and `DG*` still pass.
* **`trace_drag_motion`** (`:4186`) — arm with `tdrag_pairs` instead of the single
  pair. Still armed **once**, at the threshold.
* **`move_traces_in_graphs {graphs pairs to_gi}`** — new, PURE, next to
  `move_trace_in_graphs`. Normalise (integers, in range, dedupe, ascending by
  `(gi, ti)`, **drop every pair whose `gi == to_gi`**), then fold
  `move_trace_in_graphs` with the per-source-graph offset:

```tcl
    set graphs [wviewer::move_trace_in_graphs $graphs $gi [expr {$ti - $done}] $to_gi]
```

  where `$done` counts the members already moved **out of that same graph**.
  Returns the graph list UNCHANGED on any refusal (a pure list op has no error
  channel — `move_traces` refuses loudly). Header comment must state the three
  properties the fold order buys: destination order = source order; the
  empty-destination blanking fires exactly once; the destination's selection
  grows by one appended node index per moved trace.
* **`move_traces {pairs to_gi ?token?}`** — new, THE mutation, modelled on
  `delete_items` (`:4786`) and `move_trace` (`:3357`):
  validate LOUDLY (`ciw_echo` + `{}`) → normalise → **nothing left to move ⇒
  return without mutating and without logging** → verified `switch_ctx` →
  `capture_live_graph_state` → **one** `push_undo` → `set_graphs
  [move_traces_in_graphs …]` → `set target($token) $to_gi` **in place** → **one**
  `regenerate` → **one** `log_action` carrying the **normalised** pairs and the
  explicit token. Returns the number of traces moved, or `{}`.
* **`trace_drag_drop`** (`:4205`) — after the three shipped refusals, compute the
  movable list (`tdrag_pairs` minus pairs already on `$to`) and dispatch:

```tcl
  if {[llength $movable] == 1 && [lindex $movable 0] eq [list $from $ti]} {
    catch {set r [wviewer::move_trace $from $ti $to $token]}      ;# shipped path
  } else {
    catch {set r [wviewer::move_traces $movable $to $token]}
  }
```

  Comment D-42: the singular path is a **replay contract** — `TD1`/`TD2`/`TD7`
  and every action log on disk name `wviewer::move_trace`.
* **`trace_drag_reset`** (`:4062`) — no change needed beyond clearing
  `tdrag_pairs` in `trace_drag_clear`. **Do not move the
  `drag_preview_clear`-before-`trace_drag_feedback` order** at `:4071`.

### 7. `tests/headless/test_wave_modes.tcl` — new `MV*` group, BOTH arms

Pure list math on literal dicts, no window, no `xschem` calls — the `M8` style.
⚠ `M9` is taken.

| id | asserts |
|---|---|
| MV1 | two pairs from ONE source arrive at the destination END in source order; the source keeps its others, in order |
| MV2 | the arrival ORDER is source order (`gi` then `ti`) with three distinguishable vecs. **SAB-9 kills this** |
| MV3 | pairs spanning TWO source strips all arrive; both sources correctly reduced |
| MV4 | a pair whose `gi == to_gi` stays exactly where it is (same index, same dict) while the others move in |
| MV5 | every moved trace dict is **byte-identical** to its source dict |
| MV6 | the SELECTION: each moved node joins the destination's set at its appended index; each source's remaining selection shifts past every hole; an unrelated destination selection survives. Assert the SET, never the count |
| MV7 | markers migrate per moved trace; survivors remap; no dangling `prev` |
| **MV8** | **the index-adjustment teeth:** moving model indices **0 and 2** of a 4-trace strip leaves the traces that were at **1 and 3**. **SAB-4 kills this, and only this** |
| MV9 | empty destination ⇒ `x1 x2 y1 y2` are `{}` afterwards, and the blanking happened once; non-empty destination ⇒ all four byte-identical. **SAB-3 kills this** |
| MV10 | a source carrying a **vec-less** trace: node indices are right, the vec-less trace is untouched and never moves (landmine 34) |
| MV11 | refusals: bad `gi`, bad `ti`, non-integer, empty pair list, `to_gi` out of range → the list is returned **unchanged** |
| MV12 | duplicate pairs are deduped (a repeated pair must not `lreplace` twice and take a neighbour) |

### 8. `tests/headless/test_wave_drag_preview.tcl` — extend `DV*`, new `DM*`

Read `GRAPH_MAX_PREVIEW_WAVES` out of `src/xschem.h` at run time (the
`az_define` idiom from `test_wave_axis_zoom.tcl`), never a frozen copy.

**`DV8`-`DV12` — the verb. BOTH arms.**

| id | asserts |
|---|---|
| **DV8** | `xschem set graph_preview 1 2 0.7 0 3 2 5` → `get graph_preview` still answers the HEAD `1 2 0.7` **byte-identically**, and `get graph_preview_set` answers `1 2 0 3 2 5`. **This is the compatibility leg; SAB-5 must LEAVE IT GREEN** |
| DV9 | `get graph_preview_set` is `""` when disarmed, and after each of the two disarm forms |
| DV10 | the three-argument form gives a one-element set (`get graph_preview_set` → `0 1`) — the single-trace case is the plural case with n=1 |
| DV11 | a set longer than `GRAPH_MAX_PREVIEW_WAVES` is truncated to the cap, does not error and does not corrupt the head |
| DV12 | a trailing odd argument (a `gi` with no `ni`) is ignored; head and count unaffected |

**`DM1`-`DM6` — the multi arm. DISPLAY (except DM6).**
Extend `fill_viewer` locally so strip 0 carries **three** drawn traces plus its
existing vec-less one, and strip 1 one — so a 2-of-3 selection is
non-contiguous. Use `dp_ev` with its increasing `-time` (two identical presses
close together become `<Double-Button-1>`, which the viewer `break`s).

| id | asserts |
|---|---|
| DM0 | staging teeth: the two selected node indices are **not adjacent** (e.g. 0 and 2), and both were really selected (`selected_waves`), or the leg FAILS loudly rather than comparing against `{}` |
| **DM1** | press on one of two selected traces + >3 px travel ⇒ `graph_preview_set` names **both** node indices, head first, and `graph_preview` still names the pressed one. **SAB-5 kills this** |
| **DM2** | a selection spanning strips 0 and 1 ⇒ the set carries pairs with **different `gi`**. **SAB-6 kills this** |
| **DM3** | with a selection live on strip 0, pressing an **unselected** trace arms exactly **one** pair, and it is the pressed one. **SAB-7 kills this** |
| DM4 | teardown clears the whole set: the drop, `strip_drag_cancel`, and a bare `trace_drag_reset` each leave `get graph_preview_set` empty |
| DM5 | `graph_trace_at` answers over a swept column are **identical** with a MULTI preview armed and without it (DG4 for N), with the teeth leg that the column really crosses a trace |
| **DM6** | **source level, BOTH arms:** in `src/draw.c`, `graph_preview_has(` appears exactly once as a definition and there is **no** bare `preview_gi ==` / `preview_wave ==` comparison anywhere. Count on CODE lines only, the `test_wave_legend.tcl` `LS5` / `test_wave_markers.tcl` `MS13` idiom |

### 9. `tests/headless/test_wave_trace_menu.tcl` — new `MM*` group, DISPLAY

The end-to-end gesture. Build a **THREE-strip** fixture in the group (a 2-strip
stack cannot discriminate "moved to the strip I dropped on" from "moved to the
other one"), each strip carrying an inert `sdid` key (the `test_wave_viewer.tcl`
`sdid` idiom) so *which strip is at index k* is witnessed independently of *which
trace is in it*. Select through the **shipped bindings** with `ts_click`
(`st 0x4` = Ctrl), never by writing the tokens. Spy `wviewer::log_action`.

| id | asserts |
|---|---|
| MM0 | fixture teeth: three strips, the selection is a **non-contiguous** 2-of-3 on strip 0, both really selected, strip ids `A B C` |
| **MM1** | press on one selected trace, drag to strip 2, release ⇒ **both** arrive at strip 2, in source order; strip 0 keeps its third; strip identities unchanged. **SAB-1 and SAB-9 kill this** |
| MM2 | the selection FOLLOWED: strip 2's `hilight_wave`/`sel_waves` name both appended node indices; strip 0's set no longer names them; witness **every** strip |
| **MM3** | exactly ONE `u` restores traces **and** selection, and `history_depth` moved by exactly 1. **SAB-2 kills the depth leg** |
| **MM4** | exactly ONE log line, `wviewer::move_traces {{…} {…}} 2 <token>`, with the **normalised** pairs; replaying it from the pre-move state reproduces the layout. **SAB-8 kills this** |
| MM5 | a selection spanning strips 0 and 1 dropped on strip 2: all arrive, both sources reduced correctly |
| MM6 | destination **is** a source: select on 0 and 1, drop on 1 ⇒ 1's own stay at their indices, 0's move in, ONE log line, and its pairs exclude the already-there ones |
| **MM7** | with a selection live, pressing an **unselected** trace moves only that trace and logs the **singular** `wviewer::move_trace` line. **SAB-1 must LEAVE THIS GREEN**; SAB-7 kills it |
| MM8 | a same-strip drop with a multi-selection: nothing moves, nothing logs, no undo point |
| MM9 | a sub-threshold press-release still does the shipped wave-bold collapse; nothing moved; nothing logged |
| MM10 | Escape mid-multi-drag: nothing moved, nothing logged, preview cleared, pointer restored, the drop frame gone |
| **MM11** | dropping onto an **empty** strip blanks its ranges to auto and `regenerate` re-fits: the destination's model `x1 x2 y1 y2` are `{}` and its live rect range differs from the frozen pre-drop values. **SAB-3 kills this** |
| MM12 | the destination became the target strip, and there is **no** separate `wviewer::set_target_strip` log line for it |
| MM13 | the buffer is still `readonly` and `modified 0` after the whole gesture |

Add a staging leg with teeth per group in the `TG0`/`AC1` style: if the pixel
scan came up empty, that must **FAIL loudly**, never silently compare `{}`.

### 10. Build and run

```sh
cd /home/qflow/dev/xschem/claude_1/xschem/src && make
```

Then, with `GUI_GATE=0` in the environment:

```sh
GUI_GATE=0 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_modes.tcl
GUI_GATE=0 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_drag_preview.tcl
GUI_GATE=0 ./src/xschem         --pipe -q --nolog --script tests/headless/test_wave_modes.tcl
GUI_GATE=0 ./src/xschem         --pipe -q --nolog --script tests/headless/test_wave_drag_preview.tcl
GUI_GATE=0 ./src/xschem         --pipe -q --nolog --script tests/headless/test_wave_trace_menu.tcl
GUI_GATE=0 ./src/xschem         --pipe -q --nolog --script tests/headless/test_wave_viewer.tcl
GUI_GATE=0 bash tests/headless/full_audit.sh
```

**Gates.**

* All four suites `ALL PASS`, with the counts **risen from 433 / 46 / 323 / 368**
  by exactly the number of legs you added — and
  **`test_wave_viewer.tcl` must stay at 368**: it is the single-trace regression
  witness and nothing in it should change (D-42).
* `full_audit.sh` must match the PLAN.md PREFLIGHT baseline:
  `SUMMARY: 239 pass  20 fail  1 crash/timeout  11 skip  (total 271)`,
  `WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)`, and the fails must be exactly the
  21-line list in PLAN.md (20 FAIL + `TIMEOUT test_key_graph_context`).
  **Any fail not on that list is yours until proven otherwise.**
* Known-flaky and NOT yours: `test_cadence_drag` (12/12 red on pristine),
  **`test_wave_trace_menu` TG9** (4-in-10 under WSLg — and this is a suite you
  are extending, so read its failure text before attributing), `test_ase_plot`
  P4/P6/P8 (1-2 in 10). **The check COUNT is the signal, not the verdict** —
  `test_ase_plot` prints `ALL PASS` at 30 checks when WSLg geometry fails and it
  skips P1-P7 (145 = a real run); `test_wave_clear_all` is 68 real vs 58 skipped.
  A whole-suite wipeout with `NORESULT`/connection errors is a WSLg Xwayland
  abort killing every X client — re-run before attributing it to your change.
* `test_wave_markers` is **already red at baseline** with exactly one failing leg
  (`MF1`). If it is still `1 FAILED` with the same leg, it is not yours.

### 11. Sabotage-verify

Run every row of decision doc §7 (SAB-1 … SAB-9). For each: apply, run the
suite, confirm it fails **exactly** its named target and nothing else, `git diff`
the file to confirm it holds nothing but the sabotage, `git checkout -- <file>`,
re-run clean. Record each result in the receipt.

Two cross-checks that matter more than the rest:

* **SAB-1 must kill `MM1`/`MM5` and LEAVE `MM7` green.** If it kills `MM7` too,
  `MM7` is not really driven from an unselected trace and D-41 is untested.
* **SAB-5 must kill `DM1`/`DM2` and LEAVE `DV8` green.** If `DV8` dies too, the
  verb leg is accidentally testing the Tcl arm instead of the C storage.

### 12. Docs

* **`doc/claude/specs/waveform_viewer_modes.md`** — new **§19 "Multi-trace drag
  to a strip (2026-08-01, issue 0192)"**, in §13's shape: §19.1 the gesture table
  (what arms, what the moving set is, the refusals), §19.2 the model operations
  (`selection_pairs`, `move_traces_in_graphs`, the fold and its index
  adjustment), §19.3 the one mutation and its ordering contract, §19.4 the
  singular/plural dispatch and why the shipped `move_trace` log line survives,
  §19.5 the shrink preview as a SET (the head/set/count storage, the one writer,
  the one predicate, the per-strip centre), §19.6 the tests. Add a row to
  **§15.1**'s ownership table ("LMB press-drag > 3 px, within 10 px of a
  **selected** trace → Tcl → the whole selection moves") and a cross-reference
  from §13.
* **`doc/claude/specs/waveform_viewer.md`** — in the "Mid-drag shrink preview"
  section, a short revision block: the arm is now a SET; the head keeps its
  meaning and `xschem get graph_preview` is unchanged; the new getter; the cap
  and its truncation rule; and that traces on different source strips shrink
  about **their own** strip's centre (D-50).
* **`doc/claude/code_analysis/waveform_subsystem_reference.md`** — a new
  **landmine 49**: *"a multi-object viewer gesture folds the PURE primitive and
  owes ONE of everything"* — the per-source-graph index adjustment (`ti - done(gi)`)
  that a naive loop gets wrong and that only a non-adjacent, multi-index fixture
  can see; one `push_undo`, one `regenerate`, one log line, with the **normalised**
  indices; the singular form kept because a shipped log line is a replay contract;
  and the head/set/count + one-writer + one-predicate storage shape reused from
  landmine 46. Update §8 (the viewer paragraph on trace drag), §9 (the verb list
  gains `graph_preview_set` and the extended `set graph_preview`), and §13 (the
  three suites' new groups).
* **`doc/claude/issues/0192-multi-trace-drag-to-strip.md`** — in the house style
  of `0189-dblclick-delta-marker-selects-pair.md`: symptom/ask, what was measured,
  the decision list pointer, the fix, the tests, the eyeball list.

### 13. Receipt

Write
`doc/claude/overnight_batch_2026_08_01/receipts/05_multi-trace-drag-to-strip.md`
in the shape of `04_axis-region-ctrl-wheel-zoom.md`: commit sha, files changed,
test counts before/after in both arms for all four suites, every non-baseline
audit fail with its attribution, docs updated, **the decision list copied from
decision doc §5 (the user reads these)**, the sabotage results, and the eyeball
list from decision doc §11 — naming `::wviewer_drag_shrink` explicitly as the
one-line tune, with its current value.

---

## COMMIT

Stage **exactly** this list — nothing else, no `git add -A`, no `git commit -a`:

```
src/xschem.h
src/draw.c
src/scheduler.c
src/actions.c
src/xinit.c
src/wave_viewer.tcl
tests/headless/test_wave_modes.tcl
tests/headless/test_wave_drag_preview.tcl
tests/headless/test_wave_trace_menu.tcl
doc/claude/specs/waveform_viewer_modes.md
doc/claude/specs/waveform_viewer.md
doc/claude/code_analysis/waveform_subsystem_reference.md
doc/claude/code_analysis/ovb01_05_multi_trace_drag_to_strip_decision.md
doc/claude/overnight_batch_2026_08_01/prompts/05_multi-trace-drag-to-strip.md
doc/claude/issues/0192-multi-trace-drag-to-strip.md
```

(The receipt is committed by the batch's final ledger commit, not by this one.)

Before committing, `git status` must show only these files plus the two
pre-existing dirty tracked files from the PLAN.md PREFLIGHT
(`doc/claude/suggestions/next_session_prompt_0165.md` and
`sky130A/.../tb_bandgap.state`) and the pre-existing untracked paths.

Commit message:

```
feat(0192): a trace drag carries the whole selection, and shrinks all of it

Press on a SELECTED trace and drag: every selected trace in the window moves to
the strip you drop on, in source order, and all of them wear the mid-drag shrink
on the way. Press on an unselected one and it is exactly today's gesture --
including today's log line, because wviewer::move_trace is a replay contract that
TD1/TD2/TD7 and every action log on disk already name.

Two shipped features joined rather than two new ones built:

  * the selection has been a SET since 0175 and the trace move has been a PURE
    list op since the 0728 drag, so the plural form is a FOLD over
    move_trace_in_graphs -- marker migration, the hilight_wave/sel_waves hand-off
    and the empty-destination range blanking all come along unchanged. The only
    new arithmetic is one term: each ti is adjusted by the number of traces
    already removed from ITS OWN source graph. Moving indices 0 and 1 cannot see
    that term; moving 0 and 2 of four can, which is what MV8 does;
  * the shrink preview has been shipped since viewer item 6 -- both axes, one rc
    knob (::wviewer_drag_shrink, 0.7), flags-bit-16 chrome. It becomes a SET the
    way the marker selection did in 0189: head scalars keep their exact meaning
    so `xschem get graph_preview` and all seven DV legs are byte-identical, the
    whole set is read through a NEW getter, one writer (graph_preview_arm) and
    one draw-side predicate (graph_preview_has) own it, and DM6 counts the
    comparison sites at source level because a bare one is invisible to any leg
    that drags a single trace.

One undo point, one regenerate and one log line per GESTURE, with the NORMALISED
pairs, so three traces are a single `u` and a replay reproduces exactly this run.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

---

## CONSTRAINTS

* **Do not change the shrink factor, the shrink maths or the knob.**
  `wviewer::drag_shrink`'s `0.7` was tuned by the user's own eyeball on
  2026-07-29; `draw_graph_points`' centre computation, its
  scale-before-clamp order and its X save/restore are all correct and are not
  yours (D-47).
* **Do not edit `move_trace`, `move_trace_in_graphs` or
  `move_trace_to_new_strip`.** Your fold calls the middle one; the other two are
  shipped contracts.
* **Do not change `xschem get graph_preview`'s output shape.** The set is read
  through the new getter. Seven shipped `DV*` legs rest on the old one.
* **Do not touch `graph_wave_at`, `graph_trace_at`, `graph_near_wave` or
  `GRAPH_TRACE_PICK_TOL`.** The pick already answers what the arm needs, and that
  tolerance is shared by four surfaces (landmine 33).
* **Do not touch `src/callback.c`.** No C gesture routing changes: the press and
  release paths, the wave-bold click arm, the GRAPHPAN latch and the marker/axis
  precedence are all unchanged by this item.
* **Do not make Ctrl+LMB arm a drag.** `strip_drag_press:2977` returns 0 on
  `state & 13` and that is what keeps Ctrl+click as the selection toggle.
* **Do not add a prop token for the preview.** It is transient chrome; a token
  would persist, paste and export (landmine 19, graph_markers.md §3.5).
* **Do not delete a strip that ends up empty** (D-51). Tidying is bare `e`.
* **Do not add a second `set_target_strip` log line** for the destination — it is
  set in place, an internal consequence of the one command (§12.7 / §13.3).
* **Do not fix anything else you notice.** Record it in the receipt. Two are
  already known and deliberately left: `find_closest_wave`'s open
  `extra_rawfile` defects, and the absence of a real `graph_preview_clear()`
  function (you fix only the *comment* that names it).
* If a claim in the ANCHORS table cannot be reproduced from source, that is a
  **finding to report**, not a blocker — say so and proceed from what source
  actually shows.
