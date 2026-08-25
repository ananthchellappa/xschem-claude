# 0692 — a stale open `Save All` dialog silently reverts the remedy, and OK's `1` is truthful

Status: OPEN, FILED NOT FIXED. Filed 2026-08-25 by the 0679 crew's adversary and
write-up passes. Related: **0679** (the fix that makes this window meaningful),
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
