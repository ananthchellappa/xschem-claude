# 0437 — a hierarchy walk emits save cards for `spice_ignore=true` instances that are not in the netlist

Status: **PARTIALLY FIXED IN S3b (three of seven classes), THEN REVERTED.
SUPERSEDED BY 0442 for the remaining four classes.** The fix is preserved in
`doc/claude/issues/0442-attempt-2-reverted.patch`, not in the tree.

⚠ **THE FIX THIS ISSUE ASKED FOR WAS INCOMPLETE, AND THAT IS WHAT REFUTED S3b.**
S3b measured and filtered three netlister drop classes (`spice_ignore`,
`only_toplevel`, `lvs_ignore`) and asserted in a boxed source comment that the
walk "EMITS ONLY WHAT THE NETLISTER WOULD". Four more classes exist —
`spice_stop`, `spice_sym_def`, `default_schematic=ignore`, and an empty symbol
`format` — all in `spice_netlist.c:635-665`, all unfiltered, all reachable on
ordinary PDK symbols. **Read 0442 before re-attempting this.**

⚠ **THIS ISSUE'S OWN PRESCRIBED PROBE IS STILL WRONG** and that finding stands
independently of the revert: `xschem translate <inst> @spice_ignore` reads
`sym->templ` only (token.c:5350) and is wrong in BOTH directions — it answers
`{}` for the symbol-G-record case this issue was filed about, and `true` for a
template-borne one whose device IS in the netlist. Do not implement it as
written. The netlister-faithful pair is `getprop instance <n> spice_ignore` OR
`... cell::spice_ignore`.

Previously: OPEN, measured, not fixed. This issue, with 0436, reverted step S3
(attempt 1). Filed by the S3 write-up agent (op-annotation crew, branch
`annotate`), who reproduced it directly rather than inheriting it from the
adversary pass.

Related: 0436 (the other not-in-the-netlist source), 0434 / spec R5 (why one bad
card is fatal), spec §5 I2b, spec §6 landmine 9.

## What was measured

Fixture: `wtop.sch` instantiates `wmid.sym`; `wmid.sch` holds two identical
sky130 FETs, one of which carries the standard `spice_ignore=true` attribute.

```
C {sky130_fd_pr/nfet_01v8.sym} 400 -300 0 0 {name=MOK  W=1 L=0.15 nf=1}
C {sky130_fd_pr/nfet_01v8.sym} 700 -300 0 0 {name=MIGN W=1 L=0.15 nf=1 spice_ignore=true}
```

`xschem netlist` — `MIGN` is **absent entirely**:

```
**.subckt wmid A
XMOK net1 net2 net3 net4 sky130_fd_pr__nfet_01v8 L=0.15 W=1 nf=1 ad=0.29 ...
**.ends
```

`op_annot::save_cards` on the same design — `MIGN` is **present**:

```
.save all
.save @m.x1.xmok.msky130_fd_pr__nfet_01v8[id]
.save @m.x1.xmok.msky130_fd_pr__nfet_01v8[gm]
.save @m.x1.xmign.msky130_fd_pr__nfet_01v8[id]     <- names nothing
.save @m.x1.xmign.msky130_fd_pr__nfet_01v8[gm]     <- names nothing

== warnings: || ==
```

`op_annot::last_warnings` is **empty**. Nothing anywhere reports that two of the
four cards name a device that will not exist in the deck.

## Why it matters more than "two junk columns"

Per **R5** / issue 0434, the cost of a card naming a non-existent device depends
on the invocation idiom, and the expensive one is the idiom the shipped benches
use:

| invocation | result |
|---|---|
| `ngspice -b -r out.raw` | fabricated `0.0` column (spec landmine 9) |
| `.control … write out.raw … .endc` — **every shipped PDK bench** | **no raw file at all** |

So **one** `spice_ignore=true` device anywhere in a design is enough to make the
generated `.save` file kill the simulation it was generated for. `spice_ignore`
is not exotic — it is the standard way to keep a device on the schematic but out
of the netlist (documentation-only devices, alternate-corner spares, symbols
placed for layout intent).

## Root cause

The walk's only filters are the descriptor's `match` globs (issue 0425) and
`nolist_libs` — which is empty in every stock workarea. Neither has anything to
do with whether the instance is netlisted. The walk asks "does this symbol have a
descriptor?" when the question a save-card emitter must ask is "will this device
be in the deck?".

Both PDK prototypes (`sky130_hier_sch_expand`, `sg13g2_hier_sch_expand`) have the
same hole, so this is not a regression introduced by S3 — but S3 was about to
ship it behind a **PDK-neutral** menu item, which widens the blast radius from
"the two PDKs that have their own menu" to "every PDK, including gf180, which has
no such menu today".

## The fix (not applied)

The emitter should skip an instance whose `spice_ignore` resolves truthy, i.e.
consult the same attribute the netlister does rather than inventing a second
rule. `xschem translate <inst> @spice_ignore` is the form that also sees a value
living in the symbol `template=` (the same trap that produced issue 0430 for
`spiceprefix` — `getprop instance … spice_ignore` reads only `inst.prop_ptr`).

Related unmeasured cases in the same class, which the fix should cover or
explicitly decline:

* `spice_ignore=short` — netlisted as a short, so the device does not exist under
  its own name either.
* `only_toplevel=true` on a device below the top.
* A device inside a subcircuit whose *symbol* is `spice_ignore`.

## Test coverage

```
$ grep -c 'spice_ignore' tests/headless/test_op_annot.tcl
0
```

No row anywhere in the S3 suite places a non-netlisted instance, which is why 85
green checks missed it. A single row asserting such an instance contributes zero
cards is now written into the plan's S3 acceptance cell.

## Still open

* The filter is unimplemented; the S3 retry owns it.
* The three related spellings above are unmeasured.
* Nothing cross-checks a generated block against `xschem netlist` — that
  comparison would catch this class wholesale (both this issue and 0436) and is
  a stronger acceptance than the card-list golden, which only proves the emitter
  agrees with itself.

# ============================================================================
# THE FIX, AS SHIPPED IN S3b (2026-08-16) — decisions D5/D6/D7
# ============================================================================

Status of this issue: **FIXED**, with rows S26-S31 of
`tests/headless/test_op_annot.tcl` as the guardians. ⚠ **But the probe this
issue PRESCRIBED was measured wrong in both directions and was NOT
implemented** — read that section before touching the filter.

## ⚠ THE CORRECTION: `xschem translate <inst> @spice_ignore` IS THE WRONG PROBE

This file's "Still open" section, and the plan that came from it, assumed the
filter would ask `translate`. Measured on this tree, on a purpose-built fixture
with `xschem netlist` as the oracle:

```
inst    spice_ignore lives in   translate      getprop <n>    getprop <n>       in the
                                @spice_ignore  spice_ignore   cell::spice_ignore netlist?
MSYM    symbol G record         {}             {}             true               NO
MTMPL   symbol template=        true           {}             {}                 YES
MOPEN   instance (=open)        open           open           {}                 NO
MSHORT  instance (=short)       short          short          {}                 NO
MTRUE   instance (=true)        true           true           {}                 NO
MOK     nowhere                 {}             {}             {}                 YES
```

`translate`'s fallback is `sym->templ` ONLY (`token.c:5350-5353`); it never reads
`sym->prop_ptr`. So the prescribed probe:

* **answers `{}` for the symbol-G-record case** — the exact case this issue was
  filed about — so the bogus card would still be emitted; and
* **answers `true` for a template-borne one whose device IS in the deck** — so a
  real device would silently lose its cards.

Wrong in BOTH directions. The netlister-faithful probe is
`getprop instance <n> spice_ignore` **OR** `... cell::spice_ignore`, because
`skip_instance2` (`netlist.c:1235`) ORs `inst.flags` with `sym.flags`,
`set_inst_flags` (`actions.c:1055`) reads only `inst->prop_ptr` and
`set_sym_flags` (`actions.c:960`) reads only `sym->prop_ptr`.

Row **S27 is a CONTROL that pins this measurement** — it asserts the PROBE's
behaviour, not the filter's, and must stay green while the filter is sabotaged.
It exists so nobody "fixes" the filter back to the prescribed form.

## D5 — the filter is the netlister's OWN FOUR CLASSES, in its own spellings

`op_annot::_netlisted {i root}`, mirroring `skip_instance()`:

1. **spice_ignore** on the instance or the symbol, in `util.c:72`'s truthy
   spellings (all-digit non-zero, or `true`/`on`/`yes` case-insensitively) plus
   exact-case `open` and `short` (`short` counts because `spice_netlist.c:209`
   calls `skip_instance(i, 1, lvs_ignore)`);
2. **only_toplevel** — instance attribute only, truthy spellings only, dropped
   only BELOW the walk entry. `spice_netlist.c:216` gates it on `netlist_count`,
   i.e. on the cell being a subcircuit of the deck rather than its top; the
   walk's deck top is its ENTRY cell (issue 0436 / D2), so the test is "are we
   below the entry", **not** "is currsch > 0". Row S29 walks one cell three ways
   to pin that.
3. **lvs_ignore** on instance or symbol, gated on the user's `::lvs_ignore`
   global exactly as `spice_netlist.c:209` passes it in. The walk READS that
   global and never writes it (row S30 asserts both halves).
4. an unresolvable symbol needs nothing: it becomes a `type=missing` placeholder
   that no descriptor claims.

Truthiness lives in one helper, `op_annot::_boolattr`, mirroring `strboolcmp`
exactly — `open`/`short` are deliberately NOT folded into it, because
`only_toplevel` accepts neither and folding them in would over-filter one caller
to please another.

## D6 — an ignored SUBCIRCUIT is not DESCENDED into, not merely not emitted

`spice_netlist.c:464` writes a symbol's `.subckt` DEFINITION even when every
calling instance is ignored, but no call to it is written — so **no device
anywhere below that instance exists in the run**. A guard bolted onto the card
emitter alone would still walk in and name every one of them: this issue's
defect arriving through a different door. Separate seam
(`op_annot::_descendable`) so the two failures are independently reachable and
independently sabotageable. Row S28, with the un-ignored control beside it.

## D7 — a filtered instance produces NO warning

`last_warnings` stays reserved for cells the walk could not enter. Rung L2:
`spice_ignore` is the ordinary way to keep a documentation-only device on a
sheet, and one line per skipped device would bury the one warning that matters
under hundreds on a real PDK design.

## The acceptance this issue asked for, delivered

> Nothing cross-checks a generated block against `xschem netlist` — that
> comparison would catch this class wholesale.

Row **S31** does exactly that: it netlists the filter fixture, parses the deck
top's element names out of the `**.subckt` / `**.ends` block, and asserts the set
of device paths the cards name EQUALS it. The netlister is the oracle, not a
second copy of its rules. Measured both halves: `{xmlvs xmok xmtmpl}`.

## Sabotage matrix (clean run = `RESULT: ALL PASS (96 checks)`, headless)

```
filter_dead                          -> S26 S28 S29 S30 S31   (S2/S8 stay green)
filter_uses_translate_probe          -> S26 S30 S31           (S27 stays green)
filter_skips_cards_but_still_descends-> S28                   (S26 stays green)
```

`filter_uses_translate_probe` — which implements THIS ISSUE'S PRESCRIBED FIX
verbatim — reds S26 in both directions at once and reds S31 against the
netlister. That is the measurement, run as a test.
