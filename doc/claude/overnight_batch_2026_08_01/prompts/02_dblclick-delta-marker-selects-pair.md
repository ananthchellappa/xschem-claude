# OVB-02 — double-clicking a difference marker selects it AND its reference

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`. You are the
**implement** stage of overnight batch 2026-08-01 item **02**. The scout verdicted
**PROCEED** and re-verified every anchor below from source on **2026-08-01**, at
HEAD `be5d9b98` (item 01's commit).

The shape (decided — do **not** re-litigate; the reasoning is in the decision doc):
the marker selection becomes a **SET of at most `GRAPH_MARKER_MAX_SEL` numbers,
held in `xctx`**, with the existing `graph_marker_sel` kept as its **head**.
**It does NOT become a prop token** — marker selection has never been in the token
and must not be (`graph_markers.md` §3.5 / D9). A double-click on a marker calls
one new policy primitive, `graph_marker_select_pair()`, which selects that marker
and — only when it carries a delta block whose partner resolves — the one marker
its deltas are derived from. `Delete` then removes the whole set as ONE gesture
with ONE undo point.

## READ FIRST (in order)

1. `doc/claude/code_analysis/ovb01_02_dblclick_delta_marker_selects_pair_decision.md`
   — the decision doc. §2 is what exists today with anchors, §3 the design, §4
   **every resolved spec hole** (22 rows — that is your contract, do not re-decide
   them), §5 **four PLAN.md claims source refutes — read these before trusting the
   PLAN notes**, §6 the collision map, §7 the invariants, §8 the test plan.
2. `doc/claude/code_analysis/waveform_subsystem_reference.md` — the WIRING.md of
   waveforms. Landmines **6** (`graph_flags` ≠ `xRect.flags`), **11** (local
   `Graph_ctx`), **19** (a graph gesture does not dirty — markers deliberately do),
   **20** (the click-vs-drag anchor and the double-click poison), **36**
   (`graph_top` / the GRAPHPAN routing latch), **37** (`setup_graph_data` is not
   safe as a query), **41** (`graph_marker_notify` is `has_x`-gated ⇒ **nothing**
   about the viewer model or the viewer undo stack is observable under `--nogui`),
   **43** (the selection is a SET — the trace precedent), **45** (the creation gate,
   item 01).
3. `doc/claude/specs/graph_markers.md` — **§3.5 "What is *not* in the token"**
   (the load-bearing one), D9, §6.1 keys, §6.2 mouse + §6.2.1 the rigid drag,
   §6.6 read-only, §7.2/§7.3 the Button1 precedence tables, §9 the verb table,
   §11 the "Multi-marker selection" deferred entry this item retires.
4. `doc/claude/specs/waveform_viewer_modes.md` **§15.1** (the LMB/RMB ownership
   table — the `LMB double-click | anywhere (viewer) | Tcl | swallowed` row is the
   one you change) and **§16** (`Delete` deletes the SELECTION, issue 0176).
5. `doc/claude/overnight_batch_2026_08_01/PLAN.md` — the header (verdict alphabet,
   spec-hole policy, run policy, PREFLIGHT baseline, universal facts, test
   discipline) and the `## 02 dblclick-delta-marker-selects-pair` section.
6. `CLAUDE.md` — build, tests, conventions.
7. Templates you will copy from: `tests/headless/test_wave_legend.tcl:255-282`
   (**`LS5`** — the source-level "every draw-side comparison goes through the
   helper" leg, the exact idiom your `MS13` must mirror) and
   `tests/headless/test_wave_markers.tcl` (the suite you are extending; its `MK7`
   group is the "write the token by hand, no raw, no DISPLAY" pattern your new
   group copies).

## DISCIPLINE (non-negotiable)

* **Re-verify every anchor below from source before editing.** Line numbers drift
  and the PLAN notes for this item contain claims source refutes (decision doc
  §5). A claim you cannot reproduce is a finding for your summary, not a blocker.
* **A green suite does not prove the changed code ran.** Every named sabotage in
  the TEST section must fail **exactly** its stated kill list, be reverted with a
  targeted `git checkout -- <file>` **only after** `git diff` confirms that file
  holds nothing but the sabotage, and the clean re-run must be green.
* **C89**: declarations at block top, `/* */` comments only in `.c`/`.h`, no `//`.
  Allocations use `my_malloc`/`my_strdup`/`my_realloc` with the literal
  `_ALLOC_ID_` placeholder — never hand-numbered. (This item allocates nothing:
  the selection is a **fixed array**, never a pointer.)
* **New `xschem get` / verb keys are letter-dispatched.** `graph_marker_sel_set`
  starts with `g`, so it goes in the same `get` case as `graph_marker_sel`; the
  `graph_marker` verb already lives in `xschem_cmds_g`. A key filed in the wrong
  half is **silently unreachable** — no error.
* **`GUI_GATE=0`** in the environment for every suite run — overnight, nobody at
  the desk. Use `tests/headless/run_suites.sh`, never a bare `for` loop over
  `./src/xschem`.
* Git: **never** `git push`, `git reset --hard`, `git add -A`, `git commit -a`.
  Stage the explicit file list in the COMMIT step and nothing else. Do not touch
  the ~60 pre-existing untracked scratch/log paths, and leave the two pre-existing
  dirty tracked files alone
  (`doc/claude/suggestions/next_session_prompt_0165.md`,
  `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/ngspice_state1/tb_bandgap.state`).
* Scratch files go in the test's own `test_scratch` dir, never the repo root.

## ANCHORS (verified by the scout 2026-08-01 — **verify, do not trust**)

**Storage — the head today**

* `src/xschem.h:1690` `int graph_marker_sel;` — the selected marker NUMBER, -1 =
  none. `:1691` `graph_marker_selgraph` — the owning rect index, documented as a
  **hint** only. `:1683-1707` is the whole transient block.
* `src/xschem.h:449` `#define GRAPH_MARKER_TOL 8.0` — the anchor/label grab radius
  on a press; its comment block starts at `:436`. `:439` says `GRAPH_CLICK_TOL`
  (3.0) is **file-private to `callback.c`** and answers a different question.
* `src/xschem.h:434` `#define GRAPH_MAX_SEL_WAVES 64` and `:1145`
  `sel_wave[GRAPH_MAX_SEL_WAVES]` — the 0175 fixed-array precedent, for shape only.
* `src/xschem.h:1986-2007` — the marker extern block, where the new prototypes go.

**The four "is this marker selected" sites — all must go through the new predicate**

* `src/draw.c:6017` `selected = (m.num == xctx->graph_marker_sel);` inside
  `draw_graph_markers()` (`:5972`). Its `:6012-6016` comment explains why the
  comparison is by NUMBER only — **keep that reasoning, it is still true.**
* `src/draw.c:6495` inside `graph_marker_delete()` (`:6479`) — "the marker I just
  deleted was the selected one".
* `src/callback.c:635` inside `graph_marker_press()` (`:594`) — the
  `GRAPH_MARKER_MODE_RIGID` latch (§6.2.1: a text drag on a **selected** marker
  translates the whole marker).
* `src/callback.c:791` inside `graph_marker_release()` (`:763`) — the click
  select / deselect toggle.

**Reads that stay on the HEAD — confirm, then leave**

* `src/callback.c:613` — "is ANYTHING selected" (a press on empty space
  deselects, returns -1 so the caller repaints broadly). Becomes an `n_sel` test.
* `src/callback.c:769-770` `oldsel`/`oldgraph` — the repaint-scope hint.
* `src/callback.c:6935` `case XK_Delete:`, gate at `:6948-6963` — `rstate == 0 &&
  graph_marker_sel >= 0 && waves_selected(...)`, then `graph_marker_find(sel,&sgi)
  == graph_master`. **The gate stays on the head** (decision D-9).
* `src/scheduler.c:3951-3955` `xschem get graph_marker_sel`.
* `src/wave_viewer.tcl:2830` `wviewer::marker_selected {wp}` — reads the head,
  fail-closed to -1.

**The primitives you extend**

* `src/draw.c:6611` `int graph_marker_select(int num, int graph_idx)` — the only
  writer today. "Pure UI state: no token write, no undo, no modify." **No
  `log_action` — and none is added** (decision D-17).
* `src/draw.c:6479` `graph_marker_delete(int num)` — splits into a static
  `graph_marker_delete_1(num, push)`; `:6486` `graph_marker_ro_refuse()`, `:6488`
  the `push_undo`, `:6494` `graph_marker_clear_prev(num)`, `:6499-6501`
  `set_modify` + `graph_marker_notify` + the self-logged `delete %d` line.
* `src/draw.c:6546` `graph_marker_delete_selected()` — today a one-liner.
* `src/draw.c:6505` `graph_marker_delete_all()` — clears the selection at
  `:6534-6536`; must clear the SET.
* `src/draw.c:5607` `graph_marker_find(int num, int *graph_idx, GraphMarker *out)`
  — resolves a number window-wide. This is how `-pair` reads `prev`.
* `src/draw.c:6064` `graph_marker_at(i, px, py, tol, &part)` — the pixel hit test,
  `0` under `--nogui` (`:6081-6085`, no cairo ⇒ no measurable label box).

**The double-click seams**

* `src/xschem.tcl:13939` `bind $topwin <Double-Button-1> "xschem callback %W -3
  %x %y 0 %b 0 %s"` — where `-3` comes from, for every editor toplevel.
* `src/callback.c:153-162` — `waves_selected()` explicitly claims `event == -3`.
* `src/callback.c:1385-1393` — **the `-3` arm you edit.** `:1389` is the
  `graph_press_x = graph_press_y = -1e30` poison (issue 0152). `:1390`
  `edit_wave_attributes(1, i, gr)` (legend → wave dialog), `:1391`
  `graph_edit_properties` (`src/xschem.tcl:4249`, a **non-modal** `toplevel
  .graphdialog`; its `tkwait` is commented out).
* `src/callback.c:1219` `mkpress = ... graph_marker_press(i, gr, r)`, `:1224-1226`
  the second poison site. `:922-929` the release rung the marker arm owns, `:930`
  the wave-bold arm whose travel test the poison defeats.
* `src/wave_viewer.tcl:6495` `bind $wp <Double-Button-1> {break}` — *"D9: no graph
  props dlg"*, inside `strip_bindings` (`:6436`). `<Double-Button-1>` is MORE
  SPECIFIC than `:6470`'s `<ButtonPress-1>`, so the second press never reaches
  `strip_drag_press` or C; `:6488`'s `<ButtonRelease-1>` still fires for the
  trailing release.

**Verb surface**

* `src/scheduler.c:5131` the `xschem graph_marker` block; `:5111-5130` the usage
  comment block (update it); `:5142` the readonly exemption
  (`select`/`list`/`text` are NOT rejected — `-pair`/`-set` ride it, `delete
  -selected` does **not**); `:5177-5184` the `delete` sub-verb; `:5185-5190` the
  `select` sub-verb.
* `src/scheduler.c:3916-3921` the four fail-soft marker getters' banner; `:3927`
  `graph_marker_at`; `:3947` `graph_marker_drag`; `:3952` `graph_marker_sel` —
  the new `graph_marker_sel_set` getter goes beside it.

**Reset sites (the gesture-state class, `graph_markers.md` §3.5)**

* `src/actions.c:1915-1916` in `clear_drawing()` — with the comment explaining why
  a surviving selection latches onto the NEW document's M1.
* `src/xinit.c:668-669` in `alloc_xschem_data()`.

**Viewer**

* `src/wave_viewer.tcl:2818` `marker_grabbed`, `:2830` `marker_selected` — the
  context-switch + fail-closed pattern your new helpers copy.
* `:4837` `marker_graph_at`, `:2283` `strip_at_pixel`, `:468` `token_for_canvas`,
  `:915` `with_edit` (**not needed here** — select mutates nothing), `:3875`
  `plotbox_at`, `:5859` `over_graph`.
* `:4865` `delete_selection_at`, marker block at **`:4886-4891`** — the one-line
  change. `:4708` `delete_items` already takes a LIST of marker numbers, dedupes
  it (`:4771-4776`), filters to live records, and gives **one** undo point
  (`:4794-4795`) and one log line.
* `src/scheduler.c:9486` `xschem redraw` — the repaint the Tcl wrapper owes (the
  `delete_all_markers_at` precedent, `graph_markers.md` §6.1.1).

**Test-side anchors**

* `tests/headless/test_wave_markers.tcl:327-368` `check` / `check_true` / `note` /
  `stall` / `pcall` / `pexpr`; `:423` `mk_reset`, `:431` `mk_graph`, `:436`
  `mk_rec`, `:440` `mk_nums`, `:446` `mk_field`, `:455` `mk_close`, `:461`
  `mk_props_markers` — **all top level, available in BOTH arms.**
* `:855` the `MK12` group, `:883` the `MR*` header — **the new `MS*` group goes
  between them.**
* `:4016` `mk_list`, `:4046` `mk_wadd`, `:4051` `mk_wdel`, `:4073` `mk_parts`,
  `:4107` `mk_bold`, `:3849` `wb_ev` (⚠ it bumps `-time` by **1000 ms per event**,
  precisely so two presses are never collapsed into a Double — your double-click
  helper must stamp the second press within Tk's 500 ms / 5 px window instead),
  `:4139` `mx_ready`, `:4205` `mx_arm`, `:4523` the `MX5` select legs.
* `:5270-5271` **`mk_expect_x 868` / `mk_expect_nogui 371`** — the `MZ1` coverage
  self-check. **Update both or MZ1 fails.** `:5265-5269` says so in the file.
* `tests/headless/test_wave_legend.tcl:264-282` — the `LS5` source-level leg to
  mirror; `tests/headless/test_wave_snap.tcl:40` `count_code` (count matches on
  CODE lines only — a comment explaining what the code does *not* do contains the
  string being counted).

## DO — in this order

### 1. Baseline first, before any edit

```sh
cd /home/qflow/dev/xschem/claude_1/xschem
cd src && make && cd ..
GUI_GATE=0 tests/headless/run_suites.sh --nogui test_wave_markers
GUI_GATE=0 tests/headless/run_suites.sh         test_wave_markers
```

Record both check counts and both verdicts. PLAN.md's PREFLIGHT says this suite is
red at `MF1` with `1 FAILED (802 passed)` — that measurement predates item 01,
which added the whole `MP*` group; item 01's scout measured **328** (`--nogui`) and
**803** (DISPLAY) on `e516cc85` and reported MF1 **green** that day. So measure,
don't assume. Your gate at the end is:

> 0 or 1 FAILED; **any** failing leg is exactly `MF1`; and the pass count rose by
> exactly the number of legs I added, in **both** arms.

A second red leg, or a pass count that did not rise, is yours.

### 2. `src/xschem.h` — storage

Add beside `GRAPH_MARKER_TOL`:

```c
/* The marker SELECTION is a SET (issue 0189). Bound it in the header because
 * draw.c holds the array and callback.c copies it. 8 is headroom: the
 * double-click builds one or two, and the cap exists so the field can be a
 * FIXED array -- xctx is reset, never freed, at clear_drawing() and
 * alloc_xschem_data(), and a pointer would add a free path for nothing. */
#define GRAPH_MARKER_MAX_SEL 8
```

and beside `graph_marker_sel`:

```c
  int graph_marker_sel_set[GRAPH_MARKER_MAX_SEL]; /* the WHOLE selection, marker
                              * NUMBERS, HEAD FIRST (selection order, not sorted).
                              * NEVER a prop token: selection is UI state and dies
                              * with the document (graph_markers.md 3.5). */
  int graph_marker_n_sel;   /* 0 <=> graph_marker_sel == -1 */
```

Add the three externs to the marker block (`:1986-2007`). **Nothing here is
`MIRRORED IN TCL`** — Tcl reads the list from the getter and never needs the cap.

### 3. `src/draw.c` — one trio, one policy, one delete split

Beside `graph_marker_select()` (`:6611`):

* `int graph_marker_is_selected(int num)` — `num <= 0` → 0; else a scan of
  `sel_set[0..n_sel-1]`. **The only** "is this marker selected" test in the tree.
* `int graph_marker_select_set(const int *nums, int n, int graph_idx)` — the only
  writer. Drops `<= 0`, dedupes, caps at `GRAPH_MARKER_MAX_SEL`, then
  `graph_marker_sel = n_sel ? sel_set[0] : -1` and `selgraph = n_sel ? graph_idx :
  -1`. Returns the head. Writes **no token, no undo point, no modify flag.**
* `graph_marker_select(num, gi)` becomes a one-line wrapper
  (`num < 0` → clear, else `select_set(&num, 1, gi)`), so its contract and its
  return value are byte-identical to today.
* `int graph_marker_select_pair(int num, int graph_idx)` — the policy: resolve
  `num` with `graph_marker_find`; if that fails, select it alone (permissive, like
  the shipped verb). Otherwise `nums[0] = num`, and add `m.prev` **only** when
  `m.prev >= 1` and `graph_marker_find(m.prev, NULL, NULL)` succeeds. **Immediate
  pair only — never walk the chain.** Use the resolved owner as `graph_idx`.
* `static void graph_marker_sel_drop(int num)` — rebuild the set without `num`.

Then:

* `:6017` → `selected = graph_marker_is_selected(m.num);` **Keep the `:6012-6016`
  comment** (numbering is window-wide, `selgraph` is a hint) — it is still the
  reason the renderer can show a cross-strip pair at all; extend it with one line
  saying the test is now a set membership.
* `:6479` `graph_marker_delete()` → `static int graph_marker_delete_1(int num, int
  push)`, with `if(push && !xctx->readonly) xctx->push_undo();` at `:6488`;
  `:6495` becomes `graph_marker_sel_drop(num);`. The public
  `graph_marker_delete(num)` is `return graph_marker_delete_1(num, 1);`.
* `:6534-6536` in `delete_all` → clear the whole set.
* `:6546` `graph_marker_delete_selected()` → refuse read-only **once**
  (`graph_marker_ro_refuse()`), copy the set into a local array, push undo **once**
  (`if(!xctx->readonly) xctx->push_undo();`), then `graph_marker_delete_1(nums[k],
  0)` per member, and return the count. Each member still self-logs its own
  `xschem graph_marker delete <n>` line, so a replay reproduces the deletions.

⚠ Copy the set **before** the loop: `graph_marker_sel_drop` mutates it as records
go.

### 4. `src/callback.c` — the gesture

* `:635` → `if(part == 2 && graph_marker_is_selected(num))`.
* `:791` → the toggle with the collapse rule (decision D-15):
  ```c
  /* A plain click on the ALREADY-SELECTED marker deselects, as it always has --
   * but only when it is the whole selection. With a pair selected the click is
   * disambiguating, so it COLLAPSES to the one clicked (the issue-0174 D3 rule
   * for traces), and a second click then still deselects. */
  if(graph_marker_is_selected(num) && xctx->graph_marker_n_sel == 1)
    graph_marker_select(-1, -1);
  else graph_marker_select(num, gi);
  ```
* `:613` → `if(xctx->graph_marker_n_sel > 0)`.
* `:1385-1393` the `-3` arm — **keep the poison line and its comment**, then test
  the marker first:
  ```c
    else if(event == -3 && button == Button1) {
      int mnum, mpart = 0;
      /* issue 0152: ... (the existing comment, unchanged) */
      xctx->graph_press_x = xctx->graph_press_y = -1e30;
      /* A DOUBLE-CLICK ON A MARKER selects it and, when it carries a delta
       * block, the marker its deltas are derived from (issue 0189). It must be
       * tested BEFORE the wave dialog: a marker ANCHOR sits on a trace by
       * construction and a callout is clamped inside the plot box, so this
       * double-click otherwise reaches graph_edit_properties. need_all_redraw
       * because the partner may live on a different strip -- the selection is by
       * NUMBER and is deliberately not scoped to one rect. */
      mnum = graph_marker_at(i, (double)mx, (double)my, GRAPH_MARKER_TOL, &mpart);
      if(mnum > 0 && mpart) {
        graph_marker_select_pair(mnum, i);
        need_all_redraw = 1;
      }
      else if(!edit_wave_attributes(1, i, gr)) {
        tclvareval("graph_edit_properties ", my_itoa(i), NULL);
      }
    }
  ```
  Declarations at block top — C89.

Do **not** touch the `Delete` gate at `:6948-6963` (it stays on the head, D-9),
the GRAPHPAN latch, `graph_marker_drag`/`dragmode`, or the wave-bold arm.

### 5. `src/scheduler.c` — two verb forms, one getter

* beside `:3952`, a fifth fail-soft getter:
  ```
  xschem get graph_marker_sel_set -> "2 1" | ""   (head first, space separated)
  ```
  Same `get` case `'g'`. Never an error; empty string when nothing is selected.
* `:5185-5190` the `select` sub-verb gains `-pair <num> [<gi>]` and
  `-set <n1> [<n2> ...]`. **All forms keep returning the head**
  (`-none` still answers `-1`) — decision D-16, and ~27 shipped assertions depend
  on it.
* `:5177-5184` the `delete` sub-verb gains `-selected` → the count. It is
  readonly-**rejected** by `:5142` like every other `delete` form; `select` in all
  its forms is exempt, which is what lets the read-only viewer pair-select without
  a `with_edit` bracket.
* Update the usage strings and the `:5111-5130` comment block.

### 6. `src/actions.c` + `src/xinit.c` — the resets

Add `xctx->graph_marker_n_sel = 0;` next to `graph_marker_sel = -1;` at
`actions.c:1915` and `xinit.c:668`. This is the gesture-state reset class
(`graph_markers.md` §3.5); a surviving set latches onto the new document exactly
as a surviving head does.

### 7. `src/wave_viewer.tcl` — the viewer seam

* beside `marker_selected` (`:2830`), add `wviewer::marker_selection {wp}` — the
  whole set as a list, same context switch, fail-closed to `{}`.
* add `wviewer::marker_dblclick_at {W px py}` — resolve the token from `%W` (never
  the current ctx, the `clear_all_at` rule); `strip_at_pixel` → `gi`, `-1` → 0;
  `xschem get graph_marker_at $gi $px $py` inside a `catch`; on a `<num> anchor|
  label` answer, `xschem graph_marker select -pair $num $gi` then `xschem redraw`,
  return 1; else 0. **No `with_edit`** — select writes no token, pushes no undo,
  sets no modify flag and is exempt from the scheduler's readonly reject. Say so
  in the comment, because every neighbouring marker seam *does* bracket.
* `:6495` → `bind $wp <Double-Button-1> {wviewer::marker_dblclick_at %W %x %y; break}`.
  **The `break` is unconditional**: D9 (no graph-props dialog in the viewer) must
  survive for every non-marker double-click. Keep the `;# D9:` comment, extended.
* `:4886-4891` in `delete_selection_at` — keep the head-scoped gate, and when it
  passes set `marks` to `[wviewer::marker_selection $W]` (the whole set) instead of
  the single number. `delete_items` already dedupes, filters to live numbers and
  gives one undo point and one log line.

### 8. Tests — `tests/headless/test_wave_markers.tcl`

#### 8a. New `MS*` group — BOTH arms, no raw, no DISPLAY (insert at `:882`)

MK-style: `mk_reset`, two `mk_graph` rects, records written straight into the
`markers` token with `xschem setprop rect 2 <gi> markers` + `mk_rec`, exactly as
`MK7` (`:703`) does. Tear down with `mk_reset` + `xschem set_modify 0` so the
`MR*` fixture below starts as it does today.

| leg | asserts |
|---|---|
| `MS0` | staging: two graph rects; `graph_marker list` sees the hand-written records with the intended `prev` links (FAIL, never skip, if the staging did not take) |
| `MS1` | `select -pair 2` (M2.prev = 1) → `get graph_marker_sel` = 2 **and** `get graph_marker_sel_set` = `2 1` (head first, NOT sorted) |
| `MS2` | `select -pair 1` (a plain marker) → set = `1` |
| `MS3` | `select 2` → set = `2`; `select -none` → sel = `-1`, set = `{}`; and the **return values** of those two calls are still `2` and `-1` |
| `MS4` | orphan: `graph_marker delete 1` sweeps M2's `prev` to 0, then `select -pair 2` → set = `2` |
| `MS4b` | a hand-written **dangling** `prev` (names a number no record carries) → `select -pair` → set = the one number, no error, no message |
| `MS5` | chain M1←M2←M3: `select -pair 3` → set = `3 2`, and `1` is **not** in it |
| `MS6` | direction: `select -pair 1` while M2.prev = 1 → set = `1` |
| `MS7` | cross-strip: M1 on rect 0, M2(prev 1) on rect 1 → `select -pair 2` → set = `2 1`; `graph_marker list 0` / `list 1` witness that they are on different rects |
| `MS8` | **no token, ever**: `getprop rect 2 0 markers`, `getprop rect 2 1 markers` and both rects' whole prop strings are byte-identical before and after a two-marker `select -pair`; `xschem get modified` unchanged |
| `MS9` | `delete -selected` on the cross-strip pair → 2, both records gone from **both** rects, `sel` = -1, set = `{}` |
| `MS10` | **one undo point**: a single `xschem undo` after `MS9` restores **both** records. This is the leg that dies if undo is pushed per delete |
| `MS11` | `select -set 2 2 1` → set = `2 1` (dedupe, order preserved); a nonexistent number is accepted (the shipped verb is permissive) |
| `MS12` | `delete -selected` with nothing selected → 0, nothing deleted |
| `MS13` | **the `LS5` leg.** Read `src/draw.c` and `src/callback.c`, count on CODE lines only (`count_code` from `test_wave_snap.tcl:40`): `draw_graph_markers()` contains **no** `graph_marker_sel` and **does** contain `graph_marker_is_selected(`; the rigid latch and the click toggle likewise; and the only surviving bare `graph_marker_sel` reads are the sanctioned head readers named in the decision doc §2.3 |
| `MS14` | `xschem set readonly 1` → `select -pair` still works (pure UI state) while `delete -selected` raises (`catch` non-zero); then `readonly 0` |

#### 8b. Display legs

**Viewer**, after `MX5` (`:4523`), inside the existing `has_x` block. Write a
double-click helper: `wb_ev` (`:3849`) bumps `-time` by 1000 ms per event, so it
can never produce a `<Double-Button-1>`; stamp the second press within **500 ms
and 5 px** of the first (Tk's `NEARBY_MS` / `NEARBY_PIXELS`) and `update` between.
Replay the whole sequence: press, release, second press, release.

* `MS-X1a` — after the FIRST release: `sel` = the delta marker, set = that one
  number (the ordinary single-select still happens).
* `MS-X1b` — after the double: set = `<delta> <reference>`.
* `MS-X1c` — `mk_bold` unchanged across the whole gesture (the trailing release
  did **not** wave-bold; the first press's `-1e30` poison is what prevents it).
* `MS-X1d` — `winfo exists .graphdialog` is 0 (D9 intact).
* `MS-X1e` — the viewer buffer is still `modified 0` / `readonly 1`, and
  `llength $::mxlog` did not grow.
* `MS-X1f` — a second double-click leaves the set at `<delta> <reference>` (it
  SETS; it never toggles).
* `MS-X2` — double-click on empty plot body: set = `{}`, no `.graphdialog`.
* `MS-X3` — double-click a plain marker: set = that one number.
* `MS-X4` — pair selected, pointer over the head's strip, a real `Delete`
  keystroke (`send_key`, never a bare `event generate`) removes **both**;
  `wviewer::history_depth` rose by exactly 1 and one `u` brings both back.

**On-canvas graph**, in the `MF*` display half after `MP21`/`MP22`:

* `MS-X5` — spy the dialog (`rename graph_edit_properties __ms_saved; proc
  graph_edit_properties {i} {set ::ms_dlg 1}`, restored in the same block). Place a
  marker on the embedded graph, scan its anchor pixel with `xschem get
  graph_marker_at`, then `xschem callback .drw -3 <px> <py> 0 1 0 0` → the pair is
  selected **and** `::ms_dlg` was never set. Control: the same `-3` at an empty
  plot-box pixel sets `::ms_dlg` exactly once and selects nothing.

#### 8c. `MZ1`

Update `mk_expect_x` and `mk_expect_nogui` (`:5270-5271`) to the measured new
counts. The file's own `:5265-5269` comment says this constant is maintained by
hand on purpose.

### 9. Build, sabotage-verify, run

```sh
cd src && make && cd ..
GUI_GATE=0 tests/headless/run_suites.sh --nogui test_wave_markers
GUI_GATE=0 tests/headless/run_suites.sh         test_wave_markers
```

Then each sabotage in turn — apply, rebuild, run, confirm the kill list
**exactly**, `git diff <file>` to confirm it holds nothing but the sabotage,
`git checkout -- <file>`, rebuild, confirm green again:

| # | sabotage | must kill | must stay green |
|---|---|---|---|
| **SAB-1** | `graph_marker_select_pair` ignores `prev` (selects the clicked number alone) | `MS1`, `MS5`, `MS7`, the pair halves of `MS9`/`MS10`, `MS-X1b`, `MS-X4` | `MS2`, `MS3`, `MS4`, `MS4b`, `MS6`, `MS8`, `MS11`–`MS14`, `MS-X2`, `MS-X3` |
| **SAB-2** | restore ONE bare comparison in `draw_graph_markers` (`m.num == xctx->graph_marker_sel`) | `MS13` **only** | everything else |
| **SAB-3** | `graph_marker_delete_selected` deletes only the head | `MS9`, `MS-X4` | `MS1`–`MS8`, `MS11`–`MS14` |
| **SAB-4** | `graph_marker_select_set` writes a `sel_markers=` token onto the rect | `MS8` **only** | everything else — this is the leg that carries the "no token, ever" decision |
| **SAB-5** | push undo per delete instead of once in `graph_marker_delete_selected` | `MS10` **only** | `MS9` and everything else |

If a sabotage kills more or fewer legs than its list, **the leg is wrong, not the
sabotage** — fix the leg and re-run all five.

Then the neighbouring suites that touch the marker selection or the viewer's
button seams:

```sh
GUI_GATE=0 tests/headless/run_suites.sh test_wave_viewer test_wave_modes \
                                        test_wave_legend test_wave_trace_menu \
                                        test_wave_clear_all
```

Finally the wider audit (it is the batch's contract, not optional):

```sh
GUI_GATE=0 bash tests/headless/full_audit.sh
```

Compare against the PLAN.md PREFLIGHT baseline —
`SUMMARY: 239 pass  20 fail  1 crash/timeout  11 skip  (total 271)`,
`WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)` — and the verbatim 20-name FAIL list
plus `TIMEOUT | test_key_graph_context`. **Any fail not on that list is yours.**
Known-flaky and not yours: `test_cadence_drag` (12/12 red on pristine),
`test_wave_trace_menu` TG9 (4-in-10 under WSLg), `test_ase_plot` P4/P6/P8 — and
for the last two the **check COUNT is the signal, not the verdict** (145 = a real
`test_ase_plot` run, 30 = a WSLg geometry skip that still prints `ALL PASS`). A
whole-suite wipeout with `NORESULT`/connection errors is a WSLg Xwayland abort —
re-run before attributing it to your change.

### 10. Docs

* `doc/claude/specs/graph_markers.md`
  * **D9** — rewrite: the selection is a **SET of marker numbers held in `xctx`**,
    head first, `graph_marker_sel` is the head and keeps its meaning, and it is
    **still not in the token**. Add **D13**: a double-click on a marker selects it
    and, for a difference marker, the immediate partner its deltas are derived
    from — one direction, never transitive.
  * **§3.5** — extend "What is *not* in the token" with the set, and add
    `graph_marker_sel_set`/`n_sel` to the transient inventory and to the
    gesture-state reset class.
  * **§6.1** — the `Delete` row: it removes the whole selection, one undo point.
  * **§6.2** — a new mouse row for the double-click, and the collapse rule for a
    plain click on a member of a multi-selection (D-15).
  * **§7.2 / §7.3** — the `-3` rung in the on-canvas precedence table, and the
    viewer's `<Double-Button-1>` row (which used to read "Double-click is
    `{break}` in the viewer, so `-3` never reaches C there").
  * **§9 / the verb table** — `select -pair` / `select -set`, `delete -selected`,
    `xschem get graph_marker_sel_set`, and the statement that **every `select`
    form still returns the head**.
  * **§11** — move "Multi-marker selection" out of *Deferred* into the shipped
    ledger with the scope it actually got (pair-only; no rubber band), and record
    that the verb result shapes were deliberately left unchanged.
* `doc/claude/specs/waveform_viewer_modes.md` **§15.1** — the
  `LMB double-click | anywhere (viewer) | Tcl | swallowed ({break}, D9)` row
  becomes two rows: on a marker → the pair select (C policy, Tcl seam);
  everywhere else → still swallowed. Add a sixth "easy to get wrong" rule: the
  double-click SETS the selection and never toggles.
* `doc/claude/code_analysis/waveform_subsystem_reference.md`
  * §5, the `waves_callback` bullet — the `-3` arm now tests for a marker first.
  * §9, the marker verb table — the three new forms and the new getter.
  * **new landmine 46**, three reusable lessons: (a) *the marker selection is a
    SET and every "is this one selected" test goes through
    `graph_marker_is_selected()`* — four sites, and a missed one renders a
    selected marker unselected with no leg able to see it; (b) *it is deliberately
    NOT a prop token, unlike the 0175 trace selection* — the head it extends lives
    in `xctx`, not on the rect, so "mirror 0175 exactly" is the wrong instinct
    here; (c) *a multi-object delete owes ONE undo point* — split the primitive
    into a `push`/`no-push` pair rather than calling the public form in a loop.
* `doc/claude/issues/0189-dblclick-delta-marker-selects-pair.md` — new, house
  shape (`# 0189 — …`, `**Status:** FIXED (2026-08-01)`,
  `**Branch:** fluid-editing`, the user's request quoted verbatim, what existed
  before, the decisions that mattered — no token, immediate pair only, one undo
  point, D9 preserved — and the legs that defend each). **Verify 0189 is still
  free** (`ls doc/claude/issues/`) before writing. Do **not** edit
  `doc/claude/issues/status.md` — it is an explicit point-in-time snapshot.

### 11. COMMIT

Stage exactly this list — nothing else, no `-A`, no `-a`:

```sh
git add src/xschem.h src/draw.c src/callback.c src/scheduler.c \
        src/actions.c src/xinit.c src/wave_viewer.tcl \
        tests/headless/test_wave_markers.tcl \
        doc/claude/specs/graph_markers.md \
        doc/claude/specs/waveform_viewer_modes.md \
        doc/claude/code_analysis/waveform_subsystem_reference.md \
        doc/claude/code_analysis/ovb01_02_dblclick_delta_marker_selects_pair_decision.md \
        doc/claude/overnight_batch_2026_08_01/prompts/02_dblclick-delta-marker-selects-pair.md \
        doc/claude/issues/0189-dblclick-delta-marker-selects-pair.md
git status --short          # confirm ONLY the two pre-existing dirty tracked files remain
```

Message:

```
feat(0189): double-clicking a difference marker selects it and its reference

A `d` marker reads out Dx, Dy and a slope against a partner, but the
partner was invisible to every gesture: `graph_marker_sel` held ONE
number, so the pair could not be selected, moved over or deleted
together.

The selection becomes a SET -- a fixed array in xctx with
graph_marker_sel kept as its HEAD, so `xschem get graph_marker_sel`,
`graph_marker select`'s return value and wviewer::marker_selected are
byte-for-byte unchanged. It is deliberately NOT a prop token: marker
selection is UI state that dies with the document (graph_markers.md
3.5), unlike the issue-0175 trace selection whose head token it would
otherwise have mirrored.

A double-click asks graph_marker_select_pair(), which adds the `prev`
partner only when it resolves -- the immediate pair, never the chain,
and never the reverse direction. Delete then removes the whole set as
one gesture with ONE undo point (graph_marker_delete split into a
push/no-push pair), on both the C key path and the viewer's
delete_items path.

Every draw-side and gesture-side "is this marker selected" test now goes
through graph_marker_is_selected(); a source-level leg asserts no bare
comparison survived. The viewer's <Double-Button-1> still `break`s
unconditionally, so D9 -- no graph-properties dialog in a read-only
viewer -- holds for every non-marker double-click.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

## CONSTRAINTS

* **Do not put the selection in a prop token, at any set size.** That is decision
  D-1 and it overrides PLAN.md Q1 (decision doc §5.1). `SAB-4` exists to prove it.
* **Do not change `graph_marker_select`'s return value, `xschem get
  graph_marker_sel`, or `wviewer::marker_selected`.** Every `select` form returns
  the head; `-none` still answers `-1`. ~27 shipped assertions rest on this.
* **Do not add a `log_action` to any selection path** (D-17). Trace selection does
  not log either (`waveform_viewer_modes.md` §15); the replay-critical operations
  already name explicit numbers.
* **Do not wrap the viewer double-click in `with_edit`.** `select` mutates
  nothing and is exempt at `scheduler.c:5142`. Adding the bracket would push a
  pointless context switch plus four state writes onto a click — and hide the fact
  that this path is not a mutation.
* **Do not drop the `break` from `<Double-Button-1>`** and do not forward `-3` to
  C from the viewer. A Tcl/C hit-test disagreement would open `.graphdialog` over
  a read-only viewer — the exact fall-through class issue 0176 closed for
  `Delete`.
* **Do not touch** `GRAPH_TRACE_PICK_TOL`, `GRAPH_CLICK_TOL`, `GRAPH_MARKER_TOL`,
  the GRAPHPAN latch, `graph_marker_drag`/`dragmode`, the wave-bold arm, or the
  `-1e30` poison sites. The poison is what stops the trailing release of a
  double-click from bolding, **today**; `MS-X1c` is its regression witness.
* **Do not change the `Delete` strip-scope gate** — it stays on the head (D-9).
* **No new rendering.** Both members get exactly the cue one selected marker has
  always had (the `waveform_viewer_modes.md` §15.4 rule: no separate cue for the
  head). If you find yourself drawing something new, stop.
* **Do not bump `XSCHEM_FILE_VERSION`.** No token, grammar or file-format change —
  and confirm it by `MS8`.
* **Do not unlock rubber-band marker selection, Ctrl+click on markers, chained /
  reverse delta selection, or digital-strip markers.** All out of scope.
* Do not "re-fix" pre-existing defects you notice (`MF1`'s load sensitivity,
  `find_closest_wave`'s two open defects, `graph_coord`'s missing landmine-37
  bracket, the viewer double-click on empty body still wave-bolding through the
  trailing release). Record them in your summary instead.
