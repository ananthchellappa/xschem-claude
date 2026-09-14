# 1454 — a ports table with no widget, and the one editor that saw it destroyed it

**Status:** fixed (Stage 9's GUI half — §9a's Ports table and §9b's S-parameter surface;
the deck half is issue **1452**, commit `f438af90`)
**Branch:** `fluid-editing`
**Area:** ASE-L — the `setup` contract's widget surface, the result matrix, the
`Options…` subdialog (`src/ase.tcl`, `src/ase_window.tcl`)
**Suites:** `tests/headless/test_ase_sp_1452.tcl` section **SX** + the rewritten **SM5**
(41 → 50, both arms); `tests/headless/test_ase_dialogs.tcl` section **SP** (37 / 362 →
37 / 382, display arm)
**Batch:** `doc/claude/ase_analyses_batch/`, **PLAN.md Stage 9 §9a/§9b**, ruling ⚖ **R9**
**Decisions:** D4, D34–D37, and issue **1450**'s one-list rule, which this is the third
violation of

---

## The defect, in two halves

### 1. A table nobody could type into

Issue 1452 made a `setup` table **emit** — `alter <src> portnum = N` / `alter <src>
z0 = R`, immediately above the `sp` card — and built **no widget**. `ports` was a row key
with no surface anywhere in ASE-L, so the only way to put a two-port table on a bench was
to hand-edit a `.state` file. Every one of the four committed S-parameter benches under
`ihp-sg13g2/xschem_libs/sg13g2_tests_ase/` was still unreachable from the GUI for exactly
the reason 1452 was filed.

### 2. And the one editor that *did* see the key refused the row and would have destroyed it

Measured **2026-09-13** through the real widgets, on an `sp` row carrying a two-port table:

```
$top.chana.opts invoke
  Options editor lists: {ports {{src v1 num 1 z0 50} {src v2 num 2 z0 50}}}
$top.chana.x.btns.proceed invoke
  subdialog still up = 1
  bytes changed      = 0
```

The **whole table listed as one free-text NAME/VALUE pair**, and OK refusing it as *"a
setting ASE-L cannot emit"* — subdialog left standing, nothing written, the editor
unusable on that row.

**That is issue 1450's defect for the third time.** 1450 collapsed three copies of *"keys
on an analysis row that are not settings"* onto `ase::analysis_nonsetting_keys`, and
`ports` is deliberately **not** in that list: it is licensed on ONE type, because ONE
registry entry declares that that type carries a table (1452's own reasoning, row SK1). So
the two `Options…` sites asked the one question they knew and missed the one that names a
per-type key.

⚠ **And the writer's half is the sharper one.** `ase::ui::chana_x_ok`'s strip deletes every
key not in `skip` before writing the row back, so a `skip` that had never heard of the
table key would have **destroyed the ports table** on any commit that got past the
refusal — the same sentence 1450 wrote about `id` and `x`. Row **SP12** is that as a
byte-identity claim, with a genuine stray key as its control.

## What shipped

| | |
|---|---|
| **§9a — the Ports table** | `ase::ui::setup_dialog` and eleven companions: the row's own table in a treeview, an Add/edit/Delete entry row, the live refusal, `Add from Schematic…`, and OK as a commit door |
| **§9b — the matrix picker** | `ase::ui::matrix_dialog` and six companions: one cell per vector the run will answer, laid out as the matrix it is, four formats, and OK writing ordinary Outputs rows |
| **The contract grew two keys** | `columns` (required — a table that emits must also be typable) and `scan` (optional) |
| **The entry grew one** | `matrix`, the hook that answers the result grid for a row |
| **The plots row grew one** | `vectors ::ase::backend::ngspice::sp_vectors`, which row SM5 of the deck half had been holding the door open for |
| **One reader that must fold** | `ase::raw_vectors_present` / `ase::raw_vectors_fold` |
| **The 1450 fix, third site** | both `Options…` sites now also ask `ase::analysis_setup_key` |

**Everything the two dialogs say comes from the registry.** `Source`, `Port` and
`Z0 (ohm)` are the **adapter's** declared column labels; the button, the title and the
caption are composed from its declared `noun`; the minimum is its declared `min`. Row
**SP3** asserts that `src/ase_window.tcl` spells none of them, by searching the proc body.

## ⚠ The result matrix is a transcript, and `evidence/sp-stage9.md` is one family short

Measured **2026-09-13** on apt 45.2 **and** on the fork, one deck per shape, `display`
inside the `.control` block and the written rawfile beside it:

```
2 ports, no noise flag   S_1_1 S_1_2 S_2_1 S_2_2   Y_… (4)   Z_… (4)           = 12
3 ports, no noise flag   S_… (9)                   Y_… (9)   Z_… (9)           = 27
2 ports, noise flag on   + Cy_1_1 Cy_1_2 Cy_2_1 Cy_2_2  NF NFmin Rn SOpt       = 20
```

`evidence/sp-stage9.md` names **four** noise vectors (`NF NFmin Rn SOpt`). The **noise
correlation matrix `Cy_i_j`** is a fifth thing and an N×N grid of its own. A picker that
silently omitted a family the run produces would be this stage's own defect class, so it
is offered.

⚠ **`Cy` is the one family whose plot expression is not its name.** It is typed `current`,
so ngspice's own writer emits it as `i(Cy_1_1)` — and `wviewer::validate_rpn` answers
`unknown token 'Cy_1_1'` for the bare name against **either** binary's variable list while
accepting `i(Cy_1_1)` against both. That is why a matrix entry carries `vector` *and*
`expr`; for every other family the two are equal.

⚠ **And the noise families appear only when the row asks for them AND the table holds
exactly two ports.** `span.c:74-178` computes them for N == 2, which `sp_row_check`
already cautions about; offering them on a three-port row would put cells in the picker no
run can ever fill. Measured: a three-port row with `donoise 1` answers 27, not 36.

## ⚠ The reader folds, and that is the job SM5 was holding open

Measured **2026-09-13**, the same ASE-L-rendered `sp` deck written by both binaries:

```
the fork    frequency S_1_1 S_1_2 … Y_1_1 … Z_1_1 … NF NFmin Rn SOpt  i(Cy_1_1) …
apt 45.2    frequency s_1_1 s_1_2 … y_1_1 … z_1_1 … nf nfmin rn sopt  i(cy_1_1) …
```

`display` shows the **capitals on both**; it is the written file that differs. Row **SM5**
of `test_ase_sp_1452.tcl` asserted the *absence* of any reader of those names precisely so
that whoever added one would have to choose deliberately between folding and reddening a
suite. It is **rewritten, not deleted**: it now asserts that the reader folds, answers in
the **declared** spelling, and strips ngspice's own `v(…)`/`i(…)` wrapper — with a name
that is in neither file as its control.

## ⚠ The Smith chart in PLAN.md §9b does not exist and cannot be drawn here

Measured: `grep -ri smith src/*.c src/*.tcl` prints **nothing**, and `polar` matches only
the word `bipolar`. The waveform viewer has one rectangular axis pair and no mode that
would draw either a Smith chart or a polar plot. §9b's *"Matrix picker, Smith/polar"* and
its *"What you see: … a Smith chart"* are therefore **half shipped**: the matrix picker is
here, and the Smith chart is a new plot engine in `wave_viewer.tcl`/`draw.c`, which is a
different stage.

What the viewer **can** draw of a complex answer is offered instead, and every format on
the menu was measured accepted:

| format | RPN | measured |
|---|---|---|
| `Magnitude (dB)` | `db20()` | `validate_rpn` → `{}` on both binaries' variable lists |
| `Phase (deg)` | `cph()` | same |
| `Real` | `re()` | same |
| `Imaginary` | `im()` | same |

with `S_9_9` and `nosuchfn()` rejected as the controls. `abs()` on a complex vector was
**not** measured and is therefore **not** on the menu.

## ⚠ `Add from Schematic…` offers every top-level V source, and PLAN.md §9a says otherwise

§9a's own ⚠ says *"the netlist scan only **adds** sources that already declare one
[`portnum`]"*. Measured against the stage's own headline case, that offers **nothing**: the
whole of Stage 9 is *"S-parameters with no schematic edit"*, and its bench is two
**ordinary** V sources promoted at run time.

So the scan offers every top-level independent **voltage** source, and what the declaration
buys is the **prefill**: a source that says `portnum 2 z0 75` comes back with 2 and 75
already in it; one that says nothing gets the next free number and a **blank** Z0, because
the 50 Ω default is the simulator's and ASE-L does not invent a number the user never
typed (issue 1452's row SL2).

Three things it does **not** offer, each measured through `ase::netlist_facts`:

* a **current** source — `vsrc.c:31-37` puts `portnum` on the voltage source and there is
  no `isrc` equivalent;
* a source **inside a subcircuit** — `alter <name>` addresses an instance by its own name,
  and the scan already records a `scope` per source;
* an entry **already in the table**.

⚠ **And it peeks and never netlists.** `ase::netlist_facts_cached` answers `{}` for a bench
nobody has netlisted, and a dialog may not produce a netlist because a user opened it
(issue 1435's constraint; this window is under that dialog). A cold bench gets the
precondition banner's own cold sentence, naming `Simulation > Netlist > Recreate`, and an
empty list — which is an honest nothing rather than a wrong list. Row **SP6**.

## ⚠ OK is a commit door, and that is what makes a one-port table hard to arrive at

`span.c:376-386` calls `controlled_exit(EXIT_BAD)` below two ports: the process dies and
takes every other analysis of the run with it, `op` included. So the ports dialog's OK
**refuses** any table `ase::needs_eval` would refuse, keeps the sentence on screen and
keeps the dialog up — `chana_ok`'s own shape.

**An empty table goes through.** It is the untouched state, not a wrong answer, and the
run-time `two_ports` fatal still refuses it — and still refuses a hand-edited `.state`,
which is the case no dialog can reach.

⚠ **The evaluator is `ase::needs_eval`'s own two arms and not a second opinion.**
`ase::analysis_setup_lines` dispatches `two_ports` and `setup_check` with empty facts —
safe only for those two ids, because both read the row and the registry and nothing else.
A dialog that judged the table its own way could pass a table `render_deck` then refuses,
which is the *"nothing the window shows may fail to reach the deck"* rule this stage is
easiest to break.

## The corpus

```
TRACKED=104  NOT-BYTE-IDENTICAL={}  sp-rows=0  ports-keys=0
SEED={type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}
CONTROL-DISAGREES=1   TABLE-ROUNDTRIP=1
git status --short ihp-sg13g2/   ->  (empty)
```

104 tracked `.state` files, zero that stop round-tripping byte-identically, zero rows of
type `sp`, zero carrying a `ports` key, `ase::state_default` still seeding exactly four
rows — and the four committed S-parameter benches untouched. Row **SP13** is the same
question from the GUI side, with a changed table as its control.

## The corrections this item makes to the plan

| | |
|---|---|
| **C1** | **§9b's Smith chart cannot be drawn in this tree** — measured, there is no Smith or polar code anywhere. The matrix picker ships; the chart is outstanding |
| **C2** | **§9a's scan rule is refuted by the stage's own headline case** — "only sources that already declare a `portnum`" offers nothing on a bench of two ordinary V sources |
| **C3** | **`evidence/sp-stage9.md` is one family short** — the `Cy_i_j` noise correlation matrix, four more vectors, wrapped `i(…)` in the rawfile |
| **C4** | **§9b's `.csparam Rbase=50` workaround** was already corrected by 1452 (`let`/`unlet`); this item does not revisit it |
| **C5** | **`test_ase_dialogs` GN1b's title was stale since 1452** (receipt 32's C8) and is corrected here — and rewritten to ask **renderability** rather than the cell's state word, which depends on whether the capability cache is warm |

## ⚠ Four defects this item found in the SUITE rather than in the product

Each is the same shape and it was met **three times inside section SP alone**: a
read that raises kills a GUI suite **at rc 0** instead of reddening a row, and
the file's top-level catch turns fourteen to twenty checks into silence.

| sabotage | what raised | checks lost | the fix |
|---|---|---|---|
| **s11** (OK stops refusing) | `$sw.row.src insert` on a dialog that closed | 14 | SP5b re-opens the dialog if SP5's OK let it close |
| **s24** (the Matrix door never gridded) | `dict get [grid info …] -row` | 20 | every grid read goes through `ase_grid_row`, which the file already had |
| **s27** (a fixed column list) | `$tv set $it z0` / `$tv heading z0` / `$sw.row.z0` | 19 | `sp_tbl` catches every cell (`NOCOL`), plus new `sp_head` and `sp_type` |
| **s25** (a normalising write-back) | nothing — it **survived** | — | SP13's fixture now carries an entry whose key order differs from the columns' |

The general rule it earns: in a GUI suite, **every read of a widget a sabotage
could remove needs a total reader, not a comment.**

## What is still owed

* **A Smith chart and a polar axis** in the waveform viewer (C1). Nothing in this item
  pretends to ship one.
* **A `look` debt** — `owed.sh add look ase_sp_ports_matrix_1454`. A new table, a new
  picker and a new scan window are pixels, and a green suite is not a pair of eyes.
* **⚖ R9** — `owed.sh add rule 1454`. The new sentences are listed verbatim in
  `doc/claude/ase_analyses_batch/receipts/33-stage-9-sp-surface.md`.
* ⚠ **Issue 1453, and this item answers its open question.** Receipt 32 asked
  *"which display-arm suite runs a live probe"*.
  `tests/headless/test_ase_dialogs.tcl:2715` (section G13, long pre-dating this
  item) calls `ase::ui::sod_case_mode`, which is a live `ase::sim_capabilities`
  probe; on the display arm the run reaches the Tk event loop and each
  `probe_a.sp` load records in `~/.xschem/recent_files`. Measured after this
  item's runs: ten entries, **four pids, three decks each** — so **four display
  runs of that one suite flush the list completely**. Nothing was repaired here
  (the standing rule), and nothing of the user's was lost (the ten entries it
  displaced were already probe decks). It makes 1453's option A urgent for a
  reason it was not filed for: it is the *suite* doing this, several times an
  hour.
* **A per-port `pwr`/`freq`/`phase` surface** is still not offered, for issue 1452's
  measured reason: `VSRCportPhaseRad` is written and read nowhere.
