# Tutorial: making *input* data — Phase 3 of the action registry (mouse wheel + gestures, in C)

**Audience.** A developer who has read the Phase 1/2 tutorials
(`tutorial_action_registry.md`, `tutorial_action_registry_phase2.md`) and wants
to understand the pivot: how we made mouse input remappable by building a binding
layer *inside the C engine* — and why that was the only way to reach gestures like
right-drag-to-zoom. You'll learn a clean "separate binding from behavior"
refactor, the three small data structures that carry it, and two traps that the
gesture case sprang on us.

**What we built (one sentence).** We turned the mouse wheel and the right-drag
zoom-rectangle from hardcoded `if/else` in `callback.c` into a tiny in-memory
*binding table* (signature → action id) that you can rewrite at runtime with
`xschem bind`, while the behavior — and, for gestures, the whole rubber-band drag
loop — stays in C exactly as before.

---

## 0. Why Phase 3 had to touch C

Phases 1 and 2 made *menus* and *keyboard shortcuts* data without touching the C
engine: they intercepted keys *above* C using a Tk binding trick. That works only
for **discrete, stateless, context-free** keys. It cannot reach:

- the **mouse wheel** (dispatched deep in `handle_mouse_wheel`, no table),
- **gestures** — press → drag → release, with rubber-banding coordinated against
  `xctx`,
- **context-routed** inputs (the same key meaning different things over a graph).

These are exactly the productivity-critical, *direct* interactions. There is no
engine-free way to make them remappable, so Phase 3 lifts the "don't touch C"
rule. The whole design rests on one idea.

## 1. The one idea: separate *binding* from *behavior*

The old `handle_mouse_wheel` fused two jobs:

```c
/* OLD: which input (binding) AND what it does (behavior), welded together */
if(button==Button4 && state==0) { view_zoom(CADZOOMSTEP); }       /* zoom in  */
else if(button==Button4 && (state & ControlMask) ...) {
  xctx->yorigin += -CADMOVESTEP*xctx->zoom/2.; draw(); ...        /* pan up   */
}
```

Phase 3 splits them:

- **Behavior** stays in C — it touches `xctx`, zoom, rubber-banding. It becomes a
  named function with a stable *id*.
- **Binding** — "this physical input → that id" — becomes a row in a table you can
  edit at runtime.

That's the command-pattern + keymap that editors like Emacs/VS Code use. Three
small structures carry it.

## 2. The three data structures (all in `callback.c`)

**(a) The action — behavior with an id.** Each former `if`-body becomes a tiny
function with a uniform signature, so a table can call any of them:

```c
typedef int (*action_fn)(const ActionEvent *e);   /* returns 1 if handled */

static int act_zoom_in(const ActionEvent *e) { (void)e; view_zoom(CADZOOMSTEP); return 1; }
static int act_pan_up(const ActionEvent *e) {
  (void)e; xctx->yorigin += -CADMOVESTEP*xctx->zoom/2.; draw(); redraw_w_a_l_r_p_z_rubbers(1); return 1; }
/* ... */
```

The `ActionEvent` is everything an action might need (pointer position, mods…).
The wheel/pan actions ignore it, but gesture and key actions in later phases will
use it — defining it now means the signature never has to change.

**(b) The registry — id → behavior:**

```c
typedef struct { const char *id; action_fn fn; const char *help; } ActionDef;
static const ActionDef action_registry[] = {
  { "view.zoom_in",  act_zoom_in,  "Zoom in" },
  { "view.pan_up",   act_pan_up,   "Pan up"  },
  /* ... */
};
```

The ids deliberately match `actions.csv` — one vocabulary across menus, palette,
and now input.

**(c) The binding table — signature → id.** This is the *mutable* part:

```c
typedef struct {
  int  device;   /* DEV_WHEEL / DEV_BUTTON / DEV_KEY */
  int  code;     /* WHEEL_UP, a button number, or a keysym */
  int  mods;     /* normalized modifier mask */
  int  ctx;      /* ACTX_CANVAS, ... (grows in Phase 3c) */
  char action_id[64];
} InputBinding;
static InputBinding input_bindings[MAX_INPUT_BINDINGS];
```

A **signature** is `{device, code, mods, ctx}`. Dispatch is just: build the
signature for the current event, find the row, run its action:

```c
static int dispatch_input_action(const ActionEvent *e)
{
  int i;
  ensure_input_bindings();                 /* lazy: install defaults once */
  for(i = 0; i < num_input_bindings; ++i) {
    InputBinding *b = &input_bindings[i];
    if(b->device==e->device && b->code==e->code && b->mods==e->mods && b->ctx==e->ctx) {
      action_fn fn = lookup_action_fn(b->action_id);
      if(fn) return fn(e);
      return 0;                            /* id with no C fn: Tcl-backed (future) */
    }
  }
  return 0;
}
```

The **built-in defaults reproduce the old behavior exactly** — so with no user
config, nothing changes:

```c
set_input_binding(DEV_WHEEL, WHEEL_UP,   0,           ACTX_CANVAS, "view.zoom_in");
set_input_binding(DEV_WHEEL, WHEEL_UP,   ControlMask, ACTX_CANVAS, "view.pan_up");
/* ...6 wheel rows... then Phase 3b adds: */
set_input_binding(DEV_BUTTON, Button3,   0,           ACTX_CANVAS, "view.zoom_rect");
```

## 3. Exposing it to the user: `xschem bind`, and a dispatcher gotcha

A user remaps with no GUI and no recompile by issuing a command (e.g. in
`.xschemrc`):

```
xschem bind wheel up 0 canvas view.pan_up      # wheel-up now pans instead of zooming
xschem unbind wheel up 0 canvas                # back to nothing
xschem bindings dump                           # list current bindings
```

These are wired into the giant `xschem` dispatcher in `scheduler.c`. **Trap:** that
dispatcher is a `switch` on the subcommand's *first letter*, then an else-if
chain:

```c
switch(argv[1][0]) {
  case 'b': ... else if(!strcmp(argv[1],"bind")) ... else if(!strcmp(argv[1],"bindings")) ...
  case 'u': ... else if(!strcmp(argv[1],"unbind")) ...   /* NOT next to bind! */
}
```

We first put `unbind` next to `bind` in `case 'b'` — and it silently became
"invalid command," because `unbind` starts with `u`. Any new subcommand must live
in the case matching its first letter.

## 4. The wheel rewrite (3a): faithful by construction

The new `handle_mouse_wheel` computes a signature and dispatches — but it keeps
two things *verbatim*, because they're behavior we must not change:

1. **Graph routing.** When the pointer is over a waveform graph, the wheel belongs
   to the graph. Only the no-modifier and Shift wheel ever routed there;
   Ctrl-wheel never did. We preserved that branch exactly.
2. **The `state==0` nuance.** "No modifier" means `state==0` *exactly* — important
   because, by the time we reach this code, the caller has already stripped the
   button-mask bits (`state &= ~(Button1Mask|…)` in `handle_button_press`), so the
   remaining bits are pure modifiers.

```c
if(state == 0) {
  if(waves_selected(...)) { waves_callback(...); return 1; }   /* graph wins */
  mods = 0;
} else if(!graph_use_ctrl_key && (state & ShiftMask) && !(state & Button2Mask)) {
  if(waves_selected(...)) { waves_callback(...); return 1; }
  mods = ShiftMask;
} else if(!graph_use_ctrl_key && (state & ControlMask) && !(state & Button2Mask)) {
  mods = ControlMask;                                          /* Ctrl never routes to graph */
} else return 0;

ae.device = DEV_WHEEL; ae.code = wheel; ae.mods = mods; ae.ctx = ACTX_CANVAS;
dispatch_input_action(&ae);
```

This is the template for the rest of Phase 3: *keep the context decisions in C for
now, make the action choice data.*

## 5. The gesture (3b): why it's a different animal

A wheel notch is one event → one action. A gesture is **three phases across many
events**:

```
press   -> zoom_rectangle(START)    sets ui_state bit STARTZOOM, records corner 1
motion* -> zoom_rectangle(RUBBER)   updates corner 2, redraws the rubber band
release -> zoom_rectangle(END)      computes the zoom from the two corners
```

If we naively "bound the gesture," we'd have to reimplement that whole loop in the
binding layer. We don't. We bind **only the initiating chord** and let the
existing C machinery run the rest. The reason this is even possible is a property
we discovered by reading the code:

| Phase | Triggered by | Keyed on |
|---|---|---|
| START | Button3 press | **the button number** ← the only button-specific bit |
| RUBBER | mouse motion | `ui_state & STARTZOOM` (`callback.c:119`) — button-agnostic |
| END | button release | `ui_state & STARTZOOM` (`zoom_rectangle`) — button-agnostic |

Once `STARTZOOM` is set, the drag and finish don't care *how* it started. So
"make the gesture remappable" reduces to "make the START chord a table lookup."

## 6. Binding the chord — one branch, one helper

The START action:

```c
static int act_zoom_rect_start(const ActionEvent *e) { (void)e; zoom_rectangle(START); return 1; }
```

A button-chord dispatch helper (buttons reuse the same table, device `DEV_BUTTON`):

```c
static int dispatch_button_chord(int button, int state, int mx, int my)
{
  ActionEvent ae;
  ae.device = DEV_BUTTON; ae.code = button; ae.mods = state; ae.ctx = ACTX_CANVAS;
  ae.mx = mx; ae.my = my; ae.state = state;
  return dispatch_input_action(&ae);
}
```

And the branch in `handle_button_press` — note we kept the *exact guards* of the
old zoom branch (`!excl && semaphore<2`), only generalizing the chord:

```c
/* BEFORE */
else if(!excl && button == Button3 && state == 0 && xctx->semaphore < 2) {
  zoom_rectangle(START); return;
}
/* AFTER */
else if(!excl && xctx->semaphore < 2 && dispatch_button_chord(button, state, mx, my)) {
  return;
}
```

Because the default table has only `button 3 / mods 0`, this fires for exactly the
same input as before — but now it's data.

## 7. Trap: the *completion* was button-specific too

The table above says START is "the only button-specific bit" — that's true of the
gesture's drawing logic, but not of the **release handler**. We found this in
`handle_button_release`:

```c
if(state == Button3Mask && xctx->semaphore <2) {
  if(!end_place_move_copy_zoom()) {                 /* finishes a pending STARTZOOM */
    context_menu_action(...);                       /* else: right-click menu */
  }
}
```

So a gesture remapped to (say) button 2 would *start* but never *finish* — release
wouldn't match `Button3Mask`. The fix is a button-agnostic completion that is
**inert under defaults**:

```c
else if((xctx->ui_state & STARTZOOM) && xctx->semaphore < 2) {
  end_place_move_copy_zoom();
}
```

With default bindings, `STARTZOOM` is never pending on a non-Button3 release, so
this never runs — the Button3 path, including the elegant "drag→zoom /
click→context-menu" distinction, is untouched. The lesson generalizes: **a gesture
isn't just its start; check every event in its lifecycle for a hardcoded trigger.**

## 8. Trap: the test must actually *drag*

`zoom_rectangle(END)` zooms only if the rectangle is non-degenerate, and it reads
the second corner (`nl_x2`) that the **RUBBER (motion) pass** wrote — not the
release coordinates:

```c
if( xctx->nl_x1 != xctx->nl_x2 || xctx->nl_y1 != xctx->nl_y2) { /* ...zoom... */ }
```

A press-then-release with no motion is a degenerate rect → no zoom (and, on
Button3, a context menu instead). So the headless test drives all three phases:

```tcl
proc press {x y}   { xschem callback .drw 4 $x $y 0 3 0 0 }      ;# ButtonPress  button3
proc drag  {x y}   { xschem callback .drw 6 $x $y 0 0 0 1024 }   ;# MotionNotify Button3Mask
proc release {x y} { xschem callback .drw 5 $x $y 0 3 0 1024 }   ;# ButtonRelease button3

press 200 200
check "press sets STARTZOOM" [expr {[xschem get ui_state] & 128}] {}
drag 600 480 ; release 600 480
check "release clears STARTZOOM" [expr {!([xschem get ui_state] & 128)}] {}
```

## 9. Proving it's data, not luck

The strongest proof that the *table* drives the gesture (not leftover hardcoded C)
is unbind → inert → rebind:

```tcl
xschem unbind button 3 0 canvas
press 250 250
check "unbound press is inert" [expr {!([xschem get ui_state] & 128)}] {}   ;# nothing starts
xschem bind button 3 0 canvas view.zoom_rect
press 250 250
check "rebound press starts zoom" [expr {[xschem get ui_state] & 128}] {}
```

**A detour worth recording:** we wanted to *positively* prove remap by moving the
gesture onto button 2. But button 2 is special-cased in the early `skip` logic
(`callback.c:48/50/52` skip button-2 press/release/motion, because button 2 = pan
has its own handling). Rather than fight that, we proved data-drivenness via
unbind/rebind and logged button 2's hardwiring as a cleanup candidate for a later
phase. *Don't bend the test around an unrelated special case — prove the property
a cleaner way and write the special case down.*

## 10. Transferable lessons

1. **Split binding from behavior.** The moment "which input" and "what it does"
   live in different places, "which input" can become data — and you've changed
   nothing about "what it does."
2. **Defaults in the table = transparency for free.** Seed the table to reproduce
   the old code; a passing "behaves identically" test is then structural, not
   hopeful.
3. **Bind the *trigger*, not the interaction.** Gestures stay in C; only their
   entry point becomes data. Look for the state bit (`ui_state`) that already makes
   the continuation trigger-agnostic — if it exists, the migration is cheap.
4. **A gesture has more than one hardcoded trigger.** Start, *and* completion, and
   sometimes cancel. Audit the whole lifecycle.
5. **Tests for stateful flows must replay the whole flow** (press → motion →
   release), and assert on observable state (`xschem get ui_state`, `get zoom`),
   not on the input you sent.

## Appendix: the files & commits

| File | Phase | What changed |
|---|---|---|
| `src/callback.c` | 3a, 3b | registry, binding table, `dispatch_input_action`, the `act_*` functions, `dispatch_button_chord`, rewritten `handle_mouse_wheel`, the generalized button branch, the completion `else-if` |
| `src/scheduler.c` | 3a | `bind`/`bindings` (`case 'b'`), `unbind` (`case 'u'`) |
| `src/xschem.h` | 3a | three `extern` prototypes |
| `tests/headless/test_mouse_bindings.tcl` | 3a | wheel: defaults, dump, remap, unbind (15 checks) |
| `tests/headless/test_gesture_bindings.tcl` | 3b | gesture: start/drag/end, unbind→inert→rebind (9 checks) |

Plan & status: `refactor_plan_action_registry_phase3.md`. Diff snapshot:
`doc/claude/code_analysis/file_diff_snapshot_action_registry_phase3a.md`. Verified each phase:
the new tests + engine harness 6/6 + the Phase-2 GUI smokes still green.
