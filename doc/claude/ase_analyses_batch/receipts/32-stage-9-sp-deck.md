# Stage 9 — S-parameters, the DECK half (§9 minus §9a/§9b)

**One commit, issue 1452, and the FIRST of Stage 9's two tasks.** Scope was the
`sp` type registered and renderable, the ports emission, the `two_ports` fatal,
the `lin 2` rule and `wrs2p`. **§9a's Ports table, §9b's S-parameter surface,
the matrix picker and Smith/polar are task 2 and no widget was built here:
`src/ase_window.tcl` is UNTOUCHED.**

**Floor:** new suite `test_ase_sp_1452` — **41 checks, identical rows on both
arms** (`diff` of the two ok-lists is empty) — registered in
`tests/run_regression.tcl`'s **`hcases` only**, and the case-list comment says
why with numbers measured at collection time.

**`src/ase.tcl` 23802 → 24409** (+607). One new registry key with four core
readers, two new `needs` arms, four new adapter procs, one fleshed-out registry
entry, two insertion points in `render_deck`.

---

## ⚠ THE HEADLINE: THE BRIEF'S `mislabel` QUESTION ANSWERS **NO**, AND IT IS THE RIGHT ANSWER

The brief asks me to prove that Stage 6's `mislabel` verdict catches a mixed-case
S-parameter vector name, *"rather than assuming"*. **Measured: it does not, and it
should not.**

`mislabel` compares **PLOT** names. `Plotname: SP Analysis` is byte-identical on
apt 45.2 and on the fork. Both of its comparisons are case-**IN**sensitive by
construction — `string equal -nocase` against the results file,
`string match -nocase` against the registry — so a lowercased `select` is
tolerated. Measured, through a canned results file of each binary's shape:

```
registry select               fork raw   apt raw
{SP Analysis}    (shipped)    ok         ok
{Scattering Parameters}       mislabel   mislabel   <- the positive control
{sp analysis}    (lowercased) ok         ok         <- the brief's case
sidecar record |sp analysis|  ok
sidecar record |Noise Spectral Density Curves|  mislabel
```

The mixed case is real; it lives in the **VECTOR** names, which `mislabel` never
looks at. Measured 2026-09-13, the same ASE-L-rendered deck run by both binaries
and read back through `ase::cap_raw_plots`:

```
fork      frequency S_1_1 S_1_2 S_2_1 S_2_2 Y_1_1 … Z_1_1 …
apt 45.2  frequency s_1_1 s_1_2 s_2_1 s_2_2 y_1_1 … z_1_1 …
```

`display` shows the capitals on both; it is the **rawfile** that differs — `tf`'s
folding finding, measured again for `sp`. **This half ships no reader of those
names** (`sp`'s `plots` row routes to the viewer and declares no `vectors` proc),
so nothing here can be wrong about them. **Row SM5 asserts that absence**, so the
surface that does add one — §9b's matrix picker — cannot be written
case-sensitively and stay green. Rows SM1–SM5; sabotage **s4** makes both
comparisons case-sensitive and reds SM3 and SM4.

## ⚠ AND A MEASUREMENT THAT AMENDS ISSUE 0964: `sp` EMITS **AFTER** `op`

The brief's non-negotiable is *"`op` stays LAST in emit order (issue 0964)"*. It
cannot, and the reason is two measurements neither the plan nor the evidence file
has. Both taken 2026-09-13 on apt 45.2 **and** on the fork, one deck:

```
op                                    -> v(in) = 1.000000e+00
alter v1 portnum = 1 / z0 = 50
alter v2 portnum = 2 / z0 = 50
sp lin 3 100meg 1g
op                                    -> v(in) = 6.250000e-01
```

**Promoting a source to a port changes every other analysis in the run.**
`vsrcset.c:53-79` creates an internal `<name>#res` node per port and
`vsrcload.c:51-64` stamps `g0 = 1/z0` across it — the vectors `v(v1#res)` and
`v(v2#res)` are visible in the SP plot's own `display`.

**And it cannot be undone.** The obvious repair — demote after the analysis, let
`op` run last as 0964 requires — was measured:

```
alter v1 portnum = 0
   -> Internal Error: incomplete CKTunsetup(), this will cause serious
      problems, please report this issue !
      ERROR: fatal error in ngspice, exit(1)          rc 1, both binaries
```

So there are exactly two orders available. **`op` before `sp`** gives a correct
operating point and leaves the SP plot carrying the op tier's forward-sticky
device columns. **`op` after `sp`** gives an operating point measured on a circuit
that has grown two resistors — at rc 0, with nothing said.

**0964's rule is about which vectors land in which plot; this is about whether a
printed number is true.** `sp` takes `emitorder 95`, which beats `op`'s op-last
**90** and its non-op-last **0**, so `sp` is last under BOTH variants with **no
change to `ase::analysis_emit_rank`**. Rows SR4/SR4b assert the order and **SE2
asserts the consequence end to end**: the Operating Point plot of a real run holds
`i(v1) i(v2) v(in) v(mid) v(out)` and **no `#res` node**.

## ⚠ WHAT I VERIFIED VERSUS WHAT I TRANSCRIBED

Everything in `evidence/sp-stage9.md` was **re-measured** rather than taken on
trust, because two of its claims did not survive (the `mislabel` one above, and
`lin_two`). Every ngspice fact in this receipt and in the suite's header is a
2026-09-13 transcript on **both** binaries, taken in `/tmp/sp9`, outside the
repository. **No bench under `sky130A/` was run.** The `ihp-sg13g2/` benches were
**read only** — `git status --short ihp-sg13g2/` is empty.

Transcribed rather than re-measured, and named as such: the source line
references (`span.c:376-386`, `vsrc.c:31-37`, `vsrcask.c:160-162`,
`vsrctemp.c:74-82`, `vsrcset.c:53-79`, `vsrcload.c:51-64`, `spsetp.c:80-82`,
`span.c:74-178`, `rawfile.c:934-1022`) come from APPENDIX §2.11. Their *behaviour*
is measured here; their *line numbers* are not.

---

## What shipped — the SCHEMA half (`src/ase.tcl`, `ase::`)

### The `setup` contract, and why it is not an `emit` card

`sp` cannot be expressed as one card. A port is an ordinary V source carrying
`portnum`, the promotion is **N lines built from a TABLE the user filled in**, and
each line spells a simulator keyword. `ase::analysis_expand` joins its tokens with
a space and returns ONE line; PLAN.md §1c's `{build <proc>}` slot (specified,
never shipped) would still be one line. **A contract that produces a variable
number of lines is a different shape from a card**, so it is a different key.

```
setup {key ports noun port min 2 fields {donoise s2p}
       lines ::ase::backend::ngspice::sp_alter_lines
       post  ::ase::backend::ngspice::sp_export_lines
       check ::ase::backend::ngspice::sp_row_check}
```

| part | side of D34–D37 | what it is |
|---|---|---|
| `key` | **schema** | the per-row state key the table lives under |
| `noun` | **schema** | what one entry is called, for core's own sentence |
| `min` | **schema** | how many the simulator requires — a COUNT spells nothing |
| `fields` | **schema** | fields the contract consumes, so `fieldunused` stays a real guard |
| `lines` | **content** | `<proc> $state $row $idx` → the lines ABOVE the card |
| `post` | **content** | same signature → the lines BELOW the card and below the guard |
| `check` | **content** | `<proc> $row` → one `{verdict sentence fix}` triple, or nothing |

Four core readers: `ase::analysis_setup`, `…_setup_key`, `…_setup_rows`,
`…_setup_emit`. **They count the table and never look inside an entry** — `z0` is
an ngspice keyword. `…_setup_emit` deliberately does **not** catch: a setup leg
that raises means the deck cannot be written, which is `render_deck`'s own
documented refusal; swallowing it would emit a deck with the ports silently
missing, at rc 0.

### ⚠ `ports` IS A ROW KEY WITHOUT A THIRD ENTRY IN `ase::analysis_nonsetting_keys`

The brief says *"prefer a per-row key on the `sp` analysis row (D4 licenses `id`
and `x` and nothing else, so a third needs an argument)"*. **The argument is that
it does not need to be a third one.**

`ase::analysis_nonsetting_keys` licenses a key on **every row of every type of
every simulator** — which is why row NS1 of `test_ase_core.tcl` asserts the list
literally as `{type enabled x id}`. `ports` is licensed on **ONE type**, because
**one registry entry declares that that type carries a table**. So `ports` on a
`tran` row is still `unknownkey`, and a simulator whose S-parameter analysis wants
a different word gets one without touching core. It is exempt for `x`'s reason and
not for `id`'s: **it actually emits.** Row SK1; sabotage **s9** puts it in the
blanket list and reds SK1, SK4, SR1 **and eight rows of `test_ase_core` including
NS1**.

### The two `needs` arms

* **`two_ports`** — core counts `ase::analysis_setup_rows` against the declared
  `min` and composes its sentence from the declared `noun`. **`fatal`**, and
  exempt from the static demotion: the demotion appends *"(read from the netlist
  text, which cannot see inside an .include)"*, and `portnum` **cannot be read
  back from a netlist at all** (`vsrcask.c:160-162` answers `rValue` for an
  `IF_INTEGER`), so that caveat would be a lie about why ASE-L is unsure. Row SN2
  is that claim.
* **`setup_check`** — core delegates to the declared `check` hook and passes its
  triple through, exactly as `tf_out` delegates to `out_decompose`. An adapter
  with no `check` leg gets no opinion.

### The registry validator

`ase::analysis_schema_errors` gains `badsetup`, `nosetupkey`, `setupkeyclash`,
`nosetuplines`, `badsetuplines`, `badsetuphook`, `badsetupmin`, `badsetupfield` —
the same rule `salvage` and `resultvecs` already carry (issue 1428's S35: *a key
read by nothing is a key checked by nothing*), for a key whose failure mode is the
same silence. **A `lines` proc that is not a command answers `{}`, the ports never
reach the deck, and ngspice kills the whole run.** Row SK3, seven fixtures.

## What shipped — the CONTENT half (`ase::backend::ngspice`)

| proc | what it spells |
|---|---|
| `sp_port_field` | one field of one table entry, trimmed; `{}` for a malformed one |
| `sp_ports` | the table, through core's reader |
| `sp_alter_lines` | `alter <src> portnum = <n>` / `alter <src> z0 = <ohms>` |
| `s2p_file` | `<rundir>/<cell>_ase_sp<idx>.s2p` |
| `sp_export_lines` | `let Rbase = <z0 of port 1>` / `wrs2p <path>` / `unlet Rbase` |
| `sp_row_check` | six refusals and two cautions over the table |

And the `sp` registry entry: `emitorder 95`, `viewrank 25`, `resultvecs own`, six
fields, `emit {{role analysis tmpl {sp @sweep? @points @start @stop @donoise!}}}`,
`results {viewer {kind sweep}}`, two `plots` rows.

### ⚠ `z0` IS OMITTED WHEN THE TABLE LEAVES IT BLANK

Measured: two ports with `portnum` and no `z0` run at rc 0 and answer
`s_1_1[0] = 1.515152e-01,0.000000e+00` — `vsrctemp.c:76-77`'s 50 ohm default
applied silently. Writing `alter v1 z0 = 50` ourselves would be ASE-L inventing a
number the user never typed. Row SL2; sabotage **s7**.

### ⚠ THE TOUCHSTONE EXPORT IS `let`/`unlet`, NOT THE DOCUMENTED `.csparam`

APPENDIX §2.11 calls `.csparam Rbase=50` *"the workaround nobody promoted to a
recommendation"*. Four routes, measured on both binaries:

| route | Touchstone file | results file |
|---|---|---|
| nothing | **none**, `Error: No Rbase vector given` | — |
| `set Rbase = 50` | **none**, the same error — a shell variable is not a vector | — |
| `.csparam Rbase=50` | 8 lines, `# Hz S RI R 50` | `No. Variables: 20` |
| `let Rbase = 50` / `wrs2p` / `unlet Rbase` | **the same 8 lines**, `diff` empty past the `Generated by ngspice at` line | `No. Variables: 20` |
| `let` **without** the `unlet` | the same 8 lines | **`No. Variables: 21`**, a `16 rbase notype dims=1` column |

`let`+`unlet` is **per row, per Z0** and leaves the deck body untouched;
`.csparam` is a deck-level card and could not carry two `sp` rows with different
port-1 impedances. Rows SL4/SL4b/SL5; sabotage **s8** drops the `unlet` and reds
SL4 **and both end-to-end rows**, because SE1 asserts the 20.

### ⚠ `Rbase` IS PORT 1's IMPEDANCE, NOT THE FIRST TABLE ROW'S

The header is `# Hz S RI R <Rbase>` and `span.c:74-178` refers the whole file to
port 1, so a table listing port 2 first must still write port 1's number. Row
SL4b; sabotage **s11**.

## Where the lines land in the deck

```
  <this analysis's option lines>            opt_scope_lines / suppress_lines
  alter v1 portnum = 1                      <- setup `lines`
  alter v1 z0 = 50
  alter v2 portnum = 2
  alter v2 z0 = 50
  <checkpoint arm, if any>
  <the verbatim hatch>                      <- issue 1419, IMMEDIATELY above
  sp dec 3 100meg 1g
  if $?sim_status = 0 … / if $sim_status ne 0 … quit 1
  let Rbase = 50 / wrs2p … / unlet Rbase    <- setup `post`
  remzerovec
  echo "PLOT sp 1 |$curplotname|" >> …
  write …
```

**The ports go with the OPTION lines, not adjacent to the card**, and that is
issue 1419's constraint honoured rather than broken: rows VB1/VB2 assert the hatch
is immediately above its own analysis line, and issue 1433 paid a sabotage to
learn that anything wedged between them reds both. It is also the right order for
a second reason: **the hatch is the user's own last word**, so a user who writes
`alter v1 z0 = 75` into it wins over the table. Rows SL3/SL3b/SL5/SL6.

---

## Both arms, before and after, from the `RESULT:` line

Hard timeout (`timeout 300`) on every one of the twelve runs.

| suite | headless BEFORE | headless AFTER | display BEFORE | display AFTER |
|---|---|---|---|---|
| `test_ase_core` | ALL PASS (636) | **ALL PASS (636)** | ALL PASS (636) | **ALL PASS (636)** |
| `test_ase_meas_1443` | ALL PASS (113) | **ALL PASS (113)** | ALL PASS (113) | **ALL PASS (113)** |
| `test_ase_preflight` | ALL PASS (235) † | **ALL PASS (235)** | ALL PASS (235) † | **ALL PASS (235)** |
| `test_ase_persist` | ALL PASS (49) | **ALL PASS (49)** | ALL PASS (153) | **ALL PASS (153)** |
| `test_ase_dialogs` | ALL PASS (37) | **ALL PASS (37)** | 1 FAILED (362) | **1 FAILED (362)** |
| `test_ase_sp_1452` | — | **ALL PASS (41)** | — | **ALL PASS (41)** |

† **`test_ase_preflight` is not in the driver's baseline list and its BEFORE cell
is a reconstruction, not a run I took.** After the `src/ase.tcl` change and before
the fixture edit it printed `8 FAILED (227 passed)` — 227 + 8 = 235, the same
total, and the eight are the PF222/PF232j rows whose fixture was `sp`. Nothing
else in that file moved. Take it as 235 with that caveat, or re-run it against
HEAD to get the number first-hand.

**The one display red is `G2sens`, issue 1436, standing** — the driver's stated
baseline, unchanged, and it names `sens` and nothing of this stage's.

**No count moved.** `test_ase_core` is 636 both before and after: eighteen rows
**moved** and none were added, because eighteen rows in three suites used `sp` as
their stand-in for *"a type this adapter cannot drive"*. They are all `pss` now —
**the last probe-only type in the shipped registry**, so this is the last time that
fixture can move without a fixture backend, and the two rows that said so in as
many words (`TF3b`, `D7e3`) have now been right twice.

Ten more ASE suites, headless, all green and none of them touched:
`test_ase_simreg_0931` 117, `test_ase_simcaps_0948` 199, `test_ase_optier_0963`
108, `test_ase_simdlg_0937` 5, `test_ase_options_1437` 75,
`test_ase_predeck_1439` 78, `test_ase_optsheet_1441` 62,
`test_ase_effective_1442` 92, `test_ase_current_repair` 51,
`test_ase_result_case` 31.

### ⚠ THE END-TO-END LEG, WHICH IS THE ONE ISSUE 1449 ASKED FOR

Section **SE** is the only part of this work that starts a simulator, and it exists
because *two halves of a feature tested in different suites never meet*. It renders
the deck ASE-L writes for a bench whose two sources are **ordinary V sources
declaring no port anywhere**, runs it, and reads the answer back:

```
ok:   SE1/apt   … records both plots in the sidecar and puts an S-parameter matrix
                  in the results file
ok:   SE2/apt   … the operating point plot holds the un-promoted circuit
ok:   SE1/fork  …
ok:   SE2/fork  …
```

rc 0 on both; sidecar `PLOT op 0 |Operating Point|` / `PLOT sp 1 |SP Analysis|`;
20 vectors in the SP plot; `# Hz S RI R 50` on line 4 of the `.s2p`. **The S_1_1
match is case-INSENSITIVE and the spelling is reported**, because the two binaries
disagree about it — a case-sensitive row would be green on the development
reference and red on the binary a downloading user has.

## The `.state` byte-identity measurement

```
$ ./src/xschem --nogui --pipe -q --nolog --script /tmp/sp9/p6.tcl
TRACKED=104  NOT-BYTE-IDENTICAL={}  sp-rows=0  ports-keys=0
SEED={type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}

$ git status --short ihp-sg13g2/
                                          (empty)
```

104 tracked files, **zero** that do not re-serialize byte-identically, **zero**
committed analysis rows of type `sp`, **zero** carrying a `ports` key, and
`ase::state_default` still seeds exactly four rows because `sp` declares no
`seed_enabled`. The four committed S-parameter benches still read
`{type op enabled 0} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}`
— **enabling `sp` on one of them is a user gesture, not a migration.** Row SC1;
`test_ase_core` CP7 is the same measurement from the other suite.

**And a bench that DOES carry a table survives the trip**, with the declared
default still unwritten: row **SC2** saves → loads → saves an `sp` row carrying
`ports` and `id`, compares the two files byte for byte, and asserts that the word
`sweep` **does not appear in the file** even though the field declares
`default dec`. That is the brief's *"target a type with a declared default"*: a
serializer that back-filled defaults on load would write `sweep dec` into the file
and every committed bench would move the next time anything touched it. **SC2b** is
its control — one byte changed in the table and the comparison disagrees.

## What changed, with anchors

### `src/ase.tcl` — **23802 → 24409** (+607)

| section | what |
|---|---|
| `ase::analysis_setup{,_key,_rows,_emit}` (~:5083–5127) | the four core readers, immediately below `ase::analysis_cards` |
| `ase::analysis_emit_check` (the `$known` block) | the declared setup key, for that type only |
| `ase::analysis_schema_errors` | `badsetupfield` + the `_sfl` consumed-fields walk; the eight-way `setup` validation beside the `resultvecs` check |
| `ase::needs_eval` (~:11769, ~:11823) | `two_ports` and `setup_check`, above `saves_resolve` |
| `render_deck`'s emit loop (~:19558) | the setup `lines` leg, below the option lines and above the checkpoint arm |
| `render_deck`'s emit loop (~:19713) | the setup `post` leg, below the `$sim_status` guard and above `remzerovec` |
| `analysis_types`' header comment | *seven → one* probe-only type, and why `sp` still declares `baseline 0` |
| the `sp` comment block (before `return [dict create`) | the emit-order, viewrank, resultvecs, folding, salvage and seed measurements |
| the `sp` entry (~:22345) | the registry row |
| `sp_port_field` … `sp_row_check` (~:23506–23700) | the adapter, below `sens_is_ac` |

Line numbers are parenthesised hints; the proc and section names are the citation.

### The suites

| file | what |
|---|---|
| `tests/headless/test_ase_sp_1452.tcl` | **new**, 41 checks, sections SR SL SN SK SM SC SE |
| `tests/headless/test_ase_core.tcl` | eighteen rows moved, none added: D7a–D7e4, D7k, AG5, EM7, AC5, TF3b, PZ3b, SE3b, CP6, GP1, MP15, WD1, WD3c. **D7e3/D7e4 stop borrowing a second shipped type** and name `hb` — a real ngspice verb that will never exist (`HBinfo` is `extern`-declared and defined nowhere), so the row now covers one of EACH class and never moves again |
| `tests/headless/test_ase_meas_1443.tcl` | **DK5/DK5b**, rewritten — see below |
| `tests/headless/test_ase_preflight.tcl` | PF222a–e, PF222g–h, PF232j: the unrenderable fixture `sp` → `pss` |
| `tests/run_regression.tcl` | `test_ase_sp_1452` added to `hcases`, with a `dcases` comment carrying measured numbers |

### ⚠ DK5 WAS PASSING FOR THE WRONG REASON, AND ITS OWN CONTROL CAUGHT IT

`test_ase_meas_1443` DK5 asserts *"a measurement that would segfault the simulator
refuses the deck"* on an `sp` row. Its refusal sentence ends *"nothing was
rendered"* — **and so does the `two_ports` precondition's.** The moment `sp` became
renderable, DK5's fixture (an `sp` row with no ports) was refused by the
PRECONDITION and DK5 went on passing while measuring the wrong refusal. **DK5b, the
non-vacuity control, went red** — which is a control doing exactly its job.

Both rows now carry a two-port table, so the analysis is fine and the only thing
left to refuse the deck is the measurement. DK5 asserts the sentence names
`measurement 'a'`; **DK5b is now stronger than it was** — the safe kind RENDERS,
and the deck really carries `meas sp a MAX` and `alter v1 portnum = 1`.

---

## ⚖ R9 — WHAT WAS CONSUMED UNCHANGED, AND WHAT IS NEW

Filed as **`owed.sh add rule 1452`** at the moment it was incurred, pointing at
`doc/claude/issues/1452-*.md`. The entry is stamped `repo:/home/analog/dev/xschem-claude`.

### Consumed unchanged (already the user's, from `ac`/`noise`/`disto`)

`Sweep type`; `Points per decade` / `Points per octave` /
`Number of points (2 gives ONE point)`; `Start frequency`; `Stop frequency`; and
`lin_points`' own caution and fix, verbatim.

### New — every one of them ⚖ R9's

**Two field labels:**

1. `Noise figure (2 ports only)`
2. `Write Touchstone S2P`

**One precondition sentence and its fix, composed by core from the registry's
declared `min` and `noun`** (so it reads for any number of ports):

3. `this analysis needs at least 2 ports and names 1`
   → `add 1 more port -- ports are assigned at run time, and nothing is written to your schematic`
4. `this analysis needs at least 2 ports and names 0`
   → `add 2 more ports -- ports are assigned at run time, and nothing is written to your schematic`

**Six sentences from the adapter's rules over the table:**

5. `port 2 names no source, so nothing promotes it and the run dies before it starts`
   → `name the voltage source this port drives, or delete the row`
6. `port 'v1' has the number '0', and a port number must be a whole number of 1 or more`
   → `number the ports 1 upwards, in the order the matrix reports them`
7. `port 'v1' has Z0 '0'. A Z0 of 0 or less turns that source back into an ordinary source, and the simulator then blames a DIFFERENT port for 'incorrect port ordering'`
   → `give every port a Z0 greater than 0, or leave Z0 empty for the 50 ohm default`
8. `two ports share the number 1`
   → `give every port a different number, 1 upwards with no gaps`
9. `the port numbers are 1, 3 -- they have to run 1 to 2 with no gaps`
   → `renumber the ports 1 upwards, in the order the matrix reports them`
10. `the noise figure is computed for exactly 2 ports and this analysis has 3, so NF, NFmin, Rn and SOpt will not be in the results`
    → `switch the noise figure off, or reduce the analysis to 2 ports`
11. `a Touchstone file holds exactly 2 ports and this analysis has 3, so only ports 1 and 2 will be written`
    → `reduce the analysis to 2 ports, or read the file as the 2-port it is`

⚠ **Sentence 3/4's fix carries §9a's own sentence in lower case.** PLAN.md §9a
ratifies *"Ports are assigned at run time. Nothing is written to your schematic."*
as the **Ports table's** caption, which is the GUI half's to ship. The fix clause
here says the same thing in a refusal's voice; if the user rules on §9a's wording
the two should move together.

⚠ **`Noise figure (2 ports only)` deliberately does NOT uppercase "ports".** The
house rule is *acronyms* uppercase; `ports` is a word. `S2P` is a file-format
acronym and is uppercase.

**Batch with 1426, 1427, 1428, 1429, 1430, 1432, 1433, 1434, 1435, 1437, 1439,
1441, 1442, 1443 and 1451, which are all still waiting.**

---

## THE SABOTAGE CAMPAIGN

Twelve, each applied to a **pristine `cp`** of `src/ase.tcl`, each restored by
`cp` with an **md5 compare** (`49646a53914db0824a492c051d701116`, verified equal
after the last one). **Acceptance is a name+status diff, never a count.**

| # | sabotage | what reddened |
|---|---|---|
| **s1** | the promotion lines are emitted **after** the `sp` card | `SL3` `SL3b` **`SE1/apt` `SE1/fork`** |
| **s2** | `two_ports` demands ONE port instead of two | `SN1` `SN2` |
| **s3** | `lin_points` dropped from `sp`'s `needs` | `SN6` |
| **s4** | the reconciliation compares plot names **case-sensitively** | `SM3` `SM4` |
| **s5** | `sp` emits **before** `op` (`emitorder 25`) | `SR4` `SR4b` |
| **s6** | `resultvecs own` removed | `SL7` `SM5` |
| **s7** | a blank Z0 emits a `z0` line anyway | `SL2` |
| **s8** | the export leaves its `Rbase` vector in the plot | `SL4` **`SE1/apt` `SE1/fork`** |
| **s9** | `ports` becomes a blanket non-setting key | `SK1` `SK4` `SR1` **+ `test_ase_core`: `CK26b` `CP5` `CP6` `EM9` `GP1` `MP14` `NS1` `WD9b`** |
| **s10** | the contract stops declaring the fields it consumes | `SK4` `SR1` |
| **s11** | `Rbase` from the first table row instead of port 1 | `SL4b` |
| **s12** | the ports check stops looking at Z0 | `SN4` `SN4b` |

**No survivors.** The brief's five minimum sabotages are s1, s2, s3, s4 and s5.

### ⚠ TWO SABOTAGES FOUND DEFECTS IN THE SUITE ITSELF, AND BOTH ARE FIXED

* **s1 reddened `SL3b` but NOT `SL3`.** `sp_at` answers **-1** for a line that is
  not in the deck, and `-1 < 12` is TRUE — so SL3's *"the ports are above the
  card"* term passed with the promotion lines **removed altogether**. That is
  failure mode 3 (*an extractor that returns nothing*), the one this batch has hit
  eleven times. SL3 now carries three `>= 0` terms of its own, and s1 reds it.
* **s10 killed the suite at rc 0 with no `RESULT:` line.** `--nogui --pipe` exits
  **0** on an uncaught mid-script Tcl error, and one bare `dict get` on a key the
  sabotage had just removed took the whole file down — a "pass" indistinguishable
  from a pass. Every optional-key read now goes through a total `s_dget`, and the
  sabotage harness itself now scores a missing banner as `!!NO-BANNER-SUITE-DIED`.
  **This is the banner rule arriving from inside a suite rather than from a
  driver.**

### The four ways a row fails to fail, answered

1. **fixtures that never disagree** — SM1 and SM2 are the same evaluator on the
   same file with the registry changed; SC2b changes one byte and the comparison
   disagrees; SK3's first term is a *well-formed* contract so an empty registry
   cannot be mistaken for a clean one, and **SK3a** proves the fixture backend is
   really read.
2. **position asked where the mechanism is last-writer-wins** — SL3 asks three
   positions and their existence; SL5 asks the export's three neighbours; SR4 asks
   the emit order under **both** variants and SE2 asks its physical consequence.
3. **an extractor that returns nothing** — SL3b is SL3's positive control (five
   `alter` lines and one card, counted); SE1 reports the vector spelling it found;
   SK5 lists the ten types that declare no contract.
4. **a sabotage missing from the generator** — twelve, covering every new proc,
   both new `needs` arms, both render_deck insertion points, the registry's four
   changed keys and the one core list.

---

## What I did NOT ship, and why

* **`src/ase_window.tcl` and `tests/headless/test_ase_dialogs.tcl` — untouched**,
  as the brief requires. §9a's Ports table, §9b's surface, the matrix picker and
  Smith/polar are task 2.
* **PLAN.md §9's `lin_two` refusal.** See the corrections below.
* **A `look` debt and a `suite` debt.** Nothing here draws a pixel and the two arms
  are 41/41 with the same rows. Receipt 23 took the same position for Stage 8's
  deck half and said so.
* **A per-device noise contributor surface for `donoise`.** `NOISE_ADD_OUTVAR` is
  redefined under RFSPICE to merely increment a counter and there is no
  `onoise_spectrum` at all (APPENDIX §2.11), so there is nothing to offer.
* **`pwr`, `freq` and `phase` port parameters.** APPENDIX measures `phase` as
  having **no effect on anything** (`VSRCportPhaseRad` is written and read
  nowhere), and `pwr`/`freq` turn a port into a `PORT` waveform in transient. None
  of the three is needed for an S-parameter run and offering them would be three
  more fields with no measurement behind them.

---

## Corrections to the brief and to the plan

| | |
|---|---|
| **C1** | **PLAN.md §9's `lin_two` refusal is not shipped.** `lin_points` already exists, is a **caution** by ⚖ D47 (*"refusing removes a number the user typed into a form"*), and **its own comment says it "covers `sp` the day `sp` gets a sweep"** — written at issue 1442 in anticipation of exactly this. Shipping a second rule with a different verdict over the identical condition would be the eight-copies drift this batch exists to delete. Row SN6; measured `sp lin 2` → 1 point, `lin 3` → 3, `dec 2` → 3, `oct 2` → 7, `lin 1` → 1, both binaries |
| **C2** | **`sp` emits after `op`**, amending issue 0964 by measurement. The headline above |
| **C3** | **`sp` declares a `viewrank` where `tf` and `pz` do not.** `src/save.c:889` reads `else if(!my_strcasecmp(type, "sp")) type = "ac";`, so `xschem raw read <file> sp` answers 1 with `sim_type=ac`, 3 points, 80 vars. Withholding the key would make `plot_sim_type_reason` answer `no-viewer-mapping` for an sp-only bench — issue 1401's defect. **Below `ac`**, because with an `AC Analysis` plot and an `SP Analysis` plot in one file the reader loads the FIRST and refuses the second (*"Xschem requires all datasets to be saved with identical and same number of variables"*), and `ac` emits at 20 while `sp` emits at 95. The viewer shows AC; the label must say AC |
| **C4** | **The Touchstone export is `let`/`unlet`, not `.csparam`** — the table above. APPENDIX §2.11 and PLAN.md §9b should record it |
| **C5** | **The brief's `mislabel` premise is refuted** — the headline |
| **C6** | **`evidence/sp-stage9.md` §5's reading of the four committed benches is confirmed** and nothing was touched: `git status --short ihp-sg13g2/` is empty |
| **C7** | **The brief's file list did not anticipate `tests/headless/test_ase_preflight.tcl`.** Its PF222 fixture was built on `sp` being unrenderable and went red — eight rows. The tree's own precedent is explicit (`test_ase_core` TF3b's comment: *"rows PF222a-e and PF222h-j ... moved in the same commit as this one"*), and a standing red is a defect, not furniture. **I edited it, and this is me saying so at the moment of departing** |
| **C8** | **`test_ase_dialogs.tcl` row GN1b is now imprecise and I did not touch it** (the brief forbids it). Its title says *"the **two** unrenderable cells"* and `sp` is no longer one of them — but it is still **green**, because `sp` reads `absent unmeasured` with nothing measured and a cell in that state also carries a sentence. It is an accuracy debt for the GUI half, not a red |
| **C9** | **A suite's own death is invisible at rc 0.** `--nogui --pipe` exits 0 on an uncaught mid-script Tcl error, so a sabotage harness that reads only FAIL lines and the exit code scores a dead suite as a pass. Measured here, on sabotage s10. Any sabotage harness in this batch wants a banner check |

---

## ⚠ A FINDING THAT IS NOT MINE AND IS NOT FIXED: THE USER'S *OPEN RECENT* IS TEN PROBE DECKS

Noticed while checking that this task had touched nothing of the user's.
**`~/.xschem/recent_files` holds ten entries and every one of them is an ASE-L
capability-probe scratch deck**, measured 2026-09-13 14:35:

```
$ tr ' ' '\n' < ~/.xschem/recent_files | head -12
set
recentfile
{/home/analog/.xschem/simulations/.ase_probe/p3438206_3/probe_a.sp
 /home/analog/.xschem/simulations/.ase_probe/p3438206_2/probe_a.sp
 /home/analog/.xschem/simulations/.ase_probe/p3438206_1/probe_a.sp
 /home/analog/.xschem/simulations/.ase_probe/p3390969_3/probe_a.sp
 …
 /home/analog/.xschem/simulations/.ase_probe/p3387149_3/probe_a.sp}

$ ls ~/.xschem/simulations/.ase_probe/ | wc -l
0
```

**The file is not empty and nothing was destroyed — it was FILLED.** And the ten
paths point at directories that no longer exist, because the probe cleans up after
itself (`ase::cap_workdir_done`). So *File > Open Recent* is ten dead links. That
is issue **0924**'s class arriving from the other direction: not a stale binary
emptying the list, but a *probe* filling it.

**Four pids are in it** — `p3387149`, `p3388935`, `p3390969`, `p3438206` — so it
predates this task; only the last is mine. **What is measured about the
mechanism:**

* `xinit.c:3546` sets `no_recent_files` from
  `cli_opt_nogui || cli_opt_pipe || cli_opt_norecent`, and its own comment says
  the suppression lasts *"only for the DURATION of the `--script` body … and
  restored before the event loop"*.
* So a `--nogui --pipe -q --nolog` run never reaches an event loop and **cannot**
  record. **Verified by md5**: one such run either side of the check leaves
  `2b12704f963b74af50ab3d48a554e91a` and the mtime unchanged.
* A **`--pipe` run WITH Tk** — which is what `devdisplay.sh exec ./src/xschem
  --pipe -q --nolog …` is, and what `run_regression.tcl`'s whole `dcases` arm is —
  does reach the event loop, the gate is lifted, and anything loaded afterwards
  records. A live capability probe loads `probe_a.sp`.

**I did not repair it.** The standing rule is *never* read-modify-write anything
under `~/.xschem/`, and a repair is exactly that. Flagging it for the driver:
which display-arm suite runs a live probe, and whether `--norecent` belongs on
`devdisplay.sh exec`'s line or the gate belongs on the whole session for a
`--script` run, are both decisions above this task.

---

## Debts

⚖ **R9 — filed as `owed.sh add rule 1452`**, listed verbatim above. The ledger was
**backed up first** (`cp -a ~/.claude/xschem_owed /tmp/sp9/owed_backup_142616`),
per CLAUDE.md's warning that op-wcard's copy can still destroy this clone's
entries in silence. Count after: **168 rule, 62 look, 10 suite**.

⚠ **AND THE UNSTAMPED-ENTRY CHECK IS NOT CLEAN, WHICH IS EVIDENCE AND NOT MINE TO
CLAIM.** CLAUDE.md says an unstamped entry can only have arrived one way — another
clone's older `owed.sh` writing over something. Measured **2026-09-13**, before my
`add`:

```
$ /usr/bin/grep -L '^repo:' ~/.claude/xschem_owed/{rule,look,suite}/*
/home/analog/.claude/xschem_owed/rule/1357
/home/analog/.claude/xschem_owed/rule/1357@xschem-claude
/home/analog/.claude/xschem_owed/look/hier_pdf_nav_1357_H6.1789071932.2875683
/home/analog/.claude/xschem_owed/suite/test_hier_pdf_links_1333
```

Four entries, where the 2026-09-10 measurement in CLAUDE.md printed **nothing**.
I have **not** claimed them for this clone and have **not** cleared anything.
`cleared.log` is where the pre-image would be if this clone's script did it.

No `look` debt and no `suite` debt — the reasoning is in *What I did NOT ship*.

⚖ **R4 is untouched**: nothing was seeded, `ase::state_default` still seeds four
rows, and there is no `seed_enabled` anywhere in this diff.

---

## Testing discipline

* **Both binaries**, on every ngspice fact: `/usr/bin/ngspice` (apt 45.2) and
  `/home/analog/dev/ngspice/build-ver_50/src/ngspice` (the fork). **Every single
  measurement in this receipt was identical on the two**, including the ones that
  decided the design. The one place they differ is the rawfile's vector
  capitalisation, and that difference is itself a measurement here.
* **No bare `xschem`, ever.** `./src/xschem` or `tests/headless/devdisplay.sh exec
  ./src/xschem`.
* **`--nolog` on every launch. Never `--logdir`.**
* **Nothing under `~/.xschem/`.** All scratch work in `/tmp/sp9`, all suite scratch
  through `tests/headless/scratch.tcl`.
* **No simulation on any bench under `sky130A/`**, and none under `ihp-sg13g2/`
  either — those were read, never run. The one bench this stage runs is a
  five-element attenuator built in the suite's own scratch directory with an
  explicit `rundir`.
* **`tests/run_regression.tcl` was NOT run** — T1 is the driver's and runs solo
  (issue 0990).
* **Nothing committed, staged, stashed, restored, cleaned or pushed.** The tree is
  dirty and the file list is below.
* **`timeout 300` on every suite run**, `timeout 60/120` on every ngspice probe.
* **No new `src/*.tcl` file**, so no `./configure` re-run and no
  `grep -c <newfile> src/Makefile` obligation (issues 0423/0424).

---

## For the driver

**Changed, tracked:**

```
 doc/claude/issues/NUMBERING.md        |   6 +-      (1452 recorded, pointer -> 1453)
 src/ase.tcl                           | 623 +-
 tests/headless/test_ase_core.tcl      | 159 +-
 tests/headless/test_ase_meas_1443.tcl |  44 +-
 tests/headless/test_ase_preflight.tcl |  25 +-
 tests/run_regression.tcl              |  17 +-
```

**Added, untracked:**

```
 doc/claude/issues/1452-an-s-parameter-bench-whose-state-could-not-say-sp.md
 tests/headless/test_ase_sp_1452.tcl
 doc/claude/ase_analyses_batch/receipts/32-stage-9-sp-deck.md
```

**Pre-existing untracked, not mine:** `.xschem/`, `doc/claude/rdw_lists_batch/`,
`doc/claude/rdw_sim_batch/`,
`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/`.

**Suggested commit sentence:**

```
feat(1452): an S-parameter bench whose state could not say sp
```

**Three things to carry to the GUI half's brief:**

1. **The ports table's shape is `{src <name> num <n> z0 <ohms>}`**, stored under
   the `ports` key of the `sp` analysis row, with `z0` optional and blank meaning
   *the simulator's own 50*. Everything that validates it is already shipped —
   `sp_row_check` — so the widget's job is to collect, not to judge.
2. **Row SM5 is a trap laid for §9b's matrix picker.** It asserts that `sp`
   declares **no** `vectors` proc. The day the picker adds one it must be
   case-insensitive (`S_1_1` on the fork, `s_1_1` on apt 45.2) and SM5 must be
   rewritten to say so, deliberately, rather than deleted.
3. **`test_ase_dialogs` GN1b's title is now imprecise** (C8) and is the GUI half's
   to correct, in the commit that touches that file.

---

## Commands, for the driver to re-run

```sh
cd /home/analog/dev/xschem-claude

# both arms, every affected suite, with a hard bound
for t in test_ase_core test_ase_meas_1443 test_ase_preflight \
         test_ase_persist test_ase_dialogs test_ase_sp_1452; do
  timeout 300 ./src/xschem --nogui --pipe -q --nolog \
    --script tests/headless/$t.tcl | grep -E '^RESULT'
  timeout 300 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog \
    --script tests/headless/$t.tcl | grep -E '^RESULT'
done

# the .state corpus, byte for byte
./src/xschem --nogui --pipe -q --nolog --script /tmp/sp9/p6.tcl   # or SC1 in the suite
git status --short ihp-sg13g2/                                    # must be empty

# the end-to-end leg against a different pair of binaries
ASE_SP_NGSPICE=/path/a:/path/b timeout 300 ./src/xschem --nogui --pipe -q --nolog \
  --script tests/headless/test_ase_sp_1452.tcl | grep -E 'SE1/|SE2/|SKIPPED'
```

```sh
# the promotion route, on either binary, outside the repository
cd /tmp && cat > sp.cir <<'EOF'
* two-port attenuator, ORDINARY sources
v1 in 0 dc 1 ac 1
v2 out 0 dc 0 ac 0
r1 in mid 50
r2 mid 0 50
r3 mid out 50
.control
op
echo OP-FIRST
print v(in)
alter v1 portnum = 1
alter v1 z0 = 50
alter v2 portnum = 2
alter v2 z0 = 50
sp lin 3 100meg 1g
echo SP-SECOND
print s_1_1[0]
.endc
.end
EOF
/usr/bin/ngspice -b sp.cir
/home/analog/dev/ngspice/build-ver_50/src/ngspice -b sp.cir
#   -> OP-FIRST  v(in) = 1.000000e+00
#      SP-SECOND s_1_1[0] = 2.500000e-01,0.000000e+00
```
