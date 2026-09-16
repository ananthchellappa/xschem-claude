# 57b — adversarial verification of ⚖ R9 rulings A11 and A12, and task 3's two residues (receipt 57)

**Role:** adversarial verifier. Brief: disbelieve `57-r9-a11-a12-citations-and-acronyms.md`, re-derive
independently, finish the one claim the crew left open, and report what is actually true.
**No source file was changed.**

**Tree state.** HEAD `61f2ad6d` at start and at end. `git status` carries the identical five modified
and four untracked paths throughout, plus this receipt. No `git checkout --`, `restore`, `stash`,
`clean`, `add`, `commit` or `push` at any point. `LEDGER.md` is the driver's; I never opened it.
`tests/run_regression.tcl` **NOT run** — the driver's, solo (issue 0990).

| file | md5, start **and** end |
|---|---|
| `src/ase.tcl` | `2e3cecb81183eefa2139cbdd971d8e75` |
| `src/ase_window.tcl` | `559421793afdbf260de341cc1ba947a3` |
| `tests/headless/test_ase_core.tcl` | `084e9e04279463be5474c8f9e5f466f0` |
| `tests/headless/test_ase_dialogs.tcl` | `4b456991bf818b19e42983a5dec58ce8` |
| `tests/headless/test_ase_preflight.tcl` | `ab24f45206678d93cdeb9cfdd9d6c7af` |
| `tests/headless/test_ase_meas_1443.tcl` | `b983ab0815b92330ca1686b83269d57b` |
| `doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md` | `abc4f8a81e415d1b809344f5cdfd1106` |

`diff baseline.md5 final.md5` → **ALL SEVEN BYTE-IDENTICAL TO BASELINE**. `src/ase_window.tcl` is
also byte-identical to `61f2ad6d` (`git diff --quiet 61f2ad6d` → clean).

`~/.xschem/recent_files` **untouched at 2026-09-13 18:53:01.297381420** (issue 0924 canary), checked
at start and at end. `owed.sh count` read-only: **188 rule, 71 look, 11 suite**, unchanged — I wrote
nothing to the shared cross-clone ledger. **`/usr/bin/ngspice` was never invoked**, no simulation was
started, no deck was written under `sky130A/`, and `ps -eo comm=` showed **zero `ngspice`** at every
check (`Xvfb` ×1, `openbox` ×1, `wish` ×5, `xschem` ×2 alive throughout, predating this pass).

---

## ⚠ THE METHOD

Every mutation was built in a **scratch farm**, never in the repo.

* **Source farm** — a symlink farm of `src/` with real copies of `ase.tcl` and `ase_window.tcl`;
  `XSCHEM_SHAREDIR` points the repo's own binary at it.
* **Test farm** — for the one arm that had to mutate a *suite*: a repo-shaped root at `$S/tf` whose
  `tests/headless/` holds symlinks to everything plus a real copy of `test_ase_core.tcl`, so the
  suite's own `set repo [file normalize [file join $here .. ..]]` still resolves to a repo.
* **Whole pristine tree** — `git archive 61f2ad6d | tar -x`, then `git init && git add -A`, for the
  `G2sens` question.

**Validated before trusted**, by positive assertion:

| control | verdict |
|---|---|
| unmutated **source** farm, `test_ase_core` headless | `ALL PASS (675)` — equals the plain in-tree run |
| unmutated **test** farm, `test_ase_core` headless | `ALL PASS (675)` — equals the plain in-tree run |
| the red reader fed a log with no `RESULT:` line | `DIED(no RESULT line)` — it never answers "clean" |

Every sabotage guard is a **counted diff** against the pristine copy plus an **exact-once needle**
that aborts the arm if it does not occur exactly once (`plant.py`, exit 2 / exit 3).
**No md5 was used as a sabotage guard**; md5 and `cmp` appear only to prove the restore.

⚠ **ONE FALSE "DIED" WAS MINE AND I AM RECORDING IT.** My first S3 attempt reported all three suites
as `DIED(no RESULT line)`. The cause was my own shell helper: I redefined `run()` with the share-dir
in `$4` and then called it with four arguments, so `XSCHEM_SHAREDIR` was set to `tests/headless` and
xschem exited with `Tcl_AppInit() err 4: cannot find tests/headless/xschem.tcl`. **Nothing was wrong
with the tree.** It is the same shape as the batch's standing warning — a harness fault that reads
exactly like a finding — and it is why the arm was redone with a control row first.

---

## Attack 1 — the claim the crew was honest about, FINISHED
### `test_ase_optsheet_1441` **cannot** witness a citation move → the crew's reading is **CONFIRMED**, and now proved

The crew said `test_ase_optsheet_1441` stayed green through all nine `ase.tcl` arms, that this is
consistent **both** with the citations being right **and** with that suite being unable to see a
citation move, and that **it did not distinguish those two cases**. I distinguished them with two
arms on the same string, both counted-diff 2 with an exact-once needle.

| arm | mutation to `oldlimit`'s `inert` reason | core | optsheet_1441 nogui | optsheet_1441 **display** | options_1437 |
|---|---|---|---|---|---|
| **O1** | the citation moved **back to mid-sentence** (a pure placement change) | **REDS[`LB14`]** | `ALL PASS (64)` | `ALL PASS (89)` | `ALL PASS (75)` |
| **O2** | the whole string replaced by **grossly different text with no citation at all** | **REDS[`LB14`]** | `ALL PASS (64)` | `ALL PASS (89)` | **REDS[`IN3`]** |

**So `test_ase_optsheet_1441` is blind not merely to a citation's placement but to the entire
string.** Its `64 / 89` green is **no evidence whatever** for A11, exactly as the crew suspected but
did not show. **`LB14` really is the only cover**, and the crew is right to claim nothing else.

⚠ **One thing the crew did not know, found here:** `test_ase_options_1437` **can** witness a *content*
change to an `inert` reason (`IN3` reds under O2) but **not** a *placement* change (O1 leaves it
`ALL PASS`). The crew's statement that "no arm reached the option catalogue's rows" is true of *its*
arms, which were all placement-only; it is not a property of that suite.

---

## Attack 2 — "all twelve of A1–A12 are implemented" → **CONFIRMED**, established my own way

**Not from the receipt's table, and not by grepping for a marker.** The crew's own **C4** records that
its first status check falsely called six rulings unimplemented because it grepped for a section-level
`✅ IMPLEMENTED` block that six sections never use. So I read all twelve `✅ RULED BY THE USER` blocks
and then **rendered the shipped behaviour** each one demands, through the shipped procs.

| ruling | what the ruling demands | rendered on this tree |
|---|---|---|
| **A1** | capitals survive only for a catastrophic outcome or a row-class prefix; no arithmetic in a label | `SEGFAULTS` present in the `sp` refusal; `NOT MEASURED:` ×10 in `ase.tcl`, `NOT OFFERED:` prefix in `optsheet_detail`; **none of the 51 enumerated analysis-field captions carries arithmetic** — `gives ONE point` survives only in two **comments** (`ase.tcl:12973-12974`) |
| **A2** | display the readable word, emit the deck word; `dec`/`oct`/`lin` unchanged | `pz.transfer` `valuelabels {vol Voltage cur Current}`, `pz.mode` `{pz PZ pol Poles zer Zeroes}`, `sens.mode` `{dc DC ac AC}`; `ac.sweep`/`noise.sweep`/`disto.sweep`/`sp.sweep` declare **no** `valuelabels` — the ruled exception |
| **A3** | a refusal names the caption, colon stripped, unit kept | `needs a value for 'Stop time (s)'` · `needs a value for 'Report every N points'` |
| **A4** | no bare caption; the tran word order deliberately asymmetric | `dc.stop` = `Stop value`, `dc.step` = `Step size`, `tran.step` = `Time step (s)`, `tran.stop` = `Stop time (s)`, `ac.stop` = `Stop frequency (Hz)`. ⚠ `dc.start` is still bare `Start` — the site §A4 reported rather than tidied |
| **A5** | `Start time (s)`, and **the meaning moves to the detail line** | `tran.tstart` = `Start time (s)`; `needs_eval … tstart_note` renders `caution {ngspice still simulates from 0 and only discards the output before 5u, so this shortens the results file and not the run} {clear Start time (s) to keep the whole waveform}` — and is **silent** on an unset field |
| **A6** | `this simulator`; `verbatim` left alone | `this simulator` ×50 in `ase.tcl`, ×9 in `ase_window.tcl`; `analysis_gap_msg zznope` still renders `ASE-L does not know a simulator backend called 'zznope'.` — **the site §A6 reported and did not tidy**, unchanged |
| **A7** | one body, both frames | `analysis_refusal_frames tran <clause>` → `log {ase: enabled tran analysis needs a value for 'Stop time (s)'}` `status {This tran analysis needs a value for 'Stop time (s)'.}` — two verbs, one clause, only the status line takes the stop |
| **A8** | one body for the shared tail, leads not flattened | `preflight_refusal <lead>` → `ase: it is enabled on this bench, so the run would have started and produced nothing for it. Nothing was generated: no deck, no raw, no log. \`set ase_preflight 0\` leaves this check in force.` |
| **A9** | placeholders spelled as words; any `<…>` left is a substitution failure | `add \`distof1\` to the input source with a magnitude and a phase in degrees` · `add \`distof2\` to a source with a magnitude and a phase in degrees, or clear the F2/F1 ratio to measure harmonics instead`; **0** literal `<` across both clauses and both remedies. The 3 `<mag>`/`<phase>` hits left in `ase.tcl` are all **comments** (11992, 12089, 13279) |
| **A10** | one word per idea, qualified only where two appear together | `find.value`/`when.value` = `Value`; `trigval`/`targval` = `Trigger value`/`Target value`; `trigtd`/`targtd` = `Trigger ignore before (s)`/`Target ignore before (s)`; `find.td`/`when.td` = `Ignore before (s)`. `reaches`, `Trigger delay`, `Target delay` return **0** hits |
| **A11** | citation parenthesised and sentence-final; pin with a row; survey first | rendered survey below; `LB14` green on both arms and proved discriminating (Attack 4) |
| **A12** | `RMS FFT PSD THD` uppercase; `FFT spectrum` decided **per site**; nothing outside the four | `fft`→`FFT`, `psd`→`PSD`, `rms`→`RMS`, `fourier`→`Fourier / THD`, `spec`→`Spectrum over a frequency band` (untouched) |

**Every one of the twelve is implemented. None is outstanding.** The crew's conclusion is right and
its C4 self-correction is honest.

---

## Attack 3 — the 17-vs-247 survey → **PARTLY REFUTED**

### (a) the `site` key has **no user-visible reader** → **CONFIRMED**, with one correction to the sweep

I read `ase::ui::optsheet_detail` end to end. It composes, in order: `opt_help`; then exactly one of
`NOT OFFERED: <opt_inert>` / `SET ELSEWHERE: <opt_owner>` / `CLAMPED: <clamp>` /
`CAVEAT: <defect><caveat>` by `opt_offer`; then `opt_results_why`; then `GATED: <opt_gate_why>`; then
one of `SCOPED:` / `GLOBAL:` / `LEAKS: <opt_leak_why>` under an analysis scope; then the stored
verdict. **`site` is never among them**, and the string `site` does not occur anywhere in the
options-sheet code. So the substance holds: the key reaches no screen.

⚠ **But "I looked for a reader … and there is none" is not accurate.** `site` has **four** readers —
all in `tests/headless/test_ase_options_1437.tcl` (lines 174, 784, 791, 798), which asserts over it.
None of them renders it, so the conclusion is untouched; the sweep statement is incomplete and should
say *no user-visible reader*.

### (b) the counts → the **catalogue** figure is right, the **headline** figure is wrong by one

Measured by rendering, not grepping (`ase::sim_option_names ngspice` walked through every accessor,
then classified **outside** Tcl so the classifier under test was not reused, honouring
`optsheet_detail`'s own `switch`):

```
option rows                         247      <- "all 247 carry a site key": CONFIRMED
rows whose site holds a .c path     227
rendered BITS carrying a citation    18      <- receipt says 17
citation OCCURRENCES                 21
distinct OPTIONS                     17      <- receipt says 16
distinct KINDS                        1
END : acct deriv list node nomod nopage oldlimit opts                              (8)
MID : debug defas itl1 itl2 itl4 klu_memgrow_factor newtrunc scale wnflag x11lineararcs (10)
```

**The END and MID name lists are exactly right** — they are `LB14`'s two expected lists, and I
reproduced both independently. **The arithmetic is not.** 7 compliant options + 10 mid-sentence
options = **17 options**, plus the `deriv` kind = **18 sites**. The receipt and the shipped
`R9_COPY_REVIEW.md` §A11 implemented block both say *"17 bits over 16 options and one measurement
kind"*, and both then say *"the invariant is true of **8 of the 18**"* — **the two sentences
contradict each other by one, in the same paragraph.** 8 + 10 = 18 is the correct figure.

⚠ Also loose: *"a source grep for `\.c:[0-9]` therefore answers 247"*. A raw grep of `src/ase.tcl`
for that pattern answers **393**; what is 247 is the number of option **rows carrying a `site` key**.
The point survives — a grep-based survey would "fix" hundreds of strings nobody can read — but the
sentence as written is not reproducible.

**No reader was found.** `LB14`'s honest weakness stands: it composes the bits itself rather than
driving the widget, so a future surface that started rendering `site` would escape it.

---

## Attack 4 — `LB14`'s ratchet and its classifier control → both **CONFIRMED**

**S3, reproduced independently** (after the harness false start recorded above). An **eleventh**
mid-sentence citation planted in an option that had none — `srcsteps`'s `help` string gains
`niiter.c:38-39 caps it`, unbracketed — exact-once needle on the whole catalogue line, counted diff 2:

```
core:            REDS[LB14]  (1 FAILED, 674 passed)
  actual MID list gains `srcsteps`; every other term identical to expected
options_1437:    ALL PASS (75)
optsheet_1441:   ALL PASS (64)
meas_1443:       ALL PASS (115)
```

**The ratchet fires, and `LB14` is the only row that moves.** A row asserting only "the seven are
compliant" would have sat green through this.

**The classifier positive control is REAL, and I proved it by breaking the classifier.** In the test
farm, `lb14cite` was forced to `lappend out END ; continue` for every match — counted diff 1, an
always-`END` classifier:

```
core: REDS[LB14]  (1 FAILED, 674 passed)
actual   {{acct debug defas itl1 itl2 itl4 klu_memgrow_factor list newtrunc node nomod
           nopage oldlimit opts scale wnflag x11lineararcs} {} END END END {}}
expected {{acct list node nomod nopage oldlimit opts} {debug defas itl1 itl2 itl4
           klu_memgrow_factor newtrunc scale wnflag x11lineararcs} END MID END {}}
```

Two terms catch it: the MID list collapses to empty, **and** term 4 — the hand-made mid-sentence
string — answers `END` where `MID` is required. **A classifier that always answered `END` does not
pass this row.** The control is not decoration.

---

## Attack 5 — A12's per-site `FFT` decision → **CONFIRMED**, no fourth reader

`ase::meas_kind_label` has exactly **five call sites** in `src/`, over **three surfaces**:

| site | surface | what it names |
|---|---|---|
| `ase_window.tcl` `meas_fill` | Kind **column** of the Measurements list | the kind |
| `ase_window.tcl` `meas_show` ×2 (`-values`, then `set`) | the Kind **picker** | the kind |
| `ase.tcl` `meas_rule` ×2 (`$klbl`, and the new `$_safe`) | the two refusals | the kind |

**There is no fourth.** The one candidate worth chasing — `ase.tcl:8684`, another
`dict exists $e label` reader — is **`ase::meas_template_label`**, which reads the *template* entry,
not the kind entry, and cannot return a kind label.

**And the `Measured on` picker really does render `ase::meas_name`.** `ase::ui::meas_show` builds it
from `ase::ui::meas_producer_names`, which returns `[ase::meas_name $r]` per producer row, with
`(the analysis)` (`lbl_meas_on_own`) inserted first. The kind label never reaches it. **So the case
§A12 reserved the noun for does not occur in this tree**, and dropping it at every site is correct.

---

## Attack 6 — `R9-361`'s remedy is a RELABEL → **CONFIRMED**, and S9 reproduced

Rendered through the shipped proc:

```
on a real S-parameter run ngspice's own measure engine reads a complex frequency scale as if it
were real and SEGFAULTS for Delay (TRIG ... TARG). Measure Value at a point, Minimum, Maximum or
Average there, or measure a spectrum produced from a transient instead
```

Every word of the new clause is an existing handled label, fetched not frozen — `ase::meas_kind_label`
answers `find`→`Value at a point` (`R9-295`), `min`→`Minimum` (`R9-299`), `max`→`Maximum` (`R9-300`),
`avg`→`Average` (`R9-297`), and the four are the exact complement of the four the guard refuses
(`when trigtarg rms integ`). `SEGFAULTS` survives.

**S9, reproduced independently.** The `foreach`/`join` builder replaced by the literal
`set _safe {Value at a point, Minimum, Maximum or Average}` — exact-once needle, counted diff **7**:

```
rendered refusal after the arm:  cmp against the pristine rendering -> BYTE-IDENTICAL
core:        REDS[LB15] alone   actual {... {1 1}}  expected {... {1 0}}
meas_1443:   ALL PASS (115)
options_1437: ALL PASS (75)
```

**The arm changes no character a user reads and `LB15` reds anyway.** That is the whole case for
term 8, and it holds. ⚠ The crew's own caveat is also right: term 8 only forbids the literal
`Value at a point`, so a body freezing `Minimum`/`Maximum`/`Average` while still fetching `find`
would pass it. Terms 6 and 7 are what pin the sentence.

---

## Attack 7 — `MS9b`'s non-vacuity → **CONFIRMED**, and I added the arm the crew did not run

| arm | mutation to `ase::ui::meas_show` | counted diff | dialogs **display** | core |
|---|---|---|---|---|
| **S10** (crew's, reproduced) | a real `labelframe -text Trigger` for `trigtarg` | 5 | **REDS[`G2sens` `MS9b`]** | `ALL PASS (675)` |
| **S10b** (**mine**) | the delay form made to render **no fields at all** | 2 | **REDS[`G2sens` `MS9b`]** | — |

S10b is the non-vacuity test proper, and it is the one *"no headings"* would trivially pass:

```
MS9b actual {0 0 {} 0}   expected {0 0 0 10}
```

**The row does not pass for a form that rendered nothing** — term 4's ten captions are load-bearing,
exactly as claimed. In both arms `G2sens` is the pre-existing red, not collateral; `MS9b` is the only
row either arm moved.

---

## C1's undeclared red — **CONFIRMED, and the arm is still VALID**

S7 reproduced: the out-of-scope `spec` label shortened to `Spectrum`, exact-once needle, counted diff 2.

```
core:         REDS[LB9 LB15]   (2 FAILED, 673 passed)
meas_1443:    ALL PASS (115)
options_1437: ALL PASS (75)
```

`LB9`'s `foreach` carries `spec {Spectrum over a frequency band}` as one of its five label goldens, so
shortening that label necessarily moves it. **The aimed-at row `LB15` did redden and nothing outside
the declared file moved, so the arm proves what it was built to prove**; the crew's enumeration was
wrong and the crew says so. Recorded rather than absorbed, which is the standard.

---

## Independently verified — the rest of the brief

**Suites, both arms.** `nogui` = `./src/xschem --nogui --pipe -q --nolog`; `disp` =
`devdisplay.sh exec` on **`:99`** (Xvfb, **openbox (Openbox 3.6.1)**, `1920x1080x24`,
`devdisplay.sh status` = alive, clients 0).

| suite | nogui | display | last emitting row (both arms) | terminal banner |
|---|---|---|---|---|
| `test_ase_core` | **ALL PASS (675)** | **ALL PASS (675)** | `MT10` | `OVERALL` present |
| `test_ase_preflight` | **ALL PASS (242)** | **ALL PASS (242)** | `PF233f` | `OVERALL` present |
| `test_ase_meas_1443` | **ALL PASS (115)** | **ALL PASS (115)** | `HK2` | `OVERALL` present |
| `test_ase_dialogs` | **ALL PASS (37)** | **1 FAILED (388 passed)** — `G2sens` only | `H4d` / `SP14/fork` | `OVERALL` present |
| `test_ase_optsheet_1441` | **ALL PASS (64)** | **ALL PASS (89)** | `HK5` / `UI24` | `OVERALL` present |
| `test_ase_options_1437` | **ALL PASS (75)** | — | `PR4` | `OVERALL` present |
| `test_ase_trnoise_gui_1467` | — | **ALL PASS (63)** | `EE3/fork` | `OVERALL` present |

**Completeness, not arithmetic — and I am saying explicitly that I checked it.** For every suite on
every arm I required the **`ok:` line count to equal the `RESULT:` count**, the **last emitting row of
the file to be present**, and a **terminal `OVERALL` banner**. This is the check task 3's C1 defeated:
a `#` inside a `[list …]` substitution truncated preflight 242 → 232 while still printing a plausible
`RESULT:` line. Nothing here is truncated.

**`G2sens` is pre-existing, established on a TRUE-PRISTINE tree**, not by reading an assertion.
`git archive 61f2ad6d` extracted whole (`src/ase.tcl` and `test_ase_dialogs.tcl` both confirmed to
differ from the working tree, `ase_window.tcl` confirmed identical), display arm:

```
RESULT: 1 FAILED (387 passed)
FAIL: G2sens ... -> {1 1 0 1 0 Entry Entry normal} (exp {1 1 0 0 0 Entry Entry normal})
MS9b: absent (0 occurrences) -- it does not exist at 61f2ad6d
```

**The identical actual value.** Issue **1436**, not this crew's. T1 runs this file on neither arm.

**Floors.** `test_ase_core` `AND RAISED 673 -> 675` and `test_ase_dialogs` `AND RAISED 387 -> 388 on
the display arm` are both **additions** in the diff, each inside its own file's floor block.
`test_ase_preflight`'s new `242 UNMOVED …` paragraph sits **beside the floor**, in the floor block —
the exact gap receipt 56b found and reported. A grep of the whole `tests/` diff for a **removed**
floor or `AND RAISED` line returns **nothing**. **No floor was lowered.**

**104/104 `.state` byte-identical**, driven as the **proc** (`ase_state_roundtrip`), never by running
`state_roundtrip.tcl` as a script: `tracked 104  bad {}  control_disagrees 1  control_agrees 1`.
**Both controls live.**

**The deck is unchanged, derived my own way.** Rendered through
`ase::backend::ngspice::render_deck <state> <netlist>` (the two-argument form the suites use) on a
**scratch** rundir, with eight measurement rows covering `fft` `psd` `rms` `spec` `find` `min` `max`
`avg`. The leak list was built **from the catalogue itself** — every kind label
`ase::meas_kind_order` declares, plus the two old spellings and the four new remedy words — not from
a hand-written list:

```
DECKLEAK  []                     <- empty: not one picker word reaches the deck
DECKRMS   literal RMS occurrences = 1
  meas tran mr RMS v(out) >> .../rc_ase.meas     meas tran mv FIND v(out) AT=1u >> ...
  meas tran mn MIN v(out) >> ...                 meas tran mx MAX v(out) >> ...
  meas tran ma AVG v(out) >> ...
  fft v(out)        psd 4 v(out)        spec 1 100k 1k v(out)
```

The deck carries ngspice's tokens and ngspice's own `meas` function words; `RMS`, `FIND`, `MIN`,
`MAX`, `AVG` there are the **deck** words, which is precisely why the remedy needed relabelling in the
first place. **Together with 104/104 `.state` identity, nothing ASE-L emits, reads back or offers has
moved.** No `/usr/bin/ngspice` run was needed or made: every change under test is pure-Tcl caption and
sentence composition, and the render plus the state identity are the evidence.

**No handle minted, header unmoved.** Against `git show 61f2ad6d:…R9_COPY_REVIEW.md`: header line 14
says **730** then and now; `grep -c '^\*\*R9-'` = **727** then and now; distinct anchored handles =
**726** then and now. **I minted nothing and ruled on no copy.**

**The four citations with no handle — CONFIRMED, and the measurement has a trap in it.** The claim is
that `niiter`, `cktsopt.c:111`, `subckt.c` and `inpgmod` return **zero** hits in `R9_COPY_REVIEW.md`.
Measured against the **working** document they return **2 each** — because the new §A11 block *itself*
names them. Measured against the **baseline** (`61f2ad6d`), which is the only tree the claim can be
about:

```
niiter 0   cktsopt.c:111 0   subckt.c 0   inpgmod 0   spice_netlist.c:143 0
(for contrast, the four that DO have handles: x11.c:707 1, options.c:346 1,
 cktsopt.c:187 1, cktsopt.c:199 1)
```

**Four rendered citations, plus the `d_cosim` `spice_netlist.c:143-169` site, are user-visible copy
with no handle.** Confirmed exactly as reported. A later reader re-checking this must use the
baseline document, not the working one.

**Sabotage — six arms redone independently**, counted diff + exact-once needle, **never an md5
guard**, every restore proved by `cmp`:

| | arm | counted diff | measured reds | verdict |
|---|---|---|---|---|
| **O1** | `oldlimit` citation back mid-sentence | 2 | core `LB14` alone; optsheet **green both arms** | the decisive new arm |
| **O2** | same string grossly rewritten | 2 | core `LB14`; options_1437 `IN3`; optsheet **green both arms** | the decisive new arm |
| **S3** | an eleventh mid-sentence citation (`srcsteps`) | 2 | core `LB14` **alone** | exactly as declared |
| **S7** | out-of-scope `spec` label shortened | 2 | core `LB9` **and** `LB15` | as C1 self-reported; arm VALID |
| **S9** | the four labels frozen, rendered text byte-identical | 7 | core `LB15` **alone** | exactly as declared |
| **S10** | a real `labelframe -text Trigger` | 5 | dialogs disp `MS9b` (+`G2sens`), core unmoved | exactly as declared |
| **S10b** | the delay form renders no fields (**mine**) | 2 | dialogs disp `MS9b` (+`G2sens`) | term 4 is non-vacuous |
| **C-arm** | `lb14cite` always answers `END` (**mine**) | 1 | core `LB14` **alone** | the control is real |

**No arm reddened a row it was not aiming at**, `G2sens` excepted, which is the pre-existing red
established on the pristine tree above.

**Ends on positive restored-tree rows:** source farm `cmp`-identical to `src/ase.tcl` and
`src/ase_window.tcl`; test farm `cmp`-identical to `tests/headless/test_ase_core.tcl`; in-tree
`test_ase_core` **ALL PASS (675)** on the unmutated farm as the campaign's last control.

---

## ⚠ Found — where the receipt overstates or miscounts

1. **The headline count is wrong by one.** *"17 bits over 16 options and one measurement kind"* is
   **18 bits over 17 options and one kind** (21 citation occurrences). The receipt's own
   *"8 of the 18"* is the correct figure, so the two sentences contradict each other. **The same
   error is in the shipped `R9_COPY_REVIEW.md` §A11 implemented block**, which is a document the user
   reads — so this is a doc edit the driver owes before committing, not merely a receipt slip.
2. **"a source grep for `\.c:[0-9]` answers 247"** is not reproducible: that grep answers **393** in
   `ase.tcl`. What is 247 is the number of option rows carrying a `site` key (confirmed exactly).
3. **"nothing reads it … I looked for a reader in both sources and in the optsheet suite and there is
   none"** — no *user-visible* reader exists (confirmed by reading `optsheet_detail` end to end), but
   `test_ase_options_1437.tcl` reads `site` at four places. The conclusion survives; the sweep
   sentence does not.
4. **"no arm reached the option catalogue's rows"** is true of the crew's nine placement-only arms and
   is not a property of `test_ase_options_1437`, which **does** witness a content change (`IN3`).

None of these is a defect in the code, a wrong row, or a red. Items 1–3 are prose.

---

## Verdict summary

| # | claim | verdict |
|---|---|---|
| 1 | `test_ase_optsheet_1441` cannot witness a citation move; `LB14` is the only cover | **CONFIRMED** — and it cannot witness a total rewrite either |
| 2 | all twelve of A1–A12 are implemented | **CONFIRMED** — re-derived by rendering all twelve rulings |
| 3a | all 247 option rows carry a `site` key | **CONFIRMED** |
| 3b | `site` has no reader that reaches a screen | **CONFIRMED** — but four readers exist in `test_ase_options_1437` |
| 3c | the survey found **17** bits over **16** options and one kind | **REFUTED** — 18 bits, 17 options, 21 occurrences; the END/MID lists are right |
| 3d | a source grep "answers 247" | **REFUTED** — that grep answers 393; 247 is the row count |
| 4a | `LB14`'s ratchet: an eleventh citation reds the row | **CONFIRMED** (S3, reds alone) |
| 4b | the classifier positive control is real | **CONFIRMED** — an always-`END` classifier reds `LB14` |
| 5a | `ase::meas_kind_label` has exactly three reading surfaces, no fourth | **CONFIRMED** |
| 5b | the `Measured on` picker renders `ase::meas_name`, never the label | **CONFIRMED** |
| 6a | `R9-361`'s remedy is a relabel; the four words are fetched, not frozen | **CONFIRMED** |
| 6b | S9 reds `LB15` while changing no rendered character | **CONFIRMED** (`cmp` byte-identical) |
| 7 | `MS9b` is non-vacuous — ten captions required, reds on a real heading | **CONFIRMED** (S10 and my own S10b) |
| — | C1: S7 also reds `LB9`; the arm is still valid | **CONFIRMED** |
| — | suites both arms; `G2sens` sole red, pre-existing on a true-pristine tree | **CONFIRMED** |
| — | completeness by last-row name + banner, not arithmetic | **CONFIRMED** on both arms |
| — | floors raised in-file (core 673→675, dialogs 387→388), preflight paragraph beside the floor, none lowered | **CONFIRMED** |
| — | 104/104 `.state`, driven as a proc, both controls live | **CONFIRMED** |
| — | the deck is unchanged; zero label leakage | **CONFIRMED** — derived from the catalogue, not a hand list |
| — | no handle minted; 730 / 727 / 726 unmoved | **CONFIRMED** |
| — | four rendered citations carry no `R9-` handle | **CONFIRMED** against the baseline document |

## For the driver to decide before committing

1. **The 17→18 / 16→17 miscount is in `R9_COPY_REVIEW.md` itself**, one paragraph above its own
   correct *"8 of the 18"*. A user reads that document. One-line doc fix.
2. **"nothing reads it" should read "no user-visible reader"** in both the receipt and the §A11
   block — `test_ase_options_1437` reads `site` four times.
3. **The four unhandled citations and the `d_cosim` `spice_netlist.c` site** — reported by the crew,
   confirmed here, and the user's to rule on. No `owed.sh add rule` was filed by the crew or by me.
4. **`Measure Value at a point there`** — the awkward verb pairing the crew declined to smooth. The
   user's, and the cheapest fix is a frame change (*"Use … there"*).
5. **`LB14` composes the detail bits rather than driving the widget**, so a future surface rendering
   `site` escapes it; and **`LB15` term 8 only forbids the literal `Value at a point`**. Both are the
   crew's own declared weaknesses and both are real.
6. **No `:0` or `$DISPLAY` run was taken here either** — this pass is `:99` only. §A12 changes two
   words in the Kind picker and `MS9b` is a claim about a form's layout, so a pixel look is genuinely
   owed and **no green suite discharges it**.
