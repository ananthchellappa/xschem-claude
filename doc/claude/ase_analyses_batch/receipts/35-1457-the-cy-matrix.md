# Issue 1457 — the matrix picker hid the `Cy` family on every run with more than two ports

**One task, issue 1457.** Files I own and touched, and nothing else: **`src/ase.tcl`**,
**`tests/headless/test_ase_sp_1452.tcl`**, **`tests/headless/test_ase_dialogs.tcl`**,
plus `doc/claude/issues/1457-*.md` and this receipt. **`src/ase_window.tcl` was NOT
modified** — its md5 is byte-identical to the pristine snapshot taken at the start
(`d273ac3870211ce5a73b18174f74d4b3`), verified after every one of the twenty sabotage
restores. No commit, no `git add`, no stash, no restore, no clean, no push. `tests/run_regression.tcl`
not run (issue 0990 — the driver's, solo). **No simulation on any bench under `sky130A/` or
`ihp-sg13g2/`**: every simulator run below is a hand-written deck or an ASE-L-rendered deck in
`/tmp/cy1457` or the suite's own scratch dir, against an explicit binary path. Nothing under
`~/.xschem/` was opened for writing.

**Floors:** `test_ase_sp_1452` **50 → 58** (both arms, identical rows);
`test_ase_dialogs` **37 / 382 → 37 / 384** (headless unmoved — every SP row drives real
widgets). Each file's own `AND RAISED` paragraph is in the same diff.

`src/ase.tcl` **+46 −15**, `test_ase_sp_1452.tcl` **+329 −24**,
`test_ase_dialogs.tcl` **+228 −52**.

---

## ⚠ THE HEADLINE: THE END-TO-END ROW I WROTE FIRST WOULD HAVE PASSED THE DEFECT

SE3 runs an ASE-L-rendered three-port flagged deck on both binaries and asks whether every
vector the picker offers is in the results file. It passed, on both binaries, first time. It
would **also** have passed with the bug still in.

Because 1457's defect is not a broken promise, it is a **missing** one: with `Cy` re-gated on
`n == 2`, `sp_vectors` promises 27, the file holds 36, all 27 promised are present, the missing
list is empty, green. The direction that matters is the **surplus** — what the run wrote and the
picker never offered — and an end-to-end row is blind to it unless it is asked for explicitly.
SE3 now folds the file's own matrix-shaped names and checks them *back* against the promise.
Measured after the fact: under sabotage **m1** (the shipped defect restored) SE3 reddens on
**both** binaries.

This is the same lesson as the issue's own headline, one level up. `SX2` was *green and wrong*
because its expectation was transcribed. SE3 would have been *green and blind* because its
question was one-directional. **A row that runs the real thing is not automatically a row that
would notice.**

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

| claim | evidence |
|---|---|
| the six-shape matrix table (2/3/**4** ports × flag off/on) | **MEASURED HERE**, six decks I wrote, on **both** binaries, counted from the `Variables:` block of the written rawfile. The N == 4 shapes are **new** — the driver's table had two port counts, and two points do not establish "N×N" |
| `Cy` follows the flag at any N; only the four scalars need N == 2 | **MEASURED**, the same six decks. Confirms the driver's brief exactly |
| apt 45.2 folds the rawfile (`i(cy_1_1)`, `nf`, `sopt`, `y_1_1`) and the fork preserves (`i(Cy_1_1)`, `NF`, `SOpt`, `Y_1_1`) | **MEASURED HERE** on all six decks, not taken from `sp-stage9.md` |
| `i(Cy_3_3)` is accepted and bare `Cy_3_3` rejected **at N == 3** | **MEASURED**, through `wviewer::validate_rpn` against the **real three-port variable list of each binary**, extracted from my own rawfiles, with `i(Cy_9_9)` as the negative control. The brief told me not to assume this generalises from N == 2; it does, and now that is a measurement |
| the emitted card carries the trailing noise flag at 2, 3 and 4 ports alike | **MEASURED**, `render_deck` rendered at each shape — `sp dec 3 100meg 1g 1` |
| an ASE-L-rendered three-port flagged deck really answers all 36 | **MEASURED**, run on both binaries as row SE3 |
| the picker's 3×3 `Cy` layout with no scalar strip | **MEASURED through the real widgets** on the dev display, row SP9b — grid rows, grid columns and a collision check over every gridded child |
| baselines: sp 50/50, dialogs 37 / 1 FAILED (382) with `G2sens` = `{1 1 0 1 0 Entry Entry normal}`, core 636 | **RE-MEASURED HERE** before I edited anything; all four matched the brief |
| 104 committed `.state` files | **COUNTED LIVE** (`git ls-files \| grep -c '\.state$'` → 104); round trip is `test_ase_core` (636, unmoved on both arms) and section SC (unmoved) |
| `span.c:74-178`, `vsrc.c:31-37`, `rawfile.c:934-1022` | **TRANSCRIBED** from issues 1452/1454. Their *behaviour* is measured here; their line numbers are not. ⚠ `span.c:74-178` is the exact citation that produced this defect — it is true of the noise **parameters** and not of the correlation matrix |

---

## What shipped — `ase::backend::ngspice::sp_matrix`

One gate became two, and that is the whole fix:

```tcl
    if {[::ase::field_value ngspice sp $row donoise] eq {}} { return $out }
    # The correlation matrix follows the flag at ANY N -- measured at 2, 3 and 4.
    …Cy_i_j, N x N, expr "i(Cy_i_j)"…
    if {$n != 2} { return $out }
    …NF NFmin Rn SOpt…
```

The `if {$n != 2}` is deliberately **below** the `Cy` loop rather than folded back into the
first line, with a comment saying that offering the scalars there would be *"the mirror image of
issue 1457's own defect"*. `sp_vectors` is unchanged — it is `sp_matrix` flattened, so it
inherited the fix exactly as it had inherited the bug.

The proc's comment block, which **asserted the defect in prose**, is replaced by the six-shape
transcript and a paragraph naming the `span.c` misreading, so the next reader cannot re-derive it.

---

## The rows, and how they avoid being green-and-wrong

**SX2 is now five rows, because one row cannot separate two opposite mistakes.** `Cy` dropped at
N != 2 and the four scalars offered at N != 2 move the totals in opposite directions and are
different defects; the brief called a row that catches only one of them half a row.

| row | what it asks | which mistake |
|---|---|---|
| **SX2** | the six totals — 12 / 20 / 27 / 36 / 48 / 64 | both, from the totals |
| **SX2b** | the family list at each shape — the flag alone decides `Cy`, the port count alone decides `Noise` | both, head-on and separately |
| **SX2c** | per-family **counts** through `_families` / `_of` — a `Cy` stuck at a fixed 2×2 keeps the token and still fails | a wrong-sized grid, which the totals alone could miss |
| **SX2d** | the nine names **and** the nine expressions, spelled out | a transposed or unwrapped grid |
| **SX2e** | the four scalars **by name**, present at 2-on and in no other shape | the scalar half, so the totals cannot be tricked out of it |
| **SX2f** | the emitted **card**'s flag and the matrix's `Cy` family agree at every N | the **mirror tidy-up** — see below |
| **SE3** (×2 binaries) | the real run: nothing promised is missing **and nothing written is unoffered** | both, end to end |
| **SN5b** | the caution's own words, verbatim | the clause this issue nearly added |

**SX5** was rewritten from one shape to five. `sp_vectors` inherited 1457 *by construction*,
which is the mechanism working — and is exactly why a flattening row that only ever looks at
N == 2 cannot notice. **Measured, not asserted:** sabotage **m7b** applies a port-count gate to
`sp_vectors` alone *and rolls SX5 back to the form issue 1454 shipped* — the suite came back
**`ALL PASS (55 checks)`**. The old row could not see it.

**SP9b/SP9c** are section SP's first three-port rows. SP7 asked for 12 cells and SP9 for 20,
both on the two-port bench, so the GUI half was green too. SP9b asks for all 36 cells, the 3×3
`Cy` geometry (three distinct grid rows, three distinct grid columns), the **absence** of the
four scalars, the family headings, and that **no two gridded children of the picker share a
cell** — a four-matrix stack with no scalar strip is a geometry `matrix_dialog` had never been
handed. SP9c ticks a three-port `Cy` cell and follows it to an Outputs row.

⚠ **SP9c caught a real ordering fact on its first run.** I wrote it expecting the ticked order;
`matrix_ok` walks `ase::analysis_matrix`, so `S_3_1` lands above `Cy_3_3` however they were
ticked. That is deterministic and is now asserted rather than sorted away.

---

## ⚠ THE GAP MY FIRST SABOTAGE LIST DID NOT HAVE — SX2f

The brief warned that the first list would be short and that the missing ones are the expensive
ones. Mine was short by one and it is the one that matters: **1457 is the picker offering FEWER
vectors than the run writes, and the mirror image is the picker offering MORE.** It is one
plausible edit away — the caution says the noise figure is not computed above two ports, so
"stop emitting the trailing flag there" reads like a tidy-up. It would leave 36 cells on screen
that no rawfile ever fills.

Measured before writing the row: the card is `sp dec 3 100meg 1g 1` at two, three **and** four
ports. SX2f asserts the **pairing** (card's flag ⇔ matrix's `Cy`) at every shape, with the two
literal cards as the positive control so a `NOCARD` or an always-false reader cannot pass. This
is issue 1449's rule — two halves of a feature tested in different suites never meet — applied
to the two halves of one gate.

---

## ⚠ AND A SUITE DEFECT THE CAMPAIGN FOUND: THIRTEEN CHECKS, THE SIXTH TIME

Sabotage **m17** makes `ase::analysis_matrix_of` stop filtering by family. `matrix_dialog` then
builds `cS_1_1` once per family and Tk raises `window name "cS_1_1" already exists in parent`
**out of `$cw.matrixbtn invoke`**. Measured on the first pass:

```
=== m17 dlg: RESULT: 2 FAILED (370 passed)      <- 385 is normal
UNEXPECTED ERROR: window name "cS_1_1" already exists in parent
```

**SP7 through SP13 — thirteen checks — stopped running, and the row that should have gone red
never reported.** This is the "a read that raises kills the file" shape for the **sixth** time in
this batch and the third-plus inside section SP alone. The twist is that the raise came from the
**product**, not from a suite read: a dialog that raises on the way up *is* a defect and must
redden a row.

Fixed: `mx_open` (catching; answers `.nosuchmxwin` and puts the message in `::MXERR`), plus
`mx_caps`, `mx_cells`, `mx_slots`, `mx_title`, `mx_fmts`, `mx_click`. **Every** picker open,
click and read in section SP now goes through one — SP7, SP8, SP8b, SP9, SP9b, SP9c, SP10,
SP11b and SP13. After the repair the same mutation reads:

```
=== m17 dlg: RESULT: 9 FAILED (376 passed)      <- 376 + 9 = 385, nothing lost
   SP7 SP8 SP8b SP9 SP9b SP9c SP11b SP13   (+ the standing G2sens)
```

**Eight named rows and zero missing checks**, where before it was two rows and thirteen checks
into the void.

---

## Both arms, before and after, from the `RESULT:` line

Baselines re-measured here before any edit; they matched the brief exactly.

| suite | headless BEFORE | headless AFTER | display BEFORE | display AFTER |
|---|---|---|---|---|
| `test_ase_sp_1452` | ALL PASS (50) | **ALL PASS (58)** | ALL PASS (50) | **ALL PASS (58)** |
| `test_ase_dialogs` | ALL PASS (37) | **ALL PASS (37)** | 1 FAILED (382) | **1 FAILED (384)** |
| `test_ase_core` | ALL PASS (636) | **ALL PASS (636)** | ALL PASS (636) | **ALL PASS (636)** |

The one display red is **`G2sens`**, issue **1436**, standing before I started, value unchanged
at `{1 1 0 1 0 Entry Entry normal}`. It is the *only* failure on either arm of any suite below,
and it is not mine.

⚠ **SE3 and SE1/SE2 start real simulators and both ran**, on `apt` and on `fork` — no `SKIPPED`
line in either arm's log. Every run above printed a `RESULT:` line; there is no run in this
receipt whose absence of output I am reading as a pass.

**Neighbourhood, headless, all ALL PASS and all with a `RESULT:` line:**

| suite | | suite | |
|---|---|---|---|
| `test_ase_window` | 56 | `test_ase_simreg_0931` | 117 |
| `test_ase_persist` | 49 | `test_ase_simcaps_0948` | **211** |
| `test_ase_launch` | 28 | `test_ase_simdlg_0937` | 5 |
| `test_ase_interact` | 10 | `test_ase_current_repair` | 51 |
| `test_ase_preflight` | 235 | `test_ase_result_case` | 31 |
| `test_ase_meas_1443` | 113 | `test_ase_simchoice_1395` | 31 |
| `test_ase_options_1437` | 75 | `test_ase_optsheet_1441` | 62 |
| `test_ase_predeck_1439` | 78 | `test_ase_effective_1442` | 92 |
| `test_ase_view` | 32 | | |

⚠ **`test_ase_simcaps_0948` reads 211, not receipt 33's 199.** That is **not mine** — it is
HEAD's own commit `88ba4a16 fix(1453)`, whose section XE raised the floor to 211 and says so in
the file's own history block. Checked rather than assumed.

`.state`: **104** committed files, `test_ase_core` (which owns the byte-identity row) unmoved at
636 on both arms, and section SC unmoved. No schema change here — `sp_matrix` is a *reader*,
nothing it does reaches a stored key.

---

## THE SABOTAGE CAMPAIGN — 20 mutations, 0 survivors

One runner at a time, each on its own line; restore is `cp` from a pristine snapshot with an
**md5 compare printed every time** — all four files `OK` on all twenty runs, no `MISMATCH` ever.
The table is a name+status diff, never a count.

| # | what I broke | sp | dlg | rows that reddened |
|---|---|---|---|---|
| **m1** | **THE SHIPPED DEFECT RESTORED** — `Cy` gated on the flag **and** `n == 2` | 8 FAILED (50) | 3 FAILED (382) | `SX2` `SX2b` `SX2c` `SX2d` `SX2f` `SX5` **`SE3/apt`** **`SE3/fork`** · `SP9b` `SP9c` |
| **m2** | THE MIRROR — the four scalars offered at any port count | 7 FAILED (51) | 2 FAILED (383) | `SX2` `SX2b` `SX2c` `SX2e` `SX5` `SE3/apt` `SE3/fork` · `SP9b` |
| **m3** | `Cy` emitted as a fixed 2×2 whatever N is — family present, wrong size | 6 FAILED (52) | 3 FAILED (382) | `SX2` `SX2c` `SX2d` `SX5` `SE3/apt` `SE3/fork` · `SP9b` `SP9c` |
| **m4** | `Cy` stops following the flag at all | 6 FAILED (52) | 2 FAILED (383) | `SX1` `SX2` `SX2b` `SX2c` `SX2e` `SX2f` · `SP7` |
| **m5** | `Cy`'s plot expression is its bare name | 2 FAILED (56) | 2 FAILED (383) | `SX2d` `SX3` · `SP9c` |
| **m6** | `sp_vectors` keeps its own list instead of flattening | 4 FAILED (54) | — | `SX2e` `SX5` `SE3/apt` `SE3/fork` |
| **m7** | `sp_vectors` re-acquires a **port-count gate of its own**, matrix intact | 3 FAILED (55) | — | `SX5` `SE3/apt` `SE3/fork` |
| **m7b** | **m7 against the SX5 issue 1454 shipped** (N == 2 only) | 2 FAILED (56) | — | **`SE3` only — the old SX5 was GREEN.** See below |
| **m8** | the `Cy` grid transposed in the **name** only, `i`/`j` keys untouched | 1 FAILED (57) | — | `SX2d` — and only `SX2d`; the layout is unchanged so no GUI row can see it |
| **m9** | the picker lays every family out as a wrapped strip | ALL PASS | 3 FAILED (382) | `SP7` `SP9b` |
| **m10** | the picker does not advance past a matrix family — **families overlap** | ALL PASS | 2 FAILED (383) | **`SP9b` only.** No row that existed before this task could see it |
| **m11** | the picker mints its own family list instead of asking the matrix | ALL PASS | 2 FAILED (383) | `SP9b` |
| **m12** | **CONTROL** — SP9b's fixture drops to two ports | ALL PASS | 3 FAILED (382) | `SP9b` `SP9c` |
| **m13** | **CONTROL** — every SX2 fixture becomes two ports | 6 FAILED (52) | — | `SX2` `SX2b` `SX2c` `SX2d` `SX2e` `SX5` |
| **m14** | **THE THING THE BRIEF FORBIDS** — the caution gains a `Cy` clause | 1 FAILED (57) | — | **`SN5b`** — which did not exist this morning |
| **m15** | the Outputs row is named from `expr` rather than `vector` | ALL PASS | 2 FAILED (383) | **`SP9c` only** — at N == 2 the two keys are equal, so `SP8` cannot see it |
| **m16** | **CONTROL** — SP9c's two variable lists become identical | ALL PASS | 2 FAILED (383) | `SP9c` |
| **m17** | `analysis_matrix_of` stops filtering by family | 2 FAILED (56) | 9 FAILED (376) | `SX2c` `SX2d` · `SP7` `SP8` `SP8b` `SP9` `SP9b` `SP9c` `SP11b` `SP13` |
| **m18** | **THE MIRROR TIDY-UP** — the card stops carrying the noise flag | 4 FAILED (54) | — | `SR3` `SX2f` `SE3/apt` `SE3/fork` |
| **m19** | attack the **input**: the port list truncates to two | 8 FAILED (50) | 3 FAILED (382) | `SX2` `SX2b` `SX2c` `SX2d` `SX2e` `SX5` `SE3/apt` `SE3/fork` · `SP9b` `SP9c` |
| **m20** | the OK path drops any cell whose expression is not its own name | ALL PASS | 2 FAILED (383) | `SP9c` |

(`—` in the dlg column means the arm stayed at its baseline `1 FAILED (384 passed)`, i.e. only
the standing `G2sens`.)

### The three results worth reading twice

* **m7b is the row-rewrite justified by measurement.** The port-count gate on `sp_vectors` is
  invisible to the SX5 that shipped with issue 1454 — `ALL PASS (55 checks)`. The rewritten SX5
  reds on it, and so does SE3. A claim that a rewrite "earns its place" is cheap; this one was
  run.
* **m10 is the one nothing else could see.** Overlapping families change no count and no caption,
  so SP7 stays green; only SP9b's duplicate-slot term notices. That term exists because the brief
  said a 3×3 `Cy` block with no scalars beside it is a layout `matrix_dialog` had never been
  given, and it turned out to be true of the *geometry*, not just the cell list.
* **m15 and m20 both hit `SP9c` alone.** At two ports `vector` and `expr` are equal for every
  family that SP8 ticks, so the GUI-side consequence of *"`Cy` is the one family whose plot
  expression is not its name"* was untestable until there was a three-port `Cy` row.

### The four ways a row fails to fail, and the fifth

1. **Fixtures that never disagree.** SX2's six shapes differ in port count *and* flag; **m13**
   collapses them and reds five rows. SP9b's fixture is three-port and **m12** collapses it.
   SP9c's two variable lists are the same run in the two binaries' spellings, with a term
   (`SP9CDIFF`) asserting they *differ* — **m16** makes them identical and reds the row.
2. **Position asked where the mechanism is last-writer-wins.** Inverted deliberately: SP9c
   asserts the Outputs **order** because `matrix_ok` walks the matrix, and that was measured (the
   row failed on it first). SX2d asserts declaration order of the nine names, which **m8** breaks.
3. **An extractor that returns nothing.** Every new reader is total and answers a comparable
   value — `NOBODY`, `NOCOL`, `NOCARD`, `NOCAUTION`, `NOTITLE`, `NOFMT`, `-1`, `RAISED:…` — and
   each new row carries a positive control: SX2f's two literal cards, SE3's `[llength $SE3WANT]`
   and `[llength $SE3ALL]`, SP9b's `$::MXERR` and family headings, SN5b's Touchstone half.
4. **A sabotage missing from the generator.** Mine was short by the expensive one, as promised:
   **SX2f/m18** (the mirror tidy-up) was unwitnessed until it was written, and so was **m19**
   (attack the input rather than the gate). **m17** found the suite defect above.
5. ⚠ **THE FIFTH — a row pinned to a fact nobody measured** — is this issue's own. It is answered
   by construction: every number in SX2* and SP9b is a count of a rawfile I wrote and read, the
   `i(Cy_3_3)` wrap was re-measured at N == 3 instead of generalised, and SE3 asks the real run
   in **both** directions. **And the sixth is in the headline: a row that runs the real thing but
   asks a one-directional question.** SE3 was that row for an hour.

---

## ⚖ R9 — one new ruling, and NO new user-facing strings

**No string was minted.** The fix adds no label, no message and no sentence; the `Cy` heading and
the `i,j` cell captions are issue 1454's, already in `R9_COPY_REVIEW.md`, and they now appear at
port counts where they did not before. SN5b **pins an existing sentence verbatim** and does not
change it.

### The caution: NOT touched, and now guarded

> `the noise figure is computed for exactly 2 ports and this analysis has 3, so NF, NFmin, Rn and SOpt will not be in the results`
> `switch the noise figure off, or reduce the analysis to 2 ports`

Correct as it stands — it names the four scalars, which are exactly what is absent. **A family
that is PRESENT needs no warning**, which is itself the argument for why the picker must offer
`Cy`. I read R9-425 before touching any copy and changed none. ⚠ **Nothing pinned these words**:
`SN5` asked only for the *verdict*, so the clause this issue nearly added could have gone in
silently. **SN5b** now pins both sentences and both fixes verbatim; **m14** reds it.

### ⚠ THE OPEN RULING — the field label, filed as `owed.sh add rule 1457`

**`Noise figure (2 ports only)`** — the `donoise` field's label in the `sp` registry entry.
**Not changed**, because UI copy is the user's.

The problem is measured, not stylistic: **ticking that box is what summons the N×N `Cy` grid at
any port count.** On a three-port bench the label tells the user not to tick the only control
that would give them the nine `Cy` vectors — which is the same *hiding* this issue is about, one
layer up. Options, in the issue file:

* **(a) leave it** — "noise figure" names the four scalars precisely, and the caution explains
  the N != 2 case the moment the box is ticked;
* **(b)** `Noise figure and correlation matrix` — true at every N, leans on the caution for the
  scalars;
* **(c)** `Noise data (figure needs 2 ports)`;
* **(d)** make the parenthetical follow the table — `(2 ports only)` at N == 2, nothing above it.
  Most accurate; the only option that costs a relabel hook (the `labels`/`relabels` machinery
  already exists on the `sweep`/`points` pair, so it is not new mechanism).

**My recommendation is (b)**, on the grounds that it is the only single-string option that stops
a three-port user being told the box is not for them. It is **not implemented** — the brief's
"do not fix these" list is about the caution, and extending that caution to the label would be
me making the user's decision.

---

## Ledger

Backed up before every write: `/tmp/cy1457/owed_backup_192750`,
`owed_backup_pre_add_*`, `owed_backup_pre_rule_*` (all `cp -a` of `~/.claude/xschem_owed`).

| | rule | look | suite |
|---|---|---|---|
| **before** | 170 | 64 | 10 |
| **after** | **171** | **65** | **10** |

* `add rule 1457` — the field label above. **The user's to answer**; I implemented nothing.
* `add look sp-matrix-picker-3port` — *"the Result Matrix picker on a three-port `sp` row with
  the noise flag on now shows a fourth 3×3 block (`Cy`) below S/Y/Z and no scalar strip — 36
  cells where it showed 27. Nobody has looked at that layout; suites green, please look."*
  **Suites green is not a pixel deliverable**; this is recorded, not reported done.
* `add suite test_ase_dialogs` — printed **`updated`**, and the suite count stayed at 10, i.e. an
  entry already stood and nothing was destroyed. SP9b/SP9c are new widget rows and Calculator
  phase 0 is the precedent for a widget row that passes under Xvfb and fails on `:0` for
  `<Configure>` traffic.

Three added / updated, **none destroyed**. No `clear` of any kind was issued.

---

## Corrections to the brief and to the issue

| | |
|---|---|
| **C1** | **The brief's table is right and is now measured at a third port count.** I added N == 4 (flag off/on) on both binaries: 48 / 64, sixteen `Cy`, zero scalars. Two port counts do not establish "N×N"; three do, and the code comment and SX2's header now carry all six rows |
| **C2** | ⚠ **Issue 1457's "The fix" item 3 says *re-check `sp_vectors`, which inherits the gap by construction*. It does — and the inheritance is the mechanism working, so nothing in `sp_vectors` needed changing.** What needed changing was **SX5**, which asked its question only at N == 2 and was therefore blind to a gate re-added to `sp_vectors` alone. Measured as **m7b**: `ALL PASS`. The re-check belonged in the test, not in the code |
| **C3** | ⚠ **Issue 1457's item 4 asks whether the caution needs a second sentence, and answers "it probably does not". It does not — but the question has a sibling the issue does not name: the FIELD LABEL `Noise figure (2 ports only)`.** That one is wrong in the user-visible sense even though it is right in the literal sense, and it is filed as a ruling rather than fixed |
| **C4** | ⚠ **The brief's §4 says a 3×3 `Cy` block with no scalars beside it is "a layout it has never been given". Measured: the layout is CORRECT as `matrix_dialog` stands** — header at row R, cells at R+i, `maxr` advancing past the block — so nothing in `ase_window.tcl` was changed. The gap was that **no row could have told you that**, which is why SP9b asserts the geometry and the collision rather than only the cell count. **m10** is the proof: overlapping families change no count and no caption |
| **C5** | ⚠ **A row that runs a real simulator is not automatically a row that would notice.** SE3's first draft asked only "is everything promised present?" and would have passed the defect. Recorded as this receipt's headline because the batch's failure-mode list does not have it, and an end-to-end row is exactly the kind of row nobody re-reads |
| **C6** | **`test_ase_simcaps_0948` is 211, not receipt 33's 199.** HEAD's own `88ba4a16 fix(1453)` raised it; the file's history block says so. Anyone diffing against receipt 33's neighbourhood table will otherwise think something moved |

---

## What I did NOT ship, and why

* **No change to `src/ase_window.tcl`.** The picker's layout code is correct for a four-matrix
  stack; only its *coverage* was missing. md5 verified identical to the pristine snapshot.
* **No change to the caution sentence or to the field label.** The first is right; the second is
  the user's ruling.
* **No Smith chart** — still outstanding from issue 1454's C1, untouched here.
* **No `sp_matrix` guard for N == 1.** A one-port row answers a 1×1 grid, which is unreachable:
  `analysis_setup_min` is 2 and `two_ports` is fatal, and ngspice refuses the run outright
  (`Error: Only one RF Port is found`). Observed, deliberately not changed — it is out of this
  issue's scope and a guard would need its own row.
* **`tests/run_regression.tcl` not run** — the driver's, solo (issue 0990).

## Debts this task leaves

1. ⚖ **The `Noise figure (2 ports only)` label** — `owed.sh add rule 1457`. **Blocking nothing**;
   the fix ships without it.
2. 👁 **The three-port picker's appearance** — `owed.sh add look sp-matrix-picker-3port`. Suites
   green, please look.
3. 🖥 **`test_ase_dialogs` on `:0`** — entry updated (already stood). SP9b reads real grid
   geometry, which is the class Calculator phase 0 showed can differ between Xvfb and Xwayland.

## One observation that is not mine to act on

`ps -ef` shows **two background waiter shells from other sessions** in this clone, both of the
form `until ! pgrep -f 'nolog --script …test_ase'; do sleep 8; done`, dated Sep 12. **My suite
runs match that pattern**, so those waiters have been kept alive by this task's runs. I started
neither and killed neither (standing rule). Flagging it because an unbounded `until … sleep`
with no deadline is the exact shape of the eight-hour stall written up in
`doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md`.
