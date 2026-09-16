# 56b — adversarial verification of ⚖ R9 rulings A9 and A10, and §A3's remainder (receipt 56)

**Role:** adversarial verifier. Brief: disbelieve `56-r9-a9-a10-one-word-per-idea.md`, re-derive its
claims independently, and report what is actually true. **No source file was changed.**

**Tree state.** HEAD `94c4dd72` at start and at end. `git status` carries the identical seven
modified paths and five untracked paths throughout, plus this receipt. No `git checkout --`,
`restore`, `stash`, `clean`, `add`, `commit` or `push` at any point. `LEDGER.md` is the driver's; I
never opened it. `tests/run_regression.tcl` **NOT run** — the driver's, solo (issue 0990).

| file | md5, start **and** end |
|---|---|
| `src/ase.tcl` | `abee1b640e3e92d38b4ea07512c3937a` |
| `src/ase_window.tcl` | `559421793afdbf260de341cc1ba947a3` |
| `tests/headless/test_ase_core.tcl` | `5526ca6a7f690b1041cff9e32eb12e39` |
| `tests/headless/test_ase_dialogs.tcl` | `562aea45d8b4cb43e8593f11e347a65b` |
| `tests/headless/test_ase_meas_1443.tcl` | `b983ab0815b92330ca1686b83269d57b` |
| `tests/headless/test_ase_preflight.tcl` | `db588ffc66fea8e6f130618c8729b8a8` |
| `doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md` | `4be9504a3ab3d935f2fc9c186cb39532` |

`diff baseline.md5 final.md5` → **ALL SEVEN BYTE-IDENTICAL TO BASELINE**.

`~/.xschem/recent_files` **untouched at 2026-09-13 18:53:01.297381420** (issue 0924 canary),
checked at start and at end. `owed.sh count` read-only: **188 rule, 71 look, 11 suite** — I wrote
nothing to the shared cross-clone ledger. **`/usr/bin/ngspice` was never invoked**, no simulation
was started, no deck was written under `sky130A/`, and `ps -eo comm=` showed **no `ngspice`
process** at any point (`Xvfb` ×1 and `xschem` ×2 alive, predating this pass).

---

## ⚠ THE METHOD

Every mutation was built in a **scratch farm**, never in the repo. A farm is a symlink farm of
`src/` with the file under mutation replaced by a real copy; `XSCHEM_SHAREDIR` points the repo's own
binary at the farm (`src/xschem.tcl` sources `$XSCHEM_SHAREDIR/ase.tcl` and `.../ase_window.tcl`).
Two farms instead needed a whole tree (`git archive 94c4dd72 | tar -x`, then a `git init && git add
-A` so `state_roundtrip.tcl` and `CP7` can shell out to `git ls-files` — 104 `.state` paths in
each). Five farms in all, each its own directory so arms could not collide.

**The method was validated before it was trusted**, with positive assertions rather than absence of
FAIL:

| control | verdict |
|---|---|
| unmutated farm, `test_ase_core` / `test_ase_meas_1443` headless | `ALL PASS (673)` / `ALL PASS (115)` — equals the plain in-tree run |
| farmE (working sources + working suites, whole tree), dialogs display | `1 FAILED (387 passed)`, `G2sens` — equals the in-tree display run |
| the red-extractor fed the **empty** log | `DIED(no RESULT line)` — it never answers "clean" |

Every sabotage guard is a **counted diff** against the pristine copy plus an **exact-once needle**
that aborts the arm if it does not occur exactly once. **No md5 was used as a sabotage guard**; md5
appears only to prove the restore.

---

## Claim 1 — "the delay form has no Trigger/Target headings, and **no test can witness it**"
### → the FACT is **CONFIRMED**; the "unassertable" half is **REFUTED**

**The fact, re-derived independently.** I read `ase::ui::meas_show` end to end. It builds exactly
four fixed captions — `lname`, `lkind`, `lanalysis`, and `lon` conditionally — then one `lf<field>`
per field of the kind. Every one is gridded `-column 0` except the inline branch (columns 2/3).
There is **no `labelframe`, no `ttk::separator` and no heading widget anywhere in the proc.** So
two boxes both reading `Ignore before` really would be indistinguishable, and **the qualified
default `Trigger ignore before` / `Target ignore before` is the correct reading of §A10's
condition.**

**But the receipt's conclusion that this is unassertable is wrong, and I proved it by writing the
row.** In farmE I appended one ordinary row, `VP1`, immediately after `MS9` — the same GUI block,
the same harness, the same already-rendered form — which selects a `trigtarg` row and then walks
`winfo children $mw.form`, counting labelframes and separators and collecting each caption's grid
column:

| arm | result |
|---|---|
| **A** — `VP1` against the **shipped** form | `RESULT: 1 FAILED (388 passed)`; `ok: VP1 …`, `G2sens` the only red — the row **passes and the count rises 387 → 388** |
| **B** — a real `labelframe -text Trigger` added to `meas_show` for `trigtarg` (counted diff 5 lines) | `RESULT: 2 FAILED (387 passed)`, reds **`G2sens VP1`** — the row **discriminates** |

So the absence is witnessable by a row costing five lines, in the file that already renders this
form, and arm B shows it reddens for exactly the reason it should. **The receipt's *"no row asserts
it … the source comment is the only thing that will tell them"* is an overstatement**, and the
consequence matters: as shipped, someone adding Trigger/Target headings makes
`Trigger ignore before` the wrong copy and **nothing anywhere goes red.** The crew was honest that
it had not asserted it; it was wrong that it could not be.

⚠ Arm B reddened `G2sens` alongside `VP1`. `G2sens` is the pre-existing red established below, not
collateral — `VP1` is the only row the arm moved.

---

## Claim 2 — the shipped suites are **COMPLETE**, not merely numerically right → **CONFIRMED**

The crew's own **C1** is the reason to distrust a number: its first A9 edit put `#` inside a
`[list …]` command substitution and **truncated `test_ase_preflight` from 242 rows to 232 while
still printing a plausible `RESULT:` line.** A count that lands on the expected value would pass
every check in that receipt. So I checked reach, not arithmetic.

Four independent completeness signals, all on **both arms**:

| suite | count | `ok:` lines == count | **last row in the file** present | terminal banner |
|---|---|---|---|---|
| `test_ase_core` | 673 / 673 | 673 ✓ | `MT10` ✓ (and `LB13`) | `OVERALL: ok` |
| `test_ase_meas_1443` | 115 / 115 | 115 ✓ | `HK2` ✓ | `OVERALL: ok` |
| `test_ase_preflight` | 242 / 242 | 242 ✓ | `PF233f` ✓ | `OVERALL: ok` |
| `test_ase_dialogs` | 37 / 387 | 37 / 387 ✓ | `SP14` ✓ (and `MS9`) | `OVERALL: notok` (G2sens) |

⚠ **A note on the section guards, because they read backwards.** `test_ase_core` declares 7 and
`test_ase_meas_1443` declares 8 rows of the form *"section XX ran to the end"*, and **zero of them
appear in any passing log** — they sit *inside* `if {[catch {…} err]}`, so they emit only on
failure. Their **absence is the signal**; I confirmed they do fire by seeing `PH0` and `DK0` in the
raise arms below. `test_ase_preflight` and `test_ase_dialogs` declare **none at all**, which is why
the last-row-name check is load-bearing for those two rather than decorative.

---

## Claim 3 — `LB11`'s absence half is a **spelling** test → **CONFIRMED**, and it is worse than stated

The crew flagged this itself. I made it concrete. In `ase::ui::meas_tpl_show` I re-derived the
caption **inline in the proc's own body** — the drift shape `LB11` exists to catch — using
`dict get $_fd label` instead of `dict get $f label`, **dropping the unit** (the exact §A3 defect),
while leaving a live `ase::caption_of` call in the body so the presence half stays satisfied:

```
DEMOCHK LB11_needles_hit=0  LB11_presence_ok=1
```

| arm | core | meas | preflight | dialogs nogui | dialogs display |
|---|---|---|---|---|---|
| unnamed-spelling re-derivation, unit dropped | `ALL PASS (673)` | `ALL PASS (115)` | `ALL PASS (242)` | `ALL PASS (37)` | `1 FAILED (387)`, `G2sens` only |

**Nothing in the repository reddens.** A real regression — `Passband gain` where the form should say
`Passband gain (dB)` — is invisible to every suite on both arms. Confirmed exactly as the crew
described, and the crew deserves credit for naming it rather than leaving a green row to imply
cover.

⚠ **My first attempt at this demo was flawed and I am recording it.** I put the re-derivation in a
**helper proc** rather than inline, which removed `ase::caption_of` from `meas_tpl_show`'s body and
reddened `LB11`'s *presence* half (`{1 1 0 1}` vs `{1 1 1 1}`) — the opposite of the point. Redone
inline; the result above is the redo.

**The comment-stripping claim is CONFIRMED, and it is load-bearing.** Sabotage `S1` reddens `LB11`
even though the comment the ruling added to `ase::meas_verdict` contains the literal
`ase::caption_of` three times. An unstripped scan would have passed on the comment alone.
`lb_nocomment`'s `^\s*#` correctly catches the `##` convention used throughout.

---

## Claim 4 — the 14-field divergence → **CONFIRMED**, field for field

Re-measured my own way: walk every field of every kind and every template, compare the **old
per-body rule** (declared label, else the bare slot, no unit) against `ase::caption_of`.

```
KINDFIELDS total=64 divergent=8
  trigtarg/trigtd  Trigger ignore before -> Trigger ignore before (s)
  trigtarg/targtd  Target ignore before  -> Target ignore before (s)
  find/td          Ignore before         -> Ignore before (s)
  when/td          Ignore before         -> Ignore before (s)
  fourier/fund     Fundamental           -> Fundamental (Hz)
  spec/start       Start                 -> Start (Hz)
  spec/stop        Stop                  -> Stop (Hz)
  spec/step        Step                  -> Step (Hz)
TPLFIELDS total=22 divergent=6
  bw3db/gain  Passband gain -> Passband gain (dB)
  sr/lo       Start level   -> Start level (V)
  sr/hi       End level     -> End level (V)
  ts/final    Final value   -> Final value (V)
  ts/tol      Tolerance     -> Tolerance (V)
  thd/fund    Fundamental   -> Fundamental (Hz)
```

**8 + 6 = 14, and the field list is identical to the receipt's**, including the totals 64 and 22 it
did not have to state. In every case the divergence is the dropped unit, and the refusals now carry
it — measured through the shipped procs, not asserted:

```
'm1' needs a value for Fundamental (Hz)                  'm1' needs a value for Value   <- control, no unit, still bare
this template needs a value for Passband gain (dB)
```

---

## Claim 5 — `VD17` / `TP7` are **REAL** cover, unlike `meas_flabel` → **CONFIRMED**

Two instruments, because the blunt one turned out to be uninformative.

**Instrument A — make the proc raise** (the shape 54b used to refute `meas_flabel`). This does
**not** produce a silent green; it produces a death, which is a different and less useful answer:

| arm (counted diff 1 line) | outcome |
|---|---|
| only `ase::meas_verdict` raises | **`DIED(no RESULT line)`**, 43 reds incl. `VD17`, section guards `PH0`/`DK0` fired, section TP never reached |
| only `ase::meas_template_expand` raises | **`DIED(no RESULT line)`**, **0 reds**, TP7 never reached |

So the raise arm proves the suite genuinely *executes* both procs — the decisive contrast with
`meas_flabel`, which 54b made raise on every call while the suite finished `ALL PASS (113)` — but
it cannot settle `TP7`, because the suite dies first.

**Instrument B — the crew's own arms, re-run.** A caption re-derivation, `−1/+1`, exact-once needle:

| arm | core | meas | preflight |
|---|---|---|---|
| **S1** `meas_verdict` re-derives | `2 FAILED` — **`LB10` `LB11`** | `1 FAILED` — **`VD17`** | `ALL PASS (242)` |
| **S2** `meas_template_expand` re-derives | `3 FAILED` — **`LB10` `LB11` `MT5`** | `1 FAILED` — **`TP7`** | `ALL PASS (242)` |

**Both rows red on the precise mutation and on nothing else. The cover is real**, and the declared
blast radii are exactly right, `MT5` included.

---

## Claim 6 — `R9-140` was reported, not claimed; `R9-138` is the user's own sentence → **CONFIRMED**

§A9's ruling block writes out **one** sentence and names **`R9-138`** alone. I byte-compared it
against what ships:

```
ruling block (od -c):  add `distof1` to the input source with a magnitude and a phase in degrees
doc fenced block:      IDENTICAL_ruling_vs_docblock
rendered by ase::needs_eval:
  add `distof1` to the input source with a magnitude and a phase in degrees
```

**Character-for-character, the user's own sentence**, in the doc and out of the shipped proc.

`R9-140` is **not** in §A9's table, and the crew says so three times — in the receipt, in the source
comment beside the change, and in the `R9-140` *Note* itself (*"although §A9's ruling table names
R9-138 alone … The crew reports this rather than claiming the ruling covered it"*). **Reported, not
claimed.** Its sentence is the one piece of wording no ruling wrote; **no `rule` debt was filed**,
which is the driver's call (see below). Rendered:

```
add `distof2` to a source with a magnitude and a phase in degrees, or clear the F2/F1 ratio to measure harmonics instead
```

`LB12` counts **0** literal `<` across both clauses and both remedies, which I reproduced.

---

## Claim 7 — §A10's stale premise: `meas_inline` and its branch are **unreached** → **CONFIRMED**

Three independent checks:

* **One production caller.** `/usr/bin/grep -rn 'meas_inline' src/ tests/` → the definition
  (`ase_window.tcl:8150`), **one** call site (`meas_show:8287`), and two references in
  `test_ase_dialogs`. Nothing else in the tree reaches it.
* **No shipped label can trigger it.** Sweeping every field of every kind:
  `LOWERCASE_KIND_LABELS: ||` — empty.
* **The predicate itself answers no, everywhere.** `MEAS_INLINE_YES: ||` — `ase::ui::meas_inline`
  returns 0 for **every** kind/field pair in the registry.

`meas_show` iterates `ase::meas_kind_fields` only, so the template registry cannot reach the branch
either. **`MS9` is asserting something true**, and it is a strictly stronger claim than the row it
replaced. The branch is dead code kept deliberately; deleting it is the code question §A10 did not
ask.

---

## Independently verified — the rest of the brief

**Suites, both arms** (`nogui` = `./src/xschem --nogui --pipe -q --nolog`; `disp` =
`devdisplay.sh exec` on `:99`, Xvfb, **openbox 3.6.1**, `1920x1080x24`, `status` = alive):

| suite | nogui | display |
|---|---|---|
| `test_ase_core` | **ALL PASS (673)** | **ALL PASS (673)** |
| `test_ase_meas_1443` | **ALL PASS (115)** | **ALL PASS (115)** |
| `test_ase_preflight` | **ALL PASS (242)** | **ALL PASS (242)** |
| `test_ase_dialogs` | **ALL PASS (37)** | **1 FAILED (387 passed)** — `G2sens` only |

**`G2sens` is pre-existing, and I established it on a TRUE-PRISTINE tree** rather than by reading
the assertion: `git archive 94c4dd72` extracted whole — pristine `ase.tcl`, pristine
`ase_window.tcl`, **pristine `test_ase_dialogs.tcl`** (all three confirmed to differ from the
working tree) — display arm:

```
RESULT: 1 FAILED (387 passed)
FAIL: G2sens … -> {1 1 0 1 0 Entry Entry normal} (exp {1 1 0 0 0 Entry Entry normal})
```

**The identical actual value.** Issue **1436**, not this crew's. T1 runs this file on neither arm.

**Floors.** `test_ase_core` **669 → 673** and `test_ase_meas_1443` **113 → 115** added in each
file's own paragraph. `test_ase_preflight` (238 → 242) and `test_ase_dialogs` (386 → 387) unchanged.
**No floor was lowered** — every `AND RAISED` line in all four files is an addition in the diff, none
removed.

**104/104 `.state` byte-identical**, driven as a **proc**, measured twice (start and end):
`tracked 104  bad {}  control_disagrees 1  control_agrees 1`. **Both controls live.**

**No handle minted, header unmoved.** Against `git show 94c4dd72:…R9_COPY_REVIEW.md`:
header line 14 says **730** then and now; `grep -c '^\*\*R9-'` = **727** then and now; distinct
anchored handles = **726** then and now. Every change is a reworded existing handle. **I minted
nothing and ruled on no copy.**

**Sabotage — four arms redone independently**, counted diff + exact-once needle, **never an md5
guard**, restore proved by `cmp`:

| | arm | counted diff | measured reds | verdict |
|---|---|---|---|---|
| S1 | `meas_verdict` re-derives | −1/+1 | core `LB10` `LB11` · meas `VD17` · preflight clean | **exactly as declared** |
| S2 | `meas_template_expand` re-derives | −1/+1 | core `LB10` `LB11` `MT5` · meas `TP7` · preflight clean | **exactly as declared** |
| S3 | `meas_tpl_show` grows its copy back | −1/+1 | core `LB11` **alone**; meas/preflight clean; **dialogs display UNMOVED** (`G2sens` only) | **exactly as declared** |
| S5 | only the `distof2` sibling reverts | −2/+2 | core `LB12` **alone**; **preflight ALL PASS (242)** | **exactly as declared** |

**No arm reddened a row it was not aiming at.** S3 independently reproduces this batch's most-met
finding: `test_ase_dialogs` **cannot** witness a `meas_tpl_show` caption change on either arm, so
`LB11` really is the only cover anywhere for that third body. S5 confirms the `distof2` sibling has
no guard but `LB12`.

⚠ **One receipt inaccuracy, immaterial:** the table lists S5's diff as **−1/+1**; the remedy is a
two-line continuation and reverting it is **−2/+2**. The red is unaffected.

**The three remaining literal angle-bracket sites — CONFIRMED, and the sweep is complete.** A
case-insensitive sweep of both sources, discarding Tk event bindings, finds exactly:

| site | status |
|---|---|
| `ase.tcl` `sens_filters` — `` `<letter>.<instance path>.<name>` `` | user-facing, literal, still there |
| `ase.tcl` `preflight_gate` — `` `ase::preflight_fix_session <key>` `` | user-facing, literal, still there |
| `ase.tcl` the `xtrtol` remedy — `` `set xtrtol=<n>` `` | user-facing, literal, still there |
| `ase.tcl` Verilator `patch` — `std::unique_ptr<VerilatedContext>` | C++ the user pastes, **out of class** — agreed |
| `ase_window.tcl:3886` `{<NULL>}` | an internal sentinel compared against, not copy — out of class |

**`no_spinit`'s caveat is UNREACHABLE — CONFIRMED by measurement.**
`ase::opt_offer ngspice no_spinit` → **`elsewhere`**, and `ase::ui::optsheet_detail`'s `switch` has
a **separate `elsewhere` arm**, so the `caveat` arm cannot fire for it. Of 247 catalogued options,
**three carry a `caveat` key** (`no_spinit`, `scale`, `wnflag`) and **three reach the `caveat` arm**
(`defas`, `scale`, `wnflag`) — **none of the three that reach it carries an angle bracket.**
⚠ The receipt says *"the two options that do reach that arm (scale, wnflag)"*; it is **three**,
`defas` included. The conclusion is unchanged and slightly strengthened.

**The four suites the receipt rests on "a name diff alone" — I ran them anyway**, and all are green,
so nothing here caused collateral damage: `test_ase_window` **56**, `test_ase_simreg_0931` **118**,
`test_ase_optsheet_1441` **64 / 89**, `test_ase_trnoise_1466` **80**, `test_ase_trnoise_gui_1467`
**63** (display). I claim none of them as cover either.

---

## ⚠ Found — the one place the receipt overstates its own tree

**`test_ase_preflight` does NOT carry a paragraph explaining why its floor did not move.** The
receipt says *"Preflight and dialogs are unmoved by design … and **both files now carry a paragraph
saying so**."* Measured:

* `test_ase_dialogs` **does** — the header floor block gained a full
  `#   37 / 387   UNMOVED on both arms for ⚖ R9 ruling A10 (2026-09-16): MS9 MOVED rather than
  being added …` paragraph, sixteen lines, in the same block as every other floor entry.
* `test_ase_preflight` **does not**. Its header floor block ends at `AND RAISED 238 -> 242` with no
  A9 entry at all; the only A9 note in the file is an inline comment **at the `PF234c` row itself**,
  ~2350 lines further down. A reader auditing the floor block — which is where every other
  *"moved rather than added"* note in this batch lives, `PF222b`/`PF222e`/`PF228b`/`PF234b`
  included — learns nothing about A9.

Not a defect in the code and not a red; a documentation gap in the exact place the batch has agreed
to record such things.

---

## Verdict summary

| # | claim | verdict |
|---|---|---|
| 1a | the delay form has no Trigger/Target headings | **CONFIRMED** |
| 1b | no test can witness that absence | **REFUTED** — `VP1` passes at 388 and reds on a real heading |
| 2 | preflight 242 / core 673 / meas 115 are **complete**, not truncated | **CONFIRMED** on both arms |
| 3a | `LB11`'s absence half is spelling-only | **CONFIRMED** — an unnamed spelling reds nothing anywhere |
| 3b | `LB11` strips comments before scanning | **CONFIRMED** — S1 reds despite the literal in the comment |
| 4 | 14 divergent fields (8 kind + 6 template), refusals carry the unit | **CONFIRMED** field for field |
| 5 | `VD17` / `TP7` are real cover | **CONFIRMED** via S1/S2; raise arms kill the suite rather than greening |
| 6 | `R9-140` reported not claimed; `R9-138` char-for-char the user's | **CONFIRMED** |
| 7 | `meas_inline` and its branch are unreached; `MS9` is true | **CONFIRMED** |
| — | suites both arms, `G2sens` sole red, pre-existing on a true-pristine tree | **CONFIRMED** |
| — | floors raised in-file, none lowered | **CONFIRMED** |
| — | 104/104 `.state`, both controls live, driven as a proc | **CONFIRMED** |
| — | no handle minted; 730 / 727 / 726 unmoved | **CONFIRMED** |
| — | S1, S2, S3, S5 reproduced; blast radii exact | **CONFIRMED** |
| — | three literal `<…>` sites remain; `no_spinit` unreachable | **CONFIRMED** (`defas` is a third reacher, not two) |
| — | "both files carry a paragraph" about the unmoved floors | **PARTLY** — `test_ase_preflight` does not |

## For the driver to decide before committing

1. **The three remaining literal angle-bracket sites.** A9's invariant holds on the distortion
   preconditions and **not tree-wide**. §A9 said *report*, and the crew reported. Whether they are a
   different class (syntax templates in backticks) is the **user's** ruling.
2. **`R9-140`'s sentence has no ruling behind it and no `rule` debt filed.** The crew composed it
   and flagged it upward. Either it rides ⚖ R9 as the crew assumed, or it wants
   `owed.sh add rule` — one command, and the ledger is cross-clone (issue 1400).
3. **Whether to pin the headings absence with a row.** It is assertable in five lines
   (`VP1` above, demonstrated working and discriminating). Without it, adding Trigger/Target
   headings silently makes `Trigger ignore before` the wrong copy.
4. **Whether `ase::ui::meas_inline` and its branch should be deleted** now that they are provably
   unreached. The crew kept them deliberately; §A10 did not ask.
5. **`test_ase_preflight`'s missing floor paragraph** — a one-paragraph fix, and the receipt claims
   it is already there.
