# 0427 — sky130's generated .save file omits `id`, which all 40 shipped FET symbols display

**Status:** open (measured during S2 of `doc/claude/specs/op_annotation.md`; worked
around in the new descriptor, NOT fixed in the prototype)
**Severity:** low — one missing number on screen, no wrong number
**Area:** `sky130A/sky130_procs.tcl`, `sky130A/xschem_libs/sky130_fd_pr/*/symbol/*.sym`

## What is wrong

`sky130_write_save_lines` (`sky130A/sky130_procs.tcl:72-89`) emits **seven**
`.save` cards per FET — `gm gds vth vdsat cgg cgso cgdo`. It never saves `id`.

Meanwhile **40 shipped sky130 FET symbols** carry a text that displays it:

```
T {id=@spice_get_node i(\@m.@path@spiceprefix@name\.msky130_fd_pr__@model\[id\])} ...
```

Measured on this tree:

```
$ grep -rl 'id=@spice_get_node' sky130A/xschem_libs/sky130_fd_pr/*/symbol/*.sym | wc -l
40
$ grep -c 'save.*\[id\]' sky130A/sky130_procs.tcl
0
```

So a user who takes the `SKY130 > Create FET .save file` menu output, includes it
in a testbench and simulates gets a raw file in which every symbol's own `id=`
line has nothing to read. Per spec §5 I3 that renders blank — it is not a wrong
number — but it is a parameter the PDK's own symbols promise and its own save
file never delivers.

## Consequence, and why it is only low severity

`.save all` is not a workaround: spec §3 R1 was measured — `gm`/`gds`/`vth`/
`vdsat`/`cgg`/`id` exist in the raw **only** if the deck saved them explicitly,
one card per device per parameter. So the parameter is genuinely absent, not
merely unrequested.

It is low severity because the failure is a blank, not a fabricated value. The
neighbouring landmine (spec §6 landmine 9) is the dangerous one: a card naming a
device that is *not* in the netlist still writes a full 0.0 column. That is not
what happens here.

## What S2 did about it

Not fixed in the prototype — `sky130_write_save_lines` is left byte-for-byte
intact because it is the acceptance oracle for the S2 generalization
(`tests/headless/test_op_annot.tcl` row P3 diffs 119 cards against it).

Instead the new `op_annot` descriptor in `sky130A/sky130_procs.tcl` **carries
`id` as a params row** (eight params, the prototype's seven plus `id`), so once
S3's generic emitter replaces the prototype the card is emitted and the symbols'
own `id=` line starts reading. Row P9 of `tests/headless/test_op_annot.tcl` pins
that param list, specifically so a later "align the descriptor with the
prototype" edit cannot silently delete a parameter users already see on screen.

Recorded as decision **D7** of the S2 plan.

## Fixing it properly

Either add `.save $devpath\[id\]` to `sky130_write_save_lines`, or — better, and
what the spec is heading for — delete `sky130_write_save_lines` entirely once
`op_annot::save_cards` (S3) is the only emitter. The second option closes this
issue as a side effect and is the reason it is not being patched now.

## Related

* `doc/claude/specs/op_annotation.md` §3 R1, §4.2, §5 I3, §6 landmine 9
* issue 0428 — a *different* sky130 symbol-vs-prototype disagreement
  (`pfet_g5v0d16v0_nf.sym`'s inner-device spelling), found in the same sweep
