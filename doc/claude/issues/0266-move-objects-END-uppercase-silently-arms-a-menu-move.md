# 0266 — `xschem move_objects END` silently arms a deferred MENU move instead of committing (the sub-verbs are lowercase-only)

Status: **OPEN** — measured while building issue **0244**'s fixture. **Minor but expensive**: it
costs no data, it costs *tests*. A scripted commit that never commits leaves the gesture pending and
the following assertion measures the wrong state, silently.
Area: `src/scheduler.c` — the `move_objects` verb's sub-verb dispatch (`start` / `step` / `end` /
`abort`) and its final `else`
Tests: pinned indirectly by `tests/headless/test_paste_modify_flag_0244.tcl` section A4, which
documents the trap in a comment and uses the correct form.
Found: 2026-08-08, while implementing **0244**.
Related: **0244** (whose session plan named the broken form as its commit constructor), **0069**
(the action-log replay forms that share this verb).

## What happens

The verb dispatches on `argv[2]` with `strcmp` against the lowercase literals `"start"`, `"step"`,
`"end"`, `"abort"`. Anything else falls through to the one-shot release form
`move_objects <dx> <dy> [...]` — and when there are no further arguments *that* form's `else` arms a
**deferred menu move**:

```c
xctx->ui_state |= MENUSTART;
xctx->ui_state2 = MENUSTARTMOVE;
```

which is the "menu item clicked, waiting for the canvas click" state. So `xschem move_objects END`
does not commit anything, does not error, and returns `TCL_OK`.

Measured on a pending paste:

```
xschem merge <f>            ui_state 296     STARTMERGE|STARTMOVE|SELECTION
xschem move_objects END     ui_state 65832   MENUSTART|STARTMERGE|STARTMOVE|SELECTION
                                             <-- nothing committed, paste still pending
xschem abort_operation      -> the paste is deleted, i.e. the "commit" never happened
```

The correct forms, all measured to leave `ui_state 8` (`SELECTION`) with the paste dropped:
`xschem move_objects end 0 0`, `xschem move_objects end <dx> <dy>`, `xschem move_objects <dx> <dy>`,
and `xschem paste <dx> <dy>`.

## Why it is worth fixing rather than documenting

It is silent in the direction that produces false green. A test that "commits" with the uppercase
form and then asserts something about the committed state is asserting about a *pending* gesture,
and the assertion can pass for the wrong reason — issue 0244's own control row D
("dirty + merge + commit → modified 1") was right about the number and wrong about the state, for
exactly this reason. `MENUSTART` is also left set on `ui_state`, so the next canvas click in a GUI
session would start a move nobody asked for.

## Sketch

Either accept the sub-verbs case-insensitively (`strcasecmp` is not C89-portable in this tree — use
a small local lower-casing compare), or make an unrecognised **non-numeric** `argv[2]` a
`TCL_ERROR` (`"xschem move_objects: unknown sub-verb"`). The second is preferable: it converts a
silent no-op into a loud failure, and the one-shot form's arguments are always numeric, so the test
is unambiguous. Check the action-log replay lines (issue 0069) for the exact spellings they emit
before tightening.
