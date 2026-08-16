# open_pdk merge 5 — what actually happened

Merge `e7ae4d77`, repairs `d97fbd3e`, both on `fluid-editing`, 2026-08-15, **unpushed**.
Safety tag `pre-open-pdk-merge-5` = `5a8f01fd`.

The plan for this merge is `open_pdk_merge5_premerge_analysis.md` (written 2026-08-13).
**It was overtaken by events and should be read as history, not as instructions** — §1
below says why.

---

## 1. The merge was a fifth the size the plan predicted, and the reason is reusable

The plan sized it at 22 commits in, 113 of ours out, merge base `99d6f1ed`, two textual
conflicts, and a *three-leg* audit A/B because both sides had independently reworked the
audit scorer.

Between writing and running, `open_pdk` **merged `fluid-editing` at `7af2da9e`** — the
coordination note at the end of `open_pdk_merge5_questions.md` asked them to, and they
did — and then landed **`9be9c2d5`, "the six clean auto-merges that were nonetheless
wrong"**, repairing what pulling us into them had broken.

So the merge base moved forward to **`ca4e0065`, one of our own commits**, and the job
became:

| | plan (2026-08-13) | actual |
|---|---|---|
| their commits | 22 | **29** |
| our commits | 113 | **4** |
| textual conflicts | 2 (`FAQ.md`, `full_audit.sh`) | **0** |
| files touched by both | many | **2** |
| audit legs needed | 3 (scorer isolation) | **1 + a targeted rerun** |

The two both-touched files were `src/ase_window.tcl` (ours at ~line 550, theirs at
~2200+) and `doc/claude/specs/ase_l.md`. Both auto-merged as exact unions.

**Re-run the recon. A pre-analysis older than the other branch's last push is a
hypothesis, not a finding.**

## 2. The one measurement that made verification cheap

```sh
git diff --stat github/open_pdk..HEAD -- 'src/*.c' 'src/*.h'   # empty
```

The merged C is **byte-identical to `github/open_pdk`** — our four commits contain no C at
all. The user had already eyeballed and audited that executable, so the entire C surface
arrived pre-verified and the review collapsed to "two Tcl files and a test harness".

Take this diff first on every merge. It is one command and it decides how much of the rest
you actually owe.

Delta of merged `HEAD` over their tip: `src/calculator.tcl` +333, `src/ase_window.tcl` +21
(one menu line and its rationale), the `tests/headless/*.sh` harness, and docs.

## 3. Collision checks — all clean

Measured, not assumed:

| check | result |
|---|---|
| `src/Makefile.in` | untouched by them, and untouched in the merge result → **no `./configure` owed** (the recurring trap did not fire) |
| every `source $XSCHEM_SHAREDIR/*.tcl` | all 16 present and in `install_shares` |
| `set_input_binding` | they added **zero** |
| `src/keybindings.csv` | untouched by them |
| `src/actions.csv` | +2 rows (`select.same_net_by_label`, `…_add`), no id collision |
| `ui_state` / `ui_state2` bits | neither side added any |
| issue numbers | theirs 0249–0272, 0350–0415; ours added none in these 4 commits — disjoint |
| `calc::open` call sites | all three intact (`xschem.tcl:15143`, `wave_viewer.tcl:17599`, `ase_window.tcl:561`) |

## 4. The one real defect: `test_descend_symbol` (issue 0414)

Their SNW rows call `xschem symbol_in_new_window` with nothing selected. That arm composes
`<work>/descend_parent.sym`, a fixture that has never existed in any commit;
`load_schematic()`'s `fd==NULL` branch raises the modal `alert_` that no headless run
dismisses. **It does not fail, it hangs** — `AUDIT_TIMEOUT` (300 s) and `exit 1` on every
full run.

Fixed by adding it to `nogui_tests` in `tests/headless/full_audit.sh`, which is exactly the
fix issue 0414 identified and measured on the open_pdk side but left unapplied. Headless it
is 38 checks, exit 0.

**Whose "pre-existing"?** 0414 is marked "pre-existing, predates merge 5" — true from
*their* vantage, where the SNW rows had been in the branch for a while. On *our* branch the
test file arrived with the merge, and it went **PASS pre-merge → TIMEOUT post**. That is
merge-caused here, which is why it was fixed inside this merge.

Their sibling issue **0415** (`test_ase_log_seam_0207` and `test_select_at` missing from
`logdir_tests`; 2 reds, 26 + 5 checks, same one-word shape) is red on **both** sides of the
A/B, so it was deliberately **left alone** — folding an unrelated harness fix into a merge
muddies its before/after. It remains OPEN and is still worth a minute.

## 5. 37 stale `file:line` citations — and how to find them

Their +330 to `xschem.tcl`, +574 to `scheduler.c` and +313 to `full_audit.sh` silently
invalidated every pointer our unmerged commits had written into those files. A 28-agent
read-only audit found ~16 of them; a 20-line **difflib line-mapper** found **37** and
resolved the ambiguous ones exactly. Build `old→new` from
`SequenceMatcher(...).get_opcodes()` over `git show <pre-tag>:F` against `git show HEAD:F`,
then scan citations against it.

Three traps it taught:

1. **Scope the scan to files your own unmerged commits authored.** Tree-wide it reports
   **3370** hits — the pre-existing population that issue **0229** already covers.
   Remapping a pointer that was *already* wrong just lands it on a different wrong line.
   For the same reason `doc/claude/specs/ase_l.md`'s `hi_descend` / `viewdata` /
   `set_simulate_button` pointers were left alone: they were wrong at the merge base.
2. **Ranges corrupt under token replace.** `xschem.tcl:7332-7347` needs *both* endpoints
   mapped (`7450-7465`), not a replace of the first number.
3. **Re-running the sweep after fixing reports everything again** — it maps pre→post over
   numbers that are already post. Verify by **content** (`sed -n Np` on the new target).
   And watch the self-inflicted case: editing `full_audit.sh` moved `is_skip` from 229 to
   237 *after* the citation naming 229 had just been written.

Two citations were off by one *before* the merge (`*selectColor white`, the `-stretch`
catch) and were corrected to the line the prose actually names rather than remapped onto
the wrong neighbour. All `src/` edits are comment-only: `git diff -U0 -- src/` on
`d97fbd3e` has no non-comment line.

## 6. Verification

**Post-merge audit (pre-fix):** 313 pass / 17 fail / **1 timeout** (331).
**Post-fix audit:** **314 pass / 17 fail / 0 crash-timeout / 0 skip** (331), WIREEDIT PASS,
0 leaked scratch dirs. Row-by-row diff of the two rosters is exactly one line,
`test_descend_symbol TIMEOUT → PASS`. Nothing else moved.

Raw runs: `doc/claude/batch_F/audit_2026-08-15_postmerge5_prefix.txt` and
`doc/claude/batch_F/baseline_status_2026-08-15_postmerge5.txt`.

**The A/B that carries the weight** is not a second audit but the merge-3 technique: all
**18 non-PASS suites re-run against a pre-merge binary** built in a throwaway worktree from
`pre-open-pdk-merge-5` (`git worktree add --detach`, copy `Makefile.conf` + `src/Makefile` +
`config.h`, `make`). Every suite reporting counts matched **exactly**:

| suite | both sides |
|---|---|
| `test_ase_log_seam_0207` | 16 FAILED (10 passed) |
| `test_ase_window` | 1 FAILED (168 passed) — W7 "simulator produced output before Stop" |
| `test_cadence_drag` | 2 FAILED |
| `test_gf180mcud_libmgr` | 1 FAILED (28 passed) |
| `test_ihp_sg13g2_libmgr` | OVERALL 1 FAILED (65 passed) |
| `test_lib_manager_gui` | 2 FAILED |
| `test_lib_manager_locate` | 1 FAILED (2 passed) |
| `test_lib_sweep` | 5 FAILED |
| `test_reopen_readonly` | 1 FAILED |
| `test_rotate_stretch_short_0104` | 1 FAIL (76 checks) |
| `test_select_at` | 5 FAILED |
| `test_sky130a_libmgr` | 1 FAILED (17 passed) |
| `test_wave_markers` | 6 FAILED (977 passed) |
| `test_wave_sigbrowser_0312` | 2 FAILED (67 passed) |
| `test_wave_sigbrowser_keys` | 3 FAILED (46 passed) |

**Match the mode or the A/B lies.** `test_ciw` and `test_selflog_output` read NORESULT
under `run_suites.sh`'s default mode and FAIL under the audit's — they only match once
re-run as `run_suites.sh --logdir …`, which they then do, on both sides. (Both are issue
0415's `logdir_tests` gap.)

The four libmgr reds are the documented environment failure: the working tree's untracked
`SANDBOX` / `TEST` dirs show up in `library_list`.

## 7. `full_audit.sh` cannot see a `.sh` suite

It globs `test_*.tcl` only (and the explicit-arg path force-appends `.tcl`), so **no `.sh`
self-test is ever run or scored by the audit** — including the ~645 lines our gate
self-test commit `4b893fd2` added. 331 green rows say nothing about them. Their only
automated runner is `owed.sh drain`. Pre-existing, unfixed, worth knowing.

Run by hand for this merge, each A/B'd against the pre-merge worktree:

| suite | merged | pre-merge | verdict |
|---|---|---|---|
| `test_devdisplay.sh` | ALL PASS (39) | — | green |
| `test_gui_gate_batch.sh` | fails=0 | — | green |
| `test_owed.sh` | 2 FAILED (50 passed) — O13's real drain | identical | pre-existing |
| `test_gui_gate_revive.sh` | 5 FAILED (X1 adopt, X2 reap) | identical | pre-existing |

⚠ **The assistant's shell carries `DISPLAY=:0`.** `full_audit.sh` and `run_suites.sh`
self-arm to the dev display and are safe; a bare `tests/headless/test_gui_gate_*.sh` is
**not** and pops panels on the user's real screen. For the gate suites that is the
prescribed arm (R5's borrowed-display branch only fires on `:0`) — but say so out loud.

## 8. Owed

`owed.sh add suite merge5-gui` — a `:0` run of the merge result. Their 29 commits land
gesture teardown, a total canvas ESC, `Ctrl+Alt+Shift+LMB` whole-net select and
`Alt+Up`/`Alt+Down` snap spacing; everything here was verified on Xvfb `:99`. Because the
merged C is byte-identical to the executable the user already eyeballed, this is the
WSLg-event-traffic leg (3 `<Configure>` vs 1), **not** a pixel debt.

`test_gui_gate_batch` and `test_devdisplay` suite debts were **cleared** — both passed on
`:0` during this work.

## 9. Their answers to the two handoff questions

`open_pdk_merge5_questions.md` asked two things. Both are answered by their code:

- **Q1 (scorer baseline)** — moot. Their rework had already absorbed our side at
  `7af2da9e`, so there is only one scorer and no reclassification delta to isolate. The
  old `doc/claude/batch_F/baseline_status.txt` (285/19/1, old scorer) is nonetheless
  **void**; use the post-fix run in §6.
- **Q2 (canvas ESC policy)** — answered in their direction. Issues **0394** (ASE's seized
  canvas Escape never reaches the C Escape terminal) and **0395** (`.mkinst`) file the
  remaining seize sites as *bugs of the same family*, which settles the policy as "the
  canvas ESC slot is total — every consumer must claim, restore **and** reach
  `escape_terminal()`". `src/calculator.tcl` binds no Escape at all and never touches
  `.drw`, so it is not a consumer either way.
