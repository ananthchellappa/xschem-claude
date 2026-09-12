# Ledger — ASE-L analyses batch

The baseline below was measured **on 2026-09-09, before any crew started**, in the two
trees as they stood. Every number in it is something someone will diff against later, so it
was measured on the day rather than copied out of a dossier — where a dossier's number
turned out to be stale, the correction is in this file and stays visible.

Between the baseline and the stages there is **Rulings answered**, added 2026-09-10 when ⚖ R1
became the first ruling the user settled — a ledger whose rulings never resolve is not a
ledger. Below that there is **one empty section per stage, 0 through 14**, plus the terminal
**Stage 15** the adapter pivot added on 2026-09-10. A crew fills its
own section when its stage lands, in the shape the exemplars use
(`ase_l_ux_batch/LEDGER.md`, `descend_run_batch/LEDGER.md`): status, commit, T1, suites
moved with floors **before → after**, adversary findings with dispositions, ledger debts
filed, and the path to the receipt. A stage with no receipt is not landed.
**Numbering 0–15 is frozen** — new work rides as a sub-item inside the stage that owns it.
Nothing is renumbered, reordered or merged.

Last is **Debts this batch already knows it will leave** — the twelve open measurements from
`evidence/design-of-record.md` §16, three the plan-authoring pass added, **two the adapter
pivot of 2026-09-10 creates and does not pay**, and **one more the same day, when ⚖ R1 was
answered and always-salvage became a requirement** — eighteen, each with the exact experiment
that settles it. They are written down now, at the moment they are incurred, because a debt
discovered at Stage 11 and not written down at Stage 0 is a debt nobody pays. **Four of the
twelve are already closed** and are struck rather than deleted, because a closed debt that
vanishes gets re-opened by the next reader.

---

## Baseline, recorded before any crew started — 2026-09-09

**Re-verified 2026-09-10, by the pass that folded in the adapter pivot. Every figure below
still holds; nothing is edited.** Measured again in this tree today: xschem-claude HEAD is
still `2f1fad58` on branch `fluid-editing`; `src/ase.tcl` is still 11 745 lines / 620 846
bytes / md5 `39531e402a3d2d2720ef834bc35b0009`, and `src/ase_window.tcl` still 8 135 lines /
401 544 bytes / md5 `1e8c6b5085ddc302f1d290a29c1258b7`; `.state` files are still **105 on
disk, 104 tracked by git**, the 105th being the same untracked `debug_st1` bench. The check
is recorded even though the result was "no change", because a baseline nobody re-checked and
a baseline that was re-checked and held are not the same evidence — and a baseline that moved
in silence is worse than one that is openly stale. **Re-check rather than trusting this line**;
that is what the date is for.

### The two trees

| | |
|---|---|
| xschem-claude | `/home/analog/dev/xschem-claude`, branch `fluid-editing` |
| HEAD | `2f1fad58c5cfce651325a4a47802524379fc0f2b` (`2f1fad58`), 2026-09-09 21:59:31 −0700, *fix(1398): ASE-L came back three points smaller than it went in* |
| working tree | **dirty**, and it will stay dirty: untracked `.xschem/`, `doc/claude/ase_analyses_batch/`, `doc/claude/rdw_lists_batch/`, `doc/claude/rdw_sim_batch/`, and `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/`. **No tracked file is modified.** |
| ngspice | `/home/analog/dev/ngspice`, branch `ver_50` |
| ngspice HEAD | `ccebdf2a2ccc3ba237b7e100ee967433b6f86d33`, 2026-08-15 20:44:34 −0700; `git describe` = **`ngspice-46-419-gccebdf2a2`** |
| the binary every measurement used | `/home/analog/dev/ngspice/build-ver_50/src/ngspice`, 8 206 760 bytes, mtime 2026-09-02 23:47, md5 `eaa99c2238f35e29c70b40ac4c2a2fa1` |
| the same path, since 2026-09-10 | reconfigured with the original arguments plus `--enable-pss --enable-cider` and reinstalled into `stage/`: 8 848 296 bytes, mtime 2026-09-10 20:45, md5 `c435f1431e68b471fdf8dfdffe8260ad`; `WITH_PSS` and `CIDER` defined; still reports `ngspice-46+`. **Every measurement in `evidence/` predates this binary.** See `receipts/04-dev-build-rebuilt.md` |

⚠ **AMENDED 2026-09-10 — there are THREE binaries in the test matrix, not one, and the row above is
the one users are LEAST likely to have.** The variant-support amendment added:

| | |
|---|---|
| **apt 45.2 — what a downloading user has** | `/usr/bin/ngspice`, Ubuntu 26.04.1 LTS package `45.2+ds-1` from `resolute/universe`. Reports `ngspice-45.2`. **Has `pss` and CIDER**, which neither 46+ build has |
| **stock upstream 47 — what a from-source user has** | `/home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/builds/upstream47/src/ngspice`, 8 194 472 bytes, built 2026-09-10 from `origin/pre-master-47` @ `c5cd68015` in a scratch worktree with a bare `../configure` — autogen 26 s, configure 14 s, `make -j8` 59 s, **99 s total**, rc 0, 269 warnings. Reports **`ngspice-46+`**, i.e. **the same string as the fork** |
| the worktree it was built in | **removed.** `git worktree list` in the ngspice tree shows only the main tree, and `ver_50` is clean |

**And the rule that follows: a crew tests against apt 45.2 as well as against the fork**
(`CREW_BRIEF.md`'s testing discipline). The fork is where the work is developed; apt 45.2 is where
it is run.

Nothing in either repository was modified by this pass. This batch is **analysis only**: the
only writes are inside `doc/claude/ase_analyses_batch/`. No file under `src/` is touched.

### ASE-L, the two files the work lands in

```
11745 lines   620846 bytes   39531e402a3d2d2720ef834bc35b0009   src/ase.tcl
 8135 lines   401544 bytes   1e8c6b5085ddc302f1d290a29c1258b7   src/ase_window.tcl
19880 lines total
```

⚠ **CORRECTION to the brief's figures.** The task description said "~11.7k lines" and
"~7.7k lines". `ase.tcl` matches; **`ase_window.tcl` is 8135, not ~7700** — it grew during
the 1398 font work that landed at HEAD. Counted today with `wc -l`.

### The committed `.state` files — 104, not 105

```
105   *.state files on disk           (find . -name '*.state')
104   *.state files tracked by git    (git ls-files '*.state')
  1   untracked:
      sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/tb_bandgap.state
```

⚠ **CORRECTION, and it matters because the number is an acceptance criterion.**
`evidence/design-of-record.md` says "105 committed" in five places, and
`evidence/ase-conventions.md` §11 already flagged that "104 committed is stale everywhere —
it is **105** on disk today". Both halves are true and they are about different sets:
**105 on disk, 104 in git.** The 105th is the untracked `debug_st1` state that appears in
this session's `git status`, i.e. a scratch bench, not a golden. The suites that assert
byte-identical round-trips (rows F3 / G3 / R4 / V4 / R2) walk what is **committed**, so
**the acceptance number is 104** and a crew that reports "105 round-tripped" has walked a
file that is not in the repository. Re-count at the moment of asserting; the number moves
whenever somebody saves a bench.

### Headless suites — the ASE-L family, as it stands today

29 `test_ase_*.tcl` suites (384 `test_*.tcl` suites in total under `tests/headless/`).

`lines` is `wc -l`. `calls` is the count of assertion **call sites** —
`grep -cE '^\s*(check|check_true|check_contains|eqcheck|check_num|check_re)\s'` — measured
today, in this tree. ⚠ **`calls` is not a run count and must not be quoted as a floor.**
Loop-generated rows make the run count higher (`test_ase_window` reports 295 on `:99`
against 289 call sites); announced skips make it lower on one arm. A crew records the real
before/after numbers **from its own run**, per arm, and the floor only ever goes up.

| suite | lines | calls | floor declared in the suite's own header, or last recorded |
|---|---|---|---|
| `test_ase_bus_bits_0159.tcl` | 299 | 40 | header: `ALL PASS (39)` under a HOME with no registry |
| `test_ase_core.tcl` | 3609 | 233 | header: **230 in both arms**, and "the count is a FLOOR and it only ever goes up" (173/172 → 184 → 197 → 203 → 216 → 224 → 230) |
| `test_ase_cosim.tcl` | 2277 | 341 | none declared |
| `test_ase_current_repair.tcl` | 701 | 56 | none declared |
| `test_ase_dialogs.tcl` | 1679 | 215 | `ase_l_ux_batch/LEDGER.md`: `ALL PASS (215)`, floor 176 → 215 on `:99`, 37 `--nogui` |
| `test_ase_dirty.tcl` | 381 | 41 | none declared |
| `test_ase_final.tcl` | 1455 | 85 | header notes an `ALL PASS (80)` era; ux ledger: `ALL PASS (82)` |
| `test_ase_final_gf180.tcl` | 231 | 35 | none declared |
| `test_ase_hier_pick_0161.tcl` | 201 | 22 | header: `ALL PASS (21)` under a HOME with no registry |
| `test_ase_hier_plot_0168.tcl` | 232 | 31 | none declared |
| `test_ase_interact.tcl` | 501 | 64 | header: `ALL PASS (63)`; ux ledger: 64 |
| `test_ase_launch.tcl` | 431 | 44 | ux ledger: `ALL PASS (44)` |
| `test_ase_locked_wire_pick_0160.tcl` | 232 | 17 | header: `ALL PASS (16)` under a HOME with no registry |
| `test_ase_log_seam_0207.tcl` | 1040 | 50 | header: `ALL PASS (48)` under a clean HOME |
| `test_ase_optier_0963.tcl` | 3166 | 104 | header: `ALL PASS (102)`, with X7 named as a known flake |
| `test_ase_persist.tcl` | 1014 | 149 | header: **FLOOR, raised and never lowered: 44 headless / 147 with a display** |
| `test_ase_plot.tcl` | 912 | 153 | header: `ALL PASS (150)`; ux ledger: 151 |
| `test_ase_preflight.tcl` | 966 | 116 | none declared |
| `test_ase_print_bracket_0167.tcl` | 125 | 13 | none declared |
| `test_ase_result_case.tcl` | 484 | 29 | none declared |
| `test_ase_savestate_adopt.tcl` | 245 | 27 | ux ledger: floor 26 → 27 |
| `test_ase_simcaps_0948.tcl` | 3078 | 110 | ux ledger: `ALL PASS (110)` |
| `test_ase_simchoice_1395.tcl` | 593 | 31 | header: **FLOOR: 31 checks, on either arm** |
| `test_ase_simdlg_0937.tcl` | 2100 | 55 | header: **FLOOR: 55 on the display arm, 5 on the structural one** |
| `test_ase_simreg_0931.tcl` | 3014 | 111 | header: **⚠ FLOOR, only ever goes up: 111 as of 2026-09-08** |
| `test_ase_sod_case.tcl` | 497 | 53 | header: `ALL PASS (52)` under a HOME with no registry |
| `test_ase_unnamed_net.tcl` | 267 | 29 | header: `ALL PASS (28)` under a clean HOME |
| `test_ase_view.tcl` | 232 | 36 | none declared |
| `test_ase_window.tcl` | 3909 | 289 | ux ledger: `ALL PASS (295)` on `:99`, floor 267 → 295; 56 `--nogui` |

**Not measured here, deliberately:** no suite was run and `run_regression.tcl` (T1) was not
run for this baseline. This pass writes documents; running the GUI suites means a display,
a scratch `HOME` and an `XSCHEM_DEVDISPLAY_DIR`, and the first crew has to do it anyway to
get a *before* number it can defend. **Stage 0's crew records T1 before it changes a line**,
and that number — not this table — is the batch's zero.

**The standing rule that produced the ux batch's incident, restated because it binds every
crew here:** a simulation run **is** a write to `~/.xschem/simulations`, because
`ase::rundir` with an empty `rundir` key returns `set_netlist_dir 0` — one global directory
for every state of every cell. **No crew runs a simulation on a bench under `sky130A/`.**
Probes that need a run use a scratch library and an explicit `rundir`. (This is also
decision **D19**'s refusal, and correction C19.)

### Debts already open, before this batch adds any

`tests/headless/owed.sh list`, today:

```
131  RULE debts   — need the USER'S ruling; cleared only by `owed.sh clear rule <id>`
 51  LOOK debts   — need the USER'S eyes;   cleared only by `owed.sh clear look <id>`
  8  SUITE debts  — a :0 run each;          cleared automatically when one passes
```

Five of the eight suite debts are in this batch's blast radius and should be paid by
whichever crew next touches the file, not queued again:
`test_ase_core`, `test_ase_dialogs`, `test_ase_simdlg_0937`, `test_ase_window`, and
(neighbouring, RDW) `test_rdw_window_1245` / `test_rdw_keys_1245`.

One rule debt is *directly* in scope and is the reason ⚖ **R3** exists as a ruling rather
than a decision: **`[1243]` — "a transient-only run's Outputs Value column is still blank —
what should a scalar column show for a waveform: the final point, t=0, or nothing?"**
R3 extends that ruling; it must not reverse it.

### Issue numbering

`doc/claude/issues/NUMBERING.md` tail, read today: **"The next free number is 1400."** The
file is committed and clean in this tree. ⚠ Re-read it **at the moment of minting** — the
convention dossier's own caution #3 is that this tail is often uncommitted in a working
session, and two batches minting 1400 simultaneously is a merge nobody wants.

### The evidence base this batch implements from

**29 files** in `doc/claude/ase_analyses_batch/evidence/`, **35 490 lines** total. It was 25
files / 32 581 lines when this baseline was taken on 2026-09-09; the 26th arrived on
2026-09-10 with the answer to ⚖ R1, and was itself amended later that day; **files 27–29 arrived
later the same day again with the variant-support amendment** — the pass that answered *"most
users who download our Xschem won't have our ngspice"*:

```
variants.md            784 lines  — stock upstream 47 built and characterised beside apt 45.2
                                    and the fork; the measured proof that stock 47 and the fork
                                    are INDISTINGUISHABLE by version, command table and help text
fork-dependencies.md   612 lines  — the 105 functional fork commits classified (60 casemode,
                                    5 new diagnostics, 35 live-upstream bugs, 5 internal); five
                                    hard crashes reproduced live on apt 45.2; the headline that
                                    an ordinary ASE-L deck runs byte-identically on apt 45.2
fork-features.md       600 lines  — what the fork really adds: NOT a blanket OP save (the tier-d
                                    dump is an UPSTREAM fix, in no release); the per-binary
                                    capability dicts from ASE-L's own probe decks A/B/C
```

⚠ **Those three change the test matrix, and `CREW_BRIEF.md` carries the rule.** There are
**three** binaries now — apt 45.2 (`/usr/bin/ngspice`, what a downloading user has), stock
upstream 47 (rebuildable in **99 seconds**), and the fork — and a crew tests against the stock one
as well as the fork.

The 26th, with its own line:

```
201a7a8836fe73a9e919300401758aa0  salvage.md             913 lines  — what a stopped batch run can keep
```

⚠ **That is the amended figure.** As first written `salvage.md` was `cd3b1c126b52697bf83ef09026411f6c`
/ 840 lines; the amendment pass of the same day corrected its §3.8 recipe (the `ckdone` counter was
created after the `tran`, so it was written into every file the loop produced — `PLAN.md` **C35**)
and re-measured three of its numbers. The scorecard in its §1 records the correction against itself.

`salvage.md` is the measured basis for the always-salvage requirement, and it is also the
correction record for the quick pass that preceded it — five load-bearing statements of that
pass are refuted in its §1 scorecard. A crew implementing a checkpoint loop reads it before
it reads anything else on the subject, including the paragraphs in this ledger, which
summarise it.

`README.md`'s file table and its per-file list both read 26 and both carry a `salvage.md` row,
as of the 2026-09-10 amendment. This line is still the one to trust when they disagree, because
it is measured with `ls` and `wc -l` rather than remembered.

The three a crew must not re-derive:

```
41abed9563b27f9fc393556cd1c69740  design-of-record.md   2323 lines  — THE SPINE
276ba94b019f3cb48454549227b961e3  00-critique.md                    — the inter-dossier contradictions
61dd5ecc74f38c1add0133eaece61935  builds.md                         — PSS, CIDER, libngspice: actually built and run
```

If any of those md5s has moved when a crew starts, the crew is reading a different document
than this ledger's baseline describes, and should say so in its receipt.

---

## Rulings answered

⚖ **R1**–⚖ **R10** are `DECISIONS.md`'s, and they are the user's to answer. A ruling that
resolves in a conversation and nowhere else is a ruling the next crew re-asks, so an answer
lands **here**: the date, the option, and what the answer changed. A ruling not named in this
section is still open, and `DECISIONS.md` carries it with its options, its trade-off and its
recommendation. **This section does not restate the ruling** — it records the answer and the
corrections the answer was given on.

### ⚖ R1 — the transport — **ANSWERED 2026-09-10, Option A**

**Keep `ngspice -b` in this batch. `-p` stays deferred.** In the user's words, *"in terms of
milestones on the plan, it can wait. We proceed along path of least resistance."* So
`ase::backend::ngspice::run_cmd` does not move; the six `test_ase_simreg_0931` rows that pin
its word order — **A2 / B5 / B6 / B11 / B12 / D4**, with **L11** on the exe alone — stay as
they are except where Stage 7's `-D` re-baselines them; and Stages 0–14 are built on `-b`.
What was ratified is `DECISIONS.md` ⚖ R1's own recommendation: **one internal run interface
now (D20), `-b` as its first implementation, `-p` scheduled as the second immediately after
Stage 10.**

**The answer arrived with a requirement the ruling did not offer as an option.** The user
asked two questions before ruling — *"In batch mode, is there no way to write what was
simulated 'thus far' to disk before exiting?"* and *"What is the benefit of losing partial
results on Stop? Why would one ever want to do that?"* — and then ruled: *"We should put that
in right away — always salvage, and alert user that her sittings will cause loss of
simulation effort 'thus far'."* **Always-salvage is a plan-level requirement from this date**,
and so is the warning wherever a Stop would still discard work. **The warning is Stage 2e and the
salvage is Stage 6f** — both stage sections below say what lands in them — and the gap between the
two is debt **M18**. The receipt for the ruling and the amendment is
`receipts/02-r1-answered-salvage.md`.

⚠ **The amendment was verified after it was written, and the verification found the published
recipe defective.** `let ckdone = 0` sat *after* the `tran`, so the counter landed in `tran1` and
was written into every checkpoint and into the results file — which also falsified the
byte-identity claim attached to that deck. Repaired in all three copies and re-measured; the
correction is `PLAN.md` **C35**, and `evidence/salvage.md` §1's scorecard now grades the dossier
against itself as well as against the pass before it. Two more numbers moved in the same pass —
abort latency and the checkpoint cost table — neither changing a conclusion. **A published byte
count is checkable against `points × vectors × 8`; this one was not checked for a day.**

**Two things R1's write-up said that measurement refutes.** They stay visible rather than
being edited away, because the ruling was nearly decided on the uncorrected version and a
future reader will find the old sentences in `DECISIONS.md`:

* **`-b` does not leave *"stop and keep what you have"* permanently open.** R1's trade-off
  line says it does. Salvage is reachable in batch, on the stock binary, keeping the
  `.control` deck shape every stage of this plan depends on — `evidence/salvage.md` §3. The
  recommendation survives; its cost line does not.
* **`-p`'s abort advantage is not latency.** Batch dies in **a few milliseconds at worst** on
  SIGTERM and on SIGKILL alike (`salvage.md` §4.2; the figure tracks the run's resident memory
  rather than the signal, which is `PLAN.md` **C35**) — at or below the "under 5 ms" figure
  `evidence/builds.md` credits to `-p`, and the same order R1's Option B quotes. What `-p`
  buys is a **non-destructive** abort: no checkpoint granularity, no torn-file window, no
  `shell mv`, and the run's data still in the process afterwards. Say it that way wherever
  R1 is cited; the latency framing invites a reader to conclude the two transports are close
  on an axis where they genuinely are.

**`-p`'s other two advantages are untouched by any of this**, and they are why it is
scheduled rather than dropped: the **no-circuit capability probe** the adapter doctrine leans
on (Stage 2b's second Detect leg, and the cheaper half of debt **M15**), and the pre-deck
door collapsing to one `set` before `source`, which would moot ⚖ **R2** and delete **D19**.
Neither is about losing work.

**And one question of the user's that had no answer anywhere in the batch, now measured.**
*Why would one ever want to lose partial results on Stop?* One would not. `src/main.c`
installs its signal handlers inside `if (!ft_batchmode)`, so batch mode installs **none** and
every signal is fatal with nothing written — SIGINT 130, SIGTERM 143, SIGHUP 129, SIGQUIT
131, and SIGTERM/SIGHUP/SIGQUIT are installed in no mode at all (`salvage.md` §4.1). Batch
was written for scripted use where nobody presses Stop. **No benefit is being traded away**,
and that is recorded here so the next reader does not go hunting for the rationale.

### ⚖ R2 — `<rundir>/.spiceinit` — **ANSWERED 2026-09-10, yes, with four conditions**

**ASE-L may write `<rundir>/.spiceinit` and copy the user's own file into it.** The user's words
were *"yes, with those four conditions"*, so `DECISIONS.md` ⚖ R2's recommendation is ratified as
written and its four conditions are **requirements**: deleted and rewritten per run; the user's
lines **copied** under a banner, never `source`d (**[R-M7]**, **D19**); the run log says once that
the file exists and what it shadows; and **refused** under the shared `set_netlist_dir 0` rundir
fallback (**C19**) and under `-n` (**D18**), each refusal naming what it refuses over.

**What it changed in the plan: nothing.** No option was modified, no cost line was refuted, and
**D17 / D18 / D19 stand as written** — which is worth recording precisely because it is unusual:
⚖ R1's answer arrived with a requirement neither option contained, and a reader who has just
finished that section may expect the same here. What it changed is standing — advice became
requirement — and what it unblocks is **Stage 7**'s pre-deck option class (the 26 `cp_getvar`
variables `.options` cannot reach) and **Stage 11**'s design-variable axis.

⚠ **Measured the day it was answered**, in this tree: there is **no `$HOME/.spiceinit`** on this
machine and `SPICE_USERINIT_DIR` is unset, so condition 2 shadows nothing today. It is not
therefore optional — it is the condition that becomes load-bearing the first time the user writes
one, and the `source`-loses-your-variables measurement is what it exists to prevent.

### Still open — nine

⚖ **R3** through ⚖ **R11** are unanswered as of 2026-09-10. ⚖ **R11 — the minimum supported
ngspice — is new that day**, from the variant-support amendment, and is filed **last of all**,
behind R10: it gates **one sentence** (Stage 16e's support promise), not a stage, and the
*description* half of that release note ships without any ruling at all. `DECISIONS.md`'s ruling ledger is
the place they live and the order it sets is the order to ask them in — **one at a time, each
a short conversation**, which is the standing preference R1 was asked under. ⚖ **R9** is the
declared exception: it is batched per stage.

---

## How to fill in a stage section

Copy the block, do not restructure it. `status` is the vocabulary the tree already uses:
`x` landed clean / `E` landed with an open question that is the user's / `F` refuted and
reverted. A re-done stage **keeps its number and gains a suffix** (`6a`, `6a-2`) — history
is never renumbered.

| field | what goes in it |
|---|---|
| status | `x` / `E` / `F`, plus the date |
| commit | the sha and the subject line |
| T1 | `run_regression.tcl` **solo**, counted failures / launch failures / `exit -1` / NODISPLAY arms, under a scratch `HOME` with `XSCHEM_DEVDISPLAY_DIR` exported |
| suites moved | by name, per arm, floors **before → after**, floors RAISED never lowered |
| sabotage | each new proc no-opped, the named rows confirmed red, restored by `cp` from a pristine copy and md5-compared — never `git checkout/restore/stash/clean` |
| ledger debts | `owed.sh add rule/look/suite` ids filed **at the moment they were incurred** |
| spec paragraphs rewritten | which paragraphs of `doc/claude/specs/ase_l.md` this stage invalidated and rewrote **in the same commit**, by heading. `PLAN.md`'s Acceptance names the five this batch owes and which stage owns each. A stage that names none is asserting it invalidated none |
| receipt | `receipts/NN-stage-<slug>.md` |
| what this stage learned that binds later stages | the section the exemplars keep; the place a correction to this plan lives |

---

## Stage 0 — The silent drop dies

*The emit loop iterates the enabled rows instead of the `anorder` literal; a row whose type
is not in the registry raises a named error; the same check joins `ase::preflight_gate`;
`ase::plot_sim_type` returns `{}` honestly; and the **two** stale top-only sentences in
`doc/claude/specs/ase_l.md` (hints `:946-947`, `:997`), which nothing else in the plan
touches.* **Rulings: none that block. RED first** — a new row must assert that a
`{type noise enabled 1}` state today renders a deck with **no analysis, rc 0, and says
nothing**. ⚠ One user-facing sentence **is** minted here — the refusal naming the
unrenderable type — so file `owed.sh add rule <issue>` the moment it lands and pay it with
Stage 3's ⚖ R9 batch. No existing suite moves. Decisions: **D29**.

| | |
|---|---|
| status | **x — landed clean, 2026-09-10** |
| commit | `feat(1401): an analysis type ASE-L cannot render is dropped in silence` |
| T1 | `run_regression.tcl` **solo**, scratch `HOME` + `XSCHEM_DEVDISPLAY_DIR`, `:99`: **0 counted failures**, 0 launch failures, 0 `exit -1`, 3 NOGOLD notes (`create_save`, `open_close`, `netlisting` — no committed baseline, not counted, CLAUDE.md). ⚠ **The first two attempts at this number were both HARNESS artifacts and neither was a tree defect** — see *What Stage 0 learned* below |
| suites moved | `test_ase_core` **230 → 248**, `test_ase_preflight` **115 → 125**, identical on `--nogui` and on `:99`. Floors RAISED in both files in this commit; `test_ase_preflight` had **no declared floor** before and now has one. **No other suite moved a row**: the ASE family was re-run entire on both arms. ⚠ The last eight rows are an adversarial review's — see the receipt |
| sabotage | Four passes. `ase::analysis_emit_rank`'s `return {}` → `return 0` reddened **exactly nine rows** (D7a, D7b, D7c, D7e, PF222a–e); deleting the backend-scope guard reddened **D7e5 + PF222j**; dropping the `lsearch` dedup reddened **D7e2**; dropping the rundir clause reddened **PF222h**. Every other row in both suites stayed green in all four. Restored by `cp` from a pristine copy each time, md5 compared equal. No `git checkout/restore/stash/clean` |
| ledger debts | `owed.sh add rule 1401` — the minted refusal sentence, filed the moment it landed, stamped `repo:/home/analog/dev/xschem-claude` and `ref:` resolving to the issue file. Paid with Stage 3's ⚖ R9 batch. **No look debt**: this stage is headless by construction and changes no pixel |
| spec paragraphs rewritten | `doc/claude/specs/ase_l.md`, **three**: the `## Deck assembly (no C changes)` `analyses` bullet (the emit loop walks rows, and an unrankable type is a named refusal); and **both** stale top-only sentences (hints `:946-947` and `:997`), each replaced by a ⚠ block quoting what it used to say and naming issue 0643 as what made it false — the file's own *Netlist and Run works from any level of the design* section had contradicted them for two days |
| receipt | `receipts/05-stage-0-silent-drop.md` |

### What Stage 0 learned that binds later stages

**1. The plan's description of the defect was wrong, in the direction that made it look
milder — correction C36.** `PLAN.md` Stage 0 said today's deck for an unknown type was
*".control / set appendwrite / remzerovec / write / .endc"*, i.e. that a rawfile was
written and merely empty. **Measured: there is no `remzerovec` and no `write` at all**,
because issue 0929 moved both inside the per-analysis loop, so the run produces **no raw
file whatsoever**. Downstream that is worse, not better: `ase::attach_dbs` reports
`NOT ATTACHED … the analysis did not run` about a run that never contained the analysis,
which reads as *"the simulator failed"*. The lesson for Stages 1–16: **the batch's prose
about today's behaviour is a claim, not a measurement, even where it is specific.** Render
the deck and look.

**2. `ase::n_enabled_analyses` was never the gate, and that is why the drop was silent.**
It answers *"how many did the user tick"* — the right question for `set appendwrite` and
the wrong one for *"can this be rendered"*, which had **no reader anywhere**. Row D7d pins
that it still counts an unrenderable row. A later stage that adds a type must ask the
second question explicitly; there is no counter that answers it by accident.

**3. The refusal is minted ONCE, in `ase::analysis_unrenderable_msg`**, and both refusal
sites say it with that proc. Every later stage mints sentences by the dozen (⚖ R9); two
spellings of one refusal is the same drift this batch exists to delete, one layer up.

**4. The `ase_preflight` escape is not a general escape.** `set ase_preflight 0` is a real
lever for the save-name check — a user who knows their netlist better than the scanner does
must not be locked out — and there is nothing for it to be right about when the deck would
emit no analysis at all. **Stage 4 inherits this exactly**: its DISTO rule is also
non-defeasible, for the same shape of reason (there it would re-open a SIGSEGV). Row
PF222e is the guard; if it ever goes green with a `0`, a clause drifted below the early
return.

**5. Two T1 baselines were lost to HARNESS artifacts before one was clean, and both are
worth knowing.** (a) The first run reported **1 FATAL** in `create_save/simple_inv`:
`Tcl_AppInit(): failure creating …/t1home/.xschem`. Sixteen parallel workers raced to
create `$HOME/.xschem` in a scratch `HOME` that did not yet exist, and the loser is scored
as a case failure. **Pre-create `$HOME/.xschem` in any scratch `HOME` before a parallel
run** — issue 1397's pattern says to use a scratch `HOME`, and this is the corner it does
not mention. (b) The second run reported **3 failures in `test_ase_simcaps_0948`** because
`src/ase.tcl` was edited *while it was running*. **Do not edit product code while a suite
is in flight**; the suite sources it and reports a defect that exists for nobody. Neither
number was a tree defect and neither was carried forward.

---

## Stage 1 — The registry, byte-identically

*`ase::analysis_types` with exactly today's four types; `emit` templates reproducing today's
four lines; the radio literal, `ase::ui::anaargs`, `ase::ui::chana_fields`, `anorder`+switch,
`ase::plot_sim_type` and `ase::ui::chana_show`'s five-name destroy list all become readers;
the `.form` child frame.* **Rulings: none.** Acceptance is **byte-identity** (D32), and the
list is identical to `PLAN.md` Stage 1's: deck golden **D1**, plus **D2 / R1 / R4** of
`test_ase_core`, **V4** of `test_ase_view`, **R2** of `test_ase_persist`, **F3** of
`test_ase_final`, **G3** of `test_ase_final_gf180`, **W1p** of `test_ase_window`, the **104
committed** `.state` round-trips, and the print anchor. ⚠ **Six** widget-path lines of
`test_ase_dialogs.tcl` move with `.form` — `:625 :626 :629 :655 :656 :657`, all G2/G2b, with
`:629` a `send_return` on `$top.chana.step`. **Correction C18 said five; `PLAN.md` §0.2
re-measured.** ⚠ An earlier draft of this block also named "row E12"; `E12` exists in two
suites and neither is a byte-identity row (DECISIONS D32). **If byte-identity cannot be met,
the descriptor's shape is wrong and the plan stops here.**
Decisions: **D1, D2, D31, D32**.

⚠ **Sub-item, added 2026-09-10 with the adapter pivot, and it happens BEFORE byte-identity is
claimed.** Write **Xyce's adapter descriptor on paper** — a paper exercise against the same
schema the ngspice adapter is written through, not an implementation and not a file under
`src/`. Xyce has a native `.STEP`, no interactive control language, and a different output
format, so it presses on the assumptions ngspice lets the schema get away with. **The
deliverable is "what broke"**: every schema field that could not express Xyce, or that
expressed it only by naming something ngspice-shaped. Fix the schema against that list, then
claim byte-identity. A schema with exactly one implementation is not yet a schema. The extra
row below records the outcome and is a **Stage-1-only field**; no other stage's block gains it.

⚠ **Second sub-item, added 2026-09-10 with the VARIANT-SUPPORT amendment, and it has a hard
deadline: it lands in Stage 1 or it cannot land at all.** The contract block (`PLAN.md` 1a) and the
field descriptor (1b) gain three optional keys — **`requires`** (valid at analysis, option-row and
field level, with identical three-valued semantics, evaluated by one new `ase::requires_state`),
**`notes`** and **`lint`**. The scheduling argument is the load-bearing one: Stage 1 is where the
schema freezes *and* where the Xyce paper-validation grades it, so a `requires` key added in Stage 7
would be graded by nobody and the paper exercise would have validated a schema **that cannot express
a variant** — which is the one thing the amendment exists to make expressible. ⚠ **It moves no
byte**: acceptance is byte-identity of deck golden D1 under `string equal`, and adding a descriptor
*key* does not move it. ⚠ **It is NOT a new sub-item "1e"** — 1e is the Xyce exercise, which is its
grader; the keys ride 1a and 1b, and **1e is re-run against the schema including them**, answering
one extra question: *can this schema say that an analysis exists on one build of ONE simulator and
not on another?* Decisions **D42**, **D46**, **D48**.

| | |
|---|---|
| status | **x — landed clean, 2026-09-11** |
| commit | `feat(ase-l): the analysis registry, byte-identically — analyses batch Stage 1`, on top of `test(ase-core): D8 pins the emitted analysis line per type, because D1 could not`. ⚠ **Two commits, and the order is the evidence** — see *sabotage* |
| T1 | `run_regression.tcl` **solo**, scratch `HOME` + `XSCHEM_DEVDISPLAY_DIR`, 2026-09-11: **0 counted failures**, 58 cases, 0 launch failures, 0 `exit -1`, **0 `TIMED OUT`**, and `src/ase.tcl` + `src/ase_window.tcl` md5-verified unchanged across the run, so the numbers describe one tree |
| byte-identity | **MET.** ⚠ **D1 alone does not establish it and was not relied on**: D1's fixture is OP-ONLY, so its golden deck carries the single line `op` and the `dc`/`ac`/`tran` emit arms are never exercised — a registry refactor could move their bytes with D1 still green. A **17-case deck corpus** was captured from the pre-Stage-1 code and re-rendered after: every type alone, all four together, both row orderings, `op`-then-`dc`, duplicate rows of one type, an unknown extra key, and nothing-enabled. **md5 `958abd0ba421f65cc9db21db6b99ea03` before and after, identical.** Separately **105 `.state` files round-trip with 0 mismatches, A/B-confirmed identical against the pre-Stage-1 tree** — which matters because `ase::state_default`'s seed is now a registry reader |
| suites moved | `test_ase_dialogs` **G2** and `test_ase_window` **P4**: `source=V2 start=0 stop=1.8 step=0.01` → **`dc V2 0 1.8 0.01`**. Both are DISPLAY strings, not deck output. Six widget-path lines of `test_ase_dialogs.tcl` gained `.form` (`:625 :626 :629 :655 :656 :657`, all G2/G2b, `:629` a `send_return`) — exactly the six §0.2 re-measured, not C18's five. **No floor moved and no other row moved**: `test_ase_core` 248, `test_ase_preflight` 125, `test_ase_persist` 44, `test_ase_final` 82, `test_ase_final_gf180` 35, `test_ase_view` 32, `test_ase_optier_0963` 103, `test_ase_simcaps_0948` 110, `test_ase_simreg_0931` 111, `test_rdw_seam_1245` 49, `test_ase_cosim` 341, `test_ase_result_case` 28, `test_ase_sod_case` 53. Display arm: `test_ase_dialogs` **215**, `test_ase_window` **295** — ⚠ **and the display arm is not optional here**, see *What Stage 1 learned* |
| sabotage | Four passes against the registry, each restored by `cp` from a pristine copy with md5 compared equal (no `git checkout/restore/stash/clean`). ⚠ **Section D8 was committed SEPARATELY AND FIRST**, so that the rows guarding this refactor are provably pinning BEHAVIOUR and not this implementation: they pass against the hand-written `switch`, and sabotaging *that* switch reddens D8a/D8f/D8g/D8h and D8b/D8e/D8f/D8g — four rows each, where the same two edits previously reddened nothing. Only **D8i** (the Arguments column IS the emitted line) belongs to this commit, because the behaviour it asserts does not exist before it. ⚠ **The first two passes are the whole reason section D8 exists**: `dc`'s emit template swapping `@start`/`@stop`, and `ac`'s hardwired `dec` → `oct`, each left `test_ase_core` at **ALL PASS (248)** — the plan's own acceptance would have accepted a refactor that reversed every DC sweep in the product. With D8 committed they redden **D8a/D8f/D8g/D8h/D8i** and **D8b/D8e/D8f/D8g**. `op`'s `emitorder` 0 → 100 reddens four rows (D1 catches it because `op` moves). `tran`'s `viewrank` demoted leaves `test_ase_core` untouched — correct, it is not a deck fact — and reddens **R6** of `test_ase_optier_0963`, the row that pins `ase::plot_sim_type`'s preference ranking |
| ledger debts | **No look debt** — the one visible change is a display string two rows assert by value, and the plan says so. **No rule debt**: no user-facing sentence is minted. ⚠ `label` deliberately carries TODAY'S RADIO TEXT (`op`/`dc`/`ac`/`tran`) rather than a human noun — a refactor may not mint user-facing copy, so promoting them to `Operating point` / `DC sweep` is a ratified change under ⚖ **R9** in a later stage, not a side effect of this one |
| spec paragraphs rewritten | `doc/claude/specs/ase_l.md`, the **Analyses** pane bullet: the Arguments column stops being a view-only key dump and becomes the line the deck will carry |
| Xyce paper-validation — what broke | **Not "nothing broke."** Five families of Xyce analysis (`.OP/.DC/.TRAN`, `.STEP`, output/results, build variants, the run lifecycle) were written against the §1a key set and every "that expressed cleanly" claim was handed to a separate agent told to refute it: **157 breakages, 77 of them found ONLY by the adversary**, consolidating to **23 changes that must land before the key set freezes** and 15 recorded deferrals. All three predicted breakages reproduced and each was **larger** than predicted. THREE landed in this stage's code: **`verb` DELETED** — specified as *"the `.control` command word AND what `help <verb>` probes with"*, two ngspice words in the half §1a says may contain none, and it was never the source of the emitted token, so deleting it moves no byte; **`gated` → `baseline`**, renamed and re-specified after the exercise found it load-bearing IN THE WRONG DIRECTION (it is the only steer on `ase::requires_state`'s `unknown` arm, so an adapter that cannot assert an ngspice-style source-verified invariant writes `0`, every unmeasured capability resolves `{ok baseline}`, and analyses nobody verified get offered — the inverse of Stage 2's stated worst outcome); and **`emit` became an ORDERED LIST of role-tagged cards** with ngspice declaring exactly one, because a runnable Xyce `.TRAN` is TWO cards and **this repo already ships one** — `xschem_library/ngspice/solar_panel_xyce.sch:155-156` carries `.tran 5n 1000u uic` plus `.print tran format=raw file=…`, and `sky130A/xschem_libs/sky130_tests/test_ac/schematic/test_ac.sch:285` carries `.print ac format=raw`. ⚠ **THE META-FINDING IS THE ONE TO CARRY: §1a's naming rule is LEXICAL, so it caught every ngspice NOUN and missed every ngspice SEMANTIC.** `emit`'s `@name!` exists *"because ngspice's argument lists are POSITIONAL"*; `bool`'s *"never `=1`"* is a MEASURED NGSPICE DEFECT (trap T4) promoted into the type system; `plots.match` is a glob on a `Plotname:` record only an ngspice rawfile has. All three pass a grep for simulator words, so **D36's prediction that reaching for a simulator fact surfaces as a finding is false exactly where it cost most**. ⚠ **And the tree itself proves the sharpest case**: §1b's number lexicon `f p n u m k meg g t` is **NARROWER THAN XSCHEM'S OWN C PARSER**, which carries `x` = 1e6 at `src/editprop.c:101` under the literal comment `/* Xyce extension */`, plus `mil` = 25.4e-6. The schema was about to make one simulator's alphabet normative while this repository's own parser already disagreed. **Three defects were found on paper with no Xyce involved at all**, each verified in-tree: `rules` **has no written grammar anywhere** (§1a's cross-reference points at §1d, which is the `.form` child frame); **D30's load-time check would reject the plan's OWN `tran`/`tf`/`pz`/`sens` entries**, which carry only a plot-level `results` token and no entry-level dict; and `requires`' **`raised` arm is unreachable by a conforming adapter** — it appears at `PLAN.md:1206` and in a planned test row at `:1047`, and **zero** times in D42–D52, the decisions that created it. The 20 remaining changes are recorded against ⚖ **R10**, whose input this is; the largest is that **there is no adapter-level descriptor at all** — analysis cardinality, composition, whether the simulator owns its own sweep, and the run-model fact Stage 2e's Stop sentence needs have nowhere to be written. Full output and the five descriptors: see the receipt |
| `requires`/`notes`/`lint` — did the paper exercise use them? | **`requires` is load-bearing at FIELD level only.** At analysis level Xyce has no per-analysis capability channel — `Xyce -capabilities` reports build ingredients and takes no analysis argument — so every predicate answers `unknown`, which means what the exercise actually exercised is **D6's ungated-baseline fallback, not the three-valued contract**. Its `raised` arm is unreachable (above). **`notes` held as a mechanism and broke as a frame set**: §16a's four frames are all DEFICIT-shaped (*"…can do everything ASE-L offers except…"*) and cannot express a **surplus** — a native `.STEP`, native sampling, `.OPTIONS RESTART` — that switches ASE-L's own machinery OFF. **`lint`'s hook shape, its note/warn/refuse ladder and its adapter-proposes/ASE-L-disposes split all held unchanged**; only its declared DOMAIN (*"user-supplied CONTROL text"*) names a construct a batch-only simulator does not have. ⚠ **None of the three is exercised by Stage 1's four types**, so none is pinned by a row here — they are declared in the contract and graded on paper, which is exactly the gap ⚖ R10 governs |

⚠ **`ase::requires_state` AND THE ENTRY-LEVEL `requires` KEY ARE NOT IN THE TREE — they are DESIGNED here, not SHIPPED here.** Measured 2026-09-11: `grep -c requires_state src/ase.tcl src/ase_window.tcl` is **0** in both. The sentences above describe what the key is *for*, and a reader has already taken them as a record of something landed. **Stage 2's C5 commit creates it**, with the signature `{req caps baseline}` — not the plan's `{req caps gated}` — because Stage 1 renamed the key and INVERTED its polarity, so an absent `baseline` must default to **0**. Corrected after the Stage 2 recon caught it; the same class of un-measured record cost 100 checks as issue 1405.
| receipt | `receipts/06-stage-1-the-registry.md` |

### What Stage 1 learned that binds later stages

**1. A stage's stated acceptance is a CLAIM about coverage, and it must be sabotaged before it
is trusted.** Stage 1's gate was deck golden **D1** under `string equal`. D1's fixture is
OP-ONLY, so two of the four emit arms are not exercised by it at all, and two sabotage passes
that changed real deck output left the whole suite green. **Every later stage that names a
golden as its acceptance owes the same check**: break the thing on purpose and confirm the
named row goes red. Correction **C43**; the repair is section **D8**, floor 248 → 258.

**2. A widget change cannot be accepted on a headless number.** `test_ase_dialogs` is **37
checks headless against 215 with a display**. Stage 1 moved the quick fields into a `.form`
child frame; the headless arm stayed green while the display arm died at **0 of 215**, on a
defect (`key "source" not known in dictionary`) that only exists because the pane renders rows
the deck never sees. Stages 3, 5, 7 and 11 all move widgets.

**3. The schema's naming rule catches nouns, not semantics — and that is now written down
rather than rediscovered.** Correction **C37**. A key can pass every grep for simulator words
and still be one simulator's behaviour in a schema's clothes: `@name!` exists because ngspice's
argument lists are positional, `bool`'s *"never `=1`"* is a measured ngspice defect promoted
into the type system. **Stage 15's conformance harness should test per KEY, not grep for
words.**

**4. `dict get`'s failure mode is part of the contract.** `ase::analysis_line` resolves a
required slot with `dict get` deliberately, because that is byte for byte what `render_deck`
raised before the refactor — a refactor may not change a failure mode any more than an output.
The consequence is that a caller which renders INCOMPLETE rows (the pane) must catch, and the
one that renders complete ones (the deck) must not. Row **D8j**.

**5. The state's `simulator` key is not always a backend name.** With the ranks moved out of
core and into the rendering backend's registry, an adapter must resolve **its own** registry
(`[namespace tail [namespace current]]`), not the state's `simulator` string — `test_ase_core`
E2b and E3 drive a missing binary and a `nosuchsim`, and the mistake cost 85 checks. Every
later adapter-side reader inherits this.

---

⚠ **STAGE 1 LEFT A DEBT AND STAGE 2'S RECON FOUND IT — issue 1405, fixed and committed before
any Stage 2 code.** `PLAN.md` §0.2 records *"No other suite in the tree touches a Choose Analyses
quick field by path"*, Stage 1 acted on it, and `ase::ui::chana_show` repeats it in a comment.
**It is false.** `tests/headless/test_ase_persist.tcl` row **G2** reaches the same widgets through
a variable — `set w $top.chana` then `$w.$fld` — so the `grep 'chana\.'` the claim rested on could
not see it. **Measured cost: 100 checks.** The display arm read `1 FAILED (46 passed)` with
`UNEXPECTED ERROR: invalid command name ".ase4.chana.source"`; it now reads **ALL PASS (148)**.
It stayed invisible for **three** reasons that all had to hold: the G-block is inside an
`if {!$mainok}` skip so the **headless arm reports `ALL PASS (44)` with the defect live**;
`run_regression.tcl` runs this file on **neither** arm, so **T1 at zero said nothing about it**;
and the raise was swallowed by the enclosing `catch`, taking G3–G11 with it in silence. New row
**G2p** asserts both halves — new paths present AND old paths absent — and sabotage-verified reds
`{0 0 1 1}`. ⚠ **The method lesson, which binds every later stage: a path survey must grep the
widget LEAF NAMES, not the toplevel's spelling**, and *an arm that skips a block reports ALL PASS
for it* — headless 44 against display 148 is not a weaker measurement of the same thing, it is a
measurement of a much smaller thing.

## Stage 2 — The type list is measured

⚠ **2e SHIPPED SEPARATELY AND FIRST, 2026-09-11 — issue 1404.** The Stop warning is the user's
*right away* item and the plan already says it "is not thematic to Stage 2 and is not pretending
to be": it rides this stage only because a new user-facing sentence costs ⚖ R9 and Stage 2 is the
first stage carrying one. It has no dependency on 2a–2d, so it landed as its own commit rather
than waiting for the type grid. **Stage 2's remaining items (2a, 2b, 2c, 2d, 2f) are still open**
and this block is filled when they land.

⚠ **"ONE COMMIT" FOR STAGE 2 IS REFUTED — IT IS SEVEN.** Six recon crews and twelve adversaries
returned **72 confirmed defects**, and three collisions that no single adversary could see because
they are *between* specs: `ase::analysis_state` is defined **twice, incompatibly** (2b and 2c, same
name, different bodies, different reason vocabularies); 2c proposed redefining `ase::analysis_offered`
to return triples and **spends a ⚠ block in its own spec warning about the trap that rename creates**,
then adds a row to catch it — which the adversary measured **cannot** (membership and order do not
depend on `caps`, so warm and cold answers are byte-identical and only the *dependency* moved); and two
specs claimed the same test-section letter. **A design whose own spec needs a row to catch the defect
it introduces should not introduce it** — `ase::analysis_offered` is unchanged and the triples proc
takes a new name, which makes the trap unreachable rather than merely caught.

The order, each commit sabotage-verifiable **on the tree as that commit leaves it**:
**C1** (2f) → **C2** (cache) → **C3** (2d) → **C4** (2a) → **C5** (2b+2c-core) → **C6** (2c-grid) →
**C7** (2g).

**STAGE 2 IS COMPLETE — ALL SEVEN COMMITS LANDED, T1 AT ZERO ON EVERY ONE.**
Full receipt: `receipts/07-stage-2-the-type-list-is-measured.md`.

| landed | commit | subject | floors |
|---|---|---|---|
| `4723380f` | **C2** | `fix(1406)` a re-registered backend kept answering from the registry it replaced | simcaps 110 → 111 |
| `8bfbbd6f` | **C1** | `fix(1407)` ASE-L asked the same question of one dict twenty-eight different ways | simcaps 111 → 126 |
| `13f5ff71` | **C3** | `fix(1408)` ASE-L described a simulator it had never been told anything about | core 266 → 273; dialogs **display** 215 → 224, headless 37 unmoved |
| `dd6302eb` | **C4** | `feat(1409)` ASE-L never asked the simulator which analyses it has | simcaps 126 → 141 |
| `df60b0af` | **C5** | `feat(1410)` eleven analyses, each with a state and a reason | core 273 → **289**; simcaps 141 → 148 |
| `66fdcead` | **C6** | `feat(1411)` the grid says which analyses this build can run, and why not | dialogs **display** 224 → **236** |
| `391ef0c0` | **C7** | `feat(1412)` four defects measured from files instead of a version string | simcaps 148 → **158** |

**WHAT THE USER SEES WHEN THE WINDOW REOPENS:** eleven analyses instead of four, in a wrapping grid,
each cell carrying its state as a glyph and its reason as a sentence; a bench naming a simulator
ASE-L has no adapter for says so instead of showing ngspice's four radios and an ngspice deck line;
and Detect appears exactly where a measurement could change an answer.

⚠ **THE HONEST GRID TODAY IS FOUR `ok` AND SEVEN `blocked`.** The renderable test sits above the
availability arms deliberately — offering a type the adapter cannot emit produces a run that emits
nothing. `absent` becomes reachable when Stage 6 gives the seven an `emit`, which also means the
plan's four-states-in-one-screenshot **cannot be taken yet**; the look debt says so.

⚠ **AND A STAGE 1 DEBT LANDED FIRST — `bcb2fc59`, issue 1405** (see the paragraph above Stage 2).

**THE LESSON THIS STAGE KEEPS RE-TEACHING, THREE TIMES IN THREE COMMITS: a test section is not done
when it is green, it is done when its sabotages redden it.** Twice a sabotage designed to prove a
row went **green**, and each time the row that now exists was written *because* of that:

* **C1** — respelling `ase::cap_report`'s refusal as `![ase::caps_is $c usable 1]`, the exact defect
  the vocabulary exists to prevent (issue 0953, in the proc 0953 was filed against), passed **all
  fourteen** rows of section P. P7 proved the two predicates *differ*; nothing proved the callers had
  picked the right one. **P15** is that row, and the ban it enforces is deliberately over-broad
  because *the call site cannot show you which question is being asked*.
* **C3** — `ase::ui::chana_x_ok`'s membership guard was **unreachable in the row meant to prove it**
  (that proc returns early unless `anextra` exists, and only `chana_options` sets it — which the
  previous guard had just refused). Deleting the guard left the suite at `ALL PASS`.
* **C3, again** — and the first attempt at *that* sabotage was itself malformed: it deleted
  `set _sim` along with the guard, so the proc **raised** instead of writing and the fixture's
  `catch` swallowed it. ⚠ **A SABOTAGE THAT BREAKS THE PROC PROVES NOTHING**, and it looks exactly
  like a sabotage that was correctly refused.

**AND THE DRIVER'S EXPECTATIONS WERE WRONG FOUR TIMES WHILE THE CODE WAS RIGHT** — P8 (2 reads on one
line, counted as lines), AD2 (`>=0` written as a literal expectation), G14f (the pane contents) and
the stale-pane fixture (`ase::session_update` does not repaint). Same shape as RG13 in Stage 2e.
**Measure, then write the expectation.**

**TWO SUITES HAD NO FLOOR PARAGRAPH AT ALL** — `test_ase_simcaps_0948` (added by C2) and
`test_ase_dialogs` (added by C3). Both now have one, and dialogs' is **two numbers**: 37 headless
against 224 display reported as one reads as a floor that fell by 187. ⚠ **`run_regression.tcl` runs
`test_ase_dialogs` on NEITHER arm** — measured — so a receipt quoting a T1 zero has not exercised one
row in it. That is why C3's contract rows live in `test_ase_core`.

| 2e | |
|---|---|
| commit | `fix(1404): Stop succeeds silently, and the user hunts for a rawfile that was never written` |
| shipped | `ase::backend::ngspice::run_stop_cost` (CONTENT) declared through a new OPTIONAL hook; `ase::run_stop_cost` / `run_stop_warning` / `run_stopped_msg` (SCHEMA); the `stop      :` field in `ase::run_log_header`; a CIW note at the last instant before `execute`; and `ase::ui::do_stop` saying what the stop cost **only on the path that killed something** |
| ⚠ the design 1e forced | **ASE-L owns the FRAME, the ADAPTER owns the CLAUSE.** Stage 1's Xyce paper-validation caught this item's own plan text asserting *"ngspice in batch mode writes nothing on a stop"* in ASE-L's voice — a run-model fact about one simulator in the half D34–D37 say may hold none. **A backend that declares no hook gets NO SENTENCE**; there is no fallback text, because a guessed warning is worse than silence |
| suites moved | `test_ase_core` section **SW**, 8 rows, floor **258 → 266**. ⚠ **RG13 does NOT move, and that was the finding**: the first expectation written for this change made RG13's CIW the new sentence and it FAILED — measured, RG12/RG13's fixture runs `simulator holdsim`, which is not a registered backend, so ASE-L correctly says nothing. The code was right and the test expectation was wrong. RG13 keeps `{}` with the reason written in, and **SW7** pins `holdsim` specifically so that silence can never be mistaken for the feature having quietly broken |
| sabotage | Three passes. The adapter dropping its `before` clause, and the hook never being registered, each redden **SW1/SW2/SW4**. ⚠ **The third is the one that matters**: making core fall back to the DEFAULT backend's clause for an unknown simulator — the tempting wrong fix — reddens **RG13, SW3, SW3b, SW5 and SW7**, which is how the "no guessed sentence" rule is actually enforced rather than merely written down |
| ledger debts | `owed.sh add rule 1404` — **two** sentences, the launch warning and the moment-of-Stop line, filed the moment they landed and paid with the ⚖ R9 batch. No look debt: both are plain text in the CIW and the run log, and the suite reads them by value |
| T1 | ⚠ **NOT AT ZERO ON THE RUN TAKEN FOR THIS COMMIT, AND THE FAULT IS THE DRIVER'S.** `run_regression.tcl` on this exact tree read **2 counted failures**, both row **X7** of `test_ase_optier_0963` — `rc=1 raw=-1bytes op-vectors=0`, i.e. the ngspice run died and wrote no raw at all. **Measured cause: four ngspice processes belonging to this batch's own Stage 2 recon crews were live throughout that run**, which is precisely the condition `CLAUDE.md` names — *"a T1 number taken while another agent's suite was live is not evidence"*. The driver launched the crews and T1 in the same window; that is the defect. Standalone, nothing else alive, same tree and the same command T1 uses, the suite reads **ALL PASS (103) twice over**, and X7's own header already records it as a flake that did not reproduce under the 1377 sweep. **The clean solo number is OUTSTANDING and is taken before Stage 2's first commit.** Green and uncontended at commit time: the 13-suite ASE family through `run_suites.sh` (ALL PASS on every one), `test_ase_core` **266**, `test_ase_simreg_0931` **111** |


*The `help <verb>` probe leg on the existing capability deck (no new run);
`analyses_available` + `devices_available`; the four-state wrapping radio grid with reasons
and a **Detect** button; the ungated-baseline fallback.* Suites: `test_ase_simcaps_0948`
gains rows. **Rulings: ⚖ R4 first, then ⚖ R9** for this stage's two label sentences.
Decisions: **D5, D6, D7, D8, D9**.

⚠ **Two sub-items the adapter pivot added on 2026-09-10.** **2d** — *Setup > Simulators* is the
gesture the whole doctrine is built around, and it had no owning stage: this one says where an
adapter lives, when it is loaded, and what the grid shows when a registered simulator's backend
declares no `analysis_types` hook (a sentence over an empty grid, **not** a fifth cell state, and no
Detect button — nothing was measured). And **Detect gains a second leg**, the bare command word with
no circuit loaded, which is immune to **M15** because it reads the command table rather than the help
database; it needs `-p`, so ⚖ **R1** decided whether it can be built now (`PLAN.md` §0.11 measures why
it cannot ride the existing deck) — and **R1 = Option A means it cannot**. Stage 2 ships one
Detect leg, the `help <verb>` probe, and the second leg is deferred with the transport. Debt
**M15** keeps its cheaper half open with it.

⚠ **A third sub-item, added 2026-09-10 with ⚖ R1's answer — 2e, the Stop warning.** *"Stopping this
run discards it — ngspice in batch mode writes nothing on a stop."* Both Stop doors call
`ase::ui::do_stop` → `kill_running_cmds $id -9`, the process dies at the default disposition in
a few milliseconds at worst, with nothing of the analysis in flight on disk, and today the window says none of it:
the Stop succeeds silently and the user goes looking for a rawfile that was never written. Two
places, both plain text, no dialog — one line at launch from `ase::run_log_header`, one from
`ase::ui::do_stop` on the path that actually killed something. **It is not thematic to this stage and
does not pretend to be**: it rides here because it is a user-facing sentence and Stage 2 is the first
stage in the plan that carries one, so it joins this stage's ⚖ **R9** batch. It is **not** salvage —
Stage **6f** is — and it ships first because a warning is what is honest until salvage lands. Two
refusals recorded so they are not re-proposed: **no modal confirm** (`test_ase_core` **RG13** drives
`do_stop` headless and a modal would hang it) and **nothing on the strip button's tip**
(`test_ase_window` **W1s1** asserts the `!` button's tip is both `[ase::ui::menu_path_stop]` and
the literal `Simulation > Stop`; **W1s2** is the no-tip gap guard and **W1s2b** pins the key set to
the packed buttons, in strip order). ⚠ Debt **M18**
opens the day this ships and closes only when 6f lands.

⚠ **Two more sub-items, added later on 2026-09-10 by the VARIANT-SUPPORT amendment — 2f and 2g.**
**2f, the variant record**: there is no second store — the keys go into the dict
`ase::sim_capabilities` already returns, in four bands (identity / capability / defect / provenance
of absence), plus **three predicates and a rule about which is which** —
`ase::caps_get` (the three states as data), `ase::caps_is` (gate UP; unmeasured answers 0; for
**capabilities**), and `ase::caps_measured_as` (true only when measured *and* matching; for
**mitigations**). ⚠ **Converting the ~12 hand-written `[dict exists $c k] && [dict get $c k] == 1`
guards is part of this commit, not a hope** — `ase::op_save_tier`'s five, `ase::cap_report`'s three
and the casemode layer's; leaving them gives the tree a fifteenth idiom instead of removing
fourteen. `unmeasured_keys` is a **deliverable** here, not a design note: `ase::cap_run` already
returns its `cut` flag, so a cut leg writes `unmeasured_keys {<key> timeout}` before returning.
**2g, the variant probe**: one more `-b` leg (leg D) after decks A/B/C, publishing
`one_vector_write`, `keyword_case` and `gnd_literal` — three file-existence verdicts, zero extra
processes beyond the one leg, measured 0.00 s. ⚠ **The tree already starts SIX processes, not
four** (A, B, C plus three casemode legs — `sim_probe_capability` loops
`foreach m {fold preserve distinguish}`); leg D makes **seven**, and because it runs last it is the
first thing a spent 30 s budget kills, which is why `unmeasured_keys` and Stage 16a's fourth
sentence frame exist. ⚠ **One leg was measured and REFUSED**: the `cp_remvar` abort probe, because
it SIGABRTs the user's own `/usr/bin/ngspice` from inside a Run gesture and apport is installed and
enabled on the target platform — see **D50**, which also carries the two-marker discipline any
future aborting leg must obey. Decisions **D42–D44**, **D48–D50**, **D52**.

| | |
|---|---|
| status | **COMPLETE** — seven commits, not the planned one. |
| commit | `4723380f` C2 · `8bfbbd6f` C1 · `13f5ff71` C3 · `dd6302eb` C4 · `df60b0af` C5 · `66fdcead` C6 · `391ef0c0` C7. Alongside: `bcb2fc59` (the Stage 1 debt, issue 1405) and the 2e pre-ship (issue 1404). |
| T1 | Zero counted failures on every one of the seven — **but the number was narrower than it read.** Issue **1413** later measured that `run_regression.tcl`'s case list ran `test_ase_core` on **neither arm**, so seven commits were gated on a T1 that never touched its 289 checks. Each suite *was* run standalone on every commit, so the work is verified; what was overstated is the **T1 cell**, not the testing. From `4216c8b2` onward T1 is **61 cases** and does include it. One earlier T1 was also contaminated by this session's own live crews (four ngspice processes, X7 red) and was re-run solo rather than waved through — issue **0990**. |
| suites moved | `test_ase_core` 266 → **289** · `test_ase_simcaps_0948` 110 → **158** · `test_ase_dialogs` **display** 215 → **236**, headless 37 unmoved · `test_ase_persist` not touched by this stage (it was found broken and repaired in Stage 3) |
| sabotage | Every new section sabotage-verified. **Two sabotages went GREEN, and each minted a row that exists only because it did** — **P15** (C1) and the `chana_x_ok` membership guard (C3). Row **U2** took four fixtures before one of them could fail at all. The three-bullet block above is the record. |
| ledger debts | `rule 1401`, `rule 1404`, `rule 1408`, `rule 1411` — four rulings, all stamped `repo:/home/analog/dev/xschem-claude`, **all four unpaid**, all four to be paid in Stage 3's ⚖ R9 batch. `look chana_type_grid_1411` — **unpaid**, and note it **cannot** yet show the plan's four-states-in-one-screenshot: `absent` is unreachable until Stage 6 gives the seven types an `emit`. |
| spec paragraphs rewritten | **None — measured.** No commit in this stage touches `doc/claude/specs/`. The wrapping grid, the four-state vocabulary and the capability predicates are all absent from `ase_l.md`. Recorded here as a **standing Stage 2 spec debt**, deliberately deferred to Stage 6 so the section is written once, against a grid that can reach all four states, rather than twice. |
| receipt | `receipts/07-stage-2-the-type-list-is-measured.md` |

### What Stage 2 learned that binds later stages

**A test section is not done when it is green; it is done when its sabotages redden it.** Three
commits in a row re-taught this, and twice the sabotage passed. The corollary is the expensive half:
a sabotage that *breaks the proc* proves nothing — it must be a **plausible respelling** that a
reasonable author might have written. P15 exists because respelling a refusal as `![ase::caps_is …]`
— the exact defect the capability vocabulary was built to prevent, inside the proc issue 0953 was
filed against — passed all fourteen rows of section P.

**A green harness is only as wide as its case list.** T1 read "zero" for seven commits while running
neither arm of the suite those commits were moving. Before a count is used as evidence, measure *what
the harness runs*, not what it prints — and prefer a per-suite number that names its own file.

**When a row and the code disagree, ask which of them is making a claim about the world.** `viewrank`
reddened D7k because it was given to seven types that can emit nothing; `viewrank` orders *results*,
and a type that produces none has no rank. The row was right and the registry was wrong. The reflex
"a red row means the test is stale" cost real time here.

**The predicate follows the direction of the gate, not the band it reads** (issue 1407), and **neither
predicate may ever appear under a `!`**. `caps_unmeasured` gates what we do not know; `caps_measured_as`
gates what we measured and matched. Negating either turns "not measured" and "measured false" into one
answer, which is the whole defect the vocabulary deletes.

**A backend with no hook gets NO fallback content** (D34–D37). Every `ase::backend_hook` resolve sits
inside a `catch`, because it raises for an unknown hook *and* for an unknown simulator. ASE-L owns the
schema; the adapter owns every word that reaches the deck.

**Three Tcl traps, each of which cost a full debugging cycle in this stage** and each of which will
recur in every later stage that writes a suite:

* a **bare word inside `expr`** (`expr {$x ? PASS : FAIL}`) is a syntax error that aborts the **entire
  file** — the only symptom is the suite's check count going **down**, never a red row. Hit four times.
* **Tcl counts braces inside comments.** An unbalanced `{` in a comment left `namespace eval` unclosed
  and **aborted xschem at startup** (issue 0663's arm). Write "open brace" in prose.
* a **`#` comment inside a command's argument list is an argument.** A comment block inside a
  `dict create` silently shifted the dict, `op` lost its `emit`, and a different suite broke in five
  places.

**Measured ngspice facts that later stages must not re-derive:** `help tf` prints the *tran* bracket on
all three binaries, so the first-token rule is load-bearing and the comparison must be case-insensitive
(`cieq()`); `pss` on stock-47 is the **only** reproducible `absent` fixture, because `help sp` answers on
all three — which makes the plan's `--enable-rfspice` example undemonstrable; and a build whose `spinit`
never loaded answers `devhelp` with **52** device names against 136/138, a fabricated absence of ~84
families. That last one is why a probe must verify its own environment before it is allowed to report a
capability missing.

---

## Stage 3 — The form stops lying

*Typed fields for the four types (`tran` `tstart`/`tmax`/`grid`/`uic`; `ac` `lin|oct|dec`,
killing the dead `dec`; `dc`'s four sweep kinds and second triple; unit labels; the
SI-suffix parser; relabels); `ase::ui::dialog_status`; refuse-at-OK; the `x` verbatim hatch;
Apply; the Initial-conditions sub-dialog, because shipping `uic` without it re-creates F3.*
Suites: G2's display string; `test_ase_persist`'s `arg_summary` rows; deck goldens gain
optional tokens. **Rulings: ⚖ R5, ⚖ R9.** Decisions: **D4, D21, D22, D31**.

⚠ **"ONE COMMIT" FOR STAGE 3 IS REFUTED TOO — IT IS SEVEN**, on the same grounds as Stage 2: each
commit has to be sabotage-verifiable on the tree as that commit leaves it. The order is
**C1** (the slot grammar) → **C2** (one refusal reader + the number alphabet) → **C3** (the four
field tables + the commit door) → **C4** (the typed form and the write-back rule) → **C5** (the door
closes on an unknown key) → **C6** (the `x` verbatim hatch) → **C7** (the Arguments column).

**ALL SEVEN COMMITS LANDED. STAGE 3 IS COMPLETE.**

| landed | commit | subject | floors |
|---|---|---|---|
| `234d1b86` | **C1** | `feat(1414)` a skipped value would have emitted an empty word and shifted every value after it | core 289 → 298 |
| `5a88836a` | **C2** | `feat(1415)` one refusal reader, and the number alphabet the simulator actually reads | core 298 → **309** |
| `865c2b08` | **C3** | `feat(1416)` a skipped start time let the maximum step be read as one, and the sweep mode was discarded | core 309 → 333; simcaps 158 → **164**; dialogs **display** 236 → 242 |
| `14be0470` | **C4** | `feat(1417)` the form offered an entry for everything, and said "Points:" for both AC sweeps | core 333 → 335; dialogs **display** 242 → 261 |
| `71e4454b` | **C5** | `feat(1418)` Options collected settings, round-tripped them, and never emitted them | core 335 → 337; dialogs **display** 261 → **265** |
| `0d1be0fe` | **C6** | `feat(1419)` the one escape from a typed form that actually emits | core 337 → 343 |
| *pending* | **C7** | `feat(1420)` the Arguments column listed values the deck would never carry | core 343 → **348** |

⚠ **AND `4216c8b2` (issue 1413) LANDED FIRST, BEFORE ANY OF THEM** — not a Stage 3 item at all, but
the thing without which no Stage 3 number could be trusted: T1 ran `test_ase_core` on **neither
arm**. It is recorded in Stage 2's block because that is the stage whose numbers it corrected.

⚠ **THE PLAN'S OWN FIELD TABLE WAS WRONG IN THREE PLACES, AND THE CORPUS IS WHAT SAID SO.** All
three were found by measuring the 104 committed benches rather than by reading the sketch again:
`@target` appears in **zero** committed rows against `source`'s **36**; the template's `?` and `!`
sigils are **swapped** against the grammar C1 shipped, and the plan's spelling would have emitted
`tran 1n 10u 0` for every committed row; and the `dc` sweep-kind classifier the plan sketched
("literal `temp`, else a voltage source") mislabels **seven** committed current-source benches.

| | |
|---|---|
| status | **COMPLETE** — all seven commits landed |
| commit | `234d1b86` C1 · `5a88836a` C2 · `865c2b08` C3 · `14be0470` C4 · `71e4454b` C5 · `0d1be0fe` C6 · C7 pending |
| T1 | C1 and C2 each taken **solo** at **61 cases, all zero** — the first Stage 3 numbers that actually include `test_ase_core`, because issue 1413 landed first |
| suites moved | `test_ase_core` 289 → **348** · `test_ase_simcaps_0948` 158 → **164** · `test_ase_dialogs` display 236 → **265**, headless **37 unmoved** · `test_ase_persist` 47 (broken) → **148**, repaired in C1. **No other suite moved a row**: the ASE family was re-run entire on both arms after every commit — window 295, final 82, view 36, optier headless 103 |
| sabotage | C1 six, C2 seven, C3 seven, C4 eight, C5 five, C6 seven, C7 four — **forty-four**, all verified to redden. ⚠ C2's first cut **preempted issue 1401's block** and reddened three preflight rows; the gate now defers the `unrenderable` token to the block that owns it. ⚠ C3's row **GR5 SURVIVED its sabotage**: with the group rule deleted the finding was empty, `string first` returned -1 on the empty string, and a row written to prove a clause carried no frame proved it about a clause that did not exist |
| ledger debts | Stage 2's four rulings (1401, 1404, 1408, 1411) still unpaid and now joined by **1414–1420**; all eleven to be paid in this stage's ⚖ R9 batch. **A look debt is owed for C4** — the tran form goes from two entries to two entries plus a disclosure plus three controls including a checkbutton, and the AC form gains a combobox that rewrites its neighbour's label |
| spec paragraphs rewritten | none yet — `### Choose Analyses dialog` in `ase_l.md` is six lines and is rewritten **in full in C4**, when the form's final shape exists to describe |
| receipt | pending |

### What Stage 3 learned that binds later stages

**Measure the corpus before trusting the plan's field names.** Three of this stage's corrections came
from one census of the 104 committed benches, and each of them would otherwise have been found by a
reddened suite after the code was written. The census is now a permanent row (section **CP** of
`test_ase_core.tcl`), so the next stage that adds a field can ask the same question in one run.

**A test that asserts a refusal is satisfied by a door that refuses everything.** Row G2b — *an
enabled tran with a blank step is rejected* — would have stayed green through a change that made the
dialog refuse every legal transient in the tree. The converse row is not optional, and it is the row
that has to be written at the same time, because after the fact nobody remembers the door ever had
two sides.

**Pin the claim, not the fixture.** Row Q1 asserted the whole `dc` emit template as evidence for a
statement about its *first word*, and reddened the moment `dc` legitimately gained four slots. A row
whose expectation is wider than its own sentence will red for reasons unrelated to its subject, and
a row that reds for the wrong reason is a row that eventually gets deleted rather than fixed.

**Positional grammars need a word for "left out".** ngspice reads `tran`'s optional values purely by
position, so "skip it" and "emit nothing" are different instructions — the second silently promotes
whatever stands to the right. `whenskipped` belongs on the **field**, because the field is the thing
that knows whether it occupies a position; a flag on the card would have made every optional slot in
every future template answer the same way.

---

## Stage 4 — The netlist permits

*`ase::netlist_facts`; the `needs` predicates; the `fatal` re-check inside `render_deck`; the
DISTO save-list rule (non-defeasible); the device × analysis matrix with the
contribution-vs-stamp split.* New suite; `ase::netlist_map_resolve` gains its second **kind**
of customer. **Ruling: ⚖ R9.** Decisions: **D10, D11, D12**.

| | |
|---|---|
| status | |
| commit | |
| T1 | |
| suites moved | |
| sabotage | |
| ledger debts | |
| spec paragraphs rewritten | |
| receipt | |

### What Stage 4 learned that binds later stages

---

## Stage 5 — Single-plot analyses

*`tf`, `pz`, `sens` (DC): three registry entries, three `precheck` rows. **No writer change
at all** — each is one plot, so emission stays byte-identical.* New deck goldens only.
**Ruling: ⚖ R9.** Decisions: **D1, D30**.

| | |
|---|---|
| status | |
| commit | |
| T1 | |
| suites moved | |
| sabotage | |
| ledger debts | |
| spec paragraphs rewritten | |
| receipt | |

### What Stage 5 learned that binds later stages

---

## Stage 6 — The writer, and the multi-plot analyses

*D16's `setplot previous` walk; the plotmap sidecar with its pre-run delete; post-run
reconciliation; `noise`, `disto`, `sens` (AC); per-plot `remzerovec`; result labels from the
registry; the read-only `ase::ui::resulttable`.* ⚠ **Every deck golden moves, once,
deliberately** (the sidecar line). Rows **E5 / M1 of `test_ase_optier_0963`** must be
re-proven green — **[R-M4]** says they will be, because the `op` write is untouched — and so
must `test_ase_cosim`'s **RD1–RD11** rendered decks. (`E5` in `test_ase_cosim.tcl` is a
plan-item label in a comment, not a check name; the real `E5` is `test_ase_optier_0963:616`.) **Ruling first: ⚖ R3.**
Decisions: **D15, D16, D30**. ⚠ Debts **M3 and M4 are CLOSED by measurement** (`PLAN.md`
§0.6 and §0.7) — an earlier draft of this block gated the stage on them. Nothing gates it.

⚠ **Sub-item 6f, added 2026-09-10 with ⚖ R1's answer: always-salvage.** *A Stop keeps what the run
had.* It lands here and **mints no stage number** — 0–15 is frozen — because Stage 6 owns the write
block: the mechanism is extra lines around one analysis inside `render_deck`'s per-analysis loop, and
it has to interact with the three things that loop already does (`set appendwrite`, the `$sim_status`
guard, `remzerovec`). Stage 6 is also the one stage allowed to move every deck golden once, which is
what changing the emitted `.control` block costs — so the checkpoint lines ride in the **same**
re-baseline as the sidecar line, not a second one. `PLAN.md` §6f is the item and §0.1's salvage block
(**SV1–SV15** — the `SV` prefix keeps them clear of `APPENDIX` §7.2's own S1–S33) is the measured
basis; `evidence/salvage.md` is the basis under that and is cited, never
restated.

**The shape, in one paragraph.** `stop after <points>` — **never** `stop when time`, which hands the
integrator a breakpoint and changes both the grid and the byte count, and which is **not disarmed
when it fires** (its `resume` advances one point; a deck written that way covers 12.5 % of its run
and exits **rc 0**). The checkpoint goes to `<rundir>/<cell>_ase.raw.ckpt` through a `.ckpt.tmp` plus
`shell mv -f`, bracketed by `unset appendwrite` / `set appendwrite`, and **never** into the results
file — `set appendwrite`, which `render_deck` already emits, turns an overwrite into a stack of
plots: four plots and 64,001,536 bytes where one is 25,600,541, with readback-by-plot-name broken.
Both new paths join the pre-run delete beside the rawfile and the plotmap, and the checkpoint write
emits no `PLOT` line, so the plotmap stays 1:1 with the results file. `delete all` before the next
analysis and before the final `resume`, because a stop armed once truncates everything after it in
the same block at rc 0. Counters in the `const` plot — **created before the first analysis, or they
are written into the output**: one made after the `tran` is a vector of `tran1`, so every `write`
emits it (`No. Variables: 5`, a `ckdone` column beside the circuit quantities) and the byte-identity
above is lost. Thresholds through a `set` variable and never
`$&` (which formats above a million as `1.2E+06` and arms nothing, at rc 0). **N = 4 by default**, a
checkpoint every 20 %, clamped `[2, 50]`, from `N + 1 = sqrt(T × B / S)`; an eligibility floor read
from the deck alone keeps short runs emitting no block at all, which is what keeps the small goldens
byte-identical. Measured end to end in ASE-L's own deck shape: SIGTERM 6 s into an 80 ms transient,
**rc 143**, the completed `op` and `ac` plots intact in the results file and **60 % of the transient**
in a `.ckpt` that loads.

**`tran` only, this stage.** `dc` and `ac` both stop and resume correctly but the full loop was never
run against either — one measurement each and they land. `op` never (one point). **`noise` and
`disto` never**: a stop there leaves an incomplete plot *set*, not a short plot, so a salvaged one
would be a wrong answer wearing a partial one's label. `pss` / `sp` / `pz` / `sens` / `tf` never
until measured — `sens` is already known not to honour `bg_halt`.

**Suites.** ⚠ **`test_ase_simreg_0931`'s six argv rows — A2 / B5 / B6 / B11 / B12 / D4 — do NOT
move**: 6f touches the deck, never the command line, and one of them going red means something
emitted a flag. New rendering rows run against the deck text with no simulator, including a
non-vacuity control (a `tran` above the floor that *does* emit the block beside one below it that
does not), and a **completeness row** pinning that the verdict comes from the deck's completion echo
and not from the exit status — **rc 0 with `SIM-STATUS-IS 0` in both arms** is the point of that row.
`test_ase_preflight` gains the pre-run delete of `.ckpt` / `.ckpt.tmp`. **⚖ R9 joins this stage's
rulings** for 6f's three sentences; **6f itself needs no ruling** — always-salvage is the user's own
requirement, given with R1's answer, and R9 ratifies only the wording.

⚠ **What 6f does and does not discharge.** It closes debt **M18** — the window in which 2e's warning
is honest and ASE-L is still lossy. It does **not** close the residue: everything in the never
column above keeps 2e's un-checkpointed sentence permanently, which is most of the rows, and that is
why 2e ships first and stays. Two limits stay open in the receipt rather than in a debt: `stop
after`'s byte-identity was measured on an **RC**, not on a transistor-level deck whose stepping is
LTE-limited, and there is **no `fsync` anywhere** in `rawfile.c` or `outitf.c`, so a machine crash —
as opposed to a kill — can still lose a checkpoint that `write` reported as finished. The escape
hatch is the existing idiom, `set ase_checkpoint 0`, a hidden variable and **no new state key** (⚖ R8
already spent the one exception to *no new top-level keys* on `sweep`).

⚠ **Sub-item 6g, added 2026-09-10 by the VARIANT-SUPPORT amendment**, and it is here because this
is the one stage allowed to move every deck golden. Four mitigations, three of them unconditional:
**6g-1** never emit a narrowed `save` in the same run as `disto`, `noise`, `tf` or dc `sens` — a
**correctness precondition**, not a workaround, because without it the analysis does not run at all
on **any** binary (measured, all three: `$sim_status` 1 and a rawfile holding only
`Plotname: constants`); **6g-2** filter a phantom raw column literally named `all` that duplicates
another column of the same plot; **6g-3** force `render_deck`'s `.save all` leader when the op plot
would otherwise hold exactly one save — **gated** on `ase::caps_measured_as … one_vector_write 0`,
because the leader restores implicit save-everything and changes a *correct* binary's results file;
**6g-4** a lint over the emitter so no rendered golden carries a capitalised ngspice keyword.
⚠ **6g-2 does NOT live in `ase::raw_content_verdict`** — that proc is a read-only diagnosis over a
64 KB head/tail slice with no variable list, and it never reads the `Values:` block; the seams are
`ase::cap_raw_plots` and the `xschem raw list` consumers, and ASE-L is **already immune at the
op-parameter seam** because `ase::op_param_split` demands an `@dev[param]` shape. ⚠ **Filter the
literal `all` only** — `allv`/`alli` are ASE-L's own Save-All tokens, not ngspice vector names.
⚠ **Add one test row per analysis type asserting the run survives a STALE Outputs entry**, which is
the normal case after a net rename and the case a user will actually hit. Decisions **D46**, **D47**.

| | |
|---|---|
| status | |
| commit | |
| T1 | |
| suites moved | |
| sabotage | |
| ledger debts | |
| spec paragraphs rewritten | |
| receipt | |

### What Stage 6 learned that binds later stages

---

## Stage 7 — The options surface

*The **220-row** catalogue with `cptype`/`door`/`phase`/`scope`/`inert`; `ase::opt_line` as the
only speller; search-first + changed-only + groups + the ⚠ badge + the live deck preview; the
pre-deck class; `<rundir>/.spiceinit` (copy-chained); the `-n` refusal; the post-run
verification leg.* ⚠ **CORRECTION 2026-09-09**: this said "~250"; the measured floor is
**220** — 57 settable `OPTtbl` keywords of 98 rows, plus 163 `cp_getvar` variables
(`PLAN.md` §0.4, APPENDIX §3.1). New suite; `run_cmd` goldens move the first time `-D` is
emitted — **six** rows pin the word order, not one: `test_ase_simreg_0931`
**A2 / B5 / B6 / B11 / B12 / D4** (D4 through `$D4SAID`'s first element), with **L11** pinning
the exe alone. Re-baseline all six in one commit or five go red. **Rulings: ⚖ R2, ⚖ R9.**
Decisions: **D17, D18, D19, D23, D24, D26, D33**.

⚠ **Amended 2026-09-10 by the adapter pivot, and this is where D33's amendment lands.** The 220 rows
are the **ngspice adapter's content**, declared in `ase::backend::ngspice` and reached through
`ase::sim_option_entry`; ASE-L owns the row *shape* (`cptype`, `door`, `phase`, `scope`, `inert`),
`ase::opt_line` as the one speller (D23) and D24's inert rule. `ase::spiceinit_write` and
`ase::effective_read` move to the adapter with the catalogue — `.spiceinit` is an ngspice filename.
Decisions gain **D34**, **D36**.

⚠ **Sub-item 7g, added 2026-09-10 by the VARIANT-SUPPORT amendment.** A `rules` clause may now read
the capability dict, and four rules do: never `option klu` on a run carrying an AC `sens`
(unconditional); never a narrowed `save` beside `disto`/`noise`/`tf`/dc `sens` (unconditional,
paired with 6g-1); `ac lin 2` / `sp lin 2` → **a form-level warning that names the fix** (*"a linear
sweep of 2 points yields 1 point; use 3"*) rather than a refusal, because refusing removes a number
the user typed into a form; and a `gated 1` option row whose `requires` says `absent` is listed and
disabled with the reason and the door. ⚠ **These are RULES, not a hazard registry** — a
`hazard_table` proc would be a table with no key (**D43**) pretending to be data. Decisions **D46**.

| | |
|---|---|
| status | |
| commit | |
| T1 | |
| suites moved | |
| sabotage | |
| ledger debts | |
| spec paragraphs rewritten | |
| receipt | |

### What Stage 7 learned that binds later stages

---

## Stage 8 — Measurements and post-processing

*The `measurements` state list; the Measurements sub-dialog; `meas` emission; the eight
derived templates including phase margin with `set units=degrees`; `.four`/`fft`/`spec`/
`psd`/`linearize` producers; THD and the harmonic table.* New suite; the Value column gains
rows. **Ruling: ⚖ R9.** Decisions: **D27** (non-negotiable here), **D30**.

| | |
|---|---|
| status | |
| commit | |
| T1 | |
| suites moved | |
| sabotage | |
| ledger debts | |
| spec paragraphs rewritten | |
| receipt | |

### What Stage 8 learned that binds later stages

---

## Stage 9 — SP end to end

*The gated type; the Ports table emitting `alter portnum` / `alter z0`; the `two_ports`
fatal evaluated **after** those lines; the S-parameter surface (matrix picker, Smith/polar);
`wrs2p` with the `.csparam Rbase=50` workaround.* New goldens. **Ruling: ⚖ R9.**
Decisions: **D6, D10**. Debt M12 belongs to this stage.

| | |
|---|---|
| status | |
| commit | |
| T1 | |
| suites moved | |
| sabotage | |
| ledger debts | |
| spec paragraphs rewritten | |
| receipt | |

### What Stage 9 learned that binds later stages

---

## Stage 10 — Convergence and diagnosis

*The ladder pane (content-matched, never order-matched); `CKTncDump`'s starred nodes
highlighted on the canvas; the remedy assistant with a diff preview; the `optran` panel and
the sentence on the OP form; `wrnodev` save/restore; the run-health strip.* New suite.
⚠ **Debt M1 (stdout/stderr as two ordered streams) must close first.** **Ruling: ⚖ R9**.
⚖ **R1 is answered (Option A)**, so this is no longer where the transport is *decided* — it
is where the scheduled second implementation of the run interface becomes **due**, the stage
after which `-p` was ratified to start.

| | |
|---|---|
| status | |
| commit | |
| T1 | |
| suites moved | |
| sabotage | |
| ledger debts | |
| spec paragraphs rewritten | |
| receipt | |

### What Stage 10 learned that binds later stages

---

## Stage 11 — Campaigns

*The campaign configuration; the shard runner; `.param x='var(…)'` + per-shard `.spiceinit`;
corners as re-rendered `.lib` decks; GUI-drawn Monte Carlo samples; `index.tsv` with a column
per measurement; histogram / mean / sigma / yield computed in Tcl; abort = kill the current
shard.* New suite; the multi-raw family question goes to the Calculator's spec (debt **M5** — the
same number `evidence/design-of-record.md` §16, `PLAN.md`'s "Still open" table and APPENDIX §8
all use; an earlier draft of PLAN numbered it M13, which collides with the DC-sweep question).
**Rulings: ⚖ R8, ⚖ R2.** Decisions: **D18, D19, D25**.

| | |
|---|---|
| status | |
| commit | |
| T1 | |
| suites moved | |
| sabotage | |
| ledger debts | |
| spec paragraphs rewritten | |
| receipt | |

### What Stage 11 learned that binds later stages

---

## Stage 12 — Event-driven results

*`edisplay` inventory; `eprvcd <nodes> > <cell>_ase_evt.vcd`; the VCD joins `attach_dbs`'
list; the `trtol`-forced-to-1 caution; the `dc`+auto-bridge caution; the `.probe alli`
refusal.* New goldens. **Ruling: ⚖ R9.** Decisions: **D28**. Debt M9 is this stage's
own proof.

| | |
|---|---|
| status | |
| commit | |
| T1 | |
| suites moved | |
| sabotage | |
| ledger debts | |
| spec paragraphs rewritten | |
| receipt | |

### What Stage 12 learned that binds later stages

---

## Stage 13 — Transient noise and `trrandom`

*The Tran form's collapsible section; both injection routes; all seven / all five arguments
padded; the derived readouts; the rms `meas`; the `notrnoise` row; the honest seed sentence.*
New goldens. **Ruling: ⚖ R9.** Decisions: **D10** (the `trnoise` k=v tokens are exactly what
`netlist_facts` keeps).

| | |
|---|---|
| status | |
| commit | |
| T1 | |
| suites moved | |
| sabotage | |
| ledger debts | |
| spec paragraphs rewritten | |
| receipt | |

### What Stage 13 learned that binds later stages

---

## Stage 14 — PSS, explicitly experimental

*The gated type; the hard validator; the stdout verdict scrape; last-TD / FD-by-`Plotname`;
the transient+FFT cross-check offer; the `oscnode` hint.* New suite.
**Ruling first: ⚖ R7.** Decisions: **D6, D7**.

| | |
|---|---|
| status | |
| commit | |
| T1 | |
| suites moved | |
| sabotage | |
| ledger debts | |
| spec paragraphs rewritten | |
| receipt | |

### What Stage 14 learned that binds later stages

---

## Stage 15 — The adapter conformance harness

*Added 2026-09-10, terminal, and it is **what the SECOND adapter needs, not what the first one
does**.* A suite an adapter author runs against their own simulator binary until it goes green:
the schema's required fields present and typed; every declared analysis emitting something the
binary accepts; the probe answering on a build that has the analysis and refusing on one that
does not; result names resolving to vectors that exist after a run. It turns "write an
integration" into a closed loop with a pass/fail signal, which is the thing that makes the
contract real for a simulator nobody here owns. **Not urgent while every adapter is
first-party and written by Xschem's own agent** — that is exactly why it is terminal and not
Stage 2. The measured argument for it is the one already in this batch, and it is **two probes, not
one**: `/usr/bin/ngspice` answers `help pss` with `pss [.pss line args] : Do a periodic state
analysis.` where `build-ver_50` answers `Sorry, no help for pss.`, and the bare command word answers
`pss: no such command available in ngspice` on `build-ver_50` while `/usr/bin/ngspice` **runs the
analysis**. So **one simulator on one machine already has two analysis sets**, and a harness that
only ever ran against one build would have called both descriptors conformant. New suite; no existing
suite is expected to move.
**Ruling: ⚖ R10** — this stage is R10's **option C**; **option B**, the adapter-author specification,
is debt **M16** below, unpaid on purpose. ⚠ **NOT DECIDED — the user has not answered R10**, and
until they do this stage is a sketch, not a commitment. No receipt is owed for it. (The lettering is
`DECISIONS.md`'s: **A** the working hook plus its documented schema, **B** A plus the specification,
**C** B plus this harness; recommendation **A** in this batch.)

| | |
|---|---|
| status | |
| commit | |
| T1 | |
| suites moved | |
| sabotage | |
| ledger debts | |
| spec paragraphs rewritten | |
| receipt | |

### What Stage 15 learned that binds later stages

---

## Stage 16 — "The ngspice you actually have"

*Added 2026-09-10 by the VARIANT-SUPPORT amendment. **Terminal in NUMBERING, not in priority** —
Stage 15 is terminal *and optional* (⚖ R10 = A); Stage 16 is terminal *and the adoption gate*. Say
so wherever the number is quoted, because a reader will otherwise take 16 for last-in-importance.*

**Depends on Stage 2f/2g. Nothing depends on it.** It exists because most people who download this
Xschem will run the ngspice their distribution shipped — measured, `45.2+ds-1` on the current
Ubuntu LTS — and today ASE-L says nothing at all about the difference. The RED row is the whole
justification: a `pre_command` reading `unset temp` on apt 45.2 gives **rc 134, a destroyed log and
no sentence anywhere**.

Five items. **16a** the per-simulator sentence, one line, four frames — nothing measured / nothing
missing / something missing / **measured but not completely** (that fourth frame is not decoration:
on a slow box leg D is dropped first and without it the user gets *"can do everything"* by default).
**16b** the pass-through linter, five patterns, one proc, **warns and never rewrites**, at
pre-flight before the first `open`, reporting the LINE and not the file. **16c** the two
co-simulation file checks at `$sourcepath`'s `scripts` directory — defects of the *installation*,
not of the executable. **16d** the `dumpunsound` reason token on `ase::op_save_tier`, so the
sentence can say the actionable thing instead of today's *"much shorter way … but it is all or
nothing"*, which is true and is the wrong explanation. **16e** the release note.

⚠ **16e SPLITS, and only half of it waits on a ruling.** The **description** — *"here is what works
on which ngspice"* — is a measured finding, costs zero code, and is the single
highest-adoption-value item in the amendment; it ships **now**. The **support sentence** — *"what we
test and will fix bugs against"* — is a promise, and it is ⚖ **R11**. An earlier draft had R11
blocking the whole note while also calling the note the item that could ship today; both cannot be
true.

⚠ **Three sentences 16a must NOT say**, each corrected from a draft that said them: never *"ngspice
47 fixes that"* (`git tag --contains 10276f993` returns nothing — that names a version that does not
exist yet, and this is the very sentence introduced to repair a wrong explanation); **PSS on no
row** (the rule is *mention only capabilities ASE-L actually offers*, and frame and worked table
must obey the same rule about the same binary); and it **never says "basic"** (**D45**).

**Suites: none move.** Everything is additive. New suite for `lint_control_text` (one row per
pattern, one proving it warns and does not rewrite, one non-vacuity row) and for
`ase::variant_sentence` (one row per frame, from hand-built dicts, so no binary starts). **Three
conformance rows, shared with Stage 15:** no ordering operator takes `version_line` as an operand
(**D44**); no bare `dict get $caps <capability key>` outside `ase::caps_get`; no `ase::caps_is`
under a `!` (**D48**). **One look debt** — a new user-facing line in an existing dialog; take the
shot with **two** registry entries so the two sentences appear side by side.

**Rulings: ⚖ R11** (16e's support sentence only, filed last of all) and **⚖ R9** (16a's four
frames, the five linter clauses, the two co-simulation clauses, 16d's explanation).
Decisions: **D42–D52**.

| | |
|---|---|
| status | |
| commit | |
| T1 | |
| suites moved | |
| sabotage | |
| ledger debts | |
| spec paragraphs rewritten | |
| tested on apt 45.2 as well as the fork | *required field for this stage: the sentence and the linter are ABOUT the stock binary, so a receipt naming only the fork has tested the one configuration this stage does not care about* |
| receipt | |

### What Stage 16 learned that binds later stages

---

## Deferred, and named so it is not forgotten

The `-p` transport and the transient debugger (`iplot`, `stop when`, `resume`, `step`);
`libngspice`; offering CIDER as anything but a detection; `sens2` and `hb`. ⚖ **R1 is
ANSWERED — Option A, 2026-09-10 — and it does not reorder this list**: `-p` stays deferred,
scheduled as the run interface's second implementation after Stage 10. ⚠ Two items of this
list are **partly redeemed inside `-b`** by `evidence/salvage.md` and are no longer wholly
deferred: `stop` and `resume` ride in the rendered deck as the checkpoint loop (`stop after`,
not `stop when` — §3.2), while `iplot` and `step` stay deferred with the transport; Stage 6f
is where that lands. The measured reasons live in `evidence/design-of-record.md` §15 and are
restated in `PLAN.md`'s refusals section — a reader who wants to re-add one of these should
read the refusal first, because each was costed, not overlooked.

---

## Debts this batch already knows it will leave

**Eighteen ids, of which four are already closed.** Twelve came from
`evidence/design-of-record.md` §16; **M13, M14 and M15 were added by the pass that wrote
`PLAN.md` and `APPENDIX_ngspice_analyses.md`**; **M16 and M17 were added on 2026-09-10 by the
adapter pivot, which creates them and deliberately does not pay them**; **M18 was added later
the same day, when ⚖ R1 was answered and always-salvage became a requirement**. One numbering
space across the batch: `M1`–`M12`
are inherited unchanged, `M13`–`M15` are the plan-authoring pass's, `M16`–`M17` are the
pivot's, **`M18` is ⚖ R1's**, and `M5` is the multi-raw family in every
document (an early PLAN draft numbered it M13 — that is fixed). No id is reused, and **the next free
id is M19**. `PLAN.md`'s "Still open" paragraph and `APPENDIX` §8 both read M19 as well, as of the
2026-09-10 amendment — each was stale at "M18" for the window between M18 being minted here and that
edit. All three defer to this table for the text of a debt, so **this line stays the one to believe**,
and a crew about to mint a debt checks here first.
⚠ Not to be confused with `[R-M<n>]`, the design of record's
**measurement** markers, which run to `[R-M19]` in a different namespace.

None of them blocks Stage 0 or Stage 1. **Only M1** blocks a specific later stage (Stage 10's
*live* pane, not the stage). **M17 is about Stage 1's schema but does not gate it**: Stage 1
pays down what it can with the Xyce paper exercise, and M17 is the residue that only a real
second adapter can settle. **M18 gates nothing either — it is a debt to the USER rather than
to a stage**, and it is the only one on this list that a person feels directly: it is open for
exactly as long as ASE-L tells someone their work will be lost and then loses it.

### Closed by measurement, 2026-09-09 — kept visible, not deleted

| # | the debt | how it closed |
|---|---|---|
| ~~**M2**~~ | Does `help <verb>` answer the same way on a build with a **relocated or stripped** help database? | **PARTLY CLOSED** by `APPENDIX` §1.7 `[A-M7]`: `/usr/bin/ngspice` (ngspice-45.2) answers `pss [.pss line args] : Do a periodic state analysis.` and `sp`, where `build-ver_50` says `Sorry, no help for pss.` Two builds on one machine genuinely disagree, which is what Stage 2's grid exists for. **Both builds had their database**, so the stripped/relocated case survives as **M15** below |
| ~~**M3**~~ | Does a bare `write <raw>` write every vector of the current plot? | **CLOSED — `PLAN.md` §0.6.** One deck, three plot kinds, both forms: identical variable and point counts on every shape. The walk may keep today's bare form. The probe also found the trap that hides it: without `set appendwrite`, `write` TRUNCATES |
| ~~**M4**~~ | The exact `Plotname:` literals of `disto`'s three IM plots and of `sens ac` vs `sens dc` | **CLOSED — `PLAN.md` §0.7.** All five DISTO literals and both SENS ones measured, with their plot ids. Two SENS analyses share one literal, which is why the join is positional on creation order |
| ~~**M6**~~ | Does the DISTO segfault exist upstream? | **CLOSED — `PLAN.md` §0.8.** rc 139 on `/usr/bin/ngspice` too, which self-identifies `ngspice-45.2`. It is upstream, not a `ver_50` artefact. File it |

### Still open

| # | the debt | why it matters | the experiment that settles it | due |
|---|---|---|---|---|
| **M1** | Can the ladder pane get stdout and stderr as **two ordered streams**? ASE-L folds them with `2>@1`, and two `ngdebug` lines carry **no trailing newline**. | Without it Stage 10's live pane can only read the log file after the fact. | Run a deliberately non-converging OP through `ase::run_deck`'s existing capture with `set ngdebug`, and diff the interleaving against two separate `-o` / `2>` files. One deck. | **before Stage 10** |
| **M5** | A **multi-raw family** (one raw per shard) is new to the waveform viewer and to the Calculator, whose spec says v1 handles only the single-raw multi-dataset case. | Stage 11's family-of-curves display has no owner. | Not an experiment — a conversation with `doc/claude/specs/calculator.md`'s owner, **at Stage 11, not at Stage 0**. | Stage 11 |
| **M7** | Does `.probe p(XU1)` really yield `xu1:power`, and what are the differential / power vector spellings (`vd_R1`, `mq1:power`)? Documented by the manual §11.6.5 and **never verified against source or a run by anyone**. | The Outputs column for that pick is keyed on those names. | One deck with `.probe p(x1)` and `.probe vd(r1)`; `display` and `write`, then read the names back. | before Stage 10 |
| **M8** | Does `set interp` change a **complex** AC plot and a **nested DC** sweep correctly? Measured only on a real transient (21 points from `tran 1u 20u`). | The Tran form's `grid` field is Stage 3; the AC and DC arms are Stage 6. | Three decks; `length()` and a spot value before and after. | Stage 3 / Stage 6 |
| **M9** | Does the `eprvcd` VCD attach cleanly through `ase::attach_dbs` **alongside** a rawfile, and does the digital pane label the nodes with their ngspice names? | Stage 12's whole claim. | Drive an `adc_bridge → d_inverter → dac_bridge` chain through a real ASE-L session with the VCD in `vcdfiles`. ⚠ The design of record cited this deck as `../dor/mx.cir`; **that directory no longer exists** (README). The deck is the one `evidence/xspice.md` §5 builds: an analog source into `adc_bridge`, a `d_inverter` code model, a `dac_bridge` back out, `.control` running `tran`, then `edisplay` and `eprvcd din dout > mx_evt.vcd`. | Stage 12 |
| **M10** | `Nintegrate()`'s definition was never located, so nobody can explain an `onoise_total` number to a user. | The Value column will show it. A tooltip that says what it is beats one that does not. | `grep -rn "Nintegrate" src/` in the ngspice tree, then read. Twenty minutes. | before Stage 8 ships |
| **M11** | Does `alterparam` + `reset` preserve `.options` and `set` variables across the re-parse, and does it re-read `<rundir>/.spiceinit`? | Stage 11's collapse-into-one-shard mode depends on it. | One deck: `option reltol=0.05`, `alterparam`, `reset`, then a bare `option` — diff the effective settings (D26's reader gives this for free). | Stage 11 |
| **M12** | What does `wrs2p` actually emit for an `sp` run with the `.csparam Rbase=50` workaround, and is it a valid Touchstone file? | Stage 9's export. | One two-port deck, `wrs2p out.s2p`, and open it in any Touchstone reader. | Stage 9 |
| **M13** *(new this pass)* | The **DC-sweep + auto-bridge failure** has a reproducer and no root cause. | Stage 12 ships a **permanent** user-facing caution (`dc` on a deck with event nodes is `caution`, not `ok`) with nothing behind it until this closes. A hedge with no debt becomes furniture. | `evidence/xspice.md` §12.1/§12.2 has the reproducer; someone must debug it. | Stage 12 |
| **M14** *(new this pass)* | Why does `help devhelp` print **nothing at all** — neither a help line nor `Sorry, no help for …`? | Nothing. It matters only as *"never probe with `devhelp`"*, which is already Stage 2's rule. | Not worth an experiment; **recorded so nobody re-hunts it**. | never |
| **M15** *(new this pass; was M2's surviving half)* | Does `help <verb>` answer correctly on a build with a **relocated or stripped** help database? `[A-M7]` covers a second build but **both had their database**. | Stage 2's whole capability gate rests on the `help <verb>` probe; this is the gate's one unmeasured failure mode. | The same probe against a third build, cross-checked against `devhelp`'s families. Publish only on a clean parse. ⚠ **Stage 2b's second Detect leg is the cheaper half**: the bare command word reads the command table and needs no help database at all, so **a disagreement between the two legs is itself the signal this debt is about**. It needs `-p` and no circuit loaded (`PLAN.md` §0.11), and ⚖ **R1 = Option A** keeps `-p` out of this batch — so that half is **not** available before Stage 2 ships, and this debt stays open on the `help <verb>` probe alone. | before Stage 2 ships |
| **M16** *(new 2026-09-10, the adapter pivot)* | **The adapter-author specification is not written**, and will not be. The schema is defined by the ngspice adapter that exercises it and by Stage 15's harness; there is no document that tells a stranger how to write the second one. | Adapters are first-party for now — written by Xschem's own agent, in this tree, versioned with it — so no stranger needs the document yet. The moment a third party is wanted, the absence is the whole cost of onboarding them, and nothing in the tree announces it. | Not an experiment. Write it **when a second adapter is actually wanted**, from what Stage 1's schema and Stage 15's harness turned out to be — never speculatively, because a spec written before its second implementation documents guesses. This is ⚖ **R10**'s **option B**, and it is deliberately left standing. | when a second adapter is wanted, not before |
| **M17** *(new 2026-09-10, the adapter pivot)* | **The schema will have been validated against exactly one implementation plus one paper exercise** — the ngspice adapter, and Stage 1's Xyce descriptor on paper. That is thin. A paper exercise finds the fields that cannot express a second simulator; it cannot find the ones that express it wrongly, because nothing runs. | Every later stage adds registry content on the assumption the schema holds. If it does not, the cost is paid across Stages 2–14 rather than at Stage 1. | Not an experiment either: **a real second adapter, written against a real binary, run through Stage 15's harness**. Nothing short of that settles it — a third paper exercise buys much less than the second one did. | open until a second adapter exists |
| **M18** *(new 2026-09-10, with ⚖ R1's answer)* | **The warning ships before the salvage does.** The sentence *"stopping this run discards it — ngspice in batch mode writes nothing on a stop"* costs nothing and lands as `PLAN.md` Stage **2e** — one line at launch from `ase::run_log_header`, one from `ase::ui::do_stop` when it kills something. The checkpoint loop that makes it untrue is Stage **6f**. Between those two moments ASE-L is **honest and still lossy**. | It is a debt to the **user**, not to a stage, and it is the one on this list a person feels: a warning is what is honest until salvage lands, never a substitute for it. The user ruled *"always salvage, and alert user"* — both, and in that order. Someone who reads the sentence and stops a ten-minute run has still lost ten minutes. | Not an experiment. **Stage 6f landing discharges it**, and on the same commit Stage 2e's sentence is replaced by the two numbers `evidence/salvage.md` §5.2 makes computable — worst-case loss `100/(N+1)` %, **20 %** at the default N = 4, against the I/O the checkpoints cost — plus §5.3's marking of a salvaged result as partial, which must come from the deck's completion echo and **not** from rc or `$sim_status` (both are 0 after a stop). ⚠ **A residue survives Stage 6f and is permanent, not transitional**: `op` has one point, `noise` and `disto` leave an incomplete plot *set* rather than a short plot, and `pss` / `sp` / `pz` / `sens` / `tf` are unmeasured (`sens` is already known not to honour `bg_halt`). For those the honest-but-lossy sentence is the final answer and must be worded as one, rather than promising a salvage that is not coming. | **Stage 6f** |

| **M19** *(new 2026-09-10, the variant amendment)* | **The other ~33 category-(b) fork fixes were never individually assessed for probeability.** Three turned out to be probeable in a deck that was already running — `one_vector_write`, plus `gnd_literal` and `keyword_case` as one-line riders — which overturns *"the fork's fixes have no probe"* as a blanket statement. **But three probes is not a survey.** | It bounds how much of the fork/stock gap ASE-L can *measure* rather than merely *warn* about. Every fix that stays unprobed is a permanent warning on a binary that may not need it — which is the nag Stage 16b exists to avoid becoming. | A pass over the 35 category-(b) commits of `evidence/fork-dependencies.md` §3 asking, for each, *"does this defect land in a file?"*. Those that do are probeable in the same one extra process (**D49**). ⚠ **Not by adding legs** — the rule is that a probe needing its OWN process to buy silence is not worth it, and one that is a line in a deck already running is free. | opportunistic; nothing blocks |
| **M20** *(new 2026-09-10, the variant amendment)* | **The known-0 leg of the build-flag probes is unmeasured.** Every binary on this machine has XSPICE, OSDI, RFSPICE and KLU, so the `flags` key is proven only in its **positive** direction. | Nothing today. It becomes real the first time a user registers a stripped build and ASE-L has to say *"this one lacks X"* rather than *"this one has X"* — and a gate that has never been seen answering 0 is a gate nobody has tested. | One `../configure --disable-xspice --disable-osdi --disable-klu --disable-sp && make -j8`, then re-run leg D against it. ~2 min on the evidence of the **99-second** stock-47 build. | before Stage 16 ships |
| **M21** *(new 2026-09-10, the variant amendment)* | **The `casemodewrite` spec/code divergence is untouched.** The shipped spec asserts ASE-L emits `-D casemodewrite` alongside any non-`fold` mode; the code does not. So **no ASE-L run produces a self-describing raw, even on the fork.** | Nothing in this plan — it is a small, safe gap. But the crew that builds Stage 16 **will read that spec**, and will find it describing behaviour that does not exist. A spec that is wrong in one place is not trusted in the others. | Not an experiment: a one-line reconciliation of the spec against the code, by whoever owns that spec. `evidence/fork-features.md` §11 has the measurement. | when Stage 16 is picked up |

**And one debt that is this document's own.** The suite table above records **call sites**,
not run rows, because no suite was run for this baseline. The first crew to touch a suite
replaces its row's `calls` figure with a measured before/after pair, per arm, and says in
its receipt which it did. Until then, no number in that column may be quoted as a floor.
