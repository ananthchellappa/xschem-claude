# 0437 — a hierarchy walk emits save cards for `spice_ignore=true` instances that are not in the netlist

Status: **OPEN, measured, not fixed. This issue, with 0436, reverted step S3.**
Filed by the S3 write-up agent (op-annotation crew, branch `annotate`), who
reproduced it directly rather than inheriting it from the adversary pass.

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
