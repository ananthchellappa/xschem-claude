# Stage 16 task 2 — the Simulators-window line, its look debt, and 16e's release note (issue 1471)

**Issue `doc/claude/issues/1471-the-simulators-window-never-says-what-the-program-in-front-of-it-can-do.md`**,
minted by this crew with CLAUDE.md's two checks (1471 outside every reserved band; no file and no reservation
for it in either clone under `~/dev/*`; `NUMBERING.md` pointer → **1472**). Handed over as one task: 16a's
window row, the look debt with two registry entries, and 16e's release note. Receipt 46's *What task 2 builds
on* was the specification. **Not here:** 16c's say-site (receipt 46 C6), which is Stage 16 task 3.

Files touched, and nothing else:

| file | ± | md5 before → after |
|---|---|---|
| `src/ase.tcl` | **+64 / −0** | `a052b663` → **`19d246d7`** |
| `src/ase_window.tcl` | **+34 / −2** | `96095410` → **`55b021fd`** |
| `tests/headless/test_ase_simwin_variant_1471.tcl` | **new**, 695 lines | → `1140d0e2` |
| `tests/run_regression.tcl` | +11 / −2 (`hcases` **and** `dcases`, one paragraph) | `70313da8` → `cca6117d` |
| `doc/claude/ase_analyses_batch/RELEASE_NOTE.md` | **new**, 145 lines | → `5bb0b696` |
| `doc/claude/ase_analyses_batch/evidence/stage16-simulators-cold.png` · `…-detected.png` | **new** (the look) | → `514ed893` · `d7bdf245` |
| `doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md` | +29 / −1 (R9-720, R9-721; R9-679's *Where*) | `f0e12773` → `e8d509ab` |
| `doc/claude/issues/NUMBERING.md` | +11 / −1 | `097f2169` → `08c89a12` |
| the issue file (76 lines), this receipt | new | |

**No C, and no new `.tcl` under `src/`**: `make -q -C src` rc 0 before and after, `src/xschem` `96fc4899`
throughout, `src/xschem.tcl` `87ba1eec` unchanged, so no `Makefile.in` / `./configure` obligation. **No commit, no
`git add`, no stash/restore/clean/push. `tests/run_regression.tcl` edited, NOT run.** HEAD `4e1e1cac` at start
and at hand-over; nobody else moved the tree. **No simulation on a bench under `sky130A/`; nothing under
`~/.xschem/`; nothing written to `xschem-op-wcard`.**

---

## ⚠ THE CRASH RULE — HOW IT WAS KEPT

The only processes this crew started on a real ngspice were **the ordinary capability probe, through the real
Detect button**: rows WG7/apt and WG7/fork (every display run of the new suite, and every display arm of the
campaign that reached them) and the look script. That is the seven short `-b` decks receipt 46's EX rows
already run. `/usr/bin/ngspice` never aborted. The re-run suites also start what they already started: EX1–EX3
and M21b in `test_ase_variant_1470`, and the probes in `test_ase_simcaps_0948`. **No linter pattern was run on
any binary.** No core was dumped, and no rc was 134 or 139.

---

## THE HEADLINES

### 1. The line — where it is, and what it says on the two real binaries

⚠ **The casemode status line is not in the Simulators list. It is in the ROW EDITOR** (`$top.simrow.status`,
*Setup > Simulators… > Edit…*), which is where Detect lives. So that is where the sentence went:
`$top.simrow.variant`, a label at grid row 5, directly beneath the status line with the same span and the same
420 px wrap; the buttons move to row 6. Its one writer is `ase::ui::simdlg_variant_paint`, which paints what it
is handed and decides nothing.

MEASURED HERE through the real menu and the real Detect (the look script; rows WG7/apt and WG7/fork):

| program | status line (unchanged) | the new line |
|---|---|---|
| **`/usr/bin/ngspice`**, cold | *"…has not been tried yet, so fold is all that can be offered; press Detect to try it."* | R9-678: *"ASE-L has not measured /usr/bin/ngspice yet. Press Detect in the Simulators window to find out what it can do."* |
| **`/usr/bin/ngspice`**, after Detect | *"/usr/bin/ngspice can hand net names back these ways: fold."* | *"/usr/bin/ngspice can do everything ASE-L offers except case-sensitive net names and the fast operating-point dump. Its fast dump prints wrong numbers, so operating points are saved one device at a time; no ngspice release has the fix yet. Two kinds of command line are misread by it; ASE-L warns before a run that uses one."* — EX1's sentence, word for word |
| **the fork**, after Detect | *"…can hand net names back these ways: fold, preserve, distinguish."* | R9-679: *"/home/analog/dev/ngspice/build-ver_50/src/ngspice can do everything ASE-L offers."* — EX2's |
| either, reopened | the measured sentence | the same sentence, **read from memory — 0 probe-door entries** (WG7) |

### 2. C2 — the window shows the complete frame. Decided, reasoned, and on the queue as rule `1471`

PLAN §16's *What you see* said *"nothing at all when the answer is everything"*. §16a's **rule** said *"a user
with a complete build reads eleven words and stops"*, and its worked table gives the fork a sentence. **Shipped:
the sentence (R9-679).** There are three reasons.

1. **The run log keeps the delta rule because it repeats**: once per binary per session, on every run. The
   window is looked at on purpose.
2. **In the window an empty line already means four other things**:
   * no location typed;
   * no program at it;
   * no way to try it;
   * after Detect, a probe that did not answer.

   Reading *"everything"* off that same silence would be a fifth meaning. Silence is this batch's
   most-met defect shape (CREW_BRIEF, *a guard against absence*).
3. **R9-679 would otherwise be minted and said nowhere at all.**

Three more choices rode along, also under rule `1471`:

* **R9-678 is shown beside a status line that also names Detect.** That is two mentions of one button in one
  editor, taken as receipt 46 specified and recorded rather than resolved.
* **After a Detect whose probe did not answer, the line is empty**, not R9-678.
* **An emptied Program field empties the line.** The status line above keeps its last sentence; that is
  existing behaviour and untouched.

### 3. The window composes nothing — two schema procs decide

`src/ase.tcl`, beside `ase::variant_report`:

* **`ase::variant_status {backend path eargs}`** runs at editor-open and whenever the Program field is left.
  It has **`ase::casemode_status`'s shape exactly**.
  * No location, no program, a folder, or no probe hook gives `{}`; the status line owns each of those.
  * Otherwise it returns `ase::variant_sentence` over the cached answer **only when the peek
    `ase::sim_caps_have_path` answers 1**, and over `{known 0}` (frame 1) when it does not.
  * It starts nothing (D8).
* **`ase::variant_detected {backend path caps}`** runs after Detect and is about the answer Detect got.
  * A `known` that is not 1 gives `{}`.
  * ⚠ **It is not the peek, on purpose.** A `known 0` answer is never cached, so the peek reads it back as
    "never measured". The line would then tell the user to press the button they just pressed, which is
    issue 1371's refuted sentence. Row WS5's last term measures that the peek *would* say it.
* **Neither calls `ase::variant_say`** (receipt 46's warning), so looking at a program never silences the run
  log's line (WS6).
* **Detect empties the line before the flush** that precedes the launch, so the frozen screen shows neither
  the last program's answer nor *"press Detect"*. WG5 reads the label from inside the stood-in probe, at the
  instant it is entered, and gets `{}`.

### 4. The release note — `doc/claude/ase_analyses_batch/RELEASE_NOTE.md`

* **The description has 24 tagged claims, E1–E24.** Each tag names an evidence row, and each row names the
  receipt or evidence file that measured the claim and the binaries it was measured on. There are three parts:
  * *The same on every ngspice we test*: E1–E14, OP/DC/AC/TRAN through annotation.
  * *What differs*: E15–E23, casemode, the dump, the misread and aborting lines, VCD, noise contributions,
    point counts and `measureprec`.
  * *Handled for you*: SP names and `meas` digits.
* **Every cited receipt line was re-read by this crew before it was quoted.**
* **The support sentence (⚖ R11, Option C) has one departure from the draft.** *"…against stock upstream at
  the 47 tip…"* became *"…against stock upstream ngspice built from source…"*, because 47 is not a release
  (receipt 46 C8's rule). The departure is recorded in the note and in R9-720, and filed under rule
  `1471_release_note_destination`.
* **It is held to its rules by suite rows WR1–WR4:**
  * a claim with no evidence row, or a row naming no file that exists, reds;
  * "basic", PSS, an ngspice ≥ 46 named, a future fix, or a version floor reds;
  * the support sentence must name all three binaries and "not refused";
  * the measured *"no ngspice release has the fix yet"* must be present, and C8's two sentences absent.
  * Every scanner is also run over a planted sentence and must fire.
* **⚠ Where it ships is not this crew's call.** The `Changelog` is upstream xschem's. The note stays in the
  batch directory under rule `1471_release_note_destination`.
* **Deliberately left out, with the reasons in the note's own last section:**
  * PSS on every row (`pss-two-binaries.md`; ⚖ R7 is back with the user);
  * the phantom `v(all)` column;
  * XSPICE event counts, where the evidence disagrees (below);
  * any feature claim about stock upstream beyond its probe.

### 5. Three things the untouched tree and the campaign plan found — all repaired before the campaign ran

* **The counting wrapper broke the real probe.** The first display run of the suite got **WG7/apt and
  WG7/fork red**: the real probe was entered once and the line stayed empty. The wrapper had parked the real
  `::ase::backend::ngspice::capabilities` at `::zz_…`. A proc runs in the namespace its name is in, so every
  unqualified call in its body resolved globally and the probe answered `known 0`. It is now parked inside its
  own namespace, and the paragraph above `hook_install` says why.
* **WS6 was green on the untouched tree** (the *before* run), because procs that do not exist cannot record
  anything either. It gained a first term requiring both procs to answer the sentence, and S00 now reds it.
* **WG6 could not see sabotage S12.** The field was emptied after the missing file, whose line is already
  empty, so a paint moved behind the early return still passed. Found while writing the campaign and reordered
  so the field is emptied straight after the fork's sentence. S12 reds WG6. A term was also added for Detect's
  own empty-field branch (S19).

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

All 2026-09-15. Every xschem launch was `--nolog` with `HOME` pointed at a fresh scratch directory. The display
arm ran on `:99` (Xvfb + **openbox**) with `XSCHEM_DEVDISPLAY_DIR` set to the real state directory and
`GUI_GATE=0`. Every command ran under `timeout`, in the foreground.

| claim | evidence |
|---|---|
| the two sentences and status lines in headline 1, cold and after Detect, on apt 45.2 and the fork | **MEASURED HERE** — the look script (`look.log`) and rows WG7/apt, WG7/fork |
| opening Simulators… and Edit… starts nothing | **MEASURED HERE** — the counted probe door and the MARK stand-in, WG2 and WG3; positive control WG5 |
| the line's placement | **MEASURED HERE** — `grid info`, WG1 |
| `ase::analysis_renderable ngspice pss` → 0; the other ten → 1 | **MEASURED HERE**, headless script |
| every receipt sentence the release note quotes | **READ HERE**, at the lines cited — receipts 10, 11, 12, 14, 15, 16, 19, 20, 21, 23, 31, 32, 33, 36, 38, 39, 40, 41, 42, 43 and the evidence files |
| the note's 24 claims themselves | **TRANSCRIBED** from those measurements; this crew re-ran none of them |
| `unset` / `define` / `load` abort apt 45.2 | **TRANSCRIBED**, `evidence/fork-dependencies.md` B1.1–B1.4 — never run |
| `test_ase_dialogs`' display arm red before this change | **MEASURED HERE** on the untouched tree: G2sens, GG3, GG9, GN1b |

---

## What shipped

| where | proc | change |
|---|---|---|
| `src/ase.tcl` (schema) | `ase::variant_status` | **new** — the peek-side sentence |
| | `ase::variant_detected` | **new** — the after-Detect sentence |
| `src/ase_window.tcl` | `ase::ui::simdlg_editor` | the `.variant` label at row 5; buttons to row 6; the row-order comment |
| | `ase::ui::simdlg_variant_paint` | **new** — the one writer of the line |
| | `ase::ui::simdlg_case_status` | paints the line from `ase::variant_status`, **ahead of** its empty-field return |
| | `ase::ui::simdlg_detect` | empties the line before the flush; paints `ase::variant_detected`'s answer after; its empty-field branch clears it |

No state key, no mint kind, no new sentence in `ase::sim_why`. The window file types none of the frames' words
(WS7 greps the raw file).

### `tests/headless/test_ase_simwin_variant_1471.tcl` — NEW AT **12 headless / 21 display**

* **Sections that run on both arms:**
  * **WS** (7) — the two procs, from primed caches and stand-ins; no binary.
  * **WR** (4) — the note; the file only.
  * **ST** (1).
* **Section WG** (9) runs on the display arm: WG0 fixture, WG1 placement, WG2 cold open, WG3 two entries,
  WG4 fourth frame, WG5 Detect, WG6 the Program field, WG7/apt and WG7/fork on the real binaries.
* WG7 self-skips, uncounted, when a binary is absent.
* It ends with a whole-line `OVERALL:` and `exit [expr {$fail ? 1 : 0}]` as its last statement.
* It is added to **`hcases` and `dcases`** with one paragraph.

---

## Suites — before → after, both arms, with rc

**Before** is the untouched tree: `before.sh` swapped HEAD's two `src` files in, md5-checked `a052b663` /
`960954107`, and restored through an EXIT/TERM trap (`RESTORED OK 19d246d7 55b021fd`, 168 s). **After** is this
tree, 165 s. Both used `runner.sh`, one fresh `HOME` per suite, `timeout --kill-after=20 240`.

| suite | headless before | headless after | display before | display after |
|---|---|---|---|---|
| **`test_ase_simwin_variant_1471`** | 6 FAILED (6 passed), rc 1 | **ALL PASS (12), rc 0** | 14 FAILED (7 passed), rc 1 | **ALL PASS (21), rc 0** |
| `test_ase_variant_1470` | 57, rc 0 | 57, rc 0 | 57, rc 0 | 57, rc 0 |
| `test_ase_simdlg_0937` | 5, rc 0 | 5, rc 0 | 55, rc 0 | 55, rc 0 |
| `test_ase_simcaps_0948` | 211, rc 0 | 211, rc 0 | 211, rc 0 | 211, rc 0 |
| `test_ase_simreg_0931` | 117, rc 0 | 117, rc 0 | 117, rc 0 | 117, rc 0 |
| `test_ase_window` (W1m) | 56, rc 0 | 56, rc 0 | 295, rc 0 | 295, rc 0 |
| `test_ase_dialogs` | 37, rc 0 | 37, rc 0 | **4 FAILED (381 passed), rc 1** | **4 FAILED (381 passed), rc 1** — same four |
| `test_ase_persist` | 49, rc 0 | 49, rc 0 | 153, rc 0 | 153, rc 0 |
| `test_ase_core` | 638, rc 0 | 638, rc 0 | 638, rc 0 | 638, rc 0 |

Every other cell reads `ALL PASS (<n>)`.

**Not a count diff — a name diff.** For the eight existing suites on both arms, the sorted `status id` list
after versus before is **identical: `SAME` × 16.** The new suite's diff is exactly its own rows going red → ok.

⚠ **`test_ase_dialogs`' display arm is red on the untouched tree and not by this task**: G2sens, GG3, GG9 and
GN1b, the same four receipt 46 named. That file is not in `dcases`, so this is not a T1 count. Recorded, not
chased.

⚠ **The *after* logs of the new suite predate two hardening edits** — WS6's first term and WG6's reorder, both
from headline 5. The suite at its final md5 `1140d0e2` was re-run three times, all ALL PASS 12 / 21, and none
of the eight existing suites reads it:

1. before the campaign;
2. inside it (S00 re-ran the untouched tree);
3. on the restored tree (below).

### Per binary

* **WG7/apt and WG7/fork** ran on every display run and in every campaign display arm: **0 SKIPPED**. Detect
  probed `/usr/bin/ngspice` and the fork.
* **Everything else in the new suite** is pure Tcl and starts no simulator: the probe door counts 0 and no
  MARK file appears.
* **Stock upstream** was started only by the re-run `test_ase_variant_1470`, whose EX3 row is untouched.

---

## `.state` byte identity

Row **ST1**, through `tests/headless/state_roundtrip.tcl`, green on both arms before the campaign, in every arm
that did not touch `omit_if_empty`, and on the restored tree:

```
tracked 104    bad {}    control_disagrees 1    control_agrees 1
```

No state key was added. Sabotage **S28** removes `sweep` from `ase::omit_if_empty` and reds ST1 on both arms.

---

## THE SABOTAGE CAMPAIGN — 34 arms, every one of the 21 rows reddened by at least one, 0 restore mismatches

`sab.py`, 15:42:34–15:43:36 (62 s). It started after the *after* run, with the positive pre-row ALL PASS 12 / 21
and **no `xschem` alive, matched by `comm`**. **The gate is a positive assertion and was fed the empty case
first**: `GATE CONTROLS empty=NORESULT partial=NORESULT pass=SURVIVED fail=KILLED`.

Each arm:

1. verified the post-fix md5s;
2. applied its mutation, each anchor occurring **exactly once** (0 NOT APPLIED);
3. ran the new suite on both arms;
4. read reds **by row name**;
5. restored with a plain write and compared md5s.

The restore was guaranteed by `try/finally` plus SIGTERM/SIGINT handlers. Everything is Tcl or Markdown, so
nothing needed building. `h:` survivors are the display-only rows' arms, expected. There were no NORESULTs.

| # | what I broke | reds |
|---|---|---|
| **S00** | **the whole pre-change `src/ase.tcl` + `src/ase_window.tcl`** | h: WS1–WS7 · d: WS1–WS7, WG1–WG6, WG7/apt, WG7/fork |
| S01 | `variant_status`: the no-program guard gone | WS1 · WG6 |
| S02 | `variant_status`: the no-probe guard gone | WS1 |
| S03 | `variant_status` measures instead of peeking | WS2 WS4 WS5 · WG2 WG5 WG7/apt WG7/fork |
| S04 | the cached answer never read | WS3 WS4 WS6 · WG3 WG4 WG6 WG7/apt WG7/fork |
| S05 | `variant_status` suppresses the complete frame (C2 reversed) | WS3 WS4 · WG3 WG6 WG7/fork |
| S05b | `variant_detected` suppresses the complete frame | WS5 · WG5 WG7/fork |
| S06 | `variant_detected` reads the peek | WS5 · WG5 |
| S07 | `variant_detected`: the `known` guard gone | WS5 · WG5 |
| S08 | `variant_status` goes through `ase::variant_say` | WS6 |
| S09 | `variant_detected` drops the fourth frame | WS5 |
| S10 | the line never gridded | WG1 |
| S11 | the line gridded below the buttons | WG1 |
| S12 | `simdlg_case_status` paints after its empty-field return | WG6 |
| S13 | `simdlg_case_status` never paints the line | WS7 · WG2 WG3 WG4 WG5 WG6 WG7/apt WG7/fork |
| S14 | Detect does not empty the line before the launch | WG5 |
| S15 | Detect paints the peek | WS7 · WG5 |
| S16 | Detect never paints what came back | WS7 · WG5 WG7/apt WG7/fork |
| S17 | a frame's words typed into the window file (a comment) | WS7 |
| S18 | the window calls `ase::variant_say` | WS7 |
| S18b | a second writer of the line | WS7 |
| S19 | Detect's empty-field branch does not clear the line | WS7 · WG6 |
| S20 | note: evidence row E24 deleted | WR1 |
| S21 | note: says "basic" | WR2 |
| S22 | note: PSS as available | WR2 |
| S23 | note: C8's *"ngspice 47 gets the fast path back"* | WR2 WR4 |
| S24 | note: *"ngspice 44 or newer"* | WR2 |
| S25 | note: the support sentence loses a binary | WR3 |
| S26 | note: the measured wording removed | WR4 |
| S27 | note: an evidence row names a missing file | WR1 |
| S28 | `sweep` leaves `ase::omit_if_empty` | ST1 |
| S29 | `ase::ui::window_for` answers nothing (fixture) | WG0 |
| S30 | Detect never probes | WG5 WG7/apt WG7/fork |
| S31 | `variant_status` serves a stale answer (no stamp check) | WS4 |
| **final** | **the restored tree**, `19d246d7` / `55b021fd` / `5bb0b696` | **1471 ALL PASS (12) headless, (21) display · simdlg display 55 · variant_1470 display 57** — rc 0 each, ST1 green in all three |

**Coverage, row → arms that reddened it:**

| rows | arms |
|---|---|
| WS1 | S00 S01 S02 |
| WS2 | S00 S03 |
| WS3 | S00 S04 S05 |
| WS4 | S00 S03 S04 S05 S31 |
| WS5 | S00 S03 S05b S06 S07 S09 |
| WS6 | S00 S04 S08 |
| WS7 | S00 S13 S15 S16 S17 S18 S18b S19 |
| WR1 | S20 S27 |
| WR2 | S21–S24 |
| WR3 | S25 |
| WR4 | S23 S26 |
| ST1 | S28 |
| WG0 | S29 |
| WG1 | S00 S10 S11 |
| WG2 | S00 S03 S13 |
| WG3 | S00 S04 S05 S13 |
| WG4 | S00 S04 S13 |
| WG5 | S00 S03 S05b S06 S07 S13 S14 S15 S16 S30 |
| WG6 | S00 S01 S04 S05 S12 S13 S19 |
| WG7/apt | S00 S03 S04 S13 S16 S30 |
| WG7/fork | S00 S03 S04 S05 S05b S13 S16 S30 |

**WR1–WR4, ST1 and WG0 stay green under S00 by design**: they pin a file or a fixture the untouched tree
already has, and each has its own killer.

Logs: `…/s16t2/sab/results.txt`, `…/s16t2/sab/logs/<arm>.<h|d>.log`.

---

## Debts — before → after

`owed.sh count`: **182 rule, 69 look, 11 suite → 184 rule, 70 look, 11 suite.** The ledger was backed up first
(`…/s16t2/owed_backup/`, 263 files). Every add answered `recorded`, stamped `xschem-claude`.

* **rule `1471`** — the window's four choices: C2 (the complete frame is shown), R9-678 beside a status line
  naming Detect, empty after an unanswered Detect, empty for an emptied field. No new UI string; R9-678…R9-682
  are re-used.
* **rule `1471_release_note_destination`** — where `RELEASE_NOTE.md` ships (the `Changelog` is upstream's);
  the departure from R11's draft (R9-720); the description as new copy (R9-721). **Filed separately from
  `1471`, so each is one ruling.**
* **look** `the_Simulators_row_editor_s_new_line_saying_what_the_program_can.1789512217.468684` — *"suites
  green, please look"*. Two registry entries side by side, `/usr/bin/ngspice` and the fork, cold and after
  Detect: `evidence/stage16-simulators-detected.png` and `evidence/stage16-simulators-cold.png`.
  * ⚠ **Taken on `:99` (Xvfb + openbox), not the user's screen.**
  * **Side by side is two session windows' editors**, because the line lives in the row editor, which shows
    one program at a time.
  * I looked at the pixels. The line sits under the status line in the same font and wraps inside the dialog;
    apt 45.2's sentence is six lines at 420 px and makes the editor 307 px tall against the fork's 256.
* **suite** — none added.
* **R9**: 719 → **721** entries, from 34 → **35** issues, for `LEDGER.md`'s count. `R9_COPY_REVIEW.md`'s own
  header still says *"671 strings, from 32 issues"*; it was stale before this task and is untouched.

---

## Corrections

| | |
|---|---|
| **C1** | **PLAN §16a / §16 *Re-measure*: "the Simulators window row beside the existing casemode status line" and "two registry entries … side by side … in one shot".** The status line is in the **row editor** (`$top.simrow`), not the Simulators list, and the row editor shows one program. The sentence went beside the status line, as §16a says. The one-shot look is **two session windows' editors** placed side by side |
| **C2** | **PLAN §16's Files table: `ase_window.tcl` ≈ +40, schema unchanged.** Shipped +34 / −2 in the window **and +64 in `src/ase.tcl`**. "No second composer in `ase_window.tcl`" puts the guard ladder and the peek on the schema side, as `ase::casemode_status` already is, so two schema procs exist |
| **C3** | **PLAN §16e: "the ordinary deck already runs byte-identically on apt 45.2"** is §0.13.1's measurement, **scoped to op and tran** (receipt 03 says so). The note does not make that claim in general; it cites a per-analysis measurement for each row instead |
| **C4** | **`evidence/binary-differences.md` disagrees with itself and with M9.** Its prose says *"The differences are six"* and *"the four real differences"* over a nine-row table. Its row 3 (XSPICE events, 10 against 11) contradicts `evidence/m9-event-vcd-attach.md` (counts equal, times differ). The note omits event counts and says why. The file is not edited — the brief said do not re-derive it |
| **C5** | **⚖ R11's drafted support sentence names "the 47 tip".** Shipped *"stock upstream ngspice built from source"* under C8's rule, recorded in R9-720 and rule `1471_release_note_destination`. R11's condition 3 still binds: when a 47 release exists, the phrase becomes its name |
| **C6** | *(this crew's own, all caught before hand-over)* the counting wrapper parked the real probe outside its namespace (WG7 red on the first display run); WS6 passed vacuously on the untouched tree; WG6's order could not see S12; the new suite's *after* logs predate those two hardenings, hence the three later ALL PASS runs at `1140d0e2` |

---

## What binds later work

1. **The window reads only `ase::variant_status` and `ase::variant_detected`.** A new frame or clause needs no
   window change. A new *reason the line is empty* belongs in those two procs, never in `ase_window.tcl`
   (WS7 greps the window for the frames' words and for any `variant_*` composer call).
2. **`$top.simrow` row order is now Name 0, Program 1, Case 2, -n 3, status 4, the line 5, buttons 6.** WG1
   pins the line's place relative to the status line and the buttons, not by number.
3. **Any edit to `RELEASE_NOTE.md` runs through WR1–WR4 in T1's `hcases`.** A new claim needs an `[E<n>]` tag
   and an evidence row naming an existing file.
4. ⚠ **When Stage 14 makes `pss` renderable, WR2 still reds on a PSS mention in the note, deliberately.** The
   note must not promise PSS on apt 45.2, where it converges on nothing measured. ⚖ R7 decides; the scanner
   changes only with that ruling.
5. **The note's tested set must be re-measured when it moves** (R11 condition 3), and its "stock upstream"
   rows are the probe's only (the note's last section).
6. **T1's `dcases` now starts apt 45.2 and the fork**, through Detect in WG7 (the ordinary probe, about 2 s).
   Headless (`hcases`), the suite starts nothing.
7. **Task 3 (16c's say-site) is untouched.** The co-simulation clauses still reach no user.

## Hygiene

* **One tree-reading phase at a time, in this order:**
  1. first runs;
  2. *before* (swap and restore);
  3. *after*;
  4. look;
  5. pre-row;
  6. campaign;
  7. restored-tree rows.

  Only the *before* and campaign phases changed `src/`, and both restored with an md5 check.
* **Every command had a `timeout`, and every run was in the foreground.** No background runner and no waiter
  loop were used, so none can wake later. No `pkill`, no `pgrep -f`; processes were checked by `comm` at every
  phase boundary, and at hand-over **`xschem` 0, `ngspice` 0, `python3` 0**.
* **Nothing under `~/.xschem/`.** Each launch used its own scratch `HOME`, the probe work directory was
  redirected into scratch, and `::USER_CONF_DIR` was redirected. `owed.sh` wrote the real ledger three times,
  after a backup.
* **Snapshots disarmed.** `snap/` (HEAD and mine), `sabsnap/`, `before.sh` and `sab.py` are under
  `…/scratchpad/ARCHIVED_DO_NOT_RESTORE/i1471/`.
* **Logs kept:** `…/s16t2/logs/{first,base,after}/`, `…/s16t2/pre/`, `…/s16t2/sab/`, `…/s16t2/final/`,
  `…/s16t2/look/` (with `look.log` and four PNGs), and `…/s16t2/runner.sh`, `look_1471.tcl`.
* ⚠ **If this crew is woken after collection: run `git status` and `git log` before touching anything.**

`…/scratchpad` is `/tmp/claude-1000/-home-analog-dev-xschem-claude/c8183bb1-7387-41d6-9d30-a409f8d7e1a3/scratchpad`.
