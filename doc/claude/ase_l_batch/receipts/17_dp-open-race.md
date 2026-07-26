# Receipt — item 17 dp-open-race (round-5, Waveform Viewer interaction fixes)

Verdict: **FAILED** [F]. The **product fix is correct** (the user's launch→vanish
bug is genuinely fixed), but the item FAILS on the RUNBOOK's own green-suite gate:
the shipped test harness (`test_ase_plot.tcl`) intermittently fails its new P8
raise-witness — a protected suite that must stay green on a direct re-run does not
reliably do so, and this directly refutes the last fixer commit's "bypass-proof /
stable across runs" claim.

## Shipped commits (none pushed)

Three commits, all on `fluid-editing`, shipped HEAD = **2b5fc4a9**:

| Commit | What | Files staged |
|--------|------|--------------|
| `d08015f4` | feat/fix: fresh-arm raise so the first Direct Plot viewer stays; original P8 phase (99→ later 100 checks) with a `wm stackorder` witness | `src/wave_viewer.tcl` (+13), `tests/headless/test_ase_plot.tcl` (+121) |
| `6a23877b` | fixer round-1 (test-only): "real, deterministic teeth" — replaced the hollow/flaky stackorder snapshot | `tests/headless/test_ase_plot.tcl` (+39/−2) |
| `2b5fc4a9` | fixer round-2 (test-only): "bypass-proof" execution-trace witness replacing a `rename`+wrapper shim that was itself ~5% flaky | `tests/headless/test_ase_plot.tcl` (+25/−26) |

**The production code (`src/wave_viewer.tcl`) is byte-identical across all three
commits** (`git diff d08015f4 2b5fc4a9 -- src/wave_viewer.tcl` is empty). Only the
test harness churned across the two fixer rounds. Hygiene clean: exactly the two
in-scope files, explicit staging, no pre-batch dirty tracked file swept in.

## The product fix (correct, sound)

`src/wave_viewer.tcl` `wviewer::open` has two arms. The RE-OPEN arm (existing
viewer) already re-fronted the WSLg-reliable way via `raise_activate_toplevel`
(withdraw+deiconify re-map, issue 0054). The FRESH arm created the window with
`load_new_window` and never raised/focused it — and because Direct Plot entry
(`select_on_design`/`design_window`) raises the DESIGN window `.` to the front, the
freshly-mapped viewer landed BEHIND it and never came forward (raise honored only at
map time). Created-but-stacked-under, NOT destroyed → the user saw "launch then
VANISH"; the 2nd Direct Plot hit the RE-OPEN arm whose re-map WSLg honors, so it
"appeared." Fix = finish the FRESH arm exactly like the RE-OPEN arm:
`raise_activate_toplevel $top` + `catch {focus $top}` immediately before its
`return 1`. Additive; unifies every open path (dp_finish, `~`/open_viewer,
auto_plot, restore); leaves the raise-not-duplicate RE-OPEN arm and design_window's
raise untouched. Root-cause is honest and matches the code.

## Why FAILED (outstanding problems)

1. **PRIMARY — flaky protected suite (the refutation).** The item requires
   `test_ase_plot` to STAY GREEN on a direct re-run with the correct invocation
   (`DISPLAY=:0 src/xschem --pipe -q --nolog --script tests/headless/test_ase_plot.tcl`).
   On a clean re-run the verifier hit `RESULT: 1 FAILED (99 passed)` with
   `FAIL: P8 fresh open raised the new viewer (item-17 fix witnessed) -> {0} (exp {1})`.
   Crucially the surrounding legs all PASSED in that same run (viewer opened,
   mapped, exactly ONE new toplevel, STAYS) — only the raise-witness missed. The
   witness (`trace add execution raise_activate_toplevel enter ::dp_raise_spy` at
   test_ase_plot.tcl ~:566-569; assert `[lsearch -exact $::dp_raise_log $vtop] >= 0`
   at ~:600-601) intermittently fails to record the fresh-arm
   `raise_activate_toplevel $top` that `src/wave_viewer.tcl:307` runs
   unconditionally (`window_for` returns exactly that `$top`, so a populated log
   would always match — the miss is a trace-firing flake). Rate ~1 in ~10
   witness-executing runs (1 fail then 3+6 subsequent PASS observed), nonzero. This
   contradicts commit `2b5fc4a9`'s claim that the execution-trace witness is
   "bypass-proof … no bypass is possible" and the implementer's "Full suite 99
   checks ALL PASS (stable across repeated runs)". The flake is in the TEST
   harness, not the product.

2. **Claim-vs-shipped drift (context).** The implementer report describes commit
   `d08015f4` with 99 checks and a `wm stackorder` witness; shipped HEAD is
   `2b5fc4a9` (100 checks, execution-trace witness). The two fixer commits' own
   comments (test_ase_plot.tcl:547-565) call the stackorder check "HOLLOW … ~30%
   FLAKY" and the rename-wrapper "~5% FLAKY" — so the report's "99 checks ALL PASS
   stable" describes a superseded test; the currently-shipping witness is the one
   that flaked. The product fix is correct regardless.

3. **Honest non-attribution (kept separate so the primary finding is not
   conflated).** The same suite also flakes heavily on P4/P6/ESC WSLg gesture legs
   (e.g. `P4 REAL ESC ended the mode -> {0}`, `P4 exactly ONE new graph appended`,
   `P6 model graphs STILL 2`). The verifier checked out the pre-item-17 baseline
   (`28dc858b`) of both files and reproduced the SAME 10-failure pattern
   (`RESULT: 10 FAILED (75 passed)`), so that P4/P6/ESC WSLg flakiness is
   PRE-EXISTING and NOT item 17's regression. Item 17 added a NEW flake mode
   (the P8 raise-witness) on top of an already WSLg-flaky suite.

Net: user bug fixed, but the deliverable's test does not meet the batch's
stay-green gate; two fixer rounds could not make the witness deterministic on this
WSLg box.

## Fix-round history

- **Original (`d08015f4`).** Product fix + P8 phase using a `wm stackorder`
  snapshot witness (`wm stackorder` end = viewer).
- **Round-1 fixer (`6a23877b`, test-only).** Verifier found the stackorder witness
  HOLLOW (a freshly-created viewer is naturally last in a scripted driver's
  stackorder — passed even with the product fix reverted) and ~30% flaky. Replaced
  it with a `rename raise_activate_toplevel` + wrapper shim that logged the raise
  target.
- **Round-2 fixer (`2b5fc4a9`, test-only).** The rename-wrapper shim was itself
  ~5% flaky — `wviewer::open` is byte-compiled and already ran in P1-P7, so its
  cached command resolution intermittently still pointed at the renamed real proc
  and BYPASSED the wrapper. Replaced with an `trace add execution … enter`
  execution trace on the command object, claimed "bypass-proof." **This is the
  witness that flaked ~1/10 in the verifier's clean re-runs**, defeating the claim.
- **Round-3: none** (2-fixer-round cap reached; verdict FAILED).

## Sabotage table (from the original commit; each failed EXACTLY its target)

| # | Sabotage | Target | Exact? |
|---|----------|--------|--------|
| S1 | dp_finish `wviewer::open $key` → `expr 0` (suppress open), ase_window.tcl | all P8 open-race checks (opened / mapped / exactly ONE / STAYS / raise-witness + all three second-plot checks) FAIL; mode-end + PH/P1-P7 green | yes |
| S2 | re-open arm `if {[dict exists …]}` → `if {0}` (disable re-open), wave_viewer.tcl | P8 "second Direct Plot raises the SAME viewer" + "second added no new toplevel" FAIL (duplicate, count N0+2); first-open legs + second-viewer-exists green | yes |
| S3 | raise `.` back over the fresh viewer after the fix, wave_viewer.tcl | P8 "first viewer top of stackorder" FAILS (proves the top-of-stack check had teeth); exists/mapped/count/STAYS + second-plot legs green | yes |

Note: S3 targeted the **original** stackorder witness (d08015f4), which the fixer
rounds later removed as hollow — so the S3 sabotage no longer maps 1:1 to the
shipped test. Reverts were `git checkout` (ase_window.tcl, clean) + targeted
Edit-revert (wave_viewer.tcl, which carries the fix); scratch prelude overrode
`auto_execok` to force `have_ng=0` so ngspice-gated P1/P3-P6 stay skipped and each
sabotage isolates to its P8 legs.

## Protected suites (implementer-reported direct green runs)

`test_ase_plot` 99/100 (flakes P8 witness — see above), `test_wave_viewer` 149,
`test_ase_view` 36, `test_ase_window` 155, `test_ase_dialogs` 133,
`test_ase_interact` 63, `test_ase_persist` 109, `test_ase_launch` 38;
`test_ase_core` 66 + `test_ase_final` 28 pass under `--nogui` (both are in
full_audit's nogui_tests list; running them WITHOUT `--nogui` hits a pre-existing
do_run current-schematic focus race that reproduces at HEAD with item-17 files
stashed — not a regression). `test_ase_dirty` self-SKIPs (known WSLg display
flake, benign). No non-baseline full_audit fail attributable to the pure-Tcl
wave_viewer.tcl change (only exercised by ASE/viewer opens).

## Corrected anchors worth keeping (verified at HEAD 2b5fc4a9)

- **The fix**: `src/wave_viewer.tcl:307` `raise_activate_toplevel $top` +
  `:308 catch {focus $top}` before `:309 return 1`, at the end of the FRESH arm of
  `wviewer::open` (proc at :~230-309). The RE-OPEN arm's own raise is at
  `wave_viewer.tcl:229`; `wviewer::window_for` at :167 (returns the same `$top`).
- **The flaky witness**: `tests/headless/test_ase_plot.tcl` — spy install
  `trace add execution raise_activate_toplevel enter ::dp_raise_spy` (~:566-569),
  first-plot assert `P8 fresh open raised the new viewer (item-17 fix witnessed)`
  `[lsearch -exact $::dp_raise_log $vtop] >= 0` (~:600-601), witness rationale
  comment block :547-565, trace/spy teardown ~:630-632. Total ~100 checks
  (101 `check*` invocations in file; P8 legs run only under DISPLAY).
- Anchors from the PLAN that still hold conceptually: `dp_finish`,
  `select_on_design` + `sod_end` in `ase_window.tcl` are the mode entry that raises
  the DESIGN window `.` — this is what the fresh viewer had to out-raise; but
  `ase_window.tcl` was **left clean** (untouched) by the shipped fix (raise-alone
  in wave_viewer.tcl, no dp_finish idle deferral needed).

## Recommendation for any re-attempt (not part of this item's verdict)

The product fix should be KEPT (user bug is fixed). A re-attempt should make the P8
raise-witness deterministic — e.g. assert the observable end-state
(`wm stackorder`/focus after a bounded settle poll) rather than instrumenting a
byte-compiled proc, or move the witness onto a value the product writes
synchronously — and/or quarantine the pre-existing P4/P6/ESC WSLg gesture flakiness
so the suite meets the stay-green gate.
