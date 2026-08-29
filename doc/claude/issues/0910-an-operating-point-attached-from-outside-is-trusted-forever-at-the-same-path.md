# 0910 — an operating point attached from OUTSIDE the annotation surface is trusted FOREVER, so the previous run's numbers survive at the very same path

STATUS: FIXED 2026-08-28 (item B1) — one branch in `op_annot::db_current`, guard
**G3a-2**. First measured 2026-08-28 by item A15's adversary pass, on the tree that
ships the 0684 fix, RE-MEASURED by A15's write-up agent on the delivered tree before
filing, and reproduced byte for byte a third time by B1 before the repair. This was
issue **0684's own defect**, alive on two shipped menu items. §7 records the delivery.
⚠ **FIXED for the ordinary spelling of the path and the ordinary re-run.** Two
measured states still bring §1's transcript back and are filed separately:
[0916](0916-a-symlinked-results-path-defeats-the-same-path-test-so-the-previous-runs-numbers-survive.md)
(the candidate is a symlink to the attached file) and
[0915](0915-a-re-run-inside-the-same-second-at-the-same-byte-length-is-invisible-to-the-freshness-stamp.md)
(a re-run inside one second at the same byte length). §11 has both.
⚠ **This fix also broke the ordinary bench and was repaired in the same item** —
see §8 and [0914](0914-a-waveform-graph-open-in-the-same-window-blocks-the-press-from-reloading-the-operating-point.md).
FOUND IN: `op_annot::db_current` guard **G3a**, which on HEAD `85159039` was the
single line `src/op_annot.tcl:1003`
(`if {![info exists _db_src($key)]} { ::op_annot::_db_stamp $np ; return 1 }`).
That line number is the DEFECT's address, not the fix's: the branch that replaced
it is longer, so everything below it has moved.
RELATED: [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md) §8
(whose route table this refutes — corrected there),
[0908](0908-the-annotate-tick-can-show-another-corners-operating-point.md) (a
DIFFERENT path; this one is the SAME path).

---

## 1. What the user does, and what they see

`Simulation > Graphs > Annotate Operating Point into schematic`
(`src/xschem.tcl:16091`) or the waveform window's `Waves > Op Annotate`
(`src/xschem.tcl:15713`) — both a bare `xschem annotate_op`. Numbers appear. Then
the simulation is re-run, rewriting **the same file**. Press `6`, `6` again, `6` a
third time: the sheet keeps repainting the FIRST run's numbers, under a sentence
saying the results were already loaded. Measured, delivered tree, headless:

```
G3| USER PICKS  Waves > Annotate Operating Point  (a hand attach: no press of 6 yet)
G3| ---- the simulation is RE-RUN: the same path now holds id=9e-03 ----
G3| after the FIRST press of 6
G3|     sheet paints : id = 10u | gm = 100u | gds = 1u        (disk holds id=9e-03 = 9m)
G3|     status line  : Showing device operating-point values on the schematic. These results were already loaded.
G3| after the SECOND press of 6   -> id = 10u | gm = 100u | gds = 1u
G3| after the THIRD press of 6    -> id = 10u | gm = 100u | gds = 1u
```

ASE-L's `Results > Annotate` tick, and `ase::ui::annot_refresh_here`, behave the
same way in the same state (adversary probe `g4.tcl`). It does not self-correct,
ever. This is RULING **D5-1** and invariant **I3** — *"not the previous run's
number"* — in their own words, which is exactly what 0684 was filed about.

## 2. Why the 0684 fix does not catch it

Guard G3a stamps at the first **observation**, not at the **attach**:
`op_annot::db_current` calls `_db_stat $np`, which stats the file *now*. When the
attach happened outside `op_annot::db_attach` — which is the only place that
stamps at attach time (the proc at `src/op_annot.tcl:1070`, its stamp at `src/op_annot.tcl:1107`) — the first question is asked
AFTER the re-run, so the stamp minted describes **run 2's file** while the
in-memory database is **run 1's**. From then on G3b (`the stamp still matches`)
answers "current" forever.

"Trusted on first sight and revalidated from then on" is the property 0684 §8
claims. Measured, it is **trusted forever** whenever the first sight lands after
the change.

## 3. Why the trust arm exists at all, so nobody deletes it blind

G3a is what keeps rows N5, N10 and V31b of `tests/headless/test_op_annot.tcl`
green: they hand-attach a database and expect the `live` arm. A predicate that
answered 0 on first sight would also re-read a good file, for nothing, on the
first press after every attach (58 ms at 40 000 vectors — 0684 §8's cost table).

## 4. The narrow fix, and why it is believed safe

When the attached path **equals this surface's own candidate**, first sight
should RE-ATTACH rather than trust. A re-read of a file that has not changed is
correct and costs one read. G3a's stated reason for trusting does not require
trusting the *same* path — it only requires trusting a database whose path is
**not** the candidate, and that is the arm guard G4 already owns (issue 0908).
Not done here: it is a behaviour change on the surface item A15 had just
stabilised, and it wants its own acceptance row (attach from the menu, re-run,
press `6` once — the row A15's suite does not have, because row F7 takes its
first look *before* the rewrite).

## 5. Not covered by the existing rows

`tests/headless/test_annot_stale_0684.tcl` row **F7** stages
`annotate_op` → ask → rewrite → ask, i.e. it observes while the file is still
run 1, so its stamp is correct. The user's order is attach → walk away → re-run →
**first** observation. No row in the tree stages that order.

## 6. The acceptance rows, in the tree and RED (item B1's plan+red pass, 2026-08-28)

Line numbers above were re-measured on HEAD `85159039`; the ones this file
carried (`:984`, `:1088`) had drifted and are corrected in place.

Section 1's transcript was reproduced byte for byte on that HEAD, on all three
surfaces, with a counting proxy in front of `op_annot::db_attach`: **three
presses of `6` re-read the results file ZERO times.** The window is not slow to
notice the rewrite — it never looks.

Six new rows and two restatements live in
`tests/headless/test_annot_stale_0684.tcl`. All of them are RED on HEAD except
F40, which is green before and after and is the row that stops the repair
becoming "trust nothing":

| row | what the user does | red on HEAD |
|---|---|---|
| F36 | menu attach → re-run at the same path → `6`, `6`, `6` | yes |
| F37 | the same on ASE-L's `Results > Annotate` tick | yes |
| F38 | the same through `ase::ui::annot_refresh_here` | yes |
| F39 | POSITIVE TWIN: menu attach, nothing re-run, `6` ×3 | yes (the read count only) |
| F40 | 0908 TWIN: first press while another corner is loaded by hand | **no — green both sides** |
| F41 | the three first-sight arms, asked of the mint | yes (arm a only) |
| F7 | restated: its old gold `{1 0}` asserted the property this issue refutes | yes |
| F10b | restated: its first-look leg golded the same property | yes |

**F39's gold is ONE read across three presses, not zero.** Zero is the defect
(the first press trusts a database it has never looked at); three would be an
unconditional re-read on every press, which row F19 refuses. One is the price
§4 states out loud, and the row says so in its own comment so a later reader
does not "fix" it back.

**Every chord row must set `::netlist_dir` to its own directory** so the
candidate really is the attached file — otherwise guard G4's different-path arm
answers first and the row cannot see this defect at all. Each row also gets a
fresh `mos.raw`, so no earlier row's freshness stamp can put the question on
the second-look path where the shipped tree is already right.

Measured with §4's fix installed as a shadow proc (no repo file touched):
`test_annot_stale_0684` 45/45, `test_op_annot` 475/475 headless and 482 on the
display arm, `test_annot_blank_cause_0909` 27/27, `test_annot_show_menu` 36/36.
Rows N5, N10 and V31b — the ones §3 warns about — are undisturbed, because none
of them hands `db_current` a candidate equal to the attached path.

## 7. Delivered (item B1, 2026-08-28, on HEAD `85159039`)

### What changed, in one place

`op_annot::db_current`'s first-sight branch. It used to be one line —
*"never seen this file before, so trust it"*. It now asks **which** file:

* **the attached path IS the path this surface would load itself** → answer NOT
  CURRENT, and the caller re-attaches. That is the whole repair.
* **anything else** (a different path, or no candidate at all) → unchanged: stamp
  it and trust it. That arm is issue 0908's promise and rows N5, N10 and V31b of
  `tests/headless/test_op_annot.tcl` stand on it.

Nothing else moved: not guard G4, not `op_annot::db_attach`, not the two callers
(`utils/annot_mode.tcl:1098`, `src/ase_window.tcl:2388`), not the menu items, not
`cadence::_annot_raw_candidate`'s netlist_dir fallback (issue 0911, out of scope).

**No new sentence was minted.** Where the press used to say *"These results were
already loaded."* it now says *"Loaded results from &lt;path&gt;."* — an existing
mint at `utils/annot_mode.tcl:900`. No wording ruling is owed.

⚠ **The two emptiness terms in that branch are NOT load-bearing on this Tcl,
and this paragraph used to say the opposite.** It claimed `$cand ne {}` had to
stay above the `file normalize` because `file normalize {}` answers the current
working **directory**. Measured in the interpreter this runs in, **Tcl 8.6.14
answers the EMPTY STRING** — so with no candidate the comparison is false either
way and control falls through to stamp-and-trust, which is the answer the
no-candidate case wants. The paragraph also named row F41 leg c as the witness;
F41 is green with either term deleted, and so is every other row in the tier
list. The terms stay — deleting a guard because no row can see it is the trap
0684 §9 catalogued six of — and row **F46** is now the real, structural witness,
whose first leg re-measures `file normalize {}` on every run. §9 records the
correction; the source comment was corrected in the same pass.

### What the user sees now, same probe, same order

```
G3| USER PICKS  Waves > Annotate Operating Point  (a hand attach: no press of 6 yet)
G3| ---- the simulation is RE-RUN: the same path now holds id=9e-03 ----
G3|      the chord's own candidate is THE SAME FILE
G3| after the FIRST press of 6
G3|     sheet paints : id = 9m | gm = 7m | gds = 50u        (disk holds id=9e-03 = 9m)
G3|     status line  : Showing device operating-point values on the schematic. Loaded results from .../mos.raw.
G3| after the SECOND press of 6   -> id = 9m | gm = 7m | gds = 50u
G3| after the THIRD press of 6    -> id = 9m | gm = 7m | gds = 50u
G3|     three presses re-read the results file 1 times
G4| menu attach, then the RE-RUN, then Results > Annotate is ticked
G4| after the FIRST tick  -> id = 9m | gm = 7m | gds = 50u   (two ticks, 1 read)
G5| ase::ui::annot_refresh_here answers 1 and the sheet shows -> id = 9m | gm = 7m | gds = 50u
P1| menu attach, NOTHING re-run: press 6 x3 -> 10u / 10u / 10u, 1 read total
P2| another corner attached by hand, candidate is a DIFFERENT file:
P2|     still painting from the corner file, its sentinel vector still at index 3,
P2|     "These results were already loaded.", 0 reads
```

§1's transcript is gone on all three surfaces, and P1/P2 — the two ways this
repair could have been wrong — are intact.

### Suites, measured on the delivered tree

| suite | before | after |
|---|---|---|
| `test_annot_stale_0684` (headless / display) | 39 / 39, **7 FAILED** with the new rows in | **46 / 46 both arms** |
| `test_op_annot` (headless / devdisplay / run_regression display arm) | 475 / 482 / 483 | 475 / 482 / 483 |
| `test_annot_blank_cause_0909` | 27 | 27 |
| `test_annot_show_menu` (display) | 36 | 36 |
| `tests/run_regression.tcl` | 43 blocks, ZERO counted failures | **43 blocks, ZERO counted failures** |

The only count that moved is this issue's own suite, 39 → 46: seven new rows, none
removed.

### A guard this fix left without a witness, and what was done about it

`op_annot::_db_forget` with **no argument** throws away every freshness stamp
this window holds the moment nothing publishable is attached (`Waves > Clear`, a
graph replacing the database, another surface detaching it). Row **F7** used to
be its witness: it hand-attached a path this file had already stamped and
required the FIRST look to answer "current". After this fix that same first look
answers "re-read" whether or not a stale stamp survived, so F7 can no longer tell
the two apart. Measured by neutralizing the no-argument form and re-running the
whole file: **46 of 46 still passed, nothing moved.**

Leaving a guard with no witness is the exact trap issue 0684 §9 catalogued six of,
so row **F42** was added — structural, like F8: the forget-all must sit on the
not-attached arm, above every question about paths, and be called with no
argument. Both the proc's own comment and the row state out loud that the
behavioural witness is gone, so the next reader does not go looking for one.
Neutralizing the guard reds F42 and nothing else, which is the point.

### Sabotage

Restoring the shipped one-liner (`{ ::op_annot::_db_stamp $np ; return 1 }`) —
i.e. HEAD itself — reds **seven** rows on both arms: **F36** (the headline), F37,
F38, F39, F41, and the two restatements F7 and F10b. F40 stays green, which is
the point of it. Separately, deleting the `::op_annot::_db_forget` call from
`db_current`'s not-attached arm reds **F42** alone.

---

## 8. WHAT THIS FIX BROKE ON THE ORDINARY BENCH, AND THE REPAIR (issue 0914)

Everything above was measured with **an empty window** — the operating point
attached and nothing else. The bench does not look like that: the user has a
waveform graph on the sheet, which is a second database in the same registry.
Add that one line to §6's own P1 staging and the answer inverts.

```
  a waveform strip is open on the sheet
  Waves > Op Annotate   ->  id = 10u | gm = 100u | gds = 1u
  NOTHING is re-run
  press 6               ->  id =  | gm =  | gds =
  registry, before:  1 current / 0 …/foreign.raw tran / 1 …/mos.raw op
  registry, after :  0 current / 0 …/foreign.raw tran
```

The operating point the user had just loaded is **deleted**, on a press that
changed nothing on disk. It is this fix's own doing: before it, that first press
trusted the database and never detached; after it, the press detaches — and
`cadence::annot_mode` then asks `xschem raw loaded`, sees the user's graph, and
takes the "a raw is loaded, so stop" arm instead of going to re-attach. On HEAD
the identical probe passes; on the delivered tree it destroys the numbers.

Found by item B1's sabotage pass, which called this run a FAIL for it. Repaired
in the same item: see **[0914](0914-a-waveform-graph-open-in-the-same-window-blocks-the-press-from-reloading-the-operating-point.md)**,
which also carries the half that was broken on HEAD too (press 6, re-run, press 6
with a graph open blanked on the shipped tree), and the second door the repair
had to close — the unwind's whole-registry `xschem raw clear`.

**The lesson for the next reader of this file:** every hand-attach row in
`test_annot_stale_0684.tcl` up to F42 stages an empty window, so a green run here
says nothing about the state a user is actually in. Rows F43, F43b, F44 and F45
are the ones that stage the bench.

## 9. A CLAIM IN §7's SHIPPED COMMENT THAT WAS FALSE

The comment this fix left in `src/op_annot.tcl` said `$cand ne {}` had to stay
above the normalize because **`file normalize {}` answers the current working
directory**, and named row F41 leg c as its witness. Measured in the interpreter
this actually runs in, **Tcl 8.6.14 answers the EMPTY STRING**, and F41 is green
with the term deleted — as is every other row in the tier list. Both sentences
were wrong and both are now replaced by the measurement; row **F46** is the real,
structural witness, and its first leg re-measures `file normalize {}` on every
run so a Tcl that behaves differently reddens the suite instead of quietly
changing what the branch means. The terms themselves stay: deleting a guard
because no row can see it is the trap 0684 §9 catalogued.


## 10. The acceptance list, walked, with the row that pins each point

Item B1's brief set seven acceptance points. Each one now has a row, and this is
which:

| # | the brief's acceptance point | pinned by |
|---|---|---|
| 1 | reproduce §1's transcript on HEAD as the BEFORE | done three times — the adversary probe that filed this issue, B1's recon, and B1's implementer, all byte for byte. §1 is that transcript; §7 is the same probe after |
| 2 | attach from the menu, re-run the same path, press `6` — the sheet paints the NEW numbers, and presses 2 and 3 agree | **F36** (the `6` chord, all three presses, plus the sentence and the read count) |
| 3 | the same for ASE-L's `Results > Annotate` tick and `ase::ui::annot_refresh_here` | **F37** (the tick) and **F38** (`annot_refresh_here` — its answer AND the painted numbers together, because on the shipped tree it answered 1 while showing run 1) |
| 4 | POSITIVE TWIN: attach from the menu, change nothing, press `6` three times — the numbers stay, and nothing is needlessly re-read | **F39**, whose gold is **one** read across three presses, not zero. Zero is the defect; three is an unconditional re-read on every press, which row F19 refuses. The row carries its own comment saying so |
| 5 | 0908 TWIN: a press whose candidate names a DIFFERENT path leaves the attached database exactly where it is — proved with a row | **F40** on the first press (the sight this fix changes) and **F41 leg b** on the mint itself. F40 is green before and after; it reds under a "distrust everything" variant, together with F5, F20, F27, and with N5, N10 and V31b of `tests/headless/test_op_annot.tcl` |
| 6 | rows land in `tests/headless/test_annot_stale_0684.tcl` | all of them do: F36–F47, plus the restatements of F7 and F10b. 39 → 52 checks |
| 7 | sabotage: neutralize the new stamp-at-attach logic and name the row that reds | restoring the shipped one-liner — i.e. HEAD itself — reds **F36** (the headline), F37, F38, F39, F41, F7 and F10b, seven rows on both arms, with F40 green. Moving the same test below guard G3b reds the same seven. Deleting guard G8's attach-time stamp reds F2, F4, F9, F10b, F19, F30, F36, F37, F39, F41 here **and BC5 / BC5b in `tests/headless/test_annot_blank_cause_0909.tcl`** |

**The brief's acceptance point 4 could not be golded as written** and the reason
is worth keeping: it asked for "nothing was needlessly re-read", and the shipped
tree's answer to that is ZERO reads across three presses — which is the defect
itself, the first press trusting a database it has never looked at. One read is
the price §4 states out loud.

Two of the brief's own line numbers had drifted by the time the work started
(`:984` for guard G3a, `:1088` for `op_annot::db_attach`); they were re-measured
and corrected in this file in §2.

**Issue 0911 is NOT closed by this**, and that was checked rather than assumed:
0911 is the descended-sheet case where the candidate names the SUBCELL's raw
while the design paints from the TOP's — a **different** path, answered by guard
G4's "not mine, leave it alone" arm, which this fix does not touch. Rows F40 and
F41 leg b hold that arm green on both sides. `cadence::_annot_raw_candidate`'s
netlist_dir fallback was not touched, and neither was `src/token.c`.

## 11. What is still open at this path, after all of the above

Two states in which the sentence in §1 still comes back. Both are filed, both
measured on the delivered tree, neither is a regression from this item:

* **[0915](0915-a-re-run-inside-the-same-second-at-the-same-byte-length-is-invisible-to-the-freshness-stamp.md)**
  — a re-run inside the same wall-clock second writing the same number of bytes
  is invisible to the `{mtime size}` stamp, so from the **second** press on the
  sheet keeps the previous run's numbers. This fix narrowed the window (the
  first press after a menu attach now re-reads regardless) without closing it.
  Named as a limitation in three places since 0684 and never given a number
  until now.
* **[0916](0916-a-symlinked-results-path-defeats-the-same-path-test-so-the-previous-runs-numbers-survive.md)**
  — when `<netlist_dir>/<cell>.raw` is a **symlink** to the file the menu
  attached, `file normalize` does not resolve the final component, so the
  same-path test in G3a-2 never fires and §1's transcript reproduces word for
  word on a tree where this issue is marked FIXED.

And one behaviour change that no row covers, recorded so nobody re-derives it as
a defect: a hand attach whose results the ASE session already calls out of date,
or whose file has since been deleted, is now taken off on the **first** press
where the shipped tree kept it forever. Both match what the chord already did on
the second look, and both match rulings **0838** and **I3** ("a run that failed
must not leave the previous run's numbers live"), so neither is filed as a
defect — but the deleted-file half is the state
[0912](0912-the-two-operating-point-surfaces-disagree-when-the-results-file-is-deleted.md)
is about, and 0912 is blocked on a user ruling.
