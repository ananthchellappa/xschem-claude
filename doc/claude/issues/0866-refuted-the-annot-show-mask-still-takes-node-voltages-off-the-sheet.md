# 0866 — REFUTED: "after 0864 nothing takes annotated node voltages off the sheet"

STATUS: **NOT A DEFECT. Filed so the claim is not re-derived.** Measured
2026-08-27 on the 0864 build.

## The claim

0864's adversarial verification reported that after the opt-in split there is
*"no user control left that takes annotated numbers off the schematic short of
unloading the data"* — that unticking **Simulation > Graphs > "Live annotate
probes with 'b' cursor"** used to blank every annotated number in one click and
nothing replaced it. Its evidence:

```
Q2a annot_show default 0 -> labpin '3'
Q2b annot_show 0 -> labpin '3'
Q2c annot_show 3 -> labpin '3'
Q2d box unticked -> labpin '3'
Q2e after Waves>Clear (raw_clear) -> labpin ''
```

## Why it is wrong

`labpin` there is `xschem translate l1 {@spice_get_voltage}` — the **token
expansion**, which is not the render path. Text visibility is decided later, by
the one predicate `text_hidden()` (`src/actions.c`, S7), and annotation classes
answer to the `annot_show` mask (issue **0614**: `6` |= bit0, `Alt-6` |= bit1,
`Ctrl-6` = 0). A `T {@spice_get_voltage}` record is classified by CONTENT, so
`Ctrl-6` hides it whatever `translate` returns.

Re-measured against the **painted** output (SVG export, same fixture and the
same binary):

```
P1 after loading waves, SHIPPED annot_show=0: token='4'  PAINTED texts = d
P2 after Alt-6 (annot_show 2):                token='4'  PAINTED texts = d 4
P4 after Ctrl-6 (annot_show 0):               token='4'  PAINTED texts = d
```

`Ctrl-6` is the control, it still works, and it is the control **0614 ruled**
should own this. The token expanding to `4` under mask 0 is exactly what the
0614 design says: one predicate at draw time, no tenth visibility test bolted
onto `translate()`.

The same distinction refutes the companion claim that with the box off a loaded
raw *paints* node voltages nobody asked for: with the shipped mask of 0 it
paints nothing (P1). What survives from that report is narrower and real, and it
is filed as **0865** — a value that is already on the sheet does not follow
cursor B, and `Alt-6` will not refresh it.

## The lesson worth keeping

**`xschem translate` is not a paint measurement.** Every row and every probe
that claims something is or is not on the schematic must read an SVG/PS export
(or pixels), because between the token and the sheet sits `text_hidden()` and
the `annot_show` mask. Two of the three findings in a careful adversarial pass
came apart on exactly this.
