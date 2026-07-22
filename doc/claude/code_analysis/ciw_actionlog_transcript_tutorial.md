# Tutorial — the CIW action-log transcript, and two ways output goes missing

A teaching walk-through built from issue 0129. Goal: understand how a command typed in the CIW
console reaches the **action log**, why two kinds of output silently never made it, and the general
lessons those bugs teach about transcript logging. Everything here is in `src/ciw.tcl`,
`src/util.c`, and `src/scheduler.c`.

## 1. What the action log is

The action log (`Xschem.log[.N]`, opened by `init_action_log()` in util.c when `--logdir` is given or
under X) is a **replayable, source-able transcript** of a session: every line is either a live
`xschem`/Tcl command or a Tcl comment. You can `source` a finished log to replay the session, and the
comments are ignored on replay. Two writer families keep that invariant (util.c):

| Call | Writes | Used for |
|---|---|---|
| `log_action(fmt,...)` / `log_action_noecho(...)` | a raw command line | the command that was run |
| `log_output(iserr, text)` | comment lines, `#= ` (result) or `#! ` (error), one prefix per physical line | command OUTPUT / results — kept as comments so replay skips them |

From Tcl these are the `xschem log_action` sub-verbs (scheduler.c ~6288): `-noecho <text>` →
`log_action_noecho`; `-result <text>` → `log_output(0,...)`; `-error <text>` → `log_output(1,...)`;
`-emitted` reads the `actionlog_cmd_logged` dedup flag; `-suppressecho 0|1` and `-suppress push|pop`
are the mirror/re-entrancy controls.

**Crucial property for this tutorial:** the stream is *line-buffered* — `setvbuf(actionlog_fp, NULL,
_IOLBF, 0)` (util.c:405). Each `\n`-terminated write is flushed to the OS immediately. So a completed
line is durable the instant it is written; nothing is lost to buffering on a later crash/exit. What
*is* lost is a line that was **never written**.

## 2. How a CIW command becomes log lines

`ciw_exec` (ciw.tcl:210) runs one console command. The skeleton (post-fix):

```tcl
ciw_echo "> $cmd" input                 ;# (1) echo INPUT to the pane (not the file)
xschem log_action -reset                ;# (2) clear the cmd_logged flag
xschem log_action -suppressecho 1       ;#     while running, a core self-log writes the FILE but
rename ::puts ::ciw_saved_puts          ;#     not the pane mirror (we already echoed the input)
proc ::puts {args} {ciw_capture_puts $args}   ;# (3) intercept puts; it BUFFERS into ::ciw_out_pending
set ::ciw_out_pending {}
if {[regexp {^(exit|quit)(\s|$)} $cmd]} { xschem log_action -noecho $cmd }   ;# (Fix A)
set code [catch {uplevel #0 $cmd} res]  ;# (4) EVALUATE the command
rename ::puts {} ; rename ::ciw_saved_puts ::puts   ;# (5) restore puts
xschem log_action -suppressecho 0
if {$code} { ciw_echo $res error } elseif {$res ne {}} { ciw_echo $res result }   ;# (6) PANE echo
ciw_log_outcome $code $cmd $res         ;# (7) FILE transcript, in console order

proc ciw_log_outcome {code cmd res} {
  if {$code} {
    if {![xschem log_action -emitted]} { xschem log_action -noecho "# failed: $cmd" }  ;# command 1st
    foreach {kind txt} $::ciw_out_pending { xschem log_action -$kind $txt }             ;# output 2nd
    xschem log_action -error $res                                                       ;# error last
  } else {
    if {![xschem log_action -emitted]} { xschem log_action -noecho $cmd }               ;# command 1st
    foreach {kind txt} $::ciw_out_pending { xschem log_action -$kind $txt }             ;# output 2nd
    if {$res ne {}} { xschem log_action -result $res }                                  ;# result last
  }
  set ::ciw_out_pending {}
}
```

Three design decisions matter:

- **Record AFTER eval.** The command line is written in `ciw_log_outcome`, called after step 4. This
  keeps the file source-able: a command that *errored* becomes a `# failed:` comment (replaying it
  would abort the `source`), a successful one is raw. The comment at ciw.tcl:138-141 spells this out.
- **Command BEFORE its output** in the file. Within `ciw_log_outcome` the command line is emitted
  *first*, then any buffered console output, then the result — so a real log reads top-to-bottom like
  the pane:
  ```
  set a 10
  #= 10
  puts [expr $a + $b]
  #= 30
  ```
  (An earlier cut of the fix emitted the result *before* the command — `#= 10` then `set a 10` — which
  read backwards; issue 0129's follow-up corrected it. See §4.)
- **`-emitted` dedup.** Many `xschem` cores already self-log during eval; `ciw_log_outcome` adds the
  command line only if one did not. Because `-reset` (step 2) clears the flag at the *start* of every
  command, the check reflects only *this* command's eval — a stale flag from the previous command
  would otherwise suppress the next command's line.

## 3. Bug A — `exit` is never written (post-eval logging meets process death)

Type `exit`. It runs Tcl's builtin at step 4 and **terminates the process**. Steps 5–7 never run, so
the command line at step 7 is never written. The earlier lines survived (line-buffered, already
flushed) — but `exit` itself simply was never logged. There is no shutdown flush/close that could
have saved it, and there is nothing *to* save: the write never happened.

> **Lesson:** "log after doing" cannot log an action that never returns. Any terminating or
> non-returning command (`exit`, `quit`, a command that `exec`s over the process, …) must be logged
> **before** it runs.

The fix (Fix A) special-cases exactly those commands — `^(exit|quit)(\s|$)` — and logs them with
`log_action -noecho` *before* the eval. Line-buffering does the rest: the line is on disk before
`exit` fires. Pre-logging is safe here precisely because these commands do not come back to be logged
post-eval, and `exit`/`quit` is a faithful replay line. Scope is deliberately tiny so no *other*
command loses its normal error-aware post-eval ordering. `cmd_logged` is set by the pre-log, so the
tail's `-emitted` guard would suppress a duplicate if an `exit` ever returned.

## 4. Bug B — `puts` output is pane-only (side-effect output vs return value)

Type `puts [expr $a + $b]`. You see `30` in the CIW. The log gets **no** `#= 30`. Why? Because the
`#= ` transcript comes *only* from the command's **return value** `$res` (step 6), and `puts` returns
`""`. The visible `30` is a **side effect**, captured on a completely different path: during the eval
`::puts` is redefined to `ciw_capture_puts` (step 3), which routes the text to `ciw_echo … result`.
And `ciw_echo` (ciw.tcl:113) writes **only the Tk widget** `.ciw.l.t` — it never touches the file.

That is the whole asymmetry: `set a 10` *returns* `10` → logged; `puts 30` *prints* `30`, *returns*
`""` → not logged.

> **Lesson:** a transcript that logs only return values misses everything a command *emits* as a side
> effect. If you capture side-effect output for display, capture it for the transcript too.

The fix (Fix B) makes `ciw_capture_puts`'s three **console** branches (single-arg, `stdout`, `stderr`)
`lappend` the text into `::ciw_out_pending` instead of writing it. `ciw_log_outcome` then flushes that
buffer to the file — *after* the command line — as `#= `/`#! ` lines. The channel `else` branch
(`puts $fh …`, a real file write, not console output) is left unlogged.

Why buffer instead of writing immediately? Because `ciw_capture_puts` runs *during* the eval, before
the command line exists in the file. Writing there is what produced the backwards `#= 30` /
`puts …` order. Buffering defers the output to `ciw_log_outcome`, where it lands after the command —
and, for a self-logging core, after that core's own command line too. (§2's "command before output".)

Two traps of "log from inside an intercepted primitive", both real here:

- **Preserve the primitive's return contract.** The real `puts` returns `""`. The redefined one must
  too — otherwise `lappend`'s return value (the growing list) becomes `puts`'s result, and a command
  whose last action is a `puts` (like `puts [expr $a+$b]`) ends with a **non-empty `$res`**, minting a
  spurious `#= <list>` result line. So `ciw_capture_puts` ends with an explicit `return {}`. This bug
  is invisible if you test `ciw_capture_puts` in isolation; it only appears when a real `puts` command
  flows through `catch {uplevel …} res` — which is why the test drives one end-to-end (§5).
- **No recursion / no double echo.** The file write goes through C `log_output` (`fputs`), which never
  calls the Tcl `puts`, so it cannot re-enter `ciw_capture_puts`; and it writes the file only — the
  pane echo is `ciw_echo`'s job, done once. `-suppressecho 1` (step 2) suppresses only the *pane
  mirror* of `log_action`, not the file write. (Do not confuse it with `-suppress` push/pop, the
  re-entrancy DEPTH COUNTER that makes a whole `log_action*` no-op during replay.)

## 5. How to test log / CIW behavior headless

CIW behaviors are awkward to test because `ciw_exec` reads a Tk text widget (`.ciw.c.e get`) that does
not exist under `--nogui`. The regression test `tests/headless/test_ciw_actionlog_output.tcl` uses
three techniques worth reusing:

1. **The procs load without Tk.** `ciw_capture_puts`, `ciw_log_outcome`, `ciw_echo` are defined at
   source time (ciw.tcl is proc-definitions + a few `set ::` inits), so they exist under `--nogui`;
   `ciw_echo` no-ops safely with no widget. Splitting the file-logging OUT of `ciw_exec` into
   `ciw_log_outcome` is what makes the *ordering* testable at all — the widget-coupled `ciw_exec` body
   can't run headless, but `ciw_log_outcome $code $cmd $res` can be called directly.
2. **Child-spawn for the file assertion.** run_regression runs headless cases with no `--logdir`, so
   the outer process has no action log. Mirror `test_descend_log_absorb`: `set bin [info
   nameofexecutable]`, then `exec $bin --nogui --pipe -q --logdir $d --script $inner`, and read the
   child's `$d/Xschem.log`. This is how Fix A's *real* property is tested — the inner logs `exit` then
   actually `exit`s and the parent asserts the line survived — and how the **faithful** puts path is
   tested: a child redefines `::puts`, evals a real `puts`, calls `ciw_log_outcome`, and the parent
   checks there is no spurious result line. That end-to-end case is essential: the `return {}` bug is
   invisible to a direct `ciw_capture_puts` call and only surfaces when a real `puts` command's `$res`
   flows through `catch`.
3. **Assert ORDER, not just presence.** Reading the raw log body and checking
   `index(command) < index(output)` is what actually pins the fix; a presence-only check passed for
   both the right and the backwards ordering.
4. **Grep-guard the un-drivable integration.** `ciw_exec`'s widget path can't run headless, so the
   test also asserts the *source* still contains the exit guard, the `lappend ::ciw_out_pending`
   buffering, and `ciw_log_outcome`'s buffer flush — cheap insurance (same discipline as the
   sky130A/gf180mcuD rc grep-guards).

Sabotage-verify pays off here: dropping `return {}` trips exactly the spurious-result check; emitting
output before the command trips the ordering checks; removing a fix trips its checks/grep-guard. If a
"fix" can be removed with the suite still green, the suite was hollow.

## 6. Takeaways

- **Order of "do" vs "record" is a correctness property, not a style choice.** Post-action logging is
  right for the source-able invariant (errors become comments) but wrong for actions that never
  return. Know which commands don't come back.
- **Return value ≠ output.** A transcript must decide, explicitly, whether it records what a command
  *returns*, what it *prints*, or both — and `puts`-style side effects travel a different path than
  `$res`.
- **Logging from inside an intercepted primitive is a recursion/echo minefield.** Route the file
  write through a path that does not re-enter the primitive (here: C stdio, not Tcl `puts`), and keep
  pane-echo and file-write as separate, single responsibilities.
- **An intercepted primitive must preserve its return contract.** Redefining `puts` to also log meant
  it had to keep returning `""`; the one-line `return {}` is the whole difference between a clean
  transcript and a spurious `#= <list>` after every `puts` command. When you wrap or replace a
  built-in, match its return value, not just its side effect.
- **A transcript's line ORDER is part of its correctness.** "Command then its output" is what a reader
  expects; emitting the result during eval (before the command line is written) reads backwards.
  Buffer side-effect output and flush it *after* the command line — and test the order, not just the
  presence, of each line.
- **Line-buffering makes "log before the dangerous call" sufficient** — no explicit flush needed, but
  the line must actually be *written* before control is lost.

Related: `doc/claude/issues/0129-ciw-actionlog-drops-exit-and-puts-output.md`,
`doc/claude/issues/0070-*` (the `#= `/`#! ` output-comment design), and the self-log-at-core /
`actionlog_suppress` machinery in
`doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md`.
