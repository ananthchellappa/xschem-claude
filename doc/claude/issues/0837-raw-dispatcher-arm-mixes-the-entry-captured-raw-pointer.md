# 0837 — the `raw` dispatcher arm mixes the entry-captured `raw` pointer with the live one

**Status:** OPEN, measured, NOT fixed. Filed by the 0807+0813+0814 implement agent
(2026-08-26) as a stub, so the number cannot be re-claimed by a later crew in this run.
**Found while:** fixing 0807 / 0813 / 0814 in the same dispatcher arm. Deliberately NOT
folded in — it is a pre-existing defect with its own blast radius, and "do not silently
tidy" applies.

## 1. The capture, and the guard that runs after it

`src/scheduler.c`, the `raw` / `raw_query` arm:

```c
    else if(!strcmp(argv[1], "raw") || !strcmp(argv[1], "raw_query"))
    {
      ...
      Raw *raw = xctx->raw;          /* <-- captured HERE */
      Tcl_ResetResult(interp);
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}   /* <-- guarded HERE */
```

The `!xctx` test runs one line AFTER the dereference it is supposed to guard. Harmless
today only because every reachable caller has an `xctx`; it is the guard-after-use shape,
not a live crash.

## 2. The mixed pointers, which ARE reachable

The `raw switch` and `raw switch_back` gates both read the PRE-switch database through the
captured `raw` and the POST-switch one through `xctx->raw`, in the same condition:

```c
        if(ret && raw && raw->rawfile && raw->allpoints == 1 &&
           (!strcmp(xctx->raw->sim_type, "op") || !strcmp(xctx->raw->sim_type, "dc"))) {
          update_op();
        }
```

`raw->rawfile` / `raw->allpoints` describe the database the user switched AWAY from;
`xctx->raw->sim_type` describes the one they switched TO. Consequences:

* switching from a multi-point tran INTO a 1-point op never calls `update_op()` — the
  `raw->allpoints == 1` test asks the tran — so the schematic keeps the previous
  annotation while the current database is the op one. That is invariant I3's territory
  (the previous run's number left on screen);
* the reverse, switching from a 1-point op into a tran, passes the `allpoints` test and
  is saved only by the `sim_type` test.

## 3. Recommended fix (not applied)

Delete the entry capture, move the `!xctx` guard above everything, and ask ONE database —
`xctx->raw` — for all four fields. Then add rows to `tests/headless/test_op_annot.tcl`
(section O already owns the two-op-databases `raw switch` case, checks O37+) for the
tran -> 1-point-op direction, which nothing covers today.

## 4. Measurement provenance

The pointer mix was read out of the source by the 0807 scout and re-read by the implement
agent; the "never calls update_op()" consequence is derived from the condition, NOT yet
reproduced by a committed check. **Reproduce it before fixing it.**
