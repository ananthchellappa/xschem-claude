# 0390 — a plain descend clears the click-mode bit but leaves the mode's prompt up in the child

Status: **OPEN** (measured, not fixed; pre-existing, exposed by the 0257 work)
Found: 2026-08-10, crew item D6 adversary pass (`ATK-19`).
Area: `src/callback.c` `abort_click_mode()` — the new primitive that blanks `.statusbar.10` — is
called **only** from `xschem descend_pick` (`src/scheduler.c`). `descend_schematic()`
(`src/actions.c`) and `descend_symbol()` (`src/save.c`) clear the mode *bits* as part of the
descend but never blank the field.
Tests: none. `tests/headless/test_cmdmode_descend_0201.tcl` MS3/MS7/MS8 assert the prompt only on
the *pick* path.
Related: **0257** (where the primitive came from), **0243 F2** (gates at the verbs — this is the
sibling verb that did not get one), **0248** (status-line hold semantics).

## The defect

Enter net-highlight or deselect mode, then descend with the ordinary verb (no pick). Measured on
`leaf.sch` after descending:

```
.statusbar.10 = "HIGHLIGHT NET! (click a net or label, ESC to end)"
.statusbar.10 = "DESELECT! (click a selected object to deselect it, ESC to end)"
```

The mode is over — its bit is gone with the parent's `ui_state` — but the child advertises it. The
next Button-1 in the child does the ordinary thing while the status bar promises otherwise.

## Fix sketch

Call `abort_click_mode()` from the descend verbs as well (it already honours `gate_bypass`, touches
no selection, and returns the name it ended, so the descend can name it in its own status line the
way `descend_pick` does). The reason it was not done in D6: the item's decision D3 limited the new
primitive to the door that had been measured to *swallow a press*; this one is a stale-prompt
defect, not a swallow, and the verbs' own status lines are asserted by several suites.
