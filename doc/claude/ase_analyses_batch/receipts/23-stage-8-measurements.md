# Stage 8 task 1 — measurements, and the producers nobody could ask for (§8a + §8c)

**One commit, issue 1443, and the FIRST of Stage 8's two tasks.** Scope was
`PLAN.md` **§8a + §8c** and nothing else; **§8b — the eight named templates, the
Measurements sub-dialog, the template picker and the Value-column rows — is task
2 and no widget was built here.**

**Floor:** new suite `test_ase_meas_1443` — **100 checks, identical on both arms**
— registered in `tests/run_regression.tcl`'s **`hcases` only**, deliberately not
in `dcases`, and the file says why: task 1 is the deck half and creates no widget
at all.

**`src/ase.tcl` 21794 → 22978** (+1184). Four new optional adapter hooks,
thirty-one new `ase::meas_*` procs, one new state key, one new sidecar.
**`src/ase_window.tcl` is UNTOUCHED.**

---

## ⚠ THE HEADLINE: THE BRIEF'S OWN LOAD-BEARING FACT WAS WRONG, AND THE FIX IS BETTER FOR IT

The brief's checkpoint 1 says *"`units` is **not one of the 247 catalogue rows**
at all — neither an `OPTtbl` keyword nor a `cp_getvar` name"*, and `LEDGER.md`'s
Stage 8 block says the same. **Counted live 2026-09-13 over the shipped
catalogue: it is one of them.** Issue 1437 added it, with `cptype string`,
`phase run`, `group output`, `default radians`, `values {radians degrees}`,
`ngphase C`, and a `help` string that already carries the 57.2958 sentence.

```
ase::opt_door         ngspice units control  ->  control
ase::opt_line         ngspice units degrees control  ->  set units=degrees
ase::opt_restore_line ngspice units control          ->  set units=radians
ase::opt_line         ngspice units degrees deck     ->  RAISES
```

So the auto-emission is **`ase::opt_line`'s answer**, not a new adapter literal.
The line the deck carries and the line the options sheet would write for the same
option are the same line **by construction**, and a second adapter that describes
its own phase-unit option gets the behaviour for free. Rows **PH3** (the two
strings agree), **PH3b** (it really is in the catalogue) and **PH3c** (the
emitter *calls* the speller and carries no spelling of its own — the row a second
literal that happened to agree would still fail).

The trap itself is re-measured and confirmed, on **both** binaries, through
`meas` rather than through `print`, on an RC whose phase at 1 kHz is exactly −45°:

```
(nothing set)           meas ac p FIND vp(out) AT=1k  ->  -7.853982e-01
.options units=degrees  the same line                 ->  -7.853982e-01
set units=degrees       the same line                 ->  -4.500000e+01
```

**And the non-vacuity control is a row, not a claim.** `PH2`: a measurement with
no phase in it emits **no** units line; `PH2b`: a bench with no measurements emits
none either; `PH4`: the inert `.options units=degrees` card is never written.
Sabotage **S40** (emit it unconditionally) reddens PH2; **S41** (write it as a
card) reddens PH1 and PH4; **S42** (spell it here instead of calling the speller)
reddens PH3c.

---

## ⚠ WHAT I VERIFIED VERSUS WHAT I TRANSCRIBED

| claim | evidence |
|---|---|
| `.options units=degrees` is inert; `set units=degrees` works | **RE-MEASURED on both binaries**, through `meas` and through `print`, on an RC whose phase at 1 kHz is exactly −45° |
| `units` is one of the 247 catalogue rows | **COUNTED LIVE**, with `opt_door`, `opt_line` and `opt_restore_line` all answering. **Refutes the brief and `LEDGER.md`** (C145) |
| trap 3 — `.meas` cards are refused under `-r` | **RE-MEASURED on both binaries**: `No .measure possible in batch mode (-b) with -r rawfile set!`, no measurement, while the `meas` **command** in the same deck still printed its number |
| a dot card ALSO runs the simulation twice | **MEASURED on both binaries**, the same circuit two ways: `Doing analysis at TEMP` twice with a `.four` card beside a `.control` block, once with the `fourier` command (C148) |
| trap 1 — `expr=` is broken | **RE-MEASURED on both binaries**, and it is sharper: on the COMMAND form it does not exist — `no such function as 'expr=7.756162e+00'` |
| trap 2 — `param=` is one-shot per session | **RE-MEASURED**: on the COMMAND form `param=` does not exist either, so the `param` kind ships as a `let` and cannot reach the numparam placeholder at all (C147). `let pm1 = 180 + ok1` → `pm1 = 1.807562e+02`, both binaries |
| trap 4 — `meas … > file` writes something | **MEASURED on both binaries, in ONE deck, with `echo … > f` and `print … > f` as positive controls** — 22 / 31 bytes for the controls, **54 and 66** for the `meas` redirect. The brief asked for exactly this and it passes |
| trap 4's stated REASON is false on apt 45.2 | **MEASURED on both binaries, both routes**: `set measureprec=12` and `NGSPICE_MEAS_PRECISION=12` are accepted and **inert** on 45.2 (`$measureprec` reads back 12, the line does not move), leaving `%.6e` — exactly the vector's precision (C146) |
| a FAILING `meas … > f` truncates the file to zero bytes | **MEASURED on both binaries**, with a successful `meas … > f` in the same deck as the control (C152) |
| the §8c plot literals | **RE-MEASURED on both binaries**: `fft` → `sp2` (`Spectrum`), `psd` → `sp3` (`PSD`), `spec` → `sp4` (`Spectrum`), `linearize` → `tran2` (`Transient Analysis (linearized)`). `fourier` creates **no plot** and leaves `$curplot` alone |
| a producer's plot read back as the analysis it mimics | **MEASURED through this tree's own reader** on a file holding a real transient, a linearized copy made to DISAGREE, and an fft spectrum: `raw read … tran` → `datasets=2`, `raw read … ac` → `datasets=1 sim_type=ac`. **Source-confirmed**: `save.c:957` and `:987` match by substring (C149) |
| a measurement vector in a written plot costs a full-length column | **MEASURED on both binaries**, one 1,000,001-point transient: 48,000,724 bytes with the `fourier` below the write, **64,000,905** above it (C150) |
| a second transform reads the first one's spectrum | **MEASURED on both binaries**: `fft` then `psd` → `Error: fft needs real time scale`, **no plot created**, rc 0 (C151) |
| `meas` and `fourier` leave `$curplot` alone | **MEASURED on both binaries** — `tran1` before and after both |
| the `fourier` counter is run-wide | **MEASURED on both binaries**: first call → `thd11`, second → `thd21` |
| printed measurement names come back lower-cased | **MEASURED on both binaries**: `print thdA` → `thda` |
| `set units=degrees` / `set units=radians` round-trip | **MEASURED on both binaries** in one deck: `-6.283185e-09` → `-3.600000e-07` → `-6.283185e-09` |
| `TD=` is silently ignored by the eight window statistics | **TRANSCRIBED from `evidence/measure.md` §1.4.3** (its `n6`/`n7` pair), not re-measured. It is encoded as an ABSENT FIELD rather than as a refusal, so nothing rests on it beyond which fields the form offers |
| `deriv` and `err` are rejected at run time | **TRANSCRIBED from `evidence/measure.md` §1.4.2** and from `com_measure2.c:2156`. Not re-measured |
| `meas sp` on a real `.sp` run segfaults for WHEN/TRIG/RMS/INTEG | **TRANSCRIBED from `evidence/measure.md` §1.5**, plus a source read of `com_measure2.c:461` and `:1073`. ⚠ **NOT re-measured, deliberately** — the brief forbids a probe that crashes the user's simulator without cause, `sp` is not renderable today so no ASE-L deck can reach it, and the mitigation is a refusal rather than a workaround |
| all 104 committed `.state` files round-trip byte-identically | **COUNTED LIVE**, 104 of 104, immediately after the key was added |

---

## ⚠ THE DRIVER'S FIVE MEASURED FACTS — FOUR CONFIRMED, ONE ANSWERED WITH A NEW ROW

The driver sent five measurements mid-task
(`doc/claude/ase_analyses_batch/evidence/meas-readback.md`). **All five were
already accounted for; none of them corrects this design, and one of them is now
a row that was not there before.**

| # | the driver's fact | how this design already stood |
|---|---|---|
| **1** | `meas` creates a **VECTOR**, not a shell variable; `$name` is empty and says so only on stderr; `print name` is the door | **CONFIRMED.** Nothing here reads a measurement with `$name` or `$&name`. The two readback shapes it emits are `meas … >> <sidecar>` and, for a `fourier` row's THD and a `param` row's expression, `let <name> = …` followed by **`print <name> >> <sidecar>`** — which is fact 1's door, chosen for fact 1's reason. Row **SC2e** parses both shapes through one reader |
| **2** | `meas … > file` writes, where `option > file` writes zero | **CONFIRMED, and independently measured here** — 54 bytes on 45.2 and 66 on the fork, with `echo … > f` (22) and `print … > f` (31) as positive controls **in the same deck**, which is what the brief asked for. This receipt's C152 adds the half the driver's probe did not reach: a `meas` whose measurement **fails** creates the file and leaves it at **zero bytes**, which is why the sidecar is opened by an `echo` that cannot fail and every measurement **appends** |
| **3** | ⚠ the `meas` echo line is **binary-dependent** (six decimals on 45.2, five on the fork); `print` is not | **ACCOUNTED FOR BY CONSTRUCTION, AND NOW ASSERTED.** `ase::meas_parse` takes the value as a **token** (`\\s+(\\S+)`) and every caller compares it as a number; nothing in this change reads a width or a digit count, and no golden contains a simulator-produced number. ⚠ **It was not a ROW until this message arrived**: **SC2d** now parses the driver's two literal spellings of one measurement and asserts they yield the same number and a different tail, and **S68** — a parser rewritten to the fixed column layout the line appears to have — reddens **eight** sidecar rows. This receipt's **C146** is the same fact from the other end: `measureprec` is accepted and **inert** on 45.2, which is *why* the two differ |
| **4** | ⚠ a failed measurement is **silent on every channel the guard can see** — rc 0, `$sim_status` 0, no vector, `print` prints nothing; only a stderr line | **CONFIRMED, and it is the reason the `failed` verdict exists.** `ase::meas_results` detects the failure as **ABSENCE from the sidecar** and says so in words — *"the simulator did not report this measurement: the condition it asks about may never occur in this run"* — rather than leaving a blank cell that reads as zero. Row **SC3**, with **SC3c** as the half that stops a PRODUCER being reported that way. ⚠ And the receipt's own measurement of the same thing records where the simulator's sentence goes: **stdout on apt 45.2, stderr on the fork**, so `2>@1` puts it in the run log either way and task 2 can show the simulator's own words beside the verdict |
| **5** | ⚠ a **deck-card `.measure` never becomes a vector**, so a producer inside `.control` cannot read it back; and a deck with both `.tran` and `.control run` simulates **twice** | **CONFIRMED, and this change emits no dot card at all** — row **DK4** asserts zero `.meas`, `.measure` and `.four` lines in a deck that asks for both a measurement and a Fourier. The double-run half is this receipt's **C148**, measured here on the same day from the other side (`Doing analysis at TEMP` twice with a `.four` card against once with the `fourier` command), and it is why §8c's *"`.four` is a CARD"* is refuted and the card slot ships **empty**. ⚠ Fact 5 adds the reason C148 did not have: the card is not merely expensive, it is **unreadable** — it leaves no vector for anything downstream to use |

⚠ **THE ONE PLACE FACT 3 COULD HAVE CHANGED THE DESIGN, AND WHY IT DID NOT.** If
the sidecar carried `print <name>` for **every** measurement instead of the
redirected `meas` line, it would be byte-identical across binaries. It does not,
for two measured reasons: `print` discards the `at=` / `from=` / `to=` /
`targ=` / `trig=` tail, which is the only place a `when`'s crossing or a
`max`'s location is reported at all; and the parse is width-independent by
construction, so the difference costs nothing. The tail is kept **whole and
opaque** — one of its fields, `avg`'s echoed `to=`, is measured unreliable, so
claiming to understand it would be worse than reporting it.

---

## What shipped — the SCHEMA half (`src/ase.tcl`, `ase::`)

**One new state key.** `measurements`, between `save_op_params` and `options` in
`ase::schema_keys`, defaulting to `{}` and **in `ase::omit_if_empty`** — the fifth
member, joining for the same reason as `cosim`, `save_op_params` and `sim_entry`
and with the same consequence. Counted live at the moment it was added: **104 of
104 committed `.state` files still round-trip byte-identically**, `ase::state_default`
still seeds exactly four analysis rows, and there is no `seed_enabled` anywhere
in the diff.

**Thirty-one procs**, none of which contains a simulator word (section **HK**):

| group | procs |
|---|---|
| the adapter's catalogue, memoised | `meas_cache_clear`, `meas_kinds`, `meas_kind_entry`, `meas_kind_form`, `meas_kind_unsupported`, `meas_kind_yields`, `meas_kind_fields`, `meas_kind_field`, `meas_analyses` |
| the row | `meas_rows`, `meas_enabled`, `meas_name`, `meas_field_value`, `meas_binding`, `meas_on`, `meas_producer_of`, `meas_name_ok` |
| the refusal evaluator | `meas_verdict`, `meas_for`, `meas_fatals`, `meas_armed` |
| emission order | `meas_counter_index` |
| the sidecar | `meas_path`, `meas_marker`, `meas_parse`, `meas_read`, `meas_result`, `meas_results`, `meas_report` |
| the seam | `meas_needs_degrees`, `meas_schema_errors` |

and **nineteen more in the adapter** — `meas_kinds`, `meas_stat_kind`,
`meas_analyses`, `meas_phase_pattern`, `meas_needs_degrees`, `meas_num`,
`meas_rule`, `meas_qual`, `meas_edge`, `meas_word`, `meas_line`, `meas_window`,
`postproc_lines`, `postproc_newplot`, `postproc_resamples`, `meas_plotvar`,
`meas_srcvar`, `meas_block`, `meas_group` — of which **four are registered
hooks**: `meas_kinds`, `meas_analyses`, `meas_rule`, `meas_needs_degrees`.

**And `measurements` is one list with a `kind` that decides everything.** Two
rows may not share a name — the name becomes a VECTOR in the simulator and a KEY
in the sidecar, and the sidecar's lookup is case-insensitive because the
simulator folds what it prints, so a duplicate would silently overwrite the
first row's answer (row **VD17**).

**The refusal evaluator is four verdicts and the order matters.** `refuse` emits
nothing and is reported; `caution` emits and the run says what is uncertain;
`fatal` refuses the deck before a line is built (issue 1424's third tier, one
level down); everything else is `ok`. **Core's structural checks run first and
the simulator's rules last**, because core can say *"this row has no name"*
without knowing a verb and only the adapter can say *"this function segfaults on
that plot"*. A backend with no `meas_rule` hook refuses nothing of its own
(row **VD16**).

## What shipped — the CONTENT half (`ase::backend::ngspice`)

**Four new optional hooks** — `meas_kinds`, `meas_analyses`, `meas_rule`,
`meas_needs_degrees` — plus `meas_line`, `meas_word`, `meas_qual`, `meas_edge`,
`meas_window`, `meas_num`, `meas_stat_kind`, `postproc_lines`,
`postproc_newplot`, `postproc_resamples`, `meas_group`, `meas_block`,
`meas_plotvar`, `meas_srcvar`, `meas_phase_pattern`.

**Eighteen kinds in one catalogue**: `trigtarg`, `find`, `when`, the eight window
statistics (`avg` `rms` `min` `max` `min_at` `max_at` `pp` `integ`, sharing one
descriptor rather than eight copies of it), `deriv` (named and refused, with its
reason and the dossier's workaround), `param` (a `let`), and the five producers
`fourier`, `linearize`, `fft`, `psd`, `spec`.

## The block, and where it goes

```
<analysis line>
[checkpoint loop]                      1433
<$sim_status guard>                    casemode item 10 / C4
remzerovec
echo "PLOT …" >> <plotmap>             1430
write <raw>
──────────────────────── the Stage 8 block ────────────────────────
set aseplt = $curplot                  only when a producer changes the plot
set asesrc = $curplot
echo ASE-MEAS >> <cell>_ase.meas
set units=degrees                      only when a measurement reads a phase
meas <an> <name> … >> <cell>_ase.meas
linearize                              a producer
set asesrc = $curplot                  a resample becomes the new source
setplot $asesrc                        every transform after the first
fft v(out)
meas sp <name> … >> <cell>_ase.meas    measured on the plot that producer made
setplot $aseplt                        the analysis's own plot, back
───────────────────────────────────────────────────────────────────
[setplot previous walk]                1430
[printed outputs]                      0967 / 1243
[option restores]                      §7e
```

**All four bounds are asserted, and two different ways.** `DK2` bounds the block
against the guard, the write, the prints and the option restores **as emitted**;
`DK2c` reads `render_deck`'s own body, because three of the four moves are
invisible on a single-capture analysis — there is no walk to be below — and that
is exactly the gap issue 1442's sabotage **S24** hid in. `DK2b` is DK2's
non-vacuity half: every anchor it bounds against is really in that deck, so it
cannot compare −1 against −1 and pass over anything.

## The sidecar

`<rundir>/<cell>_ase.meas`, beside the results file, the log, the plotmap, the
checkpoint and the effective-settings sidecar; it **raises for a state with no
design cell** exactly as its five siblings do, and `run_deck` deletes it **at the
top**, with them, not just before `eval execute` (row **SC7**).

It is opened by an `echo` that cannot fail and every measurement **appends**,
because a `meas … > file` whose measurement fails writes **zero bytes** (C152).
A failed row therefore costs only its own line, and its absence from the file is
the verdict `failed` rather than a blank cell (row **SC3**).


---

## THE SABOTAGE CAMPAIGN

**Seventy-two respellings**, each a plausible rewrite rather than a break — the
tidy-up somebody would actually make — and **fifteen of them reproduce a claim
`PLAN.md`, a dossier, this tree's own shipped code, or an earlier draft of this
very change actually makes**: **S01** (binding through `analysis_emit_order`, as
every other reader in the file does, and as this change's own first cut did),
**S25** (offering ngspice's `expr=` and `param=` spellings, which `PLAN.md` §8a
lists as kinds), **S28** (a default edge on `find`, which is what the first cut
emitted), **S33** (reading `ase::si_parse`'s answer as a number, which is what
the first cut of the `spec` band rule did — **and every band then passed
silently**), **S35** (spacing the qualifiers out, which the CARD form really does
tolerate), **S37** (`param=` exactly as `PLAN.md` §8a writes it), **S41** (the
`.options units=degrees` card, which is what a reader who trusts the plan's
option story would write), **S42** (spelling `set units=degrees` in the adapter
rather than through the one speller — the shape the brief recommended), **S44**
and **S45** (the block above the write, which is `APPENDIX` §6.7's own
recommended route, and below the walk), **S48** (`.four` as a CARD, exactly as
`PLAN.md` §8c says), **S52** (`measurements` as an ordinary schema key), **S53**
(a seeded measurement row), **S57** (the bookkeeping this change emitted
unconditionally until pass 1) and **S31b** (the crash rule reading the bound
analysis rather than the emitted word — the shape it had until pass 1 found the
narrowing unreachable).

Restore was `cp` from `/tmp/s8t1/sab/good_ase.tcl` with an **md5 compare after
every application**, the campaign **aborts on a restore mismatch** rather than
continuing, **anchor uniqueness was checked against the pristine file before each
campaign started**, and **no source file was edited while a campaign was live**.

**TWO FULL CAMPAIGNS, ONE ON THE FIRST TREE AND ONE ON THE FINAL TREE**, as
issue 1442's discipline asks. Pass 1: **54 applications, 48 RED, 6 SURVIVED,
ZERO KILLS**. Six rows were rewritten for the six survivors and six sabotages
were added with them; pass 2 on the repaired tree: **71 applications, 67 RED,
4 SURVIVED, ZERO KILLS**, and a targeted re-run of the four plus the new **S68**
closed one of them. **Final: 72 applications, 3 survivors, and all three are
provably behaviour-preserving** — the table says which.

Every application ran **four** suites — `test_ase_meas_1443`, `test_ase_core`,
`test_ase_preflight` and `test_ase_effective_1442` — concurrently against one
sabotaged source, plus `test_ase_optier_0963` for the applications inside
`render_deck`'s and `run_deck`'s blast radius. ⚠ **That last split is itself a
measurement**: `test_ase_optier_0963` STARTS A SIMULATOR (a real `tb_bandgap`
run in its own scratch directory) and cost ~110 s of the campaign's ~130 s per
application, so running it 58 times would have launched ngspice 58 times for
nothing.

| # | the respelling | rows reddened on the final tree |
|---|---|---|
| S01 | meas_binding: bind through ase::analysis_emit_order, as every other reader does | VD10 VD16 DK5 DK5b |
| S02 | meas_binding: a row index that names a DISABLED analysis row still binds | VD5 |
| S03 | meas_binding: the LAST enabled row of the type wins, so a new row takes over | VD5 |
| S04 | meas_enabled: a row is off unless it says enabled 1 | VD17 VD13 VD15 PH1 PH3 PP2b PP2c PP2e PP3 PP4 PP4b PP5 PP6 DK2 DK2b DK3 DK4 DK5 DK5b DK7 SC3 SC3c SC3b SC5 SC6b SC6c |
| S05 | meas_name_ok: any non-empty name is a name | VD2 |
| S06 | meas_verdict: an unknown kind is skipped rather than refused | VD3 DK1 SC3 SC6c |
| S07 | meas_verdict: a kind the simulator names and cannot run is just an unknown kind | VD4 |
| S08 | meas_verdict: skip the measurable-type check, the adapter's rule will catch it | VD7 |
| S09 | meas_verdict: the form validates its own fields, so the evaluator need not | VD8 — **survived pass 1**; reddens the row written for it |
| S09b | meas_verdict: a required field is checked against the STORED value, not the emitted one | VD8b |
| S10 | meas_verdict: an `on` naming nothing is tolerated -- the block just measures the analysis | VD10b VD11 |
| S11 | meas_for: emit refused rows too, the speller will do its best | DK1 |
| S12 | meas_for: a cautioned row is not emitted -- a warning means do not do it | PP3 PP4b PP5 PP6 |
| S13 | meas_fatals: a fatal row is dropped like a refusal rather than refusing the deck | DK5 DK5b |
| S14 | meas_armed: armed by the list being non-empty | SC6c — **survived pass 1**; reddens the row written for it |
| S15 | meas_counter_index: count within this analysis row, as the block is built per row | PP2c |
| S16 | meas_counter_index: count every producer, not only the ones sharing the counter | PP2e — **survived pass 1**; reddens the row written for it |
| S17 | meas_path: name it after the simulator's own card, not after ASE-L | DK3 SC1 |
| S18 | meas_parse: the name is the name -- match it as the bench spelled it | SC2c — **survived pass 1**; reddens the row written for it |
| S19 | meas_parse: a line without an equals sign is still a line worth keeping | SC2 SC2c SC2b |
| S20 | meas_results: a row the run did not report is simply blank | SC3 SC3c SC5 |
| S21 | meas_report: report the numbers -- a report is what was measured | SC3c SC5 |
| S22 | meas_needs_degrees: core knows what a phase looks like | PH6b HK1 |
| S23 | meas_kinds: a backend that declares no hook still gets the ordinary vocabulary | KN5 HK2 |
| S24 | register_backend: the kind memo outlives one registration, like any memo | KN6 |
| S25 | meas_kinds: offer the simulator's own expr= and param= spellings too | KN1 |
| S26 | meas_kinds: deriv is recognised by the simulator, so it needs no refusal | KN1 KN2 KN7 KN8 VD2 VD4 VD8 VD8b VD17 VD17b VD9 VD10 VD10c VD12 VD13 VD14 LN10 PH1 PH3 PP2b PP2c PP2e PP3 PP4 PP4b PP5 PP6 DK2 DK2b DK3 DK4 DK5 DK5b DK7 SC3 SC3c SC3d SC3b SC5 SC6b SC6c |
| S27 | meas_stat_kind: the window statistics take a delay like every other measurement | KN8 |
| S28 | meas_kinds: find's edge defaults to rise, like the delay's does | LN5 |
| S29 | meas_analyses: every analysis this adapter renders can carry a measurement | KN3 VD7 |
| S30 | meas_rule: the crash pair refuses rather than refusing the whole deck | VD10 DK5 DK5b |
| S31 | meas_rule: the crash rule fires on the analysis word, spectrum or not | VD10c — **survived pass 1**; reddens the row written for it |
| S32 | meas_rule: a spectrum with no resample is refused, not merely cautioned | VD8b VD12 VD13 PP3 PP4b PP5 PP6 |
| S33 | meas_rule: si_parse answers a number, so read it as one | VD14 |
| S34 | meas_rule: a value measurement given both a point and a condition uses the point | VD9 |
| S35 | meas_qual: space the qualifiers out, as the card form tolerates | LN3 LN4 LN5 LN6 |
| S36 | meas_edge: a row may ask for more than one edge condition | LN5 LN8 |
| S37 | meas_line: the param kind emits param=, exactly as PLAN.md writes it | LN9 LN9b |
| S38 | meas_word: a measurement keeps its analysis's own word wherever it is taken | LN10 PP6 |
| S39 | meas_word: every plot a producer makes is a spectrum | LN10 |
| S40 | meas_group: set the unit on every block -- verification is not optional | PH2 |
| S41 | meas_group: write the unit as an options card, where every other option goes | PH1 PH3 PH3c PH4 |
| S42 | meas_group: spell the one line here rather than reaching into the option speller | PH3c |
| S43 | meas_group: put the unit back when the group is done, as a scoped option does | **SURVIVED — behaviour-preserving, see below** |
| S44 | meas_block: the block goes ABOVE the write, so the numbers ride the results file | DK2 DK2c |
| S45 | meas_block: the block goes below the walk, after every plot is written | DK2c |
| S45b | meas_block: the block goes below the option restores, at the very end of the row | DK2 DK2c |
| S46 | meas_block: nothing has to be put back -- the walk finds its own plot | PP3 PP4 PP5 |
| S47 | meas_block: send every producer back to the source, the first one included | PP3 PP4 PP5c |
| S48 | postproc_lines: a Fourier request is a card, exactly as PLAN.md 8c says | PP2 DK4 |
| S49 | postproc_lines: linearize always says how many points it wants | PP1 PP4 |
| S50 | render_deck: a measurement cannot stop a deck being written -- the gate is the place for that | DK5 DK5b |
| S51 | run_deck: delete the measurement sidecar just before `eval execute`, where the plan asked for it | SC7 |
| S54 | meas_verdict: names are the user's business -- two rows may share one | VD17 |
| S54b | meas_verdict: a duplicate name is a duplicate only if it is spelled the same way | VD17 |
| S55 | meas_results: a row with no number is a row that failed, whatever it was for | SC3c |
| S56 | meas_kinds: a producer yields what it yields -- the catalogue need not say | SC3c SC3d |
| S43b | meas_group: put the unit back when the group is done, as a scoped option does | PH1 PH5 |
| S31b | meas_rule: the crash rule reads the analysis the row is bound to, not the word it emits | **SURVIVED — behaviour-preserving, see below** |
| S57 | meas_block: remember the plot whenever there is a producer, belt and braces | PP4b PP5c |
| S59 | meas_needs_degrees: the phase functions are vp() and ph(), which is what the manual names | PH6 |
| S60 | meas_edge: emit the edge as two halves, so a reader can see which is which | LN1 LN3 LN7 |
| S61 | meas_verdict: a row with no name takes its kind as its name | VD1 |
| S62 | meas_verdict: a measurement whose analysis is not enabled is simply skipped, not refused | VD6 |
| S63 | meas_schema_errors: a kind that names its fields does not have to declare a form | KN4b |
| S64 | meas_line: the function word goes in as the user typed it | LN2 LN4 PP6 DK3 DK7 |
| S65 | meas_block: capture the plots the producers make, like every other plot in the deck | PP7 PP7b |
| S66 | meas_for: a measurement belongs to its analysis TYPE, not to one row of it | PP2c DK7 |
| S67 | meas_counter_index: every producer gets an ordinal, whether it needs one or not | **SURVIVED — behaviour-preserving, see below** |
| S68 | meas_parse: the simulator prints a fixed layout, so read the value off it | SC2 SC2c SC2d SC2e SC3c SC3b SC4 SC5 |
| S52 | state_default: measurements is an ordinary schema key, written like every other one | DK1b R1m |
| S53 | state_default: a fresh bench comes with a measurement ready to fill in | DK1b R1m X7 |

### ⚠ SEVENTY-TWO APPLICATIONS ON THE FINAL TREE, **ZERO KILLS**, AND THREE SURVIVORS THAT CANNOT FAIL

The three are all **behaviour-preserving respellings** — not rows that failed to
catch a defect, but sabotages that do not introduce one — and the argument for
each is short enough to check:

| survivor | why nothing could move |
|---|---|
| **S43** | it declares a local variable and **emits no line**. A sabotage that changes no output is indistinguishable from one that passes — the fourth variant of this batch's own list, met in my own generator. **S43b** is the one that actually appends the restore, and it reddens **PH1** and **PH5** |
| **S31b** | `[meas_word …] eq {sp}` against `$type eq {sp}`. The two differ only for a row whose `meas_word` is `sp` while its binding type is not, or the reverse — and both are unreachable: `meas_word` answers `sp` only through a producer, which requires `on`, and a producer bound to anything but `tran` is already refused. The shipped form is the sharper STATEMENT (it reads what the line will say, which is what `get_measure2` gates on) rather than a different behaviour. **S31** — the same clause deleted outright — reddens **VD10c** |
| **S67** | `if {$tok eq {}} {return 0}` against the same guarded by the form. With `$tok` empty the walk's own `[dict get $re counter] ne $tok` matches nothing, so the answer is `0` either way. **S16** — counting every producer regardless of token — reddens **PP2e** |

⚠ **The fourth pass-2 survivor, S63, is not in that list: it was a REAL hole.**
`ase::meas_schema_errors`' *"no form"* arm could not be reached by any fixture,
because every kind in the shipped catalogue declares one — KN4 asserts the
catalogue is clean, which is exactly what a checker returning `{}`
unconditionally would also do. **KN4b** builds a catalogue that is wrong in six
ways on a synthetic backend and asserts all six sentences; S63 now reddens it.

⚠ **AND `ase::meas_parse` GAINED A SABOTAGE OF ITS OWN AFTER THE DRIVER'S FACT 3
ARRIVED.** **S68** replaces the regexp with the fixed column layout the
simulator's printed line appears to have, and reddens **eight** sidecar rows
(SC2, SC2c, SC2d, SC2e, SC3b, SC3c, SC4, SC5) — the layout is not fixed, because
the value's width differs between the two binaries.

---

## Suites moved, before → after

**Every number below is a `RESULT:` line**, taken from a run of the final tree on
2026-09-13, headless and on the dev display (`:99`) — never from a paragraph, and
never from an earlier receipt.

| suite | headless | display (`:99`) | in T1? |
|---|---|---|---|
| **`test_ase_meas_1443`** (new) | — → **100** | — → **100** | **yes, `hcases` only** — added in this change. Not `dcases`, and the file says why |
| `test_ase_core` | 598 → **600**, **R1 re-baselined** 18 → 19 keys, **R1m** added | 598 → **600** | yes |
| `test_ase_persist` | 44 → **44**, **R1 re-baselined** 18 → 19 keys | 148 → **148** | yes (headless arm only) |
| `test_ase_options_1437` | 75 → **75** | 75 → **75** | yes |
| `test_ase_predeck_1439` | 78 → **78** | 78 → **78** | yes |
| `test_ase_optsheet_1441` | 62 → **62** | 87 → **87** | yes, BOTH arms |
| `test_ase_effective_1442` | 92 → **92** | 92 → **92** | yes |
| `test_ase_preflight` | 235 → **235** | 235 → **235** | yes |
| `test_ase_optier_0963` | 108 → **108** — `PLAN.md`'s asked-for **E17** re-run | not run — issue **1440**, and T1 runs this file headless only | yes (headless arm only) |
| `test_ase_simreg_0931` | 117 → **117** | 117 → **117** | yes |
| `test_ase_simcaps_0948` | 199 → **199** | 199 → **199** | yes |
| `test_ase_dialogs` | 37 → **37** | 312 passed / **1 FAILED** — issue **1436**, unchanged | yes (headless arm only) |
| `test_ase_simdlg_0937` | 5 → **5** | 55 → **55** | yes |
| every other ASE suite | unmoved | — | — |

**The two re-baselined rows, with the reason that moved each:**

| row | before → after | why |
|---|---|---|
| `test_ase_core` **R1** | *"exactly the 18 schema keys"* → **19** | `measurements` is the fourth key added since that row was written and the fifth member of `ase::omit_if_empty`. Its default is `{}`, it is not serialized when empty, and **all 104 committed `.state` files still round-trip byte-identically** — counted live at the moment the key was added |
| `test_ase_persist` **R1** | the same claim, the same key | the same reason; R2's byte-identical round trip below it is unaffected |

`test_ase_core` also gains **R1m** (the key is omitted when empty **and** written
when it is not — the non-vacuity half), and its floor is raised **598 → 600** in
the same commit.

### ⚠ The two results that are NOT this change

* **`test_ase_dialogs` G2sens**, display arm. Issue **1436**, filed by the 1435
  crew and not fixed. The actual value — `{1 1 0 1 0 Entry Entry normal}` against
  `{1 1 0 0 0 Entry Entry normal}` — is **byte-identical to 1436's transcript**
  and to the one every crew since has reported. T1 runs this file's **headless**
  arm only, where it is ALL PASS (37). ⚠ Its display count has grown from 300 to
  313 since issue 1442's receipt, because **another writer is adding rows to that
  file while this task runs** (⚖ R5's, issue 1445); the failing row is the same
  one.
* **`test_ase_optier_0963` display arm.** Issue **1440**, rc 124 at the 200 s
  suite timeout, stops after row N3. ⚠ **This crew did NOT investigate it** — it
  is the known exception the brief names, and this crew did not run it on that
  arm at all. Its **headless** arm, which is the one T1 runs and the one
  `PLAN.md` §8 asks for by name, is **ALL PASS (108)** here, so **E17 — *the
  Outputs Value column reads the OPERATING POINT* — is confirmed intact**:
  measurement rows are additive and displaced nothing.

⚠ **NO COMMITTED DECK GOLDEN FILE MOVED AND NO `.state` FILE MOVED.** No
committed bench carries a `measurements` list, so every deck in the tree renders
byte-identically — `test_ase_core`'s inline **D1** golden included, which is why
it did not have to be re-baselined for the first time in four issues. No state
key was added to `ase::state_default`'s SEED, it still seeds exactly four
analysis rows, there is no `seed_enabled` anywhere in this diff, `op` is still
last in emit order, and the print anchor (1243), the plotmap record (1430), the
checkpoint block (1433), the `.save all` leader (1434), 1439's door
consultation, 1441's `ase::opt_deck_plan` and 1442's effective-readback block are
all exactly where they were. `test_ase_core`'s section **CP** — the row that
would notice a byte in the 104 committed `.state` files — is green.

---

## Corrections, C145 onwards

**C100–C144 were issues 1437, 1439, 1441 and 1442.** Nine corrections, all of
them measured; the full text is in `doc/claude/issues/1443-*.md` and the
headlines are:

| # | what it corrects |
|---|---|
| **C145** | `units` **IS** one of the 247 catalogue rows — the brief and `LEDGER.md`'s Stage 8 block both say it is not, and the consequence is that the emission goes through the ONE speller rather than through a new literal |
| **C146** | trap 4's stated REASON is false on apt 45.2: `set measureprec` and `NGSPICE_MEAS_PRECISION` are both accepted and **inert** there, so the redirect buys no precision over the vector. It ships with the reason that is true |
| **C147** | traps 1 and 2 are about the CARD; on the COMMAND form `expr=`, `param=` and `par()` **do not exist**, so the `param` kind ships as a `let` and cannot meet trap 2 at all |
| **C148** | §8c's *"`.four` is a CARD"* — a dot card beside a `.control` block runs the whole simulation a **second time**. The card slot ships EMPTY and `fourier`, the command, does the same work |
| **C149** | §8c's *"All four are captured by Stage 6's walk"* — a producer's plot in the results file is read back as the analysis it MIMICS (`Transient Analysis (linearized)` → tran, `Spectrum` → ac), measured through this tree's own reader. No producer plot is written |
| **C150** | `APPENDIX` §6.7's recommended rawfile route costs a full-length column per scalar: **+16 MB for two scalars** on a 1,000,001-point transient. That is why the block sits below the write |
| **C151** | `fft`/`psd`/`spec` leave their OWN plot current, so a second transform reads a spectrum, creates nothing and exits 0 |
| **C152** | a FAILING `meas … > file` creates the file and leaves it at **zero bytes** |
| **C153** | `ase::si_parse` answers `{ok <value>}`, not a number — recorded because the first cut of the `spec` band rule read it as one and **every band then passed silently** |

⚠ **AND THE DRIVER'S FIVE MEASURED FACTS ARE CONFIRMATIONS, NOT CORRECTIONS** —
see the section above. The one that added work is fact 3, which was true of this
design by construction and is now true of it by ROW.

---

## What I did NOT ship, and why

* **A Measurements dialog, a template picker, or a Value-column row.** §8b is
  task 2. Nothing in this change creates a widget, which is also why the new
  suite's two arms are identical and why it is in `hcases` only.
* **A `<cell>_ase.spectra.raw`.** C149 makes a second results file the honest way
  to capture a producer's plot, and it is a real artefact with a reader, a
  deletion and a reconciliation of its own. Until then the plot is produced, it
  is measurable, and the run does not pretend it is in the results file.
* **Any change to `ase::analysis_captures`, the `setplot previous` walk, the
  plotmap or `ase::reconcile_plots`.** C149 removed the reason to touch them, and
  row **DK6** is what says so: a bench full of post-processing predicts exactly
  the plots its analyses make and emits no walk it did not emit before.
* **`autostop`.** It is a `.meas`-CARD feature (`ft_curckt->ci_meas`, and
  `inp.c:1143` auto-disables it for `max|min|avg|rms|integ` anyway) and this
  change emits no cards.
* **`print <name>` for every measurement instead of the redirected `meas` line.**
  It would be byte-identical across the two binaries (the driver's fact 3) and it
  discards the `at=`/`from=`/`to=` tail, which is the only report of a crossing's
  location. The parse is width-independent by construction, so the redirect costs
  nothing and keeps more. Named here because it is the obvious alternative and
  the reason for not taking it is a trade rather than an oversight.
* **A `specwindow` cross-rule.** `fft`'s *"set to `none`"* message is measured
  false — `fft_windows()` returns 0 **without writing the window array**, so
  every sample is multiplied by zero and the spectrum is silently flat. It is a
  genuine option × producer rule of §7g's shape, and it belongs with the
  `specwindow` catalogue row rather than with the producer; naming it here
  without shipping it is the honest half.
* **`help` text for the eighteen kinds.** ⚖ R9, as Stage 7 left it.
* **Any re-measurement of the `meas sp` SEGFAULT.** Transcribed from
  `evidence/measure.md` §1.5 and source-confirmed, deliberately not reproduced:
  the brief forbids a probe that crashes the user's simulator without cause, and
  `sp` is not renderable today, so no ASE-L deck can reach it.

---

## What this task learned that binds later stages

**A PLAN'S STRUCTURAL CLAIM CAN BE WRONG IN A WAY THAT MAKES THE FEATURE WORSE,
NOT MERELY DIFFERENT.** §8c's two sentences — *"`.four` is a CARD"* and *"all
four are captured by Stage 6's walk"* — would each have shipped a measured
defect: a second full simulation on every deck that asks for a THD, and a
waveform viewer publishing a linearized copy as the transient. ⚠ **Both were
found by measuring what the claim WOULD DO, not by measuring whether the claim
was true.** A card really is a card; capturing really is possible. The question
that found them was *"and then what happens?"*

**A RECOMMENDED ROUTE IN THE EVIDENCE BASE IS STILL A CLAIM.** `APPENDIX` §6.7
calls the rawfile route *"how a GUI gets numeric measurements back"* and
`evidence/measure.md` §2 calls the same thing an **anti-route**, four hundred
lines apart in two documents that agree about everything else. The measurement
(+16 MB for two scalars) settles it. ⚠ **When two dossiers disagree, neither is
the tiebreak.**

**AND A BRIEF'S OWN LOAD-BEARING FACT DESERVES THE SAME TREATMENT AS A PLAN'S.**
The `units` paragraph was driver-verified, correct about the behaviour, and wrong
about the catalogue — and being wrong about the catalogue was what made it
recommend a new literal instead of the speller that was already there. ⚠ **Check
what a fact IMPLIES you must build, not only whether the fact is true.**

**A GUARD WHOSE CALLER CANNOT REACH IT IS THE BATCH'S FIFTH OF THAT FAMILY.**
`ase::meas_binding` originally resolved through `ase::analysis_emit_order`, which
RAISES for a type the backend cannot rank — so the crash refusal, the one
refusal that exists to stop a SIGSEGV, could never fire for the very analysis it
is about. The fix is the one issue 1442 named: **let the caller supply the
input**. Binding asks the bench, which answers whether or not the deck can be
rendered.

---

## Rulings

⚖ **R9 — new user-facing copy, filed as `owed.sh add rule 1443`** at the moment
it was incurred, pointing at `doc/claude/issues/1443-*.md`:

1. **the eighteen kind labels** — *Delay (TRIG … TARG)*, *Value at a point*,
   *Where a signal crosses a value*, *Average*, *RMS*, *Minimum*, *Maximum*,
   *Where the minimum is*, *Where the maximum is*, *Peak to peak*, *Integral*,
   *Derivative*, *Expression over other measurements*, *Fourier / THD*,
   *Resample onto a uniform time grid*, *FFT spectrum*, *Power spectral density*,
   *Spectrum over a frequency band*;
2. **the field labels** — *Trigger signal / value / edge / edge number / delay*
   and their target twins, *Signal*, *At*, *When signal*, *reaches*, *Edge*,
   *Edge number*, *Ignore before*, *From*, *To*, *Expression*, *Fundamental*,
   *Points*, *Only these signals*, *Averaging points*, *Start*, *Stop*, *Step*;
3. **the twelve refusal sentences**, of which three need the ruling most: the
   `deriv` one (*"ngspice names DERIV and refuses it at run time … compute it
   first with a post-processing expression and measure that instead"*), the
   S-parameter crash one (*"ngspice's own measure engine reads a complex
   frequency scale as if it were real and SEGFAULTS"*), and the two-grammar one
   for a value measurement;
4. **the spectrum caution** — *"this spectrum is taken from adaptive-step
   transient data, which the transform assumes is evenly spaced. Add a Resample
   row before it, or read the amplitude as approximate"*;
5. **the report sentences** — `<name> = <value>`, the caution form, *"the
   simulator did not report this measurement: the condition it asks about may
   never occur in this run"*, *"<name> was not measured: …"* and *"<name> cannot
   be measured: …"*.

**Batch with 1426, 1427, 1428, 1429, 1430, 1432, 1433, 1434, 1435, 1437, 1439,
1441 and 1442, which are all still waiting.**

⚠ **NO `look` DEBT IS FILED BY THIS TASK, AND THAT IS A MEASUREMENT RATHER THAN
A CLAIM.** Nothing here draws a pixel: `src/ase_window.tcl` is **untouched**, the
new suite's two arms are **86 and 86** with the same rows, and `PLAN.md` §8's
*Re-measure on the dev display* paragraph asks for the Measurements pane and the
harmonic table — both of which are task 2's. ⚠ **`LEDGER.md`'s Stage 8 block
already flags that paragraph's "no new look debt is filed" as the claim Stage 4
got wrong; task 2 is where it is decided, and this task's silence is not a vote.**

⚖ R2, ⚖ R3 are **answered**. ⚖ **R4 is open and nothing here is gated on it** —
nothing was seeded, `ase::state_default` still seeds exactly four analysis rows,
and there is no `seed_enabled` anywhere in this diff.


---

## What binds task 2 (§8b), so it inherits rather than re-derives

**Read this before opening `PLAN.md` §8b.** Five shapes are already decided and
tested, and four of them are decisions §8b would otherwise make differently.

1. **ONE list, not two.** `measurements` carries **both** the measurements and
   the post-processing producers, and `ase::meas_kind_form` — `meas` or
   `producer` — is the single key that tells them apart. The Measurements
   sub-dialog therefore has one list widget and one Add button with an
   eighteen-entry kind picker, not a Measurements pane beside a
   Post-processing pane. The reason is §8b's own THD template: *"`.four <f0>
   v(out)` card + `thd1` read from the result table"* is a **producer plus a
   measurement**, and it composes only if they are rows of one list.

2. **A row's shape is `{name … analysis <type> [row <idx>] kind <k> [on <name>]
   [enabled 0] <kind fields>}`.** `analysis` is the analysis TYPE; `row` is the
   OCCURRENCE (absent = the first enabled row of that type); `on` names another
   row — a producer — whose plot this measurement reads. `enabled` is absent for
   on, exactly as `save_op_params`'s tri-state works.

3. **The eight templates are `ase::meas_templates`' content, in the adapter, and
   each one is a LIST OF ROWS.** Phase margin is three rows (a `find` on `vp`, a
   `when` on `vdb`, and a `param` that adds 180), not one row with an expression.
   The `param` kind emits a **`let`**, never `param=` — measured, the command
   form has no `param=` at all (C147). `set units=degrees` is emitted
   **automatically** by `meas_needs_degrees`, so a template must NOT carry it as
   a row of its own; PH2 would then fire for a template with no phase in it.

4. **The Value column reads `ase::meas_results`, which returns
   `{name verdict value why}` per row with FIVE verdicts** — `ok`, `caution`,
   `failed`, `refused`, `off`. ⚠ **`failed` is not a blank**: it means the row
   emitted and the simulator reported nothing, which is a real answer and the one
   an empty cell would be read as zero. `ase::meas_report` is the same thing as
   sentences.
   ⚠ **AND `meas_results` CURRENTLY REPORTS A PRODUCER ROW WITH NO NUMBER AS
   `failed`** — see *What I did NOT ship*. A `linearize` row is not supposed to
   yield a number, and task 2 must not put "the simulator did not report this"
   beside one. The `yields` key on the kind entry is where the fix goes.

5. **⚖ R6's `id` KEY MUST JOIN `ase::meas_binding`, AND IT IS ONE CLAUSE.** R6 was
   answered *"Add it"* while this task was being built, and `DECISIONS.md` already
   records that `ase::meas_binding` answers `{type idx}` and that the user-visible
   handle must follow that shape. The binding's explicit selector is the `row`
   key, an INDEX; when analysis rows gain `id`, the same walk gains one arm —
   *"an explicit selector matches either the row's index or its `id`"* — and
   nothing else in this task moves. ⚠ **Issue 1444 is the surface for it and it
   is R6's task's, not Stage 8's**: task 2's Measurements dropdown CONSUMES the
   scheme rather than minting one, and if the order ever inverts it consumes
   `{type idx}` verbatim.

6. **No widget exists yet and the deck preview does not show these lines.**
   `ase::opt_preview` is §7c's, and it renders the OPTION lines only. The
   Measurements block is in the rendered deck and nowhere on screen — which is
   half of the standing rule *"nothing the deck contains may be unshowable in the
   window"*, and it is task 2's to close.


---

## For the driver

* **T1 was NOT run by this crew** (issue 0990 — the driver runs it solo).
  ⚠ **T1's membership changed in this commit**: `tests/run_regression.tcl`'s
  **`hcases`** gains `headless/test_ase_meas_1443`. **`dcases` does NOT change**,
  and the file carries the measurement that says why — 86 checks on both arms,
  the same rows, and no widget is created at all.
* ⚠ **HEAD MOVED UNDER THIS TASK, THREE TIMES, AND ONE OF THOSE COMMITS CARRIED
  THIS CREW'S OWN `NUMBERING.md` EDIT.** The tree was handed over at `0390cbe6`;
  it is at **`8428608a`** as this receipt is written, through at least six
  commits (⚖ R8, R10, R11, R5's issue 1445, a receipt re-measure and a crew-slot
  note). Checked rather than assumed:
  * **`src/ase.tcl` is byte-identical at `0390cbe6` and at HEAD** (21794 lines
    both), so nothing this crew wrote sits on top of somebody else's edit to it.
  * **`src/ase_window.tcl` gained 19 lines** in that span (⚖ R5's annotation in
    `choose_analyses`). **This crew did not touch that file** and its working
    copy is byte-identical to HEAD — `git diff` on it is empty.
  * **`doc/claude/issues/NUMBERING.md` is no longer modified in the working
    tree**, because one of those commits picked up this crew's 1443 entry along
    with its own. It is **in HEAD**, the pointer has since moved to **1447**, and
    **there is no collision**: the other writer minted 1444, 1445 and 1446 —
    never 1443. ⚠ Both mint checks were nevertheless run at the moment 1443 was
    minted, and this is exactly the moving-tree case `NUMBERING.md`'s own
    paragraph warns about: the pointer was 1443 then and is 1447 now.
  * ⚠ **The issue FILE `doc/claude/issues/1443-*.md` is still untracked** — only
    the `NUMBERING.md` entry went in — so the driver's commit must include it.
* ⚠ **AND ⚖ R6 WAS ANSWERED WHILE THIS TASK WAS BEING BUILT — *"Add it"*.**
  `DECISIONS.md` already cites `ase::meas_binding` by name and records that the
  user-visible handle must follow its `{type idx}` shape. Nothing here needs to
  change for it; what R6's task adds is one arm on the binding's explicit
  selector. See *What binds task 2*, item 5.
* **Nothing was committed, added, stashed, restored, cleaned or pushed.** No
  `git checkout --`, no `git restore`, no `git stash`, no `git clean`, no
  `git commit`, no `git push`, no PR. The working tree is the one handed over
  plus **four modified files** (`src/ase.tcl`, `tests/headless/test_ase_core.tcl`,
  `tests/headless/test_ase_persist.tcl`, `tests/run_regression.tcl` — the
  `NUMBERING.md` edit is already in HEAD, see above) and **three new ones**
  (`tests/headless/test_ase_meas_1443.tcl`, the issue file, this receipt). The
  four untracked paths inherited at `0390cbe6` are untouched. **`src/ase_window.tcl`
  is UNTOUCHED.**
* **`NUMBERING.md`'s pointer was advanced 1443 → 1444** in the same change as the
  entry. **Both mint checks were run at the moment of minting**: the reserved-band
  scan over this clone's head table (**silent** for 1443) and
  `ls ~/dev/*/doc/claude/issues/1443-*` plus `/usr/bin/grep -lw 1443` across
  **every** clone's `NUMBERING.md` (the glob verified non-empty, two clones) —
  only this clone's own pointer line came back.
* ⚠ **TWO ROWS WERE RE-BASELINED AND BOTH ARE THE SAME ONE-LINE DECISION**, so
  the driver can check them without re-deriving: `test_ase_core` **R1** and
  `test_ase_persist` **R1** both count `ase::state_default`'s schema keys, and the
  count goes **18 → 19** because `measurements` is the fourth key added since
  those rows were written. The shape of both claims is unchanged: the key exists,
  its default is `{}`, and it is in `ase::omit_if_empty` — verified live, **104 of
  104** committed `.state` files still round-trip byte-identically. `test_ase_core`
  also gains **R1m** (the key is omitted when empty AND written when not), which is
  the non-vacuity half, and its floor is raised **598 → 600** in the same commit.
* ⚠ **NO COMMITTED DECK GOLDEN FILE MOVED AND NO `.state` FILE MOVED.**
  `test_ase_core`'s inline **D1** golden deck did not move either — no committed
  bench carries a `measurements` list, so every deck in the tree renders
  byte-identically. Row **DK1** is the general statement of it.
* ⚠ **NO SIMULATOR IS STARTED BY THE FEATURE, BUT ~30 PROBE RUNS WERE MADE TO
  BUILD IT, ON BOTH BINARIES.** Every probe ran on a scratch deck under
  `/tmp/s8t1/probe` or `/tmp/s8t1/e2e` with that directory as its own cwd. **No
  bench under `sky130A/` was run** and no simulation touched `~/.xschem/`.
  Verified after the fact: `find ~/.xschem -name '*_ase.meas'` returns nothing.
* ⚠ **ONE END-TO-END RUN IS THE ACCEPTANCE, AND IT IS THE PHASE MARGIN.** An RC
  whose −3 dB point is exactly 1 kHz and whose phase there is exactly −45°,
  rendered by `render_deck` and run on **both** binaries:
  ```
  f3db                =  1.000000e+03
  phs                 =  -4.500000e+01      <- DEGREES, through meas
  ```
  with the plotmap 1:1 with the results file (two `PLOT` records, two
  `Plotname:` lines) and the linearized plot and the spectrum **not** in it.
* ⚠ **`test_ase_optier_0963` STARTS A SIMULATOR, AND IT RESOLVES `ngspice` FROM
  `PATH`.** Observed while profiling the sabotage campaign — it runs a real
  `tb_bandgap_ase.spice` in its own scratch directory and costs ~110 s. That is
  pre-existing suite behaviour, not this change's, and it is why the campaign
  runs it only for the sabotages inside `render_deck`'s and `run_deck`'s blast
  radius rather than 54 times. **Its headless arm is ALL PASS (108) here**, which
  is `PLAN.md`'s asked-for E17 re-run — *the Outputs Value column reads the
  OPERATING POINT* — and measurement rows are additive: nothing displaced it.
* ⚠ **`~/.xschem/geometry` WILL HAVE BEEN WRITTEN AGAIN** by the display arm —
  issue **1397**, already on the user's queue and reported by every crew since
  1430. Every headless invocation carried `--nogui`.
* ⚠⚠ **`$HOME/.spiceinit` WAS NEVER WRITTEN, MOVED, BACKED UP OR READ**, and no
  start-up file was created anywhere in this task. Every probe carried
  `--no-spiceinit`.
* **Machine rules honoured throughout**: every xschem invocation was given a path
  (`./src/xschem`, `devdisplay.sh exec ./src/xschem`, or through
  `run_suites.sh`) and `--nolog`, never `--logdir`, never a bare `xschem`; every
  bespoke command carried a `timeout` and every waiting loop a deadline;
  **a stall was a named outcome** (the campaign runner reports `TIMEOUT/<suite>`
  and `NORESULT/<suite>` as verdicts); `tests/run_regression.tcl` was not run;
  nothing was `pkill`ed that this crew did not start.
* **The next task is Stage 8 task 2 (§8b).** What it inherits from this one is
  listed under *What binds task 2* above — read that before opening `PLAN.md` §8b.
