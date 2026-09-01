# 0877 — the node-voltage render class carries no provenance stamp, so a bit can label a number an analysis it did not come from

**Status:** 🔴 **OPEN — measured, NOT fixed. Needs a user ruling before anyone builds it.**
Filed 2026-08-27 by the A3h hardening pass, as the residual of issue **0872**.
Class: **RULING D5-1** — a number presented as measured for something it was not
measured for — in the mirror direction from 0872's.

Owner: `annot_class_mask()` and `text_hidden()` in `src/actions.c` (~:1533/:1554), the
six `@spice_get_voltage` render gates in `src/token.c`
(:4372, :4861, :4953, :5039, :5134, :5207), and `ase::ui::annot_apply` in
`src/ase_window.tcl` (~:2489).

## What 0872 fixed, and what it deliberately did not

Issue **0872** is fixed for the breach a user can reach with the keyboard: on a
transient sheet, `Alt-6` and `6` now publish nothing and say nothing, because
`cadence::annot_mode` asks the database what analysis it holds before it writes the
mask. That fix is in **Tcl, at the point where the mode is chosen**, and it is
deliberately narrow.

**Three** faces survive it, and face 3 was found only by the repair pass's
verification. All three need a decision the user has not made.

## Face 1 — the OR at `src/actions.c:1533`, in the mirror direction

Measured on an **operating-point** database, `annot=0 0 -1` published by
`update_op()`:

```
### the transient bit over an OPERATING POINT database
  sim_type      = op  annot=0 0 -1
  mask 1        : PAINT=d g          (device OP info only -- correct)
  mask 2        : PAINT=d 1.234
  mask 4        : PAINT=d 1.234      <-- bit2 ALONE paints the OP number
  mask 6        : PAINT=d 1.234
  _annot_msg 4  = OP annotation ON (transient node voltages) -- loaded
  _annot_msg 6  = OP annotation ON (node voltages + transient node voltages) -- loaded
```

`1.234` was minted by an **operating point solve**. The status line calls it
**transient node voltages**. This one IS the shared render class 0872's file blamed:

```c
if(flags & TEXT_ANNOT_VOLTAGE) return ANNOT_SHOW_VOLTAGE | ANNOT_SHOW_TRAN;
```

Every `@spice_get_voltage` gate downstream tests only
`live && sch_waves_loaded() >= 0 && annot_p >= 0`. **None of them asks which analysis
published the point**, and the engine knows — `xctx->raw->sim_type` is right there.

## Face 2 — the ASE-L menu writes the mask directly, past the new refusal

The `Results > Annotate` checkbuttons do not go through `cadence::annot_mode`; they
write `annot_show` themselves in `ase::ui::annot_apply` (`src/ase_window.tcl:2489`).
So the 0872 refusal, which lives in the mode chooser, **does not reach them**: ticking
*Node Voltages* on a transient sheet still reveals the transient's numbers under the
OP wording. Rows N22b/N22c already assert WHERE each mask writer lives precisely
because there is more than one; this is the cost of that.

## Face 3 — the standing sentence outlives the database it described

Found by verification of the A3h pass and re-measured here. **It needs no menu, no
chord and no key press after the first one**, which is what makes it the easiest of
the three to meet by accident:

```
### an OP annotation, then the transient arrives underneath it
  Alt-6 on OP    : mask=2  PAINT=d 1.234
                   status = OP annotation ON (node voltages) -- raw already loaded
  attach a tran  : mask=2  sim_type=tran  annot=-1 0 -1  PAINT=d g
  drag cursor B  : annot=2 3e-09 0        PAINT=d 3 g 0.9
                   status STILL = OP annotation ON (node voltages) -- raw already loaded
```

⚠ **STATE THIS ONE PRECISELY, BECAUSE TWO OF ITS THREE PARTS ARE CORRECT.** `3` really
is `v(d)` at 3 ns — the number is honest. bit1 painting a transient's published sample
is row **V9**'s committed golden and is deliberate. And `xschem set cursor2_x` naming a
time is a **typed request**, which row **V25** records as a deliberate ruling. What is
wrong is the **sentence**: it was minted about an operating-point database, it is
**held** (issue 0248, so pointer motion cannot clear it), and nothing invalidates it
when the database underneath changes analysis. The user reads *"OP annotation ON (node
voltages)"* over a transient sample — **RULING D5-1 carried by the label alone**.

So face 3 is not closed by option 1's render-class stamp on its own: the stamp would
make the *paint* honest, and the stale *sentence* would still be sitting there. It is
closed either by invalidating the held line whenever the attached analysis changes, or
by naming the source inside the minted sentence (option 3) so that a stale one is
visibly about the old database. Whichever option the user picks, this face wants its
own acceptance row.

## Why it was not fixed with 0872

Because the honest fix changes what the user sees in a way they have not agreed to,
and it reds a committed row.

## Options

1. **One store, one provenance stamp.** Record which analysis published the current
   annotation (`xctx->raw->sim_type` at publish time) and let each bit render only its
   own kind, blanking otherwise — invariant I3's blank, never a fabricated number.
   Closes both faces at once. ⚠ **It reds row V9's mask-2 leg**, whose golden today is
   that bit1 paints a transient's published number, and it changes what the ASE-L
   checkbuttons do.
2. **Extend the refusal to the mask writer instead of the render class** — one gate in
   C on `xschem set annot_show`, so every writer (chord, menu, script) passes it.
   Smaller than option 1 and it closes face 2; it does **not** close face 1, because
   mask 4 over an OP database is not a wrong-analysis write, it is a wrong LABEL.
3. **Fix only the WORDS**: one label, *"Node voltages"*, with the source named in the
   sentence the mode mints. Cheapest, and it makes the status line honest; the sheet
   still shows an OP number for a bit called transient.

Recommended: **1**, and it wants the user's ruling because of V9 and because option 1
changes the ASE-L menu the user asked for in the 0868 request. Owed as `rule 0877`.

## Acceptance, whichever option is chosen

* a row over an **operating-point** database sweeping masks `0..7` and pinning what
  each paints, with the status wording beside it — face 1's discriminator;
* a row driving the **ASE-L checkbuttons** on a transient sheet and asserting the same
  refusal the chord now makes — face 2's;
* a row for **face 3**: annotate an operating point, attach a transient underneath it,
  move cursor B, and assert what the held status line says — the one face whose
  subject is the sentence rather than the paint;
* all three are behavioural, so none needs a structural fallback.
