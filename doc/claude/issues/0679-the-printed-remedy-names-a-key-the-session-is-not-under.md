# 0679 — the printed remedy names a key no session is under, and `save_all_apply` reports success anyway

Status: OPEN. **Reproduced by the user on their bench, then reproduced exactly by the
driver.** Filed 2026-08-24. Related: 0653 (R-0653-d requirement 3, which this
violates), 0648, 0652, 0664, 0677.

## The user's report, verbatim

> I did a run without "Save device OP parameters" checked, and, when I tried to
> display OP info with 6, I get the required message in the CIW. However, when I
> entered the suggested command into the CIW (and get a 1 as result), if I go into
> the Menu : ASE-L > Outputs > Save All, I don't see that box checked after doing
>
>     ase::ui::save_op_params_on sky130_tests_ase/tb_bandgap/schematic

The notice worked. The remedy did not. **This is the exact failure R-0653-d
requirement 3 was written to prevent** — "advice that half-works: the user follows
correct-looking instructions and still sees blanks".

## Measured by the driver, headless on `:99`

```
REGISTERED: sky130_tests_ase/tb_bandgap/ngspice_state1
REMEDYKEY : sky130_tests_ase/tb_bandgap/schematic
update_rc : 0        <- ase::session_update: "unknown key"
apply_rc  : 1        <- ase::ui::save_all_apply: "success"
gate_real : 0        <- the gate never moved
```

## TWO defects, and the second is the dangerous one

### (a) the key comes from the wrong namespace

A session is registered under `ase::session_key $lib $cell $view` where `$view` is
the **state view the user opened** — `ngspice_state1` (`src/ase.tcl:2773`, in
`open_state`).

The remedy key is built by `ase::op_cards_nudge_key` (`src/ase.tcl:608-616`), which
reads `state -> design -> {lib cell view}` — the **design the state points at**,
whose view is `schematic`. `src/ase.tcl:715-717` then prints that as the command.

So the notice confidently prints a key that no session is ever registered under. It
is not a typo or a stale string: the two keys are built from **different fields of
the same state**, and they will never agree for any ASE session, on any cell.

### (b) `save_all_apply` fabricates its own success

`src/ase_window.tcl:2915-2923`:

```tcl
proc ase::ui::save_all_apply {key allv alli opparams} {
  set st [ase::session_state $key]      ;# returns {} for an unknown key, no error
  dict set st save_all_v ...
  ase::session_update $key $st          ;# returns 0 for an unknown key -- DISCARDED
  ase::ui::populate $key                ;# no-op with no window
  return 1                              ;# <-- always
}
```

`ase::session_update` is **honest**: `src/ase.tcl:2644-2646` documents "Returns 1, or
0 for an unknown key" and does exactly that. `save_all_apply` throws that answer away
and returns a hardcoded `1`.

That `1` is what the user saw, and it is why they trusted the command had worked.
**This is issue 0652's defect class — a report that lies — in a third place**, after
0664 (a DEGRADED claim on a live channel) and 0677. A witness that cannot fail is not
a witness.

⚠ Fixing (a) alone would hide (b) rather than fix it: the key would match, the return
would be right by luck, and the fabricated `1` would sit there waiting for the next
caller to pass a bad key.

## Fix

1. **`save_all_apply` returns what `session_update` returned.** Every caller must be
   audited for what it does with a 0 — the dialog's OK path in particular must not
   silently swallow a failed apply.
2. **The remedy prints the key the session is actually under.** It has that key in
   hand: the notice is emitted from a path that already knows the session. Do not
   "fix" this by making `op_cards_nudge_key` return the state view — that proc is
   also the LATCH key (`op_cards_nudge_rearm`, `src/ase.tcl:622`), and changing it
   silently re-scopes the 0648 latch, which is the defect 0648 was filed for.
   **Two consumers, two meanings: give the remedy its own builder or pass the
   registered key down.**
3. A test that **executes the printed command and then asserts the gate is on by
   `ase::op_gate_on`** — R-0653-d requirement 1, which was specified for exactly this
   and evidently did not cover the key.

## Why the existing test passed

The 0658 crew's remedy test executed the command against a key **it had constructed
itself** rather than one taken from a live session, so both sides of the comparison
carried the same wrong view and the round trip closed. Record this as the coverage
hole: a remedy test must take its key from the SESSION REGISTRY, never build one.
