# 0970 — the bandgap bench does not simulate what its schematic says

**FIXED 2026-08-30 by item S4b, both halves.** Found while fixing issue
**0965**, reproduced first-hand before filing. Scope: **netlister / schematic
data**. The original filing is kept below unchanged, because it is the
measurement; what was done about it is at the end, under
**THE REPAIR**.

## What is true today, measured

`sky130A/xschem_libs/sky130_tests/bandgap/bandgap.sch` places five passgates.
Two of them override the p-channel model on their own schematic line:

    C {sky130_tests/passgate} 1380 -530 0 0 {name=x5 W_N=0.5 L_N=0.35 W_P=0.6
    L_P=0.35 VCCBPIN=VCC VSSBPIN=VSS m=1
    modelp=pfet_01v8_lvt}

`sky130_tests/passgate/symbol/passgate.sym:19`'s `format=` string is

    format="@name @pinlist @VCCBPIN @VSSBPIN @symname W_N=@W_N L_N=@L_N W_P=@W_P L_P=@L_P m=@m"

It never mentions `@modelp`. So `modelp` is not a subcircuit parameter, cannot
vary per call, and the netlister writes **one** `.subckt passgate` body for all
five instances, built from the symbol template's default `modelp=pfet_01v8`.
Measured on the generated deck:

    .subckt passgate count      : 1
    occurrences of "modelp"     : 0
    XM2 Z GP A VCCBPIN sky130_fd_pr__pfet_01v8 L=L_P W=W_P nf=1 …

**x5 and x6 are not simulated with an lvt pfet at all.** The schematic's stated
override is dead in the deck.

## Why it matters, and why it is D5-1's shape

Whichever way issue 0965 is fixed, the user ends up looking at a schematic that
says `modelp=pfet_01v8_lvt` next to numbers measured from a standard-Vt device.
A number that was not measured for the thing it is displayed next to is the
defect (ruling **D5-1**).

Issue 0965's fix takes the only honest position annotation can take on its own:
it names the device the way the DECK spells it, so the numbers are real and
readable, and it **says** that the schematic and the netlist disagree — once per
offending instance, in plain English, through the channel
`ase::op_cards_capture` already echoes. That removes the fabricated attribution.
It does not remove the underlying disagreement, because annotation cannot: the
netlist is not annotation's to write.

## The three candidate fixes, none of them annotation's

1. **Add `modelp=@modelp` and `modeln=@modeln` to `passgate.sym`'s `format=`**,
   and take the models as subcircuit parameters in `passgate.sch`. Correct and
   local, but it CHANGES WHAT THE USER'S BENCH SIMULATES — x5 and x6 would
   become lvt devices — so it is a design change on a committed bench and needs
   the user's word.
2. **Warn at netlist time**, from the netlister: an instance attribute that the
   symbol's `format=` string does not pass down, and that is not `name` or one
   of the netlister's own tokens, is a setting the user wrote and the deck threw
   away. That is a general check and would catch this class everywhere, on every
   PDK.
3. **Leave it and document it on the symbol.** Cheapest, and the least honest.

Option 2 is the recommendation: it is the same rule this whole area has been
applying to itself — a request that quietly does nothing is the defect — turned
on the netlister.

## Generality

This is not a sky130 quirk. ANY per-instance override of an attribute a symbol's
`format=` does not interpolate is silently discarded, on any PDK. It only became
visible here because the annotation surface builds a device name out of the
model and therefore had to ask which model the deck used.


---

# THE REPAIR, 2026-08-30 (item S4b)

## Who owns `passgate.sym` — answered first, then moot

The brief asked to establish ownership before touching the symbol.
`sky130A/xschem_libs/sky130_tests/passgate/symbol/passgate.sym` is Apache-2.0,
© Stefan Frederik Schippers, and arrived in a single commit (`4ac38ae7`, the
in-repo sky130 workarea migration). There is no vendor lockfile and no
PROVENANCE marker anywhere under `sky130A/`. It is a migrated in-repo copy and
would have been ours to edit.

**It was not edited, because the prescribed remedy is the wrong mechanism.**
SPICE cannot substitute a model NAME from a `.subckt` parameter, and
`passgate.sym`'s `extra="VCCBPIN VSSBPIN modeln modelp"` deliberately keeps
`modeln`/`modelp` out of the parameter defaults via `get_sym_template()`
(`src/token.c`). Adding `modelp=@modelp` to the `format=` string would change
every placement of that symbol tree-wide and still not produce a per-call model.

## Half one — the mechanism this tree actually uses

The per-instance **`schematic=`** attribute. `get_additional_symbols()`
(`src/actions.c:4088`) makes a SEPARATE symbol block whose `parent_prop_ptr` is
that instance's own property string; `src/spice_netlist.c:494-496` feeds that
into `xctx->hier_attr[].prop_ptr`, so `model=@modelp` inside `passgate.sch`
resolves to the INSTANCE's `pfet_01v8_lvt`. Because the named schematic does not
exist on disk, `src/actions.c:4139-4143` falls back to the symbol's own base
`.sch` — so ONE `passgate.sch` yields two `.subckt` bodies.

This is the library author's own idiom, taught in words on the shipped
`sky130_tests/gain_stage` sheet and already used by three shipped instances
(`gain_stage` x6, and `tb_bandgap_opamp` in both copies) with `passgate_1`.

**The change is four instance lines in two files** — `x5` and `x6` in
`sky130_tests_ase/bandgap/schematic/bandgap.sch` and in
`sky130_tests/bandgap/schematic/bandgap.sch` — each gaining
` schematic=passgate_lvtp`. The name is distinct from the existing `passgate_1`
so the two hierarchies cannot collide on a `.subckt` name if they are ever
netlisted into one deck, and it says what it is.

### The deck, after

    222:.subckt passgate       Z A GP GN VCCBPIN VSSBPIN  W_N=1 L_N=0.2 W_P=1 L_P=0.2
    285:.subckt passgate_lvtp  Z A GP GN VCCBPIN VSSBPIN  W_N=1 L_N=0.2 W_P=1 L_P=0.2
    231:XM2 Z GP A VCCBPIN sky130_fd_pr__pfet_01v8      L=L_P W=W_P …
    294:XM2 Z GP A VCCBPIN sky130_fd_pr__pfet_01v8_lvt  L=L_P W=W_P …

    47:x3 … passgate        49:x5 … passgate_lvtp
    48:x4 … passgate        50:x6 … passgate_lvtp
    65:x7 … passgate

### The number, before and after — one parameter, one device, matched runs

Both runs are the shipped `tb_bandgap` bench through the ASE path into the real
ngspice, same state file, same analyses (`op` + `tran 1n 5n`), same machine,
differing only in whether those two tokens are on the schematic line. `rc=0`
both times.

| x5's transistor M2 | BEFORE | AFTER |
|---|---|---|
| the vector the results file holds | `…msky130_fd_pr__pfet_01v8[vth]` | `…msky130_fd_pr__pfet_01v8_lvt[vth]` |
| threshold voltage | **1.0575922 V** | **0.483497 V** |
| transconductance `gm` | 3.7606476e-36 | 6.9108436e-31 |
| drain current `id` | 1.2163275e-37 | 2.2827704e-32 |

The `_lvt` vector **did not exist in the results file at all** before the change,
and the plain `pfet_01v8` vector for x5 does not exist after it. The control in
the same two runs: `x3`, a passgate that overrides nothing, reads `vth` 0.827 V
before and 0.869 V after — it moved with the operating point, not with a model
card, which is what makes x5's 0.57 V shift a different DEVICE and not a
different bias.

### Goldens

**None.** Verified: the six tracked files under `tests/headless/gold/` mention
neither `passgate` nor `bandgap`, no `tests/*/results` is tracked, and
`tests/netlisting.tcl` walks only `xschem_library/` and never `sky130A/`. So
there was no golden pinning the defect and none needed the "this golden was
pinning the defect" note. The only things pinning it were rows N1–N4 of
`tests/headless/test_ase_optier_0963.tcl`; N2, N3 and N4 are inverted and a new
row **X7** measures the real run.

### The cost, and it is filed

An instance carrying `schematic=` naming a file that does not exist cannot be
opened by the `xschem descend` COMMAND — `scheduler.c:3355-3364` passes the
fallback flag as a hard 0, so a script gets a blank sheet. **The person is
fine**: the menu/keyboard descend goes through `callback.c:5490` with the flag
on and asks *"Schematic … does not exist. Descend into base schematic?"*.
Measured on the SHIPPED `gain_stage` x6 with none of this pass's changes, so it
is pre-existing and not introduced here. Filed as **0979**.

## Half two — the general defence, in the netlister

`src/token.c` gains `warn_unused_instance_attr()`, called once per instance from
`print_spice_element()` immediately after the format string is resolved and
before it is parsed. When an instance sets a property the symbol's format string
never reads, the netlister says so:

> Warning: on this sheet, instance **x5** (a **uapass**) sets
> **modelp=pfet_01v8_lvt**, but **uapass** never reads **modelp** when the
> netlist is written, so that setting did not reach the simulator and changed
> nothing. Check the spelling against the settings this cell does read, or take
> it off. If you meant to change only this one copy of the cell, give **x5** a
> `schematic=` attribute of its own as well, and the cell will be written out
> separately with your setting in it.

The recommended action is the same action half one took and the same one the
0974 sentence recommends — one story, three surfaces.

### The guards, and the measurement that justifies each

Measured across **494 schematics** in `sky130A/`, `gf180mcuD/`, `ihp-sg13g2/`
and `xschem_library/`.

| guard | what a reader would otherwise assume | cost of losing it |
|---|---|---|
| **UA-TYPE** — subcircuits only | that this is about "unused attributes" generally | 6863 lines instead of 10 on the two PDK trees |
| **UA-POLY** — skip an instance carrying `schematic=` / `*_sym_def` | that such an override is lost too | 6 of sky130A's 10 hits were false; after half one this is the only thing stopping the user being told their WORKING override did nothing |
| **UA-INST** — tokens from the instance, never the template | that a template default counts | every symbol default in the tree |
| **UA-NAME** — the token must read as an attribute name | that every token `list_tokens()` returns is a setting | 8 lines on the shipped `tb_charge_pump` reading `instance x7 (a lvtnot) sets +=` — the sky130 library writes instance properties over three lines with SPICE-style `+` continuation markers |
| **UA-STOP** — the measured exemption list | that the names are arbitrary | `device_model` alone is 2 false hits on `devices/vsource`; it is hashed straight off the instance at `spice_netlist.c:235-241`, outside any format string |
| **UA-FMT** — whole-token, never `strstr` | that a substring test is good enough | `@W_P` in a format would swallow an instance's stray `W` and the check would go silent about exactly the class it exists for |
| **UA-TOKSIZE** — latch and restore `xctx->tok_size` | that an observer cannot affect the netlist | invisible at today's call site; a structural row (UB9) is the only witness |

### The noise budget, and which way it went

With every guard in place, over all 494 schematics:

| tree | sheets | lines |
|---|---|---|
| `sky130A/` (all of it, both test libraries) | 0 | **0** |
| `gf180mcuD/` | 0 | **0** |
| `ihp-sg13g2/` | 0 | **0** |
| `xschem_library/` | 18 of 187 | **149** |

The unnarrowed rule emits **16876**. Every one of the 149 was read and every one
is real — `VSSBPIN=VSS` on `lvnand2`/`lvnor2`, whose format reads `@VSSPIN`
(`rom8k`, `0_examples_top`); `ROUT=` on `inv_ngspice`, whose format reads `@RUP`
and `@RDOWN`; `del=` on `latch`/`mux21`, which are VHDL/Verilog-only parameters.

**SO IT SHIPS ON BY DEFAULT.** Zero lines on every PDK tree and zero on every
shipped simulation bench, which is where a designer works; the 149 are the
example library's own data and are filed separately as **0978**, not fixed.

### Severity — deliberate, and on the ruling queue

`statusmsg(str, 2)`. It appends to the info/ERC window's text and does **not**
raise the netlister's error flag, so `show_infowindow_after_netlist` (default
`onerror`) will not pop the window. Identical to the existing open-net and
`#`-node notices. Rejected: raising `err`, which would pop the info window on
every netlist of a design that has one such setting.

### Rejected, and recorded

* Listing the settings the cell DOES read inside the sentence. It would make a
  misspelling obvious, but it is a second formatting surface and a second guard
  for a benefit the "check the spelling" clause already points at.
* A new opt-in Tcl-mirrored preference. That means `MIRRORED IN TCL` in
  `src/xschem.h`, a menu entry and a preferences round trip, for a line the
  measurement says is already quiet.
* Extending the check to the spectre/VHDL/Verilog/tEDAx backends. The noise was
  measured for SPICE and only for SPICE. On the user's ruling queue.

## Rows

`tests/headless/test_unused_attr_0970.tcl` (new, 21 checks), registered in
`tests/run_regression.tcl` and `tests/headless/full_audit.sh`:
UB1–UB11 (the diagnostic and its guards; UB9 and UB10/UB11 structural),
GC1–GC5 (issue 0974's sentence, on a fixture that cannot be repaired away),
PD1–PD5 (issue 0976's two PDK surfaces).
`tests/headless/test_ase_optier_0963.tcl`: N2, N3, N4 inverted; X7 new.

## ⚠ WHAT THE SABOTAGE AND VERIFICATION PASSES FOUND, AND WHAT IS STILL OPEN

Half two shipped. It is measured quiet where a designer works, it catches a real
one-letter misspelling in `rom8k`, and every named guard is now seen by at least
one row — eighteen neutralize-build-run-restore cycles, one guard at a time.
Four things came out of those passes that are **not** fixed here, and the
diagnostic ships with them live:

* **0980 — it tells a designer to delete a setting the VHDL and Verilog
  netlists use.** 36 of the 149 lines on the example library name a property
  another backend of the same symbol declares or consumes. On those the
  sentence's "changed nothing" is false and its "or take it off" would break the
  design. The check consults only the currently selected backend's format
  string, never `generic_type=` or the other formats. **This is the one to fix
  first** — it is the "do not cry wolf" clause of the brief, not met.
* **0981 — "on this sheet" is false in a hierarchy.** `warn_unused_instance_attr`
  runs from `print_spice_element()` for every instance in every cell, so
  netlisting `rom8k.sch` prints three byte-identical paragraphs about
  "instance x2 (a lvnand2)" when `grep -c lvnand2 rom8k.sch` is **0**. This is
  issue 0974 one layer down, in the sentence the same pass wrote.
* **0982 — the advice this sentence gives is silently self-defeating when
  followed twice.** Two instances given the same `schematic=` name produce ONE
  cell body, the second one's model vanishes from the deck, and GUARD UA-POLY
  switches off the diagnostic for both. Measured: one `.subckt sharedcell`,
  `hvt` count 0, warning lines 0.
* **0983 — a long or multi-line value costs the sentence its ending.** The value
  is interpolated raw into `char str[2048]`; a 1700-character one truncates
  mid-clause at "give xq" with no marker, and a newline inside a value splits
  the sentence across two info-window lines on shipped data.

Test coverage of the guards is filed as **0984**. One gap in it — row UB9's
anchor, which could not fail — **is fixed in this commit**.

### A correction to this item's own sabotage plan

The plan predicted that gutting the stoplist (GUARD UA-STOP) must redden UB5,
UB7 and UB8. Measured with a built binary: **only UB5 reddened.** With no
stoplist at all the six shipped testbenches still emitted zero lines each,
identical to baseline; only the fixture count moved, 3 to 6. The reason is that
`name` is exempt twice over — essentially every symbol's format string contains
`@name`, so GUARD UA-FMT catches it whether or not the stoplist does. A reader
following the plan would have scored that run a partial failure; it was an
over-broad prediction, not a missing guard.

### A guard the plan did not have

**GUARD UA-NAME** — a token must read as an attribute name — was added during
implementation after measurement, and is in neither the plan's guard list nor
its sabotage list. Without it the shipped `tb_charge_pump` bench emits eight
lines reading `instance x7 (a lvtnot) sets +=`, because
`sky130_tests/charge_pump_phasegen.sch` writes its properties over three lines
with SPICE-style `+` continuation markers. Its only witness is UB8's aggregate
count over that one bench; see 0984 gap 2.

