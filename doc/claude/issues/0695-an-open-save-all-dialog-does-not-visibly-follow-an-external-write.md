# 0695 — an open `Save All` dialog does not VISIBLY follow an external write

Status: OPEN, FILED NOT FIXED. Filed 2026-08-25 by the 0691+0692 crew as the
declared residual of the 0692 fix. Related: **0692** (fixed — the state half),
0679, 0648 (the dialog's diff/cancel model), 0696.

⚠ **SEVERITY RAISED 2026-08-25 BY THE SAME CREW'S WRITE-UP PASS, BEFORE THIS
EVER SHIPPED.** This was filed as a cosmetic lag. It is not: the display lag has
a DATA consequence, measured below (§ "The lag is not cosmetic"), reachable with
two shipped menu items. The sentence "the display lag is not a data-loss defect
once OK and ESC are honest" below was **wrong when written** and is struck
through where it appears. Treat this as blocking for the 0692 ruling, not as a
follow-up nicety.

## What 0692 fixed, and what it deliberately did not

0692's defect was that an OPEN `Save All` dialog is a snapshot: the pasted CIW
remedy turned the OP gate ON behind it and OK wrote the stale `0` back. That is
fixed — `ase::ui::save_all_resolve` (src/ase_window.tcl:3419) now takes the user's value for a box they
touched and the LIVE value for one they did not, and `save_all_cancel` (:3488) diffs
against the AS-OPENED seed so ESC no longer prints a phantom "was NOT applied"
about a setting that *was* applied.

**The pixels still lag.** Measured after the fix, through the real widget on
`:99` with openbox live:

```
PROBE0692  seed=0 remedy_rc=1 gate_after_remedy=1 box_still=0 ok_rc=1 gate_after_ok=1
PROBE0692C seed=0 remedy_rc=1 gate_after_remedy=1 box_still=0
           phantom_discard_notices=0 gate_after_esc=1
```

`box_still=0` is this issue: the checkbutton keeps displaying the pre-write value
until the dialog is closed and reopened. OK and ESC are now correct about the
state; the widget is not correct about itself.

## Why it was not fixed with 0692

A live refresh is 0692's **option 1** (re-seed from inside
`ase::ui::save_all_commit`), which the 0692 write-up flags with a ⚠ of its own:
it puts a widget side effect into the shared writer the pasted remedy calls, it
would silently move a box the user had just ticked by hand and not yet OK'd, and
it changes what 0679's SAB-N6 sabotage discriminator proves. L2: smallest blast
radius wins, ~~and the display lag is not a data-loss defect once OK and ESC are
honest~~ — **that struck clause is false; see the next section.**

## The lag is not cosmetic — measured, two shipped menu items

Because `ase::ui::save_all_resolve` gives an **untouched** box the LIVE value,
and the checkbutton does not follow the live value, an open dialog can DISPLAY a
ticked box while OK writes it **off**. Measured after the 0692 fix, on `:99` with
openbox 3.6.1 live, driving the real product workers:

```
WU-B2 box_at_open=1 load_rc=1 live_after_load=0 box_still=1 ok_rc=1 gate_after_ok=0
```

The gesture is entirely ordinary:

1. `ASE-L > Outputs > Save All` with 'Save device OP parameters' **ticked**
   (`box_at_open=1`), left open.
2. `ASE-L > Session > Load State`, importing a state whose gate is off
   (`live_after_load=0`). A shipped menu item, not a probe seam.
3. The checkbutton still shows **ticked** (`box_still=1`).
4. Press **OK** → the gate is written **off** (`gate_after_ok=0`).

At HEAD this wrote **on**, matching the box the user was looking at. So for this
gesture the 0692 fix is a regression in what the user GETS versus what they SEE,
and not a harmless one: `ase::op_cards_capture` gates the whole OP-card block on
`save_op_params`, so the next deck is emitted with **no OP save cards** while the
dialog says they are on — the silent-missing-numbers failure the whole 0648/0679
arc exists to end.

⚠ This is not an argument for reverting 0692. Both halves cannot be satisfied at
once: "an untouched box takes the live value" is what fixes the reported defect,
and it is only coherent when the box FOLLOWS the live value. Fixing this issue is
what makes the 0692 reconcile whole.

## Pinned, so it cannot be forgotten

`tests/headless/test_ase_window.tcl`, row **W1x**, third term
(`box_before_ok`) is pinned at `0` with a comment naming this issue. **Flip that
term to 1 when this lands.**

## Acceptance (when scheduled)

1. An external write to any of the three blankets behind an open dialog moves the
   corresponding checkbutton, read off the widget's own `-variable`.
2. A box the user has ticked by hand and not yet OK'd is NOT moved by it (the
   conflict the ⚠ above names) — or, if it is, that is a ratified ruling and not
   a side effect.
3. W1x's third term is 1; W1y/W1z/W1za stay green.
4. **The `WU-B2` gesture above**: with the dialog open and showing a ticked box,
   a `Load State` that turns the gate off must not leave OK writing a value the
   user cannot see. Either the box follows (rows 1–3), or the race is reported
   (0692's rule debt, option (a)) — but "shows on, writes off" may not ship
   unratified.
