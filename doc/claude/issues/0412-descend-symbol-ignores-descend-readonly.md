# 0412 — `descend_symbol()` ignores `descend_readonly`, so browse mode opens the `.sym` editable

Status: **OPEN** — measured headless, **not fixed**. Pre-existing C behaviour, not introduced by
any 2026-08-15 work. Filed by crew item **D11** while shipping the Ctrl-Y bind
([0410](0410-descend-into-symbol-has-no-key-in-cadence-mode.md)); fixing it is a C change that
alters four existing user-visible paths, which is outside "ship a bind".
Area: `src/actions.c:4097` (`descend_schematic()`), `src/save.c` `descend_symbol()`;
`descend_readonly` is set to 1 by `src/cadence_style_rc`.
Tests: none. `tests/headless/test_descend_readonly.tcl` covers the schematic path only.
Related: [0410](0410-descend-into-symbol-has-no-key-in-cadence-mode.md),
[0253](0253-descend-symbol-has-two-gates-with-two-thresholds.md).
Spec: `doc/claude/specs/descend_readonly.md` (which does not mention `descend_symbol` at all).

## The defect

`descend_readonly` is cadence browse mode: descend to look, not to edit. It is applied in
exactly one place —

```c
src/actions.c:4097
   if(descend_ok && tclgetboolvar("descend_readonly")) xctx->readonly = 1;
```

— which is inside `descend_schematic()`. `descend_symbol()` never consults it. Measured on the
`hi_descend` fixture with `descend_readonly 1`, same instance, same session:

```
AFTER descend        : currsch=1 ro=1 name=leaf.sch
AFTER descend_symbol : currsch=1 ro=0 name=leaf.sym
```

So in browse mode a schematic descend opens read-only while a symbol descend opens the `.sym`
**editable** — the one view a browsing user is least likely to want to modify by accident, and
the one whose accidental modification propagates to every instance of the cell.

## Blast radius of a fix

The asymmetry is reached today by four existing paths — the Edit menu, the toolbar button, the
canvas right-click "Descend symbol" (`src/callback.c:5120` retval 13) and the `e` chooser's
symbol row — plus, as of 0410, the cadence Ctrl-Y chord. **Ctrl-Y introduces no new
inconsistency**; it gives a keyboard route to behaviour those four paths already have. That is
why D11 shipped the bind and filed this instead of fixing it: making `descend_symbol()` honour
the flag changes all five at once, which is a user-visible behaviour change needing its own item.

**Explicitly rejected at D11:** a cadence-side wrapper that forces `readonly` after a Ctrl-Y
descend. That would make the KEY disagree with the MENU for the same verb — two truths for one
verb — which is strictly worse than the current honest asymmetry.

## When this is picked up

The question to answer first is whether browse mode *means* "symbols too". If yes, the fix is to
apply the flag in `descend_symbol()` as well (and to say so in
`doc/claude/specs/descend_readonly.md`, which is silent on symbols today), with a regression row
in `tests/headless/test_descend_readonly.tcl` asserting `readonly == 1` after a symbol descend
under the flag, and the flag's absence still leaving the `.sym` editable.
