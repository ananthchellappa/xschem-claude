# Phase 3d.1b — semaphore `idle_only` flag (+ migrate the sem-first chords)

**Status:** DONE (commit `c806149d`). **Branch:** `feature/action-registry`.
**Predecessors:** d1 (Tcl-backed actions), d2 batches 1-3. See the 2026-06-08 DECISION
in `refactor_plan_action_registry_phase3.md` (item d1b) and project memory
`action-registry.md`.

## Why

~75 switch branches are still gated by `if(xctx->semaphore >= 2) break;`. The top
DEV_KEY dispatch runs *before* any per-branch semaphore check, so a sem-gated chord
can't be migrated naively: it would call the side-effectful `current_input_ctx`
(`waves_selected`) and forward-to-graph at `sem>=2`, where the old code did nothing.
d1b adds a first-class **`idle_only`** property to a binding so the dispatch can skip
such a chord while the editor is busy — *before* `current_input_ctx` runs — exactly
reproducing the deleted `if(sem>=2)break;`. This unblocks the whole sem-gated set.

## The mechanism

1. `InputBinding` gains `int idle_only;`. `set_input_binding` zeroes it on the
   new-entry path; a thin `set_input_binding_idle(...)` wrapper sets it to 1 after
   seeding. (Existing rows are unchanged → idle_only 0.)
2. `key_chord_is_idle_only(code, mods)` — true if any `DEV_KEY` binding for that chord
   has `idle_only`.
3. The DEV_KEY dispatch gate (callback.c ~3066) folds the check into its condition:
   ```c
   if(key_chord_has_binding((int)key, kmods) &&
      !(xctx->semaphore >= 2 && key_chord_is_idle_only((int)key, kmods))) {
     ... dispatch ...
   }
   ```
   When idle_only **and** busy → the whole block is skipped → fall through to the
   switch, whose `if(sem>=2)break;` still applies. Checked *before* `current_input_ctx`,
   so no `waves_selected` side effect fires while busy (matching the old order).
4. Expose `idle_only` so it's settable/inspectable (needed for d3 cheat-sheet, d4 CSV
   load, and a clean test):
   - `bindings dump` appends ` idle` to idle_only rows (other rows unchanged — existing
     exact-match assertions unaffected).
   - `xschem bind <…> <id> [idle]` accepts an optional trailing `idle` token.

## The chords migrated this batch (the deferred "6", really 4)

Each branch is `if(sem>=2)break; if(waves_selected){waves_callback;break;} <canvas>`.
Migrate **only the graph routing**: an `idle_only` `over_graph → graph.forward` row,
and **delete the inline waves guard**. The `if(sem>=2)break;` and the canvas behavior
**stay in C** (these canvas ops — make-symbol dialog, merge, save, property-search —
are not table-migratable yet and are destructive to trigger in a test).

| Chord | keysym | Canvas behavior (stays in C) | Row added |
|---|---|---|---|
| plain `a` | 97, mods 0   | make symbol (dialog)        | `key 97 0 graph graph.forward idle` |
| plain `b` | 98, mods 0   | merge schematic             | `key 98 0 graph graph.forward idle` |
| `Ctrl+f`  | 102, mods C  | property search             | `key 102 ctrl graph graph.forward idle` |
| `Ctrl+s`  | 115, mods C  | save                        | `key 115 ctrl graph graph.forward idle` |

### Deferred from this batch (and why)

- **plain `s`** and **`Ctrl+r`** are *also* `cadence_compat`-gated: plain `s` simulates
  only when `!cadence_compat` (and is `snapped_wire` when `cadence_compat`); `Ctrl+r`
  simulates only when `cadence_compat`. Their `waves_selected` forward lives *inside*
  the cadence-conditioned branch, so an unconditional over_graph row would forward over
  a graph in the *wrong* mode (a behavior change). The binding table can't express
  `cadence_compat` → defer until a mode-condition mechanism exists (or leave in C).

## Behavior-preservation argument (per migrated chord)

- `sem>=2`: gate skips (idle_only) → switch → `if(sem>=2)break` → nothing. *(old: same
  break, no waves side effect.)*
- `sem<2`, over graph: gate runs → ctx OVER_GRAPH (row exists) → `graph.forward`. *(old:
  `waves_selected` true → `waves_callback`.)*
- `sem<2`, over canvas: gate runs → `current_input_ctx` (waves_selected side effect, as
  before) → CANVAS → no canvas row → fall through → canvas behavior. *(old: waves_selected
  false → canvas behavior.)*

All three preserved; the `current_input_ctx` side effect is present at `sem<2` and
absent at `sem>=2`, identical to the old code.

## Concrete steps

1. Struct field + `set_input_binding` zeroes it + `set_input_binding_idle` wrapper +
   `key_chord_is_idle_only`.
2. Fold the idle check into the DEV_KEY dispatch gate.
3. `bindings dump` appends ` idle`; `action_cmd_bind` parses optional `idle`.
4. Seed the 4 idle_only rows in `init_input_bindings`.
5. Delete the 4 inline waves guards (cases `a`, `b`, `f` Ctrl, `s` Ctrl).
6. Build (C89, no warnings).

## Testing (extend `tests/headless/test_key_graph_context.tcl`)

- **Data:** the 4 rows present with the ` idle` marker, e.g.
  `{key 97 0 graph graph.forward idle}`; a non-idle row (e.g. `{key 102 0 graph
  graph.forward}` — plain f) has **no** ` idle`.
- **The idle gate (non-destructive probe):** the 4 real chords' canvas ops are
  destructive, so prove the *gate* with a safe probe instead:
  `proc tclcmd {} { incr ::probe }` (the Tcl-backed `tools.execute_tcl_command`),
  `xschem bind key <free-key> 0 canvas tools.execute_tcl_command idle`, then
  `xschem set semaphore 0` → press → `::probe` increments;
  `xschem set semaphore 2` → press → `::probe` does **not** increment;
  reset to 0. This decisively exercises the `sem>=2 && idle_only → skip` path.
- **Regression on a non-idle chord:** confirm a non-idle migrated key (e.g. plain `f`
  zoom-full) still fires at `sem>=2` (its row isn't idle_only) — guards against the gate
  over-reaching.
- Then engine `run.sh` 6/6 and all GUI smokes green.

## Risks / watch-items

- **`xschem set semaphore`** exists (scheduler.c:5686) and `get` at :1723 — but leaving
  the semaphore at 2 would wedge later tests; always reset to 0 after the probe.
- **Dump format change** is additive (` idle` suffix on idle rows only). Re-run every
  test that greps `bindings dump` (test_key_graph_context, test_binding_precedence,
  test_remap, test_keybindings_help) — none should match the 4 new rows with an old
  pattern, but verify.
- **Don't migrate the canvas behavior** of these 4 — only the routing. The `if(sem>=2)
  break;` stays.

## Definition of done

- Builds clean; engine 6/6; all GUI smokes green.
- idle_only is a settable/dumpable binding property; the 4 chords' routing is data,
  their waves guards deleted, canvas behavior + sem guard intact.
- Test proves the idle gate (probe) + rows-present-with-idle + non-idle regression.
- Plan/tutorial/refactor-plan(d1b)/memory updated; commits split code vs docs.

## After this lands

d1b unblocks the sem-gated command keys (`*`,`&`,`>`,`<`,`?`,`/`,`!`, and letters
`n q e i j/J k/K u o …`) for fully-data migration in subsequent batches (add idle_only
canvas rows + delete the whole case). Then d3 (cheat-sheet, can now show idle), d4 (CSV
load incl. idle column + fold the C-only ids + reconcile Z/view.zoom_in), d5 (delete
ladders). The cadence_compat-gated chords (plain `s`, `Ctrl+r`) await a mode mechanism.
