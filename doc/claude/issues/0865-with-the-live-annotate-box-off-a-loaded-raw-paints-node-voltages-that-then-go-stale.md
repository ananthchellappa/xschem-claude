# 0865 — with "Live annotate" off, a node voltage stays on the sheet after the cursor leaves it

STATUS: **OPEN — measured 2026-08-27, NOT fixed. NEEDS THE USER'S RULING.**
Introduced by **0864** (the opt-in split), found by that item's adversarial
verification and re-measured from scratch here. A `rule` debt is recorded.

## What the user sees

1. Plot a transient, put cursor B at 4 ns.
2. Load the waves.
3. Press **`Alt-6`** — node voltages appear. Node `d` reads **4**. Correct: at
   4 ns, `v(d)` really is 4 V.
4. Press **`s`** in the graph to swap the cursors. Cursor B is now at 1 ns, where
   `v(d)` is **1 V**.
5. **The schematic still says 4.** Pressing `Alt-6` again does not refresh it.
   Nothing on the sheet says which time point that 4 belongs to.

The number is not fabricated — it was measured, at 4 ns — but it is displayed
beside a cursor that has moved on, which is the reading rulings **D5-1** and
**D4-3** exist to prevent.

## Why this is new, and it is 0864's doing

Before 0864, **Simulation > Graphs > "Live annotate probes with 'b' cursor"**
shipped TICKED, and it was also (wrongly) the render gate:

* ticked → every cursor move re-annotated, so the sheet could not go stale;
* unticked → the render gate blanked every node voltage, so there was nothing on
  the sheet to go stale (the 0864 BEFORE transcript, line B2f: *"box UNTICKED
  translate l1 @spice_get_voltage = ''"*).

0864 removed the render gate (correctly — the box's label promises only
"follow the cursor") and flipped the default to OFF (the user's demand). The
combination is a state that could not be reached before: **painted, and not
following.**

## Measured — 2026-08-27, binary as built for 0864, no rebuild

`./src/xschem --nogui --pipe -q --nolog --script <probe>`, fixture `g.sch`
(one `devices/lab_pin.sym` labelled `d`) plus a graph rect plotting `v(d)` from
a 5-point transient (0/1/2/3/4 V at 0/1/2/3/4 ns), cursor A at 1 ns,
cursor B at 4 ns. **`PAINTED` is the text actually emitted by an SVG export**,
not a token expansion — that distinction is the whole of this measurement, and
issue 0866 is what happens without it.

```
P0 shipped default: live_cursor2_backannotate=0  annot_show=0
P1 after loading waves, SHIPPED annot_show=0: token='4'  PAINTED texts = d
P2 after Alt-6 (annot_show 2):                token='4'  PAINTED texts = d 4
P3 after pressing s (cursor B now 1ns, v(d)=1):
     token='4'  annot=3 4e-09 0  PAINTED texts = d 4      <-- THE DEFECT
P4 after Ctrl-6 (annot_show 0):               token='4'  PAINTED texts = d
```

and, through the real chord (`cadence::annot_mode opvolt` — what `Alt-6` runs):

```
Q1 user presses Alt-6 (opvolt): mask=2 statusmsg='OP annotation ON (node voltages) -- raw already loaded'
   PAINTED = d 4   annot=3 4e-09 0
Q2 user presses s: cursor B now 1ns, v(d)@1ns=1
   PAINTED = d 4   annot=3 4e-09 0
Q3 user presses Alt-6 AGAIN to refresh: statusmsg='OP annotation ON (node voltages) -- raw already loaded'
   PAINTED = d 4   annot=3 4e-09 0                        <-- NO MANUAL REFRESH
```

The switch's remaining meaning still works, which is the positive control
(`probe3`, both legs identical but for the box):

```
R1 switch=1  cursorB 4ns labpin '4' -> after swap (B now 1ns) labpin '1'  annot 0 1e-09 0
R1 switch=0  cursorB 4ns labpin '4' -> after swap (B now 1ns) labpin '4'  annot 3 4e-09 0
```

## Mechanism — publication is not gated, only re-publication is

`backannotate_at_cursor_b_pos()` (`src/callback.c:1548`) is what writes
`xctx->raw->cursor_b_val[]` and stamps `raw->annot_p`. Its callers split in two:

**GATED on the switch** — these are the "follow the cursor" road, and 0864 left
them alone, correctly:

```
src/callback.c:2382  2553  2691  2747  3282   (cursor drags / clicks in a graph)
src/scheduler.c:13278                          (swap_cursors — the `s` key)
```

**NOT GATED** — these publish a cursor-B annotation whatever the box says:

```
src/save.c:1287        raw_read()      — loading waves
src/actions.c:4819     descend_schematic()
src/scheduler.c:12080 / 12112   `xschem set cursor2_x`
```

So with the box off the sheet still ACQUIRES a cursor-B annotation, and then the
gated half refuses to keep it current. That asymmetry is the defect. It was
invisible before 0864 only because the render gate hid the result.

## The shape of a fix, if the user rules that this must not happen

Gate **publication** on the switch instead of rendering: with the box off,
`raw_read` / `descend` / `set cursor2_x` publish nothing, `annot_p` stays -1,
nothing renders, and nothing can go stale. `6` and `Alt-6` are unaffected —
they publish through `update_op()` (`src/save.c:2276`), which never read the
switch and is a different road entirely. That keeps 0864's ruling intact
("the switch means follow-the-cursor") while removing the half-state.

The alternatives, so the ruling is a choice and not a rubber stamp:

* **(a) Gate publication** (above). Cost: with the box off, `Alt-6` on a
  *transient* would then paint nothing at all — because 0856 already ruled that
  `update_op()` does nothing silently for a transient, the cursor-B road is the
  only thing that publishes for one. That is arguably the ruled behaviour
  already ("we haven't yet built anything for annotating from TRAN results"),
  but it is a visible loss for anyone using `Alt-6` on a transient today.
* **(b) Re-annotate on demand.** Make `Alt-6` re-publish at the current cursor B
  even with the box off, so the sheet is refreshable by the chord the user
  already presses. Cheapest for the user; keeps a number on the sheet that is
  correct at the moment it is asked for.
* **(c) Say which time point it is.** Leave the value and make the sheet or the
  status line carry the annotated time, so a stale number is legible rather than
  silent. Most work, no behaviour removed.
* **(d) Accept it.** The box is off, so nothing follows the cursor — that is
  what off means, and Ctrl-6 clears the sheet.

## What is NOT wrong here — measured, so a later crew does not re-derive it

* **Nothing is painted unasked.** With the shipped `annot_show` of 0, loading
  waves paints no number at all (P1). The value only reaches the sheet after the
  user presses `Alt-6`. A report that says otherwise measured
  `xschem translate`, which is the token expansion and not the render path.
* **The user can still take them off:** `Ctrl-6` blanks them (P4). See **0866**.
* **The switch's own job is intact:** ticked, the annotation follows cursor B
  (R1, switch=1).

## Acceptance rows to write with the fix

Whichever option is ruled, these are the rows that pin it, and each needs a
PAINT (SVG-export) leg, not a `translate` leg — the token expands either way:

* **the stale row** — box off, `Alt-6`, then `s`: assert the painted text equals
  the value at cursor B's NEW position (or is absent, under option (a)).
* **the positive twin** — the identical sequence with the box ticked, which must
  keep following, so the row cannot pass by blanking everything.
* **the `Ctrl-6` control** — mask 0 paints no value in either arm.
* **a structural row** over the caller list above, since "gated" and "not gated"
  is a property of six-plus call sites that no single fixture reaches.
