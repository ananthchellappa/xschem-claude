# Phase 3d.1 — Tcl-command-backed actions (design + first migration)

**Status:** proposed. **Branch:** `feature/action-registry`. **Predecessor:** Phase 3c
(keyboard/mouse graph-routing) is migration-complete; see
`refactor_plan_action_registry_phase3.md` and
`tutorial_action_registry_phase3c_key_routing.md`.

## 1. Why this step, and why now

Phase 3d's goal is to shrink the 1600-line `handle_key_press` switch toward a thin
fallthrough by moving each key's *behavior* into the action registry. So far every
registry action is backed by a **C function** (`action_fn`). But the large majority
of the switch's command keys are not C at all — they are a single `tcleval("…")`
call (≈61 such branches inside `handle_key_press` today). Wrapping each in a
throwaway C function (`static int act_x(e){ tcleval("…"); return 1; }`) would be pure
boilerplate.

The unlock is to let an **action id resolve to a Tcl command string** run via
`tcleval`, in addition to a C function. That is plan item **d1**, and it is the
prerequisite for the bulk key migration (d2), the semaphore representation (d1b),
and generating the cheat-sheet from the table (d3).

This document scopes the *minimal* version of d1: add Tcl-backing to the registry
and **prove it end-to-end by finishing one already-half-migrated key, `B`**, which
then disappears from the switch entirely — the exact template d2 repeats.

## 2. Scope

**In scope**
- Extend the action model so an id is backed by *either* a C `fn` *or* a `tcl` string.
- Run the Tcl-backed action from the existing `dispatch_input_action` path.
- Fix the `xschem bind` validator so it accepts Tcl-backed ids (today it rejects any
  id without a C function).
- Migrate `B` (edit schematic header) fully and delete `case 'B'` from the switch.
- A headless test proving: canvas `B` runs the command; over a graph it forwards;
  `xschem bind` accepts a Tcl-backed id.

**Explicitly out of scope** (named so reviewers know they're deliberate)
- d1b semaphore-sensitivity (`idle_only`) — the 6 deferred sem-first chords.
- d2 bulk migration of the other ~60 `tcleval` keys.
- d3 cheat-sheet generation, d4 CSV loading, d5 deleting the ladders.
- Context-dependent commands (those needing mouse coords / `%`-substitution) — `B`
  is a pure global command; the substitution mechanism is a later concern (§8).
- Surfacing Tcl errors from a failed command (today's switch ignores them too).

## 3. Current state (exact)

```c
/* callback.c:2271 */
typedef struct { const char *id; action_fn fn; const char *help; } ActionDef;

/* callback.c:2273 — registry rows, all C-backed */
static const ActionDef action_registry[] = {
  { "view.zoom_in",   act_zoom_in,   "Zoom in"   },
  ... 13 rows ...
};

/* callback.c:2290 — resolves id -> C fn */
static action_fn lookup_action_fn(const char *id) { ... return fn or NULL ... }

/* callback.c:2458 — dispatch resolves + runs */
fn = lookup_action_fn(b->action_id);
return fn ? fn(e) : 0;          /* "id with no C behavior (Tcl-backed): future" */

/* callback.c:2568 — bind validation REJECTS ids with no C fn */
if(!lookup_action_fn(argv[6])) {
  Tcl_AppendResult(interp, "bind: unknown action '", argv[6], "'", NULL);
  return TCL_ERROR;
}
```

Note line 2458 already anticipated this with a comment, and 2568 is the **gotcha**:
`lookup_action_fn` returning NULL is used both as "unknown id" (reject) and would now
also mean "Tcl-backed id" (must accept). Those two meanings must be separated.

## 4. Proposed changes

### 4.1 Action model: add a `tcl` field

```c
/* An action is backed by EITHER a C function (fn) OR a Tcl command (tcl);
 * exactly one is non-NULL. Tcl-backing (Phase 3d) lets the ~60 tcleval keysym
 * branches become data without a throwaway C wrapper per command. */
typedef struct { const char *id; action_fn fn; const char *tcl; const char *help; } ActionDef;
```

Every existing row gains a `NULL` tcl slot (mechanical, ~13 rows):

```c
{ "view.zoom_in", act_zoom_in, NULL, "Zoom in" },
...
{ "graph.forward", act_graph_forward, NULL, "Forward event to the waveform graph" },
/* new, Tcl-backed: */
{ "sch.edit_header", NULL, "update_schematic_header", "Edit schematic header/license" },
```

### 4.2 Resolution: one helper, two callers updated

Replace the fn-only `lookup_action_fn` with a def lookup, so callers can check
*existence* and reach `tcl`:

```c
static const ActionDef *find_action_def(const char *id)
{
  int i;
  for(i = 0; i < num_action_defs; ++i)
    if(!strcmp(action_registry[i].id, id)) return &action_registry[i];
  return NULL;
}
```

`lookup_action_fn` then has no remaining callers and is removed (its two uses are
rewritten below).

### 4.3 Dispatch: run fn or tcl

```c
/* callback.c:2458, inside dispatch_input_action */
const ActionDef *d = find_action_def(b->action_id);
if(!d) return 0;
if(d->fn)  return d->fn(e);
if(d->tcl) { tcleval(d->tcl); return 1; }
return 0;
```

Semantics: a Tcl-backed action *always reports handled* (returns 1) once dispatched,
matching how the old switch branch unconditionally ran the `tcleval` and `break`ed.
The `ActionEvent *e` is ignored by a pure Tcl action (it carries no mouse context to
the command) — acceptable for global commands like `B`; see §8 for the limitation.

### 4.4 Bind validation: accept Tcl-backed ids

```c
/* callback.c:2568 */
if(!find_action_def(argv[6])) {   /* was: !lookup_action_fn(...) — rejected Tcl ids */
  Tcl_AppendResult(interp, "bind: unknown action '", argv[6], "'", NULL);
  return TCL_ERROR;
}
```

Still rejects genuinely unknown ids (def not found); now also accepts a valid
Tcl-backed id. No regression for C ids (their def is found).

### 4.5 Finish `B`, delete its case

`case 'B'` is currently:

```c
case 'B':
  if(rstate == 0) { tcleval("update_schematic_header"); }   /* canvas, still in C */
  else if(rstate == ControlMask) { /* empty: graph routing already data */ }
  break;
```

Add the canvas row (the over_graph row already exists from Phase 3c):

```c
set_input_binding(DEV_KEY, 'B', 0, ACTX_CANVAS, "sch.edit_header");
```

Then **delete `case 'B'` entirely**. Post-deletion routing:

| Event | Path | Result (unchanged) |
|---|---|---|
| `B` on canvas | gate → canvas row → `sch.edit_header` (tcleval) | edit header |
| `B` over graph | gate → over_graph row → `graph.forward` | forward to graph |
| `Ctrl+B` over graph | gate → over_graph row → `graph.forward` | forward to graph |
| `Ctrl+B` on canvas | gate fires (over_graph row exists) → ctx canvas → no canvas row → fall through → no `case 'B'` → default | nothing (== old empty branch) |

`B` becomes the **first key to vanish from the switch completely** — behavior fully
in the table.

## 5. Reasoning / alternatives considered

- **`tcl` field on `ActionDef` (chosen).** Minimal, single registry, reads
  naturally, and the dispatch change is three lines. The "exactly one of fn/tcl is
  non-NULL" invariant is simple to honor and check.
- **Parallel Tcl-action table.** Rejected: two registries to keep in sync, two
  lookups, more surface area for no benefit at this scale.
- **Pull the command from `actions.csv`'s `command` column.** Attractive long-term
  (single source of truth) but couples d1 to CSV loading. That unification belongs in
  **d4** (load `keybindings.csv`/`mousebindings.csv` at startup). For now the default
  Tcl-backed rows live in C next to the C-backed ones; d4 can later source them.
- **Keep wrapping each command in a C `act_` fn.** Rejected: ~60 identical
  one-line wrappers is exactly the boilerplate this step removes.

## 6. Behavior-preservation argument

- `B` canvas: old ran `tcleval("update_schematic_header")` inside the switch with no
  semaphore guard; new runs the identical string via the dispatch, which fires at the
  top of `handle_key_press` — but for `B` there was no code between function entry and
  `case 'B'` that affected it, so the timing is equivalent.
- `B`/`Ctrl+B` over graph and `Ctrl+B` canvas: already data-driven in Phase 3c;
  deleting the (now-empty / now-tcl) case does not change them (table above).
- No other key is touched. The `find_action_def` swap is behavior-identical for all
  existing C-backed ids; the bind-validation change only *widens* what's accepted.

## 7. Testing plan

Extend `tests/headless/test_key_graph_context.tcl` (or a small new file). Stub the
command so the effect is observable without opening the real dialog:

```tcl
set ::hdr_calls 0
proc update_schematic_header {} { incr ::hdr_calls }   ;# stub the real proc
# data: canvas row present, bind accepts the Tcl-backed id
check "B canvas row -> sch.edit_header" {[lsearch -exact $dump {key 66 0 canvas sch.edit_header}] >= 0}
check "bind accepts Tcl-backed id" {![catch {xschem bind key 66 0 canvas sch.edit_header}]}
# canvas B runs the command
set n $::hdr_calls; keyat $cx $cy 66
check "canvas B runs update_schematic_header" {$::hdr_calls == $n+1}
# over a graph B forwards -> command NOT run
set n $::hdr_calls; keyat $gx $gy 66
check "over-graph B forwards (command not run)" {$::hdr_calls == $n}
```

Plus the existing full regression: engine harness 6/6, all GUI smokes green.

## 8. Risks & limitations

- **Context-dependent commands.** A Tcl-backed action ignores `ActionEvent` (no mouse
  x/y, no mods). Commands that need the pointer position (place-at-cursor) can't use
  the bare `tcl` field yet. `B` is a pure global command, so it's unaffected; d2 will
  start with the pure-global subset, and a later step can add `%`-style substitution
  or a hybrid C+tcl action if needed. *Called out so d2 doesn't over-reach.*
- **Semaphore-sensitive commands.** Several `tcleval` branches sit behind
  `if(sem>=2) break;` (e.g. `n`, `Ctrl+n`). They need **d1b** (`idle_only`) before
  migrating, for the same reason the 6 deferred chords do. `B` has no semaphore guard.
- **Tcl errors.** A failing command makes `tcleval` return `TCL_ERROR`; we ignore it
  and report handled, exactly as the old switch did. Surfacing errors is a possible
  later polish, not a regression.
- **Validation widening.** `find_action_def` must still reject unknown ids — it does
  (returns NULL when no def matches); verified by an existing `test_remap`-style
  negative path if present, else add one.

## 9. How this generalizes to d2

Once landed, migrating a command key is: add a `{ "id", NULL, "<tcl command>", "help" }`
registry row, seed a `key <code> <mods> canvas → id` binding (and an `over_graph`
row if it was graph-routed), delete the switch branch. The eligible-now set is the
**pure-global `tcleval` branches with no semaphore guard**; sem-guarded ones wait for
d1b, context-dependent ones for the substitution mechanism. The switch shrinks one
deletable case at a time, exactly as `B` demonstrates.

## 10. Definition of done

- Builds clean (C89, no warnings); engine harness 6/6; all GUI smokes green.
- New checks pass: canvas `B` runs the command, over-graph `B` forwards, `xschem bind`
  accepts `sch.edit_header`.
- `case 'B'` removed from `handle_key_press`; no other behavior changes.
- Plan doc (`refactor_plan_action_registry_phase3.md`) d1 checkbox updated; a short
  tutorial note added in the established rhythm.
