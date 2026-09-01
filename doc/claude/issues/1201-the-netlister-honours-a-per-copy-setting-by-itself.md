# 1201 - the netlister must honour a per-copy setting by itself

**Branch:** annotate
**Status:** **FIXED** and committed on `annotate`, 2026-08-31, item S6 - for the
defect this file is named after. **SIX defects the verify pass measured inside
the new behaviour are NOT fixed and are filed separately as [[1202]], [[1203]],
[[1204]], [[1205]], [[1206]] and [[1209]]; the new suite's own path fragility is
[[1208]].** See "WHAT IS STILL OPEN" at the foot of this file. Seven rulings are
on the user's queue and none has been ratified.
**Filed by:** item S6, RED pass, 2026-08-31

## What the user sees

A designer opens a schematic, clicks one copy of a cell, and types a setting on
it -- `modelp=pfet_01v8_lvt` on two of the five passgates on the shipped
sky130 bandgap sheet. They press netlist. The deck that comes out builds all
five copies out of the ordinary device. The setting they typed reached the
simulator nowhere.

The only way to make it work today is to ALSO type a `schematic=<some name>`
attribute on the same copy, inventing a name by hand that no other copy asks
for. In Cadence the netlister does that for you and there is no user-typed
token for it.

## Where the rows are

`tests/headless/test_auto_specialize_1201.tcl` -- the acceptance rows AS1..AS32.
`tests/headless/test_unused_attr_0970.tcl` -- UB1 rewritten, UB12 added.

## Stub

Full write-up is owed by the implementing pass. This file exists to claim the
number.

## RED PASS, 2026-08-31 -- what is on record

Measured with the already-built `src/xschem` at HEAD `a499b47e`. No `make` was
run and no file under `src/` was touched; `grep -rn SABOTAGE src/` is empty.

### The new suite

`tests/headless/test_auto_specialize_1201.tcl`, registered once in
`tests/run_regression.tcl`'s `hcases` and once in `tests/headless/full_audit.sh`'s
`nogui_tests`, dual banner. Both arms agree exactly:

| arm | result |
|---|---|
| `--nogui --pipe -q --nolog` | `RESULT: 14 FAILED (19 passed)` |
| `devdisplay.sh exec ... --pipe -q --nolog` | `RESULT: 14 FAILED (19 passed)` |

Red now, and each for the reason the measurement recorded, not for a typo:
AS1, AS2, AS4, AS8, AS9, AS10, AS11, AS12, AS23, AS24, AS25, AS28, AS29, AS30.

Green now and green afterwards -- the controls the sabotage pass exists to
redden: AS3, AS5, AS6, AS7, AS13-AS22, AS26, AS27, AS31, AS32.

### Baselines pinned by measurement, not by assumption

* AS6 -- the COMMITTED bandgap deck fingerprint `4b48fcb4`. Verified stable
  across four separate processes (different pids, different scratch dirs); the
  deck names source paths only, never the output directory.
* AS26 -- the six shipped decks this change could reach:
  `4b48fcb4 35747644 4d069178 33ac9ad9 13cf2ab2 1566f812`
  (sky130_tests and sky130_tests_ase copies of bandgap, tb_bandgap and
  tb_bandgap_opamp).
* AS27 -- six shipped benches, zero lost-setting lines, 21 cell bodies between
  them.
* AS20 -- the guard sheet holds 4 cell bodies today.
* AS22 -- Spectre: 2 cell bodies. Verilog: 3 modules.

### Two measurement traps, both hit and corrected while writing the rows

1. **The top block.** Keying deck results by instance name collapses the
   bandgap top sheet's `x3` with a DIFFERENT `x3` one level down inside
   `passgate_nlvt`, which carries its own `schematic=` attribute. Scored that
   way, the headline acceptance criterion reads as ALREADY SATISFIED. Every row
   reads the top-level block only, through `as_topblock`.
2. **The netlist type.** `xschem setprop netlist_type <x>` silently does
   nothing; the working spelling is `xschem set netlist_type`. AS22 reads the
   type back and asserts it took, so a Spectre row can never quietly measure
   SPICE.

### 0970 moved, and why

`tests/headless/test_unused_attr_0970.tcl`: `RESULT: 2 FAILED (65 passed)` on
both arms (67 rows, up from 66).

* **UB1 rewritten onto x9/W and its last clause INVERTED.** It used to demand
  the sentence contain `schematic=`; it now demands it does not. Red today,
  measured `{1 1 1 1 1 A}` against `{1 1 1 1 0 A}`.
* **The live-warning control moved from x5 to x9** in UB2, UB3, UB5, UB6, UB7
  and UB8. Those six used "and x5 is still accused" as the thing that reddens
  if somebody turns the diagnostic off. That control is only valid while x5's
  setting really is lost -- after this fix x5 stops being accused BECAUSE THE
  TOOL FIXED IT, and six rows would have gone red on the day the defect was
  cured. x9 sets `W`, which `uapass.sch` uses nowhere, so it stays genuinely
  lost on both sides.
* **UB12 added**: the fixture that proved the defect now proves the fix. Red
  today, measured `{0 0 sky130_fd_pr__pfet_01v8 sky130_fd_pr__pfet_01v8 1 1}`.

### PREDICTED CASUALTIES IN `tests/headless/test_op_annot.tcl` -- NOT EDITED

Baseline today, headless: `RESULT: ALL PASS (483 checks)`.

That suite's NM fixture puts `x5` on `nmtop.sch` as `nmpass` with
`modelp=pfet_01v8_lvt` and **no** `schematic=`, and `nmpass.sch` consumes
`model=@modelp`. That is precisely this issue's trigger, so after the fix `x5`
gets a cell body of its own and three rows change what they measure:

| row | line | expects today |
|---|---|---|
| NM2 | 16087 | `{pfet_01v8 pfet_01v8_lvt @m.x5.xm2.msky130_fd_pr__pfet_01v8}` |
| NM6 | 16141 | `@m.x5.xm2.msky130_fd_pr__pfet_01v8` |
| NM8 | 16192 | `@m.x5.xm2.msky130_fd_pr__pfet_01v8.zz9` |

NM7 (16156) is a unit test on `_subst_model` and is NOT affected. NM4 (the
explicit-`schematic=` case, x8) is NOT affected and is the byte-for-byte
control.

These were left alone deliberately. Re-pointing them onto `nmlit`/x9 -- the
case a separate cell body genuinely cannot fix, because that sheet writes the
model in as a literal -- is the right move, but the replacement values can only
be pinned against a real post-fix run. Pinning them from a prediction would
manufacture a red the next reader would chase. Re-pin per row; never weaken one
to "zero or more".

### The second surface nobody named

`op_annot::_why_model_differs` (`src/op_annot.tcl`) tells the designer the same
thing the netlister's warning does -- give this copy a `schematic=` attribute of
its own. **It has no test row anywhere in the tree today**; AS25 is the first.
Both sentences have to change together, or the tool fixes the problem and still
tells you to fix it yourself, in two places.

---

# GREEN PASS, 2026-08-31 -- what was built and what was measured

**Status: FIXED, on by default.** Built from HEAD `a499b47e` plus the RED-pass
test files. Files touched: `src/token.c`, `src/actions.c`, `src/spice_netlist.c`,
`src/scheduler.c`, `src/xschem.h`, `src/op_annot.tcl`, plus the three suites and
the two runners.

## What a designer sees now

They click two of the five passgates on the shipped sky130 bandgap sheet, type
`modelp=pfet_01v8_lvt` on them, and press netlist. The deck comes out with those
two copies built from a cell body of their own, holding the low-threshold
p-device they asked for; the other three keep the ordinary one. Nothing else is
typed on the sheet. The info window says, once:

> Note: on sheet .../bandgap.sch, x5 (a passgate) sets modelp=pfet_01v8_lvt, and
> the passgate drawing uses that setting inside it, so XSCHEM wrote a separate
> copy of passgate called passgate__modelp_pfet_01v8_lvt and pointed x5 at it.
> Any other copy of passgate on this design that asks for the same settings
> shares that one. You do not have to add anything to the sheet.

That line REPLACES a warning that used to fire on the same copy, so the info
window gets quieter, not noisier.

## When it fires -- both halves are required

1. the copy sets something the SPICE line it is written through never reads --
   the SAME classification the "your setting went nowhere" warning uses, not a
   second one; AND
2. the cell's OWN drawing uses that setting, as `sky130_tests/passgate.sch`
   uses `model=@modelp`.

Half 2 is what keeps the change small. "The SPICE line never reads it" alone is
true of misspellings and leftovers, and writing a cell body for those would put
cells nobody asked for into decks that are correct today.

## THE 653-SHEET BYTE-DIFF -- the measurement the brief demanded

Every shipped schematic under `sky130A/`, `gf180mcuD/`, `ihp-sg13g2/`,
`xschem_library/` and `xschem_libs_newsym/` was netlisted with the CURRENT
binary before the first edit, and again after the single `make`, and the decks
were fingerprinted and diffed.

| tree | sheets | decks changed |
|---|---|---|
| sky130A | 142 | **0** |
| gf180mcuD | 62 | **0** |
| ihp-sg13g2 | 103 | **0** |
| xschem_library | 183 | **0** |
| xschem_libs_newsym | 163 | **0** |
| **total** | **653** | **0** |

The BEFORE capture was re-run into a second directory and came back
byte-identical, so the harness itself is deterministic and the zero is not a
harness that answers the same thing twice.

**Why zero**: every shipped copy that would qualify already carries a hand-typed
`schematic=` -- bandgap x5/x6 (both copies of the sheet), tb_bandgap_opamp x6
and its gain_stage x3. GUARD AS-EXPLICIT sends every one of them down today's
path unchanged. So the feature ships ON by default; the brief's fallback (behind
a setting, default off) was not needed and is not implemented.

Harness: `scratchpad/s6diff/netall.tcl` plus one wrapper per tree. Volatile.

## What was built

### src/token.c -- the classification, written once and asked twice

* `resolve_netlist_format()` -- the four-step "which SPICE line is this copy
  written through" resolution, lifted VERBATIM out of `print_spice_element()`,
  which now calls it. GUARD AS-FMTRESOLVE. Row AS29.
* `ua_instance_eligible()` -- GUARD UA-TYPE and GUARD UA-POLY, lifted out of the
  head of `warn_unused_instance_attr()`, which now calls it. UA-POLY is GUARD
  AS-EXPLICIT as well: a copy that names its own cell keeps today's deck.
* `ua_token_lost()` -- the per-token exemption chain (UA-NAME, UA-STOP, the
  UA-POLY token names, UA-STOP2, UA-SYMNAME, then `ua_reach()`), lifted out of
  the warning's loop, which now calls it. Row AS28.
* `cell_body_reads_token()` -- GUARD AS-BODY. Reads the cell's own `.sch` from
  DISK, because at the moment the question has to be answered the sub-sheet is
  not loaded and will not be until the netlister descends, which is after the
  decision. Whole-token `@tok` test, never `strstr` -- a drawing reading
  `@model` must not answer a question about `modelp`. Cached per
  (symbol, token); the cache is dropped by `auto_spec_end()`.
* `lost_attrs_the_cell_body_reads()` -- the trigger in one answer, with the
  canonical sorted spelling of the setting set (GUARD AS-ORDER) and a
  human-readable one for the note.
* **GUARD UA-HONOURED** in `warn_unused_instance_attr()`: the warning stops
  accusing a copy the netlister has just repaired. Measured on the 0970 fixture
  before this guard existed: x5 and X7 got their cell body, the low-threshold
  device really was in the deck, and the tool still told the designer their
  setting had gone nowhere.
* **The advice text changed** (RULING D5-4, one `my_snprintf`). It no longer
  tells the designer to type a `schematic=` attribute naming a cell name nobody
  else uses -- the tool does that itself now. What survives is the population a
  separate copy genuinely cannot help: the cell's drawing does not use the
  setting anywhere.
* `unused_attr_elide()` is no longer static: issue 1201's note in actions.c goes
  through the same shortener, so no value a user types can push the last
  sentence off the end or split a note into two info-window entries.

### src/actions.c -- the mechanism

* `auto_spec_begin()` / `auto_spec_end()` bracket ONE SPICE netlist run
  (GUARD AS-MODE) and own three run-scoped tables: a memo keyed
  (symbol, property string), the canonical-set table that makes sharing correct,
  and the set of names already handed out.
* `auto_spec_qualifies()` -- GUARD AS-SYMBODY, GUARD AS-TMPLMODEL, GUARD
  AS-IGNORE, then token.c's classification.
* `auto_spec_name()` -- the name, or NULL. GUARD AS-CANON builds
  `<cell>__<setting>_<value>` folded to `[A-Za-z0-9_]`; GUARD AS-COLLIDE
  refuses a name already spoken for by a loaded symbol, by a name this run has
  handed out, or by a file on disk -- asked BOTH as a bare reference and as a
  reference inside the base symbol's own library, because that is where a
  neighbouring cell of the same family actually lives.
* `auto_spec_would_specialize()` -- the same question without the AS-MODE gate
  and without minting anything, for the annotation surface. See below.
* `get_additional_symbols()` and `get_sym_name()` both consult
  `auto_spec_name()` in their "the copy named no cell of its own" arm, so the
  `.subckt` line and the call line can never drift apart about what a copy is
  called.

### src/spice_netlist.c -- the window

`auto_spec_begin()` immediately before the TOP sheet's own
`spice_netlist(fd, 0)`, `auto_spec_end()` on the single exit tail.

**⚠ The begin MUST be there and not at `get_additional_symbols()`, and that is
measured.** Opened at `get_additional_symbols()` -- which is where the plan put
it -- the deck grew the specialised cell bodies while every top-level call line
above them still named the plain cell: bodies nothing called, and the designer's
setting still nowhere. The top sheet's call lines are written by
`spice_netlist(fd, 0)`, which runs BEFORE the `if(global)` block.

### THE THIRD SURFACE, WHICH NOBODY NAMED -- src/op_annot.tcl GUARD GB

`op_annot::model_netlist` works out the model name THE DECK will build a device
with, so the annotation can ask the results file for that device by the name the
simulator gave it. Its GUARD GB tested for one thing: does the enclosing copy
carry a `schematic=` attribute? That was the only way a copy's own setting could
reach the deck. **It is not any more.** Left alone, the annotation surface would
have asked the results file for a device under a name the deck never contained,
and the user's schematic would have got no numbers -- or worse, a save card for
a device the simulator does not have, which per `doc/claude/WIRING.md`'s own
warning can cost the whole raw file. RULING D5-1.

Measured on the real netlister, this build, with the fixture cell whose drawing
takes the model from a setting:

```
x5 net2 nmpass__modelp_pfet_01v8_lvt W_P=0.6
.subckt nmpass__modelp_pfet_01v8_lvt A  W_P=1
XM2 ... sky130_fd_pr__pfet_01v8_lvt ...
```

So the fix threads the NETLISTER'S OWN answer to the surface rather than letting
it assemble a second opinion:

* `descend_schematic()` calls `auto_spec_would_specialize()` for the instance
  the walk enters a level through -- the only moment that instance and its
  symbol both still exist -- and stores it in `Lcc.auto_spec`
  (`xctx->hier_attr[]`);
* `xschem globals` publishes it as `lcc[N].auto_spec=`;
* `op_annot::model_netlist` reads it with the accessor it already has.

Row AS33 is the structural half; row NM9 of `test_op_annot.tcl` is the
behavioural one.

`op_annot::_why_model_differs` also stopped telling the designer to type a
`schematic=` attribute. After this change it fires only where a separate copy
genuinely cannot help, so the advice is now about the cell's drawing, and it says
plainly that the numbers themselves are sound -- they are the ones for the device
the simulator really built.

## Rows, and the suites that moved

| suite | before | after |
|---|---|---|
| `test_auto_specialize_1201.tcl` (new) | 14 FAILED (19 passed) | **ALL PASS (34)** |
| `test_unused_attr_0970.tcl` | 2 FAILED (65 passed) | **ALL PASS (67)** |
| `test_op_annot.tcl` | ALL PASS (483) | **ALL PASS (484)** |

**AS33 added** to the 1201 suite (33 rows at the red pass, 34 now).

**Two rows in 0970 had to be rewritten and both got STRONGER, not weaker:**

* **UF10** anchored on `no other instance asks for`, a phrase in the MIDDLE of
  the old advice, so a line cut after it would still have passed. It anchors on
  the LAST WORDS OF THE LINE now, which is what the row was always about.
* **UF13** asserted the PRESENCE of the instruction issue 1201 deletes.
  Asserting that a tool still says a thing it must stop saying would have pinned
  the defect in place. It now asserts the two things that are true of the
  surviving population, plus -- as a fourth element -- that the old hand-typed
  instruction is GONE.

**Six rows in `test_unused_attr_0970.tcl` moved from x5/X7 to two new copies
x12/X13, and two were re-pinned:**

* **GC1, GC2, GC3, GC5** -- the "which transistor disagrees" sentence. Their
  own section comment said the witness "cannot be repaired away, because x5 and
  X7 here are deliberately left without a copy of the cell to themselves". That
  premise is exactly what this issue deletes: the netlister gives them one
  without their asking. The witness is `uaparm`, whose SPICE line passes the
  setting down as a `.subckt` parameter -- which SPICE cannot use for a model
  NAME -- so the disagreement there is permanent.
* **PD1 and PD2** -- the two shipped sky130 menu items. These did NOT move,
  because their subject ("both name the device the way the DECK does") is
  unaltered; the DECK changed under them. PD1 now demands the low-threshold
  spelling on all seven parameters of x5 and X7 and the plain spelling asked
  for **zero** times (it used to be a boolean, so it is stricter now); PD2's
  fixture results file carries the deck's spellings.

**Three rows in `test_op_annot.tcl` moved from x5 to a new copy x11, and one was
added.** x5 is repaired by this change, so NM2/NM6/NM8 would have gone red on
the day the defect they describe was cured. `x11` sits on a new fixture cell
`nmfmt.sym` whose SPICE line DOES read the setting -- so it is passed down as a
cell parameter, no separate copy is written, and a SPICE `.subckt` parameter
still cannot carry a model NAME into the body. That disagreement is permanent
and cannot be repaired away, which is issue 0965's own subject. **NM9 is new**
and pins what x5 became.

## Tier, all green -- and a count belongs to an arm (issue 0994)

Headless (`./src/xschem --nogui --pipe -q --nolog --script ...`): ase_core 182,
ase_final 80, ase_final_gf180 34, ase_cosim 341, annot_blank_cause_0909 27,
ase_view 32, ase_persist 17, ase_plot 30. Also ase_optier_0963 93 (the committed
bandgap, unmoved).

Dev display (`devdisplay.sh exec ... --pipe -q --nolog`, `:99`, openbox live):
ase_view 36, ase_persist 109, ase_plot 150, ase_window 228, ase_dialogs 174,
wave_viewer 401.

**T1** (`cd tests && tclsh run_regression.tcl`, run SOLO): 57 cases,
`results.log` 56 blocks, **every one `Total num fail: 0`**. Zero `FAIL` /
`GOLD?` / `RESULT?` / `FATAL` lines and zero launch failures (no
`couldn't execute`, no `exit 127`). Block count is 56 now, up one for the new
suite; the ZERO is the invariant.

No shipped `.sch` was edited: `git status` shows no change anywhere under
`sky130A/`, `gf180mcuD/`, `ihp-sg13g2/`, `xschem_library/` or
`xschem_libs_newsym/`.

## THREE THINGS MEASUREMENT CAUGHT THAT REASONING HAD NOT

1. **The window opens too late if it opens at `get_additional_symbols()`.** See
   src/spice_netlist.c above. The plan put it there; the deck came out with
   specialised cell bodies that nothing called.
2. **`get_cell()` hands back a static buffer.** GUARD AS-COLLIDE walks every
   loaded symbol calling `get_cell()` on each, so the cell name held for the
   note -- and, once GUARD UA-HONOURED was added, the cell name in the WARNING
   -- became the tail of whatever symbol happened to be last. The user was told
   their passgate was "a 130_fd_pr/pfet_01v8". Both are copies now.
3. **`get_sch_from_sym()` with an instance CONSUMES the one-shot descend
   override.** Its instance arm reads and immediately clears the Tcl variable
   `hi_descend_view_path` (doc/claude/specs/hi_descend.md). GUARD AS-BODY asks
   it a question, so asking with the instance would have eaten a user's "descend
   into this named view just this once" before the descend it was set for ever
   saw it. It asks with `-1`, which is also the right question: both callers
   have already established that neither the copy nor the symbol names a drawing
   of its own, so the answer is a property of the symbol alone -- which is what
   makes the cache key sound.

**And one wording defect the fixture caught.** A first draft of the annotation
sentence ended "since that drawing writes the model in by hand". On the
`.subckt`-parameter shape -- row GC1's own fixture -- that is simply untrue: the
drawing reads `model=@modelp` and the reason nothing reaches it is that SPICE
cannot carry a model NAME through a parameter. A claim about the designer's
circuit that nobody measured, RULING D5-1. The sentence names only what was
measured.

## THE SABOTAGE PASS SAID FAIL, AND IT WAS RIGHT -- NINE GUARDS NOTHING COULD SEE

A sabotage pass switched off one load-bearing line at a time, rebuilt, and re-ran
everything: 36 build-and-measure cycles. **Nine lines could be deleted with every
suite still green.** The product was not broken; the tests could not see it. The
worst of them had a row written for it that passed while the defect was on the
user's screen.

Every one of the nine is now witnessed, and every witness was **proved by a real
neutralize-build-measure cycle**, not by reading. Sixteen cycles, one guard per
build, each restore proved byte-identical before the next.

| what could be deleted | now caught by | how it was proved |
|---|---|---|
| the copy of the cell name in the note (`base[PATH_MAX]`, actions.c) | **AS23**, strengthened | reverted to the raw pointer: the note read `x2 (a 130_fd_pr/pfet_01v8)`. AS23 used to look for the word `aspass` anywhere in the sentence, and the invented name in the same sentence still had it -- **the row matched the wrong half of its own sentence**. It asserts the whole clause `x2 (a aspass) sets modelp=pfet_01v8_lvt` now. |
| the same copy in the warning (`sym_cell[PATH_MAX]`, token.c) | **AS35**, new | reverted: the warning read `instance xH2 (a 130_fd_pr/pfet_01v8) sets zzspare=7`. **The fixture had to be widened to see it at all**: with the cell as the only symbol on the sheet the walk that overwrites the buffer happens to end on that very cell, and the sentence comes out right whether the copy is there or not. A pin and a transistor placed after the two copies make the walk end somewhere else, which is the ordinary case on any real sheet. |
| GUARD AS-EXPLICIT, **either** of its two copies (the six skips in `ua_instance_eligible()`, and `if(!schematic_token_found)` at both `auto_spec_name()` call sites) | **AS40**, new, structural | each copy deleted alone: previously fully green, and the committed bandgap deck byte-identical, because the other copy covers it. The token.c one reads exactly like dead code. AS40 counts both. |
| `auto_spec_end()` throwing its answers away | **AS36** (behavioural) and **AS43** (structural) | netlist a sheet, edit the cell's own drawing on disk in the same session so it stops using the setting, netlist again. Restored: the copy correctly falls back to the plain cell. Emptied: it still calls the separate copy -- an answer read off a file that no longer says that. Also proved with **only** `lost_attrs_cache_clear()` removed. AS30 only ever counted that the two functions exist. |
| any one of GUARD AS-COLLIDE's four probes | **AS37** (behavioural, the `auto_spec_taken` limb) and **AS41** (structural, all four) | AS11 only ever saw the library-relative disk probe. The `auto_spec_taken` limb is the one that matters: AS37 places two copies asking for `pfet_01v8_lvt` and `pfet_01v8-lvt`, two different devices whose invented names spell the same once punctuation is folded. Without that probe both get one name and the deck holds two different cell bodies under it. |
| the `default_schematic` half of GUARD AS-SYMBODY | **AS39**, new | `asign`, the fixture that was there, has no drawing of its own beside it, so the classification refuses it for a second reason and AS18 holds with the guard gone. AS39 adds a symbol that says do-not-write-my-insides-out **and** has a drawing beside it that does use the setting. |
| the invented name's character folding and leading-letter injection | **AS38**, new | AS12 asks the same question of a cell called `aspass` set to `pfet_01v8_lvt` -- already a legal name before any of the code that makes it one has run. AS38 uses a cell called `9as-p` and a value `pfet_01v8-lvt`, and pins the answer `x9as_p__modelp_pfet_01v8_lvt`. Each of the three limbs deleted separately: red. |
| `inst = -1` and `fallback = 0` on `get_sch_from_sym()` in `cell_body_reads_token()` | **AS42**, new, structural | passing the real instance and `fallback = 1` was fully green. Neither is reachable headless: one swallows the user's one-shot descend-into-this-view choice, the other stops a netlist run to put a dialog box up on a machine with a screen. |
| `auto_spec_would_specialize()`'s trailing cache drop | **AS43**, new, structural | deleted: green. Only reachable by annotating, editing the cell and annotating again, which no headless deck can stage. |

Two more the pass called out, both fixed:

* **GUARD UA-HONOURED had no row in its own feature's suite** -- only `UB12` in
  `test_unused_attr_0970.tcl`. **AS34** is that row: the copy whose setting the
  tool honours gets exactly one sentence, and it is the note, not the accusation.
  Deleting the guard now reddens AS34, AS35 and UB12.
* **AS32 was weaker than it looked.** It counted a substring, so renaming the
  entry to `test_auto_specialize_1201_UNREG` unregistered the suite and left the
  row green. It matches a whole name now; the rename was driven and it reddens.

`as_cfunc` is the new machinery behind the four structural rows: the body of ONE
C function, comments already stripped. Grepping the whole file cannot see any of
these, because the sibling that masks the guard is in the same file.

**test_auto_specialize_1201 is 44 checks, was 34.** No product code changed in
this repair -- the tree is byte-identical to what the sabotage pass restored.

## NOT DONE, DELIBERATELY

**The S4b workaround stays on the user's bench.** Both committed bandgap sheets
still carry the hand-typed ` schematic=passgate_lvtp` on x5 and x6. The tool no
longer needs it, but taking it off would move a deck this item promises not to
move. On the ruling queue.

## RULINGS OWED -- the user has not ratified any of these

1. **DEFAULT ON.** Measured: 653 shipped decks, ZERO move. Shipped ON, per the
   Cadence framing. Ratify, or put it behind a setting that is off until you
   turn it on?
2. **SHOULD THE TOOL SAY SO?** One plain-English line in the info window per new
   cell copy, which REPLACES a warning that used to fire on the same copy, so
   total noise goes down and no window is forced open. Cadence does this
   silently. Say it once, or say nothing?
3. **THE NAME.** `passgate__modelp_pfet_01v8_lvt` -- the cell, then the setting
   that made it different, `_1` appended if anything already answers to that
   name. Rejected: an opaque `passgate__auto_7f3a1c9e`. The readable one is
   longer and appears in every simulator log and every `.subckt` line. Which do
   you want to read in a deck?
4. **SPICE ONLY.** The classification has only ever run for SPICE. Spectre, VHDL,
   Verilog and tEDAx keep today's behaviour exactly. Ratify, or should it reach
   the other four (a bigger change than this item)?
5. **THE THREE ADVICE SENTENCES.** The netlister's "did not reach the simulator"
   warning, the annotation surface's "the model differs" sentence, and the new
   note. All three are quoted above. Confirm the wording.
6. **`schematic=` BECOMES A COMPATIBILITY MECHANISM.** It keeps working and keeps
   PRIORITY over the automatic copy, so no existing sheet changes. You have said
   it goes away entirely when the Cadence Hierarchy Editor lands; nothing here
   makes that harder. Confirm it stays supported meanwhile.
7. **THE S4b WORKAROUND STAYS ON YOUR BENCH.** Both committed bandgap sheets
   still carry the hand-typed ` schematic=passgate_lvtp` on x5 and x6. Leave it,
   or take it off in a follow-up now the byte-diff is on the record?

---

# WHAT IS STILL OPEN - the verify pass found six defects INSIDE the new behaviour

Written by the write-up/commit pass, 2026-08-31, after re-confirming each one in
the shipped source. **None of them is fixed. All are filed.** They are recorded
here as well because a reader of this file needs to know that "FIXED" means the
headline defect, not the whole surface.

The write-up pass has no `make` (house rule: only the implement and sabotage
agents build), so every one of these was filed rather than patched. A product
change that cannot be built and measured is worse than a filed measurement.

| filed | what it is | class |
|---|---|---|
| [[1202]] | a copy that hand-types the exact cell name the netlister would invent silently gets the other copy's device. **EXPLICIT BEATS IMPLICIT, the brief's own hard requirement, is refuted as written** - and it is issue [[0982]]'s trap in new dress. | REGRESSION, silently wrong deck |
| [[1203]] | `<name>_<value>` joined by `__` is an ambiguous encoding, so two DIFFERENT setting lists produce one key and share one body. One copy loses both its settings with no diagnostic at all. | silently wrong deck |
| [[1204]] | `auto_spec_begin()` is unconditional at `src/spice_netlist.c:418`, but the `.subckt` bodies are written inside `if(global)` at `:477`. "Netlist current schematic only" therefore emits a call to a subcircuit that exists nowhere, while the note claims the copy was written. | REGRESSION, unusable deck |
| [[1205]] | `if(auto_spec_name(inst) && cell_body_reads_token(inst, p))` at `src/token.c:3580` short-circuits, so when the tool declines for a STRUCTURAL reason (AS-SYMBODY, AS-TMPLMODEL, AS-IGNORE, name exhaustion) `cell_body_reads_token()` is never called - yet the sentence below asserts its answer. RULING D5-1. | false statement to the user |
| [[1206]] | `modelp=` with an empty value mints a cell body byte-identical to the base, and a note about it. Nothing checks that a specialised body would actually DIFFER before writing it. | deck noise |
| [[1209]] | `get_sym_name()` now answers the synthesised name to every consumer inside the SPICE window, so `src/netlist.c`'s four pin-mismatch comparisons stop highlighting a specialised copy. | cosmetic, error path |
| [[1208]] | rows AS6 and AS26 fingerprint a whole deck including its `** sch_path:` header, so a clone of this repository at any other absolute path reds them. | test fragility |

**Ranked**: [[1204]] first - it is the one an ordinary user of this feature meets
by pressing an ordinary menu item, and the fix is a `global` gate that needs one
build and one row. Then [[1202]] and [[1203]], which are wrong-deck defects with
narrow triggers. Then [[1205]], which is on the user's screen every time the
tool declines for a structural reason. Then [[1206]], [[1208]], [[1209]].

**What this does NOT change about the shipped population.** The 653-sheet
byte-diff stands: zero shipped decks move, because every shipped copy that would
qualify already carries a hand-typed `schematic=`. None of the six is reachable
from any schematic in this repository. They are waiting for the feature's first
real user, which is exactly why they are filed rather than left in a report.

## The sabotage pass's own verdict, and what the repair pass did with it

The sabotage pass returned **FAIL** on 36 build-and-measure cycles: nine
load-bearing lines could be deleted with every suite green. The repair pass
witnessed all nine and took the suite from 34 checks to 44. That work is
recorded in the section above. **It did not touch the six defects in the table
here** - those came from a different pass and are product defects, not coverage
holes.

---

# THE CONTRACT AFTER ITEM S6b, 2026-08-31 -- read this before the sections above

Everything above still describes the feature. Two rules were added under it, and
one of them changes when the feature fires at all, so a reader who stops before
this section will have the wrong model.

## 1. A value has to look like a value (GUARD AS-VALUE, [[1213]])

XSCHEM writes a separate copy of a cell for a setting **only when the value is
one word with at least one letter or digit in it**. Formally: not empty; no
space, tab, line break, carriage return, form feed or vertical tab anywhere in
it; no `@` and no `%` (the two marks XSCHEM reads as "fill this in later", and
it really does resolve them again when the device line is written); and at least
one letter or digit somewhere.

Anything else falls through to the plain cell and is reported as a setting that
went nowhere -- the behaviour this feature replaced. This is an ALLOW-rule on
purpose. Two passes had patched one refused shape at a time and each one was
walked past by the next shape along, so a shape nobody has thought of is now
safe because it was never admitted, not because somebody wrote a guard for it.

## 2. A refused setting is taken OUT, not merely left out of the name ([[1227]])

The first version of rule 1 only kept a refused setting out of the **sharing
key** -- the string that decides the cell's name and which copies share a body.
The setting still travelled into the cell body XSCHEM wrote, so a copy with one
good setting beside one refused one still put `sky130_fd_pr__` in the deck,
under a sentence saying that setting "did not reach the simulator and changed
nothing". `lost_attrs_strip_unusable()` (`src/token.c`) now hands the new body
the copy's settings with the refused ones removed, so they fall back to the
value the symbol's own template supplies. Two callers, one answer:
`get_additional_symbols()` for the deck and `descend_schematic()` for the level
a designer stands on, so the schematic and the deck cannot disagree.

**A cell body the DESIGNER named keeps its property string byte for byte.**
Explicit still beats implicit; the strip is only for a name XSCHEM minted.

## 3. The rest of what S6b closed

| issue | what changed |
|---|---|
| [[1212]] | the collision check reads the design's sheet FILES, so a cell name typed one level down is seen; what it cannot resolve it says out loud |
| [[1214]] | a value equal to the symbol's own default writes no second body -- and says nothing, because nothing was lost |
| [[1215]] | two copies asking for the same settings share ONE body, and it keeps the name the designer typed |
| [[1216]] [[1217]] [[1218]] | one sentence minted once; a row that prints a comparison now makes it; the invented tick box is gone from the comments |
| [[1221]]-[[1226]] | six load-bearing lines the sabotage pass could delete with every suite green, now each seen by a row |

**Still open, and on the user's ruling queue:** [[1220]] -- across sheets the
note's "any other copy that asks for the same settings shares that one" is still
false, because a name harvested from a file cannot be compared by settings.
The cost is a duplicate cell body; nothing is lost silently.
