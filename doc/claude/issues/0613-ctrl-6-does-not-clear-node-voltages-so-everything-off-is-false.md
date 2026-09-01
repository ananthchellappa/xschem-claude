# 0613 — `Ctrl-6` clears the OP blocks but not the node voltages, so "everything off" is false

STATUS: **RULED 2026-08-22 — superseded by [0614](0614-annot-chords-must-own-node-voltages.md).**
The user chose option 1: the chords take authority over the node voltages. This
file keeps the measurement; 0614 carries the work.
Originally reported and reproduced 2026-08-22. Found by the user in the
first eyes-on session for OP annotation. Related: 0457 (the mask's controls),
S8/S9b, `utils/annot_mode.tcl`.

---

## What the user sees

`src/cadence_style_rc:283` documents the three chords:

```
#   6       device OP info on            (mask 1)
#   Alt-6   device OP info + node voltages (mask 3 -- a SUPERSET of 6, not a swap)
#   Ctrl-6  everything off               (mask 0)
```

**`Ctrl-6` does not turn everything off.** It clears the six-row device blocks and
leaves every node voltage and branch current on the sheet.

Worse, the user's first observation on launch: **the node voltages were already
displayed before any key was pressed.** They are not something a chord turned on,
so they are not something a chord can turn off.

## Measured

`bandgap_opamp`, 13 FETs, 15.8 MB tran raw, `cursor2_x` 20 µs, rendered at each
mask (`<scratch>/bg/ck_[ABC]_*.png`):

| mask | chord | bytes | what is on screen |
|---|---|---|---|
| 1 | `6` | 169897 | six-row blocks **+** node voltages |
| 3 | `Alt-6` | 169897 | **byte-identical to mask 1** |
| 0 | `Ctrl-6` | 114394 | blocks gone, **node voltages remain** |

Surviving `Ctrl-6`, read off the mask-0 render: `1.8` on VCC, `0.8696` on ADJ,
`1.461` on SP, `0.5328` on G1, `0.4967` on G2, `1.185` on DIFFOUT, and the branch
currents `4.854u`, `2.43u`, `2.424u`, `12.83u`, `7.25u`, `905.8p`, `413.8n`.

**Mask 1 and mask 3 are byte-identical on this sheet**, which is a second finding
worth keeping: `bandgap_opamp` carries no `hide=voltage` texts, so bit1 has nothing
to gate and `Alt-6` is indistinguishable from `6`. The user read that as "Alt-6
also shows OP info", i.e. as a bug. It is not — `cadence::_annot_mask` returns 3
for `opvolt` and the spec's three-state table forbids dropping bit0 — but the
*documentation* invites the misreading by describing `Alt-6` as adding something
that, here, it does not.

## Cause

`annot_show` gates `hide=op` / `hide=voltage` **text records inside symbols**, via
`text_hidden()`. The node voltages and branch currents on the sheet come from
XSCHEM's **native OP back-annotation**, driven by the loaded raw and the cursor —
a different mechanism entirely, over which `annot_show` has no authority.

So the mask was never "everything". Two independent annotation systems are on
screen at once and only one has a switch.

## What is owed — and it is a decision, not just a fix

Three shapes, none chosen:

1. **Make `Ctrl-6` mean what it says** — have `cadence::annot_mode none` also
   clear the native back-annotation. Honest to the documentation, but it takes a
   chord that is documented as *view state* (invariant I4: nothing here modifies
   the schematic) and gives it authority over a different subsystem.
2. **Fix the documentation** — `Ctrl-6` clears *OP annotation*, and node voltages
   have their own control elsewhere. Cheapest, and honest, but leaves the user
   with no single off switch for what is visibly one feature.
3. **Give the native annotation a control too**, next to the 0457(b) View-menu
   pair, so the sheet has one place that turns all of it off.

Option 3 is the one that matches what the user actually wanted when they pressed
`Ctrl-6`, and it is the natural third checkbutton under *View > Show*.

## Not a regression

Nothing here was introduced by S8/S9b. The native back-annotation predates the
`annot_show` mask; what S8 added was a chord whose documentation over-promises.
