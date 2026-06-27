# One key's journey: `case 'f'` — what left the monster switch, and why the case is still there

A close reading of a single `case` in `handle_key_press` (callback.c) as a microcosm
of the whole action-registry refactor. `f` is the perfect specimen: **three chords,
three different fates** — one fully migrated to data, one half-migrated, one that can
never go with the current data model. If you understand this one case, you understand
the entire Phase-3 design, including where it deliberately stops.

Companion docs: `lessons_learnt_action_registry.md` (the themed rules cited below),
`refactor_plan_action_registry_phase3.md` (the plan this executed),
`handle_key_press_engineering_critique.md` (why the switch was a problem at all).

---

## 1. The before (commit `922001f5^`, verbatim)

```c
case 'f':
  if(rstate == 0) { /* full zoom */
    int flags = 1;
    if(waves_selected(event, key, state, button)) {
      waves_callback(event, mx, my, key, button, aux, state);
      break;
    }
    if(tclgetboolvar("zoom_full_center")) flags |= 2;
    zoom_full(1, 0, flags, 0.97);
  }
  else if(rstate == ControlMask) { /* search */
    if(xctx->semaphore >= 2) break;
    if(waves_selected(event, key, state, button)) {
      waves_callback(event, mx, my, key, button, aux, state);
      break;
    }
    tcleval("property_search");
  }
  else if(EQUAL_MODMASK) { /* flip objects around their anchor points 20171208 */
    if(xctx->ui_state & STARTMOVE) move_objects(FLIP|ROTATELOCAL,0,0,0);
    else if(xctx->ui_state & STARTCOPY) copy_objects(FLIP|ROTATELOCAL);
    else {
      rebuild_selected_array();
      xctx->mx_double_save=xctx->mousex_snap;
      xctx->my_double_save=xctx->mousey_snap;
      move_objects(START,0,0,0);
      move_objects(FLIP,...);   /* START / FLIP|ROTATELOCAL / END sequence */
    }
  }
  break;
```

Everything wrong with the switch is in this one case: **binding fused with behavior**
(the chord test and the zoom code interleaved), **context routing as inline control
flow** (two copy-pasted `waves_selected` guards — "is the pointer over a waveform
graph? then the graph gets the key"), **reentrancy protection as a per-branch idiom**
(`if(semaphore>=2) break;`), and **a modal gesture hiding in an else-if** (the flip).
None of it remappable without recompiling.

## 2. Chord 1 — plain `f`: fully migrated (Phase 3c, commit `922001f5`)

Plain `f` was chosen as the *first key ever migrated* because it is the easy case in
every dimension: an **exact** chord (`rstate == 0`, not a mask test), **no semaphore
guard**, behavior that reads **no mouse position and no edit state** — and yet it has
the one interesting feature, graph-vs-canvas routing, that Phase 2's Tcl interception
structurally could not handle.

The move, mechanically:

1. **Name the behavior.** The branch body became `act_zoom_full()`, replicated
   *verbatim* — including the `zoom_full_center` flag logic, read back from the tcl
   variable because a migrated action gets no `handle_key_press` locals (lesson 7).
   It registered under the id `view.zoom_full`, the same id actions.csv already used
   for the View-menu entry.
2. **Turn the routing into rows.** The inline `waves_selected` guard became data:

   ```
   key f 0 canvas      -> view.zoom_full
   key f 0 over_graph  -> graph.forward
   ```

   "Graph gets first refusal" is now a *lookup precedence* (`over_graph` beats
   `canvas`), not an if-statement.
3. **Gate the dispatch.** A `DEV_KEY` lookup was added at the top of
   `handle_key_press` — but guarded by `key_chord_has_binding(code, mods)`, because
   `waves_selected()` is **not pure** (it mutates graph state and the cursor).
   Only a migrated chord may consult it; every un-migrated key is byte-for-byte
   unchanged. This gate is the load-bearing idea of the whole refactor (lesson 2).
4. **Delete the branch.** The `rstate == 0` block left the switch. From that commit
   on, `f` is remappable at runtime (`xschem bind key 102 0 canvas <anything>`) and,
   since d4b, by editing `keybindings.csv`.

Proof was empirical, in both contexts: `f` on bare canvas changes `xschem get zoom`;
`f` with the pointer inside a graph rectangle leaves the canvas zoom untouched
(`test_key_graph_context.tcl`).

## 3. Chord 2 — `Ctrl+f`: HALF migrated, and the half matters (Phase 3d.1b, commit `c806149d`)

`Ctrl+f` looks almost as clean — exact chord, single `tcleval`. But its waves guard
sits **after** `if(xctx->semaphore >= 2) break;`. That ordering is semantics: while
the editor is busy (reentrant callback), the old code did nothing *and never called
`waves_selected`* (no side effects). The top-of-function dispatch runs *before* any
per-branch code, so migrating this chord naively would forward keys to the graph —
and fire `waves_selected`'s side effects — exactly when the old code was inert.

This blocked six chords for a while ("the sem-first chords"). The fix was d1b's
`idle_only` flag on the **binding row** (not the action), checked in the dispatch
gate **before** the context computation:

```
key f ctrl over_graph -> graph.forward   [idle]
```

At `semaphore>=2` the gate skips the row entirely → falls through to the switch →
the surviving `if(semaphore>=2) break;` → the old no-op, side effects and all. The
lesson generalizes: *a guard whose meaning comes from its position relative to a side
effect must migrate to the same position — reproducing the boolean isn't enough*
(lesson 2, third bullet).

So today `Ctrl+f`'s **routing** is data, but its **canvas behavior** (`tcleval
("property_search")`) is still the switch branch you see. Why? Not because the model
can't express it — an `idle_only` canvas row pointing at a Tcl-backed action would
work, and the csv even has the id (`tools.search` → `property_search`). It's parked
on **cost/benefit**: the command opens a modal dialog, which the testing discipline
can't verify headless (you don't key-press a dialog open in a `--pipe` test, lesson
10), and the case can't be whole-deleted anyway because of chord 3 — so the payoff
would be swapping one tested C line for one hard-to-test row. *Expressible but not
worth it* is a different category from *inexpressible*, and keeping that distinction
honest is what kept the migration batches small and safe.

## 4. Chord 3 — `Alt+f`: the anchor that keeps the case alive

The flip branch is the genuinely unmigratable one, and not for one reason but three:

- **It reads in-progress edit state.** `ui_state & STARTMOVE` / `STARTCOPY` — the
  same physical key does different things depending on whether a move or copy
  gesture is mid-flight. The binding tuple is `{device, code, mods, ctx}`; there is
  no `ui_state` axis, *by design*. This key isn't bound to a gesture — it **is part
  of the gesture machinery** (it mutates the object being dragged).
- **It reads the mouse position.** `mousex_snap`/`mousey_snap` → `mx_double_save`:
  the flip anchor is wherever the pointer is. Migrated actions deliberately get no
  such locals.
- **It is itself a modal sequence.** The else-arm runs `move_objects(START)` →
  `FLIP|ROTATELOCAL` → `END` — a synthetic mini-gesture against `xctx`.

Could the model grow to cover it? Sure: add a `ui_state` axis, pass coordinates,
allow action sequences. Each is a step toward re-implementing the switch as a worse
DSL in data — the plan's standing rule is to *resist* exactly that (refactor plan,
"Decisions & risks"). The sanctioned escape valve — "bind the initiating chord, let
`ui_state` carry the rest", which worked for right-drag zoom-rect — doesn't apply
here because `Alt+f` isn't an initiating chord; it's a participant in someone else's
gesture.

(Footnote: `EQUAL_MODMASK` itself is *not* the blocker — it means "exactly Mod1 or
exactly Mod4" and costs two rows; `Alt+h` migrated that way. The blockers are the
three bullets above.)

## 5. So why does `case 'f':` still exist?

The deletion rule (lesson 3): **a case leaves the switch only when every chord it
handled is either a table row or a provable no-op.** `Alt+f` anchors `case 'f'` in C
indefinitely — so the case label stays, holding one-and-a-half branches, with
tombstone comments marking what left:

```c
case 'f':
  /* rstate==0 (full zoom on canvas / forward over a graph) is data-driven now;
   * handled by the DEV_KEY dispatch above. See init_input_bindings (Phase 3c). */
  if(rstate == ControlMask) { /* search */
    if(xctx->semaphore >= 2) break;
    /* graph routing migrated (Phase 3d.1b): idle_only over_graph -> graph.forward. */
    tcleval("property_search");
  }
  else if(EQUAL_MODMASK) { /* flip ... */ }   /* stays: ui_state + mouse + modal */
  break;
```

This is not a failure state — it's the architecture working as specified. The table
and the switch *coexist by contract*: the dispatch tries the table first, and
anything without a row falls through to C unchanged. The case is smaller, its
remaining contents are exactly the parts that genuinely belong in C, and the comments
tell the next reader where the rest went.

## 6. What the journey bought, chord by chord

| Chord | Before | After | User-visible gain |
|---|---|---|---|
| `f` | hardcoded zoom + inline graph guard | 2 table rows, branch deleted | remappable (`xschem bind` / keybindings.csv), on the generated cheat-sheet, routing is data |
| `Ctrl+f` | sem guard + inline graph guard + tcleval | routing row (`idle`), guard deleted; tcleval stays in C | graph forwarding remappable; canvas behavior unchanged, still one `xschem bind` away if ever needed |
| `Alt+f` | modal flip | untouched | none — correctly so |

The general shape to take away: **migrate per chord, not per key; delete only what
the rows fully cover; let the hard parts stay in C without shame.** A refactor that
must finish 100% of a case to ship anything would never have shipped at all.
