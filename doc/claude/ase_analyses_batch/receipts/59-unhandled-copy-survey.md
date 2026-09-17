# 59 — the unhandled-copy survey: how many more strings have no `R9-` handle

**Task:** read-only survey. Three rulings (§A11, §A6, §A4) each bumped into a user-visible
string with no handle. The driver asked: **how many more are there?** Deliverable is a count
and a list.

**Answer: 19 strings, in 7 groups (A–G).** Plus one **borderline class of 53** that is reported
separately because it is ngspice's own text and the document explicitly excludes that, and
three **out-of-scope classes** (152 strings) that predate the batch and were never in ⚖ R9's
declared scope.

⚠ **Two numbers in this receipt contradict what I believed mid-survey, and both corrections
went AGAINST my own finding.** A 52-string "headline" collapsed to 0 and a 12-string group
collapsed to 0. Both are written up in §7, because the way they collapsed is the same trap
§A11 already paid for once.

---

## VERDICT TABLE

| # | question | answer |
|---|---|---|
| 1 | strings with no handle, in ⚖ R9's declared scope | **19** |
| 2 | borderline — on screen, but ngspice's own text | **53** (option help prose) |
| 3 | out of scope — pre-existing ASE-L copy, predates the batch | **152** |
| 4 | the six the driver already knows | re-found **4 of 6** independently — positive control |
| 5 | did the method survey by RENDERING, not grepping | yes — 2 890 rendered emissions, 3 arms |
| 6 | confidence in the 19 | high on each string; the 19 is a **lower bound**, not a ceiling |
| 7 | what the method could not reach | 20 procs, 2 dialogs, all run-time-only surfaces |

---

## 1 — Method: three render arms, then a provenance gate

The brief's warning was the design constraint: a source grep for `.c:` answers **393** where a
user sees **18**, because the `site` key reaches no screen. So nothing here is counted from a
source grep. Every string below was **produced by running the code that puts it on screen**.

| arm | what it renders | emissions |
|---|---|---|
| **A** — widget-tree walk | a live ASE-L session on `:99`; opens 25 dialogs, walks every widget, harvesting `-text`, `-label`, `-values`, `wm title`, menu entry labels, listbox items, Text bodies, Treeview headings and rows | **474** |
| **B** — catalogue/composer domains | what `ase::ui::optsheet_detail` composes over all **247** option rows (`help`, then `inert`/`owner`/`clamp`/`defect`+`caveat` by `ase::opt_offer`, then `results_why`, `gate_why`, `leak_why`); the measurement catalogue over **19** kinds and **8** templates; the analysis contract over **11** types and every field caption, unit, group and mode-relabel | **1 446** |
| **B2** — arg-taking spellers | the ~96 surface spellers Arm B could not call because they take arguments, driven both with synthetic probes and over their **real** domains (sim × type × field × mode) | **970** |

Arm A ran under `tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog`, Arms B/B2
under `--nogui --pipe -q --nolog`. **Never a bare `xschem`; every launch carried `--nolog`.**

Deduplicated and normalised (whitespace, unicode escapes, smart quotes, leading glyphs,
trailing colon, case): **828 distinct strings**.

Matched against the **726** handled strings extracted mechanically from the fenced `text`
blocks of `R9_COPY_REVIEW.md` (730 handles; `R9-727`–`R9-730` carry no fenced block because
they are quoted inline in §A1/§A5's new-copy blocks):

⚠ **THE DOCUMENT MOVED UNDER THIS SURVEY, AND THE 19 WERE RE-CHECKED AGAINST THE NEW ONE.**
My handled-set extraction was taken early; at **17:35:20**, while this survey was running, the
driver minted **R9-731 / R9-732 / R9-733** under a new heading — *"from ⚖ R9 itself — copy that
reached the screen with no handle"* — taking the document to **733 handles / 730 entry lines**.
That is the same class this task is about, so the match could have gone stale in exactly the
direction that would overstate my answer. **Re-extracted from the current file and re-checked
all 19: none became handled (0 now-handled, 19 still unhandled).** The three new handles are the
three returns of `ase::analysis_gap_msg` — known item 5's family, already excluded from my count
— so the tier numbers above are unaffected. **A later reader should re-run the check rather than
trust this paragraph**, for the reason it exists.

| tier | meaning | n |
|---|---|---|
| EXACT | normalised string equals a handled string | 268 |
| SUB | a piece of a handled string | 103 |
| SUPER | a composed whole whose parts are handled | 11 |
| unmatched | — | **446** |

The 446 were then put through a **provenance gate** and a **frame collapse** (§2, §3).

### ⚠ The provenance gate was control-tested in both directions before I trusted it

A gate that always answered "new" would produce exactly the alarming result this survey was
looking for, so it was fed known answers first. ⚖ R9's own title is *"every user-facing
sentence **this batch has added**"*, so the gate is: **is this string present in the source as
of `2f1fad58`** (the pre-batch HEAD named in `CREW_BRIEF.md`)?

```
NEGATIVE controls (batch-added -- must be ABSENT from the pre-batch blob)
  "does not know a simulator backend called"   absent  (good)
  "Stop value"                                 absent  (good)
  "Step size"                                  absent  (good)
  "CHANGES RESULTS"                            absent  (good)
POSITIVE controls (pre-existing -- must be PRESENT)
  "Save State?"        present (good)     "Waveform Viewer"   present (good)
  "Design Window"      present (good)     "Delete Selection"  present (good)
  "Add Variable"       present (good)
```

Nine for nine. The empty case is guarded separately (a zero-length string matches every blob,
so it is classified as noise before the gate sees it).

---

## 2 — What I counted as "user-visible", and the defence of it

**A string is user-visible if a surface a user can reach renders it.** Concretely: it was
emitted by a live Tk widget in Arm A, or it was produced by a composer whose output is
`configure -text`'d / inserted into a widget / echoed to the run log.

**EXCLUDED, with the reason:**

| excluded | why |
|---|---|
| **catalogue keys no surface renders** | the `site` key is the worked example — and **I caught a second one of exactly this shape**, see §7b |
| developer comments | never rendered |
| `dbg` output | not seen in normal operation |
| test-only strings | no suite file was read for strings |
| **SPICE syntax** — the 247 option names, analysis verbs, deck cards | the document already rules deck cards out; an option name is ngspice's identifier, not copy |
| **the probe's own environment** | Tk's internal menu window names (`#ase4#mb#sim`), the developer's real `~/.xschem/ase_simulators` entries (`ng-cm3`, `eebin`, `slowstub`), `/home/analog/...` paths, my fixture's rows |
| **probe artefacts** | `ase::sim_status` and `ase::ui::matrix_format_by_label` return **dicts**, not sentences; `nz_target_label` returned a `{name label}` pair because my probe handed it a pair as its `field`. Three renderings discarded as mine, not the product's |

**Read-only compliance.** Nothing under `~/.xschem/` was written — the registry was **read**
(which `CREW_BRIEF.md` permits) and that is why real entry names appear in the raw output and
are filtered above. No simulation was run, no `ngspice` was invoked, no bench under `sky130A/`
was touched, `tests/run_regression.tcl` was not run, and the only file I wrote is this receipt.

---

## 3 — ⚠ Instances are not strings: the frame collapse

`Result Matrix (ac)` … `Result Matrix (tran)` is **one** sentence rendered eleven times.
Counting renderings would have reported ten findings that do not exist. Every unmatched row is
collapsed to its frame before counting; 30 frames were rendered more than once, the largest
eleven-fold.

The same applies to the arg-taking spellers: 289 synthetic renderings are **61 frames**. Judged
by frame against the document: **15 HANDLED, 14 unhandled, 32 undecidable** by synthetic args
alone — of which 12 were then decided by driving the proc over its **real** domain instead,
leaving **20 genuinely undecidable** (§8).

---

## 4 — THE ANSWER: 19 strings with no handle

Each was confirmed absent from the extracted handled-string set **and** from the document text,
and confirmed batch-added by the provenance gate. `W` = confirmed rendered on a real Tk widget
in Arm A; `C` = produced by a composer whose surface Arm A opened, but not on screen in the
state my fixture reached.

### Group A — Simulation > Options…, the detail line (2)

| # | string | source |
|---|---|---|
| 1 | `the simulator entry's Case field` | `opt_owner`, option `casemode` — renders after `SET ELSEWHERE:` | C |
| 2 | `the simulator entry's -n flag` | `opt_owner`, option `no_spinit` | C |

### Group B — Choose Analyses (2)

| # | string | source |
|---|---|---|
| 3 | `Offered because every build of this simulator has it. Nothing was measured.` | `.ase4.chana.status` label | **W** |
| 4 | `ase: '<sim>' cannot run <type>, so it was not added to the bench.` | `ase::analysis_commit_refusal` | C |

⚠ #4 is **not** the document's `ase: the <type> analysis cannot run: <sentence>` (R9's preflight
refusal). Different frame, different door; the doc's nine "cannot run" mentions are all the other one.

### Group C — Campaign (5)

| # | string | source |
|---|---|---|
| 5 | `Model row` | `.ase4.campax.f.lindex` label | **W** |
| 6 | `Instance parameter` | axis-kind combobox value | **W** |
| 7 | `Model parameter` | axis-kind combobox value | **W** |
| 8 | `axis '<name>' has no values, so there is nothing to sweep` | `.ase4.campax.note` label | **W** |
| 9 | `# ASE-L campaign index -- one row per point, run or not` / `# a '-' in exit or raw means that point produced nothing` | `ase::campaign_index_text` — written to disk, read as English | C |

### Group D — Convergence / node highlighting (3)

| # | string | source |
|---|---|---|
| 10 | `this netlist has no such node` | `lbl_hilite_absent` | C |
| 11 | `ase: this session has no run log to read` | `lbl_hilite_nolog` | C |
| 12 | `ase: the last run reported no node that failed to converge` | `lbl_hilite_none` | C |

### Group E — Simulators dialog (3)

| # | string | source |
|---|---|---|
| 13 | `<entry> — will not run` | `ase::sim_label`; on the session status bar | **W** |
| 14 | `<mode> (NOT supported)` | `simdlg_case_label`, unsupported arm | C |
| 15 | `global default (<mode>)` | `simdlg_case_label`, no-explicit-mode arm | C |

⚠ #13's doc hits for "will not run" are three prose sentences about a *save list*, not this suffix.

### Group F — Noise-sources table headings (3)

| # | string | source |
|---|---|---|
| 16 | `On` | `lbl_nz_columns` | C† |
| 17 | `Target` | `lbl_nz_columns` | C† |
| 18 | `Values` | `lbl_nz_columns` | C† |

† **lowest-confidence three in the list.** `Kind`, the fourth heading, *is* handled (2 entries),
which is itself the argument that the other three should be. But `noise_editor` never opened
(§8), so these are composer-only. **Worth the driver's eye before minting.**

### Group G — the run log / CIW notice channel (1)

| # | string | source |
|---|---|---|
| 19 | `…s and was stopped; the campaign continues with the next point` | `ase::echo` literal | C |

Of **82** decidable `ase::echo` literals, 10 are handled, **71 are pre-existing** (§6) and this
is the only batch-added unhandled one. The run log is a surface no widget walk can reach, so it
was surveyed by joining Tcl line-continuations and extracting the literal at each of the 211
emission sites — the site *is* the surface there, unlike the `site` key.

---

## 5 — The borderline class, reported and NOT counted: 53 option help strings

The options sheet renders a `help` sentence for every catalogue row. **60 distinct ones reach
the screen. 53 are ngspice's own text, transcribed.** Measured, not assumed:

```
grep -rlF <each string> /home/analog/dev/ngspice/src/
  -> 53 of 60 resolve, overwhelmingly to src/spicelib/analysis/cktsopt.c
```

`Absolute error tolerence` (ngspice's own misspelling), `Set KLU as Direct Linear Solver`,
`Default MOSfet area of drain` — ngspice's `OPTinfo` table, word for word.

**The remaining 7 are ASE-L's own wording, and all 7 already carry handles.** So the
ASE-L-authored half of this surface is **completely covered**; the document's stated exclusion —
*"ngspice's own text … is not ours to ratify"* — is exactly the line that falls here, and the
five handles it does give this section (R9-254…R9-258) are each noted *"ASE-L's own wording, not
ngspice's."*

⚖ **This is the driver's call, not mine.** The 53 are on a user's screen. R9-276 sets the
precedent both ways: it **lists** an ngspice plot name *"because it is new text on a user's
screen"* while noting it is *"not ASE-L's wording to change."* If that precedent governs, the 53
want listing-without-ratification and the answer to the driver's question is **19 + 53 = 72**.
If the exclusion governs, it is **19**. I have not decided it.

---

## 6 — Out of scope, reported for completeness: 152 pre-existing strings

Unhandled, user-visible, and **predating `2f1fad58`** — so never in ⚖ R9's declared scope:

| class | n |
|---|---|
| widget strings (menus, buttons, dialog labels) — `Add Output`, `Design Window`, `Direct Plot`, `Save device OP parameters (gm, gds, vth, ...)`, `Calculator`, `Levels:` … | 73 |
| `ase::echo` run-log literals — `ase: cannot auto-plot '…'`, `ase: Select On Design — click wires/net labels…`, `ase: no netlist yet:` … | 71 |
| arg-taking frames — `design_unreachable_msg`, `hier_stranded_msg`, `run_busy_msg`, `sim_entry_why`, `sim_why`, `annot_fail_msg`, `lbl_overwrite_state`, `lbl_overwrite_readonly` | 8 |

⚠ **These are a real gap, just not this ruling's gap.** ASE-L's pre-batch copy has never been
put to the user at all. Flagging for the driver; **not** counted in the 19.

---

## 7 — ⚠ Two corrections to my own survey, both against my own finding

### (a) A filter of mine silently ate a known item

My first provenance classifier matched fixture tokens by bare substring against every string. It
classified the **`wnflag` caveat — one of the six the driver already knows** — as "fixture data",
because a 300-character sentence of ASE-L prose happens to contain one of those tokens. A filter
that removes a finding without saying so is the fails-safe guard this batch keeps being bitten
by. Bounded two ways (applies only below 60 characters; generic tokens removed), re-run, and the
item came back. **Anything that filter was hiding is now in the counts above.**

### (b) I nearly reported 12 strings that no user can read — the `site` trap, second instance

I had a group of **12 Direct Plot labels** ready to report: `DC transfer characteristic`,
`AC Analysis`, `Integrated Noise*`, `DISTORTION - IM: f1-f2` … all rendered by Arm B from the
analysis contract's `plots select` key, all absent from the document, all batch-added.

**They are not user-visible.** `src/ase.tcl` says so in the schema's own header: *"`select` is
**OPAQUE TO CORE** — it was `match`, 'a glob on the Plotname literal', which is a record type
only an ngspice rawfile has."* Every reader is `ase::reconcile_plots` / `ase::plot_select` —
matching machinery. No widget reads it, and **Arm A rendered 0 hits for all twelve**. They are
also ngspice's own plot names (`inp2dot.c`, `noisesp.c`, `distoan.c`).

**This is the `site` key wearing a different name**, and it is the second time this batch has
met it. What caught it was the widget walk disagreeing with the composer arm — which is the
argument for having run both.

### (c) My matcher under-counts by construction, and that is why 17 strings left the list

**118 handled entry lines contain `$` or `[` and 60 contain a `<placeholder>`** — the document
often records a string in its **source-expression** form, which no rendered string can ever
equal. Three findings died to this, correctly:

* the **14 option-group headers** (`CONVERGENCE (16)` …) → **R9-188**, recorded as
  `[string toupper $grp] ([llength $names])`, whose note enumerates all 14 group names;
* `+ <n> noise sources` → **R9-666**, recorded as `  + <n> noise source(s)`;
* `ngspice declares no default for it, so there is nothing to put it back to` → **R9-225**,
  recorded as `$sim declares no default for it, so there is nothing to put it back to`.

So the raw unmatched count is **not** the answer, and every one of the 19 above was additionally
checked by keyword against the document rather than by string equality alone.

---

## 8 — What my method could NOT reach (the honest bound)

**The 19 is a lower bound.** Specifically not reached:

1. **20 procs undecidable.** Their frames are too short to identify against the document
   (`facts_status`, `precheck_banner`, `stimuli_banner`, `lbl_camp_at`, `lbl_nz_points`,
   `casemode_status`, `rsel_status`, `annot_no_binding_notice`, `campaign_export_text` …). Several
   return dicts rather than sentences; the rest need a live state I did not build.
2. **2 dialogs never opened.** `setup_dialog` needs a committable `sp` analysis (it refuses
   otherwise) and `noise_editor` needs a selected noise entry. Group F's three headings sit
   behind the second.
3. **All run-time-only surfaces.** Anything that speaks only after a real simulation —
   reconciliation notes, salvage messages, stop/abort paths, annotation failures. No simulation
   was run, by standing rule.
4. **One simulator, one state.** Everything was rendered against `ngspice` and one fixture bench.
   Surfaces conditioned on another adapter, on capability-gated states (`absent`/`unmeasured`), or
   on a second registered simulator would render different text.
5. **142 probe fragments held back** — whitespace-split artefacts of list-returning spellers, not
   counted either way.

**To close the bound** would take: a state per analysis type with the type-conditional dialogs
open, a driven run for the run-time surfaces, and a second registered adapter. That is a
measurable amount of work, not an open-ended one — roughly the shape of this task again.

---

## 9 — Positive control: the six the driver already knows

Not double-counted, and used as the control on whether the method finds this class at all:

| # | known item | my survey |
|---|---|---|
| 1 | `itl1`/`itl2`/`itl4` clamp citing `niiter.c:38-39` | **re-found** |
| 2 | `defas` citing `cktsopt.c:111-113` | **re-found** |
| 3 | `scale` citing `subckt.c:592`/`inp.c:2689` | **re-found** |
| 4 | `wnflag` citing `inpgmod.c:268` | **re-found** (after §7a) |
| 5 | `ase::analysis_gap_msg` | **re-found** |
| 6 | dc's bare `Start` | correctly **not** flagged — it is **R9-002** |

**4 of 6 re-found independently before I read which they were**, #4 after the filter repair, and
#6 correctly excluded. A method that could not re-find this class would not be evidence for the
19; this one can.

---

## 10 — Debts to report upward — nothing filed or cleared by me

* ⚖ **rule** — the **19** below want handles minted by the driver. Handles are the driver's and
  the document is the user's; I edited neither.
* ⚖ **rule** — **the 53 ngspice-transcribed help strings**: list-without-ratification on R9-276's
  precedent, or exclude as simulator text? §5. **This is a question for the user, and it is one
  question, not nineteen.**
* ⚖ **rule** — **the 152 pre-existing strings** (§6) have never been put to the user in any
  ruling. Whether ⚖ R9 widens to them, or they get their own pass, is the driver's to raise.
* **look** — Group F's three headings (`On`/`Target`/`Values`) are composer-only; `noise_editor`
  would not open headless-fixtured. Worth eyes before minting.
* **No `look` debt otherwise** — nothing in this pass changed a pixel.
* **Nothing written to the owed ledger**, per the brief.

---

## 11 — Hygiene

* **Read-only on the tree.** `LEDGER.md`, `src/` and the suites were **not** touched, and **the
  only file I created is this receipt**.
  ⚠ **`git status` is NOT unchanged, and the honest statement is worth more than the tidy one.**
  It shows `M doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md` (+49/−1). **That change is not
  mine** — I never invoked a write on that path; every write I made went to the session
  scratchpad or to this receipt. It is the **driver's concurrent edit**, timestamped **17:35:20**,
  adding the `R9-731`/`R9-732`/`R9-733` block described in §1. The brief warned that file is the
  driver's and is being edited concurrently; this is that, observed. A reader auditing this pass
  should attribute the hunk to the driver, and `git diff` on it will show the minted handles
  rather than anything a survey would produce.
* **No `git` mutation** of any kind; no commit, no add, no stash, no checkout.
* **`tests/run_regression.tcl` was not run** (issue 0990 — the driver runs T1 solo).
* **No simulation. `/usr/bin/ngspice` was never invoked** — the ngspice tree was read with `grep`
  only, to establish authorship of catalogue prose.
* **Nothing under `~/.xschem/` was written.** The simulator registry was read; `$HOME/.spiceinit`
  was not touched.
* **Every command carried a `timeout`.** One probe stalled on `ase::ui::ask_save_close` (a modal
  `tkwait`); it was reaped by **exact argv match under `ps -eo comm=`**, never `pkill -f` and
  never a `pgrep -f` substring my own shell's command line could satisfy. Its data was already
  complete and the modal was dropped from the re-run.
* All probe scripts and outputs are in the session scratchpad
  (`armA3.tcl`, `armB.tcl`, `armB2.tcl`, `match2.py`, `classify.py`, `frames.py`, `final.py`).
  They are the evidence behind every number above and nothing reads them automatically.
