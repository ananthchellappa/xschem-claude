# Phase 3d — bulk key migration: tutorial notes

Companion to `design_phase3d1_tcl_backed_actions.md` (the full design) and
`tutorial_action_registry_phase3c_key_routing.md` (the 3c key-routing machinery).
This file collects the *transferable lessons* per 3d step.

## d1 — Tcl-command-backed actions (commit `11744529`)

3c migrated keys whose behavior was C (each got an `act_*` function). But most of
the switch's command keys are a single `tcleval("…")` — wrapping each in a throwaway
C function would be ~60 lines of boilerplate. d1 lets an action id resolve to a Tcl
command instead.

### The model change is tiny; the gotcha was in the *validator*

The action gains a `tcl` field — "exactly one of `fn`/`tcl` is non-NULL" — and the
dispatch becomes three lines:

```c
if(d->fn)  return d->fn(e);
if(d->tcl) { tcleval(d->tcl); return 1; }
```

The non-obvious part: `xschem bind` validated an action id with
`if(!lookup_action_fn(id)) reject;`. That conflated **two different questions** —
"does this id exist?" and "does it have a C function?" — which were the same thing
until Tcl-backed ids appeared. A Tcl-backed id has *no* C function, so the old check
would have rejected a perfectly valid binding. Fix: introduce `find_action_def`
(returns the def, or NULL only when the id is truly unknown) and validate existence,
not fn-presence.

> **Lesson:** when you add a second backing kind, audit everywhere the *old* kind was
> used as a stand-in for a more general property. "Has a C fn" silently meant "is a
> real action"; splitting the model splits that meaning.

### `B` — the first case to vanish entirely

`B` was the ideal proof key because 3c had already moved its *routing* to the table,
leaving only `tcleval("update_schematic_header")` in the switch — a pure global
command, no semaphore guard, exact chord. Finishing it (register
`sch.edit_header → "update_schematic_header"`, add the canvas row) let the **entire
`case 'B'` be deleted**. That is the template d2 repeats: a key leaves the switch
once *every* chord it handled is a table row.

### Testing a Tcl-backed action without its dialog

`update_schematic_header` opens a dialog — useless in a headless test and a hang
risk. Stub it: `proc update_schematic_header {} { incr ::hdr_calls }`, then assert
the counter moves on a canvas `B` and *doesn't* on an over-graph `B` (forwarded).
Same trick will test most d2 command keys: replace the real proc with an observable
counter.

### What d1 deliberately did NOT solve (so d2 doesn't over-reach)

- **Context-dependent commands** — a Tcl action ignores the `ActionEvent`, so it
  can't pass mouse x/y. Place-at-cursor commands need a substitution mechanism or a
  C wrapper; defer.
- **Semaphore-gated commands** (`n`, `Ctrl+n`, and the 6 chords deferred from 3c) —
  need **d1b** (`idle_only`, checked before `current_input_ctx`) first.
- **`actions.csv` unification** — the default Tcl rows live in C for now; sourcing
  them from CSV is **d4**.

So d2's eligible-now set is exactly: **pure-global `tcleval` branches with no
semaphore guard.** Start there.
