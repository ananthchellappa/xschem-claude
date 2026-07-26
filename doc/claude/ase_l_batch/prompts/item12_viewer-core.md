# Item 12 — viewer-core (Round 3, Waveform Viewer working core)

You are the IMPLEMENTER. Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch
`fluid-editing`. Execute this prompt end-to-end: code, tests, sabotage-verify,
ONE commit with the explicit file list at the bottom. Work from repo root.

Authoritative contract: `doc/claude/specs/waveform_viewer.md` (READ FULL —
esp. the Architecture "Model" paragraph and the v1 scope lock: analog core;
DEFER digital lanes / sweep selector / backannotate). Parent spec:
`doc/claude/specs/ase_l.md`. Runbook: `doc/claude/ase_l_batch/RUNBOOK.md`.
Context: item 11 landed the window shell (`cd332719` + fixers `2c3ac80d`
bind-sweep, `0a90b9db` toolbar-strip) — READ `receipts/11_viewer-window.md`
and `src/wave_viewer.tcl` FIRST.

This item = the viewer's WORKING CORE: trace/graph model, live Graph menu
(Add Graph / Add Trace… / Delete… / Axes…), live Cursors menu (A/B + readout
bar), live View>Fit, expression waves. ASE plumbing (Direct Plot, Plot
checkboxes, `~` button, automatic raw wiring) is item 13; persistence is
item 14 — do NOT touch the state dict or ase.tcl.

**This item is PURE TCL + tests. No C changes. No rebuild needed.**

## Scout-verified anchors (2026-07-21; trust these, both the item detail and
## some spec lines had drifted or were wrong)

### ERRATA in the item detail (verified against source — follow THIS)

- **"flags bits 128/256" is WRONG for Cursor A/B.** `xctx->graph_flags`
  legend (callback.c:528-539): bit 2 = draw x-cursor1 (A), bit 4 = draw
  x-cursor2 (B), 16/32 = move them; **128/256 are the HORIZONTAL y-cursors**
  (`draw_hcursor` draw.c:3783, `draw_hcursor_difference` :3810, drawn at
  :4935-4939 — and NOT drawn from `draw()`, only from waves_callback
  events). The A/B cursors this item ships are the x-cursors: drawn at
  draw.c:4928-4933 via `draw_cursor` (:3720) / `draw_cursor_difference`
  (:3745); positions resolved at draw.c:4563-4583 (rect-private `cursor1_x`
  attr when `r->flags & 4`, else `xctx->graph_cursor1_x/2_x` —
  xschem.h:1474). Plain `xschem redraw` draws them: `draw()` calls
  `draw_graph_all((xctx->graph_flags & (2|4)) + 8)` at draw.c:5950.
- **"per eval_expr.y" is WRONG.** `xschem raw add <name> <expr>` evaluates
  through `plot_raw_custom_data` (save.c:1821) — the space-separated RPN
  engine. eval_expr.y (`xschem eval_expr`) is the scalar attribute
  evaluator, unrelated to raw vectors. There is NO `db()/mag()/ph()`
  function in the RPN table; dB is `db20()`, and for AC data mag/ph/re/im
  exist as separate raw VARIABLES named `ph(v(x))`/`re(v(x))`/`im(v(x))`
  (save.c:796-821, complex read save.c:541-560).
- **Item-10 helper real name**: `ase::ui::bind_dialog_esc`
  (src/ase_window.tcl:837), not `ase::bind_dialog_esc`. Reached by
  construction through `ase::ui::dialog_buttons` (:860).

### `xschem raw` API (dispatch scheduler.c:8517-8734; spec's 8370 drifted)

- `raw read <file> <type>` :8529 → 1 ok. `raw vars` :8690 (count),
  `raw list` :8692 (newline-joined names), `raw points [dset]` :8678,
  `raw datasets` :8676, `raw sim_type` :8688, `raw rawfile` :8686.
- `raw value <node> <point> [dset]` :8577 — value at point;
  **`<point>` = empty string → falls back to `raw->cursor_b_val[idx]`**
  (:8592-8595), i.e. the engine-interpolated value at cursor B (see below).
- `raw pos_at <node> <value> [dset] [from] [to]` :8627 → `raw_get_pos`
  save.c:1639: binary search on a monotonic vector, returns the position
  index (floor-side), -1 when out of range.
- `raw index <node>` :8604 → `get_raw_index` save.c:1677: exact /
  case-folded / `v(<node>)` wrapping only — it does NOT map `i(v1)` to
  ngspice's `v1#branch`. **Tests must pick trace vars verbatim from
  `xschem raw list`, never assume `i(v1)` is a vector name.**
- `raw add <name> <expr> [sweepvar]` :8646 → `raw_add_vector` save.c:971:
  returns 1 only when `<name>` is NEW (0 = already existed; expr still
  re-evaluated). **A bad expression is NOT reported**: the -1 from
  `plot_raw_custom_data` is discarded (save.c:992) and the vector is left
  uninitialized — hence decision D4 (Tcl pre-validation).
- All `raw` subcommands THROW "No raw file loaded" when nothing is loaded
  (guard with catch). Raw state is PER-CONTEXT (`xctx->raw`) — always query
  inside the viewer ctx (`wviewer::in_ctx` / after `new_schematic switch`).
- RPN token table save.c:1855-1939 — operators `+ - * / ** == != > < >= <=
  ?` and functions (verbatim, all spelled with trailing `()`): `atan() cph()
  asin() acos() tan() sin() cos() abs() sgn() sqrt() tanh() cosh() sinh()
  atanh() acosh() asinh() exp() ln() log10() integ() avg() ravg() max()
  min() im() re() pi() k() e() q() del() db20() deriv() deriv0() deriv2()
  deriv20() prev() exch() dup() idx()`. A token is a NUMBER when strtod
  consumes a prefix (spice suffixes ok: `1k`); anything else must resolve
  via get_raw_index or the whole expression fails.

### Cursor engine

- `xschem cursor <1|2> <0|1>` scheduler.c:2689-2713 — absolute
  enable/disable of A/B (sets/clears graph_flags bit 2/4; on enable RESETS
  the position to 0.0). Not readonly-gated.
- `xschem get cursor1_x|cursor2_x` scheduler.c:3701-3712;
  `xschem set cursor1_x <v>` :9933 (position only);
  `xschem set cursor2_x <v>` :9946-9958 — ALSO fires
  `backannotate_at_cursor_b_pos` when `xctx->rects[2] > 0 &&
  rect[2][0].flags & 1 && graph_flags & 4` (true in the viewer once a graph
  rect exists and B is enabled).
- `backannotate_at_cursor_b_pos` callback.c:404-525: fills
  `raw->cursor_b_val[i]` for EVERY var via `interpolate_yval`
  (callback.c:387-402 — plain linear interpolation between p and p+1 on the
  sweep vector). This is the engine ground truth for the B readout.
- waves_callback callback.c:540; key 'a' toggle :878-893, 'b' :895-923
  (live_cursor2_backannotate default 1, xschem.tcl:15433), 's' swap
  :925-975. `graph_use_ctrl_key` default 0 (xschem.tcl:15408) → access_cond
  true in the shipping profile. **There is NO `xschem get graph_flags`
  getter** → decision D8.

### Graph rect machinery

- Creation: `xschem rect x1 y1 x2 y2 [pos] [props] [draw]` scheduler.c:8903
  (readonly-rejected :8910 → inside `with_edit`; uses `xctx->rectcolor` —
  save/set-2/restore like `place_graph_rect` wave_viewer.tcl:251). Pass
  draw=0 during regenerate, one redraw at the end.
- Update: `xschem setprop rect [-fast|-fastundo] 2 n tok [val]`
  scheduler.c:10324-10346 (doc) / :10479+ (impl); `allprops` arm :10509;
  readonly-rejected :10367. Special verbs `setprop rect 2 n fullxzoom`
  :10492 / `fullyzoom` :10500 → `graph_fullxzoom` draw.c:2881 /
  `graph_fullyzoom` :2979, which COMPUTE the data range and WRITE the rect
  attrs (x1/x2 at draw.c:2962-2963; y1/y2/ypos on the y side). Read back
  with `xschem getprop rect 2 n <tok>` (scheduler.c:4552).
- Deletion/regenerate: `xschem clear_drawing` (verb scheduler.c:2515 →
  perform_action arm :1050; argc==2 strict, readonly-rejected, NOT
  undoable) frees every object in the buffer but does NOT touch
  `xctx->raw` (actions.c:1866 — verified, raw survives). The viewer canvas
  holds ONLY wviewer-created rects, so full regenerate = clear_drawing +
  recreate, inside one `with_edit`.
- Default prop template: `add_graph` scheduler.c:1888-1917
  (wave_viewer.tcl:266 mirrors it verbatim — keep those defaults for every
  generated rect, overridden by the model fields).
- node attr grammar (draw_graph draw.c:4536, token walk :4629-4704):
  newline-separated tokens inside `node="…"`; a double-quoted token
  `"alias;expr"` displays `alias` for vector/expr `expr` (split on `;`,
  draw.c:4697); an expr containing SPACES = inline RPN custom plot
  (draw.c:4720+ — we do NOT use inline RPN, see D5); `color="4 15 7"` =
  space-separated per-trace color layer indices, count == trace count.
  Shipped example: xschem_library/examples/test_ne555.sch:27-48 (in-file
  escaping `\\"…\\"` is the SAVE format; via setprop/getprop you handle
  plain `"…"` tokens).
- graph_edit_properties xschem.tcl:4736 — NOT reused; viewer double-clicks
  stay swallowed (item-11 D9 unchanged).

### wviewer / ase helpers (current line anchors)

- src/wave_viewer.tcl: :58 namespace vars (`windows`, `graphbb`,
  `graphkeys`, `keepseqs`), :89 title_for, :109 window_for, :142 open,
  :202 close, :214 in_ctx, :230 with_edit, :251 place_graph_rect, :261
  display_raw, :279 over_graph, :301 key_filter, :322 btn3_filter, :346
  strip_bindings, :366 build_menubar (Graph/Cursors disabled placeholder
  loops :389-395 — replaced by this item).
- src/ase_window.tcl: `ase::theme` :121 (palette + named fonts),
  `ase::ui::apply_theme` :152, `ase::ui::bind_dialog_esc` :837,
  `ase::ui::dialog_frame` :844, `ase::ui::dialog_row` :852,
  `ase::ui::dialog_buttons` :860 (binds ESC to the cancel path by
  construction — item 10). REUSE these; do not fork, do not edit.
- `ase::format_value` src/ase.tcl:78 (eng notation, gate `ase_eng_notation`
  default 1) — the readout formatter.
- Test helpers: `send_key` tests/headless/test_wave_viewer.tcl:190;
  `send_return` pattern tests/headless/test_ase_dialogs.tcl:136 (copy the
  proc into test_wave_viewer.tcl if needed).
- Receipts/11 recon that still binds: `xschem object rect` descriptors have
  NO coordinates; `xschem get top_path` = {} under tabs (derive toplevel via
  regsub on win_path); Tk bind spellings are canonicalized.

## Scout decisions (each = one line of why; follow unless code reality forces
## a deviation, then document it in the receipt)

- **D1 Cursors = engine x-cursors, menu-driven absolutely.** Cursor A/B
  menu checkbuttons drive `xschem cursor 1|2 $on` + on-enable
  `xschem set cursor1_x/2_x <mid of graph-0's current x range>` (the verb
  resets pos to 0.0) + redraw in viewer ctx. Why: exact existing engine,
  zero C, drawn by plain redraw (draw.c:5950).
- **D2 Readout interpolation = Tcl mirror of interpolate_yval, one helper
  for BOTH cursors.** `wviewer::interp_value <var> <x>`: `pos = raw pos_at
  <sweepvar> $x` (sweepvar = first name in `raw list`); y = v[pos] +
  (v[pos+1]-v[pos])·(x−s[pos])/(s[pos+1]−s[pos]) via `raw value` calls
  (clamp: pos<0 → nearest end; pos==last → v[last]). Why: the engine only
  interpolates for cursor B (cursor_b_val); one honest uniform path for A
  and B, cross-checked in the test against the engine's B ground truth
  (`set cursor2_x` → `raw value <var> {}`).
- **D3 Trace/graph delete = listbox dialog** (Graph > Delete…): one listbox
  with one row per graph ("graph N") and per trace ("graph N: name (expr)"),
  extended selection, OK deletes selected traces and/or whole graphs from
  the model → regenerate. Why: canvas-legend click-select has no C hit-test
  API (receipts/11: descriptors carry no coordinates) — the listbox is the
  honest v1; documented here as the chosen selection model.
- **D4 Expression validation is Tcl-side, BEFORE `raw add`.** Pure proc
  `wviewer::validate_rpn <expr> <varlist>` → {} ok / error message: each
  whitespace token must be (a) an operator/function from the save.c table
  (verbatim list above — hardcode it with a comment pointing at
  save.c:1855-1939), (b) a number (`regexp {^[-+]?(\d|\.\d)}` — the strtod
  prefix rule, spice suffixes fine), or (c) a member of `<varlist>`
  (case-insensitive, plus the `v(tok)` wrapping get_raw_index applies).
  On dialog OK: validate against the viewer ctx's `raw list`; failure →
  in-dialog error label (ase accent color), dialog stays up, nothing added.
  Why: C discards the evaluator's error (save.c:992) — without
  pre-validation a bad expression silently plots garbage.
- **D5 Expression traces materialize via `raw add`, node attr stays
  simple.** Add Trace with an RPN expr: auto-name `expr1`, `expr2`, …
  (or the user-given name; names must match `^[A-Za-z_][A-Za-z0-9_]*$` —
  they become raw vector names and unquoted node tokens), then
  `xschem raw add <name> <expr>` in viewer ctx, trace dict stores BOTH
  (`expr` = original RPN, `vec` = vector name); the rect node token is the
  vector name (plain) or `"name;vec"` when a display name differs. Why:
  the item detail mandates the raw-add route; storing `expr` keeps item
  13/14 able to re-add after a raw reload; inline-RPN node tokens are the
  road not taken (two evaluation sites).
- **D6 Fit = engine autozoom + read-back (the ONE sanctioned model write
  from the engine).** View > Fit: for each graph n `setprop rect -fast 2 n
  fullxzoom` + `fullyzoom` inside with_edit, then `getprop rect 2 n
  x1/x2/y1/y2` back into the model, then canvas `zoom_full` + redraw.
  Why: reuses the engine's range math (log/expr aware) instead of
  reimplementing; the read-back is a model WRITE (like a user edit), rect
  generation stays one-directional. Blank (auto) model ranges also resolve
  through this path at regenerate time (D7).
- **D7 Model shape + regenerate.** Namespace var `wviewer::layouts`:
  token → dict `{sharedx 0 graphs {G0 G1 …}}`; each G =
  `{traces {{expr … name … color … vec …} …} logx 0 logy 0 x1 {} x2 {}
  y1 {} y2 {}}` (spec Model paragraph; `height` deferred with a comment).
  `wviewer::graph_props <G>` = PURE proc (no xschem/Tk calls) → full prop
  string from the add_graph template with node/color/logx/logy/ranges
  filled (blank range → template default, resolved by fullzoom after
  placement when raw is loaded). `wviewer::graph_geometry <i>` = pure →
  `{0 <i*450> 800 <i*450+400>}` (stacked vertically; xschem y grows
  downward). `wviewer::regenerate <token>` = with_edit { clear_drawing;
  foreach G: rect …geometry… -1 [graph_props] 0 } + REBUILD
  `wviewer::graphbb` for the canvas (over_graph and the a/b key gate feed
  off it — forgetting this breaks the cursor keys) + apply fullx/fullyzoom
  for blank-range graphs when raw is loaded + `zoom_full` + redraw.
  `sharedx` 1 → every graph gets graph-0's x1/x2 at generation (Graph menu
  checkbutton "Shared X Axis"). Why pure procs: the headless legs demand
  model→props checks without a window.
- **D8 Cursor state is mirrored per-window in Tcl.** No `get graph_flags`
  getter exists; menu checkbutton vars are authoritative for menu ops
  (absolute `xschem cursor`), and `key_filter` flips the mirror + refreshes
  the readout when it forwards `a`/`b`/`s` over a graph (the only other
  toggle path; C-side access_cond is true in the shipping profile).
  Document the residual desync risk (a C-side refusal the mirror can't
  see) in a comment. Why: the alternative is a C getter — out of scope.
- **D9 Readout = bottom bar, not a toplevel.** Frame `$top.wvreadout`
  packed `-side bottom -fill x` (ase theme panel + AseEntryFont; values via
  `ase::format_value`); one line per enabled cursor:
  `A: x=905m  v(g)=905m  expr1=…` (x + per-trace y for every trace in the
  model, dedup by vec). Shown automatically when a cursor is enabled;
  Cursors > Readout checkbutton shows/hides. Refresh triggers: cursor menu
  ops, key_filter a/b/s forward tail, and an APPEND (`+`) to the EXISTING
  generic `<ButtonRelease>` canvas bind — **never bind `<ButtonRelease-1>`:
  a more-specific sequence would PREEMPT the kept generic editor bind and
  break cursor dragging** (same Tk rule the item-11 sweep exists for). Also
  expose `wviewer::readout_refresh <token>` as the test seam. Why bottom
  bar: WSLg raise/focus pain with always-on-top toplevels (receipts/06/11).
- **D10 Color auto-cycle palette** = `{4 5 7 8 9 12 14 15 10 11}` (matches
  shipped graph usage, ne555 uses 4 15 7 12 9; skips layers 0-3:
  background/wire/grid/text). `wviewer::next_color <G>` = first palette
  entry unused by the graph's traces, else index by trace count mod length.
  Pure proc (headless-checkable).
- **D11 Add Trace dialog** (Graph > Add Trace…): target-graph combobox
  (indices from the model, default = LAST graph; hidden/disabled when only
  one), expression entry, listbox of raw vars (filled from `raw list` in
  viewer ctx; empty + a notice line when no raw is loaded — catch-guarded),
  optional name entry, color auto from D10. Double-click or select+OK on a
  listbox var uses it as the expr. Add Graph = append empty graph dict +
  regenerate (a graph with zero traces renders as an empty grid — fine).
- **D12 display_raw becomes a thin model wrapper** (the item-11 seam,
  reshaped as planned): ensure graph 0 exists in the model, append trace
  {expr $node vec $node color $color}, `raw read` when a rawfile is given,
  regenerate. The item-11 G7 assertions (1 rect, node contains i(v1),
  modified 0, readonly restored) must stay green UNCHANGED.
- **D13 Dialog construction**: every viewer dialog = `ase::ui::dialog_frame`
  + `dialog_row` + `dialog_buttons` (ESC-cancel by construction, item 10)
  + extra widgets gridded under the same toplevel + `ase::ui::apply_theme`
  + Return = OK on the entries; widget paths under the viewer toplevel
  (`$top.wvadd`, `$top.wvdel`, `$top.wvaxes`); per-dialog state in
  `wviewer::` namespace vars cleaned on cancel/OK (TIP-278: `variable`
  declarations, absolute names). Axes… dialog: graph combobox + x1/x2/y1/y2
  entries (blank = auto) + logx/logy checkbuttons → model → regenerate.

## Deliverables

1. **Model + regenerate** (D7): `wviewer::layouts`, pure `graph_props` /
   `graph_geometry` / `next_color` / `validate_rpn`, `regenerate` with
   graphbb rebuild. Model is the single source of truth; rects are always
   regenerated from it (the D6 fit read-back is the one documented model
   write from engine-computed values).
2. **Graph menu live** (D3/D5/D10/D11/D13): Add Graph, Add Trace…,
   Delete…, Axes…, Shared X Axis checkbutton. Remove the item-11 disabled
   placeholders (build_menubar :389-392); entries call real procs.
3. **Cursors menu live** (D1/D2/D8/D9): Cursor A / Cursor B checkbuttons,
   Readout checkbutton + bottom-bar readout with eng-notation values.
4. **View menu** (D6): Fit rewired to graph-data autozoom (fullx+fully per
   graph + model read-back + zoom_full); Zoom In/Out/Redraw stay as item 11
   wired them (canvas ops); canvas zoom/pan untouched.
5. **Expression waves** (D4/D5): Add Trace accepts RPN; bad expressions
   surface in-dialog (no throw, no silent garbage); good ones become raw
   vectors that plot like any var.
6. Update the wave_viewer.tcl file-head comment block (D-numbers, model
   description, the reshaped display_raw seam) and the test-file header —
   house style.
7. Do NOT edit: src/ase.tcl, src/ase_window.tcl, any C file, Makefile.in,
   tests/run_regression.tcl (pre-batch dirty). If a scaffold gap truly
   forces an ase_window.tcl edit, STOP and reconsider; only proceed with a
   documented justification in your handoff notes for the receipt.

## Tests — extend tests/headless/test_wave_viewer.tcl (keep V1-V6 and G1-G9
## green as they stand; G7 must pass UNCHANGED against the D12 wrapper)

Headless arm (new, run under `--nogui`; pure procs only — no window):
- H1 `graph_props single plain trace`: contains `flags=graph`,
  `node="v(d)"`, `color="4"`, `logx=0`, `logy=0`.
- H2 `graph_props alias + multi-trace`: trace {expr v(d) name drain vec
  v(d)} + plain second trace → node attr carries `"drain;v(d)"` token AND
  the plain token, `color` has exactly 2 entries.
- H3 `graph_props explicit ranges + logy`: x1 0, x2 1.8, logy 1 → attrs
  `x1=0`, `x2=1.8`, `logy=1`.
- H4 `graph_geometry stacking`: graph 0 → {0 0 800 400}; graph 2 →
  {0 900 800 1300}.
- H5 `next_color cycle`: fresh graph → 4; graph using {4 5} → 7; all used →
  wraps deterministically.
- H6 `validate_rpn`: `{v(d) db20()}` with varlist {v(d)} → ok; `{v(d)
  bogus()}` → error mentioning `bogus()`; `{v(nosuch) db20()}` → error
  mentioning v(nosuch); bare net `d` accepted when varlist has `v(d)`
  (get_raw_index wrap rule); number tokens `1k 2.5 -3` accepted.

GUI arm (DISPLAY-guarded self-SKIP, same harness; reuse send_key /
send_return; drive menus by invoking the menu entrycommand or the underlying
proc — full Tk key sequences only where a BINDING is under test):
- G10 `Add Graph`: menu entry enabled (not disabled), invoke twice on a
  fresh viewer → model has 2 graphs, `xschem get rects 2` == 2, rect 1 y
  offset == 450 (getprop-independent: rect coords via the graphbb registry
  match graph_geometry).
- G11 `Add Trace from raw vars`: raw loaded (V4 artifact via display_raw or
  raw read); Add Trace dialog listbox count == `xschem raw vars`; pick the
  first non-sweep var → OK → rect node attr contains it verbatim, color ==
  palette head, model trace recorded.
- G12 `expression trace`: pick a live var `$v` from `raw list`; expr
  "`$v db20()`" name db1 → `xschem raw index db1` >= 0, node attr carries
  db1, redraw rc 0, model stores both expr and vec.
- G12b `bad expression surfaces`: expr "`v(nosuchnet) db20()`" → dialog
  still exists, error label non-empty, `raw index` for the would-be name
  == -1, model unchanged, NO throw.
- G13 `Axes dialog log toggle`: set logy=1 (+ x1/x2 explicit) on graph 0 →
  rect attr logy == 1, x1/x2 exact; model matches.
- G14 `Delete`: delete one trace via the Delete… dialog → gone from node
  attr and model (other trace survives); delete a whole graph → rects
  count drops and remaining graphs re-stack from y 0.
- G15 `cursors + readout`: enable A+B via menu; `xschem set cursor2_x $x`
  with $x strictly between two sweep points (e.g. 0.905 on the 0..1.8/0.01
  dc sweep); readout_refresh; assert (a) readout text shows
  `[ase::format_value $x]`, (b) per-trace y for a NONZERO-SLOPE var (use
  v(g)-class: scan `raw list` for a var with v[pos+1]!=v[pos] at $x)
  matches the engine ground truth `xschem raw value <var> {}` (rel tol
  1e-6) — the honest-interpolation cross-check, (c) that value differs
  from the nearest-sample `raw value <var> <pos>` (proves interpolation
  actually interpolates), (d) cursor A at the same $x via
  `set cursor1_x` reads out the same y through the Tcl helper.
- G16 `Fit`: set graph-0 model x1 0.5 / x2 1.0, regenerate (rect shows the
  subrange), View > Fit → rect x1 ≈ sweep min, x2 ≈ sweep max (numeric
  compare, tol 1e-6 rel), model updated to the same values.
- G17 `menus live`: no Graph/Cursors entry left `-state disabled`
  (Readout may start unchecked but enabled).
- Keep the permanent `kf_errs == 0` guard passing (the key_filter grows an
  a/b/s tail — it must stay error-free).

Regression gates: full test_wave_viewer.tcl green in BOTH arms; all six
protected suites test_ase_{core,view,window,dialogs,final,interact} green;
tests/headless/full_audit.sh fails a subset of the baseline list (rerun-first
for the known WSLg flakes; V6/ne555 embedded-graph leg green inside it).

## Sabotage plan (≥2 required; do all 3, each post-commit, `git diff`-confirmed
## sabotage-only, targeted `git checkout -- <file>` revert, clean re-run green)

- S1: `graph_props` stops emitting the model's logy (hardcode `logy=0`) →
  exactly H3 + G13's logy checks fail; everything else green.
- S2: `interp_value` returns the bare `v[pos]` (drop the interpolation
  term) → exactly G15(b)/(c) fail (b: mismatch vs engine cursor_b_val;
  c: now EQUAL to the nearest sample), G15(a)/(d) per its wiring.
- S3: `validate_rpn` neutered (always ok) → exactly G12b fails (no error
  label, phantom vector/model row), H6's bad-token checks fail.

## Commit

ONE commit. Stage EXACTLY:
- `src/wave_viewer.tcl`
- `tests/headless/test_wave_viewer.tcl`

Message: normal prose (e.g. "feat(wviewer): trace/graph model, live
Graph/Cursors menus, readout + expression waves (item 12)"), body listing
model/menus/cursors/fit/expr + test counts, Co-Authored-By trailer per repo
convention. NEVER stage the pre-batch dirty files
(doc/claude/specs/sky130_workarea.md, sky130A/xschem_libs/library.defs,
src/ciw.tcl, tests/headless/test_sky130a_libmgr.tcl,
tests/run_regression.tcl, the two SANDBOX files) or any junk dirs.

## RUNBOOK policy block (verbatim — non-negotiable)

- Git: NEVER `git reset --hard`, NEVER `git add -A`/`commit -a`, NEVER push.
  Stage explicit file lists only. Pre-existing dirty tracked files at batch
  start (listed in PLAN.md preflight) must NEVER be staged; in particular
  `tests/run_regression.tcl` is dirty pre-batch → this batch does NOT register
  tests there; tests/headless/full_audit.sh auto-discovers `test_*.tcl`.
- A green suite ≠ the changed code ran: sabotage-verify (each sabotage fails
  EXACTLY its target check, revert via targeted `git checkout -- <file>` only
  after `git diff` confirms the file holds nothing but the sabotage, clean
  re-run green).
- Headless traps: each test its own process; repo-root cwd for relative paths;
  script error idles rather than hangs; `--nogui --pipe -q --nolog --script`.
- GUI tests: DISPLAY-guarded self-SKIP (`winfo exists .` guard pattern from
  full_audit.sh); replay WHOLE Tk event sequences in the shipping rc profile.
- User-facing messages via `ciw_echo`, not puts/statusbar.
- Tcl: TIP-278 (`variable`/absolute names in namespaces); C (if any): C89,
  `_ALLOC_ID_` placeholders. Windows: guard unix-only subprocess paths.
- Do not touch `_nhangle_*`/`_allm_*`/junk dirs or anything outside declared
  scope. Do not edit generated files (Makefile from Makefile.in — tmpasm, no
  `$@`/`$<`, `@` is the delimiter).
- Commit messages: normal prose, Co-Authored-By trailer per repo convention.
