# 0657 — `xschem::notify`'s `sinks` witness claimed `log` when no log file was open

Status: **FIXED** in the same pass that found it (src/ciw.tcl, `xschem::notify`).
Filed by: the 0650 write-up pass, 2026-08-23, from the adversary leg's finding.

## Why it matters more than it looks

`::xschem::notify_last`'s `sinks` field is the **only headless witness** the whole
channel has. src/ciw.tcl's own header promised: *"Returns 1 only when the text
really landed, so notify's `sinks` cannot claim a sink that was not there."* For
`log` that promise was false, and a witness that over-reports is worse than no
witness — every future "did the notice get through" assertion built on it would
pass vacuously.

## Measured, BEFORE (headless, `--nolog`, i.e. no log file exists at all)

```
actionlog_filename (--nolog)                   ''
D-c sinks claimed                              ciw log
```

Cause: `xschem log_action -result <x>` never reports a closed log
(`src/scheduler.c:7806ff`; `log_output()` in `src/util.c` silently no-ops on a
NULL `actionlog_fp`), so the `catch` around it proves only that the **call** was
well formed.

## Measured, AFTER

```
actionlog_filename (--nolog)                   ''
D-c sinks claimed                              ciw
```

and, with a log genuinely open (`--logdir`), the claim is still made and is still
true — the line really lands in the file:

```
actionlog_filename (--logdir)  '.../Xschem.log'
sinks claimed                  ciw log
--- log file lines matching --- 1
```

## The fix

The `log` claim is gated on `[xschem get actionlog_filename]` being non-empty
(the accessor already existed, `src/scheduler.c:4122`, "path of the open action
log, empty if disabled"). The write is still **attempted** unconditionally —
`&&` short-circuits left to right, so `catch {xschem log_action ...}` runs first —
only the *claim* is gated.

## Decision, ladder rung L1 (invariant I1)

One builder, two consumers. `sinks` is a consumer's evidence; a field that claims
delivery it did not verify is the silent-drift failure I1 exists to prevent.
Rejected alternative: making the C side return a status from `log_action`. That
is the more thorough fix, but it is a `.c` change on a pure-Tcl step and would
have forced a rebuild; the Tcl-side accessor gives the same answer today.

## Still open

No test yet asserts the *negative* (`log` absent under `--nolog`). `NT14` in
tests/headless/test_ase_core.tcl asserts only that neither Tk-only sink is
claimed and that nothing raises — it never read `log`, so this defect was not
covered either way. A row asserting `sinks` is exactly `ciw` under `--nolog`, and
exactly `ciw log` under `--logdir`, belongs in the next pass over that file.
