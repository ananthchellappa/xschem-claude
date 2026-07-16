# Choosing what to migrate onto a refactor boundary: the friction analysis behind Refactor B atom 12

*Prepared 2026-07-16 on branch `fluid-editing`. Companion to
`action_log_coverage_audit_and_core_selflog_refactor.md` (which records the boundary's design in §4
and every landed migration in §21–§31). This document captures a question that arose **between** atoms
11 and 12 — "which verb do we migrate next, and why is that not an arbitrary choice?" — and the
systematic answer we produced. It is written to teach a method, not just to record a decision.*

---

## 1. Background: the boundary and its implicit contract

Refactor B is a long-running, one-verb-at-a-time refactor. Its goal is to funnel every mutating editor
command in `scheduler.c` through a single function, `perform_action(verb, argc, argv)`, so that two
properties — "was this command read-only-checked?" and "was this command logged?" — stop being
per-command checklist items (which drift, and did drift, repeatedly) and become *structural invariants*
that hold by construction. Each migration is a self-contained "atom": it moves one verb onto the boundary,
proves the output is unchanged, and locks the new invariant with a grep guard and a runtime test.

The boundary, as it exists after atom 11, has a specific and *deliberately simple* shape:

```c
int perform_action(const char *verb, int argc, const char *argv[]) {
  if(!xctx) { /* not available */ return TCL_ERROR; }
  if(scheduler_readonly_reject(interp, verb)) return TCL_ERROR;   /* ONE readonly gate  */
  rc = run_core(verb, argc, argv);                                /* ONE effect         */
  if(!actionlog_suppress) core_log_action(verb, argc, argv);      /* ONE log site       */
  Tcl_ResetResult(interp);
  return rc;
}
```

Read that carefully, because the whole of this document follows from two lines:

- **The readonly gate is all-or-nothing per verb.** It rejects the command whenever the schematic is
  read-only, *regardless of the arguments*. There is no "reject this form but allow that form."
- **The log fires unconditionally, after the effect, ignoring the return code.** `core_log_action`
  runs whether `run_core` mutated anything, whether it succeeded, or whether it quietly did nothing.

These two lines are the boundary's **contract**. They are pleasant and minimal — but they are also a set
of *assumptions about the call sites*. A call site can only be moved behind the boundary "for free" —
that is, with byte-identical behaviour and no change to the boundary itself — if it already honours those
assumptions. The central lesson of this analysis is:

> **A refactoring boundary is not a universal adapter. It encodes assumptions about the code it absorbs.
> Migrating a call site is cheap exactly when the site already satisfies those assumptions, and expensive
> — or wrong — when it does not. Before migrating, you check the fit; you do not discover the misfit in
> production.**

## 2. The concern that triggered this analysis

After atom 11 (`attach_labels`) landed, the obvious "next" candidate on our running shortlist was
`reset_inst_prop` (resets an instance's property string from its symbol template). It *looks* like a
clean mutating verb. But reading its source revealed a structural mismatch with the boundary's contract:

```c
else if(!strcmp(argv[1], "reset_inst_prop")) {
  if(!xctx) { ... return TCL_ERROR; }
  if(scheduler_readonly_reject(interp, "reset_inst_prop")) return TCL_ERROR;
  if(argc < 3) {                                   /* <-- returns BEFORE mutating   */
    Tcl_SetResult(interp, "... needs 1 more argument", TCL_STATIC);
    return TCL_ERROR;
  }
  if((inst = get_instance(argv[2])) < 0 ) {        /* <-- returns BEFORE mutating   */
    Tcl_SetResult(interp, "... instance not found", TCL_STATIC);
    return TCL_ERROR;
  }
  xctx->push_undo();                               /* the effect starts here        */
  ...
}
```

`reset_inst_prop` has **argument-validation paths that fail before any mutation happens**. Under the
boundary's contract — "log unconditionally after the effect" — a call like `xschem reset_inst_prop
bogus_instance` would be *rejected by validation but still logged*, producing a phantom command in the
replayable action log that does nothing (or errors) on replay. That is a regression the boundary would
*introduce*, not remove.

There are two honest ways forward, and naming them precisely is the point:

1. **Extend the boundary** so the log fires only on success (`if(rc == TCL_OK && !actionlog_suppress)
   core_log_action(...)`). This is a principled change — it makes the boundary tolerate *validating*
   verbs as a class, unblocking `reset_inst_prop`, `replace_symbol`, `load_backup`, and every future
   verb that checks its arguments. But it is a change to shared machinery, and shared-machinery changes
   deserve their own scrutiny (does any already-migrated verb rely on the unconditional log? — the bare
   verbs never fail, so no; but you must *check*, not assume).

2. **Find a verb that already fits the current contract exactly** — one that always mutates, always
   logs, always succeeds — and migrate that instead, keeping atom 12 purely additive with zero risk to
   the shared boundary. Defer the boundary extension to a later, deliberately-scoped atom.

The user asked the sharp question: *is there such a friction-free verb at all, or are we forced to touch
the boundary?* Answering that responsibly means not guessing — it means classifying **every** verb
against a precise definition of "friction-free." That classification is the body of this document.

## 3. The six criteria for a "friction-free, always-succeeds" verb

We distilled the boundary's contract into six binary criteria. A verb is friction-free only if it passes
**all six**. Each criterion corresponds to a concrete failure mode we had already hit (or reasoned our
way to), and we name the verb that taught us each one — because a criterion with a worked example is a
criterion a future engineer can actually apply.

| # | Criterion | The friction it avoids | Taught by |
|---|-----------|------------------------|-----------|
| 1 | **Always-mutating** — no argument value yields a read-only-*safe* (query/highlight/print-only) form | The all-or-nothing gate would **over-reject** a legitimate read-only query on a read-only cell | `check_unique_names` (its `rename=0` form is a pure duplicate-refdes highlight — a read-only-legal query) |
| 2 | **Unconditional log** — the site logs its command unconditionally | The boundary's unconditional `core_log_action` would **phantom-log** a case the original deliberately suppressed | `change_elem_order` (`if(had_sel) log(...)`), `add_pin_stubs` (`if(added>0)`) |
| 3 | **Always-succeeds** — no semantic argument/precondition check returns `TCL_ERROR` *before* the effect | Same phantom-log, but for *failed* calls: a rejected command would still be logged | `reset_inst_prop` (`argc<3`, "instance not found") |
| 4 | **Real effect verb** — a C mutation, not a dialog opener or a getter/tcl-var setter | A dialog opener has no `run_core` effect to host; a getter must never be logged as an edit | `create_instance` (opens the `ciform` dialog) |
| 5 | **Not a coordinate-store / gesture-replay form** — it does not log a coordinate replay line | These verbs *are* the replay representation; routing them through the boundary would re-log every replayed drop | `instance`, `wire`, `move_objects`, `paste`, … |
| 6 | **Core is 1:1-ish** — the C function is called only by this verb's own entry points, or is at most a *shared sub-step* that stays silent below the boundary; it must not *route other verbs* through the boundary | A shared core that logs would double-log; a core that dispatches other verbs would entangle them | `trim_wires` (a benign shared sub-step of `align`); contrast `change_elem_order`'s core, shared with `instance_number` |

A note on criterion 3 that trips people up: a bare `if(!xctx) return TCL_ERROR;` guard at the *very top*
of a branch is **not** a violation. The boundary owns that guard (it checks `!xctx` itself). Criterion 3
is about *semantic* validation — argument counts, "not found," "not in a symbol," "nothing selected as
an error" — the checks that encode "this specific request cannot be honoured" and therefore must not be
recorded as if it were.

A second subtlety worth internalising: criteria 1 and 3 are *different failure modes of the same surface
feature* — an early `return`. Criterion 1's early return produces a *successful* non-mutating result (a
query — it should be *allowed* read-only, so the gate must not reject it). Criterion 3's early return
produces a *failure* (it should not be *logged*). A verb can fail either, both, or neither, and you must
read the branch to tell which. `image` fails both (a `help` sub-argument prints usage and returns
success; `argc<3` returns an error) — it is a perfect specimen of why "it looks like an effect verb" is
never sufficient.

## 4. The method: exhaustive classification by fan-out

`scheduler.c` dispatches commands through 22 first-letter functions (`xschem_cmds_a` … `xschem_cmds_z`),
holding 279 `else if(!strcmp(argv[1], ...))` branches between them. Rather than spot-check a hunch, we
classified the whole space: one reviewer per dispatch group, each reading only its ~200-line slice, each
returning a structured verdict (`FRICTION-FREE` / `FRICTION` / `SKIP`) per mutating verb with the
decisive source lines. A synthesis pass then re-verified the survivors *from source* — because a
classifier can be wrong, and the cost of trusting an unverified "clean" label is exactly the bug we are
trying to avoid (this is the recurring "re-verify every anchor from source" discipline; the shortlist we
started atom 10 with was wrong, and it has been wrong every time we trusted it).

243 verbs were classified (the remainder being pure getters, redraws, and tcl-var setters that are not
candidates at all). This is the general shape worth remembering: **when the question is "is there any X
in this space, and if not, what is the nearest miss?", a mechanical, exhaustive pass beats intuition** —
not because intuition is useless, but because the *absence* of a clean candidate is only trustworthy when
the search was complete, and the taxonomy of *near misses* is itself the deliverable that tells you what
to build next.

## 5. Findings

**Exactly three verbs are friction-free**, and only one is a genuine forward step:

| Verb | Friction-free? | Verdict |
|------|:--------------:|---------|
| `toggle_ignore` | yes | **Recommended → MIGRATED (atom 12, DONE 2026-07-16).** Bare, always-mutating, no existing *branch* log, no *branch* gate, no early error, 1:1 core (branch + one key). Purely additive migration. (One §6 sub-claim was overturned on re-verify — see Status below.) |
| `show_unconnected_pins` | yes | Viable fallback. The natural sibling of atom 11's `attach_labels` — but its core wraps the *shared* sub-step `attach_labels_to_inst(2)`, one more moving part to reason about. |
| `redo` | yes (technically) | Skip. It **already** carries a manual readonly gate and self-logs, so migrating it is a no-op-equivalent move with no coverage win, and it is undo-family composite-adjacent. |

Everything else fell into a small number of failure families — and the *shape* of that distribution is
instructive in its own right. The overwhelmingly common disqualifier was **criterion 3** (early
`TCL_ERROR` before mutation): `apply_properties`, `apply_pin_prop`, `replace_symbol`, `reset_symbol`,
`load_backup`, `move_instance`, `recompute_inst_bbox`, and more. The next most common was **criterion 1**
(a read-only-safe form the all-or-nothing gate would over-reject): `instance_number`, `image`, `netlist`,
`drc_check`, `record_global_node`, `warning_overlapped_symbols`. Then **conditional or dialog logs**
(criterion 2/4): the `make_*` family, `embed_rawfile`. That most mutating verbs validate their arguments
first is not a defect in those verbs — it is *good* defensive programming — but it is precisely what makes
them a poor fit for a boundary whose current contract logs unconditionally. **The friction is a property
of the *interface between* the verb and the boundary, not of either one alone.**

## 6. The recommendation, and the one new wrinkle it carries

**Atom 12 should migrate `toggle_ignore`** (`xschem toggle_ignore` — sets `spice_ignore`/`verilog_ignore`/…
on the selected instances, per the current netlist mode). Verified from source:

- Branch (`scheduler.c:10387`) is nothing but a `!xctx` guard, the `toggle_ignore()` call, and
  `Tcl_ResetResult` — no early error, no conditional, no existing log or gate.
- Core (`actions.c:2997`) rebuilds the selection, pushes undo on the first selected element, and sets the
  modify flag — it owns its own undo, so the `run_core` arm must add none (the no-double-push rule).
- It is a **new log site** (coverage gain, not a byte-identical move) and the readonly gate is **purely
  additive** (branch and core have no readonly check today — a scattered 0041/0051-class gap the boundary
  closes, exactly as `floaters_from_selected_inst` did in §30).
- Because it takes no argument, its log form is the default bare `xschem %s` — no `core_log_action` arm,
  no flag-fidelity concern.

The one genuinely new decision — and the reason `toggle_ignore` is a slightly richer atom than a pure
move — is the **Shift+T key**. Unlike `attach_labels`, whose key ran a *non-equivalent* interactive
dialog and therefore correctly stayed *off* the boundary (and was marked `nolog` in the action registry),
`toggle_ignore`'s key (`act_toggle_ignore`, `callback.c:3447`) calls the *same* core with the *same*
effect, and its registry row is **not** `nolog`. An equivalent key that does not self-log is a coverage
hole. So the key should route through the boundary too — `perform_action("toggle_ignore", 0, NULL)` —
mirroring how `trim_wires`' `&` key was migrated in atom 1, with the twist that `toggle_ignore`'s key is a
*registered action* rather than a legacy switch case. That gives the key the readonly gate and the log,
and makes it consistent with the menu item, which already routes through the branch via `xschem
toggle_ignore`.

One residual behaviour to lock with a test: in a netlist mode where the ignore attribute is undefined
(`attr == NULL`), `toggle_ignore()` is a harmless no-op — but under the unconditional log it still emits
one line. That is the *correct* behaviour (idempotent and replayable, exactly the "no-op still logs"
property §30 established for `floaters`), and the test should assert it rather than treat it as a bug.

### Status (2026-07-16): atom 12 landed `toggle_ignore` — and one §6 sub-claim was overturned

Atom 12 shipped `toggle_ignore` on the boundary (full record in
`action_log_coverage_audit_and_core_selflog_refactor.md` §32). The friction-free classification held, but
re-verifying from source (the discipline lesson 5 preaches) **overturned §6's "the key is a coverage
hole" sub-claim.** The Shift+T key was NOT unlogged/ungated:

- It was **already read-only-gated** — its registry `ActionDef` carries `mutates=1`, and
  `dispatch_input_action()` checks `action_id_mutates(id) && readonly_block()` *before* calling the handler.
- It was **already logged** — dispatch's Layer A emits `d->log_cmd` (`"xschem toggle_ignore"`, from
  actions.csv, not-`nolog`) once the handler reports the event handled.

So routing the key through the boundary was a **consistency** move (unify the log onto `core_log_action`),
not a coverage add — and its correctness rests on the `actionlog_cmd_logged` dedup (the boundary's
`log_action` sets the flag, so the Layer A copy skips → exactly one line). `mutates=1` was **kept** so the
key stays blocked-before-handler on read-only; removing it would let the Layer A fallback phantom-log a
*refused* edit. The genuine coverage gap — and the purely additive win — was the menu/script **branch**,
which had NEITHER a gate NOR a log. Lesson reinforced: a scout's *headline* verdict ("friction-free") can be
right while a *supporting* claim ("the key is a hole") is wrong; both must be re-verified from source, because
they justify different parts of the change.

## 7. Lessons for the engineer who reads this next

1. **Every boundary has a contract; migration is a fit check against it.** When you build a funnel that
   many call sites will pass through, write down what the funnel *assumes* about those sites (here: always
   mutates, always logs, always succeeds). Then migration stops being "move the code" and becomes "prove
   the site satisfies the contract." Misfits surface at the desk, not in the log.

2. **Prefer an additive atom to a shared-machinery change — until the shared change pays for a whole
   class.** We could have extended the boundary to log-on-success for `reset_inst_prop`. Instead we
   found a verb that fits today, kept atom 12 zero-risk, and left the boundary extension as its own future
   atom that will unblock *every* validating verb at once. Sequence the cheap, isolated win before the
   powerful, entangled one — and when you do take the entangled one, scope it so its blast radius is a
   named class of beneficiaries, not an accident.

3. **When you need to prove a negative ("is there *any* clean candidate?"), search exhaustively and keep
   the taxonomy of misses.** The three friction-free verbs are the answer to the immediate question. The
   *distribution* of why the other 240 failed — mostly early-validation, then read-only-safe forms — is
   the more durable output: it tells us the single highest-leverage boundary improvement is log-on-success
   (it reclaims the largest failure family), and it tells the next scout where *not* to look.

4. **Two failure modes can wear the same syntactic clothes.** An early `return` can mean "this is a legal
   read-only query" (criterion 1 — must be *allowed*) or "this request is invalid" (criterion 3 — must not
   be *logged*). Only reading the branch tells you which. "It looks like an effect verb" is never a
   classification; the body is.

5. **Re-verify from source; classifiers and shortlists lie.** Every prior atom that trusted an
   unverified "clean candidate" list paid for it. The fan-out classified, but the synthesis re-read the
   survivors, and this document cites line numbers you should re-check before acting — they drift as the
   tree moves.

---

*Cross-references: the boundary's design and the 1:1 test live in
`action_log_coverage_audit_and_core_selflog_refactor.md` §4; the migrations that established the
patterns cited above are §21 (`trim_wires`, the shared-sub-step lock), §29 (`break_wires`, the flag verb),
§30 (`floaters_from_selected_inst`, the boundary-adds-the-gate pattern and the no-op-still-logs property),
and §31 (`attach_labels`, the shared-core-plus-flag verb and the non-equivalent-key decision that
`toggle_ignore` inverts).*
