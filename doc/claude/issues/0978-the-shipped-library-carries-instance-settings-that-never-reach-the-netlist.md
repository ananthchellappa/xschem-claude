# 0978 — the shipped example library carries 149 settings that never reach the netlist

**Status: FILED, NOT FIXED (2026-08-30, item S4b).** Reproduced by measurement,
not by inspection. These are the example library's own data, and correcting a
schematic somebody drew is a different decision from adding a check.

## What the measurement is

Issue 0970 added a netlist-time diagnostic: when an instance sets a property the
symbol's `format=` string never reads, the netlister says so, because that
setting never reaches the simulator. The rule was swept over **494 schematics**
across `sky130A/`, `gf180mcuD/`, `ihp-sg13g2/` and `xschem_library/` before it
was allowed to ship on by default.

| tree | sheets with lines | lines |
|---|---|---|
| `sky130A/` (both test libraries, all benches) | 0 | **0** |
| `gf180mcuD/` | 0 | **0** |
| `ihp-sg13g2/` | 0 | **0** |
| `xschem_library/` | 18 of 187 | **149** |

## The 149, and 36 of them are the diagnostic's own defect — see 0980

⚠ **A CORRECTION, MADE BY THE WRITE-UP PASS THAT FILED THIS ISSUE.** The
heading here first read "and they are all real". It is not true, and it was the
claim the user was being asked to ratify a default-on warning on. Re-measured
independently: of the 147 lines that parse into a (symbol, property) pair,
**36 name a property another backend of the same symbol declares or consumes**.
`xschem_library/logic/ram_tb.sch` emits seven such lines, and the Verilog
netlist of that same sheet carries every one of them (`.datafile ( "ram.list" )`
and its six siblings) into a module body that uses them. On those lines the
sentence's "changed nothing" is false and its "or take it off" would break the
design. That class is filed as **issue 0980**, against the check, not against
the library.

The remaining **111 are real** and are what this issue is about.

Read in full. Three shapes account for nearly all of them.

* **A misspelled power pin.** `rom8k/lvnand2.sym` and its `lvnor2` sibling
  declare `extra="VCCPIN VSSPIN"` and their format reads `@VSSPIN`. Instances on
  `rom8k.sch` and `examples/0_examples_top.sch` set **`VSSBPIN=VSS`**. One
  letter, and the binding is discarded. ~40 lines, and the largest single group.
* **A resistor value the symbol does not read.** `examples/inv_ngspice.sym`'s
  format reads `@RUP` and `@RDOWN`; instances on `test_short_option.sch` and
  `test_symbolgen.sch` set **`ROUT=`**.
* **Backend-only parameters on a SPICE netlist.** `del=200` on `logic/latch` and
  `logic/mux21` in `testbench.sch`. NOTE these two are counted in the **111**,
  not in the 36: both symbols declare `generic_type="delay=time"` and name `del`
  only in their `template=`, so from the shipped files alone `del` being a live
  VHDL generic is not established. The genuinely backend-declared ones — `cap`
  on `real_capa`, `conduct` and `val` on `pump`, `del` on `switch_rreal`, `m` on
  `bts`, `delay` on `latch`, and `ram`'s seven — are issue **0980**, not this
  one.

## Why it is not fixed here

Each is a change to a schematic the library ships as an example. The `VSSBPIN`
one in particular looks like a plain typo, but "looks like" is not a
measurement: changing it changes what `rom8k` netlists, and this branch's own
rule is that a change with no row watching it is not a fix. There is no suite
over `xschem_library/`'s benches to watch one.

The diagnostic itself is on by default because it is **silent on every PDK tree
and every simulation bench**, which is where a designer works. That is still
true, and it is still the reason. But it is not the whole picture any more:
see **0980** for the 36 lines where the sentence is wrong rather than merely
unwelcome, and **0981** and **0983** for two ways the sentence misreports even
when it is right to speak. Whether it should
also be silent on the example library — by fixing these 149, or by some other
means — is the decision this issue exists to record.
