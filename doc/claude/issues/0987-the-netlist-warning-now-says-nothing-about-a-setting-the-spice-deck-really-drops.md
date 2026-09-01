# 0987 — the netlist warning now says nothing about a setting the SPICE deck really drops

**Filed** 2026-08-30, by the item S4c write-up, from the verify pass's
measurement and re-measured by me before filing. **Status** open.
**Parent** issue **0980**, whose fix caused this. **Subject**
`warn_unused_instance_attr()` / GUARD UA-TMPL in `src/token.c`.

## The short version

Issue 0980's fix was correct and it worked: the warning went from 43 wrong lines
out of 149 to **0 wrong out of 98**. But the guard that silenced those 43 lines
asks *"can any netlist format this symbol supports consume this setting?"*, not
*"does the netlist I am writing right now consume it?"* — and the answer differs.
On the shipped library there are **43 lines' worth of settings that are silently
dropped from the SPICE deck the user asked for**, and the tool now says nothing
about any of them.

Before S4c the user got a warning that named a real drop and then gave advice
that would have broken their VHDL netlist. After S4c they get silence. Neither
is the whole truth, and this file records the half that is still missing so the
next pass is not re-deriving it.

## What the user sees, measured

Open `xschem_library/examples/loading.sch` and press netlist with SPICE
selected. The sheet sets a capacitance on each of four capacitors:

    cap=100.0 on x1,  cap=30.0 on x3,  cap=20.0 on x6,  cap=40.0 on x9

The deck that comes out:

    x3 VX real_capa
    x1 VXS real_capa
    x6 SP real_capa
    x9 VX2 real_capa
    .subckt real_capa USC  cap=10.0

No parameter on any instance line. `grep -c '100\.0'` and `grep -c '30\.0'` over
the deck both return **0**. All four capacitors simulate at **10.0**, the
symbol's default. The Command window says **nothing at all** — measured,
`SPICEWARN loading.sch 0`, where before the fix it printed eleven lines.

The brief's other headline sheet is the same shape.
`xschem_library/logic/ram_tb.sch` sets `dim=8 width=16 hex=1`; the deck reads
`.subckt ram ... dim=5 width=8 hex=0`, `dim=8` occurs **0** times in it, and
`SPICEWARN ram_tb.sch` is **0**.

## Why

`real_capa.sym` is `format="@name @pinlist @symname"`. That format passes no
parameters, so `cap` genuinely does not reach the SPICE simulator. GUARD UA-TMPL
excuses it anyway, because `cap` is in the symbol's `template=` and a **VHDL**
netlist of the same sheet really would carry `cap => 30.0`.

Both statements are true at once. The setting reaches the VHDL netlist and is
dropped from the SPICE deck, and the warning is written from the SPICE netlister
while claiming to speak about "the netlist".

## Size, on the shipped library

**These are the same 43 lines.** The 43 that were false positives under the
"can any format consume it?" rule are exactly the 43 that are false negatives
under "does the netlist being written consume it?" — the trade is one-for-one.
(S4c silenced 53 lines in total; the other 10 are the 6 GUARD UA-SYMNAME lines
and the 4 `select` lines, both of which really are consumed.)

43 of those 53 sit on seven cells whose SPICE format string passes
**no parameters at all**. Each format string was read out of the shipped
symbol for this table:

| lines | cell | its SPICE `format=` |
|---|---|---|
| 9 | `logic/latch` | `@name @pinlist @symname` |
| 8 | `examples/real_capa` | `@name @pinlist @symname` |
| 8 | `examples/pump` | `@name @pinlist @symname` |
| 7 | `logic/ram` | `@name @pinlist @symname` |
| 6 | `examples/switch_rreal` | `@name @pinlist @symname` |
| 4 | `rom8k/bts` | `@name @pinlist @VCCPIN @VSSPIN @symname` — two NODES, still no parameters |
| 1 | `logic/mux21` | `@name @pinlist @symname` |

## This was sanctioned by the brief, and is filed anyway

The item brief's rule is literal: *"A property is UNUSED only if NO netlist
format this symbol can be written in consumes it."* GUARD UA-TMPL implements
exactly that, so S4c did what it was told and the `false=0` claim is true under
the rule it was given. What the brief did not say is that the rule buys its
zero by going **silent about a real drop in the deck the user asked for**, and
neither the S4c implementation report nor issue 0980 says so either. That
omission is the reason this file exists.

The harm the brief opened with was the **advice** — "take it off" would have
broken a working shipped example. S4c's own 0982 work shows that advice can be
repaired instead of deleted. Deleting the observation was not the only way to
stop the advice being destructive.

## Options, none taken

1. **Per-format truth, one sentence.** Ask whether the format being written
   consumes it, and when it does not but another format would, say so:
   "…is not passed into a SPICE netlist of this cell — it does reach a VHDL or
   Verilog netlist, so do not remove it if you netlist this design in those."
   Most informative; a longer sentence; needs the elision budget re-checked
   (ruling D5-4 keeps it one mint site, so this is a wording change, not a
   second call site).
2. **Warn at a quieter level**, distinct from the "reaches nothing anywhere"
   class. Two severities to explain instead of one.
3. **Leave it silent** (today). Cheapest; the tool watches a designer set
   `cap=100.0` on four capacitors, simulate all four at `10.0`, and says
   nothing.

Option 1 is the one this file recommends. **It is the user's call and a rule
debt is recorded against this number.**

## Rows

None yet — nothing pins this behaviour either way, which is itself part of the
defect. A row asserting `loading.sch` is silent would freeze today's answer
before the question is asked, so it was deliberately not written.

## What is NOT wrong here

The netlister's output is unchanged: the decks are byte-identical to the ones
the pre-fix binary wrote. The dropped `cap` was dropped before S4c too — that is
issue **0978**'s subject, not this one. What changed is only whether the user is
told.

---

# FIXED by item S4d, 2026-08-30

**Status** fixed. Shipped in `src/token.c`, pinned by
`tests/headless/test_unused_attr_0970.tcl` (40 checks → 57).

## What the person netlisting sees now

Open `xschem_library/examples/loading.sch`, choose SPICE, press netlist. Before
this, the Command window said nothing at all while all four capacitors simulated
at the cell default of 10.0. Now each of the four gets one line — and it is a
*different* sentence from the accusing one, because it asks for the opposite
action:

> Warning: on sheet loading.sch, instance x1 (a real_capa) sets cap=100.0, but a
> SPICE netlist of real_capa does not pass cap through, so that setting did not
> reach the simulator and changed nothing. It is not a spelling mistake and you
> should not remove it: a VHDL or Verilog netlist of the same cell does carry it,
> so deleting it would break that. To get it into the SPICE run as well, the
> real_capa symbol has to be changed so its SPICE line passes it through.

The two shapes are told apart at a glance by their third clause — the word SPICE
lands early in the new one — and the new one never tells the user to delete
anything. Row `UF28` holds that out over **every** line of that shape the whole
suite run produces, and it matches without regard to capitals: measured while
mutation-checking, appending the accusing sentence's own offer back as *"Or take
it off."* — one capital letter — slipped past a case-sensitive needle with all 57
checks green.

## The shape of the fix

`any_format_uses_token()` is gone. It asked one question and answered
silent/loud. `ua_reach()` replaces it with three answers:

| answer | meaning | what is said |
|---|---|---|
| `UA_HERE` | the deck being written now reads it | nothing |
| `UA_ELSEWHERE` | this deck drops it, another netlist of the same cell carries it | the new sentence, naming the formats, **do not remove it** |
| `UA_NOWHERE` | nothing anywhere reads it | the original 0970 sentence, unchanged word for word |

`UA_ELSEWHERE` is decided per backend by `ua_backend_carries()`, which asks three
things in order: is this instance written out in that format at all (GUARD
UA-IGNORE, issue 0988); does that backend's own format string reference the
setting (GUARD UA-ALTFMT); and, only for the two backends that emit a parameter
map, does the symbol template declare it (GUARD UA-TMPL).

**Measured, not assumed, and written into the source comment:** a one-pin
subcircuit whose template declares `knob`, with the sheet setting `knob=99`,
produces `knob => 99` in the VHDL netlist and `.knob ( 99 )` in the Verilog one,
while the Spectre product has **no instance line for the cell at all** and the
tEDAx one mentions `knob` nowhere. So template membership is evidence for VHDL
and Verilog and for no other format. Treating it as evidence for all six is what
made the shipped warning silent.

**GUARD UA-FMTWINS.** A backend that carries a format string of its own is
netlisted through that string and never through the parameter map
(`print_vhdl_element` / `print_verilog_element` hand off to their `_primitive()`
form the moment `fmt[0]` is non-empty), so for that backend template membership
counts for nothing. Row `UF4` is the witness: the fixture cell has a Verilog form
of its own, so its sentence names **VHDL** and only VHDL.

**GUARD UA-GENTIME**, found by re-running the sweep rather than by reasoning.
`print_verilog_element` drops a generic the symbol types as `time` from the
instance parameter map; VHDL has no matching exclusion. Shipped
`loading.sch` types `del` as a time on three switches, so naming Verilog beside
VHDL there would name a netlist that carries nothing — RULING D5-1. Row `UF27`
is on that shipped sheet.

**GUARD UA-LVSFMT**, the safety half of narrowing the first test to the resolved
string. 110 files in this tree carry an `lvs_format`; with LVS netlisting on, the
resolved string is that one, and a setting only the ordinary `format` line reads
would newly be called dead and offered for deletion — issue 0980's harm arriving
through a new door. Row `UF26` turns LVS on, checks the silence, turns it off and
checks the sheet's own count comes back.

**`spice_format` was dropped from the format set.** It is a phantom: no backend
reads it, and it is declared by zero `.sym` files in `xschem_library`, `sky130A`,
`ihp-sg13g2`, `gf180mcuD` or `xschem_libs_newsym`. Silencing on it was silencing
on nothing. It stays on the stoplist, because a user may still type the name.

## The noise, re-measured with the same sweep

Netlisting every schematic under `xschem_library/` to SPICE
(`tests/headless/tools/unused_attr_sweep.tcl`, committed with this item):

| pass | sheets that speak | lines | false |
|---|---|---|---|
| S4b, as shipped by 0970 | 18 | 149 | **43** |
| S4c, issue 0980's fix | 11 | 98 | 0 |
| **S4d, this fix** | **17** | **141** (98 accusing + 43 new shape) | **0** |

The 98 accusing lines are the *same* 98 S4c printed, one for one, and the 43 new
lines are one-for-one the 43 S4b got wrong — S4c turned 43 false accusations into
43 silences, and this turns those 43 silences into 43 accurate sentences. Six
sheets that had gone completely quiet speak again: `examples/loading.sch` 0 → 11,
`logic/ram_tb.sch` 0 → 7, `logic/testbench.sch` 0 → 4, `examples/doublepin.sch`
0 → 2, `rom8k/rom2_sa.sch` 0 → 1, `examples/test_bus_tap.sch` 0 → 1.

**False must be zero and it is.** The sweep's own suspect test — the literal
`setting=value` appearing in the deck it just wrote — flags 43 lines, and every
one of them was opened. All 43 are the same coincidence: the `.subckt` line
carries the **cell default** in that spelling and the sheet happened to type the
same number. `ram_tb.sch`'s `datafile=ram.list`, `modulename=ram`,
`access_delay=3000` and `oe_delay=300` are exactly the template's own defaults
(its `dim`, `width` and `hex`, which the sheet really does change, are not
flagged); `loading.sch`'s instance lines are bare — `x4 VX ING pump`,
`x5 SW VXS VX switch_rreal` — with no parameters on them at all. The eleven
`ROUT=1000` hits are a match against a *different* subcircuit,
`.subckt and_ngspice Y A B ROUT=1000`, on a sheet whose `inv_ngspice` instances
were the ones warned about. No line survives the reading. **false = 0.**

## The volume decision, taken here and not put on anybody's queue

The accurate sentence adds **43 lines across 17 sheets** on the whole shipped
library, and the most any single sheet gains is **14** (`examples/0_examples_top.sch`,
an aggregator that descends into every example and already printed 37); the
headline sheet, `loading.sch`, goes 0 → 11. That is readable, so the sentence
ships **on by default and there is no switch**. The plan's fallback — a
`netlist_warn_other_format` Tcl variable defaulting off, with the accusing
sentence staying unconditional — was **not built**, and rows UF29/UF30 were not
written. If a later measurement on a real design says otherwise, that fallback is
the shape to build; do not switch the whole diagnostic off.

## The arithmetic the recon flagged

0980's write-up says 51 lines were silenced, 0987 as filed said 53. Neither
number is the one that matters and neither was re-derivable. **The number
measured now is 43** — the count of settings the SPICE deck really drops while
another netlist of the same cell carries them. 149 − 141 = 8 lines that S4b
printed are still silent, and those are the genuinely consumed ones S4c's
GUARD UA-SYMNAME and GUARD UA-STOP found.

## Rows

`UF1` (shipped `ram_tb.sch`: 0 accusing, 7 of the new shape, each naming a
carrier), `UF2` (shipped `loading.sch`: 0 accusing, 11 new, 4 about `cap` naming
VHDL), `UF3` (the shipped ROM as negative control — its lines stay accusing),
`UF4`, `UF7`, `UF24a`–`UF24d`, `UF25`, `UF26`, `UF27`, `UF28`, `UN1`, `UN3`,
`UN4`, `UN5`. Each of the carrier rows demands one **exact** format list, so a
hardcoded phrase cannot satisfy them all.

## Rejected alternatives

* **Consult `generic_type` as the consumption test.** It is the near miss 0980
  already recorded: it silences 31 of the 43 and leaves `ram_tb`'s `datafile`
  still accused. Only used here for the narrow `time` exclusion.
* **Keep the coarser rule — template membership counts for VHDL/Verilog whatever
  format strings exist.** Simpler, and it makes `UF4`'s carrier clause read
  "VHDL or Verilog" for a cell whose Verilog netlist would not in fact carry the
  setting. That is the same class of lie this issue is about.
* **Call `skip_instance2()` for the ignore question.** It is static to
  `netlist.c` and keyed to `xctx->netlist_type`, which is SPICE at this call
  site, so it can only answer about SPICE.
* **Put the new sentence behind a default-off switch.** Measured unnecessary; see
  the volume decision above.

## Still open, deliberately

Issue **0985** — the VHDL backend writes `extra=` names into the generic map
while Verilog excludes them, so a name that is both template-declared and an
`extra=` node is reported as reaching nothing while a VHDL netlist would carry
it. Left exactly as filed, per this item's brief. It is the one remaining known
gap in the reach table.


---

# WHAT THE USER IS BEING ASKED NOW — restated 2026-08-30 by the S4d repair pass

**The rule debt filed against this issue is now out of date on the user's queue,
and this section is the current option set it points at.** The debt's blurb was
written when the tool was SILENT and asks "should the sentence tell you
per-netlist, or is silence right?". S4d answered the first half by building it,
so the question the user actually faces has changed shape. It is now two
questions, both about something already running:

### 1. Do you accept the per-netlist sentence as built?

It says, on shipped `xschem_library/examples/loading.sch`:

> Warning: on sheet loading.sch, instance x1 (a real_capa) sets cap=100.0, but a
> SPICE netlist of real_capa does not pass cap through, so that setting did not
> reach the simulator and changed nothing. It is not a spelling mistake and you
> should not remove it: a VHDL or Verilog netlist of the same cell does carry
> it, so deleting it would break that. To get it into the SPICE run as well, the
> real_capa symbol has to be changed so its SPICE line passes it through.

Six shipped sheets that had gone silent speak again — `loading.sch` 0→11,
`ram_tb.sch` 0→7, `testbench.sch` 0→4, `doublepin.sch` 0→2, `rom2_sa.sch` 0→1,
`test_bus_tap.sch` 0→1.

**The wording of the carrier clause when THREE or FOUR netlists carry the
setting is a separate rule debt filed against issue 0991** — "a Spectre, VHDL,
Verilog or tEDAx netlist of the same cell does carry it". No shipped sheet
reaches more than two names, so that one is wording, not volume.

### 2. The volume gate, and the two readings of it

The plan's ship gate was **"lines ≤ 250 AND no single sheet exceeds 30"**. The
two readings disagree, and the item shipped on one of them without saying so:

* **ADDED lines (the reading taken).** Total 141, of which 43 are the new shape.
  The worst single sheet GAINS 14 (`examples/0_examples_top.sch`, an aggregator
  that descends into every example and already printed 37). Passes.
* **TOTAL lines per sheet (the literal reading).** `examples/0_examples_top.sch`
  now prints **51**, which is over 30. Fails.

So the new sentence ships **on by default with no switch**, and the fallback the
plan named — a `netlist_warn_other_format` Tcl variable defaulting off — was not
built. The user has not ratified either the reading or the volume. If the answer
is "too loud on the aggregator sheet", the fix is the default-off switch for
sentence B ALONE; the accusing sentence should stay unconditional either way,
because that one is the diagnostic and this one is the do-not-delete note.

Nothing here changes what the tool does today. It is a restatement so that the
queue entry does not send the user to a question the tool already answered.
