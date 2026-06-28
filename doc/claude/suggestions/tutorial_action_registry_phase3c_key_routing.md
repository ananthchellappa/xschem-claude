# Phase 3c c4/c5 — the DEV_KEY dispatch: context-routed *keys* become data

This is the key-side counterpart of the graph-routing tutorial. Where c3 moved the
wheel's graph-vs-canvas routing into the binding table, c4/c5 add a **`DEV_KEY`
dispatch at the top of `handle_key_press`** and migrate the first key — plain `f`
(full-zoom). The machinery is what matters; `f` is just the first thing fed to it.

## 1. What was there before

Inside the ~1600-line `switch (key)` in `handle_key_press`, every key that behaves
differently over a waveform graph carried the *same* 4-line guard at the top of its
branch:

```c
case 'f':
  if(rstate == 0) { /* full zoom */
    int flags = 1;
    if(waves_selected(event, key, state, button)) {   /* <-- the graph guard */
      waves_callback(event, mx, my, key, button, aux, state);
      break;
    }
    if(tclgetboolvar("zoom_full_center")) flags |= 2;
    zoom_full(1, 0, flags, 0.97);
  }
  else if(rstate == ControlMask) { /* search */ ... }
  else if(EQUAL_MODMASK)         { /* flip   */ ... }
  break;
```

That guard is *identical* across ~22 (key, mods) branches (`a`, `A`, `b`, `B`, `f`,
`m`, `s`, `t`, arrows, …). It is exactly the "route to the graph when the pointer is
over one" rule — already captured as the `graph.forward` action and an `over_graph`
binding row in c3. So the migration is mechanical: add table rows, delete the guard.

## 2. The new shape

```c
static void handle_key_press(...)
{
  char str[PATH_MAX + 100];
  int dr_gr;

  /* table-first; switch is the fallthrough */
  {
    int kmods = (key < 0xff00) ? rstate : state;
    if(key_chord_has_binding((int)key, kmods)) {
      ActionEvent ae;
      ae.device = DEV_KEY; ae.code = (int)key; ae.mods = kmods;
      ae.ctx = current_input_ctx(event, key, state, button);
      /* ... mx/my/state/xevent/key/button/aux ... */
      if(dispatch_input_action(&ae)) return;   /* handled: done */
    }
  }

  switch (key) { ... }   /* unchanged for everything not migrated */
}
```

Plus two default rows and a new action:

```c
set_input_binding(DEV_KEY, 'f', 0, ACTX_CANVAS,     "view.zoom_full");
set_input_binding(DEV_KEY, 'f', 0, ACTX_OVER_GRAPH, "graph.forward");
```

`act_zoom_full` holds the canvas behavior (the old `rstate==0` body, verbatim); the
`rstate==0` arm of `case 'f'` is deleted. `Ctrl-f` (search) and `Alt-f` (flip) keep
their arms in the switch — they were not migrated, so their `{f, Ctrl/Alt, *}`
chords have no rows and fall straight through.

## 3. The one trap that shaped the whole design: side effects

`current_input_ctx` calls `waves_selected`, and **`waves_selected` is not a pure
predicate** — when the pointer is over (or leaves) a graph it mutates
`xctx->graph_master`, clears `GRAPHPAN`, reconfigures the `.drw` cursor, and can
call `graph_show_measure stop` (`callback.c:83-107`).

If the dispatch computed `ctx` for *every* keypress, then pressing an un-migrated
key like `g` or `k` while hovering a graph would now fire those side effects, where
before it fired none. That is a behavior change, however subtle.

**The gate fixes this.** `key_chord_has_binding(code, mods)` is a cheap table scan
that runs *before* `current_input_ctx`:

```c
static int key_chord_has_binding(int code, int mods) {
  int i; ensure_input_bindings();
  for(i = 0; i < num_input_bindings; ++i)
    if(input_bindings[i].device==DEV_KEY &&
       input_bindings[i].code==code && input_bindings[i].mods==mods) return 1;
  return 0;
}
```

Only a chord we actually migrated reaches `waves_selected` — and those are exactly
the chords that already called it in their old guard. So **migrated keys preserve
their side-effect contract and un-migrated keys never acquire one.** The dispatch
*could* just return 0 for an unbound chord, but only after computing `ctx`; the gate
keeps the side-effectful call from happening at all.

## 4. The mods-normalization rule

The switch reads modifiers two different ways, and the signature must match:

- **letter / printable keysyms** branch on `rstate` (= `state` with `ShiftMask`
  stripped): `rstate==0`, `rstate==ControlMask`, `EQUAL_MODMASK` (Alt).
- **named keysyms** (arrows, Tab, …) branch on the raw `state`: `state==ControlMask`.

So `kmods = (key < 0xff00) ? rstate : state`. `0xff00` is the X11 boundary between
Latin-1/printable keysyms (`< 0x100`) and the function/keypad block (`0xFF00+`).
`waves_selected` itself strips `ShiftMask` internally, so the `over_graph` match is
Shift-insensitive regardless — but the *canvas* row must key on the same `mods` the
switch would have used, hence the per-class rule.

## 5. Why partial (per-chord) migration is safe

You do **not** have to migrate a whole key at once. Migrate plain `f` and leave
`Ctrl-f`/`Alt-f` in the switch: the dispatch finds no `{f, Ctrl, *}` / `{f, Alt, *}`
row → gate returns false → switch runs them, guards intact. Likewise the `over_graph`
rows are seeded **only for chords that already had a guard** — never broaden, or a
chord that didn't route to the graph before would start to. Migration granularity is
the (key, mods) chord, not the keysym.

## 6. Why `f` reaches the dispatch but never the switch

For plain `f`, *both* `canvas` and `over_graph` rows exist, and both resolve to a
registered action (`view.zoom_full` / `graph.forward`). `current_input_ctx` only ever
returns one of those two contexts, so `dispatch_input_action` always finds a row and
returns 1 → `handle_key_press` returns. The deleted `rstate==0` arm of `case 'f'` is
therefore dead, not merely redundant.

## 7. Proving it in both contexts

`tests/headless/test_key_graph_context.tcl` loads a schematic with a graph rect,
maps schematic→screen coordinates **live** (zooming moves the graph, so it
recomputes per event, unlike the wheel test's cached coords), and fires
`KeyPress` events for `f` (keysym 102):

- over the graph → `graph.forward` → **canvas zoom unchanged**;
- on bare canvas → `view.zoom_full` → **canvas zoom changes** (perturb it first
  with a wheel-zoom so "did full-zoom happen?" is observable).

It also asserts the data is present (`key 102 0 canvas view.zoom_full`,
`key 102 0 graph graph.forward`) and that no `Ctrl-f`/`Alt-f` rows exist. 5/5 pass,
engine harness 6/6, all GUI smokes green. `test_accelerators.tcl` still confirms
`f` has no Tcl-level `<Key-f>` bind — it reaches C via the generic `KeyPress`
handler, which now table-dispatches it.

## 8. Transferable lessons

1. **Audit purity before you hoist a call.** A predicate consulted "once per event"
   is fine only if it has no side effects; `waves_selected` did, so the dispatch had
   to be *gated*, not unconditional. The gate is the load-bearing idea here.
2. **Migrate at the granularity of the conflict** — the (key, mods) chord — so an
   un-migrated chord on the same keysym is provably untouched.
3. **Match the source's modifier convention exactly** (`rstate` for letters, raw
   `state` for named keys) — a "cleaner" uniform rule would change behavior.
4. **Seed rows only where a guard existed.** Uniformity is a bug when the source
   wasn't uniform (cf. the Ctrl-wheel lesson from c3).
5. **A dead branch left as a comment** (the `rstate==0` `f` arm) documents *where*
   the behavior went, which the next migrator needs.

## 9. Batch 2: the arrow keys — when migration is *purely additive*

`f` was deletable: both its `mods==0` contexts (canvas + over_graph) were migrated,
so the `rstate==0` arm became dead and was removed. The arrow keys are the opposite
case, and they teach the complement of lesson #5 ("seed rows only where a guard
existed"): **sometimes you keep the C branch even after migrating, because the chord
set you migrated is a strict subset of what the branch handles.**

Two wrinkles in the source:

- **`XK_Up` / `XK_Down` check no modifiers at all** — they pan under *any* state.
- **`XK_Left` / `XK_Right`** split on `state==ControlMask` (tab switch) vs `else`
  (pan under any non-Ctrl state).

So the "scroll" behavior is reachable under far more than `state==0`: Shift+Up,
Alt+Down, and — the one that bites — **lock masks** like NumLock (`Mod2Mask`) or
CapsLock, which ride along in the raw X `state` of an ordinary keypress.

The migration peels off only the **no-modifier** chord:

```c
set_input_binding(DEV_KEY, XK_Up, 0, ACTX_CANVAS,     "view.scroll_up");
set_input_binding(DEV_KEY, XK_Up, 0, ACTX_OVER_GRAPH, "graph.forward");
/* …Down/Left/Right… */
```

and **leaves the `case XK_Up:` … switch arms intact.** The gate makes this correct
for free: `kmods = (key < 0xff00) ? rstate : state` → for a named keysym it is the
*raw* state, so `NumLock+Up` has `kmods == Mod2Mask`, `key_chord_has_binding(XK_Up,
Mod2Mask)` is false, and the event falls through to the switch and pans — exactly as
before. Had we *deleted* the cases (as we did for `f`), NumLock+arrow would have
silently stopped working. The net diff for this batch is **+79 / −0**: four
`act_scroll_*` fns, four registry rows, eight binding rows, four explanatory
comments — and not one line of behavior removed.

Decision rule that falls out of `f` vs arrows:

> Delete the C branch only when the rows you seeded **cover every chord the branch
> could match**. If the branch matches a *family* of modifier states (no check, or
> "anything except X") and you migrated one member, keep the branch and let the gate
> shadow just that member.

Naming note: the arrow scroll is a *full* `CADMOVESTEP` and its sign is the historical
`xorigin += -CADMOVESTEP*zoom` etc. — which is **inverted** relative to the half-step
wheel `view.pan_*` (pressing Right moves the origin the way the wheel's `pan_left`
does). Rather than "fix" the sign or overload `view.pan_*`, the actions are new
(`view.scroll_*`) and named by the *triggering arrow*, so a binding row reads
naturally (`key <Right> 0 canvas view.scroll_right`) and the arithmetic stays
byte-for-byte.

## 10. Batch 3: the Group B routing-only sweep — two gates on *what you may delete*

Group B keys (`a`, `b`, `A`, `B`, …) keep their canvas behavior in C — opening a
dialog, toggling a Tcl var, saving a file — and migrate only the **routing**: add an
`over_graph → graph.forward` row, **no canvas row**, and delete the inline waves
guard. On the canvas the dispatch finds no row, returns 0, and falls through to the
unchanged switch branch. This is the inverse of `f` (we keep the behavior, move the
routing) and it deletes real code — six guards gone here.

But "delete the guard" is only safe under two conditions discovered while scoping,
both about *ordering and exactness*:

**(1) The semaphore-ordering trap.** `callback()` dispatches `KeyPress →
handle_key_press` with **no semaphore gate** — the per-branch `if(xctx->semaphore >=
2) break;` checks live *inside* the switch. The DEV_KEY dispatch runs at the *top* of
`handle_key_press`, i.e. **before** any of those checks. So if a branch reads

```c
if(rstate == 0) {                 /* e.g. plain 'a' = make symbol */
  if(xctx->semaphore >= 2) break; /* (A) busy-guard FIRST */
  if(waves_selected(...)) { waves_callback(...); break; }  /* (B) graph guard */
  ...
}
```

then at `sem >= 2` the old code took (A) and **never forwarded to the graph**. Hoist
(B) into the top dispatch and it now forwards at `sem >= 2` — a behavior change. So a
guard is only migratable when **no semaphore check precedes it** in its branch. `f`
and the arrows passed this by luck (their guard was first). Within Group B, the
split is real:

| Migrated now (waves-first) | Deferred (semaphore-first) |
|---|---|
| `Ctrl+a`, `A`, `Ctrl+A`, `Ctrl+b`, `B`, `Ctrl+B` | plain `a`, plain `b`, `s`, `Ctrl+s`, `Ctrl+f`, `Ctrl+r` |

The deferred ones need either a semaphore-aware dispatch or to keep their guard — a
later decision, not a silent one.

**(2) Exact chord vs family (again).** Only branches that match an *exact* chord
(`rstate == 0` or `rstate == ControlMask`) are deletable, because the `over_graph`
row I seed (`{key, 0|Ctrl, graph}`) fires for exactly the states the branch matched —
no leakage. `Ctrl+t` uses `rstate & ControlMask` (any combo *containing* Ctrl); a
single `{t, Ctrl}` row wouldn't cover `Ctrl+Alt+t`, so deleting its guard would drop
that chord's forwarding. Deferred, same as the arrows' lesson in §9.

The combined rule now reads:

> Migrate a guard to the table only if (a) nothing with different semantics runs
> before it in its branch — including a semaphore/`ui_state` check — and (b) the row
> you seed covers exactly the chord(s) the branch matched. Otherwise defer or keep
> the branch.

Note the two graph-only branches (`Ctrl+A`, `Ctrl+B`): their *entire* body was the
waves guard, so after deletion they're empty `else if` stubs (kept, with a comment) —
the cleanest possible routing migration, since there was never any canvas behavior.

Verified with boolean observables rather than dialogs: `A` (Shift+a) flips
`netlist_show`, `Ctrl+b` flips `sym_txt` — on the canvas they toggle, over a graph
they forward and leave the var untouched.

## Appendix: the change

**Batch 1 — `f` (commit `922001f5`)**

| File | What changed |
|---|---|
| `src/callback.c` | `act_zoom_full` + `view.zoom_full` registry row; `key_chord_has_binding()`; DEV_KEY dispatch atop `handle_key_press`; 2 `f` default rows; deleted the `rstate==0` guard from `case 'f'` |
| `tests/headless/test_key_graph_context.tcl` | new (5 checks): `f` over graph vs canvas, live coord mapping |
| `tests/headless/test_accelerators.tcl` | comment/label clarified: `f` routing is now data, still no Tcl bind |

**Batch 2 — arrows (commit `802b2484`)**

| File | What changed |
|---|---|
| `src/callback.c` | 4 `act_scroll_*` fns + `view.scroll_*` registry rows; 8 no-modifier arrow default rows (canvas scroll + over_graph forward); arrow switch cases **kept**, each gets a comment (purely additive, +79/−0) |
| `tests/headless/test_key_graph_context.tcl` | extended to 10 checks: Up=vertical / Right=horizontal scroll on canvas; Up over a graph leaves origin; rows present; no modified-arrow rows |
| `doc/claude/suggestions/refactor_plan_action_registry_phase3.md` | c4/c5/c6 batch-2 notes |

**Batch 3 — Group B routing sweep (commit `9033b95c`)**

| File | What changed |
|---|---|
| `src/callback.c` | 6 `over_graph → graph.forward` rows for `Ctrl+a`/`A`/`Ctrl+A`/`Ctrl+b`/`B`/`Ctrl+B`; deleted the inline waves guard from each switch branch (canvas behavior stays in C); −30 net switch lines |
| `tests/headless/test_key_graph_context.tcl` | extended to 16 checks: canvas `A` toggles netlist_show / `Ctrl+b` toggles sym_txt, over-graph both forward; rows present; no canvas rows |
| `doc/claude/suggestions/refactor_plan_action_registry_phase3.md` | c4/c5/c6 batch-3 notes |

**Batch 4 — Ctrl+arrow routing (commit `de8ca946`)**

| File | What changed |
|---|---|
| `src/callback.c` | 2 `over_graph → graph.forward` rows for `{XK_Left,Ctrl}`/`{XK_Right,Ctrl}`; deleted the waves guard from each Ctrl branch (tab-switch stays in C); the non-Ctrl else branches untouched |
| `tests/headless/test_key_graph_context.tcl` | 20 checks: Ctrl+arrow rows present / no canvas rows; canvas Ctrl+Right doesn't scroll; over a graph it forwards. Narrowed the batch-2 "no modified-arrow rows" assertion to "...CANVAS rows" |

The `Ctrl`+arrows turned out **exact** (`state == ControlMask`), not a family — so
they took the Group B delete-the-guard path, not the §9 keep-branch path. (Watch the
distinction: `Ctrl+t` next to them uses `rstate & ControlMask` and *is* a family.)
One predictable ripple: adding the over_graph routing rows broke a batch-2 test
assertion that said "no modified-arrow rows at all" — now over-broad, since
modified-arrow *routing* rows are exactly what we just added. Re-scoped it to "no
modified-arrow **canvas** rows" (the real invariant: their canvas pan/tab-switch
behavior stays in C). This is the recurring lesson from c3 restated: **scope an
assertion to what the test owns, because the next batch will add the thing the broad
version forbids.**

**Batch 5 — `t` (commit `cc673858`)**

| File | What changed |
|---|---|
| `src/callback.c` | plain `t` exact → guard deleted + `{t,0,over_graph}` row; `Ctrl+t` family → `{t,Ctrl,over_graph}` row + guard **narrowed** to `(rstate != ControlMask) && waves_selected(...)` |
| `tests/headless/test_key_graph_context.tcl` | 23 checks: `t` over_graph rows present, no canvas rows; over a graph plain `t` forwards (PLACE_TEXT stays clear). Canvas behaviors not triggered (modal placement / new tab mutate the fixture) |

The family chord here got a sharper treatment than the arrows did in §9. Instead of
keeping the *whole* guard (which would call `waves_selected` twice on the exact
chord's canvas fall-through — once in the top dispatch, once in the branch), the
guard is **narrowed to the remainder it still owns**: `(rstate != ControlMask) &&
waves_selected(...)`. The table row owns the exact `Ctrl+t`; the guard owns
`Ctrl+<anything-else>`. Rule of thumb for a family chord whose canvas behavior stays
in C: *narrow* the guard to "the states the row doesn't cover," don't just keep it.

Next: only the **semaphore-first** chords remain (plain `a`, plain `b`, `s`,
`Ctrl+s`, `Ctrl+f`, `Ctrl+r`) — their guard sits *after* `if(sem>=2) break;`, so they
need a semaphore-aware approach (a dedicated forward action, or gating the dispatch),
discussed separately before coding. Then Phase 3d: let an action id resolve to a Tcl
command, generate the cheat-sheet from `xschem bindings dump`, and delete the dead
ladders.
