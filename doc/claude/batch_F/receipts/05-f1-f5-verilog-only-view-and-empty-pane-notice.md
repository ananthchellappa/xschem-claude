# Batch F item 05 — F1: the verilog-only branch, F5: the empty-pane notice

**Verdict [E] — eyeball pending.** The branch and the notice-cause selection are proved headlessly and
sabotaged, but F5's payload is *rendered text in a pane* and F1's *a tree that re-scopes itself*; no check can
say whether either READS sensibly. §5 says what to look at.

**PROCESS WARNING.** Implementer, verifier and all three reviewers DIED without reporting. Code and tests were
found already written in the tree beside a 305-line self-receipt nobody had confirmed. This receipt REPLACES
it: every number and sabotage row below was re-measured by the closer, and its unconfirmed claims are listed
as unverified in §5 rather than adopted.

## 1. Files changed

| file | +/- | what |
|---|---|---|
| `src/ase.tcl` | +170/-19 | `cosim_scope_for_state` becomes a wrapper over new `cosim_scope_for_f1` (takes an f1 the caller already read); new `browser_digital_probe`, `browser_digital_msg`; `show_in_browser_for_current` gains step 3c (the probe, ABOVE the raise), a digital arm in step 6, step 7 (the notice, last). |
| `src/wave_viewer.tcl` | +309/-1 | new `browser_show_db_scope`, `browser_notice`, `browser_db_group_id`, `browser_rows_headered`, `browser_row_exists`, `browser_names_under`; 11th `browser_msg` kind `alldbs`; empty-pane notice arm in `browser_sea_draw`, cleared by `browser_sea_refresh`; new array `browserseanote`, declared in `forget` and unset with its siblings. |
| `tests/headless/test_ase_cosim.tcl` | +357 | **FV** group, 40 checks (FV0–FV40); 264 → 304. |
| `tests/headless/test_wave_sigbrowser_digital.tcl` | **NEW** 242 | **FD** group, 18 checks; auto-enrolled by `ls test_*.tcl`. |
| `tests/headless/test_wave_sigbrowser_keys.tcl` | +16/-3 | `BK33` restated (§2). |
| `doc/claude/specs/mixed_signal_signal_browser.md` | +77/-4 | F1/F5 closed, F2 updated, RULINGS F1a–F1d, H7 row, status line. |

No C changed; no rebuild needed.
## 2. Decisions and evidence

Four open questions were ruled; the rulings and their rationale live in
`doc/claude/specs/mixed_signal_signal_browser.md` §F. Each below with the evidence that decided it.

* **F1a — the gate is "the cell HAS a `verilog` view", not "has ONLY a verilog view"** (the brief said "ONLY",
  the spec's F1 row "has a"). Decided by: `cosim_scope_for_instance` answers `nodigital` for any analog cell, so
  entering the branch for every instance would put "has no digital signals of its own" in the CIW on every
  Ctrl-Alt-V in an analog design, training the user past the very notice F5 delivers. `FV2`/`FV3`/`FV38`.
* **F1b — a refusal FALLS THROUGH to the shipped analog walk, and the notice is written LAST.** Decided by:
  refusing outright trades a partial answer for none, and a notice written before the fall-through's own output
  is the sentence nobody sees. `FV34` pins the live sequence `f1 open show_path show_path notice`.
* **F1c — the tree is re-scoped to the digital DB on a positive test, and says so** (`alldbs`). Decided by:
  with the All-DBs box off a VCD's rows are not in the tree at all, so the branch would be dead on a default
  browser. The box is invoked only after that DB's inventory is confirmed to carry the scope; the tick is put
  back if it did not help.
* **F1d — the notice is RENDERED, not composed** (one fixed prefix on the resolver's own sentence). Decided by
  item 4's rule: "a notice that describes a different no-match behaviour than the code implements is worse than
  no notice."

**F5's three causes map to the real codes** (`FV10`–`FV20`): no VCD loaded → `notloaded`; trace not enabled →
`notraced`; no mapping → `nomap` or `noscope`; plus `nopane`, minted by F1 for a scope that resolved but the
tree could not reach. `FV18` asserts the sentences are mutually DIFFERENT, so a notice that collapsed them
could not pass by satisfying each check singly. **`BK33` is restated, not renumbered:** `alldbs` is an 11th arm
so its `return ` count moves 10 → 11, the nine shipped sentences stay byte-identical, and the new one is
asserted BESIDE them (sabotage S9 proves it kept its teeth). **Closer's decision to land it:** the alternative
was discarding working, spec-documented code, so every claim was instead re-measured (§3) and six sabotages
run (§4).

## 3. Tests and verbatim RESULT lines

* `test_ase_cosim.tcl` (`--nogui`), 40 new checks: `RESULT: ALL PASS (304 checks)`
* `test_wave_sigbrowser_digital.tcl` (`:0`), NEW: `PASS     | test_wave_sigbrowser_digital run 1/2  RESULT: ALL PASS (18 checks)`
* `test_wave_sigbrowser_keys.tcl` (`:0`): `PASS     | test_wave_sigbrowser_keys    run 2/2  RESULT: ALL PASS (48 checks)`

### Audit — a DIFF against `doc/claude/batch_F/baseline_status.txt`

`full_audit.sh`, `DISPLAY=:0`, `GUI_GATE=1`, panel live (pid 3122619, `control=RUN`; logged `approved batch
window open … (no prompt)`). Panel never launched/killed/re-armed/written to; no Pause, no Stop; no hidden
display, no Xvfb; X did not die. Baseline EXISTS (`7a592f9c`, same `:0`). **307 rows** (306 + the new file):
**273 PASS / 31 FAIL / 3 TIMEOUT**; `WIREEDIT: ALL PASS` 58/58; `SCRATCH: 0 leaked dir(s)`. **NEW (1):**
`test_wave_sigbrowser_digital` PASS.

**RED → GREEN (6):** `test_fluid_bodyshove_guards_0132`, `test_fluid_editing`, `test_wave_crossdb_trace`,
`test_wire_vertex_grab` (FAIL→PASS); `test_rotate_stretch_dangling_0103` (SKIP→PASS);
`test_wave_sigbrowser_i12` (FAIL→PASS — the one suite driving `show_in_browser_for_current` end to end;
re-confirmed standalone, 124 ALL PASS).

**GREEN → WORSE (11):** `test_ase_dialogs` (→TIMEOUT), `test_ase_interact`, `test_cmdmode_descend_0201`,
`test_multi_window`, `test_wave_modes`, `test_wave_sigbrowser`, `test_wave_sigbrowser_i1315`,
`test_wave_sigbrowser_keys`, `test_wave_sigbrowser_sea`, `test_wave_tabs`, `test_wave_viewer`. Red→red
flavour changes: `test_ase_plot` (TIMEOUT→FAIL, its known P4/P6/P8 flake), `test_ase_window` (FAIL→TIMEOUT).

**None of the 11 is attributable to this item, and that was MEASURED, not assumed.** Every failing check names
key or focus delivery (`G5 Insert + w delivered`, `G9a Ctrl-W was delivered`, `TG16 a real Ctrl-N opened a
tab`, `BR25 <Return> … reaches the commit path`, `TD9 ESC disarmed both gestures`, the `BQ65`–`BQ73`
search-bar family). Five were re-run standalone, then both sources reverted to HEAD (`git show HEAD:`) and the
identical five re-run — `test_wave_sigbrowser` **7 failed with the item vs 12 at HEAD**, `_sea` **24 vs 27**,
`_i1315` 1 (BR25) vs 1, `test_wave_viewer` 4 vs 3, `test_wave_modes` 1 (MG16) vs 1. Two fail MORE at HEAD than
with the item — a flaky delivery path, not a regression. Sources restored from backups, md5 verified.

**Item-4 carry-over, answered with evidence.** Receipt 04 left `test_wave_sigbrowser_keys` and `test_wave_tabs`
unexplained; both are worse again here. `_keys` was chased to the bottom: its failing check is `BK40`, whose
diverging leg is `bs_type` returning the literal sentinel **`no-focus`** — the helper tries 50 times over ~1 s
to force focus onto the search entry, then gives up. Reverted to HEAD, **BK40 failed 4 of 5 standalone runs**;
with the item, 2 of 3 — a pre-existing WSLg focus-delivery flake confirmed from both sides, NOT this item and
NOT the new normal. `test_wave_tabs` (TG16, a bare `event generate` Ctrl-N that did not arrive) is the same
documented family but was NOT re-measured at HEAD, so it is attributed by evidence-of-kind only. No test went
red here that is red-free in the baseline and attributable to this item.

## 4. Sabotage table

Six, run by the closer one at a time, each restored from a byte-exact backup with md5 verified after every
restore (`src/ase.tcl` 644c084e…, `src/wave_viewer.tcl` 0715b11b…).

| # | what was broken | went red? | restored green? |
|---|---|---|---|
| S1 | verilog-only branch deleted (probe call removed from step 3c) | YES — FV32–FV39 (8) | YES, 304 |
| S4 | design-context probe moved BELOW `wviewer::open` | YES — FV32 33 34 36 38 39 | YES, 304 |
| S3b | WRONG notice cause: untraced run reported as `notloaded` | YES — FS42, FV12 | YES, 304 |
| S9 | 11th `alldbs` sentence deleted from `browser_msg` | YES — BK33, FV31 | YES |
| SD1 | All-DBs box never ticked, so the VCD stays out of the tree | YES — FD13 14 15 16 21 | YES, 18 |
| SD3 | the pane draws no notice at all (canvas arm deleted) | YES — FD03, FD21 | YES, 18 |

## 5. What was NOT verified

* **No crew reported** — implementer, verifier, 0-of-3 reviewers. There is **no independent review of this code
  at all**; the closer both re-measured and landed it. No reviewer findings exist, so nothing is carried in the
  raised-but-unconfirmed or not-proven columns.
* **~24 further sabotage rows claimed by the dead implementer are UNVERIFIED and are not evidence** (S2, S5–S8,
  S10–S23, SD2, SD4–SD8 …). Six were re-run and all six behaved as claimed, which raises confidence without
  establishing the rest; checks covered only by those rows are unsabotaged here, as are **S12/S13**.
* **Keys-suite X count** differs from the dead receipt (claimed 49; measured 48, and HEAD yields 48 or 49 by
  run). Not chased. **`test_wave_tabs`** was not re-measured at HEAD (§3).
* **No real co-simulation ran** — both suites synthesize their DBs (`mkraw`/`mkvcd`), so verilator's real
  scope naming is untested.
* **The lower pane lists nothing under a foreign scope**: `browser_sea_refresh` takes own-level names from the
  CURRENT database, so selecting a VCD scope selects the node and shows an empty pane — F3's business (still
  open), and why the canvas notice is reachable at all.
* **EYEBALL OWED (the [E]).** Open the co-sim design, select the `d_cosim` instance, Ctrl-Alt-V, and judge: (1)
  the re-scoped tree — *the tool did what I asked* or *something broke*; (2) the notice in the empty pane —
  legible and sanely wrapped at default sidebar width and with the sash dragged narrow; (3) caption and status
  line CLIP the long sentence — whether F5 needs a short form there is a live design question left unsettled;
  (4) the CIW pair (what was shown, then why) reads as one account.
