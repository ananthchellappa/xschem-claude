# Guided diff walkthrough — Phase 3 input bindings (read with the diff open)

A companion for reading the actual Phase 3 change top-to-bottom, the way it
appears in the diff — distinct from the *file-level* snapshots
(`file_diff_snapshot_*`) and the *concept-first* tutorials (`tutorial_*`). This
one mirrors the hunks in reading order and says, at a high level, what each does
and why.

**Open the diff alongside this:**

```sh
git diff master..HEAD -- src/callback.c src/scheduler.c    # the whole Phase 3 C change
git diff master..HEAD -- src/xschem.h                      # 3 Phase-3 lines (rest is the util refactor)
```

`callback.c` and `scheduler.c` are touched *only* by Phase 3, so `master..HEAD` on
those two files is exactly the feature — nothing else mixed in.

**Scope.** In: the C input-binding engine (3a wheel + 3b gesture + 3c contexts)
and its four tests. Out (don't be distracted by them in a full `master..HEAD`):
`util.c`/`util.h`/`editprop.c` (a separate utility-extraction refactor),
`actions.csv`/`action_registry.tcl`/`xschem.tcl` (Phase 1/2, Tcl-only), and the
`tests/headless/` harness scaffolding (`run.sh`, `gold/`, …) which predates this.

**Headline numbers.** `callback.c` ~+360 net (one new section + three handler
rewrites), `scheduler.c` +25, `xschem.h` +6, four new test files (~280 lines).

---

## Part A — `src/callback.c` (the meat)

Everything new lives in one marked section that the diff inserts *just before*
`handle_mouse_wheel`, followed by edits to three existing handlers. Read it in
this order:

### A1. The new section header + types
A big comment banner ("Phase 3a: data-driven input-action dispatch"), then the
vocabulary: `enum`s for `DEV_WHEEL/BUTTON/KEY`, `WHEEL_UP/DOWN`, and
`ACTX_GLOBAL/CANVAS/OVER_GRAPH`; the `ActionEvent` struct; the `action_fn`
typedef. **Why first:** everything below refers to these. Note `ActionEvent`
carries both the *cooked* signature (`device/code/mods/ctx`) and — added in 3c — a
*raw* tail (`xevent/key/button/aux`) for actions that re-forward the event.

### A2. The action functions (behavior)
Six one-liners (`act_zoom_in/out`, `act_pan_*`), then `act_zoom_rect_start` (3b)
and `act_graph_forward` (3c). **Why:** these are the *behavior* half — each is a
former `if`-body lifted verbatim into a named function. Reading them confirms "no
behavior was rewritten, just relocated."

### A3. The registry (id → behavior)
`action_registry[]` plus `lookup_action_fn`. A flat table mapping a string id
(matching `actions.csv`) to one of the A2 functions. The id namespace is the
contract that ties C input to the Tcl action table.

### A4. The binding table (signature → id)
`InputBinding` array, then `find_binding` (added in 3c), `set_input_binding`
(reuses `find_binding`), `unset_input_binding`, `init_input_bindings` (the
built-in defaults), and `ensure_input_bindings` (lazy init). **Why this matters:**
this is the *mutable* state — the thing `xschem bind` edits. Skim
`init_input_bindings`: the 6 canvas wheel rows (3a), the `button 3` zoom-rect row
(3b), and the 4 `over_graph` wheel rows (3c) are the whole default behavior, as
data.

### A5. Context + dispatch
`current_input_ctx` (3c: `waves_selected ? OVER_GRAPH : CANVAS`) and
`dispatch_input_action`. The dispatch is the heart: **most-specific-wins** — try
the event's own context, then fall back to `ACTX_GLOBAL`. Three lines of policy
that the precedence test exercises.

### A6. `dispatch_button_chord`
A thin wrapper that builds an `ActionEvent` for a mouse button and calls dispatch
(3b). Note it sets the raw-event tail to zeros — buttons don't forward to graphs
(that path returns earlier).

### A7. Parsers + the `xschem` command backends
`parse_device/code/mods/ctx`, the inverse `*_name` helpers, then
`action_cmd_bind`, `action_cmd_unbind`, `action_cmd_bindings`. **Why:** this is
the user-facing surface. These take `argc/argv`, validate, mutate the table, and
set the Tcl result. Keeping all parsing here is why `scheduler.c`'s hunk is tiny.

### A8. `handle_mouse_wheel` — the rewrite to study
This is the single most instructive hunk. The diff replaces the old `if/else`
ladder (which *did* the zoom/pan/graph-routing inline) with: compute
`wheel`/`mods`/`ctx` per branch, then one `dispatch_input_action` call. Read the
three branches and notice the faithfulness decisions:
- no-mod and Shift compute `ctx = current_input_ctx(...)` (they can land on a graph);
- **Ctrl stays `ACTX_CANVAS`** — the original had no `waves_selected` check there, and changing that would have broken Ctrl+wheel-over-graph;
- the function returns `(ctx == ACTX_OVER_GRAPH)`, reproducing the old "graph consumed it → 1" contract.

### A9. `handle_button_press` — the gesture trigger
A small hunk: the old `else if(... button==Button3 && state==0 ...) { zoom_rectangle(START); return; }` becomes `else if(!excl && semaphore<2 && dispatch_button_chord(button, state, mx, my)) return;`. **Why:** only the *initiating chord* became data; the same `!excl && semaphore<2` guards are preserved. Everything else about the gesture is untouched.

### A10. `handle_button_release` — the completion fix
A two-line `else if` added after the Button3 block: if a `STARTZOOM` is pending on
a non-Button3 release, finish it. **Why it's here:** a gesture remapped onto
another button must still *complete*; this is inert under defaults (the Button3
path, including click→context-menu, is unchanged). The lesson hunk: a gesture has
more than one hardcoded trigger — start *and* completion.

## Part B — `src/scheduler.c` (+25)
Two hunks, both tiny because the logic lives in A7:
- `case 'b'`: `bind` and `bindings` branches calling `action_cmd_bind/bindings`.
- `case 'u'`: the `unbind` branch calling `action_cmd_unbind`.

The split looks odd until you remember the dispatcher switches on the
subcommand's **first letter** — `unbind` *must* live under `'u'`, not beside
`bind`. (We learned that the hard way; "invalid command" was the symptom.)

## Part C — `src/xschem.h` (the 3 Phase-3 lines)
Just three `extern` prototypes for `action_cmd_bind/unbind/bindings`, so
`scheduler.c` can reach the backends in `callback.c`. The binding types/enums stay
private to `callback.c` — the header surface is intentionally minimal. (The rest
of `xschem.h`'s diff is the unrelated util refactor.)

## Part D — the tests (read these to see intended behavior)
Each is a runnable spec; reading them is the fastest way to learn what the feature
*guarantees*:
- `test_mouse_bindings.tcl` — wheel: defaults reproduce old behavior, `dump`, remap, unbind (15 checks).
- `test_gesture_bindings.tcl` — gesture: press→drag→release zooms; unbind→inert→rebind (9).
- `test_binding_precedence.tcl` — context lookup: specific beats global, global is the fallback (5).
- `test_graph_context.tcl` — real graph fixture: wheel over graph vs canvas (3).

A recurring detail visible across their diffs: count assertions are scoped (e.g.
"6 *canvas* wheel rows"), because each phase that adds a device/context would
otherwise break an earlier total.

## How the pieces connect (one breath)
An X event enters `callback()` → `handle_button_press`/`handle_mouse_wheel` builds
a **signature** (`device, code, mods`) and a **context** → `dispatch_input_action`
resolves signature+context to an **id** via the binding table (specific, then
global) → `lookup_action_fn` resolves the id to a **behavior** → the `act_*`
function runs against `xctx`. `xschem bind/unbind` edit the table; `bindings dump`
prints it. (The Phase 3a snapshot has this as an ASCII data-flow diagram.)

## Where to go next
- The *why* behind each piece: `doc/claude/suggestions/tutorial_action_registry_phase3.md`
  (3a/3b), `_phase3c.md` (precedence), `_phase3c_graph_routing.md` (contexts).
- File-level inventory + line counts: `file_diff_snapshot_action_registry_phase3a.md`.
- The remaining plan (c4–c6, then 3d): `refactor_plan_action_registry_phase3.md`.
