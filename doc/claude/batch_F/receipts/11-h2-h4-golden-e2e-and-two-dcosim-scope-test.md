# Batch F item 11 — H2 + H4: the golden end-to-end run, and the two-`d_cosim` scope test
## 1. Files changed
`git diff --stat` (tracked) + `wc -l` (new). **No production code changed:** `git diff --stat -- src/` is EMPTY and `src/ase.tcl` md5 `21f13fc1299dbf39ea17ddd3dc6976e1` = HEAD, after 26 sabotage patches to it.
```
 doc/claude/specs/mixed_signal_signal_browser.md |   4 +-    H2 and H4 rows rewritten
 tests/headless/full_audit.sh                    |   2 +-    +test_cosim_golden_e2e in nogui_tests
 tests/headless/test_ase_cosim.tcl               | 201 +++-  TD group; 310 -> 333 checks
 NEW tests/headless/test_cosim_golden_e2e.tcl            435 lines, 46 checks
 NEW tests/headless/gold/cosim_e2e_counter.golden        108 lines, 72 edge records
 NEW doc/claude/batch_F/receipts/11-h2-h4-...md          this file
```
## 2. Decisions taken, and the evidence
1. **The guard must never print a skip banner** (ruled into the spec's H2 row). `full_audit.sh:128` scores the WHOLE FILE as SKIP on `RESULT: SKIP` / `skipped: no X` / `SKIP: no X`, discarding every check that already passed; the GE arm therefore prints `note: group GE not run -- absent: <what>`. Measured BOTH arms with a shadow PATH (symlinks to every executable in /usr/bin, /usr/local/bin, /bin except the four `verilator*`): guard present -> `RESULT: ALL PASS (15 checks)` and `full_audit` PASS / 0 skip; guard deleted (S16) -> 15 red, `RESULT: 15 FAILED (31 passed)`, `full_audit` **FAIL**. Never SKIP either way.
2. **The golden is the six INTERNAL counter signals and deliberately no PORT** — a port is in the analog raw too and would prove nothing about the VCD (golden header + spec H2 row; asserted by GG4/GG5 and GE23/GE23b). **Pinned exactly, no tolerance**, at the shipping `tran 10p 2u` and the shipping build config item 12 (`1e5c2b64`) recorded — trace, non-timing, no `-t`. Determinism measured (two independent ngspice runs, byte-identical VCD prefixes), not assumed; GE11/GE13/GE16 assert the config instead of trusting it.
3. **A broken golden must FAIL, not CRASH** (ruled at review; spec H2 row). The silent-discard hazard is reachable through the golden, which its own header invites a reader to regenerate. `gold_parse` now catches `llength` (an unbalanced brace is not a valid Tcl list and THROWS); GG11/GG14 perturbations gate on `[llength $GOLD] > 1` while their checks stay ungated; GG3/GG5/GG10 require `> 0`. Measured: golden absent -> `RESULT: 13 FAILED (2 passed)` + `full_audit` FAIL (before: no RESULT line at all, scored crash); malformed record -> `RESULT: 4 FAILED (11 passed)`, GG3 red.
4. **GE10 plants a decoy** (ruled at review). The rundir is a per-pid scratch dir created this run, so `![file exists $vcdf]` was true BEFORE `cosim_clear_artifacts` ran and the check passed with the clear stubbed out. It now writes a stale file at `$vcdf` and asserts the returned `gone` list NAMES it; P11a reddens GE10 and only GE10.
5. **H4's discriminating fixture** (spec H4 row): two DIFFERENT cells whose `.v` files declare the SAME module (identical hints, ambiguous module rung) plus two instances of ONE cell (multi refusal). Why it was needed: sabotage S1/P1 (first-match resolver) reddens 9 FS checks yet every FS end-to-end resolve still answers `ok` — one `d_cosim` instance cannot catch it.
6. **TD7/TD8 assert the rung NUMBER, not the KEY** (ruled at review; spec H4 row). Here the `.model` card names separate the entries as well as lib/cell does, and a rung 1 re-keyed onto the model card (S30) reddened 5 FS checks and NOT ONE TD check. `TD7b` (an `f1` with no model card) and `TD8b` (a model card deliberately contradicting its lib/cell -> `got 'mdx 1' want 'mdy 1'`, a WRONG ANSWER not a refusal) name the key. Lens 3's alternative — two cells sharing one model card name — was rejected: the netlister folds same-named cards into one `multi` card, breaking TD1's `{8 3}` premise that 21 other checks rest on.
7. **TD16 is a FIXTURE PREMISE, not evidence** (it asserts the fixture VCD's own scope tree), and **TD17 was MOVED above TD16** because TD16's own `raw switch 0` made it green with the inventory restore deleted. Both in the spec H4 row and in a warning comment in the test file.
8. **Correction ruled and written**: the spec H4 row and the FS group header both claimed "no verilator on this machine". False — `/usr/bin/verilator` 5.020 is installed, and H2 now uses it. Corrected in the spec and in a comment in `test_ase_cosim.tcl`; what remains true is that no Verilog here produces a genuinely inlined VCD.
## 3. Tests, check count, verbatim RESULT lines
`GUI_GATE=1 DISPLAY=:0 tests/headless/run_suites.sh --nogui test_ase_cosim test_cosim_golden_e2e`
```
PASS     | test_ase_cosim               run 1/2  RESULT: ALL PASS (333 checks)
PASS     | test_cosim_golden_e2e        run 2/2  RESULT: ALL PASS (46 checks)
RESULT: 2/2 runs passed
```
Guard arm, shadow PATH without verilator — the file itself, then `full_audit.sh` on that one file:
```
note: group GE not run -- absent: verilator
RESULT: ALL PASS (15 checks)
PASS     | test_cosim_golden_e2e
SUMMARY: 1 pass  0 fail  0 crash/timeout  0 skip  (total 1)
```
**AUDIT — a diff by NAME and STATUS against `doc/claude/batch_F/baseline_status.txt` (7a592f9c), which EXISTS.** `GUI_GATE=1 DISPLAY=:0 tests/headless/full_audit.sh`, complete run: `SUMMARY: 290 pass  20 fail  0 crash/timeout  0 skip  (total 310)` / `WIREEDIT: ALL PASS` / `SCRATCH: 0 leaked dir(s)`. (The 58 "missing" `test_wireedit_*` names are an artefact of the baseline listing them individually where full_audit collapses them into one WIREEDIT line — not a real diff.)
- **NEW rows (not in the baseline), all PASS:** `test_backannotate_digital`, **`test_cosim_golden_e2e`** — this item's file, green inside the audit's own `--nogui` arm — `test_wave_cursor_crossdb`, `test_wave_sigbrowser_digital`.
- **GREEN-ward (11):** `test_ase_persist`, `test_ase_plot` (TIMEOUT->PASS), `test_fluid_bodyshove_guards_0132`, `test_fluid_editing`, `test_placement_wire_gate` (TIMEOUT->PASS), `test_rotate_stretch_dangling_0103` (SKIP->PASS), `test_wave_axis_zoom`, `test_wave_crossdb_trace`, `test_wave_markers`, `test_wave_sigbrowser_i12`, `test_wire_vertex_grab` — all FAIL->PASS unless marked. Expected: the baseline is 7a592f9c and batch F items 1-10 and 12 landed between it and this run; the five `wave_*` rows are what those items fixed.
- **RED-ward (2), both re-run:** `test_wave_trace_menu` PASS->FAIL, re-ran `RESULT: ALL PASS (397 checks)`. `test_wave_sigbrowser_i1315` PASS->FAIL, re-ran 3x NORESULT with `X connection to :0 broken (explicit kill or server shutdown)` — the WSLg Xwayland abort this batch has all day, and the row the driver's brief already lists as resolved noise. Attribution: that file contains zero occurrences of `cosim`/`golden`/`gold/`, and this item changed no production code. Neither is a regression from this item.
## 4. Sabotage table
Ids are the fix round's. Each patch was applied alone, run, then restored from a byte-exact backup with md5 verified. One row per new check; the three with no sabotage say so.

| check | what was broken | red? | restored green? |
|---|---|---|---|
| GG1-golden-file-present | golden moved aside (R6) | yes | yes |
| GG2-golden-record-count | R6; one record deleted (P24); one added (P25); malformed (R7) | yes | yes |
| GG3-golden-parses-cleanly | unbalanced-brace record appended (R7); R6; 3-token line (P26) | yes | yes |
| GG4-golden-signals | R6; bogus signal record (P25); R7/P26 | yes | yes |
| GG5-golden-has-no-ports | a PORT record added (P25); R6 | yes | yes |
| GG10-identical-is-empty | R6 only — immune to comparator sabotage by construction (a control) | yes | yes |
| GG11-one-corrupted-value-is-reported | gold_diff returns {} (R1); key drops the time (R2); R6 | yes | yes |
| GG11b-and-the-report-names-it | R1; R2; every label collapsed to "differs" (R4); R6 | yes | yes |
| GG12-a-missing-record-is-reported | R1; R6 | yes | yes |
| GG12b-missing-is-labelled-MISSING | R1; R2; R4; R6 | yes | yes |
| GG13-an-extra-record-is-reported | R1; the EXTRA sweep deleted from gold_diff (R3) | yes | yes |
| GG13b-extra-is-labelled-EXTRA | R1; R3; R4 | yes | yes |
| GG14-a-moved-edge-is-reported | R1; R2 (a move is invisible when time is not in the key); R3; R6 | yes | yes |
| GG14b-moved-is-one-MISSING-and-one-EXTRA | R1; R2; R3; R4; R6 | yes | yes |
| GG15-empty-measurement-is-not-a-pass | R1; R2; P24/P25/P26; R6; R7 | yes | yes |
| GE1-rundir | `ase::rundir` returns /tmp regardless of state (P19) | yes | yes |
| GE2-netlist-written | **UNSABOTAGED — not evidence**; needs the netlister broken | no | n/a |
| GE3-deck-has-the-d_cosim-card | **UNSABOTAGED — not evidence** | no | n/a |
| GE4-one-code-block | `cosim_map` appends every entry twice (P21) | yes | yes |
| GE5-map-cell | `cosim_design_scan` returns an empty dict (P10) | yes | yes |
| GE6-map-module | `dict set e module x$module` (P22) — reddens GE6 alone | yes | yes |
| GE7-map-vfile | P10 | yes | yes |
| GE8-map-not-multi | `dict set e multi 1` for every card (P4) — reddens GE8 alone | yes | yes |
| GE9-map-vcd | `cosim_policy` answers trace=0 (P12) | yes | yes |
| GE10-artifact-cleared | clear returns {} and deletes nothing (P11a); deletes but reports {} (P11b) | yes | yes |
| GE11-trace-policy-is-on | P12 | yes | yes |
| GE12-build-script-found | `cosim_build_script` returns {} (P13) | yes | yes |
| GE13-no--t-on-any-build-path | `lappend cmd -t` on the build command (P14) | yes | yes |
| GE14-build-status | P13; build given --no-such-flag (P15); P10; guard deleted, no verilator (S16) | yes | yes |
| GE15-so-produced | P13; P15; P19; P10; S16 | yes | yes |
| GE16-stamp-says-trace-1 | P12; P13; P15; P19; P10; S16 | yes | yes |
| GE17-sim_args-rewritten | `cosim_rewrite` returns its lines unchanged (P16/S20); P12 | yes | yes |
| GE18-ngspice-ran | S16 — no `.so` at all, ngspice exits non-zero | yes | yes |
| GE19-no-xspice-desync | **UNSABOTAGED — not evidence**; nothing here provokes the desync string | no | n/a |
| GE20-both-artifacts-exist | P12; P13; P15; P16; P19; P10; S16 | yes | yes |
| GE21-two-dbs | `attach_dbs` drops the vcd list (P17); + all of the above | yes | yes |
| GE22-analog-is-current | `attach_dbs` ends on `raw switch 1` instead of slot 0 (P20); S16 | yes | yes |
| GE23-internal-is-not-in-the-raw | P20 (VCD left current, so the internal name IS found) | yes | yes |
| GE23b-a-port-IS-in-the-raw | P20 | yes | yes |
| GE24a-vcd-is-current | P17; P12; P13; P15; P16; P19; P10; S16 | yes | yes |
| GE24b-measured-record-count | P17; P12; P13; P15; P16; P19; P10; S16 | yes | yes |
| GE24-matches-the-golden | golden corrupted by ONE value (P23 — reddens GE24 and nothing else); P24; P25; timing build (P14); S16 | yes | yes |
| GE24c-one-picosecond-would-fail | R1 (always-empty comparator); P12/P13/P15/P16/P17/P19/P10; S16 | yes | yes |
| GE25-half-toggles-once-at-1550012ps | P12; P13; P15; P16; P17; P19; P10; S16 | yes | yes |
| GE26-tc-fires-for-one-clock | same set | yes | yes |
| GE27-carry-fires-twice | same set | yes | yes |
| TD1-four-instances-three-cards | `cosim_design_scan` returns an empty dict (P10) | yes | yes |
| TD2-cards-join-their-own-cells | `cell` taken from the .model card name (P6); P10 | yes | yes |
| TD3-two-cells-one-hint-string | hint minted as `TOP.$cell` (P5); P10 | yes | yes |
| TD4-same-cell-twice-is-one-multi-card | `dict set e multi 0` always (P3) | yes | yes |
| TD5-the-other-two-are-not-multi | `dict set e multi 1` always (P4) | yes | yes |
| TD6-module-alone-cannot-separate-them | first-match resolver (P1) — "ambiguous" becomes an answer; P10 | yes | yes |
| TD7-rung1-picks-tdx | P1; P6; P10. NOT reddened by S30 — which is why TD7b exists | yes | yes |
| TD7b-rung1-is-libcell-not-the-model-card | rung 1 re-keyed onto the model card name (S30); P1 | yes | yes |
| TD8-rung1-picks-tdy | P1 (first-match answers mdz); P6; P10. NOT reddened by S30 | yes | yes |
| TD8b-libcell-beats-a-contradicting-model-card | S30 — WRONG ANSWER `got 'mdx 1' want 'mdy 1'`, not a refusal; P1 | yes | yes |
| TD9-three-distinct-vcd-paths | one VCD name for the design AND the collision-suffix dedupe removed (P8+P18) | yes | yes |
| TD10-a1-resolves | P1; P4; P5; P6; P8; P9; P10 | yes | yes |
| TD11-a2-resolves | hint accepted unconditionally (P2) — "derived" becomes "hint"; P1; P4; P6; P8; P9; P10 | yes | yes |
| TD12-the-two-instances-land-in-different-databases | **P1 — the mapping returns the first instance regardless**; P4; P6; P8+P18 | yes | yes |
| TD13-the-two-scopes-differ-although-the-hints-did-not | **P2 — trust the hint instead of the DB**; P1; P5; P6; P9; P10 | yes | yes |
| TD14-a2-note-names-the-hint-that-lost | P2; P1; P4; P5; P6; P9; P10 | yes | yes |
| TD15-neither-answer-is-TOP | `cosim_scope_derive` returns `derived TOP {}` — ruling 5e's forbidden answer (P9) | yes | yes |
| TD17-current-db-still-the-analog-raw-after-two-resolves | the inventory's unconditional `raw switch $cur` restore deleted (P7) | yes | yes |
| TD16-a2-hinted-scope-is-in-no-signal-of-its-db | P8+P18 — but this is a FIXTURE PREMISE, see §5 | yes | yes |
| TD20-a3-refuses-multi | `dict set e multi 0` always (P3) | yes | yes |
| TD21-a4-refuses-multi | P3 — both instances of the one cell, not just the first | yes | yes |
| TD22-the-multi-sentence-says-how-many | P3 | yes | yes |
| TD23-a1-still-resolves-beside-the-refusals | P1; P4; P6; P9 — proves TD20/TD21 do not pass by the resolver dying | yes | yes |
## 5. What was NOT verified
- **Unsabotaged, therefore NOT evidence — 3 of 69:** `GE2-netlist-written`, `GE3-deck-has-the-d_cosim-card` (both would need the netlister or the reference schematic broken) and `GE19-no-xspice-desync` (no available sabotage provokes the desync string). Positive assertions only. **One-sided controls:** `GG10` is immune to comparator sabotage by construction (`gold_diff $G $G` is empty whatever the comparator does) — it catches a comparator that reports SPURIOUSLY, and is drivable only by R6; `GG13`/`GG13b` are built from a synthesized EXTRA record and survive an absent golden by design.
- **Golden portability (declared limit):** one machine's numbers — verilator 5.020, g++ 13.3, ngspice-46 — pinned with no tolerance and regeneration instructions in the golden's header. Another toolchain could legitimately schedule dumps differently and redden the file for a non-defect. Not reproduced on any other machine. `[format %.0f]` is half-to-even at the libc boundary; no sample in the current 72 lands on a .5 ps edge.
- **Reviewer hypotheses raised and NOT confirmed (no reproducer built, nothing acted on):** the guard tests verilator, ngspice, the reference library and the build script but not the C++ toolchain `verilator --build` shells out to, so a box with verilator and no working g++ would go red rather than skip; the GE arm hands `attach_dbs` an explicit `[list $vcdf]` rather than going through `ase::last_vcdfiles`, so the production step choosing WHICH VCDs attach is off the measured path; and `cosim_clear_artifacts`, `render_deck`, `xschem load`/`netlist` and `raw clear` are bare calls whose failure would abort the file with no RESULT line (same class as the golden-absent finding, fixed for the golden only).
- **All four CONFIRMED reviewer findings were fixed and re-measured** (§2.3, §2.4, §2.6, and the spec H2 row's guard-deleted numbers, which were stale and are now the measured 15-red / FAIL row). Nothing was raised-but-unconfirmed and left standing.
- **A really inlined VCD still does not exist here.** The divergence fixtures synthesize the disagreeing database: the MECHANISM is proven, the PROVENANCE is not. `TD16` is a fixture premise, not independent evidence.
- **Concurrency hazard observed by a reviewer:** another agent's in-flight sabotage of `src/ase.tcl` was live in this tree around 09:31-09:33 and corrupted one measurement. Every green run reported here is md5-bracketed against HEAD's `ase.tcl`; anything measured in that window is untrustworthy.
- **Process error, reported:** an early sabotage batch was launched while a full_audit was running and timed out mid-run, leaving one test file patched for ~2 minutes; that audit was KILLED and re-run from scratch rather than trusted (~20 minutes lost, mine not the gate's). **No eyeball owed.** The payload is two test files, a golden and two spec rows — text, not pixels.
