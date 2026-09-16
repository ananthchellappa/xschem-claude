# ⚖ R9 rulings A9 and A10, and §A3's remainder — one word per idea, and a caption rule that finally has one body

**One task from the driver: implement A9 and A10, and finish §A3 in the measurement registry.**
Files touched, and nothing else: `src/ase.tcl`, `src/ase_window.tcl`,
`tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_dialogs.tcl`,
`tests/headless/test_ase_meas_1443.tcl`, `tests/headless/test_ase_preflight.tcl`,
`R9_COPY_REVIEW.md`, and this receipt.

No C. No new `.tcl` file, so no `src/Makefile.in` / `./configure` obligation.

HEAD was `94c4dd72` at hand-over and is `94c4dd72` now. **No commit, no `git add`, no
stash/restore/checkout/clean/push.** `tests/run_regression.tcl` **NOT run** — the driver's, solo
(issue 0990). `owed.sh count` is **188 rule, 71 look, 11 suite** before and after: nothing added,
nothing cleared, the shared cross-clone ledger never written, so no backup was needed.
`~/.xschem/recent_files` is **untouched at 2026-09-13 18:53:01** (issue 0924 canary), checked at
the start and at the end. **`/usr/bin/ngspice` was never invoked**, no simulation was run, no deck
was written under `sky130A/`, and **no `ngspice` process existed at any point**.

**104 of 104** tracked `.state` files round-trip byte-identically — `tracked 104`, `bad {}`,
**`control_disagrees 1`, `control_agrees 1`** — driven as a **proc** (`ase_state_roundtrip`), never
by running `state_roundtrip.tcl` as a script. Measured before the change and on the tree as it
hands over. Nothing here touches what ASE-L *emits*; every change is a caption or a sentence.

⚠ **The four untracked paths in `git status` are not mine** — they were in my baseline at
`94c4dd72`. I opened none of them.

---

## ⚠ THE HEADLINE: §A3's "ONE ACCESSOR" WAS TRUE OF ONE REGISTRY, AND IS NOW TRUE OF THREE

Task 1 built `ase::caption_of` and claimed *"one accessor, never a second table"*. Its verifier
refuted that, and this task finishes the job. **I re-measured the divergence independently rather
than taking 54b's number**, walking every field of every kind and every template and comparing the
old per-body rule against `ase::caption_of`:

| registry | fields | divergent | what the divergence was |
|---|---|---|---|
| `ase::meas_kind_field` (via `ase::meas_verdict`) | 64 | **8** | **the unit was dropped** |
| `ase::meas_template_fields` (via `ase::meas_template_expand`) | 22 | **6** | **the unit was dropped** |
| `ase::meas_template_fields` (via `ase::ui::meas_tpl_show`) | 22 | 0 | **latent** — identical today, its own copy of the rule |

**Fourteen divergent fields, confirming the driver's brief exactly.** The eight are
`trigtarg/trigtd`, `trigtarg/targtd`, `find/td`, `when/td`, `fourier/fund`, `spec/start`,
`spec/stop`, `spec/step`; the six are `bw3db/gain`, `sr/lo`, `sr/hi`, `ts/final`, `ts/tol`,
`thd/fund`. Two of the three bodies put their answer in a **refusal**, which is §A3's own subject:
a user was told `needs a value for Fundamental` at a box captioned **`Fundamental (Hz):`**.

All three now ask `ase::caption_of`. Measured, rendered, not asserted:

```
'm1' needs a value for Fundamental (Hz)          (was: Fundamental)
'm1' needs a value for Start (Hz)                (was: Start)
this template needs a value for Passband gain (dB)   (was: Passband gain)
this template needs a value for Start level (V)      (was: Start level)
this template needs a value for Final value (V)      (was: Final value)
'm1' needs a value for Value                     <- the control: no unit, still bare
```

⚠ **`ase::ui::meas_tpl_show` is the interesting one and it reds nothing today.** It agreed with
`caption_of` for every template field, so folding it changes no pixel — it was a duplicate body
with no live divergence, which is precisely the latent case §A3's reasoning warns about. **Row
LB11 is the only thing that would notice if it grew its own copy back**, and sabotage S3 proves
that (below).

⚠ **`ase::ui::nz_arg_label` STAYS OUT, and I did not re-litigate it.** The brief said the
judgement stands unless I concluded otherwise; I did not do an analysis deep enough to overturn
it, and I am saying so rather than implying I checked and agreed. What I did confirm is that it is
over a **different** registry with a different arity (`{sim type fn e d}`) and a `unit source`
special case the other three lack. **Not folded, and not endorsed either way.**

---

## PART 1 — §A3's remainder, by handle

| body | file | change |
|---|---|---|
| `ase::meas_verdict` | `ase.tcl` | resolved its own caption → asks `ase::caption_of` |
| `ase::meas_template_expand` | `ase.tcl` | resolved its own caption → asks `ase::caption_of` |
| `ase::ui::meas_tpl_show` | `ase_window.tcl` | label+unit+colon by hand → `[ase::caption_of $f $fn]:` |

⚠ **A behaviour change worth naming: the no-label fallback moved.** All three bodies fell back to
the **bare slot**; `ase::caption_of` falls back to `[string totitle $field]`. Every field in the
ngspice registries declares a label, so **no shipped caption moves** — but a future adapter that
omits one now gets `Fund` where it used to get `fund`. That is §A3's ruled fallback (row LB4's
rule) arriving on two more registries, and it is the right direction rather than an accident.

### ⚠ `test_ase_meas_1443` NOW HAS REAL COVER, AND I AM SAYING PLAINLY WHAT KIND

The brief warned that this suite *looks* like cover and is not — 54b made `ase::ui::meas_flabel`
raise on every call and the suite still finished `ALL PASS (113)`, because it is headless-only and
that proc is reached solely from a widget loop.

**`ase::meas_verdict` and `ase::meas_template_expand` are a different case, and I checked rather
than assumed**: the suite already drives `meas_verdict` at fifteen sites and
`meas_template_expand` throughout section TP. Both are pure Tcl and need no widget. So I **added
two rows that genuinely drive them** — **`VD17`** and **`TP7`** — and **both reddened under
sabotage** (S1 and S2). That is real cover, established by a red and not by a green.

**I did NOT add cover for `meas_flabel` there, and it still has none in that suite.** `LB5` in
`test_ase_core` remains its only headless cover, exactly as the driver correction on receipt 54
says.

---

## PART 2 — A9: every `<…>` left on screen is now a real value

**Ruled site `R9-138`, and its sibling `R9-140` moved with it:**

```
was:  add `distof1 <mag> <phase>` to the input source (phase is in degrees)
now:  add `distof1` to the input source with a magnitude and a phase in degrees

was:  add `distof2 <mag> <phase>` to a source, or clear the F2/F1 ratio to measure harmonics instead
now:  add `distof2` to a source with a magnitude and a phase in degrees, or clear the F2/F1 ratio
      to measure harmonics instead
```

⚠ **`R9-140` is NOT in §A9's ruling table, which names `R9-138` alone. I moved it and I am
reporting that rather than claiming the ruling covered it.** Two reasons, and the first is the
ruling's own: A9's stated point is *the invariant, not the sentence*, and **half an invariant is
not one** — a sweep that fixes one of two identical sentences cannot deliver *"any `<…>` a user
sees is a value that failed to substitute"*. The second is that leaving it would have manufactured
**§A8's exact defect by hand**: two adjacent remedies, in the same dialog, for the same mistake,
spelled two different ways. Measured after the change: **0 literal `<` across both clauses and
both remedies.**

### ⚠ THE SWEEP — four other literal angle-bracket sites, and only one of them is out of class

I swept `src/ase.tcl` and `src/ase_window.tcl` for `<…>` in non-comment lines, discarding Tk event
bindings. **Reported, not fixed** — §A9's ruling says *"sweep … and report any found"*, and that
verb is the ruling's:

| site | string | status |
|---|---|---|
| `ase.tcl`, `sens_filters` remedy | ``…a device inside a subcircuit is named `<letter>.<instance path>.<name>` `` | **user-facing, literal, still there.** Carries an R9 handle whose own *Note* already calls it *"a literal angle-bracket template in the shipped string"* |
| `ase.tcl`, `preflight_gate`'s case-mismatch advice | ``run `ase::preflight_fix_session <key>` …`` | **user-facing, literal, still there** — reaches the CIW via `::ase::echo … error` |
| `ase.tcl`, the `xtrtol` remedy | ``add `set xtrtol=<n>` to this analysis's verbatim lines`` | **user-facing, literal, still there** |
| `ase.tcl`, `no_spinit`'s `caveat` | ``…still read `<rundir>/.spiceinit`…`` | ⚠ **UNREACHABLE — measured, not reasoned.** `ase::opt_offer ngspice no_spinit` answers **`elsewhere`**, and `ase_window.tcl`'s only `CAVEAT:` render arm fires on `caveat` alone. The two options that *do* reach that arm (`scale`, `wnflag`) carry no angle bracket. **Out of the sweep** |

One more, out of class: the Verilator co-simulation `patch` text carries
`std::unique_ptr<VerilatedContext>`. That is **C++ source the user is meant to paste**, not a
placeholder, so it is not the thing A9 is about.

⚠ **SO THE INVARIANT IS NOT YET TRUE TREE-WIDE, AND I WILL NOT CLAIM IT IS.** Three user-facing
literal sites remain. A9's sentence *"any `<…>` a user sees is a value that failed to substitute"*
holds **on the distortion preconditions** and nowhere else until those three are ruled on. **This
is the driver's to raise with the user** — each is a *syntax template in backticks* rather than a
value to type over, which is arguably a different class, and deciding that is not a crew's call.

---

## PART 3 — A10: one idea, one word

| concept | was | now |
|---|---|---|
| the level a signal must reach | `Value` (when) · **`reaches`** (find) · `Trigger value` / `Target value` (delay) | `Value` · **`Value`** · `Trigger value` / `Target value` |
| ignore the signal until | `Ignore before` (find, when) · **`Trigger delay`** / **`Target delay`** (delay) | `Ignore before` · **`Trigger ignore before`** / **`Target ignore before`** |

Measured, rendered through the real form accessor:

```
find/value      Value                        when/value      Value
trigtarg/trigtd Trigger ignore before (s)    trigtarg/targtd Target ignore before (s)
trigtarg/trigval Trigger value               trigtarg/targval Target value
find/td         Ignore before (s)            when/td         Ignore before (s)
```

### ⚠ THE LAYOUT DETAIL, SETTLED AGAINST THE REAL FORM — I LOOKED, AND THERE ARE NO HEADINGS

§A10 told me to default to `Trigger ignore before` / `Target ignore before` **but** to use plain
`Ignore before` twice if the form already groups its rows under Trigger and Target headings.

**It does not.** `ase::ui::meas_show` renders **one flat label column**: `Name`, `Kind`,
`Analysis`, optionally `Measured on`, and then a single `foreach` over the kind's fields putting
every caption at `$w.form.lf<field>`, column 0. There is no `labelframe`, no separator and no
heading anywhere between them — I read the whole proc and then grepped its body for
`labelframe|heading|separator|-text` to be sure. Two boxes both reading `Ignore before` would
therefore be **indistinguishable**. **So the qualified default stands**, and the source comment
says which condition would reverse it if headings are ever added.

### ✅ `R9-325 reaches` DISSOLVED, AND THE TREE REALLY IS SIMPLER FOR IT

`reaches` was the **only lowercase label in the tree**, and it read correctly only if the form laid
`When signal` and `reaches` on **one line**. Ratifying that one word would have ratified **a layout
constraint**. Under A10 it becomes `Value` — the word the `when` form already used for the same
idea — and the constraint has nothing left to constrain. That is a ruling that *removes* a
requirement rather than adding uniformity, and it is the best thing in it.

⚠ **BUT §A10'S PREMISE IS STALE AND THE DRIVER SHOULD KNOW.** Both the ruling and every R9 entry
in that band say *"no form renders it at HEAD (task 1 builds no widget)"*, and **that is no longer
true**: `ase::ui::meas_show` renders the measurement form today, and **the layout constraint was
already implemented** — an inline-continuation branch keyed on a lowercase initial letter, plus
`ase::ui::meas_inline`, plus row `MS9` asserting it. So this was not a constraint on a dialog that
does not exist; it was a constraint on one that does.

**What I did about that, and why it is a judgement rather than a conclusion:** I **kept** the
mechanism and **pinned that nothing now reaches it**. Deleting `meas_inline` and its widget branch
is a *code* question §A10 did not ask, and it would have meant removing a row rather than moving
one. `MS9` was rewritten to assert the opposite of what it used to — that `Value:` starts its own
row in the ordinary caption column, and that **no shipped label of any kind begins lowercase** — so
the next reader learns the branch is *unreached*, not *broken*. **If the driver wants it deleted,
that is one more change and it should be asked for.**

### ⚠ §A5 AND §A10 CONFLICT, AND THE CONFLICT IS PINNED RATHER THAN SMOOTHED

§A5 ruled captions are noun phrases — that is why `Start recording at` became `Start time` (row
LB7). §A10 keeps **`Ignore before`**, an imperative. It stands as **§A5's single named exception**,
because every noun-phrase alternative is worse: it is **not a start time** (the simulation has
already started and is still running) and **not a delay** (nothing is delayed — the signal is
watched from the beginning and early crossings are discarded). `delay` was the word that *lied*,
and it is the word that left.

**Row `LB13` is the only place this is written down**, pinned exactly as `SEGFAULTS` is by `LB9`
under §A1, `dec`/`oct`/`lin` by `PZ2f` under §A2, and the `Stop time`/`Time step` asymmetry by
`LB6` under §A4 — because a ruling that deliberately leaves the interface looking inconsistent is
precisely the one a later consistency pass reverses in good faith. **Sabotage S9 is that arm**: it
tidies `Ignore before` into the noun phrase `Ignore time` and `LB13` goes red.

---

## Suites — both arms

`nogui` = `./src/xschem --nogui --pipe -q --nolog`; `disp` = `devdisplay.sh exec` on **`:99`**
(Xvfb, **openbox 3.6.1**, `1920x1080x24`, `devdisplay.sh status` = alive).

| suite | before (nogui / disp) | after | rows |
|---|---|---|---|
| `test_ase_core` | 669 / 669 | **673 / 673** | **LB10–LB13 gained**; `MT5` moved |
| `test_ase_meas_1443` | 113 | **115** | **VD17, TP7 gained** |
| `test_ase_preflight` | 242 | 242 | `PF234c` **moved and strengthened** |
| `test_ase_dialogs` | 37 / 387 passed | 37 / 387 passed | `MS9` **moved** |
| `test_ase_window` | 56 | 56 | — |
| `test_ase_trnoise_1466` | 80 | 80 | — |
| `test_ase_trnoise_gui_1467` | 63 (disp) | 63 | — |
| `test_ase_simreg_0931` | 118 | 118 | — |
| `test_ase_optsheet_1441` | 64 / 89 | 64 / 89 | — |

**Floors raised, each in its own file's paragraph:** core **669 → 673**, meas **113 → 115**.
Preflight and dialogs are **unmoved by design** — their rows moved rather than being added — and
both files now carry a paragraph saying so. **No floor was lowered.**
⚠ **DRIVER CORRECTION, 2026-09-16 — "both files" is false.** `test_ase_dialogs` carries its
paragraph; **`test_ase_preflight` does NOT.** Its only note about this ruling is an inline comment
roughly **2,350 lines below** the floor block, where nobody checking a floor will look. The floors
themselves are right and no floor was lowered — it is the *explanation* that is missing from the
one file most likely to be read for it. **Scheduled as task 3's residue in task 4.**

⚠ **`test_ase_dialogs`' display arm carries ONE red before AND after: `G2sens`**, actual
`{1 1 0 1 0 Entry Entry normal}`. **Issue 1436**, pre-existing, **not mine** — and I established it
by running the tree *before* touching anything, not by reading the assertion. T1 runs this file on
neither arm.

**Counted diff of the source, whole files:** `src/ase.tcl` **−12 / +70**, `src/ase_window.tcl`
**−16 / +24**. Of those, the **non-comment** changes are exactly **−12 / +8** and **−6 / +2** —
ten source edits in all; everything else added is comment.

---

## Sabotage — nine arms, every guard a COUNTED DIFF, every red set exactly the declared one

Each arm: restore from the finished snapshot with plain `cp` → locate the target by an **exact**
needle that must occur **exactly N times or the arm aborts** → plant → diff against the snapshot
and require **exactly** the intended changed-line counts → run → restore.
⚠ **No md5 was used as a sabotage guard.** md5 is used only at the end, to prove the restore.

⚠ **The red-extractor was fed the empty case BEFORE it was trusted**, and it is a **positive**
assertion (*"I saw a `RESULT:` line"*), never *"I did not see FAIL"*:

```
GATE empty      -> DIED(empty log)          GATE failnoline -> DIED(FAILED but no FAIL: lines)
GATE whitespace -> DIED(empty log)          GATE allpass    -> ALLPASS
GATE noresult   -> DIED(no RESULT line)
```

It never answers `(none)`, and the run asserts that before any arm plants.

| | sabotage | diff | declared blast radius | measured reds |
|---|---|---|---|---|
| S1 | A3 — `meas_verdict` re-derives its caption | −1/+1 | core `LB10` `LB11` · meas `VD17` | **exactly that** |
| S2 | A3 — `meas_template_expand` re-derives | −1/+1 | core `LB10` `LB11` `MT5` · meas `TP7` | **exactly that** |
| S3 | A3 — `meas_tpl_show` grows its copy back | −1/+1 | core `LB11` alone · dialogs UNMOVED | **exactly that** |
| S4 | A9 — the `distof1` remedy reverts | −1/+1 | core `LB12` · preflight `PF234c` | **exactly that** |
| S5 | A9 — only the `distof2` sibling reverts | −1/+1 | core `LB12` alone · preflight ALL PASS | **exactly that** |
| S6 | A10 — `find/value` back to `reaches` | −1/+1 | core `LB13` · dialogs `MS9` (+`G2sens`) | **exactly that** |
| S7 | A10 — `trigtarg/trigtd` back to `Trigger delay` | −1/+1 | core `LB13` alone | **exactly that** |
| S8 | A10 — the delay form unqualifies | −1/+1 | core `LB13` alone | **exactly that** |
| S9 | §A5's exception tidied into a noun phrase | −2/+2 | core `LB13` alone | **exactly that** |

**Every arm's blast radius was declared in advance and every arm hit exactly it.** No arm reddened
a row it was not aiming at, and none had to be discarded.

**Ends on a positive restored-tree row:** `test_ase_core` **ALL PASS (673)**, `test_ase_preflight`
**ALL PASS (242)**, `test_ase_meas_1443` **ALL PASS (115)**, `test_ase_dialogs` display **`G2sens`
only**, and both sources **md5-equal** to the finished snapshot.

### ⚠ S3 IS THE ONE THAT MATTERS, AND IT REPEATS THIS BATCH'S MOST-MET FINDING

S3 wrecks `ase::ui::meas_tpl_show`'s caption and **`test_ase_dialogs` does not move on either
arm** — `G2sens` only, its pre-existing red. That is the third time in four tasks that a display
suite turns out to be unable to witness the change it looks like it covers (task 1's dead
`test_ase_meas_1443`, task 2's dialogs-cannot-see-A7, now this). **`LB11` is the only cover
anywhere in this repository for that third body**, and I am stating that as a measured fact rather
than leaving a green dialogs arm to imply otherwise.

⚠ **S5 is the smallest and the most load-bearing for A9's scope claim.** It reverts *only* the
`distof2` sibling, and `LB12` reds while `test_ase_preflight` stays **ALL PASS** — proving the
sibling has no other guard in the tree and that `PF234c` watches the `distof1` half alone.

---

## ⚠ Corrections — three things I got wrong, every one caught by measurement

| | |
|---|---|
| **C1** | ⚠ **MY FIRST A9 EDIT BROKE THE TCL, AND THE SUITES CAUGHT IT IMMEDIATELY.** I put the explanatory `##` comment **inside** the `[list blocked …]` command substitution. **A `#` is not a comment there**: inside `[...]` a newline separates commands, so the remedy string was parsed as a **command name** and the precondition raised `invalid command name "add \`distof1\` …"`. It reddened `MP7`, `WD5b` and `WD5d` in core and **truncated `test_ase_preflight` from 242 rows to 232** — a suite that stops early still prints a plausible `RESULT:` line, which is this batch's own most-met defect shape. Fixed by moving both comments **above** the `return`; the source comment now records the reason so the next reader does not repeat it. |
| **C2** | ⚠ **MY REWRITTEN `MS9` CALLED A HELPER THAT DOES NOT EXIST.** I wrote `[ms_txt $mw.form.lfvalue]`; `test_ase_dialogs` has `ms_grid` but no `ms_txt`, and the idiom there is `cget -text`. Caught by grepping for the helper before running rather than after — but it would have died at the first display run either way. |
| **C3** | A tooling slip of my own, recorded because it silently skipped a verification step: a shell `echo` of mine put three backticks **inside double quotes**, which bash read as an unterminated command substitution, so a doc-verification command **never ran** and returned only an error. Re-run correctly afterwards; the check passed. Nothing in the tree was affected. |

---

## New copy, and the count — reported, never ruled on

⚠ **I minted NO new handle, and the header count is UNMOVED at 730.** Measured before and after:
header line 14 reads `730`, `grep -c '^\*\*R9-'` = **727**, distinct anchored handles = **726** —
identical to the values at `94c4dd72`.

**Every change is a reworded EXISTING handle**, on §A1's and §A4's precedent. The nine entries were
verified by re-reading each fenced `text` block after the edit; a sweep of **every** fenced block in
the document confirms `reaches`, `Trigger delay`, `Target delay` and `distof1/2 <mag>` appear in
**none** of them (they survive only inside *Note* prose, deliberately, as the history of what
changed).

**Where the words came from, stated so nobody has to guess:**

* **A9's sentence is the user's own** — §A9's ruling block writes it out verbatim, and the shipped
  string is that sentence character-for-character.
* **A10's `Value` is the user's own** (§A10's table), and **`Trigger ignore before` /
  `Target ignore before` are the ruling's own stated default**, applied because the measured layout
  matched the condition the ruling attached to it.
* ⚠ **`R9-140`'s new sentence is the one piece of wording no ruling wrote.** §A9's table names
  `R9-138` alone. I composed the sibling to match, for the reasons above, and **I am flagging it
  upward rather than deciding it.** **No `owed.sh add rule` was filed**, on receipts 54's and 55's
  precedent and for their reason: ⚖ R9 is the open ruling that collects exactly these, the document
  now carries the new text under the handle marked as changed, and I did not write the shared
  cross-clone ledger on my own initiative (issue 1400). **If the driver wants a debt, it is one
  command.**

---

## What rests on sabotage, and what rests on a name diff alone

**On sabotage — a named row reddened under a counted diff and was restored:** every claim about
`LB10`, `LB11`, `LB12`, `LB13`, `VD17`, `TP7`, `MS9`, `MT5` and `PF234c`, and the single-body
property for all three folded surfaces. Also the claim that `test_ase_dialogs` **cannot** witness a
`meas_tpl_show` caption change (S3), and that the `distof2` sibling has no guard but `LB12` (S5).

**On a measured rendered string** (probe logs, quoted above, run against the shipped procs): every
sentence in the A3 table, both A9 remedies, all eight A10 captions, the 14-field divergence count,
and the `no_spinit` unreachability.

**On reading the source** (no test can witness it, and I am not pretending otherwise): the claim
that **the delay form has no Trigger/Target headings**. I read `ase::ui::meas_show` end to end and
grepped its body, but *"there is no heading"* is an absence, and no row asserts it. If someone adds
one, nothing goes red and `Trigger ignore before` becomes the wrong choice — **the source comment
beside the registry is the only thing that will tell them**.

> ### ⚠ DRIVER CORRECTION, 2026-09-16 — the absence IS assertable, and this paragraph was too modest
>
> ✅ **The heading absence itself is CONFIRMED** — `meas_show` builds four fixed captions plus one
> `lf<field>` each, all in column 0, with no `labelframe` or separator anywhere.
>
> ⚠ **But "no test can witness it" is REFUTED.** The verifier wrote a **five-line row**, passed it
> on the shipped form (dialogs display 387 → **388**), and **reddened it by adding a real
> `labelframe -text Trigger`**. So the absence is ordinary assertable state, not an unwritable
> claim — and without such a row, a future heading makes `Trigger ignore before` **wrong copy,
> silently**, which is exactly the failure this receipt worried about.
>
> **Scheduled as task 3's residue in task 4**, labelled as such rather than smuggled in as A11/A12
> work. **This is a good kind of wrong to be**: the crew declined to claim cover it had not built,
> and the verifier answered by building it. Under-claiming is what makes that possible.

⚠ **On a name diff alone — weaker, and I am saying so:** `test_ase_window` (56),
`test_ase_simreg_0931` (118), `test_ase_optsheet_1441` (64/89), `test_ase_trnoise_1466` (80) and
`test_ase_trnoise_gui_1467` (63) did not move and I did **not** sabotage them to prove they
*could*. **I claim none of them as cover for anything here.**

⚠ **And one row I want to name as weaker than it looks: `LB11`'s absence half.** It requires that
none of the four bodies contains `dict get $f label`, `string totitle` or `dict get $f unit` — the
three shapes that re-derive the rule. That is a **spelling** test: a body that re-derived the
caption by some *other* spelling would pass it. The presence half and the rendered rows (LB10,
VD17, TP7) are what actually pin the behaviour; the absence half only stops the specific
regression that happened three times already.

⚠ **`LB11` strips comments before scanning, and that is not a detail.** `info body` **sees
comments**, and **every source comment this ruling added contains the literal `ase::caption_of`** —
so an unstripped scan would have passed on the comment alone and proved nothing. `LB5`'s own
comment records that exact trap from a previous pass; I would have walked into it.

---

## ⚠ Found and NOT fixed — stated plainly

1. **Three user-facing literal angle-bracket sites remain** (`<letter>.<instance path>.<name>`,
   `ase::preflight_fix_session <key>`, `set xtrtol=<n>`). **A9's invariant is therefore true of the
   distortion preconditions and not yet of the tree.** Each is a *syntax template in backticks*
   rather than a value to type over — arguably a different class — and §A9 said *report*. **The
   driver's to raise with the user.**
2. **`ase::ui::meas_inline` and its widget branch are now unreached.** Kept deliberately, pinned by
   `MS9` and `LB13`. **Deleting them is a code question §A10 did not ask.**
3. **§A10's premise that "no form renders it at HEAD" is stale** — the measurement form exists and
   the layout constraint was implemented. The `R9-325` entry now records the correction.
4. **`ase::ui::nz_arg_label` is still a fourth caption body.** Out of scope by the driver's
   instruction; I did not analyse it deeply enough to agree or disagree, and I have not implied
   that I did.
5. **`ase::meas_verdict`'s other refusals still name the user's own typed strings** — a measurement
   *name*, a *kind*, a *handle*. Those are not form captions and resolving them through the caption
   accessor would be wrong, exactly as receipt 54 found for `unknownkey` and `group`. Not an
   oversight.
6. **No `:0` or `$DISPLAY` run was taken** — the display arm here is `:99`. **No pixel deliverable
   is claimed** and no `look` debt is discharged by anything here. ⚠ A10 and A3 both change **what
   a form's captions say**, so the measurement form's appearance is genuinely a pixel matter; a
   green `:99` suite is not the same as somebody looking at it.

**Not tested against `/usr/bin/ngspice` (apt 45.2), deliberately.** Every change here is pure-Tcl
caption and sentence composition; none of it touches what ASE-L emits, reads back or offers, and
the `.state` 104/104 byte-identity is the evidence. Per `CREW_BRIEF`'s own carve-out, I say that
instead of testing twice.

---

## Hygiene

* **Every command carried a `timeout`.** One command (the sabotage campaign) exceeded the
  foreground window and was backgrounded by the harness; **I polled it myself in the foreground
  under a self-announcing deadline** (`FINISHED after 40s (67 lines)`), which reported progress and
  runner liveness on the way out. **I never ended a turn waiting to be woken.** Every run ended in
  a named verdict — `ALLPASS`, a red set, `DIED(...)` or `TIMEOUT`.
* **Processes matched by NAME** (`ps -eo comm=`), never `pgrep -f`, never `pkill`. Alive at
  hand-over and named rather than waved past: **`Xvfb`** (the shared `:99` dev display) and **two
  `xschem`** processes that predate this session. **No `ngspice` process at any point.**
* **Binary always by path** (`./src/xschem`, `devdisplay.sh exec ./src/xschem`), always `--nolog`,
  never `--logdir`, never a bare `xschem`.
* **Snapshots disarmed.** Pristine and finished copies are moved to
  `…/scratchpad/a56/ARCHIVED_DO_NOT_RESTORE/`, and `sab.py`, `plant.py` and `sab.sh` are renamed
  `.disarmed`, so a stale waiter cannot fire a restore over a later tree. **Campaign logs are
  kept** beside them as this receipt's evidence.
* ⚠ **If this crew is woken after collection: `git status` and `git log` before touching
  anything.**
