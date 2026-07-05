# Outcome-level action logging: the select_at holding area + `descend -inst`

Status: implemented (v1, descend-only consumer). Branch `fluid-editing`.
Spec'd + built 2026-07-04.

## Problem

The action log ([[action-logging]], `doc/claude/specs/select_at.md`) records the
user's editing session as a replayable list of `xschem ...` commands. Two logging
*altitudes* exist:

- **Gesture level** — the raw input: `xschem select_at <x> <y>` (a click at a
  coordinate). Fragile: the coordinate only reproduces the same selection if the
  layout is byte-identical at replay time.
- **Outcome level** — the semantic result: `xschem descend -inst U1` (descend into
  the instance *named* U1, wherever it sits). Coordinate-free, survives layout edits.

Interactive **descend** was not replayably logged at all. The context-menu path even
logged a dead comment: `# context-menu: descend to schematic (not replayable: needs
object reference, issue 0005)`. The "object reference" it lacked is exactly an
instance *name* — which the log now carries.

The user's framing: *"when the command achieves a certain outcome, log it in a way
that achieves the same outcome."* A gesture `select_at <x> <y>` + `descend` should be
recorded as one stable line `descend -inst <name>`.

## Design

Two pieces.

### Piece 1 — EMIT the outcome (`descend -inst <name>`)

- New subcommand form **`xschem descend -inst <name> [notitle]`** (scheduler.c,
  `descend` branch): resolve `<name>` → instance via `get_instance()` (name /
  floater-hash / raw index), `unselect_all()`, `select_element()`, then the existing
  `descend_schematic()`. Self-contained: does not depend on prior selection state,
  so it is the canonical replay form.
- `descend_schematic()` (actions.c) **self-logs at the core**, so *every* descend
  path — double-click, `E` key, context-menu, `hi_descend` dialog, scripted
  `xschem descend`, and the new `-inst` form — emits the same line. The raw instname
  is captured *before* `load_schematic()` runs (after it, `xctx->inst[]` is the child
  array and the parent index `n` is stale) and logged inside `if(descend_ok)` so a
  failed/aborted descend logs nothing.
- Empty instname (rare, unnamed instance) falls back to plain `xschem descend` (which
  replays against a preceding, un-absorbed `select_at`).

### Piece 2 — ABSORB the redundant `select_at` (the holding area)

`log_action()` is a raw append; there is no line list to rewrite. So the click's
`select_at` line is **held, not written**, and a following outcome command absorbs it:

- **State** (globals.c): `char actionlog_pending[300]` (the held line, `""` = none)
  + `int actionlog_pending_inst` (the instance that click selected, or `-1`).
- **Stash** — `log_action_stash_select_at(x, y, add, inst)` (util.c). Both the
  interactive selection funnel (`select_object()`, select.c) and the scripted
  `xschem select_at` command route here instead of writing. A prior held line flushes
  first, so at most one select_at is ever pending.
- **Flush** — `log_action_flush_pending()` (util.c) is called at the **top of
  `log_action()`**, so any other logged action commits the held select_at ahead of
  itself (order preserved). It clears the slot *before* re-logging, so no recursion.
- **Absorb** — `log_action_descend(inst_n, name)` (util.c): if a held select_at
  selected this same instance, **discard it** and log `descend -inst <name>` alone;
  otherwise the held line flushes normally in front of the descend line.

```
user: click U1 (funnel stash) ; press E (descend core)
log:  xschem descend -inst U1          <- one stable line; select_at absorbed
```

## Coverage / mechanism summary

| Path | select_at source | descend log |
|------|------------------|-------------|
| click + `E` key | funnel stash | core self-log, absorbs |
| double-click | funnel stash | core self-log, absorbs* |
| context-menu "descend to schematic" | funnel stash | core self-log, absorbs |
| `hi_descend` dialog | funnel stash | core self-log, absorbs |
| scripted `xschem select_at` + `xschem descend` | command stash | core self-log, absorbs |
| scripted `xschem descend -inst U1` | (none) | core self-log, stands alone |

\* a double-click that re-selects on the second press flushes the first select_at
(overwrite-flush) and absorbs the second, so it may leave one residual select_at line.
The staged click-then-`E` flow (the user's scenario) is always clean.

## Edge cases / decisions

- **Overwrite-flush, not overwrite-replace.** A second stash flushes the first
  (never lost). Replace would be cleaner for consecutive plain clicks but would drop
  the base of an additive shift-click multi-select. Flush is the safe rule.
- **Scripted `select_at` is deferred one action.** Its log line now lands after the
  *next* logged command (or at absorb time), not immediately. A trailing lone select
  with nothing after it, and no other action before process exit, is lost from the log
  (there is no `fclose(actionlog_fp)` hook to flush on exit). Low value, accepted.
- **Replay guard.** Stash/flush/absorb all respect `actionlog_suppress`; when logging
  is off they are no-ops.

## Extensibility — the door for other verbs

`descend` is the only consumer today. Any other "select then act" outcome is wired the
same way: add a `log_action_<verb>(inst_n, ...)` that absorbs a matching held select_at
then logs its own stable line, and self-log at that verb's core. Candidates:
`delete`, `copy`, `move`, `hilight`. Piece 2 (the holding area) is already general;
only the per-verb absorb+emit is new each time.

## Files

- `src/globals.c`, `src/xschem.h` — `actionlog_pending[]`, `actionlog_pending_inst`.
- `src/util.c`, `src/util.h` — `log_action_stash_select_at`,
  `log_action_flush_pending`, `log_action_descend`; flush hook in `log_action()`.
- `src/select.c` — `select_object()` funnel stashes.
- `src/scheduler.c` — `descend -inst <name>` form; scripted `select_at` stashes.
- `src/actions.c` — `descend_schematic()` captures instname + self-logs the outcome.

## Test

`tests/headless/test_descend_log_absorb.tcl` (run_regression `hcases`). Spawns child
xschem runs with `--logdir` and inspects the resulting `Xschem.log`:
absorb (one `descend -inst` line, no select_at), name-addressed replay reproduces the
end state (currsch/schname), not-found errors cleanly, overwrite-flush + absorb, and
a missed select + descend logs nothing.
