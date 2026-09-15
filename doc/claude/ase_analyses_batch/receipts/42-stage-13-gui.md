# Issue 1467 — Stage 13 task 2, transient noise and `trrandom`: the GUI half

**PLAN.md §13, task 2 of the driver's split** (LEDGER *Stage 13 — 📋 task split*). Files touched, and
nothing else: `src/ase.tcl` (**+308 / −5**), `src/ase_window.tcl` (**+904 / −1**),
`tests/headless/test_ase_trnoise_gui_1467.tcl` (new, **1089 lines**), `tests/run_regression.tcl`
(**+16 / −2**: `hcases` **and** `dcases`, one paragraph),
`doc/claude/issues/1467-the-transient-noise-table-had-a-deck-and-no-form.md` (new),
`doc/claude/issues/NUMBERING.md` (**+5 / −1**, pointer → 1468),
`doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md` (**+203 / −1**), `doc/claude/ase_analyses_batch/PLAN.md`
(**+13**, the §13 correction block only) and this receipt.

md5 at hand-over: `src/ase.tcl` `2c419b35…`, `src/ase_window.tcl` `cd552daa…`,
`tests/run_regression.tcl` `c827a696…`, the new suite `c9d228e7…`.

**No commit, no `git add`, no stash/restore/clean/push. `tests/run_regression.tcl` NOT run** (issue
0990 — the driver's, solo). **No C**: `make -q -C src` rc 0 before and after, `src/xschem` md5
`96fc4899…` unchanged. No simulation on any bench under `sky130A/`. ⚠ **HEAD moved while this task
ran** — `3ae661fa` → `3f6dbbfc` (the driver's `docs(M22)` commit); none of its files are in this diff.

---

## ⚠ THE HEADLINES

### 1. The section exists, and a row goes from the real widgets to a real run on both binaries

A **noise section on the Tran form** (grid row 5 of Choose Analyses, which was free), folded shut,
built or destroyed by `ase::ui::chana_show` on **every** rebuild. Section **EE** of the new suite types
a white-noise entry on `vdd` and a Gaussian random current into `bias` **into the widgets**, presses
OK, renders the deck, runs it, reads it back with a second ngspice, **and returns to the form**, which
now estimates the results file from that run's own vector count:

| row | `/usr/bin/ngspice` 45.2 | fork `build-ver_50` |
|---|---|---|
| EE1 the typed entries reach the deck: carrier after the netlist, `alter vdd trnoise = [ 1m 10u 0 0 0 0 0 ]`, `alter vase_noise_1_2 trrandom = [ 2 100u 1n 1m 0 ]`, both restores | ✅ (render, binary-independent) | ✅ |
| EE2 rc 0; σ v(vdd) > 0; σ v(bias) > 0; points within 2× of the form's `≈ 1,000 points` | ✅ σ 0.917 mV / 0.835 V, **1210** points | ✅ σ 0.841 mV / 0.919 V, **1349** points |
| EE3 after the run the form reads `results file ≈ 88 kB`, within 2× of the file the run wrote | ✅ file **106,899** bytes | ✅ file **119,130** bytes |

(`…/scratchpad/s13g/dev/g4_d.log`; the same rows green in `final_all/`.)

### 2. ⚠ `facts nodes` IS NOT A NET LIST — receipt 41's hand-over would have offered `dc` as a net

Receipt 41, *What task 2 must build on*: *"Net candidates: facts `nodes {} nodes`, excluding ground and
`ase::facts_event_node`."* **Measured** (`s13g/dev/m1_nodes.tcl`): on `vdd vdd 0 dc 1.8 / vsig in 0 dc
0 sin(0 1 1k) / … / r1 vdd out 1k / m1 out in 0 0 nch W=1u / xinv out y inv`, the top scope held

```
0 1 1.8 1k 1k) bias dc in nch out rts sin(0 vdd y
```

and `ase::facts_net_status` answered **`present`** for `dc`, `1k`, `sin(0` and `nch`. `ase::netlist_map`
files every token after a device's name; harmless for a refusal (which must not false-refuse), wrong
for an offer. **Shipped:** the adapter reads nets from the netlist **text** (`ase::facts_netlist_text`,
a peek of the file the facts came from) by the node positions of the letters it is sure of
(`noise_net_tokens`: `r c l v i d b e f g h j m x`, subcircuit bodies and `.control` skipped), and
**the target rules were split out of `noise_entry_check`** (`noise_target_check` / `noise_value_check`,
same finding order, NR1) so the offer and the refusal are **one body**. NQ2 asks every offered target
through `ase::stimuli_verdicts` (15+ targets, no non-caution finding); NQ3 asks the excluded ones and
gets `fatal`; NQ4 pins both halves of the measurement.

### 3. ⚠ THE LOOK DECISION: FILED, BY MEASUREMENT

PLAN §13 said *"no new look debt"*. Screenshots on `:99` (`tests/headless/winshot.sh`, fixture
`s13g/dev/shot.tcl`) show a table, an editor, a live estimate line and a two-to-four-line footer —
and three things only eyes can judge. **`owed.sh add look ase-trnoise-section-1467`, "suites green,
please look".**

| file (`…/scratchpad/s13g/shots/`) | what it shows |
|---|---|
| `01-folded.png` 667×407 | `▸ Noise sources (3)` under `▸ Advanced` |
| `02-open-entry1.png` 667×814 | the table, Add row, editor for `Source vdd`, `Estimates: density ≈ 4.47e-06 V/√Hz, flat to ≈ 50 kHz · ≈ 2,000 points`, seed + kill sentences |
| `03-open-entry2-random.png` | the `Random source` editor, Gaussian → `Standard deviation (A)` / `Mean (A)` |
| `04-fatal-entry.png` | `⊘` on the line, the verdict under the editor **and again** in the form banner |
| `05-ok-refused.png` **839**×797 | the refusal a **third** time, in the status line, which widens the dialog |
| `06-main-window-args.png` | `tran 1u 2m  + 2 noise sources` (third entry switched off) |

**The readout checked against the arithmetic**, in `02`: A = 1m, TS = 10u, `tran 1u 2m` →
1m·√(2·10u) = **4.47e-06**; 1/(2·10u) = **50 kHz**; max(2m/1u, 5·2m/10u) = **2,000**. Row GL1 computes
the same three from the formulas (not from `ase::`) and compares the whole line; GL2 (TS 100n →
100,000) and GL3 (stop typed as 20m → 20,000) move it.

### 4. ⚠ Found by looking, and by the campaign — all repaired before hand-over

| found | how | outcome |
|---|---|---|
| **Kind column truncated** — `Transient nois`, `Random sourc` | screenshot 02 | width from the longest function label |
| **retyping a value moved a byte** — delete-then-insert passes through an empty field, which drops the key; re-entering `10u` put `ts` last in a hand-written entry | writing GB6 | the editor remembers the entry's key order at load (`ase::ui::nz_reorder`) |
| **S08 survived** (noun never plural) — GD1/GB3 compose their expectation through `ase::stimuli_noun` itself | campaign pass 1 | row **NS4** pins the literal |
| **W13 killed only by GE3** — GB6 retyped `ts` then `na`, and the second retype restored the order | campaign pass 1 | GB6 retypes `ts` alone; W13 now reds **GB6** |

### 5. The display arm's standing reds, under a hermetic `HOME`

`test_ase_dialogs` on `:99`: **4 FAILED (381 passed), rc 1 — G2sens, GG3, GG9, GN1b — before any change,
and the FAIL lines `diff`-identical after** (`base/` vs `after/` vs `final_all/`). Receipt 41 recorded
**1 FAILED (384)**, G2sens only. Every run here had `HOME` pointed at `s13g/home`; GG3/GG9/GN1b are the
capability-cache/Detect rows, which is the class that reads the developer's registry. **Not chased;
named for the driver.** `test_ase_optier_0963`'s display arm was **not run** (receipt 41's pre-existing
stall after N3); headless 109 before and after.

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

All 2026-09-15. Suites and fixtures with `HOME` → `s13g/home`, `XSCHEM_DEVDISPLAY_DIR` → the real state
dir; every command under `timeout`.

| claim | evidence |
|---|---|
| `facts nodes` carries values, keywords and model names, and `facts_net_status` calls them present | **MEASURED HERE** (`dev/m1_nodes.tcl`) |
| the offered targets per function (`iref` for noise, not for a random value; `vsig` never; ground never) | **MEASURED HERE** (NQ1–NQ5, and `dev/m2_core.tcl`) |
| the readout equals the arithmetic | **MEASURED HERE** (GL1–GL4, screenshot 02) |
| the typed table runs and is noisy, both binaries; point count and file size within 2× of the estimates | **MEASURED HERE** (EE1–EE3 on both) |
| opening the section, adding, typing and switching types calls no netlist/probe/simulator door | **MEASURED HERE** (GO1: seven doors stubbed, zero calls; a direct call counts 1) |
| an untouched bench, a hand-written table looked at, an add-then-delete and a retype write identical bytes | **MEASURED HERE** (GB1, GB2, GB4, GB6) |
| the dialog widens 667 → 839 px on a refused OK | **MEASURED HERE** (winshot sizes) |
| the Arguments column showed nothing of a table on a renderable row before this task | **READ from `ase::ui::arg_summary`**, not run pre-change: it returns `"$line$vb"` whenever `analysis_line` succeeds, so receipt 41's *"renders … as `noise={…}` today"* holds only for the fallback dump |
| `notrnoise` kills white/1-f, RTS only with TS > 0, never `trrandom` | **TRANSCRIBED** from issue 1466's EE6 (both binaries) — the new help and `results_why` text states it; NO1 checks the text |
| a negative TS hangs ngspice | **TRANSCRIBED** (receipt 41, fork only). **Never run here**: the fatal table in GV1/GV2 and screenshot 04 is refused at the dialog and no deck of it was rendered to a file or run |

---

## What shipped

### Core — `src/ase.tcl`, namespace `ase::`

| proc | what |
|---|---|
| `ase::stimuli_noun` | the contract's noun, singular for 1 |
| `ase::stimuli_quantity` | the adapter's `quantity` leg for one entry (a label needs it before the entry is in a row) |
| `ase::facts_netlist_text` | the netlist text the cached facts came from, **only while warm**; never netlists |
| `ase::stimuli_candidates` | `{<target field> {names}}` for one function, through the new `candidates` leg; `{}` with no leg — **no core fallback** (NS3; sabotage S03) |
| `ase::stimuli_nvec` | the last run's vector count for row `idx`: plotmap record matched by **index and type**, same-named plots by **position**, `ase::cap_raw_plots` header; `{}` otherwise (NN1–NN3) |
| `ase::stimuli_kill_report` | **gains `sentences`** from the new `kill_sentences` leg |
| `ase::analysis_schema_errors` | validates `candidates` and `kill_sentences` as optional legs (`badstimulihook`) |

### Content — `ase::backend::ngspice::`

`noise_contract` gains `candidates` and `kill_sentences`. New: `noise_net_tokens`, `noise_target_fatal`,
`noise_candidates`, `noise_kind_noun`, `noise_and`, `noise_kill_clauses`, `noise_kill_sentences`.
**Split, behaviour-preserving:** `noise_entry_check` = `noise_target_check` then `noise_value_check`
(task 1's 62 rows green after it, and NR1 pins the order). **The `notrnoise` catalogue row** gains
`help` and a per-kind `results_why` clause.

### Window — `src/ase_window.tcl`, namespace `ase::ui::`

| proc | what |
|---|---|
| `nz_build` | destroys `.chana.noise` **first**, then builds it only for a type with a contract; peeks facts, text and nvec once |
| `nz_table` / `nz_put` / `nz_ck` / `nz_entries` | the working table, **taken verbatim** from the stored row, keyed through **one** reader (`nz_ck` → the edit cache's key) |
| `nz_bar_targets` / `nz_add_pick` / `nz_add` / `nz_del` | the Add row: function + the candidates for it; Add with no target still adds (a cold bench is no dead end) |
| `nz_fill` / `nz_rows` / `nz_pick` | the table: On, Target, Kind, **Values = `ase::stimuli_values`**, verdict glyph |
| `nz_editor` / `nz_write` / `nz_traced` / `nz_reorder` | the editor **bound to the selected entry** by textvariable traces; a function switch drops foreign arguments and rebuilds the fields |
| `nz_readout_text` / `nz_note_text` / `nz_texts` / `nz_live` | estimates, per-entry verdicts in `precheck_banner_text`'s shape, seed + kill sentences verbatim; the form's step/stop move the estimate on key release |
| `nz_summary` | the Arguments column's `  + N noise sources` (entries switched on) |
| `lbl_nz_*`, `nz_g`, `nz_si`, `nz_int`, `nz_bytes` | the words and number formats (SI prefixes, not SPICE's) |

Changed existing procs: `chana_show` (calls `nz_build`, a raise is echoed and does not take the dialog
down), `chana_merged_row` (overlays the working table), `chana_ok` (writes the table **only when it
changed**; **refuses a changed table** with a fatal/blocked verdict; GV4: an untouched bad table does
**not** trap the dialog), `chana_cache_clear` (drops the tables and editor state; `nzopen` stays, like
`advopen`), `arg_summary`.

---

## Suites — before → after, every arm, with rc

**Before** = the untouched tree (`s13g/base/`). **After** = the finished product code (`after/`), then
the final tree (`final_h/` headless neighbours, `final_all/` the new suite on both arms + every display
neighbour). Headless `./src/xschem --nogui --pipe -q --nolog --script`; display
`tests/headless/devdisplay.sh exec timeout … ./src/xschem --pipe -q --nolog --script`.

| suite | headless before | headless after | display before | display after |
|---|---|---|---|---|
| **`test_ase_trnoise_gui_1467`** | — (new) | **ALL PASS (19), rc 0** | — | **ALL PASS (63), rc 0** |
| `test_ase_trnoise_1466` | 62, rc 0 | 62, rc 0 | 62, rc 0 | 62, rc 0 |
| `test_ase_dialogs` | 37, rc 0 | 37, rc 0 | ⚠ **4 FAILED (381), rc 1** | ⚠ **4 FAILED (381), rc 1** — same four lines |
| `test_ase_window` (W1m) | 56, rc 0 | 56, rc 0 | 295, rc 0 | 295, rc 0 |
| `test_ase_simdlg_0937` | 5, rc 0 | 5, rc 0 | 55, rc 0 | 55, rc 0 |
| `test_ase_optsheet_1441` | 62, rc 0 | 62, rc 0 | 87, rc 0 | 87, rc 0 |
| `test_ase_options_1437` | 75, rc 0 | 75, rc 0 | 75, rc 0 | 75, rc 0 |
| `test_ase_persist` | 49, rc 0 | 49, rc 0 | 153, rc 0 | 153, rc 0 |
| `test_ase_core` | 638, rc 0 | 638, rc 0 | 638, rc 0 | 638, rc 0 |
| `test_ase_sp_1452` | 58, rc 0 | 58, rc 0 | 58, rc 0 | 58, rc 0 |
| `test_ase_conv_gui_1460` | 45, rc 0 | 45, rc 0 | 104, rc 0 | 104, rc 0 |
| `test_ase_campaign_gui_1464` | 78, rc 0 | 78, rc 0 | 156, rc 0 | 156, rc 0 |
| `test_ase_events_1465` | 87, rc 0 | 87, rc 0 | 87, rc 0 | 87, rc 0 |
| `test_ase_optier_0963` | 109, rc 0 | 109, rc 0 | not run (pre-existing stall) | not run |

Registration: `grep -c test_ase_trnoise_gui_1467 tests/run_regression.tcl` → **3** (hcases, dcases, the
paragraph). Whole-line `OVERALL:` banner and `exit [expr {$fail ? 1 : 0}]` — the display arm rc is 0.

### Per binary

EE runs `/usr/bin/ngspice` (45.2) **and** `/home/analog/dev/ngspice/build-ver_50/src/ngspice`, three rows
each (EE1 is the render, shared), **no `SKIPPED` line** in any log. Every other new row is pure Tcl or
widgets and starts no simulator — said instead of testing twice.

---

## `.state` byte identity

Through **`tests/headless/state_roundtrip.tcl`**, inside the new suite (row NC1), on the finished tree,
both arms:

```
tracked 104    bad {}    control_disagrees 1    control_agrees 1
```

And through the dialog: **GB1** an untouched bench opened, unfolded, OKed → same bytes, no `noise` key,
dialog closed; **GB2** a hand-written three-entry table (keys out of order, one entry off) listed,
every entry selected, a type switch, OK → same bytes; **GB4** add-then-delete → same bytes; **GB5**
deleting every stored entry removes the key; **GB6** retyping a value → same bytes.

---

## THE SABOTAGE CAMPAIGN — 64 mutations, 64 killed by name, 0 restore mismatches

`s13g/sab/sab.py`, started only after the after-change suites had finished. **The gate is a positive
assertion and was fed the empty case first**: `GATE CONTROLS empty=NORESULT timeout=NORESULT
pass=SURVIVED fail=KILLED`. Every mutation: exact anchor, count 1 (all 64 checked before the run),
applied to the pristine bytes, the suite arm(s) under `timeout`, reds read by row name, restored by
**plain write** (Tcl only, nothing to build), both files md5-checked against pristine before the next.

**Pass 1** (`results_pass1.txt`): 63 killed, **S08 SURVIVED**, W13 killed by GE3 alone. Two rows repaired
(NS4 added; GB6 narrowed to one field). **Pass 2** (`results.txt`): S08 → **NS4**; W13 → **GB6, GE3**.

| # | what I broke | rows that reddened |
|---|---|---|
| S01 | schema forgets `candidates`/`kill_sentences` | NS1 |
| S02 | kill report never asks its leg | NK1 NK3 |
| S03 | core guesses candidates with no leg | NS2 NS3 |
| S04 | candidates dropped in core's aggregation | NQ1 NQ2 NQ5 |
| S05 | nvec ignores the record's type | NN2 |
| S06 | nvec ignores the ordinal | NN3 |
| S07 | nvec guesses with no record | NN2 |
| S08 | the noun never pluralised | **pass 1 SURVIVED** → pass 2 **NS4** |
| S09 | quantity ignores its leg | GE2 |
| S10 | the netlist-text peek answers nothing | GA2 EE1 EE2/apt EE2/fork EE3/apt EE3/fork |
| S11 | subcircuit-scope sources offered | NQ1 |
| S12 | sources offered without the target check | NQ1 NQ2 |
| S13 | nets offered without the target check | NQ1 NQ2 NQ5 |
| S14 | every token read as a node (the facts-map premise) | NQ1 NQ4 |
| S15 | subcircuit bodies read | NQ4 |
| S16 | `.control` blocks read | NQ1 NQ4 |
| S17 | an X card keeps its subcircuit name | NQ4 |
| S18 | `noise_target_fatal` never fatal | NQ1 NQ2 NQ5 |
| S19 | value findings before target findings | NR1 |
| S20 | kill sentences when not armed | NK2 |
| S21 | kill clauses not grouped per entry | NK3 |
| S22 | always "them" | NK3 |
| S23 | `notrnoise` help removed | NO1 |
| S24 | `notrnoise` per-kind evidence removed | NO1 |
| S25 | contract drops `candidates` | NQ1 NQ2 NQ5 |
| S26 | contract drops `kill_sentences` | NK1 NK3 |
| W01 | destroy only for a type with a contract — **the destroy-list trap** | GD2 |
| W02 | `chana_show` never builds the section | G0 GD1 GD2 GD3 GD4 |
| W03 | never folded | GD1 |
| W04 | header drops its count | GD1 |
| W05 | working table not taken verbatim | GB2 GB6 GS1 GS2 GS3 GV6 |
| W06 | OK treats an untouched table as changed | GV4 |
| W07 | OK never refuses | G0 GV2 |
| W08 | OK refuses a caution | GV5 |
| W09 | OK never writes the table | GV3 GV5 GK2 EE1 EE2/apt EE2/fork EE3/apt EE3/fork |
| W10 | an emptied table written as an empty key | GB5 |
| W11 | the merged row ignores the working table | G0 GA3 GL1 GL2 GL3 GL4 GV1 GV2 |
| W12 | Cancel keeps the working tables | GK1 and 26 more (the tables leak into every later row) |
| W13 | retyping reorders keys | pass 1 GE3 → pass 2 **GB6 GE3** |
| W14 | a function switch keeps foreign arguments | GE3 |
| W15 | Enable on writes `enabled 1` | GE6 |
| W16 | a route switch leaves the old target | GE2 GE3 |
| W17 | editor fields not in positional order | GE1 GE2 GE3 GE5 |
| W18 | `source` unit shown raw | GE1 GE2 GE5 |
| W19 | per-distribution labels ignored | GE5 |
| W20 | the distribution written as its label | GE5 EE1 EE2/apt EE2/fork EE3/apt EE3/fork |
| W21 | the Add row offers the first function's targets for every function | GA2 |
| W22 | Add refuses without a target (a cold dead end) | GA3 |
| W23 | point count not marked as an estimate | GL1 GL2 GL3 GL4 EE1 EE2/apt EE2/fork |
| W24 | flat-to loses its kilo prefix | GL1 |
| W25 | a file size guessed before any run | GL1 GL4 EE3/apt EE3/fork |
| W26 | the estimate does not follow the form's fields | GL3 |
| W27 | no verdict marks | GV1 GV5 GV6 |
| W28 | the verdict line speaks for every entry | GV6 |
| W29 | kill sentences not shown | GS3 |
| W30 | the footer reads the stored row | GS4 |
| W31 | Arguments counts switched-off entries | GB3 |
| W32 | Arguments silent about the table | GB3 |
| W33 | Values column not the deck's positional values | GB2 |
| W34 | two transient rows share one table | GK2 |
| W35 | opening the section netlists | GO1 |
| W36 | a simulator word typed into the window (headless arm) | NZ1 |
| W37 | a function switch does not rebuild the fields | G0 GE3 |
| W38 | a bench with no table opens holding a phantom entry | GB1 GD1 GA3 GB4 GE2 GE3 GE5 GE6 GK1 GK2 GV1 GV2 GV3 GV5 EE1–EE3 |
| **final** | **the restored tree** | **`test_ase_trnoise_gui_1467` ALL PASS headless (19) and display (63)** |

**Hygiene rows, not sabotaged**: NC1 (the helper's four numbers), GD0 (fixture up, facts warm). **G0** in a
red set means a mutation raised inside the widget legs — still a named red, and in each case the
expected row is in the set too.

Logs: `…/s13g/sab/results_pass1.txt`, `results.txt`, `logs/<id>.<arm>.log`.

---

## Debts filed — queue before → after

Backed up first: `…/scratchpad/ARCHIVED_DO_NOT_RESTORE/s13g_1467/owed_backup_before_rule_1467`.

| | rule | look | suite |
|---|---|---|---|
| **before** | 179 | 68 | 11 |
| **after** | **180** | **69** | **11** |

* **`add rule 1467`** — `R9_COPY_REVIEW.md` **R9-654 … R9-671**, header **653 strings from 31 issues →
  671 from 32**. 13 are ASE-L frames (header, caption, columns, `Target:`, `Kind:`, `Estimates:`, four
  readouts, units, the Add list entry, the Arguments count); 5 are the adapter's (two kill sentences,
  `random value`, the `notrnoise` help and its evidence clause). **Reused, not re-filed:** R9-625 …
  R9-653 (now on screen — the section header of the R9 entry says so; their *Where:* lines predate it),
  `Add`, `Delete`, `Enable`, and every refusal/fix sentence (issue 1466's).
* **`add look ase-trnoise-section-1467`** — "suites green, please look"; the three points in headline 3.
* **No `suite` debt**: the new suite runs on `:99` in T1's `dcases`; nothing here is Xwayland-specific.

---

## Corrections — to receipt 41, PLAN.md §13, the brief and the ledger

| | |
|---|---|
| **C1** | ⚠ **Receipt 41 *What task 2 must build on*: "Net candidates: facts `nodes {} nodes`"** — that map holds values, keywords and model names, all `present` (measured). Nets come from the netlist text by device letter; PLAN §13's correction block now says so |
| **C2** | **Receipt 41: "The Arguments column renders a row with a table as `noise={…}` today"** — only rows with **no** deck line fall to the key dump; a renderable `tran` row read `tran 1u 2m` with nothing about its table (read from `arg_summary`). Now `tran 1u 2m  + 2 noise sources` |
| **C3** | ⚠ **PLAN §13: "no new look debt is filed"** — filed, by screenshot (headline 3) |
| **C4** | **PLAN §13: "a button that offers only the sources a stimulus is not already using"** — the offer is **per function** (a current source for noise, never for a random value) and includes nets; a menu was rejected because a real bench's net list does not fit an unscrolled Tk menu |
| **C5** | **The brief: "`test_ase_dialogs` G2sens fails on `:99` before any change"** — under a hermetic `HOME` it is **four** rows (G2sens GG3 GG9 GN1b), identical before and after; receipt 41's 1 FAILED (384) was probably a different `HOME` — not verified |
| **C6** | **Receipt 41's R9-625 … R9-653 *Where:* lines** ("not on any screen yet") are stale; noted at the head of the 1467 entry rather than rewritten 29 times |
| **C7** | **PLAN §13 *Files and procs*: `src/ase_window.tcl` ≈ +200** — +904, of which roughly a third is comment; `src/ase.tcl` gained +308 in task 2 on top of task 1's +1234 |

---

## What task 2 learned that binds later stages

1. **A node map is not a net list.** `ase::netlist_map`'s `nodes` is a superset built for refusals; any
   future OFFER of nets (a probe picker, a port scan on nets) must read positions, not that map.
2. **An offer and a refusal must be one body.** Split the adapter's check and call its target half from
   the candidates leg; a second filter written for the offer drifts from the refusal.
3. **A form that edits a table binds its editor to an entry, never to a draft**, so OK cannot drop a
   half-typed row — and **retyping passes through an empty field**, so key order must be restored or
   the byte-identity rule breaks on a value that did not change.
4. **A row whose expected value is computed through the proc under test cannot catch that proc** (S08).
   Pin the literal somewhere.
5. **A two-step retype can repair itself** (W13 vs GB6). Sabotage the row's own premise, one step.
6. **Tk delivers a generated key event to the focus window**, not the one named; a row driving a
   `<KeyRelease>` binding focuses first.
7. **`ase::ui::dialog_status` has `-wraplength 0`**: any long refusal widens Choose Analyses (667 → 839 px
   measured). Issue 1435's comment predicted it; a later stage that refuses from this door will meet it.

## Declared limits (also in the issue file)

* A cold bench offers no targets (Add still adds; the name can be typed).
* The net reader knows `r c l v i d b e f g h j m x` node positions only.
* The estimates follow the form's step/stop on a key release; a paste without a key moves them at the
  next edit.
* The results-file size needs a previous run of the same row (a plotmap record naming it).
* The Options sheet's rendering of the new `notrnoise` text is `test_ase_optsheet_1441`'s generic detail
  row; this suite checks the text as data.
* ⚠ **Not addressed, for the driver**: debt **M22** (`tran_points` and the checkpoint decision) is untouched;
  the section's `≈ N points` is `ase::stimuli_points`, which already counts the noise.

## Hygiene

* **One runner at a time** (baseline → after → final headless → campaign → final display), each with a
  deadline waiter that reports progress and checks the runner by **recorded pid** (`kill -0`), never
  `pgrep -f`. No `pkill`.
* **Nothing under `~/.xschem/`**: every suite, fixture and screenshot run had `HOME` → `s13g/home`; EE's
  ngspice runs had `HOME=$scratch`. No `untitled~.sch` in the repo root.
* **`/usr/bin/ngspice` was never handed a negative TS or any refused deck** — EE runs only the deck the
  dialog committed.
* **Snapshots disarmed**: the pre-change copies, the unused work copies, the campaign's pristine pair and
  the owed backup are under `…/scratchpad/ARCHIVED_DO_NOT_RESTORE/s13g_1467/`; `sab.py` can no longer find
  a pristine to restore from. Logs kept in `…/scratchpad/s13g/` (`base/`, `after/`, `final_h/`,
  `final_all/`, `dev/`, `sab/`, `shots/`).
* **No background process of this crew is running** (all four runner pids gone). The dev display `:99`
  is left up.
* ⚠ **If this crew is woken after collection: `git status` and `git log` before touching anything.**

`…/scratchpad` is `/tmp/claude-1000/-home-analog-dev-xschem-claude/c8183bb1-7387-41d6-9d30-a409f8d7e1a3/scratchpad`.
