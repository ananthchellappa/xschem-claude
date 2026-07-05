# Issue 0074 — Read-only enforcement gaps: three mutating `xschem` subcommands unguarded, and `set header_text`'s new reject is propagated as an uncaught Tcl error

**Opened:** 2026-07-03
**Status:** OPEN. Found by an `/code-review xhigh` sweep of branch `fluid-editing`
(workflow `wf_3fbcc32a-d1d`); all four points CONFIRMED against source. Not yet fixed.
**Severity:** MEDIUM — protection bypass + a user-visible error regression. A file-protected
(read-only) schematic can be silently mutated through three command paths that issue 0041's sweep
missed; separately, the header/license editor now throws an uncaught Tcl error on a read-only view
instead of quietly doing nothing.
**Branch:** `fluid-editing`.
**Source:** `/code-review xhigh` (findings at `scheduler.c:921`, `:652`, `:1834`, `:7764` +
`xschem.tcl:2634`).
**Affects:** `src/scheduler.c` subcommand branches `check_unique_names`, `attach_labels`,
`floaters_from_selected_inst`, and `set header_text`; `src/xschem.tcl` proc `update_schematic_header`
(:2630); the mutating cores `check_unique_names()` (token.c), `attach_labels_to_inst()` →
`place_symbol()` (actions.c), `floaters_from_selected_inst()` (select.c).
Related: [[readonly-enforcement]], issue 0041 (the enforcement sweep that established
`scheduler_readonly_reject()` but did not cover these commands — 0041 is CLOSED), issue 0051, the
action-logging thread (0061/0066).

---

## 1. Background

Issue 0041 layered read-only enforcement: `readonly_block()` at keyboard/menu altitude plus **29**
`scheduler_readonly_reject()` guards on mutating `xschem` Tcl subcommands (the Tcl-script /
command-server exposure). That sweep is CLOSED. Three mutating subcommands added/covered by the
companion action-logging work (0061/0066) never received a guard, and one command that *did* receive
one (`set header_text`) exposes a caller that does not handle the new error. All four are on the same
uncommitted branch and were surfaced together by the review.

## 2. The four defects (all CONFIRMED against source)

### 2a. `xschem check_unique_names 1` mutates a read-only schematic
`src/scheduler.c` (`check_unique_names` branch): guarded only by `if(!xctx)`. With arg `1` it calls
`check_unique_names(1)`, which in `token.c` does `xctx->push_undo()` and rewrites duplicate instance
names (`new_prop_string(...)`) + `set_modify()`. On a read-only view (Highlight menu item, a script,
or a replayed action-log line) this renames instances and pushes an undo slot with no reject.

### 2b. `xschem attach_labels` mutates a read-only schematic
`src/scheduler.c:~646` (`attach_labels` branch): only `if(!xctx)`. Calls
`attach_labels_to_inst(interactive)` → `place_symbol()` (actions.c ~2412, which guards only
`editing_symbol_view()`, never `xctx->readonly`) to create `lab_pin`/`lab_wire`/`lab_show` symbols
and `push_undo`. The newly-added `log_action_argv(...)` then records the mutation as a legitimate
replayable line.

### 2c. `xschem floaters_from_selected_inst` mutates a read-only schematic
`src/scheduler.c:~1831` (`floaters_from_selected_inst` branch): only `if(!xctx)`. Calls
`floaters_from_selected_inst()` (select.c ~1872) which does `xctx->push_undo()` + `set_modify(1)` and
rewrites each selected instance `prop_ptr` (`subst_token` `hide_texts`/`attach`), with no read-only
check anywhere in the path — and is now self-logged.

### 2d. `set header_text`'s reject is an uncaught Tcl error at its only caller
`src/scheduler.c:~7764`: the branch was correctly given
`if(scheduler_readonly_reject(interp, "set header_text")) return TCL_ERROR;` and its comment states
*"return TCL_ERROR so a caller/replay `catch`es it."* But the **sole production caller**,
`proc update_schematic_header` (`src/xschem.tcl:2630`), runs `xschem set header_text $tctx::retval`
with **no `catch`**:

```tcl
proc update_schematic_header {} {
  set tctx::retval [xschem get header_text]
  text_line {Header/License text:} 0 header
  if { $tctx::rcode ne {}} {
    xschem set header_text $tctx::retval   ;# <-- no catch; TCL_ERROR propagates
  }
}
```

So opening Properties → Edit Header/License on a read-only schematic and clicking OK raises an
**uncaught Tcl error** (background-error traceback popup) where the previous behavior was a quiet
no-op. The C author's assumption ("a caller catches it") is false for this caller.

## 3. Why 2a–2c matter (the 0041 invariant)

0041's guarantee is: a file-protected schematic cannot be mutated via the `xschem` command surface.
These three commands are reachable from menus, scripts, the command server, and — now that they
self-log — from **action-log replay**, which is the aggravating factor: a replay against a read-only
view both mutates it and re-records the mutation. The silent-no-`*`-marker behavior
(`set_modify()` `ro_suppress`, actions.c:170-174) means the user may not even see the buffer went
dirty.

## 4. Fix sketch

**2a–2c (bypass):** add the standard guard at the top of each mutating branch, before the core call
(and before `log_action*`, so a rejected op logs nothing), matching the 29 sibling guards:
```c
if(scheduler_readonly_reject(interp, "check_unique_names")) return TCL_ERROR;   /* only for arg "1" (the mutating mode) */
if(scheduler_readonly_reject(interp, "attach_labels")) return TCL_ERROR;
if(scheduler_readonly_reject(interp, "floaters_from_selected_inst")) return TCL_ERROR;
```
Note for 2a: `check_unique_names 0` is a *highlight-only* (non-mutating) probe and must stay allowed
on read-only; gate only the `argv[2]=="1"` (rename) mode.

**2d (uncaught error):** the C guard is correct; fix the caller. Either wrap the set in `catch` in
`update_schematic_header` (xschem.tcl), or gate the dialog itself on `[xschem get readonly]` so the
editor opens read-only / is suppressed. Preferred: guard the caller so the dialog can still *display*
the header on a read-only view but the write is caught (or the OK path is disabled), consistent with
"Properties opens as a viewer" from the 0041 work.

## 5. Secondary (PLAUSIBLE, same review): `attach_labels` self-logs its interactive arg
`log_action_argv(argc, argv)` records `attach_labels` verbatim, so `xschem attach_labels 1` (the
interactive dialog variant) would be logged as-is; replaying it re-invokes the modal dialog during an
otherwise non-interactive replay, diverging from / blocking the recorded session. The branch comment
already notes the interactive path is "a separate non-equivalent path" but still logs argv verbatim.
Consider logging the non-interactive form (`attach_labels` with the interactive arg normalized to 0)
or marking the interactive form no-log. Lower priority than 2a–2d.

## 6. Acceptance
1. On a read-only schematic, `xschem check_unique_names 1`, `xschem attach_labels`, and
   `xschem floaters_from_selected_inst` each reject (CIW/echo message, no mutation, no undo push, no
   log line); `check_unique_names 0` still highlights.
2. Opening the Header/License editor on a read-only schematic and clicking OK does **not** raise an
   uncaught Tcl error (quiet no-op or a clean CIW message).
3. Editable schematics: all four commands behave exactly as before.
