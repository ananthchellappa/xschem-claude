# Tutorial: one input, two meanings — context-aware binding dispatch (Phase 3c, step c2)

**Audience.** A developer who has read the Phase 3 tutorial
(`tutorial_action_registry_phase3.md`) and wants to see how we added *context* to
the binding table — the dimension that lets the same physical input do different
things depending on where the pointer is — and how we did it as a strictly
behavior-neutral plumbing step.

**What we built (one sentence).** `dispatch_input_action` now resolves a binding
by **most-specific-wins**: it looks for a row matching the event's own context
first, then falls back to a context-independent (`global`) row — so a future row
scoped to "over a graph" can override a "global" row for the very same key.

---

## 0. The problem this unlocks

xschem's hardest-to-migrate inputs are the ones where *the same key means
different things by location*: press `s` over a waveform graph and it talks to the
graph; press it on the schematic canvas and it does something else. Today that
fork is hardcoded ~30 times in `callback.c` as
`if(waves_selected(...)) { waves_callback(...); return; }`.

To turn that fork into *data*, a binding needs a **context** field, and dispatch
needs to understand that some rows are more specific than others. Step c2 builds
exactly that resolution rule — and nothing else. (Migrating the actual
`waves_selected` guards into rows is the next step, c3.)

## 1. The data was already there — only the lookup changed

The binding struct has carried a `ctx` field since Phase 3a:

```c
typedef struct { int device, code, mods, ctx; char action_id[64]; } InputBinding;
enum { ACTX_GLOBAL = 0, ACTX_CANVAS = 1, ACTX_OVER_GRAPH = 2 };
```

Until now every default was `ACTX_CANVAS` and dispatch did an *exact* match on all
four fields. c2 changes only the lookup, from "exact match" to "specific, then
global":

```c
static int dispatch_input_action(const ActionEvent *e)
{
  InputBinding *b;
  action_fn fn;
  ensure_input_bindings();
  b = find_binding(e->device, e->code, e->mods, e->ctx);                /* 1. specific */
  if(!b && e->ctx != ACTX_GLOBAL)
    b = find_binding(e->device, e->code, e->mods, ACTX_GLOBAL);         /* 2. fallback */
  if(!b) return 0;
  fn = lookup_action_fn(b->action_id);
  return fn ? fn(e) : 0;
}
```

Two lines of policy: try the event's context; if nothing, try `global`. A row
scoped to `over_graph` (or `canvas`) therefore *beats* a `global` row for the same
signature, and `global` means "applies in any context."

## 2. A small refactor that pays for itself: `find_binding`

The precedence lookup needs to search the table twice (specific, then global), so
the search became its own function:

```c
static InputBinding *find_binding(int device, int code, int mods, int ctx)
{
  int i;
  for(i = 0; i < num_input_bindings; ++i) {
    InputBinding *b = &input_bindings[i];
    if(b->device==device && b->code==code && b->mods==mods && b->ctx==ctx) return b;
  }
  return NULL;
}
```

`set_input_binding` had its own copy of that loop; it now calls `find_binding`
too, so the "match a signature" logic lives in exactly one place. When you split a
function out for one caller, check whether an existing caller was hand-rolling the
same thing — usually it was.

## 3. Why this is behavior-neutral (and how we know)

Every built-in default is `ACTX_CANVAS`, and every caller still passes
`ACTX_CANVAS` (the wheel and gesture handlers haven't been taught to compute the
real context yet — that's c1/c3). So step (1) of the lookup always finds the
canvas row and step (2) never runs. The dispatch resolves to exactly what it did
before. "No behavior change" here isn't a hope — it's a consequence of the
defaults all sharing one context.

## 4. Testing precedence *without* a graph

The honest worry: the headline feature (over-graph rows winning) needs a loaded
waveform graph to make `waves_selected` true, and we don't have that fixture yet.
But precedence is a property of the *lookup*, and we can exercise both of its rules
using ordinary canvas events:

- **specific beats global:** add a `global` row for the wheel-up signature
  alongside the default `canvas` row, fire a canvas wheel-up, and confirm the
  *canvas* action ran.
- **global is the fallback:** remove the `canvas` row, fire the same event, and
  confirm the *global* action now runs.

```tcl
xschem bind wheel up 0 global view.pan_up        ;# canvas default is view.zoom_in
# (a) canvas row should win:
set z0 [xschem get zoom]; wheel
check "specific beats global" [expr {[xschem get zoom] != $z0}] {}   ;# zoom_in ran
# (b) drop the canvas row -> global takes over:
xschem unbind wheel up 0 canvas
set z0 [xschem get zoom]; set y0 [xschem get yorigin]; wheel
check "global fallback ran pan" \
  [expr {[xschem get zoom] == $z0 && [xschem get yorigin] != $y0}] {}
```

The `over_graph` case (a graph-scoped row beating a canvas/global one) is deferred
to c3, where it arrives together with the graph test fixture.

### Trap: pick a discriminator the *other* action can't fake

The first instinct was "zoom_in changes the view, pan_up changes the view, so
check the origin moved." Wrong: `view_zoom` deliberately shifts `xorigin/yorigin`
too (it zooms toward the cursor). The only quantity that distinguishes them is
**`zoom` itself** — `view.pan_up` never touches it. So the test keys off "did
`zoom` change?", not "did the origin move?". When two actions share a side effect,
assert on the side effect that is *unique* to the one you expect.

## 5. A process note: don't commit dead code to follow a checklist

The plan listed c1 (`current_input_ctx`, which maps an event to a context by
wrapping `waves_selected`) *before* c2. But c1 has no caller until c3 wires it into
the handlers — committing it at c1 would land a dead, uncalled function. So we did
c2 first (the live, testable plumbing) and folded c1 into c3. The checklist is a
guide to scope, not a contract about ordering: prefer commits where every line is
reachable.

## 6. Transferable lessons

1. **Add the dimension to the *lookup*, not (yet) to the callers.** The struct
   already had `ctx`; making dispatch context-aware was a self-contained, provable
   step that changed no behavior. Land the resolution rule before the data that
   exercises it.
2. **Precedence is testable independently of its motivating case.** We couldn't
   make `over_graph` true without a fixture, but "specific beats general, general
   is the fallback" is provable with the contexts we *can* produce.
3. **Refactor the duplicated predicate when a second caller appears.** One
   `find_binding` now serves dispatch and `set_input_binding`.
4. **Choose assertions on effects unique to the expected action** (here `zoom`),
   never on effects both candidates share.
5. **Reorder checklist steps to keep every commit free of dead code.**

## Appendix: the change

| File | What changed |
|---|---|
| `src/callback.c` | `find_binding` helper; `set_input_binding` reuses it; `dispatch_input_action` does specific→global precedence |
| `tests/headless/test_binding_precedence.tcl` | new (5 checks): specific-beats-global, global-fallback, restore |

Commit `b1965144`. Verified: the new test 5/5, engine harness 6/6, all prior GUI
smokes green. Next: c1+c3 — compute the real context and migrate the wheel's
`waves_selected` graph-routing into `over_graph` rows.
