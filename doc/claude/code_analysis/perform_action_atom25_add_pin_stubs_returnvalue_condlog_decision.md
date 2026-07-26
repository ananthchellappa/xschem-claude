# The return-value conditional-log decision behind Refactor B atom 25 (`add_pin_stubs`)

*Prepared 2026-07-17 on branch `fluid-editing`. Companion to
`perform_action_atom24_delete_friction_analysis.md` (the fresh re-scout that ranked `add_pin_stubs` the
fr-4 runner-up) and to `action_log_coverage_audit_and_core_selflog_refactor.md` §45 (which records the
landed migration). The atom-24 scout scored `add_pin_stubs` fr-4 and flagged a **new** boundary wrinkle it
had not met before: a log gated on the core's **return value**. This document is the decision that resolved
it — and its point is that the wrinkle **dissolved** once we asked the right question, rather than being
worked around.*

---

## 1. The wrinkle the scout found

`add_pin_stubs` (draw a wire stub + an outward `lab_pin` net-label out of each selected/unconnected pin)
is a genuine mutation whose core owns its undo. But its old scheduler branch logged **conditionally on the
core's return value**:

```c
added = add_pin_stubs(prefix, suffix, inst_prefix);   /* returns the stub count */
...
if(added > 0) log_action_argv(argc, (const char *const *)argv);   /* <-- return-value condlog */
Tcl_SetResult(interp, b /* the count */, TCL_VOLATILE);
```

Under the log-on-success boundary, `core_log_action` fires whenever `run_core` returns `TCL_OK`. It has
**no way to re-derive `added`** — unlike atom-21's `change_elem_order`, whose `had_sel` gate re-read
`xctx->lastsel` (a value still sitting in the context), `added` is a transient loop counter that is gone by
the time the log runs. So preserving the old `if(added>0)` suppression would require either changing the
core's return contract or inventing a side-channel. That is the fr-4 "return-value condlog."

## 2. The three options, named precisely

| | Option | Cost |
|---|--------|------|
| **(a)** | `run_core` returns `TCL_ERROR` when `added==0`, so log-on-success suppresses the line. | **Mis-classifies a no-op success as a failure.** `added==0` means "the selection had no unconnected pins" — a legitimately-honoured request that did nothing, not a rejected one. The Symbol-menu path would raise a Tcl error on it; and it breaks the boundary's own no-op-still-logs property. |
| **(b)** | A side-channel: `run_core` stashes `added` in an `xctx` field; `core_log_action` reads it to gate. | **New bespoke machinery for one verb**, with no precedent (atom-21's gate was re-derivable; this isn't). Grows the shared boundary to preserve a cosmetic suppression. |
| **(c)** | **Embrace no-op-still-logs.** `run_core` discards `added`, always returns `TCL_OK`; the boundary logs unconditionally on success. | The `added==0` no-op now **logs one line** (old suppressed it). Zero new mechanism. |

## 3. The question that dissolves the wrinkle

The scout scored fr-4 on the *assumption that the old `if(added>0)` suppression must be preserved.* The
decisive question is whether that assumption is even correct:

> **Is `added==0` a FAILURE, or a no-op SUCCESS?**

Read the core (`actions.c`): `add_pin_stubs` returns 0 when `collect_pin_stub_targets` finds nothing to
stub (no selection, or every pin already connected) — it *honoured* the request and correctly did nothing.
That is the **same shape** as three verbs already on the boundary, all of which **log their no-op**:

- `floaters_from_selected_inst` — nothing selected → no-op, logs (§30).
- `toggle_ignore` — `attr==NULL` in symbol mode → no-op, logs (§32).
- `delete` — nothing selected → no-op, logs (§44).

The boundary's structural rule is **log-on-success, and a no-op is a success**. A logged no-op
`xschem add_pin_stubs` line is idempotent and replays to the same no-op — exactly the §30 property. So
**option (c) is not a compromise; it is the consistent choice**, and the fr-4 friction was an artifact of
preserving a suppression the boundary had already, elsewhere, decided *not* to honour. This is the same
move the atom-24 analysis made for `delete`'s arity gate: don't preserve an incidental old behaviour that
the structural rule supersedes.

### Why (c) is safe here (the two behaviour changes, both benign)

1. **The `added==0` no-op now logs one line** (old `if(added>0)` suppressed it). Asserted as
   no-op-still-logs, not a bug — check (b) of the test.
2. **The success-path count interp-result is dropped.** The boundary's `Tcl_ResetResult` on success wipes
   the `"%d"` count the old branch returned. **Grep-verified that no caller consumes it:** the only Tcl
   caller is the Symbol-menu `-command {xschem add_pin_stubs}` (Tk discards a menu command's result), and
   the SPACE key reads the **C-function's int return** directly (`callback.c`), not the Tcl result. This is
   the `apply_pin_prop` §38 precedent (dropped `"0"/"1"` result, no consumer).
3. **The scripted verb now rejects a read-only cell** (`TCL_ERROR`) where it used to silently return `"0"`
   — a correctness fix. The boundary adds the C-level readonly gate the scripted verb never had; the core
   keeps its **own** silent `if(readonly) return 0` for the SPACE key's pan-on-decline dual-use.

## 4. What actually shipped (net friction after the decision)

With (c) the "return-value condlog" is gone, and the residual friction is small and fully precedented:

- **F-flagarg (+1):** a per-verb `core_log_action` arm emits the full flag tail
  `xschem add_pin_stubs [-prefix <s>] [-suffix <s>] [-inst-prefix]` via a fresh heap array `aps` sized to
  `argc` and `log_action_argv` (the image `im[]` template, atom 20). A `-prefix` value carrying Tcl
  metacharacters (`a[0]`) brace-quotes and replays — the issue-0048 lesson. (Not the bare
  `log_action_argv(argc, argv)` the old branch used, which recurs at `paste/...` and can't be grep-pinned.)
- **F-2ndentry (+1):** the SPACE key (`act_add_pin_stubs`) stays **raw** below the boundary — it needs the
  int return for its pan-vs-handled dual-use and logs via its registered action (Layer A), never reaching
  the branch, so it cannot double-log (the `delete`/`cut` pattern).
- **readonly gate ADDED (+0):** a correctness fix (`apply_pin_prop` §38 / `toggle_ignore` §32 precedent).

Net: a clean, precedented atom — **not** a boundary-shape change, and no side-channel.

## 5. One pre-existing issue this surfaced (filed separately, NOT bundled)

The core pushes undo **unconditionally at the top of the loop** (`actions.c`, after the early-return
guards), *before* knowing whether any target will actually be stubbed. A **late** no-op — targets exist but
every one is a nameless-empty-net skip → `added==0` — therefore fires `push_undo()` yet mutates nothing,
leaving a **spurious undo slot**. This is **pre-existing** (independent of the migration) and, under (c),
that late no-op also logs. It is filed as issue **0121** (spurious-undo-on-all-skip; fix = lazy push_undo
on the first actual store). It was deliberately **kept out of atom 25** to keep the migration additive; the
atom-25 test exercises the **early** no-op (nothing selected — no undo, no mutation) to avoid entangling
it.

## 6. Lessons

1. **A "conditional log" is only friction if the condition must be preserved.** Before building machinery
   to reproduce an old gate, ask whether the gate encodes something the boundary's structural rule already
   overrides. Here `if(added>0)` encoded "don't log a no-op" — a policy the boundary had already reversed
   for floaters/toggle_ignore/delete. The friction was in the *assumption*, not the code.
2. **Distinguish a no-op success from a failure.** They can share a return value (`0`), but they are
   different: a failure means "cannot honour this"; a no-op means "honoured, nothing to do." Only the
   former should be `TCL_ERROR` (and thus unlogged). Reading the core — not the return type — tells you
   which.
3. **Prefer the precedented additive path to new shared machinery.** Option (b) would have worked, but it
   spends boundary complexity on one verb. (c) spends nothing and makes `add_pin_stubs` consistent with
   every other no-op verb.

---

*Cross-references: the boundary design — `action_log_coverage_audit_and_core_selflog_refactor.md` §4;
log-on-success — §33; the had_sel re-derivable gate (the contrast) — §41; the no-op-still-logs property —
§30 (floaters) / §32 (toggle_ignore) / §44 (delete); the faithful-flag-tail log array — §40 (image); the
dropped-interp-result-no-consumer precedent — §38 (apply_pin_prop); the landed migration — §45. The fresh
re-scout that surfaced this candidate — `perform_action_atom24_delete_friction_analysis.md`.*
