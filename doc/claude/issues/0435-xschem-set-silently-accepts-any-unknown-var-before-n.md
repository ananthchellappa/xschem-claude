# 0435 — `xschem set <var>` silently accepts ANY unknown variable whose name sorts before `n`

Status: OPEN, measured, not fixed. Filed by the S3 RED agent (op-annotation crew,
branch `annotate`); discovered while building the S3 hierarchy-walk test fixture.

## What was measured

`scheduler.c:11686` splits the `set` dispatcher alphabetically:

```c
if(argv[2][0] < 'n') {
  if(!strcmp(argv[2], "actionlog_suppress")) { ... }
  else if(...) { ... }
  /* ...and NO final else... */
} else { /* argv[2][0] >= 'n' */
  if(!strcmp(argv[2], "netlist_name")) { ... }
  ...
  else { Tcl_SetResult(interp, "xschem set: invalid command.", ...); return TCL_ERROR; }
}
```

The `invalid command` guard exists **only in the second half**. The first half
falls off the end of its `if/else if` chain and returns `TCL_OK`. Measured on
`src/xschem` as it stands (`--nogui --pipe -q --nolog`):

```
set aaa_bogus_xyz    rc=0 e=||          <- silently accepted, does nothing
set lll_bogus        rc=0 e=||          <- silently accepted, does nothing
set mmmm_bogus       rc=0 e=||          <- silently accepted, does nothing
set modified         rc=0 e=||          <- silently accepted, does nothing
set nnn_bogus        rc=1 e=|xschem set: invalid command.|
set zzz_bogus        rc=1 e=|xschem set: invalid command.|
```

## Why it cost real time, and why it is filed against THIS step

`xschem set modified 0` is the obvious spelling for "clear the dirty flag", it
returns rc 0, and it does nothing. The real verb is `xschem set_modify 0`
(scheduler.c:12093-12124). Measured round trip:

```
m0=0                                   ; fixture freshly loaded
push_undo ; select instance 0 ; delete
m1=1                                   ; dirty
set modified 0 rc=0 e=||
m2=1                                   ; STILL DIRTY, no diagnostic
set modified 1 rc=0 e=||
m3=1
```

The S3 walk has an I4 obligation ("the walk never modifies the schematic") and a
fixture that must not leave a dirty buffer behind — a dirty buffer makes the next
`xschem load` write `<cell>~.sch`, and `go_back` then prefers that backup over the
on-disk cell (`load_backup_as`, actions.c). The S3 test suite therefore works
around this with an explicit backup-delete helper (`opa_s3_load`,
tests/headless/test_op_annot.tcl) rather than a flag reset that does not work.

This is the same failure SHAPE as issue 0432 (`xschem get no_undo` returns `{}`
with rc 0 whether the flag is 0 or 1): a getter/setter surface that answers
"fine" for a name it does not implement. 0432 is the `get` side, this is the
`set` side.

## Not fixed here

S3 is a pure-Tcl step and may not build. The fix is a one-line `else` on the
`< 'n'` branch mirroring the `>= 'n'` one — but adding it will red any caller in
the tree that has been quietly setting a misspelled variable, so it needs its own
audit (grep every `xschem set` call site whose var starts a..m) rather than a
drive-by edit.

## Open question for ratification

Should `xschem set modified <0|1>` be added as a real alias for `set_modify`, or
should it stay unimplemented and merely start erroring? The second is smaller;
the first removes the trap outright. Not decided here.
