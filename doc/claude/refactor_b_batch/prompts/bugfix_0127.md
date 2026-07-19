# Bugfix implement prompt — issue 0127: scripted `xschem rect`/`arc`/`line` coord forms push NO undo checkpoint

Repo: /home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing.
Issue file: doc/claude/issues/0127-scripted-rect-arc-coord-form-no-push-undo.md
Scout receipts (batch items 25/26/30): doc/claude/refactor_b_batch/receipts/25_rect.md, 26_arc.md, 30_line.md
Plan: doc/claude/refactor_b_batch/BUGFIX_PLAN.md item 4.

## Bug (LIVE-repro'd 2026-07-18 by the scout, current binary)

The scripted coordinate forms `xschem rect x1 y1 x2 y2 ...`, `xschem line x1 y1 x2 y2 ...` and
`xschem arc x y r a b layer` store the shape + `set_modify(1)` but push NO undo checkpoint.
One undo after a scripted shape rides the PREVIOUS checkpoint and destroys unrelated edits
along with the shape. Scout repro (headless, `--nogui --pipe`): `xschem clear force`, `xschem
wire 0 0 100 0` (wire pushes per call — the precedent), then `xschem rect 300 -100 400 -50`,
then ONE `xschem undo` → wires == 0 (the wire vanished with the rect). Same result for the
line and arc variants. The interactive twins all push per gesture, so interactive and scripted
placements have divergent undo semantics.

## Decision (scout, PROCEED with per-call push)

Per-call push, mirroring the `wire` coord branch (scheduler.c:11695 pushes before every
scripted storeobject — receipts/06_wire.md "branch-push"). Family consistency: interactive
twins push per gesture; wire already pushes per scripted call; machinery loops through
`xschem wire` already tolerate per-call pushes. Machinery callers checked: create_graph.tcl:36
(ONE rect per composite, proc ends `xschem set_modify 0` which does not touch undo slots) and
place_sym_pins.tcl:38/40 (N rect + N line per pinlist loop — same class as wire loops;
MAX_UNDO=80 ring caps depth, undo depth is convenience not correctness). GUI graph creation
uses `xschem add_graph` (separate branch), NOT the rect coord form. create_save goldens
compare saved .sch bytes only — push_undo never alters the saved file, and those same test
scripts (rom8k.tcl: 23 line + 11 wire; 0_examples_top.tcl: lines+rects+wires) already mix
per-call-pushing `xschem wire` and pass. Neither defer trigger fires.

SCOPE NARROWING (record in the issue file): the `text` sibling stays OUT. Scripted
`xschem text` (scheduler.c:11187, create_text) pushes NOTHING and also never calls
set_modify — a worse, two-part bug class (interactive place_text pushes at actions.c:4987);
fixing it needs its own set_modify decision. Leave it as the recorded residual.

## ANCHORS (all re-verified from source 2026-07-18 — re-verify again before editing, lines drift)

- src/scheduler.c:8888 — `rect` branch. 8894 !xctx check; 8895
  `scheduler_readonly_reject(interp, "rect")`; coord arm `if(argc > 5)` 8896;
  8906 `storeobject(pos, x1,y1,x2,y2,xRECT,xctx->rectcolor,0,prop_str);`;
  set_modify(1) at 8917. NO push_undo anywhere in the arm.
- src/scheduler.c:5758 — `line` branch (in xschem_cmds_l). 5765 readonly reject; coord arm
  `if(argc > 5)` 5766; 5776 `storeobject(pos, x1,y1,x2,y2,LINE,xctx->rectcolor,0,prop_str);`;
  set_modify(1) at 5782. NO push_undo.
  WARNING: the rect and line coord arms are near-identical — the preceding
  `if(argc > 8) draw = atoi(argv[8]);` line is byte-identical in both. Anchor exact-string
  edits on the storeobject lines (xRECT vs LINE literal differs).
- src/scheduler.c:2077 — `arc` branch. 2081 readonly reject; coord arm `if(argc > 7)` 2085;
  layer-validity gate 2093 `if(layer >= 0 && layer < cadlayers) {`; 2094
  `store_arc(-1, x, y, r, a, b, layer, 0, prop);`; 2095 set_modify(1); result "1"/"0" at
  2096/2098 (no known consumers — receipts/26_arc.md — but do NOT touch it). NO push_undo.
- Precedent: src/scheduler.c:11695 — wire coord arm `xctx->push_undo();` immediately before
  its storeobject (11696). Mirror this placement.
- Interactive twins (why per-call is the consistent choice):
  - new_rect PLACE: actions.c:4576 push before storeobject 4583
  - new_arc SET commit: actions.c:4450 push INSIDE the `if(xctx->nl_r>0.)` success guard,
    before store_arc 4452 — i.e. interactive arc only pushes when it actually stores
  - new_line PLACE: actions.c:4499 push before its five storeobject/log sites
- store primitives contain zero undo/log by design: storeobject store.c:226, store_arc
  store.c:132.
- Undo ring persists across `xschem clear force` (clear_schematic actions.c:3754 never calls
  clear_undo) — the test sequences below were verified live against this behavior.
- Helpers verified live for the test: `xschem get wires`; `llength [xschem objects -type
  rect|line|arc]` (uniform enumerator, scheduler.c:7452); `xschem get modified`;
  `xschem set rectcolor N`; invalid-layer arc (`... 999`) returns "0" and stores nothing;
  readonly refusals for all three verbs return rc=1 with message
  `xschem <verb>: schematic is read-only (use Edit > Make Editable to enable editing)`.
- tests/headless/full_audit.sh — auto-discovers every tests/headless/test_*.tcl; default
  runner `--pipe -q --nolog --script <file>` from repo root; default pass banner
  `RESULT: ALL PASS`.
- create_save golden harness: `cd tests && tclsh create_save.tcl` (parallel, per-job
  XSCHEM_TMP_DIR; greps its results.log for FAIL/GOLD?/FATAL).

## EDITS (exact scope — nothing else; C89: no new declarations needed)

All three: insert ONE line `xctx->push_undo();` with a short trailing comment, matching the
wire-branch style. Rebuild: `cd src && make`.

1. src/scheduler.c rect coord arm — immediately BEFORE
   `storeobject(pos, x1,y1,x2,y2,xRECT,xctx->rectcolor,0,prop_str);` (≈8906):

   ```c
   xctx->push_undo(); /* issue 0127: checkpoint like interactive new_rect + the wire coord arm */
   ```

2. src/scheduler.c line coord arm — immediately BEFORE
   `storeobject(pos, x1,y1,x2,y2,LINE,xctx->rectcolor,0,prop_str);` (≈5776): same line, comment
   `/* issue 0127: checkpoint like interactive new_line + the wire coord arm */`.

3. src/scheduler.c arc coord arm — INSIDE the `if(layer >= 0 && layer < cadlayers) {` success
   arm, immediately BEFORE `store_arc(-1, x, y, r, a, b, layer, 0, prop);` (≈2094), comment
   `/* issue 0127: checkpoint like interactive new_arc; only when actually storing */`.
   NOT above the layer gate: a refused invalid-layer arc must push nothing (0121/0125
   spurious-undo class; mirrors interactive new_arc's r>0-guarded push). The "1"/"0" result
   contract stays untouched.

No new log site (D3 family — logging stays exactly as receipts 25/26/30 left it). No change
to the readonly gates, set_modify calls, draw calls, or the text branch.

## TEST PLAN

NEW test file tests/headless/test_scripted_shape_undo.tcl (auto-discovered by full_audit; own
process; run from repo root; per-check `ok:`/`FAIL:` lines; final `RESULT: ALL PASS` /
`RESULT: N FAILED` + matching exit code; end with `xschem exit closewindow force`; copy the
shape of a recent sibling e.g. tests/headless/test_apply_properties_readonly.tcl). No fixture
file needed — everything on the launch untitled buffer via `xschem clear force`. Never save.
Use `xschem set rectcolor 4` after each clear so layer state is deterministic.

Per-shape block (X = R rect / L line / A arc; commands:
`xschem rect 300 -100 400 -50` / `xschem line 0 -200 100 -200` / `xschem arc 300 -300 50 0 180 4`):

```tcl
xschem clear force
xschem set rectcolor 4
xschem wire 0 0 100 0            ;# prior edit - pushes per call (precedent)
<shape command>                   ;# the fixed arm - must push
# SSU-X1 (control, shape stored):  llength [xschem objects -type <t>] == 1
xschem undo
# SSU-X2 (THE bug regression):     [xschem get wires] == 1   (prior edit SURVIVES one undo)
# SSU-X3 (undo removed the shape): llength [xschem objects -type <t>] == 0
xschem undo
# SSU-X4 (exactly one push):       [xschem get wires] == 0   (second undo peels the wire)
```

Extra checks:

- SSU-A5 (arc refusal pushes nothing — guards the push placement inside the layer gate):
  clear force; `xschem wire 0 0 100 0`; `set r [xschem arc 300 -300 50 0 180 999]` →
  check `$r == 0` && arc count 0; then ONE `xschem undo` → `[xschem get wires] == 0`
  (the refused arc left no extra slot; the single undo peels the wire itself).
- SSU-M1 (unchanged-behavior control): after a clear force + scripted rect,
  `[xschem get modified] == 1` (set_modify still fires).
- SSU-RO1..RO3 (readonly controls): clear force; one scripted rect (real edit);
  `xschem set_modify 0`; `xschem set readonly 1`; each of the three coord calls must be
  refused (`catch` rc 1 + `*read-only*` message), counts unchanged, `[xschem get modified]`
  still 0; then `xschem set readonly 0`.
- SSU-RD1 (redo control, no dedicated sabotage): after the rect block's two undos, two
  `xschem redo` calls restore wire + rect (counts 1/1).

RED FIRST: run the new test against the UNFIXED binary — it must fail EXACTLY SSU-R2, SSU-L2,
SSU-A2 (scout verified all three variants fail live today; SSU-X3/X4/A5 pass vacuously
unfixed). Then apply the edits, rebuild, re-run: all green.

### Sabotage verification

Each: edit src/scheduler.c only, rebuild, run the new test, confirm EXACTLY the target check
fails, revert by exact-string re-edit back to the fixed text (the fix lives in the same file —
no git checkout), `git diff src/scheduler.c` must then show ONLY the three intended push
lines. After ALL sabotages: one clean rebuild + full green re-run.

- SB-R → targets SSU-R2. Delete the rect push line. One undo after wire+rect restores the
  wire-push snapshot (empty) → SSU-R2 red; SSU-R3 stays green (no rect in that snapshot),
  SSU-R4 green vacuously; line/arc blocks unaffected.
- SB-L → targets SSU-L2. Delete the line push line. Same shape.
- SB-A → targets SSU-A2. Delete the arc push line. Same shape.
- SB-P → targets SSU-A5. Move the arc push ABOVE the `if(layer >= 0 && layer < cadlayers)`
  gate. The refused 999-layer arc now pushes a spurious slot, so SSU-A5's single undo restores
  {wire} instead of empty → exactly SSU-A5 red (SSU-A1..A4 stay green — valid arcs still push).
- SB-D → targets SSU-R4. Duplicate the rect push (two consecutive pushes). undo #1 still
  lands on {wire} (SSU-R2/R3 green) but undo #2 restores {wire} again → exactly SSU-R4 red.

### Suite gates

- tests/headless/full_audit.sh — NO new failures beyond the recorded batch baseline
  (PLAN.md header, 2026-07-18, 14 tests): test_cadence_descend_newwin_ro, test_cadence_drag,
  test_ciw, test_descend_untitled_preserve, test_hi_descend, test_lib_manager_gui,
  test_lib_sweep, test_phase3_mints, test_reopen_readonly, test_save_as_cellview,
  test_select_at, test_selflog_output, test_untitled_reuse, test_wire_split.
  (test_fluid_editing passed at batch-start despite the expectation note; congestion flakes
  under full-audit load have precedent — retry suspects in isolation and record.) The new
  test_scripted_shape_undo must be PASS.
- create_save goldens (the plan's named defer-trigger — prove it does not fire):
  `cd tests && tclsh create_save.tcl` → its summary must show no FAIL/GOLD?/FATAL. These
  scripts drive the exact edited arms (rom8k.tcl lines, 0_examples_top.tcl rects+lines) plus
  the already-pushing wire arm.

## DOCS

- doc/claude/issues/0127-scripted-rect-arc-coord-form-no-push-undo.md: Status OPEN → FIXED
  (date + commit hash), add a "What changed" section: the three one-line pushes + placement
  rationale (wire-branch mirror; arc push inside the layer gate to avoid a 0121/0125-class
  spurious push), the live-repro fact (one undo after scripted shape destroyed the preceding
  wire), and the machinery-callers analysis (create_graph.tcl / place_sym_pins.tcl per-call
  pushes accepted on the wire precedent, MAX_UNDO ring). RESIDUAL: the `text` sibling
  (scheduler.c:11187) remains OPEN — pushes nothing AND never set_modify's; needs its own
  fix decision (interactive place_text pushes at actions.c:4987).
- doc/claude/refactor_b_batch/BUGFIX_PLAN.md: the driver pipeline owns the ledger stage —
  leave item 4 for the driver unless instructed otherwise.
- Memory (per discipline): per-item detail into the batch block of
  /home/qflow/.claude/projects/-home-qflow-dev-xschem-claude-1-xschem/memory/action-logging.md;
  the MEMORY.md action-logging index line stays ONE short line (append terse
  "bugfix 0127 done" style).

## COMMIT

Explicit file list ONLY (never -a / -A):
  src/scheduler.c
  tests/headless/test_scripted_shape_undo.tcl
  doc/claude/issues/0127-scripted-rect-arc-coord-form-no-push-undo.md

Message:

```
fix(undo): scripted rect/arc/line coord forms push an undo checkpoint (issue 0127)

The scheduler coord arms for rect, line and arc stored the shape + set_modify(1)
with no push_undo, so one undo after a scripted shape rode the previous
checkpoint and destroyed unrelated edits with it. One xctx->push_undo() per arm,
mirroring the wire coord branch (scheduler.c wire arm) and the interactive twins
(new_rect/new_line/new_arc). The arc push sits inside the layer-validity gate so
a refused invalid-layer arc still pushes nothing. Scripted text (which also never
set_modify's) is recorded as a residual in the issue file.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```

Do NOT push. Do not touch junk dirs (_nhangle_* etc.) or any file outside the list above.
