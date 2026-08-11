# 0377 — `xschem go_back` at `semaphore != 0` is a silent no-op that records nothing on any channel

Status: **OPEN — STUB, claimed by item D5 (descend census part 2), deliberately NOT fixed there.**
Measured (transcript in the D5 baseline); split out of
[0253](0253-descend-semaphore-thresholds-disagree-and-a-zero-is-misread.md) so that 0253 can
close its *reporting* half. Filed by the D5 Planner.

## Measured

```
0253 sem=1 descend       : '0' err='busy' currsch=0
0253 sem=1 go_back 2     : '' err='busy' currsch=0     <- 'busy' is the STALE token from the
                                                          descend above; go_back recorded nothing
```

`src/scheduler.c:5620`:

```c
      if(xctx->semaphore == 0) go_back(what);
      Tcl_ResetResult(interp);
```

Three separate facts, none of them reported:

1. The branch is guarded but has no `else`, so a swallowed ascend is byte-identical to a
   performed one at every caller. `go_back` has no return value at all (`Tcl_ResetResult`),
   so even the 0/1 discrimination `descend` and `descend_symbol` gained in D4 is unavailable.
2. `go_back` is not a producer on the D4/D5 descend reason channel
   (`xschem get descend_error`), and it does not clear it either — which is why the
   transcript above shows the *previous* verb's `busy` token being read as if it were
   go_back's own. The channel's "empty means the last attempt succeeded" contract is
   maintained only by `descend_clear_error()` at the top of the two descend verbs.
3. The user-facing consequence: `Ctrl-E` / Edit > Pop schematic while a non-grabbing
   property dialog or a foreground simulation is up does nothing and says nothing. Same
   class as the descend refusals D4/D5 closed, on the ascend verb.

## Why D5 did not fix it

D5's brief is the descend refusals that *lie about success*. `go_back` is the ascend verb;
giving it a return value is an API change of the same shape as the one D4 spent its R3
ratification on for `descend_symbol`, and D5 already carries one R3 (0250's refuse-before-push).
D5's `hier_traversal` / PDK repair deliberately keys off the **`currsch` delta** rather than
go_back's (absent) result, so it is correct whether or not this is ever fixed.

## Suggested fix

Mirror the `descend` branch exactly: evaluate to `1`/`0`, and on the guarded arm record
`descend_set_error("busy", NULL, "Pop: not while a dialog or a simulation is running", 1)`
(or a sibling `ascend_err` if the channel should not be shared). Audit the ~7 in-tree
`xschem go_back` callers first — most are `while {[xschem get currsch]}` drain loops that
would spin forever if go_back silently no-ops, which is a second, worse symptom of the same
hole.

## Coverage

None. Nothing in `tests/headless/` drives `go_back` at a nonzero semaphore.
