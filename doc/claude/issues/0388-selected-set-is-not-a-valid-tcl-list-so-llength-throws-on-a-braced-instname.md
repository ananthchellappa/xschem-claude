# 0388 — `xschem selected_set` is not a valid Tcl list, so every `llength` on it throws on a braced instname

Status: **OPEN** (measured, not fixed — one *consumer* was moved off it; the producer is unchanged)
Found: 2026-08-10, crew item D6 adversary pass (`ATK-4a`), then re-measured by the write-up agent.
Area: `src/scheduler.c` `selected_set` (`~:11258`) — `Tcl_AppendResult(interp, "{",
xctx->inst[i].instname, "}", NULL)`, i.e. hand-braced with no quoting; the same shape in
`selected_wire` (`~:11318`, wraps a `lab` value). Consumers: `src/xschem.tcl:5852`
(`hi_descend_target_inst`, `llength $sel` — a live latent throw), `:3870`, `:5743`,
`utils/*.tcl`, tests and PDK glue.
Tests: `tests/headless/test_cadence_descend_newwin_ro.tcl` `GATE-brace` / `GATE-brace-descend` pin
the one consumer that was fixed. Nothing covers the producer or the other consumers.
Related: **0259** (the fix that tripped over this), **0260** (the same list's *empty element*
hole), **0392** (the other silent-answer hazard met in the same repair).

## The defect

`selected_set` builds its list by concatenating `{`, the raw instname, and `}`. An instname is user
text (`name=` on the instance), so any unbalanced brace or trailing backslash in it produces a
string Tcl cannot parse as a list. Measured headless on a copy of the `hi_descend` fixture:

```
name=xb{roken    -> xschem selected_set = {xb{roken}
                    llength [xschem selected_set]  ->  ERROR: unmatched open brace in list
name=x y         -> xschem selected_set = {x}          <-- silently TRUNCATED at the space
name=xz\         -> xschem selected_set = {}           <-- silently EMPTIED
name= (nameless) -> xschem selected_set = {}           <-- indistinguishable from the line above
```

The A/B that found it: issue 0259's first live-read gate used `llength [xschem selected_set]`, and
on the braced name a previously **working** Ctrl-X became a propagated Tcl error
(`cadence::descend_into_inst rc=1 res={unmatched open brace in list}`), while `xschem descend` on
the same instance still worked because the C path is index-keyed. That regression was repaired by
moving the gate to `xschem selection` (type words + indices, unpoisonable) — but every other
consumer still reads `selected_set`, including `hi_descend_target_inst`, whose `llength $sel` at
`src/xschem.tcl:5852` throws on exactly the same input.

## Why it was not fixed here

Making the producer emit a real list means `Tcl_Merge`/`Tcl_AppendElement` instead of manual braces,
which changes the exact bytes for names containing spaces or braces. `selected_set`'s output is
compared string-for-string by tests and by PDK glue (and 0259/0260 both had to reason about its
`llength`), so it is a contract change and needs its own pass with the consumer inventory in hand.

## Fix sketch

* Producer: build the result with `Tcl_AppendElement()` (or `Tcl_Merge` over a `Tcl_Obj` list) so
  quoting is the interpreter's job. Same for `selected_wire`.
* Consumers that only need "how many instances / is it one instance": use `xschem selection`
  (`{type index col id}` rows, no user text) — that is what `cadence::one_instance_selected` now
  does.
* `hi_descend_target_inst` should stop being name-keyed altogether (see 0385).
