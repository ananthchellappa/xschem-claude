# 0621 — with 0614 landed, `annot_show`'s default decides whether XSCHEM's stock live back-annotation starts ON

STATUS: **OPEN — STATUS E, the ruling is the user's.** Filed by the crew that
implemented [0614](0614-annot-chords-must-own-node-voltages.md) and
[0615](0615-node-voltage-colour-collides-with-op-block.md). The implementation
shipped with the default at **0** and this issue is the escape hatch and the
question. Related: 0613, 0457(b).

---

## THE QUESTION FOR THE USER, IN ONE LINE

> Should `annot_show` default to **0** — node voltages and branch currents OFF at
> startup until you press `Alt-6` / tick View > Show node voltage / branch current
> annotation / use Waves > Op Annotate — or to **2**, i.e. node voltages ON at
> startup exactly as every XSCHEM before 0614, with the chords and the View pair
> still owning them?

Both are one line. Shipped as 0; `set annot_show 2` in `~/.xschem/xschemrc`
reverses it with no rebuild.

## Why the question exists at all

0614 ruled that the three chords **own** the node voltages: `Ctrl-6` clears both
bits and must leave *nothing* painted. Giving bit1 real producers is what makes
that true — and it makes the mask's resting value decide something it never
decided before.

Before 0614, `annot_show` 0 meant "no `hide=op` device blocks". XSCHEM's own live
cursor-2 back-annotation — the node voltages on `lab_pin` / `ipin` / `opin` /
`vdd` / `lab_wire` / `ngspice_probe`, and the branch currents on `ammeter` /
`capa` / `ind` / `diode` / `isource` / `bsource` / `cccs` / `isource_table` — ran
underneath it and appeared the moment a raw was loaded, mask or no mask. After
0614 those texts are class `TEXT_ANNOT_VOLTAGE` / `TEXT_ANNOT_CURRENT` and follow
bit1. With the default at 0 they do **not** appear until asked for.

## What the user has said that bears on it, and why it does not settle it

- 0613, unprompted, second session: *"node voltages are already displayed without
  asking for them."* That is an argument for 0.
- 0614's ruling: *"`Ctrl-6` -> everything off."* That needs bit1 to gate them, but
  says nothing about the value at startup.
- 0615: *"for node voltage display, use white."* Presupposes the display exists;
  says nothing about when.

None of the three names the resting value, so decision-ladder **L3** applies:
implement the least surprising option, ship it, and put the exact question here.

## What shipped, and the reasoning (ladder L2)

**Default 0.** It is the one value consistent with the only sentence the user
wrote about the pre-0614 behaviour ("without asking for them"), it matches the
existing `annot_show` default that 0457(b)'s checkbuttons and `xschem.tcl`'s
`set_ne annot_show 0` already document, and it makes `Ctrl-6` and a fresh session
agree — a startup value of 2 would mean the *only* way to reach mask 0 is a chord
the user has to know about.

Rejected: default 2. It preserves every pre-0614 session byte-for-byte, which is
a real virtue, but it makes "annotation is off" a state XSCHEM never starts in.

## Measured, so the cost of each answer is known

Fixture: one annotatable device, one `lab_pin` node voltage, one `capa` branch
current, an Operating Point raw, SVG at each mask (this crew's own measurement,
`/tmp/.../scratch_0614+0615/chord_acc.tcl`):

| chord | mask | bytes | on screen |
|---|---|---|---|
| `Ctrl-6` | 0 | 4298 | nothing |
| `6` | 1 | 4888 | OP blocks only |
| `Alt-6` | 3 | 5123 | blocks **and** voltages |
| `Ctrl-6` then `Alt-6` | 2 | 4533 | voltages **only** |

With **no raw loaded** the default is invisible either way: 16 SVG exports across
four shipped sheets (`ngspice/solar_panel.sch`, `ngspice/pv_ngspice.sch`,
`pcb/pcb_current_protection_embed.sch`, `examples/cmos_example.sch`) × four masks
are **byte-identical between the pre-0614 binary and the patched one**. So the
default only bites in a session that has loaded a raw.

## The escape hatch, either way

```tcl
# ~/.xschem/xschemrc
set annot_show 2      ;# node voltages + branch currents on from startup
set annot_show 3      ;# ... and device OP blocks too
```

`src/xschem.tcl` seeds `annot_show_op` / `annot_show_voltage` from the mask, so
the View > Show checkbuttons open already ticked.

## Acceptance for whichever answer is given

- The chosen value appears in exactly two places and they agree: `set_ne
  annot_show <n>` (`src/xschem.tcl`) and `xctx->annot_show = <n>` in
  `alloc_xschem_data()` (`src/xinit.c`).
- `tests/headless/test_op_annot.tcl` row L28 / section U's `U_DEFLAY`-style
  default read is updated to the chosen value in the same commit.
- With no raw loaded, the shipped-sheet exports stay byte-identical.

---

## ⚠ CORRECTION to the acceptance above, measured by the adversary after this issue was filed

The acceptance says "the chosen value appears in exactly two places and they
agree: `set_ne annot_show <n>` (`src/xschem.tcl`) and `xctx->annot_show = <n>` in
`alloc_xschem_data()` (`src/xinit.c`)". Both must still agree — but they are **not
equal partners**.

Measured on the tabbed interface: a **newly created tab inherits `annot_show` (and
`annot_voltage_layer`) from the Tcl mirror, not from `xinit.c`'s C default**. Tab
1 set to `annot_voltage_layer 7` / `annot_show 2` -> a new tab opens at **7/2**,
not 9/0. So the C initialiser only ever applies to the **first** context of a
session.

Consequence for whichever answer is given: **the value the user actually
experiences is the `set_ne` line in `src/xschem.tcl`.** `xinit.c:941` must match
it for coherence, but changing only `xinit.c` would change nothing a user can see.
