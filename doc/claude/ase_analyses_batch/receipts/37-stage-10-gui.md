# Issue 1460 — the convergence diagnostics had a parser and no surface

**Stage 10, task 2 of two — the GUI half.** Files I own and touched, and nothing else:
**`src/ase_window.tcl`**, **`src/ase.tcl`** (one reader and one adapter hook — see C16),
**`tests/headless/test_ase_conv_gui_1460.tcl`** (new), **`tests/headless/test_ase_window.tcl`**
(one changed expectation), **`tests/run_regression.tcl`**, plus
`doc/claude/issues/1460-*.md`, `doc/claude/issues/NUMBERING.md` and this receipt.

No commit, no `git add`, no stash, no restore, no clean, no push. `tests/run_regression.tcl`
**not run** (issue 0990 — the driver's, solo). **No simulation on any bench under `sky130A/`
or `ihp-sg13g2/`**: every simulator run below is a deck ASE-L itself rendered, written into
the suite's own scratch directory, against an explicit binary path. Nothing under
`~/.xschem/` was opened for writing.

**Floors:** `test_ase_conv_gui_1460` **NEW, 44 headless / 103 display**;
`test_ase_window` **unmoved at 56 / 295** — one row's *expectation* moved, not the count.
Each file's own paragraph is in the same diff.

`src/ase_window.tcl` **+1144**, `src/ase.tcl` **+44**, `test_ase_conv_gui_1460.tcl` **1369
new**, `test_ase_window.tcl` **+8 −2**, `run_regression.tcl` **+27 −2**, `PLAN.md` **+38**.

⚠ **`~/.xschem/recent_files` is untouched** — still `18:53`, the timestamp issue 1458 recorded
before I started. **`~/.xschem/geometry` moved to 22:22**, which is **issue 1458 itself**
(`store_geom` has no gate, so every display-arm suite run rewrites it) and not anything this
task did. Recorded rather than glossed, because a file under `~/.xschem/` changing during a
crew's pass is exactly what the standing rule is about.

---

## ⚠ THE HEADLINE: THE CHECKBOX REALLY MEANS OFF, AND IT IS ONE ARGUMENT AND TWO EXIT CODES APART

The brief: *"Your rung-4 checkbox must be able to mean OFF, and you must prove it with a deck
that behaves differently when it is cleared."*

**MEASURED 2026-09-13, both binaries, byte-identical.** The deck is **rendered by ASE-L from
the dialog's own state builder**; the two runs differ in **one checkbox** and in nothing else:

| the deck ASE-L renders | apt 45.2 | the fork |
|---|---|---|
| `optran 1 0 0 100n 10u 0` — transient rung **ticked** | rc 0, `v(1) = 1.413677e-02` | identical |
| `optran 1 0 0 0 10u 0` — transient rung **cleared** | **rc 1**, `Error: The operating point could not be simulated successfully.` + the starred table | identical |

Newton is **ON in both**, which is what makes the pair reachable: `ase::opstrategy_refusals`
permits both decks, so the difference is the rung and not the refusal. Row **EE1**, on **both
arms**.

⚠ **And the deck that kills the run outright cannot be reached from the form at all.**
`optran 0 0 0 0 10u 0` is rc 1 on both binaries and the dialog refuses it (`allrungsoff`) before
it can be rendered — row **GX3**. That is why the proof above had to be built with Newton on:
the obvious pair is one the product declines to produce.

---

## ⚠ THE TRAP THAT COST AN HOUR, AND THE TREE ALREADY KNEW ABOUT IT

`src/ase_window.tcl` defines **`ase::ui::open`** and **`ase::ui::close`** — the session
window's own opener and closer. A bare `open $p r` inside **any** proc in that file therefore
resolves to the **window** opener, raises on its argument count, and — inside the `catch` a
total reader needs — **returns an empty log with nothing said.**

Measured: `ase::ui::conv_logtext` answered `{}` for a session whose log file was on disk and
readable, and **seven rows went green by reading an empty string** before one of them
disagreed. The knowledge was already in the tree, one screen away, as a comment on a single
call site in `ase::ui::show_log`: *"::open — inside ase::ui a bare `open` resolves to
ase::ui::open"*. **A comment on one call site is not a rule.** Every file read added here is
`::open` / `::read` / `::close`, and the header of `conv_logtext` states it for the next
person. Sabotage **m54** puts the bare form back.

This is the shape the brief calls *"a read that raises kills a GUI suite at rc 0 instead of
reddening a row"* met from the other side: the read did not raise out of the proc, it raised
**inside a catch** and became silence.

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

| claim | evidence |
|---|---|
| the transient rung's checkbox really switches the rung off, proved by a deck ASE-L rendered and a simulator ran | **MEASURED HERE**, both binaries, the two-row table above |
| that pair is reachable through the form while the all-rungs-off pair is not | **MEASURED HERE** — row GX3 drives the dialog's four boxes and reads the refusal |
| a real non-converging run prints the starred table, ASE-L reads it, and the branch current is not offered to the canvas | **MEASURED HERE**, both binaries, from the deck EE1 just killed |
| `hilight_netname` answers 1 for a net on this sheet and 0 otherwise | **MEASURED HERE** on a real schematic under X (section GC), and **READ** from `hilight.c`'s `bus_node_hash_lookup` for why |
| a hierarchy-qualified node cannot be lit on this sheet | **MEASURED HERE** — `x1.nn` resolves through `ase::netlist_map_resolve` and has no wire here |
| `ase::netlist_map_resolve` returns the hierarchical name as a **dotted string**, not a list | **MEASURED HERE**; my first expectation said `{x1 nn}` and row NC4 refuted it |
| `ase::ui::conv_form_state` with no dialog wipes three state keys | **MEASURED HERE** — row GT6b, found by writing the row and watching it red |
| a bare `open` inside `ase::ui` resolves to `ase::ui::open` | **MEASURED HERE** (seven rows green on an empty string), **and confirmed** against the existing `::open` comment in `ase::ui::show_log` |
| `run_finished` really calls both surfaces | **MEASURED HERE**, section GF, by driving the product's own callback |
| the four `rusage` counters and their literal names | **READ** from issue 1459's adapter, **and re-run here** on both binaries (row EE3) |
| baselines: converge 76/76, core 638/638, dialogs 37 / 1 FAILED (384) with `G2sens` = `{1 1 0 1 0 Entry Entry normal}`, window 56/295, persist 49/153, sp 58/58, preflight 235/235 | **RE-MEASURED HERE** before I edited anything; all seven matched the brief exactly |
| 104 committed `.state` files round-trip byte-identically | **COUNTED AND ROUND-TRIPPED LIVE**, with a control in both directions |
| `optran.c:670-671`, `optran.c:182-185`, `cktload.c:30`, `hilight.c`'s `hilight_netname` | **READ**. Their *behaviour* is measured above; their line numbers are not |

---

## What shipped

**`src/ase_window.tcl` — four surfaces and the sentence.**

| § | what | where |
|---|---|---|
| **10a** | the starred nodes **lit on the canvas** | `Results > Highlight Non-Converged Nodes` → `ase::ui::conv_highlight_door` → `conv_failing` → `conv_resolve` → `xschem hilight_netname`, inside `ase::with_design_current` |
| **10b** | the **four-rung ladder pane** with its checkboxes, the step count and the two transient times, and the `optran` line beneath it | `Simulation > Convergence…` → `ase::ui::conv_dialog` |
| **10b** | the **remedy assistant with a deck diff** | `ase::ui::remedy_dialog`, `remedy_list`, `deck_diff` (LCS), `deck_diff_brief` |
| **10b** | **the sentence on the OP form** | `$w.opnote` on the Choose Analyses dialog, painted by `ase::ui::conv_op_note_paint` from `ase::ladder_ran_notes` |
| **10c** | the **run-health strip**, one line | `$top.status.health`, filled by `ase::ui::health_refresh` from `run_finished` |

**Everything the run says, it says from `ase::ui::run_finished`** — the health strip on both
arms of the exit code, and the failed-node announcement (which **names the door and lights
nothing**, see C18).

**`src/ase.tcl` — one reader and one hook, and only because a label table is content.**
`ase::runhealth_strip` orders and renders; `ase::backend::ngspice::runhealth_labels` names.
See correction **C16**.

---

## Both arms, before and after, from the `RESULT:` line

Baselines re-measured here before any edit; all seven matched the brief exactly.

| suite | headless BEFORE | headless AFTER | display BEFORE | display AFTER |
|---|---|---|---|---|
| `test_ase_conv_gui_1460` | — (new) | **ALL PASS (44)** | — (new) | **ALL PASS (103)** |
| `test_ase_window` | ALL PASS (56) | ALL PASS (56) | ALL PASS (295) | ALL PASS (295) |
| `test_ase_converge_1459` | ALL PASS (76) | ALL PASS (76) | ALL PASS (76) | ALL PASS (76) |
| `test_ase_core` | ALL PASS (638) | ALL PASS (638) | ALL PASS (638) | ALL PASS (638) |
| `test_ase_dialogs` | ALL PASS (37) | ALL PASS (37) | 1 FAILED (384) | 1 FAILED (384) |
| `test_ase_persist` | ALL PASS (49) | ALL PASS (49) | ALL PASS (153) | ALL PASS (153) |
| `test_ase_sp_1452` | ALL PASS (58) | ALL PASS (58) | ALL PASS (58) | ALL PASS (58) |
| `test_ase_preflight` | ALL PASS (235) | ALL PASS (235) | ALL PASS (235) | ALL PASS (235) |

The one display red is **`G2sens`**, issue **1436**, standing before I started, value unchanged
at `{1 1 0 1 0 Entry Entry normal}`. It is the only failure on either arm of any suite above,
and it is not mine.

**Every run in this receipt printed a `RESULT:` line.** There is no run whose absence of output
I am reading as a pass.

**`.state` byte identity: 104 committed files, 0 mismatches**, measured live through
`ase::state_load` → `ase::state_serialize` (`"…\n" ne $orig`, the comparison `test_ase_core`'s
CP7 uses). **With its control in BOTH directions in the same loop**: setting one of the three
Stage 10 keys re-serializes **differently**, and setting all three to `{}` re-serializes
**identically**. ⚠ My first measurement of this reported **104 of 104 mismatching** and was
wrong — it compared without the trailing newline `state_serialize` does not emit. Recorded
because a byte-identity number taken with the wrong comparison is worse than none.

---

## THE SABOTAGE CAMPAIGN — 55 mutations, 54 killed by name, 1 declared equivalent

One runner at a time, each launched on its own line and confirmed with `ps`; restore is `cp`
from a pristine snapshot with an **md5 compare printed every time** — **`restore: OK` on all
55 of 55, `MISMATCH` 0 of 55**, and the tree's md5s after the last one are the pristine
`639886328857ecd6807904705d006a91` / `77ef46583a213fec5baca9016c2014a7`. The table is a
name+status diff, never a count.

⚠ **WHICH OF THESE NUMBERS WERE TAKEN AGAINST THE FINAL SUITE, EXACTLY.** `m1`–`m58` were run
against the suite as it stood at 43/102; `CP7` and `m59` were added afterwards, when writing
the mutation list turned up a defect no row could see. **`m45` and `m54` were re-run at the
end, against the final 44/103 suite, and produced row sets identical to their earlier runs** —
`m45` → `GN3 OP1`, `m54` → the same seventeen — which is the evidence that the earlier numbers
stand. `CP7` is a new row that only `m59` touches, so no other line of this table could have
moved. Said out loud because *"re-run against the final suite"* is easy to write and this
table is only partly that.

| # | what I broke | rows that reddened |
|---|---|---|
| **m1** | branch currents are offered to the canvas | `NC1` `NC6` `GC1` |
| **m2** | a hierarchical name is handed to the canvas | `NC4` `NC6` `NC7` `GC1` |
| **m3** | an absent node is reported with no reason | `NC5` |
| **m4** | with no netlist map, nothing reaches the canvas | `NC6` `NC7` `GC1` `GC3` **`EE2/apt`** **`EE2/fork`** |
| **m5** | `unknown` is treated as a quieter `absent` | `NC8` |
| **m6** | a `hilight_netname` that found nothing counts as lit | **`GC1`** |
| **m7** | the door says only what it lit | **`GC3`** |
| **m8** | the canvas is painted on an empty answer | `GC2` |
| **m9** | the strip renders only the counters it has a label for | **`HL3`** |
| **m10** | the strip ignores the adapter's declared order | `HL2` `GH3` `GF2` |
| **m11** | **DECLARED EQUIVALENT** — the empty-parse early return is dropped | **none, and the reason is a proof** — see below |
| **m12** | the strip drops its leading word | `HL2` `GH3` `GF2` **`EE3/apt`** **`EE3/fork`** |
| **m13** | the strip is filled but never cleared | `GH4` `GF3` |
| **m14** | the status segment is never built | `GW0e` `GT0` `GX0` `GN0` `GH0` `GR0` `GC0` `GF0` — **eight section sentinels**, see below |
| **m15** | the deck diff compares by position | `DF1` `DF2` `DF4` `DF5` |
| **m16** | the brief diff drops its context lines | `DF5` |
| **m17** | the brief diff keeps everything | `DF3` `DF5` |
| **m19** | the form writes only the rungs it switched OFF | `GW5` `GT1` `GT2b` `GT6` `GX1` `GX2` `GX3` `GR6` |
| **m20** | a cleared master box still writes a strategy | `GW6` |
| **m21** | the typed fields are never read | `GT4` `GT6` `GW9` |
| **m22** | the rung checkboxes are ignored | **`GT2`** `GT3` `GT3b` `GT3c` `GX3` |
| **m23** | the rung fields are never disabled | `GW7` `GW8b` |
| **m24** | a cleared strategy shows a blank instead of the sentence | `GW6` |
| **m25** | OK does not refuse | **`GX2`** |
| **m27** | the note is spelled here instead of by `precheck_banner_text` | **`GX1`** |
| **m28** | a form reader with no form still reads the widgets | **`GT6b`** |
| **m29** | the rung checkbox label is typed rather than the rung's own | `GW2` |
| **m30** | only a rung with a step count gets fields | `GW3` `GW7` `GW8b` `GT0` |
| **m31** | every rung shows the transient rung's caution | `GW4` |
| **m32** | a rung that RAN AND FAILED is offered as a remedy | **`RM3c`** — see below |
| **m33** | a rung already switched on is offered again | `RM5` |
| **m34** | remedies are offered after a healthy run | `RM4` `RM6` `RM7` `RM8` `RM9` `GR7` |
| **m35** | the remedy writes only the rung it changed | **`RM3b`** — see below |
| **m36** | seed is offered from a file that cannot be read | `RM7` |
| **m37** | the seed remedy omits the mode | **`RM9`** |
| **m38** | a refused remedy keeps Apply live | `GR5` |
| **m39** | the apply path itself does not refuse | **`GR5b`** `GR0` — see below |
| **m40** | the `pending` row is offered with no form standing | 13 rows: `RM1`-`RM9`, `GR2` `GR3` `GR4` `GR7` |
| **m41** | the diff's "after" side is the same state as its "before" | `GR3` `GR6` |
| **m42** | a missing netlist shows an empty diff | `GR8` |
| **m43** | "nothing to suggest" is a blank | `GR7` |
| **m45** | the ladder sentence is painted on every analysis form | `OP1` `GN3` |
| **m46** | the sentence is written into the precondition banner | `GN2` |
| **m47** | the form that carries the sentence is a different type | **`CP2`** `OP1` `GN2` `GN3` |
| **m48** | the `Convergence…` door is removed | `GM1` `GW0e` |
| **m49** | the highlight door is present but wired to nothing | `GM2b` |
| **m50** | a finished run says nothing about the failed nodes | **`GF1`** |
| **m51** | a finished run does not refresh the strip | **`GF2`** |
| **m52** | the OP sentence is never painted on a rebuild | `GN2` |
| **m53** | the OP sentence has no widget to live in | `GN1` `GN2` `GN3` `GN4` |
| **m54** | **THE `::open` TRAP** — the log reader uses the bare `open` | 17 rows: `NC1` `NC6` `OP1` `OP3` `RM0` `RM1` `GC1` `GC3` `GF1` `GF2` `GH3` `GN2` `GR2` `GR3` `GR4` `GR5` `GR8` |
| **m56** | a typed step count does not reach the emitted line | **`GW9`** |
| **m57** | a Convergence rebuild leaves a stale assistant standing | **`GW10`** |
| **m58** | closing the form leaves the assistant standing | **`GW10`** |
| **m59** | the diff preview calls ONE backend's renderer by name | **`CP7`** — see below |

⚠ **`m44` could not be applied and is not mine.** It aimed at the `state eq {ok}` guard that
makes the OP-form sentence conditional, and that guard lives in **`ase::ladder_ran_notes`** —
issue 1459's core, whose own sabotage **m29** already reddens `LD11` for it. My side of that
rule is **m45/m47** (which form) and **OP2/GN4** (the controls).

### The results worth reading twice

* **m54 is the defect this task actually shipped and then found.** Seventeen rows, across six
  sections and both arms, from **one missing `::`** — and every one of them had been **green**
  a few minutes earlier, reading an empty string. The mutation is not hypothetical: it restores
  the code as I first wrote it.
* **m14 reddened eight SECTION SENTINELS rather than eight named rows, and that is the design
  working.** Deleting the status label makes the window's own `pack` raise, so the whole widget
  half dies — which under `--nogui --pipe` **exits 0** and would have looked like a pass. The
  per-section `catch` + `GX0`-style sentinel is what turns "the suite was killed" into a
  counted red. The brief names this shape as met seven times in this batch; it is met here too.
* **m32 and m35 SURVIVED my first list, and both were the same defect in the fixture.** RM1's
  bench has `gmin` and `src` switched **on** in its strategy, so the *already-on* guard hides
  them and the *never-ran* test is never reached: two guards, one fixture, and only one of them
  under test. And RM1's bench names **all four** rungs, so "write every rung" and "write only
  the one you changed" produce the identical dict. **`RM3c`** (an unarmed bench) and **`RM3b`**
  (a bench naming one rung) are the two rows that did not exist when I started. That is the
  brief's *"fixtures that never disagree"* and *"a sabotage missing from the generator"*, in one
  pair.
* **m39 survived for a third reason, and it is a Tk fact worth carrying.** `GR5b` pressed the
  Apply button after `GR5` had greyed it — and **`invoke` on a DISABLED button is a silent
  no-op**, so the row proved only that GR5 had run. The refusal *inside* `remedy_apply` was
  never reached. The row now calls the proc, the way a keyboard default or a later caller
  would, and reds.
* **m59 is the one I wrote the guard for AFTER finding the defect.** My first
  `ase::ui::conv_deck` called `ase::backend::ngspice::render_deck` **by name**, so a bench
  bound to any other simulator would have been shown an ngspice deck and told it was the deck
  that would run. No row could see it, because the only registered backend on this machine is
  ngspice. **`CP7`** scans the Stage 10 block of `src/ase_window.tcl` for any
  `ase::backend::<name>::` on a **code** line, with the same scan over `src/ase.tcl` — where
  the adapter really does spell its own namespace — as its positive control, so it cannot pass
  by having stopped matching. A citation in a **comment** is allowed and stays: house style
  prefers a real anchor, and a comment cannot render a deck.
* **m11 is declared equivalent, with the proof rather than a shrug.** It deletes
  `if {![llength $got]} { return {} }` from `ase::runhealth_strip`. With an empty parse the
  labelled loop appends nothing (no key exists) and the surplus loop appends nothing (no key
  exists), so the proc returns `{}` **on every input it can receive**. Kept because it states
  the intent and costs nothing; recorded here because **an unreddened mutation that is not
  declared is an unreddened mutation that is hidden**.

### The six ways a row fails to fail

1. **Fixtures that never disagree.** Controls that must answer empty: `NC2` (a log with no
   table, and a session with no log at all), `HL1`, `DF3`, `RM4`/`RM5`/`RM8`, `OP2`, `GC2`,
   `GH2`/`GH4`, `GN4`, `GR7`, `GF3`. **And two controls added because a mutation survived** —
   `RM3b` and `RM3c`.
2. **Position asked where the mechanism is last-writer-wins.** Inverted twice: **`GM1`** asks
   that `Convergence…` is *directly below* `Options…` (the sheet whose rows the strategy
   overrides), and **`GM2`** asks that the highlight door is the *last* entry of Results,
   below Annotate.
3. **An extractor that returns nothing.** Every reader goes through `g_ans` / `g_w` / `g_cfg`
   and answers a comparable value: `NOPROC`, `RAISED:…`, `NOWIDGET`.
4. **A sabotage missing from the generator.** Mine was short by **four**: `m32`, `m35`, the
   `m39`/GR5b repair, and **`m59`** — the last of which is a defect the mutation list found
   because the list was being written, not because a row caught it.
5. **Two halves tested in different suites.** **`GT`** goes from a tick in the pane to the
   rendered `optran` line; **`EE`** runs that deck on both binaries and reads the resulting
   log back through the surface; **`GF`** drives `ase::ui::run_finished` itself, because a
   surface nothing calls is a surface that does not exist — which is the defect this whole
   issue is about, one layer up.
6. ⚠ **A one-directional row.** **`NC6`** asks the resolver to account for **every** starred
   name, with the row count and the input list as controls, so a resolver that silently
   dropped one reds by arithmetic. **`HL3`** feeds the strip a counter the adapter has **no
   label for** and demands it appear anyway — a label-driven loop would print a stale set for
   ever the day the adapter reports a fifth counter, and would look perfectly correct doing it.
   **`GC1`** asks not only which names were missed but **which reason each carries**.

---

## ⚖ R9 — the sentences this surface mints, verbatim

**Everything core already mints is CONSUMED, not re-spelled**: the four rung labels and the
transient rung's caution come off the rung dicts, the three *"this operating point came
from …"* sentences from `ase::ladder_ran_notes`, and **all eleven refusals with their `Fix:`
clauses** render through `ase::precheck_banner_text` (row `GX1` asserts the note is
byte-identical to that frame's output). What follows is what a widget needs and a deck does
not. `owed.sh add rule 1460`.

### Doors and titles

```
Convergence…                               (Simulation menu)
Convergence                                (the window title)
Highlight Non-Converged Nodes              (Results menu)
Convergence Remedies                       (the assistant's title)
```

### The ladder pane

```
Operating point strategy
Steps
Step
Stop
Emits:
Emits nothing. The simulator uses its own strategy.
```

### The saved operating point

⚠ **`Save operating point` and `Restore operating point` are NOT free choices**: core's own
fix clause already reads *"run once with Save operating point ticked, or restore with force"*,
so a rename here makes that clause point at a control that does not exist. Row `CP3` asserts
the label is a substring of the live evaluator's fix clause.

```
Saved operating point
Save operating point
Restore operating point
File
Seed
Force
a starting guess; the run can move away from it, so it cannot change the answer
the simulator's own file unchanged; in a transient that is an initial condition, and it does change the answer
```

⚠ **`Seed` and `Force` are the two words the brief asked me to flag, and I am flagging them.**
They are the deck half's mode words and they **already reach the user inside a refusal**
(*"'<mode>' is not a way to restore an operating point. Fix: choose seed or force"*), so the
form uses them rather than inventing a second vocabulary for one setting — and each carries the
measurement that separates them, because a user asked to choose between two jargon words with
nothing beside them is being asked to guess. **Whether they stay is the user's ruling**, and if
they change, that fix clause changes with them.

### The run-health strip

```
Report run health
Health:
```

and the four counter words, which are **ngspice content** and live in the adapter
(`ase::backend::ngspice::runhealth_labels`), not here:

```
TRAN points          accepted          rejected          iterations
```

### The remedy assistant

```
Remedies…
Change                                            (the list's column heading)
Apply
Nothing to suggest. The last run found its operating point.
This changes nothing in the deck.
The edits open in the Convergence window
Switch on: <the rung's own label>
Save this run's operating point for next time
Seed the next run from the saved operating point
ASE-L has no netlist for this design yet, so it cannot show what the deck would become. Simulation > Netlist > Recreate.
```

(the last one composes its door from `lbl_simulation` / `lbl_netlist` / `lbl_netlist_recreate`,
the same three constants issue 1435's banner already uses)

### What a finished run says, and what the highlight says

```
ase: <n> node(s) did not converge: <names>
Results > Highlight Non-Converged Nodes lights them on the schematic.
ase: highlighted <n> node(s) that did not converge: <names>
ase: not on this sheet: <name> (<reason>), …
inside a subcircuit
this netlist has no such node
ase: the last run reported no node that failed to converge
ase: this session has no run log to read
```

⚠ **Two sentences, deliberately, and rows `CP5`/`CP6` pin the difference.** The one a finished
run prints must **not** claim to have highlighted anything — it lights nothing — and both agree
with themselves about singular and plural.

---

## Corrections to this brief and to `PLAN.md`

| | |
|---|---|
| **C15** | ⚠ **A form reader with no form standing must return the session UNCHANGED.** `conv_form_state` read three absent widgets as three cleared controls and handed back a state with `opstrategy`, `opstate` and `runhealth` all **wiped** — a reader that destroys what it was asked to describe, reachable from the remedy assistant and from anything that asks after OK. Row **GT6b**, sabotage **m28**. |
| **C16** | **The run-health strip needed a label hook, and that is why `src/ase.tcl` grew.** The brief allows core to grow *"if a reader genuinely has to"*; this one did. `tranpoints`/`accept`/`totiter` are not user copy, and a label table in the surface would put ngspice words in `ase_window.tcl`. `ase::runhealth_strip` (core) orders and renders; `ase::backend::ngspice::runhealth_labels` (adapter) names. **Every counter the parser found is in the answer, labelled or not** — row **HL3**. |
| **C17** | ⚠ **§10a's highlight cannot light a hierarchy-qualified node**, and that is a fact about the canvas rather than a limit of the map. `hilight_netname` looks a name up in **this sheet's** node hash (`hilight.c`, `bus_node_hash_lookup`), and `x1.nn` names a node inside a subcircuit. It is reported by name **with the reason**, never dropped — rows **NC4**, **GC1**. |
| **C18** | ⚠ **The highlight must not be automatic on a failed run.** Lighting a user's schematic unasked is a mutation of what they are looking at, and the highlights persist past ESC. `run_finished` **says** how many nodes failed and names the door; the user decides. Row **GF1**. |
| **C19** | **§10's `≈ +330` for `src/ase_window.tcl` is `+1150`** (about half comment). §10b is three surfaces, not one — the pane, the emitted line and the refusal note — and the assistant needs a real LCS diff, because a positional compare reports every line after an insertion as changed, which is the opposite of what the pane exists to show (row **DF4**, sabotage **m15**). |
| **C20** | ⚠ **`seed` and `force`**: see the ⚖ R9 section. Flagged for the user exactly as the brief asked. |
| **C21** | ⚠ **THE BRIEF'S OWN PROOF SHAPE FOR THE RUNG-4 CHECKBOX IS UNREACHABLE THROUGH THE FORM.** The obvious pair — the rung on, then the rung off with nothing else changed — is `optran 0 0 0 100n 10u 0` against `optran 0 0 0 0 10u 0`, and the second is **every rung off**, which `ase::opstrategy_refusals` blocks (`allrungsoff`). The pair that works has **Newton on in both**, on a circuit whose Newton rung runs and fails; it is in the headline above and is row **EE1**. The product declining to render the obvious pair is correct, and it is itself row **GX3**. |
| **C22** | ⚠ **`src/ase_window.tcl` shadows `open` and `close`.** See the second headline. A comment on one call site was not enough and this is now stated in the header of the reader that meets it first. |
| **C23** | **`ase::netlist_map_resolve` returns a hierarchical name as a DOTTED STRING**, not as a list of segments. My first expectation for row **NC4** said `{x1 nn}` and was refuted by the row. Recorded because the resolver's own header documents the shape of the *verdict* and not of `real`. |
| **C24** | ⚠ **A byte-identity measurement taken with the wrong comparison is worse than none.** My first `.state` run reported **104 of 104 mismatching**; `ase::state_serialize` does not emit the trailing newline the file carries, and `test_ase_core`'s CP7 compares `"[serialize]
"`. Re-measured: **0 of 104**, with the control disagreeing in both directions. |
| **C25** | **Tk's `invoke` on a DISABLED button is a silent no-op**, so a row that presses a greyed button proves the greying and nothing about the proc behind it. Sabotage **m39** survived on exactly that. Rows that mean *"this path refuses"* call the proc. |

---

## What I did NOT ship, and why

* **No live ladder pane.** Debt **M1** is closed and says it costs a **second capture channel**
  (`run_cmd` appends `2>@1` and every existing log reader expects one stream) **and** a
  byte-oriented reader (3 of 4 read chunks end mid-line, and the dangling text is always the
  rung being attempted). `PLAN.md` §10 allows the after-the-fact read, and that is what shipped.
  `ase::ladder_parse` is already built for both.
* **No automatic canvas highlight.** See **C18**.
* **No `rusage devtimes`.** Compiled out — issue 1459's **C2**, row `RH2` there.
* **No remedy that invents a number.** Every remedy is structural (switch a rung on, save, seed)
  and parameterised from the adapter's own defaults, so nothing in this file mints a step count
  or a settle time. The *"Pick a settle time for me"* button PLAN.md §10b sketches would be one
  — it needs a rule about tstep and fstart that belongs to the adapter, and it is not here.
* **No `look` paid.** See below.
* **`tests/run_regression.tcl` not run** — the driver's, solo (issue 0990).

---

## Ledger

Backed up before the write: `/tmp/stage10gui/owed/backup_214235` and
`/tmp/stage10gui/owed/backup_pre_add_*` (`cp -a` of `~/.claude/xschem_owed`).

| | rule | look | suite |
|---|---|---|---|
| **before** | 173 | 65 | 10 |
| **after** | **174** | **66** | 10 |

* `add rule 1460` — the control copy listed verbatim above, **and `seed`/`force` specifically**.
  The user's to answer; nothing is blocked on it. (Filed twice: the first `add` lost its
  backticked words to the shell and was re-`add`ed in place, which printed `updated rule debt`.
  Same clone, same id, thirty seconds apart; `cleared.log` carries the pre-image.)
* `add look` — ⚠ **the lit nets must be seen on the USER'S OWN SCREEN.** The canvas highlight is
  a change to the **canvas**, not to a dialog: `AUDIT_DISPLAY=:0` is **Xwayland**, and the
  screen the user looks at is `$DISPLAY` (a Windows X server over TCP). `CLAUDE.md`'s
  three-server table says a look debt asking for "the real screen" is something `:99` and `:0`
  **cannot provide**. The same debt names the four-rung pane with its checkboxes and the
  `optran` sentence beneath it, and the one-line health strip, per `PLAN.md` §10's own
  *Re-measure on the dev display* paragraph.
* **No `suite` debt filed, deliberately** — a `:0` debt is discharged by a pass on `:0`, and
  **this feature's pixel deliverable cannot be discharged that way at all**. It is a `look`,
  and a `look` clears only when the user says so.

**Suites green, please look.** Nothing in this receipt reports a pixel as done.

One added to each of two queues, **none destroyed**. No `clear` of any kind was issued.

⚠ **The four unstamped entries are still there and were not touched.**
`/usr/bin/grep -L '^repo:' ~/.claude/xschem_owed/{rule,look,suite}/*` names
`rule/1357`, `rule/1357@xschem-claude`, `look/hier_pdf_nav_1357_H6.…` and
`suite/test_hier_pdf_links_1333` — the same four the brief warned about. Against a stamped
ledger a bare entry can only have arrived one way, and claiming one for this clone erases the
only signal the overwrite left. They are another clone's; they stay.

---

## Debts this task leaves

1. ⚖ **The sentences above** — `owed.sh add rule 1460`. **Blocking nothing.**
2. 🔭 **The lit nets, the pane and the strip, on `$DISPLAY`** — `owed.sh add look`.
3. ⚠ **The live ladder pane is still unbuilt**, and the price is measured:
   `evidence/ladder-streams.md` §1–§3. Whoever builds it should know that
   `ase::ladder_parse` already reports an unterminated trailing trial as the rung in progress —
   the one event a live pane exists to show is the one that is never newline-terminated while
   it matters.
4. **`ase::ui::deck_diff` is a general LCS line diff with no other caller.** If a second
   preview ever wants one (the Options sheet's *effective* view is the obvious candidate), it
   should call this rather than grow a second.
