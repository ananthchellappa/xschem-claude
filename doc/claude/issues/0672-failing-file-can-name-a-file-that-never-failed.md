# 0672 — the 0663 announcement's `Failing file:` can name a file that never failed

Status: OPEN. Filed by the 0663 crew, 2026-08-24, from its own adversary leg.
Found by: Verify-C; independently reproduced by the write-up agent.

`src/xinit.c` — `xschem_failed_source_origin()`, the `strstr(info, "(file \"")`
at the top of it.

## Measured, AFTER 0663 landed, on the shipping binary

`op_annot.tcl` in a sharedir farm containing exactly:

```tcl
error {parse failed (file "/evil/decoy.tcl" line 42) sorry}
```

Durable log line, verbatim:

```
#! STARTUP ABORTED: <farm>/xschem.tcl did not finish. Failing file: /evil/decoy.tcl line 42. Cause: parse failed (file "/evil/decoy.tcl" line 42) sorry. ...
```

`/evil/decoy.tcl` does not exist and never failed. `op_annot.tcl`, which did, is
named nowhere in the labelled field.

## Mechanism

`::errorInfo` is `<the error message>` followed by the stack frames. The extractor
scans from **byte 0** for the first `(file "`, so any occurrence inside the
*message* — which precedes every frame — wins over the real innermost frame.

Two ways to hit it, one hostile and one entirely ordinary:

1. a message that happens to contain the substring (above);
2. the **standard re-raise idiom**, measured to report `xschem.tcl` rather than
   the helper:
   ```tcl
   return -code error -errorinfo "$::errorInfo\n    (loading op_annot)" $e
   ```

A third, benign case is already documented in 0663 §4: for the ABSENT shape the
field legitimately reads `xschem.tcl line 14796` and the helper is named only in
the `Cause:` text, because the helper never opened so it has no frame. That one
is correct behaviour, not this defect — but it means **the field alone is never
sufficient**, which is why 0663 carries both halves on the line.

## The fix

Scan from the frame region, not from byte 0 — skip to the first
`\n    invoked from within` or the first line beginning `    (file ` before
searching. Frames are indented; the message is not.

## Second, smaller defect in the same function's neighbourhood

`xschem_startup_announce()`'s `cause` buffer is 512 bytes and
`xschem_first_line()` truncates into it **with no marker**. Measured with a
6000-character message: no crash, no ellipsis — a reader sees a sentence cut
mid-word with nothing saying it was cut. An `…` on truncation is two lines of C.

Also measured and **not** a defect, recorded so nobody re-tests it: the cause is
always passed as an argument, never as a format string. `error {%s %s %n %d
%99999999s}` renders literally and does not crash.

## Acceptance rows a fix must add

| row | assert |
|---|---|
| SG26 | a helper whose message contains `(file "/evil/decoy.tcl" line 42)` → `Failing file:` names the **helper**, not the decoy |
| SG27 | a helper using the `-errorinfo` re-raise idiom → `Failing file:` names the helper |
| SG28 | a >512-char first line → the durable line ends in a truncation marker, and is still exactly ONE `#! ` line |

## Severity

Low for correctness of the abort (the process still exits 1 cleanly, and the
`Cause:` text still carries the real error), **moderate for diagnosability** —
which is the entire point of 0663's announcement. A field that confidently names
the wrong file is worse than one that says nothing, because it sends the reader
to a file that is fine.

## Still open

All of it.
