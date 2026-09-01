# 0980 — the new netlist warning tells a designer to delete a setting the VHDL and Verilog netlists really use

**Status: FIXED (2026-08-30, item S4c), in `src/token.c`, rebuilt and measured.**

**The count in this file was wrong and is corrected here: 43 of the 149 lines
were false, not 36, and the honest true count was 106, not 111.** This file
originally set aside `del`/`delay` on `logic/latch` and `logic/mux21` because
"from the shipped files alone `del` being a live VHDL generic is not
established". Running the netlister establishes it — `doublepin.vhdl:44`
`del => 200`, `doublepin.vhdl:43` `delay => 200 ps`, `testbench.v:74`
`.del ( 200 )`. That is 10 more false lines (latch `del` 6, latch `delay` 3,
mux21 `del` 1). Issue **0978** carries the same correction.

### The measured before and after, whole of `xschem_library`, SPICE

| | sheets that speak | lines | false | true |
|---|---|---|---|---|
| before (commit `bbca021b`) | 18 | 149 | **43** | 106 |
| after | **11** | **98** | **0** | **98** |

The true count fell from 106 to 98 because two more consumption paths turned up
when the sweep was re-run against the repaired netlister — see "Two more ways a
setting reaches something", below. False positives: **zero**, verified
mechanically rather than by eye (below).

### The fix

Three guards in `src/token.c`, all inside `warn_unused_instance_attr()`:

* **GUARD UA-TMPL** — a setting the SYMBOL's `template=` declares is passed
  straight into a VHDL or Verilog netlist of that cell as a generic or a
  parameter, with no format string involved. `print_vhdl_element()` and
  `print_verilog_element()` decide emission on exactly that test, so the
  diagnostic now uses the same one and cannot drift from the backends it speaks
  for. This is the guard that silences `ram_tb.sch` and `loading.sch`.
* **GUARD UA-EXTRA**, inside it — a name the symbol lists in `extra=` is a NODE,
  not a setting, so it stays reportable even when the template carries it too.
  Without this seam, issue 0970's own headline case (`passgate.sym`, whose
  template holds `modelp` and whose `extra=` names it) goes silent. The VHDL
  backend disagrees about `extra=`; that asymmetry is filed as issue **0985**
  and deliberately not settled here.
* **GUARD UA-ALTFMT** — every format string the symbol can be written through
  (`format`, `spice_format`, `vhdl_format`, `verilog_format`, `tedax_format`,
  `spectre_format`), on the symbol and on the instance, not only the one being
  written this minute.

**`generic_type=` was the near miss and was rejected.** It only picks quoting
and drops time-typed tokens from the Verilog map. Reading it as the consumption
test silences 31 of the 43 and leaves `ram_tb`'s `datafile` still accused.

### Two more ways a setting reaches something, found by re-running the sweep

Neither was in the plan. Both were found by running the whole-library sweep
again against the repaired netlister instead of trusting the reasoning.

* **GUARD UA-SYMNAME**, 6 lines. The cell an instance points at is not a fixed
  name: xschem substitutes the instance's attributes into the symbol reference
  before resolving it (`link_symbols_to_instances()` in `src/save.c` calls
  `translate()` on `xctx->inst[].name`). `xschem_library/generators/test_symbolgen.sch`
  places `symbolgen.tcl(inv,@ROUT\)` and sets `ROUT=1200` on it, and the deck
  gets `x1 IN_INV IN symbolgen_tcl_inv_1200`. The setting **chose the cell
  body** — the loudest way a setting can reach the simulator — and the shipped
  warning told the user on six lines to take it off. The tree ships two more of
  this shape, `mosgen.tcl(@model\)` and `tier.tcl(@lab\)`.
* **`select` added to the stoplist**, 4 lines. The property editor reads
  `select=` off the INSTANCE to decide which field to put the cursor in
  (`src/property_form.tcl`, `xschem get_tok $::tctx::retval select`).
  `xschem_library/ngspice/solar_panel.sch` sets `select=OFFSET` and
  `select=AMPLITUDE` on two comparators for exactly that and was being told on
  two lines to take them off.

### How false=0 was verified

Not by classifying symbols, which would be circular. For each of the 11 sheets
that still speak, the same sheet was written out as Verilog and as VHDL in the
same session, the instantiation blocks were parsed out of both products, and
each accused property was looked for in the parameter map (`.prop ( ... )`) or
generic map (`prop => ...`) **of that cell**. Result: `false=0 true=98`.

A whole-file grep answers 40 false and is wrong: the `ROUT` hits belong to
`comp_ngspice`, whose template does declare it, and the `VSSBPIN =>` hits belong
to an `inv-2` standard cell, not to `lvnand2`. Per-cell attribution is the
difference between evidence and a number.

### What the 98 remaining lines are

| lines | cell | setting | why it is true |
|---|---|---|---|
| 60 | `lvnand2` | `VSSBPIN` | the symbol spells it `VSSPIN`; `VSSBPIN` appears **0** times in the SPICE, Verilog and VHDL netlists of `rom8k.sch`. A real typo, and the single biggest finding in the library. |
| 22 | `inv_ngspice` | `ROUT` | the cell reads `RUP`/`RDOWN`; the deck lines read `inv_ngspice RUP=2000 RDOWN=1000`. |
| 6 | `lvnor2` | `VSSBPIN` | same typo as `lvnand2`. |
| 6 | `SYMBOL_include` | `comm`, `xschematic`, `xspice_sym_def` | attributes the shipped example deliberately disabled by prefixing an `x`. Nothing consumes them, so the warning is true — but it is noise, and it is recorded here as noise rather than special-cased, because an `x`-prefix exemption would also hide a real `xdummy` typo. |
| 2 | `nand2` | `LN` | the cell reads `LLN`. Another real typo. |
| 2 | `symbolgen_tcl()` | `ROUT` | the no-argument form of the generator takes no resistance; the two sibling instances on the same sheet that DO use `@ROUT` are correctly silent. |

### What this fix did NOT do, and it matters

The guard asks *"can any netlist format this symbol supports consume this
setting?"*, not *"does the netlist being written right now consume it?"*. Those
differ, and the difference is filed rather than buried:

* **Issue 0987** — 43 lines' worth of the settings silenced above are genuinely
  dropped from the **SPICE deck the user asked for**, and the tool now says
  nothing. `loading.sch` sets `cap=100.0` and `cap=30.0`; the deck carries
  neither and all four capacitors simulate at the symbol default `10.0`. The
  warning used to name that drop and then give advice that would have broken
  the VHDL netlist. Now it is silent. Neither state is the whole truth, and
  0987 carries the options and the ruling.
* **Issue 0988** — a symbol carrying `vhdl_ignore`/`verilog_ignore` is never
  written in those formats at all, so a name in its `template=` is consumed by
  nothing anywhere and is silenced anyway. That is a straight miss against the
  brief's stated rule. 112 shipped symbols carry such a flag.
* **Issue 0989** — `select`, added to the stoplist above, is now unreportable
  for every symbol in every design, including a real mux parameter of that name.

### Not moved, one byte

The diagnostic is observation-only. The SPICE decks of `ram_tb.sch`,
`loading.sch`, `tb_symbol_include.sch` and the 1,116,709-byte `rom8k.sch` are
**byte-identical** to the ones the pre-fix binary wrote.

### Rows

`tests/headless/test_unused_attr_0970.tcl`, section UF: UF1, UF2 (the two
shipped sheets, now silent, with the deck proved non-empty so a load failure
cannot pass as a green), UF3 (the negative control — `rom8k.sch` must still
speak, so a "fix" that switches the warning off reddens), UF4–UF7 (the four ways
a cell can consume a setting, one attribute each), UF18 (UA-SYMNAME on the
shipped generator example) and UF19 (`select` on the shipped solar panel).

---

## The original report follows, unchanged except for the corrected count.



## What the user sees

They open `xschem_library/logic/ram_tb.sch`, press netlist with SPICE selected,
and the info window fills with **seven** paragraphs like this one:

    Warning: on this sheet, instance x1 (a ram) sets datafile=ram.list, but ram
    never reads datafile when the netlist is written, so that setting did not
    reach the simulator and changed nothing. Check the spelling against the
    settings this cell does read, or take it off. If you meant to change only
    this one copy of the cell, give x1 a schematic= attribute of its own as
    well, and the cell will be written out separately with your setting in it.

Two of those clauses are false for this design and the last piece of advice is
destructive. Netlisting **the same sheet** to Verilog, in the same session,
emits every one of the seven:

    .dim ( 8 )
    .width ( 16 )
    .hex ( 1 )
    .datafile ( "ram.list" )
    .modulename ( "ram" )
    .access_delay ( 3000 )
    .oe_delay ( 300 )

and `xschem_library/logic/ram.sym`'s own body consumes them
(`$readmemh(datafile, mem)`, `assign #access_delay iidata = idata;`). A
designer who does what the sentence tells them — "take it off" — breaks the
Verilog netlist of a working example, and the tool told them to.

The same shape on `xschem_library/examples/loading.sch`: **11** warning lines
in the SPICE netlist, and the VHDL netlist of the same sheet carries
`cap => 30.0`, `cap => 100.0`, `conduct => 1.0/20000.0` and their siblings.

## The measurement

Swept with the shipped stoplist over every schematic in `xschem_library/`,
using the built binary at the S4b commit:

    SWEEP sheets_scanned=179 sheets_with_lines=18 lines=149

Of the 147 lines that parse into a (symbol, property) pair, classified by
reading each symbol's own `generic_type=`, `vhdl_format=`, `verilog_format=`
and non-SPICE body:

| class | lines |
|---|---|
| the property is declared or consumed by another backend of the same symbol | **36** |
| the property is read by nothing at all (a genuine catch) | **111** |

The 36:

    real_capa cap 8 | switch_rreal del 6 | pump conduct 4 | pump val 4
    bts m 4 | latch delay 3 | ram dim/width/hex/datafile/modulename/
    access_delay/oe_delay 1 each

**A number correction, deliberately made.** The verification pass counted **43**
in this class by also counting `del` on `logic/latch` and `logic/mux21`. This
write-up does not: those two symbols declare `generic_type="delay=time"` and
name `del` only in their `template=`, so from the shipped files alone `del`
being a live VHDL generic is not established. 36 is the number this repository
proves. The class is real either way.

## The missing guard

`warn_unused_instance_attr()` consults **only** the format string of the
backend currently selected. It never looks at the symbol's `generic_type=`, its
`vhdl_format=` / `verilog_format=` / `tedax_format=`, or its
`verilog_netlist=true` body. `generic_type` is in `unused_attr_stoplist[]` as
an **attribute name** — that exempts an instance that sets `generic_type=`
itself, which is a completely different thing from reading what a symbol's
`generic_type` declares.

## Why it matters more than the count suggests

The brief that commissioned the check said: *"Do not ship a warning that cries
wolf on a normal netlist; a diagnostic nobody can read is worse than none."*
The check is silent on all three PDK trees and on every simulation bench, which
is what let it ship on by default — and it is right about 111 of its 149 lines.
But a multi-backend cell is a normal thing in this repository, and on those
sheets the sentence is not merely noisy: it states a falsehood ("changed
nothing") and recommends an edit that breaks the design.

## What would fix it

Before emitting, ask whether **any** other backend of that symbol reads the
token — the union of `format`, `spice_format`, `vhdl_format`, `verilog_format`,
`tedax_format`, `spectre_format` and the names declared in `generic_type`. If
one does, either stay silent or say the true thing instead: *"the VHDL netlist
of this cell uses it; the SPICE one does not."* The second is better and is
what a designer needs, but it is a bigger sentence and needs its own rows.

## Acceptance rows this needs

None exist. `tests/headless/test_unused_attr_0970.tcl`'s UB8 — the row named
"the noise budget" — netlists only `sky130_tests_ase`'s `tb_*` benches, which
are pure SPICE and emit zero lines. **No row in the tree netlists a
multi-backend sheet through this check**, which is why the class shipped. A fix
needs a fixture cell carrying a `generic_type=` and two format strings, netlist
to SPICE, and assert silence.

## Related

Issue **0978** records the 149 lines as library data and says they are "all
real". That claim is corrected there by this measurement. Issue **0981** is the
same sentence being wrong about *where* the instance is; **0983** is the same
sentence being cut in half by an unusual value.
