# Stage 16 task 1 — "the ngspice you actually have", everything that is not a pixel (issue 1470)

**Issue `doc/claude/issues/1470-a-build-that-cannot-do-what-ase-l-offers-is-never-named-and-a-command-line-that-crashes-it-gets-no-warning.md`**,
minted by this crew (1470 checked free in every clone under `~/dev/*` and outside every reserved band;
`NUMBERING.md` pointer → 1471). Handed to this crew by the driver as one task: 16a's composer, 16b's linter,
16c's two file checks, 16d's reason token, debt **M21**, and the three conformance rows. **Task 2** — the
Simulators-window row, its `look` debt and 16e's release note — is not here.

Files touched, and nothing else:

| file | ± | md5 before → after |
|---|---|---|
| `src/ase.tcl` | **+710 / −2** | `c34184f6` → **`a052b663`** |
| `tests/headless/test_ase_variant_1470.tcl` | **new**, 835 lines | → `f1e4e31c` |
| `tests/headless/test_op_dump_altshow.tcl` | +7 / −1 (row T2) | `7ddb1b28` → `5cc669f8` |
| `tests/headless/test_ase_optier_0963.tcl` | +13 / −2 (row X5, row S11's filter) | `2ad565fa` → `56146daf` |
| `tests/headless/test_sim_run_profile.tcl` | +12 / −4 (CS176, CS176c, CS176d, CS176e) | `216d53ff` → `daa39258` |
| `tests/headless/test_ase_simdlg_0937.tcl` | +4 / −1 (row S29) | `13cefdc7` → `6ab93cdb` |
| `tests/run_regression.tcl` | +9 / −1 (`hcases` + its paragraph) | `c827a696` → `70313da8` |
| `doc/claude/issues/NUMBERING.md` | +10 / −1 | `9816b18a` → `097f2169` |
| `doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md` | +406 (R9-678 … R9-719) | `9747a4c0` → `f0e12773` |
| the issue file, this receipt | new | |

**`src/ase_window.tcl` md5-unchanged (`96095410`)**, as the brief asked. `src/xschem.tcl` unchanged (`87ba1eec`).
**No C**: `make -q -C src` rc 0 before and after, `src/xschem` `96fc4899` throughout. **No commit, no `git add`,
no stash/restore/clean/push. `tests/run_regression.tcl` edited, NOT run.** HEAD `3addf5ca` at start and at
hand-over; the tree moved under nobody else during the task. **No simulation on a bench under `sky130A/`.**
`render_deck` is untouched, so Stage 12's `eprvcd` line, Stage 13's noise emission and every positional anchor
(1430, 1433, 1434, 0963, 0967, §7e, 1465, 1466) are exactly where they were.

---

## ⚠ THE CRASH RULE — HOW IT WAS KEPT

**No linter pattern was ever run on any binary.** Section LN drives `lint_control_text` over strings; the one
end-to-end linter row (VS15) runs `ase::run_deck` against a `/bin/sh` stand-in, and LN11 against a gate that
refuses before anything starts. `/usr/bin/ngspice` was started only by (a) the ordinary capability probe —
`ase::sim_capabilities_path`, the seven decks Detect already runs, in my scratch measurement and in row EX1 of
every suite run — and (b) two `echo "@@sourcepath=$sourcepath"` decks (the first answered rc 1, *incomplete or
empty netlist* — a parse complaint, not a crash; the second rc 0). **It never aborted.** Stock 47 was started only
by the probe; the fork by the probe, the M21 decks and the `$sourcepath` decks. No core, no rc 134/139 anywhere.

---

## THE HEADLINES

### 1. The sentences, from the REAL probe on all three binaries — MEASURED HERE

`ase::sim_capabilities_path ngspice <bin>` in a hermetic-HOME `--nogui` session, 2026-09-15 (`s16/caps/`), then
again inside rows EX1–EX3 on both arms:

| binary | the keys that decide | frame | the sentence |
|---|---|---|---|
| **apt 45.2** `/usr/bin/ngspice` | `casemode_detected {fold}`, `altshow_op_dump 0`, `keyword_case 0`, `gnd_literal 0`, analyses incl. `pss` | missing | *"/usr/bin/ngspice can do everything ASE-L offers except case-sensitive net names and the fast operating-point dump. Its fast dump prints wrong numbers, so operating points are saved one device at a time; no ngspice release has the fix yet. Two kinds of command line are misread by it; ASE-L warns before a run that uses one."* |
| **stock 47** | `{fold}`, `altshow 1`, `0`, `0`, **no `pss`** | missing | *"… can do everything ASE-L offers except case-sensitive net names. Two kinds of command line are misread by it; ASE-L warns before a run that uses one."* |
| **the fork** | `{fold preserve distinguish}`, `1`, `1`, `1`, `pss` present | complete | *"… can do everything ASE-L offers."* |

**PSS is on no row, by one rule applied everywhere**: an analysis is named only when ASE-L lists it **and can emit
it**, and `pss` is registered with `renderable 0` today (MEASURED HERE, `ase::analysis_renderable ngspice pss` → 0).
**No sentence names a version, says "basic" or says "ngspice 47 fixes that"** (row VS12 scans every sentence the
suite composes; VS11 swaps `version_line` and nothing moves). *"no ngspice release has the fix yet"* rests on
`git -C /home/analog/dev/ngspice tag --contains 10276f993` → **empty**, re-measured here.

**The fourth frame** — measured, but a measurement did not come back — is driven by the absence the probe reports.
On the slow box whose budget kills leg D (M20's slow-box half), apt 45.2 reads *"… except case-sensitive net names
and the fast operating-point dump, and one measurement did not finish: how it reads two kinds of command line. …
Press Detect in the Simulators window to try again."* (VS4c). A key absent **without** a provenance token also takes
the fourth frame (VS4e), never *"can do everything"*.

### 2. The run log says it once per binary per session — and only a delta

`ase::run_deck` calls `ase::variant_report` directly below `ase::cap_report`. It reads **the peek**
(`ase::sim_caps_cached`) and never `ase::sim_capabilities`, so an answer that was not remembered gives no sentence
rather than a second probe (VS14: an empty cache says nothing and the marker-writing stand-in is never started).
The sentence goes to the CIW through `ase::sim_say` and into the log header's `notes` field; the second run on the
same binary says nothing (VS15, through the real `run_deck`, twice). **Frame 2 is never said in the log** (the delta
shrinks to nothing), and **frame 1 is not said there either** — on the Run path `ase::cap_report` owns the sentences
for a program that did not answer, and *"press Detect"* just after a probe ran is issue 1371's refuted sentence.
Both are recorded under `rule 1470` as choices.

### 3. The linter — five patterns, and two scopes read out of ngspice's own source

`lint_control_text {lines caps}` over the user's own lines — the bench's `pre_commands`, an enabled row's verbatim
lines (issue 1419's `x`), and the netlist's own `.control` block — run by `ase::preflight_notes` **after
`ase::run_precheck`, before `ase::preflight_gate` and before the first delete** (LN10 structural, LN11 behavioural:
a refused run was already warned and its run folder holds nothing). Each warning quotes the line **from the source,
never from the adapter's answer** (LN9), reaches the CIW tagged `note` and the run log's `notes` (VS15), and the line
reaches the deck byte for byte (LN7, through `render_deck`).

* Patterns 1–3 (`unset`, `define`/`undefine`, `load`) **warn on every binary, the fork included** (LN6) and carry
  no `refuse_key`.
* **Pattern 4's delimiters are ngspice's own**, READ HERE from the pre-fix `inp_fix_gnd_name()`
  (`git show 131779106^:src/frontend/inpcom.c`): first token skipped; before `gnd` whitespace, `(` or `,`; after it
  whitespace, `)` or `,`. PLAN said *"whitespace- or paren-delimited"* — the comma is ngspice's too (LN4 line 8).
  **Scoped to commands whose arguments are text** (the reader's case-preserving list: `echo shell write wrdata
  source cd load setcs strcmp strstr`), because on `print v(gnd)` the rewrite is the documented alias of node 0 and
  changes nothing.
* **Pattern 5 is scoped to `write`/`wrdata`** — the case-preserving lines that take a keyword argument; every other
  `.control` line is folded first, so `print ALL` works on every binary. The words checked are the wildcard family
  `all allv alli ally alle`.
* 4 and 5 are **silent on measured 1, a warning on measured 0 and on unmeasured** (D47), and the clause says which
  (*"this simulator"* / *"some ngspice builds"*, LN5b).
* **D47's warn/refuse policy is `ase::preflight_policy`**: refuse only when a note's `refuse_key` is MEASURED 0.
  The ngspice adapter names none (D50), so the refuse arm is reached only by a fixture (LN12, LN12b).

### 4. Debt M21 — MEASURED HERE, then fixed

The fork, ASE-L's own deck shape (`write` inside `.control`), same deck, same binary (`s16/m21/`):
`-D casemode=preserve` alone → **0** `Option:` lines; `-D casemode=preserve -D casemodewrite` →
`Option: casemode=preserve`. `ase::run_casemode_flag` now returns both words, never alone and never for `fold`.
Row **M21b** runs ASE-L's own `render_deck` + `run_cmd` on the fork and reads the raw back through
`xschem raw read` → `xschem raw casemode -all` = **`preserve header`** — SOURCE 2 fires on a file ASE-L caused.

### 5. 16d — `dumpunsound`

`ase::op_save_tier` guard **G4a**: G4's shape (`c`) with reason `dumpunsound` exactly when `altshow_op_dump` is
**measured 0**; an absent key still reads `unsafe` (OT1). Its sentence tail: *"There is a much faster way that collects
every device at once, but your simulator was measured printing wrong numbers that way, so xschem asks one device at a
time."* — no version, no release (OT2).

### 6. 16c — two greps and the parse rule; and a tree comment that did not reproduce

`scripts_dir_of {sourcepath}` (first absolute element whose basename is `scripts`, quotes stripped) and
`cosim_shim_verdict {scripts_dir}` (1 / 0 / `unknown` per check, a 0 carrying clause, remedy and the fork's own change
as `patch`). MEASURED HERE: `echo "@@sourcepath=$sourcepath"` in a `-b` deck gives `. /usr/share/ngspice/scripts
/usr/share/ngspice/scripts .` on apt 45.2 and `. /home/analog/dev/ngspice/build-ver_50/stage/share/ngspice/scripts`
on the fork — **including leg D's own `>> probe_d.txt` redirect form**. `src/ase.tcl`'s capability-vocabulary comment
said *"`$sourcepath` came back EMPTY from inside the probe deck"*; that did not reproduce, and the comment now says so.
The greps, MEASURED HERE: apt `/usr/share/ngspice/scripts` → `verilated_vcd_c` 0, `contextp.release` 0; fork `stage`
→ 1, 1 (CS4, both).

### 7. Two things the existing suites found, and both were right

* **`test_sim_run_profile` CS182b** reddened on the first after-run: its stand-in simulator's probe answers
  `usable 0`, and its run log gained a fourth-frame sentence. A program measured not to be a simulator has no
  variant — `cap_report` already says `cap_not_a_simulator` — so `ase::variant_frame` now gives no frame for it
  (row VS9b; sabotage S07 reds VS9b **and** CS182b).
* **`test_ase_optier_0963` S11** counts every sentence kind a run says and requires the ones from other items to be
  named in `Q_OTHERITEMS`, as issue 1370's `run_using` is. Its primed answers omit most keys, so its runs now say the
  fourth frame. `variant_missing variant_partial` were added to that list with the reason, exactly 1370's precedent.

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

All 2026-09-15; every xschem launch `--nolog` with `HOME` → a scratch directory; display arm on `:99` with
`XSCHEM_DEVDISPLAY_DIR` the real state dir and `GUI_GATE=0`; every command under `timeout`.

| claim | evidence |
|---|---|
| the three capability dicts and the three sentences (headline 1) | **MEASURED HERE**, `ase::sim_capabilities_path`, scratch session + rows EX1–EX3 both arms |
| `pss` registered, `renderable 0`; `sp` `baseline 0` | **MEASURED HERE**, headless script over `ase::analysis_types` |
| `git tag --contains 10276f993` is empty | **MEASURED HERE** (read-only git) |
| M21's 0 vs 1 `Option:` line; `preserve header` through ASE-L | **MEASURED HERE**, the fork only (the one binary that writes the header) |
| `$sourcepath` on apt 45.2 and the fork, both echo forms | **MEASURED HERE** |
| the two installation greps on apt and fork trees | **MEASURED HERE** (files only) |
| pattern 4's delimiter rule | **READ HERE**, `git show 131779106^:src/frontend/inpcom.c` |
| the vlnggen and shim changes carried as `patch` | **READ HERE**, `git show e47a2abc8`, `git show c2722d89b` |
| `unset`/`define`/`load` → SIGABRT/SIGSEGV on apt 45.2 and stock 47 | **TRANSCRIBED**, `evidence/fork-dependencies.md` §3–§4 — **deliberately not re-run** |
| the `gnd` rewrite examples and `write <file> ALL` → no file at rc 0 | **TRANSCRIBED**, same file §4.7, §4.11 |
| why `unsafe` is the wrong explanation on 45.2 | **TRANSCRIBED**, `evidence/fork-features.md` §13.3 |
| `test_ase_dialogs` display arm red on the untouched tree | **MEASURED HERE**, twice (parallel baseline, then solo) |

---

## What shipped

### `src/ase.tcl` — the schema half

| proc | change |
|---|---|
| `ase::variant_join` | **new** — "A", "A and B", "A, B and C" |
| `ase::variant_has_hook` | **new** |
| `ase::variant_notes` | **new** — the adapter's notes, validated; unknown shapes dropped; a raise propagates |
| `ase::variant_frame` | **new** — `unmeasured` / `complete` / `missing` / `partial`, `{}` with no hook, on a raise, or for `usable 0` |
| `ase::variant_sentence` | **new** — minted through `ase::sim_why variant_<frame>` |
| `ase::variant_say` | **new** — once per `{sim path sentence}` per session, deltas only, through `ase::sim_say … note` |
| `ase::variant_report` | **new** — the run's door, reads the peek |
| `ase::sim_why` | **four `variant_*` kinds**; the `dumpunsound` tail on `op_tier_perdevice` |
| `ase::sim_caps_clear` | also forgets `variant_said` |
| `ase::preflight_policy` | **new** — D47, pure |
| `ase::preflight_lint_sources` | **new** — the three sources of user text, never raises |
| `ase::preflight_where` | **new** |
| `ase::preflight_notes` | **new** — the pass; warns, or raises a D47 refusal |
| `ase::run_deck` | calls `ase::preflight_notes` after the netlist read and before `ase::preflight_gate`; `ase::variant_report` after `ase::cap_report`; both into `casenote` |
| `ase::op_save_tier` | guard G4a, reason `dumpunsound` |
| `ase::run_casemode_flag` | `-D casemode=<m> -D casemodewrite` (M21) |

### `src/ase.tcl` — the ngspice adapter

**New** `variant_key_note`, `variant_notes`, `lint_note`, `lint_text_words`, `lint_wildcards`, `lint_control_text`,
`scripts_dir_of`, `cosim_count`, `cosim_shim_verdict`; **registered** `variant_notes`, `lint_control_text`,
`scripts_dir_of`, `cosim_shim_verdict`. No refusal is licensed anywhere.

### `tests/headless/test_ase_variant_1470.tcl` — NEW AT **57**, both arms

Sections **VS** (23: VS1 VS2 VS3 VS3b VS4 VS4b VS4c VS4d VS4e VS5 VS5b VS6 VS7 VS8 VS9 VS9b VS10 VS10b VS11 VS12
VS13 VS14 VS15), **LN** (16: LN1–LN5 LN5b LN6–LN12 LN12b LN13 LN14), **CS** (6: CS1 CS2 CS3 CS4/apt CS4/fork CS5),
**OT** (2), **CF** (4: CF0 CF1 CF2 CF3), **M21** (2), **EX** (3: EX1/apt EX2/fork EX3/up47), **ST** (1). CS4, M21b and
EX self-skip, uncounted, when their binary or installed tree is absent. Ends with a whole-line `OVERALL:` and
`exit [expr {$fail ? 1 : 0}]` as its last statement; added to `hcases` with its paragraph.

---

## Suites — before → after, every arm, with rc

**Before** = the untouched tree at `3addf5ca` (`s16/logs/base/`). **After** = the final tree (`s16/logs/after2/`,
then `final2`/`final3` after the suite's own hardening). Headless `timeout --kill-after=20 600 ./src/xschem --nogui
--pipe -q --nolog --script`; display `tests/headless/devdisplay.sh exec timeout --kill-after=20 600 ./src/xschem
--pipe -q --nolog --script` on `:99`.

| suite | headless before | headless after | display before | display after |
|---|---|---|---|---|
| **`test_ase_variant_1470`** | — | **ALL PASS (57), rc 0** | — | **ALL PASS (57), rc 0** |
| `test_ase_core` | 638, rc 0 | 638, rc 0 | 638, rc 0 | 638, rc 0 |
| `test_ase_preflight` | 235, rc 0 | 235, rc 0 | 235, rc 0 | 235, rc 0 |
| `test_ase_persist` | 49, rc 0 | 49, rc 0 | 153, rc 0 | 153, rc 0 |
| `test_ase_simcaps_0948` | 211, rc 0 | 211, rc 0 | 211, rc 0 | 211, rc 0 |
| `test_ase_simreg_0931` | 117, rc 0 | 117, rc 0 | 117, rc 0 | 117, rc 0 |
| `test_ase_predeck_1439` | 78, rc 0 | 78, rc 0 | 78, rc 0 | 78, rc 0 |
| `test_ase_optier_0963` | 109, rc 0 | 109, rc 0 | *not run — stalls after N3 before any change (brief)* | *not run* |
| `test_raw_case_mode` | 277, rc 0 | 277, rc 0 | 277, rc 0 | 277, rc 0 |
| `test_ase_cosim` | 341, rc 0 | 341, rc 0 | 341, rc 0 | 341, rc 0 |
| `test_ase_events_1465` | 87, rc 0 | 87, rc 0 | 87, rc 0 | 87, rc 0 |
| `test_ase_trnoise_1466` | 78, rc 0 | 78, rc 0 | 78, rc 0 | 78, rc 0 |
| `test_ase_campaign_1462` | 161, rc 0 | 161, rc 0 | 161, rc 0 | 161, rc 0 |
| `test_ase_dialogs` | 37, rc 0 | 37, rc 0 | **4 FAILED (381 passed), rc 1** | **4 FAILED (381 passed), rc 1** — same four |
| `test_ase_window` | 56, rc 0 | 56, rc 0 | 295, rc 0 | 295, rc 0 |
| `test_op_dump_altshow` | 70, rc 0 | 70, rc 0 | 70, rc 0 | 70, rc 0 |
| `test_sim_run_profile` | 37, rc 0 | 37, rc 0 | 37, rc 0 | 37, rc 0 |
| `test_ase_simdlg_0937` | 5, rc 0 | 5, rc 0 | 55, rc 0 | 55, rc 0 |
| `test_sim_plain_run` | 54, rc 0 | 54, rc 0 | 54, rc 0 | 54, rc 0 |
| `test_sim_casemode_registry` | 43, rc 0 | 43, rc 0 | 43, rc 0 | 43, rc 0 |

Every other cell is `ALL PASS (<n>)`. **Not a count diff — a name diff**: for all 38 existing logs, the sorted
`status id` list after versus before is **identical** (`SAME` × 38). The moved rows keep their names and their `ok`;
what moved is the expected value, each with a paragraph naming issue 1470.

**The intermediate after-run** (`s16/logs/after1/`) is part of the record: optier **S11** red, and
`test_sim_run_profile` **CS176e** (my own arithmetic, 10 for 11) and **CS182b** red on both arms — headline 7.

⚠ **`test_ase_dialogs`' display arm is red on the UNTOUCHED tree, and not by this task**: **G2sens, GG3, GG9, GN1b**,
reproduced solo at `3addf5ca` (`s16/logs/base_solo/`), identical by name after. **Issue 1436** names G2sens and GG9
(and quotes GG3 inside GG9's analysis); **GN1b is not in 1436**. T1 runs this file headless only (`dcases` does not
list it), so it is not a T1 count. Named for the driver; not filed by this crew.

### Per binary

EX1/apt, EX2/fork and EX3/up47 ran on every suite run of both arms and in every sabotage arm — **0 `SKIPPED`**.
M21b ran on the fork in every run. Everything else is pure Tcl and starts no simulator; section LN never starts one.

---

## `.state` byte identity

Row **ST1**, through `tests/headless/state_roundtrip.tcl`, both arms, final tree:

```
tracked 104    bad {}    control_disagrees 1    control_agrees 1
```

No state key added; `ase::omit_if_empty` untouched (sabotage S41 removes `sweep` from it and reds ST1).

---

## THE SABOTAGE CAMPAIGN — 54 arms, every one of the 57 rows reddened by at least one, 0 restore mismatches

`sab.py`, 14:41:00–14:44:14, then S00/S36/S49 re-run 14:46 and S00 again after the suite was hardened. Started after
both after-runners printed `RUNNER DONE` with **no `xschem` alive (matched by `comm`)**. **The gate is a positive
assertion and was fed the empty case first**: `GATE CONTROLS empty=NORESULT partial=NORESULT pass=SURVIVED
fail=KILLED`. Each arm verified the post-fix md5, applied its mutation on anchors that each occur exactly once, ran
its suites, read reds **by row name**, restored by a plain write and compared md5. Tcl only — nothing to build.

| # | what I broke | reds |
|---|---|---|
| **S00** | **the whole pre-change `src/ase.tcl`** | 1470: VS1–VS15 (all 23) LN1–LN14 (all 16) CS1 CS2 CS3 CS4/apt CS4/fork CS5 OT1 OT2 M21a M21b EX1/apt EX2/fork EX3/up47 · run_profile: CS176 CS176c CS176d CS176e · altshow: T2 |
| S01 | M21: the flag drops `-D casemodewrite` | M21a M21b · CS176 CS176c CS176d CS176e · simdlg S29 (display) |
| S02 | 16d: G4a never fires | OT1 · altshow T2 · optier X5 |
| S03 | 16d: the `dumpunsound` tail gone | OT2 |
| S04 | the adapter does not register `variant_notes` | VS1–VS8 VS11 VS13 VS14 VS15 EX1 EX2 EX3 |
| S05 | the fourth frame never chosen | VS4 VS4b VS4c VS4d VS4e |
| S06 | a backend with no hook gets fallback content | VS9 |
| S07 | a non-simulator gets a sentence | VS9b · run_profile CS182b |
| S08 | an analysis ASE-L cannot emit (PSS) is named | VS3b VS5b VS12 EX3 |
| S09 | the dump-printer aside gone | VS3 VS4c VS11 VS13 VS14 VS15 EX1 |
| S10 | "said" never recorded | VS13 VS15 |
| S11 | the complete frame said in the log | VS13 |
| S12 | the run door measures instead of peeking | VS14 VS15 |
| S13 | `run_deck` never asks for the sentence | VS15 LN10 |
| S14 | a raising notes hook not caught | VS10b |
| S15 | malformed notes not dropped | VS10 |
| S16 | pattern 1 gone | VS15 LN1 LN6 LN7 LN8 LN9 LN11 |
| S17 | pattern 2 gone | LN2 LN6 |
| S18 | pattern 3 gone | LN3 LN6 LN9 |
| S19 | pattern 4 ignores ngspice's delimiters | LN4 |
| S20 | pattern 4 warns only on a sound build | LN4 LN7 LN9 |
| S21 | pattern 4 nags every command | LN4 |
| S22 | pattern 5 flags a lower-case keyword | LN3 LN5 LN5b LN8 |
| S23 | pattern 5 warns on a sound build | LN5 |
| S24a | the warning quotes a rewritten line | LN9 |
| S24b | the deck drops the flagged line ("fix" by rewriting) | LN7 |
| S25 | verbatim lines not read | LN9 |
| S25b | netlist lines outside `.control` read | LN9 |
| S26 | a disabled row read | LN9 |
| S27 | the linter runs after the gate | LN10 LN11 |
| S28 | the warnings never reach the log | VS15 |
| S29 | D47 refuses on an unmeasured build | LN12 LN12b |
| S30 | a backend with no hook linted with ngspice's patterns | LN13 |
| S31 | a raising lint hook not caught | LN14 |
| S32 | parse: first absolute element whatever its name | CS1 |
| S33 | parse: echoed quotes not stripped | CS1 |
| S34 | a missing file reads as a defect | CS2 |
| S35 | the VCD check's polarity inverted | CS2 CS4/apt CS4/fork |
| S36 | the VCD note loses its patch | CS3 *(first run: NORESULT — see below)* |
| S37 | a version comparison planted in core | CF1 |
| S38 | a bare capability `dict get` planted | CF2 |
| S39 | `caps_is` under a `!` planted | CF3 |
| S40 | clearing the cache does not forget "said" | VS13 VS15 |
| S41 | `sweep` leaves `omit_if_empty` | ST1 |
| S42 | the file check starts a process | CS5 |
| S44 | a clause keyed on the version string | VS3 VS4c VS11 VS13 VS14 VS15 CF1 EX1 |
| S45 | an aside says "basic" | VS3 VS3b VS11 VS12 VS13 VS14 VS15 EX1 EX3 |
| S46 | nothing measured reads as complete | VS1 |
| S47 | no clause for a build without distinguish | VS6 |
| S48 | one misread kind not counted | VS7 |
| S49 | the join loses its conjunction | VS3 VS4c VS4d VS8 VS11 VS13 VS14 VS15 EX1 *(first run: NOT APPLIED)* |
| S50 | a missing analysis never named | VS5 |
| S51 | an absent key with no token reads as measured | VS4e |
| S52 | pattern 5 never says what was measured | LN5b |
| **final** | **the restored tree**, md5 `a052b663` | **1470 ALL PASS (57) both arms · run_profile 37 both arms · altshow 70 both arms · simdlg display 55** |

**Coverage, row → arms that reddened it**: every one of the 57 has at least one. The five rows **S00 leaves green**
are CF0–CF3 and ST1, by design: they pin properties a clean tree already has (no version comparison, no bare
capability read, no negated `caps_is`, no new state key) and each has its own killer (S37, S38, S39, S41; CF0 is the
scanners' own planted-defect control).

⚠ **Three first-run outcomes were not reds, and each was fixed rather than averaged in:**

* **S00 and S36 returned NORESULT** — a `dict get` on a `NOPROC` answer raised at top level and the suite died before
  `RESULT:`. The gate scored them correctly (not survivors), but a reader that raises cannot disagree: `v_total` now
  wraps LN5b, LN7, CS3 and CS5. Re-run: S00 reds by name, S36 reds CS3.
* **S00's re-run then showed two rows passing for the wrong reason** on the pre-change tree: **CS4** skipped because
  its skip was decided on the (missing) parser's answer, and **VS12** counted `NOPROC` strings as sentences. Both were
  split (skip on the literal directory; count only real sentences). Re-run: S00 reds VS12, CS4/apt, CS4/fork too.
* **S49 was NOT APPLIED** — its anchor line occurs twice in the tree. Re-anchored on the proc's own context; re-run
  reds nine rows.

Logs: `…/s16/sab/results.txt`, `…/s16/sab/logs/<arm>.<suite>.<h|d>.log`.

---

## Debts — before → after

`owed.sh count`: **181 rule, 69 look, 11 suite → 182 rule, 69 look, 11 suite.** The ledger was backed up first
(`…/s16/owed_backup/`).

* **rule `1470`** — every new sentence (R9-678 … R9-719: the four frames, the clause and aside list, the five
  unfinished-measurement nouns, the linter's warning and refusal frames with the five clauses and fixes, the two
  co-simulation clauses, the `dumpunsound` tail, two developer diagnostics) and four choices: the run log says only a
  delta; patterns 1–3 warn on every binary; patterns 4–5 are confined to where they bite; `dumpunsound` only on a
  measured-unsound printer.
* **look** — none, as the brief said: task 1 draws nothing.
* **suite** — none added.
* **M21 — CLOSES with row M21b** (its sabotage S01 reds M21a, M21b and the six moved command rows).
* **M20 — STAYS OPEN, upstream-blocked.** The fourth frame is what covers its slow-box half: rows VS4b and VS4c are the
  fork and apt 45.2 with leg D cut, and neither is told *"can do everything"*.

---

## Corrections

| | |
|---|---|
| **C1** | **PLAN §16 *Suites that move*: "None move."** Measured: **eight expectations in four existing suites moved** — `test_op_dump_altshow` T2, `test_ase_optier_0963` X5, `test_sim_run_profile` CS176/CS176c/CS176d/CS176e, `test_ase_simdlg_0937` S29 — plus optier S11's filter. §16 did not count M21 and 16d as moves; both change a value an existing row pins. Every one carries a paragraph naming 1470, and every one reds under S00/S01/S02 |
| **C2** | **PLAN §16a is internally inconsistent about frame 2.** *What you see* says the window shows *"nothing at all when the answer is everything"*; §16a's frame 2 and worked fork row are a sentence. The run-log half is decided here (never said); **the window half is task 2's** |
| **C3** | **PLAN §16a's worked rows say "a Commands box".** ASE-L has none — the lines are pre-commands, verbatim lines and a netlist's `.control` — and the two gated kinds are *misread*, not crashed on. Shipped: *"Two kinds of command line are misread by it; ASE-L warns before a run that uses one."* The generic frame-3 draft (noun phrases) and the worked apt row (a clause) had two grammars; shipped one: a noun-phrase list plus whole-sentence asides |
| **C4** | **PLAN §16b pattern 4, "whitespace- or paren-delimited".** ngspice's own rule also delimits by comma and skips the first token (read from source). And a pattern on every command would warn on `print v(gnd)`, where the rewrite is harmless — scoped to text commands. Pattern 5 likewise scoped to `write`/`wrdata` |
| **C5** | **`src/ase.tcl`'s capability-vocabulary comment: `$sourcepath` "came back EMPTY from inside the probe deck".** Did not reproduce in either echo form on apt 45.2 or the fork; annotated in place. `scripts_dir` is still not a key — nothing consumes it yet |
| **C6** | **PLAN §16c: "run once, when the user first asks for Verilog waveforms."** The verdict and the parse rule shipped; **no say-site calls them and no probe leg collects `$sourcepath`**. Binds later work (below) |
| **C7** | **PLAN §16's Files table: ≈ +400 lines.** Shipped +710 / −2 in `src/ase.tcl`, most of it the comments the house style requires; no `ase_window.tcl` change (task 2's +40) |
| **C8** | ⚠ **`evidence/fork-features.md` §14, row 4 — *"ngspice **47** gets the fast path back"* — and §13.3's *"upgrading to ngspice 47 will make this much faster"* both name a release that does not exist**, which §16a (a) forbids. **16e's release note must not copy either** |
| **C9** | **§16a had no rule for a program measured not to be a simulator.** `test_sim_run_profile` CS182b found it: such a program gets no frame (`cap_report` owns its sentence) |
| **C10** | *(this crew's own, all caught before hand-over)* the first patch script died on a Python raw string ending in a backslash (nothing written); CS176e's expected word count was 10 for 11; CS5's first cut reddened on `||`; S49's anchor was not unique; S00/S36 first returned NORESULT through raising extractors; CS4 and VS12 passed vacuously on the pre-change tree; a smoke script's brace-quoting made `scripts_dir_of` look broken when it was not |

---

## What task 2 builds on

1. **The window's sentence is `ase::variant_sentence ngspice $path $caps`**, with `$caps` from
   `ase::sim_capabilities_path` **only when `ase::sim_caps_have_path` answers 1** — `ase::casemode_status`'s own shape,
   so opening the dialog starts nothing (D8). With no fresh answer, pass `{known 0}`: that is frame 1, R9-678. Apply
   `casemode_status`'s earlier guards first (no path, no program, no probe hook), which already have their sentences.
2. **`ase::variant_frame` is the token for layout** — `unmeasured` / `complete` / `missing` / `partial` / `{}`. Whether
   `complete` shows R9-679 or nothing is task 2's decision (C2).
3. **Never call `ase::variant_say` from the window** — it records "said" and would silence the run log's line.
4. **R9-678 and R9-679 are said nowhere today**; they are the window's.
5. **The look debt with two registry entries**: `/usr/bin/ngspice` should read EX1's sentence and the fork EX2's.
6. **16e's description half**: the three worked sentences are measured (EX1–EX3) — with C8's correction to
   `fork-features.md` §14.

## What binds later work

1. **The `variant_notes` contract**: a list of `{kind missing|unmeasured|aside text … key …}`; anything else dropped;
   a raise gives no sentence; no hook, no sentence. **Name only what ASE-L offers and can emit** — so ⚠ **when Stage 14
   makes `pss` renderable, stock 47 (and any build without it) will read *"except the PSS analysis"*, and apt 45.2 —
   whose PSS converges on nothing measured (`evidence/pss-two-binaries.md`) — will not.** That belongs in ⚖ R7's
   framing.
2. **The `lint_control_text` contract**: `{index pattern clause remedy ?refuse_key?}`; a `refuse_key` only for a key
   that is measured — and D50 means none for the crash family.
3. **16c is not wired** (C6): the say-site, and a leg that records `$sourcepath` as Band 1 `scripts_dir`, are owed
   before the two co-simulation clauses reach a user.
4. **`dumpunsound` is a new reason token** anywhere `reason` is read (`meta optier` included).
5. **ASE-L runs now carry `-D casemodewrite`** for a non-fold request: the fork stamps `Option: casemode=` into the
   raw, which loads cleanly on 45.2 (§4.8b); a stock binary takes the word as an inert variable.
6. **`run_deck`'s order is pinned by LN10**: `preflight_notes` between the netlist read and `preflight_gate`,
   `variant_report` directly after `cap_report`, both into `casenote` before the record.
7. **M21b runs the fork under whatever `HOME` the harness gives it**: a `~/.spiceinit` that sets `casemode` would
   override `-D` (A2) and red the row for a reason outside the tree.

## Hygiene

* **One tree-reading runner phase at a time**: baseline (both arms in parallel) → solo dialogs re-run → patch →
  after1 → the two fixes → after2 → sabotage (after `RUNNER DONE` and no `xschem` alive by `comm`) → hardening →
  S00/S36/S49 re-runs → final restored-tree rows.
* **Every wait had a deadline** in the brief's shape (540 s and 1200 s, reporting progress and liveness by `comm`);
  every command a `timeout`. No `pkill`, no `pgrep -f`.
* **Nothing under `~/.xschem/`**: every launch had `HOME` pointed at a scratch directory; every simulation used a
  scratch `rundir`. `owed.sh` wrote the real ledger once (`add rule 1470`), after a backup.
* **Snapshots disarmed**: the pre-change and post-fix copies, `sab.py` and `patch_ase.py` are under
  `…/scratchpad/ARCHIVED_DO_NOT_RESTORE/i1470/`. Logs kept: `…/s16/logs/{base,base_solo,after1,after2,final2,final2s,final3,harden,new}/`,
  `…/s16/sab/`, `…/s16/caps/`, `…/s16/m21/`, `…/s16/sp/`, `…/s16/sp2/`, `…/s16/smoke/`.
* **No background process of this crew is running** — checked by process name (`xschem` 0, `ngspice` 0, `sab.py` 0).
* ⚠ **If this crew is woken after collection: `git status` and `git log` before touching anything.**

`…/scratchpad` is `/tmp/claude-1000/-home-analog-dev-xschem-claude/c8183bb1-7387-41d6-9d30-a409f8d7e1a3/scratchpad`.
