# CIW — capture `puts` output into the log pane

## Motivation

The CIW command entry evaluates a typed command and echoes its **return value** to the log pane
(`ciw_exec`: `if {$res ne {}} {ciw_echo $res result}`). It never looks at what the command writes
to the `stdout`/`stderr` channels. So `set a 10` shows `10` (the command's result), but
`puts $net_hilight_style` shows nothing in the CIW — `puts` returns an empty string and writes its
payload to the process's real stdout (the launching terminal). A user driving xschem from the CIW
expects `puts` to print *in the CIW*, like an interactive console (tkcon, the Tk console, …).

This feature makes a Tcl `puts` to `stdout`/`stderr`, issued by an interactively-entered CIW
command, appear in the CIW log pane.

## Where it hooks in

`src/ciw.tcl`, function `ciw_exec`. The capture is installed for **exactly the dynamic extent of the
user's command** — `puts` is temporarily redefined around the `uplevel #0 $cmd` and restored
immediately after (whether the command succeeds or errors). Nothing else in xschem's Tcl is
affected: code that runs outside an interactively-entered command keeps writing to the real
stdout/stderr.

## Behaviour

While a CIW command runs, `puts` is intercepted:

| call form                         | effect                                              |
|-----------------------------------|-----------------------------------------------------|
| `puts STRING`                     | STRING → CIW log pane, `result` tag (stdout default) |
| `puts stdout STRING`              | STRING → CIW log pane, `result` tag                  |
| `puts stderr STRING`              | STRING → CIW log pane, `error` tag (red)             |
| `puts -nonewline … STRING`        | as above; the `-nonewline` flag is **ignored**       |
| `puts $chan STRING` (file/socket) | **delegated verbatim** to the real `puts` (unchanged)|
| malformed / wrong-arg `puts …`    | delegated to the real `puts` (its normal error)      |

`puts` keeps returning the empty string, so `ciw_exec`'s own result-echo does not additionally print
it — the captured text appears exactly once, as the line `ciw_echo` writes.

### Locked design decisions (per request)

1. **Scoped per command**, not global. Installed around `uplevel #0 $cmd` and torn down right
   after, so internal xschem Tcl that `puts` to stdout elsewhere still reaches the terminal, and the
   CIW is never flooded with engine chatter.
2. **`-nonewline` ignored.** The log pane is line-oriented (`ciw_echo` always appends a newline);
   honouring `-nonewline` would require buffering a pending partial line. Out of scope; the flag is
   accepted and dropped for stdout/stderr (but preserved when delegating to a real channel).
3. **Replace, CIW-only.** Captured stdout/stderr text goes to the CIW *only* — it is not also
   mirrored to the real terminal.
4. **stderr included**, shown with the existing `error` (red) tag; stdout uses `result` (gray30).
5. **Tcl `puts` only.** Output written by xschem's **C** code (`dbg()`, `fprintf` to stdout/stderr)
   is *not* captured and still goes to the terminal. This feature intercepts the Tcl `puts` command;
   it does not redirect the underlying OS file descriptors.

## Implementation sketch

```tcl
## Route a captured puts (its arg list) to the CIW; delegate non-console channels.
proc ciw_capture_puts {argl} {
  set a $argl
  if {[lindex $a 0] eq "-nonewline"} {set a [lrange $a 1 end]}   ;# accepted, ignored
  set n [llength $a]
  if {$n == 1} {                                   ;# puts STRING -> stdout
    ciw_echo [lindex $a 0] result
  } elseif {$n == 2 && [lindex $a 0] eq "stdout"} {
    ciw_echo [lindex $a 1] result
  } elseif {$n == 2 && [lindex $a 0] eq "stderr"} {
    ciw_echo [lindex $a 1] error
  } else {                                         ;# real channel or bad args: real puts, verbatim
    eval [linsert $argl 0 ::ciw_saved_puts]        ;# 8.4-safe {*}$argl
  }
}
```

and in `ciw_exec`, around the evaluation:

```tcl
  rename ::puts ::ciw_saved_puts
  proc ::puts {args} {ciw_capture_puts $args}
  set code [catch {uplevel #0 $cmd} res]
  rename ::puts {}
  rename ::ciw_saved_puts ::puts
```

The rename pair is balanced and the `catch` keeps the command's error from skipping the restore, so
`puts` is always returned to normal. Tcl-8.4-safe (no `{*}`, no `in`).

## Acceptance / tests

`tests/headless/test_ciw_puts_capture.tcl` (run under X, like `test_ciw_autocomplete.tcl`), driving
`ciw_exec` on a set entry:

- PC1 `puts hello` → log pane gains a `hello` line (and exactly one).
- PC2 `puts stdout world` → log gains `world`.
- PC3 `puts stderr oops` → log gains `oops`, carrying the `error` tag.
- PC4 `puts -nonewline nonl` → log gains `nonl` (newline added regardless).
- PC5 delegation: `set ch [open <tmp> w]; puts $ch filedata; close $ch` → the file contains
  `filedata` and the log pane does **not**.
- PC6 scoping: after any command, `::ciw_saved_puts` no longer exists and `::puts` is the real
  command again (capture fully torn down).
- PC7 `puts foo` produces the `foo` line once (no double echo from the result path).

The existing `test_ciw.tcl` and `test_ciw_autocomplete.tcl` must stay green; the
create_save/open_close/netlisting regression suites are unaffected (GUI-only Tcl).

## Out of scope

- `-nonewline` partial-line buffering.
- Capturing **C-level** stdout/stderr (would need OS fd redirection, not a Tcl `puts` shim).
- Mirroring captured output to the terminal as well as the CIW.
- Intercepting `gets`/interactive input, or any channel other than stdout/stderr.
