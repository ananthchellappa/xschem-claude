# Receipt — item 13 ase-plot (round-3, Waveform Viewer)

Verdict: **DONE** [x]. Commit (NOT pushed; amended twice pre-report for
test hardening — item-11 precedent):
- `10649ec8` feature — ASE wired to the waveform viewer: Direct Plot
  click mode, Plot-checkbox auto-plot, `~` button, raw attach
  (`src/ase.tcl` +36, `src/ase_window.tcl` +232/-..,
  `src/wave_viewer.tcl` +97/-.., `tests/headless/test_ase_plot.tcl`
  +499 NEW, `tests/headless/test_ase_window.tcl` +14/-..; exactly 5
  files staged explicitly, no pre-batch dirty tracked file swept in).

Outstanding problems: none (verified clean — empty problem list at
ledger time). Working tree clean at HEAD for all five committed files.
Pure Tcl, zero C changes, no rebuild needed. No fixer rounds.

NOTE for the driver's ledger commit: `doc/claude/specs/waveform_viewer.md`
gained the item-13 "ASE integration" D12 note in the WORKING TREE only —
the file is **untracked** (`??` in git status, never committed by any
item). The implementer deliberately left it out of the feature commit;
it rides with the ledger/spec commit.

## What landed

Per prompts/item13_ase-plot.md D1-D13:

- **Results > Direct Plot LIVE (deliverable 1)**: item-08
  `select_on_design` gained a `{mode outputs|plot}` flavor. Plot mode
  queues TRACE expressions via `dp_queue` — wire click → `v(net)`,
  terminal click → current per item-08's documented v1 scope — and
  NEVER writes session outputs (D2, test-asserted). ESC → `dp_finish`:
  op-only gate notice (ciw_echo, clean mode exit, no crash) / viewer
  raised-or-opened for the session / `ase::last_rawfile` attached /
  queued signals appended to ONE new stacked graph per invocation.
  No run yet → ciw_echo "run first", no crash, mode exits clean.
- **Outputs Plot checkboxes LIVE (deliverable 2)**: `ase::ui::auto_plot`
  runs after each successful `ase::run` — always-replace v1 policy via
  an `auto 1`-marked graph + `clear_graph_traces` (the auto graph is
  cleared and rebuilt each run; user Direct-Plot graphs untouched).
  Zero plot-checked rows never opens a viewer; no run → checkboxes
  just persist.
- **`~` strip button LIVE (deliverable 3)**: raise-or-open the
  session's viewer, no traces added; disabled state removed on both
  the strip button and the Results menu entry (D13).
- **Raw wiring (deliverable 4)**: `ase::plot_sim_type` (last enabled
  analysis in op/dc/ac/tran emit order), `ase::last_rawfile <session>`
  (file-existence == has-results), `wviewer::attach_raw` (raw clear +
  raw read + regenerate = the re-run replace path; D9 stale-vector
  semantics test-witnessed), `plot_map_expr` maps `-i(v1)` →
  `i(v1) -1 *` for the viewer's RPN.
- **Session lifecycle (deliverable 5)**: closing the ASE session closes
  its viewer — a hook was ADDED; the brief's "already item-11
  semantics" claim was confirmed FALSE (D10). Re-run replaces the raw
  through attach_raw; stale-vector traces re-resolve or show cleanly.

## Tests

`tests/headless/test_ase_plot.tcl` — NEW, **85 checks, GUI arm ALL
PASS; 25 of them also pass under `--nogui`**. Fixture = committed
test_nfet_final CLONED into scratch + scratch library.defs; real ESC
delivered via the item-08 I7 focus-gated retry loop; ngspice-verified
(`xschem raw list` carries v(d)/i(v1) verbatim — probed, not assumed).
Phases: PH prep, P1/P2 seams, P3 auto-plot (viewer opened/mapped, raw
loaded/sim_type/points, auto graph, traces, node exprs, raw index),
P4 Direct Plot (queue, one-new-graph, not-the-auto-graph, v(d)+i(v1),
auto untouched, raw-add `id` vector dies on re-attach), P5 `~`
raise (same toplevel), P6 re-run (auto graph REBUILT — points,
sim_type, `id` re-materializes — DP graph intact), P7 op-only notice.
Test cleans its `_ase_plot_*` scratch (verified none left).

- All protected suites green by DIRECT runs at the final product code:
  test_ase_core 66, test_ase_final 28 (`--nogui` arm), test_ase_view
  36, test_ase_dialogs 133, test_ase_window 155 (with the 2 justified
  assertion flips, below), test_ase_interact 63, test_wave_viewer
  149 GUI + 36 nogui.
- full_audit: launched (scratchpad/full_audit_item13.log), still in
  flight at forced-report time (receipts/08+12 precedent); partial
  output all PASS except test_ase_dialogs, which passed 133/133 in a
  direct run this session (WSLg audit flake class, rerun-first policy).
  nonBaselineFails=[] stands on the partial audit + direct green runs
  of every touched suite; the verifier lenses subsequently confirmed
  (outstanding problems empty).
- KNOWN FLAKE (pre-existing, NOT a regression): test_wave_viewer GUI
  arm intermittently dies at G9-reopen with `invalid command name
  ..wvmenubar` (load_new_window leaves .drw current — WSLg
  focus/window-creation race). A/B PROOF: with pristine HEAD tcl files
  (XSCHEM_SHAREDIR copy) 4/6 runs failed vs 2-3/7 with the change —
  environmental; passes direct re-runs.

## Sabotage table (each post-commit, `git diff`-confirmed
sabotage-only, targeted `git checkout -- <file>` revert, clean re-run
green 85/85)

| # | Sabotage | Target | Failed exactly? |
|---|----------|--------|-----------------|
| S1 | `ase::ui::auto_plot` early-returns (src/ase_window.tcl) | auto-plot family, 19 fails: P3 x10 (viewer opened/mapped, raw loaded/sim_type/points, auto_graph_index, traces-count, node v(d)/id, raw index id), P4 x2 (auto-untouched, re-attach-cleared-id), P5 x1 (same-toplevel: viewer first created by P4 dp_finish), P6 x6 (graphs-still-2, auto-present, auto-rebuilt, points, sim_type, id-rematerialized); PH+P1+P2+P4 Direct-Plot core+P7 stayed green | yes |
| S2 | `dp_finish` discards the queue after the raw attach (src/ase_window.tcl) | exactly 5: P4 one-new-graph, P4 not-the-auto-graph, P4 traces v(d)+i(v1), P6 graphs-still-2, P6 DP-graph-untouched; P3 auto-plot legs green | yes |
| S3 | `attach_raw` drops the raw clear + raw read pair, regenerate kept (src/wave_viewer.tcl) | exactly 12: P3 raw loaded/sim_type/points + auto-graph-traces-count + node-id + raw-index-id, P4 auto-untouched + re-attach-cleared-id, P6 auto-rebuilt + points + sim_type + id-rematerialized; PH and Direct-Plot core green | yes |

## Fix-round history

None — single feature commit (amended twice pre-report for test
hardening), no verifier-raised problems, no fixer commits.

## Implementer deviations (accepted, reality-forced)

- (1) **LANDMINE FIXED — run_finished fires inside `ase::wait`'s
  semaphore bracket**, where the `new_schematic` window switch silently
  no-ops (xinit.c:1755). Running auto_plot there aimed `clear_drawing`
  at the DESIGN and EMPTIED it (probe-verified — P6 netlist lost all
  devices). Fix: auto_plot deferred via `after idle` (`auto_plot_idle`
  keeps the D5 catch) + new `wviewer::switch_ctx` guard verifying
  destructive context switches took effect (`with_edit` errors loudly,
  attach_raw/add_trace bail). This touches with_edit/add_trace beyond
  the prompt's "no other wave_viewer changes" — recorded here as the
  required justification.
- (2) **`raw read` type arg**: attach_raw OMITS the type argument when
  sim_type=={} — the C command treats an absent arg differently from an
  empty-string arg.
- (3) **Relative Direct-Plot graph assertions**: P4/P6 assert
  one-new-graph + not-the-auto-marker (not absolute indices) so each
  sabotage fails exactly its own set.
- (4) **P6 switches to .drw before the re-run invoke**: P5's viewer
  raise leaves WSLg focus events in flight and do_run's design-current
  guard honestly refuses during its update — the switch replicates the
  user's actual click.
- (5) **Extra D9 witnesses**: P4 asserts the raw-add `id` vector DIES
  on re-attach, P6 asserts it RE-MATERIALIZES — honest proof the auto
  graph is rebuilt, not stale.
- (b-style flips) **test_ase_window W1m/W1s assertions flipped**
  (disabled → live for the Results entry and `~` button): keeping them
  would contradict this item's deliverables 1+3 — item-12 deviation-b
  precedent; this receipt is the required justification.
- **D10 correction**: the item brief claimed session-close-closes-viewer
  already existed from item 11 — false; the hook was added here.

## Corrected anchors worth keeping (verified at 10649ec8)

- `run_finished` callbacks execute inside `ase::wait`'s semaphore
  bracket where `new_schematic` switching silently no-ops
  (xinit.c:1755) — any callback that must change window context MUST
  defer via `after idle`, and destructive viewer ops go through
  `wviewer::switch_ctx` which verifies the switch took effect.
- `xschem raw read`: absent type argument != empty-string type argument
  in the C handler — omit the arg entirely when sim_type is unknown.
- `ase::last_rawfile <session>` is the has-results predicate
  (file existence); `ase::plot_sim_type` derives the raw type from the
  last enabled analysis in op/dc/ac/tran emit order — item 14's
  persistence/acceptance work should reuse both seams.
- Viewer trace polarity for currents: `plot_map_expr` rewrites
  `-i(v1)` → `i(v1) -1 *` (RPN) — reuse rather than reinvent.
- Direct Plot never writes session outputs; the auto-plot graph is
  identified by its `auto 1` marker in the wviewer model — item 14's
  state round-trip must preserve that marker to keep the
  always-replace policy working after reload.
