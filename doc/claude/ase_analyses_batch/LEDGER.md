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

### ⚖ R3 — the Outputs Value column — **ANSWERED 2026-09-12, Option C**

**The user's words: *"both with a rule is right, keep it"*.** Named vectors are read from the
**rawfile**; arbitrary typed expressions are read from the **`print` log**.

⚠ **No code changed.** Option C is what issue **1429** shipped as the recommendation, so the
ruling ratifies standing behaviour rather than redirecting it — which is the outcome the
"ship the recommendation, keep the alternative cheap" discipline exists to make possible.
Stage 6 was named as blocked on R3 and was never actually blocked, because of it.

**What it closes.** `noise`, `tf` and `sens` keep a Value column they could not have had under
Option B: with the prints anchored where the user's own ruling in issue **1243** put them,
`print Transfer_function`, `print onoise_total` and `print r1` produce **nothing at all** — no
value, no warning, no error line — while all three vectors sit in the results file. And
`v(a)*2` keeps working, which Option A would have broken.

⚠ **Keep row RS3 of `test_ase_core`.** It *performs both rulings* by stubbing
`ase::result_source`, with a fixture log deliberately carrying a different number from the
results file so the row can say which reader answered. That row is what would make a future
reversal one line rather than an archaeology exercise, and its value does not disappear
because the ruling landed the way the recommendation pointed.

⚠ **This does NOT close ⚖ R9.** The three user-facing sentences the R3 reader seam added are
still unratified, and issue 1429's `owed.sh` entry says so explicitly. R9 stays batched with
1426–1428, 1430, 1432 and 1433.

⚠ **A source-comment debt this created, and it is named so it is not forgotten.**
`src/ase.tcl`, four suite headers, the issue file and receipt 13 all say R3 is *asked and
unanswered* and mark Option C as a *recommendation*. Those sentences are now false. They were
NOT corrected in this pass because a crew held `src/ase.tcl` and two of those suites at the
moment the ruling arrived; the correction is the first item of the next driver pass.

### ⚖ R4 — the seeded analysis rows — **ANSWERED 2026-09-13, Option A, keep four**

**The user's words: *"keep four. I don't know how we ended up with this, but it's probably
more user-friendly than zero. In Cadence ADE-L it is zero"*.** A freshly created ASE-L state
keeps exactly **four** rows — `op`, `dc`, `ac`, `tran` — and the other seven registered types
arrive through the dialog. The four-state grid shows all eleven whether or not the state file
mentions them, so nothing becomes unreachable.

⚠ **No code changed, again.** Eleven commits across Stages 5–8 shipped Option A by
construction, because every one of them deliberately withheld `seed_enabled` from the analysis
type it added. The ruling ratifies standing behaviour.

⚠ **AND THE RULING CORRECTS THE ARGUMENT IT WAS PUT ON, WHICH IS THE PART WORTH KEEPING.**
Option A was offered to the user with *"Cadence does not add analyses to your bench either"* —
i.e. as **ADE-L parity**. **ADE-L seeds ZERO.** So ASE-L's four rows were never a match; they
are a divergence in the user's favour, and the user ratified them as one. The recommendation
reached the right answer through a claim that was not true, which is the worse kind of right,
and the claim was doing persuasive work in a decision that was the user's to make.

⚠ **The general rule, because this batch cites ADE-L constantly: ADE-L is the FLOOR, not the
ceiling.** *"ADE-L does not do this"* is an argument for removing a **restriction** of ours —
that is the standing benchmark rule and the reason issue 0643's hierarchy limit was a defect.
It is **not** an argument for removing a **convenience** of ours. And ADE-L behaviour should be
checked rather than recalled before it is cited in a ruling.

⚠ **WHAT THE RULING OBLIGES, AND IT IS NOT NOTHING.** The reason R4 existed is D5's: *"today
this would change by accident."* The registry carries a `seed_enabled` key and eleven commits
kept it off by hand. **A ratified decision must not rest on anybody remembering it.** The
follow-up is a row that names `seed_enabled` as the thing that must stay off — stronger than
the existing assertion that four rows come out, which a twelfth seeded type would also satisfy
if it were seeded *and* the count updated. ⚠ **NOT DONE IN THIS PASS**: a crew holds
`src/ase.tcl` and `test_ase_core.tcl` at the moment the ruling arrived. Same shape as R3's
comment debt, and the same remedy — **it is the first item of the next driver pass.**

⚠ **Two stale counts fixed in `DECISIONS.md` while recording this.** R4's Option B said
*"seeding all twelve"*; the registry holds **eleven**. The twelve was never re-counted after
the registry settled.

### ⚖ R5 — the form's memory across a type switch — **ANSWERED 2026-09-13, Option A, reverse D4**

**The user's words: *"Make it remember — that's a more professional UI. We are trying to be
better than Cadence"*.** Switching the analysis radio will keep what you typed, per type, for
the dialog's lifetime; OK still commits only the visible type.

⚠ **THE FIRST RULING IN THIS BATCH THAT IS WORK RATHER THAN RATIFICATION.** R1, R2, R3 and
R4 each landed on behaviour the tree already had — twice because the recommendation had been
shipped ahead of the ruling on purpose. **R5 is the opposite**: D4 shipped in Stage 3, the
recommendation was to reverse it, and the user reversed it. So this one has a crew task
attached.

⚠ **D4's REASON SURVIVES THE REVERSAL INTACT, WHICH IS WHY THE REVERSAL IS CHEAP.** D4 was
recorded as *"deterministic, no hidden multi-type writes"* — and **nothing is written until
OK either way.** That sentence defends the **commit**, not the discarding; the commit is
unchanged. A decision's stated reason turning out to defend a different thing from the
behaviour it was attached to is worth noticing, because it is how a cheap change looks
expensive for a year.

⚠ **THE TREE HAD ALREADY MEASURED THE DEFECT FROM THE USER'S SIDE AND NOBODY CONNECTED IT.**
`doc/claude/ase_l_ux_batch/FINDINGS.md` records *"I typed 500u, clicked the ac radio, clicked
back, and 500u was gone"* — a lived failure sitting in one batch's findings while another
batch carried it as an open ruling with a recommendation. **A UX finding and a ruling about
the same behaviour are the same item**; neither directory knew about the other.

⚠ **AND THE CASE GOT STRONGER AFTER THE RULING WAS WRITTEN.** Its trade-off line says
*"defensible with four types and a trap with twelve"*. Issue **1411** made the radio row a
wrapping grid of **eleven**, four per row — so the exploration a new user does first is
exactly what costs them their typing.

**Where it lands:** `src/ase_window.tcl` only, one dict per open dialog, no new widget, **no
`look` debt**. Sequenced **before Stage 8 task 2**, so the Measurements sub-dialog that task 2
builds in the same file **inherits** the behaviour instead of being retrofitted. ⚠ **The
reversal must name `doc/claude/ase_l_batch/prompts/item07_dialogs.md`**, which is where this
`D4` lives — it is *not* `DECISIONS.md`'s own D4, and a reader who reverses that one changes
the per-row key rules instead.

### ⚖ R6 — per-analysis identity — **ANSWERED 2026-09-13, Option A, add it**

**The user's words: *"Add it"*** — one bench may hold two DC sweeps, or a DC sweep and a
temperature sweep, and each becomes addressable.

⚠ **AND THE RULING ARRIVED CARRYING A REQUIREMENT NEITHER OPTION OFFERED**, which is the
part worth the ledger's space:

> *"also plan for a way for measure statements (pending work) that could be used in the
> calculator to refer to different analyses. It should be easy for a user to find out how to
> refer to different analyses … One way could be … Analysis > List which will dump one
> liners on each of the enabled analyses. Just thinking aloud here. If there is a better way,
> you may pursue that. If it's cheap to include, then include now. Else, just plan by adding
> an issue."*

**Filed as issue 1444**, with the driver's answer to *"is it cheap now?"* being **no, and for
a nameable reason**: the handles such a lister would show **do not exist yet**. ⚖ R6's `id`
is ruled and unimplemented, Stage 8 task 2's dialog is unwritten, and a lister built today
would render an unsettled naming scheme over rows that cannot be told apart — the *green but
hollow* shape this batch has spent the year removing. So it is **sequenced**, and the
sequencing is the deliverable.

⚠ **A BETTER WAY THAN THE MENU DUMP ALONE, AND THE USER'S IDEA SURVIVES INSIDE IT.** Three
surfaces, **one** naming scheme — three spellings would be worse than none:

1. **Pick, don't type** (Stage 8 task 2). The Measurements dialog's *which analysis* field is
   a dropdown of enabled analyses, each as handle plus a human one-liner. The user never
   learns the scheme because they never spell it.
2. **The handle where the user already is** (R6's task). One column in the Choose Analyses
   grid. No new window, no new menu entry.
3. **`Analyses > List`** (R6's task) — the user's own proposal, and it **earns its place
   because of the calculator**. `src/calculator.tcl`'s `calc::` namespace is where an
   expression is *typed*; a dropdown does nothing for someone composing `180 + vp(out)` by
   hand or writing a verbatim `x` block. Weakest for discovery, **strongest for the one case
   the other two cannot reach.**

⚠ **SECOND TIME A RULING HAS ARRIVED WITH A REQUIREMENT THE OPTIONS DID NOT CONTAIN.** ⚖
R1's *always salvage* was the first, and that one refuted the premise the question had been
costed on. **A ruling is a conversation and not a selection** — which is exactly why the
standing preference is one at a time.

⚠ **TWO PREMISES DRIVER-VERIFIED BEFORE ASKING.** R6's Option A claims `id` is *"absent on
every committed file"*: the four `.state` files matching `id` carry an **output row named
`id`**, not a per-analysis key, so the premise holds. And Option B's claim that the
addressing is undone: `chana_row` at HEAD still returns the **first** row of a type.
⚠ **One premise was deliberately NOT repeated to the user** — the plan's *"it is ADE-L
behaviour #9"* — because an ADE-L claim had just been wrong in R4's recommendation. It is
recorded as the plan's claim, unverified.

### ⚖ R7 — the PSS panel — **ANSWERED 2026-09-13, Option A, ship it experimental**

**The user's words: *"follow your recommendation"*.** PSS gets a real form in Stage 14,
**last**, marked **experimental**, gated on the simulator declaring `pss`, with a hard
validator and the **transient+FFT cross-check offered beside the answer**.

**What it changes from today:** `pss` is currently `registered 1`, `baseline 0`, probe-only
— driver-verified in the registry — so the grid lists it and refuses it with *"ASE-L cannot
set up PSS yet, so it is listed but cannot be enabled."* That is effectively Option B
already, and Stage 14 replaces it with a form.

⚠ **THE ARGUMENT THAT DECIDED IT HAS MOVED SINCE THE RULING WAS DRAFTED, AND THAT WAS SAID
WHEN IT WAS PUT.** The reason not to ship was PSS's measured defect: *"Convergence not
reached"* returns **rc 0 with plausible-looking data** — the silent-wrong-answer class this
whole batch exists to hunt. Three things built **after** the ruling was written now catch
exactly that shape: the `$sim_status` guard, issue **1430**'s post-run plot reconciliation,
and issue **1442**'s requested-versus-effective readback. **A ruling drafted against an older
tree can become easier to answer without anybody re-costing it** — worth re-reading the
remaining five for the same reason before they are put.

⚠ **ONE PART OF THE RECOMMENDATION WAS RATIFIED WITHOUT BEING RESTATED.** The written
recommendation has four parts; three were put to the user (ship last, the word
*experimental*, the transient+FFT cross-check) and the fourth — **the sentence that
`oscnode` steers nothing**, correction C17 — was not. It is inherited from the written
recommendation rather than separately ratified, and its wording rides ⚖ R9 regardless.
Recorded rather than blurred.

⚠ **AND THE QUESTION BEHIND THE QUESTION WENT UNANSWERED, DELIBERATELY.** The driver asked
whether the user actually *runs* PSS — oscillators, mixers, switched-capacitor — because
that is the thing no measurement here can settle and it decides whether Stage 14 is effort
the user will feel. The user answered by delegating instead. **Stage 14 is last in the plan
anyway**, so the cost of that is nil today; if the stage ever needs to be cut for time, this
is the paragraph that says why it is the cheapest one to cut.

### ⚖ R8 — where a campaign lives — **ANSWERED 2026-09-13, Option A, the state file**

**The user ruled after asking what the question meant**, and their answer carried a
requirement neither option stated:

> *"What does 'inside the bench' mean? Will there be an artifact on the schematic? I want it
> in the simulation state — so the user can interact with this Monte-carlo 'campaign' in
> ASE-L"*

⚠ **THE CLARIFYING QUESTION WAS THE DRIVER'S FAULT AND IS RECORDED AS SUCH.** *"Inside the
bench"* admits a reading the ruling never meant — *on the schematic*. It is **not**: the
`.state` file is a separate **view** (`ngspice_state1/`, beside `schematic/` and `symbol/`)
and **nothing is written to the schematic**. **A ruling phrased so that it can be answered
wrongly is a defect in the asking**, and the user caught it rather than the driver.

⚠ **AND IT IS A SURFACE REQUIREMENT, NOT A STORAGE ONE.** Option A is written as a storage
decision; the user ruled on it as *"so the user can interact with this campaign in ASE-L"*.
**Stage 11 owes a surface, not merely a key** — and that is the **third** ruling in this
batch to arrive carrying something the options did not contain, after ⚖ R1's *always
salvage* and ⚖ R6's analysis-reference discovery.

⚠ **THE PREMISE THE COST WAS ARGUED ON HAD ALREADY EXPIRED, AND THE DRIVER FOUND IT BY
CHECKING BEFORE ASKING.** Option A's cost was *"the one schema exception"* — D3 permits no
new top-level state key and names the campaign as the **single** exception. Measured while
the ruling was being put: **Stage 8's `measurements` list is already a second one**, added by
the same `ase::omit_if_empty` mechanism, with **all 104 committed `.state` files still
byte-for-byte unchanged**. So the exception was already paid and proven across every bench in
the repository. **Second time today that a ruling drafted against an older tree turned out
cheaper than its own trade-off line** — ⚖ R7 was the first. ⚠ **The remaining three should
be re-read against the tree before they are put**, not taken from the page.

⚠ **TWO DOC CORRECTIONS FELL OUT OF IT, BOTH MADE.** **D3** said *"no new top-level key"*
with one named exception and now records **two**, with the measurement behind them. And
`PLAN.md` §8a calls the measurements list *"per-row"* where it shipped **top-level** — and
top-level is **right**, because a measurement *references* an analysis rather than belonging
to one, so per-row would duplicate every measurement reading a second analysis. **The code is
right and the plan's parenthetical is wrong.**

⚠ **THE USER'S OWN BENCH IS ALREADY SHAPED FOR THIS.**
`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap` carries
`{name VCCGAUSS value {agauss(1.8, 'ABSVAR', 1)}}` — a Monte Carlo distribution written by
hand, which ASE-L today runs exactly **once**. Stage 11 is what turns that into a spread.

### ⚖ R10 — how far the adapter contract is formalised — **ANSWERED 2026-09-13, Option B**

**The user's words: *"go with B — your recommendation"*.** A **written adapter-author
specification** ships; the **Stage 15 conformance harness does not**, until there is a second
adapter to run it against.

⚠ **THE RECOMMENDATION WAS NOT ONE OF THE THREE OPTIONS**, and the reason is this batch's own
most expensive lesson. **A conformance harness with ONE implementation behind it cannot tell
the contract from the implementation.** Run against ngspice it would pass against ngspice and
codify ngspice's shape as the contract, with nothing able to disagree — *a row whose fixtures
never disagree cannot fail*, at architecture scale and priced at a whole stage. We have met
that defect **nine times in test rows and once in a measurement harness**; building it a tenth
time deliberately, as Stage 15, would be a choice rather than an accident. A written spec has
no such failure mode: prose that is wrong about a hook is wrong in a way **a second author
notices and complains about**.

⚠ **SO STAGE 15 LEAVES THIS BATCH'S COMMITTED SCOPE.** It stays in `PLAN.md` as a stage that
may be **chosen** when a second adapter appears. The batch is **16 committed stages**, not 17.

⚠ **THE MEASUREMENT THAT DECIDED IT.** Option A — *"a second adapter's author reads the
ngspice one"* — was framed on 2026-09-10 and the driver re-read it against the tree rather
than the page:

| when | hooks `ase::register_backend ngspice` declares |
|---|---|
| **2026-09-10**, when R10 was written | **8** |
| **2026-09-13** at HEAD | **23** |
| the same day, Stage 8 in flight | **27** |

`ase::backend::ngspice` is **4,987 lines**. **The contract roughly tripled while the question
sat on the queue**, with eight stages still to go. Option A was reasonable at eight hooks and
is not at twenty-seven. ⚠ **Third ruling in one day whose cost had moved since it was
drafted** — ⚖ R7 and ⚖ R8 were the others, and that is now a pattern rather than a
coincidence: **re-measure a queued ruling before putting it, always.**

⚠ **WHEN THE DOCUMENT IS WRITTEN IS PART OF THE ANSWER.** Not now. The contract is still
growing — Stages 9–14 and 16 add hooks — and a specification written against a moving
contract is stale on arrival. **That is measured, not feared**: `doc/claude/specs/ase_l.md`
sat **five stages** behind until `1d12c12a` paid it off this same day. **The adapter-author
specification is written after the last hook-adding stage** — after Stage 14, with or before
Stage 16 — and it is cheap when it comes, because the contract is already written key-by-key
in the code's own comment blocks. Collecting and sharpening, not deriving.

### ⚖ R11 — the minimum supported ngspice — **ANSWERED 2026-09-13, Option C**

**The user's words: *"go with your recommendation"*.** The floor is a **capability** floor
(`known 1 && usable 1`), enforced by the probe, with **no version comparison anywhere**; and
the release note carries one sentence naming the **tested set as binaries**, not versions.
**All three conditions ratified**: never a version comparison, below the floor ASE-L still runs
and says why once, and the tested set is re-measured when it moves.

⚠ **OPTION A WAS NOT PUT TO THE USER AS LIVE.** `DECISIONS.md` already records the version
floor as listed-to-show-why-rejected — it needs the comparison **D44** forbids and gets the
stock-47/fork pair wrong by construction, both answering `ngspice-46+`. **Offering a dead
option makes a choice look wider than it is**, so it was presented as rejected with the reason,
and the live choice was B against C.

⚠ **RE-MEASURING STRENGTHENED THE RECOMMENDATION, WHICH IS THE OPPOSITE OF THE LAST THREE.**
⚖ R7, R8 and R10 each turned out **cheaper** than their drafted trade-off. R11's ground held
— apt **45.2** is still installed here and still above every capability floor — **and the
batch has since found it is not identical to the fork**: it writes a phantom duplicate column
beside a lone op save, and issue **1434** emits a deck line to work around it, gated on a
measured capability. **So C's sentence is a description of existing practice rather than a
promise about the future** — every measurement in Stages 1–8 was taken on both binaries for
precisely that reason. That makes the sentence *more* worth having, not less.

### ✅ ALL SINGLE RULINGS ARE ANSWERED — only ⚖ R9 remains

⚖ **R1–R8, R10 and R11: answered.** ⚖ **R9** is the standing **batched** copy debt and is not
a question — it is every user-facing sentence this batch has put on screen without ratification,
carried on `owed.sh`'s rule queue one issue at a time so that it can be answered in **one pass**
rather than per sentence. It needs a **document** to read through, not a conversation, and the
one-ruling-at-a-time preference names label ratification as its single declared exception for
exactly this reason.

⚖ **R9** is the only ruling left, and it is the **batched copy debt** rather than a single question. Every single ruling — ⚖ R1–R8, R10, R11 — is answered, **seven of them on 2026-09-13**. ⚖ **R3 was answered 2026-09-12**, and ⚖ **R4** through ⚖ **R8** on 2026-09-13 — all six above. ⚖ R6's answer also minted issue **1444**. ⚖ **R11 — the minimum supported
ngspice — is new that day**, from the variant-support amendment, and is filed **last of all**,
behind R10: it gates **one sentence** (Stage 16e's support promise), not a stage, and the
*description* half of that release note ships without any ruling at all. `DECISIONS.md`'s ruling ledger is
the place they live and the order it sets is the order to ask them in — **one at a time, each
a short conversation**, which is the standing preference R1 was asked under. ⚖ **R9** is the
declared exception: it is batched per stage.

✅ **AND THE DOCUMENT IT NEEDS NOW EXISTS — `R9_COPY_REVIEW.md`, 2026-09-13.** **291
strings, 19 issues**, handles `R9-001`–`R9-291`, grouped by surface. Built by 12 agents in
parallel, every string taken **verbatim from the committed source at HEAD** rather than from
the issue prose — which turned out to be necessary rather than careful: most issue files only
*describe* their copy, and several quote drafts that were superseded before the commit landed.
**Section A is the nine cross-cutting choices**, each with a recommendation, so the ruling can
be answered in one pass instead of 291. Issue **1443**'s strings are excluded and join when
the Stage 8 crew's receipt lands.

**The driver re-measured the extraction rather than trusting it.** All 291 strings were
searched for in the committed source at HEAD with Tcl line-continuations joined the way the
interpreter joins them: **260 are present as a single literal, byte for byte; 31 are not, and
all 31 are RENDERED rather than wrong** — `label` + `unit` + the colon `form_label` appends,
an ASE-L frame + a clause the **ngspice adapter** supplies, a branch variable expanded into
the two sentences it can produce, or a readable placeholder shown where the code writes a
variable. Those 31 carry a `Rendered:` line in their entry, because the words are what the
user reads but the **edit lands on the pieces** — and for two of them one piece belongs to
the adapter, not to ASE-L. Nothing was found that the source does not say.

**And the document was then checked for HOLES from the other end.** Reading 19 issues can
only find what the issues mention, so every commit those issues name was diffed and every
**added** string literal of five words or more carrying no variable was extracted and matched
against the review: **29 such literals, 27 already present, 2 missing** — `ase: state design
has no cell (plotmap_path)` (1430) and `… (effective_path)` (1442). They are now **R9-292**
and **R9-293**, appended rather than inserted so the handles already in front of the user
stay stable. The review is **293 strings**.

⚠ **The two gaps were the same sentence twice, and the family has SIX members** —
`ckpt_path`, `plotmap_path`, `effective_path`, `cosim_file`, `log_file`, `raw_file`. Three
predate this batch and are not R9's to ratify, but the wording is shared, so a change to one
moves all six. **A completeness sweep found what nineteen careful readers did not**, and the
reason is structural: each agent read one issue's worth of surfaces, and this sentence's
family is spread across six procs and three batches.

⚠ **TWO CREWS ARE LIVE AT ONCE — 2026-09-13, deliberately, and this is a DEPARTURE from
one-task-at-a-time that is being declared at the moment of departing.** The batch's operating
model is one task to one crew; the reason to depart is that **Stage 8 task 1 holds five files
and none of them is `src/ase_window.tcl`**, which is the only file ⚖ R5's reversal touches —
so the second task is disjoint by construction rather than by care. The split is written into
both briefs: task 1 holds `src/ase.tcl`, `tests/headless/test_ase_core.tcl`,
`tests/headless/test_ase_persist.tcl`, `tests/headless/test_ase_meas_1443.tcl` and
`tests/run_regression.tcl`; ⚖ R5's crew (**issue 1445**) holds `src/ase_window.tcl` and
`tests/headless/test_ase_dialogs.tcl`, is forbidden to create a suite file (registering one
would need `run_regression.tcl`), and is forbidden to run `tests/run_regression.tcl` at all —
**T1 stays the driver's, and solo, which is what issue 0990 requires.** Neither crew commits.

✅ **UPDATE 2, same day: THREE agents now, two of them writing.** Stage 8 task 1 finished and
is committed (`3f31a33b`), which released `tests/headless/test_ase_core.tcl` — so ⚖ **R4's
unpaid `seed_enabled` row** went out as its own task (receipt 26), holding that file alone.
Issue **1446**'s crew still holds `src/ase_window.tcl` and `tests/headless/test_ase_dialogs.tcl`.
The third agent **writes nothing**: it is extracting issue 1443's user-facing strings for
`R9_COPY_REVIEW.md`, reading `src/ase.tcl` from git rather than from the tree. ⚠ ⚖ **R6's task
is NOT dispatched yet on purpose** — its schema half would want rows in `test_ase_core.tcl`,
which R4's crew is holding, and **a split that is disjoint by construction is the whole reason
this departure is survivable**. It goes out when R4's row lands.

✅ **UPDATE, same day: ⚖ R5's crew finished and its work is committed (`0d5f16b1`); the second
slot is now issue 1446's crew**, on the identical file split that worked for R5 —
`src/ase_window.tcl` and `tests/headless/test_ase_dialogs.tcl`, no new suite file, no
`run_regression.tcl`, no T1. Stage 8 task 1 still holds its five. **The departure is
therefore ongoing rather than finished**, and it has now been run twice with no collision.

⚖ **R5 is sequenced here on purpose**: Stage 8 task 2 builds the Measurements sub-dialog in
the same file and the same form idiom, and it should inherit the remembering behaviour rather
than be retrofitted with it. ⚖ **R4's `seed_enabled` row is still unpaid** and stays unpaid
until task 1 releases `tests/headless/test_ase_core.tcl` — it is the first item of the driver
pass that collects task 1.

### ⏳ ⚖ R6 — DISPATCHED as its SCHEMA half, issue **1447**, 2026-09-13

⚖ R6's task owns four things and only two of them can be written today, because
`src/ase_window.tcl` is held: **the optional per-row `id` key**, **the canonical naming
scheme** (issue **1444**'s requirement, which must follow `ase::meas_binding`'s existing
`{type idx}` shape and live in **one proc everything calls**), and **one arm on
`ase::meas_binding`** so a row carrying an `id` binds by it. The **handle column in the
Choose Analyses grid**, **`Analyses > List`**, and the dialog's **row addressing** —
`ase::ui::chana_row` still returns the *first* row of a type, driver-verified at HEAD —
follow when the file frees.

⚠ **The scheme is the half that matters for ordering.** Stage 8 task 2's Measurements
dropdown **consumes** it; if that order ever inverts, task 2 mints its own display form and
there are two spellings of the same idea in one dialog. The brief says so in as many words,
and requires the crew to write down *the exact call the GUI half must make*.

⚠ **And the scheme is ⚖ R9 copy**: it is a spelling the user will read and type. The crew
files `rule 1447` the moment it lands, and it joins `R9_COPY_REVIEW.md` with issue 1443's
strings.

### ✅ ⚖ R4's obligation — PAID, 2026-09-13, receipt 26

⚖ R4 kept the four seeded rows (*"keep four … In Cadence ADE-L it is zero"*). Its unpaid half
was a test row that **names `seed_enabled`** rather than counting to four, and it went out the
moment Stage 8 task 1 released `tests/headless/test_ase_core.tcl`.

| | |
|---|---|
| **what landed** | **AG3b** — a census over the shipped registry (`ase::analysis_types ngspice`) asserting exactly `{op 1 dc 0 ac 0 tran 0}` declare the key, exactly `{noise tf pz sens disto sp pss}` declare none, 11 entries scanned — and **AG3c**, its positive control: the same census with `disto` *given* the key, so a blind extractor cannot pass both. `tests/headless/test_ase_core.tcl` only; **`src/ase.tcl` was not changed**, confirmed by the driver from `git status`. |
| **the shape** | The dispatch asked which of two shapes the tree has. It is the first: **`seed_enabled` is a literal key in the registry dict**, four types declare it and `op` alone has it on. So the row asserts the **split** — *"no type declares it"* would be false of the four rows the user just ratified, and what must stay off is **declaring it on anything else**. `ase::analysis_seed`'s `if {![dict exists $e seed_enabled]} { continue }` is the mechanism the row guards. |
| **driver's own re-run** | `RESULT: ALL PASS (602 checks)` on **both** arms, up from 600. Nothing else moved. |
| **sabotage** | Five, each restored by `cp` with an md5 match. |
| **receipt** | `receipts/26-r4-seed-enabled-row.md` |

⚠ **The sabotage found something the row was not written for.** A twelfth entry declared
`registered 0 seed_enabled 1` is **invisible to every other row in the suite** — `ase::analysis_offered`
drops it and `ase::analysis_seed` iterates *that* — so 600 of 602 checks pass. Flip one word to
`registered 1` and it becomes **a ticked-on fifth row on every fresh bench**. **AG3b is the only row in
the tree that can see it**, and only because the census walks `dict keys` rather than the offered list.
That is D5's *"this would change by accident"* in its least visible form.

⚠ **And the obligation is discharged for the REGISTRY, not for the key's MEANING.** If a later stage
makes seed membership computable rather than declared, AG3b passes while the seed grows. Recorded here
because the next person to touch seeding is the one who needs to know it.

### ✅ Stage 8 task 1 — the DECK half of measurements, issue **1443**, collected 2026-09-13

| | |
|---|---|
| **status** | **Done.** A `measurements` state list beside `outputs`, a four-verdict refusal evaluator, the `meas` speller, the post-processing producers and the sidecar. **The GUI half is task 2** — this task creates no widget, and `src/ase_window.tcl` is untouched by it. |
| **schema** | `measurements` is **absent by default** and the **fifth** member of `ase::omit_if_empty`, which is how the second named exception to **D3** is paid for: **104/104 committed `.state` files stay byte-identical**, driver-verified as *no tracked `.state` file modified in the working tree*. |
| **split** | ASE-L owns the SCHEMA (31 `ase::meas_*` procs — **driver-verified independently at HEAD by brace-scanning every one of them and stripping comments: 31 found, ZERO whose code mentions `ngspice`, `spice`, `xyce` or `spectre`** — — section HK, and **HK1b runs HK1's own token list over the adapter and finds them**, so the rule is enforced rather than remembered); the adapter owns CONTENT (19 procs, **four registered as OPTIONAL hooks**). Eighteen kinds; `meas` lines emitted inside `.control` immediately after the analysis they read. |
| **suites moved** | New `tests/headless/test_ase_meas_1443.tcl`, registered in `run_regression.tcl`. `test_ase_core` 598 → **600** (R1 re-baselined 18 → 19 keys, R1m added); `test_ase_persist` likewise. |
| **driver's own re-run** | Every number below taken by the driver from a `RESULT:` line, on both arms. `test_ase_meas_1443` **ALL PASS (100)** headless **and** **ALL PASS (100)** on the dev display. `test_ase_core` **ALL PASS (600)** on both. `test_ase_persist` **ALL PASS (44)** headless, **ALL PASS (148)** display. |
| **sabotage** | **72 applications on the final tree, ZERO KILLS**, across two campaigns (pass 1: 54 applied, 48 red, 6 survived; pass 2: 71 applied, 67 red, 4 survived; a targeted re-run closed one). Six rows were added for pass 1's survivors, each with its own sabotage. Three survivors remain, each argued behaviour-preserving in the receipt. |
| **T1** | ⚠ **STILL DEFERRED, for the same reason and now the last one outstanding.** Issue 1446's crew was editing `src/ase_window.tcl` at the moment this was collected, so a T1 taken now would be a number about a tree nobody has finished writing. T1 runs **solo**, once, when 1446 lands — covering ⚖ R5, Stage 8 task 1 and 1446 together. |
| **ledger debts** | `owed.sh add rule 1443` — ⚖ **R9** copy: eighteen kind labels, the field labels, twelve refusals, the spectrum caution, five report sentences. ✅ **EXTRACTED AND APPENDED the same day: `R9_COPY_REVIEW.md` is now 372 strings**, the last 79 being 1443's (**R9-294 … R9-372**), and every handle already in front of the user kept its meaning. The debt's own checklist was met and exceeded — the extraction also found six adapter refusals, the S-parameter fatal clause, the `render_deck` frame, the `failed` advice sentence, the `meas_path` raise, the sidecar filename and the `ASE-MEAS` marker. **Driver-verified: all 79 are byte-present in the committed `src/ase.tcl`**, so none is composed and every edit lands where the string is. **No `look` debt** — `src/ase_window.tcl` untouched, both arms identical. |
| **receipt** | `receipts/23-stage-8-measurements.md` |

**Nine corrections came back (C145–C153). Three were re-measured by the driver rather than taken on trust, and all three hold.**

1. ⚠ **C145 — `units` IS one of ASE-L's 247 catalogue rows, and this ledger said it was not.**
   Driver-verified at HEAD: `units {cptype string phase run group output scope global default
   radians values {radians degrees} …}`. The paragraph above (Stage 7's) **conflated two
   catalogues** — ngspice's 220 names, which genuinely do not include `units`, and ASE-L's
   247, which are the 220 **plus 27 measured additions** with `units` among them. Corrected in
   place. The consequence was real: a reader taking it literally would have spelled a second,
   competing line instead of going through `ase::opt_line`.
2. **C146 — the plan's stated reason for the redirect was false, and the crew shipped the
   reason that is true.** Driver-verified on both binaries, same deck: `set measureprec=10`
   and `NGSPICE_MEAS_PRECISION=10` are **accepted and INERT on apt 45.2** (`meas` still prints
   `-7.851545e-01`) and **honoured by the fork** (`-7.8515453642e-01`). So the redirect buys no
   precision on 45.2. This is now **difference #5** in `evidence/binary-differences.md`, and the
   only one where the older build genuinely cannot do something — it *accepts the setting and
   ignores it*, which is worse than refusing.
3. **The `.four` CARD runs the simulation TWICE** — driver-verified on both binaries by
   counting `Doing analysis` lines: **2** with the card, **1** without, from otherwise
   identical decks. That is why the `.four` card slot ships **empty** and `fourier` is emitted
   as a command instead.

**And the radians trap reproduces through `meas` itself**, on both binaries: a phase read by
`meas` is `-7.851545e-01` by default and `-4.498604e+01` after `set units=degrees`. A phase
margin measured without it is wrong by 57.3×, at rc 0, silently.

⚠ **AND THE EXTRACTION FOUND THE SEVENTH MEMBER OF A FAMILY THE DOCUMENT HAD PUT AT SIX.**
`ase: state design has no cell (meas_path)` joins `ckpt_path`, `plotmap_path`, `effective_path`,
`cosim_file`, `log_file` and `raw_file` — the same sentence seven times, differing only in the
parenthesised proc name. R9-292's note says a change to one moves all of them; it now says seven.

⚠ **AND IT NAMED THE DELIVERY PROBLEM PLAINLY, WHICH IS WORTH MORE THAN THE STRINGS.** Task 1 is
the deck half, so **almost none of its copy can be seen yet**: the eighteen kind labels are
declared and read by nothing, the report frames are consumed only by `ase::meas_report` — **which
has no caller anywhere in the tree** — and a `refuse` verdict makes `ase::meas_for` drop the row
from the deck **silently**. Four strings are reachable today: the deck refusal, its clause, the
sidecar filename and the `meas_path` raise. **That is the right order to ratify in** — Stage 8
task 2 builds the surface next, and words settled first are words it consumes rather than
re-mints.

⚠ **One stale number was found and corrected by the driver at collection.**
`tests/run_regression.tcl`'s new comment said the suite is *"86 checks headless and 86 on the
dev display"*; both arms answer **100**. The suite grew after the sentence was written. That
is the **third** time in this batch a prose number has disagreed with a `RESULT:` line —
**take a suite's count from its verdict line, never from a paragraph.**

⚠ **HEAD moved six times underneath this task** (⚖ R5's commit, three ruling commits and the
driver's evidence files), and one of those commits carried this crew's own `NUMBERING.md`
entry with no collision. Two crews plus a committing driver is survivable; it is survivable
**because every dispatch names the files it owns**.

⚖ **R6's `id` key will need one arm on `ase::meas_binding`** when R6's task lands — recorded
here so it is not rediscovered.

### ⚠ Four UNSTAMPED ledger entries — found by a crew, verified by the driver, touched by nobody

⚖ R6's crew reported four entries with no `repo:` line, before its own first `add`. The driver
re-measured rather than relaying:

```
rule/1357
rule/1357@xschem-claude
look/hier_pdf_nav_1357_H6.1789071932.2875683
suite/test_hier_pdf_links_1333
```

and the stamp split is now **216 this clone / 13 op-wcard** (it was 182/14 on 2026-09-10 —
the numbers move every time anyone measures, which is why `CLAUDE.md` says re-measure rather
than quote).

**`CLAUDE.md` is explicit that against a stamped ledger an unstamped entry is EVIDENCE, not
legacy**: it means another clone's older `owed.sh` wrote over something. The prescribed
reconstruction is `cleared.log` — and `cleared.log` mentions **neither 1357 nor 1333**, so
there is no pre-image for any of the four.

⚠ **And the two `rule/1357` files are issue 1400's collision shape INSIDE the debt queue.**
They are two different rulings under one number: one is *"the hierarchical PDF nav strip ships
ON (item H6)"*, the other is *"pressing Add while the SUMMARY list is in force writes the
ANNOTATION list"*. Answering *"1357"* is therefore ambiguous — the queue cannot say which
ruling the user meant.

**Nothing was touched**, by the crew or by the driver: the rule against claiming an unstamped
entry for this clone exists precisely because doing so erases the only signal the overwrite
left. Recorded here, and a backup of the queue was taken before the crew's own `add`.

### ✅ T1 — RUN SOLO, ZERO FAILURES, 2026-09-13 — the deferral is discharged

**`RESULT: 69 Start lines, rc 0, ZERO counted failures.`** Read by the documented rule — a
`FAIL` ending a line, a `GOLD?`, a `RESULT?`, or a leading `FATAL` — and by the crash tell:
**no `couldn't execute` and no `exit 127` anywhere in the log.** The literal strings `FAIL`,
`FATAL` and `TIMED OUT` appear **zero** times in 69 cases.

**69, up from 68**, because `test_ase_meas_1443` joined the case list with Stage 8 task 1.

⚠ **It was DEFERRED THREE TIMES and that was the right call each time.** The tree carried two
crews' uncommitted work for most of the day, and `CLAUDE.md` is explicit that *a T1 number taken
while another agent's suite was live is not evidence*. Run at the first moment nothing else was
writing, it covers **five** landings in one number: ⚖ **R5** (1445), **Stage 8 task 1** (1443),
⚖ **R4's row**, **1446**, and ⚖ **R6's schema half** (1447).

**And it was run SOLO**, which is the other half of the rule: issue **0990** means two
`run_regression.tcl` at once corrupt each other and the loser reports a `FATAL` that never
happened. Nothing else was running.

`test_ase_dialogs` is in T1's **headless** list, so the standing display-arm red `G2sens`
(issue **1436**) cannot reach this number — checked before the run rather than explained after
it.

### ✅ ⚖ R6 — SCHEMA HALF SHIPPED, issue **1447**, collected 2026-09-13

| | |
|---|---|
| **what landed** | `src/ase.tcl` **+293**. (1) The optional per-row **`id`** key on an `analyses` row. (2) **The scheme, one speller**: a row's handle is its `id` if it declares one and **`<type><n>`** otherwise — `ac1 dc1 dc2 tran1 op1` — in eight procs at `:9144–9385`, with `ase::analysis_by_handle` returning **`{type idx}`**, `ase::meas_binding`'s own shape. (3) One arm on `meas_binding` so a measurement's `id` names the analysis handle and **outranks** its `row` index, plus three `meas_verdict` clauses so a handle that did not bind says which of three things went wrong. **`src/ase_window.tcl` was never opened** — no widget exists. |
| **schema cost** | ⚠ **Nothing was added to `ase::omit_if_empty`, and that is the point**: `id` is written **only when a row declares one**, so *a key that is never written cannot need omitting*. A different mechanism from `sim_entry` and `measurements`, which are top-level keys that must exist-and-be-empty. No `version` bump, no new `schema_keys` member. |
| **driver's own re-run** | Both arms, from `RESULT:` lines. `test_ase_core` **622 / 622** (was 602). `test_ase_persist` **49 headless / 153 display** (was 44/148). `test_ase_meas_1443` **100 / 100**, unmoved. |
| **byte identity** | `STATEFILES: 104 / MISMATCH: 0 / ANALYSIS-ROWS-WITH-id: 0`, identical before and after, now suite row **`CP7`** with **`CP7c`** as its control. Driver-verified independently: **no tracked `.state` file is modified.** |
| **sabotage** | **Thirteen**, each restored by `cp` + md5. |
| **receipt** | `receipts/27-r6-identity-and-naming.md` |
| **T1** | ✅ **RUN SOLO AND CLEAN — see the block below.** |

**The exact call the GUI half must make** — recorded here so the next crew does not re-derive it:

```tcl
set handle [ase::analysis_handle $state $idx]              ;# the grid column
set body   [ase::analysis_handle_text $sim $state]         ;# Analyses > List, already padded
set f      [ase::analysis_handle_fields $sim $state $idx]  ;# dropdown entry fields
dict set measrow id $chosen_handle                         ;# NOT `row <index>`
```

**Do not call `ase::analysis_id` for display** (it answers `{}` for most rows) and **do not
re-derive `"$type$n"` anywhere.** `HN15`/`HN15b` extend D34's schema/content guard to the eight
new procs, because section HK's proc list could not see a different prefix.

**Two sabotages are findings rather than confirmations.**

* **S5** — an **output** row named `id` read as the per-row key — reds **`HN7` and `R8e` and
  nothing else in 771 checks.** That is exactly the confusion the driver's brief named, and it is
  now caught in the readers *and* in the file.
* **S6** — deriving handles from `ase::analysis_offered` reds **`HN10` alone**. So a `registered 0`
  type, or one the registry never heard of, **still gets a handle**, deliberately: *"what do I call
  this?"* is a question about the **bench**, not about the registry, and the alternative leaves
  exactly the rows a user most needs to ask about unnameable. ⚠ Note this is the **second** task in
  a row whose sabotage turned on `registered 0` — ⚖ R4's `AG3b` found the same blind spot from the
  other side.

**Three corrections.**

1. ⚠ **`Analyses > List` lists EVERY row, not only the enabled ones** — a deliberate departure from
   issue **1444**, and the reason is the user's own: a measurement bound to a switched-off row
   refuses, and the next question is *which one*. Disabled rows carry `(off)`.
2. The measurement selector is a **separate `id` key that beats `row`**, not an extension of `row`.
   Receipt 23's note could be read either way.
3. `test_ase_persist`'s floor paragraph said **147** display where the arm measures **148** —
   corrected in the same diff. **Fourth** stale prose number this batch has caught.

⚖ **R6's GUI half remains**: the handle column in the Choose Analyses grid, `Analyses > List`, and
the dialog's row addressing. `src/ase_window.tcl` is free now.

### ✅ Issue 1446 — OK writes what the dialog remembered, collected 2026-09-13

Filed by the driver out of ⚖ R5's residual, implemented **ahead of the user's answer** because
the standing instruction on an open ruling is to implement the recommended shape and say so.
**The `rule` debt stands untouched**; if the user rules Option A this is one small revert, which
is why the change was required to be small and separable.

| | |
|---|---|
| **code** | `src/ase_window.tcl`, **+44 lines of which 12 are code**: `ase::ui::chana_commit_vals` returns the visible type's cache — **filtered to that type's declared field names** — with the live form merged **over** it, and `chana_ok`'s single reader line calls it. The cache procs' contract is untouched. |
| **driver's own re-run** | headless `RESULT: ALL PASS (37 checks)`; display `RESULT: 1 FAILED (321 passed)`, up from 312. The one red is `G2sens` (issue **1436**) with the identical actual value; `GG9` passed. |
| **the D4 guard** | ⚠ **"Can one OK write two types?" is answered by a ROW, not by a sentence** — `GR6e` presses OK on `ac` with a folded `tran` edit *proven present in the cache*, asks for the `ac` row written with **no foreign field name in it**, and asks for every other row of the bench back **byte for byte**. Sabotage `s6` (commit every cached type) reddens it **and** ⚖ R5's own `GR5g`. |
| **byte identity** | 104 tracked `.state` files, **0 differ**; zero modified. |
| **sabotage** | **Eight**, every `GR6` row witnessed, md5-verified restores. |
| **receipt** | `receipts/25-1446-ok-writes-what-was-remembered.md` |

**Five corrections, and three of them are about how a test lies rather than about the feature.**

1. **The driver's brief named the wrong proc.** It said `chana_ok` should read
   `chana_cache_apply`; that proc is **cache over row**, and the commit needs **live over
   cache**. A crew that followed the brief literally would have made a stale cached value beat
   what the user had just typed. Hence a new reader rather than a reuse.
2. ⚠ **The cache contains `enabled`, which is not a field.** A bare `dict merge` writes a stale
   Enable *after* `chana_ok` has already set it — bench ON, box OFF. **Not in the driver's trap
   list.** Row `GR6g`, sabotage `s5`, and the fix is that the reader answers in **fields only**.
3. ⚠ **`GR5k` cannot fail on a `form_is_absent` bypass** — see the corrected row in ⚖ R5's block
   above. The crew's first cut of `GR6f` copied it and **survived all eight mutations**; retargeted
   to `ac` it reds. *A row copied from a row that passes inherits whatever that row cannot see.*
4. **Reading `dlg(…,anen)` after OK raises** — `chana_cancel` unsets it — which **kills the suite
   file instead of reddening a row**. That is `G2tf`'s shape, met again in a new place.
5. **A wrong-type cache is nearly inert today**, because the field filter drops it: no two types
   share an `advanced 1` field name. Recorded with the mechanism, since the day two do, the
   filter is the only thing standing there.

⚠ **One residual, pinned rather than fixed.** The precondition banner's `chana_merged_row` still
reads live widgets only, so it judges the **stored** value where OK now writes the **remembered**
one. No sentence changes today — no `needs` rule reads an advanced field — and row `GR6h` pins it,
so the day one does, a row goes red instead of a banner going quietly wrong.

### ✅ ⚖ R5 — IMPLEMENTED, issue **1445**, collected 2026-09-13

| | |
|---|---|
| **status** | **Done.** The Choose Analyses dialog remembers per-type edits for the dialog's lifetime and commits **only the visible type** at OK, which is ⚖ R5's answer word for word. The cache dies with the dialog: cleared on open **and** on close, so reopening starts from stored state. |
| **issue** | **1445** — *the form forgot what you typed the moment you clicked another analysis*. `NUMBERING.md` advanced to 1446, both checks run against every clone under `~/dev/*`. |
| **code** | `src/ase_window.tcl` only, +167/−14: three procs (`chana_cache_clear`, `chana_cache_save`, `chana_cache_apply`) and four call sites — save **before** the destroy in `chana_show`, apply in place of the bare `chana_row`, clear on open and on cancel. **No new state key, nothing serialised, no schema change.** The repopulate comment is rewritten to describe what the code now does, still naming `doc/claude/ase_l_batch/prompts/item07_dialogs.md`'s D4 as the decision reversed — not `DECISIONS.md`'s own D4. |
| **suites moved** | `tests/headless/test_ase_dialogs.tcl`, new section **GR5**, **twelve** rows. Display floor **300 → 313**; headless unmoved at **37**, because every GR5 row is a widget row. |
| **driver's own re-run** | Taken by the driver, not quoted from the receipt. Headless: `RESULT: ALL PASS (37 checks)`. Display: `RESULT: 1 FAILED (312 passed)`, and the **one** red is **`G2sens`** — issue **1436**, whose own file records the identical actual value `{1 1 0 1 0 Entry Entry normal}`. The file's other named standing red, `GG9`, **passed**, as its paragraph predicts (cold-cache dependent). All twelve GR5 rows ran; **`GR5k` — click every cell in the grid, press OK, same `state_serialize` bytes as never opening the dialog — passed.** |
| **byte identity** | `STATE-ROUNDTRIP: 104 files, 0 differ` (crew), and independently: **no tracked `.state` file is modified** in the working tree. `GR5k` asks the same question from the GUI side and sabotage `c` reddens it, so it is not vacuous. ⚠ **CORRECTED 2026-09-13 by the NEXT crew, and the correction is the driver's to own: `GR5k` has a blind spot and this row overstated it.** `GR5k` presses OK on **`op`**, which has **no fields** — so it cannot see a `ase::ui::form_is_absent` bypass at all. It proves that browsing the grid with a cache live does not corrupt the bench; it does **not** prove the write-back rule still holds. Issue 1446's `GR6f` is the row that does, because it presses OK on `ac`, whose `sweep` resolves `default dec` at build time. `GR5k` was left as it is, flagged rather than changed. |
| **sabotage** | **Nine**, each restored by `cp` with a printed md5 match. `e` and `e2` are complementary (open-clear reds `GR5i` only; cancel-clear reds `GR5h` only). `c` and `f` each redden the **pre-existing** `GN7b`. |
| **T1** | ⚠ **DEFERRED, deliberately, and this is the price of running two crews.** Stage 8 task 1's uncommitted `src/ase.tcl` is in the tree, so a T1 taken now would be a number about **both** changes, and `CLAUDE.md` is explicit that a T1 number taken while another agent's suite is live is not evidence. T1 runs **solo**, once, when task 1 is collected, and covers both. |
| **ledger debts** | ⚖ R5 itself minted **no user-facing sentence** — verified by the driver's own grep: not one added non-comment line in the `src/ase_window.tcl` diff contains a string literal. **No `rule` debt, no `look` debt** (no new widget, nothing newly drawn). A `:0` suite debt was flagged by the crew rather than filed; the driver leaves it flagged, since `test_ase_dialogs` already runs on the dev display every pass. |
| **new debt** | **Issue 1446** + a `rule` debt, filed by the driver from the crew's residual: *a value the dialog remembered, and OK did not write*. |
| **receipt** | `receipts/24-r5-remember-per-type-edits.md` |

**Four corrections came back, and three of them are about testing rather than about R5.**

1. ⚠ **The obvious implementation is wrong, and an EXISTING row caught it.** Caching
   `chana_form_vals` wholesale for the outgoing type reddened **`GN7b`**: a `step` the user
   never typed was cached as the empty string, and the overlay then **deleted a stored
   `step 1n`**. The cache now stores only fields whose live value differs from an **as-built
   snapshot** taken when the form is built — which is also what makes byte-identity hold *by
   construction* rather than by luck, because an untouched field never enters the cache to be
   re-supplied. **A row written for a different feature is what stood between this and a
   silent data loss.**
2. **The driver's sabotage list was one short.** There are **two** merges — apply-side and
   save-side — and the save side had no row until the crew wrote `GR5l` (type under
   `▸ Advanced`, fold the section shut, switch type). This is variant 4 of the batch's four
   measured sabotage failures: *a sabotage missing from the generator entirely*.
3. **Two of the crew's own rows could not fail** (`GR5h`, `GR5i`): they closed the dialog
   without ever triggering a rebuild, so the cache was empty and they would have passed with
   every `clear` call removed. Variant 1 — *a row whose fixtures never disagree* — for the
   tenth time in this batch. Both now force a save first and carry a positive control.
4. **The `▸ Advanced` toggle had the same forgetting defect and nobody had reported it.**
   `chana_adv_toggle` rebuilds through `chana_show`, so folding the disclosure discarded what
   you had typed exactly as a radio click did. **Fixed for free** by putting the save inside
   `chana_show` rather than on the radio.

⚠ **And the residual is now issue 1446, not a paragraph in a receipt.** Two shapes survive:
**(A)** edit `tran`, click `ac`, press OK — the `tran` edit is dropped, which is the shape
⚖ R5 ruled and is recorded so the user can see what they chose; and **(B)** type into a field
behind `▸ Advanced`, fold it shut, press OK — remembered, not committed, because `chana_ok`
reads live widgets and the fold destroyed them. **(B) does not cross D4's line** — same type,
same row, one write — so it is a ruling worth putting, with the recommendation to fix it.


### 🔬 Driver verification taken WHILE the two crews held the code — 2026-09-13

A driver with no files to edit is not a driver with nothing to do. Three evidence files
were measured on **both** binaries (`/usr/bin/ngspice` 45.2 and the fork's 46+) while the
crews ran, each of them de-risking a stage that has not opened yet or checking a receipt
that has not arrived yet:

| file | what it settles |
|---|---|
| `evidence/meas-readback.md` | `meas` creates a **vector**, not a shell variable (`$name` is empty, `print name` answers). `meas … > file` **writes**, where `option > file` writes zero. The `meas` echo line is **binary-dependent** (six decimals against five) while `print` is byte-identical. A **failed** measurement is invisible to rc, to `$sim_status` and to stdout — `print` of it prints nothing at all — and a **deck-card `.measure` never becomes a vector**, so a `.control` producer cannot read one back. Written for Stage 8 task 1 and sent to that crew as it worked. |
| `evidence/sp-stage9.md` | `sp` runs on **both** binaries; plot `sp1 (SP Analysis)`, vectors `S_1_1`…`Y_1_1` and `NF`/`NFmin`/`Rn`/`SOpt` in ngspice's **mixed case**; the two preconditions are **refusals** because a missing port `exit(1)`s the whole deck and kills `op` with it; and **four SP benches already exist in this tree** under `ihp-sg13g2/`, carrying `portnum`/`z0`, whose committed `.state` holds only the four seeded rows because ASE-L cannot say `sp`. |
| `evidence/randomness-stage11.md` | The two random sources disagree about "no seed": netlist `agauss` differs every run, interpreter `sgauss`/`sunif` is **identical every run and across both binaries**, so an unseeded Monte Carlo loop in `.control` draws yesterday's sample. `.options seed=<n>` makes both reproducible **and agrees across the two binaries**, so a seeded campaign can have a committed golden. `agauss`/`unif` are netlist-only; `seedinfo` is not a command. |
| `evidence/binary-differences.md` | The synthesis ⚖ **R11** rests on: **four** measured differences between 45.2 and the fork — the `v(all)` phantom column beside a lone op save, the `meas` echo's six decimals against five, XSPICE event counts and times, and one `pss` return code — **and not one of them is a capability the older binary lacks**. Everything else measured agrees, including `sp`, `optran` to every digit, seeded randomness, all four `meas` facts, the `pss` segfault, `CKTncDump`, XSPICE and CIDER. |
| `evidence/events-and-trnoise.md` | **XSPICE is in both builds** (neither banner says so). Event data is a **separate namespace** — `display` is blind to it, `edisplay`/`eprint` are not — so the Outputs list, Value column and plotmap reconciliation cannot see a digital node at all. Event counts and times are **binary-dependent** (10 events against 11). And **the seed governs `trrandom` but does not reach `trnoise`**: three runs per binary give one number for `trrandom` and three different ones for `trnoise`, so a `trnoise` bench can never carry a value golden. |
| `evidence/pss-stage14.md` | ⚠ **`pss` with four arguments SEGFAULTS on both binaries** (rc 139, `Error: Strange behavior`); five or more survive. Worse than every class this batch has named — no guard, no salvage, and `op` dies with it. ⚖ R7's panel ships, and its emitter may never write fewer than five arguments. |
| `evidence/optran-and-ncdump-verified.md` | §10b's `9.999550e-01` **reproduces exactly on both binaries** — but *on by default* is not *used by default*: the same RC left alone answers exactly `1.000000e+00`, because Newton converges at rung 1. So the proposed OP-form sentence must be **conditional on the ladder having descended**. Also: `Note:` lines are **not all on one stream**, and `CKTncDump`'s table can arrive with **no starred node at all**. |

⚠ **One method correction came out of it.** The first attempt to reproduce §10b's number used
`option noopiter` alone and got `1.000000e+00`, which looks like a refutation and is not one:
gmin stepping succeeds at rung 2 and `optran` is never reached. The original measurement said
`.options noopiter gminsteps=0 srcsteps=0` and meant all three. **A claim is not refuted until
it has been re-run under its own stated conditions** — the same discipline that corrected issue
1438's defect-1 mechanism.


---

## Receipts from before Stage 0 — collected here so the ledger accounts for all of them

⚠ **Found 2026-09-12 by counting rather than remembering: three receipts existed on disk and
were referenced by the ledger nowhere at all.** They are not stage work, which is why the
stage table had no row for them — but "receipts collected onto the ledger" is the measure
this batch is run by, and 13 of 17 is not 17 of 17. They are accounted for here.

| receipt | what it records |
|---|---|
| `receipts/00-plan-authored.md` | 2026-09-09 — the plan was authored, verified against three lenses, and repaired. `doc/claude/ase_analyses_batch/` only; no file under `src/` touched and no suite row moved |
| `receipts/01-contract-pivot.md` | 2026-09-10 — the adapter pivot (D34–D37: ASE-L owns the SCHEMA, a per-simulator adapter owns CONTENT) folded into the documents, verified and repaired. Again documents only |
| `receipts/03-variant-support.md` | 2026-09-10 — the variant-support amendment, written against the user's own sentence: *"Most users who download our Xschem won't have **our** ngspice."* This is the origin of the probe-capabilities-never-branch-on-a-version-string rule that every stage since has been held to |

`receipts/02-r1-answered-salvage.md` and `receipts/04-dev-build-rebuilt.md` were already
cited above, in the rulings and baseline sections respectively.

~~**Running count: 17 receipts on disk, 16 collected, 1 in flight** (`16-stage-6-salvage.md`,
Stage 6 task 4).~~ *superseded — that count was true on 2026-09-12.*

**Running count, re-measured 2026-09-13 by counting rather than remembering: 24 receipts on
disk, 24 referenced by this ledger, ZERO gap.** Verified mechanically — every filename under
`receipts/` was searched for in this file, and none came back unreferenced. **Two more are
in flight**: Stage 8 task 1 (issue 1443) will be receipt **23**, and issue **1446**'s crew
will be receipt **25**; 24 is ⚖ R5's, collected above.

**Debt queue the same day: 163 `rule`, 59 `look`, 10 `suite`.** The rule count moved by one
this session, and it was the driver's own filing of **1446**. ⚠ These numbers are a
timestamp, not a standing fact — `owed.sh count` is the only honest source and it moves
every time anyone files.

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
| receipt | `receipts/08-stage-3-the-form-stops-lying.md` |

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

⚠ **"ONE COMMIT" FOR STAGE 4 IS REFUTED TOO — IT IS FIVE**, and the first of them is not the
stage's subject at all: `test_ase_preflight.tcl` is where this stage adds its rows, and T1 had
**never run it**, on either arm.

| landed | commit | subject | floors |
|---|---|---|---|
| `59513850` | **C1** | `fix(1421)` the preflight suite was never in T1, and 21 more ASE suites are not either | T1 61 → **62 cases** |
| `30a7be00` | **C2** | `feat(1422)` the tokens `netlist_map` throws away are exactly the ones a precondition needs | preflight 125 → 135 |
| `4adfda9a` | **C3** | `feat(1423)` preconditions become filters, not error messages | preflight 135 → 144 |
| `99224bc0` | **C4** | `feat(1424)` a precondition that destroys the run is a refusal | preflight 144 → 149 |
| `fa18442d` | **C5** | `feat(1425)` the precondition is said before the run, with its remedy | preflight 149 → **152** |

| | |
|---|---|
| status | **COMPLETE** — five commits |
| commit | `59513850` C1 · `30a7be00` C2 · `4adfda9a` C3 · `99224bc0` C4 · `fa18442d` C5 |
| T1 | Zero counted failures on every one, taken **solo**, at **62 cases** — and C1 is the reason that number means anything here at all |
| suites moved | `test_ase_preflight` **125 → 152** (sections PF223–PF226), floor raised four times. **No other suite moved a row**: core 348, simcaps 164, dialogs 265/37, persist 148/44, optier headless 103, re-run entire after every commit |
| sabotage | **twenty-four**, all verified to redden. ⚠ **Two survived first** — `precheck_worst`'s ordering (every fixture yielded one severity, so a lone `fatal` returns `fatal` under any ordering) and PF225d (its fixture had **no finding at all**, so it could not tell *refuses fatal* from *refuses anything*, and the sabotage was caught by two rows written for something else) |
| ledger debts | `rule 1423` and `rule 1425` filed — three precondition sentences with their fixes, the static-demotion suffix, and the pre-run advice line shape. **No look debt**: this stage is headless by construction and changes no pixel, exactly as the plan says |
| spec paragraphs rewritten | **None.** Same standing spec debt as Stages 2 and 3 |
| receipt | `receipts/09-stage-4-the-netlist-permits.md` |

⚠ **TWO ITEMS ARE DEFERRED AND NAMED RATHER THAN FAKED.** The **DISTO save-list rule** promotes
`saves_resolve` to `fatal` *when `disto` is enabled*, and `disto` is probe-only until Stage 6 — an
enabled `disto` row is refused by issue 1401's block long before a precondition is consulted. The
**precondition banner under the form** needs netlist *text*, which the dialog does not have and can
only obtain by calling `ase::netlist` — a side effect no dialog may have because a user opened it.
Both land in Stage 6, with the type and with the grid respectively.

⚠ **AND THE WIDEST FINDING OF THE STAGE IS ABOUT THE HARNESS, NOT THE FEATURE.** Of **29**
`test_ase_*` suites, **seven** were in T1. The other twenty-one all print `RESULT:` and no
`OVERALL:` — one cause, twenty-one times, `test_ase_cosim` at 341 checks among them. **Any
statement of the form "T1 at zero" covers eight of twenty-nine ASE suites.** Issue **1421** carries
the list, and says why they must be added in measured batches rather than in one commit.


### What Stage 4 learned that binds later stages

---

## Stage 5 — Single-plot analyses

*`tf`, `pz`, `sens` (DC): three registry entries, three `precheck` rows. **No writer change
at all** — each is one plot, so emission stays byte-identical.* New deck goldens only.
**Ruling: ⚖ R9.** Decisions: **D1, D30**.

⚠ **STAGE 5 IS THREE TASKS, NOT ONE COMMIT** — `tf`, `pz`, `sens (dc)` — and each is handed to its
own task-crew, which returns its own receipt. **This is also the first stage driven the way the
batch was set up to be driven**: the driver dispatches one task, the crew implements, tests and
sabotages it and writes the receipt, and the driver verifies, runs T1 solo and commits. Stages 0–4
were implemented inline by the driver, which is why `receipts/` shows no crew authorship before
this one.

| landed | task | subject | floors |
|---|---|---|---|
| `1e8e236e` | **T1** | `feat(1426)` the transfer function was listed and could not be chosen | core 348 → 360; simcaps 164 → 170; preflight 152 → 164; dialogs **display** 265 → 271 |
| `326fe7b1` | **T2** | `feat(1427)` the pole-zero analysis was listed and could not be chosen | core 360 → 376; simcaps 170 → 175; preflight 164 → 177; dialogs **display** 271 → 278 |
| *pending* | **T3** | `feat(1428)` DC sensitivity was listed and could not be chosen | core 376 → **391**; simcaps 175 → **180**; preflight 177 → **192**; dialogs **display** 278 → **285** |

⚠ **FOUR PLAN CLAIMS REFUTED BY THE TREE, and the first is structural.** `PLAN.md` §1c specifies an
`{build <proc>}` emit token and **Stage 1 never shipped it** — `ase::analysis_expand` implements
`@x` / `@x?` / `@x!` and nothing else, so a `{build …}` token emits as literal words. Composition is
therefore impossible today and `tf` ships **two** fields rather than the plan's five. `sens` needs
the same escape, so the decision belongs to this stage and not to a later one.

⚠ **`viewrank 0` IS WRONG AND THE MEASUREMENT SAYS WHY.** `xschem raw read <raw> tf` finds nothing:
`save.c`'s `read_dataset()` has six named `Plotname:` arms and then an exact `strcmp`. A viewrank
would make `plot_sim_type` answer `tf` and `plot_sim_type_reason` answer `{}` — *"there IS a
mapping"* — with the viewer pointed at nothing. The entry ships with **no viewrank**, which is the
same lesson D7k taught in Stage 2: a rank is a claim about RESULTS.

⚠ **THE CAPITALS ARE THE FORK'S.** `Transfer_function` / `v1#Input_impedance` are what the fork
writes; **apt 45.2 writes `transfer_function` and `v1#input_impedance`** — verified independently by
the driver. A case-sensitive reader is wrong on the binary a downloading user has. And only one of
the three vector names is a constant: the other two are templates carrying the row's own source and
node, so `plots`' `vectors` names a **proc**, not three literals.

⚠ **THE BEST FINDING IS ABOUT WHAT ngspice DOES NOT CHECK.** It validates the transfer function's
*input source* and aborts (rc 1); it does **not** validate the *output* at all. Measured by the
driver on `/usr/bin/ngspice`: `tf v(nosuchnode) V1` exits **0** and prints
`output_impedance_at_v(nosuchnode) = 1.000000e+00` — three plausible numbers and a vector **named
after the node that does not exist**. Hence two `needs` predicates rather than one. A related trap
was avoided by measurement: `i(L1)` *is* a real branch current elsewhere in ngspice, so *"an
inductor has no branch current"* would have been a **false reason for a correct rule**; the rule
rests on measuring `Transfer_function` across V/L/I/R instead.

⚠ **AND STAGE 4's STATIC DEMOTION IS RIGHT FOR ONE FINDING AND FALSE FOR ANOTHER IN THE SAME
PREDICATE.** A missing node is `blocked` → `caution` with the `.include` caveat, because an include
could supply it. A malformed output expression is `fatal` and carries no caveat, because **no
include can make `v mid` legal**. Measured against this tree's own `sim_status` guard: `tf x(mid) V1`
fires `quit 1` while `tf v(nosuchnode) V1` reaches the end.

⚠ **AND `pz` REFUTED THE PLAN'S OWN CITATION.** `PLAN.md` rests `pz_devices` on `pzan.c:92-128`'s
transmission-line check. Measured on both binaries: **`PZinit`'s check cannot fire for an LTRA at
all** — it stops at the first *name that is a compiled-in device type*, not the first that has
instances, so on any build with `tra` compiled in the LTRA arm is unreachable. A precondition resting
on an unreachable guard would have been a rule nobody could trigger.

⚠ **AND THE PLAN'S SINGLE `blocked` WOULD HAVE CALLED A SILENT WRONG ANSWER A REFUSAL.** `Y` and
`P` lines are **silently omitted from the pz matrix**: measured byte-identical poles, rc 0, against
the same deck with the line deleted. That is not a refusal — it is a result the user would believe.
Split into `fatal` (T/O/U) and `caution` (Y/P).

⚠ **A THIRD CASE OF STAGE 4's STATIC DEMOTION, WHICH NEITHER 1423 NOR 1426 HAD A NAME FOR.** A
finding of the form *"this deck CONTAINS X"* is **proved** by the static pass — an `.include` can
only ADD devices, never remove one — so it needs no `.include` caveat in either direction. Row
PF228h. The demotion is therefore not one rule but three: lower it when an include could supply what
is missing, keep it when no include can make the text legal, and skip it entirely when the finding is
about something already present.

⚠ **AND `sens` FOUND THE PREFLIGHT SUITE'S OWN ARTIFACT FROM A NEW DIRECTION.** A `sens` filter
that matches nothing produces **no plot at all**, at rc 0 — and the rawfile written holds only
`Plotname: constants / No. Variables: 12 / No. Points: 1`. That is byte-for-byte the artifact
`ase::preflight_gate`'s own refusal sentence describes: *"a raw file holding TWELVE MATHEMATICAL
CONSTANTS which reads back as a perfectly valid result."* Reproduced independently by the driver on
`/usr/bin/ngspice`. **The same silent-success artifact has at least two causes** — a save
expression that resolves to nothing, and now a filter that matches nothing — and only the first was
known.

⚠ **THE SENSITIVITY VECTOR NAMESPACE IS HIERARCHICAL** (`r.x1.ra`), which refutes APPENDIX
§2.10's three-row table as a flat-deck measurement and decides the shape of the filter predicate.
And §2.10's advice to *"write filters lowercase"* is **exactly backwards** under the fork's
`casemode=preserve`.

⚠ **`{build …}` WAS NOT BUILT, AND NOT ON COST.** `out_decompose` — the hook 1426 registered —
already takes `v(a)` / `v(a,b)` / `i(src)` APART, so the structured data the escape would compose is
already recoverable from the one verbatim token. And the DC entry has no `@modeargs` at all (the mode
is the literal `dc`), so the plan's `lin` restriction is **not a rule here**: Stage 6 can ship it as a
field constraint, `values {dec oct}`.

⚠ **AND `test_ase_core`'s OUTER `catch` CLOSES AT SECTION SI** — thousands of lines above Stage
5's sections. A sabotage reddened six rows and then **killed the file with no banner at all**, which
both banner readers score as a harness failure rather than as six named rows. The `catch` now covers
the Stage 5 section bodies alike, and the same sabotage re-run gives eight named failures **and** a
banner. A suite whose protection stops two thirds of the way down is a suite whose later sections
report differently from its earlier ones.

| | |
|---|---|
| status | **COMPLETE** — all three tasks landed, each by its own crew, each with its own receipt |
| commit | `1e8e236e` T1 · `326fe7b1` T2 · T3 pending |
| T1 | taken **solo** by the driver, 62 cases |
| suites moved | Across all three tasks: `test_ase_core` 348 → **391** · `test_ase_simcaps_0948` 164 → **180** · `test_ase_preflight` 152 → **192** · `test_ase_dialogs` **display** 265 → **285**, headless **37 unmoved**. Four existing rows moved, all expected and named: **AG1**/**AG2** (the offered list splits 5/6 now) and **EM7**/**CP6** (six probe-only types, not seven). **R1, AG3 and CP1–CP4 did NOT move** — the entry declares no `seed_enabled`, so the 104 committed `.state` files gain no `tf` row and stay byte-identical |
| sabotage | **one hundred and nine across the three tasks** (tf 21, pz 41, sens 47), all verified to redden. ⚠ **pz's survivor is the sharpest in the batch so far**: deleting the ground skip from `pz_nodes` left the WHOLE section green, because every fixture deck spells its reference node `0`. A deck spelling it `gnd` exposes it, and PF228m is that deck. ⚠ tf: twenty-one, twenty reddening a named row. ⚠ **One killed the suite instead of reddening a row** (S21, `insrc required 1→0`): `test_ase_dialogs` died at 65/271 because the row read `$top.chana.status` after an OK that now SUCCEEDS and destroys the dialog. Rewritten to read it inside its own `catch`; it now reds by name. ⚠ **One survived**: S9 passed against PF227h as first written, because **both** refusal sentences carry the user's own name, so *"the strings differ"* was satisfied trivially. The row now compares clause by clause |
| ledger debts | `rule 1426` — two field labels and six precondition sentences. ⚖ R9, batched with `pz` and `sens`. **No look debt**: `src/ase_window.tcl` is untouched and the form is built from the registry by code that already exists |
| spec paragraphs rewritten | none — same standing spec debt as Stages 2–4 |
| receipt | `receipts/10-stage-5-tf.md` — **the first crew-authored receipt in this batch** · `receipts/11-stage-5-pz.md` · `receipts/12-stage-5-sens.md` |


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

⚠ **STAGE 6 IS THE LARGEST STAGE IN THE DOCUMENT AND IS BEING DRIVEN AS TASKS.** Task 1 is the
⚖ **R3** reader seam and nothing else; the writer, the sidecar, reconciliation, `noise`/`disto`/
`sens (ac)` and checkpointed salvage are later tasks.

| landed | task | subject | floors |
|---|---|---|---|
| *pending* | **T1** | `feat(1429)` the Outputs Value column could not see three analyses' answers | core 391 → **417**; simcaps 180 → **190**; `test_ase_result_case` 28 → **31**; `test_ase_print_bracket_0167` 12 → **14** |

⚠ **⚖ R3 WAS ANSWERED ON 2026-09-12 — Option C, RATIFIED.** The user's words were *"both with a rule
is right, keep it"*. This row said *still unanswered* for as long as that was true; when the ruling
arrived, the recommendation wording was cleared out of the live artefacts in one pass — the issue
file, six comment blocks in `src/ase.tcl` and four suite headers — and `receipts/13-stage-6-reader-seam.md`
was **footnoted rather than rewritten**, because a receipt is a dated record. Option **C**
— named vectors from the rawfile, arbitrary expressions from the `print` log, with the rule *a row
whose expression names exactly one vector reads the raw; anything else reads the log*. `DECISIONS.md`
records R3 as **extending** the user's own ruling in issue **1243**, not reversing it.

⚠ **AND IT IS BUILT SO THAT ANSWERING A OR B DELETES A READER RATHER THAN INVALIDATING THE WORK.**
The rule is one proc, `ase::result_source`. Ruling A makes its body `return raw` and deletes
`result_probe_log` whole; ruling B makes it `return log` and deletes `result_probe_raw`,
`raw_spellings`, `raw_scalar_format` and `ase::raw_scalars`. The dispatcher partitions rows and hands
each reader a state containing only its own, so **neither reader knows the rule exists**. Row **RS3**
performs both rulings by stubbing that one proc, against a fixture whose log and rawfile carry
*different* numbers for the same name — so the row can say which reader answered.

⚠ **`PLAN.md` §6e's REASON FOR READING THE RAW IS WRONG, AND THE REAL REASON IS NOWHERE IN THE
BATCH.** §6e says the rawfile *"removes the case-folding ladder"*. It does not — the raw needs its
own fold, because the fork writes `v(Transfer_function)` where apt 45.2 writes
`v(transfer_function)`. The actual reason is one plot deeper: **`print` reads only the plot the
anchor stands in**, and issue 1243 anchors the prints on the `op`. Verified independently by the
driver on `/usr/bin/ngspice`: from the `tf` plot `print Transfer_function` answers
`5.000000e-01`; after `setplot op1` the identical command produces **no value at all**, while the
vector plainly exists one plot away.

⚠ **AND THE CREW'S FIRST REPORT OF THAT FACT WAS OVERSTATED — CORRECTED BEFORE THE COMMIT LANDED.**
It read *"no value, no warning, no error line"*. ngspice **does** emit
`Warning from checkvalid: vector <name> is not available or has zero length`, but on **stderr**,
where no reader in this tree looks. The defect is that nothing **parseable** reaches stdout, not that
ngspice is silent — and the distinction matters to the next person who goes looking for that warning
and finds it. Corrected in `src/ase.tcl`, the issue file and the receipt.

⚠ **THE VALUE COLUMN SHOWS NOTHING WHEN A RUN COMPUTED NOTHING, AND THE GUARD WAS NEARLY
ACCIDENTAL.** `constants` is excluded by name — but deleting that name test left `test_ase_core` at
ALL PASS, because the plot is **also** `Flags: complex` on both binaries and the accidental guard was
carrying the deliberate one. Verified by the driver against a real null-filter rawfile. Rows RD5c and
RV3b therefore use a `constants` plot flagged `real`, which is deliberately **not** what ngspice
writes. `i` is one of the twelve constants, so this is the difference between an empty cell and a
plausible number for a run that computed nothing.

| | |
|---|---|
| status | **LANDED** — task 1 of N |
| commit | `595ab274` |
| T1 | taken **solo** by the driver, 62 cases, zero |
| suites moved | `test_ase_core` 391 → **417** (RS, RD) · `test_ase_simcaps_0948` 180 → **190** (RV) · `test_ase_result_case` 28 → **31** (NCR) · `test_ase_print_bracket_0167` 12 → **14**. **Not one existing row moved.** ⚠ **The last two are NOT IN T1** (issue 1421's list of twenty-one), so the driver ran them standalone — a T1 number does not cover them and must not be quoted as if it did |
| sabotage | **31 respellings, 42 runs.** 23 reddened a named row first time; **six survived**, one killed a suite. ⚠ **The suite-killer is the sharpest**: a sabotage killed `test_ase_core` at row **P1** — a row a year older than this issue, 4,000 lines above where that file's outer catch closes. **A new seam made an old row fragile and nothing in the diff pointed at it.** RD14 now states the contract: `result_probe` must not raise for a state with no design cell, because `ase::run_done` calls it on every completion |
| ledger debts | `rule 1429` — three new sentences; the entry says explicitly that it **does not stand in for ⚖ R3** |
| spec paragraphs rewritten | none — same standing spec debt as Stages 2–5 |
| receipt | `receipts/13-stage-6-reader-seam.md` |

### Task 2 — the writer, the sidecar and reconciliation

Two `sens` rows in one deck both write `Plotname: Sensitivity Analysis`, and nothing in the
results file said which row wrote which. The literal cannot separate them **even in
principle** — two different analyses share it (`sens … dc` and `sens … ac`) — and write
order is `analysis_emit_order`'s rank, which moves under 0964's `op`-last variant. The
sidecar tells them apart by row index.

| | |
|---|---|
| status | **LANDED** — task 2 of N |
| issue | **1430** |
| commit | `7ea9f1dc` |
| T1 | taken **solo** by the driver, 62 cases, **zero** — `Total num fail: 0` on every case, and X7 did **not** red despite the other clone's GUI xschem being live throughout, which is issue 1402's load condition |
| suites moved | `test_ase_core` 417 → **453** (PM, GP, WK, RC) · `test_ase_preflight` 192 → **194** (PF218f2, PF218f3) · `test_ase_optier_0963` 103 → **105** (E5b, E5c) — forty new rows. **All three are IN T1**, so unlike task 1 nothing here needs a standalone run to be covered |
| driver's own re-run | core **453 ALL PASS**, preflight **194 ALL PASS**, optier **105** — taken by the driver on the engine arm through `run_suites.sh`, not read off the receipt |
| deck goldens moved | **one, in one file** — `test_ase_core.tcl`'s D1, with C4/C5 which compare against it. That is the whole of the "every deck golden moves" cost Stage 6 budgeted for: the sidecar record is the only line a single-plot deck gains, and every other rendered-deck assertion in the tree counts writes / `remzerovec`s / `.save` cards rather than comparing whole decks |
| fixtures moved | **one, without its row moving** — `em_bad_types` (row EM9) gained a valid `plots` key, because `analysis_schema_errors` learned a third refusal and the fixture would otherwise answer three errors, turning a row about one contradiction into a test of two unrelated checks |
| sabotage | **33 respellings + 9 re-runs, 65 suite runs.** 29 reddened a named row; **two survived** (S23, S29); **two killed a section** (S21, S24, both landing on the unnamed `PM0`); **three more reddened something while proving the row meant to catch them could not** (S05, S06, S14). Between them they bought WK2b, WK8, RC4b, a rewritten GP1, PM4's re-ordered fixture, and caught reads in WK4/WK2/PF218f3 |
| ledger debts | ⚖ **R9** — the second results file (`<cell>_ase.opinfo.raw`), which C61 shows is the only way to capture an `opinfo` plot without it winning over the real operating point |
| spec paragraphs rewritten | none — same standing spec debt as Stages 2–6 |
| receipt | `receipts/14-stage-6-writer.md` |
| ⚠ found while verifying | **issue 1431** — `test_cosim_golden_e2e`'s row **GE24** is red, deterministically, and was **not filed anywhere**. The driver caught it because PLAN Stage 6 requires `test_ase_cosim`'s RD1–RD11 re-proven and **neither cosim suite is in T1**. Proved older than this commit by re-running in a detached worktree at `595ab274` carrying this tree's own binary — same row, same six differences, same timestamps — so 1430 is innocent. **Not re-baselined**: a 1 ns VCD shift is equally consistent with a stale golden and a real regression |

**Five corrections to the plan, C60–C64.** The two that change what later stages may assume:

* **C60 — `PLAN.md` §6's `keepopinfo` list names `tf`, and `tf` produces no companion** on
  either binary; neither does `sens`. This is not pedantry, because the walk reads its
  length from the registry: a `tf` entry declaring two plots would have made every `tf` run
  **over-walk**, and an over-walk is **silent**. `setplot previous` past the first plot does
  not fail and does not wrap — it lands on ngspice's built-in `constants` plot and **stays
  there**, and the next `write` appends the twelve mathematical constants at rc 0, with the
  only trace a **stderr** warning where nothing in this tree looks. ⚠ **That is the third
  distinct route this batch has found to the `Plotname: constants` artifact**, after a save
  list resolving to nothing and a `sens` filter matching nothing.
* **C61 — the walk CANNOT capture an `opinfo` plot, and the fix cannot live on the reader
  side** as §6d proposed. `src/save.c`'s `read_dataset()` matches
  `strstr(lowerline, "operating point")` **above** its AC arm, so `AC Operating Point`,
  `Distortion Operating Point` and `NOISE Operating Point` all read back as `op`; and
  `attach_dbs` hands `xschem raw read` the file entire, so there is no per-plot lever there.
  Measured against a fixture made to **disagree** by an `alter V1 dc` between the two
  analyses, the companion **wins**: `v(mid)` reads 1 where the real operating point is 0.5.
  ⚠ **Capturing it would make Annotate Operating Point publish wrong numbers.** So
  `analysis_plots` predicts it, `analysis_captures` declines it, and the run says so.

⚠ **The walk ships with no production exerciser** (C64) and the receipt says so rather than
hiding it: every in-scope type captures exactly one plot, because `ac`'s and `pz`'s second
plots are `opinfo` and declined. It is driven by the issue-1429 **RS3 idiom** — stub the one
proc the emitter asks, keep the **unstubbed render of the same state beside it as the
control** — plus a real two-binary end-to-end run. **Stage 6d is what plugs production into
it**, via `noise` and `disto`.

⚠ **Two sabotages in two different files landed on an unnamed row.** S21 and S24 both killed
a section rather than reddening a named row, which is issue 1429's S31 one file over — the
third time in three tasks. The rule is now explicit in the receipt: **a sabotage campaign
owns the working tree while it runs**, and a floor taken during one is not a measurement.



### Task 3 — `noise`, `disto` and `sens` (AC), and the routing that had no destination

| | |
|---|---|
| status | **LANDED** — task 3 of N |
| issue | **1432** |
| commit | (filled at commit) |
| T1 | taken **solo** by the driver, 62 cases — ⚠ **NOT zero: one case red.** `test_ase_optier_0963` row **X7**, which is issue **1402** (the shipped bandgap bench does not converge reproducibly; the assertion is sound, the simulation is not). Re-measured rather than waved through: **ALL PASS (106) standalone before the T1 run, and ALL PASS (106) three more times immediately after** — four consecutive standalone passes bracketing one red, no code change between. 1402's tally read **3 of 3 reds under load, 0 of 17 standalone** when this block was written — ⚠ **and the very next T1, taken an hour later under the same conditions, came back GREEN**, so the corrected tally is **3 of 4 inside T1, 0 of 20 standalone**: load raises the probability, it does not decide the outcome. See task 4 below. ⚠ **And this run narrowed what "load" means**: the other clone's GUI xschem was live through the red run *and* all four passes, so an idle process is not the trigger — concurrent **simulation** is |
| suites moved | `test_ase_core` 453 → **476** (MP) · `test_ase_preflight` 194 → **210** (PF230) · `test_ase_simcaps_0948` 190 → **199** (NV) · `test_ase_optier_0963` 105 → **106** (E5d) — forty-nine new rows. **Every suite this commit moves is in T1.** `test_ase_cosim` is outside T1 but is **unmoved**, so nothing is owed a standalone run |
| driver's own re-run | core **476**, preflight **210**, simcaps **199**, optier **106** — taken by the driver on the engine arm, not read off the receipt |
| sabotage | **51 respellings, 48 reddened a named row, zero FATALs**, every restore md5-verified. **One survivor, S32, and it found a DEAD LINE** — a `string trimright` that could never run because the name is already trimmed twice. Deleted, and NV7 rewritten with one fixture per trim so S32r and S32s each redden it. One PATCH-FAILED on the crew's own anchor, re-run as S24r. ⚠ **S46 is the one that matters**: the over-walk reddens WK5, WK8, **MP7b**, E5b and E5c — the walk task 2 shipped stub-driven now has five production witnesses |
| ledger debts | ⚖ **R9** extended to ~19 sentences (`owed.sh add rule 1432`), to be batched with 1426–1430 |
| spec paragraphs rewritten | none — same standing spec debt as Stages 2–6 |
| receipt | `receipts/15-stage-6-multiplot.md` |

**Seven corrections, C65–C71.** The first is the one that would have shipped a silent
corruption, and it refutes **this batch's own previous task**:

* **C65 — `PLAN.md` 6b's `when {expr {start ne stop}}` is wrong, and task 2's receipt
  believed it.** Task 2 measured that `noise … lin 1` writes no `Integrated Noise` plot and
  read that as the `expr` form confirmed. Measured properly here: `noise … lin 1 1k 10k` has
  `start ne stop` and still produces **one** plot. The real rule is **more than one frequency
  point**. Shipping the `expr` form would have made every such run **over-walk** — which is
  silent, saturating on `constants` and appending the twelve mathematical constants at rc 0
  with every count agreeing. It now ships as a `{hook …}` and **the `expr` form is refused at
  validation** so it cannot come back.
  ⚠ **The driver's own task-3 brief repeated task 2's wrong claim.** It was caught because
  the brief also said *"re-measure it; do not take it from this brief"* — which is the only
  reason the error cost nothing. A brief is a starting point, never evidence.
* **C66 — the registry must list a multi-plot type's plots in WRITE order, not creation
  order**, refuting `analysis_plots`' own header comment. A creation-ordered registry passes
  every static row and **mislabels every real run** (row MP19).
* **C67** — `.options sqrnoise` renames both noise plots, so `select` must be a glob.
* **C68 — `sens … ac oct` is broken too, and nobody had measured it**: `count_steps` divides
  by `M_LOG2E` instead of `M_LN2`, giving 2 points where `ac` gives 5. The field therefore
  declares `values {dec}`, refuting receipt 12's `{dec oct}`.
* **C69** — the appendix's contributor names belong to the *other* plot, and there are
  **five** naming hazards, not the three carried in since Stage 6d was written.

**Two defects this put inside a user's reach, both now `fatal` preconditions:**

* ⚠ **`disto` SEGFAULTS — rc 139, no log, no rawfile** — when the save list resolves to
  nothing, reached through ASE-L's own `.save` dot cards. Guarded by `disto_saves`.
* ⚠ **One ticked output starves `noise`, `tf` and `sens`** (APPENDIX §7.5.2). Guarded by
  `vecsaves` — and it **reddened three of this suite's own fixtures**, which had been
  asserting about decks ngspice would have refused outright.

**End to end on both binaries:** four decks through `render_deck`, byte-identical sidecars
and `Plotname:` lists on the fork and apt 45.2, `reconcile_plots` → `ok` 5/5/5, **zero
`constants` records and no over-walk warning anywhere**.

⚠ **Two things this task surfaced that are NOT its own defects:**

1. **`Integrated Noise` reads back as `op`.** A noise-only results file answers
   `xschem raw read … op` with the noise *scalars*, and asking for `noise` returns the
   scalars rather than the spectrum. This is reader-seam territory and therefore ⚖ R3's;
   `noise` declares no `viewrank`, so nothing asks today. Recorded, not fixed.
2. **The display arm writes `~/.xschem/geometry`** — and this is **issue 1397**, filed
   2026-09-09, **not a new defect**. ⚠ **The crew reported it as unrecorded and that is the
   one claim in its report the driver had to correct**: no *receipt in this batch* had
   recorded it, but the issue tracker had, in detail, with two proposed fixes and a measured
   trap. What today adds to 1397 is a **new arm**: 1397's measurement was of headless suites
   missing `scratch.tcl`'s `::USER_CONF_DIR` redirect, whereas `run_suites.sh:125` runs the
   **display** arm as `--pipe -q --nolog --script` with **no `--nogui`**, so a real window
   opens and xschem saves geometry on close regardless of any per-suite redirect. That is
   1397's option 1 (per-suite) being structurally unable to cover this path, and its option 2
   (a scratch `HOME`, harness-wide) being the only one that does. Measured today at
   **19:49:00**, 8 196 bytes, inside the `optier` display run. **Both fixes remain the
   user's call and nothing was changed here.**

⚠ **One loop closed between driver and crew.** The driver's task-3 brief added a hazard the
task-2 crew had no reason to hit: in `read_dataset()` the `integrated noise` arm claims
**`op`** whenever it is the *first* `Plotname:` the reader meets, and reads as `noise` only
if a `Noise Spectral Density Curves` record preceded it — so file order decides the answer.
This task then measured the write order and found `noise dec 10 1 10k` writes **`Integrated
Noise` first** (`src/ase.tcl:16839`). The predicted hazard is the production case, which is
why the crew's finding (1) above reads the way it does. It is recorded against ⚖ R3's reader
seam rather than patched here.


### Task 4 — checkpointed salvage: a Stop keeps what the run had

⚖ **R1's answer implemented.** The user's ruling arrived with a requirement neither offered
option contained — *always salvage* — and this is it: a Stop now keeps what the run had
computed instead of discarding it.

| | |
|---|---|
| status | **LANDED** — task 4 of N |
| issue | **1433** |
| T1 | taken **solo** by the driver, 62 cases, **zero** — `Total num fail: 0`. ⚠ **X7 was GREEN in this run** with the other clone's GUI live exactly as it was for the red one an hour earlier, which is what corrected issue 1402's tally from *3 of 3 under load* to **3 of 4 inside T1**. Load raises the probability; it does not decide the outcome |
| suites moved | `test_ase_core` 476 → **523** · `test_ase_preflight` 210 → **218** · `test_ase_optier_0963` 106 → **108**. `test_ase_simcaps_0948` (199) and `test_ase_cosim` (341) **unmoved**. **Nothing this commit moves is outside T1** |
| driver's own re-run | core **523**, preflight **218** — taken by the driver on the engine arm |
| deck goldens moved | ⚠ **NONE — and that is a plan deviation in the opposite direction from the one predicted.** The task-4 brief warned the crew that `PLAN.md` §6f's *"the checkpoint lines ride in the SAME re-baseline as the sidecar line"* was already false, because issue 1430 had spent that budget on D1, and told it to expect D1 to move a **second** time. It did not move at all: D1 is `op`-only, and rows CK18/CK18b assert that a **below-floor** deck is byte-identical to one rendered with `ase_checkpoint 0`. 1430 spent the budget; 6f needed none |
| sabotage | **72 respellings in two passes**, 72/72 `RESTORED-OK` by `cmp`. Pass 1 (54) bought four code changes, so pass 2 (18) re-ran everything they moved plus four new ones. **Four survivors, every one of which bought a row or a deletion** — the `[2,50]` clamp (→ CK4b, stubbing `ckpt_n`), `ckpt_plan`'s two guards (→ CK27), and **two dead lines deleted**: `ckpt_rows`' `op_last` parameter and `ckpt_plan`'s `info commands` guard. One mis-specified anchor reported as `PATCH-FAILED` rather than quietly re-run, and an earlier whole-campaign attempt that failed 54/54 because **bash arguments cannot carry NUL** was reported rather than hidden |
| ledger debts | ⚖ **R9** — four new sentences, **two of which REPLACE sentences that read as defect reports for something the user did on purpose** |
| commit | `97974b42` |
| receipt | `receipts/16-stage-6-salvage.md` |

**The headline measurement, on both binaries, through ASE-L's own `render_deck`:** SIGTERM
six seconds into an 8,000,008-point transient → rc 143, `op` and `ac` **intact**, the plotmap
still 1:1, and **4,800,000 transient points kept**. Byte-identical across the fork and apt
45.2. No `ASE-RUN-COMPLETE`, no `.tmp` left behind.

**Nine corrections, C72–C80.** The one that matters most was found by a sabotage, not by
review:

* ⚠ **C80 — the loop's EXIT must be the FALSE branch, and the first cut SPUN FOREVER AT
  RC 0.** `.control`'s `if` takes the **false** branch for an *unevaluable* condition
  (measured for `<`, `>` and `>=`). With a save list resolving to nothing the transient never
  runs, so there is no `tran1` plot, `length(time)` is unevaluable, and a loop whose
  continuation was the true branch never terminated — at **exit code 0**, with nothing on
  either stream. It was found by the sabotage that deleted the eligibility floor, cost a
  **500 s suite timeout**, and was recorded as **rc 124 + FATAL** rather than as a gap in the
  log. ⚠ **The eligibility floor of 100,000 points is what had been keeping it out of
  reach** — nobody knew that until the sabotage removed the floor.
* **C73 — both directions of the plan's estimate error were silent.** Ten times high meant
  five wasted whole-rawfile writes *after* the run finished; ten times low left the last 90 %
  unprotected. Both at rc 0.
* **C74 — the `set` route rounds to six significant figures**, so a test against `cknext`
  reads a stop as "finished": an 8,000,008-point run wrote **zero** checkpoints, silently,
  and only above 1e6 points.
* **C72 — SV15's `tstop/tstep + 8` is wrong for three of the five shapes the shipped `tran`
  row can produce**, because `tstart` and `tmax` are advanced fields on it. The rule is
  `(tstop − tstart) / (tmax ?: tstep)`.
* **C79 — the arming block must sit ABOVE issue 1419's verbatim hatch**, and rows VB1/VB2
  were green while it did not.

⚠ **One finding handed on rather than fixed:** `tran` is starved by a save list resolving to
nothing (rc 1) — the `disto_saves` shape reaching a **fourth** type. Out of this task's scope
and recorded for whoever owns preconditions.

⚠ **C80 was re-measured by the driver independently, because the whole loop's correctness
rests on it.** A five-line deck on both binaries:

```
if length(nosuchvec) < 5   -> FALSE branch    (apt 45.2 AND the fork)
if length(nosuchvec) > 5   -> FALSE branch    (apt 45.2 AND the fork)
```

Both comparison directions take the false branch when the vector does not exist, on both
binaries. So a loop whose **exit** is the false branch terminates when `length(time)` cannot
be evaluated, and the inverse spins forever. The crew's claim holds as stated.

⚠ **A second 1402 data point, and it widens the row set.** Under the other clone's concurrent
load, `test_ase_optier_0963` reddened **X1 and X2 as well as X7** — where every previous
measurement named X7 alone. All three passed **ALL PASS (108) standalone, three times**. The
issue is about the bench not converging reproducibly, so more rows reading the same
simulation is consistent with it, but the row list in 1402 is now known to be incomplete.

### Task 5 — the four variant mitigations: a refusal turned back into a run

**The task carried one decision and it came back (c).** The brief named three
alternatives for `PLAN.md` §6g-1 — already satisfied by issue 1432's preconditions,
needs the `tran` case added, or genuinely needs the emission rule as well — because *a
precondition that refuses the run and an emission rule that lets the run proceed
correctly are different user-visible behaviours*. The answer is the third, and it
carries a consequence the brief did not anticipate: **1432's `vecsaves` is demoted from
`fatal` to `caution`.** Once ASE-L emits the `.save all` leader itself, a refusal on the
same condition is a **false** refusal, and this tree's rule is that a false refusal is
worse than a missed one. It is not deleted — it is the only thing that tells the user
their narrowing was overridden, and *nothing the deck contains may be unshowable in the
window* is a non-negotiable.

| | |
|---|---|
| status | **LANDED** — task 5 of N |
| issue | **1434** |
| T1 | taken **solo** by the driver, 62 cases, **zero** counted failures. `test_ase_optier_0963` was **GREEN**, standalone and inside T1 — issue 1402 did not flap in this run |
| suites moved | `test_ase_core` 523 → **558** · `test_ase_preflight` 218 → **229**. `test_ase_final` (82), `test_ase_simcaps_0948` (199), `test_ase_optier_0963` (108) and `test_ase_cosim` (341) **unmoved**. **Both moved suites are in T1**, so nothing this commit adds is outside T1's reach |
| driver's own re-run | **5/5 ALL PASS on the engine arm**, driver-run: core **558**, preflight **229**, final **82**, simcaps **199**, optier **108** |
| deck goldens moved | **NONE** — and the crew proved it is D47 holding rather than luck: `test_ase_core`'s `nfet_state` fixture *is* 6g-3's own shape (one saved output, `op` only), and the leader is withheld only because no suite probes a simulator. Row **WD6c** asserts both halves. The sabotage that made `analysis_resultvecs` default to `own` reddened **D1, D5, C4 and C5** — the goldens saying in their own voice that they are the control |
| sabotage | **53 applications, 53/53 restored** to the pristine md5, campaign set to abort on a restore mismatch. **One survivor closed** (the `op_analysis_enabled` guard, closed by priming the op-cards cache so WD6d's legs disagree — *a row whose fixtures never disagree cannot fail*, the **seventh** time in this batch) and **one section kill** reported as such rather than as a clean red. ⚠ **Pass 1's forty-four-row table was thrown away and re-taken**, because it had run against a tree in which the 6g-2 filter sat in `ase::cap_raw_plots` and 6g-3 therefore never fired at all |
| ledger debts | ⚖ **R9** — two new `caution` sentences, **one of which REPLACES a refusal**. No `look` debt: `src/ase_window.tcl` is untouched and nothing new is drawn |
| commit | `be23e3cb` |
| receipt | `receipts/17-stage-6-variants.md` |

**The driver re-took the load-bearing measurement independently**, from raw ngspice
decks with no ASE-L in the path, on `/usr/bin/ngspice` (45.2) and the fork
(`build-ver_50`), row-for-row identical on the two:

| deck | rc | `$sim_status` |
|---|---|---|
| `.save v(mid)` + `noise` / `tf` / `sens` | **1** | **1** — the guard fires, `RUN-FAILED` reaches the user |
| `.save v(mid)` + **`pz`** | **0** | **0** — ⚠ **the guard never fires** |
| `.save v(mid)` + `op` / `dc` / `ac` / `tran` / `disto` | 0 | 0 |
| `.save v(nosuchnode)` + `op` / `dc` / `ac` / `tran` | **1** | **1** |
| `.save v(nosuchnode)` + `disto` | **139 SIGSEGV** | — never reached |
| `.save all` + `.save v(mid)` + `pz` | 0 | 0, and `Plotname: Pole-Zero Analysis` really is written |

That confirms all three of the crew's refutations from an independent direction: **`pz`
is in the starved class and is its quiet member**, **`disto` is not in it**, and issue
1433's hand-off of *"`tran` is a fifth type"* understates a rule that is **universal** —
a save list resolving to nothing starves every analysis, and kills `disto` outright,
which is why `disto_saves` keeps `fatal` while the new `saves_resolve` is `caution`.
The driver also confirmed by count that **no committed bench can reach the widening**:
`git ls-files` finds **104** `.state` files and every one of them enables exactly
`op`/`dc`/`ac`/`tran` and nothing else.

⚠ **One driver correction to the issue file.** Its user-facing sentence said the silent
`pz` failure leaves *"a results file holding `Plotname: constants`"*. That is the
bare-`pz` probe's answer, not the answer an ordinary bench gets: with an `op` row ahead
of it — which is every committed bench — the second `write` emits **the operating point
again**, and the sidecar records it as the `pz` row's plot. Both were measured; the
issue file had quoted the weaker one. `constants` announces itself as junk, a duplicated
operating point does not, so the sentence was understating its own defect. Corrected in
place in `1434-*.md`, with the driver's transcript named; the receipt's own table was
already right and was left as the dated record it is.

**Named and not shipped, so the next stage inherits it rather than rediscovering it:**
§6g-2's *other* seam is `signal_list` in `src/wave_viewer.tcl` — one call, in a file
Stage 6's own *Files and procs* table does not name — and **that is where the
substantial user-visible half of 6g-2 still is.** The widening also has no surface of
its own: it reaches the user through the four-state grid and `preflight_gate`'s advice
block, and does not grey or mark the Save ticks it overrides. That is a one-row
follow-up for the next window stage, the same shape as issue 1432's `depends` note.

### Task 6 — the precondition banner, and a plan that contradicted itself

**Stage 4 deferred this item into Stage 6 and named the reason**: the banner needs netlist
*text*, which the dialog does not have and can only obtain by calling `ase::netlist` — *a
side effect no dialog may have because a user opened it*. The shipped answer is that the
dialog **never produces** a netlist; it **peeks at** facts that the run path *donates*, and
the fill site is `ase::netlist_in_place` — driver-verified as the **only** `xschem netlist`
call in `src/ase.tcl` (`:11477`), with every arm of `ase::netlist` ending there. *"The
banner only reads a netlist somebody asked for"* is therefore true **by construction**, not
by convention.

| | |
|---|---|
| status | **LANDED** — task 6 of 6, and **Stage 6 is COMPLETE** |
| issue | **1435** (and **1436** filed, not fixed) |
| T1 | taken **solo** by the driver, 62 cases, **zero** counted failures |
| suites moved | `test_ase_core` 558 → **598** (section BN, 40 rows) · `test_ase_preflight` 229 → **235** (PF233, 6) · `test_ase_dialogs` **display arm** 285 → **300** (GN, 15); its headless arm is unmoved at 37. ⚠ **46 of the 61 new rows are in T1** — `test_ase_dialogs` is in `hcases`, so T1 runs its *headless* arm and never the display arm where the fifteen `GN` rows live. Stated rather than glossed |
| driver's own re-run | engine arm **4/4 ALL PASS** — core **598**, preflight **235**, persist **44**, simcaps **199**. Display arm, `test_ase_dialogs`: **300 checks, 298 passed, and the two failures are EXACTLY issue 1436's two rows with exactly its recorded values** |
| deck goldens moved | **NONE**, and no `.state` file moved either — 104 committed, 0 modified. The banner **emits nothing**: it is pure Tcl over netlist text, starts no program, and reads no capability |
| sabotage | **32 respellings, 36 applications, 36/36 restored** by `cp` with an md5 compare — **zero survivors and zero section kills**. ⚠ **Pass 1's table was re-taken**: it produced 5 survivors and 4 suite kills, and every one of the nine was a defect in a **row**, not in the code. The kills all aborted `test_ase_core` at `invalid command name "ag_five"`, because a bare `dict get … why` on a `{state warm …}` answer raises inside the file's outer catch; every optional key now goes through `bn_get` |
| ledger debts | ⚖ **R9** (rule 1435 — three frames and the line shape) **and a `look` debt**, `ase_precheck_banner_1435`, filed at the moment the decision was taken and **before any suite was green**. Ledger 154/56/9 → **155/57/9** |
| commit | `8cab55ff` |
| receipt | `receipts/18-stage-6-banner.md` |

**⚠ THE DECISION THE BRIEF ASKED FOR CAME BACK (b), AND THE DRIVER CONFIRMED IT FROM THE
SOURCE RATHER THAN FROM THE CREW'S PIXELS.** `PLAN.md` Stage 4's *"there is no new pixel …
**No look debt is filed**"* paragraph is the **stale** half; its own *Files and procs*
table's `.note` banner is the live one. The plan's ground was that everything reaches the
user through `ase::ui::dialog_status` — i.e. through `$w.status`. Read statically at
`81312742`:

* `src/ase_window.tcl:4788` — `label $w.status -text {} -anchor w -justify left`. **No
  `-wraplength`**, so it is 0 and the label does not wrap. One 101-character precondition
  sentence took the dialog from **667 px to 856 px** in the crew's measurement, and the
  widget definition is why.
* `:5043` — `dialog_status` writes that same `$w.status`. A precondition sentence there does
  not *join* a capability sentence; it **evicts** one that is equally true.
* `:4812` — the shipped `$w.note` is `-wraplength 600`, at grid row **7**, `columnspan 2`,
  and **nothing else moved**. A genuinely new widget that grows downward instead of sideways.

⚠ **AND THE ROW THAT MEASURES THE EVICTION FOUND ITS OWN REFINEMENT.** `GN1`'s first cut
asserted *"occupied on every cell"* without touching the capability cache and **went red**:
by that point in the display arm the cache is **warm**, nine cells answer `measured`, and
the status line *looks* free. Both states are real, and the collision exists in the **cold**
one — which is what a user who has never pressed Detect has. **A surface that shares a
widget only sometimes is worse than one that never does**, because the eviction then depends
on whether the user pressed a button elsewhere in the dialog. `GN1` now clears and restores
the cache and says which state it measures.

**⚠ THE CONTENT HALF IS EMPTY, AND THAT IS THE FINDING RATHER THAN AN OMISSION.**
`ase::backend::ngspice` is **byte-unmoved** — driver-verified: the diff contains **zero**
lines mentioning it. Every sentence the banner prints was already minted in `ase::needs_eval`
by issues 1423/1425/1426/1427/1428/1432/1434. The task added three frames and nothing else.
That is **D34–D37 paying out**: a surface that is pure schema because the content was put in
the right place four stages ago.

**Eight corrections, C92–C99.** The one with the longest reach is **C96**: `ase::netlist_facts`
costs **76.5 ms over a 447 KB netlist**, and **no document in this batch treats it as a cost
at all**. That number is what decided the lazy parse, the memo and the donation. ⚠ **The
driver did not re-take it** — it is recorded here as the crew's measurement, because it is a
performance figure rather than a correctness one and nothing in this commit depends on its
exact value; a later stage that starts caching on the strength of it should re-measure first.

⚠ **ISSUE 1436 IS FILED, OPEN, AND THE DRIVER VERIFIED ITS ATTRIBUTION CAUSALLY.** The crew
proved *pre-existing* by restoring both sources from `git show HEAD:` and re-running — the
same method issue 1431 used. The driver took the stronger check, against the **committed**
tree at `81312742`: `sens` already carries `out filters mode sweep points start stop` with
`depends {mode ac}` on the last four (issue **1432** put them there), and `chana_show` at
that commit has **no `depends` handling at all**, so `$top.chana.form.stop` *must* exist and
`G2sens` *must* fail. The red is structurally guaranteed by a commit that predates this task.
Neither red is a T1 failure — T1 runs this file's headless arm only.

⚠ **ONE FILE WAS CREATED IN THE REPO ROOT AND REMOVED, AND IT IS IN THE RECEIPT RATHER THAN
QUIETLY CLEANED.** `BN4h`'s first cut dirtied the editor buffer without parking
`autosave_backup` and dropped a 74-byte `untitled~.sch` in the repo root. **Row C11 (issue
0609) caught it** — a row that exists for exactly that and had never fired. The row now parks
the knob; `git status` carries no trace.

**Still open, named rather than absorbed:** `signal_list` in `src/wave_viewer.tcl` (§6g-2's
other named seam, and the substantial user-visible half of 6g-2), a surface for issue 1434's
widening, and issue 1436's two rows. **Stage 7 — the options surface — is next**, and its
four-task split is recorded at the head of that stage's block below.

### ✅ The standing spec debt of Stages 2–6 is DISCHARGED — `1d12c12a`

Every stage from 2 onward recorded *"none — same standing spec debt"* against its
**spec paragraphs rewritten** row, and Stage 2's entry (above) named the reason: write
the section **once**, against a grid that can reach all four states, rather than twice.
Stage 6 is where that condition is met, so the debt was paid by the driver in the same
pass that collected task 5.

`doc/claude/specs/ase_l.md` gains one section, **The analyses subsystem (batch Stages
1–6)**, written as what *shipped* rather than what was planned, every claim attributed to
a measurement taken on **both** binaries: the schema/content rule and the
no-fallback-without-a-hook corollary; the eleven registered types and the four that are
seeded; the schema's seventeen refusals by name; the twenty-id precondition vocabulary and
why the **tier** is the decision rather than the detection; the plot sidecar and the
**silent over-walk** that made it necessary; ⚖ R3's answered reader rule; the
always-salvage checkpoint shape with the false-branch trap; and the two save-list classes.
Five traps are stated as rules rather than as history, because each cost this batch time —
*a row whose fixtures never disagree cannot fail*, *measure the exception before the
rule*, *read a precondition's stand-down list as a specification for the emitter*, *list a
reader's callers before filtering in it*, *check the quiet member of every set*.

⚠ **ONE DEVIATION FROM STAGE 3'S OWN PROMISE, RECORDED RATHER THAN QUIET.** Stage 3's row
said `### Choose Analyses dialog` would be *"rewritten in full in C4, when the form's final
shape exists to describe"*. It was **marked SUPERSEDED and kept** instead, with a pointer
to the new section — which is the convention `ase_l.md` already uses for its own v1 UI
sketch, and which keeps the 2026-07-21 sketch readable as the thing the grid replaced.
The shipped shape is described in full; it is simply described in the new section rather
than on top of the old one. The `P1–P5` phasing block was also pointed at this ledger,
with the reason to read the ledger before the plan.

### ✅ Stage 6's remaining work — DISCHARGED by task 6 (`8cab55ff`)

⚠ **This section was written while one task was still open, and it is kept rather
than deleted because it is the record of what the resume point WAS.** The banner landed
as issue **1435**; the plan contradiction it names below was resolved **(b)** — the
banner is a genuinely new widget, the *"no look debt"* paragraph is the stale half, and
a `look` debt is filed. **Stage 6 is COMPLETE.**

**`PLAN.md` §6a–§6g are all landed**: 6a/6b/6c in task 2 (**1430**), 6d in task 3
(**1432**), 6e in task 1 (**1429**), 6f in task 4 (**1433**), 6g in task 5 (**1434**).
What is left is not a `PLAN.md` §6 sub-item at all — it is the item **Stage 4 deferred
into Stage 6**, recorded above in the Stage 4 block:

> the **precondition banner under the form** needs netlist *text*, which the dialog does
> not have and can only obtain by calling `ase::netlist` — a side effect no dialog may
> have because a user opened it.

**That constraint is the whole of the task**, and it is Stage 6's **task 6**. Stage 4's
*other* deferred item, the DISTO save-list rule, is **discharged**: issue 1432 shipped
`disto_saves` as a `fatal` precondition and task 5 kept it there while giving the
universal case its own `caution` tier (`saves_resolve`).

⚠ **AND THE PLAN CONTRADICTS ITSELF ABOUT WHETHER THE BANNER COSTS A `look` DEBT.** Its
*Re-measure on the dev display* paragraph says *"there is no new pixel … No look debt is
filed"*; its *Files and procs* table, three paragraphs above, adds a **`.note`
precondition banner** to `src/ase_window.tcl`. Driver-measured 2026-09-12: `grep -c
'\.note\b' src/ase_window.tcl` is **0** — there is no such widget. The task-6 crew must
resolve that by measurement and say which half of the plan is stale, because filing a
`look` debt wrongly and omitting one are both costly and omitting is worse.

**Two follow-ups task 5 named and did not take**, carried here so they are not
rediscovered: `signal_list` in **`src/wave_viewer.tcl`** (§6g-2's other named seam, and
where the substantial user-visible half of 6g-2 still is), and **a surface for the
widening** — the `.save all` leader overrides the user's per-output Save ticks and
nothing greys or marks them. Both belong to whichever stage owns those files.

### What Stage 6 learned that binds later stages

---

## Stage 7 — The options surface

### 📋 Stage 7's task split, decided by the driver before the stage opens

`PLAN.md` §7 says *"One commit, or two"*. It is **seven sub-items and a 220-row measured
catalogue** — by a wide margin the heaviest section in the plan — and the two previous
stages both taught that a task whose scope spans a schema change, a content catalogue and
a new GUI surface produces a receipt nobody can verify in one pass. It is split into
**four crew tasks**, dispatched one at a time in this order:

| task | §items | why it is one task |
|---|---|---|
| **1** | **7a + 7b** | The catalogue (CONTENT, declared in `ase::backend::ngspice` and reached **only** through the hook, per D34) and `ase::opt_line` (SCHEMA, the one speller). They are one task because **7b is where 7a's columns become type errors**: T3, T4 and T5 die inside that `switch`, and a `cptype` vocabulary with no speller asserts nothing. Headless by construction |
| **2** | **7d** | The pre-deck class — the 26 variables reachable from neither `.options` nor `.control` — plus the inert list's three shapes. Its own task because the delivery mechanism is a **file ASE-L writes into the rundir** (⚖ R2's four conditions are requirements) and it carries **two refusals**, `sim_nospiceinit` and the shared-`set_netlist_dir` rundir. Nothing about it is a widget |
| **3** | **7c** | Finding one option among 220: live search, *changed-only* as the DEFAULT view, groups, the two scopes on two surfaces, the ⚠ badge on the 21 `results 1` rows, and the **live deck preview**. This is the whole GUI half and the **only** one of the four that draws a pixel — so it is the only one that can incur a `look` debt, and isolating it keeps that debt attributable |
| **4** | **7e + 7f + 7g** | Per-analysis scope is a GUI fiction and the form says so; post-run *requested vs effective* verification; and a `rules` clause reading `caps`. All three are about what ASE-L **claims** versus what the simulator **did**, and 7f is the channel that reports 7e's own honest limit — the restore that writes a default and thereby changes a global |

⚠ **Task 1 is the one to brief hardest.** The plan's own catalogue excerpt already contains
the correction that makes the point: **`gminsteps`' default is 1, not 10** —
`cktntask.c:120-122` sets `TSKnumGminSteps = 1` and the 10 in that same block is
`gminfactor`. Getting it wrong makes a shipped value read as *"changed"* in 7c's
default-only view, *"which is exactly how a real change gets hidden."* Every one of the
220 rows is an ngspice fact of that kind, and **none of them may sit in ASE-L's own
source**.

⚠ **And `defas` is the row to check the crew on.** `.options defas=<v>` sets the DRAIN
area: `cktsopt.c:111-113`'s `OPT_DEFAS` arm writes `TSKdefaultMosAD`, the same field the
`OPT_DEFAD` arm three lines above writes. A user who sets it today changes `defad` and
nothing says so. It is trap **T14**, and it is the shape of the *quiet member* rule Stage 6
paid for twice.

✅ **BOTH OF THOSE ARE DRIVER-VERIFIED IN THE NGSPICE SOURCE, 2026-09-13** — read in
`/home/analog/dev/ngspice`, not taken from the plan, because this batch has refuted a plan
claim in every stage so far. Here the plan is **right, in both places and at the cited
lines**:

```
src/spicelib/analysis/cktntask.c   tsk->TSKnumSrcSteps  = 1;
                                   tsk->TSKnumGminSteps = 1;    <- gminsteps default is 1
                                   tsk->TSKgminFactor   = 10;   <- the 10 is gminfactor

src/spicelib/analysis/cktsopt.c:108  case OPT_DEFAD: task->TSKdefaultMosAD = val->rValue;
                        :111         case OPT_DEFAS: task->TSKdefaultMosAD = val->rValue;
                                     ^^ the SAME field. `defas` sets the DRAIN area.
```

⚠ **Recording a plan claim that HELD is not decoration.** Nine stages of refutations make
the next reader distrust the plan uniformly, which is its own failure mode: a crew that
re-measures everything spends its budget on the rows that were already right. These two
are settled; the other 218 are not.


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

### Task 1 — the option catalogue and the one speller (§7a + §7b)

**The first task of the heaviest stage, and it found three shipped defects instead of
preventing future ones.** `PLAN.md` expected §7 to make the options surface safe. The
catalogue's first job turned out to be noticing that the emitter has been spelling
options **without a `cptype`** ever since there was no `cptype` to consult.

| | |
|---|---|
| status | **LANDED** — task 1 of 4 |
| issue | **1437** (and **1438** filed by the driver — see below) |
| T1 | taken **solo** by the driver, **63 → 64 cases**, **zero** counted failures. ⚠ **T1's membership changed in this commit**: `hcases` gains `headless/test_ase_options_1437`, so T1 now runs **75 more checks** than it did at `08774b2b` |
| suites moved | **none — a new suite instead.** `tests/headless/test_ase_options_1437.tcl`, **75 checks**, identical on both arms, registered in `run_regression.tcl`'s `hcases`, so **T1 covers all 75**. No existing row moved anywhere |
| driver's own re-run | **4/4 ALL PASS on the engine arm** — options_1437 **75**, core **598**, preflight **235**, simcaps **199** |
| deck goldens moved | **NONE**, and no `.state` file moved. ⚠ **`render_deck` is byte-unmoved** — driver-verified: not one diff hunk touches it. The catalogue and the speller exist; nothing yet routes through them, which is exactly why issue 1438 is filed rather than fixed |
| sabotage | **36 respellings + 4 re-runs = 40 applications, 40/40 restored** by md5, **zero kills, zero survivors**. Four survived pass 1 and **all four were rows whose fixtures never disagreed** — the eighth time in this batch. ⚠ **S31 is a new shape**: `set keepopinfo` reaches a task option on both binaries, so **no amount of running ngspice would have caught that respelling** — only the C source distinguishes them |
| ledger debts | ⚖ **R9** (rule 1437). **No `look` debt** — nothing here draws a pixel; §7c owns that. Ledger 155/57/9 → **156/57/9** |
| commit | `d2f4437a` |
| receipt | `receipts/19-stage-7-catalogue.md` |

**The reporting duty the brief imposed, and the crew met it.** A transcribed row and a
measured row are different kinds of evidence, and the count must not read wider than the
work:

| column | verified | how |
|---|---|---|
| `cptype` | **247 / 247** | extracted by script from `cktsopt.c`'s `OPTtbl` and every `cp_getvar`/`cp_getvar_policy` site |
| `site` | **247 / 247** | the `file:line` each row was read from |
| block A `help` | **57 / 57** | ngspice's own strings |
| block A `default` | **54 / 57** | from `cktntask.c` |
| `inert` | **16 / 16** | re-read in source |
| `phase` | **59 carry a non-`any` phase**; all five classes measured on both binaries with a named member | |
| **`group`, `scope`, `results`** | **0 / 247** | ⚠ **TRANSCRIBED** — *including the 21 rows §7c's ⚠ badge will rest on* |

⚠ **THAT LAST ROW IS THE ONE TO CARRY FORWARD.** §7c's badge marks the options that
change numbers, and **not one of those 21 is verified**. Task 3 must not treat `results`
as measured because the catalogue contains it.

**The driver re-derived the catalogue's own floor from the ngspice source**, independently
of both the plan and the crew:

```
OPTtbl rows                                   98      (matches APPENDIX §3.1)
  of which IF_SET (settable)                  57      (matches the plan)
distinct cp_getvar + cp_getvar_policy names  163      (162 without _policy)
union                                        220      <- the plan's floor, confirmed
overlap between the two sets                   0      <- "provably disjoint", confirmed
```

So **the plan's 220 is right**, and the shipped **247** is 220 + **27**, each of the 27
added because a *measurement* found a delivery class the floor has no member of. The
receipt says so at its own §"Blocks A + B are the plan's 220-row floor".

**Fifteen corrections, C100–C114.** The sharpest is **C103/C104**, and the driver re-took
it end to end on both binaries with an RC whose phase at 1 kHz is exactly −45°:

```
                              /usr/bin/ngspice 45.2      fork 46+
no units setting              vp(out) = -7.85398e-01     same     (radians)
.options units=degrees        vp(out) = -7.85398e-01     same     <- THE CARD DOES NOTHING
set units=degrees   (.control) vp(out) = -4.50000e+01    same     <- works
```

**A phase margin read off a deck that routed `units` to `.options` is wrong by 57.3×, at
rc 0, with nothing said.** And **`units` is not one of the 220 at all** — driver-verified:
it is neither an `OPTtbl` keyword nor a `cp_getvar` name; it is read at
`src/frontend/options.c:419` by a `va_name`/`CP_STRING` comparison, a third mechanism the
floor's two sets cannot see. The plan's own §7a catalogue excerpt lists it as a row of a
floor that does not contain it.

⚠ **ISSUE 1438 IS THE DRIVER'S, AND IT EXISTS SO A USER CAN FIND IT.** The crew named
three silent wrong answers live in the shipped tree, measured them on both binaries, and
correctly did **not** fix them — the repair is §7d/§7e's. But they were recorded only
inside a catalogue receipt and inside 1437, which will close as *"the catalogue shipped"*.
A user asking *"why is my W wrong?"* would never reach either. So they are filed under one
number, with one root cause:

1. ⚠ **Five committed benches ask for `wnflag` and none of them gets it** — driver-verified
   by `git ls-files`: five `.state` files, all `{name wnflag value 1}`, all the user's own
   sky130 benches. `render_deck` spells a stored `1` as a **bare card**, and `wnflag` is
   read at **`CP_NUM`** at three sites (`inpgmod.c:268`, `inp.c:2828`, `inpcom.c:990`) —
   all three confirmed by the driver at those exact lines. A `CP_BOOL` cannot answer a
   `CP_NUM` read, **and** `inpcom.c:990` is inside `inp_get_w_l_x()`, called from
   `inp_readall_cards()` at `:1535`, i.e. **during card reading, where no `.options` card
   can reach it at all.** The user asked for W per finger and has been getting W total.
2. **A valued option stored as `1` becomes a bare card** — `.options maxord` leaves
   MaxOrder at **2**. Driver-corroborated: `cktsopt.c:314` declares `maxord`
   `IF_SET|IF_INTEGER` and the `OPT_MAXORD` arm reads `val->iValue`.
3. **A valued option stored as `0` is dropped entirely** — `.options gminsteps=0` disables
   gmin stepping; emitting nothing leaves it at 1.

⚠ **`PLAN.md` §7b predicted defect 3 as *"this batch's own defect inside its own
antidote"*.** It is **older than the prediction** and it is in the **emitter**, not in the
speller the prediction was about.

**What task 2 inherits, and what it must budget.** The 34-row pre-deck group is already a
predicate, both its doors are computed and spelled, the sixteen inert rows carry their
reasons, and `ase::state_option_delivery` already names every stored option that cannot
reach the simulator. What §7d has to build is the **delivery** — `spiceinit_write`,
`run_cmd`'s `-D` arm, ⚖ R2's four conditions as requirements, and the two refusals.
⚠ **And it owns a re-baseline this task did not pay**: `test_ase_simreg_0931`'s six rows
are expected to move *"the first time `-D` is emitted for an option"*, and nothing emits
`-D` yet — the suite is **ALL PASS (111)** here.

### Task 2 — the pre-deck class, and a defect that turned out not to need it (§7d)

**The task was briefed to fix `wnflag` through the pre-deck door. It fixed `wnflag` and
refuted the door.** Issue **1438** — the driver's own filing — argued that `wnflag` was
*"the wrong door twice over"*, and the second half of that argument was wrong.

| | |
|---|---|
| status | **LANDED** — task 2 of 4 |
| issue | **1439**. ⚠ Also: **1438 CORRECTED** (the driver's, in place, appended not rewritten) and **1440 FILED** (the driver's, below) |
| T1 | taken **solo** by the driver, **65 cases**, **zero** counted failures |
| suites moved | **new** `tests/headless/test_ase_predeck_1439.tcl` **78 checks**, registered in `hcases` → **T1 covers all 78**. `test_ase_simreg_0931` 111 → **117** (six new rows, section P). `test_ase_options_1437` **75**, unchanged in count with **seven rows re-baselined**. `test_ase_core` 598, `test_ase_preflight` 235 unmoved |
| driver's own re-run | **5/5 ALL PASS on the engine arm** — predeck_1439 **78**, options_1437 **75**, simreg_0931 **117**, core **598**, preflight **235** |
| deck goldens moved | **NONE**, and no `.state` file moved — even though `render_deck`'s option loop now consults the door and the speller, because no committed bench stores an option the change respells |
| sabotage | **35 respellings, 76 applications** (35 + 3 survivor re-runs + 35 on the final tree + 3 more), **76/76 restored** by md5, **zero kills, 35/35 named reds, zero survivors**. ⚠ **S21 is a shape this batch has not seen**: its fixtures *did* differ and the row still passed, because the row asked about **position** where `set` is last-writer-wins. That is the ninth variant of *a row whose fixtures never disagree*, and the first where they did |
| ledger debts | ⚖ **R9** (rule 1439), **plus rule 1440** (the driver's). Ledger 156/57/9 → **158/57/9**. **No `look` debt** — nothing here draws a pixel; §7c owns that |
| commit | `98beb2b5` |
| receipt | `receipts/20-stage-7-predeck.md` |

**⚠ THE `wnflag` ANSWER, AND IT CORRECTS THE DRIVER'S OWN ISSUE.** Two of the three
`wnflag` read sites are **dead code**. Driver-verified in the ngspice source, because this
is a correction to a claim the driver made:

* `src/frontend/inpcom.c:990` reads `wnflag` into `int wnflag;` declared one line above —
  and **the name appears nowhere else in the next 110 lines**. A dead local.
* `src/frontend/inp.c:2828` sits in `rem_unused_mos_models()` at `:2685`, inside
  **`#ifdef REM_UNUSED`** opened at `:2683`. `grep -rn 'define REM_UNUSED' src/` returns
  **nothing**.
* `src/spicelib/parser/inpgmod.c:268` is the only live read, and **ngspice's own comment at
  `:294-295` says an `.options` card reaches it**: *"We do have nf, but no wnflag on the
  instance. Now it depends on the default wnflag **or on the `.options wnflag`**."*

So `wnflag` is a **`deck`** option. **Issue 1438's defect 1 is issue 1438's defect 2** — a
valued option written as a bare card — and the speller fixes it with no pre-deck delivery
at all. `ase::state_option_delivery` over the 104 committed `.state` files goes
`6 {acct list wnflag} 5` → **`1 {acct list} 0`**.

⚠ **What the driver did NOT re-take: the behavioural delta.** The crew measured
`.options wnflag` → `@m1[vth]` 0.9889 / `i(vd)` −1.017 mA against `.options wnflag=1` →
0.5889 / −1.737 mA, **71 %**, on both binaries. The driver's own scratch probes used an
**unbinned** model and `wnflag` only acts where a model is **binned**, so they showed no
difference — consistent with the source, not contrary to it, and **not** an independent
confirmation. The C-source evidence above is the driver's; the 71 % is the crew's.

**⚠ AND THE LESSON IS THE DRIVER'S TOO.** Issue 1438's mechanism was assembled from three
`grep` hits read as three live reads. Two were dead — one a dead local, one behind a macro
nobody defines — and **the dead one carried the whole argument**. *Before building a
defect's explanation on a call site, establish that the site executes.* Recorded in 1438
itself, appended rather than rewritten.

**⚠ THE RE-BASELINE THE DRIVER BUDGETED DOES NOT HAPPEN (C119).** `PLAN.md` expects
`test_ase_simreg_0931`'s six rows to move *"the first time `-D` is emitted for an option"*,
and this task is the first `-D` emitter — yet the suite is **still ALL PASS at 111** after
the change, because A2/B5/B6/B11/B12/D4 all build the command from an **empty** state, so
the `-D` arm contributes nothing. That is 0931's compatibility contract **holding**, which
is a better outcome than a re-baseline. The crew pinned the arm with **six new rows in a
new section P** rather than leaving the absence unasserted — which is this batch's own rule
that *a row explaining why nothing moved is the row to sabotage first*.

**⚠ AND ⚖ R2's CONDITION 4 IS NARROWED BY MEASUREMENT, WHICH IS THE USER'S TO SEE.**
`PLAN.md` §7d says *"every pre-deck option **and** the entire campaign mechanism are refused
when `-n` is in force"*. Measured: **`-n` closes the FILE and not `-D`.** The two doors are
not refused together, so the refusal is narrowed to the file half. R2 was answered **yes
with four conditions** and those conditions are requirements; a measured narrowing of one
of them is carried on the rule queue as part of **1439** rather than applied silently.

**Also refuted:** `[R-M7]`'s *"`source` loses the user's variables"* is **conditional on the
filename** — the copy is still required, for a sharper reason, which the receipt names.

⚠ **ISSUE 1440 IS THE DRIVER'S, AND IT IS THE THIRD TIME THIS STALL HAS BEEN MEASURED
WITHOUT EVER HAVING A NUMBER.** The crew's display-arm run reproduced
`test_ase_optier_0963`'s hang: **91 of 108 rows, stops after row N3, rc 124 at 260 s.** The
first sighting was 86 of 103 rows, also after **N3**, and it cost **8 h 07 m** before issue
**1403** bounded it. ⚠ **The suite has grown five rows and still stops after N3**, so the
stopping point is a property of what N3 leaves behind rather than of where the suite runs
out of something. 1403 makes the stall a *named outcome*; it does not stop it, and nothing
has forced the race deterministically as `CLAUDE.md` prescribes. Three things each hid it:
T1 runs the headless arm only, it has been conflated with issue **1402**'s convergence flap
(a different arm, and one that reds rather than stalls), and since 1403 a `TIMEOUT` line
reads like the harness working — which it is. The suite is not. Filed with three costed
options and `owed.sh add rule 1440`.

### Task 3 — finding one option among 247, and the badge nobody had measured (§7c)

**The brief named one outcome it would reject — a badge asserting *"this option changes
your numbers"* on the strength of a transcription — and the crew answered it by measuring
the column instead.** All 22 `results` rows, both binaries, each on a deck built to make
its own documented mechanism fire.

| | |
|---|---|
| status | **LANDED** — task 3 of 4 |
| issue | **1441** |
| T1 | taken **solo** by the driver, **66 cases**, **zero** counted failures |
| suites moved | **new** `tests/headless/test_ase_optsheet_1441.tcl`, registered in **`hcases` AND `dcases`** — **62 headless + 87 on `:99` = 149 checks into T1**. `test_ase_options_1437` **75**, one row re-baselined (BR6). Nothing else moved |
| driver's own re-run | engine arm **5/5 ALL PASS** — optsheet **62**, options_1437 **75**, predeck_1439 **78**, core **598**, preflight **235**; and the **display arm** of the new suite at **87**, taken separately |
| deck goldens moved | **NONE** — and that is the interesting part, because `render_deck`'s option loop was **lifted out whole** into `ase::opt_deck_plan`, which the emitter now calls and the preview reads. Output byte-identical |
| sabotage | **44 respellings, 140 applications** (44 + 44 + 8 targeted + 44 on the final tree), **140/140 restored, ZERO KILLS**, and on the final tree **44/44 redden a NAMED ROW with zero survivors**. Twelve of the 44 reproduce a claim the plan, a dossier or this tree's own code makes. ⚠ **S26 is a shape new to this batch: a guard no caller could reach** — `opt_preview` could not be handed both file lines and a refusal, so a branch existed that nothing could enter. ⚠ **And comparing the two campaign passes caught two sabotages reddening the WRONG row** (S21, S22), which a single pass would have scored as clean reds |
| ledger debts | ⚖ **R9** (rule 1441 — badge phrases, four preview slot labels, column headings, detail-line verdicts, finder-bar labels, one new `units` help sentence) **and a `look` debt**, `ase_options_sheet_1441`. Ledger 158/57/9 → **159/58/10** — the driver added the third: a **`:0` suite debt**, `test_ase_optsheet_1441`, because this is a new WINDOW whose suite has only ever run on Xvfb `:99` and `CLAUDE.md` asks for one `:0` run before a GUI feature is called done. A suite debt clears itself on a pass; the `look` debt does not |
| commit | `f91c36ae` |
| receipt | `receipts/21-stage-7-finding.md` |

**⚠ THE HEADLINE: THE BADGE WOULD HAVE LIED ABOUT THREE ROWS, AND THE REASON IS A
TRANSCRIPTION ERROR ONE LEVEL UP.** `warn=1` takes a deck from **0 to 5 SOA messages with
every printed value byte-identical**; `maxwarns=2` takes 5 messages to 2 and changes
nothing; `num_threads=1` is identical to the default. All three are **diagnostic printers**.
`evidence/hidden-vars.md` §2.1's own R/P column already marks all three **P** — so the
catalogue had transcribed the **section title** (*"Group R — the 21 that change numerical
results"*) rather than the **column inside it**. ⚠ **A heading is not data**, and that is
the shape to remember: the error was not in reading a fact wrongly but in reading a
container's label as if it were its contents.

**Driver's own check, on both binaries:** a deck with `.options warn=1` against the same
deck without it — **every printed value byte-identical**, `v(d)`, `v(dd)`, `i(vd)`, `i(v2)`.
⚠ **The other half was NOT reproduced**: the driver's probe model carries no SOA limits, so
it produced no SOA messages to count. The *"0 → 5 messages"* half is the crew's; **the "no
value moves" half — which is the half the badge turns on — is the driver's.**

**What was done with each of the three unverified columns, because the answer differs:**

* **`results` — MEASURED, 22 of 22.** 9 confirmed, **3 refuted**, 10 unmeasurable on this
  box. `ase::opt_results` is therefore **three-valued**, and a row with no evidence shows
  `⚠ MAY CHANGE RESULTS — UNVERIFIED` **on the surface**. **No badge anywhere asserts a
  transcription.** That is exactly what the brief asked for and it was answered by
  measurement rather than by hedging.
* **`scope` — cross-checked, and then designed around.** Zero set-level disagreements over
  27 shared rows; `dyngmin` and `chgtol` corrected. It **cannot** be measured — there is
  nothing in ngspice to measure a GUI grouping against — so the design carries the risk
  instead: **the global surface offers every row**, so a wrong scope costs a *shortcut*,
  never an *option*. Row SC1 asserts that over the whole catalogue, which converts
  `PLAN.md`'s *"an option shown in the wrong scope is worse than one not shown"* from a
  warning into a structural impossibility.
* **`group` — still 0 / 247, and the receipt says so in as many words.** 114 of 205
  taggable rows disagree with their source, mostly because the catalogue's taxonomy is
  better than the dossier's. One real **category error** fixed: `numerics` was the
  `results` column wearing a group's clothes, and all 20 members were re-filed.

**Eleven corrections, C123–C133.** Two bind later work:

* **C126 — §7c-2's *"it is a filter, not a feature, because the catalogue carries
  `default`"* is wrong in the direction that HIDES A REAL CHANGE.** **Storage** decides
  visibility; `default` decides only the *annotation*. A view built the plan's way would
  drop a stored row whose value happens to equal the default — i.e. exactly a setting the
  user made on purpose.
* **C127 — most of the catalogue cannot say what "unchanged" means.** A changed-only view
  over such a catalogue is a different object from the one the plan describes.
  ⚠ **THE NUMBERS IN THIS ROW WERE WRONG AND ARE CORRECTED HERE, 2026-09-13.** It read
  *"only 65 of 247 rows carry a default at all, and 64 carry help"*. Task 4's **C134**
  caught the transposition and the driver settled it by counting through the shipped
  readers (`ase::sim_option_names` → `ase::sim_option_entry`, in-tree binary):
  **247 rows, `default` 60, `help` 66.** So `default` was never 65 — **65 was the `help`
  count**, attached to the wrong column, and `help` has since moved 64 → 65 → 66 as two
  tasks added sentences. ⚠ **This is the third time in Stage 7 that a number right about
  one column was attached to another** (1441's C123 and C130 are the others, and C123 is
  the one that would have put a false badge on three rows). The driver repeated the wrong
  65 in a report before task 4 caught it.

⚠ **AND C133 IS THE ONE TO CARRY INTO EVERY LATER MEASUREMENT.** The crew's own probe
harness hit the vacuity defect: **nine "no difference" results came out of an extractor
that was returning nothing at all.** A row whose fixtures never disagree cannot fail — and
a *measurement* whose extractor returns nothing cannot disagree either. **A measurement
needs a positive control exactly as a row does.** This batch has now met that defect in
test rows nine times and in a measurement harness once; the second is worse, because a
measurement is what settles a dispute between a plan and a tree.

⚠ **ONE DRIVER CORRECTION.** The receipt's floor paragraph said *"so T1 covers all 82"*,
and **82 is not a number this suite produces** — driver-measured, both arms, **62 headless
and 87 on `:99`**, i.e. **149**, which is what the crew's own summary says elsewhere. The
same stale pair had reached `tests/run_regression.tcl`'s new comment as *"80 checks against
55"*. The comment is **live documentation and was corrected in place**; the receipt is a
dated record and was **footnoted**. The suite counts themselves were always right; only the
sentences about them were wrong.

### Task 4 — scope, verification and the four rules (§7e + §7f + §7g) — STAGE 7 COMPLETE

**The last task of the heaviest stage, and it found that half of §7f's recipe writes
nothing.** The plan's mandatory verification leg is two lines; one of them is inert on
both binaries, and the half that was going to report *"you asked for X, the simulator is
using Y"* would have diffed clean for ever.

| | |
|---|---|
| status | **LANDED** — task 4 of 4. **Stage 7 is COMPLETE for §7a–§7g** |
| issue | **1442** |
| T1 | taken **solo** by the driver, **67 cases**, **zero** counted failures |
| suites moved | **new** `tests/headless/test_ase_effective_1442.tcl`, **92 checks**, identical on both arms, registered in **`hcases` only** — and the file records *why not `dcases`*: its UI section drives two **pure** procs and creates no widget, so the display arm would be a weaker measurement of the same thing rather than a bigger one. `test_ase_core` **598**, `test_ase_preflight` **235**, `test_ase_options_1437` **75** — each unchanged in count with **one deliberate re-baseline** (D1's inline golden deck, PF230f `fatal`→`caution`, RS2) |
| driver's own re-run | **6/6 ALL PASS on the engine arm** — effective_1442 **92**, core **598**, preflight **235**, options_1437 **75**, optsheet_1441 **62**, predeck_1439 **78** |
| deck goldens moved | **NO COMMITTED GOLDEN FILE, and no `.state` file.** One *inline* golden inside `test_ase_core` (D1) was re-baselined deliberately, which is a different and smaller thing and is named as such |
| sabotage | **41 respellings, 82 applications, 82/82 restored, zero kills**; on the final tree **41/41 redden a NAMED ROW with zero survivors**. Five survived pass 1 and **all five were one family** — a row asking a coarser question than the code answers — each closed with a new row. ⚠ **S24 was missing from the generator entirely**, and it was the brief's own *"establish exactly where the new lines may go without moving any anchor, and assert it"* case; when finally run it **survived**, because the row's bound admitted the plan's wrong placement. It is now bounded by the pre-deck block |
| ledger debts | ⚖ **R9** (rule 1442, seven groups of new copy) **and a `look` debt**, `ase_effective_1442`. Ledger 159/58/10 → **160/59/10** |
| commit | `1a5fefec` |
| receipt | `receipts/22-stage-7-effective.md` |

**⚠ THE HEADLINE, AND THE DRIVER RE-TOOK IT WITH A POSITIVE CONTROL IN THE SAME DECK.**
`PLAN.md` §7f asks for `option > <cell>_ase.effective` followed by
`set >> <cell>_ase.effective`. Measured by the driver, both binaries, one deck, three
redirections:

```
echo CONTROL-ECHO-WORKS > ctl.txt     ->   19 bytes    <- the positive control
option                  > opt.txt     ->    0 bytes    <- §7f's FIRST LINE
set                    >> setv.txt    ->  434 / 444    <- the half that works
```

`.options reltol=0.05` was in the deck and `opt.txt` does not contain the string `reltol`.
**The `echo` proves redirection works in that `.control` block**, so the zero is `option`'s
and not the shell's — which is precisely the positive control task 3's C133 said every
measurement needs, applied one task later to the measurement that most needed it. ⚠ **And
it matters more than an ordinary refutation**, because §7f is the **only** way ASE-L can
learn that an option name did not land: there is **no error channel** for a misspelled
option on this route, and the `Error: unknown option %s - ignored` branch at
`inpdoopt.c:74-78` is reached by neither.

**⚠ THE §7g RULE-1 DECISION CAME BACK (c), AND IT IS BETTER THAN EITHER OPTION THE BRIEF
OFFERED.** The brief gave (a) keep the `sens_klu` refusal, (b) suppress `klu` for the whole
run and say so, or (c) argue for something else. The crew took (c): **scope the suppression
to the ANALYSIS** — `option klu=0` before the AC `sens`, `option klu` after — which is
§7e's own mechanism and needs **no new spelling at all**.

The argument against (b) is the one the brief itself raised and the crew sharpened: what
gets suppressed is **the user's own `klu` setting**, and (b) drops it for *every* analysis
in the deck — yet KLU is chosen for speed on exactly the circuits that carry several
analyses, so (b) is a **larger** unasked-for change than 1434's save-list widening. (c)
changes only the solver used by the one analysis that would otherwise crash. Measured on
both binaries on the deck shape ASE-L writes: **rc 139 SIGSEGV → rc 0**, solver per job
KLU / sparse / KLU, and the `sens` numbers **byte-identical** to a deck that never asked
for KLU.

⚠ **And the user can never reach the SIGSEGV, because the `fatal` is DEMOTED rather than
DELETED.** `ase::analysis_suppresses` requires **both** that the adapter names the option
**and** that the speller can write the off-line; a backend failing either still gets the
refusal. Row **RU2** builds that world by removing the hook and asserts the `fatal` returns.
That is the *"a backend with no hook gets NO fallback content"* rule producing a safety
property rather than an absence.

**Eleven corrections, C134–C144.** Two are about this stage's own arithmetic and one is
about its plan:

* **⚠ C134 — the `default` column answers for 60 of 247 rows, not 65, and 65 was the `help`
  count.** The driver settled it by counting through the shipped readers on the in-tree
  binary: **247 rows, `default` 60, `help` 66**. So task 3's C127 had the two columns
  transposed, the driver repeated the wrong 65 in a report, and the task 3 ledger row above
  is corrected in place. ⚠ **Third time in Stage 7 that a number right about one column was
  attached to another** — 1441's C123 (which would have put a false badge on three rows)
  and C130 are the others.
* **C135 — §7e's escape hatch would have REMOVED 17 rows from a surface task 3 had already
  shipped.** The plan's *"an option with no known default is labelled global and offered
  only on the global surface"* is not a tidy edge case at 60/247 coverage; applied
  literally it takes options away from a pane the user already has.
* **C141 — §7g rule 4's stated reason is `-r`-only and does not reach the deck ASE-L
  writes**, so the rule survives with a different justification rather than on the plan's.

⚠ **ONE DRIVER FOOTNOTE, AND IT IS THE SECOND IN A ROW.** Receipt 22's *For the driver*
section said the new suite adds **`+85`** to T1; it is **92**, agreeing with the same
receipt's own floor paragraph, with the comment this commit added to `run_regression.tcl`,
and with the driver's own `RESULT: ALL PASS (92 checks)`. Receipt 21 had the same shape
(*"T1 covers all 82"* for a suite printing 62 and 87). **The suites have been right every
time and the driver's re-runs have matched them exactly; it is the sentences about the
counts that drift.** Take a number from a `RESULT:` line, not from a paragraph.

---

### ✅ STAGE 7 IS COMPLETE — §7a–§7g, in four tasks

| § | task | issue | state |
|---|---|---|---|
| 7a catalogue, five columns | 1 | **1437** | 247 rows |
| 7b one speller | 1 | **1437** | T3/T4/T5 are type errors |
| 7d pre-deck class and inert list | 2 | **1439** | ⚖ R2's four conditions met, one narrowed by measurement |
| 7c finding one among 247 | 3 | **1441** | finder, groups, measured badge, live preview |
| 7e per-analysis scope | 4 | **1442** | shipped with C135's honest limit **on the surface** |
| 7f requested vs effective | 4 | **1442** | shipped **through the channel that works** |
| 7g the rules | 4 | **1442** | five: rule 2 already shipped (1434), rule 1 changed shape, 3/4/5 new |

**Four things open, none blocking a later stage:**

1. ⚖ **R9 — thirteen issues' worth of unratified user-facing copy.** This is now the
   batch's largest standing debt and it is entirely the user's to clear.
2. **Two `look` debts** — 1441's options sheet and 1442's additions to it — plus the `:0`
   **suite** debt the driver filed for the sheet. Neither `look` clears on a green suite.
3. **`group` is 0/247 verified and `scope` cannot be measured.** Both are mitigated by
   design and both are on the record.
4. **Ten `results` rows remain `unverified`** and say so on the surface.

**Stage 8 is next.**

### What Stage 7 learned that binds later stages

---

## Stage 8 — Measurements and post-processing

### 📋 Stage 8's task split, decided by the driver before the stage opens

`PLAN.md` §8 says *"one or two commits"*. It is **two crew tasks**, on the same principle
that worked for Stage 7: the deck-side half and the pixel-side half are separated so that
any **`look` debt is attributable to exactly one commit**.

| task | §items | why it is one task |
|---|---|---|
| **1** | **8a + 8c** | The `measurements` state list and the grammar it validates against (SCHEMA), `meas_line` / `meas_needs_degrees` and `render_deck`'s `meas` block (CONTENT), plus 8c's producers — `.four` as a **card**, `fft`/`spec`/`psd`/`linearize` as **commands**. They are one task because **8c's card/command rule is the same rule 8a's third refusal encodes**: *"`.meas` dot cards are refused under `-r`, so this is a command, not a card"*, and *"nothing analysis-shaped ever goes in the card slot."* Split across two tasks, one crew writes the rule and the other writes its exception. Headless by construction — no widget |
| **2** | **8b** | The eight named templates, the Measurements sub-dialog, the template picker and the Value-column rows. This is the whole GUI half and the whole of ⚖ R9's copy for the stage (eight template names, every measurement label, the degrees sentence) |

⚠ **`PLAN.md` SAYS THIS STAGE FILES NO `look` DEBT, AND STAGE 6 ALREADY CAUGHT THAT EXACT
CLAIM BEING STALE.** §8's *Re-measure on the dev display* paragraph argues the pane reuses
Stage 5's `resulttable` and Stage 3's form idiom, so nothing new is drawn — **and in the
same breath asks someone to check that the `deg` unit reaches the Y-axis label**, which is
a pixel. Stage 4 made the identical argument about the precondition banner and it was
**wrong** (issue 1435 shipped a genuinely new widget and a `look` debt). **Task 2 decides
it by measurement and says which half of the paragraph is stale**, exactly as task 6 of
Stage 6 did.

⚠ **AND THE RADIANS TRAP IS ALREADY DRIVER-VERIFIED, FROM STAGE 7.** §8a calls
`set units=degrees` *"the one nobody caught"*. Issue **1437**'s C104 and the driver's own
re-measurement settle how it must be spelled — measured on **both** binaries with an RC
whose phase at 1 kHz is exactly −45°:

```
no units setting          vp(out) = -7.85398e-01   (radians)
.options units=degrees    vp(out) = -7.85398e-01   <- THE CARD DOES NOTHING
set units=degrees         vp(out) = -4.50000e+01   <- works
```

⚠ **CORRECTED 2026-09-13 — this paragraph conflated TWO catalogues, and Stage 8 task 1's
crew caught it (C145), driver-verified at HEAD.** What is true: `units` is **not one of
ngspice's 220 names** — neither an `OPTtbl` keyword nor a `cp_getvar` name — and is read at
`src/frontend/options.c:419` through a `va_name` / `CP_STRING` comparison, which is why
`.options units=degrees` is silently inert and a phase margin taken from such a deck is
wrong by **57.2958×**. What is **false**: that it is not one of **ASE-L's** 247 catalogue
rows. It is — `git show HEAD:src/ase.tcl` carries it as

```
units {cptype string phase run group output scope global default radians values {radians degrees} …}
```

`phase run` is the adapter already saying *this one is a `set` in `.control`, not a card*.
The 247 are the 220 **plus 27 measured additions**, and `units` is one of the 27; a reader
who took this paragraph literally would have spelled a second, competing line for it instead
of going through `ase::opt_line`. **The auto-emission is still the `set` form — only the
route changes, and the route was already there.**


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

## Stage 15 — The adapter conformance harness — ⚠ **OUT OF COMMITTED SCOPE (⚖ R10, 2026-09-13)**

⚠ **THIS STAGE IS NO LONGER OWED.** ⚖ **R10 was answered Option B** on 2026-09-13: the
written adapter-author specification ships, **this harness does not**, until there is a second
adapter to run it against. A conformance suite with one implementation behind it cannot tell
the contract from the implementation — it would pass against ngspice and prove nothing. The
stage stays below as a design that may be **chosen** later; it is not a stage this batch owes,
and the batch is **16 committed stages rather than 17**.

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
