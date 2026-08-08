# 0236 — `auto_set_wire_bus()` runs from `draw()`, so a pure pan/zoom modifies the document with no undo

Status: **OPEN** — measured repro, fix drafted, not implemented. Opt-in preference, so blast radius is small.
Area: `src/draw.c:9695` (inside `draw()`, `:9539`); `src/netlist.c` `auto_set_wire_bus()` (`:1701-1727`)
Tests: none yet — proposed `tests/headless/test_auto_set_wire_bus_0236.tcl`; `xschem test 7` (`src/scheduler.c:12317`) drives the same function headlessly
Found: 2026-08-05, while grounding `doc/claude/code_analysis/net_label_model_instance_vs_wire_attached.md`
Related: **0235** — the other document-mutating path in this area, which is unconditional and needs no preference. No prior doc mentions `auto_set_wire_bus` anywhere under `doc/claude/`.

## The defect

The redraw path mutates the document and marks it modified, without pushing an undo slot.

```c
src/draw.c:9695
        if(tclgetboolvar("auto_set_wire_bus")) auto_set_wire_bus(i, i + 1);
```

That sits inside the WIRELAYER loop of `draw()` (`src/draw.c:9539`), so the Tcl boolean is
re-read **once per visible wire per repaint**, and the function runs per wire.

```c
src/netlist.c:1701-1727
void auto_set_wire_bus(int start, int end)
{
  …
  if(xctx->netlist_count) return; /* do this only in top level */
  …
  prepare_netlist_structs(0); /* update all wires .node fields */
  cc = WIRELAYER; if(xctx->only_probes) cc = GRIDLAYER;
  regcomp(&re, "(.+\\[.+(:|\\.\\.)[^.]+\\])|(,)", REG_NOSUB | REG_EXTENDED);
  …
    if( (oldbus == 0.0 && bus == 1) || (oldbus == -1.0 && bus == 0) ) {
      set_modify(1);
      my_strdup(_ALLOC_ID_, &xctx->wire[i].prop_ptr,
         subst_token(xctx->wire[i].prop_ptr, "bus", bus ? "1" : NULL));
      xctx->wire[i].bus = bus ? -1.0 : 0.0;
```

## Two corrections to keep this accurate

1. **The preference defaults OFF** — `set_ne auto_set_wire_bus 0` (`src/xschem.tcl:15734`),
   and the `xschemrc` example is commented out (`src/xschemrc:259-260`). This is opt-in.
2. **`set_modify(1)` is not unconditional per repaint** — it fires only when a wire's
   bus-ness actually *flips*. The mutation converges after the first repaint that
   reconciles the file's `bus=` tokens with the auto-detected bus names.

Also measured while reading: the inner `prepare_netlist_structs(0)` is cached by
`xctx->prep_hi_structs`, so it is one full extraction per repaint, not per wire, and the
`regcomp`/`regfree` pair is balanced (no leak).

It is still a real defect. A pure pan or zoom:

- marks the document modified,
- fires `write_backup()` (autosave — see the `set_modify` doc comment at
  `src/actions.c:196-206`),
- adds a `*` to the title,
- and does so with **no `push_undo()`**, so Ctrl-Z cannot revert it.

## Measured

1. `set auto_set_wire_bus 1` in `xschemrc` (default is 0).
2. Open a schematic whose bus-named wires lack `bus=1` — verified with
   `xschem_library/examples/greycnt.sch` with all `bus=` tokens stripped.
3. Pan or zoom once — a pure repaint.

```
MOD_AFTER_LOAD:    0
MOD_AFTER_AUTOBUS: 1
```

The title gains `*`, a `greycnt~.sch` autosave backup is written, Ctrl-Z cannot revert,
and saving writes 4 new `bus=1` tokens. Expected: a repaint does not modify the document.

(Driven headlessly via `xschem test 7`, `src/scheduler.c:12317`, which calls the same
`auto_set_wire_bus(0, xctx->wires)`; the `draw.c:9695` call site is the same function with
a one-wire range.)

## Fix

Move the call out of the draw path to the points that actually change wire names —
post-load, post-edit, and the explicit `xschem test 7` — and wrap it in `push_undo()` so
the change is undoable.

Adding `push_undo()` *inside* `draw()` would be worse than the disease (undo-slot churn
per repaint), which is why the call must move out first.

Strictly minimal alternative, if the draw-time call is to stay: hoist the
`tclgetboolvar("auto_set_wire_bus")` out of the per-wire loop. That fixes the Tcl-lookup
cost but not the mutation.

## Risks

- A schematic whose `bus=` tokens are stale no longer self-heals on repaint. Users who
  deliberately enabled the preference to get that behaviour must trigger it explicitly.
  Since the preference defaults 0, the blast radius is small.
- Whatever call sites replace the draw-time one must cover the case the preference exists
  for: a wire renamed into or out of bus syntax by an edit elsewhere in the sheet.
- `prepare_netlist_structs()` is shared with highlight, netlist, ERC, SVG export and
  flyline drawing; moving *this* caller does not change that, but any new call site
  inherits its cost.
