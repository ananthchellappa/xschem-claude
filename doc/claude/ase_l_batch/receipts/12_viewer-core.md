# Receipt — item 12 viewer-core (round-3, Waveform Viewer)

Verdict: **DONE** [x]. Commit (NOT pushed):
- `c143cedb` feature — trace/graph model, live Graph/Cursors menus, readout
  + expression waves (`src/wave_viewer.tcl` +955/-21,
  `tests/headless/test_wave_viewer.tcl` +352/-13; exactly the prompt's
  file list, no pre-batch dirty tracked file staged).

Outstanding problems: none (verified clean — empty problem list at
ledger time). Working tree clean at HEAD for both item files. Pure Tcl,
zero C changes, no rebuild needed. No fixer rounds.

## What landed

Per scout decisions D1-D13, all in `src/wave_viewer.tcl`:

- **Trace/graph model (deliverable 1)**: `wviewer::layouts` maps session
  token -> `{sharedx graphs {G...}}`, each G =
  `{traces {{expr name color vec}...} logx logy x1 x2 y1 y2}` ({} = auto).
  Model is the single source of truth; pure procs `graph_props`
  (add_graph-template attr order; alias tokens as backslash-escaped
  `"name;vec"`; per-trace color list), `graph_geometry` (800x400 slots,
  450 pitch, stacked vertically), `next_color` (fixed palette
  4 5 7 8 9 12 14 15 10 11), `validate_rpn`. `wviewer::regenerate` =
  clear_drawing + one layer-2 graph rect per graph (draw=0) + engine
  fullx/fullyzoom resolving blank ranges when a raw is loaded + graphbb
  registry rebuild + zoom_full + ONE redraw. One honest direction —
  rect attrs regenerated from the model, never parsed back (single
  sanctioned exception: Fit's range read-back, below).
- **Graph menu live (deliverable 2)**: Add Graph; Add Trace… (raw-vars
  listbox from `xschem raw vars/list` + expression entry + optional name
  + target-graph combobox defaulting to last graph + in-dialog error
  label); Delete… (listbox of graphs+traces, extended selection —
  documented honest v1 selection model per D3); Axes… (blank=auto x/y
  ranges + logx/logy checkboxes); Shared X Axis checkbutton. All dialogs
  on the `ase::ui` scaffold — ESC-cancel by construction (item-10 helper
  reused, not forked) + ase theme fonts/palette, Return=proceed.
- **Expression waves (deliverable 5)**: RPN expressions Tcl-pre-validated
  by `validate_rpn` (token table mirrored from save.c:1855-1939;
  strtod-prefix numbers; case-insensitive bare var auto-wrapped `v()`)
  BEFORE `xschem raw add` — necessary because the C evaluator DISCARDS
  errors (save.c:992) and would leave a phantom uninitialized vector.
  Bad tokens surface in the dialog error label (no close, no model
  mutation); good ones materialize as raw vectors (auto `expr<N>` or
  validated user name) and plot like any var. Trace rows store both
  `expr` and `vec`.
- **Cursors menu live (deliverable 3)**: A/B checkbuttons drive the C
  engine x-cursors (`xschem cursor 1|2` + cursor1_x/2_x re-park mid
  graph-0; plain redraw draws them). Per-window Tcl mirrors of the
  cursor flags (no graph_flags getter exists — D8 desync risk
  documented); key_filter's forwarded `a`/`b`/`s` tail flips the mirrors
  and refreshes the readout.
- **Readout**: bottom bar (packed `-before` the canvas), one line per
  enabled cursor: x value + per-trace interpolated y via
  `wviewer::interp_value` — a Tcl mirror of the C `interpolate_yval`,
  used uniformly for BOTH cursors — eng-notation formatted via
  `ase::format_value`. Refresh hook appended to the KEPT generic
  `<ButtonRelease>` (never `-1`).
- **View menu live (deliverable 4)**: Fit = fullx/fullyzoom + model
  range read-back (the ONE sanctioned reverse write) + zoom_full;
  Zoom In/Out/Redraw; canvas zoom/pan preserved.
- `display_raw` reshaped into a thin model wrapper (D12) — item-11's G7
  sanity-graph leg passes UNCHANGED.
- Model/cursor state dies with the window (namespace forget);
  persistence in the ASE state dict is item 14's contract.

## Tests

`tests/headless/test_wave_viewer.tcl` — **185 checks total: 149 GUI arm
+ 36 headless (`--nogui`) arm, ALL PASS**:
- Headless: V1-V6 kept from item 11 + new pure-proc H1-H6
  (model→rect-attr generation via graph_props/graph_geometry/next_color/
  validate_rpn, incl. logy emission and bad-token rejection).
- GUI: G1-G9 kept (incl. the permanent `kf_errs==0` key_filter guard);
  new G10-G17: add-graph stacking, add trace from raw vars → rect node
  attr contains the trace, db20 expression trace → raw vector exists and
  plots, bad-expr in-dialog surfacing (dialog stays open, error label
  set, NO phantom vector, model unchanged), axes log toggle → rect attr
  logy=1, delete trace/graph → gone + restack, menu cursors + readout in
  eng notation with the honest-interpolation cross-check against
  `xschem raw value <var> {}` engine ground truth (x=0.905 on a
  nonzero-slope var, rel 1e-6) AND proof the value differs from the
  nearest sample (actually interpolates), Fit changes x1/x2 to the data
  range.
- All six protected suites green: test_ase_core 66 + test_ase_final 28
  (in their full_audit `--nogui` arm — see deviation c), test_ase_view
  36, test_ase_window 154, test_ase_dialogs 133, test_ase_interact 63.
- full_audit: launched by the implementer
  (scratchpad/full_audit_item12.log); still mid-run at forced report
  time — partial output showed ONLY baseline fails, with test_ase_core/
  test_ase_dialogs PASS inside the audit. nonBaselineFails=[] stands on
  the partial audit + direct green runs of every suite this item touches;
  the verifier lenses subsequently confirmed (outstanding problems empty,
  no fixer round needed).

## Sabotage table (each post-commit, `git diff`-confirmed sabotage-only,
targeted `git checkout -- src/wave_viewer.tcl` revert, clean re-run
green 36/149)

| # | Sabotage | Target | Failed exactly? |
|---|----------|--------|-----------------|
| S1 | graph_props hardcodes logy=0 (model logy dropped) | H3 "logy=1 line" (both arms) + G13 "rect 0 logy == 1" (GUI) | yes |
| S2 | interp_value returns bare v[pos] (interpolation term dropped) | G15b engine cursor_b_val cross-check + G15c differs-from-nearest-sample; G15a/G15d stayed green per their wiring (readout and test share the helper), exactly as the prompt predicted | yes |
| S3 | validate_rpn neutered (always ok) | H6 bogus()/v(nosuch) bad-token checks (both arms) + all 4 G12b checks (dialog closed, empty error label, phantom raw vector db2 created, model changed) + one downstream cascade: G14 trace-count sees the phantom model row the prompt itself names in S3's target; nothing unrelated failed | yes |

## Fix-round history

None — single feature commit, no verifier-raised problems, no fixer
commits.

## Implementer deviations (accepted, reality-forced)

- (a) **`setprop` flag ordering**: the prompt/anchors wrote
  `xschem setprop rect -fast 2 n fullxzoom`, but scheduler.c's option
  scan stops at the first non-dash argument — flags must PRECEDE the
  object word: `xschem setprop -fast rect 2 n fullxzoom` (matches the
  shipped xschem.tcl:4265 usage). Without this the fullzoom calls throw
  "wrong layer or rect number".
- (b) **Item-11 G2 assertion flipped**: "every Graph+Cursors entry
  disabled" → "none disabled". Keeping G1-G9 verbatim is impossible
  against this item's own deliverable 2 / G17 (the menus go LIVE);
  header comment updated in the test — this receipt is the required
  justification.
- (c) **test_ase_core/test_ase_final are `--nogui` tests** (full_audit's
  nogui_tests list); running them in GUI mode fails BY DESIGN
  (`ase::netlist` has_x guard refuses when the design is not the current
  schematic). Verified pre-existing via a stash A/B against pristine
  HEAD files — NOT a regression; both green in their correct arm.

## Corrected anchors worth keeping (verified at c143cedb)

- `xschem setprop` flags precede the object word (deviation a) — items
  13-14 will hit the same calls.
- `xschem raw add` never reports evaluator errors (save.c:992 path
  discards them, vector left uninitialized) — any expression entry
  point MUST pre-validate Tcl-side (`wviewer::validate_rpn`, token
  table from save.c:1855-1939).
- No graph_flags getter exists — cursor enable state must be mirrored
  in Tcl (per-window mirrors in wave_viewer.tcl; keyboard toggles
  intercepted in key_filter's forwarded-key tail to keep mirrors in
  sync; desync risk documented at the mirror definition, D8).
- Engine cursor ground truth for tests: `xschem raw value <var> {}`
  evaluates at the cursor — the honest cross-check for any future
  readout work.
- Blank model ranges resolve through engine fullx/fullyzoom only when a
  raw file is loaded — regenerate guards on `xschem raw loaded`.
