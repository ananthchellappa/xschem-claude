# 0830 — `simulate_bg` is undefined in a headless session, so every scripted load/netlist/save throws a Tcl error

**Status:** FIXED (this item, as a prerequisite for 0829's `FN08` row)
**Found by:** the 0827+0817+0828 crew, while making `FN08-no-tcl-diagnostics-on-an-ordinary-run`
green. It is **not** an injection defect and **not** caused by that item's changes.

## What it is

`set_modify()` (src/actions.c:213-232) unconditionally writes the per-window context vars

    set tctx::${win_path}_netlist  $simulate_bg
    set tctx::${win_path}_simulate $simulate_bg
    set tctx::${win_path}_waves    $simulate_bg

The sibling `entryconfigure` lines beside each of them are wrapped in `catch {}`; these `set`s
are not. `simulate_bg` is assigned in exactly one place — `src/xschem.tcl:15521`,
`set simulate_bg [$topwin.menubar entrycget Simulate -background]` — which only runs when a
**menubar is built**. A `--nogui` / `--pipe` session never builds one.

## Measured, on the pre-fix binary, with an ORDINARY path (no braces, no payload)

    xschem --nogui --pipe -q --nolog --script drive.tcl
      (load a 1-instance sheet, descend, go_back, netlist, saveas)
    -> tclvareval(): error executing set tctx::.drw_simulate $simulate_bg:
       can't read "simulate_bg": no such variable

One error line on stderr from a completely ordinary scripted run. Silent in the sense that
matters: the C caller ignores the eval result, so nothing downstream notices.

## Fix

A default `set simulate_bg {}` beside the other top-level defaults in `src/xschem.tcl`
(next to `set tclcmd_txt {}`). Tcl-only, no rebuild. A GUI session still overwrites it with
the real menu-entry colour at menubar-creation time, so nothing visible changes; a headless
session simply stops throwing.

Rejected: wrapping the three `set`s in `catch {}` in C — that hides the error rather than
making the read legal, and the value would still be missing.

## Acceptance

`FN08-no-tcl-diagnostics-on-an-ordinary-run` in `tests/headless/test_raw_read_dispatch.tcl`
requires ZERO `invalid command name` / `evaluation of script` / `error executing` lines from a
child run doing load + descend + go_back + netlist + saveas. That row cannot go green while
this defect is live, whatever the injection sweep does.
