# final-docs — the serialisation rule gets its real reason, 1481 needed nothing, and the collision detector self-matches

**Status:** DONE

**Headline, and all three tasks departed from the brief.**

1. **Task A's premise is refuted.** There is **no live document** left to rewrite. All **18**
   sites carrying the refuted RAM figure sit inside the fenced leave-alone class, and that
   class is **18, not 17** — `ram-figure` counted *four* session prompts where the tree
   carries **five**. The one live document, `CLAUDE.md`, was already corrected by
   `ram-figure`; what it lacked was the rule's **real** basis, R4's status, and the
   harness-vs-dispatch-queue distinction. Those are now in it.
2. **Task B needed no edit, exactly as the brief warned it might.** Issue 1481 **already**
   states that the trailer is immune and structurally better. I changed none of it.
3. **Task C is not worth a number.** The trap is already documented correctly in **five**
   places. What was missing was *reach*: `CLAUDE.md` contained **zero** occurrences of
   `pgrep`. The correction went there, not into a sixth issue file.

⚠ **And I shipped a rotted citation into the block lecturing about rotted citations, then
caught it.** See *Self-caught error* below. That is the fourth time in this batch that a
correction has committed the error it corrects.

---

## Tree state (rule 10)

Every citation in this receipt and in both edits is against **`69c65249`**
(`test(V5): closing gate GREEN -- T1 at zero on today's tree`, 2026-09-17 09:15:48 -0700).
`git status --short` showed **no `M` line** for `tests/run_regression.tcl`, `src/main.c` or
`doc/claude/ledger/crew.js` at entry or exit, so the working tree **is** `69c65249` for
every file I read. Line numbers below are quoted with their text.

## Files touched

| file | lines | what |
|---|---|---|
| `CLAUDE.md` | **208-209**, **220-221** | 1481's rotted coordinates corrected `:841`→`:856`, `:872`→`:887`, `:826`→`:841` |
| `CLAUDE.md` | **227-238** (new ⚠) | the +15 citation-rot note, coordinates quoted with their text against `69c65249` |
| `CLAUDE.md` | **~415-480** (new ⚠ blocks) | ⚖ R4: real basis, relaxed status, harness-vs-queue, two caveats, the 18 fossil sites, and the `pgrep` trap + correct idiom |
| `doc/claude/issues/1481-…-by-eleven.md` | **6-7**, **48**, **57**, **60**, **69-70** | six rotted citations corrected, all `+15` |
| `doc/claude/issues/1481-…-by-eleven.md` | **73-92** (new ⚠) | the citation-rot note with the four lines quoted verbatim |
| `doc/claude/issues/1481-…-by-eleven.md` | **~103-115** (new ⚠) | V5's re-measurement recorded, and *"no part of this issue needed rewriting as a result"* |
| `receipts/final-docs.md` | new | this file |

`git diff --numstat`: **`81 4 CLAUDE.md`**, **`41 6` 1481** — 122 insertions, 10 deletions,
2 files.

**Untouched, as fenced:** every file under `tests/` and `src/`, `PLAN.md`, `LEDGER.md`,
`DECISIONS.md`, `CREW_BRIEF.md`, every other receipt, `owed.sh`, and **all 18 stale sites**.
**No existing ⚠ confession was removed or reworded** anywhere.

## Rows added/changed

**None.** Documentation-only. **No suite, no `./src/xschem`, no `make`, no
`run_regression.tcl`** — the brief forbade all of them and the batch's closing verification
was not disturbed. The substitute for red-before/green-after is that every claim below is
re-measured with its command quoted.

## Commands run

Read-only throughout. `/usr/bin/grep` never bare. Every command under `timeout`.

```sh
timeout 60 /usr/bin/grep -rn '7\.8 *G\|7\.8G' . --include='*.md' --include='*.sh' \
        --include='*.tcl' --include='*.c' --include='*.h'          # first sweep
timeout 60 /usr/bin/grep -rn '7\.8 *G\|7\.8G' . --include='*.js' --include='*.json' …
timeout 60 /usr/bin/grep -rn -i 'one crew at a time\|one agent at a time\|one crew may run' .
timeout 60 /usr/bin/grep -rn 'pgrep' . --include='*.md' --include='*.sh' --include='*.tcl'
timeout 30 /usr/bin/grep -c 'pgrep' CLAUDE.md                       # -> 0
timeout 30 /usr/bin/grep -n 'ps -eo\|comm=\|another regression run is live' CLAUDE.md
timeout 30 /usr/bin/grep -n 'puts "Start\|puts "Finish' tests/run_regression.tcl
timeout 30 /usr/bin/grep -n 'incr t1_cases\|^ *continue' tests/run_regression.tcl
timeout 30 awk 'NR>=656 && NR<=670 {printf "%d:%s\n", NR, $0}' tests/run_regression.tcl
timeout 30 /usr/bin/grep -n 'EMERGENCY SAVE DIR' src/main.c        # -> :52
timeout 30 awk 'NR>=24 && NR<=26 {…}' doc/claude/ledger/crew.js    # -> :25 "OVERRIDES"
timeout 10 /usr/bin/grep -E '^(MemTotal|SwapTotal|SwapFree)' /proc/meminfo
timeout 15 dmesg | /usr/bin/grep -icE 'out of memory|oom[-_]kill|Killed process'  # -> 0
timeout 30 git log -1 --format='%h %ad %s' --date=iso ; timeout 30 git status --short
timeout 30 git diff --numstat
# mint procedure, both checks, candidate 1482:
timeout 30 awk -v n=1482 -F'|' '/^\| \*\*[0-9]/{…reserved-band range test…}' NUMBERING.md
set -- ~/dev/*/doc/claude/issues/NUMBERING.md ; [ -e "$1" ] || echo '!! glob matched nothing'
timeout 30 ls ~/dev/*/doc/claude/issues/1482-*   ;   timeout 30 /usr/bin/grep -lw 1482 "$@"
```

## Measurements

| measurement | value | command |
|---|---|---|
| **`MemTotal`** | **16091816 kB = 15.35 GiB** | `grep ^MemTotal /proc/meminfo` — **my own third independent read**, byte-identical to `ram-figure`'s and V4's |
| **swap** | **4194304 kB total, 4194304 kB free (0 used)** | `grep ^Swap /proc/meminfo` |
| **kernel OOM kills** | **0** | `dmesg \| grep -icE 'out of memory\|oom[-_]kill\|Killed process'` |
| **sites carrying the refuted figure** | **18** | `grep -rln` over `*.md *.js *.tcl *.sh`, batch docs and already-corrected files excluded; raw hit count 19, **minus one false positive** |
| false positive in that sweep | `signal_browser_batch/receipts/08_receipt.md:292` | `### 7.8 GUI gate` — a **section number**, not the RAM figure |
| `pgrep` occurrences in `CLAUDE.md` | **0** (before my edit) | `grep -c 'pgrep' CLAUDE.md` |
| process-matching guidance in `CLAUDE.md` | **none** | `grep -n 'ps -eo\|comm='` → silent |
| **1481 citation rot** | **uniform +15**, six sites | `grep -n 'puts "Start\|puts "Finish'` |
| `t1_live_runs` extent | **`:656-665`** | `awk NR>=656 && NR<=670` |
| `EMERGENCY SAVE DIR` marker | **`src/main.c:52`** | `grep -n` |
| candidate issue number 1482 | **free** — band check silent, `ls` rc 2 in both clones, `grep -lw` hits only this clone's own pointer | mint procedure above |
| clones on this machine | **2** (`xschem-claude`, `xschem-op-wcard`) | `ls ~/dev/*/…/NUMBERING.md` |
| diff | **+122 / −10, 2 files** | `git diff --numstat` |

### The 18 sites, enumerated — all fenced, none touched

| class | count | sites |
|---|---|---|
| `doc/claude/ledger/*.md` | 5 | `STATE_2026-08-25.md:76`, `RESUME.md:131`, `overnight_queue_2026-08-25.md:7`, `overnight_queue_2026-08-25_night.md:13`, `PARK_2026-08-31.md:46` |
| crew-launcher `.js` | 4 | `ledger/crew.js:29`, `ledger/crew_annotate.js:58`, `ledger/crew_opfix.js:67`, `op_param_batch/item_pipeline.js:91` |
| `suggestions/next_session_prompt_*.md` | **5** | `merge5_audit_and_ctrlb_xserver_crash:208`, `modal_gesture_phase1_2:162`, `0265_leave_merge_for:238`, `op_annotation:2746`, `wire_placement_gate_f2_f3:224` |
| issue files recording a past decision | 4 | `0432:82`, `0671:83`, `0868:215`, `0876:45` |

**5 + 4 + 5 + 4 = 18.** `ram-figure.md:215-222` records the same set as **17** because it
counted four session prompts; the tree carries five. Its *judgement* — that these are dated
records and rewriting them falsifies the record — **I agree with and followed.**

⚠ **One disagreement, reported and not acted on.** The four `.js` are **launchers, not
archives.** `crew.js:29` is inside a template that a future run emits into a **new crew's
brief**, three lines after `crew.js:25` tells that crew *"Read ${REPO}/CLAUDE.md first …
It is authoritative and it OVERRIDES your defaults."* Classed as "dated ledger" by
directory, they are live guidance by function. **I did not touch them** — the brief fenced
them explicitly and a closing batch is the wrong moment to widen scope unilaterally.
Instead I made CLAUDE.md do the overriding those files already promise, and named the four
paths in it. **The driver may want to rule on whether launcher templates belong in the
leave-alone class at all.**

---

## Claims checked vs taken on trust

### Task A

| claim | verdict | evidence |
|---|---|---|
| ⚖ R4 has been relaxed | **CONFIRMED** | `DECISIONS.md:400` — *"✅ **R4 IS RELAXED, 2026-09-17.**"* |
| The box is 15.35 GiB with 4 GiB unused swap | **CONFIRMED — re-measured myself** | `/proc/meminfo`, third independent read, exact match |
| `dmesg` shows zero OOM kills ever | **CONFIRMED for this boot** | `dmesg \| grep -ic …` → **0**. ⚠ "ever" overstates it: `dmesg` is a ring buffer for **this boot only**. The stronger true statement is `ram-figure`'s — no file in the repo records an *observed* kill |
| V4 measured concurrency adding nothing (10328 vs 10350 MiB) | **CONFIRMED as recorded** | `V4.md:307-308`; **taken on trust as a measurement** — I ran no suite |
| **"six documents" state the rule and cite the box** | **REFUTED** | **18** sites carry the figure. "Six" appears at `DECISIONS.md:352`, `LEDGER.md:390` and `ram-figure.md:259` with **no measurement behind it anywhere**. This is the batch's own signature defect — a plausible number requoted — in the sentence that introduces ⚖ R4 |
| `ram-figure` names **17** left alone | **CORRECTED → 18** | five session prompts, not four |
| The 17 are dated records; rewriting falsifies | **CONFIRMED, and followed** | none touched |
| The real basis is 407/432/757 phantom `FATAL`s, second run dead at rc 1 | **CONFIRMED as the record's content** | `DECISIONS.md:365-366`, `LEDGER.md:264-266`; `plan-closeout.md:130-136` independently marks it the one measured block that survived. **Taken on trust as a measurement** — no pre-fix tree was run by me |
| R4's relaxation is about the **harness**, not the dispatch queue | **CONFIRMED** | `plan-closeout.md:102-107` flagged exactly this; `LEDGER.md:84` still reads *"Only one crew may run suites at a time"*. Written into CLAUDE.md as the distinction to ask about |
| Two caveats stand | **CONFIRMED** | `DECISIONS.md:407-410`; `V5.md:404-406` lists both as outstanding |

### Task B

| claim | verdict | evidence |
|---|---|---|
| `incr t1_cases` fires **before** the `continue` | **CONFIRMED in source** | `:841` `Start`, **`:842` `incr t1_cases`**, `:856` `continue`, `:887` `Finish` |
| 1481's hole does not reach the trailer | **CONFIRMED** | the increment precedes the branch, so `cases=84` survives |
| **"Add it to 1481"** | **REFUTED as an action** | 1481 **already** carries it: *"`incr t1_cases` happens at the top of the loop, before the branch, so the trailer reports `cases=84` on a display-less box as on any other"*, and fix direction 2 already calls the trailer *"strictly better as a **reader's** rule"*. **No substantive edit made** |
| *"a previous crew found 1481 needed no edit at all"* | **CONFIRMED, and it is still true** | the brief's own guard was correct; re-filing avoided |
| **NEW — 1481's citations are rotted** | **FOUND, not in the brief** | all six **+15**: `:825-872`→`:840-887`, `:826`→`:841`, `:841`→`:856`, `:872`→`:887`, `:736`→`:751`, `:792`→`:807`, `:895`→`:910`. CLAUDE.md carried the same rot. Cause: one crew's `+22/−7` (net **+15**) landing above all six the day 1481 was minted — **the same `+15` that produced the four-source-citation failure** |

### Task C

| claim | verdict | evidence |
|---|---|---|
| `pgrep -af 'run_regression'` returns four hits for one run | **TAKEN ON TRUST** from `V5.md:336-344` | I deliberately did **not** re-run it: no process work was in scope, and running it is itself the trap |
| …because `-f` matches the whole command line | **CONFIRMED by reading** | the mechanism is documented identically in three independent places |
| The driver used it in V5's own brief | **CONFIRMED** | `V5.md:320` — *"⚠ The driver put that exact command in V5's own brief."* |
| It is the **fourth** sighting of the defect class | **CONFIRMED for this batch**, **undercount for the repo** | in-batch: `results.log`, `C11`, `W12b`, `pgrep` = 4. Repo-wide it is at least the **sixth** — see the table below |
| `t1_live_runs` already does it correctly | **CONFIRMED** | `:656-665`: globs `results.<pid>.log`, keeps a pid only if `/proc/<pid>` is a directory. Identity, not pattern |
| CLAUDE.md is where the guidance is missing | **CONFIRMED** | `grep -c 'pgrep' CLAUDE.md` → **0** |

### `pgrep` sites, classified — every one, as asked

| site | kind | verdict |
|---|---|---|
| `code_analysis/gui_test_gate_tutorial.md:207-210` | guidance | **already correct** — Lesson 5, the `[.]` bracket trick |
| `ase_analyses_batch/CREW_BRIEF.md:125-160` | guidance (other batch) | **already correct** — three sightings, incl. one that **killed its own shell** (exit 144) |
| `suggestions/retrospective_new_user_lessons.md:46-98` | guidance | **already correct** — §7, names leaked watcher shells |
| `suggestions/next_task_0318:67-69`, `next_task_0319:94-96` | guidance | **already correct** — both prescribe the bracketed form and warn |
| `specs/gui_test_gate.md:171` | spec | mentions the hazard; fine |
| 4 × `suggestions/next_session_prompt_*` | guidance | *"Kill only PIDs you launched, after reading `pgrep -af xschem`"* — read-then-kill-by-pid, low risk, **not mine to edit** |
| `signal_browser_2pane_batch/xarm.sh:48,56` | script | unbracketed, but the caller's argv is `bash xarm.sh`, which does **not** contain the pattern — **no self-match** |
| `tests/headless/test_devdisplay.sh:122,256` | **suite** | **immune** — `Xvfb [:]$NUM`, bracketed |
| `tests/headless/test_gui_gate_revive.sh:194,205` | **suite** | **immune** — `gui_gate_widget[.]tcl`, bracketed |
| `test_op_annot.tcl`, `test_annot_stale_0684.tcl`, `test_annot_hier_0911.tcl` | **NOT process matching** | procs named `opa_v_pgrep` / `f_pgrep` / `h_pgrep` that grep a **Tcl proc body**. ⚠ **A future sweep must not "fix" these** |
| `ase_analyses_batch/LEDGER.md:1521` | record | a guard that **falsely refused T1** by self-matching — the operational cost, already recorded |
| 13 receipts in this batch | record | the bare idiom, as used. Historical; untouched |

### Decision on minting — **no new number**

The two-check procedure was run and is recorded above: **1482 is free** (band check silent;
`ls` rc 2 in both clones; `grep -lw 1482` hits only this clone's own pointer sentence).
**I deliberately did not take it.**

The trap is already written up correctly in **five** places, each with the right fix. A
sixth document about a defect documented five times and fixed zero times is this project's
signature failure — it is why this batch exists, and the brief itself warns that one of its
own briefs was about to do it. **What was missing was never a number; it was reach.** The
one file every session reads had **zero** mentions. That is now fixed, with the existing
write-ups cross-referenced so the reader lands on the fuller treatment.

## Self-caught error

⚠ **I wrote `t1_live_runs (tests/run_regression.tcl:656-668)` into CLAUDE.md — wrong by 3;
the proc ends at `:665`.** It went into the very block that lectures the reader about
citing by position. Caught by measuring the range with `awk` instead of counting a `sed`
window by eye, *before* the receipt was written, and corrected in place.

Recorded because the pattern is now this batch's most repeated finding: **the correction
committing the error it corrects** — `85` added to prevent a conflation *was* the
conflation; `d5396ddd` accused four passes of citing without reading *while* citing without
reading; and now this. The countermeasure that worked was not care, it was **running the
command**.

## Corrections to the record — the next reader needs these

1. **"Six documents" is unmeasured and wrong; it is 18 sites.** It sits at
   `DECISIONS.md:352`, `LEDGER.md:390` and `ram-figure.md:259` — all three fenced from me.
   **The driver should correct them**, or accept that ⚖ R4's opening sentence carries a
   requoted number, which is the defect the ruling is *about*.
2. **`ram-figure`'s leave-list is 17 and should read 18** (`ram-figure.md:215-222`) — five
   session prompts, not four. Fenced; reported.
3. **1481 and CLAUDE.md were both citing a tree 15 lines stale.** Fixed in both. If any
   other document cites the display arm, it is rotted by the same `+15`.
4. **The four `.js` launchers are live guidance filed as archive.** Unresolved by design;
   the driver's call.
5. **"`dmesg` shows zero OOM kills ever"** should be *"zero this boot, and no file in the
   repo records an observed one"* — the ring buffer cannot speak for "ever". The conclusion
   is unaffected; the wording overstates the instrument.
6. **`test_devdisplay.sh` and `test_gui_gate_revive.sh` are already immune** to the `pgrep`
   trap, and three `*_pgrep` Tcl procs are not process matching at all. **Any sweep must
   skip all five** or it will "fix" working code — the seventh such near-miss in this batch.

## Left dirty

```
 M CLAUDE.md                                                      (+81/-4)
 M doc/claude/issues/1481-…-by-eleven.md                           (+41/-6)
?? doc/claude/harness_concurrency_batch/receipts/final-docs.md     (this file)
?? .xschem/
?? doc/claude/rdw_lists_batch/
?? doc/claude/rdw_sim_batch/
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
```

Exactly **three** entries are mine: the two modified files and this receipt. The four
untracked directories are **pre-existing and not mine** — present in the session's opening
`git status`. **Nothing committed** (rule 7). HEAD is `69c65249`, unmoved throughout.

**No test artefact was produced or disturbed.** No suite ran, no binary ran, nothing was
built; `tests/results.log` and `tests/results.2484691.log` are V5's and untouched, so the
batch's closing verification stands exactly as V5 left it.

## Owed to the user

**Nothing, and I did not open `owed.sh`** (rule 8). Everything here is internal harness
documentation and internal scheduling policy; no sentence produced reaches a person. Per
the filter at the head of `DECISIONS.md` — *does this reach a person?* — filing a rule debt
for any of it would repeat the error the user corrected when they returned R1/R2/R3. The
two open items (whether launcher templates belong in the leave-alone class; whether the
"six documents" figure gets corrected in the fenced files) are **the driver's**, not the
user's.
