# 0369 — `descend_symbol()` drops `load_schematic()`'s result and reports a FAILED load as success

Status: **FILED (measured, not fixed)**
Found by: D4 Verify-C (adversary), 2026-08-10; **independently re-measured and corrected by
the D4 write-up agent** the same day.
Class: descend census. Siblings: 0251 (the reason channel this defect defeats), 0250
(`load-failed` leaves the hierarchy advanced), 0254.

## Why this issue exists

D4 built a reason channel (`xschem get descend_error`) whose documented contract is
*"empty means the last descend attempt on THIS context succeeded, or none has run"*.
This is the one path that makes that contract false: `descend_symbol()` returns **1** for a
descend whose load failed, so the channel positively asserts success.

It is a **coverage gap, not a regression** — `descend_symbol()` returned 1 unconditionally
before D4 as well. What changed is that there is now a channel to be wrong on, and that its
sibling `descend_schematic()` got the `load-failed` token **in the same commit** that
rewrote both functions.

## The code

`src/save.c:5684-5686` — the result is not bound:

```c
    ++xctx->currsch; /* increment level counter */
    load_schematic(1, sympath, 1, 1);
```

and `src/save.c:5701` `return 1;` is unconditional. `currsch` is incremented **before** the
load, so a failure leaves the editor one level down on a buffer that was never loaded.
The EMBEDDED arm at `:5651` drops the result the same way.

## Measured (fixed D4 binary, `src/xschem` built 2026-08-10 12:50:38)

The adversary's original repro was **invalid** and is corrected here — see "provenance"
below. The valid form must first prove the symbol genuinely resolved (`type=subcircuit`,
not `missing`, or `descend_missing_sym()` legitimately catches it first):

```
A1c| VALIDITY pre-delete: descend_symbol=1 err={} sch=doomed.sym
A1c| back at parent.sch currsch=0
A1c| deleted doomed.sym; exists=0
A1c| RESULT descend_symbol -> {1}
A1c| RESULT currsch 0 -> 1  sch=doomed.sym
A1c| RESULT descend_error={}
A1c| RESULT statusmsg={n=   2 x = 380  y = -20  w = 40 h = 22.5} hold=0
```

Every channel lies at once: return value `1`, `descend_error` empty (= "success"), status bar
showing a stale `select.c` info line, and the user parked at `currsch=1` on a file that does
not exist.

The sibling verb, on the byte-identical condition, is correct:

```
P5| descend (childA.sch deleted) -> 0  currsch: 0 -> 0
P5| descend_error = {missing-symbol:childA.sym}
```

### (b) It also writes a PHANTOM replayable action-log line

`src/save.c:5709` self-logs `descend_symbol` gated on reaching `return 1` — which this path
does. A replay then descends where the recording did not. The `verb_refused` gate D4 added to
the context-menu wrapper cannot help: the verb returned **1**, so `verb_refused` stays 0.

The comment at `src/save.c:5703-5707` enumerates the refusal paths as *"depth limit,
empty/multi selection, missing symbol, cancelled embedded save"* — **the load failure is
missing from that list**, which is exactly how this was overlooked.

## Provenance — read this before trusting the original report

Verify-C reported ret=1 from `scratch_D4/vc/p5.tcl`. Run **verbatim against the final
binary**, that script does *not* reproduce:

```
P5| descend_symbol -> 0  currsch: 0 -> 0
P5| descend_error = {missing-symbol:doomed.sym}
P5| statusmsg = {Descend: symbol not found: doomed.sym -- nothing to descend into} hold=1
```

Its fixture dir was never on `XSCHEM_LIBRARY_PATH`, so `doomed.sym` never resolved and the
instance's in-memory type was already `missing` — `descend_missing_sym()` catches that
correctly. The reported symptom (ret=1, `descend_error={}`, currsch advanced, empty buffer)
is exactly what sabotage variant **S6** (`#define descend_missing_sym(...) (0)`) produces, and
Verify-B's sabotage builds overlapped Verify-C's probe window. The adversary's *conclusion*
is right; its *evidence* was taken against a sabotaged binary. The transcript above replaces
it, and adds an explicit validity gate so the test cannot silently degrade into the
already-fixed missing-symbol path.

## Suggested fix

Bind the result and record `load-failed` on both arms, mirroring `descend_schematic()`:

```c
    if(!load_schematic(1, sympath, 1, 1)) {
      descend_set_error("load-failed", sympath, "Descend symbol: could not load <name>", 1);
      /* currsch was already incremented: the caller MUST go_back -- see 0250 */
      return 0;
    }
```

and extend the self-log comment's refusal list. Note the ordering hazard: `currsch` is
already incremented, so this is a `load-failed` in the 0251 sense ("the hierarchy ALREADY
ADVANCED"), **not** a refusal — the token must not be read as "nothing happened", and 0250
still has no in-tree caller that honours it.

## Related hardening, deliberately NOT applied

`hi_descend_finish`'s `set ok [xschem descend_symbol]` is **not empty-safe**: observed for
real under sabotage S4, `if {$ok}` raises `expected boolean value but got ""` and aborts
`hi_descend_do_body` mid-flight (which is how 0368 was found). `[expr {[xschem descend_symbol]
eq "1"}]` is the cheap hardening; it was left off on purpose so the S4 sabotage signal stays
sharp. Revisit if D6 (0251) is ratified and the return value becomes contractual.

## Coverage

None. No row in any suite covers a descend whose load fails after `currsch++`. A test needs
the validity gate shown above, or it degrades into the 0254 path and passes for the wrong
reason.
