# Issue 0003 — action-log coverage holes: the stdin REPL and the TCP server

**Opened:** 2026-06-11
**Status:** OPEN — gaps identified, fix sketched, not yet implemented
**Affects:** the faithfulness/replayability of `Xschem.log` for any session
driven through a command channel OTHER than bound input or the CIW
**Branch:** `feature/action-logging`
**Related:** spec `doc/claude/specs/action_logging.md` (§2 "what gets logged"); the CIW
typed-command path (`ciw_exec`, `src/ciw.tcl`) is the model the fixes copy.

## Summary

The action log is meant to be a faithful, source-able record of "what drove
this session." Today it captures exactly two command channels:

1. **Bound input** — keys/buttons/wheel, via `dispatch_input_action()`
   (Layer A, slices 1 + 2: Tcl-backed actions log `d->tcl`, C-backed actions
   log the canonical `actions.csv` command).
2. **CIW typed commands** — via `ciw_exec`, which records the typed command
   after evaluation (raw on success, `# failed: <cmd>` on error).

There are **two other ways to feed commands to the very same Tcl interpreter**,
and NEITHER is logged. A session driven through them produces a log with just
the header — silently incomplete, which is worse than obviously empty because
it *looks* like a faithful record.

## Hole A — the stdin REPL

**What it is.** When xschem runs without taking over the terminal for the GUI
(interactive `-x`/headless use, or `--pipe`), commands typed/piped on **stdin**
are evaluated at global scope. Two underlying mechanisms:

- the **tclreadline** loop (`xinit.c:3335`, gated on `use_tclreadline &&
  !cli_opt_detach && !cli_opt_no_readline`), and
- the fallback Tcl main loop (`Tcl_SetMainLoop(tclmainloop)` at `xinit.c:3348`,
  installed when `!has_x`).

**The hole.** Whatever is read here is `eval`'d directly; nothing calls
`log_action`. A `--pipe` automation run or an interactive `-x` console session
can issue `xschem load …`, `xschem netlist`, edits, etc., and the log records
none of it.

**Why it matters.** This is the natural headless analog of the CIW — the same
"a human/script is typing commands at the interpreter" situation the CIW
already logs. The asymmetry (CIW logged, stdin not) is the bug.

## Hole B — the TCP command server

**What it is.** `--tcp_port <N>` (or `xschem_listen_port` in xschemrc) starts a
socket server: a remote program sends Tcl text, it is evaluated at global
scope, and the result is written back. Verified working against a fully
windowless instance:

```sh
xschem -x --tcp_port 19899 &
printf 'xschem get version\n'                | nc localhost 19899   # -> 3.4.8RC
printf 'set a 10; set b 32; expr {$a + $b}\n' | nc localhost 19899   # -> 42
```

The eval happens in `xschem_getdata` (`src/xschem.tcl` ~2456): it appends the
socket lines, `redef_puts`, `uplevel #0 [list catch $line tclcmd_puts]`,
restores `puts`, and writes the captured result back to the socket.

**The hole.** That `uplevel … catch` is exactly where the CIW does its
`log_action`, and here there is none. Commands arriving over TCP — which may be
the *entire* way an external tool drives the session — never reach the log.

(There is a second, separate socket, `bespice_listen_port`, dedicated to the
bespice waveform viewer. It is a fixed protocol channel, not a general command
server, and is out of scope here.)

## Fix sketch (both holes, same shape as `ciw_exec`)

Record **after** evaluation, raw on success / `# failed: <cmd>` on error, so a
replayed `source Xschem.log` never aborts (the locked source-ability rule,
spec decision 7). Results/errors stay on their own channel (terminal / socket),
never in the file.

- **Hole B (TCP)** — smallest and most clearly correct: in `xschem_getdata`,
  right after the `catch`, add the record. ~3-5 lines of Tcl reusing the
  existing `xschem log_action -noecho` / `# failed:` idiom. The command text is
  already in hand (`$xschem_server_getdata(line,$sock)`), and success/failure
  is the `catch` return code.
- **Hole A (stdin REPL)** — wrap the read-eval step so each complete command is
  recorded the same way. ~20-30 lines; trickier only because there are two loop
  mechanisms (tclreadline vs `tclmainloop`) to cover, and because line-vs-
  complete-command boundaries need `info complete` handling to avoid logging
  half a multi-line construct.

### Explicitly NOT in scope (a deliberate non-hole)

`--script` files are **one program, not a command stream** — a `foreach` is one
"line" with N effects, and the file is already a more faithful record of itself
than any line-logging could produce. Scripts that want log entries call
`xschem log_action` explicitly (that is why the subcommand exists). Do not
auto-record sourced scripts.

## Open decisions for the implementer

1. **Default on or opt-in?** The CIW and bound input log unconditionally.
   Consistency argues stdin/TCP should too — but a chatty automation client
   could bloat the log. Suggest: log unconditionally (consistent, and `--nolog`
   already exists to silence everything), revisit only if noise is reported.
2. **TCP provenance.** Consider a comment marker (e.g. `# tcp:` prefix or a
   one-time banner) so a replayed log shows which lines came from a remote
   driver vs local input. Optional; do not break source-ability.
3. **Interaction with replay fidelity.** A TCP/stdin session that issues
   non-replayable commands (clicks have no Tcl form — see spec §6) has the same
   object-reference gap as everything else; this issue does not change that.

## Acceptance

Per-channel smokes mirroring `test_ciw.tcl` / `test_action_log_dispatch.tcl`:
- TCP: connect, send a good command and a failing one, assert the log gains the
  raw command and the `# failed:` comment respectively, and that the file still
  `source`s clean.
- stdin: pipe a command via `--pipe`, assert it lands in the log; pipe a failing
  one, assert the `# failed:` comment; assert a `--script` run does NOT
  auto-log its body.
