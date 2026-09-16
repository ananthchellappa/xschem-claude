# 54b — adversarial verification of ⚖ R9 rulings A3, A4 and A5 (receipt 54)

**Role:** adversarial verifier. Brief: disbelieve receipt `54-r9-a3-a4-a5-labels.md`, re-derive its
claims independently, and report what is actually true. **No source file was changed.**

**Tree state.** HEAD `a7bd53b7` at start and at end. `git status` carries the identical five modified
paths and five untracked paths it carried at the start, plus this receipt. No `git checkout --`,
`restore`, `stash`, `clean`, `add`, `commit` or `push` was run at any point.

| file | md5, start and end |
|---|---|
| `src/ase.tcl` | `034898612ae0134c59e4b14e750aa707` |
| `src/ase_window.tcl` | `1e30430c169fbd70f8687862b78a0933` |
| `tests/headless/test_ase_core.tcl` | `11520e50e0d75ac2c4887d2a205c7a4e` |
| `tests/headless/test_ase_dialogs.tcl` | `f34d54332adef12a6c448590b1423416` |
| `doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md` | `1fb6652d73626dfef1d41c0f26c805f4` |

`~/.xschem/recent_files` **untouched at 2026-09-13 18:53:01** (issue 0924 canary), checked at the
start and at the end. `owed.sh count` **187 rule, 71 look, 11 suite** — the ledger was never written.
**`/usr/bin/ngspice` was never invoked by me**, no simulation was started by me, no deck was written
under `sky130A/`. `tests/run_regression.tcl` **NOT run** — the driver's, solo (issue 0990).

---

## ⚠ THE METHOD

Every mutation was built in a **scratch tree**, never in the repo. `git archive a7bd53b7 | tar -x`
yields `pristine/`; `pristine` + the five working files copied over it yields `work/`; each sabotage
is a further copy differing from `work/` by a **counted** number of lines. `src/xinit.c:3204` gives
`XSCHEM_SHAREDIR` priority 1, so the repo's own binary is pointed at the scratch `src/`, and the
suite is run from that tree's own `tests/headless/` (`scratch.tcl:43` resolves the repo home from
`[info script]`, so a suite run from outside a checkout resolves its fixtures outside the repo —
receipt 53b's recorded trap).

⚠ **One addition to 53b's method: the scratch trees need a git index.** `test_ase_core`'s `CP7` and
`state_roundtrip.tcl` both shell out to `git ls-files -- *.state`; a bare `tar -x` tree answers
nothing and the suite dies at `couldn't open "GIT-LS-FILES-FAILED"`. `git init -q && git add -A`
inside each scratch tree fixes it (104 `.state` paths in both). This is a scratch-tree operation and
touches no repository.

**The method was validated before it was trusted:**

| control | verdict |
|---|---|
| `work/src` via `XSCHEM_SHAREDIR`, `test_ase_core` | `ALL PASS (662 checks)` — byte-identical to the plain in-tree run |
| `pristine/src`, `test_ase_core` | `ALL PASS (653 checks)` — the pre-change floor |

---

## Claim 1 — "`test_ase_meas_1443` (113 green) is `meas_flabel`'s regression cover" → **REFUTED**

This is the claim the crew was honest about, and it is the one that does not survive.

**Two arms, both with a counted diff of −1/+1 on `src/ase_window.tcl` line 8129.**

| arm | mutation | `test_ase_meas_1443` | `test_ase_core` | `test_ase_window` | `test_ase_dialogs` display |
|---|---|---|---|---|---|
| **M1** | `meas_flabel` returns `"$field:"` — a blatant caption regression | **`ALL PASS (113)`** | `1 FAILED (661)` — **`LB5` alone** | `ALL PASS (56)` | `1 FAILED (387)` — `G2sens` only, i.e. unmoved |
| **M2** | `meas_flabel` body replaced by `error "SAB7 meas_flabel WAS CALLED"` | **`ALL PASS (113)`** | suite **died** printing `SAB7 meas_flabel WAS CALLED` (positive control — core *does* call it) | — | `2 FAILED (349 passed)` — the suite partially died, so it calls it too |

**M2 is decisive and is the arm the receipt did not run.** A proc that raises on *every* call cannot
be called by a suite that finishes `ALL PASS (113)`. `test_ase_meas_1443` **never invokes
`ase::ui::meas_flabel` at all** — consistent with `grep -n meas_flabel tests/`, which returns hits in
**`test_ase_core.tcl` only**, and with the suite having **zero** `has_x` guards (it is headless-only,
and `meas_flabel` is reached only from `ase::ui::meas_form`'s widget loop at
`ase_window.tcl:8269`).

**So "113 green" is decoration for this delegation.** The receipt's own hedge — *"its rows were not
individually proven to witness a `meas_flabel` change"* — understates it: the suite **cannot**
witness one. The real cover for the delegation is **`LB5` in `test_ase_core`** and nothing else on
the headless arm, exactly as the receipt's arm S4 found. The receipt's suite table row
*"`test_ase_meas_1443` | 113 | 113 | — (regression cover for `meas_flabel`)"* should be corrected
before it is carried forward.

**The delegation itself is not in doubt** — `LB5` reddens on both arms and the shipped values are
`Stop time (s):` / `Averaging points:`. What is refuted is the *claim about where the cover lives*.

## Claim 2 — "One accessor, never a second table", scoped to `nz_arg_label` → **REFUTED** (the scope is under-stated)

The receipt discloses `ase::ui::nz_arg_label` as a third variant deliberately not folded in. Grepping
for the **shape** rather than for names — `string totitle`, `dict … label` over a field descriptor,
unit-in-parentheses, trailing colon — finds **three more bodies the receipt does not name**, and two
of them produce a **refusal**, which is A3's own subject.

| body | file | shape | does it match `ase::caption_of`? |
|---|---|---|---|
| `ase::meas_verdict` | `ase.tcl:8341-8345` | declared `label`, else the slot — **no unit** | **No** for 8 fields |
| `ase::meas_template_expand` | `ase.tcl:8720-8725` | declared `label`, else the slot — **no unit** | **No** for 6 required fields |
| `ase::ui::meas_tpl_show` | `ase_window.tcl:8560-8566` | declared `label`, else the **raw** slot, plus unit, plus colon | Identical **today** — latent |
| `ase::ui::nz_arg_label` | `ase_window.tcl:6250` | declared/per-value label, `unit source` special case | disclosed by the receipt |

**Measured, rendered, not inferred.** With a live analysis binding so the refusal is actually
reached:

```
'm1' needs a value for Fundamental          form says  Fundamental (Hz):
'm1' needs a value for Start                form says  Start (Hz):
this template needs a value for Passband gain     form says  Passband gain (dB):
this template needs a value for Start level       form says  Start level (V):
this template needs a value for Final value       form says  Final value (V):
this template needs a value for Tolerance         form says  Tolerance (V):
this template needs a value for Fundamental       form says  Fundamental (Hz):
```

Eight measurement-kind fields differ (`trigtarg/trigtd`, `trigtarg/targtd`, `find/td`, `when/td`,
`fourier/fund`, `spec/start`, `spec/stop`, `spec/step`) and six required template fields differ. The
A3 ruling's wording is *"a refusal names the label the user can see — trailing colon stripped, **unit
kept**"*; these refusals drop the unit. `ase::ui::meas_tpl_show` is behaviourally identical to
`caption_of` for every template field today (all 23 declare a label), so it is a duplicate body with
no live divergence — the latent case A3's own reasoning warns about.

**This is a scope finding, not a correctness finding.** Nothing A3/A4/A5 changed is wrong; the claim
*"the caption rule now has exactly one body and every surface asks it"* is true **of the analysis
registry** and **of `meas_flabel`**, and the receipt's §"Found and NOT fixed" item 5 names one of the
four outliers where it should name four. Row `LB5` asserts four specific delegations and is
therefore accurate as written; it is the prose around it that reads wider than it was measured.

⚠ **Note for the driver:** `ase::meas_verdict`'s sentence is not undocumented copy — `R9_COPY_REVIEW`
carries it as the frame `'$name' needs a value for $lbl` and says explicitly *"the ONE place a field
label reaches the user today is composed"*. So this is a **known** surface that A3's implementation
did not reach, not a hidden one.

## Claim 3 — Correction C1: `LB9` is the only guard on `SEGFAULTS` → **CONFIRMED**

Arm **S2′**, built by me: `SEGFAULTS` → `segfaults` on the **one** line of the `meas_rule` sentence
(`ase.tcl:27666`), chosen by line address because the word appears on five lines of that file.
**Counted diff: 1 removed / 1 added.**

| suite | arm | verdict |
|---|---|---|
| `test_ase_core` | headless | `1 FAILED (661 passed)` — **`LB9` alone**, term list `{1 0 0 1 0 0 1 0 0}` vs `{1 0 1 1 0 1 1 0 1}` |
| `test_ase_preflight` | headless | **`ALL PASS (238)`** |
| `test_ase_meas_1443` | headless | `ALL PASS (113)` |
| `test_ase_window` | headless | `ALL PASS (56)` |
| `test_ase_optsheet_1441` | headless / display | `ALL PASS (64)` / `ALL PASS (89)` |
| `test_ase_trnoise_1466` | headless | `ALL PASS (80)` |
| `test_ase_trnoise_gui_1467` | display | `ALL PASS (63)` |
| `test_ase_dialogs` | display | `1 FAILED (387 passed)` — `G2sens` only, i.e. unmoved |

**The crew's own correction is right and its false citation is really false.** `test_ase_preflight`
comes back `ALL PASS (238)` with the word lowercased, so `PF234`/`PF234a` pins a different
occurrence. **`LB9` is load-bearing and is the only thing standing between A1's named exception and a
tidy-up.** The corrected source comment states this accurately.

## Claim 4 — Correction C2: LB7 does not catch the hardcode, only its consequence → **CONFIRMED, both halves**

Three arms, each a counted diff against `work/`.

| arm | mutation | diff guard | `test_ase_core` | LB7's actual tuple |
|---|---|---|---|---|
| **F** | the fix clause **freezes** the caption: `clear [ase::field_caption …]` → `clear Start time (s)` | 1 / 1 | **`ALL PASS (662)`** | — (green) |
| **R** | the caption is **reworded** only: `label {Start time}` → `label {Begin at}` | 1 / 1 | `1 FAILED (661)` — LB7 | `{Begin at (s)} caution 1 1 **1** 0` |
| **F+R** | both together | 2 / 2 | `1 FAILED (661)` — LB7 | `{Begin at (s)} caution 1 1 **0** 0` |

Read term 5 (*"the fix names the caption"*): **1 under reword-alone, 0 under reword-plus-freeze.**
That is precisely the weaker guarantee the receipt retracted to — the freeze is invisible on the day
it is typed (arm F is a clean 662) and only shows up as term 5 flipping when the caption later moves.
The stronger claim the receipt withdrew would indeed have been false. **The corrected statement in
all three places is accurate.**

## Claim 5 — Row LB2 is load-bearing → **CONFIRMED for focus; the Advanced clause is true by construction and currently unreachable via `missing`**

Arm **T**: `lappend out [list missing $slot …]` → `[list missing $cap …]` at `ase.tcl:5311`.
**Counted diff: 1 removed / 1 added.**

* `test_ase_core` → `5 FAILED (657 passed)`: **`LB2`**, plus `TF3`, `PZ3`, `SE3`, `MP11` — every
  golden that pins a tuple. Declared blast radius, not a surprise.
* `test_ase_dialogs` **display** → `2 FAILED (386 passed)`: `G2sens` (pre-existing) and **`G2f`**,
  whose actual is `{1 1 .ase5.chana}` against `{1 1 .ase5.chana.form.step}` — **the focus lands on
  the dialog instead of in the offending box.** LB2 is testing something real; the damage is
  end-to-end and visible at the widget.

⚠ **Two qualifications the receipt does not make, both measured.**

1. **No analysis field is both `advanced 1` and `required 1`** (measured across all types: the twelve
   advanced fields are `dc/source2 start2 stop2 step2`, `tran/tstart tmax uic`, `noise/contributors
   ptssum`, `disto/f2overf1`, `sp/donoise s2p`, every one `required 0`). So a `missing` offence can
   never today reach the *" It is under Advanced."* clause at all.
2. **The other three offence kinds still carry the slot after A3** — measured on the working tree:
   `fill`→`step`, `boolval`→`uic`, `belowmin`→`points`. Those are the clauses that *can* reach an
   advanced field, and A3 did not touch their element 1.

So the Advanced half of LB2 is correct as an *invariant* — `ase::field_descriptor ngspice tran
{Start time (s)}` returns `{}` while `… tstart` returns the descriptor, so a caption-carrying tuple
would silently lose the clause — but it is proven by construction rather than by a live red, and the
red LB2 actually earns is the focus. **The claim is true; the receipt's phrasing implies both halves
are demonstrated, and only one is.**

## Claim 6 — A3's per-row caption (LB3) → **CONFIRMED, and wider than claimed**

Measured for **both** relabelling types, not just the one the receipt names:

| stored `sweep` | `ac` | `noise` |
|---|---|---|
| *(absent)* | `Points per decade` | `Points per decade` |
| `dec` | `Points per decade` | `Points per decade` |
| `oct` | `Points per octave` | `Points per octave` |
| `lin` | `Number of points` | `Number of points` |
| `nonsense` | `Points per decade` | `Points per decade` (falls back to the mode field's `default`) |

And the refusal on a row **storing `oct`** really says it, rendered from
`ase::analysis_emit_check`:

```
needs 'Points per octave' to be at least 1     (tuple element 1 = points)
needs 'Number of points' to be at least 1      (lin)
needs 'Points per decade' to be at least 1     (dec)
```

Arm **S3′** is not needed to establish this; it is a direct measurement of the shipped code. The
receipt's mapping is exactly right.

## Claim 7 — A5's acceptance criterion: the fact survived the rename → **CONFIRMED**

The ruling's test is that *"ngspice still simulates from 0"* must survive. Rendered by me:

```
ase::needs_eval ngspice tran tstart_note {type tran tstart 5u} {} {}
  -> caution {ngspice still simulates from 0 and only discards the output before 5u,
              so this shortens the results file and not the run}
             {clear Start time (s) to keep the whole waveform}

ase::precheck_banner_text {state caution lines {…}}
  -> ⚠ ngspice still simulates from 0 and only discards the output before 5u, so this
     shortens the results file and not the run. Fix: clear Start time (s) to keep the
     whole waveform
```

**Reachability, measured on two real surfaces**, not asserted:

* **the bench-wide pre-run advice block** — `ase::analysis_precheck ngspice $state {}` on a state
  whose tran row is enabled with `tstart 5u` returns
  `tran {{tstart_note caution {…} {…}}}`. This is the second surface the receipt flags and does not
  suppress; it is real.
* **the form's note** — `ase::ui::chana_note` → `ase::precheck_banner` → `ase::analysis_needs` →
  `ase::needs_eval`. I confirmed the middle link directly: `ase::analysis_needs` with a non-empty
  `facts` returns the `tstart_note` line, and `precheck_banner_text` renders it as quoted above.
  ⚠ **A scoping fact worth recording:** `ase::precheck_banner` returns `{state cold}` unless
  `ase::facts_status` is `warm` **and** `netlist_facts_cached` is non-empty, so on a bench that has
  never been netlisted the form shows the cold sentence and **not** this note. That is the banner's
  pre-existing design (issue 1435), not A5's doing, but "reachable" means *after a netlist*.

**Silence when unset — CONFIRMED, including the receipt's 104-bench claim, which I checked rather
than assumed.** `{type tran}`, `{type tran tstart {}}` and `{type tran tstart {  }}` all return `{}`.
Walking every `git ls-files -- *.state` file and evaluating `tstart_note` on each `tran` row:
**104 benches read, 0 loud.** Containment confirmed too: `tstart_note` is in `tran`'s `needs` list
and in no other type's.

## Suite numbers, both arms, run by me → **CONFIRMED**

| run | verdict |
|---|---|
| `test_ase_core` headless, working tree | **`ALL PASS (662 checks)`** |
| `test_ase_core` display `:99`, working tree | **`ALL PASS (662 checks)`** |
| `test_ase_core` headless, `XSCHEM_SHAREDIR=work/src` (method control) | `ALL PASS (662)` |
| `test_ase_core` headless / display, **pristine** | `ALL PASS (653)` / `ALL PASS (653)` |
| `test_ase_dialogs` headless, working tree | `ALL PASS (37 checks)` |
| `test_ase_dialogs` display `:99`, working tree | **`1 FAILED (387 passed)`** — `G2sens` only |
| `test_ase_dialogs` display `:99`, **true pristine** (pristine src **and** pristine suite) | **`1 FAILED (386 passed)`** — **`G2sens` only** |
| `test_ase_preflight` headless | `ALL PASS (238)` |
| `test_ase_meas_1443` headless | `ALL PASS (113)` |
| `test_ase_window` headless | `ALL PASS (56)` |
| `test_ase_optsheet_1441` headless / display | `ALL PASS (64)` / `ALL PASS (89)` |
| `test_ase_trnoise_1466` headless | `ALL PASS (80)` |
| `test_ase_trnoise_gui_1467` display | `ALL PASS (63)` |

**`G2sens` is genuinely pre-existing**, established by *running* a true-pristine tree — pristine
source **and** pristine suite — not by reading the assertion: the same row, the same actual value
`{1 1 0 1 0 Entry Entry normal}`, and nothing else red. Issue
**1436** (`doc/claude/issues/1436-two-display-arm-rows-of-test-ase-dialogs-have-been-red-since-before-stage-6.md`)
exists and names it. Not A3/A4/A5's.

Arithmetic, for a future reader: the display suite is **388 rows** after (387 pass + `G2sens`) and
**387 before** (386 + 1). The floor paragraph counts *passed*, not rows — the same convention 53b
recorded.

**Floors raised in each file's own paragraph, confirmed in the source:** `test_ase_core.tcl:198`
`AND RAISED 653 -> 662`; `test_ase_dialogs.tcl:208` `37 / 387  AND RAISED 386 -> 387`.

**Moved-not-gained lists confirmed against the diff:** core 8 (`EK1 EK4 AC1 AC2 TF3 PZ3 SE3 MP11`),
dialogs display 5 (`G2c G2tf G2pz G2sens G2f`), and the four dialog rows really do gain an
absence term (`g2tf_slot` / `g2pz_slot` / `g2se_slot` and `G2f`'s accessor call).

## `.state` byte identity → **CONFIRMED**

Driven as a **proc**, `ase_state_roundtrip $repo`, never by running the script:

```
tracked 104   bad {}   control_disagrees 1   control_agrees 1
```

All four reported, both controls live. A run reporting `bad {}` with a dead control would prove
nothing; these are alive.

## The handle table's rendered sentences → **CONFIRMED**

Rendered by me from the shipped procs, not read from the crew's probe log:

| handle | rendered |
|---|---|
| `R9-062` | `needs a value for 'Stop time (s)'` |
| `R9-063` | `'Use initial conditions' must be on or off` |
| `R9-064` | `cannot read 'zz' as a number for 'Time step (s)'` |
| `R9-075` | `needs 'Points per octave' to be at least 1` (and `Report every N points` is `noise/ptssum`'s real caption) |
| `R9-159` | `needs a value for 'Time step (s)'` — via `ase::ui::arg_summary`, the grid cell |
| `R9-356` | `'FFT spectrum' reads a transient, …` |
| `R9-361` | `… and SEGFAULTS for Delay (TRIG ... TARG). Measure FIND, MIN, MAX or AVG there, …` |
| `R9-003` / `R9-004` / `R9-002` | `Stop value:` / `Step size:` / **`Start:`** (still bare, as reported) |
| `R9-017` / `R9-025` | `Start time (s):` |

⚠ One cosmetic nuance in my fixture, not a defect: `R9-361`'s `[string toupper $kind]`→`$klbl` change
is confirmed, and `R9-356` rendered `bound to a  analysis` (double space, empty `$type`) because my
fixture bound the row to an analysis the state did not carry. That is `meas_binding` behaving
normally on a synthetic row, not new copy.

## Bookkeeping → **CONFIRMED**

* Header line 14 reads **`730 strings, from 38 issues`**; it read `728` at `a7bd53b7`.
* `R9-729` and `R9-730` are present under a `⚖ NEW COPY THIS RULING PRODUCED … **NOT YET RULED ON**`
  block in §A5, following §A1's `R9-727`/`R9-728` precedent.
* `grep -c '^\*\*R9-'` is **727** on the working tree and **727** at `a7bd53b7`; distinct anchored
  handles **726**. Unmoved, exactly as the receipt explains — the two new ones live inside a
  blockquote.

**I looked for new user-visible copy with no handle and found none.** Every added string literal in
the `src/` diff is one of: the `tstart_note` caution and fix (`R9-729`/`R9-730`), `Stop value`
(`R9-003`), `Step size` (`R9-004`), `Start time` (`R9-017`/`R9-025`), or `$klbl` substituted into
`R9-356`/`R9-361`. The captions newly exposed inside refusals all have handles already
(`Report every N points`, `Input source`, `Input +`, `Output +`, `Sweep type`, `Points per decade`,
`Points per octave`, `Number of points`, `Start frequency`, `Stop frequency`, `Averaging points` —
each found as a `text` block in `R9_COPY_REVIEW.md`). **I minted no handle and ruled on no copy.**

## Sabotage arms redone independently — seven arms, every guard a COUNTED DIFF

| arm | mutation | diff guard | reds |
|---|---|---|---|
| **M1** | `meas_flabel` returns `"$field:"` | 1 / 1 | core `LB5` **alone**; meas 113 ALL PASS; window 56 ALL PASS; dialogs unmoved |
| **M2** | `meas_flabel` raises | 1 / 1 | core **dies** (positive control); meas **113 ALL PASS** ⇒ never called |
| **S2′** | `SEGFAULTS`→`segfaults`, the `meas_rule` line only | 1 / 1 | core `LB9` **alone**; seven other suites unmoved |
| **T** | the `missing` tuple carries the caption | 1 / 1 | core `LB2` `TF3` `PZ3` `SE3` `MP11`; dialogs display **`G2f`** (focus) |
| **F** | the fix clause freezes the caption | 1 / 1 | **nothing** — core `ALL PASS (662)` |
| **R** | the caption is reworded only | 1 / 1 | core `LB7`, term 5 = **1** |
| **F+R** | frozen **and** reworded | 2 / 2 | core `LB7`, term 5 = **0** |

**No md5 was used as a sabotage guard.** Every arm's target was located by a grep required to match
**exactly once** before the edit, and every arm was diffed against `work/` and the changed-line count
compared with the number intended. **No arm reddened a row it was not aiming at**, with one declared
exception: arm **T** reds five rows and four of them (`TF3`/`PZ3`/`SE3`/`MP11`) are tuple goldens
that must move with it — declared in advance, not discovered.

---

## ⚠ FINDINGS THE DRIVER MUST SEE

1. **`test_ase_meas_1443` cannot detect a `meas_flabel` regression** — proven by a proc that raises
   on every call while the suite finishes `ALL PASS (113)`. The receipt's suite-table annotation
   *"(regression cover for `meas_flabel`)"* is wrong and should not be carried forward. **`LB5` is
   the only headless cover**, which is what the crew's own arm S4 measured.
2. **The "one accessor" scope is under-stated by three bodies.** `ase::meas_verdict` and
   `ase::meas_template_expand` each resolve a caption their own way **and put it in a refusal**,
   dropping the unit (`needs a value for Fundamental` where the form says `Fundamental (Hz):`);
   `ase::ui::meas_tpl_show` is a fourth form body, identical today, latent. Fourteen fields measured
   divergent. This is A3's own defect surviving in the measurement registry — **outside A3's ruling
   as written, and the driver's to decide whether it is a follow-up item or a correction to this
   receipt's prose.**
3. **LB2's Advanced-clause half is not demonstrated by any red, and cannot be.** No analysis field is
   both `advanced 1` and `required 1`, so a `missing` offence cannot reach that clause; the other
   three offence kinds still carry the slot. The focus half **is** demonstrated (`G2f`). The claim is
   true; the evidence for one of its two halves is a construction argument, not a test.
4. **The A5 note's form surface is gated on a warm netlist.** `ase::precheck_banner` returns
   `{state cold}` before a netlist exists, so on a never-netlisted bench the user sees the cold
   sentence and not the caution. Pre-existing (issue 1435) and arguably right, but "the fact is
   reachable" means *after Simulation > Netlist > Recreate*, and the receipt does not say so.
5. **Everything else the receipt claims, I reproduced.** Corrections C1 and C2 are both correct and
   both were correctly stated; A3/A4/A5's shipped behaviour matches the ruling blocks in
   `R9_COPY_REVIEW.md` §A3/§A4/§A5, which I read as the authority rather than the receipt's
   paraphrase — including A4's deliberate `Stop time` / `Time step` asymmetry and A4's table naming
   only `Stop` and `Step`, which is why `Start` stays bare.

## Disclosures

* **No simulation was launched by me and `/usr/bin/ngspice` was never invoked directly.** As 53b
  recorded, `test_ase_dialogs`' display arm runs a simulator of its own accord (`SP14/apt`,
  `SP14/fork`); I ran that suite the way receipt 54 did, added no simulation to it, and wrote no deck
  under `sky130A/`.
* **Every command carried a `timeout`.** No waiting loop was used; no background command was left
  running; every run ended in a named verdict.
* **Binary always by path** (`./src/xschem`, `devdisplay.sh exec ./src/xschem`), always `--nolog`,
  never `--logdir`, never a bare `xschem`.
* Display arm is **`:99`** (Xvfb, **openbox 3.6.1**, `1920x1080x24`, `devdisplay.sh status` = alive).
  **No `:0` and no `$DISPLAY` run was taken; no pixel deliverable is claimed** and no `look` debt is
  discharged by anything here.
* Processes matched by **name** (`ps -eo comm=`), never `pgrep -f`, never `pkill`. Alive and not
  mine: **`Xvfb`** (the shared `:99` dev display) and **two `xschem`** processes that predate this
  session. **No `ngspice` process at any point.**
* **Nothing in the repository was written except this receipt.** All scratch trees, mutations, probes
  and logs live under the session scratchpad (`…/scratchpad/v54b/`): `pristine/`, `work/`, and seven
  mutation trees. **None of them is a restore snapshot** — no script of mine copies anything back
  into the repo, so there is nothing to disarm; they are inert `XSCHEM_SHAREDIR` targets. Campaign
  logs are kept beside them (`logs/`).
* **`tests/run_regression.tcl` was NOT run** — the driver's, solo (issue 0990).
