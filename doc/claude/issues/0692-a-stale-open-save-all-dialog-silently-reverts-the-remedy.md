# 0692 — a stale open `Save All` dialog silently reverts the remedy, and OK's `1` is truthful

Status: **FIXED 2026-08-25** by the 0691+0692 crew, taking this issue's own
recommended **option 2**; see § "AFTER". ⚠ The fix ships with two measured
residuals, both filed and neither hidden: **0695** (raised to blocking — an open
dialog can show a ticked box while OK writes it OFF) and **0696** (a NEW false
discard notice on a gesture HEAD was silent about). Filed 2026-08-25 by the 0679
crew's adversary and write-up passes. Related: **0679** (the fix that makes this window meaningful),
0648 (the dialog's own diff/cancel model), 0691, 0652 (a report that lies).

## The shape

`ase::ui::dlg($key,opparams)` — the checkbutton's `-variable` — is written in
**exactly one place**: `src/ase_window.tcl:3267`, inside `save_all_dialog`, at
**dialog creation time**. It is read at `:3315`, inside `save_all_ok`.
`ase::ui::populate` never touches `dlg`.

So an **open** `Save All` dialog is a snapshot of the gate as it was when the
dialog was created. Anything that changes the gate behind it — and after 0679 the
pasted CIW remedy is exactly such a thing — is invisible to it, and OK writes the
snapshot back over it.

## Measured — driven end to end, not inferred

On `:99` (openbox live), through the real widget, by inserting a probe into a copy
of `tests/headless/test_ase_window.tcl` after the W1w block:

```
PROBE0692 seed=0 remedy_rc=1 gate_after_remedy=1 box_still=0 ok_rc=1 gate_after_ok=0
```

Read it as the user's gesture:

| step | what the user does | what happens |
|---|---|---|
| `seed=0` | opens `ASE-L > Outputs > Save All`, sees the box **unticked**, leaves it up | dialog snapshots `opparams = 0` |
| `remedy_rc=1`, `gate_after_remedy=1` | pastes the printed remedy into the CIW | **the gate really goes ON** (this is 0679 fixed, working) |
| `box_still=0` | glances at the still-open dialog | it never noticed — still unticked |
| `ok_rc=1` | presses **OK** | returns `1`, and that `1` is **honest**: the write genuinely succeeded |
| `gate_after_ok=0` | | **the stale `0` was written back. The remedy is silently undone.** |

The user's own reported order (CIW first, *then* open the menu) is fine and is
what 0679's acceptance covers. This is the other order.

## Why it is worth a number even though the end state matches HEAD's

Before 0679 the remedy never worked, so nothing could be reverted. **The 0679 fix
is what creates this window.** And the failure is of the family the whole
0650/0653/0679 arc is about — the user is told a truthful `1` while the thing they
asked for is gone — except here no proc lies: `save_all_ok` correctly reports that
it wrote what the dialog held. The defect is that what the dialog held was stale.

## The same shape applies to the other two blankets

`dlg($key,allv)` (`:3265`) and `dlg($key,alli)` (`:3266`) are seeded identically.
Any programmatic write to `save_all_v` / `save_all_i` behind an open dialog is
reverted by OK the same way. `save_op_params` is simply the one with a documented
pasteable writer pointed at it.

## Fix options (none taken — this is a filing, not a decision)

1. **Re-seed on write.** `ase::ui::save_all_commit` (`:3240`, the 0679 seam)
   already sees every write; have it refresh `dlg($key,*)` from
   `ase::ui::save_all_current` when a dialog exists for that key. Smallest, and it
   puts the refresh in the one place all writes funnel through (invariant I1).
   ⚠ It would silently move a box the user had just ticked by hand and not yet
   OK'd — that is a real conflict, not a detail.
2. **Diff on OK.** Write back only the blankets whose `dlg` value differs from what
   the dialog was *seeded* with. Preserves a hand-toggle and an external write at
   once. Needs a second per-key record of the seed.
3. **Refuse on OK.** Detect that the state moved under the dialog and report it,
   the way 0648's discard notice does. Loudest, and closest to the existing model.

Option 2 is the one that surprises a user least; it is recorded here as the
suggestion, not as a ruling.

## Acceptance

1. The probe line above reads `gate_after_ok=1` — the remedy survives an OK
   pressed on a dialog that was open before it.
2. A box the user ticks by hand and then OKs still takes effect (non-vacuity: the
   fix must not make OK inert).
3. `test_ase_dialogs`' existing Save All OK / cancel / discard-notice rows stay
   green, 0648's diff model included.


---

# AFTER — fixed 2026-08-25 (option 2), and what it cost

## What shipped

Option 2 of the three listed above — the one this issue recommended — in four
pieces, **all local to the Save All dialog**. `save_all_commit`, `save_all_apply`,
`save_all_current` and `save_op_params_on` are **untouched**, which is what keeps
0679's seam and its SAB-N6 sabotage meaning intact.

| new proc | `src/ase_window.tcl` | what it is |
|---|---|---|
| `save_all_seed` | `:3381` | stores the AS-OPENED normalised dict as ONE record `dlg($key,seed)`, from the same `$cur` the three checkbutton records come from |
| `save_all_touched` | `:3397` | **THE ONE DEFINITION** of "the user changed this box", two consumers (I1) |
| `save_all_resolve` | `:3426` | the OK-path per-field reconcile |

`save_all_cancel` (`:3495`) diffs through `save_all_touched`; `save_all_close`
(`:3453`) unsets the seed.

**Nothing was made to report failure.** `save_all_ok`'s `1` was honest before and
is honest now — the repair is to the STALENESS, exactly as this issue insisted.

## Acceptance — measured, on `:99` with openbox 3.6.1 live

Row 1 (the probe line reads `gate_after_ok=1`), byte for byte before → after:

```
BEFORE  PROBE0692 seed=0 remedy_rc=1 gate_after_remedy=1 box_still=0 ok_rc=1 gate_after_ok=0
AFTER   PROBE0692 seed=0 remedy_rc=1 gate_after_remedy=1 box_still=0 ok_rc=1 gate_after_ok=1
```

The measured **second symptom** (the ESC arm printing a phantom "was NOT applied"
about a gate that *was* applied, and re-arming the nudge) went with it:

```
BEFORE  PROBE0692C ... phantom_discard_notices=1 gate_after_esc=1
AFTER   PROBE0692C ... phantom_discard_notices=0 gate_after_esc=1
```

Row 2 (non-vacuity — OK is not inert): W1y drives a hand tick → OK → gate on, and
a hand untick → OK → gate off. Green.
Row 3 (0648's model green): `test_ase_dialogs` GE10, GE10b–GE10h, G5b, G5c all
green in a 172-check ALL PASS run. The scope fence held; **issue 0648 was not
widened into**, per the brief's STOP instruction.

## Decisions

* **Option 2 taken** (L2 — smallest blast radius among the honest fixes, and the
  least surprising: a box the user touched wins, one they did not takes the live
  value). **REJECTED option 1** (re-seed inside `save_all_commit`): a widget side
  effect inside the shared writer the pasted remedy calls; it would silently move
  a box the user had just ticked by hand (this issue's own ⚠); and it changes
  what 0679's SAB-N6 proves. **REJECTED option 3** (refuse/report on OK): loudest,
  and it turns a working gesture into an error.
* **The cancel arm was fixed here, not filed** (L1/I1). One definition of "the
  user changed this box", two consumers; two independent readings are how the
  live diff drifted into a phantom notice. Retargeting the diff from LIVE to SEED
  is not a rework of 0648's model — it implements the sentence 0648 already wrote
  ("a change THE USER MADE and lost is stated"), which HEAD approximated as
  "differs from live" only while nothing could change live behind an open dialog.
* **A missing seed falls back to HEAD's live diff** (L2), so the change is
  strictly additive for the suites that poke `dlg` records with no dialog, and
  SAB-0692-B is an exact "revert 0692" discriminator. **REJECTED** "no seed ⇒
  nothing touched": it would silently make a poked record inert.
* **On a conflict the user's hand wins, silently** (L3 — user-visible,
  unratified). Recorded as **rule debt [0692]**, not answered here.

## Sabotage matrix

| variant | predicted red | observed |
|---|---|---|
| SAB-0692-A — `save_all_touched` → `{}` | 8 rows (W1y, W1z, W1za, G5c, GE10c, GE10d, GE10f, GE10g) | **14** — all 8 plus W1za2 and 5 more G5/G5c rows |
| SAB-0692-B — `save_all_seed` → no-op (the exact "revert 0692" control) | W1x, W1za | **3** — plus W1z. Reproduces pristine HEAD's red set exactly; `test_ase_dialogs` stayed ALL PASS 172, so 0648's rows are genuinely independent of the seed |
| SAB-0692-C — `save_all_resolve` → HEAD's raw-`dlg` expression | W1x, W1z | W1x, W1z exactly ✔ — **W1za stayed GREEN**, proving the OK arm and the ESC arm are independently covered |
| SAB-N6 (0679's, restated) — `save_all_commit` writes nothing, reports 1 | F19v, F19w, W1v, W1w | **12** — all 4 plus F19p/F19q/F19r/F19u and W1x/W1y/W1z/W1za |

No predicted red failed to appear. ⚠ **SAB-N6 REFUTES a sentence the plan wrote**
("no new coupling to the 0692 rows"): the 0692 rows *do* redden under it. That is
mechanically expected — every Save All write funnels through `save_all_commit` —
but it means SAB-N6 is no longer a *discriminator* for the 0679 seam alone, and a
future crew reading it as one will misread a red set.

## STILL OPEN — the residuals this fix ships with

1. **0695, raised to BLOCKING (was filed as cosmetic).** An untouched box takes
   the LIVE value, but the checkbutton does not follow the live value, so an open
   dialog can DISPLAY a ticked box while OK writes it **off**. Measured through
   two shipped menu items (`Save All` open, then `Session > Load State`, then OK):
   `WU-B2 box_at_open=1 load_rc=1 live_after_load=0 box_still=1 ok_rc=1
   gate_after_ok=0`. HEAD wrote **on** here, matching the box. Because
   `ase::op_cards_capture` gates the whole OP-card block on `save_op_params`, the
   next deck is emitted with no OP save cards while the dialog says they are on.
   **This makes 0695 part of the 0692 ruling, not a follow-up.**
2. **0696 — a NEW false discard notice this fix created.** `save_all_touched`
   answers "differs from the seed", which is not "the user's change was lost".
   Hand-tick + an external write to the *same* value + ESC now prints
   "'Save device OP parameters' was NOT applied" while `gate_after_esc=1`.
   Measured: `WU-B1 seedbox=0 remedy_rc=1 gate=1 pending={opparams} notices=1`.
   HEAD was silent on this gesture. Milder than what it replaced (nothing is
   lost; the user is told to redo work already done), but it must **not** be
   recorded as "the ESC arm is now honest".
3. **A net-zero hand gesture loses to the live value.** Tick-then-untick returns
   the record to the seed, so the field is not "touched" and the live value wins
   over the box the user is looking at (`seedbox=0 box_at_ok=0 live_before_ok=1
   gate_after_ok=1`). The rule debt [0692] as worded names only hand-untick vs
   external tick; **this variant belongs in the same ruling**.
4. **The fix is fail-open to the bug.** `save_all_touched` deliberately falls
   back to the live diff when `dlg($key,seed)` is absent, so any future path that
   shows this dialog without going through `save_all_dialog` silently reinstates
   0692 **with zero rows red**. W1x/W1za are the only structural guard.
5. Rule debt **[0679]** (return 0 + echo vs RAISE; whether OK should still close
   the dialog on a failed apply) is **restated, not answered** — the ESC-arm work
   bears on its second half.
