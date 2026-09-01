# 0696 — the ESC arm reports a discard for a setting that DID apply

Status: **FIXED 2026-08-25** (status **E** — the item it shipped in is
user-visible and unratified; see 0695's RESOLUTION and rule debt [0692]). Fixed
together with **0695** in ONE item, because both ask one question: what does this
dialog consider the user's intent, once the checkbutton's variable can move
underneath them. Filed 2026-08-25 by the 0691+0692 crew's
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

---

# RESOLUTION — 2026-08-25, fixed with 0695 as ONE item

The full decision record, sabotage matrix and residual-risk list live in
**0695's RESOLUTION section** — this item was one crew, one commit, one question.
What is specific to 0696 is below.

## The recommendation was taken as written

The issue recommended narrowing **the cancel consumer only**: report a field when
it is touched **and** still differs from the LIVE state. That is exactly what
shipped, as its own named proc:

```tcl
proc ase::ui::save_all_discarded {key} {
  variable dlg
  if {[catch {ase::ui::save_all_current $key} live]} { return {} }
  set out {}
  foreach f [ase::ui::save_all_touched $key] {
    if {![dict exists $live $f]} { lappend out $f; continue }
    if {$dlg($key,$f) ne [dict get $live $f]} { lappend out $f }
  }
  return $out
}
```

`save_all_cancel` calls it for **both** the notice and the OP-card nudge re-arm.
Keying the re-arm off the raw touched list would have silenced the sentence and
still fired the nudge — 0696 half-fixed, and arguably more confusing than not
fixing it at all. `save_all_report_discard` and the nudge model itself are
untouched, so **0648 is not reworked**: only the predicate feeding them moved.

⚠ The issue's warning was honoured: this is **not** a revert of `save_all_cancel`
to HEAD's live diff. The narrowing sits on top of `save_all_touched`, whose
definition changed with 0695 from "differs from the as-opened seed" to "the
widget's own `-command` fired" (0695 decision D1) — but whose name, signature and
role as THE one definition did not.

## BEFORE → AFTER, same probe, same display

`:99`, Xvfb 1920x1080x24, **openbox 3.6.1 live**.

```
BEFORE  WU-B1 seedbox=0 remedy_rc=1 gate=1 pending={opparams} notices=1
        WU-B1-NOTICE: ASE: Save All was closed without OK — 'Save device OP
                      parameters' was NOT applied. Reopen Outputs > Save All and press OK.
        WU-B1 gate_after_esc=1

AFTER   WU-B1 seedbox=0 remedy_rc=1 gate=1 pending={opparams} notices=0
        WU-B1 gate_after_esc=1
```

**`pending={opparams}` is unchanged, and that is the design.** The user really
did touch that box, so `save_all_touched` still names it (0695 decision D2: a
touched field stays touched). The narrowing lives in the consumer, so nothing
about what OK writes moved.

The three gestures the issue tabulated, all re-measured after the fix:

| gesture | seed/box/live | before | after |
|---|---|---|---|
| plain 0648 hand tick, ESC | 0 / 1 / 0 | 1 notice | **1 notice** (`CONTRAST-A notices=1 gate=0`) |
| 0692 untouched + external write, ESC | 0 / 0 / 1 | 0 notices | **0 notices** (`CONTRAST-B notices=0 gate=1`) |
| **this issue**: hand tick + external write, ESC | 0 / 1 / 1 | **1 notice** | **0 notices**, `gate_after_esc=1` |

Also driven through the **window-manager close** path (`wm protocol …
WM_DELETE_WINDOW`, which is the same `save_all_cancel`): `WM-B1 notices=0 gate=1
touched_rec=0`, while the plain-hand-tick control on that same path still prints
exactly one (`WM-CTL notices=1`).

## The discriminator that isolates this issue

**SAB-0696-D** — stub `save_all_discarded` to the pre-fix predicate
(`return [ase::ui::save_all_touched $key]`): predicted **W1zd only**, observed
**W1zd ONLY**, with `test_ase_dialogs` still ALL PASS (174). That is why the
narrowing is a named callee and not an inline filter (the 0679/0691 precedent:
honesty lives in something you can stub).

## Acceptance — measured

1. `WU-B1` emits **zero** `NOT applied` notices and does not re-arm the nudge,
   `gate_after_esc=1` unchanged — **MET** (row **W1zd**, which asserts
   `{n_notices gate_after_esc nudge_rearmed} = {0 1 0}` and is RED at HEAD).
2. W1za's contrast arm (a plain hand tick discarded by ESC) still emits exactly
   one notice naming 'Save device OP parameters' — **MET** (`CONTRAST-A`, and
   W1za/W1za2 green; SAB-0695-C reddens them, proving they are load-bearing).
3. `test_ase_dialogs` GE10b–GE10h stay green — **MET**; the suite is 172 → 174
   ALL PASS (+GE10j, +GE10k; GE10i retargeted from the deleted `seed` record to
   `touched`, not weakened).

## Still open, specific to this arm

* The discard sentence still reads "was NOT applied" for a discarded **untick**
  (the message names the box while the gate IS on). That is pre-existing prose
  drift, **issue 0661**, deliberately out of scope here — same "a report that
  lies" family, and the user will meet it on the bench.
* `save_all_discarded` compares the RAW box value to live rather than
  `save_all_resolve`'s output — a third reading of "what this dialog means",
  consistent today only because resolve answers a touched box's own value.
