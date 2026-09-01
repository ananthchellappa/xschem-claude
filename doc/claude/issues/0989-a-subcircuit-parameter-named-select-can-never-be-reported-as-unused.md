# 0989 — a subcircuit parameter named `select` can never be reported as unused

**Filed** 2026-08-30, by the item S4c write-up, from the verify pass's
measurement. **Status** open, low severity. **Parent** issue **0980**.
**Subject** `unused_attr_stoplist[]` in `src/token.c`.

## What was done and why

Item S4c added `select` to the netlister's stoplist — the list of attribute
names the "you typed this and it had no effect" warning never speaks about. The
reason is real: the property editor reads `select=` off the **instance** to
decide which field the cursor lands in (`src/property_form.tcl`,
`xschem get_tok $::tctx::retval select`), and the shipped
`xschem_library/ngspice/solar_panel.sch` sets `select=OFFSET` and
`select=AMPLITUDE` on two comparators for exactly that. Before the stoplist
entry, those two sheets were told on four lines to take them off.

## The cost, measured

A stoplist name is silenced **for every symbol in every design**, forever. So a
subcircuit with a genuine parameter named `select` — a multiplexer is the
obvious one — can never be told its setting was dropped.

Fixture: an instance `xM` with `select=1 zzctl=1` on a cell whose format string
ignores both. Measured:

    SELECT_WARNINGS: 0    CONTROL_WARNINGS: 1    SELECT_IN_DECK: 0

The control attribute is reported, `select` is not, and `select` reaches the
deck zero times. The user gets no warning and no parameter.

## Flagged plainly

**No netlist format consumes `select`**, so by the brief's literal rule this is
not a false positive — it is a stoplist judgement in the same class as
`place`, `sig_type` and `device_model`, which are read by the editor and the
netlister's own machinery rather than by a cell. It is recorded here because it
is the one stoplist entry that collides with a plausible **user** parameter
name, and because it was added by measurement on two shipped sheets rather than
by a decision anyone took about the name.

## Options

1. Leave it (today). Two shipped sheets stay quiet; a `select` parameter on a
   real mux stays unreportable.
2. Drop it from the stoplist and accept four lines of noise on
   `solar_panel.sch`.
3. Make the stoplist consult whether the SYMBOL declares the name as a
   parameter, so an editor-only attribute is skipped while a real parameter of
   that name is still reported. Most precise, most work, and it interacts with
   0987's question about which netlist is being spoken for.

## Rows

`UF19` in `tests/headless/test_unused_attr_0970.tcl` pins the shipped
`solar_panel.sch` sheet as silent; `UF14` exercises all 56 stoplist names beside
a control attribute. Neither pins the cost above, and changing the answer means
changing UF19.

---

# FIXED by item S4d, 2026-08-30

**Status** fixed. **The filed cause was wrong**, and the real one is worse.

## It is not a keyword and not a list-command collision

The issue as filed guessed "a keyword or a Tcl/C list-command collision in the
guard". It is neither. It is a plain, **case-sensitive `strcmp()` against a
hand-written list of 56 attribute names** in `src/token.c`, applied to the
attribute **name alone** with no regard for the cell. Measured on one instance
carrying ten settings the cell reads nothing of:

* silent: `select`, `dir`, `class`, `global`
* reported: `selectt`, `dirr`, `classs`, `globall`, `Select` (the same word with
  a capital S), `knobx`

One extra letter, or one capital, and the tool speaks. So `select` was never
special — it was **one of 56 doors**, and any subcircuit parameter a designer
happens to name after one of those words was permanently unreportable. A fix
that removed `select` alone would have left the other 55 open.

## The fix: ask per cell, not per name

The list is split in two.

* `unused_attr_stoplist[]` — **55 names, unchanged, unconditional.** Only the
  `select` entry was removed.
* `unused_attr_cellparam_stoplist[]` — **`{ "select" }`**, GUARD UA-STOP2:
  excused **unless** `symbol_declares_param(inst, p)`, i.e. unless the cell
  declares it as one of its own parameters.

**The criterion, written into the source comment:** a name belongs on the second
list when the only thing that reads it is a UI convenience **outside any
netlist**, so a symbol author who declares it in `template=` has the stronger
claim to the name. `select` is read by the property editor to place the cursor
(`src/property_form.tcl`). The other 55 are read by xschem's own netlister,
loader or drawing code, which read them off the instance **whether or not the
cell declares them** — so the cell's template says nothing about whether the
setting was consumed.

**Why the other 55 did not move, measured.** Thirteen stoplist names are already
declared in some shipped symbol's `template=` while no shipped format string
reads them — `numslots` by 271 symbols, `class` by 67, `symversion` by 48,
`only_toplevel` by 20, `model-name` by 20, `file` by 11, `comment` by 9,
`sig_type` by 5, and `text`, `spice_ignore`, `generic_type`, `device_model` and
`bus_replacement_char` by one or two each. A blanket rule would manufacture false
positives on shipped data on every one of them. **Recorded as a rule debt on this
issue** — the partition is mine, not the user's.

## What the shipped tree does now

`xschem_library/ngspice/solar_panel.sch` stays silent, as it must:
`comp_ngspice.sym` carries `select=GAIN` as a **symbol** attribute and its
template is `name=x1 OFFSET=0 AMPLITUDE=5 GAIN=100 ROUT=1000 COUT=1p` — no
`select` — so the two comparators are still excused and the editing convenience
is untouched. Row `UF19` holds that. Across the whole `xschem_library` sweep,
**zero** lines mention `select`. And a mux whose template really does declare one
is reportable at last: row `UN1`.

## Rows

* `UF14` — the 55 unconditional names are now frozen **name for name and in
  order**, not merely counted, and the row asserts `select` is no longer among
  them. The old row demanded "fifty or more" and there are fifty-five, so a name
  could be deleted with every check green (issue 0986 gap 3).
* `UF14b` — the second list parses to exactly `{select}`, and on a cell whose
  template declares no such parameter the setting is still excused while the
  control setting beside it is reported once.
* `UN1` — a cell whose template **does** declare `select`: one sentence about it,
  in the "another netlist carries it" shape naming *VHDL or Verilog*, and the
  control setting beside it still accusing.
* `UF19` — the shipped solar panel stays silent.

Mutation-verified against a built binary: making the second list unconditional
reddens `UN1` alone; emptying it reddens `UF14b` and `UF19`; deleting one name
from the first list reddens `UF14`.

## Rejected alternatives

1. **Drop `select` outright** and accept the noise on `solar_panel.sch`. Costs a
   shipped sheet four wrong lines and an editing convenience.
2. **Move all 56 names** to the cell-parameter-aware list. Manufactures false
   positives on 13 names shipped symbols already declare; see above.
3. **Special-case the name `select`** in the reach test. Leaves the other 55
   doors shut for the same wrong reason and teaches the next reader that the name
   is what mattered.
