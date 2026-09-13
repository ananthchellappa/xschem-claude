# Stage 7 task 3 — finding one option among 247, and the badge nobody had measured

**One commit, issue 1441, and the third of Stage 7's four tasks.** Scope was
`PLAN.md` **§7c** and nothing else; §7a+§7b landed as task 1 (`d2f4437a`, issue
1437), §7d as task 2 (`98beb2b5`, issue 1439); §7e, §7f and §7g are task 4 and
are untouched here.

**Floor:** new suite `test_ase_optsheet_1441` — **62 headless / 87 on the dev
display** — registered in `tests/run_regression.tcl`'s **`hcases` AND `dcases`**,
so **T1 covers all of both arms**.

> ⚠ **DRIVER FOOTNOTE 2026-09-13.** The line above read *"so T1 covers all 82"* and
> **82 is not a number this suite produces.** Driver-measured, both arms, through
> `run_suites.sh`: **62 headless** and **87 on `:99`** — so T1 gains **149** checks from
> this suite, which is what this receipt's own summary says elsewhere. The same stale pair
> reached `tests/run_regression.tcl`'s new comment as *"80 checks against 55"* and was
> corrected there in place, since that one is live documentation rather than a dated
> record. Everything else in this receipt is left as written. `test_ase_options_1437` stays at **75** with **one row
re-baselined** (BR6). Nothing else moved.

**`src/ase.tcl` 20246 → 20614 lines** (+368): 13 new `ase::` procs (the schema
half), 1 new `ase::backend::ngspice` proc behind a new optional hook (the content
half), 23 catalogue rows corrected, and `render_deck`'s option loop **lifted out
whole** into the body the preview reads. **`src/ase_window.tcl` 8898 → 9273**
(+375): the options sheet.

---

## ⚠ THE HEADLINE: THE BADGE WOULD HAVE LIED ABOUT THREE ROWS, TWO OF THEM DIAGNOSTIC PRINTERS

The brief said this was the one outcome it would reject, so it is the first
thing here. `PLAN.md` §7c-5 asks for *"a ⚠ badge on every `results 1` row — the
21 options that change numbers"*. Issue 1437 shipped that column **0 / 247
verified** and said so.

**All 22 `results` rows were probed on BOTH binaries** — `/usr/bin/ngspice`
(`ngspice-45.2`) and `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
(`ngspice-46+`) — on 2026-09-13, each on a deck built to make **its own
documented mechanism fire**. Every value was identical on the two.

### MEASURED to move a printed value — 9

| option | the measurement |
|---|---|
| `scale` | `.options scale=0.5` → `@m1[w]` 2.000000e-06 → 1.000000e-06, `@m1[l]` 1.5e-07 → 7.5e-08 |
| `wnflag` | two binned BSIM4 models across the W bin edge: `@m1[vth]` 1.088900 → 0.688900, `i(vd)` −7.73196e-05 → −6.23913e-04 — **8×**. The bare card `.options wnflag` delivers **nothing**, reproducing 1438/1439 independently |
| `sqrnoise` | `onoise_total` 3.147875e-07 → 9.909116e-14 |
| `cshunt_value=1n` | every AC, TRAN and NOISE value of the probe deck (`vdb(mid)` −2.74175e-01 → −2.87193e-01) |
| `notrnoise` | a `trnoise` source to 0.000000e+00 at every timepoint |
| `seed` | `seed=12345` vs `seed=999`: different samples, both unlike the unseeded run |
| `autostop` | with one `.meas`: **226 data rows → 2** |
| `diode_cj0=10p` | under `ngbehavior=ps`, through the run-directory start-up file: AC imaginary part 0.000000e+00 → 1.066292e-04 |
| `diode_rser=100` | same route: `i(vb)` 5.670347e-03 → 5.867302e-04 |

### MEASURED NOT TO, with the mechanism demonstrably firing — 3

| option | the measurement |
|---|---|
| `warn=1` | five resistors over `bv_max`: **0 → 5 SOA `Bv_max` messages, and EVERY printed value byte-identical** |
| `maxwarns=2` | **5 messages → 2**, every printed value identical |
| `num_threads=1` | against the default: identical OP, AC, TRAN and NOISE |

⚠ **The transcription would have badged all three.** `evidence/hidden-vars.md`
§2.1's own **R/P column already marks them P** — the row said `results 1`
anyway. That is the defect §7c's badge exists to prevent, living inside the
badge.

### NOT MEASURED — 10

`auto_bridge`, `no_auto_bridge_family`, `noisyxspice`, `xtrtol` (event-driven or
A-device XSPICE); `ng_nomodcheck`, `enable_noisy_r` (model and netlist shapes
this probe set could not build); `dyngmin`, `topo_reduce`, `nostepsizelimit`
(nothing distinguished the two runs); `soacheck` (needs a PDK library that reads
`SWSOA`).

### What shipped because of it

`ase::opt_results` answers **three** values, and the shape is the point:

```
results_ev measured + results 1  -> yes          badge: ⚠ CHANGES RESULTS
results_ev measured + results 0  -> no           badge: none
results 1, no results_ev         -> unverified   badge: ⚠ MAY CHANGE RESULTS — UNVERIFIED
```

⚠ **THE DEFAULT IS `unverified`, NOT `yes`.** A catalogue cannot acquire a
measured badge by being edited — only by someone taking the measurement. Row
**RB5** pins that on a four-row synthetic backend, and **RB6/RB7** assert that
every measured row carries its measurement and every unverified row says why it
could not be taken, so the sentence the user reads is the one that was earned.

**So the answer to the brief's first question is: BOTH.** The nine are measured
and the badge asserts it; the ten are not and the badge **says so on the surface
itself** rather than in a receipt. What is not shipped anywhere is a badge that
asserts a measurement nobody took.

---

## ⚠ WHAT I VERIFIED VERSUS WHAT I TRANSCRIBED

| claim | evidence |
|---|---|
| the `results` column, all 22 rows | **MEASURED on both binaries**, numbers above, each with its mechanism made to fire. 9 confirmed, 3 refuted, 10 recorded as unmeasurable here and labelled on the surface |
| `warn` / `maxwarns` fire at all | **MEASURED** — 0→5 and 5→2 SOA messages. Without that the "no change" result would be the vacuity defect this batch has hit nine times, in a measurement instead of a row |
| `-D diode_cj0=10p` delivers nothing; the run-directory file does | **MEASURED on both binaries** — the `CP_STRING` trap (T5), live, and the reason `ase::opt_door` splits `predeck` from `predeck-file` |
| the `scope` column | **CROSS-CHECKED against `evidence/options.md` §10.2**, the document it was transcribed from: **zero set-level disagreements over the 27 shared rows**. Two rows moved (`dyngmin`, `chgtol`); the seven *"Any with XSPICE A-devices"* rows stay `global` because that is a device condition, not an analysis. ⚠ This is a **document** check, not a simulator measurement — `scope` is a GUI grouping and there is nothing in ngspice to measure it against. The design is what makes it safe: **the global surface offers every row**, so a wrong scope costs a shortcut and never an option (row SC1) |
| the `group` column | **CROSS-CHECKED against `evidence/hidden-vars.md` §7** and **114 of 205 taggable rows disagree** — so it is **NOT verified and cannot be**, and this receipt says so rather than implying otherwise. Most of the gap is §7.8 *"Output and formatting"*, one 100-name bucket the catalogue splits five ways, which is an improvement. The one real defect was fixed (below) |
| the catalogue's `cptype`, `site`, `phase`, `inert`, block A `help` and `default` | **inherited from task 1, measured there**, re-read only where a row of this pass asserts one |
| `units` has no `help` | **VERIFIED by grep** over the shipped catalogue: four of the five sentences task 1's receipt mints are present and `units` is not |
| 65 of 247 rows carry a `default`; 64 carry `help` | **COUNTED** over the shipped catalogue (rows CH5 and FN11 assert the shape rather than the exact number, so adding a row does not red them) |

---

## What shipped — the SCHEMA half (`src/ase.tcl`, `ase::`)

| proc | what it answers |
|---|---|
| `ase::opt_group {sim name}` | the row's drawer, or `other` |
| `ase::opt_scope {sim name}` | `global` or `{analysis <type> ...}` |
| `ase::opt_in_scope {sim name scope}` | is this row offered on this surface — **and the global surface offers everything** |
| `ase::opt_results {sim name}` | `yes` / `no` / `unverified` |
| `ase::opt_results_why {sim name}` | the measurement, or why it could not be taken |
| `ase::opt_help {sim name}` | the row's sentence, or `{}` |
| `ase::opt_match {sim name needle}` | the live search, over **name, group and help**, by substring |
| `ase::opt_browse {sim ...}` | the sheet's row set: `-needle`, `-scope`, `-state`, `-changed` |
| `ase::opt_group_index {sim names}` | groups, ordered, names ordered inside each |
| `ase::opt_stored_verdict {sim state name}` | `changed` / `default` / `nodefault` / `unknown` |
| `ase::opt_fallback_line {sim name value}` | the adapter's last-resort spelling, through a hook |
| `ase::opt_deck_plan {sim state}` | **the emitter's own option loop**, lifted out whole |
| `ase::opt_preview {sim state}` | the four slots and the notes — §7c-6 |

## What shipped — the CONTENT half (`ase::backend::ngspice`)

`option_fallback`, registered as a new optional hook: the `.options name[=value]`
last-resort spelling for a name the catalogue does not describe, or a row the one
speller refused. **A backend with no hook gets no fallback content** (D34) — row
**DP5** — and section **HK1** asserts lexically that none of the thirteen new
core procs contains `reltol`, `gminsteps`, `keepopinfo`, `casemode`, `sqrnoise`,
`wnflag`, `savecurrents`, `.options`, `.control`, `CP_BOOL`, `CP_NUM`, `ngspice`,
`spiceinit` or `-D`. **HK2** is its non-vacuity row: the same scanner over the
adapter's own fallback **finds** `.options`.

**23 catalogue rows corrected**: 22 `results` rows gain `results_ev` and
`results_why` (3 of them changed to `results 0`), 20 of those are re-filed out of
the `numerics` group, `scale` and `wnflag` move to `device`, `dyngmin` and
`chgtol` gain an analysis scope, and `units` gains a help sentence.

## What shipped — the SURFACE (`src/ase_window.tcl`)

`Simulation > Options…` **keeps its toplevel, its treeview path, its context
menu, its `$w.optrow` row editor and its integer row ids**, because the
changed-only default view *is* the bench's stored rows in the bench's own order.
`test_ase_dialogs`' **G6 and GE9 drive exactly those gestures and neither
moved** — 37 headless, 299 passing on the display arm, unchanged.

What is new around them: `Find:` (live, substring, over name/group/help),
`Show all` (the other ~240 rows in 14 groups, each naming its count), `Scope:`
(Global or one of the bench's analysis types), a `Results` badge column, a
`Written` slot column, a detail line, and the **live deck preview**. The second
surface §7c-4 asks for is the same sheet opened from the analysis form's
`Options…` dialog with the scope preset — one sheet, because two would be two
opinions about one `options` list.

---

## ⚠ THE PREVIEW IS THE NON-NEGOTIABLE MADE STRUCTURAL, NOT MERELY TESTED

*"Nothing the window shows may fail to reach the deck; nothing the deck contains
may be unshowable in the window."* The way to fail that is to write a second body
that computes what the deck *would* contain — and the preview is then the one
nobody runs.

So `render_deck`'s option loop **moved**. `ase::opt_deck_plan` is that loop, the
emitter calls it, and `ase::opt_preview` reads it. The three arms and the output
are unchanged — **no deck golden moved** — and row **DP6** asserts the rendered
deck carries exactly the shared body's lines in that order, with **DP7** as its
non-vacuity half: an option the body writes no line for has no card in the deck
either (`casemode`, which 1439 took out on purpose, and a switched-off row).

⚠ **AND THE CONVERSE GUARD IS THE HALF PEOPLE FORGET.** *"A setting with no line
in the preview is a setting that does nothing"* must not be read backwards. A
line in the preview is **not** a promise that the setting takes effect: `units`
is read after the circuit is loaded, the deck slot still carries the
`.options units=degrees` card this tree writes today, and that card is measured
on both binaries to leave the phase in **RADIANS** — the 57.2958× error. Row
**PV4** asserts the line is shown **and** a note says it will not arrive.

---

## Corrections, C123 onwards

Continuing the C series — **C100–C122 were issues 1437 and 1439**.

### C123 — `PLAN.md` §7c-5's badge would have asserted a measurement nobody had taken, and three of the rows are measured false

The headline. §7c asks for the badge on *"every `results 1` row"* and 1437
shipped `results` **0/247 verified**. Measured on both binaries: `warn` and
`maxwarns` are SOA **printers** — 0→5 and 5→2 messages with every printed value
byte-identical — and `num_threads` is an OpenMP thread count that changes no
number at 1 against the default. ⚠ **`evidence/hidden-vars.md` §2.1's own R/P
column already marks all three `P`.** The catalogue transcribed the SECTION
(*"Group R — the 21 that change numerical results"*) and not the column inside
it, so a table that was right produced a row that was wrong. **When a source
table has a per-row verdict AND a section title, the row wins.**

### C124 — §7c-3 says "the eleven categories"; the catalogue ships fifteen, and one of them is not a category

`evidence/hidden-vars.md` §7 has ten function sections plus §7.11's inert list
(which is the `inert` column, correctly, not a group). The shipped catalogue had
**fifteen** groups. Fourteen of them are functions; the fifteenth, **`numerics`,
was the `results` column wearing a group's clothes** — its 20 members were
exactly the `results`-carrying `cp_getvar` rows.

That is a category error with a user cost: **`sqrnoise` belongs in the drawer
someone opens looking for noise output**, not in a drawer named after a property
the ⚠ badge already carries, and a user who does not already know an option
changes numbers cannot find it in a drawer named for that. All 20 were re-filed
into the function category §7 itself places them in (row **GR5** names ten of
them), `scale` and `wnflag` moved from `netlist` to §7.5's `device`, and the
group count is **14**.

### C125 — and `group` is **not** verifiable against its own source: 114 of 205 taggable rows disagree

Cross-checked mechanically against §7.1–§7.10. **114 of 205 differ.** Most of the
gap is one dossier bucket: §7.8 *"Output and formatting"* is a 100-name list the
catalogue splits into `output`, `display`, `postproc`, `run` and `diagnostics`,
which is a **better** GUI grouping and not an error. ⚠ **So `group` stays
0/247 verified and this receipt says so** rather than quoting the 91 agreements
as if they were a measurement. It is safe to be wrong about because a wrong
drawer costs a click and the search does not read drawers only — row **FN4** is
what says the group is searchable, so a misfiled row is still findable by its
function word.

### C126 — §7c-2's reason for the changed-only view is wrong in the direction that hides a real change

`PLAN.md`: *"It is a **filter**, not a feature, **because the catalogue carries
`default`**."* The catalogue's `default` is not what makes it safe — **storage**
is.

`gminsteps` defaults to **1**. A bench that stores `gminsteps 1` would vanish
from a view filtered on `default`. So a **wrong** default hides a row the user
typed — which is §7a's own `gminsteps` note (*"a wrong default makes a shipped
value read as changed, which is exactly how a real change gets hidden"*)
**pointing the other way, and worse**, because the user cannot see what is
missing. What shipped: every stored row is in the view, and `default` decides the
**annotation**. Row **CH2** is the assertion and **CH3** the four verdicts.

### C127 — and the `default` column can answer for only 65 of 247 rows

Counted over the shipped catalogue. Block A's 57 `OPTtbl` keywords carry
`CKTnewTask()`'s defaults (54 of them — `minbreak`, `maxopalter` and `maxevtiter`
have none, which the brief asked about); most of block B does not. So for **73%
of the catalogue the comparison the plan builds the view on cannot be made at
all**, and the honest verdict is a fourth value, `nodefault`, shown and said
rather than guessed. Row **CH4** pins the three block-A rows specifically: they
are what the brief asked *"find out what the other three do to this view"*, and
the answer is that they are shown with the comparison declared impossible.

### C128 — `scope` cross-checks CLEAN, and recording that is not decoration

Of the catalogue's analysis-scoped rows, `evidence/options.md` §10.2 names the
**same analysis set for every one it lists — zero set-level disagreements over 27
shared rows**. Two rows moved (`dyngmin` → `{analysis op}`, `chgtol` →
`{analysis tran}`, both as §10.2 lists them); the seven rows §10.2 files under
*"Any with XSPICE A-devices"* stay `global`, because that is a **device**
condition and there is no analysis called `xspice` to scope them to — §7g's
`gated`/`requires` machinery is where a device condition belongs, and that is
task 4's.

⚠ **Nine stages of refutations make the next reader distrust every column
uniformly, which is its own failure mode.** This one held.

### C129 — an option shown in the wrong scope cannot be worse than one not shown, because nothing here can hide one

§7c says *"an option shown in the wrong scope is worse than one not shown"*, and
that failure needs a scope that can **hide**. `ase::opt_in_scope` answers 1 for
**every** row on the global surface, unconditionally (row **SC1**, over the whole
catalogue). So a wrong `scope` costs a shortcut on one analysis's short list and
never costs the option, which is the mitigation a transcribed column needs and is
cheaper than verifying 247 rows against a document that cannot settle them.

### C130 — `units` had no help text, and it is the option this batch cares most about

1437's receipt mints **five** help sentences ASE-L wrote — `savecurrents`,
`seed`, `seedinfo`, `soa_log`, `units`. Four are in the shipped catalogue.
`units` is not, so the row whose whole reason for existing is the **57.2958×**
phase error (1437's own C104: *"the single most consequential option in this
batch"*) had nothing on its detail line but a badge. It has a sentence now, and
row **FN10** keeps it. ⚠ **The same shape as C120**: a claim that was made,
survived review, and was lost in transcription — this time in the receipt's own
list of what it had minted.

### C131 — and the search leans on name and group, because only 64 of 247 rows have a sentence to search

1437 deliberately did not mint 190 new help lines (⚖ R9 — they would be the
user's to ratify), and that stands. The consequence for §7c-1 is measurable:
*"one entry filtering name, group and help"* filters on **help** for a quarter of
the catalogue. Row **FN11** records the shape. It is the strongest argument in the
batch for spending a ratification round on help text.

### C132 — `-D` still cannot deliver a `CP_REAL`, measured on a row nobody had used it on

Probing `diode_cj0` and `diode_rser` for the badge: `-D diode_cj0=10p` and
`-D diode_rser=100` under `ngbehavior=ps` change **nothing** on either binary,
while the same values in the run-directory start-up file move the AC imaginary
part from 0 to 1.066292e-04 and `i(vb)` by a factor of ten. That is T5 and
`ase::opt_door`'s `predeck` / `predeck-file` split, confirmed on two rows 1437
and 1439 never used as examples.

### C133 — my own probe harness hit the vacuity defect, in a measurement rather than a row

The first nine `results` probes all reported SAME on both binaries — because the
extractor's `grep -E` bracket expression matched nothing and **both files were
empty**. *A fixture whose two sides never disagree cannot fail*, the **eighteenth**
time in this batch and the first outside a test row. The fix was the one the brief
names: the comparator now **asserts the baseline has all nine values before it
compares**, and reports `VACUOUS-BASE(n)` rather than `SAME`. ⚠ **A measurement
needs a positive control exactly as a test row does**, and "no difference" is the
answer that looks the same whether you measured or not.

---

## THE SABOTAGE CAMPAIGN

**Forty-four respellings**, each a plausible rewrite rather than a break — the
tidy-up somebody would actually make — and **twelve of them reproduce a claim
`PLAN.md`, a dossier or this tree's own code actually makes**: S05 and S06
(`ase::ui::combo_filter`'s prefix match and its fall-back-to-everything, the
idiom §7c-1 says to generalise), S09 (§7c-2's *"a filter, because the catalogue
carries `default`"*), S18 and S32 (the catalogue as the authority), S28 (the
emitter's own loop as issue 1439 left it), S29 (`hidden-vars.md` §2.1's *"Group
R — the 21 that change numerical results"*), S30 (1437's `numerics` drawer), S31
(the transcribed `global` scope), S33 (the shipped `units` row with no help),
S35 (the dossier still listing the refuted rows) and S44 (opening Global always).

Restore was `cp` from `/tmp/s7t3/sab/good_ase.tcl` and `good_win.tcl` with an
**md5 compare after every application**, the campaign **aborts on a restore
mismatch** rather than continuing, anchor uniqueness was checked against the
pristine files **before** each campaign started (44/44 unique, both times), and
**no source file was edited while a campaign was live**. Every application ran
**four** suites: `test_ase_optsheet_1441` on the **display arm** (so section UI
is in the blast radius), then `test_ase_options_1437`, `test_ase_predeck_1439`
and `test_ase_core` headless — the last two because `render_deck` and the shared
option body are in the radius.

**Eighty-eight applications in all** — 44 on the first tree and 44 again on the
final tree — **88/88 restored, ZERO KILLS**, and on the final tree **44/44 redden
at least one NAMED row with ZERO SURVIVORS**.

| # | the respelling | rows reddened |
|---|---|---|
| S01 | opt_results: a row that claims results is believed, as the transcription shipped it | RB3 RB5 RB8 UI7 |
| S02 | opt_results: a row carrying an evidence key is measured, whichever way the measurement went | RB2 RB5 RB8 UI7 |
| S03 | opt_in_scope: the global surface shows only the global rows, so every sheet is filtered | SC1 FN7 CH1 CH2 UI0 |
| S04 | opt_scope: a row that declares no scope is offered nowhere rather than everywhere | SC6 |
| S05 | opt_match: prefix match, exactly as `ase::ui::combo_filter` does it | FN3 FN5 |
| S06 | opt_browse: a needle that matches nothing falls back to the whole list, as combo_filter does | FN6 |
| S07 | opt_match: search the name only -- the group and the help are not the option | FN3 FN4 FN5 FN7 FN8 FN10 |
| S08 | opt_match: case-sensitive, so the user gets what they typed | FN5 |
| S09 | opt_browse: the changed view filters on the default column, exactly as PLAN.md §7c-2 says | CH1 CH2 CH7 UI4 UI21 |
| S10 | opt_browse: the changed view is sorted by name, like every other list in the sheet | CH1 CH7 UI4 |
| S11 | opt_browse: a stored name the catalogue does not describe is dropped from the sheet | CH1 CH7 CH8 |
| S12 | opt_browse: the scope filter applies to an unknown stored name too | CH7 CH8 |
| S13 | opt_stored_verdict: a row with no known default is unchanged | CH3 CH4 |
| S14 | opt_stored_verdict: a row the bench does not store is `nodefault` — **survived pass 1**; reddens after the row below was written | CH9 |
| S15 | opt_group: a row with no group answers empty rather than inventing a drawer | GR2 |
| S16 | opt_group_index: keep the catalogue order -- it is already meaningful | GR3 |
| S17 | opt_deck_plan: a pre-deck option gets its deck card too, belt and braces | DP2 PV2 1439/RD9 1439/RD13 |
| S18 | opt_deck_plan: an option the catalogue does not know is dropped | DP1 DP2 DP5 1439/RD7 |
| S19 | opt_fallback_line: core spells the last resort itself, saving a hook nobody else needs | DP5 DP5b HK1 |
| S20 | option_fallback: a value of 0 writes the card too | DP4 1439/RD7 |
| S21 | opt_fallback_line: a backend with no hook falls back to the one spelling there is | DP5b HK1 |
| S22 | opt_preview: the deck slot is spelled here, so the pane reads the same however the emitter changes | PV2b HK1 |
| S23 | opt_preview: an option that has a line does not also need a complaint | PV2 PV4 UI15 UI19 |
| S24 | opt_preview: a switched-off option is not a problem, so it gets no note | PV5 |
| S25 | opt_preview: every reader gets its say -- one note per opinion, not per option | PV9 |
| S26 | opt_preview: show the start-up file lines even where the file is refused — **survived pass 1**; reddens after the row below was written | **PV10** |
| S27 | opt_preview: the analysis-block slot shows the run-door rows, which is where they belong | PV7 |
| S28 | render_deck: the emitter keeps its own copy of the loop, as issue 1439 left it | 1437/BR6 |
| S29 | catalogue: warn changes results after all, as the dossier Group R lists it | RB2 RB8 UI7 |
| S30 | catalogue: sqrnoise goes back in the numerics drawer | GR4 GR5 |
| S31 | catalogue: dyngmin is global again | SC5 |
| S32 | catalogue: sqrnoise keeps its measurement text and loses the evidence key | RB1 RB8 UI7 UI20 |
| S33 | catalogue: units loses its help line again, as the shipped row had it | FN10 UI18b |
| S34 | optsheet_badge: an unverified row gets the plain badge -- the hedge only confuses | UI7 |
| S35 | optsheet_badge: a refuted row is badged too, because the dossier still lists it | UI6 UI7 |
| S36 | optsheet_fill: the sheet opens on the whole catalogue | UI4 UI8 UI21 |
| S37 | optsheet_row: every row is keyed by name, which is tidier than an index | UI4 UI0 |
| S38 | optsheet_fill: show-all is a flat list -- the group rows only cost clicks | UI10 UI0 |
| S39 | optsheet_fill: the preview is painted at open, not on every keystroke | UI14 UI15 UI16 UI17 UI19 |
| S40 | listdlg_fill: one painter for both list dialogs -- the cfg hook is indirection for its own sake | UI19 UI20 |
| S41 | optsheet_preview: an empty slot needs no line of its own | UI16 |
| S42 | optsheet_preview: the notes belong on the detail line, not in the deck preview | UI17 |
| S43 | chana_options: the per-analysis sheet is its own window | UI23 UI24 |
| S44 | sim_options_dialog: the sheet always opens Global | UI23 |

### ⚠ TWO SURVIVED PASS 1, AND THEY ARE TWO DIFFERENT SHAPES

*A row whose fixtures never disagree cannot fail* — the **nineteenth** and
twentieth times in this batch. Neither was fixed by deleting a line.

| survivor | why nothing moved | the row written for it |
|---|---|---|
| **S14** — `ase::opt_stored_verdict`'s unstored-row branch answers `nodefault` instead of `unset` | **every fixture asked about a row the bench STORES.** The branch is what the **Show-all** view hits for the ~240 rows nobody has touched — and `nodefault` is a *wrong sentence* there, not a harmless one: 65 of those rows DO have a default and are simply not set. The verdict is now four-valued plus `unset`, and the detail line draws nothing for it | **CH9** — an unstored row with a default, one without, and one the catalogue has never heard of |
| **S26** — `ase::opt_preview` drops the `filewhy` guard and shows the start-up file lines anyway | ⚠ **the guard was UNREACHABLE THROUGH THE PUBLIC API.** `ase::predeck_plan` applies the file refusal **per option inside its own loop**, so it never returns `file` lines and a `filewhy` at once — a preview that computes its own plan can never exercise the guard. Deleting the line would have removed defence against a change in another proc | **PV10** — `ase::opt_preview` now takes the plan (as `ase::predeck_report` already does) and the row hands it the one state that loop cannot produce today: lines to write **and** a reason not to. **PV11** is its non-vacuity half |

⚠ **S26 IS THE ONE TO REMEMBER, AND IT IS A NEW SHAPE FOR THIS BATCH.** The
other nineteen survivors were fixtures that never built a state, or a row that
asked the wrong question. This one was a guard **no caller could reach**, because
the proc that feeds it never produces the input that trips it. **A defensive
clause against another proc's future is untestable while that proc is its only
caller** — and the fix is not to delete it and not to fake it, but to let the
caller pass the input, which is a shape this file already had.

### ⚠ AND TWO MORE OF THE SAME SHAPE, CAUGHT BY COMPARING THE TWO CAMPAIGNS

Neither survived — both reddened a named row — but the row they reddened was
about the **wrong thing**, which the brief names as the sharper variant, and the
two passes disagreeing is what exposed them:

* **S21** — `ase::opt_fallback_line`'s *"a backend with no hook falls back to the
  one spelling there is"* — reddened only **HK1**, the lexical *no ngspice
  literal in core* row. ⚠ It reddens that because the sabotage writes
  `ase::backend::ngspice::` into a core proc, **not** because the fallback
  behaved wrongly. The reason: `ase::backend_hook` **RAISES** for a hook a
  backend does not declare, so the `catch` answers first and the `$h eq {}` line
  below it is reachable only by a backend that **declares the hook and leaves it
  empty** — a state no fixture had built, and the same defensive idiom
  `ase::sim_options`, `ase::sim_option_spell` and `ase::predeck_deliver` all use.
  Row **DP5b** builds it.
* **S22** — *"the deck slot is spelled here, so the pane reads the same however
  the emitter changes"* — replaced the preview's line with a generic
  `.options <name>=<value>`, and **every row of the fixture spells exactly that**,
  so PV2 did not move. A **flag** is what separates them: `sqrnoise` emits the
  valueless `.options sqrnoise`, measured on both binaries to square the noise
  where `.options sqrnoise=1` leaves it alone — so a preview composing its own
  line would show the user **the spelling that silently turns the option off**.
  Row **PV2b** is that bench.

⚠ **The tell in both cases was a row list that differed between two runs of the
same campaign** — a sabotage whose reddened set moves is a sabotage that is
reaching a row by accident. Running the campaign twice is not redundancy.

### ⚠ AND THREE SABOTAGES ABORTED SECTION UI RATHER THAN ONLY REDDENING ROWS

S03, S37 and S38 each reddened **at least one named row** *and* also tripped
`UI0`, the section's own catch-all. That is still an acceptance — a named row
moved — but it is worth saying plainly: a sabotage that makes a widget path
vanish takes the rest of the section with it, so the row list for those three is
a **lower bound**. The named rows are what the acceptance rests on.

---

## Suites moved, before → after

| suite | headless | display (`:99`) | in T1? |
|---|---|---|---|
| **`test_ase_optsheet_1441`** (new) | — → **62** | — → **87** | **yes, BOTH ARMS** — added to `tests/run_regression.tcl`'s `hcases` **and** `dcases` in this change |
| `test_ase_options_1437` | **75 → 75**, one row re-baselined (BR6) | **75 → 75** | yes (already) |
| `test_ase_predeck_1439` | 78 → **78** | 78 → **78** | yes (already) |
| `test_ase_core` | 598 → **598** | 598 → **598** | yes |
| `test_ase_dialogs` | 37 → **37** | 299 passed / **1 FAILED** — issue **1436**, unchanged | yes (headless arm only) |
| `test_ase_simreg_0931` | 117 → **117** | 117 → **117** | yes |
| `test_ase_simdlg_0937` | 5 → **5** | 55 → **55** | yes |
| `test_ase_preflight` | 235 → **235** | 235 → **235** | yes |
| `test_ase_persist` | 44 → **44** | 148 → **148** | yes |
| `test_ase_simcaps_0948` | 199 → **199** | 199 → **199** | yes |
| `test_ase_optier_0963` | 108 → **108** | **not re-measured this pass** — issue **1440**, pre-existing, and T1 runs this file headless only | yes (headless arm only) |
| `test_cosim_golden_e2e` | 45 passed / **1 FAILED** — issue **1431**, unchanged | — | **no** |
| every other ASE suite | unmoved | — | — |

**The one re-baselined row, with the reason that moved it:**

| row | before → after | why |
|---|---|---|
| **BR6** | one lexical grep over `render_deck` → three, over `render_deck`, `ase::opt_deck_plan` and `ase::backend::ngspice::option_fallback` | the claim is **unchanged** — *"the loop goes through the one speller and the bare card survives only as the fallback"* — and only where the body lives moved. The row now also asserts `render_deck` no longer spells `.options` for an option row at all, which the old form could not say |

**NO DECK GOLDEN MOVED AND NO `.state` FILE MOVED.** `render_deck`'s output is
byte-unchanged (rows **DP6**/**DP7**, and `test_ase_core` **598 unmoved** with its
D-section goldens and its section **CP** — the row that would notice a byte in the
104 committed `.state` files — green). No state key was added,
`ase::state_default` still seeds exactly four rows, there is no `seed_enabled`
anywhere, `op` is still last in emit order, and the print anchor (1243), the
plotmap record (1430), the checkpoint block (1433), the `.save all` leader (1434)
and 1439's door consultation are all where they were.

### ⚠ The three results that are NOT this change

* **`test_ase_dialogs` G2sens.** Issue **1436**, filed by the 1435 crew and not
  fixed. The actual value here — `{1 1 0 1 0 Entry Entry normal}` against
  `{1 1 0 0 0 Entry Entry normal}` — is **byte-identical to 1436's transcript**
  and to the one the 1439 crew reported. T1 runs this file's **headless** arm
  only, where it is ALL PASS (37). ⚠ **And G6 and GE9, the two legs that drive
  `Simulation > Options…`, are in the 299 that PASS** — which is the measurement
  that says this change did not move a gesture the tree already had.
* **`test_ase_optier_0963` display arm.** Issue **1440**, three measurements, rc
  124 at ~260 s, stops after row N3. ⚠ **This crew did NOT re-measure it** — it is
  named as the known exception the brief says it is, and nothing in this change
  touches the option-tier code it exercises. Its **headless** arm, which is the
  one T1 runs, is **ALL PASS (108)** here.
* **`test_cosim_golden_e2e` GE24, headless.** Issue **1431**, the one-timestep
  VCD boundary, 45 passed / 1 failed, unchanged and **not in T1**. Named here
  because the whole ASE family was run and a reader of that list would otherwise
  wonder.

⚠ **Everything else is green on BOTH arms**: the twelve-suite headless run is
11/12 (the twelfth being 1431) and the ten-suite display run is 9/10 (the tenth
being 1436).

---

## What I did NOT ship, and why

* **§7e's emit-then-restore, §7f's `option`/`set` read-back, §7g's four
  `caps`-reading rules** — task 4. In particular **nothing is written inside the
  analysis block**, so the preview's `control` slot is empty and row **PV7** says
  so *as a fact* rather than leaving it as a placeholder. It is measured on a
  state that WOULD put a line there if anything did (`units` is a `run`-phase row
  whose only working door is the block), so the day §7e fills it the row says so.
* **Any change to what `render_deck` emits.** The loop moved; the output did not.
  The `control`-door rows still take the deck-slot fallback card — `.options
  units=degrees`, measured to leave the phase in RADIANS — and the preview now
  **shows that line and says it will not arrive**, which is the most §7c can do
  without §7e's emission point.
* **A re-taxonomy of all 247 `group` values.** 114 disagree with the document they
  were transcribed from and most of that gap is an improvement (C125). Churning
  245 rows of adapter content on no measurement would be the opposite of this
  batch's discipline. The one **category error** was fixed and nothing else.
* **`help` text for the 183 rows that have none.** ⚖ R9 — task 1's reason stands
  and 190 unratified sentences would be the largest copy drop in the batch. One
  sentence was minted, for `units`, because the row had been **promised** by task
  1's own receipt and lost (C130).
* **Any measurement of the ten unverified `results` rows.** They need
  event-driven XSPICE, A-devices, a PDK library or a circuit shape this probe set
  could not build. They are labelled `unverified` **on the surface**, and
  `ase::opt_results_why` carries the reason each one could not be taken, so the
  next crew starts from what was tried rather than from nothing.
* **`optran` and the guided-remedy assistant** (`evidence/options.md` §10.3).
  Convergence aids are offered here as ordinary catalogue rows in the
  `convergence` drawer; the *"Simulation failed — try this"* ladder is Stage 10's.

---

## What this task learned that binds later stages

**A SOURCE TABLE CAN HAVE A PER-ROW VERDICT AND A SECTION TITLE THAT DISAGREE,
AND THE TRANSCRIPTION WILL TAKE THE TITLE.** `hidden-vars.md` §2.1 is headed
*"Group R — the 21 that change numerical results"* and its own **R/P column marks
four of those 21 `P`**. The catalogue took the heading. ⚠ **When a dossier
section has a column that grades its own rows, the column is the claim and the
heading is a label** — and the difference is exactly the size of a badge.

**A MEASUREMENT NEEDS A POSITIVE CONTROL AS MUCH AS A TEST ROW DOES.** The first
nine `results` probes all said "no difference" because the extractor matched
nothing and both sides were empty (C133). *"No difference"* looks identical
whether you measured or not, and an option measured not to change anything is
exactly the answer that removes a badge. ⚠ **Before believing a null result, prove
the mechanism fired** — the `warn` row is 0→5 SOA messages, and without that
number the "no change" is worthless.

**A DEFENSIVE CLAUSE AGAINST ANOTHER PROC'S FUTURE IS UNTESTABLE WHILE THAT PROC
IS ITS ONLY CALLER.** S26. The fix is neither to delete it nor to fake it: let
the caller pass the input, which `ase::predeck_report` had already shown was the
shape. ⚠ **If a guard cannot be reached, the API is wrong before the test is.**

**STORAGE, NOT A DEFAULT COLUMN, IS WHAT MAKES A "CHANGED ONLY" VIEW SAFE.** A
default is a claim about the simulator and it can be wrong; whether the user
typed something is a fact about the file. ⚠ **Filter on the fact and annotate with
the claim**, never the other way round — the plan had it the other way round, and
its own `gminsteps` note is the proof (C126).

**AND A GUI COLUMN CANNOT BE "VERIFIED" THE WAY A SIMULATOR COLUMN CAN.**
`cptype` has a right answer in C source. `group` does not: it is a drawer, and
the only check available is against the document it came from — which disagrees
114 times, mostly because the catalogue is better. ⚠ **So the honest move for a
GUI column is not verification but a design in which being wrong is cheap**: the
global surface shows everything (a wrong `scope` costs a shortcut), and the
search reads the group (a wrong `group` costs a click). **Say which of the two
you did, and never let a GUI column carry an assertion the user will act on
without a measurement behind it** — which is the whole of the badge.

---

## Rulings

⚖ **R9 — new user-facing copy, filed as `owed.sh add rule 1441`** at the moment
it was incurred, pointing at `doc/claude/issues/1441-*.md`:

1. the **two badge phrases** — `⚠ CHANGES RESULTS` and
   `⚠ MAY CHANGE RESULTS — UNVERIFIED`. ⚠ **The second is the one that needs a
   ruling most**: it tells the user ASE-L does not know, which is honest and is
   also a sentence nobody has ever had to read in this GUI;
2. the **four deck-preview slot labels** — *above the analysis block*, *inside the
   analysis block*, *on the command line*, *in the run-directory start-up file* —
   plus `(nothing)` and `not delivered`;
3. the **four column headings** — Name, Value, Results, Written — and the four
   `Written` words: `DECK`, `ANALYSIS BLOCK`, `COMMAND LINE`, `START-UP FILE`,
   plus `NO DOOR`;
4. the **detail line's phrases** — `NOT OFFERED:`, `SET ELSEWHERE:`, `CLAMPED:`,
   `CAVEAT:`, *CHANGED from the default N*, *SET to this simulator's own
   default*, *SET; this simulator declares no default to compare with*, *SET;
   this simulator's catalogue has no such option*;
5. the **finder bar's labels** — `Find:`, `Show all`, `Scope:`, the `Global`
   scope word — and the `Simulator Options…` button on the analysis form;
6. **one new help sentence**, for `units`: *"angle unit for vp() and ph().
   RADIANS by default -- a phase margin computed without it is wrong by
   57.2958x"* (C130).

**Batch with 1426, 1427, 1428, 1429, 1430, 1432, 1433, 1434, 1435, 1437 and
1439, which are all still waiting.**

⚠ **AND A `look` DEBT IS FILED — `owed.sh add look ase_options_sheet_1441`.**
This is the plan's own *"largest new pane"*. **The suites are green on both arms
and the deliverable is NOT done**: it is *"suites green, please look"*, and it
clears only when the user says so. The two things the eyes are for, and which no
row can answer: whether the sheet reads as **one surface** at real font sizes
with a finder bar, a grouped tree, a detail line and a preview pane stacked in
one window; and whether the **three-valued badge reads as three states** rather
than as noise in a column.

⚖ R2 is **answered** (yes, four conditions) and its file half is what the
preview's `prefile` slot draws. ⚖ R3 is **answered** (Option C). ⚖ **R4 is open
and nothing here is gated on it** — nothing was seeded, no state key was added
and there is no `seed_enabled` anywhere.

⚠ **THE LEDGER WAS BACKED UP FIRST**, per `CLAUDE.md`'s one-ledger-every-clone
paragraph, to `/tmp/s7t3/owed_backup/xschem_owed` (**158 rule / 57 look / 9
suite** at the time); after the two adds it reads **159 / 58 / 9**. ⚠ **The rule
count was 157 when task 2 finished and was 158 before this task's add**, so
another writer added one in between — reported, not touched. Measured
immediately before the adds: `/usr/bin/grep -L '^repo:'` over the three
directories prints the **same four unstamped entries** issues 1430–1439 have each
reported (`rule/1357`, `rule/1357@xschem-claude`,
`look/hier_pdf_nav_1357_H6.1789071932.2875683`,
`suite/test_hier_pdf_links_1333`), and the stamp split is **207 this clone / 13
op-wcard** before the adds and **209 / 13** after. ⚠ The op-wcard count has now
been **13 across eight receipts** while this clone's has moved
197 → 199 → 200 → 202 → 204 → 205 → 206 → 207 → **209**.

---

## For the driver

* **T1 was NOT run by this crew** (issue 0990 — the driver runs it solo). ⚠ **T1's
  membership changed in this commit, on BOTH arms**:
  `tests/run_regression.tcl`'s `hcases` gains `headless/test_ase_optsheet_1441`
  (**+62**) and — unlike the three ASE suites issue 1413 added — its **`dcases`
  gains the same suite** (**+87**), so T1 now runs **149 more checks** than it did
  at `58499849`. The `dcases` comment asks for the wall-clock cost before a
  `test_ase_*` suite joins that list; it is recorded in the file itself:
  **0.40 s on the display arm against 0.10 s headless**, measured 2026-09-13.
  Nothing else in that file moved.
* **Nothing was committed, added, stashed, restored, cleaned or pushed.** No
  `git checkout --`, no `git restore`, no `git stash`, no `git clean`, no
  `git commit`, no `git push`, no PR. The working tree is the one handed over
  plus **five modified files** (`src/ase.tcl`, `src/ase_window.tcl`,
  `tests/headless/test_ase_options_1437.tcl`, `tests/run_regression.tcl`,
  `doc/claude/issues/NUMBERING.md`) and **three new ones**
  (`tests/headless/test_ase_optsheet_1441.tcl`, the issue file, this receipt).
  The four untracked paths inherited at `58499849` — `.xschem/`,
  `doc/claude/rdw_lists_batch/`, `doc/claude/rdw_sim_batch/`,
  `sky130A/.../debug_st1/` — are untouched.
* **`NUMBERING.md`'s pointer was advanced 1441 → 1442** in the same change as the
  entry. **Both mint checks were run at the moment of minting**: the
  reserved-band scan over this clone's head table (**silent** for 1441) and
  `ls ~/dev/*/doc/claude/issues/1441-*` plus `/usr/bin/grep -lw 1441` across
  **every** clone's `NUMBERING.md` (`~/dev/xschem-claude` and
  `~/dev/xschem-op-wcard`, the glob verified non-empty) — only this clone's own
  pointer line came back.
* ⚠ **THE THREE UNVERIFIED COLUMNS — WHAT WAS DONE, PER COLUMN.** The brief said
  it would check this specifically:
  * **`results`** — **MEASURED**, all 22 rows, both binaries, each with its own
    mechanism made to fire. 9 confirmed, **3 refuted**, 10 could not be made to
    fire and are labelled `unverified` **on the surface itself**. The badge now
    asserts a measurement where there is one and says *"UNVERIFIED"* where there
    is not. **No row draws an authoritative badge on a transcription.**
  * **`scope`** — **CROSS-CHECKED against its source document**, zero set-level
    disagreements over 27 shared rows, two rows corrected. It cannot be
    *measured* (there is nothing in ngspice to measure a GUI surface against), so
    the design carries the risk instead: the **global surface offers every row**,
    and a wrong scope costs a shortcut, never an option.
  * **`group`** — **STILL 0/247 VERIFIED, AND SAID SO.** 114 of 205 taggable rows
    disagree with the document they came from, mostly because the catalogue's
    taxonomy is better. One **category error** was fixed (`numerics`), the search
    reads the group so a misfiled row is still findable, and the receipt does not
    quote the 91 agreements as if they were a measurement.
* ⚠ **NO SIMULATOR IS STARTED BY THE FEATURE, BUT ~60 PROBE RUNS WERE MADE TO
  BUILD IT, ON BOTH BINARIES.** The sheet is Tcl and string substitution; nothing
  in it starts a program. Every probe ran on a scratch deck under
  `/tmp/s7t3/probe` with that directory as its own cwd. **No bench under
  `sky130A/` was run** and no simulation touched `~/.xschem/`.
* ⚠⚠ **`$HOME/.spiceinit` WAS NEVER WRITTEN, MOVED, BACKED UP OR READ.** There is
  none (`ls -la ~/.spiceinit` → *No such file or directory*, `SPICE_USERINIT_DIR`
  unset, measured at the start). The two `diode_*` probes needed a
  run-directory start-up file; it was created at
  **`/tmp/s7t3/probe/.spiceinit`**, with that directory as cwd, and **deleted
  immediately afterwards**.
* **Machine rules honoured throughout**: every xschem invocation was given a path
  (`./src/xschem` or `tests/headless/devdisplay.sh exec ./src/xschem`) and
  `--nolog`, never `--logdir`, never a bare `xschem`; every bespoke command
  carried a `timeout` and every waiting loop a deadline; **a stall was a named
  outcome** (the campaign runner reports `TIMEOUT/<suite>` and `NORESULT/<suite>`
  as verdicts and neither occurred); `tests/run_regression.tcl` was not run;
  nothing was `pkill`ed.
* ⚠ **`~/.xschem/geometry` WILL HAVE BEEN WRITTEN AGAIN** by the display arm —
  issue **1397**, already on the user's queue and already reported by the 1430,
  1432, 1433, 1434, 1435, 1437 and 1439 crews. Every headless invocation carried
  `--nogui`. The repo's own `.xschem/op_param_lists.conf` is unmodified.
* ⚠ **AND NOTHING HERE CALLS `ase::sim_register`.** The new suite clears the
  in-memory registry at the top with `ase::sim_clear`, which writes nothing — the
  same guard issue 1439's suite needed, and for the same measured reason: the
  developer's own saved entry can carry `-n`, which changes what the pre-deck
  half of the preview reports.
* **No file was created in the repo root**, and `git status` carries no stray.
* **The next task is 4 of 4 — `PLAN.md` §7e + §7f + §7g.** It inherits:
  `ase::opt_restore_line` exists and is the speller applied to the default
  (task 1) and **where it is called is §7e's**; the preview's `control` slot is
  the place §7e's lines go, and row **PV7** asserts it is empty **today**, so
  filling it moves a named row rather than passing silently; `ase::opt_preview`
  already takes a plan, which is the shape §7f's *requested vs effective* diff
  will want; and `ase::opt_results`' three-valued answer is what a §7g `gated`
  row's *"listed and disabled with the reason"* rendering should copy rather than
  re-derive. ⚠ **And the `control`-door rows still take the deck-slot fallback
  card** — `.options units=degrees`, measured on both binaries to leave the phase
  in **RADIANS**. The preview shows that line **and** says it will not arrive
  (row PV4); §7e is what makes it arrive.
