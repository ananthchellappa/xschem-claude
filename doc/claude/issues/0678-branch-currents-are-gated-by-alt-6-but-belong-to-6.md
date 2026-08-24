# 0678 — a voltage source's current is device OP info, so it belongs to `6`, not `Alt-6`

Status: OPEN. **A RULING REVERSAL, not a coding slip** — the code does exactly what
decision D4 said. Reported by the user 2026-08-24 from the 0614/0615 eyes-on look.
Related: 0613 (where the wrong grouping entered), 0614, 0615, 0621.

## The user's report, verbatim

> Yes, ALT-6 is going it's job for node voltages - but, it's also displaying OP info
> of voltage sources - namely their current. That should be controled by 6 key, not
> Alt-6.
>
> Otherwise, Alt-6 and 6 and Ctrl-6 behave as expected.

So the two additive setters and the clear-all are confirmed correct on a real bench.
Only the *membership* of one content class is wrong.

## Measured — it is deliberate, and the comment says so

`src/actions.c:1290-1291` classifies by content and sets two distinct flags:

```c
if(cls == ANNOT_CONTENT_VOLTAGE)      t->flags |= TEXT_ANNOT_VOLTAGE;
else if(cls == ANNOT_CONTENT_CURRENT) t->flags |= TEXT_ANNOT_CURRENT;
```

but `src/actions.c:1397` then gates BOTH with the same switch:

```c
if(flags & (TEXT_ANNOT_VOLTAGE | TEXT_ANNOT_CURRENT)) {   /* -> ANNOT_SHOW_VOLTAGE */
```

`src/actions.c:1359` records the intent — *"BRANCH CURRENTS ARE NOT HERE (decision
D4): TEXT_ANNOT_CURRENT joins the voltage SWITCH"* — and `src/xschem.h:416` traces it
to issue **0613**, *"0613 lists branch currents among what [the voltage chord]
controls"*.

**The flag split already exists.** `TEXT_ANNOT_CURRENT` (bit 9, `xschem.h:423`) is a
separate bit that was deliberately routed to the wrong switch. Nothing needs
inventing; one gate needs re-pointing.

## Why the user is right

`@spice_get_current` is read **per instance** — it is *that device's* terminal
current. A voltage source's current is a property of the device, exactly like a FET's
`id`. A node voltage is a property of the *net*. The chords split on that line:

* `6` — **device** operating-point information
* `Alt-6` — **net** quantities

Under that reading `TEXT_ANNOT_CURRENT` is on the wrong side of the line, and 0613
grouped it by *where the number comes from in the raw* rather than by *what the
number is about*.

## Fix

Re-point `TEXT_ANNOT_CURRENT` from `ANNOT_SHOW_VOLTAGE` to `ANNOT_SHOW_OP` at
`src/actions.c:1397`, and update the three sites that document the old grouping
(`actions.c:1359`, `xschem.h:416`, `xschem.h:886`).

⚠ **Do not fold the two flags together.** They are separate bits precisely so this
grouping is one line to change; collapsing them would make the next reversal a
rewrite.

⚠ **The data sources differ and must not be confused.** Branch currents come from
`.option savecurrents` (terminal currents), device OP parameters from explicit save
cards (measured rule R1). Moving the VISIBILITY switch does not move the data source,
and a sheet can legitimately have one without the other — so `6` must still render a
blank row rather than hiding the label when only one source is present (invariant I3).

## Acceptance

1. `6` on a sheet with `savecurrents` shows voltage-source currents; `Alt-6` does not.
2. `Alt-6` still shows node voltages, and still does not disturb OP blocks.
3. `Ctrl-6` still clears both.
4. `6` alone, with no `savecurrents` in the deck, renders the current row BLANK, not
   absent (I3).
5. The 0614 ruling table re-verified end to end — this must not silently re-open it.
