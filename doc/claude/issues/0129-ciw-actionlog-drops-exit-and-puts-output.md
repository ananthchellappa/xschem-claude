# 0129 — CIW action log drops the `exit` command line and `puts` console output

**Status: FIXED** (2026-07-20, fluid-editing; two serial mini-batch fixes in src/ciw.tcl, each its
own builder crew + a reviewer pass — "no issues"). Found from a real `/tmp/Xschem.log.3` transcript
where a user typed `set a 10`, `set b 20`, `puts [expr $a + $b]` (printed `30` in the CIW), then
`#= 30` and `exit` — and neither the `30` output nor `exit` reached the log. Teaching write-up:
`doc/claude/code_analysis/ciw_actionlog_transcript_tutorial.md`.

## Fix applied

- **Fix A (`exit`)** — `ciw_exec` now records an exit/quit command with `xschem log_action -noecho
  $cmd` BEFORE the eval (`if {[regexp {^(exit|quit)(\s|$)} $cmd]} {...}`, guard placed just before
  `set code [catch {uplevel #0 $cmd} res]`). Line-buffered stream flushes on the newline, so the
  line is on disk before Tcl's `exit` kills the process. `cmd_logged` is set, so the tail block
  never duplicates it if a `exit` somehow returns.
- **Fix B (`puts`) + ordering** — `ciw_capture_puts` now BUFFERS console output into
  `::ciw_out_pending` (result/error kinds) instead of writing it immediately, and a new helper
  `ciw_log_outcome $code $cmd $res` (split out of `ciw_exec` for headless testability) emits the
  transcript in **console order**: the COMMAND line first, then the buffered output, then the result
  — so the log reads top-to-bottom instead of output-before-command. The command line is still
  written only post-eval, preserving the failed→`# failed:` comment invariant; the `-emitted` guard
  still dedups self-logging cores, and the buffered output correctly trails a core's self-logged
  line too. The channel `else` branch stays unlogged. **Gotcha:** `ciw_capture_puts` must end with
  `return {}` — otherwise `lappend`'s return value becomes the redefined `puts`'s result, so a
  command ending in `puts` would mint a spurious `#= <list>` result line.

## Symptom

CIW session, action log open (`--logdir /tmp`). Log ended at:

```
xschem library_manager
#= 10
set a 10
#= 20
set b 20
puts [expr $a + $b]
```

`set a 10` / `set b 20` recorded their return value as `#= ` comment lines, but the `puts` output
`30` produced **no** `#= 30` line, and the subsequent `exit` command produced **no** log line at all.

## Root cause — two independent bugs, both rooted in `ciw_exec` (src/ciw.tcl:210)

`ciw_exec` records a typed command **after** evaluating it, so the file stays source-able (a failed
command is written as a `# failed:` comment, a successful one raw — comment at ciw.tcl:138-141):

```tcl
231:  set code [catch {uplevel #0 $cmd} res]        ;# EVALUATE
...
242:  if {$res ne {}} {ciw_echo $res result ; xschem log_action -result $res}   ;# result -> "#= " line
243:  if {![xschem log_action -emitted]} { xschem log_action -noecho $cmd }     ;# command line
```

### Bug A — `exit` is never logged (post-eval logging is skipped by process death)
`exit` runs Tcl's builtin during the eval at line 231 and terminates the process **before** control
reaches the log-write at line 243. The already-written lines survived (the log stream is line-buffered
— `setvbuf(actionlog_fp, NULL, _IOLBF, 0)`, util.c:405 — so each `\n`-terminated line was already
flushed), but the `exit` line was simply never written. No custom `exit` wrapper and no shutdown
flush/close of `actionlog_fp` exists (the `Tcl_Exit` calls in xinit.c are error-abort paths only).

### Bug B — `puts` console output is echoed to the pane but never file-logged
The `#= ` transcript lines come **only** from `log_action -result $res` (ciw.tcl:242), which records
the command's Tcl **return value** `$res`. `puts` returns `""`, so no `#= ` line. The visible `30`
comes from a *side effect*: during the eval `ciw_exec` redefines `puts` → `ciw_capture_puts`
(ciw.tcl:230), which routes output to `ciw_echo ... result` (ciw.tcl:181). `ciw_echo` (ciw.tcl:113)
writes **only the Tk widget** `.ciw.l.t` — it never touches the log file. So captured `puts` output
is pane-only. (This is why `set` — which *returns* its value — logs a `#= ` line but `puts` does not.)

## Fix plan (two serial mini-batches, one bug at a time; both edit src/ciw.tcl)

- **Fix A (`exit`)**: in `ciw_exec`, before the eval, detect an exit/quit command and log it via
  `xschem log_action -noecho $cmd` (line-buffered → flushed on the `\n`). Pre-eval logging is safe
  here precisely because `exit` never returns to be logged post-eval, and `exit`/`quit` is a valid,
  faithful replay line. Scope the special-case to `^(exit|quit)(\s|$)` so no other command changes
  its existing post-eval ordering.
- **Fix B (`puts`)**: in `ciw_capture_puts`, mirror the captured console text to the file — the
  normal/stdout branches via `xschem log_action -result <text>` (→ `#= `), the stderr branch via
  `xschem log_action -error <text>` (→ `#! `). Only the console branches (n==1, or 2-arg
  stdout/stderr); the file-channel fall-through (`::ciw_saved_puts`) must NOT be logged.

## Tests

NEW `tests/headless/test_ciw_actionlog_output.tcl` (25 checks, registered in run_regression.tcl
hcases). The outer test needs no log of its own; like `test_descend_log_absorb` it spawns a CHILD
`xschem --logdir` per case and inspects the child's `Xschem.log` (the plain run_regression
invocation passes no `--logdir`, so the outer process has no action log). Coverage:
- Fix B + ordering: a child runs `ciw_capture_puts` + `ciw_log_outcome` per scenario (with a
  `log_action -reset` first, as ciw_exec does) → asserts the `#= `/`#! ` lines are present AND that
  the COMMAND line comes strictly BEFORE its output/result (`set`, `puts`, `stderr`, failed-command);
  a channel puts is NOT logged.
- Faithful path: drives a real `puts HIFAITHFUL` through the actual redefine→eval→ciw_log_outcome
  sequence and asserts no spurious result line — guards the `return {}` invariant.
- Fix A: child logs `exit`/`quit` then really `exit`s → asserts the line survived the process death.
  Plus the exact classifier regexp (exit/quit/`exit 0` yes; `exithhh`/`set exit 1` no).
- Integration grep-guards on src/ciw.tcl (ciw_exec reads a Tk widget): the exit guard, the
  `lappend ::ciw_out_pending` buffering, and `ciw_log_outcome`'s command-then-output emission.

Sabotage-verified: dropping `return {}` → the spurious-result check FAILs; emitting output before the
command → the ordering checks FAIL; stripping Fix B / Fix A → their checks/grep-guards FAIL; restore
→ 25/25. Reviewer pass (5 risk areas: re-entrancy, double pane-echo, double command-log,
suppressecho, channel-else) → no issues.
