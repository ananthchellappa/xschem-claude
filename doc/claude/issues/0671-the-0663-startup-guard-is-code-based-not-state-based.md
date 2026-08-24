# 0671 — the 0663 startup guard is CODE-based, not STATE-based: a non-error early `return` still SEGFAULTS

Status: OPEN. Filed by the 0663 crew, 2026-08-24, from its own adversary leg.
Found by: Verify-C; independently reproduced by the write-up agent.

**This is the sharpest residual of 0663 and it is in 0663's own fix.**

## Measured, AFTER 0663 landed, on the shipping binary

Same sharedir farm as 0663 (`XSCHEM_SHAREDIR` symlink farm over `src/`, one entry
replaced), `--nogui --pipe -q --logdir D --script inner.tcl`:

```
### rcr EXIT=139 ALIVE=0 ANNOUNCE=0 NOSUCHVAR=10 HASHLINES=0
### rl2 EXIT=139 ALIVE=0 ANNOUNCE=0 NOSUCHVAR=10 HASHLINES=0
### ret EXIT=139 ALIVE=0 ANNOUNCE=0 NOSUCHVAR=10 HASHLINES=0
```

* `rcr` — `op_annot.tcl` contains `return -code return`
* `rl2` — `op_annot.tcl` contains `return -level 2`
* `ret` — `xschem.tcl` itself with a plausible top-level early-out prepended:
  `if {![info exists ::env(WU_NEVER_SET)]} { return }`

That is **the exact 0663 signature restored**: SIGSEGV, exit 139, ten `can't read
"<var>": no such variable` lines, **zero** announcement on stderr and **zero**
durable `#! ` lines. Compare 0663's fixed rows, same binary, same farm:
`EXIT=1 ANNOUNCE=1 NOSUCHVAR=0 HASHLINES=1`.

## Mechanism

0663 guards on the **return code**:

```c
if(source_tcl_file(name) != TCL_OK) xschem_startup_abort(name);
```

and `source_tcl_file()` only tests `Tcl_EvalFile(interp,s)==TCL_ERROR`. A
non-local `return` makes the OUTER file finish with **rc = 0**, so `Tcl_EvalFile`
returns `TCL_OK` and the guard never fires — while the rest of `xschem.tcl` was
just as thoroughly skipped as if it had raised. Verified with `tclsh` on a
two-file reproduction.

`TCL_BREAK`/`TCL_CONTINUE` are **not** exploitable this way: `Tcl_EvalFile`
converts a top-level `break`/`continue` into a real error (`invoked "break"
outside of a loop`), and both farms gave `EXIT 1` with a correct announcement.

## Why it matters more than it looks

`rcr`/`rl2` need a hostile or very odd helper. **`ret` does not.** A top-level
early `return` in `src/xschem.tcl` — a guard someone adds around a platform or
feature block — is an ordinary thing to write, and it **silently restores the
whole 0663 class**, with 0424's exact "green in-tree, dead installed" shape. No
SG row covers it.

## The fix, written out

One extra term, checking the STATE the crash actually depends on rather than the
code path that produced it. `cadlayers` is set at `src/xschem.tcl:16663`, i.e.
near the end of the file and after every bare source, and reads 22 on every clean
start (verified: `INTREE-ALIVE cadlayers=22`):

```c
if(source_tcl_file(name) != TCL_OK ||
   !Tcl_GetVar(interp, "cadlayers", TCL_GLOBAL_ONLY)) xschem_startup_abort(name);
```

Zero cost on the healthy path. The announcement's `Cause:` will be empty or stale
for the early-`return` shape, so the wording wants a branch — something like
"`xschem.tcl` finished without setting `cadlayers`; it returned early or was
truncated" — which is *more* accurate than reusing the error text.

## Acceptance rows a fix must add

| row | assert |
|---|---|
| SG22 | helper containing `return -code return` → `CHILDSTATUS 1`, one durable `STARTUP ABORTED` line |
| SG23 | helper containing `return -level 2` → same |
| SG24 | `xschem.tcl` with a top-level early `return` → `CHILDSTATUS 1`, one durable line naming `xschem.tcl` |
| SG25 | R6 fence unchanged: clean farm still exit 0, zero `#! ` lines |

## Why 0663's crew did not fix it

Only the Implement agent may build on this ~7.8 GB box, and this was found by the
adversary leg **after** Implement finished. A C change applied at write-up time
would have been unbuilt, unsabotaged and unverified — which is precisely the
"green checks, dead binary" failure mode 0663 exists to kill. Filed instead.

## Still open

All of it. This is the first thing a follow-up crew on 0663 should take.
