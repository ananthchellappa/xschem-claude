# 0214 — `readonly` is cleared on a FAILED load, so a vanished file makes a read-only buffer writable

Status: **OPEN**. Needs **C**.
Found by: Signal Browser batch item 00 (`doc/claude/signal_browser_batch/receipts/00_precondition.md`),
split out of **issue 0186** and filed by item 16.
Related: `doc/claude/issues/0186-viewer-context-destroyed-by-reload-and-inplace-loads.md`,
`doc/claude/specs/waveform_signal_browser.md` §15.

## Symptom

A buffer that is read-only comes back **writable** after a load that **failed**. The
schematic the user was protecting is gone from the window, and the protection went with it.

## Mechanism

`load_schematic()` in `src/save.c` clears the flag in its `reset_undo` arm:

```c
xctx->readonly = 0; /* default editable; raised below ... */
```

and only *afterwards* opens the file:

```c
if( fd == NULL) {
  fprintf(errfp, "load_schematic(): unable to open file ...");
  ...  /* alert_ {Unable to open file: %s} */
  ...
  clear_drawing();
```

So the order is **clear the flag, then discover the file is not there**. The "raised below"
comment is accurate for the success path — the read-only decision is made from the file
that was just opened — but there is no such decision on the failure path, and nothing puts
the flag back.

Grep anchors (deliberately phrases, not line numbers — those rot):

* the reset: `xschem->readonly = 0; /* default editable` → `grep -n 'readonly = 0; /\* default editable' src/save.c`
* the failure test: the `if( fd == NULL) {` immediately preceding the
  `load_schematic(): unable to open file` `fprintf`
* the failure-path `clear_drawing();` inside that block (the success-path twin is a few
  lines below)

## Repro (headless, from issue 0186 §1)

```
before  ro=1
<remove or rename the file under the buffer, then trigger a reload/load of the same path>
after   ro=0
```

Measured under `--nogui`, so this is **not** viewer-specific and not DISPLAY-specific.
**Any** read-only buffer whose backing file has been removed, renamed or made unreadable
comes back editable.

## Why it is filed rather than fixed

It needs **C**, and the batch that found it (`doc/claude/signal_browser_batch/PLAN.md`)
carries settled decision 8: **no new C code**. The batch's discipline for a real defect
found in scope is *find it, file it, route around it* — the same treatment issues 0212 and
0213 got.

## Suggested direction

Do not clear `xctx->readonly` until the file has actually been opened, i.e. move the reset
below the `fd == NULL` bail, or save and restore it across the failure path. The failure
path already calls `clear_drawing()`; whatever it leaves behind should keep the protection
the user had, because a buffer whose file has vanished is *more* in need of it, not less.

Note that the failure path also pops a **modal `alert_`** — 0186 measured that under a real
DISPLAY this is what makes a reload on a waveform viewer *hang* rather than merely blank.
A fix here should not assume the failure path is quiet.

## Relationship to 0186

0186 is "a viewer's context is destroyed by reload and in-place loads". This defect was
found while measuring that one, is independent of the viewer, and is separable — hence the
split. 0186 remains OPEN on its own merits.
