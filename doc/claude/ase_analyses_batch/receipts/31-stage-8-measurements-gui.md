# Stage 8 task 2 — the Measurements sub-dialog, the eight templates, the Value column (§8b)

**One task, issue 1451, and the SECOND of Stage 8's two tasks.** Scope was
`PLAN.md` **§8b** and nothing else. `src/ase.tcl` + `src/ase_window.tcl` +
`tests/headless/test_ase_core.tcl` + `tests/headless/test_ase_dialogs.tcl` +
`tests/headless/test_ase_meas_1443.tcl` + the 1451 issue file + the 1444 append
+ `NUMBERING.md` + this receipt. **`tests/run_regression.tcl` was NOT opened** —
no new suite file was created and both suites that moved are already in T1's
case list. No commit, no `git add`, no stash, no restore, no clean, no push. T1
not run (issue 0990 — the driver's, solo). **No simulation was started on any
bench under `sky130A/`**; every simulator run below is a hand-written deck in
`/tmp/m1451` against an explicit path.

**Floors:** `test_ase_core` **626 → 636**, `test_ase_meas_1443` **100 → 113**,
`test_ase_dialogs` **37 / 346 → 37 / 363**. Each file's own floor paragraph and
header index is in the same diff.

`src/ase.tcl` **+468/−8**, `src/ase_window.tcl` **+875/−0**,
`test_ase_core.tcl` **+221**, `test_ase_dialogs.tcl` **+632**,
`test_ase_meas_1443.tcl` **+307/−5**.

---

## ⚠ THE HEADLINE: §8b's GAIN-MARGIN LINE ANSWERS NOTHING, ON EITHER BINARY

`PLAN.md` §8b's table writes the gain margin as
`meas ac gm find vdb(out) when vp(out)=-180`. **Measured 2026-09-13 on BOTH
binaries**, on a three-pole amplifier whose phase really does pass through −180
(60 dB, UGF 915 kHz, two poles at 3 MHz, built for this in `/tmp/m1451/tb2.cir`):

```
meas ac gm FIND vdb(out) WHEN vp(out)=-180
    -> Error: measure  gm  find(AT) : out of interval        both binaries, rc 0
meas ac gm FIND vdb(out) WHEN cph(v(out))=-180
    -> Error: no such vector as cph(v(out)).                 both binaries
let gmph = cph(v(out))
meas ac gm FIND vdb(out) WHEN gmph=-180
    -> gm = -1.556922e+01   at f = 3.001137e+06              both binaries
```

**Two facts, and the first is the sharper one.** `vp()` is **WRAPPED** — measured
on the same sweep, the point whose continuous phase reads `-2.36596e+02` has
`vp(out)` reading `+1.234040e+02`, so −180 is exactly the discontinuity and no
crossing detector can ever see it. And `meas`'s `WHEN` operand must be a vector
**NAME**, not an expression, so the unwrapped phase has to exist as a named
vector first. That is the 19th kind, `cphase`.

**The hand calculation agrees with the measurement**: −15.6 dB at 3 MHz for that
pole set, against `-1.556922e+01` at `3.001137e+06`. The plan's line is not
merely unlucky on one circuit; it cannot fire on any.

---

## ⚠ AND THE 57.2958× TRAP, THIS TIME ON THE FINAL NUMBER

Issue 1443 measured the radians trap through one `meas` line. This task measured
it **through the whole rendered block** — the block `ase::backend::ngspice::meas_block`
emits for the Phase margin template, pasted into a deck and run twice on each
binary, once with `set units=degrees` and once with that single line deleted:

```
with    `set units=degrees`   pm2 = 5.614170e+01     <- 56.1 degrees
without it                    pm2 = 1.778383e+02     <- 177.8, rc 0, nothing said
                                                        and `gm` vanishes too
```

Both binaries, byte-identical `pm2` lines because `print` is binary-independent.
**A 56-degree phase margin reported as 178**, at exit code 0, with the
gain-margin row silently failing beside it (2 `failed!` lines instead of 1).

`test_ase_meas_1443` row **TP3b** is that as a check, and it is deliberately a
row about the **NUMBER** rather than about the deck line: it renders the block,
decides *from the block* which of the two measured runs it would have been, and
asserts `5.614170e+01`. Sabotages **s2** and **s3** (the two ways to lose the
units line) redden it on a number.

---

## ⚠ WHAT I VERIFIED VERSUS WHAT I TRANSCRIBED

| claim | evidence |
|---|---|
| `vp()` is wrapped, so `WHEN vp(out)=-180` cannot fire | **MEASURED on both binaries**, with the continuous phase printed beside it at the same index as the control |
| `meas`'s WHEN operand cannot be an expression | **MEASURED on both binaries**: `no such vector as cph(v(out)).` |
| `let <name> = cph(v(out))` then `WHEN <name>=-180` works | **MEASURED on both binaries**: `gm = -1.556922e+01` / `-1.55692e+01` at `f = 3.001137e+06` |
| all eight templates produce numbers | **MEASURED on both binaries**, from lines **rendered by `meas_block` itself** and pasted into a deck (`/tmp/m1451/probe3.tcl` → `/tmp/m1451/tb2.cir`) |
| `CROSS=last` is accepted | **MEASURED on both binaries**: `tslo = 2.101708e-03` / `2.10171e-03` |
| the phase margin is 56.14° with the units line and 177.84 without | **MEASURED on both binaries**, the same deck twice |
| the `meas` echo line is binary-dependent and `print` is not | **RE-MEASURED here on both binaries** over the whole eight-template run: six decimals on apt 45.2, five on the fork, and `pm2 = 5.614170e+01` identical on both |
| a failed measurement is silent on every channel the guard can see | **OBSERVED here**: `tshi` failed on both binaries, rc 0, no line in the sidecar, only a stderr sentence |
| the two binaries can disagree about a computed number | **MEASURED, and it is new**: `sr` came back `4.230294e+03` on apt 45.2 and `4.230282e+03` on the fork — a real numeric difference, not a print width. Confirms task 1's rule that no golden may carry a simulator-produced number |
| all 104 committed `.state` files round-trip byte-identically | **COUNTED LIVE**, 104 of 104, with the non-vacuity control |
| `meas sp` segfaults for WHEN/TRIG/RMS/INTEG | **TRANSCRIBED** from issue 1443, deliberately not reproduced — the brief forbids a probe that crashes the user's simulator |

---

## What shipped — the SCHEMA half (`src/ase.tcl`, `ase::`)

| anchor | what |
|---|---|
| `ase::meas_templates` / `_entry` / `_label` / `_analysis` / `_fields` / `_field` | the adapter's template catalogue and its readers, `{}` for a backend with no hook |
| `ase::meas_names_taken` | every measurement name already spoken for, folded |
| `ase::meas_template_expand` | `{ok <rows>}` / `{refuse <why>}` — required fields, the adapter's `meas_template_derive`, the **batch suffix**, and the binding |
| `ase::meas_subst` | `@field@` and `@n@`, and an unanswered `@name@` is **left alone** rather than emptied |
| `ase::meas_template_errors` | `ase::meas_schema_errors`' sibling, Stage 15's second conformance question |
| `ase::meas_kind_label` / `ase::meas_kind_order` | the Kind picker's two readers — **nothing read a kind's `label` before this** |
| `ase::meas_analysis_choices` | which analysis rows may carry a measurement, enabled or not |
| `ase::analysis_handle_line` | one row's one-liner; `ase::analysis_handle_text` became its **caller** |

**No new state key, no schema bump, nothing added to `ase::omit_if_empty`.**
`measurements` and the per-row `id` already existed.

### ⚠ `@n@`, the batch suffix, is the load-bearing part

A template writes rows **that refer to each other** — a phase margin is three
rows deep and ends in `let pm = 180 + pmph` — so uniquifying one name at a time
would rename `pmph` and leave `pm` reading a vector that no longer exists. ONE
suffix is chosen for the whole batch, tried empty first and then `2`, `3`, …, and
the template spells it into both the names it mints and the references it makes.

Measured live: with a phase margin already on the bench, a second one expands to
`ugf2` / `pmph2` / `pm2` with `let pm2 = 180 + pmph2`. `MT4` is the row and
sabotages **s8** (per-row suffix) and **s10** (no suffix at all) redden it.

## What shipped — the CONTENT half (`ase::backend::ngspice`)

`meas_templates` (the eight), `meas_template_derive` (the arithmetic), the 19th
kind `cphase`, `meas_line`'s `cphase` arm, and one clause in
`meas_needs_degrees`. Two registered hooks added: `meas_templates`,
`meas_template_derive`.

### The 19th kind, and the two shipped rules it moved

`cphase` — **Unwrapped phase** — is a `meas`-form `letform` kind that
**`yields vector`**. It is not a user-facing measurement; it exists so a gain
margin has a vector name to ask about. Two of issue 1443's own rules moved with
it, both narrowly, both measured, both with a row:

* **`meas_group` prints a `let`-form row only when its kind yields a NUMBER.** A
  `print gmph` would put one line per frequency point of the sweep into the
  sidecar. `ase::meas_kind_yields` is the question a producer already answers for
  exactly this reason, and `ase::meas_results` reports such a row as `produced`
  rather than as a failure. **TP2** (no print) and **TP2c** (a `param` row
  still IS printed) are the pair; sabotage **s9** reddens TP2.
* **`ase::meas_schema_errors` permits `yields` on a `letform` kind.** The
  sentence moved with it; **KN4b** carries both halves — the refusal on a plain
  `meas` kind and an `okyld` entry that must NOT be reported.

⚠ **And `meas_needs_degrees` gained a KIND clause.** A `cphase` row reads a phase
**without spelling one** — there is no `vp(` anywhere in it — and `cph()` is
evaluated under whatever `units` is in force at that moment. Without the clause
the gain margin below it would look for −180 in a vector whose values run to
−4.7. Sabotage **s2** is exactly that clause deleted.

## What shipped — the GUI (`src/ase_window.tcl`)

`Outputs > Measurements…` → `ase::ui::measurements_dialog`, and **forty-six**
other procs in the `ase::ui::meas_*` / `ase::ui::lbl_meas*` families (twelve of
them the `lbl_*` constants). The commit model is the `Options…` subdialog's, not
Choose Analyses': a **working copy of the whole list** in `dlg($key,mrows)`, and
**OK writes it back in one `ase::session_update`**. Choose Analyses' per-row
cache exists because that dialog edits ONE row of a list it never otherwise
touches — `GR6e` holds that line and **nothing here widens it** (it is green
throughout, and no sabotage touched `chana_ok`).

What it *does* inherit from ⚖ R5 is the **remembering, through one door**:
`ase::ui::meas_harvest` reads the live form into the working copy and every
rebuild goes through it first. **MS6** is that row, with the other row's value as
its control; sabotage **s12** reddens it.

---

## ⚠ THE LAYOUT CONSTRAINT, MEASURED RATHER THAN EYEBALLED

`R9-325` is the word `reaches` — the only **lowercase** field label in the tree,
the second half of the sentence `When signal <v(out)> reaches <0.9>` — and it
reads correctly only if the form puts both on **one line**.

The rule shipped is keyed on **the copy's own shape**: a field whose label begins
with a lowercase letter is rendered as an inline continuation of the row above
it, in grid columns 2 and 3. It needs no per-simulator knowledge and no new
descriptor key, because an adapter writes a lowercase label precisely when the
label continues the previous one.

Measured on the real widgets on `:99`:

```
lfwhen   row=5 col=0      fwhen   row=5 col=1
lfvalue  row=5 col=2      fvalue  row=5 col=3     <- `reaches`, same row
lftarget row=4 col=0                              <- an ordinary label, its own row
```

**MS9** is that, with the ordinary label as its control, plus the predicate
asked directly both ways. Sabotage **s11** (no inline continuation) and **s5**
of the copy side (`reaches` given an uppercase label, control **c5**) both
redden it.

---

## §8b's EIGHT TEMPLATES — WHICH EMIT WHAT THE PLAN SAYS, AND WHICH NEEDED CORRECTING

Every line below was rendered by `ase::backend::ngspice::meas_block` and then
**run on both binaries**. The "answered" column is the value the real run put in
the sidecar on apt 45.2.

| template | the plan | shipped | answered |
|---|---|---|---|
| **DC gain** | `meas ac gain max vdb(out)` | ✅ as written | `6.000000e+01` |
| **−3 dB bandwidth** | `meas ac f3db when vdb(out)=<gain-3.0103> fall=1` | ✅ as written, with the gain as a **third field** | `9.999994e+02` |
| **Unity-gain frequency** | `meas ac ugf when vdb(out)=0 fall=1` | ✅ as written | `9.149274e+05` |
| **Phase margin** | `set units=degrees` + `ugf` + `meas ac pm find vp(out) when vdb(out)=0` + `let pm = 180 + pm` | ⚠ **corrected** — the measured phase is `pmph@n@`, the margin `pm@n@` | `5.614170e+01` |
| **Gain margin** | `meas ac gm find vdb(out) when vp(out)=-180` | ⚠ **corrected** — `let gmph = cph(v(out))` first, then `WHEN gmph=-180` | `-1.556922e+01` |
| **Slew rate** | `meas tran sr trig … targ …` | ⚠ **corrected** — that emits **seconds**; the delay is `srt@n@` and `sr@n@` is a `param` row | `srt 3.309463e-04`, `sr 4.230294e+03` |
| **Settling time** | `meas tran ts when v(out)=<final±tol> cross=last` | ⚠ **corrected** — two rows, one per band edge | `tslo 2.101708e-03`, `tshi` **failed** |
| **THD** | `.four <f0> v(out)` **card** + `thd1` | ⚠ **corrected** — `fourier` **command** (issue 1443's C148: a card runs the simulation twice) | `8.083593e+01` |

**Four corrections, each measured or forced:**

1. **Phase margin cannot name two rows `pm`.** ngspice tolerates
   `let pm = 180 + pm`; ASE-L refuses a duplicate name outright, deliberately —
   the sidecar's lookup is case-insensitive because the simulator folds what it
   prints, so the second answer would silently overwrite the first. Row `VD17` of
   issue 1443 is that rule and this is the first thing to meet it.
2. **The gain margin's line answers nothing** — §the headline above.
3. **"Slew rate" as written emits a DELAY.** Reporting a time under the name `sr`
   is the silent-wrong-answer class this batch exists to delete, so the template
   writes `srt@n@` (the delay) and a `param` row `sr@n@ = (hi - lo)/srt@n@`
   beside it. Both are ordinary rows; either can be deleted.
4. **"fills two fields" is three or four for half of them.** `-3 dB bandwidth`
   needs the passband gain (the `when` operand must be a literal — `expr=` and
   `par()` do not exist on the command form, issue 1443's C147), `THD` the
   fundamental, `Settling time` the final value and the tolerance, `Slew rate`
   the two levels. Named rather than trimmed, because the extra field is the one
   that decides the answer.

⚠ **AND ONE THING §8b ASKED FOR THAT IS NOT HERE: a single settling-time
number.** `tslo@n@` and `tshi@n@` are the two band edges and the settling time is
the later of the two; combining them needs `max(a,b)` or a ternary inside a
`let`, and **neither was measured**, so neither was shipped. Named in the issue
file's *What is still owed* rather than guessed.

---

## Both arms, before and after, from the `RESULT:` line

| suite / arm | before | after |
|---|---|---|
| `test_ase_core` headless | `ALL PASS (626 checks)` | **`ALL PASS (636 checks)`** |
| `test_ase_core` display (`:99`) | `ALL PASS (626 checks)` | **`ALL PASS (636 checks)`** |
| `test_ase_meas_1443` headless | `ALL PASS (100 checks)` | **`ALL PASS (113 checks)`** |
| `test_ase_meas_1443` display | `ALL PASS (100 checks)` | **`ALL PASS (113 checks)`** |
| `test_ase_dialogs` headless | `ALL PASS (37 checks)` | `ALL PASS (37 checks)` |
| **`test_ase_dialogs` display** | **`1 FAILED (345 passed)`** | **`1 FAILED (362 passed)`** |
| `test_ase_window` | — | `ALL PASS (56)` / `ALL PASS (295)` |
| `test_ase_launch` | — | `ALL PASS (28)` / `ALL PASS (44)` |
| `test_ase_interact` | — | `ALL PASS (10)` / `ALL PASS (64)` |
| `test_ase_persist` | — | `ALL PASS (49)` / `ALL PASS (153)` |
| `test_ase_preflight` | — | `ALL PASS (235)` / `ALL PASS (235)` |
| `test_ase_options_1437` | — | `ALL PASS (75)` / `ALL PASS (75)` |
| `test_ase_predeck_1439` | — | `ALL PASS (78)` / — |
| `test_ase_optsheet_1441` | — | `ALL PASS (62)` / `ALL PASS (87)` |
| `test_ase_effective_1442` | — | `ALL PASS (92)` / `ALL PASS (92)` |
| `test_ase_simreg_0931` | — | `ALL PASS (117)` / — |
| `test_ase_simcaps_0948` | — | `ALL PASS (199)` / `ALL PASS (199)` |
| `test_ase_simdlg_0937` | — | `ALL PASS (5)` / — |
| `test_ase_optier_0963` headless | — | **`ALL PASS (108)`** — §8's asked-for **E17** re-run |

Every baseline was **re-measured here before any edit** and matched the
dispatch exactly, including the red's actual value. Each arm ran under a hard
`timeout` (400–500 s headless, 800 s display).

**The one red on the display arm is `G2sens`** (issue **1436**, standing), actual
`{1 1 0 1 0 Entry Entry normal}` — the value that issue's own file records,
unmoved before and after. `GG9` passed on every run of both arms, as receipts
28, 29 and 30 all found.

**Headless `test_ase_dialogs` is unmoved at 37** because every MS row drives the
real dialog's widgets. The schema halves are `test_ase_core` section **MT** and
`test_ase_meas_1443` section **TP**, both of which run on **both** arms.

⚠ **`test_ase_optier_0963`'s display arm was not run** — issue **1440**, rc 124
at the 200 s suite timeout, the known exception the brief names. Its headless
arm, which is the one T1 runs and the one `PLAN.md` §8 asks for by name, is
**ALL PASS (108)**, so **E17 — *the Outputs Value column reads the OPERATING
POINT* — is confirmed intact**: measurement rows are additive and displaced
nothing.

---

## The `.state` byte-identity measurement

```
$ git ls-files -- '*.state' | wc -l
104
$ timeout 300 ./src/xschem --nogui --pipe -q --nolog --script /tmp/m1451/state_roundtrip.tcl
STATEFILES: 104
MISMATCH:   0
ANALYSIS-ROWS: 416
ROWS-WITH-measurements: 0
CONTROL-DISAGREES: 1
TEMPLATE-ROUNDTRIP: 1
TEMPLATE-ROWS: 3
$ git status --porcelain -- '*.state'
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/tb_bandgap.state
```

— untracked, pre-existing at hand-over, not mine. **Zero tracked `.state` files
modified.** `CONTROL-DISAGREES` is the non-vacuity leg: one measurement row added
to one committed file must stop round-tripping, or the comparison measures
nothing. `TEMPLATE-ROUNDTRIP` is the other half — the three rows a Phase margin
writes serialize and come back identical.

⚠ **The comparison is `"$out\n" ne $orig`**: `ase::state_serialize` omits the
file's trailing newline (`ase::state_save` adds it). Receipt 30 §6 is where that
was written down and it was inherited rather than re-learned.

**And the same question from the GUI side**: row **MS14** opens the dialog on a
bench with no measurements, walks **every one of the nineteen kinds** through the
Kind picker, deletes the row and presses OK — and asks for the same bytes, plus
the term that `measurements` is absent from the serialization entirely. Sabotage
**s15** (the form re-supplying a declared default) reddens it.

⚠ **It presses OK on a bench with a real form standing** — `GR5k`'s blind spot
was that it pressed OK on `op`, which has no fields, so a `form_is_absent` bypass
could not be seen. MS14's walk puts a form with declared fields and declared
defaults on screen (`find`'s `n`, `when`'s `n`, `psd`'s `avgpts`) before it
commits.

⚠ **And no MS row reads `dlg(…,anen)` or any Choose Analyses slot after an OK** —
trap 3 in the dispatch, which has killed a suite file four times in this batch.
Every MS read of the dialog's own state is taken **before** the commit, and every
read of a window a sabotage can remove is guarded.


---

## What changed, with anchors

### `src/ase.tcl` — **23342 → 23802** (+468 / −8)

| anchor | change |
|---|---|
| `:7385` | **`ase::meas_templates`** — the adapter's catalogue, `{}` for a backend with no hook |
| `:7412`–`:7462` | `meas_template_entry` / `_label` / `_analysis` / `_fields` / `_field`, and `ase::meas_names_taken` |
| `:7466` | **`ase::meas_template_expand`** — required fields, the derive hook, the **batch suffix**, and the binding it writes (`id <handle>`, never `row <index>`) |
| `:7515` | `ase::meas_subst` — `@field@` and `@n@`; an unanswered `@name@` is **left alone** |
| `:7524` | `ase::meas_template_errors` — `ase::meas_schema_errors`' sibling |
| `:7581` | **`ase::meas_kind_label`** — the key nothing read until the picker existed |
| `:7595` | `ase::meas_kind_order` — the catalogue's order, not alphabetical |
| `:7605` | **`ase::meas_analysis_choices`** — what the Analysis dropdown may offer |
| `:9741` | **`ase::analysis_handle_line`** — one row's one-liner; `ase::analysis_handle_text` (`:9723`) is now its **caller** |
| `:7335` | `ase::meas_schema_errors` — `yields` permitted on a `letform` kind, with the sentence |
| `:22124` | the 19th kind **`cphase`** in `ase::backend::ngspice::meas_kinds` |
| `:22211` | **`ase::backend::ngspice::meas_templates`** — the eight |
| `:22277` | `ase::backend::ngspice::meas_template_derive` — the arithmetic, in a unit only the adapter knows |
| `meas_needs_degrees` | a **kind** clause: a `cphase` row reads a phase without spelling one |
| `meas_line` | a `cphase` arm returning the `let` |
| `meas_group` | prints a `let`-form row only when its kind yields a **number** |
| `register_backend` | two hooks added: `meas_templates`, `meas_template_derive` |

### `src/ase_window.tcl` — **9892 → 10767** (+875)

| anchor | change |
|---|---|
| `:924` | the menubar gains **`Outputs > Measurements…`**, beside `Save All…` |
| `:6110`–`:6238` | `meas_sim` / `meas_rows` / `meas_state` / `meas_ran` / **`meas_value_cell`** / `meas_results_map` / `meas_analysis_lines` / `meas_producer_names` |
| `:6239`–`:6251` | the thirteen `lbl_*` constants |
| `:6253` | **`ase::ui::measurements_dialog`** — the list, the button bar, Enable, the status and note rows, the buttons |
| `:6206` | `meas_results_list` — **positional with a name guard**, not name-keyed |
| `:6318` | `meas_fill` — the Value column |
| `:6363` | `meas_pick` — idempotent, for `chana_rows_pick`'s reason |
| `:6396` | **`ase::ui::meas_inline`** — R9-325's layout rule, keyed on the copy's own shape |
| `:6428` | **`ase::ui::meas_show`** — Name, the Kind picker, the Analysis dropdown, `Measured on`, and the kind's declared fields |
| `:6560` | `meas_row_vals` — the live form as a row, merged over the stored one |
| `:6628` | **`ase::ui::meas_harvest`** — the one door every rebuild comes through |
| `:6650`–`:6740` | `meas_kind_changed` / `meas_an_changed` / `meas_enable_changed` / `meas_add` / `meas_del` / `meas_move` / `meas_note` / `meas_ok` / `meas_cancel` |
| `:6765` | **`ase::ui::meas_tpl_dialog`** and its four companions — the template picker |
| `run_finished` | **`ase::meas_report`'s first caller anywhere in the tree**, into the run log, plus a Value-column repaint when the dialog is standing |

**State:** `dlg($key,mrows)`, `dlg($key,msel)`, `dlg($key,men)`,
`dlg($key,mkindmap)`, `dlg($key,manmap)`, `dlg($key,mtplmap)`,
`dlg($key,mtplan)` — all array slots on the existing `ase::ui::dlg`, all cleared
by `meas_cancel` and by `ase::ui::close`'s `array unset dlg $key,*`. **No new
state key, no schema change, nothing serialised.**

### The suites

| file | rows | lines |
|---|---|---|
| `tests/headless/test_ase_core.tcl` | section **MT**, 10 rows (MT1–MT10) | 10377 → 10598 |
| `tests/headless/test_ase_meas_1443.tcl` | section **TP**, 13 rows (TP1 TP2 TP2b TP2c TP3 TP3b TP4 TP4b TP5 TP5b TP5c TP6 TP6b) + KN1 and KN4b re-baselined | 1347 → 1649 |
| `tests/headless/test_ase_dialogs.tcl` | section **MS**, 17 rows (MS1–MS17) | 4616 → 5248 |

---

## ⚖ R9 — WHAT WAS CONSUMED UNCHANGED, AND WHAT IS NEW

### Consumed, not re-minted

**R9-294 … R9-342** — the eighteen kind labels, the twenty-eight field labels,
the three picker values (`rise fall cross`) and the two units (`s`, `Hz`) — are
rendered **verbatim**, by `ase::meas_kind_label` in the Kind picker and the list's
Kind column, and by `ase::ui::meas_flabel` in the form. **Nothing in this change
re-words one**, and `MS2`/`MS3` are the rows that say the picker reads the
catalogue rather than its own argument.

**R9-343 … R9-362** — the twelve core refusals and six adapter refusals — reach
the user through `$w.note`, as `ase::meas_verdict`'s own sentence with no frame
around it. **MS11** drives three of ⚖ R6's handle refusals through the real label
and asks for them byte for byte.

**R9-364 … R9-369** — the five report frames and the *"did not report"* advice —
reach the user twice: **`ase::meas_report` in the run log** (its first caller
anywhere in the tree) and **R9-369 in the Value column**, because an empty cell
reads as zero.

**R9-373 … R9-377** — ⚖ R6's handle scheme, `(off)` included — reach the
Analysis dropdown through `ase::analysis_handle_line`, which is now also what
`ase::analysis_handle_text` composes its block from.

**R9-370** — the spectrum caution — is rendered by the same `$w.note` path when
a spectrum row is selected; **R9-371 / R9-372** (the sidecar's raise and its
filename) are untouched.

### New — and every one of them is ⚖ R9's

`owed.sh add rule 1451` filed (ledger `166 rule / 61 look / 10 suite` →
`167 / 62 / 10`; two entries added, none destroyed).

| # | string | where |
|---|---|---|
| 1 | `Measurements` | the dialog's `wm title`, and the word the menu entry and the log heading are composed from |
| 2 | `Measurements…` | `Outputs > Measurements…`, the menu entry. **Composed** — `[ase::ui::lbl_measurements]…`, the shape `Save All…` and `Choose…` already use |
| 3 | `Kind` | the third column heading of the Measurements list, and its form label |
| 4 | `Analysis` | the fourth column heading, its form label, and the template picker's analysis field |
| 5 | `Measured on` | the form label on the producer binding |
| 6 | `(the analysis)` | the `Measured on` value that means *the analysis's own plot* — the blank case, spelled so the picker is never empty |
| 7 | `Up` | the button bar |
| 8 | `Down` | the button bar |
| 9 | `From Template…` | the button that opens the template picker |
| 10 | `Measurement Template` | the template picker's `wm title` |
| 11 | `Template` | its one picker's label |
| 12 | `Measurements:` | the heading `ase::ui::run_finished` puts above the report in the run log. **Composed** from #1 |
| 13 | `DC gain` | template name (adapter) |
| 14 | `-3 dB bandwidth` | template name (adapter). ⚠ ASCII hyphen-minus, not U+2212 |
| 15 | `Unity-gain frequency` | template name (adapter) |
| 16 | `Phase margin` | template name (adapter) |
| 17 | `Gain margin` | template name (adapter) |
| 18 | `Slew rate` | template name (adapter) |
| 19 | `Settling time` | template name (adapter) |
| 20 | `THD` | template name (adapter). Acronym, uppercase, per the house rule |
| 21 | `Output signal` | template field label — the signal every one of the eight reads |
| 22 | `Passband gain` (unit `dB`) | `-3 dB bandwidth`'s third field |
| 23 | `Start level` (unit `V`) | `Slew rate`'s trigger level |
| 24 | `End level` (unit `V`) | `Slew rate`'s target level |
| 25 | `Final value` (unit `V`) | `Settling time` |
| 26 | `Tolerance` (unit `V`) | `Settling time` |
| 27 | `Unwrapped phase` | the 19th kind's label (adapter) |
| 28 | `this template needs a value for $lbl` | the template picker's one refusal |
| 29 | `'$sim' has no measurement template called '$tpl'` | the other, unreachable from the GUI (the picker offers only what the catalogue declares) and reachable from a script |

**Reused byte for byte, not minted:** `Name`, `Value` and `Enable` (the Outputs
pane's own heading words), `Name:` (the `Options…` subdialog's label), `Add` and
`Delete` (its two buttons), `Fundamental` and `Signal` (already declared by issue
1443's kind catalogue and already in the R9 review as R9-333 and R9-322).

⚠ **`Analysis` is a deliberate second use of a word already on screen** — it is
the Choose Analyses radio grid's own noun. The alternative considered was
`Reads`, which would have made the column agree with the refusal sentences
(*"…for 'pm' to read"*); `Analysis` was chosen because the value in the cell is a
handle and the user's question is *which analysis is this*. Flagged because it is
exactly the kind of choice ⚖ R9 exists to rule on.

---

## THE SABOTAGE CAMPAIGN

**Thirty mutations plus a targeted re-run of two**, each a plausible rewrite rather than a break — the tidy-up
somebody would actually make — and **six of them reproduce a claim `PLAN.md`,
this tree's own shipped code, or an earlier draft of this very change actually
makes**: **s1** (the phase-margin row reading `vdb()`, which is what every other
row of that template reads), **s4** (looking the Value up by NAME, which is how
`ase::meas_result` is addressed and what this change shipped until MS10's fourth
term was written), **s6** (`row <index>`, the other selector `ase::meas_binding`
understands), **s9** (printing every `let`, which is issue 1443's shipped rule),
**s13** (hiding the switched-off analyses, which is what issue 1444 literally
proposed), and **s21**/**s23** (dropping a handle the bench no longer resolves,
which is what this change did until §Corrections 10).

Restore is `cp` from `/tmp/m1451/sab/good_*.tcl` with an **md5 compare of all
five files after every application**, and **anchor uniqueness was checked against
the pristine files before the campaign started** — every one of the thirty
resolves to exactly one occurrence.

⚠ **THE CAMPAIGN WAS RESTARTED TWICE, BOTH TIMES BECAUSE IT FOUND SOMETHING
WHILE IT WAS RUNNING**, and a third pass re-ran the two survivors on the repaired
tree — issue 1442's *"two full campaigns, the second on the final tree"*
discipline. The first restart was a behaviour-preserving sabotage that had to be
sharpened; the second and third were **real defects** in the code the campaign
was measuring — §Corrections 10 and 11 — and running the remaining arms against a
tree with a known defect in it would have produced a receipt that said nothing
about either. **Roughly twenty minutes of arms bought two defects and a row.**

| # | what I broke | core | meas | dlg | rows that reddened |
|---|---|---|---|---|---|
| **s1** | meas_templates: the phase-margin row measures vdb() where it means vp() | ALL PASS (636 checks) | 3 FAILED (110 passed) | 2 FAILED (361 passed) | MS15 TP3 TP3b TP4  |
| **s2** | meas_needs_degrees: the cphase clause dropped -- a kind that reads a phase without spelling one | ALL PASS (636 checks) | 1 FAILED (112 passed) | 1 FAILED (362 passed) | TP2  |
| **s3** | meas_needs_degrees: never fires | ALL PASS (636 checks) | 7 FAILED (106 passed) | 2 FAILED (361 passed) | MS15 PH1 PH3 PH6 TP2 TP3 TP3b TP4  |
| **s4** | meas_fill: look the result up by NAME, as ase::meas_result is addressed | ALL PASS (636 checks) | ALL PASS (113 checks) | 2 FAILED (361 passed) | MS10  |
| **s5** | meas_value_cell: a failed measurement is a blank cell | ALL PASS (636 checks) | ALL PASS (113 checks) | 2 FAILED (361 passed) | MS10  |
| **s6** | meas_row_vals: the dropdown stores `row <index>` instead of `id <handle>` | ALL PASS (636 checks) | ALL PASS (113 checks) | 4 FAILED (359 passed) | MS16 MS4 MS5  |
| **s7** | meas_template_expand: the template binds by index too | 1 FAILED (635 passed) | ALL PASS (113 checks) | 3 FAILED (360 passed) | MS15 MS8 MT3  |
| **s8** | meas_template_expand: the suffix is chosen PER ROW, not per batch | ALL PASS (636 checks) | 2 FAILED (111 passed) | 1 FAILED (362 passed) | TP4 TP5  |
| **s9** | meas_group: print every `let`, as the param row already is | ALL PASS (636 checks) | 2 FAILED (111 passed) | 1 FAILED (362 passed) | TP2 TP4  |
| **s10** | meas_subst: the batch suffix is not in the substitution map | 1 FAILED (635 passed) | 11 FAILED (102 passed) | 3 FAILED (360 passed) | MS15 MS8 MT4 TP2 TP2b TP2c TP3 TP3b TP4 TP4b TP5 TP5b TP5c TP6  |
| **s11** | meas_inline: no inline continuation -- every label starts its own row | ALL PASS (636 checks) | ALL PASS (113 checks) | 2 FAILED (361 passed) | MS9  |
| **s12** | meas_pick: picking another line does not harvest the standing form first | ALL PASS (636 checks) | ALL PASS (113 checks) | 2 FAILED (361 passed) | MS6  |
| **s13** | meas_analysis_choices: hide the switched-off analyses | 1 FAILED (635 passed) | ALL PASS (113 checks) | 3 FAILED (360 passed) | MS4 MS8 MT7  |
| **s14** | meas_kind_label: show the kind's token, not its declared label | 1 FAILED (635 passed) | 1 FAILED (112 passed) | 3 FAILED (360 passed) | MS2 MS3 MT9 TP1  |
| **s15** | meas_fabsent: a value equal to the declared default still writes a key | ALL PASS (636 checks) | ALL PASS (113 checks) | 2 FAILED (361 passed) | MS14  |
| **s16** | meas_value_cell: normalise the simulator's number through format %g | ALL PASS (636 checks) | ALL PASS (113 checks) | 3 FAILED (360 passed) | MS10 MS15  |
| **s17** | analysis_handle_line: drop the `(off)` marker | 2 FAILED (634 passed) | ALL PASS (113 checks) | 4 FAILED (359 passed) | GH8 HN11 MS4 MS8 MT8  |
| **s18** | meas_template_derive: -3 dB is gain PLUS 3.0103 | 1 FAILED (635 passed) | 1 FAILED (112 passed) | 1 FAILED (362 passed) | MT6 TP4  |
| **s19** | meas_templates: the settling template writes the low edge twice | 1 FAILED (635 passed) | 1 FAILED (112 passed) | 1 FAILED (362 passed) | MT6 TP4b  |
| **s20** | meas_analysis_choices: an explicit type WIDENS past measurability | 1 FAILED (635 passed) | ALL PASS (113 checks) | 1 FAILED (362 passed) | MT7  |
| **s21** | meas_show: a handle the bench no longer resolves is dropped from the picker | ALL PASS (636 checks) | ALL PASS (113 checks) | 2 FAILED (361 passed) | MS16  |
| **s22** | measurements_dialog: a hand-rolled button bar instead of dialog_buttons | ALL PASS (636 checks) | ALL PASS (113 checks) | 2 FAILED (361 passed) | MS17  |
| **s23** | meas_row_vals: an unmapped picker value clears the binding | ALL PASS (636 checks) | ALL PASS (113 checks) | 1 FAILED (362 passed) | **SURVIVED** |
| **s24** | meas_fill: the Value column reads the row BELOW it | ALL PASS (636 checks) | ALL PASS (113 checks) | 3 FAILED (360 passed) | MS10 MS15  |
| **c1** | CONTROL -- MS10's sidecar writer writes nothing | ALL PASS (636 checks) | ALL PASS (113 checks) | 3 FAILED (360 passed) | MS10 MS15  |
| **c2** | CONTROL -- TP5's extractor returns nothing | ALL PASS (636 checks) | 2 FAILED (111 passed) | 1 FAILED (362 passed) | TP5 TP5b  |
| **c3** | CONTROL -- MT3's id term stops being the caller's own handle | 1 FAILED (635 passed) | ALL PASS (113 checks) | 1 FAILED (362 passed) | MT3  |
| **c4** | CONTROL -- MS15's fixture never names the output signal | ALL PASS (636 checks) | ALL PASS (113 checks) | 2 FAILED (361 passed) | MS15  |
| **c5** | CONTROL -- `reaches` is given an uppercase label | ALL PASS (636 checks) | ALL PASS (113 checks) | 2 FAILED (361 passed) | MS9  |
| **c6** | CONTROL -- MS16's fixture keeps a resolvable analysis | ALL PASS (636 checks) | ALL PASS (113 checks) | 2 FAILED (361 passed) | MS16  |

**Final: 30 applications on the final tree, `md5ok=1` on all five files every
time, a `RESULT:` line from all three suites every time (`results=3`, thirty
times), 29 RED and ONE survivor — and zero kills.** `G2sens` (issue 1436) reds on
every display arm and is omitted from the red lists.

**Every MS, MT and TP row has at least one witness**: MS2 s14 · MS3 s14 · MS4
s6/s13/s17 · MS5 s6 · MS6 s12 · MS8 s7/s10/s13/s17 · MS9 s11/**c5** · MS10
s4/s5/s16/s24/**c1** · MS14 s15 · MS15 s1/s3/s7/s10/s16/s24/**c1**/**c4** · MS16
s6/s21/**c6** · MS17 s22 · MT3 s7/**c3** · MT4 s10 · MT6 s18/s19 · MT7 s13/s20 ·
MT8 s17 · MT9 s14 · TP1 s14 · TP2 s2/s3/s9/s10 · TP3 s1/s3/s10 · **TP3b s1/s3/s10**
· TP4 s1/s3/s8/s9/s10/s18 · TP5 s8/s10/**c2** · TP6 s10.

**MS1, MS7, MS11, MS12 and MS13 have no witness in this campaign**, and that is
stated rather than hidden: they assert that a door EXISTS (the menu entry and
the dialog), that Cancel writes nothing, that the verdict label carries the
evaluator's sentence, that `Measured on` appears and stores, and that Enable is a
tri-state. Each is broken only by deleting the thing it names, which is a
different kind of mutation from the twenty-four above; **s22** is the one of that
family that was worth writing, because a hand-rolled button bar is a rewrite
somebody would actually make.

**Four sabotages redden rows in sections this change did not write** — s3 reds
issue 1443's **PH1 / PH3 / PH6**, and s17 reds issue 1448's **GH8** and issue
1447's **HN11**. A feature whose only witnesses are its own new rows is a feature
nothing else in the tree is watching.

### ⚠ THE ONE SURVIVOR, AND IT CANNOT FAIL

**s23** changes `if {$l eq {}}` to `if {$l eq {} || ![dict exists $manmap $l]}`
in `meas_row_vals`' analysis branch. **The added clause is unreachable**: since
the fix in §Corrections 10 the picker offers the stored handle whenever it is not
already among the resolvable ones, so **every value the combobox can hold is in
`manmap` by construction** and the two conditions are the same condition. It is
the behaviour-preserving-respelling class issue 1443 met three times — a mutation
that introduces no defect, not a row that failed to catch one. **s21**, which
removes the offer itself, is the mutation that makes the difference visible, and
it reds **MS16**.

### ⚠ AND ONE SABOTAGE CHANGED A ROW RATHER THAN FAILING: s15

**s15 survived the campaign and is now red.** `MS14` walked every kind through
the Kind picker and then **deleted its row before pressing OK**, so it could say
that the empty list is not written and nothing at all about what a committed row
CARRIES — which is exactly where the byte-identity rule bites. The row now also
builds a `when` row, leaves `Edge number` at the declared `1` the form itself put
there, commits, and asks for **no `n` key**, with a changed `2` as the control.
Re-run on the repaired tree: **s15 → MS14**.

⚠ **And writing it cost the file once, in the documented way.** `Edge number` is
an ENTRY and not a picker; `$w.form.fn set 2` raised `bad option "set"` INSIDE a
check and **killed the suite at MS13** — no MS14, no MS15, no MS16, no MS17 and
no row red. That is G2tf's failure shape met for the fifth time in this batch,
and the fix is in place in the row itself.

### The four ways a row fails to fail, answered

1. **Fixtures that never disagree.** MS4's bench carries a `tran` row, a
   *switched-off* second `ac` row and an `op` row the dropdown must never offer,
   so "the picker is the speller's answer" cannot pass on a one-row bench. MT4's
   two phase margins are a fixture whose whole point is that the second must
   differ from the first. TP5's two sidecars are the SAME run printed by two
   binaries, so "the value comes back verbatim" cannot pass on a normaliser.
   MS16's fixture removes the very analysis its row names.
2. **Position asked where the mechanism is last-writer-wins.** Inverted on
   purpose: MS7 and MS14 ask for **whole-serialization byte equality**, MS5 asks
   for the ORDER the deck emits rather than the order the list shows, and MS10's
   fourth term asks for one row's number in the presence of another row with the
   same name.
3. **An extractor that returns nothing.** Five positive controls, all sabotaged:
   the sidecar writer (**c1**), TP5's result extractor (**c2**), MT3's id term
   (**c3**), MS15's template field (**c4**) and MS9's lowercase label (**c5**),
   plus **c6** for MS16's own fixture.
4. **A sabotage missing from the generator.** The first pass was four short in
   the way receipts 24, 25 and 28 each found theirs to be: the batch suffix's
   substitution map (s10), the `(off)` speller (s17), the picker's offer of an
   unresolvable handle (s21) and the ESC path (s22) were all unwitnessed until
   they were written. **s15 is the fifth**, and it is the one that changed a row
   instead of being added.


---

## What I did NOT ship, and why

* **A Measurements PANE in the main window.** §8b's *"What you see"* paragraph
  says *"a Measurements pane with a number in it"*, and the main window has
  **exactly three** panes — `tests/headless/test_ase_window.tcl` **W1p** asserts
  that set by name, and that file is not this task's. The Value column lives in
  the dialog's own list instead, which is where the rows are created and edited.
  Recorded here rather than silently substituted: if the user wants the numbers
  visible without opening a dialog, that is a fourth pane and it moves a suite
  this task may not open.
* **A single settling-time number — AND THE MEASUREMENT IS WHY, NOT THE
  ABSENCE OF ONE.** Measured on both binaries while this task was running:

  ```
  let m1 = max(a,b)          -> m1 = 7.000000e+00   BOTH binaries
  let m2 = (a > b) ? a : b   -> apt 45.2: PPerror: syntax error in line segment
                                          Error: RHS "(a ? a : b" invalid
                                the fork: m2 = 7.000000e+00
  ```

  So `ts@n@ = max(tslo@n@, tshi@n@)` **is** portable and is still not shipped: a
  step that does not overshoot never crosses the upper edge, `tshi` fails, and
  the `max` fails with it — **the single number would vanish in exactly the
  common case**, taking the edge that WAS measured with it. Two rows, both
  reported, is the robust shape. ⚠ **And the ternary is a NEW two-binary
  difference** — `? :` inside `let` is fork-only and a hard syntax error on apt
  45.2. Nothing emits one today; recorded so nothing starts, and it belongs in
  `evidence/binary-differences.md`, which is not this task's file.
* **An ESC row of its own for each new toplevel beyond MS17.** ESC comes from
  `ase::ui::dialog_buttons` **by construction** — both new toplevels are built
  through it, which is the same mechanism sections GE1-16 cover for every other
  dialog in that file. MS17 drives a real generated `<Key-Escape>` at both rather
  than asserting the binding exists.
* **An `▸ Advanced` disclosure on the measurement form.** Ten fields on the
  delay form is a lot, and splitting them is the obvious next move — but §8b's
  own inherited note says the precondition banner's `chana_merged_row` reads live
  widgets only, so *"if task 2's Measurements form has any `needs` rule that
  reads a field behind `▸ Advanced`, this becomes visible"*. This form has no
  disclosure and therefore no hidden field, so `GR6h`'s residual stays exactly
  where issue 1446 left it and is neither widened nor accidentally closed.
* **A per-row edit cache keyed by handle.** Choose Analyses needs one because it
  edits one row of a list it never otherwise touches; a list editor that reorders
  and deletes cannot be built that way. The whole list is the working copy and
  `meas_harvest` is the one door. Named because the brief asked for the ⚖ R5
  inheritance and this is the shape it took.
* **Any change to `ase::ui::chana_ok`, `chana_commit_vals` or `chana_cache_key`.**
  `GR6e` — *one OK writes one row* — is green throughout and no sabotage in the
  campaign touches that door.
* **A `Measurements` column in the main window's Analyses pane.** Same reason as
  the pane: `test_ase_window.tcl:1771` asserts that pane's `-columns` by value.

---

## Corrections to the brief and to the plan

1. ⚠ **`PLAN.md` §8b's Gain margin line answers nothing** — the headline above.
   `vp()` is wrapped and `meas`'s WHEN operand cannot be an expression, both
   measured on both binaries. The template needs a named vector, which is the
   19th kind.
2. ⚠ **§8b's Phase margin names two rows `pm`**, which ASE-L refuses by design
   (issue 1443's duplicate-name rule, row `VD17`). `pmph@n@` / `pm@n@`.
3. ⚠ **§8b's "Slew rate" emits a delay in SECONDS.** A time reported under the
   name `sr` is this batch's own defect class. Two rows.
4. ⚠ **§8b's "fills two fields" is three or four for half of them**, and the
   extra field is the one that decides the answer.
5. ⚠ **The brief's *"the Value column"* is the DIALOG's**, not a fourth main-window
   pane — `test_ase_window.tcl` **W1p** asserts exactly three panes and that file
   is not in this task's list. Named rather than substituted.
6. ⚠ **`ase::meas_analysis_choices`' first cut let an explicit type WIDEN past
   measurability**, so a caller asking for `op` was handed a handle that refuses
   the moment it is stored. Found by `MT7`'s own third term on its first run —
   the measurability filter is unconditional and the type filter is additional.
   Recorded because it is the shape of defect the dropdown exists to prevent.
7. ⚠ **A `letform` row that yields a VECTOR had no way to exist**, because
   `meas_group` printed every `let` and `meas_schema_errors` allowed `yields` only
   on a producer. Both were widened narrowly, both with a row, and both are the
   direct consequence of correction 1.
8. **The brief's baseline is exact**, both arms and the red's actual value,
   re-measured here before any edit: `test_ase_core` 626/626,
   `test_ase_dialogs` 37 / `1 FAILED (345 passed)`, `test_ase_persist` 49/153,
   `test_ase_meas_1443` 100/100.
9. ⚠ **The brief's trap 2 was real and is dodged by construction, not by care**:
   no MS row reads `dlg(…,anen)` or any Choose Analyses slot after an OK, and
   `MS14` presses OK on a form that HAS declared fields and declared defaults —
   `GR5k`'s `op` blind spot, inherited from `GR6f` and `GH15` rather than
   re-learned.
10. ⚠ **THE DIALOG THREW AWAY A BINDING THE BENCH NO LONGER RESOLVED, AND I
    FOUND IT BY READING MY OWN CODE RATHER THAN BY A ROW.** Delete the `ac` row
    a measurement reads and the bench still says `id ac1` — but the Analysis
    picker offered only handles that resolve, so the combobox came up EMPTY and
    `meas_row_vals`' *"blank means no analysis"* branch stripped `id` and
    `analysis` off the row on the next selection change or OK. A user who opened
    the dialog only to LOOK would have lost the binding in silence, and the
    verdict would then have said *"this measurement names no analysis"* instead
    of naming the one it used to read.
    **The fix is this batch's own rule from the other side**: the picker offers
    the stored handle even when it no longer resolves, so the row shows what it
    says and `ase::meas_verdict` explains it. **MS16** is the row, with the
    verdict sentence as its control; **s21** (drop the offer) and **s23** (treat
    an unmapped value as blank) are its two sabotages and **c6** is the control's
    own.
    ⚠ **The campaign was STOPPED, the tree fixed, and the whole campaign
    restarted** rather than running the remaining arms against a tree with a
    known defect in it — issue 1442's *"two full campaigns, the second on the
    final tree"* discipline applied at the moment the defect was found.
11. ⚠ **AND A SECOND ONE, FOUND THE SAME WAY: A DUPLICATE NAME PUT THE SECOND
    ROW'S REFUSAL IN THE FIRST ROW'S CELL.** The Value column looked its answer
    up by NAME, which is how `ase::meas_result` is addressed and therefore the
    obvious thing to write. Two rows may share a name — `ase::meas_verdict`
    refuses the second, because the sidecar's lookup is case-insensitive and the
    second answer would overwrite the first's — but the row is **still storable
    and still on screen**, and a name-keyed map hands the first row, the one with
    a real number in it, the second row's *"another measurement is already
    called 'ugf'"*. The user reads a refusal in the cell of the measurement that
    worked.
    The lookup is now **positional with a name guard**: `ase::meas_results`
    walks the state `ase::ui::meas_state` built from this very list, so element
    `i` is row `i` by construction, and a blank is the only honest thing to show
    if the two ever disagree. **MS10's fourth term** is the row; **s4** (by name)
    and **s24** (the row below) are its sabotages.
    ⚠ **The campaign was stopped a second time for it.** Two stops cost roughly
    twenty minutes; running twenty-eight arms against a tree with a known
    display defect in it would have cost a receipt that said nothing about it.
12. ⚠ **A display-arm suite run can end without a `RESULT:` line and without an
    error.** Measured during the campaign: one arm's `test_ase_dialogs` display
    run stopped after `MS14` at 95 s, with no `RESULT:`, no `OVERALL:` and no
    message on either stream; the identical arm re-run immediately afterwards
    produced `2 FAILED (359 passed)` with the expected row red. The campaign
    runner now **detects a missing `RESULT:` line and re-runs the arm**, and says
    so. A sabotage scored from a truncated log reads as a SURVIVOR, which is the
    "guard nobody can trip" shape from the other end.

---

## Debts

* **`owed.sh add rule 1451`** — the twenty-nine new sentences listed verbatim
  above. Filed, stamped `repo:/home/analog/dev/xschem-claude`.
* **`owed.sh add look ase_measurements_dialog_1451`** — **suites green on both
  arms, please look.** A whole new sub-dialog, a template picker inside it and a
  new Value column are pixels, and a green suite is not a pair of eyes.
  ⚠ **`PLAN.md` §8 claims this stage files none**, on the ground that the pane
  reuses Stage 5's `resulttable` and Stage 3's form idiom — **and it does not**:
  the dialog is a new toplevel, the template picker is a second one, and the
  form's inline-continuation rule (R9-325) is a layout nothing else in the tree
  has. **Decided by measurement, as the ledger asked.** That paragraph's other
  half — *"check the `deg` unit actually reaches the Y-axis label"* — is
  untouched by this task and stays open: no Y-axis label is drawn here.
* **`owed.sh add suite test_ase_dialogs`** — reported *updated*, so one was
  already standing. **Not drained** — a drain runs with the gate live and pops
  the user's panel; that is the driver's batching call.
* ⚠ **A ledger backup was taken before the first `add`**, at
  `/tmp/m1451/owed_backup_*`. Counts went `166 rule / 61 look / 10 suite` →
  `167 / 62 / 10`: two added, none destroyed. **The same four unstamped entries
  receipts 27, 28 and 30 found are still there and are still not mine** —
  `rule/1357`, `rule/1357@xschem-claude`,
  `look/hier_pdf_nav_1357_H6.1789071932.2875683`,
  `suite/test_hier_pdf_links_1333` — and the rest split **220 this clone / 13
  op-wcard** (was 216/13 at receipt 28).

---

## Testing discipline

**⚠ THE THREE-BINARY RULE APPLIES HERE AND WAS OBEYED.** This change alters what
ASE-L **emits** — eight new templates, a 19th kind, a new `let` line — so every
one of them was rendered by `ase::backend::ngspice::meas_block` and then **run on
`/usr/bin/ngspice` (apt 45.2) and on
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (the fork)**. All eight
answered on both. The two binaries agreed about every measurement and disagreed
about two things, both recorded: the **print width** of the `meas` echo (six
decimals against five) and the **value** of `sr` (`4.230294e+03` against
`4.230282e+03`), which is a real numeric difference and not a formatting one.

**No simulation was started on any bench under `sky130A/`.** Every run above is
`/tmp/m1451/tb2.cir` or a sibling, invoked by absolute path with an explicit
output directory under `/tmp/m1451/run`. Nothing under `~/.xschem/` was read,
written or moved. Every launch of this tree's binary carried `--nolog`; **no
`--logdir`**; never a bare `xschem`.

**The binary was not rebuilt and did not need to be** — checked rather than
assumed: `find src -name '*.c' -newer src/xschem` and the same for `*.h` both
print **nothing**; only `.tcl` files are newer and those are read from
`XSCHEM_SHAREDIR` at run time.

**Display arm:** `:99` (Xvfb 1920x1080x24 + **openbox**; `devdisplay.sh status`
reports `wm: openbox (Openbox)`), reached through `tests/headless/devdisplay.sh
exec`.

---

## For the driver

1. **`test_ase_dialogs` display is at exactly one red**, `G2sens` (issue 1436),
   `RESULT: 1 FAILED (362 passed)`.
2. **T1's number moves and its baseline stays zero.** `run_regression.tcl` runs
   `test_ase_core` on **both** arms (626 → **636**, ALL PASS on each, measured
   directly) and `test_ase_meas_1443` **headless only** (100 → **113**, ALL
   PASS). `test_ase_dialogs` is in **neither** arm's case list, so T1 exercises
   none of section MS. T1 was **not** run by this crew (issue 0990).
3. **`NUMBERING.md`'s pointer advanced 1451 → 1452.** Both mint checks were
   re-run at the moment of minting, not taken from the dispatch: the
   reserved-band scan over this clone's head table (**silent** for 1451) and
   `ls ~/dev/*/doc/claude/issues/1451-*` plus `/usr/bin/grep -lw 1451` across
   every clone's `NUMBERING.md` (only this clone's own pointer line; the glob was
   proved non-empty first).
4. **Three ledger debts are open**, and two of them clear only when the user says
   so: `rule 1451` (⚖ R9 — twenty-nine new sentences) and
   `look ase_measurements_dialog_1451`.
5. **Issue 1444 is one surface from closing.** Surface 1 (the Measurements
   dropdown) landed here and the file is appended; only the **editable `id`
   field** remains, and its blocker is gone (1449 taught the emit check the word,
   1450 collapsed the three copies).
6. **HEAD did not move under this task.** Handed over at `5c643a7f`; still there.
   Working tree: **five modified** (`src/ase.tcl`, `src/ase_window.tcl`,
   `tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_dialogs.tcl`,
   `tests/headless/test_ase_meas_1443.tcl`, plus
   `doc/claude/issues/NUMBERING.md` and `doc/claude/issues/1444-…md`) and **two
   new** (the 1451 issue file, this receipt). The four untracked paths inherited
   at hand-over are untouched. **Nothing was committed, added, stashed, restored,
   cleaned or pushed.**
7. **The one thing worth carrying forward.** `PLAN.md` §8b's table is now wrong
   in four places and this receipt is the only record of it. If Stage 9 or the
   spec pass reads that table without reading this, the gain margin goes back to
   `vp(out)` and stops answering.

---

## Commands, for the driver to re-run

```sh
cd /home/analog/dev/xschem-claude
timeout 500 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_core.tcl
timeout 800 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_core.tcl
timeout 500 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_meas_1443.tcl
timeout 800 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_meas_1443.tcl
timeout 400 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl
timeout 800 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl
timeout 300 ./src/xschem --nogui --pipe -q --nolog --script /tmp/m1451/state_roundtrip.tcl
# the eight templates, rendered by meas_block and run on BOTH binaries
timeout 200 ./src/xschem --nogui --pipe -q --nolog --script /tmp/m1451/probe3.tcl
( cd /tmp/m1451 && /usr/bin/ngspice -b tb2.cir ; cat run/tb_ase.meas )
( cd /tmp/m1451 && /home/analog/dev/ngspice/build-ver_50/src/ngspice -b tb2.cir ; cat run/tb_ase.meas )
# the radians half of the same deck
( cd /tmp/m1451 && /usr/bin/ngspice -b tb2_rad.cir ; cat run/tb_ase.meas )
/tmp/m1451/sab/run.sh s1 s2 s3 ...
```
