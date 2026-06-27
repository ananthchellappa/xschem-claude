# Tutorial: turning a hardcoded `if(over_graph)` into data — Phase 3c, steps c1+c3

**Audience.** A developer who has read the context-precedence tutorial
(`tutorial_action_registry_phase3c.md`) and wants to see that mechanism actually
*used*: migrating the mouse wheel's "is the pointer over a waveform graph?"
routing out of inline C guards and into binding-table rows.

**What we built (one sentence).** The wheel's graph-vs-canvas fork — previously
`if(waves_selected(...)) { waves_callback(...); return; }` welded into
`handle_mouse_wheel` — is now expressed as `over_graph` rows that resolve to a new
`graph.forward` action, so "what the wheel does over a graph" is data the
precedence lookup (c2) resolves.

---

## 0. Where c2 left off

Step c2 taught `dispatch_input_action` to prefer a row matching the event's own
context, then fall back to `global`. But nothing *produced* a non-canvas context
yet: every default was `ACTX_CANVAS` and every caller passed `ACTX_CANVAS`, so the
precedence machinery was real but dormant. c1+c3 wake it up for the wheel.

## 1. The thing we're replacing

xschem decides "does this input belong to a waveform graph under the pointer?"
with `waves_selected()`, called ~30 times as a hardcoded guard. The wheel's copy
looked like this (post-3a):

```c
if(state == 0) {
  if(waves_selected(event, key, state, button)) {       /* over a graph? */
    waves_callback(event, mx, my, key, button, aux, state);   /* yes: hand to graph */
    return 1;
  }
  mods = 0;                                              /* no: it's a canvas zoom */
}
```

That `if` is a *binding decision* ("over_graph → the graph handles it") trapped in
control flow. We want it to be a row.

## 2. c1 — give the context a name

One function, the only place that consults `waves_selected` for routing:

```c
static int current_input_ctx(int event, KeySym key, int state, int button)
{
  return waves_selected(event, key, state, button) ? ACTX_OVER_GRAPH : ACTX_CANVAS;
}
```

(We deliberately deferred this from its "c1" slot until now — adding it earlier
would have been a function with no caller. See the c2 tutorial's process note.)

## 3. c3 — the action, and a problem it exposes

The row needs an action to point at. "Forwarding to the graph" is just calling
`waves_callback`:

```c
static int act_graph_forward(const ActionEvent *e) {
  waves_callback(e->xevent, e->mx, e->my, e->key, e->button, e->aux, e->state); return 1; }
```

But look at the arguments — `waves_callback` wants the **raw X event** (`event`,
`key`, `button`, `aux`). Our `ActionEvent` carried only the *cooked* signature
(`device`, `code`, `mods`, `ctx`) plus `mx/my/state`. An action that *re-forwards*
an event needs the original event, not the abstraction.

So `ActionEvent` grew a raw-event tail:

```c
typedef struct {
  int device, code, mods, ctx;
  int mx, my, state;
  /* raw X event params, for actions that re-forward the event (e.g. graph.forward) */
  int xevent; KeySym key; int button; int aux;
} ActionEvent;
```

**Lesson:** a dispatch abstraction must keep an escape hatch to the raw input.
Most actions want the tidy signature; "forward this somewhere else" actions need
the unabstracted original. Carry both.

Then the rows — four of them, the no-modifier and Shift wheel, up and down:

```c
set_input_binding(DEV_WHEEL, WHEEL_UP,   0,         ACTX_OVER_GRAPH, "graph.forward");
set_input_binding(DEV_WHEEL, WHEEL_DOWN, 0,         ACTX_OVER_GRAPH, "graph.forward");
set_input_binding(DEV_WHEEL, WHEEL_UP,   ShiftMask, ACTX_OVER_GRAPH, "graph.forward");
set_input_binding(DEV_WHEEL, WHEEL_DOWN, ShiftMask, ACTX_OVER_GRAPH, "graph.forward");
```

## 4. The trap: not every branch is context-sensitive

The naive migration is "compute the real context for every wheel event." That is
**wrong**, and the original code tells you why: the Ctrl-wheel branch had *no*
`waves_selected` check. Ctrl+wheel pans the canvas whether or not you're over a
graph. If you blanket-apply `current_input_ctx`, then Ctrl+wheel *over a graph*
becomes `ACTX_OVER_GRAPH` → no Ctrl/over_graph row exists → it does nothing. You'd
have silently broken a working interaction.

So context is computed **per branch**, mirroring exactly where the original had a
`waves_selected` guard:

```c
if(state == 0) {                                  /* had a guard */
  mods = 0;          ctx = current_input_ctx(event, key, state, button);
} else if(!graph_use_ctrl_key && (state & ShiftMask) && !(state & Button2Mask)) {  /* had a guard */
  mods = ShiftMask;  ctx = current_input_ctx(event, key, state, button);
} else if(!graph_use_ctrl_key && (state & ControlMask) && !(state & Button2Mask)) { /* NO guard */
  mods = ControlMask; ctx = ACTX_CANVAS;          /* Ctrl-wheel never consulted the graph */
} else return 0;
```

**Lesson:** when you turn special-cases into data, migrate them *exactly* — read
which branches had the behavior and which didn't. "Make it uniform" is a bug when
the original wasn't.

## 5. Preserve the return-value contract

`handle_mouse_wheel` returns 1 when the caller should stop. The old code returned
1 only on the graph path (`waves_callback` consumed it) and 0 for a canvas
zoom/pan. The dispatch result alone can't reproduce that (a canvas zoom also
"matched"). But context can — graph routing happens iff `ctx == OVER_GRAPH`:

```c
dispatch_input_action(&ae);
return (ctx == ACTX_OVER_GRAPH);   /* graph consumed it -> 1, exactly as before */
```

This is faithful because, in the guarded branches, `ctx == OVER_GRAPH` is *by
definition* `waves_selected(...) == true` — the same condition that returned 1
before.

## 6. Testing it needs a real graph — and a coordinate transform

Unlike the canvas-only tests, this one needs `waves_selected` to return true,
which needs (a) a graph in the schematic and (b) the pointer inside it. We reused
an existing example that has a graph rect (`tb_test_evaluated_param.sch`, rect at
schematic `540,-740 .. 1200,-340`), then converted schematic coordinates to screen
pixels to aim the wheel. The transform is in `xschem.h`:

```c
#define X_TO_XSCHEM(x) ( (x) * xctx->zoom - xctx->xorigin )   /* screen px -> schematic */
```

Invert it to go schematic → screen: `s = (sch + origin) / zoom`:

```tcl
set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
proc screen {sx sy} { global xo yo zm; list [expr {int(($sx+$xo)/$zm)}] [expr {int(($sy+$yo)/$zm)}] }
lassign [screen 870 -540] gx gy   ;# center of the graph rect
lassign [screen 870  100] cx cy   ;# below it: bare canvas
```

The discriminator is the same idea as the precedence test — assert on the effect
unique to the path you expect. Over the graph, the *canvas* zoom must not change
(the graph consumed the wheel); over bare canvas it must:

```tcl
set z0 [xschem get zoom]; wheelat $gx $gy
check "over-graph leaves canvas zoom" [expr {[xschem get zoom] == $z0}] {}
set z0 [xschem get zoom]; wheelat $cx $cy
check "over-canvas zooms"             [expr {[xschem get zoom] != $z0}] {}
```

One environment knob: set `graph_use_ctrl_key 0`, because the no-modifier wheel
only consults the graph when that flag is off (the flag is still control flow in
`handle_mouse_wheel`/`waves_selected`, not yet data — and that's fine for now).

## 7. The recurring "stale count" trap

Adding the four `over_graph` rows broke an *older* test: `test_mouse_bindings` had
`check "dump has 6 wheel rows"`, and there are now ten. We'd already narrowed it
once (from "6 rows" to "6 wheel rows" when buttons arrived); now it became "6
*canvas* wheel rows." Every time you add a device or context, a hardcoded total in
some earlier test goes stale. Prefer assertions scoped to exactly what a test
owns (`device == wheel && ctx == canvas`) over global counts.

## 8. Transferable lessons

1. **Build the mechanism, then feed it.** c2 added precedence with all-canvas
   defaults (dormant); c3 produced the first non-canvas context and rows. Each step
   was independently provable.
2. **A dispatch struct needs a raw-event escape hatch** for "forward" actions.
3. **Migrate special cases exactly** — the Ctrl-wheel branch that *lacked* a graph
   check had to keep lacking one. Uniformity is a bug when the source wasn't
   uniform.
4. **Reproduce side-effect contracts** (the 1/0 return) from a condition you still
   have (`ctx`), not from a proxy that doesn't quite mean the same thing.
5. **Scope test assertions to what the test owns**, so adding capability elsewhere
   doesn't ripple stale-count failures.

## Appendix: the change

| File | What changed |
|---|---|
| `src/callback.c` | `current_input_ctx`; `act_graph_forward` + registry row; `ActionEvent` raw-event fields; 4 `over_graph` wheel defaults; `handle_mouse_wheel` computes per-branch context and drops the inline `waves_selected` guards |
| `tests/headless/test_graph_context.tcl` | new (3 checks): loads a graph schematic, wheel over graph vs canvas |
| `tests/headless/test_mouse_bindings.tcl` | count assertion narrowed to canvas-context wheel rows |

Commit `c153153c`. Verified: the new test 3/3, engine harness 6/6, all prior GUI
smokes green. Next: c4+c5 — the `DEV_KEY` dispatch atop `handle_key_press`, which
lets context-routed *keys* (`s`/`f`/`a`/arrows) become data too.
