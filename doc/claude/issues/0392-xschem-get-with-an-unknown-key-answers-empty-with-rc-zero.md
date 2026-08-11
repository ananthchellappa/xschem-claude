# 0392 — `xschem get <unknown-key>` answers empty with rc 0, so a typo becomes a wrong answer

Status: **OPEN** (measured, not fixed)
Found: 2026-08-10, crew item D6 write-up agent — while repairing the 0259 gate, the first attempt
used `xschem get selection` (the real subcommand is `xschem selection`) and every gate silently
answered 0.
Area: `src/scheduler.c` — the `get` dispatcher (`:3965` onward) and its fall-through.
Related: **0259** (where it bit), **0251**/**0378** (the return-channel family: a verb that cannot
say "no" is the same defect one level up).

## The defect

```
xschem selection      -> {instance 2 1 3}        (the generic selection enumerator)
xschem get selection  -> {}    rc=0              <-- no error, no warning, just empty
```

`selection` is a top-level subcommand, not a `get` key. Asking for it through `get` returns the
empty string with a **success** return code, so a caller cannot tell "there is nothing selected"
from "you spelled the key wrong". In the 0259 repair this turned a gate that should read
`instance` into a constant 0 — i.e. a silent, total refusal — and the only reason it was caught is
that the A/B probe printed the old gate's answer beside the new one.

Every `xschem get` caller in `src/xschem.tcl` and `utils/` shares this exposure; the failure mode is
always "the feature quietly stops working", never an error.

## Fix sketch

Give the `get` dispatcher a final `else` that sets a Tcl error (`unknown get key "<k>"`) and returns
`TCL_ERROR`, the way an unknown top-level subcommand already does. Risk to weigh first: some callers
may rely on an empty answer for keys that exist only in some builds or only when a document is
loaded, so the change needs a sweep of `xschem get` call sites (and of the action-log replay, which
must not start erroring on an old log).
