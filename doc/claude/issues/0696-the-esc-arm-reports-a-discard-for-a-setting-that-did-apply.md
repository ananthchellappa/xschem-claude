# 0696 — the ESC arm reports a discard for a setting that DID apply

Status: OPEN, FILED NOT FIXED. Filed 2026-08-25 by the 0691+0692 crew's
write-up pass, from the adversary pass's finding B1 and re-measured
independently before filing. **This defect did not exist before the 0692 fix —
the 0692 fix created it.** Related: **0692** (the fix that opened this window),
0648 (the discard-notice model), 0679, 0695.

## The shape

`ase::ui::save_all_cancel` (`src/ase_window.tcl:3488`) now asks
`ase::ui::save_all_touched` which boxes to report as discarded, and
`save_all_touched` answers **"the record differs from the AS-OPENED seed"**.
That is not the same predicate as **"the user's change was lost"**.

When the user ticks a box by hand *and* an external write sets the same blanket
to the same value, the field is `touched` (it differs from the seed) but nothing
was lost — the live state already agrees with the box. ESC then prints the 0648
discard notice about a setting that **is** applied, and re-arms the OP-card
nudge on the way out.

## Measured — after the 0692 fix, on `:99` with openbox 3.6.1 live

Gesture: open `Outputs > Save All` with the OP gate **off**; the user
**hand-ticks** 'Save device OP parameters'; the pasted CIW remedy *also* turns
the gate on behind the dialog; press **ESC**.

```
WU-B1 seedbox=0 remedy_rc=1 gate=1 pending={opparams} notices=1
WU-B1-NOTICE: ASE: Save All was closed without OK — 'Save device OP parameters'
              was NOT applied. Reopen Outputs > Save All and press OK.
WU-B1 gate_after_esc=1
```

Read the last line against the notice. **`gate_after_esc=1` — the gate IS on,
the setting DID apply — and the dialog tells the user it did not and to go do it
again.** At HEAD this gesture was silent, because HEAD diffed the record against
the LIVE state and `1 ne 1` is false.

## Why this is worth a number rather than a footnote

The phantom notice on an *untouched* dialog is precisely what justified touching
`save_all_cancel` at all in the 0692 pass. That one is fixed and stays fixed
(`PROBE0692C ... phantom_discard_notices=0`). This is the same false sentence
surviving on a different gesture, so the 0692 pass removed one false-notice case
and manufactured another, milder one. It must not be recorded as "the ESC arm is
now honest" — it is honest for the reported gesture and wrong for this one.

Severity is lower than what it replaced: the user is told to redo work that is
already done (annoying, and it re-arms a nudge), but no state is lost and the
gate is correct. That is why it is filed rather than hot-fixed in a pass that
had already finished its sabotage and adversary rounds.

## Recommended fix (not taken here)

Narrow the **cancel consumer only**: report a field as discarded when it differs
from the seed **and** differs from the LIVE state — i.e. when the user's change
really was lost. `save_all_touched` stays the one definition of "the user
changed this box" for the OK reconcile, which needs the seed diff alone.

Checked against the three gestures that must not move:

| gesture | seed | box | live | report? |
|---|---|---|---|---|
| plain 0648 hand tick, ESC | 0 | 1 | 0 | **yes** (box ≠ live) |
| 0692 untouched + external write, ESC | 0 | 0 | 1 | no (untouched) |
| this issue: hand tick + external write, ESC | 0 | 1 | 1 | no (box = live) |

⚠ Do NOT implement it by reverting `save_all_cancel` to HEAD's live diff — that
reinstates 0692's phantom notice, which is the worse of the two.

## Acceptance

1. The `WU-B1` gesture emits **zero** `NOT applied` notices and does not re-arm
   the OP-card nudge, with `gate_after_esc=1` unchanged.
2. `test_ase_window` W1za's contrast arm (a plain hand tick discarded by ESC)
   still emits exactly one notice naming 'Save device OP parameters'.
3. `test_ase_dialogs` GE10b–GE10h stay green — 0648's model is the scope fence.
