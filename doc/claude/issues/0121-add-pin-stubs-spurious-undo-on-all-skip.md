# 0121 — add_pin_stubs pushes a spurious undo slot on an all-skip no-op

**Status:** OPEN (pre-existing; surfaced by Refactor B atom 25, deliberately kept out of that migration)
**Area:** actions.c `add_pin_stubs()` / undo
**Severity:** minor (a wasted undo slot; no data corruption)

## Symptom

`add_pin_stubs()` (actions.c) pushes undo **unconditionally at the top of its loop**, *after* the
early-return guards but *before* it knows whether any target will actually be stubbed:

```c
nt = collect_pin_stub_targets(&t);
if(nt <= 0) { my_free(...); return 0; }          /* EARLY no-op: no push_undo -- correct */
...
xctx->push_undo();                                /* <-- pushed here, before the loop */
for(k = 0; k < nt; ++k) {
  ...
  if(!netname || !netname[0]) { ...; continue; }  /* nameless pin -> skip, added NOT incremented */
  ...
  ++added;
}
...
if(added) { set_modify(1); draw(); }              /* effect gated on added>0 */
return added;
```

So a **LATE no-op** — `nt > 0` (targets were collected) but every one is a nameless-empty-net skip, so
`added == 0` — has already called `push_undo()`. The result is a spurious undo slot that restores to a
state identical to the current one: pressing Ctrl-Z after such a call appears to "do nothing" (it burns one
undo step), and `set_modify` was correctly NOT set, so the two are inconsistent (an undo slot exists for a
change that never happened).

The **EARLY** no-op (`nt <= 0`: nothing selected, or every pin already connected) is correct — it returns
before `push_undo()`.

## Repro (conceptual)

Select an instance all of whose unconnected pins are **nameless** and call `xschem add_pin_stubs` with no
`-prefix`/`-suffix` (so each `netname` is empty → every target skips). `xctx->push_undo()` fired; `added`
came back 0; an undo slot now exists with no corresponding change.

## Interaction with Refactor B atom 25

Atom 25 migrated `add_pin_stubs` onto the perform_action boundary under **option (c) no-op-still-logs**
(see `doc/claude/code_analysis/perform_action_atom25_add_pin_stubs_returnvalue_condlog_decision.md` §5). A
no-op is logged as a `TCL_OK` success, so under (c) this LATE no-op now *also* emits one
`xschem add_pin_stubs` line (idempotent, replays to the same no-op — that part is fine). The spurious undo
slot, however, is orthogonal and pre-existing. It was deliberately **not** fixed in atom 25 to keep that
migration additive; the atom-25 test (`test_perform_action_add_pin_stubs.tcl`, check (b)) exercises the
**EARLY** no-op (nothing selected) so it does not depend on this behaviour either way.

## Proposed fix

Make the undo push **lazy** — defer `xctx->push_undo()` to the first *actual* store (the first target that
passes the nameless-skip guard), mirroring the `place_symbol(..., first /*first_call*/, ...)` /
`to_push_undo` lazy-undo pattern the surrounding code already uses. Then an all-skip call leaves no undo
slot (and, being a genuine no-op, its logged line stays idempotent). Guard with a test that an all-skip
`add_pin_stubs` leaves the undo depth unchanged.
