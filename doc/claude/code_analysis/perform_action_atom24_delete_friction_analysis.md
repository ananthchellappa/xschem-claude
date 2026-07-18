# The atom-24 re-scout: choosing `delete`, and how log-on-success reshaped the candidate space

*Prepared 2026-07-17 on branch `fluid-editing`. Companion to
`perform_action_boundary_migration_friction_analysis.md` (the atom-12-era friction analysis) and to
`action_log_coverage_audit_and_core_selflog_refactor.md` (which records the boundary's design in §4 and
every landed migration in §21–§43). The atom-12 document proved a **negative** — that only three
"friction-free" verbs existed under the boundary's original contract. Eleven atoms later that contract has
changed twice, the additive pool the old scout found is exhausted, and the question returns in a new form:
**under today's boundary, what is the lowest-friction un-migrated mutating verb, and why is `delete` it?**
This document is the fresh exhaustive re-scout and the analysis behind atom 24.*

---

## 1. Why re-scout at all — the contract moved under us

The atom-12 scout classified 243 mutating verbs against a boundary whose contract was, verbatim,
"always mutates, always logs, always succeeds." Under that contract the overwhelming disqualifier was
**criterion 3** (an early `TCL_ERROR` before mutation would be phantom-logged), which knocked out the
entire class of *validating* verbs — verbs that check their arguments before acting, which is most of them.

That contract is gone. Three pattern-expansions have landed since, and each one *retired* a failure family
the old scout treated as fatal:

| Landed | Pattern | Failure family it retired |
|--------|---------|---------------------------|
| **Atom 13** (§33) | **Log-on-success** — `if(rc==TCL_OK) core_log_action(...)` | Criterion 3. A verb that returns `TCL_ERROR` before mutating is simply not logged. Validating verbs became the *mainstream* migratable case, not the disqualified one. `reset_inst_prop`, `replace_symbol`, `embed_rawfile`, `apply_pin_prop`, `move_instance`, `reset_symbol` all rode it in. |
| **Atoms 20/23** (§40/§43) | **Query/mutate split** — a read-only-safe `help`/query sub-form kept RAW in front of the boundary; only the mutate tail routes | Criterion 1 (a read-only-safe form the all-or-nothing gate would over-reject). No longer fatal — it is a *split*, at a known cost. |
| **Atom 21** (§41) | **Log-gate flip** — a site that logged `if(had_sel)` reconciled at the boundary | Criterion 2 (conditional log). Handleable. |

So the taxonomy the atom-12 document produced is **stale as a filter**. Its *method* — exhaustive
fan-out, one reviewer per dispatch group, re-verify survivors from source — is not. We re-ran that method
against the current contract.

## 2. The contract, restated (what a candidate must fit today)

```c
int perform_action(const char *verb, int argc, const char *argv[]) {
  if(!xctx) return TCL_ERROR;                                   // boundary owns the !xctx guard
  if(scheduler_readonly_reject(interp, verb)) return TCL_ERROR; // ONE readonly gate (all-or-nothing per verb)
  rc = run_core(verb, argc, argv);                              // ONE effect
  if(rc == TCL_OK) {                                            // *** LOG-ON-SUCCESS (atom 13) ***
    if(!actionlog_suppress) core_log_action(verb, argc, argv);  // ONE log site
    Tcl_ResetResult(interp);                                    // clear on success; preserve error msg on failure
  }
  return rc;
}
```

**Hard disqualifiers (a verb is not a candidate at all):**

- **D1 — already migrated** (atoms 1–23) or the verb is `text` (the drop-funnel already logs it; a shared
  sub-step of `create_graph`/`place_sym_pins`, disqualified on a prior source scout).
- **D2 — not a real object-model mutation**: a getter/query (`Tcl_SetResult`, mutates nothing), a
  tcl-var setter, a redraw/pan/zoom-only command, or a **dialog opener** (pops a Tk dialog and returns; the
  edit happens later via a different logged verb).
- **D3 — coordinate-store / gesture-replay form**: the verb *is* the replayable representation of an
  interactive drop/drag (reads x/y from `argv`, stores geometry). Routing it re-logs every replay.
- **D4 — routes other verbs / broad composite**: the core dispatches other verbs, or the verb is a
  composite of other verbs (fails the 1:1 test — `save`/`load`/`copy`/`cut`).

**Soft friction (still a candidate — scored, not skipped):**

| Code | Friction | Cost |
|------|----------|------|
| `F-validate` (+1) | early `TCL_ERROR` before mutation | none — log-on-success handles it (mainstream) |
| `F-split` (+2) | an embedded read-only-safe query/help sub-form | must split it RAW in front |
| `F-condlog` (+2) | the site logs conditionally (`if(had_sel)`, `if(added>0)`) | must reconcile the gate |
| `F-shared` (+1) | the core is a benign shared sub-step of another op | stays raw below the boundary; one more moving part |
| `F-2ndentry` (+1) | a second live entry point (a key) also calls the core | that path stays raw and must not double-log |
| `F-flagarg` (+1) | the log form carries a flag/arg needing read-identical fidelity | a per-verb `core_log_action` arm |
| `F-gate` (+1) | the branch is under a `#if` (HAS_CAIRO etc.) | conditional-compile care |

The ideal atom-24 is a real C mutation whose **core owns its own undo** (so `run_core` adds none — the
no-double-push rule), with a **1:1 or benign-shared** core, no embedded query form, and the lowest total
friction. `F-validate` is expected and free.

## 3. The scout: 303 branches, 22 groups, 8 candidates

One reviewer per `xschem_cmds_[a-z]` dispatch group read only its ~200–1700-line slice and classified
every `else if(!strcmp(argv[1], ...))` branch it contained (SKIP verdicts included, so coverage is
provable). **303 branches** classified. All but **8** were D1–D4 disqualified — the great mass being
getters (`get`, `object`, `net`, `tab_list`), redraw/GC/pan verbs, tcl-var setters, dialog openers, and the
`instance`/`wire`/`line`/`rect`/`polygon`/`arc`/`text`/`paste`/`move_objects` coordinate-replay family (D3).

The eight survivors, then each re-verified **from source** by two adversarial lenses (one asking "is it a
real 1:1 mutation?", one asking "what friction did the scout miss?"), defaulting to rejection:

| Verb | Line | Scout | True | Confirmed | Note |
|------|------|:-----:|:----:|:---------:|------|
| **`delete`** | 2530 | 3 | **3** | ✅ | **winner — undo IDEAL, bare-verb log** |
| `add_pin_stubs` | 1720 | 3 | 4 | ✅ | return-value `F-condlog` (harder than `had_sel`) + `F-flagarg` |
| `check_unique_names` | 2168 | 4 | 5 | ✅ | `F-split` with an *asymmetric* twist (mode-0 is *currently logged*) |
| `cut` | 2481 | 2 | — | ❌ | **D4**: `save_selection(2)` + `delete(1)`, no 1:1 core |
| `make_sch_from_sel` | — | 3 | — | ❌ | **D2**: blocking `save_file_dialog` inside the core supplies the filename |
| `fluid_pass` | 3208 | 4 | — | ❌ | **D4** name-routes 7 internal passes + **D2** returns changed-count on success |
| `setprop` | ~10000 | 4 | — | ❌ | **D3/D4**: 8 subtypes; shape arms are the editprop replay form |
| `apply_properties` | 1365 | 5 | — | ❌ | **D3**: replay vehicle; `apply_properties_logging_decision.md` D1 *forbids* engine logging |

## 4. The winner: `delete` — full friction analysis

### 4.1 The two halves, from source

The scheduler branch (`scheduler.c:2530`):

```c
else if(!strcmp(argv[1], "delete")) {
  if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
  if(scheduler_readonly_reject(interp, "delete")) return TCL_ERROR;
  if(argc==2) {
    delete(1/*to_push_undo*/);
    log_action("xschem delete"); /* self-log at core */
  }
  Tcl_ResetResult(interp);
}
```

The core `delete(int to_push_undo)` (`select.c:684`):

- `if(to_push_undo && begin_edit("delete")) return;` — read-only backstop (issue 0041), gated so
  undo-free internal cleanups (`delete(0)`) still run.
- pins-only selections bail **before** `push_undo` (`select.c:705`) — a no-op leaves no spurious undo slot.
- **`if(to_push_undo && xctx->lastsel) xctx->push_undo();`** (`select.c:707`) — **the core owns its undo.**
- removes rects/lines/arcs/polys/texts/instances/wires, runs W3 wire maintenance, `set_modify(1)`
  (`select.c:788`), `draw()`, clears selection — then **returns `void`**.

### 4.2 Why it is the cleanest of the eight

- **Undo is IDEAL — no reconcile.** The core owns the single `push_undo`. `run_core`'s arm calls
  `delete(1)` and adds **no** `push_undo`/`draw` — exactly the no-double-push rule that governed
  `break_wires` (atom 9), `floaters` (atom 10) and `toggle_ignore` (atom 12). The two harder survivors do
  *not* share this cleanliness: `add_pin_stubs` gates its log on a **return value** (`added>0`) the boundary
  cannot re-derive, and `check_unique_names` needs a query/mutate split.
- **Real mutation, not D2/D3/D4.** It deletes the current selection and reads **no x/y coordinates** —
  it is not a coordinate-replay form (D3). It routes no other verbs and is not a composite (D4).
- **`void` return ⇒ always `TCL_OK` ⇒ always logs**, which matches log-on-success and **preserves the
  no-op-still-logs property** (§30/§32): the pins-only bail mutates nothing yet still logs one replayable
  `xschem delete` line, exactly as `floaters`/`toggle_ignore` no-ops do.
- **Bare-verb log.** No argument ⇒ `core_log_action`'s default `xschem %s` form. No per-verb log arm,
  no flag-fidelity concern (`floaters`/`toggle_ignore` precedent).

### 4.3 The friction it *does* carry (true score 3)

- **`F-validate` (+1).** The current branch acts only inside `if(argc==2)`; a call with extra args is a
  silent no-op returning `TCL_OK` today. Under log-on-success that silent no-op would **phantom-log**. The
  `run_core` arm therefore validates `argc==2` and returns `TCL_ERROR` otherwise — the same argc-gate
  pattern as `reset_inst_prop` (`argc<3`, §33). This is the **one deliberate behaviour tighten**: a
  malformed `xschem delete foo` changes from silent-OK to a rejected error. That is *correct* (a malformed
  request should not be recorded as a replayable edit) and is mainstream for the boundary.
- **`F-shared` (+1).** `delete()` is a widely shared primitive — the `cut` verb (`scheduler.c:2487`),
  three preview re-arm teardowns (`delete(0)`), `save.c`, and several `callback.c` interactive gestures all
  call it. But it **routes no verbs through the boundary** and stays RAW below it; only the `delete` *verb*
  crosses. This is precisely the `trim_wires` atom-1 sub-step rule and the `attach_labels_to_inst` atom-11
  shared-core rule. Benign.
- **`F-2ndentry` (+1).** Two **inline legacy-switch key handlers** call `delete()` directly and self-log,
  and their own comments state they *never reach the scheduler branch*:
  - `callback.c:6055` — Ctrl-X (cut): `save_selection(2); delete(1); log_action("xschem cut");`
  - `callback.c:6228` — `XK_Delete`: `delete(1); log_action("xschem delete");`
  They stay RAW and untouched. Because a key never dispatches the `xschem delete` **Tcl command**, there is
  **no double-log** — this is the identical shipped arrangement as `cut`. (The menu item `Edit > Delete`
  and any scripted `xschem delete` *do* route through the branch, and those are what atom 24 migrates.)

**No `F-split`** (no embedded query form), **no `F-condlog`** (the guard is arity, not content — it is
`F-validate`, corrected from the scout's over-score), **no `F-gate`** (the branch is ungated; the
`HAS_CAIRO` in `delete()` is internal font cleanup), **no `F-flagarg`** (fixed literal log string).

### 4.4 The sibling lesson: why `cut` fails where `delete` passes

`cut` scored the *lowest* raw friction (2) and was still **rejected (D4)**, which is the sharpest lesson of
this scout. `cut` has no dedicated core: `scheduler.c:2481` is literally `save_selection(2)` (the same
shared primitive that makes `copy` fail the 1:1 test) **plus** `delete(1)` (a *separate sibling verb*).
Migrating `cut` would entangle two other verbs' cores at the boundary. `delete`, by contrast, *is* the
1:1-enough owner of `delete()` for logging purposes — it is the verb whose name the primitive carries, and
the shared callers stay raw below. **Low raw friction is not fitness; a verb that is a composite of other
verbs fails D4 no matter how short its branch looks.**

## 5. Atom-24 migration plan (concrete)

1. **`run_core` arm** (add after the `instance_number` arm, ~`scheduler.c:970`):
   ```c
   else if(!strcmp(verb, "delete")) {
     /* Refactor B atom 24: a BARE no-arg mutating verb, the near-twin of toggle_ignore (atom 12) /
      * floaters (atom 10) -- delete() (select.c) OWNS its undo (push_undo on first mutation),
      * set_modify + draw, and returns void => always TCL_OK. So run_core adds NO push_undo/draw
      * (no-double-push rule). The ONLY friction is the arity guard: the old branch acted inside
      * if(argc==2), so a malformed `xschem delete <extra>` was a silent no-op; validate it here and
      * return TCL_ERROR so log-on-success does not phantom-log (the reset_inst_prop argc-gate, §33).
      * delete() is a benign SHARED primitive (cut verb, preview teardown, callback gestures call it
      * raw) that routes NO verbs -> stays raw below the boundary (trim_wires atom-1 sub-step rule).
      * The Ctrl-X and XK_Delete inline keys (callback.c) self-log and never reach this branch, so
      * they stay untouched -- no double-log (the cut pattern). Bare-verb log => default `xschem %s`. */
     if(argc != 2) { Tcl_SetResult(interp, "xschem delete: too many arguments", TCL_STATIC); return TCL_ERROR; }
     delete(1/*to_push_undo*/);
     return TCL_OK;
   }
   ```
2. **Branch** (`scheduler.c:2530`): replace the body with `return perform_action("delete", argc, argv);`
   — dropping the inline `scheduler_readonly_reject` and `log_action` (the boundary owns both).
3. **Keys untouched.** `callback.c:6055` (Ctrl-X) and `callback.c:6228` (XK_Delete) stay raw + self-logging.
   Confirm exactly one path fires per gesture (the legacy handler, per its own comment) so no double-log —
   the existing design already ensures this; assert it in the test.
4. **Grep guard + headless test.** Add `tests/headless/test_perform_action_delete.tcl` mirroring
   `test_perform_action_reset_inst_prop.tcl`: assert (a) `xschem delete` on a selection removes it, pushes
   exactly one undo, and emits exactly one log line; (b) the pins-only / empty no-op still logs one line
   (no-op-still-logs); (c) `xschem delete extra` returns `TCL_ERROR` and logs **nothing**; (d) a read-only
   cell rejects it. Lock the invariant with the same grep guard the other atoms use.
5. **Docs**: record atom 24 as §44 in `action_log_coverage_audit_and_core_selflog_refactor.md`; update the
   `run_core` header comment's migrated-verb list; update this file's Status.

## 6. Lessons

1. **A boundary's contract is a moving filter.** The atom-12 "friction-free" taxonomy was a *correct*
   answer to a *superseded* question. Log-on-success, the query/mutate split and the log-gate flip each
   dissolved a whole failure family. Re-scout when the contract moves; do not trust a stale taxonomy.
2. **Undo ownership is the real tiebreaker.** All three survivors are genuine mutations; `delete` wins
   because its core owns undo with nothing to reconcile, while the runners-up carry a return-value
   conditional log or an asymmetric split. When several candidates pass, prefer the one whose core already
   satisfies the no-double-push rule.
3. **Shortest branch ≠ best fit.** `cut` had the lowest raw friction and is disqualified — it is two other
   verbs' cores wearing one name. Read what the branch *calls*, not how long it is.
4. **Re-verify from source; classifiers lie.** The scout mis-scored `delete` as `F-condlog`; reading the
   branch showed the guard is arity (`F-validate`), a cheaper and different fix. The headline verdict
   ("candidate") was right while a supporting score was wrong — both had to be re-read, exactly as the
   atom-12 document's `toggle_ignore` key sub-claim was.

## Status (2026-07-17): atom 24 landed `delete`

Shipped on the boundary exactly as §5 planned — full record in
`action_log_coverage_audit_and_core_selflog_refactor.md` §44. The scout's headline held; the one correction
was the friction *composition* (`F-validate`, not `F-condlog` — the guard is arity, not content). The
`run_core` arm validates `argc==2` (the one deliberate behaviour tighten: malformed extra-arg → TCL_ERROR,
was silent-OK), calls `delete(1)` and adds no push_undo (core-owned). `test_perform_action_delete.tcl` (24
checks) + two sabotages green; the `test_selflog_grep_guard.tcl` S1 `delete branch` row updated from the old
inline `log_action` to the `perform_action` delegation. The §40 delete/cut/copy lumping was corrected: `delete`
is the migratable primitive; `cut`/`copy` stay deferred as composites. Runner-ups `add_pin_stubs` (fr 4) and
`check_unique_names` (fr 5) remain the leading candidates for atom 25.

---

*Cross-references: the boundary design and the 1:1 test — `action_log_coverage_audit_and_core_selflog_refactor.md`
§4; log-on-success — §33; the query/mutate split — §40/§43; the log-gate flip — §41; the shared-sub-step
rule — §21 (`trim_wires`); the no-op-still-logs property — §30 (`floaters`); the bare-verb log form —
§30/§32. The atom-12-era negative result and the six original criteria — `perform_action_boundary_migration_friction_analysis.md`.*
