# File diff snapshot — action registry (Phase 3a: data-driven mouse wheel)

Build/source file changes introduced by **Phase 3a** of the action-registry work
on branch `feature/action-registry` (commit `9fd11c1f`). This is the first slice
that *touches the C engine* — the deliberate pivot away from the Phase 1/2
"Tcl-only" approach. Line counts are whole-file (`wc -l`): `old --> new` for
modified files; documentation-only artifacts (`doc/claude/suggestions/`, `doc/claude/code_analysis/`)
are excluded from the footprint.

> **The one idea behind this slice.** The old `handle_mouse_wheel` fused two jobs:
> *which* input does *what* (binding) and *what the action actually does*
> (behavior). Phase 3a splits them. Behavior stays in C (it touches `xctx`);
> binding becomes a small in-memory table you can rewrite at runtime with
> `xschem bind`. Nothing about the default wheel behavior changes — the built-in
> table is seeded to reproduce the old `if/else` ladder exactly — but the wheel is
> now remappable with no GUI and no recompile.

## Built / installed product files

| File | What changed / why it's needed |
|---|---|
| `src/callback.c` **(4856 --> 5147, +291; 334 ins / 43 del)** | The heart of the slice. The 43 deleted lines are the old hard-coded `handle_mouse_wheel` `if/else` ladder. The 334 new lines add, as one marked section: **(1)** six *action functions* (`act_zoom_in/out`, `act_pan_{left,right,up,down}`) — the behavior, ids matching `actions.csv`; **(2)** an `ActionDef` *registry* mapping a stable id → C function; **(3)** a mutable `InputBinding` *table* mapping a signature `{device, code, mods, ctx}` → id, with `set_/unset_input_binding` and built-in defaults (`init_input_bindings`) that reproduce the previous behavior exactly; **(4)** `dispatch_input_action()`, the lookup that turns an event signature into an action call; **(5)** the string⇄int parsers and the `action_cmd_bind/unbind/bindings` backends for the new Tcl subcommands. `handle_mouse_wheel` is rewritten to compute a signature and dispatch through the table — while keeping the `waves_selected` graph-routing **verbatim** (only no-modifier and Shift wheel route to a waveform graph under the pointer; Ctrl-wheel never did). |
| `src/scheduler.c` **(7034 --> 7057, +23; 24 ins / 1 del)** | Wires three new `xschem` subcommands into the central dispatcher. `bind` and `bindings dump` go in `case 'b'`; `unbind` goes in `case 'u'`. **Why split across cases:** the dispatcher is a `switch(argv[1][0])` on the subcommand's *first letter*, then an else-if chain — a subcommand placed in the wrong case silently falls through to "invalid command". (This bit us once mid-development; it's the reason `unbind` isn't next to `bind`.) Each branch just forwards `argc/argv` to the matching `action_cmd_*` backend in `callback.c`. |
| `src/xschem.h` **(1794 --> 1800, +6)** | Declares the three `extern` backends (`action_cmd_bind/unbind/bindings`) so `scheduler.c` can call into `callback.c`. The binding-table types and enums stay private to `callback.c` — `scheduler.c` only passes strings through, so the header surface is intentionally tiny. |

## Test files (ship with the feature; run headless under X, not compiled/installed)

| File | What it is / why it's needed |
|---|---|
| `tests/headless/test_mouse_bindings.tcl` **(new, 104 lines)** | Proves the wheel is genuinely data-driven, end to end through the real C path (it drives events with `xschem callback .drw 4 …`, i.e. a synthetic `ButtonPress`). Four things, 15 assertions: **(1) transparency** — with the built-in defaults, wheel-up zooms in (`zoom /= 1.2`), wheel-down zooms out, Ctrl+wheel-up pans `yorigin` by exactly `-CADMOVESTEP*zoom/2`, Shift+wheel-up pans `xorigin` the same way (i.e. identical to the old code); **(2) introspection** — `xschem bindings dump` lists the six defaults; **(3) remap** — after `xschem bind wheel up 0 canvas view.pan_up`, wheel-up now pans and no longer zooms, and an unknown action id is rejected; **(4) unbind** — `xschem unbind` removes the row and the wheel goes inert; then the default is restored. |

## How a wheel turn now reaches an action (the data flow)

```
X ButtonPress (button 4/5, modifiers)
   -> callback()            [callback.c]   X event type dispatch
   -> handle_button_press() [callback.c]
   -> handle_mouse_wheel()  [callback.c]   build signature {device,code,mods,ctx};
                                           graph-routing stays here (waves_selected)
   -> dispatch_input_action(&ae)          look up signature in input_bindings[]
   -> lookup_action_fn(id)                resolve id -> C function via action_registry[]
   -> act_zoom_in() / act_pan_up() ...    BEHAVIOR runs against xctx
```

`xschem bind/unbind` mutate `input_bindings[]`; `xschem bindings dump` prints it.
Defaults are installed lazily on first use, so the table always works even before
any `bind`. To remap permanently with no GUI, a user adds e.g.
`xschem bind wheel up 0 canvas view.pan_up` to their `.xschemrc`.

## Out of scope (on the branch, but not part of Phase 3a)

| File | Why excluded |
|---|---|
| `src/actions.csv`, `src/action_registry.tcl`, Phase-1/2 tests | The Tcl-layer menu/palette/keyboard work (Phases 1 & 2). Phase 3a reuses the *action-id namespace* from `actions.csv` but adds no rows. |
| `doc/claude/suggestions/refactor_plan_action_registry_phase3.md` **(+15)** | Documentation: the plan doc's "Phase 3a DONE" status update. |

---

**Phase 3a footprint (built/installed + tests):** 3 modified product files
(**net +320 lines**; +291 callback.c, +23 scheduler.c, +6 xschem.h), 1 new test
file (104 lines). **C engine: this is the first slice that changes it** —
contrast Phases 1+2, which were 0 lines of C. The change is additive and
behavior-preserving by construction (defaults reproduce the old ladder; verified
15/15 + engine harness 6/6 + the Phase-2 GUI smokes still green).
