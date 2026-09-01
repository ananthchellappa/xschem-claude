# 0668 — `sig_handler` double-faults on a half-initialised `xctx`, which is why a startup crash is 139 and not `exit(1)`

Status: OPEN. Filed by the 0663 crew, 2026-08-24 (scout + Measure findings, code
shape confirmed by reading `src/main.c:32-50`).

`src/main.c:32` — `sig_handler()`. Related: `src/xinit.c:658`.

## Measured

Every 0663 crash row at HEAD reported **exit 139 / core dumped**, never the
handler's own `exit(1)`, even though `src/main.c:82` installs `sig_handler` for
`SIGSEGV`. The reason:

```c
static void sig_handler(int s){
  ...
  if(xctx->undo_type == 0 ) { /* on disk undo */
    my_snprintf(emergency_prefix, S(emergency_prefix), "xschem_emergencysave_%s_",
             get_cell(xctx->sch[xctx->currsch], 0));
```

Before `Tcl_AppInit` finishes, `xctx` is `calloc`'d: `undo_type` is 0, so the
handler takes the on-disk branch, and `xctx->sch[xctx->currsch]` is still **NULL**.
`get_cell(NULL, 0)` faults **again**, inside the SIGSEGV handler, and the default
action produces 139/core. So the famous exit-139 signature of issues 0423/0424/0663
is a **double** fault.

## Why it is still open after 0663

Issue 0663 removed the *trigger* at one call site — a failed source of
`xschem.tcl` now aborts cleanly at `src/xinit.c:3571` and never reaches the
crash. The handler itself is untouched and is still unsafe for **any** pre-init
crash. Anything else that faults before `init_done` (`src/xinit.c:3648`) gets the
same silent 139 with no emergency save and no message.

## The second half: `xinit.c:658` is deliberately still unguarded

```c
if(!strcmp(tclgetvar("undo_type"), "disk")) {
```

`tclgetvar()` returns **NULL** on a miss (`src/scheduler.c:14350`), so this is a
NULL `strcmp`. 0663's decision **D8** deliberately did not guard it: guarding it
would have masked the class instead of fixing it, and would have blurred 0663's
SAB-A sabotage variant, which must restore the exact exit-139 signature to prove
its SG1 row. The guard belongs here, with this issue.

## The fix, in two parts

1. **Make the handler survivable before init.** Early-out on a half-built
   context — `if(!init_done || !xctx || !xctx->sch[xctx->currsch]) { <report>;
   _exit(1); }` — so a pre-init fault reports and leaves with a truthful code
   instead of dying inside its own handler.
2. **NULL-guard `xinit.c:658`** (and audit its siblings): treat a missing
   `undo_type` as the documented default rather than dereferencing NULL.

## Acceptance

A deliberate pre-init SIGSEGV must exit with the handler's own code and print its
own message, not 139/core — testable with a sabotage build, since no shipped path
reaches it now that 0663 is fixed. That is the honest scope limit: **this is not
reachable from a normal build any more**, which is why it is filed rather than
fixed alongside 0663.

## Still open

All of it.
