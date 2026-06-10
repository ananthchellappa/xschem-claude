# Dispatcher decomposition — batch 1: scheduler letters a–c

**Status:** IMPLEMENTED (commit `7ba05ba2`); verification PARTIAL — see below. **Branch:** `refactor/dispatcher-decomposition`
(based on `feature/action-registry`).
**Method doc:** `refactor_plan_readability_discovery.md` (this is its #1 hotspot:
`xschem()` in scheduler.c, 6,775 lines, ~1,460 command branches).

## Goal

Begin splitting the monolithic `xschem()` Tcl-command dispatcher into one static
function per first-letter group, moved **verbatim**. Pure decomposition: no
behavior change, no reordering, no "improvements". The dispatcher keeps its
structure (`switch(argv[1][0])`); each case body becomes a call.

## The shape (decided from the code as it is now)

`xschem()` per-letter chains share exactly four things: `interp`, the
`cmd_found` flag, the `not_avail` message string, and (rarely, 5 uses
file-wide) a `char name[1024]` scratch buffer. Early exits `return TCL_ERROR/
TCL_OK` directly; normal completion falls through to a single epilogue
(`if(!cmd_found) "invalid command" → TCL_ERROR; return TCL_OK`).

Extraction per letter X:

```c
/* `xschem <X...>` commands, moved verbatim from xschem() (dispatcher
 * decomposition batch N). Sets *cmd_found = 0 if argv[1] matches nothing. */
static int xschem_cmds_X(Tcl_Interp *interp, int argc, const char *argv[],
                         int *cmd_found)
{
  /* chain verbatim; `cmd_found = 0` -> `*cmd_found = 0`;
     local `int i; char name[1024];` declared ONLY if the chain uses them */
  return TCL_OK;
}
```

Dispatcher case:

```c
case 'X': retcode = xschem_cmds_X(interp, argc, argv, &cmd_found); break;
```

with `int retcode = TCL_OK;` added to `xschem()` and the epilogue gaining
`if(retcode != TCL_OK) return retcode;` *before* the `cmd_found` check.
Equivalence: an early `return code` inside a branch (Tcl result already set)
propagates unchanged; normal completion returns TCL_OK with `*cmd_found = 1`
semantics preserved; no match keeps the "invalid command" path. `not_avail`
becomes a file-static above the letter functions.

Boundaries are the `case 'X': /*----*/` marker lines; the chain ends at its
`else { cmd_found = 0;} break;`. (Nested switches exist INSIDE branches — cut on
the marker comments, not on `case` tokens.)

## Batch 1 scope

Letters **a** (abort_operation…attach_labels, ~265 lines), **b** (~58, incl.
`bind`/`bindings` — covered by the binding smokes), **c** (~373, incl.
`callback` — the entry point every headless key/wheel test drives, plus
copy/cut/clear). ~700 lines move; `xschem()` shrinks accordingly. Later batches
continue alphabetically.

## Why this is safe to verify

The headless suite drives the program through this exact function: the engine
harness (load/netlist/get = letters l/n/g) plus all 11 smokes (`xschem callback`
= c, `bind/bindings/unbind` = b/u, `get/set/zoom*` …). Batch 1's letters are
among the best-covered in the file.

## Steps

1. Add `retcode` + epilogue change + `not_avail` file-static (one commit-able
   prep, inert by itself).
2. Move letter a; build; engine 6/6 + smokes. Then b, then c, same drill.
3. Commit (code), then docs. Single batch commit is fine — the per-letter moves
   are one mechanical operation.

## Rules (from the lessons doc, applied here)

- Move verbatim — keep comments, quirks, redundant `Tcl_ResetResult`s.
- Declare per-function locals only where the chain actually uses them (compiler
  confirms: C89, no warnings).
- No renames, no argument-parsing cleanup, no const-ing — that's a later, separate
  concern if ever.
- Engine 6/6 + all smokes green after every letter, not just at the end.


## Verification record (2026-06-10)

- Build clean; extracted bodies diff-proven verbatim against HEAD.
- Engine harness 6/6 PASS; display-independent smokes PASS (keybindings_help,
  mouse_bindings, gesture_bindings, binding_precedence, bindings_file — the last
  drives `xschem callback` = letter c directly, so the hot path is exercised).
- **BLOCKED:** the five display-dependent smokes (accelerators, remap — `event
  generate`; key_graph_context, graph_context, dump_file_menu) fail or hang
  because the WSLg X compositor degraded mid-session: `.drw` no longer maps
  (`winfo ismapped .drw` = 0, `focus -force` refused), and Tk silently drops
  synthesized KeyPress events on unmapped windows (effect probes read "ratio=1").
  All five reproduce IDENTICALLY at clean HEAD (`003d0d2d`) with the batch
  stashed — the regression is environmental, not this change.
- **Before batch 2:** restart WSL (`wsl --shutdown` from Windows, reopen), rerun
  the FULL suite, and only then continue with letters d+.
