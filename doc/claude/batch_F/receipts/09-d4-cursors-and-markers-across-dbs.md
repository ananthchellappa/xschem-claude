# Batch F item 09 — D4: cursors and markers across databases

Base 81a2b53f, branch `fluid-editing`, nothing pushed. Verdict **[E]**: the payload is a line of text under a waveform, so a human must look (§5).

## 1. Files changed

`git diff --stat` — 9 files, **893 insertions, 39 deletions**: spec `mixed_signal_signal_browser.md`
+249, `src/callback.c` +183, `src/draw.c` +195, `src/scheduler.c` +17, `src/wave_viewer.tcl` +126,
`src/xschem.h` +5, `tests/headless/full_audit.sh` +2/-1, `test_node_token_split.tcl` +27,
`test_wave_crossdb_trace.tcl` +128. New: `tests/headless/test_wave_cursor_crossdb.tcl` (747 lines,
93 checks) and this receipt. `draw.c` — new `graph_cursor_dbs()`/`…_rect()`, the **eighth** caller
of `node_token_split()`, never a second `%` parser. `callback.c` —
`backannotate_at_cursor_b_pos()` split into a per-database body plus a switch/restore fan-out;
`interpolate_yval()` grew HOLD + a frac clamp. `wave_viewer.tcl` — the readout bar
(`trace_cursor_value`, `interp_value`, `readout_entries`, `raw_cursor_restore`) now reads each
trace's own database.

## 2. Decisions taken, and the evidence

Eight rulings, written with their rationale into `doc/claude/specs/mixed_signal_signal_browser.md` § "D4 — cursors and markers across databases" (~lines 944-1105).

- **D4-1** resolve in the current DB **plus** every DB contributing a trace **plus** the strip's own
  `rawfile=` — a superset of D2, so a single-DB session stays byte-identical. SA reddens 33 of 93.
- **D4-2** exactly ONE DB publishes `ngspice::ngspice_data`, the entry one; merging VCD names into
  the schematic overlay is D5's question and stays open. SI/SI2/SI3.
- **D4-3** dense analog **interpolates**, a sparse event stream **holds**: C3 encodes X as 0.5, so
  interpolating across C2's one-tick step reports X for a known signal — under SB the readout is 0.5.
- **D4-4** neither kind extrapolates: before the first sample = that sample verbatim (for a VCD, the file's own first recorded state), after the last = the last. Also kills a one-past-the-end read — at the parent a cursor 0.5 us past a raw's end read 0.37500001, 0.9 us past it 0.43500002 (SDE).
- **D4-5** markers need **no** change, structurally: bound to ONE trace, hence single-DB by
  construction, already switching via `graph_wave_resolve()`, and sampling an exact point index.
- **D4-6** the **sweep column is exempt** from the HOLD (fix round): holding it froze a VCD's own `time` at the last event while the same `Raw`'s `annot_x` held the true cursor. SB6 reddens XCT2-XCT4 and leaves XC21/XC24 green — the honest split between the two rules.
- **D4-7** the X window is a **rendering** concern and does not gate resolution (fix round): a DB
  with no sample in view is rescanned over its whole sweep. Under SW7 one cursor reads two times.
- **D4-8** cursor B is a **viewer** object, not a strip object: it fans out to every
  non-`private_cursor` rect, so digital-on-its-own-strip is annotated. SS8 reddens 9, SS8b the rest.
- **Re-entrancy refusal**: `graph_cursor_dbs()` answers 0 when `xctx->raw` is not the registry's current entry, because `raw_read()` calls the annotator mid-read; without it two slots alias one `Raw` and the other leaks — a double free at the next `raw clear`. Found in review after 60 checks were green; SH reproduces it.

## 3. Tests, check counts, verbatim RESULT lines, audit diff

```
GUI_GATE=1 DISPLAY=:0 tests/headless/run_suites.sh --nogui \
    test_wave_cursor_crossdb test_node_token_split test_wave_crossdb_trace
PASS     | test_wave_cursor_crossdb     run 1/3  RESULT: ALL PASS (93 checks)
PASS     | test_node_token_split        run 2/3  RESULT: ALL PASS (168 checks)
PASS     | test_wave_crossdb_trace      run 3/3  RESULT: ALL PASS (56 checks)
RESULT: 3/3 runs passed
[GUI arm] PASS | test_wave_crossdb_trace  run 1/4  RESULT: ALL PASS (130 checks)
          PASS | test_wave_viewer         run 2/4  RESULT: ALL PASS (400 checks)
          FAIL | test_wave_markers        run 3/4  RESULT: 6 FAILED (977 passed)
          PASS | test_wave_modes          run 4/4  RESULT: ALL PASS (488 checks)
```

`test_wave_markers` is FAIL in the baseline too and did not move: the 6 are `MX7b`/`MX7d` pointer-position gestures on a display that shrank mid-session (below). New `test_wave_cursor_crossdb.tcl` (93 checks, true headless, in full_audit's nogui arm); +21 in `test_wave_crossdb_trace.tcl` (PU/XU legs); `NDX3`/`NDR7` **restated** 7→8, `NDR2`/`NDR3` deliberately left at 7 (the enumerator is not a sampler).

**AUDIT — a DIFF against `doc/claude/batch_F/baseline_status.txt` (7a592f9c; 277/26/0/2/1 over 306
+ 58 wireedit rows), by NAME and STATUS both ways.** This run: `SUMMARY: 272 pass 28 fail 1
crash/timeout 7 skip (total 308)`, `WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)`. **It spans two
X-server deaths** — `gui_test_gate/events.log` logs "panel death detected -- reviving" at 03:30:57
and 03:50:52 — and the root went 5120x1440 → **2560x1440** (NOT the 640x480 stub of issue 0310;
zero `+-327` sentinels). Collateral is correspondingly large, so every red-ward row was re-run.

RED-WARD, 14 rows, **all re-ran PASS; none is a regression** (this item touches no fluid, CIW,
ASE-pick or wire-label code): `test_add_wire_label` P→F (re-run ALL PASS 178), `test_altf5_ciw` P→F,
`test_ase_unnamed_net` P→F (F once more on AN8, then ALL PASS ×2), `test_deselect_mode` P→F,
`test_graph_context` P→F (ALL PASS ×2), `test_pristine_untitled_viewer_0172` P→F,
`test_wave_sigbrowser_i14` P→F (109); plus seven P→SKIP in the known X-gated self-skip class —
`…group_transform_0114`, `test_drag_keeps_selection` (PASS, then SKIP again inside one batch),
`…backbone_short_vertical_0098`, `…drag_onto_backbone_row_0106`, `…exit_stub_staircase_0111` (SKIP
then PASS), `…relay_reanchor_0108`, `…sibling_pin_backbone_short_0098`.

GREEN-WARD, 9 rows, all baseline-side red on a binary predating items 1-9, or absent from the
baseline: `test_ase_persist` F→P, `test_ase_plot` T→P, `test_fluid_bodyshove_guards_0132` F→P,
`test_rotate_stretch_dangling_0103` S→P, `test_wave_axis_zoom` F→P, `test_wave_crossdb_trace` F→P,
`test_wave_sigbrowser_i12` F→P, `test_wave_sigbrowser_digital` ABSENT→P (item 5's), and **this
item's own `test_wave_cursor_crossdb` ABSENT→PASS**. ARTIFACT, not a finding: 58 `test_wireedit_*`
rows read PASS→ABSENT because full_audit collapses them into `WIREEDIT: PASS`.

## 4. Sabotage table

Every check it reddens is named; each sabotage was restored **byte-exact from a backup** (never `git checkout --`) and re-run green. Every row: went red YES, restored green YES.

| # | what was broken | checks reddened |
|---|---|---|
| SA | fan-out limited to the current DB — the item's own defect | 33: XC13-XC17, XC21, XC24b, XC31-XC36, XC41-XC45, XC85, XCT2, XCT6, XCW1-XCW5, XCS1-XCS5, XCO2-XCO5 |
| SO / SN | fan-out starts at k=1 (ENTRY DB never annotated) / `annot_x`+`annot_sweep_idx` stamped only when `write_tcl`, leaving one DB stale after a move | XC11 XC12 XC17 XC23 XC23b XC24b XC43 XC45 XC51 XCT4 XCT5 XCW1-XCW3 XCS2 XCS5 XCO2 XCO5 |
| SB / SC / SD / SE | `sim_type=="vcd"` HOLD deleted / nearest-sample-AFTER on the sparse stream / frac clamp deleted / `point_not_last` back to `(p < ofs_end)` | XC16 XC21 XC22 XC24 XC31 XC33 XC73 XC74 XCW6; SE alone reddens **XC76 only** |
| SDE | BOTH halves of D4-4 reverted — the parent shape | XC16 XC31 XC33 XC34 XC37 XC74 XC76 XCT6 XCW5 XCW6 |
| SB6 / SW7 | D4-6 exemption reverted / D4-7 window-free rescan deleted | XCT2 XCT3 XCT4; XCW2 XCW3 XCW4 XCW6 XCW7 |
| SI/SI2/SI3, SF, SG2 | every DB publishes `ngspice_data` / a VCD does / namespaces merge; `extra_prev_idx` put-back deleted; fan-out's `extra_rawfile(2,…)` restore deleted | XC37 XC51-XC54 XC62 XC63 XC75 |
| SS8 / SS8b / SO9 | D4-8 sibling loop disabled / `private_cursor` exclusion removed / the `own_db_plots` clause deleted (a reviewer's own sabotage) | XCS1-XCS6, XCO1-XCO5 |
| SH / SJ | re-entrancy refusal deleted / every registry slot added to `slots` | XC19 XC81 XC82 XC84 XCS6 XCO0b XCO3 XCO4 |
| SK/SK2, SL, SM | `node_token_split()` replaced by a hand-rolled `%` parse; `node_db_prev_restore()` deleted; enumerator given a sweep resolve | XC71 XC72 XC85 NDX1 NDX2 NDX3 NDR2 NDR3 NDR7 |
| SU SV SW SX SR SR2 SQ SQ2 ST SS | scheduler `raw` verbs (read/switch/sim_type/index/value/switch_back), `extra_rawfile` what==4, the `cursor` flag arm — fixture premises | XC01-XC09b, XC0a, XC0e-XC0h, XC18, XC61, XC63, XU8 |
| TA/TJ/TB/TC | readout dedupe key, dedupe skip, empty-vec skip, name fallback | PU1-PU5, XU5-XU7 |
| TD/TE/TF/TP/TP2/TP3 | Tcl `interp_value` HOLD arm deleted / `trace_cursor_value`'s switch into the trace's DB removed / `raw switch $cur` restore deleted / `raw_cursor_restore`'s prev half removed / `raw_prev_idx` = -1 / a stray `raw switch 1` in the plain readout path (the CONTROL) | XU1-XU7, XU8b, XU9, XU9b, XU9c |
| TG/TH2/TK/TK2 | `db_suffix` returns {} / `{%zz tran}`; `add_trace` refuses the digital / analog trace | XU0 XU0b XU0c XU0d XU3 XU7 |

**UNSABOTAGED, therefore NOT evidence**: `XC0b XC0c XC0d` (fixture non-degeneracy guards), `XC83` (green even under SH — the aliasing REPLACES a slot rather than adding one; `XC84` catches that hazard), `XC91` (the file's own count), `XCT1 XCS0 XCO0 XCW1b` (leg premises on the fixture).

## 5. What was NOT verified

- **EYEBALL OWED — this is why the verdict is [E].** (1) Cursor B on a mixed analog+VCD strip: the
  digital name PRESENT on the readout line at every position, STEPPING not ramping, holding past the
  VCD's end — use a **1 ns** VCD, the reference `counter.vcd` is 1 ps and the difference is not
  eyeballable. (2) The same with the digital signal on ITS OWN strip (D4-8): both cursors on one
  vertical line, both readouts sensible. (3) The schematic voltage overlay UNCHANGED, analog only.
- All six confirmed reviewer findings were fixed and pinned (rows SW7, SS8, SO9, TP, SB6); **none
  was left raised-but-unconfirmed**. Still NOT PROVEN either way: markers exercised end to end on a
  cross-DB strip (D4-5 is a code-reading argument); multi-dataset databases (no fixture — both
  `(p+1 < ofs_end)` and D4-7's rescan alter that shape); the cursor-OFF asymmetry at `callback.c`
  ~1992, where siblings keep a live `cursor_b_val` after B is switched off (needs a real GUI motion
  event, no reproducer); `raw switch`'s `update_op()` path with two op/dc databases, which could
  rewrite the array D4-2 reserves for one publisher.
- The spec's "21 of 60 checks red at the parent" reproduces only with `draw.c` and `callback.c`
  reverted while `scheduler.c`'s new `raw annot` verb is KEPT — the shipped test cannot run at
  81a2b53f at all. The DEFECT itself was reproduced independently on the real viewer against a
  parent binary: the digital trace is absent from the readout line at every cursor position.
- **Cost unmeasured**: `graph_cursor_dbs()` walks every graph rect on every cursor motion, each
  `%`-carrying `node=` entry costs a switch+restore, and an `autoload=true` rect can read a database
  from disk on the first motion. **D5 is untouched and still open**, by D4-2.
